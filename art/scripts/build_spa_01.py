# Builds Spa_01 in the live Blender scene: the block-built pieces of the spa wing (Sauna, Showers, Recovery)
# that no earlier model covers (blocks to Blender, batch 6; user 2026-10-28: "everything still made with blocks
# change into models through blender ... If its a micro model/detail it does not have to be SUPER detailed because
# i want to make sure everything is optimized"). The spa's desk, shelves, low tables, bench and towels reuse the
# CafeShop_01 / Furniture_01 / Showers models, so few new meshes are added (the game's unique-mesh budget).
#
#   SaunaBench     two tiers of benches with a backrest (base boards and slats); stretched along each wall.
#   Duckboard      six floor slats (the sauna's, and stretched for every shower stall).
#   SaunaHeater    the stove, its stone basket with a glow, the steel heat shield and rims, the wooden guard.
#   SaunaLamp      a slatted wooden wall lamp round a warm glow.
#   SaunaBucket    the wooden bucket with a steel band and a ladle.
#   Thermometer    the round wall thermometer: wooden rim, white face, red needle.
#   ShowerScreen   a stall's glass screen in its black frame.
#   WallLadder     the oak stretching ladder (two rails, sixteen rungs).
#   PlungeStep     the two-tread oak step in front of a cold plunge.
#   FloorMat       a stretching mat (the game paints each one its colour).
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, items stand on z = 0 with their front toward -Y;
# wall items have the wall at y = 0 (y = -t, t the old blocks' distance from the wall). Sizes are the old blocks'
# (RoomProps Sauna / Showers / Recovery). Run in an otherwise empty file (art/blender/Spa_01.blend):
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

B = H.Builder("Spa_01")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.5, alpha=1.0, emission=None):
    return H.material("SP_" + name, tuple(linear(c) for c in rgb), metallic, roughness, alpha, emission)


# Preview colours (Roblox paints the pieces with the rooms' looks or StarterGymConfig.PropColourways).
BOARD = mat("SaunaWood", (150, 100, 60), 0.0, 0.7)
SLAT = mat("SaunaBench", (196, 150, 100), 0.0, 0.6)
OAK = mat("Oak", (198, 152, 102), 0.0, 0.6)
DARK = mat("Black", (22, 22, 24), 0.0, 0.5)
STEEL = mat("Silver", (190, 192, 198), 1.0, 0.3)
STONE = mat("Stone", (110, 110, 112), 0.0, 0.9)
WARM = mat("WarmGlow", (255, 205, 150), 0.0, 0.3, emission=(1.0, 0.75, 0.5))
WHITE = mat("White", (236, 236, 232), 0.0, 0.5)
RED = mat("Red", (200, 30, 38), 0.0, 0.5)
GLASS = mat("Glass", (205, 225, 235), 0.0, 0.05, 0.35)
TEAL = mat("Teal", (0, 138, 140), 0.0, 0.8)


def wall_box(bm, x0, s0, s1, t0, t1, y0, y1, bevel=0.0, base=0.0):
    """A box given like the old wall blocks: s along the wall (x = x0 + s), t out from it (y = -t), y up
    (z = y - base)."""
    centre = Vector((x0 + (s0 + s1) / 2, -(t0 + t1) / 2, (y0 + y1) / 2 - base))
    size = Vector((s1 - s0, t1 - t0, y1 - y0))
    if bevel:
        H.rounded_box(bm, centre, size, bevel, 1)
    else:
        H.box(bm, centre, size)


# ------------------------------------------------------------------ SaunaBench (x = 0)
# Reference 12 long (s -6..6); t 0.15..5.66 out from the wall; y 0.1 (the sauna floor) to 5.95.
BL = 6.0


def bench_base(bm):
    wall_box(bm, 0, -BL, BL, 0.15, 3.2, 0.1, 3, base=0.1)
    wall_box(bm, 0, -BL, BL, 3.2, 5.6, 0.1, 1.5, base=0.1)


def bench_slats(bm):
    for k in range(6):
        t0 = 0.25 + k * 0.5
        wall_box(bm, 0, -BL, BL, t0, t0 + 0.42, 3, 3.15, 0.02, base=0.1)
    wall_box(bm, 0, -BL, BL, 3.2, 3.26, 1.8, 2.3, base=0.1)
    for k in range(4):
        t0 = 3.3 + k * 0.58
        wall_box(bm, 0, -BL, BL, t0, t0 + 0.5, 1.5, 1.65, 0.02, base=0.1)
    for y0, y1 in ((0.3, 0.7), (0.85, 1.25)):
        wall_box(bm, 0, -BL, BL, 5.6, 5.66, y0, y1, base=0.1)
    for y in (4, 4.8, 5.6):
        wall_box(bm, 0, -BL + 0.35, BL - 0.35, 0.15, 0.4, y, y + 0.35, 0.02, base=0.1)


