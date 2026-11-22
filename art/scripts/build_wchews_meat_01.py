# W Chews' chef scene props (src/client/World/KitchenScene.luau looks for these by name in KitchenModels and uses them
# when they exist; user 2026-11-22, with two reference photos in References/W Chews/):
#
#   MeatPress   the giant meat press that slams the mince flat on the lifter's pan: a brushed-steel plate with rounded
#               corners, a round tube handle bent into a wide U on two collars, CENTRAL on its top (never the photo's
#               brand). Squatter than the photo on purpose: the scene scales it up to 5x and it must fit under the
#               nozzle 17 studs over the pan. Its underside shows when it lifts: a clean flat bottom.   10 x 6.8 x 1.6
#   MincePile   the mountain of mince after the grinder ("Look at the photo of meat, thats how the mountain of meat ...
#               should look"): a slumped heap of long soft worms of meat, deep red and pinker red, 1 in 8 white (fat),
#               draped over each other over a lumpy dark core; a few droop onto the floor. Up to 22 studs wide.
#   MeatChunk   one raw chunk of meat tumbling out of the ceiling chute (up to 12 at once): a rounded tapered slab,
#               a fat strip along one long edge and marbling on both big faces.                         2.4 x 1.6 x 1.2
#
# Every item stands on z = 0 round its own origin (the bottom centre of its bounds), front toward -Y.
# Object names are "<Item>_<Piece>", one colour per piece (the game paints pieces by name).
# The strands and lumps are made from a fixed random seed, so every run builds the same mesh.
#
#   blender -b --factory-startup --python art/scripts/build_wchews_meat_01.py -- <out.blend> [<out.glb>]

import json
import math
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, r"D:\Powerlifting Roblox\art\scripts")
import importlib  # noqa: E402

import prop_helpers as H  # noqa: E402

importlib.reload(H)

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

COLLECTION = "WChewsMeat"
B = H.Builder(COLLECTION)
# Meat is soft: smooth shading everywhere (no hard edges marked on the low-poly strands and lumps).
SOFT = H.Builder(COLLECTION, sharp_angle=math.pi)
V = Vector


def srgb(r, g, b):
    """A colour given as Roblox RGB (0-255, sRGB) in Blender's linear values, so the previews match the game."""
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (lin(r), lin(g), lin(b))


# Suggested Roblox colours (RGB) and materials are in the report and DEVELOPMENT notes; these match them.
STEEL = H.material("Wm_Steel", srgb(196, 199, 204), metallic=0.9, roughness=0.35)
STEEL_DARK = H.material("Wm_SteelDark", srgb(92, 96, 104), metallic=0.8, roughness=0.5)
MINCE_CORE = H.material("Wm_MinceCore", srgb(100, 16, 24), roughness=0.85)
MINCE_RED = H.material("Wm_MinceRed", srgb(190, 38, 48), roughness=0.4)
MINCE_PINK = H.material("Wm_MincePink", srgb(218, 92, 104), roughness=0.4)
FAT = H.material("Wm_Fat", srgb(238, 214, 208), roughness=0.5)
CHUNK_MEAT = H.material("Wm_ChunkMeat", srgb(172, 30, 40), roughness=0.4)


