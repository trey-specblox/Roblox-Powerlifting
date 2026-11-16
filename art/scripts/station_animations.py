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
OUT_DIR = os.environ.get("ANIM_OUT_DIR") or os.path.join(ROOT_DIR, "art", "animations")   # (env: a scratch folder)
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
# ---------------------------------------------------------------- the cartoon rig (lifter_heights.py)
# The cartoon lifters are taller than the block rig. lifter_heights.py holds the skeleton tables, chosen with the
# environment variable LIFTER_RIG: "torso" (DEFAULT, approved 2026-11-13: legs x1.0, torso x1.35, arms x1.2, HipHeight
# 2.0), "taller" (2026-11-12: legs x1.2286, torso and arms x1.15, HipHeight 2.4) or "block" (the measured block rig).
# Head, hands and feet are never stretched. Every animation is re-made on the chosen rig: each joint offset along a
# part's length is stretched by that part's factor. BLOCK_JOINTS keeps the measured block rig (the live game's bodies
# until the cartoon bodies go live).
_LH = {"__name__": "lifter_heights"}
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals()
                       else os.path.join(ROOT_DIR, "art", "scripts"), "lifter_heights.py")).read(), _LH)
BLOCK_JOINTS = dict(JOINTS)
BLOCK_SIZES = dict(SIZES)
_STRETCH = {"HumanoidRootPart": 1.0, "LowerTorso": _LH["TORSO"], "UpperTorso": _LH["TORSO"], "Head": 1.0,
            "UpperArm": _LH["ARM"], "LowerArm": _LH["ARM"], "Hand": 1.0,
            "UpperLeg": _LH["THIGH"], "LowerLeg": _LH["SHIN"], "Foot": 1.0}   # (knee 1.00 since 2026-11-16)


def _stretch_of(part):
    return _STRETCH.get(part.replace("Left", "").replace("Right", ""), 1.0)


RIG = _LH["RIG"]                   # "torso" (default), "taller" or "block"
TALLER = RIG != "block"            # (any stretched cartoon rig, not only the "taller" table)
if TALLER:
    JOINTS = {name: (parent, child, (c0[0], c0[1] * _stretch_of(parent), c0[2]), (c1[0], c1[1] * _stretch_of(child), c1[2]))
              for name, (parent, child, c0, c1) in BLOCK_JOINTS.items()}
    SIZES = {part: (x, y * _stretch_of(part), zz) for part, (x, y, zz) in BLOCK_SIZES.items()}

CHILD_JOINT = {child: name for name, (parent, child, c0, c1) in JOINTS.items()}
ORDER = ["LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand",
         "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
         "RightUpperLeg", "RightLowerLeg", "RightFoot"]
HRP_STAND_Y = _LH["HRP_STAND_Y"] if TALLER else 3.0          # HipHeight (2.0 torso, 2.4 taller, 2 block) + half the root part
# Roblox scales an animation's root translation by Humanoid.HipHeight / AuthoredHipHeight, so every exporter writes the
# hip height of the rig it was made on (2.0 torso, 2.4 taller, 2 block; ClothesConfig.HipHeight).
AUTHORED_HIP_HEIGHT = _LH["HIP_HEIGHT"] if TALLER else 2.0
LEG_SCALE = _LH["LEG"] if TALLER else 1.0                    # lengths along the legs (a step, a crouch, a jump)
TORSO_SCALE = _LH["TORSO"] if TALLER else 1.0                # lengths along the torso
ARM_SCALE = _LH["ARM"] if TALLER else 1.0                    # lengths along the arms (x1.2 torso, x1.15 taller)


def _straight_arm_reach(joints):
    """Shoulder joint to the hand's centre with the arm straight (the joints sit 0.5 to the side of the arm's line)."""
    down = (joints["LeftShoulder"][3][1] - joints["LeftElbow"][2][1] + joints["LeftElbow"][3][1]
            - joints["LeftWrist"][2][1] + joints["LeftWrist"][3][1])
    return math.hypot(down, joints["LeftShoulder"][3][0])


# How much further a straight arm reaches (1.170 torso, 1.127 taller: the hands and the shoulder's side offset are not
# stretched).
# Hand targets held out at arm's length are moved out from the shoulder by this, so they stay just within reach.
ARM_REACH_SCALE = _straight_arm_reach(JOINTS) / _straight_arm_reach(BLOCK_JOINTS)


def up_floor(height_from_floor):
    """A height above the floor on the BLOCK rig's body (a knee, the hips) to the same place on this rig's body."""
    return _LH["z"](height_from_floor) if TALLER else height_from_floor


def up_body(y_from_block_root):
    """A height written relative to the BLOCK rig's standing root (3.0 above the floor) on the body (a shoulder, the
    chest), moved to the same place on this rig's body."""
    return (_LH["z"](y_from_block_root + 3.0) - HRP_STAND_Y) if TALLER else y_from_block_root


def reach(length):
    """A distance along the arms (straight-arm reach) on this rig."""
    return length * ARM_SCALE


BLOCK_SHOULDER = Vector((-1.0, 0.763, 0.0))            # the left shoulder joint, block rig, root part's frame


def within_arm(target_block, target_now, shoulder_block=BLOCK_SHOULDER, shoulder_now=None):
    """A hand ON THE BODY (the belt, the hips, a thigh, the chest): target_now is the block rig's target_block moved
    with the body (up_body). On the torso rig the arms grow less than the torso (x1.2 vs x1.35), so a hand low on the
    body can end up out of reach (the arm locks straight and the hand misses). Then the point rises toward the
    shoulder just enough that the arm reaches it no straighter than on the block rig (its distance from the shoulder
    grows only by ARM_REACH_SCALE): the same bend of the arm, a little higher on the body. Anywhere the arm reaches,
    and on rigs whose arms grow with the torso (taller, block), target_now is kept. Distances are from the nearer
    shoulder (|x|), so it works for either hand. Same frame for all four points."""
    if not TALLER or ARM_SCALE >= TORSO_SCALE:
        return target_now
    if shoulder_now is None:
        shoulder_now = Vector((shoulder_block[0], up_body(shoulder_block[1]), shoulder_block[2]))

    def offset(t, s):
        return Vector((abs(t[0]) - abs(s[0]), t[1] - s[1], t[2] - s[2]))
    allowed = offset(target_block, shoulder_block).length * ARM_REACH_SCALE
    if offset(target_now, shoulder_now).length <= allowed:
        return target_now
    o = offset(target_now, shoulder_now)
    rise = math.sqrt(max(0.0, allowed * allowed - o.x * o.x - o.z * o.z))
    y = shoulder_now[1] - rise if target_now[1] < shoulder_now[1] else shoulder_now[1] + rise
    return type(target_now)((target_now[0], y, target_now[2]))


