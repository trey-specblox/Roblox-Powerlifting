# Builds SBarProps_01 in the live Blender scene: the supplement bar's props
# (user, 2026-10-25: "tubs and shakers with CENTRAL labels, bar stools").
# The brand on every label is "CENTRAL" (user's rule, 2026-10-23: never an
# empty box), never a real brand.
#
# Units: 1 Blender unit = 1 Roblox stud (as build_shop_gear_01.py). Blender is
# Z-up; every object has ONE material (Roblox colours each MeshPart once), and
# the colours are set again in Roblox, so one model serves several colourways
# (black tub with red lid, white tub with black lid; red or black shaker).
# Names are "<Item>_<Piece>"; one Model per item in Roblox.
#
# Items, side by side along X, each standing on z = 0, front (label) toward -Y:
#   SBarWhey, SBarGainer, SBarPreWorkout, SBarCreatine, SBarBCAA (round) and
#   SBarIsolate (square): Body, Lid, Label, Text ("CENTRAL" + the product name)
#   SBarShaker   Body, Lid, Text ("CENTRAL")
#   SBarStool    Seat (cushion), Metal (base, stem, foot ring and spokes, collar)
# Run in an otherwise empty file: objects are replaced by name on every run.

import bpy, bmesh, math
from mathutils import Matrix, Vector

COLL = "SBarProps_01"
SHARP_ANGLE = math.radians(50)


def material(name, color, metallic=0.0, roughness=0.8):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    mat.diffuse_color = (*color, 1.0)
    return mat


MAT = {
    "Black": material("SBar_Black", (0.02, 0.02, 0.022), 0.0, 0.5),
    "Red": material("SBar_Red", (0.55, 0.015, 0.025), 0.0, 0.45),
    "White": material("SBar_White", (0.85, 0.85, 0.85), 0.0, 0.5),
    "Steel": material("SBar_Steel", (0.55, 0.56, 0.58), 1.0, 0.25),
    "Leather": material("SBar_Leather", (0.025, 0.025, 0.028), 0.0, 0.6),
}

BRAND = "CENTRAL"


def find_font():
    import glob, os
    roots = [os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions"), r"C:\Program Files (x86)\Roblox\Versions",
             r"C:\Program Files\Roblox\Versions"]
    found = []
    for root in roots:
        found += glob.glob(os.path.join(root, "*", "content", "fonts", "Montserrat-Black.ttf"))
    if not found:
        raise RuntimeError("Montserrat-Black.ttf not found in a Roblox install")
    return bpy.data.fonts.load(max(found, key=os.path.getmtime), check_existing=True)


FONT = find_font()

coll = bpy.data.collections.get(COLL)
if coll is None:
    coll = bpy.data.collections.new(COLL)
    bpy.context.scene.collection.children.link(coll)


def finish(name, bm, mat, smooth=True):
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
        mesh.set_sharp_from_angle(angle=SHARP_ANGLE)
    obj = bpy.data.objects.new(name, mesh)
    obj.location = centre
    coll.objects.link(obj)
    return obj


def lathe_z(bm, outline, segments, centre=Vector((0, 0, 0))):
    """Spins an (r, z) outline around the Z axis. Closed outlines make closed
    solids; r = 0 points make poles."""
    tmp = bmesh.new()
    verts = [tmp.verts.new((r, 0.0, z)) for r, z in outline]
    edges = [tmp.edges.new((verts[i], verts[i + 1])) for i in range(len(verts) - 1)]
    if outline[0][0] > 0 and outline[-1][0] > 0:
        edges.append(tmp.edges.new((verts[-1], verts[0])))
    bmesh.ops.spin(tmp, geom=verts + edges, cent=(0, 0, 0), axis=(0, 0, 1),
                   angle=2 * math.pi, steps=segments, use_duplicate=False)
    bmesh.ops.remove_doubles(tmp, verts=tmp.verts[:], dist=1e-6)
    # Spinning an anticlockwise (r, z) outline makes faces that point inward, and Roblox draws one side
    # only: turn them outward, whichever way the outline runs (as prop_helpers.lathe_z).
    if sum(r0 * z1 - r1 * z0 for (r0, z0), (r1, z1) in zip(outline, outline[1:] + outline[:1])) > 0:
        bmesh.ops.reverse_faces(tmp, faces=tmp.faces[:])
    for v in tmp.verts:
        v.co += centre
    mesh = bpy.data.meshes.new("_tmp")
    tmp.to_mesh(mesh)
    tmp.free()
    bm.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)


