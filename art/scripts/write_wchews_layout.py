"""Writes the game's copy of W Chews' layout: src/shared/Config/WChewsLayout.luau, from art/scripts/wchews_layout.py
and the kits' bounds (art/blender/WChewsKit_01_bounds.json, WChewsBack_01_bounds.json and WChewsDoor_01_bounds.json,
written by build_wchews_kit_01.py, build_wchews_back_01.py and build_wchews_door_01.py).

    python art/scripts/write_wchews_layout.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import wchews_layout  # noqa: E402

bounds = json.loads((ROOT / "art" / "blender" / "WChewsKit_01_bounds.json").read_text(encoding="utf-8"))
bounds.update(json.loads((ROOT / "art" / "blender" / "WChewsBack_01_bounds.json").read_text(encoding="utf-8")))
bounds.update(json.loads((ROOT / "art" / "blender" / "WChewsDoor_01_bounds.json").read_text(encoding="utf-8")))
# The mafia boss cow is one item of its own file (build_wchews_cow_boss_01.py): its bounds, for its pivot offset.
cow = json.loads((ROOT / "art" / "blender" / "WChewsCowBoss_01_bounds.json").read_text(encoding="utf-8"))
bounds["CowBoss"] = {"low": cow["low"], "high": cow["high"]}
wchews_layout.COW_NECK = tuple(cow["neck"])
wchews_layout.COW_SHOULDER = tuple(cow["shoulder"])
missing = sorted({p[0] for p in wchews_layout.PLACEMENTS} - set(bounds))
if missing:
    sys.exit(f"The layout uses items the kit doesn't have: {missing}")
out = ROOT / "src" / "shared" / "Config" / "WChewsLayout.luau"
wchews_layout.write_luau(out, bounds)
print(f"wrote {out} ({len(wchews_layout.PLACEMENTS)} placements, {len(bounds)} items)")
