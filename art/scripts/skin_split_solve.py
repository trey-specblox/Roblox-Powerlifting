# SKIN-WEIGHT SOLVE for the two body folds (body polish 2026-11-17, user: "Body polish"):
#   1. the armpit fold with the arms overhead (skin through the tee / singlet, Big and buff's tee pinching under the arm);
#   2. the hip fold in the deep squat / deadlift / sitting (skin through the shorts at the hip crease).
# Library, no Blender needed (numpy only): build_cartoon_rig_05.py runs it on the shared weights, after its shoulder
# and elbow spreading and before the final mirror.
#
# What it does. Round the shoulder (upper torso <-> upper arm) and the hip (lower torso <-> thigh), each skin point
# gets ONE number: its share of the limb bone in (torso + limb). The solver chooses those shares so that, over a set
# of joint poses, the skinned body changes as little as possible:
#   - every skin edge keeps its length (log of the length ratio: squashing and stretching cost the same);
#   - no triangle flips inside out (its signed area along the skinned rest normal; a flip costs a lot);
#   - the surface doesn't crumple (each point keeps its rest offset from its neighbours' middle, skinned);
#   - the shares stay smooth along the skin and near where they started.
# The poses: sweeps (arm out / forward / diagonal up to 165 degrees, thigh forward to 145) plus the game's own
# hardest moments read from art/animations (arms up, the overhead clap, the squat bar hold, bench, double biceps, the
# squat bottom, the deadlift, sitting...). All six builds are solved TOGETHER (they share their weights by point;
# solving each build alone was tried and was worse). Left side only; the caller mirrors it.
#
# Measured 2026-11-17 (D:\ClaudeScratch\folds, all six builds, the live animations; "folds" = skin triangles cutting
# through skin that sat within 0.45 of them at rest, i.e. the skin folding onto itself, not two parts touching):
#   arms up (ArmsUpBounce / LightsArmsUp)  14-104 -> 0-10      squat bar hold  14-84 -> 0-35
#   squat bottom (hip)                     18-52  -> 0-2       sitting         0-48  -> 0-4
#   double biceps 8-20 -> 0-14; bench, chest slap, deadlift unchanged or better. The overhead clap (arms crossed over
#   the head) stays about as before: thin builds better, Muscular / Big and buff a little worse bare, but the v4 tee
#   test there went 32-119 -> 8-33 skin points through. Elbow sweep identical.
# The "jagged seat facets" seen in Blender pictures were mostly Blender's way of bending stored corner normals; shaded
# as Roblox does (each point's normal turned by its own bone blend) they were not there. The real hip problem was the
# fold above (skin through the shorts at the hip crease), which this fixes.
import math

import numpy as np

# tuning (the values chosen on 2026-11-17; see the measurements above)
W_EDGE, W_TRI, W_LAP = 0.5, 1.0, 55.0
LAM_SMOOTH, LAM_KEEP = 0.3, 0.002
S_MIN, KAPPA = 0.08, 300.0
ITERS, LR = 1500, 0.02
import os  # noqa: E402  (tuning switches for comparisons)
HOLD_X = float(os.environ.get("SOLVE_HOLD_X", "0"))         # the strap band's outer edge; 0 = OFF (tried, worse: see below)
HOLD_DOWN = float(os.environ.get("SOLVE_HOLD_DOWN", "0.6"))  # ... from the shoulder top down to SH - this
HOLD_X_BUILD = {"Skinny": 0.80}                              # (the thin arm puts Skinny's strap edge further in)


def rot(axis, deg):
    a = np.asarray(axis, float)
    a = a / np.linalg.norm(a)
    t = math.radians(deg)
    K = np.array([[0, -a[2], a[1]], [a[2], 0, -a[0]], [-a[1], a[0], 0]])
    return np.eye(3) + math.sin(t) * K + (1 - math.cos(t)) * K @ K


