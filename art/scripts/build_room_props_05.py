# Builds RoomProps_05 in the live Blender scene: the 3D props for the outdoor Strongman Yard
# (GAME_DESIGN §27 "Strongman becomes an outdoor yard", user-approved 2026-10-26): a tractor tyre, a
# strongman sandbag, a yoke and a farmer's walk handle. The yoke and handles are loaded in Roblox with
# the CompPlate competition plates of RoomProps_04. Variety in shapes and colours, not just red and
# black; every gear label says CENTRAL (user's rules).
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud (a 450 mm plate is 2.0 studs), each item
# stands on z = 0 with its front toward -Y, objects are "<Item>_<Piece>" with ONE material each. Roblox
# recolours every piece from StarterGymConfig.PropColourways (COLOURWAYS below is the list to copy
# there; the first colourway is also what this file shows). PAINT holds the same colours as
# StarterGymConfig.PropPaints (0-255).
#
# Run in an otherwise empty file (art/blender/RoomProps_05.blend):
#   exec(compile(open(path).read(), path, "exec"), {"__file__": path, "__name__": "__main__"})
# Objects are replaced by name on every run.

import math
import os
import sys

import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

B = H.Builder("RoomProps_05")
BRAND = H.BRAND

# StarterGymConfig.PropPaints (sRGB 0-255).
PAINT = {
    "Black": (22, 22, 24), "Charcoal": (46, 48, 54), "Red": (200, 30, 38), "White": (236, 236, 232),
    "Navy": (30, 48, 98), "Yellow": (242, 190, 30), "Forest": (34, 98, 62), "Teal": (0, 138, 140),
    "Orange": (245, 130, 30), "Kraft": (184, 142, 98), "Terracotta": (196, 98, 62), "Silver": (190, 192, 198),
    "Sage": (140, 164, 134), "Mustard": (214, 160, 38),
}
METAL = {"Silver"}


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


MAT = {}
for colour, rgb in PAINT.items():
    lin = tuple(linear(c) for c in rgb)
    MAT[colour] = H.material("RP5_" + colour, lin, 1.0 if colour in METAL else 0.0, 0.55)

# Per item: a list of colourways, each piece -> colour name. Pieces not named keep the file's look.
COLOURWAYS = {
    "Tyre": [{"Rubber": "Black", "Text": t} for t in ("Yellow", "White")],
    "Sandbag": [{"Body": b, "Strap": "Black", "Text": t}
                for b, t in (("Forest", "White"), ("Kraft", "Black"), ("Navy", "White"), ("Terracotta", "White"),
                             ("Black", "Yellow"))],
    "Yoke": [{"Frame": f, "Horn": "Silver", "Pad": "Black", "Text": t}
             for f, t in (("Black", "White"), ("Red", "White"), ("Navy", "White"))],
    "FarmerHandle": [{"Frame": f, "Grip": "Silver", "Text": t}
                     for f, t in (("Black", "White"), ("Orange", "Black"), ("Teal", "White"))],
}


def mat_of(item, piece):
    return MAT[COLOURWAYS[item][0].get(piece, "White")]


def part(item, piece, build, smooth=True):
    return B.piece(f"{item}_{piece}", mat_of(item, piece), build, smooth)


def text_piece(item, lines, smooth=False):
    """<Item>_Text: lines = [(text, size, place)]."""
    def build(bm):
        for words, size, place in lines:
            B.add_text(bm, words, size, 0.004, place)
    return part(item, "Text", build, smooth)


def turned(bm, build, matrix):
    """Runs build(tmp) and merges it into bm, transformed by `matrix`."""
    tmp = bmesh.new()
    build(tmp)
    bmesh.ops.transform(tmp, matrix=matrix, verts=tmp.verts[:])
    H._merge(bm, tmp)


X = [0.0]


def slot(width):
    base = Vector((X[0] + width / 2, 0, 0))
    X[0] += width + 1.5
    return base


