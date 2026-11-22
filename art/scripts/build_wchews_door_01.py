# W Chews' EMPLOYEES ONLY double door (GAME_DESIGN §40.7; user 2026-11-22: "make the entrance door way more
# noticable, like a double door, and the mafia boss cow can push open both of them at the same time"). It replaces the
# kit's single WcStaffDoor (6 x 9, dark green) and stands in the MIDDLE of the kitchen's back wall.
#
# ONE item, WcDoubleDoor, built in its own space: x across (the doorway's middle at 0; +x is the walking-in player's
# RIGHT), y through the wall (0 = the wall's middle line; the kitchen is at -y, the back room at +y), z up.
#
#   _Frame      walnut: the two jambs, the head, the door stops, and a pitched pediment on the kitchen's side
#   _Trim       brass: the cornice, the pediment's edges, the jambs' feet, the lamps' brackets and the round lamp's ring
#   _Lamps      warm glow: a lantern either side, a row of bulbs over the doors, a round lamp in the pediment
#   _LeafL...   the left leaf (x < 0), "EMPLOYEES" on it;  _LeafR... the right leaf (x > 0), "ONLY" on it. Each leaf is
#               five pieces that swing together: the red slab, its Brass (kick plates, pull bar, the window's rings,
#               the plaque's border, the hinges), its navy Plate, its glowing Text and its glowing round Window.
#
# THE RULES IT IS BUILT TO (the single door flashed two colours where its frame lay in the wall's cut edges, and cut
# through its frame when open; memory "No flicker, no overlap"):
#   - the frame's inner faces stand 0.1 INTO the doorway from the wall's cut edges (x 7.9 against 8.0, the head's
#     underside 12.9 against 13.0), and its faces stand 0.4 proud of the wall on both sides;
#   - each leaf hangs on its OUTER edge (x 7.6) and turns on the corner of that edge on the back room's side
#     (y 0.15): opened 90 degrees into the back room it lies between x 7.3 and 7.6, 0.3 clear of its jamb (x 7.9),
#     and nothing on a leaf's back face stands more than 0.11 proud within the frame's depth;
#   - the two leaves meet with 0.1 between them and swing away from each other (the right leaf's brass meeting
#     strip covers that gap from the kitchen, 0.05 clear in front of the left leaf);
#   - every layer on a leaf (panels, plates, letters, the window) stands at least 0.05 proud of what it lies on.
# The doorway's size and the hinges' places come from art/scripts/wchews_layout.py, which the hall's shell
# (build_wchews_hall_02.py) and the game (KitchenBackDoor) read too.
#
#   blender -b --factory-startup --python art/scripts/build_wchews_door_01.py -- <out.blend> [<out.glb>]

import json
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, r"D:\Powerlifting Roblox\art\scripts")
import importlib  # noqa: E402

import prop_helpers as H  # noqa: E402
import wchews_layout as L  # noqa: E402

importlib.reload(H)
importlib.reload(L)

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

B = H.Builder("WChewsDoor")

WOOD = H.material("Wc_Walnut", (0.26, 0.14, 0.07), roughness=0.55)
BRASS = H.material("Wc_Brass", (0.86, 0.64, 0.22), metallic=0.9, roughness=0.3)
DOOR_RED = H.material("Wc_DoorRed", (0.56, 0.07, 0.10), roughness=0.45)
NAVY = H.material("Wc_Navy", (0.05, 0.08, 0.21), roughness=0.55)
GLOW_WARM = H.material("Wc_GlowWarm", (1.0, 0.80, 0.55), emission=(1.0, 0.72, 0.38))
GLOW_YELLOW = H.material("Wc_GlowYellow", (1.0, 0.84, 0.25), emission=(1.0, 0.78, 0.15))

V = Vector
S = H.span

