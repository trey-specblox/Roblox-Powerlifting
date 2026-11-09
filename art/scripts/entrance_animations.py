# Meet entrances (GAME_DESIGN.md §36.4, decided by the user 2026-11-08): a walk style out to the platform, then a
# short hype move at the platform's edge before the bar (the hype move at State meets and up only). Same Roblox R15
# block rig and tools as the station reps, the fails and the chalking up (station_animations.py, fail_animations.py).
#
#   Walk_Swagger     confident: chin up, hips swaying, shoulders rolling, arms swinging wide
#   Walk_Hype        bouncy and quick: knees springy, arms pumping, head bobbing
#   Walk_Stomp       slow and heavy: leaning in, arms held out from the sides, rocking side to side, head down
#   Hype_Belt        hands to the belt, two hard tugs, a clap (the default entrance's hype move)
#   Hype_Flex        a double biceps flex, held shaking, then shakes the arms out
#   Hype_ChestSlap   two slaps on the chest, then arms down and out and a roar to the ceiling
#   Hype_NeckRoll    rolls the neck, two claps, points at the bar
#   Touch_GameFace   arms only, over the last steps of a Local or Regional walk-out: two quick chalky claps, then both
#                    hands tap the belt (user 2026-11-08: those walk-outs "too bland", but not flashy or long)
#
# The walks loop (Movement priority) and are made for the speed in WALKS[...]["speed"] (studs per second): the
# server walks the body at that speed (EntranceConfig), so the feet keep up with the floor. The hype moves play once
# (Action priority), start and end standing with the arms hanging, and stand on the spot.
#
#   blender -b --factory-startup --python art/scripts/entrance_animations.py -- <preview folder>
# writes art/animations/Entrance_<Name>.rbxmx and, with a folder, preview sheets and videos there. Publish with
# art/scripts/upload_animations.py.
import importlib.util
import math
import os
import sys

from mathutils import Matrix, Vector

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\Powerlifting Roblox\art\scripts"
_spec = importlib.util.spec_from_file_location("fail_animations", os.path.join(_HERE, "fail_animations.py"))
F = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(F)
S = F.S

rx, ry, rz, T = S.rx, S.ry, S.rz, S.T
TAU = 2 * math.pi
STAND_ANKLE_Y = S.STAND_ANKLES[0].y
LEG_LENGTH = 1.75          # hip joint to ankle joint on this rig (studs)


# ---------------------------------------------------------------- walks
def leg(side, root_rot, thigh, flex, stance, toes, foot_pitch=0.0):
    """One leg: thigh angle (+ forward), knee flex (+ bent), the foot flat but for foot_pitch (+ toes up)."""
    sx = -1 if side == "Left" else 1
    turned = rz(sx * stance) @ ry(-sx * toes)
    thigh_world = turned @ rx(thigh)
    knee = rx(-flex)
    foot_world = ry(-sx * toes) @ rx(foot_pitch)
    return {side + "Hip": root_rot.inverted() @ thigh_world, side + "Knee": knee,
            side + "Ankle": (thigh_world @ knee).inverted() @ foot_world}


def one_arm(side, a):
    both = S.arms(a)
    return {side + "Shoulder": both[side + "Shoulder"], side + "Elbow": both[side + "Elbow"]}


def leg_phase(phi, w):
    """(thigh, knee flex, foot pitch) at phase phi of one leg's cycle: the thigh furthest forward at 0.25 (heel down),
    furthest back at 0.75 (toes off); the swing from 0.75 round to 0.25 bends the knee most at 0."""
    thigh = w["thigh"] * math.sin(TAU * phi)
    s = (phi - 0.75) % 1.0
    if s < 0.5:
        lift = math.sin(math.pi * s / 0.5)
        flex = w["swing_flex"] * lift
        pitch = w["toe_up"] * lift
    else:
        flex = w["stance_flex"] * math.sin(math.pi * (s - 0.5) / 0.5)
        pitch = 0.0
    if w.get("stamp") and 0.15 <= phi <= 0.25:
        # The heavy walk drops the foot hard: the leg reaches forward late, then lands.
        flex *= 0.6
    return thigh, flex, pitch


