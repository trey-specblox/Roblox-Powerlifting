# The pose engine for the celebrations (GAME_DESIGN.md §36.4, celebrations from the user's 15 meet videos, 2026-11-11;
# References/Clip Study). Same Roblox R15 block rig, joints and exporter maths as the station reps, fails and hype moves
# (station_animations.py), but every limb is free on its own: one fist up, a step, a knee down, a jump, lying back.
#
# A clip is a list of keys: (time, {channel: value, ...}). Each channel is interpolated only between the keys that set
# it (like Blender's f-curves), with the ease of the later key ("ease": smooth / fast / slow / linear / hold). Then, each
# sampled moment, the body is built from the keyed angles and each arm and leg is SOLVED onto its keyed target.
#
# Space ("floor space"): Roblox's, +Y up, the character starts facing -Z, its Left is -X; the floor is y = 0 and the
# HumanoidRootPart sits at (0, S.HRP_STAND_Y, 0) as it does standing: 3.4 on the taller rig (HipHeight 2.4, user
# 2026-11-12), 3.0 on the block rig (HipHeight 2). Angles are degrees.
#
# Channels (all optional; the defaults are standing still, arms hanging):
#   pos                (x, y, z) the hips' offset from standing (y < 0 crouches, > 0 jumps)
#   yaw, lean, side    the whole body: yaw + turns to its right, lean + forward, side + leans to its right
#   cbend, ctwist, cside   the chest on the hips (the Waist): bend + forward, twist + to its right, side + to its right
#   up, turn, hroll    the head: up + looks up, turn + to its right, hroll + tilts to its right
#   lh, rh             a hand's target: (frame, (x, y, z)); frame "hrp" = from the root part's centre (the hype moves'
#                      numbers, HANG_HAND etc.), "chest" = in the chest's own frame (follows lean and twist), "floor" =
#                      floor space. Or ("angles", {raise, swing, twist, elbow}) to pose the arm directly.
#   le, re             where the elbow should point (a direction in the chest's frame), to choose how the arm bends
#   lw, rw             (pitch, roll) of the wrist
#   lf, rf             a foot: (x, y, z, yaw, pitch): its ankle in floor space, toes turned out by yaw (+ outward for
#                      either foot), pitch + toes up / - on tiptoe. Default: where it stands, toes out STAND_TOES.
#   lk, rk             (x, y, z) a knee's target (kneeling: y = KNEE_ON_FLOOR); None = free
#
# Layers: functions layer(t, ch) that add to the sampled channels before solving (a shake, breathing...).
import importlib.util
import math
import glob
import os

from mathutils import Euler, Matrix, Vector

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\Powerlifting Roblox\art\scripts"
_spec = importlib.util.spec_from_file_location("station_animations", os.path.join(_HERE, "station_animations.py"))
S = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(S)

rx, ry, rz, T = S.rx, S.ry, S.rz, S.T
HRP = Vector((0.0, S.HRP_STAND_Y, 0.0))
HRP_M = T(HRP)

# ---------------------------------------------------------------- rig constants
_C0 = {j: T(c0) for j, (p, c, c0, c1) in S.JOINTS.items()}
_C1I = {j: T(c1).inverted() for j, (p, c, c0, c1) in S.JOINTS.items()}
_C0V = {j: Vector(c0) for j, (p, c, c0, c1) in S.JOINTS.items()}
_C1V = {j: Vector(c1) for j, (p, c, c0, c1) in S.JOINTS.items()}


def place(parent_world, joint, transform):
    return parent_world @ _C0[joint] @ transform @ _C1I[joint]


STAND_TOES = 12.0                  # standing toes-out, as the hype moves
KNEE_ON_FLOOR = 0.5                # the knee joint's height with the shin flat on the floor (half the leg's depth)
_STAND_WORLD = S.forward_kinematics(HRP_M, {})
STAND_ANKLE = {side: _STAND_WORLD[side + "Foot"] @ _C1V[side + "Ankle"] for side in ("Left", "Right")}
# The left hand hanging, from the root part's centre (entrance_animations): an arm's length below the shoulder.
HANG_HAND = Vector((-1.5, S.up_body(0.763) - S.reach(1.488) - 0.125, 0.0))
START_ARM = {"raise": 4.0, "swing": 0.0, "twist": 0.0, "elbow": 8.0}
START_LEG = {"flex": 0.0, "out": 0.0, "turn": STAND_TOES, "bend": 0.0}
SIDES = (("Left", -1), ("Right", 1))
_SHORT = {"Left": "l", "Right": "r"}


REST = ("angles", dict(START_ARM))          # a hand back to hanging loose (either side)


def stand_foot(side, yaw=STAND_TOES):
    a = STAND_ANKLE[side]
    return (a.x, a.y, a.z, yaw, 0.0)


DEFAULTS = {
    "pos": (0.0, 0.0, 0.0), "yaw": 0.0, "lean": 0.0, "side": 0.0,
    "cbend": 0.0, "ctwist": 0.0, "cside": 0.0, "up": 0.0, "turn": 0.0, "hroll": 0.0,
    "lh": ("angles", dict(START_ARM)), "rh": ("angles", dict(START_ARM)),
    "le": (-0.4, -1.0, 0.35), "re": (0.4, -1.0, 0.35), "lw": (0.0, 0.0), "rw": (0.0, 0.0),
    "lf": stand_foot("Left"), "rf": stand_foot("Right"), "lk": None, "rk": None,
}


def mirror(spec):
    """A left hand or foot value for the right side (or back): x flipped. Feet keep yaw (it is 'outward' for both)."""
    if spec is None:
        return None
    if isinstance(spec, tuple) and len(spec) == 2 and isinstance(spec[0], str):
        frame, v = spec
        if frame == "angles":
            return spec
        return (frame, (-v[0], v[1], v[2]))
    if len(spec) == 5:
        return (-spec[0], spec[1], spec[2], spec[3], spec[4])
    return (-spec[0], spec[1], spec[2])


# ---------------------------------------------------------------- easing and channel interpolation
def _ease(kind, u):
    u = max(0.0, min(1.0, u))
    if kind == "linear":
        return u
    if kind == "fast":                  # quick start, soft landing (a snap, a punch)
        return 1 - (1 - u) ** 3
    if kind == "slow":                  # soft start, quick end (a wind-up)
        return u ** 3
    if kind == "hold":
        return 0.0 if u < 1 else 1.0
    return u * u * (3 - 2 * u)


def _lerp(a, b, u):
    if a is None or b is None:
        return b if u >= 0.5 else a
    if isinstance(a, (int, float)):
        return a + (b - a) * u
    if isinstance(a, dict):
        return {k: a[k] + (b[k] - a[k]) * u for k in a}
    return tuple(x + (y - x) * u for x, y in zip(a, b))


