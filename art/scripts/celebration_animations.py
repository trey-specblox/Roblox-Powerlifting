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
#
# CLOTHES (2026-11-16, rules 16-17): every clip is solved with clothed=True: hands and forearms are kept out of the meet
# outfit (tee, singlet, belt) on all six builds (celebration_rig.clear_of_clothes). It needs the envelope data file
# art/data/clothed_envelope_05.json (or CELEB_ENVELOPE=<path>); remake it whenever the bodies or the outfit exports change:
#   blender -b art/blender/CartoonBodies_05_Rigged.blend --python art/scripts/celebration_rig.py -- envelope
# Check with anim_qa.py on QA_BUILDS=Skinny,Fat,Muscular,BigBuff (arm_in_outfit must read 0.00).
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

# ---------------------------------------------------------------- the taller rig (user 2026-11-12)
# The numbers below were written on the block rig. The cartoon lifters are taller (lifter_heights.py: legs x1.2286,
# torso and arms x1.15; head, hands and feet unchanged), so they are moved onto this rig as they are read:
#   B(v)   a hand on or near the body (chest frame): only its height stretches with the torso (the body is no wider);
#          on the torso rig (arms x1.2, torso x1.35) a low hand rises just enough to stay within the arm's reach
#   O(v)   an arm held out or up at arm's length: moved out from the shoulder by how much further the arm reaches
#   F(v)   an arm reaching straight forward: the same, its x kept
#   H(v)   at the head (the face, the crown): the head is not stretched, it just sits higher on the chest
#   P(x, y, z)   the hips' offset in a crouch or a jump (y), stretched with the legs; L(d) a foot lift or step
TOR = R.S.TORSO_SCALE
LEG = R.S.LEG_SCALE
_NECK, _BLOCK_NECK = R.S.JOINTS["Neck"], R.S.BLOCK_JOINTS["Neck"]
HEAD_UP = (_NECK[2][1] - _NECK[3][1]) - ((_BLOCK_NECK[2][1] - _BLOCK_NECK[3][1]) if R.S.TALLER else 0.0)
REACH = R.S.ARM_REACH_SCALE
_SHOULDER = R.S.BLOCK_JOINTS["LeftShoulder"][2] if R.S.TALLER else R.S.JOINTS["LeftShoulder"][2]   # chest frame
_SHOULDER_NOW = R.S.JOINTS["LeftShoulder"][2]


def B(v):
    # (on the torso rig a hand low on the body stays within the arm's reach: S.within_arm, chest frame)
    return tuple(R.S.within_arm(v, (v[0], v[1] * TOR, v[2]), _SHOULDER, _SHOULDER_NOW))


_CHEST_UP = R.S.forward_kinematics(R.S.Matrix.Identity(4), {})["UpperTorso"].to_translation().y   # chest centre


def BELT_B(v, belt_ref):
    """A hand on the belt (chest frame, block numbers; the move's own belt key at belt_ref): on the torso rig at the new
    bodies' navel belt (S.on_belt's rule), else B(v)."""
    if R.S.RIG != "torso":
        return B(v)
    y = (R.S.BELT_NAVEL_Y - _CHEST_UP) + (v[1] - belt_ref) * TOR
    return tuple(R.S.within_arm(v, (v[0], y, v[2]), _SHOULDER, _SHOULDER_NOW))


def O(v, keep_x=False):
    x = _SHOULDER_NOW[0] + (-abs(v[0]) - _SHOULDER[0]) * REACH
    y = _SHOULDER_NOW[1] + (v[1] - _SHOULDER[1]) * REACH
    return (v[0] if keep_x else math.copysign(abs(x), v[0]), y, v[2] * REACH)


def F(v):
    return O(v, keep_x=True)


def H(v):
    return (v[0], v[1] + HEAD_UP, v[2])


def P(x, y, z):
    return (x, y * LEG, z)


def L(d):
    return d * LEG


# ---------------------------------------------------------------- pose vocabulary (left hand, chest frame; mirrored)
def mx(v):
    return (-v[0], v[1], v[2])


def both(left, right=None):
    """Both hands in the chest frame: the right is the left mirrored unless given (in its own true position)."""
    return {"lh": ("chest", left), "rh": ("chest", right if right is not None else mx(left))}


def rest():
    return {"lh": REST, "rh": REST}


V_UP = O((-1.78, 2.05, -0.2))          # arms up in a wide V
SKY = O((-1.55, 2.2, -0.25))           # an arm straight up, out from the head (2026-11-14: -1.02 went through it)
# (2026-11-16, clothed QA on all builds: BigBuff's huge upper arm, splayed further out at rest, swings IN toward the head
#  when raised, so SKY / SKY_CLEAR still sank 0.15-0.16 into its head: the raised arm a little further out, a touch lower)
SKY_OUT = O((-1.8, 2.12, -0.25))
T_OUT = O((-2.7, 0.62, -0.25))         # an arm straight out to the side
LOW_WING = O((-2.2, -0.62, -0.35))     # out and 45 degrees down
HEAD_TOP = H((-0.88, 2.3, 0.0))       # hands on the head: the WRIST at the side of the head, the hand draped over
#   the crown (2026-11-14: the old target sat behind the head and threw the elbows back; user: "physically impossible")
HEAD_TOP_R = H((0.88, 2.3, 0.0))
HEAD_W_L, HEAD_W_R = (100.0, -90.0), (100.0, 90.0)   # the wrists that drape the hands over the crown
FIST_CHEST = B((-0.5, 0.55, -0.95))    # a boxer's guard at the chest
FIST_CHEST_W = B((-0.6, 0.55, -0.95))  # (2026-11-16: the guard a touch wider: on Skinny's narrow shoulders the two fists
#                                        went 0.15-0.16 into each other)
FIST_LOW = B((-0.6, -1.15, -0.85))     # fists pulled down in front of the hips
BICEP = O((-1.95, 1.38, 0.0))          # double biceps: fist beside the head, upper arm out level
GOALPOST = O((-1.95, 1.05, -0.15))
CLAP = B((-0.56, 0.2, -1.1))           # hands together at the chest (palms meeting, not inside each other)
CLAP_APART = B((-1.05, 0.25, -1.1))
HIPS = B((-1.3, -0.95, -0.1))          # hands on the hips
PRAYER = H((-0.5, 1.12, -1.0))         # hands pressed together over the mouth
CHIN = H((-0.5, 0.95, -0.95))          # both hands up at the chin
CHEST_HEART = B((-0.3, 0.45, -1.0))    # (right hand) flat over the heart (2026-11-14: -0.72 sank into the chest)
ELBOW_HEART = (1.0, -0.45, -0.3)      # (right) that elbow out, down and a little forward
ELBOW_OUT = (-1.0, 0.05, 0.25)      # elbow points out to the side
ELBOW_DOWN = (-0.25, -1.0, 0.1)     # elbow points down (tucked)
ELBOW_HEAD = (-1.0, 0.3, -0.2)      # hands on the head: elbows out to the sides and up, never back (2026-11-14)
PUMP_UP = B((1.55, 1.2, -0.3))         # (right) a bent-arm fist up beside the head, elbow down at the side
PUMP_DOWN = B((1.5, 0.62, -0.85))       # (right) pumped down to the shoulder (in front of the deltoid)
ELBOW_PUMP = (0.75, -1.0, 0.05)
ELBOW_BICEP = (-0.72, -0.7, 0.05)   # double biceps: elbow out and down, forearm folding UP in the front plane
DB_OPEN_OLD = (_SHOULDER_NOW[0] - 0.85, _SHOULDER_NOW[1] + 1.44, -0.1)   # the open double biceps the user asked for
ELBOW_DB_OLD = (-1.0, -0.25, 0.05)                                       #   (upper arm level, forearm up; 2026-11-14)


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


# Kneeling upright: the thigh straight up from the knee, the root a hip's drop (1.0) above it (-0.68 on the block rig);
# the toes a shin's length behind the knees (0.74 on the block rig).
KNEEL_Y = R.KNEE_ON_FLOOR + R.THIGH + 1.0 - R.HRP.y
KNEEL_FEET_Z = 0.74 + (R.SHIN - 0.926)
# Sat back toward the heels for the bow: the thigh tipped back as on the block rig (hips 0.45 behind the knees and 0.682
# above them there, on a 0.822 thigh), so the drop and the shift grow with the thigh.
BOW_Y = R.KNEE_ON_FLOOR + R.THIGH * (0.682 / 0.822) + 1.0 - R.HRP.y
BOW_Z = KNEE_Z + R.THIGH * (0.45 / 0.822)


def kneel(lean=0.0, z=-0.1):
    """Upright on both knees, shins flat behind, toes tucked."""
    return {"pos": (0, KNEEL_Y, z), "lean": lean,
            "lk": (-0.5, R.KNEE_ON_FLOOR, KNEE_Z), "rk": (0.5, R.KNEE_ON_FLOOR, KNEE_Z),
            "lf": (-0.52, on_toes(-62)[0], KNEEL_FEET_Z, 4, -62), "rf": (0.52, on_toes(-62)[0], KNEEL_FEET_Z, 4, -62)}


def bow_down():
    """Kneeling, sat back on the heels, folded forward: forehead and forearms to the floor."""
    d = kneel(0.0)
    reach = KNEE_Z + (-1.35 - KNEE_Z) * TOR          # the forearms further ahead with the longer torso
    d.update({"pos": (0, BOW_Y, BOW_Z), "lean": 52, "cbend": 26, "up": -30,
              "lh": ("floor", (-0.85, 0.62, reach)), "rh": ("floor", (0.85, 0.62, reach))})
    return d


BOW_HANDS_X, BOW_HANDS_AHEAD = 1.3, 0.4    # (bow_down_clear)


def bow_down_clear():
    """bow_down with the forearms out wide and further ahead, beside the head (2026-11-16, clothed QA: under the folded
    chest the big builds' chests and bellies lay ON the forearms, 0.25-0.33 into the singlet)."""
    d = bow_down()
    reach = KNEE_Z + (-1.35 - KNEE_Z) * TOR - BOW_HANDS_AHEAD
    d.update({"lh": ("floor", (-BOW_HANDS_X, 0.62, reach)), "rh": ("floor", (BOW_HANDS_X, 0.62, reach)),
              "le": (-1.0, -0.2, -0.2), "re": (1.0, -0.2, -0.2)})
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


def _hand_spans():
    """The game's hand swaps per celebration, read from src/shared/Config/HandShapeConfig.luau (read only): {name:
    {side: [(t0, t1, shape)]}}. The clothes check uses the hand the player actually sees then (a fist's knuckles sit
    elsewhere than an open hand's fingers)."""
    import re
    path = os.path.join(os.path.dirname(os.path.dirname(_HERE)), "src", "shared", "Config", "HandShapeConfig.luau")
    out = {}
    try:
        text = open(path, encoding="utf-8").read()
        block = text[text.index("local CELEBRATIONS"):text.index("local EMOTES")]
    except (OSError, ValueError):
        print("WARNING: HandShapeConfig.luau not read: the clothes check assumes open hands")
        return out
    for line in block.splitlines():
        m = re.match(r"\s*(\w+)\s*=\s*\{(.*)\},", line)
        if not m:
            continue
        spans = {"Left": [], "Right": []}
        for kind, t0, t1, shape in re.findall(r'(right|left|both)\(([\d.]+),\s*([\d.]+),\s*"(\w+)"\)', m.group(2)):
            for side in (("Left", "Right") if kind == "both" else (kind.capitalize(),)):
                spans[side].append((float(t0), float(t1), shape))
        out[m.group(1)] = spans
    return out


HAND_SPANS = _hand_spans()


def clip(name, length, keys, layers=(), kind="standing", source="", rarity="Common", only=None, events=()):
    # clothed: hands and forearms kept out of the meet outfit on every build (celebration_rig.clear_of_clothes; rules
    # 16-17, 2026-11-16), with the hand shapes the game shows (HandShapeConfig)
    c = R.Clip(name, length, keys, layers, clothed=True)
    c.hand_spans = HAND_SPANS.get(name)
    CLIPS[name] = c
    META[name] = {"kind": kind, "source": source, "rarity": rarity, "only": only, "events": list(events)}
    return c


ARMS_AND_HEAD = ("Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand")
RIGHT_ARM_AND_HEAD = ("Head", "RightUpperArm", "RightLowerArm", "RightHand")

# DEFAULT (CEL-71) chalk clap and fist pump: a clap at the chest, a proud beat, one bent-arm fist pump, ~3 s.
# (2026-11-16, legs fix 2: at CLAP, 1.1 in front of the chest, the forearms sank into Fat's and BigBuff's tee and
#  singlet; the clothed solve pushed the hands 0.3 apart and out, so on Fat they did not even meet, and on the way down
#  to hanging they still read 0.03 into Fat's belt. Now the clap is out in front of the widest chest (chest frame, as the
#  emote ChalkClap's), elbows named down and out (never back), and the hands come down round the front of the belly.)
_CCP_CLAP = (-0.56, 0.27, -1.45)
_CCP_APART = (-1.05, 0.34, -1.4)
_CCP_ELBOW = (-0.6, -1.0, 0.0)          # (down and a little out: the forearms up, fingers up, as the old clap; the
#                                          emote's (-0.85, -0.5, -0.15) raised the elbows into chicken wings here)
_ccp_e = {"le": _CCP_ELBOW, "re": mx(_CCP_ELBOW)}
clip("ChalkClapPump", 3.0, [
    K(0.25, with_=[both(_CCP_APART), _ccp_e], up=-4),
    K(0.42, with_=[both(_CCP_CLAP), _ccp_e], up=-7, pos=P(0, -0.05, 0), ease="fast"),
    K(0.58, with_=[both((-0.78, 0.3, -1.42)), _ccp_e], up=-4, pos=(0, 0, 0)),
    K(0.78, with_=both((-1.3, -0.75, -1.35))),
    K(0.95, with_=rest(), cbend=-5, up=4),
    K(1.4, yaw=10, turn=8, cbend=-5, up=4),
    K(1.75, rh=("chest", PUMP_UP), re=ELBOW_PUMP, up=6, ease="fast"),
    K(2.0, rh=("chest", PUMP_DOWN), up=-4, pos=P(0, -0.06, 0), ease="fast"),
    K(2.2, rh=("chest", B((1.52, 0.7, -0.75))), up=0, pos=(0, 0, 0)),
    K(2.6, rh=REST, yaw=0, turn=0, cbend=0, up=0),
    K(3.0),
], kind="standing", source="CEL-71", rarity="Default", events=[(0.42, "ChalkClap"), (2.0, "FistPump")])

