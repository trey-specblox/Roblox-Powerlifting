# Meet fail animations (GAME_DESIGN.md §37.5 "The fail animations", 2026-11-02).
#
# Six missed lifts, one for each part of each lift (a lift's two parts are its two
# minigames), built on the same Roblox R15 block rig and tools as the station rep
# animations (station_animations.py, loaded below):
#   Fail_Squat_1     "Lost it on the way down": tips forward, stumbles onto hands and knees
#   Fail_Squat_2     "Stuck in the hole": drives up a little, grinds, sinks, sits down
#   Fail_Bench_1     "Crushed on the way down": the bar lands hard and pins, the legs kick
#   Fail_Bench_2     "Stalls on the press": a third of the way up, tilts, sinks back
#   Fail_Deadlift_1  "Won't break the floor": hips shoot up, the bar barely moves
#   Fail_Deadlift_2  "Can't lock out": strains above the knees, one hitch, drops the bar
# Each starts about where its part stops in the meet (the server cross-fades into
# it), ends with the lifter standing (bench: lying, relaxed), and lets go of the bar
# at FAILS[name]["release"] (the spotters take it; the deadlift is set down).
# Keep FAILS' lengths, releases and catches in step with StationAnimationConfig.Fails.
#
# Run inside Blender: preview_fails() shows all six beside the rack and a loaded
# bar; export_all() writes art/animations/Fail_<Lift>_<Part>.rbxmx (Action
# priority, not looped), to publish in Studio under the game's group.
import importlib.util, math, os
from mathutils import Matrix, Quaternion, Vector

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else \
    r"D:\Powerlifting Roblox\art\scripts"
_spec = importlib.util.spec_from_file_location("station_animations", os.path.join(_HERE, "station_animations.py"))
S = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(S)

SAMPLE_STEP = 0.05         # finer than the reps: the grinds tremble

# ---------------------------------------------------------------- key poses
# A key pose is a dict of parameters. "mode" says how the body meets the floor:
#   "planted"  feet where they stand (plant_feet), as in the reps
#   "ground"   explicit root offset (sitting, kneeling), solved when the key is made
# Between two planted keys the feet are re-planted every sample; otherwise the
# root offsets are blended.

def lerp(a, b, u):
    if isinstance(a, dict):
        return {k: lerp(a[k], b[k], u) for k in a}
    if isinstance(a, Quaternion):                 # a wrist: blended as a rotation (the short way round)
        return a.slerp(b if a.dot(b) >= 0 else -b, u)
    if isinstance(a, Vector):
        return a.lerp(b, u)
    return a + (b - a) * u

def tremble(t, t0, t1, amp, hz=6.0):
    """A shaking strain between t0 and t1, faded in and out."""
    if t <= t0 or t >= t1:
        return 0.0
    edge = min(1.0, (t - t0) / 0.25, (t1 - t) / 0.25)
    return amp * edge * math.sin(2 * math.pi * hz * (t - t0))

def at(keys, t):
    """(a, b, u): the two keys around t and how far between them (smoothed)."""
    if t <= keys[0][0]:
        return keys[0][1], keys[0][1], 0.0
    for (t0, a), (t1, b) in zip(keys, keys[1:]):
        if t <= t1:
            return a, b, S.smooth((t - t0) / (t1 - t0))
    return keys[-1][1], keys[-1][1], 0.0

# ---------------------------------------------------------------- standing bodies (squat, deadlift)
HANG = {"raise": 4.0, "swing": 0.0, "twist": 0.0, "elbow": 8.0}      # arms hanging loose
_STAND_ANKLE_X = S._left_ankle_x(S.squat_pose(0.0))

def _body(p, root=None):
    torso = p["torso"]
    pose = {"Root": (S.T(root) if root is not None else Matrix.Identity(4)) @ S.rx(torso), "Neck": S.rx(p["neck"])}
    pose.update(S.legs(torso, p["thigh"], p["shin"], p["stance"], p["toes"]))
    pose.update(S.arms(p["arm"]))
    if S.RIG == "torso" and p.get("sqgrip"):
        pose.update(S.squat_wrists(p["sqgrip"]))      # (torso rig: the hands turned onto the bar, easing off as they let go)
    add_wrists(pose, p.get("wrist"))
    return pose


