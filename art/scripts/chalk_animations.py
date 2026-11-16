# Chalking up before an attempt (GAME_DESIGN.md 37.5, user 2026-11-06), on the same Roblox R15 block rig and tools as
# the station reps (station_animations.py) and the fails (fail_animations.py):
#   Chalk_Lifter      leans to the stand, hands in the bowl, rubs them, comes up rubbing palms, claps twice, relaxes
#   Chalk_Coach_Back  behind the lifter on squat: rubs chalk across their upper back, two slaps, hands down
#   Chalk_Coach_Talk  in front of the lifter: holds the clipboard, talks with the other hand, nods
# All looped. Chalk_Lifter and Chalk_Coach_Back are the same length and start together; the claps and slaps fall at
# CLAPS and SLAPS, kept in step with LocalMeetConfig.Chalk.
#
# (2026-11-16, user rule §5.0.17) Chalk_Lifter and Chalk_Coach_Back keep hands and forearms outside their own worn
# outfit on every build (entrance_animations Hype.outfit); the coach's slaps on the lifter are held exactly in place.
#
# Distances: the lifter stands STAND_AHEAD from the stand's post (LocalMeetVenue), the coach COACH_BEHIND behind them.
#
#   blender -b --factory-startup --python art/scripts/chalk_animations.py -- <preview.png>
# writes art/animations/Chalk_<Name>.rbxmx and a preview of the key moments next to the real stand. Publish with
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

STAND_AHEAD = 1.75
COACH_BEHIND = 2.0
LOOP_SECONDS = 9.0
TALK_SECONDS = 4.0
CLAPS = (4.4, 4.77)
SLAPS = (4.85, 5.15)

# Hand targets are in the root part's frame, written for the block rig and moved onto the taller rig (user 2026-11-12,
# lifter_heights.py): heights on the body through S.hand_on_body (S.up_body kept within the arm's reach), the hanging
# hand one arm's length (S.reach) below the shoulder.
HANG_HAND = Vector((-1.5, S.up_body(0.763) - S.reach(1.488) - 0.125, 0.0))
STAND = {"torso": 0.0, "thigh": 0.0, "shin": 0.0, "toes": S.SQUAT_TOES_OUT, "neck": 0.0}
LEAN = {"torso": -20.0, "thigh": 12.0, "shin": -4.5, "toes": S.SQUAT_TOES_OUT, "neck": -4.0}
LOOK_AT_HANDS = {"torso": -3.0, "thigh": 2.0, "shin": -1.0, "toes": S.SQUAT_TOES_OUT, "neck": -8.0}
LOOK_AT_BACK = {"torso": -3.0, "thigh": 2.0, "shin": -1.0, "toes": S.SQUAT_TOES_OUT, "neck": -3.0}
SOLVE_STEPS = (4, 2, 1, 0.5, 0.25)
START_ARM = {"raise": 0.0, "swing": 45.0, "twist": 0.0, "elbow": 45.0}


def body_at(keys, t):
    a, b, u = F.at(keys, t)
    p = {k: a[k] + (b[k] - a[k]) * u for k in a}
    p["arm"] = F.HANG
    return F.planted(p)


def hand_at(keys, t):
    a, b, u = F.at(keys, t)
    return a.lerp(b, u)


def wave(t, t0, t1, hz):
    """A smooth back and forth between t0 and t1, faded in and out."""
    if t <= t0 or t >= t1:
        return 0.0
    edge = min(1.0, (t - t0) / 0.2, (t1 - t) / 0.2)
    return edge * math.sin(2 * math.pi * hz * (t - t0))


def mirror(v):
    return Vector((-v.x, v.y, v.z))


def preference(_world, a):
    # Elbows down and out, no needless twist: the hand's position alone leaves the arm free to turn oddly.
    return 0.002 * abs(a["twist"]) + 0.001 * abs(a["raise"])


