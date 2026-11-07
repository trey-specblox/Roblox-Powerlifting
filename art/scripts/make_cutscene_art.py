"""Draws the sharp comic-style pieces of the coach's cutscene dialogue from scratch, so they are our own work (user's reference,
2026-11-06: an angular panel behind a big portrait of who is talking, angular speech tabs beside it; the shapes and colours here
are ours, in the game's yellow).

    uv run --no-project --with pillow python art/scripts/make_cutscene_art.py

Writes art/ui/Cutscene_Bubble.png (a black speech tab with a white edge, its tail to the lower left, for an answer) and
art/ui/Cutscene_Panel.png (a see-through dark panel down the left of the screen, its right edge cut into yellow and white
shards, for the portrait to stand on). Transparent backgrounds. Drawn at 4x and scaled down, so the edges are clean. Upload with
art/scripts/upload_group_images.py.
"""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "ui"
SCALE = 4
YELLOW = (250, 206, 36, 255)
WHITE = (250, 250, 246, 255)
BLACK = (10, 10, 12, 255)
SHADE = (8, 9, 14, 165)
STRIPE = (255, 255, 255, 16)
# Where the panel's dark part ends, down its right edge.
PANEL = [(0.0, 0.0), (0.60, 0.0), (0.50, 0.40), (0.56, 0.38), (0.44, 1.0), (0.0, 1.0)]


def scaled(points, width, height):
    return [(x * width * SCALE, y * height * SCALE) for x, y in points]


def draw(name, size, shapes):
    width, height = size
    image = Image.new("RGBA", (width * SCALE, height * SCALE), (0, 0, 0, 0))
    pen = ImageDraw.Draw(image)
    for colour, points in shapes:
        pen.polygon(scaled(points, width, height), fill=colour)
    image.resize(size, Image.LANCZOS).save(OUT / name)
    print("wrote", OUT / name)


def draw_panel(name, size):
    width, height = size
    full = (width * SCALE, height * SCALE)
    # The dark panel with thin diagonal stripes, cut to its shape.
    shade = Image.new("RGBA", full, SHADE)
    stripes = ImageDraw.Draw(shade, "RGBA")
    for x in range(-full[1], full[0], 26 * SCALE):
        stripes.line([(x, full[1]), (x + full[1] * 0.45, 0)], fill=STRIPE, width=2 * SCALE)
    mask = Image.new("L", full, 0)
    ImageDraw.Draw(mask).polygon(scaled(PANEL, width, height), fill=255)
    image = Image.new("RGBA", full, (0, 0, 0, 0))
    image.paste(shade, (0, 0), mask)
    # The shards: each a black shape with its colour inside.
    pen = ImageDraw.Draw(image)
    shards = [
        # Down the panel's edge.
        (BLACK, [(0.58, 0.0), (0.73, 0.0), (0.615, 0.37), (0.68, 0.34), (0.545, 1.0), (0.42, 1.0), (0.535, 0.43), (0.475, 0.455)]),
        (WHITE, [(0.60, 0.0), (0.71, 0.0), (0.59, 0.395), (0.655, 0.37), (0.525, 1.0), (0.445, 1.0), (0.555, 0.40), (0.50, 0.42)]),
        # A yellow blade along the top of it, and one low down.
        (BLACK, [(0.75, 0.0), (0.90, 0.0), (0.68, 0.30), (0.655, 0.20)]),
        (YELLOW, [(0.77, 0.0), (0.875, 0.0), (0.695, 0.25), (0.675, 0.19)]),
        (BLACK, [(0.56, 0.62), (0.63, 0.56), (0.58, 1.0), (0.525, 1.0)]),
        (YELLOW, [(0.57, 0.655), (0.615, 0.60), (0.57, 1.0), (0.54, 1.0)]),
        # Big yellow shards in the lower left corner, behind the portrait.
        (BLACK, [(0.0, 0.40), (0.26, 1.0), (0.0, 1.0)]),
        (YELLOW, [(0.0, 0.45), (0.225, 1.0), (0.0, 1.0)]),
        (BLACK, [(0.0, 0.14), (0.085, 0.42), (0.0, 0.36)]),
        (YELLOW, [(0.0, 0.18), (0.065, 0.395), (0.0, 0.345)]),
    ]
    for colour, points in shards:
        pen.polygon(scaled(points, width, height), fill=colour)
    image.resize(size, Image.LANCZOS).save(OUT / name)
    print("wrote", OUT / name)


def main():
    OUT.mkdir(exist_ok=True)
    draw("Cutscene_Bubble.png", (1024, 400), [
        (WHITE, [(0.015, 0.95), (0.19, 0.60), (0.125, 0.07), (0.84, 0.0), (1.0, 0.90), (0.25, 0.80)]),
        (BLACK, [(0.085, 0.87), (0.225, 0.59), (0.17, 0.135), (0.815, 0.075), (0.95, 0.825), (0.235, 0.735)]),
    ])
    draw_panel("Cutscene_Panel.png", (1000, 1000))


if __name__ == "__main__":
    main()