def worm(bm, points, radius, sides, twist=0.0):
    """A closed soft tube through `points` (3 or more), its two ends drawn in to a rounded point. One ring of `sides`
    vertices at every inner point; the first and last points are the tips. Radius is full in the middle and a little
    thinner near the ends."""
    pts = [V(p) for p in points]
    n = len(pts)
    tmp = bmesh.new()
    tip0 = tmp.verts.new(pts[0])
    tip1 = tmp.verts.new(pts[-1])
    rings = []
    # A frame carried along the path (parallel transport), so the rings never twist into a knot.
    t0 = (pts[1] - pts[0]).normalized()
    side = t0.orthogonal().normalized()
    side.rotate(Matrix.Rotation(twist, 3, t0))
    prev_t = t0
    for i in range(1, n - 1):
        t = (pts[i + 1] - pts[i - 1]).normalized()
        axis = prev_t.cross(t)
        if axis.length > 1e-6:
            side.rotate(Matrix.Rotation(prev_t.angle(t), 3, axis.normalized()))
        side = (side - t * side.dot(t)).normalized()
        up = t.cross(side)
        k = 0.82 if i in (1, n - 2) else 1.0
        ring = []
        for s in range(sides):
            a = 2 * math.pi * s / sides
            ring.append(tmp.verts.new(pts[i] + radius * k * (math.cos(a) * side + math.sin(a) * up)))
        rings.append(ring)
        prev_t = t
    for s in range(sides):
        s2 = (s + 1) % sides
        tmp.faces.new((tip0, rings[0][s2], rings[0][s]))
        tmp.faces.new((tip1, rings[-1][s], rings[-1][s2]))
        for r in range(len(rings) - 1):
            tmp.faces.new((rings[r][s], rings[r][s2], rings[r + 1][s2], rings[r + 1][s]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)


def lumpy(seed, amount, freq):
    """A smooth bumpy field in 3D (a few sine waves in random directions): returns f(point) -> -amount .. amount."""
    rng = random.Random(seed)
    waves = []
    for _ in range(6):
        d = V((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized()
        waves.append((d * freq * rng.uniform(0.7, 1.6), rng.uniform(0, 2 * math.pi)))

    def field(p):
        return amount * sum(math.sin(d.dot(p) + ph) for d, ph in waves) / len(waves) * 1.6
    return field


# ======================================================================= MeatPress (10 x 6.8, 1.6 tall)
PLATE_X, PLATE_Y, PLATE_T = 10.0, 6.8, 0.45
CORNER = 0.95
POST_X = 3.3  # the handle's posts: 6.6 apart
TUBE_R = 0.2
BAR_Z = PLATE_T + 1.15 - TUBE_R  # the handle's centreline at its top: its top 1.15 over the plate, 1.6 from the floor
BEND_R = 0.5


def rounded_rect(hx, hy, r, steps=6):
    """The outline of a rectangle with rounded corners (half sizes hx, hy), anticlockwise seen from above."""
    pts = []
    for cx, cy, start in ((hx - r, hy - r, 0), (-hx + r, hy - r, 90), (-hx + r, -hy + r, 180), (hx - r, -hy + r, 270)):
        for k in range(steps + 1):
            a = math.radians(start + 90 * k / steps)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def press_plate(bm):
    # Layers of the outline: the flat bottom, straight sides, then a soft rounded edge onto the top.
    levels = [(0.0, 0.0), (PLATE_T - 0.09, 0.0), (PLATE_T - 0.03, 0.025), (PLATE_T, 0.08)]
    tmp = bmesh.new()
    rings = []
    for z, inset in levels:
        outline = rounded_rect(PLATE_X / 2 - inset, PLATE_Y / 2 - inset, CORNER - inset)
        rings.append([tmp.verts.new((x, y, z)) for x, y in outline])
    tmp.faces.new(list(reversed(rings[0])))
    tmp.faces.new(rings[-1])
    n = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            tmp.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)


def press_handle(bm):
    # The tube: up out of one collar, round a bend, along the top, round the other bend and down into the other collar.
    path = [V((-POST_X, 0, PLATE_T - 0.03))]
    bend_z = BAR_Z - BEND_R
    for k in range(7):
        a = math.radians(180 - 90 * k / 6)
        path.append(V((-POST_X + BEND_R + BEND_R * math.cos(a), 0, bend_z + BEND_R * math.sin(a))))
    for k in range(7):
        a = math.radians(90 - 90 * k / 6)
        path.append(V((POST_X - BEND_R + BEND_R * math.cos(a), 0, bend_z + BEND_R * math.sin(a))))
    path.append(V((POST_X, 0, PLATE_T - 0.03)))
    tmp = bmesh.new()
    sides = 12
    rings = []
    for i, c in enumerate(path):
        t = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        across = t.cross(V((0, 1, 0))).normalized()
        rings.append([tmp.verts.new(c + TUBE_R * (math.cos(2 * math.pi * s / sides) * across +
                                                  math.sin(2 * math.pi * s / sides) * V((0, 1, 0))))
                      for s in range(sides)])
    for a, b in zip(rings, rings[1:]):
        for s in range(sides):
            s2 = (s + 1) % sides
            tmp.faces.new((a[s], a[s2], b[s2], b[s]))
    tmp.faces.new(rings[0])
    tmp.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)
    # The two collars the posts stand in (their bottoms sunk a little into the plate).
    for s in (-1, 1):
        H.lathe_z(bm, [(0.0, PLATE_T - 0.04), (0.34, PLATE_T - 0.04), (0.34, PLATE_T + 0.12), (0.29, PLATE_T + 0.19),
                       (0.0, PLATE_T + 0.19)], 16, centre=V((s * POST_X, 0, 0)))


def press_text(bm):
    # CENTRAL across the plate's top in front of the handle, read from the front; dark like an engraving, its top
    # 0.05 proud of the plate so the two never flicker.
    B.add_text(bm, "CENTRAL", 0.95, 0.03, lambda x, up, depth: V((x, -2.05 + up, PLATE_T - 0.01 + depth)))


B.piece("MeatPress_Plate", STEEL, press_plate)
B.piece("MeatPress_Handle", STEEL, press_handle)
B.piece("MeatPress_Text", STEEL_DARK, press_text, smooth=False)

# ======================================================================= MincePile (a slumped heap, ~2.7 tall)
# As the user's photo: long soft worms of meat lying along the heap and draped over each other in two or three layers,
# over a lumpy dark-red core so any gap reads as more meat in shadow; an uneven outline, wider and messier at the base,
# a few worms drooping onto the floor. The heap's shape is a height field (one height for every point of the floor),
# so a worm can be walked along its surface. Review 2026-11-21 (W Chews session): up to 12,000 triangles for the pile
# (shown at most twice at once, one player's screen, no shadows or collisions); every piece still under 5,000.
PILE_R = 2.0  # the heap's base radius (its outline is uneven round that)
PILE_H = 1.95  # the core's height; the worms lying over it bring the whole to about 2.4
_shape = random.Random(41)
_OUTLINE_WAVES = [(k, _shape.uniform(0.04, 0.09) / (1 + 0.3 * k), _shape.uniform(0, 2 * math.pi)) for k in (2, 3, 5)]
_LOBES = [(V((_shape.uniform(-1.0, 1.0), _shape.uniform(-1.0, 1.0), 0)), _shape.uniform(0.15, 0.3)) for _ in range(3)]


def pile_radius(angle):
    return PILE_R * (1 + sum(a * math.sin(k * angle + ph) for k, a, ph in _OUTLINE_WAVES))


def pile_height(x, y):
    """The core's surface height over the floor point (x, y): a rounded, convex top slumping into a soft base, with a
    few broad lobes so it is not a clean dome; 0 beyond its outline (the floor)."""
    u = math.hypot(x, y) / pile_radius(math.atan2(y, x))
    if u >= 1:
        return 0.0
    lobes = sum(h * math.exp(-((x - c.x) ** 2 + (y - c.y) ** 2) / 0.7) for c, h in _LOBES)
    # (its sides meet the floor at about 70 degrees: steep, but never a wall worms would slide straight down)
    return (PILE_H + lobes) * (1 - u * u) * (1 + 0.6 * u * u)


def pile_normal(x, y, e=0.02):
    """The surface's normal at floor point (x, y), and its slopes along x and y."""
    hx = (pile_height(x + e, y) - pile_height(x - e, y)) / (2 * e)
    hy = (pile_height(x, y + e) - pile_height(x, y - e)) / (2 * e)
    return V((-hx, -hy, 1)).normalized(), hx, hy


def pile_core(bm):
    segs, rings = 40, 14
    bump = lumpy(11, 0.11, 9.0)  # lumps about a worm's width across
    tmp = bmesh.new()
    top = tmp.verts.new((0, 0, pile_height(0, 0)))
    grid = []
    for k in range(1, rings + 1):
        u = k / rings
        row = []
        for s in range(segs):
            a = 2 * math.pi * (s + 0.5 * (k % 2)) / segs
            x, y = pile_radius(a) * u * math.cos(a), pile_radius(a) * u * math.sin(a)
            p = V((x, y, pile_height(x, y) if k < rings else 0.0))
            if k < rings:
                p = p + pile_normal(x, y)[0] * bump(p) * min(1.0, p.z / 0.25)
            row.append(tmp.verts.new((p.x, p.y, max(p.z, 0.0))))
        grid.append(row)
    for s in range(segs):
        tmp.faces.new((top, grid[0][s], grid[0][(s + 1) % segs]))
    for k in range(rings - 1):
        a, b = grid[k], grid[k + 1]
        for s in range(segs):
            s2 = (s + 1) % segs
            if k % 2 == 0:
                tmp.faces.new((a[s], b[s], b[s2]))
                tmp.faces.new((a[s], b[s2], a[s2]))
            else:
                tmp.faces.new((a[s], b[s], a[s2]))
                tmp.faces.new((a[s2], b[s], b[s2]))
    tmp.faces.new(list(reversed(grid[-1])))  # the flat bottom
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)


