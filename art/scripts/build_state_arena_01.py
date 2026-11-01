# Builds StateArena_01 in the live Blender scene: the BLOCKOUT of the State Championship arena (GAME_DESIGN 36,
# user 2026-11-01: "a big indoor arena" from 7 reference photos, written down in 36.1). The big shapes at their
# real size, so the layout and scale can be approved before the detailed props are modelled. Items:
#
#   StandWedge      one 15-degree slice of the seating bowl, reused 24 times round the floor: a low wall round
#                   the floor, the lower tier (10 rows), a walkway, the upper tier (10 steeper rows) with a lit ad
#                   ribbon on its front, the suites ring on top, the outer wall, handrails, an aisle at one edge.
#   DomeWedge       one 15-degree slice of the roof, reused 24 times: the dark dome shell, its steel lattice (a
#                   meridian rib and ring beams) and a spotlight on the rim ring.
#   ArenaFloor      the round arena floor, the grey competition mat and its darker centre aisle.
#   CentreCube      the centre-hung video cube: frame, four screens, the lit ring under it, four speaker stacks
#                   and the hanging cables.
#   RackGantry      the screen above each of the 4 racks: two truss legs, a top beam, a big screen (the game
#                   draws the lifter's live minigame on it) and a number panel. Stands behind a rack.
#   ArenaEntrance   the building outside the gym (scaled down, like the Local meet's entrance): a red-brick base
#                   with three round arches (cream stone rings, glass doors), a sign screen above them the game
#                   writes on, a grey cornice, a ribbed cream drum with small windows and a shallow pale dome
#                   with a white edge ring.
#   JudgesTable     a table for a platform's 3 judges, navy skirt with CENTRAL (the game turns it to face the rack).
#   CameraTripod    a TV camera on a tripod (front rows and floor corners in the photos).
#   ArenaBanner     a red championship banner (STATE CHAMPS), hung round the top of the stands.
#   ArenaFlag       a big navy CENTRAL flag hung from the roof near the centre cube (logo on both sides).
#   NameSign        the big sign on the suites at each end; the game writes STATE CHAMPIONSHIP on its screen.
#   GantryBanner    a navy CENTRAL / STATE CHAMPIONSHIP backdrop inside each gantry, under the screen, to the floor.
#
# The detail pass (user "Looks good, detail it", 2026-11-01) added real seats (StandWedge_SeatsLower/Upper:
# 24 triangles a seat, split in two to stay under the 5,000 budget), sponsor boards round the floor wall, logos
# and the props above. PERFORMANCE: the seats are the heaviest part, about 6,200 triangles a wedge, 150,000 for
# the whole bowl, all one reused mesh pair (Roblox draws repeats of one mesh cheaply).
#
# Layout (the arena's own frame, 1 unit = 1 stud, Z up, the floor's middle at 0,0,0; the 4 racks stand in a row
# along X, facing -Y toward the main stand):
#   floor radius 80 | lower tier r 82-112, z 4-20 | walkway r 112-116 | upper tier r 116-146, z 26-46 |
#   suites r 146-154, z 46-56 | outer wall r 154-156 | dome from r 156, z 58 to the top at z 98.
# A "Preview" collection repeats the wedges round the bowl and adds racks, gantries, people for scale and the
# entrance, for preview renders only (check_models.py skips it).
#
# Run in an otherwise empty file (art/blender/StateArena_01.blend):
#   exec(compile(open(path).read(), path, "exec"), {"__file__": path, "__name__": "__main__"})
# Objects are replaced by name on every run.

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

B = H.Builder("StateArena_01")
# Start from an empty collection, so a piece renamed or dropped here never lingers in the file (and the export).
for _old in list(B.coll.objects):
    bpy.data.objects.remove(_old, do_unlink=True)


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.5, emission=None):
    return H.material("SA_" + name, tuple(linear(c) for c in rgb), metallic, roughness, 1.0, emission)


# Preview colours (Roblox colours each piece from StarterGymConfig.PropColourways).
CONCRETE = mat("Concrete", (120, 122, 128), 0.0, 0.8)
NAVY = mat("Navy", (30, 48, 98))
SEAT = mat("Seat", (36, 52, 104), 0.0, 0.45)
DARK = mat("Dark", (20, 22, 30), 0.0, 0.7)
DOME = mat("Dome", (34, 40, 92), 0.0, 0.6)
STEEL = mat("Steel", (190, 192, 198), 1.0, 0.3)
BLACK = mat("Black", (22, 22, 24))
YELLOW = mat("Yellow", (242, 190, 30), 0.0, 0.4)
GLOW = mat("Glow", (255, 250, 240), 0.0, 0.3, emission=(1.0, 0.98, 0.94))
RIBBON = mat("Ribbon", (230, 40, 60), 0.0, 0.3, emission=(0.9, 0.12, 0.2))
SCREEN = mat("Screen", (8, 10, 18), 0.0, 0.08)
GLASS = mat("Glass", (60, 80, 110), 0.2, 0.1)
FLOOR = mat("Floor", (176, 140, 96), 0.0, 0.5)
MAT_GREY = mat("MatGrey", (128, 130, 136), 0.0, 0.9)
MAT_DARK = mat("MatDark", (62, 64, 72), 0.0, 0.9)
BRICK = mat("Brick", (150, 64, 52), 0.0, 0.85)
CREAM = mat("Cream", (226, 214, 188), 0.0, 0.7)
ROOF = mat("Roof", (214, 180, 168), 0.0, 0.6)
WHITE = mat("White", (236, 236, 232), 0.0, 0.4)

