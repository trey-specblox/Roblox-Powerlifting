# The celebrations after a good lift (GAME_DESIGN.md §36.4; user 2026-11-11: "Make all the celebrations you want ...
# tons of emphasis ... if there is a REALLY dramatic celebration, you can add cinematic to them"). Each one is a real
# lifter's celebration from the user's 15 meet videos, move by move from References/Clip Study/Celebration Catalogue.md
# (its CEL number is in each clip's notes), adapted to the game: it starts and ends standing at the lift spot, clear of
# the bar (the bar is already back in the rack or on the floor), facing the front. Built on celebration_rig.py.
#
# Two kinds:
#   standing   the whole body, on the spot (the server waits for it, then walks the lifter back)
#   walk       arms and head only, played over the walk back (CEL-59, CEL-51: real lifters never stop walking)
#
#   blender -b --factory-startup --python art/scripts/celebration_animations.py -- [preview folder] [names...]
# checks every clip, writes art/animations/Celebrate_<Name>.rbxmx, and with a folder renders preview sheets (front and
# side) of each. Publish with art/scripts/upload_animations.py; ids go in src/shared/Config/CelebrationConfig.luau.
import importlib.util
import math
import os
import sys

from mathutils import Vector

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\Powerlifting Roblox\art\scripts"
_spec = importlib.util.spec_from_file_location("celebration_rig", os.path.join(_HERE, "celebration_rig.py"))
R = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(R)

REST = R.REST
ANKLE = R.STAND_ANKLE["Left"]          # the left ankle standing (floor space)
AY, AZ = ANKLE.y, ANKLE.z


# ---------------------------------------------------------------- pose vocabulary (left hand, chest frame; mirrored)
def mx(v):
    return (-v[0], v[1], v[2])


def both(left, right=None):
    """Both hands in the chest frame: the right is the left mirrored unless given (in its own true position)."""
    return {"lh": ("chest", left), "rh": ("chest", right if right is not None else mx(left))}


def rest():
    return {"lh": REST, "rh": REST}


V_UP = (-1.78, 2.05, -0.2)          # arms up in a wide V
SKY = (-1.02, 2.3, -0.2)            # an arm straight up (a finger to the sky)
T_OUT = (-2.7, 0.62, -0.25)         # an arm straight out to the side
LOW_WING = (-2.2, -0.62, -0.35)     # out and 45 degrees down
HEAD_TOP = (-0.5, 2.08, 0.34)       # hand on top of the head, toward the back (the face stays clear)
HEAD_TOP_R = (0.46, 2.14, 0.3)      # the right hand stacked a little higher
FIST_CHEST = (-0.5, 0.55, -0.95)    # a boxer's guard at the chest
FIST_LOW = (-0.6, -1.15, -0.85)     # fists pulled down in front of the hips
BICEP = (-1.95, 1.38, 0.0)          # double biceps: fist beside the head, upper arm out level
GOALPOST = (-1.95, 1.05, -0.15)
CLAP = (-0.5, 0.2, -1.05)           # hands together at the chest (1-stud hands: centres 1 apart = touching)
CLAP_APART = (-1.05, 0.25, -1.1)
HIPS = (-1.3, -0.95, -0.1)          # hands on the hips
PRAYER = (-0.5, 1.12, -1.0)         # hands pressed together over the mouth
CHIN = (-0.5, 0.95, -0.95)          # both hands up at the chin
CHEST_HEART = (-0.38, 0.45, -0.72)  # (right hand) flat over the heart, on the left of the chest
ELBOW_OUT = (-1.0, 0.05, 0.25)      # elbow points out to the side
ELBOW_DOWN = (-0.25, -1.0, 0.1)     # elbow points down (tucked)
ELBOW_HEAD = (-1.0, 0.1, 0.6)       # hands on the head: elbows out wide and back
PUMP_UP = (1.55, 1.2, -0.3)         # (right) a bent-arm fist up beside the head, elbow down at the side
PUMP_DOWN = (1.5, 0.62, -0.35)      # (right) pumped down to the shoulder
ELBOW_PUMP = (0.75, -1.0, 0.05)
ELBOW_BICEP = (-0.72, -0.7, 0.05)   # double biceps: elbow out and down, forearm folding UP in the front plane


# The foot box's toe edge to its ankle joint (foot part: 0.3 tall, 1 deep; ankle 0.1019 above its centre).
TOE_TO_ANKLE = (0.15 + 0.1019, 0.5)


def on_toes(pitch):
    """(ankle height, how far the ankle moves toward the toes) with the heel up `pitch` degrees (negative) and the toe
    edge still on the floor."""
    p = math.radians(pitch)
    up, back = TOE_TO_ANKLE
    return up * math.cos(p) - back * math.sin(p), back - (up * math.sin(p) + back * math.cos(p))


def foot(side, x=None, z=None, y=None, yaw=R.STAND_TOES, pitch=0.0):
    """A foot (floor space). x is the left foot's x; the right is mirrored. A negative pitch (heel up) with no y given
    stays on its toes: the ankle rises and moves forward so the toe edge stays on the floor."""
    sx = -1 if side == "Left" else 1
    a = R.STAND_ANKLE[side]
    zz = AZ if z is None else z
    yy = AY if y is None else y
    if pitch < 0 and y is None:
        yy, forward = on_toes(pitch)
        zz -= forward
    return (a.x if x is None else sx * abs(x), yy, zz, yaw, pitch)