SOFT.piece("MincePile_Core", MINCE_CORE, pile_core)

WORM_R = 0.105  # a worm's thickness (radius)
WORM_RINGS = 4  # rings along a worm: 3 segments of a curl, a round tip at each end; 4 sides: 32 triangles
COUNTS = {"red": 156, "pink": 135, "fat": 42}  # (the fat about 1 in 8, the same worm shape as the meat)
DROOPERS = 12  # worms that start on the heap's bottom edge and run out onto the floor
SKIRT = 26  # worms lying round the heap's bottom edge (along it), so no bare core shows at the floor


class SampleGrid:
    """Points along the worms already laid (with their radii), found by neighbourhood, for draping new ones over."""
    CELL = 0.5

    def __init__(self):
        self.cells = {}

    def key(self, p):
        return tuple(int(math.floor(c / self.CELL)) for c in p)

    def add(self, p, radius):
        self.cells.setdefault(self.key(p), []).append((p, radius))

    def near(self, p, reach):
        k0 = self.key(p)
        n = int(math.ceil(reach / self.CELL))
        for i in range(-n, n + 1):
            for j in range(-n, n + 1):
                for k in range(-n, n + 1):
                    yield from self.cells.get((k0[0] + i, k0[1] + j, k0[2] + k), ())


def surface_xy(rng, rim=None):
    """A random floor point under the heap's surface (evenly over the surface, steep sides included); with rim (low,
    high), one near its bottom edge, between those shares of its radius."""
    while True:
        if rim:
            a = rng.uniform(0, 2 * math.pi)
            u = rng.uniform(*rim)
            return pile_radius(a) * u * math.cos(a), pile_radius(a) * u * math.sin(a)
        x, y = rng.uniform(-1.15, 1.15) * PILE_R, rng.uniform(-1.15, 1.15) * PILE_R
        if math.hypot(x, y) > 0.97 * pile_radius(math.atan2(y, x)):
            continue
        _, hx, hy = pile_normal(x, y)
        if rng.random() * 4.5 < math.sqrt(1 + hx * hx + hy * hy):
            return x, y


