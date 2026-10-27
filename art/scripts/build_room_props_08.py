# Builds RoomProps_08 in the live Blender scene: the machines of the open dumbbell & machine zone
# (GAME_DESIGN §27 "The open dumbbell & machine zone", user 2026-10-26: "new machine models previewed
# later"; picked by the user 2026-10-26): a tricep pulldown station, a lat pulldown, a seated cable row
# and a leg extension / leg curl (the first idea, a dual cable tower, was "just a pull-up bar with two
# stacks": the user asked for a tricep pulldown like their photo instead). They replace the zone's thin weight-stack stations. Look only.
# Mixed frame colours (user's pick), not just red and black; every label says CENTRAL (user's rules).
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, each machine stands on z = 0 with its back
# against the wall at y = 0 and its front toward -Y, objects are "<Item>_<Piece>" with ONE material each.
# Roblox recolours every piece from StarterGymConfig.PropColourways (COLOURWAYS below is the list to copy
# there; the first colourway is also what this file shows). PAINT holds the same colours as
# StarterGymConfig.PropPaints (0-255). Sizes fit the gym: drawn at the approved WeightStack's size (8.6
# tall), then shrunk by SCALE to the power racks' scale (7 tall; a player is about 5.7): seats about 1.5.
#
# Run in an otherwise empty file (art/blender/RoomProps_08.blend):
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

B = H.Builder("RoomProps_08")
BRAND = H.BRAND

# StarterGymConfig.PropPaints (sRGB 0-255). Nothing new in this batch.
PAINT = {
    "Black": (22, 22, 24), "Charcoal": (46, 48, 54), "Red": (200, 30, 38), "White": (236, 236, 232),
    "LightGrey": (176, 180, 186), "Blue": (30, 92, 205), "Navy": (30, 48, 98), "Yellow": (242, 190, 30),
    "Green": (95, 222, 60), "Forest": (34, 98, 62), "Teal": (0, 138, 140), "Purple": (128, 52, 190),
    "Orange": (245, 130, 30), "Lime": (170, 214, 60), "Silver": (190, 192, 198),
}
METAL = {"Silver"}


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


MAT = {}
for colour, rgb in PAINT.items():
    lin = tuple(linear(c) for c in rgb)
    MAT[colour] = H.material("RP8_" + colour, lin, 1.0 if colour in METAL else 0.0, 0.5, 1.0)


def machine(frame, shroud, pad, logo, pin, plate="Black"):
    """One colourway: frame, shroud panels (and the top plate, cam), pads (and the stack cap), CENTRAL, pin."""
    return {"Frame": frame, "Shroud": shroud, "Top": shroud, "Pad": pad, "Cap": pad, "Logo": logo, "Pin": pin, "Plate": plate,
            "Rod": "Silver", "Cable": "Black", "Pulley": "Silver", "Bar": "Silver", "Grip": "Black", "Text": "White"}


# Per item: a list of colourways, each piece -> colour name.
COLOURWAYS = {
    "TricepPulldown": [machine("White", "Blue", "Black", "White", "Yellow"),
                       machine("Black", "Orange", "Black", "Black", "Yellow"),
                       machine("LightGrey", "Teal", "Charcoal", "White", "Red")],
    "LatPulldown": [machine("Blue", "Yellow", "Charcoal", "Black", "Red"),
                    machine("White", "Red", "Black", "White", "Yellow"),
                    machine("LightGrey", "Purple", "Charcoal", "White", "Yellow")],
    "SeatedRow": [machine("LightGrey", "Teal", "Charcoal", "White", "Yellow"),
                  machine("Yellow", "Black", "Black", "Yellow", "Red", "Charcoal"),
                  machine("Navy", "Lime", "Navy", "Black", "Yellow")],
    "LegExtension": [machine("Black", "Orange", "Navy", "Black", "Yellow", "Charcoal"),
                     machine("White", "Green", "Forest", "Black", "Red"),
                     machine("Teal", "White", "Charcoal", "Teal", "Yellow")],
}


