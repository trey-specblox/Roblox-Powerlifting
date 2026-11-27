# The podium ceremony (GAME_DESIGN.md §40.5 "The podium ceremony", user 2026-11-25): the top 3 are called one by one;
# each walks to the FRONT of their podium block where a REFEREE on the floor, facing them, hands over the award and they
# shake hands; then the lifter hops up onto the block (5x5 studs; 1st 3.0 tall, 2nd 2.0, 3rd 1.4).
# Local / Regional: a medal over the neck for all three. State / Nationals: 1st is handed a trophy, 2nd and 3rd a medal.
#
# Clips (art/animations/<name>.rbxmx, Action priority, not looped):
#   Ceremony_Ref_PlaceMedal + Ceremony_Lifter_ReceiveMedal   (3.0 s) the referee lifts the medal by its ribbon over the
#       lifter's head (the lifter dips his head), lowers it onto his neck, lets go; the lifter straightens up proud and
#       looks down at it.
#   Ceremony_Ref_Handshake + Ceremony_Lifter_Handshake       (2.5 s) right hands meet midway, palms together, 3 pumps.
#   Ceremony_Ref_HandTrophy + Ceremony_Lifter_TakeTrophy_<Build> (3.0 s) the referee holds the trophy out (left hand
#       under the base, right hand on the back of the cup); the lifter takes it by both sides of the cup and brings it in
#       to his chest. ONE LIFTER CLIP PER BUILD: a two-handed hold on a rigid object cannot be shared, because the same
#       joint turns put the hands of the six builds up to ~1 stud further apart or closer together (their shoulders and
#       resting arm splay differ: CartoonExport05.json joints), so each variant is solved on its own build's skeleton.
#   Ceremony_Lifter_StepUp                                   (1.2 s) a hop onto the block: crouch, spring, tuck, land
#       with a squash, straighten. IN PLACE: the game moves the root along the arc in code (as MeetCoachLook's JUMP);
#       on the floor phases the clip lowers the hips so the feet stay flat (crouch, squash).
#
# The referee is a MeetFigures "Referee": MeetFigures.build with no look -> LifterBuild.BuildRules.Spotter = "Fat", in a
# tee, joggers and sneakers; his clips are solved on the Fat skeleton (meet_end_animations BODY_JOINTS["Fat"]).
# Shared lifter clips are on the standard lifter skeleton (station_animations S.JOINTS) like every other lifter clip.
#
# Arms: the approved exact two-bone solve (entrance_animations.ik_arm: the elbow pointed where it is told, never behind
# the body by a solver's whim), done here for either arm in the chest frame (so a turned waist is fine), the hand turned
# by the wrist (S.hand_frame) and the arm solved for the wrist joint. Elbows are kept gently bent where the move allows.
#
# PLACEMENT (the game): both on the floor, the referee facing the lifter:
#   refRoot = lifterRoot * CFrame.new(x, 0, -d) * CFrame.Angles(0, math.pi, 0)
# (x right of the lifter, d in front of him), per clip and lifter build: PLACEMENT below, fitted by `pairqa`.
#
#   blender -b --factory-startup --python art/scripts/ceremony_animations.py
#       writes the clips (ANIM_OUT_DIR=<folder> for a scratch folder)
#   blender -b art/blender/CartoonBodies_05_Rigged.blend --python art/scripts/ceremony_animations.py -- pairqa <out>
#       READ-ONLY pair check on the real bodies (lifter in the meet outfit, referee in his tee/joggers): fits the
#       placement, measures every keyframe, pictures. env CER_CLIPS=Medal,Handshake,Trophy  CER_LIFTERS=...
#       CER_PICTURES=Skinny,Fat,BigBuff  CER_ANIMS=<folder with the clips>
import importlib.util
import json
import math
import os
import sys

from mathutils import Matrix, Quaternion, Vector

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\Powerlifting Roblox\art\scripts"
ROOT = os.path.dirname(os.path.dirname(_HERE))
LIFTERS = ("Skinny", "SkinnyFat", "Fit", "Fat", "Muscular", "BigBuff")
HAND_SIZE = {"Skinny": 1.05, "SkinnyFat": 1.12, "Fit": 1.22, "Fat": 1.30, "Muscular": 1.50, "BigBuff": 1.58}
REF_BUILD = "Fat"
HRP_Y = 3.0                       # the root part's centre above the floor (HipHeight 2.0 + 1.0), both bodies

# ---------------------------------------------------------------- timings (seconds; the game keys off these)
MEDAL_LENGTH = 3.0
MEDAL_GRIP = (0.0, 1.98)          # the referee's hands show the Grip swap (holding the ribbon) until he lets go
MEDAL_OVER_HEAD = 1.15            # the ribbon passes over the lifter's head (the hands at their highest, over his brow)
MEDAL_ON_NECK = 1.85              # the hands reach the upper chest: the ribbon lies on the neck -> swap to the worn medal
SHAKE_LENGTH = 2.5
SHAKE_CONTACT = (0.62, 1.78)      # the palms together (pumps 0.85-1.55)
TROPHY_LENGTH = 3.0
TROPHY_TOUCH = 1.05               # the lifter's palms land on the cup
TROPHY_WELD = 1.25                # weld the trophy to the lifter (it was the referee's) at this time
TROPHY_REF_LETGO = 1.32           # the referee's hands start to leave it
STEP_LENGTH = 1.2
STEP_LAUNCH, STEP_TOP, STEP_LAND = 0.40, 0.60, 0.80

# ---------------------------------------------------------------- the modules and the skeletons
_espec = importlib.util.spec_from_file_location("entrance_animations", os.path.join(_HERE, "entrance_animations.py"))
E = importlib.util.module_from_spec(_espec)
_espec.loader.exec_module(E)
F, S = E.F, E.S
I4 = Matrix.Identity(4)
DEFAULT_JOINTS = dict(S.JOINTS)
_BUILDS = json.load(open(os.path.join(ROOT, "art", "exports", "CartoonExport05.json")))["builds"]


def joint_table(rest):
    """S.JOINTS for a body given its rest joints (rig-local Roblox studs from the floor), each part's frame at its own
    joint, the hand's at its centre 0.125 under the wrist (meet_end_animations.use_body)."""
    j = {k: Vector(v) for k, v in rest.items()}
    for side, sx in (("Left", 1), ("Right", -1)):
        for part in ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot"):
            v = j["Left" + part]
            j[side + part] = Vector((v.x * sx, v.y, v.z))
    j.setdefault("Neck", Vector((0, 4.7, 0)))
    z = lambda a, b: tuple(j[a] - j[b])
    table = {"Root": ("HumanoidRootPart", "LowerTorso", z("LowerTorso", "HumanoidRootNode"), (0, 0, 0)),
             "Waist": ("LowerTorso", "UpperTorso", z("UpperTorso", "LowerTorso"), (0, 0, 0)),
             "Neck": ("UpperTorso", "Head", z("Neck", "UpperTorso"), (0, 0, 0))}
    for side in ("Left", "Right"):
        table[side + "Shoulder"] = ("UpperTorso", side + "UpperArm", z(side + "UpperArm", "UpperTorso"), (0, 0, 0))
        table[side + "Elbow"] = (side + "UpperArm", side + "LowerArm", z(side + "LowerArm", side + "UpperArm"), (0, 0, 0))
        table[side + "Wrist"] = (side + "LowerArm", side + "Hand", z(side + "Hand", side + "LowerArm"), (0, 0.125, 0))
        table[side + "Hip"] = ("LowerTorso", side + "UpperLeg", z(side + "UpperLeg", "LowerTorso"), (0, 0, 0))
        table[side + "Knee"] = (side + "UpperLeg", side + "LowerLeg", z(side + "LowerLeg", side + "UpperLeg"), (0, 0, 0))
        table[side + "Ankle"] = (side + "LowerLeg", side + "Foot", z(side + "Foot", side + "LowerLeg"), (0, 0, 0))
    return table