WEDGE = math.radians(15)  # 24 wedges round the bowl
HALF = WEDGE / 2

# The bowl's profile (radius, height), shared by the wedges and the preview.
FLOOR_R = 80.0
LOWER_ROWS, LOWER_R0, LOWER_Z0, LOWER_DEPTH, LOWER_RISE = 10, 82.0, 4.0, 3.0, 1.6
WALK_R0, WALK_R1 = 112.0, 116.0
UPPER_ROWS, UPPER_R0, UPPER_Z0, UPPER_DEPTH, UPPER_RISE = 10, 116.0, 26.0, 3.0, 2.0
SUITE_R0, SUITE_R1, SUITE_Z0, SUITE_Z1 = 146.0, 154.0, 46.0, 56.0
WALL_R0, WALL_R1, WALL_Z1 = 154.0, 156.0, 58.0
DOME_R, DOME_Z0, DOME_RISE, DOME_THICK = 156.0, 58.0, 40.0, 1.5


def arc_solid(bm, outline, a0, a1, steps):
    """Spins a CONVEX closed (r, z) outline around Z from angle a0 to a1 (0 = -Y, counter-clockwise seen from
    above) and caps both ends: one closed slice of a ring."""
    tmp = bmesh.new()
    rings = []
    for k in range(steps + 1):
        a = a0 + (a1 - a0) * k / steps
        s, c = math.sin(a), -math.cos(a)
        rings.append([tmp.verts.new((r * s, r * c, z)) for r, z in outline])
    n = len(outline)
    for k in range(steps):
        for i in range(n):
            j = (i + 1) % n
            tmp.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    tmp.faces.new(rings[0])
    tmp.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)


def ring_box(bm, r0, r1, z0, z1, a0=-HALF, a1=HALF, steps=3):
    arc_solid(bm, [(r0, z0), (r1, z0), (r1, z1), (r0, z1)], a0, a1, steps)


def aisle_angle(r):
    return 3.0 / r  # a 3-stud aisle at this radius


# ---------------------------------------------------------------- StandWedge
def stand_concrete(bm):
    ring_box(bm, FLOOR_R, LOWER_R0, 0, LOWER_Z0)  # the wall round the floor
    for i in range(LOWER_ROWS):
        r = LOWER_R0 + i * LOWER_DEPTH
        ring_box(bm, r, r + LOWER_DEPTH, 0, LOWER_Z0 + LOWER_RISE * (i + 1))
    top_lower = LOWER_Z0 + LOWER_RISE * LOWER_ROWS
    ring_box(bm, WALK_R0, WALK_R1, 0, top_lower)  # the walkway between the tiers
    ring_box(bm, WALK_R1 - 0.01, WALK_R1 + 1.0, top_lower, UPPER_Z0)  # the upper tier's front wall
    for i in range(UPPER_ROWS):
        r = UPPER_R0 + i * UPPER_DEPTH
        ring_box(bm, r, r + UPPER_DEPTH, 0, UPPER_Z0 + UPPER_RISE * (i + 1))
    ring_box(bm, WALL_R0, WALL_R1, 0, WALL_Z1)  # the outer wall


SEAT_PITCH = 2.0  # seat to seat along a row


