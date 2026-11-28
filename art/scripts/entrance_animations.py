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
#
# Six more, unlocked from the celebration NPC's spin (user 2026-11-11: "Make ~6 new ones" from the real walk-ups in
# References/Clip Study/Clip Study.md, "Walk-ups" and "Pre-lift rituals"):
#   Walk_ArmUp         a steady walk with one arm held straight up for noise
#   Walk_Airplane      arms out like wings, banking side to side
#   Walk_RaiseRoof     bouncy, both hands pumping overhead ("raise the roof")
#   Walk_CrowdLift     palms-up lifts toward the crowd every stride ("lift the crowd")
#   Walk_SuperHeavy    the super-heavyweight walk: a wide base, rocking, arms held off the body, the whole torso turning
#   Walk_WarCry        a low, leaning prowl with the arms swung back
#   Hype_OverheadClap  arms up wide, a clap overhead (a chalk puff), head back, arms flung out (the side-of-stage primer)
#   Hype_WingsV        arms out wide like wings, then up into a V with the head back (the "wings and V")
#   Hype_TrapSlap      slaps both traps twice, then a hard clap with a dip
#   Hype_CrowdLift     two big palms-up lifts of the crowd, then points at the bar
#   Hype_ChalkRitual   thigh slaps, an X arm swing across the chest, a clap overhead, the arms flung out
#   Hype_WarCrouch     a war crouch with the arms swung back, trembling, then explodes up roaring, arms up and out
#   Touch_GameFace   arms only, over the last steps of a Local or Regional walk-out: two quick chalky claps, then both
#                    hands tap the belt (user 2026-11-08: those walk-outs "too bland", but not flashy or long)
#
# (2026-11-16, user rules §5.0.16-17) every hype move and the game face keep both hands and the far half of each
# forearm OUTSIDE the worn meet outfit (tee, singlet, belt) on all six builds: Hype.outfit, measured from the game's
# own exports like anim_qa's arm_in_outfit. Contact (claps, belt, chest, traps) is fitted to the widest clothed build,
# so the slimmer builds' hands float a little off their clothes there (the user's choice).
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
import glob
import os
import sys

from mathutils import Euler, Matrix, Quaternion, Vector

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\Powerlifting Roblox\art\scripts"
_spec = importlib.util.spec_from_file_location("fail_animations", os.path.join(_HERE, "fail_animations.py"))
F = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(F)
S = F.S

rx, ry, rz, T = S.rx, S.ry, S.rz, S.T
TAU = 2 * math.pi
STAND_ANKLE_Y = S.STAND_ANKLES[0].y
# Hip joint to ankle joint on this rig (studs): 1.75 on the block rig, ~2.15 on the taller one (user 2026-11-12). It sets
# each walk's speed, so EntranceConfig's speeds must match the CHECK lines.
LEG_LENGTH = (S.JOINTS["LeftHip"][3][1] - S.JOINTS["LeftKnee"][2][1]) + (S.JOINTS["LeftKnee"][3][1] - S.JOINTS["LeftAnkle"][2][1])


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
        a = {"raise": w["arm_raise"], "swing": swing, "twist": w.get("arm_twist", 0.0),
             "elbow": w["elbow"] + w.get("elbow_pump", 0.0) * forward}
        if "arms" in w:
            # A gesture walk: its own arms (the walk's swing passed in), still held level against the lean.
            a = w["arms"](side, ph, a)
            a["swing"] = a["swing"] - pitch
        pose.update(one_arm(side, a))
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


def _arm_up(side, ph, a):
    if side == "Right":
        return {"raise": 150.0 + 4.0 * math.sin(TAU * ph), "swing": 18.0, "twist": 0.0, "elbow": 4.0}
    return a


def _airplane(side, ph, a):
    tilt = 12.0 * math.sin(TAU * ph)          # the wings bank with the stride: one up as the other goes down
    return {"raise": 86.0 + (tilt if side == "Left" else -tilt), "swing": 4.0, "twist": 0.0, "elbow": 6.0}


def _raise_roof(side, ph, a):
    push = 0.5 + 0.5 * math.sin(2 * TAU * ph)  # two pushes a stride, both hands together
    return {"raise": 125.0 + 30.0 * push, "swing": 10.0, "twist": 0.0, "elbow": 35.0 - 25.0 * push}


def _crowd_lift(side, ph, a):
    lift = 0.5 - 0.5 * math.cos(TAU * ph)     # one slow lift a stride, low in front up to overhead
    return {"raise": 38.0 + 10.0 * lift, "swing": 10.0 + 85.0 * lift, "twist": -20.0, "elbow": 30.0 - 15.0 * lift}


def _war_cry(side, ph, a):
    return {"raise": 20.0, "swing": -34.0 + 0.35 * a["swing"], "twist": 10.0, "elbow": 38.0}


WALKS.update({
    "ArmUp": {"period": 0.8, "thigh": 30.0, "swing_flex": 55.0, "stance_flex": 10.0, "toe_up": 10.0,
              "stance": 3.0, "toes": 10.0, "torso": 1.0, "sway": 2.0, "hip_turn": 4.0, "shoulder_turn": 5.0,
              "arm_swing": 26.0, "arm_raise": 10.0, "elbow": 15.0, "elbow_pump": 12.0, "neck": 8.0, "nod": 2.0,
              "arms": _arm_up},
    "Airplane": {"period": 0.8, "thigh": 29.0, "swing_flex": 55.0, "stance_flex": 10.0, "toe_up": 10.0,
                 "stance": 3.0, "toes": 10.0, "torso": 0.0, "sway": 9.0, "hip_turn": 3.0, "shoulder_turn": 3.0,
                 "arm_swing": 0.0, "arm_raise": 86.0, "elbow": 6.0, "neck": 6.0, "arms": _airplane},
    "RaiseRoof": {"period": 0.62, "thigh": 27.0, "swing_flex": 72.0, "stance_flex": 18.0, "toe_up": 12.0,
                  "stance": 2.5, "toes": 8.0, "torso": -3.0, "hip_turn": 4.0, "shoulder_turn": 4.0, "bounce": 0.12,
                  "arm_swing": 0.0, "arm_raise": 130.0, "elbow": 40.0, "neck": 10.0, "nod": 6.0,
                  "arms": _raise_roof},
    "CrowdLift": {"period": 0.78, "thigh": 29.0, "swing_flex": 55.0, "stance_flex": 12.0, "toe_up": 10.0,
                  "stance": 3.0, "toes": 10.0, "torso": 0.0, "sway": 3.0, "hip_turn": 3.0, "shoulder_turn": 3.0,
                  "arm_swing": 0.0, "arm_raise": 22.0, "elbow": 28.0, "neck": 10.0, "nod": 3.0,
                  "arms": _crowd_lift},
    # (user 2026-11-15: "the really heavy walk is too slow": was period 1.1, thigh 24, 2.59 studs/s, the slowest by far;
    #  now ~3.9, still wide and rocking)
    "SuperHeavy": {"period": 0.82, "thigh": 27.0, "swing_flex": 45.0, "stance_flex": 12.0, "toe_up": 5.0, "stamp": True,
                   "stance": 9.0, "toes": 18.0, "torso": -4.0, "lean_bob": 1.5, "sway": 8.0, "hip_turn": 2.0,
                   "shoulder_turn": 12.0, "arm_swing": 8.0, "arm_raise": 38.0, "arm_twist": 25.0, "elbow": 30.0,
                   "neck": -3.0},
    "WarCry": {"period": 0.95, "thigh": 30.0, "swing_flex": 50.0, "stance_flex": 22.0, "toe_up": 6.0,
               "stance": 4.0, "toes": 12.0, "torso": -18.0, "lean_bob": 3.0, "sway": 3.0, "hip_turn": 3.0,
               "shoulder_turn": 8.0, "arm_swing": 18.0, "arm_raise": 20.0, "elbow": 38.0, "neck": 14.0,
               "arms": _war_cry},
})
if S.RIG == "torso":
    # (2026-11-16, QA upper_in_head FAIL on the big builds: Muscular 0.12-0.13, BigBuff 0.18-0.19; their wider
    # shoulders and thicker upper arms met the head with the arm 150-155 degrees up beside it) the raised arms a little
    # less high and a touch forward, still held up for the crowd: ArmUp 150 -> 136-140 up, RaiseRoof's pushes 155 -> 140
    def _arm_up(side, ph, a):
        if side == "Right":
            return {"raise": 136.0 + 4.0 * math.sin(TAU * ph), "swing": 26.0, "twist": 0.0, "elbow": 4.0}
        return a

    def _raise_roof(side, ph, a):
        push = 0.5 + 0.5 * math.sin(2 * TAU * ph)
        return {"raise": 120.0 + 20.0 * push, "swing": 18.0, "twist": 0.0, "elbow": 35.0 - 25.0 * push}
    WALKS["ArmUp"]["arms"], WALKS["RaiseRoof"]["arms"] = _arm_up, _raise_roof
for _w in WALKS.values():
    _w["speed"] = round(stride_speed(_w), 2)


# ---------------------------------------------------------------- hype moves (standing on the spot, hands solved)
# Hand targets (the root part's frame) are written for the block rig and moved onto the taller rig (user 2026-11-12,
# lifter_heights.py): on_body keeps a hand on the body (only its height follows the body); held_out moves a hand held
# out at arm's length (to the side or overhead) out from the shoulder by how much further the arm reaches; reach_out
# stretches an arm reaching forward or back (its x kept). The hanging hand is an arm's length below the shoulder.
HANG_HAND = Vector((-1.5, S.up_body(0.763) - S.reach(1.488) - 0.125, 0.0))
SHOULDER = Vector((-1.0, 0.763, 0.0))         # the left shoulder joint on the block rig (root frame)
SHOULDER_NOW = Vector((-1.0, S.up_body(0.763), 0.0))
K = S.ARM_REACH_SCALE


def on_body(x, y, z):
    return S.hand_on_body(x, y, z)          # (kept within the arm's reach on the torso rig: S.within_arm)


def held_out(x, y, z, keep_x=False):
    v = SHOULDER_NOW + (Vector((-abs(x), y, z)) - SHOULDER) * K
    return Vector((x if keep_x else math.copysign(abs(v.x), x), v.y, v.z))


def reach_out(x, y, z):
    # (Height on the body, the forward reach x1.15: the shoulder-relative held_out rule made Hype_CrowdLift's arms
    # lag behind its fast high-to-low swing, worst hand miss 0.78.)
    return S.within_arm(Vector((x, y, z)), Vector((x, S.up_body(y), S.reach(z))))


def arc_mid(a, b, shoulder=SHOULDER_NOW):
    """Half way between two hand spots ON the arm's arc round the shoulder (a straight line between them cuts inside
    the arm's reach: the elbow folds and snaps open on the way). Left-hand spots, root frame."""
    u, v = a - shoulder, b - shoulder
    d = u.normalized() + v.normalized()
    if d.length < 1e-4:                       # (straight opposite: go round by the side)
        d = Vector((-1.0, 0.0, 0.0))
    return shoulder + d.normalized() * (u.length + v.length) / 2