# COMMON (CEL-59) exit fist pump: walking off, the right fist comes up to the shoulder and shakes once. Over the walk.
clip("ExitFistPump", 1.6, [
    K(0.3, rh=("chest", PUMP_UP), re=ELBOW_PUMP, up=5, ease="fast"),
    K(0.45, rh=("chest", PUMP_DOWN), ease="fast"),
    K(0.62, rh=("chest", PUMP_UP), ease="fast"),
    K(1.05, rh=("chest", B((1.55, 1.12, -0.3))), up=3),
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
    K(0.6, rh=("chest", H((0.42, 1.62, -0.8))), re=(1.0, 0.1, 0.1), rw=(0.0, 0.0), ease="fast"),
    K(1.65, rh=("chest", H((0.42, 1.62, -0.8)))),
    K(1.95, rh=REST),
    K(2.6, cbend=-5, up=4),
    K(3.0, cbend=0, up=0),
], source="CEL-66", rarity="Common", events=[(0.6, "Salute")])

# UNCOMMON (CEL-46) wingspan T hold: arms swing out and up into a T, chest out, chin up, soaking it in; feet planted.
clip("WingspanHold", 3.4, [
    K(0.35, with_=both(LOW_WING), pos=P(0, -0.1, 0), up=4),
    K(0.8, with_=both(T_OUT), cbend=-7, up=12, pos=P(0, -0.06, 0)),
    K(2.45, with_=both(O((-2.68, 0.55, -0.3))), cbend=-8, up=16),
    K(2.7, up=-10),
    K(3.0, with_=rest(), cbend=0, pos=(0, 0, 0)),
    K(3.4, up=0),
], layers=[sway(0.9, 2.5, 3.0)], source="CEL-46", rarity="Uncommon")

# UNCOMMON (CEL-49) arms up, bounce, grin: both arms straight up, then out low, bouncing on the toes.
_bounce_keys = []
for i, t in enumerate((0.75, 0.95, 1.15, 1.35, 1.55, 1.75)):
    up_beat = i % 2 == 1
    _bounce_keys.append(K(t, pos=P(0, 0.06 if up_beat else -0.2, 0),
                          with_=[feet(y=AY + L(0.1 if up_beat else 0.0), pitch=-22 if up_beat else 0.0),
                                 both(O((-1.85, -0.05 if up_beat else -0.25, -0.5)))]))
clip("ArmsUpBounce", 2.5, [
    K(0.32, with_=both(SKY_OUT), up=14, ease="fast"),
    K(0.68, with_=both(O((-1.9, 0.2, -0.7))), up=8),   # (2026-11-16: -0.45 swung BigBuff's elbows 0.41 back coming down)
    *_bounce_keys,
    K(2.1, with_=[rest(), stand_feet()], pos=(0, 0, 0), up=0),
    K(2.5),
], layers=[bounce(0.7, 1.9, chest=1.5)], source="CEL-49", rarity="Uncommon")

# UNCOMMON (CEL-51) walking finger to the sky: the right arm shoots straight up, chin up, held for three steps. Over
# the walk.
clip("SkyPoint", 3.4, [
    K(0.45, rh=("chest", mx(SKY_OUT)), up=18, ease="fast"),
    K(2.8, rh=("chest", mx(SKY_OUT)), up=20),
    K(3.2, rh=REST, up=0),
    K(3.4),
], kind="walk", source="CEL-51", rarity="Uncommon", only=RIGHT_ARM_AND_HEAD)

# RARE walking "shhh" (user 2026-11-05: celebrations "where they point up or do 'shhh'"; 2026-11-12 with the hand-shape
# swaps): walking off, the right index finger comes up to the lips (the Point hand, HandShapeConfig), the head sweeping
# slowly across the crowd, then the arm drops. Arms and head only, over the walk.
SHH = H((0.16, 0.92, -1.02))         # (right) the hand under the chin, so the pointing finger crosses the lips
clip("Shhh", 3.2, [
    K(0.35, rh=("chest", SHH), re=mx(ELBOW_DOWN), turn=-18, up=6, ease="fast"),
    K(1.1, rh=("chest", SHH), turn=-8, up=6),
    K(1.9, rh=("chest", SHH), turn=12, up=5),
    K(2.4, rh=("chest", SHH), turn=16, up=4),
    K(2.85, rh=REST, turn=0, up=0),
    K(3.2),
], kind="walk", source="User request 2026-11-05 (finger to the lips)", rarity="Rare", only=RIGHT_ARM_AND_HEAD)

# Two that go on ALL THE WAY BACK to the waiting spot (user 2026-11-11: "a celebration that continues even when your
# going back to the bench ... Use the videos i sent you again, to see how they step off and go away from the
# platform"): looped, arms and head only, over the walk back; the server ends them when the lifter arrives.
# Rewatched 2026-11-11: 9FQM0Z6_s8Q 1:16.8-1:17.3 (walks off toward the camera, right fist pumped high, elbow bent, left
# arm swinging low, roaring), lNOrz4CVNMY 20:55.2 (walking off, both arms flung out wide, grinning), 20:56.2 (double
# thumbs up held high to the crowd while walking), 2:36.5-2:39.5 (steps back from the rack, turns, walks off looking up
# at the crowd, the open belt swinging), and the notes' gracious open-palm wave at 23:30 (Clip notes B).
WAVE_HIGH = B((1.45, 1.75, -0.35))    # (right) an open hand up beside the head
PUMP_HIGH = B((1.3, 1.85, -0.35))     # (right) a fist punched up high, elbow bent
ELBOW_HIGH = (1.0, 0.3, -0.15)        # (right) that elbow out to the side (2026-11-14: was behind)
WIDE_WALK = O((-2.3, -0.2, -0.3))     # arms flung out wide, a little down
THUMBS = B((-1.7, 1.4, -0.4))         # both forearms up, fists by the head (thumbs up)

# EPIC crowd pleaser: two fist pumps with a roar, arms flung wide, double thumbs up to the stands; round and round
# until they are back.
clip("CrowdPleaser", 4.4, [
    K(0.35, rh=("chest", PUMP_HIGH), re=ELBOW_HIGH, up=14, turn=-16, ease="fast"),
    K(0.6, rh=("chest", B((1.45, 1.45, -0.35))), re=ELBOW_HIGH, up=10),
    K(0.85, rh=("chest", PUMP_HIGH), re=ELBOW_HIGH, up=15, ease="fast"),
    K(1.3, rh=REST, up=6, turn=0),
    K(1.7, with_=both(WIDE_WALK), up=10, turn=8),
    K(2.4, with_=both(O((-2.35, -0.1, -0.25))), up=12, turn=12),
    K(2.8, with_=both(THUMBS), le=ELBOW_BICEP, re=mx(ELBOW_BICEP), up=12, turn=0, ease="fast"),
    K(3.5, with_=both(B((-1.7, 1.48, -0.4))), up=14),
    K(4.0, with_=rest(), up=0),
    K(4.4),
], kind="walkloop", source="Walk-off: 9FQM0Z6_s8Q 1:16.8, lNOrz4CVNMY 20:55", rarity="Epic", only=ARMS_AND_HEAD)

# RARE thank-you wave: an open hand waved up to the crowd, then the hand on the heart with a nod; again and again
# until they are back.
clip("ThankYouWave", 3.6, [
    K(0.4, rh=("chest", WAVE_HIGH), re=ELBOW_HIGH, turn=-18, up=8, ease="fast"),
    K(0.65, rh=("chest", B((1.75, 1.7, -0.3))), re=ELBOW_HIGH),
    K(0.9, rh=("chest", B((1.2, 1.78, -0.4))), re=ELBOW_HIGH),
    K(1.15, rh=("chest", B((1.75, 1.7, -0.3))), re=ELBOW_HIGH),
    K(1.4, rh=("chest", WAVE_HIGH), re=ELBOW_HIGH),
    K(1.9, rh=("chest", CHEST_HEART), re=ELBOW_HEART, turn=-8, up=-6),
    K(2.4, rh=("chest", CHEST_HEART), re=ELBOW_HEART, up=2),
    K(2.7, rh=("chest", B((1.2, -0.2, -1.1))), re=ELBOW_HEART, up=1),   # (out in front of the belly on the way down),
    K(3.0, rh=REST, turn=0, up=0),
    K(3.6),
], kind="walkloop", source="Walk-off: lNOrz4CVNMY 23:30", rarity="Rare", only=RIGHT_ARM_AND_HEAD)

# RARE (CEL-34) relief roar, hands locked on the head: a heavyweight's sinking roar, arms down and tense, then both
# hands onto the crown, face up. Feet planted.
clip("ReliefRoar", 4.2, [
    K(0.4, pos=P(0, -0.42, 0.05), lean=10, cbend=-4, up=22, with_=both(B((-1.3, -0.95, -0.2))), ease="fast"),
    K(1.35, pos=P(0, -0.38, 0.05), lean=8, up=24),
    K(1.75, pos=P(0, -0.08, 0), lean=0, cbend=0, up=6, with_=rest()),
    K(2.25, with_=both(HEAD_TOP, HEAD_TOP_R), le=ELBOW_HEAD, re=mx(ELBOW_HEAD), lw=HEAD_W_L, rw=HEAD_W_R, cbend=-9, up=12,
      ease="smooth"),
    K(3.2, with_=both(HEAD_TOP, HEAD_TOP_R), le=ELBOW_HEAD, re=mx(ELBOW_HEAD), lw=HEAD_W_L, rw=HEAD_W_R, cbend=-8, up=10),
    K(3.65, with_=rest(), lw=(0, 0), rw=(0, 0), cbend=0, up=0, pos=(0, 0, 0)),
    K(4.2),
], layers=[tremble(0.45, 1.4, amp=0.03, chest=1.8)], source="CEL-34", rarity="Rare", events=[(0.4, "Roar")])

# RARE (CEL-36) wait for the lights, then arms straight up: hands on hips watching the judges, then both arms shoot up.
clip("LightsArmsUp", 3.8, [
    K(0.4, with_=both(HIPS), turn=-30, up=4, le=(-0.6, -0.2, 0.8), re=(0.6, -0.2, 0.8)),
    K(1.25, with_=both(HIPS), turn=-32, up=6),
    K(1.55, with_=both(SKY_OUT), turn=0, up=20, cbend=-7, ease="fast"),
    K(2.7, with_=both(SKY_OUT), up=22, cbend=-8),
    K(3.25, with_=rest(), up=0, cbend=0),
    K(3.8),
], layers=[tremble(1.65, 2.7, amp=0.04, chest=1.2)], source="CEL-36", rarity="Rare", events=[(1.55, "Roar")])

# RARE (CEL-43) sit down and laugh at the lights: sits on the platform, leaning back on the right hand, laughing.
# Sitting on the floor: the root stays 1.73 above it (the hips on the floor), the feet out in front of the hips a leg's
# stretch further, the hand behind the hips an arm's stretch further (all written on the block rig).
SEAT_Y = -1.27 + 3.0 - R.HRP.y
SEAT_Z = 0.55


def from_seat(z, scale):
    """A floor-space z written on the block rig for a foot or hand reaching out from the seated hips."""
    return SEAT_Z + (z - SEAT_Z) * scale


_seat = {"pos": (0, SEAT_Y, SEAT_Z), "lean": -28, "lf": (-0.62, AY, from_seat(-0.62, LEG), 28, 0),
         "rf": (0.18, AY, from_seat(-0.78, LEG), 8, 0)}
_hand_back = ("floor", (1.4, 0.32, from_seat(0.9, R.S.ARM_SCALE)))   # (out to the side: at 1.05 the arm ran through the hip, 2026-11-14)   # (an arm's stretch: the arm factor)
clip("SitAndLaugh", 5.2, [
    K(0.6, pos=P(0, -0.75, 0.25), lean=22, up=-8, with_=both(B((-1.5, -0.9, -0.8)), B((1.55, -1.0, -0.1)))),
    K(1.15, with_=_seat, lh=("chest", B((-1.25, -0.6, -1.2))), rh=_hand_back, up=30, turn=-12),
    K(3.0, with_=_seat, lh=("chest", B((-1.3, -0.35, -1.35))), rh=_hand_back, up=30, turn=-8),
    # (2026-11-16, legs fix 2: getting up, the hands keyed on the knees sat inside the longer thighs of every build and
    #  the clothed solve shoved them out a different way on each (out on Fat, up on BigBuff with a straight arm): 0.06
    #  into Fat's shorts and a 1005 deg/s jerk. Now (chest frame) on the OUTSIDE of the knees, clear on every build, and
    #  the left hand comes round there out wide.)
    K(3.3, lh=("chest", (-1.8, -0.8, -1.15)), rh=("chest", B((1.65, -0.55, -0.35))), lf=(-0.56, AY + L(0.2), (from_seat(-0.62, LEG) - 0.15) / 2, 18, 0),
      rf=(0.3, AY + L(0.2), (from_seat(-0.78, LEG) - 0.2) / 2, 8, 0)),   # (feet lifted as they are drawn in: they slid)
    K(3.55, pos=P(0, -1.0, 0.25), lean=26, lh=("chest", (-1.6, -1.05, -1.2)), rh=("chest", (1.6, -1.24, -1.19)),   # (pushes up off the knees)
     
      up=-5, turn=0, lf=foot("Left", z=-0.15), rf=foot("Right", z=-0.2)),
    K(4.2, pos=P(0, -0.3, 0.05), lean=10, with_=[rest(), stand_feet()], up=0),
    K(4.7, pos=(0, 0, 0), lean=0),
    K(5.2),
], layers=[bounce(1.25, 2.95)], source="CEL-43", rarity="Rare", events=[(1.15, "SitDown"), (1.3, "Laugh")])

