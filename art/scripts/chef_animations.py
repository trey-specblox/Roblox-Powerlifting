# The Kitchen chef's moves for the chef scene (GAME_DESIGN §40.7; user 2026-11-21: the old scene was "too fast and
# weird, like the meat just walks away"; he held the meat in the "Long V" celebration, fists in a wide V, so it floated
# between two fists). Built on the celebrations' pose engine (celebration_rig.py, celebration_animations.py's numbers),
# on the Fat build the staff wear (LifterBuild.BuildRules.Spotter):
#
#   Chef_ScoopLift  squats at the meat mound, both OPEN hands slide under it palms up, stands up with it at the chest,
#                   dips and drives it up high in front of his head (his tall hat leaves no room right overhead: the
#                   arms can reach 3.64 above the root, the hat's top is at 4.19), ends in the hold
#   Chef_Hold       the hold, looped, arms and head only (the game's walk plays under it while he turns to the pan)
#   Chef_Throw      from the hold: a wind-up back over the head, a two-handed heave forward (the meat leaves the
#                   palms at RELEASE), a follow-through, arms down
#   Chef_ButtonPress  (2026-11-21, the new chef scene: "the chef presses a button to start the grinder") he looks down
#                   at the start button in front of him, lifts his OPEN right hand in front of his shoulder, slaps the
#                   palm down flat on the button (PRESS), holds it there a beat and lets the arm fall. The scene stands
#                   him so the button is under that hand (KitchenConfig.ChefPress numbers, measured in Studio).
#
# The scene (src/client/World/KitchenScene.luau) plays them on the cooking player's own copy of the chef, so the hands
# and the meat always keep time; it puts the meat ON the palms from GRAB on (ChefConfig numbers in KitchenConfig).
#   blender -b --factory-startup --python art/scripts/chef_animations.py -- [preview folder]
# writes art/animations/Chef_<Name>.rbxmx; publish with art/scripts/upload_animations.py.
# Check: anim_qa.py with QA_BUILDS=Fat (only the Fat build plays them), QA_ANIM=Chef_<Name>.
import importlib.util
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\Powerlifting Roblox\art\scripts"
_spec = importlib.util.spec_from_file_location("celebration_animations", os.path.join(_HERE, "celebration_animations.py"))
C = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(C)
R = C.R
K, both, B, O, mx, mx_w, rest, tremble = C.K, C.both, C.B, C.O, C.mx, C.mx_w, C.rest, C.tremble

GRAB = 1.05       # Chef_ScoopLift: the hands are under the meat (the scene puts it on the palms from here)
RELEASE = 0.72    # Chef_Throw: the meat leaves the palms

# Left hand, chest frame (mirrored for the right). Palms up under the meat.
SCOOP = {"lh": ("floor", (-0.9, 0.55, -1.85)), "rh": ("floor", (0.9, 0.55, -1.85))}   # low in front of the toes (floor space)
TRAY = B((-0.78, 0.3, -1.55))                # at the chest, forearms level, like carrying a big tray
HOLD = O((-1.05, 1.6, -1.65))                # up and well forward (about 25 degrees up, the hands ~2 studs ahead of
#                                              the head), so the meat sits over his palms and still clears his tall hat
#                                              (2026-11-21 Studio: held at 50 degrees, the meat had to sit so far ahead
#                                              of the hands that a gap showed under it)
WIND = O((-1.05, 1.72, -1.55))               # wound back: the arms stay near the hold (on the chest), the whole upper body
#                                              arches back to take the meat back, so it never swings over his hat
THROWN = O((-1.1, 1.75, -1.7))               # driven forward and up (about 35 degrees): the release
FOLLOW = B((-0.9, -0.35, -1.65))             # the follow-through, down in front of the belly
# wrists (pitch, roll) with the palm facing straight up and the fingers forward, found by a search over every pitch and
# roll on each pose (palm . up + fingers . forward; 2026-11-21: the first guesses turned the palms toward the head)
W_SCOOP, W_TRAY, W_HOLD, W_THROW = (60, 80), (-30, 80), (-30, 120), (-30, 90)
ELBOW_OUT_DOWN = (-1.0, -0.5, 0.1)           # elbows out to the sides and a little down
ELBOW_UP = (-0.9, 0.6, -0.2)                 # winding up: out and up, a little forward

_hold = dict(with_=both(HOLD), le=ELBOW_OUT_DOWN, re=mx(ELBOW_OUT_DOWN), lw=W_HOLD, rw=mx_w(W_HOLD))

CLIPS = {}


def clip(name, length, keys, layers=(), only=None, looped=False):
    c = R.Clip(name, length, keys, layers, clothed=True)
    CLIPS[name] = (c, only, looped)
    return c


