# The worn lifting gear and the tee, version 4: for the PROTOTYPE-04 bodies (CHARACTER_ART_DIRECTION.md §10.1: height in
# the torso, arms x1.2), remade from the user's reference photos (2026-11-13: SBD singlet over a tee, lever belt,
# knee sleeves, wrist wraps on competition lifters; "Study the photo closely and remake it closely"). PROTOTYPE:
# nothing exported or uploaded; the gear session's build_cartoon_gear_03.py is used as a LIBRARY and is unchanged.
#
# What the photos show (and what this builds):
#   TEE under the singlet: a fitted crew-neck tee, sleeves to the middle of the upper arm, the crew neck showing above
#     the singlet's scoop.
#   SINGLET: skin-tight over the tee; a deep front scoop (well below the collarbones) and a shallower back U, both
#     piped in the accent colour; wide straps on top of the shoulders (accent-colour shoulder tops); deep armholes;
#     an accent side panel from the armhole down to the hip; short legs ending about a third down the thigh, plain
#     hem; a logo on the chest under the scoop and one across the middle of the back.
#   BELT: a stiff 4-inch lever belt round the NAVEL (not the hips), over the singlet, pressing it in; stitched edges,
#     steel lever on the front.
#   KNEE SLEEVES: thick neoprene tubes centred on the knee, from the lower third of the thigh to below the calf's top,
#     bare skin between the singlet's hem and the sleeve; a stripe and a logo.
#   WRIST WRAPS: a thick wound band right over the wrist joint, from the base of the hand up the forearm.
#
# How: the tee and the singlet are SHELLS over a smoothed copy of the body (the body's own distance field from
# build_cartoon_body_04.py WITHOUT its carved grooves, so fabric bridges the abs and the pec line), the singlet a
# fixed 0.04 further out than the tee from the SAME field, so it can never cut into the tee. Their outlines (necks,
# straps, armholes, hems) are cut as smooth curves on that surface. The belt, knee sleeves and wrist wraps are the
# v03 builders with the photo's placement. Every piece gets the body's bone weights, room in the real lift poses
# (gear_fit_03.pose_relief), one mesh per R15 part (the game format).
#
#   set GEAR04_ANIMS=<folder of the BLOCK-rig animation .rbxmx files> (the committed originals: these bodies have the
#   block rig's legs and HipHeight 2), then
#   blender -b art/blender/CartoonBodies_04_Rigged.blend --python art/scripts/build_cartoon_gear_04.py
# Writes art/blender/CartoonGear_04_Proto.blend.
import math
import os
import tempfile

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
OUT_BLEND = os.path.join(ROOT, "art", "blender", "CartoonGear_04_Proto.blend")
ANIMS = os.environ.get("GEAR04_ANIMS", "")
assert os.path.isdir(ANIMS), "set GEAR04_ANIMS to the folder of the block-rig animations"
BUILDS = ("Skinny", "Heavy", "Muscular")
COLLECTION = "CartoonGear04"
VOX = 0.02

# v03 as a library: its source up to its build lines (definitions only)
_v3_path = os.path.join(SCRIPTS, "build_cartoon_gear_03.py")
_v3_src = open(_v3_path).read()
_cut = "\ncoll = bpy.data.collections.get(COLLECTION)"
assert _cut in _v3_src
V = {"__name__": "gear03_lib", "ITEMS": ("Belt",), "EXPORT": False}
exec(compile(_v3_src.split(_cut)[0], _v3_path, "exec"), V)
F = V["F"]
F["ANIMS"] = ANIMS
P = {"__name__": "body04_lib", "PROTO04_AS_LIBRARY": True}
exec(open(os.path.join(SCRIPTS, "build_cartoon_body_04.py")).read(), P)
L = P["TORSO_TALL"]
U, VV = Vector((1, 0, 0)), Vector((0, 1, 0))


def log(*a):
    print("[Gear04]", *a)


# ---------------------------------------------------------------- the smoothed body the shirts sit on
def body_spec(build):
    """The build's shapes on the torso-tall heights, its torso shapes stretched as build_cartoon_body_04 does."""
    spec = P["BUILDS"][build](L)
    tz = (L["N"] - L["HJ"]) / (P["TALLER"]["N"] - P["TALLER"]["HJ"])
    out = []
    for kind, args, blend, op, mirror in spec["torso"]:
        if kind == "ellipsoid":
            c, r, rot = args
            args = (c, (r[0], r[1], r[2] * tz), rot)
        elif kind == "box":
            c, h, rad, rot = args
            args = (c, (h[0], h[1], h[2] * tz), rad, rot)
        out.append((kind, args, blend, op, mirror))
    spec["torso"] = out
    return spec


class Shell:
    """The body without its grooves; arms count only from `arm_from` up (below that they hang free, and a shirt must
    not web from the arm to the belly)."""

    def __init__(self, spec, arm_from):
        self.spec, self.arm_from = spec, arm_from
        adds = lambda shapes: [s for s in shapes if s[3] == "add"]
        self.torso_s, self.arm_s, self.leg_s = adds(spec["torso"]), adds(spec["arm"]), adds(spec["leg"])

    def parts(self, X):
        fam = P["family"]
        torso = fam(X, self.torso_s)
        arm = np.minimum(fam(X, self.arm_s, 1), fam(X, self.arm_s, -1))
        arm = arm + 4.0 * (1.0 - P["smoothstep"](self.arm_from - 0.06, self.arm_from, X[:, 2]))
        leg = np.minimum(fam(X, self.leg_s, 1), fam(X, self.leg_s, -1))
        return torso, arm, leg

    def field(self, X):
        torso, arm, leg = self.parts(X)
        z, ax = X[:, 2], np.abs(X[:, 0])
        k_sh = self.spec["k_shoulder"] * P["smoothstep"](L["SH"] - 0.80, L["SH"] - 0.25, z) * P["smoothstep"](0.5, 0.8, ax)
        d = P["smin"](torso, arm, k_sh)
        k_hip = self.spec["k_hip"] * P["smoothstep"](L["HJ"] - 0.60, L["HJ"] - 0.10, z)
        return P["smin"](d, leg, k_hip)

    def label(self, X):
        """0 torso, 1 arm, 2 leg: which part each point belongs to."""
        return np.argmin(np.stack(self.parts(X), axis=1), axis=1)

    def arm_inner_x(self, z):
        """How far out the arm's inner surface is at height z (the strap must stay inside it)."""
        fam = P["family"]
        for x in np.arange(0.0, 2.5, 0.005):           # out from the middle: the first point inside the arm
            X = np.array([[x, 0.0, z]], dtype=np.float32)
            if fam(X, self.arm_s, 1)[0] < 0.0:
                return float(x)
        return 2.5


