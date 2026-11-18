"""Joins per-item preview tiles (<Item>_front.png and <Item>_back.png, as build_nationals_arena_02.py renders them)
into labelled contact sheets, three items to a sheet, so every model can be checked close up from both sides.

    python -I art/scripts/make_preview_sheets.py <tiles folder> <output folder>

Writes items_1.png, items_2.png, ... into the output folder. Needs Pillow.
"""
import os
import sys

from PIL import Image, ImageDraw

TILE_W, TILE_H, PER_SHEET = 640, 420, 3

tiles, out = sys.argv[1], sys.argv[2]
names = sorted({f.rsplit("_", 1)[0] for f in os.listdir(tiles) if f.endswith(".png")},
               key=lambda n: os.path.getmtime(os.path.join(tiles, n + "_front.png")))
for s in range(0, len(names), PER_SHEET):
    group = names[s:s + PER_SHEET]
    sheet = Image.new("RGB", (TILE_W * 2, TILE_H * len(group)), (40, 40, 40))
    draw = ImageDraw.Draw(sheet)
    for i, name in enumerate(group):
        for j, view in enumerate(("front", "back")):
            tile = Image.open(os.path.join(tiles, f"{name}_{view}.png")).convert("RGB")
            sheet.paste(tile, (j * TILE_W, i * TILE_H))
            draw.rectangle((j * TILE_W, i * TILE_H, j * TILE_W + 230, i * TILE_H + 20), fill=(0, 0, 0))
            draw.text((j * TILE_W + 4, i * TILE_H + 4), f"{name} ({view})", fill=(255, 220, 0))
    sheet.save(os.path.join(out, f"items_{s // PER_SHEET + 1}.png"))
    print("sheet", s // PER_SHEET + 1, group)
