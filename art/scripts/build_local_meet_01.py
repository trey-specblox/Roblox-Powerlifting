# Builds LocalMeet_01 in the live Blender scene: the Local meet venue's new models (GAME_DESIGN 29.10, "The Local
# meet", step 3; user 2026-10-29: a building outside the gym, a dark arena with lit platforms, referee light boxes,
# tiered seating, an awards podium and a warm-up area). The hall reuses MockMeet_01 (platform, board, banner, desk),
# the gym's competition rack and the light fittings; these are the pieces it did not have. Five items, side by side:
#
#   RefLights     the referees' light box on a floor stand: a black housing with THREE separate lamps (Lamp1..3,
#                 one object each, so the game lights each one white or red after a lift), a yellow trim and
#                 CENTRAL.
#   Bleachers     one section of tiered seating: four steps of navy risers with oak seat planks, yellow nosing on
#                 every step, a steel rail along the back, CENTRAL on the front. The seats face -Y.
#   AwardPodium   the 1-2-3 podium: navy blocks (1st in the middle, highest), gold, silver and bronze tops, the
#                 numbers in white on the front, CENTRAL under the 1.
#   PlateTree     a warm-up plate tree: a black post on crossed feet with three pegs each side, two bumper plates
#                 per peg (big at the bottom, small at the top; one piece per size, so they take competition
#                 colours), silver hubs.
#   MeetHall      the venue's entrance building outside the gym: charcoal walls under a PITCHED black gable roof
#                 with yellow edges and CENTRAL in the front gable (user: no flat roofs, no plain boxes), an
#                 entrance porch sticking out with its own small gable, glass double doors in a black frame (dark
#                 inside) under a light strip, wall lamps, the gym's red competition stripe, navy front panels,
#                 high glass windows, glowing corner strips, and the sign: a black frame round a screen the game
#                 writes LOCAL MEET on, between yellow // slashes.
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, items stand on z = 0 with their front toward -Y.
# Objects are "<Item>_<Piece>" with ONE material each.
#
# Run in an otherwise empty file (art/blender/LocalMeet_01.blend):
#   exec(compile(open(path).read(), path, "exec"), {"__file__": path, "__name__": "__main__"})
# Objects are replaced by name on every run.

import os
import sys

import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

B = H.Builder("LocalMeet_01")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.5, emission=None, alpha=1.0):
    lin = tuple(linear(c) for c in rgb)
    return H.material("LM_" + name, lin, metallic, roughness, alpha, emission)


# Preview colours (Roblox colours each piece from StarterGymConfig.PropColourways).
NAVY = mat("Navy", (30, 48, 98))
BLACK = mat("Black", (22, 22, 24))
CHARCOAL = mat("Charcoal", (46, 48, 54))
OAK = mat("Oak", (198, 152, 102), 0.0, 0.6)
YELLOW = mat("Yellow", (242, 190, 30), 0.0, 0.4)
WHITE = mat("White", (236, 236, 232), 0.0, 0.4)
RED = mat("Red", (200, 30, 38), 0.0, 0.45)
STEEL = mat("Steel", (190, 192, 198), 1.0, 0.3)
BRONZE = mat("Bronze", (176, 110, 60), 1.0, 0.35)
GREY = mat("Grey", (176, 180, 186), 0.0, 0.8)
LAMP = mat("Lamp", (60, 62, 68), 0.0, 0.3)
GLOW = mat("Glow", (255, 250, 240), 0.0, 0.3, emission=(1.0, 0.98, 0.94))
WARM = mat("Warm", (255, 205, 150), 0.0, 0.3, emission=(1.0, 0.8, 0.6))
GLASS = mat("Glass", (205, 225, 235), 0.0, 0.1, alpha=0.35)
SCREEN = mat("Screen", (8, 10, 18), 0.0, 0.08)


def slanted(k):
    """A shear that leans a box's vertical sides to the right by k per unit of height (the UI's slanted tags)."""
    return Matrix(((1, 0, k, 0), (0, 1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)))


def italic_front(x0, y_front, z_mid, k=0.18):
    """place() for text on a front face (toward -Y), leaned like the UI's heavy italic headings."""
    def place(x, up, depth):
        return Vector((x0 + x + k * up, y_front - depth, z_mid + up))
    return place


