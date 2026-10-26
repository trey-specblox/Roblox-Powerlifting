# Builds RoomProps_06 in the live Blender scene: the 3D props for the themed room fronts, batch 2a
# (GAME_DESIGN §27 "Themed room fronts", user-approved 2026-10-26): Machines (a selectorised weight stack
# with its pin, cable and pulley), Office (a brass wall sconce), Storage (a wooden crate, a pallet and a
# bumper plate lying flat, for stacks of plates) and Index (a hanging medal on a ribbon).
# Variety in shapes and colours, not just red and black; every gear label says CENTRAL (user's rules).
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, each item stands on z = 0 with its front
# toward -Y (wall-mounted items have their back on y = 0), objects are "<Item>_<Piece>" with ONE material
# each. Roblox recolours every piece from StarterGymConfig.PropColourways (COLOURWAYS below is the list to
# copy there; the first colourway is also what this file shows). PAINT holds the same colours as
# StarterGymConfig.PropPaints (0-255).
#
# Run in an otherwise empty file (art/blender/RoomProps_06.blend):
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

B = H.Builder("RoomProps_06")
BRAND = H.BRAND

# StarterGymConfig.PropPaints (sRGB 0-255; the new one for this batch at the end).
PAINT = {
    "Black": (22, 22, 24), "Charcoal": (46, 48, 54), "Red": (200, 30, 38), "White": (236, 236, 232),
    "LightGrey": (176, 180, 186), "Blue": (30, 92, 205), "Navy": (30, 48, 98), "Yellow": (242, 190, 30),
    "Mustard": (214, 160, 38), "Green": (95, 222, 60), "Forest": (34, 98, 62), "Teal": (0, 138, 140),
    "Purple": (128, 52, 190), "Orange": (245, 130, 30), "Terracotta": (196, 98, 62), "Cream": (236, 224, 196),
    "Kraft": (184, 142, 98), "Oak": (198, 152, 102), "Coffee": (62, 34, 20), "Chocolate": (94, 52, 32),
    "Silver": (190, 192, 198), "Brass": (200, 160, 82), "WarmGlow": (255, 205, 150),
    # new in RoomProps_06
    "Bronze": (176, 110, 60),
}
METAL = {"Silver", "Brass", "Bronze"}


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


MAT = {}
for colour, rgb in PAINT.items():
    lin = tuple(linear(c) for c in rgb)
    MAT[colour] = H.material("RP6_" + colour, lin, 1.0 if colour in METAL else 0.0, 0.5, 1.0,
                             lin if colour == "WarmGlow" else None)

# Per item: a list of colourways, each piece -> colour name. Pieces not named keep the file's look.
COLOURWAYS = {
    # Machines
    "WeightStack": [{"Frame": f, "Rod": "Silver", "Plate": p, "Top": t, "Pin": pin, "Cable": "Black", "Pulley": "Silver",
                     "Text": "White", "Logo": logo}
                    for f, p, t, pin, logo in (("Black", "Black", "Red", "Yellow", "White"),
                                               ("LightGrey", "Charcoal", "Blue", "Red", "White"),
                                               ("White", "Black", "Yellow", "Red", "Black"),
                                               ("Navy", "Black", "Orange", "Yellow", "Black"))],
    # Office
    "WallSconce": [{"Mount": m, "Shade": s, "Light": "WarmGlow"}
                   for m, s in (("Brass", "Cream"), ("Black", "White"), ("Brass", "Forest"), ("Silver", "Navy"))],
    # Storage
    "WoodCrate": [{"Slats": s, "Frame": f, "Text": t}
                  for s, f, t in (("Oak", "Chocolate", "Black"), ("Kraft", "Coffee", "Black"), ("Forest", "Black", "White"),
                                  ("Navy", "Black", "White"), ("Mustard", "Black", "Black"))],
    "Pallet": [{"Boards": b, "Blocks": k} for b, k in (("Kraft", "Kraft"), ("Blue", "Blue"), ("Oak", "Chocolate"))],
    "BumperPlate": [{"Disc": d, "Hub": "Silver", "Text": t}
                    for d, t in (("Red", "White"), ("Blue", "White"), ("Yellow", "Black"), ("Green", "Black"),
                                 ("Black", "White"), ("LightGrey", "Black"))],
    # Index
    "Medal": [{"Disc": d, "Ribbon": r, "Text": t}
              for d, r, t in (("Brass", "Red", "Coffee"), ("Silver", "Blue", "Charcoal"), ("Bronze", "Forest", "Coffee"),
                              ("Brass", "Navy", "Coffee"), ("Silver", "Purple", "Charcoal"))],
}