def iso_mesh(name, fn, lo, hi, coll):
    """The surface fn = 0 (negative inside) as a mesh, through OpenVDB (as build_cartoon_body_04.field_to_mesh)."""
    import openvdb as vdb
    lo, hi = np.asarray(lo), np.asarray(hi)
    i0 = np.floor(lo / VOX).astype(int)
    n = (np.ceil(hi / VOX).astype(int) - i0) + 1
    xs, ys, zs = [(i0[a] + np.arange(n[a])) * VOX for a in range(3)]
    density = np.empty(tuple(n), dtype=np.float32)
    for k in range(0, n[2], 40):
        kk = slice(k, min(k + 40, n[2]))
        X, Y, Z = np.meshgrid(xs, ys, zs[kk], indexing="ij")
        pts = np.stack([X.ravel(), Y.ravel(), Z.ravel()], axis=1).astype(np.float32)
        density[:, :, kk] = np.clip(-fn(pts), -0.1, 0.1).reshape(X.shape)
    grid = vdb.FloatGrid(-0.1)
    grid.copyFromArray(density, ijk=tuple(int(v) for v in i0), tolerance=0.0)
    grid.transform = vdb.createLinearTransform(voxelSize=VOX)
    grid.name = "density"
    path = os.path.join(tempfile.gettempdir(), "gear04_%s.vdb" % name)
    vdb.write(path, grids=[grid])
    vol = bpy.data.volumes.new(name + "_Field")
    vol.filepath = path
    vol_obj = bpy.data.objects.new(name + "_Field", vol)
    coll.objects.link(vol_obj)
    holder = bpy.data.objects.new(name + "_Holder", bpy.data.meshes.new(name + "_Holder"))
    coll.objects.link(holder)
    m = holder.modifiers.new("Field", "VOLUME_TO_MESH")
    m.object, m.grid_name, m.threshold, m.resolution_mode, m.adaptivity = vol_obj, "density", 0.0, "GRID", 0.0
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(holder.evaluated_get(dg))
    bpy.data.objects.remove(holder, do_unlink=True)
    bpy.data.objects.remove(vol_obj, do_unlink=True)
    bpy.data.volumes.remove(vol)
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    return o


def apply_mod(o, kind, **props):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    m = o.modifiers.new(kind, kind)
    for k, v in props.items():
        setattr(m, k, v)
    bpy.ops.object.modifier_apply(modifier=m.name)


def triangles(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def coords(o):
    return np.array([v.co[:] for v in o.data.vertices], dtype=np.float32)


def grad(fn, X, eps=0.004):
    g = np.zeros_like(X)
    for a in range(3):
        d = np.zeros(3, dtype=np.float32)
        d[a] = eps
        g[:, a] = (fn(X + d) - fn(X - d)) / (2 * eps)
    return g


def settle(X, fn, rules):
    """Moves each edge point onto its cut line (the rule nearest to it: g = 0) while staying on the surface fn = 0."""
    if len(X) == 0:
        return X
    score = np.full(len(X), np.inf)
    which = np.full(len(X), -1)
    for r, (pred, g_fn) in enumerate(rules):
        ok = pred(X)
        s = np.where(ok, np.abs(g_fn(X)), np.inf)
        better = s < score
        score[better], which[better] = s[better], r
    for _ in range(4):
        for r, (pred, g_fn) in enumerate(rules):
            sel = which == r
            if not sel.any():
                continue
            Y = X[sel]
            n = grad(fn, Y)
            n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-6)
            gv = g_fn(Y)
            gg = grad(g_fn, Y)
            t = gg - (gg * n).sum(axis=1, keepdims=True) * n
            step = (gv / np.maximum((t * t).sum(axis=1), 1e-6))[:, None] * t
            ln = np.linalg.norm(step, axis=1, keepdims=True)
            step *= np.minimum(1.0, 0.06 / np.maximum(ln, 1e-6))
            X[sel] = Y - step
        f = fn(X)
        gf = grad(fn, X)
        X -= (f / np.maximum((gf * gf).sum(axis=1), 1e-6))[:, None] * gf
    return X


