# Layer check for the gear worn OVER the clothes (user 2026-11-16: "gear should act as a ACCESSORY"), read-only (the
# .blend is NOT saved): on every build, the whole Tee under the singlet (and each suit), the singlet / suits under the
# belt, posed through the game's animations (art/animations, every file, sampled every STEP seconds and at each one's
# hardest moment). A point "shows through" when a tee point the singlet covers at rest no longer has the singlet straight
# out along its normal in the pose (it came out through it, or the singlet slid off it); the same for the belt.
#   blender -b art/blender/CartoonGear_05.blend --python art/scripts/check_layers_05.py -- <out_txt> [quick]
# quick: only gear_fit_03.CHECK_POSES (the lifts, set-up, walks, raises). Env LAYER_BUILDS=Fit,BigBuff for a subset,
# LAYER_ANIMS=Setup_Squat,... for some animations only (each still sampled every STEP).
import glob
import os
import sys

import bpy
from mathutils.bvhtree import BVHTree

ROOT = r"D:\Powerlifting Roblox"
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else os.path.join(ROOT, "art", "previews", "gear05_layers.txt")
QUICK = len(argv) > 1 and argv[1] == "quick"
STEP = 0.25
G = {"__name__": "gear_fit_03"}
exec(open(os.path.join(ROOT, "art", "scripts", "gear_fit_03.py")).read(), G)
G["ANIMS"] = os.path.join(ROOT, "art", "animations")
ORDER = ("Skinny", "SkinnyFat", "Fat", "Fit", "Muscular", "BigBuff")
BUILDS = [b for b in os.environ.get("LAYER_BUILDS", ",".join(ORDER)).split(",") if bpy.data.objects.get(b + "Rig")]
SHOW = 0.002                     # outside by more than this = shows through


def pieces(build, heads):
    return [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(build + "_") and "__" in o.name
            and o.name[len(build) + 1:].split("__")[0] in heads]


def heads_of(build, worn):
    return {o.name[len(build) + 1:].split("__")[0] for o in bpy.data.objects
            if o.name.startswith("%s_%s_" % (build, worn)) and "__" in o.name}


def joined(objs, rig, posed):
    vs, fs = [], []
    for o in objs:
        if posed:
            pts, faces = G["evaluated_points"](o, rig)
        else:
            m = rig.matrix_world.inverted() @ o.matrix_world
            pts = [m @ v.co for v in o.data.vertices]
            faces = [tuple(p.vertices) for p in o.data.polygons]
        base = len(vs)
        vs += pts
        fs += [tuple(base + i for i in f) for f in faces]
    return vs, fs


def rest_normals(objs, rig):
    out = []
    for o in objs:
        m = (rig.matrix_world.inverted() @ o.matrix_world).to_3x3()
        out += [(m @ v.normal).normalized() for v in o.data.vertices]
    return out


EDGE_MARGIN = 0.06               # a point covered within this of the layer's edge is left out (the layer's edge
                                 # sliding a little over the tee shows tee beside it, which is how it should look)


def covered(under, over, rig, reach=0.15):
    """Indices of `under`'s points that `over` covers at rest (a ray straight out meets it, away from its edges)."""
    import bmesh
    from mathutils.kdtree import KDTree
    G["rest_rig"](rig)
    uv, _uf = joined(under, rig, False)
    un = rest_normals(under, rig)
    ov, of = joined(over, rig, False)
    tree = BVHTree.FromPolygons(ov, of)
    rim = []
    for o in over:                                   # each piece's own open edges, minus the cuts between pieces
        m = rig.matrix_world.inverted() @ o.matrix_world
        bm = bmesh.new()
        bm.from_mesh(o.data)
        rim += [m @ v.co for v in bm.verts if v.is_boundary]
        bm.free()
    # (a cut between two pieces is boundary in both: such points have another piece's point at the same place)
    kd_all = KDTree(len(rim))
    for i, p in enumerate(rim):
        kd_all.insert(p, i)
    kd_all.balance()
    real = [p for p in rim if len(kd_all.find_range(p, 1e-4)) < 2]
    kd = KDTree(max(1, len(real)))
    for i, p in enumerate(real):
        kd.insert(p, i)
    kd.balance()
    out = []
    for i, (p, n) in enumerate(zip(uv, un)):
        hit = tree.ray_cast(p + n * 0.002, n, reach)[0]
        if hit is None or (real and kd.find(hit)[2] <= EDGE_MARGIN):
            continue
        # also EDGE_MARGIN away from the layer's edge sideways: the same ray moved that far along the surface four
        # ways must still meet the layer (a thick, closed layer such as the belt has no open edge to measure from)
        t1 = n.orthogonal().normalized()
        t2 = n.cross(t1).normalized()
        if all(tree.ray_cast(p + d * EDGE_MARGIN + n * 0.002, n, reach)[0] is not None for d in (t1, -t1, t2, -t2)):
            out.append(i)
    return out


def posed_with_normals(objs, rig):
    """The objects as drawn now (armature applied), rig space: points and their normals."""
    dg = bpy.context.evaluated_depsgraph_get()
    pts, nrm = [], []
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        m = rig.matrix_world.inverted() @ o.matrix_world
        m3 = m.to_3x3()
        pts += [m @ v.co for v in me.vertices]
        nrm += [(m3 @ v.normal).normalized() for v in me.vertices]
        ev.to_mesh_clear()
    return pts, nrm


