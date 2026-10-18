"""Exercise the actual QML scenes, not copies of their gameplay code."""
import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

import pytest
import shiboken6
from PySide6.QtCore import QObject, QUrl
from PySide6.QtGui import QImage
from PySide6.QtQuick import QQuickView

from dazi.backend import Backend

PACKAGE = Path(__file__).parents[1] / "src/dazi"


def variant(value):
    return value.toVariant() if hasattr(value, "toVariant") else value


@pytest.fixture
def scene(qapp, tmp_path):
    views = []
    backend = Backend(PACKAGE / "resources", tmp_path)
    backend.soundEnabled = False
    backend.reducedMotion = True

    def create(name, width=760, height=540):
        view = QQuickView()
        views.append(view)
        messages = []
        view.engine().warnings.connect(lambda errors: messages.extend(error.toString() for error in errors))
        view.rootContext().setContextProperty("backend", backend)
        view.setResizeMode(QQuickView.SizeRootObjectToView)
        view.resize(width, height)
        view.setSource(QUrl.fromLocalFile(str(PACKAGE / "qml" / f"{name}.qml")))
        assert view.status() == QQuickView.Ready, view.errors()
        view.show()
        qapp.processEvents()
        return view, view.rootObject(), messages

    yield create, backend
    for view in views:
        view.close()
        shiboken6.delete(view)
    backend.storage.connection.close()


@pytest.mark.parametrize("name", ["LetterRain", "TypingRace", "SpaceWords", "PoliceChase"])
@pytest.mark.parametrize("size", [(760, 540), (1000, 650)])
def test_game_ready_active_pause_and_images_load(scene, qtbot, name, size):
    create, backend = scene
    view, game, warnings = create(name, *size)
    if name == "TypingRace":
        game.reset()
    else:
        game.start()
    qtbot.wait(70)
    assert not view.grabWindow().isNull()
    for child in game.findChildren(QObject):
        if "QQuickImage" in child.metaObject().className() and child.property("source"):
            source = child.property("source")
            if isinstance(source, QUrl) and not source.isEmpty():
                resolved = QUrl.fromLocalFile(str(PACKAGE / "qml") + "/").resolved(source)
                assert resolved.isLocalFile(), resolved.toString()
                assert not QImage(resolved.toLocalFile()).isNull(), f"Failed image: {resolved.toString()}"
    game.setProperty("paused", True)
    elapsed = (backend.pursuitState["elapsed"] if name == "PoliceChase" else
               game.property("seconds") if name == "LetterRain" else game.property("elapsed"))
    qtbot.wait(1050)
    current = (backend.pursuitState["elapsed"] if name == "PoliceChase" else
               game.property("seconds") if name == "LetterRain" else game.property("elapsed"))
    assert elapsed == current
    assert not warnings, warnings


def test_rain_typing_pause_and_finish_once(scene):
    create, backend = scene
    _, game, _ = create("LetterRain")
    game.start()
    game.setProperty("drops", [{"id": 1, "token": "a", "x": 0.5, "y": 10}])
    game.submitInput("a")
    assert game.property("hits") == 1
    assert game.property("correctChars") == 1
    game.setProperty("paused", True)
    game.submitInput("x")
    assert game.property("attempts") == 1
    game.setProperty("paused", False)
    game.finish()
    game.finish()
    assert len(backend.storage.recent_results()) == 1
    game.reset()
    assert game.property("score") == 0
    assert game.property("resultSaved") is False


def test_space_live_words_character_accuracy_and_finish_once(scene):
    create, backend = scene
    _, game, _ = create("SpaceWords")
    game.start()
    game.setProperty("enemies", [{"id": 1, "word": "cat", "x": .5, "y": 30, "boss": False, "kind": 0}])
    for key in "xcat":
        game.submitInput(key)
    assert game.property("hits") == 1
    assert game.property("accuracy") == 75
    game.setProperty("paused", True)
    game.submitInput("z")
    assert game.property("shots") == 4
    game.setProperty("paused", False)
    game.finish()
    game.finish()
    assert len(backend.storage.recent_results()) == 1


def test_race_backspace_cannot_farm_combo_and_result_saved_once(scene):
    create, backend = scene
    _, game, _ = create("TypingRace")
    game.reset()
    field = game.findChild(QObject, "typingRaceInput")
    target = game.property("target")
    field.setProperty("text", target[:3])
    game.acceptInput()
    assert game.property("combo") == 3
    field.setProperty("text", target[:2])
    game.acceptInput()
    field.setProperty("text", target[:3])
    game.acceptInput()
    assert game.property("combo") == 3
    field.setProperty("text", target)
    game.acceptInput()
    assert game.property("won") is True
    game.complete(True)
    assert len(backend.storage.recent_results()) == 1
    game.reset()
    game.complete(False)
    assert len(backend.storage.recent_results()) == 2


def test_chase_real_input_advances_and_pause_is_respected(scene, qapp):
    create, backend = scene
    _, game, warnings = create("PoliceChase")
    game.start()
    field = game.findChild(QObject, "policeChaseInput")
    target = backend.pursuitState["target"]
    field.setProperty("text", target)
    field.textEdited.emit()
    qapp.processEvents()
    assert backend.pursuitState["completed_stages"] == 1
    assert field.property("text") == ""
    game.setProperty("paused", True)
    field.setProperty("text", "wrong")
    field.textEdited.emit()
    assert backend.pursuitState["errors"] == 0
    assert not warnings, warnings
