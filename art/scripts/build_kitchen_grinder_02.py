# The W Chews hero meat grinder (GAME_DESIGN §40.7; user 2026-11-21: a "large hero machine for the meat blender", from
# the user's photo of a commercial stainless mixer-grinder: a big tub with a rounded bottom, the grinding head and outlet
# out of one end, a motor box under it, a tall cabinet panel, a square-tube frame on red caster wheels, a black coiled
# cord and caution stickers). Replaces the squat red KitchenExtras_01 MeatGrinder in the Kitchen.
#
#   MeatGrinder_Hopper   the open tub (the bag or cow drops in here; KitchenScene reads its top)
#   MeatGrinder_Spout    the outlet the meat squirts from, pointing to the FRONT (-Y; KitchenScene reads its look)
#   MeatGrinder_Head     the grinding head's barrel and collar between the tub and the outlet
#   MeatGrinder_Rim      the tub's rolled top rim
#   MeatGrinder_Frame    the square-tube frame (legs and rails)
#   MeatGrinder_Motor    the motor box under the tub
#   MeatGrinder_Cabinet  the tall panel at the back end
#   MeatGrinder_Casters  the wheel forks and stems; MeatGrinder_Wheels the red wheels
#   MeatGrinder_Cord     the black coiled power cord and its plug
#   MeatGrinder_Plate / _PlateText   a navy CENTRAL nameplate on the left side (memory: gear brand CENTRAL)
#   MeatGrinder_Caution  the yellow caution plates
#
# Units: studs (the game scales it by KitchenConfig.GrinderScale); z up; the front (the outlet) toward -Y. About 6.4 wide,
# 15 long, 10 tall. Builder stops on any inside-out piece; run check_models.py before export.
#
#   blender -b --factory-startup --python art/scripts/build_kitchen_grinder_02.py -- <out.blend> [<out.glb>]

import math
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

B = H.Builder("KitchenGrinder")

STEEL = H.material("Grinder_Steel", (0.72, 0.74, 0.77), metallic=0.9, roughness=0.28)
STEEL_DARK = H.material("Grinder_SteelDark", (0.45, 0.47, 0.5), metallic=0.85, roughness=0.35)
RED = H.material("Grinder_WheelRed", (0.82, 0.12, 0.1), roughness=0.45)
BLACK = H.material("Grinder_Black", (0.05, 0.05, 0.06), roughness=0.6)
NAVY = H.material("Grinder_Navy", (0.05, 0.08, 0.21), roughness=0.55)
YELLOW = H.material("Grinder_Yellow", (0.98, 0.8, 0.12), roughness=0.5)

# The tub: a trough along Y, its rounded bottom a half circle.
TUB_W = 3.0          # half width (x)
TUB_Y0, TUB_Y1 = -4.0, 4.0
Z_BOTTOM = 4.5       # the bottom of the rounded part
Z_CENTRE = Z_BOTTOM + TUB_W
Z_TOP = 9.5
WALL = 0.25
END = 0.28           # end plate thickness
HEAD_Z = 5.75        # the grinding head's axis height
HEAD_R = 1.15


def prism(bm, outline, y0, y1):
    """A solid from a closed outline in the XZ plane, from y0 to y1 (faces made outward by recalculating)."""
    tmp = bmesh.new()
    a = [tmp.verts.new((x, y0, z)) for x, z in outline]
    b = [tmp.verts.new((x, y1, z)) for x, z in outline]
    n = len(outline)
    tmp.faces.new(a[::-1])
    tmp.faces.new(b)
    for i in range(n):
        j = (i + 1) % n
        tmp.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.triangulate(tmp, faces=tmp.faces[:])
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)


def arc(cx, cz, r, a0, a1, steps):
    return [(cx + r * math.cos(a0 + (a1 - a0) * k / steps), cz + r * math.sin(a0 + (a1 - a0) * k / steps))
            for k in range(steps + 1)]


def u_outline(half, z_centre, z_top, steps=20):
    """A U: straight sides from z_top down to z_centre, a half circle under."""
    return [(-half, z_top)] + arc(0, z_centre, half, math.pi, 2 * math.pi, steps) + [(half, z_top)]


