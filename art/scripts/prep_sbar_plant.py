"""Prepare the supplement bar's plant (Poly Haven potted_plant_02, CC0) for Roblox, in headless Blender:

    blender -b --factory-startup -P art/scripts/prep_sbar_plant.py -- --in <potted_plant_02.gltf> --out art/exports/SBarPlant_01.glb

Based on the Roblox Maps kit's prep_model.py (method by fwjelaa), but with a triangle budget per part instead of
one shared ratio: the leaves keep most of their detail, the soil (hidden in the pot) almost none. Scales metres to
studs at the gym's 0.225 m per stud, puts the bottom-centre at the origin and writes a GLB (a GLB uploaded as a
Model arrives at 1 Blender unit = 1 stud with its textures). The download comes from the kit's polyhaven_model().
"""
import json
import sys

import bmesh
import bpy
import mathutils

SCALE = 1 / 0.225
BUDGET = {"leaves": 6000, "pot": 1500, "dirt": 400}  # by a word in the mesh name


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def main(argv):
    args = dict(zip(argv[0::2], argv[1::2]))
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=args["--in"])
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in bpy.context.scene.objects:
        if o.parent:
            mw = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = mw
    for o in meshes:
        o.matrix_world = mathutils.Matrix.Scale(SCALE, 4) @ o.matrix_world
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.make_single_user(object=True, obdata=True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for o in [o for o in bpy.context.scene.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o, do_unlink=True)
    report = []
    for o in meshes:
        before = tri_count(o)
        target = next((n for word, n in BUDGET.items() if word in o.name.lower()), 1000)
        if before > target:
            bm = bmesh.new()  # weld UV-seam doubles first, so the collapse can reach the target
            bm.from_mesh(o.data)
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
            bm.to_mesh(o.data)
            bm.free()
            bpy.context.view_layer.objects.active = o
            m = o.modifiers.new("decimate", "DECIMATE")
            m.ratio = min(1.0, target / max(1, tri_count(o)))
            m.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=m.name)
        report.append([o.name, before, tri_count(o)])
    pts = [o.matrix_world @ mathutils.Vector(c) for o in meshes for c in o.bound_box]
    lo = mathutils.Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = mathutils.Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    shift = mathutils.Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for o in meshes:
        o.data.transform(mathutils.Matrix.Translation(o.matrix_world.inverted().to_3x3() @ -shift))
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=args["--out"], export_format="GLB", use_selection=True, use_active_scene=True,
                              export_apply=True, export_yup=True, export_texcoords=True, export_normals=True,
                              export_materials="EXPORT", export_image_format="AUTO")
    size = hi - lo
    print("PREP " + json.dumps({"tris": sum(r[2] for r in report), "meshes": report,
                                "size_studs": [round(size.x, 2), round(size.z, 2), round(size.y, 2)]}))


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
