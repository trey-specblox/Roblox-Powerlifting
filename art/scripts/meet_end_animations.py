# End-of-meet scene (2026-11-25): the lifter's coach walks up to the lifter's right, turned 36-45 deg toward him, and
# lands his near (LEFT) hand open and flat on the lifter's upper back by the right shoulder blade, fingers toward the
# spine. Fat (default), Benchamin and Sumo REACH with the arm close to its relaxed shape (elbow ~23-31 deg, the shoulder
# swinging the arm out and round behind the lifter, the coach about an arm's length off: the user's elbow note);
# Squatavious, short, stands close behind the shoulder and reaches UP to the mid back (elbow ~52 deg). Two small pats
# (lift and land), the hand rests while he talks (head turned to the lifter, small nods), then it comes away and hangs.
# His right hand hangs relaxed the whole time (no clipboard: the game hides it). The lifter gets no new animation.
#
# One clip per coach body (each solved on that body's own skeleton, so the arm bends the same way on every coach):
#   MeetEnd_Coach_BackPat              the gym coach's default staff body: the Fat build (MeetFigures.build "Coach"
#                                      without a look -> LifterBuild.BuildRules.Spotter = "Fat"; the Gym Owner keeps it)
#   MeetEnd_Coach_BackPat_Squatavious  short (shoulders 2.87 up): pats the MID back at his own reach, never the belt
#   MeetEnd_Coach_BackPat_Benchamin    the BigBuff skeleton (wide, splayed arms)
#   MeetEnd_Coach_BackPat_Sumo         long arms, high hips
# All 9.0 s, NOT looped, Action priority. Pats land at PATS; the hand rests to RELEASE[0]; hangs from RELEASE[1].
# (MeetCoachLook copies the platform coach's joints onto the chosen coach's copy each frame: the game plays the chosen
# coach's version on the platform coach and stands the platform coach where PLACEMENT says for that version.)
#
# HOW: the body is joint turns only (the Waist leans and turns toward the lifter, the Neck turns and nods; legs and root
# untouched, so the feet never move). The left arm is the approved exact two-bone solve (entrance_animations.ik_arm,
# the elbow pointed where it is told: down), on THIS body's joints (S.JOINTS swapped for the body's rest joints, from
# art/blender/CartoonBodies_05_Rigged.blend / CoachBodies_01_Rigged.blend), and in contact the hand is turned palm-to-
# back (S.hand_frame) and the arm solved again for the wrist (Hype._palm_solve's method).
#
# PLACEMENT (the game): the coach's root stands `side` to the lifter's right (+X of the lifter's root), `back` behind it
# (+Z), turned `yaw` degrees toward the lifter (about the vertical, from facing the same way), both on the floor:
#   coachRoot = lifterRoot * CFrame.new(side, 0, back) * CFrame.Angles(0, math.rad(yaw), 0)   (then HipHeight)
# measured per lifter build by `pairqa` on the real bodies (the lifter in the meet outfit, the coach in his own clothes):
# the palm ON the outer layer, the bodies a small gap apart, nothing ever inside the other.
#
#   blender -b --factory-startup --python art/scripts/meet_end_animations.py
#       writes art/animations/MeetEnd_Coach_BackPat*.rbxmx (all four)
#   blender -b art/blender/CartoonBodies_05_Rigged.blend --python art/scripts/meet_end_animations.py -- pairqa <out dir>
#       READ-ONLY: each version's coach with each lifter build; fits side/back/yaw, measures every keyframe, pictures.
#       env PAIR_VERSIONS=MeetEnd_Coach_BackPat,...  PAIR_LIFTERS=Skinny,...  PAIR_PICTURES=Skinny,Fat,BigBuff
# Check each coach on his own body with art/scripts/anim_qa.py. Publish with upload_animations.py (ask the user first).
import importlib.util
import math
import os
import sys

from mathutils import Matrix, Vector

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\Powerlifting Roblox\art\scripts"
ROOT = os.path.dirname(os.path.dirname(_HERE))
LENGTH = 9.0
PATS = (0.85, 1.20)            # the two pats land (seconds)
RELEASE = (8.00, 8.70)         # the hand leaves the back / hangs again
LIFTERS = ("Skinny", "SkinnyFat", "Fit", "Fat", "Muscular", "BigBuff")

# Rest joints (rig-local Roblox studs from the floor: x = the body's left is -x, y up, z back), from the rigs.
BODY_JOINTS = {
    "Fat": {"HumanoidRootNode": (0, 3.0, 0), "LowerTorso": (0, 2.0, 0), "UpperTorso": (0, 2.54, 0),
            "LeftUpperArm": (-1.0, 4.38, 0), "LeftLowerArm": (-1.42, 3.287, 0), "LeftHand": (-1.42, 2.148, 0),
            "LeftUpperLeg": (-0.5, 2.0, 0), "LeftLowerLeg": (-0.5, 1.0, 0), "LeftFoot": (-0.5, 0.252, 0),
            "Neck": (0, 4.7, 0)},
    "Benchamin": {"HumanoidRootNode": (0, 3.0, 0), "LowerTorso": (0, 2.0, 0), "UpperTorso": (0, 2.54, 0),
                  "LeftUpperArm": (-1.05, 4.38, 0), "LeftLowerArm": (-1.66, 3.287, 0), "LeftHand": (-1.66, 2.148, 0),
                  "LeftUpperLeg": (-0.5, 2.0, 0), "LeftLowerLeg": (-0.5, 1.0, 0), "LeftFoot": (-0.5, 0.252, 0),
                  "Neck": (0, 4.7, 0)},
    "Squatavious": {"HumanoidRootNode": (0, 2.192, 0), "LowerTorso": (0, 1.192, 0), "UpperTorso": (0, 1.582, 0),
                    "LeftUpperArm": (-1.06, 2.8701, 0), "LeftLowerArm": (-1.6112, 2.1701, 0),
                    "LeftHand": (-1.6112, 1.4701, 0), "LeftUpperLeg": (-0.5, 1.192, 0), "LeftLowerLeg": (-0.5, 0.672, 0),
                    "LeftFoot": (-0.5, 0.252, 0), "Neck": (0, 3.142, 0)},
    "Sumo": {"HumanoidRootNode": (0, 3.902, 0), "LowerTorso": (0, 2.902, 0), "UpperTorso": (0, 3.242, 0),
             "LeftUpperArm": (-0.8096, 4.3481, 0), "LeftLowerArm": (-1.1264, 2.9481, 0), "LeftHand": (-1.1264, 1.4981, 0),
             "LeftUpperLeg": (-0.5, 2.902, 0), "LeftLowerLeg": (-0.5, 1.352, 0), "LeftFoot": (-0.5, 0.252, 0),
             "Neck": (0, 4.602, 0)},
}

