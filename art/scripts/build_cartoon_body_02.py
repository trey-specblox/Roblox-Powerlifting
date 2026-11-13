# Cartoon lifter bodies, second test (user 2026-11-12, with screenshots and clips of a chunky Roblox gym game; notes in
# References/Body Study.md). Our own design, following the references' details, not copying their models:
#   - every muscle is its own smooth rounded shape; the shapes are fused into ONE surface (voxel remesh), so where two
#     meet there is a clean crease (pec over abs, delt over chest) instead of a melted blob
#   - the game's ORIGINAL R15 block skeleton (station_animations.py SIZES/JOINTS): arms hang at x +-1.5, hips at 2.0,
#     neck at 4.0, a full-size head on top; the torso's top wraps the bottom of the head (traps / round shoulders), no neck
#   - three builds: Skinny, Heavy, Muscular; preview colours as a tee + shorts with thick white cuffs
# Run inside Blender:  exec(open(r"D:\Powerlifting Roblox\art\scripts\build_cartoon_body_02.py").read())
import math

import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

COLLECTION = "CartoonTest"
VOXEL = 0.022          # studs: fusing resolution (smaller = crisper creases, more triangles before decimating)
TRIANGLES = 12000      # per body, after decimating
SPACING = 4.4          # studs between the builds in the line-up

SKIN = (0.95, 0.76, 0.60, 1)

# The taller bodies (user 2026-11-12): every shape below is written on the block skeleton's heights and remapped by
# lifter_heights.py when it is built (legs x1.23, torso and arms x1.15).
_HEIGHTS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals()
                             else r"D:\Powerlifting Roblox\art\scripts", "lifter_heights.py")
HEIGHTS = {"__name__": "lifter_heights"}
exec(open(_HEIGHTS_PATH).read(), HEIGHTS)


# A shape: (centre, radii, options). Options: "mirror" (add the -X twin), "rot" (degrees x, y, z), "taper" (the
# bottom is (1 - taper) as wide as the middle and the top (1 + taper): a cone-ish forearm or thigh), "boxy" (< 1
# squares the shape off: a torso with rounded corners instead of an egg).
def S(centre, radii, mirror=True, rot=(0, 0, 0), taper=0.0, boxy=1.0):
    return (Vector(centre), Vector(radii), mirror, rot, taper, boxy)


def arm_and_leg(upper, fore, thigh, calf, out=1.5, arm_top=3.98):
    """Shared limb shapes for one build: radii scales for the upper arm, forearm, thigh and calf; where the upper
    arm's top is (the shoulders themselves are each build's own, see shoulders())."""
    return [
        # arm (hanging at x = out)
        S((out, 0.0, arm_top - 0.62), (0.30 * upper, 0.30 * upper, 0.62)),
        S((out, 0.0, 2.80), (0.30 * fore, 0.29 * fore, 0.55), taper=0.28),
        S((out, 0.0, 2.33), (0.19, 0.18, 0.12)),
        # leg (x 0.5)
        S((0.52, -0.02, 1.62), (0.40 * thigh, 0.40 * thigh, 0.70), taper=0.18),
        S((0.50, 0.02, 0.76), (0.27 * calf, 0.27 * calf, 0.55), taper=0.30),
        S((0.50, 0.0, 0.32), (0.18, 0.18, 0.15)),
    ]


