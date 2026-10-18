import json
import re
import struct
import tomllib
from pathlib import Path

ROOT = Path(__file__).parents[1]
ART = ROOT / "src/dazi/resources/games"


def test_runtime_art_manifest_matches_png_dimensions():
    manifest = json.loads((ART / "manifest.json").read_text(encoding="utf-8"))
    assert len(manifest["sources"]) == 4
    assert len(manifest["sprites"]) >= 35
    # Watercraft include a detached hull/splash: never trim to just the pilot's head.
    duck_width, duck_height = manifest["sprites"]["race-duck"]["size"]
    assert duck_height / duck_width > 0.7
    for name, sprite in manifest["sprites"].items():
        data = (ART / f"{name}.png").read_bytes()
        assert data[:8] == b"\x89PNG\r\n\x1a\n"
        assert list(struct.unpack(">II", data[16:24])) == sprite["size"]
        if not name.endswith("cover"):
            assert data[25] == 6, f"Sprite must include alpha: {name}"


def test_qml_static_art_references_resolve_without_original_sheets():
    for qml in (ROOT / "src/dazi/qml").glob("*.qml"):
        text = qml.read_text(encoding="utf-8")
        assert "ass/" not in text
        for name in re.findall(r'\.\./resources/games/([a-z-]+\.png)', text):
            assert (ART / name).is_file(), (qml.name, name)


def test_wheel_configuration_includes_runtime_art_and_git_ignores_raw_directory():
    config = tomllib.loads((ROOT / "pyproject.toml").read_text(encoding="utf-8"))
    patterns = config["tool"]["setuptools"]["package-data"]["dazi"]
    assert "resources/games/*.png" in patterns
    assert "resources/games/*.json" in patterns
    assert "/ass/" in (ROOT / ".gitignore").read_text(encoding="utf-8").splitlines()
