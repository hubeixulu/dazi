from __future__ import annotations

import os
import sys
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtGui import QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication

from .backend import Backend


def main() -> int:
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    app = QApplication(sys.argv)
    app.setApplicationName("打字星球")
    app.setOrganizationName("DaziAcademy")
    app.setApplicationVersion("0.3.1")

    package_dir = Path(__file__).resolve().parent
    app.setWindowIcon(QIcon(str(package_dir / "resources" / "icons" / "app-icon-1024.png")))
    backend = Backend(package_dir / "resources")
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(package_dir / "qml" / "Main.qml")))
    if not engine.rootObjects():
        return 1
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