class Clip:
    """One animation: `body(t)` gives a planted body, `hands(t)` both hands' centres in the root part's frame (the
    right hand given as its own true position). Each arm is solved on its own, so the hands can move differently."""

    def __init__(self, name, length, body, hands, contact=False):
        self.name, self.length, self.body, self.hands = name, length, body, hands
        self.contact = contact and S.RIG == "torso"     # (hands stop at the skin: S.contact_out)
        self.clear_of_builds = ()                       # (torso rig) builds whose skin the hands keep clear of
        self.cache = {}
        self.left, self.right = dict(START_ARM), dict(START_ARM)
        self.worst = 0.0

    def pose(self, t):
        key = round(t, 3)
        if key in self.cache:
            return self.cache[key]
        p = self.body(t)
        body = F._body(p, p["root"])
        left, right = self.hands(t)
        if self.contact:
            frames = S.forward_kinematics(Matrix.Identity(4), body)
            left, right = S.contact_out(left, frames), S.contact_out(right, frames)
        if self.clear_of_builds and S.RIG == "torso":
            # hands that must NOT touch the body (holding, talking): kept a hand's half-thickness plus a gap in front of
            # the deepest bodies' skin, so they clear every build (slimmer builds hold them a little further out)
            frames = S.forward_kinematics(Matrix.Identity(4), body)
            for build in self.clear_of_builds:
                left = S.contact_out(left, frames, depth=S.HAND_HALF + 0.12, build=build)
                right = S.contact_out(right, frames, depth=S.HAND_HALF + 0.12, build=build)
        pref = preference
        if self.clear_of_builds and S.RIG == "torso":
            builds = self.clear_of_builds

            def pref(w, a, builds=builds):
                # (torso rig) the upper arm, elbow and forearm kept off the bigger builds' skin while the hand reaches
                # its spot, so the arm angles out round the body instead of through it; the hand follows the arm
                c = preference(w, a)
                sh, el, wr = (S.joint_point(w, j) for j in ("LeftShoulder", "LeftElbow", "LeftWrist"))
                for q in (el, el.lerp(wr, 0.33), el.lerp(wr, 0.66)):     # (elbow and forearm: the upper arm always meets
                    #  the thick shoulder near the joint)
                    for build in builds:
                        near = S._skin_near(q, w, build)
                        if near is not None:
                            c += 6.0 * max(0.0, 0.10 - near[0])
                return c
        reach_weight = 25.0 if (self.clear_of_builds and S.RIG == "torso") else 5.0   # (reaching the spot first; the
        # clearance then only chooses HOW the arm gets there: the elbow swung out round the body)
        a_left, miss_left = S.solve_arms(body, left, self.left, pref, reach_weight, SOLVE_STEPS)
        a_right, miss_right = S.solve_arms(body, mirror(right), self.right, pref, reach_weight, SOLVE_STEPS)
        self.left, self.right = a_left, a_right
        pose = dict(body)
        from_left, from_right = S.arms(a_left), S.arms(a_right)
        pose["LeftShoulder"], pose["LeftElbow"] = from_left["LeftShoulder"], from_left["LeftElbow"]
        pose["RightShoulder"], pose["RightElbow"] = from_right["RightShoulder"], from_right["RightElbow"]
        w = S.forward_kinematics(Matrix.Identity(4), pose)
        self.worst = max(self.worst, (w["LeftHand"].to_translation() - left).length,
                         (w["RightHand"].to_translation() - right).length)
        self.cache[key] = pose
        return pose


# ---------------------------------------------------------------- the lifter
BOWL_HAND = Vector((-0.55, 2.88 - S.HRP_STAND_Y, -STAND_AHEAD + 0.3))     # the bowl stays where it is (2.88 up)
CHEST_HAND = S.hand_on_body(-0.5, 0.35, -1.05)
APART_HAND = S.hand_on_body(-1.05, 0.42, -1.1)
LOW_HAND = S.hand_on_body(-0.55, 0.0, -1.0)
LIFTER_HANDS = [
    (0.0, HANG_HAND), (0.5, HANG_HAND), (1.1, BOWL_HAND), (2.3, BOWL_HAND), (2.9, CHEST_HAND), (4.0, CHEST_HAND),
    (4.2, APART_HAND), (CLAPS[0], CHEST_HAND), (4.6, APART_HAND), (CLAPS[1], CHEST_HAND), (5.1, LOW_HAND),
    (5.8, HANG_HAND), (LOOP_SECONDS, HANG_HAND),
]
LIFTER_BODY = [(0.0, STAND), (0.5, STAND), (1.1, LEAN), (2.3, LEAN), (2.9, LOOK_AT_HANDS), (5.1, LOOK_AT_HANDS),
               (5.8, STAND), (LOOP_SECONDS, STAND)]