# ================================================================ TYRE
# Tyre: a big tractor tyre lying flat (6.6 across, about 1.5 m; 2.6 tall): a rounded rubber section with
# chevron tread lugs round its outside and CENTRAL on its top sidewall.
o = slot(6.8)
TYRE_IN, TYRE_OUT, TYRE_H = 1.6, 3.25, 2.6


def tyre_rubber(bm):
    H.lathe_z(bm, [(TYRE_IN + 0.1, 0.2), (2.2, 0.0), (2.95, 0.05), (TYRE_OUT, 0.45), (TYRE_OUT + 0.04, TYRE_H / 2),
                   (TYRE_OUT, TYRE_H - 0.45), (2.95, TYRE_H - 0.05), (2.2, TYRE_H), (TYRE_IN + 0.1, TYRE_H - 0.2),
                   (TYRE_IN, TYRE_H / 2)], 64, o)
    lugs = 32
    for k in range(lugs):
        angle = 2 * math.pi * k / lugs
        for half, tilt in ((-1, 1), (1, -1)):
            z = TYRE_H / 2 + half * 0.55
            lean = math.radians(28) * tilt * (1 if k % 2 == 0 else -1)
            rot = Matrix.Rotation(angle, 4, "Z") @ Matrix.Rotation(lean, 4, "X")
            centre = o + Vector((math.cos(angle) * (TYRE_OUT + 0.1), math.sin(angle) * (TYRE_OUT + 0.1), z))
            H.box(bm, centre, (0.2, 0.5, 0.95), rot)


part("Tyre", "Rubber", tyre_rubber)


def on_ring(radius, z):
    def place(x, up, depth):
        angle = -math.pi / 2 + x / radius
        r = radius - up
        return o + Vector((r * math.cos(angle), r * math.sin(angle), z + depth))
    return place


text_piece("Tyre", [(BRAND, 0.42, on_ring(2.45, TYRE_H))])

# ================================================================ SANDBAG
# Sandbag: a strongman sandbag lying on its side (2.8 long, 1.6 across, a little squashed), two
# webbing straps round it and a carry handle over the top, CENTRAL on its front.
o = slot(2.8)
BAG_R, BAG_L = 0.8, 2.8
squash = Matrix.Diagonal((1, 1, 0.85, 1))
lie = Matrix.Translation(o + Vector((0, 0, BAG_R * 0.85))) @ squash @ Matrix.Rotation(math.pi / 2, 4, "Y")
part("Sandbag", "Body", lambda bm: turned(bm, lambda t: H.lathe_z(t, [(0, -BAG_L / 2), (0.6, -BAG_L / 2 + 0.02),
                                                                        (BAG_R, -BAG_L / 2 + 0.3), (BAG_R, BAG_L / 2 - 0.3),
                                                                        (0.6, BAG_L / 2 - 0.02), (0, BAG_L / 2)], 32),
                                          lie))


def bag_straps(bm):
    for x in (-0.65, 0.65):
        turned(bm, lambda t: H.torus(t, (0, 0, 0), BAG_R + 0.03, 0.06, "XY", 32, 6), lie @ Matrix.Translation((0, 0, x)))
    H.torus(bm, o + Vector((0, 0, BAG_R * 1.7 - 0.05)), 0.45, 0.07, "XZ", 20, 6, arc=math.pi)


part("Sandbag", "Strap", bag_straps)
text_piece("Sandbag", [(BRAND, 0.32, lambda x, up, d: o + Vector((x, -(BAG_R + d) * 0.98, BAG_R * 0.85 + up)))])

# ================================================================ YOKE
# Yoke: a strongman yoke (5.6 wide, 7.4 tall, about 1.7 m): two square uprights on feet, a round
# crossbar with a pad across the top, and a plate horn sticking out of each upright at the height
# that lets the plates (2.0 across) stand on the ground; CENTRAL plates on the uprights.
o = slot(8.0)
YOKE_X, YOKE_H, HORN_Z = 2.6, 7.4, 1.0


