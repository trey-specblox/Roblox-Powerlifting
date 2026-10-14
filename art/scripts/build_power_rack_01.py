# Builds PowerRack_01 in the live Blender scene.
# Units: 1 Blender unit = 1 Roblox stud. Blender is Z-up.
# Rack origin: world (0,0,0) = centre of the footprint at floor level.
# Front of the rack faces -Y (the side you see in Blender's Front view).
# "Left" = -X = the viewer's left when looking at the Front view.
import bpy, bmesh, math
from mathutils import Matrix, Vector

RACK = "PowerRack_01"

W, D, H = 6.0, 6.0, 8.0          # outer frame width (X), depth (Y), height (Z)
T = 0.30                          # square tube size
UX, UY = W / 2 - T / 2, D / 2 - T / 2   # upright centre lines (2.85)
OUT_X, OUT_Y = W / 2, D / 2       # outer faces (3.0)
IN_X, IN_Y = OUT_X - T, OUT_Y - T # inner faces (2.7)

HOLE_W, HOLE_H, HOLE_DEPTH = 0.12, 0.12, 0.06
HOLE_START, HOLE_STEP, HOLE_COUNT = 1.5, 0.4, 14   # holes at z = 1.5 .. 6.7
HOLE_Z = [HOLE_START + i * HOLE_STEP for i in range(HOLE_COUNT)]
JCUP_Z = HOLE_Z[7]      # 4.3  (squat height, provisional)
SAFETY_Z = HOLE_Z[3]    # 2.7  (provisional)

CROSSBAR_Z0 = H - T     # top crossbars occupy z 7.7 .. 8.0
BASE_H = 0.25           # base rails occupy z 0 .. 0.25

# ---------------------------------------------------------------- materials
def material(name, color, metallic, roughness):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    mat.diffuse_color = (*color, 1.0)
    return mat

MAT_STEEL = material("Steel_BlackPainted", (0.02, 0.02, 0.022), 0.0, 0.8)
MAT_HARDWARE = material("Steel_Hardware", (0.18, 0.18, 0.19), 1.0, 0.45)
MAT_RUBBER = material("Rubber_Black", (0.03, 0.03, 0.03), 0.0, 0.95)

# ---------------------------------------------------------------- helpers
coll = bpy.data.collections.get(RACK)
if coll is None:
    coll = bpy.data.collections.new(RACK)
    bpy.context.scene.collection.children.link(coll)

def finish(name, bm, mat):
    """Turns a bmesh into a named object whose origin sits at its own bounds centre."""
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
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
    obj = bpy.data.objects.new(name, mesh)
    obj.location = centre
    coll.objects.link(obj)
    return obj

def add_box(bm, x0, x1, y0, y1, z0, z1):
    c = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    m = Matrix.Translation(c) @ Matrix.Diagonal((x1 - x0, y1 - y0, z1 - z0, 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)

def box_object(name, mat, *bounds):
    bm = bmesh.new()
    add_box(bm, *bounds)
    return finish(name, bm, mat)

def add_cylinder(bm, centre, axis, radius, length, segments):
    """Low-poly capped cylinder. axis is 'X', 'Y' or 'Z'."""
    rot = {"X": Matrix.Rotation(math.pi / 2, 4, "Y"),
           "Y": Matrix.Rotation(math.pi / 2, 4, "X"),
           "Z": Matrix.Identity(4)}[axis]
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments,
                          radius1=radius, radius2=radius, depth=length,
                          matrix=Matrix.Translation(centre) @ rot)

def add_profile_extrusion(bm, profile_yz, x0, x1):
    """Extrudes a closed (y, z) outline along X from x0 to x1; caps are triangulated."""
    left = [bm.verts.new((x0, y, z)) for y, z in profile_yz]
    right = [bm.verts.new((x1, y, z)) for y, z in profile_yz]
    caps = [bm.faces.new(left), bm.faces.new(list(reversed(right)))]
    n = len(profile_yz)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((left[i], left[j], right[j], right[i]))
    bmesh.ops.triangulate(bm, faces=caps, quad_method="BEAUTY", ngon_method="EAR_CLIP")

# ---------------------------------------------------------------- uprights
def upright(name, cx, cy):
    bm = bmesh.new()
    add_box(bm, cx - T / 2, cx + T / 2, cy - T / 2, cy + T / 2, 0.0, H)
    geom = lambda: bm.verts[:] + bm.edges[:] + bm.faces[:]
    for z in HOLE_Z:
        for zz in (z - HOLE_H / 2, z + HOLE_H / 2):
            bmesh.ops.bisect_plane(bm, geom=geom(), plane_co=(0, 0, zz), plane_no=(0, 0, 1))
    for xx in (cx - HOLE_W / 2, cx + HOLE_W / 2):
        bmesh.ops.bisect_plane(bm, geom=geom(), plane_co=(xx, 0, 0), plane_no=(1, 0, 0))
    bm.normal_update()
    hole_faces = []
    for f in bm.faces:
        if abs(f.normal.y) < 0.99:
            continue
        c = f.calc_center_median()
        if abs(c.x - cx) < HOLE_W / 2 and any(abs(c.z - z) < HOLE_H / 2 for z in HOLE_Z):
            hole_faces.append(f)
    assert len(hole_faces) == HOLE_COUNT * 2, (name, len(hole_faces))
    bmesh.ops.inset_individual(bm, faces=hole_faces, thickness=0.0, depth=-HOLE_DEPTH,
                               use_even_offset=True)
    return finish(name, bm, MAT_STEEL)

