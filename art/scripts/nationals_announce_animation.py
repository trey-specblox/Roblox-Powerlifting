# Nationals: the announcer's welcome (GAME_DESIGN §39, user 2026-11-18: the opening "pans to the announcer (a judge),
# talking to the crowd under a spotlight"). Played by the server on the platform's head referee (NationalsScenes.opening,
# MeetChalk.play: Action priority, not looped) LEAD seconds before the recording starts (NationalsConfig.WelcomeVoiceId,
# 10.75 s, ElevenLabs "David - Sports Arena Announcer"), so the microphone is up for the first word. The right hand
# holds the microphone (MeetFigures.giveMicrophone welds it into the closed hand, the head at the thumb's end) in front
# of the chin the whole time; the left arm, hand OPEN (rule 8), does the talking, in step with the words (read word by
# word from take A with a local faster-whisper, seconds into the recording):
#
#   0.0-1.4   "Welcome, ladies and gentlemen,"         the free arm opens out wide to the crowd, the head sweeps along it
#   1.8-3.0   "to Central Nationals!"                  the arm goes up high on "Nationals", chest lifted
#   3.7-4.4   "Where these lifters"                    the open hand goes back toward the platforms behind, a look back
#   4.4-6.3   "will be in an all or nothing battle,"   the hand out in front, three beats down: "all", "nothing", "battle"
#   6.3-8.3   "competing for the Worlds invitation!"   the arm rises again, highest on "Worlds"
#   8.9-10.2  "This meet will begin shortly!"          an open hand out in front, palm up, a nod; then both arms come down
#
# Built on celebration_rig.py like nationals_flow_animation.py: hands and forearms kept clear of the worn clothes on
# every build (clothed solve). Elbows only ever point down, out or forward (rule 1).
#   blender -b --factory-startup --python art/scripts/nationals_announce_animation.py -- [preview folder]
# writes art/animations/Nationals_Announce.rbxmx. Check it with anim_qa.py (QA_ANIM=Nationals_Announce), publish with
# art/scripts/upload_animations.py; the id goes in src/shared/Config/NationalsConfig.luau (Opening.AnnounceAnimationId).
import importlib.util
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\Powerlifting Roblox\art\scripts"
_spec = importlib.util.spec_from_file_location("celebration_animations", os.path.join(_HERE, "celebration_animations.py"))
C = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(C)
R = C.R
K = C.K

LEAD = 0.7                 # the microphone comes up this long before the first word (NationalsConfig.Opening.AnnounceLeadSeconds)
VOICE = 10.75              # the recording's length
LENGTH = LEAD + VOICE + 0.9


def v(seconds):
    """A time in the recording, as a time in the clip."""
    return LEAD + seconds


# The microphone hand (right), in front of the chin: the head of the microphone, at the thumb's end, comes to the mouth.
MIC = C.H((0.34, 0.5, -1.0))
MIC_ELBOW = (0.55, -1.0, -0.15)            # that elbow down, a little out and forward (never behind, rule 1)
# The free hand (left; chest frame, block numbers as the celebrations').
OUT_WIDE = C.O((-2.05, 0.75, -0.75))       # out to the side toward the crowd, a little forward, shoulder height
OUT_FRONT = C.O((-1.5, 0.7, -1.2))         # sweeping across the front on the way
UP_HIGH = C.O((-1.8, 2.05, -0.45))         # up high, well out from the head (-1.5 put Muscular's upper arm 0.15 into it)
BACK_AT_THEM = C.O((-2.0, 0.85, 0.25))     # out to the side and a little back: the platforms behind
BEAT_HIGH = C.F((-0.95, 0.75, -1.35))      # out in front of the chest: the top of a beat
BEAT_LOW = C.F((-0.95, 0.4, -1.4))         # ... and its bottom
UP_WORLDS = C.O((-1.7, 1.95, -0.7))        # up and forward, to the crowd, out from the head
PALM_UP = C.F((-1.0, 0.35, -1.45))         # out in front, lower, the palm turned up
ELBOW_SIDE = (-1.0, -0.35, -0.1)           # elbow out to the side and down
ELBOW_UP = (-1.0, 0.1, -0.2)               # arm raised: elbow out to the side, never back
ELBOW_FRONT = (-0.7, -0.75, -0.15)         # hand in front: elbow down and out

mic = {"rh": ("chest", MIC), "re": MIC_ELBOW}


def left(target, elbow):
    return {"lh": ("chest", target), "le": elbow}


