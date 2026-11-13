# Cartoon hands with real fingers, as hand-shape swaps (user 2026-11-12: "Lets use hand-shape swaps"; references in
# References/Body Study.md: big chunky hands, knuckles, a thumb, fingers wrapping the bar). One mesh per shape; a
# celebration or lift shows the shape it needs (Sky Point and "shhh" use Point).
#
# Hand space: the wrist at the origin, the hand hanging down (-Z), the palm facing -Y, the thumb on +X (a right hand
# seen from the front; the left hand is the mirror). Studs, sized for the cartoon bodies (build_cartoon_body_02.py).
# Run inside Blender after build_cartoon_body_02.py:
#   exec(open(r"D:\Powerlifting Roblox\art\scripts\build_cartoon_hands_02.py").read())
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

COLLECTION = "CartoonTest"
VOXEL = 0.011
TRIANGLES = 2500
SKIN = (0.95, 0.76, 0.60, 1)

PALM = (Vector((0, 0, -0.20)), Vector((0.21, 0.12, 0.165)))
# Finger roots along the bottom of the palm (x), and segment lengths, thickest first.
FINGERS = {"Index": 0.135, "Middle": 0.045, "Ring": -0.045, "Pinky": -0.13}
SEGMENTS = {"Index": (0.13, 0.095, 0.075), "Middle": (0.14, 0.10, 0.08), "Ring": (0.13, 0.095, 0.075),
            "Pinky": (0.105, 0.08, 0.065)}
RADIUS = {"Index": 0.064, "Middle": 0.066, "Ring": 0.063, "Pinky": 0.055}

# Per shape: each finger's three curl angles (degrees, toward the palm), and the thumb (base turn, then curls).
CURLED = (85, 100, 70)
SHAPES = {
    "Fist": {"fingers": {f: CURLED for f in FINGERS}, "thumb": "across"},
    "Open": {"fingers": {f: (6, 8, 4) for f in FINGERS}, "thumb": "open"},
    "Point": {"fingers": {"Index": (0, 0, 0), "Middle": CURLED, "Ring": CURLED, "Pinky": CURLED}, "thumb": "across"},
    "ThumbsUp": {"fingers": {f: CURLED for f in FINGERS}, "thumb": "up"},
}


def capsule(bm, a, b, r):
    """A rounded segment from a to b: an ellipsoid along the segment, a little longer than it."""
    d = b - a
    length = d.length
    geom = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=1.0)
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix()
    mid = (a + b) / 2
    for v in geom["verts"]:
        p = Vector((v.co.x * r, v.co.y * r, v.co.z * (length / 2 + r * 0.75)))
        v.co = rot @ p + mid


def blob(bm, centre, radii, boxy=1.0):
    """An ellipsoid; boxy < 1 squares it off (a rounded block, like the references' palms)."""
    geom = bmesh.ops.create_uvsphere(bm, u_segments=22, v_segments=14, radius=1.0)
    for v in geom["verts"]:
        x, y, z = (math.copysign(abs(c) ** boxy, c) for c in v.co)
        v.co = Vector((x * radii.x, y * radii.y, z * radii.z)) + centre


def finger(bm, root, lengths, curls, r):
    """Segments from the root, each bending further toward the palm (-Y)."""
    direction = Vector((0, 0, -1))
    at = root
    angle = 0.0
    for length, curl in zip(lengths, curls):
        angle += math.radians(curl)
        # Bend in the Y-Z plane: down at 0, toward the palm (-Y) and back up as it curls.
        direction = Vector((0, -math.sin(angle), -math.cos(angle)))
        nxt = at + direction * length
        capsule(bm, at, nxt, r)
        at = nxt
        r *= 0.92


def thumb(bm, kind):
    base = Vector((0.17, -0.05, -0.13))
    if kind == "open":
        pts = [base, base + Vector((0.08, -0.05, -0.10)), base + Vector((0.13, -0.08, -0.19))]
    elif kind == "up":
        pts = [base, base + Vector((0.04, -0.08, 0.06)), base + Vector((0.05, -0.10, 0.16))]
    else:  # across the curled fingers, in front of them
        pts = [base, base + Vector((-0.02, -0.12, -0.12)), base + Vector((-0.12, -0.17, -0.17))]
    capsule(bm, Vector((0.12, -0.03, -0.10)), pts[0], 0.075)     # the thumb's root muscle
    capsule(bm, pts[0], pts[1], 0.062)
    capsule(bm, pts[1], pts[2], 0.056)


def make_hand(shape, coll):
    spec = SHAPES[shape]
    bm = bmesh.new()
    blob(bm, PALM[0], PALM[1], boxy=0.55)
    blob(bm, Vector((0, 0, -0.03)), Vector((0.19, 0.13, 0.11)))     # wrist
    for name, x in FINGERS.items():
        root = Vector((x, 0.0, -0.33))
        blob(bm, root + Vector((0, -0.01, 0.02)), Vector((RADIUS[name] * 1.1,) * 3))   # knuckle
        finger(bm, root, SEGMENTS[name], spec["fingers"][name], RADIUS[name])
    thumb(bm, spec["thumb"])
    me = bpy.data.meshes.new("Hand_" + shape)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("Hand_" + shape, me)
    coll.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    rm = obj.modifiers.new("Fuse", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = VOXEL
    bpy.ops.object.modifier_apply(modifier=rm.name)
    sm = obj.modifiers.new("Soften", "SMOOTH")
    sm.factor = 0.5
    sm.iterations = 3
    bpy.ops.object.modifier_apply(modifier=sm.name)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    if tris > TRIANGLES:
        dec = obj.modifiers.new("Fewer", "DECIMATE")
        dec.ratio = TRIANGLES / tris
        bpy.ops.object.modifier_apply(modifier=dec.name)
    for p in me.polygons:
        p.use_smooth = True
    m = bpy.data.materials.get("CartoonSkin") or bpy.data.materials.new("CartoonSkin")
    m.diffuse_color = SKIN
    me.materials.append(m)
    return obj


if globals().get("CARTOON_AS_LIBRARY") is not True:
    coll = bpy.data.collections.get(COLLECTION)
    for o in [o for o in coll.objects if o.name.startswith("Hand_") or o.name.startswith("BodyHand_")]:
        bpy.data.objects.remove(o, do_unlink=True)
    HANDS = {s: make_hand(s, coll) for s in SHAPES}
    # The four shapes in a row in front of the line-up, twice size, for the close-up.
    for i, (s, o) in enumerate(HANDS.items()):
        o.location = (2.2 + i * 1.6, -2.6, 1.6)
        o.scale = (2.0, 2.0, 2.0)
        o.rotation_euler = (0, 0, 0)
    print("[Hands]", {s: sum(len(p.vertices) - 2 for p in o.data.polygons) for s, o in HANDS.items()})
