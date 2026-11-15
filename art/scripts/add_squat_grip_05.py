# Adds the SquatGrip swap hand (build_cartoon_hands_04.py: the squat's thumbless grip, bar in the palm heel; user
# 2026-11-14 "Bar in palm heel") to every build of art/blender/CartoonBodies_05_Rigged.blend, placed exactly like the
# other swaps (build_cartoon_rig_05.swap_hands): "<Build>_SquatGrip<Side>" on each hand bone in "SwapHands05", hidden,
# with its "grip_point" (where the bar's centre sits, rest pose, rig space). A full rebuild (build_cartoon_rig_05.py)
# makes the same objects; this only adds them without remaking the weights. Run again: replaces the SquatGrip objects.
#   blender -b art/blender/CartoonBodies_05_Rigged.blend --python art/scripts/add_squat_grip_05.py
import os

import bpy
from mathutils import Matrix, Vector

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
B = {"__name__": "body05_lib", "BODY05_AS_LIBRARY": True}
exec(open(os.path.join(SCRIPTS, "build_cartoon_body_05.py")).read(), B)
L = B["L"]
HL = B["load_hands"]()
SHAPE = "SquatGrip"

coll = bpy.data.collections.get("SwapHands05")
assert coll is not None, "SwapHands05 missing: is this CartoonBodies_05_Rigged.blend?"
for o in [o for o in bpy.data.objects if ("_" + SHAPE) in o.name]:
    bpy.data.objects.remove(o, do_unlink=True)
src = HL["make_hand"](SHAPE, coll, name="Hand04_" + SHAPE)
folds = src["folds_smoothed"]
made = []
for build in B["ORDER"]:
    rig = bpy.data.objects.get(build + "Rig")
    assert rig is not None, build + "Rig missing"
    spec = B["body_spec"](build)
    for side in ("Left", "Right"):
        o = B["place_hand"](src.data, side, spec, "%s_%s%s" % (build, SHAPE, side), coll)
        bpy.context.view_layer.update()
        o.matrix_world = rig.matrix_world.copy()
        bpy.context.view_layer.update()
        mw = o.matrix_world.copy()
        o.parent, o.parent_type, o.parent_bone = rig, "BONE", side + "Hand"
        bpy.context.view_layer.update()
        o.matrix_world = mw
        o.hide_render = True
        o.hide_set(True)
        sx = 1 if side == "Left" else -1
        m = Matrix.Translation(Vector((sx * spec["arm_x"], 0, L["WR"]))) @ B["hand_space"](side, spec["hand"])
        o["grip_point"] = list(m @ Vector(HL["HEEL_C"]))
        made.append(o)
bpy.data.objects.remove(src, do_unlink=True)
bpy.data.orphans_purge(do_recursive=True)
tris = sum(len(p.vertices) - 2 for p in made[0].data.polygons)
print("[SquatGrip05] added", len(made), "hands,", tris, "triangles each; folded edges smoothed", folds)
bpy.ops.wm.save_mainfile()
print("[SquatGrip05] saved", bpy.data.filepath)