def cut_shell(o, fn, keep, rules, final_tris, smooth_rounds=10):
    """Keeps the faces whose corners all pass `keep`, drops stray bits, smooths every open edge into a clean line lying
    on its cut (`rules`) and on the surface, then thins the piece to `final_tris` with its edges held in place (cutting
    a fine mesh, then thinning: cutting an already-thinned one left notches and lost the narrow straps)."""
    X = coords(o)
    ok = keep(X)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not all(ok[v.index] for v in f.verts)], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # stray islands (a scrap of fabric caught under the jaw): keep pieces with at least 4% of the faces
    seen, islands = set(), []
    for f0 in bm.faces:
        if f0 in seen:
            continue
        isl, stack = [], [f0]
        seen.add(f0)
        while stack:
            f = stack.pop()
            isl.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g not in seen:
                        seen.add(g)
                        stack.append(g)
        islands.append(isl)
    total = sum(len(i) for i in islands)
    gone = [f for isl in islands if len(isl) < 0.04 * total for f in isl]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # spikes: a face hanging on by one corner
    for _ in range(2):
        spikes = [f for f in bm.faces if sum(1 for e in f.edges if e.is_boundary) >= 3 or
                  (sum(1 for e in f.edges if e.is_boundary) >= 2 and f.calc_area() < 0.0004)]
        if not spikes:
            break
        bmesh.ops.delete(bm, geom=spikes, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    rim = [v for v in bm.verts if v.is_boundary]
    index = {v: i for i, v in enumerate(rim)}
    nbrs = [[index[e.other_vert(v)] for e in v.link_edges if e.is_boundary and e.other_vert(v) in index] for v in rim]
    R = np.array([v.co[:] for v in rim], dtype=np.float32)
    for _ in range(smooth_rounds):
        avg = np.array([R[n].mean(axis=0) if n else R[i] for i, n in enumerate(nbrs)], dtype=np.float32)
        R = 0.5 * R + 0.5 * avg
        R = settle(R, fn, rules)
    for v, p in zip(rim, R):
        v.co = Vector(p.tolist())
    # the faces next to the edge, evened out (the edge points moved)
    ring = {o2 for v in rim for e in v.link_edges for o2 in e.verts} - set(rim)
    bmesh.ops.smooth_vert(bm, verts=list(ring), factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.to_mesh(o.data)
    bm.free()
    # every face turned the same way, outward (the mesher's faces were not all facing out)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    X = np.array([f.calc_center_median()[:] for f in bm.faces], dtype=np.float32)
    N = np.array([f.normal[:] for f in bm.faces], dtype=np.float32)
    g = grad(fn, X)                                    # the field grows outward
    if (np.sum(N * g, axis=1) < 0).sum() > len(X) / 2:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(o.data)
    bm.free()
    # thin it, its edges held (the decimation only collapses the inside)
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    held = {v.index for v in bm.verts if v.is_boundary}
    bm.free()
    grp = o.vertex_groups.new(name="Inside")
    grp.add([i for i in range(len(me.vertices)) if i not in held], 1.0, "REPLACE")
    tris = triangles(o)
    if tris > final_tris:
        apply_mod(o, "DECIMATE", ratio=final_tris / tris, use_symmetry=False, vertex_group="Inside")
    o.vertex_groups.remove(o.vertex_groups["Inside"])
    # every other edge point dissolved (nothing moves: the edge keeps its line at half the points; each edge point
    # costs four triangles once the fabric has thickness)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    drop, seen = [], set()
    for v in bm.verts:
        if v.is_boundary and v not in seen and len(v.link_faces) >= 1:
            nb = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
            if len(nb) == 2 and not any(n in seen for n in nb):
                drop.append(v)
                seen.add(v)
                seen.update(nb)
    bmesh.ops.dissolve_verts(bm, verts=drop)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-4)
    bm.to_mesh(o.data)
    bm.free()
    for p in o.data.polygons:
        p.use_smooth = True
    return [tuple(p) for p in R]


def bisect(o, planes):
    """Cuts edges into the mesh along planes (nothing removed), so colour panels end on clean straight lines. Each
    plane: (point, normal, where) - only faces whose centre passes `where` (None: all) are cut, so a plane that only
    grazes the surface elsewhere (an outer thigh) leaves no slivers there."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    for plane in planes:
        co, no = plane[0], plane[1]
        where = plane[2] if len(plane) > 2 else None
        faces = [f for f in bm.faces if where is None or where(f.calc_center_median())]
        geom = list({v for f in faces for v in f.verts}) + list({e for f in faces for e in f.edges}) + faces
        if faces:
            bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, dist=0.002)
    bm.to_mesh(o.data)
    bm.free()
    for p in o.data.polygons:
        p.use_smooth = True


def face_keys(o, key_of):
    me = o.data
    C = np.array([p.center[:] for p in me.polygons], dtype=np.float32)
    o["keys"] = list(key_of(C))


def push_out_of(o, inner, gap, collar=0.12):
    """Moves every point of `o` that is closer than `gap` outside `inner`'s surface (or inside it) out to `gap`, except
    within `collar` of the inner piece's own edges (its rolled collar and hems would crumple the fabric over them)."""
    from mathutils.kdtree import KDTree
    me = inner.data
    tree = BVHTree.FromPolygons([v.co for v in me.vertices], [tuple(p.vertices) for p in me.polygons])
    bm = bmesh.new()
    bm.from_mesh(me)
    rim = [v.co.copy() for v in bm.verts if v.is_boundary]
    bm.free()
    kd = KDTree(max(1, len(rim)))
    for i, p in enumerate(rim):
        kd.insert(p, i)
    kd.balance()
    moved = 0
    for v in o.data.vertices:
        if rim and kd.find(v.co)[2] < collar:
            continue
        loc, nrm, _i, d = tree.find_nearest(v.co, 0.25)
        if loc is None:
            continue
        side = (v.co - loc).dot(nrm)
        if side < gap:
            v.co += nrm * (gap - side)
            moved += 1
    return moved


def under_belt(o, shape, gap):
    """A belt is stiff and presses the fabric under it in: points inside the belt's height that stick out past its
    inner face go back in to `gap` under it (the photos: the singlet and tee squeezed under the belt)."""
    mid, axis = shape[0], shape[1]
    half = 0.27
    moved = 0
    for v in o.data.vertices:
        h = v.co.z - mid
        if abs(h) > half:
            continue
        d = Vector((v.co.x - axis.x, v.co.y - axis.y, 0))
        if d.length < 1e-6:
            continue
        ang = math.atan2(d.y, d.x)
        inner = V["belt_point"](shape, ang, h, 0.0)
        r_in = Vector((inner.x - axis.x, inner.y - axis.y, 0)).length - gap
        if d.length > r_in:
            v.co.x, v.co.y = axis.x + d.x / d.length * r_in, axis.y + d.y / d.length * r_in
            moved += 1
    return moved


def hold_shoulder(o, pivot):
    """Inside the shoulder joint the torso holds the fabric (as build_cartoon_rig_04.shoulder_weights does for the
    skin): the upper-arm share fades from nothing 0.30 in from the joint to all of it at the joint, so the tee under
    the straps stays under them when the arm goes up, and only the sleeve follows the arm."""
    ut = o.vertex_groups.get("UpperTorso") or o.vertex_groups.new(name="UpperTorso")
    for v in o.data.vertices:
        if v.co.z < L["SH"] - 0.8:
            continue
        t = min(1.0, max(0.0, (abs(v.co.x) - (pivot - 0.30)) / 0.28))
        keep = t * t * (3 - 2 * t)
        moved = 0.0
        for g in v.groups:
            if o.vertex_groups[g.group].name in ("LeftUpperArm", "RightUpperArm") and g.weight > 0:
                moved += g.weight * (1 - keep)
                g.weight *= keep
        if moved > 0:
            ut.add([v.index], moved + next((g.weight for g in v.groups if g.group == ut.index), 0.0), "REPLACE")


def finish_shell(o, body, clear, only=None, cap=0.03, hold=None):
    """Out of the skin, the body's bone weights (only these bones, if given), room in the lift poses. The edges get
    their thickness later (thicken): a folded-in hem on a paper-thin sheet read as a crease and showed the sheet's
    back from most angles."""
    F["push_clear"](o, body, clear * 0.6)
    F["transfer_weights"](o, body, only=only)
    if hold is not None:
        hold_shoulder(o, hold)
    relief = F["pose_relief"](o, body, cap=cap)
    return relief


FABRIC = 0.018                 # the fabric's thickness


def thicken(o, edge_key=None, near=None, thick=FABRIC):
    """Real fabric thickness: the sheet grown inward by FABRIC (Blender's Solidify) with a rim round every opening, so
    an edge reads as a thick bound edge from every angle and the back of the sheet is never seen. The inside copy is
    kept only on the row along each opening (elsewhere it is hidden under the outside: no triangles spent on it).
    `near`: only openings within 0.03 of these points get thickness (the tee under the singlet: its sleeve ends and
    collar, not the hidden cut round the covered middle). Keys: the outside keeps its own; the rim and the edge rows
    take edge_key(centre, old_key) (the binding / piping): the outside keeps its own colour."""
    from mathutils.kdtree import KDTree
    me = o.data
    f0 = len(me.polygons)
    keys = list(o["keys"])
    bm = bmesh.new()
    bm.from_mesh(me)
    edge_v = {v.index for v in bm.verts if v.is_boundary}
    n0 = len(bm.verts)
    bm.free()
    if near is not None:
        kd = KDTree(max(1, len(near)))
        for i, p in enumerate(near):
            kd.insert(Vector(p), i)
        kd.balance()
        edge_v = {i for i in edge_v if near and kd.find(me.vertices[i].co)[2] < 0.03}
    apply_mod(o, "SOLIDIFY", thickness=thick, offset=-1.0, use_rim=True, use_even_offset=False)
    me = o.data
    assert len(me.polygons) >= 2 * f0, "solidify face order"
    new_keys, keep = [], []
    for i, p in enumerate(me.polygons):
        vs = list(p.vertices)
        if i < f0:                                     # the outside keeps its colour
            new_keys.append(keys[i])
            keep.append(True)
        elif i < 2 * f0:                               # the inside copy: only the row along an opening
            on_edge = any((v - n0) in edge_v for v in vs)
            k = keys[i - f0]
            if edge_key and on_edge:
                k = edge_key(p.center, k)
            new_keys.append(k)
            keep.append(on_edge)
        else:                                          # the rim (only round the openings that get thickness)
            on_edge = all((v if v < n0 else v - n0) in edge_v for v in vs)
            new_keys.append(edge_key(p.center, keys[0]) if edge_key else keys[0])
            keep.append(on_edge)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i, k in enumerate(keep) if not k], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    o["keys"] = [k for k, kp in zip(new_keys, keep) if kp]
    for p in me.polygons:
        p.use_smooth = True


