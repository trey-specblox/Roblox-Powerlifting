# Builds WeighBooth_01: the small weigh-in booth that stands by the State arena's sign-up desk between meets (user 2026-11-06:
# "small weight scale rooms maybe with like a shower curtain for cover"). Scenery for now: weigh-in stays automatic.
#
#   WeighBooth  a steel frame with navy side and back walls, a WEIGH-IN sign over the front, a shower curtain half drawn on a rail with
#               rings, and inside a floor scale with a post, its read-out and CENTRAL on it. 6 wide, 5 deep, about 8.2 tall.
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, stands on z = 0, its front toward -Y. Objects are "<Item>_<Piece>" with ONE
# material each. One mesh, reused for every booth.
#
# Run in an otherwise empty file (art/blender/WeighBooth_01.blend):
#   exec(compile(open(path).read(), path, "exec"), {"__file__": path, "__name__": "__main__"})
# Objects are replaced by name on every run.

import math
import os
import sys

import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

B = H.Builder("WeighBooth_01")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.5, emission=None):
    lin = tuple(linear(c) for c in rgb)
    return H.material("WB_" + name, lin, metallic, roughness, 1.0, emission)


# Preview colours (Roblox colours each piece from StarterGymConfig.PropColourways).
NAVY = mat("Navy", (30, 48, 98), 0.0, 0.5)
BLACK = mat("Black", (22, 22, 24), 0.0, 0.5)
YELLOW = mat("Yellow", (242, 190, 30), 0.0, 0.4)
WHITE = mat("White", (236, 236, 232), 0.0, 0.45)
STEEL = mat("Steel", (190, 192, 198), 1.0, 0.3)
RUBBER = mat("Rubber", (46, 48, 54), 0.0, 0.9)
SCREEN = mat("Screen", (40, 220, 130), 0.0, 0.2, (0.1, 0.9, 0.5))

WIDTH, DEPTH = 6.0, 5.0
HEIGHT = 7.4  # the top of the walls
POST = 0.14  # half a corner post's thickness
FRONT_Y = -DEPTH / 2
BACK_Y = DEPTH / 2
RAIL_Y = FRONT_Y + 0.28
RAIL_Z = HEIGHT - 0.42

# ------------------------------------------------------------------ the floor
B.piece("WeighBooth_Base", RUBBER, lambda bm: H.rounded_box(bm, Vector((0, 0, 0.1)), Vector((WIDTH, DEPTH, 0.2)), 0.05), smooth=False)


# ------------------------------------------------------------------ the frame
def frame(bm):
    for x in (-WIDTH / 2 + POST, WIDTH / 2 - POST):
        for y in (FRONT_Y + POST, BACK_Y - POST):
            H.box(bm, Vector((x, y, HEIGHT / 2)), Vector((2 * POST, 2 * POST, HEIGHT)))
    # The top: round the four sides.
    for y in (FRONT_Y + POST, BACK_Y - POST):
        H.box(bm, Vector((0, y, HEIGHT - POST)), Vector((WIDTH, 2 * POST, 2 * POST)))
    for x in (-WIDTH / 2 + POST, WIDTH / 2 - POST):
        H.box(bm, Vector((x, 0, HEIGHT - POST)), Vector((2 * POST, DEPTH - 4 * POST, 2 * POST)))


B.piece("WeighBooth_Frame", BLACK, frame, smooth=False)


# ------------------------------------------------------------------ the walls: the back and two sides, up to the top rail
def walls(bm):
    z0, z1 = 0.2, HEIGHT - 2 * POST
    middle = (z0 + z1) / 2
    tall = z1 - z0
    H.box(bm, Vector((0, BACK_Y - POST, middle)), Vector((WIDTH - 4 * POST, 0.08, tall)))
    for x in (-WIDTH / 2 + POST, WIDTH / 2 - POST):
        H.box(bm, Vector((x, 0, middle)), Vector((0.08, DEPTH - 4 * POST, tall)))


B.piece("WeighBooth_Walls", NAVY, walls, smooth=False)


# A stripe along the side walls and the back, in the game's yellow.
def stripes(bm):
    z = 3.4
    H.box(bm, Vector((0, BACK_Y - POST - 0.05, z)), Vector((WIDTH - 4 * POST, 0.02, 0.28)))
    for sign in (-1, 1):
        H.box(bm, Vector((sign * (WIDTH / 2 - POST + 0.05), 0, z)), Vector((0.02, DEPTH - 4 * POST, 0.28)))


B.piece("WeighBooth_Stripes", YELLOW, stripes, smooth=False)

