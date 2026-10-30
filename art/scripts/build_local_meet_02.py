# Builds LocalMeet_02 in the live Blender scene: the models the redesigned Local meet venue needs (GAME_DESIGN 29.10,
# "Venue redesign and awards ceremony", user 2026-10-29: barricades in front of the platforms, referees seated on
# chairs, a platform number sign on a post, and an awards stage with a LOCAL CENTRAL MEET backdrop). LocalMeet_01's
# models (light box, seating, podium, plate tree, entrance building) carry over. Four items, side by side:
#
#   Barricade       a metal crowd barrier on flat feet: steel posts, rails and infill bars, a navy banner on the
#                   front with CENTRAL and a yellow edge, black feet. One mesh reused along the whole row.
#   RefChair        a referee's chair: black frame, red seat and back cushions, CENTRAL on the back. Faces -Y.
#   PlatformSign    a sign on a post beside each platform: weighted black base, steel pole, navy board with a dark
#                   screen the game writes "PLATFORM 1" .. "PLATFORM 8" on, yellow trim, CENTRAL on the back.
#   AwardsBackdrop  the awards stage's backdrop: two steel truss towers and a top truss, a navy banner with a
#                   step-and-repeat of CENTRAL logos, a black-framed title screen the game writes LOCAL CENTRAL MEET
#                   on, yellow trims and // slashes, and stage lights hanging from the top truss.
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, items stand on z = 0 with their front toward -Y.
# Objects are "<Item>_<Piece>" with ONE material each.
#
# Run in an otherwise empty file (art/blender/LocalMeet_02.blend):
#   exec(compile(open(path).read(), path, "exec"), {"__file__": path, "__name__": "__main__"})
# Objects are replaced by name on every run.

import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

B = H.Builder("LocalMeet_02")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.5, emission=None, alpha=1.0):
    lin = tuple(linear(c) for c in rgb)
    return H.material("LM_" + name, lin, metallic, roughness, alpha, emission)


# Preview colours (Roblox colours each piece from StarterGymConfig.PropColourways).
NAVY = mat("Navy", (30, 48, 98))
BLUE = mat("Blue", (58, 92, 168))
BLACK = mat("Black", (22, 22, 24))
YELLOW = mat("Yellow", (242, 190, 30), 0.0, 0.4)
WHITE = mat("White", (236, 236, 232), 0.0, 0.4)
RED = mat("Red", (200, 30, 38), 0.0, 0.45)
STEEL = mat("Steel", (190, 192, 198), 1.0, 0.3)
GLOW = mat("Glow", (255, 250, 240), 0.0, 0.3, emission=(1.0, 0.98, 0.94))
SCREEN = mat("Screen", (8, 10, 18), 0.0, 0.08)


def slanted(k):
    """A shear that leans a box's vertical sides to the right by k per unit of height (the UI's slanted tags)."""
    return Matrix(((1, 0, k, 0), (0, 1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)))


def italic_front(x0, y_front, z_mid, k=0.18):
    """place() for text on a front face (toward -Y), leaned like the UI's heavy italic headings."""
    def place(x, up, depth):
        return Vector((x0 + x + k * up, y_front - depth, z_mid + up))
    return place


def italic_back(x0, y_back, z_mid, k=0.18):
    """place() for text on a back face (toward +Y), reading left to right for someone behind the item."""
    def place(x, up, depth):
        return Vector((x0 - x - k * up, y_back + depth, z_mid + up))
    return place


def bar(bm, a, b, thickness):
    """A square bar from point a to point b (a truss member). Cheaper than a cylinder."""
    a, b = Vector(a), Vector(b)
    d = b - a
    rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
    H.box(bm, (a + b) / 2, Vector((thickness, thickness, d.length)), rot)


# ------------------------------------------------------------------ Barricade (x = 0)
# 7 wide and 3.3 high (about a real 2.3 m x 1.1 m crowd barrier next to a Roblox character). Front (-Y) faces the
# spectators.
BX = 0.0
BAR_W, BAR_H = 7.0, 3.3
POST_X = BAR_W / 2 - 0.1
RAIL_LO = 0.45


def barricade_frame(bm):
    for side in (-1, 1):
        H.cylinder(bm, Vector((BX + side * POST_X, 0, (0.12 + BAR_H) / 2)), 0.09, BAR_H - 0.12, segments=8)
    H.cylinder(bm, Vector((BX, 0, BAR_H - 0.1)), 0.09, 2 * POST_X, axis="X", segments=8)
    H.cylinder(bm, Vector((BX, 0, RAIL_LO)), 0.07, 2 * POST_X, axis="X", segments=8)
    x = -POST_X + 0.4
    while x < POST_X - 0.2:
        H.cylinder(bm, Vector((BX + x, 0, (RAIL_LO + BAR_H - 0.1) / 2)), 0.04, BAR_H - 0.1 - RAIL_LO, segments=6)
        x += 0.4


B.piece("Barricade_Frame", STEEL, barricade_frame)
# Flat bridge feet, so the row of barriers stands on its own.
B.piece("Barricade_Feet", BLACK, lambda bm: [H.box(
    bm, Vector((BX + side * POST_X, 0, 0.06)), Vector((0.34, 2.4, 0.12))) for side in (-1, 1)], smooth=False)