def build_rest(build):
    r = dict(_BUILDS[build]["joints"])
    r["Neck"] = (0.0, 4.7, 0.0)
    return r


def use(table):
    S.JOINTS.clear()
    S.JOINTS.update(table)


def P(x, y_floor, z):
    """A point in a root part's frame from (x right, height above the floor, z back)."""
    return Vector((x, y_floor - HRP_Y, z))


def l2r(p, d, x=0.0):
    """Lifter root frame <-> referee root frame (the referee at (x, 0, -d), turned to face the lifter); its own inverse."""
    return Vector((x - p.x, p.y, -d - p.z))


def dir_l2r(v):
    return Vector((-v.x, v.y, -v.z))


ROT_Y180 = Matrix.Rotation(math.pi, 3, "Y")

# ---------------------------------------------------------------- hand points (from the WRIST joint, hand frame:
# left hand hanging palm +X, fingers -Y, thumb -Z; the right mirrors X), at hand size s (HandShapeConfig.HandSize)


def grip_point(side, s):
    """The Grip swap's hole centre (anim_qa.grip_at): what the fingers close round."""
    return Vector(((0.135 * s + 0.07) * (1 if side == "Left" else -1), -0.34 * s, 0.0))


def palm_point(side, s):
    """The middle of the open palm's surface (entrance_animations.HAND_BOX: palm face 0.178 out, middle 0.255 down
    the fingers, 0.08 toward the thumb)."""
    return Vector((0.178 * s * (1 if side == "Left" else -1), -0.255 * s, -0.08 * s))


def hand_rot(side, palm, thumb):
    """The hand's rotation (root frame) with its palm facing `palm` and its thumb (and the Grip hole's axis) toward
    `thumb` (made square to the palm); fingers follow."""
    p = Vector(palm).normalized()
    th = Vector(thumb)
    th = (th - p * th.dot(p)).normalized()
    f = th.cross(p) if side == "Left" else p.cross(th)
    return S.hand_frame(side, p, f)


def along_palm(side, palm):
    """rot(forearm) for Arms.put: the palm facing `palm`, the fingers continuing the forearm's line as far as that
    palm allows (the forearm projected onto the palm's plane): the least wrist bend."""
    p = Vector(palm).normalized()

    def fn(fore):
        f = fore - p * fore.dot(p)
        if f.length < 1e-4:
            f = Vector((0, 1, 0)) - p * p.y
        return S.hand_frame(side, p, f.normalized())
    return fn


def along_thumb(side, thumb):
    """rot(forearm): the thumb (and the Grip hole's axis) toward `thumb`, the fingers continuing the forearm's line
    as far as that allows (a fist round a stem, a ribbon held up)."""
    th = Vector(thumb).normalized()

    def fn(fore):
        f = (fore - th * fore.dot(th)).normalized()
        p = f.cross(th) if side == "Left" else th.cross(f)
        return S.hand_frame(side, p, f)
    return fn


MIRROR = Matrix.Diagonal((-1.0, 1.0, 1.0))


def solve_arm(body, side, point, rot, offset, pull, prev):
    """(arm angles, wrist Transform): `side`'s hand turned `rot` (root frame) with its hand-frame point `offset` (from
    the wrist joint) on `point`, the elbow pointing toward `pull` (chest frame, written for the LEFT arm; the right
    mirrors), moving the shortest way from `prev`. entrance_animations.ik_arm's exact two-bone solve, in the chest frame
    for either arm. rot None: the hand keeps the forearm's line (wrist straight) and `point` is the wrist joint."""
    frames = S.forward_kinematics(I4, body)
    ut = frames["UpperTorso"]
    c0s = Vector(S.JOINTS[side + "Shoulder"][2])
    goal = point if rot is None else point - rot @ offset
    h = ut.to_3x3().transposed() @ (goal - ut @ c0s)
    if side == "Right":
        h = MIRROR @ h
    _p, _c, l0s, l1s = S.JOINTS["LeftShoulder"]
    _p, _c, l0e, l1e = S.JOINTS["LeftElbow"]
    _p, _c, l0w, _l1w = S.JOINTS["LeftWrist"]
    U = Vector(l0e) - Vector(l1s)
    lf = (Vector(l0w) - Vector(l1e)).length
    uy, ux = -U.y, U.x
    cos_e = (h.length_squared - ux * ux - uy * uy - lf * lf) / (2 * uy * lf)
    e = math.degrees(math.acos(max(math.cos(math.radians(150.0)), min(1.0, cos_e))))
    er = math.radians(e)
    v = Vector((ux, -uy - lf * math.cos(er), -lf * math.sin(er)))
    a1 = v.normalized()
    a2 = (Vector((0, 0, 1)) - a1 * a1.z).normalized()
    b1 = h.normalized()
    pl = Vector(pull)
    b2 = pl - b1 * pl.dot(b1)
    b2 = b2.normalized() if b2.length > 1e-6 else a2
    A = Matrix((a1, a2, a1.cross(a2))).transposed()
    B = Matrix((b1, b2, b1.cross(b2))).transposed()
    rs = B @ A.transposed()
    from mathutils import Euler
    compat = Euler((math.radians(prev["swing"]), math.radians(prev["twist"]), math.radians(-prev["raise"])), "YXZ")
    eu = rs.to_euler("YXZ", compat)
    a = {"raise": -math.degrees(eu.z), "swing": math.degrees(eu.x), "twist": math.degrees(eu.y), "elbow": e}
    if rot is None:
        return a, I4
    lower = lower_frame(body, side, a)
    return a, (lower.to_3x3().transposed() @ rot).to_4x4()


def lower_frame(body, side, a):
    ut = S.forward_kinematics(I4, body)["UpperTorso"]
    _p, _c, c0s, c1s = S.JOINTS[side + "Shoulder"]
    _p, _c, c0e, c1e = S.JOINTS[side + "Elbow"]
    sh, el = S._arm_tf(side, a)
    return ut @ S.T(c0s) @ sh @ S.T(c1s).inverted() @ S.T(c0e) @ el @ S.T(c1e).inverted()


def wrist_frame(pose, side):
    """The wrist joint's frame (root frame) of a posed body: the hand's rotation, at the wrist joint."""
    w = S.forward_kinematics(I4, pose)
    return w[side + "Hand"] @ S.T(S.JOINTS[side + "Wrist"][3])


def track(keys, t):
    a, b, u = F.at(keys, t)
    if isinstance(a, Vector):
        return a.lerp(b, u)
    if isinstance(a, Quaternion):
        return a.slerp(b if a.dot(b) >= 0 else -b, u)
    return a + (b - a) * u


