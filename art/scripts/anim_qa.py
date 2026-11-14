# Animation quality check (References/Character Animation Quality.md, "Validation"): plays ONE animation on the
# production bodies (art/blender/CartoonBodies_05_Rigged.blend: <Build>Rig + <Build>_<Part>, swap fists in
# SwapHands05) and
#   - renders the chosen moments from the front, side, three-quarter and back, the three representative builds side by
#     side (Skinny, Fat, Muscular by default), one ROW PER ANIMATION FOLDER, so a "before" and an "after" folder give a
#     before/after comparison of the same moment from the same cameras;
#   - measures EVERY keyframe on every build and prints/writes a table:
#       arm_in_body   deepest point of a lower arm / hand inside the torso, head or legs (studs; contact on purpose,
#                     like a chest slap, shows here too: read it with the picture)
#       upper_in_head deepest point of an upper arm (away from its shoulder) inside the head or the torso's top
#       bar_in_body   deepest point of the bar shaft inside the body (hands excluded)
#       hand_to_bar   while a hand grips: its centre's distance from the bar's axis
#       elbow         elbow bend (degrees; 0 = straight) of each arm
#       foot_floor    lowest foot point below the floor; foot_slide: a planted ankle moving between keyframes
#       pop           the fastest joint turn between keyframes (degrees per second): a jump/hitch in the motion
#     and for lifts the mechanics (from the joints): shin lean (+ = knee ahead of the ankle), hip above knee, back angle
#     from vertical, arm angle from vertical (+ = hand behind the shoulder), shoulder ahead of the bar, bar ahead of the
#     midfoot, body's centre (surface-weighted) ahead of the midfoot.
#   PASS numbers never replace a look at the pictures.
# READ-ONLY: the .blend is opened and NOT saved.
#   set QA_ANIM=Setup_Deadlift
#   set QA_FOLDERS=Before=D:\some\folder;After=D:\Powerlifting Roblox\art\animations   (default: Now=art/animations)
#   set QA_TIMES=2.0:hinging down,2.6:grip,3.3:set      (default: start, middle, hardest, end)
#   (optional) QA_BUILDS=Skinny,Fat,Muscular  QA_VIEWS=front,side,threequarter,back  QA_BAR=deadlift|none
#   blender -b art/blender/CartoonBodies_05_Rigged.blend --python art/scripts/anim_qa.py -- <out_dir>
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
OUT = sys.argv[sys.argv.index("--") + 1]
TILES = os.path.join(OUT, "tiles")
os.makedirs(TILES, exist_ok=True)
ANIM = os.environ["QA_ANIM"]
FOLDERS = [tuple(f.split("=", 1)) for f in os.environ.get(
    "QA_FOLDERS", "Now=" + os.path.join(ROOT, "art", "animations")).split(";") if f]
BUILDS = os.environ.get("QA_BUILDS", "Skinny,Fat,Muscular").split(",")
VIEWS = os.environ.get("QA_VIEWS", "front,side,threequarter,back").split(",")
BAR_MODE = os.environ.get("QA_BAR", "bar" if ("Deadlift" in ANIM or "Squat" in ANIM) else "none")
# when the game draws the bar in the hands (StationAnimationConfig / setup_animations.BAR_HELD_AT); else it rests
HELD = {"Station_Deadlift": (1.6, 4.3), "Station_Squat": (0.0, 99.0), "Setup_Squat": (3.1, 99.0)}.get(ANIM)
# where it rests otherwise, from the root's floor point (Roblox: up, and -Z = in front): the deadlift's floor bar 1.0 up
# and 0.6 in front; the squat's J-cups (torso rig: StationLayout + tallSquatJCupRaise 0.525 -> 4.19 up) 1.32 in front
# of where the setup ends (setup_animations BAR_SQUAT z -0.28, SQUAT_FINAL_Z -1.6)
BAR_REST = Vector((0, 4.19, -1.32)) if "Squat" in ANIM else Vector((0, 1.0, -0.6))

# WHAT-IF ONLY: QA_ARM_STRETCH=1.25 makes every upper and lower arm that much longer IN MEMORY (bones and skin below the
# shoulder joint; hands keep their size) to preview a proportion change on the real bodies. Never saved.
ARM_STRETCH = float(os.environ.get("QA_ARM_STRETCH", "0") or 0)
# EXTRA ROWS: QA_EXTRA_ROWS=Tag=<tiles folder of another run> adds that run's tiles of the same moments as more rows
EXTRA = [tuple(f.split("=", 1)) for f in os.environ.get("QA_EXTRA_ROWS", "").split(";") if f]