def feet(x=None, z=None, y=None, yaw=R.STAND_TOES, pitch=0.0):
    return {"lf": foot("Left", x, z, y, yaw, pitch), "rf": foot("Right", x, z, y, yaw, pitch)}


def stand_feet():
    return {"lf": R.stand_foot("Left"), "rf": R.stand_foot("Right")}


WIDE = 0.95                          # a wide (sumo-like) stance: ankles 0.95 out
KNEE_Z = -0.15                       # kneeling: knees just ahead of the hips


def kneel(lean=0.0, z=-0.1):
    """Upright on both knees, shins flat behind, toes tucked."""
    return {"pos": (0, -0.68, z), "lean": lean,
            "lk": (-0.5, R.KNEE_ON_FLOOR, KNEE_Z), "rk": (0.5, R.KNEE_ON_FLOOR, KNEE_Z),
            "lf": (-0.52, on_toes(-62)[0], 0.74, 4, -62), "rf": (0.52, on_toes(-62)[0], 0.74, 4, -62)}


def bow_down():
    """Kneeling, sat back on the heels, folded forward: forehead and forearms to the floor."""
    d = kneel(0.0)
    d.update({"pos": (0, -0.82, 0.3), "lean": 52, "cbend": 26, "up": -30,
              "lh": ("floor", (-0.85, 0.62, -1.35)), "rh": ("floor", (0.85, 0.62, -1.35))})
    return d


def free_knees():
    return {"lk": None, "rk": None}


def tremble(t0, t1, amp=0.035, hz=9.0, chest=1.2):
    """A roar's shake: hands and chest tremble between t0 and t1, faded in and out."""
    def layer(t, ch):
        if t <= t0 or t >= t1:
            return {}
        edge = min(1.0, (t - t0) / 0.2, (t1 - t) / 0.2)
        w = edge * math.sin(2 * math.pi * hz * (t - t0))
        w2 = edge * math.sin(2 * math.pi * hz * 0.83 * (t - t0) + 1.3)
        return {"lh": (0, amp * w, amp * 0.5 * w2), "rh": (0, amp * w2, amp * 0.5 * w), "cbend": chest * w2}
    return layer


def sway(t0, t1, degrees=3.0, period=1.6):
    def layer(t, ch):
        if t <= t0 or t >= t1:
            return {}
        edge = min(1.0, (t - t0) / 0.3, (t1 - t) / 0.3)
        return {"yaw": degrees * edge * math.sin(2 * math.pi * (t - t0) / period)}
    return layer


def bounce(t0, t1, height=0.03, hz=3.2, chest=2.0):
    """Laughing: small quick shoulder bounces."""
    def layer(t, ch):
        if t <= t0 or t >= t1:
            return {}
        edge = min(1.0, (t - t0) / 0.2, (t1 - t) / 0.2)
        w = edge * abs(math.sin(math.pi * hz * (t - t0)))
        return {"cbend": -chest * w, "up": 3.0 * w}
    return layer


def K(t, **kw):
    """A key: keyword channels plus any dicts passed as `with_`."""
    extra = kw.pop("with_", None)
    d = {}
    for part in (extra if isinstance(extra, (list, tuple)) else [extra] if extra else []):
        d.update(part)
    d.update(kw)
    return (t, d)


# ---------------------------------------------------------------- the celebrations
CLIPS = {}
META = {}


def clip(name, length, keys, layers=(), kind="standing", source="", rarity="Common", only=None, events=()):
    c = R.Clip(name, length, keys, layers)
    CLIPS[name] = c
    META[name] = {"kind": kind, "source": source, "rarity": rarity, "only": only, "events": list(events)}
    return c


ARMS_AND_HEAD = ("Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand")
RIGHT_ARM_AND_HEAD = ("Head", "RightUpperArm", "RightLowerArm", "RightHand")

# DEFAULT (CEL-71) chalk clap and fist pump: a clap at the chest, a proud beat, one bent-arm fist pump, ~3 s.
clip("ChalkClapPump", 3.0, [
    K(0.25, with_=both(CLAP_APART), up=-4),
    K(0.42, with_=both(CLAP), up=-7, pos=(0, -0.05, 0), ease="fast"),
    K(0.58, with_=both((-0.78, 0.22, -1.08)), up=-4, pos=(0, 0, 0)),
    K(0.95, with_=rest(), cbend=-5, up=4),
    K(1.4, yaw=10, turn=8, cbend=-5, up=4),
    K(1.75, rh=("chest", PUMP_UP), re=ELBOW_PUMP, up=6, ease="fast"),
    K(2.0, rh=("chest", PUMP_DOWN), up=-4, pos=(0, -0.06, 0), ease="fast"),
    K(2.2, rh=("chest", (1.52, 0.7, -0.35)), up=0, pos=(0, 0, 0)),
    K(2.6, rh=REST, yaw=0, turn=0, cbend=0, up=0),
    K(3.0),
], kind="standing", source="CEL-71", rarity="Default", events=[(0.42, "ChalkClap"), (2.0, "FistPump")])