HALF = L.DOOR_HALF  # the doorway is cut from -HALF to HALF
HIGH = L.DOOR_HEIGHT
HINGE = L.LEAF_HINGE  # a leaf's hung edge
T = L.LEAF_HALF_THICK  # half a leaf's slab
WALL = L.WALL / 2  # the wall's faces are at -WALL (kitchen) and WALL (back room; its panelling is 0.3 thicker)
JAMB_IN = HALF - 0.1  # the frame's inner faces, 0.1 into the doorway
JAMB_OUT = HALF + 1.4
HEAD = HIGH - 0.1  # the head's underside
Y_FRONT, Y_BACK = -WALL - 0.4, WALL + 0.7  # 0.4 proud of the kitchen's tiles and of the back room's panelling
FRIEZE_TOP = 14.8
CORNICE = (14.6, 15.1)
PEDIMENT_HALF, PEDIMENT_TOP = JAMB_OUT + 1.2, 18.5
LEAF_LOW, LEAF_TOP = 0.08, HEAD - 0.2
FREE = 0.05  # a leaf's free edge: the two leaves stand 0.1 apart
LAMP_X, LAMP_Z = JAMB_OUT + 2.2, 9.6
PLAQUE = (0.55, 7.05, 9.75, 11.55)  # on a leaf's kitchen face: |x| from, to; z from, to
PLAQUE_X = (PLAQUE[0] + PLAQUE[1]) / 2
WINDOW_Z, WINDOW_R = 7.5, 1.25
TEXT_SIZE = 1.15


def prism_y(bm, points, y0, y1):
    """A solid from an outline in the XZ plane, from y0 to y1."""
    front = [bm.verts.new((x, y0, z)) for x, z in points]
    back = [bm.verts.new((x, y1, z)) for x, z in points]
    made = [bm.faces.new(front), bm.faces.new(list(reversed(back)))]
    n = len(points)
    for i in range(n):
        j = (i + 1) % n
        made.append(bm.faces.new((front[i], back[i], back[j], front[j])))
    bmesh.ops.recalc_face_normals(bm, faces=made)


# ----------------------------------------------------------------------- the frame

def frame(bm):
    for s in (-1, 1):
        S(bm, (s * JAMB_IN, Y_FRONT, 0.0), (s * JAMB_OUT, Y_BACK, FRIEZE_TOP))  # the jambs
        # The stops the leaves shut against, on the kitchen's side: they cover the gap at each hung edge.
        S(bm, (s * (HINGE - 0.15), -0.55, 0.0), (s * JAMB_IN, -T - 0.05, HEAD))
    S(bm, (-JAMB_IN, Y_FRONT, HEAD), (JAMB_IN, Y_BACK, FRIEZE_TOP))  # the head, and the frieze over it
    S(bm, (-JAMB_IN, -0.55, LEAF_TOP - 0.2), (JAMB_IN, -T - 0.05, HEAD))  # the head's stop
    # The pediment: a low gable over the doors (its back half is inside the wall).
    prism_y(bm, [(-PEDIMENT_HALF, CORNICE[1] - 0.1), (PEDIMENT_HALF, CORNICE[1] - 0.1), (0.0, PEDIMENT_TOP)],
            -WALL - 0.7, -WALL + 0.5)


