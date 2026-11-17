# Exports gear v8 = gear v7 on the LONGER-LEGGED bodies (knee 1.00, user 2026-11-15), read-only on both .blend files.
# Same as export_cartoon_07.py, but the base is the v5 items refitted to the new legs (build_cartoon_gear_05.py re-run on
# the new CartoonBodies_05_Rigged: art/blender/CartoonGear_05_Knee100.blend), and the files are numbered 08:
#   art/exports/CartoonGear08_<Build>.glb, art/exports/CartoonClothes08_<Build>.glb
#   blender -b art/blender/CartoonGear_05_Knee100.blend --python art/scripts/export_cartoon_08.py
# (v7's notes follow.)
# Gear v7 (art/scripts/build_cartoon_gear_07.py, art/blender/CartoonGear_07.blend): the singlet redesigned from the
# user's reference, the knee sleeves rebuilt on the skin (whole in the deep squat), the tee and the approved rigid belt
# as v6. Every other item stays as uploaded in v5 (art/blender/CartoonGear_05.blend: suits, bench shirt, knee wraps,
# wrist wraps, the other clothes). This opens the v5 file, swaps those four items for the v7 ones (same names apart
# from the sleeves' part: one piece per leg under "<Side>LowerLeg"; same rig), and writes:
#   art/exports/CartoonGear07_<Build>.glb     the rig + every worn gear piece, "<Worn>_<ColourKey>__<Part>"
#   art/exports/CartoonClothes07_<Build>.glb  the rig + every clothes piece, "<Item>__<Part>"
# The bodies and the swap hands did not change (CartoonBody05_* / CartoonHands05 stay as uploaded).
# TeeUnder (v5's cut tee for under a singlet) is left out: the game wears the WHOLE tee under gear (ClothesConfig,
# user 2026-11-16) and no code reads TeeUnder.
#   blender -b art/blender/CartoonGear_05.blend --python art/scripts/export_cartoon_07.py
import os

import bpy

ROOT = r"D:\Powerlifting Roblox"
EXPORTS = os.environ.get("GEAR08_EXPORTS") or os.path.join(ROOT, "art", "exports")   # (env: a trial elsewhere)
V6_BLEND = os.environ.get("GEAR08_V7_BLEND") or os.path.join(ROOT, "art", "blender", "CartoonGear_07.blend")
E5 = os.path.join(ROOT, "art", "scripts", "export_cartoon_05.py")
ORDER = ("Skinny", "SkinnyFat", "Fat", "Fit", "Muscular", "BigBuff")
V6_HEADS = ("Tee", "TeeWhite")                       # clothes items replaced by v6
V6_GEAR = ("WornSinglet_", "WornLeverBelt_", "WornKneeSleeve_")   # gear items replaced by v7
DROPPED = ("TeeUnder", "TeeUnderWhite")
NUM = os.environ.get("GEAR_EXPORT_NUM", "09")       # the files' number: 09 = the rounded-U neckline + centring fix
                                                     # (2026-11-16, user "Looks good, upload"); 08 = the first knee-1.00 set
CENTRE_LIMIT = 0.6                                   # every exported piece's centre within this (x) of its body part's


def log(*a):
    print("[Export08]", *a, flush=True)


# the v5 export's helpers (point_bones_up, export_glb, CLOTHES ...) without running its export
src = open(E5).read().split("\nbpy.context.view_layer.update()\nfor o in bpy.data.objects:")[0]
E = {"__name__": "export05_lib"}
exec(src, E)


def head_of(o, b):
    return o.name[len(b) + 1:].split("__")[0]


def replaced(o, b):
    h = head_of(o, b)
    return h in V6_HEADS or h in DROPPED or h.startswith(V6_GEAR)


# 1) take the v5 pieces of the replaced items out (in memory only)
gone = 0
for b in ORDER:
    for o in [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(b + "_") and "__" in o.name]:
        if replaced(o, b):
            me = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if me.users == 0:
                bpy.data.meshes.remove(me)
            gone += 1
log("v5 pieces of the replaced items taken out:", gone)

# 2) bring the v6 pieces in and put them on this file's rigs (checked to be the same rigs first)
with bpy.data.libraries.load(V6_BLEND, link=False) as (src_data, dst_data):
    want = [n for n in src_data.objects if any(n.startswith(b + "_") for b in ORDER) and "__" in n]
    dst_data.objects = want