def walk_pose(w, t):
    ph = (t / w["period"]) % 1.0
    step = math.sin(TAU * ph)                 # +1: left leg forward (right arm forward)
    pitch = w["torso"] + w.get("lean_bob", 0.0) * math.cos(2 * TAU * ph)
    roll = w.get("sway", 0.0) * math.sin(TAU * ph + math.pi / 2)
    yaw = w.get("hip_turn", 0.0) * step
    root_rot = ry(yaw) @ rz(roll) @ rx(pitch)
    pose = {"Waist": ry(-yaw - w.get("shoulder_turn", 0.0) * step)}
    for side, offset in (("Left", 0.0), ("Right", 0.5)):
        thigh, flex, foot = leg_phase((ph + offset) % 1.0, w)
        pose.update(leg(side, root_rot, thigh, flex, w["stance"], w["toes"], foot))
        swing = -w["arm_swing"] * math.sin(TAU * ((ph + offset) % 1.0)) - pitch
        forward = max(0.0, swing + pitch) / max(1.0, w["arm_swing"])
        pose.update(one_arm(side, {"raise": w["arm_raise"], "swing": swing, "twist": w.get("arm_twist", 0.0),
                                   "elbow": w["elbow"] + w.get("elbow_pump", 0.0) * forward}))
    pose["Neck"] = rx(w["neck"] - pitch * 0.6 + w.get("nod", 0.0) * math.sin(2 * TAU * ph))
    pose["Root"] = root_rot
    # Down onto the lower foot's sole: the hips rise and fall with the stride by themselves, and no corner of a foot
    # goes into the floor.
    world = S.forward_kinematics(T((0, S.HRP_STAND_Y, 0)), pose)
    low = min(sole_low(world, part) for part in ("LeftFoot", "RightFoot"))
    pose["Root"] = T((0, -low + w.get("bounce", 0.0) * max(0.0, math.cos(2 * TAU * ph)), 0)) @ root_rot
    return pose


def sole_low(world, part):
    sx, sy, sz = S.SIZES[part]
    m = world[part]
    return min((m @ Vector((x * sx / 2, -sy / 2, z * sz / 2))).y for x in (-1, 1) for z in (-1, 1))


def stride_speed(w):
    """Studs per second the stance foot slides back at: the speed the server must walk this style at."""
    reach = 2 * LEG_LENGTH * math.sin(math.radians(w["thigh"]))
    return reach / (w["period"] / 2)


WALKS = {
    "Swagger": {"period": 0.85, "thigh": 33.0, "swing_flex": 55.0, "stance_flex": 8.0, "toe_up": 10.0,
                "stance": 3.0, "toes": 12.0, "torso": 3.0, "sway": 4.0, "hip_turn": 5.0, "shoulder_turn": 9.0,
                "arm_swing": 32.0, "arm_raise": 14.0, "elbow": 18.0, "elbow_pump": 15.0, "neck": 6.0, "nod": 2.0},
    "Hype": {"period": 0.6, "thigh": 28.0, "swing_flex": 75.0, "stance_flex": 20.0, "toe_up": 12.0,
             "stance": 2.0, "toes": 8.0, "torso": -6.0, "hip_turn": 4.0, "shoulder_turn": 6.0, "bounce": 0.12,
             "arm_swing": 45.0, "arm_raise": 10.0, "elbow": 80.0, "elbow_pump": 15.0, "neck": 2.0, "nod": 6.0},
    "Stomp": {"period": 1.0, "thigh": 30.0, "swing_flex": 52.0, "stance_flex": 14.0, "toe_up": 6.0, "stamp": True,
              "stance": 6.0, "toes": 15.0, "torso": -10.0, "lean_bob": 2.0, "sway": 6.0, "hip_turn": 3.0,
              "shoulder_turn": 4.0, "arm_swing": 10.0, "arm_raise": 32.0, "arm_twist": 20.0, "elbow": 35.0,
              "neck": -6.0},
}
for _w in WALKS.values():
    _w["speed"] = round(stride_speed(_w), 2)


