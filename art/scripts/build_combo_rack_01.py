# Builds ComboRack_01 (black combo rack with a bench) in the live Blender scene.
# Reference: References/Visual Style/Images/Rack_ERCombo_Bench.webp (simplified, no branding).
# Units: 1 Blender unit = 1 Roblox stud. Blender is Z-up.
# Rack origin: world (0,0,0) = centre line of the tall posts, at floor level.
# Front of the rack faces -Y: the open side where the lifter walks out for squat,
# lies with feet toward for bench, and stands for deadlift (in front of the rack).
# "Left" = -X = the viewer's left when looking at the Front view.
#
# The bench is two separate parts, Bench_Pad and Bench_Frame, so the game can hide
# them for squat and deadlift (GAME_DESIGN.md section 34.12, decision 15).
# Run in an otherwise empty file: parts are replaced by name on every run.
#
# Detail pass (2026-10-18): edges are rounded in the mesh itself (bmesh bevel, not a
# modifier), faces are shaded smooth with sharp edges above 50 degrees, and a
# Weighted Normal modifier keeps the flat sides flat. Phone budget: about 8-12k
# triangles for the whole station (printed at the end of a run).
import bpy, bmesh, math
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

RACK = "ComboRack_01"
BENCH_PARTS = ("Bench_Pad", "Bench_Frame")

UX = 2.85                 # tall post / spotter post centre lines (X), same width as PowerRack_01
BASE_H = 0.25             # base rails occupy z 0 .. 0.25; posts stand on them

# Tall posts: black outer sleeve + silver insert with the J-cup holes.
SLEEVE_T, SLEEVE_TOP = 0.30, 2.90
INSERT_T, INSERT_Z0, INSERT_TOP = 0.22, 2.50, 7.00   # insert continues hidden inside the sleeve
SLEEVE_HOLES = [1.22, 1.57, 1.92, 2.27, 2.62]
INSERT_HOLES = [3.10 + i * 0.35 for i in range(11)]  # z = 3.10 .. 6.60
BENCH_HOLE, SQUAT_HOLE = INSERT_HOLES[2], INSERT_HOLES[4]   # 3.80 / 4.50 (provisional)
JCUP_Z = BENCH_HOLE        # modelled at bench height; the game may move the J-cups later

# Short front posts carry the front end of the safety arms.
SPOT_Y, SPOT_T, SPOT_TOP = -2.60, 0.25, 2.60
SPOT_HOLES = [1.22, 1.57, 1.92, 2.27]
SAFETY_Z, SAFETY_T = 1.92, 0.16                      # arm top at z 2.0
SAFETY_Y0, SAFETY_Y1 = -SLEEVE_T / 2, -2.95

RAIL_Y0, RAIL_Y1 = -2.90, 1.95                       # side base rails (Y extent)

# Bench (feet toward -Y, head under the bar)
PAD_W, PAD_Y0, PAD_Y1, PAD_TOP, PAD_THICK = 1.24, -3.40, 0.60, 1.20, 0.30

# Rounding (bevel width, segments) per kind of part
TUBE_BEVEL = (0.03, 2)
SMALL_BEVEL = (0.02, 2)
PAD_BEVEL = (0.09, 3)
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

MAT_STEEL = material("Steel_BlackPainted", (0.02, 0.02, 0.022), 0.0, 0.8)
MAT_ZINC = material("Steel_ZincPlated", (0.62, 0.63, 0.65), 1.0, 0.35)
MAT_HARDWARE = material("Steel_Hardware", (0.18, 0.18, 0.19), 1.0, 0.45)
MAT_RUBBER = material("Rubber_Black", (0.03, 0.03, 0.03), 0.0, 0.95)
MAT_VINYL = material("Vinyl_Black", (0.015, 0.015, 0.015), 0.0, 0.6)

# ---------------------------------------------------------------- helpers
coll = bpy.data.collections.get(RACK)
if coll is None:
    coll = bpy.data.collections.new(RACK)
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

