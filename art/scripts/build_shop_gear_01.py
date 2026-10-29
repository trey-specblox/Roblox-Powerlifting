# Builds ShopGear_01 in the live Blender scene: the powerlifting gear for the
# Starter Gym's Shop (user, 2026-10-23, from their photos of knee sleeves, wrist
# wraps, a lever belt, a singlet and a gear stand). Black with red details; the
# brand on every badge is "CENTRAL" (user's rule, 2026-10-23: never an empty
# box), never a real brand's name or logo.
#
# Units: 1 Blender unit = 1 Roblox stud, at 0.225 m per stud (the barbell's
# scale, art/scripts/build_barbell_01.py). Blender is Z-up. Every object has ONE
# material (Roblox colours each MeshPart once), so stripes, linings and buckles
# are separate objects. Names are "<Item>_<Piece>": tools/studio/
# ShopGear01_PrepareImport.luau groups them into one Model per item.
#
# Items, side by side along X, each standing on z = 0, front toward -Y:
#   KneeSleeve        Body (black), Stripes (red), Patch (red badge + "CENTRAL")
#   WristWrap         Body (rolled, black), Tail (black), Stripes (red), Text (white)
#   WristWrapHanging  Body (black), Loop (black), Stripes (red), Velcro (grey), Text (white)
#   LeverBelt         Outer (black), Lining (red), Stitch (grey), Lever (steel), Text (black)
#   MannequinSinglet  Form (with thighs), Stand, Black, Red (side panels), Trim (red,
#                     neck and armholes), Shorts (black), ShortsRed, Patch (badge + text)
#   MannequinTee      Form, Stand, Black, Logo (red badge + "CENTRAL")
# Run in an otherwise empty file: objects are replaced by name on every run.
import bpy, bmesh, math
from mathutils import Matrix, Vector

COLL = "ShopGear_01"
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
    "Black": material("Gear_Black", (0.018, 0.018, 0.02)),
    "Red": material("Gear_Red", (0.55, 0.015, 0.025)),
    "Grey": material("Gear_Grey", (0.16, 0.16, 0.17)),
    "Steel": material("Gear_Steel", (0.32, 0.33, 0.35), 1.0, 0.35),
    "Form": material("Mannequin_Form", (0.82, 0.82, 0.8), 0.0, 0.45),
    "Stand": material("Mannequin_Stand", (0.03, 0.03, 0.035), 1.0, 0.4),
    "White": material("Gear_White", (0.85, 0.85, 0.85)),
}

# The gear brand is "CENTRAL" (user, 2026-10-23: every badge box carries it;
# never an empty box). Set in Montserrat Black, the free (OFL) font Roblox
# ships and the gym's signs use, found in the local Roblox install.
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

built = []

def finish(name, bm, mat, solidify=0.0, smooth=True):
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
    if solidify > 0:
        mod = obj.modifiers.new("Solidify", "SOLIDIFY")
        mod.thickness = solidify
        mod.offset = -1.0
    coll.objects.link(obj)
    built.append(obj)
    return obj

def interp(points, z):
    """Radius at height z on a (radius, z) outline sorted by z."""
    if z <= points[0][1]:
        return points[0][0]
    for (r0, z0), (r1, z1) in zip(points, points[1:]):
        if z0 <= z <= z1:
            t = 0.0 if z1 == z0 else (z - z0) / (z1 - z0)
            return r0 + (r1 - r0) * t
    return points[-1][0]

def lathe_z(bm, outline, segments, centre=Vector((0, 0, 0)), squash=None):
    """Spins an (r, z) outline around the Z axis. Closed outlines make closed
    solids; r = 0 points make poles. squash(z) scales Y (depth) at height z."""
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
        if squash:
            v.co.y *= squash(v.co.z)
        v.co += centre
    mesh = bpy.data.meshes.new("_tmp")
    tmp.to_mesh(mesh)
    tmp.free()
    bm.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)

