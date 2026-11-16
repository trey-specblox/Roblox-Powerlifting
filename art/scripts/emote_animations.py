# The emotes (user 2026-11-11: an emote wheel on B, "8 gym emotes", collected; two free, the rest won at the
# celebration NPC's spin). Powerlifting flavour from the user's meet clips (References/Clip Study) and gym life. Each
# starts and ends standing at rest, on the spot, and plays once (Action priority); moving cancels it in the game.
#
#   Wave           (free) a big wave, hand up beside the head
#   ChalkClap      (free) two chalky claps at the chest and a rub of the hands
#   BeltTighten    hands to the belt, two hard tugs with a dip, a slap on the belt
#   DoubleBiceps   a double biceps flex, held and shaking
#   TrapSlap       slaps both traps twice, then a hard clap, chest out
#   PointLaugh     points at someone, then laughs, both hands holding the belly
#   SitBreath      sits down on the floor, forearms on the knees, catching a breath, and back up
#   MostMuscular   the crab: leans in, fists together in front of the hips, everything tensed and shaking
#
# Built on celebration_rig.py with the celebrations' pose vocabulary (celebration_animations.py).
#   blender -b --factory-startup --python art/scripts/emote_animations.py -- [preview folder] [names...]
# checks each, writes art/animations/Emote_<Name>.rbxmx, and with a folder renders front preview sheets. Publish with
# art/scripts/upload_animations.py; ids go in src/shared/Config/EmoteConfig.luau.
import importlib.util
from mathutils import Vector
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\Powerlifting Roblox\art\scripts"
_spec = importlib.util.spec_from_file_location("celebration_animations", os.path.join(_HERE, "celebration_animations.py"))
C = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(C)
R = C.R
K, both, rest, mx, foot, stand_feet = C.K, C.both, C.rest, C.mx, C.foot, C.stand_feet
CLAP, CLAP_APART, BICEP, ELBOW_BICEP, FIST_LOW = C.CLAP, C.CLAP_APART, C.BICEP, C.ELBOW_BICEP, C.FIST_LOW
AY = C.AY
# The taller rig (user 2026-11-12): the numbers are written on the block rig and moved onto this one with the
# celebrations' helpers (B on the body, O held out, F reaching forward, P a crouch, L a step; celebration_animations).
B, O, F, P, L, TOR, LEG = C.B, C.O, C.F, C.P, C.L, C.TOR, C.LEG

EMOTES = {}


# (2026-11-16, clothes count as the body, user rules 16-17) Every emote is solved clear of the worn meet outfit (tee,
# singlet, belt) on every build (celebration_rig's clothed solve: a hand or forearm that would sink into the clothes on
# any build is moved out along them and the arm re-solved). The contact targets below are fitted to the widest clothed
# build first, so the solve only trims what is left; one animation plays on all builds, so a hand may float a little
# off Skinny's clothes, never sink into Fat's (user 2026-11-16). Needs celebration_rig's clothed envelope
# (art/data/clothed_envelope_05.json, or CELEB_ENVELOPE).
def emote(name, length, keys, layers=(), clothed=True, fists=False):
    c = R.Clip("Emote" + name, length, keys, layers, clothed=clothed)
    # The game's hand swaps (HandShapeConfig EMOTES), so the clothes are kept clear of the shape actually shown then
    # (celebration_rig Clip.hand_spans: the open hand always, plus these). `fists`: fists all through.
    spans = HAND_SPANS.get(name)
    if fists:
        spans = {s: [(0.0, length, "Fist")] for s in ("Left", "Right")}
    if spans:
        c.hand_spans = spans
    EMOTES[name] = c


# HandShapeConfig EMOTES (keep in step): BeltTighten fists 0.3-1.35, DoubleBiceps fists all through, PointLaugh the
# right hand pointing 0.15-1.25 (MostMuscular: emote(..., fists=True)).
HAND_SPANS = {
    "BeltTighten": {"Left": [(0.3, 1.35, "Fist")], "Right": [(0.3, 1.35, "Fist")]},
    "DoubleBiceps": {"Left": [(0.0, 3.0, "Fist")], "Right": [(0.0, 3.0, "Fist")]},
    "PointLaugh": {"Right": [(0.15, 1.25, "Point")]},
}


