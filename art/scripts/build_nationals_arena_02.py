# Builds NationalsArena_02: the DETAILED Nationals arena (GAME_DESIGN 39, step 3), after the user approved the blockout
# (NationalsArena_01, "Looks good, detail it", 2026-11-17). References: References/Nationals Arena/Nationals Arena Study.md.
#
# Every repeated part is ONE item the game copies (Roblox draws repeats of one mesh cheaply). Items, each in its own frame
# (1 unit = 1 stud, Z up, front toward -Y, centred on x = 0, standing on z = 0; the game's pivot is the bottom centre of an
# item's bounds, printed as BOUNDS):
#
#   THE BUILDING ON THE PLAZA (every server), from the user's two exterior photos
#     NatBay        one roof bay, 26 wide, 70 deep: a pitched teal standing-seam roof with white trim and a ridge cap,
#                   overhanging the front walkway; the white steel gable truss standing in front of it on a column (the
#                   column on its -X edge); the glass curtain wall up into the gable with dark frames; a brick base; a
#                   warm-lit inside behind the glass; a lamp on the column; a valley gutter. The game sets 6 side by side.
#     NatBayEnd     the last column (+X end) with its lamp.
#     NatPorch      the projecting entrance in the middle: a lower pitched roof, brick piers, glass doors in frames, and a
#                   sign board whose dark SignScreen the game writes NATIONALS and the countdown on.
#     NatEndLeft / NatEndRight   the end walls: white with wood-look panels, a brick base, a corner pier, high windows.
#     NatWalkway    the covered walkway at the +X end: a low pitched canopy on posts.
#   THE HALL (far from the gym, like the State arena)
#     NatFloor      the hall floor: grey concrete, the lifters' floor in dark rubber with white boundary lines.
#     NatStandMain  one 20-wide section of the main stand: a front wall with a blue pipe rail, 18 stepped rows, 8 folding
#                   seats a row (24 triangles a seat), an aisle with half steps and a handrail, the concourse behind. x10.
#     NatStandEnd   one 20-wide section of an end stand: 12 rows, the same seats, a short concourse. x5 each end.
#     NatWall       one 37-wide wall panel, 50 high: a dark base band, the cream wall, a pilaster, a top band. x26.
#     NatRoofBay    one 37-wide roof bay over the whole depth: two sloped dark plates, purlins under them, a ridge beam,
#                   and its gable triangles at both ends. x8.
#     NatTruss      the blue Warren truss spanning front to back under each ridge and valley (the civic-center photos). x15.
#     NatHighBay    a high-bay light (a dish and its lens). The game dims them: the hall is a dark room.
#     NatDrape      one 37-wide panel of white curtain folds for the back wall (the photos). x8.
#     NatStageSet   one platform's set, like the user's YouTube meet: a low stage (rubber top, navy edge with CENTRAL),
#                   steps in the middle of its back edge (v05), a tall purple backdrop with gold and orange flashes and the
#                   NATIONALS / CENTRAL logo, a big video wall above it (its dark Screen the game draws the lifter on), a
#                   dark drape at the +X side and the pipe over both sides. x4. (v04: the backdrop 7 behind the stage.)
#     NatCurtainPanel  one 2.5-wide dark curtain panel (v04): 4 hang side by side at each stage's -X side, the lifter's
#                   way through onto the stage; the game swings the middle two apart as someone walks through. x16.
#     NatCurtainGlow   the stage's light leaking past that curtain (v07): a glowing line in the split, a glowing strip
#                   under the hem. x4.
#     NatCurtainGap / NatCurtainEndL / NatCurtainEndR   plain black curtain runs on a pipe (v08) closing the curtain line
#                   between the stage sets (x3) and out to the side barricades (one each end).
#     NatBanner     the big NATIONALS banner hung over the officials' area: navy cloth, yellow trim, rods and cables.
#     NatCrowdMainA / NatCrowdMainB   seated figures for one main-stand section (blocky, the game's character style,
#                   about 70 triangles a figure, fuller near the front). NatCrowdEnd for an end-stand section. Colour
#                   pieces Skin1-3 / Shirt1-5 / Pants1-2 / Hair1-2 so each section's colourway mixes colours.
#   Reused from the game, not modelled here: the competition rack, referee chairs, plate trees, judges' tables, crowd
#   barricades, benches, chalk stands, the awards podium, camera tripods, the meet desk.
#
# PERFORMANCE: printed per item and in all (TRIANGLES lines). check_models.py must PASS before any export.
# The "Preview" collection assembles copies (sharing the meshes) for the preview renders only.
#
# Run headless:
#   blender -b --python art/scripts/build_nationals_arena_02.py -- <out.blend> <preview folder> [<out.glb>]

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop_helpers as H  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_BLEND = argv[0] if len(argv) > 0 else None
PREVIEW_DIR = argv[1] if len(argv) > 1 else None
OUT_GLB = argv[2] if len(argv) > 2 else None

bpy.ops.wm.read_factory_settings(use_empty=True)
B = H.Builder("NationalsArena_02")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.6, emission=None, strength=3.0):
    m = H.material("NA2_" + name, tuple(linear(c) for c in rgb), metallic, roughness, 1.0, emission)
    if emission is not None:
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Emission Strength"].default_value = strength
    return m


# Preview colours (Roblox colours every piece from StarterGymConfig.PropColourways).
TEAL = mat("RoofTeal", (64, 150, 140), 0.3, 0.45)
WHITE = mat("White", (230, 232, 234), 0.3, 0.4)
TRUSS_WHITE = mat("TrussWhite", (226, 230, 232), 0.6, 0.35)
GLASS = mat("Glass", (48, 70, 88), 0.6, 0.05)
FRAME = mat("Frame", (58, 62, 68), 0.6, 0.4)
INSIDE = mat("InsideGlow", (240, 214, 170), 0.0, 0.6, emission=(1.0, 0.82, 0.55), strength=0.5)
BRICK = mat("Brick", (138, 82, 58), 0.0, 0.85)
WOOD = mat("Wood", (150, 104, 66), 0.0, 0.7)
WALL_WHITE = mat("WallWhite", (228, 226, 220), 0.0, 0.7)
LAMP = mat("Lamp", (255, 236, 200), 0.0, 0.3, emission=(1.0, 0.86, 0.6), strength=10.0)
DARK = mat("Dark", (30, 32, 38), 0.0, 0.6)
SCREEN = mat("Screen", (10, 12, 20), 0.0, 0.1)
NAVY = mat("Navy", (28, 44, 96), 0.0, 0.5)
YELLOW = mat("Yellow", (242, 190, 30), 0.0, 0.4)
TEXT_WHITE = mat("TextWhite", (250, 250, 250), 0.0, 0.4)
CONCRETE = mat("Concrete", (120, 122, 128), 0.0, 0.85)
RUBBER = mat("Rubber", (46, 48, 54), 0.0, 0.9)
LINE_WHITE = mat("Line", (220, 220, 220), 0.0, 0.6)
STEP_GREY = mat("StepGrey", (100, 102, 108), 0.0, 0.85)
SEAT_BLUE = mat("SeatBlue", (34, 64, 140), 0.0, 0.45)
RAIL_BLUE = mat("RailBlue", (40, 96, 190), 0.5, 0.35)
TRUSS_BLUE = mat("TrussBlue", (36, 84, 168), 0.5, 0.4)
HALL_CREAM = mat("HallCream", (206, 200, 188), 0.0, 0.8)
HALL_BAND = mat("HallBand", (70, 72, 80), 0.0, 0.7)
ROOF_IN = mat("RoofInside", (52, 54, 62), 0.0, 0.8)
STEEL = mat("Steel", (170, 172, 178), 0.9, 0.3)
HIGHBAY = mat("HighBayLens", (240, 240, 235), 0.0, 0.3, emission=(1.0, 1.0, 0.95), strength=0.4)
DRAPE_WHITE = mat("DrapeWhite", (214, 214, 218), 0.0, 0.9)
DRAPE_DARK = mat("DrapeDark", (26, 26, 30), 0.0, 0.95)
LEAK = mat("StageLeak", (255, 226, 180), 0.0, 0.5, emission=(1.0, 0.88, 0.7), strength=6.0)
BACKDROP = mat("Backdrop", (74, 36, 120), 0.0, 0.6)
FLASH_GOLD = mat("FlashGold", (230, 176, 40), 0.0, 0.4)
FLASH_ORANGE = mat("FlashOrange", (236, 110, 30), 0.0, 0.4)
BLACK = mat("Black", (20, 20, 22), 0.0, 0.7)
SKINS = [mat("Skin1", (232, 190, 160)), mat("Skin2", (190, 136, 96)), mat("Skin3", (112, 72, 50))]
SHIRTS = [mat("Shirt1", (200, 30, 38)), mat("Shirt2", (30, 92, 205)), mat("Shirt3", (242, 190, 30)),
          mat("Shirt4", (236, 236, 232)), mat("Shirt5", (0, 138, 140))]
PANTS = [mat("Pants1", (30, 48, 98)), mat("Pants2", (46, 48, 54))]
HAIRS = [mat("Hair1", (30, 24, 20)), mat("Hair2", (110, 74, 40))]
EYES = mat("Eyes", (20, 20, 24))


# ---------------------------------------------------------------- shape helpers