def mat_of(item, piece):
    return MAT[COLOURWAYS[item][0][piece]]


def part(item, piece, build, smooth=True):
    return B.piece(f"{item}_{piece}", mat_of(item, piece), build, smooth)


def text_piece(item, lines, piece="Text", smooth=False):
    """<Item>_<piece>: lines = [(text, size, place)]."""
    def build(bm):
        for words, size, place in lines:
            B.add_text(bm, words, size, 0.004, place)
    return part(item, piece, build, smooth)


def turned(bm, build, matrix):
    """Runs build(tmp) and merges it into bm, transformed by `matrix`."""
    tmp = bmesh.new()
    build(tmp)
    bmesh.ops.transform(tmp, matrix=matrix, verts=tmp.verts[:])
    H._merge(bm, tmp)


X = [0.0]  # the next item's X position along the shelf of items


def slot(width):
    """The base point of the next item, `width` studs wide."""
    base = Vector((X[0] + width / 2, 0, 0))
    X[0] += width + 1.0
    return base


# ================================================================ MACHINES
# WeightStack: a cable machine's weight stack (3 wide, 1.7 deep, 8.6 tall), its back against the wall at
# y = 0: a base, two uprights and a top beam; two guide rods; 14 plates with their kg numbers; a top plate
# with CENTRAL; the selector pin in the sixth plate; the cable up to a pulley in the beam and back.
o = slot(3.0)
STACK_Y, PLATES, PLATE_H, PLATE_GAP = -0.85, 14, 0.24, 0.04
FRONT_Y = STACK_Y - 0.55  # the plates' front faces
TOP_Z = 0.45 + PLATES * (PLATE_H + PLATE_GAP)  # the top plate's bottom


def stack_frame(bm):
    H.box(bm, o + Vector((0, STACK_Y, 0.1)), (3.0, 1.7, 0.2))                 # base
    for sx in (-1, 1):
        H.box(bm, o + Vector((sx * 1.38, STACK_Y, 4.3)), (0.24, 0.24, 8.6))    # upright
        H.cylinder(bm, o + Vector((sx * 0.7, STACK_Y, 0.32)), 0.16, 0.25, "Z", 16)  # rubber bumper
        H.box(bm, o + Vector((sx * 0.13, -0.6, 7.98)), (0.04, 0.6, 0.65))      # pulley cheek
    H.box(bm, o + Vector((0, STACK_Y, 8.45)), (3.0, 0.4, 0.3))                # top beam
    H.box(bm, o + Vector((0, -0.6, 8.36)), (0.34, 0.6, 0.12))                 # pulley bracket
    H.box(bm, o + Vector((0, -0.12, 8.2)), (0.36, 0.24, 0.36))                # cable anchor on the wall


part("WeightStack", "Frame", stack_frame, smooth=False)
part("WeightStack", "Rod", lambda bm: [H.cylinder(bm, o + Vector((sx * 0.7, STACK_Y, 4.25)), 0.05, 7.9, "Z", 12)
                                       for sx in (-1, 1)])
part("WeightStack", "Plate", lambda bm: [H.rounded_box(bm, o + Vector((0, STACK_Y, 0.45 + k * (PLATE_H + PLATE_GAP) + PLATE_H / 2)),
                                                       (2.1, 1.1, PLATE_H), 0.03, 2) for k in range(PLATES)], smooth=False)
part("WeightStack", "Top", lambda bm: [H.rounded_box(bm, o + Vector((0, STACK_Y, TOP_Z + 0.18)), (2.1, 1.1, 0.36), 0.04, 2),
                                       H.cylinder(bm, o + Vector((0, STACK_Y, TOP_Z + 0.46)), 0.1, 0.2, "Z", 16)], smooth=False)
PIN_Z = 0.45 + 5 * (PLATE_H + PLATE_GAP) + PLATE_H / 2
part("WeightStack", "Pin", lambda bm: [H.cylinder(bm, o + Vector((0.35, FRONT_Y + 0.2, PIN_Z)), 0.05, 0.6, "Y", 12),
                                       H.cylinder(bm, o + Vector((0.35, FRONT_Y - 0.12, PIN_Z)), 0.13, 0.14, "Y", 20),
                                       H.sphere(bm, o + Vector((0.35, FRONT_Y - 0.22, PIN_Z)), 0.11, (1, 0.7, 1), 16, 8)])
