# The Kitchen's scene props (GAME_DESIGN §40.7, user 2026-11-19): the lifter dumps the steaks (a bag, or a cow to be
# funny) into the meat grinder, it blends, and the chef lifts out a mountain of meat the size of the finished steak.
#
#   MeatGrinder_*  a squat red grinder on four feet with a big steel hopper on top, a crank and a front spout; CENTRAL
#   MeatBag_*      a fat burlap sack tied at the top with a STEAKS label (small cooks)
#   Cow_*          a cartoon cow (big cooks): white body, black spots, pink snout, cream horns, dark hooves
#   MeatMound_*    a lumpy mound of ground meat; code scales it to the steak's size for the chef to lift
#
# Units: studs; z up; fronts toward -Y. Builder stops on any inside-out piece; run check_models.py before export.
#
#   blender -b --factory-startup --python art/scripts/build_kitchen_extras_01.py -- <out.blend> [<out.glb>]

import math
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, r"D:\Powerlifting Roblox\art\scripts")
import importlib  # noqa: E402

import prop_helpers as H  # noqa: E402

importlib.reload(H)

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

B = H.Builder("KitchenExtras")

RED = H.material("Extra_GrinderRed", (0.78, 0.1, 0.1), metallic=0.2, roughness=0.35)
STEEL = H.material("Extra_Steel", (0.66, 0.68, 0.72), metallic=0.85, roughness=0.3)
DARK = H.material("Extra_Dark", (0.08, 0.08, 0.09), roughness=0.5)
YELLOW = H.material("Extra_Yellow", (0.98, 0.79, 0.12), roughness=0.5)
BURLAP = H.material("Extra_Burlap", (0.72, 0.56, 0.34), roughness=0.9)
ROPE = H.material("Extra_Rope", (0.5, 0.36, 0.2), roughness=0.9)
LABEL_RED = H.material("Extra_LabelRed", (0.75, 0.12, 0.1), roughness=0.6)
WHITE = H.material("Extra_CowWhite", (0.96, 0.96, 0.94), roughness=0.7)
BLACK = H.material("Extra_CowBlack", (0.07, 0.07, 0.08), roughness=0.7)
PINK = H.material("Extra_Pink", (0.96, 0.62, 0.66), roughness=0.6)
CREAM = H.material("Extra_Cream", (0.95, 0.9, 0.76), roughness=0.6)
MEAT = H.material("Extra_GroundMeat", (0.78, 0.3, 0.3), roughness=0.85)

# ---------------------------------------------------------------- MeatGrinder (about 4 wide, 8 tall)


def grinder_body(bm):
    # The squat body: a rounded drum lying along Y (front to back), on a waist.
    H.rounded_box(bm, Vector((0, 0, 2.2)), (2.8, 3.2, 2.6), 0.6, segments=3)
    H.cylinder(bm, Vector((0, 0, 0.75)), 1.1, 0.7, segments=20)


def grinder_feet(bm):
    for x in (-1.2, 1.2):
        for y in (-1.3, 1.3):
            H.rounded_box(bm, Vector((x, y, 0.2)), (0.7, 0.7, 0.4), 0.12, segments=1)


def grinder_hopper(bm):
    # A big funnel on top: wide at the mouth (a cow has to fit, sort of), with a rolled rim.
    H.lathe_z(bm, [(0.0, 3.4), (0.9, 3.4), (2.6, 6.3), (2.8, 6.5), (2.55, 6.55), (0.75, 3.7), (0.0, 3.7)],
              segments=32, centre=Vector((0, 0.3, 0)))


def grinder_spout(bm):
    # The round mouth at the front where the meat comes out, with its cutting plate.
    H.cylinder(bm, Vector((0, -2.1, 2.1)), 0.85, 1.2, axis="Y", segments=20)
    H.cylinder(bm, Vector((0, -2.75, 2.1)), 0.95, 0.12, axis="Y", segments=20)


def grinder_crank(bm):
    # The crank on the right side: an axle, an arm and a knob.
    H.cylinder(bm, Vector((1.75, 0, 2.4)), 0.22, 0.8, axis="X", segments=12)
    H.rounded_box(bm, Vector((2.2, 0, 1.75)), (0.24, 0.35, 1.6), 0.08, segments=1)
    H.cylinder(bm, Vector((2.45, 0, 1.05)), 0.26, 0.5, axis="X", segments=12)


def grinder_label(bm):
    # On the left side (the spout covers the front); read from that side, so along -Y.
    def place(x, up, depth):
        return Vector((-1.42 - depth, -x, 2.3 + up))
    B.add_text(bm, "CENTRAL", 0.5, 0.03, place)


B.piece("MeatGrinder_Body", RED, grinder_body)
B.piece("MeatGrinder_Feet", DARK, grinder_feet)
B.piece("MeatGrinder_Hopper", STEEL, grinder_hopper)
B.piece("MeatGrinder_Spout", STEEL, grinder_spout)
B.piece("MeatGrinder_Crank", DARK, grinder_crank)
B.piece("MeatGrinder_Label", YELLOW, grinder_label, smooth=False)

# The grinder stands at x = 0; the next items are built at their own origins (each item is placed by code).

# ---------------------------------------------------------------- MeatBag (about 2 wide, 2.6 tall)