# The belt on the new bodies (gear v4, approved 2026-11-13): round the navel, a third of the way from the hips to the
# shoulder joint (2.79 above the floor on the torso rig), in the root part's frame. The block rig's belt hands were
# written lower (2.25-2.45, its waist), so moved with the body they would land below the belt.
BELT_NAVEL_Y = (_LH["NEW_HIPS"] + (_LH["z"](3.763) - _LH["NEW_HIPS"]) / 3.0) - HRP_STAND_Y


def on_belt(x, y, z, belt_ref):
    """A hand on the lifter's belt, written on the block rig (root part's frame) for a move whose own belt key is at
    belt_ref. On the torso rig the hand goes to the navel belt (BELT_NAVEL_Y), keeping its offset from belt_ref
    (stretched with the torso: a tug a little lower), within the arm's reach. Other rigs: hand_on_body, as before."""
    if RIG != "torso":
        return hand_on_body(x, y, z)
    return within_arm(Vector((x, y, z)), Vector((x, BELT_NAVEL_Y + (y - belt_ref) * TORSO_SCALE, z)))


def hand_on_body(x, y, z):
    """A hand target on the body, written on the block rig in the root part's frame: its height follows the body
    (up_body), kept within the arm's reach (within_arm)."""
    return within_arm(Vector((x, y, z)), Vector((x, up_body(y), z)))

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
# On the taller rig the arms are re-solved (squat_arm()) to put the hands at the same place on the upper back: the
# block rig's hand (x 1.55) at the bar's height on the back, a little behind the torso's centre.
SQUAT_HAND = Vector((-1.55, up_body(0.65), 0.3))
_SQUAT_ARM = None


SQUAT_ARM_RESOLVE = False   # (re-solving folded the longer arms to the elbow's limit: the approved angles look right)


def squat_arm():
    global _SQUAT_ARM
    if RIG == "torso":
        squat_lock_arms()                  # (torso rig: the arms that lock the hands onto the placed bar, mirrored)
        return dict(_SQUAT_LOCK["Left_angles"])
    if not TALLER or not SQUAT_ARM_RESOLVE:
        return SQUAT_ARM
    if _SQUAT_ARM is None:
        body = {"Root": rx(0.0), "Neck": rx(0.0)}
        body.update(legs(0.0, 0.0, 0.0, SQUAT_STANCE_OUT, SQUAT_TOES_OUT))

        def behind(w, a):
            elbow = joint_point(w, "LeftElbow")
            hand = w["LeftHand"].to_translation()
            # elbows below and behind the bar, and as close as it can stay to the approved block pose (user review
            # 2026-10-19): left free, the solver folded the elbow to its limit and turned the arm in.
            return (max(0.0, elbow.y - hand.y + 0.4) + max(0.0, hand.z - elbow.z)
                    + 0.004 * sum(abs(a[k] - SQUAT_ARM[k]) for k in ARM_KEYS))
        _SQUAT_ARM = solve_arms(body, SQUAT_HAND, SQUAT_ARM, behind, 5.0)[0]
    return _SQUAT_ARM

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

# ---------------------------------------------------------------- hands LOCKED onto a bar (torso rig)
# A hand that holds a bar is placed by its whole frame, not its centre: the bar in the Grip swap's hole (GRIP_POINT),
# the palm and fingers turned the way a lifter's are. lock_hand() solves the arm (shoulder raise/swing/twist, elbow)
# so the wrist lands where that frame needs it, then turns the wrist to match exactly (References/Character Animation
# Quality.md: one shared animation; the game's per-build hand IK does the same per body).

def hand_frame(side, palm, fingers):
    """The hand part's rotation with its palm facing `palm` and its fingers pointing `fingers` (the hand hangs palm-in
    at rest: palm +X on the left hand, -X on the right; fingers -Y; the thumb and the Grip hole's axis -Z)."""
    p, f = Vector(palm).normalized(), Vector(fingers).normalized()
    x = p if side == "Left" else -p
    y = -f
    z = x.cross(y)
    return Matrix((x, y, z)).transposed()


def grip_from_wrist(side):
    """The Grip hole's centre from the wrist joint, in the hand part's frame."""
    return Vector((GRIP_POINT.x if side == "Left" else -GRIP_POINT.x, GRIP_POINT.y - JOINTS[side + "Wrist"][3][1], 0.0))


def _arm_tf(side, a):
    s = 1 if side == "Left" else -1
    return rz(-s * a["raise"]) @ rx(a["swing"]) @ ry(s * a["twist"]), rx(a["elbow"])


def hand_centre_from_wrist(side):
    """The hand part's centre from the wrist joint, in the hand's frame (for lock_hand's `offset`)."""
    return Vector((0.0, -JOINTS[side + "Wrist"][3][1], 0.0))


