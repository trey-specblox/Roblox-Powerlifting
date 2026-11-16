# The six production bodies (build_cartoon_body_05.py -> art/blender/CartoonBodies_05.blend) rigged and split into
# the layout the gear tools read: "<Build>Rig" + the 14 R15 parts "<Build>_<Part>" (gear_fit_03.Body,
# build_cartoon_gear_04.py), a stand-in 1.2-stud head on the neck (the player's own head in the game), and the hidden
# swap hands (Fist, Point, ThumbsUp, Grip) on each hand bone in "SwapHands05". PRODUCTION CANDIDATE: nothing exported or
# uploaded.
#   blender -b art/blender/CartoonBodies_05.blend --python art/scripts/build_cartoon_rig_05.py
# Writes art/blender/CartoonBodies_05_Rigged.blend.
#
# Skeleton: TORSO_TALL (hips/HipHeight 2.0, waist 2.54, shoulder 4.38, elbow 3.287, wrist 2.148, knee 1.00 (longer thighs 2026-11-15); arms x1.5
# approved 2026-11-13), the arms
# at each build's arm_x, the shoulder joint at its pivot_x.
#
# WEIGHTS ARE SHARED: the six bodies have the same points in the same order, so the weights are made ONCE on the base
# build (Fit) and every build gets the same weight on the same point. A point on the delt is a delt point on every
# build, so the bodies bend the same way, the parts split at the same faces (every part keeps one topology across the
# builds), and the gear fitter can map one body onto another.
# How the weights are made (on Fit):
#   1. Blender's automatic weights (heat), at most 4 bones per point.
#   2. HAND-TUNED SHOULDERS (the armpit tear, §10.3): see shoulder_weights below.
#   3. Mirrored left -> right exactly (the base mesh is mirror-symmetric), normalised.
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
OUT = os.environ.get("RIG05_OUT") or os.path.join(ROOT, "art", "blender", "CartoonBodies_05_Rigged.blend")
SPACING = 4.6
MAX_INFLUENCES = 4
PARTS = ["LowerTorso", "UpperTorso"] + [s + p for s in ("Left", "Right") for p in
                                         ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")]

# build_cartoon_rig_02.py's bone helpers (make_rig), without running its build; that file is unchanged.
_src = open(os.path.join(SCRIPTS, "build_cartoon_rig_02.py")).read().split("\ncoll = collection()\nRESULTS")[0]
R = {"__name__": "rig02_lib"}
exec(_src, R)
B = {"__name__": "body05_lib", "BODY05_AS_LIBRARY": True}
exec(open(os.path.join(SCRIPTS, "build_cartoon_body_05.py")).read(), B)
L = B["L"]
R["HIP_HEIGHT"] = L["HJ"]          # the root node stands at HipHeight + 1
ORDER, BASE = B["ORDER"], B["BASE"]
SHOULDER_MODE = os.environ.get("RIG05_SHOULDERS", "spread")     # "spread" | "rig04" | "auto" (for comparisons)


def log(*a):
    print("[Rig05]", *a)


def joints(spec):
    arm_x, pivot = spec["arm_x"], spec["pivot_x"]
    j = {"LowerTorso": Vector((0, 0, L["HJ"])), "UpperTorso": Vector((0, 0, L["W"]))}
    for side, sx in (("Left", 1), ("Right", -1)):
        j[side + "UpperArm"] = Vector((sx * pivot, 0, L["SH"]))
        j[side + "LowerArm"] = Vector((sx * arm_x, 0, L["E"]))
        j[side + "Hand"] = Vector((sx * arm_x, 0, L["WR"]))
        j[side + "UpperLeg"] = Vector((sx * 0.5, 0, L["HJ"]))
        j[side + "LowerLeg"] = Vector((sx * 0.5, 0, L["K"]))
        j[side + "Foot"] = Vector((sx * 0.5, 0, L["A"]))
    return j


# ---------------------------------------------------------------- weights (numpy table: points x bones)
def read_weights(obj, bones):
    W = np.zeros((len(obj.data.vertices), len(bones)), dtype=np.float64)
    col = {obj.vertex_groups[b].index: i for i, b in enumerate(bones) if b in obj.vertex_groups}
    for v in obj.data.vertices:
        for g in v.groups:
            if g.group in col:
                W[v.index, col[g.group]] = g.weight
    return W


def write_weights(obj, bones, W):
    for g in list(obj.vertex_groups):
        obj.vertex_groups.remove(g)
    groups = [obj.vertex_groups.new(name=b) for b in bones]
    for i in range(W.shape[0]):
        for j in np.nonzero(W[i] > 1e-4)[0]:
            groups[j].add([i], float(W[i, j]), "REPLACE")


def limit_normalise(W, k=MAX_INFLUENCES):
    W = W.copy()
    if W.shape[1] > k:
        cut = np.argsort(W, axis=1)[:, :-k]
        np.put_along_axis(W, cut, 0.0, axis=1)
    W[W < 0.01] = 0.0
    s = W.sum(axis=1, keepdims=True)
    return W / np.maximum(s, 1e-9)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


NEIGHBOURS = None          # (pairs, counts) of the base mesh, set before the weights are made
SPREAD_ROUNDS = 120


def shoulder_weights(co, W, bones, spec, mode):
    """HAND-TUNED SHOULDERS (the armpit tear, CHARACTER_ART_DIRECTION.md §10.3). The R15 shoulder is ONE ball joint,
    and on these bodies its pivot sits almost straight above the armpit crease, so automatic weights squeeze the whole
    torso -> arm change into a thin band there: a raised arm pulls that band into a web of skin, and the tee (which
    copies the nearest skin's weights) comes apart there. Modes (RIG05_SHOULDERS, for comparisons):
      "spread"  (production): spread_shoulders below.
      "rig04"   build_cartoon_rig_04.shoulder_weights' rule (torso holds everything inside the joint).
      "auto"    automatic weights only.
    Measured 2026-11-13 on Fit, Muscular and Fat with the gear session's v4 tee (build_cartoon_gear_04.make_tee, in
    memory) and gear_fit_03.clearance, skin points coming through the tee: squat bar hold / arms up / double biceps /
    bench all 0 with "spread" (Fat's double biceps 4); "auto" tore in the squat bar hold (Fit 5, Fat 17); a zone-based
    version (torso only under the armpit, a short ramp at the crease) tore in every raise (23-58) and was dropped.
    Arms crossed overhead (OverheadClap) still pokes through on all of them ("spread" 25-119, "auto" 93-160)."""
    if mode == "auto":
        return W
    if mode == "rig04":
        bi = {b: i for i, b in enumerate(bones)}
        ut, piv, SH = bi["UpperTorso"], spec["pivot_x"], L["SH"]
        for sx, ua in ((1, bi["LeftUpperArm"]), (-1, bi["RightUpperArm"])):
            x, z = co[:, 0] * sx, co[:, 2]
            keep = smoothstep(piv - 0.30, piv - 0.02, x)
            sel = (z >= SH - 0.8) & (x > 0.05)
            moved = W[sel, ua] * (1 - keep[sel])
            W[sel, ua] *= keep[sel]
            W[sel, ut] += moved
        return W
    return spread_shoulders(co, W, bones, spec, SPREAD_ROUNDS)


def spread_shoulders(co, W, bones, spec, rounds):
    """The torso/upper-arm split round each shoulder SPREAD over a wide strip of skin: the arm's share is averaged
    with its neighbours `rounds` times inside the shoulder zone (the upper arm below the delt stays on the arm; outside
    the zone nothing changes, so the elbows and the waist keep their automatic weights). A raised arm then stretches
    the side of the ribs, the armpit and the top of the shoulder gradually, like a real lat and delt, instead of
    pulling one thin web of skin. No separate "torso holds the traps" rule: it left slits beside the head when the
    arms went up (tried as rig04 and as a spread variant)."""
    bi = {b: i for i, b in enumerate(bones)}
    ut = bi["UpperTorso"]
    arm_x, SH = spec["arm_x"], L["SH"]
    pairs, cnt = NEIGHBOURS
    starts = np.r_[0, np.cumsum(cnt)[:-1]]
    for sx, ua in ((1, bi["LeftUpperArm"]), (-1, bi["RightUpperArm"])):
        x, z = co[:, 0] * sx, co[:, 2]
        pool = W[:, ut] + W[:, ua]
        share = np.where(pool > 1e-6, W[:, ua] / np.maximum(pool, 1e-9), 0.0)
        zone = (x > 0.25) & (z > SH - 0.57) & (pool > 0.5)      # (= the measured zone: elbow 3.51 + 0.30)
        free = zone & ~((x > arm_x - 0.05) & (z < SH - 0.55))
        a = share.copy()
        for _ in range(rounds):
            mean = np.add.reduceat(a[pairs[:, 1]], starts) / cnt
            a = np.where(free, 0.5 * a + 0.5 * mean, a)
        W[zone, ua] = pool[zone] * a[zone]
        W[zone, ut] = pool[zone] * (1 - a[zone])
    return W


ELBOW_REACH = float(os.environ.get("RIG05_ELBOW_REACH", "0.75"))  # half-height of the elbow blend (0 = off)
ELBOW_ROUNDS = int(os.environ.get("RIG05_ELBOW_ROUNDS", "80"))
ELBOW_BACK_Y = float(os.environ.get("RIG05_ELBOW_BACK", "-0.05"))   # the blend fades in from this far behind the arm's
ELBOW_FRONT_Y = float(os.environ.get("RIG05_ELBOW_FRONT", "0.12"))  # line to fully on this far in front of it


def spread_elbows(co, W, bones, reach, rounds):
    """The upper-arm/forearm split round each elbow spread over +-reach along the arm (the forearm's share averaged
    with its neighbours inside that band; the band's ends keep their weights, so the share ramps smoothly across it).
    A bent elbow then folds its inner skin in towards the joint instead of the forearm swinging rigidly into the
    biceps (big builds' arm_in_body).
    Measured 2026-11-15 (elbow bent forward at rest, the deepest forearm/hand point inside the rest of the body, every
    point, points within 0.45 of the elbow skipped as anim_qa): BigBuff 126/130/138/148 deg 0.243/0.260/0.273/0.321
    without -> 0.015/0.058/0.142/0.258 with reach 0.75 (0.55: 0.106/0.142/0.212/0.321); Muscular 148 0.270 -> 0.191;
    Fit 148 0.145 -> 0.090. The knee-1.178 bodies were as deep (BigBuff 130: 0.286): anim_qa samples every other
    point and missed it there."""
    pairs, cnt = NEIGHBOURS
    starts = np.r_[0, np.cumsum(cnt)[:-1]]
    bi = {b: i for i, b in enumerate(bones)}
    for side in ("Left", "Right"):
        ua, la = bi[side + "UpperArm"], bi[side + "LowerArm"]
        pool = W[:, ua] + W[:, la]
        share = np.where(pool > 1e-6, W[:, la] / np.maximum(pool, 1e-9), 0.0)
        near = np.abs(co[:, 2] - L["E"])
        zone = (pool > 0.9) & (near < reach)
        free = zone & (near < reach - 0.06)
        a = share.copy()
        for _ in range(rounds):
            mean = np.add.reduceat(a[pairs[:, 1]], starts) / cnt
            a = np.where(free, 0.5 * a + 0.5 * mean, a)
        # only the INSIDE of the elbow (the front at rest, -y: the crease the forearm folds into) gets the soft blend;
        # the bony back of the elbow keeps its sharp point (a blend all round made a rubber-hose bend at 90 degrees)
        front = smoothstep(ELBOW_BACK_Y, ELBOW_FRONT_Y, -co[:, 1])
        a = share + (a - share) * front
        W[zone, la] = pool[zone] * a[zone]
        W[zone, ua] = pool[zone] * (1 - a[zone])
    return W


def mirror_weights(W, bones, mirror, co):
    """The left side's weights copied to the right twins (bone names swapped), centre points averaged."""
    swap = [bones.index(b.replace("Left", "#").replace("Right", "Left").replace("#", "Right")) for b in bones]
    out = W.copy()
    left = co[:, 0] > 1e-5
    out[mirror[left]] = W[left][:, swap]
    centre = np.abs(co[:, 0]) <= 1e-5
    out[centre] = 0.5 * (W[centre] + W[centre][:, swap])
    return out


# ---------------------------------------------------------------- one build
def make_body(build, spec, W, bones, faces_part, coll, i):
    src = bpy.data.objects["Body05_" + build]
    body = src.copy()
    body.data = src.data.copy()
    body.location = (0, 0, 0)
    body.name = build + "_Skin"
    coll.objects.link(body)
    rig, _order = R["make_rig"](build, joints(spec), coll)
    write_weights(body, bones, W)
    body.parent = rig
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    # the open hands, fully on their hand bones
    for side in ("Left", "Right"):
        h = bpy.data.objects["Body05_%s_%sHand" % (build, side)].copy()
        h.data = h.data.copy()
        h.location = (0, 0, 0)
        coll.objects.link(h)
        h.name = "%s_%s" % (build, side + "Hand")
        h.data.name = h.name
        for g in list(h.vertex_groups):
            h.vertex_groups.remove(g)
        h.vertex_groups.new(name=side + "Hand").add(list(range(len(h.data.vertices))), 1.0, "REPLACE")
        h.parent = rig
        m = h.modifiers.new("Armature", "ARMATURE")
        m.object = rig
    # split the skin into the R15 parts by the SHARED face table (the same faces in the same part on every build)
    me = body.data
    me.materials.clear()
    for part in PARTS:
        me.materials.append(bpy.data.materials.get("Split_" + part) or bpy.data.materials.new("Split_" + part))
    me.polygons.foreach_set("material_index", faces_part)
    # the whole body's smooth normals kept on every part (no shading line where it is cut; Roblox keeps them too)
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
        o.name = build + "_" + part
        o.data.name = o.name
        for p in o.data.polygons:
            p.use_smooth = True
    # stand-in head on the neck
    head = B["stand_in_head"](build + "_StandInHead", 0.0, coll)
    bpy.context.view_layer.update()
    mw = head.matrix_world.copy()
    head.parent, head.parent_type, head.parent_bone = rig, "BONE", "UpperTorso"
    bpy.context.view_layer.update()
    head.matrix_world = mw
    rig.location.x = i * SPACING
    return rig


SWAP_SHAPES = ("Fist", "Point", "ThumbsUp", "Grip", "SquatGrip")    # (SquatGrip 2026-11-14: add_squat_grip_05.py)


def grip_point(side, spec):
    """Where the bar's centre sits in the Grip hand, at rest (the hand placed like place_hand places its mesh)."""
    sx = 1 if side == "Left" else -1
    m = Matrix.Translation(Vector((sx * spec["arm_x"], 0, L["WR"]))) @ B["hand_space"](side, spec["hand"])
    return m @ Vector(HL["GRIP_C"])


def swap_hands(build, spec, rig, coll, H):
    """Fist, Point, ThumbsUp, Grip on each hand bone (hidden; the game swaps them in, HandShapeConfig). Grip: fingers
    wrapped round a bar hole; the bar's centre goes at build_cartoon_hands_04.GRIP_C in hand space (x the build's hand
    size), kept on each Grip object as "grip_point" (rest pose, in the rig's own space)."""
    made = []
    for shape in SWAP_SHAPES:
        for side in ("Left", "Right"):
            o = B["place_hand"](H[shape].data, side, spec, "%s_%s%s" % (build, shape, side), coll)
            bpy.context.view_layer.update()
            o.matrix_world = rig.matrix_world.copy()
            bpy.context.view_layer.update()
            mw = o.matrix_world.copy()
            o.parent, o.parent_type, o.parent_bone = rig, "BONE", side + "Hand"
            bpy.context.view_layer.update()
            o.matrix_world = mw
            o.hide_render = True
            if shape == "Grip":
                o["grip_point"] = list(grip_point(side, spec))         # in the rig's own space
            elif shape == "SquatGrip":                                  # (the bar in the palm heel: HEEL_C)
                sx = 1 if side == "Left" else -1
                m = Matrix.Translation(Vector((sx * spec["arm_x"], 0, L["WR"]))) @ B["hand_space"](side, spec["hand"])
                o["grip_point"] = list(m @ Vector(HL["HEEL_C"]))
            made.append(o)
    return made


# ---------------------------------------------------------------- main
coll = bpy.data.collections.new("CartoonRig")
bpy.context.scene.collection.children.link(coll)
swap_coll = bpy.data.collections.new("SwapHands05")
bpy.context.scene.collection.children.link(swap_coll)
specs = {b: B["body_spec"](b) for b in ORDER}

# 1) automatic weights on the base build
base_src = bpy.data.objects["Body05_" + BASE]
base = base_src.copy()
base.data = base_src.data.copy()
base.location = (0, 0, 0)
coll.objects.link(base)
base_rig, order = R["make_rig"]("WeightBase", joints(specs[BASE]), coll)
bpy.ops.object.select_all(action="DESELECT")
base.select_set(True)
base_rig.select_set(True)
bpy.context.view_layer.objects.active = base_rig
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
bones = list(order)
co = np.array([v.co for v in base.data.vertices], dtype=np.float64)
W = read_weights(base, bones)
missing = np.nonzero(W.sum(axis=1) < 1e-6)[0]
for i in missing:                                      # any point left without a bone: its nearest bone
    best = min(range(len(bones)), key=lambda j: (Vector(co[i]) - (base_rig.data.bones[bones[j]].head_local +
                                                                   base_rig.data.bones[bones[j]].tail_local) / 2).length)
    W[i, best] = 1.0
log("automatic weights; points without a bone fixed:", len(missing))
# the body keeps no weight on the hand bones (the hand part is exactly the hand mesh; a swap replaces it whole)
for side in ("Left", "Right"):
    W[:, bones.index(side + "LowerArm")] += W[:, bones.index(side + "Hand")]
    W[:, bones.index(side + "Hand")] = 0.0
W = limit_normalise(W)
NEIGHBOURS = B["neighbour_table"](base.data)
W = shoulder_weights(co, W, bones, specs[BASE], SHOULDER_MODE)
if ELBOW_REACH > 0:
    W = spread_elbows(co, W, bones, ELBOW_REACH, ELBOW_ROUNDS)
mirror, worst = B["mirror_map"](co.astype(np.float32))
log("mirror twins, worst %.5f" % worst)
W = mirror_weights(W, bones, mirror, co)
W = limit_normalise(W)
# the shared part table: each face goes to the bone most of its points follow
main = np.argmax(W, axis=1)
faces_part = np.zeros(len(base.data.polygons), dtype=np.int32)
for f in base.data.polygons:
    votes = {}
    for vi in f.vertices:
        p = bones[main[vi]]
        votes[p] = votes.get(p, 0) + 1
    faces_part[f.index] = PARTS.index(max(votes.items(), key=lambda kv: kv[1])[0])
np.save(os.path.join(os.environ.get("TEMP", "."), "rig05_weights.npy"), W)
bpy.data.objects.remove(base, do_unlink=True)
bpy.data.objects.remove(base_rig, do_unlink=True)

# 2) every build: the same weights, the same split
HL = B["load_hands"]()
H = {s: HL["make_hand"](s, swap_coll, name="Hand04_" + s) for s in SWAP_SHAPES}
for i, build in enumerate(ORDER):
    rig = make_body(build, specs[build], W, bones, faces_part, coll, i)
    swap_hands(build, specs[build], rig, swap_coll, H)
    tris = sum(B["triangles"](o) for o in coll.objects if o.type == "MESH" and o.name.startswith(build + "_")
               and not o.name.endswith("StandInHead"))
    log(build, "parts + open hands:", tris, "triangles")
for o in H.values():
    bpy.data.objects.remove(o, do_unlink=True)

# only the rigged set stays in this file
for o in list(bpy.data.objects):
    if coll not in o.users_collection and swap_coll not in o.users_collection:
        bpy.data.objects.remove(o, do_unlink=True)
for c in list(bpy.data.collections):
    if c not in (coll, swap_coll):
        bpy.data.collections.remove(c)
bpy.data.orphans_purge(do_recursive=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT)
log("saved", OUT, "shoulders:", SHOULDER_MODE)
