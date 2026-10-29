# Builds Furniture_01 in the live Blender scene: the shared furniture that RoomProps still built from blocks
# (user 2026-10-28: "everything still made with blocks change into models through blender ... If its a micro
# model/detail it does not have to be SUPER detailed because i want to make sure everything is optimized").
# Low detail on purpose: few pieces (one per colour), small triangle counts, one mesh reused for every copy.
#
#   OfficeChair  padded seat and back on a gas pole and a five-star base (chair() in RoomProps).
#   Desk         a wooden top on two steel side panels and a back rail (desk()); stretched to each desk's size.
#   Workstation  a monitor on a stand with a keyboard and mouse in front of it (monitor() and the Keyboard).
#   ShelfThree   a shelving frame with 3 boards and a top (shelving()); stretched to each shelf's size, coloured
#   ShelfFour    like the room's old shelf (one piece, so one MeshPart per shelf instead of 6-8 blocks).
#   StorageBox   a cardboard box with closed flaps (boxes()); stretched for the tall ones.
#   BookRow      four books of one colour, one leaning (books()); every shelf level gets its own colour.
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, items stand on z = 0 with their front toward
# -Y (a chair's and a desk's front is where the sitter looks; a shelf's front faces into the room, its back
# on the wall at +Y). Objects are "<Item>_<Piece>" with ONE material each.
#
# Run in an otherwise empty file (art/blender/Furniture_01.blend):
#   exec(compile(open(path).read(), path, "exec"), {"__file__": path, "__name__": "__main__"})
# Objects are replaced by name on every run.

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

B = H.Builder("Furniture_01")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.5):
    return H.material("FN_" + name, tuple(linear(c) for c in rgb), metallic, roughness)


# Preview colours (Roblox colours each piece from StarterGymConfig.PropColourways or the room's look).
CHARCOAL = mat("Charcoal", (46, 48, 54), 0.0, 0.8)
BLACK = mat("Black", (22, 22, 24), 0.0, 0.5)
STEEL = mat("Steel", (190, 192, 198), 1.0, 0.3)
OAK = mat("Oak", (198, 152, 102), 0.0, 0.6)
SCREEN = mat("Screen", (8, 10, 18), 0.0, 0.08)
KRAFT = mat("Kraft", (184, 142, 98), 0.0, 0.8)
RED = mat("Red", (200, 30, 38), 0.0, 0.6)
SHELF = mat("Shelf", (120, 96, 70), 0.0, 0.7)

# ------------------------------------------------------------------ OfficeChair (x = 0)
# Old blocks: seat 1.8 x 1.8 at 1.6-1.85, back 0.2 thick up to 4, pole and a 1.6 base.
CX = 0.0


def chair_padding(bm):
    H.rounded_box(bm, Vector((CX, -0.05, 1.725)), Vector((1.8, 1.7, 0.25)), 0.08, 2)
    H.rounded_box(bm, Vector((CX, 0.78, 3.0)), Vector((1.7, 0.22, 1.8)), 0.08, 2)


def chair_frame(bm):
    H.cylinder(bm, Vector((CX, 0, 0.85)), 0.11, 1.5, segments=10)
    H.cylinder(bm, Vector((CX, 0, 0.12)), 0.18, 0.12, segments=10)
    for k in range(5):
        turn = Matrix.Rotation(2 * math.pi * k / 5, 4, "Z")
        H.box(bm, Vector((CX, 0, 0.12)) + (turn @ Vector((0.4, 0, 0))), Vector((0.8, 0.14, 0.08)), turn)
        H.cylinder(bm, Vector((CX, 0, 0.05)) + (turn @ Vector((0.78, 0, 0))), 0.06, 0.1, segments=8)
    # The bar from under the seat up the back.
    H.box(bm, Vector((CX, 0.55, 1.55)), Vector((0.16, 1.1, 0.1)))
    H.box(bm, Vector((CX, 0.92, 2.0)), Vector((0.16, 0.1, 1.0)))


B.piece("OfficeChair_Seat", CHARCOAL, chair_padding)
B.piece("OfficeChair_Frame", BLACK, chair_frame)

# ------------------------------------------------------------------ Desk (x = 10)
# Reference size 10 wide, 2.5 deep, 3.0 tall (the Office desk); the game stretches it to every desk.
DKX = 10.0
B.piece("Desk_Top", OAK, lambda bm: H.rounded_box(bm, Vector((DKX, 0, 2.9)), Vector((10.0, 2.5, 0.2)), 0.05, 2))


