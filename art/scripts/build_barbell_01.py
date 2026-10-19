# Builds Barbell_01 (power bar, IPF-colour calibrated plates and a lock collar) in the
# live Blender scene. Reference: Ohio Power Bar + Eleiko IPF plates
# (References/Visual Style/Visual Style.md), at game scale.
# Units: 1 Blender unit = 1 Roblox stud. Blender is Z-up.
# Origin: world (0,0,0) = the centre of the bar. The bar lies along X.
#
# Scale (revised 2026-10-19 after the user's reference photos): 0.225 m per stud,
# the scale of a Roblox avatar's WIDTH (its 2-stud torso is about shoulder width).
# The rack and the bar are sized to that width, so at this scale every barbell
# proportion matches a real competition bar: a 450 mm plate is 2.0 studs across,
# about a third of the 6.5-stud grip section, and the 0.14-stud shaft is ~31 mm.
# (The first version used the avatar's HEIGHT scale, 0.346 m per stud, and the
# plates looked too small next to the bar.) The rack's clearance checks
# (art/scripts/build_combo_rack_01.py) use the same plate radius and sleeves.
#
# The template holds ONE part per plate type, stacked on the right sleeve in
# loading order. The game will clone and stack plates to show any load later.
# Run in an otherwise empty file: parts are replaced by name on every run.
import bpy, bmesh, math
from mathutils import Matrix, Vector

COLL = "Barbell_01"

SHAFT_R, SHAFT_X = 0.07, 3.25       # knurled shaft between the inner collars
COLLAR_X1, COLLAR_R = 3.31, 0.17    # inner collar flange x 3.25 .. 3.31
SLEEVE_R, SLEEVE_X1, SLEEVE_BORE = 0.13, 4.95, 0.04   # 1.64-stud loadable sleeves
PLATE_BORE = 0.14                   # plate hole (just over the sleeve)

M_PER_STUD = 0.225
def studs(mm):
    return mm / 1000 / M_PER_STUD

# name: (outer diameter mm, thickness mm, colour)  -- IPF calibrated plates
PLATES_MM = [
    ("Plate_25", 450, 27, (0.70, 0.04, 0.04)),      # red
    ("Plate_20", 450, 22, (0.04, 0.16, 0.70)),      # blue
    ("Plate_15", 400, 21, (0.92, 0.72, 0.04)),      # yellow
    ("Plate_10", 325, 21, (0.04, 0.50, 0.14)),      # green
    ("Plate_5", 228, 26, (0.88, 0.88, 0.88)),       # white
    ("Plate_2_5", 190, 19, (0.03, 0.03, 0.03)),     # black
    ("Plate_1_25", 160, 15, (0.70, 0.71, 0.73)),    # chrome
]
PLATES = [(name, studs(dia) / 2, studs(thick), color) for name, dia, thick, color in PLATES_MM]
LOCK_R, LOCK_LEN = studs(110) / 2, studs(50)   # 2.5 kg competition lock collar

def plate_segments(radius):
    return 32 if radius >= 0.6 else 24
SHARP_ANGLE = math.radians(50)

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

MAT_BAR = material("Steel_BarShaft", (0.50, 0.51, 0.53), 1.0, 0.5)
MAT_CHROME = material("Steel_Chrome", (0.80, 0.80, 0.82), 1.0, 0.2)

# ---------------------------------------------------------------- helpers
coll = bpy.data.collections.get(COLL)
if coll is None:
    coll = bpy.data.collections.new(COLL)
    bpy.context.scene.collection.children.link(coll)

def finish(name, bm, mat):
    """Turns a bmesh into a named object whose origin sits at its own bounds centre.
    Shading: smooth, sharp above SHARP_ANGLE, flat sides kept flat by weighted normals."""
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
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mesh.set_sharp_from_angle(angle=SHARP_ANGLE)
    obj = bpy.data.objects.new(name, mesh)
    obj.location = centre
    wn = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    wn.mode = "FACE_AREA"
    wn.keep_sharp = True
    coll.objects.link(obj)
    return obj