# ---------------------------------------------------------------- the tub
def tub(bm):
    # The trough wall: the outer U and the inner U (back the other way) make one thick U-shaped outline.
    outer = u_outline(TUB_W, Z_CENTRE, Z_TOP)
    inner = u_outline(TUB_W - WALL, Z_CENTRE, Z_TOP)[::-1]
    prism(bm, outer + inner, TUB_Y0 + END, TUB_Y1 - END)
    # The two end plates (solid U's).
    prism(bm, u_outline(TUB_W, Z_CENTRE, Z_TOP), TUB_Y0, TUB_Y0 + END)
    prism(bm, u_outline(TUB_W, Z_CENTRE, Z_TOP), TUB_Y1 - END, TUB_Y1)


def rim(bm):
    # A rounded lip round the opening: four bars along the top edges, rounded ends overlapping at the corners.
    t = 0.32
    for x in (-TUB_W, TUB_W):
        H.rounded_box(bm, Vector((x, 0, Z_TOP + 0.05)), (t * 1.6, TUB_Y1 - TUB_Y0 + t, t), 0.1, segments=2)
    for y in (TUB_Y0, TUB_Y1):
        H.rounded_box(bm, Vector((0, y, Z_TOP + 0.05)), (2 * TUB_W + t, t * 1.6, t), 0.1, segments=2)


# ---------------------------------------------------------------- the grinding head and outlet (out of the front end)
def head(bm):
    H.cylinder(bm, Vector((0, TUB_Y0 - 1.35, HEAD_Z)), HEAD_R, 2.8, axis="Y", segments=28)
    # the collar where the outlet screws on, and the wing nut on top of the barrel
    H.torus(bm, Vector((0, TUB_Y0 - 2.75, HEAD_Z)), HEAD_R + 0.05, 0.22, plane="XZ", segments=28, sides=8)
    H.cylinder(bm, Vector((0, TUB_Y0 - 1.6, HEAD_Z + HEAD_R + 0.2)), 0.22, 0.5, segments=10)
    H.cylinder(bm, Vector((0, TUB_Y0 - 1.6, HEAD_Z + HEAD_R + 0.5)), 0.12, 1.1, axis="X", segments=8)


def spout(bm):
    # The outlet ring and its cutting plate; the hand wheel ring round it (the photo's big loop).
    H.cylinder(bm, Vector((0, TUB_Y0 - 3.15, HEAD_Z)), HEAD_R - 0.1, 0.8, axis="Y", segments=28)
    H.torus(bm, Vector((0, TUB_Y0 - 3.3, HEAD_Z)), HEAD_R + 0.35, 0.09, plane="XZ", segments=32, sides=6)
    H.cylinder(bm, Vector((0, TUB_Y0 - 3.6, HEAD_Z)), HEAD_R - 0.05, 0.1, axis="Y", segments=28)


def guard(bm):
    # The square hood over the outlet (the photo's angled box): a slab tipped forward over it.
    H.rounded_box(bm, Vector((0, TUB_Y0 - 4.05, HEAD_Z + 1.15)), (2.4, 1.4, 0.18), 0.05, segments=1,
                  rotation=Matrix.Rotation(math.radians(-30), 4, "X"))


# ---------------------------------------------------------------- the stand
LEG_X, LEG_Y = 2.65, 3.55
LEG_LOW, LEG_HIGH = 1.25, Z_BOTTOM + 0.6


def frame(bm):
    s = 0.42
    for x in (-LEG_X, LEG_X):
        for y in (-LEG_Y, LEG_Y):
            H.box(bm, Vector((x, y, (LEG_LOW + LEG_HIGH) / 2)), (s, s, LEG_HIGH - LEG_LOW))
    for z in (LEG_LOW + s / 2, LEG_HIGH - s / 2):
        for x in (-LEG_X, LEG_X):
            H.box(bm, Vector((x, 0, z)), (s, 2 * LEG_Y - s, s))
        for y in (-LEG_Y, LEG_Y):
            H.box(bm, Vector((0, y, z)), (2 * LEG_X - s, s, s))
    # the saddles the tub sits in
    for y in (-2.2, 2.2):
        H.box(bm, Vector((0, y, Z_BOTTOM + 0.15)), (2 * LEG_X, 0.42, 0.3))


def motor(bm):
    H.rounded_box(bm, Vector((0, 0.4, (LEG_LOW + 0.4 + Z_BOTTOM - 0.25) / 2)), (3.8, 4.4, Z_BOTTOM - 0.25 - LEG_LOW - 0.4),
                  0.15, segments=2)