# ------------------------------------------------------------------ RefLights (x = 0)
# A floor stand about 6 tall; the housing's front (-Y) faces the audience. The three lamps are separate objects.
LX = 0.0
HOUSING_Z = 5.3
HOUSING_FRONT = -0.45


def light_stand(bm):
    H.cylinder(bm, Vector((LX, 0, 0.06)), 0.8, 0.12, segments=20)
    H.cylinder(bm, Vector((LX, 0, 0.12 + 2.25)), 0.1, 4.5, segments=12)
    H.rounded_box(bm, Vector((LX, 0, HOUSING_Z)), Vector((3.4, 0.9, 1.3)), 0.08, 2)


B.piece("RefLights_Housing", BLACK, light_stand)
for index, x in enumerate((-1.05, 0.0, 1.05), start=1):
    B.piece("RefLights_Lamp%d" % index, LAMP, lambda bm, x=x: H.cylinder(
        bm, Vector((LX + x, HOUSING_FRONT - 0.05, HOUSING_Z + 0.15)), 0.37, 0.1, axis="Y", segments=20))
B.piece("RefLights_Trim", YELLOW, lambda bm: H.box(
    bm, Vector((LX, HOUSING_FRONT - 0.02, HOUSING_Z - 0.52)), Vector((3.0, 0.04, 0.08))), smooth=False)
B.piece("RefLights_Logo", WHITE, lambda bm: B.add_text(
    bm, "CENTRAL", 0.14, 0.006, italic_front(LX, HOUSING_FRONT - 0.03, HOUSING_Z - 0.36)), smooth=False)

# ------------------------------------------------------------------ Bleachers (x = 24)
# One section 24 wide and 12 deep: four steps, each 3 deep and 1.5 higher, seats facing -Y. Built as stacked
# slabs (each closed), so every face points outward.
SX = 24.0
SEAT_W = 24.0
STEPS = 4
STEP_D = 3.0
STEP_H = 1.5
FRONT_Y = -STEPS * STEP_D / 2
BACK_Y = -FRONT_Y


def stand_body(bm):
    for k in range(STEPS):
        H.span(bm, Vector((SX - SEAT_W / 2, FRONT_Y + k * STEP_D, k * STEP_H)),
               Vector((SX + SEAT_W / 2, BACK_Y, (k + 1) * STEP_H)))


B.piece("Bleachers_Body", NAVY, stand_body, smooth=False)


def seats(bm):
    for k in range(STEPS):
        top = (k + 1) * STEP_H
        H.rounded_box(bm, Vector((SX, FRONT_Y + k * STEP_D + 1.05, top + 0.09)),
                      Vector((SEAT_W - 0.8, 1.7, 0.18)), 0.05, 2)


B.piece("Bleachers_Seats", OAK, seats)


def nosing(bm):
    for k in range(STEPS):
        H.box(bm, Vector((SX, FRONT_Y + k * STEP_D - 0.03, (k + 1) * STEP_H - 0.06)), Vector((SEAT_W, 0.06, 0.12)))


B.piece("Bleachers_Nosing", YELLOW, nosing, smooth=False)


def back_rail(bm):
    top = STEPS * STEP_H
    rail_y = BACK_Y - 0.3
    for x in (-11.4, -5.7, 0.0, 5.7, 11.4):
        H.cylinder(bm, Vector((SX + x, rail_y, top + 1.3)), 0.1, 2.6, segments=10)
    H.cylinder(bm, Vector((SX, rail_y, top + 2.6)), 0.12, SEAT_W - 0.4, axis="X", segments=10)
    H.cylinder(bm, Vector((SX, rail_y, top + 1.4)), 0.08, SEAT_W - 0.4, axis="X", segments=10)


B.piece("Bleachers_Rail", STEEL, back_rail)
B.piece("Bleachers_Logo", WHITE, lambda bm: B.add_text(
    bm, "CENTRAL", 0.7, 0.01, italic_front(SX, FRONT_Y - 0.01, STEP_H / 2)), smooth=False)

# ------------------------------------------------------------------ AwardPodium (x = 50)
# Blocks 5 x 5: 1st in the middle 3 high, 2nd on the left 2 high, 3rd on the right 1.4 high.
PX = 50.0
BLOCKS = ((0.0, 3.0, "1"), (-5.0, 2.0, "2"), (5.0, 1.4, "3"))


def podium_blocks(bm):
    for x, h, _ in BLOCKS:
        H.rounded_box(bm, Vector((PX + x, 0, (h - 0.1) / 2)), Vector((4.96, 5.0, h - 0.1)), 0.06, 2)