def lathe_x(bm, outline, segments, centre):
    """Spins a closed (x, r) outline around the X axis."""
    tmp = bmesh.new()
    verts = [tmp.verts.new((x, 0.0, r)) for x, r in outline]
    edges = [tmp.edges.new((verts[i], verts[(i + 1) % len(verts)])) for i in range(len(verts))]
    bmesh.ops.spin(tmp, geom=verts + edges, cent=(0, 0, 0), axis=(1, 0, 0),
                   angle=2 * math.pi, steps=segments, use_duplicate=False)
    bmesh.ops.remove_doubles(tmp, verts=tmp.verts[:], dist=1e-6)
    # As lathe_z: turn the faces outward, whichever way the outline runs.
    if sum(r0 * x1 - r1 * x0 for (x0, r0), (x1, r1) in zip(outline, outline[1:] + outline[:1])) > 0:
        bmesh.ops.reverse_faces(tmp, faces=tmp.faces[:])
    for v in tmp.verts:
        v.co += centre
    mesh = bpy.data.meshes.new("_tmp")
    tmp.to_mesh(mesh)
    tmp.free()
    bm.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)

def ribbon(bm, frames, width, thickness, closed=False):
    """A thin flat band along a path. frames: (centre, across, normal) per step;
    the band is `width` along `across` and `thickness` along `normal`."""
    rings = []
    for c, a, n in frames:
        a, n = a.normalized(), n.normalized()
        hw, ht = width / 2, thickness / 2
        rings.append([bm.verts.new(c + a * sa * hw + n * sn * ht)
                      for sa, sn in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    count = len(rings) if closed else len(rings) - 1
    for i in range(count):
        r0, r1 = rings[i], rings[(i + 1) % len(rings)]
        for k in range(4):
            bm.faces.new((r0[k], r0[(k + 1) % 4], r1[(k + 1) % 4], r1[k]))
    if not closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])

def rounded_box(bm, centre, size, bevel):
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0, matrix=Matrix.Translation(centre) @ Matrix.Diagonal((*size, 1)))
    if bevel > 0:
        bmesh.ops.bevel(tmp, geom=tmp.edges[:], offset=bevel, segments=2, affect="EDGES", profile=0.5)
    mesh = bpy.data.meshes.new("_tmp")
    tmp.to_mesh(mesh)
    tmp.free()
    bm.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)

def add_text(bm, text, size, extrude, place):
    """Adds `text` (centred, extruded `extrude` each way) to bm. place(x, up,
    depth) maps a point of the flat text (x to the right, up, depth toward the
    reader) onto the item, so the letters can follow a curved surface."""
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

def cylinder_z(bm, centre, radius, height, segments=24):
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius, radius2=radius,
                          depth=height, matrix=Matrix.Translation(centre))

# ================================================================ KneeSleeve
# ~30 cm long, a slightly tapered 7 mm neoprene tube, wider at the thigh end.
KS = Vector((0, 0, 0))
KS_OUT = [(0.265, 0.0), (0.27, 0.3), (0.29, 0.7), (0.315, 1.05), (0.33, 1.31)]
outline = [(0.225, 0.0), (0.265, 0.0), (0.27, 0.3), (0.29, 0.7), (0.315, 1.05), (0.33, 1.31), (0.32, 1.335),
           (0.29, 1.33), (0.275, 1.05), (0.25, 0.7), (0.23, 0.3)]
bm = bmesh.new()
lathe_z(bm, outline, 32, KS)
finish("KneeSleeve_Body", bm, MAT["Black"])

def on_sleeve(z, phi, lift):
    r = interp([(r, z) for r, z in KS_OUT], z) + lift
    return KS + Vector((r * math.cos(phi), r * math.sin(phi), z)), Vector((math.cos(phi), math.sin(phi), 0))

def sleeve_stripe(z_top, z_bottom, phi_top, phi_bottom, steps=20):
    frames = []
    for i in range(steps + 1):
        u = i / steps
        z = z_top + (z_bottom - z_top) * u
        phi = phi_top + (phi_bottom - phi_top) * u
        c, n = on_sleeve(z, phi, 0.008)
        c2, _ = on_sleeve(z + 0.01 * (z_bottom - z_top), phi + 0.01 * (phi_bottom - phi_top), 0.008)
        along = (c2 - c).normalized()
        frames.append((c, n.cross(along), n))
    return frames

bm = bmesh.new()
# A diagonal stripe from the front of the thigh opening round toward the side,
# and a short one low on the other side (like the user's photo).
ribbon(bm, sleeve_stripe(1.29, 0.5, -1.75, -0.6), 0.12, 0.012)
ribbon(bm, sleeve_stripe(0.42, 0.06, 0.75, 1.35, 10), 0.1, 0.012)
finish("KneeSleeve_Stripes", bm, MAT["Red"])

