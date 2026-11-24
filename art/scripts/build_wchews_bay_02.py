# W Chews' meat display bay, version 02 (user 2026-11-23: "can you remove these words", then "Yes, both": the YOUR MEAT
# words AND the dark bar they sat on). It replaces WChewsKit_01's WcBay: the same item and piece names, so it is listed
# AFTER WChewsKit_01 in StarterGymConfig.PropAssets (a later asset's item wins).
#
# The same bay as build_wchews_kit_01.py's (a steel tray, four posts, top rails on the front and both sides, glass on the
# front and both sides, light strips under the rails; the back open, where the grinder's outlet pours in) WITHOUT the
# sign: no backing bar, no little posts under it, no words.
#
# One item, WcBay, round its own origin, standing on z = 0, its front toward -Y. 26 x 26.
#
#   blender -b --factory-startup --python art/scripts/build_wchews_bay_02.py -- <out.blend> [<out.glb>]

import json
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, r"D:\Powerlifting Roblox\art\scripts")
import importlib  # noqa: E402

import prop_helpers as H  # noqa: E402

importlib.reload(H)

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

B = H.Builder("WChewsBay")
V = Vector

STEEL = H.material("Wc_Steel", (0.80, 0.82, 0.85), metallic=0.9, roughness=0.28)
STEEL_DARK = H.material("Wc_SteelDark", (0.42, 0.44, 0.48), metallic=0.85, roughness=0.35)
GLASS = H.material("Wc_Glass", (0.62, 0.80, 0.88), metallic=0.2, roughness=0.1, alpha=0.3)
GLOW_WHITE = H.material("Wc_GlowWhite", (1.0, 0.98, 0.94), emission=(1.0, 0.97, 0.9))

BH = 13.0  # half the bay's width
POST_H = 12.0


def bay_tray(bm):
    H.span(bm, (-BH, -BH, 0.0), (BH, BH, 0.3))
    H.span(bm, (-BH, -BH, 0.3), (BH, -BH + 0.7, 1.6))
    H.span(bm, (-BH, BH - 0.7, 0.3), (BH, BH, 1.6))
    H.span(bm, (-BH, -BH + 0.7, 0.3), (-BH + 0.7, BH - 0.7, 1.6))
    H.span(bm, (BH - 0.7, -BH + 0.7, 0.3), (BH, BH - 0.7, 1.6))


def bay_frame(bm):
    for sx in (-1, 1):
        for sy in (-1, 1):
            H.box(bm, V((sx * (BH - 0.35), sy * (BH - 0.35), POST_H / 2)), (0.7, 0.7, POST_H))
    # Top rails on the front and both sides; none at the back, where the grinder's outlet comes in.
    H.box(bm, V((0, -(BH - 0.35), POST_H - 0.3)), (2 * BH, 0.7, 0.6))
    for s in (-1, 1):
        H.box(bm, V((s * (BH - 0.35), 0, POST_H - 0.3)), (0.7, 2 * BH, 0.6))
    # (version 01's sign backing bar and its two little posts are gone)


def bay_glass(bm):
    # Glass on the front and both sides (the back is open: the grinder's outlet pours in there).
    H.span(bm, (-BH + 0.7, -BH + 0.25, 1.6), (BH - 0.7, -BH + 0.4, 8.0))
    H.span(bm, (-BH + 0.25, -BH + 0.7, 1.6), (-BH + 0.4, BH - 0.7, 8.0))
    H.span(bm, (BH - 0.4, -BH + 0.7, 1.6), (BH - 0.25, BH - 0.7, 8.0))


def bay_lights(bm):
    H.box(bm, V((0, -(BH - 0.9), POST_H - 0.68)), (2 * BH - 3, 0.4, 0.16))
    for s in (-1, 1):
        H.box(bm, V((s * (BH - 0.9), 0, POST_H - 0.68)), (0.4, 2 * BH - 3, 0.16))


B.piece("WcBay_Tray", STEEL, bay_tray, smooth=False)
B.piece("WcBay_Frame", STEEL_DARK, bay_frame, smooth=False)
B.piece("WcBay_Glass", GLASS, bay_glass, smooth=False)
B.piece("WcBay_Lights", GLOW_WHITE, bay_lights, smooth=False)

bpy.context.view_layer.update()
lo = V((1e9, 1e9, 1e9))
hi = -lo
for ob in B.coll.objects:
    for corner in ob.bound_box:
        w = ob.matrix_world @ V(corner)
        lo = V(map(min, lo, w))
        hi = V(map(max, hi, w))
bounds = {"WcBay": {"low": [round(v, 4) for v in lo], "high": [round(v, 4) for v in hi]}}

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if argv:
    bpy.ops.wm.save_as_mainfile(filepath=argv[0])
    with open(argv[0].replace(".blend", "_bounds.json"), "w", encoding="utf-8") as handle:
        json.dump(bounds, handle, indent=1)
if len(argv) >= 2:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in B.coll.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=argv[1], export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
tris = sum(len(p.vertices) - 2 for o in B.coll.objects for p in o.data.polygons)
print("WCHEWS BAY BUILT:", len(B.coll.objects), "objects,", tris, "triangles; bounds", bounds)
