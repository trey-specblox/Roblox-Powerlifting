# Cartoon hands, fourth pass (CHARACTER_ART_DIRECTION.md §11 Phase 2: "lighter hands, about 600 triangles each instead
# of 1,400, open hand plus the Fist, Point and ThumbsUp swaps"). build_cartoon_hands_03.py stays unchanged.
#
# What changed from hands_03:
#   - built like the bodies: ONE smooth distance field per hand (palm, knuckles, fingers, thumb), meshed with OpenVDB,
#     instead of separate shells fused by a voxel remesh. Fingers meet each other with a hard crease (a clean row of
#     separate fingers, the references' look); fingers and thumb melt softly into the palm.
#   - chunkier and simpler (§4: "chunky, at least as wide as the wrist"): a wider, deeper palm, thicker and slightly
#     shorter fingers, a thicker thumb; small details that 600 triangles can't carry (finger joints, nails) left out.
#   - ~600 triangles per hand (was ~1,400): two hands are now ~1,200 of the ~5,500 body budget.
#
# Hand space (unchanged from hands_03, so the rig's hand_space matrix still fits): the hand bone's joint (the wrist) at
# (0, 0, -0.06), the hand hanging down (-Z), the palm facing -Y, the thumb on +X (a right hand seen from the front; the
# left hand is the mirror). Each build scales it (build_cartoon_body_05.py: hand 1.05 ... 1.58).
#
# Library use (build_cartoon_body_05.py, build_cartoon_rig_05.py): make_hand(shape, coll) -> object.
# Alone (a close-up line-up of the four shapes, saved nowhere):
#   blender -b --python art/scripts/build_cartoon_hands_04.py
import math
import os
import tempfile

import bmesh
import bpy
import numpy as np

SCRIPTS = os.path.join(r"D:\Powerlifting Roblox", "art", "scripts")
_P4 = {"__name__": "body04_lib", "PROTO04_AS_LIBRARY": True}
exec(open(os.path.join(SCRIPTS, "build_cartoon_body_04.py")).read(), _P4)
ellipsoid, round_cone, round_box, smin = (_P4[k] for k in ("ellipsoid", "round_cone", "round_box", "smin"))

SKIN = (0.95, 0.76, 0.60, 1)
WRIST = (0.0, 0.0, -0.06)
VOXEL = 0.0055
TRIANGLES = 600
KNUCKLE_Z = -0.385
# finger roots along the knuckle row: x, radius, root lift (the pinky's root sits higher), length (straight)
FINGERS = {"Index": (0.128, 0.072, 0.0, 0.225), "Middle": (0.043, 0.075, 0.0, 0.24),
           "Ring": (-0.043, 0.071, 0.006, 0.225), "Pinky": (-0.124, 0.062, 0.022, 0.185)}
SPREAD = {"Index": 0.016, "Middle": 0.004, "Ring": -0.007, "Pinky": -0.02}
SHAPES = {
    "Fist": {"curled": ("Index", "Middle", "Ring", "Pinky"), "thumb": "across"},
    "Open": {"curled": (), "thumb": "open"},
    "Point": {"curled": ("Middle", "Ring", "Pinky"), "thumb": "across"},
    "ThumbsUp": {"curled": ("Index", "Middle", "Ring", "Pinky"), "thumb": "up"},
    "Grip": {"curled": (), "thumb": "grip"},          # wrapped round the bar: grip_finger / grip_thumb below
}
# GRIP (asked 2026-11-13 for the deadlift, later every lift: "make sure the fingers are actually wrapped around
# grabbing it"): a bar hole along hand-space X at GRIP_C, the palm's front face (y -0.135) plus the hole's radius, at the
# base of the fingers. 0.062 hand units = 0.075 studs at Fit's 1.22 (the bar is 0.07; one mesh scaled per build).
# The four fingers go from the knuckles down under the bar, up its far side and curl back over the top towards the
# palm; the thumb closes the other way over the top and down across the index and middle fingers (a closed grip).
# The game's grip point (where the bar's centre goes) is GRIP_C in hand space.
GRIP_C = (0.0, -0.197, -0.40)
GRIP_R = 0.062
GRIP_WRAP = {"Index": -270, "Middle": -270, "Ring": -265, "Pinky": -245}     # how far round each finger gets (deg)


def v3(x, y, z):
    return np.array((x, y, z), dtype=np.float32)


