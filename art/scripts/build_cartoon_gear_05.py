# The lifting gear and the everyday clothes, version 5: the APPROVED v4 look (CHARACTER_ART_DIRECTION.md §10.3, user
# 2026-11-13: singlet over a black tee with piped edges and torso-held straps, belt at the navel, thin snug knee sleeves
# from the lower thigh to mid-shin, wraps over the wrist joint) fitted to the six PRODUCTION bodies
# (art/blender/CartoonBodies_05_Rigged.blend: Skinny, SkinnyFat, Fat, Fit, Muscular, BigBuff; torso-tall skeleton, arms
# x1.5). Phase 3 of the production plan (§11).
#
# build_cartoon_gear_04.py (and through it build_cartoon_gear_03.py + gear_fit_03.py) is used as a LIBRARY, unchanged;
# this file only points it at the new bodies (build_cartoon_body_05.body_spec, its heights L) and adds the items v4 never
# built, made the same way:
#   - tee, under-tee, singlet, belt, knee sleeves, wrist wraps, sneakers: the v4 builders;
#   - long sleeve: the v4 tee with the sleeves down to the wrist;
#   - tank: the v4 singlet's top (straps, scoop, armholes) cut at the tee's hem, at tee clearance (worn alone);
#   - squat suit, deadlift suit: the v4 singlet with longer legs (the same top, so the under-tee fits under all three),
#     the suits' own colour keys (Body / Panel / Trim);
#   - bench shirt: the v4 tee shell, sleeves to above the elbow, thicker fabric, the sleeves its Shoulder key, a back
#     logo (worn under the singlet, so at tee clearance);
#   - knee wraps, shorts, joggers: the v03 builders (outline-ring tubes, already measured from each body).
# A new body is a re-run: every height comes from the body (L table, landmarks), nothing per build is written here.
# v4's hold_shoulder is OFF (Phase 2: the bodies' own spread shoulder weights are copied instead).
#
#   blender -b art/blender/CartoonBodies_05_Rigged.blend --python art/scripts/build_cartoon_gear_05.py
# Writes art/blender/CartoonGear_05.blend (nothing exported or uploaded). Optional env: GEAR05_BUILDS=Fit,Fat (a subset),
# GEAR05_ITEMS=Singlet,Belt (a subset of ITEMS below).
import math
import os

import bmesh
import bpy
import numpy as np

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
OUT_BLEND = os.environ.get("GEAR05_OUT") or os.path.join(ROOT, "art", "blender", "CartoonGear_05.blend")
# the re-made animations for this rig (commit e8db04a): the lift poses the pose room is made for
os.environ["GEAR04_ANIMS"] = os.path.join(ROOT, "art", "animations")

# ---------------------------------------------------------------- the v4 builders as a library
_v4_path = os.path.join(SCRIPTS, "build_cartoon_gear_04.py")
_v4_src = open(_v4_path).read()
_cut = "\ncoll = bpy.data.collections.get(COLLECTION)"
assert _cut in _v4_src
W = {"__name__": "gear04_lib"}
exec(compile(_v4_src.split(_cut)[0], _v4_path, "exec"), W)
B5 = {"__name__": "body05_lib", "BODY05_AS_LIBRARY": True}
exec(open(os.path.join(SCRIPTS, "build_cartoon_body_05.py")).read(), B5)
F, V = W["F"], W["V"]
L = B5["L"]
ORDER = B5["ORDER"]
BUILDS = tuple(b for b in os.environ.get("GEAR05_BUILDS", ",".join(ORDER)).split(",") if b)

# point v4 at the production bodies: their heights, their smoothed shapes, all six names
W["L"] = L
W["body_spec"] = B5["body_spec"]
_P = dict(W["P"])
_P["BUILDS"] = {b: (lambda _L, b=b: B5["body_spec"](b)) for b in ORDER}
W["P"] = _P
W["hold_shoulder"] = lambda o, pivot: None          # Phase 2: the tee copies the body's spread shoulder weights
# v4's mesher writes its field to "<temp>/gear04_<name>.vdb" and Blender keeps a loaded .vdb by its path, so a second
# piece with the same name (the long sleeve and bench shirt are made by make_tee, named "<Build>_Tee") silently got the
# FIRST piece's shape. Every call gets its own file.
_iso0 = W["iso_mesh"]
_iso_n = [0]


def _iso_unique(name, fn, lo, hi, coll):
    _iso_n[0] += 1
    o = _iso0("%s_%d_%d" % (name, os.getpid(), _iso_n[0]), fn, lo, hi, coll)
    o.name = name
    return o


W["iso_mesh"] = _iso_unique

# v4's cut_shell turns the faces outward as a WHOLE (it flips everything when most faces point in). Where the mesher's
# faces were mixed (Skinny-fat's knee sleeves) whole patches stayed facing in and vanished under one-sided drawing (as
# Roblox draws). Here each face is checked on its own against the shape's outward direction (the field grows outward)
# and turned if it points in. (Before the fabric gets its thickness, so the inside rows are untouched.)
_cut0 = W["cut_shell"]
FLIPPED = {}

