# Picture and pose check for the six production bodies (build_cartoon_rig_05.py -> CartoonBodies_05_Rigged.blend).
# Read-only: the .blend is opened and NOT saved. CHARACTER_ART_DIRECTION.md §4 checklist: front, back, side,
# three-quarter and silhouette line-ups at the same cameras and light, backface culling on (as Roblox draws), the
# stand-in head; the hands at game size; the lift / raise / contact moments with the game's hand shapes
# (HandShapeConfig: fists while gripping the bar, in double biceps and the roars); shoulder close-ups in the raises;
# and a SHOULDER MEASURE per raised pose: skin triangles of the shoulder region that pass through other skin
# triangles (the fold that makes a tee tear) and the most-squashed triangle there.
#
#   set CHECK05_ANIMS=<folder of the block-rig animations> (the committed originals: these bodies have block legs and
#   HipHeight 2; until Phase 1's re-made set exists), then
#   blender -b art/blender/CartoonBodies_05_Rigged.blend --python art/scripts/check_bodies_05.py -- <out_dir> [tag]
# Writes <out_dir>/Bodies05_<tag>*.png and prints the measures.
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
TAG = argv[1] if len(argv) > 1 else ""
ONLY = os.environ.get("CHECK05_ONLY", "")           # "lineups", "poses", "raises", "measure"
RES = float(os.environ.get("CHECK05_RES", "1"))       # picture size factor (smaller for quick comparisons)           # "lineups", "poses", "measure" to run one part
os.makedirs(OUT, exist_ok=True)
ANIMS = os.environ.get("CHECK05_ANIMS", "")
assert os.path.isdir(ANIMS), "set CHECK05_ANIMS to the folder of the block-rig animations"
G = {"__name__": "gear_fit_03"}
exec(open(os.path.join(SCRIPTS, "gear_fit_03.py")).read(), G)
G["ANIMS"] = ANIMS
B = {"__name__": "body05_lib", "BODY05_AS_LIBRARY": True}
exec(open(os.path.join(SCRIPTS, "build_cartoon_body_05.py")).read(), B)
L, ORDER = B["L"], B["ORDER"]
LABEL = {"Skinny": "Skinny", "SkinnyFat": "Skinny-fat", "Fat": "Fat", "Fit": "Fit", "Muscular": "Muscular",
         "BigBuff": "Big and buff"}
SPACING = 4.6
rigs = {b: bpy.data.objects[b + "Rig"] for b in ORDER}
PARTS = G["PARTS"]

# ---------------------------------------------------------------- scene
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading
sh.light, sh.color_type, sh.show_backface_culling, sh.show_cavity = "STUDIO", "MATERIAL", True, True
sh.cavity_type = os.environ.get("CHECK05_CAVITY", "WORLD")
sh.show_cavity = sh.cavity_type != "OFF"
if sh.show_cavity:
    sh.cavity_ridge_factor, sh.cavity_valley_factor = 0.6, 1.0
sc.render.film_transparent = False
if sc.world is None:
    sc.world = bpy.data.worlds.new("W")
sc.world.color = (0.16, 0.17, 0.2)
cd = bpy.data.cameras.new("Check05Cam")
cd.type = "ORTHO"
cam = bpy.data.objects.new("Check05Cam", cd)
sc.collection.objects.link(cam)
sc.camera = cam
skin = bpy.data.materials["CartoonSkin"]
head_mat = bpy.data.materials.get("StandInHead")


def shoot(name, direction, scale, res, target):
    cd.ortho_scale = scale
    sc.render.resolution_x, sc.render.resolution_y = (int(res[0] * RES), int(res[1] * RES))
    cam.location = Vector(target) + Vector(direction).normalized() * 40
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(OUT, "Bodies05_%s%s.png" % (TAG, name))
    bpy.ops.render.render(write_still=True)
    print("[Check05] shot", sc.render.filepath, flush=True)


def label_objects(row_pos, z=-0.35, size=0.38):
    """Build names under each body (text objects, removed afterwards)."""
    made = []
    for b, pos in row_pos.items():
        cu = bpy.data.curves.new("Label_" + b, "FONT")
        cu.body = LABEL[b]
        cu.align_x = "CENTER"
        cu.size = size
        o = bpy.data.objects.new("Label_" + b, cu)
        sc.collection.objects.link(o)
        o.location = Vector(pos) + Vector((0, 0, z))
        made.append(o)
    return made