def lifter_body(t):
    p = body_at(LIFTER_BODY, t)
    return p


def lifter_hands(t):
    base = hand_at(LIFTER_HANDS, t)
    # Hands working in the bowl, then palms rubbing together, each hand opposite the other.
    bowl = wave(t, 1.15, 2.25, 2.2)
    palms = wave(t, 3.0, 3.95, 2.4)
    left = base + Vector((0, 0.03 * bowl + 0.18 * palms, 0.12 * bowl))
    right = mirror(base) + Vector((0, -0.03 * bowl - 0.18 * palms, -0.12 * bowl))
    return left, right


# ---------------------------------------------------------------- the coach, behind the lifter (squat)
ON_BACK = S.hand_on_body(-0.62, 0.35, -(COACH_BEHIND - 0.7))
OFF_BACK = ON_BACK + Vector((0, 0.1, 0.3))
COACH_BACK_HANDS = [
    (0.0, HANG_HAND), (0.3, HANG_HAND), (0.9, ON_BACK), (4.55, ON_BACK), (4.72, OFF_BACK), (SLAPS[0], ON_BACK),
    (5.02, OFF_BACK), (SLAPS[1], ON_BACK), (5.4, ON_BACK), (6.1, HANG_HAND), (LOOP_SECONDS, HANG_HAND),
]
COACH_BACK_BODY = [(0.0, STAND), (0.3, STAND), (0.9, LOOK_AT_BACK), (5.4, LOOK_AT_BACK), (6.1, STAND), (LOOP_SECONDS, STAND)]


def coach_back_body(t):
    return body_at(COACH_BACK_BODY, t)


def coach_back_hands(t):
    base = hand_at(COACH_BACK_HANDS, t)
    # Rubbing the chalk across the upper back, the hands going opposite ways.
    rub = wave(t, 1.0, 4.5, 1.3)
    side = wave(t, 1.0, 4.5, 0.65)
    return (base + Vector((0.12 * side, 0.2 * rub, 0)),
            mirror(base) + Vector((0.12 * side, -0.2 * rub, 0)))


# ---------------------------------------------------------------- the coach, in front of the lifter, talking
HOLD = S.hand_on_body(-0.62, -0.2, -1.05)
TALK_LOW = S.hand_on_body(-0.9, -0.1, -1.1)     # (2026-11-16, legs fix 2: was (-0.78, -0.1, -1.0); at rest the talking
#   arm's forearm brushed 0.05 into Fat's worn belt at its side (anim_qa arm_in_outfit, rule 17): a touch further out and
#   forward. The loop still starts and ends on it.)
TALK_HIGH = S.hand_on_body(-0.7, 0.36, -1.2)
TALK_MID = S.hand_on_body(-0.76, 0.14, -1.1)
TALK_HAND = [(0.0, TALK_LOW), (1.0, TALK_HIGH), (1.5, TALK_MID), (2.2, TALK_HIGH), (3.2, TALK_LOW), (TALK_SECONDS, TALK_LOW)]


def coach_talk_body(t):
    nod = 4.0 * math.sin(2 * math.pi * t * 2 / TALK_SECONDS)
    p = dict(STAND, neck=-3.0 + nod)
    p["arm"] = F.HANG
    return F.planted(p)


def coach_talk_hands(t):
    return HOLD, mirror(hand_at(TALK_HAND, t))