# COMMON (CEL-59) exit fist pump: walking off, the right fist comes up to the shoulder and shakes once. Over the walk.
clip("ExitFistPump", 1.6, [
    K(0.3, rh=("chest", PUMP_UP), re=ELBOW_PUMP, up=5, ease="fast"),
    K(0.45, rh=("chest", PUMP_DOWN), ease="fast"),
    K(0.62, rh=("chest", PUMP_UP), ease="fast"),
    K(1.05, rh=("chest", (1.55, 1.12, -0.3)), up=3),
    K(1.45, rh=REST, up=0),
    K(1.6),
], kind="walk", source="CEL-59", rarity="Common", only=RIGHT_ARM_AND_HEAD)

# COMMON (CEL-60) bent-arm fist salute: right fist held up beside the head, upper arm level, small shakes, looking up
# toward the crowd.
clip("FistSalute", 2.4, [
    K(0.38, rh=("chest", mx(BICEP)), re=mx(ELBOW_BICEP), turn=-18, up=10, cbend=-3, ease="fast"),
    K(1.45, rh=("chest", mx(BICEP)), turn=-22, up=12),
    K(1.85, rh=REST, turn=0, up=0, cbend=0),
    K(2.4),
], layers=[tremble(0.45, 1.4, amp=0.05, hz=6.0, chest=0.0)], source="CEL-60", rarity="Common")

# COMMON (CEL-66) stoic military salute: chest out, a crisp salute at the brow facing the judges, at attention.
clip("MilitarySalute", 3.0, [
    K(0.25, cbend=-5, up=4),
    K(0.6, rh=("chest", (0.42, 1.62, -0.8)), re=(1.0, 0.1, 0.1), rw=(0.0, 0.0), ease="fast"),
    K(1.65, rh=("chest", (0.42, 1.62, -0.8))),
    K(1.95, rh=REST),
    K(2.6, cbend=-5, up=4),
    K(3.0, cbend=0, up=0),
], source="CEL-66", rarity="Common", events=[(0.6, "Salute")])

# UNCOMMON (CEL-46) wingspan T hold: arms swing out and up into a T, chest out, chin up, soaking it in; feet planted.
clip("WingspanHold", 3.4, [
    K(0.35, with_=both(LOW_WING), pos=(0, -0.1, 0), up=4),
    K(0.8, with_=both(T_OUT), cbend=-7, up=12, pos=(0, -0.06, 0)),
    K(2.45, with_=both((-2.68, 0.55, -0.3)), cbend=-8, up=16),
    K(2.7, up=-10),
    K(3.0, with_=rest(), cbend=0, pos=(0, 0, 0)),
    K(3.4, up=0),
], layers=[sway(0.9, 2.5, 3.0)], source="CEL-46", rarity="Uncommon")

# UNCOMMON (CEL-49) arms up, bounce, grin: both arms straight up, then out low, bouncing on the toes.
_bounce_keys = []
for i, t in enumerate((0.75, 0.95, 1.15, 1.35, 1.55, 1.75)):
    up_beat = i % 2 == 1
    _bounce_keys.append(K(t, pos=(0, 0.06 if up_beat else -0.2, 0),
                          with_=[feet(y=AY + (0.1 if up_beat else 0.0), pitch=-22 if up_beat else 0.0),
                                 both((-1.85, -0.05 if up_beat else -0.25, -0.5))]))
clip("ArmsUpBounce", 2.5, [
    K(0.28, with_=both((-1.25, 2.25, -0.25)), up=14, ease="fast"),
    K(0.55, with_=both((-1.9, 0.2, -0.45)), up=8),
    *_bounce_keys,
    K(2.1, with_=[rest(), stand_feet()], pos=(0, 0, 0), up=0),
    K(2.5),
], layers=[bounce(0.7, 1.9, chest=1.5)], source="CEL-49", rarity="Uncommon")

# UNCOMMON (CEL-51) walking finger to the sky: the right arm shoots straight up, chin up, held for three steps. Over
# the walk.
clip("SkyPoint", 3.4, [
    K(0.45, rh=("chest", mx(SKY)), up=18, ease="fast"),
    K(2.8, rh=("chest", mx(SKY)), up=20),
    K(3.2, rh=REST, up=0),
    K(3.4),
], kind="walk", source="CEL-51", rarity="Uncommon", only=RIGHT_ARM_AND_HEAD)

