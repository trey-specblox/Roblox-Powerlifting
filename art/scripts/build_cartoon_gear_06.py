# Gear and clothes version 6: every layer built ON THE BODY'S OWN MESH (user 2026-11-16, "Yes, build it").
#
# Why: v5's tee, singlet and belt were three separately shaped meshes, each with its own points, so Roblox bent each
# one from different points and they crossed wherever they sat close (the tee through the singlet and over its straps,
# the body through the tee, the singlet through the belt). The user: "singlets are accessories ... over the shirt",
# "STOP guessing".
# How: the build's body parts are joined into one skin mesh (seams welded). Each layer is a copy of that mesh, every point
# moved out from its OWN skin point along one shared direction per point (the normal of a smoothed copy of the skin),
# keeping exactly that skin point's bone weights:
#     skin  ->  tee (TEE_OUT)  ->  singlet (+ SINGLET_OUT)
# The BELT is the approved rigid lever belt (v4/v5, user 2026-11-16: the layered belt curved and waved), sitting just
# outside the singlet.
# Point i of every layer sits on the same line out from skin point i and bends with the same bones, so in any pose the
# layers stay stacked in that order: they cannot cross (the gap between two layers is only ever carried along by the
# same bones). Grooves are bridged, not copied (the user's 2026-11-12 rejection of skin-copied gear: "painted on"): each
# point stands out at least as far as the smoothed skin, so the fabric spans the muscle grooves.
# Garments are cut out of their layer along smooth lines (cut_lines: every edge a line drawn across the mesh, no ragged
# faces), get real thickness along the same lines (stacked: the inside of a layer can't cross the layer under it) and
# clean bound edges; colour panels end on cut lines too. Nothing under a garment is ever removed: the tee is whole
# under the singlet.
#
#   blender -b art/blender/CartoonBodies_05_Rigged.blend --python art/scripts/build_cartoon_gear_06.py
# Env: GEAR06_BUILDS=Fit (default: Fit, the prototype), GEAR06_OUT (default art/blender/CartoonGear_06_Proto.blend).
# PROTOTYPE: tee, singlet, belt. Nothing exported or uploaded.
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
OUT_BLEND = os.environ.get("GEAR06_OUT") or os.path.join(ROOT, "art", "blender", "CartoonGear_06_Proto.blend")
os.environ["GEAR04_ANIMS"] = os.path.join(ROOT, "art", "animations")

# ---------------------------------------------------------------- the v4 / v3 helpers as a library (as v5 loads them)
_v4_path = os.path.join(SCRIPTS, "build_cartoon_gear_04.py")
_v4_src = open(_v4_path).read()
_cut = "\ncoll = bpy.data.collections.get(COLLECTION)"
W = {"__name__": "gear04_lib"}
exec(compile(_v4_src.split(_cut)[0], _v4_path, "exec"), W)
B5 = {"__name__": "body05_lib", "BODY05_AS_LIBRARY": True}
exec(open(os.path.join(SCRIPTS, "build_cartoon_body_05.py")).read(), B5)
F, V = W["F"], W["V"]
L = B5["L"]
W["L"] = L
W["body_spec"] = B5["body_spec"]
_P = dict(W["P"])
_P["BUILDS"] = {b: (lambda _L, b=b: B5["body_spec"](b)) for b in B5["ORDER"]}
W["P"] = _P
F["BUILDS"] = B5["ORDER"]
V["BELT_SEGMENTS"] = 18       # the approved v5 belt (thinned, user 2026-11-14 "Yes, thin it")
BUILDS = tuple(b for b in os.environ.get("GEAR06_BUILDS", "Fit").split(",") if b)
COLLECTION = "CartoonGear06"
PARTS = F["PARTS"]

# ---------------------------------------------------------------- the layers
TEE_OUT = 0.035               # the tee's outside off the skin (the approved v4 tee: 0.035)
SINGLET_OUT = 0.042           # the singlet's outside off the tee's outside (0.03 let a raised arm squash the gap shut)
BELT_CLEAR_START = 0.10       # the approved belt's room over the body (v4/v5), raised only as far as the singlet needs
BELT_MARGIN = 0.008           # ... plus this
FABRIC = 0.012                # a fabric layer's thickness, grown INWARD along the same lines (< every gap above)
SHOULDER_ROOM = float(os.environ.get("GEAR06_SHOULDER", "0.0"))   # extra room round each shoulder joint...
SHOULDER_REACH = (0.30, 0.65)  # ... all of it within the first distance, fading out by the second
SKIN_JOINTS = [None]
LAYER_WEIGHT_SMOOTH = int(os.environ.get("GEAR06_WSMOOTH", "0"))   # rounds of weight spreading for the layers
SMOOTH_ROUNDS = 24            # Taubin rounds for the smoothed skin (the grooves the fabric spans)
TRIM = 0.035                  # the bound-edge band's width
RED_IN = 0.09                 # the straps' accent reaches this far inside the strap's inner edge
ARM_OFF = 0.15                # the singlet stops where the arm has this share of a point (outside the straps): the
                              # armhole's edge stays out of the armpit crease
ARM_LOW_OFF = 0.6             # ... and below the armhole: only the arm's own skin (by the smoothed share)
TRIM_STRIP_FAR = 0.06         # trim further than this from the singlet's red / black is a loose strip and is dropped
SIDE_OVAL_FROM = 0.1          # a build whose torso is this much narrower than the strap's outer edge gets the side opening
SIDE_OVAL_DEPTH = 0.6         # the side opening's half-width front to back, as a share of the torso's half-depth
SIDE_OVAL_BACK = 1.0          # ... toward the back (1.5 cut into the back strap; the thin strip left between the opening
                              # and the arm's root at the back is dropped by drop_trim_strips instead)
SIDE_OVAL_FACING = 55.0       # ... cut only where the torso faces this close to sideways (degrees off the side)


def log(*a):
    print("[Gear06]", *a, flush=True)


