import json
import math

import pytest

from dazi.pursuit import DIFFICULTIES, PHRASES, PursuitGame, generate_route


def test_routes_are_reproducible_varied_ascii_and_global_rng_independent():
    import random

    random.seed(102)
    baseline = random.random()
    random.seed(102)
    for difficulty, config in DIFFICULTIES.items():
        route = generate_route(difficulty, 42)
        assert route == generate_route(difficulty, 42)
        assert len(route) == config.stages
        assert len({item.phrase for item in route}) == len(route)
        assert len({item.route for item in route}) == len(route)
        assert all(item.phrase.isascii() and item.phrase in PHRASES[difficulty] for item in route)
        assert all(item.obstacle for item in route[1::2])
        assert all(item.obstacle is None for item in route[::2])
    assert random.random() == baseline
    assert generate_route("hard", 42) != generate_route("hard", 43)


def test_difficulty_profiles_materially_differ():
    assert [DIFFICULTIES[name].stages for name in ("easy", "normal", "hard")] == [5, 6, 7]
    assert DIFFICULTIES["easy"].thief_speed < DIFFICULTIES["normal"].thief_speed < DIFFICULTIES["hard"].thief_speed
    assert max(map(len, PHRASES["easy"])) < min(map(len, PHRASES["hard"]))
    with pytest.raises(ValueError):
        generate_route("expert", 1)
    with pytest.raises(ValueError):
        PursuitGame().start("expert")


def test_initial_state_is_plain_and_wrapper_friendly():
    game = PursuitGame()
    assert game.state()["phase"] == "ready"
    state = game.start("easy", 1)
    expected = {"phase", "target", "typed", "progress", "distance", "elapsed", "score",
                "combo", "best_combo", "accuracy", "stage", "stages", "lives", "message",
                "difficulty", "thief_progress", "police_progress"}
    assert expected <= state.keys()
    assert state["stage"] == 1 and state["progress"] == 0
    assert state["accuracy"] == 100 and state["distance"] == 30
    assert json.loads(json.dumps(state)) == state
    state["segments"].clear()
    assert len(game.state()["segments"]) == 5


def test_incremental_input_combo_accuracy_and_repeated_error():
    game = PursuitGame()
    phrase = game.start("easy", 4)["target"]
    a = game.submit(phrase[:3])
    assert a["correct"] == 3 and a["combo"] == 3 and a["progress"] > 0
    b = game.submit(phrase[:3] + "!")
    assert b["errors"] == 1 and b["combo"] == 0 and b["accuracy"] == 75
    assert game.submit(phrase[:3] + "!") == b
    assert game.submit(phrase[:3] + "!still wrong")["errors"] == 1
    assert game.submit(phrase[:3])["errors"] == 1
    c = game.submit(phrase[:5])
    assert c["correct"] == 5 and c["best_combo"] == 3 and c["combo"] == 2
    assert c["score"] > 0
    with pytest.raises(TypeError):
        game.submit(None)


def test_completion_obstacle_and_victory():
    game = PursuitGame()
    game.start("easy", 2)
    for i in range(5):
        current = game.state()
        before = current["distance"]
        target = current["target"]
        after = game.submit(target)
        expected = max(0, before - len(target) * DIFFICULTIES["easy"].typing_gain)
        if current["current"]["obstacle"]:
            expected += DIFFICULTIES["easy"].obstacle_penalty
        assert after["distance"] == round(expected, 2)
        assert after["completed_stages"] == i + 1
    assert after["phase"] == "won"
    assert after["score"] > 150
    assert game.submit("anything") == after
    assert game.tick(10) == after


def test_tick_escape_is_deterministic_and_time_limit_is_enforced():
    game = PursuitGame()
    game.start("hard", 7)
    one = game.tick(10)
    assert one["elapsed"] == 10
    assert one["distance"] == 60.5
    final = game.tick(30)
    assert final["phase"] == "lost"
    assert game.tick(1) == final
    game.start("easy", 5)
    assert game.tick(150)["phase"] == "lost"
    for seconds in (-1, math.inf, math.nan, "3"):
        with pytest.raises(ValueError):
            game.tick(seconds)


def test_obstacle_can_end_chase_before_final_stage():
    game = PursuitGame()
    game.start("easy", 12)
    game.submit(game.state()["target"])
    game._distance = game._config.escape_distance + 100
    # Finishing a stage must not allow a win when the obstacle has already ended the chase.
    result = game.submit(game.state()["target"])
    assert result["phase"] == "lost"


def test_restart_resets_statistics_and_route():
    game = PursuitGame()
    game.start("normal", 11)
    game.submit("x")
    game.tick(2)
    fresh = game.start("normal", 11)
    assert fresh["errors"] == 0 and fresh["elapsed"] == 0 and fresh["combo"] == 0
    assert fresh["segments"] == PursuitGame().start("normal", 11)["segments"]