class Track:
    """One channel's keys: [(t, value, ease)]."""

    def __init__(self):
        self.keys = []

    def at_keys(self, t):
        """(index a, index b, eased u): which two keys t falls between."""
        keys = self.keys
        if t <= keys[0][0]:
            return 0, 0, 0.0
        for i in range(len(keys) - 1):
            t0, t1 = keys[i][0], keys[i + 1][0]
            if t <= t1:
                return i, i + 1, _ease(keys[i + 1][2], (t - t0) / (t1 - t0) if t1 > t0 else 1.0)
        return len(keys) - 1, len(keys) - 1, 0.0

    def at(self, t):
        keys = self.keys
        if t <= keys[0][0]:
            return keys[0][1], keys[0][1], 0.0
        for (t0, a, _), (t1, b, ease) in zip(keys, keys[1:]):
            if t <= t1:
                return a, b, _ease(ease, (t - t0) / (t1 - t0) if t1 > t0 else 1.0)
        return keys[-1][1], keys[-1][1], 0.0


# ---------------------------------------------------------------- the body
def body_transforms(ch):
    root = T(Vector(ch["pos"])) @ ry(-ch["yaw"]) @ rx(-ch["lean"]) @ rz(-ch["side"])
    waist = rx(-ch["cbend"]) @ ry(-ch["ctwist"]) @ rz(-ch["cside"])
    neck = rx(ch["up"]) @ ry(-ch["turn"]) @ rz(-ch["hroll"])
    return {"Root": root, "Waist": waist, "Neck": neck}


def _shoulder(side, a):
    if side == "Left":
        return rz(-a["raise"]) @ rx(a["swing"]) @ ry(a["twist"])
    return rz(a["raise"]) @ rx(a["swing"]) @ ry(-a["twist"])


def _blend_arm(side, a, b, u):
    """Blend two arm solutions: the shoulder as a ROTATION (the shortest turn), the elbow linearly. (2026-11-14: the
    number-by-number blend of raise/swing/twist swung the arm the long way round, elbows behind the body, between keys
    whose solutions were near each other but numbered far apart; user: "physically impossible to go backwards".)"""
    near = _lerp(a, b, u)
    qa, qb = _shoulder(side, a).to_quaternion(), _shoulder(side, b).to_quaternion()
    q = qa.slerp(qb, u)
    sg = 1.0 if side == "Left" else -1.0
    compat = Euler((math.radians(near["swing"]), math.radians(sg * near["twist"]), math.radians(-sg * near["raise"])),
                   "YXZ")
    e = q.to_matrix().to_euler("YXZ", compat)        # (exact round trip, checked: 2e-7)
    out = dict(near)
    out["swing"], out["twist"], out["raise"] = math.degrees(e.x), sg * math.degrees(e.y), -sg * math.degrees(e.z)
    return out


def _hip(side, g):
    if side == "Left":
        return rz(-g["out"]) @ ry(g["turn"]) @ rx(g["flex"])
    return rz(g["out"]) @ ry(-g["turn"]) @ rx(g["flex"])


def _arm_chain(upper, side, a, wrist=(0.0, 0.0)):
    ua = place(upper, side + "Shoulder", _shoulder(side, a))
    la = place(ua, side + "Elbow", rx(a["elbow"]))
    hand = place(la, side + "Wrist", rx(wrist[0]) @ ry(wrist[1]))
    return ua, la, hand


def _leg_chain(lower, side, g):
    ul = place(lower, side + "Hip", _hip(side, g))
    ll = place(ul, side + "Knee", rx(-g["bend"]))
    return ul, ll


def resolve_hand(spec, upper):
    """A hand target in floor space (None for ("angles", ...))."""
    frame, v = spec
    v = Vector(v)
    if frame == "hrp":
        return HRP + v
    if frame == "chest":
        return upper @ v
    if frame == "floor":
        return v
    return None


# ---------------------------------------------------------------- solving
ARM_KEYS = ("raise", "swing", "twist", "elbow")
# The most an elbow may bend (degrees). 150 for every clip unless the clip sets its own Clip.elbow_max (opt-in, 2026-11-16
# legs fix): Clip.solve() sets this for its own solve and puts it back after.
ELBOW_MAX = 150.0
LEG_KEYS = ("flex", "out", "turn", "bend")
STEPS = (8, 4, 2, 1, 0.5, 0.25)


def _descend(params, keys, cost, steps=STEPS):
    a, best = dict(params), cost(params)
    for step in steps:
        improved = True
        while improved:
            improved = False
            for k in keys:
                for d in (step, -step):
                    b = dict(a)
                    b[k] += d
                    c = cost(b)
                    if c < best - 1e-7:
                        a, best, improved = b, c, True
    return a, best


def _hand_at(upper, side, a, wrist):
    return _arm_chain(upper, side, a, wrist)[2].to_translation()


def _reach(upper, side, target, start, wrist, iterations=40):
    """Damped least squares on all four arm angles at once: the hand onto the target from `start`."""
    a = dict(start)
    damping = 0.004
    for _ in range(iterations):
        hand = _hand_at(upper, side, a, wrist)
        error = target - hand
        if error.length < 0.002:
            break
        columns = []
        for k in ARM_KEYS:
            b = dict(a)
            b[k] += 0.5
            columns.append((_hand_at(upper, side, b, wrist) - hand) / 0.5)
        m = Matrix(((0.0, 0.0, 0.0), (0.0, 0.0, 0.0), (0.0, 0.0, 0.0)))
        for c in columns:
            for i in range(3):
                for j in range(3):
                    m[i][j] += c[i] * c[j]
        for i in range(3):
            m[i][i] += damping * damping
        try:
            x = m.inverted() @ error
        except ValueError:
            break
        for k, c in zip(ARM_KEYS, columns):
            a[k] += max(-15.0, min(15.0, c.dot(x)))
        a["elbow"] = max(-5.0, min(ELBOW_MAX, a["elbow"]))
    return a


def auto_elbow(upper, side, target):
    """Where the elbow points when a clip doesn't say (chest frame): down, out and back for a low hand, out to the side
    for a hand at or over the head (arms up in a V, hands on the head)."""
    local = upper.inverted() @ target
    shoulder = _C0V[side + "Shoulder"]
    high = max(0.0, min(1.0, (local.y - shoulder.y + 0.3) / 1.0))
    low_dir, high_dir = Vector((-0.4, -1.0, 0.35)), Vector((-1.0, 0.15, 0.25))
    v = low_dir.lerp(high_dir, high)
    if side == "Right":
        v.x = -v.x
    return tuple(v)


# Natural arm shapes to start a key's solve from: hanging, forward, out to the side, up, overhead forward, bent up.
ARM_STARTS = [
    {"raise": 4.0, "swing": 0.0, "twist": 0.0, "elbow": 8.0},
    {"raise": 10.0, "swing": 60.0, "twist": 0.0, "elbow": 40.0},
    {"raise": 85.0, "swing": 0.0, "twist": 0.0, "elbow": 15.0},
    {"raise": 150.0, "swing": 10.0, "twist": 0.0, "elbow": 10.0},
    {"raise": 30.0, "swing": 140.0, "twist": 0.0, "elbow": 20.0},
    {"raise": 80.0, "swing": 10.0, "twist": -60.0, "elbow": 100.0},
    {"raise": 20.0, "swing": 40.0, "twist": 30.0, "elbow": 120.0},
    {"raise": 15.0, "swing": -50.0, "twist": 0.0, "elbow": 10.0},
]


