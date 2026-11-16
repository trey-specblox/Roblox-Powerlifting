# Cartoon lifter bodies, PRODUCTION 05 (CHARACTER_ART_DIRECTION.md §11 Phase 2). Six bodies on ONE shared base mesh
# (user's pick 2026-11-13: same vertex count and order on every build, each build a reshaped copy), on the TORSO_TALL
# skeleton (approved 2026-11-13: hips/HipHeight 2.0, waist 2.54, shoulder 4.38, neck 4.70; arms x1.5: elbow 3.287, wrist 2.148;
# longer thighs: knee 1.00).
#
# The six (§5.4, two axes: muscle from PP, fat from bodyweight):
#               Lean        Soft             Heavy
#   Low         Skinny      SkinnyFat        Fat
#   Mid         Fit         (BigBuff small)  (Fat)
#   High        Muscular    BigBuff          (BigBuff)
# Object names use one word per build (the gear tools split names on "_"): Skinny, SkinnyFat, Fat, Fit, Muscular,
# BigBuff ("Skinny-fat" and "Big and buff" in the docs).
#
# How (the approved prototype method, build_cartoon_body_04.py, then one topology for all):
#   1. Each build is ONE smooth distance field (forms melted together, definition carved in as shallow grooves), the
#      prototype's shapes. Skinny, Fat (the prototype's "Heavy") and Muscular keep the prototype's look; SkinnyFat,
#      Fit and BigBuff are new in the same language.
#   2. The BASE MESH is the Fit field meshed with OpenVDB and remeshed into even, mirror-symmetric quads (QuadriFlow).
#   3. Every build (Fit included) is that base mesh reshaped onto its own field: each point is carried along with its
#      body part (torso, each arm, each leg) by rays from that part's bone axis (same crossing, scaled by how much
#      further out the new build's surface is), blended across the joins, snapped onto the surface, then evened out
#      along the surface (points slide, never leave the surface). Same points, same order, same faces on all six.
# Grooves are wider and shallower than the prototype's (the even mesh is coarser than the prototype's 4,800 thinned
# triangles in the grooves), so they read at game distance instead of flickering.
#
# Run headless:  blender -b --python art/scripts/build_cartoon_body_05.py
# Writes art/blender/CartoonBodies_05.blend: "Bodies05" (Body05_<Build> + its open hands Body05_<Build>_<Side>Hand),
# "Preview" (stand-in 1.2-stud heads: the player's own head in the game). build_cartoon_rig_05.py rigs them.
import math
import os
import tempfile

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
OUT_BLEND = os.path.join(ROOT, "art", "blender", "CartoonBodies_05.blend")
VOXEL = 0.016             # studs: sampling of the base field
BASE_QUADS = 2165         # QuadriFlow lands a little under its target (arms x1.5: ~2,090 quads = ~4,200 tris)
SPACING = 4.6
SKIN = (0.95, 0.76, 0.60, 1)

# The prototype's field tools (ellipsoid, round cone, smooth union, carve, the skeleton tables). Read-only use.
P4 = {"__name__": "body04_lib", "PROTO04_AS_LIBRARY": True}
exec(open(os.path.join(SCRIPTS, "build_cartoon_body_04.py")).read(), P4)
TALLER = P4["TALLER"]
# S: the heights the six builds' shapes are WRITTEN on (TORSO_TALL with the arms x1.2: elbow 3.51, wrist 2.59).
# L: the skeleton the bodies are BUILT on. Arms x1.5 of the block arm, approved 2026-11-13 (Phase 1 session: with
# arms x1.2 the hands hang above the hip joint and no correct deadlift set-up exists; user picked "1. Arms x1.5"):
# elbow 3.287, wrist 2.148 (shoulder 4.38 minus 0.7284 x1.5 and 0.7596 x1.5), the hand's centre at about hip height.
# Legs, torso, shoulder and hands unchanged. body_spec() stretches the arm shapes from S onto L (arm_z below), so the
# muscles grow with the bones instead of sitting at the old elbow. build_cartoon_body_04.py is left as it was.
# LONGER THIGHS, approved 2026-11-15 (user: "Can we make the legs, a little longer. so there is a gap between the
# singlet, and the knee sleeves?", then picked "Knee 1.00" from a mock-up): the knee 1.178 -> 1.00 with the hips kept at
# 2.0 (HipHeight, station heights and the arms x1.5 deadlift fix unchanged): thigh 0.822 -> 1.00, shin 0.926 -> 0.748
# (real legs: the thigh longer than the shin). body_spec() stretches the leg shapes the same way (leg_z below).
S = P4["TORSO_TALL"]
L = dict(S, E=3.287, WR=2.148, K=1.00)
E, C, BX, family, smin, smoothstep, lerp = (P4[k] for k in ("E", "C", "BX", "family", "smin", "smoothstep", "lerp"))
# The prototype wrote its shapes on the taller-leg heights and stretched the torso shapes' heights by this factor for
# the torso-tall bodies (the approved look); the same stretch is kept.
TZ = (L["N"] - L["HJ"]) / (TALLER["N"] - TALLER["HJ"])