def tangent(x, y, theta):
    """The direction along the surface at floor point (x, y) that is `theta` radians round from level (0 = along the
    heap's contour, pi/2 = straight uphill): every way along the surface equally likely, steep sides included."""
    n = pile_normal(x, y)[0]
    level = V((0, 0, 1)).cross(n)
    level = level.normalized() if level.length > 1e-6 else V((1, 0, 0))
    return (level * math.cos(theta) + n.cross(level) * math.sin(theta)).normalized()


def walk(x, y, d, dist, turn, steps=3):
    """Walks `dist` along the surface from floor point (x, y) along direction d, turning `turn` radians round the
    surface's normal on the way. Returns the new floor point and direction."""
    for _ in range(steps):
        n = pile_normal(x, y)[0]
        flat = d - n * d.dot(n)
        if flat.length < 1e-4:  # (straight into the surface, as down a wall onto the floor: carry on level)
            flat = V((d.x, d.y, 0)) if math.hypot(d.x, d.y) > 1e-4 else V((1, 0, 0))
        d = flat.normalized()
        d.rotate(Matrix.Rotation(turn / steps, 3, n))
        p = V((x, y, pile_height(x, y))) + d * (dist / steps)
        x, y = p.x, p.y
    return x, y, d


def worm_floor_points(w):
    """The floor points under a worm's rings: walked from its middle both ways along a gently wavy curve."""
    ts = [i - (WORM_RINGS - 1) / 2 for i in range(WORM_RINGS)]

    def heading(t):
        return w["turn"] * t + w["wave"] * math.sin(2.2 * t + w["phase"])

    points = {0.0: w["mid"]}  # (an odd number of rings has one at the middle)
    for sign in (1, -1):
        x, y = w["mid"]
        d = tangent(x, y, w["heading"]) * sign
        t_prev = 0.0
        for t in sorted((t for t in ts if t * sign > 0), key=abs):
            x, y, d = walk(x, y, d, abs(t - t_prev) * w["seg"], heading(t) - heading(t_prev))
            points[t] = (x, y)
            t_prev = t
    return [points[t] for t in ts]