# ---------------------------------------------------------------- thinning (the meet gear's triangle budget)
# User 2026-11-14: "Yes, thin it". Phase 3 budget (§11): under-tee ~800, singlet ~1,600, belt ~700, knee sleeves ~800,
# wraps ~500, sneakers ~600 = ~5,000 (was ~7,100). Each shell's inside is thinned harder (MEET_TRIS) and its edge
# points halved once more (EDGE_THIN rounds; every edge point costs ~4 triangles once the fabric has thickness, piping
# and rim). GEAR05_THIN=0 builds the unthinned version for comparison.
THIN = os.environ.get("GEAR05_THIN", "1") == "1"
MEET_TRIS = {"Tee": 560, "Singlet": 600, "KneeSleeves": 380, "Sneakers": 380}
EDGE_THIN = {"Tee": 1, "Singlet": 1, "KneeSleeves": 1, "Sneakers": 1}
_thin = [None]
# Wrist wraps: v4 ran them 0.17 below the wrist joint, which on the production hands is the middle of the palm: the
# lowest turn flared out over the hand like a skirt and skin showed between the turns (close-up 2026-11-14). Now from
# the base of the hand, the same overall width moved up the forearm, the joint still covered.
# (0.05, 0.21) with three turns puts the middle of the top turn at wrist + 0.167, where v03 lays the CENTRAL text
# (wrist + 0.16): at (0.06, 0.30) the text straddled two turns and broke up.
V["WRIST_WRAP"]["span"] = (0.05, 0.21)
if THIN:
    V["BELT_SEGMENTS"] = 18                     # 22 in v4, 28 in v03
    V["WRIST_WRAP"]["around"] = 10              # 12 in v4, 16 in v03


class Thin:
    """Inside this block, the next shells are cut to the meet budget for `kind`."""

    def __init__(self, kind):
        self.kind = kind

    def __enter__(self):
        _thin[0] = self.kind if THIN else None

    def __exit__(self, *exc):
        _thin[0] = None


def halve_edges(o):
    """Every other point along each open edge dissolved (the line keeps its shape at half the points)."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    drop, seen = [], set()
    for v in bm.verts:
        if v.is_boundary and v not in seen:
            nb = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
            if len(nb) == 2 and not any(n in seen for n in nb):
                # keep corners (a strap meeting the neck line): only points where the edge runs fairly straight
                a, c = (nb[0].co - v.co), (nb[1].co - v.co)
                if a.length > 1e-6 and c.length > 1e-6 and a.normalized().dot(c.normalized()) < -0.6:
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
    return len(drop)


def _cut_outward(o, fn, keep, rules, final_tris, smooth_rounds=10):
    kind = _thin[0]
    if kind:
        final_tris = MEET_TRIS[kind]
    out = _cut0(o, fn, keep, rules, final_tris, smooth_rounds)
    if kind:
        for _ in range(EDGE_THIN[kind]):
            halve_edges(o)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.normal_update()
    faces = list(bm.faces)
    if faces:
        C = np.array([f.calc_center_median()[:] for f in faces], dtype=np.float32)
        N = np.array([f.normal[:] for f in faces], dtype=np.float32)
        g = W["grad"](fn, C)
        bad = [f for f, d in zip(faces, (N * g).sum(axis=1)) if d < 0]
        if bad:
            bmesh.ops.reverse_faces(bm, faces=bad)
            bm.to_mesh(o.data)
        FLIPPED[o.name] = len(bad)
        if bad:
            log(o.name, "faces turned outward:", len(bad), "of", len(faces))
    bm.free()
    return out


W["cut_shell"] = _cut_outward
F["BUILDS"] = ORDER
COLLECTION = "CartoonGear05"

ITEMS = ("Tee", "TeeUnder", "WornSinglet", "WornLeverBelt", "WornKneeSleeve", "WornWristWrap", "Sneakers",
         "LongSleeve", "Tank", "WornSquatSuit", "WornDeadliftSuit", "WornBenchShirt", "WornKneeWrap", "Shorts",
         "Joggers")
_only = [i for i in os.environ.get("GEAR05_ITEMS", "").split(",") if i]
WANT = set(_only or ITEMS)
if "TeeUnder" in WANT or "WornSinglet" in WANT:
    WANT |= {"Tee", "WornSinglet", "TeeUnder"}       # the under-tee is cut from the whole tee against the singlet

# preview colours for the items v4 had none for (the game colours come from ShopConfig / ClothesConfig)
V["PREVIEW"].setdefault("WornBenchShirt", {})
V["PREVIEW"]["WornBenchShirt"].update({"Body": (0.62, 0.05, 0.05), "Shoulder": (0.03, 0.03, 0.035),
                                       "Trim": (0.03, 0.03, 0.035), "Patch": (1, 1, 1)})
V["PREVIEW"]["TeeUnder"] = {"Tee": (0.03, 0.03, 0.035), "TeeWhite": (0.75, 0.75, 0.77)}   # the photos' black tee
V["PREVIEW"]["Sneakers"] = dict(V["PREVIEW"].get("Sneakers", {}), Sneakers=(0.03, 0.03, 0.035),
                                SneakersSole=(0.9, 0.9, 0.9))
V["PREVIEW"]["WornSquatSuit"].update({"Body": (0.45, 0.04, 0.06), "Panel": (0.03, 0.03, 0.035),
                                      "Trim": (0.03, 0.03, 0.035), "Patch": (1, 1, 1)})
V["PREVIEW"]["WornDeadliftSuit"].update({"Body": (0.05, 0.12, 0.40), "Panel": (0.03, 0.03, 0.035),
                                         "Trim": (0.03, 0.03, 0.035), "Patch": (1, 1, 1)})


def log(*a):
    print("[Gear05]", *a, flush=True)


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def boundary_points(o):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    pts = [tuple(v.co) for v in bm.verts if v.is_boundary]
    bm.free()
    return pts


class Patched:
    """Swaps names in the v4 namespace for the length of one build call (the v4 builders read them as globals)."""

    def __init__(self, **kw):
        self.kw, self.old = kw, {}

    def __enter__(self):
        for k, v in self.kw.items():
            self.old[k] = W[k]
            W[k] = v

    def __exit__(self, *exc):
        W.update(self.old)


def covered_cut(tee, singlet, name, coll, margin=0.15, reach=0.25):
    # margin 0.15: at 0.07 the singlet (torso-held) slid far enough over the tee (arm-held at the shoulders) in the
    # bench and raise poses to open skin gaps at the cut line on the back
    """The tee as worn under the singlet, cut to what can show. Replaces v4's covered_cut, which dropped a face when
    the ray from its CENTRE met the singlet, so big faces at the cut line poked past the singlet's scoop and left
    see-through teeth inside the neckline. Here a face goes only when EVERY corner is covered: a ray out along the
    corner's normal meets the singlet at least `margin` away from any singlet edge (the cut line stays hidden)."""
    from mathutils.bvhtree import BVHTree
    from mathutils.kdtree import KDTree
    sm = singlet.data
    tree = BVHTree.FromPolygons([v.co for v in sm.vertices], [tuple(p.vertices) for p in sm.polygons])
    rim = boundary_points(singlet)
    kd = KDTree(max(1, len(rim)))
    for i, p in enumerate(rim):
        kd.insert(p, i)
    kd.balance()
    o = tee.copy()
    o.data = tee.data.copy()
    o.name = name
    coll.objects.link(o)
    keys = list(o["keys"])
    me = o.data
    covered = []
    for v in me.vertices:
        loc, _n, _i, _d = tree.ray_cast(v.co + v.normal * 0.004, v.normal, reach)
        covered.append(loc is not None and kd.find(loc)[2] > margin)
    gone = [p.index for p in me.polygons if all(covered[i] for i in p.vertices)]
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in gone], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    gone = set(gone)
    o["keys"] = [k for i, k in enumerate(keys) if i not in gone]
    return o