def prism(bm, outline_xz, y0, y1):
    """A closed solid: a convex (x, z) outline pushed from y = y0 to y = y1."""
    tmp = bmesh.new()
    a = [tmp.verts.new((x, y0, z)) for x, z in outline_xz]
    b = [tmp.verts.new((x, y1, z)) for x, z in outline_xz]
    n = len(outline_xz)
    tmp.faces.new(a)
    tmp.faces.new(list(reversed(b)))
    for i in range(n):
        j = (i + 1) % n
        tmp.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)


def prism_y(bm, outline_yz, x0, x1):
    """A closed solid: a convex (y, z) outline pushed from x = x0 to x = x1."""
    tmp = bmesh.new()
    a = [tmp.verts.new((x0, y, z)) for y, z in outline_yz]
    b = [tmp.verts.new((x1, y, z)) for y, z in outline_yz]
    n = len(outline_yz)
    tmp.faces.new(a)
    tmp.faces.new(list(reversed(b)))
    for i in range(n):
        j = (i + 1) % n
        tmp.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)


def beam(bm, p0, p1, thick):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    rot = d.to_track_quat("X", "Z").to_matrix().to_4x4()
    H.box(bm, (p0 + p1) / 2, (d.length, thick, thick), rot)


def slab(bm, a, b, y0, y1, thick):
    """A sloped plate from (x, z) a to b, from y0 to y1, `thick` below the line."""
    (ax, az), (bx, bz) = a, b
    dx, dz = bx - ax, bz - az
    ln = math.hypot(dx, dz)
    nx, nz = -dz / ln * thick, dx / ln * thick
    if nz > 0:
        nx, nz = -nx, -nz
    prism(bm, [(ax, az), (bx, bz), (bx + nx, bz + nz), (ax + nx, az + nz)], y0, y1)


def folds(bm, x0, x1, y_front, depth, z0, z1, count):
    """A curtain: a zigzag front (count folds) and a flat back, closed."""
    tmp = bmesh.new()
    pts = []
    for k in range(count * 2 + 1):
        x = x0 + (x1 - x0) * k / (count * 2)
        y = y_front + (depth * 0.6 if k % 2 else 0.0)
        pts.append((x, y))
    back_y = y_front + depth
    outline = pts + [(x1, back_y), (x0, back_y)]
    lo = [tmp.verts.new((x, y, z0)) for x, y in outline]
    hi = [tmp.verts.new((x, y, z1)) for x, y in outline]
    n = len(outline)
    tmp.faces.new(lo)
    tmp.faces.new(list(reversed(hi)))
    for i in range(n):
        j = (i + 1) % n
        tmp.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)


# ---------------------------------------------------------------- items

ITEMS = {}   # item name -> list of objects (built at the origin, in the item's frame)


def piece(item, name, material, build):
    obj = B.piece("%s_%s" % (item, name), material, build, smooth=False)
    ITEMS.setdefault(item, []).append(obj)
    return obj


def text(bm, words, size, y, z, x=0.0, extrude=0.06):
    B.add_text(bm, words, size, extrude, H.on_front((x, 0, 0), y, z))


# ================================================================ THE BUILDING

BAY_W, DEPTH = 26.0, 70.0
EAVE, RIDGE, OVERHANG, COL_Y = 22.0, 36.0, 9.0, -7.0
HALF = BAY_W / 2


def gable_z(x):
    """The roof line's height over x in a bay (x from -13 to 13)."""
    return EAVE + (RIDGE - EAVE) * (1 - abs(x) / HALF)


def build_bay():
    item = "NatBay"

    def roof(bm):
        slab(bm, (-HALF, EAVE), (0, RIDGE), -OVERHANG, DEPTH, 0.6)
        slab(bm, (0, RIDGE), (HALF, EAVE), -OVERHANG, DEPTH, 0.6)

    def trim(bm):
        # The white fascia along both sloped front edges, the ridge cap and the standing seams' end lines.
        for sx in (-1, 1):
            beam(bm, (sx * HALF, -OVERHANG - 0.2, EAVE + 0.2), (0, -OVERHANG - 0.2, RIDGE + 0.2), 0.7)
        beam(bm, (0, -OVERHANG, RIDGE + 0.35), (0, DEPTH, RIDGE + 0.35), 0.6)
        # Standing seams along the roof: a raised rib every 2.6 studs.
        for k in range(1, 5):
            for sx in (-1, 1):
                x = sx * HALF * k / 5
                z = gable_z(x) + 0.12
                beam(bm, (x, -OVERHANG, z), (x, DEPTH, z), 0.18)

    def truss(bm):
        y, t = COL_Y, 0.7
        tl, tr, pk = Vector((-HALF, y, EAVE - 0.8)), Vector((HALF, y, EAVE - 0.8)), Vector((0, y, RIDGE - 1.6))
        bl, br = Vector((-HALF, y, EAVE - 3.4)), Vector((HALF, y, EAVE - 3.4))
        beam(bm, tl, pk, t)
        beam(bm, pk, tr, t)
        beam(bm, bl, br, t)
        steps = 8

        def top(f):
            return tl.lerp(pk, f * 2) if f <= 0.5 else pk.lerp(tr, (f - 0.5) * 2)

        for k in range(steps):
            f0, f1 = k / steps, (k + 1) / steps
            b0, b1 = bl.lerp(br, f0), bl.lerp(br, f1)
            beam(bm, b0, top(f1) if k < steps / 2 else top(f0), 0.42)
            beam(bm, b1 if k < steps / 2 else b0, top(f1) if k < steps / 2 else top(f0), 0.42)
        # Beams back to the wall under the overhang (at the ridge and both eaves).
        for x, z in ((0, RIDGE - 1.6), (-HALF, EAVE - 0.8), (HALF, EAVE - 0.8)):
            beam(bm, (x, y, z), (x, 0, z), 0.5)

    def column(bm):
        # The column on the bay's -X line, with a base plate (its own piece: the game leaves it out where the porch
        # stands).
        H.box(bm, (-HALF, COL_Y, EAVE / 2), (1.0, 1.0, EAVE))
        H.box(bm, (-HALF, COL_Y, 0.15), (1.8, 1.8, 0.3))

    def glass(bm):
        prism(bm, [(-HALF + 0.8, 3), (HALF - 0.8, 3), (HALF - 0.8, EAVE - 0.5), (0, RIDGE - 1.2), (-HALF + 0.8, EAVE - 0.5)],
              -0.3, 0.3)

    def frames(bm):
        t, y = 0.35, -0.45
        inner = HALF - 0.8
        for k in range(1, 6):
            x = -inner + k * 2 * inner / 6
            top = (EAVE - 0.5) + ((RIDGE - 1.2) - (EAVE - 0.5)) * (1 - abs(x) / inner)
            H.span(bm, (x - t / 2, y - t / 2, 3), (x + t / 2, y + t / 2, top))
        for z in (8.0, 13.5, EAVE - 0.6):
            H.span(bm, (-inner, y - t / 2, z - t / 2), (inner, y + t / 2, z + t / 2))
        # The outline of the glass.
        for sx in (-1, 1):
            H.span(bm, (sx * inner - t / 2, y - t / 2, 3), (sx * inner + t / 2, y + t / 2, EAVE - 0.5))
            beam(bm, (sx * inner, y, EAVE - 0.5), (0, y, RIDGE - 1.2), t)

    def inside(bm):
        # A warm-lit wall a little behind the glass, so the glass shows a lit hall rather than nothing.
        prism(bm, [(-HALF, 0), (HALF, 0), (HALF, EAVE), (0, RIDGE - 1), (-HALF, EAVE)], 5.0, 5.6)

    def walls(bm):
        # The hall's shell behind (its sides are shared with the next bay; the roof covers its top).
        H.span(bm, (-HALF, 0.4, 0), (HALF, DEPTH, 3.0))
        H.span(bm, (-HALF, DEPTH - 0.8, 0), (HALF, DEPTH, EAVE))
        # The back gable, closing the roof's triangle at the rear.
        prism(bm, [(-HALF, EAVE), (HALF, EAVE), (0, RIDGE - 0.6)], DEPTH - 0.8, DEPTH)

    def brick(bm):
        H.span(bm, (-HALF, -0.8, 0), (HALF, 0.4, 3))
        H.span(bm, (-HALF, -0.9, 2.9), (HALF, 0.5, 3.3))

    def lamp(bm):
        H.box(bm, (-HALF, COL_Y - 0.95, EAVE - 6), (1.4, 0.9, 0.8))

    def lamp_arm(bm):
        H.box(bm, (-HALF, COL_Y - 0.7, EAVE - 5.5), (0.3, 0.6, 0.3))

    def gutter(bm):
        # The valley gutter on the bay's -X line, and its downpipe on the column.
        H.span(bm, (-HALF - 0.5, -OVERHANG, EAVE - 0.4), (-HALF + 0.5, DEPTH, EAVE + 0.1))
        H.box(bm, (-HALF + 0.65, COL_Y + 0.4, EAVE / 2), (0.3, 0.3, EAVE))

    piece(item, "Roof", TEAL, roof)
    piece(item, "Trim", WHITE, trim)
    piece(item, "Truss", TRUSS_WHITE, truss)
    piece(item, "Column", TRUSS_WHITE, column)
    piece(item, "Glass", GLASS, glass)
    piece(item, "Frames", FRAME, frames)
    piece(item, "Inside", INSIDE, inside)
    piece(item, "Walls", WALL_WHITE, walls)
    piece(item, "Brick", BRICK, brick)
    piece(item, "Lamp", LAMP, lamp)
    piece(item, "LampArm", DARK, lamp_arm)
    piece(item, "Gutter", FRAME, gutter)


