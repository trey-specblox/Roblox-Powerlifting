# Shared Blender helpers for the room prop scripts (build_room_props_02.py and later ones).
# The same helpers build_sbar_props_01.py has inline, made reusable: one Builder per collection.
#
# Units: 1 Blender unit = 1 Roblox stud. Blender is Z-up; an item stands on z = 0 with its
# front toward -Y (after the GLB export with export_yup it faces -Z in Roblox, where RoomProps
# expects the front). Every object has ONE material (Roblox colours each MeshPart once).
# Object names are "<Item>_<Piece>" (letters only), so Roblox can split the file into items.

import glob
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

BRAND = "CENTRAL"


def material(name, color, metallic=0.0, roughness=0.6, alpha=1.0, emission=None):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Alpha"].default_value = alpha
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 3.0
    mat.diffuse_color = (*color, alpha)
    return mat


def find_font():
    """Montserrat Black from the Roblox install (OFL), the font of every CENTRAL label."""
    roots = [os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions"), r"C:\Program Files (x86)\Roblox\Versions",
             r"C:\Program Files\Roblox\Versions"]
    found = []
    for root in roots:
        found += glob.glob(os.path.join(root, "*", "content", "fonts", "Montserrat-Black.ttf"))
    if not found:
        raise RuntimeError("Montserrat-Black.ttf not found in a Roblox install")
    return bpy.data.fonts.load(max(found, key=os.path.getmtime), check_existing=True)


def _merge(bm, tmp):
    mesh = bpy.data.meshes.new("_tmp")
    tmp.to_mesh(mesh)
    tmp.free()
    bm.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)


def lathe_z(bm, outline, segments, centre=Vector((0, 0, 0))):
    """Spins an (r, z) outline around the Z axis. Closed outlines make closed solids; r = 0 points make poles."""
    tmp = bmesh.new()
    verts = [tmp.verts.new((r, 0.0, z)) for r, z in outline]
    edges = [tmp.edges.new((verts[i], verts[i + 1])) for i in range(len(verts) - 1)]
    if outline[0][0] > 0 and outline[-1][0] > 0:
        edges.append(tmp.edges.new((verts[-1], verts[0])))
    bmesh.ops.spin(tmp, geom=verts + edges, cent=(0, 0, 0), axis=(0, 0, 1), angle=2 * math.pi, steps=segments,
                   use_duplicate=False)
    bmesh.ops.remove_doubles(tmp, verts=tmp.verts[:], dist=1e-6)
    # Spinning an anticlockwise (r, z) outline (out along the bottom, up, back in along the top) makes faces
    # that point inward, and Roblox draws one side only. Turn them outward, whichever way the outline runs.
    area = sum(r0 * z1 - r1 * z0 for (r0, z0), (r1, z1) in zip(outline, outline[1:] + outline[:1]))
    if area > 0:
        bmesh.ops.reverse_faces(tmp, faces=tmp.faces[:])
    for v in tmp.verts:
        v.co += centre
    _merge(bm, tmp)


def box(bm, centre, size, rotation=Matrix.Identity(4)):
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(centre) @ rotation @ Matrix.Diagonal((*size, 1)))


def span(bm, low, high):
    """A box between two opposite corners (in any order: a negative size would turn the box inside out)."""
    low, high = Vector(map(min, low, high)), Vector(map(max, low, high))
    box(bm, (low + high) / 2, high - low)


def rounded_box(bm, centre, size, bevel, segments=3, rotation=Matrix.Identity(4)):
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0, matrix=Matrix.Diagonal((*size, 1)))
    edges = tmp.edges[:]
    thin = min(range(3), key=lambda i: size[i])
    if 2 * bevel > size[thin]:
        # Too thin to round every edge (the bevels would cross and fold the faces inside out): round only the
        # edges across the thin side, a flat slab with rounded corners.
        edges = [e for e in edges if abs(e.verts[0].co[thin] - e.verts[1].co[thin]) > 1e-6]
        bevel = min(bevel, 0.49 * min(s for i, s in enumerate(size) if i != thin))
    bmesh.ops.bevel(tmp, geom=edges, offset=bevel, segments=segments, affect="EDGES", profile=0.5)
    bmesh.ops.transform(tmp, matrix=Matrix.Translation(centre) @ rotation, verts=tmp.verts[:])
    _merge(bm, tmp)


def cylinder(bm, centre, radius, length, axis="Z", segments=24, radius2=None):
    """A capped cylinder (a cone with radius2) along the X, Y or Z axis."""
    rot = {"Z": Matrix.Identity(4), "X": Matrix.Rotation(math.pi / 2, 4, "Y"),
           "Y": Matrix.Rotation(math.pi / 2, 4, "X")}[axis]
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius,
                          radius2=radius if radius2 is None else radius2, depth=length,
                          matrix=Matrix.Translation(centre) @ rot)