def add_box(bm, x0, x1, y0, y1, z0, z1, bevel=None):
    """Box from bounds; bevel = (width, segments) rounds all 12 edges."""
    c = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    m = Matrix.Translation(c) @ Matrix.Diagonal((x1 - x0, y1 - y0, z1 - z0, 1.0))
    verts = bmesh.ops.create_cube(bm, size=1.0, matrix=m)["verts"]
    if bevel:
        edges = list({e for v in verts for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=bevel[0], segments=bevel[1], profile=0.5,
                        affect="EDGES", clamp_overlap=True)

def box_object(name, mat, bevel, *bounds):
    bm = bmesh.new()
    add_box(bm, *bounds, bevel=bevel)
    return finish(name, bm, mat)

def add_cylinder(bm, centre, axis, radius, length, segments):
    """Low-poly capped cylinder. axis is 'X', 'Y' or 'Z'."""
    rot = {"X": Matrix.Rotation(math.pi / 2, 4, "Y"),
           "Y": Matrix.Rotation(math.pi / 2, 4, "X"),
           "Z": Matrix.Identity(4)}[axis]
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments,
                          radius1=radius, radius2=radius, depth=length,
                          matrix=Matrix.Translation(centre) @ rot)

def add_profile_extrusion(bm, profile, axis, a0, a1):
    """Extrudes a closed 2D outline along X (profile in (y, z)) or Y (profile in (x, z))."""
    def vert(a, p, q):
        return bm.verts.new((a, p, q) if axis == "X" else (p, a, q))
    start = [vert(a0, p, q) for p, q in profile]
    end = [vert(a1, p, q) for p, q in profile]
    caps = [bm.faces.new(start), bm.faces.new(list(reversed(end)))]
    n = len(profile)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((start[i], start[j], end[j], end[i]))
    bmesh.ops.triangulate(bm, faces=caps, quad_method="BEAUTY", ngon_method="EAR_CLIP")