# ---------------------------------------------------------------- free hands placed by the whole hand (2026-11-15)
# A key may carry "wrist": the LEFT wrist's turn (a Quaternion; the right is mirrored), blended as a rotation. Hands on
# the hips, on the knees or on the head are placed by the wrist joint and turned to lie ON the body (palm on the hip,
# the thigh, the crown) instead of pointing the fingers along the forearm into it (anim_qa arm_in_body, user rule 2).
NO_WRIST = Quaternion()


def wrists(q):
    """{LeftWrist, RightWrist} from the left wrist's turn q (the right mirrored: the y and z turns flip)."""
    return {"LeftWrist": q.to_matrix().to_4x4(), "RightWrist": Quaternion((q.w, q.x, -q.y, -q.z)).to_matrix().to_4x4()}


def add_wrists(pose, q):
    if q is None:
        return
    for j, m in wrists(q).items():
        pose[j] = pose.get(j, Matrix.Identity(4)) @ m


ARM_STARTS = [{"raise": 4.0, "swing": 0.0, "twist": 0.0, "elbow": 8.0},
              {"raise": 35.0, "swing": -15.0, "twist": -70.0, "elbow": 60.0},
              {"raise": 85.0, "swing": 0.0, "twist": 0.0, "elbow": 15.0},
              {"raise": 120.0, "swing": 10.0, "twist": -30.0, "elbow": 120.0},
              {"raise": 80.0, "swing": 10.0, "twist": -60.0, "elbow": 100.0},
              {"raise": 15.0, "swing": 40.0, "twist": 0.0, "elbow": 20.0}]


def solve_hand(body_pose, target, elbow_dir, wrist=NO_WRIST, at="wrist", starts=ARM_STARTS):
    """Left arm angles (the right mirrored) that put the wrist joint (at="wrist") or the hand's centre (at="hand") on
    `target` (root part's frame) with the wrist turned `wrist`, the elbow pointing toward elbow_dir (the chest's frame,
    measured off the shoulder-hand line, as celebration_rig.solve_arm does). Best of several starts (no local folds)."""
    wr = wrists(wrist)

    def cost(a):
        if not (-5 <= a["elbow"] <= 150):
            return 1e9
        p = dict(body_pose)
        p.update(S.arms(a))
        p.update(wr)
        w = S.forward_kinematics(Matrix.Identity(4), p)
        pt = S.joint_point(w, "LeftWrist") if at == "wrist" else w["LeftHand"].to_translation()
        c = 6.0 * (pt - target).length
        sh, el = S.joint_point(w, "LeftShoulder"), S.joint_point(w, "LeftElbow")
        line = pt - sh
        if a["elbow"] > 15 and line.length > 1e-6:
            u = line.normalized()
            off = (el - sh) - u * (el - sh).dot(u)
            pole = (w["UpperTorso"].to_3x3() @ Vector(elbow_dir)).normalized()
            if off.length > 1e-6:
                c += 1.5 * (1 - off.normalized().dot(pole))
        return c + 0.0015 * abs(a["twist"]) + 0.0004 * abs(a["raise"])
    best = None
    for start in starts:
        a, c = dict(start), cost(start)
        for step in (16, 8, 4, 2, 1, 0.5, 0.25):
            improved = True
            while improved:
                improved = False
                for k in S.ARM_KEYS:
                    for d in (step, -step):
                        b = dict(a)
                        b[k] += d
                        cb = cost(b)
                        if cb < c - 1e-7:
                            a, c, improved = b, cb, True
        if best is None or c < best[1]:
            best = (a, c)
    return best


def wrist_for(body_pose, arm, palm, fingers):
    """The left wrist's turn that lays the hand with its palm facing `palm` and its fingers pointing `fingers` (chest
    frame directions), the arm posed `arm` (the hand part: palm +X on the left hand, fingers -Y)."""
    p = dict(body_pose)
    p.update(S.arms(arm))
    w = S.forward_kinematics(Matrix.Identity(4), p)
    f = Vector(fingers).normalized()
    x = Vector(palm)
    x = (x - f * x.dot(f)).normalized()
    y = -f
    hand = Matrix((x, y, x.cross(y))).transposed()            # columns: the hand's +X, +Y, +Z in the chest frame
    return (w["LeftLowerArm"].to_3x3().inverted() @ w["UpperTorso"].to_3x3() @ hand).to_quaternion()