WAVE_HIGH = B((1.45, 1.75, -0.35))       # (right) hand up beside the head, open
BELT = C.BELT_B((-0.75, -0.95, -1.38), -0.95)          # hands on the front of the belt (torso rig: the navel belt)
BELT_TUG = (-0.82, -1.0, -1.4)          # (chest frame; 2026-11-16 legs fix 2: was C.BELT_B((-0.79, -1.1, -1.33), -0.95) =
#                                         (-0.79, -1.03, -1.33), where the open hand still read 0.03 into Fat's belt in the
#                                         tug; now a touch further out on its front. The game shows fists there: clear too)
# (2026-11-16, clothes count as the body: the fists were on the skin's belly line, 0.26-0.44 into Fat's belt, which
#  sits ~0.25 out from the skin; now on the outside of the widest belt, Fat's, z -1.05/-0.99 -> -1.38/-1.33, the
#  elbows more forward (ELBOW_BELT) so the forearms come round in front of the belly instead of along its sides.)
# (2026-11-15 QA: at z -0.78 the fists sank into the belly, 0.46 on Fat; now on the belt's front surface, forward of
#  the biggest belly, as one animation plays on every build; 0.13 further apart so the fists don't press into each
#  other on the slim build.)
TRAP = B((-0.62, 0.86, -0.12))           # a hand on top of its own shoulder
TRAP_OFF = O((-1.0, 1.2, -0.45))
BELLY = B((-0.75, -0.4, -1.45))          # (left; mirrored) both hands holding the belly in the laugh (2026-11-15: was
#                                          the right hand across at (-0.42, -0.45, -0.98) and the left at the side, both
#                                          inside Fat's belly; now on each side of the belly's front, forward of Fat's;
#                                          2026-11-16: -1.22 -> -1.45, on the singlet over Fat's belly, not in it)
POINT = F((0.8, 0.62, -1.55))           # (right) pointing straight ahead, as far as the arm reaches
POINT_PREP = F((1.1, 0.5, -1.2))
CRAB = B((-0.72, -0.8, -1.48))             # fists nearly touching in front of the hips (2026-11-15: forward of Fat's
#                                          belly; at -0.95 the forearms went 0.38 into it; 2026-11-16: -1.3 -> -1.48,
#                                          the fists in front of Fat's belt, not through it)

# (2026-11-15 QA: the waving elbow was left to the default "out and back" and sat 0.7 behind the shoulder; it is now
#  named: out to the side, a little down and a touch forward, the forearm up beside the head.)
ELBOW_WAVE = (1.0, -0.3, -0.3)
emote("Wave", 2.4, [
    K(0.35, rh=("chest", WAVE_HIGH), re=ELBOW_WAVE, up=6, ease="fast"),
    K(0.6, rh=("chest", B((1.75, 1.7, -0.3))), re=ELBOW_WAVE),
    K(0.85, rh=("chest", B((1.2, 1.78, -0.4))), re=ELBOW_WAVE),
    K(1.1, rh=("chest", B((1.75, 1.7, -0.3))), re=ELBOW_WAVE),
    K(1.35, rh=("chest", B((1.2, 1.78, -0.4))), re=ELBOW_WAVE),
    K(1.6, rh=("chest", WAVE_HIGH), re=ELBOW_WAVE),
    K(2.0, rh=C.REST, up=0),
    K(2.4),
])

# (2026-11-15 QA: the rub pressed the hands 0.45 out, into each other; now they rub at the clap's width, sliding up and
#  down against each other, and the first lift from hanging is a touch slower: it popped at 1361 deg/s.)
# (2026-11-16, clothes count as the body: at the celebrations' clap spot, 1.1 in front of the chest, the heels of the
#  hands and the forearms sank into the tee and singlet, 0.24 on Skinny (elbows left to the default, down and back,
#  so the forearms ran along the chest) to 0.39 on Fat. The emote's own clap is out in front of Fat's chest, the
#  elbows named out to the sides and down, never back.)
E_CLAP = B((-0.56, 0.2, -1.5))
E_CLAP_APART = B((-1.05, 0.25, -1.45))
ELBOW_E_CLAP = (-0.85, -0.5, -0.15)
_ec = {"le": ELBOW_E_CLAP, "re": mx(ELBOW_E_CLAP)}
RUB_A = B((-0.5, 0.3, -1.48))
RUB_B = B((-0.5, 0.16, -1.52))
emote("ChalkClap", 2.0, [
    K(0.24, with_=[both(E_CLAP_APART), _ec], up=-4),
    K(0.38, with_=[both(E_CLAP), _ec], up=-8, ease="fast"),
    K(0.52, with_=[both(E_CLAP_APART), _ec], up=-4),
    K(0.66, with_=[both(E_CLAP), _ec], up=-8, ease="fast"),
    K(0.85, with_=[both(RUB_A), _ec]),
    K(1.0, with_=[both(RUB_B), _ec]),
    K(1.15, with_=[both(RUB_A), _ec]),
    K(1.6, with_=rest(), up=0),
    K(2.0),
])

