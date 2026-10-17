"""Deterministic, UI-independent police-and-thief typing pursuit.

All distances are abstract route units.  The playful thief escapes rather than being
hurt; catching them means returning the missing library books to their shelf.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
import math
import random


@dataclass(frozen=True)
class Difficulty:
    stages: int
    start_distance: float
    escape_distance: float
    thief_speed: float
    typing_gain: float
    error_penalty: float
    obstacle_penalty: float
    time_limit: float
    catch_distance: float
    lives: int


DIFFICULTIES: dict[str, Difficulty] = {
    "easy": Difficulty(5, 30, 100, 0.65, 1.45, 0.35, 2, 150, 5, 5),
    "normal": Difficulty(6, 36, 100, 1.2, 1.15, 0.7, 4, 115, 5, 4),
    "hard": Difficulty(7, 42, 100, 1.85, 0.95, 1.1, 6, 90, 5, 3),
}

PHRASES: dict[str, tuple[str, ...]] = {
    "easy": ("look for clues", "run to the park", "follow the trail", "find the books",
             "take the path", "wave to a friend", "check the map", "cross the bridge"),
    "normal": ("follow the bright blue footprints", "ask the friendly crossing guard",
               "turn left beside the old clock", "spot the trail of library cards",
               "hurry past the noisy playground", "find a shortcut through the garden",
               "check the map at the town square", "keep the lost books safe and dry"),
    "hard": ("carefully follow the winding riverside trail",
             "quickly decode the clues beside the clock tower",
             "navigate the busy market without losing the trail",
             "remember where the colorful library wagon stopped",
             "look for tiny footprints near the wooden bridge",
             "choose the clever shortcut around the fountain",
             "ask a friendly neighbor about the missing books",
             "bring every borrowed story safely back to the shelf"),
}

OBSTACLES = ("puddle", "fallen leaves", "traffic cone", "playful puppy")
ROUTES = ("park", "bridge", "market", "garden", "square", "library", "river", "playground")


@dataclass(frozen=True)
class Segment:
    stage: int
    route: str
    phrase: str
    obstacle: str | None

    def to_dict(self) -> dict:
        return asdict(self)


def generate_route(difficulty: str, seed: int | None = None) -> tuple[Segment, ...]:
    """Generate 5/6/7 reproducible, varied segments without touching global RNG."""
    if difficulty not in DIFFICULTIES:
        raise ValueError(f"Unknown difficulty: {difficulty}")
    rng = random.Random(seed)
    phrases = list(PHRASES[difficulty])
    routes = list(ROUTES)
    rng.shuffle(phrases)
    rng.shuffle(routes)
    return tuple(Segment(index + 1, routes[index], phrases[index],
                         rng.choice(OBSTACLES) if index % 2 == 1 else None)
                 for index in range(DIFFICULTIES[difficulty].stages))


class PursuitGame:
    """Pure state machine; no Qt, clock, filesystem, or process-global randomness.

    ``submit`` accepts the *entire current input buffer*, not just new characters.
    Only a valid extension of the current accepted prefix advances the route. A
    wrong input is penalized once until the bad suffix is removed; backspace to
    the accepted prefix before retrying. ``tick`` is the sole source of elapsed time.
    """

    def __init__(self) -> None:
        self._config: Difficulty | None = None
        self._difficulty = ""
        self._segments: tuple[Segment, ...] = ()
        self._index = 0
        self._prefix = ""
        self._failed_buffer: str | None = None
        self._elapsed = 0.0
        self._distance = 0.0
        self._correct = 0
        self._errors = 0
        self._combo = 0
        self._best_combo = 0
        self._cleared = 0
        self._status = "ready"

    def start(self, difficulty: str, seed: int | None = None) -> dict:
        """Start/restart a chase, returning a fresh JSON/QVariant-compatible state."""
        if difficulty not in DIFFICULTIES:
            raise ValueError(f"Unknown difficulty: {difficulty}")
        self.__init__()
        self._difficulty = difficulty
        self._config = DIFFICULTIES[difficulty]
        self._segments = generate_route(difficulty, seed)
        self._distance = self._config.start_distance
        self._status = "running"
        return self.state()

    def submit(self, typed: str) -> dict:
        """Apply a complete text-field value; stale calls after the game ends do nothing."""
        if not isinstance(typed, str):
            raise TypeError("typed must be a string")
        if self._status != "running":
            return self.state()
        phrase = self._segments[self._index].phrase
        if typed == self._prefix:
            self._failed_buffer = None
            return self.state()
        if self._failed_buffer is not None:
            bad_char_index = len(self._prefix)
            if (len(typed) > bad_char_index and len(self._failed_buffer) > bad_char_index
                    and typed[bad_char_index] == self._failed_buffer[bad_char_index]):
                # A single typo and all characters typed after it cost only one life.
                return self.state()
        if typed.startswith(self._prefix) and phrase.startswith(typed):
            newly_correct = len(typed) - len(self._prefix)
            self._correct += newly_correct
            self._combo += newly_correct
            self._best_combo = max(self._best_combo, self._combo)
            self._distance = max(0.0, self._distance - newly_correct * self._config.typing_gain)
            self._prefix = typed
            self._failed_buffer = None
            if typed == phrase:
                self._cleared += 1
                obstacle = self._segments[self._index].obstacle
                if obstacle:
                    self._distance += self._config.obstacle_penalty
                self._check_escape()
                if self._status == "lost":
                    self._index += 1
                    return self.state()
                self._index += 1
                self._prefix = ""
                if self._index == len(self._segments):
                    self._status = "won"
            return self.state()
        # One penalty per typo; changing that bad suffix cannot drain every life.
        if typed != self._failed_buffer:
            self._failed_buffer = typed
            self._errors += 1
            self._combo = 0
            self._distance += self._config.error_penalty
            self._check_escape()
        return self.state()

    def tick(self, seconds: float = 1) -> dict:
        """Advance simulated time explicitly; nonnegative finite seconds only."""
        if not isinstance(seconds, (int, float)) or not math.isfinite(seconds) or seconds < 0:
            raise ValueError("seconds must be a finite nonnegative number")
        if self._status == "running":
            self._elapsed += seconds
            self._distance += self._config.thief_speed * seconds
            self._check_escape()
        return self.state()

    def _check_escape(self) -> None:
        if (self._distance >= self._config.escape_distance
                or self._elapsed >= self._config.time_limit
                or self._errors >= self._config.lives):
            self._status = "lost"

    def state(self) -> dict:
        """Return a detached, plain dict suited to a PySide6 QVariantMap slot."""
        config = self._config
        segment = self._segments[self._index] if self._status == "running" else None
        attempts = self._correct + self._errors
        accuracy = round(100 * self._correct / attempts, 1) if attempts else 100.0
        return {
            "status": self._status,
            "phase": self._status,
            "difficulty": self._difficulty,
            "stage": self._index + 1 if segment else self._cleared,
            "stages": len(self._segments),
            "total_stages": len(self._segments),
            "target": segment.phrase if segment else "",
            "message": ("Catch the book thief by typing the clue!" if segment else
                        "Great work! The books are safe!" if self._status == "won" else
                        "The thief got away. Try another route!" if self._status == "lost" else
                        "Choose a difficulty to start."),
            "lives": max(0, config.lives - self._errors) if config else 0,
            "segments": [item.to_dict() for item in self._segments],
            "current": segment.to_dict() if segment else None,
            "obstacles": ([{"position": 0.48, "kind": segment.obstacle}] if segment and segment.obstacle else []),
            "typed": self._prefix,
            "progress": round(len(self._prefix) / len(segment.phrase), 3) if segment else 0.0,
            "completed_stages": self._cleared,
            "correct": self._correct,
            "errors": self._errors,
            "accuracy": accuracy,
            "combo": self._combo,
            "best_combo": self._best_combo,
            "distance": round(self._distance, 2),
            "thief_progress": round(min(100.0, 100.0 * self._distance / config.escape_distance), 2) if config else 0.0,
            "police_progress": round(100.0 * (self._cleared + (len(self._prefix) / len(segment.phrase) if segment else 0)) / len(self._segments), 2) if self._segments else 0.0,
            "escape_distance": config.escape_distance if config else 0,
            "elapsed": round(self._elapsed, 2),
            "elapsed_seconds": round(self._elapsed, 2),
            "time_limit": config.time_limit if config else 0,
            "score": max(0, self._correct * 10 + self._cleared * 50
                         + self._best_combo * 2 - self._errors * 15
                         + (150 if self._status == "won" else 0)),
        }
