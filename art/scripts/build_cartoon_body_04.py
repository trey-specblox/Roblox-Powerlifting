# Cartoon lifter bodies, PROTOTYPE 04 (comparison only; CHARACTER_ART_DIRECTION.md §7, user "Yes, build prototype",
# 2026-11-13). NOT game bodies: no rig export, no upload. CartoonBodies_02.blend and its scripts stay untouched.
#
# What is different from build_cartoon_body_02.py (the "blobs" diagnosis, CHARACTER_ART_DIRECTION.md §3):
#   - each body is ONE smooth distance field: forms melt into each other with a chosen softness (smooth union), so a
#     pec flows into the delt and the delt wraps the arm, instead of ellipsoids stuck onto ellipsoids
#   - definition is CARVED into that surface (shallow grooves: sternum, pec edge, ab lines, spine, glute fold), only
#     on the muscular build; never added as balls
#   - every position is written against the skeleton's joint heights (LANDMARKS), so the "height in the torso only"
#     variant comes from the same shapes
#   - arms and legs join the torso softly only at the shoulder and the hip; lower down they stay separate surfaces
#     (an arm hanging next to the belly never webs onto it)
# Meshed with OpenVDB (Blender's Volume to Mesh), lightly smoothed, thinned to a triangle budget.
#
# Run headless:  blender -b --python art/scripts/build_cartoon_body_04.py
# Writes art/blender/CartoonBodies_04_Proto.blend (bodies + the open hands; stand-in heads in a "Preview" collection).
import math
import os
import sys
import tempfile

import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
OUT_BLEND = os.path.join(ROOT, "art", "blender", "CartoonBodies_04_Proto.blend")
VOXEL = 0.02            # studs: sampling of the distance field
BODY_TRIANGLES = 4800   # per body, before the hands (budget proposal, CHARACTER_ART_DIRECTION.md §6.4)
SPACING = 4.6
SKIN = (0.95, 0.76, 0.60, 1)

# ----------------------------------------------------------------------------------------------- skeleton heights
# The taller rig in use now (lifter_heights.py): legs x1.2286, torso and arms x1.15. Block-rig heights in comments.
TALLER = dict(A=0.252, K=1.390, HJ=2.4, W=2.86, N=4.70, SH=4.4275, E=3.60, WR=2.716)
# The comparison variant: the block rig's legs, the extra height in the torso and arms only (same 4.70 neck).
# APPROVED 2026-11-13 ("Height in the torso"). Arms shortened the same day (user: "Yes fix the arms, legs are good"):
# the arms were x1.35 like the torso (elbow 3.40, wrist 2.37: hands to mid-thigh, gorilla-like on the big-handed
# builds); now x1.2 of the block arm (upper 0.728 -> 0.874, lower 0.76 -> 0.912).
TORSO_TALL = dict(A=0.252, K=1.178, HJ=2.0, W=2.54, N=4.70, SH=4.38, E=3.51, WR=2.59)


def lerp(a, b, t):
    return a + (b - a) * t


# ----------------------------------------------------------------------------------------------- distance fields
# All functions take P: (n, 3) float32 points and return (n,) signed distances (negative inside).
def _local(P, c, rot):
    q = P - np.asarray(c, dtype=np.float32)
    if rot is not None and any(rot):
        m = np.array(Euler([math.radians(a) for a in rot]).to_matrix(), dtype=np.float32)
        q = q @ m
    return q


def ellipsoid(P, c, r, rot=None):
    q = _local(P, c, rot)
    r = np.asarray(r, dtype=np.float32)
    k0 = np.linalg.norm(q / r, axis=1)
    k1 = np.linalg.norm(q / (r * r), axis=1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)


def round_cone(P, a, b, ra, rb):
    """A limb segment: a capsule from a (radius ra) to b (radius rb) (Inigo Quilez's round cone)."""
    a = np.asarray(a, dtype=np.float32)
    b = np.asarray(b, dtype=np.float32)
    ba = b - a
    l2 = float(ba @ ba)
    rr = ra - rb
    a2 = l2 - rr * rr
    il2 = 1.0 / l2
    pa = P - a
    y = pa @ ba
    z = y - l2
    xv = pa * l2 - np.outer(y, ba)
    x2 = np.einsum("ij,ij->i", xv, xv)
    y2 = y * y * l2
    z2 = z * z * l2
    k = math.copysign(1.0, rr) * rr * rr * x2
    d_mid = (np.sqrt(np.maximum(x2 * a2 * il2, 0)) + y * rr) * il2 - ra
    d_b = np.sqrt(x2 + z2) * il2 - rb
    d_a = np.sqrt(x2 + y2) * il2 - ra
    return np.where(np.sign(z) * a2 * z2 > k, d_b, np.where(np.sign(y) * a2 * y2 < k, d_a, d_mid))