def seat_row(bm, r, z):
    """One row of seats facing the middle, on the tread from r to r + 3 at height z, leaving the aisle at the
    wedge's -angle edge. A seat is a back and a pan (two boxes, 24 triangles)."""
    rs = r + 1.6
    a0 = -HALF + aisle_angle(r)
    usable = (HALF - a0) * rs
    n = int(usable // SEAT_PITCH)
    first = a0 + ((usable - n * SEAT_PITCH) / 2 + SEAT_PITCH / 2) / rs
    for k in range(n):
        a = first + k * SEAT_PITCH / rs
        rot = Matrix.Rotation(a, 4, "Z")

        def at(dr, dz):
            return Vector(((rs + dr) * math.sin(a), -(rs + dr) * math.cos(a), z + dz))
        H.box(bm, at(0.75, 1.05), (1.7, 0.3, 1.5), rot)  # the back
        H.box(bm, at(-0.05, 0.85), (1.7, 1.3, 0.25), rot)  # the pan


def stand_seats_lower(bm):
    for i in range(LOWER_ROWS):
        seat_row(bm, LOWER_R0 + i * LOWER_DEPTH, LOWER_Z0 + LOWER_RISE * (i + 1))


def stand_seats_upper(bm):
    for i in range(UPPER_ROWS):
        seat_row(bm, UPPER_R0 + i * UPPER_DEPTH, UPPER_Z0 + UPPER_RISE * (i + 1))


# A sponsor board on the wall round the floor, facing the middle (+Y for this wedge).
BOARD_Y = -(FLOOR_R - 0.2)


def facing_middle(y_face, z_mid):
    """place() for text on a face looking toward +Y (the arena's middle, for this wedge)."""
    def place(x, up, depth):
        return Vector((-x, y_face + depth, z_mid + up))
    return place


def stand_board(bm):
    H.box(bm, (0, BOARD_Y, 2.1), (17.0, 0.4, 3.0))


def stand_board_trim(bm):
    H.box(bm, (0, BOARD_Y + 0.25, 0.85), (17.0, 0.1, 0.4))  # a yellow stripe along the board's foot


def stand_board_logo(bm):
    B.add_text(bm, "CENTRAL", 1.7, 0.04, facing_middle(BOARD_Y + 0.2, 2.3))


def stand_ribbon(bm):
    top_lower = LOWER_Z0 + LOWER_RISE * LOWER_ROWS
    ring_box(bm, WALK_R1 - 0.2, WALK_R1, top_lower + 1.2, UPPER_Z0 - 0.6)


def stand_suites(bm):
    ring_box(bm, SUITE_R0, SUITE_R1, SUITE_Z0, SUITE_Z0 + 1.5)
    ring_box(bm, SUITE_R0, SUITE_R1, SUITE_Z1 - 1.5, SUITE_Z1)
    ring_box(bm, SUITE_R0 + 2, WALL_R0, SUITE_Z0 + 1.5, SUITE_Z1 - 1.5)  # the suites' back block


def stand_glass(bm):
    ring_box(bm, SUITE_R0 + 1.6, SUITE_R0 + 2.0, SUITE_Z0 + 1.5, SUITE_Z1 - 1.5)


def stand_rails(bm):
    # Handrails at the front of each tier and down the aisle.
    for r, z in ((LOWER_R0 + 0.3, LOWER_Z0), (WALK_R1 + 1.3, UPPER_Z0)):
        ring_box(bm, r, r + 0.3, z + 3.0, z + 3.3)
        for a in (-HALF + 0.01, 0, HALF - 0.08):
            ring_box(bm, r, r + 0.3, z, z + 3.0, a, a + 0.25 / r, 1)


B.piece("StandWedge_Concrete", CONCRETE, stand_concrete, smooth=False)
B.piece("StandWedge_SeatsLower", SEAT, stand_seats_lower, smooth=False)
B.piece("StandWedge_SeatsUpper", SEAT, stand_seats_upper, smooth=False)
B.piece("StandWedge_Board", NAVY, stand_board, smooth=False)
B.piece("StandWedge_BoardTrim", YELLOW, stand_board_trim, smooth=False)
B.piece("StandWedge_BoardLogo", WHITE, stand_board_logo, smooth=False)
B.piece("StandWedge_Ribbon", RIBBON, stand_ribbon, smooth=False)
B.piece("StandWedge_Suites", DARK, stand_suites, smooth=False)
B.piece("StandWedge_Glass", GLASS, stand_glass, smooth=False)
B.piece("StandWedge_Rails", STEEL, stand_rails, smooth=False)


# ---------------------------------------------------------------- DomeWedge
def dome_point(t):
    """(r, z) on the dome's inner surface, t = 0 at the rim to 1 at the top (a circular arc)."""
    # A spherical cap through the rim (DOME_R, DOME_Z0) and the top (0, DOME_Z0 + DOME_RISE).
    sphere_r = (DOME_R ** 2 + DOME_RISE ** 2) / (2 * DOME_RISE)
    centre_z = DOME_Z0 + DOME_RISE - sphere_r
    rim_angle = math.asin(DOME_R / sphere_r)
    a = rim_angle * (1 - t)
    return sphere_r * math.sin(a), centre_z + sphere_r * math.cos(a), sphere_r, centre_z


def dome_shell(bm):
    steps = 8
    for k in range(steps):
        r0, z0, _, _ = dome_point(k / steps)
        r1, z1, _, _ = dome_point((k + 1) / steps)
        # One band of the shell, DOME_THICK thick (a convex quad outline).
        outline = [(r0, z0), (r1, z1), (r1 * 1.0, z1 + DOME_THICK), (r0, z0 + DOME_THICK)]
        if r1 < 0.5:
            outline = [(r0, z0), (0.01, z1), (0.01, z1 + DOME_THICK), (r0, z0 + DOME_THICK)]
        arc_solid(bm, outline, -HALF, HALF, 3)
    ring_box(bm, WALL_R0, WALL_R1 + 1, WALL_Z1, DOME_Z0 + 2)  # the rim beam the dome sits on


def dome_lattice(bm):
    steps = 10
    # The meridian rib down the wedge's edge, then diagonal braces and ring beams: the criss-cross truss look.
    for k in range(steps):
        r0, z0, _, _ = dome_point(k / steps)
        r1, z1, _, _ = dome_point((k + 1) / steps)
        if r1 < 1:
            break
        arc_solid(bm, [(r0, z0 - 1.2), (r1, z1 - 1.2), (r1, z1 - 0.01), (r0, z0 - 0.01)], -HALF, -HALF + 0.6 / r0, 1)
        if k % 2 == 0:
            ring_box(bm, r1 - 0.4, r1 + 0.4, z1 - 1.0, z1 - 0.01, -HALF, HALF, 3)
    for k in range(0, steps - 2, 2):
        # Two braces crossing the wedge between ring beams.
        ra, za, _, _ = dome_point(k / steps)
        rb, zb, _, _ = dome_point((k + 2) / steps)
        for sa, sb in ((-HALF, HALF), (HALF, -HALF)):
            p = Vector((ra * math.sin(sa), -ra * math.cos(sa), za - 0.6))
            q = Vector((rb * math.sin(sb), -rb * math.cos(sb), zb - 0.6))
            d = q - p
            rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
            H.box(bm, (p + q) / 2, (0.5, 0.5, d.length), rot)


def dome_lights(bm):
    r, z = WALL_R0 - 3, DOME_Z0 - 2
    H.cylinder(bm, (0, -r, z), 1.0, 1.4, "Z", 10)


B.piece("DomeWedge_Shell", DOME, dome_shell, smooth=False)
B.piece("DomeWedge_Lattice", STEEL, dome_lattice, smooth=False)
B.piece("DomeWedge_Lights", GLOW, dome_lights)


# ---------------------------------------------------------------- ArenaFloor
B.piece("ArenaFloor_Base", FLOOR, lambda bm: H.cylinder(bm, (0, 0, -0.5), FLOOR_R + 0.5, 1.0, "Z", 48), smooth=False)
B.piece("ArenaFloor_Mat", MAT_GREY, lambda bm: H.box(bm, (0, 0, 0.1), (130, 80, 0.2)), smooth=False)  # corners inside r 80
B.piece("ArenaFloor_Aisle", MAT_DARK, lambda bm: H.box(bm, (0, -14, 0.15), (130, 8, 0.2)), smooth=False)


# ---------------------------------------------------------------- CentreCube (hangs with its top at z = 0 here)
CUBE_W, CUBE_H = 26.0, 14.0


def cube_frame(bm):
    H.box(bm, (0, 0, -CUBE_H / 2), (CUBE_W, CUBE_W, CUBE_H))
    H.box(bm, (0, 0, -CUBE_H - 4), (CUBE_W * 0.7, CUBE_W * 0.7, 4.0))  # the lower body under the ring
    for sx in (-1, 1):
        for sy in (-1, 1):
            H.cylinder(bm, (sx * 9, sy * 9, 12), 0.15, 24, "Z", 6)  # the hanging cables up to the roof


def cube_screens(bm):
    for a in range(4):
        rot = Matrix.Rotation(a * math.pi / 2, 4, "Z")
        H.box(bm, rot @ Vector((0, -CUBE_W / 2 - 0.1, -CUBE_H / 2)), (CUBE_W - 2, 0.2, CUBE_H - 2), rot)


def cube_ring(bm):
    for a in range(4):
        rot = Matrix.Rotation(a * math.pi / 2, 4, "Z")
        H.box(bm, rot @ Vector((0, -CUBE_W * 0.35 - 0.1, -CUBE_H - 2.5)), (CUBE_W * 0.7, 0.2, 1.6), rot)


def cube_speakers(bm):
    for a in range(4):
        rot = Matrix.Rotation(a * math.pi / 2 + math.pi / 4, 4, "Z")
        H.box(bm, rot @ Vector((0, -CUBE_W * 0.85, -6)), (2.6, 2.4, 16), rot)


B.piece("CentreCube_Frame", BLACK, cube_frame, smooth=False)
B.piece("CentreCube_Screens", SCREEN, cube_screens, smooth=False)
B.piece("CentreCube_Ring", RIBBON, cube_ring, smooth=False)
B.piece("CentreCube_Speakers", BLACK, cube_speakers, smooth=False)


def cube_logo(bm):
    # CENTRAL on each side of the lower body, under the lit ring.
    for a in range(4):
        rot = Matrix.Rotation(a * math.pi / 2, 3, "Z")
        face = -CUBE_W * 0.35

        def place(x, up, depth, rot=rot, face=face):
            return rot @ Vector((x, face - depth, -CUBE_H - 4.9 + up))
        B.add_text(bm, "CENTRAL", 2.2, 0.05, place)


B.piece("CentreCube_Logo", WHITE, cube_logo, smooth=False)


# ---------------------------------------------------------------- RackGantry
GANTRY_W, GANTRY_H, SCREEN_W, SCREEN_H = 22.0, 26.0, 18.0, 10.0


def gantry_frame(bm):
    for sx in (-1, 1):
        x = sx * GANTRY_W / 2
        H.box(bm, (x, 0, 0.3), (3.0, 3.0, 0.6))  # a weighted foot
        for dx in (-0.6, 0.6):
            for dy in (-0.6, 0.6):
                H.box(bm, (x + dx, dy, GANTRY_H / 2), (0.25, 0.25, GANTRY_H))  # the truss leg's four tubes
        for z in range(2, int(GANTRY_H), 3):
            H.box(bm, (x, -0.6, z), (1.2, 0.2, 0.2))
            H.box(bm, (x, 0.6, z), (1.2, 0.2, 0.2))
    H.box(bm, (0, 0, GANTRY_H + 0.6), (GANTRY_W + 1.5, 1.5, 1.2))  # the top beam
    # The screen's black backing (user 2026-11-01: the backs, seen from the warm-up area, black, not yellow).
    H.box(bm, (0, -0.55, GANTRY_H - SCREEN_H / 2 - 1.2), (SCREEN_W + 1.0, 0.5, SCREEN_H + 1.0))


def gantry_screen(bm):
    H.box(bm, (0, -0.9, GANTRY_H - SCREEN_H / 2 - 1.2), (SCREEN_W, 0.25, SCREEN_H))


def gantry_trim(bm):
    # The yellow border round the front of the screen only. (The number panel under it went when the GantryBanner
    # came: the banner covers that space.)
    z = GANTRY_H - SCREEN_H / 2 - 1.2
    for dz in (-1, 1):
        H.box(bm, (0, -0.9, z + dz * (SCREEN_H / 2 + 0.25)), (SCREEN_W + 1.0, 0.3, 0.5))
    for dx in (-1, 1):
        H.box(bm, (dx * (SCREEN_W / 2 + 0.25), -0.9, z), (0.5, 0.3, SCREEN_H))


B.piece("RackGantry_Frame", BLACK, gantry_frame, smooth=False)
B.piece("RackGantry_Screen", SCREEN, gantry_screen, smooth=False)
B.piece("RackGantry_Trim", YELLOW, gantry_trim, smooth=False)
B.piece("RackGantry_Logo", WHITE,
        lambda bm: B.add_text(bm, "CENTRAL", 0.9, 0.04, H.on_front((0, 0, 0), -0.75, GANTRY_H + 0.6)), smooth=False)


# ---------------------------------------------------------------- ArenaEntrance (outside the gym, scaled down)
ENT_R, BRICK_H, DRUM_R, DRUM_H, ENT_RISE = 55.0, 22.0, 50.0, 14.0, 15.0
ARCH_C, ARCH_R, SPRING = (-12.5, 0.0, 12.5), 4.5, 9.0  # three round arches: centres, radius, springing height
FRONT_Y = -ENT_R * math.cos(3 * HALF)  # the flat entrance front spans the front 45 degrees
FRONT_HALF_W = ENT_R * math.sin(3 * HALF)


def hull(bm, points):
    """A closed convex solid round the points."""
    tmp = bmesh.new()
    for p in points:
        tmp.verts.new(p)
    bmesh.ops.convex_hull(tmp, input=tmp.verts[:])
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)


