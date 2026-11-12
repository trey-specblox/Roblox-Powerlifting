# The pose engine for the celebrations (GAME_DESIGN.md §36.4, celebrations from the user's 15 meet videos, 2026-11-11;
# References/Clip Study). Same Roblox R15 block rig, joints and exporter maths as the station reps, fails and hype moves
# (station_animations.py), but every limb is free on its own: one fist up, a step, a knee down, a jump, lying back.
#
# A clip is a list of keys: (time, {channel: value, ...}). Each channel is interpolated only between the keys that set
# it (like Blender's f-curves), with the ease of the later key ("ease": smooth / fast / slow / linear / hold). Then, each
# sampled moment, the body is built from the keyed angles and each arm and leg is SOLVED onto its keyed target.
#
# Space ("floor space"): Roblox's, +Y up, the character starts facing -Z, its Left is -X; the floor is y = 0 and the
# HumanoidRootPart sits at (0, 3, 0) as it does standing (HipHeight 2). Angles are degrees.
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
import os

from mathutils import Matrix, Vector

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
HANG_HAND = Vector((-1.5, -0.85, 0.0))      # left hand hanging, from the root part's centre (entrance_animations)
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
        a["elbow"] = max(-5.0, min(150.0, a["elbow"]))
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
        if not (-5 <= a["elbow"] <= 150):
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


# ---------------------------------------------------------------- a clip
class Clip:
    """A celebration: keys, optional layers, and how it is exported."""

    STEP = 1 / 30          # solve and write every 1/30 s

    def __init__(self, name, length, keys, layers=(), title="", notes=""):
        self.name, self.length, self.layers, self.title, self.notes = name, length, list(layers), title, notes
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
            for index, spec in ends:
                if spec[0] == "angles":
                    solved.append(dict(spec[1]))
                    continue
                target = resolve_hand(spec, upper)
                firm = s + "e" in self.tracks
                elbow_dir = ch[s + "e"] if firm else auto_elbow(upper, side, target)
                warm = self._arm_cache.get((s, index))
                if warm is None:
                    # First time this key is solved: from several natural arm shapes, keep the best (the least
                    # twisted), so keys blend into each other without the arm swinging through odd shapes.
                    best = None
                    for start in [prev[s + "arm"], *ARM_STARTS]:
                        candidate = solve_arm(upper, side, target, elbow_dir, start, wrist, firm)
                        if best is None or candidate[1] < best[1]:
                            best = candidate
                    angles = best[0]
                else:
                    angles, _ = solve_arm(upper, side, target, elbow_dir, warm, wrist, firm)
                self._arm_cache[(s, index)] = angles
                if u < 0.02 or u > 0.98:
                    hand = _hand_at(upper, side, angles, wrist)
                    self.worst_hand = max(self.worst_hand, (hand - target).length)
                solved.append(angles)
            angles = solved[0] if len(solved) == 1 else _lerp(solved[0], solved[1], u)
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
        return pose, out_prev

    def solve(self):
        prev = {"larm": dict(START_ARM), "rarm": dict(START_ARM), "lleg": None, "rleg": None}
        self._arm_cache = {}
        self._table = []
        n = int(math.ceil(self.length / self.STEP))
        for i in range(n + 1):
            t = min(self.length, i * self.STEP)
            pose, prev = self._solve_at(t, prev)
            self._table.append((t, pose))
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
            f"foot miss {clip.worst_foot:.3f}, start off {off(first):.2f}, end off {off(last):.2f}")


def export(clip, priority=2, step=1 / 24, only=None):
    """art/animations/Celebrate_<name>.rbxmx (Action priority by default, not looped). `only`: just these parts keyed
    (their parents go in at weight 0 and are left to whatever else plays: an arms-only clip over the walk)."""
    refs = iter(range(1, 1_000_000))
    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
           f'<Item class="KeyframeSequence" referent="RBX{next(refs)}"><Properties>'
           f'<float name="AuthoredHipHeight">2</float><bool name="Loop">false</bool>'
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
