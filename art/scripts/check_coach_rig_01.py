# Pose check for the rigged coaches (build_coach_rig_01.py -> art/blender/CoachBodies_01_Rigged.blend). READ-ONLY:
# the .blend is opened and NOT saved. Poses each coach in the game's own animations (art/animations, posed the way
# Roblox does it: gear_fit_03.pose_rig) at the moment that bends the body most, backface culling on, and measures the
# skin passing through other skin (shoulder, armpit and hip folds) per pose.
#   blender -b art/blender/CoachBodies_01_Rigged.blend --python art/scripts/check_coach_rig_01.py -- <out_dir>
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
os.makedirs(OUT, exist_ok=True)
G = {"__name__": "gear_fit_03"}
exec(open(os.path.join(SCRIPTS, "gear_fit_03.py"), encoding="utf-8").read(), G)
COACHES = ("Squatavious", "Benchamin", "Sumo")
POSES = [("Rest", None, None), ("CoachTalk", "Chalk_Coach_Talk", None), ("CoachBack", "Chalk_Coach_Back", None),
         ("ChalkClap", "Emote_ChalkClap", None), ("Walk", "Entrance_Walk_Swagger", None),
         ("ArmsUp", "Celebrate_ArmsUpBounce", None)]
rigs = {c: bpy.data.objects[c + "Rig"] for c in COACHES}

sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading
sh.light, sh.color_type, sh.show_backface_culling, sh.show_cavity = "STUDIO", "MATERIAL", True, True
sh.cavity_type = "WORLD"
sc.world = sc.world or bpy.data.worlds.new("W")
sc.world.color = (0.16, 0.17, 0.2)
cd = bpy.data.cameras.new("Cam")
cd.type = "ORTHO"
cam = bpy.data.objects.new("Cam", cd)
sc.collection.objects.link(cam)
sc.camera = cam
for o in bpy.data.objects:                       # the swap hands stay hidden (the open hands show)
    if o.type == "MESH" and any(o.name.endswith(s + side) for s in ("Fist", "Point", "ThumbsUp", "Grip", "SquatGrip")
                                for side in ("Left", "Right")):
        o.hide_render = True


def skin_objects(c):
    return [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(c + "_") and o.parent == rigs[c]
            and not o.name.endswith("StandInHead") and o.parent_type != "BONE"]


def self_cross(c):
    """Skin triangles of different parts that pass through each other (a fold), counted once per pair of parts."""
    dg = bpy.context.evaluated_depsgraph_get()
    trees = {}
    for o in skin_objects(c):
        if o.name.endswith("Hand"):
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        verts = [o.matrix_world @ v.co for v in me.vertices]
        tris = [tuple(p.vertices) for p in me.polygons]
        trees[o.name] = BVHTree.FromPolygons(verts, tris)
        ev.to_mesh_clear()
    names = sorted(trees)
    total = 0
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            total += len(trees[a].overlap(trees[b]))
    return total


report = {}
for col, (pose, anim, t) in enumerate(POSES):
    for c in COACHES:
        G["rest_rig"](rigs[c])
        if anim:
            when = t if t is not None else G["extreme_time"](anim)
            G["pose_rig"](rigs[c], G["anim_at"](anim, when))
        report.setdefault(c, {})[pose] = self_cross(c)
    xs = [rigs[c].location.x for c in COACHES]
    mid = Vector(((min(xs) + max(xs)) / 2, 0, 2.6))
    for view, d in (("front", (0, -1, 0.06)), ("threequarter", (-0.8, -1, 0.2))):
        cd.ortho_scale = 14.5
        sc.render.resolution_x, sc.render.resolution_y = 1500, 900
        cam.location = mid + Vector(d).normalized() * 40
        cam.rotation_euler = (mid - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(OUT, "CoachRig01_%d_%s_%s.png" % (col, pose, view))
        bpy.ops.render.render(write_still=True)
for c in COACHES:
    print("[CoachRigCheck]", c, "parts crossing (pairs of triangles):", report[c], flush=True)
