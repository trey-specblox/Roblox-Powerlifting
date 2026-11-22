# The meet spotters' CENTRAL shirt print (GAME_DESIGN §37.5: "3 spotters bald, Central shirt ..."), front and back,
# shaped onto the Fat build's tee (the spotters' build, LifterBuild.BuildRules.Spotter) so every letter lies on the
# shirt. Replaces MeetFigures' flat transparent card with a SurfaceGui, which stood 0.12 - 0.27 studs off the shirt
# (a flat card in front of a round chest; user 2026-11-20: "if my assessories were floating i would tell you").
#
#   SpotterPrint_Front, SpotterPrint_Back   white letters on the chest and across the upper back
#
# Built in the figure's ROOT SPACE (the HumanoidRootPart's centre at the origin, front toward -Y, z up), on the
# uploaded tee (art/blender/CartoonGear_07.blend, the v13 crew neck). MeetFigures welds both to the UpperTorso.
#
#   blender -b --factory-startup --python art/scripts/build_spotter_print_01.py -- <out.blend> [<out.glb>]

import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, r"D:\Powerlifting Roblox\art\scripts")
import importlib  # noqa: E402

import prop_helpers as H  # noqa: E402

importlib.reload(H)

ROOT = r"D:\Powerlifting Roblox"
GEAR_BLEND = os.path.join(ROOT, "art", "blender", "CartoonGear_07.blend")
BUILD = "Fat"
ROOT_NODE = 3.0

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
B = H.Builder("SpotterPrint")
WHITE = H.material("SpotterPrint_White", (0.95, 0.95, 0.95), roughness=0.6)

with bpy.data.libraries.load(GEAR_BLEND, link=False) as (src, dst):
    dst.objects = [BUILD + "Rig"] + [n for n in src.objects if n.startswith(BUILD + "_Tee__")]
rig = next(o for o in dst.objects if o and o.name.startswith(BUILD + "Rig"))
to_root = Matrix.Translation(-(rig.matrix_world.translation + Vector((0, 0, ROOT_NODE))))
tee_bm = bmesh.new()
for o in dst.objects:
    if o is not None and o.type == "MESH":
        me = o.data.copy()
        me.transform(to_root @ o.matrix_world)
        tee_bm.from_mesh(me)
        bpy.data.meshes.remove(me)
for o in dst.objects:
    if o is not None:
        bpy.data.objects.remove(o, do_unlink=True)
TEE = BVHTree.FromBMesh(tee_bm)

LIFT = 0.006           # the letters' back off the shirt
DEPTH = 0.012          # their thickness
FRONT_Z = 0.95         # the print's middle (root space, up): the old card's height (upper torso centre + 0.2)
BACK_Z = 1.05
SIZE = 0.24


def on_tee(side):
    """place() for text lying on the tee, seen from the front (side -1) or the back (side +1)."""
    z_mid = FRONT_Z if side < 0 else BACK_Z

    def place(x, up, depth):
        # seen from behind, the text's x runs the other way so it reads correctly
        px = x if side < 0 else -x
        start = Vector((px, side * 4.0, z_mid + up))
        loc, normal, _i, _d = TEE.ray_cast(start, Vector((0, -side, 0)), 8.0)
        if loc is None:
            raise RuntimeError("the print missed the shirt at x %.2f" % px)
        if normal.y * side < 0:
            normal = -normal
        return loc + normal * (LIFT + depth)
    return place


def front(bm):
    B.add_text(bm, "CENTRAL", SIZE, DEPTH / 2, on_tee(-1))


def back(bm):
    # (mirrored left-right so it reads from behind, and its depth runs the other way too: the faces stay outward)
    B.add_text(bm, "CENTRAL", SIZE * 1.15, DEPTH / 2, on_tee(1))


B.piece("SpotterPrint_Front", WHITE, front, smooth=False)
B.piece("SpotterPrint_Back", WHITE, back, smooth=False)
tee_bm.free()

bpy.context.view_layer.update()
lo = Vector((1e9, 1e9, 1e9))
hi = -lo
for ob in B.coll.objects:
    for corner in ob.bound_box:
        w = ob.matrix_world @ Vector(corner)
        lo = Vector(map(min, lo, w))
        hi = Vector(map(max, hi, w))
print(f"BOUNDS SpotterPrint lo {tuple(round(v, 3) for v in lo)} hi {tuple(round(v, 3) for v in hi)}")

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if argv:
    bpy.ops.wm.save_as_mainfile(filepath=argv[0])
if len(argv) >= 2:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in B.coll.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=argv[1], export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
print("SPOTTER PRINT BUILT:", [o.name for o in B.coll.objects])