def _with_stance(p):
    """Opens the legs so the ankles stay as wide as when standing (squat_pose's bisection)."""
    lo, hi = 0.0, 45.0
    for _ in range(30):
        mid = (lo + hi) / 2
        q = dict(p, stance=mid)
        if S._left_ankle_x(_body(q)) > _STAND_ANKLE_X:
            lo = mid
        else:
            hi = mid
    return dict(p, stance=(lo + hi) / 2)

def planted(p):
    p = _with_stance(dict(p, mode="planted"))
    p["root"] = S.plant_feet(_body(p))["Root"].to_translation()
    return p

def sq(u, torso_add=0.0, arm=None, neck=None):
    """A squat key at depth u (0 standing, 1 the bottom; more is deeper), the bar on the back."""
    torso = S.blend(*S.SQUAT_TORSO, u) + torso_add
    return planted({"torso": torso, "thigh": S.blend(*S.SQUAT_THIGH, u), "shin": S.blend(*S.SQUAT_SHIN, u),
                    "toes": S.SQUAT_TOES_OUT, "arm": dict(arm or S.squat_arm()),
                    "neck": -torso * 0.55 if neck is None else neck, "sqgrip": 0.0 if arm else 1.0})

def grounded(p, joint, height, ankle_z=None, joint_z=None):
    """A floor key: the root offset that puts `joint` `height` above the floor and either the
    ankles at ankle_z or that joint at joint_z (root-frame z; the character faces -z)."""
    p = dict(p, mode="ground")
    w = S.forward_kinematics(S.T((0, S.HRP_STAND_Y, 0)), _body(p))
    j = S.joint_point(w, "Left" + joint)
    dz = 0.0
    if ankle_z is not None:
        dz = ankle_z - S.joint_point(w, "LeftAnkle").z
    elif joint_z is not None:
        dz = joint_z - j.z
    p["root"] = Vector((0, height - j.y, dz))
    return p

def sit_key(p, hip_height=0.55, ankle_height=0.25):
    """Sitting on the floor, knees up, feet flat where they stood: the thigh angle that puts the hips
    hip_height above the floor with the ankles ankle_height above it (bisection), then grounded."""
    lo, hi = 90.0, 170.0
    for _ in range(40):
        mid = (lo + hi) / 2
        w = S.forward_kinematics(S.T((0, S.HRP_STAND_Y, 0)), _body(dict(p, thigh=mid)))
        drop = S.joint_point(w, "LeftHip").y - S.joint_point(w, "LeftAnkle").y
        if drop > hip_height - ankle_height:    # hips still too high above the feet: knees further up
            lo = mid
        else:
            hi = mid
    return grounded(dict(p, thigh=(lo + hi) / 2), "Ankle", ankle_height, ankle_z=_STAND_ANKLE_Z)

def standing_body_pose(p):
    pose = {"Root": S.rx(p["torso"]), "Neck": S.rx(p["neck"])}
    pose.update(S.legs(p["torso"], p["thigh"], p["shin"], p["stance"], p["toes"]))
    return pose

# Hands on the hips (2026-11-15; the old hand target sank the fingers into every build's hips, arm_in_body 0.24-0.37):
# the wrist on the side of the hips 2.45 above the floor (the hanging wrist is at 2.15: the elbow bends out), the palm
# flat on the hip, fingers forward and a little down along the top of the hip, where the six CartoonBodies_05 builds
# are about equally wide (half widths 0.73-0.82 Skinny ... 1.03-1.08 Fat at 2.0-2.4), elbows out to the sides.
# (Tried 2026-11-15: fingers pointing further down dig into Skinny's thigh; measured arm_in_body Skinny 0.04, Fat 0.13.)
# (2026-11-16, clothes count as the body, rules 16-17: at 2.45 the wrist and forearm came up through the bottom edge of
#  the BELT, which sits at the navel ~0.22 out from the skin (anim_qa arm_in_outfit 0.11-0.25 on every build; seen by the
#  user on Fat). The hands now rest ON the belt's side: the wrist 2.75 up and 1.45 out, fitted to the widest belt (Fat,
#  BigBuff ~1.3 out there); the palm on it, fingers forward over its top edge; the elbows out to the sides and a touch
#  forward, never back (elbow_back 0.12 Skinny, was 0.48). One animation plays on every build, so the hands float a
#  little off Skinny's narrower belt, as the user chose: a float on Skinny, never sinking on Fat.)
HIP_WRIST = Vector((-1.45, 2.75 - S.HRP_STAND_Y, -0.05))
HIP_ELBOW = (-1.0, 0.1, -0.15)
HIP_PALM, HIP_FINGERS = (1.0, 0.0, 0.0), (0.0, -0.35, -0.94)
_HIPS_HOLD = {}


