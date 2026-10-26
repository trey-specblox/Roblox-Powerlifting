# Builds RoomProps_02 in the live Blender scene: the 3D props for the Lockers, the Cafe and the Staff
# Room (user-approved 2026-10-25, GAME_DESIGN §27 "Room purposes"; "variety, not just red and black").
# Every gear / product label says CENTRAL (user's rule), never a real brand.
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, each item stands on z = 0 with its
# front toward -Y, objects are "<Item>_<Piece>" with ONE material each. Roblox recolours every piece
# from StarterGymConfig.PropColourways (COLOURWAYS below is the list to copy there; the first
# colourway is also what this file shows).
#
# Run in an otherwise empty file (art/blender/RoomProps_02.blend):
#   exec(compile(open(path).read(), path, "exec"), {"__file__": path})
# Objects are replaced by name on every run.

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

B = H.Builder("RoomProps_02")
BRAND = H.BRAND

# Colour names as Roblox shows them (the same names go into StarterGymConfig.PropPaints).
PAINT = {
    "Black": (0.02, 0.02, 0.022), "Charcoal": (0.05, 0.05, 0.055), "White": (0.85, 0.85, 0.83),
    "LightGrey": (0.45, 0.47, 0.5), "Navy": (0.02, 0.05, 0.2), "Sage": (0.3, 0.42, 0.3), "Oak": (0.55, 0.36, 0.18),
    "Red": (0.55, 0.015, 0.025), "Pink": (0.85, 0.2, 0.45), "Teal": (0.0, 0.3, 0.3), "Mustard": (0.7, 0.45, 0.03),
    "Terracotta": (0.55, 0.16, 0.07), "Forest": (0.03, 0.18, 0.08), "Cream": (0.8, 0.72, 0.55),
    "Mint": (0.45, 0.75, 0.6), "Kraft": (0.5, 0.33, 0.17), "Coffee": (0.12, 0.05, 0.02), "Brass": (0.7, 0.5, 0.2),
    "Silver": (0.6, 0.62, 0.65), "Chocolate": (0.15, 0.06, 0.03), "Dough": (0.75, 0.48, 0.2),
    "Blue": (0.02, 0.12, 0.55), "Yellow": (0.85, 0.62, 0.02), "Orange": (0.9, 0.3, 0.02), "Purple": (0.3, 0.04, 0.55),
    "Green": (0.2, 0.7, 0.05), "Glass": (0.7, 0.8, 0.85), "WaterBlue": (0.4, 0.65, 0.85), "Mirror": (0.75, 0.78, 0.8),
    "WarmGlow": (1.0, 0.75, 0.45), "Lavender": (0.5, 0.42, 0.75),
}
METAL = {"Silver", "Brass", "Mirror"}
MAT = {}
for colour, rgb in PAINT.items():
    MAT[colour] = H.material("RP_" + colour, rgb, 1.0 if colour in METAL else 0.0,
                             0.15 if colour == "Mirror" else 0.5,
                             0.35 if colour in ("Glass", "WaterBlue") else 1.0,
                             rgb if colour == "WarmGlow" else None)