def solve_arm(upper, side, target, elbow_dir, previous, wrist, firm=False):
    """firm: the clip named the elbow's direction, so it outweighs the wish for an untwisted arm."""
    pole = upper.to_3x3() @ Vector(elbow_dir)
    if pole.length > 1e-6:
        pole.normalize()
    shoulder_at = upper @ _C0V[side + "Shoulder"]
    start = _reach(upper, side, target, previous, wrist)

    def cost(a):
        if not (-5 <= a["elbow"] <= ELBOW_MAX):
            return 1e9
        ua, la, hand = _arm_chain(upper, side, a, wrist)
        c = 6.0 * (hand.to_translation() - target).length
        # the elbow toward its hint, measured off the shoulder-hand line
        elbow = la @ _C1V[side + "Elbow"]
        line = hand.to_translation() - shoulder_at
        if line.length > 1e-6 and a["elbow"] > 15:
            u = line.normalized()
            off = (elbow - shoulder_at) - u * (elbow - shoulder_at).dot(u)
            if off.length > 1e-6:
                c += (1.5 if firm else 0.25) * (1 - off.normalized().dot(pole))
        # no needless twist; close to the last frame (no flips)
        c += (0.0015 if firm else 0.006) * abs(a["twist"]) + 0.0004 * abs(a["raise"])
        c += 0.002 * sum(abs(a[k] - previous[k]) for k in ARM_KEYS)
        return c
    return _descend(start, ARM_KEYS, cost, steps=(2, 1, 0.5, 0.25))


def foot_rotation(side, yaw, pitch):
    sx = -1 if side == "Left" else 1
    return ry(-sx * yaw) @ rx(pitch)


_FOOT_CORNERS = [Vector((x * 0.5, y * 0.15, z * 0.5)) - _C1V["LeftAnkle"] for x in (-1, 1) for y in (-1, 1)
                 for z in (-1, 1)]


def foot_low(side, yaw, pitch, ankle):
    """The lowest point of the foot box with its ankle at `ankle`, turned and pitched as given."""
    r = foot_rotation(side, yaw, pitch).to_3x3()
    return min((ankle + r @ c).y for c in _FOOT_CORNERS)


# The leg's two bones run straight down their parts' -Y: hip -> knee, knee -> ankle.
THIGH = _C1V["LeftHip"].y - _C0V["LeftKnee"].y
SHIN = _C1V["LeftKnee"].y - _C0V["LeftAnkle"].y


def solve_leg(lower, side, ankle_target, knee_target, foot_yaw):
    """Exact two-bone leg: (hip transform, knee bend). The ankle goes to its target; the knee bends toward the toes, or
    toward knee_target (kneeling). A target out of reach leaves the leg straight toward it."""
    sx = -1 if side == "Left" else 1
    hip_at = lower @ _C0V[side + "Hip"]
    toes = (ry(-sx * foot_yaw).to_3x3() @ Vector((0, 0, -1)))
    to_ankle = ankle_target - hip_at
    length = max(0.05, to_ankle.length)
    u = to_ankle / length

    def across(v, axis):
        w = v - axis * v.dot(axis)
        return w.normalized() if w.length > 1e-5 else None

    if knee_target is not None and knee_target[0] == "blend":
        _, point, weight = knee_target
        free_hip, free_bend = solve_leg(lower, side, ankle_target, None, foot_yaw)
        free_knee = place(lower, side + "Hip", free_hip) @ _C0V[side + "Knee"]
        knee_target = tuple(free_knee.lerp(Vector(point), weight))
    # The knee bends toward the toes, or toward its target (kneeling): the ankle always lands on its own target, and
    # the knee on its target whenever the two agree (they do for every kneel written in the clips).
    d = min(length, THIGH + SHIN - 1e-4)
    pole = None
    if knee_target is not None:
        pole = across(Vector(knee_target) - hip_at, u)
    pole = pole or across(toes, u) or across(Vector((0, 0, -1)), u) or Vector((0, 0, -1))
    cos_a = max(-1.0, min(1.0, (THIGH * THIGH + d * d - SHIN * SHIN) / (2 * THIGH * d)))
    a = math.acos(cos_a)
    thigh_dir = u * math.cos(a) + pole * math.sin(a)
    knee = hip_at + thigh_dir * THIGH
    shin_dir = ((hip_at + u * d) - knee).normalized()
    y_axis = -thigh_dir
    z_axis = across(shin_dir, thigh_dir)
    if z_axis is None or shin_dir.dot(thigh_dir) > 0.99995:
        z_axis = across(-toes, thigh_dir) or Vector((0, 0, 1))
    x_axis = y_axis.cross(z_axis)
    thigh_rot = Matrix((x_axis, y_axis, z_axis)).transposed()
    bend = math.degrees(math.acos(max(-1.0, min(1.0, thigh_dir.dot(shin_dir)))))
    hip = (lower.to_3x3().inverted() @ thigh_rot).to_4x4()
    return hip, bend


# ---------------------------------------------------------------- clothes count as the body (rules 16-17, 2026-11-16)
# One animation plays on all six builds, each with its own shoulder width and arm splay, wearing the meet outfit (tee,
# singlet, belt). A hand or forearm must never sink into the clothes on ANY build (contact fitted to the widest clothed
# build; a small float on Skinny is accepted, user 2026-11-16). anim_qa.py measures it (arm_in_outfit); this makes the
# clips meet it while they are solved.
#
# The ENVELOPE (a data file made from the real bodies and the game's outfit exports, export_envelope() below): per
# build its rest joints, the skin of the torso and thighs sampled every ~0.07 stud with each spot's outward normal and
# how thick the outfit is stacked on it there (the same layer stacking as anim_qa: the tee, the singlet over it, the
# belt over that), and the forearm's far half and the hand (open and fist) as points. Each solved frame is posed on
# every build exactly as the game and anim_qa pose a shared animation (each part = parent * (its rest joint offset) *
# the joint's Transform), and when a hand or forearm point would sit inside the outfit plus CLOTHED_MARGIN on any build,
# that hand is moved out along the clothes' normal there and the arm re-solved (a few rounds). A clip opts in with
# clothed=True (celebration_animations does for every celebration; emotes are not touched).
#   make the envelope:  blender -b art/blender/CartoonBodies_05_Rigged.blend --python art/scripts/celebration_rig.py
#                         -- envelope [out.json]
ENVELOPE_PATH = os.environ.get("CELEB_ENVELOPE") or os.path.join(os.path.dirname(_HERE), "data",
                                                                   "clothed_envelope_05.json")