# EPIC (CEL-26) double finger point and prance: giddy hands at the chin with a skip, then both arms up pointing at the
# ceiling and alternating high knees.
_prance = []
for i, t in enumerate((1.33, 1.58, 1.83, 2.08, 2.33)):   # (0.25 s a step: 0.22 snapped the knees)
    left_up = i % 2 == 0
    _prance.append(K(t, pos=P(0, 0.06, 0),
                     lf=foot("Left", y=AY + L(0.75 if left_up else 0.0), z=AZ - L(0.45 if left_up else 0.0),
                             pitch=12 if left_up else 0.0),
                     rf=foot("Right", y=AY + L(0.0 if left_up else 0.75), z=AZ - L(0.0 if left_up else 0.45),
                             pitch=0.0 if left_up else 12)))
clip("PointAndPrance", 3.6, [
    K(0.3, with_=both(CHIN), rf=foot("Right", y=AY + L(0.45), z=AZ - L(0.3)), pos=P(0, 0.05, 0), up=4),
    K(0.55, rf=R.stand_foot("Right"), pos=P(0, -0.08, 0)),
    K(0.85, with_=both(CHIN), pos=(0, 0, 0), up=6),
    K(1.02, with_=both(B((-1.25, 1.35, -0.85))), pos=P(0, 0.02, 0), up=10),   # (hands rise in front first: straight from the chin the arms flipped)
    K(1.2, with_=both(SKY_OUT), rf=foot("Right", y=AY + L(0.8), z=AZ - L(0.5), pitch=12),
      pos=P(0, 0.08, 0), up=18, ease="fast"),
    *_prance,
    K(2.58, with_=[stand_feet(), both(SKY_OUT)], pos=P(0, -0.05, 0)),
    K(2.85, with_=both(O((-2.3, 0.7, -0.65))), le=(-0.4, -1.0, -0.3), re=(0.4, -1.0, -0.3), pos=(0, 0, 0), up=6),
    # (2026-11-16: out at -0.3 BigBuff's elbows swung 0.45 back on the way down: the arms come down in front)
    K(3.25, with_=rest(), up=0),
    K(3.6),
], source="CEL-26", rarity="Epic", events=[(1.1, "Scream")])

_FIST_CHEST_OUT = (-0.72, 0.8, -1.5)      # (chest frame) the guard out in front of every build's chest (FIST_CHEST sank)
_FISTS_DOWN_FWD = (-0.92, -1.0, -1.7)     # (chest frame) fists pulled down in front of the knees, not into the thighs
_GOALPOST_FWD = O((-1.95, 1.05, -0.32))   # (2026-11-16: GOALPOST's elbows went 0.40 back on BigBuff from the V: forward)
_ELBOW_GOAL_FWD = (-0.72, -0.7, -0.1)
# EPIC (CEL-20) rack-side double fist roar: a wide half squat with fists at the chest, up into a V, down into
# goalposts, then sinking deep and pulling both fists down.
clip("RackSideRoar", 3.4, [
    K(0.15, pos=P(0, 0.05, 0), with_=feet(x=0.72, y=AY + L(0.18), yaw=12)),   # (a little hop out to the wide stance: the feet slid)
    K(0.3, with_=[feet(x=WIDE, yaw=24), both(_FIST_CHEST_OUT)], pos=P(0, -0.55, 0.05), lean=10, up=8),
    K(0.65, with_=both(V_UP), pos=P(0, -0.05, 0), lean=-4, cbend=-10, up=30, ease="fast"),
    K(1.1, with_=both(_GOALPOST_FWD), le=_ELBOW_GOAL_FWD, re=mx(_ELBOW_GOAL_FWD), pos=P(0, -0.6, 0.05), lean=8, cbend=0, up=14,
      ease="fast"),
    K(1.6, with_=both(_FISTS_DOWN_FWD), pos=P(0, -0.9, 0.15), lean=30, up=-16, ease="fast"),
    K(1.95, with_=both(_FISTS_DOWN_FWD), pos=P(0, -0.88, 0.15), lean=30),   # (the hold re-states its fists: sliding
    #                                                                       on toward the rest they went into the thighs)
    K(2.15, with_=both((-1.5, -1.15, -1.3)), le=ELBOW_OUT, re=mx(ELBOW_OUT)),   # (rising: the fists come up round the outside of the thighs)
    K(2.45, with_=[rest(), stand_feet()], pos=(0, 0, 0), lean=0, up=0),
    K(3.4),
], layers=[tremble(0.7, 2.0, amp=0.04, chest=1.5)], source="CEL-20", rarity="Epic",
    events=[(0.65, "Roar"), (1.1, "Roar"), (1.6, "Roar")])

# EPIC (CEL-18) crouch roar into a tuck jump: a deep crouch roar with fists low, a crunch, a tuck jump, a little hop.
_air = {"lf": foot("Left", y=AY + L(1.1), z=AZ + L(0.3), pitch=-25),
        "rf": foot("Right", y=AY + L(1.1), z=AZ + L(0.3), pitch=-25)}
clip("CrouchRoarJump", 4.2, [
    K(0.4, with_=[feet(x=0.75, yaw=20), both(_FISTS_DOWN_FWD)], pos=P(0, -0.78, 0.1), lean=26, cbend=3, up=26,
      ease="fast"),   # (2026-11-16: the fists in front of the knees; between them they sank into the thighs and shorts)
    K(1.15, with_=both(_FISTS_DOWN_FWD), pos=P(0, -0.75, 0.1), lean=25, cbend=3, up=24),   # (the chest holds too: easing
    #   on toward the crunch it carried the fists down onto Fat's knees)
    K(1.4, with_=both(B((-0.6, -0.45, -1.4))), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.22, 0), lean=12, cbend=18,
      up=4),
    K(1.65, with_=[stand_feet(), both(B((-1.45, -1.0, 0.0)))], pos=P(0, -0.5, 0.05), lean=16, cbend=6),
    K(1.85, pos=P(0, 0.05, 0), lean=4, cbend=0, with_=[feet(pitch=-30), both(FIST_CHEST)], ease="fast"),
    K(2.1, pos=P(0, 0.78, 0), lean=0, with_=_air, ease="fast"),
    K(2.35, pos=(0, 0.0, 0), with_=[stand_feet(), both(O((-1.85, -0.05, -0.5)))], ease="slow"),
    K(2.55, pos=P(0, -0.45, 0.05), lean=12),
    K(2.8, pos=P(0, 0.05, 0), lean=0, with_=feet(pitch=-25), ease="fast"),
    K(2.95, pos=P(0, 0.32, 0), with_=feet(y=AY + L(0.3), pitch=-10), ease="fast"),
    K(3.1, pos=(0, 0.0, 0), with_=stand_feet(), ease="slow"),
    K(3.25, pos=P(0, -0.25, 0), with_=both(O((-1.6, -0.35, -0.35)))),
    K(3.7, pos=(0, 0, 0), with_=rest(), up=0, lean=0),
    K(4.2),
], layers=[tremble(0.45, 1.15, amp=0.04, chest=1.6)], source="CEL-18", rarity="Epic",
    events=[(0.4, "Roar"), (2.35, "Land"), (3.1, "Land")])

# EPIC (CEL-17) wingspan roar into the crunch: watches the lights, flings both arms out to a T roaring, holds it, then
# sweeps down into a crunching squeeze, roaring at the floor. Feet planted.
clip("WingspanCrunch", 4.2, [
    K(0.35, turn=-30, up=4),
    K(0.8, turn=-26, rh=("chest", O((1.6, -0.6, -0.4)))),
    K(1.05, with_=both(T_OUT), turn=0, cbend=-8, up=16, pos=P(0, -0.1, 0), ease="fast"),
    K(2.2, with_=both(O((-2.45, 0.6, -0.95))), cbend=-9, up=26),
    K(2.55, with_=both(B((-1.45, -0.85, -0.75))), pos=P(0, -0.35, 0.05), cbend=4, up=8),
    K(2.85, with_=both(B((-0.55, -0.45, -1.4))), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.62, 0.1), lean=15,
      cbend=24, up=-16, ease="fast"),
    K(3.45, pos=P(0, -0.6, 0.1), lean=15, cbend=24, up=-14),
    K(3.85, with_=rest(), pos=(0, 0, 0), lean=0, cbend=0, up=0),
    K(4.2),
], layers=[tremble(1.1, 2.2, amp=0.035, chest=1.2), tremble(2.9, 3.45, amp=0.05, chest=2.0)], source="CEL-17",
    rarity="Epic", events=[(1.05, "Roar"), (2.85, "Roar")])

# LEGENDARY (CEL-02) disbelief, deep squat, arms to the sky, prayer hands: frozen shock, hands on the head, a roar
# with fists yanked to the chest, a full deep squat, "can you believe it", arms up in a V, hands over the face.
clip("DisbeliefPrayer", 9.6, [
    K(0.65, up=-3),
    K(1.0, rh=("chest", HEAD_TOP_R), re=mx(ELBOW_HEAD), rw=HEAD_W_R, up=-8, hroll=-7, pos=P(0, -0.08, 0)),
    K(1.3, with_=feet(x=WIDE, yaw=26)),
    K(1.5, with_=both(HEAD_TOP, HEAD_TOP_R), le=ELBOW_HEAD, re=mx(ELBOW_HEAD), lw=HEAD_W_L, rw=HEAD_W_R, pos=P(0, -0.32, 0.02), lean=-6, up=-4, hroll=0),
    K(1.75, with_=both(H((-1.05, 2.25, -0.85))), le=ELBOW_HEAD, re=mx(ELBOW_HEAD), lw=(40, -60), rw=(40, 60)),   # (hands up off the head and forward)
    K(2.05, with_=both(FIST_CHEST_W), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), lw=(0, 0), rw=(0, 0), pos=P(0, -0.42, 0.05), lean=10, up=6,
      ease="fast"),
    K(2.45, with_=both(B((-1.6, -0.9, -0.75))), pos=P(0, -0.2, 0.02), lean=4, up=10),   # (2026-11-16: out from the belt:
    #   at (-1.45, -0.9, -0.55) the forearms grazed Fat's belt)
    K(2.95, with_=both(B((-0.5, 0.35, -1.0))), pos=P(0, -1.22, 0.32), lean=24, up=-8),
    K(3.5, pos=P(0, -1.22, 0.32), lean=24, up=-10),
    K(4.0, pos=P(0, -0.25, 0.05), lean=6, up=0),
    K(4.45, with_=[rest(), stand_feet()], pos=(0, 0, 0), lean=0, turn=22, up=10),
    K(5.0, turn=-16, up=12),
    K(5.5, with_=both(O((-1.85, 0.78, -0.6))), le=(-0.6, -1.0, 0.2), re=(0.6, -1.0, 0.2), turn=0, up=10, hroll=6),
    K(6.0, with_=both(O((-2.35, 0.55, -0.45)), HEAD_TOP_R), re=mx(ELBOW_HEAD), rw=HEAD_W_R, hroll=0),
    K(6.5, with_=both(V_UP), rw=(0, 0), pos=P(0, -0.12, 0), cbend=-8, up=30, ease="fast"),
    K(7.35, with_=both(V_UP), pos=P(0, -0.1, 0), cbend=-9, up=32),
    K(7.8, with_=both(O((-1.9, 0.4, -0.7))), pos=(0, 0, 0), cbend=0, up=8),
    K(8.3, with_=both(PRAYER), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), cbend=12, up=-10),
    K(8.85, lean=9, cbend=14, up=-14),
    K(9.2, with_=rest(), lean=0, cbend=0, up=0),
    K(9.6),
], layers=[tremble(1.95, 2.45, amp=0.05, chest=2.0), tremble(6.55, 7.35, amp=0.04, chest=1.2)],
    source="CEL-02", rarity="Legendary", events=[(2.05, "Roar"), (6.5, "Roar")])

# LEGENDARY (CEL-03) world-record roar into wingspan and double biceps: a crouched scream, a hop back with the arms
# flung up and wide, leaning back, turning to the crowd, then a double biceps.
clip("WingspanBiceps", 6.2, [
    K(0.3, with_=[feet(x=0.8, yaw=22), both(_FISTS_DOWN_FWD)], pos=P(0, -0.62, 0.12), lean=30, up=-6),   # (in front of
    #   the knees, 2026-11-16: between them they sank into the thighs)
    K(0.5, up=30, ease="fast"),
    K(0.85, pos=P(0, 0.25, 0.3), lean=0, with_=feet(x=0.8, y=AY + L(0.25), z=AZ + L(0.2), yaw=22, pitch=-15),
      ease="fast"),
    K(1.05, with_=[both(O((-2.35, 1.75, -0.2))), feet(x=0.8, z=AZ + L(0.32), yaw=22)], pos=P(0, -0.05, 0.32),
      lean=-14, up=30, ease="slow"),
    K(1.25, rf=foot("Right", x=0.8, y=AY + L(0.25), z=AZ + L(0.55), yaw=22)),   # (the step back lifted: it slid)
    K(1.45, with_=both(T_OUT), rf=foot("Right", x=0.8, z=AZ + L(0.75), yaw=22), yaw=24, lean=-10, up=24),
    K(1.95, with_=both(LOW_WING), turn=18, up=24, hroll=10, lean=-4),
    K(2.6, with_=[rest(), stand_feet()], pos=(0, 0, 0), yaw=0, lean=0, turn=0, up=4, hroll=0),
    K(3.1, with_=both(O((-2.5, 0.25, -0.3))), up=8),
    K(3.6, with_=both(B((-0.7, -0.75, -1.25))), up=0),
    K(4.05, with_=both(DB_OPEN_OLD), le=ELBOW_DB_OLD, re=mx(ELBOW_DB_OLD), cbend=-9, up=6, pos=P(0, -0.1, 0), ease="fast"),
    K(4.95, with_=both(DB_OPEN_OLD), le=ELBOW_DB_OLD, re=mx(ELBOW_DB_OLD), cbend=-10, up=6),
    K(5.3, with_=both(B((-0.6, -0.55, -1.3))), cbend=0, pos=(0, 0, 0)),
    K(5.75, with_=rest()),
    K(6.2),
], layers=[tremble(0.5, 0.85, amp=0.05, chest=2.0), tremble(4.1, 4.95, amp=0.045, chest=1.0)],
    source="CEL-03", rarity="Legendary", events=[(0.5, "Roar"), (1.05, "Roar"), (4.05, "Flex")])

