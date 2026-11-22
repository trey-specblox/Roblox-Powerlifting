# Puts the crew-neck long sleeves (build_cartoon_gear_05.py GEAR05_ITEMS=LongSleeve, tee_neck_fix.py; user 2026-11-20:
# "they have no neck, and their shirts are covering almost to their chin") into art/blender/CartoonGear_05_Knee100.blend
# in place of the old ones, on the same rigs; nothing else in the file changes.
#   blender -b art/blender/CartoonGear_05_Knee100.blend --python art/scripts/swap_longsleeve_neck.py -- <longsleeve.blend>
import sys

import bpy

SRC = sys.argv[sys.argv.index("--") + 1]
ORDER = ("Skinny", "SkinnyFat", "Fat", "Fit", "Muscular", "BigBuff")


def is_ls(name):
    return any(name.startswith(b + "_LongSleeve__") or name.startswith(b + "_LongSleeveWhite__") for b in ORDER)


old = [o for o in bpy.data.objects if o.type == "MESH" and is_ls(o.name)]
colls = {o.name: [c for c in o.users_collection] for o in old}
for o in old:
    me = o.data
    bpy.data.objects.remove(o, do_unlink=True)
    if me.users == 0:
        bpy.data.meshes.remove(me)
print("[SwapLS] old long-sleeve pieces taken out:", len(old))

with bpy.data.libraries.load(SRC, link=False) as (src, dst):
    dst.objects = [n for n in src.objects if is_ls(n)] + [b + "Rig" for b in ORDER]
src_rigs = {o.name.split(".")[0]: o for o in dst.objects if o is not None and o.type == "ARMATURE"}
brought = 0
for o in dst.objects:
    if o is None or o.type != "MESH":
        continue
    b = next(b for b in ORDER if o.name.startswith(b + "_"))
    rig = bpy.data.objects[b + "Rig"]
    src_rig = o.parent if (o.parent is not None and o.parent.type == "ARMATURE") else src_rigs[b + "Rig"]
    for bone in src_rig.data.bones:
        assert (bone.head_local - rig.data.bones[bone.name].head_local).length < 1e-4, "rigs differ: " + bone.name
    local = src_rig.matrix_world.inverted() @ o.matrix_world
    for m in o.modifiers:
        if m.type == "ARMATURE":
            m.object = rig
    o.parent = rig
    o.matrix_world = rig.matrix_world @ local
    target = colls.get(o.name) or [rig.users_collection[0]]
    for c in target:
        c.objects.link(o)
    brought += 1
for r in src_rigs.values():
    bpy.data.objects.remove(r, do_unlink=True)
print("[SwapLS] crew-neck long-sleeve pieces brought in:", brought)
if brought != len(old):
    print("[SwapLS] (piece counts differ: %d old, %d new - the colour split moved with the neck)" % (len(old), brought))
bpy.ops.wm.save_mainfile()
print("[SwapLS] saved", bpy.data.filepath)