def trim(bm):
    S(bm, (-PEDIMENT_HALF - 0.3, -WALL - 0.95, CORNICE[0]), (PEDIMENT_HALF + 0.3, -WALL + 0.5, CORNICE[1]))  # the cornice
    # The pediment's two raking edges.
    rise, run = PEDIMENT_TOP - CORNICE[1] + 0.1, PEDIMENT_HALF
    length, angle = math.hypot(rise, run), math.atan2(rise, run)
    for s in (-1, 1):
        mid = V((s * run / 2, -WALL - 0.2, (CORNICE[1] - 0.1 + PEDIMENT_TOP) / 2))
        normal = V((s * math.sin(angle), 0, math.cos(angle)))
        H.box(bm, mid + normal * 0.12, (length, 1.3, 0.3), rotation=Matrix.Rotation(s * angle, 4, "Y"))
        # The jambs' feet (0.1 into the doorway on the kitchen's side of the stops, 0.15 proud of the jamb elsewhere).
        S(bm, (s * (JAMB_IN - 0.1), Y_FRONT - 0.15, 0.0), (s * (JAMB_OUT + 0.15), -0.6, 1.2))
        # A lantern's bracket either side: a plate on the wall, an arm, and a cup under the globe.
        S(bm, (s * (LAMP_X - 0.35), -WALL - 0.12, LAMP_Z - 1.5), (s * (LAMP_X + 0.35), -WALL + 0.3, LAMP_Z - 0.3))
        S(bm, (s * (LAMP_X - 0.1), -WALL - 0.95, LAMP_Z - 1.0), (s * (LAMP_X + 0.1), -WALL, LAMP_Z - 0.8))
        H.cylinder(bm, V((s * LAMP_X, -WALL - 0.95, LAMP_Z - 0.72)), 0.4, 0.3, segments=12, radius2=0.52)
    # The ring round the pediment's lamp.
    H.torus(bm, V((0, -WALL - 0.76, 16.25)), 0.86, 0.13, plane="XZ", segments=24, sides=8)


def lamps(bm):
    for s in (-1, 1):
        H.sphere(bm, V((s * LAMP_X, -WALL - 0.95, LAMP_Z)), 0.62, segments=14, rings=8)
    for k in range(9):  # the row of bulbs along the frieze
        H.sphere(bm, V((-7.0 + 1.75 * k, Y_FRONT - 0.08, 13.78)), 0.24, segments=10, rings=6)
    H.cylinder(bm, V((0, -WALL - 0.55, 16.25)), 0.8, 0.5, axis="Y", segments=20)  # (0.1 proud of the pediment)


B.piece("WcDoubleDoor_Frame", WOOD, frame, smooth=False)
B.piece("WcDoubleDoor_Trim", BRASS, trim)
B.piece("WcDoubleDoor_Lamps", GLOW_WARM, lamps)


# ----------------------------------------------------------------------- the leaves (s = -1 the left, 1 the right)

def leaf(s):
    def build(bm):
        S(bm, (s * FREE, -T, LEAF_LOW), (s * HINGE, T, LEAF_TOP))
        for side in (-1, 1):  # a raised panel low on both faces, and a tall one on the back room's face
            S(bm, (s * 0.85, side * T, 1.9), (s * 6.8, side * (T + 0.06), 5.6))
        S(bm, (s * 0.85, T, 9.6), (s * 6.8, T + 0.06, 11.9))
    return build


def leaf_brass(s):
    def build(bm):
        for side in (-1, 1):
            S(bm, (s * 0.3, side * T, 0.2), (s * 7.3, side * (T + 0.05), 1.3))  # the kick plates
            # The ring round the window, on both faces.
            H.torus(bm, V((s * PLAQUE_X, side * (T + 0.04), WINDOW_Z)), WINDOW_R + 0.08, 0.14, plane="XZ", segments=28,
                    sides=8)
        # The pull bar on the kitchen's face, near the free edge, and a push plate behind it on the back room's.
        H.cylinder(bm, V((s * 1.0, -T - 0.42, 6.4)), 0.11, 3.2, segments=10)
        for z in (5.1, 7.7):
            H.cylinder(bm, V((s * 1.0, -T - 0.2, z)), 0.07, 0.44, axis="Y", segments=8)
        S(bm, (s * 0.5, T, 5.2), (s * 1.5, T + 0.05, 7.6))
        # The plaque's border (0.06 proud of the plate).
        x0, x1, z0, z1 = PLAQUE
        y0, y1 = -T - 0.14, -T + 0.02
        S(bm, (s * (x0 - 0.12), y0, z0 - 0.12), (s * (x1 + 0.12), y1, z0))
        S(bm, (s * (x0 - 0.12), y0, z1), (s * (x1 + 0.12), y1, z1 + 0.12))
        S(bm, (s * (x0 - 0.12), y0, z0), (s * x0, y1, z1))
        S(bm, (s * x1, y0, z0), (s * (x1 + 0.12), y1, z1))
        # Three hinges on the hinge line itself (they turn on their own axes).
        for z in (1.5, 6.4, 11.3):
            H.cylinder(bm, V((s * HINGE, T, z)), 0.11, 0.7, segments=10)
        if s > 0:
            # The right leaf's meeting strip: on its own face, and 0.05 clear in front of the left leaf's edge, so
            # no light shows between the shut leaves and neither cuts the other as they swing apart.
            S(bm, (FREE, -T - 0.11, LEAF_LOW), (0.3, -T, LEAF_TOP))
            S(bm, (-FREE - 0.1, -T - 0.11, LEAF_LOW), (FREE, -T - 0.05, LEAF_TOP))
    return build