B.piece("AwardPodium_Blocks", NAVY, podium_blocks)
for (x, h, _), name, colour in zip(BLOCKS, ("Gold", "Silver", "Bronze"), (YELLOW, STEEL, BRONZE)):
    B.piece("AwardPodium_" + name, colour, lambda bm, x=x, h=h: H.rounded_box(
        bm, Vector((PX + x, 0, h - 0.05)), Vector((5.0, 5.04, 0.1)), 0.03, 1))


def podium_numbers(bm):
    for x, h, number in BLOCKS:
        B.add_text(bm, number, 1.5 if number == "1" else 1.2, 0.02,
                   italic_front(PX + x, -2.5, (h - 0.1) / 2 + (0.25 if number == "1" else 0.0)))


B.piece("AwardPodium_Numbers", WHITE, podium_numbers, smooth=False)
B.piece("AwardPodium_Logo", YELLOW, lambda bm: B.add_text(
    bm, "CENTRAL", 0.32, 0.01, italic_front(PX, -2.5, 0.75)), smooth=False)

# ------------------------------------------------------------------ PlateTree (x = 65)
# A post 5 tall on crossed feet, three pegs on each side (front -Y and back +Y), two plates on every peg.
TX = 65.0
PEGS = ((1.1, 0.9), (2.5, 0.72), (3.8, 0.52))  # (height, plate radius)


def tree_frame(bm):
    H.box(bm, Vector((TX, 0, 0.08)), Vector((2.6, 0.32, 0.16)))
    H.box(bm, Vector((TX, 0, 0.08)), Vector((0.32, 2.6, 0.16)))
    H.box(bm, Vector((TX, 0, 2.6)), Vector((0.3, 0.3, 4.9)))
    for z, _ in PEGS:
        H.cylinder(bm, Vector((TX, 0, z)), 0.09, 2.3, axis="Y", segments=10)


B.piece("PlateTree_Frame", BLACK, tree_frame)


def tree_plates(z, r):
    def build(bm):
        for side in (-1, 1):
            for k in range(2):
                H.cylinder(bm, Vector((TX, side * (0.36 + 0.1 + k * 0.2), z)), r, 0.17, axis="Y", segments=24)
    return build


# One piece per peg height, so the plates take competition colours by size (red, blue, yellow by default).
for (z, r), name, colour in zip(PEGS, ("PlatesLarge", "PlatesMid", "PlatesSmall"), (RED, NAVY, YELLOW)):
    B.piece("PlateTree_" + name, colour, tree_plates(z, r))


def tree_hubs(bm):
    for z, _ in PEGS:
        for side in (-1, 1):
            H.cylinder(bm, Vector((TX, side * 0.6, z)), 0.17, 0.44, axis="Y", segments=12)


B.piece("PlateTree_Hubs", STEEL, tree_hubs)

# ------------------------------------------------------------------ MeetHall (x = 110)
# The entrance building outside the gym (user 2026-10-29: "I dont want any places to just have a square shape, and
# flat roof"): a 40 x 30 hall under a PITCHED gable roof (ridge front to back, CENTRAL in the front gable), and an
# entrance porch sticking out of the front with its own small gable roof. The sign sits on the hall's front above
# the porch.
HX = 110.0
HW, HD = 40.0, 30.0
EAVE, RIDGE = 16.0, 24.0
FRONT = -HD / 2
OVER_SIDE, OVER_END, ROOF_T = 1.2, 1.0, 0.6
# The porch: 18 wide, 5 deep, walls 9 high, its own gable up to 11.
PW, PD, PH, P_RIDGE = 18.0, 5.0, 9.0, 11.0
P_FRONT = FRONT - PD
DOOR_W, DOOR_H = 8.4, 7.6


def prism_y(bm, outline, y0, y1, x0=0.0):
    """A closed solid: the (x, z) polygon `outline` (convex, any winding) from y = y0 to y = y1, faces outward."""
    tmp = bmesh.new()
    a = [tmp.verts.new((x0 + x, y0, z)) for x, z in outline]
    b = [tmp.verts.new((x0 + x, y1, z)) for x, z in outline]
    tmp.faces.new(a)
    tmp.faces.new(list(reversed(b)))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        tmp.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)