def lock_hand(ut, side, point, rot, start, down=Vector((0, -1, 0)), back=Vector((0, 0, 1)), below=0.45, offset=None,
              clear_of=None, clearance=0.18, clear_upper=False, clear_build=None, keep=0.0005, first_step=16):
    """Arm angles + wrist turn putting `side`'s Grip hole on `point` with the hand turned `rot` (both in the frame `ut`
    is given in; ut = the UpperTorso part's frame). The elbow prefers to sit `below` under the bar and toward `back`.
    clear_of: posed part frames ({part: frame}, same frame as `ut`): the elbow and the forearm then keep `clearance`
    off that body's skin (the middle build's, _skin_near), so they never dig into the ribs or belly (user 2026-11-13,
    the chest slap's elbows "digging and phasing through the character's body"); back=None drops the elbow-behind wish.
    Returns (arm angles, {joint: Transform} for Shoulder, Elbow, Wrist, miss)."""
    _, _, c0s, c1s = JOINTS[side + "Shoulder"]
    _, _, c0e, c1e = JOINTS[side + "Elbow"]
    c0w = Vector(JOINTS[side + "Wrist"][2])
    wrist_goal = point - rot @ (grip_from_wrist(side) if offset is None else offset)

    def fk(a):
        sh, el = _arm_tf(side, a)
        upper = ut @ T(c0s) @ sh @ T(c1s).inverted()
        lower = upper @ T(c0e) @ el @ T(c1e).inverted()
        return upper, lower

    def cost(a):
        if not (-5 <= a["elbow"] <= 150):
            return 1e9
        upper, lower = fk(a)
        wrist = lower @ c0w
        turn = (lower.to_3x3().transposed() @ rot).to_quaternion().angle
        elbow = upper @ Vector(c0e)
        c = 20.0 * (wrist - wrist_goal).length
        c += 0.15 * turn + 2.0 * max(0.0, turn - math.radians(60))       # wrists near straight
        c += 0.5 * max(0.0, (elbow - point).dot(-down) + below)            # elbow under the bar
        if back is not None:
            c += 0.3 * max(0.0, -(elbow - point).dot(back) - 0.1)          # and not in front of it
        if clear_of is not None:                                            # upper arm, elbow, forearm clear of it
            shoulder = upper @ Vector(c1s)
            for q in ([shoulder.lerp(elbow, 0.7)] if clear_upper else []) + [elbow.lerp(wrist, k) for k in (0.0, 0.33, 0.66)]:
                near = _skin_near(q, clear_of, clear_build or CONTACT_BUILD)
                if near is not None:
                    c += 8.0 * max(0.0, clearance - near[0])
        c += keep * sum(abs(a[k] - start[k]) for k in ARM_KEYS)    # (keep: stay near `start`, the last frame;
        #  higher stops the elbow swinging round the shoulder-hand line from frame to frame, Chalk_Lifter 2026-11-13)
        return c
    a, best = dict(start), cost(start)
    for step in [s for s in (16, 8, 4, 2, 1, 0.5, 0.25) if s <= first_step]:   # (first_step < 16: no hops to another
        improved = True                                                          #  arm shape far from `start`)
        while improved:
            improved = False
            for k in ARM_KEYS:
                for d in (step, -step):
                    b = dict(a)
                    b[k] += d
                    c = cost(b)
                    if c < best - 1e-7:
                        a, best, improved = b, c, True
    upper, lower = fk(a)
    sh, el = _arm_tf(side, a)
    wr = (lower.to_3x3().transposed() @ rot).to_4x4()
    return a, {side + "Shoulder": sh, side + "Elbow": el, side + "Wrist": wr}, ((lower @ c0w) - wrist_goal).length


# ---------------------------------------------------------------- hands STOP AT THE SKIN (torso rig)
# References/Character Animation Quality.md: a hand aimed at the body (a chest slap, a trap slap, hands on the belly)
# stops at its skin instead of sinking in. Body-contact targets were written on the thin block rig; the production
# bodies are much deeper (chest, belly, traps), so a target moved over sinks in. contact_out() pushes a hand-centre
# target out along the skin's normal until the hand's centre is a hand's half-thickness off the skin, on the middle
# build (Fit; art/data/body_surface_05.json, export_body_surface.py), following the posed torso. Other builds: the
# game's per-build hand correction (anim_qa.py "@ik" previews it). Targets clear of the body are left alone.
import json as _json
from mathutils.kdtree import KDTree as _KDTree

BODY_SURFACE = os.path.join(ROOT_DIR, "art", "data", "body_surface_05.json")
CONTACT_BUILD = "Fit"
HAND_HALF = 0.135 * 1.22 + 0.03          # hand centre to the skin when the hand lies on it (palm or back), Fit's hand
_SURFACE = {}


def _surface(build=CONTACT_BUILD):
    """{part: (KDTree of rest points relative to the root part, [(point, normal)])} for a build."""
    if build not in _SURFACE:
        data = _json.load(open(BODY_SURFACE))["builds"][build]
        parts = {}
        for part, rows in data.items():
            pts = [(Vector((r[0], r[1] - HRP_STAND_Y, r[2])), Vector(r[3:6])) for r in rows]
            tree = _KDTree(len(pts))
            for i, (p, _n) in enumerate(pts):
                tree.insert(p, i)
            tree.balance()
            parts[part] = (tree, pts)
        _SURFACE[build] = parts
    return _SURFACE[build]


_REST_FRAMES = None


def contact_out(target, posed, rest=None, depth=HAND_HALF, build=CONTACT_BUILD):
    """(Three passes of contact_out_once: each nearest skin point's plane is only a local guess.)"""
    for _ in range(3):
        moved = contact_out_once(target, posed, rest, depth, build)
        if (moved - target).length < 1e-4:
            break
        target = moved
    return target


def contact_out_once(target, posed, rest=None, depth=HAND_HALF, build=CONTACT_BUILD):
    """`target` (a hand centre, in the frame `posed` is in: {part: part frame}, the root part at the origin) moved out
    of the posed body's skin to `depth` off it. rest: the same parts' frames at rest (default: this rig standing with
    the root part at the origin)."""
    global _REST_FRAMES
    if rest is None:
        if _REST_FRAMES is None:
            _REST_FRAMES = forward_kinematics(Matrix.Identity(4), {})
        rest = _REST_FRAMES
    worst = None
    for part, (tree, pts) in _surface(build).items():
        if part not in posed or part not in rest:
            continue
        m = posed[part] @ rest[part].inverted()
        local = m.inverted() @ target
        co, i, dist = tree.find(local)
        if co is None or dist > 1.2:
            continue
        p, n = pts[i]
        s = (local - p).dot(n)
        if s < depth and (worst is None or s - depth < worst[0]):
            worst = (s - depth, m, local, n)
    if worst is None:
        return target
    short, m, local, n = worst
    return m @ (local - n * short)