def lin(keys, t):
    """Linear (unsmoothed) between keys."""
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, a), (t1, b) in zip(keys, keys[1:]):
        if t <= t1:
            u = (t - t0) / (t1 - t0)
            return a.lerp(b, u) if isinstance(a, Vector) else a + (b - a) * u
    return keys[-1][1]


def arc_keys(keys, pivot, t):
    """Between keys round `pivot` (a shoulder): the direction turned, the distance eased: a sweep of a nearly straight
    arm does not cut inside the reach and fold the elbow."""
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, a), (t1, b) in zip(keys, keys[1:]):
        if t <= t1:
            u = S.smooth((t - t0) / (t1 - t0))
            da, db = a - pivot, b - pivot
            d = da.normalized().slerp(db.normalized(), u) if da.angle(db) > 1e-4 else da.normalized()
            return pivot + d * (da.length + (db.length - da.length) * u)
    return keys[-1][1]


def bump(t, centre, half):
    u = (t - centre) / half
    return 0.0 if abs(u) >= 1.0 else 0.5 * (1.0 + math.cos(math.pi * u))


def times_for(length, fine=()):
    """Keyframe times: every 0.05 s (0.033 inside `fine` spans: pumps, the hop)."""
    out, t = [], 0.0
    while t < length - 1e-6:
        out.append(round(t, 3))
        t += 1.0 / 30.0 if any(a <= t < b for a, b in fine) else 0.05
    out.append(length)
    return out


HANG_ARM = dict(F.HANG)


def hang_pose(body):
    p = dict(body)
    p.update(E.one_arm("Left", HANG_ARM))
    p.update(E.one_arm("Right", HANG_ARM))
    return p


def upright(waist=None, neck=None):
    """A standing body: legs untouched (feet where they are), the Waist and Neck turned."""
    return {"Waist": waist if waist is not None else I4, "Neck": neck if neck is not None else I4}


class Arms:
    """Solves the arms of one clip in time order (each frame from the last: no flips) and keeps the worst numbers."""

    def __init__(self):
        self.prev = {"Left": dict(HANG_ARM), "Right": dict(HANG_ARM)}
        self.worst = {"elbow": 0.0, "wrist": 0.0, "miss": 0.0}
        self.log = []          # (side, elbow, wrist) per put, for CER_DEBUG

    def put(self, pose, side, point, rot, offset, pull, weight=1.0, free=None):
        """side's hand onto (point, rot) at `weight` (0..1) blended from `free` (the hanging/relaxed arm angles: the
        blend is a rotation of the shoulder, E._blend-style, so the arm never swings the long way round).
        rot may be a function of the forearm's direction (root frame) -> rotation: the hand then FOLLOWS the forearm
        (the least wrist bend for the palm it must show), solved a few rounds as the forearm settles."""
        body = {k: v for k, v in pose.items() if k not in (side + "Shoulder", side + "Elbow", side + "Wrist")}
        if callable(rot):
            fn, a = rot, self.prev[side]
            for _ in range(4):
                fore = lower_frame(body, side, a).to_3x3() @ Vector((0, -1, 0))
                rot = fn(fore.normalized())
                a, wr = solve_arm(body, side, point, rot, offset, pull, self.prev[side])
        else:
            a, wr = solve_arm(body, side, point, rot, offset, pull, self.prev[side])
        if free is not None and weight < 1.0:
            sh_a, _el = S._arm_tf(side, a)
            sh_f, _el = S._arm_tf(side, free)
            q = sh_f.to_quaternion().slerp(sh_a.to_quaternion(), weight)
            pose[side + "Shoulder"] = q.to_matrix().to_4x4()
            pose[side + "Elbow"] = S.rx(free["elbow"] + (a["elbow"] - free["elbow"]) * weight)
            pose[side + "Wrist"] = Quaternion().slerp(wr.to_quaternion(), weight).to_matrix().to_4x4()
            self.prev[side] = {k: free[k] + (a[k] - free[k]) * weight for k in a}
            return
        pose.update(E.one_arm(side, a))
        pose[side + "Wrist"] = wr
        self.prev[side] = a
        self.worst["elbow"] = max(self.worst["elbow"], a["elbow"])
        self.worst["wrist"] = max(self.worst["wrist"], math.degrees(wr.to_quaternion().angle))
        bend = math.degrees((wr.to_3x3() @ Vector((0, -1, 0))).angle(Vector((0, -1, 0))))
        self.worst["bend"] = max(self.worst.get("bend", 0.0), bend)
        self.log.append((side, a["elbow"], math.degrees(wr.to_quaternion().angle), bend))
        if rot is not None:
            got = wrist_frame(pose, side)
            self.worst["miss"] = max(self.worst["miss"], ((got @ offset.to_4d()).to_3d() - point).length)

    def hang(self, pose, side, arm=None):
        a = dict(arm or HANG_ARM)
        pose.update(E.one_arm(side, a))
        pose[side + "Wrist"] = I4
        self.prev[side] = a


# ================================================================ 1. THE MEDAL
# Design (studs; lifter root frame of the middle build Fit at the nominal spot D_MEDAL; the referee's clip is this path
# turned into HIS frame, so it is one clip for every lifter build, the game standing him per build). The two hold
# points (the Grip holes, where the medal's ribbon is held) stay exactly MEDAL_HOLD apart (a rigid held medal). Hands
# thumbs up, palms facing each other, fingers toward the lifter and down a little (a soft hold of the ribbon). The
# hands stay IN FRONT of the lifter's head (never beside it: the head is 1.2 wide, the hold points 0.9 apart): up over
# his brow as he dips his head, the ribbon's far side drops behind his head, then down in front of his face to his upper
# chest (below the chin), where the ribbon lies round the back of the neck; the referee lets go and steps back his hands.
MEDAL_HOLD = 1.5    # the real held medal's hold points (art/exports/WornMedal_01_fit.json "held": +-0.75 in the
#                     HeldMedal_Ribbon part's space; the loop opens wider than a head). Grip holes, thumbs toward the
#                     middle: the ribbon folds over each fist like over a bar (the fold's radius is the bar's, 0.07).
D_MEDAL = 3.45                     # nominal (Fit); pairqa fits each build's own
# (arms x1.5: an elbow bent past ~90 deg creases the mesh (user 2026-11-25, the back pat), so the referee stands about
#  an arm's length off and the hands are never pulled in close to his own chest)
MEDAL_MID_REF = [                  # the hold points' midpoint, REFEREE frame (x his right, z back; he faces -z)
    (0.00, P(0.0, 4.02, -2.08)),   # holding the medal out in front of him, showing it (held further out, it was
    (0.30, P(0.0, 4.05, -2.10)),   #  thrust at the lifter's belt)
    (0.78, P(0.0, 5.25, -2.30)),   # rising in front of the lifter's face
    (MEDAL_OVER_HEAD, P(0.0, 6.12, -2.33)),   # over the lifter's dipped brow: the ribbon passes over the head
    (1.30, P(0.0, 6.08, -2.26)),
    (1.55, P(0.0, 5.35, -2.12)),   # down in front of his face (well clear of it: the slim builds stand closest)
    (MEDAL_ON_NECK, P(0.0, 4.75, -2.45)),     # just under his chin: the ribbon round the back of the neck
    (1.98, P(0.0, 4.74, -2.45)),   # let go
]
# (2026-11-25 review: let go, his hands came forward and down to the lifter's belt. Now they lift off, draw back toward
#  his own chest and drop to his sides, never nearer the lifter than ~0.6 (pairqa release_gap).)
MEDAL_RELEASE_HAND = [(2.20, Vector((0.03, 0.08, 0.22))),      # (from the let-go spot: up off him, back)
                      (2.48, P(0.98, 3.95, -2.02)),            # back toward his own chest (x: out from his middle)
                      (2.75, P(1.35, 2.90, -1.55))]            # down past his own belly, out to the side