def build_bay_end():
    item = "NatBayEnd"
    piece(item, "Column", TRUSS_WHITE, lambda bm: (H.box(bm, (0, 0, EAVE / 2), (1.0, 1.0, EAVE)),
                                                   H.box(bm, (0, 0, 0.15), (1.8, 1.8, 0.3))))
    piece(item, "Lamp", LAMP, lambda bm: H.box(bm, (0, -0.95, EAVE - 6), (1.4, 0.9, 0.8)))
    piece(item, "LampArm", DARK, lambda bm: H.box(bm, (0, -0.7, EAVE - 5.5), (0.3, 0.6, 0.3)))


PORCH_W, PORCH_D, PORCH_EAVE, PORCH_RIDGE = 22.0, 11.0, 15.0, 22.0


def build_porch():
    item = "NatPorch"
    hw = PORCH_W / 2

    def roof(bm):
        slab(bm, (-hw - 1, PORCH_EAVE), (0, PORCH_RIDGE), -PORCH_D - 1.5, 0, 0.5)
        slab(bm, (0, PORCH_RIDGE), (hw + 1, PORCH_EAVE), -PORCH_D - 1.5, 0, 0.5)

    def trim(bm):
        for sx in (-1, 1):
            beam(bm, (sx * (hw + 1), -PORCH_D - 1.7, PORCH_EAVE + 0.15), (0, -PORCH_D - 1.7, PORCH_RIDGE + 0.15), 0.55)
        beam(bm, (0, -PORCH_D - 1.5, PORCH_RIDGE + 0.3), (0, 0, PORCH_RIDGE + 0.3), 0.5)

    def piers(bm):
        for sx in (-1, 1):
            H.span(bm, (sx * hw - 1.2, -PORCH_D - 0.8, 0), (sx * hw + 1.2, 0, PORCH_EAVE))
            H.span(bm, (sx * hw - 1.4, -PORCH_D - 1.0, PORCH_EAVE - 1.0), (sx * hw + 1.4, 0, PORCH_EAVE - 0.4))

    def gable(bm):
        # The white gable above the doors (the sign board hangs on it).
        prism(bm, [(-hw + 1, PORCH_EAVE - 3), (hw - 1, PORCH_EAVE - 3), (hw - 1, PORCH_EAVE), (0, PORCH_RIDGE - 0.8),
                   (-hw + 1, PORCH_EAVE)], -PORCH_D - 0.6, -PORCH_D + 0.2)

    def glass(bm):
        H.span(bm, (-hw + 1.2, -PORCH_D - 0.3, 0.2), (hw - 1.2, -PORCH_D + 0.3, PORCH_EAVE - 3))

    def frames(bm):
        t, y = 0.35, -PORCH_D - 0.45
        for k in range(-3, 4):
            x = k * (PORCH_W - 2.4) / 6
            H.span(bm, (x - t / 2, y - t / 2, 0.2), (x + t / 2, y + t / 2, PORCH_EAVE - 3))
        for z in (0.35, 8.4, PORCH_EAVE - 3.1):
            H.span(bm, (-hw + 1.2, y - t / 2, z - t / 2), (hw - 1.2, y + t / 2, z + t / 2))

    def handles(bm):
        for x in (-1.0, 1.0):
            H.box(bm, (x, -PORCH_D - 0.75, 4.2), (0.2, 0.3, 2.4))

    def sign_frame(bm):
        H.span(bm, (-hw + 1.6, -PORCH_D - 1.3, PORCH_EAVE - 2.6), (hw - 1.6, -PORCH_D - 0.6, PORCH_EAVE + 3.6))

    def sign_screen(bm):
        # The dark face the game writes NATIONALS and the countdown on.
        H.span(bm, (-hw + 2.1, -PORCH_D - 1.45, PORCH_EAVE - 2.1), (hw - 2.1, -PORCH_D - 1.25, PORCH_EAVE + 3.1))

    def inside(bm):
        H.span(bm, (-hw + 1, -PORCH_D + 3, 0), (hw - 1, -PORCH_D + 3.6, PORCH_EAVE - 2))

    piece(item, "Roof", TEAL, roof)
    piece(item, "Trim", WHITE, trim)
    piece(item, "Piers", BRICK, piers)
    piece(item, "Gable", WALL_WHITE, gable)
    piece(item, "Glass", GLASS, glass)
    piece(item, "Frames", FRAME, frames)
    piece(item, "Handles", STEEL, handles)
    piece(item, "SignFrame", NAVY, sign_frame)
    piece(item, "SignScreen", SCREEN, sign_screen)
    piece(item, "Inside", INSIDE, inside)


def build_end(item, side):
    """An end wall facing `side` (-1 = -X, +1 = +X), from the front glass line back the whole depth."""
    s = side

    def wall(bm):
        H.span(bm, (s * 0.0, 0.0, 0), (s * 1.2, DEPTH, EAVE))

    def wood(bm):
        for y0, y1 in ((4.0, 22.0), (26.0, 44.0), (48.0, 66.0)):
            H.span(bm, (s * 1.2, y0, 7.5), (s * 1.6, y1, EAVE - 2.5))

    def brick(bm):
        H.span(bm, (s * 1.2, -0.8, 0), (s * 1.9, DEPTH, 7.5))
        H.span(bm, (s * 1.2, -0.9, 0), (s * 2.6, 2.0, EAVE))  # the corner pier

    def windows(bm):
        for y0, y1 in ((8.0, 18.0), (30.0, 40.0), (52.0, 62.0)):
            H.span(bm, (s * 1.6, y0, EAVE - 2.2), (s * 1.75, y1, EAVE - 0.8))

    def fix(objects):
        return objects

    piece(item, "Wall", WALL_WHITE, wall)
    piece(item, "Wood", WOOD, wood)
    piece(item, "Brick", BRICK, brick)
    piece(item, "Windows", GLASS, windows)


def build_walkway():
    item = "NatWalkway"

    def roof(bm):
        slab(bm, (0, 11), (10, 13.5), -14, 8, 0.35)
        slab(bm, (10, 13.5), (20, 11), -14, 8, 0.35)

    def posts(bm):
        for x in (1.5, 18.5):
            for y in (-12.0, 6.0):
                H.box(bm, (x, y, 5.6), (0.6, 0.6, 11.2))
        for y in (-12.0, 6.0):
            H.span(bm, (1.5, y - 0.3, 10.6), (18.5, y + 0.3, 11.1))

    piece(item, "Roof", TEAL, roof)
    piece(item, "Posts", TRUSS_WHITE, posts)


# ================================================================ THE HALL

# The hall (version 03, user 2026-11-17: "make the shell bigger", wider gaps between the platforms): 336 x 210.
WALL_X, WALL_Y_FRONT, WALL_Y_BACK, WALL_Z = 168.0, -110.0, 100.0, 50.0
PANEL_W = 42.0
ROOF_BAYS, HALL_RIDGE = 8, 62.0
FLOOR_X, RAIL_Y = 120.0, -42.0
MAIN_SECTIONS = 12
SIDE_PANELS = 5  # 5 x 42 = the hall's 210 depth
# The white line between the lifters' zone (behind the backdrops) and the warm-up area; spectators stay on the far side.
# (v04, 2026-11-18: 7 further back with the backdrops, which moved back 5 from the stages.)
WHITE_LINE_Y = 41.0
SECTION_W = 20.0
ROW_D, ROW_RISE, ROW_BASE = 3.0, 1.6, 2.5
MAIN_ROWS, END_ROWS = 18, 12
FRONT_WALL_D = 0.8
SEATS = 8
AISLE_W = 2.4
SEAT_SLOT = (SECTION_W - AISLE_W) / SEATS
MAIN_CONCOURSE, END_CONCOURSE = 10.0, 6.0
# End-stand sections a side, from the floor's front (y -40) to the backdrops' line (y 20).
END_SECTIONS = 3
PLATFORM_XS = (-78.0, -26.0, 26.0, 78.0)


def seat_xs():
    x0 = -SECTION_W / 2 + AISLE_W
    return [x0 + SEAT_SLOT * (i + 0.5) for i in range(SEATS)]


def row_front(k):
    return FRONT_WALL_D + k * ROW_D


def row_top(k):
    return ROW_BASE + k * ROW_RISE


def build_floor():
    item = "NatFloor"
    piece(item, "Concrete", CONCRETE, lambda bm: H.span(bm, (-WALL_X, WALL_Y_FRONT, -1), (WALL_X, WALL_Y_BACK, 0)))
    piece(item, "Rubber", RUBBER, lambda bm: H.span(bm, (-FLOOR_X, RAIL_Y, 0), (FLOOR_X, WALL_Y_BACK - 3, 0.06)))

    def lines(bm):
        w = 0.35
        y0, y1 = RAIL_Y + 2, WALL_Y_BACK - 5
        for x in (-FLOOR_X + 2, FLOOR_X - 2):
            H.span(bm, (x - w / 2, y0, 0.06), (x + w / 2, y1, 0.09))
        for y in (y0, y1, WHITE_LINE_Y):
            H.span(bm, (-FLOOR_X + 2, y - w / 2, 0.06), (FLOOR_X - 2, y + w / 2, 0.09))

    piece(item, "Lines", LINE_WHITE, lines)