def _skin_near(point, frames, build=CONTACT_BUILD, facing=None):
    """The posed skin nearest `point` (root part's frame): (signed distance, skin point, outward normal) or None.
    facing: only skin whose outward normal points that way (within ~65 degrees), e.g. up for the top of a trap."""
    global _REST_FRAMES
    if _REST_FRAMES is None:
        _REST_FRAMES = forward_kinematics(Matrix.Identity(4), {})
    best = None
    for part, (tree, pts) in _surface(build).items():
        if part not in frames:
            continue
        m = frames[part] @ _REST_FRAMES[part].inverted()
        local = m.inverted() @ point
        if facing is None:
            co, i, dist = tree.find(local)
        else:
            want = (m.to_3x3().inverted() @ Vector(facing)).normalized()
            hits = [h for h in tree.find_n(local, 60) if pts[h[1]][1].dot(want) > 0.42]
            co, i, dist = hits[0] if hits else (None, None, None)
        if co is None or dist > 1.5:
            continue
        p, n = pts[i]
        s = (local - p).dot(n)
        if best is None or (facing is not None and dist < best[3]) or (facing is None and s < best[0]):
            best = (s, m @ p, (m.to_3x3() @ n).normalized(), dist)
    return best[:3] if best else None


CONTACT_PULL = 0.12      # a hand this close beyond resting on the skin is drawn onto it (a slap that falls short)
CONTACT_TURN = 0.30      # within this, the hand turns toward lying flat on the skin (fully at the skin)


def contact_pass(pose, build=CONTACT_BUILD, depth=HAND_HALF):
    """(torso rig) The hands of a finished pose made to LIE on the body where they meet it: a hand that sinks in, or
    falls just short, is put a hand's half-thickness off the skin, turned palm-to-skin (fingers carrying on along the
    arm's line, laid onto the skin), easing in as it nears; the shoulder and elbow move by the least that does it and
    the wrist takes the turn. Hands clear of the body are untouched. (References/Character Animation Quality.md)"""
    out = dict(pose)
    for side in ("Left", "Right"):
        frames = forward_kinematics(Matrix.Identity(4), out)
        centre = frames[side + "Hand"].to_translation()
        near = _skin_near(centre, frames, build)
        if near is None:
            continue
        s, skin, n = near
        if s > depth + CONTACT_TURN:
            continue
        w = 1.0 - smooth((s - depth) / CONTACT_TURN) if s > depth else 1.0
        move = (depth - s) if s < depth else ((depth - s) if s < depth + CONTACT_PULL else 0.0)
        goal = centre + n * move * (1.0 if s < depth else w)
        free = frames[side + "Hand"].to_3x3()
        fingers = free @ Vector((0, -1, 0))
        along = fingers - n * fingers.dot(n)
        if along.length < 1e-4:
            continue
        rot = free.to_quaternion().slerp(hand_frame(side, -n, along).to_quaternion(), w).to_matrix()
        sh0, el0 = out.get(side + "Shoulder", Matrix.Identity(4)), out.get(side + "Elbow", Matrix.Identity(4))

        def apply(q):
            p = dict(out)
            p[side + "Shoulder"] = sh0 @ rx(q[0]) @ ry(q[1]) @ rz(q[2])
            p[side + "Elbow"] = el0 @ rx(q[3])
            f = forward_kinematics(Matrix.Identity(4), p)
            lower = f[side + "LowerArm"].to_3x3()
            p[side + "Wrist"] = (lower.transposed() @ rot).to_4x4()
            c0 = Vector(JOINTS[side + "Wrist"][2])
            wrist = f[side + "LowerArm"] @ c0
            return p, wrist + rot @ Vector((0, -JOINTS[side + "Wrist"][3][1], 0))

        def cost(q):
            return 20.0 * (apply(q)[1] - goal).length + 0.002 * sum(abs(v) for v in q)
        q, best = [0.0, 0.0, 0.0, 0.0], cost([0.0, 0.0, 0.0, 0.0])
        for step in (8, 4, 2, 1, 0.5, 0.25):
            improved = True
            while improved:
                improved = False
                for i in range(4):
                    for d in (step, -step):
                        r = list(q)
                        r[i] += d
                        c = cost(r)
                        if c < best - 1e-7:
                            q, best, improved = r, c, True
        out = apply(q)[0]
    return out


def palm_contact(pose, side, spot, fingers, w, start, below=0.25, facing=None):
    """(torso rig) AUTHORED body contact on a finished pose (approved method, ChestSlap 2026-11-13): `side`'s hand
    goes, `w` of the way, to lie flat on the posed middle build's skin at `spot` (root part's frame), palm to the
    skin, fingers along `fingers` laid onto it, the elbow and arm kept off the body; the wrist takes the turn.
    start: arm angles to solve from (the last answer). Returns (pose, arm angles)."""
    if w <= 0:
        return pose, start
    frames = forward_kinematics(Matrix.Identity(4), pose)
    near = _skin_near(Vector(spot), frames, facing=facing)
    if near is None:
        return pose, start
    _s, skin, n = near
    on_skin = skin + n * HAND_HALF
    hand = frames[side + "Hand"]
    target = hand.to_translation().lerp(on_skin, w)
    f = Vector(fingers)
    along = f - n * f.dot(n)
    rot = hand.to_3x3().to_quaternion().slerp(hand_frame(side, -n, along).to_quaternion(), w).to_matrix()
    a, tfs, _miss = lock_hand(frames["UpperTorso"], side, target, rot, start, back=None, below=below,
                              offset=hand_centre_from_wrist(side), clear_of=frames, clear_upper=True)
    out = dict(pose)
    out.update(tfs)
    return out, a