G = {"__name__": "gear_fit_03"}
exec(open(os.path.join(SCRIPTS, "gear_fit_03.py")).read(), G)
TO_B, PARENT = G["TO_B"], G["PARENT"]
rigs = {b: bpy.data.objects[b + "Rig"] for b in BUILDS}
others = [o for o in bpy.data.objects if o.type == "ARMATURE" and o.name.endswith("Rig") and o.name[:-3] not in BUILDS]
for o in others:
    o.location = (500, 500, 0)                # (the other builds out of every picture)


def stretch_arms(b, k):
    rig = rigs[b]
    G["rest_rig"](rig)
    for side in ("Left", "Right"):
        top = rig.data.bones[side + "UpperArm"].head_local.z
        wrist = rig.data.bones[side + "Hand"].head_local.z
        drop = (top + (wrist - top) * k) - wrist

        def f(p, top=top, wrist=wrist, drop=drop):
            p = Vector(p)
            if p.z >= top:
                return p
            if p.z >= wrist:
                return Vector((p.x, p.y, top + (p.z - top) * k))
            return p + Vector((0, 0, drop))
        moved = {}
        for name in ("UpperArm", "LowerArm", "Hand"):
            o = bpy.data.objects["%s_%s%s" % (b, side, name)]
            m = rig.matrix_world.inverted() @ o.matrix_world
            mi = m.inverted()
            for v in o.data.vertices:
                p = m @ v.co
                moved[tuple(round(c, 4) for c in p)] = f(p)
                v.co = mi @ f(p)
        # the torso's side of the arm seam (the same points, split into another part) moves with the arm: no crack
        for name in ("UpperTorso", "LowerTorso"):
            o = bpy.data.objects["%s_%s" % (b, name)]
            m = rig.matrix_world.inverted() @ o.matrix_world
            mi = m.inverted()
            for v in o.data.vertices:
                key = tuple(round(c, 4) for c in (m @ v.co))
                if key in moved:
                    v.co = mi @ moved[key]
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode="EDIT")
        for name in ("UpperArm", "LowerArm", "Hand"):
            eb = rig.data.edit_bones[side + name]
            eb.head, eb.tail = f(eb.head), f(eb.tail)
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()


if ARM_STRETCH:
    for b in BUILDS:
        stretch_arms(b, ARM_STRETCH)
J = {b: {bone.name: TO_B @ bone.head_local for bone in rigs[b].data.bones} for b in BUILDS}   # rest joints, Roblox
coll = bpy.data.collections.new("AnimQA")
bpy.context.scene.collection.children.link(coll)


def material(name, rgba):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = rgba
    return m


def cylinder(name, radius, depth, rgba, verts=20):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, vertices=verts)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material(name + "Mat", rgba))
    for c in o.users_collection:
        c.objects.unlink(o)
    coll.objects.link(o)
    return o


# ---------------------------------------------------------------- the bar (shaft 7.2 long, plates 1.0 in radius
# so the bar's centre sits 1.0 up when they stand on the floor; small end markers for the side view)
bars = {}
for b in BUILDS:
    shaft = cylinder(b + "_QABar", 0.07, 5.0, (0.6, 0.61, 0.65, 1), 16)     # (cut short: neighbours stay clear)
    plates = [cylinder("%s_QAPlate%d" % (b, i), 1.0, 0.22, (0.75, 0.12, 0.1, 1), 40) for i in range(2)]
    marks = [cylinder("%s_QAMark%d" % (b, i), 0.13, 0.05, (0.85, 0.15, 0.1, 1), 16) for i in range(2)]
    bars[b] = (shaft, plates, marks)
floor = cylinder("QAFloor", 60, 0.02, (0.34, 0.35, 0.38, 1), 8)
floor.location = (0, 0, -0.011)


def place_bar(b, centre_b, shown, view):
    """centre_b: the bar's centre in Blender world; the bar runs along the rig's X."""
    shaft, plates, marks = bars[b]
    rot = rigs[b].matrix_world.to_3x3() @ Matrix.Rotation(math.radians(90), 3, "Y")
    for o in [shaft] + plates + marks:
        o.hide_render = not shown
    if not shown:
        return
    shaft.matrix_world = Matrix.Translation(centre_b) @ rot.to_4x4()
    side = rigs[b].matrix_world.to_3x3() @ Vector((1, 0, 0))
    for i, s in enumerate((-1, 1)):
        plates[i].matrix_world = Matrix.Translation(centre_b + side * s * 2.35) @ rot.to_4x4()
        marks[i].matrix_world = Matrix.Translation(centre_b + side * s * 1.95) @ rot.to_4x4()
        plates[i].hide_render = view in ("side", "inside")   # (a plate would hide the shins from the side)
        marks[i].hide_render = view not in ("side", "inside") or bool(FOCUS)