def swaps(b, shape):
    """Shows one hand shape on this build (Open = the hands in the body; the others = SwapHands05)."""
    for side in ("Left", "Right"):
        bpy.data.objects["%s_%sHand" % (b, side)].hide_render = shape != "Open"
        for s in ("Fist", "Point", "ThumbsUp", "Grip"):
            bpy.data.objects["%s_%s%s" % (b, s, side)].hide_render = s != shape


def place_row(axis="x", gap=SPACING):
    for i, b in enumerate(ORDER):
        rigs[b].location = (i * gap, 0, 0) if axis == "x" else (0, -i * gap, 0)
    bpy.context.view_layer.update()


def rest_all():
    for b in ORDER:
        G["rest_rig"](rigs[b])
        swaps(b, "Open")


# ---------------------------------------------------------------- line-ups
def lineups():
    rest_all()
    place_row("x")
    mid = Vector(((len(ORDER) - 1) * SPACING / 2, 0, 2.9))
    labels = label_objects({b: (i * SPACING, -1.6, 0) for i, b in enumerate(ORDER)})
    for lab in labels:
        lab.rotation_euler = (math.radians(90), 0, 0)
    for view, d in {"Front": (0, -1, 0.04), "Back": (0, 1, 0.04), "Threequarter": (-0.8, -1, 0.18)}.items():
        for lab in labels:
            lab.hide_render = view == "Back"
        shoot("Lineup_" + view, d, 28.5, (2600, 1000), mid)
    for lab in labels:
        bpy.data.objects.remove(lab, do_unlink=True)
    # side: the six in a row seen from their left
    place_row("y", 3.4)
    mid_s = Vector((0, -(len(ORDER) - 1) * 3.4 / 2, 2.9))
    labels = label_objects({b: (0.0, -i * 3.4, 0) for i, b in enumerate(ORDER)})
    for lab in labels:
        lab.rotation_euler = (math.radians(90), 0, math.radians(90))
    shoot("Lineup_Side", (1, 0, 0.04), 21.5, (2400, 1000), mid_s)
    for lab in labels:
        bpy.data.objects.remove(lab, do_unlink=True)
    # silhouettes: flat black on white, front row and side row
    sh.light, sh.color_type, sh.single_color, sh.show_cavity = "FLAT", "SINGLE", (0.02, 0.02, 0.02), False
    old_world = tuple(sc.world.color)
    sc.world.color = (1, 1, 1)
    shoot("Silhouette_Side", (1, 0, 0.0), 21.5, (2400, 1000), mid_s)
    place_row("x")
    shoot("Silhouette_Front", (0, -1, 0.0), 28.5, (2600, 1000), mid)
    sh.light, sh.color_type, sh.show_cavity = "STUDIO", "MATERIAL", os.environ.get("CHECK05_CAVITY", "WORLD") != "OFF"
    sc.world.color = old_world
    # close-ups, one tile per build: head and shoulders (head integration, no ledge, delt wrap), the right hand at the
    # side (hand size against the forearm), and the four hand shapes on Fit
    close_sheet("Close_HeadShoulders", [((-0.9, -1, 0.25), Vector((0, 0, 4.45)), 4.2), ((0, -1, 0.08), Vector((0, 0, 4.45)), 4.2),
                                         ((0, 1, 0.08), Vector((0, 0, 4.45)), 4.2)], (640, 560))
    close_sheet("Close_Hands", [((-1, -0.6, 0.15), "RightHand", 1.9), ((-0.2, -1, 0.1), "RightHand", 1.9)], (520, 560))
    tiles = []
    b = "Fit"
    for i, shape in enumerate(("Open", "Fist", "Point", "ThumbsUp", "Grip")):
        swaps(b, shape)
        tiles.append((b, shape, shoot_tile("Shape_" + shape, (-1, -0.6, 0.15), hand_centre(b, "Right"), 1.6, (520, 560))))
    swaps(b, "Open")
    G["contact_sheet"](tiles, os.path.join(OUT, "Bodies05_%sClose_HandShapes.png" % TAG), cols=5)
    for _b, _v, p in tiles:
        os.remove(p)