# ---- The squat's bar and hands on the torso rig (2026-11-13; GAME_DESIGN §37.5 / user 2026-11-08: the bar across the
# upper back and shoulder blades, below the neck, wide grip outside the shoulders, elbows back and down). The block-rig
# arm angles (SQUAT_ARM, approved 2026-10-19) on the x1.5 arms put the hands, and so the bar the game draws between
# them, high near the neck with the elbows flared. Now the BAR is placed (on the middle build's back: Fit, at
# shoulder-blade height) and the hands lock onto it: palms forward, fingers over the bar, thumbs in. Each body's own
# back depth and shoulder width (Skinny back 0.39 ... Big and buff 0.72; delts 1.23 ... 2.03) is the game's per-build
# hand IK (anim_qa.py QA_BUILD_IK previews it).
SQUAT_BAR_REST = Vector((0.0, 4.30, 0.556 + 0.07 + 0.01))   # standing, from the floor (Roblox; +Z = behind): Fit's back
# Grip width (2026-11-14, user: the 1.95 grip was "right up against the plates", "only bigger builds should be doing
# that like 105kgs+"): a little outside the shoulders, Fit's outer delt (1.55) + 0.12. Per build (the game's per-build
# hand IK): delt + 0.12 for Skinny, Skinny-fat, Fit, Muscular; wide near the plates only for Fat and Big and buff.
SQUAT_GRIP_X = 1.67                                         # each hand's grip point out from the centre
# The squat's thumbless grip (user 2026-11-14 "Bar in palm heel"; the wrist wraps cut into the hand at the Grip's 80
# degrees): the "SquatGrip" swap hand, the bar in the HEEL of the palm (build_cartoon_hands_04.HEEL_C (0, -0.197,
# -0.19) in hand space, at Fit's hand size), much closer to the wrist than the Grip hole, so the wrist can stay nearer
# straight while the elbows stay BACK AND DOWN (approved 2026-11-13; never pointed forward).
SQUAT_GRIP_POINT = Vector((0.135 * 1.22 + 0.07, -(0.13 * 1.22 - 0.125), 0.0))
# The hand's turn round the bar is chosen with the arm: of the shapes with the elbows at least SQUAT_ELBOW_UNDER below
# the bar and SQUAT_ELBOW_BEHIND behind it (as far back as the approved hold), the straightest wrist. Measured
# 2026-11-14: 59 degrees (the approved hold with the Grip hand: 80); elbows only level with the bar would allow 46, a
# straight wrist only with the elbows forward, which the user rejected.
SQUAT_ELBOW_UNDER, SQUAT_ELBOW_BEHIND = 0.35, 0.20     # (the approved hold: 0.72 under, +0.25 behind)
SQUAT_TURNS = tuple(range(-90, 61, 15))
_SQUAT_STARTS = [{"raise": r, "swing": sw, "twist": tw, "elbow": e} for r in (-30.0, 0.0, 30.0, 60.0)
                 for sw in (-40.0, 0.0, 40.0) for tw in (30.0, 80.0, 130.0) for e in (100.0, 130.0)]
_SQUAT_LOCK = None


def squat_turn_frame(side, turn):
    """The hand's frame turned `turn` degrees round the bar from palm forward / fingers up."""
    t = math.radians(turn)
    return hand_frame(side, Vector((0.0, math.sin(t), -math.cos(t))), Vector((0.0, math.cos(t), math.sin(t))))


def squat_grip_from_wrist(side):
    """The squat grip point (palm heel) from the wrist joint, in the hand part's frame (lock_hand's offset)."""
    return Vector((SQUAT_GRIP_POINT.x if side == "Left" else -SQUAT_GRIP_POINT.x,
                   SQUAT_GRIP_POINT.y - JOINTS[side + "Wrist"][3][1], 0.0))


def squat_grip_point(w, side):
    """Where this hand holds the squat bar (the SquatGrip palm heel), root part's frame."""
    return w[side + "Hand"] @ Vector((SQUAT_GRIP_POINT.x if side == "Left" else -SQUAT_GRIP_POINT.x,
                                      SQUAT_GRIP_POINT.y, 0.0))


def wrist_bend(wrist):
    """Degrees between the hand's long axis and the forearm's (a wrist bent back, forward or sideways)."""
    return math.degrees((wrist.to_3x3() @ Vector((0, -1, 0))).angle(Vector((0, -1, 0))))


def squat_lock_arms():
    """{joint: Transform} of both arms holding the bar on the back (torso rig), in the torso's frame: solved once."""
    global _SQUAT_LOCK
    if _SQUAT_LOCK is None:
        world = forward_kinematics(T((0, HRP_STAND_Y, 0)), {})        # standing: rest positions = SQUAT_BAR_REST's frame
        ut = world["UpperTorso"]
        _SQUAT_LOCK = {}
        for side, s in (("Left", -1), ("Right", 1)):
            point = SQUAT_BAR_REST + Vector((s * SQUAT_GRIP_X, 0, 0))
            _, _, c0s, c1s = JOINTS[side + "Shoulder"]
            c0e = JOINTS[side + "Elbow"][2]
            best = None
            for turn in SQUAT_TURNS:
                rot = squat_turn_frame(side, turn)
                for start in _SQUAT_STARTS:
                    a, tfs, miss = lock_hand(ut, side, point, rot, start, offset=squat_grip_from_wrist(side))
                    if miss > 0.02:
                        continue
                    sh, _el = _arm_tf(side, a)
                    elbow = (ut @ T(c0s) @ sh @ T(c1s).inverted()) @ Vector(c0e)
                    if point.y - elbow.y < SQUAT_ELBOW_UNDER or elbow.z - point.z < SQUAT_ELBOW_BEHIND:
                        continue                                   # (elbows down, and back: never in front of the bar)
                    bend = wrist_bend(tfs[side + "Wrist"])
                    if best is None or bend < best[0]:
                        best = (bend, turn, a, tfs, miss)
            bend, turn, a, tfs, miss = best
            _SQUAT_LOCK.update(tfs)
            _SQUAT_LOCK[side + "_miss"] = miss
            _SQUAT_LOCK[side + "_angles"] = a
            _SQUAT_LOCK[side + "_turn"] = turn
            _SQUAT_LOCK[side + "_bend"] = bend
    return {k: v for k, v in _SQUAT_LOCK.items() if not k.endswith(("_miss", "_angles", "_turn", "_bend"))}


def squat_hand_frame(side):
    """(torso rig) the hand's turn on the bar in the hold, in the upper torso's frame (the set-up uses the same)."""
    squat_lock_arms()
    return squat_turn_frame(side, _SQUAT_LOCK[side + "_turn"])


def squat_wrists(g):
    """(torso rig) the hands' turn on the squat bar, g of the way from relaxed (0) to holding it (1)."""
    lock = squat_lock_arms()
    q0 = Matrix.Identity(4).to_quaternion()
    return {j: q0.slerp(lock[j].to_quaternion(), g).to_matrix().to_4x4() for j in ("LeftWrist", "RightWrist")}


