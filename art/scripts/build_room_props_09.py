# Builds RoomProps_09 in the live Blender scene: the Cardio room's machines (user 2026-10-26: "make Cardio a
# look-only room (treadmills, bikes, rowers, ski erg, TV) where players can hop on a machine for a fun
# running/cycling animation, no stats"): a treadmill, an upright exercise bike, a rowing machine and a ski erg.
# Mixed colours, not just red and black; every label says CENTRAL (user's rules).
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, each machine stands on z = 0 with its front
# toward -Y, objects are "<Item>_<Piece>" with ONE material each. Roblox recolours every piece from
# StarterGymConfig.PropColourways (COLOURWAYS below is the list to copy there; the first colourway is also what
# this file shows). PAINT holds the same colours as StarterGymConfig.PropPaints (0-255). Sized for a player of
# about 5.7 studs (1 stud is about 0.31 m): treadmill deck 0.7 high, bike saddle 3.0, rower seat 1.6.
# Where a player stands or sits is in POSES (copied to StarterGymConfig.CardioMachines).
#
# Run in an otherwise empty file (art/blender/RoomProps_09.blend):
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

B = H.Builder("RoomProps_09")
BRAND = H.BRAND

# StarterGymConfig.PropPaints (sRGB 0-255). Nothing new in this batch.
PAINT = {
    "Black": (22, 22, 24), "Charcoal": (46, 48, 54), "Red": (200, 30, 38), "White": (236, 236, 232),
    "LightGrey": (176, 180, 186), "Blue": (30, 92, 205), "Navy": (30, 48, 98), "Yellow": (242, 190, 30),
    "Green": (95, 222, 60), "Teal": (0, 138, 140), "Purple": (128, 52, 190), "Orange": (245, 130, 30),
    "Lime": (170, 214, 60), "Sky": (120, 178, 224), "Coral": (238, 112, 92), "Silver": (190, 192, 198),
}
METAL = {"Silver"}


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


MAT = {}
for colour, rgb in PAINT.items():
    lin = tuple(linear(c) for c in rgb)
    MAT[colour] = H.material("RP9_" + colour, lin, 1.0 if colour in METAL else 0.0, 0.5, 1.0)


def cardio(frame, shroud, pad, logo, display):
    """One colourway: frame, shroud (motor hood, flywheel cover), pads (saddle, seat), CENTRAL, the screen's
    display."""
    return {"Frame": frame, "Shroud": shroud, "Pad": pad, "Logo": logo, "Display": display, "Screen": "Black",
            "Belt": "Charcoal", "Grip": "Black", "Metal": "Silver", "Text": "White",
            # pieces that move while someone uses the machine (StarterGymConfig.CardioMachines)
            "Crank": "Silver", "Handle": "Black", "Chain": "Silver", "HandleLeft": "Black", "HandleRight": "Black",
            "CordLeft": "Charcoal", "CordRight": "Charcoal"}


COLOURWAYS = {
    "Treadmill": [cardio("Charcoal", "Red", "Black", "White", "Sky"),
                  cardio("White", "Teal", "Black", "White", "Lime"),
                  cardio("Black", "Orange", "Black", "Black", "Sky")],
    "ExerciseBike": [cardio("White", "Blue", "Black", "White", "Sky"),
                     cardio("Charcoal", "Lime", "Black", "Black", "Lime"),
                     cardio("LightGrey", "Coral", "Navy", "White", "Sky")],
    "Rower": [cardio("Black", "Yellow", "Black", "Black", "Lime"),
              cardio("LightGrey", "Navy", "Charcoal", "White", "Sky"),
              cardio("White", "Purple", "Black", "White", "Sky")],
    "SkiErg": [cardio("Black", "Teal", "Black", "White", "Lime"),
               cardio("White", "Orange", "Black", "White", "Sky"),
               cardio("Charcoal", "Green", "Black", "Black", "Lime")],
}

# Where the player stands or sits on each machine, in this file's coordinates (x across, y along, z up from
# the floor), with the machine's back at y = 0; filled in item by item below and printed at the end.
POSES = {}