# Per item: a list of colourways, each piece -> colour name. Pieces not named keep the file's look.
COLOURWAYS = {
    # Lockers
    "Locker": [{"Door": d, "Frame": "Charcoal", "Metal": "Silver", "Dark": "Black"}
               for d in ("Navy", "Sage", "Oak", "LightGrey")],
    "LockerBench": [{"Seat": "Oak", "Metal": "Black"}],
    "GymBag": [{"Body": "Black", "Trim": "Red", "Text": "White"}, {"Body": "Navy", "Trim": "White", "Text": "White"},
               {"Body": "Pink", "Trim": "Black", "Text": "Black"}, {"Body": "LightGrey", "Trim": "Teal", "Text": "Black"},
               {"Body": "Mustard", "Trim": "Black", "Text": "Black"}],
    "WaterBottle": [{"Body": "Blue", "Cap": "Black", "Text": "White"}, {"Body": "Pink", "Cap": "White", "Text": "White"},
                    {"Body": "Teal", "Cap": "Black", "Text": "White"}, {"Body": "Orange", "Cap": "Black", "Text": "Black"}],
    "RoundMirror": [{"Glass": "Mirror", "Glow": "WarmGlow"}],
    "Sink": [{"Bowl": "White", "Metal": "Silver"}],
    "Curtain": [{"Cloth": c, "Metal": "Silver"} for c in ("Teal", "Mustard", "Terracotta")],
    # Cafe
    "Espresso": [{"Body": "Silver", "Panel": "Black", "Metal": "Silver", "Text": "White"},
                 {"Body": "Mint", "Panel": "Cream", "Metal": "Silver", "Text": "Black"}],
    "Grinder": [{"Body": "Black", "Hopper": "Glass", "Beans": "Coffee", "Metal": "Silver"}],
    "CoffeeCup": [{"Body": "White", "Lid": "Black", "Label": l, "Text": t}
                  for l, t in (("Kraft", "White"), ("Forest", "White"), ("Terracotta", "White"), ("Black", "White"))],
    "Mug": [{"Body": c, "Coffee": "Coffee"} for c in ("White", "Mint", "Mustard", "Terracotta", "Navy")],
    "PastryCase": [{"Base": "Oak", "Glass": "Glass", "Metal": "Brass"}],
    "Donut": [{"Dough": "Dough", "Icing": c} for c in ("Pink", "Chocolate", "White")],
    "Muffin": [{"Case": c, "Top": t} for c, t in (("Red", "Chocolate"), ("Teal", "Dough"), ("Mustard", "Chocolate"))],
    "Croissant": [{"Dough": "Dough"}],
    "CafeChair": [{"Shell": c, "Legs": l} for c, l in (("Mustard", "Oak"), ("Teal", "Oak"), ("Terracotta", "Black"),
                                                       ("White", "Oak"))],
    "Booth": [{"Frame": "Oak", "Cushion": "Forest"}, {"Frame": "Black", "Cushion": "Mustard"},
              {"Frame": "Oak", "Cushion": "Terracotta"}],
    "PendantLamp": [{"Shade": c, "Bulb": "WarmGlow"} for c in ("Brass", "Black", "Sage", "Terracotta")],
    "CoffeeBag": [{"Body": b, "Label": "Cream", "Text": "Black"} for b in ("Black", "Kraft", "Forest", "Terracotta")],
    # Staff room
    "Sofa": [{"Frame": c, "Cushion": c, "Legs": "Oak"} for c in ("Teal", "Mustard", "LightGrey")],
    "Microwave": [{"Body": "White", "Door": "Black", "Panel": "Black", "Metal": "Silver"},
                  {"Body": "Silver", "Door": "Black", "Panel": "Black", "Metal": "Silver"}],
    "Kettle": [{"Body": c, "Trim": t} for c, t in (("Cream", "Black"), ("Sage", "Silver"), ("Red", "Black"))],
    "WaterCooler": [{"Body": "White", "Bottle": "WaterBlue", "Tap": "Blue", "Dark": "Black"}],
    "Fridge": [{"Body": c, "Dark": "Charcoal", "Metal": "Silver"} for c in ("Mint", "Cream", "Lavender")],
    "StaffTee": [{"Body": b, "Text": t, "Metal": "Silver"} for b, t in (("Black", "White"), ("Red", "White"),
                                                                        ("Navy", "White"), ("White", "Black"))],
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


X = [0.0]  # the next item's X position along the shelf of items


def slot(width):
    """The base point of the next item, `width` studs wide."""
    base = Vector((X[0] + width / 2, 0, 0))
    X[0] += width + 1.0
    return base


# ================================================================ LOCKERS
# Locker: a full-height column of two lockers (2.4 x 1.7 x 7.4), coloured doors in a charcoal frame,
# vent slots, a bar handle and a keypad lock on each door.
o = slot(2.4)
W, D, HT = 2.4, 1.7, 7.4
FRONT = -D / 2


def locker_frame(bm):
    for sx in (-1, 1):
        H.span(bm, o + Vector((sx * W / 2 - (0.08 if sx > 0 else 0), -D / 2, 0)),
               o + Vector((sx * W / 2 + (0 if sx > 0 else 0.08), D / 2, HT)))
    H.span(bm, o + Vector((-W / 2, -D / 2, HT - 0.1)), o + Vector((W / 2, D / 2, HT)))  # top
    H.span(bm, o + Vector((-W / 2, -D / 2 + 0.06, 0)), o + Vector((W / 2, D / 2, 0.3)))  # plinth
    H.span(bm, o + Vector((-W / 2, FRONT, 3.78)), o + Vector((W / 2, FRONT + 0.1, 3.92)))  # middle rail
    H.span(bm, o + Vector((-W / 2, D / 2 - 0.05, 0)), o + Vector((W / 2, D / 2, HT)))  # back


part("Locker", "Frame", locker_frame, smooth=False)
DOORS = ((0.32, 3.76), (3.94, HT - 0.12))


def locker_doors(bm):
    for z0, z1 in DOORS:
        H.rounded_box(bm, o + Vector((0, FRONT - 0.01, (z0 + z1) / 2)), (W - 0.2, 0.07, z1 - z0), 0.02, 2)


part("Locker", "Door", locker_doors, smooth=False)


def locker_dark(bm):
    for z0, z1 in DOORS:
        for k in range(4):  # vent slots near the top of each door
            z = z1 - 0.35 - k * 0.16
            H.span(bm, o + Vector((-0.6, FRONT - 0.06, z)), o + Vector((0.6, FRONT - 0.04, z + 0.07)))
        H.rounded_box(bm, o + Vector((0.72, FRONT - 0.07, z0 + (z1 - z0) * 0.45)), (0.3, 0.05, 0.42), 0.02, 2)


part("Locker", "Dark", locker_dark, smooth=False)


def locker_metal(bm):
    for z0, z1 in DOORS:
        zm = z0 + (z1 - z0) * 0.45
        H.cylinder(bm, o + Vector((0.95, FRONT - 0.17, zm)), 0.035, 0.8, "Z", 12)  # bar handle
        for dz in (-0.35, 0.35):
            H.cylinder(bm, o + Vector((0.95, FRONT - 0.1, zm + dz)), 0.03, 0.14, "Y", 10)
        H.rounded_box(bm, o + Vector((0.72, FRONT - 0.1, zm + 0.05)), (0.18, 0.02, 0.12), 0.01, 1)  # keypad screen


part("Locker", "Metal", locker_metal)

# LockerBench: an oak slab on two black steel frames (8 x 1.6, seat top at 1.8).
o = slot(8)


def bench_seat(bm):
    H.rounded_box(bm, o + Vector((0, 0, 1.675)), (8, 1.6, 0.25), 0.06)


def bench_metal(bm):
    for sx in (-3.3, 3.3):
        for sy in (-0.6, 0.6):
            H.span(bm, o + Vector((sx - 0.07, sy - 0.07, 0.08)), o + Vector((sx + 0.07, sy + 0.07, 1.47)))
        H.span(bm, o + Vector((sx - 0.08, -0.72, 0)), o + Vector((sx + 0.08, 0.72, 0.1)))
        H.span(bm, o + Vector((sx - 0.08, -0.72, 1.45)), o + Vector((sx + 0.08, 0.72, 1.55)))


part("LockerBench", "Seat", bench_seat)
part("LockerBench", "Metal", bench_metal, smooth=False)

# GymBag: a duffel bag (2.1 x 0.95 x 0.95) with end panels, two straps and a carry handle, CENTRAL on the side.
o = slot(2.2)


def bag_body(bm):
    H.rounded_box(bm, o + Vector((0, 0, 0.45)), (2.0, 0.95, 0.9), 0.32, 4)


def bag_trim(bm):
    for sx in (-1, 1):
        H.rounded_box(bm, o + Vector((sx * 1.0, 0, 0.45)), (0.06, 0.8, 0.75), 0.2, 3)
    for sx in (-0.75, 0.75):
        H.rounded_box(bm, o + Vector((sx, 0, 0.45)), (0.14, 0.99, 0.94), 0.33, 4)
    H.torus(bm, o + Vector((0, 0, 0.88)), 0.75, 0.045, "XZ", 24, 8, math.pi, 0)


part("GymBag", "Body", bag_body)
part("GymBag", "Trim", bag_trim)
text_piece("GymBag", [(BRAND, 0.2, H.on_front(o, -0.476, 0.45))])

# WaterBottle: a sports bottle (0.38 x 0.85) with a flip cap.
o = slot(0.4)
part("WaterBottle", "Body", lambda bm: H.lathe_z(bm, [(0, 0), (0.17, 0), (0.185, 0.03), (0.19, 0.6), (0.16, 0.68),
                                                    (0.13, 0.7), (0, 0.7)], 32, o))
part("WaterBottle", "Cap", lambda bm: (H.lathe_z(bm, [(0, 0.69), (0.14, 0.69), (0.145, 0.8), (0.09, 0.84), (0, 0.84)],
                                                 24, o), H.box(bm, o + Vector((0, -0.1, 0.86)), (0.05, 0.08, 0.06))))
text_piece("WaterBottle", [(BRAND, 0.075, H.on_cylinder(o, 0.192, 0.35))])

# RoundMirror: a round mirror (3.2 across) standing upright, a warm glowing ring behind it.
o = slot(3.4)
part("RoundMirror", "Glass", lambda bm: H.cylinder(bm, o + Vector((0, -0.08, 1.6)), 1.5, 0.05, "Y", 48))
part("RoundMirror", "Glow", lambda bm: H.cylinder(bm, o + Vector((0, 0, 1.6)), 1.62, 0.08, "Y", 48))

# Sink: a white vessel basin with a tall chrome tap behind it (sits on a counter).
o = slot(1.5)
part("Sink", "Bowl", lambda bm: H.lathe_z(bm, [(0, 0), (0.4, 0), (0.62, 0.15), (0.7, 0.42), (0.64, 0.42),
                                               (0.56, 0.18), (0, 0.12)], 40, o))


def sink_metal(bm):
    H.cylinder(bm, o + Vector((0, 0.75, 0.45)), 0.06, 0.9, "Z", 16)
    H.cylinder(bm, o + Vector((0, 0.5, 0.88)), 0.05, 0.5, "Y", 16)
    H.cylinder(bm, o + Vector((0, 0.75, 0.02)), 0.12, 0.04, "Z", 16)


part("Sink", "Metal", sink_metal)

# Curtain: a changing-cubicle curtain (4 x 6.6), folded in soft waves, on a chrome rail with rings.
o = slot(4.2)


def curtain_cloth(bm):
    import bmesh
    tmp = bmesh.new()
    cols, rows = 40, 6
    grid = []
    for j in range(rows + 1):
        z = 0.35 + (6.3 - 0.35) * j / rows
        row = []
        for i in range(cols + 1):
            x = -2 + 4 * i / cols
            row.append(tmp.verts.new(o + Vector((x, 0.12 * math.sin(i * math.pi / 2.5), z))))
        grid.append(row)
    for j in range(rows):
        for i in range(cols):
            tmp.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    bmesh.ops.solidify(tmp, geom=tmp.faces[:], thickness=0.04)
    H._merge(bm, tmp)


def curtain_metal(bm):
    H.cylinder(bm, o + Vector((0, 0, 6.55)), 0.05, 4.2, "X", 12)
    for k in range(9):
        H.torus(bm, o + Vector((-1.9 + k * 0.475, 0, 6.55)), 0.09, 0.02, "YZ", 12, 6)


part("Curtain", "Cloth", curtain_cloth)
part("Curtain", "Metal", curtain_metal)

# ================================================================ CAFE
# Espresso: a two-group espresso machine (2.4 x 1.4 x 1.45) with a front panel saying CENTRAL, drip
# tray, portafilters, steam wand and a cup rail on top. Sits on a counter.
o = slot(2.4)
part("Espresso", "Body", lambda bm: H.rounded_box(bm, o + Vector((0, 0.05, 0.72)), (2.4, 1.3, 1.25), 0.08))
part("Espresso", "Panel", lambda bm: H.rounded_box(bm, o + Vector((0, -0.6, 1.12)), (2.1, 0.04, 0.34), 0.015, 1),
     smooth=False)


def espresso_metal(bm):
    H.span(bm, o + Vector((-1.0, -0.9, 0.02)), o + Vector((1.0, -0.6, 0.12)))  # drip tray
    for sx in (-0.5, 0.5):
        H.cylinder(bm, o + Vector((sx, -0.72, 0.75)), 0.18, 0.22, "Z", 20)  # group head
        H.cylinder(bm, o + Vector((sx, -0.72, 0.6)), 0.15, 0.1, "Z", 20)  # portafilter basket
        H.span(bm, o + Vector((sx - 0.05, -1.25, 0.56)), o + Vector((sx + 0.05, -0.8, 0.64)))  # its handle
    H.cylinder(bm, o + Vector((1.05, -0.75, 0.6)), 0.03, 0.6, "Z", 10)  # steam wand
    for sy in (-0.5, 0.6):  # cup rail
        H.span(bm, o + Vector((-1.1, sy - 0.03, 1.35)), o + Vector((1.1, sy + 0.03, 1.45)))
    for sx in (-1.1, 1.1):
        H.span(bm, o + Vector((sx - 0.03, -0.5, 1.35)), o + Vector((sx + 0.03, 0.6, 1.45)))
    for sx in (-1.0, 1.0):
        for sy in (-0.45, 0.55):
            H.cylinder(bm, o + Vector((sx, sy, 0.04)), 0.07, 0.08, "Z", 10)  # feet


part("Espresso", "Metal", espresso_metal)
text_piece("Espresso", [(BRAND, 0.2, H.on_front(o, -0.62, 1.12))])

# Grinder: a coffee grinder (0.6 x 0.7 x 1.45) with a glass hopper of beans.
o = slot(0.7)
part("Grinder", "Body", lambda bm: H.rounded_box(bm, o + Vector((0, 0, 0.45)), (0.55, 0.65, 0.9), 0.06))
part("Grinder", "Hopper", lambda bm: H.lathe_z(bm, [(0.1, 0.9), (0.28, 1.35), (0.28, 1.45), (0, 1.45), (0, 0.9)], 24, o))
part("Grinder", "Beans", lambda bm: H.lathe_z(bm, [(0, 0.93), (0.11, 0.93), (0.24, 1.25), (0, 1.25)], 24, o))
part("Grinder", "Metal", lambda bm: (H.span(bm, o + Vector((-0.06, -0.45, 0.4)), o + Vector((0.06, -0.3, 0.6))),
                                     H.span(bm, o + Vector((-0.2, -0.45, 0.05)), o + Vector((0.2, -0.3, 0.1)))))

# CoffeeCup: a takeaway cup (0.36 x 0.6) with a lid and a coloured sleeve saying CENTRAL.
o = slot(0.4)
part("CoffeeCup", "Body", lambda bm: H.lathe_z(bm, [(0, 0), (0.13, 0), (0.17, 0.52), (0, 0.52)], 28, o))
part("CoffeeCup", "Lid", lambda bm: H.lathe_z(bm, [(0, 0.5), (0.18, 0.5), (0.18, 0.55), (0.15, 0.6), (0, 0.6)], 28, o))
part("CoffeeCup", "Label", lambda bm: H.lathe_z(bm, [(0.135, 0.14), (0.158, 0.14), (0.168, 0.4), (0.145, 0.4)], 28, o))
text_piece("CoffeeCup", [(BRAND, 0.06, H.on_cylinder(o, 0.165, 0.27))])

# Mug: a ceramic mug (0.36 x 0.4) with coffee in it and a handle.
o = slot(0.5)
part("Mug", "Body", lambda bm: (H.lathe_z(bm, [(0, 0), (0.17, 0), (0.18, 0.4), (0.15, 0.4), (0.15, 0.06), (0, 0.06)],
                                          28, o),
                                H.torus(bm, o + Vector((0.2, 0, 0.2)), 0.1, 0.025, "XZ", 14, 6, math.pi, -math.pi / 2)))
part("Mug", "Coffee", lambda bm: H.cylinder(bm, o + Vector((0, 0, 0.34)), 0.152, 0.02, "Z", 28))

# PastryCase: a glass counter display (3.6 x 1.6 x 1.5) on an oak base with a brass frame and one shelf.
o = slot(3.6)
part("PastryCase", "Base", lambda bm: H.rounded_box(bm, o + Vector((0, 0, 0.15)), (3.6, 1.6, 0.3), 0.04, 2))
part("PastryCase", "Glass", lambda bm: H.span(bm, o + Vector((-1.75, -0.75, 0.3)), o + Vector((1.75, 0.75, 1.48))),
     smooth=False)


def case_metal(bm):
    for sx in (-1.77, 1.77):
        for sy in (-0.77, 0.77):
            H.span(bm, o + Vector((sx - 0.03, sy - 0.03, 0.3)), o + Vector((sx + 0.03, sy + 0.03, 1.5)))
    for sy in (-0.77, 0.77):
        H.span(bm, o + Vector((-1.8, sy - 0.03, 1.47)), o + Vector((1.8, sy + 0.03, 1.53)))
    for sx in (-1.77, 1.77):
        H.span(bm, o + Vector((sx - 0.03, -0.8, 1.47)), o + Vector((sx + 0.03, 0.8, 1.53)))
    H.span(bm, o + Vector((-1.7, -0.7, 0.86)), o + Vector((1.7, 0.7, 0.89)))  # shelf


part("PastryCase", "Metal", case_metal, smooth=False)

# Pastries for the case: Donut, Muffin, Croissant (about 0.4 studs across).
o = slot(0.5)
part("Donut", "Dough", lambda bm: H.torus(bm, o + Vector((0, 0, 0.08)), 0.13, 0.08, "XY", 20, 10))
part("Donut", "Icing", lambda bm: H.torus(bm, o + Vector((0, 0, 0.105)), 0.13, 0.072, "XY", 20, 10))
o = slot(0.4)
part("Muffin", "Case", lambda bm: H.lathe_z(bm, [(0, 0), (0.12, 0), (0.16, 0.18), (0, 0.18)], 16, o), smooth=False)
part("Muffin", "Top", lambda bm: H.sphere(bm, o + Vector((0, 0, 0.2)), 0.19, (1, 1, 0.7), 16, 8))
o = slot(0.6)


def croissant(bm):
    for k in range(7):  # puffy segments along a crescent
        a = math.pi * (0.15 + 0.7 * k / 6)
        r = 0.09 if k in (0, 6) else (0.12 if k in (1, 5) else 0.14)
        H.sphere(bm, o + Vector((0.25 * math.cos(a), 0.25 * math.sin(a) - 0.12, r * 0.8)), r, (1, 1, 0.8), 12, 6)


part("Croissant", "Dough", croissant)

# CafeChair: a moulded shell chair (seat top 1.95) on four splayed legs; the sitter faces -Y.
o = slot(1.6)


def chair_shell(bm):
    H.rounded_box(bm, o + Vector((0, -0.05, 1.88)), (1.45, 1.35, 0.14), 0.06)
    tilt = Matrix.Rotation(math.radians(-10), 4, "X")
    H.rounded_box(bm, o + Vector((0, 0.68, 2.7)), (1.4, 0.12, 1.45), 0.06, 3, tilt)


def chair_legs(bm):
    import bmesh
    for sx in (-1, 1):
        for sy in (-1, 1):
            top = o + Vector((sx * 0.45, sy * 0.4, 1.8))
            foot = o + Vector((sx * 0.62, sy * 0.58, 0))
            mid, along = (top + foot) / 2, top - foot
            # a tapered leg made along Z, turned to run from the seat to the foot
            turn = Vector((0, 0, 1)).rotation_difference(along.normalized()).to_matrix().to_4x4()
            bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=10, radius1=0.04, radius2=0.065,
                                  depth=along.length, matrix=Matrix.Translation(mid) @ turn)


