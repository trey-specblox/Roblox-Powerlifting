# The emotes (user 2026-11-11: an emote wheel on B, "8 gym emotes", collected; two free, the rest won at the
# celebration NPC's spin). Powerlifting flavour from the user's meet clips (References/Clip Study) and gym life. Each
# starts and ends standing at rest, on the spot, and plays once (Action priority); moving cancels it in the game.
#
#   Wave           (free) a big wave, hand up beside the head
#   ChalkClap      (free) two chalky claps at the chest and a rub of the hands
#   BeltTighten    hands to the belt, two hard tugs with a dip, a slap on the belt
#   DoubleBiceps   a double biceps flex, held and shaking
#   TrapSlap       slaps both traps twice, then a hard clap, chest out
#   PointLaugh     points at someone, then laughs, a hand on the belly
#   SitBreath      sits down on the floor, forearms on the knees, catching a breath, and back up
#   MostMuscular   the crab: leans in, fists together in front of the hips, everything tensed and shaking
#
# Built on celebration_rig.py with the celebrations' pose vocabulary (celebration_animations.py).
#   blender -b --factory-startup --python art/scripts/emote_animations.py -- [preview folder] [names...]
# checks each, writes art/animations/Emote_<Name>.rbxmx, and with a folder renders front preview sheets. Publish with
# art/scripts/upload_animations.py; ids go in src/shared/Config/EmoteConfig.luau.
import importlib.util
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

EMOTES = {}


def emote(name, length, keys, layers=()):
    EMOTES[name] = R.Clip("Emote" + name, length, keys, layers)


WAVE_HIGH = (1.45, 1.75, -0.35)       # (right) hand up beside the head, open
BELT = (-0.62, -0.95, -0.78)          # hands on the front of the belt
BELT_TUG = (-0.66, -1.1, -0.72)
TRAP = (-0.62, 0.86, -0.12)           # a hand on top of its own shoulder
TRAP_OFF = (-1.0, 1.2, -0.45)
BELLY = (-0.42, -0.45, -0.98)
POINT = (0.8, 0.62, -1.55)           # (right) pointing straight ahead, as far as the arm reaches
POINT_PREP = (1.1, 0.5, -1.2)
CRAB = (-0.42, -0.95, -0.95)          # fists nearly touching in front of the hips

emote("Wave", 2.4, [
    K(0.35, rh=("chest", WAVE_HIGH), up=6, ease="fast"),
    K(0.6, rh=("chest", (1.75, 1.7, -0.3))),
    K(0.85, rh=("chest", (1.2, 1.78, -0.4))),
    K(1.1, rh=("chest", (1.75, 1.7, -0.3))),
    K(1.35, rh=("chest", (1.2, 1.78, -0.4))),
    K(1.6, rh=("chest", WAVE_HIGH)),
    K(2.0, rh=C.REST, up=0),
    K(2.4),
])

emote("ChalkClap", 2.0, [
    K(0.2, with_=both(CLAP_APART), up=-4),
    K(0.35, with_=both(CLAP), up=-8, ease="fast"),
    K(0.5, with_=both(CLAP_APART), up=-4),
    K(0.65, with_=both(CLAP), up=-8, ease="fast"),
    K(0.85, with_=both((-0.55, 0.3, -1.02))),
    K(1.0, with_=both((-0.45, 0.22, -1.05))),
    K(1.15, with_=both((-0.55, 0.3, -1.02))),
    K(1.6, with_=rest(), up=0),
    K(2.0),
])

emote("BeltTighten", 2.6, [
    K(0.4, with_=both(BELT), up=-14),
    K(0.7, with_=both(BELT_TUG), pos=(0, -0.12, 0), up=-16, ease="fast"),
    K(0.85, with_=both(BELT), pos=(0, 0, 0), up=-12),
    K(1.1, with_=both(BELT_TUG), pos=(0, -0.14, 0), up=-16, ease="fast"),
    K(1.3, with_=both(BELT), pos=(0, 0, 0), up=-6),
    K(1.55, with_=both((-0.9, -0.6, -0.9)), up=4),
    K(1.7, with_=both(BELT), up=2, ease="fast"),
    K(2.2, with_=rest(), up=0),
    K(2.6),
])

