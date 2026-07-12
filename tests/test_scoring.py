from dazi.scoring import current_error_index, normalize, score_text


def test_english_score_uses_wpm():
    result = score_text("hello world", "hello world", 60, "en")
    assert result.accuracy == 100
    assert result.speed == 2.2
    assert result.speed_unit == "WPM"


def test_chinese_score_uses_characters_per_minute():
    result = score_text("春眠不觉晓", "春眠不觉", 30, "zh")
    assert result.correct == 4
    assert result.errors == 1
    assert result.accuracy == 80
    assert result.speed == 8
    assert result.speed_unit == "字/分钟"


def test_insertions_and_deletions_are_counted():
    result = score_text("abcdef", "abXdef!", 10, "en")
    assert result.correct == 5
    assert result.errors == 2


def test_current_prefix_error():
    assert current_error_index("hello", "hel") == -1
    assert current_error_index("hello", "hex") == 2
    assert current_error_index("hi", "hit") == 2


def test_newlines_are_normalized():
    assert normalize("a\r\nb\rc") == "a\nb\nc"


def test_zero_elapsed_is_safe():
    result = score_text("a", "a", 0, "en")
    assert result.speed > 0

