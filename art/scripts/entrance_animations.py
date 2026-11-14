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
    "SuperHeavy": {"period": 1.1, "thigh": 24.0, "swing_flex": 45.0, "stance_flex": 12.0, "toe_up": 5.0, "stamp": True,
                   "stance": 9.0, "toes": 18.0, "torso": -4.0, "lean_bob": 1.5, "sway": 10.0, "hip_turn": 2.0,
                   "shoulder_turn": 12.0, "arm_swing": 8.0, "arm_raise": 38.0, "arm_twist": 25.0, "elbow": 30.0,
                   "neck": -3.0},
    "WarCry": {"period": 0.95, "thigh": 30.0, "swing_flex": 50.0, "stance_flex": 22.0, "toe_up": 6.0,
               "stance": 4.0, "toes": 12.0, "torso": -18.0, "lean_bob": 3.0, "sway": 3.0, "hip_turn": 3.0,
               "shoulder_turn": 8.0, "arm_swing": 18.0, "arm_raise": 20.0, "elbow": 38.0, "neck": 14.0,
               "arms": _war_cry},
})
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
        left = hand_at(self.left_keys, t) + extra
        right = (hand_at(self.right_keys, t) if self.right_keys else mirror(hand_at(self.left_keys, t))) + mirror(extra)
        return left, right

    def _solve(self):
        """The arms solved once, in time order from the start, every STEP: each solve starts from the one before, so
        the arms never flip to another way of reaching the same spot, and every caller gets the same answer."""
        a_left, a_right = dict(START_ARM), dict(START_ARM)
        self.table, self.wrists = [], []
        I3 = Matrix.Identity(3)
        for i in range(int(math.ceil(self.length / self.STEP)) + 1):
            t = min(self.length, i * self.STEP)
            p = body_at(self.body, t)
            body = F._body(p, p["root"])
            left, right = self._targets(t)
            if self.contact:
                frames = S.forward_kinematics(Matrix.Identity(4), body)
                left, right = S.contact_out(left, frames), S.contact_out(right, frames)
            a_left = self._solve_one(body, left, a_left)
            a_right = self._solve_one(body, mirror(right), a_right)
            wrist = {"Left": I3.to_quaternion(), "Right": I3.to_quaternion()}
            w = self._palm_weight(t)
            if w > 0:
                a_left, a_right, wrist = self._palm_solve(body, left, right, a_left, a_right, w)
            if self.hands and S.RIG == "torso":
                specs = self.hands if isinstance(self.hands, list) else [self.hands]
                ws = {sd: max([(self._track(sp["weight"], t), sp) for sp in specs if sd in sp.get("sides", ("Left", "Right"))]
                              or [(0.0, None)], key=lambda x: x[0]) for sd in ("Left", "Right")}
                if ws["Left"][0] > 0 or ws["Right"][0] > 0:
                    a_left, a_right, wrist = self._turn_solve(body, left, right, a_left, a_right, ws, wrist)
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
            along = fingers - n * fingers.dot(n)
            target = free.lerp(on_skin, w)
            sh, el = S._arm_tf(side, start)
            c0s, c1s = S.JOINTS[side + "Shoulder"][2], S.JOINTS[side + "Shoulder"][3]
            c0e, c1e = S.JOINTS[side + "Elbow"][2], S.JOINTS[side + "Elbow"][3]
            lower = ut @ S.T(c0s) @ sh @ S.T(c1s).inverted() @ S.T(c0e) @ el @ S.T(c1e).inverted()
            free_rot = lower.to_3x3()
            rot = free_rot.to_quaternion().slerp(S.hand_frame(side, -n, along).to_quaternion(), w).to_matrix()
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

    def _pref(self, w, a):
        c = preference(w, a)
        if self.natural:
            c += 0.02 * max(0.0, -a["raise"] - 12.0)
        return c

    def _solve_one(self, body, target, start):
        pref = self._pref if self.natural else preference
        a, cost = S.solve_arms(body, target, start, pref, 5.0, SOLVE_STEPS)
        if cost > self.RETRY_COST:
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
WINGS_V = Hype(3.2,
               [(0.0, STAND), (0.5, dict(STAND, neck=4.0)), (1.25, dict(STAND, neck=6.0)), (1.6, dip(0.35, 26.0)),
                (2.5, dip(0.4, 28.0)), (2.9, STAND), (3.2, STAND)],
               [(0.0, HANG_HAND), (0.5, WING), (1.25, WING), (1.6, V_UP), (2.5, V_UP), (2.95, HANG_HAND),
                (3.2, HANG_HAND)],
               wobble=lambda t: Vector((0, shake(t, 0.55, 1.2, 0.03, 6.0) + shake(t, 1.65, 2.5, 0.05, 10.0), 0)))
