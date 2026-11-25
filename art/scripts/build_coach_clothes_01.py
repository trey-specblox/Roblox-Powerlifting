# The coaches' clothes (user 2026-11-24, "Start the coaches cloths"): the game's own basic clothes (ClothesConfig: tee,
# long sleeve, shorts, joggers, sneakers, each with its white trim piece) moved from an approved lifter body onto each
# coach body. Coaches wear the tee, the joggers and dark sneakers in their colours (MeetFigures.build, QuestConfig).
#   blender -b art/blender/CoachBodies_01_Rigged.blend --python art/scripts/build_coach_clothes_01.py
# Writes art/blender/CoachClothes_01.blend (the coach rigs + bodies + "<Coach>_<Item>__<Part>" clothes pieces) and
# art/previews/CoachClothes01_*.png. Nothing exported or uploaded.
#
# HOW: the coach bodies are the lifters' base mesh reshaped (same points, same order, same faces), so every skin
# triangle of a lifter IS the same triangle on a coach. Each point of a lifter's finished clothes piece is pinned to
# the skin triangle under it (the closest point on the skin of the piece point's own bone part, its place inside the
# triangle, and its height above the skin along the smooth skin normal, plus any sideways offset in the triangle's own
# frame); on the coach the same triangle gives the new place, at the same height. So the clothes keep the lifter
# clothes' approved gaps, collar (the crew neck at the neck's base), hems and thickness, and the same skin weights
# (copied from the lifter piece: the coach skin carries the lifters' weights). Points shared by two pieces (the seams)
# are placed once, so no seam opens.
# Sources (the uploaded clothes 14): the tee from CartoonGear_07.blend (v7, the lowered crew neck), the rest from
# CartoonGear_05_Knee100.blend. Each coach takes each item group from the lifter body most like his (SOURCES).
import os

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

ROOT = r"D:\Powerlifting Roblox"
BLEND = os.path.join(ROOT, "art", "blender")
PREVIEWS = os.path.join(ROOT, "art", "previews")
OUT = os.environ.get("COACHCLOTHES01_OUT") or os.path.join(BLEND, "CoachClothes_01.blend")
TEE_BLEND = os.path.join(BLEND, "CartoonGear_07.blend")
REST_BLEND = os.path.join(BLEND, "CartoonGear_05_Knee100.blend")
BODIES05 = os.path.join(BLEND, "CartoonBodies_05.blend")
COACH_BODIES = os.path.join(BLEND, "CoachBodies_01.blend")
COACHES = ("Squatavious", "Benchamin", "Sumo")
GROUPS = {"Shirt": ("Tee", "TeeWhite", "LongSleeve", "LongSleeveWhite"),
          "Bottom": ("Shorts", "ShortsWhite", "Joggers", "JoggersWhite"),
          "Shoes": ("Sneakers", "SneakersSole")}
# the lifter body each coach's item group is taken from (the closest shape there; the gaps carry over either way)
SOURCES = {"Squatavious": {"Shirt": "Muscular", "Bottom": "Muscular", "Shoes": "Muscular"},
           "Benchamin": {"Shirt": "BigBuff", "Bottom": "Fit", "Shoes": "Fit"},
           "Sumo": {"Shirt": "Fit", "Bottom": "Skinny", "Shoes": "Fit"}}   # (shirt from Skinny tried: a notch in
                                                                            # the collar, the sleeve bands no better)
