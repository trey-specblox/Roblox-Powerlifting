# W Chews' restaurant kit (GAME_DESIGN §40.7, user 2026-11-21: a "beautiful", fancy restaurant with a big, clean,
# stainless commercial kitchen; floor plan 02, art/previews/WChews_FloorPlan_02.png). One mesh per repeated object:
# the game places copies (KitchenBuilding / WChewsLayout), scaled where the plan wants them bigger.
#
# Every item is built round its own origin, standing on z = 0 (hanging items: see each), its front toward -Y.
# Object names are "<Item>_<Piece>", one colour per piece (StarterGymConfig.PropColourways paints them).
#
#   Back of house (stainless):
#     WcCounter      a steel worktop on legs with an undershelf and a backsplash                      8 x 3 x 3.8
#     WcRange        a six-burner range with an oven, red knobs, two copper pots and a flame          8 x 3 x 4.3
#     WcFryer        a twin fryer with baskets on teal grips                                           8 x 3 x 4.4
#     WcHood         an exhaust hood with filters, a light strip and its duct (hangs: origin = its underside)
#     WcFridge       a two-door glass fridge, lit inside, with steak packs, greens and cheese          6 x 3 x 8
#     WcSink         a three-basin sink with water and two tall taps                                   8 x 3 x 5
#     WcIsland       a prep island with cutting boards, tomatoes, greens and teal bowls               14 x 5 x 3.8
#   The chef scene (user 2026-11-21: button, ceiling chute, display bay, tube onto your pan):
#     WcButtonPanel  a pedestal with a big red start button, a green lamp and a CENTRAL plate
#     WcChute        the ceiling drop chute over the grinder (hangs: origin = its mouth)
#     WcBay          the meat display bay: a steel tray with glass sides, lights and a glowing YOUR MEAT sign  26 x 26
#     WcTubeIntake   the pick-up funnel over the bay, its riser and the run to the trunk (origin = bay centre, floor)
#     WcTubeTrunk    half of the overhead trunk (origin = its inner end, on the tube's axis; runs to +X)
#     WcTubeBranch   the line over one column of five pans, with a drop over each (origin = its trunk end; runs +Y)
#   Front of house (fancy):
#     WcTable        a round table with a white cloth, navy plates and a candle
#     WcChair        a dining chair with a cushion (colourways: teal, burgundy, mustard)
#     WcPendant      a brass hanging light with a warm bulb (hangs: origin = the bulb's underside; cord up 6)
#     WcChandelier   two brass rings of warm globes on rods (hangs: origin = the big ring's underside; 6.6 up)
#     WcHostStand    the host's stand with a brass top and W CHEWS on its front
#     WcBar          a module of the chef's service counter: walnut panels, a pale stone top, a brass foot rail  12 x 3.8
#     WcPlant        a potted plant in a teal pot
#     WcStaffDoor    the EMPLOYEES ONLY door in its frame (Door / DoorBrass / DoorText swing together on the hinge)
#
#   blender -b --factory-startup --python art/scripts/build_wchews_kit_01.py -- <out.blend> [<out.glb>]

import json
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, r"D:\Powerlifting Roblox\art\scripts")
import importlib  # noqa: E402

import prop_helpers as H  # noqa: E402

importlib.reload(H)

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

B = H.Builder("WChewsKit")

STEEL = H.material("Wc_Steel", (0.80, 0.82, 0.85), metallic=0.9, roughness=0.28)
STEEL_DARK = H.material("Wc_SteelDark", (0.42, 0.44, 0.48), metallic=0.85, roughness=0.35)
BLACK = H.material("Wc_Black", (0.04, 0.04, 0.05), roughness=0.6)
GLASS = H.material("Wc_Glass", (0.62, 0.80, 0.88), metallic=0.2, roughness=0.1, alpha=0.3)
WOOD = H.material("Wc_Walnut", (0.26, 0.14, 0.07), roughness=0.55)
WOOD_LIGHT = H.material("Wc_Maple", (0.80, 0.62, 0.38), roughness=0.6)
CLOTH = H.material("Wc_ClothWhite", (0.96, 0.95, 0.92), roughness=0.8)
BRASS = H.material("Wc_Brass", (0.86, 0.64, 0.22), metallic=0.9, roughness=0.3)
COPPER = H.material("Wc_Copper", (0.78, 0.42, 0.24), metallic=0.9, roughness=0.3)
NAVY = H.material("Wc_Navy", (0.05, 0.08, 0.21), roughness=0.55)
YELLOW = H.material("Wc_Yellow", (0.98, 0.80, 0.12), roughness=0.5)
RED = H.material("Wc_Red", (0.82, 0.12, 0.10), roughness=0.45)
TEAL = H.material("Wc_Teal", (0.06, 0.52, 0.52), roughness=0.5)
GREEN = H.material("Wc_LeafGreen", (0.16, 0.50, 0.18), roughness=0.7)
DOOR_GREEN = H.material("Wc_DoorGreen", (0.06, 0.22, 0.16), roughness=0.5)
MEAT = H.material("Wc_MeatRed", (0.70, 0.16, 0.16), roughness=0.5)
WATER = H.material("Wc_Water", (0.25, 0.62, 0.80), roughness=0.1)
OIL = H.material("Wc_Oil", (0.80, 0.56, 0.12), roughness=0.15)
CUSHION = H.material("Wc_Cushion", (0.06, 0.45, 0.47), roughness=0.9)
GLOW_WARM = H.material("Wc_GlowWarm", (1.0, 0.80, 0.55), emission=(1.0, 0.72, 0.38))
GLOW_WHITE = H.material("Wc_GlowWhite", (1.0, 0.98, 0.94), emission=(1.0, 0.97, 0.9))
GLOW_GREEN = H.material("Wc_GlowGreen", (0.2, 0.95, 0.4), emission=(0.1, 0.95, 0.3))
GLOW_YELLOW = H.material("Wc_GlowYellow", (1.0, 0.84, 0.25), emission=(1.0, 0.78, 0.15))
FLAME = H.material("Wc_Flame", (1.0, 0.48, 0.12), emission=(1.0, 0.42, 0.08))