if S.RIG == "torso":
    # (torso rig, 2026-11-13, the user's flagged move) the chalk-up on the approved clap method of Hype_NeckRoll
    # (entrance_animations.Hype): the old one-pose-at-a-time solve swung the arms up into an X in front of the face
    # (upper arm 0.4 into the head) coming up from the bowl, the "together" hands were a full stud apart, and the
    # hands went down through the Fat belly (0.46). Now: solved in time order from the start, arms kept out of the
    # twisted raised-backwards shape (natural), palms really together for the rub and the claps, turned palm to palm
    # with the fingers forward and up, palms down in the bowl, and the hands swing down to the side on the arm's arc.
    # Same timing, same claps (LocalMeetConfig.Chalk).
    _espec = importlib.util.spec_from_file_location("entrance_animations", os.path.join(_HERE, "entrance_animations.py"))
    E = importlib.util.module_from_spec(_espec)
    _espec.loader.exec_module(E)
    RUB_HAND = Vector((-0.2, CHEST_HAND.y, CHEST_HAND.z - 0.2))         # palms meet (E.NR_CLAP)
    CLAP_APART = Vector((APART_HAND.x, APART_HAND.y, APART_HAND.z - 0.1))
    # after the last clap the hands part out to the sides, then drop on the arm's arc round the shoulder (straight
    # down from the clap they went through the Fat belly)
    PART_HAND = Vector((APART_HAND.x - 0.3, APART_HAND.y - 0.4, APART_HAND.z + 0.05))   # out wide and forward
    TO_BOWL = E.arc_mid(HANG_HAND, BOWL_HAND)                           # (forward round the shoulder, clear of the belly)
    DOWN_ARC = E.arc_mid(PART_HAND, HANG_HAND)
    # (2026-11-16, longer-thigh rebuild: the solve ends the hang with the upper arm turned 58 deg from the first frame;
    #  while the loop's last 0.6 s eases it back, Skinny's fingertips brushed 0.05 into the singlet's shorts, anim_qa.
    #  The hands hang a touch further out after the claps, so the ease back stays clear; the first frame is unchanged.)
    HANG_END = HANG_HAND + Vector((-0.12, 0.0, 0.0))
    LIFTER_HANDS = [
        (0.0, HANG_HAND), (0.5, HANG_HAND), (0.8, TO_BOWL), (1.1, BOWL_HAND), (2.3, BOWL_HAND), (2.9, RUB_HAND),
        (4.0, RUB_HAND),
        (4.2, CLAP_APART), (CLAPS[0], RUB_HAND), (4.6, CLAP_APART), (CLAPS[1], RUB_HAND), (5.0, PART_HAND),
        (5.4, DOWN_ARC), (5.8, HANG_END), (LOOP_SECONDS, HANG_END),
    ]

    class _LifterHype(E.Hype):
        def _targets(self, t):
            return lifter_hands(t)

    class HypeClip:
        """A chalk clip on the Hype solver (export() and preview() only need name, length, pose and worst)."""

        def __init__(self, name, hype):
            self.name, self.length, self.hype = name, hype.length, hype

        @property
        def worst(self):
            return self.hype.worst

        def pose(self, t):
            return self.hype.pose(t)

    _lifter = _LifterHype(LOOP_SECONDS, LIFTER_BODY, [(0.0, HANG_HAND), (LOOP_SECONDS, HANG_HAND)])
    _lifter.natural = True
    _lifter.outfit = True    # (2026-11-16, rule §5.0.17: hands and forearms kept outside the worn tee, singlet, belt)
    # (the rub and the claps: pushed out of the clothes forward and up only, the palms still together)
    # (in the bowl: pushed only further forward over the bowl (1.0 stud round the post), never up or out past its rim:
    # Fat's leaning belly reaches the bowl's near side)
    _lifter.outfit_mirror = True   # (the hands mirror each other but for the rub)
    _lifter.outfit_forward = [(0.0, 0.0), (0.75, 0.0), (0.95, 1.0), (2.3, 1.0), (2.6, 0.0), (LOOP_SECONDS, 0.0)]
    _lifter.outfit_claps = [(0.0, 0.0), (2.62, 0.0), (2.9, 1.0), (CLAPS[1] + 0.05, 1.0), (5.0, 0.0), (LOOP_SECONDS, 0.0)]
    _lifter.keep = 0.01      # (the elbows had swung round the shoulder-hand line frame to frame in the claps)
    _lifter.hands = [
        # in the bowl: palms down, fingers forward
        {"palm": Vector((0.0, -1.0, 0.0)), "fingers": Vector((0.0, 0.0, -1.0)),
         "weight": [(0.0, 0.0), (0.8, 0.0), (1.1, 1.0), (2.3, 1.0), (2.62, 0.0), (LOOP_SECONDS, 0.0)]},
        # the rub and the claps: palm to palm, fingers forward and a little up
        {"palm": Vector((1.0, 0.0, 0.0)), "fingers": Vector((0.0, 0.45, -1.0)),
         "weight": [(0.0, 0.0), (2.62, 0.0), (2.9, 1.0), (CLAPS[1] + 0.05, 1.0), (5.15, 0.0), (LOOP_SECONDS, 0.0)]},
    ]

    # (torso rig, 2026-11-15, user: "the coach is not even slapping the shoulders or neck of the lifter, because the hands
    # are closed and it just looks like hes punching the lifter") The coach behind the lifter: open hands ON the lifter's
    # traps rubbing the chalk in, then the two slaps land flat on top of the SHOULDERS and on the traps at the back of the
    # NECK (before: a fixed spot on the mid-back, 0.35 up the block body), palms down, fingers forward over the shoulder.
    # Same slap times (LocalMeetConfig.Chalk.SlapAt: the game's slap sounds and chalk puffs). The lifter stands
    # COACH_BEHIND ahead; his back surface is ~0.5-1.1 behind his spine by build, so the wrists sit 0.7 behind the
    # lifter's shoulder line (a mid build; the palm reaches forward onto the top of the shoulder).
    _BACK_Z = -(COACH_BEHIND - 0.7)
    ON_TRAPS = S.hand_on_body(-0.5, 1.02, _BACK_Z)          # rubbing chalk on the traps
    ON_SHOULDERS = S.hand_on_body(-0.85, 0.98, _BACK_Z + 0.08)   # slap 1: flat on top of each shoulder
    ON_NECK = S.hand_on_body(-0.38, 1.12, _BACK_Z - 0.05)   # slap 2: the traps at the back of the neck
    LIFTED = Vector((0, 0.42, 0.1))                         # the wind-up between slaps: up off the body (not back at
    #                                                         his own face)
    TO_TRAPS = E.arc_mid(HANG_HAND, ON_TRAPS)
    OUT_SIDE = Vector((HANG_HAND.x - 0.55, (ON_NECK.y + HANG_HAND.y) / 2, -0.55))   # down round the outside (straight
    #                                                         down from the neck went through his own Fat belly)
    COACH_BACK_HANDS = [
        (0.0, HANG_HAND), (0.3, HANG_HAND), (0.62, TO_TRAPS), (0.9, ON_TRAPS), (4.5, ON_TRAPS),
        (4.7, ON_SHOULDERS + LIFTED), (SLAPS[0], ON_SHOULDERS), (5.0, ON_NECK + LIFTED), (SLAPS[1], ON_NECK),
        (5.4, ON_NECK), (5.75, OUT_SIDE), (6.1, HANG_HAND), (LOOP_SECONDS, HANG_HAND),
    ]

    def coach_back_hands(t):
        base = hand_at(COACH_BACK_HANDS, t)
        rub = wave(t, 1.0, 4.4, 1.3)          # rubbing across the traps, the hands going opposite ways
        return (base + Vector((0.1 * rub, 0.04 * rub, 0)), mirror(base) + Vector((0.1 * rub, -0.04 * rub, 0)))

    class _CoachBackHype(E.Hype):
        def _targets(self, t):
            return coach_back_hands(t)

    # (2026-11-16, longer-thigh rebuild of the bodies: the coach's elbows bent 131 deg for the first slap, which folds
    #  BigBuff's forearm 0.27 into its own biceps, anim_qa. He stands a touch more upright for the two slaps, so his
    #  shoulders sit further back and the elbows open; the hands still land on exactly the same spots on the lifter.)
    SLAP_UPRIGHT = dict(LOOK_AT_BACK, torso=3.0)
    COACH_BACK_BODY_T = [(0.0, STAND), (0.3, STAND), (0.9, LOOK_AT_BACK), (4.45, LOOK_AT_BACK), (4.68, SLAP_UPRIGHT),
                         (5.2, SLAP_UPRIGHT), (5.4, LOOK_AT_BACK), (6.1, STAND), (LOOP_SECONDS, STAND)]
    _coach_back = _CoachBackHype(LOOP_SECONDS, COACH_BACK_BODY_T, [(0.0, HANG_HAND), (LOOP_SECONDS, HANG_HAND)])
    _coach_back.natural = True
    _coach_back.outfit = True   # (his own clothes)
    # the slaps land on the LIFTER exactly as before (LocalMeetConfig.Chalk.SlapAt): no push there
    _coach_back.outfit_hold = [(0.0, 0.0), (4.4, 0.0), (4.55, 1.0), (5.25, 1.0), (5.4, 0.0), (LOOP_SECONDS, 0.0)]
    _coach_back.keep = 0.01
    _coach_back.hands = [
        # on the traps and the slaps: palm down on the body, fingers forward over the shoulder
        {"palm": Vector((0.0, -1.0, 0.0)), "fingers": Vector((0.0, 0.0, -1.0)),
         "weight": [(0.0, 0.0), (0.62, 0.0), (0.9, 1.0), (5.4, 1.0), (5.75, 0.0), (LOOP_SECONDS, 0.0)]},
    ]