def hips_hold(p):
    """{"arm", "wrist"} resting the hands on the hips for an upright standing key (torso 0: the arms are solved in the
    chest's frame, so one answer serves every upright key)."""
    if not _HIPS_HOLD:
        body = standing_body_pose(dict(p, torso=0.0))
        a, _ = solve_hand(body, HIP_WRIST, HIP_ELBOW)
        _HIPS_HOLD.update(arm=a, wrist=wrist_for(body, a, HIP_PALM, HIP_FINGERS))
    return {"arm": dict(_HIPS_HOLD["arm"]), "wrist": _HIPS_HOLD["wrist"].copy()}


def hands_on_hips(p):
    """Arm angles of the hands-on-hips hold (use hips_hold: it also turns the wrists onto the hips)."""
    return hips_hold(p)["arm"]

def build_standing(p, root):
    return _body(p, root)

# ---------------------------------------------------------------- the squat fails
def _squat_1_keys():
    stand = sq(0.0, arm=HANG, neck=0.0)
    hips = dict(stand, **hips_hold(stand), neck=-22.0)
    hips = planted(hips)
    free = {"raise": 10.0, "swing": 55.0, "twist": 0.0, "elbow": 25.0}
    # On hands and knees, stumbled forward: knees on the floor ahead of where the feet were.
    kneel = {"torso": -62.0, "thigh": 12.0, "shin": -97.0, "stance": 8.0, "toes": 10.0, "arm": HANG, "neck": 12.0}
    # (Lengths along the legs and arms follow the taller rig, user 2026-11-12: S.LEG_SCALE, S.up_floor, S.reach.)
    knee_z = _STAND_ANKLE_Z - 0.9 * S.LEG_SCALE
    kneel = grounded(kneel, "Knee", 0.55, joint_z=knee_z)
    # Halfway down: knees bent, falling forward onto them (keeps the legs out of the floor on the way).
    falling = {"torso": -70.0, "thigh": 45.0, "shin": -70.0, "stance": 10.0, "toes": 15.0,
               "arm": {"raise": 10.0, "swing": 75.0, "twist": 0.0, "elbow": 10.0}, "neck": 20.0}
    falling = grounded(falling, "Knee", S.up_floor(0.95), joint_z=knee_z + 0.2)
    # Hands flat on the floor well in front of the knees.
    target = Vector((-1.3, -S.HRP_STAND_Y + 0.15, knee_z - S.reach(1.6)))
    kneel["arm"], _ = S.solve_arms(_body(kneel, kneel["root"]), target,
                                   {"raise": 12.0, "swing": 60.0, "twist": 0.0, "elbow": 6.0})
    kneel_down = dict(kneel, neck=-8.0)
    return [
        (0.0, sq(0.6)),
        (0.6, sq(0.95, torso_add=-24.0)),          # hips shoot back, chest tips forward
        (1.1, sq(1.0, torso_add=-44.0)),           # folding over, the bar rolling up the neck
        (1.45, falling),                           # the spotters have the bar; falling forward
        (1.8, kneel),                              # onto hands and knees
        (2.9, kneel_down),
        (3.7, sq(1.0, torso_add=-14.0, arm=free, neck=10.0)),   # back onto the feet
        (4.4, stand),
        (5.0, hips),
    ]