bm = bmesh.new()
# A small badge outline low on the front (no brand name).
def ring_frames(z, phi0, phi1, steps, lift):
    frames = []
    for i in range(steps + 1):
        phi = phi0 + (phi1 - phi0) * i / steps
        c, n = on_sleeve(z, phi, lift)
        frames.append((c, Vector((0, 0, 1)), n))
    return frames
ribbon(bm, ring_frames(0.11, -2.2, -0.94, 10, 0.009), 0.025, 0.012)
ribbon(bm, ring_frames(0.25, -2.2, -0.94, 10, 0.009), 0.025, 0.012)
for phi in (-2.2, -0.94):
    c0, n = on_sleeve(0.11, phi, 0.009)
    c1, _ = on_sleeve(0.25, phi, 0.009)
    ribbon(bm, [(c0, n.cross(Vector((0, 0, 1))), n), (c1, n.cross(Vector((0, 0, 1))), n)], 0.025, 0.012)
# The brand inside the badge, wrapped round the sleeve.
def on_sleeve_text(x, up, depth):
    z = 0.18 + up
    r = interp([(r, z) for r, z in KS_OUT], z)
    phi = -math.pi / 2 + x / r
    rr = r + 0.004 + depth
    return KS + Vector((rr * math.cos(phi), rr * math.sin(phi), z))
add_text(bm, BRAND, 0.05, 0.004, on_sleeve_text)
finish("KneeSleeve_Patch", bm, MAT["Red"])

# ================================================================ WristWrap (rolled)
# A 1 m x 8 cm wrap rolled up (about 7 cm across), lying with its roll axis
# along X and the loose end out to the front, three red stripes round it.
WW = Vector((2.0, 0, 0))
ROLL_R, ROLL_HALF = 0.16, 0.18
bm = bmesh.new()
lathe_x(bm, [(-ROLL_HALF, 0.03), (-ROLL_HALF, ROLL_R - 0.012), (-ROLL_HALF + 0.012, ROLL_R),
             (ROLL_HALF - 0.012, ROLL_R), (ROLL_HALF, ROLL_R - 0.012), (ROLL_HALF, 0.03)], 24, WW + Vector((0, 0, ROLL_R)))
finish("WristWrap_Body", bm, MAT["Black"])

bm = bmesh.new()
tail = [(WW + Vector((0, -0.02 - 0.05 * i, 0.016)), Vector((1, 0, 0)), Vector((0, 0, 1))) for i in range(11)]
ribbon(bm, tail, 2 * ROLL_HALF, 0.03)
finish("WristWrap_Tail", bm, MAT["Black"])

bm = bmesh.new()
for x in (-0.1, 0.0, 0.1):
    frames = []
    for i in range(24):
        a = 2 * math.pi * i / 24
        n = Vector((0, math.cos(a), math.sin(a)))
        frames.append((WW + Vector((x, 0, ROLL_R)) + n * (ROLL_R + 0.004), Vector((1, 0, 0)), n))
    ribbon(bm, frames, 0.035, 0.008, closed=True)
    line = [(WW + Vector((x, -0.06 - 0.045 * i, 0.034)), Vector((1, 0, 0)), Vector((0, 0, 1))) for i in range(11)]
    ribbon(bm, line, 0.035, 0.006)
finish("WristWrap_Stripes", bm, MAT["Red"])

bm = bmesh.new()
# White brand across the loose end, readable from the front.
add_text(bm, BRAND, 0.055, 0.003, lambda x, up, depth: WW + Vector((x, -0.34 + up, 0.038 + depth)))
finish("WristWrap_Text", bm, MAT["White"])

# ================================================================ WristWrapHanging
# The same wrap hanging flat from its thumb loop, for wall hooks. Front is -Y.
WH = Vector((3.5, 0, 0))
WH_LEN = 1.75
bm = bmesh.new()
rounded_box(bm, WH + Vector((0, 0, WH_LEN / 2)), (0.36, 0.03, WH_LEN), 0.01)
finish("WristWrapHanging_Body", bm, MAT["Black"])

bm = bmesh.new()
frames = []
for i in range(25):
    a = math.pi * 2 * i / 24
    n = Vector((math.sin(a), 0, math.cos(a)))
    frames.append((WH + Vector((0, 0, WH_LEN + 0.11)) + n * 0.11, Vector((0, 1, 0)), n))