def finger_field(P, name, shape):
    x, r, lift, length = FINGERS[name]
    root = v3(x, -0.005, KNUCKLE_Z + lift + 0.02)
    if name in SHAPES[shape]["curled"]:
        # knuckle segment forward under the palm, then the middle segment turned back up the front of the fist
        bend = v3(x, -0.165, KNUCKLE_Z + lift + 0.0)
        tip = v3(x, -0.175, KNUCKLE_Z + lift + 0.15)
        return np.minimum(round_cone(P, root, bend, r, r * 0.97), round_cone(P, bend, tip, r * 0.97, r * 0.9))
    straight = shape == "Point"
    spread = 0.0 if straight else SPREAD[name]
    curl = 0.0 if straight else 0.028
    mid = root + v3(spread * 0.5, -curl * 0.5, -length * 0.5)
    tip = root + v3(spread, -curl * 1.6, -length)
    return np.minimum(round_cone(P, root, mid, r, r * 0.95), round_cone(P, mid, tip, r * 0.95, r * 0.88))


def thumb_field(P, kind):
    root = v3(0.15, -0.045, -0.15)
    if kind == "open":
        pts = [root + v3(0.08, -0.04, -0.08), root + v3(0.15, -0.07, -0.17)]
    elif kind == "up":
        pts = [root + v3(0.05, -0.05, -0.17), root + v3(0.055, -0.06, -0.33)]
    else:
        pts = [root + v3(0.0, -0.13, -0.09), v3(0.0, -0.25, -0.28)]
    base = round_cone(P, root + v3(-0.05, 0.02, 0.04), root, 0.085, 0.078)          # the thumb's root muscle
    seg = np.minimum(round_cone(P, root, pts[0], 0.076, 0.07), round_cone(P, pts[0], pts[1], 0.07, 0.064))
    return smin(base, seg, 0.03)


def around_bar(a, radius, x):
    """A point at angle a (degrees) round the bar in the YZ plane: 0 = the palm side, -90 = under, 180 = far side."""
    t = math.radians(a)
    return v3(x, GRIP_C[1] + radius * math.cos(t), GRIP_C[2] + radius * math.sin(t))


def grip_finger(P, name):
    x, r, lift, _length = FINGERS[name]
    root = v3(x, -0.005, KNUCKLE_Z + lift + 0.02)
    ring = GRIP_R + r * 0.96 + 0.004                     # the finger's centre line round the bar
    angles = list(range(-45, GRIP_WRAP[name] - 1, -45))
    if angles[-1] != GRIP_WRAP[name]:
        angles.append(GRIP_WRAP[name])
    pts = [root] + [around_bar(a, ring, x) for a in angles]
    radii = np.linspace(r, r * 0.86, len(pts))
    d = None
    for i in range(len(pts) - 1):
        seg = round_cone(P, pts[i], pts[i + 1], radii[i] * 0.96, radii[i + 1] * 0.96)
        d = seg if d is None else np.minimum(d, seg)
    return d


def grip_thumb(P):
    root = v3(0.15, -0.06, -0.19)
    pts = [root, around_bar(120, 0.20, 0.135), around_bar(165, 0.232, 0.075), around_bar(195, 0.228, 0.035)]
    base = round_cone(P, root + v3(-0.05, 0.02, 0.04), root, 0.085, 0.078)
    seg = np.minimum(np.minimum(round_cone(P, pts[0], pts[1], 0.076, 0.071), round_cone(P, pts[1], pts[2], 0.071, 0.067)),
                     round_cone(P, pts[2], pts[3], 0.067, 0.062))
    return smin(base, seg, 0.03)


def grip_field(P):
    palm = round_box(P, v3(0, 0.0, -0.23), v3(0.205, 0.135, 0.175), 0.11)
    wrist = ellipsoid(P, v3(*WRIST), v3(0.115, 0.088, 0.10))
    d = smin(palm, wrist, 0.06)
    fingers = None
    for name in FINGERS:
        x, r, lift, _l = FINGERS[name]
        knuckle = ellipsoid(P, v3(x, 0.045, KNUCKLE_Z + lift + 0.02), v3(r * 0.92, r * 1.0, r * 0.92))
        d = smin(d, knuckle, 0.035)
        f = grip_finger(P, name)
        fingers = f if fingers is None else np.minimum(fingers, f)       # hard creases between fingers
    d = smin(d, fingers, 0.03)
    d = smin(d, grip_thumb(P), 0.03)
    # the bar's hole kept clean through the whole hand (nothing melts into it)
    hole = np.sqrt((P[:, 1] - GRIP_C[1]) ** 2 + (P[:, 2] - GRIP_C[2]) ** 2) - (GRIP_R + 0.002)
    return np.maximum(d, -hole)