# Two that go on ALL THE WAY BACK to the waiting spot (user 2026-11-11: "a celebration that continues even when your
# going back to the bench ... Use the videos i sent you again, to see how they step off and go away from the
# platform"): looped, arms and head only, over the walk back; the server ends them when the lifter arrives.
# Rewatched 2026-11-11: 9FQM0Z6_s8Q 1:16.8-1:17.3 (walks off toward the camera, right fist pumped high, elbow bent, left
# arm swinging low, roaring), lNOrz4CVNMY 20:55.2 (walking off, both arms flung out wide, grinning), 20:56.2 (double
# thumbs up held high to the crowd while walking), 2:36.5-2:39.5 (steps back from the rack, turns, walks off looking up
# at the crowd, the open belt swinging), and the notes' gracious open-palm wave at 23:30 (Clip notes B).
WAVE_HIGH = (1.45, 1.75, -0.35)       # (right) an open hand up beside the head
PUMP_HIGH = (1.3, 1.85, -0.35)        # (right) a fist punched up high, elbow bent
ELBOW_HIGH = (1.0, 0.3, 0.2)          # (right) that elbow out to the side
WIDE_WALK = (-2.3, -0.2, -0.3)        # arms flung out wide, a little down
THUMBS = (-1.7, 1.4, -0.4)            # both forearms up, fists by the head (thumbs up)

# EPIC crowd pleaser: two fist pumps with a roar, arms flung wide, double thumbs up to the stands; round and round
# until they are back.
clip("CrowdPleaser", 4.4, [
    K(0.35, rh=("chest", PUMP_HIGH), re=ELBOW_HIGH, up=14, turn=-16, ease="fast"),
    K(0.6, rh=("chest", (1.45, 1.45, -0.35)), up=10),
    K(0.85, rh=("chest", PUMP_HIGH), up=15, ease="fast"),
    K(1.3, rh=REST, up=6, turn=0),
    K(1.7, with_=both(WIDE_WALK), up=10, turn=8),
    K(2.4, with_=both((-2.35, -0.1, -0.25)), up=12, turn=12),
    K(2.8, with_=both(THUMBS), le=ELBOW_BICEP, re=mx(ELBOW_BICEP), up=12, turn=0, ease="fast"),
    K(3.5, with_=both((-1.7, 1.48, -0.4)), up=14),
    K(4.0, with_=rest(), up=0),
    K(4.4),
], kind="walkloop", source="Walk-off: 9FQM0Z6_s8Q 1:16.8, lNOrz4CVNMY 20:55", rarity="Epic", only=ARMS_AND_HEAD)

# RARE thank-you wave: an open hand waved up to the crowd, then the hand on the heart with a nod; again and again
# until they are back.
clip("ThankYouWave", 3.6, [
    K(0.4, rh=("chest", WAVE_HIGH), turn=-18, up=8, ease="fast"),
    K(0.65, rh=("chest", (1.75, 1.7, -0.3))),
    K(0.9, rh=("chest", (1.2, 1.78, -0.4))),
    K(1.15, rh=("chest", (1.75, 1.7, -0.3))),
    K(1.4, rh=("chest", WAVE_HIGH)),
    K(1.9, rh=("chest", CHEST_HEART), turn=-8, up=-6),
    K(2.4, rh=("chest", CHEST_HEART), up=2),
    K(3.0, rh=REST, turn=0, up=0),
    K(3.6),
], kind="walkloop", source="Walk-off: lNOrz4CVNMY 23:30", rarity="Rare", only=RIGHT_ARM_AND_HEAD)

# RARE (CEL-34) relief roar, hands locked on the head: a heavyweight's sinking roar, arms down and tense, then both
# hands onto the crown, face up. Feet planted.
clip("ReliefRoar", 4.2, [
    K(0.4, pos=(0, -0.42, 0.05), lean=10, cbend=-4, up=22, with_=both((-1.3, -0.95, -0.2)), ease="fast"),
    K(1.35, pos=(0, -0.38, 0.05), lean=8, up=24),
    K(1.75, pos=(0, -0.08, 0), lean=0, cbend=0, up=6, with_=rest()),
    K(2.25, with_=both(HEAD_TOP, HEAD_TOP_R), le=ELBOW_HEAD, re=mx(ELBOW_HEAD), cbend=-9, up=12, ease="smooth"),
    K(3.2, with_=both(HEAD_TOP, HEAD_TOP_R), cbend=-8, up=10),
    K(3.65, with_=rest(), cbend=0, up=0, pos=(0, 0, 0)),
    K(4.2),
], layers=[tremble(0.45, 1.4, amp=0.03, chest=1.8)], source="CEL-34", rarity="Rare", events=[(0.4, "Roar")])

# RARE (CEL-36) wait for the lights, then arms straight up: hands on hips watching the judges, then both arms shoot up.
clip("LightsArmsUp", 3.8, [
    K(0.4, with_=both(HIPS), turn=-30, up=4, le=(-0.6, -0.2, 0.8), re=(0.6, -0.2, 0.8)),
    K(1.25, with_=both(HIPS), turn=-32, up=6),
    K(1.55, with_=both((-1.15, 2.28, -0.15)), turn=0, up=20, cbend=-7, ease="fast"),
    K(2.7, with_=both((-1.2, 2.25, -0.15)), up=22, cbend=-8),
    K(3.25, with_=rest(), up=0, cbend=0),
    K(3.8),
], layers=[tremble(1.65, 2.7, amp=0.04, chest=1.2)], source="CEL-36", rarity="Rare", events=[(1.55, "Roar")])

