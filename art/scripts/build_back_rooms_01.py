# Builds BackRooms_01 in the live Blender scene: the block-built pieces of the Staff Room, Lockers, Office, Coach
# room, Storage, Training Zone and Strongman Shed that no earlier model covers (blocks to Blender, batch 7; user
# 2026-10-28: "everything still made with blocks change into models through blender ... If its a micro
# model/detail it does not have to be SUPER detailed because i want to make sure everything is optimized").
# Few colour pieces per item (the game's unique-mesh budget); the vanity, cubicle seats, staff tables, sink and
# spare boxes reuse earlier models.
#
#   KitchenUnit     a run of cabinets with door fronts, a worktop and handles; stretched (base and wall units).
#   CorkBoard       the staff rota board: wooden frame, cork, notes in two colours (the title stays a sign).
#   HangRail        a clothes rail on two wall brackets; stretched.
#   CoatHook        a wall hook.
#   FilingCabinet   a three-drawer filing cabinet with handles.
#   WallClock       a round wall clock: dark rim and hands, white face (the themed fronts' clocks later too).
#   WhiteboardFrame the steel frame and pen tray round a whiteboard (the board stays the game's writing surface).
#   Laptop          an open laptop.
#   FlatPlate       a bumper plate lying flat (Storage's plate stacks; the game paints each plate's colour).
#   BarStand        Storage's bar holder with five barbells standing in it.
#   FlatBench       the Training Zone's flat bench: pad on a steel frame.
#   ChalkStand      the Strongman Shed's chalk stand with its bowl of chalk.
#   StrongmanRig    the Strongman Shed's steel rig with its pull-up bar.
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, items stand on z = 0 with their front toward -Y;
# wall items have the wall at y = 0 (y = -t, t the old blocks' distance from the wall). Sizes are the old blocks'
# (RoomProps StaffRoom / Lockers / Office / Coach / Storage / TrainingZone / StrongmanShed).
# Run in an otherwise empty file (art/blender/BackRooms_01.blend):
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

B = H.Builder("BackRooms_01")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.5, alpha=1.0, emission=None):
    return H.material("BR_" + name, tuple(linear(c) for c in rgb), metallic, roughness, alpha, emission)


# Preview colours (Roblox paints the pieces with the rooms' looks or StarterGymConfig.PropColourways).
SAGE = mat("Sage", (140, 164, 134), 0.0, 0.6)
OAK = mat("Oak", (198, 152, 102), 0.0, 0.6)
STEEL = mat("Silver", (190, 192, 198), 1.0, 0.3)
DARK_STEEL = mat("Charcoal", (46, 48, 54), 0.6, 0.4)
BLACK = mat("Black", (22, 22, 24), 0.0, 0.5)
WHITE = mat("White", (236, 236, 232), 0.0, 0.5)
CORK = mat("Kraft", (184, 142, 98), 0.0, 0.9)
YELLOW = mat("Yellow", (242, 190, 30), 0.0, 0.6)
MINT = mat("Mint", (172, 218, 196), 0.0, 0.6)
GREY = mat("LightGrey", (176, 180, 186), 0.0, 0.5)
RED = mat("Red", (200, 30, 38), 0.0, 0.6)
BLUE = mat("Blue", (30, 92, 205), 0.0, 0.6)


def wall_box(bm, x0, s0, s1, t0, t1, y0, y1, bevel=0.0, base=0.0, rotation=None):
    """A box given like the old wall blocks: s along the wall (x = x0 + s), t out from it (y = -t), y up
    (z = y - base)."""
    centre = Vector((x0 + (s0 + s1) / 2, -(t0 + t1) / 2, (y0 + y1) / 2 - base))
    size = Vector((s1 - s0, t1 - t0, y1 - y0))
    if bevel:
        H.rounded_box(bm, centre, size, bevel, 1)
    else:
        H.box(bm, centre, size)


# ------------------------------------------------------------------ KitchenUnit (x = 0)
# Reference 10 long (s -5..5), t 0.08..2.4, y 0.06..3.4: cabinets to t 2.2 with six door fronts, the worktop
# 0.2 thick over them, a handle on each door near its top.
KL = 10.0


