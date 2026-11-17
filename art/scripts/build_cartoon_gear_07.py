# Gear v7: the SINGLET re-designed from the user's reference (SBD singlet over a tee, user 2026-11-15 after the v6
# Studio test: "tears, and rough edged ... does not even cover the bottom crotch area ... a big hole in the middle of the
# chest ... you can see how theres room to fit the arms, WHILE being up higher being right by the armpits ... no tears,
# no rigid rough edges ... the line [where the strap changes colour] goes too far down. with a visible corner piece").
# The tee and the rigid belt are v6's (build_cartoon_gear_06.py is loaded as a library; v6 itself is unchanged).
#
# The reference, item by item:
#   - neck: a round scoop just below the tee's crew collar (the tee's collar shows above it), back a little higher;
#   - straps: the singlet's own colour, a thin piping (Trim) along both edges, NO colour block on the strap;
#   - armhole: high, its bottom just under the armpit, one smooth curve round the arm with room for it;
#   - side panel (Red): from the armhole's bottom down the side to the hip, ending in a round;
#   - shorts: the crotch covered; the leg hems a level ring round each thigh;
#   - every edge and colour line ONE smooth curve, its piping an even band (no corners, steps or teeth).
# How: each edge is the zero line of ONE smooth field, scaled to read as distance along the surface (its value over
# its gradient along the surface), so the piping's inner line (the same field at TRIM) runs parallel to the edge.
#   neck     a superellipse in the front view (round bottom, its sides turning straight up into the straps' inner
#            edges at the shoulder: no corner where the scoop meets the strap)
#   armhole  an elliptic cylinder along the arm (seen from the side: an oval round the arm's root from just under the
#            armpit up to the shoulder at the strap's outer edge). It cuts the torso's side under the arm on every
#            build (thin or wide); the arm, cut off by it, is dropped as a loose piece.
#   legs     a level hem, dipping smoothly at the inseam so the crotch stays covered.
# Faces are kept and coloured by the values each cut was drawn from (cut_lines store=...).
#   blender -b art/blender/CartoonBodies_05_Rigged.blend --python art/scripts/build_cartoon_gear_07.py
# Env: GEAR07_BUILDS (default Fit), GEAR07_OUT (default art/blender/CartoonGear_07_Proto.blend).
import math
import os

import bpy
from mathutils import Vector

ROOT = r"D:\Powerlifting Roblox"
os.environ["GEAR06_BUILDS"] = ""
_src = open(os.path.join(ROOT, "art", "scripts", "build_cartoon_gear_06.py")).read()
_src = _src.split("\ncoll = bpy.data.collections.get(COLLECTION)")[0]
G6 = {"__name__": "gear06_lib"}
exec(_src, G6)
globals().update({k: v for k, v in G6.items() if not k.startswith("__")})

# (prototype, user 2026-11-17 via the redesign session) the tee sleeve's hem ends this much HIGHER on the underside of
# the arm only (the outside keeps its length, like a real tee's underarm seam): standing, the cuff's underside tucked
# into the crease between arm and body and showed as points beside the singlet's edge. 0 = v6's hem.
SLEEVE_UNDER_UP = float(os.environ.get("GEAR07_SLEEVE_UNDER_UP", "0"))
_tee_lines6 = G6["tee_lines"]


def tee_lines7(H, body):
    t = _tee_lines6(H, body)
    if SLEEVE_UNDER_UP <= 0:
        return t
    sleeve = H["sleeve"]
    low = min(sleeve, H["m"]["armpit"] - 0.12 + SLEEVE_UNDER_UP)
    sh, el = body.joints["LeftUpperArm"], body.joints["LeftLowerArm"]

    def arm_x(z):
        k = (sh.z - z) / max(1e-6, sh.z - el.z)
        return abs(sh.x + (el.x - sh.x) * k)
    r = 0.24

    def hem(c, up=0.0):                     # v6's slanted hem, its inside end raised
        inner = min(1.0, max(0.0, (arm_x(c.z) + r - abs(c.x)) / (2 * r)))
        return sleeve + up - (sleeve - low) * inner * inner * (3 - 2 * inner)
    t["sleeve_at"] = hem
    return t


G6["tee_lines"] = tee_lines7

OUT_BLEND = os.environ.get("GEAR07_OUT") or os.path.join(ROOT, "art", "blender", "CartoonGear_07_Proto.blend")
BUILDS = tuple(b for b in os.environ.get("GEAR07_BUILDS", "Fit").split(",") if b)
COLLECTION = "CartoonGear07"

# --- the singlet's shape (studs; SH = the shoulder joints' height)
# The neck (user 2026-11-16, Studio, with the SBD reference: "the chest and back area seems overexposed ... you made the
# model seem like a straight line across the chest, instead of a oval like"): a rounded U on the front and the back, its
# sides running up into the straps' inner edges in one curve. (Was a squarish superellipse 0.34 deep, power 2.4, three
# times as wide as deep: a flat line across the chest with square corners, too much tee showing.)
NECK_FRONT = float(os.environ.get("GEAR07_NECK_FRONT", "0.26"))  # the front U's bottom below SH (the tee's collar is at
                             # about SH at the front's middle: ~0.26 of tee shows, was 0.31)
NECK_BACK = float(os.environ.get("GEAR07_NECK_BACK", "-0.10"))   # the back U's bottom, ABOVE SH: the tee's collar is at
                             # ~SH + 0.48 at the back (it was 0.24 below SH: ~0.75 of tee showed, a box over the back)
NECK_TURN = 0.02             # below SH, where the front U's sides reach the straps' inner edges
NECK_H_BACK = float(os.environ.get("GEAR07_NECK_H_BACK", "0.25"))  # the back U's height, bottom to the straps
NECK_K = float(os.environ.get("GEAR07_NECK_K", "2.0"))           # the U's power (2 = a parabola: round, no flat bottom)
NECK_ROUND = float(os.environ.get("GEAR07_NECK_ROUND", "0.06"))  # how softly the U turns into the straps' inner edges
# The U's top is this much narrower than v4's strap inner edge (HEAD_HALF + 0.06), front / back, the straps' outer edges
# unchanged: wider straps, a narrower opening, as the reference (the tee's collar is about half the old opening's width)
NECK_NARROW = float(os.environ.get("GEAR07_NECK_NARROW", "0.12"))
NECK_NARROW_BACK = float(os.environ.get("GEAR07_NECK_NARROW_BACK", "0.04"))
ARM_UNDER = float(os.environ.get("GEAR07_ARM_UNDER", "0.06"))             # the armhole's bottom below the armpit
STRAP_PUSH, STRAP_SOFT = 3.0, 0.05   # how strongly the strap's zone is kept, and how soft its edge is
STRAP_W = 0.22               # the straps' width over the shoulder (narrower where the shoulder is: thin builds)
ARM_GAP_TOP = 0.04           # the armhole's edge this far off the arm's root over the shoulder ...
ARM_GAP_UNDER = float(os.environ.get("GEAR07_ARM_GAP_UNDER", "0.10"))         # ... and this far below it (just under the armpit)
PANEL_TOP = float(os.environ.get("GEAR07_PANEL_TOP", "0.2"))              # the side panel reaches this far above the armhole's bottom (into its piping)
PIPING = 0.035               # the piping's width along the neck and the armholes
PANEL_HALF = 0.22            # the side panel's half-width front to back
PANEL_LOW = 0.25             # the panel's bottom above the hip joints, ...
PANEL_ROUND = 0.08           # ... rounded this much
LEG_LENGTH = 0.31            # the shorts' legs reach this share of the way from the crotch to the knee, ...
LEG_GAP = 0.10               # ... ending at least this far above the knee sleeves' top (bare thigh between)
LEG_ABOVE_SLEEVE = float(os.environ.get("GEAR07_LEG_OVER", "-0.08"))  # ... ending this far above the knee sleeves' top
                              # (v5's); NEGATIVE = over it: a hem 0.02 above left a ring of bare skin between the shorts
                              # and the sleeve (user 2026-11-15, from below); the shorts (0.077 out) cover the sleeve
                              # (0.02-0.03 out) where they overlap. Unless:
LONG_SHORTS = os.environ.get("GEAR07_LONG_SHORTS") == "1"   # trial: the shorts at LEG_LENGTH (with shorter sleeves)
HEM_SKIN_CLEAR = 0.03        # ... and never closer than this to the thigh
SLEEVE_WALL = 0.025          # the sleeve's full width is taken this far below its (rounded) top
SLEEVE_CLEAR = 0.0135        # the shorts' outside this far outside the knee sleeve where they overlap (fabric 0.012):
                              # the inside touches the sleeve (0.020 left a gap that showed the thigh from below)
HEM_SNUG, HEM_SNUG_H = 0.048, 0.10   # the shorts' hem this far off the skin, drawn in over this height above it
                                     # (tighter, 0.040 over 0.16, let the sleeve's top edge show through)