part("CafeChair", "Shell", chair_shell)
part("CafeChair", "Legs", chair_legs)

# Booth: a banquette sofa (10 x 2.4) for the brick wall: a frame with seat and back cushions.
o = slot(10)


def booth_frame(bm):
    H.span(bm, o + Vector((-5, -1.1, 0)), o + Vector((5, 0.9, 1.4)))
    H.span(bm, o + Vector((-5, 0.8, 0)), o + Vector((5, 1.2, 4.2)))
    for sx in (-5, 5):
        H.span(bm, o + Vector((sx - 0.15, -1.15, 0)), o + Vector((sx + 0.15, 1.2, 2.6)))


def booth_cushion(bm):
    H.rounded_box(bm, o + Vector((0, -0.1, 1.62)), (9.6, 1.95, 0.45), 0.15)
    tilt = Matrix.Rotation(math.radians(-8), 4, "X")
    for k in range(4):
        H.rounded_box(bm, o + Vector((-3.6 + k * 2.4, 0.55, 2.85)), (2.3, 0.42, 1.75), 0.18, 3, tilt)


part("Booth", "Frame", booth_frame, smooth=False)
part("Booth", "Cushion", booth_cushion)

# PendantLamp: a dome shade (1.5 across) with a warm bulb; RoomProps hangs it on a cable.
o = slot(1.6)
part("PendantLamp", "Shade", lambda bm: H.lathe_z(bm, [(0.75, 0.25), (0.72, 0.45), (0.55, 0.72), (0.12, 0.85),
                                                       (0.1, 0.95), (0, 0.95), (0, 0.8), (0.5, 0.66), (0.66, 0.42),
                                                       (0.69, 0.25)], 40, o))