ribbon(bm, frames[:24], 0.05, 0.02, closed=True)
finish("WristWrapHanging_Loop", bm, MAT["Black"])

bm = bmesh.new()
for x in (-0.1, 0.0, 0.1):
    rounded_box(bm, WH + Vector((x, -0.019, 0.3 + (WH_LEN - 0.3) / 2)), (0.035, 0.008, WH_LEN - 0.32), 0.0)
finish("WristWrapHanging_Stripes", bm, MAT["Red"], smooth=False)

bm = bmesh.new()
rounded_box(bm, WH + Vector((0, -0.018, 0.15)), (0.34, 0.008, 0.22), 0.0)
finish("WristWrapHanging_Velcro", bm, MAT["Grey"], smooth=False)

bm = bmesh.new()
add_text(bm, BRAND, 0.056, 0.003, lambda x, up, depth: WH + Vector((x, -0.023 - depth, WH_LEN - 0.3 + up)))
finish("WristWrapHanging_Text", bm, MAT["White"])

# ================================================================ LeverBelt
# A 10 mm, 10 cm lever belt closed into a loop (about 28 x 22 cm), standing on
# its edge: black suede outside, red lining inside, grey stitching along both
# edges, a steel lever buckle on the front.
LB = Vector((6.0, 0, 0))
EA, EB, BELT_W, BELT_T = 0.62, 0.5, 0.44, 0.045

def ellipse_frames(offset, z, steps=64):
    frames = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        p = Vector((EA * math.cos(t), EB * math.sin(t), 0))
        n = Vector((EB * math.cos(t), EA * math.sin(t), 0)).normalized()
        frames.append((LB + p + n * offset + Vector((0, 0, z)), Vector((0, 0, 1)), n))
    return frames

bm = bmesh.new()
ribbon(bm, ellipse_frames(BELT_T / 2, BELT_W / 2), BELT_W, BELT_T, closed=True)
finish("LeverBelt_Outer", bm, MAT["Black"])
bm = bmesh.new()
ribbon(bm, ellipse_frames(-0.007, BELT_W / 2), BELT_W - 0.01, 0.014, closed=True)
finish("LeverBelt_Lining", bm, MAT["Red"])
bm = bmesh.new()
for z in (0.035, BELT_W - 0.035):
    ribbon(bm, ellipse_frames(BELT_T + 0.002, z), 0.01, 0.004, closed=True)
finish("LeverBelt_Stitch", bm, MAT["Grey"])
bm = bmesh.new()
front = LB + Vector((0, -EB - BELT_T, BELT_W / 2))
rounded_box(bm, front + Vector((0, -0.03, 0)), (0.5, 0.06, 0.36), 0.015)        # base plate
rounded_box(bm, front + Vector((0.02, -0.08, 0)), (0.4, 0.045, 0.27), 0.018)    # lever
rounded_box(bm, front + Vector((-0.24, -0.075, 0)), (0.06, 0.07, 0.3), 0.012)   # hinge
finish("LeverBelt_Lever", bm, MAT["Steel"])
bm = bmesh.new()
# The brand raised in black on the lever's face.
add_text(bm, BRAND, 0.062, 0.004, lambda x, up, depth: front + Vector((0.02 + x, -0.1025 - depth, up)))
finish("LeverBelt_Text", bm, MAT["Black"])

# ================================================================ Mannequins
# Shop display forms on stands (like a gear stand), shoulders 2 studs wide (a
# Roblox avatar's width), short arm stubs, torso about 2.9 tall on a 2.8
# stand. The singlet form also has thighs: a powerlifting singlet is a
# one-piece with mid-thigh legs (user's photo, 2026-10-23): black, a high round
# neck, red trim round the neck and armholes, red panels down the sides of the
# body AND the legs, and a small "CENTRAL" chest badge. The T-shirt form wears a
# black tee with a "CENTRAL" badge.
STAND_TOP = 2.8
FORM = [(0.0, -0.25), (0.7, -0.25), (0.78, 0.0), (0.84, 0.25), (0.8, 0.6), (0.7, 0.95), (0.74, 1.25), (0.86, 1.6), (0.95, 1.95),
        (1.0, 2.15), (0.92, 2.3), (0.6, 2.42), (0.3, 2.5), (0.26, 2.6), (0.25, 2.8), (0.2, 2.86), (0.0, 2.88)]
