# The Kitchen's chef (GAME_DESIGN §40.7, user 2026-11-19): a cartoon-body NPC (the coaches' body, MeetFigures: the
# "Fat" build) in a white tee, wearing these:
#
#   ChefHat_*    a puffy chef's hat (toque) with a band saying CENTRAL; welded to the head
#   ChefBib_*    the apron's bib with its neck strap and a CENTRAL label; welded to the upper torso
#   ChefSkirt_*  the apron's skirt to the knees with a pocket and the waist ties with a bow at the back; welded to the
#                lower torso
#
# FITTED to the body (user 2026-11-20, Studio: "the chef hat is over his eyes, the apron is not even on his chest ...
# If i seen my neck was covered ... or if my assessories were floating i would tell you something"): the bib, skirt,
# ties and strap are shaped on the Fat body itself (art/blender/CartoonBodies_05_Rigged.blend, the same mesh the game
# uses), lying just over the tee; the bib follows the chest and belly, the skirt hangs straight down from the belly's
# front, the strap goes round the neck under the head. The hat's band sits on the head above the eyebrows (the default
# head: a rounded cylinder 1.2 wide, its top 2.89 up, its eyes about 2.3 - 2.45 up; Studio 2026-11-20).
#
# Built in the FIGURE'S ROOT SPACE (the HumanoidRootPart's centre at the origin, front toward -Y, z up; the rig's
# HumanoidRootNode is 3.0 above its feet). KitchenChef places each item by the bounds this script prints (BOUNDS lines).
#
#   blender -b --factory-startup --python art/scripts/build_kitchen_chef_01.py -- <out.blend> [<out.glb>]

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, r"D:\Powerlifting Roblox\art\scripts")
import importlib  # noqa: E402

import prop_helpers as H  # noqa: E402

importlib.reload(H)

ROOT = r"D:\Powerlifting Roblox"
BODY_BLEND = os.path.join(ROOT, "art", "blender", "CartoonBodies_05_Rigged.blend")
BUILD = "Fat"                  # the staff's build (LifterBuild.BuildRules.Spotter)
ROOT_NODE = 3.0                # the HumanoidRootPart's centre above the rig's feet

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

B = H.Builder("KitchenChef")

WHITE = H.material("Chef_White", (0.96, 0.96, 0.94), roughness=0.7)
NAVY = H.material("Chef_ApronNavy", (0.05, 0.08, 0.21), roughness=0.8)
YELLOW = H.material("Chef_Yellow", (0.98, 0.79, 0.12), roughness=0.6)
INK = H.material("Chef_Ink", (0.06, 0.08, 0.2), roughness=0.6)

# ---------------------------------------------------------------- the body (root space)
BODY_PARTS = ("UpperTorso", "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftUpperArm", "RightUpperArm")
with bpy.data.libraries.load(BODY_BLEND, link=False) as (src, dst):
    dst.objects = [BUILD + "Rig"] + [BUILD + "_" + p for p in BODY_PARTS]
rig = next(o for o in dst.objects if o and o.name.startswith(BUILD + "Rig"))
to_root = Matrix.Translation(-(rig.matrix_world.translation + Vector((0, 0, ROOT_NODE))))
body_bm = bmesh.new()
for o in dst.objects:
    if o is None or o.type != "MESH":
        continue
    me = o.data.copy()
    me.transform(to_root @ o.matrix_world)
    body_bm.from_mesh(me)
    if o.name.startswith(BUILD + "_UpperTorso"):
        lo = Vector([min(v.co[i] for v in me.vertices) for i in range(3)])
        hi = Vector([max(v.co[i] for v in me.vertices) for i in range(3)])
        # (Studio: the upper torso's bounds centre is (0, 0.75 up, 0.18 forward) in root space)
        print("UPPER TORSO bounds centre (root space):", tuple(round(c, 3) for c in (lo + hi) / 2))
    bpy.data.meshes.remove(me)
for o in dst.objects:
    if o is not None:
        bpy.data.objects.remove(o, do_unlink=True)
BODY = BVHTree.FromBMesh(body_bm)

