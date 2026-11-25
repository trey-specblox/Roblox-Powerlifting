# The three lift coaches' own bodies, PROTOTYPE 01 (GAME_DESIGN §40.5; the user's descriptions 2026-11-23,
# work started 2026-11-24 "we can start with the coach figures"). [EXPERIMENTAL, waiting for the user's look]
#
#   Coach Squatavious (squat):   "a really muscular short midget": very short, short limbs, heavily muscled
#   Coach Benchamin (bench):     "a muscular guy with less muscular legs": muscular top on thin legs
#   Coach Sumo (deadlift):       "a skinnier/leaner guy with a really short torso long legs and long arms"
#
# The approved body method (build_cartoon_body_05.py, CHARACTER_ART_DIRECTION.md §11 Phase 2), on each coach's OWN
# skeleton: the shared base mesh (Base05_Fit from CartoonBodies_05.blend: same points, same order as the six lifter
# bodies, so the rig and gear tools work on them) reshaped onto each coach's distance field. A coach's shapes are an
# approved build's shapes moved onto the coach's joint heights (each part stretched or squashed between its joints:
# a shorter thigh, not a thinner one), plus the coach's own changes.
#
# Run headless:  blender -b --python art/scripts/build_coach_bodies_01.py
# Writes art/blender/CoachBodies_01.blend ("CoachBodies01": CoachBody01_<Coach> + hands; "Preview": stand-in heads and
# the Fit lifter for scale) and art/previews/CoachBodies01_*.png (backface culling on, as Roblox draws).
import math
import os

import bpy
import numpy as np
from mathutils import Vector

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
BODIES05 = os.path.join(ROOT, "art", "blender", "CartoonBodies_05.blend")
OUT_BLEND = os.path.join(ROOT, "art", "blender", "CoachBodies_01.blend")
PREVIEWS = os.path.join(ROOT, "art", "previews")
SPACING = 4.6

B = {"__name__": "body05_lib", "BODY05_AS_LIBRARY": True}
exec(open(os.path.join(SCRIPTS, "build_cartoon_body_05.py")).read(), B)
L = B["L"]
E, C, smin, smoothstep, lerp = B["E"], B["C"], B["smin"], B["smoothstep"], B["lerp"]
log = B["log"]

# ------------------------------------------------------------------------------------------- the coaches' skeletons
# Heights in studs (the lifters: ankle 0.252, knee 1.00, hips 2.0, waist 2.54, shoulder 4.38, neck 4.70, elbow 3.287,
# wrist 2.148; the head 1.2 on top: ~5.9 tall). The feet stay the lifters' (same shoes).


def skeleton(thigh, shin, torso, upper_arm, lower_arm):
    """Joint heights from segment lengths (torso = hips to neck; the waist and shoulder at the lifters' shares)."""
    A = L["A"]
    K = A + shin
    HJ = K + thigh
    N = HJ + torso
    W = HJ + torso * (L["W"] - L["HJ"]) / (L["N"] - L["HJ"])
    SH = N - (L["N"] - L["SH"]) * (torso / (L["N"] - L["HJ"])) ** 0.5
    E_ = SH - upper_arm
    return dict(A=A, K=K, HJ=HJ, W=W, N=N, SH=SH, E=E_, WR=E_ - lower_arm)


LIFTER = (L["HJ"] - L["K"], L["K"] - L["A"], L["N"] - L["HJ"], L["SH"] - L["E"], L["E"] - L["WR"])
SKELETONS = {
    # very short: legs ~half the lifters', torso ~0.72, arms ~0.62 (dwarf proportions: the limbs shortest); ~4.3 tall
    "Squatavious": skeleton(0.52, 0.42, 1.95, 0.70, 0.70),
    # the lifters' own skeleton
    "Benchamin": dict(L),
    # torso ~0.63 of the lifters', thighs x1.55, shins x1.47, arms x1.27: hands at the knees; ~5.8 tall
    "Sumo": skeleton(1.55, 1.10, 1.70, 1.40, 1.45),
}
ORDER = ("Squatavious", "Benchamin", "Sumo")
LABEL = {"Squatavious": "Coach Squatavious", "Benchamin": "Coach Benchamin", "Sumo": "Coach Sumo", "Fit": "A lifter (Fit)"}