def leaf_plate(s):
    def build(bm):
        x0, x1, z0, z1 = PLAQUE
        S(bm, (s * x0, -T - 0.08, z0), (s * x1, -T + 0.02, z1))
    return build


def leaf_text(s, word):
    def build(bm):
        # (its back 0.02 inside the plate, its face 0.06 proud of it)
        B.add_text(bm, word, TEXT_SIZE, 0.04, H.on_front((s * PLAQUE_X, 0, 0), -T - 0.06, (PLAQUE[2] + PLAQUE[3]) / 2))
    return build


def leaf_window(s):
    def build(bm):
        # A glowing round window, through the leaf: 0.05 proud of the slab on both faces.
        H.cylinder(bm, V((s * PLAQUE_X, 0, WINDOW_Z)), WINDOW_R, 2 * T + 0.1, axis="Y", segments=28)
    return build


for s, side, word in ((-1, "L", "EMPLOYEES"), (1, "R", "ONLY")):
    B.piece(f"WcDoubleDoor_Leaf{side}", DOOR_RED, leaf(s), smooth=False)
    B.piece(f"WcDoubleDoor_Leaf{side}Brass", BRASS, leaf_brass(s))
    B.piece(f"WcDoubleDoor_Leaf{side}Plate", NAVY, leaf_plate(s), smooth=False)
    text = B.piece(f"WcDoubleDoor_Leaf{side}Text", GLOW_YELLOW, leaf_text(s, word), smooth=False)
    B.piece(f"WcDoubleDoor_Leaf{side}Window", GLOW_WARM, leaf_window(s))
    width = text.dimensions.x
    print(f"TEXT {word}: {width:.2f} wide in a {PLAQUE[1] - PLAQUE[0]:.2f} plate")
    if width > PLAQUE[1] - PLAQUE[0] - 0.3:
        raise RuntimeError(f"'{word}' ({width:.2f} wide) doesn't fit its plate")

# The item's bounds (the game pivots a copy at the bottom centre of its bounds: the layout needs that offset).
bpy.context.view_layer.update()
lo = Vector((1e9, 1e9, 1e9))
hi = -lo
for ob in B.coll.objects:
    for corner in ob.bound_box:
        w = ob.matrix_world @ Vector(corner)
        lo = Vector(map(min, lo, w))
        hi = Vector(map(max, hi, w))
bounds = {"WcDoubleDoor": {"low": [round(v, 4) for v in lo], "high": [round(v, 4) for v in hi]}}

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if argv:
    bpy.ops.wm.save_as_mainfile(filepath=argv[0])
    with open(argv[0].replace(".blend", "_bounds.json"), "w", encoding="utf-8") as handle:
        json.dump(bounds, handle, indent=1)
if len(argv) >= 2:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in B.coll.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=argv[1], export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
tris = sum(len(p.vertices) - 2 for o in B.coll.objects for p in o.data.polygons)
print("WCHEWS DOOR BUILT:", len(B.coll.objects), "objects,", tris, "triangles; bounds", bounds)
