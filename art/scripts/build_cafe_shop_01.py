# Builds CafeShop_01 in the live Blender scene: the block-built furniture of the Cafe, the Supplement Bar and the
# Shop (blocks to Blender, batch 5; user 2026-10-28: "everything still made with blocks change into models through
# blender ... If its a micro model/detail it does not have to be SUPER detailed because i want to make sure
# everything is optimized"). Low detail on purpose: one piece per colour, one mesh reused for every copy.
#
#   CounterUnit    a bar counter: body with a recessed kick and a top overhanging the front and ends; stretched
#                  to every counter and back bar, painted with the room's looks (tiles, planks, marble).
#   WallShelf      a floating wall shelf: a board on two L brackets; stretched (cafe and bar shelves, shop ledges).
#   Till           a till: base with a receipt printer, the screen on a short neck at the back.
#   RoundTable     a round café table: disc top on a pole and a round foot (stretched for the low spa tables).
#   HighTable      a square high table on a pole and a square foot.
#   WindowBar      the cafe's window bar: a 15.5-long top on three posts with feet.
#   Blender        the supplement bar's blender: a base with a dial, a glass jug and its lid.
#   DrinksFridge   the see-through drinks fridge: steel body, glass door and shelves, a top light, rows of bottles.
#   SBarCounter    the supplement bar's serving counter: plinth, planked body with front slats, marble top,
#                  steel foot rail on brackets.
#   Slatwall       the shop's slatwall with its steel grooves and six hooks.
#   Podium         the shop's mannequin podium with a red glow line.
#   TeeStack       three folded tees (each its own piece, so every stack can mix colours).
#   DisplayTable   the shop's tee table: a top on four legs with an apron, red lines along the top.
#   ShopCounterTop the shop counter's top with its red front edge (the counter body with the logo stays a block).
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, items stand on z = 0 with their front toward
# -Y; wall items have the wall at y = 0. Sizes are the old blocks' (RoomProps Cafe / SupplementBar / Shop).
# Run in an otherwise empty file (art/blender/CafeShop_01.blend):
#   exec(compile(open(path).read(), path, "exec"), {"__file__": path, "__name__": "__main__"})
# Objects are replaced by name on every run.

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

B = H.Builder("CafeShop_01")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.5, alpha=1.0, emission=None):
    return H.material("CS_" + name, tuple(linear(c) for c in rgb), metallic, roughness, alpha, emission)


# Preview colours (Roblox paints each piece with the room's looks or StarterGymConfig.PropColourways).
TILES = mat("Tiles", (60, 130, 100), 0.0, 0.4)
MARBLE = mat("Marble", (235, 235, 230), 0.0, 0.2)
PLANKS = mat("Planks", (92, 62, 40), 0.0, 0.7)
OAK = mat("Oak", (198, 152, 102), 0.0, 0.6)
BLACK = mat("Black", (22, 22, 24), 0.0, 0.5)
DARK = mat("Dark", (28, 28, 30), 0.0, 0.5)
NAVY = mat("Navy", (30, 48, 98), 0.0, 0.3)
STEEL = mat("Silver", (190, 192, 198), 1.0, 0.3)
GLASS = mat("Glass", (205, 225, 235), 0.0, 0.05, 0.35)
GLOW = mat("GlowWhite", (255, 250, 240), 0.0, 0.3, emission=(1.0, 0.98, 0.94))
RED_GLOW = mat("GlowRed", (230, 40, 40), 0.0, 0.3, emission=(1.0, 0.1, 0.1))
RED = mat("Red", (200, 30, 38), 0.0, 0.6)
WHITE = mat("White", (236, 236, 232), 0.0, 0.6)
BLUE = mat("Blue", (30, 92, 205), 0.0, 0.4)
GREEN = mat("Green", (95, 222, 60), 0.0, 0.4)
YELLOW = mat("Yellow", (242, 190, 30), 0.0, 0.4)