OVER_TEE = 0.075               # the apron's inside off the skin (the tee: 0.035 off the skin, 0.012 thick; plus room)
CLOTH = 0.025                  # the apron's thickness


def front_hit(x, z):
    """The body's front at (x, z): (point, outward normal), or None."""
    loc, normal, _i, _d = BODY.ray_cast(Vector((x, -6.0, z)), Vector((0, 1, 0)), 12.0)
    if loc is None:
        return None
    if normal.y > 0:
        normal = -normal
    return loc, normal


def around_hit(angle, z, centre_y=0.0):
    """The body's surface round the waist at `angle` (0 = front, toward -Y), height z: (point, outward normal)."""
    d = Vector((math.sin(angle), -math.cos(angle), 0))
    start = Vector((0, centre_y, z)) + d * 4.0
    loc, normal, _i, _dd = BODY.ray_cast(start, -d, 8.0)
    if loc is None:
        return None
    if normal.dot(d) < 0:
        normal = -normal
    return loc, normal


def shell(bm, front, back):
    """A closed cloth panel from two matching grids (rows of points; front = outside, back = inside), faces outward."""
    rows, cols = len(front), len(front[0])
    F = [[bm.verts.new(p) for p in row] for row in front]
    K = [[bm.verts.new(p) for p in row] for row in back]
    for r in range(rows - 1):
        for c in range(cols - 1):
            bm.faces.new((F[r][c], F[r][c + 1], F[r + 1][c + 1], F[r + 1][c]))
            bm.faces.new((K[r][c], K[r + 1][c], K[r + 1][c + 1], K[r][c + 1]))
    for r in range(rows - 1):
        for c in (0, cols - 1):
            bm.faces.new((F[r][c], F[r + 1][c], K[r + 1][c], K[r][c]))
    for c in range(cols - 1):
        for r in (0, rows - 1):
            bm.faces.new((F[r][c], K[r][c], K[r][c + 1], F[r][c + 1]))
    faces = [f for f in bm.faces]
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def ribbon(bm, path, normals, width, thick, closed=False):
    """A flat strap along `path` (points), lying on the surface whose outward normals are `normals`."""
    n = len(path)
    rings = []
    for i in range(n):
        a = path[i - 1] if (closed or i > 0) else path[i]
        b = path[(i + 1) % n] if (closed or i < n - 1) else path[i]
        t = (b - a).normalized()
        nn = (normals[i] - t * normals[i].dot(t)).normalized()
        side = t.cross(nn).normalized()
        p = path[i]
        rings.append([bm.verts.new(p + side * (width / 2) * sx + nn * (thick / 2) * sy)
                      for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    count = n if closed else n - 1
    for i in range(count):
        r0, r1 = rings[i], rings[(i + 1) % n]
        for k in range(4):
            k1 = (k + 1) % 4
            bm.faces.new((r0[k], r1[k], r1[k1], r0[k1]))
    if not closed:
        bm.faces.new(rings[0])
        bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


def smooth_path(points, rounds=3):
    pts = [p.copy() for p in points]
    for _ in range(rounds):
        pts = [pts[0]] + [pts[i] * 0.5 + (pts[i - 1] + pts[i + 1]) * 0.25 for i in range(1, len(pts) - 1)] + [pts[-1]]
    return pts


# ---------------------------------------------------------------- ChefHat (on the head)

HEAD_TOP = 2.886               # the head's top (root space, up; its HatAttachment)
BAND_BOTTOM = 2.60             # above the eyebrows (the eyes are about 2.3 - 2.45 up)
BAND_TOP = 2.97
HAT_R = 0.64                   # snug round the head (the rounded cylinder head is 0.6 round)


def hat_band(bm):
    H.cylinder(bm, Vector((0, 0, (BAND_BOTTOM + BAND_TOP) / 2)), HAT_R, BAND_TOP - BAND_BOTTOM, segments=32)


def hat_puff(bm):
    # The puffy top: a short drum over the band, a ring of soft balls round a bigger middle one, wider than the band.
    H.cylinder(bm, Vector((0, 0, BAND_TOP + 0.18)), HAT_R - 0.02, 0.42, segments=32)
    for k in range(8):
        a = 2 * math.pi * k / 8
        H.sphere(bm, Vector((0.55 * math.cos(a), 0.55 * math.sin(a), BAND_TOP + 0.62)), 0.36, segments=12, rings=7)
    H.sphere(bm, Vector((0, 0, BAND_TOP + 0.78)), 0.56, scale=(1, 1, 0.78), segments=16, rings=8)


def hat_label(bm):
    B.add_text(bm, "CENTRAL", 0.15, 0.015, H.on_cylinder((0, 0, 0), HAT_R + 0.004, (BAND_BOTTOM + BAND_TOP) / 2))


B.piece("ChefHat_Band", WHITE, hat_band)
B.piece("ChefHat_Puff", WHITE, hat_puff)
B.piece("ChefHat_Label", INK, hat_label, smooth=False)

# ---------------------------------------------------------------- ChefBib (on the upper torso)

# rows bottom to top: (height, half width); the bib's top sits under the tee's crew neck (its front at 1.45 up)
BIB_ROWS = [(-0.50, 0.80), (-0.15, 0.80), (0.20, 0.77), (0.55, 0.70), (0.85, 0.62), (1.10, 0.55), (1.28, 0.50)]
BIB_COLS = 14
BIB_STEPS = 3                  # extra rows between those


def bib_rows():
    rows = []
    for i in range(len(BIB_ROWS) - 1):
        (z0, h0), (z1, h1) = BIB_ROWS[i], BIB_ROWS[i + 1]
        for s in range(BIB_STEPS):
            t = s / BIB_STEPS
            rows.append((z0 + (z1 - z0) * t, h0 + (h1 - h0) * t))
    rows.append(BIB_ROWS[-1])
    return rows


def on_body(x, z, out):
    hit = front_hit(x, z)
    if hit is None:
        raise RuntimeError("the bib missed the body at x %.2f z %.2f" % (x, z))
    return hit[0] + hit[1] * out, hit[1]


def bib_cloth(bm):
    front, back = [], []
    for z, half in bib_rows():
        rf, rb = [], []
        for c in range(BIB_COLS + 1):
            x = -half + 2 * half * c / BIB_COLS
            rf.append(on_body(x, z, OVER_TEE + CLOTH)[0])
            rb.append(on_body(x, z, OVER_TEE)[0])
        front.append(rf)
        back.append(rb)
    shell(bm, front, back)


BIB_TOP_Z, BIB_TOP_HALF = BIB_ROWS[-1]


def top_hit(x, y):
    """The body's top surface at (x, y), seen from above: (point, outward normal), or None."""
    loc, normal, _i, _d = BODY.ray_cast(Vector((x, y, 4.0)), Vector((0, 0, -1)), 6.0)
    # (a hit on a face looking down went in through the neck's opening under the head)
    if loc is None or normal.z < 0.05:
        return None
    return loc, normal


STRAP_R = 0.72                 # the strap's ring round the neck, seen from above: just outside the head (0.6 round);
                               # the Fat body's traps run straight up into the head, so the strap lies on them there
STRAP_OUT = OVER_TEE + 0.02    # the strap's middle off the skin (over the tee)


def strap_path():
    """The neck strap: from the bib's top corners up the chest, then round the back of the neck on the traps just
    outside the head, on the body. Left corner -> round the back -> right corner."""
    top = BIB_TOP_Z - 0.06
    halves = []
    for side in (-1, 1):
        half = [on_body(side * (BIB_TOP_HALF - 0.08), top, OVER_TEE + CLOTH * 0.5)]
        z_side = None
        for ang in (55, 70, 90, 110, 130, 150, 165, 180):
            a = math.radians(ang)
            if ang <= 110:
                # over the shoulders: on top of the traps, just outside the head (seen from above)
                r = STRAP_R
                hit = None
                while hit is None and r < 1.0:
                    hit = top_hit(side * r * math.sin(a), -r * math.cos(a))
                    r += 0.02
                # (the Fat build's traps climb the head's sides: the strap goes over them there, about 1.9 up)
                if hit is not None:
                    z_side = hit[0].z
            else:
                # behind the neck: the back runs straight up into the head, so the strap goes round it there, just
                # under the head (its bottom is 1.69 up), found from outside
                t = (ang - 110) / 70
                z = z_side + (1.60 - z_side) * t
                hit = around_hit(a * side, z, centre_y=0.0)
            if hit is None:
                raise RuntimeError("the strap missed the body at %s deg" % ang)
            half.append((hit[0] + hit[1] * STRAP_OUT, hit[1]))
        halves.append(half)
    left, right = halves
    full = left + list(reversed(right[:-1]))
    path = smooth_path([p for p, _n in full], rounds=2)
    normals = [n for _p, n in full]
    # (smoothing can pull a point toward the body: put every point back STRAP_OUT off it)
    fixed = []
    for p, n in zip(path, normals):
        hit = BODY.find_nearest(p)
        if hit[0] is not None and (p - hit[0]).length < STRAP_OUT:
            p = hit[0] + (p - hit[0]).normalized() * STRAP_OUT
        fixed.append(p)
    return fixed, normals


def bib_strap(bm):
    path, normals = strap_path()
    ribbon(bm, path, normals, 0.11, 0.022)


def bib_label(bm):
    def place(x, up, depth):
        p, n = on_body(x, 0.85 + up, OVER_TEE + CLOTH + 0.004 + depth)
        return p
    B.add_text(bm, "CENTRAL", 0.24, 0.012, place)


B.piece("ChefBib_Cloth", NAVY, bib_cloth)
B.piece("ChefBib_Strap", NAVY, bib_strap)
B.piece("ChefBib_Label", YELLOW, bib_label, smooth=False)

# ---------------------------------------------------------------- ChefSkirt (on the lower torso)

SKIRT_TOP = -0.42              # the waist (the upper and lower torso meet at -0.46)
SKIRT_BOTTOM = -2.15           # the knees are at -2.0
SKIRT_HALF = (1.0, 1.02)       # half width at the top and the bottom
SKIRT_COLS = 16
SKIRT_ROWS = 14


def skirt_grid(out):
    """The skirt's surface `out` off the body: each column follows the body's front down from the waist, then hangs
    straight down from the furthest-forward point above (cloth hangs, it never tucks under the belly or between the
    legs). Columns past the body's edge take their neighbour's line, a little further back."""
    zs = [SKIRT_TOP + (SKIRT_BOTTOM - SKIRT_TOP) * r / SKIRT_ROWS for r in range(SKIRT_ROWS + 1)]
    cols = {}
    order = sorted(range(SKIRT_COLS + 1), key=lambda c: abs(c - SKIRT_COLS / 2))
    for c in order:
        line = []
        lowest = None
        for r, z in enumerate(zs):
            half = SKIRT_HALF[0] + (SKIRT_HALF[1] - SKIRT_HALF[0]) * r / SKIRT_ROWS
            x = -half + 2 * half * c / SKIRT_COLS
            hit = front_hit(x, z)
            y = hit[0].y - out if hit is not None else None
            if lowest is None:
                lowest = y
            elif y is not None:
                lowest = min(lowest, y)
            if lowest is None:
                # past the body at the waist: the inner neighbour's, a bit back
                nb = SKIRT_COLS / 2 + (abs(c - SKIRT_COLS / 2) - 1) * (1 if c > SKIRT_COLS / 2 else -1)
                lowest = cols[int(round(nb))][r].y + 0.06
            line.append(Vector((x, lowest, z)))
        cols[c] = line
    return [[cols[c][r] for c in range(SKIRT_COLS + 1)] for r in range(SKIRT_ROWS + 1)]


def skirt_cloth(bm):
    front = skirt_grid(OVER_TEE + CLOTH)
    back = [[p + Vector((0, CLOTH, 0)) for p in row] for row in front]
    shell(bm, list(reversed(front)), list(reversed(back)))


SKIRT_FRONT_GRID = None


def skirt_at(x, z, extra):
    """A point on the skirt's front at (x, z), `extra` further out."""
    global SKIRT_FRONT_GRID
    if SKIRT_FRONT_GRID is None:
        SKIRT_FRONT_GRID = skirt_grid(OVER_TEE + CLOTH)
    g = SKIRT_FRONT_GRID
    r = (z - SKIRT_TOP) / (SKIRT_BOTTOM - SKIRT_TOP) * SKIRT_ROWS
    r0 = max(0, min(SKIRT_ROWS - 1, int(r)))
    tr = r - r0
    row = [g[r0][c].lerp(g[r0 + 1][c], tr) for c in range(SKIRT_COLS + 1)]
    xs = [p.x for p in row]
    c0 = max(0, min(SKIRT_COLS - 1, int((x - xs[0]) / (xs[-1] - xs[0]) * SKIRT_COLS)))
    tc = (x - xs[c0]) / max(1e-6, xs[c0 + 1] - xs[c0])
    y = row[c0].y + (row[c0 + 1].y - row[c0].y) * tc
    return Vector((x, y - extra, z))


def skirt_pocket(bm):
    # A yellow patch pocket with a stitched split down its middle, on the skirt's front.
    front, back = [], []
    for r in range(5):
        z = -1.48 + 0.46 * r / 4
        rf, rb = [], []
        for c in range(9):
            x = -0.52 + 1.04 * c / 8
            rf.append(skirt_at(x, z, 0.022))
            rb.append(skirt_at(x, z, 0.004))
        front.append(rf)
        back.append(rb)
    shell(bm, front, back)


def skirt_ties(bm):
    # The waist band right round the body over the bib's and skirt's tops, a bow at the back, two hanging ends.
    z = SKIRT_TOP - 0.02
    path, normals = [], []
    for k in range(48):
        a = 2 * math.pi * k / 48
        hit = around_hit(a, z, centre_y=0.1)
        if hit is None:
            continue
        p, n = hit
        out = OVER_TEE + CLOTH + 0.012
        if abs(math.degrees(a) % 360 - 180) > 110:      # over the bib and skirt at the front
            out += CLOTH
        path.append(p + n * out)
        normals.append(n)
    ribbon(bm, path, normals, 0.13, 0.03, closed=True)
    back = around_hit(math.pi, z, centre_y=0.1)
    bp, bn = back[0] + back[1] * (OVER_TEE + CLOTH + 0.05), back[1]
    for side in (-1, 1):
        # the bow's loops and the hanging ends
        H.torus(bm, bp + Vector((side * 0.13, 0, 0)), 0.1, 0.035, plane="XZ", segments=16, sides=6)
        end = [bp + Vector((side * 0.05, 0, -0.02)), bp + Vector((side * 0.1, 0.01, -0.25)),
               bp + Vector((side * 0.14, 0.02, -0.5))]
        ribbon(bm, end, [bn] * 3, 0.1, 0.025)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


B.piece("ChefSkirt_Cloth", NAVY, skirt_cloth)
B.piece("ChefSkirt_Pocket", YELLOW, skirt_pocket)
B.piece("ChefSkirt_Ties", NAVY, skirt_ties)

body_bm.free()

# The bounds of each item in root space (Blender x, y, z), for KitchenChef's placement.
bpy.context.view_layer.update()
for item in ("ChefHat", "ChefBib", "ChefSkirt"):
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for ob in B.coll.objects:
        if ob.name.startswith(item + "_"):
            for corner in ob.bound_box:
                w = ob.matrix_world @ Vector(corner)
                lo = Vector(map(min, lo, w))
                hi = Vector(map(max, hi, w))
    print(f"BOUNDS {item} lo {tuple(round(v, 3) for v in lo)} hi {tuple(round(v, 3) for v in hi)}")

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if argv:
    bpy.ops.wm.save_as_mainfile(filepath=argv[0])
if len(argv) >= 2:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in B.coll.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=argv[1], export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
print("KITCHEN CHEF BUILT:", [o.name for o in B.coll.objects])