def common_feet(wide=1.0):
    return P4["common_feet"](S, wide)


def J():
    return tuple(S[k] for k in ("A", "K", "HJ", "W", "N", "SH", "E", "WR"))


def arm_z(z):
    """A height on the written arm (S) -> the same place on the built arm (L), and that segment's stretch factor.
    Upper arm: shoulder..elbow, lower arm: elbow..wrist and below; above the shoulder nothing moves."""
    sh = S["SH"]
    if z >= sh:
        return z, 1.0
    if z >= S["E"]:
        k = (sh - L["E"]) / (sh - S["E"])
        return sh + (z - sh) * k, k
    k = (L["E"] - L["WR"]) / (S["E"] - S["WR"])
    return L["E"] + (z - S["E"]) * k, k


def leg_z(z):
    """The same for the legs: thigh hip..knee, shin knee..ankle; above the hips and below the ankle (the feet) nothing
    moves."""
    hj, a = S["HJ"], S["A"]
    if z >= hj or z <= a:
        return z, 1.0
    if z >= S["K"]:
        k = (hj - L["K"]) / (hj - S["K"])
        return hj + (z - hj) * k, k
    k = (L["K"] - a) / (S["K"] - a)
    return a + (z - a) * k, k


def along(shapes, zmap):
    """Shapes moved along a limb by zmap (cone ends moved; ellipsoids and boxes moved and lengthened with their
    segment, same thickness)."""
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


# ----------------------------------------------------------------------------------------------- the six builds
# Coordinates: studs, x = the character's left, -y = front, z = up. arm_x: where the arm hangs; pivot_x: the R15
# shoulder joint (inside the shoulder); hand: the hand's size (hand width ~0.9-1.0x the forearm's widest, §4).
# Each body is designed as a silhouette first (front width, side depth), then muscle.

def skinny():
    """Low muscle, lean (the prototype's Skinny, unchanged)."""
    A, K, HJ, W, N, SH, E_, WR = J()
    spec = P4["skinny"](S)
    spec.update(name="Skinny", hand=1.05)
    return spec


def skinny_fat():
    """Low muscle, soft: the skinny frame with a soft low belly and love handles, soft upper arms and hips, a flat
    chest (a separate soft chest shape read as breasts: the smooth union adds volume). No definition anywhere."""
    A, K, HJ, W, N, SH, E_, WR = J()
    CZ = lerp(W, N, 0.62)
    arm_x = 1.12
    torso = [
        E((0, 0.03, CZ), (0.74, 0.46, 0.78), mirror=False),                                  # rib cage, a bit wider
        E((0, -0.12, W + 0.20), (0.68, 0.54, 0.54), blend=0.34, mirror=False),              # soft belly, low, forward
        E((0.50, 0.10, W + 0.10), (0.28, 0.32, 0.30), blend=0.26),                          # small love handles
        E((0, 0.04, HJ + 0.12), (0.62, 0.40, 0.36), blend=0.28, mirror=False),              # wider soft pelvis
        E((0, 0.04, N + 0.03), (0.44, 0.38, 0.22), blend=0.22, mirror=False),               # under the head (no ledge)
        C((0.32, 0.06, N + 0.08), (0.90, 0.03, SH + 0.01), 0.19, 0.17, blend=0.18),         # trap slope, small, soft
        E((0.92, 0.0, SH - 0.08), (0.24, 0.26, 0.26), blend=0.16),                          # small soft shoulder cap
        E((0.30, 0.24, HJ - 0.02), (0.31, 0.25, 0.31), blend=0.22),                         # soft glutes, one mass
    ]
    arm = [C((arm_x, 0, SH - 0.03), (arm_x, 0, E_ + 0.05), 0.225, 0.18),
           C((arm_x, 0, E_ - 0.05), (arm_x, 0, WR + 0.05), 0.185, 0.14, blend=0.08),
           E((arm_x, 0.05, E_ + 0.36), (0.20, 0.21, 0.30), blend=0.12)]                      # soft upper-arm hang
    leg = [C((0.5, 0.0, HJ + 0.05), (0.5, 0.0, K + 0.08), 0.36, 0.23),
           C((0.5, 0.0, K - 0.02), (0.5, 0.0, A + 0.10), 0.215, 0.14, blend=0.08),
           E((0.5, 0.08, K - 0.34), (0.20, 0.18, 0.30), blend=0.10)] + common_feet(1.03)
    return dict(name="SkinnyFat", torso=torso, arm=arm, leg=leg, arm_x=arm_x, pivot_x=0.86, hand=1.12,
                k_shoulder=0.18, k_hip=0.18)


