# W Chews' back room kit (GAME_DESIGN §40.7, user 2026-11-21: a small EMPLOYEES ONLY door at the back of the kitchen
# into the mafia boss cow's room, "in the same style"; the cow's wheel gives a luck multiplier, and his games are
# skill games that earn spins. Nothing in this room is ever bet). The room's shell (burgundy carpet, walnut
# panelling, brass rails) is part of WChewsHall_01; this is its furniture. One mesh per repeated object.
#
# Every item is built round its own origin, standing on z = 0 (hanging items: see each), its front toward -Y.
# Object names are "<Item>_<Piece>", one colour per piece (StarterGymConfig.PropColourways paints them).
#
#   The luck wheel (20 wedges of one mesh, turned by code round the wheel's axis and painted by their prize):
#     WcWheelWedge    one 18 degree wedge, its piece of the brass rim and its peg (origin = the wheel's axis; the
#                     wedge points up; radius 5.15)
#     WcWheelStand    the walnut A-frame, the brass axle and hub, the red pointer and a glowing WHEEL OF LUCK sign
#                     (origin = the floor under the axis; the axis is WHEEL_AXIS up)
#   The cow's games:
#     WcArmTable      an arm wrestling table: elbow pads, pin pads and grip pegs               5 x 3.2, top 3.3
#     WcShuffleTable  a green felt table for the cloche shuffle, three brass marks on it      9 x 4.8, top 3.3
#     WcCloche        a silver dish cover with a knob (origin = the table under it)            2.2 across
#   The boss's corner:
#     WcBossDesk      a walnut desk with a green leather top, a banker's lamp, a bell, a ledger, a milk bottle
#     WcBossChair     a tall burgundy leather chair
#   The lounge:
#     WcBooth         a leather booth sofa (colourways: burgundy, deep green)                  10.7 x 3.6
#     WcMilkShelf     the milk bar's back shelf: bottles of plain, strawberry and chocolate milk 14 x 2 x 10
#     WcStool         a brass bar stool with a burgundy seat
#     WcRopeSpan      two brass posts with a velvet rope between them                          6 between the posts
#     WcPortrait      a brass-framed portrait of a cow in a hat (hangs: origin = the middle of its back)
#     WcNeonMoo       THE MOO ROOM in glowing letters (on a wall: origin = the middle of its back)
#     WcRug           a big round navy rug with gold rings and a W                             28 across
#
#   blender -b --factory-startup --python art/scripts/build_wchews_back_01.py -- <out.blend> [<out.glb>]

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

B = H.Builder("WChewsBack")
V = Vector
S = H.span

WOOD = H.material("Wb_Walnut", (0.26, 0.14, 0.07), roughness=0.55)
BRASS = H.material("Wb_Brass", (0.86, 0.64, 0.22), metallic=0.9, roughness=0.3)
STEEL = H.material("Wb_Steel", (0.80, 0.82, 0.85), metallic=0.9, roughness=0.25)
BURGUNDY = H.material("Wb_Burgundy", (0.42, 0.07, 0.12), roughness=0.7)
GREEN = H.material("Wb_LeatherGreen", (0.07, 0.26, 0.18), roughness=0.6)
FELT = H.material("Wb_Felt", (0.05, 0.36, 0.20), roughness=0.95)
MUSTARD = H.material("Wb_Mustard", (0.85, 0.60, 0.14), roughness=0.8)
RED = H.material("Wb_Red", (0.82, 0.12, 0.10), roughness=0.45)
WHITE = H.material("Wb_White", (0.96, 0.95, 0.92), roughness=0.6)
PINK = H.material("Wb_Strawberry", (0.96, 0.62, 0.70), roughness=0.5)
CHOCO = H.material("Wb_Chocolate", (0.36, 0.20, 0.12), roughness=0.5)
BLACK = H.material("Wb_Black", (0.04, 0.04, 0.05), roughness=0.6)
NAVY = H.material("Wb_Navy", (0.05, 0.08, 0.21), roughness=0.55)
SNOUT = H.material("Wb_Snout", (0.96, 0.62, 0.66), roughness=0.6)
GLOW_WARM = H.material("Wb_GlowWarm", (1.0, 0.80, 0.55), emission=(1.0, 0.72, 0.38))
GLOW_GREEN = H.material("Wb_GlowGreen", (0.35, 0.95, 0.55), emission=(0.2, 0.9, 0.45))
GLOW_PINK = H.material("Wb_GlowPink", (1.0, 0.45, 0.65), emission=(1.0, 0.3, 0.55))
WEDGE = H.material("Wb_Wedge", (0.90, 0.88, 0.80), roughness=0.5)