OUT_, FWD, BACK, DIAG, UP = (0, -1, 0), (-1, 0, 0), (1, 0, 0), (-1, -1, 0), (0, 0, 1)
# the game's hardest moments: the left upper arm vs the upper torso / the left thigh vs the lower torso (axis in the
# rig's space, degrees, weight), read 2026-11-17 from art/animations with gear_fit_03.pose_rig: ArmsUpBounce,
# OverheadClap, Setup_Squat (bar hold), Station_Bench, DoubleBiceps, Station_Squat, ChestSlap, CrouchRoarJump /
# Station_Squat, Station_Deadlift, SitBreath, Setup_Squat, CrouchRoarJump, Station_Bench.
REAL_ARM = [((-0.02, -1.0, -0.05), 141, 3), ((-0.65, -0.75, -0.14), 166, 3), ((-0.14, -0.30, 0.95), 140, 2),
            ((-0.28, -0.75, -0.60), 107, 2), ((-0.85, -0.42, 0.32), 111, 2), ((0.16, -0.19, 0.97), 113, 2),
            ((0.11, -0.89, -0.44), 93, 1), ((0.59, -0.71, -0.40), 108, 1)]
REAL_LEG = [((-0.96, -0.23, 0.13), 133, 3), ((-0.99, -0.02, 0.13), 83, 2), ((-0.92, 0.01, 0.40), 106, 2),
            ((-0.94, -0.27, 0.19), 59, 1), ((-0.95, -0.21, 0.22), 81, 1), ((0.75, -0.62, 0.26), 58, 1)]
ARM_POSES = ([(rot(OUT_, d), w) for d, w in ((45, 1), (90, 1), (135, 2), (165, 3))] +
             [(rot(FWD, d), w) for d, w in ((45, 1), (90, 1), (135, 2), (165, 3))] +
             [(rot(DIAG, d), w) for d, w in ((90, 1), (135, 2), (165, 3))] +
             [(rot(BACK, 40), 1), (rot(UP, -30) @ rot(FWD, 90), 1), (rot(UP, 25) @ rot(OUT_, 80), 1)] +
             [(rot(ax, d), w) for ax, d, w in REAL_ARM] + [(rot(ax, d / 2), 1) for ax, d, w in REAL_ARM])
LEG_POSES = ([(rot(FWD, d), w) for d, w in ((45, 1), (90, 1.5), (120, 2), (135, 3), (145, 2))] +
             [(rot(UP, 20) @ rot(OUT_, 25) @ rot(FWD, d), w) for d, w in ((110, 2), (130, 3))] +
             [(rot(BACK, 25), 1), (rot(OUT_, 35), 1)] +
             [(rot(ax, d), w) for ax, d, w in REAL_LEG])


class Mesh:
    """The shared skin's topology: edges, triangles, neighbour means."""

    def __init__(self, n, polygons):
        edges, tris = set(), []
        for vs in polygons:
            for k in range(len(vs)):
                a, c = vs[k], vs[(k + 1) % len(vs)]
                if a != c:
                    edges.add((min(a, c), max(a, c)))
            for k in range(1, len(vs) - 1):
                t = (vs[0], vs[k], vs[k + 1])
                if len(set(t)) == 3:
                    tris.append(t)
        self.n = n
        self.edges = np.array(sorted(edges))
        self.tris = np.array(tris)
        self.deg = np.zeros(n)
        np.add.at(self.deg, self.edges[:, 0], 1)
        np.add.at(self.deg, self.edges[:, 1], 1)

    def nbmean(self, P):
        e = self.edges
        S = np.zeros_like(P)
        np.add.at(S, e[:, 0], P[e[:, 1]])
        np.add.at(S, e[:, 1], P[e[:, 0]])
        return S / self.deg[:, None]

    def nbspread(self, G):
        """The transpose of nbmean."""
        e = self.edges
        Gd = G / self.deg[:, None]
        S = np.zeros_like(G)
        np.add.at(S, e[:, 1], Gd[e[:, 0]])
        np.add.at(S, e[:, 0], Gd[e[:, 1]])
        return S