# The form's outer edge only (without the r = 0 poles), so heights below the
# hips keep the hips' radius instead of shrinking to the centre.
FORM_SORTED = [(r, z) for r, z in FORM if r > 0]
THIGH_LENGTH, THIGH_TOP_R, THIGH_END_R = 1.35, 0.34, 0.29
SIDE_PANEL = 0.86   # |cos| above this faces sideways: the red side panels

def squash(z):
    """Front-to-back depth relative to width: a flat torso, a round neck."""
    if z < 2.2:
        return 0.55
    if z > 2.5:
        return 0.85
    return 0.55 + (z - 2.2) / 0.3 * 0.3

def add_tube(bm, start, direction, length, r_start, r_end, caps, segments=20):
    """A straight (open or capped) tube from `start` along `direction`."""
    tmp = bmesh.new()
    bmesh.ops.create_cone(tmp, cap_ends=caps, cap_tris=False, segments=segments, radius1=r_start, radius2=r_end,
                          depth=length)
    d = direction.normalized()
    rot = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
    tmp.transform(Matrix.Translation(start + d * (length / 2)) @ rot)
    mesh = bpy.data.meshes.new("_tmp")
    tmp.to_mesh(mesh)
    tmp.free()
    bm.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)

def arm_direction(side):
    return Vector((side, 0, -0.75))

def shoulder(base, side):
    return base + Vector((side * 0.78, 0, STAND_TOP + 2.02))

def thigh(base, side):
    """Top of a thigh (inside the hips) and its direction, slightly outward."""
    return base + Vector((side * 0.35, 0, STAND_TOP + 0.1)), Vector((side * 0.06, 0, -1)).normalized()

def thigh_radius(t):
    return THIGH_TOP_R + (THIGH_END_R - THIGH_TOP_R) * t / THIGH_LENGTH

def form_and_stand(prefix, base, legs):
    bm = bmesh.new()
    lathe_z(bm, FORM, 40, base + Vector((0, 0, STAND_TOP)), squash)
    for side in (-1, 1):
        add_tube(bm, shoulder(base, side), arm_direction(side), 0.6, 0.28, 0.25, True)
        if legs:
            top, direction = thigh(base, side)
            add_tube(bm, top, direction, THIGH_LENGTH, THIGH_TOP_R, THIGH_END_R, True, 24)
    finish(prefix + "_Form", bm, MAT["Form"])
    bm = bmesh.new()
    cylinder_z(bm, base + Vector((0, 0, 0.04)), 0.65, 0.08, 32)
    # With legs the pole rises behind the thighs into the seat.
    pole = base + Vector((0, 0.25 if legs else 0, 0))
    top = STAND_TOP + (0.0 if legs else 0.05)
    cylinder_z(bm, pole + Vector((0, 0, 0.08 + (top - 0.08) / 2)), 0.06, top - 0.08, 12)
    finish(prefix + "_Stand", bm, MAT["Stand"])

def outward_face(bm, corners, radial):
    face = bm.faces.new([bm.verts.new(c) for c in corners])
    face.normal_update()
    if face.normal.dot(radial) < 0:
        face.normal_flip()

def garment(base, z0, z1, rings, segments, classify, offsets):
    """A shell over the torso between heights z0 and z1. classify(x, z, theta)
    names each face's piece (or None for a hole); offsets[piece] is how far it
    stands off the form."""
    meshes = {}
    for i in range(rings):
        za, zb = z0 + (z1 - z0) * i / rings, z0 + (z1 - z0) * (i + 1) / rings
        for j in range(segments):
            ta, tb = 2 * math.pi * j / segments, 2 * math.pi * (j + 1) / segments
            zc, tc = (za + zb) / 2, (ta + tb) / 2
            piece = classify(interp(FORM_SORTED, zc) * math.cos(tc), zc, tc)
            if piece is None:
                continue
            off = offsets[piece]
            def point(z, t):
                r = interp(FORM_SORTED, z)
                return base + Vector(((r + off) * math.cos(t), (squash(z) * r + off) * math.sin(t), STAND_TOP + z))
            outward_face(meshes.setdefault(piece, bmesh.new()),
                         [point(za, ta), point(za, tb), point(zb, tb), point(zb, ta)], Vector((math.cos(tc), math.sin(tc), 0)))
    return meshes