def arch_points(c, r, n=12):
    """The arch's curve from left to right: (x, z) on a half circle round (c, SPRING)."""
    return [(c + r * math.cos(math.pi * (1 - i / n)), SPRING + r * math.sin(math.pi * (1 - i / n))) for i in range(n + 1)]


def entrance_brick(bm):
    # The brick base as wedges, leaving the front three (45 degrees) for the flat entrance front.
    for k in range(24):
        a0 = -HALF + k * WEDGE
        if k in (0, 1, 23):
            continue
        arc_solid(bm, [(ENT_R - 3, 0), (ENT_R, 0), (ENT_R, BRICK_H), (ENT_R - 3, BRICK_H)], a0, a0 + WEDGE, 2)
    # The front: brick piers between the openings, and above each opening the wall down to its round top, built
    # as thin vertical strips (each convex) from the arch's curve up to the top.
    y0, y1 = FRONT_Y - 0.5, FRONT_Y + 2.5
    edges = [-FRONT_HALF_W] + [c + s * ARCH_R for c in ARCH_C for s in (-1, 1)] + [FRONT_HALF_W]
    for x0, x1 in zip(edges[0::2], edges[1::2]):
        H.span(bm, (x0, y0, 0), (x1, y1, BRICK_H))
    for c in ARCH_C:
        pts = arch_points(c, ARCH_R)
        for (xa, za), (xb, zb) in zip(pts, pts[1:]):
            hull(bm, [(x, y, z) for y in (y0, y1) for x, z in ((xa, za), (xb, zb), (xb, BRICK_H), (xa, BRICK_H))])