part("PendantLamp", "Bulb", lambda bm: H.sphere(bm, o + Vector((0, 0, 0.42)), 0.2, (1, 1, 1), 16, 8))

# CoffeeBag: a stand-up bag of beans (0.5 x 0.28 x 0.8) with a cream CENTRAL label.
o = slot(0.6)
part("CoffeeBag", "Body", lambda bm: (H.rounded_box(bm, o + Vector((0, 0, 0.36)), (0.5, 0.28, 0.72), 0.06),
                                      H.span(bm, o + Vector((-0.25, -0.03, 0.72)), o + Vector((0.25, 0.03, 0.82)))))
part("CoffeeBag", "Label", lambda bm: H.span(bm, o + Vector((-0.19, -0.148, 0.2)), o + Vector((0.19, -0.138, 0.56))),
     smooth=False)
text_piece("CoffeeBag", [(BRAND, 0.068, H.on_front(o, -0.148, 0.43)), ("COFFEE", 0.05, H.on_front(o, -0.148, 0.31))])

# ================================================================ STAFF ROOM
# Sofa: a two-seat sofa (6 x 2.6), seat top 1.8, arms, back cushions, short oak legs; faces -Y.
o = slot(6)


def sofa_frame(bm):
    H.rounded_box(bm, o + Vector((0, 0.05, 0.85)), (6, 2.5, 1.0), 0.1)  # base
    H.rounded_box(bm, o + Vector((0, 1.05, 2.3)), (6, 0.5, 2.9), 0.15)  # back
    for sx in (-2.75, 2.75):
        H.rounded_box(bm, o + Vector((sx, 0.05, 1.75)), (0.5, 2.5, 1.9), 0.18)  # arms