ANNOUNCE = R.Clip("NationalsAnnounce", LENGTH, [
    K(0.0, lh=R.REST, rh=R.REST, up=0, turn=0, cbend=0, yaw=0),
    # the microphone comes up
    K(LEAD - 0.1, with_=mic, up=3),
    # "Welcome, ladies and gentlemen,"
    K(v(0.25), with_=[mic, left(OUT_FRONT, ELBOW_FRONT)], turn=10, up=4, yaw=4),
    K(v(0.95), with_=[mic, left(OUT_WIDE, ELBOW_SIDE)], turn=-16, up=6, yaw=-6, cbend=-2),
    K(v(1.5), with_=[mic, left(OUT_WIDE, ELBOW_SIDE)], turn=-10, up=6, yaw=-5),
    # "to Central Nationals!"
    K(v(2.0), with_=[mic, left(OUT_FRONT, ELBOW_FRONT)], turn=0, up=4, yaw=0, cbend=0),
    K(v(2.6), with_=[mic, left(UP_HIGH, ELBOW_UP)], turn=6, up=12, cbend=-5, ease="fast"),
    K(v(3.25), with_=[mic, left(UP_HIGH, ELBOW_UP)], turn=-6, up=12, cbend=-5),
    # "Where these lifters"
    K(v(3.75), with_=[mic, left(OUT_WIDE, ELBOW_SIDE)], turn=-14, up=4, cbend=0, yaw=-6),
    K(v(4.25), with_=[mic, left(BACK_AT_THEM, ELBOW_SIDE)], turn=-34, up=2, yaw=-14, ctwist=-6),
    # "will be in an all or nothing battle,"
    K(v(4.8), with_=[mic, left(BEAT_HIGH, ELBOW_FRONT)], turn=-4, up=4, yaw=0, ctwist=0),
    K(v(5.2), with_=[mic, left(BEAT_LOW, ELBOW_FRONT)], turn=4, up=0, ease="fast"),          # "all"
    K(v(5.42), with_=[mic, left(BEAT_HIGH, ELBOW_FRONT)], up=4),
    K(v(5.62), with_=[mic, left(BEAT_LOW, ELBOW_FRONT)], turn=8, up=0, ease="fast"),         # "nothing"
    K(v(5.84), with_=[mic, left(BEAT_HIGH, ELBOW_FRONT)], up=4),
    K(v(6.05), with_=[mic, left(BEAT_LOW, ELBOW_FRONT)], turn=0, up=-2, cbend=3, ease="fast"),  # "battle"
    # "competing for the Worlds invitation!"
    K(v(6.6), with_=[mic, left(OUT_FRONT, ELBOW_FRONT)], turn=8, up=4, cbend=0, yaw=5),
    K(v(7.5), with_=[mic, left(UP_WORLDS, ELBOW_UP)], turn=0, up=13, cbend=-5, yaw=0, ease="fast"),   # "Worlds"
    K(v(8.35), with_=[mic, left(UP_WORLDS, ELBOW_UP)], turn=-8, up=12, cbend=-4),
    # the breath before the last line
    K(v(8.85), with_=[mic, left(OUT_FRONT, ELBOW_FRONT)], turn=-4, up=3, cbend=0),
    # "This meet will begin shortly!"
    K(v(9.3), with_=[mic, left(PALM_UP, ELBOW_FRONT)], turn=6, up=4, yaw=4, lw=(0.0, 70.0)),
    K(v(9.9), with_=[mic, left(PALM_UP, ELBOW_FRONT)], turn=-6, up=-6, yaw=-3, lw=(0.0, 70.0)),     # the nod on "shortly"
    K(v(10.3), with_=[mic, left(PALM_UP, ELBOW_FRONT)], turn=0, up=2, yaw=0, lw=(0.0, 70.0)),
    # the microphone comes down, both arms to the sides
    K(v(10.75), with_=mic, lh=R.REST, le=ELBOW_SIDE, lw=(0.0, 0.0), up=0),
    K(LENGTH - 0.15, lh=R.REST, rh=R.REST, up=0, turn=0, cbend=0, yaw=0),
    K(LENGTH),
], clothed=True)


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


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    folder = argv[0] if argv else None
    ANNOUNCE.solve()
    print("CHECK", R.check(ANNOUNCE))
    print("EXPORTED", export_named(ANNOUNCE, "Nationals_Announce"))
    if folder:
        times = [LEAD + t for t in (0.0, 0.95, 2.6, 3.25, 4.25, 5.2, 5.84, 6.05, 7.5, 9.3, 9.9)] + [LENGTH - 0.3]
        for view in ("front", "side"):
            R.preview_sheet(ANNOUNCE, folder, times=times, view=view)
    print("DONE")