# ------------------------------------------------------------------ CounterUnit (x = 0)
# Reference 10 long, 2.2 deep, 3.6 tall: the top (0.2) overhangs the front by 0.15 and the ends by 0.1; the
# kick (0.3) is set back 0.1.
CL, CD, CH = 10.0, 2.2, 3.6


def counter_body(bm):
    H.rounded_box(bm, Vector((0, (-CD / 2 + 0.15 + CD / 2) / 2, (0.3 + CH - 0.2) / 2)),
                  Vector((CL - 0.2, CD - 0.15, CH - 0.5)), 0.03, 1)
    H.box(bm, Vector((0, (-CD / 2 + 0.25 + CD / 2) / 2, 0.15)), Vector((CL - 0.4, CD - 0.25, 0.3)))


B.piece("CounterUnit_Body", TILES, counter_body, smooth=False)
B.piece("CounterUnit_Top", MARBLE, lambda bm: H.rounded_box(bm, Vector((0, 0, CH - 0.1)), Vector((CL, CD, 0.2)), 0.04, 2))

# ------------------------------------------------------------------ WallShelf (x = 14)
# Reference 10 long, 0.92 deep (the wall at y = 0), the 0.15 board on two brackets reaching 0.5 under it.
SX, SL, SD = 14.0, 10.0, 0.92
B.piece("WallShelf_Board", OAK, lambda bm: H.rounded_box(
    bm, Vector((SX, -SD / 2, 0.575)), Vector((SL, SD, 0.15)), 0.03, 1))


def shelf_brackets(bm):
    for x in (-0.35 * SL, 0.35 * SL):
        H.box(bm, Vector((SX + x, -0.03, 0.25)), Vector((0.08, 0.06, 0.5)))
        H.box(bm, Vector((SX + x, -SD * 0.4, 0.47)), Vector((0.08, SD * 0.8, 0.06)))


B.piece("WallShelf_Brackets", BLACK, shelf_brackets, smooth=False)

# ------------------------------------------------------------------ Till (x = 28)
# 1.0 wide, 0.6 deep base; the screen at the back (+Y), facing the front.
TX = 28.0


def till_body(bm):
    H.rounded_box(bm, Vector((TX, 0, 0.06)), Vector((1.0, 0.6, 0.12)), 0.02, 1)
    H.rounded_box(bm, Vector((TX + 0.3, -0.1, 0.17)), Vector((0.3, 0.3, 0.1)), 0.02, 1)
    H.box(bm, Vector((TX - 0.1, 0.2, 0.3)), Vector((0.12, 0.08, 0.36)))
    tilt = Matrix.Rotation(math.radians(-12), 4, "X")
    H.rounded_box(bm, Vector((TX - 0.1, 0.22, 0.72)), Vector((0.66, 0.08, 0.5)), 0.02, 1, rotation=tilt)


B.piece("Till_Body", BLACK, till_body)
B.piece("Till_Screen", NAVY, lambda bm: H.box(
    bm, Vector((TX - 0.1, 0.22, 0.72)) + Matrix.Rotation(math.radians(-12), 4, "X") @ Vector((0, -0.045, 0)),
    Vector((0.56, 0.01, 0.4)), Matrix.Rotation(math.radians(-12), 4, "X")), smooth=False)

# ------------------------------------------------------------------ RoundTable (x = 32)
# A 2.8 disc top, 3.06 tall (the game stretches it to the room's height).
RX = 32.0
B.piece("RoundTable_Top", MARBLE, lambda bm: H.cylinder(bm, Vector((RX, 0, 2.98)), 1.4, 0.16, segments=24))


def round_stand(bm):
    H.cylinder(bm, Vector((RX, 0, 1.5)), 0.12, 2.8, segments=10)
    H.cylinder(bm, Vector((RX, 0, 0.05)), 0.6, 0.1, segments=16)
    H.cylinder(bm, Vector((RX, 0, 2.86)), 0.35, 0.08, segments=12)