# LEGENDARY (CEL-04) leap and bow to the platform: springs up with the hands up by the head, shins tucked back, lands
# straight on both knees and folds into a forehead-to-floor bow; then up and away.
_kneel = kneel()


def leg_air(y):
    """A floor-space height of a knee or ankle in the air, written on the block rig: stretched with the legs from the
    ankle joint's height, as the hips' jump is (P)."""
    return ANKLE.y + (y - ANKLE.y) * LEG


clip("LeapAndBow", 5.8, [
    K(0.32, with_=both(B((-1.6, -0.95, -0.2))), pos=P(0, -0.55, 0.08), lean=20, up=-6),
    K(0.55, pos=P(0, 0.1, 0), lean=4, with_=[feet(pitch=-30), both(B((-1.55, 0.9, -0.6)))], ease="fast"),
    K(0.85, pos=P(0, 0.85, 0), lean=6, up=-16, with_=both(B((-1.75, 1.25, -0.2))), le=(-1.0, 0.0, -0.2), re=(1.0, 0.0, -0.2),
      lk=(-0.52, leg_air(2.3), L(-0.45)), rk=(0.52, leg_air(2.3), L(-0.45)),
      lf=(-0.55, leg_air(1.8), L(0.35), 4, -45), rf=(0.55, leg_air(1.8), L(0.35), 4, -45), ease="fast"),
    K(1.18, pos=_kneel["pos"], lean=4, lk=_kneel["lk"], rk=_kneel["rk"], lf=_kneel["lf"], rf=_kneel["rf"],
      up=-20, ease="slow"),
    K(1.35, pos=(0, KNEEL_Y - 0.1, -0.05), lean=8),
    K(1.75, with_=bow_down_clear(), ease="smooth"),
    K(2.85, with_=bow_down_clear()),
    K(3.35, with_=[_kneel, rest()], cbend=0, up=0),
    K(3.75, rk=None, rf=foot("Right", z=AZ - L(0.55)), pos=(0, KNEEL_Y + 0.06, -0.15), lean=14),
    K(4.45, with_=[free_knees(), stand_feet()], pos=(0, 0, 0), lean=0),
    K(5.8),
], source="CEL-04", rarity="Legendary", events=[(0.55, "Roar"), (1.18, "KneeThud"), (1.75, "Bow")])

# LEGENDARY (CEL-05) bow down, then rise roaring: stunned, knees buckle into a face-down bow, then up on the knees with
# fists at the chin, fists driven down and head thrown back in a roar, up to standing, hand on the heart.
clip("BowAndRise", 6.6, [
    K(0.7, up=-2),
    K(1.05, pos=P(0, -0.3, 0.05), lean=16, with_=both(B((-0.95, -1.2, -0.9))), up=-10),
    K(1.55, with_=[kneel(48)], cbend=16, lh=("floor", (-0.8, 0.5, KNEE_Z + (-0.9 - KNEE_Z) * TOR)),
      rh=("floor", (0.8, 0.5, KNEE_Z + (-0.9 - KNEE_Z) * TOR))),
    K(2.05, with_=bow_down_clear()),
    K(2.95, with_=bow_down_clear()),
    # (2026-11-16, longer thighs: at x 0.95, z -0.7 the hands pushing up off the floor went 0.68 into Fat's knees and
    #  thighs, anim_qa: now a little wider and further ahead, beside the knees)
    K(3.45, with_=kneel(46), lh=("floor", (-1.15, 0.55, KNEE_Z + (-0.8 - KNEE_Z) * TOR)),
      rh=("floor", (1.15, 0.55, KNEE_Z + (-0.8 - KNEE_Z) * TOR)), cbend=14, up=-5),
    K(3.65, with_=[kneel(0), both(H((-0.45, 0.95, -0.85)))], le=ELBOW_DOWN, re=mx(ELBOW_DOWN), up=-6),
    K(3.95, with_=both(B((-1.28, -1.05, -0.15))), cbend=-10, up=6, ease="fast"),
    K(4.2, up=32, cbend=-12, ease="fast"),
    K(4.6, lean=14, cbend=0, up=18, with_=both(B((-0.65, -1.1, -0.85))), rk=None,
      rf=foot("Right", z=AZ - L(0.55))),
    K(5.1, with_=[free_knees(), stand_feet()], pos=(0, 0, 0), lean=0, up=6),
    K(5.55, rh=("chest", CHEST_HEART), lh=REST, re=ELBOW_HEART, up=4),
    K(5.9, rh=("chest", B((1.2, -0.2, -1.1))), re=ELBOW_HEART, up=2),
    K(6.25, rh=REST, up=0),
    K(6.6),
], layers=[tremble(4.0, 4.95, amp=0.05, chest=2.2)], source="CEL-05", rarity="Legendary",
    events=[(1.55, "KneeThud"), (4.2, "Roar")])

# LEGENDARY (CEL-01) record jump-and-roar with chalk burst: arms wide and low in disbelief, looks up at the screen,
# hands on the head, folds forward, a skip, a tucked jump punching forward, a big clap that bursts chalk, a fist to the
# sky out of the cloud.
clip("RecordJumpRoar", 9.2, [
    K(0.4, with_=[both(O((-2.2, -0.5, -0.4))), feet(x=0.75, yaw=18)], pos=P(0, -0.12, 0.05), cbend=-8, up=12),
    K(1.6, with_=both(O((-2.25, -0.45, -0.45))), cbend=-9, up=14),
    K(1.9, with_=[rest(), stand_feet()], pos=(0, 0, 0), cbend=0, up=4),
    K(2.25, up=26),
    K(3.0, up=28),
    K(3.6, with_=both(HEAD_TOP, HEAD_TOP_R), le=ELBOW_HEAD, re=mx(ELBOW_HEAD), lw=HEAD_W_L, rw=HEAD_W_R, up=8),
    K(4.0, with_=both(HEAD_TOP, HEAD_TOP_R), le=ELBOW_HEAD, re=mx(ELBOW_HEAD), lw=HEAD_W_L, rw=HEAD_W_R, pos=P(0, -0.42, 0.05), lean=8,
      up=0),
    K(4.45, pos=P(0, -0.42, 0.08), lean=25, cbend=8, up=-6,   # (bent forward holding the head: the hands-on-head hold, a shallower fold:
      #   folded 46 deg the draped hands stuck out in the air or went into the head; 2026-11-14)
      with_=both(HEAD_TOP, HEAD_TOP_R), le=ELBOW_HEAD, re=mx(ELBOW_HEAD),
      lw=HEAD_W_L, rw=HEAD_W_R),
    K(4.7, with_=both(H((-1.05, 2.2, -0.85))), le=ELBOW_HEAD, re=mx(ELBOW_HEAD), lw=(40, -60), rw=(40, 60), pos=P(0, -0.3, 0.06), lean=20,
      cbend=6, up=-6),   # (hands up off the head and forward)
    K(4.95, pos=P(0, -0.15, 0), lean=4, cbend=0, up=8, with_=both(B((-1.0, 0.55, -1.05))), lw=(0, 0), rw=(0, 0), le=(-0.6, -1, 0.2),
      re=(0.6, -1, 0.2)),
    K(5.1, pos=P(0, 0.12, 0), with_=feet(pitch=-20), ease="fast"),
    K(5.25, pos=P(0, -0.05, 0), with_=stand_feet()),
    K(5.5, with_=both(FIST_CHEST), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), rf=foot("Right", y=AY + L(0.85), z=AZ - L(0.5),
      pitch=10), pos=P(0, 0.06, 0)),
    K(5.75, rf=R.stand_foot("Right"), pos=P(0, -0.5, 0.05), lean=10),
    K(5.95, pos=P(0, 0.08, 0), lean=0, with_=feet(pitch=-30), ease="fast"),
    K(6.2, pos=P(0, 0.82, 0), lean=-8, with_=[_air, both(F((-0.55, 0.6, -1.55)))], ease="fast"),
    K(6.45, pos=(0, 0, 0), lean=0, with_=[stand_feet(), both(FIST_CHEST)], ease="slow"),
    K(6.65, pos=P(0, -0.45, 0.05), lean=10),
    K(6.85, with_=both(B((-1.25, 1.05, -1.0))), pos=P(0, -0.1, 0), lean=0, up=8),
    K(7.0, with_=both(B((-0.5, 1.02, -1.08))), up=10, ease="fast"),
    K(7.3, rh=("chest", mx(SKY_OUT)), lh=("chest", B((-0.6, 0.6, -1.0))), up=28, ease="fast"),
    K(7.55, rh=("chest", O((1.4, 1.85, -0.35)))),
    K(7.8, rh=("chest", mx(SKY_OUT))),
    K(8.15, with_=both(CLAP), up=6),
    K(8.65, with_=rest(), up=0),
    K(9.2),
], layers=[tremble(5.0, 5.4, amp=0.03)], source="CEL-01", rarity="Legendary",
    events=[(6.45, "Land"), (7.0, "ChalkBurst"), (7.3, "Roar")])


# ---------------------------------------------------------------- from the full Meet Study (2026-11-14)
# References/Meet Study/Meet Celebration Catalogue.md: every second of the user's meet videos studied; MC numbers.

# LEGENDARY (MC-010; 9FQM0Z6_s8Q 6:46-7:07, a -120 kg man's world-record deadlift) flexed roar, V, hands clamped on
# the head: up out of the bend with the fists curled, a double-biceps roar, both arms high in a V with the head back,
# both hands clamped on top of the head screaming at the ceiling, then a crouched roar with the fists low and a last
# arms-flared roar at the camera. The feet stay planted (wide, as he left the bar): it suits every build, heavyweights
# included. (The real lifter starts yelling while still holding the lockout: that belongs to the lift; this starts with
# the bar on the floor, as every celebration does.)
# (every hold re-states its hands and elbows: a hand track otherwise keeps sliding toward its next key)
_DB_FIST = (_SHOULDER_NOW[0] - 1.05, _SHOULDER_NOW[1] + 0.95, -0.15)   # double biceps on the long arms: upper arm out
#                                                                          level, forearm straight up, fist by the head
_BENT_HANDS = B((-0.85, -0.85, -1.25))     # hanging forward of the belly while bent over the bar (clear of Fat's)
_FISTS_LOW_OUT = B((-0.95, -0.7, -0.95))   # fists low by the hips, elbows out ("gorilla"), clear of every belly
_HEAD_CLAMP = H((-0.88, 2.24, 0.0))         # the WRIST at the side of the head, just under the crown: the big hand drapes
#   over the top (the hand target is the wrist). User 2026-11-14: elbows thrown back are "physically impossible": the elbows
#   go out to the sides at ear height (measured: head top 2.27, chest frame)
_HEAD_CLAMP_R = H((0.88, 2.24, 0.0))
_ELBOW_HEAD_SIDE = (-1.0, 0.3, -0.2)        # (left) elbow out to the side and up, a touch forward
_FLARE = O((-1.9, -0.4, -0.45))            # arms flared down and out, roaring at the camera
# (2026-11-14: the open double biceps the user asked for; ELBOW_OUT threw the raised elbows behind the body)
_HOLD_DB = dict(with_=both((_SHOULDER_NOW[0] - 0.85, _SHOULDER_NOW[1] + 1.44, -0.1)), le=(-1.0, -0.25, 0.05),
                re=(1.0, -0.25, 0.05))
_HOLD_HEAD = dict(with_=both(_HEAD_CLAMP, _HEAD_CLAMP_R), le=_ELBOW_HEAD_SIDE, re=mx(_ELBOW_HEAD_SIDE), lw=(70.0, -90.0), rw=(70.0, 90.0))
_HOLD_LOW = dict(with_=both(_FISTS_LOW_OUT), le=ELBOW_OUT, re=mx(ELBOW_OUT), lw=(0.0, 0.0), rw=(0.0, 0.0))
_HOLD_FLARE = dict(with_=both(_FLARE), le=ELBOW_OUT, re=mx(ELBOW_OUT))
clip("HeadClampRoar", 7.0, [
    K(0.4, with_=both(_BENT_HANDS), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), pos=P(0, -0.5, 0.15), lean=32, up=8),
    K(1.0, **_HOLD_DB, pos=P(0, -0.15, 0.03), lean=4, cbend=-8, up=24),
    K(1.4, **_HOLD_DB, pos=P(0, -0.15, 0.03), lean=4, cbend=-9, up=26),
    K(1.9, with_=both(V_UP), pos=P(0, -0.04, 0), lean=-4, cbend=-10, up=32),
    K(2.3, with_=both(V_UP), pos=P(0, -0.04, 0), lean=-4, cbend=-10, up=33, lw=(0.0, 0.0), rw=(0.0, 0.0)),
    K(2.7, **_HOLD_HEAD, pos=P(0, -0.05, 0), lean=-2, cbend=-6, up=14),
    K(3.0, **_HOLD_HEAD, pos=P(0, -0.08, 0), lean=-2, cbend=-11, up=22),
    K(4.0, **_HOLD_HEAD, pos=P(0, -0.08, 0), lean=-2, cbend=-11, up=20),
    K(4.5, **_HOLD_LOW, pos=P(0, -0.45, 0.08), lean=18, cbend=6, up=6),
    K(5.05, **_HOLD_LOW, pos=P(0, -0.45, 0.08), lean=18, cbend=6, up=8),
    K(5.4, **_HOLD_FLARE, pos=P(0, -0.1, 0), lean=8, cbend=-4, up=14),
    K(6.0, **_HOLD_FLARE, pos=P(0, -0.1, 0), lean=8, cbend=-4, up=14),
    K(6.5, with_=rest(), pos=(0, 0, 0), lean=0, cbend=0, up=0),
    K(7.0),
], layers=[tremble(1.0, 1.4, amp=0.045, chest=1.4), tremble(3.0, 4.0, amp=0.05, chest=2.0),
           tremble(4.5, 5.05, amp=0.045, chest=1.6)],
    source="MC-010", rarity="Legendary", events=[(1.0, "Roar"), (3.0, "Roar"), (4.5, "Roar")])