SCALE = 0.85  # the machines are drawn at the approved WeightStack's size, then shrunk to the racks' (7 tall) scale


class Item:
    """Collects the geometry of one machine per piece, then makes one object per piece, scaled by SCALE
    about the machine's base point (so it still stands on the floor with its back on the wall)."""

    def __init__(self, name, origin):
        self.name = name
        self.shrink = Matrix.Translation(origin) @ Matrix.Scale(SCALE, 4) @ Matrix.Translation(-origin)
        self.pieces = {}

    def add(self, piece, build):
        self.pieces.setdefault(piece, []).append(build)

    def text(self, piece, words, size, place):
        self.add(piece, lambda bm: B.add_text(bm, words, size, 0.004, place))

    def finish(self):
        def build(bm, bs):
            for b in bs:
                b(bm)
            bmesh.ops.transform(bm, matrix=self.shrink, verts=bm.verts[:])
        for piece, builds in self.pieces.items():
            mat = MAT[COLOURWAYS[self.name][0][piece]]
            B.piece(f"{self.name}_{piece}", mat, lambda bm, bs=builds: build(bm, bs), piece not in ("Text", "Logo"))


def beam(bm, a, b, size):
    """A square bar of side `size` from point a to point b."""
    a, b = Vector(a), Vector(b)
    direction = (b - a).normalized()
    rot = direction.to_track_quat("Z", "Y").to_matrix().to_4x4()
    H.box(bm, (a + b) / 2, (size, size, (b - a).length), rot)


def rod(bm, a, b, radius, segments=12):
    """A round bar from point a to point b."""
    a, b = Vector(a), Vector(b)
    direction = (b - a).normalized()
    rot = direction.to_track_quat("Z", "Y").to_matrix().to_4x4()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius, radius2=radius,
                          depth=(b - a).length, matrix=Matrix.Translation((a + b) / 2) @ rot)


def on_side(base, x_face, sign, y_mid, z_mid):
    """place() for text on a flat face looking toward +X (sign 1) or -X (sign -1) at x = x_face."""
    def place(x, up, depth):
        return Vector(base) + Vector((x_face + sign * depth, y_mid + sign * x, z_mid + up))
    return place


X = [0.0]  # the next item's X position along the shelf of items


def slot(width):
    """The base point of the next item, `width` studs wide."""
    base = Vector((X[0] + width / 2, 0, 0))
    X[0] += width + 2.0
    return base


PLATE_H, PLATE_GAP = 0.22, 0.04
STACK_Y = -0.9  # every weight stack's middle, 1.8 deep frame against the wall


