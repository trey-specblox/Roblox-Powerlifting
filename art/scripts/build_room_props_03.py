# Builds RoomProps_03 in the live Blender scene: the 3D props for the Showers, Recovery and Massage rooms
# (GAME_DESIGN §27 "Room purposes": Showers look only; Recovery and Massage are relax spots). Variety in
# shapes and colours, not just red and black; every product label says CENTRAL (user's rules).
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, each item stands on z = 0 with its
# front toward -Y (wall-mounted items have their back on y = 0), objects are "<Item>_<Piece>" with ONE
# material each. Roblox recolours every piece from StarterGymConfig.PropColourways (COLOURWAYS below is
# the list to copy there; the first colourway is also what this file shows). PAINT holds the same
# colours as StarterGymConfig.PropPaints, in Roblox's 0-255 values.
#
# Run in an otherwise empty file (art/blender/RoomProps_03.blend):
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

B = H.Builder("RoomProps_03")
BRAND = H.BRAND

# StarterGymConfig.PropPaints (sRGB 0-255; the new ones for this batch at the end).
PAINT = {
    "Black": (22, 22, 24), "Charcoal": (46, 48, 54), "Red": (200, 30, 38), "White": (236, 236, 232),
    "LightGrey": (176, 180, 186), "Blue": (30, 92, 205), "Navy": (30, 48, 98), "Yellow": (242, 190, 30),
    "Mustard": (214, 160, 38), "Green": (95, 222, 60), "Forest": (34, 98, 62), "Sage": (140, 164, 134),
    "Mint": (172, 218, 196), "Teal": (0, 138, 140), "Purple": (128, 52, 190), "Lavender": (184, 170, 222),
    "Orange": (245, 130, 30), "Terracotta": (196, 98, 62), "Pink": (240, 125, 172), "Cream": (236, 224, 196),
    "Kraft": (184, 142, 98), "Oak": (198, 152, 102), "Silver": (190, 192, 198), "Brass": (200, 160, 82),
    "Glass": (205, 225, 235), "WaterBlue": (150, 200, 235), "WarmGlow": (255, 205, 150),
    # new in RoomProps_03
    "Coral": (238, 112, 92), "Lime": (170, 214, 60), "Sky": (120, 178, 224), "Sand": (214, 190, 150),
    "Slate": (78, 82, 88), "Amber": (190, 110, 40), "BlueGlass": (40, 90, 170), "Ice": (225, 240, 250),
}
METAL = {"Silver", "Brass"}
SEE_THROUGH = {"Glass": 0.35, "WaterBlue": 0.35, "Amber": 0.75, "BlueGlass": 0.75, "Ice": 0.6}


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


MAT = {}
for colour, rgb in PAINT.items():
    lin = tuple(linear(c) for c in rgb)
    MAT[colour] = H.material("RP3_" + colour, lin, 1.0 if colour in METAL else 0.0, 0.5,
                             SEE_THROUGH.get(colour, 1.0), lin if colour == "WarmGlow" else None)