def entrance_stone(bm):
    # Cream stone: a ring round each arch, a band at the springing height on the piers, and a band near the top.
    y0, y1 = FRONT_Y - 0.85, FRONT_Y - 0.45
    for c in ARCH_C:
        inner, outer = arch_points(c, ARCH_R), arch_points(c, ARCH_R + 0.9)
        for i in range(len(inner) - 1):
            quad = (inner[i], inner[i + 1], outer[i + 1], outer[i])
            hull(bm, [(x, y, z) for y in (y0, y1) for x, z in quad])
    edges = [-FRONT_HALF_W] + [c + s * (ARCH_R + 0.9) for c in ARCH_C for s in (-1, 1)] + [FRONT_HALF_W]
    for x0, x1 in zip(edges[0::2], edges[1::2]):
        H.span(bm, (x0, y0, SPRING - 0.5), (x1, y1, SPRING + 0.2))
    H.span(bm, (-FRONT_HALF_W, y0, BRICK_H - 2.6), (FRONT_HALF_W, y1, BRICK_H - 1.8))


def entrance_doors(bm):
    # Dark doorways in the openings (set back), with the round tops.
    for c in ARCH_C:
        H.span(bm, (c - ARCH_R, FRONT_Y + 2.0, 0), (c + ARCH_R, FRONT_Y + 2.5, SPRING + ARCH_R))


def entrance_glass(bm):
    # A pair of glass doors in each opening.
    for c in ARCH_C:
        for s in (-1, 1):
            H.box(bm, (c + s * ARCH_R / 2, FRONT_Y + 1.85, 3.75), (ARCH_R - 0.4, 0.2, 7.5))


def entrance_sign_frame(bm):
    H.box(bm, (0, FRONT_Y - 0.9, 16.4), (18.0, 0.8, 3.6))


def entrance_sign_screen(bm):
    # The game writes the arena's name on it.
    H.box(bm, (0, FRONT_Y - 1.35, 16.4), (17.0, 0.1, 2.8))