def rekey(o, fn):
    o["keys"] = [fn(i, k) for i, k in enumerate(o["keys"])]


def join_into(target, others):
    bpy.ops.object.select_all(action="DESELECT")
    target.select_set(True)
    for o in others:
        o.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()
    return target


def materials(pieces, worn):
    for key, p in pieces.items():
        p.data.materials.clear()
        p.data.materials.append(V["material"](worn, key))


def logos(body, coll, target, name, z_front, H, worn):
    """The CENTRAL logo under the front scoop and across the middle of the back (the v4 singlet's), one piece."""
    front = V["front_patch"](body, coll, target, name + "Patch", z_front, 0.46, 0.12, "Red")
    back = V["front_patch"](body, coll, target, name + "BackText", L["SH"] - 0.95, 0.62, 0.15, "Red", side="back")
    join_into(front, [back])
    F["transfer_weights"](front, body)
    return front


# ---------------------------------------------------------------- the one-piece family (singlet, suits, tank)
def one_piece(body, shell, H, coll, worn, leg_hem=None, hem=None, clear=None, keymap=None, tris_out=950):
    """The v4 singlet (make_singlet) with other leg lengths (`leg_hem`), or cut at a hem with no legs (`hem`, the tank),
    at another clearance (`clear`), its keys renamed (`keymap`: v4 key -> this item's key)."""
    Hx = dict(H)
    if leg_hem is not None:
        Hx["leg_hem"] = leg_hem
    cut0 = W["cut_shell"]

    def cut(o, fn, keep, rules, final_tris, smooth_rounds=10):
        if hem is not None:
            keep2 = lambda X: keep(X) & (X[:, 2] > hem)
            rules = [r for r in rules[1:]] + [(lambda X: X[:, 2] < hem + 0.2, lambda X: X[:, 2] - hem)]
        else:
            keep2 = keep
        return cut0(o, fn, keep2, rules, tris_out, smooth_rounds)
    sc = W["SINGLET_CLEAR"] if clear is None else clear
    with Patched(cut_shell=cut, SINGLET_CLEAR=sc):
        o = W["make_singlet"](body, shell, Hx, coll)
        o.name = "%s_%s" % (body.build, worn)
        if keymap:
            rekey(o, lambda i, k: keymap.get(k, k))
        relief = W["finish_shell"](o, body, sc, only=W["SINGLET_BONES"], cap=0.04)
    log(body.build, worn, tris(o), "triangles, pose relief up to %.3f" % relief)
    return o, Hx


def finish_one_piece(o, body, coll, H, worn, trim_key, plain_key, with_logo=True, tee=None, belt=None):
    """Out of the tee and pressed in under the belt (as the singlet), thickness, piping round the neck and armholes,
    the logo; one object per key."""
    if tee is not None:
        log(body.build, worn, "points pushed out of the tee:", W["push_out_of"](o, tee, 0.03))
    if belt is not None:
        log(body.build, worn, "under the belt:", W["under_belt"](o, belt, 0.015))
    edge = (lambda c, k: plain_key if c.z < H["leg_hem"] + 0.12 else trim_key)
    pipe = W["piping"](o, body.build + "_" + worn + "Piping", coll, body, lambda c: c.z > H["leg_hem"] + 0.12,
                       only=W["SINGLET_BONES"])
    W["thicken"](o, edge)
    z_nf = o["z_nf"]
    pieces = V["split_keys"](o, coll, body.build + "_" + worn)
    if trim_key in pieces:
        join_into(pieces[trim_key], [pipe])
    else:
        pieces[trim_key] = pipe
    if with_logo:
        target = pieces.get(plain_key) or next(iter(pieces.values()))
        pieces["Patch"] = logos(body, coll, target, body.build + "_" + worn, z_nf - 0.24, H, worn)
    materials(pieces, worn)
    return pieces


# ---------------------------------------------------------------- the sleeved family (tee, long sleeve, bench shirt)
def sleeved(body, H, coll, name, sleeve, tris_out=900):
    """The v4 tee (make_tee) with its sleeves ending at `sleeve` (the shell's arms counted from there up)."""
    Hx = dict(H, sleeve=sleeve, arm_from=sleeve - 0.12)
    shell = W["Shell"](B5["body_spec"](body.build), Hx["arm_from"])
    cut0 = W["cut_shell"]
    cut = lambda o, fn, keep, rules, final_tris, smooth_rounds=10: cut0(o, fn, keep, rules, tris_out, smooth_rounds)
    with Patched(cut_shell=cut):
        o = W["make_tee"](body, shell, Hx, coll)
    o.name = "%s_%s" % (body.build, name)
    return o, shell, Hx