coll = bpy.context.scene.collection
brought = 0
extra_rigs = set()
for o in dst_data.objects:
    if o is None:
        continue
    b = next(b for b in ORDER if o.name.startswith(b + "_"))
    if not replaced(o, b):
        bpy.data.objects.remove(o, do_unlink=True)
        continue
    rig = bpy.data.objects[b + "Rig"]
    # the piece's place in ITS OWN rig's space, carried over to this file's rig (2026-11-16 fix: the world matrix was
    # kept, so every build but the first kept the v7 file's side-by-side offset: the tee and gear floated 4.6 x the
    # build's index studs off the body in the 08 uploads)
    src_rig = o.parent if (o.parent is not None and o.parent.type == "ARMATURE") else None
    for m in o.modifiers:
        if m.type == "ARMATURE":
            if m.object is not None and m.object is not rig:
                extra_rigs.add(m.object)
                src_rig = src_rig or m.object
            m.object = rig
    if o.parent is not None and o.parent is not rig:
        extra_rigs.add(o.parent)
    assert src_rig is not None, "%s: no rig to place it by" % o.name
    local = src_rig.matrix_world.inverted() @ o.matrix_world
    o.parent = rig
    o.matrix_world = rig.matrix_world @ local
    coll.objects.link(o)
    brought += 1
for r in extra_rigs:
    b = next(b for b in ORDER if r.name.startswith(b + "Rig"))
    mine = bpy.data.objects[b + "Rig"]
    for bone in r.data.bones:
        d = (bone.head_local - mine.data.bones[bone.name].head_local).length
        assert d < 1e-4, "%s: bone %s differs by %.5f between the v5 and v6 rigs" % (b, bone.name, d)
    bpy.data.objects.remove(r, do_unlink=True)
log("v6 pieces brought in:", brought, "(rigs checked identical:", len(extra_rigs), ")")
assert brought > 0

# 3) export gear + clothes per build (as export_cartoon_05.py does)
bpy.context.view_layer.update()
for o in bpy.data.objects:
    o.hide_set(False)
    o.hide_viewport = False
for b in ORDER:
    E["point_bones_up"](bpy.data.objects[b + "Rig"])
for b in ORDER:
    rig = bpy.data.objects[b + "Rig"]
    saved_loc = rig.location.copy()
    rig.location = (0, 0, 0)
    bpy.context.view_layer.update()
    gear, clothes = {}, {}
    for o in bpy.data.objects:
        if o.type != "MESH" or not o.name.startswith(b + "_") or "__" not in o.name:
            continue
        name = o.name[len(b) + 1:]
        head = name.split("__")[0]
        if head.startswith("Worn"):
            gear[o] = name
        elif head in E["CLOTHES"]:
            clothes[o] = name
        else:
            log("NOT EXPORTED (unknown piece)", o.name)
    # every piece centred on the body part it's worn on (the "__<Part>" in its name) before anything is written
    from mathutils import Vector
    def cx(o):
        return sum((o.matrix_world @ Vector(c)).x for c in o.bound_box) / 8
    off = []
    for o in list(gear) + list(clothes):
        part = bpy.data.objects[b + "_" + o.name.split("__")[-1]]
        if abs(cx(o) - cx(part)) > CENTRE_LIMIT:
            off.append("%s %+.2f" % (o.name, cx(o) - cx(part)))
    assert not off, "%s: pieces off their body part (x): %s" % (b, off[:12])
    log(b, "centring check passed:", len(gear) + len(clothes), "pieces within %.1f of their body part" % CENTRE_LIMIT)
    E["export_glb"](os.path.join(EXPORTS, "CartoonGear%s_%s.glb" % (NUM, b)), rig, list(gear), gear)
    E["export_glb"](os.path.join(EXPORTS, "CartoonClothes%s_%s.glb" % (NUM, b)), rig, list(clothes), clothes)
    heads = sorted({n.split("__")[0] for n in list(gear.values()) + list(clothes.values())})
    log(b, "items:", heads)
    rig.location = saved_loc
    bpy.context.view_layer.update()
log("done")