B.piece("RoundTable_Stand", BLACK, round_stand)

# ------------------------------------------------------------------ HighTable (x = 36)
HX = 36.0
B.piece("HighTable_Top", MARBLE, lambda bm: H.rounded_box(bm, Vector((HX, 0, 3.075)), Vector((2.6, 2.6, 0.15)), 0.04, 2))


def high_stand(bm):
    H.cylinder(bm, Vector((HX, 0, 1.55)), 0.14, 2.9, segments=10)
    H.rounded_box(bm, Vector((HX, 0, 0.05)), Vector((1.4, 1.4, 0.1)), 0.03, 1)
    H.box(bm, Vector((HX, 0, 2.96)), Vector((0.8, 0.8, 0.08)))


B.piece("HighTable_Stand", STEEL, high_stand)

# ------------------------------------------------------------------ WindowBar (x = 50)
# 15.5 long, 1.3 deep, its top 3.54-3.79 up (the room's floor is 0.06 above the room's base); three posts.
WX = 50.0
B.piece("WindowBar_Top", MARBLE, lambda bm: H.rounded_box(bm, Vector((WX, 0, 3.665)), Vector((15.5, 1.3, 0.25)), 0.04, 2))


def window_legs(bm):
    for x in (-7.05, 0.0, 7.05):
        H.box(bm, Vector((WX + x, 0, 1.77)), Vector((0.2, 0.2, 3.54)))
        H.box(bm, Vector((WX + x, 0, 0.02)), Vector((0.6, 0.6, 0.04)))


B.piece("WindowBar_Legs", BLACK, window_legs, smooth=False)

# ------------------------------------------------------------------ Blender (x = 62)
# On the back bar: a 1.2 base 0.6 tall, a 0.8 glass jug 1.5 tall, the lid.
BX = 62.0


def blender_body(bm):
    H.rounded_box(bm, Vector((BX, 0, 0.3)), Vector((1.1, 1.1, 0.6)), 0.08, 2)
    H.cylinder(bm, Vector((BX, -0.56, 0.3)), 0.12, 0.06, axis="Y", segments=10)
    H.cylinder(bm, Vector((BX, 0, 2.17)), 0.43, 0.14, segments=14)


B.piece("Blender_Body", BLACK, blender_body)
B.piece("Blender_Jug", GLASS, lambda bm: H.cylinder(bm, Vector((BX, 0, 1.35)), 0.34, 1.5, segments=14, radius2=0.4))

# ------------------------------------------------------------------ DrinksFridge (x = 70)
# 4.48 wide (the Supplement Bar's), 2.2 deep plus the door and handle, 7.5 tall; the wall at y = 0. Five bottles
# on each of four levels, coloured blue, red, green, yellow along the rows.
FX, FW, FD, FH = 70.0, 4.48, 2.2, 7.5
F0 = FX - FW / 2


def fridge_body(bm):
    H.box(bm, Vector((FX, -0.1, FH / 2)), Vector((FW, 0.2, FH)))
    for x in (F0 + 0.1, F0 + FW - 0.1):
        H.box(bm, Vector((x, -(0.2 + FD) / 2, FH / 2)), Vector((0.2, FD - 0.2, FH)))
    H.box(bm, Vector((FX, -(0.2 + FD) / 2, FH - 0.15)), Vector((FW - 0.4, FD - 0.2, 0.3)))
    H.box(bm, Vector((FX, -(0.2 + FD) / 2, 0.25)), Vector((FW - 0.4, FD - 0.2, 0.5)))
    H.rounded_box(bm, Vector((F0 + FW - 0.525, -(FD + 0.175), 3.75)), Vector((0.15, 0.15, 2.5)), 0.04, 1)