def bag_sack(bm):
    # A fat sack: a lathe bulging at the middle and gathered at the neck.
    H.lathe_z(bm, [(0.0, 0.0), (0.8, 0.0), (1.05, 0.5), (1.1, 1.2), (0.9, 1.9), (0.35, 2.25), (0.3, 2.3),
                   (0.0, 2.3)], segments=20)
    # The ruffled top above the tie.
    H.lathe_z(bm, [(0.0, 2.35), (0.3, 2.35), (0.55, 2.7), (0.4, 2.75), (0.0, 2.65)], segments=14)


def bag_tie(bm):
    H.torus(bm, (0, 0, 2.33), 0.34, 0.08, segments=16, sides=6)


def bag_label(bm):
    B.add_text(bm, "STEAKS", 0.34, 0.03, H.on_cylinder((0, 0, 0), 1.1, 1.15))


B.piece("MeatBag_Sack", BURLAP, bag_sack)
B.piece("MeatBag_Tie", ROPE, bag_tie)
B.piece("MeatBag_Label", LABEL_RED, bag_label, smooth=False)

# ---------------------------------------------------------------- Cow (about 2.4 wide, 5 long, 3.6 tall; front -Y)


def cow_body(bm):
    H.rounded_box(bm, Vector((0, 0.3, 2.1)), (2.2, 3.6, 1.8), 0.7, segments=3)
    # Legs.
    for x in (-0.75, 0.75):
        for y in (-0.9, 1.5):
            H.rounded_box(bm, Vector((x, y, 0.75)), (0.55, 0.55, 1.3), 0.2, segments=2)
    # The head, big and cartoony, and its ears.
    H.rounded_box(bm, Vector((0, -1.9, 2.9)), (1.5, 1.3, 1.4), 0.45, segments=3)
    for side in (-1, 1):
        H.sphere(bm, Vector((side * 0.95, -1.75, 3.35)), 0.3, scale=(1.3, 0.6, 0.6), segments=10, rings=5)
    # The tail.
    H.cylinder(bm, Vector((0, 2.15, 2.4)), 0.08, 1.0, axis="Y", segments=6)


def cow_spots(bm):
    # Black patches sitting on the body's sides and back.
    spots = [((1.11, 0.0, 2.2), (0.12, 0.9, 0.6)), ((1.11, 1.2, 1.9), (0.12, 0.6, 0.5)), ((-1.11, 0.6, 2.3), (0.12, 1.0, 0.7)),
             ((0.2, 0.9, 3.01), (0.9, 0.8, 0.12)), ((-0.3, -0.4, 3.01), (0.6, 0.6, 0.12))]
    for centre, size in spots:
        H.rounded_box(bm, Vector(centre), size, 0.05, segments=1)
    # One around an eye.
    H.rounded_box(bm, Vector((0.4, -2.56, 3.15)), (0.45, 0.06, 0.45), 0.02, segments=1)


def cow_snout(bm):
    H.rounded_box(bm, Vector((0, -2.65, 2.55)), (1.25, 0.5, 0.75), 0.22, segments=2)
    # The udder.
    H.sphere(bm, Vector((0, 1.0, 1.15)), 0.45, scale=(1, 1, 0.6), segments=10, rings=5)


def cow_horns(bm):
    for side in (-1, 1):
        H.cylinder(bm, Vector((side * 0.55, -1.85, 3.75)), 0.14, 0.55, segments=8, radius2=0.04)


def cow_eyes(bm):
    for side in (-1, 1):
        H.sphere(bm, Vector((side * 0.38, -2.58, 3.15)), 0.14, segments=8, rings=4)
    for side in (-1, 1):
        H.sphere(bm, Vector((side * 0.28, -2.92, 2.55)), 0.09, segments=6, rings=3)


def cow_hooves(bm):
    for x in (-0.75, 0.75):
        for y in (-0.9, 1.5):
            H.cylinder(bm, Vector((x, y, 0.14)), 0.3, 0.28, segments=10)
    H.sphere(bm, Vector((0, 2.65, 1.95)), 0.2, scale=(1, 1, 1.4), segments=8, rings=4)


B.piece("Cow_Body", WHITE, cow_body)
B.piece("Cow_Spots", BLACK, cow_spots)
B.piece("Cow_Snout", PINK, cow_snout)
B.piece("Cow_Horns", CREAM, cow_horns)
B.piece("Cow_Eyes", BLACK, cow_eyes)
B.piece("Cow_Hooves", BLACK, cow_hooves)

# ---------------------------------------------------------------- MeatMound (about 2 across, 1.3 tall)

rng = random.Random(7)


def mound_meat(bm):
    # A lumpy heap of ground meat: one big squashed ball and a ring of smaller lumps, each placed by its own matrix.
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=1.0,
                              matrix=Matrix.Translation((0, 0, 0.45)) @ Matrix.Diagonal((1.0, 1.0, 0.8, 1)))
    for k in range(9):
        a = 2 * math.pi * k / 9 + rng.uniform(-0.2, 0.2)
        r = rng.uniform(0.6, 0.85)
        size = rng.uniform(0.28, 0.42)
        bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=5, radius=size,
                                  matrix=Matrix.Translation((r * math.cos(a), r * math.sin(a), 0.25 + rng.uniform(0.0, 0.7))))


B.piece("MeatMound_Meat", MEAT, mound_meat)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if argv:
    bpy.ops.wm.save_as_mainfile(filepath=argv[0])
if len(argv) >= 2:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in B.coll.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=argv[1], export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
print("KITCHEN EXTRAS BUILT:", [o.name for o in B.coll.objects])