def round_box(P, c, h, rad, rot=None):
    q = np.abs(_local(P, c, rot)) - (np.asarray(h, dtype=np.float32) - rad)
    return np.linalg.norm(np.maximum(q, 0), axis=1) + np.minimum(q.max(axis=1), 0) - rad


def smin(a, b, k):
    k = np.maximum(k, 1e-4)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b + (a - b) * h - k * h * (1.0 - h)


def carve(a, b, k):
    """Carves shape b out of a with a soft edge (a groove)."""
    return -smin(-a, b, k)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# A shape: (kind, args, blend, op). op "add" melts it in with softness `blend`; "carve" cuts a groove.
def E(c, r, blend=0.12, rot=None, op="add", mirror=True):
    return ("ellipsoid", (c, r, rot), blend, op, mirror)


def C(a, b, ra, rb, blend=0.12, op="add", mirror=True):
    return ("cone", (a, b, ra, rb), blend, op, mirror)


def BX(c, h, rad, blend=0.12, rot=None, op="add", mirror=True):
    return ("box", (c, h, rad, rot), blend, op, mirror)


def _mirror_args(kind, args):
    flip = lambda v: (-v[0], v[1], v[2])
    if kind == "ellipsoid":
        c, r, rot = args
        return (flip(c), r, None if rot is None else (rot[0], -rot[1], -rot[2]))
    if kind == "cone":
        a, b, ra, rb = args
        return (flip(a), flip(b), ra, rb)
    c, h, rad, rot = args
    return (flip(c), h, rad, None if rot is None else (rot[0], -rot[1], -rot[2]))


def _eval(kind, args, P):
    if kind == "ellipsoid":
        return ellipsoid(P, *args)
    if kind == "cone":
        return round_cone(P, *args)
    return round_box(P, *args)


def family(P, shapes, side=None):
    """Folds a list of shapes into one field (the first must be an "add"). side None: each mirrored shape and its twin
    melt together (the torso); side 1 / -1: only the left / right copy (one limb)."""
    d = None
    for kind, args, blend, op, mirror in shapes:
        if side is None:
            variants = [args] + ([_mirror_args(kind, args)] if mirror else [])
        else:
            variants = [args if side > 0 else _mirror_args(kind, args)]
        for v in variants:
            s = _eval(kind, v, P)
            if d is None:
                d = s
            elif op == "add":
                d = smin(d, s, blend)
            else:
                d = carve(d, s, blend)
    return d


# ----------------------------------------------------------------------------------------------- the three builds
# Coordinates: studs, x = the character's left, -y = front, z = up. The arms hang along x = arm_x; the head (the
# player's own, 1.2 studs) sits on the neck at N. Each build returns its torso, one arm and one leg (mirrored).

def common_feet(L, wide=1.0):
    return [BX((0.5, -0.12, 0.15), (0.21 * wide, 0.39, 0.13), 0.10, blend=0.07),          # a rounded shoe shape
            E((0.5, -0.30, 0.17), (0.19 * wide, 0.20, 0.13), blend=0.06)]                   # toe box