def muscular():
    return arm_and_leg(1.0, 1.15, 1.05, 1.0) + [
        S((0, 0.02, 3.15), (0.80, 0.46, 0.85), mirror=False),             # core
        S((0, 0.06, 3.58), (0.92, 0.48, 0.42), mirror=False),             # rib cage
        S((0.42, -0.30, 3.56), (0.54, 0.30, 0.37), rot=(12, 0, 0)),       # pec
        S((0.62, 0.12, 4.00), (0.50, 0.38, 0.34), rot=(0, 30, 0)),        # trap slope
        S((0.64, 0.10, 4.22), (0.26, 0.30, 0.26)),                        # trap peak, climbing beside the head
        S((1.13, 0.0, 3.78), (0.46, 0.48, 0.42)),                         # delt
        S((0.62, 0.18, 3.18), (0.40, 0.38, 0.66), rot=(0, -14, 0)),       # lat
        S((0.17, 0.34, 2.86), (0.17, 0.12, 0.44)),                        # spine muscles
        S((0.19, -0.38, 3.04), (0.19, 0.11, 0.12)),                       # abs, three rows of pillows
        S((0.19, -0.39, 2.78), (0.19, 0.11, 0.12)),
        S((0.18, -0.37, 2.53), (0.18, 0.10, 0.11)),
        S((0.48, -0.08, 2.76), (0.25, 0.31, 0.38)),                       # oblique
        S((0, 0.0, 2.36), (0.60, 0.40, 0.32), mirror=False),              # waist
        S((0, 0.02, 2.12), (0.70, 0.42, 0.30), mirror=False),             # hips
        S((0.32, 0.26, 2.05), (0.36, 0.30, 0.32)),                        # glute
        S((1.47, -0.15, 3.32), (0.33, 0.31, 0.45)),                       # biceps
        S((1.54, 0.14, 3.40), (0.31, 0.29, 0.48)),                        # triceps
        S((0.76, -0.06, 1.72), (0.25, 0.30, 0.52)),                       # outer quad sweep
        S((0.36, -0.18, 1.26), (0.21, 0.20, 0.27)),                       # teardrop above the knee
        S((0.50, 0.13, 0.80), (0.31, 0.29, 0.36)),                        # calf
        S((0, 0.06, 4.04), (0.42, 0.36, 0.24), mirror=False),             # under the head
    ]


# Where each build's arms hang (the middle of the arm, studs from the centre). The skeleton only fixes the shoulder
# PIVOT (x = 1, the block torso's edge); the arm's shape can hang anywhere near it and still swing right. A skinny
# body is narrow, so its arms hang close in (user 2026-11-12: "The bodies are too wide"); the muscular ones hang out at
# the block arm's 1.5.
SKINNY_ARMS = 1.0
HEAVY_ARMS = 1.34


def upper_body(out, arm_r, depth, top_r):
    """A normal person's upper body (user 2026-11-12: the non-buff shoulders looked "popped out of place. Level it with
    the body"): the arms hang where the skeleton puts them (x = out), so the chest and back are as wide as the arms'
    inner edge and each arm hangs FLUSH against the side. The shoulder is a level, rounded corner at the torso's top,
    the arm's top meets it there; no slope out to a cap, no gap to bridge."""
    flush = out - arm_r + 0.06
    return [
        S((0, 0.03, 3.52), (flush, depth, 0.50), mirror=False, boxy=0.62),   # chest and back, out to the arms
        S((out - arm_r * 0.9, 0.0, 3.70), (arm_r * 0.9, arm_r * 1.0, 0.18)),  # fills the armpit crease, below the top line
        S((0, 0.05, 3.99), top_r, mirror=False),                          # round top under the head
    ]


def heavy():
    return arm_and_leg(1.20, 1.10, 1.18, 1.22, out=HEAVY_ARMS, arm_top=3.86) + upper_body(HEAVY_ARMS, 0.36, 0.56,
                                                                                        (0.62, 0.46, 0.26)) + [
        S((0, 0.02, 3.05), (0.92, 0.58, 0.80), mirror=False, boxy=0.8),   # round core
        S((0, -0.20, 2.62), (0.84, 0.70, 0.62), mirror=False),            # belly, low and forward
        S((0.38, -0.30, 3.45), (0.44, 0.30, 0.34)),                       # soft chest
        S((0, -0.31, 3.40), (0.30, 0.22, 0.32), mirror=False),            # between the chest (no dent)
        S((0, 0.02, 2.16), (0.84, 0.50, 0.34), mirror=False),             # hips
        S((0.34, 0.28, 2.04), (0.40, 0.32, 0.34)),                        # glute
    ]


def skinny():
    return arm_and_leg(0.74, 0.80, 0.78, 0.80, out=SKINNY_ARMS, arm_top=3.86) + upper_body(SKINNY_ARMS, 0.222, 0.34,
                                                                                         (0.42, 0.32, 0.20)) + [
        S((0, 0.02, 2.95), (0.64, 0.33, 0.62), mirror=False, boxy=0.75),  # stomach, a little narrower than the chest
        S((0, -0.20, 3.48), (0.55, 0.16, 0.26), mirror=False),            # flat chest, one smooth plate
        S((0, 0.0, 2.36), (0.60, 0.32, 0.32), mirror=False),              # waist
        S((0, 0.02, 2.13), (0.62, 0.34, 0.28), mirror=False),             # hips
        S((0.30, 0.22, 2.06), (0.28, 0.24, 0.28)),
    ]