# ---------------------------------------------------------------- wrist wraps v5 (a shell on the real skin)
# User 2026-11-14 (close-ups of the thinned set): "for the wrist wraps im seeing a lot of phasing through the body, and
# the body phasing through it." Causes: the v03 wound wrap was RIGID with the forearm (the hand swung through its lower
# turn whenever the wrist bent, as in every grip), its turns were rings round a smoothed outline of the forearm (the
# hand's base bulged out through it; its inner lips sat inside the arm), and the clearance test had left the hands out.
# Now, like the approved knee sleeves: a thick shell over the REAL skin of the forearm and the base of the hand (its
# inside hugging the skin), three turns stepping out (each turn's lower edge laps over the one below), the red stripe on
# the middle turn, CENTRAL on the top turn's outer side; it ends just under the wrist joint and is held by the forearm,
# with room where the hand moves under its edge (tried: the bottom turn following the hand halfway cut deeper into
# the hand in the squat set-up and the deadlift). No loose tail flap (it stuck out like a fin).
WRAP_SPAN = (0.03, 0.28)       # from just under the wrist joint up the forearm (at 0.07 down it climbed onto the
                               # palm's wide base: a flared bottom edge at rest, crumpled in the deadlift grip)
WRAP_TURNS = 3
WRAP_OUT = 0.050               # outside of the lowest turn from the skin
WRAP_STEP = 0.010              # each turn up stands this much further out
WRAP_GRIP = 0.012              # both ends pulled in this much (they grip there: no gap to the skin at the edge)
WRAP_THICK = 0.026             # the wrap's thickness: its inside ~0.024 off the skin
MEET_TRIS["WristWraps"] = 220
EDGE_THIN["WristWraps"] = 1
# 2026-11-14 (the animation session; plan approved by the user): the squat now holds the bar in the heel of the palm
# (the "SquatGrip" swap hand) with the elbows back and down as approved; with arms x1.5 that leaves the wrist bent back
# ~60 degrees for the whole bar hold (65 at the set-up's hardest frame), and the base of the hand swung up through the
# front of the wrap (up to 0.14 above the wrist joint, about a quarter of the way round: 35-110 wrap points inside the
# hand). The lower edge now RISES there, just enough to clear the posed hands: every keyframe of the squat hold, set-up
# and fails with the SquatGrip hand, and the bench and deadlift with the Grip hand, measured in the forearm's own frame
# (the wrap moves with the forearm, so there the hand is a fixed obstacle). The turns and the stripe follow the raised
# edge and the top rises by WRAP_TOP_FOLLOW of the lift: the wrap is tilted, wound on a slant, not notched. Capped at
# WRAP_LIFT_CAP of its height: the biggest hands (Muscular, Big and buff) need more than the whole wrap, so there the
# base of the hand still covers a little of its lower front in the squat.
# (animation, hand shape, from, to seconds): "Open" = the body's own hand. The squat set-up reaches for the bar from
# 0.45 s to 1.2 s (setup_animations.py) with the open hand, then holds it in the SquatGrip hand.
WRAP_HAND_POSES = tuple((a, "SquatGrip", 0.0, 99.0) for a in (
    "Station_Squat", "Fail_Squat_1", "Fail_Squat_2", "Fail_Bailout_Squat_1", "Fail_Bailout_Squat_2",
    "Fail_Dramatic_Squat_1", "Fail_Dramatic_Squat_2", "Fail_Grinder_Squat_1", "Fail_Grinder_Squat_2")) + \
    (("Setup_Squat", "SquatGrip", 1.2, 99.0), ("Station_Bench", "Grip", 0.0, 99.0),
     ("Station_Deadlift", "Grip", 0.0, 99.0))
# (Left out: the set-up's reach, 0.45-1.2 s, the open hand swinging up to the bar: it touched the wrap's lower edge
# all the way round for that half second, and clearing it shrank the whole wrap.)
WRAP_CLEAR = 0.012             # room kept between any posed hand and the wrap
WRAP_EDGE_GAP = 0.02           # the edge sits this much above the highest wrap point the hand would reach
# Tried (pictures 2026-11-14): one local rise (half-width 50-150) read as a deep U-notch on the front, several made
# chevrons and a zig-zag stripe; a half-height rise left the hand over the wrap. A rise of half-width 180 with the top
# following it is the whole wrap TILTED (a plane through a tube): it reads as a wrap wound on a slant.
WRAP_LIFT_WIDTH = 180.0        # degrees round the arm: the narrowest half-width of the rise
WRAP_LIFT_MAX_WIDTH = 180.0    # ... and the widest
WRAP_LIFT_CAP = 0.7            # the rise never takes more than this share of the wrap's height
WRAP_TOP_FOLLOW = 0.85         # the top edge rises by this share of the lower edge's rise
WRAP_LIFT_BINS = 72
if os.environ.get("GEAR05_WRAP_KNOBS"):          # trials: "cap,top_follow,min_width,max_width"
    WRAP_LIFT_CAP, WRAP_TOP_FOLLOW, WRAP_LIFT_WIDTH, WRAP_LIFT_MAX_WIDTH = \
        [float(x) for x in os.environ["GEAR05_WRAP_KNOBS"].split(",")]