def fat():
    """Low muscle, heavy (the prototype's Heavy, unchanged): round soft upper body, low forward belly with love
    handles, round collar to the head, soft low chest, wide soft glutes."""
    spec = P4["heavy"](S)
    spec.update(name="Fat", hand=1.30)
    return spec


def fit():
    """Mid muscle, lean (the base mesh; "average" at its smallest step): an athletic V, round delts, flat pecs with a
    soft lower edge, faint abs (centre line and one cross line), lats from the armpit, a light trap slope."""
    A, K, HJ, W, N, SH, E_, WR = J()
    CZ = lerp(W, N, 0.61)
    arm_x = 1.28
    torso = [
        E((0, 0.03, CZ + 0.03), (0.78, 0.48, 0.79), mirror=False),                           # rib cage
        E((0, -0.01, W + 0.22), (0.58, 0.40, 0.55), blend=0.28, mirror=False),              # abdomen, narrow waist
        E((0, 0.04, HJ + 0.11), (0.62, 0.40, 0.35), blend=0.24, mirror=False),              # pelvis
        E((0.46, -0.04, W + 0.28), (0.15, 0.27, 0.32), blend=0.22),                         # obliques
        C((0.80, 0.12, CZ + 0.06), (0.52, 0.13, W + 0.30), 0.21, 0.13, blend=0.24),         # lats: armpit to waist
        E((0, 0.33, N - 0.42), (0.48, 0.20, 0.56), blend=0.22, mirror=False),               # upper back
        E((0, 0.05, N + 0.04), (0.45, 0.38, 0.24), blend=0.22, mirror=False),               # under the head
        C((0.29, 0.08, N + 0.18), (0.93, 0.04, SH + 0.03), 0.19, 0.22, blend=0.19),         # trap slope, moderate
        E((1.08, 0.0, SH - 0.07), (0.33, 0.36, 0.38), blend=0.17),                          # round delt over the arm
        E((0.38, -0.28, CZ + 0.02), (0.47, 0.18, 0.28), blend=0.22, rot=(6, -12, 0)),      # pec slab
        C((0.12, -0.38, CZ + 0.28), (0.86, -0.20, SH - 0.12), 0.11, 0.15, blend=0.20),      # upper pec into the delt
        E((0.31, 0.24, HJ - 0.03), (0.32, 0.27, 0.33), blend=0.17),                         # glutes
        E((0.14, 0.33, W + 0.32), (0.11, 0.09, 0.46), blend=0.12),                          # erectors (spine groove)
        # Faint definition, wide and shallow (reads on the even mesh):
        C((0, -0.62, CZ + 0.26), (0, -0.60, CZ - 0.22), 0.055, 0.055, blend=0.07, op="carve", mirror=False),  # sternum
        C((0.08, -0.60, CZ - 0.27), (0.56, -0.50, CZ - 0.17), 0.055, 0.04, blend=0.08, op="carve"),        # pec edge
        C((0, -0.48, W + 0.60), (0, -0.46, W - 0.02), 0.045, 0.04, blend=0.07, op="carve", mirror=False),    # linea alba
        C((-0.26, -0.45, W + 0.40), (0.26, -0.45, W + 0.40), 0.038, 0.038, blend=0.07, op="carve", mirror=False),
    ]
    arm = [C((arm_x, 0, SH - 0.06), (arm_x, 0, E_ + 0.06), 0.27, 0.215, blend=0.10),
           E((arm_x - 0.02, -0.11, E_ + 0.36), (0.21, 0.19, 0.30), blend=0.10),               # biceps
           E((arm_x + 0.02, 0.11, E_ + 0.44), (0.22, 0.20, 0.36), blend=0.10),               # triceps
           C((arm_x, 0, E_ - 0.08), (arm_x, 0, WR + 0.06), 0.24, 0.165, blend=0.08),          # forearm
           E((arm_x + 0.03, -0.05, E_ - 0.22), (0.20, 0.19, 0.27), blend=0.10)]
    leg = [C((0.51, -0.01, HJ + 0.05), (0.5, 0.0, K + 0.10), 0.40, 0.26),
           E((0.70, -0.05, lerp(K, HJ, 0.55)), (0.18, 0.26, 0.46), blend=0.16),             # outer quad sweep
           E((0.54, 0.19, lerp(K, HJ, 0.55)), (0.23, 0.21, 0.45), blend=0.18),              # hamstrings
           C((0.5, 0.01, K - 0.03), (0.5, 0.0, A + 0.10), 0.23, 0.145, blend=0.08),
           E((0.5, 0.11, K - 0.35), (0.23, 0.20, 0.33), blend=0.11)] + common_feet(1.03)    # calf
    return dict(name="Fit", torso=torso, arm=arm, leg=leg, arm_x=arm_x, pivot_x=0.92, hand=1.22,
                k_shoulder=0.18, k_hip=0.17)