def piping(sheet, name, coll, body, where, width=0.05, lift=0.008, only=None):
    """The accent binding along a garment's edges (the photos' red piping round the neck and armholes): a ribbon
    `width` wide lying on the sheet just inside each edge chosen by `where(point)`, `lift` proud of it. Two triangles
    per edge segment."""
    bm = bmesh.new()
    bm.from_mesh(sheet.data)
    bm.normal_update()
    inward = {}
    for e in bm.edges:
        if not e.is_boundary:
            continue
        f = e.link_faces[0]
        a, b = e.verts
        mid = (a.co + b.co) / 2
        d = (b.co - a.co).normalized()
        t = f.calc_center_median() - mid
        t = (t - d * t.dot(d)).normalized()
        for v in (a, b):
            inward[v] = inward.get(v, Vector()) + t
    verts, faces, index = [], [], {}
    for v, t in inward.items():
        if not where(v.co):
            continue
        t = t.normalized()
        index[v] = len(verts)
        verts += [v.co + v.normal * lift, v.co + t * width + v.normal * lift]
    for e in bm.edges:
        if e.is_boundary and e.verts[0] in index and e.verts[1] in index:
            i, j = index[e.verts[0]], index[e.verts[1]]
            faces.append((i, j, j + 1, i + 1))
    bm.free()
    o = F["new_object"](name, coll, verts, faces)
    # facing out like the sheet
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    out = sum(f.normal.dot(f.calc_center_median() - Vector((0, 0, f.calc_center_median().z))) for f in bm.faces)
    if out < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(o.data)
    bm.free()
    for p in o.data.polygons:
        p.use_smooth = True
    F["transfer_weights"](o, body, only=only)
    return o


def covered_cut(tee, singlet, name, coll, margin=0.10):
    """The tee as worn UNDER the singlet: the faces the singlet covers (a ray straight out meets it, away from its
    edges) are removed; the sleeves, the collar and the strip round every singlet edge stay."""
    from mathutils.kdtree import KDTree
    sm = singlet.data
    tree = BVHTree.FromPolygons([v.co for v in sm.vertices], [tuple(p.vertices) for p in sm.polygons])
    bm = bmesh.new()
    bm.from_mesh(sm)
    rim = [v.co.copy() for v in bm.verts if v.is_boundary]
    bm.free()
    kd = KDTree(max(1, len(rim)))
    for i, p in enumerate(rim):
        kd.insert(p, i)
    kd.balance()
    o = tee.copy()
    o.data = tee.data.copy()
    o.name = name
    coll.objects.link(o)
    keys = list(o["keys"])
    gone = []
    for p in o.data.polygons:
        loc, _n, _i, _d = tree.ray_cast(p.center + p.normal * 0.004, p.normal, 0.2)
        if loc is not None and kd.find(loc)[2] > margin:
            gone.append(p.index)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in gone], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    gone = set(gone)
    o["keys"] = [k for i, k in enumerate(keys) if i not in gone]
    return o


# ---------------------------------------------------------------- the tee and the singlet
TEE_CLEAR = 0.035
SINGLET_CLEAR = 0.075          # 0.04 over the tee, from the same smoothed body
NECK = (0.0, 0.03, 0.55, 0.46)  # the crew neck's ellipse (centre x, y, radius x, y): clear of the 1.2-wide head


def heights(body):
    m = body.landmarks()
    sleeve = L["E"] + 0.55 * (L["SH"] - L["E"])           # the middle of the upper arm
    # short singlet legs (user 2026-11-13: "a tad bit shorter on the thighs, to make room for the knee sleeves"), then
    # long knee sleeves from the lower thigh to mid-shin with a strip of bare skin between them
    leg_hem = m["crotch"] - 0.06
    knee_top = min(m["knee"] + 0.36, leg_hem - 0.08)
    knee_bot = m["knee"] - 0.42
    return dict(m=m, sleeve=sleeve, arm_from=sleeve - 0.12, hem=L["W"] - 0.10, neck=L["N"] - 0.30,
                leg_hem=leg_hem, knee_top=knee_top, knee_bot=knee_bot)