def kitchen_body(bm):
    wall_box(bm, 0, -KL / 2 + 0.05, KL / 2 - 0.05, 0.08, 2.1, 0.36, 3.2, base=0.06)
    wall_box(bm, 0, -KL / 2 + 0.1, KL / 2 - 0.1, 0.08, 1.95, 0.06, 0.36, base=0.06)
    door = KL / 6
    for k in range(6):
        s0 = -KL / 2 + k * door
        wall_box(bm, 0, s0 + 0.05, s0 + door - 0.05, 2.1, 2.2, 0.42, 3.12, 0.02, base=0.06)


def kitchen_handles(bm):
    door = KL / 6
    for k in range(6):
        s = -KL / 2 + (k + 0.5) * door + (0.32 if k % 2 == 0 else -0.32)
        wall_box(bm, 0, s - 0.05, s + 0.05, 2.2, 2.32, 2.2, 2.9, 0.02, base=0.06)


B.piece("KitchenUnit_Body", SAGE, kitchen_body, smooth=False)
B.piece("KitchenUnit_Top", OAK, lambda bm: wall_box(bm, 0, -KL / 2, KL / 2, 0.08, 2.4, 3.2, 3.4, 0.03, base=0.06),
        smooth=False)
B.piece("KitchenUnit_Handles", STEEL, kitchen_handles, smooth=False)

# ------------------------------------------------------------------ CorkBoard (x = 14)
# On the wall from s 12.8 to 22.8 (x = 14 + s - 17.8), 8 to 11.6 up: frame, cork, eight notes.
CX = 14.0 - 17.8
B.piece("CorkBoard_Frame", OAK, lambda bm: wall_box(bm, CX, 12.8, 22.8, 0.08, 0.16, 8, 11.6, 0.02, base=8), smooth=False)
B.piece("CorkBoard_Cork", CORK, lambda bm: wall_box(bm, CX, 13, 22.6, 0.16, 0.2, 8.2, 11.4, base=8), smooth=False)


def notes(parity):
    def build(bm):
        for k in range(8):
            if k % 2 == parity:
                ns, ny = 13.5 + k * 1.15, 8.5 + (k % 2) * 1.1
                tilt = Matrix.Rotation(math.radians(4 if k % 3 == 0 else -3), 4, "Y")
                centre = Vector((CX + ns + 0.45, -0.21, ny + 0.5 - 8))
                H.box(bm, centre, Vector((0.9, 0.02, 1.0)), tilt)
    return build


B.piece("CorkBoard_NoteA", YELLOW, notes(0), smooth=False)
B.piece("CorkBoard_NoteB", MINT, notes(1), smooth=False)

# ------------------------------------------------------------------ HangRail (x = 30)
# On the wall from s 3 to 11.5, the rail 0.6 out, 7.1 up; brackets at both ends.
RX = 30.0 - 7.25


def hang_rail(bm):
    H.cylinder(bm, Vector((RX + 7.25, -0.6, 0.06)), 0.05, 8.5, axis="X", segments=8)
    for s in (3.2, 11.3):
        H.cylinder(bm, Vector((RX + s, -0.34, 0.06)), 0.04, 0.52, axis="Y", segments=6)
        H.cylinder(bm, Vector((RX + s, -0.1, 0.06)), 0.1, 0.04, axis="Y", segments=8)


B.piece("HangRail_Rail", STEEL, hang_rail)

# ------------------------------------------------------------------ CoatHook (x = 36)


def coat_hook(bm):
    H.rounded_box(bm, Vector((36.0, -0.1, 0.1)), Vector((0.16, 0.04, 0.3)), 0.015, 1)
    tilt = Matrix.Rotation(math.radians(-20), 4, "X")
    H.cylinder(bm, Vector((36.0, -0.28, 0.1)), 0.03, 0.4, axis="Y", segments=6)
    H.sphere(bm, Vector((36.0, -0.48, 0.14)), 0.05, segments=8, rings=4)


B.piece("CoatHook_Hook", STEEL, coat_hook)

# ------------------------------------------------------------------ FilingCabinet (x = 40)
# On the wall from s 10 to 14, 2 deep, 4.5 tall, three drawers.
FX = 40.0 - 12


def filing_body(bm):
    wall_box(bm, FX, 10, 14, 0, 1.94, 0, 4.5, 0.04)
    for k in range(3):
        y0 = 0.08 + k * 1.47
        wall_box(bm, FX, 10.1, 13.9, 1.94, 2.0, y0, y0 + 1.4, 0.02)