PARTS = ["LowerTorso", "UpperTorso"] + [s + p for s in ("Left", "Right") for p in
                                         ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")]
# the game's colours (QuestConfig.Coaches shirt / trousers; MeetFigures: dark sneakers; ClothesConfig fixed whites)
COLOURS = {"Squatavious": ((250, 206, 36), (20, 22, 30)), "Benchamin": ((226, 46, 56), (20, 22, 30)),
           "Sumo": ((70, 146, 255), (20, 22, 30))}
WHITE, SNEAKER, SOLE = (245, 245, 245), (34, 34, 38), (236, 234, 228)
CUFF_KEEP = 0.20                                    # studs above the ankle (0.252) the jogger cuff keeps its height
# the coaches' knee heights (build_coach_bodies_01.SKELETONS; the lifters' knee is 1.00)
SKELETON_K = {"Squatavious": 0.672, "Benchamin": 1.00, "Sumo": 1.352}


def log(*a):
    print("[CoachClothes01]", *a, flush=True)


PARENT_OF = {"UpperTorso": "LowerTorso"}
for _s in ("Left", "Right"):
    PARENT_OF.update({_s + "UpperArm": "UpperTorso", _s + "LowerArm": _s + "UpperArm", _s + "Hand": _s + "LowerArm",
                      _s + "UpperLeg": "LowerTorso", _s + "LowerLeg": _s + "UpperLeg", _s + "Foot": _s + "LowerLeg"})
# each part with its parent and children (the body parts it is joined to)
JOINED = {p: {p, PARENT_OF.get(p)} | {c for c, par in PARENT_OF.items() if par == p} for p in PARTS}


def load_objects(path, names):
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in names if n in src.objects]
    return {o.name: o for o in dst.objects if o is not None}


def item_of(name):
    return name.split("_", 1)[1].split("__")[0]


# ---------------------------------------------------------------- the skins (rest, rig space)
def skin_arrays(me):
    """Points, smooth normals, and triangles cut the SAME way on every body (a fan from each face's first point:
    Blender's own triangulation picks each quad's diagonal by its shape, so it differs between bodies)."""
    V = np.array([v.co for v in me.vertices], dtype=np.float64)
    N = np.array([v.normal for v in me.vertices], dtype=np.float64)
    tris, tri_face = [], []
    for p in me.polygons:
        vs = p.vertices
        for k in range(1, len(vs) - 1):
            tris.append((vs[0], vs[k], vs[k + 1]))
            tri_face.append(p.index)
    return V, N, np.array(tris, dtype=np.int64), np.array(tri_face, dtype=np.int64)


def faces_part_table(coach_body_me, coach):
    """Each face's R15 part, read off the coach's split parts (the same faces as on every body)."""
    cent = np.array([p.center for p in coach_body_me.polygons], dtype=np.float64)
    kd = KDTree(len(cent))
    for i, c in enumerate(cent):
        kd.insert(c, i)
    kd.balance()
    table = np.full(len(cent), -1, dtype=np.int64)
    for pi, part in enumerate(PARTS):
        o = bpy.data.objects.get("%s_%s" % (coach, part))
        if o is None:
            continue
        for p in o.data.polygons:
            _c, i, d = kd.find(p.center)
            if d < 1e-4:
                table[i] = pi
    assert (table >= 0).all(), "faces without a part: %d" % int((table < 0).sum())
    return table