INNER_ROUNDS = 6             # rounds of smoothing of the two rings of points inside every edge / colour line
ROOT_SMOOTH = 10             # rounds of smoothing of the arm's surface the armhole is measured from
SEAM_ROUNDS = 60              # rounds of smoothing along every edge and colour line (Taubin, kept on the surface)
SHORTS_TOP = 0.05            # the shorts' colour starts this far below the hip joints (a level line)
REFINE_BAND = 0.03
ARM_BLEND = float(os.environ.get("GEAR07_ARM_BLEND", "0.015"))  # the armhole and the arm-seam cut blended over this (0.04 pulled the
                             # edge in where the two lines run close: the notch at the strap's foot, user 2026-11-16)
ARMSEAM_TOP, ARMSKIN_ROUND = 0.0, 0.05   # the cut along the arm's seam stops this far above the armpit, blended in
ARMSEAM_SMOOTH = 2           # rounds of smoothing of the arm-part marker (its 0.5 line stays on the seam)
IS_ARM_S = "_IsArmS"
TRIM_STRIP_FAR_7 = 0.065     # piping further than this from the red / black is a sliver (the thin builds' armpit crease)


IS_ARM = "_IsArm"             # a temporary group: the points of the arm PARTS' meshes (weight 1), removed before export


def joined_skin7(build, coll):
    """v6's joined skin, also marking which points came from the arm parts' meshes (group IS_ARM): the arm and the
    torso are told apart by that seam, not by bone weights (the inside of a thin build's upper arm is weighted largely
    to the torso, and a strip of singlet stayed on it)."""
    for p in PARTS:
        if p.endswith(("UpperArm", "LowerArm")):
            src = bpy.data.objects[build + "_" + p]
            g = src.vertex_groups.get(IS_ARM) or src.vertex_groups.new(name=IS_ARM)
            g.add(list(range(len(src.data.vertices))), 1.0, "REPLACE")
    skin = joined_skin(build, coll)
    for p in PARTS:
        src = bpy.data.objects.get(build + "_" + p)
        if src is not None and src.vertex_groups.get(IS_ARM):
            src.vertex_groups.remove(src.vertex_groups[IS_ARM])
    return skin


def smoothed_group(o, src, dst, rounds):
    """A copy of group `src` (0/1) averaged with neighbours `rounds` times, as group `dst`; returns {its index}."""
    import numpy as np
    me = o.data
    gi = o.vertex_groups[src].index
    val = np.array([next((g.weight for g in v.groups if g.group == gi), 0.0) for v in me.vertices])
    nb = [[] for _ in me.vertices]
    for e in me.edges:
        a_, b_ = e.vertices
        nb[a_].append(b_)
        nb[b_].append(a_)
    for _ in range(rounds):
        val = np.array([(val[i] + sum(val[j] for j in nb[i])) / (1 + len(nb[i])) for i in range(len(val))])
    g = o.vertex_groups.get(dst) or o.vertex_groups.new(name=dst)
    for i, x in enumerate(val):
        g.add([i], float(x), "REPLACE")
    return {g.index}


def drop_group(o, name):
    g = o.vertex_groups.get(name)
    if g:
        o.vertex_groups.remove(g)


def relax_seams(o, rounds=SEAM_ROUNDS if "SEAM_ROUNDS" in globals() else 8, lam=0.5, mu=-0.53):
    """Smooths every open edge and every colour line of a garment (o["keys"] per face): each point on such a line moves
    toward the middle of its two neighbours along it (Taubin: no shrinking), then back onto the garment's surface. The
    lines are drawn through the body's triangles, so they come out as zigzags of straight pieces: up close in the game
    they read as rough, torn edges (user 2026-11-15). Points where lines meet (corners) stay put."""
    from mathutils.bvhtree import BVHTree
    me = o.data
    keys = list(o["keys"])
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    tree = BVHTree.FromBMesh(bm)
    nbrs = {}
    for e in bm.edges:
        fs = e.link_faces
        seam = len(fs) == 1 or (len(fs) == 2 and keys[fs[0].index] != keys[fs[1].index])
        if seam:
            a_, b_ = e.verts
            nbrs.setdefault(a_, []).append(b_)
            nbrs.setdefault(b_, []).append(a_)
    line = {v: n for v, n in nbrs.items() if len(n) == 2}
    for _ in range(rounds):
        for f in (lam, mu):
            new = {v: v.co + ((n[0].co + n[1].co) * 0.5 - v.co) * f for v, n in line.items()}
            for v, c in new.items():
                v.co = c
    moved = 0
    for v in line:
        hit = tree.find_nearest(v.co)
        if hit[0] is not None:
            v.co = hit[0]
            moved += 1
    # the points just inside the lines follow (two rings, averaged with their neighbours and put back on the surface):
    # an edge point slid along its line past its inner neighbour folded a thin triangle over, a white sliver sticking
    # out of the piping (user 2026-11-15: "tears on the back")
    seam = set(nbrs)
    ring = set()
    for v in seam:
        for e in v.link_edges:
            o2 = e.other_vert(v)
            if o2 not in seam:
                ring.add(o2)
    ring2 = set(ring)
    for v in ring:
        for e in v.link_edges:
            o2 = e.other_vert(v)
            if o2 not in seam:
                ring2.add(o2)
    for _ in range(INNER_ROUNDS):
        new = {}
        for v in ring2:
            ns = [e.other_vert(v).co for e in v.link_edges]
            if ns:
                new[v] = sum(ns, Vector()) / len(ns)
        for v, c in new.items():
            hit = tree.find_nearest(c)
            v.co = hit[0] if hit[0] is not None else c
    bm.to_mesh(me)
    bm.free()
    me.update()
    return moved


def snug_hems(o, hem):
    """The shorts' legs grip the thigh at the hem, as real shorts do: within HEM_SNUG_H above the hem each point moves
    in along its stacking line, to HEM_SNUG off the skin at the hem itself (from TEE_OUT + SINGLET_OUT). Seen from
    below, the loose hem left a ring of bare thigh between the shorts and the knee sleeve (user 2026-11-15); the
    sleeve's outside is 0.02-0.03 off the skin, so the shorts still pass over it."""
    me = o.data
    leg = group_ids(o, ("UpperLeg", "LowerLeg"))
    line = me.attributes["line"]
    full = TEE_OUT + SINGLET_OUT
    n = 0
    for v in me.vertices:
        if sum(g.weight for g in v.groups if g.group in leg) < 0.5:
            continue
        t = 1.0 - min(1.0, max(0.0, (v.co.z - hem) / HEM_SNUG_H))
        if t <= 0:
            continue
        t = t * t * (3 - 2 * t)
        d = Vector(line.data[v.index].vector)
        if d.length < 1e-9:
            continue
        v.co = v.co - d.normalized() * ((full - HEM_SNUG) * t)
        n += 1
    me.update()
    return n


SLEEVE_SRC = os.path.join(ROOT, "art", "blender", "CartoonGear_05.blend")   # the knee sleeves as uploaded (v5)


def sleeve_tree(build):
    """The build's uploaded knee sleeves (CartoonGear_05.blend) as one BVH in the rig's space (its outside faces)."""
    from mathutils.bvhtree import BVHTree
    with bpy.data.libraries.load(SLEEVE_SRC, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n.startswith(build + "_WornKneeSleeve_")] + [build + "Rig"]
    rig = next(o for o in dst.objects if o is not None and o.type == "ARMATURE")
    to_rig = rig.matrix_world.inverted()
    verts, faces = [], []
    for o in dst.objects:
        if o is None or o.type != "MESH":
            continue
        m = to_rig @ o.matrix_world
        base = len(verts)
        verts += [m @ v.co for v in o.data.vertices]
        faces += [tuple(base + i for i in p.vertices) for p in o.data.polygons]
    for o in dst.objects:
        if o is not None:
            bpy.data.objects.remove(o, do_unlink=True)
    return BVHTree.FromPolygons(verts, faces) if faces else None


SLEEVES_NOW = [None]          # the build's v7 sleeves (a BVH), set before the singlet is built