BANNER_Y = -0.15
BANNER_Z, BANNER_H = 2.2, 1.5
B.piece("Barricade_Banner", NAVY, lambda bm: H.box(
    bm, Vector((BX, BANNER_Y, BANNER_Z)), Vector((BAR_W - 0.6, 0.04, BANNER_H))), smooth=False)
B.piece("Barricade_Stripe", YELLOW, lambda bm: H.box(
    bm, Vector((BX, BANNER_Y - 0.03, BANNER_Z - BANNER_H / 2 + 0.1)), Vector((BAR_W - 0.6, 0.02, 0.12))),
    smooth=False)
B.piece("Barricade_Logo", WHITE, lambda bm: B.add_text(
    bm, "CENTRAL", 0.75, 0.01, italic_front(BX, BANNER_Y - 0.03, BANNER_Z + 0.08)), smooth=False)

# ------------------------------------------------------------------ RefChair (x = 10)
# Seat 1.6 high, 1.8 square; the referee faces -Y, so the back is at +Y.
CX = 10.0
SEAT_Z = 1.6
LEG = 0.75


def chair_frame(bm):
    for sx in (-1, 1):
        H.cylinder(bm, Vector((CX + sx * LEG, -LEG, SEAT_Z / 2)), 0.07, SEAT_Z, segments=8)
        # The back legs carry on up as the uprights of the backrest.
        H.cylinder(bm, Vector((CX + sx * LEG, LEG, 1.7)), 0.07, 3.4, segments=8)
        H.cylinder(bm, Vector((CX + sx * LEG, 0, 0.55)), 0.05, 2 * LEG, axis="Y", segments=6)
    H.cylinder(bm, Vector((CX, -LEG, 0.55)), 0.05, 2 * LEG, axis="X", segments=6)
    H.box(bm, Vector((CX, 0, SEAT_Z - 0.05)), Vector((2 * LEG + 0.14, 2 * LEG + 0.14, 0.1)))


B.piece("RefChair_Frame", BLACK, chair_frame)
B.piece("RefChair_Cushion", RED, lambda bm: (
    H.rounded_box(bm, Vector((CX, -0.02, SEAT_Z + 0.12)), Vector((1.8, 1.76, 0.24)), 0.08, 2),
    H.rounded_box(bm, Vector((CX, LEG - 0.1, 2.75)), Vector((1.8, 0.22, 1.1)), 0.08, 2)))
B.piece("RefChair_Logo", WHITE, lambda bm: B.add_text(
    bm, "CENTRAL", 0.3, 0.006, italic_back(CX, LEG + 0.01, 2.75)), smooth=False)

# ------------------------------------------------------------------ PlatformSign (x = 20)
# The board's middle is 9.4 up, so it reads over the barricades and the referees. Screen on the front (-Y).
PX = 20.0
BOARD_Z = 9.4
BOARD_W, BOARD_H = 6.0, 2.8
SCREEN_W, SCREEN_H = 5.4, 2.0

B.piece("PlatformSign_Base", BLACK, lambda bm: H.cylinder(
    bm, Vector((PX, 0, 0.1)), 1.0, 0.2, segments=20))
B.piece("PlatformSign_Pole", STEEL, lambda bm: H.cylinder(
    bm, Vector((PX, 0, (0.2 + BOARD_Z - BOARD_H / 2 + 0.1) / 2)), 0.12, BOARD_Z - BOARD_H / 2 - 0.1, segments=12))
B.piece("PlatformSign_Board", NAVY, lambda bm: H.rounded_box(
    bm, Vector((PX, 0, BOARD_Z)), Vector((BOARD_W, 0.36, BOARD_H)), 0.08, 2))
B.piece("PlatformSign_Screen", SCREEN, lambda bm: H.box(
    bm, Vector((PX, -0.195, BOARD_Z + 0.15)), Vector((SCREEN_W, 0.03, SCREEN_H))), smooth=False)
B.piece("PlatformSign_Trim", YELLOW, lambda bm: H.box(
    bm, Vector((PX, -0.2, BOARD_Z - BOARD_H / 2 + 0.2)), Vector((SCREEN_W, 0.04, 0.12))), smooth=False)
B.piece("PlatformSign_Logo", WHITE, lambda bm: B.add_text(
    bm, "CENTRAL", 0.9, 0.01, italic_back(PX, 0.19, BOARD_Z)), smooth=False)

# ------------------------------------------------------------------ AwardsBackdrop (x = 45)
# 32 wide and 18 high, behind the 15-wide podium. Two square truss towers (1 x 1) at the ends and a top truss
# across them; the banner hangs between the towers.
AX = 45.0
TOWER_X = 15.0
TRUSS = 1.0
TOP_Z = 16.6
PANEL_W = 2 * TOWER_X - TRUSS - 0.4
PANEL_LO, PANEL_HI = 1.4, 15.8
PANEL_FRONT = -0.12