# ---------------------------------------------------------------- hype moves (standing on the spot, hands solved)
HANG_HAND = Vector((-1.5, -0.85, 0.0))
STAND = {"torso": 0.0, "thigh": 0.0, "shin": 0.0, "toes": 12.0, "neck": 0.0}
SOLVE_STEPS = (4, 2, 1, 0.5, 0.25)
START_ARM = {"raise": 4.0, "swing": 0.0, "twist": 0.0, "elbow": 8.0}


def body_at(keys, t):
    a, b, u = F.at(keys, t)
    p = {k: a[k] + (b[k] - a[k]) * u for k in a}
    p["arm"] = F.HANG
    return F.planted(p)


def hand_at(keys, t):
    a, b, u = F.at(keys, t)
    return a.lerp(b, u)


def mirror(v):
    return Vector((-v.x, v.y, v.z))


def shake(t, t0, t1, amp, hz=9.0):
    return F.tremble(t, t0, t1, amp, hz)


def preference(_world, a):
    # No needless twist, and arms straight unless the hand needs the elbow bent.
    return 0.002 * abs(a["twist"]) + 0.001 * abs(a["raise"]) + 0.0005 * abs(a["elbow"])


class Hype:
    """A hype move: `body` keys (planted), the left hand's keys (`right` keys too, as true positions, else mirrored),
    `neck(t)` an extra neck turn, `wobble(t)` added to both hands (left; the right mirrored)."""

    STEP = 0.025

    def __init__(self, length, body, left, right=None, neck=None, wobble=None):
        self.length, self.body, self.left_keys, self.right_keys = length, body, left, right
        self.neck, self.wobble = neck, wobble
        self.table, self.worst = None, 0.0

    def _targets(self, t):
        extra = self.wobble(t) if self.wobble else Vector((0, 0, 0))
        left = hand_at(self.left_keys, t) + extra
        right = (hand_at(self.right_keys, t) if self.right_keys else mirror(hand_at(self.left_keys, t))) + mirror(extra)
        return left, right

    def _solve(self):
        """The arms solved once, in time order from the start, every STEP: each solve starts from the one before, so
        the arms never flip to another way of reaching the same spot, and every caller gets the same answer."""
        a_left, a_right = dict(START_ARM), dict(START_ARM)
        self.table = []
        for i in range(int(math.ceil(self.length / self.STEP)) + 1):
            t = min(self.length, i * self.STEP)
            p = body_at(self.body, t)
            body = F._body(p, p["root"])
            left, right = self._targets(t)
            a_left, _ = S.solve_arms(body, left, a_left, preference, 5.0, SOLVE_STEPS)
            a_right, _ = S.solve_arms(body, mirror(right), a_right, preference, 5.0, SOLVE_STEPS)
            self.table.append((dict(a_left), dict(a_right)))

    def pose(self, t):
        if self.table is None:
            self._solve()
        t = max(0.0, min(self.length, t))
        p = body_at(self.body, t)
        pose = dict(F._body(p, p["root"]))
        f = t / self.STEP
        i = min(int(f), len(self.table) - 2)
        u = f - i
        (l0, r0), (l1, r1) = self.table[i], self.table[i + 1]
        pose.update(one_arm("Left", F.lerp(l0, l1, u)))
        pose.update(one_arm("Right", F.lerp(r0, r1, u)))
        if self.neck:
            pose["Neck"] = pose["Neck"] @ self.neck(t)
        left, right = self._targets(t)
        w = S.forward_kinematics(Matrix.Identity(4), pose)
        self.worst = max(self.worst, (w["LeftHand"].to_translation() - left).length,
                         (w["RightHand"].to_translation() - right).length)
        return pose


def dip(depth, neck=0.0, torso=0.0):
    return {"torso": torso - 4.0 * depth, "thigh": 18.0 * depth, "shin": -8.0 * depth, "toes": 12.0, "neck": neck}