# ------------------------------------------------------------------------------------------- moving shapes
def piecewise(knots_from, knots_to):
    """z on one skeleton -> the same place on another, linear between joints, a plain shift outside them; and the local
    stretch factor."""
    kf, kt = list(knots_from), list(knots_to)

    def f(z):
        if z <= kf[0]:
            return kt[0] + (z - kf[0]), 1.0
        if z >= kf[-1]:
            return kt[-1] + (z - kf[-1]), 1.0
        for i in range(len(kf) - 1):
            if kf[i] <= z <= kf[i + 1]:
                k = (kt[i + 1] - kt[i]) / (kf[i + 1] - kf[i])
                return kt[i] + (z - kf[i]) * k, k
        return z, 1.0
    return f


def onto(shapes, zmap):
    out = []
    for kind, args, blend, op, mirror in shapes:
        if kind == "cone":
            a, b, ra, rb = args
            args = ((a[0], a[1], zmap(a[2])[0]), (b[0], b[1], zmap(b[2])[0]), ra, rb)
        elif kind == "ellipsoid":
            c, r, rot = args
            z, k = zmap(c[2])
            args = ((c[0], c[1], z), (r[0], r[1], r[2] * k), rot)
        elif kind == "box":
            c, h, rad, rot = args
            z, k = zmap(c[2])
            args = ((c[0], c[1], z), (h[0], h[1], h[2] * k), rad, rot)
        out.append((kind, args, blend, op, mirror))
    return out


def scale_x(shapes, sx, sy=1.0):
    """Wider (and deeper) shapes about the centre line: positions and radii (a stockier frame)."""
    out = []
    for kind, args, blend, op, mirror in shapes:
        if kind == "cone":
            a, b, ra, rb = args
            args = ((a[0] * sx, a[1] * sy, a[2]), (b[0] * sx, b[1] * sy, b[2]), ra * sx, rb * sx)
        elif kind == "ellipsoid":
            c, r, rot = args
            args = ((c[0] * sx, c[1] * sy, c[2]), (r[0] * sx, r[1] * sy, r[2]), rot)
        elif kind == "box":
            c, h, rad, rot = args
            args = ((c[0] * sx, c[1] * sy, c[2]), (h[0] * sx, h[1] * sy, h[2]), rad, rot)
        out.append((kind, args, blend, op, mirror))
    return out


def thinner(shapes, k):
    """Thinner limb shapes (radii only, the same places)."""
    out = []
    for kind, args, blend, op, mirror in shapes:
        if kind == "cone":
            a, b, ra, rb = args
            args = (a, b, ra * k, rb * k)
        elif kind == "ellipsoid":
            c, r, rot = args
            args = (c, (r[0] * k, r[1] * k, r[2]), rot)
        out.append((kind, args, blend, op, mirror))
    return out


def moved(spec, skel):
    """An approved build's spec (on L) moved onto a coach's skeleton."""
    out = dict(spec)
    out["torso"] = onto(spec["torso"], piecewise((L["HJ"], L["W"], L["SH"], L["N"]),
                                                 (skel["HJ"], skel["W"], skel["SH"], skel["N"])))
    out["arm"] = onto(spec["arm"], piecewise((L["WR"], L["E"], L["SH"]), (skel["WR"], skel["E"], skel["SH"])))
    feet = spec["leg"][-2:]                        # common_feet: the shoes stay where they are
    out["leg"] = onto(spec["leg"][:-2], piecewise((L["A"], L["K"], L["HJ"]), (skel["A"], skel["K"], skel["HJ"]))) + feet
    out["skel"] = skel
    return out