def collection():
    coll = bpy.data.collections.get(COLLECTION) or bpy.data.collections.new(COLLECTION)
    if coll.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(coll)
    for o in list(coll.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.orphans_purge(do_recursive=True)
    return coll


def material(name, rgba):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = rgba
    m.roughness = 0.35
    return m


def add_shape(bm, centre, radii, rot, taper, flip, boxy=1.0):
    """One smooth ellipsoid (optionally tapered, squared off and turned) into the bmesh."""
    geom = bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=18, radius=1.0)
    verts = geom["verts"]
    r = Euler(tuple(math.radians(a) for a in (rot[0], -rot[1] if flip else rot[1], -rot[2] if flip else rot[2]))).to_matrix()
    c = Vector((-centre.x if flip else centre.x, centre.y, centre.z))
    for v in verts:
        p = Vector(tuple(math.copysign(abs(c) ** boxy, c) for c in v.co))
        k = 1.0 + taper * p.z
        p = Vector((p.x * radii.x * k, p.y * radii.y * k, p.z * radii.z))
        v.co = r @ p + c


# How much each build is smoothed after fusing: the muscular one keeps crisp creases between its muscles; a normal,
# non-buff body melts together (user: the shoulders must look "like a normal person").
SOFTEN = {"CartoonSkinny": 12, "CartoonHeavy": 12, "CartoonMuscular": 4}


def taller(centre, radii):
    """A shape written for the block skeleton's heights, moved and stretched to the taller bodies (lifter_heights.py)."""
    H = HEIGHTS
    c, r = Vector(centre), Vector(radii)
    stretch = H["span"](c.z - r.z, c.z + r.z)
    return Vector((c.x, c.y, H["z"](c.z))), Vector((r.x, r.y, r.z * stretch))


def build_body(name, shapes, x, coll):
    bm = bmesh.new()
    for centre, radii, mirror, rot, taper, boxy in shapes:
        centre, radii = taller(centre, radii)
        add_shape(bm, centre, radii, rot, taper, False, boxy)
        if mirror:
            add_shape(bm, centre, radii, rot, taper, True, boxy)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    coll.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    # Fuse the shapes into one surface: the creases stay where they meet.
    rm = obj.modifiers.new("Fuse", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = VOXEL
    rm.adaptivity = 0.0
    bpy.ops.object.modifier_apply(modifier=rm.name)
    sm = obj.modifiers.new("Soften", "SMOOTH")
    sm.factor = 0.6
    sm.iterations = SOFTEN.get(name, 4)
    bpy.ops.object.modifier_apply(modifier=sm.name)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    if tris > TRIANGLES:
        dec = obj.modifiers.new("Fewer", "DECIMATE")
        dec.ratio = TRIANGLES / tris
        dec.use_symmetry = True
        dec.symmetry_axis = "X"
        bpy.ops.object.modifier_apply(modifier=dec.name)
    for p in me.polygons:
        p.use_smooth = True
    obj.location.x = x
    return obj


def ring(name, centre, rx, ry, thickness, coll, mat):
    """A thick fabric cuff round a limb (or the waist): a squashed torus."""
    bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=thickness, major_segments=40, minor_segments=10,
                                     location=centre)
    o = bpy.context.object
    o.name = name
    o.scale = (rx, ry, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    for c in list(o.users_collection):
        c.objects.unlink(o)
    coll.objects.link(o)
    return o


def cross_section(obj, z, xmin, xmax, band=0.03):
    """Half-widths (x, y) and centre of the body's slice at height z between xmin and xmax (local coordinates)."""
    pts = [v.co for v in obj.data.vertices if abs(v.co.z - z) < band and xmin <= v.co.x <= xmax]
    if not pts:
        return None
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts)))
    return (hi - lo) / 2, (hi + lo) / 2