def muscular():
    """High muscle, lean (the prototype's Muscular): the same masses; its grooves made wider and shallower for the
    even mesh, the delt/pec line moved off the armpit (the prototype's dark notch, §10.1 issue 3)."""
    A, K, HJ, W, N, SH, E_, WR = J()
    CZ = lerp(W, N, 0.60)
    spec = P4["muscular"](S)
    torso = [s for s in spec["torso"] if s[3] == "add"]
    torso += [
        C((0, -0.64, CZ + 0.30), (0, -0.61, CZ - 0.28), 0.06, 0.06, blend=0.07, op="carve", mirror=False),   # sternum
        C((0.10, -0.62, CZ - 0.33), (0.62, -0.52, CZ - 0.22), 0.06, 0.045, blend=0.08, op="carve"),         # pec edge
        C((0, -0.49, W + 0.68), (0, -0.47, W - 0.06), 0.05, 0.045, blend=0.06, op="carve", mirror=False),    # linea alba
        C((-0.30, -0.45, W + 0.56), (0.30, -0.45, W + 0.56), 0.042, 0.042, blend=0.06, op="carve", mirror=False),
        C((-0.29, -0.46, W + 0.32), (0.29, -0.46, W + 0.32), 0.042, 0.042, blend=0.06, op="carve", mirror=False),
        C((-0.27, -0.46, W + 0.08), (0.27, -0.46, W + 0.08), 0.040, 0.040, blend=0.06, op="carve", mirror=False),
        C((0.10, 0.52, HJ - 0.40), (0.62, 0.42, HJ - 0.34), 0.05, 0.05, blend=0.07, op="carve"),            # glute fold
        C((0.90, -0.46, SH - 0.16), (1.00, -0.44, CZ - 0.12), 0.045, 0.045, blend=0.06, op="carve"),        # delt/pec line
    ]
    spec.update(name="Muscular", torso=torso, hand=1.50)
    return spec


def big_buff():
    """High muscle, soft: the super-heavy powerlifter. Widest build: huge traps up the head's sides, a thick deep
    chest, big round delts, a thick firm waist pushed forward (no V-taper, no ab lines), thick arms and legs."""
    A, K, HJ, W, N, SH, E_, WR = J()
    CZ = lerp(W, N, 0.60)
    arm_x = 1.66
    torso = [
        E((0, 0.04, CZ + 0.04), (0.98, 0.62, 0.82), mirror=False),                           # big deep rib cage
        E((0, -0.10, W + 0.38), (0.92, 0.62, 0.64), blend=0.34, mirror=False),              # thick firm waist, high
        E((0.66, 0.08, W + 0.22), (0.36, 0.40, 0.42), blend=0.30),                          # thick obliques / handles
        E((0, 0.08, HJ + 0.11), (0.86, 0.50, 0.40), blend=0.34, mirror=False),              # wide pelvis
        C((0.94, 0.18, CZ + 0.06), (0.68, 0.18, W + 0.32), 0.30, 0.20, blend=0.26),         # lats
        E((0, 0.42, N - 0.40), (0.66, 0.28, 0.66), blend=0.24, mirror=False),               # big upper back
        E((0, 0.08, N + 0.08), (0.60, 0.48, 0.30), blend=0.24, mirror=False),               # under the head
        C((0.30, 0.12, N + 0.36), (1.12, 0.08, SH + 0.06), 0.25, 0.31, blend=0.22),         # traps up the head's sides
        E((1.42, 0.0, SH - 0.10), (0.47, 0.50, 0.52), blend=0.20),                          # big round delt
        E((0.46, -0.40, CZ + 0.0), (0.60, 0.26, 0.36), blend=0.24, rot=(8, -12, 0)),       # thick pec slab
        C((0.14, -0.50, CZ + 0.30), (1.04, -0.28, SH - 0.12), 0.15, 0.19, blend=0.22),      # upper pec into the delt
        E((0.40, 0.31, HJ - 0.02), (0.44, 0.34, 0.40), blend=0.20),                         # big glutes
        E((0.17, 0.44, W + 0.36), (0.14, 0.12, 0.52), blend=0.14),                          # erectors
        # Only big soft grooves on a soft build: the spine groove and the pec's lower edge.
        C((0.10, -0.74, CZ - 0.34), (0.70, -0.60, CZ - 0.24), 0.07, 0.05, blend=0.10, op="carve"),          # pec edge
    ]
    arm = [C((arm_x, 0, SH - 0.10), (arm_x, 0, E_ + 0.08), 0.36, 0.29, blend=0.10),
           E((arm_x - 0.02, -0.16, E_ + 0.38), (0.29, 0.27, 0.36), blend=0.12),               # biceps
           E((arm_x + 0.02, 0.16, E_ + 0.46), (0.30, 0.27, 0.44), blend=0.12),               # triceps
           C((arm_x, 0, E_ - 0.10), (arm_x, 0, WR + 0.07), 0.32, 0.20, blend=0.08),           # thick forearm
           E((arm_x + 0.04, -0.06, E_ - 0.24), (0.27, 0.26, 0.31), blend=0.10)]
    leg = [C((0.56, -0.02, HJ + 0.03), (0.5, 0.0, K + 0.12), 0.50, 0.32),
           E((0.82, -0.06, lerp(K, HJ, 0.55)), (0.22, 0.32, 0.52), blend=0.18),             # outer quad sweep
           E((0.58, 0.24, lerp(K, HJ, 0.55)), (0.29, 0.26, 0.50), blend=0.18),              # hamstrings
           C((0.5, 0.02, K - 0.04), (0.5, 0.0, A + 0.10), 0.28, 0.18, blend=0.08),
           E((0.5, 0.15, K - 0.36), (0.29, 0.25, 0.37), blend=0.12)] + common_feet(1.16)    # calf diamond
    return dict(name="BigBuff", torso=torso, arm=arm, leg=leg, arm_x=arm_x, pivot_x=1.05, hand=1.58,
                k_shoulder=0.24, k_hip=0.22)


