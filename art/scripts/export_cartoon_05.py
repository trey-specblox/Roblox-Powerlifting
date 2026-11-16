# Exports the production cartoon lifters for the game (Phase 4, user 2026-11-15 "Yes, upload them"), read-only on the
# .blend (it is NOT saved): from art/blender/CartoonGear_05.blend (the six CartoonBodies_05 bodies, rigs, swap hands,
# gear v5 and clothes v5, all on one rig per build):
#   art/exports/CartoonBody05_<Build>.glb     the rig + the 14 skinned R15 parts (the OPEN hand is the body's own hand)
#   art/exports/CartoonGear05_<Build>.glb     the rig + the worn gear pieces, "<Worn>_<ColourKey>__<Part>"
#   art/exports/CartoonClothes05_<Build>.glb  the rig + the clothes pieces, "<Item>__<Part>" (TeeUnder = the tee under a
#                                             singlet)
#   art/exports/CartoonHands05.glb            the swap hands (Fist, Point, ThumbsUp, Grip, SquatGrip) x Left/Right, rigid,
#                                             at hand size 1, in the hand bone's space
#   art/exports/CartoonExport05.json          what the game config needs: per build the joints, the neck mark, the
#                                             hand size, each swap hand's offset from the body's hand part, the squat
#                                             bar rest and bench clearance (UpperTorso space); per shape its size
#   blender -b art/blender/CartoonGear_05.blend --python art/scripts/export_cartoon_05.py
# Like build_cartoon_rig_02.export (the bodies the game ran): every bone is pointed straight up before export (the game's
# rig is axis-aligned; only the joint positions are read), each rig at the origin, mesh objects named exactly as the game
# reads them. No images in the GLBs (the CENTRAL logo is its own upload, a tinted Decal).
import json
import os

import bpy
from mathutils import Vector

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
EXPORTS = os.path.join(ROOT, "art", "exports")
B5 = {"__name__": "body05_lib", "BODY05_AS_LIBRARY": True}
exec(open(os.path.join(SCRIPTS, "build_cartoon_body_05.py")).read(), B5)
L, ORDER = B5["L"], B5["ORDER"]
PARTS = ["LowerTorso", "UpperTorso"] + [s + p for s in ("Left", "Right") for p in
                                         ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")]
SHAPES = ("Fist", "Point", "ThumbsUp", "Grip", "SquatGrip")
CLOTHES = ("Tee", "TeeWhite", "TeeUnder", "TeeUnderWhite", "LongSleeve", "LongSleeveWhite", "Tank", "Shorts",
           "ShortsWhite", "Joggers", "JoggersWhite", "Sneakers", "SneakersSole")
# Character Animation Quality.md §4.1b (2026-11-13): the squat bar's centre behind the spine, measured on each body's
# own back with the arms up, and each hand's grip from the centre (the data for the game's per-build hold)
SQUAT_BAR_BEHIND_SPINE = {"Skinny": 0.51, "SkinnyFat": 0.52, "Fit": 0.64, "Fat": 0.85, "Muscular": 0.93,
                          "BigBuff": 1.08}
SQUAT_GRIP = {"Skinny": 1.55, "SkinnyFat": 1.66, "Fit": 1.87, "Fat": 2.05, "Muscular": 2.17, "BigBuff": 2.35}
BAR_RADIUS, FABRIC = 0.07, 0.07        # (as ClothesConfig: the bar's radius, the tee + singlet over the chest)


def log(*a):
    print("[Export05]", *a, flush=True)


def rbx(v):
    """Blender (front -Y) to Roblox (front -Z, after the importer's half turn)."""
    return [round(-v.x, 4), round(v.z, 4), round(v.y, 4)]


def rig_points(o, rig):
    m = rig.matrix_world.inverted() @ o.matrix_world
    return [m @ v.co for v in o.data.vertices]


def bbox(points):
    lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return lo, hi


def tris(objs):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)


def point_bones_up(rig):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for b in rig.data.edit_bones:
        b.tail = b.head + Vector((0, 0, 0.25))
        b.roll = 0
    bpy.ops.object.mode_set(mode="OBJECT")


def export_glb(path, rig, objs, names, skins=True):
    """Selects rig + objs, renames each to names[obj] for the file, exports, puts the names back."""
    saved = {o: (o.name, o.data.name) for o in objs}
    for o in objs:                      # two passes: a wanted name may be held by another build's object
        o.name, o.data.name = "~" + saved[o][0], "~" + saved[o][1]
    for o in objs:
        o.name = o.data.name = names[o]
    bpy.ops.object.select_all(action="DESELECT")
    if rig:
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
    for o in objs:
        o.select_set(True)
    if not rig:
        bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_yup=True,
                              export_skins=skins, export_animations=False, export_morph=False,
                              export_image_format="NONE")
    for o in objs:
        o.name, o.data.name = "~~" + saved[o][0], "~~" + saved[o][1]
    for o in objs:
        o.name, o.data.name = saved[o]
    log("exported", os.path.basename(path), len(objs), "objects", tris(objs), "triangles")


bpy.context.view_layer.update()
for o in bpy.data.objects:                       # (hidden objects can't be selected for export)
    o.hide_set(False)
    o.hide_viewport = False