def lay_worm(w, laid):
    """A worm's ring centres: lying along the surface, half sunk into the core, lifted wherever it crosses a worm
    laid before it (and sagging off it gently on each side), never through the floor."""
    r = w["radius"]
    centres, normals = [], []
    for x, y in worm_floor_points(w):
        n = pile_normal(x, y)[0]
        centres.append(V((x, y, pile_height(x, y))) + n * (r * 0.45))
        normals.append(n)
    lifts = []
    for c, n in zip(centres, normals):
        lift = 0.0
        for q, rq in laid.near(c, 0.9):
            rel = q - c
            along = rel.dot(n)
            lateral = (rel - n * along).length
            touch = (r + rq) * 0.55  # (worms settle into each other: stacked high, they bridge over hollows)
            if lateral < touch:
                lift = max(lift, along + math.sqrt(touch * touch - lateral * lateral))
        lifts.append(lift)
    lifts = [min(lift, r * 1.3) for lift in lifts]  # (at most about one worm deep)
    for _ in range(2):
        lifts = [max(lifts[i], 0.55 * max(lifts[max(i - 1, 0)], lifts[min(i + 1, len(lifts) - 1)]))
                 for i in range(len(lifts))]
    centres = [c + n * lift for c, n, lift in zip(centres, normals, lifts)]
    centres = [V((c.x, c.y, max(c.z, r))) for c in centres]
    # No sharp kinks (a lift on a steep side pushes a ring sideways): any bend over 55 degrees is eased.
    for _ in range(6):
        for i in range(1, len(centres) - 1):
            a, b = centres[i] - centres[i - 1], centres[i + 1] - centres[i]
            if a.length > 1e-6 and b.length > 1e-6 and a.angle(b) > math.radians(55):
                centres[i] = centres[i] * 0.5 + (centres[i - 1] + centres[i + 1]) * 0.25
    return centres


WORMS = []