CLOTHED_LAYER_EXTRA = 1.3     # + this share of a layer's thickness past 0.13 (the belt, 0.19-0.27, bends and slides more
#                               than the skin as the body bends: measured 0.04-0.11 further out in anim_qa on Fat bent
#                               over; the tee and the shorts get ~none: the hand hanging at rest stays exactly the idle's)
CLOTHED_MARGIN = 0.04          # clearance over the outermost layer (anim_qa's limit is 0.03 INTO it; the singlet may
#                                still move out a little, 2026-11-16)
CLOTHED_UP_SHARE = 0.3        # how much of the clothes' normal's chest-up part a push keeps (clear_of_clothes)
CLOTHED_PARTS = ("UpperTorso", "LowerTorso", "LeftUpperLeg", "RightUpperLeg")   # anim_qa.OUTFIT_BODY_PARTS

def centre_outfit(meshes, part_of=lambda o: o.name.partition("__")[2].split(".")[0]):
    """The exports store each build's pieces where that build stood in the gear file (Fat 9.2 studs over, Muscular
    18.4, BigBuff 23) while its skeleton stands at the centre: move the pieces' mesh data onto the centre line (the
    outfit is left-right symmetric; its torso pieces' middle). 2026-11-16: missed, so on every build but Skinny the
    clothes were far from the body and only the skin was kept clear of / checked."""
    from mathutils import Matrix, Vector
    xs = [v.co.x for o in meshes if part_of(o) == "UpperTorso" for v in o.data.vertices]
    if not xs:
        return 0.0
    shift = -(min(xs) + max(xs)) / 2
    if abs(shift) <= 0.5:
        return 0.0
    for o in meshes:
        o.data.transform(Matrix.Translation(Vector((shift, 0, 0))))
    return shift
HAND_SHAPES = ("Open", "Fist", "Point", "ThumbsUp")     # (the game's hand swaps, HandShapeConfig)
_PART_JOINT = {child: joint for joint, (parent, child, c0, c1) in S.JOINTS.items()}
_PART_PARENT = {child: parent for joint, (parent, child, c0, c1) in S.JOINTS.items()}
_ENVELOPE = {}


def _envelope():
    """{build: {"J": {part: Vector}, "parts": {part: (KDTree, [(point, normal, layer)])}, "arm": {side: [(part, point)]}}}
    (rest, Roblox space, points relative to their part's joint)."""
    if not _ENVELOPE:
        import json
        from mathutils.kdtree import KDTree
        if not os.path.exists(ENVELOPE_PATH):
            raise FileNotFoundError(f"clothed envelope missing: {ENVELOPE_PATH} (make it: celebration_rig.py -- envelope)")
        data = json.load(open(ENVELOPE_PATH))
        for build, d in data["builds"].items():
            J = {k: Vector(v) for k, v in d["J"].items()}
            parts = {}
            for part, rows in d["skin"].items():
                pts = [(Vector(r[0:3]), Vector(r[3:6]), r[6]) for r in rows]
                tree = KDTree(len(pts))
                for i, (p, _n, _l) in enumerate(pts):
                    tree.insert(p, i)
                tree.balance()
                parts[part] = (tree, pts)
            # per hand shape: the forearm points go with every shape; the hand's are the open hand's unless the game
            # swaps in a fist / point / thumbs up then (Clip.hand_spans; the fist hanging at rest reads 0.04 into
            # Skinny's shorts, but at rest the game's hand is open)
            arm = {}
            for side in ("Left", "Right"):
                rows = [(r[2], r[0], Vector(r[1])) for r in d["arm"][side]]
                fore = [(part, v) for shape, part, v in rows if shape == "Arm"]
                arm[side] = {shape: fore + [(part, v) for sh, part, v in rows if sh == shape] for shape in HAND_SHAPES}
                for shape in HAND_SHAPES:
                    if len(arm[side][shape]) == len(fore):
                        arm[side][shape] = arm[side]["Open"]       # (a shape this build has no mesh for)
            _ENVELOPE[build] = {"J": J, "parts": parts, "arm": arm, "upper_r": d.get("upper_r")}
    return _ENVELOPE


_BUILD_ORDER = ["LowerTorso", "UpperTorso", "LeftUpperLeg", "RightUpperLeg", "LeftUpperArm", "LeftLowerArm", "LeftHand",
                "RightUpperArm", "RightLowerArm", "RightHand"]


def build_frames(J, pose, parts=_BUILD_ORDER):
    """A build's part frames (Roblox space, its root part standing at its rest place) for a pose {joint: Transform}:
    world[part] = world[parent] @ T(J[part] - J[parent]) @ Transform, as gear_fit_03.pose_rig and anim_qa pose it. A
    rest point p of a part is at world[part] @ (p - J[part])."""
    world = {"HumanoidRootPart": Matrix.Translation(J["HumanoidRootNode"])}
    for part in parts:
        parent = _PART_PARENT[part]
        jp = J["HumanoidRootNode"] if parent == "HumanoidRootPart" else J[parent]
        world[part] = world[parent] @ Matrix.Translation(J[part] - jp) @ pose.get(_PART_JOINT[part], Matrix.Identity(4))
    return world


def clothed_deficit(pose, side, margin=CLOTHED_MARGIN, shapes=("Open",)):
    """The worst over every build of how far this arm's hand / forearm far half sits inside the clothes + margin:
    (deficit, outward normal (Roblox world axes), how far along the forearm that point is (1 = the hand), build)."""
    worst = (0.0, None, 1.0, None)
    for build, env in _envelope().items():
        world = build_frames(env["J"], pose)
        inv = {p: world[p].inverted() for p in CLOTHED_PARTS}
        elbow = world[side + "LowerArm"].to_translation()
        hand_c = world[side + "Hand"].to_translation()
        reach = (hand_c - elbow).length
        # (quick: a hand far from the torso and thighs touches nothing)
        if min((hand_c - world[p].to_translation()).length for p in CLOTHED_PARTS) > 3.2:
            continue
        sh = world[side + "UpperArm"].to_translation()
        axis = world[side + "UpperArm"] @ (env["J"][side + "LowerArm"] - env["J"][side + "UpperArm"]) - sh
        profile = (env.get("upper_r") or {}).get(side)
        for part, q in [pt for shape in shapes for pt in env["arm"][side][shape]]:
            p = world[part] @ q
            if profile:
                u = (p - sh).dot(axis) / axis.length_squared
                if 0.0 <= u < 1.0 and (p - (sh + axis * u)).length < profile[int(u * 6)]:
                    continue        # (inside its own upper arm: not the clothes' business; anim_qa skips it too)
            best = None
            for name in CLOTHED_PARTS:
                local = inv[name] @ p
                tree, pts = env["parts"][name]
                co, i, dist = tree.find(local)
                if co is not None and (best is None or dist < best[0]):
                    best = (dist, name, local, i)
            if best is None or best[0] > 0.6:
                continue
            dist, name, local, i = best
            sp, n, layer = env["parts"][name][1][i]
            s = (local - sp).dot(n)
            deficit = layer + CLOTHED_LAYER_EXTRA * max(0.0, layer - 0.13) + margin - s     # (thick layers (the belt) shift more
            #                                                               as the body bends: a share extra)
            if deficit > worst[0]:
                along = max(0.35, min(1.0, (p - elbow).length / max(reach, 1e-3)))
                worst = (deficit, (world[name].to_3x3() @ n).normalized(), along, build)
    return worst