def _squat_2_keys():
    rest = {"raise": 12.0, "swing": 45.0, "twist": 0.0, "elbow": 30.0}   # hands loose by the knees
    sit = sit_key({"torso": 6.0, "shin": 12.0, "stance": 14.0, "toes": S.SQUAT_TOES_OUT, "arm": rest, "neck": -18.0})
    sit_low = dict(sit, neck=-30.0)
    stand = sq(0.0, arm=HANG, neck=-10.0)
    free = {"raise": 10.0, "swing": 60.0, "twist": 0.0, "elbow": 20.0}
    return [
        (0.0, sq(1.0)),
        (0.45, sq(0.86, torso_add=-8.0)),          # drives up a few centimetres, hips first
        (0.9, sq(0.84, torso_add=-10.0)),
        (2.0, sq(0.86, torso_add=-12.0)),          # grinding (tremble below)
        (2.6, sq(1.04, torso_add=-14.0)),          # sinks back; the spotters take the bar
        (3.1, sq(1.04, torso_add=-10.0, arm=rest)),
        (3.7, sit),                                # sits down on the platform
        (4.4, sit_low),
        (5.0, sq(1.0, torso_add=-18.0, arm=free, neck=10.0)),
        (5.6, stand),
    ]

_STAND_ANKLE_Z = S.STAND_ANKLES[0].z       # the ankles' z when standing (root frame)

# ---------------------------------------------------------------- the bench fails
def _bench_thigh():
    lo, hi = -90.0, 0.0
    for _ in range(40):
        mid = (lo + hi) / 2
        w = S.forward_kinematics(Matrix.Identity(4), S._bench_legs_at(mid))
        if S.joint_point(w, "LeftAnkle").z < S.BENCH_ANKLE_Z:
            hi = mid
        else:
            lo = mid
    return (lo + hi) / 2

_BENCH_CACHE = {}

def _bench():
    if not _BENCH_CACHE:
        _BENCH_CACHE["thigh"] = _bench_thigh()
        _BENCH_CACHE["table"] = S._bench_table()[1]
    return _BENCH_CACHE["thigh"], _BENCH_CACHE["table"]

RELAXED = {"raise": 18.0, "swing": 0.0, "twist": 0.0, "elbow": 25.0}      # arms down by the sides

def bk(ul, ur=None, kick_l=0.0, kick_r=0.0, relax=0.0, neck=0.0):
    return {"mode": "bench", "ul": ul, "ur": ul if ur is None else ur, "kl": kick_l, "kr": kick_r,
            "relax": relax, "neck": neck}

def build_bench(p, extra_u=0.0):
    thigh, table = _bench()
    pose = {"Neck": S.rx(p["neck"])}
    left = S._bench_legs_at(thigh + p["kl"])
    right = S._bench_legs_at(thigh + p["kr"])
    for k in ("LeftHip", "LeftKnee", "LeftAnkle"):
        pose[k] = left[k]
    for k in ("RightHip", "RightKnee", "RightAnkle"):
        pose[k] = right[k]
    def arm(u):
        a = S.lerp_angles(table, max(0.0, min(1.0, u + extra_u)))
        return lerp(a, RELAXED, p["relax"])
    al, ar = S.arms(arm(p["ul"])), S.arms(arm(p["ur"]))
    pose["LeftShoulder"], pose["LeftElbow"] = al["LeftShoulder"], al["LeftElbow"]
    pose["RightShoulder"], pose["RightElbow"] = ar["RightShoulder"], ar["RightElbow"]
    return pose

def _bench_1_keys():
    return [
        (0.0, bk(0.5)),
        (0.35, bk(1.0)),                           # crashes onto the chest
        (0.6, bk(0.97)),
        (1.0, bk(0.95, 1.0, kick_l=28.0)),         # pinned: pushing, the legs kick
        (1.4, bk(1.0, 0.95, kick_r=28.0)),
        (1.8, bk(0.97, 0.97, kick_l=18.0)),
        (2.2, bk(1.0)),                            # the spotters lift it off
        (2.9, bk(1.0, relax=1.0, neck=-6.0)),
        (4.4, bk(1.0, relax=1.0, neck=-10.0)),
    ]

def _bench_2_keys():
    return [
        (0.0, bk(1.0)),
        (0.6, bk(0.67, 0.65)),                     # a third of the way up
        (1.0, bk(0.74, 0.60)),                     # stalls and tilts: the left hand lower
        (1.8, bk(0.76, 0.62)),
        (2.5, bk(1.0)),                            # sinks back to the chest
        (2.8, bk(1.0)),                            # the spotters take it
        (3.4, bk(1.0, relax=1.0, neck=-6.0)),
        (4.4, bk(1.0, relax=1.0, neck=-10.0)),
    ]