def desk_frame(bm):
    for x in (-4.85, 4.85):
        H.box(bm, Vector((DKX + x, 0, 1.4)), Vector((0.2, 2.3, 2.8)))
    H.box(bm, Vector((DKX, 1.0, 2.45)), Vector((9.5, 0.08, 0.6)))


B.piece("Desk_Frame", STEEL, desk_frame, smooth=False)

# ------------------------------------------------------------------ Workstation (x = 20)
# Stands on a desk top (z = 0 here is the desk's top). The screen faces the sitter (-Y); the keyboard is 1.05
# in front of the monitor, the mouse to its right.
WX = 20.0


def workstation_body(bm):
    H.rounded_box(bm, Vector((WX, 0, 0.02)), Vector((1.0, 0.7, 0.04)), 0.02, 1)
    H.box(bm, Vector((WX, 0.05, 0.3)), Vector((0.2, 0.12, 0.52)))
    H.rounded_box(bm, Vector((WX, 0, 1.3)), Vector((2.8, 0.12, 1.6)), 0.03, 1)
    H.rounded_box(bm, Vector((WX, -1.05, 0.03)), Vector((2.0, 0.5, 0.06)), 0.02, 1)
    H.rounded_box(bm, Vector((WX + 1.4, -1.05, 0.04)), Vector((0.22, 0.34, 0.08)), 0.04, 2)


B.piece("Workstation_Body", BLACK, workstation_body)
B.piece("Workstation_Screen", SCREEN, lambda bm: H.box(
    bm, Vector((WX, -0.07, 1.33)), Vector((2.62, 0.02, 1.42))), smooth=False)
B.piece("Workstation_Keys", CHARCOAL, lambda bm: H.box(
    bm, Vector((WX, -1.05, 0.075)), Vector((1.84, 0.38, 0.03))), smooth=False)

# ------------------------------------------------------------------ ShelfThree / ShelfFour (x = 30, 40)
# Reference size 6 wide, 6 tall, 1.4 deep (back on the wall at +Y), like shelving() in RoomProps: a 0.1 back,
# two 0.15 ends, boards 0.15 thick at 0.15 + (level - 1) * height / levels, and a top board.
SW, SH, SD = 6.0, 6.0, 1.4


def shelf(levels, x0):
    def build(bm):
        back_y = SD / 2 - 0.05
        H.box(bm, Vector((x0, back_y, SH / 2)), Vector((SW, 0.1, SH)))
        for x in (-SW / 2 + 0.075, SW / 2 - 0.075):
            H.box(bm, Vector((x0 + x, -0.05, SH / 2)), Vector((0.15, SD - 0.1, SH)))
        zs = [0.15 + (level - 1) * SH / levels for level in range(1, levels + 1)] + [SH - 0.15]
        for z in zs:
            H.box(bm, Vector((x0, -0.05, z + 0.075)), Vector((SW - 0.3, SD - 0.1, 0.15)))
        # A kick plate under the lowest board.
        H.box(bm, Vector((x0, -SD / 2 + 0.1, 0.075)), Vector((SW - 0.3, 0.1, 0.15)))
    return build


B.piece("ShelfThree_Frame", SHELF, shelf(3, 30.0), smooth=False)
B.piece("ShelfFour_Frame", SHELF, shelf(4, 40.0), smooth=False)

# ------------------------------------------------------------------ StorageBox (x = 50)
# 1 wide, 1.2 deep, 1 tall (the game stretches it to 1.4 for the tall ones): a box with a seam where the
# top flaps meet.
BX = 50.0


def storage_box(bm):
    H.rounded_box(bm, Vector((BX, 0, 0.5)), Vector((1.0, 1.2, 0.98)), 0.025, 1)
    for x in (-0.255, 0.255):
        H.box(bm, Vector((BX + x, 0, 0.995)), Vector((0.48, 1.16, 0.03)))


B.piece("StorageBox_Body", KRAFT, storage_box)

# ------------------------------------------------------------------ BookRow (x = 60)
# Four books in one 1.0-wide slot, 1.2 to 1.55 tall like the old blocks; the last one leans on the third.
KX = 60.0


def book_row(bm):
    for k, tall in enumerate((1.2, 1.5, 1.3)):
        H.rounded_box(bm, Vector((KX - 0.375 + k * 0.25, 0, tall / 2)), Vector((0.21, 0.95, tall)), 0.02, 1)
    lean = Matrix.Rotation(math.radians(-14), 4, "Y")
    H.rounded_box(bm, Vector((KX + 0.43, 0, 0.64)), Vector((0.21, 0.95, 1.25)), 0.02, 1, lean)


B.piece("BookRow_Books", RED, book_row)

print("Furniture_01 built:", sorted(o.name for o in B.coll.objects))