# ------------------------------------------------------------------ the sign over the front
SIGN_Y = FRONT_Y - 0.02
SIGN_Z = HEIGHT + 0.42
B.piece("WeighBooth_Sign", BLACK, lambda bm: H.rounded_box(bm, Vector((0, SIGN_Y + 0.1, SIGN_Z)), Vector((WIDTH - 0.2, 0.2, 0.84)), 0.05), smooth=False)
B.piece("WeighBooth_SignTrim", YELLOW, lambda bm: H.box(bm, Vector((0, SIGN_Y - 0.01, SIGN_Z - 0.36)), Vector((WIDTH - 0.5, 0.02, 0.06))), smooth=False)
B.piece("WeighBooth_SignText", WHITE, lambda bm: B.add_text(bm, "WEIGH-IN", 0.52, 0.03, H.on_front(Vector((0, 0, 0)), SIGN_Y, SIGN_Z + 0.03)), smooth=False)

# ------------------------------------------------------------------ the curtain, half drawn, on a rail with rings
CURTAIN_LEFT, CURTAIN_RIGHT = -WIDTH / 2 + 0.3, 0.7
CURTAIN_TOP, CURTAIN_BOTTOM = RAIL_Z - 0.2, 0.55
FOLDS = 7
RINGS = FOLDS + 1
FOLD_DEPTH = 0.2
THICK = 0.05


def wave(u):
    """How far a point `u` (0 to 1) along the curtain stands off the rail's line: smooth folds."""
    return FOLD_DEPTH * math.sin(u * FOLDS * 2 * math.pi)


def solid_sheet(bm, top, bottom, left, right, y0):
    """A wavy closed sheet from z = bottom to top, its folds along x, a little thick so both faces show."""
    steps = FOLDS * 8
    rows = {}
    for i in range(steps + 1):
        u = i / steps
        x = left + (right - left) * u
        y = y0 + wave(u)
        rows[i] = [
            bm.verts.new((x, y - THICK, bottom)), bm.verts.new((x, y + THICK, bottom)),
            bm.verts.new((x, y + THICK, top)), bm.verts.new((x, y - THICK, top)),
        ]
    for i in range(steps):
        a, b = rows[i], rows[i + 1]
        for k in range(4):
            bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
    bm.faces.new(tuple(reversed(rows[0])))
    bm.faces.new(tuple(rows[steps]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


B.piece("WeighBooth_Curtain", WHITE, lambda bm: solid_sheet(bm, CURTAIN_TOP, CURTAIN_BOTTOM + 0.34, CURTAIN_LEFT, CURTAIN_RIGHT, RAIL_Y), smooth=True)
# The hem, a band of the game's navy along the bottom.
B.piece("WeighBooth_Hem", NAVY, lambda bm: solid_sheet(bm, CURTAIN_BOTTOM + 0.34, CURTAIN_BOTTOM, CURTAIN_LEFT, CURTAIN_RIGHT, RAIL_Y), smooth=True)
B.piece("WeighBooth_Rail", STEEL, lambda bm: H.cylinder(bm, Vector((0, RAIL_Y, RAIL_Z)), 0.05, WIDTH - 0.3, axis="X", segments=10))


def rings(bm):
    for k in range(RINGS):
        u = k / (RINGS - 1)
        x = CURTAIN_LEFT + (CURTAIN_RIGHT - CURTAIN_LEFT) * u
        H.torus(bm, Vector((x, RAIL_Y, RAIL_Z - 0.04)), 0.12, 0.022, plane="YZ", segments=10, sides=5)


B.piece("WeighBooth_Rings", STEEL, rings)

# ------------------------------------------------------------------ the scale
SCALE_X, SCALE_Y = 0.5, 0.45
B.piece("WeighBooth_ScaleBase", BLACK, lambda bm: H.rounded_box(bm, Vector((SCALE_X, SCALE_Y, 0.3)), Vector((2.4, 2.4, 0.2)), 0.05), smooth=False)
B.piece("WeighBooth_ScaleTop", STEEL, lambda bm: H.rounded_box(bm, Vector((SCALE_X, SCALE_Y, 0.42)), Vector((2.1, 2.1, 0.05)), 0.02), smooth=False)
POST_Y = SCALE_Y + 1.1


def scale_post(bm):
    H.box(bm, Vector((SCALE_X, POST_Y, 1.8)), Vector((0.2, 0.2, 2.8)))
    H.rounded_box(bm, Vector((SCALE_X, POST_Y - 0.03, 3.5)), Vector((1.4, 0.26, 0.8)), 0.06)


B.piece("WeighBooth_ScalePost", BLACK, scale_post, smooth=False)
READ_Y = POST_Y - 0.17
B.piece("WeighBooth_ScaleScreen", SCREEN, lambda bm: H.box(bm, Vector((SCALE_X, READ_Y, 3.56)), Vector((1.14, 0.02, 0.42))), smooth=False)
B.piece("WeighBooth_ScaleLogo", WHITE, lambda bm: B.add_text(bm, "CENTRAL", 0.17, 0.012, H.on_front(Vector((SCALE_X, 0, 0)), READ_Y + 0.015, 3.22)), smooth=False)

print("WeighBooth_01 built:", sorted(o.name for o in B.coll.objects))