# ---------------------------------------------------------------- posing and the joint frames
def frames_of(b, transforms):
    """Every part's frame (rig-local ROBLOX space) as gear_fit_03.pose_rig poses it: a rest point p of a part goes
    to world[part] @ (p - J[part])."""
    j = J[b]
    world = {"HumanoidRootNode": Matrix.Translation(j["HumanoidRootNode"])}
    for part in ["LowerTorso", "UpperTorso"] + [s + p for s in ("Left", "Right") for p in
                                                 ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")]:
        par = PARENT[part]
        world[part] = world[par] @ Matrix.Translation(j[part] - j[par]) @ transforms.get(part, Matrix.Identity(4))
    return world


def at(b, world, part, rest_point):
    return world[part] @ (Vector(rest_point) - J[b][part])


def axis(world, part):
    return (world[part].to_3x3() @ Vector((0, -1, 0))).normalized()     # a limb's long axis (it hangs down at rest)


def to_blender(b, v):
    return rigs[b].matrix_world @ (TO_B @ Vector(v))


def to_roblox(b, v):
    return TO_B @ (rigs[b].matrix_world.inverted() @ Vector(v))


def hand_centre(b, world, side):
    return at(b, world, side + "Hand", J[b][side + "Hand"] + Vector((0, -0.125, 0)))


# Where a hand holds the bar: the "Grip" swap's hole (build_cartoon_hands_04.py hand space (0, -0.197, -0.40)) at each
# build's OWN hand size (build_cartoon_body_05.py), so a shared animation's per-build mismatch shows in hand_to_bar.
# QA_GRIP_POINT=0 measures from the hand's centre instead (the old fist).
HAND_SIZE = {"Skinny": 1.05, "SkinnyFat": 1.12, "Fit": 1.22, "Fat": 1.30, "Muscular": 1.50, "BigBuff": 1.58}
USE_GRIP_POINT = os.environ.get("QA_GRIP_POINT", "1") != "0"


def grip_at(b, world, side):
    if not USE_GRIP_POINT:
        return hand_centre(b, world, side)
    size = HAND_SIZE.get(b, 1.22)
    d, h = 0.135 * size + 0.07, 0.34 * size - 0.125
    local = Vector((d if side == "Left" else -d, -0.125 - h, 0))
    return at(b, world, side + "Hand", J[b][side + "Hand"] + local)


def bar_centre(b, world, t):
    """The bar's centre (rig-local Roblox) as the game draws it: in the hands while held, else resting."""
    if BAR_MODE == "none":
        return None
    if HELD and HELD[0] <= t < HELD[1]:
        return (grip_at(b, world, "Left") + grip_at(b, world, "Right")) / 2      # (the game: grip attachments, Phase 4)
    return BAR_REST - Vector((0, 0, body_shift(b)))      # (the bar stays put when a body is shifted)


def gripping(b, world, side, bar):
    if bar is None:
        return False
    h = grip_at(b, world, side)
    return Vector((0, h.y - bar.y, h.z - bar.z)).length < 0.35


# ---------------------------------------------------------------- PER-BODY HAND CORRECTION (preview of the game's IK)
# A folder given as "<path>@ik" plays the animation, then moves each body's hands onto ITS OWN targets, as the game's
# per-build hand IK will (References/Character Animation Quality.md §3.3): the squat bar on that body's own upper back
# (its back depth) at a grip outside its own shoulders, and on the setup's J-cup bar the body stands its own back depth
# closer/further so the bar meets its back. The arm turns by the least that does it; the hand keeps its turn.
SQUAT_BACK = {"Skinny": 0.39, "SkinnyFat": 0.437, "Fat": 0.58, "Fit": 0.556, "Muscular": 0.621, "BigBuff": 0.72}
SQUAT_DELT = {"Skinny": 1.23, "SkinnyFat": 1.34, "Fat": 1.73, "Fit": 1.55, "Muscular": 1.85, "BigBuff": 2.03}
SQUAT_BAR_Y, SHARED_BACK = 4.30, 0.556
IK_ON = [False]


EXTRA_BACK = {}            # per body: how much further out the bar must sit, measured on the posed back (calibrate)


def bar_spot_z(b):
    return SQUAT_BACK.get(b, SHARED_BACK) + 0.08 + EXTRA_BACK.get(b, 0.0)


def body_shift(b):
    """Roblox +Z (backward) shift of the whole body so the setup's J-cup bar meets this body's back."""
    return ((SHARED_BACK + 0.08) - bar_spot_z(b)) if (IK_ON[0] and ANIM == "Setup_Squat") else 0.0


def _rot(ax, ay, az):
    return (Matrix.Rotation(math.radians(ax), 4, "X") @ Matrix.Rotation(math.radians(ay), 4, "Y")
            @ Matrix.Rotation(math.radians(az), 4, "Z"))


def build_ik(b, frames, t, force_held=False):
    if not (IK_ON[0] or force_held) or "Squat" not in ANIM or b not in SQUAT_BACK:
        return frames
    world = frames_of(b, frames)
    held = force_held or (HELD and HELD[0] <= t < HELD[1])
    size = HAND_SIZE.get(b, 1.22)
    d, h = 0.135 * size + 0.07, 0.34 * size - 0.125
    out = dict(frames)
    for side, s in (("Left", -1), ("Right", 1)):
        gx = SQUAT_DELT[b] + 0.32
        if held:
            goal = at(b, world, "UpperTorso", Vector((s * gx, SQUAT_BAR_Y, bar_spot_z(b))))
        else:
            goal = BAR_REST - Vector((0, 0, body_shift(b))) + Vector((s * gx, 0, 0))
        cur = grip_at(b, world, side)
        w = max(0.0, min(1.0, (0.7 - (cur - goal).length) / 0.3))          # (only once the hand is at the bar)
        if w <= 0:
            continue
        goal = cur.lerp(goal, w)
        rot = world[side + "Hand"].to_3x3()
        local = Vector((d if side == "Left" else -d, -0.125 - h, 0))
        sh0, el0 = out.get(side + "UpperArm", Matrix.Identity(4)), out.get(side + "LowerArm", Matrix.Identity(4))

        def apply(q):
            f = dict(out)
            f[side + "UpperArm"] = sh0 @ _rot(q[0], q[1], q[2])
            f[side + "LowerArm"] = el0 @ Matrix.Rotation(math.radians(q[3]), 4, "X")
            wf = frames_of(b, f)
            lower = wf[side + "LowerArm"].to_3x3()
            f[side + "Hand"] = (lower.transposed() @ rot).to_4x4()
            return f, wf[side + "Hand"].to_translation() + rot @ local

        def cost(q):
            _f, grip = apply(q)
            return 20.0 * (grip - goal).length + 0.002 * sum(abs(v) for v in q)
        q, best = [0.0, 0.0, 0.0, 0.0], cost([0.0, 0.0, 0.0, 0.0])
        for step in (8, 4, 2, 1, 0.5, 0.25, 0.1):
            improved = True
            while improved:
                improved = False
                for i in range(4):
                    for dv in (step, -step):
                        r = list(q)
                        r[i] += dv
                        c = cost(r)
                        if c < best - 1e-7:
                            q, best, improved = r, c, True
        out = apply(q)[0]
    return out


GRIP_SHAPE = "Grip" if bpy.data.objects.get("%s_GripLeft" % BUILDS[0]) else "Fist"      # (the Grip swap once it exists)


# QA_SHAPES="Right:Point:2.4:2.85;Left:Fist:0.2:1.0": the game's other hand swaps (HandShapeConfig) in those spans
SHAPE_SPANS = [(f.split(":")[0], f.split(":")[1], float(f.split(":")[2]), float(f.split(":")[3]))
               for f in os.environ.get("QA_SHAPES", "").split(";") if f]


def set_hands(b, fist, t=None):
    for side in ("Left", "Right"):
        shape = GRIP_SHAPE if fist[side] else None
        for sd, sh, t0, t1 in SHAPE_SPANS:
            if sd == side and t is not None and t0 <= t < t1:
                shape = sh
        bpy.data.objects["%s_%sHand" % (b, side)].hide_render = shape is not None
        for s in ("Fist", "Grip", "Point", "ThumbsUp"):
            o = bpy.data.objects.get("%s_%s%s" % (b, s, side))
            if o:
                o.hide_render = s != shape


def visible_hand(b, side):
    for s in ("Grip", "Fist", "Point", "ThumbsUp"):
        o = bpy.data.objects.get("%s_%s%s" % (b, s, side))
        if o and not o.hide_render:
            return o
    return bpy.data.objects["%s_%sHand" % (b, side)]


# ---------------------------------------------------------------- mesh tests
def surface(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    verts, polys = [], []
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        base = len(verts)
        verts += [o.matrix_world @ v.co for v in me.vertices]
        polys += [tuple(base + i for i in p.vertices) for p in me.polygons]
        ev.to_mesh_clear()
    return BVHTree.FromPolygons(verts, polys) if polys else None, verts


def deepest(points, tree, reach=0.6):
    """How deep the deepest of these points sits under the tree's surface (its outward normals; parts are open at the
    joint cuts, so only points within reach of the surface count)."""
    worst = 0.0
    if tree is None:
        return worst
    for p in points:
        loc, nrm, _i, d = tree.find_nearest(p, reach)
        if loc is not None and (p - loc).dot(nrm) < 0:
            worst = max(worst, d)
    return worst


RAY_DIRS = [Vector(d).normalized() for d in ((0.31, 0.93, 0.19), (-0.27, -0.35, 0.9), (0.12, -0.95, -0.29))]


def inside_depth(points, tree, skip=None):
    """The deepest of `points` INSIDE the closed-ish surface `tree` (ray parity, majority of three directions: robust
    next to thin parts, unlike a nearest-normal test), as its distance to the surface. skip(p) -> True ignores a point."""
    worst = 0.0
    if tree is None:
        return worst
    for p in points:
        if skip and skip(p):
            continue
        votes = 0
        for d in RAY_DIRS:
            o, n = p, 0
            for _ in range(24):
                hit = tree.ray_cast(o, d, 20.0)
                if hit[0] is None:
                    break
                n += 1
                o = hit[0] + d * 1e-4
            votes += n % 2
        if votes >= 2:
            loc, _n, _i, dist = tree.find_nearest(p, 2.0)
            if loc is not None:
                worst = max(worst, dist)
    return worst


def part(b, name):
    return bpy.data.objects["%s_%s" % (b, name)]


def mesh_numbers(b, world, bar_r):
    body = [part(b, n) for n in ("UpperTorso", "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg",
                                 "RightLowerLeg")]
    head = bpy.data.objects.get(b + "_StandInHead")
    torso_head, _v = surface(body[:2] + ([head] if head else []))
    legs_t, _l = surface(body[2:])
    out = {}
    worst = 0.0
    names = ["UpperTorso", "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
             "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftFoot", "RightFoot"]
    for side in ("Left", "Right"):
        other = "Right" if side == "Left" else "Left"
        rest = [part(b, n) for n in names if n != side + "LowerArm"] + [visible_hand(b, other)] + ([head] if head else [])
        tree, _r = surface(rest)
        _t, pts = surface([part(b, side + "LowerArm"), visible_hand(b, side)])
        elbow = to_blender(b, at(b, world, side + "LowerArm", J[b][side + "LowerArm"]))
        worst = max(worst, inside_depth(pts[::2], tree, lambda q, e=elbow: (q - e).length < 0.45))   # (elbow fold)
    out["arm_in_body"] = worst
    up = 0.0
    for side in ("Left", "Right"):
        sh = to_blender(b, at(b, world, side + "UpperArm", J[b][side + "UpperArm"]))
        _t, pts = surface([part(b, side + "UpperArm")])
        far = [p for p in pts if (p - sh).length > 0.75]
        top, _x = surface([head] if head else [])
        up = max(up, deepest(far, top))
    out["upper_in_head"] = up
    if bar_r is not None:
        whole, _w = surface(body + [part(b, s + n) for s in ("Left", "Right") for n in ("UpperArm", "LowerArm", "Foot")])
        side = rigs[b].matrix_world.to_3x3() @ Vector((1, 0, 0))
        c = to_blender(b, bar_r)
        shaft = [c + side * (x / 20.0) for x in range(-36, 37)]
        out["bar_in_body"] = deepest(shaft, whole, 0.4)
    else:
        out["bar_in_body"] = 0.0
    _f, fv = surface([part(b, "LeftFoot"), part(b, "RightFoot")])
    out["foot_floor"] = max(0.0, -min(v.z for v in fv))
    return out


def angle_of(m):
    return math.degrees(m.to_quaternion().angle)


def mechanics(b, world, bar_r):
    j = J[b]
    p = lambda name: at(b, world, name, j[name])
    mid = lambda a, c: (a + c) / 2
    ankle, knee, hip = mid(p("LeftFoot"), p("RightFoot")), mid(p("LeftLowerLeg"), p("RightLowerLeg")), \
        mid(p("LeftUpperLeg"), p("RightUpperLeg"))
    shoulder = mid(p("LeftUpperArm"), p("RightUpperArm"))
    fwd = Vector((0, 0, -1))                  # the body faces -Z (Roblox)
    out = {"shin_lean": (knee - ankle).dot(fwd), "hip_above_knee": hip.y - knee.y,
           "back": math.degrees(math.atan2((shoulder - hip).dot(fwd), (shoulder - hip).y))}
    arm = 0.0
    elbows = []
    for side in ("Left", "Right"):
        ua, la = axis(world, side + "UpperArm"), axis(world, side + "LowerArm")
        elbows.append(math.degrees(ua.angle(la)))
        arm += math.degrees(math.atan2(-((ua + la).dot(fwd)), -(ua + la).y)) / 2
    out["elbow"] = max(elbows)
    out["arm_from_vertical"] = arm
    if bar_r is not None:
        top = mid(at(b, world, "LeftUpperArm", j["LeftUpperArm"] + Vector((-0.5, 0, 0))),
                  at(b, world, "RightUpperArm", j["RightUpperArm"] + Vector((0.5, 0, 0))))
        out["shoulder_ahead_of_bar"] = (top - bar_r).dot(fwd)
        out["bar_ahead_of_midfoot"] = (bar_r - ankle).dot(fwd) - FOOT_MID[b]
    return out


# the midfoot (half way from heel to toe) relative to the ankle joint, from each build's foot at rest
FOOT_MID = {}
for b in BUILDS:
    G["rest_rig"](rigs[b])
    _f, fv = surface([part(b, "LeftFoot")])
    zs = [to_roblox(b, v).z for v in fv]
    FOOT_MID[b] = -((min(zs) + max(zs)) / 2 - J[b]["LeftFoot"].z)      # + = ahead of the ankle


def centre_ahead(b):
    pts = []
    for n in ("UpperTorso", "LowerTorso") + tuple(s + q for s in ("Left", "Right") for q in
                                                  ("UpperArm", "LowerArm", "UpperLeg", "LowerLeg", "Foot")):
        _t, v = surface([part(b, n)])
        pts += v
    head = bpy.data.objects.get(b + "_StandInHead")
    c = sum((to_roblox(b, v) for v in pts), Vector()) / len(pts)
    return c


# ---------------------------------------------------------------- pictures
sc = bpy.context.scene
try:
    sc.render.engine = "BLENDER_WORKBENCH"
except TypeError as e:
    print("engine", e)
sh = sc.display.shading
sh.light, sh.color_type, sh.show_backface_culling, sh.show_cavity = "STUDIO", "MATERIAL", True, True
sh.cavity_type = "WORLD"
sh.cavity_ridge_factor, sh.cavity_valley_factor = 0.6, 1.0
sh.background_type = "VIEWPORT"
sh.background_color = (0.16, 0.17, 0.2)
sc.render.image_settings.file_format = "PNG"
cd = bpy.data.cameras.new("AnimQACam")
cd.type = "ORTHO"
cd.clip_end = 300
cam = bpy.data.objects.new("AnimQACam", cd)
coll.objects.link(cam)
sc.camera = cam
label_curve = bpy.data.curves.new("AnimQALabel", "FONT")
label = bpy.data.objects.new("AnimQALabel", label_curve)
label_curve.size = 0.4
label.data.materials.append(material("AnimQALabelMat", (0.95, 0.95, 0.9, 1)))
coll.objects.link(label)
label.parent = cam
TILE = (900, 470)
# CLOSE-UP: QA_FOCUS=Left|Right frames that hand of the FIRST build (QA_BUILDS=Muscular for one build), QA_FOCUS_SCALE
# the picture's width in studs (default 1.4); extra views "top" and "below" for grips
FOCUS = os.environ.get("QA_FOCUS", "")
FOCUS_AT = []
if FOCUS:
    TILE = (640, 640)
GAP = 5.3
VIEW = {  # direction from the target to the camera (Blender: the lifters face -Y), how builds are spread
    "front": ((0.0, -1.0, 0.16), "x"), "back": ((0.0, 1.0, 0.22), "x"),
    "threequarter": ((-0.75, -1.0, 0.3), "x"), "side": ((-1.0, 0.0, 0.06), "y"),
    "inside": ((1.0, 0.0, 0.06), "y"), "top": ((0.05, -0.3, 1.0), "x"), "below": ((0.05, -0.4, -1.0), "x")}


def place(view):
    spread = VIEW[view][1]
    for i, b in enumerate(BUILDS):
        rigs[b].matrix_world = Matrix.Translation(Vector((i * GAP, 0, 0) if spread == "x" else (0, -i * GAP * 1.05, 0))
                                                  + TO_B.to_3x3() @ Vector((0, 0, body_shift(b))))


def shoot(path, text, view):
    direction, spread = VIEW[view]
    n = len(BUILDS) - 1
    target = Vector((n * GAP / 2, 0, 2.3)) if spread == "x" else Vector((0, -n * GAP * 1.05 / 2 - 0.7, 2.3))
    scale = n * GAP + 5.4
    floor.hide_render = view == "below"
    if FOCUS_AT:                                   # (close-up: QA_FOCUS)
        target, scale = FOCUS_AT[0], float(os.environ.get("QA_FOCUS_SCALE", "1.4"))
    cd.ortho_scale = scale
    sc.render.resolution_x, sc.render.resolution_y = TILE
    cam.location = target + Vector(direction).normalized() * 60
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    label_curve.body = text
    label_curve.size = 0.4 if not FOCUS_AT else scale * 0.035
    label.location = (-scale / 2 + scale * 0.015, scale * TILE[1] / TILE[0] / 2 - label_curve.size * 1.35, -5)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def pose_all(folder, t, view):
    IK_ON[0] = folder.endswith("@ik")
    G["ANIMS"] = folder[:-3] if IK_ON[0] else folder
    G["_ANIM_CACHE"].clear()
    frames0 = G["anim_at"](ANIM, t)
    place(view)
    for b in BUILDS:
        frames = build_ik(b, frames0, t)
        G["pose_rig"](rigs[b], frames)
        world = frames_of(b, frames)
        bar = bar_centre(b, world, t)
        set_hands(b, {s: gripping(b, world, s, bar) for s in ("Left", "Right")}, t)
        place_bar(b, to_blender(b, bar) if bar is not None else None, bar is not None, view)
        if FOCUS and b == BUILDS[0]:
            FOCUS_AT[:] = [to_blender(b, grip_at(b, world, FOCUS))]
    bpy.context.view_layer.update()


# ---------------------------------------------------------------- the numbers over every keyframe
def all_numbers(folder):
    IK_ON[0] = folder.endswith("@ik")
    G["ANIMS"] = folder[:-3] if IK_ON[0] else folder
    G["_ANIM_CACHE"].clear()
    keys = G["read_anim"](ANIM)
    place("front")
    rows = []
    prev = {}
    for t, frames0 in keys:
        row = {"t": t}
        for b in BUILDS:
            frames = build_ik(b, frames0, t)
            G["pose_rig"](rigs[b], frames)
            world = frames_of(b, frames)
            bar = bar_centre(b, world, t)
            fist = {s: gripping(b, world, s, bar) for s in ("Left", "Right")}
            set_hands(b, fist, t)
            bpy.context.view_layer.update()
            n = mesh_numbers(b, world, bar)
            n.update(mechanics(b, world, bar))
            n["hand_to_bar"] = max([Vector((0, (grip_at(b, world, s) - bar).y, (grip_at(b, world, s) - bar).z)).length
                                    for s in ("Left", "Right") if fist[s]] or [0.0])
            c = centre_ahead(b)
            ankle = (at(b, world, "LeftFoot", J[b]["LeftFoot"]) + at(b, world, "RightFoot", J[b]["RightFoot"])) / 2
            n["centre_ahead_of_midfoot"] = -(c.z - ankle.z) - FOOT_MID[b]
            slide, pop = 0.0, 0.0
            if b in prev:
                pt, pw, pf = prev[b]
                for s in ("Left", "Right"):
                    a0, a1 = at(b, pw, s + "Foot", J[b][s + "Foot"]), at(b, world, s + "Foot", J[b][s + "Foot"])
                    if a0.y < 0.3 and a1.y < 0.3:
                        slide = max(slide, Vector((a1.x - a0.x, 0, a1.z - a0.z)).length)
                dt = max(1e-3, t - pt)
                for k, m in frames.items():
                    if k in pf:
                        turn = math.degrees((pf[k].to_quaternion().rotation_difference(m.to_quaternion())).angle)
                        pop = max(pop, min(turn, 360.0 - turn) / dt)      # (q and -q are the same turn)
            n["foot_slide"], n["pop"] = slide, pop
            prev[b] = (t, world, frames)
            row[b] = n
        rows.append(row)
    return rows


def calibrate_squat_backs(folder):
    """Per body: push the squat bar out from the back until it no longer sinks into the POSED back (raised arms bunch
    the delts and traps up past the rest-pose depth). Uses Station_Squat standing from `folder`."""
    G["ANIMS"] = folder
    G["_ANIM_CACHE"].clear()
    if not os.path.exists(os.path.join(folder, "Station_Squat.rbxmx")):
        return
    frames0 = G["anim_at"]("Station_Squat", 0.0)
    place("front")
    for b in BUILDS:
        EXTRA_BACK[b] = 0.0
        for _ in range(4):
            fr = build_ik(b, frames0, 0.0, force_held=True)
            G["pose_rig"](rigs[b], fr)
            bpy.context.view_layer.update()
            world = frames_of(b, fr)
            bar = to_blender(b, (grip_at(b, world, "Left") + grip_at(b, world, "Right")) / 2)
            body = [part(b, n) for n in ("UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm")]
            tree, _v = surface(body)
            side = rigs[b].matrix_world.to_3x3() @ Vector((1, 0, 0))
            shaft = [bar + side * (x / 20.0) for x in range(-30, 31)]
            sunk = deepest(shaft, tree, 0.4)
            if sunk < 0.01:
                break
            EXTRA_BACK[b] += sunk + 0.005
        print("[AnimQA] squat bar depth", b, "back %.3f + bar 0.08 + posed %.3f = %.3f" % (
            SQUAT_BACK[b], EXTRA_BACK[b], bar_spot_z(b)))


if "Squat" in ANIM and any(f.endswith("@ik") for _t, f in FOLDERS):
    calibrate_squat_backs(next(f for _t, f in FOLDERS if f.endswith("@ik"))[:-3])


KEYS = ["arm_in_body", "upper_in_head", "bar_in_body", "hand_to_bar", "elbow", "foot_floor", "foot_slide", "pop",
        "shin_lean", "hip_above_knee", "back", "arm_from_vertical", "shoulder_ahead_of_bar", "bar_ahead_of_midfoot",
        "centre_ahead_of_midfoot"]
report = ["# %s quality numbers (anim_qa.py, %s)\n" % (ANIM, ", ".join(BUILDS)),
          "Studs and degrees. Every keyframe was measured; the moments below are the pictured ones, then the worst "
          "over the whole animation. Numbers flag problems; only the pictures say whether it looks right.\n"]
moments = None
for tag, folder in FOLDERS:
    rows = all_numbers(folder)
    if moments is None:
        spec = os.environ.get("QA_TIMES", "")
        if spec:
            moments = [(float(s.split(":")[0]), s.split(":", 1)[1] if ":" in s else "") for s in spec.split(",")]
        else:
            ts = [r["t"] for r in rows]
            moments = [(ts[0], "start"), (ts[len(ts) // 2], "middle"), (G["extreme_time"](ANIM), "hardest"), (ts[-1], "end")]
    report.append("\n## %s (%s)\n" % (tag, folder))
    for t, note in moments:
        r = min(rows, key=lambda x: abs(x["t"] - t))
        report.append("\n**t %.2f %s**\n\n| | %s |\n|---|%s\n" % (r["t"], note, " | ".join(KEYS), "---|" * len(KEYS)))
        for b in BUILDS:
            report.append("| %s | %s |\n" % (b, " | ".join("%.2f" % r[b].get(k, float("nan")) if k in r[b] else "-" for k in KEYS)))
    report.append("\n**worst over the animation**\n\n| | arm_in_body | upper_in_head | bar_in_body | hand_to_bar | "
                  "foot_floor | foot_slide | pop (deg/s) |\n|---|---|---|---|---|---|---|---|\n")
    for b in BUILDS:
        w = {k: max(rows, key=lambda r: r[b].get(k, 0.0)) for k in ("arm_in_body", "upper_in_head", "bar_in_body",
                                                                   "hand_to_bar", "foot_floor", "foot_slide", "pop")}
        report.append("| %s | %s |\n" % (b, " | ".join("%.2f (t %.2f)" % (w[k][b][k], w[k]["t"]) for k in w)))
open(os.path.join(OUT, ANIM + "_qa.md"), "w", encoding="utf-8").write("".join(report))
print("".join(report))

# ---------------------------------------------------------------- the pictures: one sheet per moment
for t, note in moments:
    tiles = []
    for tag, folder in FOLDERS:
        for view in VIEWS:
            pose_all(folder, t, view)
            text = "%s  -  %s  t %.2f %s  -  %s view" % (
                tag.upper(), ANIM, t, note, view)
            tiles.append(shoot(os.path.join(TILES, "%s_%s_%.2f_%s.png" % (ANIM, tag, t, view)), text, view))
    extra = [os.path.join(folder, "%s_%s_%.2f_%s.png" % (ANIM, tag, t, view)) for tag, folder in EXTRA for view in VIEWS]
    extra = [p for p in extra if os.path.exists(p)]
    tiles = extra + tiles if os.environ.get("QA_EXTRA_FIRST") else tiles + extra     # (QA_EXTRA_FIRST=1: on top)
    path = os.path.join(OUT, "%s_%.2f.png" % (ANIM, t))
    G["contact_sheet"]([(None, None, p) for p in tiles], path, len(VIEWS))
    print("[AnimQA] sheet", path)
for b in BUILDS:
    G["rest_rig"](rigs[b])
print("[AnimQA] DONE (nothing saved)")