def clear_sleeves(o, build, hem):
    """Where the shorts overlap the knee sleeve, they sit on it: each point is put at the sleeve's outside + SLEEVE_CLEAR,
    measured straight out from the thigh's axis. Right at its top the sleeve's edge rounds inward, so from just below
    the top upward the sleeve's FULL width (at SLEEVE_WALL below its top) is used: there the shorts don't follow the
    lip in, and no sliver of thigh shows between the sleeve's top and the shorts from below (user 2026-11-15). The
    sleeve's top edge (jagged where its cut crossed the mesh) stays hidden. Fades back to the shorts' own line above."""
    tree = SLEEVES_NOW[0] if SLEEVES_NOW[0] is not None else sleeve_tree(build)
    if tree is None:
        return 0, 0.0
    rig = bpy.data.objects[build + "Rig"]
    axes = {}
    for side in ("Left", "Right"):
        hip = rig.data.bones[side + "UpperLeg"].head_local.copy()
        knee = rig.data.bones[side + "LowerLeg"].head_local.copy()
        axes[side] = (hip, knee)
    top = hem - LEG_ABOVE_SLEEVE
    me = o.data
    moved, worst = 0, 0.0
    for v in me.vertices:
        w = 1.0 - min(1.0, max(0.0, (v.co.z - (top + 0.03)) / 0.06))
        if w <= 0 or v.co.z < hem - 0.02:
            continue
        side = min(axes, key=lambda k: abs(v.co.x - axes[k][0].x))
        hip, knee = axes[side]
        zq = min(v.co.z, top - SLEEVE_WALL)

        def centre(z):
            t = (hip.z - z) / max(1e-6, hip.z - knee.z)
            return hip.lerp(knee, t)
        c = centre(v.co.z)
        d = Vector((v.co.x - c.x, v.co.y - c.y, 0.0))
        if d.length < 1e-6:
            continue
        d.normalize()
        cq = centre(zq)
        # this leg's sleeve only: its wall's inside then outside, the two hits within a short reach (further on the ray
        # can meet the other leg's sleeve)
        p, hits = cq.copy(), []
        for _ in range(3):
            h = tree.ray_cast(p + d * 1e-4, d, 0.6)
            if h[0] is None:
                break
            if hits and (h[0] - hits[-1]).length > 0.06:
                break
            hits.append(h[0])
            p = h[0]
        if not hits:
            continue
        last = hits[-1]
        r_sleeve = (Vector((last.x - cq.x, last.y - cq.y, 0.0))).length
        r_now = (Vector((v.co.x - c.x, v.co.y - c.y, 0.0))).length
        r_want = r_sleeve + SLEEVE_CLEAR
        delta = (r_want - r_now) * w
        if abs(delta) < 1e-5 or abs(delta) > 0.08:
            continue
        v.co = v.co + d * delta
        moved += 1
        worst = max(worst, abs(delta))
    me.update()
    return moved, worst


def clear_skin_band(o, skin, hem):
    """After the hem was drawn in over the sleeve, no point near it may come within HEM_SKIN_CLEAR of the thigh: just
    above the sleeve's top the thigh bulges out past the sleeve, and the drawn-in shorts let it show through (a
    crescent of skin seen from below, user 2026-11-15)."""
    from mathutils.bvhtree import BVHTree
    sm = skin.data
    tree = BVHTree.FromPolygons([v.co for v in sm.vertices], [tuple(p.vertices) for p in sm.polygons])
    me = o.data
    line = me.attributes["line"]
    top = hem - LEG_ABOVE_SLEEVE
    n, worst = 0, 0.0
    for v in me.vertices:
        if v.co.z > top + 0.12:
            continue
        loc, nrm, _i, d = tree.find_nearest(v.co, 0.3)
        if loc is None:
            continue
        side = (v.co - loc).dot(nrm)
        need = HEM_SKIN_CLEAR - side
        if need <= 0:
            continue
        dl = Vector(line.data[v.index].vector)
        if dl.length < 1e-9:
            continue
        v.co = v.co + dl.normalized() * need
        n += 1
        worst = max(worst, need)
    me.update()
    return n, worst


def drop_trim_strips7(o):
    """v6's drop_trim_strips, but measured to the red / black SURFACE (its faces), not to their corner points: on long
    thin faces a piping face's middle was further than the limit from every corner point, and whole bits of real
    piping were dropped, rectangular bites out of the strap's edges (user 2026-11-15: "tears on the back")."""
    from mathutils.bvhtree import BVHTree
    me = o.data
    keys = list(o["keys"])
    body = [tuple(p.vertices) for p, k in zip(me.polygons, keys) if k in ("Red", "Black")]
    if not body:
        return 0
    tree = BVHTree.FromPolygons([v.co for v in me.vertices], body)
    gone = set()
    for p, k in zip(me.polygons, keys):
        if k != "Trim":
            continue
        hit = tree.find_nearest(p.center, TRIM_STRIP_FAR_7 + 0.01)
        if hit[0] is None or hit[3] > TRIM_STRIP_FAR_7:
            gone.add(p.index)
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
    return len(gone)


def dedupe_faces(o):
    """Drops faces that repeat another face's corners exactly (the cuts can leave one, and thickening then failed with
    "face already exists"). Keeps o["keys"] in step."""
    me = o.data
    keys = list(o["keys"]) if "keys" in o.keys() else None
    seen, gone = set(), set()
    for p in me.polygons:
        k = tuple(sorted(p.vertices))
        if k in seen:
            gone.add(p.index)
        seen.add(k)
    if not gone:
        return 0
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in gone], context="FACES_ONLY")
    bm.to_mesh(me)
    bm.free()
    me.update()
    if keys is not None:
        o["keys"] = [k for i, k in enumerate(keys) if i not in gone]
    return len(gone)


STIFF_BAND = float(os.environ.get("GEAR07_STIFF_BAND", "0.30"))   # how far in from an open edge the weights are smoothed
STIFF_ROUNDS = int(os.environ.get("GEAR07_STIFF_ROUNDS", "16"))    # rounds of smoothing (full strength at the edge)


def stiff_edges7(o, band=None, rounds=None):
    """Smooths the bone weights near the garment's OPEN EDGES where the arm takes part (the tee's sleeve ends, the
    singlet's armholes): the skin under a raised arm bunches (a one-joint shoulder), and an edge with the skin's own
    weights crumpled into a white zigzag there (user 2026-11-17, body polish, "Arms overhead - left side"). Each point
    within `band` (along the surface) of an open edge takes the average of its neighbours' weights, round after round,
    at full strength on the edge and fading to none at `band`; edge points average along the edge. Max 4 bones a point
    (Roblox), normalised. Returns the number of points smoothed.
    Used on the TEE only. Tried and dropped 2026-11-17 for the singlet's crease under a raised arm (all made it worse):
    the same smoothing on the singlet (wider / 200 rounds: the tee came through it); one smoothed shoulder field for tee
    and singlet (over the chest the skin came through the tee; under the arm alone it didn't help, Body under Tee 7-24 ->
    54-112 points); a deeper armhole (its bottom folded into a V notch) with the red panel lower (a loose red oval); the
    garment under the armpit following the torso (Body under Tee 115-182 points)."""
    import heapq
    band = STIFF_BAND if band is None else band
    rounds = STIFF_ROUNDS if rounds is None else rounds
    me = o.data
    bones = {g.index: g.name for g in o.vertex_groups if not g.name.startswith("_")}
    arm = {i for i, n in bones.items() if "UpperArm" in n or "LowerArm" in n}
    n = len(me.vertices)
    W = [{g.group: g.weight for g in v.groups if g.group in bones and g.weight > 1e-5} for v in me.vertices]
    nb = [set() for _ in range(n)]
    count = {}
    for p_ in me.polygons:
        for ek in p_.edge_keys:
            count[ek] = count.get(ek, 0) + 1
    edge_nb = [set() for _ in range(n)]
    for e in me.edges:
        a_, b_ = e.vertices
        nb[a_].add(b_)
        nb[b_].add(a_)
        if count.get(tuple(sorted((a_, b_))), 0) == 1:
            edge_nb[a_].add(b_)
            edge_nb[b_].add(a_)
    on_edge = [len(edge_nb[i]) > 0 for i in range(n)]
    # distance along the surface to the nearest open edge (Dijkstra out to band)
    co = [v.co.copy() for v in me.vertices]
    dist = [band] * n
    heap = [(0.0, i) for i in range(n) if on_edge[i]]
    for _, i in heap:
        dist[i] = 0.0
    heapq.heapify(heap)
    while heap:
        d, i = heapq.heappop(heap)
        if d > dist[i]:
            continue
        for j in nb[i]:
            dj = d + (co[i] - co[j]).length
            if dj < dist[j]:
                dist[j] = dj
                heapq.heappush(heap, (dj, j))
    # only where the arm takes part: the point or a neighbour has some arm weight
    armish = [any(k in arm for k in W[i]) for i in range(n)]
    region = [i for i in range(n) if dist[i] < band and (armish[i] or any(armish[j] for j in nb[i]))]
    if not region:
        return 0
    strength = {i: (1.0 - dist[i] / band) ** 1.5 for i in region}
    for _ in range(rounds):
        new = {}
        for i in region:
            src = edge_nb[i] if on_edge[i] and len(edge_nb[i]) == 2 else nb[i]
            avg = {}
            for j in src:
                for k, w in W[j].items():
                    avg[k] = avg.get(k, 0.0) + w / len(src)
            f = 0.6 * strength[i]
            keys = set(avg) | set(W[i])
            new[i] = {k: W[i].get(k, 0.0) * (1 - f) + avg.get(k, 0.0) * f for k in keys}
        for i, w in new.items():
            top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
            tot = sum(x for _, x in top) or 1.0
            W[i] = {k: x / tot for k, x in top if x / tot > 1e-4}
    groups = {i: o.vertex_groups[bones[i]] for i in bones}
    for i in region:
        for gi, g in groups.items():
            g.remove([i])
        for k, w in W[i].items():
            groups[k].add([i], w, "REPLACE")
    return len(region)