def gable_slabs(bm, half_w, eave, ridge, over, t, y0, y1, x0):
    """Two roof slabs (vertical thickness t) from the ridge down past both eaves by `over`."""
    slope = (ridge - eave) / half_w
    for side in (-1, 1):
        xo = side * (half_w + over)
        zo = ridge - (half_w + over) * slope
        prism_y(bm, [(0.0, ridge), (xo, zo), (xo, zo + t), (0.0, ridge + t)], y0, y1, x0)


def walls(bm):
    H.box(bm, Vector((HX, 0, EAVE / 2)), Vector((HW, HD, EAVE)))
    # The gable: the triangle between the eaves and the ridge, front to back.
    prism_y(bm, [(-HW / 2, EAVE), (HW / 2, EAVE), (0.0, RIDGE)], -HD / 2, HD / 2, HX)
    # The porch and its little gable.
    H.span(bm, Vector((HX - PW / 2, P_FRONT, 0)), Vector((HX + PW / 2, FRONT + 0.2, PH)))
    prism_y(bm, [(-PW / 2, PH), (PW / 2, PH), (0.0, P_RIDGE)], P_FRONT, FRONT + 0.2, HX)


B.piece("MeetHall_Walls", CHARCOAL, walls, smooth=False)


def roofs(bm):
    gable_slabs(bm, HW / 2, EAVE, RIDGE, OVER_SIDE, ROOF_T, -HD / 2 - OVER_END, HD / 2 + OVER_END, HX)
    gable_slabs(bm, PW / 2, PH, P_RIDGE, 0.8, 0.4, P_FRONT - 0.8, FRONT, HX)


B.piece("MeetHall_Roof", BLACK, roofs, smooth=False)


def roof_trim(bm):
    # Yellow edges along the two front gables' slopes, just in front of the roof slabs.
    for half_w, eave, ridge, over, t, y in ((HW / 2, EAVE, RIDGE, OVER_SIDE, ROOF_T, -HD / 2 - OVER_END),
                                            (PW / 2, PH, P_RIDGE, 0.8, 0.4, P_FRONT - 0.8)):
        slope = (ridge - eave) / half_w
        for side in (-1, 1):
            xo = side * (half_w + over)
            zo = ridge - (half_w + over) * slope
            prism_y(bm, [(0.0, ridge - 0.05), (xo, zo - 0.05), (xo, zo + t + 0.05), (0.0, ridge + t + 0.05)],
                    y - 0.08, y, HX)


B.piece("MeetHall_RoofTrim", YELLOW, roof_trim, smooth=False)
B.piece("MeetHall_GableLogo", WHITE, lambda bm: B.add_text(
    bm, "CENTRAL", 2.2, 0.03, italic_front(HX, FRONT - 0.02, EAVE + 2.6)), smooth=False)


def stripes(bm, z, height, inset):
    # Round the whole hall, and round the porch's front and sides.
    H.box(bm, Vector((HX, FRONT - inset, z)), Vector((HW + 2 * inset, 2 * inset, height)))
    H.box(bm, Vector((HX, -FRONT + inset, z)), Vector((HW + 2 * inset, 2 * inset, height)))
    for side in (-1, 1):
        H.box(bm, Vector((HX + side * (HW / 2 + inset / 2), 0, z)), Vector((inset, HD, height)))
    H.box(bm, Vector((HX, P_FRONT - inset, z)), Vector((PW + 2 * inset, 2 * inset, height)))
    for side in (-1, 1):
        H.box(bm, Vector((HX + side * (PW / 2 + inset / 2), (P_FRONT + FRONT) / 2, z)), Vector((inset, PD, height)))


B.piece("MeetHall_Stripe", RED, lambda bm: stripes(bm, 3.2, 0.8, 0.05), smooth=False)
B.piece("MeetHall_Pinstripe", WHITE, lambda bm: stripes(bm, 3.75, 0.12, 0.05), smooth=False)

# The navy front panels: on the hall's front round the sign, and on the porch round the doors.
B.piece("MeetHall_Facade", NAVY, lambda bm: (
    H.box(bm, Vector((HX, FRONT - 0.05, (4.1 + EAVE) / 2)), Vector((32.0, 0.1, EAVE - 4.1))),
    H.box(bm, Vector((HX, P_FRONT - 0.05, (4.1 + PH) / 2)), Vector((PW - 1.0, 0.1, PH - 4.1)))), smooth=False)