def sofa_cushion(bm):
    for sx in (-1.25, 1.25):
        H.rounded_box(bm, o + Vector((sx, -0.15, 1.6)), (2.45, 2.0, 0.45), 0.16)
        H.rounded_box(bm, o + Vector((sx, 0.6, 2.75)), (2.4, 0.45, 1.5), 0.18, 3,
                      Matrix.Rotation(math.radians(-10), 4, "X"))


def sofa_legs(bm):
    for sx in (-2.7, 2.7):
        for sy in (-1.0, 1.1):
            H.cylinder(bm, o + Vector((sx, sy, 0.175)), 0.09, 0.35, "Z", 12, 0.12)


part("Sofa", "Frame", sofa_frame)
part("Sofa", "Cushion", sofa_cushion)
part("Sofa", "Legs", sofa_legs)

# Microwave (1.7 x 1.15 x 1.0): a dark glass door, a control panel and a handle.
o = slot(1.7)
part("Microwave", "Body", lambda bm: H.rounded_box(bm, o + Vector((0, 0, 0.5)), (1.7, 1.15, 1.0), 0.06))
part("Microwave", "Door", lambda bm: H.rounded_box(bm, o + Vector((-0.22, -0.58, 0.5)), (1.1, 0.03, 0.75), 0.02, 1),
     smooth=False)