# (2026-11-15 QA: the elbows are named, out to the sides and a little forward, so the forearms come round the belly to
#  the belt instead of through Fat's sides.)
ELBOW_BELT = (-0.7, -0.35, -0.75)     # (2026-11-16: was (-1.0, -0.45, -0.25))
_eb = {"le": ELBOW_BELT, "re": mx(ELBOW_BELT)}
emote("BeltTighten", 2.6, [
    K(0.4, with_=[both(BELT), _eb], up=-14),
    K(0.7, with_=[both(BELT_TUG), _eb], pos=P(0, -0.12, 0), up=-16, ease="fast"),
    K(0.85, with_=[both(BELT), _eb], pos=(0, 0, 0), up=-12),
    K(1.1, with_=[both(BELT_TUG), _eb], pos=P(0, -0.14, 0), up=-16, ease="fast"),
    K(1.3, with_=[both(BELT), _eb], pos=(0, 0, 0), up=-6),
    K(1.55, with_=[both(B((-0.9, -0.6, -1.45))), _eb], up=4),
    K(1.7, with_=[both(BELT), _eb], up=2, ease="fast"),
    K(2.2, with_=rest(), up=0),
    K(2.6),
])

# (2026-11-15: the user's double biceps, as the celebrations' _DB_OPEN: upper arms out level, forearms straight up.)
emote("DoubleBiceps", 3.0, [
    K(0.45, with_=both(C._DB_OPEN), le=C._ELBOW_DB_OPEN, re=mx(C._ELBOW_DB_OPEN), cbend=-8, up=8, pos=P(0, -0.05, 0),
      ease="fast"),
    K(2.2, with_=both(C._DB_OPEN), le=C._ELBOW_DB_OPEN, re=mx(C._ELBOW_DB_OPEN), cbend=-10, up=10),
    K(2.6, with_=rest(), cbend=0, up=0, pos=(0, 0, 0)),
    K(3.0),
], layers=[C.tremble(0.55, 2.15, amp=0.04, hz=8.0, chest=1.0)])

if R.S.RIG == "torso":
    # (torso rig, 2026-11-13) ALTERNATING CROSS-BODY trap slaps: with the x1.5 arms a hand can't fold onto the top of its
    # own shoulder (it stopped by the head: "touching the face cheek instead of the trap", user), so each hand slaps the
    # OTHER trap in turn; the palm lands flat on top of the trap.
    # (2026-11-15 QA fix: the free hand "guarding" low at the belly had its elbow pulled behind the body and its hand in
    #  the belly, and the cocked hand's elbow was left to the default "out and back" (0.8 behind the shoulder); the joint
    #  flipped (3600 deg/s) between the two slaps. Now every elbow is named: the cocked arm's out to the side and a touch
    #  forward, the slapping arm's forward and down across the chest; the free arm hangs loose.)
    TRAP_WIND = B((-1.45, 0.75, -0.9))          # a hand cocked out to the side and forward at shoulder height (from beside
    #                                             the head the swing across cut through the face)
    TRAP_CROSS = B((0.88, 0.96, -0.66))         # the LEFT hand on top of the RIGHT trap, toward its front: the forearm
    #                                             crosses the upper chest, under the chin (2026-11-16, clothes count as
    #                                             the body: at (0.8, 0.9, -0.3) the palm went 0.3 into the tee and the
    #                                             singlet strap over the trap on Fat, Muscular and BigBuff; now it lands
    #                                             on them, a little further out and forward on the trap. Raising it
    #                                             instead put the upper arm into the head)
    ELBOW_WIND = (-1.0, -0.2, -0.3)             # (left) out to the side, a touch forward
    ELBOW_CROSS = (-0.25, -0.4, -1.0)           # (left) forward and a little down, the forearm across the upper chest
    ELBOW_CLAP = (-0.55, -1.0, -0.05)           # (left) down and out, never back
    # each slap comes back off the trap the way it went in (out to the cocked spot), never dragged down across the chest
    _trap_keys = [
        K(0.25, lh=("chest", TRAP_WIND), rh=C.REST, le=ELBOW_WIND, re=mx(ELBOW_WIND), up=-4),
        K(0.4, lh=("chest", TRAP_CROSS), le=ELBOW_CROSS, up=-6),
        K(0.48, rh=("chest", C.mx(TRAP_WIND)), re=mx(ELBOW_WIND)),
        K(0.55, lh=("chest", TRAP_WIND), le=ELBOW_WIND, up=-4),
        K(0.7, rh=("chest", C.mx(TRAP_CROSS)), re=mx(ELBOW_CROSS), up=-6),
        K(0.95, le=ELBOW_CLAP, re=mx(ELBOW_CLAP)),
    ]
