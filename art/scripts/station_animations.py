# Station rep animations (GAME_DESIGN.md §34.12 decision 15: slow repeating reps).
#
# One source for each animation: joint rotations over time, defined below in
# Roblox's own R15 coordinates. This script
#   - builds a preview R15 rig in Blender (the exact Roblox block rig measured
#     from art/animations/R15_BlockRig.rbxmx) and keyframes it, with the station
#     rack and a loaded bar for context;
#   - writes each animation as a Roblox KeyframeSequence (.rbxmx) to
#     art/animations/, ready for Studio: Insert from File -> right-click ->
#     Save to Roblox (publishes it as an Animation asset).
#
# Roblox space: +Y up, the character faces -Z, its Left side is -X. A joint
# moves its child part as  child = parent * C0 * Transform * C1:Inverse(),
# where C0/C1 are the joint's rig attachments (positions only on this rig) and
# Transform is what an animation Pose sets. Rotations here are about X (bend
# forward/back) and Z (raise sideways); see the angle notes per animation.
#
# Blender preview space: Blender = (-X, Z, Y) of Roblox (the project's FBX
# mapping, so the rack's open front is -Y in Blender and -Z in Roblox).
#
# Run inside Blender (bpy + mathutils). preview("Squat") / export("Squat").
import math, os
from mathutils import Matrix, Vector

ROOT_DIR = r"D:\Powerlifting Roblox"
OUT_DIR = os.path.join(ROOT_DIR, "art", "animations")
FPS = 30
SAMPLE_STEP = 0.1          # seconds between written keyframes

# ---------------------------------------------------------------- R15 block rig (measured)
# Part sizes (studs) from R15_BlockRig.rbxmx (Rig Builder, R15 Block, 2026-10-19).
SIZES = {
    "HumanoidRootPart": (2, 2, 1), "LowerTorso": (2, 0.4, 1), "UpperTorso": (2, 1.6, 1),
    "Head": (1.196, 1.203, 1.198),
    "LeftUpperArm": (1, 1.169, 1), "LeftLowerArm": (1, 1.052, 1), "LeftHand": (1, 0.3, 1),
    "RightUpperArm": (1, 1.169, 1), "RightLowerArm": (1, 1.052, 1), "RightHand": (1, 0.3, 1),
    "LeftUpperLeg": (1, 1.217, 1), "LeftLowerLeg": (1, 1.193, 1), "LeftFoot": (1, 0.3, 1),
    "RightUpperLeg": (1, 1.217, 1), "RightLowerLeg": (1, 1.193, 1), "RightFoot": (1, 0.3, 1),
}
# joint: (parent, child, attachment position in parent (C0), in child (C1))
JOINTS = {
    "Root": ("HumanoidRootPart", "LowerTorso", (0, -1, 0), (0, -0.2, 0)),
    "Waist": ("LowerTorso", "UpperTorso", (0, 0.2, 0), (0, -0.8, 0)),
    "Neck": ("UpperTorso", "Head", (0, 0.8, 0), (0, -0.586, 0)),
    "LeftShoulder": ("UpperTorso", "LeftUpperArm", (-1, 0.563, 0), (0.5, 0.3943, 0)),
    "LeftElbow": ("LeftUpperArm", "LeftLowerArm", (0, -0.3341, 0), (0, 0.2587, 0)),
    "LeftWrist": ("LeftLowerArm", "LeftHand", (0, -0.5009, 0), (0, 0.125, 0)),
    "RightShoulder": ("UpperTorso", "RightUpperArm", (1, 0.563, 0), (-0.5, 0.3943, 0)),
    "RightElbow": ("RightUpperArm", "RightLowerArm", (0, -0.3342, 0), (0, 0.2586, 0)),
    "RightWrist": ("RightLowerArm", "RightHand", (0, -0.5009, 0), (0, 0.125, 0)),
    "LeftHip": ("LowerTorso", "LeftUpperLeg", (-0.5, -0.2, 0), (0, 0.4208, 0)),
    "LeftKnee": ("LeftUpperLeg", "LeftLowerLeg", (0, -0.4011, 0), (0, 0.379, 0)),
    "LeftAnkle": ("LeftLowerLeg", "LeftFoot", (0, -0.5472, 0), (0, 0.1019, 0)),
    "RightHip": ("LowerTorso", "RightUpperLeg", (0.5, -0.2, 0), (0, 0.4208, 0)),
    "RightKnee": ("RightUpperLeg", "RightLowerLeg", (0, -0.4009, 0), (0, 0.3792, 0)),
    "RightAnkle": ("RightLowerLeg", "RightFoot", (0, -0.5472, 0), (0, 0.1019, 0)),
}
CHILD_JOINT = {child: name for name, (parent, child, c0, c1) in JOINTS.items()}
ORDER = ["LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand",
         "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
         "RightUpperLeg", "RightLowerLeg", "RightFoot"]
