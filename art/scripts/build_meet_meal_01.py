# The meet meal (GAME_DESIGN §40.7 "Meet meals", user 2026-11-23: "Chicken, rice, broccoli", the classic powerlifter
# meet-prep plate). ONE item, MeetMeal, shared by all 40 pan zones: the game scales it to the size of each cook
# (KitchenConfig.steakLength, as the big steak) and shows it on your pan and in the chef's picker.
#
#   _Plate     a white plate: a foot ring, a wide flat well and a raised rim
#   _Rim       a navy band round the rim's top
#   _Label     CENTRAL in yellow on the rim's front slope (the gear-brand rule)
#   _Chicken   a fat grilled chicken breast
#   _Grill     dark grill marks across the chicken's top
#   _Rice      a mound of white rice with a few clumps on top
#   _Broccoli  three florets' heads, dark green
#   _Stems     the florets' pale stalks
#
# Units: 1 Blender unit = 1 stud, z up, the front toward -Y. About 10 studs across at scale 1, as the big steak (9.6).
# Every layer stands at least 0.05 proud of what it lies on, or cuts into it (memory "No flicker, no overlap").
#
#   blender -b --factory-startup --python art/scripts/build_meet_meal_01.py -- <out.blend> [<out.glb>]

import json
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, r"D:\Powerlifting Roblox\art\scripts")
import importlib  # noqa: E402

import prop_helpers as H  # noqa: E402

importlib.reload(H)

# A clean scene (run with --factory-startup: no default cube).
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

B = H.Builder("MeetMeal")
V = Vector

PLATE = H.material("Meal_Plate", (0.95, 0.95, 0.93), roughness=0.35)
NAVY = H.material("Meal_RimNavy", (0.04, 0.08, 0.24), roughness=0.4)
YELLOW = H.material("Meal_LabelYellow", (0.98, 0.78, 0.1), roughness=0.45)
CHICKEN = H.material("Meal_Chicken", (0.82, 0.52, 0.22), roughness=0.6)
GRILL = H.material("Meal_Grill", (0.28, 0.13, 0.05), roughness=0.7)
RICE = H.material("Meal_Rice", (0.96, 0.94, 0.86), roughness=0.75)
BROCCOLI = H.material("Meal_Broccoli", (0.1, 0.42, 0.12), roughness=0.7)
STEM = H.material("Meal_Stem", (0.55, 0.75, 0.3), roughness=0.65)

R = 5.0  # the plate's outer radius
FLOOR = 0.28  # the well's top
WELL = 3.3  # the flat well's radius
SEG = 40

# ---------------------------------------------------------------- the plate


def plate(bm):
    # Out along the underside (a foot ring), up the outside to the rim's lip, back down the inside slope, across the well.
    H.lathe_z(bm, [
        (0.0, 0.1),
        (2.6, 0.1),
        (2.7, 0.0),
        (3.0, 0.0),
        (3.15, 0.12),
        (4.55, 0.42),
        (R, 0.64),
        (R - 0.12, 0.74),
        (4.4, 0.6),
        (WELL, FLOOR),
        (0.0, FLOOR),
    ], segments=SEG)


def rim_band(bm):
    # A navy band on the rim's top: a torus whose tube cuts into the lip (no face lies on the plate's).
    H.torus(bm, (0, 0, 0.69), R - 0.3, 0.1, segments=SEG, sides=8)


def label(bm):
    # CENTRAL on the inside slope, at the front (-Y), lying in the slope: it rises 0.32 over 1.1 outward.
    slope = math.atan2(0.32, 1.1)
    # The letters' tops point down the slope, toward the plate's middle: read from the front, like writing on a table.
    up_dir = V((0, math.cos(slope), -math.sin(slope)))
    normal = V((0, math.sin(slope), math.cos(slope)))  # out of the surface
    r_mid = (WELL + 4.4) / 2
    surface = V((0, -r_mid, FLOOR + (r_mid - WELL) / (4.4 - WELL) * (0.6 - FLOOR)))

    def place(x, up, depth):
        # (its back 0.02 inside the plate, its face 0.06 proud of it)
        return surface + V((x, 0, 0)) + up_dir * up + normal * (depth - 0.02)

    B.add_text(bm, "CENTRAL", 0.6, 0.04, place)


B.piece("MeetMeal_Plate", PLATE, plate)
B.piece("MeetMeal_Rim", NAVY, rim_band)
label_obj = B.piece("MeetMeal_Label", YELLOW, label, smooth=False)
if label_obj.dimensions.x > 3.2:
    raise RuntimeError(f"CENTRAL ({label_obj.dimensions.x:.2f} wide) is too wide for the rim")

# ---------------------------------------------------------------- the food (on the well, its bottoms 0.03 into it)

BASE = FLOOR - 0.03