def skinny(L):
    A, K, HJ, W, N, SH, E_, WR = (L[k] for k in ("A", "K", "HJ", "W", "N", "SH", "E", "WR"))
    CZ = lerp(W, N, 0.62)
    arm_x = 1.02
    torso = [
        E((0, 0.02, CZ), (0.70, 0.42, 0.78), mirror=False),                                  # rib cage
        E((0, 0.0, W + 0.22), (0.58, 0.36, 0.55), blend=0.30, mirror=False),                # stomach, flat
        E((0, 0.02, HJ + 0.12), (0.55, 0.36, 0.34), blend=0.25, mirror=False),              # pelvis (straight male sides)
        E((0, 0.04, N + 0.02), (0.40, 0.34, 0.20), blend=0.20, mirror=False),               # under the head (no ledge)
        C((0.30, 0.06, N + 0.08), (0.86, 0.02, SH + 0.02), 0.17, 0.15, blend=0.16),         # trap slope, small
        E((0.86, 0.0, SH - 0.06), (0.22, 0.24, 0.24), blend=0.14),                          # small delt cap
        E((0.30, -0.22, CZ + 0.06), (0.42, 0.10, 0.24), blend=0.26, rot=(0, -10, 0)),      # flat chest plate
        E((0.28, 0.21, HJ - 0.02), (0.27, 0.22, 0.28), blend=0.20),                         # glutes, one soft mass
    ]
    arm = [C((arm_x, 0, SH - 0.02), (arm_x, 0, E_ + 0.05), 0.205, 0.165),
           C((arm_x, 0, E_ - 0.05), (arm_x, 0, WR + 0.05), 0.175, 0.135, blend=0.08),
           E((arm_x + 0.01, -0.03, E_ - 0.22), (0.18, 0.18, 0.26), blend=0.10)]
    leg = [C((0.5, 0.0, HJ + 0.05), (0.5, 0.0, K + 0.08), 0.32, 0.21),
           C((0.5, 0.0, K - 0.02), (0.5, 0.0, A + 0.10), 0.20, 0.13, blend=0.08),
           E((0.5, 0.08, K - 0.34), (0.19, 0.17, 0.30), blend=0.10)] + common_feet(L)
    return dict(torso=torso, arm=arm, leg=leg, arm_x=arm_x, pivot_x=0.80, hand=1.05, k_shoulder=0.16, k_hip=0.16)


def heavy(L):
    A, K, HJ, W, N, SH, E_, WR = (L[k] for k in ("A", "K", "HJ", "W", "N", "SH", "E", "WR"))
    CZ = lerp(W, N, 0.62)
    arm_x = 1.42
    torso = [
        E((0, 0.04, CZ), (0.94, 0.60, 0.82), mirror=False),                                  # round upper body
        E((0, -0.22, W + 0.32), (0.98, 0.78, 0.72), blend=0.40, mirror=False),              # belly: low, forward
        E((0.70, 0.12, W + 0.20), (0.40, 0.42, 0.42), blend=0.30),                          # love handles
        E((0, 0.10, HJ + 0.10), (0.90, 0.52, 0.40), blend=0.40, mirror=False),              # wide pelvis
        E((0, 0.06, N + 0.06), (0.66, 0.52, 0.28), blend=0.28, mirror=False),               # round collar to the head
        C((0.40, 0.08, N + 0.06), (1.10, 0.05, SH - 0.02), 0.26, 0.25, blend=0.24),         # sloped round shoulders
        E((1.16, 0.0, SH - 0.14), (0.32, 0.34, 0.34), blend=0.22),                          # soft shoulder cap
        E((0.40, -0.38, CZ - 0.12), (0.40, 0.24, 0.30), blend=0.26),                        # soft low chest
        E((0.36, 0.32, HJ + 0.0), (0.44, 0.32, 0.36), blend=0.32),                          # glutes, one wide soft mass
    ]
    arm = [C((arm_x, 0, SH - 0.06), (arm_x, 0, E_ + 0.05), 0.31, 0.25, blend=0.10),
           C((arm_x, 0, E_ - 0.05), (arm_x, 0, WR + 0.05), 0.255, 0.18, blend=0.10),
           E((arm_x, 0.06, E_ + 0.40), (0.28, 0.28, 0.36), blend=0.14)]                       # soft upper arm hang
    leg = [C((0.53, 0.02, HJ + 0.02), (0.5, 0.0, K + 0.10), 0.47, 0.29),
           C((0.5, 0.02, K - 0.02), (0.5, 0.0, A + 0.10), 0.29, 0.185, blend=0.10),
           E((0.5, 0.08, K - 0.30), (0.25, 0.22, 0.32), blend=0.12)] + common_feet(L, 1.12)
    return dict(torso=torso, arm=arm, leg=leg, arm_x=arm_x, pivot_x=1.0, hand=1.30, k_shoulder=0.24, k_hip=0.22)