# (Batch 2 rules, from its QA: a raised arm is held a little OUT from the head (SKY_CLEAR; straight up, the upper arm
#  sank into the head on the big builds); fists in front of the body sit forward of Fat's belly; feet stay planted.)
SKY_CLEAR = O((-1.55, 2.2, -0.25))           # an arm straight up, out from the head (left; mx for the right; -1.3 grazed Muscular)

# EPIC (MC-020; 3i4jvmDrtdY 4:50-4:54.5, a heavy 93 kg man's lead-taking deadlift) power-crunch "gorilla" roar: chest
# out, fists at the hips roaring at the ceiling, crunch down into a hunched half squat with the fists pulled in front of
# the belly yelling at the floor, up again, down once more with the fists to the knees. Feet planted: heavy builds.
_FISTS_HIPS = B((-1.55, -0.75, -0.85))      # fists at the hips, elbows bent out
_FISTS_BELLY = B((-0.6, -0.15, -1.55))     # fists pulled in front of the belly (forward of the biggest belly)
_FISTS_BELLY_W = B((-0.72, -0.15, -1.55))  # (2026-11-16: a touch apart: Skinny's fists went 0.16 into each other)
_FISTS_KNEES = B((-0.9, -0.9, -1.2))
clip("GorillaRoar", 3.6, [
    K(0.4, with_=both(_FISTS_HIPS), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.12, 0), cbend=-8, up=20),
    K(0.85, with_=both(_FISTS_HIPS), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.12, 0), cbend=-9, up=22),
    K(1.25, with_=both(_FISTS_BELLY_W), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), pos=P(0, -0.5, 0.08), lean=22, cbend=14,
      up=-12),
    K(1.65, with_=both(_FISTS_BELLY_W), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), pos=P(0, -0.5, 0.08), lean=22, cbend=14,
      up=-10),
    K(2.0, with_=both(_FISTS_HIPS), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.12, 0), lean=0, cbend=-8, up=18),
    K(2.35, with_=both(_FISTS_KNEES), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.45, 0.08), lean=20, cbend=8, up=-4),
    K(2.75, with_=both(_FISTS_KNEES), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.45, 0.08), lean=20, cbend=8, up=-2),
    K(3.15, with_=rest(), pos=(0, 0, 0), lean=0, cbend=0, up=0),
    K(3.6),
], layers=[tremble(0.4, 0.85, amp=0.04, chest=1.6), tremble(1.25, 1.65, amp=0.05, chest=2.0),
           tremble(2.35, 2.75, amp=0.045, chest=1.8)],
    source="MC-020", rarity="Epic", events=[(0.4, "Roar"), (1.25, "Roar"), (2.35, "Roar")])

# EPIC (MC-008; YMrXwUrTpkw 2:06.8-2:11.5, a 93 kg man's junior world-record squat) hammer-fist roar: right fist
# straight up overhead yelling with the head back, both forearms up in front of the face, then a deep forward lean
# hammering both fists down toward the knees, and the head whips back up. On the spot (the walk-off is the server's).
# (2026-11-16, legs fix 2: the old hammer spot B((-0.85, -0.95, -1.65)) is out of the arm's reach bent over (0.22 short)
#  and inside the thighs and belly of Fat, Muscular and BigBuff; the clothed solve pushed it out up to 0.99, a different
#  way on each build (out to the side on Fat, up with the elbow bent on BigBuff), a 1351 deg/s jerk. Now keyed (chest
#  frame) where every build is clear: fists down beside the knees, arms nearly straight.)
_HAMMER_CLEAR = (-1.25, -0.9, -1.7)
_PUMP_OUT = B((1.5, 0.55, -0.9))            # (right) a fist pump at the shoulder, clear of the chest
clip("HammerFistRoar", 3.4, [
    K(0.45, rh=("chest", mx(SKY_OUT)), up=28, cbend=-6),
    K(0.7, rh=("chest", mx(SKY_OUT)), up=30, cbend=-7),
    K(1.0, with_=both(H((-0.5, 1.0, -1.1))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), up=10, cbend=0),
    K(1.2, with_=both(H((-0.5, 0.95, -1.1))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), lean=14, up=0),
    K(1.5, with_=both(_HAMMER_CLEAR), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.35, 0.15), lean=45, cbend=15, up=-25),
    K(1.75, with_=both(_HAMMER_CLEAR), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.35, 0.15), lean=45, cbend=15, up=-22),
    K(2.05, rh=("chest", _PUMP_OUT), re=ELBOW_PUMP, lh=REST, le=ELBOW_DOWN, pos=(0, 0, 0), lean=0, cbend=0, up=22),
    K(2.5, rh=("chest", B((1.35, -0.2, -0.9))), re=ELBOW_PUMP, lh=("chest", B((-1.35, 0.1, -0.85))), le=ELBOW_DOWN,
      up=8),
    K(2.95, with_=rest(), up=0),
    K(3.4),
], layers=[tremble(0.45, 0.7, amp=0.04, chest=1.2), tremble(1.5, 1.75, amp=0.05, chest=2.0)],
    source="MC-008", rarity="Epic", events=[(0.45, "Roar"), (1.5, "Roar")])

# EPIC (MC-018; 3i4jvmDrtdY 3:11-3:12.8, a Sheffield bench) hopping sky punch: a small sideways hop with the right leg
# kicked up behind, the body arched back and the left fist thrown up and back at the sky in the air; lands, walks on.
# Light and middle builds (a small hop: it still reads on a heavy one).
_PUNCH_UP = O((-1.5, 2.25, 0.0))       # straight up: the arched body makes it "up and back" (0.45 back threw the elbow behind)
_PUNCH_UP_OUT = O((-1.75, 2.17, -0.1))   # (2026-11-16: _PUNCH_UP went 0.16 into BigBuff's head; out a little, as SKY_OUT)
_WIND = B((-1.25, -0.6, -0.35))      # (wound down and a little back; 0.05 threw the elbow behind the body)
_WIND_FWD = B((-1.3, -0.55, -0.65))  # (2026-11-16: out of the clothes _WIND's elbow went 0.77-0.83 behind: further forward)
clip("HopSkyPunch", 2.4, [
    K(0.3, turn=12),
    K(0.6, lh=("chest", _WIND_FWD), pos=P(0, -0.25, 0), lean=8, turn=12),
    K(0.95, lh=("chest", _PUNCH_UP_OUT), rh=("chest", B((1.25, -0.35, -1.2))), re=mx(ELBOW_DOWN), pos=P(0, 0.45, 0), lean=-16, cbend=-12,
      up=28, turn=12, lf=foot("Left", y=AY + L(0.3), pitch=-20),
      rf=foot("Right", y=AY + L(0.9), z=AZ + L(0.6), pitch=30)),
    K(1.2, lh=("chest", _PUNCH_UP_OUT), rh=("chest", B((1.25, -0.35, -1.2))), re=mx(ELBOW_DOWN), pos=P(0, 0.38, 0), lean=-16, cbend=-12,
      up=28, turn=12, lf=foot("Left", y=AY + L(0.25), pitch=-20),
      rf=foot("Right", y=AY + L(0.85), z=AZ + L(0.55), pitch=30)),
    K(1.55, with_=stand_feet(), lh=("chest", O((-1.7, 0.8, -0.35))), rh=REST, pos=P(0, -0.2, 0), lean=4, cbend=0, up=8,
      ease="slow"),
    K(2.05, with_=rest(), pos=(0, 0, 0), lean=0, up=0, turn=0),
    K(2.4),
], source="MC-018", rarity="Epic", events=[(0.95, "Roar"), (1.55, "Land")])

# UNCOMMON (MC-064; eu_9nPA3zRs 186:34 and 195:44, a 93 kg junior's signature on every good pull) double fists up beside
# the head: fists at the hips, a clap at the chin, both fists up beside the head with the elbows out, one fist pump.
_FISTS_BY_HEAD = (_SHOULDER_NOW[0] - 0.85, _SHOULDER_NOW[1] + 0.95, -0.2)
_ELBOW_BY_HEAD = (-1.0, 0.0, -0.2)      # (2026-11-14: out to the side, a touch forward; ELBOW_OUT put them behind)
clip("FistsBesideHead", 2.3, [
    K(0.3, with_=both(_FISTS_HIPS), le=ELBOW_OUT, re=mx(ELBOW_OUT), cbend=-6),
    K(0.55, with_=both(B((-0.45, 0.6, -1.15))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), cbend=-2),
    K(0.85, with_=both(_FISTS_BY_HEAD), le=_ELBOW_BY_HEAD, re=mx(_ELBOW_BY_HEAD), cbend=-8, up=14),
    K(1.15, with_=both(_FISTS_BY_HEAD), le=_ELBOW_BY_HEAD, re=mx(_ELBOW_BY_HEAD), cbend=-8, up=14),
    K(1.45, rh=("chest", _PUMP_OUT), re=ELBOW_PUMP, lh=REST, le=ELBOW_DOWN, cbend=0, up=4),
    K(1.9, with_=rest(), up=0),
    K(2.3),
], layers=[tremble(0.85, 1.15, amp=0.035, chest=1.0)], source="MC-064", rarity="Uncommon",
    events=[(0.55, "ChalkClap"), (0.85, "Roar"), (1.45, "FistPump")])

# RARE (MC-034; c6JJZD1W-QA 6:19-6:24, a 66 kg man's 3rd bench after a timed-out 2nd) finger to the ceiling, chalk-cloud
# clap, crouching "YES": right index finger straight up at the ceiling half turned to the crowd, one hard clap in front
# of the face (a chalk cloud), hands spread, then bent almost flat with the fists swinging down past the knees, up roaring.
clip("SkyPointChalkYes", 4.0, [
    K(0.5, rh=("chest", mx(SKY_OUT)), turn=-20, cbend=-6, up=18),
    K(1.3, rh=("chest", mx(SKY_OUT)), turn=-20, cbend=-6, up=20),
    K(1.65, with_=both(B((-0.42, 0.9, -1.15))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), turn=0, cbend=0, up=8),
    K(2.0, with_=both(O((-1.9, 0.6, -0.5))), le=ELBOW_OUT, re=mx(ELBOW_OUT), up=12),
    # (2026-11-16, legs fix 2: the fists in front of the belly, past the knees and at the chest were inside Fat's and
    #  BigBuff's clothes; the clothed solve pushed them out up to 0.82, a different way on each build (out to the side on
    #  Fat, up on BigBuff): 0.06 into Fat's singlet and a 1204 deg/s jerk. Now keyed (chest frame) clear of every build:
    #  further out in front of the belly, down beside the knees, the guard a little further from the chest.)
    K(2.35, with_=both((-0.85, -0.65, -1.78)), le=ELBOW_OUT, re=mx(ELBOW_OUT), lean=20, up=0),
    K(2.65, with_=both((-1.5, -1.25, -1.2)), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.2, 0.25), lean=50, cbend=10,
      up=-20),
    K(3.0, with_=both((-0.65, 0.76, -1.33)), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), pos=(0, 0, 0), lean=0, cbend=-6, up=16),
    K(3.5, with_=rest(), cbend=0, up=0),
    K(4.0),
], layers=[tremble(3.0, 3.35, amp=0.04, chest=1.4)], source="MC-034", rarity="Rare",
    events=[(1.65, "ChalkBurst"), (3.0, "Roar")])


# EPIC (MC-022; 3i4jvmDrtdY 1:14.5-1:24, a 305 kg record squat at Sheffield 2024) hunched victory dance: bent forward at
# the hips, knees bouncing on a ~0.5 s beat, elbows bent and swinging, head up grinning at the camera, knee-lift stomps,
# fists pumping by the hips, a hunched running-man kick, then upright. Loopable (also an emote-wheel dance).
def _dance(t, y, la, ra, lf=None, rf=None, **kw):
    keys = dict(with_=both(la, ra), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, y, 0.12), lean=38, cbend=14, up=26, **kw)
    keys["lf"] = lf or foot("Left")
    keys["rf"] = rf or foot("Right")
    return K(t, **keys)