def lay_all_worms():
    """Every worm, laid one after another (later ones drape over earlier ones). Each goes where the heap is least
    covered (best of 8 random tries); the kinds are shuffled together."""
    rng = random.Random(21)
    kinds = [k for k, c in COUNTS.items() for _ in range(c)]
    rng.shuffle(kinds)
    edge = rng.sample(range(len(kinds)), DROOPERS + SKIRT)
    droop, skirt = set(edge[:DROOPERS]), set(edge[DROOPERS:])
    laid = SampleGrid()
    for index, kind in enumerate(kinds):
        rim = (0.86, 0.96) if index in droop else (0.9, 0.99) if index in skirt else None
        size = 0.85 if kind == "fat" else 1.0
        # Several tries (place, way, length, curl); the one whose whole length lies over the least-covered surface wins,
        # so the worms fill the bare patches rather than piling on each other.
        best, best_score = None, -1.0
        for _ in range(4 if rim else 8):
            x, y = surface_xy(rng, rim)
            if index in droop:
                # (from the heap's edge outward: half of it lies on the floor)
                heading = -math.pi / 2 + rng.uniform(-0.45, 0.45)  # (downhill)
                length = rng.uniform(0.7, 1.0)
            elif index in skirt:
                heading = rng.uniform(-0.3, 0.3)  # (along the bottom edge)
                length = rng.uniform(0.8, 1.1)
            else:
                heading = rng.uniform(0, 2 * math.pi)  # (any way along the surface)
                # (15 to 27 percent of the heap's width: the photo's strands are short and curly, 7 to 15 percent)
                length = rng.uniform(0.6, 1.1) * (0.8 if kind == "fat" else 1.0)
            w = {"kind": kind, "mid": (x, y), "heading": heading, "seg": length / (WORM_RINGS - 1),
                 "turn": rng.uniform(-0.15, 0.15), "wave": rng.uniform(0.35, 0.7), "phase": rng.uniform(0, 2 * math.pi),
                 "radius": WORM_R * size * rng.uniform(0.85, 1.15), "twist": rng.uniform(0, math.pi)}
            score = 0.0
            for fx, fy in worm_floor_points(w):
                p = V((fx, fy, pile_height(fx, fy)))
                score += min([(p - q).length for q, _ in laid.near(p, 0.6)] + [0.6])
            if score > best_score:
                best, best_score = w, score
        w = best
        w["centres"] = lay_worm(w, laid)
        for a, b in zip(w["centres"], w["centres"][1:]):
            laid.add(a, w["radius"])
            laid.add((a + b) / 2, w["radius"])
        laid.add(w["centres"][-1], w["radius"])
        WORMS.append(w)


def mince(kind):
    def build(bm):
        if not WORMS:
            lay_all_worms()
        for w in WORMS:
            if w["kind"] != kind:
                continue
            cs, r = w["centres"], w["radius"]
            tips = []
            for end, nxt in ((cs[0], cs[1]), (cs[-1], cs[-2])):
                out = (end - nxt).normalized()
                if (end + out * r * 0.85).z < r * 0.4:
                    # (an end lying on the floor: its tip points along the floor, not down into it, or it folds back)
                    out = V((out.x, out.y, 0)).normalized()
                tips.append(end + out * r * 0.85)
            tip0, tip1 = tips
            # Checked on its own first (the whole piece check cannot say which worm is broken).
            test = bmesh.new()
            worm(test, [tip0] + cs + [tip1], r, 4, twist=w["twist"])
            mesh = bpy.data.meshes.new("_test")
            test.to_mesh(mesh)
            test.free()
            bad = H.winding_problems(mesh)
            bpy.data.meshes.remove(mesh)
            if bad:
                # (a safety net: a worm that would fold or turn inside out is left out, and said so)
                print("MINCE WORM LEFT OUT:", kind, bad)
                continue
            worm(bm, [tip0] + cs + [tip1], r, 4, twist=w["twist"])
    return build


SOFT.piece("MincePile_Red", MINCE_RED, mince("red"))
SOFT.piece("MincePile_Pink", MINCE_PINK, mince("pink"))
SOFT.piece("MincePile_Fat", FAT, mince("fat"))