def make_tee(body, shell, H, coll):
    fn = lambda X: shell.field(X) - TEE_CLEAR
    o = iso_mesh(body.build + "_Tee", fn, (-2.4, -1.5, H["hem"] - 0.15), (2.4, 1.4, L["N"] + 0.4), coll)
    apply_mod(o, "SMOOTH", factor=0.5, iterations=2)
    apply_mod(o, "DECIMATE", ratio=min(1.0, 7000 / max(1, triangles(o))), use_symmetry=False)
    cx, cy, rx, ry = NECK
    ell = lambda X: np.sqrt(((X[:, 0] - cx) / rx) ** 2 + ((X[:, 1] - cy) / ry) ** 2) - 1.0

    def keep(X):
        lab = shell.label(X)
        return ((lab != 2) & (X[:, 2] > H["hem"]) & ~((lab == 1) & (X[:, 2] < H["sleeve"]))
                & ~((X[:, 2] > H["neck"]) & (ell(X) < 0)))
    rules = [
        (lambda X: (X[:, 2] < H["hem"] + 0.2) & (np.abs(X[:, 0]) < 1.9), lambda X: X[:, 2] - H["hem"]),
        (lambda X: (np.abs(X[:, 0]) > 0.6) & (X[:, 2] < H["sleeve"] + 0.2), lambda X: X[:, 2] - H["sleeve"]),
        (lambda X: X[:, 2] > H["neck"] - 0.2, ell),
    ]
    cut_shell(o, fn, keep, rules, 900)
    bisect(o, [((0, 0, H["sleeve"] + 0.13), (0, 0, 1), lambda c: abs(c.x) > 0.6)])
    lab_of = lambda C: shell.label(C)
    face_keys(o, lambda C: np.where((lab_of(C) == 1) & (C[:, 2] < H["sleeve"] + 0.13), "TeeWhite", "Tee"))
    # the white cuffs stand a little proud
    keys = o["keys"]
    me = o.data
    cuff = {vi for p, k in zip(me.polygons, keys) if k == "TeeWhite" for vi in p.vertices}
    for vi in cuff:
        me.vertices[vi].co += me.vertices[vi].normal * 0.015
    relief = finish_shell(o, body, TEE_CLEAR, hold=P["BUILDS"][body.build](L)["pivot_x"])
    log(body.build, "Tee", triangles(o), "triangles, pose relief up to %.3f" % relief)
    return o