def muscular(L):
    A, K, HJ, W, N, SH, E_, WR = (L[k] for k in ("A", "K", "HJ", "W", "N", "SH", "E", "WR"))
    CZ = lerp(W, N, 0.60)
    arm_x = 1.52
    torso = [
        E((0, 0.03, CZ + 0.05), (0.84, 0.54, 0.80), mirror=False),                           # rib cage
        E((0, -0.02, W + 0.22), (0.58, 0.42, 0.56), blend=0.28, mirror=False),              # abdomen, narrow waist
        E((0, 0.04, HJ + 0.10), (0.68, 0.42, 0.36), blend=0.24, mirror=False),              # pelvis
        E((0.50, -0.06, W + 0.30), (0.17, 0.30, 0.34), blend=0.22),                         # obliques
        C((0.86, 0.14, CZ + 0.08), (0.55, 0.16, W + 0.28), 0.27, 0.15, blend=0.24),         # lats: armpit to waist
        E((0, 0.36, N - 0.42), (0.56, 0.24, 0.62), blend=0.22, mirror=False),               # trap diamond, upper back
        E((0, 0.06, N + 0.06), (0.50, 0.42, 0.28), blend=0.22, mirror=False),               # under the head
        C((0.28, 0.10, N + 0.30), (1.00, 0.06, SH + 0.04), 0.21, 0.27, blend=0.20),         # traps up the head's sides
        E((1.28, 0.0, SH - 0.08), (0.42, 0.45, 0.47), blend=0.18),                          # delt, wraps the arm top
        E((0.42, -0.32, CZ + 0.02), (0.54, 0.23, 0.32), blend=0.22, rot=(8, -14, 0)),      # pec slab
        C((0.12, -0.42, CZ + 0.30), (0.95, -0.24, SH - 0.12), 0.13, 0.17, blend=0.20),      # upper pec into the delt
        E((0.34, 0.26, HJ - 0.04), (0.36, 0.30, 0.36), blend=0.16),                         # glutes
        E((0.15, 0.36, W + 0.32), (0.12, 0.10, 0.50), blend=0.12),                          # erectors: the spine groove between
        # Carved definition (shallow, soft-edged grooves):
        C((0, -0.62, CZ + 0.30), (0, -0.58, CZ - 0.30), 0.035, 0.035, blend=0.05, op="carve", mirror=False),  # sternum
        C((0.10, -0.60, CZ - 0.31), (0.62, -0.50, CZ - 0.20), 0.040, 0.026, blend=0.06, op="carve"),        # pec edge
        C((0, -0.47, W + 0.68), (0, -0.45, W - 0.06), 0.030, 0.026, blend=0.04, op="carve", mirror=False),   # linea alba
        C((-0.30, -0.42, W + 0.56), (0.30, -0.42, W + 0.56), 0.024, 0.024, blend=0.04, op="carve", mirror=False),
        C((-0.29, -0.43, W + 0.32), (0.29, -0.43, W + 0.32), 0.024, 0.024, blend=0.04, op="carve", mirror=False),
        C((-0.27, -0.43, W + 0.08), (0.27, -0.43, W + 0.08), 0.022, 0.022, blend=0.04, op="carve", mirror=False),
        C((0.10, 0.50, HJ - 0.40), (0.62, 0.40, HJ - 0.34), 0.035, 0.035, blend=0.06, op="carve"),          # glute fold
        C((0.92, -0.42, SH - 0.20), (1.05, -0.38, CZ - 0.25), 0.030, 0.030, blend=0.05, op="carve"),        # delt/pec line
    ]
    arm = [C((arm_x, 0, SH - 0.10), (arm_x, 0, E_ + 0.08), 0.33, 0.26, blend=0.10),
           E((arm_x - 0.02, -0.15, E_ + 0.38), (0.26, 0.24, 0.34), blend=0.10),               # biceps
           E((arm_x + 0.02, 0.14, E_ + 0.46), (0.27, 0.24, 0.42), blend=0.10),               # triceps
           C((arm_x, 0, E_ - 0.10), (arm_x, 0, WR + 0.07), 0.29, 0.185, blend=0.08),          # forearm, thick at the top
           E((arm_x + 0.04, -0.06, E_ - 0.24), (0.24, 0.23, 0.30), blend=0.10)]
    leg = [C((0.52, -0.02, HJ + 0.05), (0.5, 0.0, K + 0.12), 0.45, 0.29),
           E((0.76, -0.06, lerp(K, HJ, 0.55)), (0.22, 0.30, 0.52), blend=0.16),             # outer quad sweep
           E((0.56, 0.22, lerp(K, HJ, 0.55)), (0.27, 0.24, 0.50), blend=0.18),              # hamstrings
           C((0.5, 0.02, K - 0.04), (0.5, 0.0, A + 0.10), 0.255, 0.16, blend=0.08),
           E((0.5, 0.14, K - 0.36), (0.27, 0.23, 0.36), blend=0.12)]                        # calf diamond
    leg += common_feet(L, 1.06)
    return dict(torso=torso, arm=arm, leg=leg, arm_x=arm_x, pivot_x=1.0, hand=1.50, k_shoulder=0.20, k_hip=0.18)