clip("ScoopLift", 2.8, [
    K(0.0),
    K(0.45, pos=(0, -0.55, 0.15), lean=16, cbend=6, up=-12,
      with_=both(B((-1.0, -1.05, -1.55))), le=ELBOW_OUT_DOWN, re=mx(ELBOW_OUT_DOWN), lw=W_SCOOP, rw=mx_w(W_SCOOP)),
    K(0.95, pos=(0, -1.2, 0.35), lean=32, cbend=10, up=-18, with_=SCOOP),
    K(GRAB + 0.15, pos=(0, -1.2, 0.35), lean=32, cbend=10, up=-14, with_=SCOOP),
    K(1.75, pos=(0, -0.1, 0.05), lean=4, cbend=0, up=0, with_=both(TRAY), lw=W_TRAY, rw=mx_w(W_TRAY)),
    K(1.95, pos=(0, -0.22, 0.05), lean=2, with_=both(B((-0.8, 0.75, -1.45)))),       # the dip
    K(2.35, pos=(0, 0, 0), lean=0, up=12, ease="fast", **_hold),                         # the drive up
    K(2.8, up=14, **_hold),
])

clip("Hold", 2.0, [
    K(0.0, up=14, **_hold),
    K(1.0, up=16, **_hold),
    K(2.0, up=14, **_hold),
], layers=[tremble(0.1, 1.9, amp=0.025, hz=5.0, chest=0.6)], only=C.ARMS_AND_HEAD, looped=True)

clip("Throw", 1.7, [
    K(0.0, up=14, **_hold),
    K(0.45, pos=(0, -0.12, 0.1), lean=-10, cbend=-16, up=16, with_=both(WIND), le=ELBOW_UP, re=mx(ELBOW_UP),
      lw=W_HOLD, rw=mx_w(W_HOLD), ease="slow"),
    K(RELEASE, pos=(0, -0.05, -0.1), lean=10, cbend=10, up=8, with_=both(THROWN), le=ELBOW_OUT_DOWN,
      re=mx(ELBOW_OUT_DOWN), lw=W_THROW, rw=mx_w(W_THROW), ease="fast"),
    K(0.98, pos=(0, -0.08, -0.1), lean=22, cbend=16, up=-6, with_=both(FOLLOW), lw=(0, 0), rw=(0, 0)),
    K(1.4, pos=(0, 0, 0), lean=0, cbend=0, up=0, with_=rest()),
    K(1.7),
])


PRESS = 0.62      # Chef_ButtonPress: the palm lands on the button
# Right hand, chest frame (x to his right, y up, -z forward). The button stands in front of him, a little to his right,
# about belly height. The elbow stays out to the side and forward of the body (never behind it, never into the ribs).
_BP_READY = mx(O((-0.78, 1.05, -1.3)))         # the open hand lifted in front of the right shoulder
_BP_DOWN = mx(B((-0.8, -0.2, -1.95)))         # flat on the button: out in front of his right side, clear of the belly
#                                               (first try (-0.52, -0.62, -1.5) ended on his belt in the middle)
_BP_ELBOW = (0.7, -0.7, 0.0)                   # out to the side and down, level with the body (never behind it)
_BP_W_READY, _BP_W_DOWN = (-20, 100), (10, 100)   # palm down, fingers forward (the mirror of the tray's palm-up roll)

clip("ButtonPress", 1.6, [
    K(0.0),
    K(0.36, rh=("chest", _BP_READY), re=_BP_ELBOW, rw=_BP_W_READY, lh=C.REST, lean=3, up=-12, ease="slow"),
    K(PRESS, rh=("chest", _BP_DOWN), re=_BP_ELBOW, rw=_BP_W_DOWN, lh=C.REST, lean=9, cbend=5, up=-18, ease="fast"),
    K(PRESS + 0.3, rh=("chest", _BP_DOWN), re=_BP_ELBOW, rw=_BP_W_DOWN, lh=C.REST, lean=9, cbend=5, up=-16),
    K(1.3, with_=rest(), rw=(0, 0), lean=0, cbend=0, up=0),
    K(1.6),
])


def export(c, only, looped):
    path, frames = R.export(c, only=only, looped=looped)
    out = os.path.join(os.path.dirname(path), f"Chef_{c.name}.rbxmx")
    text = open(path, encoding="utf-8").read()
    text = re.sub(r"<string name=\"Name\">Celebrate_%s</string>" % c.name, f"<string name=\"Name\">Chef_{c.name}</string>", text, 1)
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    os.remove(path)
    return out, frames


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    folder = argv[0] if argv else None
    wanted = [n for n in os.environ.get("CHEF_ONLY", "").split(",") if n]   # e.g. CHEF_ONLY=ButtonPress
    for name, (c, only, looped) in CLIPS.items():
        if wanted and name not in wanted:
            continue
        c.solve()
        print("CHECK", R.check(c))
        print("EXPORTED", export(c, only, looped))
        if folder:
            R.preview_sheet(c, folder, view="front")
            R.preview_sheet(c, folder, view="side")
    print("DONE")