MEDAL_RELEASE = [(1.98, Vector((0, 0, 0))), (2.18, Vector((0.12, -0.10, 0.18))), (2.45, Vector((0.25, -0.55, 0.25)))]
# (relative to the release spot, per hand: x outward, y, z back toward himself; then the arms swing down to hang)
MEDAL_HANG_FROM, MEDAL_HANG_AT = 2.75, 3.00
REF_LEAN = [(0.0, 0.0), (0.3, 0.0), (0.85, -9.0), (MEDAL_OVER_HEAD, -15.0), (1.4, -13.0), (MEDAL_ON_NECK, -4.0),
            (2.0, -3.0), (2.45, 5.0), (2.85, 1.0), (MEDAL_LENGTH, 0.0)]   # (leans back a touch letting go)
REF_LOOK = [(0.0, -8.0), (0.3, -8.0), (0.85, 6.0), (MEDAL_OVER_HEAD, 14.0), (1.4, 10.0), (MEDAL_ON_NECK, -6.0),
            (2.3, -2.0), (2.8, 0.0), (MEDAL_LENGTH, 0.0)]    # (looking at the medal, up over the head, down, at him)


def medal_ref():
    use(joint_table(build_rest(REF_BUILD)))
    s = HAND_SIZE[REF_BUILD]
    arms = Arms()
    poses = {}
    # elbows: down and out while low, out to the sides with the arms raised
    pulls = [(0.0, Vector((-0.6, -1.0, 0.2))), (0.4, Vector((-0.7, -1.0, 0.1))), (0.85, Vector((-1.0, -0.5, 0.0))),
             (1.35, Vector((-1.0, -0.4, 0.0))), (1.7, Vector((-0.8, -1.0, 0.1))), (2.5, Vector((-0.4, -1.0, 0.3))),
             (MEDAL_LENGTH, Vector((-0.3, -0.8, 0.6)))]
    for t in times_for(MEDAL_LENGTH, fine=((0.7, 2.1),)):
        body = upright(S.rx(track(REF_LEAN, t)), S.rx(track(REF_LOOK, t)))
        pose = hang_pose(body)
        pull = track(pulls, t)
        ut = S.forward_kinematics(I4, body)["UpperTorso"]
        for side, sx in (("Left", -1.0), ("Right", 1.0)):
            # fists round the ribbon's folds, thumbs (the Grip hole's axis) toward the middle and a little up, the
            # fingers following the forearm
            rot = along_thumb(side, Vector((-sx, 0.35, 0.0)))
            if t <= 1.98:
                mid = track(MEDAL_MID_REF, t)
                point = mid + Vector((sx * MEDAL_HOLD / 2, 0, 0))
                arms.put(pose, side, point, rot, grip_point(side, s), pull)
            elif t <= MEDAL_HANG_FROM:
                land = MEDAL_MID_REF[-1][1] + Vector((sx * MEDAL_HOLD / 2, 0, 0))
                (t1, v1), (t2, v2), (t3, v3) = MEDAL_RELEASE_HAND
                keys = [(1.98, land), (t1, land + Vector((sx * v1.x, v1.y, v1.z))),
                        (t2, Vector((sx * v2.x, v2.y, v2.z))), (t3, Vector((sx * v3.x, v3.y, v3.z)))]
                point = track(keys, t)
                arms.put(pose, side, point, rot, grip_point(side, s), pull)
            else:
                # the arm swings down to hang (a rotation blend from the last solved arm)
                u = S.smooth((t - MEDAL_HANG_FROM) / (MEDAL_HANG_AT - MEDAL_HANG_FROM))
                a0 = medal_ref.last[side]
                q = S._arm_tf(side, a0)[0].to_quaternion().slerp(S._arm_tf(side, HANG_ARM)[0].to_quaternion(), u)
                pose[side + "Shoulder"] = q.to_matrix().to_4x4()
                pose[side + "Elbow"] = S.rx(a0["elbow"] + (HANG_ARM["elbow"] - a0["elbow"]) * u)
                pose[side + "Wrist"] = medal_ref.last_wrist[side].to_quaternion().slerp(Quaternion(), u).to_matrix().to_4x4()
                continue
            if t <= MEDAL_HANG_FROM:
                medal_ref.last[side] = dict(arms.prev[side])
                medal_ref.last_wrist[side] = pose[side + "Wrist"].copy()
        poses[t] = pose
    return poses, arms.worst


medal_ref.last, medal_ref.last_wrist = {}, {}

# The lifter: stands proud, dips his head (and a touch of the shoulders) as the ribbon comes over, straightens up proud
# (chest up, chin up), looks down at the medal on his chest, chin up again. Arms hang relaxed (no hand touch: one clip for
# six chest depths would float the hand off Skinny's chest or sink it into Fat's).
# (the head dips only once the hands are up above it, and lifts again as they come down in front of his face: dipped
#  earlier, his head met the rising hands)
LIFTER_NECK = [(0.0, 0.0), (0.93, 0.0), (1.12, -25.0), (1.24, -25.0), (1.55, -5.0), (2.05, 3.0), (2.25, 3.0),
               (2.5, -16.0), (2.7, -16.0), (2.95, 4.0), (MEDAL_LENGTH, 4.0)]
LIFTER_LEAN = [(0.0, 0.0), (0.93, 0.0), (1.12, -4.0), (1.3, -4.0), (1.75, 0.0), (2.05, 2.5), (MEDAL_LENGTH, 2.5)]
PROUD_ARM = {"raise": 6.0, "swing": -3.0, "twist": 0.0, "elbow": 10.0}


def medal_lifter():
    use(DEFAULT_JOINTS)
    poses = {}
    for t in times_for(MEDAL_LENGTH):
        body = upright(S.rx(track(LIFTER_LEAN, t)), S.rx(track(LIFTER_NECK, t)))
        k = S.smooth((t - 1.8) / 0.4)
        arm = {q: HANG_ARM[q] + (PROUD_ARM[q] - HANG_ARM[q]) * k for q in HANG_ARM}
        pose = dict(body)
        pose.update(E.one_arm("Left", arm))
        pose.update(E.one_arm("Right", arm))
        poses[t] = pose
    return poses, {}