class Pinner:
    """Pins points to a source skin and places them on a target skin with the same triangles."""

    def __init__(self, src_me, dst_me, face_part):
        self.Vs, self.Ns, self.T, self.TF = skin_arrays(src_me)
        self.Vd, self.Nd, T2, _ = skin_arrays(dst_me)
        assert (T2 == self.T).all(), "the two skins' triangles differ"
        part_of_tri = face_part[self.TF]
        self.trees = {}
        self.kds = {}
        for pi, part in enumerate(PARTS):
            sel = np.nonzero(part_of_tri == pi)[0]
            if len(sel):
                self.trees[part] = (BVHTree.FromPolygons([Vector(v) for v in self.Vs], [tuple(t) for t in self.T[sel]]), sel)
        # every skin point with the parts it belongs to (for the loose-fabric carry)
        self.vparts = [set() for _ in range(len(self.Vs))]
        for ti, t in enumerate(self.T):
            for vi in t:
                self.vparts[vi].add(PARTS[part_of_tri[ti]])
        self.kd_all = KDTree(len(self.Vs))
        for vi, v in enumerate(self.Vs):
            self.kd_all.insert(Vector(v), vi)
        self.kd_all.balance()
        self.disp = self.Vd - self.Vs
        self.cache = {}
        self.zmap = None          # the lower-leg joggers' heights (set per coach, below)

    def smooth_move(self, x, part, k=16):
        """The skin's own movement round x (its nearest points of that part AND the parts joined to it, nearer ones
        counting more): a smooth carry for loose fabric far from the skin. The joined parts count too, so fabric on two
        sides of a piece seam (Sumo's crotch: hips and thighs that move very differently) is carried alike."""
        ok = JOINED[part]
        found = [f for f in self.kd_all.find_n(Vector(x), 60) if self.vparts[f[1]] & ok][:k]
        if len(found) < 4:          # none of those parts close by: look further, then take the nearest skin at all
            found = [f for f in self.kd_all.find_n(Vector(x), 400) if self.vparts[f[1]] & ok][:k]
            if len(found) < 4:
                found = self.kd_all.find_n(Vector(x), k)
        w = np.array([1.0 / (d * d + 1e-3) for _c, _i, d in found])
        idx = [i for _c, i, _d in found]
        return x + (w[:, None] * self.disp[idx]).sum(axis=0) / w.sum()

    @staticmethod
    def bary(p, a, b, c):
        v0, v1, v2 = b - a, c - a, p - a
        d00, d01, d11 = v0 @ v0, v0 @ v1, v1 @ v1
        d20, d21 = v2 @ v0, v2 @ v1
        den = d00 * d11 - d01 * d01
        if abs(den) < 1e-14:
            return np.array([1.0, 0.0, 0.0])
        v = (d11 * d20 - d01 * d21) / den
        w = (d00 * d21 - d01 * d20) / den
        return np.array([1.0 - v - w, v, w])

    @staticmethod
    def frame(a, b, c):
        e1 = b - a
        n = np.cross(b - a, c - a)
        n /= max(np.linalg.norm(n), 1e-12)
        e1 /= max(np.linalg.norm(e1), 1e-12)
        return np.stack([e1, np.cross(n, e1), n])

    def place(self, x, part, smooth=False):
        key = tuple(np.round(x, 5))
        if key in self.cache:
            return self.cache[key]
        if smooth:
            out = self.smooth_move(x, part)
            if self.zmap is not None:
                out[2] = self.zmap(x[2])
            self.cache[key] = out
            return out
        tree, sel = self.trees[part]
        loc, _n, idx, _d = tree.find_nearest(Vector(x))
        t = self.T[sel[idx]]
        p = np.array(loc)
        a, b, c = self.Vs[t]
        w = self.bary(p, a, b, c)
        ns = w @ self.Ns[t]
        ns /= max(np.linalg.norm(ns), 1e-12)
        d = x - p
        h = d @ ns
        r = d - h * ns
        Fs = self.frame(a, b, c)
        a2, b2, c2 = self.Vd[t]
        p2 = w @ self.Vd[t]
        nd = w @ self.Nd[t]
        nd /= max(np.linalg.norm(nd), 1e-12)
        Fd = self.frame(a2, b2, c2)
        out = p2 + h * nd + Fd.T @ (Fs @ r)
        # LOOSE FABRIC (far from the skin: the jogger cuffs round the ankle, the crotch): one triangle's turn swung it
        # into spikes where the coach's skin changed shape a lot (Sumo's cuffs hung down in white teeth). Past 0.05
        # from the skin it blends into the skin's smooth movement round it, fully by 0.14.
        dist = float(np.linalg.norm(d))
        t = min(1.0, max(0.0, (dist - 0.05) / 0.09))
        if t > 0.0:
            t = t * t * (3 - 2 * t)
            out = out * (1 - t) + self.smooth_move(x, part) * t
        self.cache[key] = out
        return out


# ---------------------------------------------------------------- main
need = sorted({b for s in SOURCES.values() for b in s.values()})
src_bodies = load_objects(BODIES05, ["Body05_" + b for b in need])
coach_bodies = load_objects(COACH_BODIES, ["CoachBody01_" + c for c in COACHES])
tee_names, rest_names = [], []
for b in need:
    for g, items in GROUPS.items():
        for it in items:
            for part in PARTS:
                n = "%s_%s__%s" % (b, it, part)
                (tee_names if it in ("Tee", "TeeWhite") else rest_names).append(n)
pieces = load_objects(TEE_BLEND, tee_names)
pieces.update(load_objects(REST_BLEND, [n for n in rest_names]))
log("source pieces loaded:", len(pieces))
face_part = faces_part_table(coach_bodies["CoachBody01_" + COACHES[0]].data, COACHES[0])