HRP_STAND_Y = 3.0          # HipHeight 2 + half the root part

def rx(deg):
    return Matrix.Rotation(math.radians(deg), 4, "X")

def rz(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Z")

def T(v):
    return Matrix.Translation(Vector(v))

def forward_kinematics(hrp, transforms):
    """World matrix of every part (Roblox space) for a root matrix and {joint: Transform}."""
    world = {"HumanoidRootPart": hrp}
    for part in ORDER:
        joint = CHILD_JOINT[part]
        parent, child, c0, c1 = JOINTS[joint]
        world[part] = world[parent] @ T(c0) @ transforms.get(joint, Matrix.Identity(4)) @ T(c1).inverted()
    return world

def ankle_points(world):
    return [world[f] @ Vector(JOINTS[j][3]) for f, j in (("LeftFoot", "LeftAnkle"), ("RightFoot", "RightAnkle"))]

STAND_ANKLES = ankle_points(forward_kinematics(T((0, HRP_STAND_Y, 0)), {}))

def plant_feet(transforms):
    """Adds the Root translation that keeps both ankles where they are when standing."""
    world = forward_kinematics(T((0, HRP_STAND_Y, 0)), transforms)
    now = ankle_points(world)
    shift = sum(((a - b) for a, b in zip(STAND_ANKLES, now)), Vector((0, 0, 0))) / 2
    out = dict(transforms)
    out["Root"] = T(shift) @ transforms.get("Root", Matrix.Identity(4))
    return out

def ry(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Y")

def arms(a):
    """Both arms, mirrored. raise: upper arm out sideways; swing: forward (+) / back (-);
    twist: about the upper arm; elbow: hinge, forearm folds forward/up (+)."""
    return {
        "LeftShoulder": rz(-a["raise"]) @ rx(a["swing"]) @ ry(a["twist"]),
        "RightShoulder": rz(a["raise"]) @ rx(a["swing"]) @ ry(-a["twist"]),
        "LeftElbow": rx(a["elbow"]), "RightElbow": rx(a["elbow"]),
    }

def smooth(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)

def blend(a, b, u):
    return a + (b - a) * u

# ---------------------------------------------------------------- animations
# Each animation: length (s), and pose(t) -> {joint: Transform}.

SQUAT_LENGTH = 6.0
# Phases (s): stand, descend, pause at the bottom, stand up, rest.
SQUAT_PHASES = (0.6, 1.9, 2.1, 3.1)
# Absolute segment angles about X, standing -> bottom (degrees).
# Torso: negative = leans forward. Thigh: positive = knee forward/up (90 = parallel).
# Shin: negative = knee travels forward over the toes. The foot stays flat.
# User review 2026-10-19: torso more upright (was -42), wider stance, toes out.
SQUAT_TORSO = (0.0, -30.0)
SQUAT_THIGH = (0.0, 98.0)
SQUAT_SHIN = (0.0, -36.0)
# Stance: each leg out sideways (degrees, ankles ~0.85 studs from the centre
# instead of 0.5) and turned out; knees bend the way the toes point.
SQUAT_STANCE_OUT, SQUAT_TOES_OUT = 11.0, 25.0
# Arms hold the bar on the upper back the whole time (relative to the torso).
# Solved in Blender (2026-10-19) so the hands sit on the bar at x = +-1.55 with
# the elbows below and behind it: shoulder raise / swing / twist and a hinge
# elbow (see arm()).
SQUAT_ARM = {"raise": 8.0, "swing": 0.0, "twist": 98.0, "elbow": 136.0}

def squat_depth(t):
    a, b, c, d = SQUAT_PHASES
    if t < a or t >= d:
        return 0.0
    if t < b:
        return smooth((t - a) / (b - a))
    if t < c:
        return 1.0
    return 1.0 - smooth((t - c) / (d - c))

def legs(torso, thigh, shin, stance_out, toes_out, lying=False, leg_twist=None):
    """Both legs from absolute angles (see SQUAT_*), mirrored, feet flat and turned out.
    The leg is first set out sideways and turned (leg_twist, default toes_out), then
    bends in that turned plane.
    lying: the body lies face up (root frame turned by rx(90)), so 'flat on the floor'
    means the sole faces the root's +Z and the toes point down the body."""
    root = rx(torso)
    twist = toes_out if leg_twist is None else leg_twist
    pose = {}
    for side, sx in (("Left", -1), ("Right", 1)):
        turned = rz(sx * stance_out) @ ry(-sx * twist)
        thigh_world = turned @ rx(thigh)
        knee = rx(shin - thigh)
        foot_world = rz(sx * toes_out) @ rx(-90) if lying else ry(-sx * toes_out)
        pose[side + "Hip"] = root.inverted() @ thigh_world
        pose[side + "Knee"] = knee
        pose[side + "Ankle"] = (thigh_world @ knee).inverted() @ foot_world
    return pose

# ---------------------------------------------------------------- reaching the bar
ARM_KEYS = ("raise", "swing", "twist", "elbow")

def joint_point(world, joint):
    """World position of a joint (its attachment on the child part)."""
    parent, child, c0, c1 = JOINTS[joint]
    return world[child] @ Vector(c1)

def hands_mid(world):
    return (world["LeftHand"].to_translation() + world["RightHand"].to_translation()) / 2

def solve_arms(body_pose, target_left, start, extra=None, hand_weight=1.0,
               steps=(16, 8, 4, 2, 1, 0.5, 0.25)):
    """Arm angles (mirrored) that put the LEFT hand's centre on target_left, in the
    root part's frame. extra(world, angles) adds a preference cost; hand_weight sets
    how much more the hand-on-target term counts. Coordinate descent; small steps
    only refine near the start."""
    def cost(a):
        if not (-5 <= a["elbow"] <= 150):
            return 1e9
        p = dict(body_pose)
        p.update(arms(a))
        w = forward_kinematics(Matrix.Identity(4), p)
        c = hand_weight * (w["LeftHand"].to_translation() - target_left).length
        return c + (extra(w, a) if extra else 0.0)
    a, best = dict(start), cost(start)
    for step in steps:
        improved = True
        while improved:
            improved = False
            for k in ARM_KEYS:
                for d in (step, -step):
                    b = dict(a)
                    b[k] += d
                    c = cost(b)
                    if c < best - 1e-7:
                        a, best, improved = b, c, True
    return a, best

def lerp_angles(table, u):
    """Angles from a table solved at u = 0, 1/n, ... 1 (linear in between)."""
    n = len(table) - 1
    i = min(int(u * n), n - 1)
    f = u * n - i
    return {k: blend(table[i][k], table[i + 1][k], f) for k in table[i]}

def _left_ankle_x(pose):
    w = forward_kinematics(T((0, HRP_STAND_Y, 0)), pose)
    return (w["LeftFoot"] @ Vector(JOINTS["LeftAnkle"][3])).x

def squat_pose(t):
    u = squat_depth(t)
    torso = blend(*SQUAT_TORSO, u)
    thigh, shin = blend(*SQUAT_THIGH, u), blend(*SQUAT_SHIN, u)

    def build(stance_out):
        pose = {"Root": rx(torso), "Neck": rx(-torso * 0.55)}   # neck: eyes roughly level
        pose.update(legs(torso, thigh, shin, stance_out, SQUAT_TOES_OUT))
        pose.update(arms(SQUAT_ARM))
        return pose

    # Keep the feet planted: as the turned-out knees bend, open the legs a little
    # more so each ankle stays exactly as wide as when standing (bisection).
    want = _left_ankle_x(build(SQUAT_STANCE_OUT) if u == 0 else squat_pose(0.0))
    lo, hi = 0.0, 45.0
    for _ in range(30):
        mid = (lo + hi) / 2
        if _left_ankle_x(build(mid)) > want:     # not wide enough yet (left ankle is at -x)
            lo = mid
        else:
            hi = mid
    return plant_feet(build((lo + hi) / 2))

# ---- Bench press. The game lays the lifter face up on the pad (StationPoses):
# root part at pad top + 0.5, turned by rx(90), so in the ROOT'S frame "up to the
# ceiling" is -Z and "down to the floor" is +Z; the head is +Y.
BENCH_LENGTH = 6.0
# Phases (s): hold at lockout, lower, pause on the chest, press, hold.
BENCH_PHASES = (0.6, 2.0, 2.2, 3.0)
BENCH_ROOT_HEIGHT = 1.7            # pad top 1.2 + half the root part's depth
# Left hand centre in the root's frame (the right hand mirrors). Wide competition
# grip, hands well outside the shoulders (user review 2026-10-19: was 1.5).
BENCH_LOCKOUT = Vector((-1.9, 0.75, -1.52))    # over the shoulders, arms straight
# Where the left elbow sits at lockout: shoulder level, turned out (the touch and
# lockout must be on the same arm "branch" or the arm would flip mid-rep).
BENCH_ELBOW_AT_LOCKOUT = Vector((-1.6, 0.74, -0.66))
BENCH_CHEST = Vector((-1.9, 0.3, -0.6))        # touching mid-chest
# Where the left elbow goes at the touch: flared out, about level with the chest
# and the torso's mid-plane (not hanging toward the floor), so it does not look
# like the bar was dropped (user review 2026-10-19).
BENCH_ELBOW_AT_CHEST = Vector((-1.86, 0.74, 0.02))
# Legs: feet planted wide on the floor, knees out; shins tilt slightly down the body.
BENCH_STANCE_OUT, BENCH_TOES_OUT, BENCH_LEG_TWIST, BENCH_SHIN = 38.0, 20.0, 0.0, -80.0
BENCH_ANKLE_Z = BENCH_ROOT_HEIGHT - 0.252      # ankle 0.252 above the floor

def _bench_legs_at(thigh):
    return legs(0, thigh, BENCH_SHIN, BENCH_STANCE_OUT, BENCH_TOES_OUT, True, BENCH_LEG_TWIST)

def _bench_legs():
    """Thigh angle that puts the ankles on the floor (bisection), legs fixed for the rep."""
    lo, hi = -90.0, 0.0
    for _ in range(40):
        mid = (lo + hi) / 2
        w = forward_kinematics(Matrix.Identity(4), _bench_legs_at(mid))
        if joint_point(w, "LeftAnkle").z < BENCH_ANKLE_Z:   # not low enough yet
            hi = mid
        else:
            lo = mid
    return _bench_legs_at((lo + hi) / 2)

ELBOW_POINT = Vector((-1, 0, 1)).normalized()   # left elbow points out and down (to the floor)

def _bench_preference(w, a):
    # Elbows below the bar (toward the floor, +Z), flared out past the shoulders
    # (not through the chest), forearms close to vertical, and the point of the
    # elbow turned OUT and DOWN, never in (user review 2026-10-19). The elbow's
    # point is the upper arm's +Z side: the hinge folds the forearm toward -Z.
    elbow = joint_point(w, "LeftElbow")
    wrist = joint_point(w, "LeftWrist")
    hand = w["LeftHand"].to_translation()
    forearm = (wrist - elbow).normalized()
    point = (w["LeftUpperArm"].to_3x3() @ Vector((0, 0, 1))).normalized()
    return (max(0.0, hand.z + 0.3 - elbow.z)
            + max(0.0, elbow.x + 1.35)                 # left elbow at x <= -1.35
            + 0.15 * (1 - abs(forearm.z))
            + 0.4 * (1 - point.dot(ELBOW_POINT)))

HAND_WEIGHT = 5.0                  # the hands must stay on the bar

def _bench_table(steps=20):
    """Arm angles from lockout (u=0) to the chest (u=1). The flared touch is solved
    first (multi-start, hands on the bar); then the rep is walked UP to lockout one
    small step at a time, the hand following the bar path and the elbow guided along
    a straight line to its lockout spot, with straight arms preferred near the top.
    Walking from the touch keeps the whole rep on one arm branch: no mid-rep flip."""
    body = _bench_legs()

    def flare(w):
        return (joint_point(w, "LeftElbow") - BENCH_ELBOW_AT_CHEST).length

    touch = None
    for start in ({"raise": r, "swing": s, "twist": tw, "elbow": 98.0}
                  for r in (40, 60, 80) for s in (-30, -15, 0) for tw in (-60, -40, -20, 0)):
        a, cost = solve_arms(body, BENCH_CHEST, start,
                             lambda w, angles: _bench_preference(w, angles) + 0.6 * flare(w), HAND_WEIGHT)
        if touch is None or cost < touch[1]:
            touch = (a, cost)
    touch = touch[0]

    def elbow_of(angles):
        p = dict(body)
        p.update(arms(angles))
        return joint_point(forward_kinematics(Matrix.Identity(4), p), "LeftElbow")

    elbow_touch = elbow_of(touch)
    table = [touch]
    for i in range(steps - 1, -1, -1):
        u = smooth(i / steps)
        elbow_target = BENCH_ELBOW_AT_LOCKOUT.lerp(elbow_touch, u)

        def follow(w, angles, elbow_target=elbow_target, u=u):
            return ((joint_point(w, "LeftElbow") - elbow_target).length
                    + (1 - u) ** 2 * 0.006 * max(0.0, angles["elbow"]))

        a, _ = solve_arms(body, BENCH_LOCKOUT.lerp(BENCH_CHEST, u), table[-1], follow, 20.0,
                          steps=(8, 4, 2, 1, 0.5, 0.25))
        table.append(a)
    table.reverse()
    return body, table

_BENCH = None

def bench_pose(t):
    global _BENCH
    if _BENCH is None:
        _BENCH = _bench_table()
    body, table = _BENCH
    a, b, c, d = BENCH_PHASES
    u = 0.0 if t < a or t >= d else (t - a) / (b - a) if t < b else 1.0 if t < c else 1.0 - (t - c) / (d - c)
    pose = dict(body)
    pose.update(arms(lerp_angles(table, max(0.0, min(1.0, u)))))
    return pose

# ---- Deadlift. The lifter stands behind the floor bar facing it (StationPoses):
# root at standing height, the bar's centre 0.6 in front (-Z) and 2.0 down.
DEADLIFT_LENGTH = 6.0
# Phases (s): stand, hinge down to the bar, set, pull, hold at lockout,
# lower, let go, stand up, rest. The bar is in the hands from grip to release.
DEADLIFT_PHASES = (0.5, 1.5, 1.8, 2.9, 3.3, 4.2, 4.4, 5.2)
DEADLIFT_BAR_HELD = (1.6, 4.3)
DEADLIFT_BAR = Vector((-1.5, -2.0, -0.6))      # left hand centre on the floor bar
DEADLIFT_TOES_OUT = 10.0

def _deadlift_body(torso, thigh, shin, swing=None):
    """swing: arms' forward angle relative to the torso; default hangs them straight down."""
    pose = {"Root": rx(torso), "Neck": rx(-torso * 0.45)}
    pose.update(legs(torso, thigh, shin, 0.0, DEADLIFT_TOES_OUT))
    pose.update(arms({"raise": 0.0, "swing": -torso if swing is None else swing, "twist": 0.0, "elbow": 0.0}))
    return plant_feet(pose)

def _deadlift_on_bar_path(torso, thigh, shin):
    """While the bar is held: straight arms swung just enough to keep the hands (the
    bar) on a vertical path DEADLIFT_BAR.z in front of the feet, so the bar slides up
    the front of the shins and thighs instead of passing through them (bisection)."""
    lo, hi = -torso - 5.0, -torso + 80.0          # more swing = hands further forward (-z)
    for _ in range(40):
        mid = (lo + hi) / 2
        w = forward_kinematics(Matrix.Identity(4), _deadlift_body(torso, thigh, shin, mid))
        if w["LeftHand"].to_translation().z > DEADLIFT_BAR.z:
            lo = mid
        else:
            hi = mid
    return _deadlift_body(torso, thigh, shin, (lo + hi) / 2)

def _solve_deadlift_bottom():
    """Hip hinge that puts the straight-armed hands on the floor bar, hips above the knees."""
    def cost(v):
        torso, thigh, shin = v
        w = forward_kinematics(Matrix.Identity(4), _deadlift_body(torso, thigh, shin))
        c = (w["LeftHand"].to_translation() - DEADLIFT_BAR).length
        hip, knee = joint_point(w, "LeftHip"), joint_point(w, "LeftKnee")
        c += max(0.0, knee.y + 0.25 - hip.y)            # hips clearly above the knees
        c += 0.01 * abs(torso + 50)                      # prefer a ~50 degree back angle
        return c
    v, best = [-50.0, 60.0, -15.0], None
    best = cost(v)
    for step in (8, 4, 2, 1, 0.5, 0.25):
        improved = True
        while improved:
            improved = False
            for i in range(3):
                for d in (step, -step):
                    w = list(v)
                    w[i] += d
                    c = cost(w)
                    if c < best - 1e-7:
                        v, best, improved = w, c, True
    return v, best

_DEADLIFT = None

def deadlift_depth(t):
    s, down, sett, pull, hold, lower, release, up = DEADLIFT_PHASES
    if t < s or t >= up:
        return 0.0
    if t < down:
        return smooth((t - s) / (down - s))
    if t < sett:
        return 1.0
    if t < pull:
        return 1.0 - smooth((t - sett) / (pull - sett))
    if t < hold:
        return 0.0
    if t < lower:
        return smooth((t - hold) / (lower - hold))
    if t < release:
        return 1.0
    return 1.0 - smooth((t - release) / (up - release))

# Lockout with the bar: knees STRAIGHT (thigh = shin, the whole leg tilted 3 degrees
# so the hips sit just in front of the feet) and the shoulders leaning back
# (user reviews 2026-10-19). Torso + = leans back.
DEADLIFT_LOCKOUT = (12.0, -3.0, -3.0)

def deadlift_pose(t):
    global _DEADLIFT
    if _DEADLIFT is None:
        _DEADLIFT = _solve_deadlift_bottom()[0]
    u = deadlift_depth(t)
    # The top of the movement is the leaned-back lockout while the bar is held,
    # and a relaxed neutral stand before the grip and after letting go.
    held = deadlift_bar_held(t)
    top = DEADLIFT_LOCKOUT if held else (0.0, 0.0, 0.0)
    torso, thigh, shin = (blend(top[i], _DEADLIFT[i], u) for i in range(3))
    return _deadlift_on_bar_path(torso, thigh, shin) if held else _deadlift_body(torso, thigh, shin)

def deadlift_bar_held(t):
    return DEADLIFT_BAR_HELD[0] <= t < DEADLIFT_BAR_HELD[1]

# Each animation: length (s), pose(t), and when the bar is in the hands (else it
# stays where it rests). The bar's centre is the midpoint of the hands.
ANIMATIONS = {
    "Squat": {"length": SQUAT_LENGTH, "pose": squat_pose, "held": lambda t: True},
    "Bench": {"length": BENCH_LENGTH, "pose": bench_pose, "held": lambda t: True},
    "Deadlift": {"length": DEADLIFT_LENGTH, "pose": deadlift_pose, "held": deadlift_bar_held},
}

# ---------------------------------------------------------------- Roblox KeyframeSequence writer
def _cframe_xml(m):
    p = m.to_translation()
    r = m.to_3x3()
    vals = [p.x, p.y, p.z] + [r[i][j] for i in range(3) for j in range(3)]
    tags = ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]
    return "".join(f"<{tag}>{v:.6f}</{tag}>" for tag, v in zip(tags, vals))

def export(name):
    """Writes art/animations/Station_<name>.rbxmx (a looping KeyframeSequence, Action priority)."""
    anim = ANIMATIONS[name]
    refs = iter(range(1, 1_000_000))
    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
           f'<Item class="KeyframeSequence" referent="RBX{next(refs)}"><Properties>'
           f'<float name="AuthoredHipHeight">2</float><bool name="Loop">true</bool>'
           f'<string name="Name">Station_{name}</string><token name="Priority">2</token>'
           f'</Properties>']
    children = {}
    for joint, (parent, child, c0, c1) in JOINTS.items():
        children.setdefault(parent, []).append((child, joint))

    def pose_xml(part, transforms):
        joint = CHILD_JOINT.get(part)
        m = transforms.get(joint, Matrix.Identity(4)) if joint else Matrix.Identity(4)
        s = (f'<Item class="Pose" referent="RBX{next(refs)}"><Properties>'
             f'<CoordinateFrame name="CFrame">{_cframe_xml(m)}</CoordinateFrame>'
             f'<token name="EasingDirection">0</token><token name="EasingStyle">0</token>'
             f'<string name="Name">{part}</string><float name="Weight">1</float></Properties>')
        for child, _ in children.get(part, []):
            s += pose_xml(child, transforms)
        return s + "</Item>"

    steps = int(round(anim["length"] / SAMPLE_STEP))
    for i in range(steps + 1):
        t = i * SAMPLE_STEP
        out.append(f'<Item class="Keyframe" referent="RBX{next(refs)}"><Properties>'
                   f'<string name="Name">Keyframe</string><float name="Time">{t:.3f}</float></Properties>')
        out.append(pose_xml("HumanoidRootPart", anim["pose"](t)))
        out.append("</Item>")
    out.append("</Item></roblox>")
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, f"Station_{name}.rbxmx")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    return path, steps + 1