# The lifter's upper back where the palm goes (lifter's root frame, his root 3.0 up): by the right shoulder blade; its
# outward normal there (turned toward his right as the back rounds), the fingers' way along it (to the spine and up).
BACK_NORMAL = Vector((0.30, 0.03, 0.95)).normalized()
FINGERS = Vector((-0.9, 0.42, 0.0))
PALM_X = 0.40                  # (pairqa) the palm's middle this far right of the lifter's spine (Fit), scaled by each
#                                build's back width (UpperTorso half widths 0.71-1.20), so it sits on the shoulder blade
#                                of every build and the coach stands as close to a slim lifter as to a big one
BACK_HALF = {"Skinny": 0.71, "SkinnyFat": 0.79, "Fit": 0.91, "Fat": 1.10, "Muscular": 1.02, "BigBuff": 1.20}
NOMINAL_YAW = 42.0             # the yaw each clip's palm turn is written for (pairqa picks 38-45 per lifter build)

# Per version: the body, its hip height, the left hand's centre resting on the back from the LEFT SHOULDER JOINT in the
# coach's root frame (x left -, y up, z back +; the coach faces -z), and the elbow's pull (chest frame: down, a touch
# out). Written so the arm reads forward-down / elbow bent ~90 deg and pointing down / forearm forward, and the hand at
# the lifter's upper back (~4.0 up) - Squatavious's at the mid back (~3.6 up), his reach up from 2.87.
# (Scanned 2026-11-25, scan of hand spot x elbow pull x finger way: with the hand straight ahead of the shoulder the
# forearm points INTO the back and the wrist must turn 80-108 deg to lay the palm on it; with the hand ahead and to
# the left, the forearm runs diagonally across the back toward the spine and the wrist turns 40-60 deg, the least
# for these bodies. Squatavious reaches UP to the back: his upper arm comes forward level, elbow under the line,
# fingers up.)
# (2026-11-25, user on Sumo: "the arms are just bending unnaturally looking like the arm is getting pinched until it
# creases ... keep the arm's shape but just move it to pat the lifter's back") Fat, Benchamin and Sumo now REACH: the
# arm stays close to its relaxed shape (elbow bent `bend` deg from straight, ~30-35; it was 96-116 and creased on all
# three) and the shoulder swings it out to the coach's left and round behind the lifter; the coach stands about an
# arm's length off. "reach": (degrees left of his forward, degrees up) of the shoulder-to-hand line. A scan (hand way x
# yaw x finger way x elbow pull, the coach kept behind the lifter's shoulder line) gave the least wrist turn, 23-31 deg,
# with the arm out 55 deg left of forward and 10 deg down at yaw 40, fingers toward the spine. Squatavious keeps his bent
# reach UP (52 deg at rest, no crease: his short arm is thick).
VERSIONS = {
    "MeetEnd_Coach_BackPat": {"body": "Fat", "hip": 2.0, "reach": (55.0, -10.0), "bend": 34.0,
                              "pull": (-0.3, -1.0, 0.0), "fingers": (-1.0, 0.1, 0.0), "side": (85.0, -50.0)},
    "MeetEnd_Coach_BackPat_Benchamin": {"body": "Benchamin", "hip": 2.0, "reach": (55.0, -10.0), "bend": 34.0,
                                        "pull": (-0.3, -1.0, 0.0), "fingers": (-1.0, 0.1, 0.0), "side": (85.0, -50.0)},
    "MeetEnd_Coach_BackPat_Sumo": {"body": "Sumo", "hip": 2.902, "reach": (55.0, -10.0), "bend": 34.0,
                                   "pull": (-0.3, -1.0, 0.0), "fingers": (-1.0, 0.1, 0.0), "side": (85.0, -50.0)},
    "MeetEnd_Coach_BackPat_Squatavious": {"body": "Squatavious", "hip": 1.192, "on": (-0.55, 0.74, -1.12),
                                          "pull": (-0.3, -1.0, 0.15), "fingers": (-0.3, 0.95, 0.0),
                                          "mid": (-0.75, -0.75, -0.75)},
}

# Measured by pairqa 2026-11-25 (Squatavious: D:/ClaudeScratch/backpat/v2_final; the reaching Fat, Benchamin and Sumo,
# after the user's elbow note: D:/ClaudeScratch/backpat/v3_final): {version: {lifter build: (side, back, yaw)}}. On every
# pair: the palm's middle on the shoulder blade (0.31-0.52 right of the spine by build, 4.05-4.15 up; Squatavious
# 3.76-3.79 up), gap 0.012-0.019 to the outer layer, no sink, 1.5-13.7 deg off flat; no point of either body inside the
# other at any keyframe; the coach (but his left arm) 0.16-0.24 from the widest (BigBuff) lifter, 0.45-0.58 from the
# slimmest (Skinny: his narrow back leaves room); the hand passes at least 0.067 off the lifter on its way.
PLACEMENT = {
    "MeetEnd_Coach_BackPat": {
        "Skinny": (3.625, 0.003, 36), "SkinnyFat": (3.609, -0.188, 40), "Fit": (3.688, -0.089, 40),
        "Fat": (3.699, -0.305, 44), "Muscular": (3.674, -0.251, 44), "BigBuff": (3.748, -0.163, 44)},
    "MeetEnd_Coach_BackPat_Benchamin": {
        "Skinny": (3.747, 0.002, 36), "SkinnyFat": (3.729, -0.200, 40), "Fit": (3.812, -0.091, 40),
        "Fat": (3.822, -0.327, 44), "Muscular": (3.799, -0.268, 44), "BigBuff": (3.869, -0.178, 44)},
    "MeetEnd_Coach_BackPat_Squatavious": {
        "Skinny": (2.350, 0.315, 45), "SkinnyFat": (2.390, 0.360, 45), "Fit": (2.462, 0.457, 45),
        "Fat": (2.540, 0.470, 45), "Muscular": (2.530, 0.736, 38), "BigBuff": (2.609, 0.809, 38)},
    "MeetEnd_Coach_BackPat_Sumo": {
        "Skinny": (4.012, 0.102, 36), "SkinnyFat": (4.004, -0.111, 40), "Fit": (4.079, -0.046, 40),
        "Fat": (4.097, -0.250, 44), "Muscular": (4.064, -0.231, 44), "BigBuff": (4.144, -0.147, 44)},
}


def _rot_y(v, deg):
    a = math.radians(deg)
    return Vector((v.x * math.cos(a) + v.z * math.sin(a), v.y, -v.x * math.sin(a) + v.z * math.cos(a)))