def solve(W, bones, mesh, rests, pivots, torso, limb, chain, var, poses, log=print, name="", hold=None):
    """Changes W (points x bones) in place: inside `var`, each point's limb share of (torso + limb).
    rests: {build: rest points (n x 3)}; pivots: {build: the limb joint's rest position}; chain: the limb's lower
    bones (they follow it fully in these poses). hold: points pinned to the torso (share 0, not solved: the
    neighbours are solved around them)."""
    bi = {b: i for i, b in enumerate(bones)}
    ut, ua = bi[torso], bi[limb]
    ch = [bi[c] for c in chain]
    N = mesh.n
    pool = W[:, ut] + W[:, ua]
    share0 = np.where(pool > 1e-6, W[:, ua] / np.maximum(pool, 1e-9), 0.0)
    if hold is not None:
        share0 = np.where(hold, 0.0, share0)
        var = var & ~hold
        W[hold, ut] = pool[hold]
        W[hold, ua] = 0.0
    edges, tris = mesh.edges, mesh.tris
    E2 = edges[var[edges[:, 0]] | var[edges[:, 1]]]
    T2 = tris[var[tris[:, 0]] | var[tris[:, 1]] | var[tris[:, 2]]]
    fixed_chain = W[:, ch].sum(axis=1)
    terms = []
    for b, r in rests.items():
        h = np.asarray(pivots[b], float)
        l0 = np.sum((r[E2[:, 0]] - r[E2[:, 1]]) ** 2, axis=1)
        n0 = np.cross(r[T2[:, 1]] - r[T2[:, 0]], r[T2[:, 2]] - r[T2[:, 0]])
        A0 = np.linalg.norm(n0, axis=1)
        n0h = n0 / np.maximum(A0, 1e-12)[:, None]
        lap = r - mesh.nbmean(r)
        h2 = np.mean(l0)
        for Rm, w in poses:
            d = ((r - h) @ Rm.T + h) - r          # where each point goes if it follows the limb fully, minus rest
            terms.append((r, d, w, l0, n0h, n0h @ Rm.T, A0, lap, lap @ Rm.T, h2))
    K = len(terms)

    def energy_grad(a):
        wc = fixed_chain + pool * a
        g = np.zeros(N)
        tot = 0.0
        for r, d, w, l0, n0h, rn0h, A0, lap, rlap, h2 in terms:
            p = r + wc[:, None] * d
            # edges keep their length
            e = p[E2[:, 0]] - p[E2[:, 1]]
            q = np.maximum(np.sum(e * e, axis=1), 1e-8)
            lg = np.log(q / l0)
            tot += W_EDGE * w * np.sum(lg ** 2)
            c = W_EDGE * w * 4 * lg / q
            np.add.at(g, E2[:, 0], c * np.sum(e * d[E2[:, 0]], axis=1))
            np.add.at(g, E2[:, 1], -c * np.sum(e * d[E2[:, 1]], axis=1))
            # no crumpling
            dl = p - mesh.nbmean(p) - (lap + wc[:, None] * (rlap - lap))
            tot += W_LAP * w * np.sum(dl * dl) / h2
            gl = 2 * W_LAP * w / h2 * dl
            g += np.sum((gl - mesh.nbspread(gl)) * d, axis=1) - np.sum(gl * (rlap - lap), axis=1)
            # no flipped triangles
            wb = wc[T2].mean(axis=1)[:, None]
            m = (1 - wb) * n0h + wb * rn0h
            m /= np.maximum(np.linalg.norm(m, axis=1), 1e-12)[:, None]
            p0, p1, p2 = p[T2[:, 0]], p[T2[:, 1]], p[T2[:, 2]]
            u, v = p1 - p0, p2 - p0
            sa = np.sum(np.cross(u, v) * m, axis=1) / A0
            ok = sa > S_MIN
            ls = np.log(np.where(ok, sa, S_MIN))
            tot += W_TRI * w * (np.sum(ls[ok] ** 2) + np.sum(np.log(S_MIN) ** 2 + KAPPA * (S_MIN - sa[~ok]) ** 2))
            dEds = W_TRI * w * np.where(ok, 2 * ls / np.where(ok, sa, 1.0), -2 * KAPPA * (S_MIN - sa))
            gj = np.cross(v, m) / A0[:, None]
            gk = np.cross(m, u) / A0[:, None]
            for col, gg in ((0, -(gj + gk)), (1, gj), (2, gk)):
                np.add.at(g, T2[:, col], dEds * np.sum(gg * d[T2[:, col]], axis=1))
        g *= pool
        da = a[E2[:, 0]] - a[E2[:, 1]]
        tot += LAM_SMOOTH * np.sum(da ** 2) * K + LAM_KEEP * np.sum((a - share0) ** 2) * K
        np.add.at(g, E2[:, 0], 2 * LAM_SMOOTH * da * K)
        np.add.at(g, E2[:, 1], -2 * LAM_SMOOTH * da * K)
        g += 2 * LAM_KEEP * (a - share0) * K
        g[~var] = 0.0
        return tot, g

    a = share0.copy()
    m1, m2 = np.zeros(N), np.zeros(N)
    e0, _ = energy_grad(a)
    for it in range(1, ITERS + 1):
        tot, g = energy_grad(a)
        m1 = 0.9 * m1 + 0.1 * g
        m2 = 0.999 * m2 + 0.001 * g * g
        a = np.clip(a - LR * (m1 / (1 - 0.9 ** it)) / (np.sqrt(m2 / (1 - 0.999 ** it)) + 1e-8), 0.0, 1.0)
    W[var, ua] = pool[var] * a[var]
    W[var, ut] = pool[var] * (1 - a[var])
    log("%s solve: %d points, energy %.0f -> %.0f, share changed mean %.3f max %.3f" % (
        name, int(var.sum()), e0, tot, np.mean(np.abs(a - share0)[var]), np.max(np.abs(a - share0)[var])))
    return W


