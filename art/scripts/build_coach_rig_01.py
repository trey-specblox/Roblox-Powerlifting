# The three coach bodies (build_coach_bodies_01.py -> art/blender/CoachBodies_01.blend, APPROVED by the user
# 2026-11-24: "They look right") rigged in the lifters' layout: "<Coach>Rig" + the 14 R15 parts "<Coach>_<Part>", the
# open hands, a stand-in head on the neck, and the hidden swap hands (Fist, Point, ThumbsUp, Grip, SquatGrip) on each
# hand bone. Nothing exported or uploaded.
#   blender -b art/blender/CartoonBodies_05.blend --python art/scripts/build_coach_rig_01.py
# Writes art/blender/CoachBodies_01_Rigged.blend.
#
# THE LIFTERS' WEIGHTS: the coach bodies are the lifters' base mesh reshaped (same points, same order, each point
# carried along its own bone), so a coach point is the same anatomical point as on a lifter. The weights are made
# exactly as build_cartoon_rig_05.py makes them (its own code is run: automatic weights on Fit, the spread shoulders
# and elbows, the mirror, the armpit/hip fold solve) and every coach gets the same weight on the same point, and the
# same R15 part split (the same faces in each part). Only the BONES differ: each coach's at his own joint heights
# (Squatavious short, Sumo long-legged), the arms at his own arm_x / pivot_x, the HumanoidRootNode at his own hip
# height + 1.
import math
import os

import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
COACH_BLEND = os.path.join(ROOT, "art", "blender", "CoachBodies_01.blend")
OUT = os.environ.get("COACHRIG01_OUT") or os.path.join(ROOT, "art", "blender", "CoachBodies_01_Rigged.blend")
SPACING = 4.6

# build_cartoon_rig_05.py: its helpers (everything before "main"), then its weight section, run here unchanged.
_rig05 = open(os.path.join(SCRIPTS, "build_cartoon_rig_05.py"), encoding="utf-8").read()
_head, _main = _rig05.split("# ---------------------------------------------------------------- main", 1)
_weights = _main.split("# 2) every build: the same weights, the same split")[0]
_weights = _weights.split("# 1) automatic weights on the base build", 1)[1]
RG = {"__name__": "rig05_lib"}
exec(_head, RG)
R, B, PARTS = RG["R"], RG["B"], RG["PARTS"]

C1 = {"__name__": "coach01_lib", "COACH01_AS_LIBRARY": True}
exec(open(os.path.join(SCRIPTS, "build_coach_bodies_01.py"), encoding="utf-8").read(), C1)
COACHES = C1["ORDER"]


def log(*a):
    print("[CoachRig01]", *a, flush=True)


def coach_joints(spec):
    sk, arm_x, pivot = spec["skel"], spec["arm_x"], spec["pivot_x"]
    j = {"LowerTorso": Vector((0, 0, sk["HJ"])), "UpperTorso": Vector((0, 0, sk["W"]))}
    for side, sx in (("Left", 1), ("Right", -1)):
        j[side + "UpperArm"] = Vector((sx * pivot, 0, sk["SH"]))
        j[side + "LowerArm"] = Vector((sx * arm_x, 0, sk["E"]))
        j[side + "Hand"] = Vector((sx * arm_x, 0, sk["WR"]))
        j[side + "UpperLeg"] = Vector((sx * 0.5, 0, sk["HJ"]))
        j[side + "LowerLeg"] = Vector((sx * 0.5, 0, sk["K"]))
        j[side + "Foot"] = Vector((sx * 0.5, 0, sk["A"]))
    return j


def hand_matrix(side, spec):
    sx = 1 if side == "Left" else -1
    return Matrix.Translation(Vector((sx * spec["arm_x"], 0, spec["skel"]["WR"]))) @ B["hand_space"](side, spec["hand"])