def build_stand(item, rows, concourse):
    """One 20-wide stand section facing -Y: the front wall with its rail at y = 0, rows rising toward +Y."""
    depth = row_front(rows) + concourse
    top_last = row_top(rows - 1)

    def steps(bm):
        H.span(bm, (-SECTION_W / 2, 0, 0), (SECTION_W / 2, FRONT_WALL_D, ROW_BASE + 0.6))
        for k in range(rows):
            H.span(bm, (-SECTION_W / 2, row_front(k), 0), (SECTION_W / 2, row_front(k + 1), row_top(k)))
        H.span(bm, (-SECTION_W / 2, row_front(rows), 0), (SECTION_W / 2, depth, top_last + 0.6))

    def aisle(bm):
        # Half steps in the aisle at the section's -X edge.
        for k in range(rows):
            H.span(bm, (-SECTION_W / 2 + 0.2, row_front(k), row_top(k)), (-SECTION_W / 2 + AISLE_W - 0.2, row_front(k) + 1.5,
                                                                            row_top(k) + ROW_RISE / 2))

    def seats(bm, k_range):
        for k in k_range:
            yf, z = row_front(k), row_top(k)
            for x in seat_xs():
                H.box(bm, (x, yf + 1.15, z + 1.05), (SEAT_SLOT - 0.45, 1.3, 0.25))
                H.box(bm, (x, yf + 1.95, z + 1.8), (SEAT_SLOT - 0.45, 0.25, 1.3))

    def rails(bm):
        top = ROW_BASE + 0.6
        H.span(bm, (-SECTION_W / 2, 0.3, top + 3.0), (SECTION_W / 2, 0.55, top + 3.3))
        H.span(bm, (-SECTION_W / 2, 0.3, top + 1.6), (SECTION_W / 2, 0.5, top + 1.75))
        for x in (-SECTION_W / 2 + 0.3, -SECTION_W / 2 + 5.3, 0.3, SECTION_W / 2 - 4.7):
            H.box(bm, (x, 0.42, top + 1.6), (0.25, 0.25, 3.3))
        # The aisle handrail.
        x = -SECTION_W / 2 + AISLE_W - 0.25
        beam(bm, (x, row_front(0), row_top(0) + 3.0), (x, row_front(rows - 1) + 1.5, row_top(rows - 1) + 3.0), 0.22)
        for k in range(0, rows, 3):
            H.box(bm, (x, row_front(k) + 0.75, row_top(k) + 1.5), (0.2, 0.2, 3.0))

    piece(item, "Steps", STEP_GREY, steps)
    piece(item, "Aisle", CONCRETE, aisle)
    if rows > 12:
        half = rows // 2
        piece(item, "SeatsLower", SEAT_BLUE, lambda bm: seats(bm, range(half)))
        piece(item, "SeatsUpper", SEAT_BLUE, lambda bm: seats(bm, range(half, rows)))
    else:
        piece(item, "Seats", SEAT_BLUE, lambda bm: seats(bm, range(rows)))
    piece(item, "Rails", RAIL_BLUE, rails)


def build_wall():
    item = "NatWall"
    piece(item, "Band", HALL_BAND, lambda bm: H.span(bm, (-PANEL_W / 2, 0, 0), (PANEL_W / 2, 1.2, 5)))
    piece(item, "Wall", HALL_CREAM, lambda bm: H.span(bm, (-PANEL_W / 2, 0.2, 5), (PANEL_W / 2, 1.2, WALL_Z)))
    piece(item, "Pilaster", HALL_BAND, lambda bm: (H.span(bm, (-PANEL_W / 2, -0.6, 0), (-PANEL_W / 2 + 2.0, 0.4, WALL_Z)),
                                                    H.span(bm, (-PANEL_W / 2, -0.4, WALL_Z - 3), (PANEL_W / 2, 0.4, WALL_Z - 2.2))))


def build_roof_bay():
    item = "NatRoofBay"
    w = PANEL_W / 2
    y0, y1 = WALL_Y_FRONT - 1, WALL_Y_BACK + 1

    def plates(bm):
        slab(bm, (-w, WALL_Z), (0, HALL_RIDGE), y0, y1, 0.8)
        slab(bm, (0, HALL_RIDGE), (w, WALL_Z), y0, y1, 0.8)

    def purlins(bm):
        for k in range(1, 4):
            for sx in (-1, 1):
                x = sx * w * k / 4
                z = WALL_Z + (HALL_RIDGE - WALL_Z) * (1 - abs(x) / w) - 1.2
                beam(bm, (x, y0 + 1, z), (x, y1 - 1, z), 0.5)

    def gables(bm):
        for y in (WALL_Y_FRONT, WALL_Y_BACK):
            prism(bm, [(-w, WALL_Z), (w, WALL_Z), (0, HALL_RIDGE)], y - 1, y + 1)

    piece(item, "Plates", ROOF_IN, plates)
    piece(item, "Purlins", STEEL, purlins)
    piece(item, "Gables", HALL_CREAM, gables)


def build_truss():
    item = "NatTruss"

    def truss(bm):
        y0, y1, depth = WALL_Y_FRONT + 1.5, WALL_Y_BACK - 1.5, 6.0
        beam(bm, (0, y0, 0), (0, y1, 0), 0.8)
        beam(bm, (0, y0, -depth), (0, y1, -depth), 0.8)
        n = int((y1 - y0) / 7.5)
        for k in range(n + 1):
            y = y0 + k * (y1 - y0) / n
            beam(bm, (0, y, -depth), (0, y, 0), 0.4)
            if k < n:
                yn = y0 + (k + 1) * (y1 - y0) / n
                beam(bm, (0, y, -depth) if k % 2 == 0 else (0, y, 0), (0, yn, 0) if k % 2 == 0 else (0, yn, -depth), 0.4)

    piece(item, "Steel", TRUSS_BLUE, truss)


def build_highbay():
    item = "NatHighBay"
    piece(item, "Dish", DARK, lambda bm: (H.cylinder(bm, (0, 0, -0.6), 1.3, 1.2, segments=12, radius2=0.5),
                                          H.box(bm, (0, 0, 0.5), (0.2, 0.2, 1.2))))
    piece(item, "Lens", HIGHBAY, lambda bm: H.cylinder(bm, (0, 0, -1.25), 1.15, 0.1, segments=12))


def build_drape():
    item = "NatDrape"
    piece(item, "Cloth", DRAPE_WHITE, lambda bm: folds(bm, -PANEL_W / 2, PANEL_W / 2, 0, 1.4, 0, 44, 14))
    piece(item, "Pipe", STEEL, lambda bm: H.cylinder(bm, (0, 0.7, 44.4), 0.18, PANEL_W, axis="X", segments=8))


STAGE_W, STAGE_D, STAGE_H = 24.0, 18.0, 1.2
STEPS_W = 5.0                # the steps up at the middle of the stage's back edge
# (v04, user 2026-11-18: "you might want to place the banner farther back": the backdrop and its video wall 5 further back
#  from the stage, 7 behind its back edge, so the camera behind a lifter at the bar has room in front of it.)
BACKDROP_Y, BACKDROP_W, BACKDROP_H = 25.0, 28.0, 15.0
VIDEO_Z0, VIDEO_Z1 = 15.5, 29.0
# The curtains' top (the pipe hangs just above it).
CURTAIN_TOP = VIDEO_Z1 + 0.4
# The +X curtain: one narrow fixed drape beside the backdrop, as before.
CURTAIN_R_W = 3.55
# The -X curtain, the lifter's way onto the stage (v04, user 2026-11-18: "extend the curtain farther, so ... the lifter can
# be waiting with the flow state animation then once the user clicks, they are seen using their arms and moving the
# curtain to enter the platform"): 4 panels of NatCurtainPanel side by side, 10 wide. The middle two hang either side of
# the split the lifter pushes through; the game swings them apart (NationalsCurtains) as someone walks through.
CURTAIN_PANEL_W, CURTAIN_PANELS = 2.5, 4
CURTAIN_HEM = 0.3            # the panels stop this far off the floor: the stage's light shows under them
CURTAIN_L_EDGE = -(BACKDROP_W / 2 + 0.05 + CURTAIN_PANEL_W * CURTAIN_PANELS)
CURTAIN_SPLIT_X = -(BACKDROP_W / 2 + 0.05 + CURTAIN_PANEL_W * CURTAIN_PANELS / 2)
CURTAIN_R_EDGE = BACKDROP_W / 2 + 0.05 + CURTAIN_R_W


