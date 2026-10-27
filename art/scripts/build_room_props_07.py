# Builds RoomProps_07 in the live Blender scene: the 3D props for the themed room fronts, batch 2b
# (GAME_DESIGN §27 "Themed room fronts", user-approved 2026-10-26): Media Room (a broadcast microphone on
# a wall arm, an ON AIR lamp, headphones on a hook), Warm-up & Mobility (a resistance band on a hook, a foam
# roller, a wall rack for rollers) and Coaches (a clipboard with a training sheet).
# Variety in shapes and colours, not just red and black; every gear label says CENTRAL (user's rules).
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, each item stands on z = 0 with its front
# toward -Y (wall-mounted items have their back on y = 0), objects are "<Item>_<Piece>" with ONE material
# each. Roblox recolours every piece from StarterGymConfig.PropColourways (COLOURWAYS below is the list to
# copy there; the first colourway is also what this file shows). PAINT holds the same colours as
# StarterGymConfig.PropPaints (0-255).
#
# Run in an otherwise empty file (art/blender/RoomProps_07.blend):
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

B = H.Builder("RoomProps_07")
BRAND = H.BRAND

# StarterGymConfig.PropPaints (sRGB 0-255; the new one for this batch at the end).
PAINT = {
    "Black": (22, 22, 24), "Charcoal": (46, 48, 54), "Red": (200, 30, 38), "White": (236, 236, 232),
    "LightGrey": (176, 180, 186), "Blue": (30, 92, 205), "Navy": (30, 48, 98), "Yellow": (242, 190, 30),
    "Green": (95, 222, 60), "Forest": (34, 98, 62), "Teal": (0, 138, 140), "Purple": (128, 52, 190),
    "Orange": (245, 130, 30), "Pink": (240, 125, 172), "Kraft": (184, 142, 98), "Oak": (198, 152, 102),
    "Silver": (190, 192, 198), "Coral": (238, 112, 92), "Lime": (170, 214, 60), "Sky": (120, 178, 224),
    # new in RoomProps_07
    "RedGlow": (230, 40, 40),
}
METAL = {"Silver"}
GLOW = {"RedGlow"}


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


MAT = {}
for colour, rgb in PAINT.items():
    lin = tuple(linear(c) for c in rgb)
    MAT[colour] = H.material("RP7_" + colour, lin, 1.0 if colour in METAL else 0.0, 0.5, 1.0,
                             lin if colour in GLOW else None)