V = Vector


def prism_x(bm, points, x0, x1):
    """A solid from an outline in the YZ plane, from x0 to x1."""
    left = [bm.verts.new((x0, y, z)) for y, z in points]
    right = [bm.verts.new((x1, y, z)) for y, z in points]
    made = [bm.faces.new(list(reversed(left))), bm.faces.new(right)]
    n = len(points)
    for i in range(n):
        j = (i + 1) % n
        made.append(bm.faces.new((left[i], left[j], right[j], right[i])))
    bmesh.ops.recalc_face_normals(bm, faces=made)


def legs(bm, w, d, h, t=0.25, inset=0.2):
    for sx in (-1, 1):
        for sy in (-1, 1):
            H.box(bm, V((sx * (w / 2 - inset), sy * (d / 2 - inset), h / 2)), (t, t, h))


# ======================================================================= WcCounter (8 x 3, top at 3.3)

def counter_top(bm):
    H.rounded_box(bm, V((0, 0, 3.2)), (8.0, 3.0, 0.22), 0.06, segments=2)
    H.box(bm, V((0, 1.42, 3.55)), (8.0, 0.16, 0.6))  # the backsplash


def counter_frame(bm):
    legs(bm, 8.0, 3.0, 3.1)
    H.box(bm, V((0, 0, 0.9)), (7.5, 2.5, 0.12))  # the undershelf
    H.box(bm, V((0, -1.3, 2.9)), (7.5, 0.12, 0.3))  # the front rail


B.piece("WcCounter_Top", STEEL, counter_top)
B.piece("WcCounter_Frame", STEEL_DARK, counter_frame, smooth=False)

# ======================================================================= WcRange (8 x 3)

BURNERS = [(x, y) for x in (-2.6, 0.0, 2.6) for y in (-0.65, 0.7)]