def arc(cy, cz, r, a0, a1, n):
    """Points on a circle arc in the (y, z) plane, from angle a0 to a1 (degrees), n steps."""
    return [(cy + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cz + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]

def punch_holes(bm, name, cx, hole_zs, hole, hole_depth):
    """Square holes in the front and back (Y-facing) flat faces of a tube centred on x = cx."""
    geom = lambda: bm.verts[:] + bm.edges[:] + bm.faces[:]
    for z in hole_zs:
        for zz in (z - hole / 2, z + hole / 2):
            bmesh.ops.bisect_plane(bm, geom=geom(), plane_co=(0, 0, zz), plane_no=(0, 0, 1))
    for xx in (cx - hole / 2, cx + hole / 2):
        bmesh.ops.bisect_plane(bm, geom=geom(), plane_co=(xx, 0, 0), plane_no=(1, 0, 0))
    bm.normal_update()
    hole_faces = []
    for f in bm.faces:
        if abs(f.normal.y) < 0.99:
            continue
        c = f.calc_center_median()
        if abs(c.x - cx) < hole / 2 and any(abs(c.z - z) < hole / 2 for z in hole_zs):
            hole_faces.append(f)
    assert len(hole_faces) == len(hole_zs) * 2, (name, len(hole_faces))
    bmesh.ops.inset_individual(bm, faces=hole_faces, thickness=0.0, depth=-hole_depth,
                               use_even_offset=True)

def post_mesh(cx, cy, size, z0, z1, hole_zs, hole, hole_depth, name, bevel=TUBE_BEVEL):
    """Rounded square tube from z0 to z1 with holes in its front and back faces (open bmesh)."""
    bm = bmesh.new()
    add_box(bm, cx - size / 2, cx + size / 2, cy - size / 2, cy + size / 2, z0, z1, bevel=bevel)
    punch_holes(bm, name, cx, hole_zs, hole, hole_depth)
    return bm

SIDES = (("Left", -1), ("Right", 1))
parts = []

# ---------------------------------------------------------------- tall posts
for side, sx in SIDES:
    cx = sx * UX
    name = "Upright_" + side
    parts.append(finish(name, post_mesh(cx, 0.0, SLEEVE_T, BASE_H, SLEEVE_TOP,
                                        SLEEVE_HOLES, 0.12, 0.06, name), MAT_STEEL))
    name = "UprightInsert_" + side
    parts.append(finish(name, post_mesh(cx, 0.0, INSERT_T, INSERT_Z0, INSERT_TOP,
                                        INSERT_HOLES, 0.09, 0.05, name, SMALL_BEVEL), MAT_ZINC))

bm = bmesh.new()   # pull-pin that locks each insert, on the sleeve's outer side near its top
for side, sx in SIDES:
    x = sx * (UX + SLEEVE_T / 2)
    add_cylinder(bm, (x + sx * 0.03, 0.0, SLEEVE_TOP - 0.15), "X", 0.035, 0.06, 8)
    add_cylinder(bm, (x + sx * 0.075, 0.0, SLEEVE_TOP - 0.15), "X", 0.06, 0.03, 10)
parts.append(finish("InsertLockPins", bm, MAT_HARDWARE))

# ---------------------------------------------------------------- spotter posts + safety arms
# Each short post carries a small open cradle on top, like the hooks in the reference photo.
CRADLE_Z0, CRADLE_BACK = SPOT_TOP, 0.20
for side, sx in SIDES:
    cx = sx * UX
    name = "SpotterPost_" + side
    bm = post_mesh(cx, SPOT_Y, SPOT_T, BASE_H, SPOT_TOP, SPOT_HOLES, 0.10, 0.05, name)
    yf, yb = SPOT_Y - SPOT_T / 2, SPOT_Y + CRADLE_BACK      # front wall / back lip (outer faces)
    cradle = ([(yb, CRADLE_Z0), (yb, CRADLE_Z0 + 0.15)]
              + arc(yb - 0.025, CRADLE_Z0 + 0.15, 0.025, 0, 180, 3)[1:]   # rounded lip top
              + [(yb - 0.05, CRADLE_Z0 + 0.08)]
              + arc(yf + 0.11, CRADLE_Z0 + 0.13, 0.05, 270, 180, 3)       # rounded seat
              + [(yf + 0.06, CRADLE_Z0 + 0.32)]
              + arc(yf + 0.03, CRADLE_Z0 + 0.32, 0.03, 0, 180, 3)[1:]     # rounded front wall top
              + [(yf, CRADLE_Z0)])
    add_profile_extrusion(bm, cradle, "X", cx - SPOT_T / 2, cx + SPOT_T / 2)
    parts.append(finish(name, bm, MAT_STEEL))

    bm = bmesh.new()
    add_box(bm, cx - SAFETY_T / 2, cx + SAFETY_T / 2, SAFETY_Y1, SAFETY_Y0,
            SAFETY_Z - SAFETY_T / 2, SAFETY_Z + SAFETY_T / 2, bevel=SMALL_BEVEL)
    BR = SAFETY_T / 2 + 0.04     # bracket sleeve where the arm meets the tall post
    add_box(bm, cx - BR, cx + BR, SAFETY_Y0 - 0.22, SAFETY_Y0, SAFETY_Z - BR, SAFETY_Z + BR,
            bevel=SMALL_BEVEL)
    parts.append(finish("SafetyArm_" + side, bm, MAT_STEEL))

bm = bmesh.new()   # lock pins on the outer side of both safety-arm supports, level with the arm
for side, sx in SIDES:
    for half, y in ((SLEEVE_T / 2, 0.0), (SPOT_T / 2, SPOT_Y)):
        x = sx * (UX + half)
        add_cylinder(bm, (x + sx * 0.03, y, SAFETY_Z), "X", 0.03, 0.06, 8)
        add_cylinder(bm, (x + sx * 0.07, y, SAFETY_Z), "X", 0.05, 0.025, 10)
parts.append(finish("SafetyPins", bm, MAT_HARDWARE))

# ---------------------------------------------------------------- base
OUT_X, IN_X = UX + SLEEVE_T / 2, UX - SLEEVE_T / 2      # 3.0 / 2.7
BACK_Y0 = RAIL_Y1 - SLEEVE_T
FOOT_X1 = 3.90
parts += [
    box_object("BaseRail_Left", MAT_STEEL, TUBE_BEVEL, -OUT_X, -IN_X, RAIL_Y0, RAIL_Y1, 0.0, BASE_H),
    box_object("BaseRail_Right", MAT_STEEL, TUBE_BEVEL, IN_X, OUT_X, RAIL_Y0, RAIL_Y1, 0.0, BASE_H),
    box_object("BaseRail_Back", MAT_STEEL, TUBE_BEVEL, -IN_X, IN_X, BACK_Y0, RAIL_Y1, 0.0, BASE_H),
    box_object("BaseFoot_Left", MAT_STEEL, TUBE_BEVEL, -FOOT_X1, -OUT_X, -0.15, 0.15, 0.0, 0.20),
    box_object("BaseFoot_Right", MAT_STEEL, TUBE_BEVEL, OUT_X, FOOT_X1, -0.15, 0.15, 0.0, 0.20),
    box_object("SpotterDeck", MAT_STEEL, SMALL_BEVEL, -IN_X, IN_X, 0.75, BACK_Y0, 0.0, 0.15),
]

bm = bmesh.new()   # rubber end caps on the open tube ends of the base
CAP = 0.05
for sx in (-1, 1):
    x0, x1 = sorted((sx * FOOT_X1, sx * (FOOT_X1 + CAP)))
    add_box(bm, x0, x1, -0.16, 0.16, 0.0, 0.21, bevel=(0.015, 1))
    for y0, y1 in ((RAIL_Y0 - CAP, RAIL_Y0), (RAIL_Y1, RAIL_Y1 + CAP)):
        add_box(bm, sx * UX - 0.16, sx * UX + 0.16, y0, y1, 0.0, BASE_H + 0.01, bevel=(0.015, 1))
parts.append(finish("FootCaps", bm, MAT_RUBBER))

# ---------------------------------------------------------------- J-cups (on the insert's front face)
F = -INSERT_T / 2
PLATE, SEAT_Y, HOOK_T, LIP_T = 0.06, 0.34, 0.07, 0.07
Z_BOT, Z_TOP, LIP_TOP = JCUP_Z - 0.45, JCUP_Z + 0.15, JCUP_Z - 0.20
SEAT_Z = Z_BOT + HOOK_T
YF, YFI, YPI = F - SEAT_Y, F - SEAT_Y + LIP_T, F - PLATE     # front outer / lip inner / plate inner
R_OUT, R_IN = 0.08, 0.04
JCUP_PROFILE = ([(F, Z_TOP), (F, Z_BOT)]
                + arc(YF + R_OUT, Z_BOT + R_OUT, R_OUT, 270, 180, 4)       # rounded bottom-front
                + [(YF, LIP_TOP)]
                + arc(YF + LIP_T / 2, LIP_TOP, LIP_T / 2, 180, 0, 3)[1:-1] # rounded lip top
                + [(YFI, LIP_TOP)]
                + arc(YFI + R_IN, SEAT_Z + R_IN, R_IN, 180, 270, 3)        # lip-to-seat
                + arc(YPI - R_IN, SEAT_Z + R_IN, R_IN, 270, 360, 3)        # seat-to-plate
                + [(YPI, Z_TOP)])
LINER_T, LINER_TOP = 0.03, JCUP_Z - 0.10
for side, sx in SIDES:
    cx = sx * UX
    bm = bmesh.new()
    add_profile_extrusion(bm, JCUP_PROFILE, "X", cx - 0.15, cx + 0.15)
    parts.append(finish("JCup_" + side, bm, MAT_STEEL))
    bm = bmesh.new()
    add_box(bm, cx - 0.13, cx + 0.13, YFI + R_IN, YPI - R_IN, SEAT_Z, SEAT_Z + LINER_T)
    add_box(bm, cx - 0.13, cx + 0.13, YPI - LINER_T, YPI, SEAT_Z + R_IN, LINER_TOP)
    parts.append(finish("JCupLiner_" + side, bm, MAT_RUBBER))
    bm = bmesh.new()   # pull-pin knob on the J-cup face, level with its hole
    add_cylinder(bm, (cx, YPI - 0.02, JCUP_Z), "Y", 0.035, 0.04, 10)
    parts.append(finish("JCupPin_" + side, bm, MAT_HARDWARE))

# ---------------------------------------------------------------- frame bolts
BOLT_R, BOLT_L = 0.045, 0.03
bm = bmesh.new()
def bolt(x, y, z, axis):
    add_cylinder(bm, (x, y, z), axis, BOLT_R, BOLT_L, 6)
for sx in (-1, 1):
    bolt(sx * 3.60, 0.0, 0.20 + BOLT_L / 2, "Z")                      # stabiliser feet
    bolt(sx * (OUT_X + BOLT_L / 2), SPOT_Y, BASE_H / 2, "X")           # spotter post bases
    bolt(sx * (OUT_X + BOLT_L / 2), BACK_Y0 + SLEEVE_T / 2, BASE_H / 2, "X")   # back rail joints
    for y in (0.90, BACK_Y0 - 0.15):
        bolt(sx * (IN_X - 0.20), y, 0.15 + BOLT_L / 2, "Z")            # spotter deck corners
parts.append(finish("FrameBolts", bm, MAT_HARDWARE))

# ---------------------------------------------------------------- bench (separate, hideable)
PAD_BOT = PAD_TOP - PAD_THICK
bm = bmesh.new()
add_box(bm, -PAD_W / 2, PAD_W / 2, PAD_Y0, PAD_Y1, PAD_BOT, PAD_TOP, bevel=PAD_BEVEL)
parts.append(finish("Bench_Pad", bm, MAT_VINYL))

SPINE_Z0 = PAD_BOT - 0.16
bm = bmesh.new()
add_box(bm, -0.22, 0.22, PAD_Y0 + 0.25, PAD_Y1 - 0.25, SPINE_Z0, PAD_BOT, bevel=SMALL_BEVEL)  # pad rail
for y in (PAD_Y0 + 0.50, PAD_Y1 - 0.45):
    add_box(bm, -0.09, 0.09, y - 0.09, y + 0.09, 0.14, SPINE_Z0, bevel=SMALL_BEVEL)    # leg post
    add_box(bm, -0.75, 0.75, y - 0.10, y + 0.10, 0.0, 0.15, bevel=TUBE_BEVEL)          # foot tube
parts.append(finish("Bench_Frame", bm, MAT_STEEL))

print("built", len(parts), "parts:", [p.name for p in parts])

# ---------------------------------------------------------------- triangle budget (read-only)
bpy.context.view_layer.update()   # new objects' matrix_world is only valid after this
tris = {p.name: sum(len(f.vertices) - 2 for f in p.data.polygons) for p in parts}
print("triangles: total", sum(tris.values()), "| largest", max(tris.items(), key=lambda kv: kv[1]))

# ---------------------------------------------------------------- clearance checks (read-only)
# Keep-out boxes for a future barbell and lifter. They are only tested, never added to the scene.
# A barbell's plate sleeves must start at least 3.2 studs from its centre (plates outside the J-cups).
# Plate size and sleeve end follow art/scripts/build_barbell_01.py (450 mm plates = 2.0 studs
# across, sleeves to 4.95; revised 2026-10-19).
BAR_R, SLEEVE_X, PLATE_X1, PLATE_R = 0.10, 3.20, 4.95, 1.00
BAR_Y = F - SEAT_Y / 2 - 0.03              # bar centre when racked, inside the J-cup
BENCH_BAR_Z = SEAT_Z + BAR_R               # bar centre racked at bench height
SQUAT_BAR_Z = BENCH_BAR_Z + (SQUAT_HOLE - BENCH_HOLE)
CHEST_BAR_Z = PAD_TOP + 1.0 + BAR_R        # bar touching a lying R15 lifter's chest
DEADLIFT_Y = -4.20

KEEP_OUT = {
    # bench: bar from the J-cups down to the chest, moving toward the feet
    "bench bar path": ((-SLEEVE_X, SLEEVE_X), (-1.6, BAR_Y + BAR_R), (CHEST_BAR_Z - BAR_R, BENCH_BAR_Z + BAR_R), {"JCup", "JCupLiner"}),
    "bench plates L": ((-PLATE_X1, -SLEEVE_X), (-1.9, BAR_Y + 0.3), (CHEST_BAR_Z - PLATE_R, BENCH_BAR_Z + PLATE_R), set()),
    "bench plates R": ((SLEEVE_X, PLATE_X1), (-1.9, BAR_Y + 0.3), (CHEST_BAR_Z - PLATE_R, BENCH_BAR_Z + PLATE_R), set()),
    "bench lifter":   ((-1.0, 1.0), (-2.6, 0.5), (PAD_TOP + 0.01, PAD_TOP + 1.0), set()),
    # squat: racked bar and walkout to 1.6 studs in front of the posts
    "squat bar":      ((-SLEEVE_X, SLEEVE_X), (-1.6, BAR_Y + BAR_R), (SQUAT_BAR_Z - BAR_R, SQUAT_BAR_Z + BAR_R), {"JCup", "JCupLiner"}),
    "squat plates L": ((-PLATE_X1, -SLEEVE_X), (-1.9, BAR_Y + 0.3), (SQUAT_BAR_Z - PLATE_R, SQUAT_BAR_Z + PLATE_R), set()),
    "squat plates R": ((SLEEVE_X, PLATE_X1), (-1.9, BAR_Y + 0.3), (SQUAT_BAR_Z - PLATE_R, SQUAT_BAR_Z + PLATE_R), set()),
    # deadlift: bar and plates on the floor in front of the rack, lifter standing behind it
    "deadlift bar":   ((-PLATE_X1, PLATE_X1), (DEADLIFT_Y - PLATE_R, DEADLIFT_Y + PLATE_R), (0.0, 2 * PLATE_R), set()),
    "deadlift lifter": ((-1.2, 1.2), (DEADLIFT_Y - 1.6, DEADLIFT_Y - PLATE_R), (0.0, 5.0), set()),
}
# The bench is hidden for squat and deadlift, so it only counts for bench-press checks.
SKIP_BENCH = {"squat bar", "squat plates L", "squat plates R", "deadlift bar", "deadlift lifter", "bench lifter"}

def bvh_of_box(xs, ys, zs):
    bm = bmesh.new()
    add_box(bm, xs[0], xs[1], ys[0], ys[1], zs[0], zs[1])
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    return tree

def bvh_of_object(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(obj.matrix_world)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    return tree

def inside(obj, xs, ys, zs):
    for v in obj.data.vertices:
        p = obj.matrix_world @ v.co
        if xs[0] < p.x < xs[1] and ys[0] < p.y < ys[1] and zs[0] < p.z < zs[1]:
            return True
    return False

part_trees = {p.name: bvh_of_object(p) for p in parts}
problems = []
for label, (xs, ys, zs, allowed_prefixes) in KEEP_OUT.items():
    box = bvh_of_box(xs, ys, zs)
    for p in parts:
        if p.name.split("_")[0] in allowed_prefixes:
            continue
        if label in SKIP_BENCH and p.name in BENCH_PARTS:
            continue
        if box.overlap(part_trees[p.name]) or inside(p, xs, ys, zs):
            problems.append(f"{label}: {p.name}")
print(f"bar rest heights: bench {BENCH_BAR_Z:.2f}, squat {SQUAT_BAR_Z:.2f}; chest {CHEST_BAR_Z:.2f}; bar y {BAR_Y:.2f}")
print("CLEARANCE OK" if not problems else "CLEARANCE PROBLEMS: " + "; ".join(problems))
