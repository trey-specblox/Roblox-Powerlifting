# A STYLE TEST, not a game asset yet (user 2026-11-12: "I want models something like this ... I feel like current
# models are just too sloppy", with screenshots of chunky cartoon gym-game bodies). Our own design, not a copy:
# smooth "inflated" cartoon muscles built from blobs (metaballs) that melt into one surface, on the game's ORIGINAL
# R15 block skeleton (station_animations.py SIZES/JOINTS): wide shoulders, arms hanging at x +-1.5, hips at 2.0,
# neck at 4.0 with a full-size Roblox head. On that skeleton every existing animation would keep working.
#
# Builds two looks side by side (Muscular, Heavy) as one-sided-ready meshes, coloured as a tee + shorts for the
# comparison. Run inside Blender:  exec(open(r"D:\Powerlifting Roblox\art\scripts\build_stylised_body_test.py").read())
import bpy
from mathutils import Vector

COLLECTION = "StylisedTest"
SKIN = (0.93, 0.74, 0.58, 1)
HEAD = (0.93, 0.74, 0.58, 1)

# Blob: (centre x, y, z, radii x, y, z). Front is -Y, studs, the R15 block rig's layout (floor at 0).
# Mirrored blobs are given for the +X side only; mirror=True adds the -X twin.
MUSCULAR = [
    # torso: a big V, pecs, traps, abs
    ((0, 0.08, 3.25), (1.1, 0.55, 0.80), False),     # back and lats
    ((0, 0.0, 3.55), (1.05, 0.45, 0.42), False),      # upper chest width
    ((0.44, -0.26, 3.50), (0.62, 0.40, 0.44), True),  # pec
    ((0.40, 0.12, 3.98), (0.50, 0.34, 0.26), True),   # trap
    ((0, 0.0, 2.55), (0.68, 0.42, 0.55), False),      # waist (narrow)
    ((0.16, -0.36, 3.02), (0.17, 0.10, 0.13), True),  # abs, three rows
    ((0.16, -0.37, 2.76), (0.17, 0.10, 0.13), True),
    ((0.16, -0.36, 2.50), (0.16, 0.10, 0.12), True),
    ((0, 0.0, 2.15), (0.78, 0.44, 0.32), False),      # hips
    ((0.36, 0.28, 2.05), (0.40, 0.30, 0.34), True),   # glute
    ((0, 0.02, 4.02), (0.36, 0.30, 0.22), False),     # neck
    # arms (hanging at x 1.5)
    ((1.24, 0.0, 3.78), (0.62, 0.54, 0.50), True),    # delt
    ((1.52, -0.16, 3.33), (0.50, 0.46, 0.58), True),  # biceps
    ((1.56, 0.16, 3.38), (0.46, 0.42, 0.55), True),   # triceps
    ((1.50, -0.02, 2.80), (0.44, 0.42, 0.46), True),  # forearm
    ((1.50, 0.0, 2.45), (0.25, 0.25, 0.22), True),    # wrist
    ((1.50, -0.04, 2.15), (0.24, 0.28, 0.26), True),  # hand (a mitten)
    # legs (x 0.5)
    ((0.53, -0.06, 1.62), (0.52, 0.50, 0.64), True),  # thigh
    ((0.50, 0.10, 0.95), (0.38, 0.40, 0.42), True),   # calf
    ((0.50, 0.0, 0.42), (0.24, 0.26, 0.26), True),    # ankle
    ((0.50, -0.16, 0.13), (0.30, 0.50, 0.15), True),  # foot
]