def fridge_glass(bm):
    H.box(bm, Vector((FX, -(FD + 0.05), (0.5 + FH - 0.3) / 2)), Vector((FW - 0.4, 0.1, FH - 0.8)))
    for level in (1, 2, 3):
        y = 0.5 + level * 1.7
        H.box(bm, Vector((FX, -(0.2 + FD - 0.1) / 2, y - 0.03)), Vector((FW - 0.4, FD - 0.3, 0.06)))


BOTTLE = [(0.0, 0.0), (0.2, 0.0), (0.21, 0.7), (0.12, 0.9), (0.08, 0.98), (0.09, 1.0), (0.09, 1.16), (0.0, 1.16)]


def fridge_bottles(colour):
    def build(bm):
        count = int((FW - 0.6) / 0.7)
        for level in range(4):
            y = 0.5 + level * 1.7
            for index in range(count):
                if (level + index) % 4 == colour:
                    H.lathe_z(bm, BOTTLE, 8, Vector((F0 + 0.6 + index * 0.7, -1.2, y + 0.02)))
    return build


B.piece("DrinksFridge_Body", STEEL, fridge_body, smooth=False)
B.piece("DrinksFridge_Glass", GLASS, fridge_glass, smooth=False)
B.piece("DrinksFridge_Glow", GLOW, lambda bm: H.box(
    bm, Vector((FX, -0.45, FH - 0.375)), Vector((FW - 0.6, 0.3, 0.15))), smooth=False)
B.piece("DrinksFridge_BottleA", BLUE, fridge_bottles(0))
B.piece("DrinksFridge_BottleB", RED, fridge_bottles(1))
B.piece("DrinksFridge_BottleC", GREEN, fridge_bottles(2))
B.piece("DrinksFridge_BottleD", YELLOW, fridge_bottles(3))

# ------------------------------------------------------------------ SBarCounter (x = 90)
# The old blocks along the bar's back wall: s from -10.3 to 8.3 (x = s + 1 here), t out from the wall
# (y = 6.565 - t: the customers' side, larger t, is the front -Y), y from the room floor (z = y - 0.06).
QX = 90.0


def q(s, t, y):
    return Vector((QX + s + 1, 6.565 - t, y - 0.06))


def q_box(bm, s0, s1, t0, t1, y0, y1, bevel=0.0):
    centre = (q(s0, t0, y0) + q(s1, t1, y1)) / 2
    size = Vector((s1 - s0, t1 - t0, y1 - y0))
    if bevel:
        H.rounded_box(bm, centre, size, bevel, 1)
    else:
        H.box(bm, centre, size)


B.piece("SBarCounter_Plinth", BLACK, lambda bm: q_box(bm, -9.8, 7.8, 5.6, 6.7, 0.06, 0.4), smooth=False)


def sbar_body(bm):
    q_box(bm, -10, 8, 5.5, 6.95, 0.4, 3.6)
    s = -9.85
    while s + 0.3 <= 7.9:
        q_box(bm, s, s + 0.3, 6.95, 7.07, 0.45, 3.55)
        s += 0.45


B.piece("SBarCounter_Body", PLANKS, sbar_body, smooth=False)
B.piece("SBarCounter_Top", BLACK, lambda bm: q_box(bm, -10.3, 8.3, 5.3, 7.45, 3.6, 3.85, 0.04))


def sbar_rail(bm):
    H.cylinder(bm, q(-1, 7.75, 0.9), 0.08, 17.6, axis="X", segments=10)
    for s in (-9, -1, 7):
        q_box(bm, s - 0.06, s + 0.06, 7.07, 7.75, 0.84, 0.96)


B.piece("SBarCounter_Rail", STEEL, sbar_rail)

# ------------------------------------------------------------------ Slatwall (x = 112)
# The shop's left wall from s 6 to 24 (x = s - 15 here), 0.5 to 9.5 up; the panel 0.15-0.35 off the wall.
WLX = 112.0
B.piece("Slatwall_Panel", DARK, lambda bm: H.box(bm, Vector((WLX, -0.25, 5.0)), Vector((18.0, 0.2, 9.0))), smooth=False)