part("Microwave", "Panel", lambda bm: H.span(bm, o + Vector((0.42, -0.6, 0.15)), o + Vector((0.75, -0.57, 0.85))),
     smooth=False)
part("Microwave", "Metal", lambda bm: (H.span(bm, o + Vector((0.28, -0.68, 0.2)), o + Vector((0.34, -0.6, 0.8))),
                                       H.cylinder(bm, o + Vector((0.585, -0.62, 0.65)), 0.08, 0.04, "Y", 16),
                                       H.cylinder(bm, o + Vector((0.585, -0.62, 0.42)), 0.08, 0.04, "Y", 16)))

# Kettle (0.6 x 0.75): a round body, spout, handle, lid knob and a base.
o = slot(0.8)
part("Kettle", "Body", lambda bm: (H.lathe_z(bm, [(0, 0.06), (0.28, 0.06), (0.3, 0.3), (0.24, 0.62), (0.16, 0.7),
                                                  (0, 0.7)], 32, o),
                                   H.cylinder(bm, o + Vector((0, -0.33, 0.48)), 0.07, 0.25, "Y", 12, 0.04)))
part("Kettle", "Trim", lambda bm: (H.cylinder(bm, o + Vector((0, 0, 0.03)), 0.31, 0.06, "Z", 32),
                                   H.sphere(bm, o + Vector((0, 0, 0.74)), 0.06, (1, 1, 0.8), 12, 6),
                                   H.torus(bm, o + Vector((0, 0.25, 0.42)), 0.24, 0.04, "YZ", 16, 8, math.pi, 0)))