TRAP_SLAP = Hype(3.0,
                 [(0.0, STAND), (0.35, dict(STAND, neck=-6.0)), (1.0, dict(STAND, neck=-8.0)), (1.4, dip(0.6, -10.0)),
                  (1.7, dict(STAND, neck=6.0)), (2.4, dict(STAND, neck=10.0)), (3.0, STAND)],
                 [(0.0, HANG_HAND), (0.35, TRAP_OFF), (0.5, TRAP), (0.65, TRAP_OFF), (0.8, TRAP), (1.15, APART),
                  (1.4, CLAP), (1.6, CLAP), (2.0, ROAR), (2.5, ROAR), (3.0, HANG_HAND)],
                 wobble=lambda t: Vector((shake(t, 2.0, 2.5, 0.06, 10.0), 0, 0)))
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
def arc_mid(a, b, shoulder=SHOULDER_NOW):
    """Half way between two hand spots ON the arm's arc round the shoulder (a straight line between them cuts inside
    the arm's reach: the elbow folds and snaps open on the way). Left-hand spots, root frame."""
    u, v = a - shoulder, b - shoulder
    d = u.normalized() + v.normalized()
    if d.length < 1e-4:                       # (straight opposite: go round by the side)
        d = Vector((-1.0, 0.0, 0.0))
    return shoulder + d.normalized() * (u.length + v.length) / 2


if S.RIG == "torso":
    # (torso rig, 2026-11-13, the user's flagged move) each big arm swing goes round the shoulder on the arm's arc: the
    # explosion from swung back to up-and-out and the lowering snapped (~1,800 degrees a second) along straight lines
    # that cut inside the arms' reach
    # the arms-up spot pulled just inside the reach (beyond it every arm shape lands about as close, and the solver
    # jumped between them as the arms started down); the lowering's arc point likewise
    _reach = S.reach(1.488) + 0.125
    WC_UP_OUT = SHOULDER_NOW + (UP_OUT - SHOULDER_NOW).normalized() * min((UP_OUT - SHOULDER_NOW).length, 0.97 * _reach)
    WC_START = arc_mid(HANG_HAND, SWUNG_BACK)
    WC_UP = arc_mid(SWUNG_BACK, WC_UP_OUT)
    WC_DOWN = SHOULDER_NOW + (arc_mid(WC_UP_OUT, HANG_HAND) - SHOULDER_NOW).normalized() * 0.97 * _reach
    _wc_hands = [(0.0, HANG_HAND), (0.25, WC_START), (0.5, SWUNG_BACK), (1.4, SWUNG_BACK), (1.55, WC_UP),
                 (1.7, WC_UP_OUT), (2.8, WC_UP_OUT), (3.02, WC_DOWN), (3.25, HANG_HAND), (3.6, HANG_HAND)]
else:
    _wc_hands = [(0.0, HANG_HAND), (0.5, SWUNG_BACK), (1.4, SWUNG_BACK), (1.7, UP_OUT), (2.8, UP_OUT),
                 (3.25, HANG_HAND), (3.6, HANG_HAND)]
WAR_CROUCH = Hype(3.6,
                  [(0.0, STAND), (0.5, crouch(0.9, 8.0)), (1.4, crouch(1.0, 10.0)), (1.7, dict(STAND, neck=26.0)),
                   (2.8, dict(STAND, neck=24.0)), (3.2, STAND), (3.6, STAND)],
                  _wc_hands,
                  wobble=lambda t: Vector((shake(t, 0.55, 1.4, 0.04, 12.0) + shake(t, 1.75, 2.8, 0.06, 10.0),
                                           shake(t, 1.75, 2.8, 0.05, 8.0), 0)))

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