CABLE_LOW, PULLEY_Z = TOP_Z + 0.56, 7.98
part("WeightStack", "Cable", lambda bm: [
    H.cylinder(bm, o + Vector((0, STACK_Y, (CABLE_LOW + PULLEY_Z) / 2)), 0.035, PULLEY_Z - CABLE_LOW, "Z", 8),
    H.cylinder(bm, o + Vector((0, -0.42, PULLEY_Z + 0.25)), 0.035, 0.36, "Y", 8)])
part("WeightStack", "Pulley", lambda bm: [H.cylinder(bm, o + Vector((0, -0.6, PULLEY_Z)), 0.27, 0.16, "X", 24),
                                          H.cylinder(bm, o + Vector((0, -0.6, PULLEY_Z)), 0.06, 0.3, "X", 12)])
text_piece("WeightStack", [
    (str((k + 1) * 5), 0.15, lambda x, up, d, z=TOP_Z - PLATE_GAP - PLATE_H / 2 - k * (PLATE_H + PLATE_GAP):
     o + Vector((x - 0.7, FRONT_Y - d, z + up)))
    for k in range(PLATES)])
text_piece("WeightStack", [(BRAND, 0.2, H.on_front(o, FRONT_Y, TOP_Z + 0.18))], "Logo")

# ================================================================ OFFICE
# WallSconce: a brass wall lamp (0.9 wide, 1.6 tall, 1.1 out), its back on y = 0: a round wall plate, an
# arm out to a drum shade, the warm light under the shade.
o = slot(0.9)
part("WallSconce", "Mount", lambda bm: [
    H.cylinder(bm, o + Vector((0, -0.04, 0.85)), 0.26, 0.08, "Y", 24),
    H.cylinder(bm, o + Vector((0, -0.35, 0.85)), 0.045, 0.6, "Y", 12),
    H.cylinder(bm, o + Vector((0, -0.65, 0.95)), 0.045, 0.24, "Z", 12)])
part("WallSconce", "Shade", lambda bm: H.lathe_z(bm, [(0.4, 1.0), (0.43, 1.0), (0.31, 1.62), (0.28, 1.62)], 32,
                                                  o + Vector((0, -0.65, 0))), smooth=True)
part("WallSconce", "Light", lambda bm: [H.cylinder(bm, o + Vector((0, -0.65, 1.03)), 0.39, 0.04, "Z", 24),
                                        H.sphere(bm, o + Vector((0, -0.65, 1.25)), 0.16, (1, 1, 1.3), 16, 8)])

# ================================================================ STORAGE
# WoodCrate: a slatted wooden crate (2.4 wide, 1.8 deep, 1.8 tall): three slats on each side and a slat lid,
# corner posts and rims, CENTRAL stencilled on the front.
o = slot(2.4)
CW, CD, CH = 2.4, 1.8, 1.8


def crate_slats(bm):
    for k in range(3):
        z = 0.2 + k * 0.5 + 0.22
        H.box(bm, o + Vector((0, -CD + 0.04, z)), (CW - 0.4, 0.06, 0.42))          # front
        H.box(bm, o + Vector((0, -0.04, z)), (CW - 0.4, 0.06, 0.42))               # back
        for sx in (-1, 1):
            H.box(bm, o + Vector((sx * (CW / 2 - 0.04), -CD / 2, z)), (0.06, CD - 0.4, 0.42))
    for k in range(4):
        H.box(bm, o + Vector((-CW / 2 + 0.2 + (k + 0.5) * (CW - 0.4) / 4, -CD / 2, CH - 0.04)),
              ((CW - 0.4) / 4 - 0.06, CD - 0.1, 0.06))


def crate_frame(bm):
    for sx in (-1, 1):
        for sy in (0, 1):
            H.box(bm, o + Vector((sx * (CW / 2 - 0.1), -0.1 - sy * (CD - 0.2), CH / 2)), (0.2, 0.2, CH))
    for z in (0.1, CH - 0.17):
        H.box(bm, o + Vector((0, -CD + 0.03, z)), (CW, 0.08, 0.16))
        H.box(bm, o + Vector((0, -0.03, z)), (CW, 0.08, 0.16))
        for sx in (-1, 1):
            H.box(bm, o + Vector((sx * (CW / 2 - 0.03), -CD / 2, z)), (0.08, CD, 0.16))