def wrap_hand_obstacles(body):
    """{1 (left) / -1 (right): [(lo, hi, BVHTree, label)]}: each distinct posed swap hand of WRAP_HAND_POSES, carried
    into the forearm's REST frame (rig space). Repeated poses (the long hold) are kept once."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    rig = body.rig
    to_rig = rig.matrix_world.inverted()
    out = {1: [], -1: []}
    seen = {1: set(), -1: set()}
    try:
        for anim, shape, t0, t1 in WRAP_HAND_POSES:
            if not os.path.exists(os.path.join(F["ANIMS"], anim + ".rbxmx")):
                log(body.build, "wrap obstacles: no", anim)
                continue
            for t, data in F["read_anim"](anim):
                if not t0 <= t < t1:
                    continue
                F["pose_rig"](rig, data)
                for side, sx in (("Left", 1), ("Right", -1)):
                    name = "%s_%sHand" % (body.build, side) if shape == "Open" else "%s_%s%s" % (body.build, shape, side)
                    hand = bpy.data.objects.get(name)
                    assert hand is not None, name + " missing (add_squat_grip_05.py)"
                    fa = rig.pose.bones[side + "LowerArm"]
                    # (the open hand is skinned: its drawn points; the swap hands ride their bone)
                    pts, faces = F["evaluated_points"](hand, rig)
                    m = fa.bone.matrix_local @ fa.matrix.inverted()
                    hb = rig.pose.bones[side + "Hand"]
                    rel = m @ hb.matrix
                    key = (shape,) + tuple(round(rel[r][c], 2) for r in range(3) for c in range(4))
                    if key in seen[sx]:
                        continue
                    seen[sx].add(key)
                    pts = [m @ p for p in pts]
                    lo = Vector([min(p[i] for p in pts) for i in range(3)])
                    hi = Vector([max(p[i] for p in pts) for i in range(3)])
                    out[sx].append((lo, hi, BVHTree.FromPolygons(pts, faces), "%s@%.2f" % (anim, t)))
    finally:
        F["rest_rig"](rig)
    return out


def wrap_lift(body, skin, z_lo, z_hi, centre):
    """{sx: (lift per angle bin, worst label)}: how far the lower edge must rise at each angle round the arm (angle 0 =
    the arm's outer side, measured in the forearm's own x / z axes, mirrored on the right) so that no posed hand
    comes within WRAP_CLEAR of where the wrap lies (its inside to its outermost turn)."""
    from mathutils import Vector
    obst = wrap_hand_obstacles(body)
    ang = np.radians(np.arange(WRAP_LIFT_BINS) * 360.0 / WRAP_LIFT_BINS)
    zs = np.arange(z_lo, z_hi + 1e-6, 0.01)
    out = {}
    for sx in (1, -1):
        cx, cy = centre[sx]
        A, Z = np.meshgrid(ang, zs, indexing="ij")
        D = np.stack([sx * np.cos(A).ravel(), np.sin(A).ravel(), np.zeros(A.size)], axis=1)
        C = np.stack([np.full(A.size, cx), np.full(A.size, cy), Z.ravel()], axis=1)
        flagged = np.zeros(A.size, dtype=bool)
        worst = np.full(A.size, "", dtype=object)
        bounds = [z_lo + (z_hi - z_lo) * k / WRAP_TURNS for k in range(1, WRAP_TURNS)]
        turn_out = WRAP_OUT + WRAP_STEP * sum((Z.ravel() > b).astype(float) for b in bounds)   # each turn's outside
        for off in (WRAP_OUT - WRAP_THICK, turn_out - WRAP_THICK / 2, turn_out):
            lo, hi = np.zeros(A.size), np.full(A.size, 0.9)
            for _ in range(14):                       # where the skin is `off` away, out along each ray
                mid = (lo + hi) / 2
                inside = skin((C + D * mid[:, None]).astype(np.float32)) < off
                lo, hi = np.where(inside, mid, lo), np.where(inside, hi, mid)
            X = C + D * hi[:, None]
            for i, p in enumerate(X):
                if flagged[i]:
                    continue
                q = Vector(p.tolist())
                for blo, bhi, tree, label in obst[sx]:
                    if any(q[k] < blo[k] - 0.05 or q[k] > bhi[k] + 0.05 for k in range(3)):
                        continue
                    loc, nrm, _i, d = tree.find_nearest(q)
                    if loc is not None and (d if (q - loc).dot(nrm) >= 0 else -d) < WRAP_CLEAR:
                        flagged[i], worst[i] = True, label
                        break
        need = np.full(WRAP_LIFT_BINS, -9.0)
        need_by = [""] * WRAP_LIFT_BINS
        who = ""
        Zf = Z.ravel()
        for i in np.nonzero(flagged)[0]:
            b = i // len(zs)
            if Zf[i] > need[b]:
                need[b] = Zf[i]
                need_by[b] = worst[i]
                if Zf[i] >= need.max():
                    who = worst[i]
        if os.environ.get("GEAR05_WRAP_DEBUG"):
            for b in range(WRAP_LIFT_BINS):
                if need[b] > -9:
                    log(body.build, "WrapNeed", sx, int(b * 360 / WRAP_LIFT_BINS), "%.3f" % (need[b] - z_lo), need_by[b])
        raw = np.where(need > -9, np.maximum(0.0, need + WRAP_EDGE_GAP - z_lo), 0.0)
        raw = np.minimum(raw, WRAP_LIFT_CAP * (z_hi - z_lo))
        deg = np.arange(WRAP_LIFT_BINS) * 360.0 / WRAP_LIFT_BINS
        # ONE smooth rise (several overlapping ones made chevrons and a zig-zag stripe): as high as the highest need,
        # centred and as narrow as still covers every angle's need (WRAP_LIFT_WIDTH..WRAP_LIFT_MAX_WIDTH half-width)
        lift = np.zeros(WRAP_LIFT_BINS)
        if raw.max() > 0:
            amp = raw.max()
            best = None
            for w in np.arange(WRAP_LIFT_WIDTH, WRAP_LIFT_MAX_WIDTH + 1e-6, 5.0):
                for c in deg:
                    dd = np.abs((deg - c + 180.0) % 360.0 - 180.0)
                    bump = amp * np.where(dd < w, 0.5 * (1 + np.cos(np.pi * dd / w)), 0.0)
                    short = np.maximum(0.0, raw - bump).max()
                    if best is None or short < best[0] - 1e-9:
                        best = (short, bump)
                if best[0] <= 1e-9:
                    break
            lift = best[1]
            if best[0] > 0:
                log(body.build, "WristWraps", "edge rise short of the need by up to %.3f" % best[0])
        out[sx] = (lift, who)
        log(body.build, "WristWraps", "left" if sx > 0 else "right", "edge rise up to %.3f at %d deg (%s); %d hand "
            "poses" % (lift.max(), int(deg[int(np.argmax(lift))]), who, len(obst[sx])))
    return out


def build_wrist_wraps_05(body, coll):
    from mathutils import Vector
    wrist = body.joints["LeftHand"].z
    z_lo, z_hi = wrist - WRAP_SPAN[0], wrist + WRAP_SPAN[1]
    bounds = [z_lo + (z_hi - z_lo) * k / WRAP_TURNS for k in range(1, WRAP_TURNS)]
    # one tree per PART: the hand mesh overlaps the forearm's end, and one signed distance to both at once called a
    # point inside the hand "outside" when the forearm's face was nearer (the wrap then cut into the hand); the union
    # is the smaller of the two parts' own signed distances
    trees = {sx: [body.bvh((side + "LowerArm",)), body.bvh((side + "Hand",))]
             for side, sx in (("Left", 1), ("Right", -1))}
    smooth = B5["smoothstep"] if "smoothstep" in B5 else W["P"]["smoothstep"]

    def skin(X):
        """Signed distance to the forearm + hand skin of the arm on each point's side (negative inside)."""
        out = np.empty(len(X), dtype=np.float32)
        for i, p in enumerate(X):
            q = Vector(p.tolist())
            best = 9.0
            for tree in trees[1 if p[0] > 0 else -1]:
                loc, nrm, _i, d = tree.find_nearest(q)
                if loc is not None:
                    best = min(best, d if (q - loc).dot(nrm) >= 0 else -d)
            out[i] = best
        return out

    # the raised edge (WRAP_HAND_POSES): angle round each forearm's axis (vertical at rest, through the wrist joint)
    centre = {sx: (body.joints[side + "Hand"].x, body.joints[side + "Hand"].y)
              for side, sx in (("Left", 1), ("Right", -1))}
    lifts = wrap_lift(body, skin, z_lo, z_hi, centre)
    bins_deg = np.arange(WRAP_LIFT_BINS) * 360.0 / WRAP_LIFT_BINS

    def lift_at(X):
        out = np.zeros(len(X))
        for sx in (1, -1):
            sel = (X[:, 0] > 0) if sx > 0 else (X[:, 0] <= 0)
            if sel.any():
                cx, cy = centre[sx]
                a = np.degrees(np.arctan2(X[sel, 1] - cy, sx * (X[sel, 0] - cx))) % 360.0
                out[sel] = np.interp(a, bins_deg, lifts[sx][0], period=360.0)
        return out

    def edges(X):
        lf = lift_at(X)
        return z_lo + lf, z_hi + WRAP_TOP_FOLLOW * lf

    def u_of(X):
        """Height along the wrap as if it were level: z_lo at its (raised) lower edge, z_hi at its top."""
        lo, hi = edges(X)
        return z_lo + (X[:, 2] - lo) * (z_hi - z_lo) / (hi - lo)

    def z_of(X, u):
        lo, hi = edges(X)
        return lo + (u - z_lo) * (hi - lo) / (z_hi - z_lo)

    def fn(X):
        z = u_of(X)
        off = WRAP_OUT + sum(WRAP_STEP * smooth(b - 0.006, b + 0.006, z) for b in bounds)
        ends = np.maximum(1.0 - smooth(z_lo, z_lo + 0.03, z), smooth(z_hi - 0.03, z_hi, z))
        return skin(X) - (off - WRAP_GRIP * ends)
    top = z_hi + WRAP_TOP_FOLLOW * max(lifts[1][0].max(), lifts[-1][0].max())
    sides = []
    for side, sx in (("Left", 1), ("Right", -1)):
        jx = body.joints[side + "Hand"].x
        s = W["iso_mesh"]("%s_WristWrap%s" % (body.build, side), fn, (jx - 0.6, -0.6, z_lo - 0.08),
                          (jx + 0.6, 0.6, top + 0.08), coll)
        sides.append(s)
    o = join_into(sides[0], sides[1:])
    o.name = body.build + "_WornWristWrap"
    W["apply_mod"](o, "SMOOTH", factor=0.5, iterations=3)
    W["apply_mod"](o, "DECIMATE", ratio=min(1.0, 3000 / max(1, tris(o))), use_symmetry=False)
    keep = lambda X: (u_of(X) >= z_lo) & (u_of(X) <= z_hi)
    rules = [(lambda X: u_of(X) < z_lo + 0.1, lambda X: X[:, 2] - edges(X)[0]),
             (lambda X: u_of(X) > z_hi - 0.1, lambda X: X[:, 2] - edges(X)[1])]
    with Thin("WristWraps"):
        W["cut_shell"](o, fn, keep, rules, 360)
    mid = (bounds[0] + bounds[1]) / 2 if len(bounds) > 1 else (z_lo + z_hi) / 2
    st_lo, st_hi = mid - 0.018, mid + 0.018
    # the stripe's two lines follow the slant: cut flat in the level heights, then put back
    me = o.data
    P = np.array([v.co[:] for v in me.vertices], dtype=np.float64)
    U_ = u_of(P)
    for v, uu in zip(me.vertices, U_):
        v.co.z = uu
    W["bisect"](o, [((0, 0, st_lo), (0, 0, 1)), ((0, 0, st_hi), (0, 0, 1))])
    me = o.data
    P = np.array([v.co[:] for v in me.vertices], dtype=np.float64)
    Zr = z_of(P, P[:, 2])
    for v, zz in zip(me.vertices, Zr):
        v.co.z = zz
    me.update()
    W["face_keys"](o, lambda C: np.where((u_of(C) > st_lo) & (u_of(C) < st_hi), "Stripes", "Body"))
    F["push_clear"](o, body, WRAP_THICK + 0.008, region="All")
    # held by the forearm: with the hand's share the bottom turn twisted and crumpled when the hand turned palm-in at
    # the wrist (the deadlift grip); it now ends just under the joint, and pose_relief makes room where the hand
    # moves under its edge
    bones = ("LeftLowerArm", "RightLowerArm")
    F["transfer_weights"](o, body, region=bones, only=bones)
    relief = F["pose_relief"](o, body, cap=0.03)
    W["thicken"](o, thick=WRAP_THICK)
    log(body.build, "WristWraps", tris(o), "triangles, pose relief up to %.3f" % relief)
    pieces = V["split_keys"](o, coll, body.build + "_WornWristWrap")
    texts = []
    z_t = (bounds[-1] + z_hi) / 2
    u0, u1 = V["LOGO_U"]
    v_top = 1 - V["LOGO_ROWS"]["White"] / 4.0
    for side, sx in (("Left", 1), ("Right", -1)):
        el, wr = body.joints[side + "LowerArm"], body.joints[side + "Hand"]

        def axis(z, el=el, wr=wr):
            t = (z - wr.z) / max(1e-6, el.z - wr.z)
            return wr + (el - wr) * t
        outer = 0.0 if sx > 0 else math.pi
        path = []
        for t in [i / 8 for i in range(9)]:
            a = outer + 1.0 * (t - 0.5)
            cx, cy = centre[sx]
            Xa = np.array([[cx + math.cos(a), cy + math.sin(a), z_t]])
            path.append((a, float(z_of(Xa, np.array([z_t]))[0])))     # the top turn's middle, on the slant
        target = [p for k, p in pieces.items()]
        tx = V["limb_overlay"](body, coll, target, axis, path, 0.06, 0.010, body.build + "_WristText" + side,
                               uv=(u0, u1, v_top - 0.25, v_top))
        if tx:
            texts.append(tx)
    if texts:
        join_into(texts[0], texts[1:])
        F["transfer_weights"](texts[0], body, region=bones, only=bones)
        pieces["Text"] = texts[0]
    materials(pieces, "WornWristWrap")
    return pieces