# The armhole's lower part (below SHARE_TOP under the shoulder line) also stops where the skin is more than SHARE_CUT
# on the arm (its smoothed share): there the arm drags the skin, and the singlet's edge round the armpit stretched up
# to 5-13x with the arm overhead (user 2026-11-17: "the singlet strap disappears ... gets all torn up"). 0 = off.
SHARE_CUT = float(os.environ.get("GEAR07_SHARE_CUT", "0"))
SHARE_TOP = float(os.environ.get("GEAR07_SHARE_TOP", "0.35"))    # below SH: the straps above it are left as they are
SHARE_ROUNDS = int(os.environ.get("GEAR07_SHARE_ROUNDS", "8"))   # smoothing rounds of the arm share (a smooth line)
SHARE_K = 2.0                                                     # the share's step to studs (for the soft blend)
# PROTOTYPE (user 2026-11-17: "try it, i wanna take a look"): a DEEP armhole like real singlets, so no fabric lies on
# the skin that stretches from the side of the ribs to the arm's root (2.6-4x with the arms overhead, SH-0.7..-1.1 on
# the side): a smooth superellipse in the side view round the arm's root, down to DEEP below the shoulder line, cut only
# on the torso's side (|x| beyond DEEP_IN inside the torso's half-width). The straps are left exactly as approved.
DEEP = float(os.environ.get("GEAR07_DEEP", "0"))                 # its bottom this far below SH; 0 = off
DEEP_Y = float(os.environ.get("GEAR07_DEEP_Y", "0.30"))          # its half-width toward the BACK from the arm's root
# ... and toward the FRONT (user 2026-11-17, "middle way": "i dont like how theres this whole right here ... is it
# possible to have that area covered" - from the front the singlet stays closed up to the tee sleeve as before; the
# deep cut is only at the true side and toward the back). Unset = DEEP_Y (the symmetric first prototype).
DEEP_YF = float(os.environ["GEAR07_DEEP_YF"]) if os.environ.get("GEAR07_DEEP_YF") else None   # negative = the
                             # opening's front edge BEHIND the arm's root (hidden from the front, user 2026-11-17)
DEEP_BLEND = float(os.environ.get("GEAR07_DEEP_BLEND", "0.05"))  # how softly the deep cut merges into the armhole (a
                             # hard meeting left a step and a tooth in the piping under the arm, user 2026-11-17)
DEEP_MORPH = os.environ.get("GEAR07_DEEP_MORPH", "")   # (prototype) "above,below" the armpit: the armhole's curve turns
                             # INTO the deep oval over this band (one line, no corner where two cuts meet); "" = off
# (prototype, the redesign session's "(a)", 2026-11-17) the deep armhole as ONE shape: the armhole is the band a set
# distance round the arm's root, and that distance itself grows under and behind the arm, so the edge is a single
# offset curve from the strap round the armpit and down (two cuts blended left a notch / kink / curl at the armpit).
ONE_DEEP = float(os.environ.get("GEAR07_ONE_DEEP", "0"))      # the extra distance at full depth (0 = off)
ONE_TOP = float(os.environ.get("GEAR07_ONE_TOP", "0.05"))     # it starts this far above the armpit ...
ONE_FULL = float(os.environ.get("GEAR07_ONE_FULL", "0.35"))   # ... and is full this far below it
ONE_YF = float(os.environ.get("GEAR07_ONE_YF", "0.02"))       # none in front of (arm root - this): the front stays shut
ONE_YB = float(os.environ.get("GEAR07_ONE_YB", "0.14"))       # full behind (arm root + this)
ONE_PANEL = float(os.environ.get("GEAR07_ONE_PANEL", "0.10"))  # the red panel's centre behind the arm's root
DEEP_SMOOTH = float(os.environ.get("GEAR07_DEEP_SMOOTH", "0"))  # (prototype) the armhole + deep oval cut, as ONE
                             # field blurred over this radius before its line is drawn: the corner where the two met
                             # (a notch / kink / curl at the armpit, user 2026-11-17) rounds into one curve. 0 = off
DEEP_TEE_PUSH = float(os.environ.get("GEAR07_DEEP_TEE_PUSH", "0"))  # the tee pushed out this much inside the opening
DEEP_TOP = float(os.environ.get("GEAR07_DEEP_TOP", "0.10"))      # its top this far above the armpit
DEEP_IN = float(os.environ.get("GEAR07_DEEP_IN", "0.18"))        # how far round the side it reaches inward
DEEP_P = 2.4                                                      # its roundness
HOLD_FULL = float(os.environ.get("GEAR07_HOLD_FULL", "0.15"))    # the singlet is torso-only from this far below the
HOLD_FADE = float(os.environ.get("GEAR07_HOLD_FADE", "0.30"))    # armpit up, fading to the skin's own weights over this
HOLD_AMOUNT = float(os.environ.get("GEAR07_HOLD_AMOUNT", "0.0"))  # the share of the arm's weight handed to the torso.
# OFF (0) until the body holds the shoulder's top on the torso: on the body-polish weights (Prod_Rigged, 2026-11-17) the
# skin carries 40-65% arm where the straps lie and 15-28% even beside the neck, so a torso-held singlet let the skin out
# through it (full hold: stretch p99 1.04-1.22, max <= 2.25, but Body under WornSinglet 95-203 points, up to 0.49
# deep; half: p99 1.7-1.9, max 3-7, skin 53-134 points, 0.18-0.22; off: p99 2.6-3.1, max 6-13, skin ~0).


def hold_straps7(o, pit, only=None):
    """The singlet's straps and armhole band move with the TORSO only: every point's arm share (UpperArm, LowerArm,
    Hand) goes to UpperTorso from HOLD_FULL below the armpit up, fading back to the skin's copied weights over HOLD_FADE
    below that. The approved v4 rule (memory worn-gear-style: "the straps stay put while the arm moves"); v7's copied
    skin weights dragged the straps with the arm overhead: edges stretched up to 7-19x, the strap seemed to vanish and
    the armpit tore (user 2026-11-17). Returns the number of points changed."""
    bones = {g.index: g.name for g in o.vertex_groups if not g.name.startswith("_")}
    arm = {i for i, n in bones.items() if "UpperArm" in n or "LowerArm" in n or n.endswith("Hand")}
    ut = o.vertex_groups.get("UpperTorso") or o.vertex_groups.new(name="UpperTorso")
    z_full, z_none = pit - HOLD_FULL, pit - HOLD_FULL - HOLD_FADE
    changed = 0
    for v in o.data.vertices:
        if v.co.z <= z_none or (only is not None and not only[v.index]):
            continue
        w = {g.group: g.weight for g in v.groups if g.group in bones and g.weight > 0}
        a = sum(x for k, x in w.items() if k in arm)
        if a <= 1e-5:
            continue
        t = min(1.0, (v.co.z - z_none) / max(1e-6, z_full - z_none))
        t = t * t * (3 - 2 * t) * HOLD_AMOUNT
        moved = 0.0
        for k in list(w):
            if k in arm:
                moved += w[k] * t
                w[k] *= 1 - t
        w[ut.index] = w.get(ut.index, 0.0) + moved
        top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
        tot = sum(x for _, x in top) or 1.0
        for g in list(v.groups):
            if g.group in bones:
                o.vertex_groups[bones[g.group]].remove([v.index])
        for k, x in top:
            if x / tot > 1e-4:
                o.vertex_groups[bones.get(k, "UpperTorso")].add([v.index], x / tot, "REPLACE")
        changed += 1
    return changed


def covered_by7(o, cover, reach=0.15):
    """Per point of `o` (a layer under `cover`, both at rest, not yet thickened): does `cover` lie straight out from it
    along its stacking line, within `reach`?"""
    from mathutils.bvhtree import BVHTree
    bm = bmesh.new()
    bm.from_mesh(cover.data)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    line = o.data.attributes.get("line")
    out = []
    for v in o.data.vertices:
        d = Vector(line.data[v.index].vector) if line is not None else Vector(v.normal)
        if d.length < 1e-6:
            d = Vector(v.normal)
        d.normalize()
        out.append(tree.ray_cast(v.co - d * 0.005, d, reach)[0] is not None)
    return out


SLIVER = float(os.environ.get("GEAR07_SLIVER", "0"))   # (prototype) points closer than this are merged; 0 = off


def weld_slivers7(o, dist):
    """Merges points closer than `dist` and dissolves the near-flat slivers left where two cut lines nearly meet (the
    piping's 0.004-long edges at the deep armhole's junction read as points and teeth, user 2026-11-17). The faces'
    colours (o["keys"]) ride along as a face attribute."""
    me = o.data
    keys = list(o["keys"])
    names = sorted(set(keys))
    att = me.attributes.new("_kid", "INT", "FACE")
    for i, k in enumerate(keys):
        att.data[i].value = names.index(k)
    n0 = len(me.vertices)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=dist)
    bmesh.ops.dissolve_degenerate(bm, dist=dist, edges=bm.edges[:])
    bm.to_mesh(me)
    bm.free()
    me.update()
    att = me.attributes["_kid"]
    o["keys"] = [names[att.data[i].value] for i in range(len(me.polygons))]
    me.attributes.remove(att)
    return n0 - len(me.vertices)


