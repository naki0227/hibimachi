"""Draws the app icon (1024x1024, no alpha) as 128x128 pixel art scaled up 8x.

Same direction as the in-game art (ADR-0004): code-drawn, isometric island, warm palette.
Run: python3 scripts/art/make_app_icon.py Hibimachi/Assets.xcassets/AppIcon.appiconset/icon-1024.png
"""
import sys

from PIL import Image, ImageDraw

N = 128
SKY_TOP = (150, 214, 236)
SKY_BOTTOM = (98, 178, 214)
SEA = (72, 160, 205)
GRASS = (122, 196, 92)
GRASS_DARK = (96, 170, 74)
CLIFF = (176, 120, 78)
CLIFF_DARK = (140, 92, 60)
PATH = (226, 200, 150)
ROOF = (222, 96, 72)
WALL = (250, 240, 220)
TRUNK = (128, 86, 56)
LEAF = (70, 150, 72)
WHITE = (255, 255, 255)
INK = (60, 50, 40)


def diamond(cx, cy, hw, hh):
    return [(cx, cy - hh), (cx + hw, cy), (cx, cy + hh), (cx - hw, cy)]


def main(path):
    img = Image.new("RGB", (N, N))
    d = ImageDraw.Draw(img)
    for y in range(N):
        t = y / (N - 1)
        color = tuple(round(a + (b - a) * t) for a, b in zip(SKY_TOP, SKY_BOTTOM))
        d.line([(0, y), (N, y)], fill=color)
    cx, cy, hw, hh, depth = 64, 70, 46, 23, 12
    # sea ring and cliff
    d.polygon(diamond(cx, cy + depth + 4, hw + 8, hh + 4), fill=SEA)
    d.polygon([(cx - hw, cy), (cx, cy + hh), (cx, cy + hh + depth), (cx - hw, cy + depth)], fill=CLIFF)
    d.polygon([(cx + hw, cy), (cx, cy + hh), (cx, cy + hh + depth), (cx + hw, cy + depth)], fill=CLIFF_DARK)
    # grass top with a checker of darker tufts and a path cross
    d.polygon(diamond(cx, cy, hw, hh), fill=GRASS)
    for i in range(-3, 4):
        for j in range(-3, 4):
            if (i + j) % 2 == 0:
                x, y = cx + (i - j) * 6, cy + (i + j) * 3
                d.point([(x, y), (x + 1, y)], fill=GRASS_DARK)
    d.line([(cx - 30, cy - 15), (cx + 30, cy + 15)], fill=PATH, width=4)
    d.line([(cx + 30, cy - 15), (cx - 30, cy + 15)], fill=PATH, width=4)
    # house (left)
    hx, hy = 40, 62
    d.rectangle([hx - 9, hy - 8, hx + 9, hy + 6], fill=WALL)
    d.polygon([(hx - 12, hy - 7), (hx, hy - 18), (hx + 12, hy - 7)], fill=ROOF)
    d.rectangle([hx - 2, hy - 1, hx + 2, hy + 6], fill=TRUNK)
    # tree (back right)
    tx, ty = 86, 50
    d.rectangle([tx - 1, ty, tx + 1, ty + 8], fill=TRUNK)
    d.ellipse([tx - 9, ty - 16, tx + 9, ty + 2], fill=LEAF)
    d.ellipse([tx - 5, ty - 14, tx + 1, ty - 9], fill=GRASS)
    # creature (white round, front)
    kx, ky = 70, 78
    d.ellipse([kx - 8, ky - 7, kx + 8, ky + 5], fill=WHITE)
    d.point([(kx - 3, ky - 2), (kx + 3, ky - 2)], fill=INK)
    d.point([(kx - 1, ky + 1), (kx, ky + 1)], fill=ROOF)
    img.resize((1024, 1024), Image.NEAREST).save(path)


if __name__ == "__main__":
    main(sys.argv[1])