# RARE (CEL-43) sit down and laugh at the lights: sits on the platform, leaning back on the right hand, laughing.
_seat = {"pos": (0, -1.27, 0.55), "lean": -28, "lf": (-0.62, AY, -0.62, 28, 0), "rf": (0.18, AY, -0.78, 8, 0)}
clip("SitAndLaugh", 5.2, [
    K(0.6, pos=(0, -0.75, 0.25), lean=22, up=-8, with_=both((-0.9, -1.3, 0.2))),
    K(1.15, with_=_seat, lh=("chest", (-0.95, -0.75, -1.05)), rh=("floor", (1.05, 0.32, 1.05)), up=30, turn=-12),
    K(3.0, with_=_seat, lh=("chest", (-0.95, -0.75, -1.05)), rh=("floor", (1.05, 0.32, 1.05)), up=30, turn=-8),
    K(3.55, pos=(0, -1.0, 0.25), lean=26, lh=("chest", (-0.9, -0.9, -1.0)), rh=("floor", (0.95, 0.32, 0.62)),
      up=-5, turn=0, lf=foot("Left", z=-0.15), rf=foot("Right", z=-0.2)),
    K(4.2, pos=(0, -0.3, 0.05), lean=10, with_=[rest(), stand_feet()], up=0),
    K(4.7, pos=(0, 0, 0), lean=0),
    K(5.2),
], layers=[bounce(1.25, 2.95)], source="CEL-43", rarity="Rare", events=[(1.15, "SitDown"), (1.3, "Laugh")])

# EPIC (CEL-26) double finger point and prance: giddy hands at the chin with a skip, then both arms up pointing at the
# ceiling and alternating high knees.
_prance = []
for i, t in enumerate((1.33, 1.55, 1.77, 1.99, 2.21)):
    left_up = i % 2 == 0
    _prance.append(K(t, pos=(0, 0.06, 0),
                     lf=foot("Left", y=AY + (0.75 if left_up else 0.0), z=AZ - (0.45 if left_up else 0.0),
                             pitch=12 if left_up else 0.0),
                     rf=foot("Right", y=AY + (0.0 if left_up else 0.75), z=AZ - (0.0 if left_up else 0.45),
                             pitch=0.0 if left_up else 12)))
clip("PointAndPrance", 3.6, [
    K(0.3, with_=both(CHIN), rf=foot("Right", y=AY + 0.45, z=AZ - 0.3), pos=(0, 0.05, 0), up=4),
    K(0.55, rf=R.stand_foot("Right"), pos=(0, -0.08, 0)),
    K(0.85, with_=both(CHIN), pos=(0, 0, 0), up=6),
    K(1.1, with_=both((-1.45, 2.18, -0.25)), rf=foot("Right", y=AY + 0.8, z=AZ - 0.5, pitch=12), pos=(0, 0.08, 0),
      up=18, ease="fast"),
    *_prance,
    K(2.45, with_=[stand_feet(), both((-1.45, 2.18, -0.25))], pos=(0, -0.05, 0)),
    K(2.7, with_=both((-2.4, 0.7, -0.3)), pos=(0, 0, 0), up=6),
    K(3.1, with_=rest(), up=0),
    K(3.6),
], source="CEL-26", rarity="Epic", events=[(1.1, "Scream")])

# EPIC (CEL-20) rack-side double fist roar: a wide half squat with fists at the chest, up into a V, down into
# goalposts, then sinking deep and pulling both fists down.
clip("RackSideRoar", 3.4, [
    K(0.3, with_=[feet(x=WIDE, yaw=24), both(FIST_CHEST)], pos=(0, -0.55, 0.05), lean=10, up=8),
    K(0.65, with_=both(V_UP), pos=(0, -0.05, 0), lean=-4, cbend=-10, up=30, ease="fast"),
    K(1.1, with_=both(GOALPOST), le=ELBOW_BICEP, re=mx(ELBOW_BICEP), pos=(0, -0.6, 0.05), lean=8, cbend=0, up=14, ease="fast"),
    K(1.6, with_=both((-0.62, -1.12, -0.82)), pos=(0, -0.9, 0.15), lean=30, up=-16, ease="fast"),
    K(1.95, pos=(0, -0.88, 0.15), lean=30),
    K(2.45, with_=[rest(), stand_feet()], pos=(0, 0, 0), lean=0, up=0),
    K(3.4),
], layers=[tremble(0.7, 2.0, amp=0.04, chest=1.5)], source="CEL-20", rarity="Epic",
    events=[(0.65, "Roar"), (1.1, "Roar"), (1.6, "Roar")])

