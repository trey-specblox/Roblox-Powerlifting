# Builds NationalsArena_01: the BLOCKOUT of the Nationals arena (GAME_DESIGN 39, step 3; references and the user's
# words in References/Nationals Arena/Nationals Arena Study.md). Big shapes at their real size only, so the size and
# layout can be approved before anything is detailed (as StateArena_01 was). Two parts:
#
#   EXTERIOR  the building on the plaza (every server, user 2026-11-17), from the user's two exterior photos: a long
#             hall with a row of pitched teal roof bays, a white steel truss frame standing in front of each bay on
#             columns (the roof overhangs a walkway), a tall glass front up into each gable, a brick base, white end
#             walls, lamps on the columns, a projecting entrance porch in the middle with the NATIONALS sign, and a
#             covered walkway at one end. Faces -Y (toward the gym's doors in the game).
#   INTERIOR  the hall the doors lead to (built far from the gym in the game, like the State arena): a wide lifters'
#             floor, tiered seats along the front (the main stand) and both ends behind a rail, an upper concourse,
#             exposed blue roof trusses under pitched roof bays, white drapes on the back wall; 4 PLATFORMS (user's
#             pick) in a row, each like the user's YouTube meet: a low raised stage, a tall backdrop, a big video
#             wall above it, side drapes, plate trees, the head referee's red chair in front; a warm-up area behind
#             the backdrops; the officials' table and a NATIONALS banner in front; simple seated crowd figures.
#             Lit as a dark room with each platform spotlit (the user's lighting photos).
#
# Units: 1 Blender unit = 1 stud, Z up, fronts toward -Y (prop_helpers.py). A player is about 5.5 studs tall.
# Blockout only: nothing here is exported or uploaded.
#
# Run headless (renders the previews and saves the .blend):
#   blender -b --python art/scripts/build_nationals_arena_01.py -- <out.blend> <preview folder>

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

bpy.ops.wm.read_factory_settings(use_empty=True)
B = H.Builder("NationalsArena_01")
random.seed(7)


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.6, emission=None, strength=3.0):
    m = H.material("NA_" + name, tuple(linear(c) for c in rgb), metallic, roughness, 1.0, emission)
    if emission is not None:
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Emission Strength"].default_value = strength
    return m


TEAL = mat("RoofTeal", (64, 150, 140), 0.3, 0.45)
TRUSS_WHITE = mat("TrussWhite", (226, 230, 232), 0.6, 0.35)
GLASS_DAY = mat("Glass", (48, 70, 88), 0.6, 0.05, emission=(1.0, 0.78, 0.48), strength=0.0)
FRAME = mat("WindowFrame", (58, 62, 68), 0.6, 0.4)
BRICK = mat("Brick", (138, 82, 58), 0.0, 0.85)
WOOD = mat("WoodPanel", (150, 104, 66), 0.0, 0.7)
WALL_WHITE = mat("WallWhite", (228, 226, 220), 0.0, 0.7)
CONCRETE = mat("Concrete", (150, 150, 150), 0.0, 0.9)
NAVY = mat("Navy", (28, 44, 96), 0.0, 0.5)
LAMP = mat("Lamp", (255, 236, 200), 0.0, 0.3, emission=(1.0, 0.86, 0.6), strength=12.0)
SIGN_TEXT = mat("SignText", (255, 255, 255), 0.0, 0.3, emission=(1.0, 1.0, 1.0), strength=4.0)
YELLOW = mat("Yellow", (242, 190, 30), 0.0, 0.4)

FLOOR = mat("HallFloor", (78, 80, 86), 0.0, 0.85)
SEAT_BLUE = mat("SeatBlue", (34, 64, 140), 0.0, 0.5)
STEP_GREY = mat("StepGrey", (96, 98, 104), 0.0, 0.85)
RAIL_BLUE = mat("RailBlue", (40, 96, 190), 0.5, 0.35)
TRUSS_BLUE = mat("TrussBlue", (36, 84, 168), 0.5, 0.4)
HALL_WALL = mat("HallWall", (200, 196, 186), 0.0, 0.8)
ROOF_IN = mat("RoofInside", (46, 48, 58), 0.0, 0.8)
DRAPE_WHITE = mat("DrapeWhite", (210, 210, 214), 0.0, 0.9)
DRAPE_DARK = mat("DrapeDark", (40, 16, 22), 0.0, 0.95)
STAGE_TOP = mat("StageTop", (34, 36, 40), 0.0, 0.9)
STAGE_EDGE = mat("StageEdge", (24, 36, 80), 0.0, 0.5)
BACKDROP = mat("Backdrop", (74, 36, 120), 0.0, 0.6)
VIDEO = mat("VideoWall", (20, 34, 70), 0.0, 0.2, emission=(0.25, 0.42, 0.9), strength=0.7)
RED_CHAIR = mat("RedChair", (170, 28, 36), 0.0, 0.6)
BLACK = mat("Black", (22, 22, 24), 0.0, 0.7)
STEEL = mat("Steel", (170, 172, 178), 0.9, 0.3)
HIGHBAY = mat("HighBay", (240, 240, 235), 0.0, 0.3, emission=(1.0, 1.0, 0.95), strength=0.3)
PERSON = [mat("Person" + str(i), c, 0.0, 0.7) for i, c in enumerate(
    [(200, 60, 60), (60, 120, 200), (230, 200, 60), (60, 160, 90), (150, 80, 180), (230, 130, 50), (220, 220, 220),
     (40, 40, 48)])]
