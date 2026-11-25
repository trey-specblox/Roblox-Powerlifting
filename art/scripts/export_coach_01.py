# Exports the three coaches for the game (approved: the bodies 2026-11-24 "They look right", the clothes "Cloths look
# right"), read-only on art/blender/CoachClothes_01.blend (NOT saved), exactly as export_cartoon_05.py exports the
# lifters (its helpers are used unchanged):
#   art/exports/CoachBody01_<Coach>.glb     the rig + the 14 skinned R15 parts (the open hand is the body's own hand)
#   art/exports/CoachClothes01_<Coach>.glb  the rig + the clothes pieces, "<Item>__<Part>" (tee, long sleeve, shorts,
#                                           joggers, sneakers and their white pieces)
#   art/exports/CoachExport01.json          per coach: the joints, the neck mark, the hip height (the game's HipHeight),
#                                           the hand size, each swap hand's offset from the body's hand part, the
#                                           squat bar rest and bench clearance (for the config's Body fields; coaches
#                                           don't lift yet), the triangles
# The swap hands themselves are the lifters' uploaded CartoonHands05 (hand size 1, scaled per body by the game).
#   blender -b art/blender/CoachClothes_01.blend --python art/scripts/export_coach_01.py
import json
import os

import bpy
from mathutils import Vector

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
EXPORTS = os.environ.get("COACH01_EXPORTS") or os.path.join(ROOT, "art", "exports")
COACHES = ("Squatavious", "Benchamin", "Sumo")
HAND_SIZE = {"Squatavious": 1.40, "Benchamin": 1.50, "Sumo": 1.10}      # build_coach_bodies_01 (spec "hand")

src = open(os.path.join(SCRIPTS, "export_cartoon_05.py"), encoding="utf-8").read()
src = src.split("\nbpy.context.view_layer.update()\nfor o in bpy.data.objects:")[0]
E = {"__name__": "export05_lib"}
exec(src, E)
PARTS, SHAPES, CLOTHES = E["PARTS"], E["SHAPES"], E["CLOTHES"]
rbx, rig_points, bbox, tris = E["rbx"], E["rig_points"], E["bbox"], E["tris"]


def log(*a):
    print("[ExportCoach01]", *a, flush=True)


bpy.context.view_layer.update()
for o in bpy.data.objects:
    o.hide_set(False)
    o.hide_viewport = False
SWAP_PTS = {}
for c in COACHES:
    rig = bpy.data.objects[c + "Rig"]
    for shape in SHAPES:
        for side in ("Left", "Right"):
            SWAP_PTS[(c, shape, side)] = rig_points(bpy.data.objects["%s_%s%s" % (c, shape, side)], rig)
for c in COACHES:
    E["point_bones_up"](bpy.data.objects[c + "Rig"])

info = {"coaches": {}, "about": "art/scripts/export_coach_01.py: Roblox axes (x = -Blender x, y = up, z = Blender y = "
        "toward the back); offsets/marks in each part's own space at rest (the part's centre = its box centre)."}
os.makedirs(EXPORTS, exist_ok=True)
for c in COACHES:
    rig = bpy.data.objects[c + "Rig"]
    sk = dict(rig["skeleton"])
    saved_loc = rig.location.copy()
    rig.location = (0, 0, 0)
    bpy.context.view_layer.update()
    parts = {p: bpy.data.objects["%s_%s" % (c, p)] for p in PARTS}
    centre = {}
    for p, o in parts.items():
        lo, hi = bbox(rig_points(o, rig))
        centre[p] = (lo + hi) / 2
    up = rig_points(parts["UpperTorso"], rig)
    cu = centre["UpperTorso"]
    chest = [p for p in up if abs(p.x) < 0.6 and sk["SH"] - 0.9 < p.z < sk["SH"] - 0.1]
    back = [p for p in up if abs(p.x) < 0.6 and sk["SH"] - 0.6 < p.z < sk["SH"] + 0.1]
    front, behind = min(p.y for p in chest), max(p.y for p in back)
    row = {
        "joints": {bone.name: rbx(bone.head_local) for bone in rig.data.bones},
        "neckMark": rbx(Vector((0, 0, sk["N"])) - cu),
        "hipHeight": round(sk["HJ"], 4),
        "handSize": HAND_SIZE[c],
        "squatBarRest": round((behind - cu.y) + E["BAR_RADIUS"] + E["FABRIC"], 3),
        "benchBarClear": round((cu.y - front) + E["BAR_RADIUS"] + E["FABRIC"], 3),
        "handOffsets": {},
        "triangles": tris(parts.values()),
    }
    for shape in SHAPES:
        for side in ("Left", "Right"):
            lo, hi = bbox(SWAP_PTS[(c, shape, side)])
            row["handOffsets"]["%s_%s" % (shape, side)] = rbx((lo + hi) / 2 - centre[side + "Hand"])
    E["export_glb"](os.path.join(EXPORTS, "CoachBody01_%s.glb" % c), rig, list(parts.values()),
                    {o: p for p, o in parts.items()})
    clothes = {}
    for o in bpy.data.objects:
        if o.type == "MESH" and o.name.startswith(c + "_") and "__" in o.name:
            name = o.name[len(c) + 1:]
            if name.split("__")[0] in CLOTHES:
                clothes[o] = name
            else:
                log("NOT EXPORTED (unknown piece)", o.name)
    E["export_glb"](os.path.join(EXPORTS, "CoachClothes01_%s.glb" % c), rig, list(clothes), clothes)
    row["clothesPieces"] = len(clothes)
    row["clothesTriangles"] = tris(clothes)
    info["coaches"][c] = row
    rig.location = saved_loc
    bpy.context.view_layer.update()
    log(c, {k: v for k, v in row.items() if k not in ("joints", "handOffsets")})
with open(os.path.join(EXPORTS, "CoachExport01.json"), "w") as f:
    f.write(json.dumps(info, indent=1))
log("wrote CoachExport01.json")