# ---------------------------------------------------------------- the deadlift fails
_DL_CACHE = {}

def _dl_bottom():
    if not _DL_CACHE:
        _DL_CACHE["bottom"] = S._solve_deadlift_bottom()[0]
    return _DL_CACHE["bottom"]

def dl(u, torso_add=0.0, thigh_add=0.0, shin_add=0.0, held=True, arm=None, neck=None, wrist=None):
    """A deadlift key at depth u (0 lockout, 1 the bar on the floor)."""
    bottom = _dl_bottom()
    top = S.DEADLIFT_LOCKOUT if held else (0.0, 0.0, 0.0)
    torso, thigh, shin = (S.blend(top[i], bottom[i], u) for i in range(3))
    k = {"mode": "deadlift", "torso": torso + torso_add, "thigh": thigh + thigh_add, "shin": shin + shin_add,
         "held": held, "arm": arm, "neck": -(torso + torso_add) * 0.45 if neck is None else neck,
         "grip": 1.0 if held else 0.0, "u": u}
    if wrist is not None:
        k["wrist"] = wrist
    return k

# (2026-11-16, clothes count as the body) While the bar is held the arms hang a few degrees out from the sides near the
# top, as Station_Deadlift's do (station_animations.DEADLIFT_STATION_ARM_OUT, easing to 0 at the floor bar), so the
# hands stay outside the singlet shorts where they flare at the hip (Grinder_Deadlift_2 on Skinny: 0.06 into them at
# mid-thigh) and the fails start from the same arms the meet's pull ends in.
_ARM_OUT = getattr(S, "DEADLIFT_STATION_ARM_OUT", 0.0)
_ON_BAR_HAS_ARM_OUT = "arm_out" in __import__("inspect").signature(S._deadlift_on_bar_path).parameters


def build_deadlift(p):
    if p["held"]:
        if _ON_BAR_HAS_ARM_OUT and _ARM_OUT:
            out = _ARM_OUT * (1.0 - max(0.0, min(1.0, p.get("u", 1.0))))
            pose = S._deadlift_on_bar_path(p["torso"], p["thigh"], p["shin"], arm_out=out)
        else:
            pose = S._deadlift_on_bar_path(p["torso"], p["thigh"], p["shin"])
    else:
        pose = S._deadlift_body(p["torso"], p["thigh"], p["shin"])
        if p["arm"] is not None:
            pose.update(S.arms(p["arm"]))
        if S.RIG == "torso" and p.get("grip"):
            # (torso rig) the hands untwist out of the mixed grip while letting go, instead of snapping back
            pose.update(S.mixed_grip_wrists(p["grip"]))
        add_wrists(pose, p.get("wrist"))
    pose["Neck"] = S.rx(p["neck"])
    return pose

def dl_hips():
    """dl() keyword arguments for the hands-on-hips hold (arm and wrist)."""
    stand = {"torso": 0.0, "thigh": 0.0, "shin": 0.0, "stance": 0.0, "toes": S.DEADLIFT_TOES_OUT, "neck": 0.0}
    return hips_hold(stand)

def _dl_hips_arm():
    return dl_hips()["arm"]

def _deadlift_1_keys():
    b = _dl_bottom()
    # Starts with the bar on the floor (the meet's pull only rises with the typing; a pull that never got going
    # fails here). Hips shoot up: the knees straighten while the back stays bent, the bar barely leaves the floor.
    stuck = dl(0.95, torso_add=-6.0, thigh_add=-b[1] * 0.4, shin_add=-b[2] * 0.4)
    return [
        (0.0, dl(1.0)),
        (0.5, stuck),
        (2.0, stuck),                              # straining (tremble below)
        (2.5, dl(1.0)),                            # set down
        (3.3, dl(0.0, held=False)),                # lets go and stands
        (3.8, dl(0.0, held=False, **dl_hips(), neck=-20.0)),
        (4.8, dl(0.0, held=False, **dl_hips(), neck=-24.0)),
    ]