# ---------------------------------------------------------------- the clips
def build():
    _espec = importlib.util.spec_from_file_location("entrance_animations", os.path.join(_HERE, "entrance_animations.py"))
    E = importlib.util.module_from_spec(_espec)
    _espec.loader.exec_module(E)
    F, S = E.F, E.S
    I4 = Matrix.Identity(4)
    original = dict(S.JOINTS)

    def use_body(body):
        """S.JOINTS = this body's rest joints, each part's frame at its own joint (the hand's at its centre, 0.125 under
        the wrist, as anim_qa and the game's hand centre): S.forward_kinematics and ik_arm then pose THIS body."""
        j = {k: Vector(v) for k, v in BODY_JOINTS[body].items()}
        for side, sx in (("Left", 1), ("Right", -1)):
            for part in ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot"):
                v = j["Left" + part]
                j[side + part] = Vector((v.x * sx, v.y, v.z))
        z = lambda a, b: tuple(j[a] - j[b])
        table = {
            "Root": ("HumanoidRootPart", "LowerTorso", z("LowerTorso", "HumanoidRootNode"), (0, 0, 0)),
            "Waist": ("LowerTorso", "UpperTorso", z("UpperTorso", "LowerTorso"), (0, 0, 0)),
            "Neck": ("UpperTorso", "Head", z("Neck", "UpperTorso"), (0, 0, 0)),
        }
        for side in ("Left", "Right"):
            table[side + "Shoulder"] = ("UpperTorso", side + "UpperArm", z(side + "UpperArm", "UpperTorso"), (0, 0, 0))
            table[side + "Elbow"] = (side + "UpperArm", side + "LowerArm", z(side + "LowerArm", side + "UpperArm"), (0, 0, 0))
            table[side + "Wrist"] = (side + "LowerArm", side + "Hand", z(side + "Hand", side + "LowerArm"), (0, 0.125, 0))
            table[side + "Hip"] = ("LowerTorso", side + "UpperLeg", z(side + "UpperLeg", "LowerTorso"), (0, 0, 0))
            table[side + "Knee"] = (side + "UpperLeg", side + "LowerLeg", z(side + "LowerLeg", side + "UpperLeg"), (0, 0, 0))
            table[side + "Ankle"] = (side + "LowerLeg", side + "Foot", z(side + "Foot", side + "LowerLeg"), (0, 0, 0))
        S.JOINTS.clear()
        S.JOINTS.update(table)
        return j

    def track(keys, t):
        a, b, u = F.at(keys, t)
        return a + (b - a) * u if not isinstance(a, Vector) else a.lerp(b, u)

    def bump(t, centre, half):
        u = (t - centre) / half
        return 0.0 if abs(u) >= 1.0 else 0.5 * (1.0 + math.cos(math.pi * u))

    NODS = (2.25, 3.15, 4.4, 5.55, 6.3, 7.15)
    HANG = F.HANG
    RIGHT_HANG = {"raise": 7.0, "swing": 2.0, "twist": 0.0, "elbow": 10.0}   # (relaxed, a hair off his side)

    def body_at(t):
        lean = track([(0.0, 0.0), (0.12, 0.0), (0.75, -4.0), (RELEASE[0], -4.0), (8.8, 0.0), (LENGTH, 0.0)], t)
        turn = track([(0.0, 0.0), (0.12, 0.0), (0.75, 6.0), (RELEASE[0], 6.0), (8.8, 0.0), (LENGTH, 0.0)], t)
        yaw = track([(0.0, 0.0), (0.12, 0.0), (0.72, 18.0), (RELEASE[0], 18.0), (8.75, 0.0), (LENGTH, 0.0)], t)
        nod = -5.0 * sum(bump(t, c, 0.22) for c in NODS)
        return {"Waist": S.ry(turn) @ S.rx(lean), "Neck": S.ry(yaw) @ S.rx(nod - 2.0 * (yaw / 18.0))}

    clips = {}
    for name, spec in VERSIONS.items():
        j = use_body(spec["body"])
        root = j["HumanoidRootNode"]
        shoulder0 = j["LeftUpperArm"] - root
        rest = S.forward_kinematics(I4, E.one_arm("Left", HANG))
        hang = rest["LeftHand"].to_translation()
        reach = "reach" in spec
        upper = (j["LeftLowerArm"] - j["LeftUpperArm"]).length
        fore = (j["LeftHand"] - j["LeftLowerArm"]).length + 0.125

        def arm_dir(az, el):
            a_, e_ = math.radians(az), math.radians(el)
            return Vector((-math.sin(a_) * math.cos(e_), math.sin(e_), -math.cos(a_) * math.cos(e_)))
        if reach:
            reach_len = math.sqrt(upper * upper + fore * fore + 2 * upper * fore * math.cos(math.radians(spec["bend"])))
            on = shoulder0 + arm_dir(*spec["reach"]) * reach_len
        else:
            on = shoulder0 + Vector(spec["on"])
        n_c = _rot_y(BACK_NORMAL, -NOMINAL_YAW)                     # the back's normal, coach frame
        fingers_c = _rot_y(Vector(spec["fingers"]), -NOMINAL_YAW)
        pre = on + n_c * 0.2 + Vector((0, 0.04, 0))                 # just off the back, before landing / after leaving
        lift = n_c * 0.12 + Vector((0, 0.03, 0))                    # a pat: the hand lifts a little off the back
        settle = Vector((0, -0.025, 0))
        # on the way: the hand rises at his own left side, the arm out a little, elbow down (`mid`), behind the
        # lifter's right arm, then goes forward onto the back; the release the same way back. (The coach faces the
        # lifter, so "forward" from the hang, or in front of his own chest, ran the hand into the lifter's right arm,
        # 0.10-0.23 deep, pairqa 2026-11-25.)
        arm_len = (j["LeftLowerArm"] - j["LeftUpperArm"]).length + (j["LeftHand"] - j["LeftLowerArm"]).length + 0.125
        mid = shoulder0 + Vector(spec.get("mid", (0, 0, 0))) * (arm_len / 2.43)
        mid_back = mid + Vector((0.0, -0.06, 0.0))
        if reach:
            # the arm keeps its length (the elbow its gentle bend): every spot on the sphere round the shoulder, the
            # pats and the settle pivoting at the shoulder; on the way the arm swings out to his left side, low
            # (`side`), behind the lifter's right arm, then up and round onto the back
            def on_sphere(v):
                return shoulder0 + (v - shoulder0).normalized() * reach_len
            pre, lift_on, settled = on_sphere(pre), on_sphere(on + lift), on_sphere(on + settle)
            mid = shoulder0 + arm_dir(*spec["side"]) * reach_len
            mid_back = shoulder0 + arm_dir(spec["side"][0], spec["side"][1] - 6.0) * reach_len
            keys = [(0.0, hang), (0.12, hang), (0.38, mid), (0.64, pre), (PATS[0], on), (1.02, lift_on), (PATS[1], on),
                    (1.7, settled), (RELEASE[0], settled), (8.16, on_sphere(pre + settle)), (8.42, mid_back),
                    (RELEASE[1], hang), (LENGTH, hang)]
        else:
            keys = [(0.0, hang), (0.12, hang), (0.38, mid), (0.64, pre), (PATS[0], on), (1.02, on + lift), (PATS[1], on),
                    (1.7, on + settle), (RELEASE[0], on + settle), (8.16, pre + settle), (8.42, mid_back),
                    (RELEASE[1], hang), (LENGTH, hang)]

        def arc_track(t):
            """Between keys round the shoulder: the direction turned, the distance eased (a straight line between two
            spots at arm's length cuts inside the reach and folds the elbow on the way)."""
            if t <= keys[0][0]:
                return keys[0][1]
            for (t0, a_), (t1, b_) in zip(keys, keys[1:]):
                if t <= t1:
                    u = S.smooth((t - t0) / (t1 - t0))
                    da, db = a_ - shoulder0, b_ - shoulder0
                    d = da.normalized().slerp(db.normalized(), u) if da.angle(db) > 1e-4 else da.normalized()
                    return shoulder0 + d * (da.length + (db.length - da.length) * u)
            return keys[-1][1]
        el_hang, el_down = Vector((-0.3, -0.8, 0.6)), Vector(spec["pull"])   # (hanging: the bend back and down; close
        #  to the reach's pull, so swapping them does not spin the arm round: pop 1157 deg/s with (-0.2, -0.3, 1.0))
        # (the elbow stays pointing down until the hand is back at his side: easing it to the hang earlier turned the
        #  elbow back while the hand was still up, anim_qa elbow_back 0.77-0.95 and the hand into his own body)
        pulls = [(0.0, el_hang), (0.1, el_hang), (0.2, el_down), (8.48, el_down), (8.72, el_hang), (LENGTH, el_hang)]
        palm_w = [(0.0, 0.0), (0.3, 0.0), (0.62, 1.0), (8.18, 1.0), (8.45, 0.0), (LENGTH, 0.0)]
        hcw = S.hand_centre_from_wrist("Left")
        _p, _c, c0s, c1s = S.JOINTS["LeftShoulder"]
        _p, _c, c0e, c1e = S.JOINTS["LeftElbow"]

        def lower_of(body, a):
            ut = S.forward_kinematics(I4, body)["UpperTorso"]
            sh, el = S._arm_tf("Left", a)
            return ut @ S.T(c0s) @ sh @ S.T(c1s).inverted() @ S.T(c0e) @ el @ S.T(c1e).inverted()

        poses, prev, worst = {}, dict(HANG), {"miss": 0.0, "wrist": 0.0, "elbow": 0.0}
        t = 0.0
        times = []
        while t < LENGTH - 1e-6:
            times.append(round(t, 3))
            t += 0.05 if (t < 1.5 or RELEASE[0] - 0.1 <= t < RELEASE[1] + 0.1) else 0.1
        times.append(LENGTH)
        for t in times:
            body = body_at(t)
            target = arc_track(t) if reach else track(keys, t)
            pull = track(pulls, t)
            w = track(palm_w, t)
            a = E.ik_arm(body, target, pull, prev)
            wrist = I4
            if w > 0:
                free_rot = lower_of(body, a).to_3x3()
                want = S.hand_frame("Left", -n_c, fingers_c - (-n_c) * fingers_c.dot(-n_c))
                rot = free_rot.to_quaternion().slerp(want.to_quaternion(), w).to_matrix()
                a = E.ik_arm(body, target - rot @ hcw, pull, prev, wrist_point=True)
                wrist = (lower_of(body, a).to_3x3().transposed() @ rot).to_4x4()
                worst["wrist"] = max(worst["wrist"], math.degrees(wrist.to_quaternion().angle))
            prev = a
            pose = dict(body)
            pose.update(E.one_arm("Left", a))
            pose["LeftWrist"] = wrist
            right = E.one_arm("Right", RIGHT_HANG)
            pose["RightShoulder"], pose["RightElbow"] = right["RightShoulder"], right["RightElbow"]
            fk = S.forward_kinematics(I4, pose)
            worst["miss"] = max(worst["miss"], (fk["LeftHand"].to_translation() - target).length)
            worst["elbow"] = max(worst["elbow"], a["elbow"])
            poses[t] = pose
        clips[name] = (poses, spec, worst, {"on": on, "pre": pre, "mid": mid, "hang": hang})
    S.JOINTS.clear()
    S.JOINTS.update(original)
    return clips, S