BUILDS = {"Skinny": skinny, "Heavy": heavy, "Muscular": muscular}


# ----------------------------------------------------------------------------------------------- field -> mesh
def body_field(spec, L, P):
    torso = family(P, spec["torso"])
    # Left and right limbs are separate surfaces (thighs that touch must not web together).
    arm = np.minimum(family(P, spec["arm"], 1), family(P, spec["arm"], -1))
    leg = np.minimum(family(P, spec["leg"], 1), family(P, spec["leg"], -1))
    z, ax = P[:, 2], np.abs(P[:, 0])
    # Arms melt into the torso only at the shoulder; legs only round the hips and glutes.
    k_sh = spec["k_shoulder"] * smoothstep(L["SH"] - 0.80, L["SH"] - 0.25, z) * smoothstep(0.5, 0.8, ax)
    d = smin(torso, arm, k_sh)
    k_hip = spec["k_hip"] * smoothstep(L["HJ"] - 0.60, L["HJ"] - 0.10, z)
    return smin(d, leg, k_hip)


def field_to_mesh(name, spec, L):
    import openvdb as vdb
    lo = np.array([-2.4, -1.4, -0.10])
    hi = np.array([2.4, 1.3, L["N"] + 0.75])
    i0 = np.floor(lo / VOXEL).astype(int)
    n = (np.ceil(hi / VOXEL).astype(int) - i0) + 1
    xs, ys, zs = [(i0[a] + np.arange(n[a])) * VOXEL for a in range(3)]
    density = np.empty(tuple(n), dtype=np.float32)
    for k in range(0, n[2], 40):                                 # slab by slab (memory)
        kk = slice(k, min(k + 40, n[2]))
        X, Y, Zs = np.meshgrid(xs, ys, zs[kk], indexing="ij")
        P = np.stack([X.ravel(), Y.ravel(), Zs.ravel()], axis=1).astype(np.float32)
        density[:, :, kk] = np.clip(-body_field(spec, L, P), -0.1, 0.1).reshape(X.shape)
    grid = vdb.FloatGrid(-0.1)
    grid.copyFromArray(density, ijk=tuple(int(v) for v in i0), tolerance=0.0)
    grid.transform = vdb.createLinearTransform(voxelSize=VOXEL)
    grid.name = "density"
    path = os.path.join(tempfile.gettempdir(), "proto04_%s.vdb" % name)
    vdb.write(path, grids=[grid])
    vol = bpy.data.volumes.new(name + "_Field")
    vol.filepath = path
    vol_obj = bpy.data.objects.new(name + "_Field", vol)
    bpy.context.scene.collection.objects.link(vol_obj)
    holder = bpy.data.objects.new(name, bpy.data.meshes.new(name))
    bpy.context.scene.collection.objects.link(holder)
    m = holder.modifiers.new("Field", "VOLUME_TO_MESH")
    m.object = vol_obj
    m.grid_name = "density"
    m.threshold = 0.0
    m.resolution_mode = "GRID"
    m.adaptivity = 0.0
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(holder.evaluated_get(dg))
    bpy.data.objects.remove(holder, do_unlink=True)
    bpy.data.objects.remove(vol_obj, do_unlink=True)
    bpy.data.volumes.remove(vol)
    obj = bpy.data.objects.new(name, me)
    return obj