def make_singlet(body, shell, H, coll):
    def fn(X):
        lift = P["smoothstep"](H["hem"] - 0.15, H["hem"] + 0.02, X[:, 2])
        return shell.field(X) - (TEE_CLEAR + (SINGLET_CLEAR - TEE_CLEAR) * lift)
    o = iso_mesh(body.build + "_Singlet", fn, (-2.4, -1.5, H["leg_hem"] - 0.15), (2.4, 1.4, L["N"] + 0.4), coll)
    apply_mod(o, "SMOOTH", factor=0.5, iterations=2)
    apply_mod(o, "DECIMATE", ratio=min(1.0, 8000 / max(1, triangles(o))), use_symmetry=False)
    m = H["m"]
    xi = V["HEAD_HALF"] + 0.06                                        # straps clear of the head
    xo = min(xi + 0.28, shell.arm_inner_x(L["SH"] - 0.45) - 0.04)     # and inside the arm
    z_cap = L["N"] + 0.6
    z_nf, z_nb = L["SH"] - 0.52, L["SH"] - 0.28                       # deep front scoop, shallower back U
    # deep armholes: at least half a stud under the shoulder joint (the skin-found armpit sits high on some builds)
    z_ah, w_ah = min(m["armpit"], L["SH"] - 0.5) - 0.15, 0.45

    z_st = L["SH"] + 0.05                                             # where the strap's outer edge meets the armhole

    def top(X):
        s = np.abs(X[:, 0])
        back = P["smoothstep"](-0.15, 0.15, X[:, 1])
        z_n = z_nf + (z_nb - z_nf) * back
        centre = z_n + (z_cap - z_n) * np.clip(s / xi, 0, 1) ** 3
        # the armhole: straight down from the strap's outer edge, rounding into a flat bottom under the arm
        t = np.clip((s - xo) / w_ah, 0, 1)
        side = z_ah + (z_st - z_ah) * (1 - np.sqrt(np.clip(1 - (1 - t) ** 2, 0, 1)))
        return np.where(s < xi, centre, np.where(s <= xo, z_cap + 1.0, side))

    def keep(X):
        lab = shell.label(X)
        s = np.abs(X[:, 0])
        strap = (s >= xi) & (s <= xo + 0.01) & (X[:, 2] > L["SH"] - 0.5)    # the straps stay, whatever is under them
        return ((lab != 1) | strap) & ((lab != 2) | (X[:, 2] > H["leg_hem"])) & (X[:, 2] <= top(X))
    rules = [
        (lambda X: (shell.label(X) == 2) & (X[:, 2] < H["leg_hem"] + 0.2), lambda X: X[:, 2] - H["leg_hem"]),
        (lambda X: X[:, 2] > m["armpit"] - 0.5, lambda X: X[:, 2] - np.minimum(top(X), z_cap)),
        # the straps' straight side edges over the shoulder
        (lambda X: (X[:, 2] > z_st - 0.05) & (np.abs(np.abs(X[:, 0]) - xo) < 0.1), lambda X: np.abs(X[:, 0]) - xo),
        (lambda X: (X[:, 2] > L["SH"] - 0.2) & (np.abs(np.abs(X[:, 0]) - xi) < 0.1), lambda X: np.abs(X[:, 0]) - xi),
    ]
    cut_shell(o, fn, keep, rules, 950)
    # the straps lie flat over the shoulders (the photos): their inside smoothed, then put back on the surface (where
    # they climb the traps beside the head the thinned mesh folded into crinkles)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    strap_v = [v for v in bm.verts if not v.is_boundary and xi - 0.05 <= abs(v.co.x) <= xo + 0.05
               and v.co.z > L["SH"] - 0.35]
    for _ in range(6):
        bmesh.ops.smooth_vert(bm, verts=strap_v, factor=0.6, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        if strap_v:
            Xs = np.array([v.co[:] for v in strap_v], dtype=np.float32)
            f = fn(Xs)
            gf = grad(fn, Xs)
            Xs -= (f / np.maximum((gf * gf).sum(axis=1), 1e-6))[:, None] * gf
            for v, p in zip(strap_v, Xs):
                v.co = Vector(p.tolist())
    bm.to_mesh(o.data)
    bm.free()
    side_cut = math.radians(19)
    upper = lambda c: c.z > L["SH"] - 0.5
    torso_side = lambda c: c.z > L["HJ"] + 0.15 and shell.label(np.array([c[:]], dtype=np.float32))[0] == 0
    planes = [((0, 0, L["HJ"] + 0.25), (0, 0, 1), torso_side), ((0, 0, L["SH"] - 0.14), (0, 0, 1), upper)]
    for sx in (1, -1):
        for x in (xi, xo):
            planes.append(((sx * x, 0, 0), (1, 0, 0), upper))
        for sa in (1, -1):
            d = Vector((sx * math.cos(side_cut), sa * math.sin(side_cut), 0))
            planes.append(((0, 0, 0), (d.y, -d.x, 0), torso_side))
    bisect(o, planes)

    def key_of(C):
        lab = shell.label(C)
        out = []
        for c, lb in zip(C, lab):
            x, y, z = c
            s = abs(x)
            side_deg = math.degrees(math.atan2(abs(y), s))
            if lb == 2:
                out.append("Shorts")                                  # plain legs (the photos)
            elif xi <= s <= xo and z > L["SH"] - 0.14:
                out.append("Red")                                     # accent shoulder tops
            elif lb == 0 and side_deg < 19 and z > L["HJ"] + 0.25:
                out.append("Red")                                     # side panels, armhole down to the hip
            else:
                out.append("Black")
        return out
    face_keys(o, key_of)
    o["z_nf"] = z_nf
    log(body.build, "Singlet straps", round(xi, 3), round(xo, 3))
    return o


SINGLET_BONES = ("LowerTorso", "UpperTorso", "LeftUpperLeg", "RightUpperLeg")


def finish_singlet(o, body, coll, H):
    # the singlet moves with the torso and thighs only: the straps stay on the shoulders while the arm moves under
    # them (the photos), instead of following the arm and twisting
    relief = finish_shell(o, body, SINGLET_CLEAR, only=SINGLET_BONES, cap=0.04)
    log(body.build, "Singlet", triangles(o), "triangles, pose relief up to %.3f" % relief)


def singlet_edge(H):
    """The singlet's bound edges: accent piping round the neck and armholes, plain at the leg hems (the photos)."""
    return lambda c, k: "Shorts" if c.z < H["leg_hem"] + 0.12 else "Trim"


# ---------------------------------------------------------------- belt (v03 builder, placed at the navel)
V["BELT_CLEAR"] = 0.10          # over the body: outside the singlet; the fabric under it is pressed in (under_belt)


def belt_shape_04(body):
    """v03's stiff-band fit, centred on the navel: a third of the way from the hip joint to the shoulder joint (the
    photos: the belt round the belly button, the hips below it bare of belt)."""
    hip, shoulder = body.joints["LowerTorso"].z, body.joints["LeftUpperArm"].z
    mid = hip + 0.33 * (shoulder - hip)
    rows = body.stack("TorsoHips", mid - 0.30, mid + 0.30, 0.03, (0, 0), n=72, smooth=0)
    axis = Vector((0, sum(r[1].y for r in rows) / len(rows), mid))
    K = 72
    angles = [2 * math.pi * k / K for k in range(K)]
    per_row = []
    for z, c, rs in rows:
        poly = [F["ring_point"](c, U, VV, rs, a) - axis for a in angles]
        per_row.append((z - mid, F["radial"]([(p.x, p.y) for p in poly], angles)))
    slopes = [s * 0.02 for s in range(-30, 31)]
    a_of, b_of = [], []
    for k in range(K):
        best = None
        for b in slopes:
            a = max(r[k] - b * h for h, r in per_row)
            cost = sum(a + b * h - r[k] for h, r in per_row)
            if best is None or cost < best[0]:
                best = (cost, a, b)
        a_of.append(best[1])
        b_of.append(best[2])
    b_s = [sum(b_of[(k + d) % K] for d in range(-4, 5)) / 9 for k in range(K)]
    a_s = [sum(a_of[(k + d) % K] for d in range(-3, 4)) / 7 for k in range(K)]
    a_s = [max(a_s[k], max(r[k] - b_s[k] * h for h, r in per_row)) for k in range(K)]
    return mid, axis, angles, a_s, b_s


V["belt_shape"] = belt_shape_04

# ---------------------------------------------------------------- knee sleeves (v03's tube, the photo's placement)
KNEE_SLEEVE = dict(V["KNEE_SLEEVE"], clear=0.065, length=(0.26, 0.34),   # thick neoprene; centred on the knee
                   around=16, rows=6)                                       # (lighter: a smooth tube needs few rows)
V["BELT_SEGMENTS"] = 22         # lighter belt (28 in v03)


def build_knee_sleeves_04(body, coll):
    """One seamless thick tube per leg from the lower third of the thigh to below the calf's top (bare skin between
    it and the singlet's hem), rolled ends, a diagonal stripe down the outer side, the logo low on the front."""
    spec = KNEE_SLEEVE
    knee = body.landmarks()["knee"]
    cl = spec["clear"]
    G = V["Garment"]()
    stacks = {}
    z_lo = knee - spec["length"][1]
    z_hi = min(knee + spec["length"][0], heights(body)["leg_hem"] - 0.14)     # a gap of bare skin under the singlet
    for side, sx in (("Left", 1), ("Right", -1)):
        rows = body.stack(side + "Leg", z_lo - 0.03, z_hi + 0.03, 0.03, (sx * 0.5, 0), n=96, smooth=2)
        stacks[side] = rows
        n = spec["around"]
        T = V["TRIM"]
        hs = [z_lo] + [z_lo + T + (z_hi - T - z_lo - T) * i / (spec["rows"] - 1) for i in range(spec["rows"])] + [z_hi]
        prev = None
        for z in hs:
            c, rs = F["stack_at"](rows, z)
            # a sleeve smooths the knee into a near-round tube (the photos): the outline rounded toward a circle
            cur = []
            for j in range(n):
                a = 2 * math.pi * j / n
                p = F["ring_point"](c, U, VV, rs, a, cl)
                r_mean = sum(rs) / len(rs)
                d = Vector((p.x - c.x, p.y - c.y, 0))
                if d.length > 1e-6:
                    want = max(d.length, 0.7 * d.length + 0.3 * (r_mean + cl))
                    p = Vector((c.x, c.y, p.z)) + d.normalized() * want
                cur.append(G.add(p))
            if prev:
                for j in range(n):
                    G.quad(prev[j], prev[(j + 1) % n], cur[(j + 1) % n], cur[j], spec["keys"]["body"])
            prev = cur
    o = G.build(body.build + "_" + spec["worn"], coll)
    F["push_clear"](o, body, cl * 0.7)
    V["lip"](o, 0.03, 0.016, spec["keys"]["body"])
    F["push_clear"](o, body, 0.012)
    F["transfer_weights"](o, body)
    relief = F["pose_relief"](o, body)
    log(body.build, spec["worn"], "pose relief up to %.3f" % relief)
    pieces = V["split_keys"](o, coll, body.build + "_" + spec["worn"])
    target = pieces[spec["keys"]["body"]]
    stripes, patches = [], []
    for side, sx in (("Left", 1), ("Right", -1)):
        rows = stacks[side]
        axis = lambda z, rows=rows: F["stack_at"](rows, z)[0]
        outer = 0.0 if sx > 0 else math.pi
        top, bot = z_hi - 0.06, z_lo + 0.07
        path = [(outer - sx * 0.9 + sx * 1.8 * t, top + (bot - top) * t) for t in [i / 10 for i in range(11)]]
        s = V["limb_overlay"](body, coll, target, axis, path, 0.07, 0.006, body.build + "_SleeveStripe" + side)
        if s:
            stripes.append(s)
        u0, u1 = V["LOGO_U"]
        v_top = 1 - V["LOGO_ROWS"]["White"] / 4.0
        front = -math.pi / 2
        path = [(front + 0.62 * (t - 0.5), knee - 0.20) for t in [i / 8 for i in range(9)]]
        p = V["limb_overlay"](body, coll, target, axis, path, 0.10, 0.008, body.build + "_SleevePatch" + side,
                              uv=(u0, u1, v_top - 0.25, v_top))
        if p:
            patches.append(p)
    for group, key in ((stripes, spec["keys"]["stripe"]), (patches, spec["keys"]["patch"])):
        if not group:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for g in group:
            g.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        bpy.ops.object.join()
        F["transfer_weights"](group[0], body)
        pieces[key] = group[0]
    for key, p in pieces.items():
        p.data.materials.clear()
        p.data.materials.append(V["material"](spec["worn"], key))
    return pieces


# ---------------------------------------------------------------- wrist wraps (v03's wound wrap, over the joint)
V["WRIST_WRAP"]["span"] = (0.17, 0.24)        # from the base of the hand up the forearm: the wrist joint covered
V["WRIST_WRAP"]["around"] = 12                 # lighter (16 in v03)

# ---------------------------------------------------------------- sneakers (a shell round the new feet)
def make_sneakers(body, shell, coll):
    """A shoe shell over each foot up to just above the ankle (the new bodies' feet have a flat top the v03 ring-sliced
    sneaker cut through), the bottom band white (the sole), a rolled collar."""
    collar = body.landmarks()["ankle"] + 0.15
    fn = lambda X: shell.field(X) - 0.045
    o = iso_mesh(body.build + "_Sneakers", fn, (-1.4, -1.1, -0.12), (1.4, 0.9, collar + 0.15), coll)
    apply_mod(o, "DECIMATE", ratio=min(1.0, 3500 / max(1, triangles(o))), use_symmetry=False)
    keep = lambda X: X[:, 2] <= collar
    rules = [(lambda X: X[:, 2] > collar - 0.2, lambda X: X[:, 2] - collar)]
    cut_shell(o, fn, keep, rules, 560)
    bisect(o, [((0, 0, 0.07), (0, 0, 1))])
    face_keys(o, lambda C: np.where(C[:, 2] < 0.07, "SneakersSole", "Sneakers"))
    V["lip"](o, 0.025, 0.010, "Sneakers")
    F["push_clear"](o, body, 0.02)
    F["transfer_weights"](o, body)
    pieces = V["split_keys"](o, coll, body.build + "_Sneakers")
    for key, p in pieces.items():
        p.data.materials.clear()
        p.data.materials.append(V["material"]("Sneakers", key))
    return pieces


# ---------------------------------------------------------------- knee sleeves v4 round 3 (shaped to the leg)
# Round 4 (user: "they seem to thick, they need to be thinner and morph off the leg more", with close-up photos): a snug
# sleeve showing the kneecap and the calf, gripping tighter at its ends, a modest edge.
SLEEVE_OUT = 0.030             # outside of the neoprene from the skin over the knee
SLEEVE_OUT_END = 0.020         # ... and at the two ends (it grips there)
SLEEVE_THICK = 0.020           # its thickness: the inside sits ~0.005-0.01 off the skin (hugging, never floating)
V["PREVIEW"]["WornKneeSleeve"] = {"Body": (0.03, 0.03, 0.035), "Stripes": (0.55, 0.02, 0.03), "Patch": (1, 1, 1)}


def make_knee_sleeves(body, shell, H, coll):
    """User 2026-11-13: the sleeves looked "compressed and small", floated with a gap round the leg; "It needs to be
    a accessory, that morphs with the shape of the leg." Now: a thick neoprene shell over each leg's own smoothed
    shape (thigh, kneecap, calf), from the lower thigh to mid-shin, its inside hugging the skin, its ends showing
    the full thickness; a diagonal stripe down the outer side, the logo low on the front."""
    fam = P["family"]
    legs = shell.leg_s
    z_lo, z_hi = H["knee_bot"], H["knee_top"]
    knee0 = H["m"]["knee"]

    def fn(X):
        z = X[:, 2]
        end = np.maximum(P["smoothstep"](knee0 + 0.12, z_hi, z), P["smoothstep"](knee0 - 0.18, z_lo, z))
        return np.minimum(fam(X, legs, 1), fam(X, legs, -1)) - (SLEEVE_OUT + (SLEEVE_OUT_END - SLEEVE_OUT) * end)
    o = iso_mesh(body.build + "_KneeSleeves", fn, (-1.4, -1.0, z_lo - 0.1), (1.4, 1.0, z_hi + 0.1), coll)
    apply_mod(o, "DECIMATE", ratio=min(1.0, 4000 / max(1, triangles(o))), use_symmetry=False)
    keep = lambda X: (X[:, 2] >= z_lo) & (X[:, 2] <= z_hi)
    rules = [(lambda X: X[:, 2] < z_lo + 0.15, lambda X: X[:, 2] - z_lo),
             (lambda X: X[:, 2] > z_hi - 0.15, lambda X: X[:, 2] - z_hi)]
    cut_shell(o, fn, keep, rules, 560)
    o["keys"] = ["Body"] * len(o.data.polygons)
    F["push_clear"](o, body, SLEEVE_THICK + 0.004)
    F["transfer_weights"](o, body, smooth=1)          # one smooth bend across the knee, no crease
    # little room: the full 0.05 puffed the whole sleeve up at rest for the deep squat; neoprene stretches over the
    # knee, and the back of the knee is hidden when it folds
    relief = F["pose_relief"](o, body, cap=0.012)
    thicken(o, thick=SLEEVE_THICK)
    log(body.build, "KneeSleeves", triangles(o), "triangles, pose relief up to %.3f" % relief)
    pieces = V["split_keys"](o, coll, body.build + "_WornKneeSleeve")
    target = pieces["Body"]
    knee = H["m"]["knee"]
    stripes, patches = [], []
    for side, sx in (("Left", 1), ("Right", -1)):
        rows = body.stack(side + "Leg", z_lo, z_hi, 0.04, (sx * 0.5, 0), n=48, smooth=1)
        axis = lambda z, rows=rows: F["stack_at"](rows, z)[0]
        outer = 0.0 if sx > 0 else math.pi
        # two short accent stripes on the outer side, angled toward the back: one under the top edge, one over the
        # bottom edge (the photos)
        for name, (a0, z0), (a1, z1) in (("Top", (0.15, z_hi - 0.035), (1.05, z_hi - 0.24)),
                                         ("Bot", (0.10, z_lo + 0.24), (0.95, z_lo + 0.035))):
            path = [(outer + sx * (a0 + (a1 - a0) * t), z0 + (z1 - z0) * t) for t in [i / 5 for i in range(6)]]
            st = V["limb_overlay"](body, coll, target, axis, path, 0.045, 0.006,
                                   body.build + "_SleeveStripe" + name + side)
            if st:
                stripes.append(st)
        u0, u1 = V["LOGO_U"]
        v_top = 1 - V["LOGO_ROWS"]["Red"] / 4.0
        front = -math.pi / 2
        path = [(front + 0.70 * (t - 0.5), z_lo + 0.13) for t in [i / 6 for i in range(7)]]
        pt = V["limb_overlay"](body, coll, target, axis, path, 0.11, 0.008, body.build + "_SleevePatch" + side,
                               uv=(u0, u1, v_top - 0.25, v_top))
        if pt:
            patches.append(pt)
    for group, key in ((stripes, "Stripes"), (patches, "Patch")):
        if not group:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for g in group:
            g.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        bpy.ops.object.join()
        F["transfer_weights"](group[0], body, smooth=2)
        pieces[key] = group[0]
    for key, p in pieces.items():
        p.data.materials.clear()
        p.data.materials.append(V["material"]("WornKneeSleeve", key))
    return pieces


# ---------------------------------------------------------------- per build
coll = bpy.data.collections.get(COLLECTION) or bpy.data.collections.new(COLLECTION)
if coll.name not in bpy.context.scene.collection.children:
    bpy.context.scene.collection.children.link(coll)
for o in list(coll.objects):
    bpy.data.objects.remove(o, do_unlink=True)


def to_parts(pieces, prefix_of, body):
    made = []
    for key, o in pieces.items():
        made += F["split_parts"](o, prefix_of(key), body, coll,
                                 material=o.data.materials[0] if o.data.materials else None)
    return made


RESULT = {}
for b in BUILDS:
    body = F["Body"](b)
    H = heights(body)
    shell = Shell(body_spec(b), H["arm_from"])
    belt = V["belt_shape"](body)
    made = {}
    # the tee and the singlet, layered: the singlet always outside the tee, both pressed in under the belt
    tee = make_tee(body, shell, H, coll)
    singlet = make_singlet(body, shell, H, coll)
    finish_singlet(singlet, body, coll, H)
    log(b, "singlet points pushed out of the tee:", push_out_of(singlet, tee, 0.03))
    log(b, "under the belt: tee", under_belt(tee, belt, 0.05), "singlet", under_belt(singlet, belt, 0.015))
    z_nf = singlet["z_nf"]
    # the tee worn under the singlet: only what shows (sleeves, collar, round the straps); the everyday tee stays whole
    bm_t = bmesh.new()
    bm_t.from_mesh(tee.data)
    tee_openings = [tuple(v.co) for v in bm_t.verts if v.is_boundary]
    bm_t.free()
    under = covered_cut(tee, singlet, b + "_TeeUnder", coll)
    thicken(tee)
    thicken(under, near=tee_openings)
    pipe = piping(singlet, b + "_SingletPiping", coll, body, lambda c: c.z > H["leg_hem"] + 0.12,
                  only=SINGLET_BONES)
    thicken(singlet, singlet_edge(H))
    for name, o, item in (("Tee", tee, "Tee"), ("TeeUnder", under, "TeeUnder")):
        pieces = V["split_keys"](o, coll, b + "_" + name)
        for key, p in pieces.items():
            p.data.materials.clear()
            p.data.materials.append(V["material"]("Tee", key))
        made[item] = to_parts(pieces, lambda k, item=item: k.replace("Tee", item), body)
    s_pieces = V["split_keys"](singlet, coll, b + "_WornSinglet")
    if "Trim" in s_pieces:
        bpy.ops.object.select_all(action="DESELECT")
        pipe.select_set(True)
        s_pieces["Trim"].select_set(True)
        bpy.context.view_layer.objects.active = s_pieces["Trim"]
        bpy.ops.object.join()
    else:
        s_pieces["Trim"] = pipe
    target = s_pieces["Black"]
    s_pieces["Patch"] = V["front_patch"](body, coll, target, b + "_SingletPatch", z_nf - 0.24, 0.46, 0.12, "Red")
    s_pieces["Patch"].data.materials.clear()
    back = V["front_patch"](body, coll, target, b + "_SingletBackText", L["SH"] - 0.95, 0.62, 0.15, "Red",
                            side="back")
    bpy.ops.object.select_all(action="DESELECT")
    s_pieces["Patch"].select_set(True)
    back.select_set(True)
    bpy.context.view_layer.objects.active = s_pieces["Patch"]
    bpy.ops.object.join()
    F["transfer_weights"](s_pieces["Patch"], body)
    for key, p in s_pieces.items():
        p.data.materials.clear()
        p.data.materials.append(V["material"]("WornSinglet", key))
    made["WornSinglet"] = to_parts(s_pieces, lambda k: "WornSinglet_" + k, body)
    # the belt, knee sleeves, wrist wraps (v03 builders, the photos' placement)
    made["WornLeverBelt"] = to_parts(V["build_belt"](body, coll), lambda k: "WornLeverBelt_" + k, body)
    made["WornKneeSleeve"] = to_parts(make_knee_sleeves(body, shell, H, coll), lambda k: "WornKneeSleeve_" + k, body)
    made["WornWristWrap"] = to_parts(V["build_wrist_wraps"](body, coll), lambda k: "WornWristWrap_" + k, body)
    # everyday bottoms and shoes for the clothes line-up (v03 builders unchanged)
    made["Shorts"] = to_parts(V["CLOTHES_BUILDERS"]["Shorts"](body, coll), lambda k: k, body)
    made["Sneakers"] = to_parts(make_sneakers(body, shell, coll), lambda k: k, body)
    RESULT[b] = made
    log(b, {k: sum(triangles(p) for p in v) for k, v in made.items()})

bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
log("saved", OUT_BLEND)
