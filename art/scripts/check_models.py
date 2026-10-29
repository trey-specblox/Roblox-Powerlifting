# Checks every mesh in a .blend before it goes to Roblox. Run it on every model file before exporting or
# uploading; it changes nothing.
#
#   blender -b art/blender/<File>.blend --python art/scripts/check_models.py
#   (or in Blender's Python console: exec(open(path).read()) with the file open)
#
# 1. FACES. Roblox draws each face from one side only, so a piece that is inside out (or folded) shows
#    see-through gaps in the game even when it looks fine in Blender. The same check runs inside
#    prop_helpers.Builder for every piece it builds.
# 2. TRIANGLES (user 2026-10-28: "optimize everything"). Every object becomes one MeshPart, so every object
#    must stay inside a triangle budget: TRI_BUDGET by default, or its own custom property "tri_budget" (set
#    it on the object in Blender, with a reason in the build script, for a genuinely big piece). Roblox
#    refuses a mesh over ROBLOX_LIMIT, whatever its budget.
#
# Checks the meshes as exported (modifiers applied), skipping the "Preview" collection (preview renders).
# Prints one line per broken object, the file's heaviest objects and its total, and ends with "CHECK PASSED"
# or "CHECK FAILED" (and exit code 1 when run with -b).
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib  # noqa: E402
import prop_helpers as H  # noqa: E402

importlib.reload(H)

TRI_BUDGET = 5000  # a prop or piece of furniture
ROBLOX_LIMIT = 20000  # the most Roblox accepts in one mesh

depsgraph = bpy.context.evaluated_depsgraph_get()
broken, counts, checked = [], [], 0
for ob in bpy.data.objects:
    if ob.type != "MESH" or any(c.name == "Preview" for c in ob.users_collection) or ob.name.startswith("Preview"):
        continue
    checked += 1
    mesh = bpy.data.meshes.new_from_object(ob.evaluated_get(depsgraph))
    problems = H.winding_problems(mesh)
    triangles = sum(len(poly.vertices) - 2 for poly in mesh.polygons)
    bpy.data.meshes.remove(mesh)
    if ob.matrix_world.determinant() < 0:
        problems.append("mirrored (negative scale)")
    budget = int(ob.get("tri_budget", TRI_BUDGET))
    if triangles > ROBLOX_LIMIT:
        problems.append(f"{triangles} triangles: over Roblox's {ROBLOX_LIMIT} limit")
    elif triangles > budget:
        problems.append(f"{triangles} triangles: over its budget of {budget}")
    counts.append((triangles, ob.name))
    if problems:
        broken.append(f"  {ob.name}: " + "; ".join(problems))

counts.sort(reverse=True)
total = sum(t for t, _ in counts)
print(f"{bpy.path.basename(bpy.data.filepath)}: {checked} meshes checked, {total} triangles in all")
print("  heaviest: " + ", ".join(f"{name} {t}" for t, name in counts[:5]))
print("\n".join(broken))
print("CHECK FAILED" if broken else "CHECK PASSED")
if broken and bpy.app.background:
    sys.exit(1)