coll = bpy.data.collections.new("CoachClothes")
bpy.context.scene.collection.children.link(coll)
made = {}
for coach in COACHES:
    rig = bpy.data.objects[coach + "Rig"]
    dst_me = coach_bodies["CoachBody01_" + coach].data
    for group, items in GROUPS.items():
        src_build = SOURCES[coach][group]
        pin = Pinner(src_bodies["Body05_" + src_build].data, dst_me, face_part)
        # THE JOGGERS' LOWER LEGS keep the cuff's own height: up to CUFF_KEEP above the ankle nothing moves up or down
        # (the cuff band and the fabric just above the shoe), and only the shin above it is stretched or squashed to
        # the coach's knee. Carried by the skin's shin, Squatavious's half-length shins (knee 0.672, lifters 1.00)
        # crushed the cuff band to a ragged sliver.
        A_, Ks, Kc = 0.252, 1.00, SKELETON_K[coach]
        top = A_ + CUFF_KEEP
        pin.zmap = (lambda z, top=top, Ks=Ks, Kc=Kc: z if z <= top else top + (z - top) * (Kc - top) / (Ks - top))
        for name in sorted(n for n in pieces if n.startswith(src_build + "_") and item_of(n) in items):
            src = pieces[name]
            src_rig = src.parent
            local = (src_rig.matrix_world.inverted() if src_rig else Matrix.Identity(4)) @ src.matrix_world
            groups = {g.index: g.name for g in src.vertex_groups}
            me = src.data.copy()
            new_co = []
            for v in src.data.vertices:
                x = np.array(local @ v.co, dtype=np.float64)
                ws = [(g.weight, groups[g.group]) for g in v.groups if groups.get(g.group) in PARTS]
                bone = max(ws)[1] if ws else name.split("__")[-1]
                if bone not in pin.trees:          # hands carry no skin: their arm's lower part instead
                    bone = bone.replace("Hand", "LowerArm")
                # the joggers below the knee are loose all round: carried smoothly as a whole (pinned point by point,
                # Squatavious's half-length shins crushed the cuff band into a ragged sliver with a flap). The lower-leg
                # pieces come first in name order, so the knee seam takes this rule on both sides.
                # (tried on the tee's white sleeve bands too: worse, the bands flared away from the pinned sleeves)
                smooth = item_of(name).startswith("Joggers") and name.endswith("LowerLeg")
                new_co.append(pin.place(x, bone, smooth=smooth))
            me.vertices.foreach_set("co", np.array(new_co, dtype=np.float32).ravel())
            me.update()
            new_name = coach + "_" + name.split("_", 1)[1]
            o = bpy.data.objects.new(new_name, me)
            me.name = new_name
            for g in src.vertex_groups:
                o.vertex_groups.new(name=g.name)
            coll.objects.link(o)
            o.parent = rig
            o.matrix_parent_inverse = Matrix.Identity(4)
            o.matrix_basis = Matrix.Identity(4)
            o.modifiers.new("Armature", "ARMATURE").object = rig
            made.setdefault(coach, []).append(o)
        log(coach, group, "from", src_build, "points pinned:", len(pin.cache))
    log(coach, "pieces:", len(made[coach]), "triangles (tee + joggers + sneakers):",
        sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in made[coach]
            if item_of(o.name) in ("Tee", "TeeWhite", "Joggers", "JoggersWhite", "Sneakers", "SneakersSole")))

# vertex groups were created empty above: copy each point's weights from its source piece (same point order)
for coach in COACHES:
    for o in made[coach]:
        src = pieces[SOURCES[coach][[g for g, its in GROUPS.items() if item_of(o.name) in its][0]] + "_" +
                     o.name.split("_", 1)[1]]
        names = {g.index: g.name for g in src.vertex_groups}
        for v in src.data.vertices:
            for g in v.groups:
                o.vertex_groups[names[g.group]].add([v.index], g.weight, "REPLACE")


