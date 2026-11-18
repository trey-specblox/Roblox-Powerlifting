# Nationals: the lifter's "flow state" behind the curtain (GAME_DESIGN §39, user 2026-11-17: "the lifter, chalks their
# hands n then it seen standing right behind the curtain, entering 'flow state' or just rocking back n forth, until the
# user clicks anywhere on the screen"). From the Meet Study's self-composure moves (References/Meet Study/Meet Study.md:
# head bowed, eyes down, a slow breath; shaking out the hands; rocking): a LOOP, played by the server (LocalMeetService
# waitBehindCurtain, MeetChalk.play: looped, Action priority) until the lifter steps out.
#
#   FlowState  feet planted; the body rocks slowly forward and back over them (two rocks a loop), head bowed, a slow
#              breath in the chest; halfway the hands shake out loose at the sides, open, then hang again.
#
# Built on celebration_rig.py with the emotes' tools (emote_animations.py): hands and forearms kept clear of the worn
# meet outfit on every build (clothed solve). The loop's first and last frames are the same pose: every moving channel
# is a whole number of sine periods over LOOP_SECONDS, the shake-out fades in and out inside the loop.
#   blender -b --factory-startup --python art/scripts/nationals_flow_animation.py -- [preview folder]
# writes art/animations/Nationals_FlowState.rbxmx. Check it with anim_qa.py (QA_ANIM=Nationals_FlowState), publish with
# art/scripts/upload_animations.py; the id goes in src/shared/Config/NationalsConfig.luau (FlowAnimationId).
import importlib.util
import math
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\Powerlifting Roblox\art\scripts"
_spec = importlib.util.spec_from_file_location("celebration_animations", os.path.join(_HERE, "celebration_animations.py"))
C = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(C)
R = C.R
K, P = C.K, C.P

LOOP_SECONDS = 4.0
ROCK_PERIOD = 2.0            # one slow rock forward and back (two a loop)
ROCK_LEAN = 7.0              # degrees forward/back at the hips (3.5 was too small to read from the side)
ROCK_SHIFT = 0.14            # the hips' travel forward/back over the planted feet (block-rig studs, scaled by P)
BREATH_BEND = 2.5            # the chest's slow breath (degrees), one breath a loop
HEAD_DOWN = -24              # head bowed, eyes on the floor ahead (-14 barely showed on the block heads)
SHAKE = (1.2, 2.6)           # the hands shake out loose at the sides


def rock(t, ch):
    """The slow rock and the breath: whole periods over the loop, so the loop has no seam."""
    w = math.sin(2 * math.pi * t / ROCK_PERIOD)
    b = math.sin(2 * math.pi * t / LOOP_SECONDS)
    shift = P(0, 0, -ROCK_SHIFT * w)
    return {"lean": ROCK_LEAN * w, "pos": shift, "cbend": -BREATH_BEND * b, "up": 2.0 * b}


def shake_out(t, ch):
    """Loose hands shaking at the sides (open), faded in and out inside the loop."""
    t0, t1 = SHAKE
    if t <= t0 or t >= t1:
        return {}
    edge = min(1.0, (t - t0) / 0.3, (t1 - t) / 0.3)
    w = edge * math.sin(2 * math.pi * 6.5 * (t - t0))
    w2 = edge * math.sin(2 * math.pi * 6.5 * 0.9 * (t - t0) + 1.1)
    return {"lh": (0.03 * w2, 0.05 * w, 0.02 * w2), "rh": (0.03 * w, 0.05 * w2, 0.02 * w)}


FLOW = R.Clip("NationalsFlowState", LOOP_SECONDS, [
    K(0.0, up=HEAD_DOWN, turn=0),
    K(LOOP_SECONDS, up=HEAD_DOWN, turn=0),
], layers=[rock, shake_out], clothed=True)