HEAVY = [
    ((0, 0.05, 3.25), (1.0, 0.55, 0.78), False),      # big round torso
    ((0, -0.18, 2.62), (0.92, 0.70, 0.70), False),    # belly
    ((0.40, -0.22, 3.45), (0.50, 0.35, 0.38), True),  # soft chest
    ((0.36, 0.12, 3.92), (0.42, 0.32, 0.24), True),
    ((0, 0.0, 2.12), (0.82, 0.50, 0.34), False),      # hips
    ((0.36, 0.28, 2.02), (0.42, 0.32, 0.34), True),
    ((0, 0.02, 4.02), (0.40, 0.34, 0.24), False),     # neck
    ((1.20, 0.0, 3.72), (0.48, 0.44, 0.40), True),    # soft shoulder
    ((1.50, 0.0, 3.30), (0.40, 0.40, 0.55), True),    # upper arm
    ((1.50, 0.0, 2.78), (0.34, 0.34, 0.42), True),
    ((1.50, 0.0, 2.45), (0.25, 0.25, 0.22), True),
    ((1.50, -0.04, 2.15), (0.24, 0.28, 0.26), True),
    ((0.52, -0.04, 1.62), (0.48, 0.48, 0.62), True),  # thick thigh
    ((0.50, 0.06, 0.95), (0.33, 0.35, 0.42), True),
    ((0.50, 0.0, 0.42), (0.24, 0.26, 0.26), True),
    ((0.50, -0.16, 0.13), (0.30, 0.50, 0.15), True),
]


def collection():
    coll = bpy.data.collections.get(COLLECTION) or bpy.data.collections.new(COLLECTION)
    if coll.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(coll)
    for o in list(coll.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    return coll


def material(name, rgba):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = rgba
    return m


def blob_body(name, blobs, offset_x, coll):
    mb = bpy.data.metaballs.new(name + "Balls")
    mb.resolution = 0.05
    mb.threshold = 0.35
    obj = bpy.data.objects.new(name + "Balls", mb)
    coll.objects.link(obj)
    for (cx, cy, cz), (rx, ry, rz), mirror in blobs:
        for sx in ((1, -1) if mirror else (1,)):
            e = mb.elements.new(type="ELLIPSOID")
            e.co = (cx * sx, cy, cz)
            e.radius = 1.55   # the surface sits at ~0.64 of a blob's field, so this makes it show at its size
            e.size_x, e.size_y, e.size_z = rx, ry, rz
            e.stiffness = 1.0
    obj.location.x = offset_x
    # Into a mesh, smoothed.
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(deps))
    body = bpy.data.objects.new(name, me)
    coll.objects.link(body)
    body.location.x = offset_x
    bpy.data.objects.remove(obj, do_unlink=True)
    for p in me.polygons:
        p.use_smooth = True
    sm = body.modifiers.new("Smooth", "CORRECTIVE_SMOOTH")
    sm.iterations = 6
    sm.smooth_type = "LENGTH_WEIGHTED"
    return body


def paint(body, shirt, shorts, shoes):
    """Preview colours by height: shirt on the torso and upper arms, shorts on the hips and thighs, shoes."""
    me = body.data
    mats = [material("StyleSkin", SKIN), material(body.name + "_Shirt", shirt), material(body.name + "_Shorts", shorts),
            material(body.name + "_Shoes", shoes)]
    for m in mats:
        me.materials.append(m)
    for p in me.polygons:
        c = p.center
        arm = abs(c.x) > 1.05
        if c.z < 0.30:
            p.material_index = 3
        elif (not arm) and 1.25 < c.z < 2.40:
            p.material_index = 2
        elif (not arm and 2.40 <= c.z < 3.98) or (arm and c.z > 3.30):
            p.material_index = 1
        else:
            p.material_index = 0


def head(name, x, coll):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.6, depth=1.2, location=(x, 0.0, 4.6))
    o = bpy.context.object
    o.name = name
    o.scale = (1.0, 0.85, 1.0)
    bev = o.modifiers.new("Round", "BEVEL")
    bev.width = 0.25
    bev.segments = 6
    o.data.materials.append(material("StyleHead", HEAD))
    bpy.ops.object.shade_smooth()
    for c in list(o.users_collection):
        c.objects.unlink(o)
    coll.objects.link(o)
    return o


coll = collection()
m = blob_body("StyleMuscular", MUSCULAR, 0.0, coll)
paint(m, (0.62, 0.64, 0.68, 1), (0.10, 0.28, 0.70, 1), (0.12, 0.12, 0.14, 1))
head("StyleMuscularHead", 0.0, coll)
h = blob_body("StyleHeavy", HEAVY, 4.2, coll)
paint(h, (0.75, 0.16, 0.16, 1), (0.10, 0.10, 0.12, 1), (0.12, 0.12, 0.14, 1))
head("StyleHeavyHead", 4.2, coll)
print("[StyleTest]", m.name, len(m.data.polygons), h.name, len(h.data.polygons))