else:
    _trap_keys = [
        K(0.25, with_=both(TRAP_OFF), up=-4),
        K(0.4, with_=both(TRAP), up=-6, ease="fast"),
        K(0.55, with_=both(TRAP_OFF), up=-4),
        K(0.7, with_=both(TRAP), up=-6, ease="fast"),
    ]
emote("TrapSlap", 2.6, _trap_keys + [
    K(0.95, with_=[both(E_CLAP_APART), _ec], up=0),
    K(1.15, with_=[both(E_CLAP), _ec], cbend=-6, up=10, ease="fast"),
    K(1.55, with_=both(B((-1.6, -0.1, -0.7))), cbend=-10, up=14),
    K(2.1, with_=rest(), cbend=0, up=0),
    K(2.6),
], layers=[C.tremble(1.2, 1.6, amp=0.04, hz=9.0, chest=1.2)], clothed=False)
# (2026-11-16: an elbow cap of 126 here (the cocked hand's elbow bent 133-135 folded BigBuff's forearm into its own
#  biceps) was removed the same day: the bodies' inner-elbow weights were spread (build_cartoon_rig_05.spread_elbows).)
# (clothed=False: hand-fitted instead; the clothed solve lifted the slapping hand off the trap and its upper arm went
#  through the head, 2026-11-16)
# (2026-11-15: the authored palm contact (S.palm_contact) was removed here: each time its weight let go, the solved arm
#  jumped back to the keyed one, 3000-4500 deg/s, a joint flip. The keyed hand now lands on the trap itself, palm down,
#  fingers out over the shoulder.)

# (2026-11-15 QA: the elbows are named so the forearms wrap round the belly to it, not through Fat's sides: out to the
#  side and a little forward; the pointing arm's elbow down and out.)
ELBOW_LAUGH = (-1.0, -0.45, -0.35)
ELBOW_POINT = (0.5, -1.0, -0.1)
emote("PointLaugh", 3.0, [
    K(0.25, rh=("chest", POINT_PREP), re=ELBOW_POINT, up=2),
    K(0.45, rh=("chest", POINT), re=ELBOW_POINT, turn=-6, up=4, ease="fast"),
    K(1.1, rh=("chest", POINT), re=ELBOW_POINT, turn=-6, up=4),
    K(1.4, with_=both(BELLY), le=ELBOW_LAUGH, re=mx(ELBOW_LAUGH), turn=0, up=10, lean=-4),
    K(2.4, with_=both(BELLY), le=ELBOW_LAUGH, re=mx(ELBOW_LAUGH), up=12, lean=-6),
    # (2026-11-15 QA: dropping straight to hanging swung the hands back through Fat's belly; they come off it forward
    #  and out first)
    K(2.6, with_=both(B((-1.35, -0.55, -1.45))), up=6, lean=-2),
    K(2.85, with_=rest(), up=0, lean=0),
    K(3.0),
], layers=[C.bounce(1.45, 2.4, height=0.04, hz=3.6, chest=2.5)])

# Sat on the floor as the celebrations' SitAndLaugh (C.SEAT_Y, C.from_seat): the feet a leg's stretch out from the hips;
# the forearms on the knees, which sit further forward by however much longer the thigh is.
_seat = {"pos": (0, C.SEAT_Y, C.SEAT_Z), "lean": -12, "lf": (-0.62, AY, C.from_seat(-0.62, LEG), 28, 0),
         "rf": (0.62, AY, C.from_seat(-0.62, LEG), 28, 0)}