def seam_groups(objs, rig):
    """Points that sit at the same place at rest (a garment is cut into one piece per body part: the cut's points are
    in both pieces): each point's group, so normals can be averaged across the cut (a piece's own normals at its cut
    edge are one-sided and pointed the test's ray off sideways)."""
    G["rest_rig"](rig)
    pts, _f = joined(objs, rig, False)
    key = {}
    group = []
    for p in pts:
        k = (round(p.x, 4), round(p.y, 4), round(p.z, 4))
        group.append(key.setdefault(k, len(key)))
    return group


def through(under, over, rig, idx, groups, reach=0.25):
    """(how many of the covered points show through `over` now, how far the worst is past it). A point counts only
    when two tests agree: the layer is no longer straight out along its normal (averaged across piece cuts), AND the
    nearest face of the layer has it on its outer side (beyond SHOW)."""
    from mathutils import Vector
    uv, un = posed_with_normals(under, rig)
    acc = {}
    for g, n in zip(groups, un):
        acc[g] = acc.get(g, Vector()) + n
    un = [acc[g].normalized() for g in groups]
    ov, of = joined(over, rig, True)
    tree = BVHTree.FromPolygons(ov, of)
    n, worst = 0, 0.0
    for i in idx:
        if tree.ray_cast(uv[i] + un[i] * 0.001, un[i], reach)[0] is not None:
            continue
        loc, nrm, _f, d = tree.find_nearest(uv[i], 0.5)
        if loc is None or (uv[i] - loc).dot(nrm) <= SHOW:
            continue
        n += 1
        worst = max(worst, d)
    return n, worst


def poses():
    if QUICK:
        return [(label, anim, t) for label, anim, t in G["CHECK_POSES"]]
    out = [("Rest", None, None)]
    only = [a for a in os.environ.get("LAYER_ANIMS", "").split(",") if a]
    for path in sorted(glob.glob(os.path.join(G["ANIMS"], "*.rbxmx"))):
        name = os.path.splitext(os.path.basename(path))[0]
        if only and name not in only:
            continue
        frames = G["read_anim"](name)
        if not frames:
            continue
        end = frames[-1][0]
        times = sorted({round(k * STEP, 3) for k in range(int(end / STEP) + 1)} | {G["extreme_time"](name)})
        out += [(name, name, t) for t in times]
    return out


POSES = poses()
lines = ["check_layers_05: %d poses (%s), builds %s; 'shows' = covered points with the layer no longer straight out "
         "over them AND on its outer side (distance back to it in brackets)" % (len(POSES), "quick" if QUICK else
                                                           "every animation every %.2f s" % STEP, ",".join(BUILDS))]
summary = []
for b in BUILDS:
    rig = bpy.data.objects[b + "Rig"]
    tee = pieces(b, {"Tee", "TeeWhite"})
    belt = pieces(b, heads_of(b, "WornLeverBelt"))
    pairs = []
    for worn in ("WornSinglet", "WornSquatSuit", "WornDeadliftSuit"):
        over = pieces(b, heads_of(b, worn))
        if tee and over:
            pairs.append(("Tee under " + worn, tee, over))
        if over and belt:
            pairs.append((worn + " under belt", over, belt))
    if tee and belt:
        pairs.append(("Tee under belt", tee, belt))
    skin = [bpy.data.objects[b + "_" + p] for p in G["PARTS"] if not p.endswith("Hand") and bpy.data.objects.get(b + "_" + p)]
    if tee and skin:
        pairs.insert(0, ("Body under Tee", skin, tee))
    cov = {label: covered(u, o, rig) for label, u, o in pairs}
    grp = {label: seam_groups(u, rig) for label, u, o in pairs}
    worst = {label: (0, 0.0, "") for label, _u, _o in pairs}
    per_anim = {}
    for label_p, anim, t in POSES:
        if anim is None:
            G["rest_rig"](rig)
        else:
            G["pose_rig"](rig, G["anim_at"](anim, G["extreme_time"](anim) if t is None else t))
        for label, u, o in pairs:
            n, d = through(u, o, rig, cov[label], grp[label])
            if n:
                key = (label, label_p)
                c, dd, tt = per_anim.get(key, (0, 0.0, 0.0))
                if n > c:
                    per_anim[key] = (n, max(dd, d), t)
                elif d > dd:
                    per_anim[key] = (c, d, tt)
            if n > worst[label][0] or (n == worst[label][0] and d > worst[label][1]):
                worst[label] = (n, d, "%s@%s" % (label_p, t))
    G["rest_rig"](rig)
    for label, _u, _o in pairs:
        n, d, where = worst[label]
        bad = sorted(((c, dd, a, tt) for (lb, a), (c, dd, tt) in per_anim.items() if lb == label), reverse=True)
        lines.append("%-9s %-28s covered %4d  worst %3d points (%.3f) at %s; %d animations with any" % (
            b, label, len(cov[label]), n, d, where or "-", len(bad)))
        for c, dd, a, tt in bad[:8]:
            lines.append("            %-34s %3d points (%.3f) at %s s" % (a, c, dd, tt))
        summary.append((b, label, n, d, len(bad)))
    print("[Layers]", b, "done", flush=True)
lines.append("")
lines.append("SUMMARY (build, layer pair, worst points, deepest, animations with any)")
for row in summary:
    lines.append("  %-9s %-28s %4d  %.3f  %3d" % row)
open(OUT, "w").write("\n".join(lines))
print("[Layers] wrote", OUT, flush=True)
