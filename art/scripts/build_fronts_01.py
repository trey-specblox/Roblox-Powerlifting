# Builds Fronts_01 in the live Blender scene: the block-built details of the themed room fronts that no earlier
# model covers (blocks to Blender, batch 8; user 2026-10-28: "everything still made with blocks change into models
# through blender ... If its a micro model/detail it does not have to be SUPER detailed because i want to make sure
# everything is optimized"). Few pieces (the game's unique-mesh budget): every barbell is one model painted its own
# colour, and the fronts' clocks, whiteboard frame and rails reuse earlier models.
#
#   Barbell         a barbell lying along X: shaft (the game paints each bar's colour), steel collars and sleeves.
#   BarbellUpright  the same barbell standing up (the Mock Meet front's "gun rack").
#   WallBarRack     the black wall rack for horizontal bars: two uprights with seven pairs of hooks.
#   GunRack         the black top and bottom bars of the upright rack.
#   JudgesLights    the judges' lights: a black housing with three white lamps.
#   Stick           a stick of chalk or a marker (painted its colour).
#   Duster          the chalkboard duster.
#   FoamTile        a 2 x 2 acoustic foam tile with pyramids (the game paints each tile's colour).
#   Blinds          the Office window's white blinds with their head rail.
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, items stand on z = 0 with their front toward -Y;
# front items have the wall at y = 0 (y = -d, d the old blocks' distance out from the wall). Sizes are the old
# blocks' (RoomProps FRONT.MockMeet / Classroom / RecordsWall / Coach / MediaRoom / Office).
# Run in an otherwise empty file (art/blender/Fronts_01.blend):
#   exec(compile(open(path).read(), path, "exec"), {"__file__": path, "__name__": "__main__"})
# Objects are replaced by name on every run.

import math
import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

B = H.Builder("Fronts_01")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.5, alpha=1.0, emission=None):
    return H.material("FR_" + name, tuple(linear(c) for c in rgb), metallic, roughness, alpha, emission)


# Preview colours (Roblox paints the pieces with the fronts' looks or StarterGymConfig.PropColourways).
STEEL = mat("Silver", (190, 192, 198), 1.0, 0.3)
RUST = mat("Rust", (140, 80, 50), 0.6, 0.6)
BLACK = mat("Black", (22, 22, 24), 0.0, 0.5)
GLOW = mat("GlowWhite", (255, 250, 240), 0.0, 0.3, emission=(1.0, 0.98, 0.94))
WHITE = mat("White", (236, 236, 232), 0.0, 0.6)
OAK = mat("Oak", (198, 152, 102), 0.0, 0.6)
FOAM = mat("Foam", (60, 90, 170), 0.0, 0.95)


def front_box(bm, x0, a0, a1, d0, d1, y0, y1, bevel=0.0, base=0.0):
    """A box given like the old front blocks: a along the wall (x = x0 + a), d out from it (y = -d), y up
    (z = y - base)."""
    centre = Vector((x0 + (a0 + a1) / 2, -(d0 + d1) / 2, (y0 + y1) / 2 - base))
    size = Vector((a1 - a0, d1 - d0, y1 - y0))
    if bevel:
        H.rounded_box(bm, centre, size, bevel, 1)
    else:
        H.box(bm, centre, size)


# ------------------------------------------------------------------ Barbell (x = 0) and BarbellUpright (x = 12)
# The old blocks: a 5.8 shaft 0.15 thick, collars (0.15 long, 0.34 across) at +-2.975, sleeves (1.85 long, 0.22
# across) at +-3.975; the bar's middle 0.17 up (lying) or 4.9 up (standing).


def bar_shaft(axis, centre):
    def build(bm):
        H.cylinder(bm, centre, 0.075, 5.8, axis=axis, segments=8)
    return build


def bar_steel(axis, centre):
    def build(bm):
        unit = Vector((1, 0, 0)) if axis == "X" else Vector((0, 0, 1))
        for sign in (-1, 1):
            H.cylinder(bm, centre + unit * (sign * 2.975), 0.17, 0.15, axis=axis, segments=12)
            H.cylinder(bm, centre + unit * (sign * 3.975), 0.11, 1.85, axis=axis, segments=10)
    return build


LYING, STANDING = Vector((0, 0, 0.17)), Vector((12, 0, 4.9))
B.piece("Barbell_Shaft", STEEL, bar_shaft("X", LYING))
B.piece("Barbell_Steel", STEEL, bar_steel("X", LYING))
B.piece("BarbellUpright_Shaft", STEEL, bar_shaft("Z", STANDING))
B.piece("BarbellUpright_Steel", STEEL, bar_steel("Z", STANDING))

# ------------------------------------------------------------------ WallBarRack (x = 20)
# Uprights at a +-2.6 (0.4 wide, d 0.06..0.25, 4.2 to 9.6 up); for each of seven bars (4.6 + 0.72 k up) a hook
# pair: an arm out to d 0.62 and a lip at its end.