def build_stage_set():
    item = "NatStageSet"
    hw = STAGE_W / 2

    def riser(bm):
        H.span(bm, (-hw, 0.3, 0), (hw, STAGE_D, STAGE_H - 0.1))

    def top(bm):
        H.span(bm, (-hw + 0.2, 0.5, STAGE_H - 0.1), (hw - 0.2, STAGE_D - 0.2, STAGE_H))

    def edge(bm):
        # The navy band round the front and sides (the YouTube stage's branded edge).
        H.span(bm, (-hw - 0.15, 0.0, 0), (hw + 0.15, 0.32, STAGE_H + 0.02))
        for sx in (-1, 1):
            H.span(bm, (sx * hw - 0.15, 0.0, 0), (sx * hw + 0.15, STAGE_D, STAGE_H + 0.02))

    def edge_logo(bm):
        for x in (-7.0, 7.0):
            text(bm, "CENTRAL", 0.75, -0.02, STAGE_H / 2, x, 0.03)

    def steps(bm):
        # Two steps at the middle of the BACK edge (v05, user 2026-11-18: "when im entering the platform, i need to be
        # walking from the curtain, to behind the platform. Not with the stairs on the right side in the middle"): the
        # lifter comes through the curtain, along behind the stage and up here, then straight in to the bar (the rack's
        # open side faces the back; from the side they walked through the rack's frame).
        for k, h in enumerate((STAGE_H / 3 * 2, STAGE_H / 3)):
            H.span(bm, (-STEPS_W / 2, STAGE_D + 1.2 * k, 0), (STEPS_W / 2, STAGE_D + 1.2 * (k + 1), h))

    def backdrop(bm):
        H.span(bm, (-BACKDROP_W / 2, BACKDROP_Y, 0), (BACKDROP_W / 2, BACKDROP_Y + 1, BACKDROP_H))

    def flash(bm, colour_offset):
        # Diagonal streaks across the backdrop's face (the event print's gold and orange flashes).
        y = BACKDROP_Y - 0.06
        for i, (x0, z0, ln) in enumerate(((-13.0, 2.0, 9.0), (-11.0, 9.5, 7.0), (6.0, 1.0, 8.0), (8.5, 10.0, 5.5))):
            if i % 2 != colour_offset:
                continue
            x1 = min(x0 + ln, BACKDROP_W / 2 - 0.2)
            prism(bm, [(x0, z0), (x1, z0 + 1.6), (x1, z0 + 2.4), (x0, z0 + 0.8)], y, y + 0.08)

    def logo(bm):
        text(bm, "NATIONALS", 2.6, BACKDROP_Y - 0.1, 8.2, 0, 0.05)
        text(bm, "CENTRAL", 1.2, BACKDROP_Y - 0.1, 5.4, 0, 0.05)

    def video_frame(bm):
        H.span(bm, (-BACKDROP_W / 2 + 0.5, BACKDROP_Y + 0.1, VIDEO_Z0 - 0.4), (BACKDROP_W / 2 - 0.5, BACKDROP_Y + 1.3, VIDEO_Z1 + 0.4))

    def screen(bm):
        H.span(bm, (-BACKDROP_W / 2 + 1.1, BACKDROP_Y - 0.02, VIDEO_Z0 + 0.2), (BACKDROP_W / 2 - 1.1, BACKDROP_Y + 0.1, VIDEO_Z1 - 0.2))

    # The curtains stand in line with the backdrop and the video wall (user 2026-11-17: "the curtain stands need to line up
    # with the platform screens"): right beside their edges, in the same plane, as tall as the video wall. Here only the
    # +X one; the -X one (the lifter's way through, v04) is 4 NatCurtainPanel copies the game places and swings.
    def drapes(bm):
        x0 = BACKDROP_W / 2 + 0.05
        folds(bm, x0, CURTAIN_R_EDGE, BACKDROP_Y - 0.4, 1.2, 0, CURTAIN_TOP, 5)

    def pipe(bm):
        left, right = CURTAIN_L_EDGE - 0.2, CURTAIN_R_EDGE + 0.2
        # (the pipe runs a little behind the curtains' backs: y + 0.2 is inside their 1.2 depth, so the swung panels'
        #  tops stay hidden behind it)
        H.cylinder(bm, ((left + right) / 2, BACKDROP_Y + 0.2, VIDEO_Z1 + 0.7), 0.2, right - left, axis="X", segments=8)
        for x in (left, right):
            H.box(bm, (x, BACKDROP_Y + 0.2, (VIDEO_Z1 + 0.7) / 2), (0.4, 0.4, VIDEO_Z1 + 0.7))
            H.box(bm, (x, BACKDROP_Y + 0.2, 0.1), (2.4, 2.4, 0.2))

    piece(item, "Riser", BLACK, riser)
    piece(item, "Top", RUBBER, top)
    piece(item, "Edge", NAVY, edge)
    piece(item, "EdgeLogo", TEXT_WHITE, edge_logo)
    piece(item, "Steps", BLACK, steps)
    piece(item, "Backdrop", BACKDROP, backdrop)
    piece(item, "FlashGold", FLASH_GOLD, lambda bm: flash(bm, 0))
    piece(item, "FlashOrange", FLASH_ORANGE, lambda bm: flash(bm, 1))
    piece(item, "Logo", TEXT_WHITE, logo)
    piece(item, "VideoFrame", BLACK, video_frame)
    piece(item, "Screen", SCREEN, screen)
    piece(item, "Drapes", DRAPE_DARK, drapes)
    piece(item, "Pipe", STEEL, pipe)


def pleats(bm, x0, x1, y_front, depth, thick, z0, z1, count):
    """A hanging cloth folded both sides: the same zigzag front and back, `thick` apart (a curtain seen from behind
    shows its folds too), closed."""
    tmp = bmesh.new()
    zig = []
    for k in range(count * 2 + 1):
        x = x0 + (x1 - x0) * k / (count * 2)
        zig.append((x, y_front + (depth if k % 2 else 0.0)))
    outline = zig + [(x, y + thick) for x, y in reversed(zig)]
    lo = [tmp.verts.new((x, y, z0)) for x, y in outline]
    hi = [tmp.verts.new((x, y, z1)) for x, y in outline]
    n = len(outline)
    tmp.faces.new(lo)
    tmp.faces.new(list(reversed(hi)))
    for i in range(n):
        j = (i + 1) % n
        tmp.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)


def build_curtain_panel():
    """One 2.5-wide panel of the lifter's curtain (v04): 4 folds on BOTH faces (the walk-out's cinematic looks at its
    back), its front at y = 0, hanging from the pipe's height to CURTAIN_HEM off the floor. The game hangs 4 side by side
    at each stage's -X side and swings the middle two apart."""
    item = "NatCurtainPanel"
    piece(item, "Cloth", DRAPE_DARK, lambda bm: pleats(bm, -CURTAIN_PANEL_W / 2, CURTAIN_PANEL_W / 2, 0, 0.75, 0.18,
                                                        CURTAIN_HEM, CURTAIN_TOP, 4))


CURTAIN_BACK = 0.93          # NatCurtainPanel's depth (its folds' backs)
# The stage sets' outer edges (with the pipe's uprights) and the meet area's side barricades (the game's MEET_SIDE_X).
SET_LEFT, SET_RIGHT, MEET_SIDE_X = CURTAIN_L_EDGE - 0.4, CURTAIN_R_EDGE + 0.4, 106.0
CURTAIN_RUNS = {
    # (user 2026-11-18: "you need to place a curtain that coveres these open areas"): the curtain line closed all the
    # way across, so nobody sees past the stage sets into the lifters' zone and the warm-up area.
    "NatCurtainGap": (PLATFORM_XS[1] - PLATFORM_XS[0]) + SET_LEFT - SET_RIGHT,   # between two stage sets
    "NatCurtainEndL": (PLATFORM_XS[0] + SET_LEFT) + MEET_SIDE_X,                 # the -X end set to the side barricade
    "NatCurtainEndR": MEET_SIDE_X - (PLATFORM_XS[-1] + SET_RIGHT),               # the +X end set to the side barricade
}


def build_curtain_runs():
    """Plain black curtain runs (pleated both faces, the lifter's curtain's folds) on their own pipe, closing the curtain
    line between the stage sets and out to the side barricades. Each item's frame: x centred, its front at y 0. The end
    runs carry an upright at their outer end (the gaps' ends are the sets' own uprights)."""
    for item, width in CURTAIN_RUNS.items():
        count = max(1, round(width / (CURTAIN_PANEL_W / 4)))
        piece(item, "Cloth", DRAPE_DARK, lambda bm, w=width, n=count: pleats(bm, -w / 2, w / 2, 0, 0.75, 0.18, CURTAIN_HEM,
                                                                               CURTAIN_TOP, n))

        def pipe(bm, w=width, it=item):
            H.cylinder(bm, (0, 0.6, VIDEO_Z1 + 0.7), 0.2, w, axis="X", segments=8)
            if it != "NatCurtainGap":
                x = (w / 2 - 0.2) * (-1 if it == "NatCurtainEndL" else 1)
                H.box(bm, (x, 0.6, (VIDEO_Z1 + 0.7) / 2), (0.4, 0.4, VIDEO_Z1 + 0.7))
                H.box(bm, (x, 0.6, 0.1), (2.4, 2.4, 0.2))

        piece(item, "Pipe", STEEL, pipe)


def curtain_run_spots():
    """(item, centre x) for every curtain run in the hall (the game places them the same way: NationalsArenaVenue)."""
    spots = [("NatCurtainEndL", (-MEET_SIDE_X + PLATFORM_XS[0] + SET_LEFT) / 2)]
    for a, b in zip(PLATFORM_XS, PLATFORM_XS[1:]):
        spots.append(("NatCurtainGap", (a + SET_RIGHT + b + SET_LEFT) / 2))
    spots.append(("NatCurtainEndR", (PLATFORM_XS[-1] + SET_RIGHT + MEET_SIDE_X) / 2))
    return spots