def export(name, poses, hip, S):
    """Writes art/animations/<name>.rbxmx (Action priority, NOT looped)."""
    refs = iter(range(1, 1_000_000))
    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
           f'<Item class="KeyframeSequence" referent="RBX{next(refs)}"><Properties>'
           f'<float name="AuthoredHipHeight">{hip:g}</float><bool name="Loop">false</bool>'
           f'<string name="Name">{name}</string><token name="Priority">2</token>'
           f'</Properties>']
    children = {}
    for joint, (parent, child, c0, c1) in S.JOINTS.items():
        children.setdefault(parent, []).append((child, joint))

    def pose_xml(part, transforms):
        joint = S.CHILD_JOINT.get(part)
        m = transforms.get(joint, Matrix.Identity(4)) if joint else Matrix.Identity(4)
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


# ---------------------------------------------------------------- pair check on the real bodies (READ-ONLY)
def pair_qa(out_dir):
    import glob
    import bpy
    from mathutils.bvhtree import BVHTree

    os.makedirs(os.path.join(out_dir, "tiles"), exist_ok=True)
    G = {"__name__": "gear_fit_03"}
    exec(open(os.path.join(_HERE, "gear_fit_03.py"), encoding="utf-8").read(), G)
    TO_B = G["TO_B"]
    G["ANIMS"] = os.environ.get("PAIR_ANIMS", os.path.join(ROOT, "art", "animations"))
    versions = [v for v in os.environ.get("PAIR_VERSIONS", ",".join(VERSIONS)).split(",") if v]
    lifters = [b for b in os.environ.get("PAIR_LIFTERS", ",".join(LIFTERS)).split(",") if b]
    pictured = [b for b in os.environ.get("PAIR_PICTURES", "Skinny,Fat,BigBuff").split(",") if b]
    yaws = [float(y) for y in os.environ.get("PAIR_YAWS", "38,42,45").split(",")]
    OUTFIT = ("Tee", "WornSinglet_Black", "WornSinglet_Red", "WornSinglet_Shorts", "WornSinglet_Trim",
              "WornLeverBelt_Outer", "WornLeverBelt_Lining", "WornLeverBelt_Lever")
    BODY_PARTS = ["UpperTorso", "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
                  "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftFoot", "RightFoot",
                  "LeftHand", "RightHand", "StandInHead"]
    LEFT_ARM = ("LeftUpperArm", "LeftLowerArm")
    SWAPS = ("Fist", "Grip", "SquatGrip", "Point", "ThumbsUp")
    COACH_CLOTHES = ("Tee", "TeeWhite", "Joggers", "JoggersWhite", "Sneakers", "SneakersSole")

    def mat(name, rgba):
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.diffuse_color = rgba
        return m

    for o in bpy.data.objects:
        if o.type == "ARMATURE":
            o.location = (500, 500, 0)
        if o.parent is not None and any(s in o.name for s in SWAPS):
            o.hide_render = True

    def dress(rig, build, items, tint=None):
        before = set(bpy.data.objects)
        for kind in ("Clothes", "Gear"):
            found = sorted(glob.glob(os.path.join(ROOT, "art", "exports", "Cartoon%s[0-9][0-9]_%s.glb" % (kind, build))))
            if found:
                bpy.ops.import_scene.gltf(filepath=found[-1])
        kept = []
        ref = [c for c in rig.children if c.name.endswith("_UpperTorso")][0]
        rel = ref.matrix_parent_inverse @ ref.matrix_basis
        for o in [o for o in bpy.data.objects if o not in before]:
            item, _, _part = o.name.partition("__")
            if o.type == "MESH" and item in items:
                o.data.transform(rel.inverted() @ o.matrix_world)
                o.parent = rig
                o.matrix_parent_inverse = ref.matrix_parent_inverse.copy()
                o.matrix_basis = ref.matrix_basis.copy()
                for m in o.modifiers:
                    if m.type == "ARMATURE":
                        m.object = rig
                if tint:
                    o.data = o.data.copy()
                    o.data.materials.clear()
                    o.data.materials.append(tint)
                kept.append(o)
            else:
                bpy.data.objects.remove(o, do_unlink=True)
        xs = [v.co.x for o in kept if o.name.partition("__")[2].split(".")[0] == "UpperTorso" for v in o.data.vertices]
        if xs:
            body = [v.co.x for v in ref.data.vertices]
            shift = (min(body) + max(body)) / 2 - (min(xs) + max(xs)) / 2
            if abs(shift) > 0.5:
                for o in kept:
                    o.data.transform(Matrix.Translation(Vector((shift, 0, 0))))
        return kept

    coach_tee = mat("PairCoachTee", (0.05, 0.09, 0.28, 1))
    coach_skin = mat("PairCoachSkin", (0.42, 0.27, 0.18, 1))
    figures = {}

    def coach_figure(body):
        """(rig, parts {name: obj}, clothes [obj]) of the coach body, in his own clothes."""
        if body in figures:
            return figures[body]
        if body + "Rig" in bpy.data.objects and body not in BODY_JOINTS or body == "Fat":
            # the staff body: a second figure of the lifter build (the lifter's own may be on screen too)
            src = bpy.data.objects[body + "Rig"]
            rig = src.copy()
            rig.name = "Coach" + body + "Rig"
            bpy.context.scene.collection.objects.link(rig)
            parts = {}
            for c in src.children:
                if any(s in c.name for s in SWAPS):
                    continue
                n = c.copy()
                n.name = "Coach" + body + "_" + c.name.partition("_")[2]
                bpy.context.scene.collection.objects.link(n)
                n.parent = rig
                n.parent_type, n.parent_bone = c.parent_type, c.parent_bone
                n.matrix_parent_inverse = c.matrix_parent_inverse.copy()
                for m in n.modifiers:
                    if m.type == "ARMATURE":
                        m.object = rig
                parts[c.name.partition("_")[2]] = n
            clothes = dress(rig, body, ("Tee",), coach_tee)
        else:
            # a lift coach: his rig, body and own clothes (tee, joggers, sneakers) from CoachClothes_01.blend
            path = os.path.join(ROOT, "art", "blender", "CoachClothes_01.blend")
            with bpy.data.libraries.load(path) as (src_lib, dst_lib):
                dst_lib.objects = [n for n in src_lib.objects if n == body + "Rig" or (
                    n.startswith(body + "_") and not any(s in n for s in SWAPS) and
                    ("__" not in n or n.split("_", 1)[1].split("__")[0] in COACH_CLOTHES))]
            for o in dst_lib.objects:
                if o is not None:
                    bpy.context.scene.collection.objects.link(o)
            rig = bpy.data.objects[body + "Rig"]
            parts = {o.name.partition("_")[2]: o for o in dst_lib.objects if o and o.parent == rig and "__" not in o.name}
            clothes = [o for o in dst_lib.objects if o and "__" in o.name]
        for n in parts.values():
            if n.type == "MESH" and n.name.split("_", 1)[1] in ("LeftHand", "RightHand", "StandInHead",
                                                                "LeftLowerArm", "RightLowerArm"):
                n.data = n.data.copy()
                n.data.materials.clear()
                n.data.materials.append(coach_skin)
        figures[body] = (rig, parts, clothes)
        return figures[body]

    lifter_dressed = {}

    def lifter_figure(build):
        if build not in lifter_dressed:
            rig = bpy.data.objects[build + "Rig"]
            parts = {c.name.partition("_")[2]: c for c in rig.children if not any(s in c.name for s in SWAPS)}
            lifter_dressed[build] = (rig, parts, dress(rig, build, OUTFIT))
        return lifter_dressed[build]

    J = {}

    def joints(rig):
        if rig.name not in J:
            J[rig.name] = {b.name: TO_B @ b.head_local for b in rig.data.bones}
        return J[rig.name]

    def frames_of(rig, transforms):
        j = joints(rig)
        world = {"HumanoidRootNode": Matrix.Translation(j["HumanoidRootNode"])}
        for part in ["LowerTorso", "UpperTorso"] + [s + p for s in ("Left", "Right") for p in
                                                     ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")]:
            par = G["PARENT"][part]
            world[part] = world[par] @ Matrix.Translation(j[part] - j[par]) @ transforms.get(part, Matrix.Identity(4))
        return world

    def points(objs):
        dg = bpy.context.evaluated_depsgraph_get()
        verts, polys = [], []
        for o in objs:
            ev = o.evaluated_get(dg)
            me = ev.to_mesh()
            base = len(verts)
            verts += [o.matrix_world @ v.co for v in me.vertices]
            polys += [tuple(base + i for i in p.vertices) for p in me.polygons]
            ev.to_mesh_clear()
        return (BVHTree.FromPolygons(verts, polys) if polys else None), verts

    RAYS = [Vector(d).normalized() for d in ((0.31, 0.93, 0.19), (-0.27, -0.35, 0.9), (0.12, -0.95, -0.29))]

    def inside(p, tree):
        votes = 0
        for d in RAYS:
            o, n = p, 0
            for _ in range(24):
                hit = tree.ray_cast(o, d, 20.0)
                if hit[0] is None:
                    break
                n += 1
                o = hit[0] + d * 1e-4
            votes += n % 2
        return votes >= 2

    def clothes_out(p, skin, worn):
        """How far a point outside the skin is out from the OUTERMOST layer there (anim_qa's layer stacking); < 0 =
        inside the clothes."""
        loc, nrm, _i, d = skin.find_nearest(p, 3.0)
        if loc is None:
            return 9.0
        if worn is None:
            return d
        layer, q = 0.0, loc + nrm * 0.002
        for _ in range(8):
            hit = worn.ray_cast(q, nrm, 0.15 if layer == 0.0 else 0.08)
            if hit[0] is None:
                break
            layer = (hit[0] - loc).dot(nrm)
            q = hit[0] + nrm * 1e-4
            if layer > 0.35:
                break
        return d - layer

    def place(lifter_rig, coach_rig, side, back, yaw):
        lifter_rig.matrix_world = Matrix.Identity(4)
        coach_rig.matrix_world = (Matrix.Translation(TO_B.to_3x3() @ Vector((side, 0.0, back)))
                                  @ Matrix.Rotation(math.radians(yaw), 4, "Z"))

    def to_lifter(p):
        return TO_B @ p           # (the lifter rig stands at the origin)

    cache = {}

    def lifter_trees(lifter):
        key = lifter[0].name
        if key not in cache:
            l_rig, l_parts, l_worn = lifter
            bpy.context.view_layer.update()
            skin, skin_pts = points([l_parts[n] for n in BODY_PARTS if n in l_parts])
            worn, worn_pts = points([o for o in l_worn if o.name.partition("__")[2].split(".")[0] in
                                     ("UpperTorso", "LowerTorso")])
            cache[key] = (skin, worn, skin_pts + worn_pts)
        return cache[key]

    def measure(name, coach, lifter, t, full=True):
        c_rig, c_parts, c_clothes = coach
        G["pose_rig"](c_rig, G["anim_at"](name, t))
        bpy.context.view_layer.update()
        l_skin, l_out, l_pts = lifter_trees(lifter)
        _h, hand_pts = points([c_parts["LeftHand"]])
        gap, sink = 9.0, 0.0
        for p in hand_pts:
            if inside(p, l_skin):
                sink = max(sink, l_skin.find_nearest(p, 2.0)[3] + 0.07)
                continue
            out = clothes_out(p, l_skin, l_out)
            if out < 0:
                sink = max(sink, -out)
            else:
                gap = min(gap, out)
        res = {"gap": 0.0 if sink > 0 else gap, "sink": sink}
        w = frames_of(c_rig, G["anim_at"](name, t))
        palm = (c_rig.matrix_world.to_3x3() @ TO_B.to_3x3() @ (w["LeftHand"].to_3x3() @ Vector((1.0, 0.0, 0.0))))
        palm.normalize()
        hj = joints(c_rig)["LeftHand"]
        mid = c_rig.matrix_world @ (TO_B @ (w["LeftHand"] @ Vector((0, -0.3, 0))))
        loc, nrm, _i, _d = (l_out.find_nearest(mid, 3.0) if l_out else l_skin.find_nearest(mid, 3.0))
        res["tilt"] = math.degrees(palm.angle(-nrm)) if loc is not None else -1.0
        res["mid_on"] = to_lifter(loc) if loc is not None else None
        res["mid"] = mid
        if not full:
            return res
        # the bodies, judged on the outer clothes: the coach (but his left arm) and the lifter
        c_skin, _cs = points([c_parts[n] for n in BODY_PARTS if n in c_parts])
        c_body, _cb = points([c_parts[n] for n in BODY_PARTS if n in c_parts and n not in LEFT_ARM + ("LeftHand",)])
        torso_clothes = [o for o in c_clothes if o.name.partition("__")[2].split(".")[0] in ("UpperTorso", "LowerTorso")]
        c_out = points(torso_clothes)[0] if torso_clothes else None
        rest_objs = [c_parts[n] for n in BODY_PARTS if n in c_parts and n not in LEFT_ARM + ("LeftHand",)]
        rest_objs += [o for o in c_clothes if o.name.partition("__")[2].split(".")[0] not in LEFT_ARM]
        _r, rest_pts = points(rest_objs)
        arm_objs = [c_parts[n] for n in LEFT_ARM] + [o for o in c_clothes if o.name.partition("__")[2].split(".")[0]
                                                     in LEFT_ARM]
        _a, arm_pts = points(arm_objs)
        overlap, body_gap, arm_gap = 0.0, 9.0, 9.0
        for pts, is_arm in ((rest_pts[::2], False), (arm_pts, True)):
            for p in pts:
                h = l_skin.find_nearest(p, 0.8)
                if h[0] is None:
                    continue
                if inside(p, l_skin):
                    overlap = max(overlap, h[3] + 0.05)
                    continue
                out = clothes_out(p, l_skin, l_out)
                if out < 0:
                    overlap = max(overlap, -out)
                    out = 0.0
                if is_arm:
                    arm_gap = min(arm_gap, out)
                else:
                    body_gap = min(body_gap, out)
        for p in l_pts[::2]:
            h = c_skin.find_nearest(p, 0.6)
            if h[0] is None:
                continue
            if inside(p, c_skin):
                overlap = max(overlap, h[3] + 0.05)
            elif c_out is not None and clothes_out(p, c_skin, c_out) < 0:
                overlap = max(overlap, -clothes_out(p, c_skin, c_out))
            else:
                hb = c_body.find_nearest(p, 0.6)
                if hb[0] is not None:
                    body_gap = min(body_gap, clothes_out(p, c_body, c_out))
        res.update({"overlap": overlap, "body_gap": body_gap, "arm_gap": arm_gap})
        return res

    def fit(name, coach, lifter, yaw, t=4.0, want=0.012):
        """side, back for this yaw: the palm's middle at PALM_X (scaled) across the back, resting ON the outer layer."""
        palm_x = PALM_X * BACK_HALF.get(lifter[0].name[:-3], 0.91) / 0.91
        side, back = 2.5, 1.0
        place(lifter[0], coach[0], side, back, yaw)
        r = measure(name, coach, lifter, t, full=False)
        p = to_lifter(r["mid"])
        side += palm_x - p.x
        for _ in range(4):
            lo, hi = back - 1.2, back + 1.2
            for _ in range(16):
                m = (lo + hi) / 2
                place(lifter[0], coach[0], side, m, yaw)
                r = measure(name, coach, lifter, t, full=False)
                if r["sink"] > 0 or r["gap"] < want:
                    lo = m
                else:
                    hi = m
            back = hi
            place(lifter[0], coach[0], side, back, yaw)
            on = measure(name, coach, lifter, t, full=False)["mid_on"]
            if on is None or abs(on.x - palm_x) < 0.01:
                break
            side += palm_x - on.x
        return side, back

    report = ["# MeetEnd_Coach_BackPat pair check (meet_end_animations.py pairqa)\n\n",
              "Studs, degrees. Coach root `side` right of the lifter's root, `back` behind, turned `yaw` toward him. "
              "gap/sink: the coach's left hand on the lifter's outer layer; tilt: palm vs the back's normal (0 = flat); "
              "body_gap: the nearest the coach (not his left arm) comes to the lifter, outer clothes to outer clothes; "
              "arm_gap: the same for his left arm; overlap: deepest point of either body inside the other.\n\n"]
    placements = {}
    times = [t for t, _f in G["read_anim"](versions[0])]
    for name in versions:
        body = VERSIONS[name]["body"]
        coach = coach_figure(body)
        for f in list(figures.values()):
            f[0].location = (500, 500, 0)
        placements[name] = {}
        for lb in lifters:
            if os.environ.get("PAIR_USE_TABLE") and lb in PLACEMENT.get(name, {}):
                # (pictures only: the stored spot, no fitting or measuring)
                placements[name][lb] = tuple(PLACEMENT[name][lb]) + (None, {})
                continue
            lifter = lifter_figure(lb)
            for other in lifter_dressed.values():
                other[0].location = (500, 500, 0)
            tries = []
            for yaw in yaws:
                side, back = fit(name, coach, lifter, yaw)
                place(lifter[0], coach[0], side, back, yaw)
                r = measure(name, coach, lifter, 4.0, full=True)
                tries.append((yaw, side, back, r))
                print("[PairQA] %s/%s yaw %.0f side %.3f back %.3f body_gap %.3f arm_gap %.3f overlap %.3f tilt %.1f" % (
                    name, lb, yaw, side, back, r["body_gap"], r["arm_gap"], r["overlap"], r["tilt"]))
            ok = [x for x in tries if x[3]["overlap"] == 0 and x[3]["arm_gap"] >= 0.02 and 0.15 <= x[3]["body_gap"] <= 0.35]
            pick = min(ok or tries, key=lambda x: (abs(x[3]["body_gap"] - 0.25) + 0.01 * x[3]["tilt"]
                                                   + (0 if ok else 9 * x[3]["overlap"])))
            yaw, side, back, _r = pick
            place(lifter[0], coach[0], side, back, yaw)
            worst = {"sink_contact": (0.0, 0), "gap_contact": (0.0, 0), "tilt_contact": (0.0, 0), "overlap": (0.0, 0),
                     "body_gap_min": (9.0, 0), "body_gap_max_rest": (0.0, 0), "arm_gap_min": (9.0, 0),
                     "hand_path_min": (9.0, 0)}
            moments = {}
            for t in times:
                r = measure(name, coach, lifter, t, full=True)
                contact = PATS[0] - 0.01 <= t <= RELEASE[0] + 0.01 and (abs(t - PATS[0]) < 0.01 or t >= PATS[1] - 0.01)
                if contact:
                    for k, v in (("sink_contact", r["sink"]), ("gap_contact", r["gap"]), ("tilt_contact", r["tilt"])):
                        if v > worst[k][0]:
                            worst[k] = (v, t)
                    if r["body_gap"] > worst["body_gap_max_rest"][0]:
                        worst["body_gap_max_rest"] = (r["body_gap"], t)
                if r["overlap"] > worst["overlap"][0]:
                    worst["overlap"] = (r["overlap"], t)
                if r["body_gap"] < worst["body_gap_min"][0]:
                    worst["body_gap_min"] = (r["body_gap"], t)
                if r["arm_gap"] < worst["arm_gap_min"][0]:
                    worst["arm_gap_min"] = (r["arm_gap"], t)
                if (t < 0.62 or t > 8.2) and r["gap"] < worst["hand_path_min"][0]:
                    worst["hand_path_min"] = (r["gap"], t)
                if abs(t - 4.0) < 0.01 or any(abs(t - p) < 0.01 for p in PATS):
                    moments[t] = r
            on = moments[4.0]["mid_on"]
            placements[name][lb] = (round(side, 3), round(back, 3), yaw, on, worst)
            report.append("## %s (%s) with lifter %s: side %.3f, back %.3f, yaw %.0f\n\n" % (name, body, lb, side, back, yaw))
            report.append("palm middle on the back at 4.0 s (lifter root frame): (%.2f, %.2f, %.2f), %.2f up\n\n" % (
                on.x, on.y - 3.0, on.z, on.y))
            for t, r in sorted(moments.items()):
                report.append("- t %.2f: gap %.3f, sink %.3f, tilt %.1f, body_gap %.3f, arm_gap %.3f, overlap %.3f\n" % (
                    t, r["gap"], r["sink"], r["tilt"], r["body_gap"], r["arm_gap"], r["overlap"]))
            report.append("\nworst: " + ", ".join("%s %.3f (t %.2f)" % (k, v, tt) for k, (v, tt) in worst.items()) + "\n\n")
            print("[PairQA] RESULT %s/%s side %.3f back %.3f yaw %.0f palm (%.2f, %.2f up) worst %s" % (
                name, lb, side, back, yaw, on.x, on.y, {k: (round(v, 3), tt) for k, (v, tt) in worst.items()}))
    open(os.path.join(out_dir, "MeetEnd_pair_qa_%s.md" % "_".join(v.split("_")[-1] for v in versions)), "w",
         encoding="utf-8").write("".join(report))
    lua = ["-- (side, back, yaw) per lifter build, meet_end_animations.py pairqa\n"]
    for name, rows in placements.items():
        lua.append("%s = {\n" % name)
        for lb, (side, back, yaw, _on, _w) in rows.items():
            lua.append("\t%s = { side = %.3f, back = %.3f, yaw = %.0f },\n" % (lb, side, back, yaw))
        lua.append("},\n")
    open(os.path.join(out_dir, "placement_%s.lua" % "_".join(v.split("_")[-1] for v in versions)), "w",
         encoding="utf-8").write("".join(lua))
    print("".join(lua))

    # ---------------- pictures: each version with each pictured lifter, four moments, five views + hand close-ups
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_WORKBENCH"
    except TypeError as e:
        print("engine", e)
    sh = sc.display.shading
    sh.light, sh.color_type, sh.show_backface_culling, sh.show_cavity = "STUDIO", "MATERIAL", True, True
    sh.cavity_type = "WORLD"
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.16, 0.17, 0.2)
    sc.render.image_settings.file_format = "PNG"
    cd = bpy.data.cameras.new("PairCam")
    cd.type = "ORTHO"
    cd.clip_end = 300
    cam = bpy.data.objects.new("PairCam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    lc = bpy.data.curves.new("PairLabel", "FONT")
    label = bpy.data.objects.new("PairLabel", lc)
    label.data.materials.append(mat("PairLabelMat", (0.95, 0.95, 0.9, 1)))
    sc.collection.objects.link(label)
    label.parent = cam
    bpy.ops.mesh.primitive_cylinder_add(radius=40, depth=0.02, vertices=8)
    floor = bpy.context.active_object
    floor.location = (0, 0, -0.011)
    floor.data.materials.append(mat("PairFloor", (0.34, 0.35, 0.38, 1)))
    # (Blender: the lifter faces -Y, his right is -X, the coach stands at -X/+Y.) "game": the game's camera, in front
    # of the pair a little to the coach's side.
    VIEWS = {"game": (-0.55, -1.0, 0.22), "front": (0.0, -1.0, 0.12), "side": (-1.0, 0.0, 0.08),
             "back": (0.0, 1.0, 0.2), "backquarter": (-0.8, 0.9, 0.35)}
    ZOOMS = {"zoom_game": (-0.7, -0.6, 0.45), "zoom_back": (0.15, 1.0, 0.35), "zoom_top": (-0.1, 0.25, 1.0)}
    MOMENTS = [(0.45, "reach"), (PATS[0], "pat 1 lands"), (4.0, "resting, talking"), (8.35, "release")]

    def shoot(path, text, direction, target, scale, size):
        cd.ortho_scale = scale
        sc.render.resolution_x, sc.render.resolution_y = size
        cam.location = target + Vector(direction).normalized() * 60
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        lc.body = text
        lc.size = scale * 0.03
        label.location = (-scale / 2 + scale * 0.015, scale * size[1] / size[0] / 2 - lc.size * 1.35, -5)
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        return path

    for name in versions:
        coach = coach_figure(VERSIONS[name]["body"])
        for lb in [b for b in pictured if b in placements[name]]:
            lifter = lifter_figure(lb)
            for other in list(figures.values()) + list(lifter_dressed.values()):
                other[0].location = (500, 500, 0)
            side, back, yaw, _on, _w = placements[name][lb]
            place(lifter[0], coach[0], side, back, yaw)
            tiles, zooms = [], []
            centre = TO_B.to_3x3() @ Vector((side / 2, 0, back / 2))
            tag = name.replace("MeetEnd_Coach_BackPat", "BackPat") or "BackPat"
            for t, note in MOMENTS:
                G["pose_rig"](coach[0], G["anim_at"](name, t))
                bpy.context.view_layer.update()
                for v, d in VIEWS.items():
                    text = "%s (%s) + lifter %s  t %.2f %s  -  %s" % (tag, VERSIONS[name]["body"], lb, t, note, v)
                    tiles.append((None, None, shoot(os.path.join(out_dir, "tiles", "%s_%s_%.2f_%s.png" % (tag, lb, t, v)),
                                                    text, d, Vector((centre.x, centre.y, 3.0)), 7.0, (700, 700))))
                if t >= PATS[0] - 0.01 and t < 8.0:
                    r = measure(name, coach, lifter, t, full=False)
                    for v, d in ZOOMS.items():
                        text = "%s + %s t %.2f %s  %s  gap %.3f sink %.3f tilt %.0f" % (
                            tag, lb, t, note, v, r["gap"], r["sink"], r["tilt"])
                        zooms.append((None, None, shoot(os.path.join(out_dir, "tiles", "%s_%s_%.2f_%s.png" % (
                            tag, lb, t, v)), text, d, r["mid"], 2.6, (640, 640))))
            # the elbow at rest, close up (the user's check for a pinched, creased elbow), and its bend
            G["pose_rig"](coach[0], G["anim_at"](name, 4.0))
            bpy.context.view_layer.update()
            w = frames_of(coach[0], G["anim_at"](name, 4.0))
            ua, la = (w[k].to_3x3() @ Vector((0, -1, 0)) for k in ("LeftUpperArm", "LeftLowerArm"))
            bend = math.degrees(ua.angle(la))
            elbow = coach[0].matrix_world @ (TO_B @ w["LeftLowerArm"].to_translation())
            elbows = []
            for v, d in (("game", VIEWS["game"]), ("back", VIEWS["back"]), ("side", (-1.0, 0.3, 0.1))):
                text = "%s + %s t 4.00 resting  elbow %s  bend %.0f deg" % (tag, lb, v, bend)
                elbows.append((None, None, shoot(os.path.join(out_dir, "tiles", "%s_%s_elbow_%s.png" % (tag, lb, v)),
                                                 text, d, elbow, 2.0, (640, 640))))
            pe = os.path.join(out_dir, "%s_Lifter%s_ElbowZoom.png" % (tag, lb))
            G["contact_sheet"](elbows, pe, 3)
            print("[PairQA] ELBOW %s/%s resting bend %.1f deg -> %s" % (name, lb, bend, pe))
            p1 = os.path.join(out_dir, "%s_Lifter%s.png" % (tag, lb))
            G["contact_sheet"](tiles, p1, len(VIEWS))
            p2 = os.path.join(out_dir, "%s_Lifter%s_HandZoom.png" % (tag, lb))
            G["contact_sheet"](zooms, p2, len(ZOOMS))
            print("[PairQA] sheet", p1, p2)
    print("[PairQA] DONE (nothing saved)")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argv and argv[0] == "pairqa":
        pair_qa(argv[1] if len(argv) > 1 else r"D:\ClaudeScratch\backpat\pair")
    else:
        clips, S = build()
        only = [v for v in os.environ.get("BACKPAT_ONLY", "").split(",") if v]
        for name, (poses, spec, worst, keys) in clips.items():
            if only and name not in only:
                continue
            print("EXPORTED", export(name, poses, spec["hip"], S), "worst", {k: round(v, 3) for k, v in worst.items()},
                  "on", tuple(round(c, 3) for c in keys["on"]))
        print("DONE")


# ---------------------------------------------------------------- notes (2026-11-25)
# anim_qa PASS (limits): MeetEnd_Coach_BackPat on Skinny, SkinnyFat, Fit, Fat, Muscular, BigBuff (meet outfit worn);
# each coach version on its own body (CoachBodies_01_Rigged.blend, QA_OUTFIT=none). Squatavious's name contains "Squat",
# which makes anim_qa draw a bar and use the squat exceptions: run it with QA_BAR=none and
# QA_FAIL_LIMITS="elbow_back=0.75;elbow_back_raised=0.4" (the normal limits; it passes them).
# The wrist turns 39-64 deg in contact (the palm laid on a back that faces the coach at ~40 deg): the least found by a
# scan of hand spot x elbow pull x finger way; anim_qa has no wrist limit; lock_hand's soft limit is 60.
# Rejected on the way: the hand straight ahead of the shoulder (wrist 80-108 deg); the hand coming up in front of the
# coach's chest (it ran into the lifter's right arm: the coach faces the lifter); the elbow pull eased back to the hang
# while the hand was still up (elbow 0.77-0.95 behind the shoulder); the reach waypoint close to the shoulder (elbow
# folded to 140-150, Squatavious's forearm into his own arm).
# (Later 2026-11-25, the user's elbow note) Fat, Benchamin and Sumo re-made as REACHES: resting elbow bend 31 / 23 / 31
# deg (was 97 / 97 / 116, creased); the coach stands about an arm's length to the lifter's right, level with him or a
# touch ahead (back -0.33..+0.10), turned 36-44 deg in, the arm out and round behind the lifter; the bodies 0.55+ apart
# (the user chose the arm's shape over closeness). Wrist turn 22-30 deg. Squatavious unchanged (52 deg, no crease).
# PAIR_USE_TABLE=1 re-renders pictures from PLACEMENT without fitting; each sheet set now has an _ElbowZoom.