def filing_handles(bm):
    for k in range(3):
        y = 0.08 + k * 1.47 + 1.0
        wall_box(bm, FX, 11.5, 12.5, 2.0, 2.1, y, y + 0.12, 0.02)


B.piece("FilingCabinet_Body", GREY, filing_body, smooth=False)
B.piece("FilingCabinet_Handles", STEEL, filing_handles, smooth=False)

# ------------------------------------------------------------------ WallClock (x = 46)
# A 1.6 clock 0.15 off the wall, its centre 0.8 up.
WCX = 46.0


def clock_rim(bm):
    H.torus(bm, Vector((WCX, -0.09, 0.8)), 0.74, 0.07, plane="XZ", segments=24, sides=6)
    H.cylinder(bm, Vector((WCX, -0.03, 0.8)), 0.72, 0.06, axis="Y", segments=24)
    H.box(bm, Vector((WCX, -0.17, 0.95)), Vector((0.05, 0.02, 0.32)))
    H.box(bm, Vector((WCX + 0.18, -0.175, 0.8)), Vector((0.38, 0.02, 0.04)))
    H.cylinder(bm, Vector((WCX, -0.17, 0.8)), 0.05, 0.03, axis="Y", segments=8)


B.piece("WallClock_Rim", BLACK, clock_rim)
B.piece("WallClock_Face", WHITE, lambda bm: H.cylinder(bm, Vector((WCX, -0.1, 0.8)), 0.7, 0.1, axis="Y", segments=24))

# ------------------------------------------------------------------ WhiteboardFrame (x = 50)
# Round a whiteboard from s -7 to 7, 3.5 to 8.5 up: a 0.15 steel rim to t 0.18, the pen tray s -4..4 at 3.3.
WBX = 50.0


def whiteboard_frame(bm):
    wall_box(bm, WBX, -7.15, 7.15, 0, 0.18, 8.5, 8.65, 0.02, base=3.3)
    wall_box(bm, WBX, -7.15, 7.15, 0, 0.18, 3.35, 3.5, 0.02, base=3.3)
    for s0 in (-7.15, 7.0):
        wall_box(bm, WBX, s0, s0 + 0.15, 0, 0.18, 3.5, 8.5, base=3.3)
    wall_box(bm, WBX, -4, 4, 0.15, 0.5, 3.3, 3.36, base=3.3)
    wall_box(bm, WBX, -4, 4, 0.44, 0.5, 3.36, 3.45, base=3.3)


B.piece("WhiteboardFrame_Frame", STEEL, whiteboard_frame, smooth=False)

# ------------------------------------------------------------------ Laptop (x = 60)
# 2 wide, 1.4 deep, the screen 1.2 tall at the back, leaning back 12 degrees.
LX = 60.0
LID = Matrix.Rotation(math.radians(-12), 4, "X")  # the top leans back (+Y)


def laptop_body(bm):
    H.rounded_box(bm, Vector((LX, 0, 0.04)), Vector((2.0, 1.4, 0.08)), 0.02, 1)
    H.rounded_box(bm, Vector((LX, 0.7, 0.08)) + LID @ Vector((0, 0.02, 0.6)), Vector((2.0, 0.05, 1.2)), 0.02, 1,
                  rotation=LID)


def laptop_screen(bm):
    H.box(bm, Vector((LX, 0.7, 0.08)) + LID @ Vector((0, -0.01, 0.62)), Vector((1.84, 0.01, 1.04)), LID)
    H.box(bm, Vector((LX, -0.05, 0.085)), Vector((1.7, 0.7, 0.01)))


B.piece("Laptop_Body", GREY, laptop_body)
B.piece("Laptop_Screen", BLACK, laptop_screen, smooth=False)

# ------------------------------------------------------------------ FlatPlate (x = 64)
# A 2.0 bumper plate 0.18 thick lying flat, with a raised hub.


def flat_plate(bm):
    H.cylinder(bm, Vector((64.0, 0, 0.09)), 1.0, 0.16, segments=20)
    H.cylinder(bm, Vector((64.0, 0, 0.09)), 0.94, 0.18, segments=20)
    H.cylinder(bm, Vector((64.0, 0, 0.1)), 0.28, 0.2, segments=12)


B.piece("FlatPlate_Plate", RED, flat_plate)

# ------------------------------------------------------------------ BarStand (x = 70)
# On the wall from s 9 to 15: the holder 1.2 deep, 0.6 tall; five bars 1.2 apart, 0.6 out, to 10.4 up.
BSX = 70.0 - 12