# Hype_Belt: hands to the belt's sides, slide to the front, two hard tugs with a dip, a clap, hands down.
BELT_SIDE = Vector((-1.12, -0.5, -0.62))
BELT_FRONT = Vector((-0.55, -0.55, -0.98))
BELT_TUG = Vector((-0.6, -0.68, -0.94))
CLAP = Vector((-0.5, 0.35, -1.05))
APART = Vector((-1.05, 0.42, -1.1))
BELT = Hype(3.0,
            [(0.0, STAND), (0.35, dict(STAND, neck=-14.0)), (0.9, dict(STAND, neck=-16.0)), (1.05, dip(0.6, -18.0)),
             (1.2, dict(STAND, neck=-14.0)), (1.4, dip(0.7, -18.0)), (1.6, dict(STAND, neck=-4.0)),
             (2.2, dict(STAND, neck=4.0)), (3.0, STAND)],
            [(0.0, HANG_HAND), (0.45, BELT_SIDE), (0.8, BELT_FRONT), (1.05, BELT_TUG), (1.2, BELT_FRONT),
             (1.4, BELT_TUG), (1.6, BELT_FRONT), (1.85, APART), (2.0, CLAP), (2.2, CLAP), (2.6, HANG_HAND),
             (3.0, HANG_HAND)])

# Hype_Flex: arms up into a double biceps, held and shaking, a small lean, then shakes the arms out.
FLEX = Vector((-1.78, 1.72, -0.15))
FLEX_IN = Vector((-1.7, 1.55, -0.35))
LOOSE = Vector((-1.6, -0.7, -0.25))
FLEX_HYPE = Hype(3.2,
                 [(0.0, STAND), (0.5, dict(STAND, neck=6.0)), (0.7, dip(0.35, 4.0)), (1.8, dip(0.4, 2.0)),
                  (2.2, STAND), (3.2, STAND)],
                 [(0.0, HANG_HAND), (0.5, FLEX_IN), (0.7, FLEX), (1.8, FLEX), (2.15, LOOSE), (2.9, HANG_HAND),
                  (3.2, HANG_HAND)],
                 wobble=lambda t: Vector((0, shake(t, 0.75, 1.8, 0.05, 11.0), 0)) +
                 Vector((0.12 * F.tremble(t, 2.15, 2.9, 1.0, 5.0), 0.1 * F.tremble(t, 2.15, 2.9, 1.0, 5.0), 0)))

# Hype_ChestSlap: hands back wide, two slaps on the chest, then arms down and out and a roar up at the ceiling.
CHEST = Vector((-0.48, 0.42, -0.98))
WIDE = Vector((-1.45, 0.45, -0.95))
ROAR = Vector((-1.95, -0.35, -0.55))
CHEST_SLAP = Hype(3.2,
                  [(0.0, STAND), (0.4, dict(STAND, neck=-4.0)), (0.95, dict(STAND, neck=-6.0)),
                   (1.25, dip(0.5, 22.0, 2.0)), (2.4, dip(0.55, 26.0, 2.0)), (2.9, STAND), (3.2, STAND)],
                  [(0.0, HANG_HAND), (0.35, WIDE), (0.5, CHEST), (0.65, WIDE), (0.8, CHEST), (1.25, ROAR),
                   (2.4, ROAR), (2.9, HANG_HAND), (3.2, HANG_HAND)],
                  wobble=lambda t: Vector((shake(t, 1.3, 2.4, 0.06, 10.0), shake(t, 1.3, 2.4, 0.04, 8.0), 0)))

# Hype_NeckRoll: rolls the neck round, two claps, then points the right hand at the bar.
POINT = Vector((0.6, 0.85, -1.72))


def neck_roll(t):
    if t <= 0.1 or t >= 1.5:
        return Matrix.Identity(4)
    u = (t - 0.1) / 1.4
    edge = min(1.0, u / 0.15, (1 - u) / 0.15)
    angle = TAU * u
    return rz(16.0 * edge * math.sin(angle)) @ rx(14.0 * edge * (math.cos(angle) - 1) * 0.5 - 6.0 * edge)