CLIPS = {
    "Lifter": HypeClip("Lifter", _lifter) if S.RIG == "torso" else Clip("Lifter", LOOP_SECONDS, lifter_body, lifter_hands),
    "Coach_Back": (HypeClip("Coach_Back", _coach_back) if S.RIG == "torso"
                   else Clip("Coach_Back", LOOP_SECONDS, coach_back_body, coach_back_hands)),
    "Coach_Talk": Clip("Coach_Talk", TALK_SECONDS, coach_talk_body, coach_talk_hands),
}
# (torso rig, 2026-11-13, the user's flagged move) the coach's clipboard hand and talking hand stay in front of the body
# instead of sinking into the bigger bellies and chests (Fat 0.35 deep): clear of the deepest builds
CLIPS["Coach_Talk"].clear_of_builds = ("Fat",)


# ---------------------------------------------------------------- export
def sample_times(clip):
    """Every 0.1 s, every 0.05 s where it moves fast (the claps and slaps)."""
    times, t = [], 0.0
    while t < clip.length - 1e-6:
        times.append(round(t, 3))
        t += 0.05 if clip.name != "Coach_Talk" and 4.0 <= t < 5.3 else 0.1
    times.append(clip.length)
    return times


# Every clip here loops: its last this-many seconds ease onto its first frame (export, closed_pose).
LOOP_SEAM_SECONDS = 0.6


