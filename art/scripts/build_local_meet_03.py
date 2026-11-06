# Builds LocalMeet_03: the chalk stand each lifter chalks up at in the warm-up room (GAME_DESIGN 37.5, from the user's
# photos, 2026-11-06: a stainless bowl of chalk blocks on a black square post with a cross-shaped foot).
#
#   MeetChalkStand  black crossed feet with rubber caps, a square post with its bolts and CENTRAL down it, a yellow
#                   collar, a hollow stainless bowl with white chalk blocks and loose powder in it, and two spare
#                   blocks by the foot. Sized for the game's blocky bodies: the bowl is at a lifter's waist and wide
#                   enough for both hands. One mesh reused on every platform.
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, it stands on z = 0 with its front toward -Y.
# Objects are "<Item>_<Piece>" with ONE material each.
#
#   blender -b --python art/scripts/build_local_meet_03.py -- <out.blend> <out.glb> <preview.png>
# Then, before uploading: blender -b <out.blend> --python art/scripts/check_models.py (must say CHECK PASSED).

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

# (Blender's start-up scene, so nothing but the stand ends up in the file.)
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

B = H.Builder("LocalMeet_03")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.5):
    return H.material("LM3_" + name, tuple(linear(c) for c in rgb), metallic, roughness)


# Preview colours (Roblox colours each piece from StarterGymConfig.PropColourways).
BLACK = mat("Black", (24, 24, 26), 0.2, 0.45)
STEEL = mat("Steel", (205, 208, 214), 1.0, 0.22)
YELLOW = mat("Yellow", (242, 190, 30), 0.0, 0.4)
WHITE = mat("White", (240, 240, 236), 0.0, 0.75)
LOGO = mat("Logo", (236, 236, 232), 0.0, 0.4)

BOWL_RADIUS = 0.95
RIM_Z = 2.95
BOWL_DEPTH = 0.62
POST = 0.3
POST_TOP = RIM_Z - BOWL_DEPTH + 0.04
FOOT_REACH = 1.2
FOOT_H = 0.16
TURN = Matrix.Rotation(math.radians(45), 4, "Z")


def feet(bm):
    # Two crossed tubes, turned 45 degrees so the corners stay clear of the lifter's feet.
    H.box(bm, Vector((0, 0, FOOT_H / 2 + 0.05)), Vector((2 * FOOT_REACH, 0.22, FOOT_H)), TURN)
    H.box(bm, Vector((0, 0, FOOT_H / 2 + 0.05)), Vector((0.22, 2 * FOOT_REACH, FOOT_H)), TURN)
    H.box(bm, Vector((0, 0, FOOT_H + 0.08)), Vector((0.46, 0.46, 0.05)), TURN)


def caps(bm):
    for k in range(4):
        a = math.radians(45 + 90 * k)
        at = Vector((math.cos(a) * FOOT_REACH, math.sin(a) * FOOT_REACH, 0.11))
        H.box(bm, at, Vector((0.14, 0.27, 0.22)), Matrix.Rotation(a + math.pi / 2, 4, "Z"))


def post(bm):
    H.box(bm, Vector((0, 0, (POST_TOP + 0.2) / 2)), Vector((POST, POST, POST_TOP - 0.2)))


def bolts(bm):
    # Two bolts through the post's front, like the photo's.
    for z in (0.62, 1.86):
        H.cylinder(bm, Vector((0, -POST / 2 - 0.012, z)), 0.05, 0.03, axis="Y", segments=8)


def collar(bm):
    H.cylinder(bm, Vector((0, 0, POST_TOP - 0.03)), 0.27, 0.1, segments=20)


def bowl(bm):
    # A hollow bowl: outside from the foot up to a rolled rim, then back down inside. A closed outline, so it has a
    # real inside and outside, and both draw.
    z0 = RIM_Z - BOWL_DEPTH
    wall = 0.05
    outline = [(0.0, z0)]
    for k in range(1, 9):
        u = k / 8
        outline.append((BOWL_RADIUS * math.sin(u * math.pi / 2), z0 + BOWL_DEPTH * (1 - math.cos(u * math.pi / 2))))
    outline += [(BOWL_RADIUS + 0.04, RIM_Z + 0.015), (BOWL_RADIUS + 0.02, RIM_Z + 0.05), (BOWL_RADIUS - 0.04, RIM_Z + 0.03)]
    for k in range(8, -1, -1):
        u = k / 8
        outline.append(((BOWL_RADIUS - wall) * math.sin(u * math.pi / 2),
                        z0 + wall + (BOWL_DEPTH - wall) * (1 - math.cos(u * math.pi / 2))))
    H.lathe_z(bm, outline, 24)