def add_text(bm, text, size, extrude, place):
    """Adds `text` (centred, extruded `extrude` each way) to bm. place(x, up,
    depth) maps a point of the flat text onto the item's curved surface."""
    curve = bpy.data.curves.new("_text", "FONT")
    curve.body = text
    curve.font = FONT
    curve.size = size
    curve.extrude = extrude
    curve.resolution_u = 2
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    obj = bpy.data.objects.new("_text", curve)
    coll.objects.link(obj)
    bpy.context.view_layer.update()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.curves.remove(curve)
    tmp = bmesh.new()
    tmp.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)
    for v in tmp.verts:
        v.co = place(v.co.x, v.co.y, v.co.z + extrude)
    mesh = bpy.data.meshes.new("_tmp")
    tmp.to_mesh(mesh)
    tmp.free()
    bm.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)


def on_cylinder(base, radius, z_mid):
    """place() for text wrapped round a vertical cylinder, centred on its front (-Y)."""
    def place(x, up, depth):
        angle = x / radius
        r = radius + depth
        return base + Vector((r * math.sin(angle), -r * math.cos(angle), z_mid + up))
    return place


def cylinder_z(bm, centre, radius, height, segments=24):
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius, radius2=radius,
                          depth=height, matrix=Matrix.Translation(centre))


def box(bm, centre, size, rotation=Matrix.Identity(4)):
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(centre) @ rotation @ Matrix.Diagonal((*size, 1)))


# ================================================================ Products
# Six supplement products (user, 2026-10-25, with photos of real supplement
# walls: many shapes and colours, not just red and black). Each is one CENTRAL
# product line with its own shape and name; Roblox colours them per product
# (COLOURWAYS below is the default in this file and the list to copy there).
# Every product: <Item>_Body, <Item>_Lid, <Item>_Label, <Item>_Text.
COLOURWAYS = {  # (body, lid, label, text)
    "SBarWhey": [("Black", "Red", "Red", "White"), ("White", "Black", "Black", "White")],
    "SBarIsolate": [("White", "Blue", "Blue", "White")],
    "SBarGainer": [("Black", "Black", "Yellow", "Black")],
    "SBarPreWorkout": [("Black", "Green", "Green", "Black"), ("Black", "Purple", "Purple", "White")],
    "SBarCreatine": [("White", "Silver", "Silver", "Black")],
    "SBarBCAA": [("White", "Orange", "Orange", "White")],
    "SBarShaker": [("Red", "Black", None, "White"), ("Blue", "Black", None, "White"), ("White", "Black", None, "Black"),
                   ("Black", "White", None, "White"), ("Green", "Black", None, "Black"), ("Pink", "White", None, "White")],
}
MAT.update({
    "Blue": material("SBar_Blue", (0.02, 0.12, 0.55), 0.0, 0.45),
    "Yellow": material("SBar_Yellow", (0.85, 0.62, 0.02), 0.0, 0.45),
    "Green": material("SBar_Green", (0.2, 0.85, 0.05), 0.0, 0.45),
    "Purple": material("SBar_Purple", (0.3, 0.04, 0.55), 0.0, 0.45),
    "Orange": material("SBar_Orange", (0.9, 0.3, 0.02), 0.0, 0.45),
    "Silver": material("SBar_Silver", (0.6, 0.62, 0.65), 0.8, 0.3),
    "Pink": material("SBar_Pink", (0.85, 0.2, 0.45), 0.0, 0.45),
})


def round_product(item, base, body, lid, radius, label, brand_size, name, name_size):
    """A round container: lathe body and lid outlines, a label band label=(z0,
    z1), and "CENTRAL" over the product name on the front of the band."""
    look = COLOURWAYS[item][0]
    bm = bmesh.new()
    lathe_z(bm, body, 48, base)
    finish(item + "_Body", bm, MAT[look[0]])
    bm = bmesh.new()
    lathe_z(bm, lid, 48, base)
    finish(item + "_Lid", bm, MAT[look[1]])
    z0, z1 = label
    bm = bmesh.new()
    lathe_z(bm, [(radius - 0.004, z0), (radius + 0.008, z0), (radius + 0.008, z1), (radius - 0.004, z1)], 48, base)
    finish(item + "_Label", bm, MAT[look[2]])
    span = z1 - z0
    bm = bmesh.new()
    add_text(bm, BRAND, brand_size, 0.005, on_cylinder(base, radius + 0.008, z0 + span * 0.62))
    add_text(bm, name, name_size, 0.005, on_cylinder(base, radius + 0.008, z0 + span * 0.3))
    finish(item + "_Text", bm, MAT[look[3]])