def stack(it, c, plates, frame_h, z0=0.45, logo_z=None, logo_sides=(1, -1)):
    """A weight stack at c (its base point, middle of the stack on the wall line + STACK_Y) inside a frame of
    two uprights, base and top beam, with shroud panels on both sides: plates with kg numbers, a top plate,
    guide rods, the pin and CENTRAL on the shroud. Returns the z of the top plate's lifting stem."""
    c = Vector(c)
    y = STACK_Y
    front = y - 0.5  # the plates' front faces
    top_z = z0 + plates * (PLATE_H + PLATE_GAP)
    it.add("Frame", lambda bm: [H.box(bm, c + Vector((0, y, 0.1)), (2.6, 1.8, 0.2)),
                                H.box(bm, c + Vector((0, y, frame_h - 0.15)), (2.6, 0.4, 0.3))]
           + [H.box(bm, c + Vector((sx * 1.18, y, frame_h / 2)), (0.24, 0.24, frame_h)) for sx in (-1, 1)])
    it.add("Shroud", lambda bm: [H.box(bm, c + Vector((sx * 1.33, y, (0.3 + frame_h - 0.4) / 2)),
                                       (0.06, 1.4, frame_h - 0.7)) for sx in (-1, 1)])
    for k in range(plates):
        it.add("Plate", lambda bm, k=k: H.rounded_box(
            bm, c + Vector((0, y, z0 + k * (PLATE_H + PLATE_GAP) + PLATE_H / 2)), (1.8, 1.0, PLATE_H), 0.03, 2))
        it.text("Text", str((k + 1) * 5), 0.13,
                lambda x, up, d, z=top_z - PLATE_GAP - PLATE_H / 2 - k * (PLATE_H + PLATE_GAP):
                c + Vector((x - 0.6, front - d, z + up)))
    it.add("Top", lambda bm: [H.rounded_box(bm, c + Vector((0, y, top_z + 0.17)), (1.8, 1.0, 0.34), 0.04, 2),
                              H.cylinder(bm, c + Vector((0, y, top_z + 0.44)), 0.09, 0.2, "Z", 16)])
    it.add("Rod", lambda bm: [H.cylinder(bm, c + Vector((sx * 0.6, y, (0.3 + frame_h - 0.3) / 2)), 0.045,
                                         frame_h - 0.6, "Z", 12) for sx in (-1, 1)])
    it.add("Grip", lambda bm: [H.cylinder(bm, c + Vector((sx * 0.6, y, 0.32)), 0.15, 0.24, "Z", 16) for sx in (-1, 1)])
    pin_z = z0 + 5 * (PLATE_H + PLATE_GAP) + PLATE_H / 2
    it.add("Pin", lambda bm: [H.cylinder(bm, c + Vector((0.3, front + 0.2, pin_z)), 0.045, 0.5, "Y", 12),
                              H.sphere(bm, c + Vector((0.3, front - 0.12, pin_z)), 0.11, (1, 0.7, 1), 16, 8)])
    if logo_z is not None:
        for sx in logo_sides:
            it.text("Logo", BRAND, 0.24, on_side(c, sx * 1.36, sx, y, logo_z))
    return top_z + 0.54


def pulley(it, centre, radius=0.2):
    """A pulley wheel turning about X, with its axle."""
    centre = Vector(centre)
    it.add("Pulley", lambda bm: [H.cylinder(bm, centre, radius, 0.12, "X", 24),
                                 H.cylinder(bm, centre, 0.05, 0.3, "X", 12)])


def cable(it, *points):
    """A cable through the given points (straight runs)."""
    pts = [Vector(p) for p in points]
    it.add("Cable", lambda bm: [rod(bm, pts[k], pts[k + 1], 0.03, 8) for k in range(len(pts) - 1)])


