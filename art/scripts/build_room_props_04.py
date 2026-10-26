# Builds RoomProps_04 in the live Blender scene: the 3D props for the themed room fronts, batch 1
# (GAME_DESIGN §27 "Themed room fronts", user-approved 2026-10-26): Strongman (atlas stone on a stand,
# log, chain), Dumbbells (hex dumbbell, also scaled up as the sign over the door, and a dumbbell rack),
# Max Testing (competition plates for the plate wall) and Recovery & Spa (planter box, wall uplight).
# Variety in shapes and colours, not just red and black; every gear label says CENTRAL (user's rules).
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud (a 450 mm plate is 2.0 studs, as on
# Barbell_01), each item stands on z = 0 with its front toward -Y (wall-mounted items have their back
# on y = 0), objects are "<Item>_<Piece>" with ONE material each. Roblox recolours every piece from
# StarterGymConfig.PropColourways (COLOURWAYS below is the list to copy there; the first colourway is
# also what this file shows). PAINT holds the same colours as StarterGymConfig.PropPaints (0-255).
#
# Run in an otherwise empty file (art/blender/RoomProps_04.blend):
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

B = H.Builder("RoomProps_04")
BRAND = H.BRAND

# StarterGymConfig.PropPaints (sRGB 0-255; the new one for this batch at the end).
PAINT = {
    "Black": (22, 22, 24), "Charcoal": (46, 48, 54), "Red": (200, 30, 38), "White": (236, 236, 232),
    "LightGrey": (176, 180, 186), "Blue": (30, 92, 205), "Navy": (30, 48, 98), "Yellow": (242, 190, 30),
    "Mustard": (214, 160, 38), "Green": (95, 222, 60), "Forest": (34, 98, 62), "Sage": (140, 164, 134),
    "Teal": (0, 138, 140), "Purple": (128, 52, 190), "Orange": (245, 130, 30), "Terracotta": (196, 98, 62),
    "Cream": (236, 224, 196), "Oak": (198, 152, 102), "Chocolate": (94, 52, 32), "Silver": (190, 192, 198),
    "Brass": (200, 160, 82), "WarmGlow": (255, 205, 150), "Slate": (78, 82, 88), "Coral": (238, 112, 92),
    "Sky": (120, 178, 224),
    # new in RoomProps_04
    "Granite": (150, 150, 146),
}
METAL = {"Silver", "Brass"}


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


MAT = {}
for colour, rgb in PAINT.items():
    lin = tuple(linear(c) for c in rgb)
    MAT[colour] = H.material("RP4_" + colour, lin, 1.0 if colour in METAL else 0.0, 0.5, 1.0,
                             lin if colour == "WarmGlow" else None)

# Per item: a list of colourways, each piece -> colour name. Pieces not named keep the file's look.
COLOURWAYS = {
    # Strongman
    "AtlasStone": [{"Stone": s} for s in ("Granite", "Slate", "Charcoal")],
    "AtlasStand": [{"Frame": f, "Top": t} for f, t in (("Oak", "Chocolate"), ("Black", "Oak"))],
    "StrongLog": [{"Body": b, "Cap": c, "Slot": "Charcoal", "Handle": "Silver", "Text": t}
                  for b, c, t in (("Black", "Silver", "White"), ("Navy", "Silver", "White"), ("Forest", "Brass", "Cream"),
                                  ("Orange", "Black", "Black"))],
    "Chain": [{"Metal": m} for m in ("Silver", "Charcoal")],
    # Dumbbells
    "HexDumbbell": [{"Head": "Black", "Face": f, "Handle": "Silver", "Text": t}
                    for f, t in (("Red", "White"), ("Blue", "White"), ("Yellow", "Black"), ("Green", "Black"),
                                 ("Orange", "Black"), ("White", "Black"), ("Purple", "White"), ("Teal", "White"))],
    "DumbbellRack": [{"Frame": f, "Shelf": s, "Text": t}
                     for f, s, t in (("Black", "Charcoal", "White"), ("Silver", "Black", "Black"))],
    # Max Testing: IPF calibrated plate colours.
    "CompPlate": [{"Disc": d, "Hub": "Silver", "Text": t}
                  for d, t in (("Red", "White"), ("Blue", "White"), ("Yellow", "Black"), ("Green", "White"),
                               ("White", "Black"))],
    # Recovery & Spa
    "Planter": [{"Body": b, "Soil": "Chocolate"} for b in ("Oak", "Charcoal", "Terracotta", "Cream")],
    "WallUplight": [{"Body": b, "Light": "WarmGlow"} for b in ("Brass", "Black", "White")],
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


X = [0.0]  # the next item's X position along the shelf of items


def slot(width):
    """The base point of the next item, `width` studs wide."""
    base = Vector((X[0] + width / 2, 0, 0))
    X[0] += width + 1.0
    return base


# ================================================================ STRONGMAN
# AtlasStone: a round granite stone, 1.8 across (about 400 mm), slightly flattened where it sits.
o = slot(1.8)
part("AtlasStone", "Stone", lambda bm: H.sphere(bm, o + Vector((0, 0, 0.88)), 0.9, (1, 1, 0.98), 32, 16))

# AtlasStand: a low wooden platform the stone sits on beside the door (2.6 square, 1.2 tall): four
# square legs, rails, and a thick top with a shallow ring where the stone rests.
o = slot(2.6)


def stand_frame(bm):
    for sx in (-1, 1):
        for sy in (-1, 1):
            H.box(bm, o + Vector((sx * 1.1, sy * 1.1, 0.5)), (0.3, 0.3, 1.0))
    for sy in (-1, 1):
        H.box(bm, o + Vector((0, sy * 1.1, 0.25)), (2.2, 0.16, 0.2))
    for sx in (-1, 1):
        H.box(bm, o + Vector((sx * 1.1, 0, 0.25)), (0.16, 2.2, 0.2))


part("AtlasStand", "Frame", stand_frame, smooth=False)
part("AtlasStand", "Top", lambda bm: [H.rounded_box(bm, o + Vector((0, 0, 1.1)), (2.6, 2.6, 0.2), 0.04),
                                      H.torus(bm, o + Vector((0, 0, 1.22)), 0.55, 0.06, "XY", 32, 8)], smooth=False)

# StrongLog: a strongman log (7 long, 1.35 across) lying along X, steel end caps with CENTRAL, and two
# neutral-grip handles set into a dark slot in its front-top.
o = slot(7.0)
LOG_R, LOG_HALF = 0.68, 3.5
part("StrongLog", "Body", lambda bm: turned(bm, lambda t: H.cylinder(t, (0, 0, 0), LOG_R, 2 * LOG_HALF - 0.2, "Z", 32),
                                           Matrix.Translation(o + Vector((0, 0, LOG_R))) @ Matrix.Rotation(math.pi / 2, 4, "Y")))
part("StrongLog", "Cap", lambda bm: [turned(bm, lambda t: H.cylinder(t, (0, 0, 0), LOG_R + 0.04, 0.12, "Z", 32),
                                            Matrix.Translation(o + Vector((sx * (LOG_HALF - 0.06), 0, LOG_R)))
                                            @ Matrix.Rotation(math.pi / 2, 4, "Y")) for sx in (-1, 1)])


HANDLE_X = (-0.5, 0.5)


def log_slots(bm):
    # The two dark cut-outs in the log's front-top, where the hands go.
    for sx in HANDLE_X:
        H.rounded_box(bm, o + Vector((sx, -0.18, 2 * LOG_R - 0.12)), (0.62, 0.95, 0.3), 0.06,
                      rotation=Matrix.Rotation(math.radians(-25), 4, "X"))


def log_handles(bm):
    # A grip bar across each cut-out, front to back, just below the log's surface.
    for sx in HANDLE_X:
        H.cylinder(bm, o + Vector((sx, -0.18, 2 * LOG_R - 0.16)), 0.075, 0.9, "Y", 16)


part("StrongLog", "Slot", log_slots, smooth=False)
part("StrongLog", "Handle", log_handles)
text_piece("StrongLog", [
    (BRAND, 0.32, lambda x, up, d, sx=sx: o + Vector((sx * (LOG_HALF + d), x * sx, LOG_R + up)))
    for sx in (-1, 1)])

# Chain: a hanging steel chain (5.4 long) of oval links, alternate links turned 90 degrees; the top
# link hangs from y = 0 (wall hook), so it can hang from a wall or a beam.
o = slot(0.8)


def chain_links(bm):
    for k in range(12):
        z = 5.4 - 0.25 - k * 0.43
        plane = "XZ" if k % 2 == 0 else "YZ"
        turned(bm, lambda t: H.torus(t, (0, 0, 0), 0.17, 0.05, "XY", 16, 8),
               Matrix.Translation(o + Vector((0, -0.25, z))) @ Matrix.Diagonal((1, 1, 1.6, 1))
               @ (Matrix.Rotation(math.pi / 2, 4, "X") if plane == "XZ" else Matrix.Rotation(math.pi / 2, 4, "Y")
                  @ Matrix.Rotation(math.pi / 2, 4, "X")))


part("Chain", "Metal", chain_links)

# ================================================================ DUMBBELLS
# HexDumbbell: a rubber hex dumbbell lying on its flat (1.9 long, 0.75 across the heads): black heads
# with a coloured end face carrying CENTRAL, a knurled steel handle. Roblox scales a copy up for the
# big sign over the Dumbbells door.
o = slot(1.9)
HEAD_R, HEAD_LEN, HANDLE_HALF = 0.4, 0.5, 0.42


def hex_head(t, length):
    H.cylinder(t, (0, 0, 0), HEAD_R, length, "Z", 6)


def dumbbell_part(build_one):
    def build(bm):
        for sx in (-1, 1):
            turned(bm, build_one, Matrix.Translation(o + Vector((sx * (HANDLE_HALF + HEAD_LEN / 2), 0, HEAD_R * math.cos(math.pi / 6))))
                   @ Matrix.Rotation(sx * math.pi / 2, 4, "Y") @ Matrix.Rotation(math.pi / 6, 4, "Z"))
    return build


part("HexDumbbell", "Head", dumbbell_part(lambda t: hex_head(t, HEAD_LEN - 0.08)), smooth=False)
part("HexDumbbell", "Face", lambda bm: [turned(bm, lambda t: H.cylinder(t, (0, 0, 0), HEAD_R - 0.03, 0.04, "Z", 6),
                                               Matrix.Translation(o + Vector((sx * (HANDLE_HALF + HEAD_LEN - 0.02), 0,
                                                                              HEAD_R * math.cos(math.pi / 6))))
                                               @ Matrix.Rotation(math.pi / 2, 4, "Y") @ Matrix.Rotation(math.pi / 6, 4, "Z"))
                                        for sx in (-1, 1)], smooth=False)
part("HexDumbbell", "Handle", lambda bm: turned(bm, lambda t: H.cylinder(t, (0, 0, 0), 0.09, 2 * HANDLE_HALF + 0.1, "Z", 16),
                                                Matrix.Translation(o + Vector((0, 0, HEAD_R * math.cos(math.pi / 6))))
                                                @ Matrix.Rotation(math.pi / 2, 4, "Y")))
text_piece("HexDumbbell", [
    (BRAND, 0.13, lambda x, up, d, sx=sx: o + Vector((sx * (HANDLE_HALF + HEAD_LEN + d), x * sx,
                                                      HEAD_R * math.cos(math.pi / 6) + up)))
    for sx in (-1, 1)])

# DumbbellRack: a two-tier angled dumbbell rack (6 wide, 2.7 tall, 2 deep), its back against a wall at
# y = 0: side frames, two sloping shelves with lips, and a CENTRAL plate on the front rail.
o = slot(6.0)
RACK_W = 6.0


def rack_frame(bm):
    for sx in (-1, 1):
        x = sx * (RACK_W / 2 - 0.1)
        H.box(bm, o + Vector((x, -0.25, 1.35)), (0.16, 0.16, 2.7))     # back post
        H.box(bm, o + Vector((x, -1.85, 0.6)), (0.16, 0.16, 1.2))      # front post
        H.box(bm, o + Vector((x, -1.05, 0.06)), (0.16, 1.9, 0.12))     # foot
    H.box(bm, o + Vector((0, -1.85, 1.05)), (RACK_W, 0.12, 0.16))      # front rail (label)


def rack_shelves(bm):
    for z, y_front, y_back, lip in ((0.95, -1.75, -0.6, -1.78), (1.95, -1.0, -0.3, -1.03)):
        mid_y = (y_front + y_back) / 2
        tilt = Matrix.Rotation(math.radians(-12), 4, "X")
        H.box(bm, o + Vector((0, mid_y, z)), (RACK_W - 0.2, abs(y_back - y_front), 0.08), tilt)
        H.box(bm, o + Vector((0, lip, z + 0.05)), (RACK_W - 0.2, 0.06, 0.2))


part("DumbbellRack", "Frame", rack_frame, smooth=False)
part("DumbbellRack", "Shelf", rack_shelves, smooth=False)
text_piece("DumbbellRack", [(BRAND, 0.13, H.on_front(o, -1.92, 1.05))])

# ================================================================ MAX TESTING
# CompPlate: a calibrated competition plate standing on its edge (2.0 across, as on Barbell_01), its
# face toward -Y: a disc with a raised rim, a steel hub, CENTRAL on the face.
o = slot(2.0)
PLATE_R, PLATE_T = 1.0, 0.12
plate_at = Matrix.Translation(o + Vector((0, -PLATE_T / 2, PLATE_R))) @ Matrix.Rotation(math.pi / 2, 4, "X")
part("CompPlate", "Disc", lambda bm: turned(bm, lambda t: H.lathe_z(t, [(0.2, -PLATE_T / 2), (PLATE_R - 0.06, -PLATE_T / 2),
                                                                         (PLATE_R, -PLATE_T / 2 + 0.03), (PLATE_R, PLATE_T / 2 - 0.03),
                                                                         (PLATE_R - 0.06, PLATE_T / 2), (0.2, PLATE_T / 2)], 48),
                                            plate_at))
part("CompPlate", "Hub", lambda bm: turned(bm, lambda t: H.lathe_z(t, [(0.07, -PLATE_T / 2 - 0.04), (0.22, -PLATE_T / 2 - 0.04),
                                                                        (0.22, PLATE_T / 2 + 0.04), (0.07, PLATE_T / 2 + 0.04)], 32),
                                           plate_at))
text_piece("CompPlate", [
    (BRAND, 0.2, lambda x, up, d: o + Vector((x, -PLATE_T - d, PLATE_R + 0.55 + up))),
    ("CALIBRATED", 0.09, lambda x, up, d: o + Vector((x, -PLATE_T - d, PLATE_R - 0.5 + up))),
])

# ================================================================ RECOVERY & SPA
# Planter: a long planter box (4 x 1.2, 1.3 tall) with a lip, short feet and soil; plants come from the
# existing potted-plant model, set in the soil by RoomProps.
o = slot(4.0)
part("Planter", "Body", lambda bm: [H.rounded_box(bm, o + Vector((0, -0.6, 0.7)), (4.0, 1.2, 1.1), 0.05),
                                    H.rounded_box(bm, o + Vector((0, -0.6, 1.25)), (4.12, 1.32, 0.1), 0.03)]
     + [H.box(bm, o + Vector((sx * 1.8, -0.6, 0.075)), (0.25, 1.0, 0.15)) for sx in (-1, 1)], smooth=False)
part("Planter", "Soil", lambda bm: H.box(bm, o + Vector((0, -0.6, 1.24)), (3.8, 1.0, 0.06)), smooth=False)

# WallUplight: a half-cylinder wall light (0.5 wide, 0.8 tall, back on y = 0) with a glowing top.
o = slot(0.6)
part("WallUplight", "Body", lambda bm: turned(bm, lambda t: H.cylinder(t, (0, 0, 0), 0.25, 0.75, "Z", 24, None),
                                              Matrix.Translation(o + Vector((0, -0.25, 0.375)))))
part("WallUplight", "Light", lambda bm: H.cylinder(bm, o + Vector((0, -0.25, 0.78)), 0.2, 0.05, "Z", 24))

print("RoomProps_04 built:", len(B.coll.objects), "objects:", sorted({ob.name.split("_")[0] for ob in B.coll.objects}))