def entrance_windows(bm):
    # Small square windows round the ribbed drum, between the ribs.
    z = BRICK_H + 1.6 + DRUM_H * 0.62
    for k in range(10):
        a = (k + 0.5) * 2 * math.pi / 10 + math.pi / 32
        ring_box(bm, DRUM_R - 0.1, DRUM_R + 0.3, z - 1.2, z + 1.2, a - 1.2 / DRUM_R, a + 1.2 / DRUM_R, 1)


def entrance_cornice(bm):
    lathe = [(DRUM_R - 1, BRICK_H), (ENT_R + 1.2, BRICK_H), (ENT_R + 1.2, BRICK_H + 1.6), (DRUM_R - 1, BRICK_H + 1.6)]
    arc_solid(bm, lathe, 0, 2 * math.pi - 1e-4, 48)


def entrance_drum(bm):
    arc_solid(bm, [(DRUM_R - 2, BRICK_H + 1.6), (DRUM_R, BRICK_H + 1.6), (DRUM_R, BRICK_H + 1.6 + DRUM_H),
                   (DRUM_R - 2, BRICK_H + 1.6 + DRUM_H)], 0, 2 * math.pi - 1e-4, 48)
    for k in range(32):  # the ribs (pilasters) round the drum
        a = k * 2 * math.pi / 32
        ring_box(bm, DRUM_R, DRUM_R + 0.8, BRICK_H + 1.6, BRICK_H + 1.6 + DRUM_H, a - 0.012, a + 0.012, 1)


def entrance_roof(bm):
    z0 = BRICK_H + 1.6 + DRUM_H
    sphere_r = (DRUM_R ** 2 + ENT_RISE ** 2) / (2 * ENT_RISE)
    centre_z = z0 + ENT_RISE - sphere_r
    rim = math.asin(DRUM_R / sphere_r)
    outline = [(0.0, z0)] + [(sphere_r * math.sin(rim * (1 - t / 10)), centre_z + sphere_r * math.cos(rim * (1 - t / 10)))
                             for t in range(11)]
    outline[-1] = (0.0, z0 + ENT_RISE)
    H.lathe_z(bm, outline, 48)


def entrance_ring(bm):
    z0 = BRICK_H + 1.6 + DRUM_H
    arc_solid(bm, [(DRUM_R - 0.5, z0), (DRUM_R + 1.0, z0), (DRUM_R + 1.0, z0 + 1.2), (DRUM_R - 0.5, z0 + 1.2)],
              0, 2 * math.pi - 1e-4, 48)


B.piece("ArenaEntrance_Brick", BRICK, entrance_brick, smooth=False)
B.piece("ArenaEntrance_Stone", CREAM, entrance_stone, smooth=False)
B.piece("ArenaEntrance_Doors", DARK, entrance_doors, smooth=False)
B.piece("ArenaEntrance_Glass", GLASS, entrance_glass, smooth=False)
B.piece("ArenaEntrance_SignFrame", BLACK, entrance_sign_frame, smooth=False)
B.piece("ArenaEntrance_SignScreen", SCREEN, entrance_sign_screen, smooth=False)
B.piece("ArenaEntrance_Windows", DARK, entrance_windows, smooth=False)
B.piece("ArenaEntrance_Cornice", CONCRETE, entrance_cornice, smooth=False)
B.piece("ArenaEntrance_Drum", CREAM, entrance_drum, smooth=False)
B.piece("ArenaEntrance_Roof", ROOF, entrance_roof)
B.piece("ArenaEntrance_Ring", WHITE, entrance_ring, smooth=False)


# GantryBanner (user 2026-11-01: "the space between rack # and the rack itself, fill in a banner"): a navy CENTRAL
# backdrop hung inside each rack's gantry, from just under the screen to the floor, in front of the number panel.
# Built in the gantry's frame (place it like the gantry).
BANNER_W, BANNER_Z0, BANNER_Z1, BANNER_Y = GANTRY_W - 1.6, 0.6, 14.2, -1.0


def gantry_banner_cloth(bm):
    H.box(bm, (0, BANNER_Y, (BANNER_Z0 + BANNER_Z1) / 2), (BANNER_W, 0.15, BANNER_Z1 - BANNER_Z0))


def gantry_banner_trim(bm):
    for z in (BANNER_Z0 + 0.7, BANNER_Z1 - 0.7):
        H.box(bm, (0, BANNER_Y - 0.1, z), (BANNER_W, 0.05, 0.45))


def gantry_banner_logo(bm):
    front = BANNER_Y - 0.1
    B.add_text(bm, "CENTRAL", 3.2, 0.03, H.on_front((0, 0, 0), front, 10.6))
    B.add_text(bm, "STATE CHAMPIONSHIP", 1.05, 0.03, H.on_front((0, 0, 0), front, 8.1))


B.piece("GantryBanner_Cloth", NAVY, gantry_banner_cloth, smooth=False)
B.piece("GantryBanner_Trim", YELLOW, gantry_banner_trim, smooth=False)
B.piece("GantryBanner_Logo", WHITE, gantry_banner_logo, smooth=False)


# ---------------------------------------------------------------- Floor and stand props
# JudgesTable: a table for a platform's three judges. Its skirt (with CENTRAL) faces -Y as usual; the game turns
# it so the judges sit behind it facing their platform.
def judges_top(bm):
    H.box(bm, (0, 0, 2.55), (12.0, 3.0, 0.2))


