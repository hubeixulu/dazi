from __future__ import annotations

DIFFICULTIES = {
    "easy": {"label": "简单", "min_chars": 0, "max_chars": 110, "hint": "always"},
    "normal": {"label": "普通", "min_chars": 80, "max_chars": 230, "hint": "next"},
    "hard": {"label": "困难", "min_chars": 180, "max_chars": 600, "hint": "minimal"},
}

GAME_CONFIG = {
    "letter-rain": {
        "easy": {"spawn_ms": 1050, "fall_step": 2.1, "lives": 5, "mode": "home"},
        "normal": {"spawn_ms": 720, "fall_step": 3.2, "lives": 3, "mode": "letters"},
        "hard": {"spawn_ms": 500, "fall_step": 4.3, "lives": 2, "mode": "words"},
    },
    "typing-race": {
        "easy": {"opponent_speed": 0.55, "phrase_set": "easy"},
        "normal": {"opponent_speed": 0.82, "phrase_set": "normal"},
        "hard": {"opponent_speed": 1.08, "phrase_set": "hard"},
    },
    "space-words": {
        "easy": {"spawn_ms": 1400, "fall_step": 1.3, "lives": 5, "word_set": "easy"},
        "normal": {"spawn_ms": 1000, "fall_step": 2.0, "lives": 3, "word_set": "normal"},
        "hard": {"spawn_ms": 720, "fall_step": 2.8, "lives": 2, "word_set": "hard"},
    },
}