_SW_F, _SW_B = B((-1.3, -0.3, -1.3)), B((-1.3, -0.6, -0.4))      # arm swung forward / back (left; mx for the right)
_DPUMP = B((-1.2, -0.55, -1.2))
clip("HunchedDance", 4.2, [
    _dance(0.35, -0.38, _SW_F, mx(_SW_B)),
    _dance(0.6, -0.22, _SW_B, mx(_SW_F)),
    _dance(0.85, -0.42, _SW_F, mx(_SW_B), rf=foot("Right", y=AY + L(0.35), pitch=-10)),
    _dance(1.1, -0.24, _SW_B, mx(_SW_F)),
    _dance(1.35, -0.45, _DPUMP, mx(_DPUMP), lf=foot("Left", y=AY + L(0.35), pitch=-10)),
    _dance(1.6, -0.28, B((-1.05, -0.45, -1.1)), mx(B((-1.05, -0.45, -1.1)))),
    _dance(1.85, -0.45, _DPUMP, mx(_DPUMP)),
    _dance(2.1, -0.28, B((-1.05, -0.45, -1.1)), mx(B((-1.05, -0.45, -1.1)))),
    _dance(2.35, -0.4, B((-0.75, 0.05, -1.15)), mx(_SW_B), rf=foot("Right", y=AY + L(0.5), z=AZ + L(0.45), pitch=25)),
    _dance(2.6, -0.24, _SW_B, mx(B((-0.75, 0.05, -1.15)))),
    _dance(2.85, -0.4, B((-0.75, 0.05, -1.15)), mx(_SW_B), lf=foot("Left", y=AY + L(0.5), z=AZ + L(0.45), pitch=25)),
    _dance(3.1, -0.26, _SW_B, mx(_SW_F)),
    K(3.6, with_=[rest(), stand_feet()], pos=(0, 0, 0), lean=0, cbend=0, up=0, turn=14),
    K(4.2, turn=0),
], source="MC-022", rarity="Epic", events=[(0.85, "Land"), (1.35, "Land"), (2.35, "Land"), (2.85, "Land")])

# LEGENDARY (MC-004; ay2OvIWZUcU 6:31.5-6:50, a 74 kg man's meet-winning 343 kg deadlift) arms wide, chalk-clap crouch,
# "right here" roar: right arm flung up shouting, hands up before the face, arms thrown wide palms up at the crowd, one
# chalk-cloud clap, a half crouch roaring with the fists by the thighs, an arms-back strut, then a step in and a roar
# into the camera with the right fist pointing at the floor. (The real one then walks back to shake every spotter's hand.)
clip("ChalkClapRightHere", 5.8, [
    K(0.35, rh=("chest", O((1.9, 1.6, -0.35))), up=22, cbend=-6),
    K(0.8, with_=both(H((-0.55, 0.95, -1.1))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), cbend=-8, up=12),
    K(1.3, with_=both(O((-2.3, 0.1, -0.6))), le=ELBOW_OUT, re=mx(ELBOW_OUT), cbend=-9, up=16),
    K(1.75, with_=both(B((-0.65, -0.3, -1.3))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), cbend=-2, up=8),
    K(2.15, with_=both(B((-0.42, 0.2, -1.2))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), up=6),
    K(2.5, with_=both(B((-1.3, -0.9, -0.95))), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.45, 0.08), lean=24,
      cbend=8, up=-6),
    K(2.9, with_=both(B((-1.3, -0.9, -0.95))), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.45, 0.08), lean=24,
      cbend=8, up=-4),
    K(3.3, with_=both(B((-1.6, -0.6, 0.1))), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=(0, 0, 0), lean=0, cbend=-11, up=16),
    K(3.75, rh=("chest", B((1.0, -1.05, -1.15))), re=ELBOW_PUMP, lh=("chest", B((-1.5, -0.7, -0.6))), le=ELBOW_OUT,
      rf=foot("Right", z=AZ - L(0.55)), pos=(0, 0, -0.25), lean=12, cbend=4, up=10),
    K(4.45, rh=("chest", B((1.0, -1.05, -1.15))), re=ELBOW_PUMP, lh=("chest", B((-1.5, -0.7, -0.6))), le=ELBOW_OUT,
      rf=foot("Right", z=AZ - L(0.55)), pos=(0, 0, -0.25), lean=12, cbend=4, up=12),
    K(4.75, rf=foot("Right", y=AY + L(0.25), z=AZ - L(0.3)), pos=(0, 0, -0.12), lean=6, up=6),   # (the foot lifts back)
    K(5.05, with_=[rest(), stand_feet()], pos=(0, 0, 0), lean=0, cbend=0, up=0),
    K(5.8),
], layers=[tremble(2.5, 2.9, amp=0.045, chest=1.8), tremble(3.75, 4.45, amp=0.05, chest=1.8)],
    source="MC-004", rarity="Legendary", events=[(0.35, "Scream"), (2.15, "ChalkBurst"), (2.5, "Roar"), (3.75, "Roar")])

# EPIC (MC-011; Mw95YfGN7Vg 2:51.5-3:06, an 83 kg showman's second squat world record of the day) stage-edge V strut and
# half-squat roar at the crowd: arms spread in a high V with the hips swaying side to side, a sudden half squat roaring
# with the fists by the hips, a flex, a hunched roar with the fists by the face, low once more, hands on the hips, then
# a point at the crowd and a fist at the chest. On the spot (no stage edge in every venue).
_HIGH_V = O((-2.1, 1.4, -0.3))
_HIPS_CLEAR = B((-1.5, -0.85, -0.35))   # hands on the hips, out where every build's hips are (HIPS went into Fat, 2026-11-14)
_FISTS_THIGHS = B((-1.05, -0.95, -0.7))
clip("VStrutRoar", 6.0, [
    K(0.35, with_=both(_HIGH_V), cbend=-8, up=14, side=0),
    K(0.65, with_=both(_HIGH_V), cbend=-8, up=14, side=7, pos=P(0, -0.05, 0)),
    K(0.95, with_=both(_HIGH_V), cbend=-8, up=14, side=-7, pos=P(0, 0, 0)),
    K(1.25, with_=both(_HIGH_V), cbend=-8, up=14, side=7, pos=P(0, -0.05, 0)),
    K(1.55, with_=both(_HIGH_V), cbend=-8, up=14, side=0, pos=P(0, 0, 0)),
    K(1.85, with_=both(_FISTS_THIGHS), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.5, 0.05), lean=18, cbend=6, up=4),
    K(2.3, with_=both(_FISTS_THIGHS), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.5, 0.05), lean=18, cbend=6, up=6),
    K(2.65, with_=both(B((-1.3, 0.35, -0.75))), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=(0, 0, 0), lean=0, cbend=-9, up=10),
    K(3.0, with_=both(H((-0.6, 0.7, -1.25))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), lean=15, cbend=8, up=4),
    K(3.35, with_=both(H((-0.6, 0.7, -1.25))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), pos=P(0, -0.45, 0.05), lean=20, cbend=8,
      up=0),
    K(3.6, with_=both(B((-1.65, -0.3, -0.75))), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.2, 0.02), lean=8, cbend=0, up=4),   # (round the outside)
    K(3.85, with_=both(_HIPS_CLEAR), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=(0, 0, 0), lean=0, cbend=-6, up=6),
    K(4.45, rh=("chest", O((1.6, 0.75, -1.35))), lh=("chest", _HIPS_CLEAR), le=ELBOW_OUT, turn=-12, up=8),
    K(4.9, rh=("chest", O((1.6, 0.75, -1.35))), lh=("chest", _HIPS_CLEAR), le=ELBOW_OUT, turn=-12, up=8),
    K(5.25, rh=("chest", B((0.3, 0.45, -1.1))), re=mx(ELBOW_DOWN), lh=REST, turn=0, up=4),
    K(5.6, with_=rest(), cbend=0, up=0),
    K(6.0),
], layers=[tremble(1.85, 2.3, amp=0.045, chest=1.8), tremble(3.0, 3.35, amp=0.045, chest=1.6)],
    source="MC-011", rarity="Epic", events=[(1.85, "Roar"), (3.0, "Roar")])

# LEGENDARY (MC-013; jfMBhKh4ab4 6:21-6:29.5, a very heavy man's 380 kg European-record deadlift) throws himself
# backward: crouched low with the hands up in disbelief, sits back, rolls onto his back with BOTH LEGS KICKED UP at the
# ceiling, lies back with the hands on his face, sits up, onto his knees, rises screaming at the ceiling with the chest
# open, then claps walking to the coach. Big bodies lower themselves: they never leap down.
_ROLL_HIPS = (0, SEAT_Y + 0.65, SEAT_Z + 0.55)
_LEG_UP_Y = AY + L(2.8)
_KNEES_UP_L, _KNEES_UP_R = (-0.5, AY + L(4.5), SEAT_Z + 0.3), (0.5, AY + L(4.5), SEAT_Z + 0.3)   # (knees bend UP while lying:
#                                                   by default a knee bends toward the toes and flipped as they turned)
_LAP_CLEAR = (-1.05, -0.6, -1.75)   # (chest frame) sat up, the hands held up in front over the knees: in the lap
#                                     (B((-0.85, -0.95, -1.0))) they sank into every build's thighs and shorts (2026-11-16)
clip("BackRollLegsUp", 8.4, [
    K(0.5, with_=both(B((-0.5, 0.05, -1.15))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), pos=P(0, -0.95, 0.25), lean=24,
      up=4),
    K(1.15, with_=[_seat, both(B((-0.5, 0.05, -1.15)))], le=ELBOW_DOWN, re=mx(ELBOW_DOWN), up=10),
    K(1.75, lk=_KNEES_UP_L, rk=_KNEES_UP_R, pos=_ROLL_HIPS, lean=-78, with_=both(H((-0.45, 0.95, -0.95))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), up=-10,
      lf=(-0.45, _LEG_UP_Y - L(0.35), SEAT_Z + 0.1, 8, -10), rf=(0.45, _LEG_UP_Y - L(0.35), SEAT_Z + 0.1, 8, -10)),
    K(2.3, lk=_KNEES_UP_L, rk=_KNEES_UP_R, pos=_ROLL_HIPS, lean=-80, with_=both(H((-0.45, 0.95, -0.95))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), up=-10,
      lf=(-0.45, _LEG_UP_Y, SEAT_Z + 0.35, 8, -35), rf=(0.45, _LEG_UP_Y, SEAT_Z + 0.35, 8, -35)),
    K(2.9, lk=_KNEES_UP_L, rk=_KNEES_UP_R, pos=_ROLL_HIPS, lean=-80, with_=both(H((-0.45, 0.95, -0.95))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), up=-10,
      lf=(-0.45, _LEG_UP_Y, SEAT_Z + 0.35, 8, -35), rf=(0.45, _LEG_UP_Y, SEAT_Z + 0.35, 8, -35)),
    K(3.3, lk=_KNEES_UP_L, rk=_KNEES_UP_R, pos=_ROLL_HIPS, lean=-78, with_=both(H((-0.45, 0.95, -0.92))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), up=-8,
      lf=(-0.5, AY + L(1.4), SEAT_Z - 0.1, 9, -40), rf=(0.5, AY + L(1.4), SEAT_Z - 0.1, 9, -40)),
    K(3.8, lk=_KNEES_UP_L, rk=_KNEES_UP_R, pos=_ROLL_HIPS, lean=-76, with_=both(H((-0.45, 0.95, -0.9))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), up=-6,
      lf=(-0.55, AY, SEAT_Z - L(0.55), 10, 0), rf=(0.55, AY, SEAT_Z - L(0.55), 10, 0)),
    # (feet lifted a little as they are drawn in: sitting up they slid along the floor, 2026-11-14)
    K(4.05, lf=(-0.58, AY + L(0.2), (SEAT_Z - L(0.55) + _seat["lf"][2]) / 2, 18, 0),
      rf=(0.58, AY + L(0.2), (SEAT_Z - L(0.55) + _seat["lf"][2]) / 2, 18, 0)),
    K(4.3, with_=[_seat, free_knees(), both(_LAP_CLEAR)], le=ELBOW_DOWN, re=mx(ELBOW_DOWN), up=0),
    K(4.8, with_=bow_down(), lean=40, cbend=18, up=-14),    # on hands and knees (a kneeling torso this long only
    #                                                         reaches the floor folded like the bow)
    # (hands up off the floor and out to the sides first: straight to the arms-back roar they went through the thighs)
    K(5.15, with_=[kneel(-2), both(B((-1.6, -0.55, -0.75)))], le=ELBOW_OUT, re=mx(ELBOW_OUT), cbend=0, up=10),
    K(5.4, with_=[kneel(-8), both(B((-1.25, -0.6, 0.45)))], le=ELBOW_OUT, re=mx(ELBOW_OUT), cbend=-12, up=30),
    K(5.9, with_=[kneel(-8), both(B((-1.25, -0.6, 0.45)))], le=ELBOW_OUT, re=mx(ELBOW_OUT), cbend=-12, up=32),
    K(6.12, with_=[kneel(-2), both(B((-1.75, -0.35, -0.3)))], le=ELBOW_OUT, re=mx(ELBOW_OUT), cbend=-4, up=14),   # (arms round the outside)
    K(6.4, with_=both(B((-1.45, -0.6, -1.25))), le=ELBOW_OUT, re=mx(ELBOW_OUT), lean=14, cbend=0, up=12, rk=None,
      rf=foot("Right", z=AZ - L(0.55))),
    K(6.9, with_=[free_knees(), stand_feet(), both(B((-1.45, -0.6, -1.25)))], le=ELBOW_OUT, re=mx(ELBOW_OUT),
      pos=P(0, -0.22, 0.05), lean=8, up=8),
    K(7.2, with_=both(B((-0.42, 0.2, -1.2))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), pos=(0, 0, 0), lean=0, up=10),
    K(7.4, with_=both(B((-0.95, 0.2, -1.2))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), up=10),
    K(7.6, with_=both(B((-0.42, 0.2, -1.2))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), up=10),
    K(8.0, with_=rest(), up=0),
    K(8.4),
], layers=[tremble(5.4, 5.9, amp=0.05, chest=2.0)], source="MC-013", rarity="Legendary",
    events=[(1.15, "SitDown"), (1.75, "SitDown"), (4.8, "KneeThud"), (5.4, "Roar"), (7.2, "ChalkClap"),
            (7.6, "ChalkClap")])