TEE_PIT = float(os.environ.get("GEAR07_TEE_PIT", "0"))   # (prototype) the tee smoothed within this of each armpit; 0 off


def smooth_armpit7(o, skin, centres, radius, rounds=12):
    """The tee's sleeve underside and its join to the body in the armpit, at rest: one smooth surface. Its points within
    `radius` of an armpit are smoothed (Taubin, strongest at the armpit; points on the tee's open edges move only along
    the edge), which bridges the crease outward like a garment over a groove, then kept at least TEE_OUT * 0.9 off the
    skin (pushed back out along their lines). The skin's crease had the layer bunched into teeth and points beside the
    singlet's edge (user 2026-11-17: "has points to it ... rough edges trying to line up with the armpit"). Returns the
    number of points moved."""
    from mathutils.bvhtree import BVHTree
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.verts.ensure_lookup_table()
    w = {}
    for v in bm.verts:
        d = min((v.co - c).length for c in centres)
        if d < radius:
            w[v] = (1.0 - d / radius) ** 2
    if not w:
        bm.free()
        return 0
    nbr = {}
    for v in w:
        if v.is_boundary:
            nbr[v] = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
        else:
            nbr[v] = [e.other_vert(v) for e in v.link_edges]
    for _ in range(rounds):
        for f in (0.5, -0.53):
            new = {}
            for v, k in w.items():
                ns = nbr[v]
                if not ns:
                    continue
                c = Vector()
                for n in ns:
                    c += n.co
                new[v] = v.co + (c / len(ns) - v.co) * f * k
            for v, c in new.items():
                v.co = c
    # the stacking lines there too (the thickness is grown inward along them: crossing lines in the crease pushed the
    # inner layer out through the cuff's edge as dark teeth)
    line_l = bm.verts.layers.float_vector.get("line")
    if line_l is not None:
        for _ in range(rounds):
            new = {}
            for v, k in w.items():
                acc = Vector(v[line_l])
                for e in v.link_edges:
                    acc += Vector(e.other_vert(v)[line_l])
                if acc.length > 1e-9:
                    new[v] = Vector(v[line_l]).lerp(acc.normalized() * Vector(v[line_l]).length, k)
            for v, c in new.items():
                v[line_l] = c
    # keep the tee off the skin
    sb = bmesh.new()
    sb.from_mesh(skin.data)
    tree = BVHTree.FromBMesh(sb)
    sb.free()
    line = bm.verts.layers.float_vector.get("line")
    need = TEE_OUT * 0.9
    for v in w:
        hit = tree.find_nearest(v.co, 0.5)
        if hit[0] is None:
            continue
        d = (v.co - hit[0]).length
        if (v.co - hit[0]).dot(hit[1]) < 0:
            d = -d
        if d < need:
            n = Vector(v[line]) if line is not None else Vector(hit[1])
            if n.length < 1e-6:
                n = Vector(hit[1])
            v.co += n.normalized() * (need - d)
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()
    return len(w)


def colour_islands7(o, rounds=2):
    """A face whose colour (o["keys"]) matches none of its neighbours takes the colour most of them have: a lone body
    face poking into the piping read as a speck in the edge up close (user 2026-11-16, "a little tear"). Returns how
    many changed."""
    from collections import Counter
    me = o.data
    keys = list(o["keys"])
    by_edge = {}
    for p_ in me.polygons:
        for ek in p_.edge_keys:
            by_edge.setdefault(ek, []).append(p_.index)
    nb = [[g for ek in p_.edge_keys for g in by_edge[ek] if g != p_.index] for p_ in me.polygons]
    changed = 0
    for _ in range(rounds):
        new = list(keys)
        for i, n in enumerate(nb):
            # (never a piping face: where the piping is one triangle wide that would cut a gap into it)
            if keys[i] != "Trim" and len(n) >= 2 and all(keys[j] != keys[i] for j in n):
                new[i] = Counter(keys[j] for j in n).most_common(1)[0][0]
                changed += 1
        keys = new
    o["keys"] = keys
    return changed


def unfold7(o, rounds=UNFOLD_ROUNDS if "UNFOLD_ROUNDS" in globals() else 15, thresh=0.3):
    """Smooths out folded triangles (a face turned against its neighbours: up close a dark notch, a "little tear", user
    2026-11-16): their corners and the ring round them move toward their neighbours (along the edge for edge points) and
    back onto the garment's surface, until none is left. Returns (folded faces before, after)."""
    from mathutils.bvhtree import BVHTree
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    tree = BVHTree.FromBMesh(bm)

    def folded():
        bm.normal_update()
        out = []
        for f in bm.faces:
            nb = {g for e in f.edges for g in e.link_faces if g is not f}
            avg = Vector()
            for g in nb:
                avg += g.normal
            if avg.length > 1e-6 and f.normal.dot(avg.normalized()) < thresh:
                out.append(f)
        return out
    bad = folded()
    first = len(bad)
    for _ in range(rounds):
        if not bad:
            break
        move = {v for f in bad for v in f.verts}
        move |= {e.other_vert(v) for v in list(move) for e in v.link_edges}
        new = {}
        for v in move:
            if v.is_boundary:
                nbv = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
                if len(nbv) != 2:
                    continue
            else:
                nbv = [e.other_vert(v) for e in v.link_edges]
            c = Vector()
            for n in nbv:
                c += n.co
            new[v] = v.co.lerp(c / len(nbv), 0.6)
        for v, c in new.items():
            hit = tree.find_nearest(c)
            v.co = hit[0] if hit[0] is not None else c
        bad = folded()
    bm.to_mesh(me)
    bm.free()
    me.update()
    return first, len(bad)


def soft_min(a, b, k):
    if k <= 0:
        return min(a, b)
    return -k * math.log(math.exp(-a / k) + math.exp(-b / k))


def along_surface(fn, h=0.01):
    """fn(co) -> value; returns g(v, dl): fn over its gradient along the surface at v (the tangent plane of v's line),
    so the value reads as distance along the surface to fn's zero line near it."""
    def g(v, dl):
        c = v.co
        f = fn(c)
        grad = Vector(((fn(c + Vector((h, 0, 0))) - fn(c - Vector((h, 0, 0)))) / (2 * h),
                       (fn(c + Vector((0, h, 0))) - fn(c - Vector((0, h, 0)))) / (2 * h),
                       (fn(c + Vector((0, 0, h))) - fn(c - Vector((0, 0, h)))) / (2 * h)))
        n = line_of(v)
        if n.length > 1e-9:
            n = n.normalized()
            grad = grad - n * grad.dot(n)
        return f / max(0.25, grad.length)
    return g