# EPIC (CEL-18) crouch roar into a tuck jump: a deep crouch roar with fists low, a crunch, a tuck jump, a little hop.
_air = {"lf": foot("Left", y=AY + 1.1, z=AZ + 0.3, pitch=-25), "rf": foot("Right", y=AY + 1.1, z=AZ + 0.3, pitch=-25)}
clip("CrouchRoarJump", 4.2, [
    K(0.4, with_=[feet(x=0.75, yaw=20), both((-0.6, -1.0, -0.8))], pos=(0, -0.78, 0.1), lean=26, up=26, ease="fast"),
    K(1.15, pos=(0, -0.75, 0.1), lean=25, up=24),
    K(1.4, with_=both((-0.45, -0.5, -0.9)), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=(0, -0.22, 0), lean=12, cbend=18,
      up=4),
    K(1.65, with_=[stand_feet(), both((-1.3, -1.1, 0.25))], pos=(0, -0.5, 0.05), lean=16, cbend=6),
    K(1.85, pos=(0, 0.05, 0), lean=4, cbend=0, with_=[feet(pitch=-30), both(FIST_CHEST)], ease="fast"),
    K(2.1, pos=(0, 0.78, 0), lean=0, with_=_air, ease="fast"),
    K(2.35, pos=(0, 0.0, 0), with_=[stand_feet(), both((-1.85, -0.05, -0.5))], ease="slow"),
    K(2.55, pos=(0, -0.45, 0.05), lean=12),
    K(2.8, pos=(0, 0.05, 0), lean=0, with_=feet(pitch=-25), ease="fast"),
    K(2.95, pos=(0, 0.32, 0), with_=feet(y=AY + 0.3, pitch=-10), ease="fast"),
    K(3.1, pos=(0, 0.0, 0), with_=stand_feet(), ease="slow"),
    K(3.25, pos=(0, -0.25, 0), with_=both((-1.6, -0.35, -0.35))),
    K(3.7, pos=(0, 0, 0), with_=rest(), up=0, lean=0),
    K(4.2),
], layers=[tremble(0.45, 1.15, amp=0.04, chest=1.6)], source="CEL-18", rarity="Epic",
    events=[(0.4, "Roar"), (2.35, "Land"), (3.1, "Land")])

# EPIC (CEL-17) wingspan roar into the crunch: watches the lights, flings both arms out to a T roaring, holds it, then
# sweeps down into a crunching squeeze, roaring at the floor. Feet planted.
clip("WingspanCrunch", 4.2, [
    K(0.35, turn=-30, up=4),
    K(0.8, turn=-26, rh=("chest", (1.6, -0.6, -0.4))),
    K(1.05, with_=both(T_OUT), turn=0, cbend=-8, up=16, pos=(0, -0.1, 0), ease="fast"),
    K(2.2, with_=both((-2.45, 0.6, -0.95)), cbend=-9, up=26),
    K(2.55, with_=both((-1.1, -0.95, -0.4)), pos=(0, -0.35, 0.05), cbend=4, up=8),
    K(2.85, with_=both((-0.42, -0.5, -0.92)), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=(0, -0.62, 0.1), lean=15,
      cbend=24, up=-16, ease="fast"),
    K(3.45, pos=(0, -0.6, 0.1), lean=15, cbend=24, up=-14),
    K(3.85, with_=rest(), pos=(0, 0, 0), lean=0, cbend=0, up=0),
    K(4.2),
], layers=[tremble(1.1, 2.2, amp=0.035, chest=1.2), tremble(2.9, 3.45, amp=0.05, chest=2.0)], source="CEL-17",
    rarity="Epic", events=[(1.05, "Roar"), (2.85, "Roar")])

# LEGENDARY (CEL-02) disbelief, deep squat, arms to the sky, prayer hands: frozen shock, hands on the head, a roar
# with fists yanked to the chest, a full deep squat, "can you believe it", arms up in a V, hands over the face.
clip("DisbeliefPrayer", 9.6, [
    K(0.65, up=-3),
    K(1.0, rh=("chest", HEAD_TOP_R), re=mx(ELBOW_HEAD), up=-8, hroll=-7, pos=(0, -0.08, 0)),
    K(1.3, with_=feet(x=WIDE, yaw=26)),
    K(1.5, with_=both(HEAD_TOP, HEAD_TOP_R), le=ELBOW_HEAD, pos=(0, -0.32, 0.02), lean=-6, up=-4, hroll=0),
    K(1.95, with_=both(FIST_CHEST), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), pos=(0, -0.42, 0.05), lean=10, up=6,
      ease="fast"),
    K(2.45, with_=both((-1.2, -0.95, -0.25)), pos=(0, -0.2, 0.02), lean=4, up=10),
    K(2.95, with_=both((-0.5, 0.35, -1.0)), pos=(0, -1.22, 0.32), lean=24, up=-8),
    K(3.5, pos=(0, -1.22, 0.32), lean=24, up=-10),
    K(4.0, pos=(0, -0.25, 0.05), lean=6, up=0),
    K(4.45, with_=[rest(), stand_feet()], pos=(0, 0, 0), lean=0, turn=22, up=10),
    K(5.0, turn=-16, up=12),
    K(5.5, with_=both((-1.85, 0.78, -0.6)), le=(-0.6, -1.0, 0.2), re=(0.6, -1.0, 0.2), turn=0, up=10, hroll=6),
    K(6.0, with_=both((-2.35, 0.55, -0.45), HEAD_TOP_R), re=mx(ELBOW_HEAD), hroll=0),
    K(6.5, with_=both(V_UP), pos=(0, -0.12, 0), cbend=-8, up=30, ease="fast"),
    K(7.35, with_=both(V_UP), pos=(0, -0.1, 0), cbend=-9, up=32),
    K(7.8, with_=both((-1.9, 0.4, -0.7)), pos=(0, 0, 0), cbend=0, up=8),
    K(8.3, with_=both(PRAYER), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), cbend=12, up=-10),
    K(8.85, lean=9, cbend=14, up=-14),
    K(9.2, with_=rest(), lean=0, cbend=0, up=0),
    K(9.6),
], layers=[tremble(1.95, 2.45, amp=0.05, chest=2.0), tremble(6.55, 7.35, amp=0.04, chest=1.2)],
    source="CEL-02", rarity="Legendary", events=[(1.95, "Roar"), (6.5, "Roar")])