class Item:
    """Collects the geometry of one machine per piece, then makes one object per piece."""

    def __init__(self, name):
        self.name = name
        self.pieces = {}

    def add(self, piece, build):
        self.pieces.setdefault(piece, []).append(build)

    def text(self, piece, words, size, place):
        self.add(piece, lambda bm: B.add_text(bm, words, size, 0.004, place))

    def finish(self):
        for piece, builds in self.pieces.items():
            mat = MAT[COLOURWAYS[self.name][0][piece]]
            B.piece(f"{self.name}_{piece}", mat, lambda bm, bs=builds: [b(bm) for b in bs], piece not in ("Text", "Logo"))


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


def tilted(bm, centre, size, angle, bevel=0.05):
    """A rounded box turned `angle` degrees about X (positive tips its top toward -Y)."""
    H.rounded_box(bm, centre, size, bevel, 3, Matrix.Rotation(math.radians(-angle), 4, "X"))


def on_tilted(base, centre, angle, depth_dir=-1):
    """place() for text on the -Y face of a box tilted `angle` degrees about X, centred at `centre`."""
    rot = Matrix.Rotation(math.radians(-angle), 3, "X")

    def place(x, up, depth):
        return Vector(base) + Vector(centre) + rot @ Vector((x, depth_dir * depth, up))
    return place


X = [0.0]  # the next item's X position along the shelf of items


def slot(width):
    """The base point of the next item, `width` studs wide."""
    base = Vector((X[0] + width / 2, 0, 0))
    X[0] += width + 2.0
    return base


# ================================================================ TREADMILL
# Treadmill (2.8 wide, 6.3 long, 4.7 tall): the console end at +Y (y = 0), the open end of the belt at -Y, so
# placed with its front toward the room the runner faces the wall (and the TV). A deck with side rails and
# grip treads, the belt, a motor hood with CENTRAL, two uprights, a tilted console with its screen and
# handrails. The runner stands on the belt facing +Y.
it = Item("Treadmill")
o = slot(2.8)
DECK = 0.66
it.add("Frame", lambda bm: [
    H.span(bm, o + Vector((sx * 1.4 - 0.15, -6.3, 0)), o + Vector((sx * 1.4 + 0.15, -0.6, DECK))) for sx in (-1, 1)]
    + [H.span(bm, o + Vector((-1.4, -6.3, 0)), o + Vector((1.4, -6.0, 0.35)))]
    + [beam(bm, o + Vector((sx * 1.3, -0.75, 0.8)), o + Vector((sx * 1.3, -1.35, 4.05)), 0.24) for sx in (-1, 1)])
it.add("Grip", lambda bm: [H.span(bm, o + Vector((sx * 1.4 - 0.13, -5.9, DECK)), o + Vector((sx * 1.4 + 0.13, -1.6, DECK + 0.03)))
                           for sx in (-1, 1)]
       + [rod(bm, o + Vector((sx * 1.32, -1.35, 3.35)), o + Vector((sx * 1.32, -2.9, 3.35)), 0.07) for sx in (-1, 1)])
it.add("Belt", lambda bm: [H.span(bm, o + Vector((-1.2, -6.1, 0.35)), o + Vector((1.2, -1.55, DECK - 0.02)))])
it.add("Shroud", lambda bm: [H.rounded_box(bm, o + Vector((0, -0.75, 0.56)), (2.9, 1.5, 1.12), 0.2, 3)])
it.text("Logo", BRAND, 0.24, H.on_front(o, -1.5, 0.84))  # above the belt
CONSOLE = Vector((0, -1.45, 4.25))
it.add("Frame", lambda bm: [tilted(bm, o + CONSOLE, (2.8, 0.45, 1.0), 25, 0.12)])
it.add("Screen", lambda bm: [tilted(bm, o + CONSOLE + Vector((0, -0.21, 0.1)), (1.5, 0.06, 0.62), 25, 0.03)])
it.add("Display", lambda bm: [tilted(bm, o + CONSOLE + Vector((0, -0.25, 0.1)), (1.3, 0.02, 0.44), 25, 0.01)])
it.text("Text", "5.0 KM/H", 0.13, on_tilted(o, CONSOLE + Vector((0, -0.27, 0.12)), 25))
it.text("Logo", BRAND, 0.12, on_tilted(o, CONSOLE + Vector((0, -0.25, -0.33)), 25))
it.finish()
POSES["Treadmill"] = {"stand": (0, -3.9, DECK), "facing": "+Y", "motion": "Run"}