# ================================================================ TRICEP PULLDOWN
# TricepPulldown: a tricep pulldown station (user 2026-10-26, from a photo; 3.4 wide, 3.8 deep, 7.3 tall after
# SCALE), its back on the wall: a tall covered weight stack with a rounded cap and CENTRAL on its side and
# cap, a column beside it braced to the stack, a top arm with a pulley and a tricep rope hanging from it, an
# arm pad on the column, a low pulley at its foot and floor feet.
o = slot(4.0)
it = Item("TricepPulldown", o)
S = o + Vector((-0.8, 0, 0))  # the stack
stem = stack(it, S, 14, 8.0, logo_z=6.2, logo_sides=(-1,))
COL = Vector((1.3, -2.2, 0))  # the column's foot
TOP_Z, ARM_Y = 8.35, -3.5
PULLEY_TOP = o + Vector((COL.x, ARM_Y, TOP_Z - 0.35))
PULLEY_LOW = o + Vector((COL.x, COL.y - 0.35, 0.65))
it.add("Cap", lambda bm: [H.rounded_box(bm, S + Vector((0, STACK_Y, 8.2)), (2.95, 2.0, 0.5), 0.2, 4)])
it.text("Logo", BRAND, 0.3, H.on_front(S, STACK_Y - 1.0, 8.2))
it.add("Frame", lambda bm: [
    H.box(bm, o + COL + Vector((0, 0, (0.2 + TOP_Z) / 2)), (0.34, 0.34, TOP_Z - 0.2)),           # the column
    H.span(bm, o + Vector((COL.x - 0.17, ARM_Y - 0.15, TOP_Z - 0.15)), o + Vector((COL.x + 0.17, COL.y, TOP_Z + 0.15))),  # top arm
    beam(bm, S + Vector((1.18, STACK_Y, 7.4)), o + COL + Vector((0, 0.1, TOP_Z - 0.6)), 0.24),    # brace
    H.span(bm, S + Vector((1.3, -1.8, 0)), o + Vector((COL.x + 0.25, COL.y + 0.25, 0.25))),      # base to the column
    H.span(bm, o + Vector((COL.x - 0.8, -4.0, 0)), o + Vector((COL.x + 0.8, COL.y + 0.25, 0.2))),  # front foot
    H.span(bm, o + Vector((COL.x - 0.15, ARM_Y - 0.25, TOP_Z - 0.75)), o + Vector((COL.x - 0.09, ARM_Y + 0.25, TOP_Z - 0.15))),
    H.span(bm, o + Vector((COL.x + 0.09, ARM_Y - 0.25, TOP_Z - 0.75)), o + Vector((COL.x + 0.15, ARM_Y + 0.25, TOP_Z - 0.15))),
    H.span(bm, o + Vector((COL.x - 0.16, COL.y - 0.65, 0.25)), o + Vector((COL.x - 0.1, COL.y - 0.05, 1.05))),
    H.span(bm, o + Vector((COL.x + 0.1, COL.y - 0.65, 0.25)), o + Vector((COL.x + 0.16, COL.y - 0.05, 1.05))),
    H.span(bm, o + Vector((COL.x - 0.12, COL.y - 0.45, 4.85)), o + Vector((COL.x + 0.12, COL.y - 0.17, 5.15)))])  # pad bracket
it.add("Pad", lambda bm: [H.rounded_box(bm, o + Vector((COL.x, COL.y - 0.62, 5.0)), (0.95, 0.35, 1.5), 0.12, 3)])
pulley(it, PULLEY_TOP, 0.24)
pulley(it, PULLEY_LOW, 0.24)
# The stack's cable over the brace to the top arm, round the top pulley, down to the rope's clip.
ROPE_Z = 6.05
cable(it, S + Vector((0, STACK_Y, stem)), S + Vector((0, STACK_Y, 7.6)), o + COL + Vector((0, -0.1, TOP_Z - 0.4)),
      PULLEY_TOP + Vector((0, 0.24, 0.05)))
cable(it, PULLEY_TOP + Vector((0, -0.24, 0)), PULLEY_TOP + Vector((0, -0.24, ROPE_Z - PULLEY_TOP.z + 0.3)))
cable(it, PULLEY_LOW + Vector((0, 0.24, 0)), o + COL + Vector((0, -0.2, 7.6)))
CLIP = o + Vector((COL.x, ARM_Y - 0.24, ROPE_Z))
it.add("Bar", lambda bm: [H.torus(bm, CLIP + Vector((0, 0, 0.18)), 0.12, 0.03, "YZ", 16, 6),
                          H.cylinder(bm, CLIP, 0.07, 0.12, "Z", 12)])
# The tricep rope: two thick strands from the clip, each ending in a black stopper.
it.add("Grip", lambda bm: [rod(bm, CLIP + Vector((0, 0, -0.05)), CLIP + Vector((sx * 0.3, 0, -1.15)), 0.075, 12)
                           for sx in (-1, 1)]
       + [H.sphere(bm, CLIP + Vector((sx * 0.31, 0, -1.25)), 0.14, (1, 1, 1), 16, 8) for sx in (-1, 1)])
it.finish()