def chalk(bm):
    # Loose powder filling the bowl, a soft low mound.
    z0 = RIM_Z - BOWL_DEPTH + 0.05
    H.lathe_z(bm, [(0.0, z0), (0.62, z0 + 0.2), (0.82, z0 + 0.33), (0.8, z0 + 0.36), (0.45, z0 + 0.42), (0.0, z0 + 0.45)], 24)
    # Blocks half sunk in it, each at its own angle.
    blocks = (
        (Vector((-0.34, -0.2, z0 + 0.5)), Vector((0.52, 0.4, 0.26)), 18, 8),
        (Vector((0.36, -0.12, z0 + 0.46)), Vector((0.46, 0.36, 0.24)), -32, -10),
        (Vector((0.02, 0.38, z0 + 0.5)), Vector((0.56, 0.38, 0.26)), 62, 12),
    )
    for at, size, spin, tip in blocks:
        turn = Matrix.Rotation(math.radians(spin), 4, "Z") @ Matrix.Rotation(math.radians(tip), 4, "X")
        H.rounded_box(bm, at, size, 0.03, 1, turn)
    # Two spare blocks on the floor by the foot.
    H.rounded_box(bm, Vector((0.88, -0.3, 0.13)), Vector((0.5, 0.38, 0.26)), 0.03, 1, Matrix.Rotation(0.4, 4, "Z"))
    H.rounded_box(bm, Vector((-0.92, 0.42, 0.13)), Vector((0.46, 0.36, 0.26)), 0.03, 1, Matrix.Rotation(-0.7, 4, "Z"))


def logo(bm):
    # CENTRAL up the post's front. (x, y, z) -> (-up, -depth, x) is a turn, not a mirror, so it reads and stays one-sided.
    def place(x, up, depth):
        return Vector((-up, -POST / 2 - depth, 1.24 + x))

    B.add_text(bm, "CENTRAL", 0.19, 0.006, place)


def frame(bm):
    feet(bm)
    caps(bm)
    post(bm)


def steel(bm):
    bowl(bm)
    bolts(bm)


# Five pieces, so five MeshParts per stand: one colour each, everything of a colour in one mesh.
objects = [
    B.piece("MeetChalkStand_Frame", BLACK, frame, smooth=False),
    B.piece("MeetChalkStand_Collar", YELLOW, collar),
    B.piece("MeetChalkStand_Bowl", STEEL, steel),
    B.piece("MeetChalkStand_Chalk", WHITE, chalk),
    B.piece("MeetChalkStand_Logo", LOGO, logo, smooth=False),
]

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(argv) >= 1:
    bpy.ops.wm.save_as_mainfile(filepath=argv[0])
if len(argv) >= 2:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=argv[1], export_format="GLB", use_selection=True, export_apply=True)
if len(argv) >= 3:
    # Previews as Roblox draws it: one-sided faces. The whole stand from the front, then looking down into the bowl.
    scene = bpy.context.scene
    camera = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.lens = 50
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_backface_culling = True
    scene.display.shading.show_shadows = True
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.55, 0.57, 0.6)
    scene.display.shading.background_type = "WORLD"
    scene.render.resolution_x, scene.render.resolution_y = 800, 800
    root, ext = os.path.splitext(argv[2])
    for suffix, eye, target in (("_Front", (3.0, -7.5, 3.0), (0, 0, 1.55)), ("_Bowl", (1.5, -3.4, 5.6), (0, 0, 2.6))):
        camera.location = Vector(eye)
        camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = root + suffix + ext
        bpy.ops.render.render(write_still=True)
print("LocalMeet_03 built:", sorted(o.name for o in B.coll.objects))
print("DONE")