# Elbow directions for Hype.elbows (left arm, chest frame; 2026-11-15, user rules §5.0.1 and 6)
EL_HANG = Vector((-0.2, -0.3, 1.0))      # a hanging or loosely bent arm's natural bend: the elbow back, forearm forward
EL_UNDER = Vector((-0.5, -1.0, 0.2))     # an arm out to the side: the elbow under it (the forearm can fold up)
EL_DB = Vector((-1.0, -0.25, 0.05))      # the open double biceps: the elbow out to the side, a touch down
EL_OUT = Vector((-1.0, 0.0, 0.15))       # arms raised up and out: the elbows out to the sides


STAND = {"torso": 0.0, "thigh": 0.0, "shin": 0.0, "toes": 12.0, "neck": 0.0}
SOLVE_STEPS = (4, 2, 1, 0.5, 0.25)
START_ARM = {"raise": 4.0, "swing": 0.0, "twist": 0.0, "elbow": 8.0}


def body_at(keys, t):
    a, b, u = F.at(keys, t)
    p = {k: a[k] + (b[k] - a[k]) * u for k in a}
    p["arm"] = F.HANG
    return F.planted(p)


def on_arm(body_keys, t, direction, frac=0.97):
    """(2026-11-15) A left-hand spot `frac` of the arm's length from the shoulder joint, along `direction` in the
    chest frame, on the body as `body_keys` pose it at time t (a sweep of a nearly straight arm while the body moves:
    spots written for the standing root fold the elbow as the shoulders drop or rise)."""
    p = body_at(body_keys, t)
    w = S.forward_kinematics(Matrix.Identity(4), F._body(p, p["root"]))
    arm = (HANG_HAND - SHOULDER_NOW).length
    return S.joint_point(w, "LeftShoulder") + w["UpperTorso"].to_3x3() @ Vector(direction).normalized() * (frac * arm)


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


def ik_arm(body, target, pull, prev, wrist_point=False):
    """(2026-11-15) The LEFT arm's angles putting its hand centre on `target` (root frame) with the elbow pointing
    toward `pull` (chest frame; hanging arms bend with the elbow back, +Z), exactly: a two-bone solve, so the elbow goes where it is told (never behind the body by a
    solver's whim) and the arm moves on the shortest turn from `prev` (no flips). Out of reach: the arm straight."""
    ut = S.forward_kinematics(Matrix.Identity(4), body)["UpperTorso"]
    _p, _c, c0s, c1s = S.JOINTS["LeftShoulder"]
    _p, _c, c0e, c1e = S.JOINTS["LeftElbow"]
    _p, _c, c0w, c1w = S.JOINTS["LeftWrist"]
    rot = ut.to_3x3()
    h = rot.transposed() @ (target - ut @ Vector(c0s))          # the hand from the shoulder joint, chest frame
    U = Vector(c0e) - Vector(c1s)                               # shoulder joint -> elbow joint (upper arm frame)
    l = ((Vector(c0w) - Vector(c1w)) - Vector(c1e)).length      # elbow joint -> hand centre (straight down the forearm)
    if wrist_point:                                             # (or to the wrist joint: `target` is where it goes)
        l = (Vector(c0w) - Vector(c1e)).length
    uy, ux = -U.y, U.x
    cos_e = (h.length_squared - ux * ux - uy * uy - l * l) / (2 * uy * l)
    e = math.degrees(math.acos(max(math.cos(math.radians(150.0)), min(1.0, cos_e))))
    er = math.radians(e)
    v = Vector((ux, -uy - l * math.cos(er), -l * math.sin(er)))   # shoulder -> hand at this bend (upper arm frame)
    a1 = v.normalized()
    # the side the elbow points to: the upper arm's back (+Z, the forearm folds forward), whatever the bend (the
    # elbow joint's own offset turns with the bend and would roll the arm as it bends and straightens)
    a2 = (Vector((0, 0, 1)) - a1 * a1.z).normalized()
    b1 = h.normalized()
    b2 = Vector(pull) - b1 * Vector(pull).dot(b1)
    b2 = b2.normalized() if b2.length > 1e-6 else a2
    A = Matrix((a1, a2, a1.cross(a2))).transposed()
    B = Matrix((b1, b2, b1.cross(b2))).transposed()
    rs = B @ A.transposed()
    compat = Euler((math.radians(prev["swing"]), math.radians(prev["twist"]), math.radians(-prev["raise"])), "YXZ")
    eu = rs.to_euler("YXZ", compat)
    return {"raise": -math.degrees(eu.z), "swing": math.degrees(eu.x), "twist": math.degrees(eu.y), "elbow": e}


# ---------------------------------------------------------------- the worn outfit as part of the body (opt-in)
# (2026-11-16, user rules §5.0.16-17: clothes and gear count as the body for clipping; contact moves are fitted to the
# WIDEST clothed build, a small float on Skinny accepted.) anim_qa.py wears the game's meet outfit (tee, singlet, belt)
# on every build and fails a hand or the forearm's far half sinking into it (arm_in_outfit). The same test, inside the
# solver: each build posed with its OWN joints (art/exports/CartoonExport05.json: shoulders 0.8-1.05 out, the rest arm
# splayed per build, as the game and anim_qa pose it), its skin (art/data/body_surface_05.json) and how far the outfit
# stands off that skin at each skin point, measured straight from the game's exports (art/exports
# CartoonClothes05_<Build>.glb, CartoonGear05_<Build>.glb, the pieces anim_qa wears) with anim_qa's own layer-stacking
# rule, so a re-fitted singlet or belt is picked up on the next build.
OUTFIT_ITEMS = ("Tee", "WornSinglet_Black", "WornSinglet_Red", "WornSinglet_Shorts", "WornSinglet_Trim",
                "WornLeverBelt_Outer", "WornLeverBelt_Lining", "WornLeverBelt_Lever")
OUTFIT_PARTS = ("UpperTorso", "LowerTorso", "LeftUpperLeg", "RightUpperLeg")
OUTFIT_BUILDS = ("Skinny", "SkinnyFat", "Fit", "Fat", "Muscular", "BigBuff")
OUTFIT_MARGIN = 0.02            # kept off the outfit by this much more (the hand is modelled as a box, see HAND_BOX)
# The open hand's box from its wrist joint at hand size 1.0 (left hand, hanging: palm +X, fingers -Y, thumb -Z; the
# right mirrors X), scaled per build (handSize), and the forearm's radius over its far half (anim_qa judges the hand and
# the forearm from 0.6 past the elbow) - measured from the v5 bodies' meshes.
HAND_BOX = ((-0.134, 0.178), (-0.608, 0.098), (-0.362, 0.203))
FOREARM_R = {"Skinny": 0.16, "SkinnyFat": 0.162, "Fit": 0.206, "Fat": 0.217, "Muscular": 0.255, "BigBuff": 0.279}
_TO_B = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))    # Roblox <-> Blender (gear_fit_03.TO_B)
_OUTFIT = {}


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


def _outfit_tree(root, b):
    """The build's worn outfit over the torso and thighs at rest, as a BVH tree in rig-local Roblox studs."""
    import bpy
    from mathutils.bvhtree import BVHTree
    before = set(bpy.data.objects)
    meshes_before = set(bpy.data.meshes)
    for kind in ("Clothes", "Gear"):
        bpy.ops.import_scene.gltf(filepath=sorted(   # (the newest outfit export: the highest version on disk)
            glob.glob(os.path.join(root, "art", "exports", "Cartoon%s[0-9][0-9]_%s.glb" % (kind, b))))[-1])
    new = [o for o in bpy.data.objects if o not in before]
    centre_outfit([o for o in new if o.type == "MESH" and o.name.partition("__")[0] in OUTFIT_ITEMS])
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    verts, polys = [], []
    for o in new:
        item, _, part = o.name.partition("__")
        if o.type != "MESH" or item not in OUTFIT_ITEMS or part.split(".")[0] not in OUTFIT_PARTS:
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        base = len(verts)
        verts += [_TO_B @ (o.matrix_world @ v.co) for v in me.vertices]
        polys += [tuple(base + i for i in p.vertices) for p in me.polygons]
        ev.to_mesh_clear()
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    for m in [m for m in bpy.data.meshes if m not in meshes_before and m.users == 0]:
        bpy.data.meshes.remove(m)
    return BVHTree.FromPolygons(verts, polys)


def _thickness(tree, p, n):
    """anim_qa.arm_in_outfit's layers stacked on the skin at p (normal n): the first within 0.15 of the skin, each next
    within 0.08 of the last, never past 0.35."""
    layer, q = 0.0, p + n * 0.002
    for _ in range(8):
        hit = tree.ray_cast(q, n, 0.15 if layer == 0.0 else 0.08)
        if hit[0] is None:
            break
        layer = (hit[0] - p).dot(n)
        q = hit[0] + n * 1e-4
        if layer > 0.35:
            break
    return layer