def judges_skirt(bm):
    H.box(bm, (0, -1.45, 1.45), (12.0, 0.1, 2.0))
    for s in (-1, 1):
        H.box(bm, (s * 5.95, 0, 1.45), (0.1, 2.9, 2.0))


def judges_legs(bm):
    for sx in (-1, 1):
        for sy in (-1, 1):
            H.box(bm, (sx * 5.6, sy * 1.2, 1.2), (0.25, 0.25, 2.4))


B.piece("JudgesTable_Top", BLACK, judges_top, smooth=False)
B.piece("JudgesTable_Skirt", NAVY, judges_skirt, smooth=False)
B.piece("JudgesTable_Trim", YELLOW, lambda bm: H.box(bm, (0, -1.52, 0.65), (12.0, 0.05, 0.3)), smooth=False)
B.piece("JudgesTable_Logo", WHITE,
        lambda bm: B.add_text(bm, "CENTRAL", 1.0, 0.03, H.on_front((0, 0, 0), -1.5, 1.6)), smooth=False)
B.piece("JudgesTable_Legs", STEEL, judges_legs, smooth=False)


# CameraTripod: a TV camera on a tripod, the lens toward -Y (the photos' cameras in the front rows).
def tripod_legs(bm):
    top = Vector((0, 0, 4.2))
    for k in range(3):
        a = k * 2 * math.pi / 3 + math.pi / 2
        foot = Vector((1.6 * math.cos(a), 1.6 * math.sin(a), 0.0))
        d = top - foot
        H.box(bm, (top + foot) / 2, (0.18, 0.18, d.length), d.to_track_quat("Z", "Y").to_matrix().to_4x4())
    H.box(bm, (0, 0, 3.9), (0.3, 0.3, 1.2))  # the centre column
    H.box(bm, (0, 0, 4.6), (0.7, 0.7, 0.4))  # the head
    H.box(bm, (0, 1.2, 4.6), (0.12, 2.4, 0.12))  # the pan handle, out the back


def tripod_body(bm):
    H.box(bm, (0, 0, 5.4), (0.9, 2.0, 1.1))
    H.box(bm, (0, 0.2, 6.15), (0.25, 1.2, 0.25))  # the carry handle
    H.box(bm, (0, 1.15, 5.6), (0.5, 0.3, 0.4))  # the viewfinder


def tripod_lens(bm):
    H.cylinder(bm, (0, -1.4, 5.4), 0.42, 0.9, "Y", 14)


def tripod_screen(bm):
    H.box(bm, (0.55, -0.3, 5.5), (0.08, 0.9, 0.6))  # the flip-out monitor


B.piece("CameraTripod_Legs", BLACK, tripod_legs, smooth=False)
B.piece("CameraTripod_Body", DARK, tripod_body, smooth=False)
B.piece("CameraTripod_Lens", GLASS, tripod_lens)
B.piece("CameraTripod_Screen", SCREEN, tripod_screen, smooth=False)


# ArenaBanner: a championship banner hung round the top of the stands (pointed at the bottom), front -Y.
RED = mat("Red", (200, 30, 38), 0.0, 0.45)


def banner_cloth(bm):
    hull(bm, [(x, y, z) for y in (-0.08, 0.08) for x, z in ((-3, 12), (3, 12), (3, 2), (0, 0), (-3, 2))])


def banner_trim(bm):
    H.box(bm, (0, -0.1, 10.9), (6.0, 0.05, 0.5))
    H.box(bm, (0, -0.1, 3.4), (6.0, 0.05, 0.35))


def banner_text(bm):
    B.add_text(bm, "STATE", 1.25, 0.03, H.on_front((0, 0, 0), -0.1, 8.6))
    B.add_text(bm, "CHAMPS", 1.0, 0.03, H.on_front((0, 0, 0), -0.1, 6.9))
    B.add_text(bm, "CENTRAL", 0.75, 0.03, H.on_front((0, 0, 0), -0.1, 5.0))


B.piece("ArenaBanner_Cloth", RED, banner_cloth, smooth=False)
B.piece("ArenaBanner_Trim", YELLOW, banner_trim, smooth=False)
B.piece("ArenaBanner_Text", WHITE, banner_text, smooth=False)
B.piece("ArenaBanner_Rod", STEEL, lambda bm: H.cylinder(bm, (0, 0, 12.3), 0.15, 7.0, "X", 8))


# ArenaFlag: the big flag hung from the roof near the centre cube, seen from both sides.
def flag_cloth(bm):
    H.box(bm, (0, 0, 5.5), (18.0, 0.15, 11.0))


def flag_stripes(bm):
    for z in (1.6, 9.4):
        H.box(bm, (0, 0, z), (18.0, 0.25, 0.9))


def flag_logo(bm):
    B.add_text(bm, "CENTRAL", 3.0, 0.03, H.on_front((0, 0, 0), -0.1, 5.5))

    def back(x, up, depth):
        return Vector((-x, 0.1 + depth, 5.5 + up))
    B.add_text(bm, "CENTRAL", 3.0, 0.03, back)


B.piece("ArenaFlag_Cloth", NAVY, flag_cloth, smooth=False)
B.piece("ArenaFlag_Stripes", YELLOW, flag_stripes, smooth=False)
B.piece("ArenaFlag_Logo", WHITE, flag_logo, smooth=False)
B.piece("ArenaFlag_Rod", STEEL, lambda bm: H.cylinder(bm, (0, 0, 11.3), 0.2, 19.0, "X", 8))