# ------------------------------------------------------------------------------------------- the three coaches
# MORE TONED (user 2026-11-24, "Make them all more toned"): real muscle shapes on every part (Sumo's and Benchamin's legs
# from the Fit build, thinned) plus definition lines measured off each body's own surface (tone() below), so the lines
# sit at the same shallow depth on any shape. The Muscular build's own grooves are swapped for the measured ones.
def adds_only(shapes):
    return [sh for sh in shapes if sh[3] == "add"]


def squatavious():
    """Very short and very muscular: the Muscular build's masses on the short skeleton, a little wider and deeper
    (stocky), with bigger traps and delts; thick short legs and arms; full definition."""
    spec = B["body_spec"]("Muscular")
    skel = SKELETONS["Squatavious"]
    s = moved(spec, skel)
    s["torso"] = scale_x(adds_only(s["torso"]), 1.08, 1.06)
    N, SH = skel["N"], skel["SH"]
    s["torso"] = s["torso"] + [
        C((0.30, 0.10, N + 0.26), (1.06, 0.06, SH + 0.05), 0.24, 0.29, blend=0.20),       # big traps up the head's sides
    ]
    s["arm"] = scale_x(s["arm"], 1.06)
    s["leg"] = s["leg"][:-2] + B["common_feet"](1.10)
    s.update(name="Squatavious", arm_x=spec["arm_x"] * 1.06, pivot_x=spec["pivot_x"] * 1.06, hand=1.40, tone=0.034)
    return s


def benchamin():
    """A big muscular top (the Muscular build's torso, a bigger chest, the big build's delts, traps and arms) on thin
    but defined legs (the Fit build's leg muscles at 80%): the bench specialist who skips leg day."""
    top = B["body_spec"]("Muscular")
    big = B["body_spec"]("BigBuff")
    fit = B["body_spec"]("Fit")
    s = moved(top, SKELETONS["Benchamin"])
    s["torso"] = adds_only(s["torso"])
    CZ = lerp(L["W"], L["N"], 0.60)
    SH, N = L["SH"], L["N"]
    s["torso"] = s["torso"] + [
        E((0.48, -0.40, CZ + 0.02), (0.60, 0.27, 0.35), blend=0.22, rot=(6, -12, 0)),     # a big pec slab
        C((0.14, -0.50, CZ + 0.30), (1.06, -0.28, SH - 0.12), 0.15, 0.19, blend=0.22),    # upper pec into the delt
        E((1.44, 0.0, SH - 0.10), (0.48, 0.50, 0.52), blend=0.20),                         # big round delt
        C((0.30, 0.12, N + 0.30), (1.12, 0.08, SH + 0.06), 0.24, 0.30, blend=0.22),       # big traps
    ]
    s["arm"] = big["arm"]                                                                   # the big build's arms
    s["leg"] = thinner(fit["leg"][:-2], 0.80) + B["common_feet"](0.98) + [
        E((0.5, -0.06, L["A"] + 0.02), (0.18, 0.27, 0.13), blend=0.12)]                    # rounded ankle
    s.update(name="Benchamin", arm_x=big["arm_x"], pivot_x=big["pivot_x"], hand=1.50, k_shoulder=0.22, k_hip=0.16,
             tone=0.032)
    return s