emote("DoubleBiceps", 3.0, [
    K(0.45, with_=both(BICEP), le=ELBOW_BICEP, re=mx(ELBOW_BICEP), cbend=-8, up=8, pos=(0, -0.05, 0), ease="fast"),
    K(2.2, with_=both(BICEP), cbend=-10, up=10),
    K(2.6, with_=rest(), cbend=0, up=0, pos=(0, 0, 0)),
    K(3.0),
], layers=[C.tremble(0.55, 2.15, amp=0.04, hz=8.0, chest=1.0)])

emote("TrapSlap", 2.6, [
    K(0.25, with_=both(TRAP_OFF), up=-4),
    K(0.4, with_=both(TRAP), up=-6, ease="fast"),
    K(0.55, with_=both(TRAP_OFF), up=-4),
    K(0.7, with_=both(TRAP), up=-6, ease="fast"),
    K(0.95, with_=both(CLAP_APART), up=0),
    K(1.15, with_=both(CLAP), cbend=-6, up=10, ease="fast"),
    K(1.55, with_=both((-1.6, -0.1, -0.7)), cbend=-10, up=14),
    K(2.1, with_=rest(), cbend=0, up=0),
    K(2.6),
], layers=[C.tremble(1.2, 1.6, amp=0.04, hz=9.0, chest=1.2)])

emote("PointLaugh", 3.0, [
    K(0.25, rh=("chest", POINT_PREP), up=2),
    K(0.45, rh=("chest", POINT), turn=-6, up=4, ease="fast"),
    K(1.1, rh=("chest", POINT), turn=-6, up=4),
    K(1.4, rh=("chest", BELLY), lh=("chest", (-0.9, -0.2, -0.85)), turn=0, up=10, lean=-4),
    K(2.4, rh=("chest", BELLY), lh=("chest", (-0.9, -0.2, -0.85)), up=12, lean=-6),
    K(2.75, with_=rest(), up=0, lean=0),
    K(3.0),
], layers=[C.bounce(1.45, 2.4, height=0.04, hz=3.6, chest=2.5)])

_seat = {"pos": (0, -1.27, 0.55), "lean": -12, "lf": (-0.62, AY, -0.62, 28, 0), "rf": (0.62, AY, -0.62, 28, 0)}
_knees = both((-0.8, -0.55, -1.25))
emote("SitBreath", 5.0, [
    K(0.6, pos=(0, -0.75, 0.25), lean=22, up=-8, with_=both((-0.9, -1.3, 0.2))),
    K(1.15, with_=[_seat, _knees], up=-12),
    K(3.4, with_=[_seat, _knees], up=-14),
    K(3.9, pos=(0, -1.0, 0.25), lean=26, with_=[both((-0.9, -0.9, -1.0)), {"lf": foot("Left", z=-0.15),
                                                                           "rf": foot("Right", z=-0.2)}], up=-5),
    K(4.4, pos=(0, -0.3, 0.05), lean=10, with_=[rest(), stand_feet()], up=0),
    K(4.75, pos=(0, 0, 0), lean=0),
    K(5.0),
], layers=[C.bounce(1.3, 3.4, height=0.02, hz=1.2, chest=3.0)])

emote("MostMuscular", 3.2, [
    K(0.5, with_=both(CRAB), lean=14, cbend=10, up=-14, pos=(0, -0.12, 0), ease="fast"),
    K(2.3, with_=both(CRAB), lean=16, cbend=12, up=-16, pos=(0, -0.14, 0)),
    K(2.7, with_=rest(), lean=0, cbend=0, up=0, pos=(0, 0, 0)),
    K(3.2),
], layers=[C.tremble(0.6, 2.3, amp=0.05, hz=9.0, chest=1.5)])


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