def tube(bm, a, b, radius, segments=8, radius2=None):
    """A capped cylinder (a cone with radius2) from point a to point b."""
    a, b = V(a), V(b)
    d = b - a
    rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius,
                          radius2=radius if radius2 is None else radius2, depth=d.length,
                          matrix=Matrix.Translation((a + b) / 2) @ rot)


def prism(bm, points, y0, y1):
    """A convex polygon in the XZ plane (points: (x, z), in order round it) pushed from y0 to y1."""
    tmp = bmesh.new()
    front = [tmp.verts.new((x, y0, z)) for x, z in points]
    back = [tmp.verts.new((x, y1, z)) for x, z in points]
    n = len(points)
    tmp.faces.new(front)
    tmp.faces.new(list(reversed(back)))
    for i in range(n):
        j = (i + 1) % n
        tmp.faces.new((front[j], front[i], back[i], back[j]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)


def polar(radius, degrees):
    """A point of the wheel's face: `degrees` clockwise from straight up, seen from the front."""
    a = math.radians(degrees)
    return (radius * math.sin(a), radius * math.cos(a))


# ======================================================================= WcWheelWedge (origin = the wheel's axis)
WEDGES = 20
HALF = 180.0 / WEDGES  # 9 degrees each side of the wedge's middle
WHEEL_R = 5.15
WHEEL_AXIS = 7.6


def wedge_face(bm):
    # From just inside the hub cap out to the rim, in two flat steps so its outer edge follows the circle.
    for a0, a1 in ((-HALF, 0.0), (0.0, HALF)):
        prism(bm, [polar(0.7, a0), polar(4.82, a0), polar(4.82, a1), polar(0.7, a1)], -0.15, 0.15)


def wedge_rim(bm):
    for a0, a1 in ((-HALF, 0.0), (0.0, HALF)):
        prism(bm, [polar(4.8, a0), polar(WHEEL_R, a0), polar(WHEEL_R, a1), polar(4.8, a1)], -0.3, 0.3)
    # The peg the pointer clicks over, on the wedge's edge, standing out of the front.
    x, z = polar(4.97, HALF)
    H.cylinder(bm, V((x, -0.55, z)), 0.13, 0.5, axis="Y", segments=6)


B.piece("WcWheelWedge_Face", WEDGE, wedge_face, smooth=False)
B.piece("WcWheelWedge_Rim", BRASS, wedge_rim, smooth=False)

# ======================================================================= WcWheelStand (origin = the floor under the axis)
SIGN_Z = WHEEL_AXIS + 7.0  # (clear of the pointer, which hangs from 5.75 to 6.0 over the axis)


def stand_frame(bm):
    # An A-frame behind the wheel, a base beam with two feet, and the post that carries the pointer and the sign.
    for s in (-1, 1):
        tube(bm, (s * 3.6, 1.2, 0.3), (s * 0.3, 1.2, WHEEL_AXIS + 0.2), 0.38, segments=4)
        S(bm, (s * 3.6 - 0.45, -2.2, 0.0), (s * 3.6 + 0.45, 2.6, 0.5))
    S(bm, (-4.1, 0.7, 0.0), (4.1, 1.7, 0.55))
    S(bm, (-0.4, 0.8, WHEEL_AXIS - 0.3), (0.4, 1.5, SIGN_Z - 0.6))
    H.rounded_box(bm, V((0, 1.1, SIGN_Z)), (8.6, 0.6, 1.5), 0.2, segments=2)


def stand_brass(bm):
    # The axle through the wheel, the hub cap over the wedges' inner ends, and the pointer's arm.
    H.cylinder(bm, V((0, 0.5, WHEEL_AXIS)), 0.32, 1.9, axis="Y", segments=10)
    H.cylinder(bm, V((0, -0.42, WHEEL_AXIS)), 0.95, 0.3, axis="Y", segments=20)
    H.sphere(bm, V((0, -0.55, WHEEL_AXIS)), 0.5, scale=(1, 0.5, 1), segments=12, rings=6)
    S(bm, (-0.22, -0.78, WHEEL_AXIS + 5.72), (0.22, 0.85, WHEEL_AXIS + 6.0))
    # A trim line round the sign board.
    S(bm, (-4.3, 0.74, SIGN_Z - 0.78), (4.3, 0.8, SIGN_Z - 0.7))
    S(bm, (-4.3, 0.74, SIGN_Z + 0.7), (4.3, 0.8, SIGN_Z + 0.78))


def stand_pointer(bm):
    # A red flapper hanging over the top of the wheel: its tip rides over the pegs.
    top = WHEEL_AXIS + 5.75
    prism(bm, [(-0.38, top), (0.38, top), (0.0, WHEEL_AXIS + 4.72)], -0.78, -0.56)


def stand_sign(bm):
    B.add_text(bm, "WHEEL OF LUCK", 0.82, 0.05, H.on_front((0, 0, 0), 0.79, SIGN_Z))


def stand_bulbs(bm):
    for k in range(9):
        H.sphere(bm, V((-4.0 + k, 0.9, SIGN_Z + 0.95)), 0.2, segments=6, rings=4)


B.piece("WcWheelStand_Frame", WOOD, stand_frame, smooth=False)
B.piece("WcWheelStand_Brass", BRASS, stand_brass)
B.piece("WcWheelStand_Pointer", RED, stand_pointer, smooth=False)
B.piece("WcWheelStand_Sign", GLOW_WARM, stand_sign, smooth=False)
B.piece("WcWheelStand_Bulbs", GLOW_WARM, stand_bulbs)

# ======================================================================= WcArmTable (5 x 3.2, top at 3.3)
# The two wrestlers stand at its -Y and +Y sides.


def arm_wood(bm):
    H.rounded_box(bm, V((0, 0, 3.15)), (5.0, 3.2, 0.3), 0.08, segments=1)
    H.lathe_z(bm, [(0.0, 0.0), (1.4, 0.0), (1.4, 0.2), (0.5, 0.5), (0.42, 3.0), (0.0, 3.0)], 12)


def arm_pads(bm):
    # An elbow pad for each wrestler.
    H.rounded_box(bm, V((0.55, -0.75, 3.36)), (1.2, 1.1, 0.14), 0.05, segments=1)
    H.rounded_box(bm, V((-0.55, 0.75, 3.36)), (1.2, 1.1, 0.14), 0.05, segments=1)


def arm_pins(bm):
    # The pin pads at each end: where the loser's hand lands.
    for s in (-1, 1):
        H.rounded_box(bm, V((s * 1.75, 0, 3.35)), (1.1, 1.5, 0.12), 0.05, segments=1)


def arm_brass(bm):
    # A grip peg for each wrestler's free hand, and a brass band round the top's edge.
    H.cylinder(bm, V((-2.05, -1.2, 3.75)), 0.11, 0.9, segments=8)
    H.cylinder(bm, V((2.05, 1.2, 3.75)), 0.11, 0.9, segments=8)
    H.sphere(bm, V((-2.05, -1.2, 4.22)), 0.17, segments=8, rings=4)
    H.sphere(bm, V((2.05, 1.2, 4.22)), 0.17, segments=8, rings=4)
    H.lathe_z(bm, [(1.4, 0.2), (1.46, 0.2), (1.46, 0.3), (1.4, 0.3)], 12)


B.piece("WcArmTable_Wood", WOOD, arm_wood)
B.piece("WcArmTable_Pads", BURGUNDY, arm_pads)
B.piece("WcArmTable_Pins", MUSTARD, arm_pins)
B.piece("WcArmTable_Brass", BRASS, arm_brass)

# ======================================================================= WcShuffleTable (9 x 4.8, top at 3.3)
CLOCHE_XS = (-2.7, 0.0, 2.7)


def shuffle_wood(bm):
    H.rounded_box(bm, V((0, 0, 3.1)), (9.0, 4.8, 0.36), 0.12, segments=2)
    for x in (-2.7, 2.7):
        H.lathe_z(bm, [(0.0, 0.0), (1.3, 0.0), (1.3, 0.2), (0.45, 0.5), (0.4, 2.95), (0.0, 2.95)], 12,
                  centre=V((x, 0, 0)))


def shuffle_felt(bm):
    H.rounded_box(bm, V((0, 0, 3.27)), (8.3, 4.1, 0.08), 0.02, segments=1)


def shuffle_brass(bm):
    # A mark under each cloche, and a rail along the player's side.
    for x in CLOCHE_XS:
        H.lathe_z(bm, [(1.18, 3.31), (1.3, 3.31), (1.3, 3.33), (1.18, 3.33)], 20, centre=V((x, 0, 0)))
    H.cylinder(bm, V((0, -2.62, 3.05)), 0.09, 8.4, axis="X", segments=8)
    for x in (-3.6, 0.0, 3.6):
        S(bm, (x - 0.08, -2.62, 2.98), (x + 0.08, -2.3, 3.12))


B.piece("WcShuffleTable_Wood", WOOD, shuffle_wood)
B.piece("WcShuffleTable_Felt", FELT, shuffle_felt)
B.piece("WcShuffleTable_Brass", BRASS, shuffle_brass)

# ======================================================================= WcCloche (origin = the table under it)
# A closed shape (a flat underside): lifted, you see steel from below, not through it.


def cloche(bm):
    H.lathe_z(bm, [(0.0, 0.0), (1.12, 0.0), (1.12, 0.07), (1.0, 0.11), (0.93, 0.5), (0.66, 0.86), (0.22, 1.02),
                   (0.11, 1.04), (0.11, 1.12), (0.22, 1.2), (0.12, 1.3), (0.0, 1.32)], 16)


B.piece("WcCloche_Dome", STEEL, cloche)

# ======================================================================= WcBossDesk (12.2 x 5.2, top at 3.65)
# Visitors stand at its front (-Y); the boss sits behind it (+Y).


def desk_body(bm):
    for s in (-1, 1):
        S(bm, (s * 2.6, -2.2, 0.15), (s * 5.8, 2.2, 3.35))
        S(bm, (s * 2.5, -2.3, 0.0), (s * 5.9, 2.3, 0.2))
    S(bm, (-2.6, -2.2, 1.1), (2.6, -1.9, 3.35))
    H.rounded_box(bm, V((0, 0, 3.5)), (12.2, 5.2, 0.3), 0.08, segments=1)
    # The lamp's base plate and the ledger's cover (dark), flat on the top.
    S(bm, (-1.5, -1.0, 3.69), (0.7, 0.8, 3.74))


def desk_leather(bm):
    S(bm, (-5.4, -2.05, 3.65), (5.4, 2.05, 3.69))


def desk_trim(bm):
    # Brass lines on the pedestals' fronts, drawer pulls on the boss's side, the lamp's stem, the bell, the bottle's cap.
    for s in (-1, 1):
        S(bm, (s * 2.9, -2.26, 0.6), (s * 5.5, -2.2, 0.68))
        S(bm, (s * 2.9, -2.26, 2.9), (s * 5.5, -2.2, 2.98))
        for z in (1.0, 1.9, 2.8):
            H.cylinder(bm, V((s * 4.2, 2.26, z)), 0.07, 1.2, axis="X", segments=6)
    H.cylinder(bm, V((-4.3, -0.5, 3.76)), 0.5, 0.14, segments=12)
    H.cylinder(bm, V((-4.3, -0.5, 4.45)), 0.07, 1.3, segments=6)
    H.sphere(bm, V((3.9, -1.2, 3.69)), 0.42, scale=(1, 1, 0.75), segments=12, rings=6)
    H.cylinder(bm, V((3.9, -1.2, 4.05)), 0.07, 0.14, segments=6)
    H.cylinder(bm, V((4.5, 0.9, 4.9)), 0.15, 0.1, segments=8)


def desk_lamp(bm):
    # A banker's lamp's green glass shade.
    H.cylinder(bm, V((-4.3, -0.5, 5.2)), 0.36, 1.7, axis="X", segments=10)


def desk_white(bm):
    # The ledger's pages and a bottle of milk.
    S(bm, (-1.4, -0.9, 3.74), (0.6, 0.7, 3.84))
    H.lathe_z(bm, [(0.0, 3.69), (0.3, 3.69), (0.3, 4.38), (0.13, 4.62), (0.13, 4.86), (0.0, 4.86)], 8,
              centre=V((4.5, 0.9, 0)))


B.piece("WcBossDesk_Body", WOOD, desk_body, smooth=False)
B.piece("WcBossDesk_Leather", GREEN, desk_leather, smooth=False)
B.piece("WcBossDesk_Trim", BRASS, desk_trim)
B.piece("WcBossDesk_Lamp", GLOW_GREEN, desk_lamp)
B.piece("WcBossDesk_White", WHITE, desk_white)

# ======================================================================= WcBossChair (front = the way the sitter faces, -Y)


def chair_leather(bm):
    H.rounded_box(bm, V((0, -0.1, 2.0)), (2.7, 2.5, 0.7), 0.22, segments=2)
    H.rounded_box(bm, V((0, 1.05, 4.2)), (2.7, 0.6, 4.6), 0.22, segments=2)
    for s in (-1, 1):
        H.rounded_box(bm, V((s * 1.5, -0.05, 2.75)), (0.5, 2.4, 0.5), 0.16, segments=2)
        H.rounded_box(bm, V((s * 1.5, 0.9, 2.3)), (0.4, 0.5, 0.9), 0.1, segments=1)
        # The back's wings.
        H.rounded_box(bm, V((s * 1.45, 0.75, 5.2)), (0.4, 0.9, 2.2), 0.14, segments=1)


def chair_wood(bm):
    for sx in (-1, 1):
        for y in (-1.0, 1.0):
            H.cylinder(bm, V((sx * 1.05, y, 0.85)), 0.16, 1.7, segments=6, radius2=0.22)


def chair_brass(bm):
    # Studs along the top of the back, and a button row down its middle.
    for k in range(6):
        H.sphere(bm, V((-1.0 + 0.4 * k, 0.74, 6.3)), 0.07, segments=6, rings=3)
    for z in (3.4, 4.3, 5.2):
        for x in (-0.6, 0.6):
            H.sphere(bm, V((x, 0.73, z)), 0.07, segments=6, rings=3)


B.piece("WcBossChair_Leather", BURGUNDY, chair_leather)
B.piece("WcBossChair_Wood", WOOD, chair_wood)
B.piece("WcBossChair_Brass", BRASS, chair_brass)

# ======================================================================= WcBooth (10.7 x 3.6; its back toward +Y)


def booth_wood(bm):
    S(bm, (-5.0, -1.5, 0.0), (5.0, 1.8, 0.9))
    S(bm, (-5.0, 1.3, 0.9), (5.0, 1.8, 4.3))


def booth_leather(bm):
    for x in (-3.3, 0.0, 3.3):
        H.rounded_box(bm, V((x, -0.25, 1.3)), (3.22, 2.9, 0.85), 0.25, segments=2)
        H.rounded_box(bm, V((x, 1.0, 3.05)), (3.22, 0.8, 2.9), 0.25, segments=2)
    for s in (-1, 1):
        H.rounded_box(bm, V((s * 5.1, 0.1, 1.75)), (0.6, 3.4, 3.5), 0.2, segments=2)


def booth_brass(bm):
    H.cylinder(bm, V((0, 1.55, 4.42)), 0.1, 10.0, axis="X", segments=6)
    for s in (-1, 1):
        H.sphere(bm, V((s * 5.05, 1.55, 4.42)), 0.2, segments=8, rings=4)
    S(bm, (-5.0, -1.56, 0.15), (5.0, -1.5, 0.25))


B.piece("WcBooth_Wood", WOOD, booth_wood, smooth=False)
B.piece("WcBooth_Leather", BURGUNDY, booth_leather)
B.piece("WcBooth_Brass", BRASS, booth_brass)

# ======================================================================= WcMilkShelf (14 x 2 x 10; its back toward +Y)
SHELVES = (4.4, 6.3, 8.2)
BOTTLE_XS = [-5.4 + 1.8 * k for k in range(7)]


def bottles(kind):
    """The bottles of one flavour: plain on shelves' places 0, 3, 6, strawberry 1, 4, chocolate 2, 5 (shifted a place
    on each shelf)."""
    def build(bm):
        for row, z in enumerate(SHELVES):
            for k, x in enumerate(BOTTLE_XS):
                if (k + row) % 3 == kind:
                    H.lathe_z(bm, [(0.0, z + 0.2), (0.32, z + 0.2), (0.32, z + 0.95), (0.14, z + 1.2), (0.14, z + 1.42),
                                   (0.0, z + 1.42)], 6, centre=V((x, -0.1, 0)))
    return build


def shelf_wood(bm):
    S(bm, (-7.0, 0.6, 0.0), (7.0, 1.0, 10.0))
    S(bm, (-7.0, -1.0, 0.0), (7.0, 0.6, 3.2))
    for z in SHELVES:
        S(bm, (-6.8, -0.9, z), (6.8, 0.6, z + 0.2))
    for s in (-1, 1):
        S(bm, (s * 6.8, -0.9, 3.2), (s * 7.0, 0.6, 10.0))
    H.rounded_box(bm, V((0, 0.0, 10.15)), (14.4, 2.3, 0.3), 0.08, segments=1)


def shelf_brass(bm):
    S(bm, (-7.0, -1.06, 2.9), (7.0, -1.0, 3.0))
    S(bm, (-7.0, -1.06, 0.3), (7.0, -1.0, 0.4))
    # A little rail along each shelf's front edge, and every bottle's cap.
    for z in SHELVES:
        H.cylinder(bm, V((0, -0.85, z + 0.42)), 0.05, 13.6, axis="X", segments=6)
        for x in BOTTLE_XS:
            H.cylinder(bm, V((x, -0.1, z + 1.47)), 0.16, 0.1, segments=6)


def shelf_glow(bm):
    # A warm strip under each shelf and under the cornice, lighting the bottles below.
    for z in SHELVES[1:] + (10.0,):
        S(bm, (-6.6, 0.3, z - 0.1), (6.6, 0.5, z - 0.02))


B.piece("WcMilkShelf_Wood", WOOD, shelf_wood, smooth=False)
B.piece("WcMilkShelf_Brass", BRASS, shelf_brass)
B.piece("WcMilkShelf_Milk", WHITE, bottles(0))
B.piece("WcMilkShelf_Strawberry", PINK, bottles(1))
B.piece("WcMilkShelf_Chocolate", CHOCO, bottles(2))
B.piece("WcMilkShelf_Glow", GLOW_WARM, shelf_glow, smooth=False)

# ======================================================================= WcStool


def stool_brass(bm):
    H.lathe_z(bm, [(0.0, 0.0), (0.95, 0.0), (0.95, 0.12), (0.16, 0.32), (0.13, 2.5), (0.0, 2.5)], 12)
    H.torus(bm, (0, 0, 1.0), 0.62, 0.05, segments=12, sides=6)
    for k in range(3):
        a = 2 * math.pi * k / 3
        tube(bm, (0.12 * math.cos(a), 0.12 * math.sin(a), 1.0), (0.62 * math.cos(a), 0.62 * math.sin(a), 1.0), 0.04, 4)


def stool_seat(bm):
    H.lathe_z(bm, [(0.0, 2.5), (0.9, 2.5), (1.0, 2.68), (0.94, 2.95), (0.6, 3.05), (0.0, 3.07)], 12)


B.piece("WcStool_Brass", BRASS, stool_brass)
B.piece("WcStool_Seat", BURGUNDY, stool_seat)

# ======================================================================= WcRopeSpan (6 between the posts)


def rope_posts(bm):
    for s in (-1, 1):
        H.lathe_z(bm, [(0.0, 0.0), (0.65, 0.0), (0.65, 0.12), (0.13, 0.32), (0.1, 2.95), (0.24, 3.05), (0.24, 3.25),
                       (0.1, 3.38), (0.0, 3.4)], 10, centre=V((s * 3.0, 0, 0)))


def rope(bm):
    # A hanging curve in six straight pieces.
    points = []
    for k in range(7):
        t = k / 6
        x = -2.82 + 5.64 * t
        z = 3.1 - 0.75 * (1 - (2 * t - 1) ** 2)
        points.append((x, 0.0, z))
    for a, b in zip(points, points[1:]):
        tube(bm, a, b, 0.13, segments=6)


B.piece("WcRopeSpan_Posts", BRASS, rope_posts)
B.piece("WcRopeSpan_Rope", BURGUNDY, rope)

# ======================================================================= WcPortrait (5 x 6.4; origin = the middle of its back)


def portrait_frame(bm):
    S(bm, (-2.5, -0.28, 2.8), (2.5, 0.0, 3.2))
    S(bm, (-2.5, -0.28, -3.2), (2.5, 0.0, -2.8))
    for s in (-1, 1):
        S(bm, (s * 2.1, -0.28, -2.8), (s * 2.5, 0.0, 2.8))
    H.sphere(bm, V((0, -0.2, 3.3)), 0.3, scale=(1.6, 0.5, 0.7), segments=8, rings=4)


def portrait_canvas(bm):
    S(bm, (-2.1, -0.1, -2.8), (2.1, -0.02, 2.8))


def portrait_hide(bm):
    # The cow's face and ears.
    H.rounded_box(bm, V((0, -0.14, -0.2)), (2.0, 0.07, 2.0), 0.03, segments=1)
    for s in (-1, 1):
        H.box(bm, V((s * 1.25, -0.14, 0.35)), (0.7, 0.07, 0.4), rotation=Matrix.Rotation(math.radians(-s * 20), 4, "Y"))


def portrait_snout(bm):
    H.rounded_box(bm, V((0, -0.19, -0.75)), (1.5, 0.07, 0.8), 0.03, segments=1)


def portrait_dark(bm):
    # His hat, his eyes and nostrils, and his suit's shoulders.
    S(bm, (-1.7, -0.22, 0.75), (1.7, -0.15, 0.98))
    H.rounded_box(bm, V((0, -0.185, 1.5)), (2.0, 0.07, 1.1), 0.03, segments=1)
    for s in (-1, 1):
        S(bm, (s * 0.3, -0.21, 0.05), (s * 0.62, -0.17, 0.4))
        S(bm, (s * 0.25, -0.26, -0.85), (s * 0.45, -0.22, -0.65))
    prism(bm, [(-2.1, -2.8), (2.1, -2.8), (2.1, -2.0), (0.9, -1.25), (-0.9, -1.25), (-2.1, -2.0)], -0.17, -0.1)


def portrait_tie(bm):
    # A white shirt front with a red tie on it, and the hat's red band.
    prism(bm, [(-0.45, -1.3), (0.45, -1.3), (0.0, -2.2)], -0.21, -0.17)
    S(bm, (-1.0, -0.26, 1.0), (1.0, -0.22, 1.22))


B.piece("WcPortrait_Frame", BRASS, portrait_frame)
B.piece("WcPortrait_Canvas", NAVY, portrait_canvas, smooth=False)
B.piece("WcPortrait_Hide", WHITE, portrait_hide, smooth=False)
B.piece("WcPortrait_Snout", SNOUT, portrait_snout, smooth=False)
B.piece("WcPortrait_Dark", BLACK, portrait_dark, smooth=False)
B.piece("WcPortrait_Tie", RED, portrait_tie, smooth=False)

# ======================================================================= WcNeonMoo (origin = the middle of its back)


def neon(bm):
    B.add_text(bm, "THE MOO ROOM", 1.7, 0.08, H.on_front((0, 0, 0), -0.02, 0.0))


def neon_line(bm):
    # A glowing line under the words, with a small star at each end.
    S(bm, (-7.2, -0.16, -1.5), (7.2, -0.02, -1.36))
    for s in (-1, 1):
        H.sphere(bm, V((s * 7.6, -0.1, -1.43)), 0.26, scale=(1, 0.35, 1), segments=8, rings=4)


B.piece("WcNeonMoo_Words", GLOW_PINK, neon, smooth=False)
B.piece("WcNeonMoo_Line", GLOW_WARM, neon_line)

# ======================================================================= WcRug (28 across, flat on the floor)


def rug_field(bm):
    H.lathe_z(bm, [(0.0, 0.0), (13.2, 0.0), (13.2, 0.06), (0.0, 0.06)], 40)


def rug_gold(bm):
    H.lathe_z(bm, [(13.2, 0.0), (14.0, 0.0), (14.0, 0.07), (13.2, 0.07)], 40)
    H.lathe_z(bm, [(8.2, 0.05), (8.7, 0.05), (8.7, 0.09), (8.2, 0.09)], 40)
    # A W in the middle, read from the door (-Y).
    B.add_text(bm, "W", 6.0, 0.02, lambda x, up, depth: V((x, up, 0.07 + depth)))


def rug_centre(bm):
    H.lathe_z(bm, [(0.0, 0.05), (5.2, 0.05), (5.2, 0.08), (0.0, 0.08)], 32)


B.piece("WcRug_Field", NAVY, rug_field, smooth=False)
B.piece("WcRug_Gold", MUSTARD, rug_gold, smooth=False)
B.piece("WcRug_Centre", BURGUNDY, rug_centre, smooth=False)

# Each item's bounds (the game pivots a copy at the bottom centre of its bounds: the layout needs that offset).
bpy.context.view_layer.update()
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
per = {}
for o in B.coll.objects:
    per[o.name.split("_")[0]] = per.get(o.name.split("_")[0], 0) + sum(len(p.vertices) - 2 for p in o.data.polygons)
print("WCHEWS BACK BUILT:", len(B.coll.objects), "objects,", tris, "triangles;", per)
