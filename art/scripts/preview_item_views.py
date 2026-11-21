# Pictures of one model file from four sides (front, right side, back, three-quarter), drawn with backface culling on,
# as Roblox draws (CLAUDE.md: 3D models). Nothing is saved: it only renders pictures.
#
#   blender -b <file>.blend --python art/scripts/preview_item_views.py -- <out folder> <name> [object name prefix]

import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT, NAME = argv[0], argv[1]
PREFIX = argv[2] if len(argv) > 2 else ""
scene = bpy.context.scene

objects = [o for o in scene.objects if o.type == "MESH" and o.name.startswith(PREFIX)]
for o in scene.objects:
    if o.type == "MESH" and o not in objects:
        o.hide_render = True
lo = Vector((1e9, 1e9, 1e9))
hi = -lo
for ob in objects:
    for corner in ob.bound_box:
        w = ob.matrix_world @ Vector(corner)
        lo = Vector(map(min, lo, w))
        hi = Vector(map(max, hi, w))
centre = (lo + hi) / 2
size = max(hi - lo)

for m in bpy.data.materials:
    m.use_backface_culling = True
try:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
except TypeError:
    scene.render.engine = "BLENDER_EEVEE"
try:
    scene.view_settings.view_transform = "Standard"
except TypeError:
    pass
world = bpy.data.worlds.new("PreviewWorld")
scene.world = world
world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs[0].default_value = (0.42, 0.45, 0.5, 1)
bg.inputs[1].default_value = 0.8


def sun(name, energy, rot):
    data = bpy.data.lights.new(name, "SUN")
    data.energy = energy
    ob = bpy.data.objects.new(name, data)
    ob.rotation_euler = [math.radians(a) for a in rot]
    scene.collection.objects.link(ob)


sun("Key", 2.4, (50, 0, 30))
sun("Fill", 1.2, (60, 0, -140))
sun("Back", 0.9, (70, 0, 160))

cam_data = bpy.data.cameras.new("PreviewCam")
cam_data.lens = 50
cam = bpy.data.objects.new("PreviewCam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.resolution_x = 900
scene.render.resolution_y = 1000

# Directions the camera stands in, from the model's centre (the model faces -Y).
VIEWS = {"1_Front": (0, -1, 0.12), "2_Side": (-1, 0, 0.12), "3_Back": (0, 1, 0.12), "4_ThreeQuarter": (-0.7, -0.8, 0.3),
         "5_OtherSide": (1, 0, 0.12), "6_Above": (0.5, -0.7, 0.9)}
for view, direction in VIEWS.items():
    d = Vector(direction).normalized()
    cam.location = centre + d * size * 1.5
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, f"{NAME}_{view}.png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED", view)