BUILDS = {"Skinny": skinny, "SkinnyFat": skinny_fat, "Fat": fat, "Fit": fit, "Muscular": muscular,
          "BigBuff": big_buff}
ORDER = ("Skinny", "SkinnyFat", "Fat", "Fit", "Muscular", "BigBuff")
BASE = "Fit"


def body_spec(build):
    """The build's shapes on the torso-tall heights, the torso shapes' heights stretched (the approved look). This is
    the one entry point for other scripts (the rig, the gear fitter's smoothed body)."""
    spec = BUILDS[build]()
    out = []
    for kind, args, blend, op, mirror in spec["torso"]:
        if kind == "ellipsoid":
            c, r, rot = args
            args = (c, (r[0], r[1], r[2] * TZ), rot)
        elif kind == "box":
            c, h, rad, rot = args
            args = (c, (h[0], h[1], h[2] * TZ), rad, rot)
        out.append((kind, args, blend, op, mirror))
    spec["torso"] = out
    # The arm and leg shapes from the written limbs (S) onto the built ones (L): a longer arm or thigh, not a fatter one.
    spec["arm"] = along(spec["arm"], arm_z)
    spec["leg"] = along(spec["leg"], leg_z)
    return spec


# ----------------------------------------------------------------------------------------------- fields
class Field:
    """One build's distance field and its parts (torso, each arm, each leg), the joins as in the prototype."""

    def __init__(self, spec):
        self.spec = spec

    def parts(self, P):
        s = self.spec
        return (family(P, s["torso"]), family(P, s["arm"], 1), family(P, s["arm"], -1),
                family(P, s["leg"], 1), family(P, s["leg"], -1))

    def join(self, T, AL, AR, GL, GR, P):
        z, ax = P[:, 2], np.abs(P[:, 0])
        k_sh = self.spec["k_shoulder"] * smoothstep(L["SH"] - 0.80, L["SH"] - 0.25, z) * smoothstep(0.5, 0.8, ax)
        d = smin(T, np.minimum(AL, AR), k_sh)
        k_hip = self.spec["k_hip"] * smoothstep(L["HJ"] - 0.60, L["HJ"] - 0.10, z)
        return smin(d, np.minimum(GL, GR), k_hip)

    def __call__(self, P):
        P = np.asarray(P, dtype=np.float32)
        out = np.empty(len(P), dtype=np.float32)
        for i in range(0, len(P), 200000):
            Q = P[i:i + 200000]
            out[i:i + 200000] = self.join(*self.parts(Q), Q)
        return out

    def grad(self, P, eps=0.003):
        g = np.zeros_like(P)
        for a in range(3):
            d = np.zeros(3, dtype=np.float32)
            d[a] = eps
            g[:, a] = (self(P + d) - self(P - d)) / (2 * eps)
        return g

    def part(self, which, P):
        """One part's own field: 0 torso, 1 left arm, 2 right arm, 3 left leg, 4 right leg."""
        s = self.spec
        if which == 0:
            return family(P, s["torso"])
        if which in (1, 2):
            return family(P, s["arm"], 1 if which == 1 else -1)
        return family(P, s["leg"], 1 if which == 3 else -1)


def field_to_mesh(name, fn, lo, hi, voxel):
    """Meshes the field's zero surface with OpenVDB (Blender's Volume to Mesh)."""
    import openvdb as vdb
    lo, hi = np.asarray(lo), np.asarray(hi)
    i0 = np.floor(lo / voxel).astype(int)
    n = (np.ceil(hi / voxel).astype(int) - i0) + 1
    xs, ys, zs = [(i0[a] + np.arange(n[a])) * voxel for a in range(3)]
    density = np.empty(tuple(n), dtype=np.float32)
    for k in range(0, n[2], 24):
        kk = slice(k, min(k + 24, n[2]))
        X, Y, Zs = np.meshgrid(xs, ys, zs[kk], indexing="ij")
        P = np.stack([X.ravel(), Y.ravel(), Zs.ravel()], axis=1).astype(np.float32)
        density[:, :, kk] = np.clip(-fn(P), -0.1, 0.1).reshape(X.shape)
    grid = vdb.FloatGrid(-0.1)
    grid.copyFromArray(density, ijk=tuple(int(v) for v in i0), tolerance=0.0)
    grid.transform = vdb.createLinearTransform(voxelSize=voxel)
    grid.name = "density"
    path = os.path.join(tempfile.gettempdir(), "body05_%s.vdb" % name)
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
        os.remove(path)                   # (the field file is only needed while meshing)
    except OSError:
        pass
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