def lathe(bm, profile_xr, segments):
    """Spins a closed (x, radius) outline once around the X axis. Radii must be > 0."""
    tmp = bmesh.new()
    verts = [tmp.verts.new((x, 0.0, r)) for x, r in profile_xr]
    edges = [tmp.edges.new((verts[i], verts[(i + 1) % len(verts)])) for i in range(len(verts))]
    bmesh.ops.spin(tmp, geom=verts + edges, cent=(0, 0, 0), axis=(1, 0, 0),
                   angle=2 * math.pi, steps=segments, use_duplicate=False)
    bmesh.ops.remove_doubles(tmp, verts=tmp.verts[:], dist=1e-6)
    mesh = bpy.data.meshes.new("_lathe_tmp")
    tmp.to_mesh(mesh)
    tmp.free()
    bm.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)

def tube(x0, x1, r_in, r_out, chamfer=0.0):
    """(x, r) outline of a hollow tube from x0 to x1, outer edges chamfered."""
    c = min(chamfer, (x1 - x0) / 3, (r_out - r_in) / 3)
    if c <= 0:
        return [(x0, r_in), (x0, r_out), (x1, r_out), (x1, r_in)]
    return [(x0, r_in), (x0, r_out - c), (x0 + c, r_out), (x1 - c, r_out), (x1, r_out - c), (x1, r_in)]

def plate_profile(radius, thickness):
    """(x, r) outline of a calibrated plate centred on x = 0: raised hub, slightly
    recessed faces, rounded rim."""
    h = thickness / 2
    hub = min(0.36, radius - 0.12)
    d = h * 0.3                     # face recess depth
    rim = 0.02
    left = [(-h, PLATE_BORE), (-h, hub)]
    if radius - 0.1 > hub + d + 0.04:
        left += [(-h + d, hub + d), (-h + d, radius - 0.1), (-h, radius - 0.065)]
    left += [(-h, radius - rim), (-h + rim, radius)]
    right = [(-x, r) for x, r in reversed(left)]
    return left + right

parts = []

# ---------------------------------------------------------------- bar
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=16, radius1=SHAFT_R,
                      radius2=SHAFT_R, depth=2 * SHAFT_X, matrix=Matrix.Rotation(math.pi / 2, 4, "Y"))
parts.append(finish("Bar_Shaft", bm, MAT_BAR))

bm = bmesh.new()
for sx in (-1, 1):
    flange = tube(SHAFT_X, COLLAR_X1, SLEEVE_BORE, COLLAR_R, 0.012)
    sleeve = tube(COLLAR_X1, SLEEVE_X1, SLEEVE_BORE, SLEEVE_R, 0.02)
    for outline in (flange, sleeve):
        if sx < 0:
            outline = [(-x, r) for x, r in reversed(outline)]
        lathe(bm, outline, 16)
parts.append(finish("Bar_Sleeves", bm, MAT_CHROME))

# ---------------------------------------------------------------- plates, stacked on the right sleeve
x = COLLAR_X1
for name, radius, thickness, color in PLATES:
    bm = bmesh.new()
    lathe(bm, plate_profile(radius, thickness), plate_segments(radius))
    bm.transform(Matrix.Translation((x + thickness / 2, 0, 0)))
    mat = material("Paint_" + name, color, 0.0 if name != "Plate_1_25" else 1.0,
                   0.55 if name != "Plate_1_25" else 0.25)
    parts.append(finish(name, bm, mat))
    x += thickness

# ---------------------------------------------------------------- lock collar
bm = bmesh.new()
lathe(bm, tube(x, x + LOCK_LEN, SLEEVE_R + 0.005, LOCK_R, 0.025), 24)
lever = Matrix.Translation((x + LOCK_LEN / 2, 0, LOCK_R + 0.07)) @ Matrix.Diagonal((0.08, 0.08, 0.16, 1))
bmesh.ops.create_cube(bm, size=1.0, matrix=lever)
parts.append(finish("Collar_Lock", bm, MAT_CHROME))

print("built", len(parts), "parts:", [p.name for p in parts])
bpy.context.view_layer.update()
tris = {p.name: sum(len(f.vertices) - 2 for f in p.data.polygons) for p in parts}
print("triangles: total", sum(tris.values()), "|", tris)
print(f"loaded right sleeve ends at x = {x + LOCK_LEN:.3f} (sleeve end {SLEEVE_X1})")