def _outfit_data():
    if not _OUTFIT:
        import json
        from mathutils.kdtree import KDTree
        root = os.path.dirname(os.path.dirname(_HERE))
        builds = json.load(open(os.path.join(root, "art", "exports", "CartoonExport05.json")))["builds"]
        skin = json.load(open(os.path.join(root, "art", "data", "body_surface_05.json")))["builds"]
        for b in OUTFIT_BUILDS:
            joints = {k: Vector(v) for k, v in builds[b]["joints"].items()}
            worn = _outfit_tree(root, b)
            parts = {}
            for part, rows in skin[b].items():
                pts = [(Vector(r[0:3]), Vector(r[3:6])) for r in rows]
                pts = [(p, n, _thickness(worn, p, n)) for p, n in pts]
                tree = KDTree(len(pts))
                for i, (p, _n, _th) in enumerate(pts):
                    tree.insert(p, i)
                tree.balance()
                parts[part] = (tree, pts)
            s = builds[b]["handSize"]
            hand = []
            (x0, x1), (y0, y1), (z0, z1) = HAND_BOX
            for x in (x0, (x0 + x1) / 2, x1):
                for y in (y0, 0.75 * y0, 0.5 * y0, 0.25 * y0, y1):
                    for z in (z0, (z0 + z1) / 2, z1):
                        corner = sum(1 for v, lo, hi in ((x, x0, x1), (y, y0, y1), (z, z0, z1)) if v in (lo, hi)) == 3
                        k = 0.82 if corner else 1.0          # (the hand is rounded: its box corners are air)
                        c = Vector(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
                        hand.append((c + (Vector((x, y, z)) - c) * k) * s)
            r = FOREARM_R[b]
            fore_len = (joints["LeftHand"] - joints["LeftLowerArm"]).length
            fore = [Vector((r * math.cos(a), -d, r * math.sin(a))) for d in (0.62, 0.8, 0.98, fore_len - 0.02)
                    for a in [i * TAU / 8 for i in range(8)]]
            _OUTFIT[b] = (joints, parts, hand, fore)
    return _OUTFIT


def build_frames(b, pose):
    """{part: matrix} of build b posed by `pose` as anim_qa and the game pose it: a rest point p (rig-local, from the
    floor) of a part goes to frames[part] @ (p - joints[part])."""
    joints = _outfit_data()[b][0]
    world = {"HumanoidRootPart": Matrix.Translation(joints["HumanoidRootNode"])}
    pivot = {"HumanoidRootPart": joints["HumanoidRootNode"]}
    for part in S.ORDER:
        joint = S.CHILD_JOINT[part]
        parent = S.JOINTS[joint][0]
        if part not in joints or parent not in world:
            continue
        world[part] = world[parent] @ Matrix.Translation(joints[part] - pivot[parent]) @ pose.get(joint, Matrix.Identity(4))
        pivot[part] = joints[part]
    return world


def outfit_pen(pose, builds=OUTFIT_BUILDS, sides=("Left", "Right"), margin=OUTFIT_MARGIN):
    """How far each hand / far forearm sinks into the worn outfit (plus OUTFIT_MARGIN), the worst over `builds`:
    {side: (depth, outward normal)}, depth <= 0 when clear."""
    out = {}
    data = _outfit_data()
    for side in sides:
        sx = 1.0 if side == "Left" else -1.0
        worst = (-1.0, Vector((0, 0, 0)))
        for b in builds:
            joints, parts, hand, fore = data[b]
            w = build_frames(b, pose)
            pts = [w[side + "Hand"] @ Vector((sx * p.x, p.y, p.z)) for p in hand]
            pts += [w[side + "LowerArm"] @ Vector((sx * p.x, p.y, p.z)) for p in fore]
            inv = {part: (w[part].inverted(), w[part].to_3x3()) for part in parts if part in w}
            for q in pts:
                best = None
                for part, (tree, rest) in parts.items():
                    if part not in inv:
                        continue
                    mi, rot = inv[part]
                    local = joints[part] + mi @ q
                    co, i, dist = tree.find(local)
                    if co is None or dist > 0.6 or (best is not None and dist >= best[0]):
                        continue
                    p, n, th = rest[i]
                    best = (dist, (local - p).dot(n), th, rot @ n)
                if best is None:
                    continue
                _d, s, th, n = best
                if th <= 0.0:
                    continue
                pen = th + margin - s
                if pen > worst[0]:
                    worst = (pen, n.normalized())
        out[side] = worst
    return out


def _smooth_pushes(raw, steps_wide, steps_blur):
    """A push per frame (Vectors) spread over +-steps_wide frames (the biggest nearby wins), then blurred: the hand eases
    out of the clothes ahead of the moment it would sink and back after, never a jump."""
    n = len(raw)
    wide = []
    for i in range(n):
        near = raw[max(0, i - steps_wide):min(n, i + steps_wide + 1)]
        wide.append(max(near, key=lambda v: v.length).copy())
    if steps_blur <= 0:
        return wide
    ker = [math.exp(-0.5 * (k / steps_blur) ** 2) for k in range(-3 * steps_blur, 3 * steps_blur + 1)]
    out = []
    for i in range(n):
        acc, tot = Vector((0, 0, 0)), 0.0
        for k, wt in enumerate(ker):
            j = min(n - 1, max(0, i + k - 3 * steps_blur))
            acc += wide[j] * wt
            tot += wt
        out.append(acc / tot)
    return out


class Hype:
    """A hype move: `body` keys (planted), the left hand's keys (`right` keys too, as true positions, else mirrored),
    `neck(t)` an extra neck turn, `wobble(t)` added to both hands (left; the right mirrored)."""

    STEP = 0.025

    def __init__(self, length, body, left, right=None, neck=None, wobble=None, contact=False, palms=None):
        self.length, self.body, self.left_keys, self.right_keys = length, body, left, right
        self.neck, self.wobble = neck, wobble
        self.contact = contact and S.RIG == "torso"     # (hands stop at the skin: S.contact_out)
        # palms (torso rig): authored CONTACT, the hand flat on the body (References/Character Animation Quality.md):
        # {"spot": the left hand's spot near the body (root frame; the right mirrors), "fingers": the left fingers'
        # direction laid onto the skin, "weight": [(t, 0..1)] how far into the contact}. At weight > 0 the hand goes
        # to the posed middle build's skin there (a hand's half-thickness off it) turned palm-to-skin, the arm and
        # wrist solved exactly (S.lock_hand), easing in and out with the weight.
        self.palms = palms if S.RIG == "torso" else None
        # hands (torso rig): the hands' TURN without skin contact (claps: palms facing each other), set after
        # creation: {"palm": left palm direction, "fingers": left fingers direction (root frame; the right mirrors),
        # "weight": [(t, 0..1)]}; the arm and wrist are solved for it (S.lock_hand), elbows kept off the body
        self.hands = None
        self.table, self.worst = None, 0.0

    def _targets(self, t):
        extra = self.wobble(t) if self.wobble else Vector((0, 0, 0))
        if self.arcs:
            left = self._arc_hand(self.left_keys, t) + extra
            right = (mirror(self._arc_hand([(k, mirror(v)) for k, v in self.right_keys], t)) if self.right_keys
                     else mirror(self._arc_hand(self.left_keys, t))) + mirror(extra)
            return left, right
        left = hand_at(self.left_keys, t) + extra
        right = (hand_at(self.right_keys, t) if self.right_keys else mirror(hand_at(self.left_keys, t))) + mirror(extra)
        return left, right

    # (2026-11-15, per hype, opt-in) arcs: True moves a hand between its keys round its shoulder (the direction turned,
    # the distance eased; each key taken from the shoulder where the body has it at that key's time) instead of on the
    # straight line between them, which cuts inside a nearly straight arm's reach and folds the elbow on every sweep
    arcs = False

    def _shoulder_at(self, t):
        p = body_at(self.body, t)
        return S.joint_point(S.forward_kinematics(Matrix.Identity(4), F._body(p, p["root"])), "LeftShoulder")

    def _arc_hand(self, keys, t):
        if t <= keys[0][0]:
            return keys[0][1]
        for (t0, a), (t1, b) in zip(keys, keys[1:]):
            if t <= t1:
                u = S.smooth((t - t0) / (t1 - t0))
                da, db = a - self._shoulder_at(t0), b - self._shoulder_at(t1)
                d = da.normalized().slerp(db.normalized(), u, da.normalized()) if da.angle(db) > 1e-4 else da.normalized()
                return self._shoulder_at(t) + d * (da.length + (db.length - da.length) * u)
        return keys[-1][1]

    # (2026-11-16, per clip, opt-in: None leaves the solve exactly as it was) outfit: True keeps both hands and the far
    # half of each forearm OUTSIDE the worn meet outfit on every build (outfit_pen): the arms are solved, every frame
    # where a hand would sink gets a push straight out of the clothes there, the pushes are eased over the moments round
    # it (_smooth_pushes), and the arms solved again with the hands' paths moved out - the same one solve per frame with
    # the move's own elbow and turn wishes, only the hand's spot moved (never a fix-up solve after it). A few rounds.
    outfit = None
    OUTFIT_ROUNDS = 7
    OUTFIT_WIDE = 0.15          # seconds the push reaches ahead and behind the deepest moment
    OUTFIT_BLUR = 0.05
    outfit_margin = OUTFIT_MARGIN
    outfit_keep = None          # (free-solve clips) a pull toward the last frame's arm, per degree
    outfit_hold = None          # [(t, 0..1)]: at 1 no outfit push at all (the hand spot kept exactly)
    outfit_mirror = None        # True/False: both hands get mirrored pushes (None: when the move is mirrored)
    outfit_forward = None       # [(t, 0..1)]: at 1 the push keeps only its forward part
    outfit_claps = None         # [(t, 0..1)]: at 1 the outfit push keeps no sideways part (claps keep meeting)

    def _solve(self):
        if not (self.outfit and S.RIG == "torso"):
            self.push = None
            return self._solve_pass(None)
        n = int(math.ceil(self.length / self.STEP)) + 1
        zero = Vector((0, 0, 0))
        raw = {"Left": [zero.copy() for _ in range(n)], "Right": [zero.copy() for _ in range(n)]}
        pushes = None
        self.outfit_log = []
        for rnd in range(self.OUTFIT_ROUNDS + 1):
            self._solve_pass(pushes)
            worst = 0.0
            for i in range(n):
                pen = outfit_pen(self._table_pose(i), margin=self.outfit_margin)
                for side in ("Left", "Right"):
                    d, nrm = pen[side]
                    if d > 0:
                        raw[side][i] += nrm * d
                        worst = max(worst, d)
            self.outfit_log.append(round(worst, 3))
            if worst <= 0.003 or rnd == self.OUTFIT_ROUNDS:
                break
            wide, blur = int(round(self.OUTFIT_WIDE / self.STEP)), int(round(self.OUTFIT_BLUR / self.STEP))
            sm = {side: _smooth_pushes(raw[side], wide, blur) for side in raw}
            sym = self.outfit_mirror
            if sym is None:
                sym = self.right_keys is None and type(self)._targets is Hype._targets
            if sym:
                # (a mirrored move stays mirrored: both hands get the bigger of the two pushes, mirrored)
                for i in range(n):
                    l, r = sm["Left"][i], mirror(sm["Right"][i])
                    v = (l + r) / 2
                    big = max(l.length, r.length)
                    if v.length > 1e-6:
                        v = v.normalized() * big
                    sm["Left"][i], sm["Right"][i] = v, mirror(v)
            if self.outfit_hold:
                # (moments whose hand spots must stay exactly where they are, e.g. a slap landing on someone else)
                for i in range(n):
                    k = 1.0 - self._track(self.outfit_hold, min(self.length, i * self.STEP))
                    for side in sm:
                        sm[side][i] = sm[side][i] * k
            if self.outfit_claps:
                # (claps: the hands are pushed only forward and up, never apart, so the palms still meet)
                for i in range(n):
                    k = 1.0 - self._track(self.outfit_claps, min(self.length, i * self.STEP))
                    for side in sm:
                        sm[side][i] = Vector((sm[side][i].x * k, sm[side][i].y, sm[side][i].z))
            if self.outfit_forward:
                # (hands in a fixed place, e.g. the chalk bowl: pushed only further forward, never up or out of it)
                for i in range(n):
                    k = 1.0 - self._track(self.outfit_forward, min(self.length, i * self.STEP))
                    for side in sm:
                        v = sm[side][i]
                        sm[side][i] = Vector((v.x * k, v.y * k, v.z if v.z < 0 else v.z * k))
            pushes = list(zip(sm["Left"], sm["Right"]))
        self.push = pushes

    def _table_pose(self, i):
        t = min(self.length, i * self.STEP)
        p = body_at(self.body, t)
        pose = dict(F._body(p, p["root"]))
        l, r = self.table[i]
        pose.update(one_arm("Left", l))
        pose.update(one_arm("Right", r))
        if self.palms or self.hands:
            for side in ("Left", "Right"):
                pose[side + "Wrist"] = self.wrists[i][side].to_matrix().to_4x4()
        return pose

    def _solve_pass(self, pushes):
        """The arms solved once, in time order from the start, every STEP: each solve starts from the one before, so
        the arms never flip to another way of reaching the same spot, and every caller gets the same answer."""
        a_left, a_right = dict(START_ARM), dict(START_ARM)
        self.table, self.wrists = [], []
        I3 = Matrix.Identity(3)
        self._push_now = None
        for i in range(int(math.ceil(self.length / self.STEP)) + 1):
            t = min(self.length, i * self.STEP)
            p = body_at(self.body, t)
            body = F._body(p, p["root"])
            left, right = self._targets(t)
            if self.contact:
                frames = S.forward_kinematics(Matrix.Identity(4), body)
                left, right = S.contact_out(left, frames), S.contact_out(right, frames)
            if pushes is not None:
                self._push_now = pushes[i]
                left, right = left + pushes[i][0], right + pushes[i][1]
            self._t_now, self._side_now = t, "Left"
            prev_left, prev_right = a_left, a_right
            a_left = self._solve_one(body, left, a_left)
            self._side_now = "Right"
            a_right = self._solve_one(body, mirror(right), a_right)
            wrist = {"Left": I3.to_quaternion(), "Right": I3.to_quaternion()}
            w = self._palm_weight(t)
            if w > 0:
                a_left, a_right, wrist = self._palm_solve(body, left, right, a_left, a_right, w)
            if self.hands and S.RIG == "torso":
                specs = self.hands if isinstance(self.hands, list) else [self.hands]
                if self.hands_mix:
                    # (cross-faded: every spec with its weight, _mix_turn blends them)
                    ws = {sd: [(self._track(sp["weight"], t), sp) for sp in specs
                               if sd in sp.get("sides", ("Left", "Right"))] for sd in ("Left", "Right")}
                    any_w = any(w > 0 for sd in ws for w, _sp in ws[sd])
                else:
                    ws = {sd: max([(self._track(sp["weight"], t), sp) for sp in specs if sd in sp.get("sides", ("Left", "Right"))]
                                  or [(0.0, None)], key=lambda x: x[0]) for sd in ("Left", "Right")}
                    any_w = ws["Left"][0] > 0 or ws["Right"][0] > 0
                if any_w:
                    a_left, a_right, wrist = self._turn_solve(body, left, right, a_left, a_right, ws, wrist)
                    if self.elbows is not None:
                        # (exact-solve hypes) a hand turned at the wrist swings its centre off the target: the arms
                        # are solved again for where the turned hands land, twice (claps meet, taps land)
                        aim_l, aim_r = Vector(left), Vector(right)
                        for _ in range(2):
                            q = dict(body)
                            q.update(one_arm("Left", a_left))
                            q.update(one_arm("Right", a_right))
                            for sd in ("Left", "Right"):
                                q[sd + "Wrist"] = wrist[sd].to_matrix().to_4x4()
                            fw = S.forward_kinematics(Matrix.Identity(4), q)
                            aim_l -= fw["LeftHand"].to_translation() - left
                            aim_r -= fw["RightHand"].to_translation() - right
                            self._side_now = "Left"
                            a_left = self._solve_one(body, aim_l, prev_left)
                            self._side_now = "Right"
                            a_right = self._solve_one(body, mirror(aim_r), prev_right)
                            a_left, a_right, wrist = self._turn_solve(body, aim_l, aim_r, a_left, a_right, ws, wrist)
            self.table.append((dict(a_left), dict(a_right)))
            self.wrists.append(wrist)

    @staticmethod
    def _track(keys, t):
        a, b, u = F.at(keys, t)
        return a + (b - a) * u

    def _turn_solve(self, body, left, right, a_left, a_right, ws, wrist_now):
        """The hands turned toward their spec's palm/fingers by its weight, kept on their targets (claps, a point).
        ws: {side: (weight, spec)}; a spec for both sides gives the left's directions (the right mirrors), a spec for
        one side gives that side's own true directions."""
        if self.hands_mix:
            return self._mix_turn(body, a_left, a_right, ws, wrist_now)
        frames = S.forward_kinematics(Matrix.Identity(4), body)
        ut = frames["UpperTorso"]
        out, wrists = {"Left": a_left, "Right": a_right}, dict(wrist_now)
        for side, target, start in (("Left", left, a_left), ("Right", right, a_right)):
            w, spec = ws[side]
            if w <= 0:
                continue
            palm, fingers = Vector(spec["palm"]), Vector(spec["fingers"])
            if side == "Right" and len(spec.get("sides", ("Left", "Right"))) == 2:
                palm, fingers = mirror(palm), mirror(fingers)
            fingers = fingers - palm.normalized() * fingers.dot(palm.normalized())
            sh, el = S._arm_tf(side, start)
            c0s, c1s = S.JOINTS[side + "Shoulder"][2], S.JOINTS[side + "Shoulder"][3]
            c0e, c1e = S.JOINTS[side + "Elbow"][2], S.JOINTS[side + "Elbow"][3]
            lower = ut @ S.T(c0s) @ sh @ S.T(c1s).inverted() @ S.T(c0e) @ el @ S.T(c1e).inverted()
            rot = lower.to_3x3().to_quaternion().slerp(S.hand_frame(side, palm, fingers).to_quaternion(), w).to_matrix()
            if spec.get("wrist_only"):
                # the arm keeps its own (natural) reach; only the hand turns at the wrist (a point: the forearm
                # turns the palm down, the arm stays straight out)
                wrists[side] = (lower.to_3x3().transposed() @ rot).to_quaternion()
                continue
            a, tfs, _miss = S.lock_hand(ut, side, target, rot, start, back=None, below=0.2,
                                        offset=S.hand_centre_from_wrist(side), clear_of=frames,
                                        **({"keep": self.keep, "first_step": 4} if self.keep else {}))
            out[side], wrists[side] = a, tfs[side + "Wrist"].to_quaternion()
        return out["Left"], out["Right"], wrists

    # (2026-11-28, per hype, opt-in: False leaves every other move exactly as it was) hands_mix: the hand turns
    # CROSS-FADE instead of the strongest one winning, so one turn hands over to the next without the wrist untwisting
    # to its natural turn and twisting back (Hype_OverheadClap: the clap's palms-in turn handed to the fling's palms-up
    # one while the arms swing down the sides). Wrist-only specs only. A spec may also be {"supinate": degrees}: the
    # hand turned round the forearm's own length from the arm's natural turn, palm toward the elbow crease's side (as a
    # forearm rolls palm-up; R15 has no forearm roll, so the wrist does it), the fingers kept straight down the forearm.
    hands_mix = False

    def _mix_turn(self, body, a_left, a_right, ws, wrist_now):
        frames = S.forward_kinematics(Matrix.Identity(4), body)
        ut = frames["UpperTorso"]
        wrists = dict(wrist_now)
        I = Matrix.Identity(3).to_quaternion()
        for side, start in (("Left", a_left), ("Right", a_right)):
            q, cum = None, 0.0
            for w, spec in ws[side]:
                if w <= 0:
                    continue
                if "supinate" in spec:
                    ang = math.radians(spec["supinate"]) * (1 if side == "Left" else -1)
                    local = Quaternion(Vector((0.0, 1.0, 0.0)), ang)
                else:
                    assert spec.get("wrist_only"), "hands_mix: wrist-only hand turns only"
                    palm, fingers = Vector(spec["palm"]), Vector(spec["fingers"])
                    if side == "Right" and len(spec.get("sides", ("Left", "Right"))) == 2:
                        palm, fingers = mirror(palm), mirror(fingers)
                    fingers = fingers - palm.normalized() * fingers.dot(palm.normalized())
                    sh, el = S._arm_tf(side, start)
                    c0s, c1s = S.JOINTS[side + "Shoulder"][2], S.JOINTS[side + "Shoulder"][3]
                    c0e, c1e = S.JOINTS[side + "Elbow"][2], S.JOINTS[side + "Elbow"][3]
                    lower = ut @ S.T(c0s) @ sh @ S.T(c1s).inverted() @ S.T(c0e) @ el @ S.T(c1e).inverted()
                    local = (lower.to_3x3().transposed() @ S.hand_frame(side, palm, fingers)).to_quaternion()
                cum += w
                q = local if q is None else q.slerp(local, w / cum)
            if q is not None:
                wrists[side] = I.slerp(q, min(1.0, cum))
        return a_left, a_right, wrists

    def _palm_weight(self, t):
        if not self.palms:
            return 0.0
        a, b, u = F.at(self.palms["weight"], t)
        return a + (b - a) * u

    def _palm_solve(self, body, left, right, a_left, a_right, w):
        frames = S.forward_kinematics(Matrix.Identity(4), body)
        ut = frames["UpperTorso"]
        out = {}
        wrists = {}
        for side, free, start in (("Left", left, a_left), ("Right", right, a_right)):
            spot = Vector(self.palms["spot"]) if side == "Left" else mirror(Vector(self.palms["spot"]))
            fingers = Vector(self.palms["fingers"]) if side == "Left" else mirror(Vector(self.palms["fingers"]))
            near = S._skin_near(spot, frames)
            if near is None:
                out[side], wrists[side] = start, Matrix.Identity(3).to_quaternion()
                continue
            _s, skin, n = near
            on_skin = skin + n * S.HAND_HALF
            if self._push_now is not None:          # (outfit: the palm on the clothes of the widest build)
                on_skin = on_skin + self._push_now[0 if side == "Left" else 1]
            along = fingers - n * fingers.dot(n)
            target = free.lerp(on_skin, w)
            sh, el = S._arm_tf(side, start)
            c0s, c1s = S.JOINTS[side + "Shoulder"][2], S.JOINTS[side + "Shoulder"][3]
            c0e, c1e = S.JOINTS[side + "Elbow"][2], S.JOINTS[side + "Elbow"][3]
            lower = ut @ S.T(c0s) @ sh @ S.T(c1s).inverted() @ S.T(c0e) @ el @ S.T(c1e).inverted()
            free_rot = lower.to_3x3()
            rot = free_rot.to_quaternion().slerp(S.hand_frame(side, -n, along).to_quaternion(), w).to_matrix()
            if self.elbows is not None:
                # (exact-solve hypes, 2026-11-15) the wrist joint put where the turned hand needs it, the elbow where the
                # hype says (lock_hand's search hopped between elbow-up and elbow-down shapes from frame to frame)
                wrist_goal = target - rot @ S.hand_centre_from_wrist(side)
                self._side_now = side
                pull = self._elbow_pull(self._t_now)
                if side == "Left":
                    a = ik_arm(body, wrist_goal, pull, start, wrist_point=True)
                else:
                    a = ik_arm(body, mirror(wrist_goal), pull, start, wrist_point=True)
                sh, el = S._arm_tf(side, a)
                lower = ut @ S.T(c0s) @ sh @ S.T(c1s).inverted() @ S.T(c0e) @ el @ S.T(c1e).inverted()
                out[side] = a
                wrists[side] = (lower.to_3x3().transposed() @ rot).to_quaternion()
                continue
            a, tfs, _miss = S.lock_hand(ut, side, target, rot, start, back=None, below=self.palms.get("below", 0.25),
                                        offset=S.hand_centre_from_wrist(side), clear_of=frames)
            out[side] = a
            wrists[side] = tfs[side + "Wrist"].to_quaternion()
        return out["Left"], out["Right"], wrists

    # A solve that misses by more than ~0.25 got stuck (torso rig 2026-11-13: Hype_CrowdLift's fast swing from overhead
    # to behind the hips left the arm reaching out sideways for two frames, a 1.3 miss): only then it is tried again
    # from fresh starts and the best kept. (Never happens on the taller rig: its worst miss is 0.155.)
    RETRY_COST = 5.0 * 0.25 + 0.6
    RETRY_STARTS = [{"raise": r, "swing": s, "twist": 0.0, "elbow": e}
                    for r in (10.0, 60.0) for s in (-60.0, 0.0, 60.0, 120.0) for e in (30.0, 110.0)]

    keep = None          # (torso rig) hand turns: S.lock_hand's pull toward the arm's natural solve, small search
    #                      steps only (None: lock_hand's defaults)
    natural = False      # (torso rig) True: arms keep away from the twisted "raised backwards" shape (raise < -12)

    # (2026-11-15, per hype, opt-in: None leaves the solve exactly as it was, so the chalk clips built on this class
    # are unchanged) elbows: [(t, Vector)] the LEFT elbow's wanted direction in the chest frame (the right mirrors),
    # eased between keys: the arm is then solved exactly (ik_arm) with the elbow off the shoulder-hand line toward
    # it. User rule §5.0.1: elbows never point behind the body; hands up: elbows out to the sides.
    elbows = None

    elbows_right = None    # (opt-in) the right arm's own elbow keys, written mirrored (in the left arm's terms)

    def _elbow_pull(self, t):
        keys = self.elbows_right if (self.elbows_right and self._side_now == "Right") else self.elbows
        a, b, u = F.at(keys, t)
        return a.lerp(b, u)

    # (2026-11-15, per hype, opt-in) elbow_min: the free solve keeps each elbow bent at least this much (degrees): it may
    # otherwise straighten a hanging arm past straight (to -5), which reads as an elbow bent backward on the big builds
    elbow_min = None

    def _pref(self, w, a):
        c = preference(w, a)
        if self.natural:
            c += 0.02 * max(0.0, -a["raise"] - 12.0)
        if self.elbow_min is not None:
            c += 0.05 * max(0.0, self.elbow_min - a["elbow"])
        return c

    def _solve_one(self, body, target, start):
        if self.elbows is not None:
            return ik_arm(body, target, self._elbow_pull(self._t_now), start)
        pref = self._pref if (self.natural or self.elbow_min is not None) else preference
        if self.outfit and self.outfit_keep:
            # (outfit: the pushed spots must not slide the arm over into another shape from one frame to the next)
            base_pref, k = pref, self.outfit_keep

            def pref(w, a, base_pref=base_pref, k=k, start=start):
                return base_pref(w, a) + k * sum(abs(a[q] - start[q]) for q in ("raise", "swing", "elbow"))
        a, cost = S.solve_arms(body, target, start, pref, 5.0, SOLVE_STEPS)
        if cost > self.RETRY_COST and not self.outfit:      # (outfit: a pushed spot may lie a little beyond the
            # reach; a fresh start there jumps to another arm shape, so the arm stays on its own path)
            for fresh in self.RETRY_STARTS:
                b, c = S.solve_arms(body, target, fresh, pref, 5.0)
                if c < cost:
                    a, cost = b, c
        return a

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
        if self.palms or self.hands:
            w0, w1 = self.wrists[i], self.wrists[i + 1]
            for side in ("Left", "Right"):
                pose[side + "Wrist"] = w0[side].slerp(w1[side], u).to_matrix().to_4x4()
        if self.neck:
            pose["Neck"] = pose["Neck"] @ self.neck(t)
        left, right = self._targets(t)
        if self.push is not None:                   # (outfit: the hands' spots moved out of the clothes)
            (pl0, pr0), (pl1, pr1) = self.push[i], self.push[i + 1]
            left, right = left + pl0.lerp(pl1, u), right + pr0.lerp(pr1, u)
        w = S.forward_kinematics(Matrix.Identity(4), pose)
        self.worst = max(self.worst, (w["LeftHand"].to_translation() - left).length,
                         (w["RightHand"].to_translation() - right).length)
        return pose


def dip(depth, neck=0.0, torso=0.0):
    return {"torso": torso - 4.0 * depth, "thigh": 18.0 * depth, "shin": -8.0 * depth, "toes": 12.0, "neck": neck}


# Hype_Belt: hands to the belt's sides, slide to the front, two hard tugs with a dip, a clap, hands down.
# (on the torso rig the hands go to the navel belt of the new bodies: S.on_belt, this move's belt front at -0.55)
BELT_SIDE = S.on_belt(-1.12, -0.5, -0.62, -0.55)
BELT_FRONT = S.on_belt(-0.55, -0.55, -0.98, -0.55)
BELT_TUG = S.on_belt(-0.6, -0.68, -0.94, -0.55)
CLAP = on_body(-0.5, 0.35, -1.05)
APART = on_body(-1.05, 0.42, -1.1)
BELT = Hype(3.0,
            [(0.0, STAND), (0.35, dict(STAND, neck=-14.0)), (0.9, dict(STAND, neck=-16.0)), (1.05, dip(0.6, -18.0)),
             (1.2, dict(STAND, neck=-14.0)), (1.4, dip(0.7, -18.0)), (1.6, dict(STAND, neck=-4.0)),
             (2.2, dict(STAND, neck=4.0)), (3.0, STAND)],
            [(0.0, HANG_HAND), (0.45, BELT_SIDE), (0.8, BELT_FRONT), (1.05, BELT_TUG), (1.2, BELT_FRONT),
             (1.4, BELT_TUG), (1.6, BELT_FRONT), (1.85, APART), (2.0, CLAP), (2.2, CLAP), (2.6, HANG_HAND),
             (3.0, HANG_HAND)])
if S.RIG == "torso":
    # (2026-11-15, QA arm_in_body FAIL: palms-up fingers poking into the Fat belly on the belt, the "clap" wrists
    # crossing in front of the chest) the hands lie ON the belt: palms turned in against it, fingers down, a touch
    # further forward (Fat's belly is the deepest), and the clap is open palms meeting in front of the chest (user
    # rule §5.0.8, the approved clap of Hype_NeckRoll)
    _bf = Vector((0.0, 0.0, -0.12))
    BH_SIDE, BH_FRONT, BH_TUG = BELT_SIDE + Vector((-0.04, 0.0, -0.1)), BELT_FRONT + _bf, BELT_TUG + _bf
    BH_CLAP = Vector((-0.15, CLAP.y, CLAP.z - 0.2))
    BH_APART = Vector((APART.x, APART.y, APART.z - 0.1))
    BELT.left_keys = [(0.0, HANG_HAND), (0.45, BH_SIDE), (0.8, BH_FRONT), (1.05, BH_TUG), (1.2, BH_FRONT),
                      (1.4, BH_TUG), (1.6, BH_FRONT), (1.85, BH_APART), (2.0, BH_CLAP), (2.2, BH_CLAP),
                      (2.4, arc_mid(BH_CLAP, HANG_HAND)), (2.6, HANG_HAND), (3.0, HANG_HAND)]   # (down in front)
    # the arms solved with their elbows told where to point: out and back with the hands on the belt (as on the hips),
    # down and out for the clap, so they keep off the belly (the free solve tucked them in across the Fat belly)
    _EL_BELT, _EL_CLAP = Vector((-0.75, -0.3, 0.6)), Vector((-0.55, -1.0, 0.05))
    BELT.elbows = [(0.0, EL_HANG), (0.3, _EL_BELT), (1.62, _EL_BELT), (1.9, _EL_CLAP), (2.3, _EL_CLAP), (2.6, EL_HANG),
                   (3.0, EL_HANG)]
    BELT_HANDS = {"palm": Vector((0.3, 0.0, 1.0)), "fingers": Vector((0.35, -1.0, 0.0)), "wrist_only": True}
    CLAP_FRONT = {"palm": Vector((1.0, 0.0, 0.0)), "fingers": Vector((0.0, 0.45, -1.0)), "wrist_only": True}
    BELT.hands = [dict(BELT_HANDS, weight=[(0.0, 0.0), (0.3, 0.0), (0.5, 1.0), (1.62, 1.0), (1.8, 0.0), (3.0, 0.0)]),
                  dict(CLAP_FRONT, weight=[(0.0, 0.0), (1.8, 0.0), (1.97, 1.0), (2.25, 1.0), (2.45, 0.0), (3.0, 0.0)])]

# Hype_Flex: arms up into a double biceps, held and shaking, a small lean, then shakes the arms out.
FLEX = held_out(-1.78, 1.72, -0.15)
FLEX_IN = held_out(-1.7, 1.55, -0.35)
LOOSE = on_body(-1.6, -0.7, -0.25)
FLEX_HYPE = Hype(3.2,
                 [(0.0, STAND), (0.5, dict(STAND, neck=6.0)), (0.7, dip(0.35, 4.0)), (1.8, dip(0.4, 2.0)),
                  (2.2, STAND), (3.2, STAND)],
                 [(0.0, HANG_HAND), (0.5, FLEX_IN), (0.7, FLEX), (1.8, FLEX), (2.15, LOOSE), (2.9, HANG_HAND),
                  (3.2, HANG_HAND)],
                 wobble=lambda t: Vector((0, shake(t, 0.75, 1.8, 0.05, 11.0), 0)) +
                 Vector((0.12 * F.tremble(t, 2.15, 2.9, 1.0, 5.0), 0.1 * F.tremble(t, 2.15, 2.9, 1.0, 5.0), 0)))
if S.RIG == "torso":
    # (2026-11-15, user rules §5.0.1 and 6: the flex was arms up and BACK, elbows a stud behind the shoulders) the open
    # double biceps of the celebrations (celebration_animations._DB_OPEN): upper arms out level, forearms straight up,
    # each fist 0.85 out and 1.44 up from its shoulder joint, the elbows held out to the sides (the elbow hint
    # _ELBOW_DB_OPEN). Up through the side (the upper arm rising out to the side, the forearm folding up) and back down
    # the same way: the forearm opens out to the side first, then the straight arm drops (a straight line from the
    # flex to the hips cut past the shoulder and folded the elbow back).
    FLEX = SHOULDER_NOW + Vector((-0.85, 1.44, -0.1))
    FLEX_IN = SHOULDER_NOW + Vector((-2.05, 0.2, -0.3))       # on the way: the arm out to the side, a soft bend
    FLEX_OPEN = SHOULDER_NOW + Vector((-2.1, 0.35, -0.3))     # on the way down: the forearm opened out first
    FLEX_LOOSE = SHOULDER_NOW + Vector((-0.65, -2.15, -0.3))  # shaking out: hanging loose, a little out and forward
    FLEX_HYPE = Hype(3.2,
                     [(0.0, STAND), (0.5, dict(STAND, neck=6.0)), (0.7, dip(0.35, 4.0)), (1.8, dip(0.4, 2.0)),
                      (2.2, STAND), (3.2, STAND)],
                     [(0.0, HANG_HAND), (0.2, arc_mid(HANG_HAND, FLEX_IN)), (0.4, FLEX_IN), (0.7, FLEX), (1.8, FLEX),
                      (2.0, FLEX_OPEN), (2.12, arc_mid(FLEX_OPEN, FLEX_LOOSE)), (2.25, FLEX_LOOSE), (2.9, HANG_HAND),
                      (3.2, HANG_HAND)],
                     wobble=FLEX_HYPE.wobble)
    # (the shoulder turns the forearm up as the arm rises: palms-down lateral raise into the double biceps)
    FLEX_HYPE.elbows = [(0.0, EL_HANG), (0.1, EL_HANG), (0.4, EL_UNDER), (0.68, EL_DB), (1.8, EL_DB), (2.0, EL_UNDER),
                        (2.25, EL_HANG), (3.2, EL_HANG)]

# Hype_ChestSlap: hands back wide, two slaps on the chest, then arms down and out and a roar up at the ceiling.
CHEST = on_body(-0.48, 0.42, -0.98)
WIDE = held_out(-1.45, 0.45, -0.95)
ROAR = held_out(-1.95, -0.35, -0.55)
CHEST_SLAP = Hype(3.2,
                  [(0.0, STAND), (0.4, dict(STAND, neck=-4.0)), (0.95, dict(STAND, neck=-6.0)),
                   (1.25, dip(0.5, 22.0, 2.0)), (2.4, dip(0.55, 26.0, 2.0)), (2.9, STAND), (3.2, STAND)],
                  [(0.0, HANG_HAND), (0.35, WIDE), (0.5, CHEST), (0.65, WIDE), (0.8, CHEST), (1.25, ROAR),
                   (2.4, ROAR), (2.9, HANG_HAND), (3.2, HANG_HAND)],
                  wobble=lambda t: Vector((shake(t, 1.3, 2.4, 0.06, 10.0), shake(t, 1.3, 2.4, 0.04, 8.0), 0)),
                  # (torso rig, 2026-11-13) the slaps land FLAT on the chest from the side: palm on the pec, fingers
                  # pointing in toward the breastbone (a little up), the forearm carrying on in line, elbows out
                  # (each hand on its own pec, out at x 0.66, so the inward fingertips stop short of the middle; the
                  # biggest hands' fingertips (Muscular, Big and buff) still meet: their per-build fit, Phase 4)
                  palms={"spot": Vector((-0.66, CHEST.y, CHEST.z)), "fingers": Vector((1.0, 0.35, 0.0)), "below": 0.05,
                         # (the palms stay turned to the chest between the two slaps, as people do; in over 0.2 s)
                         "weight": [(0.0, 0.0), (0.28, 0.0), (0.5, 1.0), (0.58, 1.0), (0.66, 0.65), (0.8, 1.0),
                                    (0.88, 1.0), (1.12, 0.0), (3.2, 0.0)]})
if S.RIG == "torso":
    # (2026-11-15, the approved move; QA: a 207 degree turn in 0.35 s) between the two slaps the elbow flapped up over
    # the shoulder and back down while the hand stayed on the chest (lock_hand's search hopping between an elbow-up and
    # an elbow-down shape). The same slaps, solved exactly with the elbow held out to the side at chest height and the
    # forearm coming across (user rule §5.0.1); the hands still land flat on the pecs (palms).
    _EL_SLAP = Vector((-0.9, 0.6, 0.25))
    CHEST_SLAP.elbows = [(0.0, EL_HANG), (0.3, _EL_SLAP), (1.0, _EL_SLAP), (1.3, EL_HANG), (3.2, EL_HANG)]
    # (2026-11-16, longer-thigh rebuild of the bodies: on the pecs' upper edge the elbows bent 131 deg, which folds
    #  BigBuff's forearm 0.27 into its own biceps, anim_qa. The palms land a little lower on the pecs, so the elbows open;
    #  same two slaps, same times, palms flat on the chest.)
    #  (0.06 down; 0.12 already slid the palms off the pecs onto the belly)
    _CHEST_LOW = Vector((CHEST.x, CHEST.y - 0.06, CHEST.z))
    CHEST_SLAP.left_keys = [(k, _CHEST_LOW if v is CHEST else v) for k, v in CHEST_SLAP.left_keys]
    CHEST_SLAP.palms["spot"] = Vector((CHEST_SLAP.palms["spot"].x, _CHEST_LOW.y, _CHEST_LOW.z))

# Hype_NeckRoll: rolls the neck round, two claps, then points the right hand at the bar.
POINT = reach_out(0.6, 0.85, -1.72)


def neck_roll(t):
    if t <= 0.1 or t >= 1.5:
        return Matrix.Identity(4)
    u = (t - 0.1) / 1.4
    edge = min(1.0, u / 0.15, (1 - u) / 0.15)
    angle = TAU * u
    return rz(16.0 * edge * math.sin(angle)) @ rx(14.0 * edge * (math.cos(angle) - 1) * 0.5 - 6.0 * edge)


if S.RIG == "torso":
    # (torso rig, 2026-11-13, the user's flagged move) the claps really MEET (the block body's clap left the hands a
    # full stud apart: palms together now, a little further out in front of the chest), the arms start up for them a
    # little earlier, and the pointing arm swings straight down over 0.4 s in its natural shape (a 0.2 s drop from a twisted
    # pointing shape made it flip back and forth)
    NR_CLAP = Vector((-0.2, CLAP.y, CLAP.z - 0.2))       # (palms meet: room for the biggest hands' fingers)
    # the point: straight out from the shoulder at shoulder height, a little outside it, elbow soft
    # (aimed a little beyond the reach: the arm goes fully straight that way instead of bending to land short)
    NR_POINT = mirror(SHOULDER_NOW) + Vector((0.15, 0.0, -1.12 * (S.reach(1.488) + 0.125)))
    NR_APART = Vector((APART.x, APART.y, APART.z - 0.1))
    # half way down the pointing arm's swing, ON its arc (a straight line from the point to the hang cuts inside the
    # arm's reach and made the elbow bend and straighten in a snap)
    _sh_r = mirror(SHOULDER_NOW)
    _from, _to = NR_POINT - _sh_r, mirror(HANG_HAND) - _sh_r
    NR_ARC = _sh_r + (_from.normalized() + _to.normalized()).normalized() * (_from.length + _to.length) / 2
    NECK_ROLL = Hype(3.0,
                     [(0.0, STAND), (1.5, STAND), (1.7, dict(STAND, neck=-4.0)), (2.3, dict(STAND, neck=-2.0)),
                      (2.5, dict(STAND, neck=-8.0)), (3.0, STAND)],
                     [(0.0, HANG_HAND), (1.35, HANG_HAND), (1.72, NR_APART), (1.9, NR_CLAP), (2.05, NR_APART),
                      (2.2, NR_CLAP), (2.36, NR_APART), (2.62, HANG_HAND), (3.0, HANG_HAND)],
                     right=[(0.0, mirror(HANG_HAND)), (1.35, mirror(HANG_HAND)), (1.72, mirror(NR_APART)),
                            (1.9, mirror(NR_CLAP)), (2.05, mirror(NR_APART)), (2.2, mirror(NR_CLAP)), (2.45, NR_POINT),
                            (2.6, NR_POINT), (2.8, NR_ARC), (3.0, mirror(HANG_HAND))],
                     neck=neck_roll)
    # the point at the bar with the arm's natural shape (it had twisted "raised backwards" and snapped back coming down)
    NECK_ROLL.natural = True
    # (2026-11-15, the approved move: only the last 0.2 s change) the pointing arm comes down with its elbow soft, not
    # past straight (QA elbow_hyper 11.5 on Muscular at 2.95)
    NECK_ROLL.elbow_min = 1.0
    # the claps: palms facing each other, fingers forward and a little up
    NECK_ROLL.hands = [
        {"palm": Vector((1.0, 0.0, 0.0)), "fingers": Vector((0.0, 0.45, -1.0)),
         "weight": [(0.0, 0.0), (1.45, 0.0), (1.8, 1.0), (2.25, 1.0), (2.36, 0.0), (3.0, 0.0)]},
        # the pointing hand: palm down, knuckles up, the finger straight ahead along the arm (the Point swap)
        {"sides": ("Right",), "palm": Vector((0.0, -1.0, 0.0)), "fingers": Vector((0.0, 0.0, -1.0)), "wrist_only": True,
         "weight": [(0.0, 0.0), (2.36, 0.0), (2.48, 1.0), (2.62, 1.0), (2.88, 0.0), (3.0, 0.0)]}]
else:
    NECK_ROLL = Hype(3.0,
                     [(0.0, STAND), (1.5, STAND), (1.7, dict(STAND, neck=-4.0)), (2.3, dict(STAND, neck=-2.0)),
                      (2.5, dict(STAND, neck=-8.0)), (3.0, STAND)],
                     [(0.0, HANG_HAND), (1.5, HANG_HAND), (1.75, APART), (1.9, CLAP), (2.05, APART), (2.2, CLAP),
                      (2.45, HANG_HAND), (3.0, HANG_HAND)],
                     right=[(0.0, mirror(HANG_HAND)), (1.5, mirror(HANG_HAND)), (1.75, mirror(APART)),
                            (1.9, mirror(CLAP)), (2.05, mirror(APART)), (2.2, mirror(CLAP)), (2.45, POINT),
                            (2.8, POINT), (3.0, mirror(HANG_HAND))],
                     neck=neck_roll)

# ---- the six new ones (Clip Study walk-ups and pre-lift rituals)
OVER = held_out(-0.35, 2.45, -0.05, keep_x=True)     # hands together overhead
HIGH_WIDE = held_out(-1.55, 2.3, -0.3)
FLING = held_out(-2.55, 1.15, -0.4)        # arms flung out wide, a little up
WING = held_out(-2.65, 1.0, 0.0)
V_UP = held_out(-1.55, 2.4, -0.25)
TRAP = on_body(-0.55, 1.05, -0.5)           # the hand on the top of its own shoulder
TRAP_OFF = held_out(-1.2, 1.5, -0.6)
THIGH = on_body(-1.15, -0.75, -0.45)
CROSS = on_body(0.35, 0.45, -0.9)          # across the chest, past the middle
LOW_FRONT = reach_out(-0.95, -0.45, -0.95)
HIGH_FRONT = reach_out(-1.3, 2.2, -0.85)
SWUNG_BACK = reach_out(-1.3, -0.35, 0.95)
UP_OUT = held_out(-2.3, 1.8, -0.3)


def crouch(depth, neck=0.0):
    return {"torso": -20.0 * depth, "thigh": 62.0 * depth, "shin": -30.0 * depth, "toes": 12.0, "neck": neck}


OVERHEAD_CLAP = Hype(3.0,
                     [(0.0, STAND), (0.6, dict(STAND, neck=8.0)), (0.95, dip(0.3, 12.0)), (1.2, dict(STAND, neck=24.0)),
                      (2.0, dict(STAND, neck=22.0)), (2.5, STAND), (3.0, STAND)],
                     [(0.0, HANG_HAND), (0.55, HIGH_WIDE), (0.9, OVER), (1.05, OVER), (1.4, FLING), (2.1, FLING),
                      (2.6, HANG_HAND), (3.0, HANG_HAND)],
                     wobble=lambda t: Vector((shake(t, 1.45, 2.1, 0.05, 10.0), shake(t, 1.45, 2.1, 0.04, 8.0), 0)))
# (2026-11-15) the overhead clap with the elbows OUT and the hands meeting just above and in front of the head (the
# straight arms brought the hands together right over the head, the upper arms through it: QA upper_in_head FAIL),
# open palms turned to face each other at the wrists (user rule §5.0.8), and the arms swinging round the shoulders
# (the straight line from the hips up to the wide hands folded the elbows behind the body)
OC_CLAP = SHOULDER_NOW + Vector((0.85, 2.0, -0.4))         # the left hand's centre at the clap (the right mirrors)
OC_APART = SHOULDER_NOW + Vector((0.5, 2.05, -0.4))
OC_ELBOWS = [(0.0, EL_HANG), (0.15, EL_HANG), (0.55, EL_OUT), (1.1, EL_OUT), (1.4, EL_UNDER), (2.1, EL_UNDER),
             (2.6, EL_HANG), (3.0, EL_HANG)]
CLAP_HANDS = {"palm": Vector((1.0, 0.0, 0.0)), "fingers": Vector((0.0, 1.0, -0.3)), "wrist_only": True}
if S.RIG == "torso":
    OVERHEAD_CLAP = Hype(3.0, OVERHEAD_CLAP.body,
                         [(0.0, HANG_HAND), (0.55, HIGH_WIDE), (0.8, OC_APART), (0.9, OC_CLAP), (1.05, OC_CLAP),
                          (1.4, FLING), (2.1, FLING), (2.6, HANG_HAND), (3.0, HANG_HAND)],
                         wobble=OVERHEAD_CLAP.wobble)
    OVERHEAD_CLAP.elbows, OVERHEAD_CLAP.arcs = OC_ELBOWS, True
    OVERHEAD_CLAP.hands = dict(CLAP_HANDS, weight=[(0.0, 0.0), (0.6, 0.0), (0.85, 1.0), (1.1, 1.0), (1.35, 0.0),
                                                   (3.0, 0.0)])
    # (2026-11-28, the user's live test of ARM UP: "the arms are going the opposite direction ... twisting the entire
    # arm. Hands should be pointing the other direction"; the reference: arms spread wide to the sides a little above
    # the shoulders, elbows nearly straight with the creases forward/up, palms OPEN up and forward to the crowd, fingers
    # outward.) The fling had no hand turn: as the arms swung down from the clap the wrists untwisted the clap's palms-in
    # turn, so the hands spun to palms-forward-and-down, thumbs up, the backs of the hands to the crowd behind, and the
    # arms reached 27 degrees forward with the elbows bent 23. Now the arms go out to the SIDES nearly straight (elbows
    # under: creases up), and the clap's turn cross-fades straight into a palms-up roll of the hands (hands_mix: no
    # untwist and re-twist on the way), which rolls back to palms-in as the arms come down to the hips.
    OC_FLING = SHOULDER_NOW + Vector((-0.95, 0.3, -0.02)).normalized() * 0.983 * (HANG_HAND - SHOULDER_NOW).length
    OVERHEAD_CLAP.left_keys = [(k, OC_FLING if v is FLING else v) for k, v in OVERHEAD_CLAP.left_keys]
    FLING_PALMS_UP = {"supinate": 75.0}
    OVERHEAD_CLAP.hands_mix = True
    OVERHEAD_CLAP.hands = [OVERHEAD_CLAP.hands,
                           dict(FLING_PALMS_UP, weight=[(0.0, 0.0), (1.1, 0.0), (1.35, 1.0), (2.1, 1.0), (2.6, 0.0),
                                                        (3.0, 0.0)])]
WINGS_V = Hype(3.2,
               [(0.0, STAND), (0.5, dict(STAND, neck=4.0)), (1.25, dict(STAND, neck=6.0)), (1.6, dip(0.35, 26.0)),
                (2.5, dip(0.4, 28.0)), (2.9, STAND), (3.2, STAND)],
               [(0.0, HANG_HAND), (0.5, WING), (1.25, WING), (1.6, V_UP), (2.5, V_UP), (2.95, HANG_HAND),
                (3.2, HANG_HAND)],
               wobble=lambda t: Vector((0, shake(t, 0.55, 1.2, 0.03, 6.0) + shake(t, 1.65, 2.5, 0.05, 10.0), 0)))
if S.RIG == "torso":
    # (2026-11-15: the arms dropped from the V to the hips along a straight line past the shoulders, the elbows folding
    # up behind the body and the arms turning 220 degrees in 0.35 s, QA elbow_back and pop FAIL) the arms swing round
    # their shoulders, nearly straight: up the sides into the wings, up into the V, and back down the sides
    WINGS_V.elbows = [(0.0, EL_HANG), (3.2, EL_HANG)]
    WINGS_V.arcs = True
    # (2026-11-16, QA upper_in_head 0.13 on BigBuff in the V: its thick upper arms met the head) the V a little wider
    # and more forward, still a V with the head back
    WV_UP = held_out(-1.72, 2.33, -0.38)
    WINGS_V.left_keys = [(k, WV_UP if v is V_UP else v) for k, v in WINGS_V.left_keys]
    # (2026-11-28, checked with Hype_OverheadClap's twist fix) the wings stay palms DOWN (wings); in the V the hands
    # had turned palms out and down (thumbs forward, the backs of the hands to the head): they roll palms FORWARD to
    # the crowd as the arms go up into the V, and back to palms-in on the way down
    WINGS_V.hands_mix = True
    WINGS_V.hands = [dict(FLING_PALMS_UP, supinate=80.0,
                          weight=[(0.0, 0.0), (1.25, 0.0), (1.6, 1.0), (2.5, 1.0), (2.95, 0.0), (3.2, 0.0)])]
TRAP_SLAP = Hype(3.0,
                 [(0.0, STAND), (0.35, dict(STAND, neck=-6.0)), (1.0, dict(STAND, neck=-8.0)), (1.4, dip(0.6, -10.0)),
                  (1.7, dict(STAND, neck=6.0)), (2.4, dict(STAND, neck=10.0)), (3.0, STAND)],
                 [(0.0, HANG_HAND), (0.35, TRAP_OFF), (0.5, TRAP), (0.65, TRAP_OFF), (0.8, TRAP), (1.15, APART),
                  (1.4, CLAP), (1.6, CLAP), (2.0, ROAR), (2.5, ROAR), (3.0, HANG_HAND)],
                 wobble=lambda t: Vector((shake(t, 2.0, 2.5, 0.06, 10.0), 0, 0)))
if S.RIG == "torso":
    # (2026-11-15, the user-approved move: only its start changed) the hands come up to the traps IN FRONT, the elbows
    # down then forward (straight up past the shoulders they folded the elbows behind the body, 0.89, and flipped
    # forward: QA elbow_back FAIL and a 225 degree turn in 0.35 s)
    TS_FRONT = SHOULDER_NOW + Vector((-0.6, -0.6, -1.4))      # the hand in front of the belly, forearm forward
    TRAP_SLAP.left_keys = [(0.0, HANG_HAND), (0.17, TS_FRONT)] + TRAP_SLAP.left_keys[1:]
CROWD_LIFT = Hype(3.2,
                  [(0.0, STAND), (0.3, dip(0.4, -4.0)), (0.75, dict(STAND, neck=16.0)), (1.05, dip(0.4, -2.0)),
                   (1.5, dict(STAND, neck=18.0)), (2.1, dict(STAND, neck=-4.0)), (2.8, dict(STAND, neck=-6.0)),
                   (3.2, STAND)],
                  [(0.0, HANG_HAND), (0.3, LOW_FRONT), (0.75, HIGH_FRONT), (1.05, LOW_FRONT), (1.5, HIGH_FRONT),
                   (1.9, HANG_HAND), (3.2, HANG_HAND)],
                  right=[(0.0, mirror(HANG_HAND)), (0.3, mirror(LOW_FRONT)), (0.75, mirror(HIGH_FRONT)),
                         (1.05, mirror(LOW_FRONT)), (1.5, mirror(HIGH_FRONT)), (1.75, mirror(LOW_FRONT)),
                         (2.05, POINT), (2.7, POINT),
                         (3.2, mirror(HANG_HAND))])
if S.RIG == "torso":
    # (2026-11-15, QA FAIL: the arms turned 210 degrees in 0.35 s on the lifts, a forearm in the Muscular belly on the
    # way down) each lift swings round the shoulder with the elbows out (palms up, as a crowd lift is), the point
    # with the elbow under the arm (thumb up)
    _EL_LIFT = Vector((-1.0, -0.1, 0.1))
    CROWD_LIFT.elbows = [(0.0, EL_HANG), (0.2, _EL_LIFT), (1.6, _EL_LIFT), (1.9, EL_HANG), (3.2, EL_HANG)]
    CROWD_LIFT.elbows_right = [(0.0, EL_HANG), (0.2, _EL_LIFT), (1.75, _EL_LIFT), (2.05, EL_UNDER), (2.7, EL_UNDER),
                               (3.2, EL_HANG)]
    CROWD_LIFT.arcs = True
CHALK_RITUAL = Hype(3.4,
                    [(0.0, STAND), (0.35, dip(0.5, -10.0)), (0.6, dip(0.5, -10.0)), (0.9, STAND),
                     (1.6, dict(STAND, neck=10.0)), (1.8, dict(STAND, neck=22.0)), (2.6, dict(STAND, neck=18.0)),
                     (3.0, STAND), (3.4, STAND)],
                    [(0.0, HANG_HAND), (0.35, THIGH), (0.47, LOOSE), (0.6, THIGH), (0.85, FLING), (1.1, CROSS),
                     (1.35, HIGH_WIDE), (1.65, OVER), (1.8, OVER), (2.1, FLING), (2.6, FLING), (3.1, HANG_HAND),
                     (3.4, HANG_HAND)],
                    right=[(0.0, mirror(HANG_HAND)), (0.35, mirror(THIGH)), (0.47, mirror(LOOSE)), (0.6, mirror(THIGH)),
                           (0.85, mirror(FLING)), (1.1, mirror(CROSS) + Vector((0, -0.25, -0.15))),
                           (1.35, mirror(HIGH_WIDE)), (1.65, mirror(OVER)), (1.8, mirror(OVER)), (2.1, mirror(FLING)),
                           (2.6, mirror(FLING)), (3.1, mirror(HANG_HAND)), (3.4, mirror(HANG_HAND))])
if S.RIG == "torso":
    # (2026-11-15, QA FAIL: arms spinning 267 degrees in 0.35 s, a 1,785 deg/s pop, the upper arms through the head at
    # the overhead clap, forearms in the Fat belly at the X) the same ritual, re-timed inside its 3.4 s so each big
    # swing gets its time: two quicker thigh slaps, the arms out to the sides, the X swing across the chest (in front of
    # every belly, elbows out), up the sides into the overhead clap of Hype_OverheadClap (elbows out, hands meeting
    # above the forehead, open palms), flung out, down. Every swing goes round the shoulders (arcs), the elbows told
    # where to point.
    CR_OUT = SHOULDER_NOW + Vector((-2.2, -0.35, -0.5))        # the arms out to the sides, a little low, before the X
    CR_CROSS = SHOULDER_NOW + Vector((1.25, -0.35, -1.25))     # the left hand across the chest (the right goes under)
    CR_CROSS_R = SHOULDER_NOW + Vector((1.15, -0.65, -1.45))   # (the right arm's own spot, in the left's terms)
    _cr_body = [(0.0, STAND), (0.25, dip(0.5, -10.0)), (0.47, dip(0.5, -10.0)), (0.8, STAND),
                (1.6, dict(STAND, neck=10.0)), (1.8, dict(STAND, neck=22.0)), (2.6, dict(STAND, neck=18.0)),
                (3.0, STAND), (3.4, STAND)]

    def _cr_hands(cross):
        return [(0.0, HANG_HAND), (0.25, THIGH), (0.36, LOOSE), (0.47, THIGH), (0.8, CR_OUT), (1.15, cross),
                (1.45, HIGH_WIDE), (1.68, OC_APART), (1.78, OC_CLAP), (1.9, OC_CLAP), (2.2, OC_FLING), (2.6, OC_FLING),
                (3.1, HANG_HAND), (3.4, HANG_HAND)]
    CHALK_RITUAL = Hype(3.4, _cr_body, _cr_hands(CR_CROSS),
                        right=[(k, mirror(v)) for k, v in _cr_hands(CR_CROSS_R)])
    _EL_CROSS = Vector((-1.0, -0.6, 0.1))                      # the crossing arm: the elbow out and down
    CHALK_RITUAL.elbows = [(0.0, EL_HANG), (0.5, EL_HANG), (0.8, EL_UNDER), (1.15, _EL_CROSS), (1.45, EL_OUT),
                           (1.95, EL_OUT), (2.2, EL_UNDER), (2.6, EL_UNDER), (3.1, EL_HANG), (3.4, EL_HANG)]
    CHALK_RITUAL.arcs = True
    CHALK_RITUAL.hands = dict(CLAP_HANDS, weight=[(0.0, 0.0), (1.5, 0.0), (1.72, 1.0), (1.95, 1.0), (2.15, 0.0),
                                                  (3.4, 0.0)])
    # (2026-11-28, the same fault as Hype_OverheadClap's fling, fixed the same way) flung out to the SIDES nearly
    # straight (OC_FLING), the clap's turn cross-fading into palms up to the crowd, rolling back to palms-in going down
    CHALK_RITUAL.hands_mix = True
    CHALK_RITUAL.hands = [CHALK_RITUAL.hands,
                          dict(FLING_PALMS_UP, weight=[(0.0, 0.0), (1.95, 0.0), (2.15, 1.0), (2.6, 1.0), (3.1, 0.0),
                                                       (3.4, 0.0)])]
if S.RIG == "torso":
    # (torso rig, 2026-11-13, the user's flagged move) each big arm swing goes round the shoulder on the arm's arc: the
    # explosion from swung back to up-and-out and the lowering snapped (~1,800 degrees a second) along straight lines
    # that cut inside the arms' reach
    # the arms-up spot pulled just inside the reach (beyond it every arm shape lands about as close, and the solver
    # jumped between them as the arms started down); the lowering's arc point likewise
    _reach = S.reach(1.488) + 0.125
    WC_UP_OUT = SHOULDER_NOW + (UP_OUT - SHOULDER_NOW).normalized() * min((UP_OUT - SHOULDER_NOW).length, 0.97 * _reach)
    # (2026-11-15, user rule §5.0.1: the swung-back arms sat bent with the elbows 1.1 behind the shoulders, QA
    # elbow_back FAIL) the arms swung back STRAIGHT, 30 degrees behind the leaning chest (measured on the crouched
    # body: the hand spot was written for the standing root, so the crouch folded the elbows), the same look; on the
    # explosion the arms come up past the sides at shoulder height (behind the body they raised the elbows backward)
    _wc_body = [(0.0, STAND), (0.5, crouch(0.9, 8.0)), (1.4, crouch(1.0, 10.0)), (1.7, dict(STAND, neck=26.0)),
                (2.8, dict(STAND, neck=24.0)), (3.2, STAND), (3.6, STAND)]
    _wc_back = (-0.3, -math.cos(math.radians(26.0)), math.sin(math.radians(26.0)))
    WC_BACK = on_arm([(0.0, crouch(0.95, 9.0))], 0.0, _wc_back, 0.995)
    WC_START = arc_mid(HANG_HAND, WC_BACK)
    WC_DOWN = SHOULDER_NOW + (arc_mid(WC_UP_OUT, HANG_HAND) - SHOULDER_NOW).normalized() * 0.97 * _reach
    _wc_hands = [(0.0, HANG_HAND), (0.25, WC_START), (0.5, WC_BACK), (1.4, WC_BACK),
                 (1.47, on_arm(_wc_body, 1.47, (-0.6, -0.75, 0.3))), (1.55, on_arm(_wc_body, 1.55, (-1.0, -0.15, 0.05))),
                 (1.62, on_arm(_wc_body, 1.62, (-0.9, 0.45, -0.1))),
                 (1.7, WC_UP_OUT), (2.8, WC_UP_OUT), (3.02, WC_DOWN), (3.25, HANG_HAND), (3.6, HANG_HAND)]
else:
    _wc_hands = [(0.0, HANG_HAND), (0.5, SWUNG_BACK), (1.4, SWUNG_BACK), (1.7, UP_OUT), (2.8, UP_OUT),
                 (3.25, HANG_HAND), (3.6, HANG_HAND)]
WAR_CROUCH = Hype(3.6,
                  [(0.0, STAND), (0.5, crouch(0.9, 8.0)), (1.4, crouch(1.0, 10.0)), (1.7, dict(STAND, neck=26.0)),
                   (2.8, dict(STAND, neck=24.0)), (3.2, STAND), (3.6, STAND)],   # (_wc_body: the same keys)
                  _wc_hands,
                  wobble=lambda t: Vector((shake(t, 0.55, 1.4, 0.04, 12.0) + shake(t, 1.75, 2.8, 0.06, 10.0),
                                           shake(t, 1.75, 2.8, 0.05, 8.0), 0)))
if S.RIG == "torso":
    # (2026-11-15) the arms solved with their elbows told where to point: back (natural) while swung back, turning out
    # to the sides as the arms sweep up past them (the free solve bent them backward on the way up)
    WAR_CROUCH.elbows = [(0.0, EL_HANG), (1.4, EL_HANG), (1.7, EL_OUT), (2.8, EL_OUT), (3.25, EL_HANG), (3.6, EL_HANG)]
    WAR_CROUCH.arcs = True
    # (2026-11-28, checked with Hype_OverheadClap's twist fix: NOT the same fault) up roaring with the arms up and out,
    # the hands face the crowd (palms forward, thumbs toward the head, elbow creases up: the arms simply raised from
    # palms-forward), and they stay turned the same way into and out of it; left as it was

if S.RIG == "torso":
    # (2026-11-16, rule §5.0.17) hands and forearms kept outside the worn outfit on every build (Hype.outfit)
    for _h in (BELT, FLEX_HYPE, CHEST_SLAP, NECK_ROLL, OVERHEAD_CLAP, WINGS_V, TRAP_SLAP, CROWD_LIFT, CHALK_RITUAL,
               WAR_CROUCH):
        _h.outfit = True
    # the claps in front of the chest: pushed out of the clothes forward and up only, so the palms still meet
    BELT.outfit_margin = 0.06      # (the hands flat on the belt front: the boxy hand model reads ~0.04 shallow there)
    BELT.outfit_claps = [(0.0, 0.0), (1.8, 0.0), (1.97, 1.0), (2.25, 1.0), (2.45, 0.0), (3.0, 0.0)]
    NECK_ROLL.outfit_claps = [(0.0, 0.0), (1.45, 0.0), (1.8, 1.0), (2.25, 1.0), (2.36, 0.0), (3.0, 0.0)]
    TRAP_SLAP.outfit_keep = 0.004
    TRAP_SLAP.outfit_claps = [(0.0, 0.0), (1.15, 0.0), (1.35, 1.0), (1.65, 1.0), (1.85, 0.0), (3.0, 0.0)]

HYPES = {"Belt": BELT, "Flex": FLEX_HYPE, "ChestSlap": CHEST_SLAP, "NeckRoll": NECK_ROLL,
         "OverheadClap": OVERHEAD_CLAP, "WingsV": WINGS_V, "TrapSlap": TRAP_SLAP, "CrowdLift": CROWD_LIFT,
         "ChalkRitual": CHALK_RITUAL, "WarCrouch": WAR_CROUCH}

# Touch_GameFace: played over the walk (Action priority) with only the arms keyed, so the legs and hips keep walking;
# the server times it to end as the walk does. Claps at 0.32 and 0.56 s (EntranceConfig.QuickTouch.clapSeconds).
NEAR = on_body(-0.82, 0.4, -1.08)
GAME_FACE = Hype(1.5,
                 [(0.0, STAND), (1.5, STAND)],
                 [(0.0, HANG_HAND), (0.2, APART), (0.32, CLAP), (0.44, NEAR), (0.56, CLAP), (0.78, BELT_FRONT),
                  (0.9, BELT_TUG), (1.02, BELT_FRONT), (1.5, HANG_HAND)])
if S.RIG == "torso":
    # (2026-11-15, QA arm_in_body FAIL; the claps left the hands a stud apart) the two claps are open palms meeting in
    # front of the chest and the taps land ON the belt, as in Hype_Belt (palms in, a touch forward of the Fat belly);
    # the clap times stay (EntranceConfig.QuickTouch.clapSeconds 0.32, 0.56)
    GF_NEAR = Vector((-0.6, NEAR.y, NEAR.z - 0.15))
    GAME_FACE = Hype(1.5, [(0.0, STAND), (1.5, STAND)],
                     [(0.0, HANG_HAND), (0.2, BH_APART), (0.32, BH_CLAP), (0.44, GF_NEAR), (0.56, BH_CLAP),
                      (0.78, BH_FRONT), (0.9, BH_TUG), (1.02, BH_FRONT), (1.5, HANG_HAND)])
    GAME_FACE.elbows = [(0.0, EL_HANG), (0.15, _EL_CLAP), (0.6, _EL_CLAP), (0.75, _EL_BELT), (1.05, _EL_BELT),
                        (1.5, EL_HANG)]
    # (one hand turn hands over to the other with both at zero: the stronger one wins, so an overlap would jump)
    GAME_FACE.hands = [dict(CLAP_FRONT, weight=[(0.0, 0.0), (0.15, 0.0), (0.28, 1.0), (0.57, 1.0), (0.67, 0.0),
                                                (1.5, 0.0)]),
                       dict(BELT_HANDS, weight=[(0.0, 0.0), (0.67, 0.0), (0.78, 1.0), (1.05, 1.0), (1.25, 0.0),
                                                (1.5, 0.0)])]
if S.RIG == "torso":
    GAME_FACE.outfit = True          # (2026-11-16, rule §5.0.17: the claps and belt taps on the clothes, not in them)
    GAME_FACE.outfit_margin = 0.06
    GAME_FACE.outfit_claps = [(0.0, 0.0), (0.15, 0.0), (0.28, 1.0), (0.57, 1.0), (0.67, 0.0), (1.5, 0.0)]
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
           f'<float name="AuthoredHipHeight">{S.AUTHORED_HIP_HEIGHT:g}</float><bool name="Loop">{"true" if looped else "false"}</bool>'
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
        lines.append(f"Hype_{name}: {h.length} s, worst hand miss {h.worst:.3f}" +
                     (f", outfit rounds {h.outfit_log}" if h.outfit else ""))
    for name, h in TOUCHES.items():
        if h.outfit:
            h.pose(0.0)
            lines.append(f"Touch_{name}: outfit rounds {h.outfit_log}")
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
    centre = far / 2 + Vector((0, 0, 2.6 + (S.HRP_STAND_Y - 3.0)))      # (the taller rig: framed 0.4 higher)
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
        objs = _figure(bpy, name, COLOURS[lane % len(COLOURS)])
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
        objs = _figure(bpy, name, COLOURS[lane % len(COLOURS)])
        for f in range(0, frames + 1):
            _place(objs, h.pose(min(h.length, f / 30)), Vector((lane * 4.5, 0, 0)), frame=f + 1)
    _floor_lines(bpy, -2.5, 3 * 4.5 + 2.5, -3, 3, 6.0)
    centre = Vector((3 * 4.5 / 2, 0, 2.6 + (S.HRP_STAND_Y - 3.0)))
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
