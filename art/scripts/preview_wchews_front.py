# Preview of W Chews' front building, backface culling on (as Roblox draws), by day and at dusk (its glow).
#   blender -b art/blender/WChewsFront_01.blend --python art/scripts/preview_wchews_front.py -- <out folder>
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else r"D:\ClaudeScratch\wchews"
scene = bpy.context.scene
for m in bpy.data.materials:
    m.use_backface_culling = True
    if m.use_nodes:
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf and bsdf.inputs["Alpha"].default_value < 0.99:
            try:
                m.surface_render_method = "BLENDED"
            except (AttributeError, TypeError):
                pass
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
sun = bpy.data.objects.new("PreviewSun", bpy.data.lights.new("PreviewSun", "SUN"))
sun.rotation_euler = (math.radians(55), 0, math.radians(-35))
scene.collection.objects.link(sun)
fill = bpy.data.objects.new("PreviewFill", bpy.data.lights.new("PreviewFill", "SUN"))
fill.data.use_shadow = False
fill.rotation_euler = (math.radians(65), 0, math.radians(150))
scene.collection.objects.link(fill)
ground = bpy.data.meshes.new("PreviewGround")
bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=200)
bm.to_mesh(ground)
ground_ob = bpy.data.objects.new("PreviewGround", ground)
ground_ob.location = (0, 0, -0.02)
scene.collection.objects.link(ground_ob)
gm = bpy.data.materials.new("PreviewGroundMat")
gm.use_nodes = True
gb = next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
gb.inputs["Base Color"].default_value = (0.22, 0.23, 0.27, 1)
gb.inputs["Roughness"].default_value = 0.7
ground.materials.append(gm)
cam_data = bpy.data.cameras.new("PreviewCam")
cam_data.lens = 28
cam_data.clip_end = 2000
cam = bpy.data.objects.new("PreviewCam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.resolution_x = 1600
scene.render.resolution_y = 900

LOOKS = {
    "Day": ((0.55, 0.68, 0.9), 0.8, 2.2, 0.6),
    "Dusk": ((0.03, 0.05, 0.14), 1.0, 0.25, 0.25),
}
VIEWS = {
    "Front": ((0, -78, 9), (0, 0, 11)),
    "ThreeQuarter": ((-56, -62, 12), (4, -6, 9)),
    "Steps": ((16, -40, 6), (-2, -12, 6)),
    "Side": ((70, -40, 14), (10, 0, 9)),
}
for look, (sky, strength, sun_e, fill_e) in LOOKS.items():
    bg.inputs[0].default_value = (*sky, 1)
    bg.inputs[1].default_value = strength
    sun.data.energy = sun_e
    fill.data.energy = fill_e
    for name, (pos, target) in VIEWS.items():
        pos, target = Vector(pos), Vector(target)
        cam.location = pos
        cam.rotation_euler = (target - pos).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(OUT, f"WChewsFront_{look}_{name}.png")
        bpy.ops.render.render(write_still=True)
        print("RENDERED", look, name)
