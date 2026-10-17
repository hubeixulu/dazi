from pathlib import Path

from dazi.backend import Backend


RESOURCE = Path(__file__).parents[1] / "src" / "dazi" / "resources"


def test_pursuit_saves_terminal_result_once_and_uses_correct_difficulty(tmp_path, monkeypatch):
    backend = Backend(RESOURCE, tmp_path)
    monkeypatch.setattr(backend, "playFeedback", lambda kind: None)
    state = backend.pursuitStart("easy")
    assert state["phase"] == "running"
    for _ in range(state["stages"]):
        state = backend.pursuitSubmit(state["target"])
    assert state["phase"] == "won"
    results = backend.storage.recent_results()
    assert len(results) == 1
    assert results[0]["lesson_id"] == "game-police-chase"
    assert results[0]["difficulty"] == "easy"
    backend.pursuitSubmit("extra")
    backend.pursuitTick()
    assert len(backend.storage.recent_results()) == 1


def test_pursuit_escape_and_restart(tmp_path, monkeypatch):
    backend = Backend(RESOURCE, tmp_path)
    monkeypatch.setattr(backend, "playFeedback", lambda kind: None)
    assert backend.pursuitStart("hard")["phase"] == "running"
    for _ in range(100):
        result = backend.pursuitTick()
        if result["phase"] == "lost":
            break
    assert result["phase"] == "lost"
    assert len(backend.storage.recent_results()) == 1
    assert backend.pursuitStart("normal")["phase"] == "running"
    assert backend.pursuitState["difficulty"] == "normal"
    assert backend.pursuitState["elapsed"] == 0
