# Meet lift setups (GAME_DESIGN.md §37.5, user 2026-11-08: "On squat im basically teleporting inside the bar, no unrack
# animation either on squat and bench. No walk up animation, no sitting down animation"), made from the SBD Sheffield
# 2026 meet video the user sent (Perkins' squat, Borenstein's bench, Lawrence's deadlift):
#
#   Setup_Squat     from where the walk out ends in front of the bar: two steps up, both hands grip the bar wide, duck
#                   under it, feet under the bar, brace, stand it up out of the J-cups, three steps back, set the stance
#   Setup_Bench     from just past the foot of the bench: turn round, step back to the bench, sit on its end, lie back,
#                   set the feet, grip the bar, unrack it to arms' length and hold it there
#   Setup_Deadlift  behind the floor bar: set the feet, stand tall and breathe, hinge down, grip (right hand, then
#                   left), drop the hips and set
#
# Each one ends exactly on the station rep animation's pose where the meet's lift starts (StationAnimationConfig
# MeetStages: squat 0.6 s, bench 0.6 s, deadlift 1.8 s), so the lift carries straight on from it.
#
# HOW THE BODY MOVES: in the game the root part stands still at the lift's spot (anchored) for the whole setup; the
# walking, sitting and lying are in the animation's Root joint, so the body moves away from the root part and back.
# Here every pose is made in the rack's own space (rack-local Roblox, StationLayout's numbers) with a "virtual" root
# that walks, and export turns it into a Root transform about the real one (FINAL).
#
#   blender -b --factory-startup --python art/scripts/setup_animations.py -- <preview folder>
# writes art/animations/Setup_<Lift>.rbxmx and, with a folder, preview frames of each at its rack there. Publish with
# art/scripts/upload_animations.py.
import importlib.util
import math
import os
import sys

from mathutils import Matrix, Quaternion, Vector

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\Powerlifting Roblox\art\scripts"