def truss_tower(bm, x):
    h = TRUSS / 2
    corners = [(x - h, -h), (x + h, -h), (x + h, h), (x - h, h)]
    for cx, cy in corners:
        H.cylinder(bm, Vector((cx, cy, (0.2 + TOP_Z + TRUSS) / 2)), 0.08, TOP_Z + TRUSS - 0.2, segments=8)
    z = 0.2
    while z < TOP_Z - 0.1:
        for i in range(4):
            (ax, ay), (bx, by) = corners[i], corners[(i + 1) % 4]
            bar(bm, (ax, ay, z), (bx, by, z), 0.06)
            bar(bm, (ax, ay, z), (bx, by, z + 2.0), 0.05)
        z += 2.0


def truss_top(bm):
    h = TRUSS / 2
    x0, x1 = AX - TOWER_X + h, AX + TOWER_X - h
    for y in (-h, h):
        for z in (TOP_Z, TOP_Z + TRUSS):
            H.cylinder(bm, Vector(((x0 + x1) / 2, y, z)), 0.08, x1 - x0, axis="X", segments=8)
    x = x0
    step = (x1 - x0) / 14
    for k in range(14):
        for y in (-h, h):
            bar(bm, (x, y, TOP_Z), (x + step, y, TOP_Z + TRUSS), 0.05)
        bar(bm, (x, -h, TOP_Z), (x, h, TOP_Z), 0.05)
        bar(bm, (x, -h, TOP_Z + TRUSS), (x, h, TOP_Z + TRUSS), 0.05)
        x += step


def truss(bm):
    for side in (-1, 1):
        truss_tower(bm, AX + side * TOWER_X)
    truss_top(bm)


B.piece("AwardsBackdrop_Truss", STEEL, truss, smooth=False)
B.piece("AwardsBackdrop_Feet", BLACK, lambda bm: [H.box(
    bm, Vector((AX + side * TOWER_X, 0, 0.1)), Vector((2.4, 2.4, 0.2))) for side in (-1, 1)], smooth=False)
B.piece("AwardsBackdrop_Panel", NAVY, lambda bm: H.box(
    bm, Vector((AX, 0, (PANEL_LO + PANEL_HI) / 2)), Vector((PANEL_W, 0.24, PANEL_HI - PANEL_LO))), smooth=False)


def step_and_repeat(bm):
    # The press-wall pattern: two rows of CENTRAL logos, the upper row shifted half a step. Seven logos keep it
    # inside the 5,000-triangle budget (each word is about 600).
    for row, z in enumerate((5.0, 8.6)):
        xs = (-10.5, -3.5, 3.5, 10.5) if row == 0 else (-7.0, 0.0, 7.0)
        for x in xs:
            B.add_text(bm, "CENTRAL", 1.3, 0.01, italic_front(AX + x, PANEL_FRONT - 0.01, z))


B.piece("AwardsBackdrop_Pattern", BLUE, step_and_repeat, smooth=False)

TITLE_Z = 13.0
TITLE_W, TITLE_H = 22.0, 3.6
B.piece("AwardsBackdrop_TitleFrame", BLACK, lambda bm: H.rounded_box(
    bm, Vector((AX, PANEL_FRONT - 0.15, TITLE_Z)), Vector((TITLE_W + 0.8, 0.3, TITLE_H + 0.8)), 0.1, 2))
B.piece("AwardsBackdrop_Title", SCREEN, lambda bm: H.box(
    bm, Vector((AX, PANEL_FRONT - 0.315, TITLE_Z)), Vector((TITLE_W, 0.03, TITLE_H))), smooth=False)


def backdrop_trim(bm):
    for z in (PANEL_LO + 0.15, PANEL_HI - 0.15):
        H.box(bm, Vector((AX, PANEL_FRONT - 0.02, z)), Vector((PANEL_W, 0.04, 0.3)))
    for x in (TITLE_W / 2 + 1.2, TITLE_W / 2 + 2.1):
        for side in (-1, 1):
            H.box(bm, Vector((AX + side * x, PANEL_FRONT - 0.04, TITLE_Z)), Vector((0.45, 0.08, TITLE_H)),
                  slanted(0.35))


B.piece("AwardsBackdrop_Trim", YELLOW, backdrop_trim, smooth=False)

# Six stage cans hanging in front of the top truss, pointing down at the podium.
CAN_XS = (-12.5, -7.5, -2.5, 2.5, 7.5, 12.5)


def can_at(x):
    return Vector((AX + x, -TRUSS / 2 - 0.5, TOP_Z - 0.6))


def cans(bm):
    for x in CAN_XS:
        H.cylinder(bm, can_at(x), 0.4, 1.0, segments=12)
        H.box(bm, can_at(x) + Vector((0, 0.25, 0.55)), Vector((0.12, 0.6, 0.12)))


def can_lenses(bm):
    for x in CAN_XS:
        H.cylinder(bm, can_at(x) + Vector((0, 0, -0.52)), 0.32, 0.04, segments=12)


B.piece("AwardsBackdrop_Cans", BLACK, cans)
B.piece("AwardsBackdrop_Lenses", GLOW, can_lenses, smooth=False)

print("LocalMeet_02 built:", sorted(o.name for o in B.coll.objects))