# ================================================================ LAT PULLDOWN
# LatPulldown: a lat pulldown (3.5 wide, 4.2 deep, 7.4 tall after SCALE), its back on the wall: a weight stack, an arm
# out over the seat with a pulley, a wide bar with bent grips on the cable, a seat and knee rollers.
o = slot(4.1)
it = Item("LatPulldown", o)
stem = stack(it, o, 14, 8.6, logo_z=7.0)
ARM_Y = -3.75
it.add("Frame", lambda bm: [
    H.span(bm, o + Vector((-0.18, ARM_Y - 0.15, 8.25)), o + Vector((0.18, STACK_Y, 8.6))),       # the arm
    beam(bm, o + Vector((0, -1.1, 6.6)), o + Vector((0, -2.7, 8.3)), 0.22),                        # its brace
    H.span(bm, o + Vector((-0.16, ARM_Y - 0.2, 7.75)), o + Vector((-0.1, ARM_Y + 0.2, 8.25))),     # pulley cheeks
    H.span(bm, o + Vector((0.1, ARM_Y - 0.2, 7.75)), o + Vector((0.16, ARM_Y + 0.2, 8.25))),
    H.span(bm, o + Vector((-0.25, -4.9, 0)), o + Vector((0.25, -1.8, 0.3))),                      # floor rail
    H.span(bm, o + Vector((-0.15, -4.4, 0.3)), o + Vector((0.15, -4.1, 1.55))),                  # seat post
    H.span(bm, o + Vector((-0.14, -3.14, 0.3)), o + Vector((0.14, -2.86, 2.75))),                # knee pad post
    H.span(bm, o + Vector((-0.1, -3.55, 2.5)), o + Vector((0.1, -2.86, 2.7)))])
pulley(it, o + Vector((0, ARM_Y, 7.95)))
cable(it, o + Vector((0, STACK_Y, stem)), o + Vector((0, STACK_Y, 8.2)), o + Vector((0, ARM_Y + 0.2, 8.2)))
cable(it, o + Vector((0, ARM_Y - 0.2, 7.95)), o + Vector((0, ARM_Y - 0.2, 6.35)))
it.add("Bar", lambda bm: [H.cylinder(bm, o + Vector((0, ARM_Y - 0.2, 6.3)), 0.06, 3.0, "X", 16),
                          H.torus(bm, o + Vector((0, ARM_Y - 0.2, 6.42)), 0.1, 0.025, "XZ", 16, 6)]
       + [beam(bm, o + Vector((sx * 1.5, ARM_Y - 0.2, 6.3)), o + Vector((sx * 2.0, ARM_Y - 0.2, 5.9)), 0.1)
          for sx in (-1, 1)])
it.add("Grip", lambda bm: [rod(bm, o + Vector((sx * 1.56, ARM_Y - 0.2, 6.25)), o + Vector((sx * 1.98, ARM_Y - 0.2, 5.91)),
                               0.09, 16) for sx in (-1, 1)])
it.add("Rod", lambda bm: [H.cylinder(bm, o + Vector((0, -3.55, 2.6)), 0.06, 1.5, "X", 12)])
it.add("Pad", lambda bm: [H.rounded_box(bm, o + Vector((0, -4.25, 1.72)), (1.7, 1.5, 0.35), 0.1, 3)]
       + [H.cylinder(bm, o + Vector((sx * 0.5, -3.55, 2.6)), 0.27, 0.65, "X", 24) for sx in (-1, 1)])
it.finish()

# ================================================================ SEATED ROW
# SeatedRow: a seated cable row (user 2026-10-26, from a photo: "an actual pulley machine"; 2.6 wide, 7.1 deep,
# 5.8 tall after SCALE), its back on the wall: a shorter weight stack, a front column with a big pulley in a
# housing at the top and another at knee height, the cable running down the column and round the low pulley
# to a double-D row handle, a long floor beam with an angled foot plate and the seat.
o = slot(3.0)
it = Item("SeatedRow", o)
stem = stack(it, o, 12, 6.8, logo_z=5.7)
ROW_Z, COL_Y, R = 2.2, -2.0, 0.3  # the low pulley's height, the column's middle, the pulleys' radius
TOP = o + Vector((0, COL_Y - 0.5, 6.2))
LOW = o + Vector((0, COL_Y - 0.5, ROW_Z))