# ================================================================ EXERCISE BIKE
# ExerciseBike (1.9 wide, 3.9 long, 3.5 tall): the handlebar end at +Y, the rider faces +Y. Sized for ROBLOX
# avatars, not real people (user 2026-10-26: the first bike "is not even pedalling the right way"; a Roblox
# avatar's hips are only about 2 studs up, so a real bike's 3-stud saddle left the feet far off the pedals):
# the saddle top 1.75 up, the crank 0.75 up and 0.75 ahead of the saddle with 0.4 arms, the grips 3.1 up.
# Two floor feet, the frame from the rear foot to the front, a seat post with the saddle, a handlebar post
# with the bars and a small screen, a flywheel in a coloured cover at the front with CENTRAL, the crank with
# pedals (one piece, turning about its axle).
it = Item("ExerciseBike")
o = slot(1.9)
CRANK = Vector((0, -2.0, 0.75))
CRANK_R = 0.4  # the crank arms' length
FLY = Vector((0, -0.95, 0.78))
SADDLE = Vector((0, -2.75, 1.62))  # its top at 1.75
BARS_Y, BARS_Z = -1.15, 3.0
GRIP = Vector((0.45, -1.7, 3.12))  # the horns' ends, where the hands go (and at -X)
it.add("Frame", lambda bm: [
    H.rounded_box(bm, o + Vector((0, -0.35, 0.12)), (1.9, 0.4, 0.24), 0.08, 2),        # front foot
    H.rounded_box(bm, o + Vector((0, -3.55, 0.12)), (1.9, 0.4, 0.24), 0.08, 2),        # rear foot
    beam(bm, o + Vector((0, -3.45, 0.24)), o + CRANK + Vector((0, 0, -0.1)), 0.28),   # lower frame
    beam(bm, o + CRANK, o + Vector((0, -0.5, 0.24)), 0.28),                           # to the front foot
    beam(bm, o + CRANK, o + SADDLE + Vector((0, 0.1, -0.13)), 0.26),                  # seat post
    beam(bm, o + CRANK + Vector((0, 0.15, 0.1)), o + Vector((0, BARS_Y, BARS_Z - 0.05)), 0.26)])  # handlebar post
it.add("Shroud", lambda bm: [H.cylinder(bm, o + FLY, 0.62, 0.34, "X", 32)])
it.add("Metal", lambda bm: [H.cylinder(bm, o + FLY, 0.1, 0.48, "X", 16)])
it.text("Logo", BRAND, 0.13, lambda x, up, d: o + FLY + Vector((0.17 + d, x, up + 0.33)))  # above the hub
it.text("Logo", BRAND, 0.13, lambda x, up, d: o + FLY + Vector((-0.17 - d, -x, up + 0.33)))
it.add("Pad", lambda bm: [H.rounded_box(bm, o + SADDLE, (0.62, 0.95, 0.26), 0.1, 3)])
it.add("Grip", lambda bm: [rod(bm, o + Vector((-0.6, BARS_Y, BARS_Z)), o + Vector((0.6, BARS_Y, BARS_Z)), 0.07)]
       + [rod(bm, o + Vector((sx * 0.6, BARS_Y, BARS_Z)), o + Vector((sx * GRIP.x, GRIP.y, GRIP.z)), 0.07)
          for sx in (-1, 1)])