def hand_centre(b, side):
    o = bpy.data.objects["%s_%sHand" % (b, side)]
    pts, _f = G["evaluated_points"](o, rigs[b])
    c = sum(pts, Vector()) / len(pts)
    return rigs[b].matrix_world @ c


def shoot_tile(name, direction, target, scale, res):
    path = os.path.join(OUT, "_tile_%s.png" % name)
    cd.ortho_scale = scale
    sc.render.resolution_x, sc.render.resolution_y = res
    cam.location = Vector(target) + Vector(direction).normalized() * 40
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def close_sheet(name, views, res):
    """Rows = views, columns = the six builds (each build alone in its tile)."""
    tiles = []
    for vi, (d, where, scale) in enumerate(views):
        for b in ORDER:
            if isinstance(where, str):
                target = hand_centre(b, where.replace("Hand", ""))
            else:
                target = rigs[b].matrix_world @ where
            tiles.append((b, vi, shoot_tile("%s_%d_%s" % (name, vi, b), d, target, scale, res)))
    G["contact_sheet"](tiles, os.path.join(OUT, "Bodies05_%s%s.png" % (TAG, name)), cols=len(ORDER))
    print("[Check05] sheet", name, flush=True)
    for _b, _v, p in tiles:
        os.remove(p)


# ---------------------------------------------------------------- poses
FIST_SPANS = {"Station_Squat": [(0, 99)], "Station_Bench": [(0, 99)], "Station_Deadlift": [(0, 99)],
              "Setup_Squat": [(0, 99)], "Emote_BeltTighten": [(0.3, 2.2)], "Emote_DoubleBiceps": [(0, 99)],
              "Celebrate_CrouchRoarJump": [(0.25, 3.6)], "Celebrate_DisbeliefPrayer": [(1.85, 2.5), (6.4, 7.5)]}


def shape_at(anim, t):
    return "Fist" if any(a <= t < b for a, b in FIST_SPANS.get(anim, [])) else "Open"


def closest_time(anim, rig):
    best, bt = None, 0.0
    for t, poses in G["read_anim"](anim):
        G["pose_rig"](rig, poses)
        d = (rig.pose.bones["LeftLowerArm"].tail - rig.pose.bones["RightLowerArm"].tail).length
        if best is None or d < best:
            best, bt = d, t
    return bt


def highest_time(anim, rig):
    """The keyframe with the hands highest (the top of a raise)."""
    best, bt = None, 0.0
    for t, poses in G["read_anim"](anim):
        G["pose_rig"](rig, poses)
        z = rig.pose.bones["LeftLowerArm"].tail.z + rig.pose.bones["RightLowerArm"].tail.z
        if best is None or z > best:
            best, bt = z, t
    return bt


POSES = [("SquatBottom", "Station_Squat", 1.9), ("BenchChest", "Station_Bench", 2.0),
         ("DeadliftBottom", "Station_Deadlift", 1.6), ("SquatBarHold", "Setup_Squat", None),
         ("ArmsUp", "Celebrate_ArmsUpBounce", "high"), ("OverheadClap", "Entrance_Hype_OverheadClap", "high"),
         ("DoubleBiceps", "Emote_DoubleBiceps", None), ("CrouchRoar", "Celebrate_CrouchRoarJump", None),
         ("ChestSlap", "Entrance_Hype_ChestSlap", None), ("Walk", "Entrance_Walk_Swagger", None)]
RAISES = ("SquatBarHold", "ArmsUp", "OverheadClap", "DoubleBiceps")


def pose_all(anim, t):
    times = {}
    for b in ORDER:
        rig = rigs[b]
        if t == "high":
            times[b] = highest_time(anim, rig)
        elif t is None:
            times[b] = G["extreme_time"](anim)
        else:
            times[b] = t
        G["pose_rig"](rig, G["anim_at"](anim, times[b]))
        swaps(b, shape_at(anim, times[b]))
    return times