def make_coach(coach, spec, W, bones, faces_part, coll, i):
    """build_cartoon_rig_05.make_body for a coach: his own bones, the shared weights and part split."""
    src = bpy.data.objects["CoachBody01_" + coach]
    body = src.copy()
    body.data = src.data.copy()
    body.location = (0, 0, 0)
    body.name = coach + "_Skin"
    coll.objects.link(body)
    R["HIP_HEIGHT"] = spec["skel"]["HJ"]
    rig, _order = R["make_rig"](coach, coach_joints(spec), coll)
    RG["write_weights"](body, bones, W)
    body.parent = rig
    body.modifiers.new("Armature", "ARMATURE").object = rig
    for side in ("Left", "Right"):
        h = bpy.data.objects["CoachBody01_%s_%sHand" % (coach, side)].copy()
        h.data = h.data.copy()
        h.location = (0, 0, 0)
        coll.objects.link(h)
        h.name = h.data.name = "%s_%sHand" % (coach, side)
        for g in list(h.vertex_groups):
            h.vertex_groups.remove(g)
        h.vertex_groups.new(name=side + "Hand").add(list(range(len(h.data.vertices))), 1.0, "REPLACE")
        h.parent = rig
        h.modifiers.new("Armature", "ARMATURE").object = rig
    me = body.data
    me.materials.clear()
    for part in PARTS:
        me.materials.append(bpy.data.materials.get("Split_" + part) or bpy.data.materials.new("Split_" + part))
    me.polygons.foreach_set("material_index", faces_part)
    for p in me.polygons:
        p.use_smooth = True
    me.normals_split_custom_set_from_vertices([v.normal for v in me.vertices])
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")
    skin = B["skin_material"]()
    for o in [x for x in coll.objects if x.name == body.name or x.name.startswith(body.name + ".")]:
        if not o.data.polygons:
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        part = o.data.materials[o.data.polygons[0].material_index].name.replace("Split_", "")
        o.data.materials.clear()
        o.data.materials.append(skin)
        o.name = o.data.name = coach + "_" + part
        for p in o.data.polygons:
            p.use_smooth = True
    head = B["P4"]["stand_in_head"](coach + "_StandInHead", spec["skel"], 0.0, coll)
    bpy.context.view_layer.update()
    mw = head.matrix_world.copy()
    head.parent, head.parent_type, head.parent_bone = rig, "BONE", "UpperTorso"
    bpy.context.view_layer.update()
    head.matrix_world = mw
    rig.location.x = i * SPACING
    return rig


def swap_hands(coach, spec, rig, coll, H, HL):
    made = []
    for shape in RG["SWAP_SHAPES"]:
        for side in ("Left", "Right"):
            me = H[shape].data.copy()
            me.name = "%s_%s%s" % (coach, shape, side)
            me.transform(hand_matrix(side, spec))
            if side == "Right":
                me.flip_normals()
            for p in me.polygons:
                p.use_smooth = True
            me.materials.clear()
            me.materials.append(B["skin_material"]())
            o = bpy.data.objects.new(me.name, me)
            coll.objects.link(o)
            bpy.context.view_layer.update()
            o.matrix_world = rig.matrix_world.copy()
            bpy.context.view_layer.update()
            mw = o.matrix_world.copy()
            o.parent, o.parent_type, o.parent_bone = rig, "BONE", side + "Hand"
            bpy.context.view_layer.update()
            o.matrix_world = mw
            o.hide_render = True
            if shape == "Grip":
                o["grip_point"] = list(hand_matrix(side, spec) @ Vector(HL["GRIP_C"]))
            elif shape == "SquatGrip":
                o["grip_point"] = list(hand_matrix(side, spec) @ Vector(HL["HEEL_C"]))
            made.append(o)
    return made