# Round tub, 2 kg whey: about 20 cm across, 28 cm tall (0.9 x 1.27 studs).
round_product("SBarWhey", Vector((0, 0, 0)),
              [(0, 0), (0.40, 0), (0.44, 0.03), (0.45, 0.1), (0.45, 1.0), (0.43, 1.05), (0.41, 1.08), (0, 1.08)],
              [(0, 1.06), (0.44, 1.06), (0.465, 1.09), (0.465, 1.23), (0.445, 1.27), (0, 1.27)],
              0.45, (0.24, 0.86), 0.2, "WHEY PROTEIN", 0.085)
# Tall jug, mass gainer: shoulders narrowing to a screw cap (0.84 x 1.45).
round_product("SBarGainer", Vector((1.2, 0, 0)),
              [(0, 0), (0.38, 0), (0.415, 0.04), (0.42, 0.12), (0.42, 1.0), (0.36, 1.15), (0.22, 1.24), (0.2, 1.28), (0, 1.28)],
              [(0, 1.26), (0.215, 1.26), (0.225, 1.29), (0.225, 1.43), (0.21, 1.45), (0, 1.45)],
              0.42, (0.2, 0.92), 0.19, "MASS GAINER", 0.08)
# Small jar, pre-workout (0.62 x 0.82).
round_product("SBarPreWorkout", Vector((2.2, 0, 0)),
              [(0, 0), (0.27, 0), (0.295, 0.02), (0.3, 0.07), (0.3, 0.66), (0.285, 0.69), (0.27, 0.71), (0, 0.71)],
              [(0, 0.69), (0.29, 0.69), (0.31, 0.71), (0.31, 0.8), (0.295, 0.82), (0, 0.82)],
              0.3, (0.16, 0.56), 0.13, "PRE-WORKOUT", 0.055)
# Smaller jar, creatine (0.56 x 0.72).
round_product("SBarCreatine", Vector((3.0, 0, 0)),
              [(0, 0), (0.24, 0), (0.265, 0.02), (0.27, 0.06), (0.27, 0.58), (0.255, 0.61), (0.24, 0.62), (0, 0.62)],
              [(0, 0.6), (0.26, 0.6), (0.28, 0.62), (0.28, 0.7), (0.265, 0.72), (0, 0.72)],
              0.27, (0.14, 0.5), 0.115, "CREATINE", 0.05)
# Capsule bottle, BCAA (0.44 x 0.66).
round_product("SBarBCAA", Vector((3.7, 0, 0)),
              [(0, 0), (0.2, 0), (0.215, 0.02), (0.22, 0.06), (0.22, 0.44), (0.18, 0.5), (0.12, 0.53), (0.11, 0.55), (0, 0.55)],
              [(0, 0.54), (0.125, 0.54), (0.13, 0.56), (0.13, 0.66), (0, 0.66)],
              0.22, (0.1, 0.4), 0.085, "BCAA", 0.06)

# Square tub, whey isolate: a rounded box (0.86 x 0.86 x 1.15) with a flat
# front label.
IS = Vector((4.6, 0, 0))
look = COLOURWAYS["SBarIsolate"][0]


def rounded_box(bm, centre, size, bevel):
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0, matrix=Matrix.Translation(centre) @ Matrix.Diagonal((*size, 1)))
    bmesh.ops.bevel(tmp, geom=tmp.edges[:], offset=bevel, segments=3, affect="EDGES", profile=0.5)
    mesh = bpy.data.meshes.new("_tmp")
    tmp.to_mesh(mesh)
    tmp.free()
    bm.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)


bm = bmesh.new()
rounded_box(bm, IS + Vector((0, 0, 0.49)), (0.86, 0.86, 0.98), 0.12)
finish("SBarIsolate_Body", bm, MAT[look[0]])
bm = bmesh.new()
rounded_box(bm, IS + Vector((0, 0, 1.065)), (0.88, 0.88, 0.17), 0.06)
finish("SBarIsolate_Lid", bm, MAT[look[1]])
bm = bmesh.new()
box(bm, IS + Vector((0, -0.436, 0.5)), (0.62, 0.012, 0.6))
finish("SBarIsolate_Label", bm, MAT[look[2]], smooth=False)
bm = bmesh.new()
front = 0.442