def dress(obj, shirt, shorts, coll, arm_x=1.5, sleeve_z=3.12, hem_z=1.30, waist_z=2.46):
    """Preview colours: a tee and shorts by height, and the thick white cuffs at the hems (the references' look)."""
    me = obj.data
    mats = [material("CartoonSkin", SKIN), material(obj.name + "_Tee", shirt), material(obj.name + "_Shorts", shorts),
            material("CartoonShoe", (0.10, 0.11, 0.14, 1))]
    for m in mats:
        me.materials.append(m)
    for p in me.polygons:
        c = p.center
        arm = abs(c.x) > arm_x - 0.12
        if c.z < 0.42 and not arm:
            p.material_index = 3
        elif not arm and hem_z < c.z < waist_z + 0.06:
            p.material_index = 2
        elif (not arm and c.z >= waist_z) or (arm and c.z > sleeve_z):
            p.material_index = 1
        else:
            p.material_index = 0
    white = material("CartoonCuff", (0.96, 0.96, 0.95, 1))
    x = obj.location.x
    for side in (1, -1):
        lo, hi = arm_x - 0.45, arm_x + 0.7
        sec = cross_section(obj, sleeve_z, lo if side > 0 else -hi, hi if side > 0 else -lo)
        if sec:
            (hx, hy), c = sec
            ring(obj.name + "_Sleeve%d" % side, (x + c.x, c.y, sleeve_z), hx + 0.02, hy + 0.02, 0.05, coll, white)
        sec = cross_section(obj, hem_z, 0.02 if side > 0 else -1.1, 1.1 if side > 0 else -0.02)
        if sec:
            (hx, hy), c = sec
            ring(obj.name + "_Hem%d" % side, (x + c.x, c.y, hem_z), hx + 0.02, hy + 0.02, 0.05, coll, white)
    inner = arm_x - 0.32          # the waistband goes round the body, not the arms hanging beside it
    sec = cross_section(obj, waist_z, -inner, inner)
    if sec:
        (hx, hy), c = sec
        for dz in (0.0, -0.12):
            ring(obj.name + "_Waist%.0f" % (dz * 100), (x + c.x, c.y, waist_z + dz), hx + 0.03, hy + 0.03, 0.045, coll, white)


def shoes(obj, coll):
    shoe = material("CartoonShoe", (0.10, 0.11, 0.14, 1))
    x = obj.location.x
    for side in (1, -1):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=16, radius=1.0, location=(x + side * 0.5, -0.10, 0.14))
        o = bpy.context.object
        o.name = obj.name + "_Shoe%d" % side
        o.scale = (0.27, 0.44, 0.16)
        bpy.ops.object.transform_apply(scale=True)
        o.data.materials.append(shoe)
        bpy.ops.object.shade_smooth()
        for c in list(o.users_collection):
            c.objects.unlink(o)
        coll.objects.link(o)


def head(name, x, coll):
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=0.6, depth=1.2, location=(x, 0.0, 4.586))
    o = bpy.context.object
    o.name = name
    o.scale = (1.0, 0.85, 1.0)
    bev = o.modifiers.new("Round", "BEVEL")
    bev.width = 0.26
    bev.segments = 8
    o.data.materials.append(material("CartoonSkin", SKIN))
    bpy.ops.object.shade_smooth()
    for c in list(o.users_collection):
        c.objects.unlink(o)
    coll.objects.link(o)


if globals().get("CARTOON_AS_LIBRARY") is not True:
    coll = collection()
    LOOKS = [
        ("CartoonSkinny", skinny(), (0.92, 0.92, 0.90, 1), (0.10, 0.10, 0.12, 1), SKINNY_ARMS),
        ("CartoonHeavy", heavy(), (0.62, 0.65, 0.70, 1), (0.10, 0.10, 0.12, 1), HEAVY_ARMS),
        ("CartoonMuscular", muscular(), (0.08, 0.09, 0.12, 1), (0.08, 0.09, 0.12, 1), 1.5),
    ]
    BODIES = []
    for i, (name, shapes, tee, shorts, arm_x) in enumerate(LOOKS):
        x = i * SPACING
        body = build_body(name, shapes, x, coll)
        dress(body, tee, shorts, coll, arm_x)
        shoes(body, coll)
        head(name + "Head", x, coll)
        BODIES.append(body)
        print("[Cartoon]", name, sum(len(p.vertices) - 2 for p in body.data.polygons), "triangles")
