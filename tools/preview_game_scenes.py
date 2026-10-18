"""Render deterministic game scene previews using the application's Qt runtime.

QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software python tools/preview_game_scenes.py
Previews go to build/game-previews/ (ignored by Git).
"""
from pathlib import Path
import os
import tempfile

os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

import shiboken6
from PySide6.QtCore import QUrl
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest
from PySide6.QtWidgets import QApplication

from dazi.backend import Backend

ROOT = Path(__file__).resolve().parents[1]


def main():
    app = QApplication([])
    output = ROOT / "build/game-previews"
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as data:
        backend = Backend(ROOT / "src/dazi/resources", Path(data))
        backend.soundEnabled = False
        backend.reducedMotion = True
        for name in ("LetterRain", "TypingRace", "SpaceWords", "PoliceChase"):
            view = QQuickView()
            view.rootContext().setContextProperty("backend", backend)
            view.setResizeMode(QQuickView.SizeRootObjectToView)
            view.resize(1000, 650)
            view.setSource(QUrl.fromLocalFile(str(ROOT / "src/dazi/qml" / f"{name}.qml")))
            assert view.status() == QQuickView.Ready, view.errors()
            view.show()
            QTest.qWait(100)
            assert view.grabWindow().save(str(output / f"{name}-ready.png"))
            game = view.rootObject()
            if name == "TypingRace":
                game.reset()
            else:
                game.start()
            if name == "LetterRain":
                game.setProperty("drops", [{"id": i, "token": key, "x": x, "y": y}
                                           for i, (key, x, y) in enumerate([
                                               ("a", .2, 75), ("f", .42, 145), ("j", .65, 80), ("s", .82, 210)])])
                game.setProperty("score", 120)
                game.setProperty("combo", 5)
            elif name == "SpaceWords":
                game.setProperty("enemies", [{"id": i, "word": word, "x": x, "y": y, "boss": boss, "kind": i}
                                             for i, (word, x, y, boss) in enumerate([
                                                 ("cat", .2, 65, False), ("sun", .43, 130, False),
                                                 ("planet", .75, 70, True)])])
                game.setProperty("score", 230)
                game.setProperty("combo", 6)
            elif name == "PoliceChase":
                backend.pursuitSubmit(backend.pursuitState["target"][:7])
            QTest.qWait(120)
            assert view.grabWindow().save(str(output / f"{name}-active.png"))
            game.setProperty("paused", True)
            QTest.qWait(50)
            assert view.grabWindow().save(str(output / f"{name}-paused.png"))
            view.close()
            shiboken6.delete(view)
            app.processEvents()
        print(f"Rendered ready/active/paused previews to {output}")


if __name__ == "__main__":
    main()