NECK_ROLL = Hype(3.0,
                 [(0.0, STAND), (1.5, STAND), (1.7, dict(STAND, neck=-4.0)), (2.3, dict(STAND, neck=-2.0)),
                  (2.5, dict(STAND, neck=-8.0)), (3.0, STAND)],
                 [(0.0, HANG_HAND), (1.5, HANG_HAND), (1.75, APART), (1.9, CLAP), (2.05, APART), (2.2, CLAP),
                  (2.45, HANG_HAND), (3.0, HANG_HAND)],
                 right=[(0.0, mirror(HANG_HAND)), (1.5, mirror(HANG_HAND)), (1.75, mirror(APART)),
                        (1.9, mirror(CLAP)), (2.05, mirror(APART)), (2.2, mirror(CLAP)), (2.45, POINT),
                        (2.8, POINT), (3.0, mirror(HANG_HAND))],
                 neck=neck_roll)

HYPES = {"Belt": BELT, "Flex": FLEX_HYPE, "ChestSlap": CHEST_SLAP, "NeckRoll": NECK_ROLL}

# Touch_GameFace: played over the walk (Action priority) with only the arms keyed, so the legs and hips keep walking;
# the server times it to end as the walk does. Claps at 0.32 and 0.56 s (EntranceConfig.QuickTouch.clapSeconds).
NEAR = Vector((-0.82, 0.4, -1.08))
GAME_FACE = Hype(1.5,
                 [(0.0, STAND), (1.5, STAND)],
                 [(0.0, HANG_HAND), (0.2, APART), (0.32, CLAP), (0.44, NEAR), (0.56, CLAP), (0.78, BELT_FRONT),
                  (0.9, BELT_TUG), (1.02, BELT_FRONT), (1.5, HANG_HAND)])
TOUCHES = {"GameFace": GAME_FACE}
# The parts a touch keys; their parents go in at weight 0, which leaves them to the walk (tested in Studio 2026-11-08: at
# weight 1 they hold the hips and waist still).
ARMS = ("LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand")


# ---------------------------------------------------------------- export
def clips():
    """(file name, length, pose(t), looped, priority token, sample step, only these parts keyed or None)."""
    out = []
    for name, w in WALKS.items():
        out.append((f"Entrance_Walk_{name}", w["period"], lambda t, w=w: walk_pose(w, t), True, 1, w["period"] / 24, None))
    for name, h in HYPES.items():
        out.append((f"Entrance_Hype_{name}", h.length, h.pose, False, 2, 0.05, None))
    for name, h in TOUCHES.items():
        out.append((f"Entrance_Touch_{name}", h.length, h.pose, False, 2, 0.05, ARMS))
    return out


def export(name, length, pose, looped, priority, step, only=None):
    refs = iter(range(1, 1_000_000))
    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
           f'<Item class="KeyframeSequence" referent="RBX{next(refs)}"><Properties>'
           f'<float name="AuthoredHipHeight">2</float><bool name="Loop">{"true" if looped else "false"}</bool>'
           f'<string name="Name">{name}</string><token name="Priority">{priority}</token>'
           f'</Properties>']
    children, parent_of = {}, {}
    for joint, (parent, child, c0, c1) in S.JOINTS.items():
        children.setdefault(parent, []).append((child, joint))
        parent_of[child] = parent
    # With `only`, just those parts and their parents (at weight 0, left to whatever else plays).
    keep = None
    if only:
        keep = set(only)
        for part in only:
            while part in parent_of:
                part = parent_of[part]
                keep.add(part)

    def pose_xml(part, transforms):
        if keep is not None and part not in keep:
            return ""
        joint = S.CHILD_JOINT.get(part)
        m = transforms.get(joint, Matrix.Identity(4)) if joint else Matrix.Identity(4)
        weight = 0 if only and part not in only else 1
        s = (f'<Item class="Pose" referent="RBX{next(refs)}"><Properties>'
             f'<CoordinateFrame name="CFrame">{S._cframe_xml(m)}</CoordinateFrame>'
             f'<token name="EasingDirection">0</token><token name="EasingStyle">0</token>'
             f'<string name="Name">{part}</string><float name="Weight">{weight}</float></Properties>')
        for child, _ in children.get(part, []):
            s += pose_xml(child, transforms)
        return s + "</Item>"

    steps = int(round(length / step))
    for i in range(steps + 1):
        t = min(length, i * step)
        # A looped walk ends on its own first pose, so the loop has no jump.
        p = pose(0.0 if looped and i == steps else t)
        out.append(f'<Item class="Keyframe" referent="RBX{next(refs)}"><Properties>'
                   f'<string name="Name">Keyframe</string><float name="Time">{t:.3f}</float></Properties>')
        out.append(pose_xml("HumanoidRootPart", p))
        out.append("</Item>")
    out.append("</Item></roblox>")
    os.makedirs(S.OUT_DIR, exist_ok=True)
    path = os.path.join(S.OUT_DIR, f"{name}.rbxmx")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    return path, steps + 1