# ================================================================ 2. THE HANDSHAKE
# The right hands meet midway between them, a little to the lifter's right of his middle (the referee stands offset to
# the lifter's right by SHAKE_X, so each hand comes forward and in a little, like people shaking hands). Open hands,
# thumbs up, palms flat together, the fingers of each pointing a little toward its own left (along the other's palm to
# his wrist); 3 pumps of 0.13 studs. Elbows ~45-60 deg, the upper arm forward and in, never across the body.
D_SHAKE = 3.55
SHAKE_X = 0.55                      # the referee's root this far to the lifter's right (nominal)
SHAKE_MEET = P(0.275, 3.42, -1.775)  # the palms' meeting point (lifter frame, nominal Fit placement)
SHAKE_ANGLE = 18.0                  # each hand's fingers turned this far toward its own left (degrees)
SHAKE_PUMPS = (0.85, 1.55, 3)       # pumps: from, to, how many


def _pump(t):
    a, b, n = SHAKE_PUMPS
    if t <= a or t >= b:
        return 0.0
    u = (t - a) / (b - a)
    fade = min(1.0, u / 0.12, (1 - u) / 0.12)
    return 0.13 * fade * math.sin(2 * math.pi * n * u)


def shake_meet_lifter(t):
    """The contact point (palms' middles), lifter frame: reaching in, the pumps, letting go."""
    return SHAKE_MEET + Vector((0.0, _pump(t), 0.0))


def shake_clip(who):
    if who == "ref":
        use(joint_table(build_rest(REF_BUILD)))
        s = HAND_SIZE[REF_BUILD]
    else:
        use(DEFAULT_JOINTS)
        s = HAND_SIZE["Fit"]
    arms = Arms()
    poses = {}
    a_ = math.radians(SHAKE_ANGLE)
    # own frame: the right palm faces own left (-x) turned by the angle; thumb up; fingers forward and toward own left
    palm = Vector((-math.cos(a_), 0.0, math.sin(a_)))
    rot = hand_rot("Right", palm, Vector((0, 1, 0)))
    # the right hand's palm-middle path, own frame: from the hang, a curve forward (pre: just short of the other's
    # hand), onto the contact point, pumps, off and back down
    def contact(t):
        c = shake_meet_lifter(t)
        return c if who == "lifter" else l2r(c, D_SHAKE, SHAKE_X)
    pre_off = Vector((0.06, -0.10, 0.12))        # (own frame: a hand's width short, lower, nearer himself)
    pulls = [(0.0, Vector((-0.2, -0.5, 1.0))), (0.3, Vector((-0.4, -1.0, 0.3))), (2.0, Vector((-0.4, -1.0, 0.3))),
             (SHAKE_LENGTH, Vector((-0.2, -0.5, 1.0)))]
    lean = [(0.0, 0.0), (0.35, -4.0), (1.8, -4.0), (2.4, 0.0), (SHAKE_LENGTH, 0.0)]
    nod = lambda t: -6.0 * bump(t, 1.0, 0.25) - 4.0 * bump(t, 1.45, 0.22)
    turn = [(0.0, 0.0), (0.4, 7.0), (1.9, 7.0), (2.45, 0.0), (SHAKE_LENGTH, 0.0)]   # chest turned a touch to his left
    for t in times_for(SHAKE_LENGTH, fine=((0.5, 1.9),)):
        body = upright(S.ry(track(turn, t)) @ S.rx(track(lean, t)), S.rx(-3.0 + nod(t)))
        pose = hang_pose(body)
        arms.hang(pose, "Left", {"raise": 5.0, "swing": 2.0, "twist": 0.0, "elbow": 10.0})
        c = contact(min(max(t, SHAKE_CONTACT[0]), SHAKE_CONTACT[1]))
        if t < SHAKE_CONTACT[0]:
            # reaching: from the hanging arm to just short of the hand, then in
            u = S.smooth(t / SHAKE_CONTACT[0])
            target = c + pre_off * (1.0 - S.smooth((t - 0.35) / (SHAKE_CONTACT[0] - 0.35)))
            arms.put(pose, "Right", target, rot, palm_point("Right", s), track(pulls, t), weight=min(1.0, u * 1.25),
                     free=HANG_ARM)
        elif t <= SHAKE_CONTACT[1]:
            arms.put(pose, "Right", contact(t), rot, palm_point("Right", s), track(pulls, t))
        else:
            u = S.smooth((t - SHAKE_CONTACT[1]) / (SHAKE_LENGTH - 0.1 - SHAKE_CONTACT[1]))
            target = contact(SHAKE_CONTACT[1]) + pre_off * min(1.0, 3.0 * u)
            arms.put(pose, "Right", target, rot, palm_point("Right", s), track(pulls, t), weight=1.0 - u,
                     free=HANG_ARM)
        poses[t] = pose
    return poses, arms.worst


# ================================================================ 3. THE TROPHY
# The trophy (art/blender/Trophy_01.blend, MeetLevelConfig.TrophyAssetId): origin at the base's bottom centre, up +Y,
# CENTRAL on the base's front (-Z). Base 0.62 square, 0.34 tall; the cup's widest ~0.40 (y 1.14-1.38), its sides where
# the lifter holds it ~0.36 out at y 1.05. It never turns: its front faces the lifter's forward throughout (CENTRAL to
# the crowd/camera in front of him; while the referee holds it, toward the referee).
TROPHY_HOLD_Y = 1.08                 # the lifter's palms on the cup's sides at this height on the trophy
TROPHY_SIDE = 0.385                  # the cup's radius there (lathe outline: 0.35 at 1.14, 0.27 at 0.96: 0.33 ... 0.37)
D_TROPHY = float(os.environ.get("CER_D_TROPHY", "4.1"))   # the same for every build (each build's clip reaches it)
# The trophy's base-bottom centre, REFEREE frame: held in front of him, then presented forward.
TROPHY_PRESENT = float(os.environ.get("CER_TROPHY_PRESENT", "2.0"))
TROPHY_REF = [(0.0, P(0.0, 3.28, -1.85)), (0.3, P(0.0, 3.30, -1.86)), (0.95, P(0.0, 3.40, -TROPHY_PRESENT + 0.02)),
              (TROPHY_WELD, P(0.0, 3.42, -TROPHY_PRESENT))]
# The referee's hands on it, in HIS frame from the base-bottom centre: his LEFT hand flat under the base (palm up,
# fingers toward the lifter), his RIGHT flat on the base's right side (palm in, fingers ahead), open: he holds it out by the
# base, and lets go by drawing both hands straight back and down, where nothing is in the way. The lifter's hands take
# the cup's two sides, well above, so nobody's hands meet. (Tried: his right fist round the stem; letting go of it, the
# opening fingers swept through the base, and his fist touched the big builds' hands on the cup.)
REF_UNDER_BASE = Vector((-0.04, -0.012, 0.0))      # (palm middle, a hair under the base)
REF_ON_BASE = Vector((0.322, 0.17, 0.04))          # (palm middle on the base's right side face, his right)
TROPHY_GRIP = (0.0, 0.0)                           # no hand swap in this clip: both hands open


