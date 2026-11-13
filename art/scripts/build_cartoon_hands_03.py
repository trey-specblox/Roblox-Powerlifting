# Cartoon hands, third pass (GAME_DESIGN.md §38.7; user 2026-11-12: "make sure the quality is how i want it"). Hand-shape
# swaps (user's pick): Fist (on the body), Open, Point (also "shhh"), ThumbsUp (swapped in by celebrations).
#
# What changed from build_cartoon_hands_02.py, after comparing with the references (References/Body Study.md, the
# BodyClips bench frames: smooth rounded hands, a clean row of separate finger segments, the wrist narrower than the
# hand):
#   - every piece starts as its own smooth shell (palm, wrist ball, knuckle bumps, finger segments, thumb), then they
#     are fused on a fine voxel grid (0.0045, was 0.011) and smoothed before thinning: the coarse fuse came out lumpy
#     with the knuckles blurred together; unfused shells left jagged seams where they cross. Knuckle bumps on the back
#     of the hand, finger rolls on the front, like the references' fists.
#   - no big wrist blob (it stuck out past the forearm: the "wrist ridge"). A small wrist ball sits centred ON the wrist
#     joint, so it turns in place inside the forearm's end when the wrist bends (build_cartoon_rig_02.py cuts the
#     forearm's bulging end off and caps it).
#   - about 1,250 triangles per hand (performance: the fused hands were 900 but lumpy).
#
# Hand space: the hand bone's joint (the wrist) at (0, 0, -0.06), the hand hanging down (-Z), the palm facing -Y, the
# thumb on +X (a right hand seen from the front; the left hand is the mirror). Units are the hand's own: each build
# scales it (build_cartoon_rig_02.py BUILDS hand size: Skinny 0.95, Heavy 1.15, Muscular 1.28; 10% up 2026-11-12, the references' big hands).
# Run as a library from build_cartoon_rig_02.py, or alone inside Blender for a close-up line-up:
#   exec(open(r"D:\Powerlifting Roblox\art\scripts\build_cartoon_hands_03.py").read())
import math

import bmesh
import bpy
from mathutils import Vector

COLLECTION = "CartoonHands"
SKIN = (0.95, 0.76, 0.60, 1)
WRIST = Vector((0, 0, -0.06))          # the hand bone's joint, in hand space
VOXEL = 0.0045                         # the fuse (0.011 in the second pass blurred the knuckles)
TRIANGLES = 1400                       # per hand

# Finger roots along the bottom of the palm (x), radius, and how much higher the root sits (the pinky's is higher).
FINGERS = {"Index": (0.132, 0.066, 0.0), "Middle": (0.044, 0.068, 0.0), "Ring": (-0.044, 0.064, 0.006),
           "Pinky": (-0.128, 0.056, 0.02)}
KNUCKLE_Z = -0.385                     # the knuckle row (the bottom edge of the palm)


def ellipsoid(bm, centre, radii, u=12, v=8, boxy=1.0):
    """A closed ellipsoid shell; boxy < 1 squares it off into a rounded block (the palm)."""
    geom = bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    for vert in geom["verts"]:
        x, y, z = (math.copysign(abs(c) ** boxy, c) for c in vert.co)
        vert.co = Vector((x * radii[0], y * radii[1], z * radii[2])) + centre


def capsule(bm, a, b, r, u=10, v=6):
    """A rounded segment from a to b, radius r (an ellipsoid stretched along the segment, ends rounded)."""
    d = b - a
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix()
    half = d.length / 2 + r * 0.8
    geom = bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    mid = (a + b) / 2
    for vert in geom["verts"]:
        vert.co = rot @ Vector((vert.co.x * r, vert.co.y * r, vert.co.z * half)) + mid


def curled_finger(bm, x, r, lift):
    """A finger in a fist: the knuckle segment pointing forward (-Y) under the palm, then the middle segment turned
    back up the front of the fist. The fingertip is tucked against the palm (hidden), so it isn't modelled."""
    root = Vector((x, -0.005, KNUCKLE_Z + lift))
    bend = Vector((x, -0.155, KNUCKLE_Z + lift + 0.005))
    capsule(bm, root, bend, r)
    capsule(bm, bend + Vector((0, -0.005, 0.0)), Vector((x, -0.165, KNUCKLE_Z + lift + 0.15)), r * 0.93)


def straight_finger(bm, x, r, lift, spread=0.0, curl=0.02):
    """A straight finger hanging from the knuckle (a little spread sideways and curled toward the palm)."""
    root = Vector((x, -0.005, KNUCKLE_Z + lift))
    length = {0.132: 0.245, 0.044: 0.26, -0.044: 0.245, -0.128: 0.2}.get(x, 0.24)
    mid = root + Vector((spread * 0.5, -curl * 0.5, -length * 0.5))
    tip = root + Vector((spread, -curl * 1.6, -length))
    capsule(bm, root, mid, r)
    capsule(bm, mid, tip, r * 0.9)