def sumo():
    """Lean, lanky and toned: the Fit build's muscles (pecs, delts, lats, biceps, triceps, quads, hamstrings, calves)
    slimmed (torso 88% wide, limbs about 80% thick) on the short-torso, long-leg, long-arm skeleton."""
    spec = B["body_spec"]("Fit")
    s = moved(spec, SKELETONS["Sumo"])
    s["torso"] = scale_x(adds_only(s["torso"]), 0.88, 0.90)
    s["arm"] = thinner(scale_x(s["arm"], 0.88), 0.93)
    A = SKELETONS["Sumo"]["A"]
    # a rounded ankle: the thin shin melts into the shoe instead of sitting on a flat box top
    s["leg"] = thinner(s["leg"][:-2], 0.80) + B["common_feet"](1.0) + [
        E((0.5, -0.06, A + 0.02), (0.18, 0.27, 0.13), blend=0.12)]
    s.update(name="Sumo", arm_x=spec["arm_x"] * 0.88, pivot_x=spec["pivot_x"] * 0.88, hand=1.10, tone=0.030)
    return s


# ------------------------------------------------------------------------------------------- definition lines
GROOVE_R = 0.065          # groove radius: wide and shallow, reads on the even mesh (body 05's are 0.04-0.06)


def surface(fn, start, direction, far=3.0, step=0.004):
    """The first point where a ray from outside enters the solid (None if it never does)."""
    start = np.asarray(start, dtype=np.float32)
    d = np.asarray(direction, dtype=np.float32)
    d = d / np.linalg.norm(d)
    ts = np.arange(0.0, far, step, dtype=np.float32)
    vals = fn(start[None, :] + ts[:, None] * d[None, :])
    inside = np.nonzero(vals < 0)[0]
    if not len(inside):
        return None
    j = int(inside[0])
    if j == 0:
        return start
    a, b = vals[j - 1], vals[j]
    return start + d * (ts[j - 1] + step * a / (a - b))


def grad_of(fn):
    def g(P, eps=0.003):
        out = np.zeros_like(P)
        for a in range(3):
            d = np.zeros(3, dtype=np.float32)
            d[a] = eps
            out[:, a] = (fn(P + d) - fn(P - d)) / (2 * eps)
        return out
    return g


def groove(fn, p1, p2, view, depth, mirror=True, pieces=5):
    """A definition line from p1 to p2 (each (x, y, z): the ray starts there and goes along `view` to the skin), cut
    `depth` deep as a chain of short carve cones that follow the skin (one straight cone would sink in the middle)."""
    grad = grad_of(fn)
    pts = []
    for i in range(pieces + 1):
        t = i / pieces
        start = np.array(p1, dtype=np.float32) * (1 - t) + np.array(p2, dtype=np.float32) * t
        hit = surface(fn, start, view)
        if hit is None:
            log("definition line missed the body at", tuple(round(float(v), 2) for v in start))
            return []
        g = grad(hit[None, :].astype(np.float32))[0]
        n = g / max(float(np.linalg.norm(g)), 1e-6)
        pts.append(hit + n * (GROOVE_R - depth))
    return [C(tuple(map(float, pts[i])), tuple(map(float, pts[i + 1])), GROOVE_R, GROOVE_R, blend=0.06, op="carve",
              mirror=mirror) for i in range(pieces)]