def trophy_ref():
    use(joint_table(build_rest(REF_BUILD)))
    s = HAND_SIZE[REF_BUILD]
    arms = Arms()
    poses = {}
    pulls = [(0.0, Vector((-0.7, -1.0, 0.2))), (2.0, Vector((-0.7, -1.0, 0.2))), (TROPHY_LENGTH, Vector((-0.3, -0.8, 0.6)))]
    lean = [(0.0, 0.0), (0.3, 0.0), (0.95, -5.0), (TROPHY_WELD, -5.0), (1.9, 0.0), (TROPHY_LENGTH, 0.0)]
    look = [(0.0, -10.0), (0.3, -10.0), (0.95, -4.0), (1.3, -2.0), (2.0, 0.0), (TROPHY_LENGTH, 0.0)]
    letgo = TROPHY_REF_LETGO
    for t in times_for(TROPHY_LENGTH, fine=((0.9, 1.7),)):
        body = upright(S.rx(track(lean, t)), S.rx(track(look, t)))
        pose = hang_pose(body)
        base = track(TROPHY_REF, min(t, TROPHY_WELD))
        # left: palm up under the base, fingers forward (toward the lifter: -z his frame); right: palm toward the lifter
        # (-z) flat on the cup's back, thumb up-ish, fingers up
        rot_l = along_palm("Left", Vector((0, 1, 0)))       # palm up under the base, fingers along the forearm
        rot_r = along_palm("Right", Vector((-1, 0, 0)))     # palm flat on the base's side, fingers along the forearm
        pts = {"Left": base + REF_UNDER_BASE, "Right": base + REF_ON_BASE}
        offs = {"Left": palm_point("Left", s), "Right": palm_point("Right", s)}
        for side, rot in (("Left", rot_l), ("Right", rot_r)):
            if t <= letgo:
                arms.put(pose, side, pts[side], rot, offs[side], track(pulls, t))
                trophy_ref.last[side] = (dict(arms.prev[side]), pose[side + "Wrist"].copy())
            else:
                # off it: the hand backs away (left down and back, right back) on the way to the hang
                u = S.smooth((t - letgo) / 0.3)
                back = Vector((0.0, -0.20, 0.22)) if side == "Left" else Vector((0.18, -0.12, 0.22))
                side_off = Vector((0.0, 0.0, 0.0))
                drop = 0.3
                if t <= letgo + drop:
                    k = S.smooth((t - letgo - 0.3) / 0.25) if t > letgo + 0.3 else 0.0
                    arms.put(pose, side, pts[side] + back * u + side_off * k, rot, offs[side], track(pulls, t))
                    trophy_ref.last[side] = (dict(arms.prev[side]), pose[side + "Wrist"].copy())
                else:
                    a0, w0 = trophy_ref.last[side]
                    v = S.smooth((t - letgo - drop) / (0.85 - drop))
                    q = S._arm_tf(side, a0)[0].to_quaternion().slerp(S._arm_tf(side, HANG_ARM)[0].to_quaternion(), v)
                    pose[side + "Shoulder"] = q.to_matrix().to_4x4()
                    pose[side + "Elbow"] = S.rx(a0["elbow"] + (HANG_ARM["elbow"] - a0["elbow"]) * v)
                    pose[side + "Wrist"] = w0.to_quaternion().slerp(Quaternion(), v).to_matrix().to_4x4()
        poses[t] = pose
    return poses, arms.worst


trophy_ref.last = {}

# The lifter (per build): reaches to the cup's sides as it is presented, palms on it at TROPHY_TOUCH, takes it at
# TROPHY_WELD and lifts it in toward his chest (its base-bottom centre ends at (0, TROPHY_CHEST_Y, -TROPHY_CHEST_Z) in
# his frame, the same for every build), holding it there. TROPHY_FRONT: each build's outer clothes 3.4-4.2 up (kept for
# reference: the held spot clears Fat's by 0.75, the deepest).
TROPHY_CHEST_Y = float(os.environ.get("CER_TROPHY_CHEST_Y", "3.60"))
# The held spot is the SAME distance in front of every build (the shoulders are all at z 0): a forearm's length out in
# front of the chest, so the elbows stay at ~90 deg (pressed against the chest they would fold ~115 deg and crease).
TROPHY_CHEST_Z = float(os.environ.get("CER_TROPHY_CHEST_Z", "1.95"))
TROPHY_FRONT = {"Skinny": 0.53, "SkinnyFat": 0.51, "Fit": 0.62, "Fat": 0.89, "Muscular": 0.68, "BigBuff": 0.78}
# (outer clothes' front, 3.4-4.2 up, measured on the v12/v14 exports: the base and cup sit at that height)


def trophy_lifter(build, d, x=0.0):
    use(joint_table(build_rest(build)))
    s = HAND_SIZE[build]
    arms = Arms()
    poses = {}
    presented = l2r(TROPHY_REF[-1][1], d, x)                 # (the base point, lifter frame; the trophy does not turn)
    chest = P(0.0, TROPHY_CHEST_Y, -TROPHY_CHEST_Z)
    path = [(TROPHY_WELD, presented), (1.45, presented + Vector((0, 0.06, 0.08))), (2.15, chest), (TROPHY_LENGTH, chest)]
    pulls = [(0.0, Vector((-0.3, -0.6, 0.8))), (0.5, Vector((-0.7, -1.0, 0.1))), (TROPHY_LENGTH, Vector((-0.7, -1.0, 0.1)))]
    lean = [(0.0, 0.0), (0.5, 0.0), (1.0, -5.0), (1.4, -4.0), (2.2, 1.5), (TROPHY_LENGTH, 1.5)]
    look = [(0.0, -4.0), (0.5, -6.0), (1.0, -10.0), (1.4, -8.0), (2.2, -5.0), (2.5, 4.0), (TROPHY_LENGTH, 4.0)]
    for t in times_for(TROPHY_LENGTH, fine=((0.9, 1.6),)):
        body = upright(S.rx(track(lean, t)), S.rx(track(look, t)))
        pose = hang_pose(body)
        if t <= TROPHY_WELD:
            # before the weld the trophy is where the referee has it (his clip, this placement)
            base = l2r(track(TROPHY_REF, t), d, x)
        else:
            base = track(path, t)
        for side, sx in (("Left", -1.0), ("Right", 1.0)):
            # palms on the cup's sides, thumbs up, fingers wrapping forward round the cup (fingers pointing up past the
            # rim read as clapping the cup, 2026-11-25 pictures)
            rot = hand_rot(side, Vector((-sx, 0.0, 0.0)), Vector((0.0, 1.0, 0.25)))
            on = base + Vector((sx * TROPHY_SIDE, TROPHY_HOLD_Y, 0.0))
            if t < 0.35:
                arms.hang(pose, side)
                continue
            if t < TROPHY_TOUCH:
                # reaching in: from the hang to just off the cup's side (0.12 out, a little low), then onto it
                u = S.smooth((t - 0.35) / (TROPHY_TOUCH - 0.35))
                k = S.smooth((t - 0.75) / (TROPHY_TOUCH - 0.75))
                target = on + Vector((sx * 0.14 * (1 - k), -0.10 * (1 - k), 0.0))
                arms.put(pose, side, target, rot, palm_point(side, s), track(pulls, t), weight=min(1.0, u * 1.2),
                         free=HANG_ARM)
            else:
                arms.put(pose, side, on, rot, palm_point(side, s), track(pulls, t))
        poses[t] = pose
    return poses, arms.worst