def slatwall_metal(bm):
    for k in range(15):
        H.box(bm, Vector((WLX, -0.36, 0.83 + k * 0.6)), Vector((18.0, 0.02, 0.06)))
    for index in range(6):
        x = WLX + 8 + index * 2.8 - 15
        H.cylinder(bm, Vector((x, -0.66, 8.45)), 0.04, 0.58, axis="Y", segments=6)
        H.cylinder(bm, Vector((x, -0.93, 8.52)), 0.04, 0.14, segments=6)


B.piece("Slatwall_Metal", STEEL, slatwall_metal)

# ------------------------------------------------------------------ Podium (x = 135)
# 15 wide, 4.5 deep, 0.3 tall; the red line on the front, 0.08-0.2 up.
PX = 135.0
B.piece("Podium_Base", BLACK, lambda bm: H.rounded_box(bm, Vector((PX, 0, 0.15)), Vector((15.0, 4.5, 0.3)), 0.03, 1))
B.piece("Podium_Glow", RED_GLOW, lambda bm: H.box(bm, Vector((PX, -2.28, 0.14)), Vector((15.0, 0.06, 0.12))), smooth=False)

# ------------------------------------------------------------------ TeeStack (x = 146)
# Three folded tees, 1.4 wide, 1.2 deep, 0.25 apart.
TSX = 146.0


def tee(fold):
    def build(bm):
        H.rounded_box(bm, Vector((TSX, 0, 0.115 + fold * 0.25)), Vector((1.4, 1.2, 0.23)), 0.06, 1)
        H.box(bm, Vector((TSX, 0.45, 0.235 + fold * 0.25)), Vector((0.4, 0.12, 0.02)))
    return build


B.piece("TeeStack_TeeA", BLACK, tee(0))
B.piece("TeeStack_TeeB", RED, tee(1))
B.piece("TeeStack_TeeC", WHITE, tee(2))

# ------------------------------------------------------------------ DisplayTable (x = 152)
# 5.5 wide, 3 deep, 2.6 tall.
DX = 152.0


def display_body(bm):
    H.rounded_box(bm, Vector((DX, 0, 2.5)), Vector((5.5, 3.0, 0.2)), 0.03, 1)
    for x in (-2.55, 2.55):
        for y in (-1.3, 1.3):
            H.box(bm, Vector((DX + x, y, 1.2)), Vector((0.25, 0.25, 2.4)))
    for y in (-1.3, 1.3):
        H.box(bm, Vector((DX, y, 2.25)), Vector((4.85, 0.1, 0.3)))
    for x in (-2.55, 2.55):
        H.box(bm, Vector((DX + x, 0, 2.25)), Vector((0.1, 2.35, 0.3)))


B.piece("DisplayTable_Body", DARK, display_body, smooth=False)


def display_edge(bm):
    for y in (-1.505, 1.505):
        H.box(bm, Vector((DX, y, 2.5)), Vector((5.3, 0.01, 0.05)))


B.piece("DisplayTable_Edge", RED_GLOW, display_edge, smooth=False)

# ------------------------------------------------------------------ ShopCounterTop (x = 160)
# 6.7 wide, 2.2 deep, 0.2 thick, with the red edge on its front.
KX = 160.0
B.piece("ShopCounterTop_Top", BLACK, lambda bm: H.box(bm, Vector((KX, 0.03, 0.1)), Vector((6.7, 2.2, 0.2))), smooth=False)
B.piece("ShopCounterTop_Edge", RED_GLOW, lambda bm: H.box(bm, Vector((KX, -1.1, 0.1)), Vector((6.7, 0.06, 0.2))), smooth=False)

print("CafeShop_01 built:", sorted(o.name for o in B.coll.objects))