# ---------------------------------------------------------------- main
coll = bpy.data.collections.new("CoachRig")
bpy.context.scene.collection.children.link(coll)
swap_coll = bpy.data.collections.new("CoachSwapHands")
bpy.context.scene.collection.children.link(swap_coll)
RG["coll"] = coll
RG["specs"] = {b: B["body_spec"](b) for b in RG["ORDER"]}
exec(_weights, RG)                       # -> RG["W"], RG["bones"], RG["faces_part"] (the lifters' own)
W, bones, faces_part = RG["W"], RG["bones"], RG["faces_part"]
log("lifter weights made:", W.shape, "parts table:", len(faces_part))

with bpy.data.libraries.load(COACH_BLEND, link=False) as (src, dst):
    dst.objects = [n for n in src.objects if n.startswith("CoachBody01_") and not n.endswith("_Head")]
for o in dst.objects:
    if o is not None:
        assert len(o.data.vertices) == W.shape[0] or o.name.endswith("Hand"), o.name

# THE COACHES' OWN FOLD SOLVE (COACHRIG01_SOLVE=1; the default 0 = the lifters' weights as they are). The lifters'
# armpit/hip solve (skin_split_solve.py) tuned the shoulder and hip shares for the six lifter shapes; on Squatavious's
# and Benchamin's huge delts the raised arm then pulled the shoulder into a cape-like web (pose check 2026-11-24). The
# same solver is run again from the lifters' weights with the three COACH shapes and joints (the regions picked on the
# base build, as for the lifters); the part split (faces_part) stays the lifters', so only how the skin bends changes.
# OFF BY DEFAULT since the clothes (2026-11-24): it changed nothing visible in the pose check, and the coach clothes
# carry the LIFTERS' clothes weights (build_coach_clothes_01.py), so the skin must keep the lifters' weights too: with
# the solve on, the tee sleeves bent differently from the arms and the skin came through them in the coach moves.
if os.environ.get("COACHRIG01_SOLVE", "0") == "1":
    rests = {c: np.array([v.co for v in bpy.data.objects["CoachBody01_" + c].data.vertices], dtype=np.float64)
             for c in COACHES}
    cspecs = {c: C1["COACHES"][c]() for c in COACHES}
    arm_p = {c: np.array(coach_joints(cspecs[c])["LeftUpperArm"]) for c in COACHES}
    leg_p = {c: np.array(coach_joints(cspecs[c])["LeftUpperLeg"]) for c in COACHES}
    W = RG["SS"]["solve_shoulders_hips"](W.copy(), bones, RG["mesh"], RG["co"], rests, arm_p, leg_p, RG["L"], log)
    W = RG["mirror_weights"](W, bones, RG["mirror"], RG["co"])
    W = RG["limit_normalise"](W)
    log("coach fold solve done")

HL = B["load_hands"]()
H = {s: HL["make_hand"](s, swap_coll, name="Hand04_" + s) for s in RG["SWAP_SHAPES"]}
for i, coach in enumerate(COACHES):
    spec = C1["COACHES"][coach]()
    rig = make_coach(coach, spec, W, bones, faces_part, coll, i)
    swap_hands(coach, spec, rig, swap_coll, H, HL)
    rig["hip_height"] = spec["skel"]["HJ"]
    rig["skeleton"] = {k: float(v) for k, v in spec["skel"].items()}
    tris = sum(B["triangles"](o) for o in coll.objects if o.type == "MESH" and o.name.startswith(coach + "_")
               and not o.name.endswith("StandInHead"))
    parts = sorted(o.name for o in coll.objects if o.type == "MESH" and o.name.startswith(coach + "_"))
    log(coach, "parts:", len(parts), "triangles:", tris, "hip height:", round(spec["skel"]["HJ"], 3))
for o in H.values():
    bpy.data.objects.remove(o, do_unlink=True)

for o in list(bpy.data.objects):
    if coll not in o.users_collection and swap_coll not in o.users_collection:
        bpy.data.objects.remove(o, do_unlink=True)
for c in list(bpy.data.collections):
    if c not in (coll, swap_coll):
        bpy.data.collections.remove(c)
bpy.data.orphans_purge(do_recursive=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT)
log("saved", OUT)