def range_body(bm):
    H.rounded_box(bm, V((0, 0, 1.75)), (8.0, 3.0, 2.9), 0.08, segments=2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            H.cylinder(bm, V((sx * 3.6, sy * 1.2, 0.16)), 0.16, 0.32, segments=10)
    H.box(bm, V((0, 1.42, 3.7)), (8.0, 0.16, 1.0))  # the back guard
    H.box(bm, V((0, 1.2, 4.25)), (8.0, 0.6, 0.1))  # its shelf


def range_top(bm):
    H.box(bm, V((0, -0.05, 3.24)), (7.7, 2.7, 0.1))  # the black cooktop
    for x, y in BURNERS:
        H.cylinder(bm, V((x, y, 3.33)), 0.5, 0.08, segments=14)
        H.box(bm, V((x, y, 3.4)), (1.2, 0.1, 0.08))
        H.box(bm, V((x, y, 3.4)), (0.1, 1.2, 0.08))
    # The two oven doors' windows and handles.
    for x in (-2.0, 2.0):
        H.box(bm, V((x, -1.52, 1.5)), (2.6, 0.06, 1.0))
        H.cylinder(bm, V((x, -1.66, 2.35)), 0.08, 3.0, axis="X", segments=8)
        for dx in (-1.3, 1.3):
            H.box(bm, V((x + dx, -1.58, 2.35)), (0.12, 0.2, 0.12))


def range_knobs(bm):
    for k in range(6):
        H.cylinder(bm, V((-3.25 + 1.3 * k, -1.56, 2.9)), 0.17, 0.16, axis="Y", segments=10)


def pot_outline(r, h):
    return [(0.0, 0.0), (r, 0.0), (r, h), (r - 0.07, h), (r - 0.07, 0.1), (0.0, 0.1)]


def range_pots(bm):
    H.lathe_z(bm, pot_outline(0.62, 0.8), 16, V((-2.6, -0.65, 3.44)))
    H.lathe_z(bm, pot_outline(0.5, 0.45), 16, V((2.6, 0.7, 3.44)))
    H.cylinder(bm, V((2.6, -0.2, 3.8)), 0.06, 1.0, axis="Y", segments=8)  # the pan's handle
    for sx in (-1, 1):
        H.box(bm, V((-2.6 + sx * 0.72, -0.65, 4.1)), (0.22, 0.4, 0.08))


def range_flame(bm):
    for x, y in ((0.0, -0.65), (0.0, 0.7)):
        H.torus(bm, (x, y, 3.42), 0.3, 0.07, segments=12, sides=6)


B.piece("WcRange_Body", STEEL, range_body)
B.piece("WcRange_Top", BLACK, range_top, smooth=False)
B.piece("WcRange_Knobs", RED, range_knobs)
B.piece("WcRange_Pots", COPPER, range_pots)
B.piece("WcRange_Flame", FLAME, range_flame)

# ======================================================================= WcFryer (8 x 3)

WELLS = (-2.0, 2.0)


def fryer_body(bm):
    # A cabinet with two open wells: the cabinet below, then a rim round each well.
    H.rounded_box(bm, V((0, 0, 1.5)), (8.0, 3.0, 2.4), 0.08, segments=2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            H.cylinder(bm, V((sx * 3.6, sy * 1.2, 0.16)), 0.16, 0.32, segments=10)
    for x in WELLS:
        H.span(bm, (x - 1.7, -1.3, 2.7), (x + 1.7, -1.05, 3.3))
        H.span(bm, (x - 1.7, 1.05, 2.7), (x + 1.7, 1.3, 3.3))
        H.span(bm, (x - 1.7, -1.05, 2.7), (x - 1.45, 1.05, 3.3))
        H.span(bm, (x + 1.45, -1.05, 2.7), (x + 1.7, 1.05, 3.3))
    H.box(bm, V((0, 1.42, 3.8)), (8.0, 0.16, 1.2))  # the back guard
    H.box(bm, V((0, 1.0, 4.36)), (8.0, 1.0, 0.1))  # the basket shelf's lip
    for x in (-2.0, 2.0):  # door handles
        H.cylinder(bm, V((x, -1.6, 2.1)), 0.07, 2.4, axis="X", segments=8)
        for dx in (-1.1, 1.1):
            H.box(bm, V((x + dx, -1.54, 2.1)), (0.1, 0.14, 0.1))


def fryer_oil(bm):
    for x in WELLS:
        H.span(bm, (x - 1.46, -1.06, 2.69), (x + 1.46, 1.06, 3.12))


def fryer_baskets(bm):
    # Wire baskets hooked on the back guard: a frame of bars and a grid floor.
    for x in WELLS:
        for bx in (-0.5, 0.5):
            cx = x + bx * 1.3
            for sy in (-0.7, 0.3):
                H.box(bm, V((cx, sy + 0.2, 3.5)), (1.0, 0.06, 0.7))
            for sx in (-0.5, 0.5):
                H.box(bm, V((cx + sx, 0.0, 3.5)), (0.06, 1.0, 0.7))
            H.box(bm, V((cx, 0.0, 3.18)), (1.0, 1.0, 0.06))
            H.box(bm, V((cx, -0.95, 3.82)), (0.1, 0.9, 0.08))  # the handle's bar


def fryer_grips(bm):
    for x in WELLS:
        for bx in (-0.5, 0.5):
            H.cylinder(bm, V((x + bx * 1.3, -1.62, 3.82)), 0.11, 0.7, axis="Y", segments=8)


B.piece("WcFryer_Body", STEEL, fryer_body)
B.piece("WcFryer_Oil", OIL, fryer_oil, smooth=False)
B.piece("WcFryer_Baskets", STEEL_DARK, fryer_baskets, smooth=False)
B.piece("WcFryer_Grips", TEAL, fryer_grips)

# ======================================================================= WcHood (8 x 3.6, hangs; origin = underside)


def hood_canopy(bm):
    # A sloped canopy (front low, rising to the back) and the duct up to the ceiling.
    prism_x(bm, [(-1.9, 0.0), (1.7, 0.0), (1.7, 2.6), (0.3, 2.6), (-1.9, 0.9)], -4.0, 4.0)
    H.box(bm, V((0, 0.9, 9.0)), (2.4, 1.4, 12.8))  # up into the ceiling at the cooking line's scale (1.6)
    H.box(bm, V((0, 0.9, 2.75)), (3.0, 2.0, 0.3))  # the duct's collar


def hood_filters(bm):
    # The grease filters: a slanted dark panel just inside the front lip, and the trim line along the front.
    for k in range(4):
        H.box(bm, V((-3.0 + 2.0 * k, -0.2, -0.06)), (1.8, 2.4, 0.1))
    H.box(bm, V((0, -1.93, 0.45)), (8.02, 0.06, 0.12))


def hood_light(bm):
    H.box(bm, V((0, 1.3, -0.06)), (7.0, 0.5, 0.1))


B.piece("WcHood_Canopy", STEEL, hood_canopy, smooth=False)
B.piece("WcHood_Filters", STEEL_DARK, hood_filters, smooth=False)
B.piece("WcHood_Light", GLOW_WHITE, hood_light, smooth=False)

# ======================================================================= WcFridge (6 x 3 x 8)

SHELVES = (1.0, 2.7, 4.4, 6.1)


def fridge_body(bm):
    H.span(bm, (-3.0, 1.2, 0.0), (3.0, 1.5, 8.0))  # back
    H.span(bm, (-3.0, -1.5, 0.0), (-2.75, 1.2, 8.0))  # sides
    H.span(bm, (2.75, -1.5, 0.0), (3.0, 1.2, 8.0))
    H.span(bm, (-2.75, -1.5, 0.0), (2.75, 1.2, 0.7))  # the plinth
    H.span(bm, (-2.75, -1.5, 7.3), (2.75, 1.2, 8.0))  # the header
    H.span(bm, (-0.1, -1.5, 0.7), (0.1, -1.3, 7.3))  # the mullion between the doors
    for z in SHELVES[1:]:
        H.span(bm, (-2.75, -1.2, z - 0.08), (2.75, 1.2, z))
    for sx in (-1, 1):  # the doors' handles
        H.cylinder(bm, V((sx * 0.45, -1.72, 4.0)), 0.07, 2.2, segments=8)
        for dz in (-1.0, 1.0):
            H.box(bm, V((sx * 0.45, -1.62, 4.0 + dz)), (0.1, 0.2, 0.1))


def fridge_light(bm):
    H.span(bm, (-2.75, 1.1, 0.7), (2.75, 1.2, 7.3))


def fridge_meat(bm):
    # Steak packs on the two lower shelves.
    for z in SHELVES[:2]:
        for k in range(4):
            H.rounded_box(bm, V((-2.0 + 1.33 * k, 0.1, z + 0.22)), (1.0, 1.5, 0.4), 0.08, segments=1)


def fridge_greens(bm):
    for k in range(5):
        H.sphere(bm, V((-2.1 + 1.05 * k, 0.2, SHELVES[2] + 0.42)), 0.42, scale=(1, 1, 0.9), segments=10, rings=6)


def fridge_cheese(bm):
    for k in range(3):
        H.cylinder(bm, V((-1.8 + 1.8 * k, 0.2, SHELVES[3] + 0.3)), 0.7, 0.55, segments=14)


def fridge_glass(bm):
    for sx in (-1, 1):
        H.span(bm, (sx * 0.1, -1.5, 0.75), (sx * 2.72, -1.42, 7.25))


B.piece("WcFridge_Body", STEEL, fridge_body, smooth=False)
B.piece("WcFridge_Light", GLOW_WHITE, fridge_light, smooth=False)
B.piece("WcFridge_Meat", MEAT, fridge_meat)
B.piece("WcFridge_Greens", GREEN, fridge_greens)
B.piece("WcFridge_Cheese", YELLOW, fridge_cheese)
B.piece("WcFridge_Glass", GLASS, fridge_glass, smooth=False)

# ======================================================================= WcSink (8 x 3)

BASINS = (-2.55, 0.0, 2.55)


def sink_body(bm):
    # The deck as a frame round three open basins, each basin a five-sided tub hanging below it.
    H.span(bm, (-4.0, -1.5, 3.1), (4.0, -1.1, 3.3))
    H.span(bm, (-4.0, 1.0, 3.1), (4.0, 1.5, 3.3))
    for x in (-3.9, -1.275, 1.275, 3.9):
        H.span(bm, (x - 0.1, -1.1, 3.1), (x + 0.1, 1.0, 3.3))
    for x in BASINS:
        H.span(bm, (x - 1.2, -1.15, 1.9), (x + 1.2, 1.05, 2.0))  # the basin's floor
        H.span(bm, (x - 1.2, -1.15, 1.9), (x - 1.12, 1.05, 3.1))
        H.span(bm, (x + 1.12, -1.15, 1.9), (x + 1.2, 1.05, 3.1))
        H.span(bm, (x - 1.2, -1.15, 1.9), (x + 1.2, -1.07, 3.1))
        H.span(bm, (x - 1.2, 0.97, 1.9), (x + 1.2, 1.05, 3.1))
    H.box(bm, V((0, 1.42, 3.9)), (8.0, 0.16, 1.2))  # the backsplash


def sink_frame(bm):
    legs(bm, 8.0, 3.0, 3.1)
    H.box(bm, V((0, 0, 0.7)), (7.5, 2.5, 0.1))
    # Two tall taps: a riser, a curved neck and a spout.
    for x in (-1.275, 1.275):
        H.cylinder(bm, V((x, 1.2, 3.9)), 0.09, 1.2, segments=8)
        H.torus(bm, (x, 0.8, 4.5), 0.4, 0.09, plane="YZ", segments=10, sides=8, arc=math.pi, start=0.0)
        H.cylinder(bm, V((x, 0.4, 4.3)), 0.09, 0.4, segments=8)
        for sx in (-1, 1):
            H.box(bm, V((x + sx * 0.35, 1.2, 3.5)), (0.3, 0.1, 0.1))


def sink_water(bm):
    H.span(bm, (BASINS[0] - 1.12, -1.07, 2.0), (BASINS[0] + 1.12, 0.97, 2.75))


B.piece("WcSink_Body", STEEL, sink_body, smooth=False)
B.piece("WcSink_Frame", STEEL_DARK, sink_frame)
B.piece("WcSink_Water", WATER, sink_water, smooth=False)

# ======================================================================= WcIsland (14 x 5)


def island_top(bm):
    H.rounded_box(bm, V((0, 0, 3.2)), (14.0, 5.0, 0.24), 0.07, segments=2)


def island_frame(bm):
    legs(bm, 14.0, 5.0, 3.1, t=0.3)
    for sy in (-1, 1):
        H.box(bm, V((0, sy * 2.3, 1.55)), (0.3, 0.3, 3.1))
    H.box(bm, V((0, 0, 0.9)), (13.4, 4.4, 0.12))
    H.box(bm, V((0, 0, 2.0)), (13.4, 4.4, 0.12))
    # A rack over the island: two posts, a rail, and hooks.
    for sx in (-1, 1):
        H.box(bm, V((sx * 6.6, 0, 5.2)), (0.25, 0.25, 4.0))
    H.box(bm, V((0, 0, 7.1)), (13.45, 0.25, 0.25))


def island_boards(bm):
    H.rounded_box(bm, V((-4.2, -0.4, 3.42)), (3.2, 2.2, 0.2), 0.06, segments=1)
    H.rounded_box(bm, V((3.6, 0.5, 3.42)), (2.6, 1.8, 0.2), 0.06, segments=1)


def island_tomatoes(bm):
    for x, y in ((-4.9, -0.7), (-4.2, -0.1), (-3.6, -0.8), (-4.4, 0.4)):
        H.sphere(bm, V((x, y, 3.78)), 0.3, scale=(1, 1, 0.85), segments=10, rings=6)


def island_greens(bm):
    for k in range(4):
        H.sphere(bm, V((3.0 + 0.45 * k, 0.5, 3.72)), 0.34, scale=(1.3, 0.9, 0.6), segments=10, rings=6)
    H.sphere(bm, V((0.2, 1.3, 3.95)), 0.6, scale=(1, 1, 0.8), segments=12, rings=7)


def island_bowls(bm):
    outline = [(0.0, 0.0), (0.45, 0.0), (0.95, 0.75), (0.87, 0.75), (0.42, 0.1), (0.0, 0.1)]
    H.lathe_z(bm, outline, 16, V((0.2, 1.3, 3.33)))
    H.lathe_z(bm, outline, 16, V((-1.6, -1.2, 3.33)))
    H.lathe_z(bm, outline, 16, V((6.0, -1.3, 3.33)))


def island_pans(bm):
    # Copper pans hanging from the rack.
    for k in range(5):
        x = -5.0 + 2.5 * k
        H.cylinder(bm, V((x, 0, 6.0)), 0.7, 0.14, axis="Y", segments=14)
        H.box(bm, V((x, 0, 6.85)), (0.14, 0.1, 0.5))


B.piece("WcIsland_Top", STEEL, island_top)
B.piece("WcIsland_Frame", STEEL_DARK, island_frame, smooth=False)
B.piece("WcIsland_Boards", WOOD_LIGHT, island_boards)
B.piece("WcIsland_Tomatoes", RED, island_tomatoes)
B.piece("WcIsland_Greens", GREEN, island_greens)
B.piece("WcIsland_Bowls", TEAL, island_bowls)
B.piece("WcIsland_Pans", COPPER, island_pans)

# ======================================================================= WcButtonPanel


def panel_body(bm):
    H.rounded_box(bm, V((0, 0.1, 1.5)), (1.3, 1.0, 3.0), 0.12, segments=2)
    H.rounded_box(bm, V((0, 0, 3.2)), (2.8, 1.9, 0.6), 0.14, segments=2)
    H.rounded_box(bm, V((0, 0.1, 0.12)), (2.2, 1.7, 0.24), 0.08, segments=1)


def panel_button(bm):
    H.lathe_z(bm, [(0.0, 0.0), (0.42, 0.0), (0.42, 0.22), (0.66, 0.22), (0.62, 0.42), (0.4, 0.56), (0.0, 0.6)], 20,
              V((-0.35, 0, 3.58)))


def panel_collar(bm):
    H.cylinder(bm, V((-0.35, 0, 3.54)), 0.82, 0.1, segments=20)


def panel_lamp(bm):
    H.sphere(bm, V((0.95, 0.4, 3.52)), 0.2, scale=(1, 1, 0.8), segments=10, rings=6)


def panel_plate(bm):
    H.rounded_box(bm, V((0, -0.43, 2.2)), (1.1, 0.06, 0.5), 0.02, segments=1)


def panel_plate_text(bm):
    B.add_text(bm, H.BRAND, 0.17, 0.012, H.on_front((0, 0, 0), -0.465, 2.2))


B.piece("WcButtonPanel_Body", STEEL, panel_body)
B.piece("WcButtonPanel_Button", RED, panel_button)
B.piece("WcButtonPanel_Collar", YELLOW, panel_collar)
B.piece("WcButtonPanel_Lamp", GLOW_GREEN, panel_lamp)
B.piece("WcButtonPanel_Plate", NAVY, panel_plate)
B.piece("WcButtonPanel_PlateText", YELLOW, panel_plate_text, smooth=False)

# ======================================================================= WcChute (hangs; origin = its mouth, 14 up to the ceiling)

CH = 4.5  # half the duct's width


def square_tube(bm, half, t, z0, z1):
    H.span(bm, (-half, -half, z0), (half, -half + t, z1))
    H.span(bm, (-half, half - t, z0), (half, half, z1))
    H.span(bm, (-half, -half + t, z0), (-half + t, half - t, z1))
    H.span(bm, (half - t, -half + t, z0), (half, half - t, z1))


def chute_duct(bm):
    square_tube(bm, CH, 0.3, 0.0, 14.0)
    for z in (4.0, 9.0, 13.6):  # stiffening bands
        square_tube(bm, CH + 0.2, 0.2, z, z + 0.5)


def chute_band(bm):
    square_tube(bm, CH + 0.5, 0.5, 0.0, 1.2)  # the yellow mouth band


def chute_inside(bm):
    H.span(bm, (-CH + 0.3, -CH + 0.3, 7.0), (CH - 0.3, CH - 0.3, 7.3))  # darkness up the chute
    for k in range(4):  # black warning blocks on the mouth band's four faces
        for s in (-1, 1):
            H.box(bm, V((-3.0 + 2.0 * k, s * (CH + 0.52), 0.6)), (0.9, 0.06, 1.2))
            H.box(bm, V((s * (CH + 0.52), -3.0 + 2.0 * k, 0.6)), (0.06, 0.9, 1.2))


B.piece("WcChute_Duct", STEEL, chute_duct, smooth=False)
B.piece("WcChute_Band", YELLOW, chute_band, smooth=False)
B.piece("WcChute_Inside", BLACK, chute_inside, smooth=False)

# ======================================================================= WcBay (26 x 26; the grinder pours in over its back, +Y)

BH = 13.0  # half the bay's width
POST_H = 12.0


def bay_tray(bm):
    H.span(bm, (-BH, -BH, 0.0), (BH, BH, 0.3))
    H.span(bm, (-BH, -BH, 0.3), (BH, -BH + 0.7, 1.6))
    H.span(bm, (-BH, BH - 0.7, 0.3), (BH, BH, 1.6))
    H.span(bm, (-BH, -BH + 0.7, 0.3), (-BH + 0.7, BH - 0.7, 1.6))
    H.span(bm, (BH - 0.7, -BH + 0.7, 0.3), (BH, BH - 0.7, 1.6))


def bay_frame(bm):
    for sx in (-1, 1):
        for sy in (-1, 1):
            H.box(bm, V((sx * (BH - 0.35), sy * (BH - 0.35), POST_H / 2)), (0.7, 0.7, POST_H))
    # Top rails on the front and both sides; none at the back, where the grinder's outlet comes in.
    H.box(bm, V((0, -(BH - 0.35), POST_H - 0.3)), (2 * BH, 0.7, 0.6))
    for s in (-1, 1):
        H.box(bm, V((s * (BH - 0.35), 0, POST_H - 0.3)), (0.7, 2 * BH, 0.6))
    # The sign's backing bar on the front.
    H.box(bm, V((0, -BH + 0.3, POST_H + 1.1)), (14.0, 0.5, 2.4))
    H.box(bm, V((-6.6, -BH + 0.3, POST_H + 0.1)), (0.4, 0.4, 0.6))
    H.box(bm, V((6.6, -BH + 0.3, POST_H + 0.1)), (0.4, 0.4, 0.6))


def bay_glass(bm):
    # Glass on the front and both sides (the back is open: the grinder's outlet pours in there).
    H.span(bm, (-BH + 0.7, -BH + 0.25, 1.6), (BH - 0.7, -BH + 0.4, 8.0))
    H.span(bm, (-BH + 0.25, -BH + 0.7, 1.6), (-BH + 0.4, BH - 0.7, 8.0))
    H.span(bm, (BH - 0.4, -BH + 0.7, 1.6), (BH - 0.25, BH - 0.7, 8.0))


def bay_lights(bm):
    H.box(bm, V((0, -(BH - 0.9), POST_H - 0.68)), (2 * BH - 3, 0.4, 0.16))
    for s in (-1, 1):
        H.box(bm, V((s * (BH - 0.9), 0, POST_H - 0.68)), (0.4, 2 * BH - 3, 0.16))


def bay_sign_text(bm):
    B.add_text(bm, "YOUR MEAT", 1.7, 0.08, H.on_front((0, 0, 0), -BH + 0.05, POST_H + 1.1))


B.piece("WcBay_Tray", STEEL, bay_tray, smooth=False)
B.piece("WcBay_Frame", STEEL_DARK, bay_frame, smooth=False)
B.piece("WcBay_Glass", GLASS, bay_glass, smooth=False)
B.piece("WcBay_Lights", GLOW_WHITE, bay_lights, smooth=False)
B.piece("WcBay_SignText", GLOW_YELLOW, bay_sign_text, smooth=False)

# ======================================================================= The meat tube (radius 1.5, 26 up in the game)

TR = 1.5  # the tube's radius
TUBE_UP = 10.0  # from the tube's axis up to the ceiling (hangers)
DROP = 8.0  # a drop's length below the axis
BRANCH_LEN = 216.0  # trunk (y 10) to the last pan (y 226)
DROPS = [24.0 + 48.0 * k for k in range(5)]  # pans at y 34, 82, 130, 178, 226
TRUNK_LEN = 234.0
TEES = (78.0, 130.0, 182.0, 234.0)
INTAKE_RUN = 26.0  # bay centre (y 36) to the trunk (y 10)
INTAKE_UP = 26.0  # the tube's height over the bay's floor
INTAKE_MOUTH = 14.5  # the funnel's mouth over the bay's floor (above the bay's frame and sign)


def collar(bm, centre, axis, radius=TR + 0.28, length=0.7):
    H.cylinder(bm, V(centre), radius, length, axis=axis, segments=12)


def hanger(bm, x, y):
    H.cylinder(bm, V((x, y, TR + (TUBE_UP - TR) / 2)), 0.14, TUBE_UP - TR, segments=6)


def branch_glass(bm):
    H.cylinder(bm, V((0, BRANCH_LEN / 2, 0)), TR, BRANCH_LEN, axis="Y", segments=12)
    for y in DROPS:
        H.cylinder(bm, V((0, y, -DROP / 2)), TR * 0.85, DROP, segments=12)


def branch_collars(bm):
    y = 0.0
    while y <= BRANCH_LEN + 0.01:
        collar(bm, (0, y, 0), "Y")
        y += 24.0
    collar(bm, (0, BRANCH_LEN + 0.6, 0), "Y", radius=TR + 0.1, length=0.6)  # the end cap
    for y in DROPS:
        collar(bm, (0, y, -TR - 0.2), "Z", radius=TR * 0.85 + 0.28, length=0.6)
        # The nozzle: a flared steel skirt at the drop's end.
        H.cylinder(bm, V((0, y, -DROP - 0.5)), TR * 0.85 + 0.9, 1.2, segments=12, radius2=TR * 0.85 + 0.2)


def branch_hangers(bm):
    for y in (12.0, 60.0, 108.0, 156.0, 204.0):
        hanger(bm, 0, y)
        H.box(bm, V((0, y, 0)), (2 * TR + 0.5, 0.3, 2 * TR + 0.5))  # the clamp


def trunk_glass(bm):
    H.cylinder(bm, V((TRUNK_LEN / 2, 0, 0)), TR, TRUNK_LEN, axis="X", segments=12)


def trunk_collars(bm):
    x = 0.0
    while x <= TRUNK_LEN + 0.01:
        collar(bm, (x, 0, 0), "X")
        x += 26.0
    for x in TEES:
        H.rounded_box(bm, V((x, 0, 0)), (4.2, 4.2, 4.2), 0.5, segments=2)  # a tee block where a branch leaves
    collar(bm, (TRUNK_LEN + 2.3, 0, 0), "X", radius=TR + 0.1, length=0.5)


def trunk_hangers(bm):
    for x in (13.0, 52.0, 104.0, 156.0, 208.0):
        hanger(bm, x, 0)
        H.box(bm, V((x, 0, 0)), (0.3, 2 * TR + 0.5, 2 * TR + 0.5))


def intake_glass(bm):
    H.cylinder(bm, V((0, 0, (INTAKE_MOUTH + 2 + INTAKE_UP) / 2)), TR, INTAKE_UP - INTAKE_MOUTH - 2, segments=12)
    H.cylinder(bm, V((0, -INTAKE_RUN / 2, INTAKE_UP)), TR, INTAKE_RUN, axis="Y", segments=12)


def intake_collars(bm):
    # The funnel (a wide steel skirt), the elbow block over the bay and the tee block on the trunk.
    H.cylinder(bm, V((0, 0, INTAKE_MOUTH + 1.0)), 4.6, 2.0, segments=16, radius2=TR + 0.2)
    H.cylinder(bm, V((0, 0, INTAKE_MOUTH + 0.1)), 4.9, 0.4, segments=16)
    H.rounded_box(bm, V((0, 0, INTAKE_UP)), (4.2, 4.2, 4.2), 0.5, segments=2)
    H.rounded_box(bm, V((0, -INTAKE_RUN, INTAKE_UP)), (5.0, 4.2, 4.2), 0.5, segments=2)
    collar(bm, (0, 0, INTAKE_MOUTH + 4.5), "Z")
    collar(bm, (0, -INTAKE_RUN / 2, INTAKE_UP), "Y")


def intake_hangers(bm):
    for y in (-6.0, -20.0):
        H.cylinder(bm, V((0, y, INTAKE_UP + TR + (TUBE_UP - TR) / 2)), 0.14, TUBE_UP - TR, segments=6)
        H.box(bm, V((0, y, INTAKE_UP)), (2 * TR + 0.5, 0.3, 2 * TR + 0.5))


B.piece("WcTubeBranch_Glass", GLASS, branch_glass)
B.piece("WcTubeBranch_Collars", STEEL, branch_collars)
B.piece("WcTubeBranch_Hangers", STEEL_DARK, branch_hangers, smooth=False)
B.piece("WcTubeTrunk_Glass", GLASS, trunk_glass)
B.piece("WcTubeTrunk_Collars", STEEL, trunk_collars)
B.piece("WcTubeTrunk_Hangers", STEEL_DARK, trunk_hangers, smooth=False)
B.piece("WcTubeIntake_Glass", GLASS, intake_glass)
B.piece("WcTubeIntake_Collars", STEEL, intake_collars)
B.piece("WcTubeIntake_Hangers", STEEL_DARK, intake_hangers, smooth=False)

# ======================================================================= WcTable (round, 5.4 across)


def table_cloth(bm):
    H.lathe_z(bm, [(0.0, 2.75), (2.6, 2.75), (2.7, 2.66), (2.86, 0.9), (2.76, 0.9), (2.5, 2.56), (0.0, 2.56)], 24)
    H.cylinder(bm, V((0, 0, 3.12)), 0.07, 0.55, segments=8)  # the candle


def table_base(bm):
    H.lathe_z(bm, [(0.0, 0.0), (1.3, 0.0), (1.3, 0.14), (0.3, 0.42), (0.22, 2.56), (0.0, 2.56)], 16)


def table_plates(bm):
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        H.cylinder(bm, V((1.75 * math.cos(a), 1.75 * math.sin(a), 2.79)), 0.55, 0.07, segments=14)
    H.cylinder(bm, V((0, 0, 2.81)), 0.3, 0.1, segments=12)  # the candle's dish


def table_flame(bm):
    H.sphere(bm, V((0, 0, 3.52)), 0.12, scale=(1, 1, 1.6), segments=8, rings=6)


B.piece("WcTable_Cloth", CLOTH, table_cloth)
B.piece("WcTable_Base", BRASS, table_base)
B.piece("WcTable_Plates", NAVY, table_plates)
B.piece("WcTable_Flame", GLOW_WARM, table_flame)

# ======================================================================= WcChair (front = the way the sitter faces, -Y)


def chair_frame(bm):
    for sx in (-1, 1):
        H.box(bm, V((sx * 0.72, -0.72, 0.8)), (0.16, 0.16, 1.6))
        H.box(bm, V((sx * 0.72, 0.72, 1.9)), (0.16, 0.16, 3.8))
    H.box(bm, V((0, 0, 1.6)), (1.6, 1.6, 0.14))
    H.rounded_box(bm, V((0, 0.74, 3.1)), (1.5, 0.14, 1.1), 0.05, segments=1)
    H.box(bm, V((0, 0.72, 2.2)), (1.44, 0.1, 0.14))


def chair_cushion(bm):
    H.rounded_box(bm, V((0, -0.02, 1.8)), (1.5, 1.44, 0.28), 0.1, segments=2)
    H.rounded_box(bm, V((0, 0.64, 3.1)), (1.2, 0.1, 0.8), 0.04, segments=1)


B.piece("WcChair_Frame", WOOD, chair_frame, smooth=False)
B.piece("WcChair_Cushion", CUSHION, chair_cushion)

# ======================================================================= WcPendant (hangs; origin = the bulb's underside)


def pendant_cord(bm):
    H.cylinder(bm, V((0, 0, 4.2)), 0.05, 5.6, segments=6)
    H.cylinder(bm, V((0, 0, 6.9)), 0.35, 0.2, segments=12)  # the ceiling rose


def pendant_shade(bm):
    H.lathe_z(bm, [(0.18, 1.5), (0.5, 1.35), (1.25, 0.35), (1.3, 0.2), (1.2, 0.2), (1.16, 0.38), (0.45, 1.25), (0.18, 1.38)], 20)


def pendant_bulb(bm):
    H.sphere(bm, V((0, 0, 0.4)), 0.4, segments=12, rings=8)


B.piece("WcPendant_Cord", BLACK, pendant_cord)
B.piece("WcPendant_Shade", BRASS, pendant_shade)
B.piece("WcPendant_Bulb", GLOW_WARM, pendant_bulb)

# ======================================================================= WcChandelier (hangs; origin = the ring's underside)


def chandelier_ring(bm):
    H.torus(bm, (0, 0, 0.35), 5.0, 0.3, segments=28, sides=8)
    H.torus(bm, (0, 0, 2.6), 2.6, 0.22, segments=20, sides=8)
    for k in range(4):  # rods from the ceiling to the rings
        a = math.pi / 4 + k * math.pi / 2
        H.cylinder(bm, V((2.6 * math.cos(a), 2.6 * math.sin(a), 4.6)), 0.07, 4.0, segments=6)
        tilt = Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(-math.atan2(2.4, 2.25), 4, "Y")
        H.box(bm, V((3.8 * math.cos(a), 3.8 * math.sin(a), 1.48)), (0.12, 0.12, 3.3), rotation=tilt)
    H.cylinder(bm, V((0, 0, 6.5)), 0.9, 0.2, segments=12)


def chandelier_globes(bm):
    for k in range(10):
        a = k * math.tau / 10
        H.sphere(bm, V((5.0 * math.cos(a), 5.0 * math.sin(a), -0.3)), 0.55, segments=10, rings=6)
    for k in range(5):
        a = k * math.tau / 5 + 0.3
        H.sphere(bm, V((2.6 * math.cos(a), 2.6 * math.sin(a), 2.05)), 0.45, segments=10, rings=6)


B.piece("WcChandelier_Ring", BRASS, chandelier_ring)
B.piece("WcChandelier_Globes", GLOW_WARM, chandelier_globes)

# ======================================================================= WcHostStand


def host_body(bm):
    H.rounded_box(bm, V((0, 0, 2.0)), (3.4, 1.6, 4.0), 0.1, segments=2)
    H.rounded_box(bm, V((0, 0, 0.15)), (3.8, 2.0, 0.3), 0.06, segments=1)


def host_trim(bm):
    H.rounded_box(bm, V((0, -0.1, 4.12)), (3.8, 2.0, 0.24), 0.08, segments=2, rotation=Matrix.Rotation(-0.12, 4, "X"))
    H.box(bm, V((0, -0.82, 1.0)), (3.0, 0.05, 0.1))
    H.box(bm, V((0, -0.82, 3.2)), (3.0, 0.05, 0.1))


def host_text(bm):
    B.add_text(bm, "W CHEWS", 0.5, 0.03, H.on_front((0, 0, 0), -0.86, 2.1))


def host_menu(bm):
    H.rounded_box(bm, V((0.4, -0.2, 4.34)), (1.4, 1.0, 0.12), 0.03, segments=1, rotation=Matrix.Rotation(-0.12, 4, "X"))


B.piece("WcHostStand_Body", WOOD, host_body)
B.piece("WcHostStand_Trim", BRASS, host_trim)
B.piece("WcHostStand_Text", BRASS, host_text, smooth=False)
B.piece("WcHostStand_Menu", NAVY, host_menu)

# ======================================================================= WcBar (the chef's service counter, 12 x 3.8)


def bar_body(bm):
    H.box(bm, V((0, 0.2, 1.75)), (12.0, 3.0, 3.5))
    for k in range(3):  # raised panels on the dining side
        H.rounded_box(bm, V((-4.0 + 4.0 * k, -1.34, 1.9)), (3.4, 0.1, 2.3), 0.04, segments=1)
    H.box(bm, V((0, -1.2, 0.2)), (12.0, 0.4, 0.4))  # the plinth


def bar_top(bm):
    H.rounded_box(bm, V((0, 0, 3.66)), (12.0, 3.8, 0.32), 0.1, segments=2)


def bar_trim(bm):
    H.cylinder(bm, V((0, -1.95, 0.75)), 0.1, 12.0, axis="X", segments=8)  # the foot rail
    for x in (-4.0, 0.0, 4.0):
        H.box(bm, V((x, -1.65, 0.75)), (0.12, 0.6, 0.12))
    H.box(bm, V((0, -1.33, 3.36)), (12.0, 0.06, 0.12))  # an inlay under the top's edge


B.piece("WcBar_Body", WOOD, bar_body)
B.piece("WcBar_Top", CLOTH, bar_top)
B.piece("WcBar_Trim", BRASS, bar_trim)

# ======================================================================= WcPlant


def plant_pot(bm):
    H.lathe_z(bm, [(0.0, 0.0), (0.8, 0.0), (1.1, 2.0), (1.0, 2.0), (0.9, 1.7), (0.0, 1.7)], 16)


def plant_leaves(bm):
    # A bush of long leaves: thin pointed blades leaning out all round.
    for k in range(12):
        turn = Matrix.Rotation(k * math.tau / 12 + 0.3 * (k % 3), 4, "Z")
        lean = 0.35 + 0.22 * (k % 3)
        height = 3.4 - 0.5 * (k % 3)
        blade = turn @ Matrix.Rotation(lean, 4, "Y") @ Matrix.Translation((0, 0, height / 2))
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=True, segments=4, radius1=0.42, radius2=0.03, depth=height,
                              matrix=Matrix.Diagonal((1, 0.22, 1, 1)))
        bmesh.ops.transform(tmp, matrix=Matrix.Translation((0, 0, 1.7)) @ blade, verts=tmp.verts[:])
        H._merge(bm, tmp)
    H.cylinder(bm, V((0, 0, 1.8)), 0.92, 0.2, segments=14)  # the soil's cover of moss


B.piece("WcPlant_Pot", TEAL, plant_pot)
B.piece("WcPlant_Leaves", GREEN, plant_leaves, smooth=False)

# ======================================================================= WcStaffDoor (6 wide, 9 tall opening; hinge at x = -3)


def staff_frame(bm):
    # Deeper than the 2-stud wall it stands in, so it wraps the wall's cut edges.
    H.span(bm, (-3.5, -1.2, 0.0), (-3.0, 1.2, 9.5))
    H.span(bm, (3.0, -1.2, 0.0), (3.5, 1.2, 9.5))
    H.span(bm, (-3.5, -1.2, 9.0), (3.5, 1.2, 9.5))


def staff_door(bm):
    H.span(bm, (-2.97, -0.12, 0.05), (2.97, 0.12, 8.97))
    for z0, z1 in ((0.9, 4.0), (4.5, 8.2)):  # raised panels on both faces
        for s in (-1, 1):
            H.span(bm, (-2.3, s * 0.12, z0), (2.3, s * 0.17, z1))


def staff_brass(bm):
    for s in (-1, 1):
        H.span(bm, (-2.9, s * 0.12, 0.1), (2.9, s * 0.16, 0.75))  # the kick plates
        H.sphere(bm, V((2.45, s * 0.4, 4.3)), 0.2, segments=10, rings=6)  # the knobs
        H.cylinder(bm, V((2.45, s * 0.26, 4.3)), 0.07, 0.3, axis="Y", segments=8)
    H.rounded_box(bm, V((0, -0.2, 6.9)), (4.0, 0.08, 1.0), 0.03, segments=1)  # the plaque (kitchen side)


def staff_text(bm):
    B.add_text(bm, "EMPLOYEES ONLY", 0.34, 0.015, H.on_front((0, 0, 0), -0.245, 6.9))


B.piece("WcStaffDoor_Frame", WOOD, staff_frame, smooth=False)
B.piece("WcStaffDoor_Door", DOOR_GREEN, staff_door, smooth=False)
B.piece("WcStaffDoor_DoorBrass", BRASS, staff_brass)
B.piece("WcStaffDoor_DoorText", BLACK, staff_text, smooth=False)

# ----------------------------------------------------------------------- the meat tube is long: its own budgets
for ob in B.coll.objects:
    if ob.name.startswith("WcTube"):
        ob["tri_budget"] = 8000

# Each item's bounds (the game pivots a copy at the bottom centre of its bounds: the layout needs that offset).
bpy.context.view_layer.update()  # the new objects' world matrices
items = {}
for ob in B.coll.objects:
    item = ob.name.split("_")[0]
    for corner in ob.bound_box:
        w = ob.matrix_world @ Vector(corner)
        lo, hi = items.setdefault(item, [list(w), list(w)])
        for i in range(3):
            lo[i] = min(lo[i], w[i])
            hi[i] = max(hi[i], w[i])
bounds = {item: {"low": [round(v, 4) for v in lo], "high": [round(v, 4) for v in hi]} for item, (lo, hi) in sorted(items.items())}

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if argv:
    bpy.ops.wm.save_as_mainfile(filepath=argv[0])
    with open(argv[0].replace(".blend", "_bounds.json"), "w", encoding="utf-8") as handle:
        json.dump(bounds, handle, indent=1)
if len(argv) >= 2:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in B.coll.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=argv[1], export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
tris = sum(len(p.vertices) - 2 for o in B.coll.objects for p in o.data.polygons)
print("WCHEWS KIT BUILT:", len(B.coll.objects), "objects,", tris, "triangles;", sorted(items))