B.piece("SaunaBench_Base", BOARD, bench_base, smooth=False)
B.piece("SaunaBench_Slats", SLAT, bench_slats, smooth=False)

# ------------------------------------------------------------------ Duckboard (x = 20)
# Six 12-long slats 0.45 wide, 0.55 apart (t 5.9..9.1 in the sauna), 0.12 tall.


def duckboard(bm):
    for k in range(6):
        t0 = 5.9 + k * 0.55
        wall_box(bm, 20, -6, 6, t0, t0 + 0.45, 0.1, 0.22, 0.02, base=0.1)


B.piece("Duckboard_Slats", SLAT, duckboard, smooth=False)

# ------------------------------------------------------------------ SaunaHeater (x = 30)
# Along the left wall from s 0.7 to 4.2 (x = 30 + s - 2.45); the stove s 1.2..3.7, t 0.6..3.
HX = 30.0 - 2.45
h0, h1, g0, g1, gt = 1.2, 3.7, 0.8, 4.1, 3.5

B.piece("SaunaHeater_Stove", DARK, lambda bm: wall_box(bm, HX, h0, h1, 0.6, 3, 0.1, 2.6, 0.06, base=0.1))


def heater_metal(bm):
    wall_box(bm, HX, h0 - 0.5, h1 + 0.5, 0.15, 0.22, 0.6, 6, base=0.1)
    for s0, s1, t0, t1 in ((h0, h0 + 0.1, 0.6, 3), (h1 - 0.1, h1, 0.6, 3), (h0 + 0.1, h1 - 0.1, 0.6, 0.7),
                           (h0 + 0.1, h1 - 0.1, 2.9, 3)):
        wall_box(bm, HX, s0, s1, t0, t1, 2.6, 3.3, base=0.1)


B.piece("SaunaHeater_Metal", STEEL, heater_metal, smooth=False)
B.piece("SaunaHeater_Glow", WARM, lambda bm: wall_box(bm, HX, h0 + 0.2, h1 - 0.2, 0.8, 2.8, 2.6, 2.7, base=0.1),
        smooth=False)


def heater_stones(bm):
    for i in range(4):
        for j in range(4):
            squash = (1.0, 0.9 + 0.1 * ((i + j) % 2), 0.75)
            H.sphere(bm, Vector((HX + h0 + 0.35 + i * 0.6, -(0.95 + j * 0.6), 2.95 - 0.1)), 0.3, scale=squash,
                     segments=7, rings=4)
    for i in range(3):
        for j in range(3):
            H.sphere(bm, Vector((HX + h0 + 0.65 + i * 0.6, -(1.25 + j * 0.6), 3.4 - 0.1)), 0.275, scale=(1, 0.95, 0.8),
                     segments=7, rings=4)


B.piece("SaunaHeater_Stones", STONE, heater_stones)


def heater_guard(bm):
    for s in (g0, g1):
        wall_box(bm, HX, s - 0.08, s + 0.08, gt - 0.08, gt + 0.08, 0.1, 3.6, 0.02, base=0.1)
    for y in (1.6, 3.4):
        wall_box(bm, HX, g0, g1, gt - 0.05, gt + 0.05, y, y + 0.2, base=0.1)
        for s in (g0, g1):
            wall_box(bm, HX, s - 0.05, s + 0.05, 0.15, gt - 0.08, y, y + 0.2, base=0.1)


B.piece("SaunaHeater_Guard", SLAT, heater_guard, smooth=False)

# ------------------------------------------------------------------ SaunaLamp (x = 40)
# On the back wall, s -0.9..0.9, t 0.15..0.75, y 6.85..8.95.
LX = 40.0


def lamp_frame(bm):
    for y0, y1 in ((8.8, 8.95), (6.85, 7.0)):
        wall_box(bm, LX, -0.9, 0.9, 0.15, 0.75, y0, y1, 0.02, base=6.85)
    for k in range(4):
        s0 = -0.8 + k * 0.45
        wall_box(bm, LX, s0, s0 + 0.15, 0.6, 0.72, 7, 8.8, base=6.85)
    for s0 in (-0.85, 0.7):
        wall_box(bm, LX, s0, s0 + 0.15, 0.25, 0.6, 7, 8.8, base=6.85)