# ---------------------------------------------------------------- parting the curtain (user 2026-11-18)
# "once the user clicks, they are seen using their arms and moving the curtain to enter the platform". Played the moment
# they click (LocalMeetService), ARMS, CHEST AND HEAD ONLY over the walk that starts CurtainPartLeadSeconds later: the head
# comes up off the floor to the split, both open hands come up together in front of the chest into the split, sweep
# apart pushing the two halves aside (palms turned out), hold them wide while the body steps through, then drop to the
# sides. The curtain's halves swing apart with the hands (NationalsCurtains opens it sooner while this plays).
PART_SECONDS = 1.8
# (first try 2026-11-18: y 0.55 / 0.5 / 0.42 put the hands at the belly, and the wrists rolled 95 turned the palms down
#  like paws: the hands now chest-high and upright, palms facing in, the BACKS of the hands parting the cloth)
#  (second try: y 1.05 / 1.0 / 0.9 threw the hands up beside the head, "hands up"; chest height is about y 0.5-0.8 here)
PART_LIFT = C.F((-0.8, 0.05, -1.35))       # on the way up: out in front of the belly, clear of it
PART_REACH = C.F((-0.42, 0.78, -1.5))      # (left; mirrored) both hands together in front of the chest, into the split
PART_OPEN = C.F((-1.45, 0.42, -1.45))      # swept apart at chest height, out in front (y 0.6 z -1.0 read as a guard)
PART_HOLD = C.O((-1.9, 0.38, -0.75))       # held wide as the body passes between the halves
ELBOW_REACH = (-0.65, -0.6, -0.45)         # elbows down, out and forward (never behind the body, rule 1)
ELBOW_OPEN = (-1.0, -0.4, -0.2)
PALM_OUT_L, PALM_OUT_R = (0.0, 0.0), (0.0, 0.0)   # hands upright, palms in: the backs push the cloth aside


def both_hands(left):
    return {"lh": ("chest", left), "rh": ("chest", C.mx(left))}


PART = R.Clip("NationalsCurtainPart", PART_SECONDS, [
    K(0.0, up=HEAD_DOWN, cbend=0, lh=R.REST, rh=R.REST, lw=(0.0, 0.0), rw=(0.0, 0.0)),
    K(0.17, with_=both_hands(PART_LIFT), le=ELBOW_REACH, re=C.mx(ELBOW_REACH), up=-14),
    K(0.35, with_=both_hands(PART_REACH), le=ELBOW_REACH, re=C.mx(ELBOW_REACH), lw=PALM_OUT_L, rw=PALM_OUT_R,
      up=-4, cbend=5, ease="fast"),
    K(0.8, with_=both_hands(PART_OPEN), le=ELBOW_OPEN, re=C.mx(ELBOW_OPEN), up=0, cbend=4),
    K(1.25, with_=both_hands(PART_HOLD), up=2, cbend=2),
    K(PART_SECONDS, lh=R.REST, rh=R.REST, lw=(0.0, 0.0), rw=(0.0, 0.0), up=0, cbend=0),
], clothed=True)
# Keyed parts (the rest, legs and hips, is left to the walk underneath).
PART_ONLY = ["UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm",
             "RightHand"]


def export_named(clip, name, looped=False, only=None):
    """Celebrate_<clip>.rbxmx from the rig, renamed to <name>.rbxmx with its sequence named the same."""
    path = R.export(clip, looped=looped, only=only)
    path = path[0] if isinstance(path, tuple) else path
    text = open(path, encoding="utf-8").read().replace("Celebrate_" + clip.name, name)
    final = os.path.join(os.path.dirname(path), name + ".rbxmx")
    with open(final, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    os.remove(path)
    return final


def export_flow():
    """Nationals_FlowState.rbxmx, looped."""
    return export_named(FLOW, "Nationals_FlowState", looped=True)


def export_part():
    """Nationals_CurtainPart.rbxmx: arms, chest and head only, not looped."""
    return export_named(PART, "Nationals_CurtainPart", only=PART_ONLY)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    folder = argv[0] if argv else None
    which = argv[1:] or ["flow", "part"]
    for key, clip, export in (("flow", FLOW, export_flow), ("part", PART, export_part)):
        if key not in which:
            continue
        clip.solve()
        print("CHECK", R.check(clip))
        print("EXPORTED", export())
        if folder:
            R.preview_sheet(clip, folder, view="front")
    print("DONE")