def solve_shoulders_hips(W, bones, mesh, co, rests, arm_pivots, leg_pivots, L, log=print):
    """Both solves on the LEFT side (x > 0.02); the caller mirrors the result. co: the base build's rest points (the
    regions are picked on it); arm_pivots / leg_pivots: {build: left shoulder / hip joint}."""
    bi = {b: i for i, b in enumerate(bones)}
    pool = W[:, bi["UpperTorso"]] + W[:, bi["LeftUpperArm"]]
    var = (co[:, 0] > 0.02) & (pool > 0.3) & (co[:, 2] > L["SH"] - 1.3) & (co[:, 2] > L["E"] + 0.4)
    # THE STRAP BAND ON THE TORSO (2026-11-17, for the user's singlet: "your singlet strap disappears, and ur singlet
    # gets all torn up"): where the singlet's straps lie (build_cartoon_gear_07: |x| 0.66 .. ~0.88 on every build, from
    # the head's width), from the shoulder top down the chest and back to armpit level, the skin follows the TORSO
    # only, so the straps (copied from it and held on the torso) don't stretch with the arm; the deltoid outside the
    # strap line takes the arm's bend. Picked on the base build; the shared weights carry it to the others.
    # A point is held only where it lies under the strap on EVERY build (the shared weights put the same point further
    # out on a wide build: held on the base build alone, Big and buff's deltoid was held too and folded).
    # RESULT (2026-11-17, OFF by default): tried |x| < 0.86 / 0.75, down to SH-0.6 / SH-0.25. Every version was WORSE on
    # both counts: arms-up folds 0-10 -> 14-66 on all builds, and the skin under the straps stretched MORE (p99 1.2-1.6x
    # -> 1.6-2.5x): with one shoulder joint the arm's 140-166 degree turn has to happen in the thin strip between the
    # held band and the arm, so it piles up there. The singlet's stretch is mostly at its armhole edge on the arm's root,
    # not on the strap band. A real fix needs a second shoulder bone (clavicle) or a gear-side change.
    hold = None
    if HOLD_X > 0:
        hold = co[:, 0] > 0.02
        for b, r in rests.items():
            hold &= (np.abs(r[:, 0]) < HOLD_X_BUILD.get(b, HOLD_X)) & (r[:, 2] > L["SH"] - HOLD_DOWN)
    solve(W, bones, mesh, rests, arm_pivots, "UpperTorso", "LeftUpperArm", ["LeftLowerArm", "LeftHand"], var,
          ARM_POSES, log, "shoulder", hold=hold)
    pool = W[:, bi["LowerTorso"]] + W[:, bi["LeftUpperLeg"]]
    var = (co[:, 0] > 0.02) & (pool > 0.3) & (co[:, 2] > L["HJ"] - 0.95) & (co[:, 2] < L["HJ"] + 0.6)
    solve(W, bones, mesh, rests, leg_pivots, "LowerTorso", "LeftUpperLeg", ["LeftLowerLeg", "LeftFoot"], var,
          LEG_POSES, log, "hip")
    return W