it.add("Screen", lambda bm: [tilted(bm, o + Vector((0, -1.0, 3.32)), (0.7, 0.18, 0.5), 30, 0.05)])
it.add("Display", lambda bm: [tilted(bm, o + Vector((0, -1.1, 3.35)), (0.56, 0.02, 0.34), 30, 0.01)])


def crank(bm):
    # The axle, two arms (one forward, one back: symmetric about the axle, so the piece's centre is the axle and
    # Roblox can turn it about its own centre) and pedals.
    H.cylinder(bm, o + CRANK, 0.1, 0.9, "X", 12)
    for sx, ang in ((1, 0.0), (-1, math.pi)):
        tip = Vector((sx * 0.42, CRANK_R * math.cos(ang), CRANK_R * math.sin(ang)))
        beam(bm, o + CRANK + Vector((sx * 0.42, 0, 0)), o + CRANK + tip, 0.1)
        H.box(bm, o + CRANK + tip + Vector((sx * 0.18, 0, 0)), (0.36, 0.26, 0.08))


it.add("Crank", crank)
it.finish()
# The pedals (at +X: the +Y arm; at -X: the -Y arm) and the grips, for the rider's feet and hands.
POSES["ExerciseBike"] = {"seat": tuple(SADDLE + Vector((0, 0, 0.13))), "crank": tuple(CRANK),
                         "pedals": ((0.6, CRANK_R, 0), (-0.6, -CRANK_R, 0)), "grips": (tuple(GRIP), (-GRIP.x, GRIP.y, GRIP.z)),
                         "facing": "+Y", "motion": "Cycle"}

# ================================================================ ROWER
# Rower (1.9 wide, 7.8 long, 3.6 tall): the flywheel end at +Y, the rower faces +Y. A front leg with the
# flywheel in a round cover with CENTRAL, the monitor on its arm, foot stretchers, a monorail sloping down to
# the rear leg, the seat on the rail and the handle resting in its holder.
it = Item("Rower")
o = slot(1.9)
RAIL0, RAIL1 = Vector((0, -1.3, 1.45)), Vector((0, -7.6, 0.95))
FLY = Vector((0, -0.65, 1.35))


def rail_z(y):
    return RAIL0.z + (RAIL1.z - RAIL0.z) * (y - RAIL0.y) / (RAIL1.y - RAIL0.y)


SEAT_Y = -4.6
it.add("Frame", lambda bm: [
    beam(bm, o + RAIL0, o + RAIL1, 0.32),                                              # the monorail
    H.span(bm, o + Vector((-0.95, -1.0, 0)), o + Vector((0.95, -0.3, 0.2))),           # front foot
    beam(bm, o + Vector((0, -0.65, 0.2)), o + FLY, 0.3),
    H.span(bm, o + Vector((-0.8, -7.8, 0)), o + Vector((0.8, -7.4, 0.2))),             # rear foot
    beam(bm, o + Vector((0, -7.6, 0.2)), o + RAIL1 + Vector((0, 0, -0.1)), 0.26),
    beam(bm, o + Vector((0, -1.0, 1.9)), o + Vector((0, -1.55, 3.15)), 0.12)]          # monitor arm
    + [H.box(bm, o + Vector((sx * 0.4, -2.15, 1.05)), (0.42, 0.12, 0.85), Matrix.Rotation(math.radians(35), 4, "X"))
       for sx in (-1, 1)])                                                             # foot stretchers
it.add("Shroud", lambda bm: [H.cylinder(bm, o + FLY, 0.95, 0.75, "X", 32)])
it.text("Logo", BRAND, 0.2, lambda x, up, d: o + FLY + Vector((0.375 + d, x, up)))
it.text("Logo", BRAND, 0.2, lambda x, up, d: o + FLY + Vector((-0.375 - d, -x, up)))
it.add("Grip", lambda bm: [H.box(bm, o + Vector((sx * 0.4, -2.2, 1.1)), (0.36, 0.04, 0.6),
                                 Matrix.Rotation(math.radians(35), 4, "X")) for sx in (-1, 1)])
