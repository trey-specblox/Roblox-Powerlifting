# Clothes check for the coaches (build_coach_clothes_01.py -> art/blender/CoachClothes_01.blend). READ-ONLY.
#   blender -b art/blender/CoachClothes_01.blend --python art/scripts/check_coach_clothes_01.py -- <out_dir>
# 1. SKIN THROUGH THE CLOTHES: every skin point the tee / joggers / sneakers cover at rest (a ray out along the skin's
#    normal meets the piece within 0.5) is checked again in each pose: a point whose ray no longer meets them pokes
#    through. Poses: the game's coach moves (art/animations, posed as Roblox does).
# 2. Pictures in the coaches' colours, backface culling on: line-ups (front, back, side, three-quarter), close-ups
#    (neck and shoulders, hem and hips), and the coach moves.
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
OUT = sys.argv[sys.argv.index("--") + 1]
PREVIEWS = os.path.join(ROOT, "art", "previews")
os.makedirs(OUT, exist_ok=True)
G = {"__name__": "gear_fit_03"}
exec(open(os.path.join(SCRIPTS, "gear_fit_03.py"), encoding="utf-8").read(), G)
COACHES = tuple(os.environ.get("CHECK_FIGURES", "Squatavious,Benchamin,Sumo").split(","))
WORN = tuple(os.environ.get("CHECK_WORN", "Tee,TeeWhite,Joggers,JoggersWhite,Sneakers,SneakersSole").split(","))
PICTURES = os.environ.get("CHECK_PICTURES", "1") == "1"
# BASELINE: the same check on the approved lifter clothes, e.g. on CartoonGear_07.blend with
# CHECK_FIGURES=Fit,Muscular,BigBuff CHECK_WORN=Tee,TeeWhite CHECK_PICTURES=0
POSES = [("Rest", None), ("CoachTalk", "Chalk_Coach_Talk"), ("CoachBack", "Chalk_Coach_Back"),
         ("ChalkClap", "Emote_ChalkClap"), ("Walk", "Entrance_Walk_Swagger")]
SKIN_PARTS = ["LowerTorso", "UpperTorso"] + [s + p for s in ("Left", "Right") for p in
                                              ("UpperArm", "LowerArm", "UpperLeg", "LowerLeg", "Foot")]
rigs = {c: bpy.data.objects[c + "Rig"] for c in COACHES}


def item_of(o):
    return o.name.split("_", 1)[1].split("__")[0]


def worn(c):
    return [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(c + "_") and "__" in o.name
            and item_of(o) in WORN]


def evaluated(o):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = o.evaluated_get(dg)
    me = ev.to_mesh()
    V = [o.matrix_world @ v.co for v in me.vertices]
    N = [(o.matrix_world.to_3x3() @ v.normal).normalized() for v in me.vertices]
    F = [tuple(p.vertices) for p in me.polygons]
    ev.to_mesh_clear()
    return V, N, F


NEAR = {"UpperTorso": ("UpperTorso", "LowerTorso"), "LowerTorso": ("LowerTorso", "UpperTorso")}


def clothes_tree(c):
    """One tree per skin part: the worn pieces on that part (the torso's two parts together), so skin is only judged
    against the clothes made to cover it (a forearm hanging next to the joggers is not 'covered' by them)."""
    pieces = {}
    for o in worn(c):
        v, _n, f = evaluated(o)
        pieces.setdefault(o.name.split("__")[-1], []).append((v, f))
    trees = {}
    for part in SKIN_PARTS:
        V, F = [], []
        for p in NEAR.get(part, (part,)):
            for v, f in pieces.get(p, []):
                k = len(V)
                V += v
                F += [tuple(i + k for i in t) for t in f]
        trees[part] = BVHTree.FromPolygons(V, F) if F else None
    return trees


def covered(c, trees):
    out = {}
    for part in SKIN_PARTS:
        o = bpy.data.objects[c + "_" + part]
        V, N, _f = evaluated(o)
        tree = trees[part]
        # covered = the clothes lie right over this skin (within 0.2: the joggers' loosest gap), not just face it
        out[part] = [tree is not None and tree.ray_cast(V[i] + N[i] * 0.002, N[i], 0.2)[0] is not None
                     for i in range(len(V))]
    return out


