# Builds Doors_01 in the live Blender scene: the doors' block-built pieces and the hall-front name plaques
# (blocks to Blender, batch 3; user 2026-10-28: "everything still made with blocks change into models through
# blender ... optimized"). Low detail; the game colours the door pieces with each door's own looks and stretches
# the leaves and frames to each door's size.
#
#   DoorLeaf        a solid swing-door leaf with a raised panel on each face and a kick plate (Leaf, Kick).
#   DoorLeafGlazed  a swing-door leaf with a window (the sauna's): stiles and rails, glass, kick plate.
#   DoorHandle      a pair of vertical pull bars, one on each face, on stand-offs.
#   NamePlaque      the hall-front name plaque: steel back plate on four stand-offs with a steel strip, and
#                   the black face the game writes the room's name on.
#   SlideDoorFrame  the aluminium frame round each sliding glass panel (the glass stays the game's own pane).
#   DoorSensor      the sliding doors' sensor box with its lamp (the game renames the lamp "SensorLamp").
#   DoorSign        the small name sign over a swing door.
#
# Units, axes and names as in prop_helpers.py (1 unit = 1 stud, z up, front -Y). Sizes are the game's
# (StarterGymConfig.SwingDoors / ClosedRoomDoor / NamePlaque, DoorFrameStuds 0.25, panel 0.3 thick).
# Run in an otherwise empty file (art/blender/Doors_01.blend):
#   exec(compile(open(path).read(), path, "exec"), {"__file__": path, "__name__": "__main__"})

import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

B = H.Builder("Doors_01")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.5, alpha=1.0, emission=None):
    return H.material("DR_" + name, tuple(linear(c) for c in rgb), metallic, roughness, alpha, emission)


LEAF = mat("Leaf", (96, 110, 150), 0.0, 0.6)
STEEL = mat("Steel", (190, 192, 198), 1.0, 0.3)
BLACK = mat("Black", (22, 22, 24), 0.0, 0.5)
GLASS = mat("Glass", (200, 140, 90), 0.0, 0.1, 0.5)
ALU = mat("Alu", (160, 164, 170), 1.0, 0.35)
RED = mat("Lamp", (230, 40, 40), 0.0, 0.3, emission=(1.0, 0.1, 0.1))
WOOD = mat("Wood", (178, 126, 78), 0.0, 0.6)

T = 0.25  # leaf thickness

# ------------------------------------------------------------------ DoorLeaf (x = 0)
# A closed room's door leaf: 5.16 wide, 8.53 tall.
LW, LH = 5.16, 8.53


def leaf(bm):
    H.rounded_box(bm, Vector((0, 0, LH / 2)), Vector((LW, T, LH)), 0.03, 1)
    for y in (-T / 2 - 0.01, T / 2 + 0.01):
        for z, h in ((5.6, 4.6), (2.1, 1.6)):
            H.box(bm, Vector((0, y, z)), Vector((LW - 1.4, 0.04, h)))


def kick(width, x0=0.0):
    def build(bm):
        for y in (-T / 2 - 0.015, T / 2 + 0.015):
            H.box(bm, Vector((x0, y, 0.35)), Vector((width - 0.2, 0.03, 0.6)))
    return build


B.piece("DoorLeaf_Leaf", LEAF, leaf, smooth=False)
B.piece("DoorLeaf_Kick", STEEL, kick(LW), smooth=False)

# ------------------------------------------------------------------ DoorLeafGlazed (x = 8)
# The sauna's leaves: 3.66 wide, 8.93 tall, 0.6 stiles, a window from 4.9 to 7.78 up.
GX, GW, GH = 8.0, 3.66, 8.93
WIN_LO, WIN_HI = 4.9, 7.78


def glazed(bm):
    for x in (-GW / 2 + 0.3, GW / 2 - 0.3):
        H.box(bm, Vector((GX + x, 0, GH / 2)), Vector((0.6, T, GH)))
    H.box(bm, Vector((GX, 0, WIN_LO / 2)), Vector((GW - 1.2, T, WIN_LO)))
    H.box(bm, Vector((GX, 0, (WIN_HI + GH) / 2)), Vector((GW - 1.2, T, GH - WIN_HI)))