# LEGENDARY (CEL-03) world-record roar into wingspan and double biceps: a crouched scream, a hop back with the arms
# flung up and wide, leaning back, turning to the crowd, then a double biceps.
clip("WingspanBiceps", 6.2, [
    K(0.3, with_=[feet(x=0.8, yaw=22), both((-0.6, -1.02, -0.85))], pos=(0, -0.62, 0.12), lean=30, up=-6),
    K(0.5, up=30, ease="fast"),
    K(0.85, pos=(0, 0.25, 0.3), lean=0, with_=feet(x=0.8, y=AY + 0.25, z=AZ + 0.2, yaw=22, pitch=-15), ease="fast"),
    K(1.05, with_=[both((-2.35, 1.75, -0.2)), feet(x=0.8, z=AZ + 0.32, yaw=22)], pos=(0, -0.05, 0.32), lean=-14,
      up=30, ease="slow"),
    K(1.45, with_=both(T_OUT), rf=foot("Right", x=0.8, z=AZ + 0.75, yaw=22), yaw=24, lean=-10, up=24),
    K(1.95, with_=both(LOW_WING), turn=18, up=24, hroll=10, lean=-4),
    K(2.6, with_=[rest(), stand_feet()], pos=(0, 0, 0), yaw=0, lean=0, turn=0, up=4, hroll=0),
    K(3.1, with_=both((-2.5, 0.25, -0.3)), up=8),
    K(3.6, with_=both((-0.52, -0.82, -0.78)), up=0),
    K(4.05, with_=both(BICEP), le=ELBOW_BICEP, re=mx(ELBOW_BICEP), cbend=-9, up=6, pos=(0, -0.1, 0), ease="fast"),
    K(4.95, with_=both(BICEP), cbend=-10, up=6),
    K(5.3, with_=both((-0.4, -0.6, -0.95)), cbend=0, pos=(0, 0, 0)),
    K(5.75, with_=rest()),
    K(6.2),
], layers=[tremble(0.5, 0.85, amp=0.05, chest=2.0), tremble(4.1, 4.95, amp=0.045, chest=1.0)],
    source="CEL-03", rarity="Legendary", events=[(0.5, "Roar"), (1.05, "Roar"), (4.05, "Flex")])

# LEGENDARY (CEL-04) leap and bow to the platform: springs up with the hands up by the head, shins tucked back, lands
# straight on both knees and folds into a forehead-to-floor bow; then up and away.
_kneel = kneel()
clip("LeapAndBow", 5.8, [
    K(0.32, with_=both((-1.3, -1.1, 0.25)), pos=(0, -0.55, 0.08), lean=20, up=-6),
    K(0.55, pos=(0, 0.1, 0), lean=4, with_=[feet(pitch=-30), both((-1.4, 0.9, -0.4))], ease="fast"),
    K(0.85, pos=(0, 0.85, 0), lean=6, up=-16, with_=both((-1.75, 1.25, -0.2)), le=ELBOW_OUT, re=mx(ELBOW_OUT),
      lk=(-0.52, 2.3, -0.45), rk=(0.52, 2.3, -0.45),
      lf=(-0.55, 1.8, 0.35, 4, -45), rf=(0.55, 1.8, 0.35, 4, -45), ease="fast"),
    K(1.18, pos=_kneel["pos"], lean=4, lk=_kneel["lk"], rk=_kneel["rk"], lf=_kneel["lf"], rf=_kneel["rf"],
      up=-20, ease="slow"),
    K(1.35, pos=(0, -0.78, -0.05), lean=8),
    K(1.75, with_=bow_down(), ease="smooth"),
    K(2.85, with_=bow_down()),
    K(3.35, with_=[_kneel, rest()], cbend=0, up=0),
    K(3.75, rk=None, rf=foot("Right", z=AZ - 0.55), pos=(0, -0.62, -0.15), lean=14),
    K(4.45, with_=[free_knees(), stand_feet()], pos=(0, 0, 0), lean=0),
    K(5.8),
], source="CEL-04", rarity="Legendary", events=[(0.55, "Roar"), (1.18, "KneeThud"), (1.75, "Bow")])