# ======================================================================= MeatChunk (~2.4 x 1.6 x 1.2)
# A raw chunk: a rounded, slightly tapered slab (thicker and wider at its -X end), its outline uneven, its two big
# faces gently domed, its sides a soft pillow curve (no flat walls); a fat strip along its back long edge (+Y) and
# marbling streaks lying in both big faces.
CHUNK_POINTS = 12
CHUNK_RX, CHUNK_RY = 1.25, 0.76  # the outline's half sizes before its unevenness and taper
CHUNK_H = 1.12  # its thickness at the middle
# (share of the thickness, how far in from the outline) from the bottom face's edge to the top face's edge.
CHUNK_LEVELS = [(0.05, 0.34), (0.16, 0.13), (0.34, 0.03), (0.55, 0.0), (0.76, 0.04), (0.92, 0.15), (1.0, 0.36)]
CHUNK_DOME = 0.08  # how far the middles of the big faces bulge past their edges


def taper(x):
    """How much of the full width and thickness the slab has at x (thinner toward +X)."""
    return 1 - 0.13 * x / CHUNK_RX


def chunk_outline():
    rng = random.Random(31)
    out = []
    for k in range(CHUNK_POINTS):
        a = 2 * math.pi * (k + rng.uniform(-0.2, 0.2)) / CHUNK_POINTS
        r = rng.uniform(0.88, 1.06)
        x = CHUNK_RX * r * math.cos(a)
        p = V((x, CHUNK_RY * r * math.sin(a) * taper(x), 0))
        out.append((p, p.normalized(), a))
    return out


OUTLINE = chunk_outline()
CHUNK_RINGS = []  # the slab's rings of points, bottom to top (the fat strip follows them)
CHUNK_HIT = []  # the slab's surface, for laying the marbling into its faces