def singlet_lines7(body, H, skin, layer):
    """The singlet's fields (> 0 = kept / in the panel), all in the rig's space (x across, -y front, z up)."""
    m = H["m"]
    SH = L["SH"]
    xi = V["HEAD_HALF"] + 0.06                                        # the straps' inner edge: clear of the head (v4)
    shell = W["Shell"](B5["body_spec"](body.build), H["arm_from"])
    xo = min(xi + 0.28, shell.arm_inner_x(SH - 0.45) - 0.04)          # the straps' outer edge (v4)
    arm_ids = group_ids(skin, ("UpperArm", "LowerArm", "Hand"))
    pit = m["armpit"]
    xs = min(xi + STRAP_W, xo + 0.02)                                 # the straps' outer edge over the shoulder
    # The armhole: everything within a set distance of the arm's ROOT (the arm's own skin above the armpit). Its edge is
    # one smooth curve round the arm, that distance off it: just inside the deltoid over the shoulder (where the strap
    # ends), just under the armpit below. The arm itself is inside it, so the arm comes off as a loose piece.
    # (Tried: an oval seen from the side: reaching up to the strap it cut the straps away where they come down the
    # front and back of the shoulder; kept lower it left the arm on.)
    from mathutils.bvhtree import BVHTree
    me = skin.data
    arm_part = skin.vertex_groups[IS_ARM].index
    is_arm = [any(g.group == arm_part and g.weight > 0.5 for g in v.groups) for v in me.vertices]
    root = [tuple(p.vertices) for p in me.polygons
            if all(is_arm[i] and me.vertices[i].co.z > pit for i in p.vertices)]
    # (measured from a SMOOTHED copy of the arm's surface: the deltoid's facets made the strap's outer edge wavy)
    import numpy as np
    pts = np.array([v.co[:] for v in me.vertices])
    used = sorted({i for f in root for i in f})
    nb = {i: set() for i in used}
    for f in root:
        for a_ in f:
            for b_ in f:
                if a_ != b_:
                    nb[a_].add(b_)
    for _ in range(ROOT_SMOOTH):                                   # (Taubin: plain smoothing shrank the arm and the
        for f in (0.5, -0.53):                                     # singlet crept up over the shoulder)
            new = pts.copy()
            for i in used:
                new[i] = pts[i] + (np.mean([pts[j] for j in nb[i]], axis=0) - pts[i]) * f
            pts = new
    tree = BVHTree.FromPolygons([Vector(p_) for p_ in pts], root)
    out = TEE_OUT + SINGLET_OUT
    y_arm = sum(me.vertices[i].co.y for f in root for i in f) / max(1, sum(len(f) for f in root))
    ry = 0.0
    z_bot = pit - ARM_UNDER
    z_turn = SH - NECK_TURN
    smooth = W["P"]["smoothstep"]
    import numpy as np

    def neck(c):
        # kept below the U's edge (its height at |x|: the bottom at the middle, rising as a parabola to the straps' inner
        # edge at z_turn) or outside the straps' inner edge; a soft maximum of the two rounds where they meet
        back = smooth(-0.15, 0.15, np.array([c.y]))[0]
        bottom = SH - (NECK_FRONT + (NECK_BACK - NECK_FRONT) * back)
        h = (NECK_FRONT - NECK_TURN) + (NECK_H_BACK - (NECK_FRONT - NECK_TURN)) * back
        xn = xi - (NECK_NARROW + (NECK_NARROW_BACK - NECK_NARROW) * back)
        t = min(1.0, abs(c.x) / xn)
        below = bottom + h * t ** NECK_K - c.z
        outside = abs(c.x) - xn
        return -soft_min(-below, -outside, NECK_ROUND)

    def arm(c):
        hit = tree.find_nearest(c, 2.0)
        d = hit[3] if hit[0] is not None else 2.0
        t = min(1.0, max(0.0, (SH - c.z) / max(0.01, SH - pit)))
        # Inside the strap's outer edge the distance counts for more (a smooth ramp): the top of the shoulder is the
        # arm's own skin on these bodies, and the plain distance cut the straps away. (Tried: a separate strap zone:
        # a step where it ended; measuring only from the root's faces outside the strap: a ragged strap edge.)
        inward = STRAP_PUSH * STRAP_SOFT * math.log1p(math.exp((xs - abs(c.x)) / STRAP_SOFT))
        gap = ARM_GAP_TOP + (ARM_GAP_UNDER - ARM_GAP_TOP) * t * t * (3 - 2 * t)
        if ONE_DEEP > 0:
            wz = min(1.0, max(0.0, (pit + ONE_TOP - c.z) / (ONE_TOP + ONE_FULL)))
            wy = min(1.0, max(0.0, (c.y - (y_arm - ONE_YF)) / (ONE_YF + ONE_YB)))
            gap += ONE_DEEP * (wz * wz * (3 - 2 * wz)) * (wy * wy * (3 - 2 * wy))
        return d + inward - out - gap

    # The shorts' legs: full tubes round each thigh, their hems a level ring as low as the knee sleeves allow (v4's hem,
    # just under the crotch, left the inside of the thighs bare beside a narrow strip over the crotch: user 2026-11-15
    # "THAT SMALL COVER, and LITTLE GAP BETWEEN THE LEG ... IT NEEDS TO BE FULLY COVERED")
    # As low as the knee sleeves allow (v5's sleeves, as uploaded, reach ~70% up these short thighs: a hem at 40% of the
    # thigh, like the reference, had the sleeves' tops standing out through the shorts by up to 0.13).
    # With the longer thighs (bodies knee 1.00, user 2026-11-15: "make the legs a little longer. so there is a gap
    # between the singlet, and the knee sleeves") the shorts end LEG_LENGTH down the thigh, at least LEG_GAP above the
    # knee sleeves' top: a strip of bare thigh between them, as the reference.
    hem_z = m["crotch"] - LEG_LENGTH * (m["crotch"] - m["knee"])
    if not LONG_SHORTS:
        hem_z = max(hem_z, H["knee_top"] + LEG_GAP)

    def leg(c):
        return c.z - hem_z

    z_pb = L["HJ"] + PANEL_LOW
    py = PANEL_HALF
    yf = DEEP_YF if DEEP_YF is not None else DEEP_Y
    y_deep, w_deep = y_arm + (DEEP_Y - yf) / 2, (DEEP_Y + yf) / 2
    # with the deep cut the red side panel is centred on the opening, so it runs up into it (beside it, it left a notch)
    y_panel = y_deep if DEEP > 0 else (y_arm + ONE_PANEL if ONE_DEEP > 0 else y_arm)

    z_pt = z_bot + PANEL_TOP

    def panel(c):
        # from just above the armhole's bottom (the piping round the armhole meets it) down to the hip, rounded
        return soft_min(soft_min(py - abs(c.y - y_panel), c.z - z_pb, PANEL_ROUND), z_pt - c.z, PANEL_ROUND)

    z_sh = L["HJ"] - SHORTS_TOP

    def shorts(c):
        return z_sh - c.z

    deep = None
    if DEEP > 0:
        torso_x = max(abs(v.co.x) for v in me.vertices if abs(v.co.z - pit) < 0.08 and not is_arm[v.index])
        xg = torso_x - DEEP_IN
        z_lo, z_hi = SH - DEEP, pit + DEEP_TOP
        zc, az = (z_lo + z_hi) / 2, (z_hi - z_lo) / 2

        def deep(c):
            # kept: outside the oval (side view) or inward of the gate (the chest / back)
            # ONE superellipse (smooth all round): from DEEP_YF in front of the arm's root to DEEP_Y behind it
            u = abs(c.y - y_deep) / w_deep
            v = abs(c.z - zc) / az
            outside = ((u ** DEEP_P + v ** DEEP_P) ** (1.0 / DEEP_P) - 1.0) * min(w_deep, az)
            return -soft_min(-outside, -(xg - abs(c.x)), 0.04)

    log(body.build, "singlet v7: strap from %.3f, armhole %d root faces, front U to %.3f (top half-width %.3f, back %.3f to %.3f), arm blend %.3f, leg hem %.3f (crotch %.3f)"
        % (xi, len(root), SH - NECK_FRONT, xi - NECK_NARROW, xi - NECK_NARROW_BACK, SH - NECK_BACK, ARM_BLEND, hem_z,
           m["crotch"]))
    side_x = max(abs(v.co.x) for v in me.vertices if abs(v.co.z - pit) < 0.08 and not is_arm[v.index])
    return dict(neck=neck, arm=arm, leg=leg, panel=panel, shorts=shorts, xi=xi, xo=xo, z_ah=z_bot, pit=pit, hem=hem_z,
                deep=deep, one=(arm if ONE_DEEP > 0 else None), pit_pts=[Vector((sx * side_x, y_arm, pit)) for sx in (1, -1)])


