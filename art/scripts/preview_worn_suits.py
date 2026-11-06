# Renders the rare suits and knee wraps for approval, lit, with the game's rough canvas on them, and saves the file. Faces are
# one-sided, as Roblox draws them. Runs after the build:
#
#   blender -b art/blender/WornGear_01.blend --python art/scripts/build_worn_gear_01.py --python art/scripts/preview_worn_suits.py -- <out.blend> <preview folder>
#
# Then, before uploading: blender -b <out.blend> --python art/scripts/check_models.py (must say CHECK PASSED).
# The canvas (art/scripts/make_suit_canvas.py) tiles every 1.2 studs in the game; here it is laid on by a box projection.
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.save_as_mainfile(filepath=argv[0])
folder = argv[1]
CANVAS = r"D:\Powerlifting Roblox Extras\Textures\SuitCanvas"
STUDS_PER_TILE = 1.2

colour_image = bpy.data.images.load(os.path.join(CANVAS, "color.png"), check_existing=True)
normal_image = bpy.data.images.load(os.path.join(CANVAS, "normal.png"), check_existing=True)
normal_image.colorspace_settings.name = "Non-Color"


def add_canvas(mat):
    """The canvas's weave on a material: its colour multiplied in, its bumps through the normal."""
    if mat is None or mat.get("has_canvas"):
        return
    mat["has_canvas"] = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    tint = tuple(bsdf.inputs["Base Color"].default_value)
    coord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1 / STUDS_PER_TILE,) * 3
    links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    colour = nodes.new("ShaderNodeTexImage")
    colour.image = colour_image
    colour.projection = "BOX"
    colour.projection_blend = 0.2
    links.new(mapping.outputs["Vector"], colour.inputs["Vector"])
    bump = nodes.new("ShaderNodeTexImage")
    bump.image = normal_image
    bump.projection = "BOX"
    bump.projection_blend = 0.2
    links.new(mapping.outputs["Vector"], bump.inputs["Vector"])
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 1.2
    links.new(bump.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    multiply = nodes.new("ShaderNodeMixRGB")
    multiply.blend_type = "MULTIPLY"
    multiply.inputs["Fac"].default_value = 1.0
    multiply.inputs["Color1"].default_value = tint
    links.new(colour.outputs["Color"], multiply.inputs["Color2"])
    links.new(multiply.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.92
    bsdf.inputs["Metallic"].default_value = 0.0


CANVAS_KEYS = ("Body", "Panel", "Shoulder", "Trim")
for ob in bpy.data.objects:
    if ob.type == "MESH" and ob.name.startswith("Preview_") and any(w in ob.name for w in ("WornSquatSuit", "WornDeadliftSuit", "WornBenchShirt", "WornKneeWrap_Body")):
        key = ob.name.split("_")[-2] if ob.name.count("_") >= 4 else ""
        if key in CANVAS_KEYS and ob.material_slots:
            add_canvas(ob.material_slots[0].material)
for mat in bpy.data.materials:
    mat.use_backface_culling = True

scene = bpy.context.scene
camera = bpy.data.objects.get("PreviewCamera") or bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
if camera.name not in scene.collection.objects:
    scene.collection.objects.link(camera)
scene.camera = camera
camera.data.lens = 70
for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        continue
print("engine", scene.render.engine)
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("PreviewWorld")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.57, 0.62, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
scene.world = world
sun = bpy.data.objects.new("PreviewSun", bpy.data.lights.new("PreviewSun", "SUN"))
sun.data.energy = 3.2
sun.rotation_euler = (math.radians(58), 0, math.radians(30))
scene.collection.objects.link(sun)
scene.render.resolution_x, scene.render.resolution_y = 1400, 900


def show(prefixes):
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            ob.hide_render = not any(ob.name.startswith("Preview_" + p) for p in prefixes)


def shoot(name, eye, target, lens=70):
    camera.data.lens = lens
    camera.location = Vector(eye)
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(folder, name + ".png")
    bpy.ops.render.render(write_still=True)


# Close enough to judge: each one from the front at an angle, then the row from behind.
show(["SuitSquat"])
shoot("WornSuits_Squat", (-19.8, -11.5, 1.2), (-22, 0, -0.2))
show(["SuitDeadlift"])
shoot("WornSuits_Deadlift", (-31.8, -11.5, 1.2), (-34, 0, -0.2))
show(["SuitShirt", "SuitBoth"])
shoot("WornSuits_Bench", (-27.0, -15, 1.6), (-28, 0, -0.1))
show(["SuitSquat", "SuitShirt", "SuitBoth", "SuitDeadlift"])
shoot("WornSuits_Back", (-29, 22, 2.6), (-28, 0, 0.4))
show(["SuitWraps"])
shoot("WornKneeWraps", (-36.6, -6.5, -0.9), (-38, 0, -1.9))
show(["PoseSquat", "PoseBench", "PoseDeadlift"])
shoot("WornSuits_Lifting", (-24, -13, 4.0), (-28, 8, -0.8), 50)
print("DONE")
