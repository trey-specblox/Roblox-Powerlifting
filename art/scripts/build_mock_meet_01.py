# Builds MockMeet_01 in the live Blender scene: the Mock Meet's furniture as real models instead of stacked
# Roblox blocks (user 2026-10-28: "I want every model to be made in blender"). Five items, side by side:
#
#   MeetDesk      the Mock Meet Room's check-in desk: navy body, oak top, a slanted black CHECK-IN tag with
#                 yellow // slashes and CENTRAL, a monitor facing the clerk (the game draws on its screen), a
#                 service bell and a clipboard.
#   MeetPlatform  the private room's competition platform: oak planks down the middle where the lifter stands,
#                 rubber mats on the sides where the plates land, a navy base with a yellow edge, CENTRAL on
#                 the wood in front of the rack.
#   MeetBench     the private room's wait bench: oak slats on a yellow steel frame, CENTRAL badge.
#   MeetBoard     the attempt board's frame: a black bezel round the screen (the game draws the board on it),
#                 a yellow CENTRAL header tag and a red trim.
#   MeetBanner    a side-wall banner: the cloth (the game draws the banner on it) between two steel rails with
#                 yellow end caps, on two wall brackets. One mesh for both banners.
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, items stand on z = 0 with their front toward
# -Y; wall items have their back on the wall plane y = 0. Objects are "<Item>_<Piece>" with ONE material each.
# The screens keep the old blocks' sizes so the game's screens fit as before: board 28 x 12, banner 20 x 6.
#
# Run in an otherwise empty file (art/blender/MockMeet_01.blend):
#   exec(compile(open(path).read(), path, "exec"), {"__file__": path, "__name__": "__main__"})
# Objects are replaced by name on every run.

import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

B = H.Builder("MockMeet_01")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.5, emission=None):
    lin = tuple(linear(c) for c in rgb)
    return H.material("MM_" + name, lin, metallic, roughness, 1.0, emission)


# Preview colours (Roblox colours each piece from StarterGymConfig.PropColourways).
NAVY = mat("Navy", (30, 48, 98), 0.0, 0.5)
BLACK = mat("Black", (22, 22, 24), 0.0, 0.5)
OAK = mat("Oak", (198, 152, 102), 0.0, 0.6)
YELLOW = mat("Yellow", (242, 190, 30), 0.0, 0.4)
WHITE = mat("White", (236, 236, 232), 0.0, 0.4)
RED = mat("Red", (200, 30, 38), 0.0, 0.45)
STEEL = mat("Steel", (190, 192, 198), 1.0, 0.3)
BRASS = mat("Brass", (200, 160, 82), 1.0, 0.3)
KRAFT = mat("Kraft", (184, 142, 98), 0.0, 0.7)
RUBBER = mat("Rubber", (46, 48, 54), 0.0, 0.9)
SCREEN = mat("Screen", (8, 10, 18), 0.0, 0.08)


def slanted(k):
    """A shear that leans a box's vertical sides to the right by k per unit of height (the UI's slanted tags)."""
    return Matrix(((1, 0, k, 0), (0, 1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)))


def italic_front(x0, y_front, z_mid, k=0.18):
    """place() for text on a front face (toward -Y), leaned like the UI's heavy italic headings."""
    def place(x, up, depth):
        return Vector((x0 + x + k * up, y_front - depth, z_mid + up))
    return place


# ------------------------------------------------------------------ MeetDesk (x = 0)
# Old block desk: body 10 x 1.8 x 3.1, top 10.4 x 2.2 at 3.1-3.3. Front (-Y) faces the door.
DX = 0.0
DESK_FRONT = -0.9

B.piece("MeetDesk_Body", NAVY, lambda bm: H.rounded_box(
    bm, Vector((DX, 0, 1.7)), Vector((10.0, 1.8, 2.8)), 0.08, 3))
B.piece("MeetDesk_Kick", BLACK, lambda bm: H.rounded_box(
    bm, Vector((DX, 0.1, 0.15)), Vector((9.7, 1.6, 0.3)), 0.03, 2))
B.piece("MeetDesk_Top", OAK, lambda bm: H.rounded_box(
    bm, Vector((DX, 0, 3.2)), Vector((10.5, 2.3, 0.2)), 0.06, 3))

TAG_Z = 2.05
B.piece("MeetDesk_Tag", BLACK, lambda bm: H.box(
    bm, Vector((DX - 0.4, DESK_FRONT - 0.03, TAG_Z)), Vector((5.2, 0.06, 1.3)), slanted(0.25)), smooth=False)
B.piece("MeetDesk_Lettering", WHITE, lambda bm: B.add_text(
    bm, "CHECK-IN", 0.72, 0.012, italic_front(DX - 0.4, DESK_FRONT - 0.06, TAG_Z + 0.16)))