def thumb(bm, kind):
    root = Vector((0.15, -0.045, -0.15))
    if kind == "open":          # out to the side and a little down
        pts = [root + Vector((0.08, -0.04, -0.08)), root + Vector((0.15, -0.07, -0.17))]
    elif kind == "up":          # straight out past the knuckles, along the hand (up when the forearm is up)
        pts = [root + Vector((0.05, -0.05, -0.17)), root + Vector((0.055, -0.06, -0.34))]
    else:                       # across the front of the curled fingers
        pts = [root + Vector((0.0, -0.13, -0.09)), Vector((0.0, -0.245, -0.285))]
    capsule(bm, root + Vector((-0.04, 0.02, 0.03)), root, 0.074, u=10, v=6)   # the thumb's root muscle
    capsule(bm, root, pts[0], 0.064, u=10, v=6)
    capsule(bm, pts[0], pts[1], 0.058, u=10, v=6)


SHAPES = {
    "Fist": {"curled": ("Index", "Middle", "Ring", "Pinky"), "thumb": "across"},
    "Open": {"curled": (), "thumb": "open"},
    "Point": {"curled": ("Middle", "Ring", "Pinky"), "thumb": "across"},
    "ThumbsUp": {"curled": ("Index", "Middle", "Ring", "Pinky"), "thumb": "up"},
}
SPREAD = {"Index": 0.015, "Middle": 0.004, "Ring": -0.006, "Pinky": -0.018}


def fuse(obj):
    """The shells into one smooth surface with soft creases: a fine voxel remesh (a coarse one blurred the knuckles),
    smoothed, then fewer triangles, then a light smooth again (decimating alone left it lumpy)."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    steps = [("REMESH", {"mode": "VOXEL", "voxel_size": VOXEL}),
             ("CORRECTIVE_SMOOTH", {"iterations": 8, "use_only_smooth": True, "smooth_type": "LENGTH_WEIGHTED"})]
    for kind, settings in steps:
        mod = obj.modifiers.new(kind, kind)
        for key, value in settings.items():
            setattr(mod, key, value)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    mod = obj.modifiers.new("Fewer", "DECIMATE")
    mod.ratio = min(1.0, TRIANGLES / max(1, triangles(obj)))
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod = obj.modifiers.new("Soften", "SMOOTH")
    mod.factor, mod.iterations = 0.4, 2
    bpy.ops.object.modifier_apply(modifier=mod.name)


def make_hand(shape, coll, name=None):
    spec = SHAPES[shape]
    bm = bmesh.new()
    ellipsoid(bm, Vector((0, 0, -0.225)), (0.198, 0.128, 0.165), u=14, v=8, boxy=0.5)    # the palm: a rounded block
    ellipsoid(bm, WRIST, (0.112, 0.085, 0.10), u=10, v=6)                                # the wrist ball, on the joint
    for finger, (x, r, lift) in FINGERS.items():
        # The knuckle: a bump on the back edge of the palm, clear on a fist (the references' fists).
        ellipsoid(bm, Vector((x, 0.045, KNUCKLE_Z + lift + 0.015)), (r * 0.9, r * 1.05, r * 0.95), u=10, v=6)
        if finger in spec["curled"]:
            curled_finger(bm, x, r, lift)
        else:
            # A pointing index is straight down the hand, no spread; open hands spread a little.
            straight_finger(bm, x, r, lift, spread=0.0 if shape == "Point" else SPREAD[finger],
                            curl=0.0 if shape == "Point" else 0.025)
    thumb(bm, spec["thumb"])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("Hand_" + shape)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name or ("Hand_" + shape), me)
    coll.objects.link(obj)
    fuse(obj)
    for p in me.polygons:
        p.use_smooth = True
    m = bpy.data.materials.get("CartoonSkin") or bpy.data.materials.new("CartoonSkin")
    m.diffuse_color = SKIN
    me.materials.append(m)
    return obj


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


if globals().get("CARTOON_AS_LIBRARY") is not True:
    coll = bpy.data.collections.get(COLLECTION) or bpy.data.collections.new(COLLECTION)
    if coll.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(coll)
    for o in list(coll.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    HANDS = {s: make_hand(s, coll) for s in SHAPES}
    for i, (s, o) in enumerate(HANDS.items()):
        o.location = (12.0 + i * 1.0, -2.0, 2.0)
        o.scale = (2.0, 2.0, 2.0)
    print("[Hands03]", {s: triangles(o) for s, o in HANDS.items()})