def tone(spec):
    """Adds the measured definition lines to a coach's spec: torso front (sternum, pec edge, centre line, three ab
    rows, obliques) and back (spine, shoulder blades), arms (biceps/triceps, delt/biceps), legs (two quad lines,
    hamstrings, calf)."""
    depth = spec["tone"]
    sk = spec["skel"]
    HJ, W, N, SH, E_, K, A = (sk[k] for k in ("HJ", "W", "N", "SH", "E", "K", "A"))
    t = N - HJ
    CZ = lerp(W, N, 0.60)
    field = CoachField(dict(spec))
    torso = lambda P: field.part(0, P)
    arm = lambda P: field.part(1, P)
    leg = lambda P: field.part(3, P)

    def half_width(fn, z, y=0.0):
        hit = surface(fn, (3.0, y, z), (-1, 0, 0), far=3.0)
        return float(hit[0]) if hit is not None else 0.5

    pec_z = CZ - 0.11 * t
    # the chest's width at the pec line, on the front half (at chest height the big builds' delts and lats are in the
    # torso and doubled it: the pec and oblique lines then aimed off the body)
    hw_chest, hw_waist = min(half_width(torso, pec_z, -0.3), 1.05), half_width(torso, W + 0.1, -0.2)
    FRONT, BACK = (0, 1, 0), (0, -1, 0)
    cuts = []
    cuts += groove(torso, (0, -3, CZ + 0.10 * t), (0, -3, pec_z + 0.02), FRONT, depth, mirror=False)          # sternum
    cuts += groove(torso, (0.10 * hw_chest, -3, pec_z), (0.72 * hw_chest, -3, pec_z + 0.04 * t), FRONT, depth)  # pec edge
    # a short torso (Squatavious) gets two ab rows set higher: three crowded rows put the lowest on the waist, where it
    # read as a belt
    rows = 2 if t < 2.2 else 3
    top_abs, low_abs = pec_z - 0.07 * t, W + (0.12 * t if rows == 2 else 0.02)
    cuts += groove(torso, (0, -3, top_abs + 0.04), (0, -3, W - 0.06), FRONT, depth, mirror=False)              # centre line
    for r in range(rows):                                                                                      # ab rows
        z = lerp(top_abs, low_abs, r / (rows - 1.0))
        half = 0.34 * hw_waist * (1.0 - 0.12 * r / (rows - 1.0))
        cuts += groove(torso, (-half, -3, z), (half, -3, z), FRONT, depth * 0.85, mirror=False, pieces=6)
    cuts += groove(torso, (0.66 * hw_chest, -3, pec_z - 0.03 * t), (0.52 * hw_waist, -3, W - 0.02), FRONT,
                   depth * 0.8)                                                                                 # obliques
    cuts += groove(torso, (0, 3, N - 0.14 * t), (0, 3, W - 0.10), BACK, depth, mirror=False, pieces=6)         # spine
    cuts += groove(torso, (0.30 * hw_chest, 3, N - 0.08 * t), (0.48 * hw_chest, 3, CZ - 0.10 * t), BACK,
                   depth * 0.8)                                                                                 # shoulder blades
    spec["torso"] = spec["torso"] + cuts

    ax = spec["arm_x"]
    up = SH - E_
    arm_cuts = []
    arm_cuts += groove(arm, (ax + 3, 0.0, SH - 0.30 * up), (ax + 3, 0.0, E_ + 0.10 * up), (-1, 0, 0), depth)  # biceps|triceps
    arm_cuts += groove(arm, (ax, -3, SH - 0.22 * up), (ax + 0.12, -3, SH - 0.34 * up), FRONT, depth * 0.9,
                       pieces=3)                                                                                # delt|biceps
    spec["arm"] = spec["arm"] + arm_cuts

    th = HJ - K
    sh_ = K - A
    leg_cuts = []
    leg_cuts += groove(leg, (0.42, -3, K + 0.14 * th), (0.50, -3, K + 0.50 * th), FRONT, depth)               # inner quad
    leg_cuts += groove(leg, (0.62, -3, K + 0.16 * th), (0.64, -3, HJ - 0.24 * th), FRONT, depth)              # outer quad
    leg_cuts += groove(leg, (0.50, 3, HJ - 0.26 * th), (0.50, 3, K + 0.22 * th), BACK, depth * 0.8)           # hamstrings
    leg_cuts += groove(leg, (0.50, 3, K - 0.10 * sh_), (0.50, 3, K - 0.45 * sh_), BACK, depth * 0.8, pieces=3)  # calf
    spec["leg"] = spec["leg"] + leg_cuts
    log(spec["name"], "definition pieces:", len(cuts), "torso,", len(arm_cuts), "arm,", len(leg_cuts), "leg")
    return spec


COACHES = {"Squatavious": squatavious, "Benchamin": benchamin, "Sumo": sumo}