def to_parts(pieces, prefix_of, body, coll):
    made = []
    for key, o in pieces.items():
        made += F["split_parts"](o, prefix_of(key), body, coll,
                                 material=o.data.materials[0] if o.data.materials else None)
    return made


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
    m = H["m"]
    shell = W["Shell"](B5["body_spec"](b), H["arm_from"])
    belt = V["belt_shape"](body)
    made = {}
    log(b, "heights", {k: round(v, 3) for k, v in H.items() if isinstance(v, float)})

    # --- the meet set (v4): tee + singlet layered, both pressed in under the belt; the under-tee cut from the tee
    tee_whole = None
    if "Tee" in WANT:
        with Thin("Tee"):
            tee = tee_whole = W["make_tee"](body, shell, H, coll)
        with Thin("Singlet"):
            singlet = W["make_singlet"](body, shell, H, coll)
        W["finish_singlet"](singlet, body, coll, H)
        log(b, "singlet points pushed out of the tee:", W["push_out_of"](singlet, tee, 0.03))
        log(b, "under the belt: tee", W["under_belt"](tee, belt, 0.05), "singlet", W["under_belt"](singlet, belt, 0.015))
        z_nf = singlet["z_nf"]
        tee_openings = boundary_points(tee)
        under = covered_cut(tee, singlet, b + "_TeeUnder", coll)
        W["thicken"](tee)
        W["thicken"](under, near=tee_openings)
        # a copy of the whole tee for the suits to sit outside of (the tee itself is split up below)
        tee_whole = bpy.data.objects.new(b + "_TeeRef", tee.data.copy())
        coll.objects.link(tee_whole)
        pipe = W["piping"](singlet, b + "_SingletPiping", coll, body, lambda c: c.z > H["leg_hem"] + 0.12,
                           only=W["SINGLET_BONES"])
        W["thicken"](singlet, W["singlet_edge"](H))
        for name, o in (("Tee", tee), ("TeeUnder", under)):
            pieces = V["split_keys"](o, coll, b + "_" + name)
            materials(pieces, name)
            made[name] = to_parts(pieces, lambda k, name=name: k.replace("Tee", name), body, coll)
        s_pieces = V["split_keys"](singlet, coll, b + "_WornSinglet")
        if "Trim" in s_pieces:
            join_into(s_pieces["Trim"], [pipe])
        else:
            s_pieces["Trim"] = pipe
        s_pieces["Patch"] = logos(body, coll, s_pieces["Black"], b + "_Singlet", z_nf - 0.24, H, "WornSinglet")
        materials(s_pieces, "WornSinglet")
        made["WornSinglet"] = to_parts(s_pieces, lambda k: "WornSinglet_" + k, body, coll)
    if "WornLeverBelt" in WANT:
        made["WornLeverBelt"] = to_parts(V["build_belt"](body, coll), lambda k: "WornLeverBelt_" + k, body, coll)
    if "WornKneeSleeve" in WANT:
        with Thin("KneeSleeves"):
            sleeves = W["make_knee_sleeves"](body, shell, H, coll)
        made["WornKneeSleeve"] = to_parts(sleeves, lambda k: "WornKneeSleeve_" + k, body, coll)
    if "WornWristWrap" in WANT:
        made["WornWristWrap"] = to_parts(build_wrist_wraps_05(body, coll), lambda k: "WornWristWrap_" + k, body, coll)
    if "Sneakers" in WANT:
        with Thin("Sneakers"):
            shoes = W["make_sneakers"](body, shell, coll)
        made["Sneakers"] = to_parts(shoes, lambda k: k, body, coll)

    # --- suits: the singlet's top with longer legs (squat suit to mid-thigh, deadlift suit a little shorter)
    suit_keys = {"Black": "Body", "Red": "Panel", "Shorts": "Body", "Trim": "Trim"}
    for worn, frac in (("WornSquatSuit", 0.34), ("WornDeadliftSuit", 0.24)):
        if worn not in WANT:
            continue
        leg_hem = m["crotch"] - frac * (m["crotch"] - m["knee"])
        with Thin("Singlet"):                         # worn instead of the singlet: the same budget
            o, Hs = one_piece(body, shell, H, coll, worn, leg_hem=leg_hem, keymap=suit_keys, tris_out=1000)
        made[worn] = to_parts(finish_one_piece(o, body, coll, Hs, worn, "Trim", "Body", tee=tee_whole, belt=belt),
                              lambda k, worn=worn: worn + "_" + k, body, coll)

    # --- tank: the singlet's top cut at the tee's hem, worn alone at tee clearance, one colour
    if "Tank" in WANT and os.environ.get("GEAR05_TANK", "v03") == "v03":
        # the v03 ring-built tank (outline rings + strap arcs): the singlet-shell tank below crumpled along its neck
        # and straps at tee clearance (kept for comparison: GEAR05_TANK=shell)
        made["Tank"] = to_parts(V["CLOTHES_BUILDERS"]["Tank"](body, coll), lambda k: k, body, coll)
    elif "Tank" in WANT:
        # a little looser than the tee (at 0.035 the straps followed the traps' bumps and crumpled)
        o, Ht = one_piece(body, shell, H, coll, "Tank", hem=H["hem"], clear=0.05,
                          keymap={"Black": "Tank", "Red": "Tank", "Shorts": "Tank"}, tris_out=950)
        Ht = dict(Ht, leg_hem=H["hem"] - 1.0)        # no legs: every edge is bound
        pieces = finish_one_piece(o, body, coll, Ht, "Tank", "TankWhite", "Tank", with_logo=False)
        made["Tank"] = to_parts(pieces, lambda k: k, body, coll)

    # --- long sleeve: the tee with sleeves to the wrist (white cuffs)
    if "LongSleeve" in WANT:
        o, _sh, _H = sleeved(body, H, coll, "LongSleeve", m["wrist"] + 0.19, tris_out=1300)
        rekey(o, lambda i, k: k.replace("Tee", "LongSleeve"))
        W["thicken"](o)
        pieces = V["split_keys"](o, coll, b + "_LongSleeve")
        materials(pieces, "LongSleeve")
        made["LongSleeve"] = to_parts(pieces, lambda k: k, body, coll)

    # --- bench shirt: the tee shell, sleeves to above the elbow, thick fabric, sleeves its Shoulder colour
    if "WornBenchShirt" in WANT:
        o, sh_b, Hb = sleeved(body, H, coll, "WornBenchShirt", m["elbow"] + 0.38, tris_out=1000)
        # the sleeves in their own colour up to a straight seam over the shoulder (just outside the shoulder joint),
        # below the armpit along the arm's own crease (the sleeve tube and the body are separate surfaces there)
        seam, z_ap = body.joints["LeftUpperArm"].x + 0.12, m["armpit"]
        W["bisect"](o, [((sx * seam, 0, 0), (1, 0, 0), lambda c: c.z > z_ap - 0.05) for sx in (1, -1)] +
                    [((0, 0, z_ap), (0, 0, 1), lambda c: abs(c.x) > seam - 0.25)])
        o["keys"] = ["Tee"] * len(o.data.polygons)
        C = np.array([p.center[:] for p in o.data.polygons], dtype=np.float32)
        lab = sh_b.label(C)
        cuff_z = Hb["sleeve"] + 0.13
        rekey(o, lambda i, k: ("Trim" if lab[i] == 1 and C[i, 2] < cuff_z else
                               "Shoulder" if (C[i, 2] >= z_ap and abs(C[i, 0]) > seam) or
                               (C[i, 2] < z_ap and lab[i] == 1) else "Body"))
        W["thicken"](o, thick=0.03)
        pieces = V["split_keys"](o, coll, b + "_WornBenchShirt")
        back = V["front_patch"](body, coll, pieces["Body"], b + "_BenchShirtBackText", L["SH"] - 0.95, 0.62, 0.15,
                                "Red", side="back")
        F["transfer_weights"](back, body)
        pieces["Patch"] = back
        materials(pieces, "WornBenchShirt")
        made["WornBenchShirt"] = to_parts(pieces, lambda k: "WornBenchShirt_" + k, body, coll)

    # --- v03 builders (outline rings measured on this body)
    if "WornKneeWrap" in WANT:
        made["WornKneeWrap"] = to_parts(V["build_knee_wraps"](body, coll), lambda k: "WornKneeWrap_" + k, body, coll)
    for item in ("Shorts", "Joggers"):
        if item in WANT:
            made[item] = to_parts(V["CLOTHES_BUILDERS"][item](body, coll), lambda k: k, body, coll)

    RESULT[b] = made
    log(b, "TRIANGLES", {k: sum(tris(p) for p in v) for k, v in made.items()})

# leftovers of the build steps (the whole garments before the R15 split, overlays) are removed: only the game pieces
# "<Build>_<Worn>_<Key>__<Part>" / "<Build>_<Item>__<Part>" stay
keep = {p.name for made in RESULT.values() for v in made.values() for p in v}
for o in list(coll.objects):
    if o.name not in keep:
        bpy.data.objects.remove(o, do_unlink=True)
for c in [c for c in bpy.data.collections if c.name.startswith(("Gear03Outline", "Gear03Test"))]:
    bpy.data.collections.remove(c)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
log("saved", OUT_BLEND, sum(len(v) for made in RESULT.values() for v in made.values()), "pieces")
