# Saves the worn gear and exports it for upload. Runs after the build:
#
#   blender -b art/blender/WornGear_01.blend --python art/scripts/build_worn_gear_01.py --python art/scripts/export_worn_gear.py -- <out.blend> <out.glb>
#
# Then: blender -b <out.blend> --python art/scripts/check_models.py (must say CHECK PASSED), and upload_group_images.py.
# Only the Worn* pieces go in the file; the Preview figures stay in the .blend.
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.save_as_mainfile(filepath=argv[0])
bpy.ops.object.select_all(action="DESELECT")
count = 0
for ob in bpy.data.objects:
    if ob.type == "MESH" and ob.name.startswith("Worn"):
        ob.hide_set(False)
        ob.select_set(True)
        count += 1
bpy.ops.export_scene.gltf(filepath=argv[1], export_format="GLB", use_selection=True, export_apply=True)
print("exported", count, "pieces")
print("DONE")