part("WoodCrate", "Slats", crate_slats, smooth=False)
part("WoodCrate", "Frame", crate_frame, smooth=False)
text_piece("WoodCrate", [(BRAND, 0.32, H.on_front(o, -CD + 0.01, 1.05)),
                         ("GYM EQUIPMENT", 0.13, H.on_front(o, -CD + 0.01, 0.62))])

# Pallet: a wooden pallet (4 wide, 3.2 deep, 0.6 tall): five top boards, three bottom boards, nine blocks.
o = slot(4.0)
part("Pallet", "Boards", lambda bm: [H.box(bm, o + Vector((0, -0.3 - k * 0.65, 0.55)), (4.0, 0.5, 0.1)) for k in range(5)]
     + [H.box(bm, o + Vector((0, -0.25 - k * 1.35, 0.05)), (4.0, 0.5, 0.1)) for k in range(3)], smooth=False)
part("Pallet", "Blocks", lambda bm: [H.box(bm, o + Vector((sx * 1.7, -0.25 - k * 1.35, 0.3)), (0.5, 0.5, 0.4))
                                     for sx in (-1, 0, 1) for k in range(3)], smooth=False)

# BumperPlate: a rubber bumper plate lying flat (2.0 across, 0.32 thick), a steel hub, CENTRAL on its top
# face; RoomProps piles copies in different colours into stacks.
o = slot(2.0)
BP_R, BP_T = 1.0, 0.32
part("BumperPlate", "Disc", lambda bm: H.lathe_z(bm, [(0.22, 0.0), (BP_R - 0.05, 0.0), (BP_R, 0.04), (BP_R, BP_T - 0.04),
                                                       (BP_R - 0.05, BP_T), (0.22, BP_T)], 48, o), smooth=True)
part("BumperPlate", "Hub", lambda bm: H.lathe_z(bm, [(0.1, 0.0), (0.24, 0.0), (0.24, BP_T + 0.02), (0.1, BP_T + 0.02)], 32, o))
text_piece("BumperPlate", [
    (BRAND, 0.2, lambda x, up, d: o + Vector((x, up + 0.55, BP_T + d))),
    ("BUMPER", 0.13, lambda x, up, d: o + Vector((x, up - 0.6, BP_T + d))),
])

# ================================================================ INDEX
# Medal: a medal hanging from a hook on its ribbon (0.8 wide, 2.3 tall), its back on y = 0: the ribbon in a
# V from the hook to the disc, a disc with a raised rim and CENTRAL on its face.
o = slot(0.8)
MEDAL_Z, MEDAL_R = 0.42, 0.38


def ribbon(bm):
    for sx in (-1, 1):
        top, bottom = Vector((sx * 0.24, -0.04, 2.15)), Vector((sx * 0.08, -0.04, MEDAL_Z + MEDAL_R - 0.02))
        length = (top - bottom).length
        angle = math.atan2(top.x - bottom.x, top.z - bottom.z)
        H.box(bm, o + (top + bottom) / 2, (0.2, 0.04, length), Matrix.Rotation(angle, 4, "Y"))
    H.box(bm, o + Vector((0, -0.05, 2.2)), (0.62, 0.06, 0.12))  # the hanger bar


part("Medal", "Ribbon", ribbon, smooth=False)
part("Medal", "Disc", lambda bm: [H.cylinder(bm, o + Vector((0, -0.11, MEDAL_Z)), MEDAL_R, 0.07, "Y", 40),
                                  H.torus(bm, o + Vector((0, -0.145, MEDAL_Z)), MEDAL_R - 0.04, 0.02, "XZ", 40, 6),
                                  H.torus(bm, o + Vector((0, -0.11, MEDAL_Z + MEDAL_R + 0.03)), 0.06, 0.02, "XZ", 16, 6)])
text_piece("Medal", [(BRAND, 0.1, H.on_front(o, -0.145, MEDAL_Z))])

print("RoomProps_06 built:", len(B.coll.objects), "objects:", sorted({ob.name.split("_")[0] for ob in B.coll.objects}))