def clear_of_clothes(pose, upper, side, angles, wrist, rounds=14, shapes=("Open",)):
    """The arm's angles moved (the hand out along the clothes' normal, the arm re-solved) until no build's hand or
    forearm sits inside the outfit + margin. Returns (angles, how far the hand moved)."""
    moved = Vector((0, 0, 0))
    for _ in range(rounds):
        pose[side + "Shoulder"] = _shoulder(side, angles)
        pose[side + "Elbow"] = rx(angles["elbow"])
        deficit, normal, along, _build = clothed_deficit(pose, side, shapes=shapes)
        if deficit <= 1e-4:
            break
        hand = _hand_at(upper, side, angles, wrist)
        # Out mostly level with the chest, not along a sloping belly's or pec's normal (that dragged a chest clap down
        # to the belly): the chest-up part of the push is damped, and the push made long enough to clear along the
        # true normal.
        up = (upper.to_3x3() @ Vector((0, 1, 0))).normalized()
        push = normal - up * (normal.dot(up) * (1 - CLOTHED_UP_SHARE))
        if push.length < 1e-6 or push.dot(normal) < 0.2:
            push = normal.copy()
        if hand.y < 1.2 and push.y < 0:
            push.y = 0.0            # (a hand down by the floor (a bow, kneeling) is never pushed into the floor)
            if push.length < 0.2 or push.normalized().dot(normal) < 0.2:
                break               # (nowhere to go but the floor: left as it is)
        push.normalize()
        step = push * ((deficit + 0.005) / max(0.35, push.dot(normal)))     # (a forearm point: several small rounds,
        #                                               not one hand move of deficit / along: that overshot 0.9 stud)
        angles = _reach(upper, side, hand + step, angles, wrist, 16)
        moved += _hand_at(upper, side, angles, wrist) - hand
    pose[side + "Shoulder"] = _shoulder(side, angles)
    pose[side + "Elbow"] = rx(angles["elbow"])
    return angles, moved.length


def export_envelope(path=ENVELOPE_PATH, spacing=0.07):
    """(Inside Blender, art/blender/CartoonBodies_05_Rigged.blend open.) Writes the envelope: every build's rest joints,
    its torso and thigh skin sampled every `spacing` with outward normals and the outfit's stacked thickness there, and
    its forearm far half + hand points (open hand and fist). The outfit is the game's (art/exports Cartoon{Clothes,Gear}05_
    <build>.glb), the same items and layer stacking anim_qa.py measures against."""
    import json
    import bpy
    from mathutils.bvhtree import BVHTree
    root = os.path.dirname(os.path.dirname(_HERE))
    to_b = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))     # (gear_fit_03.TO_B; its own inverse)
    items = ["Tee", "WornSinglet_Black", "WornSinglet_Red", "WornSinglet_Shorts", "WornSinglet_Trim",
             "WornLeverBelt_Outer", "WornLeverBelt_Lining", "WornLeverBelt_Lever"]
    first, gap, most = 0.15, 0.08, 0.35          # anim_qa OUTFIT_FIRST / OUTFIT_GAP / OUTFIT_MAX
    dg = None
    out = {"note": "celebration_rig.export_envelope: rest, Roblox space; skin rows (x, y, z, nx, ny, nz, layer) "
                   "relative to their part's joint; arm rows (part, (x, y, z) relative to the part's joint, shape)",
           "spacing": spacing, "builds": {}}
    builds = [o.name[:-3] for o in bpy.data.objects if o.type == "ARMATURE" and o.name.endswith("Rig")]
    for b in builds:
        rig = bpy.data.objects[b + "Rig"]
        for pb in rig.pose.bones:
            pb.matrix_basis = Matrix.Identity(4)
        before = set(bpy.data.objects)
        for kind in ("Clothes", "Gear"):
            found = sorted(glob.glob(os.path.join(root, "art", "exports", f"Cartoon{kind}[0-9][0-9]_{b}.glb")))
            p = found[-1] if found else ""   # (the newest outfit export: the highest version number on disk)
            if os.path.exists(p):
                bpy.ops.import_scene.gltf(filepath=p)
        cloth = []
        centre_outfit([o for o in bpy.data.objects if o not in before and o.type == "MESH"
                       and o.name.partition("__")[0] in items])
        for o in [o for o in bpy.data.objects if o not in before]:
            item, _, part = o.name.partition("__")
            if o.type == "MESH" and item in items and part.split(".")[0] in CLOTHED_PARTS:
                basis = o.matrix_world.copy()
                o.parent = rig
                o.matrix_parent_inverse = Matrix.Identity(4)
                o.matrix_basis = basis
                for m in o.modifiers:
                    if m.type == "ARMATURE":
                        m.object = rig
                cloth.append(o)
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        rinv = rig.matrix_world.inverted()

        def to_r(v):
            return to_b @ (rinv @ v)

        def mesh_of(objs):
            verts, polys = [], []
            for o in objs:
                ev = o.evaluated_get(dg)
                me = ev.to_mesh()
                base = len(verts)
                verts += [o.matrix_world @ v.co for v in me.vertices]
                polys += [tuple(base + i for i in p.vertices) for p in me.polygons]
                ev.to_mesh_clear()
            return verts, polys
        cv, cp = mesh_of(cloth)
        cloth_t = BVHTree.FromPolygons(cv, cp) if cp else None
        J = {bone.name: to_b @ bone.head_local for bone in rig.data.bones}
        skin = {}
        for part in CLOTHED_PARTS:
            verts, polys = mesh_of([bpy.data.objects[f"{b}_{part}"]])
            rows = []
            for poly in polys:
                pts = [verts[i] for i in poly]
                for k in range(1, len(pts) - 1):
                    a, c1, c2 = pts[0], pts[k], pts[k + 1]
                    nrm = (c1 - a).cross(c2 - a)
                    if nrm.length < 1e-9:
                        continue
                    nrm.normalize()
                    n = max(1, int(math.ceil(max((c1 - a).length, (c2 - a).length, (c2 - c1).length) / spacing)))
                    for i in range(n + 1):
                        for j in range(n + 1 - i):
                            u, v = (i + 1 / 3) / (n + 1), (j + 1 / 3) / (n + 1)
                            if u + v > 1:
                                continue
                            loc = a + (c1 - a) * u + (c2 - a) * v
                            layer, q = 0.0, loc + nrm * 0.002
                            for _ in range(8):
                                hit = cloth_t.ray_cast(q, nrm, first if layer == 0.0 else gap) if cloth_t else (None,)
                                if hit[0] is None:
                                    break
                                layer = (hit[0] - loc).dot(nrm)
                                q = hit[0] + nrm * 1e-4
                                if layer > most:
                                    break
                            r = to_r(loc) - J[part]
                            rn = (to_b.to_3x3() @ (rinv.to_3x3() @ nrm)).normalized()
                            rows.append([round(x, 4) for x in (*r, *rn)] + [round(min(layer, most), 4)])
            skin[part] = rows
        arm, upper_r = {}, {}
        for side in ("Left", "Right"):
            rows = []
            elbow = J[side + "LowerArm"]
            for name, part, shape in ((f"{b}_{side}LowerArm", side + "LowerArm", "Arm"),
                                      (f"{b}_{side}Hand", side + "Hand", "Open"), (f"{b}_Fist{side}", side + "Hand", "Fist"),
                                      (f"{b}_Point{side}", side + "Hand", "Point"),
                                      (f"{b}_ThumbsUp{side}", side + "Hand", "ThumbsUp")):
                o = bpy.data.objects.get(name)
                if o is None:
                    continue
                verts, _p = mesh_of([o])
                for v in verts:
                    r = to_r(v)
                    if (r - elbow).length < 0.6:          # (anim_qa: the hand and the forearm's far half)
                        continue
                    rows.append([part, [round(x, 4) for x in (r - J[part])], shape])
            arm[side] = rows
            # the upper arm's thickness along it (6 bins shoulder -> elbow, 70th percentile of the skin's distance from
            # the bone): a forearm point inside it is the upper arm's business, as anim_qa skips it (a fist pumped up
            # with the forearm folded on the biceps)
            sh, el = J[side + "UpperArm"], J[side + "LowerArm"]
            axis = el - sh
            bins = [[] for _ in range(6)]
            verts, _p = mesh_of([bpy.data.objects[f"{b}_{side}UpperArm"]])
            for v in verts:
                r = to_r(v)
                u = max(0.0, min(0.999, (r - sh).dot(axis) / axis.length_squared))
                bins[int(u * 6)].append((r - (sh + axis * u)).length)
            upper_r[side] = [round(sorted(x)[int(len(x) * 0.7)] if x else 0.0, 4) for x in bins]
        for o in cloth:
            bpy.data.objects.remove(o, do_unlink=True)
        out["builds"][b] = {"J": {k: [round(x, 5) for x in v] for k, v in J.items()}, "skin": skin, "arm": arm,
                            "upper_r": upper_r}
        print(f"[Envelope] {b}: skin " + ", ".join(f"{k} {len(v)}" for k, v in skin.items()) +
              f"; arm points {len(arm['Left'])}/{len(arm['Right'])}; outfit pieces {len(cloth)}")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump(out, open(path, "w"))
    print("[Envelope] wrote", path)