def yoke_frame(bm):
    for sx in (-1, 1):
        H.box(bm, o + Vector((sx * YOKE_X, 0, YOKE_H / 2)), (0.36, 0.36, YOKE_H))
        H.box(bm, o + Vector((sx * YOKE_X, 0, 0.12)), (0.4, 2.4, 0.24))
        for sy in (-1, 1):
            H.box(bm, o + Vector((sx * YOKE_X, sy * 0.55, 0.62)), (0.12, 0.9, 0.12),
                  Matrix.Rotation(sy * math.radians(-40), 4, "X"))
    turned(bm, lambda t: H.cylinder(t, (0, 0, 0), 0.17, 2 * YOKE_X + 0.5, "Z", 20),
           Matrix.Translation(o + Vector((0, 0, YOKE_H - 0.35))) @ Matrix.Rotation(math.pi / 2, 4, "Y"))


def yoke_horns(bm):
    for sx in (-1, 1):
        turned(bm, lambda t: H.cylinder(t, (0, 0, 0), 0.11, 1.9, "Z", 16),
               Matrix.Translation(o + Vector((sx * (YOKE_X + 0.18 + 0.95), 0, HORN_Z))) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
        turned(bm, lambda t: H.cylinder(t, (0, 0, 0), 0.18, 0.12, "Z", 16),
               Matrix.Translation(o + Vector((sx * (YOKE_X + 0.3), 0, HORN_Z))) @ Matrix.Rotation(math.pi / 2, 4, "Y"))


part("Yoke", "Frame", yoke_frame, smooth=False)
part("Yoke", "Horn", yoke_horns)
part("Yoke", "Pad", lambda bm: turned(bm, lambda t: H.cylinder(t, (0, 0, 0), 0.32, 2.2, "Z", 24),
                                      Matrix.Translation(o + Vector((0, 0, YOKE_H - 0.35))) @ Matrix.Rotation(math.pi / 2, 4, "Y")))
# The words run up the uprights (read with your head tilted left): along the text is up, the letters' up is -X.
text_piece("Yoke", [(BRAND, 0.17, lambda x, up, d, sx=sx: o + Vector((sx * YOKE_X - up, -(0.18 + d), 4.2 + x)))
                    for sx in (-1, 1)])

# ================================================================ FARMER'S HANDLE
# FarmerHandle: one farmer's walk handle (6 long): a main rail at plate-centre height (the plates at its
# ends hold it up), sleeves at both ends, and a raised grip in the middle on two short uprights.
o = slot(6.4)
RAIL_Z, RAIL_HALF = 1.0, 3.0


def farmer_frame(bm):
    turned(bm, lambda t: H.cylinder(t, (0, 0, 0), 0.14, 2 * (RAIL_HALF - 1.0), "Z", 16),
           Matrix.Translation(o + Vector((0, 0, RAIL_Z))) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
    for sx in (-0.65, 0.65):
        H.box(bm, o + Vector((sx, 0, RAIL_Z + 0.45)), (0.16, 0.16, 0.9))


def farmer_grip(bm):
    turned(bm, lambda t: H.cylinder(t, (0, 0, 0), 0.08, 1.46, "Z", 14),
           Matrix.Translation(o + Vector((0, 0, RAIL_Z + 0.86))) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
    for sx in (-1, 1):
        turned(bm, lambda t: H.cylinder(t, (0, 0, 0), 0.11, 1.0, "Z", 16),
               Matrix.Translation(o + Vector((sx * (RAIL_HALF - 0.5), 0, RAIL_Z))) @ Matrix.Rotation(math.pi / 2, 4, "Y"))


part("FarmerHandle", "Frame", farmer_frame, smooth=False)
part("FarmerHandle", "Grip", farmer_grip)
text_piece("FarmerHandle", [(BRAND, 0.13, lambda x, up, d: o + Vector((x - 1.4, -(0.14 + d), RAIL_Z + up)))])

print("RoomProps_05 built:", len(B.coll.objects), "objects:", sorted({ob.name.split("_")[0] for ob in B.coll.objects}))