# Per item: a list of colourways, each piece -> colour name.
COLOURWAYS = {
    # Media Room
    "StudioMic": [{"Mount": "Black", "Body": b, "Grille": g, "Ring": "Silver", "Text": t}
                  for b, g, t in (("Black", "Silver", "White"), ("Silver", "Charcoal", "Black"), ("Red", "Silver", "White"))],
    "OnAirLamp": [{"Body": "Black", "Glow": "RedGlow", "Text": "White"}],
    "Headphones": [{"Band": b, "Cups": c, "Pads": "Black", "Text": t}
                   for b, c, t in (("Black", "Red", "White"), ("White", "Sky", "Black"), ("Black", "Yellow", "Black"),
                                   ("Charcoal", "Teal", "White"))],
    # Warm-up & Mobility
    "ResistanceBand": [{"Band": b, "Hook": "Silver"}
                       for b in ("Red", "Yellow", "Green", "Blue", "Purple", "Black", "Orange")],
    "MobilityRoller": [{"Body": b, "Ends": "Black", "Text": "White"} for b in ("Teal", "Orange", "Purple", "Blue", "Lime", "Pink")],
    "RollerRack": [{"Frame": f, "Text": t} for f, t in (("Black", "White"), ("Silver", "Black"), ("White", "Black"))],
    # Coaches
    "Clipboard": [{"Board": b, "Clip": "Silver", "Paper": "White", "Lines": "Charcoal", "Text": "Black"}
                  for b in ("Kraft", "Blue", "Red", "Green", "Orange", "Purple")],
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


def beam(bm, a, b, size):
    """A square bar of side `size` from point a to point b."""
    a, b = Vector(a), Vector(b)
    direction = (b - a).normalized()
    rot = direction.to_track_quat("Z", "Y").to_matrix().to_4x4()
    H.box(bm, (a + b) / 2, (size, size, (b - a).length), rot)


X = [0.0]  # the next item's X position along the shelf of items


def slot(width):
    """The base point of the next item, `width` studs wide."""
    base = Vector((X[0] + width / 2, 0, 0))
    X[0] += width + 1.0
    return base


# ================================================================ MEDIA ROOM
# StudioMic: a broadcast microphone on a wall boom arm (0.9 wide, 2.0 out, 2.9 tall), its back on y = 0:
# a wall plate, a two-part arm, a cradle ring round the mic body, a domed grille, CENTRAL on the body.
o = slot(0.9)
MIC = Vector((0, -1.9, 0))
part("StudioMic", "Mount", lambda bm: [H.box(bm, o + Vector((0, -0.05, 1.4)), (0.5, 0.1, 0.8)),
                                       beam(bm, o + Vector((0, -0.1, 1.4)), o + Vector((0, -1.0, 2.6)), 0.1),
                                       beam(bm, o + Vector((0, -1.0, 2.6)), o + MIC + Vector((0, 0.36, 2.1)), 0.1),
                                       H.sphere(bm, o + Vector((0, -1.0, 2.6)), 0.09, (1, 1, 1), 12, 6)], smooth=False)
part("StudioMic", "Body", lambda bm: H.lathe_z(bm, [(0, 1.45), (0.2, 1.45), (0.25, 1.6), (0.25, 2.5), (0, 2.5)], 32, o + MIC))
part("StudioMic", "Grille", lambda bm: H.sphere(bm, o + MIC + Vector((0, 0, 2.55)), 0.27, (1, 1, 1.3), 24, 12))
part("StudioMic", "Ring", lambda bm: H.torus(bm, o + MIC + Vector((0, 0, 2.1)), 0.36, 0.05, "XY", 32, 8))
text_piece("StudioMic", [(BRAND, 0.1, H.on_cylinder(o + MIC, 0.25, 1.95))])

# OnAirLamp: an "ON AIR" light box (2.4 wide, 0.8 tall, 0.4 out), its back on y = 0: a black box, a glowing
# red front, white letters.
o = slot(2.4)
part("OnAirLamp", "Body", lambda bm: H.rounded_box(bm, o + Vector((0, -0.18, 0.4)), (2.4, 0.36, 0.8), 0.04), smooth=False)
part("OnAirLamp", "Glow", lambda bm: H.box(bm, o + Vector((0, -0.37, 0.4)), (2.2, 0.04, 0.62)), smooth=False)
text_piece("OnAirLamp", [("ON AIR", 0.42, H.on_front(o, -0.39, 0.4))])

# Headphones: studio headphones hanging on a wall peg (1.1 wide, 0.6 out, 1.4 tall): a headband arc, ear
# cups with CENTRAL on their outsides, pads.
o = slot(1.1)
HP = Vector((0, -0.35, 0.9))
part("Headphones", "Band", lambda bm: [H.torus(bm, o + HP, 0.45, 0.05, "XZ", 32, 8, math.pi, 0.0),
                                       H.box(bm, o + Vector((0, -0.16, 1.27)), (0.08, 0.32, 0.06))])
part("Headphones", "Cups", lambda bm: [H.cylinder(bm, o + HP + Vector((sx * 0.48, 0, -0.12)), 0.22, 0.16, "X", 24)
                                       for sx in (-1, 1)])
part("Headphones", "Pads", lambda bm: [H.cylinder(bm, o + HP + Vector((sx * 0.37, 0, -0.12)), 0.19, 0.08, "X", 24)
                                       for sx in (-1, 1)])
text_piece("Headphones", [(BRAND, 0.07, lambda x, up, d, sx=sx: o + HP + Vector((sx * (0.56 + d), -x * sx, -0.12 + up)))
                          for sx in (-1, 1)])

# ================================================================ WARM-UP & MOBILITY
# ResistanceBand: a long loop band hanging from a wall hook (0.7 wide, 2.6 tall).
o = slot(0.7)


BAND_W, BAND_T = 0.2, 0.05  # the strip's width (facing you, user 2026-10-26: thin hoops did not read as bands)


def band_loop(bm):
    # A flat strip hanging in a long loop: two straight sides and a half circle at the top and bottom, the
    # strip's wide face toward the room.
    def arc(centre, start):
        tmp = bmesh.new()
        H.torus(tmp, (0, 0, 0), 0.3, BAND_W / 2, "XZ", 20, 8, math.pi, start)
        bmesh.ops.transform(tmp, matrix=Matrix.Translation(o + centre) @ Matrix.Diagonal((1, BAND_T / BAND_W, 1, 1)),
                            verts=tmp.verts[:])
        H._merge(bm, tmp)
    arc(Vector((0, -0.12, 2.3)), 0.0)
    arc(Vector((0, -0.12, 0.4)), math.pi)
    for sx in (-1, 1):
        H.box(bm, o + Vector((sx * 0.3, -0.12, 1.35)), (BAND_W, BAND_T, 1.9))


part("ResistanceBand", "Band", band_loop)
part("ResistanceBand", "Hook", lambda bm: [H.cylinder(bm, o + Vector((0, -0.14, 2.45)), 0.05, 0.28, "Y", 12),
                                           H.cylinder(bm, o + Vector((0, -0.04, 2.45)), 0.12, 0.08, "Y", 16)])

# MobilityRoller (not "FoamRoller": that is the Recovery room's roller in RoomProps_03): a foam roller
# lying along X (2.7 long, 0.67 across): the foam body with CENTRAL, black end caps
# and raised black rings.
o = slot(2.7)
FR = 0.335
part("MobilityRoller", "Body", lambda bm: H.cylinder(bm, o + Vector((0, -FR, FR)), FR, 2.5, "X", 32))
part("MobilityRoller", "Ends", lambda bm: [H.cylinder(bm, o + Vector((sx * 1.3, -FR, FR)), FR + 0.01, 0.1, "X", 32) for sx in (-1, 1)]
     + [H.torus(bm, o + Vector((x, -FR, FR)), FR, 0.03, "YZ", 32, 6) for x in (-0.8, -0.4, 0.4, 0.8)])
text_piece("MobilityRoller", [(BRAND, 0.16, lambda x, up, d: o + Vector((x, -FR - (FR + d) * math.cos(up / FR),
                                                                         FR + (FR + d) * math.sin(up / FR))))])

# RollerRack: a wall rack for four foam rollers (2.6 wide, 1.0 out, 4.7 tall), its back on y = 0: two
# uprights with a pair of pegs per level (a lip at the front), a top bar with CENTRAL.
o = slot(2.6)
ROLLER_LEVELS = (0.9, 1.9, 2.9, 3.9)  # the pegs' tops


def rack_frame(bm):
    for sx in (-1, 1):
        H.box(bm, o + Vector((sx * 1.2, -0.06, 2.35)), (0.16, 0.12, 4.7))
        for z in ROLLER_LEVELS:
            H.box(bm, o + Vector((sx * 1.2, -0.5, z - 0.05)), (0.12, 0.88, 0.1))
            H.box(bm, o + Vector((sx * 1.2, -0.9, z + 0.06)), (0.12, 0.08, 0.22))
    H.box(bm, o + Vector((0, -0.08, 4.55)), (2.6, 0.16, 0.3))


part("RollerRack", "Frame", rack_frame, smooth=False)
text_piece("RollerRack", [(BRAND, 0.18, H.on_front(o, -0.165, 4.55))])

# ================================================================ COACHES
# Clipboard: a clipboard hanging on the wall (1.0 wide, 1.4 tall, 0.15 out): the board, a steel clip with
# CENTRAL, a training sheet with ruled lines.
o = slot(1.0)
part("Clipboard", "Board", lambda bm: H.rounded_box(bm, o + Vector((0, -0.03, 0.7)), (1.0, 0.05, 1.4), 0.04), smooth=False)
part("Clipboard", "Paper", lambda bm: H.box(bm, o + Vector((0, -0.065, 0.62)), (0.84, 0.02, 1.1)), smooth=False)
part("Clipboard", "Clip", lambda bm: [H.rounded_box(bm, o + Vector((0, -0.09, 1.26)), (0.5, 0.08, 0.2), 0.03),
                                      H.torus(bm, o + Vector((0, -0.09, 1.39)), 0.08, 0.02, "XZ", 16, 6)], smooth=False)
part("Clipboard", "Lines", lambda bm: [H.box(bm, o + Vector((0.05, -0.078, 1.0 - k * 0.11)), (0.66, 0.006, 0.025))
                                       for k in range(8)], smooth=False)
text_piece("Clipboard", [(BRAND, 0.08, H.on_front(o, -0.13, 1.26)),
                         ("TRAINING", 0.07, H.on_front(o, -0.078, 1.1))])

print("RoomProps_07 built:", len(B.coll.objects), "objects:", sorted({ob.name.split("_")[0] for ob in B.coll.objects}))