def checks():
    """Lines to print: each walk's speed, and the lowest point of every clip (nothing may sink into the floor)."""
    lines = []
    for name, length, pose, *_ in clips():
        lowest, highest_foot = 9.0, -9.0
        t = 0.0
        while t <= length + 1e-6:
            w = S.forward_kinematics(T((0, S.HRP_STAND_Y, 0)), pose(t))
            for part in ("LeftFoot", "RightFoot", "LeftHand", "RightHand"):
                sx, sy, sz = S.SIZES[part]
                m = w[part]
                ys = [(m @ Vector((x * sx / 2, y * sy / 2, z * sz / 2))).y
                      for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
                lowest = min(lowest, min(ys))
                if "Foot" in part:
                    highest_foot = max(highest_foot, min(ys))
            t += length / 40
        lines.append(f"{name}: lowest {lowest:.2f}, highest foot sole {highest_foot:.2f}")
    for name, w in WALKS.items():
        lines.append(f"Walk_{name}: speed {w['speed']} studs/s, {2 / w['period']:.1f} steps/s")
    for name, h in HYPES.items():
        lines.append(f"Hype_{name}: {h.length} s, worst hand miss {h.worst:.3f}")
    for name, h in TOUCHES.items():
        gap = min((S.forward_kinematics(Matrix.Identity(4), h.pose(c))["LeftHand"].to_translation() -
                   S.forward_kinematics(Matrix.Identity(4), h.pose(c))["RightHand"].to_translation()).length
                  for c in (0.32, 0.56))
        lines.append(f"Touch_{name}: {h.length} s, worst hand miss {h.worst:.3f}, hands {gap:.2f} apart at the claps")
    return lines


# ---------------------------------------------------------------- previews
def _scene_setup(bpy):
    bpy.ops.wm.read_homefile(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_backface_culling = True
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.55, 0.57, 0.6)
    scene.display.shading.background_type = "WORLD"
    return scene


def _material(bpy, name, rgb):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    return m


def _figure(bpy, label, top):
    """Block body objects (not placed); returns {part: object}."""
    import bmesh
    looks = {"top": _material(bpy, "Top_" + label, top), "skin": _material(bpy, "Skin", (0.75, 0.5, 0.35)),
             "legs": _material(bpy, "Legs", (0.12, 0.12, 0.14))}
    objs = {}
    for part, size in S.SIZES.items():
        if part == "HumanoidRootPart":
            continue
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Diagonal((*size, 1)))
        mesh = bpy.data.meshes.new(f"{label}_{part}")
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(looks["top"] if "Torso" in part else looks["legs"] if "Leg" in part or "Foot" in part
                              else looks["skin"])
        ob = bpy.data.objects.new(f"{label}_{part}", mesh)
        ob.rotation_mode = "QUATERNION"
        bpy.context.scene.collection.objects.link(ob)
        objs[part] = ob
    return objs


