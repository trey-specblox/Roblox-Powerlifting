# Checks every mesh in a .blend for faces Roblox would draw wrongly. Roblox draws each face from one side only,
# so a piece that is inside out (or folded) shows see-through gaps in the game even when it looks fine in
# Blender. Run it on every model file before exporting or uploading; it changes nothing.
#
#   blender -b art/blender/<File>.blend --python art/scripts/check_models.py
#   (or in Blender's Python console: exec(open(path).read()) with the file open)
#
# Checks the meshes as exported (modifiers applied), skipping the "Preview" collection (preview renders).
# Prints one line per broken object and ends with "CHECK PASSED" or "CHECK FAILED" (and exit code 1 when run
# with -b). The same check runs automatically inside prop_helpers.Builder for every piece it builds.
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

depsgraph = bpy.context.evaluated_depsgraph_get()
broken, checked = [], 0
for ob in bpy.data.objects:
    if ob.type != "MESH" or any(c.name == "Preview" for c in ob.users_collection) or ob.name.startswith("Preview"):
        continue
    checked += 1
    mesh = bpy.data.meshes.new_from_object(ob.evaluated_get(depsgraph))
    problems = H.winding_problems(mesh)
    bpy.data.meshes.remove(mesh)
    if ob.matrix_world.determinant() < 0:
        problems.append("mirrored (negative scale)")
    if problems:
        broken.append(f"  {ob.name}: " + "; ".join(problems))
print(f"{bpy.path.basename(bpy.data.filepath)}: {checked} meshes checked")
print("\n".join(broken))
print("CHECK FAILED" if broken else "CHECK PASSED")
if broken and bpy.app.background:
    sys.exit(1)
