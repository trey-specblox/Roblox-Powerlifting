"""Writes the game's copy of W Chews' layout: src/shared/Config/WChewsLayout.luau, from art/scripts/wchews_layout.py
and the kit's bounds (art/blender/WChewsKit_01_bounds.json, written by build_wchews_kit_01.py).

    python art/scripts/write_wchews_layout.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import wchews_layout  # noqa: E402

bounds = json.loads((ROOT / "art" / "blender" / "WChewsKit_01_bounds.json").read_text(encoding="utf-8"))
missing = sorted({p[0] for p in wchews_layout.PLACEMENTS} - set(bounds))
if missing:
    sys.exit(f"The layout uses items the kit doesn't have: {missing}")
out = ROOT / "src" / "shared" / "Config" / "WChewsLayout.luau"
wchews_layout.write_luau(out, bounds)
print(f"wrote {out} ({len(wchews_layout.PLACEMENTS)} placements, {len(bounds)} items)")