def squat_pose(t):
    u = squat_depth(t)
    torso = blend(*SQUAT_TORSO, u)
    thigh, shin = blend(*SQUAT_THIGH, u), blend(*SQUAT_SHIN, u)

    def build(stance_out):
        pose = {"Root": rx(torso), "Neck": rx(-torso * 0.55)}   # neck: eyes roughly level
        pose.update(legs(torso, thigh, shin, stance_out, SQUAT_TOES_OUT))
        pose.update(squat_lock_arms() if RIG == "torso" else arms(squat_arm()))
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
BENCH_LOCKOUT = Vector((-1.9, up_body(0.75), reach(-1.52)))    # over the shoulders, arms straight
# Where the left elbow sits at lockout: shoulder level, turned out (the touch and
# lockout must be on the same arm "branch" or the arm would flip mid-rep).
BENCH_ELBOW_AT_LOCKOUT = Vector((-1.6, up_body(0.74), reach(-0.66)))
BENCH_CHEST = Vector((-1.9, up_body(0.3), -0.6))        # touching mid-chest
# Where the left elbow goes at the touch: flared out, about level with the chest
# and the torso's mid-plane (not hanging toward the floor), so it does not look
# like the bar was dropped (user review 2026-10-19).
BENCH_ELBOW_AT_CHEST = Vector((-1.86, up_body(0.74), 0.02))
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
DEADLIFT_BAR = Vector((-1.5, 1.0 - HRP_STAND_Y, -0.6))      # left hand centre on the floor bar (its centre 1.0 up)
DEADLIFT_TOES_OUT = 10.0

def _deadlift_body(torso, thigh, shin, swing=None, forward=None, grip=0.0, swing_right=None, arm_out=0.0):
    """swing: arms' forward angle relative to the torso; default hangs them straight down.
    forward: how far the whole lifter stands closer to the bar than the root part (torso rig: deadlift_forward()).
    grip (torso rig, 0..1): how far the hands have turned into the MIXED GRIP; swing_right: the right arm's own swing
    (a mixed grip puts the two hands on opposite sides of the bar, so the arms differ by a few degrees).
    arm_out (opt-in, default 0 = unchanged): both arms raised that many degrees out from the sides."""
    pose = {"Root": rx(torso), "Neck": rx(-torso * 0.45)}
    pose.update(legs(torso, thigh, shin, 0.0, DEADLIFT_TOES_OUT))
    pose.update(arms({"raise": arm_out, "swing": -torso if swing is None else swing, "twist": 0.0, "elbow": 0.0}))
    if swing_right is not None:
        pose["RightShoulder"] = rz(arm_out) @ rx(swing_right) if arm_out else rx(swing_right)
    if grip:
        pose.update(mixed_grip_wrists(grip))
    pose = plant_feet(pose)
    f = deadlift_forward() if forward is None else forward
    if f:
        pose["Root"] = T((0, 0, -f)) @ pose["Root"]
    return pose


# ---- The deadlift's MIXED GRIP (torso rig; user 2026-11-13: "make sure one hand is facing forward other is back ...
# the fingers are actually wrapped around grabbing it"). The hands hang palm-in; a quarter turn of each wrist (the
# same turn, the hands being mirrored) turns the LEFT palm forward (under-hand, thumb out) and the RIGHT palm back
# (over-hand, thumb in). The bar then sits in the fingers (the "Grip" hand swap's hole, build_cartoon_hands_04.py:
# hand space (0, -0.197, -0.40)), not at the hand's centre: GRIP_POINT is that hole in the hand part's own frame (palm
# side +X on the left hand, -X on the right; down -Y), at the middle build's hand size (Fit, 1.22). Each build's own
# hand size moves it by up to ~0.1 (Skinny 1.05 ... Big and buff 1.58): the game's per-build hand IK takes that up.
GRIP_HAND_SIZE = 1.22
GRIP_POINT = Vector((0.135 * GRIP_HAND_SIZE + 0.07, -(0.34 * GRIP_HAND_SIZE - 0.125), 0.0))


def mixed_grip_wrists(g):
    return {"LeftWrist": ry(90.0 * g), "RightWrist": ry(90.0 * g)}


def grip_point(w, side):
    """Where this hand holds the bar (torso rig: the Grip hole; other rigs: the hand's centre), root part's frame."""
    if RIG != "torso":
        return w[side + "Hand"].to_translation()
    return w[side + "Hand"] @ Vector((GRIP_POINT.x if side == "Left" else -GRIP_POINT.x, GRIP_POINT.y, 0.0))


DEADLIFT_BAR_RIGHT = Vector((-DEADLIFT_BAR.x, DEADLIFT_BAR.y, DEADLIFT_BAR.z))


def _right_swing_onto(torso, thigh, shin, swing, fwd, target_z=None, grip=1.0, arm_out=0.0):
    """The right arm's swing that puts its grip on the bar (target_z: only on that bar path line, by bisection)."""
    def body(s):
        return forward_kinematics(Matrix.Identity(4), _deadlift_body(torso, thigh, shin, swing, fwd, grip, s, arm_out))
    if target_z is not None:
        lo, hi = -torso - 60.0, -torso + 80.0
        for _ in range(40):
            mid = (lo + hi) / 2
            if grip_point(body(mid), "Right").z > target_z:
                lo = mid
            else:
                hi = mid
        return (lo + hi) / 2
    miss = lambda s: (grip_point(body(s), "Right") - DEADLIFT_BAR_RIGHT).length
    s = min(range(-60, 121, 4), key=miss) + 0.0
    for step in (2, 1, 0.5, 0.25, 0.1, 0.05):
        s = min((s - step, s, s + step), key=miss)
    return s


