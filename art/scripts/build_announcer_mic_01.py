# Builds AnnouncerMic_01: the hand-held microphone of the Nationals announcer (GAME_DESIGN 39, user 2026-11-18: "the
# announcer (a judge), talking to the crowd under a spotlight"). Held in the right hand (MeetFigures.giveMicrophone
# welds it there, the hand closed round the handle), so it is small: about one stud long.
#
#   AnnouncerMic  a black handle, slightly wider toward the top, with a rounded butt; a yellow collar (the game's
#                 yellow) under the head; a round silver grille head with a darker band round its middle.
#
# Units, axes and names as in prop_helpers.py: 1 unit = 1 stud, it stands upright on z = 0 (its butt), so its pivot in
# Roblox is the butt and its length runs up. Objects are "<Item>_<Piece>" with ONE material each.
#
#   blender -b --python art/scripts/build_announcer_mic_01.py -- <out.blend> <out.glb> <preview.png>
# Then, before uploading: blender -b <out.blend> --python art/scripts/check_models.py (must say CHECK PASSED).

import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

# (Blender's start-up scene, so nothing but the microphone ends up in the file.)
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

B = H.Builder("AnnouncerMic_01")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb, metallic=0.0, roughness=0.5):
    return H.material("AM1_" + name, tuple(linear(c) for c in rgb), metallic, roughness)


# Preview colours (Roblox colours each piece from StarterGymConfig.PropColourways).
BLACK = mat("Black", (24, 24, 26), 0.2, 0.45)
YELLOW = mat("Yellow", (242, 190, 30), 0.0, 0.4)
SILVER = mat("Silver", (205, 208, 214), 1.0, 0.3)
CHARCOAL = mat("Charcoal", (46, 48, 54), 0.4, 0.5)

HANDLE_TOP = 0.74       # where the collar starts
BUTT_R = 0.07
TOP_R = 0.092
COLLAR_H = 0.07
HEAD_R = 0.185
HEAD_Z = HANDLE_TOP + COLLAR_H + HEAD_R * 0.86


def handle(bm):
    # A rounded butt, then a gentle taper wider toward the top: one closed outline turned round the axis.
    outline = [(0.0, 0.0), (BUTT_R * 0.7, 0.012), (BUTT_R, 0.05), (BUTT_R + 0.004, 0.2), (TOP_R, HANDLE_TOP),
               (0.0, HANDLE_TOP)]
    H.lathe_z(bm, outline, 14)


def collar(bm):
    outline = [(0.0, HANDLE_TOP - 0.005), (TOP_R + 0.02, HANDLE_TOP - 0.005), (TOP_R + 0.03, HANDLE_TOP + COLLAR_H / 2),
               (TOP_R + 0.02, HANDLE_TOP + COLLAR_H), (0.0, HANDLE_TOP + COLLAR_H)]
    H.lathe_z(bm, outline, 14)


def head(bm):
    # The grille: a ball, a little taller than wide, sitting on the collar.
    H.sphere(bm, Vector((0, 0, HEAD_Z)), HEAD_R, scale=(1, 1, 1.08), segments=14, rings=8)


def band(bm):
    # The band round the head's middle, a hair proud of the ball.
    H.torus(bm, Vector((0, 0, HEAD_Z)), HEAD_R + 0.004, 0.02, plane="XY", segments=14, sides=6)


objects = [
    B.piece("AnnouncerMic_Handle", BLACK, handle),
    B.piece("AnnouncerMic_Collar", YELLOW, collar),
    B.piece("AnnouncerMic_Head", SILVER, head),
    B.piece("AnnouncerMic_Band", CHARCOAL, band),
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
    # Previews as Roblox draws it: one-sided faces. The whole microphone, then its head from above.
    scene = bpy.context.scene
    camera = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.lens = 60
    camera.data.clip_start = 0.01
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_backface_culling = True
    scene.display.shading.show_shadows = True
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.55, 0.57, 0.6)
    scene.display.shading.background_type = "WORLD"
    scene.render.resolution_x, scene.render.resolution_y = 700, 800
    root, ext = os.path.splitext(argv[2])
    for suffix, eye, target in (("_Side", (0.9, -2.3, 0.75), (0, 0, 0.55)), ("_Top", (0.5, -1.0, 1.9), (0, 0, 0.9)),
                                ("_Under", (0.4, -1.2, -0.7), (0, 0, 0.3))):
        camera.location = Vector(eye)
        camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = root + suffix + ext
        bpy.ops.render.render(write_still=True)
tris = sum(len(o.data.loop_triangles) or sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objects)
print("AnnouncerMic_01 built:", sorted(o.name for o in B.coll.objects), "triangles", tris)
print("DONE")
