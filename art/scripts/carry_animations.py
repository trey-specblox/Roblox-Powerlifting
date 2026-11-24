# Carrying food in front with both hands (GAME_DESIGN §42; user 2026-11-24 first: "hold it over their head, like a server
# bringing you food"; then, after the over-the-head pose: "just change it to where two hands are foward holding the
# plate"). Built on the celebrations' pose engine (celebration_rig.py, celebration_animations.py).
#
#   Carry_FoodTray  loop, ARMS ONLY (the walk and the idle keep the legs, the body and the head): both OPEN hands out in
#                   front of the chest, palms up, fingers forward, forearms level, elbows out to the sides and a little
#                   down (never behind the body), a small bob. HoldService plays it while food is held and puts the
#                   plate on both palms.
#
# The pose is the chef's tray hold (chef_animations.py TRAY / W_TRAY / ELBOW_OUT_DOWN, checked on the rig 2026-11-21:
# palms up, fingers forward), a little further forward so the plate clears the biggest bellies.
#   blender -b --factory-startup --python art/scripts/carry_animations.py -- [preview folder]
# writes art/animations/Carry_<Name>.rbxmx; publish with art/scripts/upload_animations.py (ask the user first).
# Check: anim_qa.py with QA_ANIM=Carry_FoodTray, QA_BUILDS=Skinny,Fat,Muscular,BigBuff.
import importlib.util
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\Powerlifting Roblox\art\scripts"
_spec = importlib.util.spec_from_file_location("celebration_animations", os.path.join(_HERE, "celebration_animations.py"))
C = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(C)
R = C.R
K, mx, mx_w = C.K, C.mx, C.mx_w

ARMS = ("LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand")

_TRAY = C.B((-0.95, 0.3, -2.0))         # left hand, chest frame (mirrored): at the chest, out in front, wide enough
#                                         for a plate and clear of the Fat belly (-0.78, -1.7 nearly met at the middle)
_TRAY_BOB = C.B((-0.95, 0.27, -2.0))    # the bob: 0.03 lower
_ELBOW = (-1.0, -0.5, 0.1)              # out to the sides and a little down
_WRIST = (-30, 80)                      # palms up, fingers forward (the chef's W_TRAY)

CLIPS = {}


def clip(name, length, keys, layers=(), only=None, looped=False):
    c = R.Clip(name, length, keys, layers, clothed=True)
    CLIPS[name] = (c, only, looped)
    return c


def _carry(hand):
    return dict(with_=C.both(hand), le=_ELBOW, re=mx(_ELBOW), lw=_WRIST, rw=mx_w(_WRIST))


clip("FoodTray", 2.0, [
    K(0.0, **_carry(_TRAY)),
    K(1.0, **_carry(_TRAY_BOB)),
    K(2.0, **_carry(_TRAY)),
], only=ARMS, looped=True)


def export(c, only, looped):
    path, frames = R.export(c, only=only, looped=looped)
    out = os.path.join(os.path.dirname(path), f"Carry_{c.name}.rbxmx")
    text = open(path, encoding="utf-8").read()
    text = re.sub(r"<string name=\"Name\">Celebrate_%s</string>" % c.name, f"<string name=\"Name\">Carry_{c.name}</string>", text, 1)
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    os.remove(path)
    return out, frames


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    folder = argv[0] if argv else None
    for name, (c, only, looped) in CLIPS.items():
        c.solve()
        print("CHECK", R.check(c))
        print("EXPORTED", export(c, only, looped))
        if folder:
            R.preview_sheet(c, folder, view="front")
            R.preview_sheet(c, folder, view="side")
    print("DONE")