def _deadlift_2_keys():
    # Starts where the meet holds the pull through the lockout game: mid-thigh, above the knees, not locked
    # out (StationAnimationConfig.MeetStages Deadlift 2.2 s = depth 0.70; the bar about 0.5 above the knees).
    soft = dict(torso_add=-8.0, shin_add=-8.0)    # shoulders forward, knees soft
    return [
        (0.0, dl(0.70)),
        (0.5, dl(0.72, **soft)),                   # straining (tremble below)
        (1.0, dl(0.62, torso_add=-4.0, shin_add=-4.0)),   # one hitch toward lockout
        (1.3, dl(0.75, **soft)),                   # loses it
        (1.45, dl(0.76, **soft)),                  # and drops the bar
        (1.8, dl(0.76, held=False, neck=0.0, **soft)),
        (2.5, dl(0.0, held=False)),                # stands up
        (3.0, dl(0.0, held=False, **dl_hips(), neck=-20.0)),
        (3.8, dl(0.0, held=False, **dl_hips(), neck=-24.0)),
    ]

# ---------------------------------------------------------------- sampling
def _sample(keys, t, shake):
    a, b, u = at(keys, t)
    mode = a["mode"]
    if mode == "bench":
        return build_bench(lerp_params(a, b, u), shake)
    if mode == "deadlift":
        p = lerp_params(a, b, u)
        p["torso"] += shake
        return build_deadlift(p)
    p = lerp_params(a, b, u)
    p["torso"] += shake
    if a["mode"] == "planted" and b["mode"] == "planted":
        p["root"] = None
        return S.plant_feet(build_standing(p, None))
    return build_standing(p, p["root"])

HANG_FREE_RAISE = 7.0               # a free arm hanging (deadlift fails after the release): out from the thigh
GRIP_KEYS = ("grip", "sqgrip")      # (torso rig) how far the hands are turned onto the bar: a key without one has let go


def lerp_params(a, b, u):
    out = dict(a)
    for k in GRIP_KEYS:
        if k in b and k not in a:
            out[k] = lerp(0.0, b[k], u)
    if a.get("wrist") is not None or b.get("wrist") is not None:     # (a key without a wrist turn: the hand straight)
        wa, wb = a.get("wrist"), b.get("wrist")
        out["wrist"] = lerp(NO_WRIST if wa is None else wa, NO_WRIST if wb is None else wb, u)
    for k, v in a.items():
        if k in ("mode", "held", "wrist"):
            continue
        w = b.get(k, 0.0 if k in GRIP_KEYS else v)
        if v is None or w is None:
            out[k] = v if u < 0.5 else w
        else:
            out[k] = lerp(v, w, u)
    if "held" in a:
        # Once either key lets go of the bar, the arms are free: a key without its own arms hangs them
        # straight down (as _deadlift_body does), so the arms blend instead of jumping.
        out["held"] = a["held"] and b["held"]
        if not out["held"]:
            # (2026-11-16: raise 0 -> 7: hanging dead straight, the hands brushed 0.07-0.10 into Skinny's singlet
            #  shorts as he stood up from the bar, anim_qa arm_in_outfit; now they hang a hair out from the thighs)
            def arm_of(p):
                return p["arm"] if p["arm"] is not None else {"raise": HANG_FREE_RAISE, "swing": -p["torso"],
                                                              "twist": 0.0, "elbow": 0.0}
            out["arm"] = lerp(arm_of(a), arm_of(b), u)
    return out

def _shake(name, t):
    if name == "Squat_1":
        return tremble(t, 0.4, 1.2, 1.5)
    if name == "Squat_2":
        return tremble(t, 0.5, 2.2, 1.4)
    if name == "Bench_1":
        return tremble(t, 0.5, 2.2, 0.02, 7.0)
    if name == "Bench_2":
        return tremble(t, 0.7, 2.2, 0.025, 7.0)
    if name == "Deadlift_1":
        return tremble(t, 0.4, 2.2, 1.6)
    if name == "Deadlift_2":
        return tremble(t, 0.2, 1.4, 1.3)
    return 0.0