def on_front(x, up, depth, z_mid):
    return IS + Vector((x, -(front + depth), z_mid + up))


add_text(bm, BRAND, 0.13, 0.004, lambda x, up, d: on_front(x, up, d, 0.6))
add_text(bm, "ISOLATE", 0.09, 0.004, lambda x, up, d: on_front(x, up, d, 0.39))
finish("SBarIsolate_Text", bm, MAT[look[3]], smooth=False)

# ================================================================ SBarShaker
# A 700 ml shaker cup, about 0.85 studs tall: a slightly flared body, a black
# screw lid with a flip-cap spout, "CENTRAL" on the front.
SH = Vector((5.6, 0, 0))
SH_BODY = [(0, 0), (0.19, 0), (0.205, 0.02), (0.24, 0.6), (0, 0.6)]
bm = bmesh.new()
lathe_z(bm, SH_BODY, 40, SH)
finish("SBarShaker_Body", bm, MAT["Red"])
bm = bmesh.new()
lathe_z(bm, [(0, 0.58), (0.255, 0.58), (0.262, 0.6), (0.262, 0.71), (0.235, 0.74), (0.22, 0.78), (0, 0.78)], 40, SH)
box(bm, SH + Vector((0, -0.12, 0.81)), (0.12, 0.1, 0.07))  # the flip cap over the spout
finish("SBarShaker_Lid", bm, MAT["Black"])
bm = bmesh.new()
add_text(bm, BRAND, 0.095, 0.004, on_cylinder(SH, 0.2275 + 0.002, 0.3))
finish("SBarShaker_Text", bm, MAT["White"])

# ================================================================ SBarStool
# A modern bar stool for the 3.85-stud counter: black cushion with its top at
# 2.8 studs, chrome stem, a foot ring on three spokes, a round base.
ST = Vector((7.0, 0, 0))
bm = bmesh.new()
lathe_z(bm, [(0, 2.5), (0.7, 2.5), (0.74, 2.55), (0.76, 2.68), (0.72, 2.77), (0.5, 2.8), (0, 2.8)], 48, ST)
finish("SBarStool_Seat", bm, MAT["Leather"])
bm = bmesh.new()
lathe_z(bm, [(0, 0), (0.68, 0), (0.7, 0.03), (0.62, 0.09), (0.14, 0.14), (0, 0.15)], 48, ST)  # base
cylinder_z(bm, ST + Vector((0, 0, 1.3)), 0.07, 2.3, 20)  # stem
lathe_z(bm, [(0, 2.38), (0.22, 2.38), (0.24, 2.5), (0, 2.5)], 32, ST)  # collar under the seat
# The foot ring: a torus made by spinning a small circle.
tmp_mesh = bpy.data.meshes.new("_ring")
tor = bmesh.new()
verts = []
for k in range(12):
    a = 2 * math.pi * k / 12
    verts.append(tor.verts.new((0.5 + 0.04 * math.cos(a), 0, 0.04 * math.sin(a))))
edges = [tor.edges.new((verts[i], verts[(i + 1) % 12])) for i in range(12)]
bmesh.ops.spin(tor, geom=verts + edges, cent=(0, 0, 0), axis=(0, 0, 1), angle=2 * math.pi, steps=40, use_duplicate=False)
bmesh.ops.remove_doubles(tor, verts=tor.verts[:], dist=1e-6)
bmesh.ops.reverse_faces(tor, faces=tor.faces[:])  # the circle runs anticlockwise: faces would point inward
for v in tor.verts:
    v.co += ST + Vector((0, 0, 1.0))
tor.to_mesh(tmp_mesh)
tor.free()
bm.from_mesh(tmp_mesh)
bpy.data.meshes.remove(tmp_mesh)
for k in range(3):  # spokes from the stem to the ring
    a = 2 * math.pi * k / 3 + math.pi / 2
    mid = ST + Vector((0.28 * math.cos(a), 0.28 * math.sin(a), 1.0))
    box(bm, mid, (0.44, 0.045, 0.045), Matrix.Rotation(a, 4, "Z"))
finish("SBarStool_Metal", bm, MAT["Steel"])

bpy.context.view_layer.update()
print("SBarProps_01 built:", sorted(o.name for o in coll.objects))