def _load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(_HERE, name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


E = _load("entrance_animations")
S = E.S
rx, ry, rz, T = S.rx, S.ry, S.rz, S.T
FACE = S.FACE_RACK                 # facing the rack (+Z rack-local)
STAND_Y = S.HRP_STAND_Y            # root part height standing (3.4 taller, 3.0 block)
ANKLE_Y = 0.2517                   # ankle joint above the floor with the sole flat (the feet keep their size)
# The leg's bones from the rig (taller rig, user 2026-11-12: x1.2286; block 0.822 and 0.926).
THIGH = S.JOINTS["LeftHip"][3][1] - S.JOINTS["LeftKnee"][2][1]      # hip joint to knee joint
SHIN = S.JOINTS["LeftKnee"][3][1] - S.JOINTS["LeftAnkle"][2][1]     # knee joint to ankle joint
STEP = 0.025                       # solving step (s); export samples every 0.05
I4 = Matrix.Identity(4)
C0_ROOT = T(S.JOINTS["Root"][2])
HANG = {"raise": 4.0, "swing": 0.0, "twist": 0.0, "elbow": 8.0}

# The rack (StationLayout ComboRack_01, rack-local): bar rests, the bench, the deadlift bar.
# The squat J-cups at the shoulder blades (user 2026-11-08; build_combo_rack_01.py hole 3.975): just under the 3.75
# where the bar rides on the back standing, so a slight knee bend gets under it and standing up lifts it off.
# The taller lifters (2026-11-12) get the squat J-cups 0.70 higher (4.365) and the bench J-cups 0.175 higher (3.315);
# the pad and the floor bar stay where they are.
BAR_SQUAT = Vector((0, S.BAR_REST_SQUAT_Y, -0.28))
BAR_BENCH = Vector((0, S.BAR_REST_BENCH_Y, -0.28))
PAD_TOP, PAD_END_Z = 1.2, -3.4
DL_BAR = Vector((0, 1.0, -4.2))
# Where each setup starts (the walk's end, MeetLiftAnimation.approachFor) and ends (the lift's spot).
SQUAT_APPROACH_Z, SQUAT_FINAL_Z = -1.2, -1.6
BENCH_APPROACH_Z = -4.6
DL_STAND_Z = -4.8
FINAL = {
    "Squat": T((0, STAND_Y, SQUAT_FINAL_Z)) @ FACE,
    "Bench": T((0, S.BENCH_ROOT_HEIGHT, -0.3 - S.BENCH_HEAD_UP)) @ rx(90),
    "Deadlift": T((0, STAND_Y, DL_STAND_Z)) @ FACE,
}
# Where the rep animation takes over (StationAnimationConfig.MeetStages) and its pose there.
REP_AT = {"Squat": 0.6, "Bench": 0.6, "Deadlift": 1.8}
REP_POSE = {"Squat": S.squat_pose, "Bench": S.bench_pose, "Deadlift": S.deadlift_pose}


# ---------------------------------------------------------------- small helpers
def smooth(u):
    return S.smooth(u)


def lerp(a, b, u):
    return a + (b - a) * u


def keyed(keys, t):
    """Value at t from [(time, value...)] keys: smoothstep between each pair (values: numbers or Vectors)."""
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            u = smooth((t - t0) / (t1 - t0)) if t1 > t0 else 1.0
            return v0.lerp(v1, u) if isinstance(v0, Vector) else lerp(v0, v1, u)
    return keys[-1][1]


def root_at(pos, yaw_deg):
    """The virtual root: at `pos` (rack-local), turned `yaw_deg` from facing -Z (180 = facing the rack)."""
    return T(pos) @ ry(yaw_deg)


def yaw_of(m):
    f = m.to_3x3() @ Vector((0, 0, -1))
    return math.degrees(math.atan2(-f.x, -f.z))


def blend_pose(a, b, u):
    """Joint transforms a -> b by u: rotations slerped, translations lerped."""
    out = {}
    for joint in set(a) | set(b):
        ma, mb = a.get(joint, I4), b.get(joint, I4)
        q = ma.to_quaternion().slerp(mb.to_quaternion(), u)
        out[joint] = T(ma.to_translation().lerp(mb.to_translation(), u)) @ q.to_matrix().to_4x4()
    return out


def frame(down, forward):
    """A part's rotation whose local -Y points along `down` and local -Z as near `forward` as it can."""
    y = -down.normalized()
    f = forward - y * forward.dot(y)
    if f.length < 1e-6:
        f = Vector((0, 0, -1)) - y * (-y.z)
    z = -f.normalized()
    x = y.cross(z)
    return Matrix((x, y, z)).transposed().to_4x4()


def upper_frames(root, pose):
    """World matrices of the lower and upper torso (the arms and legs hang off these)."""
    _, _, c0, c1 = S.JOINTS["Root"]
    lt = root @ T(c0) @ pose.get("Root", I4) @ T(c1).inverted()
    _, _, c0, c1 = S.JOINTS["Waist"]
    ut = lt @ T(c0) @ pose.get("Waist", I4) @ T(c1).inverted()
    return lt, ut


# ---------------------------------------------------------------- legs (two-bone, feet where they are told)
def leg_ik(pose, lt, side, ankle, foot_rot, knee_dir):
    """Hip, knee and ankle transforms that put `side`'s ankle joint on `ankle` (world), the foot turned `foot_rot`
    (world rotation) and the knee bending toward `knee_dir`. Too far to reach: as near as a straight leg gets."""
    sx = -1 if side == "Left" else 1
    hip = lt @ Vector(S.JOINTS[side + "Hip"][2])
    d = ankle - hip
    reach = min(d.length, THIGH + SHIN - 1e-4)
    u = d.normalized()
    cos_a = max(-1.0, min(1.0, (THIGH ** 2 + reach ** 2 - SHIN ** 2) / (2 * THIGH * reach)))
    pole = knee_dir - u * knee_dir.dot(u)
    pole = pole.normalized() if pole.length > 1e-6 else Vector((0, 0, -1))
    knee = hip + (u * cos_a + pole * math.sqrt(1 - cos_a ** 2)) * THIGH
    end = hip + u * reach
    r_thigh = frame(knee - hip, pole)
    r_shin = frame(end - knee, pole)
    r_lt = lt.to_3x3().to_4x4()
    pose[side + "Hip"] = r_lt.inverted() @ r_thigh
    pose[side + "Knee"] = r_thigh.inverted() @ r_shin
    pose[side + "Ankle"] = r_shin.inverted() @ foot_rot


def foot_rot(yaw_deg, side, toes=0.0, pitch=0.0):
    """A foot flat on the floor (or pitched, + toes up) facing yaw_deg, turned out by `toes`."""
    sx = -1 if side == "Left" else 1
    return ry(yaw_deg) @ ry(-sx * toes) @ rx(pitch)


class Steps:
    """One foot's moves: [(t0, t1, from, to, yaw0, yaw1)] ankle points (world) and facings; a foot lifts `lift` studs
    on the way and stays put between moves."""

    def __init__(self, start, yaw, toes, moves, lift=0.22):
        self.start, self.yaw, self.toes, self.moves, self.lift = start, yaw, toes, moves, lift

    def at(self, t):
        pos, yaw = self.start, self.yaw
        for t0, t1, p0, p1, y0, y1 in self.moves:
            if t < t0:
                break
            if t <= t1:
                u = (t - t0) / (t1 - t0)
                p = p0.lerp(p1, smooth(u))
                return p + Vector((0, self.lift * math.sin(math.pi * u), 0)), lerp(y0, y1, smooth(u)), \
                    5.0 * math.sin(math.pi * u)
            pos, yaw = p1, y1
        return pos, yaw, 0.0


# ---------------------------------------------------------------- arms (each hand on its own target)
def arm_tf(side, a):
    if side == "Left":
        return rz(-a["raise"]) @ rx(a["swing"]) @ ry(a["twist"]), rx(a["elbow"])
    return rz(a["raise"]) @ rx(a["swing"]) @ ry(-a["twist"]), rx(a["elbow"])


def hand_world(ut, side, a):
    sh, el = arm_tf(side, a)
    _, _, c0, c1 = S.JOINTS[side + "Shoulder"]
    upper = ut @ T(c0) @ sh @ T(c1).inverted()
    _, _, c0, c1 = S.JOINTS[side + "Elbow"]
    lower = upper @ T(c0) @ el @ T(c1).inverted()
    _, _, c0, c1 = S.JOINTS[side + "Wrist"]
    return (lower @ T(c0) @ T(c1).inverted()).to_translation(), upper


def solve_arm(ut, side, target, start, elbow_down=None):
    """Arm angles putting `side`'s hand centre on `target` (world), starting from `start` (the last answer, so the arm
    never flips). `elbow_down`: a world direction the elbow should hang toward."""
    def cost(a):
        if not (-5 <= a["elbow"] <= 150):
            return 1e9
        hand, upper = hand_world(ut, side, a)
        c = 20.0 * (hand - target).length + 0.002 * abs(a["twist"]) + 0.001 * abs(a["raise"])
        if elbow_down is not None:
            point = (upper.to_3x3() @ Vector((0, -1, 0))).normalized()
            c += 0.05 * (1 - point.dot(elbow_down))
        return c
    a, best = dict(start), cost(start)
    for step in (8, 4, 2, 1, 0.5, 0.25):
        improved = True
        while improved:
            improved = False
            for k in ("raise", "swing", "twist", "elbow"):
                for d in (step, -step):
                    b = dict(a)
                    b[k] += d
                    c = cost(b)
                    if c < best - 1e-7:
                        a, best, improved = b, c, True
    miss = (hand_world(ut, side, a)[0] - target).length
    return a, miss


# ---------------------------------------------------------------- a setup clip
class Setup:
    """A setup made of `body(t)` -> (root, pose without arms and legs, feet, hand targets, bar):
         feet:    {side: (ankle world, foot rotation world, knee direction world)}
         targets: {side: world point or None (arm hangs)}
         bar:     (world centre, held) or None
    solved in time order every STEP, the last `blend_s` seconds easing into the rep animation's pose."""

    def __init__(self, lift, length, body, blend_s=0.4):
        self.lift, self.length, self.body, self.blend_s = lift, length, body, blend_s
        self.frames, self.bars, self.worst, self.virtual = None, None, 0.0, None

    def _solve(self):
        final = FINAL[self.lift]
        rep = REP_POSE[self.lift](REP_AT[self.lift])
        arms_now = {"Left": dict(HANG), "Right": dict(HANG)}
        self.frames, self.bars, self.virtual = [], [], []
        for i in range(int(round(self.length / STEP)) + 1):
            t = i * STEP
            root, pose, feet, targets, bar = self.body(t)
            pose = dict(pose)
            lt, ut = upper_frames(root, pose)
            for side, (ankle, rot, knee) in feet.items():
                leg_ik(pose, lt, side, ankle, rot, knee)
            for side in ("Left", "Right"):
                target = targets.get(side)
                if target is None:
                    a = HANG
                elif isinstance(target, dict):
                    a = target
                else:
                    a, miss = solve_arm(ut, side, target, arms_now[side],
                                        root.to_3x3() @ Vector((0, -1, 0.3)).normalized())
                    self.worst = max(self.worst, miss)
                arms_now[side] = dict(a)
                sh, el = arm_tf(side, a)
                pose[side + "Shoulder"], pose[side + "Elbow"] = sh, el
            # About the real root part: the virtual root's offset goes into the Root joint.
            moved = C0_ROOT.inverted() @ final.inverted() @ root @ C0_ROOT
            real = dict(pose)
            real["Root"] = moved @ pose.get("Root", I4)
            left = self.length - t
            if left < self.blend_s:
                real = blend_pose(real, rep, smooth(1 - left / self.blend_s))
            self.frames.append(real)
            self.bars.append(bar)
            self.virtual.append(root)

    def pose(self, t):
        if self.frames is None:
            self._solve()
        return self.frames[max(0, min(len(self.frames) - 1, int(round(t / STEP))))]

    def world(self, t):
        """Every part's world matrix (rack-local) at t, as the game shows it."""
        return S.forward_kinematics(FINAL[self.lift], self.pose(t))

    def bar_at(self, t):
        """The bar's centre (rack-local) and whether it is in the hands, as the game draws it."""
        if self.frames is None:
            self._solve()
        bar = self.bars[max(0, min(len(self.bars) - 1, int(round(t / STEP))))]
        if bar is None or not bar[1]:
            return (bar[0] if bar else None), False
        return S.hands_mid(self.world(t)), True


# ---------------------------------------------------------------- squat
SQ = {"grip": 1.55, "toes": S.SQUAT_TOES_OUT}
# The bar on the upper back, in the upper torso's frame (where the rep's hands hold it).
_w0 = S.forward_kinematics(T((0, STAND_Y, 0)), S.squat_pose(0.0))
BACK_BAR = _w0["UpperTorso"].inverted() @ S.hands_mid(_w0)
SQ_STANCE = [_w0[f] @ Vector(S.JOINTS[j][3]) for f, j in (("LeftFoot", "LeftAnkle"), ("RightFoot", "RightAnkle"))]
SQ_UNDER_LEAN = -8.0
SQ_UNRACK, SQ_LENGTH = 3.1, 6.7


def _under_root():
    """Where the root goes so the bar on the back (BACK_BAR) is exactly the bar in the J-cups, leaning SQ_UNDER_LEAN."""
    probe = T((0, 0, 0)) @ FACE
    _, ut = upper_frames(probe, {"Root": rx(SQ_UNDER_LEAN)})
    offset = ut @ BACK_BAR
    return BAR_SQUAT - offset


SQ_UNDER = _under_root()
# The duck under the bar at shoulder-blade height (user 2026-11-08: no crouch to the floor; searched for the least
# overlap of the big block head with the bar, the knees bending a quarter at most): a small dip, the head ducks
# forward and down under the bar as they step under it, then they rise into it. About 0.08 is left, for a moment.
# The root heights were tuned on the block rig (standing 3.0, bar 3.665). On the taller rig the shoulders, the head and
# the J-cups are all 0.70 higher and the head sits 0.30 higher on the root, so the same dips below standing (0.176,
# 0.347, 0.187) duck the head under the bar the same way: DUCK_DIP keeps them as dips (user 2026-11-12).
DUCK_DIP = (3.0 - 2.824, 3.0 - 2.653, 3.0 - 2.813)
SQ_DUCK = {"grip_z": -1.05, "t1": 1.458, "y1": STAND_Y - DUCK_DIP[0], "lean1": 0.0, "neck1": 10.0,
           "t2": 1.759, "y2": STAND_Y - DUCK_DIP[1], "z2": -0.563, "lean2": -22.0, "neck2": -25.5,
           "t3": 2.285, "y3": STAND_Y - DUCK_DIP[2], "lean3": -22.0}
SQ_UNDER_AT = 2.6


def _squat_body(t):
    z_app, z_fin = SQUAT_APPROACH_Z, SQUAT_FINAL_Z
    under = SQ_UNDER
    pos = keyed([(0.3, Vector((0, STAND_Y, z_app))), (1.2, Vector((0, STAND_Y, SQ_DUCK["grip_z"]))),
                 (SQ_DUCK["t1"], Vector((0, SQ_DUCK["y1"], SQ_DUCK["grip_z"] - 0.04))),
                 (SQ_DUCK["t2"], Vector((0, SQ_DUCK["y2"], SQ_DUCK["z2"]))),
                 (SQ_DUCK["t3"], Vector((0, SQ_DUCK["y3"], under.z - 0.04))), (SQ_UNDER_AT, under),
                 (SQ_UNRACK, under), (3.65, Vector((0, STAND_Y, under.z))), (3.95, Vector((0, STAND_Y, under.z))),
                 (4.4, Vector((0, STAND_Y, under.z - 0.5))), (4.9, Vector((0, STAND_Y, z_fin + 0.12))),
                 (5.35, Vector((0, STAND_Y, z_fin)))], t)
    lean = keyed([(1.2, 0.0), (SQ_DUCK["t1"], SQ_DUCK["lean1"]), (SQ_DUCK["t2"], SQ_DUCK["lean2"]),
                  (SQ_DUCK["t3"], SQ_DUCK["lean3"]), (SQ_UNDER_AT, SQ_UNDER_LEAN), (SQ_UNRACK, SQ_UNDER_LEAN),
                  (3.65, 0.0)], t)
    neck = keyed([(0.0, -6.0), (1.2, -4.0), (SQ_DUCK["t1"], SQ_DUCK["neck1"]), (SQ_DUCK["t2"], SQ_DUCK["neck2"]),
                  (SQ_UNDER_AT, 4.0), (2.85, 10.0), (SQ_UNRACK, 4.0), (3.65, 0.0)], t)
    # Swaying onto the standing foot through the walk-out.
    sway = 2.5 * math.sin(math.pi * max(0.0, min(1.0, (t - 3.95) / 0.95))) * (1 if t < 4.9 else 0)
    root = root_at(pos, 180.0) @ rz(sway)
    pose = {"Root": rx(lean), "Neck": rx(neck - lean * 0.55)}

    # Feet: two steps up, a shuffle under the bar into the squat stance, three steps back, set.
    stand = lambda z, x: Vector((x, ANKLE_Y, z))
    # SQ_STANCE was measured facing -Z at the origin: turned to face the rack, the left ankle is at rack +x.
    stance_x = abs(SQ_STANCE[0].x)
    gz = SQ_DUCK["grip_z"]
    left = Steps(stand(z_app, 0.5), 180.0, 0.0, [
        (0.3, 0.72, stand(z_app, 0.5), stand(gz - 0.04, 0.55), 180.0, 180.0),
        (1.95, 2.3, stand(gz - 0.04, 0.55), stand(under.z - 0.02, stance_x), 180.0, 180.0),
        (4.4, 4.85, stand(under.z - 0.02, stance_x), stand(z_fin - 0.02, stance_x), 180.0, 180.0)])
    right = Steps(stand(z_app, -0.5), 180.0, 0.0, [
        (0.7, 1.12, stand(z_app, -0.5), stand(gz + 0.04, -0.55), 180.0, 180.0),
        (2.2, 2.55, stand(gz + 0.04, -0.55), stand(under.z + 0.02, -stance_x), 180.0, 180.0),
        (3.95, 4.4, stand(under.z + 0.02, -stance_x), stand(under.z - 0.6, -stance_x), 180.0, 180.0),
        (4.9, 5.3, stand(under.z - 0.6, -stance_x), stand(z_fin + 0.02, -stance_x), 180.0, 180.0)])
    feet = {}
    for side, steps in (("Left", left), ("Right", right)):
        ankle, yaw, pitch = steps.at(t)
        toes = keyed([(1.95, 0.0), (2.55, SQ["toes"])], t)
        sx = -1 if side == "Left" else 1
        rot = foot_rot(yaw, side, toes, pitch)
        knee = ry(yaw) @ ry(-sx * toes) @ Vector((0, 0, -1))
        feet[side] = (ankle, rot, knee)

    # Hands: up to the bar as they step in, on it through the duck, then on the bar riding the back.
    _, ut = upper_frames(root, pose)
    if t < SQ_UNRACK:
        bar, held = BAR_SQUAT, False
    else:
        bar, held = ut @ BACK_BAR, True
    grip = Vector((SQ["grip"], 0, 0))
    targets = {}
    reach = smooth((t - 0.45) / 0.75)
    for side, sign in (("Left", 1), ("Right", -1)):
        on_bar = bar + grip * sign
        if reach <= 0:
            targets[side] = None
        elif reach < 1:
            hang = hand_world(ut, side, HANG)[0]
            targets[side] = hang.lerp(on_bar, reach)
        else:
            targets[side] = on_bar
    return root, pose, feet, targets, (bar, held)


SQUAT = Setup("Squat", SQ_LENGTH, _squat_body)


# ---------------------------------------------------------------- bench
BE = {"grip": 1.9}
BENCH_UNRACK, BENCH_LENGTH = 5.4, 6.9
_wb = S.forward_kinematics(FINAL["Bench"], S.bench_pose(0.6))
BENCH_LOCK_BAR = S.hands_mid(_wb)
BENCH_ANKLES = {"Left": _wb["LeftFoot"] @ Vector(S.JOINTS["LeftAnkle"][3]),
                "Right": _wb["RightFoot"] @ Vector(S.JOINTS["RightAnkle"][3])}
BENCH_FOOT_ROT = {s: _wb[s + "Foot"].to_3x3().to_4x4() for s in ("Left", "Right")}
BENCH_KNEE = {s: (_wb[s + "LowerLeg"] @ Vector(S.JOINTS[s + "Knee"][3])) for s in ("Left", "Right")}
# The hips: where they sit on the bench's end and stay as the lifter lies back (root part 1.2 above them).
# On the taller rig the head is further from the hips (BENCH_HEAD_UP 1.886, 1.586 on the block rig), so they sit
# SIT_BACK (that 0.30) further toward the bench's end, to lie back with the head passing under the bar as before and
# slide up into place by the same 0.19 (bar into the head 0.13, 0.17 on the block rig). They sit right at the pad's end.
SIT_BACK = S.BENCH_HEAD_UP - 1.586
HIP_SIT = Vector((0, S.BENCH_ROOT_HEIGHT, -3.28 - SIT_BACK))
# Lying down from there leaves the head short of the bar (so it passes under it); then they slide up into place.
LIE_SLIDE = FINAL["Bench"].to_translation().z - (HIP_SIT.z + 1.2)
SIT_FEET_Z = HIP_SIT.z - 0.95 * S.LEG_SCALE      # about a thigh's length in front (longer on the taller rig)


def _lying_root(angle):
    """The root lying back by `angle` degrees about the hips (0 = sitting up, facing away from the rack)."""
    return T(HIP_SIT) @ rx(angle) @ T((0, 1.2, 0))


def _bench_body(t):
    z0 = BENCH_APPROACH_Z
    # Turn round (facing the rack -> facing away), two steps back to the bench's end, sit, lie back.
    yaw = keyed([(0.15, 180.0), (1.15, 0.0)], t)
    stand_z = keyed([(1.15, z0), (2.0, SIT_FEET_Z + 0.08)], t)
    if t < 2.0:
        root = root_at(Vector((0, STAND_Y, stand_z)), yaw)
        pose = {"Neck": rx(keyed([(0.0, -4.0), (1.2, 4.0), (2.0, -6.0)], t))}
    elif t < 2.9:
        # Sitting down: the hips go back and down onto the pad's end, leaning forward, then sit up.
        u = smooth((t - 2.0) / 0.9)
        standing = Vector((0, STAND_Y, SIT_FEET_Z + 0.08))
        sitting = HIP_SIT + Vector((0, 1.2, 0))
        pos = standing.lerp(sitting, u)
        root = root_at(pos, 0.0)
        pose = {"Root": rx(-28.0 * math.sin(math.pi * u)), "Neck": rx(-6.0 + 10 * u)}
    else:
        angle = 90.0 * smooth((t - 2.9) / 1.3)
        # Slide up the bench into place, then an arch through the grip and the unrack, flat again for the rep.
        slide = LIE_SLIDE * smooth((t - 4.1) / 0.4)
        arch = keyed([(4.4, 0.0), (4.9, 9.0), (6.2, 9.0), (6.55, 0.0)], t)
        root = T((0, 0, slide)) @ _lying_root(angle) @ T((0, 0, -0.04 * arch / 6.0))
        pose = {"Root": rx(-arch * 0.4), "Waist": rx(arch),
                "Neck": rx(keyed([(2.9, 4.0), (3.3, 30.0), (3.95, 30.0), (4.4, -6.0), (5.0, 0.0)], t))}

    # Feet: turning steps round the root, two steps back, planted in front of the bench as they sit, out to the
    # bench stance lying.
    def spot(side, heading):
        sx = -1 if side == "Left" else 1
        left_dir = ry(heading).to_3x3() @ Vector((-1, 0, 0))
        return Vector((0, ANKLE_Y, z0)) - left_dir * (0.5 * sx)
    left = Steps(spot("Left", 180.0), 180.0, 0.0, [
        (0.15, 0.5, spot("Left", 180.0), spot("Left", 110.0), 180.0, 110.0),
        (0.8, 1.15, spot("Left", 110.0), spot("Left", 0.0), 110.0, 0.0),
        (1.5, 1.95, spot("Left", 0.0), Vector((-0.55, ANKLE_Y, SIT_FEET_Z)), 0.0, 0.0)])
    right = Steps(spot("Right", 180.0), 180.0, 0.0, [
        (0.45, 0.85, spot("Right", 180.0), spot("Right", 40.0), 180.0, 40.0),
        (1.15, 1.55, spot("Right", 40.0), Vector((0.55, ANKLE_Y, SIT_FEET_Z)), 40.0, 0.0)])
    feet = {}
    for side, steps in (("Left", left), ("Right", right)):
        ankle, yaw_f, pitch = steps.at(t)
        rot = foot_rot(yaw_f, side, 0.0, pitch)
        knee = ry(yaw_f) @ Vector((0, 0.35, -1)).normalized()
        if t > 2.9:
            u = smooth((t - 2.9) / 1.5)
            ankle = ankle.lerp(BENCH_ANKLES[side], u) + Vector((0, 0.25 * math.sin(math.pi * u), 0))
            q = rot.to_quaternion().slerp(BENCH_FOOT_ROT[side].to_quaternion(), u)
            rot = q.to_matrix().to_4x4()
            sx = -1 if side == "Left" else 1
            hip_now = Vector((sx * 0.55, HIP_SIT.y, HIP_SIT.z + LIE_SLIDE))
            knee = knee.lerp((BENCH_KNEE[side] - (hip_now + BENCH_ANKLES[side]) / 2).normalized(), u)
        feet[side] = (ankle, rot, knee)

    # Hands: hanging, onto the thighs as they sit, beside the hips lying back, up to the bar, then the unrack.
    _, ut = upper_frames(root, pose)
    lt, _ = upper_frames(root, pose)
    if t < BENCH_UNRACK:
        bar, held = BAR_BENCH, False
    else:
        u = smooth((t - BENCH_UNRACK) / 0.9)
        top = Vector((0, max(BAR_BENCH.y, BENCH_LOCK_BAR.y) + 0.18, BAR_BENCH.z))
        bar = (BAR_BENCH * (1 - u) ** 2 + top * 2 * u * (1 - u) + BENCH_LOCK_BAR * u * u)
        held = True
    left_dir = FINAL["Bench"].to_3x3() @ Vector((-1, 0, 0))
    targets = {}
    for side, sign in (("Left", 1), ("Right", -1)):
        hang = hand_world(ut, side, HANG)[0]
        sx = -1 if side == "Left" else 1
        thigh = lt @ Vector(S.JOINTS[side + "Hip"][2])
        knee_pt = thigh + (feet[side][0] - thigh) * 0.25
        on_thigh = knee_pt + Vector((0, 0.62, 0)) + left_dir * (0.2 * sign)
        beside = hang
        on_bar = bar + left_dir * (BE["grip"] * sign)
        if t < 1.9:
            targets[side] = None
        elif t < 2.6:
            targets[side] = hang.lerp(on_thigh, smooth((t - 1.9) / 0.7))
        elif t < 3.3:
            targets[side] = on_thigh
        elif t < 3.9:
            targets[side] = on_thigh.lerp(beside, smooth((t - 3.3) / 0.6))
        elif t < 4.3:
            targets[side] = dict(HANG)
        elif t < 4.95:
            targets[side] = beside.lerp(on_bar, smooth((t - 4.3) / 0.65))
        else:
            targets[side] = on_bar
    return root, pose, feet, targets, (bar, held)


BENCH = Setup("Bench", BENCH_LENGTH, _bench_body, blend_s=0.35)


# ---------------------------------------------------------------- deadlift
DL_BOTTOM = S._solve_deadlift_bottom()[0]
DL_LENGTH = 3.3


def _deadlift_body(t):
    final = FINAL["Deadlift"]
    # Set the feet (toes turn out), stand tall and breathe, hinge down to the bar, set.
    u = smooth((t - 1.4) / 1.0)
    torso, thigh, shin = (lerp(0.0, DL_BOTTOM[i], u) for i in range(3))
    tall = 4.0 * math.sin(math.pi * max(0.0, min(1.0, (t - 0.95) / 0.6)))
    body = S._deadlift_body(torso + tall, thigh, shin)
    pose = {k: v for k, v in body.items() if k in ("Root", "Neck", "Waist")}
    pose["Neck"] = pose.get("Neck", I4) @ rx(keyed([(0.0, -10.0), (0.9, -14.0), (1.2, 8.0), (1.6, 0.0)], t))
    root = final
    feet = {}
    for side in ("Left", "Right"):
        sx = -1 if side == "Left" else 1
        w = S.forward_kinematics(root, body)
        ankle = w[side + "Foot"] @ Vector(S.JOINTS[side + "Ankle"][3])
        toes_now = keyed([(0.2 if side == "Left" else 0.55, 0.0), (0.5 if side == "Left" else 0.85, S.DEADLIFT_TOES_OUT)], t)
        step_u = (t - (0.2 if side == "Left" else 0.55)) / 0.3
        pitch = 5.0 * math.sin(math.pi * step_u) if 0 < step_u < 1 else 0.0
        lift = 0.12 * math.sin(math.pi * step_u) if 0 < step_u < 1 else 0.0
        rot = foot_rot(180.0, side, toes_now, pitch)
        knee = ry(180.0) @ ry(-sx * S.DEADLIFT_TOES_OUT) @ Vector((0, 0, -1))
        feet[side] = (ankle + Vector((0, lift, 0)), rot, knee)
    _, ut = upper_frames(root, pose)
    targets = {}
    hanging = {"raise": 0.0, "swing": -(torso + tall), "twist": 0.0, "elbow": 0.0}
    for side, sign, at in (("Right", -1, 2.45), ("Left", 1, 2.65)):
        grip = DL_BAR + Vector((1.5 * sign, 0, 0))
        hang = hand_world(ut, side, hanging)[0]
        v = smooth((t - (at - 0.45)) / 0.45)
        targets[side] = dict(hanging) if v <= 0 else hang.lerp(grip, v)
    return root, pose, feet, targets, (DL_BAR, False)


DEADLIFT = Setup("Deadlift", DL_LENGTH, _deadlift_body, blend_s=0.5)

SETUPS = {"Squat": SQUAT, "Bench": BENCH, "Deadlift": DEADLIFT}
# When the bar leaves its rest and is in the hands (the server tells every client then: MeetBarHeld).
BAR_HELD_AT = {"Squat": SQ_UNRACK, "Bench": BENCH_UNRACK, "Deadlift": DL_LENGTH}


# ---------------------------------------------------------------- checks
def _bar_inside(world, part, bar):
    """How deep the bar's line (along x, at `bar`'s height and z) goes into `part`'s box, or 0."""
    sx, sy, sz = S.SIZES[part]
    inv = world[part].inverted()
    deepest = 0.0
    for i in range(41):
        p = inv @ Vector((-2.0 + i * 0.1, bar.y, bar.z))
        depth = min(sx / 2 + 0.07 - abs(p.x), sy / 2 + 0.07 - abs(p.y), sz / 2 + 0.07 - abs(p.z))
        deepest = max(deepest, depth)
    return deepest


def checks():
    lines = []
    for name, setup in SETUPS.items():
        lowest, bar_in, bar_jump, prev, bar_in_at = 9.0, 0.0, 0.0, None, "-"
        t = 0.0
        while t <= setup.length + 1e-6:
            w = setup.world(t)
            for part in ("LeftFoot", "RightFoot", "LeftHand", "RightHand", "LowerTorso"):
                sx, sy, sz = S.SIZES[part]
                ys = [(w[part] @ Vector((x * sx / 2, y * sy / 2, z * sz / 2))).y
                      for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
                lowest = min(lowest, min(ys))
            bar, held = setup.bar_at(t)
            if bar is not None and not held:
                for part in ("Head", "UpperTorso", "LowerTorso"):
                    depth = _bar_inside(w, part, bar)
                    if depth > bar_in:
                        bar_in, bar_in_at = depth, "%s at %.2f" % (part, t)
            if prev is not None and bar is not None and prev is not None:
                bar_jump = max(bar_jump, (bar - prev).length)
            prev = bar
            t += 0.05
        rep = S.forward_kinematics(FINAL[name], REP_POSE[name](REP_AT[name]))
        end = setup.world(setup.length)
        seam = max((rep[p].to_translation() - end[p].to_translation()).length for p in rep)
        lines.append(f"Setup_{name}: {setup.length} s, worst hand miss {setup.worst:.3f}, lowest {lowest:.2f}, "
                     f"bar into the body {bar_in:.2f} ({bar_in_at}), biggest bar move in 0.05 s {bar_jump:.2f}, "
                     f"seam with the rep {seam:.3f}, bar held from {BAR_HELD_AT[name]} s")
    return lines


# ---------------------------------------------------------------- previews (each setup at its rack, with the bar)
def previews(folder):
    import bpy
    os.makedirs(folder, exist_ok=True)
    for name, setup in SETUPS.items():
        bpy.ops.wm.read_homefile(use_empty=True)
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "MATERIAL"
        world = bpy.data.worlds.new("World")
        world.color = (0.75, 0.77, 0.8)
        scene.world = world
        # The rack as collection instances (as station_animations.preview_all shows it): the J-cups on their own, at
        # the bench hole for the bench; the bench only at the bench; no rack for the deadlift (the meet takes it away).
        with bpy.data.libraries.load(os.path.join(S.ROOT_DIR, "art", "blender", "ComboRack_01.blend"), link=True) as (src, dst):
            dst.objects = list(src.objects)
        groups = {"Frame": bpy.data.collections.new("Rack_Frame"), "JCups": bpy.data.collections.new("Rack_JCups"),
                  "Bench": bpy.data.collections.new("Rack_Bench")}
        for o in dst.objects:
            if o is None:
                continue
            key = "Bench" if o.name.startswith("Bench_") else "JCups" if o.name.startswith("JCup") else "Frame"
            groups[key].objects.link(o)
        shown = [] if name == "Deadlift" else ["Frame", "JCups"] + (["Bench"] if name == "Bench" else [])
        for key in shown:
            inst = bpy.data.objects.new("Rack_" + key, None)
            inst.instance_type = "COLLECTION"
            inst.instance_collection = groups[key]
            if key == "JCups" and name == "Bench":
                inst.matrix_world = Matrix.Translation((0, 0, -0.35 + (BAR_BENCH.y - 3.14)))
            elif key == "JCups":
                # (the taller lifters' squat cups sit higher than in the .blend, as the game moves them)
                inst.matrix_world = Matrix.Translation((0, 0, BAR_SQUAT.y - 3.665))
            scene.collection.objects.link(inst)
        with bpy.data.libraries.load(os.path.join(S.ROOT_DIR, "art", "blender", "Barbell_01.blend"), link=True) as (src, dst):
            dst.objects = list(src.objects)
        kit = {o.name: o for o in dst.objects if o is not None}
        bar = bpy.data.objects.new("Bar", None)
        scene.collection.objects.link(bar)
        for piece_name in ("Bar_Shaft", "Bar_Sleeves"):
            c = bpy.data.objects.new(piece_name, kit[piece_name].data)
            c.parent = bar
            scene.collection.objects.link(c)
        for side in ((1, -1) if os.environ.get("SETUP_VIEW") != "side" else ()):
            x = 3.31
            for n in S.DISPLAY_LOAD:
                w = kit[n].dimensions.x
                c = bpy.data.objects.new(n, kit[n].data)
                m = Matrix.Translation((side * (x + w / 2), 0, kit[n].location.z))
                if side < 0:
                    m = m @ Matrix.Scale(-1, 4, (1, 0, 0))
                c.parent = bar
                c.matrix_basis = m
                scene.collection.objects.link(c)
                x += w
        objs = E._figure(bpy, name, E.COLOURS[1])
        frames = int(setup.length * 30)
        for f in range(0, frames + 1):
            t = f / 30
            w = setup.world(t)
            for part, o in objs.items():
                o.matrix_world = S.TO_BLENDER @ w[part]
                o.keyframe_insert("location", frame=f + 1)
                o.keyframe_insert("rotation_quaternion", frame=f + 1)
            centre, _ = setup.bar_at(t)
            bar.matrix_world = S.TO_BLENDER @ T(centre) @ S.TO_BLENDER.inverted()
            bar.keyframe_insert("location", frame=f + 1)
            bar.keyframe_insert("rotation_euler", frame=f + 1)
        # From the lifter's right, a little behind: Blender (x, y, z) = rack-local (-x, z, y).
        centre_z, offset, width = {"Squat": (-0.8, (15.0, -5.0, 4.0), 10.0), "Bench": (-2.4, (15.0, -4.0, 6.0), 12.0),
                                   "Deadlift": (-4.4, (13.0, -7.0, 4.0), 12.0)}[name]
        target = Vector((0.0, centre_z, 2.2 + 2 * (STAND_Y - 3.0) if name != "Bench" else 1.8))
        if os.environ.get("SETUP_VIEW") == "side":
            # Straight from the lifter's right (for checking where the body goes past the bar).
            offset = (18.0, 0.0, 0.6)
        E._camera(bpy, scene, target + Vector(offset), target, width)
        scene.frame_start, scene.frame_end = 1, frames
        scene.render.resolution_x, scene.render.resolution_y = 720, 480
        if E._video_settings(scene, os.path.join(folder, f"Setup_{name}_frames")):
            bpy.ops.render.render(animation=True)


if __name__ == "__main__":
    for line in checks():
        print("CHECK", line)
    for name, setup in SETUPS.items():
        print("EXPORTED", E.export(f"Setup_{name}", setup.length, setup.pose, False, 2, 0.05))
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argv:
        previews(argv[0])
    print("DONE")