# release: when the bar leaves the hands (the spotters take it, or it is set down).
# catch: when the spotters get their hands on the bar (none for the deadlift).
FAILS = {
    "Squat_1": {"keys": _squat_1_keys, "length": 5.0, "release": 1.3, "catch": 0.9, "lift": "Squat"},
    "Squat_2": {"keys": _squat_2_keys, "length": 5.6, "release": 2.6, "catch": 2.1, "lift": "Squat"},
    "Bench_1": {"keys": _bench_1_keys, "length": 4.4, "release": 2.2, "catch": 1.5, "lift": "Bench"},
    "Bench_2": {"keys": _bench_2_keys, "length": 4.4, "release": 2.8, "catch": 2.2, "lift": "Bench"},
    "Deadlift_1": {"keys": _deadlift_1_keys, "length": 4.8, "release": 2.55, "catch": None, "lift": "Deadlift"},
    "Deadlift_2": {"keys": _deadlift_2_keys, "length": 3.8, "release": 1.45, "catch": None, "lift": "Deadlift"},
}
_KEYS = {}

def pose_of(name):
    def pose(t):
        if name not in _KEYS:
            _KEYS[name] = FAILS[name]["keys"]()
        return _sample(_KEYS[name], t, _shake(name, t))
    return pose

def held_of(name):
    release = FAILS[name]["release"]
    return lambda t: t < release

# ---------------------------------------------------------------- export and preview
def export(name):
    """Writes art/animations/Fail_<name>.rbxmx (Action priority, not looped)."""
    fail = FAILS[name]
    pose = pose_of(name)
    refs = iter(range(1, 1_000_000))
    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
           f'<Item class="KeyframeSequence" referent="RBX{next(refs)}"><Properties>'
           f'<float name="AuthoredHipHeight">{S.AUTHORED_HIP_HEIGHT:g}</float><bool name="Loop">false</bool>'
           f'<string name="Name">Fail_{name}</string><token name="Priority">2</token>'
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

    steps = int(round(fail["length"] / SAMPLE_STEP))
    for i in range(steps + 1):
        t = i * SAMPLE_STEP
        out.append(f'<Item class="Keyframe" referent="RBX{next(refs)}"><Properties>'
                   f'<string name="Name">Keyframe</string><float name="Time">{t:.3f}</float></Properties>')
        out.append(pose_xml("HumanoidRootPart", pose(t)))
        out.append("</Item>")
    out.append("</Item></roblox>")
    os.makedirs(S.OUT_DIR, exist_ok=True)
    path = os.path.join(S.OUT_DIR, f"Fail_{name}.rbxmx")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    return path, steps + 1

def export_all():
    return [export(name) for name in FAILS]

# Where the meet puts the lifter (MeetLiftAnimation): the squat after the walk-out (rack-local z -1.6).
_FAIL_BASES = {
    "Squat": S.T((0, S.HRP_STAND_Y, -1.6)) @ S.FACE_RACK,
    "Bench": S.PREVIEW_BASES["Bench"],
    "Deadlift": S.PREVIEW_BASES["Deadlift"],
}

def register():
    """Adds the fails to station_animations' tables, so its preview tools can show them."""
    for name, fail in FAILS.items():
        S.ANIMATIONS[name] = {"length": fail["length"], "pose": pose_of(name), "held": held_of(name)}
        S.PREVIEW_BASES[name] = _FAIL_BASES[fail["lift"]]
        S.PREVIEW_BAR_REST[name] = S.PREVIEW_BAR_REST[fail["lift"]]

def preview_fails(names=tuple(FAILS)):
    register()
    S.preview_all(names)

def lowest_points(name, step=0.25):
    """(t, lowest foot/knee/hand/torso y above the floor) through the animation: a check that nothing sinks
    into the floor (y < 0) or floats where it should rest."""
    pose = pose_of(name)
    base = S.T((0, S.HRP_STAND_Y, 0)) if FAILS[name]["lift"] != "Bench" else S.PREVIEW_BASES["Bench"]
    rows = []
    t = 0.0
    while t <= FAILS[name]["length"] + 1e-6:
        w = S.forward_kinematics(base, pose(t))
        low = {}
        for part in ("LeftFoot", "LeftLowerLeg", "LeftHand", "LowerTorso", "Head"):
            sx, sy, sz = S.SIZES[part]
            m = w[part]
            ys = [(m @ Vector((x * sx / 2, y * sy / 2, z * sz / 2))).y for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
            low[part] = round(min(ys), 2)
        rows.append((round(t, 2), low))
        t += step
    return rows