import time as _time
_T0 = _time.time()


def log(*a):
    print("[Body05] %6.1fs" % (_time.time() - _T0), *a, flush=True)


# ----------------------------------------------------------------------------------------------- the base mesh
def make_base(field):
    """The Fit field -> even, mirror-symmetric quads; returns the base object (checked closed and in one piece)."""
    hi_obj = field_to_mesh("Base05_Dense", field, (-2.6, -1.5, -0.10), (2.6, 1.4, L["N"] + 0.80), VOXEL)
    bpy.context.view_layer.objects.active = hi_obj
    bpy.ops.object.select_all(action="DESELECT")
    hi_obj.select_set(True)
    log("dense base mesh:", len(hi_obj.data.polygons), "faces")
    dec = hi_obj.modifiers.new("Fewer", "DECIMATE")          # QuadriFlow is slow on the dense field mesh
    dec.ratio = min(1.0, 60000 / max(1, len(hi_obj.data.polygons)))
    bpy.ops.object.modifier_apply(modifier=dec.name)
    hi_obj.data.use_mirror_x = True
    r = bpy.ops.object.quadriflow_remesh(target_faces=BASE_QUADS, use_mesh_symmetry=True, use_preserve_sharp=False,
                                         use_preserve_boundary=False, smooth_normals=False, seed=7)
    log("QuadriFlow:", r)
    bm = bmesh.new()
    bm.from_mesh(hi_obj.data)
    # the centre seam of the mirrored halves: open edges near x = 0 snapped onto it and joined
    seam = {v for e in bm.edges if len(e.link_faces) == 1 for v in e.verts if abs(v.co.x) < 0.03}
    for v in bm.verts:
        if abs(v.co.x) < 1e-3:
            seam.add(v)
    for v in seam:
        v.co.x = 0.0
    bmesh.ops.remove_doubles(bm, verts=list(seam), dist=0.02)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(hi_obj.data)
    bm.free()
    hi_obj.name = hi_obj.data.name = "Base05"
    check_closed(hi_obj)
    return hi_obj