def shorts_leg(meshes, base, side, t0, t1, rings, segments, off):
    """One leg of the singlet round a thigh: black, red down the outside."""
    top, d = thigh(base, side)
    u = (Vector((1, 0, 0)) - d * d.x).normalized()
    w = d.cross(u)
    for i in range(rings):
        ta, tb = t0 + (t1 - t0) * i / rings, t0 + (t1 - t0) * (i + 1) / rings
        for j in range(segments):
            aa, ab = 2 * math.pi * j / segments, 2 * math.pi * (j + 1) / segments
            ac = (aa + ab) / 2
            radial = u * math.cos(ac) + w * math.sin(ac)
            piece = "Red" if radial.x * side > SIDE_PANEL else "Black"
            def point(t, a):
                return top + d * t + (u * math.cos(a) + w * math.sin(a)) * (thigh_radius(t) + off)
            outward_face(meshes.setdefault(piece, bmesh.new()),
                         [point(ta, aa), point(ta, ab), point(tb, ab), point(tb, aa)], radial)

def cutter(name, bm):
    """A temporary boolean cutter object."""
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.display_type = "WIRE"
    obj.hide_render = True
    coll.objects.link(obj)
    return obj

def booleans_and_apply(obj, steps):
    """Applies the object's modifiers (solidify), then each (operation, cutter)
    with exact booleans, so openings get smooth edges."""
    for index, (operation, c) in enumerate(steps):
        mod = obj.modifiers.new(f"Cut_{index}", "BOOLEAN")
        mod.operation = operation
        mod.solver = "EXACT"
        mod.object = c
    bpy.context.view_layer.update()
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = bpy.data.meshes.new_from_object(evaluated)
    old = obj.data
    obj.modifiers.clear()
    obj.data = mesh
    bpy.data.meshes.remove(old)
    mesh.name = obj.name

def cylinders(specs, segments=48):
    """One mesh holding several capped cylinders: (centre, axis, radius, length)."""
    bm = bmesh.new()
    for centre, axis, radius, length in specs:
        add_tube(bm, centre - axis.normalized() * (length / 2), axis, length, radius, radius, True, segments)
    return bm

def form_front(x, z):
    """The front (-Y) of the form at x, z, and its outward normal."""
    r, s = interp(FORM_SORTED, z), squash(z)
    y = -s * math.sqrt(max(r * r - x * x, 1e-6))
    return Vector((x, y, z)), Vector((x / (r * r), y / (s * r) ** 2, 0)).normalized()

def chest_badge(base, z, half_w, half_h, off, line, text_size):
    """A red badge outline on the chest with the brand inside, following the form."""
    def point(x, zz):
        p, n = form_front(x, zz)
        return base + Vector((0, 0, STAND_TOP)) + p + n * off, n
    bm = bmesh.new()
    for zz in (z - half_h, z + half_h):
        frames = []
        for i in range(11):
            c, n = point(-half_w + 2 * half_w * i / 10, zz)
            frames.append((c, Vector((0, 0, 1)), n))
        ribbon(bm, frames, line, 0.012)
    for x in (-half_w, half_w):
        c0, n0 = point(x, z - half_h - line / 2)
        c1, n1 = point(x, z + half_h + line / 2)
        ribbon(bm, [(c0, n0.cross(Vector((0, 0, 1))), n0), (c1, n1.cross(Vector((0, 0, 1))), n1)], line, 0.012)
    def on_chest(x, up, depth):
        p, n = form_front(x, z + up)
        return base + Vector((0, 0, STAND_TOP)) + p + n * (off - 0.006 + depth)
    add_text(bm, BRAND, text_size, 0.004, on_chest)
    return bm

# ---------------------------------------------------------------- the singlet
MS = Vector((10.0, 0, 0))
form_and_stand("MannequinSinglet", MS, legs=True)
OFF = 0.03
singlet = garment(MS, -0.25 - OFF, 2.46, 32, 48,
                  lambda x, z, t: "Red" if abs(math.cos(t)) > SIDE_PANEL and z < 1.75 else "Black",
                  {"Black": OFF, "Red": OFF})