def export(clip):
    """Writes art/animations/Chalk_<name>.rbxmx (Action priority, looped)."""
    refs = iter(range(1, 1_000_000))
    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
           f'<Item class="KeyframeSequence" referent="RBX{next(refs)}"><Properties>'
           f'<float name="AuthoredHipHeight">{S.AUTHORED_HIP_HEIGHT:g}</float><bool name="Loop">true</bool>'
           f'<string name="Name">Chalk_{clip.name}</string><token name="Priority">2</token>'
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

    times = sample_times(clip)
    first = clip.pose(0.0)

    def closed_pose(t):
        """The pose at `t`, eased over the last LOOP_SEAM_SECONDS onto the first frame's, so the loop has no seam
        (Studio 2026-11-15: the solver ended Chalk_Lifter with the hand 42 deg and the upper arm 18 deg off its start, a
        one-frame 2400 deg/s jump of the shoulders every time the loop came round)."""
        pose = clip.pose(t)
        u = (t - (clip.length - LOOP_SEAM_SECONDS)) / LOOP_SEAM_SECONDS
        if u <= 0.0:
            return pose
        w = min(1.0, u)
        w = w * w * (3.0 - 2.0 * w)
        out_pose = {}
        for joint, m in pose.items():
            f = first.get(joint)
            if f is None:
                out_pose[joint] = m
                continue
            q = m.to_quaternion().slerp(f.to_quaternion(), w)
            out_pose[joint] = Matrix.Translation(m.to_translation().lerp(f.to_translation(), w)) @ q.to_matrix().to_4x4()
        return out_pose

    for t in times:
        out.append(f'<Item class="Keyframe" referent="RBX{next(refs)}"><Properties>'
                   f'<string name="Name">Keyframe</string><float name="Time">{t:.3f}</float></Properties>')
        out.append(pose_xml("HumanoidRootPart", closed_pose(t)))
        out.append("</Item>")
    out.append("</Item></roblox>")
    os.makedirs(S.OUT_DIR, exist_ok=True)
    path = os.path.join(S.OUT_DIR, f"Chalk_{clip.name}.rbxmx")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    return path, len(times), round(clip.worst, 3)