B.piece("SaunaLamp_Frame", SLAT, lamp_frame, smooth=False)
B.piece("SaunaLamp_Glow", WARM, lambda bm: wall_box(bm, LX, -0.7, 0.7, 0.15, 0.5, 7.2, 8.6, base=6.85), smooth=False)

# ------------------------------------------------------------------ SaunaBucket (x = 44)
# A 1.0 bucket 0.9 tall standing on z = 0, the ladle's handle along +X over the rim.
KX = 44.0


def bucket_wood(bm):
    H.cylinder(bm, Vector((KX, 0, 0.45)), 0.47, 0.9, segments=16, radius2=0.5)
    H.cylinder(bm, Vector((KX + 0.5, 0, 0.97)), 0.04, 1.6, axis="X", segments=6)
    H.sphere(bm, Vector((KX - 0.2, 0, 0.8)), 0.175, segments=8, rings=5)


B.piece("SaunaBucket_Wood", SLAT, bucket_wood)
B.piece("SaunaBucket_Band", STEEL, lambda bm: H.cylinder(bm, Vector((KX, 0, 0.25)), 0.5, 0.08, segments=16))

# ------------------------------------------------------------------ Thermometer (x = 48)
# On the back wall: the rim 1.4 across at t 0.15..0.25, the face t 0.25..0.29, the needle to t 0.31; centre 7.6 up.
TX = 48.0
B.piece("Thermometer_Body", SLAT, lambda bm: H.cylinder(bm, Vector((TX, -0.2, 0.7)), 0.7, 0.1, axis="Y", segments=20))
B.piece("Thermometer_Face", WHITE, lambda bm: H.cylinder(bm, Vector((TX, -0.27, 0.7)), 0.525, 0.04, axis="Y",
                                                          segments=20))
B.piece("Thermometer_Needle", RED, lambda bm: H.box(bm, Vector((TX, -0.3, 0.925)), Vector((0.06, 0.02, 0.45))),
        smooth=False)

# ------------------------------------------------------------------ ShowerScreen (x = 52)
# On the back wall, s 0.1..2.5 (the frame's edge at the low end), t 4.88..5.02, y 0.06..7.6.
SX = 52.0
B.piece("ShowerScreen_Glass", GLASS, lambda bm: wall_box(bm, SX, 0.2, 2.5, 4.9, 5.0, 0.06, 7.5, base=0.06), smooth=False)


def screen_frame(bm):
    wall_box(bm, SX, 0.1, 0.2, 4.88, 5.02, 0.06, 7.6, base=0.06)
    wall_box(bm, SX, 0.2, 2.5, 4.88, 5.02, 7.5, 7.6, base=0.06)


B.piece("ShowerScreen_Frame", DARK, screen_frame, smooth=False)

# ------------------------------------------------------------------ WallLadder (x = 58)
# On the left wall: rails at s 0 and 3, t 0.08..0.5, 0.06..9.6 up; sixteen rungs 0.58 apart.
WX = 58.0


def ladder(bm):
    for s in (0.0, 3.0):
        wall_box(bm, WX, s - 0.12, s + 0.12, 0.08, 0.5, 0.06, 9.6, 0.03, base=0.06)
    for rung in range(1, 17):
        H.cylinder(bm, Vector((WX + 1.5, -0.3, rung * 0.58)), 0.11, 2.76, axis="X", segments=8)


B.piece("WallLadder_Wood", OAK, ladder)

# ------------------------------------------------------------------ PlungeStep (x = 64)
# In front of a plunge on the back wall: s -1..1, t 5.3..6.3, 0.06..1 up; the higher tread toward the tub.
PX = 64.0


def plunge_step(bm):
    wall_box(bm, PX, -1, 1, 5.3, 6.3, 0.06, 0.53, 0.04, base=0.06)
    wall_box(bm, PX, -1, 1, 5.3, 5.8, 0.53, 1.0, 0.04, base=0.06)


B.piece("PlungeStep_Wood", OAK, plunge_step, smooth=False)

# ------------------------------------------------------------------ FloorMat (x = 68)
B.piece("FloorMat_Mat", TEAL, lambda bm: H.rounded_box(bm, Vector((68.0, 0, 0.04)), Vector((2.8, 6.5, 0.08)), 0.03, 1))

print("Spa_01 built:", sorted(o.name for o in B.coll.objects))