def _place(objs, pose, at, turn=Matrix.Identity(4), frame=None):
    world = S.forward_kinematics(T((0, S.HRP_STAND_Y, 0)), pose)
    for part, ob in objs.items():
        ob.matrix_world = Matrix.Translation(at) @ turn @ S.TO_BLENDER @ world[part]
        if frame is not None:
            ob.keyframe_insert("location", frame=frame)
            ob.keyframe_insert("rotation_quaternion", frame=frame)


def _floor_lines(bpy, x0, x1, y0, y1, gap):
    """Thin dark strips across the floor every `gap` studs, so a foot sliding on the floor shows."""
    import bmesh
    mat = _material(bpy, "FloorLine", (0.2, 0.2, 0.22))
    floor = _material(bpy, "Floor", (0.62, 0.6, 0.56))
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=0.5,
                          matrix=Matrix.Translation(((x0 + x1) / 2, (y0 + y1) / 2, -0.01)) @
                          Matrix.Diagonal((x1 - x0, y1 - y0, 1, 1)))
    mesh = bpy.data.meshes.new("PreviewFloor")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(floor)
    ob = bpy.data.objects.new("PreviewFloor", mesh)
    bpy.context.scene.collection.objects.link(ob)
    y = y0
    while y <= y1:
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=0.5,
                              matrix=Matrix.Translation(((x0 + x1) / 2, y, 0.0)) @
                              Matrix.Diagonal((x1 - x0, 0.08, 1, 1)))
        mesh = bpy.data.meshes.new("PreviewFloorLine")
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(mat)
        line = bpy.data.objects.new("PreviewFloorLine", mesh)
        bpy.context.scene.collection.objects.link(line)
        y += gap


def _camera(bpy, scene, location, target, ortho):
    camera = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = ortho
    camera.location = location
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera


def _video_settings(scene, path):
    """Every second frame as PNGs in the folder `path` (this Blender build writes no video; the frames become a GIF
    outside Blender)."""
    os.makedirs(path, exist_ok=True)
    scene.render.image_settings.file_format = "PNG"
    scene.render.fps = 30
    scene.frame_step = 2
    scene.render.filepath = os.path.join(path, "frame_")
    return True


COLOURS = [(0.8, 0.08, 0.08), (0.1, 0.45, 0.85), (0.95, 0.65, 0.1), (0.15, 0.6, 0.3)]


def sheet(folder, title, pose, length, count, turn, cam_offset, along):
    """`count` moments of one clip side by side in one image, spaced along the Blender vector `along`."""
    import bpy
    scene = _scene_setup(bpy)
    spacing = 4.0
    for i in range(count):
        t = length * i / count
        objs = _figure(bpy, f"F{i}", COLOURS[0])
        _place(objs, pose(t), along * (i * spacing), turn)
    far = along * ((count - 1) * spacing)
    centre = far / 2 + Vector((0, 0, 2.6))
    _camera(bpy, scene, centre + cam_offset, centre, count * spacing + 1)
    scene.render.resolution_x, scene.render.resolution_y = 1800, 380
    scene.render.filepath = os.path.join(folder, f"{title}.png")
    bpy.ops.render.render(write_still=True)


def walk_video(folder):
    """The three walks and Roblox's own beside each other (a plain reference only as a still figure), each walking
    at its own speed across lines on the floor."""
    import bpy
    scene = _scene_setup(bpy)
    seconds = 4.0
    frames = int(seconds * 30)
    lanes = list(WALKS.items())
    for lane, (name, w) in enumerate(lanes):
        objs = _figure(bpy, name, COLOURS[lane])
        x = lane * 4.0
        for f in range(0, frames + 1):
            t = f / 30
            # Facing Roblox -Z = Blender -Y: walking toward -Y.
            _place(objs, walk_pose(w, t), Vector((x, 8.0 - w["speed"] * t, 0)), frame=f + 1)
    _floor_lines(bpy, -2, (len(lanes) - 1) * 4.0 + 2, -16, 10, 2.0)
    centre = Vector(((len(lanes) - 1) * 2.0, -3.0, 1.5))
    _camera(bpy, scene, centre + Vector((24.0, -14.0, 9.0)), centre, 26)
    scene.frame_start, scene.frame_end = 1, frames
    scene.render.resolution_x, scene.render.resolution_y = 960, 540
    if _video_settings(scene, os.path.join(folder, "Entrance_Walks_frames")):
        bpy.ops.render.render(animation=True)