# ---- batch 4 (the catalogue's next wave; solo, no props)
def one_knee(lean=0.0):
    """Down on the right knee (toes tucked behind), the left foot flat in front with its shin upright."""
    d = kneel(lean)
    fz = d["pos"][2] - R.THIGH * 0.95                  # the front foot under the front knee
    d["lk"] = (-0.5, AY + R.SHIN, fz - 0.4)            # (pole: the front knee bends forward and up)
    d["lf"] = (-0.55, AY, fz, R.STAND_TOES, 0.0)
    return d


# EPIC (MC-016; gfp-IdEaQNc 1:04-1:10, a 93 kg man's 363 kg national-record squat) one-knee fist pumps under the record
# wall: racks and bends forward roaring, drops onto the right knee, both fists pumping down with the head bowed, then
# (the old reading, on the wall flip) both arms thrown up in a wide V from the knee roaring, stands and stomps forward
# roaring with the fists low. One knee is the easiest floor pose: any build (big ones lower themselves).
_V_KNEE = O((-1.7, 1.95, -0.25))          # V from the knee, a touch inside full reach (V_UP over-straightened)
_KNEE_PUMP_UP, _KNEE_PUMP_DOWN = B((-0.6, 0.3, -1.1)), B((-0.9, -0.5, -1.35))
_KNEE_PUMP_UP_W = B((-0.72, 0.3, -1.1))   # (2026-11-16: a touch apart: Skinny's fists went 0.16 into each other)
clip("OneKneeFistPumps", 6.0, [
    # (2026-11-16, longer thighs: bent over, the hanging fists at z -1.15 went 0.60 into BigBuff's thighs above the
    #  knees, anim_qa: a little further ahead and out)
    K(0.45, with_=both(B((-0.85, -1.0, -1.38))), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.2, 0.05), lean=24, cbend=8, up=-4),
    K(1.2, with_=[one_knee(14), both(_KNEE_PUMP_UP_W)], le=ELBOW_DOWN, re=mx(ELBOW_DOWN), cbend=8, up=-14),
    K(1.5, with_=[one_knee(16), both(_KNEE_PUMP_DOWN)], le=ELBOW_OUT, re=mx(ELBOW_OUT), cbend=10, up=-22),
    K(1.8, with_=[one_knee(14), both(_KNEE_PUMP_UP_W)], le=ELBOW_DOWN, re=mx(ELBOW_DOWN), cbend=8, up=-18),
    K(2.1, with_=[one_knee(16), both(_KNEE_PUMP_DOWN)], le=ELBOW_OUT, re=mx(ELBOW_OUT), cbend=10, up=-22),
    K(2.4, with_=[one_knee(14), both(_KNEE_PUMP_UP_W)], le=ELBOW_DOWN, re=mx(ELBOW_DOWN), cbend=8, up=-18),
    K(2.75, with_=[one_knee(16), both(_KNEE_PUMP_DOWN)], le=ELBOW_OUT, re=mx(ELBOW_OUT), cbend=10, up=-24),
    K(3.35, with_=[one_knee(-4), both(_V_KNEE)], cbend=-8, up=30, ease="fast"),
    K(4.1, with_=[one_knee(-4), both(_V_KNEE)], cbend=-9, up=32),
    # (the front foot steps back lifted as he stands: it slid along the floor, 2026-11-14)
    K(4.45, lf=(-0.55, AY + L(0.3), (one_knee()["lf"][2] + AZ) / 2, R.STAND_TOES, 0.0)),
    K(4.8, with_=[free_knees(), stand_feet(), both(B((-1.1, -0.75, -0.6)))], le=ELBOW_OUT, re=mx(ELBOW_OUT),
      pos=P(0, -0.15, 0), lean=10, cbend=4, up=8),
    K(5.4, with_=rest(), pos=(0, 0, 0), lean=0, cbend=0, up=0),
    K(6.0),
], layers=[tremble(3.35, 4.1, amp=0.05, chest=2.0)], source="MC-016", rarity="Epic",
    events=[(0.45, "Roar"), (1.2, "KneeThud"), (3.35, "Roar")])

# EPIC (MC-021; 3i4jvmDrtdY 5:05-5:13, a heavy man's last deadlift at Sheffield 2024) crucifix to the sky, then tears:
# both arms up in a V with the head back, out to the sides at shoulder height with the face to the sky, then the arms
# drop, the shoulders slump, the right forearm comes over the face, bent forward crying (shoulders heaving ~0.7 s a
# breath). On the spot, feet planted (the coach who walks him off is not in the build): ends with the head still down.
_PALM_UP = (0, 120)                         # (left wrist) the palm turned forward and a little up (crucifix)


def mx_w(w):
    return (w[0], -w[1])


_FOREARM_FACE = H((-0.1, 1.2, -1.0))         # (right hand) across the eyes, forearm over the face
clip("CrucifixTears", 6.6, [
    K(0.35, with_=both(V_UP), cbend=-8, up=30, ease="fast"),
    K(0.75, with_=both(V_UP), lw=(0, 0), rw=(0, 0), cbend=-8, up=32),
    K(1.15, with_=both(T_OUT), lw=_PALM_UP, rw=mx_w(_PALM_UP), cbend=-10, up=36),
    K(1.9, with_=both(T_OUT), lw=_PALM_UP, rw=mx_w(_PALM_UP), cbend=-10, up=36),
    K(2.4, with_=rest(), lw=(0, 0), rw=(0, 0), lean=10, cbend=12, up=-18),
    K(2.85, rh=("chest", _FOREARM_FACE), re=(0.7, -0.35, -0.6), lh=REST, lean=20, cbend=16, up=-24),
    K(5.0, rh=("chest", _FOREARM_FACE), re=(0.7, -0.35, -0.6), lh=REST, lean=22, cbend=18, up=-26),
    K(5.55, with_=rest(), lean=8, cbend=6, up=-12),
    K(6.6, lean=0, cbend=0, up=0),
], layers=[bounce(2.85, 5.0, height=0.0, hz=1.4, chest=3.0)], source="MC-021", rarity="Epic",
    events=[(0.35, "Roar"), (2.85, "Sob")])

# RARE (MC-031; gfp-IdEaQNc 2:29.5-2:42, a very big man's 478.5 kg American-record squat) index finger to the sky, then
# arms crossed: steps out shouting with the right index finger thrust straight up, then stands still with both arms
# crossed over the chest, fists at the opposite shoulders (an X: the arms x1.5 forearms overshoot a folded-arms pose and
# the wrist cannot bend sideways to lay a hand flat), head slightly bowed, taking it in (~3.3 s). (HandShapeConfig: right
# Point 0.3-1.7, both Fist 2.5-6.3.)
_CROSS_L = (0.6, _SHOULDER_NOW[1] - 0.45, -1.1)    # (left fist) at the right shoulder, in front
_CROSS_R = (-0.6, _SHOULDER_NOW[1] - 0.3, -0.8)    # (right fist) at the left shoulder, behind
_ELBOW_CROSS = (-0.2, -1.0, -0.35)          # (left) elbow low and in front: the forearms cross steeply (an X)
_CROSS_L_FWD = (0.6, _SHOULDER_NOW[1] - 0.45, -1.33)   # (2026-11-16: the front forearm a little further out: on BigBuff the
#                                                        crossed forearms went 0.27 into each other)
_CROSS_L_OUT = (0.55, 0.25, -1.9)     # (legs fix 2, see the keys: the front fist as far out as the arm reaches)
_CROSS_R_OUT = (-0.6, 0.62, -1.55)    # (the back fist clear of Fat's clothes, a little higher)
clip("SkyFingerArmsCrossed", 7.3, [
    K(0.45, rh=("chest", mx(SKY_OUT)), cbend=-6, up=22),
    K(1.4, rh=("chest", mx(SKY_OUT)), cbend=-7, up=24),
    K(2.05, with_=rest(), cbend=0, up=4),
    K(2.35, with_=both(B((-0.75, -0.2, -1.5))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), lw=(0, 0), rw=(0, 0), up=0),
    # (2026-11-16, legs fix 2: with the clothes really on the big builds, the back fist (_CROSS_R, 0.8 in front of the
    #  chest) was pushed 0.56 out of Fat's tee and singlet, level with the front one, so the forearms went through each
    #  other (0.26 into the singlet on Fat, 0.26 forearm-in-forearm on BigBuff). Now (chest frame) the back fist sits
    #  where Fat's clothes are clear and the front one as far out as the arm reaches; the front arm crosses first, the back
    #  one comes in behind it, and coming out the front arm leaves first with the back elbow held, so the forearms never
    #  slide through each other. BigBuff's thick forearms still TOUCH in the hold (0.24-0.25, its limit 0.26).)
    K(2.55, lh=("chest", (0.1, 0.0, -1.85)), rh=("chest", (0.55, 0.1, -1.4))),
    K(2.75, lh=("chest", _CROSS_L_OUT), rh=("chest", _CROSS_R_OUT), le=_ELBOW_CROSS, re=mx(_ELBOW_CROSS), lw=(0, 0), rw=(0, 0), up=-12),
    K(6.0, lh=("chest", _CROSS_L_OUT), rh=("chest", _CROSS_R_OUT), le=_ELBOW_CROSS, re=mx(_ELBOW_CROSS), lw=(0, 0), rw=(0, 0), up=-14),
    K(6.2, lh=("chest", (-0.4, 0.0, -1.95)), rh=("chest", _CROSS_R_OUT), le=_ELBOW_CROSS, re=mx(_ELBOW_CROSS)),
    K(6.4, with_=both(B((-0.75, -0.2, -1.5))), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), lw=(0, 0), rw=(0, 0), up=-4),   # (out in front of the belly)
    K(6.85, with_=rest(), up=0),
    K(7.3),
], layers=[sway(2.6, 6.1, degrees=2.0, period=2.4)], source="MC-031", rarity="Rare", events=[(0.35, "Roar")])

# EPIC (MC-051; ay2OvIWZUcU 0:28-0:37, the 74 kg man of MC-003, an opener) gunslinger: both hands together in front of
# the mouth with the index fingers up like two pistols, blows the smoke off them, drops them to the hips (holstered),
# points the right arm at the crowd, sweeps it across, points again, then both fists up beside the head. Any body.
# (Hand shapes for the game, HandShapeConfig: left Point 0.6-1.95, right Point 0.6-3.55, both Fist 3.6-4.45.)
_DB_OPEN = (_SHOULDER_NOW[0] - 0.85, _SHOULDER_NOW[1] + 1.44, -0.1)   # a true double biceps on the long arms:
#   upper arm level out to the side (1.09), elbow ~90 deg, forearm straight up (user 2026-11-14: "arms more straight")
_ELBOW_DB_OPEN = (-1.0, -0.25, 0.05)
_DB_OPEN_FWD = (_DB_OPEN[0], _DB_OPEN[1], -0.22)   # (2026-11-16: the same double biceps a touch forward: BigBuff's raised
#                                                    elbow sat 0.402 behind, limit 0.40)
_PISTOLS = H((-0.45, 0.62, -1.3))      # pressed together in front of the mouth, fingers up
_PISTOLS_W = H((-0.5, 0.62, -1.3))     # (2026-11-16: Skinny's pointing hands went 0.16 into each other: touching, not inside)
_HOLSTER = B((-1.3, -1.0, -0.3))
_POINT_CROWD = O((1.6, 0.75, -1.35))
clip("Gunslinger", 5.0, [
    K(0.85, with_=both(_PISTOLS_W), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), up=2),
    K(1.25, with_=both(_PISTOLS_W), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), lean=4, up=-4),
    K(1.55, with_=both(_PISTOLS_W), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), lean=0, up=2),
    K(1.95, with_=both(_HOLSTER), le=ELBOW_OUT, re=mx(ELBOW_OUT), turn=10, up=4),
    K(2.35, rh=("chest", _POINT_CROWD), lh=("chest", _HOLSTER), le=ELBOW_OUT, turn=-14, up=8, ease="fast"),
    K(2.85, rh=("chest", _POINT_CROWD), lh=("chest", _HOLSTER), le=ELBOW_OUT, turn=12, up=8),
    K(3.25, rh=("chest", _POINT_CROWD), lh=("chest", _HOLSTER), le=ELBOW_OUT, turn=0, up=10, ease="fast"),
    K(3.55, rh=("chest", _POINT_CROWD), lh=("chest", _HOLSTER), le=ELBOW_OUT, turn=0, up=10),
    K(3.9, with_=both(_DB_OPEN_FWD), le=_ELBOW_DB_OPEN, re=mx(_ELBOW_DB_OPEN), cbend=-8, up=12),
    K(4.45, with_=rest(), cbend=0, up=0),
    K(5.0),
], source="MC-051", rarity="Epic", events=[(1.25, "Blow"), (3.9, "Roar")])

# ---- batch 5 (next wave, solo, any build)
_PALMS_UP = (0, 175)          # (left wrist) on an arm held out: palm turned up (0 = back, 90 = forward, 120 = forward+up)
_SKY_WIDE_R = mx(SKY_CLEAR)
_SKY_OUT_R = mx(SKY_OUT)