def skin_mesh(b):
    """The posed skin of one build (rig space): points, triangles, which points are in the shoulder region."""
    rig = rigs[b]
    pts, tris, piv = [], [], B["body_spec"](b)["pivot_x"]
    rest = []
    for part in PARTS:
        if part.endswith("Hand"):
            continue
        o = bpy.data.objects[b + "_" + part]
        P, F = G["evaluated_points"](o, rig)
        base = len(pts)
        pts += P
        rest += [v.co.copy() for v in o.data.vertices]
        for f in F:
            for k in range(1, len(f) - 1):
                tris.append((base + f[0], base + f[k], base + f[k + 1]))
    near = [abs(abs(r.x) - piv) < 0.75 and r.z > L["SH"] - 0.9 for r in rest]
    return pts, tris, rest, near


def shoulder_measure(b):
    """Shoulder-region triangles that cut through other skin triangles (not neighbours), and the smallest posed/rest
    area ratio there (1 = unchanged, near 0 = squashed flat)."""
    pts, tris, rest, near = skin_mesh(b)
    # the parts repeat the points along each cut: one id per rest position, so triangles across a cut count as
    # neighbours (they touch there by design)
    ids, canon = {}, []
    for r in rest:
        canon.append(ids.setdefault((round(r.x, 4), round(r.y, 4), round(r.z, 4)), len(ids)))
    tris = [tuple(canon[v] for v in t) for t in tris]
    first = {}
    for i, c in enumerate(canon):
        first.setdefault(c, i)
    pts = [pts[first[c]] for c in range(len(ids))]
    rest = [rest[first[c]] for c in range(len(ids))]
    near = [near[first[c]] for c in range(len(ids))]
    tree = BVHTree.FromPolygons(pts, tris)
    hits = set()
    for i, j in tree.overlap(tree):
        if i == j or set(tris[i]) & set(tris[j]):
            continue
        for k in (i, j):
            if any(near[v] for v in tris[k]):
                hits.add(k)
    worst = 9.0
    for t in tris:
        if not all(near[v] for v in t):
            continue
        a = (pts[t[1]] - pts[t[0]]).cross(pts[t[2]] - pts[t[0]]).length
        a0 = (rest[t[1]] - rest[t[0]]).cross(rest[t[2]] - rest[t[0]]).length
        if a0 > 1e-8:
            worst = min(worst, a / a0)
    return len(hits), round(worst, 3)


def poses():
    place_row("x")
    rows = []
    mid = Vector(((len(ORDER) - 1) * SPACING / 2, 0, 2.8))
    for name, anim, t in POSES:
        times = pose_all(anim, t)
        shoot("Pose_" + name, (-16, -22, 6), 29.0, (2600, 900), mid)
        if name in RAISES:
            shoot("Pose_%s_ShoulderClose" % name, (-0.35, -1, 0.35), 28.5, (2600, 700), Vector((mid.x, 0, 4.6)))
            shoot("Pose_%s_ShoulderBack" % name, (0.35, 1, 0.35), 28.5, (2600, 700), Vector((mid.x, 0, 4.6)))
        if name in RAISES or name == "ChestSlap":
            row = {b: shoulder_measure(b) for b in ORDER}
            rows.append((name, row))
            print("[Check05] shoulder %s %s" % (name, row), flush=True)
        print("[Check05] pose", name, {b: round(v, 2) for b, v in times.items()}, flush=True)
    rest_all()
    return rows


def measure_only():
    place_row("x")
    rows = []
    for name, anim, t in POSES:
        if name not in RAISES and name != "ChestSlap":
            continue
        pose_all(anim, t)
        row = {b: shoulder_measure(b) for b in ORDER}
        rows.append((name, row))
        print("[Check05] shoulder %s %s" % (name, row), flush=True)
    rest_all()
    return rows


if ONLY in ("", "lineups"):
    lineups()
if ONLY in ("", "poses"):
    poses()
if ONLY == "measure":
    measure_only()
if ONLY == "raises":
    place_row("x")
    mid = Vector(((len(ORDER) - 1) * SPACING / 2, 0, 2.8))
    for name, anim, t in POSES:
        if name not in RAISES:
            continue
        pose_all(anim, t)
        shoot("Pose_%s_ShoulderClose" % name, (-0.35, -1, 0.35), 28.5, (2600, 700), Vector((mid.x, 0, 4.6)))
        print("[Check05] shoulder %s %s" % (name, {b: shoulder_measure(b) for b in ORDER}), flush=True)
    rest_all()
    print("[Check05] shoulder Rest %s" % {b: shoulder_measure(b) for b in ORDER}, flush=True)
print("[Check05] done", flush=True)