# ---------------------------------------------------------------- Blender preview
TO_BLENDER = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))

def preview(name, base, shift=Matrix.Identity(4)):
    """Keyframes a preview rig (collection PREVIEW_<name>, objects <name>_<Part>) for one
    loop of the animation. base: the root part's matrix, rack-local Roblox (see
    PREVIEW_BASES). shift: a Blender-space offset, to line several stations up."""
    import bpy, bmesh
    anim = ANIMATIONS[name]
    coll_name = "PREVIEW_" + name
    old = bpy.data.collections.get(coll_name)
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old)
    coll = bpy.data.collections.new(coll_name)
    bpy.context.scene.collection.children.link(coll)

    def mat(nm, rgb):
        m = bpy.data.materials.get(nm) or bpy.data.materials.new(nm)
        m.use_nodes = True
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*rgb, 1)
        m.diffuse_color = (*rgb, 1)
        return m
    colours = {"Torso": mat("Rig_Torso", (0.15, 0.35, 0.75)), "Limb": mat("Rig_Limb", (0.85, 0.85, 0.82)),
               "Head": mat("Rig_Head", (0.95, 0.8, 0.2)), "Leg": mat("Rig_Leg", (0.1, 0.25, 0.6))}
    objs = {}
    for part, size in SIZES.items():
        if part == "HumanoidRootPart":
            continue
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Diagonal((*size, 1)))
        me = bpy.data.meshes.new("Rig_" + part)
        bm.to_mesh(me); bm.free()
        kind = "Torso" if "Torso" in part else "Head" if part == "Head" else "Leg" if ("Leg" in part or "Foot" in part) else "Limb"
        me.materials.append(colours[kind])
        o = bpy.data.objects.new(f"{name}_{part}", me)
        o.rotation_mode = "QUATERNION"
        coll.objects.link(o)
        objs[part] = o

    scene = bpy.context.scene
    scene.render.fps = FPS
    frames = int(round(anim["length"] * FPS))
    scene.frame_start, scene.frame_end = 1, frames
    for f in range(0, frames + 1, 3):
        t = f / FPS
        world = forward_kinematics(base, anim["pose"](t))
        for part, o in objs.items():
            m = shift @ TO_BLENDER @ world[part]
            o.matrix_world = m
            o.keyframe_insert("location", frame=f + 1)
            o.keyframe_insert("rotation_quaternion", frame=f + 1)
    return coll, objs

