# -*- mode: python ; coding: utf-8 -*-
from pathlib import Path
import sys
import dazi

package = Path(dazi.__file__).parent

a = Analysis(
    [str(Path(SPECPATH) / "launcher.py")],
    pathex=[],
    binaries=[],
    datas=[(str(package / "qml"), "dazi/qml"), (str(package / "resources"), "dazi/resources")],
    hiddenimports=["PySide6.QtQml", "PySide6.QtQuick", "PySide6.QtQuickControls2"],
    hookspath=[], hooksconfig={}, runtime_hooks=[], excludes=[], noarchive=False,
)
pyz = PYZ(a.pure)
platform_icon = str(Path(SPECPATH) / ("app-icon.ico" if sys.platform == "win32" else "app-icon.icns"))
exe = EXE(pyz, a.scripts, [], exclude_binaries=True, name="打字星球", debug=False,
          bootloader_ignore_signals=False, strip=False, upx=True, console=False, icon=platform_icon)
coll = COLLECT(exe, a.binaries, a.datas, strip=False, upx=True, name="打字星球")
app = BUNDLE(coll, name="打字星球.app", icon=str(Path(SPECPATH) / "app-icon.icns"),
             bundle_identifier="com.dazi.academy")