# ------------------------------------------------------------------------------------------- per-skeleton tools
class CoachField(B["Field"]):
    """The body-05 field with the joins at the coach's own shoulder and hip heights."""

    def join(self, T, AL, AR, GL, GR, P):
        sk = self.spec.get("skel", L)
        z, ax = P[:, 2], np.abs(P[:, 0])
        k_sh = self.spec["k_shoulder"] * smoothstep(sk["SH"] - 0.80, sk["SH"] - 0.25, z) * smoothstep(0.5, 0.8, ax)
        d = smin(T, np.minimum(AL, AR), k_sh)
        k_hip = self.spec["k_hip"] * smoothstep(sk["HJ"] - 0.60, sk["HJ"] - 0.10, z)
        return smin(d, np.minimum(GL, GR), k_hip)


def coach_axes(spec):
    """Each part's bone axis on the spec's own skeleton (body 05's axes() on L)."""
    sk = spec.get("skel", L)
    ax = spec["arm_x"]
    torso = [(0, 0.0, sk["HJ"] + 0.05), (0, 0.0, sk["N"] - 0.10)]
    armL = [(ax, 0, sk["SH"]), (ax, 0, sk["E"]), (ax, 0, sk["WR"] + 0.05)]
    legL = [(0.5, 0, sk["HJ"]), (0.5, 0, sk["K"]), (0.5, 0, sk["A"] + 0.10)]
    flip = lambda pts: [(-x, y, z) for x, y, z in pts]
    return [np.array(p, dtype=np.float32) for p in (torso, armL, flip(armL), legL, flip(legL))]


B["axes"] = coach_axes          # reshape() looks it up by name


def place_hand(hand_mesh, side, spec, name, coll):
    sk = spec["skel"]
    me = hand_mesh.copy()
    me.name = name
    sx = 1 if side == "Left" else -1
    from mathutils import Matrix
    me.transform(Matrix.Translation(Vector((sx * spec["arm_x"], 0, sk["WR"]))) @ B["hand_space"](side, spec["hand"]))
    if sx < 0:
        me.flip_normals()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.clear()
    me.materials.append(B["skin_material"]())
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    return o


def stand_in_head(name, skel, x, coll):
    return B["P4"]["stand_in_head"](name, skel, x, coll)


def load_from_bodies05(names):
    with bpy.data.libraries.load(BODIES05, link=False) as (src, dst):
        dst.objects = [n for n in names if n in src.objects]
    return {o.name: o for o in dst.objects if o is not None}


