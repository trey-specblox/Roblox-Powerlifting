# Builds WornMedal_01: the medal a lifter WEARS round the neck after a meet, and the medal a referee HOLDS open
# before putting it on (art/blender/WornMedal_01.blend, art/exports/WornMedal_*.glb, HeldMedal_Ribbon.glb).
#
# The look is the wall Medal prop's (build_room_props_06.py, "Index"): a disc with a raised rim, a small ring on top
# and CENTRAL on its face, on a ribbon; the same three pieces Disc / Ribbon / Text, so the same colourways apply
# (StarterGymConfig.PropColourways.Medal: gold = Brass + Red, silver = Silver + Blue, bronze = Bronze + Forest).
#
#   WornMedal_Disc            the disc + rim + ring, ONE mesh for every build (reused), modelled facing front
#   WornMedal_Text            CENTRAL, raised on the disc's face (0.03 proud: never in the disc's plane, no flicker)
#   WornMedal_Ribbon_<Build>  one closed ribbon loop per build: from the ring up both sides of the chest, over the
#                             traps / collarbones and round the BACK of the neck at its base (the tee's crew collar),
#                             fitted to that build's outermost clothes (singlet over tee) with a 0.02-0.05 clearance
#   HeldMedal_Ribbon          the ribbon held open by both hands (an open loop, the disc hanging in the front V)
#
# Rigid: every piece is welded to the UpperTorso in game (the held one to the referee's hand). The script prints, and
# writes to art/exports/WornMedal_01_fit.json, each piece's CFrame in UpperTorso space per build (from the UpperTorso
# MeshPart's centre, which is its mesh's bounds centre: checked against ClothesConfig.neckMark) and the held medal's
# hold points.
#
# Fitting: the meet outfit is the game's own export (the newest art/exports/CartoonClothes<NN>_<Build>.glb and
# CartoonGear<NN>_<Build>.glb, loaded onto the build's rig exactly as anim_qa.py does), rest pose. The ribbon's path is
# laid on the OUTERMOST layer by rays from outside (first hit = the singlet where it is, else the tee), then every
# vertex of its inner face is checked again and pushed out to the clearance where needed.
#
#   blender -b art/blender/CartoonBodies_05_Rigged.blend --python art/scripts/build_worn_medal_01.py
# The bodies file is only read: the result is saved AS art/blender/WornMedal_01.blend with the medal pieces only.
# Env: MEDAL_PREVIEW_DIR (default D:\ClaudeScratch\medal) for the pictures; MEDAL_PREVIEWS=0 skips them.
# Then: blender -b art/blender/WornMedal_01.blend --python art/scripts/check_models.py  (must end CHECK PASSED)
import glob
import importlib
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
EXPORTS = os.path.join(ROOT, "art", "exports")
OUT_BLEND = os.path.join(ROOT, "art", "blender", "WornMedal_01.blend")
PREVIEW_DIR = os.environ.get("MEDAL_PREVIEW_DIR", r"D:\ClaudeScratch\medal")
PREVIEWS = os.environ.get("MEDAL_PREVIEWS", "1") != "0"
sys.path.insert(0, SCRIPTS)
import prop_helpers as H  # noqa: E402

importlib.reload(H)
BRAND = H.BRAND
BUILDS = tuple(os.environ.get("MEDAL_BUILDS", "Skinny,SkinnyFat,Fit,Fat,Muscular,BigBuff").split(","))


def log(*a):
    print("[WornMedal]", *a, flush=True)


# ---------------------------------------------------------------- sizes (studs)
DISC_R = 0.30          # the prop's 0.38, sized for the chest
DISC_T = 0.06          # thickness
RIM_R, RIM_TUBE = DISC_R - 0.03, 0.022       # raised rim on the front face
RING_Z, RING_R, RING_TUBE = DISC_R + 0.025, 0.055, 0.018   # the small ring on top the ribbon goes through
TEXT_SIZE, TEXT_PROUD, TEXT_SINK = 0.09, 0.03, 0.01
RIB_W, RIB_T = 0.20, 0.025                   # ribbon width and thickness
RIB_W_TIP, TAPER = 0.05, 0.35                # bunched at the ring, full width this far up
TIP_R = 0.035                                # the ribbon's turn through the ring
CLEAR = 0.03           # the ribbon's / disc's inner face from the clothes
CLEAR_MIN = 0.02       # never closer (pushed out to CLEAR)
FLOAT_MAX = 0.06       # reported above this (a visible gap)
DISC_Z = 3.72          # the disc's centre height (rig space; every build: shoulders 4.38, belt top ~3.07)
THETA_S = 100.0        # where the ribbon leaves the collar line to go down the chest (degrees from the back)
NECK_CY = -0.07        # the crew neck oval's middle (tee_neck_fix.py)
STEP = 0.025           # ribbon centreline spacing (the held ribbon; the drape works at this too)
STEP_WORN = 0.035      # the worn ribbon's final spacing (fewer triangles: ~2,500 per build)

# Colours (StarterGymConfig.PropPaints, sRGB 0-255) and the three colourways (PropColourways.Medal's first three).
PAINT = {"Brass": (200, 160, 82), "Silver": (190, 192, 198), "Bronze": (176, 110, 60), "Red": (200, 30, 38),
         "Blue": (30, 92, 205), "Forest": (34, 98, 62), "Coffee": (62, 34, 20), "Charcoal": (46, 48, 54)}
METAL = {"Brass", "Silver", "Bronze"}
COLOURWAYS = [{"Disc": "Brass", "Ribbon": "Red", "Text": "Coffee"},       # gold
              {"Disc": "Silver", "Ribbon": "Blue", "Text": "Charcoal"},   # silver
              {"Disc": "Bronze", "Ribbon": "Forest", "Text": "Coffee"}]   # bronze


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


MAT = {k: H.material("WM_" + k, tuple(linear(c) for c in v), 1.0 if k in METAL else 0.0, 0.45) for k, v in PAINT.items()}
B = H.Builder("WornMedal")


def to_rbx(v):
    """Blender (x = the character's left, -y front, z up) -> Roblox (x right, y up, -z front): gear_fit_03 TO_B."""
    return Vector((-v.x, v.z, v.y))


M_RBX = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))