def cabinet(bm):
    # The tall panel at the back end, a little taller than the tub's wall, with a slanted top.
    tmp_outline = [(-2.4, LEG_LOW), (2.4, LEG_LOW), (2.4, Z_TOP - 0.6), (-2.4, Z_TOP + 0.2)]
    prism(bm, tmp_outline, TUB_Y1 + 0.05, TUB_Y1 + 0.85)


def casters(bm):
    for x in (-LEG_X, LEG_X):
        for y in (-LEG_Y, LEG_Y):
            H.box(bm, Vector((x, y, 1.12)), (0.7, 0.7, 0.12))                 # the top plate
            for side in (-0.29, 0.29):
                H.box(bm, Vector((x + side, y, 0.82)), (0.08, 0.5, 0.55))     # the fork's two sides
            H.cylinder(bm, Vector((x, y, 0.55)), 0.11, 0.66, axis="X", segments=8)   # the axle


def wheels(bm):
    for x in (-LEG_X, LEG_X):
        for y in (-LEG_Y, LEG_Y):
            H.cylinder(bm, Vector((x, y, 0.55)), 0.55, 0.44, axis="X", segments=20)


def cord(bm):
    # A plug socket on the motor's left side and the cord hanging in two loops.
    H.box(bm, Vector((-1.97, -0.6, 3.6)), (0.14, 0.5, 0.5))
    H.torus(bm, Vector((-2.06, -0.6, 2.55)), 0.62, 0.07, plane="YZ", segments=24, sides=6)
    H.torus(bm, Vector((-2.14, -0.4, 2.35)), 0.55, 0.07, plane="YZ", segments=24, sides=6)
    H.box(bm, Vector((-2.2, -0.15, 1.75)), (0.24, 0.3, 0.38))                   # the plug


def plate(bm):
    H.box(bm, Vector((-TUB_W - 0.06, 0.6, (Z_TOP + Z_CENTRE) / 2 + 0.1)), (0.08, 3.6, 1.1))


def plate_text(bm):
    def place(x, up, depth):
        return Vector((-TUB_W - 0.12 - depth, 0.6 - x, (Z_TOP + Z_CENTRE) / 2 + 0.1 + up))
    B.add_text(bm, "CENTRAL", 0.62, 0.03, place)


def caution(bm):
    # On the front end above the head, and on the right side.
    H.box(bm, Vector((0, TUB_Y0 - 0.05, Z_TOP - 0.75)), (1.6, 0.08, 0.7))
    H.box(bm, Vector((TUB_W + 0.05, -1.8, Z_TOP - 0.9)), (0.08, 1.4, 0.9))


B.piece("MeatGrinder_Hopper", STEEL, tub)
B.piece("MeatGrinder_Rim", STEEL, rim)
B.piece("MeatGrinder_Head", STEEL, head)
B.piece("MeatGrinder_Spout", STEEL, spout)
B.piece("MeatGrinder_Guard", STEEL, guard)
B.piece("MeatGrinder_Frame", STEEL_DARK, frame)
B.piece("MeatGrinder_Motor", STEEL, motor)
B.piece("MeatGrinder_Cabinet", STEEL, cabinet)
B.piece("MeatGrinder_Casters", STEEL_DARK, casters)
B.piece("MeatGrinder_Wheels", RED, wheels)
B.piece("MeatGrinder_Cord", BLACK, cord)
B.piece("MeatGrinder_Plate", NAVY, plate)
B.piece("MeatGrinder_PlateText", YELLOW, plate_text, smooth=False)
B.piece("MeatGrinder_Caution", YELLOW, caution)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if argv:
    bpy.ops.wm.save_as_mainfile(filepath=argv[0])
if len(argv) >= 2:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in B.coll.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=argv[1], export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
lo = Vector([min((o.matrix_world @ Vector(c))[i] for o in B.coll.objects for c in o.bound_box) for i in range(3)])
hi = Vector([max((o.matrix_world @ Vector(c))[i] for o in B.coll.objects for c in o.bound_box) for i in range(3)])
print("KITCHEN GRINDER BUILT:", len(B.coll.objects), "pieces; bounds", tuple(round(v, 2) for v in lo), tuple(round(v, 2) for v in hi))