def bar_holder(bm):
    wall_box(bm, BSX, 9, 15, 0, 1.2, 0, 0.6, 0.04)


def bars(bm):
    for k in range(5):
        x = BSX + 9.6 + k * 1.2
        H.cylinder(bm, Vector((x, -0.6, 0.6 + 3.1)), 0.07, 6.2, segments=8)
        H.cylinder(bm, Vector((x, -0.6, 6.8 + 1.8)), 0.11, 3.6, segments=10)
        H.cylinder(bm, Vector((x, -0.6, 6.8)), 0.16, 0.12, segments=10)


B.piece("BarStand_Holder", DARK_STEEL, bar_holder, smooth=False)
B.piece("BarStand_Bars", STEEL, bars)

# ------------------------------------------------------------------ FlatBench (x = 76)
# The pad 1.4 wide, 4.6 long, 1.5-1.9 up; legs 1.2 wide near both ends; a rail under the pad.
FB = 76.0
B.piece("FlatBench_Pad", RED, lambda bm: H.rounded_box(bm, Vector((FB, 0, 1.7)), Vector((1.4, 4.6, 0.4)), 0.1, 2))


def bench_frame(bm):
    for y in (-1.9, 1.9):
        H.box(bm, Vector((FB, y, 0.75)), Vector((0.2, 0.2, 1.5)))
        H.rounded_box(bm, Vector((FB, y, 0.05)), Vector((1.2, 0.3, 0.1)), 0.03, 1)
    H.box(bm, Vector((FB, 0, 1.35)), Vector((0.3, 4.0, 0.3)))


B.piece("FlatBench_Frame", BLACK, bench_frame, smooth=False)

# ------------------------------------------------------------------ ChalkStand (x = 80)
# A 0.8 post 3.2 tall on a foot, the 1.6 bowl on top to 3.7.
CSX = 80.0


def chalk_stand(bm):
    H.rounded_box(bm, Vector((CSX, 0, 0.05)), Vector((1.2, 1.2, 0.1)), 0.03, 1)
    H.box(bm, Vector((CSX, 0, 1.65)), Vector((0.5, 0.5, 3.1)))
    H.cylinder(bm, Vector((CSX, 0, 3.15)), 0.3, 0.1, segments=10)


def chalk_bowl(bm):
    H.lathe_z(bm, [(0.0, 0.0), (0.35, 0.0), (0.8, 0.42), (0.8, 0.5), (0.7, 0.5), (0.68, 0.44), (0.0, 0.44)], 18,
              Vector((CSX, 0, 3.2)))
    for k in range(5):
        a = k * 1.3
        H.sphere(bm, Vector((CSX + 0.3 * math.cos(a), 0.3 * math.sin(a), 3.66)), 0.16, scale=(1, 1, 0.5), segments=6,
                 rings=3)


B.piece("ChalkStand_Stand", DARK_STEEL, chalk_stand, smooth=False)
B.piece("ChalkStand_Bowl", WHITE, chalk_bowl)

# ------------------------------------------------------------------ StrongmanRig (x = 95)
# Posts 0.6 square at a -4 and 6, d 42.4 and 52.4 (x = 95 + a - 1, y = 47.4 - d), 10.2 tall; beams along the top;
# the pull-up bar across the middle at 9.35.
RGX = 95.0 - 1


def rig_frame(bm):
    for a in (-4, 6):
        for d in (42.4, 52.4):
            centre = Vector((RGX + a, 47.4 - d, 5.1))
            H.box(bm, centre, Vector((0.6, 0.6, 10.2)))
            H.box(bm, Vector((centre.x, centre.y, 0.04)), Vector((1.2, 1.2, 0.08)))
    for d in (42.4, 52.4):
        H.box(bm, Vector((RGX + 1, 47.4 - d, 9.9)), Vector((10.6, 0.6, 0.6)))
    for a in (-4, 6):
        H.box(bm, Vector((RGX + a, 0, 9.9)), Vector((0.6, 9.4, 0.6)))


B.piece("StrongmanRig_Frame", DARK_STEEL, rig_frame, smooth=False)
B.piece("StrongmanRig_Bar", STEEL, lambda bm: H.cylinder(bm, Vector((RGX + 1, 0, 9.35)), 0.1, 10.0, axis="X", segments=10))

print("BackRooms_01 built:", sorted(o.name for o in B.coll.objects))