def desk_accent(bm):
    # The low yellow band, the // slashes beside the tag, and CENTRAL under CHECK-IN.
    H.box(bm, Vector((DX, DESK_FRONT - 0.02, 0.85)), Vector((9.8, 0.04, 0.22)))
    for x in (2.75, 3.15):
        H.box(bm, Vector((DX + x, DESK_FRONT - 0.03, TAG_Z)), Vector((0.16, 0.06, 1.1)), slanted(0.45))
    B.add_text(bm, "CENTRAL", 0.26, 0.01, italic_front(DX - 0.4, DESK_FRONT - 0.06, TAG_Z - 0.36))


B.piece("MeetDesk_Accent", YELLOW, desk_accent, smooth=False)

# The monitor at the back, facing the clerk (+Y); the game draws on its screen.
MON_X, MON_Y, MON_Z = DX - 2.6, 0.35, 3.3 + 0.35 + 0.75


def monitor(bm):
    H.rounded_box(bm, Vector((MON_X, MON_Y, MON_Z)), Vector((2.5, 0.12, 1.5)), 0.04, 2)
    H.box(bm, Vector((MON_X, MON_Y - 0.12, 3.3 + 0.3)), Vector((0.2, 0.1, 0.6)))
    H.rounded_box(bm, Vector((MON_X, MON_Y - 0.12, 3.33)), Vector((0.9, 0.6, 0.06)), 0.02, 2)


B.piece("MeetDesk_Monitor", BLACK, monitor)
B.piece("MeetDesk_MonitorScreen", SCREEN, lambda bm: H.box(
    bm, Vector((MON_X, MON_Y + 0.07, MON_Z + 0.05)), Vector((2.3, 0.02, 1.3))), smooth=False)


def bell(bm):
    # A service bell: a flat base, a dome and a little knob.
    H.lathe_z(bm, [(0.0, 0.0), (0.24, 0.0), (0.24, 0.04), (0.2, 0.05), (0.2, 0.08), (0.17, 0.16), (0.1, 0.22),
                   (0.03, 0.24), (0.03, 0.3), (0.05, 0.31), (0.05, 0.34), (0.0, 0.35)], 16,
              Vector((DX + 3.1, -0.45, 3.3)))


B.piece("MeetDesk_Bell", BRASS, bell)

CLIP_ROT = Matrix.Rotation(0.18, 4, "Z")
B.piece("MeetDesk_Clipboard", KRAFT, lambda bm: H.rounded_box(
    bm, Vector((DX + 1.3, -0.3, 3.32)), Vector((0.9, 1.25, 0.04)), 0.03, 2, CLIP_ROT))


B.piece("MeetDesk_Paper", WHITE, lambda bm: H.box(
    bm, Vector((DX + 1.3, -0.26, 3.345)), Vector((0.76, 1.0, 0.012)), CLIP_ROT), smooth=False)

# ------------------------------------------------------------------ MeetPlatform (x = 20)
# Old blocks: base 16.6 x 16.6 to 0.5, top 16 x 16 at 0.5-0.6. The rack stands in the middle; the lifter
# stands 4 studs in front of it (MockMeetArena LIFT_SPOT_IN_FRONT).
PX = 20.0
B.piece("MeetPlatform_Base", NAVY, lambda bm: H.rounded_box(
    bm, Vector((PX, 0, 0.25)), Vector((16.6, 16.6, 0.5)), 0.04, 2))


def planks(bm):
    for k in range(8):
        H.box(bm, Vector((PX - 3.5 + k, 0, 0.55)), Vector((0.97, 16.0, 0.1)))


B.piece("MeetPlatform_Wood", OAK, planks, smooth=False)


def mats(bm):
    for x in (-6.0, 6.0):
        H.rounded_box(bm, Vector((PX + x, 0, 0.55)), Vector((3.96, 16.0, 0.1)), 0.03, 2)


B.piece("MeetPlatform_Rubber", RUBBER, mats)


def edge(bm):
    # A yellow line round the base's sides, under the top.
    h, t, z = 16.64, 0.04, 0.36
    for y in (-h / 2 + t / 2, h / 2 - t / 2):
        H.box(bm, Vector((PX, y, z)), Vector((h, t, 0.1)))
    for x in (-h / 2 + t / 2, h / 2 - t / 2):
        H.box(bm, Vector((PX + x, 0, z)), Vector((t, h - 2 * t, 0.1)))


B.piece("MeetPlatform_Edge", YELLOW, edge, smooth=False)


def platform_logo(bm):
    # CENTRAL lying on the wood in front of the lifter's spot, reading from the front.
    B.add_text(bm, "CENTRAL", 1.0, 0.004, lambda x, up, depth: Vector((PX + x + 0.18 * up, -6.4 + up, 0.6 + depth)))


B.piece("MeetPlatform_Logo", WHITE, platform_logo, smooth=False)

# ------------------------------------------------------------------ MeetBench (x = 40)
# Old blocks: seat 2 deep x 10 long at 1.5-1.8, legs under it. Length along X, front toward -Y.
BX = 40.0


def slats(bm):
    for k in range(4):
        H.rounded_box(bm, Vector((BX, -0.78 + k * 0.52, 1.71)), Vector((10.0, 0.44, 0.18)), 0.04, 2)


B.piece("MeetBench_Slats", OAK, slats)


