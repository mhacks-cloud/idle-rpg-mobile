#!/usr/bin/env python3
"""Rebuild Vigília do Musgo's original pixel art and PCM effects.

Requires Python 3 and Pillow (only during regeneration). No source artwork,
downloads, model-generated textures, font files, or sampled audio are used.
The generator is MIT licensed; its generated art and sound are CC0-1.0.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import random
import struct
import wave

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "godot" / "assets"
SEED = 417203
OUTLINE = "#101a2d"
SKIN = "#f4cba1"
LIGHT_SKIN = "#ffe2b3"
MINT = "#87d8b1"
GOLD = "#f5c46c"
PALE = "#e6f3dc"


def rect(draw: ImageDraw.ImageDraw, box, color):
    draw.rectangle(tuple(int(v) for v in box), fill=color)


def hero(kind: str, frame: int) -> Image.Image:
    im = Image.new("RGBA", (24, 24))
    d = ImageDraw.Draw(im)
    y = (0, -1, 0, 0)[frame]
    swing = frame == 2
    step = frame in (1, 3)
    colors = {
        "warrior": ("#7fadc5", "#415b85", "#d5e5db"),
        "archer": ("#83be9b", "#3e786e", "#d4e2a0"),
        "mage": ("#b6a1dc", "#695b9a", "#e4c5ef"),
        "healer": ("#e2c47d", "#7c956e", "#fff0c4"),
    }
    base, dark, light = colors[kind]

    # Asymmetrical cloak, boots, tunic and satchel. All coordinates are pixels.
    rect(d, (5, 11 + y, 16, 20 + y), OUTLINE)
    rect(d, (5, 12 + y, 8, 18 + y), dark)
    rect(d, (7, 19 + y, 10, 22), OUTLINE)
    rect(d, (13, 19 + y, 16, 22 - int(step)), OUTLINE)
    rect(d, (8, 20 + y, 10, 21 + y), "#8e6a68")
    rect(d, (14, 20 + y, 16, 21 - int(step)), "#8e6a68")
    rect(d, (8, 10 + y, 15, 19 + y), base)
    rect(d, (8, 15 + y, 15, 18 + y), dark)
    rect(d, (8, 17 + y, 15, 17 + y), "#c69768")
    rect(d, (10, 11 + y, 11, 14 + y), light)
    rect(d, (5, 12 + y, 7, 16 + y), base)
    rect(d, (5, 16 + y, 7, 18 + y), SKIN)
    rect(d, (16, 11 + y, 18, 16 + y), OUTLINE)
    rect(d, (16, 12 + y, 17, 15 + y), base)
    rect(d, (17, 15 + y, 19, 17 + y), SKIN)

    # Face turned toward the enemy.
    rect(d, (7, 3 + y, 16, 10 + y), OUTLINE)
    rect(d, (8, 4 + y, 15, 9 + y), SKIN)
    rect(d, (10, 4 + y, 15, 6 + y), LIGHT_SKIN)
    rect(d, (15, 7 + y, 17, 8 + y), SKIN)
    rect(d, (13, 6 + y, 14, 7 + y), OUTLINE)

    if kind == "warrior":
        rect(d, (7, 2 + y, 15, 5 + y), base)
        rect(d, (6, 4 + y, 8, 8 + y), dark)
        rect(d, (10, 2 + y, 12, 4 + y), light)
        rect(d, (6, 1 + y, 10, 2 + y), "#f08b80")
        # A square lantern shield, not a borrowed emblem.
        rect(d, (2, 12 + y, 7, 19 + y), OUTLINE)
        rect(d, (3, 13 + y, 6, 18 + y), dark)
        rect(d, (4, 14 + y, 5, 16 + y), GOLD)
        if swing:
            rect(d, (17, 12, 22, 14), OUTLINE)
            rect(d, (19, 12, 23, 12), light)
            rect(d, (20, 11, 22, 11), "#f5fff1")
            rect(d, (18, 11, 18, 15), GOLD)
        else:
            rect(d, (19, 7 + y, 21, 17 + y), OUTLINE)
            rect(d, (20, 6 + y, 20, 14 + y), light)
            rect(d, (18, 15 + y, 22, 15 + y), GOLD)
    elif kind == "archer":
        d.polygon([(6, 7 + y), (7, 3 + y), (11, 1 + y),
                   (16, 3 + y), (18, 5 + y), (8, 5 + y),
                   (8, 9 + y)], fill=dark)
        rect(d, (8, 3 + y, 14, 4 + y), base)
        rect(d, (9, 1 + y, 12, 2 + y), light)
        rect(d, (4, 7 + y, 5, 15 + y), "#ad8063")
        rect(d, (3, 6 + y, 6, 7 + y), light)
        d.line([(19, 8 + y), (22, 11 + y), (22, 16 + y), (19, 19 + y)],
               fill="#dab073", width=1)
        d.line([(19, 8 + y), (19 if not swing else 17, 14 + y),
                (19, 19 + y)], fill=PALE, width=1)
        if swing:
            rect(d, (17, 13 + y, 23, 13 + y), light)
            rect(d, (22, 12 + y, 23, 14 + y), PALE)
    elif kind == "mage":
        d.polygon([(6, 5 + y), (9, 1 + y), (14, 0), (14, 3 + y),
                   (17, 5 + y), (18, 6 + y), (5, 6 + y)], fill=dark)
        rect(d, (8, 4 + y, 15, 4 + y), base)
        rect(d, (11, 1 + y, 12, 2 + y), light)
        rect(d, (8, 19 + y, 16, 20 + y), base)
        rect(d, (20, 8 + y, 20, 21), "#b59389")
        rect(d, (18, 6 + y, 22, 8 + y), OUTLINE)
        rect(d, (19, 4 + y, 21, 8 + y), light)
        rect(d, (20, 5 + y, 22, 6 + y), "#a4f3df")
        if swing:
            rect(d, (18, 2, 18, 3), GOLD)
            rect(d, (22, 1, 23, 1), GOLD)
    else:
        rect(d, (7, 2 + y, 15, 4 + y), dark)
        rect(d, (8, 1 + y, 14, 2 + y), base)
        rect(d, (6, 4 + y, 8, 8 + y), base)
        rect(d, (9, 2 + y, 13, 3 + y), light)
        rect(d, (10, 1 + y, 11, 2 + y), "#7ccda3")
        rect(d, (8, 18 + y, 16, 20 + y), light)
        rect(d, (20, 8 + y, 20, 21), "#a17b68")
        rect(d, (17, 6 + y, 22, 9 + y), dark)
        rect(d, (18, 5 + y, 20, 7 + y), MINT)
        rect(d, (21, 7 + y, 22, 8 + y), light)
        if swing:
            rect(d, (20, 2, 20, 4), GOLD)
            rect(d, (19, 3, 21, 3), GOLD)
    return im


def enemy(kind: str, frame: int) -> Image.Image:
    im = Image.new("RGBA", (24, 24))
    d = ImageDraw.Draw(im)
    y = (0, -1, 0, 1)[frame]
    if kind == "dew_slime":
        rect(d, (6, 16 + y, 17, 21 + y), OUTLINE)
        rect(d, (4, 11 + y, 19, 18 + y), OUTLINE)
        rect(d, (5, 10 + y, 18, 17 + y), "#5aab88")
        rect(d, (7, 8 + y, 16, 18 + y), "#83d2a0")
        rect(d, (9, 9 + y, 15, 11 + y), "#b6e0a8")
        rect(d, (7, 13 + y, 8, 14 + y), OUTLINE)
        rect(d, (13, 13 + y, 14, 14 + y), OUTLINE)
        rect(d, (10, 16 + y, 11, 16 + y), "#348574")
        rect(d, (7, 20, 9, 21), "#448777")
        rect(d, (15, 20, 17, 21), "#448777")
        d.polygon([(11, 8 + y), (7, 6 + y), (7, 3 + y),
                   (11, 4 + y), (13, 8 + y)], fill="#b4d77e")
        d.polygon([(12, 8 + y), (14, 2 + y), (19, 3 + y),
                   (17, 7 + y)], fill="#72b66e")
    elif kind == "bark_mite":
        leg_shift = frame % 2
        for px in (6, 12, 17):
            rect(d, (px - leg_shift, 17, px + 1 - leg_shift, 21), OUTLINE)
            rect(d, (px - leg_shift - 1, 20, px + 1 - leg_shift, 21), "#677998")
        rect(d, (3, 11 + y, 20, 17 + y), OUTLINE)
        rect(d, (6, 7 + y, 19, 16 + y), "#657baf")
        rect(d, (7, 6 + y, 17, 10 + y), "#91a4cf")
        rect(d, (12, 7 + y, 13, 16 + y), "#435a89")
        rect(d, (6, 9 + y, 7, 12 + y), "#d7d0e2")
        rect(d, (2, 12 + y, 7, 17 + y), "#465b81")
        rect(d, (3, 12 + y, 4, 13 + y), GOLD)
        d.line([(4, 12 + y), (2, 9 + y), (1, 9 + y)], fill="#a5c4c8")
        rect(d, (17, 8 + y, 18, 10 + y), "#b2c5df")
    elif kind == "lantern_moth":
        spread = 1 if frame in (1, 3) else 0
        d.polygon([(10, 10 + y), (5 - spread, 5 + y), (2 - spread, 7 + y),
                   (3 - spread, 14 + y), (7, 17 + y), (10, 15 + y)], fill="#6e87b4")
        d.polygon([(13, 10 + y), (18 + spread, 5 + y), (21 + spread, 7 + y),
                   (20 + spread, 14 + y), (16, 17 + y), (13, 15 + y)], fill="#6e87b4")
        rect(d, (4 - spread, 8 + y, 6 - spread, 12 + y), "#b0c4dd")
        rect(d, (17 + spread, 8 + y, 19 + spread, 12 + y), "#b0c4dd")
        rect(d, (9, 9 + y, 14, 18 + y), "#4f7985")
        rect(d, (10, 12 + y, 13, 17 + y), "#e7d98b")
        rect(d, (11, 13 + y, 12, 15 + y), "#fff0b1")
        rect(d, (9, 8 + y, 14, 10 + y), "#b6dad5")
        rect(d, (9, 8 + y, 9, 9 + y), "#285b79")
        rect(d, (13, 8 + y, 13, 9 + y), "#285b79")
        d.line([(10, 8 + y), (8, 5 + y)], fill="#a5c4c8")
        d.line([(13, 8 + y), (15, 5 + y)], fill="#a5c4c8")
        rect(d, (4, 5 + frame, 5, 6 + frame), GOLD)
        rect(d, (19, 17 - frame, 20, 18 - frame), MINT)
    else:
        # The Hollow Trunk is a broad, broken ancient seed-tree guardian.
        d.polygon([(2, 20), (4, 16 + y), (3, 9 + y), (6, 8 + y),
                   (6, 4 + y), (9, 5 + y), (11, 2 + y), (16, 4 + y),
                   (18, 8 + y), (21, 8 + y), (20, 17 + y), (23, 21),
                   (15, 22), (11, 21), (4, 22)], fill=OUTLINE)
        rect(d, (5, 9 + y, 19, 19 + y), "#796c6c")
        rect(d, (8, 5 + y, 16, 19 + y), "#9b8370")
        rect(d, (7, 18, 8, 21), "#5f605b")
        rect(d, (16, 17, 18, 21), "#5f605b")
        rect(d, (6, 11 + y, 8, 13 + y), "#f4be67")
        rect(d, (14, 10 + y, 16, 12 + y), "#f4be67")
        rect(d, (10, 13 + y, 13, 18 + y), "#253d43")
        rect(d, (11, 14 + y, 12, 15 + y), "#e9a75c")
        rect(d, (8, 4 + y, 13, 6 + y), "#66957b")
        rect(d, (13, 3 + y, 17, 5 + y), "#89b68a")
        rect(d, (2, 9 + y, 5, 11 + y), "#4f7e6c")
        rect(d, (18, 7 + y, 21, 9 + y), "#89b68a")
        rect(d, (7, 7 + y, 8, 8 + y), "#c3b07a")
        rect(d, (17, 13 + y, 18, 16 + y), "#b99a7d")
    return im


def save_sheet(kind: str, make):
    sheet = Image.new("RGBA", (96, 24))
    for frame in range(4):
        sheet.paste(make(kind, frame), (frame * 24, 0))
    sheet.save(OUT / f"{kind}.png", optimize=False)


def background():
    rng = random.Random(SEED)
    im = Image.new("RGB", (640, 240), "#111f34")
    d = ImageDraw.Draw(im)
    # Deliberate, discrete color bands preserve the hand-built pixel look.
    for y, col in ((38, "#14283d"), (86, "#173448"), (130, "#1c424e"),
                   (176, "#244f52"), (203, "#294d48"), (220, "#213d3b")):
        rect(d, (0, y, 639, 239), col)
    for x, y in ((474, 26), (480, 21), (488, 18), (498, 20), (504, 28)):
        rect(d, (x, y, x + 8, y + 16), "#e0d69c")
    rect(d, (481, 23, 502, 45), "#e0d69c")
    rect(d, (493, 18, 507, 36), "#14283d")
    for _ in range(44):
        x, y = rng.randrange(640), rng.randrange(8, 92)
        rect(d, (x, y, x + (1 if rng.random() < 0.3 else 0), y), "#6c9b98")
    # Three silhouette depths; light can travel through the central clearing.
    for layer, col, trunk, yy in ((0, "#1c3c4d", "#193246", 142),
                                  (1, "#23504f", "#203c46", 170)):
        for x in range(-22, 690, 44 if layer == 0 else 74):
            height = rng.randrange(56, 126)
            width = rng.randrange(26, 48)
            bx = x + rng.randrange(-8, 9)
            rect(d, (bx - 3, yy - height // 2, bx + 3, 208), trunk)
            for crown in range(3):
                cy = yy - height + crown * 19
                half = int(width * (0.55 + crown * 0.2))
                d.polygon([(bx, cy - 18), (bx + half, cy + 25),
                           (bx - half, cy + 25)], fill=col)
    # Near framing trees use broad rectangular boughs, not smooth brushes.
    for x, flip in ((25, 1), (603, -1)):
        rect(d, (x - 10, 4, x + 8, 208), "#172b35")
        rect(d, (x - 5, 25, x - 2, 191), "#2c4546")
        for yy in (42, 81, 116):
            extent = rng.randrange(30, 55)
            xx = x + extent * flip
            rect(d, (min(x, xx), yy, max(x, xx), yy + 7), "#172b35")
            for leaf in range(5):
                lx = xx + rng.randrange(-30, 28)
                ly = yy + rng.randrange(-24, 8)
                rect(d, (lx, ly, lx + 34, ly + 15), "#285149")
                rect(d, (lx + 4, ly, lx + 24, ly + 3), "#38675a")
    # Winding path and roots.
    d.polygon([(206, 196), (347, 192), (523, 239), (105, 239)], fill="#52625a")
    d.polygon([(220, 200), (342, 197), (471, 239), (152, 239)], fill="#637061")
    for _ in range(125):
        x, y = rng.randrange(640), rng.randrange(195, 239)
        col = rng.choice(("#547b59", "#3c654d", "#799467", "#233e3e"))
        rect(d, (x, y, x + rng.randrange(1, 5), y + 1), col)
    for x, y in ((88, 205), (145, 219), (550, 211), (585, 226), (388, 202)):
        rect(d, (x, y - 8, x + 1, y), "#bcc4a4")
        rect(d, (x - 3, y - 10, x + 4, y - 7), "#d5b36b")
        rect(d, (x - 1, y - 11, x + 2, y - 11), "#f6d78b")
    # A small hanging lantern anchors the original woodland identity.
    rect(d, (67, 88, 67, 114), "#779183")
    rect(d, (62, 113, 72, 128), "#263c42")
    rect(d, (64, 116, 70, 125), "#e7ae60")
    rect(d, (66, 117, 68, 123), "#ffdf91")
    for _ in range(19):
        x, y = rng.randrange(80, 580), rng.randrange(60, 180)
        rect(d, (x, y, x + 1, y + 1), "#b4c97e")
    im.save(OUT / "forest.png", optimize=False)


def icon():
    im = Image.new("RGBA", (64, 64), "#142436")
    d = ImageDraw.Draw(im)
    rect(d, (4, 4, 59, 59), "#284e4b")
    rect(d, (7, 7, 56, 56), "#172c3a")
    rect(d, (28, 11, 36, 18), "#9eb494")
    rect(d, (25, 15, 39, 19), "#9eb494")
    rect(d, (21, 19, 43, 42), "#466d62")
    rect(d, (25, 22, 39, 39), "#f0bd69")
    rect(d, (29, 24, 35, 35), "#ffe5a2")
    rect(d, (21, 40, 43, 45), "#adc29b")
    d.polygon([(32, 48), (17, 48), (12, 40), (22, 42)], fill="#74bb8c")
    d.polygon([(32, 48), (47, 48), (51, 38), (41, 40)], fill="#97d3a1")
    rect(d, (30, 45, 33, 53), "#74bb8c")
    im.save(OUT / "icon.png", optimize=False)


def triangle(phase: float) -> float:
    return 4.0 * abs((phase % 1.0) - 0.5) - 1.0


def sound(name: str, duration: float, notes: list[float]):
    rate = 22050
    rng = random.Random(SEED)
    samples = []
    for i in range(int(rate * duration)):
        t = i / rate
        if name == "attack":
            frequency = 500.0 - 330.0 * t / duration
            env = min(t / 0.008, 1.0) * max(0.0, 1.0 - t / duration) ** 2
            signal = triangle(frequency * t) * 0.65 + rng.uniform(-1, 1) * 0.35
        else:
            part = duration / len(notes)
            idx = min(int(t / part), len(notes) - 1)
            local = t - idx * part
            frequency = notes[idx]
            env = min(local / 0.009, 1.0) * max(0.0, 1.0 - local / part) ** 1.2
            signal = triangle(frequency * local) * 0.8 + math.sin(2 * math.pi * frequency * local) * 0.2
        samples.append(struct.pack("<h", int(32767 * 0.09 * env * signal)))
    with wave.open(str(OUT / f"{name}.wav"), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(b"".join(samples))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for kind in ("warrior", "archer", "mage", "healer"):
        save_sheet(kind, hero)
    for kind in ("dew_slime", "bark_mite", "lantern_moth", "root_guardian"):
        save_sheet(kind, enemy)
    background()
    icon()
    sound("attack", 0.11, [])
    sound("victory", 0.56, [523.25, 659.25, 783.99, 1046.50])
    manifest = {
        "generator": "tools/generate_assets.py",
        "seed": SEED,
        "license": "CC0-1.0",
        "sprite_frame_size": [24, 24],
        "sprite_frames": ["idle", "step", "attack", "recover"],
        "files": {},
    }
    for path in sorted(OUT.iterdir()):
        if path.suffix in (".png", ".wav"):
            manifest["files"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(manifest['files'])} original assets in {OUT}")


if __name__ == "__main__":
    main()