def build_curtain_glow():
    """The stage's light leaking past the lifter's curtain, seen from behind it (v07, user 2026-11-18: every model made in
    Blender): a thin glowing line in the split and a glowing strip on the floor under the hem. Its frame: x 0 at the
    split, y 0 at the curtain's front, the floor at z 0. The game fades the split's line while the curtain is parted."""
    item = "NatCurtainGlow"
    half = CURTAIN_PANEL_W * CURTAIN_PANELS / 2
    piece(item, "Split", LEAK, lambda bm: H.span(bm, (-0.06, CURTAIN_BACK + 0.03, CURTAIN_HEM),
                                                 (0.06, CURTAIN_BACK + 0.07, CURTAIN_HEM + 11.0)))
    piece(item, "Hem", LEAK, lambda bm: H.span(bm, (-half, CURTAIN_BACK + 0.03, 0.09), (half, CURTAIN_BACK + 0.93, 0.13)))


def build_banner():
    item = "NatBanner"
    w, h = 68.0, 8.0
    piece(item, "Cloth", NAVY, lambda bm: H.span(bm, (-w / 2, 0, 0), (w / 2, 0.6, h)))
    piece(item, "Trim", YELLOW, lambda bm: (H.span(bm, (-w / 2, -0.05, 0.4), (w / 2, 0.0, 0.9)),
                                            H.span(bm, (-w / 2, -0.05, h - 0.9), (w / 2, 0.0, h - 0.4))))
    def banner_text(bm):
        text(bm, "NATIONALS", 4.2, -0.06, 4.6, 0, 0.05)
        text(bm, "CENTRAL", 1.3, -0.06, 1.7, 0, 0.04)

    def banner_text_back(bm):
        # The same words on the back, for the lifters on the platforms (read correctly from behind).
        tmp = bmesh.new()
        text(tmp, "NATIONALS", 4.2, -0.06, 4.6, 0, 0.05)
        text(tmp, "CENTRAL", 1.3, -0.06, 1.7, 0, 0.04)
        bmesh.ops.rotate(tmp, verts=tmp.verts[:], cent=(0, 0.3, 0), matrix=Matrix.Rotation(math.pi, 3, "Z"))
        H._merge(bm, tmp)

    piece(item, "Text", TEXT_WHITE, banner_text)
    piece(item, "TextBack", TEXT_WHITE, banner_text_back)
    piece(item, "Rods", STEEL, lambda bm: (H.cylinder(bm, (0, 0.3, h + 0.3), 0.25, w + 1, axis="X", segments=8),
                                           beam(bm, (-w / 2 + 2, 0.3, h + 0.3), (-w / 2 + 2, 0.3, h + 14), 0.12),
                                           beam(bm, (w / 2 - 2, 0.3, h + 0.3), (w / 2 - 2, 0.3, h + 14), 0.12)))


# ---------------------------------------------------------------- the crowd

TORSO = Vector((1.6, 0.8, 1.8))
HEAD = 1.0


def figure(parts, x, yf, z, rng):
    """One seated figure on the seat of a row whose front is at yf and top at z (facing -Y): about 70 triangles."""
    skin, shirt, pants, hair = (rng.randrange(len(SKINS)), rng.randrange(len(SHIRTS)), rng.randrange(len(PANTS)),
                                rng.randrange(len(HAIRS)))
    x += rng.uniform(-0.15, 0.15)
    seat = z + 1.2
    back = yf + 1.75
    parts["Pants%d" % (pants + 1)].append((Vector((x, back - 0.75, seat + 0.35)), Vector((1.5, 1.7, 0.7))))
    parts["Pants%d" % (pants + 1)].append((Vector((x, yf + 0.55, seat - 0.55)), Vector((1.4, 0.65, 1.3))))
    parts["Shirt%d" % (shirt + 1)].append((Vector((x, back, seat + 0.7 + TORSO.z / 2)), TORSO))
    head_z = seat + 0.7 + TORSO.z + HEAD / 2 + 0.02
    parts["Skin%d" % (skin + 1)].append((Vector((x, back, head_z)), Vector((HEAD, HEAD, HEAD))))
    parts["Hair%d" % (hair + 1)].append((Vector((x, back + 0.08, head_z + HEAD / 2 + 0.07)), Vector((HEAD + 0.08, HEAD, 0.18))))
    # Eyes, as on the Local meet's crowd (Crowd_01), facing the floor.
    for side in (-1, 1):
        parts["Eyes"].append((Vector((x + side * 0.21, back - HEAD / 2 - 0.01, head_z + 0.08)), Vector((0.13, 0.04, 0.17))))
    up = rng.random()
    if up < 0.25:
        side = rng.choice((-1, 1))
        parts["Shirt%d" % (shirt + 1)].append((Vector((x + side * 1.1, back, seat + 0.7 + TORSO.z + 0.6)), Vector((0.55, 0.55, 2.0))))
    else:
        parts["Shirt%d" % (shirt + 1)].append((Vector((x, back - 0.2, seat + 0.7 + TORSO.z - 0.85)), Vector((2.7, 0.55, 1.3))))