# LEGENDARY (CEL-05) bow down, then rise roaring: stunned, knees buckle into a face-down bow, then up on the knees with
# fists at the chin, fists driven down and head thrown back in a roar, up to standing, hand on the heart.
clip("BowAndRise", 6.6, [
    K(0.7, up=-2),
    K(1.05, pos=(0, -0.3, 0.05), lean=16, with_=both((-0.8, -1.3, -0.5)), up=-10),
    K(1.55, with_=[kneel(18)], lh=("floor", (-0.8, 0.5, -0.9)), rh=("floor", (0.8, 0.5, -0.9))),
    K(2.05, with_=bow_down()),
    K(2.95, with_=bow_down()),
    K(3.35, with_=kneel(4), lh=("floor", (-0.95, 0.55, -0.7)), rh=("floor", (0.95, 0.55, -0.7)), cbend=0, up=-5),
    K(3.65, with_=[kneel(0), both((-0.45, 0.95, -0.85))], le=ELBOW_DOWN, re=mx(ELBOW_DOWN), up=-6),
    K(3.95, with_=both((-1.28, -1.05, -0.15)), cbend=-10, up=6, ease="fast"),
    K(4.2, up=32, cbend=-12, ease="fast"),
    K(4.6, lean=14, cbend=0, up=18, with_=both((-0.65, -1.1, -0.85)), rk=None,
      rf=foot("Right", z=AZ - 0.55)),
    K(5.1, with_=[free_knees(), stand_feet()], pos=(0, 0, 0), lean=0, up=6),
    K(5.55, rh=("chest", CHEST_HEART), lh=REST, re=mx(ELBOW_DOWN), up=4),
    K(6.15, rh=REST, up=0),
    K(6.6),
], layers=[tremble(4.0, 4.95, amp=0.05, chest=2.2)], source="CEL-05", rarity="Legendary",
    events=[(1.55, "KneeThud"), (4.2, "Roar")])

# LEGENDARY (CEL-01) record jump-and-roar with chalk burst: arms wide and low in disbelief, looks up at the screen,
# hands on the head, folds forward, a skip, a tucked jump punching forward, a big clap that bursts chalk, a fist to the
# sky out of the cloud.
clip("RecordJumpRoar", 9.2, [
    K(0.4, with_=[both((-2.2, -0.5, -0.4)), feet(x=0.75, yaw=18)], pos=(0, -0.12, 0.05), cbend=-8, up=12),
    K(1.6, with_=both((-2.25, -0.45, -0.45)), cbend=-9, up=14),
    K(1.9, with_=[rest(), stand_feet()], pos=(0, 0, 0), cbend=0, up=4),
    K(2.25, up=26),
    K(3.0, up=28),
    K(3.6, with_=both(HEAD_TOP, HEAD_TOP_R), le=ELBOW_HEAD, re=mx(ELBOW_HEAD), up=8),
    K(4.0, pos=(0, -0.42, 0.05), lean=8, up=0),
    K(4.45, pos=(0, -0.45, 0.12), lean=46, cbend=14, up=-22, with_=both((-0.48, 1.95, 0.45), (0.48, 2.0, 0.42))),
    K(4.95, pos=(0, -0.15, 0), lean=4, cbend=0, up=8, with_=both((-1.0, 0.55, -1.05)), le=(-0.6, -1, 0.2),
      re=(0.6, -1, 0.2)),
    K(5.1, pos=(0, 0.12, 0), with_=feet(pitch=-20), ease="fast"),
    K(5.25, pos=(0, -0.05, 0), with_=stand_feet()),
    K(5.5, with_=both(FIST_CHEST), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), rf=foot("Right", y=AY + 0.85, z=AZ - 0.5,
      pitch=10), pos=(0, 0.06, 0)),
    K(5.75, rf=R.stand_foot("Right"), pos=(0, -0.5, 0.05), lean=10),
    K(5.95, pos=(0, 0.08, 0), lean=0, with_=feet(pitch=-30), ease="fast"),
    K(6.2, pos=(0, 0.82, 0), lean=-8, with_=[_air, both((-0.55, 0.6, -1.55))], ease="fast"),
    K(6.45, pos=(0, 0, 0), lean=0, with_=[stand_feet(), both(FIST_CHEST)], ease="slow"),
    K(6.65, pos=(0, -0.45, 0.05), lean=10),
    K(6.85, with_=both((-1.25, 1.05, -1.0)), pos=(0, -0.1, 0), lean=0, up=8),
    K(7.0, with_=both((-0.5, 1.02, -1.08)), up=10, ease="fast"),
    K(7.25, rh=("chest", mx(SKY)), lh=("chest", (-0.6, 0.6, -1.0)), up=28, ease="fast"),
    K(7.42, rh=("chest", (1.02, 1.95, -0.3)), ease="fast"),
    K(7.6, rh=("chest", mx(SKY)), ease="fast"),
    K(7.95, with_=both(CLAP), up=6),
    K(8.5, with_=rest(), up=0),
    K(9.2),
], layers=[tremble(5.0, 5.4, amp=0.03)], source="CEL-01", rarity="Legendary",
    events=[(6.45, "Land"), (7.0, "ChalkBurst"), (7.25, "Roar")])


# ---------------------------------------------------------------- run
if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    folder = argv[0] if argv else None
    names = argv[1:] or list(CLIPS)
    for name in names:
        c = CLIPS[name]
        c.solve()
        print("CHECK", R.check(c), META[name]["kind"])
        print("EXPORTED", R.export(c, only=META[name]["only"], looped=META[name]["kind"] == "walkloop"))
        if folder:
            R.preview_sheet(c, folder, view="front")
            R.preview_sheet(c, folder, view="side")
    print("DONE")