def housing(bm, centre):
    """Two cheek plates holding a pulley's axle, joined to the column's front (the wheel's front half shows)."""
    for sx in (-1, 1):
        H.span(bm, centre + Vector((sx * 0.12 - 0.03, -0.1, -0.16)), centre + Vector((sx * 0.12 + 0.03, 0.5, 0.16)))


it.add("Frame", lambda bm: [
    H.span(bm, o + Vector((-0.17, COL_Y - 0.17, 0.2)), o + Vector((0.17, COL_Y + 0.17, 6.8))),    # front column
    H.span(bm, o + Vector((-0.15, COL_Y - 0.1, 6.5)), o + Vector((0.15, STACK_Y, 6.8))),
    housing(bm, TOP), housing(bm, LOW),
    H.span(bm, o + Vector((-0.25, -8.4, 0)), o + Vector((0.25, -1.8, 0.4))),                      # floor beam
    H.span(bm, o + Vector((-0.15, -6.75, 0.4)), o + Vector((0.15, -6.45, 1.2))),                 # seat post
    H.box(bm, o + Vector((0, -3.3, 1.0)), (2.2, 0.12, 1.3), Matrix.Rotation(math.radians(-25), 4, "X")),  # foot plate
    beam(bm, o + Vector((0, -3.6, 0.4)), o + Vector((0, -3.25, 0.95)), 0.2)])
it.add("Grip", lambda bm: [H.box(bm, o + Vector((sx * 0.55, -3.36, 1.05)), (0.9, 0.04, 1.0),
                                 Matrix.Rotation(math.radians(-25), 4, "X")) for sx in (-1, 1)])
pulley(it, TOP, R)
pulley(it, LOW, R)
# From the stack up and over the top pulley, down the column's front, under the low pulley and out to the handle.
HANDLE_Y = -3.9
cable(it, o + Vector((0, STACK_Y, stem)), o + Vector((0, STACK_Y, TOP.z + R)), TOP + Vector((0, 0, R)))
cable(it, TOP + Vector((0, -R, 0)), LOW + Vector((0, -R, 0)))
cable(it, LOW + Vector((0, -R, 0)), LOW + Vector((0, -R * 0.7, -R * 0.7)), LOW + Vector((0, 0, -R)),
      o + Vector((0, HANDLE_Y + 0.25, LOW.z - R)))
# The double-D row handle: a ring on the cable, a centre plate, two loops each round an upright grip.
HZ = LOW.z - R
it.add("Bar", lambda bm: [H.torus(bm, o + Vector((0, HANDLE_Y + 0.17, HZ)), 0.09, 0.025, "YZ", 16, 6),
                          H.box(bm, o + Vector((0, HANDLE_Y - 0.05, HZ)), (0.06, 0.3, 0.7))]
       + [rod(bm, o + Vector((0, HANDLE_Y - 0.05, HZ + dz)), o + Vector((sx * 0.36, HANDLE_Y - 0.3, HZ + dz)), 0.035, 10)
          for sx in (-1, 1) for dz in (-0.32, 0.32)])
it.add("Grip", lambda bm: [H.cylinder(bm, o + Vector((sx * 0.36, HANDLE_Y - 0.3, HZ)), 0.08, 0.6, "Z", 16)
                           for sx in (-1, 1)])
it.add("Pad", lambda bm: [H.rounded_box(bm, o + Vector((0, -6.6, 1.38)), (1.5, 2.4, 0.35), 0.1, 3)])
it.finish()