# The shorts: separate objects, because the neck and armhole booleans must not
# see them (their overlap with the body shell made the exact boolean drop a leg
# and the crotch). The crotch closes the shell's bottom between the legs, just
# below the form's own bottom (never in the same place, or the form shows through).
shorts = {}
cap = shorts.setdefault("Black", bmesh.new())
ring = []
for j in range(48):
    t = 2 * math.pi * j / 48
    r = interp(FORM_SORTED, -0.25 - OFF)
    ring.append(cap.verts.new(MS + Vector(((r + OFF) * math.cos(t), (squash(0) * r + OFF) * math.sin(t), STAND_TOP - 0.25 - OFF))))
centre = cap.verts.new(MS + Vector((0, 0, STAND_TOP - 0.25 - OFF)))
for j in range(48):
    face = cap.faces.new((centre, ring[(j + 1) % 48], ring[j]))
    face.normal_update()
    if face.normal.z > 0:
        face.normal_flip()
# The legs, from inside the hips down to mid-thigh.
for side in (-1, 1):
    shorts_leg(shorts, MS, side, 0.2, 1.0, 10, 32, 0.035)
finish("MannequinSinglet_Shorts", shorts["Black"], MAT["Black"], solidify=0.012)
finish("MannequinSinglet_ShortsRed", shorts["Red"], MAT["Red"], solidify=0.012)

# Openings: a high round neck and deep armholes. The black and the red side
# panels stop at a band round each opening; that band is the red trim.
TRIM = 0.065
neck = (MS + Vector((0, -0.02, STAND_TOP + 2.75)), Vector((0, 0, 1)), 0.34, 0.9)
arm_l = (MS + Vector((1.02, 0, STAND_TOP + 2.2)), Vector((0, 1, 0)), 0.45, 3)
arm_r = (MS + Vector((-1.02, 0, STAND_TOP + 2.2)), Vector((0, 1, 0)), 0.45, 3)
small = cutter("_Cut_Small", cylinders([neck, arm_l, arm_r]))
big = cutter("_Cut_Big", cylinders([(c, a, r + TRIM, l) for c, a, r, l in (neck, arm_l, arm_r)]))
trim_shell = garment(MS, 1.5, 2.46, 30, 48, lambda x, z, t: "Trim", {"Trim": OFF})["Trim"]
for piece, bm in singlet.items():
    obj = finish("MannequinSinglet_" + piece, bm, MAT["Red"] if piece == "Red" else MAT["Black"], solidify=0.012)
    booleans_and_apply(obj, [("DIFFERENCE", big)])
obj = finish("MannequinSinglet_Trim", trim_shell, MAT["Red"], solidify=0.012)
booleans_and_apply(obj, [("INTERSECT", big), ("DIFFERENCE", small)])
for c in (small, big):
    bpy.data.objects.remove(c, do_unlink=True)
# Big enough to read from across the shop (user, 2026-10-23: the first ones were too small).
finish("MannequinSinglet_Patch", chest_badge(MS, 1.6, 0.34, 0.1, OFF + 0.006, 0.03, 0.15), MAT["Red"])

# ---------------------------------------------------------------- the T-shirt
MT = Vector((13.0, 0, 0))
form_and_stand("MannequinTee", MT, legs=False)
tee = garment(MT, -0.02, 2.46, 28, 44, lambda x, z, t: "Black", {"Black": 0.035})
for side in (-1, 1):
    add_tube(tee["Black"], shoulder(MT, side) - arm_direction(side).normalized() * 0.08, arm_direction(side), 0.48,
             0.34, 0.32, False)
neck_cut = cutter("_Cut_TeeNeck", cylinders([(MT + Vector((0, -0.04, STAND_TOP + 2.65)), Vector((0, 0, 1)), 0.37, 0.7)]))
obj = finish("MannequinTee_Black", tee["Black"], MAT["Black"], solidify=0.012)
booleans_and_apply(obj, [("DIFFERENCE", neck_cut)])
# check_models.py budget (default 5,000): the tee is a large hero display piece, a smooth body-sized shell with
# sleeves; it came out at 5,464 triangles and was uploaded before the budgets existed.
obj["tri_budget"] = 6000
bpy.data.objects.remove(neck_cut, do_unlink=True)
finish("MannequinTee_Logo", chest_badge(MT, 1.6, 0.48, 0.15, 0.041, 0.04, 0.22), MAT["Red"])

bpy.context.view_layer.update()
tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in built}
print("built", len(built), "objects; triangles before solidify:", sum(tris.values()))
for name, count in tris.items():
    print(f"  {name}: {count}")