# ---- The torso rig's deadlift set-up (2026-11-13, References/Character Animation Quality.md "Deadlift").
# The block rig's solve (arms hanging straight down onto the bar, hips above the knees) on the torso rig (torso x1.35,
# arms x1.2, block legs) leaned the SHINS BACKWARD (knees 0.49 behind the ankles), sat the hips 1.23 behind the feet and
# left the bar 0.48 ahead of the midfoot: the "sitting back, hips out" set-up. Measured: with this torso, these arms
# and these legs no pose has upright shins, hips above the knees AND the shoulders just over the bar (the arms were too
# short for the torso; the user then chose arms x1.5, lifter_heights.py). This solve asks for real technique - the
# bar against the shins over the midfoot, shins angled slightly forward, hips above the knees, straight arms, the
# shoulders just over the bar - and gets as close as the skeleton allows. With arms x1.5 and the bar held in the
# fingers (the mixed grip below): shins upright, the bar 0.25 ahead of the midfoot (the thick cartoon shins never let
# it sit exactly over it), hips 0.44 above the knees (at most 0.45: higher reads as a stiff-legged pull), back 31
# degrees, arms near vertical (left 9 back, right 1), shoulders 0.20 over the bar. (Without the midfoot rule the shins
# lean forward and the bar ends up over the toes, 0.52 ahead: it read as a squat, 2026-11-13 comparison.)
# deadlift_forward() (0.23) moves the whole lifter that much closer to the bar than the root part (the game's floor bar
# stays 0.6 in front of the root part; no game change).
DEADLIFT_SHIN_CLEARANCE = 0.36    # the thickest shin's front (Fat 0.25, CartoonBodies_05) + bar radius 0.07 + a hair
DEADLIFT_MIDFOOT = 0.12            # half way from heel to toe, ahead of the ankle (all six CartoonBodies_05 feet)
DEADLIFT_BAR_OVER_FOOT = 0.25      # the bar at most this far ahead of the midfoot (thick cartoon shins: never exactly over it)
DEADLIFT_WANT = {"shin_lean": 0.15, "hip_above_knee": 0.3, "shoulder_ahead": 0.15}
DEADLIFT_HIPS_HIGHEST = 0.45       # hips above the knees by at most this (higher reads as a stiff-legged deadlift)
_DL_FIT = None


def _dl_numbers(w):
    """Set-up numbers of a posed body (root part's frame; the lifter faces -Z)."""
    ank, knee, hip = joint_point(w, "LeftAnkle"), joint_point(w, "LeftKnee"), joint_point(w, "LeftHip")
    bar_y = DEADLIFT_BAR.y
    u = (bar_y - ank.y) / max(1e-6, knee.y - ank.y)
    shin_z = ank.z + (knee.z - ank.z) * u                       # the shin's line at the bar's height
    top = w["LeftUpperArm"] @ Vector((0, JOINTS["LeftShoulder"][3][1], 0))     # top of the upper arm
    return {"shin_lean": ank.z - knee.z, "hip_above_knee": hip.y - knee.y,
            "bar_gap": (shin_z - DEADLIFT_SHIN_CLEARANCE) - DEADLIFT_BAR.z,    # + = the bar clear of the shin
            "shoulder_ahead": DEADLIFT_BAR.z - top.z, "bar_ahead_of_midfoot": (ank.z - DEADLIFT_BAR.z) - DEADLIFT_MIDFOOT}


def _solve_deadlift_torso():
    """(torso, thigh, shin, swing, forward) of the torso rig's set-up: the hands on the bar (straight arms), the bar
    against the shins, then as close to DEADLIFT_WANT as the body allows (upright shins first)."""
    def complete(torso, thigh, shin):
        # forward: the bar exactly against the shins (bar_gap 0); swing: the straight arm closest to the bar
        w0 = forward_kinematics(Matrix.Identity(4), _deadlift_body(torso, thigh, shin, None, 0.0))
        fwd = _dl_numbers(w0)["bar_gap"]                 # (the body moving forward closes the gap one for one)
        miss = lambda s: (grip_point(forward_kinematics(Matrix.Identity(4), _deadlift_body(torso, thigh, shin, s, fwd, 1.0)),
                                     "Left") - DEADLIFT_BAR).length
        s = min(range(-60, 121, 4), key=miss) + 0.0
        for step in (2, 1, 0.5, 0.25, 0.1, 0.05):
            s = min((s - step, s, s + step), key=miss)
        return [torso, thigh, shin, s, fwd]

    def cost(v):
        full = complete(*v)
        w = forward_kinematics(Matrix.Identity(4), _deadlift_body(*full, 1.0))
        n = _dl_numbers(w)
        c = 20 * (grip_point(w, "Left") - DEADLIFT_BAR).length
        c += 3 * abs(n["shin_lean"] - DEADLIFT_WANT["shin_lean"])
        c += 5 * max(0.0, DEADLIFT_WANT["hip_above_knee"] - n["hip_above_knee"])
        c += 3 * max(0.0, n["hip_above_knee"] - DEADLIFT_HIPS_HIGHEST)       # (not a stiff-legged pull either)
        c += 2 * abs(n["shoulder_ahead"] - DEADLIFT_WANT["shoulder_ahead"])
        c += 6 * max(0.0, n["bar_ahead_of_midfoot"] - DEADLIFT_BAR_OVER_FOOT)
        return c
    # the hand-on-bar term couples all three angles, so single-angle steps stall: steps along every direction of the
    # 3 angles (26), from a few starts; the best wins
    moves = [(a, b, c) for a in (-1, 0, 1) for b in (-1, 0, 1) for c in (-1, 0, 1) if (a, b, c) != (0, 0, 0)]
    found = []
    for start in ([-60.0, 68.0, -5.0], [-45.0, 60.0, -15.0], [-35.0, 70.0, -20.0], [-52.0, 55.0, -10.0]):
        v, best = start, cost(start)
        for step in (8, 4, 2, 1, 0.5, 0.25, 0.1):
            improved = True
            while improved:
                improved = False
                for m in moves:
                    w = [v[i] + m[i] * step for i in range(3)]
                    c = cost(w)
                    if c < best - 1e-7:
                        v, best, improved = w, c, True
        found.append((best, v))
    best, v = min(found)
    full = complete(*v)
    full.append(_right_swing_onto(full[0], full[1], full[2], full[3], full[4]))     # [5]: the right arm (mixed grip)
    return full, best


def _dl_fit():
    global _DL_FIT
    if _DL_FIT is None:
        _DL_FIT = _solve_deadlift_torso()[0]
    return _DL_FIT


def deadlift_forward():
    """How far the lifter stands closer to the floor bar than the root part (torso rig only; 0 elsewhere)."""
    return _dl_fit()[4] if RIG == "torso" else 0.0