def hype_video(folder):
    import bpy
    scene = _scene_setup(bpy)
    frames = int(3.4 * 30)
    for lane, (name, h) in enumerate(HYPES.items()):
        objs = _figure(bpy, name, COLOURS[lane])
        for f in range(0, frames + 1):
            _place(objs, h.pose(min(h.length, f / 30)), Vector((lane * 4.5, 0, 0)), frame=f + 1)
    _floor_lines(bpy, -2.5, 3 * 4.5 + 2.5, -3, 3, 6.0)
    centre = Vector((3 * 4.5 / 2, 0, 2.6))
    _camera(bpy, scene, centre + Vector((-6.0, -22.0, 4.0)), centre, 21)
    scene.frame_start, scene.frame_end = 1, frames
    scene.render.resolution_x, scene.render.resolution_y = 960, 400
    if _video_settings(scene, os.path.join(folder, "Entrance_Hypes_frames")):
        bpy.ops.render.render(animation=True)


def touch_previews(folder):
    """The game face over a walk (Swagger's legs, the touch's arms, as the game layers them) and standing."""
    import bpy
    os.makedirs(folder, exist_ok=True)
    h, w = GAME_FACE, WALKS["Swagger"]

    def layered(t):
        p = dict(walk_pose(w, t))
        top = h.pose(t)
        for joint in ("LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow", "RightWrist"):
            if joint in top:
                p[joint] = top[joint]
        return p

    sheet(folder, "Entrance_Touch_GameFace", h.pose, h.length, 8, Matrix.Identity(4),
          Vector((-6.0, -22.0, 3.0)), Vector((1, 0, 0)))
    scene = _scene_setup(bpy)
    frames = int(h.length * 30)
    walker, stander = _figure(bpy, "Walking", COLOURS[1]), _figure(bpy, "Standing", COLOURS[2])
    for f in range(0, frames + 1):
        t = f / 30
        _place(walker, layered(t), Vector((0, 6.0 - w["speed"] * t, 0)), frame=f + 1)
        _place(stander, h.pose(t), Vector((4.5, 0, 0)), frame=f + 1)
    _floor_lines(bpy, -2.5, 7.0, -4, 8, 2.0)
    centre = Vector((2.2, 1.0, 2.4))
    _camera(bpy, scene, centre + Vector((-9.0, -20.0, 4.0)), centre, 15)
    scene.frame_start, scene.frame_end = 1, frames
    scene.render.resolution_x, scene.render.resolution_y = 800, 480
    if _video_settings(scene, os.path.join(folder, "Entrance_Touch_frames")):
        bpy.ops.render.render(animation=True)


def previews(folder):
    os.makedirs(folder, exist_ok=True)
    side = Vector((22.0, -4.0, 2.0))          # from the figure's right side, a little in front
    front = Vector((-6.0, -22.0, 3.0))        # from in front, a little to their left
    for name, w in WALKS.items():
        sheet(folder, f"Entrance_Walk_{name}", lambda t, w=w: walk_pose(w, t), w["period"], 8, Matrix.Identity(4), side,
              Vector((0, -1, 0)))
    for name, h in HYPES.items():
        sheet(folder, f"Entrance_Hype_{name}", h.pose, h.length, 8, Matrix.Identity(4), front, Vector((1, 0, 0)))
    walk_video(folder)
    hype_video(folder)


if __name__ == "__main__":
    for line in checks():
        print("CHECK", line)
    for clip in clips():
        print("EXPORTED", export(*clip))
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) > 1 and argv[1] == "touch":
        touch_previews(argv[0])
    elif argv:
        previews(argv[0])
    print("DONE")