# ---------------------------------------------------------------- relief: room where the coach's moves need it
# gear_fit_03.pose_relief's method, for pieces already split by body part (points shared by pieces move together):
# the skin points an item covers at rest are checked in the coach's moves (the game's coach animations, posed as Roblox
# does); wherever one comes out THROUGH a face of the item, that face's points move out at rest by the depth plus a
# small margin (at most RELIEF_CAP), spread to their neighbours and evened out, a few rounds. The joggers also treat the
# tee as something under them (the tee hem showed through the waistband). Measured against the lifters' approved
# clothes with art/scripts/check_coach_clothes_01.py.
RELIEF_POSES = [None, "Chalk_Coach_Talk", "Chalk_Coach_Back", "Emote_ChalkClap", "Entrance_Walk_Swagger"]
RELIEF_MARGIN, RELIEF_CAP, RELIEF_ROUNDS = 0.012, 0.09, 4
GF = {"__name__": "gear_fit_03"}
exec(open(os.path.join(ROOT, "art", "scripts", "gear_fit_03.py"), encoding="utf-8").read(), GF)
SKIN_PARTS = [p for p in PARTS if "Hand" not in p]


def evaluated_world(o):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = o.evaluated_get(dg)
    me = ev.to_mesh()
    V = [o.matrix_world @ v.co for v in me.vertices]
    N = [(o.matrix_world.to_3x3() @ v.normal).normalized() for v in me.vertices]
    F = [tuple(p.vertices) for p in me.polygons]
    ev.to_mesh_clear()
    return V, N, F


def relieve(coach, objs, under_objs):
    rig = bpy.data.objects[coach + "Rig"]
    keyof = {}
    for o in objs:
        keyof[o.name] = [tuple(round(c, 4) for c in v.co) for v in o.data.vertices]
    nbr = {}
    for o in objs:
        ks = keyof[o.name]
        for e in o.data.edges:
            a, b = ks[e.vertices[0]], ks[e.vertices[1]]
            nbr.setdefault(a, set()).add(b)
            nbr.setdefault(b, set()).add(a)
    under = [bpy.data.objects[coach + "_" + p] for p in SKIN_PARTS] + list(under_objs)
    biggest = 0.0
    for _round in range(RELIEF_ROUNDS):
        need = {}
        GF["rest_rig"](rig)
        cover = {}
        gv, gf, gkey = [], [], []
        for o in objs:
            V, _N, F = evaluated_world(o)
            base = len(gv)
            gv += V
            gf += [tuple(base + i for i in f) for f in F]
            gkey += keyof[o.name]
        tree = BVHTree.FromPolygons(gv, gf)
        for u in under:
            V, N, _F = evaluated_world(u)
            # (0.2: the joggers' loosest gap; at 0.15 the loose shins of Squatavious's joggers were skipped)
            cover[u.name] = [i for i in range(len(V)) if tree.ray_cast(V[i] + N[i] * 0.0005, N[i], 0.2)[0] is not None]
        for anim in RELIEF_POSES:
            GF["rest_rig"](rig)
            if anim:
                GF["pose_rig"](rig, GF["anim_at"](anim, GF["extreme_time"](anim)))
            gv, gf = [], []
            for o in objs:
                V, _N, F = evaluated_world(o)
                base = len(gv)
                gv += V
                gf += [tuple(base + i for i in f) for f in F]
            tree = BVHTree.FromPolygons(gv, gf)
            for u in under:
                V, N, _F = evaluated_world(u)
                for i in cover[u.name]:
                    p, n = V[i], N[i]
                    loc, fn, fi, d = tree.ray_cast(p + n * 0.0005, -n, 0.25)
                    if loc is None or fn.dot(-n) >= 0:
                        continue
                    for vi in gf[fi]:
                        k = gkey[vi]
                        need[k] = max(need.get(k, 0.0), d + RELIEF_MARGIN)
        GF["rest_rig"](rig)
        if not need:
            break
        keys = list(nbr.keys())
        val = {k: need.get(k, 0.0) for k in keys}
        for _ in range(3):
            val = {k: max(val[k], 0.7 * max((val[j] for j in nbr[k]), default=0.0)) for k in keys}
        for _ in range(4):
            val = {k: 0.5 * val[k] + 0.5 * sum(val[j] for j in nbr[k]) / len(nbr[k]) for k in keys}
        # move out along the rest skin's normal under each point (rig space = these objects' own space)
        skin_tree = BVHTree.FromPolygons([Vector(v) for v in pin_rest[coach][0]], [tuple(t) for t in pin_rest[coach][1]])
        moved = 0
        for o in objs:
            ks = keyof[o.name]
            for v, k in zip(o.data.vertices, ks):
                amount = min(RELIEF_CAP, val.get(k, 0.0))
                if amount <= 1e-4:
                    continue
                _loc, nrm, _fi, _d = skin_tree.find_nearest(v.co)
                v.co = v.co + nrm.normalized() * amount
                biggest = max(biggest, amount)
                moved += 1
            o.data.update()
        # the moved points' keys change: re-key so seams stay together next round
        for o in objs:
            new = [tuple(round(c, 4) for c in v.co) for v in o.data.vertices]
            remap = dict(zip(keyof[o.name], new))
            keyof[o.name] = new
            nbr = {remap.get(a, a): {remap.get(b, b) for b in bs} for a, bs in nbr.items()}
        log(coach, [item_of(o.name) for o in objs][0], "relief round", _round + 1, "points to move:", len(need),
            "moved:", moved)
    return biggest