def _deadlift_on_bar_path(torso, thigh, shin, arm_out=0.0):
    """While the bar is held: straight arms swung just enough to keep the hands (the
    bar) on a vertical path DEADLIFT_BAR.z in front of the feet, so the bar slides up
    the front of the shins and thighs instead of passing through them (bisection).
    arm_out (opt-in, default 0 = unchanged): the arms that many degrees out from the sides (Station_Deadlift's lockout)."""
    lo, hi = -torso - 5.0, -torso + 80.0          # more swing = hands further forward (-z)
    grip = 0.0
    if RIG == "torso":
        lo = -torso - 60.0                        # (torso rig: the arms slant back onto the bar at the bottom)
        grip = 1.0                                # (and hold it in the mixed grip, by the Grip hole)
    for _ in range(40):
        mid = (lo + hi) / 2
        w = forward_kinematics(Matrix.Identity(4), _deadlift_body(torso, thigh, shin, mid, None, grip, None, arm_out))
        if grip_point(w, "Left").z > DEADLIFT_BAR.z:
            lo = mid
        else:
            hi = mid
    left = (lo + hi) / 2
    if RIG != "torso":
        return _deadlift_body(torso, thigh, shin, left)
    right = _right_swing_onto(torso, thigh, shin, left, None, DEADLIFT_BAR.z, 1.0, arm_out)
    return _deadlift_body(torso, thigh, shin, left, None, 1.0, right, arm_out)

def _solve_deadlift_bottom():
    """Hip hinge that puts the straight-armed hands on the floor bar, hips above the knees. (torso rig: the set-up
    above; returns its (torso, thigh, shin))"""
    if RIG == "torso":
        return list(_dl_fit()[:3]), 0.0

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

# (2026-11-16, clothes count as the body, rule 17) Station_Deadlift ONLY: whenever he is upright (standing, and the bar
# at the lockout) the arms hang this many degrees out from the sides, easing to 0 as he goes down to the floor bar (the
# set position is unchanged), so the hands stay outside the singlet shorts where they flare at the hip (Skinny: the
# underhand left hand's back sank 0.15 into them at the lockout, the hanging hand 0.09 standing up; 4 degrees still left
# 0.02 at mid-thigh in the pull). Setup_Deadlift's hanging arms: setup_animations.DL_HANG_OUT. Other scripts calling
# deadlift_pose(t) / _deadlift_on_bar_path keep the old arms (default 0).
DEADLIFT_STATION_ARM_OUT = 5.0

def deadlift_pose(t, arm_out=0.0):
    global _DEADLIFT
    if _DEADLIFT is None:
        _DEADLIFT = _solve_deadlift_bottom()[0]
    u = deadlift_depth(t)
    # The top of the movement is the leaned-back lockout while the bar is held,
    # and a relaxed neutral stand before the grip and after letting go.
    held = deadlift_bar_held(t)
    top = DEADLIFT_LOCKOUT if held else (0.0, 0.0, 0.0)
    torso, thigh, shin = (blend(top[i], _DEADLIFT[i], u) for i in range(3))
    if held:
        return _deadlift_on_bar_path(torso, thigh, shin, arm_out * (1.0 - u))
    if RIG == "torso" and u > 0:
        # (torso rig) the arms reach for the bar on the way down (and leave it on the way up): at the bottom they hang
        # slanted onto the bar, not straight down
        reach = _dl_fit()[3] + (_DEADLIFT[0] - torso)            # the bottom's slant, kept as the torso turns
        reach_right = _dl_fit()[5] + (_DEADLIFT[0] - torso)
        g = smooth(u)                                             # (the hands turn into the mixed grip as they reach)
        return _deadlift_body(torso, thigh, shin, blend(-torso, reach, g), None, g, blend(-torso, reach_right, g),
                              arm_out * (1.0 - u))
    return _deadlift_body(torso, thigh, shin, arm_out=arm_out * (1.0 - u))

def deadlift_bar_held(t):
    return DEADLIFT_BAR_HELD[0] <= t < DEADLIFT_BAR_HELD[1]

# Each animation: length (s), pose(t), and when the bar is in the hands (else it
# stays where it rests). The bar's centre is the midpoint of the hands.
ANIMATIONS = {
    "Squat": {"length": SQUAT_LENGTH, "pose": squat_pose, "held": lambda t: True},
    "Bench": {"length": BENCH_LENGTH, "pose": bench_pose, "held": lambda t: True},
    "Deadlift": {"length": DEADLIFT_LENGTH, "pose": lambda t: deadlift_pose(t, DEADLIFT_STATION_ARM_OUT),
                 "held": deadlift_bar_held},
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
           f'<float name="AuthoredHipHeight">{AUTHORED_HIP_HEIGHT:g}</float><bool name="Loop">true</bool>'
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
BENCH_HEAD_UP = forward_kinematics(Matrix.Identity(4), {})["Head"].to_translation().y   # head centre above the root
                                                                                       # (1.886 taller, 1.586 block)
PREVIEW_BASES = {
    "Squat": T((0, HRP_STAND_Y, -1.0)) @ FACE_RACK,
    "Bench": T((0, BENCH_ROOT_HEIGHT, -0.3 - BENCH_HEAD_UP)) @ rx(90),
    "Deadlift": T((0, HRP_STAND_Y, -4.8)) @ FACE_RACK,
}
# Where the cartoon lifters' J-cups hold the bar (the rack's holes are 0.175 apart; game code: StationLayout).
#   taller (2026-11-12): the squat cups 0.70 higher (4 holes, bar 4.365), the bench cups 0.175 higher (3.315).
#   torso (2026-11-13): the squat cups 0.525 higher (3 holes, bar 4.19): the bar on this rig's back stands at 4.31,
#     so 4.365 would sit above it (they could only lift it on tiptoe); 4.19 is just under it, a slight knee bend
#     (user 2026-11-08: "the height of their shoulder blades"; the block rig's bar was 0.05 under its back, 3.715).
#     The bench cups stay 1 hole up (3.315, just under the longer arms' lockout, 3.47).
#   StationLayout's tallSquatJCupRaise is still 0.70 (taller): the torso bodies need 0.525 (Phase 4, game code).
BAR_REST_SQUAT_Y = {"torso": 4.19, "taller": 4.365}.get(RIG, 3.665)
BAR_REST_BENCH_Y = {"torso": 3.315, "taller": 3.315}.get(RIG, 3.14)
PREVIEW_BAR_REST = {"Squat": (0, BAR_REST_SQUAT_Y, -0.28), "Bench": (0, BAR_REST_BENCH_Y, -0.28), "Deadlift": (0, 1.0, -4.2)}
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