def check_closed(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    open_edges = sum(1 for e in bm.edges if len(e.link_faces) != 2)
    sizes = {}
    for f in bm.faces:
        sizes[len(f.verts)] = sizes.get(len(f.verts), 0) + 1
    euler = len(bm.verts) - len(bm.edges) + len(bm.faces)
    bm.free()
    log(obj.name, "verts", len(obj.data.vertices), "faces", sizes, "open edges", open_edges, "euler", euler)
    assert open_edges == 0, "base mesh is not closed"
    assert euler == 2, "base mesh is not one closed piece without holes (euler %d)" % euler


def mirror_map(co):
    """For each point, its mirror twin across x = 0 (itself on the centre line)."""
    kd = KDTree(len(co))
    for i, c in enumerate(co):
        kd.insert(c, i)
    kd.balance()
    out = np.empty(len(co), dtype=np.int64)
    worst = 0.0
    for i, c in enumerate(co):
        _p, j, d = kd.find((-c[0], c[1], c[2]))
        out[i] = j
        worst = max(worst, d)
    return out, worst


# ----------------------------------------------------------------------------------------------- reshaping
def axes(spec):
    """Each part's bone axis as a polyline (shared joint heights; the arms hang at the build's own arm_x)."""
    ax = spec["arm_x"]
    torso = [(0, 0.0, L["HJ"] + 0.05), (0, 0.0, L["N"] - 0.10)]
    armL = [(ax, 0, L["SH"]), (ax, 0, L["E"]), (ax, 0, L["WR"] + 0.05)]
    legL = [(0.5, 0, L["HJ"]), (0.5, 0, L["K"]), (0.5, 0, L["A"] + 0.10)]
    flip = lambda pts: [(-x, y, z) for x, y, z in pts]
    return [np.array(p, dtype=np.float32) for p in (torso, armL, flip(armL), legL, flip(legL))]


def closest_on_polyline(X, pts):
    """For each point: (segment index, parameter 0..1) of the closest point on the polyline."""
    best_d = np.full(len(X), np.inf)
    seg = np.zeros(len(X), dtype=np.int64)
    par = np.zeros(len(X), dtype=np.float32)
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        ab = b - a
        t = np.clip(((X - a) @ ab) / float(ab @ ab), 0.0, 1.0)
        q = a + t[:, None] * ab
        d = np.linalg.norm(X - q, axis=1)
        better = d < best_d
        best_d[better], seg[better], par[better] = d[better], i, t[better]
    return seg, par


def at_polyline(pts, seg, par):
    return pts[seg] + par[:, None] * (pts[seg + 1] - pts[seg])


def exits(fn, origins, dirs, far=2.6, step=0.012):
    """Every place each ray leaves the solid (inside -> outside), as an array (n, k) padded with nan."""
    ts = np.arange(0.0, far, step, dtype=np.float32)
    n = len(origins)
    vals = np.empty((n, len(ts)), dtype=np.float32)
    for j, t in enumerate(ts):
        vals[:, j] = fn(origins + dirs * t)
    leave = (vals[:, :-1] < 0) & (vals[:, 1:] >= 0)
    k = max(1, int(leave.sum(axis=1).max()))
    out = np.full((n, k), np.nan, dtype=np.float32)
    for i in range(n):
        idx = np.nonzero(leave[i])[0]
        for m, j in enumerate(idx[:k]):
            a, b = vals[i, j], vals[i, j + 1]
            out[i, m] = ts[j] + step * (a / (a - b))          # linear refine inside the step
    return out


def reshape(base_co, faces_idx, neighbours, base_field, target_field, base_spec, target_spec, mirror):
    """The base points carried onto the target build's surface (see the header)."""
    X = base_co.astype(np.float32)
    n = len(X)
    # how much each point belongs to each part (soft, from the base's own part fields)
    parts_b = np.stack([base_field.part(i, X) for i in range(5)], axis=1)
    w = np.exp(-(parts_b - parts_b.min(axis=1, keepdims=True)) / 0.035)
    w /= w.sum(axis=1, keepdims=True)
    ax_b, ax_t = axes(base_spec), axes(target_spec)
    out = np.zeros_like(X)
    for r in range(5):
        sel = np.nonzero(w[:, r] > 1e-3)[0]
        if not len(sel):
            continue
        Xs = X[sel]
        seg, par = closest_on_polyline(Xs, ax_b[r])
        a_b = at_polyline(ax_b[r], seg, par)
        a_t = at_polyline(ax_t[r], seg, par)
        d = Xs - a_b
        rho = np.linalg.norm(d, axis=1)
        d = d / np.maximum(rho, 1e-6)[:, None]
        fb = lambda P, r=r: base_field.part(r, P)
        ft = lambda P, r=r: target_field.part(r, P)
        eb, et = exits(fb, a_b, d), exits(ft, a_t, d)
        new = np.empty_like(Xs)
        for i in range(len(sel)):
            row_b = eb[i][~np.isnan(eb[i])]
            row_t = et[i][~np.isnan(et[i])]
            if len(row_b) and len(row_t):
                k = int(np.argmin(np.abs(row_b - rho[i])))
                k_t = min(k, len(row_t) - 1)
                new[i] = a_t[i] + d[i] * rho[i] * (row_t[k_t] / max(row_b[k], 1e-4))
            else:
                new[i] = Xs[i] + (a_t[i] - a_b[i])
        out[sel] += w[sel, r][:, None] * new
    X = out
    X = project(X, target_field, 10)
    X = symmetrize(X, mirror)
    # even the points out along the surface (they slide; the surface stays)
    for _ in range(12):
        X = relax(X, neighbours, target_field, 0.45)
        X = project(X, target_field, 3)
        X = symmetrize(X, mirror)
    return X


def project(X, field, rounds):
    for _ in range(rounds):
        f = field(X)
        g = field.grad(X)
        g2 = np.maximum((g * g).sum(axis=1), 1e-6)
        step = np.clip(f / g2, -0.12, 0.12)
        X = X - step[:, None] * g
    return X


def relax(X, neighbours, field, lam):
    """One round of even spacing: each point moves toward the middle of its neighbours, only along the surface."""
    idx, cnt = neighbours
    mean = np.add.reduceat(X[idx[:, 1]], np.r_[0, np.cumsum(cnt)[:-1]], axis=0) / cnt[:, None]
    move = mean - X
    g = field.grad(X)
    nrm = g / np.maximum(np.linalg.norm(g, axis=1, keepdims=True), 1e-6)
    move -= (move * nrm).sum(axis=1, keepdims=True) * nrm
    return X + lam * move


def symmetrize(X, mirror):
    Y = X[mirror].copy()
    Y[:, 0] *= -1
    X = 0.5 * (X + Y)
    centre = mirror == np.arange(len(X))
    X[centre, 0] = 0.0
    return X


def neighbour_table(me):
    pairs = []
    for e in me.edges:
        a, b = e.vertices
        pairs += [(a, b), (b, a)]
    pairs = np.array(sorted(pairs), dtype=np.int64)
    cnt = np.bincount(pairs[:, 0], minlength=len(me.vertices))
    return pairs, cnt


# ----------------------------------------------------------------------------------------------- quality checks
def quality(obj, base_obj, field):
    """Folds (edges sharper than ~115 degrees), faces turned against the field's outside, stretch against the base."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    folds = sum(1 for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle() > 2.0)
    cents = np.array([f.calc_center_median() for f in bm.faces], dtype=np.float32)
    nrms = np.array([f.normal for f in bm.faces], dtype=np.float32)
    g = field.grad(cents)
    inward = int(((g * nrms).sum(axis=1) < 0).sum())
    el = np.array([e.calc_length() for e in bm.edges])
    bm.free()
    bb = bmesh.new()
    bb.from_mesh(base_obj.data)
    el_b = np.array([e.calc_length() for e in bb.edges])
    bb.free()
    ratio = el / np.maximum(el_b, 1e-6)
    return dict(folds=folds, inward=inward, edge_min=round(float(el.min()), 4),
                stretch_p1=round(float(np.percentile(ratio, 1)), 2), stretch_p99=round(float(np.percentile(ratio, 99)), 2))


def unfold(obj, passes=6):
    """Smooths round any edge folded sharper than ~115 degrees (positions only: the topology stays shared)."""
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


# ----------------------------------------------------------------------------------------------- hands, heads
def load_hands():
    ns = {"__name__": "hands04_lib", "CARTOON_AS_LIBRARY": True}
    exec(open(os.path.join(SCRIPTS, "build_cartoon_hands_04.py")).read(), ns)
    return ns


def hand_space(side, size):
    """Hand space (build_cartoon_hands_04.py, as hands_03) to the hand bone: left turned -90 degrees, right mirrored
    and turned +90 (palm facing the body, thumb forward), scaled to the build, the wrist on the joint
    (build_cartoon_rig_02.hand_space, the same matrix)."""
    sx = 1 if side == "Left" else -1
    return Matrix.Translation(Vector((0, 0, 0.06 * size))) @ Matrix.Rotation(math.radians(-90 * sx), 4, "Z") \
        @ Matrix.Diagonal((size * sx, size, size, 1.0))


def place_hand(hand_mesh, side, spec, name, coll):
    me = hand_mesh.copy()
    me.name = name
    sx = 1 if side == "Left" else -1
    me.transform(Matrix.Translation(Vector((sx * spec["arm_x"], 0, L["WR"]))) @ hand_space(side, spec["hand"]))
    if sx < 0:
        me.flip_normals()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.clear()
    me.materials.append(skin_material())
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    return o


def skin_material():
    m = bpy.data.materials.get("CartoonSkin") or bpy.data.materials.new("CartoonSkin")
    m.diffuse_color = SKIN
    return m


def stand_in_head(name, x, coll):
    return P4["stand_in_head"](name, L, x, coll)


def new_collection(name):
    coll = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(coll)
    return coll


def triangles(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


# ----------------------------------------------------------------------------------------------- main
if globals().get("BODY05_AS_LIBRARY") is not True:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    HANDS = load_hands()
    main = new_collection("Bodies05")
    preview = new_collection("Preview")
    specs = {b: body_spec(b) for b in ORDER}
    fields = {b: Field(specs[b]) for b in ORDER}
    base = make_base(fields[BASE])
    me_b = base.data
    base_co = np.array([v.co for v in me_b.vertices], dtype=np.float32)
    mirror, worst = mirror_map(base_co)
    log("mirror twins found, worst distance %.5f" % worst)
    nb = neighbour_table(me_b)
    open_hand = HANDS["make_hand"]("Open", preview)        # one hand mesh, placed per build
    report = {}
    for i, b in enumerate(ORDER):
        X = reshape(base_co, None, nb, fields[BASE], fields[b], specs[BASE], specs[b], mirror)
        me = me_b.copy()
        me.name = "Body05_" + b
        me.vertices.foreach_set("co", X.astype(np.float32).ravel())
        me.update()
        obj = bpy.data.objects.new("Body05_" + b, me)
        main.objects.link(obj)
        smoothed = unfold(obj)
        for p in me.polygons:
            p.use_smooth = True
        me.materials.clear()
        me.materials.append(skin_material())
        q = quality(obj, base, fields[b])
        hands = [place_hand(open_hand.data, s, specs[b], "Body05_%s_%sHand" % (b, s), main) for s in ("Left", "Right")]
        x = i * SPACING
        for o in [obj] + hands:
            o.location.x = x
        stand_in_head("Body05_%s_Head" % b, x, preview)
        q.update(tris=triangles(obj), hand_tris=sum(triangles(h) for h in hands), unfolded=smoothed)
        report[b] = q
        log(b, q)
    bpy.data.objects.remove(open_hand, do_unlink=True)
    base.name = "Base05_Fit"
    for c in list(base.users_collection):
        c.objects.unlink(base)
    preview.objects.link(base)
    base.hide_render = True
    base.hide_viewport = True
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    log("saved", OUT_BLEND)