pin_rest = {}
for coach in COACHES:
    me = coach_bodies["CoachBody01_" + coach].data
    V, _N, T, _TF = skin_arrays(me)
    pin_rest[coach] = (V, T)
for coach in COACHES:
    groups = {}
    for o in made[coach]:
        groups.setdefault([g for g, its in GROUPS.items() if item_of(o.name) in its][0], {}).setdefault(
            item_of(o.name).replace("White", "").replace("Sole", ""), []).append(o)
    # (not the sneakers: relieving them for the walk's bent foot swelled one shoe up; the lifters' approved sneakers
    # show the same few foot points in the walk, check_coach_clothes_01 baseline)
    for group in ("Shirt", "Bottom"):
        for item, objs in groups[group].items():
            under = groups["Shirt"]["Tee"] if item == "Joggers" else []
            big = relieve(coach, objs, under)
            log(coach, item, "relief: largest move %.3f" % big)


# ---------------------------------------------------------------- shading normals for the NEW shape
# The source pieces carry custom shading normals made for the lifter's shape (copied with the mesh): on the coach they
# drew spiky creases. Each point gets the smooth normal of its item's whole surface on the coach, averaged over every
# piece that shares the point (the item is cut into pieces by body part; one normal per place, so no seam line shows).
def reshade(objs):
    acc = {}
    for o in objs:
        o.data.free_normals_split() if hasattr(o.data, "free_normals_split") else None
        for v in o.data.vertices:
            key = tuple(round(c, 4) for c in v.co)
            acc.setdefault(key, Vector((0, 0, 0)))
            acc[key] += v.normal
    for o in objs:
        normals = []
        for v in o.data.vertices:
            n = acc[tuple(round(c, 4) for c in v.co)]
            normals.append(n.normalized() if n.length > 1e-9 else v.normal)
        for p in o.data.polygons:
            p.use_smooth = True
        o.data.normals_split_custom_set_from_vertices(normals)


for coach in COACHES:
    by_item = {}
    for o in made[coach]:
        if o.data.has_custom_normals:
            bpy.context.view_layer.objects.active = o
            with bpy.context.temp_override(object=o, active_object=o):
                bpy.ops.mesh.customdata_custom_splitnormals_clear()
        by_item.setdefault(item_of(o.name), []).append(o)
    for item, objs in by_item.items():
        reshade(objs)


# ---------------------------------------------------------------- materials (the coaches' colours, for the pictures)
def mat(name, rgb):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    lin = tuple(((c / 255.0) ** 2.2) for c in rgb)
    m.diffuse_color = lin + (1.0,)
    return m


for coach in COACHES:
    shirt, trousers = COLOURS[coach]
    for o in made[coach]:
        it = item_of(o.name)
        colour = {"Tee": shirt, "LongSleeve": shirt, "Joggers": trousers, "Shorts": trousers, "Sneakers": SNEAKER,
                  "SneakersSole": SOLE}.get(it, WHITE)
        o.data.materials.clear()
        o.data.materials.append(mat("Coach_%s_%s" % (coach, it), colour))
        for p in o.data.polygons:
            p.use_smooth = True
        o.hide_render = it not in ("Tee", "TeeWhite", "Joggers", "JoggersWhite", "Sneakers", "SneakersSole")

# only the coaches stay in the file
for o in list(bpy.data.objects):
    if not o.users_collection:
        bpy.data.objects.remove(o, do_unlink=True)
bpy.data.orphans_purge(do_recursive=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT)
log("saved", OUT)
