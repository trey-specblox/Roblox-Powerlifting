# Builds CardioTV_01 in the live Blender scene: the Cardio room's wall TV (user 2026-10-28: "This Tv is very
# bland and just a square", then "I want every model to be made in blender"). A slim TV with a thin rounded
# bezel and a chin carrying the CENTRAL logo and a power light, a glossy screen panel (Roblox draws the
# screen's content on it with a SurfaceGui: the idle CARDIO ZONE sign and the rhythm game's round), a steel
# wall mount behind it, and a soundbar under it with a speaker grille, end caps and a yellow trim.
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, the wall is the plane y = 0 and the TV faces
# -Y; the screen is 13 x 6.2 studs like the old block TV, its centre at z = 0. Objects are "CardioTV_<Piece>"
# with ONE material each.
#
# Run in an otherwise empty file (art/blender/CardioTV_01.blend):
#   exec(compile(open(path).read(), path, "exec"), {"__file__": path, "__name__": "__main__"})
# Objects are replaced by name on every run.

import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

B = H.Builder("CardioTV_01")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.5, emission=None):
    lin = tuple(linear(c) for c in rgb)
    return H.material("CTV_" + name, lin, metallic, roughness, 1.0, emission)


BEZEL = mat("Bezel", (18, 18, 20), 0.2, 0.35)
SCREEN = mat("Screen", (8, 10, 18), 0.0, 0.08)
BACK = mat("Back", (40, 42, 48), 0.0, 0.6)
STEEL = mat("Steel", (176, 180, 186), 1.0, 0.3)
GRILLE = mat("Grille", (30, 32, 36), 0.0, 0.8)
YELLOW = mat("Yellow", (250, 206, 36), 0.0, 0.4)
WHITE = mat("White", (248, 248, 244), 0.0, 0.4)
GREEN = mat("PowerLight", (70, 230, 110), 0.0, 0.3, emission=(0.2, 0.9, 0.4))

SCREEN_W, SCREEN_H = 13.0, 6.2
BEZEL_SIDE, BEZEL_TOP, CHIN = 0.22, 0.22, 0.62
DEPTH = 0.42            # the panel's thickness
MOUNT_GAP = 0.35        # space between the wall and the panel's back
PANEL_BACK = -MOUNT_GAP
PANEL_FRONT = PANEL_BACK - DEPTH
BODY_W = SCREEN_W + 2 * BEZEL_SIDE
BODY_TOP = SCREEN_H / 2 + BEZEL_TOP
BODY_BOTTOM = -SCREEN_H / 2 - CHIN
BODY_H = BODY_TOP - BODY_BOTTOM
BODY_Z = (BODY_TOP + BODY_BOTTOM) / 2

# The frame: a rounded slab with the screen opening as a shallow recess (the screen panel sits in it).
B.piece("CardioTV_Bezel", BEZEL, lambda bm: H.rounded_box(
    bm, Vector((0, (PANEL_BACK + PANEL_FRONT) / 2, BODY_Z)), Vector((BODY_W, DEPTH, BODY_H)), 0.12, 4))

# The screen: a glossy panel standing just proud of the bezel's front.
B.piece("CardioTV_Screen", SCREEN, lambda bm: H.box(
    bm, Vector((0, PANEL_FRONT - 0.015, 0)), Vector((SCREEN_W, 0.03, SCREEN_H))), smooth=False)

# The back housing: a smaller, deeper rounded block (electronics), only seen from the side.
B.piece("CardioTV_Back", BACK, lambda bm: H.rounded_box(
    bm, Vector((0, PANEL_BACK + 0.12, BODY_Z + 0.2)), Vector((BODY_W * 0.62, 0.24, BODY_H * 0.6)), 0.08, 3))


def mount(bm):
    # A wall plate and two arms reaching the TV's back housing.
    H.rounded_box(bm, Vector((0, -0.03, BODY_Z + 0.2)), Vector((4.6, 0.06, 3.0)), 0.025, 2)
    for x in (-1.6, 1.6):
        H.box(bm, Vector((x, PANEL_BACK / 2, BODY_Z + 0.2)), Vector((0.32, abs(PANEL_BACK) - 0.05, 2.6)))


B.piece("CardioTV_Mount", STEEL, mount, smooth=False)

# The chin's CENTRAL logo, raised from the bezel's front.
CHIN_Z = -SCREEN_H / 2 - CHIN / 2
B.piece("CardioTV_Logo", WHITE, lambda bm: B.add_text(
    bm, "CENTRAL", 0.34, 0.012, H.on_front((0, 0, 0), PANEL_FRONT, CHIN_Z)))

# The power light, at the chin's right.
B.piece("CardioTV_PowerLight", GREEN, lambda bm: H.rounded_box(
    bm, Vector((SCREEN_W / 2 - 0.35, PANEL_FRONT - 0.01, CHIN_Z)), Vector((0.16, 0.03, 0.08)), 0.012, 2))

# The soundbar, under the TV: a rounded body, a grille on its front, end caps and a yellow trim on top.
BAR_W, BAR_H, BAR_D = 11.2, 0.62, 0.6
BAR_Z = BODY_BOTTOM - 0.35 - BAR_H / 2
BAR_Y = -BAR_D / 2 - 0.02
B.piece("CardioTV_Soundbar", BEZEL, lambda bm: H.rounded_box(
    bm, Vector((0, BAR_Y, BAR_Z)), Vector((BAR_W, BAR_D, BAR_H)), 0.2, 5))
B.piece("CardioTV_SoundbarGrille", GRILLE, lambda bm: H.rounded_box(
    bm, Vector((0, BAR_Y - BAR_D / 2 + 0.01, BAR_Z - 0.02)), Vector((BAR_W - 1.0, 0.04, BAR_H - 0.22)), 0.015, 2))
B.piece("CardioTV_SoundbarTrim", YELLOW, lambda bm: H.box(
    bm, Vector((0, BAR_Y - BAR_D / 2 + 0.03, BAR_Z + BAR_H / 2 - 0.09)), Vector((BAR_W - 1.0, 0.06, 0.05))), smooth=False)


def caps(bm):
    for x in (-BAR_W / 2 + 0.25, BAR_W / 2 - 0.25):
        H.cylinder(bm, Vector((x, BAR_Y - BAR_D / 2 + 0.01, BAR_Z)), 0.16, 0.04, axis="Y", segments=20)


B.piece("CardioTV_SoundbarCaps", STEEL, caps)
B.piece("CardioTV_SoundbarLogo", WHITE, lambda bm: B.add_text(
    bm, "CENTRAL", 0.2, 0.008, H.on_front((0, 0, 0), BAR_Y - BAR_D / 2 - 0.01, BAR_Z - 0.02)))

# The soundbar's two wall brackets.
def brackets(bm):
    for x in (-3.0, 3.0):
        H.box(bm, Vector((x, -0.04, BAR_Z)), Vector((0.5, 0.08, BAR_H * 0.8)))


B.piece("CardioTV_SoundbarBrackets", STEEL, brackets, smooth=False)

print("CardioTV_01 built:", sorted(o.name for o in B.coll.objects))
