"""Extract runtime sprites from the user's locally supplied ass/ contact sheets.

Requires Pillow (only for this offline authoring step, not app runtime).
Original sheets are not packaged or committed. Run from the repository root:
    python tools/prepare_game_art.py
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "src/dazi/resources/games"
# Crops exclude the printed asset captions and section frames.
SPRITES = {
    "字母雨": {
        "rain-idle": (28, 608, 313, 838),
        "rain-happy": (332, 637, 521, 825),
        "rain-sad": (549, 640, 735, 830),
        "rain-drop": (931, 772, 1004, 856),
        "heart": (366, 944, 450, 1025),
        "combo": (34, 925, 318, 1054),
    },
    "打字竞速": {
        "race-player": (30, 570, 248, 724),
        "race-player-fast": (488, 566, 705, 728),
        "race-player-win": (714, 565, 914, 728),
        "race-rabbit": (36, 794, 207, 926),
        "race-duck": (224, 797, 385, 928),
        "race-cat": (398, 793, 554, 929),
        "race-boost": (581, 800, 786, 912),
        "race-finish": (1026, 806, 1430, 936),
    },
    "单词太空战": {
        "space-player": (35, 563, 379, 745),
        "space-player-fire": (273, 754, 393, 824),
        "space-enemy-green": (408, 564, 521, 672),
        "space-enemy-red": (534, 564, 642, 674),
        "space-enemy-yellow": (650, 564, 770, 674),
        "space-enemy-purple": (416, 713, 553, 822),
        "space-enemy-robot": (567, 704, 701, 822),
        "space-boss": (766, 560, 1032, 817),
        "space-earth": (1051, 558, 1175, 674),
        "space-saturn": (1190, 563, 1318, 678),
        "space-meteor": (1332, 566, 1431, 674),
        "space-nebula": (1303, 699, 1437, 809),
        "space-bolt": (24, 901, 163, 962),
        "space-shield": (492, 922, 577, 1012),
        "star": (763, 919, 842, 1008),
    },
    "警察抓小偷": {
        "chase-police": (29, 610, 378, 821),
        "chase-thief": (394, 617, 678, 820),
        "chase-caught": (451, 910, 771, 1067),
        "chase-boost": (31, 920, 205, 1016),
        "chase-smoke": (211, 925, 313, 1017),
        "chase-sign": (736, 615, 932, 696),
    },
}
COVERS = {
    "字母雨": ("rain-cover", (14, 14, 1434, 550)),
    "打字竞速": ("race-cover", (14, 14, 1434, 516)),
    "单词太空战": ("space-cover", (14, 14, 1434, 506)),
    "警察抓小偷": ("chase-cover", (14, 14, 1434, 550)),
}


def remove_connected_white(image: Image.Image) -> Image.Image:
    """Key only the edge-connected pale paper, retaining enclosed white highlights."""
    image = image.convert("RGB")
    paper = Image.new("L", image.size)
    rgb_bytes = image.tobytes()
    pixels_rgb = zip(rgb_bytes[0::3], rgb_bytes[1::3], rgb_bytes[2::3])
    paper.putdata([255 if min(rgb) >= 228 and max(rgb) - min(rgb) < 26 else 0
                   for rgb in pixels_rgb])
    width, height = image.size
    pixels = paper.load()
    for x in range(width):
        for y in (0, height - 1):
            if pixels[x, y] == 255:
                ImageDraw.floodfill(paper, (x, y), 128)
    for y in range(height):
        for x in (0, width - 1):
            if pixels[x, y] == 255:
                ImageDraw.floodfill(paper, (x, y), 128)
    background = paper.point(lambda value: 255 if value == 128 else 0)
    background = background.filter(ImageFilter.GaussianBlur(0.35))
    alpha = background.point(lambda value: 255 - value)
    result = image.convert("RGBA")
    result.putalpha(alpha)
    bbox = result.getchannel("A").getbbox()
    return result.crop(bbox) if bbox else result


def remove_neighbor_fragments(image: Image.Image) -> Image.Image:
    """Discard disconnected neighboring sprites/caption remnants outside the subject."""
    width, height = image.size
    alpha = bytearray(image.getchannel("A").tobytes())
    seen = bytearray(len(alpha))
    components = []
    for seed, opacity in enumerate(alpha):
        if opacity < 32 or seen[seed]:
            continue
        stack = [seed]
        seen[seed] = 1
        points = []
        left = right = seed % width
        top = bottom = seed // width
        while stack:
            index = stack.pop()
            points.append(index)
            x, y = index % width, index // width
            left, right = min(left, x), max(right, x)
            top, bottom = min(top, y), max(bottom, y)
            adjacent = []
            if x: adjacent.append(index - 1)
            if x + 1 < width: adjacent.append(index + 1)
            if y: adjacent.append(index - width)
            if y + 1 < height: adjacent.append(index + width)
            for neighbor in adjacent:
                if alpha[neighbor] >= 32 and not seen[neighbor]:
                    seen[neighbor] = 1
                    stack.append(neighbor)
        components.append((points, (left, top, right, bottom)))
    if not components:
        return image
    main_points, main_box = max(components, key=lambda part: len(part[0]))
    left, top, right, bottom = main_box
    retained = bytearray(len(alpha))
    for points, box in components:
        center_x, center_y = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
        if points is main_points or (len(points) >= 10 and
                left - 5 <= center_x <= right + 5 and top - 5 <= center_y <= bottom + 5):
            for index in points:
                retained[index] = 255
    # Grow only the kept pixel mask, never clear entire overlapping bounding boxes.
    mask = Image.frombytes("L", image.size, bytes(retained)).filter(ImageFilter.MaxFilter(3))
    image.putalpha(ImageChops.multiply(image.getchannel("A"), mask))
    return image


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = {"description": "Runtime derivatives of user-supplied local art sheets; original ass/ excluded.",
                "sources": {}, "sprites": {}}
    for sheet_name, sprites in SPRITES.items():
        source = ROOT / "ass" / f"{sheet_name}.png"
        with Image.open(source) as sheet:
            manifest["sources"][sheet_name] = hashlib.sha256(source.read_bytes()).hexdigest()
            for name, bounds in sprites.items():
                sprite = sheet.crop(bounds)
                if name == "chase-sign":
                    # Remove the baked sample word; runtime text supplies the live prompt.
                    draw = ImageDraw.Draw(sprite)
                    draw.rounded_rectangle((17, 13, 183, 64), radius=5, fill=(17, 117, 70))
                sprite = remove_connected_white(sprite)
                if name in {"space-earth", "space-saturn", "space-meteor", "space-nebula", "star"}:
                    sprite = remove_neighbor_fragments(sprite)
                    bbox = sprite.getchannel("A").getbbox()
                    if bbox:
                        sprite = sprite.crop(bbox)
                sprite.save(OUTPUT / f"{name}.png", optimize=True)
                manifest["sprites"][name] = {"source": sheet_name, "crop": list(bounds), "size": list(sprite.size)}
            cover_name, bounds = COVERS[sheet_name]
            cover = sheet.crop(bounds).convert("RGB")
            cover.thumbnail((1100, 480), Image.Resampling.LANCZOS)
            cover.save(OUTPUT / f"{cover_name}.png", optimize=True)
            manifest["sprites"][cover_name] = {"source": sheet_name, "crop": list(bounds), "size": list(cover.size)}
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Prepared {len(manifest['sprites'])} runtime images in {OUTPUT}")


if __name__ == "__main__":
    main()