# Where StationPoses puts the root part (rack-local, Roblox), and where the bar
# rests when not held (StationVisuals / StationLayout). Keep in step with those.
FACE_RACK = Matrix.Rotation(math.pi, 4, "Y")
BENCH_HEAD_UP = 1.586              # head centre above the root on this rig
PREVIEW_BASES = {
    "Squat": T((0, HRP_STAND_Y, -1.0)) @ FACE_RACK,
    "Bench": T((0, BENCH_ROOT_HEIGHT, -0.3 - BENCH_HEAD_UP)) @ rx(90),
    "Deadlift": T((0, HRP_STAND_Y, -4.8)) @ FACE_RACK,
}
PREVIEW_BAR_REST = {"Squat": (0, 3.49, -0.28), "Bench": (0, 3.14, -0.28), "Deadlift": (0, 1.0, -4.2)}
DISPLAY_LOAD = ("Plate_25", "Plate_25", "Collar_Lock")   # TrainingStationConfig + collar

STATION_SPACING = 12.0             # Blender X between the preview stations

def preview_all(names=("Squat", "Bench", "Deadlift")):
    """Fresh scene with one station per lift side by side (Blender X 0, 12, 24): the
    rack (linked from ComboRack_01.blend, shown as collection instances; bench only at
    the Bench station), a loaded bar (Barbell_01.blend meshes) following the hands,
    and the keyframed rig. Nothing here is saved or exported."""
    import bpy
    bpy.ops.wm.read_homefile(use_empty=True)
    scene_coll = bpy.context.scene.collection
    with bpy.data.libraries.load(os.path.join(ROOT_DIR, "art", "blender", "ComboRack_01.blend"), link=True) as (src, dst):
        dst.objects = list(src.objects)
    rack = bpy.data.collections.new("PREVIEW_Rack")
    bench = bpy.data.collections.new("PREVIEW_Bench")
    for o in dst.objects:
        (bench if o.name.startswith("Bench_") else rack).objects.link(o)
    with bpy.data.libraries.load(os.path.join(ROOT_DIR, "art", "blender", "Barbell_01.blend"), link=True) as (src, dst):
        dst.objects = list(src.objects)
    kit = {o.name: o for o in dst.objects}
    stations = bpy.data.collections.new("PREVIEW_Stations")
    scene_coll.children.link(stations)

    for i, name in enumerate(names):
        shift = Matrix.Translation((i * STATION_SPACING, 0, 0))
        for coll in ([rack, bench] if name == "Bench" else [rack]):
            inst = bpy.data.objects.new(f"{name}_{coll.name}", None)
            inst.instance_type = "COLLECTION"
            inst.instance_collection = coll
            inst.matrix_world = shift
            stations.objects.link(inst)
        bar = bpy.data.objects.new(f"{name}_Bar", None)
        stations.objects.link(bar)

        def piece(src, m):
            c = bpy.data.objects.new(f"{name}_Bar_{src.name}", src.data)
            c.parent = bar
            c.matrix_basis = m
            stations.objects.link(c)
        piece(kit["Bar_Shaft"], Matrix.Identity(4))
        piece(kit["Bar_Sleeves"], Matrix.Identity(4))
        for side in (1, -1):
            x = 3.31
            for n in DISPLAY_LOAD:
                w = kit[n].dimensions.x
                m = Matrix.Translation((side * (x + w / 2), 0, kit[n].location.z))
                if side < 0:
                    m = m @ Matrix.Scale(-1, 4, (1, 0, 0))
                piece(kit[n], m)
                x += w

        base, rest = PREVIEW_BASES[name], PREVIEW_BAR_REST[name]
        preview(name, base, shift)
        frames = int(round(ANIMATIONS[name]["length"] * FPS))
        for f in range(0, frames + 1, 3):
            bar.matrix_world = shift @ TO_BLENDER @ bar_world(name, f / FPS, base, rest) @ TO_BLENDER.inverted()
            bar.keyframe_insert("location", frame=f + 1)
            bar.keyframe_insert("rotation_euler", frame=f + 1)

def bar_world(name, t, base, rest):
    """Where the bar is (Roblox rack-local) at time t: the midpoint of the hands while
    held, else its rest position. It stays level, along the rack's X."""
    anim = ANIMATIONS[name]
    if not anim["held"](t):
        return T(rest)
    world = forward_kinematics(base, anim["pose"](t))
    return T(hands_mid(world))