B.piece("DoorLeafGlazed_Leaf", WOOD, glazed, smooth=False)
B.piece("DoorLeafGlazed_Glass", GLASS, lambda bm: H.box(
    bm, Vector((GX, 0, (WIN_LO + WIN_HI) / 2)), Vector((GW - 1.2, 0.08, WIN_HI - WIN_LO))), smooth=False)
B.piece("DoorLeafGlazed_Kick", STEEL, kick(GW, GX), smooth=False)

# ------------------------------------------------------------------ DoorHandle (x = 12)
# Old blocks: 0.15 x 2 bars sticking 0.3 out of each face.
HX = 12.0


def handles(bm):
    for side in (-1, 1):
        H.cylinder(bm, Vector((HX, side * (T / 2 + 0.28), 1.0)), 0.06, 2.0, segments=8)
        for z in (0.2, 1.8):
            H.cylinder(bm, Vector((HX, side * (T / 2 + 0.14), z)), 0.035, 0.28, axis="Y", segments=6)


B.piece("DoorHandle_Bar", STEEL, handles)

# ------------------------------------------------------------------ NamePlaque (x = 15)
# 2.0 x 1.4, its back plate 0.24 off the wall (the wall is y = 0, the front -Y).
NX, NW, NH, OFF = 15.0, 2.0, 1.4, 0.24


def plaque_steel(bm):
    for x, z in ((-NW / 2 + 0.26, 0.26), (NW / 2 - 0.26, 0.26), (-NW / 2 + 0.26, NH - 0.26), (NW / 2 - 0.26, NH - 0.26)):
        H.cylinder(bm, Vector((NX + x, -OFF / 2, z)), 0.06, OFF, axis="Y", segments=8)
    H.rounded_box(bm, Vector((NX, -OFF - 0.03, NH / 2)), Vector((NW, 0.06, NH)), 0.025, 1)
    H.box(bm, Vector((NX, -OFF - 0.125, NH - 0.4)), Vector((NW - 0.24, 0.01, 0.04)))


B.piece("NamePlaque_Steel", STEEL, plaque_steel)
B.piece("NamePlaque_Face", BLACK, lambda bm: H.box(
    bm, Vector((NX, -OFF - 0.09, NH / 2)), Vector((NW - 0.24, 0.06, NH - 0.24))), smooth=False)

# ------------------------------------------------------------------ SlideDoorFrame (x = 19)
# Reference panel 4 wide, 9 tall, the frame 0.25 wide and 0.34 deep (panel 0.3 + 0.02 each side).
SX, SW, SH, SD, FB = 19.0, 4.0, 9.0, 0.34, 0.25


def slide_frame(bm):
    for z in (FB / 2, SH - FB / 2):
        H.box(bm, Vector((SX, 0, z)), Vector((SW, SD, FB)))
    for x in (-SW / 2 + FB / 2, SW / 2 - FB / 2):
        H.box(bm, Vector((SX + x, 0, SH / 2)), Vector((FB, SD, SH - 2 * FB)))


B.piece("SlideDoorFrame_Frame", ALU, slide_frame, smooth=False)

# ------------------------------------------------------------------ DoorSensor (x = 23)
# Old blocks: a 1.2 x 0.3 box 0.35 deep and a small lamp under it.
DX = 23.0
B.piece("DoorSensor_Box", BLACK, lambda bm: H.rounded_box(bm, Vector((DX, 0, 0.19)), Vector((1.2, 0.35, 0.3)), 0.04, 2))
B.piece("DoorSensor_Lamp", RED, lambda bm: H.rounded_box(bm, Vector((DX, 0, 0.025)), Vector((0.24, 0.12, 0.05)), 0.015, 1))

# ------------------------------------------------------------------ DoorSign (x = 26)
# Old block: 2.4 x 0.7, 0.05 thick, over a swing door.
B.piece("DoorSign_Plate", BLACK, lambda bm: H.rounded_box(bm, Vector((26.0, 0, 0.35)), Vector((2.4, 0.05, 0.7)), 0.06, 2))

print("Doors_01 built:", sorted(o.name for o in B.coll.objects))