def unfold(obj, passes=6):
    """Removes zero-area faces, then smooths round any edge folded sharper than ~115 degrees until none are left."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-5)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
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
        bmesh.ops.smooth_vert(bm, verts=list(around), factor=0.7, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.to_mesh(obj.data)
    bm.free()
    return found


def finish(obj, coll):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    coll.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    sm = obj.modifiers.new("Soften", "SMOOTH")
    sm.factor = 0.5
    sm.iterations = 2
    bpy.ops.object.modifier_apply(modifier=sm.name)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris > BODY_TRIANGLES:
        dec = obj.modifiers.new("Fewer", "DECIMATE")
        dec.ratio = BODY_TRIANGLES / tris
        dec.use_symmetry = False          # (symmetric thinning folded faces along the centre line: black spots)
        bpy.ops.object.modifier_apply(modifier=dec.name)
    print("[Proto04]", obj.name, "folds smoothed:", unfold(obj))
    for p in obj.data.polygons:
        p.use_smooth = True
    skin = bpy.data.materials.get("CartoonSkin") or bpy.data.materials.new("CartoonSkin")
    skin.diffuse_color = SKIN
    obj.data.materials.clear()
    obj.data.materials.append(skin)
    return obj


# ----------------------------------------------------------------------------------------------- hands, heads
def load_rig_library():
    """build_cartoon_rig_02.py's helpers (hand meshes, hand placement) without running its build: its source up to
    the build lines. Read-only use; that script is unchanged."""
    src = open(os.path.join(SCRIPTS, "build_cartoon_rig_02.py")).read()
    src = src.split("\ncoll = collection()\nRESULTS")[0]
    ns = {"__name__": "rig02_lib"}
    exec(src, ns)
    return ns


def add_hands(name, spec, L, coll, R):
    hands = []
    for side, sx in (("Left", 1), ("Right", -1)):
        hand = R["H"]["make_hand"]("Open", coll)
        hand.name = "%s_%sHand" % (name, side)
        joint = Vector((sx * spec["arm_x"], 0, L["WR"]))
        hand.data.transform(Matrix.Translation(joint) @ R["hand_space"](side, spec["hand"]))
        if sx < 0:
            hand.data.flip_normals()
        hand.matrix_world = Matrix.Identity(4)
        for g in list(hand.vertex_groups):
            hand.vertex_groups.remove(g)
        hand.data.materials.clear()
        hand.data.materials.append(bpy.data.materials["CartoonSkin"])
        for c in list(hand.users_collection):
            c.objects.unlink(hand)
        coll.objects.link(hand)
        hands.append(hand)
    return hands


def stand_in_head(name, L, x, coll):
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=0.6, depth=1.2, location=(x, 0.0, L["N"] + 0.6))
    h = bpy.context.object
    h.name = name
    h.scale = (1.0, 0.85, 1.0)
    bev = h.modifiers.new("Round", "BEVEL")
    bev.width = 0.25
    bev.segments = 6
    mat = bpy.data.materials.get("StandInHead") or bpy.data.materials.new("StandInHead")
    mat.diffuse_color = (0.98, 0.80, 0.35, 1)
    h.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    for c in list(h.users_collection):
        c.objects.unlink(h)
    coll.objects.link(h)
    return h


# ----------------------------------------------------------------------------------------------- main
def new_collection(name):
    coll = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(coll)
    return coll


def build_set(tag, L, coll, preview, R, y=0.0):
    out = {}
    # A longer torso stretches the torso's shapes too (their positions already follow the joint heights).
    tz = (L["N"] - L["HJ"]) / (TALLER["N"] - TALLER["HJ"])
    for i, (name, fn) in enumerate(BUILDS.items()):
        spec = fn(L)
        if abs(tz - 1.0) > 1e-6:
            stretched = []
            for kind, args, blend, op, mirror in spec["torso"]:
                if kind == "ellipsoid":
                    c, r, rot = args
                    args = (c, (r[0], r[1], r[2] * tz), rot)
                elif kind == "box":
                    c, h, rad, rot = args
                    args = (c, (h[0], h[1], h[2] * tz), rad, rot)
                stretched.append((kind, args, blend, op, mirror))
            spec["torso"] = stretched
        body = finish(field_to_mesh("Proto%s_%s" % (tag, name), spec, L), coll)
        hands = add_hands(body.name, spec, L, coll, R)
        x = i * SPACING
        for o in [body] + hands:
            o.location = (x, y, 0)
        stand_in_head(body.name + "_Head", L, x, preview).location.y = y
        tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
        htris = sum(len(p.vertices) - 2 for h in hands for p in h.data.polygons)
        out[name] = (body, tris, htris)
        print("[Proto04]", body.name, "body", tris, "hands", htris)
    return out


if globals().get("PROTO04_AS_LIBRARY") is not True:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    R = load_rig_library()
    preview = new_collection("Preview")
    main = new_collection("Proto04")
    build_set("", TALLER, main, preview, R)
    if not os.environ.get("PROTO04_FAST"):        # (set while iterating on shapes: skips the height variant)
        variant = new_collection("Proto04_TorsoTall")
        build_set("TorsoTall", TORSO_TALL, variant, preview, R, y=8.0)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    print("[Proto04] saved", OUT_BLEND)