def loft(bm, rings):
    """A closed solid through horizontal rings of (x, y) points, bottom ring first, each anticlockwise from above."""
    layers = [[bm.verts.new(V((x, y, z))) for x, y in ring] for ring, z in rings]
    bm.faces.new(list(reversed(layers[0])))
    bm.faces.new(layers[-1])
    n = len(layers[0])
    for low, high in zip(layers, layers[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((low[i], low[j], high[j], high[i]))


CHICKEN_C = V((-1.05, 1.1, 0))  # its middle on the plate (back left)
CHICKEN_TURN = math.radians(-18)
CH_N = 24
CH_THICK = 1.15


def breast(t, grow=0.0):
    """A chicken breast seen from above: a teardrop, round at one end (+x), tapering to the other."""
    x = 2.15 * math.cos(t)
    y = (1.15 + 0.32 * math.cos(t)) * math.sin(t)
    d = math.hypot(x, y) or 1
    x, y = x * (1 + grow / d), y * (1 + grow / d)
    c, s = math.cos(CHICKEN_TURN), math.sin(CHICKEN_TURN)
    return (CHICKEN_C.x + c * x - s * y, CHICKEN_C.y + s * x + c * y)


CH_RING = [2 * math.pi * k / CH_N for k in range(CH_N)]


def chicken(bm):
    # Plump: narrower at the bottom than the middle, the top rounded over by three smaller rings.
    loft(bm, [
        ([breast(t, -0.18) for t in CH_RING], BASE),
        ([breast(t, 0.0) for t in CH_RING], BASE + 0.3),
        ([breast(t, -0.04) for t in CH_RING], BASE + CH_THICK - 0.4),
        ([breast(t, -0.2) for t in CH_RING], BASE + CH_THICK - 0.15),
        ([breast(t, -0.45) for t in CH_RING], BASE + CH_THICK - 0.03),
        ([breast(t, -0.75) for t in CH_RING], BASE + CH_THICK),
    ])


# The grill marks (user 2026-11-23: "line up the chicken lines ... the grill lines are falling off the chicken breast",
# with a photo of grilled breasts: many even, parallel sear lines across the meat, all ON it). Each line is a thin strip
# laid ON the chicken's surface: sampled along a straight line, every sample dropped onto the breast (a ray from above),
# the strip 0.035 above the surface and 0.05 into it, and it stops where the surface turns down the side, so no end
# ever hangs off the edge. The lines are parallel, evenly spaced, across the breast at an angle.
GRILL_ANGLE = math.radians(48)  # from the breast's long axis
GRILL_GAP = 0.36  # between lines
GRILL_HALF = 0.07  # half a line's width
GRILL_STEP = 0.15  # between samples along a line
GRILL_FLAT = 0.55  # a line stops where the surface's normal leans further than this (its z) from straight up


def grill_marks(bm, surface):
    """`surface` is a BVHTree of the chicken."""
    along = Matrix.Rotation(CHICKEN_TURN + GRILL_ANGLE, 3, "Z") @ V((1, 0, 0))
    across = V((-along.y, along.x, 0))  # left of `along`
    top = BASE + CH_THICK + 1

    def drop(x, y):
        hit = surface.ray_cast(V((x, y, top)), V((0, 0, -1)))
        if hit[0] is None or hit[1].z < GRILL_FLAT:
            return None
        return hit[0].z

    for k in range(-6, 7):
        offset = CHICKEN_C + across * (k * GRILL_GAP)
        # walk the whole line; keep the longest run of samples that land on the top
        run, best = [], []
        for i in range(-32, 33):
            p = offset + along * (i * GRILL_STEP)
            z = drop(p.x, p.y)
            if z is None:
                if len(run) > len(best):
                    best = run
                run = []
            else:
                run.append(p)
        if len(run) > len(best):
            best = run
        best = best[1:-1]  # one step in from where the surface turns down
        if len(best) < 6:
            continue  # (too short to read as a mark: a lone stub near the tip looked like a crumb)
        n = len(best)
        rows = []
        for i, p in enumerate(best):
            # narrower toward the ends, like a real sear mark
            ends = min(i, n - 1 - i)
            w = GRILL_HALF * min(1.0, 0.45 + 0.55 * ends / 2)
            left, right = p + across * w, p - across * w
            zl, zr, zm = drop(left.x, left.y), drop(right.x, right.y), drop(p.x, p.y)
            zl = zl if zl is not None else zm
            zr = zr if zr is not None else zm
            rows.append((
                bm.verts.new(V((left.x, left.y, zl + 0.035))), bm.verts.new(V((right.x, right.y, zr + 0.035))),
                bm.verts.new(V((left.x, left.y, zl - 0.05))), bm.verts.new(V((right.x, right.y, zr - 0.05))),
            ))
        for (lt0, rt0, lb0, rb0), (lt1, rt1, lb1, rb1) in zip(rows, rows[1:]):
            bm.faces.new((lt0, rt0, rt1, lt1))  # top
            bm.faces.new((lb1, rb1, rb0, lb0))  # bottom
            bm.faces.new((lt0, lt1, lb1, lb0))  # left side
            bm.faces.new((rt1, rt0, rb0, rb1))  # right side
        lt, rt, lb, rb = rows[0]
        bm.faces.new((lt, lb, rb, rt))  # start cap
        lt, rt, lb, rb = rows[-1]
        bm.faces.new((rt, rb, lb, lt))  # end cap


RICE_C = V((1.95, 0.45, 0))  # the mound's middle (back right)
RICE_R, RICE_H = 1.75, 1.05


def rice(bm):
    # A soft mound (a lathe dome, a little lumpy), dotted all over with long rice grains lying on it, half sunk in.
    profile = [(0.0, BASE)]
    for k in range(9):
        a = math.pi / 2 * k / 8
        lump = 0.07 * math.sin(k * 2.3)
        profile.append((RICE_R * math.cos(a) + lump, BASE + RICE_H * math.sin(a)))
    profile[-1] = (0.0, BASE + RICE_H)
    H.lathe_z(bm, profile, segments=24, centre=RICE_C)
    golden = math.pi * (3 - math.sqrt(5))
    for k in range(16):
        # spread over the dome (a golden-angle spiral), each grain turned its own way
        dist = RICE_R * 0.85 * math.sqrt((k + 0.5) / 16)
        angle = k * golden
        x, y = RICE_C.x + dist * math.cos(angle), RICE_C.y + dist * math.sin(angle)
        z = BASE + RICE_H * math.sqrt(max(0.0, 1 - (dist / RICE_R) ** 2))
        turn = Matrix.Rotation(angle * 1.7 + k, 4, "Z") @ Matrix.Rotation(math.radians(12), 4, "Y")
        bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=4, radius=1.0,
                                  matrix=Matrix.Translation(V((x, y, z))) @ turn @ Matrix.Diagonal((0.26, 0.11, 0.1, 1)))


FLORETS = [  # (x, y, height, size): three florets along the front (-Y), short stalks under big heads
    (-1.55, -1.6, 1.25, 1.25),
    (0.15, -2.05, 1.05, 1.05),
    (1.85, -1.55, 1.15, 1.15),
]


def heads(bm):
    # Each floret's head: a dome of bumps, a big middle one and six round it, sitting low on a short stalk.
    for x, y, h, s in FLORETS:
        top = BASE + h
        H.sphere(bm, V((x, y, top)), 0.55 * s, scale=(1, 1, 0.75), segments=9, rings=5)
        for k in range(6):
            a = 2 * math.pi * k / 6 + x
            H.sphere(bm, V((x + 0.5 * s * math.cos(a), y + 0.5 * s * math.sin(a), top - 0.16 * s)), 0.38 * s,
                     scale=(1, 1, 0.8), segments=7, rings=4)


def stems(bm):
    # The stalks: short and thick, from the plate up into the head, wider at the bottom.
    for x, y, h, s in FLORETS:
        H.cylinder(bm, V((x, y, BASE + h * 0.4)), 0.32 * s, h * 0.8, segments=10, radius2=0.24 * s)


chicken_bm = bmesh.new()
chicken(chicken_bm)
_probe = chicken_bm.copy()
bmesh.ops.triangulate(_probe, faces=_probe.faces[:])
_probe.normal_update()
chicken_surface = BVHTree.FromBMesh(_probe)
B.finish("MeetMeal_Chicken", chicken_bm, CHICKEN)
B.piece("MeetMeal_Grill", GRILL, lambda bm: grill_marks(bm, chicken_surface), smooth=False)
B.piece("MeetMeal_Rice", RICE, rice)
B.piece("MeetMeal_Broccoli", BROCCOLI, heads)
B.piece("MeetMeal_Stems", STEM, stems)

# ---------------------------------------------------------------- bounds, save, export

bpy.context.view_layer.update()
lo = V((1e9, 1e9, 1e9))
hi = -lo
for ob in B.coll.objects:
    for corner in ob.bound_box:
        w = ob.matrix_world @ V(corner)
        lo = V(map(min, lo, w))
        hi = V(map(max, hi, w))
bounds = {"MeetMeal": {"low": [round(v, 4) for v in lo], "high": [round(v, 4) for v in hi]}}

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if argv:
    bpy.ops.wm.save_as_mainfile(filepath=argv[0])
    with open(argv[0].replace(".blend", "_bounds.json"), "w", encoding="utf-8") as handle:
        json.dump(bounds, handle, indent=1)
if len(argv) >= 2:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in B.coll.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=argv[1], export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
tris = sum(len(p.vertices) - 2 for o in B.coll.objects for p in o.data.polygons)
print("MEET MEAL BUILT:", len(B.coll.objects), "objects,", tris, "triangles; bounds", bounds)