def build_singlet7(skin, P, N, fill, H, coll, build, body):
    o = make_layer(skin, build + "_WornSinglet07", TEE_OUT + SINGLET_OUT, coll, P, N, fill)
    log(build, "Singlet", "skin fold pushed out up to %.3f" % clear_of_skin(o, skin, (TEE_OUT + SINGLET_OUT) * 0.8))
    s = singlet_lines7(body, H, skin, o)
    arm_seam = smoothed_group(o, IS_ARM, IS_ARM_S, ARMSEAM_SMOOTH)
    z_seam = s["pit"] + ARMSEAM_TOP

    def f_armskin(v, dl):
        # > 0 = kept: off the arm's own skin, or above the armhole's bottom (where the armhole itself decides). Where a
        # build's arm rests against its side the two skins are joined, and cutting round the arm's root alone left the
        # singlet running down the arm; cutting there by whole faces left jagged notches under the arm.
        # (by the arm PARTS' points, not by bone weights: the smoothed arm share spread onto the side of the body and
        # cut notches into the red panel; by the raw share a strip stayed on the inside of a thin build's upper arm)
        # Cut along the SEAM between the arm's mesh and the body's (its marker smoothed a little, so the line is a smooth
        # curve on the seam), below the armpit. Above it the armhole (the distance off the arm's root, which is all the
        # arm's mesh above the armpit) takes the arm off already, but for the strap. (Tried: from below the top of the
        # shoulder: the thin builds' straps, on the arm's mesh, were cut off; from under the armhole's bottom with the
        # root found by bone weights: a flap stayed on the arm.)
        return -soft_min(-(0.5 - _deform_weight(v, dl, arm_seam)) * 0.4, -(v.co.z - z_seam), ARMSKIN_ROUND)
    f_neck, f_arm, f_leg = along_surface(s["neck"]), along_surface(s["arm"]), along_surface(s["leg"])
    f_panel, f_shorts = along_surface(s["panel"]), along_surface(s["shorts"])
    # The armhole and the cut along the arm's seam are ONE edge (blended, a soft minimum): cut as two lines they met
    # at a corner, a notch in the piping on the back under the shoulder (user 2026-11-15: "tears on the back")
    f_arm_raw = f_arm
    f_arm = lambda v, dl: soft_min(f_arm_raw(v, dl), f_armskin(v, dl), ARM_BLEND)
    if s["deep"] is not None and DEEP_MORPH:
        f_deep = along_surface(s["deep"])
        m_hi, m_lo = (float(x) for x in DEEP_MORPH.split(","))
        z_mhi, z_mlo = s["pit"] + m_hi, s["pit"] - m_lo

        def f_morph(v, dl):
            t = min(1.0, max(0.0, (z_mhi - v.co.z) / max(1e-6, z_mhi - z_mlo)))
            t = t * t * (3 - 2 * t)
            a = f_arm_raw(v, dl)
            return a if t <= 0 else (1 - t) * a + t * f_deep(v, dl)
        f_arm = lambda v, dl: soft_min(f_morph(v, dl), f_armskin(v, dl), ARM_BLEND)
    elif s["deep"] is not None and DEEP_SMOOTH > 0:
        arm_p, deep_p = s["arm"], s["deep"]
        r_ = DEEP_SMOOTH
        k_ = r_ / math.sqrt(3.0)
        offs = [Vector((0, 0, 0))] + [Vector(v_) * r_ for v_ in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0),
                                                                 (0, 0, 1), (0, 0, -1))] +                [Vector((sx_ * k_, sy_ * k_, sz_ * k_)) for sx_ in (1, -1) for sy_ in (1, -1) for sz_ in (1, -1)]

        def both(c):
            return soft_min(arm_p(c), deep_p(c), DEEP_BLEND)

        def blurred(c):
            return sum(both(c + o_) for o_ in offs) / len(offs)
        f_one = along_surface(blurred)
        f_arm = lambda v, dl: soft_min(f_one(v, dl), f_armskin(v, dl), ARM_BLEND)
    elif s["deep"] is not None:
        f_deep = along_surface(s["deep"])
        f_arm_shallow = f_arm
        f_arm = lambda v, dl: soft_min(f_arm_shallow(v, dl), f_deep(v, dl), DEEP_BLEND)
    if SHARE_CUT > 0:
        share_g = smoothed_arm_group(o, rounds=SHARE_ROUNDS)
        z_share = L["SH"] - SHARE_TOP
        # kept where the skin is mostly the torso's, or above z_share (a soft maximum: one smooth edge)
        f_share = lambda v, dl: -soft_min(-SHARE_K * (SHARE_CUT - _deform_weight(v, dl, share_g)), -(v.co.z - z_share),
                                          ARM_BLEND)
        f_arm_held = f_arm
        f_arm = lambda v, dl: soft_min(f_arm_held(v, dl), f_share(v, dl), ARM_BLEND)
    edges = [f_neck, f_arm, f_leg]
    refine_near(o, [f_neck, f_arm], band=REFINE_BAND, rounds=2)        # (the edges seen up close: finest)
    refine_near(o, [f_leg, f_panel, f_shorts], band=REFINE_BAND, rounds=1)
    cut_lines(o, edges, store=["neck_at", "arm_at", "leg_at"])
    me = o.data
    at = {n: [me.attributes[n].data[i].value for i in range(len(me.vertices))]
          for n in ("neck_at", "arm_at", "leg_at")}
    mean = lambda n, verts: sum(at[n][i] for i in verts) / len(verts)
    keep_faces(o, lambda c, w, verts: mean("neck_at", verts) > 0 and mean("arm_at", verts) > 0
               and mean("leg_at", verts) > 0, with_verts=True)
    for n in ("neck_at", "arm_at", "leg_at"):
        o.data.attributes.remove(o.data.attributes[n])
    log(build, "Singlet", "loose pieces dropped (the arms, cut off by the armholes):", keep_largest(o))
    log(build, "Singlet", "pinholes filled:", fill_pinholes(o))
    # the piping along the neck and the armholes, then the colours: lines drawn, faces chosen by the drawn values
    f_trim = lambda v, dl: min(f_neck(v, dl), f_arm(v, dl)) - PIPING
    refine_near(o, [f_trim], band=REFINE_BAND, rounds=1)
    cut_lines(o, [f_trim, f_panel, f_shorts], store=["trim_at", "panel_at", "shorts_at"])
    me = o.data
    at = {n: [me.attributes[n].data[i].value for i in range(len(me.vertices))] for n in ("trim_at", "panel_at", "shorts_at")}
    for n in at:
        me.attributes.remove(me.attributes[n])

    def key(c, w, verts):
        if mean("trim_at", verts) < 0:
            return "Trim"
        if mean("shorts_at", verts) > 0:
            return "Shorts"
        if mean("panel_at", verts) > 0:
            return "Red"
        return "Black"
    face_keys(o, key, with_verts=True)
    log(build, "Singlet", "trim-only strips dropped:", drop_trim_strips7(o))
    log(build, "Singlet", "lone colour faces matched to their neighbours:", colour_islands7(o))
    log(build, "Singlet", "points smoothed along the edges and colour lines:", relax_seams(o, SEAM_ROUNDS))
    log(build, "Singlet", "leg hems drawn in snug:", snug_hems(o, s["hem"]))
    log(build, "Singlet", "repeated faces dropped:", dedupe_faces(o))
    if SLIVER > 0:
        log(build, "Singlet", "points merged at slivers:", weld_slivers7(o, SLIVER))
    log(build, "Singlet", "hem points pushed out over the knee sleeves: %d (up to %.3f)" % clear_sleeves(o, build, s["hem"]))
    log(build, "Singlet", "hem points pushed out clear of the thigh: %d (up to %.3f)" % clear_skin_band(o, skin, s["hem"]))
    log(build, "Singlet", "folded faces smoothed out (before, left): %d, %d" % unfold7(o))
    log(build, "Singlet", "straps and armholes held by the torso:", hold_straps7(o, s["pit"]))
    drop_group(o, IS_ARM)
    drop_group(o, IS_ARM_S)
    drop_group(o, "_ArmCut")
    return o, s


# ---------------------------------------------------------------- knee sleeves v7: the approved sleeves on the skin
# v5's sleeves (a shell over each leg's smoothed shape, weights smoothed across the knee) let the kneecap push out
# through the front in the deep squat (Studio-style close-ups 2026-11-15; exact skin weights alone did not help: the
# coarse shell's flat faces sit inside the bent knee's bump). Same sleeve - same ends (knee_bot..knee_top), thickness,
# two outer accent stripes and the logo patch low on the front - but built like the tee and singlet: a layer of the
# skin itself, stacked along the same lines with the same weights, so it bends exactly with the knee.
SLEEVE7_OUT = 0.035          # the sleeve's outside off the skin (v5: 0.020-0.030 off the smoothed leg)
SLEEVE7_THICK = 0.020        # its thickness (v5's), grown inward