def trophy_base_lifter(t, d, x=0.0, build="Fit"):
    """Where the trophy's base-bottom centre is (lifter frame) at t, for the pictures and the game."""
    if t <= TROPHY_WELD:
        return l2r(track(TROPHY_REF, t), d, x)
    presented = l2r(TROPHY_REF[-1][1], d, x)
    chest = P(0.0, TROPHY_CHEST_Y, -TROPHY_CHEST_Z)
    return track([(TROPHY_WELD, presented), (1.45, presented + Vector((0, 0.06, 0.08))), (2.15, chest),
                  (TROPHY_LENGTH, chest)], t)


# ================================================================ 4. THE STEP UP (a hop onto the block)
# Legs as station_animations.legs angles (absolute, from the upright root): thigh + forward, shin + forward (knee
# behind), feet flat (toes pointed down in the air). Floor phases planted (the hips drop as the legs bend: feet flat
# on the floor or the block's top); air phases leave the hips at standing height (Root translation 0): the GAME lifts
# the root along its arc between STEP_LAUNCH and STEP_LAND (0 -> block height), moving it forward onto the block.
STEP_KEYS = [  # t, torso, thigh, shin, toe pitch (+ up), arm swing (+ forward), arm raise, elbow, neck
    (0.00, 0.0, 0.0, 0.0, 0.0, 0.0, 4.0, 8.0, 0.0),
    (0.08, -2.0, 4.0, -3.0, 0.0, -6.0, 6.0, 12.0, -2.0),
    (0.27, -22.0, 62.0, -40.0, 0.0, -26.0, 10.0, 18.0, 10.0),   # the crouch: arms back (bottom 0.27)
    (STEP_LAUNCH, -10.0, 8.0, -6.0, -22.0, 26.0, 14.0, 30.0, 6.0),   # spring: legs straight, toes pushing, arms swing up
    (0.50, -6.0, 58.0, -18.0, -25.0, 62.0, 16.0, 40.0, 0.0),   # tucking
    (STEP_TOP, -8.0, 78.0, -14.0, -20.0, 55.0, 18.0, 45.0, -4.0),    # tucked at the top
    (0.72, -6.0, 40.0, -14.0, -10.0, 30.0, 18.0, 35.0, -6.0),   # legs reaching down for the block
    (STEP_LAND, -6.0, 18.0, -10.0, 0.0, 18.0, 18.0, 30.0, -6.0),    # touch down
    (0.92, -16.0, 52.0, -32.0, 0.0, 10.0, 16.0, 28.0, 0.0),    # the squash
    (1.06, -4.0, 14.0, -9.0, 0.0, 2.0, 8.0, 14.0, 2.0),
    (STEP_LENGTH, 0.0, 0.0, 0.0, 0.0, 0.0, 4.0, 8.0, 0.0),
]
STEP_AIR = (STEP_LAUNCH, STEP_LAND)


def step_arc(t, h, fwd):
    """The game's root arc for the hop (Lua twin in the report): (up, forward) of the root from where it stood, onto a
    block `h` tall whose middle is `fwd` ahead. The root rises at once and only starts forward a fifth of the way into
    the air, so the tucked feet are above the block before they pass its front edge (start 0.9 in front of the face:
    clears 1.4 / 2.0 / 3.0 by 0.15+ in the pictures); it lands with no forward speed (the squash)."""
    if t <= STEP_LAUNCH:
        return 0.0, 0.0
    if t >= STEP_LAND:
        return h, fwd
    u = (t - STEP_LAUNCH) / (STEP_LAND - STEP_LAUNCH)
    a = 0.45 * h
    up = h * u + 4.0 * a * u * (1.0 - u)
    f = max(0.0, min(1.0, (u - 0.2) / 0.8))
    return up, fwd * f * f * (3.0 - 2.0 * f)


def step_params(t):
    keys = [(k[0], {"torso": k[1], "thigh": k[2], "shin": k[3], "pitch": k[4], "swing": k[5], "raise": k[6],
                    "elbow": k[7], "neck": k[8]}) for k in STEP_KEYS]
    a, b, u = F.at(keys, t)
    return {q: a[q] + (b[q] - a[q]) * u for q in a}


def step_clip():
    use(DEFAULT_JOINTS)
    global STAND_SOLE
    STAND_SOLE = 0.0
    w0 = S.forward_kinematics(S.T((0, HRP_Y, 0)), F._body(F.planted(dict(E.STAND, arm=dict(F.HANG))), Vector()))
    # (the block-rig feet the solver knows sit this far off the floor standing: kept, so standing is the root at 0, as
    #  in every other lifter clip; only pointed toes lift the body)
    STAND_SOLE = min(E.sole_low(w0, f) for f in ("LeftFoot", "RightFoot"))
    poses, info = {}, []
    def floor_root(p):
        """The root on the floor: the ankles where they stand (x, z), lifted so the lowest point of the soles is ON the
        floor (pointed toes: up on the toes, heels off it)."""
        q = {"torso": p["torso"], "thigh": p["thigh"], "shin": p["shin"], "toes": 12.0, "neck": p["neck"],
             "arm": dict(F.HANG)}
        planted = F.planted(q)
        pose = F._body(planted, planted["root"])
        for side in ("Left", "Right"):
            pose[side + "Ankle"] = pose[side + "Ankle"] @ S.rx(p["pitch"])
        w = S.forward_kinematics(S.T((0, HRP_Y, 0)), pose)
        low = min(E.sole_low(w, f) for f in ("LeftFoot", "RightFoot")) - STAND_SOLE
        return planted, planted["root"] + Vector((0, -low, 0))
    r_launch = floor_root(step_params(STEP_LAUNCH))[1]
    r_land = floor_root(step_params(STEP_LAND))[1]
    for t in times_for(STEP_LENGTH, fine=((0.0, STEP_LENGTH),)):
        p = step_params(t)
        planted, r_floor = floor_root(p)
        # in the air the root keeps its take-off height (eased to the landing's): the GAME lifts the root on its arc
        if STEP_LAUNCH < t < STEP_LAND:
            v = S.smooth((t - STEP_LAUNCH) / (STEP_LAND - STEP_LAUNCH))
            root = r_launch.lerp(r_land, v)
        else:
            root = r_floor
        pose = F._body(planted, root)
        for side in ("Left", "Right"):
            pose[side + "Ankle"] = pose[side + "Ankle"] @ S.rx(p["pitch"])
        arm = {"raise": p["raise"], "swing": p["swing"], "twist": 0.0, "elbow": p["elbow"]}
        pose.update(E.one_arm("Left", arm))
        pose.update(E.one_arm("Right", arm))
        w = S.forward_kinematics(S.T((0, HRP_Y, 0)), pose)
        low = min(E.sole_low(w, f) for f in ("LeftFoot", "RightFoot"))
        info.append((t, low, p["thigh"], p["shin"] - p["thigh"], root.y))
        poses[t] = pose
    return poses, info