# EPIC (MC-025; eu_9nPA3zRs 75:52-76:01, a bulky 93 kg man's grinder squat, Houston) "are you not entertained": right
# fist straight up, head tilted, a slap on the chest (a chalk puff), then both arms spread wide and level, palms up,
# chin raised, perfectly still and defiant while he turns slowly. (HandShapeConfig: right Fist 0.3-1.5.)
# (user 2026-11-14: the first slap tucked the elbow behind and into the ribs; now as the approved entrance ChestSlap:
#  the hand flat on its OWN pec from the side, the elbow out at chest height)
_SLAP_PEC_R = B((0.66, 0.42, -1.0))
_ELBOW_SLAP_R = (1.0, -0.15, 0.0)
clip("AreYouNotEntertained", 6.0, [
    K(0.4, rh=("chest", _SKY_OUT_R), lh=REST, cbend=-6, up=14),
    K(0.95, rh=("chest", _SKY_OUT_R), lh=REST, cbend=-6, up=18),
    K(1.45, rh=("chest", B((1.45, 0.45, -1.0))), re=_ELBOW_SLAP_R, lh=REST, up=8),
    K(1.75, rh=("chest", _SLAP_PEC_R), re=_ELBOW_SLAP_R, lh=REST, cbend=4, up=4, ease="fast"),
    K(2.1, rh=("chest", B((1.3, 0.35, -1.05))), re=_ELBOW_SLAP_R, lh=REST, cbend=0, up=6),
    K(2.65, with_=both(T_OUT), lw=_PALMS_UP, rw=mx_w(_PALMS_UP), cbend=-6, up=14, turn=-10),
    K(4.65, with_=both(T_OUT), lw=_PALMS_UP, rw=mx_w(_PALMS_UP), cbend=-6, up=14, turn=10),
    K(5.25, with_=rest(), lw=(0, 0), rw=(0, 0), cbend=0, up=0, turn=0),
    K(6.0),
], source="MC-025", rarity="Epic", events=[(1.75, "ChestSlap"), (1.75, "ChalkBurst")])

# RARE (MC-030; UnUJPzEesc4 3:35-3:54, a super-heavy man's 398.5 kg deadlift world record) the long V: both arms shoot
# straight up into a V and HOLD, head tipped right back roaring at the ceiling while the press shoots (held ~3.5 s here),
# then the left arm comes down with the right fist still up. No hop: the biggest build's V. (HandShapeConfig: both
# Fist 0.4-5.2, right Fist to 5.7.)
clip("LongVHold", 6.4, [
    K(0.55, with_=both(V_UP), cbend=-8, up=28, ease="fast"),
    K(1.0, with_=both(V_UP), cbend=-9, up=38),
    K(4.5, with_=both(V_UP), cbend=-10, up=40),
    K(5.1, lh=REST, rh=("chest", mx(V_UP)), cbend=-4, up=12),
    K(5.7, with_=rest(), cbend=0, up=0),
    K(6.4),
], layers=[tremble(1.0, 4.5, amp=0.02, hz=6.0, chest=0.8)], source="MC-030", rarity="Rare",
    events=[(0.55, "Roar")])

# EPIC (MC-035; Mw95YfGN7Vg 6:17.5-6:27, the 83 kg showman of MC-011, 6 for 6) stage-edge double biceps (the standing
# part; the bench leg-kick needs the bench): fists clenched, chest out, then a full front double biceps pumped twice, a
# "most muscular" squeeze in front of the belly, one arm swung out wide leaning ("come on"), and the "crab": bent ~40
# deg at the hips, both arms hanging flexed. (HandShapeConfig: both Fist 0.3-4.9.)
_DB_PUMP = (_DB_OPEN[0], _DB_OPEN[1] - 0.15, _DB_OPEN[2])
_SQUEEZE = B((-0.55, -0.25, -1.55))
_CRAB = B((-0.85, -1.0, -1.15))
clip("StageEdgeDoubleBiceps", 5.6, [
    K(0.4, with_=both(B((-1.1, -0.5, -0.8))), le=ELBOW_OUT, re=mx(ELBOW_OUT), cbend=-8, up=8),
    K(1.0, with_=both(_DB_OPEN), le=_ELBOW_DB_OPEN, re=mx(_ELBOW_DB_OPEN), cbend=-10, up=10),
    K(1.3, with_=both(_DB_PUMP), le=_ELBOW_DB_OPEN, re=mx(_ELBOW_DB_OPEN), cbend=-11, up=10),
    K(1.55, with_=both(_DB_OPEN), le=_ELBOW_DB_OPEN, re=mx(_ELBOW_DB_OPEN), cbend=-10, up=10),
    K(1.8, with_=both(_DB_PUMP), le=_ELBOW_DB_OPEN, re=mx(_ELBOW_DB_OPEN), cbend=-11, up=10),
    K(2.05, with_=both(_DB_OPEN), le=_ELBOW_DB_OPEN, re=mx(_ELBOW_DB_OPEN), cbend=-10, up=10),
    K(2.45, with_=both(_SQUEEZE), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.15, 0.05), lean=14, cbend=12, up=-2),
    K(2.95, with_=both(_SQUEEZE), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.15, 0.05), lean=14, cbend=12, up=0),
    K(3.45, rh=("chest", O((2.2, 0.35, -0.7))), lh=("chest", B((-1.1, -0.5, -0.8))), le=ELBOW_OUT, pos=(0, 0, 0),
      lean=0, cbend=-4, side=-8, up=10),
    K(3.95, with_=both(_CRAB), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.2, 0.15), lean=38, cbend=14, side=0, up=12),
    K(4.45, with_=both(_CRAB), le=ELBOW_OUT, re=mx(ELBOW_OUT), pos=P(0, -0.2, 0.15), lean=38, cbend=14, up=14),
    K(4.95, with_=rest(), pos=(0, 0, 0), lean=0, cbend=0, up=0),
    K(5.6),
], layers=[tremble(2.45, 2.95, amp=0.045, chest=1.8), tremble(3.95, 4.45, amp=0.04, chest=1.4)],
    source="MC-035", rarity="Epic", events=[(1.0, "Roar"), (2.45, "Roar")])

# RARE (MC-024; eu_9nPA3zRs 70:50-70:57.5, a 93 kg man's grinder squat PR, Houston) fists to the chest, then the ceiling
# roar: both fists pulled up to the chest with the elbows out, leaning back roaring, the right fist thrust straight up,
# then the head thrown right back screaming at the ceiling, chest out, arms bent low at the sides (exaggerated arch).
# (HandShapeConfig: both Fist 0.35-4.3.)
clip("FistsChestCeilingRoar", 5.4, [
    K(0.5, with_=both(FIST_CHEST), le=ELBOW_OUT, re=mx(ELBOW_OUT), lean=-8, cbend=-12, up=18, ease="fast"),
    K(0.95, with_=both(FIST_CHEST), le=ELBOW_OUT, re=mx(ELBOW_OUT), lean=-8, cbend=-12, up=20, turn=10),
    K(1.4, rh=("chest", _SKY_OUT_R), lh=REST, lean=0, cbend=-6, up=14, turn=-10),
    K(1.9, rh=("chest", _SKY_OUT_R), lh=REST, cbend=-6, up=16, turn=-10),
    K(2.45, with_=both(B((-1.5, -0.65, -0.6))), le=ELBOW_OUT, re=mx(ELBOW_OUT), lean=-8, cbend=-14, up=44, turn=0),
    K(3.9, with_=both(B((-1.5, -0.65, -0.6))), le=ELBOW_OUT, re=mx(ELBOW_OUT), lean=-8, cbend=-14, up=46),
    K(4.4, with_=rest(), lean=0, cbend=2, up=-10),
    K(5.0, cbend=0, up=0),
    K(5.4),
], layers=[tremble(0.5, 0.95, amp=0.04, chest=1.6), tremble(2.45, 3.9, amp=0.045, chest=2.0)],
    source="MC-024", rarity="Rare", events=[(0.5, "Roar"), (2.45, "Roar")])

# UNCOMMON (MC-049; FwruiLgnapQ 6:39-6:42.5, the 105 kg man of MC-002, a 3rd bench after a timed-out 2nd) waits for the
# lights: stands looking up at the board, then on the lights throws both arms out wide and up ~45 deg, palms up ("come
# on!"), both hands onto the top of the head (relief), hands off and the arms open again. Any build.
_WIDE_UP = (_SHOULDER_NOW[0] - 1.6, _SHOULDER_NOW[1] + 1.5, -0.45)   # out and up ~45 deg, near full reach
_WIDE = O((-2.1, 0.55, -0.5))
clip("LightsArmsWideHeadHands", 4.8, [
    K(0.6, up=20, turn=10),
    K(1.25, up=21, turn=10),
    K(1.6, with_=both(_WIDE_UP), lw=_PALMS_UP, rw=mx_w(_PALMS_UP), cbend=-8, up=14, turn=0, ease="fast"),
    K(2.2, with_=both(_WIDE_UP), lw=_PALMS_UP, rw=mx_w(_PALMS_UP), cbend=-8, up=16),
    K(2.75, **_HOLD_HEAD, cbend=-2, up=6),
    K(3.3, **_HOLD_HEAD, cbend=-2, up=8),
    K(3.75, with_=both(_WIDE), lw=(0, 150), rw=(0, -150), le=ELBOW_DOWN, re=mx(ELBOW_DOWN), cbend=-4, up=8),
    K(4.25, with_=rest(), lw=(0, 0), rw=(0, 0), cbend=0, up=0),
    K(4.8),
], source="MC-049", rarity="Uncommon", events=[(1.6, "Roar")])

# ---- miss reactions over the walk back (user 2026-11-15: "the lifter does NOT do the fail animation while looking at the
# crowd, the lifter would be facing the direction they are going back to, then yelling or screaming ... it should be
# fail, turn while walking hand gestures, scream"). Arms and head only (the walk is the game's), so the lifter turns and
# walks off while he does them. Elbows out to the sides, never back; open hands except the swipe's and the yell's fists
# (HandShapeConfig). Replace the standing LeapAndBow / ReliefRoar reactions.
# hands up onto the head walking away (the "can't believe I missed it" walk), a look up, then the head drops and shakes
clip("MissHandsOnHead", 3.5, [
    K(0.35, **_HOLD_HEAD, up=8),
    K(1.0, **_HOLD_HEAD, up=14),
    K(1.5, **_HOLD_HEAD, up=-10),
    *[K(t, **_HOLD_HEAD, turn=tr, up=-10) for t, tr in ((1.75, 12), (1.95, -12), (2.15, 10), (2.35, -8))],
    K(2.55, with_=both(H((-0.95, 2.5, -0.35))), le=_ELBOW_HEAD_SIDE, re=mx(_ELBOW_HEAD_SIDE), lw=(40, -60), rw=(40, 60),
      turn=0, up=-6),   # (hands lift UP off the head first: curled fingers dig in otherwise)
    # (2026-11-15, Studio: from the head out to the sides in 0.3 s turned the shoulders at 1600 deg/s in the game; 0.45 s)
    K(3.0, with_=both(B((-1.45, 0.9, -0.9))), le=_ELBOW_HEAD_SIDE, re=mx(_ELBOW_HEAD_SIDE), lw=(20, -30), rw=(20, 30),
      up=-4),
    K(3.32, with_=rest(), lw=(0, 0), rw=(0, 0), up=0),
    K(3.5),
], kind="walk", source="User 2026-11-15 (miss: walk off)", rarity="Default", only=ARMS_AND_HEAD,
    events=[(0.35, "Roar")])

# a frustrated swipe: the right fist thrown up and slashed down across the body, then hands on the hips shaking the head
_SWIPE_UP = B((1.45, 1.1, -0.55))
_SWIPE_DOWN = B((0.6, -0.7, -1.6))      # (across in front, clear of the Fat belly)
clip("MissArmSwipe", 3.0, [
    K(0.25, rh=("chest", _SWIPE_UP), re=mx(_ELBOW_BY_HEAD), lh=REST, up=10),
    K(0.55, rh=("chest", _SWIPE_DOWN), re=mx(ELBOW_DOWN), lh=REST, up=-8),
    K(0.95, with_=both(_HIPS_CLEAR), le=ELBOW_OUT, re=mx(ELBOW_OUT), up=-6),
    *[K(t, with_=both(_HIPS_CLEAR), le=ELBOW_OUT, re=mx(ELBOW_OUT), turn=tr, up=-8)
      for t, tr in ((1.25, 14), (1.45, -14), (1.65, 12), (1.85, -10))],
    K(2.2, with_=both(_HIPS_CLEAR), le=ELBOW_OUT, re=mx(ELBOW_OUT), turn=0, up=-4),
    K(2.7, with_=rest(), up=0),
    K(3.0),
], kind="walk", source="User 2026-11-15 (miss: walk off)", rarity="Default", only=ARMS_AND_HEAD,
    events=[(0.25, "Roar")])

# yelling at the ceiling walking away, fists flared low and tense, two fists driven down, then the head drops
_FLARE_LOW = O((-1.9, -0.45, -0.5))
_DRIVE_DOWN = B((-1.3, -0.85, -0.75))
clip("MissYell", 2.8, [
    K(0.3, with_=both(_FLARE_LOW), le=ELBOW_OUT, re=mx(ELBOW_OUT), up=30),
    K(1.05, with_=both(_FLARE_LOW), le=ELBOW_OUT, re=mx(ELBOW_OUT), up=32),
    K(1.3, with_=both(_DRIVE_DOWN), le=ELBOW_OUT, re=mx(ELBOW_OUT), up=4),
    K(1.55, with_=both(B((-1.35, -0.55, -0.7))), le=ELBOW_OUT, re=mx(ELBOW_OUT), up=0),
    K(1.8, with_=both(_DRIVE_DOWN), le=ELBOW_OUT, re=mx(ELBOW_OUT), up=-10),
    K(2.4, with_=rest(), up=-6),
    K(2.8, up=0),
], layers=[tremble(0.3, 1.05, amp=0.04, chest=0.0)], kind="walk", source="User 2026-11-15 (miss: walk off)",
    rarity="Default", only=ARMS_AND_HEAD, events=[(0.3, "Roar")])


# ---------------------------------------------------------------- run
# (2026-11-16, longer-thigh rebuild of the bodies) BigBuff's forearm folded 0.26-0.27 into its own biceps whenever an
# elbow bent ~128-148 degrees on the rebuilt arms, so AreYouNotEntertained, ChalkClapPump, ExitFistPump, FistsBesideHead,
# HammerFistRoar, LeapAndBow, RecordJumpRoar and VStrutRoar had their elbows capped at 126 (Clip.elbow_max). Removed the
# same day: the bodies' inner-elbow weights now blend over the inside of the elbow (build_cartoon_rig_05.spread_elbows)
# and every one of them passes anim_qa uncapped, the fists back on their own spots.

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