# Per item: a list of colourways, each piece -> colour name. Pieces not named keep the file's look.
COLOURWAYS = {
    # Showers
    "RainShower": [{"Metal": m, "Head": m, "Dark": "Charcoal"} for m in ("Silver", "Black", "Brass")],
    "ShowerGel": [{"Body": b, "Pump": p, "Label": "White", "Text": "Black"}
                  for b, p in (("Teal", "White"), ("Lavender", "White"), ("Coral", "Black"), ("Charcoal", "Silver"),
                               ("Mint", "White"))],
    "Shampoo": [{"Body": b, "Cap": c, "Label": l, "Text": t}
                for b, c, l, t in (("Sky", "White", "White", "Navy"), ("Lime", "White", "White", "Black"),
                                   ("Orange", "Black", "Cream", "Black"), ("White", "Navy", "Navy", "White"))],
    "Towel": [{"Body": b, "Stripe": s} for b, s in (("White", "LightGrey"), ("Sage", "White"), ("Navy", "White"),
                                                     ("Terracotta", "Cream"), ("Mustard", "White"), ("Sky", "White"))],
    "HangingTowel": [{"Body": b, "Stripe": s, "Metal": "Silver"}
                     for b, s in (("White", "LightGrey"), ("Sage", "White"), ("Navy", "White"), ("Terracotta", "Cream"),
                                  ("Mustard", "White"), ("Sky", "White"))],
    "SoapDispenser": [{"Body": "White", "Window": "Ice", "Button": "Silver", "Text": "Black"},
                      {"Body": "Black", "Window": "Ice", "Button": "Silver", "Text": "White"}],
    "TowelBin": [{"Body": b, "Rim": r, "Text": t, "Fill": "White"}
                 for b, r, t in (("Sage", "Oak", "White"), ("Charcoal", "Oak", "White"), ("Cream", "Black", "Black"))],
    "Slides": [{"Sole": s, "Strap": st, "Text": t}
               for s, st, t in (("Black", "Black", "White"), ("White", "Navy", "White"), ("White", "Teal", "White"),
                                ("Black", "Sage", "Black"), ("Cream", "Coral", "White"))],
    # Recovery
    "ColdPlunge": [{"Body": "Oak", "Band": "Black", "Rim": "Oak", "Water": "WaterBlue", "Ice": "Ice"},
                   {"Body": "White", "Band": "Silver", "Rim": "Silver", "Water": "WaterBlue", "Ice": "Ice"},
                   {"Body": "Charcoal", "Band": "Oak", "Rim": "Oak", "Water": "WaterBlue", "Ice": "Ice"}],
    "FoamRoller": [{"Body": b, "Core": c} for b, c in (("Blue", "Black"), ("Orange", "Black"), ("Pink", "White"),
                                                         ("Lime", "Charcoal"), ("Teal", "White"), ("Purple", "Black"))],
    "Lounger": [{"Pad": p, "Frame": f, "Pillow": pi}
                for p, f, pi in (("Charcoal", "Silver", "LightGrey"), ("Sage", "Oak", "Cream"),
                                 ("Terracotta", "Black", "Cream"), ("Navy", "Silver", "White"))],
    "MassageGun": [{"Body": b, "Grip": g, "Head": h, "Text": t}
                   for b, g, h, t in (("Black", "Charcoal", "Orange", "White"), ("Sage", "Charcoal", "White", "White"),
                                      ("White", "LightGrey", "Teal", "Black"), ("Lavender", "Charcoal", "White", "Black"))],
    "YogaMat": [{"Body": b, "Strap": s} for b, s in (("Purple", "Black"), ("Teal", "Black"), ("Coral", "White"),
                                                       ("Mustard", "Black"), ("Sky", "White"), ("Sage", "Oak"))],
    # Massage
    "MassageTable": [{"Pad": p, "Frame": f, "Legs": f, "Bolster": b, "Towel": t}
                     for p, f, b, t in (("Cream", "Oak", "Sage", "White"), ("Sage", "Oak", "Cream", "White"),
                                        ("Charcoal", "Black", "Terracotta", "White"),
                                        ("Terracotta", "Oak", "Cream", "Cream"))],
    "OilBottle": [{"Body": b, "Cap": c, "Label": "Cream", "Text": "Black"}
                  for b, c in (("Amber", "Black"), ("BlueGlass", "White"), ("White", "Brass"))],
    "CandleSet": [{"Wax": w, "Flame": "WarmGlow", "Tray": t}
                  for w, t in (("Cream", "Brass"), ("Sage", "Oak"), ("Terracotta", "Black"), ("White", "Oak"))],
    "Diffuser": [{"Body": b, "Base": ba, "Light": "WarmGlow"}
                 for b, ba in (("White", "Oak"), ("Sage", "Oak"), ("Terracotta", "Black"))],
    "SpaStones": [{"Stone": s} for s in ("Slate", "Charcoal")],
    "Pouf": [{"Body": b, "Piping": p} for b, p in (("Mustard", "Cream"), ("Sage", "Cream"), ("Terracotta", "Cream"),
                                                     ("Cream", "Kraft"), ("Navy", "Cream"))],
    "FoldingScreen": [{"Frame": f, "Panel": p} for f, p in (("Oak", "Cream"), ("Black", "Sage"), ("Oak", "Kraft"))],
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


def tube(bm, a, b, radius, segments=10, radius2=None):
    """A cylinder from point a to point b."""
    a, b = Vector(a), Vector(b)
    along = b - a
    turn = Vector((0, 0, 1)).rotation_difference(along.normalized()).to_matrix().to_4x4()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius,
                          radius2=radius if radius2 is None else radius2, depth=along.length,
                          matrix=Matrix.Translation((a + b) / 2) @ turn)