def bench_frame(bm):
    for x in (-4.3, 0.0, 4.3):
        for y in (-0.72, 0.72):
            H.box(bm, Vector((BX + x, y, 0.81)), Vector((0.16, 0.16, 1.5)))
        H.box(bm, Vector((BX + x, 0, 1.54)), Vector((0.16, 1.6, 0.16)))
        H.box(bm, Vector((BX + x, 0, 0.32)), Vector((0.12, 1.44, 0.12)))
    H.box(bm, Vector((BX, 0, 1.4)), Vector((8.76, 0.14, 0.14)))


B.piece("MeetBench_Frame", YELLOW, bench_frame, smooth=False)


def feet(bm):
    for x in (-4.3, 0.0, 4.3):
        for y in (-0.72, 0.72):
            H.rounded_box(bm, Vector((BX + x, y, 0.03)), Vector((0.24, 0.24, 0.06)), 0.02, 1)


B.piece("MeetBench_Feet", BLACK, feet)
B.piece("MeetBench_Badge", NAVY, lambda bm: H.rounded_box(
    bm, Vector((BX, -0.86, 1.4)), Vector((1.7, 0.04, 0.3)), 0.015, 2))
B.piece("MeetBench_Logo", WHITE, lambda bm: B.add_text(
    bm, "CENTRAL", 0.2, 0.006, italic_front(BX, -0.88, 1.4)))

# ------------------------------------------------------------------ MeetBoard (x = 60)
# Old block: 28 x 12, 0.34 deep, 0.06 off the wall. The screen keeps that size.
WX = 60.0
SCR_W, SCR_H = 28.0, 12.0
FRAME_BACK, FRAME_FRONT = -0.06, -0.46
FRAME_Y = (FRAME_BACK + FRAME_FRONT) / 2
B.piece("MeetBoard_Frame", BLACK, lambda bm: H.rounded_box(
    bm, Vector((WX, FRAME_Y, SCR_H / 2 + 0.4)), Vector((SCR_W + 0.8, FRAME_BACK - FRAME_FRONT, SCR_H + 0.8)), 0.12, 3))
B.piece("MeetBoard_Screen", SCREEN, lambda bm: H.box(
    bm, Vector((WX, FRAME_FRONT - 0.015, SCR_H / 2 + 0.4)), Vector((SCR_W, 0.03, SCR_H))), smooth=False)
HEAD_Z = SCR_H + 0.8 + 0.55
B.piece("MeetBoard_Header", YELLOW, lambda bm: H.box(
    bm, Vector((WX, FRAME_Y - 0.06, HEAD_Z)), Vector((11.0, 0.3, 2.0)), slanted(0.3)), smooth=False)
B.piece("MeetBoard_HeaderText", BLACK, lambda bm: B.add_text(
    bm, "CENTRAL", 1.3, 0.015, italic_front(WX, FRAME_Y - 0.21, HEAD_Z)))
B.piece("MeetBoard_Trim", RED, lambda bm: H.box(
    bm, Vector((WX, FRAME_FRONT - 0.02, 0.2)), Vector((SCR_W - 2.0, 0.04, 0.12))), smooth=False)

# ------------------------------------------------------------------ MeetBanner (x = 95)
# Old block: 20 x 6 on the side walls. The cloth keeps that size.
NX = 95.0
CLOTH_W, CLOTH_H = 20.0, 6.0
CLOTH_Y = -0.32
RAIL_R = 0.12
BAN_Z = CLOTH_H / 2 + RAIL_R + 0.1  # the cloth's middle, so the bottom rail sits on z = 0
B.piece("MeetBanner_Cloth", NAVY, lambda bm: H.box(
    bm, Vector((NX, CLOTH_Y, BAN_Z)), Vector((CLOTH_W, 0.04, CLOTH_H))), smooth=False)
RAIL_ZS = (BAN_Z + CLOTH_H / 2 + RAIL_R - 0.02, BAN_Z - CLOTH_H / 2 - RAIL_R + 0.02)


def rails(bm):
    for z in RAIL_ZS:
        H.cylinder(bm, Vector((NX, CLOTH_Y, z)), RAIL_R, CLOTH_W + 0.8, axis="X", segments=12)


B.piece("MeetBanner_Rails", STEEL, rails)


def caps(bm):
    for z in RAIL_ZS:
        for x in (-(CLOTH_W / 2 + 0.4), CLOTH_W / 2 + 0.4):
            H.sphere(bm, Vector((NX + x, CLOTH_Y, z)), 0.2, segments=12, rings=6)


B.piece("MeetBanner_Caps", YELLOW, caps)


def brackets(bm):
    z = RAIL_ZS[0]
    for x in (-6.5, 6.5):
        H.box(bm, Vector((NX + x, -0.02, z)), Vector((0.5, 0.04, 0.8)))
        H.box(bm, Vector((NX + x, CLOTH_Y / 2 - 0.02, z)), Vector((0.18, abs(CLOTH_Y) - 0.04, 0.18)))


B.piece("MeetBanner_Brackets", BLACK, brackets, smooth=False)

print("MockMeet_01 built:", sorted(o.name for o in B.coll.objects))