# The handle and its chain are pieces of their own: the handle follows the rower's hands, the chain is
# stretched from the flywheel to it.
it.add("Handle", lambda bm: [rod(bm, o + Vector((-0.55, -1.45, 1.85)), o + Vector((0.55, -1.45, 1.85)), 0.08)])
it.add("Chain", lambda bm: [rod(bm, o + Vector((0, -1.1, 1.85)), o + Vector((0, -1.42, 1.85)), 0.03, 8)])
it.add("Pad", lambda bm: [H.rounded_box(bm, o + Vector((0, SEAT_Y, rail_z(SEAT_Y) + 0.3)), (0.95, 1.05, 0.22), 0.09, 3)])
it.add("Screen", lambda bm: [tilted(bm, o + Vector((0, -1.6, 3.25)), (0.75, 0.16, 0.6), 20, 0.05)])
it.add("Display", lambda bm: [tilted(bm, o + Vector((0, -1.69, 3.27)), (0.6, 0.02, 0.42), 20, 0.01)])
it.finish()
POSES["Rower"] = {"seat": (0, SEAT_Y, rail_z(SEAT_Y) + 0.41), "chainFrom": (0, -1.1, 1.85), "facing": "+Y",
                  "motion": "Row"}

# ================================================================ SKI ERG
# SkiErg (2.1 wide, 2.9 deep, 6.4 tall): its column against the wall at +Y, the skier faces it. A floor
# platform with a rubber top, the column, the head with its flywheel cover and CENTRAL, the monitor, two
# handles hanging on cords from the head's pulleys.
it = Item("SkiErg")
o = slot(2.1)
it.add("Frame", lambda bm: [H.span(bm, o + Vector((-1.05, -2.9, 0)), o + Vector((1.05, 0, 0.22))),
                            H.span(bm, o + Vector((-0.28, -0.6, 0.22)), o + Vector((0.28, -0.04, 5.7)))])
it.add("Grip", lambda bm: [H.span(bm, o + Vector((-0.95, -2.8, 0.22)), o + Vector((0.95, -0.7, 0.26)))])
it.add("Shroud", lambda bm: [H.rounded_box(bm, o + Vector((0, -0.6, 6.0)), (1.5, 1.1, 0.8), 0.25, 3)])
it.text("Logo", BRAND, 0.24, H.on_front(o, -1.15, 6.0))
it.add("Metal", lambda bm: [H.cylinder(bm, o + Vector((sx * 0.4, -1.22, 5.65)), 0.1, 0.12, "X", 16) for sx in (-1, 1)])
# Each handle and its cord is a piece of its own: the handles follow the skier's hands, the cords are stretched
# from the pulleys to them. Left / right as seen by the skier facing the column (+Y): left is -X.
for side, sx in (("Left", -1), ("Right", 1)):
    it.add("Handle" + side, lambda bm, sx=sx: [rod(bm, o + Vector((sx * 0.42, -1.3, 3.55)), o + Vector((sx * 0.42, -1.3, 4.05)), 0.07)])
    it.add("Cord" + side, lambda bm, sx=sx: [rod(bm, o + Vector((sx * 0.42, -1.3, 4.05)), o + Vector((sx * 0.4, -1.3, 5.6)), 0.025, 8)])
it.add("Screen", lambda bm: [tilted(bm, o + Vector((0, -0.72, 4.75)), (0.7, 0.16, 0.55), 15, 0.05)])
it.add("Display", lambda bm: [tilted(bm, o + Vector((0, -0.81, 4.77)), (0.56, 0.02, 0.4), 15, 0.01)])
it.finish()
POSES["SkiErg"] = {"stand": (0, -2.0, 0.26), "pulleys": ((-0.4, -1.3, 5.6), (0.4, -1.3, 5.6)), "facing": "+Y",
                   "motion": "Ski"}

print("RoomProps_09 built:", len(B.coll.objects), "objects:", sorted({ob.name.split("_")[0] for ob in B.coll.objects}))
print("POSES", POSES)