def chunk_meat(bm):
    rng = random.Random(33)
    tmp = bmesh.new()
    rings = []
    for li, (share, inset) in enumerate(CHUNK_LEVELS):
        ring, coords = [], []
        for p, d, _ in OUTLINE:
            inner = 0 < li < len(CHUNK_LEVELS) - 1
            wobble = rng.uniform(-0.05, 0.05) if inner else 0.0
            dz = rng.uniform(-0.03, 0.03) if li in (2, 3, 4) else 0.0
            q = p - d * (inset - wobble) + V((0, 0, share * CHUNK_H * taper(p.x) + dz))
            coords.append(q)
            ring.append(tmp.verts.new(q))
        rings.append(ring)
        CHUNK_RINGS.append(coords)
    bottom = tmp.verts.new((0, 0, CHUNK_LEVELS[0][0] * CHUNK_H - CHUNK_DOME))
    top = tmp.verts.new((0, 0, CHUNK_H + CHUNK_DOME))
    n = CHUNK_POINTS
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            tmp.faces.new((a[i], a[j], b[j], b[i]))
    for i in range(n):
        j = (i + 1) % n
        tmp.faces.new((bottom, rings[0][j], rings[0][i]))
        tmp.faces.new((top, rings[-1][i], rings[-1][j]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    keep = tmp.copy()
    CHUNK_HIT.append((BVHTree.FromBMesh(keep), keep))
    H._merge(bm, tmp)


def chunk_fat(bm):
    # The fat strip along the back long edge (+Y): a band hugging the slab's side, thickest in its middle and running
    # into the meat at its ends, its inner half buried in the meat.
    arc = [k for k, (p, d, a) in enumerate(OUTLINE) if math.sin(a) > 0.45]
    arc.sort(key=lambda k: -OUTLINE[k][0].x)
    tmp = bmesh.new()
    sections = []
    for i, k in enumerate(arc):
        p, d, _ = OUTLINE[k]
        t = 0.03 + 0.13 * math.sin(math.pi * i / (len(arc) - 1))  # how far the fat stands out of the meat
        # Only the upper half of the side and over the top edge (a strip along the edge, not a white wall): its lower
        # edge starts inside the meat and swells out of it.
        upper = range(3, len(CHUNK_LEVELS))
        ring = [tmp.verts.new(CHUNK_RINGS[li][k] + d * (t * 0.2 if li == 3 else t)) for li in upper]
        ring.append(tmp.verts.new(V((p.x, p.y, CHUNK_RINGS[-1][k].z - 0.06)) - d * 0.32))
        ring.append(tmp.verts.new(V((p.x, p.y, CHUNK_RINGS[3][k].z - 0.05)) - d * 0.32))
        sections.append(ring)
    m = len(sections[0])
    for a, b in zip(sections, sections[1:]):
        for i in range(m):
            j = (i + 1) % m
            tmp.faces.new((a[i], a[j], b[j], b[i]))
    tmp.faces.new(sections[0])
    tmp.faces.new(list(reversed(sections[-1])))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)
    # Marbling: three gently bent streaks lying in each big face, half sunk in (laid onto the real surface).
    bvh = CHUNK_HIT[0][0]
    rng = random.Random(34)
    for k in range(6):
        on_top = k < 3
        centre = V((rng.uniform(-0.65, 0.6), rng.uniform(-0.35, 0.2), 0))
        a = rng.uniform(-0.7, 0.7)
        d = V((math.cos(a), math.sin(a), 0))
        side = V((-d.y, d.x, 0)) * rng.uniform(0.03, 0.07) * rng.choice((-1, 1))
        length = rng.uniform(0.38, 0.6)
        pts = []
        for s in (-0.5, -0.17, 0.17, 0.5):
            xy = centre + d * length * s + side * (1 - 4 * s * s)
            hit, normal, _, _ = bvh.ray_cast(V((xy.x, xy.y, 5.0 if on_top else -5.0)), V((0, 0, -1 if on_top else 1)))
            if hit is None:
                break
            pts.append(hit - normal * 0.014)
        if len(pts) == 4:
            worm(bm, pts, rng.uniform(0.036, 0.048), 4, twist=math.pi / 4)


SOFT.piece("MeatChunk_Meat", CHUNK_MEAT, chunk_meat)
SOFT.piece("MeatChunk_Fat", FAT, chunk_fat)

# ======================================================================= origins
# Every item's pieces moved together so the item's bounds sit with their bottom centre on the origin.
bpy.context.view_layer.update()


def item_bounds():
    items = {}
    for ob in B.coll.objects:
        item = ob.name.split("_")[0]
        for corner in ob.bound_box:
            w = ob.matrix_world @ Vector(corner)
            lo, hi = items.setdefault(item, [list(w), list(w)])
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
    return items


for item, (lo, hi) in item_bounds().items():
    shift = V((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))
    for ob in B.coll.objects:
        if ob.name.split("_")[0] == item:
            ob.location += shift
bpy.context.view_layer.update()
bounds = {item: {"low": [round(v, 4) for v in lo], "high": [round(v, 4) for v in hi]}
          for item, (lo, hi) in sorted(item_bounds().items())}

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if argv:
    bpy.ops.wm.save_as_mainfile(filepath=argv[0])
    # (next to the .glb when one is exported, art/exports/WChewsMeat_01_bounds.json; else next to the .blend)
    out = argv[1].replace(".glb", "_bounds.json") if len(argv) >= 2 else argv[0].replace(".blend", "_bounds.json")
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(bounds, handle, indent=1)
if len(argv) >= 2:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in B.coll.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=argv[1], export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
per_piece = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in B.coll.objects}
per_item = {}
for name, tris in per_piece.items():
    per_item[name.split("_")[0]] = per_item.get(name.split("_")[0], 0) + tris
print("WCHEWS MEAT BUILT:", len(B.coll.objects), "objects;", per_item)
print("  pieces:", per_piece)
print("  bounds:", {k: [round(h - l, 3) for l, h in zip(v["low"], v["high"])] for k, v in bounds.items()})