# ---------------------------------------------------------------- the skin mesh
def joined_skin(build, coll):
    """The build's body parts (no hands: the swap hands live there) as ONE mesh in rig space, seams welded, with the
    body's bone weights. Returns the object."""
    rig = bpy.data.objects[build + "Rig"]
    to_rig = rig.matrix_world.inverted()
    copies = []
    for p in PARTS:
        if p.endswith("Hand"):
            continue
        src = bpy.data.objects[build + "_" + p]
        o = src.copy()
        o.data = src.data.copy()
        o.modifiers.clear()
        o.parent = None
        o.data.transform(to_rig @ src.matrix_world)
        o.matrix_world = Matrix.Identity(4)
        coll.objects.link(o)
        copies.append(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in copies:
        o.select_set(True)
    bpy.context.view_layer.objects.active = copies[0]
    bpy.ops.object.join()
    skin = copies[0]
    skin.name = skin.data.name = build + "_Skin06"
    bm = bmesh.new()
    bm.from_mesh(skin.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=2e-4)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(skin.data)
    bm.free()
    skin.data.materials.clear()
    if LAYER_WEIGHT_SMOOTH:
        smooth_layer_weights(skin, LAYER_WEIGHT_SMOOTH)
    return skin


def smooth_layer_weights(o, rounds):
    """The bone weights every LAYER takes (the body keeps its own): spread over the skin a few rounds, so where the
    skin folds as a joint turns hard (the shoulder with the arm overhead) the layers bend in a smooth curve instead of
    folding with it. All layers take the same weights, so they still stay stacked."""
    names = {g.index: g.name for g in o.vertex_groups}
    per = [{names[g.group]: g.weight for g in v.groups if g.weight > 0} for v in o.data.vertices]
    nbr = neighbours(o.data)
    for _ in range(rounds):
        nxt = []
        for i, w in enumerate(per):
            acc = {k: x * 0.5 for k, x in w.items()}
            if nbr[i]:
                share = 0.5 / len(nbr[i])
                for j in nbr[i]:
                    for k, x in per[j].items():
                        acc[k] = acc.get(k, 0.0) + x * share
            nxt.append(acc)
        per = nxt
    o.vertex_groups.clear()
    groups = {}
    for i, w in enumerate(per):
        best = sorted(w.items(), key=lambda kv: -kv[1])[:4]
        s_ = sum(x for _b, x in best) or 1.0
        for b_, x in best:
            g = groups.get(b_) or o.vertex_groups.new(name=b_)
            groups[b_] = g
            g.add([i], x / s_, "REPLACE")


def neighbours(me):
    nbr = [set() for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        nbr[a].add(b)
        nbr[b].add(a)
    return nbr


def layer_lines(skin):
    """Per skin point: the line every layer's point i sits on (its direction: the smoothed skin's normal) and how far
    out the smoothed skin is along it (the grooves to bridge). Taubin smoothing keeps the size (no shrinking)."""
    me = skin.data
    nbr = neighbours(me)
    P = np.array([v.co[:] for v in me.vertices])
    S = P.copy()
    for _ in range(SMOOTH_ROUNDS):
        for lam in (0.55, -0.58):
            avg = np.array([S[list(n)].mean(axis=0) if n else S[i] for i, n in enumerate(nbr)])
            S = S + lam * (avg - S)
    tmp = me.copy()
    for v, s in zip(tmp.vertices, S):
        v.co = s.tolist()
    tmp.update()
    N = np.array([v.normal[:] for v in tmp.vertices])
    bpy.data.meshes.remove(tmp)
    N /= np.maximum(np.linalg.norm(N, axis=1), 1e-9)[:, None]
    fill = np.maximum(0.0, ((S - P) * N).sum(axis=1))
    # more room round the shoulder joints: with the arm overhead the skin folds there (the deltoid rolls into the
    # trapezius) and a fold of up to ~0.04 came out through the tee; every layer stands out with it, so they stay
    # stacked
    if SHOULDER_ROOM:
        rig_bones = SKIN_JOINTS[0]
        for side in ("Left", "Right"):
            j = np.array(rig_bones[side + "UpperArm"])
            d = np.linalg.norm(P - j, axis=1)
            t = np.clip(1.0 - (d - SHOULDER_REACH[0]) / (SHOULDER_REACH[1] - SHOULDER_REACH[0]), 0.0, 1.0)
            fill = fill + SHOULDER_ROOM * t * t * (3 - 2 * t)
    # even the bridging out a little (a gentle span, never a dent): each point at least its neighbours' average
    for _ in range(4):
        avg = np.array([fill[list(n)].mean() if n else fill[i] for i, n in enumerate(nbr)])
        fill = np.maximum(fill, 0.85 * avg)
    return P, N, fill


def make_layer(skin, name, out, coll, P, N, fill):
    """A copy of the skin with point i at P_i + N_i * (fill_i + out), the skin's weights, and its line direction kept
    as the point attribute "line" (for the thickness and for the cuts' new points)."""
    o = skin.copy()
    o.data = skin.data.copy()
    o.name = o.data.name = name
    coll.objects.link(o)
    me = o.data
    X = P + N * (fill + out)[:, None]
    for v, x in zip(me.vertices, X):
        v.co = x.tolist()
    attr = me.attributes.new("line", "FLOAT_VECTOR", "POINT")
    for i, n in enumerate(N):
        attr.data[i].vector = n.tolist()
    me.update()
    return o


def clear_of_skin(o, skin, gap, N_attr="line"):
    """Where a layer still comes closer than `gap` to the real skin (a concave fold), its point moves out along its own
    line by the shortfall; returns the largest move (logged: normally zero)."""
    tree = BVHTree.FromPolygons([v.co for v in skin.data.vertices], [tuple(p.vertices) for p in skin.data.polygons])
    attr = o.data.attributes[N_attr]
    worst = 0.0
    for i, v in enumerate(o.data.vertices):
        loc, nrm, _f, d = tree.find_nearest(v.co, 0.5)
        if loc is None:
            continue
        g = d if (v.co - loc).dot(nrm) >= 0 else -d
        if g < gap:
            n = Vector(attr.data[i].vector)
            v.co = v.co + n * (gap - g)
            worst = max(worst, gap - g)
    o.data.update()
    return worst


# ---------------------------------------------------------------- cutting along smooth lines
def _deform_weight(v, dl, groups):
    return sum(w for g, w in v[dl].items() if g in groups) if dl is not None else 0.0


ARM_CUT = "_ArmCut"            # a temporary group: the arm's share, smoothed, for drawing cuts (removed afterwards)


def smoothed_arm_group(o, rounds=6):
    """The arm's share of each point, averaged with its neighbours a few times, as a temporary group. The raw share
    jumps from 0 to 1 at the seam between the arm and torso meshes, and a cut drawn along it at the armpit came out as
    spikes (BigBuff's sleeve underarm 2026-11-16); the smoothed share's lines are smooth curves through the same place."""
    me = o.data
    n = len(me.vertices)
    arm = group_ids(o, ("UpperArm", "LowerArm", "Hand"))
    val = np.array([sum(g.weight for g in v.groups if g.group in arm) for v in me.vertices])
    nb = [[] for _ in range(n)]
    for e in me.edges:
        a_, b_ = e.vertices
        nb[a_].append(b_)
        nb[b_].append(a_)
    for _ in range(rounds):
        val = np.array([(val[i] + sum(val[j] for j in nb[i])) / (1 + len(nb[i])) for i in range(n)])
    g = o.vertex_groups.get(ARM_CUT) or o.vertex_groups.new(name=ARM_CUT)
    for i in range(n):
        g.add([i], float(val[i]), "REPLACE")
    return {g.index}


def drop_arm_group(o):
    g = o.vertex_groups.get(ARM_CUT)
    if g:
        o.vertex_groups.remove(g)


_LINE = [None]                # the bmesh "line" layer of the mesh being cut (for fields that need a point's line)


def line_of(v):
    return Vector(v[_LINE[0]]) if _LINE[0] is not None else Vector((1.0, 0.0, 0.0))


def refine_near(o, fields, band=0.035, rounds=1):
    """Splits the edges lying near any of these lines (each field within `band` of zero at both ends) so a cut line
    across the coarse skin mesh comes out as a smooth curve, not a few long straight pieces. Weights and the line
    attribute are interpolated on the new points."""
    for _ in range(rounds):
        bm = bmesh.new()
        bm.from_mesh(o.data)
        dl = bm.verts.layers.deform.active
        _LINE[0] = bm.verts.layers.float_vector.get("line")
        near = set()
        for v in bm.verts:
            if any(abs(fn(v, dl)) < band for fn in fields):
                near.add(v)
        edges = [e for e in bm.edges if e.verts[0] in near and e.verts[1] in near]
        if edges:
            bmesh.ops.subdivide_edges(bm, edges=edges, cuts=1, use_grid_fill=False)
            bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
        bm.to_mesh(o.data)
        bm.free()
        o.data.update()


def cut_lines(o, fields, store=None):
    """Draws each field's zero line across the mesh (new points exactly where the field crosses zero on an edge, their
    weights and attributes interpolated; the faces split along the line), so later face choices end on clean lines.
    A face the line crosses more than once (a thin strip, a panel's corner) is split at every crossing; a point lying
    on the line already counts as on it. fields: [callable(BMVert, deform_layer) -> float]."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    dl = bm.verts.layers.deform.active
    _LINE[0] = bm.verts.layers.float_vector.get("line")
    names = store if isinstance(store, (list, tuple)) else [None] * (len(fields) - 1) + [store]
    for fn, store_as in zip(fields, names):
        vals = {}
        on = set()
        for v in bm.verts:
            x = fn(v, dl)
            if abs(x) < 1e-6:
                on.add(v)
                x = 0.0
            vals[v] = x
        for e in list(bm.edges):
            a, b = e.verts
            fa, fb = vals[a], vals[b]
            if a in on or b in on or (fa < 0) == (fb < 0):
                continue
            t = fa / (fa - fb)
            if t < 1e-3:
                on.add(a)
                continue
            if t > 1 - 1e-3:
                on.add(b)
                continue
            _ne, nv = bmesh.utils.edge_split(e, a, t)
            vals[nv] = 0.0
            on.add(nv)
        # split every face along the line: between two on-line points whose arc (the points between them round the
        # face) is all on one side, and the rest on the other
        for _round in range(4):
            changed = False
            for f in list(bm.faces):
                if not f.is_valid:
                    continue
                vs = list(f.verts)
                n = len(vs)
                idx = [i for i, v in enumerate(vs) if v in on]
                if len(idx) < 2:
                    continue
                done = False
                for k in range(len(idx)):
                    i, j = idx[k], idx[(k + 1) % len(idx)]
                    arc = [vs[(i + d) % n] for d in range(1, (j - i) % n)]
                    rest = [vs[(j + d) % n] for d in range(1, (i - j) % n)]
                    if not arc or not rest:
                        continue
                    sa = {vals[v] < 0 for v in arc if v not in on}
                    sr = {vals[v] < 0 for v in rest if v not in on}
                    if len(sa) == 1 and len(sr) == 1 and sa != sr:
                        try:
                            bmesh.utils.face_split(f, vs[i], vs[j])
                            changed = done = True
                        except ValueError:
                            pass
                        break
                    if len(sa) == 1 and len(sr) == 2:
                        try:
                            bmesh.utils.face_split(f, vs[i], vs[j])
                            changed = done = True
                        except ValueError:
                            pass
                        break
                if done:
                    continue
            if not changed:
                break
        if store_as:
            # the field's values as the cut used them (0 on the line): colour choices made from these fall exactly on
            # the cut, where the value recomputed at a face's middle or new points can disagree. (Written before the
            # triangulation: after it the points no longer match as dictionary keys.)
            got = [vals[v] for v in bm.verts]
            lay = bm.verts.layers.float.get(store_as) or bm.verts.layers.float.new(store_as)
            for v, x in zip(bm.verts, got):
                v[lay] = x
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()


def keep_faces(o, keep, with_line=False, with_verts=False):
    """Deletes the faces whose centre fails keep(centre, mean bone weights by name); drops loose points."""
    me = o.data
    names = {g.index: g.name for g in o.vertex_groups}
    bm = bmesh.new()
    bm.from_mesh(me)
    dl = bm.verts.layers.deform.active
    ll = bm.verts.layers.float_vector.get("line")
    gone = []
    for f in bm.faces:
        c = f.calc_center_median()
        line = sum((Vector(v[ll]) for v in f.verts), Vector()) if (with_line and ll is not None) else None
        w = {}
        for v in f.verts:
            for g, x in (v[dl].items() if dl is not None else []):
                n = names.get(g)
                if n:
                    w[n] = w.get(n, 0.0) + x / len(f.verts)
        if with_verts:
            ok = keep(c, w, [v.index for v in f.verts])
        else:
            ok = keep(c, w, line) if with_line else keep(c, w)
        if not ok:
            gone.append(f)
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    me.update()


def rim_segments(o, which):
    """The garment's open edges (as segments) whose middle passes which(point)."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    segs = []
    for e in bm.edges:
        if e.is_boundary:
            a, b = e.verts[0].co.copy(), e.verts[1].co.copy()
            if which((a + b) / 2):
                segs.append((a, b))
    bm.free()
    from mathutils.kdtree import KDTree
    kd = KDTree(max(1, len(segs)))
    for i, (a, b) in enumerate(segs):
        kd.insert((a + b) / 2, i)
    kd.balance()
    # the search reaches half the longest segment further: segments are found by their middles, and a long straight
    # edge's points far from its middle were missed (the trim came out as teeth along BigBuff's strap, 2026-11-16)
    half = max([(a - b).length / 2 for a, b in segs] or [0.0])
    return segs, kd, half


def dist_to_segments(p, rim, reach=0.25):
    from mathutils.geometry import intersect_point_line
    segs, kd, half = rim
    best = 9.0
    for _co, i, _d in kd.find_range(p, reach + half):
        a, b = segs[i]
        q, t = intersect_point_line(p, a, b)
        q = a if t < 0 else b if t > 1 else q
        best = min(best, (p - q).length)
    return best


def drop_trim_strips(o):
    """Drops the trim faces lying further than TRIM_STRIP_FAR from any red / black face: a part of the singlet narrower
    than two trim widths is all trim and reads as a loose string (the thin builds' armpits, 2026-11-16)."""
    from mathutils.kdtree import KDTree
    me = o.data
    keys = list(o["keys"])
    body = {i for p, k in zip(me.polygons, keys) if k in ("Red", "Black") for i in p.vertices}
    if not body:
        return 0
    kd = KDTree(len(body))
    for n, i in enumerate(body):
        kd.insert(me.vertices[i].co, n)
    kd.balance()
    gone = {p.index for p, k in zip(me.polygons, keys) if k == "Trim" and kd.find(p.center)[2] > TRIM_STRIP_FAR}
    if not gone:
        return 0
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in gone], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    me.update()
    o["keys"] = [k for i, k in enumerate(keys) if i not in gone]
    assert len(o["keys"]) == len(me.polygons)
    return len(gone)


def keep_largest(o):
    """Keeps only the biggest connected piece (a garment is one piece; an arm hanging below a cut is a loose one)."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    seen, comps = set(), []
    for f in bm.faces:
        if f in seen:
            continue
        comp, stack = [], [f]
        seen.add(f)
        while stack:
            g = stack.pop()
            comp.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen:
                        seen.add(h)
                        stack.append(h)
        comps.append(comp)
    comps.sort(key=len, reverse=True)
    gone = [f for comp in comps[1:] for f in comp]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()
    return len(comps) - 1


def fill_pinholes(o, max_edges=10):
    """A face lost while cutting leaves a pinhole (a boundary loop of a few edges); it is filled (its corners keep their
    weights; the new face takes its neighbour's key later). Returns how many were filled."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    loops, seen = [], set()
    for e in bm.edges:
        if not e.is_boundary or e in seen:
            continue
        loop, cur, v = [], e, e.verts[0]
        while cur is not None and cur not in seen:
            seen.add(cur)
            loop.append(cur)
            v = cur.other_vert(v)
            cur = next((x for x in v.link_edges if x.is_boundary and x not in seen), None)
        loops.append(loop)
    small = [lp for lp in loops if len(lp) <= max_edges]
    for lp in small:
        try:
            bmesh.ops.holes_fill(bm, edges=lp, sides=max_edges)
        except Exception:
            pass
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()
    return len(small)


def share(w, suffixes):
    return sum(x for n, x in w.items() if n.endswith(suffixes))


def group_ids(o, suffixes):
    return {g.index for g in o.vertex_groups if g.name.endswith(suffixes)}


def face_keys(o, key_of, with_verts=False):
    names = {g.index: g.name for g in o.vertex_groups}
    me = o.data
    keys = []
    for p in me.polygons:
        w = {}
        for vi in p.vertices:
            for g in me.vertices[vi].groups:
                n = names.get(g.group)
                if n:
                    w[n] = w.get(n, 0.0) + g.weight / len(p.vertices)
        keys.append(key_of(p.center, w, list(p.vertices)) if with_verts else key_of(p.center, w))
    o["keys"] = keys


# ---------------------------------------------------------------- thickness along the lines
def thicken_stacked(o, thick, edge_key=None, outward=False, keep_inside="edge"):
    """Real thickness ALONG EACH POINT'S LINE (not along the face normals: the inside can't cross the layer under it):
    an inside copy `thick` in (or out, `outward`), and a rim round every opening. keep_inside: "edge" keeps only the
    inside row along the openings (the rest is hidden under the outside), "all" keeps it all (a belt). Keys: the
    outside keeps its own; the rim and the inside row take edge_key(centre, own key) if given."""
    me = o.data
    keys = list(o["keys"])
    attr = me.attributes["line"]
    lines = [Vector(attr.data[i].vector) for i in range(len(me.vertices))]
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    edge_v = {v.index for v in bm.verts if v.is_boundary}
    sign = 1.0 if outward else -1.0
    copy = {}
    for v in list(bm.verts):
        nv = bm.verts.new(v.co + lines[v.index] * (thick * sign), v)
        copy[v] = nv
    new_keys = []
    outer_faces = list(bm.faces)
    for f, k in zip(outer_faces, keys):
        new_keys.append(k)
    inner = []
    for i, (f, k) in enumerate(zip(outer_faces, keys)):
        on_edge = any(v.index in edge_v for v in f.verts)
        if keep_inside == "all" or on_edge:
            nf = bm.faces.new([copy[v] for v in reversed(f.verts)], f)
            if outward:
                # the copy is the OUTSIDE (it keeps the colour), the original becomes the inside (the lining)
                inner.append((nf, k))
                if edge_key:
                    new_keys[i] = edge_key(f.calc_center_median(), k)
            else:
                inner.append((nf, edge_key(f.calc_center_median(), k) if (edge_key and on_edge) else k))
    rims = []
    for e in [e for e in bm.edges if e.is_boundary and e.verts[0] in copy and e.verts[1] in copy]:
        f = e.link_faces[0]
        a, b = e.verts
        # the outside face runs a->b along its own winding: the rim goes b->a->a'->b' so it faces out of the opening
        loop = next(l for l in f.loops if l.edge == e)
        if loop.vert != a:
            a, b = b, a
        quad = [b, a, copy[a], copy[b]]
        try:
            nf = bm.faces.new(quad, f)
        except ValueError:
            continue
        k0 = keys[outer_faces.index(f)] if f in outer_faces else keys[0]
        rims.append((nf, edge_key(nf.calc_center_median(), k0) if edge_key else k0))
    if outward:
        # the outside of an outward-thick layer is the copy: flip the original to face in, the copy faces out
        for f in outer_faces:
            f.normal_flip()
        for nf, _k in inner:
            nf.normal_flip()
        for nf, _k in rims:
            nf.normal_flip()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    order = list(bm.faces)
    keymap = {}
    for f, k in zip(outer_faces, new_keys):
        keymap[f] = k
    for nf, k in inner + rims:
        keymap[nf] = k
    bm.to_mesh(me)
    o["keys"] = [keymap.get(f, keys[0]) for f in order]
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.update()


# ---------------------------------------------------------------- the garments
def tee_lines(H, body):
    neck_z = H["neck"]
    cx, cy, rx, ry = W["NECK"]
    sleeve = H["sleeve"]
    # the sleeve's hem SLANTS: at the approved height on the outside of the arm, down to below the armpit on the
    # inside (a level hem at mid upper arm was ABOVE the armpit on the inside: raising the arm bared the armpit)
    low = min(sleeve, H["m"]["armpit"] - 0.12)
    sh, el = body.joints["LeftUpperArm"], body.joints["LeftLowerArm"]

    def arm_x(z):                                   # the upper arm's centre line (rest), |x| at height z
        t = (sh.z - z) / max(1e-6, sh.z - el.z)
        return abs(sh.x + (el.x - sh.x) * t)
    r = 0.24

    def hem(c, up=0.0):
        inner = min(1.0, max(0.0, (arm_x(c.z) + r - abs(c.x)) / (2 * r)))   # 0 outside of the arm .. 1 inside
        return sleeve + up - (sleeve - low) * inner * inner * (3 - 2 * inner)

    def ell(c):
        return math.sqrt(((c.x - cx) / rx) ** 2 + ((c.y - cy) / ry) ** 2) - 1.0
    z_low = L["SH"] - 0.2

    def neck(c):
        # the crew neck: the ellipse round the neck, from a low floor so the floor never meets the body (a hard
        # corner there left a V at the front), the two blended (soft maximum)
        a1, a2, k = ell(c), (z_low - c.z) * 3.0, 0.06
        m = max(a1, a2)
        return m + k * math.log(math.exp((a1 - m) / k) + math.exp((a2 - m) / k))
    return dict(hem=H["hem"], sleeve=sleeve, sleeve_at=hem, cuff=0.13, neck_z=neck_z, ell=ell, neck=neck)


def build_tee(skin, P, N, fill, H, coll, build, body):
    t = tee_lines(H, body)
    o = make_layer(skin, build + "_Tee06", TEE_OUT, coll, P, N, fill)
    log(build, "Tee", "skin fold pushed out up to %.3f" % clear_of_skin(o, skin, TEE_OUT * 0.8))
    arm_g = smoothed_arm_group(o)
    leg_g = group_ids(o, ("UpperLeg", "LowerLeg", "Foot"))
    refine_near(o, [lambda v, dl: t["neck"](v.co) * 0.5,
                    lambda v, dl: max(v.co.z - t["sleeve_at"](v.co), 0.5 - _deform_weight(v, dl, arm_g))])
    cut_lines(o, [
        lambda v, dl: max(v.co.z - t["hem"], _deform_weight(v, dl, arm_g) - 0.5),          # the hem (not the arms)
        lambda v, dl: max(v.co.z - t["sleeve_at"](v.co), 0.5 - _deform_weight(v, dl, arm_g)),          # sleeve ends
        lambda v, dl: max(v.co.z - t["sleeve_at"](v.co, t["cuff"]), 0.5 - _deform_weight(v, dl, arm_g)),  # cuffs' top
        lambda v, dl: t["neck"](v.co),                                                       # the crew neck
    ], store=["hem_at", "sleeve_end_at", "cuff_at", "neck_at"])
    # (faces kept and coloured by the values the cuts were drawn from, as on the singlet: judged at a face's middle,
    # BigBuff's sleeve underside came out with teeth of cuff colour, 2026-11-16)
    me = o.data
    at = {}
    for name in ("hem_at", "sleeve_end_at", "cuff_at", "neck_at"):
        lay = me.attributes[name]
        at[name] = [lay.data[i].value for i in range(len(me.vertices))]
    mean = lambda name, verts: sum(at[name][i] for i in verts) / len(verts)
    keep_faces(o, lambda c, w, verts: mean("hem_at", verts) > 0 and share(w, ("UpperLeg", "LowerLeg", "Foot")) < 0.5
               and mean("sleeve_end_at", verts) > 0 and mean("neck_at", verts) > 0, with_verts=True)
    log(build, "Tee", "pinholes filled:", fill_pinholes(o))
    me = o.data
    lay = me.attributes["cuff_at"]
    cuff_at = [lay.data[i].value for i in range(len(me.vertices))]
    for name in ("hem_at", "sleeve_end_at", "cuff_at", "neck_at"):
        me.attributes.remove(me.attributes[name])
    face_keys(o, lambda c, w, verts: "TeeWhite" if sum(cuff_at[i] for i in verts) / len(verts) < 0 else "Tee",
              with_verts=True)
    drop_arm_group(o)
    return o


def singlet_lines(body, shell, H, skin):
    m = H["m"]
    xi = V["HEAD_HALF"] + 0.06                                        # straps clear of the head (v4)
    xo = min(xi + 0.28, shell.arm_inner_x(L["SH"] - 0.45) - 0.04)     # and inside the arm (v4)
    z_cap = L["N"] + 0.6
    z_nf, z_nb = L["SH"] - 0.52, L["SH"] - 0.28                       # deep front scoop, shallower back U (v4)
    # the armhole's bottom: v4's, 0.1 lower (out of the armpit crease, where a raised arm squashes everything)
    z_ah = min(m["armpit"], L["SH"] - 0.5) - 0.32
    z_st = L["SH"] + 0.05
    # the armhole curves down from the strap's outer edge to its bottom at the side of the TORSO (v4's 0.45 reached past
    # the torso on the body mesh: a shallow armhole)
    # (torso points only: a thin build's hanging arm is within reach at that height, and counting it put the armhole's
    # bottom out past the arm, leaving a thin strip of singlet down the side, Skinny 2026-11-16)
    arm_ids = group_ids(skin, ("UpperArm", "LowerArm", "Hand"))
    torso_x = max(abs(v.co.x) for v in skin.data.vertices if abs(v.co.z - z_ah) < 0.06 and abs(v.co.x) < 1.15
                  and sum(g.weight for g in v.groups if g.group in arm_ids) < 0.5)
    w_ah = max(0.08, torso_x - xo)
    # THIN builds (the torso narrower than the strap's outer edge): the armhole above lies wholly over the arm and the
    # singlet covered the torso's whole side up to the arm, its trim reading as a string hanging down between arm and
    # body (Skinny / SkinnyFat 2026-11-16). They get the armhole a real singlet has there: an oval opening in the
    # torso's SIDE (seen from the side: from the armhole's bottom up to the shoulder, round the arm's root).
    side_oval = None
    if torso_x < xo - SIDE_OVAL_FROM:
        pit = m["armpit"]
        ys = [v.co.y for v in skin.data.vertices if abs(v.co.z - pit) < 0.06 and abs(v.co.x) < 1.15
              and sum(g.weight for g in v.groups if g.group in arm_ids) < 0.5]
        y_c = (max(ys) + min(ys)) / 2
        ry = (max(ys) - min(ys)) / 2 * SIDE_OVAL_DEPTH
        z_lo, z_hi = z_ah, L["SH"] + 0.1
        side_oval = dict(y=y_c, ry=ry, z=(z_lo + z_hi) / 2, rz=(z_hi - z_lo) / 2)
        log("", "armhole: thin build, side opening", {k: round(v, 3) for k, v in side_oval.items()})
    smooth = W["P"]["smoothstep"]

    z_top = L["SH"] + 0.05

    def centre(c):
        # the scoop rises to z_top exactly at the strap's inner edge (|x| = xi), so it runs straight into the strap's
        # edge; above z_top everything inside the straps is neckline (capping a curve that went on up left a step)
        s = abs(c.x)
        back = smooth(-0.15, 0.15, np.array([c.y]))[0]
        z_n = z_nf + (z_nb - z_nf) * back
        return z_n + (z_top - z_n) * min(1.0, s / xi) ** 3

    def side(c):
        s = abs(c.x)
        t = min(1.0, max(0.0, (s - xo) / w_ah))
        return z_ah + (z_st - z_ah) * (1 - math.sqrt(max(0.0, 1 - (1 - t) ** 2)))
    return dict(xi=xi, xo=xo, z_ah=z_ah, z_st=z_st, centre=centre, side=side, leg_hem=H["leg_hem"], side_oval=side_oval,
                strap_red_front=L["SH"] - 0.45, strap_red_back=L["SH"] - 0.14, side_cut=math.radians(19),
                panel_low=L["HJ"] + 0.25)


def build_singlet(tee_layer_src, skin, P, N, fill, H, s, coll, build):
    o = make_layer(skin, build + "_WornSinglet06", TEE_OUT + SINGLET_OUT, coll, P, N, fill)
    log(build, "Singlet", "skin fold pushed out up to %.3f" % clear_of_skin(o, skin, (TEE_OUT + SINGLET_OUT) * 0.8))
    arm_g = group_ids(o, ("UpperArm", "LowerArm", "Hand"))
    arm_s = smoothed_arm_group(o)
    leg_g = group_ids(o, ("UpperLeg", "LowerLeg", "Foot"))
    xi, xo = s["xi"], s["xo"]
    sc = s["side_cut"]
    zst = s["z_st"]

    def armhole(c, arm, arm_smooth):
        # ONE armhole: off above the side curve OR where the arm has much of the point, blended (a soft minimum) so no
        # thin strip of singlet is left between the two (it folded into a loop at the armpit)
        a1 = s["side"](c) - c.z
        # below the armhole only the arm's own skin is cut (weight ~1): the torso's side there carries some arm
        # weight too, and cutting at ARM_OFF holed it (Skinny / SkinnyFat 2026-11-16)
        # There the arm's share is the SMOOTHED one: the raw share steps 0 -> 1 across the seam between the arm and
        # torso meshes and left a one-face strip of singlet hanging down the thin builds' armpits.
        low = min(1.0, max(0.0, (s["z_ah"] - c.z) / 0.1))
        arm = arm * (1 - low) + arm_smooth * low
        a2 = (ARM_OFF + (ARM_LOW_OFF - ARM_OFF) * low - arm) * 0.35   # (weight -> about studs: ~3 per stud there)
        k = 0.04
        return -k * math.log(math.exp(-a1 / k) + math.exp(-a2 / k))

    def red_strap(c):
        # (the accent starts a little INSIDE the strap's inner edge: the scoop meets the strap a touch inside xi, and
        # starting the red at xi left a thin black wedge between the trim and the red at the corner)
        zr = s["strap_red_front"] if c.y < 0 else s["strap_red_back"]
        return min(abs(c.x) - (xi - RED_IN), xo - abs(c.x), c.z - zr)

    def side_panel(c):
        return min(sc - math.atan2(abs(c.y), abs(c.x)), c.z - s["panel_low"])

    def side_keep(c, line):
        # > 0 = kept by the thin builds' side opening: outside the oval, or more than SIDE_OVAL_FACING round from the
        # side. (Tried: judging the facing by the surface's direction: its noise left jagged edges on the back.)
        so = s["side_oval"]
        if so is None:
            return 1.0
        ry = so["ry"] * (SIDE_OVAL_BACK if c.y > so["y"] else 1.0)
        inside = 1.0 - ((c.y - so["y"]) / ry) ** 2 - ((c.z - so["z"]) / so["rz"]) ** 2
        facing = math.degrees(math.atan2(abs(c.y - so["y"]), abs(c.x))) - SIDE_OVAL_FACING
        return max(-inside * 0.3, facing * 0.01)

    def strap_guard(c):
        # the strap over the shoulder (inside xo) is never cut by the arm term... but only up there: below the armhole
        # a thin build's hanging arm is inside xo too, and the singlet ran down the inner arm (Skinny 2026-11-16)
        return xo - abs(c.x) - 10.0 * max(0.0, s["z_ah"] - c.z)
    refine_near(o, [lambda v, dl: max(s["centre"](v.co) - v.co.z, abs(v.co.x) - xi),
                    lambda v, dl: max(s["side"](v.co) - v.co.z, xo - abs(v.co.x))]
                + ([lambda v, dl: side_keep(v.co, line_of(v))] if s["side_oval"] else []))
    cut_lines(o, [
        lambda v, dl: v.co.z - s["leg_hem"],                                                   # the leg hems
        lambda v, dl: max(s["centre"](v.co) - v.co.z, abs(v.co.x) - xi),                       # the scoop / back U
        lambda v, dl: min(max(armhole(v.co, _deform_weight(v, dl, arm_g), _deform_weight(v, dl, arm_s)),
                              strap_guard(v.co)), side_keep(v.co, line_of(v))),                # the armholes
        lambda v, dl: _deform_weight(v, dl, leg_g) - 0.5,                                      # the shorts' line
        lambda v, dl: red_strap(v.co),                                                         # the straps' accent
        lambda v, dl: side_panel(v.co),                                                        # the side panels
    ], store=[None, None, None, None, "red_at", "panel_at"])

    def kept(c, w, line):
        sx = abs(c.x)
        if c.z < s["leg_hem"]:
            return False
        if share(w, ("LowerLeg", "Foot")) > 0.5:
            return False
        if sx < xi and c.z > s["centre"](c):
            return False
        if strap_guard(c) < 0 and armhole(c, share(w, ("UpperArm", "LowerArm", "Hand")), w.get(ARM_CUT, 0.0)) < 0:
            return False
        if side_keep(c, line) < 0:
            return False
        return True
    keep_faces(o, kept, with_line=True)
    log(build, "Singlet", "loose pieces dropped (the arms below the armholes):", keep_largest(o))
    log(build, "Singlet", "pinholes filled:", fill_pinholes(o))

    # the bound edge: a band TRIM wide along every opening but the leg hems, its inner line drawn at an even distance
    # from the real edge (separate lines per edge met at the strap corners and left notches)
    rim = rim_segments(o, lambda p: p.z > s["z_ah"] - 0.3)            # the neck and armholes (not the leg hems)
    cut_lines(o, [lambda v, dl: dist_to_segments(v.co, rim) - TRIM], store="trim_at")

    # a face is trim when its POINTS are on average inside the trim line, by the values the cut was drawn from;
    # deciding by the distance recomputed at the face's middle left teeth of trim / notches of red along BigBuff's
    # strap edge (2026-11-16)
    def stored(name):
        lay = o.data.attributes[name]
        got = [lay.data[i].value for i in range(len(o.data.vertices))]
        o.data.attributes.remove(o.data.attributes[name])
        return got
    trim_at, red_at, panel_at = stored("trim_at"), stored("red_at"), stored("panel_at")
    mean = lambda vals, verts: sum(vals[i] for i in verts) / len(verts)

    def key(c, w, verts):
        sx = abs(c.x)
        if share(w, ("UpperLeg", "LowerLeg")) > 0.5:
            return "Shorts"
        if mean(trim_at, verts) < 0:
            return "Trim"
        # (the accent colours likewise from the values their cuts were drawn from: by the face's middle they came out
        # in steps and notches on the thin builds' side panels)
        if mean(red_at, verts) > 0 or (mean(panel_at, verts) > 0 and share(w, ("UpperLeg",)) < 0.5):
            return "Red"
        return "Black"
    face_keys(o, key, with_verts=True)
    log(build, "Singlet", "trim-only strips dropped:", drop_trim_strips(o))
    drop_arm_group(o)
    return o


def belt_shortfall(belt_pieces, singlet_parts, body):
    """How far the singlet's points within the belt's height stand OUTSIDE the belt's inside (rays out from the belt's
    axis: the first belt face met is its inside), at rest; > 0 = the belt must stand off that much more."""
    mid, axis = V["belt_shape"](body)[:2]
    verts, faces = [], []
    for o in belt_pieces.values():
        base = len(verts)
        verts += [o.matrix_world @ v.co for v in o.data.vertices]
        faces += [tuple(base + i for i in p.vertices) for p in o.data.polygons]
    tree = BVHTree.FromPolygons(verts, faces)
    rig = body.rig
    worst = -9.0
    for o in singlet_parts:
        m = o.matrix_world
        for v in o.data.vertices:
            p = m @ v.co
            h = p.z - (rig.matrix_world @ Vector((0, 0, mid))).z
            if abs(h) > 0.24:
                continue
            c = rig.matrix_world @ Vector((axis.x, axis.y, mid + h))
            d = Vector((p.x - c.x, p.y - c.y, 0.0))
            if d.length < 1e-6:
                continue
            hit = tree.ray_cast(c, d.normalized(), 3.0)
            if hit[0] is None:
                continue
            worst = max(worst, d.length - hit[3])
    return worst


def copy_weights_nearest(dst, src):
    tree = BVHTree.FromPolygons([v.co for v in src.data.vertices], [tuple(p.vertices) for p in src.data.polygons])
    names = {g.index: g.name for g in src.vertex_groups}
    sw = [{names[g.group]: g.weight for g in v.groups} for v in src.data.vertices]
    dst.vertex_groups.clear()
    groups = {}
    for v in dst.data.vertices:
        loc, _n, fi, _d = tree.find_nearest(v.co)
        face = src.data.polygons[fi].vertices
        acc = {}
        for j in face:
            for b, x in sw[j].items():
                acc[b] = acc.get(b, 0.0) + x / len(face)
        s = sum(acc.values()) or 1.0
        for b, x in acc.items():
            g = groups.get(b) or dst.vertex_groups.new(name=b)
            groups[b] = g
            g.add([v.index], x / s, "REPLACE")


def materials(pieces, worn):
    for key, p in pieces.items():
        p.data.materials.clear()
        p.data.materials.append(V["material"](worn, key))


def to_parts(pieces, prefix_of, body, coll):
    made = []
    for key, o in pieces.items():
        made += F["split_parts"](o, prefix_of(key), body, coll, material=o.data.materials[0] if o.data.materials else None)
    return made


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


# ---------------------------------------------------------------- per build
coll = bpy.data.collections.get(COLLECTION) or bpy.data.collections.new(COLLECTION)
if coll.name not in bpy.context.scene.collection.children:
    bpy.context.scene.collection.children.link(coll)
for o in list(coll.objects):
    bpy.data.objects.remove(o, do_unlink=True)
RESULT = {}
for b in BUILDS:
    body = F["Body"](b)
    H = W["heights"](body)
    shell = W["Shell"](B5["body_spec"](b), H["arm_from"])
    skin = joined_skin(b, coll)
    SKIN_JOINTS[0] = {k: tuple(v) for k, v in body.joints.items()}
    # (Tried 2026-11-15: holding the layers by the hips under the belt, as v5 did. With the legs held too the body
    # bent out through the tee at the hips (0.08) and red/black patches showed under the belt; with the legs left
    # alone it changed nothing. Close-ups showed the plain rigid belt clean in the deep squat and deadlift, so the
    # layers just follow the skin.)
    P, N, fill = layer_lines(skin)
    log(b, "skin", len(skin.data.vertices), "points; grooves bridged up to %.3f" % float(fill.max()))
    made = {}
    tee = build_tee(skin, P, N, fill, H, coll, b, body)
    thicken_stacked(tee, FABRIC)
    log(b, "Tee", tris(tee), "triangles")
    pieces = V["split_keys"](tee, coll, b + "_Tee")
    materials(pieces, "Tee")
    made["Tee"] = to_parts(pieces, lambda k: k, body, coll)

    s_lines = singlet_lines(body, shell, H, skin)
    singlet = build_singlet(None, skin, P, N, fill, H, s_lines, coll, b)
    edge = lambda c, k: "Shorts" if k == "Shorts" else "Trim"
    thicken_stacked(singlet, FABRIC, edge_key=edge)
    log(b, "Singlet", tris(singlet), "triangles")
    sp = V["split_keys"](singlet, coll, b + "_WornSinglet")
    z_nf = L["SH"] - 0.52
    target = sp.get("Black") or next(iter(sp.values()))
    front = V["front_patch"](body, coll, target, b + "_Singlet06Patch", z_nf - 0.24, 0.46, 0.12, "Red")
    back = V["front_patch"](body, coll, target, b + "_Singlet06BackText", L["SH"] - 0.95, 0.62, 0.15, "Red", side="back")
    bpy.ops.object.select_all(action="DESELECT")
    front.select_set(True)
    back.select_set(True)
    bpy.context.view_layer.objects.active = front
    bpy.ops.object.join()
    copy_weights_nearest(front, target)
    sp["Patch"] = front
    materials(sp, "WornSinglet")
    made["WornSinglet"] = to_parts(sp, lambda k: "WornSinglet_" + k, body, coll)

    # --- the belt: the APPROVED rigid lever belt (v4/v5: a straight stiff band at the navel, held by the hips), user
    # 2026-11-16 on the layered belt: "I liked the original way the belt was made ... its okay if the somthing phases
    # through the belt a little bit as long as the belt is not curving and doing weird waves". Only its room over the
    # body is set here: as little as clears the singlet standing (the layered belt's gap was "way too big").
    singlet_parts = made["WornSinglet"]
    clear = BELT_CLEAR_START
    for attempt in range(4):
        V["BELT_CLEAR"] = clear
        bp = V["build_belt"](body, coll)
        short = belt_shortfall(bp, singlet_parts, body)
        log(b, "Belt", "room over the body %.3f: singlet up to %.3f inside it" % (clear, max(0.0, short)))
        if short <= 0 or attempt == 3:
            break
        for o in bp.values():
            bpy.data.objects.remove(o, do_unlink=True)
        clear += short + BELT_MARGIN
    made["WornLeverBelt"] = to_parts(bp, lambda k: "WornLeverBelt_" + k, body, coll)
    bpy.data.objects.remove(skin, do_unlink=True)
    RESULT[b] = made
    log(b, "TRIANGLES", {k: sum(tris(p) for p in v) for k, v in made.items()})

keep = {p.name for made in RESULT.values() for v in made.values() for p in v}
for o in list(coll.objects):
    if o.name not in keep:
        bpy.data.objects.remove(o, do_unlink=True)
# the v5 gear in the source file (CartoonBodies_05_Rigged has none; CartoonGear_05 would) stays out of this file
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
log("saved", OUT_BLEND, len(keep), "pieces")