# ---------------------------------------------------------------- export (meet_end_animations.export, parametrised)
def export(name, poses, hip=2.0, looped=False, joints=None):
    use(joints or DEFAULT_JOINTS)
    refs = iter(range(1, 1_000_000))
    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
           f'<Item class="KeyframeSequence" referent="RBX{next(refs)}"><Properties>'
           f'<float name="AuthoredHipHeight">{hip:g}</float><bool name="Loop">{"true" if looped else "false"}</bool>'
           f'<string name="Name">{name}</string><token name="Priority">2</token>'
           f'</Properties>']
    children = {}
    for joint, (parent, child, c0, c1) in S.JOINTS.items():
        children.setdefault(parent, []).append((child, joint))

    def pose_xml(part, transforms):
        joint = S.CHILD_JOINT.get(part)
        m = transforms.get(joint, I4) if joint else I4
        s = (f'<Item class="Pose" referent="RBX{next(refs)}"><Properties>'
             f'<CoordinateFrame name="CFrame">{S._cframe_xml(m)}</CoordinateFrame>'
             f'<token name="EasingDirection">0</token><token name="EasingStyle">0</token>'
             f'<string name="Name">{part}</string><float name="Weight">1</float></Properties>')
        for child, _ in children.get(part, []):
            s += pose_xml(child, transforms)
        return s + "</Item>"

    for t in sorted(poses):
        out.append(f'<Item class="Keyframe" referent="RBX{next(refs)}"><Properties>'
                   f'<string name="Name">Keyframe</string><float name="Time">{t:.3f}</float></Properties>')
        out.append(pose_xml("HumanoidRootPart", poses[t]))
        out.append("</Item>")
    out.append("</Item></roblox>")
    os.makedirs(S.OUT_DIR, exist_ok=True)
    path = os.path.join(S.OUT_DIR, name + ".rbxmx")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    return path, len(poses)


# Per lifter build, fitted by pairqa 2026-11-25 (D:/ClaudeScratch/ceremony/final_pair): (x, d) for
#   refRoot = lifterRoot * CFrame.new(x, 0, -d) * CFrame.Angles(0, math.pi, 0)
# Medal: the referee's hands (Grip) 0.03 off the lifter's outer clothes as the ribbon lands; Handshake: the two right
# palms' middles together, then the hand meshes just touching; Trophy: one spot (each build's clip reaches the cup).
PLACEMENT = {
    # (Medal, 2026-11-25 v7, held medal 1.5 apart: d = the largest of hands 0.03 off the chest as it lands, arms clear of
    #  the head, hands/forearms 0.6+ off the torso while letting go; D:/ClaudeScratch/ceremony/medal_v7)
    "Medal": {"Skinny": (0.0, 3.183), "SkinnyFat": (0.0, 3.183), "Fit": (0.0, 3.257), "Fat": (0.0, 3.322),
              "Muscular": (0.0, 3.339), "BigBuff": (0.0, 3.455)},
    "Handshake": {"Skinny": (0.166, 3.346), "SkinnyFat": (0.237, 3.388), "Fit": (0.353, 3.466),
                  "Fat": (0.467, 3.523), "Muscular": (0.516, 3.613), "BigBuff": (0.626, 3.681)},
    "Trophy": {b: (0.0, D_TROPHY) for b in LIFTERS},
}


def build_all(only=None):
    done = {}

    def want(n):
        return not only or any(o in n for o in only)
    ref_joints = joint_table(build_rest(REF_BUILD))
    if want("Medal"):
        p, w = medal_ref()
        done["Ceremony_Ref_PlaceMedal"] = export("Ceremony_Ref_PlaceMedal", p, joints=ref_joints) + (w,)
        p, w = medal_lifter()
        done["Ceremony_Lifter_ReceiveMedal"] = export("Ceremony_Lifter_ReceiveMedal", p) + (w,)
    if want("Handshake"):
        p, w = shake_clip("ref")
        done["Ceremony_Ref_Handshake"] = export("Ceremony_Ref_Handshake", p, joints=ref_joints) + (w,)
        p, w = shake_clip("lifter")
        done["Ceremony_Lifter_Handshake"] = export("Ceremony_Lifter_Handshake", p) + (w,)
    if want("Trophy"):
        p, w = trophy_ref()
        done["Ceremony_Ref_HandTrophy"] = export("Ceremony_Ref_HandTrophy", p, joints=ref_joints) + (w,)
        for b in LIFTERS:
            x, d = PLACEMENT["Trophy"][b]
            p, w = trophy_lifter(b, d, x)
            n = "Ceremony_Lifter_TakeTrophy_" + b
            done[n] = export(n, p, joints=joint_table(build_rest(b))) + (w,)
    if want("StepUp"):
        p, info = step_clip()
        done["Ceremony_Lifter_StepUp"] = export("Ceremony_Lifter_StepUp", p) + ({},)
        for t, low, thigh, knee, ry in info:
            if abs(t * 30 - round(t * 30)) < 1e-3 and round(t * 30) % 2 == 0:
                print("STEP t %.3f  sole_low %.3f  thigh %.1f  knee %.1f  root_y %.3f" % (t, low, thigh, knee, ry))
    use(DEFAULT_JOINTS)
    return done


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argv and argv[0] == "pairqa":
        _qspec = importlib.util.spec_from_file_location("ceremony_pairqa", os.path.join(_HERE, "ceremony_pairqa.py"))
        Q = importlib.util.module_from_spec(_qspec)
        _qspec.loader.exec_module(Q)
        Q.run(sys.modules[__name__] if __name__ in sys.modules else None, argv[1] if len(argv) > 1 else
              r"D:\ClaudeScratch\ceremony\pair")
    else:
        only = [v for v in os.environ.get("CER_ONLY", "").split(",") if v]
        for name, (path, n, worst) in build_all(only).items():
            print("EXPORTED %s keys %d worst %s" % (name, n, {k: round(v, 3) for k, v in worst.items()}))
        print("DONE")


# ---------------------------------------------------------------- notes (2026-11-25)
# anim_qa PASS (limits): ReceiveMedal, Lifter_Handshake, StepUp on all six builds (meet outfit worn); each
# TakeTrophy_<Build> on its own build; the three referee clips on Fat in tee/joggers/sneakers (QA_OUTFIT=Tee,Joggers,
# Sneakers). pairqa on all six lifter builds: no body inside the other at any measured keyframe; the referee's arms never
# inside the lifter's head or body (medal: nearest 0.04-0.26 to the head, 0.03 to the chest as it lands); handshake palms
# touching (<= 0.002 in); trophy: the lifter's palms on the cup (<= 0.013 off, <= 0.005 in), the referee's hands on the
# base until he lets go, never in it, nobody's hands touching.
# Elbows: referee <= 90 deg (medal, handshake), <= 85 (trophy); lifter handshake <= 91; TakeTrophy holds 84 (Skinny) ...
# 98 (BigBuff): holding a trophy ON the chest would fold these x1.5 arms ~115 deg (the user's crease note), so it is
# held a forearm's length out in front of the chest. Wrist bend <= 49 deg (the trophy referee's palm-up left hand also
# rolls ~100 deg at the wrist: a hand turned palm up under the base).
# Tried and dropped: hands set to fixed turns (wrists 110-150 deg: the hands now follow the forearm); the figures close
# together (elbows 110-135); the referee's right fist round the trophy's stem (letting go swept the opening fingers
# through the base, and the fist touched the big builds' hands); the lifter's fingers pointing up the cup's sides (read
# as clapping the cup); the head dipped while the medal was still rising (the hands met the head).