# WaterCooler (1.2 x 1.2 x 4.7): a white cabinet, a blue bottle on top, taps and a drip tray.
o = slot(1.3)
part("WaterCooler", "Body", lambda bm: H.rounded_box(bm, o + Vector((0, 0, 1.7)), (1.2, 1.2, 3.4), 0.08))
part("WaterCooler", "Bottle", lambda bm: H.lathe_z(bm, [(0, 3.4), (0.12, 3.4), (0.12, 3.55), (0.45, 3.75), (0.5, 3.95),
                                                        (0.5, 4.5), (0.45, 4.65), (0, 4.68)], 32, o))
part("WaterCooler", "Tap", lambda bm: [H.span(bm, o + Vector((sx - 0.07, -0.72, 2.5)), o + Vector((sx + 0.07, -0.6, 2.7)))
                                       for sx in (-0.2, 0.2)], smooth=False)
part("WaterCooler", "Dark", lambda bm: (H.span(bm, o + Vector((-0.35, -0.65, 1.9)), o + Vector((0.35, -0.6, 2.9))),
                                        H.span(bm, o + Vector((-0.35, -0.85, 1.9)), o + Vector((0.35, -0.6, 1.98)))),
     smooth=False)

# Fridge: a retro fridge (2.4 x 2.2 x 6), rounded, a freezer door seam, chrome handles and a CENTRAL badge.
o = slot(2.4)
part("Fridge", "Body", lambda bm: H.rounded_box(bm, o + Vector((0, 0, 3.1)), (2.4, 2.1, 5.8), 0.3, 4))
part("Fridge", "Dark", lambda bm: (H.span(bm, o + Vector((-1.15, -1.07, 4.3)), o + Vector((1.15, -1.03, 4.36))),
                                   H.span(bm, o + Vector((-1.0, -0.8, 0)), o + Vector((1.0, 0.8, 0.2)))), smooth=False)