def sphere(bm, centre, radius, scale=(1, 1, 1), segments=16, rings=8):
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=radius,
                              matrix=Matrix.Translation(centre) @ Matrix.Diagonal((*scale, 1)))


def torus(bm, centre, radius, tube, plane="XY", segments=32, sides=10, arc=2 * math.pi, start=0.0):
    """A torus (or an arc of one, `arc` radians from `start`) round `centre`, lying in `plane`."""
    tmp = bmesh.new()
    ring = [tmp.verts.new((radius + tube * math.cos(2 * math.pi * k / sides), 0, tube * math.sin(2 * math.pi * k / sides)))
            for k in range(sides)]
    edges = [tmp.edges.new((ring[k], ring[(k + 1) % sides])) for k in range(sides)]
    closed = abs(arc - 2 * math.pi) < 1e-6
    bmesh.ops.rotate(tmp, verts=ring, cent=(0, 0, 0), matrix=Matrix.Rotation(start, 3, "Z"))
    bmesh.ops.spin(tmp, geom=ring + edges, cent=(0, 0, 0), axis=(0, 0, 1), angle=arc, steps=segments,
                   use_duplicate=False)
    bmesh.ops.remove_doubles(tmp, verts=tmp.verts[:], dist=1e-6)
    # The ring runs anticlockwise, so the spun faces point inward (see lathe_z): turn them outward.
    bmesh.ops.reverse_faces(tmp, faces=tmp.faces[:])
    if not closed:
        bmesh.ops.holes_fill(tmp, edges=tmp.edges[:], sides=sides)
    turn = {"XY": Matrix.Identity(3), "XZ": Matrix.Rotation(math.pi / 2, 3, "X"),
            "YZ": Matrix.Rotation(math.pi / 2, 3, "Y")}[plane]
    for v in tmp.verts:
        v.co = turn @ v.co + Vector(centre)
    _merge(bm, tmp)


def on_cylinder(base, radius, z_mid):
    """place() for text wrapped round a vertical cylinder, centred on its front (-Y)."""
    def place(x, up, depth):
        angle = x / radius
        r = radius + depth
        return Vector(base) + Vector((r * math.sin(angle), -r * math.cos(angle), z_mid + up))
    return place


def on_front(base, y_front, z_mid):
    """place() for text on a flat face looking toward -Y at y = y_front."""
    def place(x, up, depth):
        return Vector(base) + Vector((x, y_front - depth, z_mid + up))
    return place


class Builder:
    """Makes named objects in one collection. Objects of the same name are replaced on every run."""

    def __init__(self, collection, sharp_angle=math.radians(50)):
        self.coll = bpy.data.collections.get(collection)
        if self.coll is None:
            self.coll = bpy.data.collections.new(collection)
            bpy.context.scene.collection.children.link(self.coll)
        self.sharp = sharp_angle
        self.font = find_font()

    def finish(self, name, bm, mat, smooth=True):
        """A named object from a bmesh, origin at its own bounds centre."""
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
        bm.normal_update()
        old = bpy.data.objects.get(name)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        old_mesh = bpy.data.meshes.get(name)
        if old_mesh:
            bpy.data.meshes.remove(old_mesh)
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        lo = Vector([min(v.co[i] for v in mesh.vertices) for i in range(3)])
        hi = Vector([max(v.co[i] for v in mesh.vertices) for i in range(3)])
        centre = (lo + hi) / 2
        mesh.transform(Matrix.Translation(-centre))
        mesh.materials.append(mat)
        mesh.polygons.foreach_set("use_smooth", [smooth] * len(mesh.polygons))
        if smooth:
            mesh.set_sharp_from_angle(angle=self.sharp)
        obj = bpy.data.objects.new(name, mesh)
        obj.location = centre
        self.coll.objects.link(obj)
        return obj

    def add_text(self, bm, text, size, extrude, place):
        """Adds `text` (centred, extruded `extrude` each way) to bm. place(x, up, depth) maps a point of the
        flat text onto the item's surface."""
        curve = bpy.data.curves.new("_text", "FONT")
        curve.body = text
        curve.font = self.font
        curve.size = size
        curve.extrude = extrude
        curve.resolution_u = 2
        curve.align_x = "CENTER"
        curve.align_y = "CENTER"
        obj = bpy.data.objects.new("_text", curve)
        self.coll.objects.link(obj)
        bpy.context.view_layer.update()
        mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(bpy.context.evaluated_depsgraph_get()))
        bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.curves.remove(curve)
        tmp = bmesh.new()
        tmp.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
        for v in tmp.verts:
            v.co = place(v.co.x, v.co.y, v.co.z + extrude)
        _merge(bm, tmp)

    def piece(self, name, mat, build, smooth=True):
        """One object: build(bm) fills a fresh bmesh."""
        bm = bmesh.new()
        build(bm)
        return self.finish(name, bm, mat, smooth)