# The swap hands ride their hand BONE (bone parents): pointing the bones up would swing them round, so their rest
# places (rig space) are read first.
SWAP_PTS = {}
for b in ORDER:
    rig = bpy.data.objects[b + "Rig"]
    for shape in SHAPES:
        for side in ("Left", "Right"):
            SWAP_PTS[(b, shape, side)] = rig_points(bpy.data.objects["%s_%s%s" % (b, shape, side)], rig)
for b in ORDER:
    point_bones_up(bpy.data.objects[b + "Rig"])

info = {"builds": {}, "shapes": {}, "about": "art/scripts/export_cartoon_05.py: Roblox axes (x = -Blender x, y = up, "
        "z = Blender y = toward the back); offsets/marks in each part's own space at rest (the part's centre = its box "
        "centre, as Roblox recentres a mesh)."}
for b in ORDER:
    rig = bpy.data.objects[b + "Rig"]
    saved_loc = rig.location.copy()
    rig.location = (0, 0, 0)
    bpy.context.view_layer.update()
    parts = {p: bpy.data.objects["%s_%s" % (b, p)] for p in PARTS}
    centre = {}
    for p, o in parts.items():
        lo, hi = bbox(rig_points(o, rig))
        centre[p] = (lo + hi) / 2
    spec = B5["body_spec"](b)
    size = spec["hand"]
    up = rig_points(parts["UpperTorso"], rig)
    cu = centre["UpperTorso"]
    # the chest's front: the UpperTorso's most forward point over the chest (between the armpits' height and the neck)
    chest = [p for p in up if abs(p.x) < 0.6 and L["SH"] - 0.9 < p.z < L["SH"] - 0.1]
    front = min(p.y for p in chest)
    row = {
        "joints": {bone.name: rbx(bone.head_local) for bone in rig.data.bones},
        "neckMark": rbx(Vector((0, 0, L["N"])) - cu),
        "handSize": round(size, 4),
        "squatBarRest": round(SQUAT_BAR_BEHIND_SPINE[b] - cu.y, 3),
        "squatGrip": SQUAT_GRIP[b],
        "benchBarClear": round((cu.y - front) + BAR_RADIUS + FABRIC, 3),
        "handOffsets": {},
        "triangles": tris(parts.values()),
    }
    for shape in SHAPES:
        for side in ("Left", "Right"):
            lo, hi = bbox(SWAP_PTS[(b, shape, side)])
            row["handOffsets"]["%s_%s" % (shape, side)] = rbx((lo + hi) / 2 - centre[side + "Hand"])
    info["builds"][b] = row
    export_glb(os.path.join(EXPORTS, "CartoonBody05_%s.glb" % b), rig, list(parts.values()),
               {o: p for p, o in parts.items()})
    gear, clothes = {}, {}
    for o in bpy.data.objects:
        if o.type != "MESH" or not o.name.startswith(b + "_") or "__" not in o.name:
            continue
        name = o.name[len(b) + 1:]
        head = name.split("__")[0]
        if head.startswith("Worn"):
            gear[o] = name
        elif head in CLOTHES:
            clothes[o] = name
        else:
            log("NOT EXPORTED (unknown piece)", o.name)
    export_glb(os.path.join(EXPORTS, "CartoonGear05_%s.glb" % b), rig, list(gear), gear)
    export_glb(os.path.join(EXPORTS, "CartoonClothes05_%s.glb" % b), rig, list(clothes), clothes)
    row["gearPieces"], row["clothesPieces"] = len(gear), len(clothes)
    rig.location = saved_loc
    bpy.context.view_layer.update()
    log(b, {k: v for k, v in row.items() if k not in ("joints", "handOffsets")})

# the swap hands at hand size 1 in the hand bone's space (Fit's, scaled back: place_hand is the wrist offset + a uniform
# scale, so (point - wrist) / size)
fit = "Fit"
rig = bpy.data.objects[fit + "Rig"]
size = B5["body_spec"](fit)["hand"]
made, names = [], {}
for shape in SHAPES:
    for side in ("Left", "Right"):
        src = bpy.data.objects["%s_%s%s" % (fit, shape, side)]
        wrist = rig.data.bones[side + "Hand"].head_local
        me = src.data.copy()
        for v, p in zip(me.vertices, SWAP_PTS[(fit, shape, side)]):
            v.co = (p - wrist) / size
        me.materials.clear()
        o = bpy.data.objects.new("Swap05_%s_%s" % (shape, side), me)
        bpy.context.scene.collection.objects.link(o)
        lo, hi = bbox([v.co for v in me.vertices])
        e = hi - lo
        info["shapes"]["%s_%s" % (shape, side)] = {"size": [round(e.x, 4), round(e.z, 4), round(e.y, 4)],
                                                   "triangles": tris([o])}
        made.append(o)
        names[o] = "%s_%s" % (shape, side)
export_glb(os.path.join(EXPORTS, "CartoonHands05.glb"), None, made, names, skins=False)
with open(os.path.join(EXPORTS, "CartoonExport05.json"), "w") as f:
    f.write(json.dumps(info, indent=1))
log("wrote CartoonExport05.json")