def fridge_metal(bm):
    for z0, z1 in ((4.6, 5.6), (2.6, 4.0)):
        H.rounded_box(bm, o + Vector((0.95, -1.15, (z0 + z1) / 2)), (0.12, 0.1, z1 - z0), 0.04, 2)
    B.add_text(bm, BRAND, 0.32, 0.01, H.on_front(o, -1.06, 5.1))


part("Fridge", "Metal", fridge_metal, smooth=False)

# StaffTee: a staff tee on a hanger (2.3 wide, 2.6 tall from the hook), CENTRAL over STAFF on the chest.
o = slot(2.4)
TEE = [(-0.5, 0), (0.5, 0), (0.55, 1.35), (1.05, 1.05), (1.25, 1.45), (0.65, 1.95), (0.25, 2.05), (0, 1.9),
       (-0.25, 2.05), (-0.65, 1.95), (-1.25, 1.45), (-1.05, 1.05), (-0.55, 1.35)]


def tee_body(bm):
    import bmesh
    tmp = bmesh.new()
    front = [tmp.verts.new(o + Vector((x, -0.05, z))) for x, z in TEE]
    face = tmp.faces.new(front)
    ext = bmesh.ops.extrude_face_region(tmp, geom=[face])
    for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.y += 0.1
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    bmesh.ops.triangulate(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)


def tee_metal(bm):
    H.cylinder(bm, o + Vector((0, 0, 1.97)), 0.03, 2.1, "X", 8)
    for sx in (-1, 1):
        a = Vector((sx * 1.05, 0, 1.97))
        b = Vector((0, 0, 2.3))
        mid, along = (a + b) / 2 + o, b - a
        H.box(bm, mid, (along.length, 0.05, 0.05), Matrix.Rotation(math.atan2(along.z, along.x), 4, "Y").inverted())
    H.torus(bm, o + Vector((0, 0, 2.42)), 0.12, 0.02, "XZ", 14, 6, math.pi * 1.4, -math.pi * 0.2)


part("StaffTee", "Body", tee_body, smooth=False)
text_piece("StaffTee", [(BRAND, 0.22, H.on_front(o, -0.05, 1.55)), ("STAFF", 0.15, H.on_front(o, -0.05, 1.3))])
part("StaffTee", "Metal", tee_metal)

print("RoomProps_02 built:", len(B.coll.objects), "objects:", sorted({ob.name.split("_")[0] for ob in B.coll.objects}))