# ---------------------------------------------------------------- a clip
class Clip:
    """A celebration: keys, optional layers, and how it is exported."""

    STEP = 1 / 30          # solve and write every 1/30 s
    # (opt-in, 2026-11-16 legs fix) the most this clip's elbows may bend (degrees; None = ELBOW_MAX, 150). The rebuilt
    # bodies (CartoonBodies_05_Rigged, longer-thigh rebuild) fold BigBuff's forearm 0.26-0.27 into its own biceps with
    # the elbow bent ~128-148 degrees (anim_qa arm_in_body limit 0.26); a clip that bends that far sets 126 here, and a
    # hand keyed closer to its shoulder than that bend reaches stops a little short, out along the arm.
    elbow_max = None

    def __init__(self, name, length, keys, layers=(), title="", notes="", contact=False, clothed=False):
        self.name, self.length, self.layers, self.title, self.notes = name, length, list(layers), title, notes
        self.clothed = clothed      # (hands and forearms kept out of every build's clothes: clear_of_clothes)
        self.clothed_moved = 0.0    # (the most a hand was moved out of the clothes, for the CHECK line)
        self.hand_spans = None      # {side: [(t0, t1, shape)]}: the game's hand swaps (HandShapeConfig), for clothed
        self.contact = contact and S.RIG == "torso"     # (hands stop at the skin: S.contact_out)
        # palms (torso rig): authored body contact, set after creation: {"spot": left hand's spot (root frame; the
        # right mirrors), "fingers": left fingers' direction, "weight": [(t, 0..1)], "below": elbow under the hand}
        self.palms = None
        self.tracks = {}
        for t, values in keys:
            ease = values.get("ease", "smooth")
            for channel, value in values.items():
                if channel == "ease":
                    continue
                if channel not in DEFAULTS:
                    raise ValueError(f"{name}: unknown channel {channel}")
                self.tracks.setdefault(channel, Track()).keys.append((t, value, ease))
        for channel, track in self.tracks.items():
            track.keys.sort(key=lambda k: k[0])
            # Every clip starts standing: a channel first keyed later starts from its default.
            if track.keys[0][0] > 0:
                track.keys.insert(0, (0.0, DEFAULTS[channel], "smooth"))
        self._table = None
        self._arm_cache = {}
        self.worst_hand = 0.0
        self.worst_foot = 0.0

    def channels(self, t):
        """The channels at t, interpolated (hand targets still as specs, with their blend)."""
        ch, blends = {}, {}
        for name, default in DEFAULTS.items():
            track = self.tracks.get(name)
            if track is None:
                ch[name] = default
                continue
            a, b, u = track.at(t)
            if name in ("lh", "rh"):
                ia, ib, u = track.at_keys(t)
                blends[name] = (ia, ib, u)
                ch[name] = a
            elif name in ("lk", "rk") and (a is None) != (b is None):
                # easing a knee onto the floor or off it: ("blend", point, how far onto it)
                ch[name] = ("blend", b, u) if a is None else ("blend", a, 1 - u)
            else:
                ch[name] = _lerp(a, b, u)
        for layer in self.layers:
            for name, delta in layer(t, ch).items():
                if name in ("lh", "rh"):
                    ch[name + "_add"] = ch.get(name + "_add", Vector((0, 0, 0))) + Vector(delta)
                elif isinstance(ch[name], (int, float)):
                    ch[name] += delta
                else:
                    ch[name] = tuple(x + y for x, y in zip(ch[name], delta))
        return ch, blends

    def _solve_at(self, t, prev):
        ch, blends = self.channels(t)
        body = body_transforms(ch)
        lower = place(HRP_M, "Root", body["Root"])
        upper = place(lower, "Waist", body["Waist"])
        pose = dict(body)
        out_prev = {}
        for side, sx in SIDES:
            s = _SHORT[side]
            # arm: each end of the current stretch solved onto its target (or given as angles), then the ANGLES blended,
            # so the hand moves on a natural arc and never cuts straight through the body
            wrist = ch[s + "w"]
            track = self.tracks.get(s + "h")
            if track is None:
                ends = [(None, DEFAULTS[s + "h"])]
                u = 0.0
            else:
                ia, ib, u = blends[s + "h"]
                ends = [(ia, track.keys[ia][1]), (ib, track.keys[ib][1])]
            solved = []
            # (the miss is measured only for the end actually shown: at a blend's start the first, at its end the
            #  second; the other end's target, with ~0 weight, was being counted too, 2026-11-14)
            shown = 0 if u < 0.02 else (len(ends) - 1 if u > 0.98 else None)
            for end_i, (index, spec) in enumerate(ends):
                if spec[0] == "angles":
                    solved.append(dict(spec[1]))
                    continue
                target = resolve_hand(spec, upper)
                if self.contact:
                    to_root = HRP_M.inverted()
                    target = HRP_M @ S.contact_out(to_root @ target, {"UpperTorso": to_root @ upper,
                                                                      "LowerTorso": to_root @ lower})
                firm = s + "e" in self.tracks
                # The key is solved with the elbow and wrist the clip gives AT THE KEY'S TIME, not the values still
                # blending in at this frame (2026-11-14: a key first solved early, while the elbow was still blending
                # from the default "down and back", kept an elbow-behind solution for good; user: "physically
                # impossible to go backwards").
                key_t = track.keys[index][0] if (track is not None and index is not None) else t
                if firm:
                    ea, eb, eu = self.tracks[s + "e"].at(key_t)
                    elbow_dir = _lerp(ea, eb, eu)
                else:
                    elbow_dir = auto_elbow(upper, side, target)
                key_wrist = wrist
                if s + "w" in self.tracks:
                    wa, wb, wu = self.tracks[s + "w"].at(key_t)
                    key_wrist = _lerp(wa, wb, wu)
                warm = self._arm_cache.get((s, index))
                if warm is None:
                    # First time this key is solved: from several natural arm shapes, keep the best (the least
                    # twisted), so keys blend into each other without the arm swinging through odd shapes.
                    best = None
                    for start in [prev[s + "arm"], *ARM_STARTS]:
                        candidate = solve_arm(upper, side, target, elbow_dir, start, key_wrist, firm)
                        if best is None or candidate[1] < best[1]:
                            best = candidate
                    angles = best[0]
                else:
                    angles, _ = solve_arm(upper, side, target, elbow_dir, warm, key_wrist, firm)
                self._arm_cache[(s, index)] = angles
                if shown == end_i:
                    hand = _hand_at(upper, side, angles, wrist)
                    self.worst_hand = max(self.worst_hand, (hand - target).length)
                    if (hand - target).length > 0.3 and __import__("os").environ.get("CELEB_DEBUG"):
                        print(f"MISS {self.name} t {t:.2f} {side} {(hand - target).length:.2f} spec {spec}")
                solved.append(angles)
            angles = solved[0] if len(solved) == 1 else _blend_arm(side, solved[0], solved[1], u)
            extra = ch.get(s + "h_add")
            if extra is not None and extra.length > 1e-5:
                angles = _reach(upper, side, _hand_at(upper, side, angles, wrist) + extra, angles, wrist, 12)
            out_prev[s + "arm"] = angles
            pose[side + "Shoulder"] = _shoulder(side, angles)
            pose[side + "Elbow"] = rx(angles["elbow"])
            pose[side + "Wrist"] = rx(wrist[0]) @ ry(wrist[1])
            # leg
            fx, fy, fz, fyaw, fpitch = ch[s + "f"]
            ankle_target = Vector((fx, fy, fz))
            # A foot never goes through the floor: lift the ankle by however far its lowest corner would sink.
            sink = foot_low(side, fyaw, fpitch, ankle_target)
            if sink < 0:
                ankle_target.y -= sink
            hip, bend = solve_leg(lower, side, ankle_target, ch[s + "k"], fyaw)
            out_prev[s + "leg"] = None
            pose[side + "Hip"] = hip
            pose[side + "Knee"] = rx(-bend)
            ul = place(lower, side + "Hip", hip)
            ll = place(ul, side + "Knee", rx(-bend))
            self.worst_foot = max(self.worst_foot, ((ll @ _C0V[side + "Ankle"]) - ankle_target).length)
            want = foot_rotation(side, fyaw, fpitch)
            pose[side + "Ankle"] = (ll.to_3x3().inverted() @ want.to_3x3()).to_4x4()
        if self.clothed:
            # (after both legs: a hand by the thigh needs the thigh where it is this frame)
            for side, sx in SIDES:
                s = _SHORT[side]
                # (the open hand always, and the swapped-in shape in its span: both must clear, so the clip passes
                #  anim_qa with open hands and with the game's shapes, and a swap a frame early or late is safe)
                shapes = ("Open",) + tuple(sh for t0, t1, sh in (self.hand_spans or {}).get(side, ())
                                           if t0 - 0.05 <= t < t1 + 0.05 and sh != "Open")
                _angles, moved = clear_of_clothes(pose, upper, side, dict(out_prev[s + "arm"]), ch[s + "w"],
                                                  shapes=shapes)
                if moved > self.clothed_moved:
                    self.clothed_moved, self.clothed_moved_at = moved, (t, side)
        return pose, out_prev

    @staticmethod
    def _weight(keys, t):
        if t <= keys[0][0]:
            return keys[0][1]
        if t >= keys[-1][0]:
            return keys[-1][1]
        for (t0, a), (t1, b) in zip(keys, keys[1:]):
            if t0 <= t <= t1:
                u = (t - t0) / (t1 - t0)
                return a + (b - a) * u * u * (3 - 2 * u)
        return 0.0

    def _palms_at(self, t, pose):
        """palms: one dict for both hands (the right mirrored), or {"Left": {...}, "Right": {...}} (each its own true
        spot, fingers and weight: hands that do different things, like alternating slaps)."""
        starts = getattr(self, "_palm_starts", None) or {s: {"raise": 40.0, "swing": 60.0, "twist": 0.0, "elbow": 110.0}
                                                         for s in ("Left", "Right")}
        for side in ("Left", "Right"):
            if "Left" in self.palms:
                spec = self.palms.get(side)
                if not spec:
                    continue
                spot, fingers = Vector(spec["spot"]), Vector(spec["fingers"])
            else:
                spec = self.palms
                spot, fingers = Vector(spec["spot"]), Vector(spec["fingers"])
                if side == "Right":
                    spot, fingers = Vector((-spot.x, spot.y, spot.z)), Vector((-fingers.x, fingers.y, fingers.z))
            w = self._weight(spec["weight"], t)
            pose, starts[side] = S.palm_contact(pose, side, spot, fingers, w, starts[side], spec.get("below", 0.25),
                                                spec.get("facing"))
        self._palm_starts = starts
        return pose

    def solve(self):
        global ELBOW_MAX
        keep_max = ELBOW_MAX
        if self.elbow_max is not None:
            ELBOW_MAX = float(self.elbow_max)
        try:
            prev = {"larm": dict(START_ARM), "rarm": dict(START_ARM), "lleg": None, "rleg": None}
            self._arm_cache = {}
            self._table = []
            n = int(math.ceil(self.length / self.STEP))
            for i in range(n + 1):
                t = min(self.length, i * self.STEP)
                pose, prev = self._solve_at(t, prev)
                if self.palms and S.RIG == "torso":
                    pose = self._palms_at(t, pose)
                self._table.append((t, pose))
        finally:
            ELBOW_MAX = keep_max
        return self

    def pose(self, t):
        if self._table is None:
            self.solve()
        i = int(round(max(0.0, min(self.length, t)) / self.STEP))
        return self._table[min(i, len(self._table) - 1)][1]

    def samples(self):
        if self._table is None:
            self.solve()
        return self._table