def smoothstep(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- the meet outfit on every build (anim_qa.py's way)
ITEMS = ("Tee,WornSinglet_Black,WornSinglet_Red,WornSinglet_Shorts,WornSinglet_Trim,"
         "WornLeverBelt_Outer,WornLeverBelt_Lining,WornLeverBelt_Lever").split(",")
BODY_PARTS = ["UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
              "LeftHand", "RightHand", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
              "LeftFoot", "RightFoot"]
rigs = {b: bpy.data.objects[b + "Rig"] for b in BUILDS}
for r in rigs.values():
    r.data.pose_position = "REST"
OUTFIT = {b: [] for b in BUILDS}
USED_EXPORTS = set()
for b in BUILDS:
    before = set(bpy.data.objects)
    for kind in ("Clothes", "Gear"):
        found = sorted(glob.glob(os.path.join(EXPORTS, "Cartoon%s[0-9][0-9]_%s.glb" % (kind, b))))
        if found:
            USED_EXPORTS.add(os.path.basename(found[-1]).split("_")[0])
            bpy.ops.import_scene.gltf(filepath=found[-1])
    kept = []
    for o in [o for o in bpy.data.objects if o not in before]:
        item, _, part = o.name.partition("__")
        if o.type == "MESH" and item in ITEMS:
            ref = bpy.data.objects[b + "_UpperTorso"]
            rel = ref.matrix_parent_inverse @ ref.matrix_basis
            o.data.transform(rel.inverted() @ o.matrix_world)
            o.parent = rigs[b]
            o.matrix_parent_inverse = ref.matrix_parent_inverse.copy()
            o.matrix_basis = ref.matrix_basis.copy()
            for m in o.modifiers:
                if m.type == "ARMATURE":
                    m.object = rigs[b]
            kept.append(o)
        else:
            bpy.data.objects.remove(o, do_unlink=True)
    xs = [v.co.x for o in kept if o.name.partition("__")[2].split(".")[0] == "UpperTorso" for v in o.data.vertices]
    if xs:
        body = [v.co.x for v in bpy.data.objects[b + "_UpperTorso"].data.vertices]
        shift = (min(body) + max(body)) / 2 - (min(xs) + max(xs)) / 2
        shift = shift if abs(shift) > 0.5 else 0.0
        for o in kept:
            o.data.transform(Matrix.Translation(Vector((shift, 0, 0))))
    for o in kept:
        o.name = "Preview_%s_%s" % (b, o.name)
    OUTFIT[b] = kept
bpy.context.view_layer.update()
log("outfit exports used:", sorted(USED_EXPORTS))
DG = bpy.context.evaluated_depsgraph_get()


def local_tris(objs, rig):
    """The objects' evaluated meshes (rest pose) in the rig's own space."""
    vs, fs = [], []
    inv = rig.matrix_world.inverted()
    for o in objs:
        ev = o.evaluated_get(DG)
        m = ev.to_mesh()
        M = inv @ o.matrix_world
        k = len(vs)
        vs += [M @ v.co for v in m.vertices]
        fs += [tuple(i + k for i in p.vertices) for p in m.polygons]
        ev.to_mesh_clear()
    return vs, fs


class Surface:
    """One build's outermost layer (outfit + body, head apart) in rig space."""

    def __init__(self, b):
        self.b = b
        rig = rigs[b]
        body = [bpy.data.objects[b + "_" + n] for n in BODY_PARTS]
        vs, fs = local_tris(OUTFIT[b] + body, rig)
        self.tree = BVHTree.FromPolygons(vs, fs)
        hv, hf = local_tris([bpy.data.objects[b + "_StandInHead"]], rig)
        self.head = BVHTree.FromPolygons(hv, hf)
        tv, tf = local_tris([bpy.data.objects[b + "_UpperTorso"]], rig)
        self.ut_centre = Vector([(min(v[i] for v in tv) + max(v[i] for v in tv)) / 2 for i in range(3)])
        # the tee's crew collar: the open edges of its UpperTorso piece round the neck
        tee = next(o for o in OUTFIT[b] if o.name.endswith("Tee__UpperTorso"))
        ev = tee.evaluated_get(DG)
        m = ev.to_mesh()
        bm = bmesh.new()
        bm.from_mesh(m)
        M = rig.matrix_world.inverted() @ tee.matrix_world
        pts = [M @ v.co for e in bm.edges if e.is_boundary for v in e.verts]
        bm.free()
        ev.to_mesh_clear()
        pts = [p for p in pts if p.z > 4.0 and abs(p.x) < 0.75]
        self.collar_pts = pts

        # the collar line by angle round the neck (degrees from the back, both sides merged), every 5 degrees; angles
        # with no edge found are filled in between their neighbours
        bins = {}
        for p in pts:
            k = int(round(math.degrees(math.atan2(abs(p.x), p.y - NECK_CY)) / 5)) * 5
            bins.setdefault(k, []).append(p)
        known = {}
        for k, ps in bins.items():
            r = sorted(ps, key=lambda p: math.hypot(p.x, p.y - NECK_CY))[:max(1, (len(ps) + 1) // 2)]
            known[k] = (sum(math.hypot(p.x, p.y - NECK_CY) for p in r) / len(r), sum(p.z for p in r) / len(r))
        ks = sorted(known)
        self.collar_table = {}
        for k in range(0, 181, 5):
            lo_k = max([x for x in ks if x <= k], default=ks[0])
            hi_k = min([x for x in ks if x >= k], default=ks[-1])
            f = 0 if hi_k == lo_k else (k - lo_k) / (hi_k - lo_k)
            self.collar_table[k] = tuple(known[lo_k][i] * (1 - f) + known[hi_k][i] * f for i in range(2))
        log("%s collar (deg: radius, z):" % b, " ".join("%d:%.2f,%.2f" % (k, *self.collar_table[k])
                                                         for k in range(0, 181, 15)), "measured at", ks)

    def collar(self, theta):
        """The collar line at `theta` degrees from the back (+ toward the build's left, +x)."""
        t = min(180.0, abs(theta))
        k0 = int(t // 5) * 5
        k1 = min(180, k0 + 5)
        f = (t - k0) / 5
        rad, z = (self.collar_table[k0][i] * (1 - f) + self.collar_table[k1][i] * f for i in range(2))
        a = math.radians(t)
        return Vector((math.copysign(1, theta) * rad * math.sin(a), NECK_CY + rad * math.cos(a), z))

    def hit(self, origin, direction, tree=None):
        loc, nrm, _i, d = (tree or self.tree).ray_cast(origin, direction, 8.0)
        if loc is None:
            return None, None
        if nrm.dot(direction) > 0:
            nrm = -nrm
        return loc, nrm

    def gap(self, p, n, reach=0.5):
        """How far p is outside the outermost layer along n (negative = inside it)."""
        loc, _n = self.hit(p + n * reach, -n)
        if loc is None:
            return 9.0
        return (loc - (p + n * reach)).length - reach


SURF = {}
for b in BUILDS:
    SURF[b] = Surface(b)
    s = SURF[b]
    nm = to_rbx(Vector((0, 0, 4.7)) - s.ut_centre)
    log("%s UpperTorso centre (rig space) %s; neck mark from it (Roblox) %.4f %.4f %.4f" % (
        b, tuple(round(c, 3) for c in s.ut_centre), nm.x, nm.y, nm.z))


# ---------------------------------------------------------------- the disc and its text (one mesh each, every build)
def disc_geom(bm):
    H.cylinder(bm, Vector((0, 0, 0)), DISC_R, DISC_T, "Y", 48)
    H.torus(bm, Vector((0, -DISC_T / 2, 0)), RIM_R, RIM_TUBE, "XZ", 48, 6)
    H.torus(bm, Vector((0, 0, RING_Z)), RING_R, RING_TUBE, "XZ", 16, 6)


def text_geom(bm):
    e = (TEXT_PROUD + TEXT_SINK) / 2
    B.add_text(bm, BRAND, TEXT_SIZE, e, H.on_front(Vector((0, 0, 0)), -DISC_T / 2 + TEXT_SINK, 0.0))


disc = B.piece("WornMedal_Disc", MAT["Brass"], disc_geom, smooth=True)
text = B.piece("WornMedal_Text", MAT["Coffee"], text_geom, smooth=False)
DISC_C = disc.location.copy()        # each mesh's bounds centre in the disc frame (circle centre = origin)
TEXT_C = text.location.copy()
log("disc bounds centre in its frame", tuple(round(c, 4) for c in DISC_C), "text", tuple(round(c, 4) for c in TEXT_C), "text size", tuple(round(c, 3) for c in text.dimensions))


# ---------------------------------------------------------------- per build: where the disc lies, the ribbon's path
def fit_disc(s):
    """The disc's plane on the chest: a plane fitted to the outermost layer under it, pushed out to touch it with
    CLEAR. Returns (centre, rotation 3x3 taking the disc frame's -Y to the outward normal)."""
    hits = []
    for i in range(-6, 7):
        for k in range(-6, 7):
            x, dz = i / 6 * (DISC_R + 0.03), k / 6 * (DISC_R + 0.03)
            if x * x + dz * dz > (DISC_R + 0.03) ** 2:
                continue
            loc, _n = s.hit(Vector((x, -5, DISC_Z + dz)), Vector((0, 1, 0)))
            if loc is not None:
                hits.append(loc)
    A = np.array([[1.0, h.z - DISC_Z] for h in hits])
    yv = np.array([h.y for h in hits])
    (a, c), *_ = np.linalg.lstsq(A, yv, rcond=None)
    n = Vector((0, -1, c)).normalized()         # outward: front, tilted up where the chest slopes forward lower down
    p0 = Vector((0, a, DISC_Z))
    lift = max((h - p0).dot(n) for h in hits) + CLEAR
    centre = p0 + n * (lift + DISC_T / 2)
    rot = Vector((0, -1, 0)).rotation_difference(n).to_matrix()
    gaps = [((centre - n * DISC_T / 2) - h).dot(n) for h in hits]
    return centre, rot, n, (min(gaps), sum(gaps) / len(gaps), max(gaps))


def quad_bezier(a, c, e, n):
    return [a * (1 - t) ** 2 + c * 2 * t * (1 - t) + e * t * t for t in (i / n for i in range(n + 1))]


def resample(pts, step, closed=True):
    seq = pts + ([pts[0]] if closed else [])
    d = [0.0]
    for p, q in zip(seq, seq[1:]):
        d.append(d[-1] + (q - p).length)
    total = d[-1]
    n = max(8, int(round(total / step)))
    out, j = [], 0
    for i in range(n if closed else n + 1):
        t = total * i / n
        while j < len(d) - 2 and d[j + 1] < t:
            j += 1
        k = (t - d[j]) / max(1e-9, d[j + 1] - d[j])
        out.append(seq[j].lerp(seq[j + 1], k))
    return out, total


P_CLEAR = CLEAR + RIB_T / 2      # the centreline's distance from the clothes
H_CLEAR = RIB_W / 2 + 0.03        # ... and from the head (the ribbon's edge may face it). (0.07 was tried for
#                                   head-tilt room: it pushed the ribbon off the narrow builds' traps, 2026-11-25)
HEAD_MIN = 0.02                   # no ribbon point closer to the head than this


def collide(s, p, d):
    """Keeps p P_CLEAR outside the OUTERMOST layer as seen from its outside direction d (a ray from outside finds the
    singlet before the tee before the skin, so a point can never slip in between layers), and H_CLEAR off the head."""
    loc, _n = s.hit(p + d * 0.6, -d)
    if loc is not None:
        hgt = (p - loc).dot(d)
        if hgt < P_CLEAR:
            p = p + d * (P_CLEAR - hgt)
    loc, nrm, _i, _dd = s.head.find_nearest(p, H_CLEAR * 1.5)
    if loc is not None and (p - loc).dot(nrm) < H_CLEAR:
        p = loc + nrm * H_CLEAR
    return p


def drape(s, init, dirs, pins, steps=900):
    """The ribbon as a TAUT string of points: `init` (closed loop) tightened with `pins` {index: position} held, kept
    outside the clothes (P_CLEAR, the outermost layer) and the head (H_CLEAR). It settles on the shortest way round:
    straight over the chest, round the neck where the head and the traps meet, bridging hollows."""
    X = [p.copy() for p in init]
    N = len(X)
    for i, q in pins.items():
        X[i] = q.copy()
    free = [i for i in range(N) if i not in pins]
    seg0 = sum((X[(i + 1) % N] - X[i]).length for i in range(N)) / N
    for step in range(steps):
        rest = seg0 * (1 - 0.5 * min(1.0, step / 500))
        for _it in range(6):
            corr = [Vector() for _ in range(N)]
            for i in range(N):
                j = (i + 1) % N
                d = X[j] - X[i]
                ln = d.length
                if ln < 1e-9:
                    continue
                wi, wj = (0.0 if i in pins else 1.0), (0.0 if j in pins else 1.0)
                if wi + wj == 0:
                    continue
                c = d * ((ln - rest) / ln) * 0.5
                corr[i] += c * (wi / (wi + wj))
                corr[j] -= c * (wj / (wi + wj))
            for i in free:
                X[i] += corr[i]
        # a little stiffness: no zigzag from the collisions' sideways pushes
        mids = [(X[i - 1] + X[(i + 1) % N]) / 2 for i in range(N)]
        for i in free:
            X[i] = X[i].lerp(mids[i], 0.25)
        for i in free:
            X[i] = collide(s, X[i], dirs[i])
    return X


def loop_length(X):
    return sum((X[(i + 1) % len(X)] - X[i]).length for i in range(len(X)))


def ribbon_path(s, ring_top, n_disc):
    """The closed centreline (rig space): index 0 at the bottom of the turn through the ring, then up the build's left
    (+x), round the back of the neck, down the right. Returns points, outward normals, arc length from the tip, total."""
    tip_z = ring_top.z
    # the turn through the ring, on the chest (its depth from a ray from the front)
    turn = []
    for a in range(-90, 91, 15):
        x = TIP_R * math.sin(math.radians(a))
        z = tip_z + TIP_R - TIP_R * math.cos(math.radians(a))
        loc, _n = s.hit(Vector((x, -5, z)), Vector((0, 1, 0)))
        turn.append(loc + n_disc * P_CLEAR)
    # the back of the neck at the collar: the ribbon's middle a little above the collar's back edge
    zb = s.collar(0.001).z + 0.02
    loc, nb = s.hit(Vector((0, 5, zb)), Vector((0, -1, 0)))
    back = loc + nb * P_CLEAR
    # the start: a loop round the head well above the shoulders, joined to the turn and the back pin
    arc, arc_d = [], []
    for k in range(115, -116, -5):
        th = math.radians(k)
        z = zb + (5.55 - zb) * smoothstep(abs(k) / 60)
        radial = Vector((math.sin(th), math.cos(th), 0))
        p = Vector((0.85 * math.sin(th), 0.8 * math.cos(th), z))
        h, _n = s.hit(Vector((0, 0, z)) + radial * 3, -radial)
        if h is not None and Vector((h.x, h.y, 0)).length + 0.06 > Vector((p.x, p.y, 0)).length:
            p = h + radial * 0.08
        arc.append(p)
        # outside direction: from above and outward over the traps, straight outward (level) behind the neck, so the
        # back of the loop keeps the smooth height it is given there
        arc_d.append((Vector((math.sin(th), math.cos(th) * 0.9, 0)) + Vector((0, 0, 0.8 * smoothstep(abs(k) / 90)))
                      ).normalized())
    left = [turn[-1].lerp(arc[0], t / 20) for t in range(1, 20)]
    right = [arc[-1].lerp(turn[0], t / 20) for t in range(1, 20)]
    for seq in (left, right):
        for i, p in enumerate(seq):
            h, _n = s.hit(Vector((p.x, -5, p.z)), Vector((0, 1, 0)))
            if h is not None and p.y > h.y - 0.06:
                seq[i] = Vector((p.x, h.y - 0.08, p.z))
    half = len(turn) // 2
    loop = turn[half:] + left + arc + right + turn[:half]
    front = Vector((0, -1, 0))
    dirs = ([front] * (len(turn) - half) + [front.lerp(arc_d[0], smoothstep(t / 19 * 1.6 - 0.6)).normalized()
                                            for t in range(1, 20)]
            + arc_d + [front.lerp(arc_d[-1], smoothstep((19 - t) / 19 * 1.6 - 0.6)).normalized() for t in range(1, 20)]
            + [front] * half)
    pins = {i: loop[i] for i in range(len(turn) - half)}
    pins.update({len(loop) - half + i: loop[len(loop) - half + i] for i in range(half)})
    # Not pinned at the back (a pin there pulled the taut string into a V that creased the ribbon; a longer loop under
    # gravity slid out over the shoulders): the taut loop (the shortest, its back riding up under the head), then its
    # back half lowered smoothly onto the back of the neck at the collar (zb) and laid on the clothes again.
    X = drape(s, loop, dirs, pins)
    l_taut = loop_length(X)
    top_back = max(X, key=lambda p: p.y).z
    drop = max(0.0, top_back - zb)
    # the back half, as a smooth curve round the neck's axis: its height lowered by drop * cos^2 (0 at 85 degrees from
    # the back), its distance from the axis the least that keeps it on the clothes and off the head, smoothed as an
    # envelope (a running maximum, then blurred, never let below what is needed)
    back_idx = [i for i, p in enumerate(X) if i not in pins and p.y > NECK_CY
                and math.degrees(math.atan2(abs(p.x), p.y - NECK_CY)) < 85]
    if back_idx and drop > 0:
        thetas = [math.atan2(X[i].x, X[i].y - NECK_CY) for i in back_idx]
        zs = [X[i].z - drop * math.cos(min(math.pi / 2, abs(th) / math.radians(85) * math.pi / 2)) ** 2
              for i, th in zip(back_idx, thetas)]

        def needed_r(th, z):
            radial = Vector((math.sin(th), math.cos(th), 0))
            axis = Vector((0, NECK_CY, z))
            h, nn = s.hit(axis + radial * 3, -radial)
            r = (Vector((h.x, h.y - NECK_CY, 0)).length if h is not None else 0.3) + P_CLEAR / max(0.4, abs(nn.dot(radial)) if nn else 1)
            for _ in range(40):
                q = axis + radial * r
                loc, hn, _i, dd = s.head.find_nearest(q, H_CLEAR * 1.2)
                if loc is None or ((q - loc).dot(hn) >= 0 and dd >= H_CLEAR):
                    break
                r += 0.01
            return r
        need = [needed_r(th, z) for th, z in zip(thetas, zs)]
        M = len(need)
        env = [max(need[max(0, j - 4):j + 5]) for j in range(M)]
        for _ in range(10):
            env = [env[0]] + [(env[j - 1] + 2 * env[j] + env[j + 1]) / 4 for j in range(1, M - 1)] + [env[-1]]
            env = [max(e, n) for e, n in zip(env, need)]
        for j, i in enumerate(back_idx):
            designed = Vector((env[j] * math.sin(thetas[j]), NECK_CY + env[j] * math.cos(thetas[j]), zs[j]))
            u = smoothstep((85 - math.degrees(abs(thetas[j]))) / 25)     # (joins the taut sides without a step)
            X[i] = X[i].lerp(designed, u)
    # the body is left-right symmetric, so is the ribbon: the smoother half (fewer, gentler bends) mirrored
    ib = min((i for i in range(len(X)) if i not in pins and X[i].y > NECK_CY + 0.2), key=lambda i: abs(X[i].x))

    def bends(seq):
        return sum((seq[i] - seq[i - 1]).angle(seq[i + 1] - seq[i], 0) ** 2 for i in range(1, len(seq) - 1))
    left_half = X[:ib + 1]
    right_half = [Vector((-p.x, p.y, p.z)) for p in reversed(X[ib:] + [X[0]])]
    half_ = left_half if bends(left_half) <= bends(right_half) else right_half
    half_[-1] = Vector((0, half_[-1].y, half_[-1].z))
    half_[0] = Vector((0, half_[0].y, half_[0].z))
    X = half_ + [Vector((-p.x, p.y, p.z)) for p in reversed(half_[1:-1])]
    log("%s drape: taut loop %.2f, its back at z %.3f lowered by %.3f to the collar (%.3f) -> %.2f long, %s half kept" % (
        s.b, l_taut, top_back, drop, zb, loop_length(X), "left" if half_ is left_half else "right"))
    pts, total = resample(X, STEP)      # index 0 = the first pin = the bottom of the turn
    N = len(pts)
    pdirs = []
    for p in pts:
        j = min(range(len(loop)), key=lambda j: (Vector((abs(loop[j].x), loop[j].y, loop[j].z))
                                                   - Vector((abs(p.x), p.y, p.z))).length_squared)
        dj = dirs[j]
        pdirs.append(Vector((math.copysign(abs(dj.x), p.x) if abs(p.x) > 1e-6 else dj.x, dj.y, dj.z)))
    d = [0.0]
    for p, q in zip(pts, pts[1:]):
        d.append(d[-1] + (q - p).length)
    keep_tip = [min(x, total - x) < 0.08 for x in d]
    for _ in range(10):                 # smooth, kept outside
        mids = [(pts[i - 1] + pts[(i + 1) % N]) / 2 for i in range(N)]
        pts = [p if keep_tip[i] else collide(s, p.lerp(mids[i], 0.5), pdirs[i]) for i, p in enumerate(pts)]
    pts, total = resample(pts, STEP_WORN)
    N = len(pts)
    nrm = []
    for p in pts:
        loc, m, _i, _d = s.tree.find_nearest(p, 1.0)
        nrm.append(m.copy() if loc is not None else Vector((0, 0, 1)))
    for _ in range(10):
        nrm = [(nrm[i] * 2 + nrm[i - 1] + nrm[(i + 1) % N]).normalized() for i in range(N)]
    d = [0.0]
    for p, q in zip(pts, pts[1:]):
        d.append(d[-1] + (q - p).length)
    dist = [min(x, total - x) for x in d]
    sharp = [i for i in range(N) if (pts[i] - pts[i - 1]).angle(pts[(i + 1) % N] - pts[i], 0) > math.radians(40)]
    log("%s centreline: %d points, sharp turns (>40 deg) at %s" % (s.b, N, sharp[:20]))
    return pts, nrm, dist, total


def ribbon_sections(pts, nrm, dist, width_of, closed=True):
    """Four vertices per centreline point: inner-left, outer-left, outer-right, inner-right."""
    N = len(pts)
    secs, frames = [], []
    for i in range(N):
        a, c = pts[i - 1] if (closed or i > 0) else pts[i], pts[(i + 1) % N] if (closed or i < N - 1) else pts[i]
        t = (c - a).normalized()
        n = (nrm[i] - t * nrm[i].dot(t)).normalized()
        w = t.cross(n).normalized()
        hw = width_of(dist[i]) / 2
        p = pts[i]
        secs.append([p + w * hw - n * RIB_T / 2, p + w * hw + n * RIB_T / 2,
                     p - w * hw + n * RIB_T / 2, p - w * hw - n * RIB_T / 2])
        frames.append((t, n, w))
    return secs, frames


def tube(bm, secs, closed=True):
    verts = [[bm.verts.new(v) for v in s] for s in secs]
    N = len(verts)
    R = len(verts[0])
    for i in range(N if closed else N - 1):
        a, b2 = verts[i], verts[(i + 1) % N]
        for k in range(R):
            bm.faces.new((a[k], b2[k], b2[(k + 1) % R], a[(k + 1) % R]))
    if not closed:
        bm.faces.new(list(reversed(verts[0])))
        bm.faces.new(verts[-1])
    bm.normal_update()
    vol = sum(f.verts[0].co.dot(f.verts[i].co.cross(f.verts[i + 1].co)) / 6
              for f in bm.faces for i in range(1, len(f.verts) - 1))
    if vol < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])


def width_worn(d):
    return RIB_W_TIP + (RIB_W - RIB_W_TIP) * smoothstep(d / TAPER)


def surface_height(s, c, n, w, u):
    """Where the outermost layer is under the point c + w*u, measured along n from c (None: nothing under it)."""
    loc, _nn, _i, d = s.tree.ray_cast(c + w * u + n * 0.5, -n, 1.2)
    return 0.5 - d if loc is not None else None


TILT_ON = float(os.environ.get("MEDAL_TILT", "1"))


def smooth_loop(vals, passes):
    N = len(vals)
    for _ in range(passes):
        vals = [(vals[i - 1] + 2 * vals[i] + vals[(i + 1) % N]) / 4 for i in range(N)]
    return vals


ACROSS = 4      # inner-face points across the worn ribbon's width (3 segments: it bends over the traps' curve)


BRIDGE = 0.035  # a ribbon point may float this much above CLEAR (bridging a crease) before it is pulled down


def wrap(s, p):
    """p laid on the outermost layer: pushed out to CLEAR where it is closer (or inside), pulled down to CLEAR where
    it floats more than BRIDGE above that (an edge hanging over a curve), left alone in between (a ribbon bridges a
    crease such as where the neck meets the collar: pulling every point into it bunched the ribbon up)."""
    loc, nn, _i, d = s.tree.find_nearest(p, 0.6)
    if loc is None:
        return p
    out = (p - loc)
    outside = out.length > 1e-5 and out.dot(nn) > 0
    if outside and CLEAR <= out.length <= CLEAR + BRIDGE:
        return p
    out = out.normalized() if outside else nn
    return loc + out * CLEAR


def lay_sections(s, pts, nrm, dist, width_of):
    """Each cross-section laid ON the clothes: ACROSS points spread over the ribbon's width are each moved onto the
    outermost layer (its nearest point, CLEAR out), so the ribbon wraps the traps' and the back's curves across its
    width instead of sticking out flat; then each line of points along the loop is smoothed and laid on again, the
    outer face is the inner one RIB_T further out, and the head is kept clear. Returns the sections (inner points
    across, then the outer ones back) and per-section gaps (closest, widest under an edge, middle) measured by rays."""
    N = len(pts)
    frames, inner = [], []
    for i in range(N):
        t = (pts[(i + 1) % N] - pts[i - 1]).normalized()
        n = (nrm[i] - t * nrm[i].dot(t)).normalized()
        w = t.cross(n).normalized()
        hw = width_of(dist[i]) / 2
        uk = [hw - 2 * hw * k / (ACROSS - 1) for k in range(ACROSS)]
        frames.append((t, n, w, hw))
        inner.append([wrap(s, pts[i] + w * u) for u in uk])
    for _ in range(16):            # smooth along the loop and across (fabric, not the facets), lay it on again
        new = []
        for i in range(N):
            row = [inner[i][k] * 0.4 + (inner[i - 1][k] + inner[(i + 1) % N][k]) * 0.3 for k in range(ACROSS)]
            # across: the inner points stay evenly spread on a gentle curve (their middles pulled toward a line)
            row = [row[0]] + [row[k] * 0.5 + (row[k - 1] + row[k + 1]) * 0.25 for k in range(1, ACROSS - 1)] + [row[-1]]
            new.append([wrap(s, q) for q in row])
        inner = new
    for _ in range(4):             # no lone point out of line (a seam or a lip caught one): back between its neighbours
        for i in range(N):
            for k in range(ACROSS):
                avg = (inner[i - 1][k] + inner[(i + 1) % N][k]) / 2
                if 0 < k < ACROSS - 1:
                    avg = (avg + (inner[i][k - 1] + inner[i][k + 1]) / 2) / 2
                if (inner[i][k] - avg).length > min(0.015, frames[i][3] * 0.25):
                    inner[i][k] = wrap(s, avg)
    secs = []
    for i in range(N):
        t, n, w, hw = frames[i]
        row = inner[i]
        outer = []
        for k in range(ACROSS):
            across = row[min(ACROSS - 1, k + 1)] - row[max(0, k - 1)]
            along = inner[(i + 1) % N][k] - inner[i - 1][k]
            nk = along.cross(across).normalized()
            if nk.dot(n) < 0:
                nk = -nk
            outer.append(row[k] + nk * RIB_T)
        secs.append(row + list(reversed(outer)))
    R = 2 * ACROSS

    def seg_normal(sec, k):
        return ((sec[R - 1 - k] - sec[k]) + (sec[R - 2 - k] - sec[k + 1])).normalized()
    # never closer than CLEAR_MIN anywhere across (a segment's middle can cut a curve, an edge can tuck under the
    # collar's lip): the lifts each inner point needs, spread smoothly along the loop so nothing pokes out
    for _round in range(4):
        need = [0.0] * N
        for i in range(N):
            for k in range(ACROSS - 1):
                for f in (0.0, 0.5, 1.0):
                    q = secs[i][k].lerp(secs[i][k + 1], f)
                    need[i] = max(need[i], CLEAR_MIN + 0.006 - s.gap(q, seg_normal(secs[i], k), 0.3))
        if max(need) <= 0:
            break
        sm = [max(0.0, max(need[(i + j) % N] for j in range(-3, 4))) for i in range(N)]
        for _ in range(4):
            sm = smooth_loop(sm, 1)
            sm = [max(a_, c_) for a_, c_ in zip(sm, need)]
        for i in range(N):
            if sm[i] > 0:          # the whole section lifted along its own outward direction: it stays flat, no spikes
                nq = sum(((secs[i][R - 1 - k] - secs[i][k]) for k in range(ACROSS)), Vector()).normalized()
                secs[i] = [v + nq * sm[i] for v in secs[i]]
    gaps = []
    for i in range(N):
        sec = secs[i]
        for _ in range(3):         # the head: never closer than HEAD_MIN (pushed straight away from it)
            worst, away = 0.0, None
            for v in sec:
                loc, nn, _i, dd = s.head.find_nearest(v, 0.5)
                if loc is None:
                    continue
                sd = dd if (v - loc).dot(nn) >= 0 else -dd
                if HEAD_MIN - sd > worst:
                    worst, away = HEAD_MIN - sd, nn.copy()
            if away is None:
                break
            sec = [v + away * (worst + 0.005) for v in sec]
        secs[i] = sec
        # gaps: rays from outside down to the inner face's segments and on to the clothes
        g = []
        for k in range(ACROSS - 1):
            for f in (0.0, 0.5) if k < ACROSS - 2 else (0.0, 0.5, 1.0):
                g.append(s.gap(sec[k].lerp(sec[k + 1], f), seg_normal(sec, k), 0.3))
        gaps.append((min(g), max(g[0], g[-1]), g[len(g) // 2]))
    return secs, gaps


def head_clear(s, secs):
    worst = 9.0
    for sec in secs:
        for v in sec:
            loc, nn, _i, d = s.head.find_nearest(v, 2.0)
            if loc is None:
                continue
            inside = (v - loc).dot(nn) < 0
            worst = min(worst, -d if inside else d)
    return worst


def self_overlap(obj):
    """Triangle pairs of the mesh crossing each other (sharing no vertex): a ribbon folding through itself."""
    m = obj.data
    vs = [v.co.copy() for v in m.vertices]
    fs = [tuple(p.vertices) for p in m.polygons]
    t = BVHTree.FromPolygons(vs, fs)
    return sum(1 for a, b2 in t.overlap(t) if a < b2 and not set(fs[a]) & set(fs[b2]))


placed = {}      # build -> dict of preview objects
REPORT = {"units": "studs", "axes": "Roblox: x = the wearer's right, y up, -z front (UpperTorso part space)",
          "outfitExports": sorted(USED_EXPORTS), "worn": {}, "held": {}}
LOOP_LEN = {}
for bi, b in enumerate(BUILDS):
    s = SURF[b]
    rig_off = rigs[b].matrix_world.translation.copy()
    centre, rot, n_disc, disc_gaps = fit_disc(s)
    ring_c = centre + rot @ Vector((0, 0, RING_Z))
    ring_top = ring_c + rot @ Vector((0, 0, RING_R * 0.45))
    pts, nrm, dist, total = ribbon_path(s, ring_top, n_disc)
    secs, gaps = lay_sections(s, pts, nrm, dist, width_worn)
    LOOP_LEN[b] = total
    hc = head_clear(s, secs)

    def rib_geom(bm, secs=secs, off=rig_off):
        tube(bm, [[v + off for v in sec] for sec in secs])
    rib = B.piece("WornMedal_Ribbon_" + b, MAT["Red"], rib_geom, smooth=True)
    overl = self_overlap(rib)
    # the disc and its text placed on this build (preview copies sharing the one mesh)
    objs = {}
    for name, src, c0 in (("Disc", disc, DISC_C), ("Text", text, TEXT_C)):
        o = bpy.data.objects.new("Preview_WornMedal_%s_%s" % (name, b), src.data)
        o.matrix_world = Matrix.Translation(rig_off + centre + rot @ c0) @ rot.to_4x4()
        B.coll.objects.link(o)
        objs[name] = o
    objs["Ribbon"] = rib
    placed[b] = objs
    # numbers
    touch = [g[0] for g in gaps]          # each section's closest point to the clothes (CLEAR = lying on them)
    if os.environ.get("MEDAL_DEBUG"):
        for i in range(len(gaps)):
            if gaps[i][1] > 0.08 or gaps[i][0] < 0.022:
                log("  sec %d c %s gaps %s inner %s" % (i, tuple(round(c, 3) for c in pts[i]), tuple(round(g, 3) for g in gaps[i]),
                    [tuple(round(c, 3) for c in v) for v in secs[i][:ACROSS]]))
    i_min = min(range(len(gaps)), key=lambda i: gaps[i][0])
    i_max = max(range(len(gaps)), key=lambda i: gaps[i][1] if gaps[i][1] < 5 else -1)
    log("%s: closest at section %d %s, widest edge gap at section %d %s" % (
        b, i_min, tuple(round(c, 2) for c in pts[i_min]), i_max, tuple(round(c, 2) for c in pts[i_max])))
    inner = touch
    belt_top = 3.07
    disc_bottom = (centre + rot @ Vector((0, 0, -DISC_R))).z
    log("%s: disc centre %s tilt %.1f deg, disc back gap min %.3f mean %.3f max %.3f; disc bottom %.2f (belt top ~%.2f)" % (
        b, tuple(round(c, 3) for c in centre), math.degrees(math.atan2(n_disc.z, -n_disc.y)), *disc_gaps, disc_bottom,
        belt_top))
    log("%s: ribbon loop %.2f long, %d sections; each section's closest gap: min %.3f max %.3f (sections not touching "
        "within %.2f: %d); widest gap under a ribbon edge %.3f; head clearance %.3f; self-crossing triangle pairs %d" % (
            b, total, len(secs), min(touch), max(touch), FLOAT_MAX, sum(1 for g in touch if g > FLOAT_MAX),
            max(g[1] for g in gaps if g[1] < 5), hc, overl))
    # CFrames in UpperTorso space (Roblox): each MeshPart sits at its mesh's bounds centre
    ut = s.ut_centre
    rr = M_RBX @ rot @ M_RBX

    def cf(pos_b, rmat):
        p = to_rbx(pos_b - ut)
        return [round(p.x, 4), round(p.y, 4), round(p.z, 4)] + [round(rmat[i][j], 5) for i in range(3) for j in range(3)]
    neck_mark = to_rbx(Vector((0, 0, 4.7)) - ut)
    REPORT["worn"][b] = {
        "Disc": cf(centre + rot @ DISC_C, rr),
        "Text": cf(centre + rot @ TEXT_C, rr),
        "Ribbon": cf(rib.location - rig_off, Matrix.Identity(3)),
        "neckMarkCheck": [round(neck_mark.x, 4), round(neck_mark.y, 4), round(neck_mark.z, 4)],
        "discTiltDeg": round(math.degrees(math.atan2(n_disc.z, -n_disc.y)), 2),
        "ribbonInnerGap": [round(min(inner), 3), round(max(inner), 3)],
        "discBackGap": [round(disc_gaps[0], 3), round(disc_gaps[2], 3)],
        "headClearance": round(hc, 3),
        "loopLength": round(total, 3),
    }
    rib["fit_build"] = b


# ---------------------------------------------------------------- the held medal (a referee holds the loop open)
HX = 0.75          # the hands' half distance (1.5 apart: the loop opens wider than a head, 1.2)
FOLD = 0.07        # the fold over the fingers: front and back parts this far either side of the hold point
BOW = 0.30         # the back part bows back this much at its middle (the loop reads open)
L_HELD = LOOP_LEN["Fit"]


def held_path(drop):
    """Closed centreline (model space, Blender axes, front -Y; the hold points at (+-HX, 0, 0)): the turn through the
    ring at the bottom of the front V, up the left strand, over the left hand, the back part (a hanging U), over the
    right hand, down the right strand."""
    tip_z = -drop
    ey = Vector((0, 1, 0))
    turn = [Vector((TIP_R * math.sin(math.radians(a)), -FOLD, tip_z + TIP_R - TIP_R * math.cos(math.radians(a))))
            for a in range(0, 91, 15)]                   # bottom -> the left strand's foot
    pts = list(turn)
    hl, hr = Vector((HX, 0, 0)), Vector((-HX, 0, 0))
    pts += quad_bezier(turn[-1], Vector((TIP_R, -FOLD, tip_z + TIP_R + 0.25)), hl - FOLD * ey, 30)[1:]
    ul, ur = Vector((1, 0, 1)).normalized(), Vector((-1, 0, 1)).normalized()
    for k in range(1, 12):                               # over the left hand: front -> top -> back
        phi = math.pi * k / 12
        pts.append(hl + FOLD * (-math.cos(phi) * ey + math.sin(phi) * ul))
    for k in range(0, 41):                               # the back part: a hanging U from hand to hand, bowed back
        u = k / 40
        x = HX - 2 * HX * u
        z = -0.42 * (1 - (x / HX) ** 2) - 0.08 * (1 - (x / HX) ** 4)
        pts.append(Vector((x, FOLD + BOW * math.sin(math.pi * u), z)))
    for k in range(1, 12):                               # over the right hand: back -> top -> front
        phi = math.pi - math.pi * k / 12
        pts.append(hr + FOLD * (-math.cos(phi) * ey + math.sin(phi) * ur))
    a2 = Vector((-TIP_R, -FOLD, tip_z + TIP_R))
    pts += list(reversed(quad_bezier(a2, Vector((-TIP_R, -FOLD, tip_z + TIP_R + 0.25)), hr - FOLD * ey, 30)))
    pts += [Vector((-p.x, p.y, p.z)) for p in reversed(turn[1:-1])]
    return resample(pts, STEP)


lo, hi = 0.3, 2.5
for _ in range(40):                                      # the front V's depth that gives the worn loop's length
    mid = (lo + hi) / 2
    _p, tot = held_path(mid)
    lo, hi = (mid, hi) if tot < L_HELD else (lo, mid)
held_drop = (lo + hi) / 2
hpts, htot = held_path(held_drop)
# frames: rotation-minimising along the loop from the bottom (flat face toward the front there)
N = len(hpts)
tan = [(hpts[(i + 1) % N] - hpts[i - 1]).normalized() for i in range(N)]
n0 = Vector((0, -1, 0))
hn = [(n0 - tan[0] * n0.dot(tan[0])).normalized()]
for i in range(1, N):
    v = hn[-1] - tan[i] * hn[-1].dot(tan[i])
    hn.append(v.normalized())
twist = math.degrees(hn[-1].angle((n0 - tan[-1] * n0.dot(tan[-1])).normalized()))
hd = [0.0]
for p, q in zip(hpts, hpts[1:]):
    hd.append(hd[-1] + (q - p).length)
hdist = [min(x, htot - x) for x in hd]
hsecs, _hf = ribbon_sections(hpts, hn, hdist, width_worn)
HELD_ORIGIN = Vector((-6.0, 0, 4.4))                    # where it stands in the .blend (beside Skinny)
held_rib = B.piece("HeldMedal_Ribbon", MAT["Red"], lambda bm: tube(bm, [[v + HELD_ORIGIN for v in s_] for s_ in hsecs]))
h_overlap = self_overlap(held_rib)
ring_c_h = Vector((0, -FOLD, -held_drop + 0.0)) - Vector((0, 0, RING_R * 0.45))
disc_c_h = ring_c_h - Vector((0, 0, RING_Z))
disc_c_h.y = -FOLD - 0.0
held_objs = {}
for name, src, c0 in (("Disc", disc, DISC_C), ("Text", text, TEXT_C)):
    o = bpy.data.objects.new("Preview_HeldMedal_" + name, src.data)
    o.location = HELD_ORIGIN + disc_c_h + c0
    B.coll.objects.link(o)
    held_objs[name] = o
held_objs["Ribbon"] = held_rib
rib_c = held_rib.location - HELD_ORIGIN


def rel(p):
    v = to_rbx(p - rib_c)
    return [round(v.x, 4), round(v.y, 4), round(v.z, 4)]


REPORT["held"] = {
    "space": "HeldMedal_Ribbon MeshPart's own space (its mesh's bounds centre, Roblox axes, the medal's face toward -z)",
    "holdPointPlusX": rel(Vector((-HX, 0, 0))), "holdPointMinusX": rel(Vector((HX, 0, 0))),
    "holdMidpoint": rel(Vector((0, 0, 0))),
    "discCentre": rel(disc_c_h), "Disc": rel(disc_c_h + DISC_C), "Text": rel(disc_c_h + TEXT_C),
    "frontVDepth": round(held_drop, 3), "loopLength": round(htot, 3), "handsApart": 2 * HX,
}
log("held: loop %.2f (worn Fit %.2f), front V %.2f deep, closure twist %.1f deg, self-crossing pairs %d" % (
    htot, L_HELD, held_drop, twist, h_overlap))
log("held report", REPORT["held"])

# the worn pieces' names and their recolouring
REPORT["pieces"] = {"Disc": "WornMedal_Disc (shared)", "Text": "WornMedal_Text (shared)",
                    "Ribbon": "WornMedal_Ribbon_<Build>", "HeldRibbon": "HeldMedal_Ribbon"}
REPORT["colourways"] = COLOURWAYS
with open(os.path.join(EXPORTS, "WornMedal_01_fit.json"), "w") as f:
    json.dump(REPORT, f, indent=1)
for b in BUILDS:
    log("CFrame", b, json.dumps({k: REPORT["worn"][b][k] for k in ("Disc", "Text", "Ribbon")}))


# ---------------------------------------------------------------- pictures (backface culling on, as Roblox draws)
def paint(name, rgb, metal=False):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (*[linear(c) for c in rgb], 1)
    m.metallic = 0.6 if metal else 0.0
    m.roughness = 0.35 if metal else 0.7
    return m


def set_mat(o, m):
    if len(o.material_slots) == 0:
        o.data.materials.append(m)
    for sl in o.material_slots:
        sl.link = "OBJECT"
        sl.material = m


def render_setup():
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_WORKBENCH"
    except TypeError as e:
        log("engine", e)
    sh = sc.display.shading
    sh.light, sh.color_type, sh.show_backface_culling, sh.show_cavity = "STUDIO", "MATERIAL", True, True
    sh.cavity_type = "WORLD"
    sh.cavity_ridge_factor, sh.cavity_valley_factor = 0.6, 1.0
    sh.show_specular_highlight = True
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.16, 0.17, 0.2)
    sc.display.render_aa = "16"
    sc.render.image_settings.file_format = "PNG"
    cd = bpy.data.cameras.new("Preview_Cam")
    cd.type = "ORTHO"
    cd.clip_end = 300
    cam = bpy.data.objects.new("Preview_Cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    lc = bpy.data.curves.new("Preview_Label", "FONT")
    lab = bpy.data.objects.new("Preview_Label", lc)
    lab.data.materials.append(paint("PV_Label", (240, 240, 230)))
    sc.collection.objects.link(lab)
    lab.parent = cam
    return sc, cam, cd, lab, lc


def shoot(path, target, direction, scale, label, res=(640, 640)):
    sc = bpy.context.scene
    CAM[2].ortho_scale = scale
    sc.render.resolution_x, sc.render.resolution_y = res
    cam = CAM[1]
    cam.location = target + Vector(direction).normalized() * 40
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    CAM[4].body = label
    CAM[4].size = scale * 0.045
    CAM[3].location = (-scale / 2 + scale * 0.02, scale * res[1] / res[0] / 2 - CAM[4].size * 1.3, -5)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def compose(paths, cols, out):
    imgs = [bpy.data.images.load(p) for p in paths]
    w, h = imgs[0].size
    rows = (len(imgs) + cols - 1) // cols
    sheet = np.zeros((rows * h, cols * w, 4), dtype=np.float32)
    for i, im in enumerate(imgs):
        a = np.empty(w * h * 4, dtype=np.float32)
        im.pixels.foreach_get(a)
        a = a.reshape(h, w, 4)
        r, c = rows - 1 - i // cols, i % cols
        sheet[r * h:(r + 1) * h, c * w:(c + 1) * w] = a
    img = bpy.data.images.new("Sheet", cols * w, rows * h, alpha=True)
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()
    for im in imgs:
        bpy.data.images.remove(im)
    bpy.data.images.remove(img)
    return out


if PREVIEWS:
    os.makedirs(os.path.join(PREVIEW_DIR, "tiles"), exist_ok=True)
    CAM = render_setup()
    skin = paint("PV_Skin", (214, 168, 132))
    head_m = paint("PV_Head", (226, 182, 146))
    # the user's meet colours: red singlet, black panels and piping, white tee, black belt
    look = {"Tee": (236, 236, 232), "WornSinglet_Black": (200, 30, 38), "WornSinglet_Red": (22, 22, 24),
            "WornSinglet_Trim": (22, 22, 24), "WornSinglet_Shorts": (200, 30, 38),
            "WornLeverBelt_Outer": (22, 22, 24), "WornLeverBelt_Lining": (200, 30, 38),
            "WornLeverBelt_Lever": (190, 192, 198)}
    show = set()
    for b in BUILDS:
        for n in BODY_PARTS:
            o = bpy.data.objects[b + "_" + n]
            set_mat(o, skin)
            show.add(o)
        hd = bpy.data.objects[b + "_StandInHead"]
        set_mat(hd, head_m)
        show.add(hd)
        for o in OUTFIT[b]:
            item = o.name.split("_", 2)[2].partition("__")[0]
            set_mat(o, paint("PV_" + item, look.get(item, (128, 128, 128)), item.endswith("Lever")))
            show.add(o)
        cw = COLOURWAYS[BUILDS.index(b) % 3]
        for piece, o in placed[b].items():
            set_mat(o, paint("PV_M_" + cw[piece], PAINT[cw[piece]], cw[piece] in METAL))
            show.add(o)
    for o in bpy.data.objects:
        if o.type in ("MESH", "CURVE", "FONT") and o not in show and o.name != "Preview_Label":
            o.hide_render = True
    owner = {}
    for b in BUILDS:
        for o in [bpy.data.objects[b + "_" + n] for n in BODY_PARTS] + [bpy.data.objects[b + "_StandInHead"]] \
                + OUTFIT[b] + list(placed[b].values()):
            owner[o] = b

    def only(b):
        for o, ob in owner.items():
            o.hide_render = ob != b
        for o in held_objs.values():
            o.hide_render = b != "Held"

    VIEWS = {"front": (0, -1, 0.12), "side": (-1, 0, 0.06), "threequarter": (-0.8, -1, 0.3), "back": (0, 1, 0.3)}
    CLOSE = {"neck_back": ((0, 1, 0.55), 1.9, "neck"), "neck_backside": ((-0.9, 0.8, 0.45), 1.9, "neck"),
             "neck_side": ((-1, 0, 0.12), 1.9, "neck"), "neck_front": ((0.35, -1, 0.35), 1.9, "neck"),
             "disc_front": ((0, -1, 0.04), 1.05, "disc"), "disc_side": ((-1, 0, 0.0), 1.3, "disc")}
    sheets = []
    for v, d in VIEWS.items():
        tiles = []
        for b in BUILDS:
            only(b)
            off = rigs[b].matrix_world.translation
            tiles.append(shoot(os.path.join(PREVIEW_DIR, "tiles", "%s_%s.png" % (v, b)), off + Vector((0, 0, 4.05)), d,
                               3.9, "%s  %s" % (b, v)))
        sheets.append(compose(tiles, 3, os.path.join(PREVIEW_DIR, "worn_%s.png" % v)))
    for v, (d, sc_, what) in CLOSE.items():
        tiles = []
        for b in BUILDS:
            only(b)
            off = rigs[b].matrix_world.translation
            if what == "neck":
                tgt = off + Vector((0, 0.05, 4.75))
            else:
                tgt = placed[b]["Disc"].matrix_world.translation.copy()
                tgt.z -= 0.05
            tiles.append(shoot(os.path.join(PREVIEW_DIR, "tiles", "%s_%s.png" % (v, b)), tgt, d, sc_,
                               "%s  %s" % (b, v)))
        sheets.append(compose(tiles, 3, os.path.join(PREVIEW_DIR, "worn_%s.png" % v)))
    only("Held")
    tiles = []
    for v, d in (("front", (0, -1, 0.05)), ("threequarter", (-0.8, -1, 0.35)), ("side", (-1, 0, 0.05)),
                 ("top", (0.0, -0.35, 1.0)), ("back", (0, 1, 0.2)), ("disc", (0, -1, 0.0))):
        tgt = HELD_ORIGIN + Vector((0, 0, -held_drop * 0.55)) if v != "disc" else held_objs["Disc"].location
        tiles.append(shoot(os.path.join(PREVIEW_DIR, "tiles", "held_%s.png" % v), tgt, d,
                           2.6 if v != "disc" else 0.9, "HeldMedal  " + v))
    sheets.append(compose(tiles, 3, os.path.join(PREVIEW_DIR, "held.png")))
    log("previews:", sheets)

# ---------------------------------------------------------------- the file: the medal pieces only, then the exports
def save_and_export():
    keep = {disc, text, held_rib} | {placed[b]["Ribbon"] for b in BUILDS}
    # the disc and text where they sit on each build and in the held medal stay in the file as "Preview" copies (the same
    # meshes; check_models.py skips that collection), so the file shows the whole fit
    pv = bpy.data.collections.new("Preview")
    bpy.context.scene.collection.children.link(pv)
    copies = [placed[b][k] for b in BUILDS for k in ("Disc", "Text")] + [held_objs["Disc"], held_objs["Text"]]
    for o in copies:
        for c_ in list(o.users_collection):
            c_.objects.unlink(o)
        pv.objects.link(o)
    keep_all = keep | set(copies)
    for o in list(bpy.data.objects):
        if o not in keep_all:
            bpy.data.objects.remove(o, do_unlink=True)
    for coll in list(bpy.data.collections):
        if coll.name not in ("WornMedal", "Preview"):
            bpy.data.collections.remove(coll)
    try:
        for _ in range(3):
            bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
    except Exception as e:  # (only tidiness)
        log("purge skipped:", e)
    disc.location = (-6.0, 0, 2.6)        # the shared disc and text below the held medal in the file
    text.location = disc.location + (TEXT_C - DISC_C)
    for o in keep_all:
        for sl in o.material_slots:
            sl.link = "DATA"
            sl.material = None
    for o in keep:
        o.data.materials.clear()
    disc.data.materials.append(MAT["Brass"])
    text.data.materials.append(MAT["Coffee"])
    for o in keep - {disc, text}:
        o.data.materials.append(MAT["Red"])
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    log("saved", OUT_BLEND)


    def export(o, name):
        loc = o.location.copy()
        o.location = (0, 0, 0)
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        path = os.path.join(EXPORTS, name + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True)
        o.location = loc
        return path


    paths = [export(disc, "WornMedal_Disc"), export(text, "WornMedal_Text"), export(held_rib, "HeldMedal_Ribbon")]
    paths += [export(placed[b]["Ribbon"], "WornMedal_Ribbon_" + b) for b in BUILDS]
    for o in sorted(keep, key=lambda o: o.name):
        log("tris %s %d" % (o.name, sum(len(p.vertices) - 2 for p in o.data.polygons)))
    log("exported", [os.path.basename(p) for p in paths])
    log("DONE")


if os.environ.get("MEDAL_SAVE", "1") == "0":     # (a trial: pictures and numbers only)
    log("MEDAL_SAVE=0: nothing saved or exported")
else:
    save_and_export()