# ---------------------------------------------------------------- preview: real stand, the key moments side by side
def preview(path):
    import bpy
    import bmesh

    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    stand_file = os.path.join(S.ROOT_DIR, "art", "blender", "LocalMeet_03.blend")
    with bpy.data.libraries.load(stand_file) as (source, target):
        target.objects = [n for n in source.objects if n.startswith("MeetChalkStand_")]
    stand_parts = target.objects

    def colour(name, rgb):
        m = bpy.data.materials.new(name)
        m.diffuse_color = (*rgb, 1)
        return m

    looks = {"lifter_top": colour("LifterTop", (0.8, 0.08, 0.08)), "coach_top": colour("CoachTop", (0.03, 0.06, 0.2)),
             "skin": colour("Skin", (0.75, 0.5, 0.35)), "legs": colour("Legs", (0.12, 0.12, 0.14))}

    def figure(pose, at, top, turn=Matrix.Identity(4)):
        """A block body at `at` (Blender space): `at` is under the root part, on the floor."""
        world = S.forward_kinematics(S.T((0, S.HRP_STAND_Y, 0)), pose)
        for part, size in S.SIZES.items():
            if part == "HumanoidRootPart":
                continue
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Diagonal((*size, 1)))
            mesh = bpy.data.meshes.new(part)
            bm.to_mesh(mesh)
            bm.free()
            mesh.materials.append(looks[top] if "Torso" in part else looks["legs"] if "Leg" in part or "Foot" in part
                                  else looks["skin"])
            ob = bpy.data.objects.new(part, mesh)
            bpy.context.scene.collection.objects.link(ob)
            ob.matrix_world = Matrix.Translation(at) @ turn @ S.TO_BLENDER @ world[part]

    def stand_at(at):
        for source in stand_parts:
            ob = source.copy()
            bpy.context.scene.collection.objects.link(ob)
            ob.location = source.location + at

    # Roblox faces -Z, which TO_BLENDER turns into Blender -Y. The moments in a row along Y, seen from the side.
    moments = (("Lifter", 0.3), ("Lifter", 1.7), ("Lifter", 3.5), ("Lifter", CLAPS[0]), ("Back", 2.3), ("Back", SLAPS[0]),
               ("Talk", 1.0))
    for index, (kind, t) in enumerate(moments):
        at = Vector((0, index * 8.5, 0))
        if kind == "Lifter":
            figure(CLIPS["Lifter"].pose(t), at, "lifter_top")
            stand_at(at + Vector((0, -STAND_AHEAD, 0)))
        elif kind == "Back":
            figure(CLIPS["Lifter"].pose(t), at, "lifter_top")
            stand_at(at + Vector((0, -STAND_AHEAD, 0)))
            figure(CLIPS["Coach_Back"].pose(t), at + Vector((0, COACH_BEHIND, 0)), "coach_top")
        else:
            figure(CLIPS["Lifter"].pose(0.2), at, "lifter_top")
            # The coach a step in front, turned to face the lifter.
            figure(CLIPS["Coach_Talk"].pose(t), at + Vector((0, -3.2, 0)), "coach_top", Matrix.Rotation(math.pi, 4, "Z"))
    scene = bpy.context.scene
    camera = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 60
    centre = Vector((0, 3 * 8.5 - 0.5, 2.8))
    camera.location = centre + Vector((-40.0, -9.0, 6.0))
    camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_backface_culling = True
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.55, 0.57, 0.6)
    scene.display.shading.background_type = "WORLD"
    scene.render.resolution_x, scene.render.resolution_y = 1800, 420
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    for clip in CLIPS.values():
        print("EXPORTED", export(clip))
        if getattr(getattr(clip, "hype", None), "outfit", None):
            print("OUTFIT", clip.name, clip.hype.outfit_log)
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argv:
        preview(argv[0])
    print("DONE")