# ---------------------------------------------------------------- checks and export
def world_of(pose):
    return S.forward_kinematics(HRP_M, pose)


def lowest_point(world):
    low = 99.0
    # (The lower legs' box corners at the ankle dip into the floor in any deep knee bend on this blocky rig, as in the
    # station squats: the knees themselves are checked instead.)
    for side in ("Left", "Right"):
        low = min(low, (world[side + "LowerLeg"] @ _C1V[side + "Knee"]).y - KNEE_ON_FLOOR)
    for part in ("LeftFoot", "RightFoot", "LeftHand", "RightHand", "Head",
                 "UpperTorso", "LowerTorso", "LeftUpperLeg", "RightUpperLeg"):
        sx, sy, sz = S.SIZES[part]
        m = world[part]
        for x in (-1, 1):
            for y in (-1, 1):
                for z in (-1, 1):
                    low = min(low, (m @ Vector((x * sx / 2, y * sy / 2, z * sz / 2))).y)
    return low


def check(clip):
    """A line of numbers: the lowest point of the body (the floor is 0; below -0.15 sinks in), the worst hand and foot
    misses, and how far the start and end are from standing (they must be ~0 to blend in and out cleanly)."""
    lowest = 99.0
    for t, pose in clip.samples():
        lowest = min(lowest, lowest_point(world_of(pose)))
    stand = world_of({})

    def off(pose):
        w = world_of(pose)
        return max((w[p].to_translation() - stand[p].to_translation()).length for p in S.ORDER)
    first, last = clip.samples()[0][1], clip.samples()[-1][1]
    return (f"{clip.name}: {clip.length:.1f} s, lowest {lowest:.2f}, hand miss {clip.worst_hand:.3f}, "
            f"foot miss {clip.worst_foot:.3f}, start off {off(first):.2f}, end off {off(last):.2f}"
            + (f", moved out of the clothes up to {clip.clothed_moved:.2f} (t, side {getattr(clip, 'clothed_moved_at', '-')})"
               if getattr(clip, "clothed", False) else ""))