def build_knee_sleeves7(skin, P, N, fill, H, coll, build, body):
    o = make_layer(skin, build + "_KneeSleeve07", SLEEVE7_OUT, coll, P, N, fill)
    leg_g = group_ids(o, ("UpperLeg", "LowerLeg", "Foot"))
    z_lo, z_hi = H["knee_bot"], H["knee_top"]
    f_lo = lambda v, dl: v.co.z - z_lo
    f_hi = lambda v, dl: z_hi - v.co.z
    f_leg = lambda v, dl: _deform_weight(v, dl, leg_g) - 0.5
    refine_near(o, [f_lo, f_hi], band=REFINE_BAND, rounds=1)
    cut_lines(o, [f_lo, f_hi, f_leg], store=["lo_at", "hi_at", "leg_at"])
    me = o.data
    at = {n: [me.attributes[n].data[i].value for i in range(len(me.vertices))] for n in ("lo_at", "hi_at", "leg_at")}
    mean = lambda n, verts: sum(at[n][i] for i in verts) / len(verts)
    keep_faces(o, lambda c, w, verts: mean("lo_at", verts) > 0 and mean("hi_at", verts) > 0
               and mean("leg_at", verts) > 0, with_verts=True)
    for n in at:
        o.data.attributes.remove(o.data.attributes[n])
    o["keys"] = ["Body"] * len(o.data.polygons)
    log(build, "KneeSleeves", "points smoothed along the ends:", relax_seams(o, SEAM_ROUNDS))
    dedupe_faces(o)
    thicken_stacked(o, SLEEVE7_THICK)
    log(build, "KneeSleeves", tris(o), "triangles")
    pieces = V["split_keys"](o, coll, build + "_WornKneeSleeve")
    target = pieces["Body"]
    stripes, patches = [], []
    for side, sx in (("Left", 1), ("Right", -1)):
        rows = body.stack(side + "Leg", z_lo, z_hi, 0.04, (sx * 0.5, 0), n=48, smooth=1)
        axis = lambda z, rows=rows: F["stack_at"](rows, z)[0]
        outer = 0.0 if sx > 0 else math.pi
        for name, (a0, z0), (a1, z1) in (("Top", (0.15, z_hi - 0.035), (1.05, z_hi - 0.24)),
                                         ("Bot", (0.10, z_lo + 0.24), (0.95, z_lo + 0.035))):
            path = [(outer + sx * (a0 + (a1 - a0) * t), z0 + (z1 - z0) * t) for t in [i / 5 for i in range(6)]]
            st = V["limb_overlay"](body, coll, target, axis, path, 0.045, 0.012, build + "_SleeveStripe" + name + side)
            if st:
                stripes.append(st)
        u0, u1 = V["LOGO_U"]
        v_top = 1 - V["LOGO_ROWS"]["Red"] / 4.0
        front = -math.pi / 2
        path = [(front + 0.70 * (t - 0.5), z_lo + 0.13) for t in [i / 6 for i in range(7)]]
        pt = V["limb_overlay"](body, coll, target, axis, path, 0.11, 0.016, build + "_SleevePatch" + side,
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
        copy_weights_nearest(group[0], target)
        pieces[key] = group[0]
    materials(pieces, "WornKneeSleeve")
    return pieces


def leg_parts(pieces, prefix_of, body, coll):
    """One piece per leg per colour, under "<Side>LowerLeg" (not split by the dominant bone per face: that split runs
    across the kneecap as a zigzag and its two sides shaded apart in the bend, a jagged dark line). A skinned piece
    bends by its own weights whatever part it hangs on."""
    gf = F
    made = []
    for key, o in pieces.items():
        me = o.data
        if not any(p.use_smooth for p in me.polygons):
            for p in me.polygons:
                p.use_smooth = True
        if not me.has_custom_normals:
            me.normals_split_custom_set_from_vertices([v.normal for v in me.vertices])
        for side, sgn in (("Left", 1), ("Right", -1)):
            # (which side is +x: the LeftUpperLeg bone's side)
            lx = body.rig.data.bones["LeftUpperLeg"].head_local.x
            want = (lambda c: (c.x > 0) == (lx > 0)) if side == "Left" else (lambda c: (c.x > 0) != (lx > 0))
            nm = "%s_%s__%sLowerLeg" % (body.build, prefix_of(key), side)
            c = o.copy()
            c.data = me.copy()
            c.name = c.data.name = nm
            c.modifiers.clear()
            coll.objects.link(c)
            bm = bmesh.new()
            bm.from_mesh(c.data)
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if not want(f.calc_center_median())], context="FACES")
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
            bm.to_mesh(c.data)
            bm.free()
            if not c.data.polygons:
                bpy.data.objects.remove(c, do_unlink=True)
                continue
            mat = me.materials[0] if me.materials else None
            c.data.materials.clear()
            if mat:
                c.data.materials.append(mat)
            gf["apply_kept_normals"](c)
            c.parent = body.rig
            c.matrix_parent_inverse = Matrix.Identity(4)
            c.matrix_world = body.rig.matrix_world.copy()
            mod = c.modifiers.new("Armature", "ARMATURE")
            mod.object = body.rig
            made.append(c)
        bpy.data.objects.remove(o, do_unlink=True)
    return made


def sleeve_tree_from(pieces):
    from mathutils.bvhtree import BVHTree
    verts, faces = [], []
    for o in pieces.values():
        base = len(verts)
        verts += [o.matrix_world @ v.co for v in o.data.vertices]
        faces += [tuple(base + i for i in p.vertices) for p in o.data.polygons]
    return BVHTree.FromPolygons(verts, faces)


# ---------------------------------------------------------------- main (as v6, with the v7 singlet)
coll = bpy.data.collections.get(COLLECTION) or bpy.data.collections.new(COLLECTION)
if coll.name not in bpy.context.scene.collection.children:
    bpy.context.scene.collection.children.link(coll)
for o in list(coll.objects):
    bpy.data.objects.remove(o, do_unlink=True)
RESULT = {}
for b in BUILDS:
    body = F["Body"](b)
    H = W["heights"](body)
    skin = joined_skin7(b, coll)
    SKIN_JOINTS[0] = {k: tuple(v) for k, v in body.joints.items()}
    P, N, fill = layer_lines(skin)
    made = {}
    tee = build_tee(skin, P, N, fill, H, coll, b, body)
    drop_group(tee, IS_ARM)
    dedupe_faces(tee)
    log(b, "Tee", "points smoothed along the edges and colour lines:", relax_seams(tee, SEAM_ROUNDS))
    log(b, "Tee", "weights smoothed near the sleeve ends:", stiff_edges7(tee))
    if SLIVER > 0:                    # (prototype: the tee's crumple in the armpit at rest, beside the singlet's edge)
        log(b, "Tee", "folded faces smoothed out (before, left): %d, %d" % unfold7(tee))

    sleeves = build_knee_sleeves7(skin, P, N, fill, H, coll, b, body)
    SLEEVES_NOW[0] = sleeve_tree_from(sleeves)
    made["WornKneeSleeve"] = leg_parts(sleeves, lambda k: "WornKneeSleeve_" + k, body, coll)

    singlet, s = build_singlet7(skin, P, N, fill, H, coll, b, body)
    # the tee under the singlet held by the torso like the singlet's straps (else it rose through them with the arm)
    if TEE_PIT > 0:
        log(b, "Tee", "points smoothed in the armpits:", smooth_armpit7(tee, skin, s["pit_pts"], TEE_PIT,
                                                                         int(os.environ.get("GEAR07_TEE_PIT_ROUNDS", "12"))))
    if s["one"] is not None and DEEP_TEE_PUSH > 0:
        # (one-shape armhole) the tee seen in the opening: on the torso (not the sleeve) below the armpit, inside the
        # armhole, pushed out a little along its lines
        line = tee.data.attributes.get("line")
        armg = {g.index for g in tee.vertex_groups if "Arm" in g.name and not g.name.startswith("_")}
        pushed = 0
        for v in tee.data.vertices:
            if v.co.z > s["pit"] + 0.02 or sum(g.weight for g in v.groups if g.group in armg) > 0.5:
                continue
            inside = -s["one"](v.co)
            if inside <= 0:
                continue
            d = Vector(line.data[v.index].vector) if line is not None else Vector(v.normal)
            if d.length < 1e-6:
                continue
            v.co += d.normalized() * DEEP_TEE_PUSH * min(1.0, inside / 0.06)
            pushed += 1
        log(b, "Tee", "points inside the one-shape armhole pushed out:", pushed)
    if s["deep"] is not None and DEEP_TEE_PUSH > 0:
        # inside the deep opening the tee is seen: pushed out a little along its lines (the skin came through it in
        # small spots under the raised arm), fading out over 0.06 toward the opening's edge (the singlet covers it)
        line = tee.data.attributes.get("line")
        pushed = 0
        for v in tee.data.vertices:
            inside = -s["deep"](v.co)
            if inside <= 0:
                continue
            d = Vector(line.data[v.index].vector) if line is not None else Vector(v.normal)
            if d.length < 1e-6:
                continue
            v.co += d.normalized() * DEEP_TEE_PUSH * min(1.0, inside / 0.06)
            pushed += 1
        log(b, "Tee", "points inside the deep armhole pushed out:", pushed)
    log(b, "Tee", "points under the singlet held by the torso:",
        hold_straps7(tee, s["pit"], only=covered_by7(tee, singlet)))
    thicken_stacked(tee, FABRIC)
    log(b, "Tee", tris(tee), "triangles")
    pieces = V["split_keys"](tee, coll, b + "_Tee")
    materials(pieces, "Tee")
    made["Tee"] = to_parts(pieces, lambda k: k, body, coll)
    thicken_stacked(singlet, FABRIC, edge_key=lambda c, k: "Shorts" if k == "Shorts" else "Trim")
    # (again on the thick shell, only faces turned well against their neighbours: the rims along the edges stand at a
    # right angle to the faces beside them and are left alone)
    log(b, "Singlet", "folds in the thick shell smoothed out (before, left): %d, %d" % unfold7(singlet, thresh=-0.2))
    log(b, "Singlet", tris(singlet), "triangles")
    sp = V["split_keys"](singlet, coll, b + "_WornSinglet")
    target = sp.get("Black") or next(iter(sp.values()))
    z_logo = L["SH"] - NECK_FRONT - 0.22                               # just under the scoop, as the reference's logo
    front = V["front_patch"](body, coll, target, b + "_Singlet07Patch", z_logo, 0.46, 0.12, "Red")
    back = V["front_patch"](body, coll, target, b + "_Singlet07BackText", L["SH"] - 0.95, 0.62, 0.15, "Red", side="back")
    bpy.ops.object.select_all(action="DESELECT")
    front.select_set(True)
    back.select_set(True)
    bpy.context.view_layer.objects.active = front
    bpy.ops.object.join()
    copy_weights_nearest(front, target)
    sp["Patch"] = front
    materials(sp, "WornSinglet")
    made["WornSinglet"] = to_parts(sp, lambda k: "WornSinglet_" + k, body, coll)

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
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
log("saved", OUT_BLEND, len(keep), "pieces")