# NameSign: the big sign on the suites at each end of the bowl ("LOUISIANA" in the photos); the game writes
# STATE CHAMPIONSHIP on its screen. Front -Y.
def name_frame(bm):
    H.box(bm, (0, 0, 4.0), (44.0, 1.2, 8.0))


def name_trim(bm):
    for z in (0.5, 7.5):
        H.box(bm, (0, -0.65, z), (44.0, 0.1, 0.5))


B.piece("NameSign_Frame", BLACK, name_frame, smooth=False)
B.piece("NameSign_Screen", SCREEN, lambda bm: H.box(bm, (0, -0.65, 4.0), (42.0, 0.1, 6.0)), smooth=False)
B.piece("NameSign_Trim", YELLOW, name_trim, smooth=False)


# ---------------------------------------------------------------- Preview (not exported)
def preview():
    coll = bpy.data.collections.get("Preview")
    if coll is None:
        coll = bpy.data.collections.new("Preview")
        bpy.context.scene.collection.children.link(coll)
    for ob in list(coll.objects):
        bpy.data.objects.remove(ob, do_unlink=True)

    def copy(src, matrix, tag):
        ob = bpy.data.objects.new(f"Preview_{tag}_{src.name}", src.data)
        ob.matrix_world = matrix @ src.matrix_world
        coll.objects.link(ob)
        return ob

    bpy.context.view_layer.update()  # new objects' matrix_world is only set after an update
    parts = [o for o in B.coll.objects]
    for o in parts:
        o.hide_render = o.hide_viewport = False
    for k in range(1, 24):
        rot = Matrix.Rotation(k * WEDGE, 4, "Z")
        for o in parts:
            if o.name.startswith(("StandWedge", "DomeWedge")):
                copy(o, rot, f"W{k}")
    def facing_middle_at(r, a, z):
        """At angle a (0 = -Y) and radius r, turned so the item's -Y front faces the arena's middle."""
        return Matrix.Translation((r * math.sin(a), -r * math.cos(a), z)) @ Matrix.Rotation(a + math.pi, 4, "Z")

    racks = (-45, -15, 15, 45)
    placements = {
        # The centre cube hangs 60 studs up; the entrance sits far away for its own render.
        "CentreCube": [Matrix.Translation((0, 0, 62))],
        "ArenaEntrance": [Matrix.Translation((500, 0, 0))],
        # A gantry behind each rack, a judges' table in front of each platform (the judges face the rack).
        "RackGantry": [Matrix.Translation((x, 12, 0)) for x in racks],
        "GantryBanner": [Matrix.Translation((x, 12, 0)) for x in racks],
        "JudgesTable": [Matrix.Translation((x, -17, 0)) @ Matrix.Rotation(math.pi, 4, "Z") for x in racks],
        # TV cameras on the walkway between the tiers and on the floor's front corners.
        "CameraTripod": [facing_middle_at(114, a, 20) for a in (-0.3, 0.0, 0.3)]
        + [Matrix.Translation((x, -34, 0)) @ Matrix.Rotation(math.pi + s * 0.5, 4, "Z") for x, s in ((-62, 1), (62, -1))],
        # Banners round the top of the stands, name signs on the suites at both ends, the flag near the cube.
        "ArenaBanner": [facing_middle_at(143, k * WEDGE, 47) for k in (2, 4, 8, 10, 14, 16, 20, 22)],
        "NameSign": [facing_middle_at(145.2, a, 47.5) for a in (math.pi / 2, 3 * math.pi / 2)],
        "ArenaFlag": [Matrix.Translation((0, 42, 72))],
    }
    for o in parts:
        for prefix, matrices in placements.items():
            if o.name.startswith(prefix):
                for i, m in enumerate(matrices):
                    copy(o, m, f"{prefix}{i}")
                o.hide_render = o.hide_viewport = True
    bm = bmesh.new()
    for x in racks:
        H.box(bm, (x, 0, 0.4), (16, 16, 0.6))  # platform
        H.box(bm, (x, 1, 4.5), (6, 4, 8))  # rack
    for k, (x, y) in enumerate([(-30, -30), (0, -34), (30, -30), (20, 30), (-60, 20)]):
        H.box(bm, (x, y, 2.5), (1.6, 1.0, 5.0))  # people for scale (5 studs tall)
    mesh = bpy.data.meshes.new("Preview_Blocks")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(MAT_DARK)
    ob = bpy.data.objects.new("Preview_Blocks", mesh)
    coll.objects.link(ob)

    def cam(name, loc, target, lens):
        c = bpy.data.objects.new(name, bpy.data.cameras.new(name))
        coll.objects.link(c)
        c.data.lens, c.data.clip_end, c.location = lens, 3000, loc
        c.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam("Preview_CamStands", (20, -133, 46), (0, 10, 4), 16)
    cam("Preview_CamFloor", (-25, -60, 6), (5, 10, 22), 14)
    cam("Preview_CamOut", (440, -150, 30), (500, 0, 20), 24)
    cam("Preview_CamFront", (500, -105, 12), (500, -40, 14), 22)


preview()
print("built", len(B.coll.objects), "objects")