def build_crowd(item, rows, seed, fill_front, fill_back):
    rng = random.Random(seed)
    names = ["Skin1", "Skin2", "Skin3", "Shirt1", "Shirt2", "Shirt3", "Shirt4", "Shirt5", "Pants1", "Pants2", "Hair1", "Hair2",
             "Eyes"]
    parts = {n: [] for n in names}
    count = 0
    xs = seat_xs()
    for k in range(rows):
        fill = fill_front if k < rows / 2 else fill_back
        for i, x in enumerate(xs):
            # The two outer seats of the front row are always taken, so the bounds always span the section's width.
            edge = k == 0 and i in (0, len(xs) - 1)
            if edge or rng.random() < fill:
                figure(parts, x, row_front(k), row_top(k), random.Random(rng.random()))
                count += 1
    materials = {m.name.replace("NA2_", ""): m for m in SKINS + SHIRTS + PANTS + HAIRS + [EYES]}
    def eye_quads(bm, boxes):
        # PERFORMANCE: eyes are only ever seen from the front, so each is one flat face toward -Y (2 triangles, not a
        # 12-triangle box). Open faces are fine for Roblox's one-sided drawing when they face the viewer.
        for c, s in boxes:
            y = c.y - s.y / 2
            v = [bm.verts.new((c.x + dx * s.x / 2, y, c.z + dz * s.z / 2)) for dx, dz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            bm.faces.new(v)
        bm.normal_update()
        for f in bm.faces:
            if f.normal.y > 0:
                f.normal_flip()

    for n in names:
        boxes = parts[n]
        if boxes:
            if n == "Eyes":
                piece(item, n, materials[n], lambda bm, boxes=boxes: eye_quads(bm, boxes))
            else:
                piece(item, n, materials[n], lambda bm, boxes=boxes: [H.box(bm, c, s) for c, s in boxes])
    print("CROWD %s figures=%d" % (item, count))


# ---------------------------------------------------------------- build everything

def build_all():
    build_bay()
    build_bay_end()
    build_porch()
    build_end("NatEndLeft", -1)
    build_end("NatEndRight", 1)
    build_walkway()
    build_floor()
    build_stand("NatStandMain", MAIN_ROWS, MAIN_CONCOURSE)
    build_stand("NatStandEnd", END_ROWS, END_CONCOURSE)
    build_wall()
    build_roof_bay()
    build_truss()
    build_highbay()
    build_drape()
    build_stage_set()
    build_curtain_panel()
    build_curtain_glow()
    build_curtain_runs()
    build_banner()
    build_crowd("NatCrowdMainA", MAIN_ROWS, 11, 0.72, 0.38)
    build_crowd("NatCrowdMainB", MAIN_ROWS, 29, 0.66, 0.30)
    build_crowd("NatCrowdEnd", END_ROWS, 47, 0.55, 0.30)


build_all()
# New objects' world matrices are only set after an update (the bounds and the preview copies read them).
bpy.context.view_layer.update()

# Item origins: where each item's pieces sit in the file (side by side), and each item's bounds in its own frame.
BOUNDS = {}
offset = 0.0
for name, objs in ITEMS.items():
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    BOUNDS[name] = (lo, hi)
    tris = 0
    for o in objs:
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
    print("BOUNDS %-14s tris=%6d  low=(%.2f, %.2f, %.2f) high=(%.2f, %.2f, %.2f) bottomcentre=(%.2f, %.2f, %.2f)" % (
        name, tris, lo.x, lo.y, lo.z, hi.x, hi.y, hi.z, (lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
FILE_OFFSET = {}
for name, (lo, hi) in BOUNDS.items():
    FILE_OFFSET[name] = offset - lo.x
    for o in ITEMS[name]:
        o.location.x += FILE_OFFSET[name]
    offset += (hi.x - lo.x) + 20
bpy.context.view_layer.update()
total = 0
for objs in ITEMS.values():
    for o in objs:
        total += len(o.data.loop_triangles)
print("TRIANGLES unique meshes %d (before copies)" % total)


# ---------------------------------------------------------------- the assembled preview

PREVIEW = bpy.data.collections.new("Preview")
bpy.context.scene.collection.children.link(PREVIEW)
PLACED_TRIS = {"exterior": 0, "hall": 0}


def place(item, matrix, group, skip=()):
    """A copy of every piece of `item` (sharing its meshes) at `matrix` (the item's frame in the world), leaving out the
    pieces named in `skip`."""
    back = Matrix.Translation((-FILE_OFFSET[item], 0, 0))
    for o in ITEMS[item]:
        if o.name.split("_", 1)[1] in skip:
            continue
        c = o.copy()
        c.matrix_world = matrix @ back @ o.matrix_world
        PREVIEW.objects.link(c)
        PLACED_TRIS[group] += len(o.data.loop_triangles)


def T(x, y, z, turn_deg=0.0):
    return Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(turn_deg), 4, "Z")


def assemble():
    # The building (its own frame: glass front at y = 0, centred on x = 0, 6 bays).
    x0 = -BAY_W * 3
    for i in range(6):
        xc = x0 + BAY_W * (i + 0.5)
        # The bay whose -X line is the building's middle has the porch there: no column, lamp or downpipe.
        at_porch = abs(xc - HALF) < 0.01
        place("NatBay", T(xc, 0, 0), "exterior", ("Column", "Lamp", "LampArm") if at_porch else ())
    place("NatBayEnd", T(-x0, COL_Y, 0), "exterior")
    place("NatPorch", T(0, 0, 0), "exterior")
    place("NatEndLeft", T(x0, 0, 0), "exterior")
    place("NatEndRight", T(-x0, 0, 0), "exterior")
    place("NatWalkway", T(-x0, 0, 0), "exterior")

    # The hall, far away (its frame: the floor's middle; the stages face -Y toward the main stand).
    hall = Matrix.Translation((1000, 0, 0))
    place("NatFloor", hall, "hall")
    for k in range(MAIN_SECTIONS):
        x = -FLOOR_X + SECTION_W * (k + 0.5)
        place("NatStandMain", hall @ T(x, RAIL_Y, 0, 180), "hall")
        place("NatCrowdMainA" if k % 2 == 0 else "NatCrowdMainB", hall @ T(x, RAIL_Y, 0, 180), "hall")
    # The end stands stop at the backdrops' line (user 2026-11-17: seats behind it only looked at the backdrops' backs and
    # the warm-up area, "a backrow of spectators that are just watching nothing"): 3 sections a side, all with a crowd.
    for s in (-1, 1):
        for k in range(END_SECTIONS):
            y = -40.0 + SECTION_W * (k + 0.5)
            place("NatStandEnd", hall @ T(s * (FLOOR_X + 2), y, 0, -90 * s), "hall")
            place("NatCrowdEnd", hall @ T(s * (FLOOR_X + 2), y, 0, -90 * s), "hall")
    for k in range(ROOF_BAYS):
        x = -WALL_X + PANEL_W * (k + 0.5)
        place("NatWall", hall @ T(x, WALL_Y_FRONT, 0, 180), "hall")
        place("NatWall", hall @ T(x, WALL_Y_BACK, 0), "hall")
        place("NatRoofBay", hall @ T(x, 0, 0), "hall")
        place("NatDrape", hall @ T(x, WALL_Y_BACK - 3, 0), "hall")
    for s in (-1, 1):
        for k in range(SIDE_PANELS):
            y = WALL_Y_FRONT + PANEL_W * (k + 0.5)
            place("NatWall", hall @ T(s * WALL_X, y, 0, -90 * s), "hall")
    for k in range(1, ROOF_BAYS * 2):
        x = -WALL_X + PANEL_W / 2 * k
        ridge = k % 2 == 1
        z = (HALL_RIDGE - 2.2) if ridge else (WALL_Z - 1.2)
        place("NatTruss", hall @ T(x, 0, z), "hall")
        for y in range(int(WALL_Y_FRONT) + 18, int(WALL_Y_BACK) - 6, 24):
            # None hangs between the main stand and the banner across its width (they'd sit in the line of sight).
            if abs(x) < 38 and y < -10:
                continue
            place("NatHighBay", hall @ T(x, y, z - 7.5), "hall")
    for x in PLATFORM_XS:
        place("NatStageSet", hall @ T(x, 0, 0), "hall")
        for k in range(CURTAIN_PANELS):
            px = -(BACKDROP_W / 2 + 0.05) - CURTAIN_PANEL_W * (k + 0.5)
            place("NatCurtainPanel", hall @ T(x + px, BACKDROP_Y - 0.4, 0), "hall")
        place("NatCurtainGlow", hall @ T(x + CURTAIN_SPLIT_X, BACKDROP_Y - 0.4, 0), "hall")
    for item, cx in curtain_run_spots():
        place(item, hall @ T(cx, BACKDROP_Y - 0.4, 0), "hall")
    # Under the middle valley truss (its bottom chord at 42.8; the cloth's top at 42) and still above every seat's line of
    # sight to the video walls (top 29): from the top row (eye about 34) that line passes the banner at about 31.
    place("NatBanner", hall @ T(0, -26, 34), "hall")
    preview_stand_ins(hall)


def preview_stand_ins(hall):
    """PREVIEW ONLY (never exported): plain stand-ins for the game's own props the hall reuses (the competition rack,
    plate trees, referee chairs, judges' tables, warm-up racks) and people for scale, so the previews read as a meet."""
    stand_in = {
        "Steel": H.material("NA2_PreviewSteel", (0.5, 0.5, 0.52), 0.9, 0.3),
        "Plates": H.material("NA2_PreviewPlates", (0.05, 0.05, 0.06), 0.0, 0.5),
        "Red": H.material("NA2_PreviewRed", (0.45, 0.02, 0.03), 0.0, 0.6),
        "Black": H.material("NA2_PreviewBlack", (0.02, 0.02, 0.02), 0.0, 0.7),
        "Loader": H.material("NA2_PreviewLoader", (0.02, 0.02, 0.025), 0.0, 0.7),
        "Shorts": H.material("NA2_PreviewShorts", (0.12, 0.3, 0.6), 0.0, 0.7),
        "Lifter": H.material("NA2_PreviewLifter", (0.6, 0.05, 0.08), 0.0, 0.6),
        "Skin": H.material("NA2_PreviewSkin", (0.52, 0.32, 0.22), 0.0, 0.6),
    }
    shapes = {k: bmesh.new() for k in stand_in}

    def person(x, y, z, body, seated=False):
        if seated:
            H.box(shapes[body], (x, y, z + 1.6), (1.6, 1.0, 2.2))
            H.box(shapes["Shorts"], (x, y - 0.9, z + 0.6), (1.4, 1.6, 0.8))
            H.box(shapes["Skin"], (x, y, z + 3.3), (1.0, 1.0, 1.0))
            return
        H.box(shapes["Shorts"], (x, y, z + 1.2), (1.5, 0.9, 2.4))
        H.box(shapes[body], (x, y, z + 3.3), (1.7, 0.95, 1.9))
        H.box(shapes["Skin"], (x, y, z + 4.75), (1.0, 1.0, 1.0))

    def rack(x, y, z):
        for s in (-1, 1):
            H.box(shapes["Steel"], (x + s * 3.6, y, z + 3.2), (0.5, 0.5, 6.4))
            H.box(shapes["Steel"], (x + s * 3.6, y + 0.4, z + 0.2), (0.8, 3.0, 0.4))
        H.cylinder(shapes["Steel"], (x, y - 0.6, z + 5.0), 0.12, 9.0, axis="X", segments=8)
        for s in (-1, 1):
            H.cylinder(shapes["Plates"], (x + s * 4.2, y - 0.6, z + 5.0), 1.6, 0.6, axis="X", segments=16)

    def chair(x, y):
        H.box(shapes["Red"], (x, y, 0.9), (1.8, 1.8, 0.3))
        H.box(shapes["Red"], (x, y + 0.8, 2.2), (1.8, 0.3, 2.4))
        H.box(shapes["Black"], (x, y, 0.4), (1.6, 1.6, 0.8))

    for x in PLATFORM_XS:
        rack(x, 9.0, STAGE_H)
        person(x, 8.6, STAGE_H, "Lifter")
        for lx, ly in ((x - 5.6, 9.2), (x + 5.6, 9.2), (x, 12.6)):
            person(lx, ly, STAGE_H, "Loader")
        for s in (-1, 1):
            H.cylinder(shapes["Plates"], (x + s * 10.4, 15.5, STAGE_H + 2.2), 1.3, 4.4, segments=12)
        chair(x, -6.0)
        person(x, -6.0, 0, "Loader", seated=True)
        for s in (-1, 1):
            chair(x + s * 11, -1.5)
    for row_y in (52.0, 66.0, 80.0):
        x = -81.0
        while x <= 81.0:
            rack(x, row_y, 0)
            x += 18.0
    for x, y in ((-70, 45), (-40, 48), (-10, 43), (25, 46), (55, 49), (80, 44), (-50, 58), (10, 60), (32, 37)):
        person(x, y, 0, "Lifter" if (x // 10) % 2 else "Loader")
    # A lifter waiting behind each -X curtain's split (the Nationals walk-out), for the curtain previews.
    for x in PLATFORM_XS:
        person(x + CURTAIN_SPLIT_X, BACKDROP_Y + 4.6, 0, "Lifter")
    for key, bm in shapes.items():
        mesh = bpy.data.meshes.new("PreviewStandIns_" + key)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(stand_in[key])
        obj = bpy.data.objects.new("PreviewStandIns_" + key, mesh)
        obj.matrix_world = hall
        PREVIEW.objects.link(obj)


assemble()
print("PLACED triangles: exterior %d, hall %d" % (PLACED_TRIS["exterior"], PLACED_TRIS["hall"]))
for o in B.coll.objects:
    o.hide_render = True


# ---------------------------------------------------------------- previews

def light(name, kind, loc, power=1000.0, colour=(1, 1, 1), spot=None, size=None):
    data = bpy.data.lights.new(name, kind)
    data.energy = power
    data.color = colour
    if spot is not None:
        data.spot_size = spot
        data.spot_blend = 0.35
    if size is not None:
        data.size = size
    obj = bpy.data.objects.new(name, data)
    obj.location = loc
    bpy.context.scene.collection.objects.link(obj)
    return obj


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def camera(name, loc, target, lens=24):
    data = bpy.data.cameras.new(name)
    data.lens = lens
    data.clip_end = 5000
    obj = bpy.data.objects.new(name, data)
    obj.location = loc
    bpy.context.scene.collection.objects.link(obj)
    aim(obj, target)
    return obj


def set_world(colour, strength):
    world = bpy.data.worlds.get("NA2_World") or bpy.data.worlds.new("NA2_World")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (*colour, 1)
    bg.inputs["Strength"].default_value = strength
    bpy.context.scene.world = world


def render(cam, path, engine="EEVEE"):
    scene = bpy.context.scene
    scene.camera = cam
    if engine == "WORKBENCH":
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "MATERIAL"
        scene.display.shading.show_backface_culling = True
    else:
        for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
            try:
                scene.render.engine = eng
                break
            except TypeError:
                continue
        try:
            scene.eevee.taa_render_samples = 32
        except AttributeError:
            pass
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("rendered", path)


def show_only(group):
    for o in PREVIEW.objects:
        o.hide_render = (o.location.x > 500) != (group == "hall")


def previews():
    if not PREVIEW_DIR:
        return
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    # Roblox draws one side of each face: every preview culls back faces, so an inside-out piece would show as a hole.
    for m in bpy.data.materials:
        m.use_backface_culling = True
    show_only("exterior")
    set_world((0.55, 0.7, 0.95), 1.0)
    sun = light("Sun", "SUN", (0, 0, 100), power=4.0)
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    render(camera("CamExtDay", (95, -120, 6), (-10, 10, 16), 22), os.path.join(PREVIEW_DIR, "01_exterior_day.png"))
    render(camera("CamExtEntrance", (14, -42, 5.5), (0, -8, 12), 22), os.path.join(PREVIEW_DIR, "02_exterior_entrance.png"))
    render(camera("CamExtEnd", (130, 40, 12), (60, 20, 14), 24), os.path.join(PREVIEW_DIR, "03_exterior_end_and_back.png"))
    sun.hide_render = True
    set_world((0.01, 0.02, 0.06), 1.0)
    for i in range(7):
        x = -BAY_W * 3 + BAY_W * i
        if abs(x) >= PORCH_W / 2:
            light("ExtLamp%d" % i, "POINT", (x, COL_Y - 2, EAVE - 6.5), power=4000, colour=(1, 0.85, 0.6))
    # The preview's glass is solid, so let it carry the warm light from inside (in Roblox the glass is see-through and the
    # lit Inside piece shows behind it).
    glass_bsdf = next(n for n in GLASS.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    glass_bsdf.inputs["Emission Color"].default_value = (1.0, 0.78, 0.48, 1)
    glass_bsdf.inputs["Emission Strength"].default_value = 1.4
    render(camera("CamExtNight", (-125, -75, 7), (-5, 15, 16), 22), os.path.join(PREVIEW_DIR, "04_exterior_night.png"))

    show_only("hall")
    set_world((0, 0, 0), 0)
    hall = Vector((1000, 0, 0))
    for x in PLATFORM_XS:
        sp = light("Spot%d" % x, "SPOT", hall + Vector((x, -4, 44)), power=320000, colour=(1, 0.97, 0.92), spot=math.radians(30))
        aim(sp, hall + Vector((x, 9, 0)))
        for cx in (CURTAIN_SPLIT_X, (BACKDROP_W / 2 + CURTAIN_R_EDGE) / 2):
            d = light("Drape%d_%d" % (x, cx), "SPOT", hall + Vector((x + cx, 10, 2)), power=40000, colour=(0.55, 0.25, 1.0),
                      spot=math.radians(32))
            aim(d, hall + Vector((x + cx, BACKDROP_Y, 22)))
        wash = light("Wash%d" % x, "AREA", hall + Vector((x, 2, 22)), power=12000, colour=(0.6, 0.45, 1.0), size=26)
        aim(wash, hall + Vector((x, BACKDROP_Y, 8)))
    house = light("House", "AREA", hall + Vector((0, -30, 48)), power=26000, colour=(0.35, 0.42, 0.9), size=260)
    house.rotation_euler = (0, 0, 0)
    # The banner's own light from the front, and a plain working light over the warm-up area (lifters practise there).
    bl = light("BannerLight", "SPOT", hall + Vector((0, -60, 30)), power=60000, colour=(1, 0.96, 0.9), spot=math.radians(40))
    aim(bl, hall + Vector((0, -26, 43)))
    warm = light("WarmUpLight", "AREA", hall + Vector((0, 42, 40)), power=30000, colour=(1, 0.95, 0.88), size=170)
    warm.data.shape = "RECTANGLE"
    warm.data.size_y = 34
    render(camera("CamHallStand", hall + Vector((0, -92, 34)), hall + Vector((0, 12, 6)), 20),
           os.path.join(PREVIEW_DIR, "05_hall_from_stand.png"))
    render(camera("CamHallPlatform", hall + Vector((-8, -26, 6)), hall + Vector((-20, 12, 11)), 24),
           os.path.join(PREVIEW_DIR, "06_platform.png"))
    render(camera("CamHallCrowd", hall + Vector((-30, -22, 7)), hall + Vector((-10, -80, 18)), 22),
           os.path.join(PREVIEW_DIR, "07_hall_stands_and_crowd.png"))
    render(camera("CamHallWarmup", hall + Vector((96, 66, 14)), hall + Vector((0, 30, 4)), 22),
           os.path.join(PREVIEW_DIR, "08_hall_warmup.png"))
    render(camera("CamHallEnd", hall + Vector((-120, 10, 18)), hall + Vector((0, 0, 8)), 20),
           os.path.join(PREVIEW_DIR, "09_hall_from_end_stand.png"))
    # (v04) The lifter's curtain: from the lifters' zone behind it, and from the stage side.
    split = hall + Vector((-26 + CURTAIN_SPLIT_X, BACKDROP_Y, 0))
    render(camera("CamCurtainBack", split + Vector((3, 14, 7)), split + Vector((0, 0, 6)), 24),
           os.path.join(PREVIEW_DIR, "10_curtain_from_behind.png"))
    render(camera("CamCurtainFront", split + Vector((10, -14, 5)), split + Vector((0, 0, 7)), 24),
           os.path.join(PREVIEW_DIR, "11_curtain_from_stage.png"))

    # Every item alone, close up, flat-lit with back faces culled (a hole = an inside-out face), front and back views.
    tiles = os.path.join(PREVIEW_DIR, "tiles")
    os.makedirs(tiles, exist_ok=True)
    for o in PREVIEW.objects:
        o.hide_render = True
    set_world((0.6, 0.6, 0.62), 1.0)
    scene = bpy.context.scene
    for name, objs in ITEMS.items():
        for o in B.coll.objects:
            o.hide_render = o not in objs
        lo = Vector((1e9, 1e9, 1e9))
        hi = Vector((-1e9, -1e9, -1e9))
        for o in objs:
            for c in o.bound_box:
                w = o.matrix_world @ Vector(c)
                lo = Vector(map(min, lo, w))
                hi = Vector(map(max, hi, w))
        centre, size = (lo + hi) / 2, (hi - lo).length
        for view, direction in (("front", Vector((-0.55, -1, 0.45))), ("back", Vector((0.55, 1, 0.45)))):
            cam = camera("CamTile", centre + direction.normalized() * size * 1.05, centre, 35)
            scene.render.resolution_x, scene.render.resolution_y = 640, 420
            scene.camera = cam
            scene.render.engine = "BLENDER_WORKBENCH"
            scene.display.shading.light = "STUDIO"
            scene.display.shading.color_type = "MATERIAL"
            scene.display.shading.show_backface_culling = True
            scene.render.filepath = os.path.join(tiles, "%s_%s.png" % (name, view))
            bpy.ops.render.render(write_still=True)
            bpy.data.objects.remove(cam, do_unlink=True)
    print("tiles", tiles)


previews()

if OUT_BLEND:
    for o in B.coll.objects:
        o.hide_render = False
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    print("saved", OUT_BLEND)
if OUT_GLB:
    bpy.ops.object.select_all(action="DESELECT")
    for o in B.coll.objects:
        o.hide_set(False)
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=True, export_apply=True)
    print("exported", OUT_GLB)