def door_frame(bm):
    y = P_FRONT - 0.2
    H.box(bm, Vector((HX, y, DOOR_H + 0.2)), Vector((DOOR_W + 0.8, 0.4, 0.4)))
    for side in (-1, 1):
        H.box(bm, Vector((HX + side * (DOOR_W / 2 + 0.2), y, (DOOR_H + 0.4) / 2)), Vector((0.4, 0.4, DOOR_H + 0.4)))
    H.box(bm, Vector((HX, y, DOOR_H / 2)), Vector((0.16, 0.3, DOOR_H)))


B.piece("MeetHall_DoorFrame", BLACK, door_frame, smooth=False)
# Dark inside the doors, in front of the stripes, so the glass shows a dark hall rather than the wall.
B.piece("MeetHall_Inside", BLACK, lambda bm: H.box(
    bm, Vector((HX, P_FRONT - 0.14, DOOR_H / 2)), Vector((DOOR_W, 0.04, DOOR_H))), smooth=False)


def doors(bm):
    for side in (-1, 1):
        H.box(bm, Vector((HX + side * DOOR_W / 4, P_FRONT - 0.25, DOOR_H / 2)), Vector((DOOR_W / 2 - 0.2, 0.1, DOOR_H)))


B.piece("MeetHall_Doors", GLASS, doors, smooth=False)


def handles(bm):
    for side in (-1, 1):
        H.cylinder(bm, Vector((HX + side * 0.5, P_FRONT - 0.42, 3.6)), 0.06, 2.2, segments=8)


B.piece("MeetHall_Handles", STEEL, handles)
# A glowing strip under the porch roof's front edge, over the doors.
B.piece("MeetHall_DoorLight", GLOW, lambda bm: H.box(
    bm, Vector((HX, P_FRONT - 0.12, PH - 0.35)), Vector((PW - 2.0, 0.12, 0.2))), smooth=False)
B.piece("MeetHall_Landing", GREY, lambda bm: H.box(
    bm, Vector((HX, P_FRONT - 2.6, 0.15)), Vector((PW + 2.0, 5.2, 0.3))), smooth=False)


def wall_lamps(bm):
    for side in (-1, 1):
        H.rounded_box(bm, Vector((HX + side * 6.6, P_FRONT - 0.2, 6.2)), Vector((0.6, 0.4, 1.4)), 0.08, 2)


B.piece("MeetHall_Lamps", WARM, wall_lamps)


def windows(bm):
    for side in (-1, 1):
        H.box(bm, Vector((HX + side * (HW / 2 + 0.05), 0, 11.5)), Vector((0.1, HD - 8.0, 2.4)))


B.piece("MeetHall_Windows", GLASS, windows, smooth=False)

SIGN_Z = 13.9
SIGN_W, SIGN_H = 24.0, 4.2
B.piece("MeetHall_SignFrame", BLACK, lambda bm: H.rounded_box(
    bm, Vector((HX, FRONT - 0.2, SIGN_Z)), Vector((SIGN_W + 1.0, 0.4, SIGN_H + 1.0)), 0.1, 2))
B.piece("MeetHall_SignScreen", SCREEN, lambda bm: H.box(
    bm, Vector((HX, FRONT - 0.415, SIGN_Z)), Vector((SIGN_W, 0.03, SIGN_H))), smooth=False)
B.piece("MeetHall_SignTrim", YELLOW, lambda bm: H.box(
    bm, Vector((HX, FRONT - 0.43, SIGN_Z - SIGN_H / 2 - 0.25)), Vector((SIGN_W - 2.0, 0.04, 0.16))), smooth=False)


def slashes(bm):
    for x in (SIGN_W / 2 + 1.4, SIGN_W / 2 + 2.4):
        for side in (-1, 1):
            H.box(bm, Vector((HX + side * x, FRONT - 0.15, SIGN_Z)), Vector((0.5, 0.1, SIGN_H)), slanted(0.35))


B.piece("MeetHall_Slashes", YELLOW, slashes, smooth=False)


def corner_lights(bm):
    for side in (-1, 1):
        H.box(bm, Vector((HX + side * (HW / 2 - 0.3), FRONT - 0.06, (4.1 + EAVE - 0.4) / 2)),
              Vector((0.3, 0.12, EAVE - 0.4 - 4.1)))


B.piece("MeetHall_CornerLights", GLOW, corner_lights, smooth=False)

print("LocalMeet_01 built:", sorted(o.name for o in B.coll.objects))