def export(clip, priority=2, step=1 / 24, only=None, looped=False):
    """art/animations/Celebrate_<name>.rbxmx (Action priority by default, not looped). `only`: just these parts keyed
    (their parents go in at weight 0 and are left to whatever else plays: an arms-only clip over the walk)."""
    refs = iter(range(1, 1_000_000))
    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
           f'<Item class="KeyframeSequence" referent="RBX{next(refs)}"><Properties>'
           f'<float name="AuthoredHipHeight">{S.AUTHORED_HIP_HEIGHT:g}</float><bool name="Loop">{"true" if looped else "false"}</bool>'
           f'<string name="Name">Celebrate_{clip.name}</string><token name="Priority">{priority}</token>'
           f'</Properties>']
    children, parent_of = {}, {}
    for joint, (parent, child, c0, c1) in S.JOINTS.items():
        children.setdefault(parent, []).append((child, joint))
        parent_of[child] = parent
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

    steps = int(round(clip.length / step))
    for i in range(steps + 1):
        t = min(clip.length, i * step)
        out.append(f'<Item class="Keyframe" referent="RBX{next(refs)}"><Properties>'
                   f'<string name="Name">Keyframe</string><float name="Time">{t:.3f}</float></Properties>')
        out.append(pose_xml("HumanoidRootPart", clip.pose(t)))
        out.append("</Item>")
    out.append("</Item></roblox>")
    os.makedirs(S.OUT_DIR, exist_ok=True)
    path = os.path.join(S.OUT_DIR, f"Celebrate_{clip.name}.rbxmx")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    return path, steps + 1


# ---------------------------------------------------------------- previews (inside Blender)
def _entrance():
    spec = importlib.util.spec_from_file_location("entrance_animations", os.path.join(_HERE, "entrance_animations.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def preview_sheet(clip, folder, times=None, view="front", width=2200):
    """One image of the clip at several moments side by side, each labelled with its time. view: "front" (three
    quarters from the front-left), "side" (from its right) or "back"."""
    import bpy
    E = _entrance()
    scene = E._scene_setup(bpy)
    times = times or [clip.length * i / 7 for i in range(8)]
    spacing = 5.0
    along = Vector((1, 0, 0)) if view != "side" else Vector((0, -1, 0))
    cams = {"front": Vector((-7.0, -24.0, 4.0)), "side": Vector((24.0, -3.0, 3.0)), "back": Vector((6.0, 24.0, 4.0)),
            "face": Vector((0.0, -25.0, 2.5))}
    label_mat = E._material(bpy, "Label", (0.05, 0.05, 0.08))
    for i, t in enumerate(times):
        objs = E._figure(bpy, f"F{i}", (0.8, 0.08, 0.08))
        at = along * (i * spacing)
        E._place(objs, clip.pose(t), at)
        curve = bpy.data.curves.new(f"L{i}", "FONT")
        curve.body = f"{t:.2f}s"
        curve.size = 0.9
        text = bpy.data.objects.new(f"L{i}", curve)
        text.data.materials.append(label_mat)
        text.location = at + Vector((-0.9, 0, -1.4))
        text.rotation_euler = (cams[view] * -1).to_track_quat("-Z", "Z").to_euler()
        text.rotation_euler = (math.radians(80), 0, math.atan2(cams[view].x, -cams[view].y))
        scene.collection.objects.link(text)
    E._floor_lines(bpy, -3, (len(times) - 1) * spacing * abs(along.x) + 3, -3 - (len(times) - 1) * spacing * abs(along.y),
                   3, 3.0)
    far = along * ((len(times) - 1) * spacing)
    centre = far / 2 + Vector((0, 0, 2.2))
    E._camera(bpy, scene, centre + cams[view], centre, len(times) * spacing + 1)
    scene.render.resolution_x, scene.render.resolution_y = width, int(width * 0.26)
    os.makedirs(folder, exist_ok=True)
    scene.render.filepath = os.path.join(folder, f"{clip.name}_{view}.png")
    bpy.ops.render.render(write_still=True)
    return scene.render.filepath


if __name__ == "__main__":
    import sys
    _argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if _argv and _argv[0] == "envelope":
        export_envelope(_argv[1] if len(_argv) > 1 else ENVELOPE_PATH)