def through(c, trees, cov):
    n = 0
    where = {}
    for part in SKIN_PARTS:
        o = bpy.data.objects[c + "_" + part]
        V, N, _f = evaluated(o)
        tree = trees[part]
        k = sum(1 for i in range(len(V)) if cov[part][i] and (tree is None or
                tree.ray_cast(V[i] + N[i] * 0.002, N[i], 0.3)[0] is None))
        if k:
            where[part] = k
        n += k
    return n, where


report = {}
for c in COACHES:
    G["rest_rig"](rigs[c])
    cov = covered(c, clothes_tree(c))
    report[c] = {"covered": sum(sum(v) for v in cov.values())}
    for pose, anim in POSES:
        G["rest_rig"](rigs[c])
        if anim:
            G["pose_rig"](rigs[c], G["anim_at"](anim, G["extreme_time"](anim)))
        report[c][pose] = through(c, clothes_tree(c), cov)
    G["rest_rig"](rigs[c])
    print("[CoachClothesCheck]", c, report[c], flush=True)

# ---------------------------------------------------------------- pictures
if not PICTURES:
    raise SystemExit(0)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading
sh.light, sh.color_type, sh.show_backface_culling, sh.show_cavity = "STUDIO", "MATERIAL", True, True
sh.cavity_type = "WORLD"
sh.cavity_ridge_factor, sh.cavity_valley_factor = 0.6, 1.0
sc.world = sc.world or bpy.data.worlds.new("W")
sc.world.color = (0.16, 0.17, 0.2)
cd = bpy.data.cameras.new("Cam")
cd.type = "ORTHO"
cam = bpy.data.objects.new("Cam", cd)
sc.collection.objects.link(cam)
sc.camera = cam


def shoot(path, target, d, scale, res):
    cd.ortho_scale = scale
    sc.render.resolution_x, sc.render.resolution_y = res
    cam.location = Vector(target) + Vector(d).normalized() * 40
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


xs = [rigs[c].location.x for c in COACHES]
mid = Vector(((min(xs) + max(xs)) / 2, 0, 2.7))
for view, d in (("Front", (0, -1, 0.04)), ("Back", (0, 1, 0.04)), ("Threequarter", (-0.8, -1, 0.18))):
    shoot(os.path.join(PREVIEWS, "CoachClothes01_%s.png" % view), mid, d, 14.5, (1800, 1000))
for c in COACHES:
    rigs[c].rotation_euler = (0, 0, math.radians(90))
bpy.context.view_layer.update()
shoot(os.path.join(PREVIEWS, "CoachClothes01_Side.png"), mid, (0, -1, 0.04), 14.5, (1800, 1000))
for c in COACHES:
    rigs[c].rotation_euler = (0, 0, 0)
bpy.context.view_layer.update()
# close-ups: neck and shoulders, and hem and hips, each coach, front and three-quarter and back
for c in COACHES:
    sk = rigs[c]["skeleton"]
    x = rigs[c].location.x
    for name, z, scale in (("Neck", sk["N"] - 0.35, 3.2), ("Hips", sk["HJ"] + 0.15, 3.4)):
        for view, d in (("Front", (0, -1, 0.1)), ("Threequarter", (-0.8, -1, 0.25)), ("Back", (0.4, 1, 0.15))):
            shoot(os.path.join(OUT, "Close_%s_%s_%s.png" % (c, name, view)), (x, 0, z), d, scale, (700, 600))
# the coach moves, three-quarter
for i, (pose, anim) in enumerate(POSES):
    for c in COACHES:
        G["rest_rig"](rigs[c])
        if anim:
            G["pose_rig"](rigs[c], G["anim_at"](anim, G["extreme_time"](anim)))
    shoot(os.path.join(OUT, "Pose_%d_%s.png" % (i, pose)), mid, (-0.8, -1, 0.18), 14.5, (1500, 900))
print("[CoachClothesCheck] pictures done", flush=True)