# ------------------------------------------------------------------------------------------- pictures
def pictures(row):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light, sh.color_type, sh.show_backface_culling, sh.show_cavity = "STUDIO", "MATERIAL", True, True
    sh.cavity_type = "WORLD"
    sh.cavity_ridge_factor, sh.cavity_valley_factor = 0.6, 1.0
    if sc.world is None:
        sc.world = bpy.data.worlds.new("W")
    sc.world.color = (0.16, 0.17, 0.2)
    cd = bpy.data.cameras.new("CoachCam")
    cd.type = "ORTHO"
    cam = bpy.data.objects.new("CoachCam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam

    def shoot(name, direction, scale, res, target):
        cd.ortho_scale = scale
        sc.render.resolution_x, sc.render.resolution_y = res
        cam.location = Vector(target) + Vector(direction).normalized() * 40
        cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(PREVIEWS, "CoachBodies01_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        log("shot", sc.render.filepath)

    labels = []
    for key, (objs, x) in row.items():
        cu = bpy.data.curves.new("Label_" + key, "FONT")
        cu.body = LABEL[key]
        cu.align_x = "CENTER"
        cu.size = 0.34
        o = bpy.data.objects.new("Label_" + key, cu)
        sc.collection.objects.link(o)
        o.location = (x, -1.6, -0.35)
        o.rotation_euler = (math.radians(90), 0, 0)
        labels.append(o)
    mid = Vector(((len(row) - 1) * SPACING / 2, 0, 2.7))
    for view, d in {"Front": (0, -1, 0.04), "Back": (0, 1, 0.04), "Threequarter": (-0.8, -1, 0.18)}.items():
        for lab in labels:
            lab.hide_render = view == "Back"
        shoot(view, d, 19.5, (2200, 1000), mid)
    for lab in labels:
        lab.hide_render = True
    # side: every figure turned to show its left side, same row
    for key, (objs, x) in row.items():
        for o in objs:
            o.rotation_euler = (0, 0, math.radians(90))
            o.location.x = x
    shoot("Side", (0, -1, 0.04), 19.5, (2200, 1000), mid)
    for key, (objs, x) in row.items():
        for o in objs:
            o.rotation_euler = (0, 0, 0)


# ------------------------------------------------------------------------------------------- main
if globals().get("COACH01_AS_LIBRARY") is not True:
    import time as _t
    B["_T0"] = _t.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    HANDS = B["load_hands"]()
    main = B["new_collection"]("CoachBodies01")
    preview = B["new_collection"]("Preview")
    got = load_from_bodies05(["Base05_Fit", "Body05_Fit", "Body05_Fit_LeftHand", "Body05_Fit_RightHand"])
    base = got["Base05_Fit"]
    preview.objects.link(base)
    base.hide_render = base.hide_viewport = True
    base.location = (0, 0, 0)
    fit_spec = B["body_spec"]("Fit")
    fit_spec["skel"] = L
    fit_field = CoachField(fit_spec)
    me_b = base.data
    base_co = np.array([v.co for v in me_b.vertices], dtype=np.float32)
    mirror, worst = B["mirror_map"](base_co)
    log("base", len(base_co), "points, mirror worst %.5f" % worst)
    nb = B["neighbour_table"](me_b)
    open_hand = HANDS["make_hand"]("Open", preview)
    row = {}
    # the Fit lifter for scale, at the left
    fit_objs = [got[n] for n in ("Body05_Fit", "Body05_Fit_LeftHand", "Body05_Fit_RightHand") if n in got]
    for o in fit_objs:
        preview.objects.link(o)
        o.location = (0, 0, 0)
    fit_objs.append(stand_in_head("Fit_Head", L, 0.0, preview))
    row["Fit"] = (fit_objs, 0.0)
    report = {}
    for i, c in enumerate(ORDER):
        spec = tone(COACHES[c]())
        field = CoachField(spec)
        X = B["reshape"](base_co, None, nb, fit_field, field, fit_spec, spec, mirror)
        me = me_b.copy()
        me.name = "CoachBody01_" + c
        me.vertices.foreach_set("co", X.astype(np.float32).ravel())
        me.update()
        obj = bpy.data.objects.new("CoachBody01_" + c, me)
        main.objects.link(obj)
        unfolded = B["unfold"](obj)
        for p in me.polygons:
            p.use_smooth = True
        me.materials.clear()
        me.materials.append(B["skin_material"]())
        q = B["quality"](obj, base, field)
        hands = [place_hand(open_hand.data, s, spec, "CoachBody01_%s_%sHand" % (c, s), main) for s in ("Left", "Right")]
        x = (i + 1) * SPACING
        for o in [obj] + hands:
            o.location.x = x
        head = stand_in_head("CoachBody01_%s_Head" % c, spec["skel"], x, preview)
        row[c] = ([obj] + hands + [head], x)
        zs = X[:, 2]
        q.update(tris=B["triangles"](obj), unfolded=unfolded, height=round(float(zs.max()) + 1.2, 2),
                 width=round(float(X[:, 0].max() - X[:, 0].min()), 2), skeleton={k: round(v, 3) for k, v in spec["skel"].items()})
        report[c] = q
        log(c, q)
    bpy.data.objects.remove(open_hand, do_unlink=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    log("saved", OUT_BLEND)
    pictures(row)
    for c, q in report.items():
        print("[Coach01]", c, q, flush=True)
