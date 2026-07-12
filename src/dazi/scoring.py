from __future__ import annotations

from dataclasses import asdict, dataclass
from difflib import SequenceMatcher


@dataclass(frozen=True)
class Score:
    correct: int
    errors: int
    accuracy: float
    elapsed_seconds: float
    speed: float
    speed_unit: str

    def to_dict(self) -> dict:
        return asdict(self)


def normalize(text: str) -> str:
    """Normalize newlines without changing meaningful spaces or punctuation."""
    return text.replace("\r\n", "\n").replace("\r", "\n")


def score_text(target: str, typed: str, elapsed_seconds: float, language: str) -> Score:
    target, typed = normalize(target), normalize(typed)
    matcher = SequenceMatcher(a=target, b=typed, autojunk=False)
    correct = sum(block.size for block in matcher.get_matching_blocks())
    errors = max(len(target), len(typed)) - correct
    total = max(len(target), len(typed), 1)
    accuracy = round(correct / total * 100, 1)
    minutes = max(elapsed_seconds, 0.1) / 60
    if language == "en":
        speed = round((correct / 5) / minutes, 1)
        unit = "WPM"
    else:
        speed = round(correct / minutes, 1)
        unit = "字/分钟"
    return Score(correct, errors, accuracy, round(max(elapsed_seconds, 0), 1), speed, unit)


def score_live_text(target: str, typed: str, elapsed_seconds: float, language: str) -> Score:
    """Score only what has been entered; unfinished target text is not an error."""
    if not typed:
        return Score(0, 0, 100.0, round(max(elapsed_seconds, 0), 1), 0.0,
                     "WPM" if language == "en" else "字/分钟")
    return score_text(target[:len(typed)], typed, elapsed_seconds, language)


def current_error_index(target: str, typed: str) -> int:
    """Return the first mismatching index, or -1 when the current prefix is valid."""
    for index, char in enumerate(typed):
        if index >= len(target) or target[index] != char:
            return index
    return -1