# ================================================================ LEG EXTENSION / LEG CURL
# LegExtension: a leg extension / leg curl seat (4.2 wide, 4.0 deep, 5.4 tall after SCALE), its back on the wall: a short
# weight stack beside the seat, a reclined back pad, handles, a cam with a lever arm holding the shin roller
# (extension) and a thigh hold-down roller (curl), a cable from the cam to the stack.
o = slot(5.0)
it = Item("LegExtension", o)
S = o + Vector((1.4, 0, 0))  # the stack beside the seat
SEAT_X = -1.0
stem = stack(it, S, 10, 6.4, logo_z=5.3, logo_sides=(1,))
HUB = Vector((0.2, -3.9, 1.85))
it.add("Frame", lambda bm: [
    H.span(bm, o + Vector((SEAT_X - 0.25, -4.3, 0)), o + Vector((SEAT_X + 0.25, -0.4, 0.35))),    # floor rail
    H.span(bm, o + Vector((SEAT_X, -1.15, 0)), S + Vector((-1.3, -0.65, 0.35))),                  # to the stack
    H.span(bm, o + Vector((SEAT_X - 0.15, -3.2, 0.35)), o + Vector((SEAT_X + 0.15, -2.9, 1.55))),  # seat post
    beam(bm, o + Vector((SEAT_X, -1.1, 0.35)), o + Vector((SEAT_X, -1.55, 2.9)), 0.26),            # back pad post
    H.span(bm, o + Vector((SEAT_X + 0.15, -3.9, 1.35)), o + HUB + Vector((-0.1, 0.2, 0.1))),       # hub arm
    beam(bm, o + HUB, o + Vector((HUB.x, -4.35, 0.8)), 0.2),                                       # shin lever
    beam(bm, o + HUB, o + Vector((HUB.x, -3.45, 2.6)), 0.16)]                                      # thigh lever
    + [beam(bm, o + Vector((SEAT_X + sx * 0.6, -3.2, 1.45)), o + Vector((SEAT_X + sx * 1.15, -3.2, 1.75)), 0.1)
       for sx in (-1, 1)])
it.add("Grip", lambda bm: [H.cylinder(bm, o + Vector((SEAT_X + sx * 1.15, -3.25, 1.78)), 0.08, 0.6, "Y", 16)
                           for sx in (-1, 1)])
it.add("Top", lambda bm: [H.cylinder(bm, o + HUB, 0.28, 0.25, "X", 24)])
it.add("Rod", lambda bm: [H.cylinder(bm, o + Vector(((HUB.x + SEAT_X - 0.85) / 2, -4.35, 0.8)), 0.05,
                                     HUB.x - SEAT_X + 0.85, "X", 12),
                          H.cylinder(bm, o + Vector(((HUB.x + SEAT_X - 0.8) / 2, -3.45, 2.6)), 0.05,
                                     HUB.x - SEAT_X + 0.8, "X", 12)])
it.add("Pad", lambda bm: [H.rounded_box(bm, o + Vector((SEAT_X, -3.0, 1.72)), (1.7, 1.8, 0.35), 0.1, 3),
                          H.rounded_box(bm, o + Vector((SEAT_X, -1.75, 3.2)), (1.7, 0.35, 2.4), 0.1, 3,
                                        Matrix.Rotation(math.radians(-12), 4, "X")),
                          H.cylinder(bm, o + Vector((SEAT_X, -4.35, 0.8)), 0.28, 1.5, "X", 24),
                          H.cylinder(bm, o + Vector((SEAT_X, -3.45, 2.6)), 0.25, 1.4, "X", 24)])
pulley(it, S + Vector((0, -1.6, 0.6)), 0.18)
pulley(it, S + Vector((0, -1.2, 6.05)), 0.18)
cable(it, S + Vector((0, STACK_Y, stem)), S + Vector((0, STACK_Y, 6.23)), S + Vector((0, -1.42, 6.23)),
      S + Vector((0, -1.42, 0.6)), S + Vector((0, -1.6, 0.42)), o + HUB + Vector((0.05, 0, -0.28)))
it.finish()

print("RoomProps_08 built:", len(B.coll.objects), "objects:", sorted({ob.name.split("_")[0] for ob in B.coll.objects}))