_knees = both(B((-0.8, -0.55, -1.25 - (R.THIGH - 0.822))))
emote("SitBreath", 5.0, [
    # (2026-11-15 QA: the hands reaching back for the floor dragged the forearms through the thighs; going down, the
    #  arms now reach out and forward for balance, clear of the knees)
    # (2026-11-16, legs fix 2: going down, the hands at B((-1.35, -0.9, -0.7)) sat in the thighs of every build and the
    #  clothed solve shoved them out a different way on each (out to the side on Fat, in front with a straight arm on
    #  Muscular): a 1487 deg/s jerk at 0.83. Now keyed where they clear every build's thighs (chest frame), out to the
    #  side, then round in front of the knees, so the solve has nothing to push)
    K(0.6, pos=P(0, -0.75, 0.25), lean=22, up=-8, with_=both((-1.62, -0.97, -0.78))),
    K(0.85, with_=both((-1.5, -0.9, -1.3))),
    K(1.15, with_=[_seat, _knees], up=-12),
    K(3.4, with_=[_seat, _knees], up=-14),
    # (2026-11-16, longer thighs: off the knees the hands go out round them, not down through the thighs)
    K(3.62, with_=both(B((-1.3, -0.65, -1.25 - (R.THIGH - 0.822)))), up=-10),
    # (2026-11-16, longer thighs: getting up, the hands at z -1.0 sat inside the thighs and the clothed solve shoved
    #  them out up to 0.95 frame by frame, a 1300 deg/s jerk: now ahead of the knees by the thigh's extra length)
    # (legs fix 2: and out beside the knees (chest frame), where every build's thighs are clear: at the old spot the
    #  solve still pushed them 0.44 out on Skinny)
    K(3.9, pos=P(0, -1.0, 0.25), lean=26, with_=[both((-1.6, -1.17, -1.3)), {"lf": foot("Left", z=-0.15),
                                                                           "rf": foot("Right", z=-0.2)}], up=-5),
    K(4.4, pos=P(0, -0.3, 0.05), lean=10, with_=[rest(), stand_feet()], up=0),
    K(4.75, pos=(0, 0, 0), lean=0),
    K(5.0),
], layers=[C.bounce(1.3, 3.4, height=0.02, hz=1.2, chest=3.0)])

ELBOW_CRAB = (-0.85, -0.55, -0.45)       # (2026-11-16: more forward, -0.15 -> -0.45: the forearms clear Fat's belt)
CRAB_OUT = B((-1.2, -0.85, -0.8))          # on the way in and out: round the thighs, not through them
emote("MostMuscular", 3.2, [
    # (2026-11-15: the elbows bent out to the sides, as the crab is, so the fists come in clear of the thighs)
    K(0.22, with_=both(CRAB_OUT), le=ELBOW_CRAB, re=mx(ELBOW_CRAB), lean=5, cbend=4, up=-5),
    K(0.5, with_=both(CRAB), le=ELBOW_CRAB, re=mx(ELBOW_CRAB), lean=14, cbend=10, up=-14, pos=P(0, -0.12, 0), ease="fast"),
    K(2.3, with_=both(CRAB), le=ELBOW_CRAB, re=mx(ELBOW_CRAB), lean=16, cbend=12, up=-16, pos=P(0, -0.14, 0)),
    K(2.5, with_=both(CRAB_OUT), le=ELBOW_CRAB, re=mx(ELBOW_CRAB), lean=6, cbend=5, up=-6, pos=P(0, -0.05, 0)),
    K(2.7, with_=rest(), lean=0, cbend=0, up=0, pos=(0, 0, 0)),
    K(3.2),
], layers=[C.tremble(0.6, 2.3, amp=0.05, hz=9.0, chest=1.5)], fists=True)


def export_emote(name):
    """Celebrate_Emote<Name>.rbxmx from the rig, renamed to Emote_<Name>.rbxmx with its sequence named the same."""
    path = R.export(EMOTES[name])
    path = path[0] if isinstance(path, tuple) else path
    text = open(path, encoding="utf-8").read().replace(f"Celebrate_Emote{name}", f"Emote_{name}")
    final = os.path.join(os.path.dirname(path), f"Emote_{name}.rbxmx")
    with open(final, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    os.remove(path)
    return final


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    folder = argv[0] if argv else None
    names = argv[1:] or list(EMOTES)
    for name in names:
        c = EMOTES[name]
        c.solve()
        print("CHECK", R.check(c))
        print("EXPORTED", export_emote(name))
        if folder:
            R.preview_sheet(c, folder, view="front")
    print("DONE")