parts = []
for name, sx, sy in [("Upright_FrontLeft", -1, -1), ("Upright_FrontRight", 1, -1),
                     ("Upright_BackLeft", -1, 1), ("Upright_BackRight", 1, 1)]:
    parts.append(upright(name, sx * UX, sy * UY))

# ---------------------------------------------------------------- frame tubes
parts += [
    box_object("Crossbar_Front", MAT_STEEL, -IN_X, IN_X, -OUT_Y, -IN_Y, CROSSBAR_Z0, H),
    box_object("Crossbar_Back", MAT_STEEL, -IN_X, IN_X, IN_Y, OUT_Y, CROSSBAR_Z0, H),
    box_object("Crossbar_Left", MAT_STEEL, -OUT_X, -IN_X, -IN_Y, IN_Y, CROSSBAR_Z0, H),
    box_object("Crossbar_Right", MAT_STEEL, IN_X, OUT_X, -IN_Y, IN_Y, CROSSBAR_Z0, H),
    box_object("BaseRail_Left", MAT_STEEL, -OUT_X, -IN_X, -IN_Y, IN_Y, 0.0, BASE_H),
    box_object("BaseRail_Right", MAT_STEEL, IN_X, OUT_X, -IN_Y, IN_Y, 0.0, BASE_H),
    box_object("BaseRail_Back", MAT_STEEL, -IN_X, IN_X, IN_Y, OUT_Y, 0.0, BASE_H),
]

# ---------------------------------------------------------------- J-cups
# J outline in (y, z), on the front face (y = -3.0) of each front upright.
F = -OUT_Y
PLATE, SEAT_Y, HOOK_T, LIP_T = 0.06, 0.34, 0.07, 0.07
Z_BOT, Z_TOP, LIP_TOP = JCUP_Z - 0.45, JCUP_Z + 0.15, JCUP_Z - 0.20
JCUP_PROFILE = [
    (F, Z_TOP), (F, Z_BOT), (F - SEAT_Y, Z_BOT), (F - SEAT_Y, LIP_TOP),
    (F - SEAT_Y + LIP_T, LIP_TOP), (F - SEAT_Y + LIP_T, Z_BOT + HOOK_T),
    (F - PLATE, Z_BOT + HOOK_T), (F - PLATE, Z_TOP),
]
# Rubber liner = seat pad on the hook + back pad on the plate (two boxes; an
# extruded L outline triangulated wrongly across its inside corner).
LINER_T, LINER_TOP = 0.03, JCUP_Z - 0.10
SEAT_Z = Z_BOT + HOOK_T
for side, sx in (("Left", -1), ("Right", 1)):
    cx = sx * UX
    bm = bmesh.new()
    add_profile_extrusion(bm, JCUP_PROFILE, cx - 0.17, cx + 0.17)
    parts.append(finish("JCup_" + side, bm, MAT_STEEL))
    bm = bmesh.new()
    add_box(bm, cx - 0.15, cx + 0.15, F - SEAT_Y + LIP_T, F - PLATE, SEAT_Z, SEAT_Z + LINER_T)
    add_box(bm, cx - 0.15, cx + 0.15, F - PLATE - LINER_T, F - PLATE, SEAT_Z + LINER_T, LINER_TOP)
    parts.append(finish("JCupLiner_" + side, bm, MAT_RUBBER))
    bm = bmesh.new()   # pull-pin knob on the J-cup face, level with its hole
    add_cylinder(bm, (cx, F - PLATE - 0.02, JCUP_Z), "Y", 0.035, 0.04, 8)
    parts.append(finish("JCupPin_" + side, bm, MAT_HARDWARE))

# ---------------------------------------------------------------- safety bars
SAFETY_HALF, SAFETY_END = 0.05, OUT_Y + 0.20
for side, sx in (("Left", -1), ("Right", 1)):
    cx = sx * UX
    parts.append(box_object("SafetyBar_" + side, MAT_STEEL,
                            cx - SAFETY_HALF, cx + SAFETY_HALF, -SAFETY_END, SAFETY_END,
                            SAFETY_Z - SAFETY_HALF, SAFETY_Z + SAFETY_HALF))
bm = bmesh.new()   # lock pins through both ends of both safety bars
for sx in (-1, 1):
    for sy in (-1, 1):
        add_cylinder(bm, (sx * UX, sy * (OUT_Y + 0.11), SAFETY_Z), "Z", 0.025, 0.16, 8)
parts.append(finish("SafetyPins", bm, MAT_HARDWARE))

# ---------------------------------------------------------------- bolts
BOLT_R, BOLT_L = 0.045, 0.03
bm = bmesh.new()
def bolt(x, y, z, axis):
    add_cylinder(bm, (x, y, z), axis, BOLT_R, BOLT_L, 6)
for sx in (-1, 1):
    for sy in (-1, 1):
        for z in (CROSSBAR_Z0 + 0.08, H - 0.08):
            bolt(sx * (OUT_X + BOLT_L / 2), sy * UY, z, "X")   # front/back crossbar joints
            bolt(sx * UX, sy * (OUT_Y + BOLT_L / 2), z, "Y")   # left/right crossbar joints
        bolt(sx * UX, sy * (OUT_Y + BOLT_L / 2), BASE_H / 2, "Y")  # side base rail joints
    bolt(sx * (OUT_X + BOLT_L / 2), UY, BASE_H / 2, "X")           # back base rail joints
parts.append(finish("FrameBolts", bm, MAT_HARDWARE))

print("built", len(parts), "parts:", [p.name for p in parts])