SKIN = mat("Skin", (196, 150, 116), 0.0, 0.6)


# ---------------------------------------------------------------- shape helpers

def prism(bm, outline_xz, y0, y1):
    """A closed solid: a convex (x, z) outline pushed from y = y0 to y = y1."""
    tmp = bmesh.new()
    front = [tmp.verts.new((x, y0, z)) for x, z in outline_xz]
    back = [tmp.verts.new((x, y1, z)) for x, z in outline_xz]
    n = len(outline_xz)
    tmp.faces.new(front)
    tmp.faces.new(list(reversed(back)))
    for i in range(n):
        j = (i + 1) % n
        tmp.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)


def prism_x(bm, outline_yz, x0, x1):
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
    """A square beam from p0 to p1."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    rot = d.to_track_quat("X", "Z").to_matrix().to_4x4()
    H.box(bm, (p0 + p1) / 2, (d.length, thick, thick), rot)


def slab(bm, a, b, y0, y1, thick):
    """A sloped roof plate from (x, z) point a to b, from y0 to y1, `thick` deep below the line."""
    (ax, az), (bx, bz) = a, b
    dx, dz = bx - ax, bz - az
    ln = math.hypot(dx, dz)
    nx, nz = -dz / ln * thick, dx / ln * thick
    if nz > 0:
        nx, nz = -nx, -nz
    prism(bm, [(ax, az), (bx, bz), (bx + nx, bz + nz), (ax + nx, az + nz)], y0, y1)


def person(bm, x, y, z, height=5.5, seated=False):
    """A simple figure for scale: legs/body box and a head."""
    if seated:
        H.box(bm, (x, y, z + 1.6), (1.6, 1.0, 2.2))
        H.box(bm, (x, y - 0.9, z + 0.6), (1.4, 1.6, 0.8))
        H.sphere(bm, (x, y, z + 3.3), 0.6, segments=8, rings=5)
    else:
        H.box(bm, (x, y, z + height * 0.38), (1.6, 1.0, height * 0.76))
        H.sphere(bm, (x, y, z + height * 0.88), 0.62, segments=8, rings=5)


# ================================================================ EXTERIOR (the plaza building)
EX = Vector((0, 0, 0))
BAY_W, N_BAYS, DEPTH = 26.0, 6, 70.0
EAVE, RIDGE, OVERHANG, COL_Y = 22.0, 36.0, 9.0, -7.0
X0 = -BAY_W * N_BAYS / 2
PORCH_W, PORCH_D, PORCH_EAVE, PORCH_RIDGE = 22.0, 11.0, 15.0, 22.0


def ex_roofs(bm):
    for i in range(N_BAYS):
        x0 = X0 + i * BAY_W
        xc = x0 + BAY_W / 2
        slab(bm, (x0, EAVE), (xc, RIDGE), -OVERHANG, DEPTH, 0.8)
        slab(bm, (xc, RIDGE), (x0 + BAY_W, EAVE), -OVERHANG, DEPTH, 0.8)
    # The porch roof.
    slab(bm, (-PORCH_W / 2 - 1, PORCH_EAVE), (0, PORCH_RIDGE), -PORCH_D - 1, 0, 0.6)
    slab(bm, (0, PORCH_RIDGE), (PORCH_W / 2 + 1, PORCH_EAVE), -PORCH_D - 1, 0, 0.6)
    # The walkway canopy at the +X end (pitched, low).
    slab(bm, (-X0, 11), (-X0 + 10, 13.5), -14, 8, 0.4)
    slab(bm, (-X0 + 10, 13.5), (-X0 + 20, 11), -14, 8, 0.4)


def ex_glass(bm):
    for i in range(N_BAYS):
        x0 = X0 + i * BAY_W
        xc = x0 + BAY_W / 2
        prism(bm, [(x0 + 0.8, 3), (x0 + BAY_W - 0.8, 3), (x0 + BAY_W - 0.8, EAVE - 0.5), (xc, RIDGE - 1.2),
                   (x0 + 0.8, EAVE - 0.5)], -0.3, 0.3)
    # The porch's glass front and doors.
    prism(bm, [(-PORCH_W / 2 + 0.6, 1), (PORCH_W / 2 - 0.6, 1), (PORCH_W / 2 - 0.6, PORCH_EAVE - 3),
               (-PORCH_W / 2 + 0.6, PORCH_EAVE - 3)], -PORCH_D - 0.3, -PORCH_D + 0.3)


def ex_mullions(bm):
    """The window frames over the glass (the photos' tall curtain wall): verticals up to the gable line, three rows of
    transoms, and the porch's frames and door lines."""
    t, y = 0.35, -0.45
    for i in range(N_BAYS):
        x0 = X0 + i * BAY_W
        xc = x0 + BAY_W / 2
        half = BAY_W / 2 - 0.8
        for k in range(1, 6):
            x = x0 + 0.8 + k * (BAY_W - 1.6) / 6
            top = (EAVE - 0.5) + ((RIDGE - 1.2) - (EAVE - 0.5)) * (1 - abs(x - xc) / half)
            H.span(bm, (x - t / 2, y - t / 2, 3), (x + t / 2, y + t / 2, top))
        for z in (8.0, 13.5, EAVE - 0.6):
            H.span(bm, (x0 + 0.8, y - t / 2, z - t / 2), (x0 + BAY_W - 0.8, y + t / 2, z + t / 2))
    py = -PORCH_D - 0.45
    for k in range(-2, 3):
        x = k * (PORCH_W - 1.2) / 5
        H.span(bm, (x - t / 2, py - t / 2, 1), (x + t / 2, py + t / 2, PORCH_EAVE - 3))
    H.span(bm, (-PORCH_W / 2 + 0.6, py - t / 2, 8.5), (PORCH_W / 2 - 0.6, py + t / 2, 9.0))


def ex_trusses(bm):
    t = 0.7
    for i in range(N_BAYS):
        x0 = X0 + i * BAY_W
        xc = x0 + BAY_W / 2
        y = COL_Y
        top_l, top_r, peak = Vector((x0, y, EAVE - 0.8)), Vector((x0 + BAY_W, y, EAVE - 0.8)), Vector((xc, y, RIDGE - 1.6))
        bot_l, bot_r = Vector((x0, y, EAVE - 3.2)), Vector((x0 + BAY_W, y, EAVE - 3.2))
        beam(bm, top_l, peak, t)
        beam(bm, peak, top_r, t)
        beam(bm, bot_l, bot_r, t)
        # Webs: alternating diagonals between the sloped top chords and the bottom chord.
        steps = 6
        for k in range(steps):
            f0, f1 = k / steps, (k + 1) / steps
            def top(f):
                return top_l.lerp(peak, f * 2) if f <= 0.5 else peak.lerp(top_r, (f - 0.5) * 2)
            b0 = bot_l.lerp(bot_r, f0)
            b1 = bot_l.lerp(bot_r, f1)
            beam(bm, b0, top(f1) if k % 2 == 0 else top(f0), t * 0.6)
            beam(bm, top(f1), b1, t * 0.6)
        # The beam back from the truss to the wall, under the overhang.
        beam(bm, (xc, y, RIDGE - 1.6), (xc, 0, RIDGE - 1.6), t * 0.7)
    # Columns at the bay lines (not where the porch stands).
    for i in range(N_BAYS + 1):
        x = X0 + i * BAY_W
        if abs(x) < PORCH_W / 2:
            continue
        H.box(bm, (x, COL_Y, EAVE / 2), (1.0, 1.0, EAVE))
    # The walkway canopy's posts.
    for x in (-X0 + 2, -X0 + 18):
        for y in (-12, 6):
            H.box(bm, (x, y, 5.5), (0.6, 0.6, 11))


def ex_walls(bm):
    # The hall behind the glass (its top hides under the roofs).
    H.span(bm, (X0, 0.3, 0), (-X0, DEPTH, EAVE))
    # The porch's side walls.
    for s in (-1, 1):
        H.span(bm, (s * PORCH_W / 2 - 0.8, -PORCH_D, 0), (s * PORCH_W / 2 + 0.8, 0, PORCH_EAVE))


def ex_brick(bm):
    H.span(bm, (X0, -0.8, 0), (-X0, 0.4, 3))
    for x in (X0, -X0):
        H.span(bm, (x - 1.2, -0.8, 0), (x + 1.2, DEPTH, 8))
    for s in (-1, 1):
        H.span(bm, (s * PORCH_W / 2 - 1.2, -PORCH_D - 0.8, 0), (s * PORCH_W / 2 + 1.2, 0, 4))


def ex_wood(bm):
    # Wood-look panels on the end walls (the photos' warm brown sections).
    for x in (X0 - 1.3, -X0 + 1.3):
        H.span(bm, (x - 0.2, 4, 8), (x + 0.2, DEPTH - 4, EAVE - 2))


def ex_lamps(bm):
    for i in range(N_BAYS + 1):
        x = X0 + i * BAY_W
        if abs(x) < PORCH_W / 2:
            continue
        H.box(bm, (x, COL_Y - 0.9, EAVE - 6), (1.4, 0.9, 0.8))


def ex_sign(bm):
    # A big sign board on the porch's gable (the game writes the countdown under it in the detail pass).
    H.span(bm, (-PORCH_W / 2 + 0.5, -PORCH_D - 1.5, PORCH_EAVE - 2.8), (PORCH_W / 2 - 0.5, -PORCH_D - 0.9, PORCH_EAVE + 3.2))


def ex_sign_text(bm):
    B.add_text(bm, "NATIONALS", 3.4, 0.1, H.on_front((0, 0, 0), -PORCH_D - 1.6, PORCH_EAVE + 0.8))
    B.add_text(bm, "CENTRAL", 1.4, 0.08, H.on_front((0, 0, 0), -PORCH_D - 1.6, PORCH_EAVE - 1.6))


def ex_plaza(bm):
    H.span(bm, (-140, -150, -1), (140, 90, 0))


def ex_people(bm):
    for x, y in ((-30, -12), (-26, -14), (0, -20), (12, -18), (40, -10), (-60, -16)):
        person(bm, x, y, 0)


EXTERIOR = [
    ("NatExterior_Roofs", TEAL, ex_roofs),
    ("NatExterior_Glass", GLASS_DAY, ex_glass),
    ("NatExterior_Frames", FRAME, ex_mullions),
    ("NatExterior_Trusses", TRUSS_WHITE, ex_trusses),
    ("NatExterior_Walls", WALL_WHITE, ex_walls),
    ("NatExterior_Brick", BRICK, ex_brick),
    ("NatExterior_Wood", WOOD, ex_wood),
    ("NatExterior_Lamps", LAMP, ex_lamps),
    ("NatExterior_Sign", NAVY, ex_sign),
    ("NatExterior_SignText", SIGN_TEXT, ex_sign_text),
    ("NatExterior_Plaza", CONCRETE, ex_plaza),
    ("NatExterior_People", PERSON[1], ex_people),
]

# ================================================================ INTERIOR (the hall)
IN = Vector((1000, 0, 0))   # far from the exterior, as in the game
FLOOR_X, FLOOR_Y0, FLOOR_Y1 = 100.0, -40.0, 62.0
RAIL_Y = -42.0
MAIN_ROWS, END_ROWS, ROW_D, ROW_RISE, ROW_BASE = 18, 12, 3.0, 1.6, 2.5
MAIN_Y0 = -44.0
END_X0 = 104.0
WALL_X, WALL_Y_FRONT, WALL_Y_BACK, WALL_Z = 150.0, -110.0, 66.0, 50.0
HALL_BAYS, HALL_RIDGE = 6, 64.0
PLATFORM_XS = (-60.0, -20.0, 20.0, 60.0)
STAGE_W, STAGE_Y0, STAGE_Y1, STAGE_H = 24.0, 0.0, 18.0, 1.2
BACKDROP_Y, BACKDROP_W, BACKDROP_H = 20.0, 28.0, 15.0
VIDEO_Z0, VIDEO_Z1 = 15.5, 29.0


def at(v):
    return IN + Vector(v)


def in_floor(bm):
    H.span(bm, at((-WALL_X, WALL_Y_FRONT, -1)), at((WALL_X, WALL_Y_BACK, 0)))


def in_main_stand_steps(bm):
    for k in range(MAIN_ROWS):
        y1 = MAIN_Y0 - k * ROW_D
        H.span(bm, at((-FLOOR_X - 2, y1 - ROW_D, 0)), at((FLOOR_X + 2, y1, ROW_BASE + k * ROW_RISE)))
    # The upper concourse behind the top row.
    top = ROW_BASE + (MAIN_ROWS - 1) * ROW_RISE
    H.span(bm, at((-WALL_X, WALL_Y_FRONT, 0)), at((WALL_X, MAIN_Y0 - MAIN_ROWS * ROW_D, top + 0.6)))
    # The end stands.
    for s in (-1, 1):
        for k in range(END_ROWS):
            x0 = END_X0 + k * ROW_D
            H.span(bm, at((s * x0, RAIL_Y, 0)), at((s * (x0 + ROW_D), 46, ROW_BASE + k * ROW_RISE)))
        x_top = END_X0 + END_ROWS * ROW_D
        H.span(bm, at((s * x_top, RAIL_Y, 0)), at((s * WALL_X, 46, ROW_BASE + (END_ROWS - 1) * ROW_RISE + 0.6)))


def in_seats(bm):
    # A seat strip on each row (blockout: one long block a row; the detail pass makes real seats and aisles).
    for k in range(MAIN_ROWS):
        y1 = MAIN_Y0 - k * ROW_D
        z = ROW_BASE + k * ROW_RISE
        H.span(bm, at((-FLOOR_X, y1 - 1.9, z)), at((FLOOR_X, y1 - 0.7, z + 1.4)))
    for s in (-1, 1):
        for k in range(END_ROWS):
            x0 = END_X0 + k * ROW_D
            z = ROW_BASE + k * ROW_RISE
            H.span(bm, at((s * (x0 + 0.7), RAIL_Y + 2, z)), at((s * (x0 + 1.9), 44, z + 1.4)))


def in_rails(bm):
    H.span(bm, at((-FLOOR_X - 4, RAIL_Y - 0.2, 0)), at((FLOOR_X + 4, RAIL_Y + 0.2, 3.6)))
    for s in (-1, 1):
        H.span(bm, at((s * (END_X0 - 2) - 0.2, RAIL_Y, 0)), at((s * (END_X0 - 2) + 0.2, 46, 3.6)))
    # The concourse rail.
    top = ROW_BASE + (MAIN_ROWS - 1) * ROW_RISE + 0.6
    H.span(bm, at((-WALL_X, MAIN_Y0 - MAIN_ROWS * ROW_D - 0.2, top)), at((WALL_X, MAIN_Y0 - MAIN_ROWS * ROW_D + 0.2, top + 3.4)))


def in_walls(bm):
    for s in (-1, 1):
        H.span(bm, at((s * WALL_X - 1, WALL_Y_FRONT, 0)), at((s * WALL_X + 1, WALL_Y_BACK, WALL_Z)))
    H.span(bm, at((-WALL_X, WALL_Y_FRONT - 1, 0)), at((WALL_X, WALL_Y_FRONT + 1, WALL_Z)))
    H.span(bm, at((-WALL_X, WALL_Y_BACK - 1, 0)), at((WALL_X, WALL_Y_BACK + 1, WALL_Z)))
    # Gable ends of each roof bay on the front and back walls.
    bay = 2 * WALL_X / HALL_BAYS
    for i in range(HALL_BAYS):
        x0 = -WALL_X + i * bay
        for y in (WALL_Y_FRONT, WALL_Y_BACK):
            prism(bm, [(IN.x + x0, WALL_Z), (IN.x + x0 + bay, WALL_Z), (IN.x + x0 + bay / 2, HALL_RIDGE)], y - 1, y + 1)


def in_roof(bm):
    bay = 2 * WALL_X / HALL_BAYS
    for i in range(HALL_BAYS):
        x0 = -WALL_X + i * bay
        xc = x0 + bay / 2
        slab(bm, (IN.x + x0, WALL_Z), (IN.x + xc, HALL_RIDGE), WALL_Y_FRONT - 1, WALL_Y_BACK + 1, 1.0)
        slab(bm, (IN.x + xc, HALL_RIDGE), (IN.x + x0 + bay, WALL_Z), WALL_Y_FRONT - 1, WALL_Y_BACK + 1, 1.0)


def in_trusses(bm):
    # Blue trusses spanning front to back under each ridge and each valley (the civic-center photos).
    bay = 2 * WALL_X / HALL_BAYS
    for i in range(HALL_BAYS * 2 + 1):
        x = -WALL_X + i * bay / 2
        if abs(abs(x) - WALL_X) < 1:
            continue
        ridge = i % 2 == 1
        z_top = (HALL_RIDGE - 2) if ridge else (WALL_Z - 1)
        z_bot = z_top - 6
        y0, y1 = WALL_Y_FRONT + 2, WALL_Y_BACK - 2
        beam(bm, at((x, y0, z_top)), at((x, y1, z_top)), 0.8)
        beam(bm, at((x, y0, z_bot)), at((x, y1, z_bot)), 0.8)
        n = int((y1 - y0) / 8)
        for k in range(n):
            ya, yb = y0 + k * (y1 - y0) / n, y0 + (k + 1) * (y1 - y0) / n
            beam(bm, at((x, ya, z_bot)), at((x, yb, z_top)) if k % 2 == 0 else at((x, ya, z_top)), 0.45)
            beam(bm, at((x, yb, z_bot)), at((x, yb, z_top)), 0.45)


def in_highbays(bm):
    bay = 2 * WALL_X / HALL_BAYS
    for i in range(HALL_BAYS * 2 + 1):
        x = -WALL_X + i * bay / 2
        if abs(abs(x) - WALL_X) < 1:
            continue
        z = (HALL_RIDGE - 9) if i % 2 == 1 else (WALL_Z - 8)
        for y in range(int(WALL_Y_FRONT) + 14, int(WALL_Y_BACK) - 6, 22):
            H.cylinder(bm, at((x, y, z)), 1.2, 1.0, segments=10, radius2=0.6)


def in_back_drapes(bm):
    for k in range(-14, 15):
        x = k * 10.0
        H.span(bm, at((x - 4.6, WALL_Y_BACK - 2.5 + (k % 2) * 0.6, 0)), at((x + 4.6, WALL_Y_BACK - 1.2, WALL_Z - 6)))


def in_stages(bm):
    for x in PLATFORM_XS:
        H.span(bm, at((x - STAGE_W / 2, STAGE_Y0, 0)), at((x + STAGE_W / 2, STAGE_Y1, STAGE_H)))


def in_stage_edges(bm):
    for x in PLATFORM_XS:
        H.span(bm, at((x - STAGE_W / 2 - 0.1, STAGE_Y0 - 0.15, 0)), at((x + STAGE_W / 2 + 0.1, STAGE_Y0 + 0.1, STAGE_H + 0.05)))


def in_backdrops(bm):
    for x in PLATFORM_XS:
        H.span(bm, at((x - BACKDROP_W / 2, BACKDROP_Y, 0)), at((x + BACKDROP_W / 2, BACKDROP_Y + 1, BACKDROP_H)))


def in_video_walls(bm):
    for x in PLATFORM_XS:
        H.span(bm, at((x - BACKDROP_W / 2 + 1, BACKDROP_Y + 0.2, VIDEO_Z0)), at((x + BACKDROP_W / 2 - 1, BACKDROP_Y + 1.2, VIDEO_Z1)))


def in_stage_drapes(bm):
    for x in PLATFORM_XS:
        for s in (-1, 1):
            H.span(bm, at((x + s * BACKDROP_W / 2, STAGE_Y1 - 2, 0)), at((x + s * (BACKDROP_W / 2 + 3.2), BACKDROP_Y + 2, VIDEO_Z1 + 1)))


def in_racks(bm):
    # A plain rack at each stage (the game places its real competition rack), plates on the bar.
    for x in PLATFORM_XS:
        y = 9.0
        for s in (-1, 1):
            H.box(bm, at((x + s * 3.6, y, STAGE_H + 3.2)), (0.5, 0.5, 6.4))
            H.box(bm, at((x + s * 3.6, y + 0.4, STAGE_H + 0.2)), (0.8, 3.0, 0.4))
        H.cylinder(bm, at((x, y - 0.6, STAGE_H + 5.0)), 0.12, 9.0, axis="X", segments=8)
        for s in (-1, 1):
            H.cylinder(bm, at((x + s * 4.2, y - 0.6, STAGE_H + 5.0)), 1.6, 0.6, axis="X", segments=16)


def in_plate_trees(bm):
    for x in PLATFORM_XS:
        for s in (-1, 1):
            H.cylinder(bm, at((x + s * 10.5, 15.5, STAGE_H + 2)), 1.3, 4.0, segments=12)


def in_ref_chairs(bm):
    for x in PLATFORM_XS:
        for cx, cy in ((x, -6.0), (x - 11, -1.5), (x + 11, -1.5)):
            H.span(bm, at((cx - 1, cy - 1, 0)), at((cx + 1, cy + 1, 1.8)))
            H.span(bm, at((cx - 1, cy + 0.7, 1.8)), at((cx + 1, cy + 1, 4.0)))


def in_officials(bm):
    H.span(bm, at((-36, -18.5, 0)), at((36, -15.5, 2.6)))


def in_banner(bm):
    H.span(bm, at((-34, -30.4, 34)), at((34, -29.6, 42)))


def in_banner_text(bm):
    B.add_text(bm, "NATIONALS", 5.0, 0.1, H.on_front(IN, -30.6, 38))


def in_warmup(bm):
    # Rows of warm-up racks and benches behind the backdrops (the detail pass uses the game's competition rack).
    for row_y in (32.0, 46.0):
        x = -84.0
        while x <= 84.0:
            for s in (-1, 1):
                H.box(bm, at((x + s * 2.4, row_y, 3.2)), (0.5, 0.5, 6.4))
            H.cylinder(bm, at((x, row_y - 0.6, 5)), 0.12, 7.0, axis="X", segments=8)
            x += 12.0
    for x in PLATFORM_XS:
        H.span(bm, at((x - 5, 25.5, 0)), at((x + 5, 26.7, 1.8)))


def in_people(bm):
    # On each stage: the lifter at the bar, three loaders/spotters; the head referee in the red chair; a few lifters
    # and coaches in the warm-up area.
    for x in PLATFORM_XS:
        person(bm, at((x, 8.0, STAGE_H)).x, 8.0, STAGE_H)
        for lx, ly in ((x - 5.5, 9.0), (x + 5.5, 9.0), (x, 12.5)):
            person(bm, at((lx, ly, 0)).x, ly, STAGE_H)
        person(bm, at((x, -6.0, 0)).x, -6.0, 0, seated=True)
    for x, y in ((-70, 38), (-40, 40), (-10, 36), (25, 39), (55, 42), (80, 37), (-50, 52), (10, 54)):
        person(bm, at((x, y, 0)).x, y, 0)


def crowd_maker(colour_index):
    def build(bm):
        rng = random.Random(100 + colour_index)
        for k in range(MAIN_ROWS):
            y1 = MAIN_Y0 - k * ROW_D
            z = ROW_BASE + k * ROW_RISE
            fill = 0.75 if k < 9 else 0.45
            x = -FLOOR_X + 1.5
            while x < FLOOR_X:
                if rng.random() < fill and rng.randrange(len(PERSON)) == colour_index:
                    person(bm, IN.x + x, y1 - 1.3, z + 0.7, seated=True)
                x += 2.2
        for s in (-1, 1):
            for k in range(END_ROWS):
                x0 = END_X0 + k * ROW_D
                z = ROW_BASE + k * ROW_RISE
                y = RAIL_Y + 3
                while y < 44:
                    if rng.random() < 0.5 and rng.randrange(len(PERSON)) == colour_index:
                        tmp = bmesh.new()
                        person(tmp, 0, 0, 0, seated=True)
                        bmesh.ops.rotate(tmp, verts=tmp.verts[:], cent=(0, 0, 0),
                                         matrix=Matrix.Rotation(-s * math.pi / 2, 3, "Z"))
                        bmesh.ops.translate(tmp, verts=tmp.verts[:], vec=Vector((IN.x + s * (x0 + 1.3), y, z + 0.7)))
                        H._merge(bm, tmp)
                    y += 2.2
    return build


INTERIOR = [
    ("NatHall_Floor", FLOOR, in_floor),
    ("NatHall_StandSteps", STEP_GREY, in_main_stand_steps),
    ("NatHall_Seats", SEAT_BLUE, in_seats),
    ("NatHall_Rails", RAIL_BLUE, in_rails),
    ("NatHall_Walls", HALL_WALL, in_walls),
    ("NatHall_Roof", ROOF_IN, in_roof),
    ("NatHall_Trusses", TRUSS_BLUE, in_trusses),
    ("NatHall_HighBays", HIGHBAY, in_highbays),
    ("NatHall_BackDrapes", DRAPE_WHITE, in_back_drapes),
    ("NatHall_Stages", STAGE_TOP, in_stages),
    ("NatHall_StageEdges", STAGE_EDGE, in_stage_edges),
    ("NatHall_Backdrops", BACKDROP, in_backdrops),
    ("NatHall_VideoWalls", VIDEO, in_video_walls),
    ("NatHall_StageDrapes", DRAPE_DARK, in_stage_drapes),
    ("NatHall_Racks", STEEL, in_racks),
    ("NatHall_PlateTrees", BLACK, in_plate_trees),
    ("NatHall_RefChairs", RED_CHAIR, in_ref_chairs),
    ("NatHall_Officials", BLACK, in_officials),
    ("NatHall_Banner", NAVY, in_banner),
    ("NatHall_BannerText", SIGN_TEXT, in_banner_text),
    ("NatHall_WarmUp", STEEL, in_warmup),
    ("NatHall_People", PERSON[6], in_people),
]
for i in range(len(PERSON)):
    INTERIOR.append(("NatHall_Crowd" + str(i), PERSON[i], crowd_maker(i)))


def build_all():
    for name, material, fn in EXTERIOR + INTERIOR:
        B.piece(name, material, fn, smooth=False)
    tris = {}
    for obj in B.coll.objects:
        obj.data.calc_loop_triangles()
        tris[obj.name] = len(obj.data.loop_triangles)
    total_ex = sum(v for k, v in tris.items() if k.startswith("NatExterior"))
    total_in = sum(v for k, v in tris.items() if k.startswith("NatHall"))
    print("TRIANGLES exterior %d, interior %d" % (total_ex, total_in))
    for k in sorted(tris):
        print("  %-26s %7d" % (k, tris[k]))


# ================================================================ lights, cameras, previews

def light(name, kind, loc, rot=None, power=1000.0, colour=(1, 1, 1), size=None, spot=None):
    data = bpy.data.lights.new(name, kind)
    data.energy = power
    data.color = colour
    if size is not None and hasattr(data, "shadow_soft_size"):
        data.shadow_soft_size = size
    if spot is not None:
        data.spot_size = spot
        data.spot_blend = 0.35
    obj = bpy.data.objects.new(name, data)
    obj.location = loc
    if rot is not None:
        obj.rotation_euler = rot
    bpy.context.scene.collection.objects.link(obj)
    return obj


def aim(obj, target):
    d = Vector(target) - obj.location
    obj.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def camera(name, loc, target, lens=24, ortho=None):
    data = bpy.data.cameras.new(name)
    data.lens = lens
    data.clip_end = 5000
    if ortho:
        data.type = "ORTHO"
        data.ortho_scale = ortho
    obj = bpy.data.objects.new(name, data)
    obj.location = loc
    bpy.context.scene.collection.objects.link(obj)
    aim(obj, target)
    return obj


def set_world(colour, strength):
    world = bpy.data.worlds.get("NA_World") or bpy.data.worlds.new("NA_World")
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
    else:
        for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
            try:
                scene.render.engine = eng
                break
            except TypeError:
                continue
        try:
            scene.eevee.taa_render_samples = 24
        except AttributeError:
            pass
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("rendered", path)


def label(text, loc, size=6.0):
    curve = bpy.data.curves.new("Label_" + text, "FONT")
    curve.body = text
    curve.font = B.font
    curve.size = size
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    obj = bpy.data.objects.new("Label_" + text, curve)
    obj.location = loc
    obj.data.materials.append(YELLOW)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def previews():
    if not PREVIEW_DIR:
        return
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    scene = bpy.context.scene
    hidden = {}

    def show(prefixes):
        for obj in B.coll.objects:
            obj.hide_render = not any(obj.name.startswith(p) for p in prefixes)

    # 1. The building by day, as the game shows it (the game's sky is daytime), from the plaza at eye height.
    show(["NatExterior"])
    set_world((0.55, 0.7, 0.95), 1.0)
    sun = light("Sun", "SUN", (0, 0, 100), power=4.0)
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    render(camera("CamExteriorDay", (95, -120, 6), (-10, 10, 16), lens=22), os.path.join(PREVIEW_DIR, "01_exterior_day.png"))
    # 2. The building at night, like the user's photo (glass glowing, lamps lit): the look the materials aim for.
    sun.hide_render = True
    set_world((0.01, 0.02, 0.06), 1.0)
    # At night the glass glows warm from inside, as in the user's photo.
    glass_bsdf = next(n for n in GLASS_DAY.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    glass_bsdf.inputs["Emission Strength"].default_value = 1.6
    for i in range(N_BAYS + 1):
        x = X0 + i * BAY_W
        if abs(x) >= PORCH_W / 2:
            light("ExtLamp%d" % i, "POINT", (x, COL_Y - 2, EAVE - 6.5), power=4000, colour=(1, 0.85, 0.6))
    glow_inside = light("ExtGlow", "AREA", (0, 30, 20), power=60000, colour=(1, 0.8, 0.55))
    glow_inside.data.size = 150
    glow_inside.rotation_euler = (math.radians(90), 0, 0)
    render(camera("CamExteriorNight", (-125, -75, 7), (-5, 15, 16), lens=22), os.path.join(PREVIEW_DIR, "02_exterior_night.png"))

    # 3. The hall, dark, from high in the main stand (the dark room with the platforms spotlit).
    show(["NatHall"])
    set_world((0.0, 0.0, 0.0), 0.0)
    # The dark room: each platform hard-lit from above, a narrow purple wash on its drapes, and only a faint cool
    # house light so the seats stay readable (dark, but not black: phones, per the fwjelaa lighting notes).
    for x in PLATFORM_XS:
        sp = light("Spot%d" % x, "SPOT", IN + Vector((x, -4, 44)), power=320000, colour=(1, 0.97, 0.92), spot=math.radians(30), size=1.0)
        aim(sp, IN + Vector((x, 9, 0)))
        for s in (-1, 1):
            light("Drape%d_%d" % (x, s), "SPOT", IN + Vector((x + s * 15.6, 10, 2)), power=40000, colour=(0.55, 0.25, 1.0),
                  spot=math.radians(25))
            aim(bpy.data.objects["Drape%d_%d" % (x, s)], IN + Vector((x + s * 15.6, BACKDROP_Y + 2, 24)))
        wash = light("Wash%d" % x, "AREA", IN + Vector((x, 2, 22)), power=12000, colour=(0.6, 0.45, 1.0))
        wash.data.size = 26
        aim(wash, IN + Vector((x, BACKDROP_Y, 8)))
    house = light("House", "AREA", IN + Vector((0, -30, 48)), power=26000, colour=(0.35, 0.42, 0.9))
    house.data.size = 260
    render(camera("CamHallStand", IN + Vector((0, -92, 34)), IN + Vector((0, 12, 6)), lens=20), os.path.join(PREVIEW_DIR, "03_hall_dark_from_stand.png"))
    # 4. One platform up close, from the floor beside the head referee.
    render(camera("CamHallPlatform", IN + Vector((-12, -24, 6)), IN + Vector((-20, 12, 10)), lens=24), os.path.join(PREVIEW_DIR, "04_platform_close.png"))
    # 5. The layout from above, lit flat, with labels (roof hidden).
    for obj in B.coll.objects:
        if obj.name in ("NatHall_Roof", "NatHall_Trusses", "NatHall_HighBays"):
            obj.hide_render = True
    for i, x in enumerate(PLATFORM_XS):
        label("PLATFORM %d" % (i + 1), IN + Vector((x, -10, 60)), 4.0)
    label("WARM-UP", IN + Vector((0, 40, 60)), 7.0)
    label("MAIN STAND (18 ROWS)", IN + Vector((0, -72, 60)), 7.0)
    label("END STAND", IN + Vector((-124, 0, 60)), 6.0).rotation_euler = (0, 0, math.radians(90))
    label("END STAND", IN + Vector((124, 0, 60)), 6.0).rotation_euler = (0, 0, math.radians(-90))
    label("RAIL", IN + Vector((80, -45, 60)), 3.5)
    label("OFFICIALS", IN + Vector((0, -22, 60)), 3.5)
    render(camera("CamHallPlan", IN + Vector((0, -20, 400)), IN + Vector((0, -20, 0)), ortho=330), os.path.join(PREVIEW_DIR, "05_hall_plan.png"), engine="WORKBENCH")


build_all()
previews()
if OUT_BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    print("saved", OUT_BLEND)