def hand_field(P, shape):
    if shape == "Grip":
        return grip_field(P)
    palm = round_box(P, v3(0, 0.0, -0.23), v3(0.205, 0.135, 0.175), 0.11)            # a chunky rounded block
    wrist = ellipsoid(P, v3(*WRIST), v3(0.115, 0.088, 0.10))                         # turns in place in the forearm
    d = smin(palm, wrist, 0.06)
    fingers = None
    for name in FINGERS:
        x, r, lift, _l = FINGERS[name]
        knuckle = ellipsoid(P, v3(x, 0.045, KNUCKLE_Z + lift + 0.02), v3(r * 0.92, r * 1.0, r * 0.92))
        d = smin(d, knuckle, 0.035)
        f = finger_field(P, name, shape)
        fingers = f if fingers is None else np.minimum(fingers, f)      # hard creases between fingers
    d = smin(d, fingers, 0.035)
    return smin(d, thumb_field(P, SHAPES[shape]["thumb"]), 0.035)


def mesh_field(name, fn, lo, hi):
    import openvdb as vdb
    lo, hi = np.asarray(lo), np.asarray(hi)
    i0 = np.floor(lo / VOXEL).astype(int)
    n = (np.ceil(hi / VOXEL).astype(int) - i0) + 1
    xs, ys, zs = [(i0[a] + np.arange(n[a])) * VOXEL for a in range(3)]
    X, Y, Z = np.meshgrid(xs, ys, zs, indexing="ij")
    P = np.stack([X.ravel(), Y.ravel(), Z.ravel()], axis=1).astype(np.float32)
    density = np.clip(-fn(P), -0.05, 0.05).reshape(X.shape).astype(np.float32)
    grid = vdb.FloatGrid(-0.05)
    grid.copyFromArray(density, ijk=tuple(int(v) for v in i0), tolerance=0.0)
    grid.transform = vdb.createLinearTransform(voxelSize=VOXEL)
    grid.name = "density"
    path = os.path.join(tempfile.gettempdir(), "hands04_%s.vdb" % name)
    vdb.write(path, grids=[grid])
    vol = bpy.data.volumes.new(name + "_Field")
    vol.filepath = path
    vol_obj = bpy.data.objects.new(name + "_Field", vol)
    bpy.context.scene.collection.objects.link(vol_obj)
    holder = bpy.data.objects.new(name + "_Holder", bpy.data.meshes.new(name + "_Holder"))
    bpy.context.scene.collection.objects.link(holder)
    m = holder.modifiers.new("Field", "VOLUME_TO_MESH")
    m.object, m.grid_name, m.threshold, m.resolution_mode, m.adaptivity = vol_obj, "density", 0.0, "GRID", 0.0
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(holder.evaluated_get(dg))
    bpy.data.objects.remove(holder, do_unlink=True)
    bpy.data.objects.remove(vol_obj, do_unlink=True)
    bpy.data.volumes.remove(vol)
    try:
        os.remove(path)
    except OSError:
        pass
    me.name = name
    return me


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def _apply(obj, kind, **props):
    mod = obj.modifiers.new(kind, kind)
    for k, v in props.items():
        setattr(mod, k, v)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def unfold(obj, passes=6):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    found = 0
    for _ in range(passes):
        bm.normal_update()
        folded = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle() > 2.0]
        if not folded:
            break
        found += len(folded)
        around = set()
        for e in folded:
            for v in e.verts:
                around.add(v)
                around.update(o for le in v.link_edges for o in le.verts)
        bmesh.ops.smooth_vert(bm, verts=list(around), factor=0.6, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.to_mesh(obj.data)
    bm.free()
    return found


def make_hand(shape, coll, name=None):
    name = name or ("Hand04_" + shape)
    lo = (-0.36, -0.58, -0.70) if shape == "Grip" else (-0.36, -0.40, -0.70)
    me = mesh_field(name, lambda P: hand_field(P, shape), lo, (0.38, 0.24, 0.10))
    obj = bpy.data.objects.new(name, me)
    coll.objects.link(obj)
    _apply(obj, "SMOOTH", factor=0.5, iterations=2)
    _apply(obj, "DECIMATE", ratio=min(1.0, TRIANGLES / max(1, triangles(obj))), use_symmetry=False)
    _apply(obj, "SMOOTH", factor=0.35, iterations=1)
    obj["folds_smoothed"] = unfold(obj)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    m = bpy.data.materials.get("CartoonSkin") or bpy.data.materials.new("CartoonSkin")
    m.diffuse_color = SKIN
    me.materials.clear()
    me.materials.append(m)
    return obj


if globals().get("CARTOON_AS_LIBRARY") is not True:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    coll = bpy.data.collections.new("CartoonHands04")
    bpy.context.scene.collection.children.link(coll)
    HANDS = {s: make_hand(s, coll) for s in SHAPES}
    print("[Hands04]", {s: (triangles(o), o["folds_smoothed"]) for s, o in HANDS.items()})