def lathe_x(bm, outline, segments, centre):
    """lathe_z turned so the outline's z runs along X (a roller lying on the floor)."""
    tmp = bmesh.new()
    H.lathe_z(tmp, outline, segments)
    bmesh.ops.rotate(tmp, verts=tmp.verts[:], cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    bmesh.ops.translate(tmp, verts=tmp.verts[:], vec=Vector(centre))
    H._merge(bm, tmp)


def sheet(bm, points, width, thickness, wave=0.0):
    """A cloth sheet: the (y, z) path `points` swept across X (`width`), solidified."""
    tmp = bmesh.new()
    cols = 16
    grid = []
    for y, z in points:
        row = []
        for i in range(cols + 1):
            x = -width / 2 + width * i / cols
            row.append(tmp.verts.new(o + Vector((x, y + wave * math.sin(i * math.pi / 4), z))))
        grid.append(row)
    for j in range(len(points) - 1):
        for i in range(cols):
            tmp.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    bmesh.ops.solidify(tmp, geom=tmp.faces[:], thickness=thickness)
    H._merge(bm, tmp)


X = [0.0]  # the next item's X position along the shelf of items


def slot(width):
    """The base point of the next item, `width` studs wide."""
    base = Vector((X[0] + width / 2, 0, 0))
    X[0] += width + 1.0
    return base


# ================================================================ SHOWERS
# RainShower: a wall-mounted shower column (back on the wall): a thermostatic bar with two knobs, a riser
# with a wall bracket, an arm and a square rain head (1.4 across, 2.1 out from the wall, 4.6 tall).
o = slot(1.6)


def shower_metal(bm):
    H.cylinder(bm, o + Vector((0, -0.2, 0.55)), 0.1, 1.0, "X", 20)  # thermostatic bar
    for sx in (-0.56, 0.56):
        H.cylinder(bm, o + Vector((sx, -0.2, 0.55)), 0.14, 0.14, "X", 20)  # knobs
    for sx in (-0.4, 0.4):
        H.cylinder(bm, o + Vector((sx, -0.06, 0.55)), 0.09, 0.12, "Y", 16)  # wall unions
    H.cylinder(bm, o + Vector((0, -0.2, 2.6)), 0.06, 4.0, "Z", 16)  # riser
    H.cylinder(bm, o + Vector((0, -0.11, 3.7)), 0.04, 0.2, "Y", 10)  # bracket
    H.cylinder(bm, o + Vector((0, -0.02, 3.7)), 0.1, 0.04, "Y", 16)
    H.sphere(bm, o + Vector((0, -0.2, 4.6)), 0.075, (1, 1, 1), 12, 6)  # elbow
    H.cylinder(bm, o + Vector((0, -0.85, 4.6)), 0.05, 1.3, "Y", 12)  # arm


part("RainShower", "Metal", shower_metal)
part("RainShower", "Head", lambda bm: H.rounded_box(bm, o + Vector((0, -1.4, 4.5)), (1.4, 1.4, 0.1), 0.03, 2))
part("RainShower", "Dark", lambda bm: H.span(bm, o + Vector((-0.6, -2.0, 4.43)), o + Vector((0.6, -0.8, 4.45))),
     smooth=False)

# ShowerGel: a pump bottle (0.42 x 1.0) with a white label saying CENTRAL / BODY WASH.
o = slot(0.5)
part("ShowerGel", "Body", lambda bm: H.lathe_z(bm, [(0, 0), (0.2, 0), (0.21, 0.04), (0.21, 0.62), (0.17, 0.7),
                                                   (0.08, 0.74), (0, 0.74)], 28, o))
part("ShowerGel", "Pump", lambda bm: (H.cylinder(bm, o + Vector((0, 0, 0.78)), 0.09, 0.08, "Z", 16),
                                      H.cylinder(bm, o + Vector((0, 0, 0.88)), 0.03, 0.14, "Z", 10),
                                      H.rounded_box(bm, o + Vector((0, -0.07, 0.97)), (0.12, 0.3, 0.08), 0.03, 2)))
part("ShowerGel", "Label", lambda bm: H.lathe_z(bm, [(0.2, 0.14), (0.214, 0.14), (0.214, 0.56), (0.2, 0.56)], 28, o))
text_piece("ShowerGel", [(BRAND, 0.075, H.on_cylinder(o, 0.214, 0.4)), ("BODY WASH", 0.045, H.on_cylinder(o, 0.214, 0.28))])

# Shampoo: an oval squeeze bottle (0.48 x 0.26 x 0.95) with a flip cap, CENTRAL / SHAMPOO on its label.
o = slot(0.5)
part("Shampoo", "Body", lambda bm: H.rounded_box(bm, o + Vector((0, 0, 0.42)), (0.48, 0.26, 0.84), 0.1, 3))
part("Shampoo", "Cap", lambda bm: H.rounded_box(bm, o + Vector((0, 0, 0.9)), (0.3, 0.2, 0.14), 0.05, 2))
part("Shampoo", "Label", lambda bm: H.span(bm, o + Vector((-0.19, -0.135, 0.18)), o + Vector((0.19, -0.128, 0.62))),
     smooth=False)
text_piece("Shampoo", [(BRAND, 0.07, H.on_front(o, -0.135, 0.46)), ("SHAMPOO", 0.045, H.on_front(o, -0.135, 0.34))])

# Towel: a folded towel (1.5 x 1.0 x 0.26) with a stripe across; RoomProps stacks them.
o = slot(1.5)
part("Towel", "Body", lambda bm: H.rounded_box(bm, o + Vector((0, 0, 0.13)), (1.5, 1.0, 0.26), 0.1, 3))
part("Towel", "Stripe", lambda bm: H.rounded_box(bm, o + Vector((0, -0.28, 0.13)), (1.52, 0.14, 0.272), 0.1, 3))

# HangingTowel: a towel hung over a chrome rail on two wall brackets (back on the wall), 1.9 wide, 2.4 tall.
o = slot(1.9)
TOWEL_PATH = [(-0.56, 0.2)] + [(-0.56, 0.2 + 2.05 * k / 6) for k in range(1, 7)] + \
             [(-0.45 - 0.11 * math.cos(math.pi * k / 6), 2.25 + 0.11 * math.sin(math.pi * k / 6)) for k in range(1, 6)] + \
             [(-0.34, 2.25 - 1.3 * k / 4) for k in range(5)]
part("HangingTowel", "Body", lambda bm: sheet(bm, TOWEL_PATH, 1.5, 0.04, 0.025))
part("HangingTowel", "Stripe", lambda bm: sheet(bm, [(-0.6, 0.42), (-0.6, 0.58)], 1.52, 0.035, 0.025))


def towel_rail(bm):
    H.cylinder(bm, o + Vector((0, -0.45, 2.25)), 0.05, 1.9, "X", 12)
    for sx in (-0.9, 0.9):
        H.cylinder(bm, o + Vector((sx, -0.23, 2.25)), 0.04, 0.44, "Y", 10)
        H.cylinder(bm, o + Vector((sx, -0.02, 2.25)), 0.1, 0.04, "Y", 16)


part("HangingTowel", "Metal", towel_rail)

# SoapDispenser: a wall dispenser (0.6 x 0.35 x 0.95; back on the wall) with a level window and a push pad.
o = slot(0.6)
part("SoapDispenser", "Body", lambda bm: H.rounded_box(bm, o + Vector((0, -0.175, 0.475)), (0.6, 0.35, 0.95), 0.08))
part("SoapDispenser", "Window", lambda bm: H.span(bm, o + Vector((-0.06, -0.36, 0.3)), o + Vector((0.06, -0.345, 0.62))),
     smooth=False)
part("SoapDispenser", "Button", lambda bm: H.rounded_box(bm, o + Vector((0, -0.36, 0.12)), (0.36, 0.06, 0.16), 0.03, 2))
text_piece("SoapDispenser", [(BRAND, 0.08, H.on_front(o, -0.352, 0.78))])

# TowelBin: a round laundry basket (1.7 across, 2.2 tall) of used towels, "USED TOWELS" on the front.
o = slot(1.8)
part("TowelBin", "Body", lambda bm: H.lathe_z(bm, [(0, 0), (0.7, 0), (0.84, 2.15), (0.78, 2.15), (0.65, 0.08),
                                                  (0, 0.08)], 36, o))
part("TowelBin", "Rim", lambda bm: H.torus(bm, o + Vector((0, 0, 2.17)), 0.81, 0.06, "XY", 36, 8))
part("TowelBin", "Fill", lambda bm: [H.sphere(bm, o + Vector((x, y, 2.05)), 0.38, (1, 1, 0.55), 12, 6)
                                      for x, y in ((-0.3, -0.2), (0.3, -0.15), (0, 0.32), (0.05, -0.05))])
text_piece("TowelBin", [("USED TOWELS", 0.13, H.on_cylinder(o, 0.79, 1.4)), (BRAND, 0.09, H.on_cylinder(o, 0.785, 1.2))])

# Slides: a pair of pool slides (1.2 long), CENTRAL on each strap; RoomProps puts them under benches.
o = slot(1.3)
SLIDES = ((-0.32, 0.12), (0.32, -0.08))  # each slide's x and its slight turn


def slides(piece):
    def build(bm):
        for sx, turn in SLIDES:
            rot = Matrix.Rotation(turn, 4, "Z")
            if piece == "Sole":
                H.rounded_box(bm, o + Vector((sx, 0, 0.06)), (0.5, 1.15, 0.12), 0.05, 2, rot)
            else:
                H.rounded_box(bm, o + Vector((sx, 0, 0.0)) + rot.to_3x3() @ Vector((0, -0.18, 0.2)), (0.54, 0.44, 0.17),
                              0.07, 2, rot)
    return build


part("Slides", "Sole", slides("Sole"))
part("Slides", "Strap", slides("Strap"))
text_piece("Slides", [(BRAND, 0.07, lambda x, up, depth, sx=sx, turn=turn:
                       o + Vector((sx, 0, 0)) + Matrix.Rotation(turn, 3, "Z") @ Vector((x, -0.405 - depth, 0.2 + up)))
                      for sx, turn in SLIDES])

# ================================================================ RECOVERY
# ColdPlunge: a round cold plunge tub (4.7 across, 3 tall) with hoops, a rim, water and floating ice.
o = slot(4.8)
part("ColdPlunge", "Body", lambda bm: H.lathe_z(bm, [(0, 0), (2.2, 0), (2.35, 1.45), (2.25, 2.9), (2.0, 2.9), (2.0, 0.25),
                                                    (0, 0.25)], 48, o))
part("ColdPlunge", "Band", lambda bm: (H.lathe_z(bm, [(2.25, 0.5), (2.31, 0.5), (2.31, 0.7), (2.25, 0.7)], 48, o),
                                       H.lathe_z(bm, [(2.28, 2.2), (2.34, 2.2), (2.34, 2.4), (2.28, 2.4)], 48, o)))
part("ColdPlunge", "Rim", lambda bm: H.torus(bm, o + Vector((0, 0, 2.93)), 2.13, 0.15, "XY", 48, 8))
part("ColdPlunge", "Water", lambda bm: H.cylinder(bm, o + Vector((0, 0, 2.38)), 2.0, 0.04, "Z", 48), smooth=False)
ICE = [(0.6, -0.4, 0.3), (-0.8, 0.3, 1.1), (0.1, 0.9, 2.0), (-0.3, -1.1, 0.7), (1.2, 0.5, 1.6), (-1.3, -0.4, 2.4),
       (0.9, -1.1, 0.2), (-0.5, 1.3, 1.3)]
part("ColdPlunge", "Ice", lambda bm: [H.box(bm, o + Vector((x, y, 2.42)), (0.32, 0.32, 0.2), Matrix.Rotation(r, 4, "Z"))
                                      for x, y, r in ICE], smooth=False)

# FoamRoller: a ridged foam roller (2.6 long, 0.72 across) with a hollow core, lying on the floor.
o = slot(2.6)
RIDGES = [(0.15, -1.3), (0.34, -1.3)] + [(0.34 if k % 2 == 0 else 0.37, -1.2 + k * 0.2) for k in range(13)] + \
         [(0.34, 1.3), (0.15, 1.3)]
part("FoamRoller", "Body", lambda bm: lathe_x(bm, RIDGES, 28, o + Vector((0, 0, 0.37))))
part("FoamRoller", "Core", lambda bm: lathe_x(bm, [(0, -1.29), (0.152, -1.29), (0.152, 1.29), (0, 1.29)], 20,
                                              o + Vector((0, 0, 0.37))))

# Lounger: a zero-gravity recovery lounger (2.6 x 6.4), feet raised toward -Y, head up toward +Y.
o = slot(2.8)


def smooth_path(points, steps=4):
    """Catmull-Rom through (y, z) points."""
    out = []
    pts = [points[0]] + points + [points[-1]]
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = (Vector(p) for p in pts[i - 1:i + 3])
        for s in range(steps):
            t = s / steps
            out.append(0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(Vector(points[-1]))
    return out


LOUNGE = smooth_path([(-3.0, 2.35), (-1.7, 2.05), (-0.3, 1.55), (0.6, 1.5), (1.9, 2.5), (3.0, 3.55)])


def lounge_normals(path):
    normals = []
    for i, p in enumerate(path):
        a, b = path[max(i - 1, 0)], path[min(i + 1, len(path) - 1)]
        t = (b - a).normalized()
        normals.append(Vector((-t.y, t.x)))
    return normals


def lounger_pad(bm):
    tmp = bmesh.new()
    normals = lounge_normals(LOUNGE)
    rings = []
    for p, n in zip(LOUNGE, normals):
        ring = []
        for x, h in ((-1.1, 0), (1.1, 0), (1.1, 0.38), (-1.1, 0.38)):
            q = p + n * h
            ring.append(tmp.verts.new(o + Vector((x, q.x, q.y))))
        rings.append(ring)
    for j in range(len(rings) - 1):
        for k in range(4):
            tmp.faces.new((rings[j][k], rings[j][(k + 1) % 4], rings[j + 1][(k + 1) % 4], rings[j + 1][k]))
    tmp.faces.new(rings[0][::-1])
    tmp.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)


def lounger_frame(bm):
    normals = lounge_normals(LOUNGE)
    for sx in (-1.18, 1.18):
        pts = [o + Vector((sx, (p - n * 0.1).x, (p - n * 0.1).y)) for p, n in zip(LOUNGE, normals)]
        for a, b in zip(pts, pts[1:]):
            tube(bm, a, b, 0.07, 8)
        for top, foot in (((-1.7, 1.95), (-2.5, 0.0)), ((-1.7, 1.95), (-0.6, 0.0)), ((1.6, 2.15), (0.9, 0.0)),
                          ((1.6, 2.15), (2.4, 0.0))):
            tube(bm, o + Vector((sx, top[0], top[1])), o + Vector((sx, foot[0], foot[1] + 0.07)), 0.07, 8)
    for y in (-2.5, -0.6, 0.9, 2.4):
        tube(bm, o + Vector((-1.18, y, 0.07)), o + Vector((1.18, y, 0.07)), 0.06, 8)


part("Lounger", "Pad", lounger_pad, smooth=False)
part("Lounger", "Frame", lounger_frame)
part("Lounger", "Pillow", lambda bm: H.rounded_box(bm, o + Vector((0, 2.65, 3.45)), (1.5, 0.6, 0.38), 0.15, 3,
                                                   Matrix.Rotation(math.radians(48), 4, "X")))

# MassageGun: a percussion massage gun (0.95 long, 1.1 tall) standing on its battery, CENTRAL on its side.
o = slot(1.0)
part("MassageGun", "Body", lambda bm: (H.cylinder(bm, o + Vector((0, 0, 0.98)), 0.15, 0.64, "X", 24),
                                       H.sphere(bm, o + Vector((0.32, 0, 0.98)), 0.15, (0.4, 1, 1), 16, 8)))
part("MassageGun", "Grip", lambda bm: (H.rounded_box(bm, o + Vector((0.08, 0, 0.5)), (0.2, 0.24, 0.8), 0.07, 3,
                                                     Matrix.Rotation(math.radians(-12), 4, "Y")),
                                       H.rounded_box(bm, o + Vector((0.0, 0, 0.08)), (0.34, 0.32, 0.16), 0.05, 2)))
part("MassageGun", "Head", lambda bm: (H.cylinder(bm, o + Vector((-0.4, 0, 0.98)), 0.05, 0.2, "X", 12),
                                       H.sphere(bm, o + Vector((-0.55, 0, 0.98)), 0.12, (1, 1, 1), 16, 8)))
text_piece("MassageGun", [(BRAND, 0.075, H.on_front(o, -0.15, 0.98))])

# YogaMat: a rolled yoga mat (2.4 long, 0.6 across) with two straps, lying on its side.
o = slot(2.4)
part("YogaMat", "Body", lambda bm: H.cylinder(bm, o + Vector((0, 0, 0.3)), 0.3, 2.4, "X", 24))
part("YogaMat", "Strap", lambda bm: [H.torus(bm, o + Vector((sx, 0, 0.3)), 0.3, 0.03, "YZ", 24, 6) for sx in (-0.7, 0.7)])

# ================================================================ MASSAGE
# MassageTable: a padded massage table (3.0 x 9.7, top at 3.3) with a face cradle at the head (+Y), a
# bolster at the feet, a towel draped across, an oak apron, legs and a slatted shelf.
o = slot(3.4)


def table_pad(bm):
    H.rounded_box(bm, o + Vector((0, 0, 3.09)), (3.0, 8.0, 0.42), 0.12, 3)
    H.torus(bm, o + Vector((0, 4.75, 3.12)), 0.55, 0.17, "XY", 28, 8, 1.6 * math.pi, 0.7 * math.pi)


def table_frame(bm):
    for sx in (-1.35, 1.35):
        H.span(bm, o + Vector((sx - 0.06, -3.7, 2.48)), o + Vector((sx + 0.06, 3.7, 2.88)))
    for sy in (-3.7, 3.7):
        H.span(bm, o + Vector((-1.35, sy - 0.06, 2.48)), o + Vector((1.35, sy + 0.06, 2.88)))
    for k in range(5):
        y = -2.6 + k * 1.3
        H.span(bm, o + Vector((-1.15, y - 0.25, 0.75)), o + Vector((1.15, y + 0.25, 0.85)))
    for sx in (-0.3, 0.3):  # face-cradle struts
        H.span(bm, o + Vector((sx - 0.05, 3.7, 2.9)), o + Vector((sx + 0.05, 4.35, 3.0)))


def table_legs(bm):
    for sx in (-1.15, 1.15):
        for sy in (-3.3, 3.3):
            H.cylinder(bm, o + Vector((sx, sy, 1.24)), 0.11, 2.48, "Z", 12, 0.15)
        H.span(bm, o + Vector((sx - 0.05, -3.3, 0.75)), o + Vector((sx + 0.05, 3.3, 0.85)))


part("MassageTable", "Pad", table_pad)
part("MassageTable", "Frame", table_frame, smooth=False)
part("MassageTable", "Legs", table_legs)
part("MassageTable", "Bolster", lambda bm: H.cylinder(bm, o + Vector((0, -3.1, 3.62)), 0.33, 2.6, "X", 24))
part("MassageTable", "Towel", lambda bm: (H.rounded_box(bm, o + Vector((0, 0.4, 3.33)), (3.1, 2.6, 0.06), 0.03, 1),
                                          [H.rounded_box(bm, o + Vector((sx, 0.4, 2.98)), (0.06, 2.6, 0.75), 0.03, 1)
                                           for sx in (-1.55, 1.55)]), smooth=False)

# OilBottle: a small dropper bottle of massage oil (0.27 x 0.73), CENTRAL on a cream label.
o = slot(0.35)
part("OilBottle", "Body", lambda bm: H.lathe_z(bm, [(0, 0), (0.13, 0), (0.135, 0.02), (0.135, 0.36), (0.1, 0.42),
                                                   (0.05, 0.45), (0.05, 0.5), (0, 0.5)], 24, o))
part("OilBottle", "Cap", lambda bm: (H.cylinder(bm, o + Vector((0, 0, 0.54)), 0.065, 0.08, "Z", 16),
                                     H.sphere(bm, o + Vector((0, 0, 0.64)), 0.055, (1, 1, 1.6), 12, 6)))
part("OilBottle", "Label", lambda bm: H.lathe_z(bm, [(0.13, 0.08), (0.139, 0.08), (0.139, 0.3), (0.13, 0.3)], 24, o))
text_piece("OilBottle", [(BRAND, 0.05, H.on_cylinder(o, 0.139, 0.19))])

# CandleSet: three pillar candles of different heights on a tray (1.3 x 0.6), their flames glowing.
o = slot(1.3)
CANDLES = ((-0.42, 0.45), (0.0, 0.85), (0.42, 0.62))
part("CandleSet", "Tray", lambda bm: H.rounded_box(bm, o + Vector((0, 0, 0.03)), (1.3, 0.6, 0.06), 0.025, 2))
part("CandleSet", "Wax", lambda bm: [H.cylinder(bm, o + Vector((x, 0, 0.06 + h / 2)), 0.17, h, "Z", 20) for x, h in CANDLES])
part("CandleSet", "Flame", lambda bm: [H.sphere(bm, o + Vector((x, 0, 0.06 + h + 0.1)), 0.045, (1, 1, 2.2), 10, 6)
                                       for x, h in CANDLES])

# Diffuser: an aroma diffuser (0.64 across, 0.95 tall): a ceramic teardrop on a wooden base, a warm glow ring.
o = slot(0.7)
part("Diffuser", "Base", lambda bm: H.cylinder(bm, o + Vector((0, 0, 0.08)), 0.32, 0.16, "Z", 28))
part("Diffuser", "Light", lambda bm: H.torus(bm, o + Vector((0, 0, 0.17)), 0.27, 0.02, "XY", 28, 6))
part("Diffuser", "Body", lambda bm: H.lathe_z(bm, [(0, 0.16), (0.27, 0.16), (0.3, 0.32), (0.25, 0.6), (0.12, 0.85),
                                                   (0.05, 0.93), (0, 0.94)], 28, o))

# SpaStones: a stack of four smooth stones (1.0 across, 0.95 tall).
o = slot(1.0)
part("SpaStones", "Stone", lambda bm: [H.sphere(bm, o + Vector((dx, 0, z)), r, (1, 0.85, 0.42), 20, 10)
                                       for dx, z, r in ((0, 0.21, 0.5), (0.04, 0.53, 0.38), (-0.03, 0.76, 0.28),
                                                        (0.02, 0.92, 0.19))])

# Pouf: a round fabric pouf seat (1.9 across, 1.6 tall) with piping round the top and bottom.
o = slot(1.9)
part("Pouf", "Body", lambda bm: H.lathe_z(bm, [(0, 0), (0.85, 0), (0.95, 0.25), (0.95, 1.35), (0.85, 1.56),
                                               (0, 1.6)], 36, o))
part("Pouf", "Piping", lambda bm: [H.torus(bm, o + Vector((0, 0, z)), 0.95, 0.045, "XY", 36, 6) for z in (0.25, 1.35)])

# FoldingScreen: a three-panel folding screen (5.5 wide, 6.4 tall) in a zig-zag, oak frames round cloth panels.
o = slot(5.6)
SCREEN = []
p = Vector((-2.72, -0.42, 0))
for k, angle in enumerate((25, -25, 25)):
    d = Vector((math.cos(math.radians(angle)), math.sin(math.radians(angle)), 0))
    SCREEN.append((p.copy(), p + d * 2.0, math.radians(angle)))
    p = p + d * 2.0


def screen_frame(bm):
    for a, b, angle in SCREEN:
        rot = Matrix.Rotation(angle, 4, "Z")
        mid = (a + b) / 2
        for end in (a, b):
            post = end + (mid - end).normalized() * 0.07
            H.box(bm, o + post + Vector((0, 0, 3.2)), (0.12, 0.12, 6.4), rot)
        for z in (0.45, 6.25):
            H.box(bm, o + mid + Vector((0, 0, z)), (1.8, 0.1, 0.14), rot)


part("FoldingScreen", "Frame", screen_frame, smooth=False)
part("FoldingScreen", "Panel", lambda bm: [H.box(bm, o + (a + b) / 2 + Vector((0, 0, 3.35)), (1.78, 0.04, 5.66),
                                                 Matrix.Rotation(angle, 4, "Z")) for a, b, angle in SCREEN],
     smooth=False)

print("RoomProps_03 built:", len(B.coll.objects), "objects:", sorted({ob.name.split("_")[0] for ob in B.coll.objects}))