def wall_bar_rack(bm):
    for offset in (-2.6, 2.6):
        front_box(bm, 20, offset - 0.2, offset + 0.2, 0.06, 0.25, 4.2, 9.6, 0.03, base=4.2)
        for k in range(7):
            y = 4.6 + k * 0.72
            front_box(bm, 20, offset - 0.15, offset + 0.15, 0.25, 0.62, y - 0.2, y - 0.12, base=4.2)
            front_box(bm, 20, offset - 0.15, offset + 0.15, 0.56, 0.62, y - 0.12, y + 0.06, base=4.2)


B.piece("WallBarRack_Rack", BLACK, wall_bar_rack, smooth=False)

# ------------------------------------------------------------------ GunRack (x = 30)
# The top bar (7.7..8.0 up) and the bottom bar (1.0..1.2), 10.4 long, d 0.06..0.6.


def gun_rack(bm):
    front_box(bm, 30, -5.2, 5.2, 0.06, 0.6, 7.7, 8.0, 0.03, base=1.0)
    front_box(bm, 30, -5.2, 5.2, 0.06, 0.6, 1.0, 1.2, 0.03, base=1.0)


B.piece("GunRack_Rack", BLACK, gun_rack, smooth=False)

# ------------------------------------------------------------------ JudgesLights (x = 40)
# The housing a -4..4 (its middle the old a -23), d 0.06..0.4, 5 to 8 up; lamps 1.4 across at a -2, 0, 2 and 6.5
# up, d 0.4..0.52, each in a black hood.


def judges_housing(bm):
    front_box(bm, 40, -4, 4, 0.06, 0.4, 5, 8, 0.08, base=5)
    for a in (-2, 0, 2):
        H.cylinder(bm, Vector((40 + a, -0.44, 1.5)), 0.8, 0.08, axis="Y", segments=20)


B.piece("JudgesLights_Housing", BLACK, judges_housing)
B.piece("JudgesLights_Lamps", GLOW, lambda bm: [H.cylinder(bm, Vector((40 + a, -0.5, 1.5)), 0.7, 0.04, axis="Y",
                                                           segments=20) for a in (-2, 0, 2)])

# ------------------------------------------------------------------ Stick (x = 46) and Duster (x = 48)
B.piece("Stick_Body", WHITE, lambda bm: H.cylinder(bm, Vector((46.0, 0, 0.045)), 0.045, 0.45, axis="X", segments=8))


def duster(bm):
    H.rounded_box(bm, Vector((48.0, 0, 0.05)), Vector((0.86, 0.26, 0.1)), 0.02, 1)
    H.rounded_box(bm, Vector((48.0, 0, 0.145)), Vector((0.9, 0.28, 0.09)), 0.04, 2)


B.piece("Duster_Body", OAK, duster)

# ------------------------------------------------------------------ FoamTile (x = 52)
# A 2 x 2 tile 0.3 deep: a 0.1 base on the wall and a 4 x 4 grid of pyramids pointing out (-Y).


def foam_tile(bm):
    H.box(bm, Vector((52.0, -0.05, 1.0)), Vector((2.0, 0.1, 2.0)))
    import bmesh
    for i in range(4):
        for j in range(4):
            cx, cz = 52.0 - 0.75 + i * 0.5, 0.25 + j * 0.5
            tmp = bmesh.new()
            v = [tmp.verts.new(p) for p in ((cx - 0.25, -0.1, cz - 0.25), (cx + 0.25, -0.1, cz - 0.25),
                                            (cx + 0.25, -0.1, cz + 0.25), (cx - 0.25, -0.1, cz + 0.25), (cx, -0.3, cz))]
            for a, b in ((0, 1), (1, 2), (2, 3), (3, 0)):
                tmp.faces.new((v[a], v[b], v[4]))
            tmp.faces.new((v[3], v[2], v[1], v[0]))
            tmp.normal_update()
            H._merge(bm, tmp)


B.piece("FoamTile_Foam", FOAM, foam_tile, smooth=False)

# ------------------------------------------------------------------ Blinds (x = 60)
# Sixteen 6.6-wide slats 0.18 tall, 0.26 apart from 4.05 up, d 0.09..0.12; a head rail over them to 8.28.


def blinds(bm):
    for k in range(16):
        y = 4.05 + k * 0.26
        front_box(bm, 60, -3.3, 3.3, 0.09, 0.12, y, y + 0.18, base=4.05)
    front_box(bm, 60, -3.3, 3.3, 0.09, 0.15, 8.15, 8.28, 0.02, base=4.05)


B.piece("Blinds_Slats", WHITE, blinds, smooth=False)

print("Fronts_01 built:", sorted(o.name for o in B.coll.objects))
