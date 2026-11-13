# The cartoon lifters' worn lifting gear, version 3 (approved plan 2026-11-12, memory "gear-fitting-architecture";
# user: "do all of the phases"). Replaces, for the cartoon bodies, build_cartoon_gear_02.py (kept for reference), whose
# pieces were the body's own skin pushed outward and were rejected.
#
# Each item is ONE master shape written here like the real gear (a belt is a stiff band with rounded, stitched edges
# and a steel lever; ...). gear_fit_03.py fits it to each build's SMOOTHED outline automatically, so a new or
# redesigned body is a re-run of this script, never a rebuild by hand. Layers out from the skin (studs):
#   shirt 0.035 < bench shirt 0.05 < singlet / suit 0.06 < belt (over everything) 0.02 past the singlet
#
# The rules that stand (memory "worn-gear-style", "gear-brand-central", "performance-first"): CENTRAL on every logo, a
# CHUNKY belt, seamless knee sleeves, wraps covering the wrist, no stretched rubber look, a triangle budget.
# Game format (WornGearFit.dressCartoon): per build, skinned pieces "<Worn>_<ColourKey>__<Part>" in one GLB.
#
# Run inside Blender with art/blender/CartoonBodies_02.blend open:
#   exec(open(r"D:\Powerlifting Roblox\art\scripts\build_cartoon_gear_03.py").read())
# Optional before running: ITEMS = ("Belt",) to build only some items; EXPORT = False to skip the GLB/.blend writing.
import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = r"D:\Powerlifting Roblox"
F = {"__name__": "gear_fit_03"}
exec(open(os.path.join(ROOT, "art", "scripts", "gear_fit_03.py")).read(), F)
BUILDS = F["BUILDS"]
OUT_BLEND = os.path.join(ROOT, "art", "blender", "CartoonGear_03.blend")
EXPORTS = os.path.join(ROOT, "art", "exports")
LOGO = os.path.join(ROOT, "art", "logos", "CentralGearLogo_03.png")
COLLECTION = "CartoonGear03"
ALL_ITEMS = ("Belt", "Singlet", "SquatSuit", "DeadliftSuit", "BenchShirt", "KneeSleeves", "KneeWraps",
             "WristWraps", "Tee", "LongSleeve", "Tank", "Shorts", "Joggers", "Sneakers")
ITEMS = globals().get("ITEMS") or ALL_ITEMS
EXPORT = globals().get("EXPORT", True)

U, V = Vector((1, 0, 0)), Vector((0, 1, 0))
FRONT = -math.pi / 2          # the angle (round the vertical axis, from +X) that faces the front (-Y)
BACK = math.pi / 2

# Preview colours (the first item of each kind in ShopConfig; the game colours each piece itself).
PREVIEW = {
    "WornLeverBelt": {"Outer": (0.03, 0.03, 0.035), "Lining": (0.52, 0.02, 0.03), "Stitch": (0.30, 0.30, 0.32),
                      "Lever": (0.62, 0.64, 0.68), "Text": (1, 1, 1)},
    "WornSinglet": {"Black": (0.035, 0.035, 0.04), "Red": (0.55, 0.02, 0.03), "Trim": (0.55, 0.02, 0.03),
                    "Patch": (1, 1, 1), "Shorts": (0.035, 0.035, 0.04), "ShortsRed": (0.55, 0.02, 0.03)},
}

# The logo image's rows (CentralGearLogo_03.png, 1024 x 512): white, black, red, gold CENTRAL; the word spans u .225-.775.
LOGO_ROWS = {"White": 0, "Black": 1, "Red": 2, "Gold": 3}
LOGO_U = (0.225, 0.775)


def log(*a):
    print("[CartoonGear03]", *a)


def material(worn, key):
    name = "Gear03_%s_%s" % (worn, key)
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    rgb = PREVIEW.get(worn, {}).get(key, (0.5, 0.5, 0.5))
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    if key in ("Text", "Patch") and os.path.exists(LOGO):
        # the logo for the pictures (Workbench "Texture" colour shows the active image node)
        img = bpy.data.images.get("CentralGearLogo_03.png") or bpy.data.images.load(LOGO)
        tex = next((n for n in m.node_tree.nodes if n.type == "TEX_IMAGE"), None) or m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = img
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        m.node_tree.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        m.node_tree.nodes.active = tex
        m.blend_method = "CLIP" if hasattr(m, "blend_method") else None
    return m


def mesh_from(name, coll, verts, faces, uvs=None, smooth=True):
    o = F["new_object"](name, coll, verts, faces, smooth)
    if uvs:
        layer = o.data.uv_layers.new(name="UVMap")
        for poly in o.data.polygons:
            for li, vi in zip(poly.loop_indices, poly.vertices):
                layer.data[li].uv = uvs[vi]
    return o


def outward(o, centre_of):
    """Turns every face so it points away from centre_of(face centre) (for closed shells built by hand)."""
    me = o.data
    for p in me.polygons:
        c = p.center
        if p.normal.dot(c - centre_of(c)) < 0:
            p.flip()
    me.update()


# ---------------------------------------------------------------- the belt
BELT_HEIGHT = 0.55
BELT_THICK = 0.12
BELT_CLEAR = 0.02          # over the smoothed outline (the singlet's 0.06 sits under it: the belt goes on top)
BELT_SEGMENTS = 28
# The belt's cross-section (out from its inner face, up from its middle): a flat inner face, rounded bulging edges,
# a stitch channel in from each edge, a flat outer face. Faces 0-1 and 12-13 (the inner part of each edge) and the
# inner face show the suede LINING; the rest is the OUTER leather.
BELT_PROFILE = [(0.000, -0.236), (0.012, -0.268), (0.066, -0.279), (0.116, -0.257), (0.126, -0.215), (0.113, -0.172),
                (0.113, 0.172), (0.126, 0.215), (0.116, 0.257), (0.066, 0.279), (0.012, 0.268), (0.000, 0.236)]
BELT_LINING_FACES = {0, 10, 11}        # profile segments i -> i+1 (11 -> 0 is the inner face)
BELT_STITCH_H = 0.172                  # the stitch rows sit in the channels
LEVER_KEY_RGB = (0.62, 0.64, 0.68)


def belt_shape(body):
    """The belt's inner surface for this build: round a common vertical axis, at each angle a straight line up the belt
    (a stiff band can lean like a cone, never bend in round a groove) as close as it can sit outside the smoothed
    outline over the belt's height. Returns (mid height, axis point, angles, a, b): inner radius at height h from the
    middle = a + b * h."""
    hip, waist = body.joints["LowerTorso"].z, body.landmarks()["waist"]
    mid = hip + 0.625 * (waist - hip)              # 2.69 on today's skeleton: on the hips, over the navel
    rows = body.stack("TorsoHips", mid - 0.30, mid + 0.30, 0.03, (0, 0), n=72, smooth=0)
    axis = Vector((0, sum(r[1].y for r in rows) / len(rows), mid))
    K = 72
    angles = [2 * math.pi * k / K for k in range(K)]
    per_row = []
    for z, c, rs in rows:
        poly = [F["ring_point"](c, U, V, rs, a) - axis for a in angles]
        per_row.append((z - mid, F["radial"]([(p.x, p.y) for p in poly], angles)))
    slopes = [s * 0.02 for s in range(-30, 31)]
    a_of, b_of = [], []
    for k in range(K):
        best = None
        for b in slopes:
            a = max(r[k] - b * h for h, r in per_row)
            cost = sum(a + b * h - r[k] for h, r in per_row)
            if best is None or cost < best[0]:
                best = (cost, a, b)
        a_of.append(best[1])
        b_of.append(best[2])
    # a stiff band: no kinks round the body (moving average of the lean), then pushed back out wherever that let the
    # outline through
    b_s = [sum(b_of[(k + d) % K] for d in range(-4, 5)) / 9 for k in range(K)]
    a_s = [sum(a_of[(k + d) % K] for d in range(-3, 4)) / 7 for k in range(K)]
    a_s = [max(a_s[k], max(r[k] - b_s[k] * h for h, r in per_row)) for k in range(K)]
    return mid, axis, angles, a_s, b_s


def interp(values, angle):
    n = len(values)
    f = (angle / (2 * math.pi)) % 1.0 * n
    i = int(f) % n
    t = f - int(f)
    return values[i] * (1 - t) + values[(i + 1) % n] * t


def belt_point(shape, angle, h, n):
    """A point `n` out from the belt's inner face (perpendicular to it), `h` up from its middle, at `angle`."""
    mid, axis, _angles, a_s, b_s = shape
    a, b = interp(a_s, angle), interp(b_s, angle)
    k = 1.0 / math.sqrt(1 + b * b)
    r = a + b * h + BELT_CLEAR + n * k
    z = mid + h - n * b * k
    d = U * math.cos(angle) + V * math.sin(angle)
    return Vector((axis.x, axis.y, z)) + d * r


def belt_outer_normal(shape, angle):
    d = U * math.cos(angle) + V * math.sin(angle)
    return d


def build_belt(body, coll):
    shape = belt_shape(body)
    mid, axis = shape[0], shape[1]
    centre_of = lambda c: Vector((axis.x, axis.y, c.z))
    pieces = {}
    # the band
    S, P = BELT_SEGMENTS, len(BELT_PROFILE)
    angles = [FRONT + 2 * math.pi * j / S for j in range(S)]
    verts = [belt_point(shape, a, h, n) for a in angles for (n, h) in BELT_PROFILE]
    faces, lining = [], set()
    for j in range(S):
        for i in range(P):
            if i in BELT_LINING_FACES:
                lining.add(len(faces))
            faces.append((j * P + i, j * P + (i + 1) % P, ((j + 1) % S) * P + (i + 1) % P, ((j + 1) % S) * P + i))
    band = mesh_from(body.build + "_BeltBand", coll, verts, faces)
    recalc(band)          # a closed ring: every face turned outward
    for key, keep in (("Outer", lambda i: i not in lining), ("Lining", lambda i: i in lining)):
        o = band.copy()
        o.data = band.data.copy()
        o.name = body.build + "_Belt" + key
        coll.objects.link(o)
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if not keep(f.index)], context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.to_mesh(o.data)
        bm.free()
        pieces[key] = o
    bpy.data.objects.remove(band, do_unlink=True)
    # stitch dashes in the two channels (a raised thread line, 2 triangles each)
    sv, sf = [], []
    for j in range(S):
        a0 = angles[j]
        da = 2 * math.pi / S
        for row in (-BELT_STITCH_H, BELT_STITCH_H):
            for d in (0.2,):          # one dash per segment (performance: two cost 240 triangles)
                lo, hi = a0 + da * d, a0 + da * (d + 0.5)
                base = len(sv)
                for a, h in ((lo, row - 0.008), (hi, row - 0.008), (hi, row + 0.008), (lo, row + 0.008)):
                    sv.append(belt_point(shape, a, h, 0.113 + 0.006))
                sf.append((base, base + 1, base + 2, base + 3))
    o = mesh_from(body.build + "_BeltStitch", coll, sv, sf, smooth=False)
    outward(o, centre_of)
    pieces["Stitch"] = o
    # CENTRAL on the back: a thin curved patch on the outer face (the logo texture; LOGO_ROWS picks the colour row)
    pieces["Text"] = belt_patch(body, shape, coll, centre_of)
    # the steel lever on the front
    pieces["Lever"] = belt_lever(body, shape, coll, centre_of)
    for key, o in pieces.items():
        F["transfer_weights"](o, body, rigid="LowerTorso")
        o.data.materials.append(material("WornLeverBelt", key))
    return pieces


def recalc(o):
    """Turns every face of a closed shell outward."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(o.data)
    bm.free()


def belt_patch(body, shape, coll, centre_of, width=0.66, height=0.17, row="White"):
    axis = shape[1]
    r = interp(shape[3], BACK) + BELT_CLEAR + 0.113
    span = width / r
    cols = 8
    verts, faces, uvs = [], [], []
    u0, u1 = LOGO_U
    v_top = 1 - LOGO_ROWS[row] / 4.0
    v_bot = v_top - 0.25
    for c in range(cols + 1):
        t = c / cols
        # seen from behind, the character's right (-X) is on the viewer's left: the word reads left to right there
        a = BACK + span * (t - 0.5)
        for h, v in ((-height / 2, v_bot), (height / 2, v_top)):
            verts.append(belt_point(shape, a, h, 0.113 + 0.008))
            uvs.append((u0 + (u1 - u0) * t, v))
    for c in range(cols):
        faces.append((c * 2, c * 2 + 2, c * 2 + 3, c * 2 + 1))
    o = mesh_from(body.build + "_BeltText", coll, verts, faces, uvs, smooth=True)
    outward(o, centre_of)
    return o


def slab(name, coll, point_at, cols, rows, thick, centre_of):
    """A curved plate: point_at(u, v, n) (u, v from 0 to 1 across it, n from 0 inner to 1 outer) -> point."""
    verts, faces = [], []
    def idx(layer, c, r):
        return layer * (cols + 1) * (rows + 1) + c * (rows + 1) + r
    for layer in (0, 1):
        for c in range(cols + 1):
            for r in range(rows + 1):
                verts.append(point_at(c / cols, r / rows, layer))
    for c in range(cols):
        for r in range(rows):
            faces.append((idx(1, c, r), idx(1, c + 1, r), idx(1, c + 1, r + 1), idx(1, c, r + 1)))
            faces.append((idx(0, c, r), idx(0, c, r + 1), idx(0, c + 1, r + 1), idx(0, c + 1, r)))
    for c in range(cols):
        faces.append((idx(0, c, 0), idx(0, c + 1, 0), idx(1, c + 1, 0), idx(1, c, 0)))
        faces.append((idx(0, c, rows), idx(1, c, rows), idx(1, c + 1, rows), idx(0, c + 1, rows)))
    for r in range(rows):
        faces.append((idx(0, 0, r), idx(1, 0, r), idx(1, 0, r + 1), idx(0, 0, r + 1)))
        faces.append((idx(0, cols, r), idx(0, cols, r + 1), idx(1, cols, r + 1), idx(1, cols, r)))
    o = mesh_from(name, coll, verts, faces, smooth=False)
    return o


def box(bm, centre, x_axis, y_axis, z_axis, size, bevel=0.0):
    """A (bevelled) box into bm, its axes given (x along, y out, z up)."""
    if x_axis.cross(y_axis).dot(z_axis) < 0:
        y_axis = -y_axis          # keep the frame right-handed, so the cube's faces stay pointing out
    geom = bmesh.ops.create_cube(bm, size=1.0)
    vs = geom["verts"]
    for v in vs:
        p = v.co
        v.co = centre + x_axis * (p.x * size[0]) + y_axis * (p.y * size[1]) + z_axis * (p.z * size[2])
    if bevel:
        edges = list({e for v in vs for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=1, affect="EDGES", clamp_overlap=True)
    return vs


def belt_lever(body, shape, coll, centre_of):
    """A steel lever buckle: a curved base plate on the front, the lever arm standing on it with a pull tab at the top,
    a hinge pin and four rivets."""
    axis, mid = shape[1], shape[0]
    r = interp(shape[3], FRONT) + BELT_CLEAR + 0.113
    half = 0.21 / r
    plate_t = 0.03

    def plate_at(u, v, layer):
        a = FRONT + half * (u * 2 - 1)
        h = -0.19 + 0.38 * v
        return belt_point(shape, a, h, 0.110 + layer * plate_t)
    plate = slab(body.build + "_BeltPlate", coll, plate_at, 4, 2, plate_t, centre_of)
    recalc(plate)
    # lever arm, pin and rivets (bmesh boxes in the front's own frame)
    out = belt_outer_normal(shape, FRONT)
    along = Vector((1, 0, 0))
    up = Vector((0, 0, 1))
    front = belt_point(shape, FRONT, 0.0, 0.110 + plate_t)
    bm = bmesh.new()
    tilt = up + out * 0.10
    tilt.normalize()
    box(bm, front + out * 0.035 + up * 0.01, along, out, tilt, (0.15, 0.06, 0.36), bevel=0.014)
    box(bm, front + out * 0.05 + up * 0.20, along, out, up, (0.19, 0.075, 0.06), bevel=0.014)   # pull tab
    box(bm, front + out * 0.014 - up * 0.15, along, out, up, (0.26, 0.035, 0.04), bevel=0.008)               # hinge pin
    for sx in (-1, 1):
        for sz in (-1, 1):
            a = FRONT + sx * half * 0.78
            p = belt_point(shape, a, sz * 0.14, 0.110 + plate_t)
            box(bm, p + out * 0.008, along, out, up, (0.04, 0.02, 0.04))
    me = bpy.data.meshes.new(body.build + "_BeltLeverArm")
    bm.to_mesh(me)
    bm.free()
    arm = bpy.data.objects.new(me.name, me)
    coll.objects.link(arm)
    for p in arm.data.polygons:
        p.use_smooth = False
    # one object: plate + arm
    bpy.ops.object.select_all(action="DESELECT")
    plate.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = plate
    bpy.ops.object.join()
    plate.name = body.build + "_BeltLever"
    return plate


# ---------------------------------------------------------------- shared garment tools
def angle_for_x(c, rs, x, lo, hi, extra):
    """The angle between lo and hi at which the outline ring's point (extra out) has this x (x runs one way there)."""
    f = lambda a: F["ring_point"](c, U, V, rs, a, extra).x - x
    flo = f(lo)
    for _ in range(40):
        mid = (lo + hi) / 2
        fm = f(mid)
        if (fm > 0) == (flo > 0):
            lo, flo = mid, fm
        else:
            hi = mid
    return (lo + hi) / 2


def arc_path(body, region, origin, a, b, e1, e2, through, count, clear, rays=72):
    """count - 1 points from a to b (both already placed) over the skin, in the plane through `origin` spanned by e1, e2,
    the way that passes the direction angle `through`: rays from origin to the skin, the convex loop round the hits (so
    it bridges a hollow, as a strap lies over a collarbone), `clear` out, blended to meet a and b exactly."""
    def ang(p):
        w = p - origin
        return math.atan2(w.dot(e2), w.dot(e1))
    pa, pb = ang(a), ang(b)
    ccw = (pb - pa) % (2 * math.pi)
    sweep = ccw if (through - pa) % (2 * math.pi) < ccw else ccw - 2 * math.pi
    pts = [(0.0, 0.0)]
    for i in range(rays + 1):
        phi = pa + sweep * (-0.15 + 1.3 * i / rays)
        hit = body.hit(region, origin, e1 * math.cos(phi) + e2 * math.sin(phi))
        if hit is not None:
            w = hit - origin
            pts.append((w.dot(e1), w.dot(e2)))
    hull = F["hull_2d"](pts)

    def place(phi):
        r = F["radial"](hull, [phi])[0]
        return origin + (e1 * math.cos(phi) + e2 * math.sin(phi)) * (r + clear)
    ca, cb = a - place(pa), b - place(pb)
    return [place(pa + sweep * i / count) + ca * (1 - i / count) + cb * (i / count) for i in range(1, count)]


class Garment:
    """Points, quads and a colour key per quad, built up piece by piece, then made into one object."""

    def __init__(self):
        self.verts, self.faces, self.keys = [], [], []

    def add(self, p):
        self.verts.append(p)
        return len(self.verts) - 1

    def quad(self, a, b, c, d, key):
        self.faces.append((a, b, c, d))
        self.keys.append(key)

    def build(self, name, coll, axis_y=0.0):
        """One object, every face turned to point away from the body's vertical axis."""
        o = F["new_object"](name, coll, self.verts, self.faces)
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")   # cut-away points
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.normal_update()
        # each separate piece (a torso, a leg's tube, an arm's wrap) faces away from its own middle line
        seen = set()
        for start in bm.faces:
            if start.index in seen:
                continue
            island, stack = [], [start]
            seen.add(start.index)
            while stack:
                f = stack.pop()
                island.append(f)
                for e in f.edges:
                    for g in e.link_faces:
                        if g.index not in seen:
                            seen.add(g.index)
                            stack.append(g)
            vs = {v for f in island for v in f.verts}
            cx = sum(v.co.x for v in vs) / len(vs)
            cy = sum(v.co.y for v in vs) / len(vs)
            score = sum(f.normal.dot(Vector((f.calc_center_median().x - cx, f.calc_center_median().y - cy, 0)))
                        * f.calc_area() for f in island)
            if score < 0:
                bmesh.ops.reverse_faces(bm, faces=island)
        bm.to_mesh(o.data)
        bm.free()
        o["keys"] = list(self.keys)
        return o


def lip(o, depth, roll, key="Trim"):
    """Every open edge becomes a thick hem: the edge is rolled out a little and folded in toward the body by `depth`
    (less than the garment's clearance, so the fold never enters the skin). The fold's faces get `key`."""
    keys = list(o["keys"])
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.normal_update()
    deform = bm.verts.layers.deform.active
    edges = [e for e in bm.edges if e.is_boundary]
    rim = {v for e in edges for v in e.verts}
    normal = {v: v.normal.copy() for v in rim}
    partner = {}
    for v in rim:
        p = bm.verts.new(v.co - normal[v] * depth)
        if deform is not None:
            for k, w in v[deform].items():
                p[deform][k] = w
        partner[v] = p
    for v in rim:
        v.co += normal[v] * roll
    for e in edges:
        a, b = e.verts
        f = e.link_faces[0]
        # keep the fold's winding the same as the face it hangs from (so it faces outward from the fold)
        loop = next(l for l in f.loops if l.edge == e)
        a, b = (loop.vert, loop.link_loop_next.vert)
        try:
            bm.faces.new((b, a, partner[a], partner[b]))
            keys.append(key)
        except ValueError:
            pass
    bm.to_mesh(o.data)
    bm.free()
    o["keys"] = keys


def keep_normals(o):
    me = o.data
    attr = me.attributes.get("gearNormal") or me.attributes.new("gearNormal", "FLOAT_VECTOR", "POINT")
    for i, v in enumerate(me.vertices):
        attr.data[i].vector = v.normal


def split_keys(o, coll, prefix):
    """One object per colour key (copies keep the whole garment's weights and smooth shading)."""
    me = o.data
    # the whole garment's smooth normals, carried as a point attribute through every cut (custom normals set before
    # cutting were re-based on each piece's own faces: shading jumps at every cut); split_parts applies them at the end
    keep_normals(o)
    keys = list(o["keys"])
    out = {}
    for key in sorted(set(keys)):
        c = o.copy()
        c.data = me.copy()
        c.name = "%s_%s" % (prefix, key)
        coll.objects.link(c)
        bm = bmesh.new()
        bm.from_mesh(c.data)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if keys[f.index] != key], context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.to_mesh(c.data)
        bm.free()
        del c["keys"]
        out[key] = c
    bpy.data.objects.remove(o, do_unlink=True)
    return out


def front_patch(body, coll, target, name, z, width, height, row="White", cols=12, lift=0.02, side="front", uv=True):
    """A logo patch laid on a garment's front or back (rays straight in onto `target`), `lift` out, UV-mapped to a row
    of the CENTRAL image (uv=False: a plain label box behind a logo)."""
    from mathutils.bvhtree import BVHTree
    me = target.data
    tree = BVHTree.FromPolygons([v.co for v in me.vertices], [tuple(p.vertices) for p in me.polygons])
    s = -1.0 if side == "front" else 1.0         # which way is out
    verts, faces, uvs = [], [], []
    u0, u1 = LOGO_U
    v_top = 1 - LOGO_ROWS[row] / 4.0
    for c in range(cols + 1):
        t = c / cols
        # seen from the front the character's right (-X) is on the viewer's left; from behind, the left (+X)
        x = (-width / 2 + width * t) * (1 if side == "front" else -1)
        for h, v in ((-height / 2, v_top - 0.25), (height / 2, v_top)):
            loc, nrm, _i, _d = tree.ray_cast(Vector((x, s * 5.0, z + h)), Vector((0, -s, 0)), 10.0)
            if loc is None:
                loc, nrm = Vector((x, s * 0.5, z + h)), Vector((0, s, 0))
            if nrm.y * s < 0:
                nrm = -nrm
            verts.append(loc + nrm * lift)
            uvs.append((u0 + (u1 - u0) * t, v))
    for c in range(cols):
        faces.append((c * 2, c * 2 + 2, c * 2 + 3, c * 2 + 1))
    o = mesh_from(name, coll, verts, faces, uvs if uv else None, smooth=True)
    outward(o, lambda p: Vector((0, 0, p.z)))
    return o


# ---------------------------------------------------------------- the singlet family (singlet, suits, tank top)
TRIM = 0.035               # the width of a trim band along an edge
HEAD_HALF = 0.6            # half the width of a default Roblox head (ClothesConfig HeadScale 1)
SINGLET = {
    "worn": "WornSinglet", "clear": 0.06, "cols": 32, "rows": 10, "strapWidth": 0.24, "strapGap": 0.06,
    "strapBase": 0.22, "neckFront": 0.42, "neckBack": 0.26, "armholeDrop": 0.14, "panelDeg": 26,
    "legs": {"length": 0.32, "rows": 3, "gusset": 5, "stripeDeg": 18}, "patch": ("Patch", "White"),
    "keys": {"body": "Black", "panel": "Red", "trim": "Trim", "legs": "Shorts", "stripe": "ShortsRed"},
}


def band_heights(lo, hi, rows, bottom=None, top=None):
    """Row heights from lo to hi: (kind, z) with `rows` even rows between an optional band at each end, each
    (height, "trim" | "band"): kind "b" bottom band, "m" middle, "t" top band."""
    hs = []
    start = lo
    if bottom:
        hs.append(("b", lo))
        start = lo + bottom[0]
    stop = hi - (top[0] if top else 0.0)
    for j in range(rows):
        hs.append(("m", start + (stop - start) * j / max(1, rows - 1)))
    if top:
        if top[1] == "trim":
            hs.append(("t", hi))
        else:
            hs += [("t", stop), ("t", stop + top[0] * 0.5), ("t", hi)]
    return hs


def add_legs(G, body, spec, grid, cols, index, z_bot, cl, keys):
    """Legs joined under the crotch: each leg's top loop = the torso's bottom points on its side + a gusset seam
    under the crotch (shared by both legs), then rings round the thigh down to the leg opening."""
    m = body.landmarks()
    legs = spec["legs"]
    K = len(cols)
    kF, kB = index[round(FRONT, 9)], index[round(BACK, 9)]
    F0, B0 = G.verts[grid[kF][0]], G.verts[grid[kB][0]]
    origin = Vector((0, (F0.y + B0.y) / 2, z_bot + 0.06))
    J = legs["gusset"]
    gus = [G.add(p) for p in arc_path(body, "TorsoHips", origin, F0, B0, Vector((0, -1, 0)), Vector((0, 0, 1)),
                                      -math.pi / 2, J + 1, cl)]
    z_le = legs["end"](m) if "end" in legs else m["crotch"] - legs["length"]
    alpha = 35.0
    cuff = legs.get("cuff")              # (height, out, key): a raised cuff band at the opening
    for side, sx in (("Left", 1), ("Right", -1)):
        thigh = body.stack(side + "Leg", z_le - 0.03, z_bot, 0.03, (sx * 0.5, 0), n=96, smooth=2)
        if sx > 0:
            outer = [k for k in range(K) if cols[k] <= BACK + 1e-9]
            loop0 = [grid[k][0] for k in outer] + list(reversed(gus))
            phis = [-90 - alpha + (math.degrees(cols[k]) + 90) * (180 + 2 * alpha) / 180 for k in outer]
            phis += [90 + alpha + (180 - 2 * alpha) * (i + 1) / (J + 1) for i in range(J)]
        else:
            outer = [k for k in range(K) if cols[k] >= BACK - 1e-9] + [kF]
            loop0 = [grid[k][0] for k in outer] + gus

            def phi_r(a):
                t = 180 - math.degrees(a)
                return 180 - (-90 - alpha + (t + 90) * (180 + 2 * alpha) / 180)
            phis = [phi_r(cols[k] if k != kF else FRONT + 2 * math.pi) for k in outer]
            phis += [270 + alpha + (180 - 2 * alpha) * (i + 1) / (J + 1) for i in range(J)]
        LR = legs["rows"]
        top_z = z_bot - 0.07
        bottom_z = z_le + (cuff[0] if cuff else TRIM)
        rows = [(top_z + (bottom_z - top_z) * r / max(1, LR - 1), cl, "legs") for r in range(LR)]
        if cuff:
            ch, cout, ckey = cuff
            rows += [(z_le + ch, cl + cout, ckey), (z_le + ch * 0.5, cl + cout * 0.75, ckey), (z_le, cl + cout, ckey)]
        else:
            rows += [(z_le, cl, "trim")]
        prev = loop0
        outer_dir = 0.0 if sx > 0 else 180.0
        for z, c_l, kind in rows:
            c, rs = F["stack_at"](thigh, z)
            cur = [G.add(F["ring_point"](c, U, V, rs, math.radians(p), c_l)) for p in phis]
            for i in range(len(cur)):
                i2 = (i + 1) % len(cur)
                pm = (phis[i] + (phis[i2] if i2 else phis[0] + 360)) / 2
                d = abs((pm - outer_dir + 180) % 360 - 180)
                if kind == "trim":
                    key = keys["trim"]
                elif kind != "legs":
                    key = kind
                elif d < legs.get("stripeDeg", -1):
                    key = keys["stripe"]
                else:
                    key = keys["legs"]
                G.quad(prev[i], prev[i2], cur[i2], cur[i], key)
            prev = cur
    return z_le


def finish(G, body, coll, spec, axis_y, patch=None):
    """Points out of the skin, hems, the body's weights, room where the poses need it, one object per colour key,
    a logo patch, preview materials."""
    cl, keys = spec["clear"], spec["keys"]
    name = body.build + "_" + spec["worn"]
    o = G.build(name, coll, axis_y=axis_y)
    F["push_clear"](o, body, cl * 0.7)        # wherever the skin bulges between outline samples
    lip(o, max(0.01, cl - 0.015), 0.012, keys["trim"])
    F["push_clear"](o, body, min(0.012, cl * 0.4))   # the hems' inward folds too
    F["transfer_weights"](o, body)            # exact skin weights: smoothing made the fabric lag (more clips)
    relief = F["pose_relief"](o, body)       # room only where a pose pushes the skin through
    log(body.build, spec["worn"], "pose relief up to %.3f" % relief)
    pieces = split_keys(o, coll, name)
    for extra in spec.get("extras", ()):
        extra(body, coll, pieces, spec)
    if spec.get("patch") and patch:
        key, row = spec["patch"][:2]
        side, z = patch
        target = pieces[keys["body"]]
        pieces[key] = front_patch(body, coll, target, name + "Patch", z, 0.44, 0.115, row, side=side)
        F["transfer_weights"](pieces[key], body)
        if len(spec["patch"]) > 2:           # a label box behind the logo
            pieces[spec["patch"][2]] = front_patch(body, coll, target, name + "Label", z, 0.54, 0.17, row, side=side,
                                                   lift=0.012, uv=False)
            F["transfer_weights"](pieces[spec["patch"][2]], body)
    for key, p in pieces.items():
        p.data.materials.clear()
        p.data.materials.append(material(spec["worn"], key))
    return pieces


def torso_garment(body, coll, spec):
    """The singlet family from a master pattern `spec`: front and back panels, side panels, and either two straps
    over the shoulders with a scoop neck and armholes (singlet, suits, tank) or a flat top edge (shorts, joggers);
    optionally legs joined under the crotch by a gusset; every edge a rolled hem with a trim band (or a raised band).
    Fitted to this build's smoothed outline at spec clearance. Returns {colour key: object} (weighted, unsplit)."""
    m = body.landmarks()
    cl, keys = spec["clear"], spec["keys"]
    armpit = m["armpit"]
    flat = spec.get("flatTop")
    z_s0 = flat(m) if flat else armpit + spec["strapBase"]
    legs = spec.get("legs")
    z_bot = m["crotch"] + 0.05 if legs else spec["hem"](m)
    rows_t = body.stack(body.torso_region, z_bot - 0.02, z_s0 + 0.02, 0.03, (0, 0), n=96, smooth=3)
    ring = lambda z: F["stack_at"](rows_t, z)
    c0, rs0 = ring(z_s0)
    A = lambda a: (a - FRONT) % (2 * math.pi) + FRONT          # angles kept in [FRONT, FRONT + 2 pi)
    straps = {}
    if not flat:
        # straps: the inner edge clear of the head (the player's own Roblox head, 1.2 wide, sits on the neck), never
        # out past the arm's middle line
        x_si = HEAD_HALF + spec["strapGap"]
        x_so = min(x_si + spec["strapWidth"], m["armX"] - 0.05)
        strap_x = [x_si, x_si + TRIM, x_so - TRIM, x_so]
        for side, sx in (("L", 1), ("R", -1)):
            for face, (lo, hi) in (("F", (-math.pi / 2, 0.0) if sx > 0 else (-math.pi / 2, -math.pi)),
                                   ("B", (math.pi / 2, 0.0) if sx > 0 else (math.pi / 2, math.pi))):
                straps[(side, face)] = [A(angle_for_x(c0, rs0, sx * x, lo, hi, cl)) for x in strap_x]
    strap_angles = sorted({a for v in straps.values() for a in v})
    step = 2 * math.pi / spec["cols"]
    base = [FRONT + step * k for k in range(spec["cols"])]
    keep = [a for a in base if abs(a - FRONT) < 1e-9 or abs(a - BACK) < 1e-9 or
            all(abs(a - s) > 0.45 * step for s in strap_angles)]
    cols = sorted(set(round(a, 9) for a in keep + strap_angles))

    def in_range(a, lo, hi):
        lo, hi = min(lo, hi), max(lo, hi)
        return lo - 1e-9 <= a <= hi + 1e-9

    def circ(a, b):
        d = (a - b) % (2 * math.pi)
        return min(d, 2 * math.pi - d)
    z_nf = z_nb = z_ah = z_s0
    if not flat:
        z_nf, z_nb, z_ah = z_s0 - spec["neckFront"], z_s0 - spec["neckBack"], armpit - spec["armholeDrop"]

    def top_of(a):
        if flat:
            return z_s0, "edge"
        for (side, face), angs in straps.items():
            if in_range(a, angs[0], angs[-1]):
                return z_s0, "strap"
        for centre, face, low in ((FRONT, "F", z_nf), (BACK, "B", z_nb)):
            half = max(circ(straps[("L", face)][0], centre), circ(straps[("R", face)][0], centre))
            d = circ(a, centre)
            if d <= half:
                return low + (z_s0 - low) * (d / half) ** 2, "neck"
        for side in ("L", "R"):
            lo, hi = straps[(side, "F")][-1], straps[(side, "B")][-1]
            if side == "L":
                hi = hi + (2 * math.pi if hi < lo else 0)
                aa = a if a >= lo else a + 2 * math.pi
            else:
                lo, hi = hi, lo
                aa = a
            if in_range(aa, lo, hi):
                mid, half = (lo + hi) / 2, (hi - lo) / 2
                return z_ah + (z_s0 - z_ah) * (abs(aa - mid) / half) ** 2.6, "armhole"
        return z_s0, "strap"
    G = Garment()
    grid, tops, kinds = [], [], None
    top_band = spec.get("topBand")             # (height, out, key): a raised band round a flat top (a waistband)
    for a in cols:
        zt, kind = top_of(a)
        tops.append(kind)
        hs = band_heights(z_bot, zt, spec["rows"], bottom=None if legs else (TRIM, "trim"),
                          top=(top_band[0], "band") if top_band else (TRIM, "trim"))
        kinds = [h[0] for h in hs]
        col = []
        for i, (kd, z) in enumerate(hs):
            c, rs = ring(z)
            out = cl
            if top_band and kd == "t":
                out = cl + top_band[1] * (0.75 if i == len(hs) - 2 else 1.0)
            col.append(G.add(F["ring_point"](c, U, V, rs, a, out)))
        grid.append(col)
    K = len(cols)
    nrows = len(grid[0])

    def panel_key(a):
        side = min(abs(math.atan2(math.sin(a), math.cos(a))), abs(math.pi - abs(math.atan2(math.sin(a), math.cos(a)))))
        return keys["panel"] if math.degrees(side) < spec.get("panelDeg", -1) else keys["body"]
    for k in range(K):
        k2 = (k + 1) % K
        amid = (cols[k] + (cols[k2] if k2 else cols[0] + 2 * math.pi)) / 2
        for j in range(nrows - 1):
            if top_band and kinds[j + 1] == "t":
                key = top_band[2]
            elif j == nrows - 2 and not (tops[k] == "strap" and tops[k2] == "strap"):
                key = keys["trim"]
            elif (not legs) and j == 0:
                key = keys["trim"]
            else:
                key = panel_key(amid)
            G.quad(grid[k][j], grid[k2][j], grid[k2][j + 1], grid[k][j + 1], key)
    index = {round(a, 9): k for k, a in enumerate(cols)}
    if not flat:
        # straps over the shoulders: each strap column from its front top point over the skin to the matching back one
        M = 8
        for side in ("L", "R"):
            front = [index[round(a, 9)] for a in straps[(side, "F")]]
            back = [index[round(a, 9)] for a in straps[(side, "B")]]
            lines = []
            for kf, kb in zip(front, back):
                pa, pb = G.verts[grid[kf][-1]], G.verts[grid[kb][-1]]
                origin = Vector((pa.x, (pa.y + pb.y) / 2, z_s0 - 0.1))
                mids = arc_path(body, "All", origin, pa, pb, Vector((0, -1, 0)), Vector((0, 0, 1)), math.pi / 2, M, cl)
                lines.append([grid[kf][-1]] + [G.add(p) for p in mids] + [grid[kb][-1]])
            for c in range(len(lines) - 1):
                key = keys["trim"] if c in (0, len(lines) - 2) else keys.get("strap", keys["body"])
                for i in range(M):
                    G.quad(lines[c][i], lines[c + 1][i], lines[c + 1][i + 1], lines[c][i + 1], key)
    if legs:
        add_legs(G, body, spec, grid, cols, index, z_bot, cl, keys)
    patch = None
    if spec.get("patch"):
        patch = ("front", z_nf - 0.2) if not flat else ("front", z_s0 - 0.3)
    return finish(G, body, coll, spec, c0.y, patch)


def build_singlet(body, coll):
    return torso_garment(body, coll, SINGLET)


SQUAT_SUIT = dict(SINGLET, worn="WornSquatSuit", clear=0.055, strapWidth=0.36, strapGap=0.04, neckFront=0.30,
                  neckBack=0.18, armholeDrop=0.08, panelDeg=34,
                  legs={"length": 0.22, "rows": 3, "gusset": 5, "stripeDeg": 22},
                  patch=("Patch", "White", "Label"),
                  keys={"body": "Body", "panel": "Panel", "trim": "Trim", "legs": "Body", "stripe": "Panel"})
DEADLIFT_SUIT = dict(SQUAT_SUIT, worn="WornDeadliftSuit", strapWidth=0.34, neckFront=0.34,
                     legs={"length": 0.18, "rows": 3, "gusset": 5, "stripeDeg": 22})
PREVIEW["WornSquatSuit"] = {"Body": (0.45, 0.04, 0.06), "Panel": (0.08, 0.08, 0.09), "Trim": (0.08, 0.08, 0.09),
                            "Label": (0.08, 0.08, 0.09), "Patch": (0.85, 0.82, 0.7)}
PREVIEW["WornDeadliftSuit"] = {"Body": (0.2, 0.08, 0.42), "Panel": (0.08, 0.08, 0.09), "Trim": (0.08, 0.08, 0.09),
                               "Label": (0.08, 0.08, 0.09), "Patch": (0.85, 0.82, 0.7)}


# ---------------------------------------------------------------- sleeved shirts (bench shirt, tee, long sleeve)
def shirt_garment(body, coll, spec):
    """A shirt with set-in sleeves from a master pattern. The body panel goes up to the chest and upper back; the
    whole top (the yoke) is made of front-to-back ARCS over the skin, from the middle out to each arm's outer side (so
    it goes over big traps, not round them), with a round neck hole cut out where the head sits; each sleeve is a
    tube round the arm whose top joins the body along an armpit seam (the body's side and the sleeve's inner side meet
    in one seam line) and the yoke over the shoulder. Hem, neck and sleeve ends hemmed; optional raised cuffs."""
    m = body.landmarks()
    cl, keys = spec["clear"], spec["keys"]
    armpit = m["armpit"]
    z_ap = armpit - 0.03
    z_s0 = armpit + spec["yokeBase"]
    z_bot = spec["hem"](m)
    rows_t = body.stack(body.torso_region, z_bot - 0.02, z_s0 + 0.02, 0.03, (0, 0), n=96, smooth=3)
    ring = lambda z: F["stack_at"](rows_t, z)
    c_ap, rs_ap = ring(z_ap)
    c_s0, rs_s0 = ring(z_s0)
    max_x = max(F["ring_point"](c_ap, U, V, rs_ap, a, cl).x for a in [FRONT + k * math.pi / 64 for k in range(33)])
    th_fl = angle_for_x(c_ap, rs_ap, max_x - 0.10, -math.pi / 2, 0.0, cl)                 # the front of the armpit
    th_si = angle_for_x(c_s0, rs_s0, HEAD_HALF + spec["neckGap"], -math.pi / 2, 0.0, cl)  # above the neck's side
    th_si = min(th_si, th_fl - 0.15)
    segs = spec["segments"]              # (middle, shoulder, side) segments per quadrant
    q = []
    q += [FRONT + (th_si - FRONT) * i / segs[0] for i in range(segs[0])]
    q += [th_si + (th_fl - th_si) * i / segs[1] for i in range(segs[1])]
    q += [th_fl + (0.0 - th_fl) * i / segs[2] for i in range(segs[2])]
    A = lambda a: (a - FRONT) % (2 * math.pi) + FRONT
    cols = sorted(set(round(A(x), 9) for a in q for x in (a, -a, math.pi - a, math.pi + a)))
    K = len(cols)

    def col_of(a):
        """The column nearest to angle a (mirrored angles can differ in the last digits)."""
        a = A(a)
        return min(range(K), key=lambda k: min(abs(cols[k] - a), 2 * math.pi - abs(cols[k] - a)))

    def fold(a):
        """(region, u, face) of a column, seen from the left-front quadrant: "top" columns rise into the yoke arcs
        (u: 0 in the middle .. 1 at the front of the armpit), "side" columns stop at the armpit seam."""
        x = math.atan2(math.sin(a), math.cos(a))
        lf = -abs(x) if abs(x) <= math.pi / 2 else -(math.pi - abs(x))
        face = "F" if math.sin(a) < -1e-9 else "B"
        if lf <= th_fl + 1e-7:
            return "top", max(0.0, (lf - th_si) / (th_fl - th_si)), face
        return "side", (lf - th_fl) / (0.0 - th_fl), face
    G = Garment()
    grid, info = [], []
    for a in cols:
        reg, u, face = fold(a)
        zt = z_s0 + (z_ap - z_s0) * u ** 1.3 if reg == "top" else z_ap
        info.append((reg, u, face))
        hs = band_heights(z_bot, zt, spec["rows"], bottom=(TRIM, "trim"), top=None)
        col = []
        for kd, z in hs:
            c, rs = ring(z)
            col.append(G.add(F["ring_point"](c, U, V, rs, a, cl)))
        grid.append(col)
    nrows = len(grid[0])

    def panel_key(a):
        side = min(abs(math.atan2(math.sin(a), math.cos(a))), abs(math.pi - abs(math.atan2(math.sin(a), math.cos(a)))))
        return keys["panel"] if math.degrees(side) < spec.get("panelDeg", -1) else keys["body"]
    for k in range(K):
        k2 = (k + 1) % K
        amid = (cols[k] + (cols[k2] if k2 else cols[0] + 2 * math.pi)) / 2
        for j in range(nrows - 1):
            key = keys["trim"] if j == 0 else panel_key(amid)
            G.quad(grid[k][j], grid[k2][j], grid[k2][j + 1], grid[k][j + 1], key)
    Mo = 8                                   # sleeve points round the outside of the arm (even)
    N_ARC = spec.get("arcSegments", 10)
    z_end = spec["sleeveEnd"](m)
    cuff = spec.get("cuff")
    outers = {}
    for side, sx in (("L", 1), ("R", -1)):
        k_front = col_of(th_fl if sx > 0 else math.pi - th_fl)
        k_back = col_of(-th_fl if sx > 0 else math.pi + th_fl)
        side_cols = sorted([k for k in range(K) if info[k][0] == "side" and math.cos(cols[k]) * sx > 0],
                           key=lambda k: math.sin(cols[k]))           # front to back
        S = len(side_cols)
        arm = body.stack(("Left" if sx > 0 else "Right") + "Arm", z_end - 0.03, z_ap, 0.03, (sx * m["armX"], 0),
                         n=96, smooth=2)
        ca, ra = F["stack_at"](arm, z_ap)
        phi_o = [-110 + 220 * (j + 1) / (Mo + 1) for j in range(Mo)]
        phi_s = [110 + 140 * (i + 1) / (S + 1) for i in range(S)]          # back -> inner -> front
        mirror = (lambda p: p) if sx > 0 else (lambda p: 180 - p)
        outer = [G.add(F["ring_point"](ca, U, V, ra, math.radians(mirror(p)), cl)) for p in phi_o]
        seam = []
        for i, k in enumerate(reversed(side_cols)):
            p_t = G.verts[grid[k][-1]]
            p_a = F["ring_point"](ca, U, V, ra, math.radians(mirror(phi_s[i])), cl)
            G.verts[grid[k][-1]] = (p_t + p_a) / 2          # the seam: halfway between body side and inner arm
            seam.append(grid[k][-1])
        loop = [grid[k_front][-1]] + outer + [grid[k_back][-1]] + seam
        phis = [mirror(p) for p in [-110] + phi_o + [110] + phi_s]
        if cuff:
            ch, cout, ckey = cuff
            rows = [(z_end, cl + cout, ckey), (z_end + ch * 0.5, cl + cout * 0.75, ckey), (z_end + ch, cl + cout, ckey)]
            lo = z_end + ch
            rows.append((lo, cl, "sleeve"))
        else:
            rows = [(z_end, cl, "trim")]
            lo = z_end + TRIM
            rows.append((lo, cl, "trim"))
        hi = z_ap - 0.07
        n_mid = spec["sleeveRows"]
        for r in range(1, n_mid + 1):
            rows.append((lo + (hi - lo) * r / n_mid, cl, "sleeve"))
        prev, prev_kind = None, None
        for z, c_l, kind in rows:
            c, rs = F["stack_at"](arm, z)
            cur = [G.add(F["ring_point"](c, U, V, rs, math.radians(p), c_l)) for p in phis]
            if prev is not None:
                if kind == "trim" and prev_kind == "trim":
                    key = keys["trim"]
                elif kind not in ("sleeve", "trim"):
                    key = kind
                elif prev_kind not in ("sleeve", "trim", None):
                    key = prev_kind
                else:
                    key = keys["sleeve"]
                for i in range(len(cur)):
                    i2 = (i + 1) % len(cur)
                    G.quad(prev[i], prev[i2], cur[i2], cur[i], key)
            prev, prev_kind = cur, kind
        for i in range(len(loop)):
            i2 = (i + 1) % len(loop)
            G.quad(prev[i], prev[i2], loop[i2], loop[i], keys["sleeve"])
        outers[side] = (outer, ca, k_front)
    # the yoke: arcs front to back, ordered right arm .. middle .. left arm; points spaced evenly along each arc; the
    # arcs that pass where the head sits stop on a round neck line (a front half and a back half)
    pairs = []          # (front vertex, back vertex, arm centre or None)
    for j in range(Mo // 2):                          # right arm, outermost first
        outer, ca, _k = outers["R"]
        jj = Mo // 2 - 1 - j
        pairs.append((outer[jj], outer[Mo - 1 - jj], ca))
    fronts = sorted([k for k in range(K) if info[k][0] == "top" and info[k][2] == "F"], key=lambda k: math.cos(cols[k]))
    for k in fronts:                                  # right shoulder .. middle .. left shoulder
        pairs.append((grid[k][-1], grid[col_of(-cols[k])][-1], None))
    for j in range(Mo // 2):                          # left arm, innermost first
        outer, ca, _k = outers["L"]
        pairs.append((outer[j], outer[Mo - 1 - j], ca))
    # the neck hole: the build's own neck just under the head (Roblox's head is wider than a skinny neck), never
    # tighter than a skinny neck or wider than the head
    z_n = m["neckRim"] - 0.30                 # just under where the head sits (found on the skin, not a number)
    probe = Vector((0, 0, z_n))
    hx = body.hit("All", probe, Vector((1, 0, 0)))
    hf, hb = body.hit("All", probe, Vector((0, -1, 0))), body.hit("All", probe, Vector((0, 1, 0)))
    rx = min(HEAD_HALF + 0.05, max(0.40, (hx.x if hx else 0.45) + spec["neckGap"]))
    cy = ((hf.y if hf else -0.3) + (hb.y if hb else 0.3)) / 2
    depth = ((hb.y if hb else 0.3) - (hf.y if hf else -0.3)) / 2
    ry_f = ry_b = depth + spec["neckGap"]
    drop = spec.get("neckFrontDrop", 0.10)      # the front of the neckline lower, along the chest (a U, deepest in front)

    def trim_end(poly, length):
        """The polyline with `length` cut off its end."""
        if length <= 1e-6:
            return poly
        out = list(poly)
        while len(out) > 2 and length > 0:
            seg = (out[-1] - out[-2]).length
            if seg > length:
                out[-1] = out[-1].lerp(out[-2], length / seg)
                return out
            length -= seg
            out.pop()
        return out
    half = N_ARC // 2

    def resample(poly, n, last=None):
        """n segments evenly along a polyline (the final one `last` long when given)."""
        lens = [0.0]
        for p, q2 in zip(poly, poly[1:]):
            lens.append(lens[-1] + (q2 - p).length)
        total = lens[-1]
        if last:
            marks = [(total - last) * i / (n - 1) for i in range(n)] + [total]
        else:
            marks = [total * i / n for i in range(n + 1)]
        out, j = [], 0
        for t in marks:
            while j < len(lens) - 2 and lens[j + 1] < t:
                j += 1
            seg = max(1e-9, lens[j + 1] - lens[j])
            out.append(poly[j].lerp(poly[j + 1], min(1.0, max(0.0, (t - lens[j]) / seg))))
        return out

    def cross(poly, y_target, from_front):
        """The point where the polyline crosses y = y_target, and the polyline cut there (front part or back part)."""
        for i in range(len(poly) - 1):
            p, q2 = poly[i], poly[i + 1]
            if (p.y - y_target) * (q2.y - y_target) <= 0 and abs(q2.y - p.y) > 1e-9:
                pt = p.lerp(q2, (y_target - p.y) / (q2.y - p.y))
                return (poly[:i + 1] + [pt]) if from_front else ([pt] + poly[i + 1:])
        return None
    arcs = []           # each: ("full", [N_ARC + 1 indices]) or ("split", front [half + 1], back [half + 1])
    # which arcs may split: a run outward from the middle on each side (one full arc in between would put a spike in
    # the neckline)
    mid_i = min(range(len(pairs)), key=lambda i: abs(G.verts[pairs[i][0]].x))
    may_split = set()
    for direction in (-1, 1):
        i = mid_i
        while 0 <= i < len(pairs) and pairs[i][2] is None and abs(G.verts[pairs[i][0]].x) < rx * 0.92:
            may_split.add(i)
            i += direction
    for ai, (va, vb, ca) in enumerate(pairs):
        pa, pb = G.verts[va], G.verts[vb]
        if ca is not None:
            ox, oz = ca.x + (pa.x - ca.x) * 0.5, z_ap - 0.15
        else:
            ox, oz = pa.x, min(pa.z, pb.z) - 0.15
        origin = Vector((ox, (pa.y + pb.y) / 2, oz))
        dense = [pa] + arc_path(body, "All", origin, pa, pb, Vector((0, -1, 0)), Vector((0, 0, 1)), math.pi / 2, 48,
                                cl) + [pb]
        x = (pa.x + pb.x) / 2
        if ai in may_split:
            k = math.sqrt(1 - (x / rx) ** 2)
            # (on a shallow chest the neck can be deeper than the arc's ends: the hole stops just inside them)
            front = cross(dense, cy - min(ry_f * k, cy - pa.y - 0.03), True)
            back = cross(dense, cy + min(ry_b * k, pb.y - cy - 0.03), False)
            if front:
                front = trim_end(front, drop * k * k)
            if front and back and front[-1].z > z_s0 - 0.05:
                fp = resample(front, half, last=TRIM)
                bp = resample(back, half, last=None)
                bp = resample(list(reversed(back)), half, last=TRIM)[::-1]
                arcs.append(("split", [va] + [G.add(p) for p in fp[1:]], [G.add(p) for p in bp[:-1]] + [vb]))
                continue
        pts = resample(dense, N_ARC)
        arcs.append(("full", [va] + [G.add(p) for p in pts[1:-1]] + [vb]))
    key_s, key_t = keys["sleeve"], keys["trim"]
    for c in range(len(arcs) - 1):
        A0, A1 = arcs[c], arcs[c + 1]
        if A0[0] == "full" and A1[0] == "full":
            for i in range(N_ARC):
                G.quad(A0[1][i], A1[1][i], A1[1][i + 1], A0[1][i + 1], key_s)
        elif A0[0] == "split" and A1[0] == "split":
            for part in (1, 2):
                a, b = A0[part], A1[part]
                for i in range(half):
                    at_neck = (part == 1 and i == half - 1) or (part == 2 and i == 0)
                    G.quad(a[i], b[i], b[i + 1], a[i + 1], key_t if at_neck else key_s)
        else:
            sp, fu = (A0, A1) if A0[0] == "split" else (A1, A0)
            flip = A0[0] != "split"
            f, b, u = sp[1], sp[2], fu[1]
            def q4(p1, p2, p3, p4, key):
                if flip:
                    G.quad(p2, p1, p4, p3, key)
                else:
                    G.quad(p1, p2, p3, p4, key)
            for i in range(half):
                q4(f[i], u[i], u[i + 1], f[i + 1], key_t if i == half - 1 else key_s)
                q4(b[i], u[half + i], u[half + i + 1], b[i + 1], key_t if i == 0 else key_s)
            tri = (f[half], u[half], b[0]) if not flip else (u[half], f[half], b[0])
            G.faces.append(tri)
            G.keys.append(key_t)
    for kind_last in (arcs[0], arcs[-1]):             # close the shoulder's outer end
        last = kind_last[1]
        for kk in range(N_ARC // 2):
            a0, a1, b1, b0 = last[kk], last[kk + 1], last[N_ARC - kk - 1], last[N_ARC - kk]
            if a1 == b1:
                G.faces.append((a0, a1, b0))
                G.keys.append(key_s)
            else:
                G.quad(a0, a1, b1, b0, key_s)
    # drop the points the neck hole took (keep the index list tidy: unused points are removed by the build's clean-up)
    patch = None
    if spec.get("patch"):
        side = spec.get("patchSide", "front")
        patch = (side, z_s0 - 0.25)
    return finish(G, body, coll, spec, c_ap.y, patch)


BENCH_SHIRT = {
    "worn": "WornBenchShirt", "clear": 0.045, "rows": 9, "yokeBase": 0.30, "neckGap": 0.05, "neckFront": 0.30,
    "neckBack": 0.12, "segments": (3, 3, 3), "panelDeg": 30, "sleeveRows": 3,
    "hem": lambda m: m["crotch"] + 0.25, "sleeveEnd": lambda m: m["elbow"] + 0.38,
    "patch": ("Patch", "White", "Label"), "patchSide": "back",
    "keys": {"body": "Body", "panel": "Panel", "trim": "Trim", "sleeve": "Shoulder"},
}
PREVIEW["WornBenchShirt"] = {"Body": (0.85, 0.30, 0.03), "Shoulder": (0.85, 0.30, 0.03), "Panel": (0.08, 0.08, 0.09),
                             "Trim": (0.08, 0.08, 0.09), "Label": (0.08, 0.08, 0.09), "Patch": (1, 1, 1)}


def build_bench_shirt(body, coll):
    return shirt_garment(body, coll, BENCH_SHIRT)


def build_squat_suit(body, coll):
    return torso_garment(body, coll, SQUAT_SUIT)


def build_deadlift_suit(body, coll):
    return torso_garment(body, coll, DEADLIFT_SUIT)


# ---------------------------------------------------------------- everyday clothes (the same masters, ClothesConfig)
# Style (References/Body Study.md): tight shells; sleeves and shorts end in thick WHITE cuffs; shorts and joggers have
# a doubled white waistband with drawstrings. One colour per item (coloured in the game); the white pieces are
# "<Item>White" (ClothesConfig `fixed`). Pieces are named "<Item>__<Part>" (no worn-model prefix).
CLOTHES = ("Tee", "LongSleeve", "Tank", "Shorts", "Joggers", "Sneakers")
WHITE_RGB = (0.93, 0.93, 0.91)
CLOTH_RGB = (0.45, 0.47, 0.52)


def drawstrings(body, coll, pieces, spec):
    """Two drawstrings hanging from the front of the waistband, joined into the white piece."""
    key = spec["topBand"][2]
    band = pieces.get(key)
    if band is None:
        return
    m = body.landmarks()
    z_top = spec["flatTop"](m)
    from mathutils.bvhtree import BVHTree
    tree = BVHTree.FromPolygons([v.co for v in band.data.vertices], [tuple(p.vertices) for p in band.data.polygons])
    bm = bmesh.new()
    for sx in (1, -1):
        z0 = z_top - spec["topBand"][0] * 0.55
        loc, nrm, _i, _d = tree.ray_cast(Vector((sx * 0.07, -5.0, z0)), Vector((0, 1, 0)), 10.0)
        if loc is None:
            continue
        start = loc + Vector((0, -0.012, 0))
        end = start + Vector((sx * 0.02, -0.03, -0.17))
        d = end - start
        rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix()
        r = 0.022
        geom = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6, radius1=r, radius2=r, depth=d.length)
        for v in geom["verts"]:
            v.co = rot @ v.co + (start + end) / 2
        geom = bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=4, radius=r * 1.5)
        for v in geom["verts"]:
            v.co = rot @ Vector((v.co.x, v.co.y, v.co.z * 1.4)) + end
    me = bpy.data.meshes.new(body.build + "_Drawstrings")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(me.name, me)
    coll.objects.link(o)
    F["transfer_weights"](o, body, rigid="LowerTorso")
    # into the white piece (vertex groups merge by name)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    band.select_set(True)
    bpy.context.view_layer.objects.active = band
    bpy.ops.object.join()


def clothing(item, base, **changes):
    spec = dict(base, **changes)
    spec["worn"] = item
    return spec


TEE = clothing("Tee", BENCH_SHIRT, clear=0.035, rows=9, yokeBase=0.30, neckGap=0.04, neckFrontDrop=0.08,
               panelDeg=-1, sleeveRows=3, hem=lambda m: m["waist"] - 0.06,
               sleeveEnd=lambda m: m["elbow"] + 0.28, cuff=(0.13, 0.03, "TeeWhite"), patch=None,
               keys={"body": "Tee", "panel": "Tee", "trim": "Tee", "sleeve": "Tee"})
LONG_SLEEVE = clothing("LongSleeve", TEE, sleeveEnd=lambda m: m["wrist"] + 0.19, sleeveRows=6,
                       cuff=(0.13, 0.03, "LongSleeveWhite"),
                       keys={"body": "LongSleeve", "panel": "LongSleeve", "trim": "LongSleeve", "sleeve": "LongSleeve"})
TANK = clothing("Tank", SINGLET, clear=0.035, strapWidth=0.30, strapGap=0.03, strapBase=0.24, neckFront=0.40,
                neckBack=0.22, armholeDrop=0.16, panelDeg=-1, legs=None, hem=lambda m: m["waist"] - 0.06, patch=None,
                keys={"body": "Tank", "panel": "Tank", "trim": "Tank", "legs": "Tank", "stripe": "Tank"})
SHORTS = clothing("Shorts", SINGLET, clear=0.025, flatTop=lambda m: m["waist"], rows=4, panelDeg=-1, patch=None,
                  topBand=(0.16, 0.03, "ShortsWhite"),
                  legs={"end": lambda m: m["knee"] + 0.58 * (m["crotch"] - m["knee"]), "rows": 3, "gusset": 5, "cuff": (0.13, 0.03, "ShortsWhite")},
                  extras=(drawstrings,),
                  keys={"body": "Shorts", "panel": "Shorts", "trim": "Shorts", "legs": "Shorts", "stripe": "Shorts"})
JOGGERS = clothing("Joggers", SHORTS, topBand=(0.16, 0.03, "JoggersWhite"),
                   legs={"end": lambda m: m["ankle"] + 0.17, "rows": 9, "gusset": 5, "cuff": (0.13, 0.03, "JoggersWhite")},
                   keys={"body": "Joggers", "panel": "Joggers", "trim": "Joggers", "legs": "Joggers",
                         "stripe": "Joggers"})
for _item in ("Tee", "LongSleeve", "Tank", "Shorts", "Joggers", "Sneakers"):
    PREVIEW[_item] = {_item: CLOTH_RGB, _item + "White": WHITE_RGB, "SneakersSole": WHITE_RGB}


def build_sneakers(body, coll):
    """Sneakers: a shell round each foot up to the collar (outline rings round the foot), a rolled collar, and a
    white rounded sole slab under it."""
    cl = 0.045
    G = Garment()
    soles = []
    for side, sx in (("Left", 1), ("Right", -1)):
        foot = body.joints[side + "Foot"]
        rows = body.stack((side + "Foot", side + "LowerLeg"), 0.07, body.landmarks()["ankle"] + 0.15, 0.03, (foot.x, foot.y - 0.08), n=64, smooth=1)
        n = 20
        collar = body.landmarks()["ankle"] + 0.15      # the shoe's collar just over the ankle
        heights = [0.07, 0.14, 0.22, 0.30, collar - TRIM, collar]
        prev = None
        for i, z in enumerate(heights):
            c, rs = F["stack_at"](rows, z)
            cur = [G.add(F["ring_point"](c, U, V, rs, 2 * math.pi * k / n, cl)) for k in range(n)]
            if prev:
                key = "Sneakers"
                for k in range(n):
                    G.quad(prev[k], prev[(k + 1) % n], cur[(k + 1) % n], cur[k], key)
            prev = cur
        # the sole: a rounded slab a little bigger than the shell's bottom ring
        c, rs = F["stack_at"](rows, 0.07)
        bm = bmesh.new()
        ring_lo = [F["ring_point"](c, U, V, rs, 2 * math.pi * k / n, cl + 0.03) for k in range(n)]
        top = [bm.verts.new(Vector((p.x, p.y, 0.11))) for p in ring_lo]
        bot = [bm.verts.new(Vector((p.x, p.y, 0.0))) for p in ring_lo]
        for k in range(n):
            bm.faces.new((top[k], top[(k + 1) % n], bot[(k + 1) % n], bot[k]))
        bm.faces.new(top)
        bm.faces.new(list(reversed(bot)))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bmesh.ops.bevel(bm, geom=[e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-6],
                        offset=0.025, segments=1, affect="EDGES", clamp_overlap=True)
        me = bpy.data.meshes.new(body.build + "_Sole" + side)
        bm.to_mesh(me)
        bm.free()
        so = bpy.data.objects.new(me.name, me)
        coll.objects.link(so)
        F["transfer_weights"](so, body, rigid=side + "Foot")
        soles.append(so)
    spec = {"worn": "Sneakers", "clear": cl, "keys": {"body": "Sneakers", "trim": "Sneakers"}}
    o = G.build(body.build + "_Sneakers", coll, axis_y=0.0)
    lip(o, 0.03, 0.012, "Sneakers")
    F["push_clear"](o, body, 0.02)
    F["transfer_weights"](o, body)
    pieces = split_keys(o, coll, body.build + "_Sneakers")
    bpy.ops.object.select_all(action="DESELECT")
    for so in soles:
        so.select_set(True)
    bpy.context.view_layer.objects.active = soles[0]
    bpy.ops.object.join()
    soles[0].name = body.build + "_SneakersSole"
    pieces["SneakersSole"] = soles[0]
    for key, p in pieces.items():
        p.data.materials.clear()
        p.data.materials.append(material("Sneakers", key))
    return pieces


CLOTHES_BUILDERS = {
    "Tee": lambda body, coll: shirt_garment(body, coll, TEE),
    "LongSleeve": lambda body, coll: shirt_garment(body, coll, LONG_SLEEVE),
    "Tank": lambda body, coll: torso_garment(body, coll, TANK),
    "Shorts": lambda body, coll: torso_garment(body, coll, SHORTS),
    "Joggers": lambda body, coll: torso_garment(body, coll, JOGGERS),
    "Sneakers": build_sneakers,
}


# ---------------------------------------------------------------- knee sleeves, knee wraps, wrist wraps
def limb_overlay(body, coll, target, axis_at, path, width, lift, name, uv=None):
    """A thin strip laid on a finished limb piece (a stripe, a logo): `path` = [(angle, z)] along its middle line round
    the limb's axis (axis_at(z) -> axis point); rays from outside onto `target`, the strip `width` wide across its own
    direction, `lift` out. uv: (u0, u1, v0, v1) maps the strip to the logo image (u along, v across)."""
    from mathutils.bvhtree import BVHTree
    tv, tf = [], []
    for t_obj in (target if isinstance(target, (list, tuple)) else [target]):
        base = len(tv)
        tv += [v.co.copy() for v in t_obj.data.vertices]
        tf += [tuple(base + i for i in p.vertices) for p in t_obj.data.polygons]
    tree = BVHTree.FromPolygons(tv, tf)

    def hit(angle, z):
        a = axis_at(z)
        d = U * math.cos(angle) + V * math.sin(angle)
        loc, nrm, _i, _dd = tree.ray_cast(Vector((a.x, a.y, z)) + d * 3.0, -d, 6.0)
        if loc is None:
            return None, None
        if nrm.dot(d) < 0:
            nrm = -nrm
        return loc, nrm
    centre = [hit(a, z) for a, z in path]
    if any(p is None for p, _n in centre):
        log(name, "missed its piece: left out")
        return None
    verts, faces, uvs = [], [], []
    n = len(path)
    for i, (p, nrm) in enumerate(centre):
        if p is None:
            return None
        q_prev = centre[max(0, i - 1)][0]
        q_next = centre[min(n - 1, i + 1)][0]
        tangent = (q_next - q_prev).normalized()
        across = nrm.cross(tangent).normalized()
        for s, vv in ((-0.5, 0.0), (0.5, 1.0)):
            e = p + across * (width * s)
            # back onto the surface
            a_e = axis_at(e.z)
            d = Vector((e.x - a_e.x, e.y - a_e.y, 0)).normalized()
            loc, nn, _i, _dd = tree.ray_cast(Vector((a_e.x, a_e.y, e.z)) + d * 3.0, -d, 6.0)
            if loc is None or (loc - e).length > 0.15:      # (never jump onto the other leg)
                loc, nn = e, nrm
            if nn.dot(d) < 0:
                nn = -nn
            verts.append(loc + nn * lift)
            if uv:
                uvs.append((uv[0] + (uv[1] - uv[0]) * i / (n - 1), uv[2] + (uv[3] - uv[2]) * vv))
    for i in range(n - 1):
        faces.append((2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1))
    o = mesh_from(name, coll, verts, faces, uvs if uv else None, smooth=True)
    # facing out from the limb
    for poly in o.data.polygons:
        c = poly.center
        a = axis_at(c.z)
        if poly.normal.dot(Vector((c.x - a.x, c.y - a.y, 0))) < 0:
            poly.flip()
    o.data.update()
    return o


def wound(body, coll, spec, region_of, centre_of, z_lo, z_hi, side_sign):
    """A wound wrap round a limb from z_lo up to z_hi: `turns` overlapping turns, each one standing a little further out
    at its top than the one below (so every turn's lower edge laps over the last: shingles), each turn's middle row
    a stripe; returns the Garment and the limb stack."""
    turns, cl, t = spec["turns"], spec["clear"], spec["thick"]
    rows = body.stack(region_of, z_lo - 0.03, z_hi + 0.03, 0.02, centre_of, n=64, smooth=1)
    n = spec["around"]
    G = Garment()
    h = (z_hi - z_lo) / turns
    keys = spec["keys"]
    prev_top = None
    for k in range(turns):
        a = z_lo + h * k
        tilt = spec.get("tilt", 0.0) * (1 if k % 2 == 0 else -1)
        levels = [(a - (0.0 if k == 0 else 0.03), cl + t * (0.2 if k == 0 else 0.75), "edge"),
                  (a + h * 0.35, cl + t * 0.9, "body"), (a + h * 0.65, cl + t * 0.95, "stripe"),
                  (a + h + 0.012, cl + t * 0.55, "body")]
        ring_ids = []
        for z, c_l, kind in levels:
            c, rs = F["stack_at"](rows, z)
            ring = []
            for j in range(n):
                ang = 2 * math.pi * j / n
                # a slight lean round the limb, so each turn reads as wound, not stacked
                dz = tilt * math.sin(ang)
                cc, rr = F["stack_at"](rows, z + dz)
                ring.append(G.add(F["ring_point"](cc, U, V, rr, ang, c_l)))
            ring_ids.append((ring, kind))
        striped = k in spec.get("stripeTurns", range(turns))
        for (r0, k0), (r1, k1) in zip(ring_ids, ring_ids[1:]):
            key = keys["stripe"] if striped and k1 == "stripe" and k0 == "body" else keys["body"]
            for j in range(n):
                G.quad(r0[j], r0[(j + 1) % n], r1[(j + 1) % n], r1[j], key)
        # the turn's underside: from its lower edge back in under the turn below (closed, never see-through)
        r_edge = ring_ids[0][0]
        under = []
        for j in range(n):
            p = G.verts[r_edge[j]]
            c, rs = F["stack_at"](rows, p.z + 0.02)
            under.append(G.add(F["ring_point"](c, U, V, rs, 2 * math.pi * j / n, cl * 0.6)))
        for j in range(n):
            G.quad(under[j], under[(j + 1) % n], r_edge[(j + 1) % n], r_edge[j], keys["body"])
        if k == turns - 1:
            top = ring_ids[-1][0]
            inner = []
            for j in range(n):
                p = G.verts[top[j]]
                c, rs = F["stack_at"](rows, p.z - 0.02)
                inner.append(G.add(F["ring_point"](c, U, V, rs, 2 * math.pi * j / n, cl * 0.6)))
            for j in range(n):
                G.quad(top[j], top[(j + 1) % n], inner[(j + 1) % n], inner[j], keys["body"])
    return G, rows


KNEE_SLEEVE = {"worn": "WornKneeSleeve", "clear": 0.04, "around": 24, "rows": 9, "length": (0.42, 0.42),
               "keys": {"body": "Body", "trim": "Body", "stripe": "Stripes", "patch": "Patch"}}
KNEE_WRAP = {"worn": "WornKneeWrap", "clear": 0.035, "thick": 0.045, "turns": 5, "around": 20, "tilt": 0.03,
             "length": (0.24, 0.26), "keys": {"body": "Body", "trim": "Body", "stripe": "Stripes", "accent": "Accent"}}
WRIST_WRAP = {"worn": "WornWristWrap", "clear": 0.03, "thick": 0.05, "turns": 3, "around": 16, "tilt": 0.03,
              "span": (0.10, 0.36), "stripeTurns": (1,), "keys": {"body": "Body", "trim": "Body", "stripe": "Stripes", "tail": "Tail",
                                             "text": "Text"}}
PREVIEW["WornKneeSleeve"] = {"Body": (0.03, 0.03, 0.035), "Stripes": (0.2, 0.2, 0.22), "Patch": (1, 1, 1)}
PREVIEW["WornKneeWrap"] = {"Body": (0.1, 0.12, 0.3), "Stripes": (0.2, 0.45, 0.9), "Accent": (0.8, 0.15, 0.15)}
PREVIEW["WornWristWrap"] = {"Body": (0.03, 0.03, 0.035), "Tail": (0.03, 0.03, 0.035), "Stripes": (0.55, 0.02, 0.03),
                            "Text": (1, 1, 1)}


def limb_finish(body, coll, spec, G, name):
    """Hems, the body's own weights, pose relief, one object per key (like finish(), without the torso patch)."""
    o = G.build(name, coll, axis_y=0.0)
    for poly in o.data.polygons:      # limbs: face out from each limb, not the body's middle
        pass
    F["push_clear"](o, body, spec["clear"] * 0.7)
    return o


def build_knee_sleeves(body, coll):
    """One seamless compression tube per leg from mid-thigh to mid-shin (bending with the knee as one piece), thick
    rolled ends, a diagonal stripe down the outer side, CENTRAL low on the front."""
    spec = KNEE_SLEEVE
    m = body.landmarks()
    knee = m["knee"]
    cl = spec["clear"]
    G = Garment()
    stacks = {}
    for side, sx in (("Left", 1), ("Right", -1)):
        z_lo, z_hi = knee - spec["length"][0], knee + spec["length"][1]
        rows = body.stack(side + "Leg", z_lo - 0.03, z_hi + 0.03, 0.03, (sx * 0.5, 0), n=96, smooth=2)
        stacks[side] = rows
        n = spec["around"]
        hs = [z_lo] + [z_lo + TRIM + (z_hi - TRIM - z_lo - TRIM) * i / (spec["rows"] - 1) for i in range(spec["rows"])] + [z_hi]
        prev = None
        for z in hs:
            c, rs = F["stack_at"](rows, z)
            cur = [G.add(F["ring_point"](c, U, V, rs, 2 * math.pi * j / n, cl)) for j in range(n)]
            if prev:
                for j in range(n):
                    G.quad(prev[j], prev[(j + 1) % n], cur[(j + 1) % n], cur[j], spec["keys"]["body"])
            prev = cur
    o = G.build(body.build + "_" + spec["worn"], coll)
    F["push_clear"](o, body, cl * 0.7)
    lip(o, 0.03, 0.016, spec["keys"]["body"])
    F["push_clear"](o, body, 0.012)
    F["transfer_weights"](o, body)
    relief = F["pose_relief"](o, body)
    log(body.build, spec["worn"], "pose relief up to %.3f" % relief)
    pieces = split_keys(o, coll, body.build + "_" + spec["worn"])
    target = pieces[spec["keys"]["body"]]
    stripes, patches = [], []
    for side, sx in (("Left", 1), ("Right", -1)):
        rows = stacks[side]
        axis = lambda z, rows=rows: F["stack_at"](rows, z)[0]
        outer = 0.0 if sx > 0 else math.pi
        # the stripe: down the outer side, from the front above the knee to the back below it
        path = [(outer - sx * 0.9 + sx * 1.8 * t, knee + 0.33 - 0.66 * t) for t in [i / 10 for i in range(11)]]
        s = limb_overlay(body, coll, target, axis, path, 0.07, 0.006, body.build + "_SleeveStripe" + side)
        if s:
            stripes.append(s)
        # CENTRAL low on the front, below the kneecap
        u0, u1 = LOGO_U
        v_top = 1 - LOGO_ROWS["White"] / 4.0
        span = 0.62
        front = -math.pi / 2
        path = [(front - sx * 0.0 + (span * (t - 0.5)) * (1 if True else -1), knee - 0.24) for t in [i / 8 for i in range(9)]]
        p = limb_overlay(body, coll, target, axis, path, 0.10, 0.008, body.build + "_SleevePatch" + side,
                         uv=(u0, u1, v_top - 0.25, v_top))
        if p:
            patches.append(p)
    for group, key in ((stripes, spec["keys"]["stripe"]), (patches, spec["keys"]["patch"])):
        if not group:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for g in group:
            g.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        bpy.ops.object.join()
        F["transfer_weights"](group[0], body)
        pieces[key] = group[0]
    for key, p in pieces.items():
        p.data.materials.clear()
        p.data.materials.append(material(spec["worn"], key))
    return pieces


def fix_limb_normals(o, body):
    """Turns every face of limb pieces to point away from its own limb's axis (the body-axis rule is wrong there)."""
    me = o.data
    for poly in me.polygons:
        c = poly.center
        if abs(c.x) < 0.15:
            continue
        ax = Vector((0.5 if c.x > 0 else -0.5, 0.0, c.z))
        if abs(c.z - 2.7) < 0.5 and abs(c.x) > 0.7:
            ax = Vector((body.landmarks()["armX"] * (1 if c.x > 0 else -1), 0.0, c.z))
        if poly.normal.dot(Vector((c.x - ax.x, c.y - ax.y, 0))) < 0:
            poly.flip()
    me.update()


def build_knee_wraps(body, coll):
    """A strap wound round each knee: five overlapping turns lapping like shingles, each with a stripe along it, the
    strap's end tucked at the top in the accent colour."""
    spec = KNEE_WRAP
    m = body.landmarks()
    knee = m["knee"]
    allG = Garment()
    tails = []
    for side, sx in (("Left", 1), ("Right", -1)):
        G, rows = wound(body, coll, spec, side + "Leg", (sx * 0.5, 0), knee - spec["length"][0], knee + spec["length"][1], sx)
        base = len(allG.verts)
        allG.verts += G.verts
        allG.faces += [tuple(base + i for i in f) for f in G.faces]
        allG.keys += G.keys
    o = allG.build(body.build + "_" + spec["worn"], coll)
    F["push_clear"](o, body, spec["clear"] * 0.5)
    F["transfer_weights"](o, body)
    relief = F["pose_relief"](o, body)
    log(body.build, spec["worn"], "pose relief up to %.3f" % relief)
    pieces = split_keys(o, coll, body.build + "_" + spec["worn"])
    # the strap's end: a short tab tucked on the outer side of the top turn
    target = list(pieces.values())
    for side, sx in (("Left", 1), ("Right", -1)):
        rows = body.stack(side + "Leg", knee - 0.3, knee + 0.4, 0.03, (sx * 0.5, 0), n=64, smooth=1)
        axis = lambda z, rows=rows: F["stack_at"](rows, z)[0]
        outer = 0.0 if sx > 0 else math.pi
        z_top = knee + spec["length"][1] - 0.02
        path = [(outer - sx * 0.25 + sx * 0.5 * t, z_top - 0.05 * t) for t in [i / 4 for i in range(5)]]
        tab = limb_overlay(body, coll, target, axis, path, 0.09, 0.01, body.build + "_WrapTab" + side)
        if tab:
            tails.append(tab)
    if tails:
        bpy.ops.object.select_all(action="DESELECT")
        for g in tails:
            g.select_set(True)
        bpy.context.view_layer.objects.active = tails[0]
        bpy.ops.object.join()
        F["transfer_weights"](tails[0], body)
        pieces[spec["keys"]["accent"]] = tails[0]
    for key, p in pieces.items():
        p.data.materials.clear()
        p.data.materials.append(material(spec["worn"], key))
    return pieces


def build_wrist_wraps(body, coll):
    """A thick wound wrap round each wrist: four overlapping turns from the base of the hand well up the forearm (so
    the whole wrist is covered: never a thin ring), a stripe along each turn, the loose tail tucked on the outer side,
    CENTRAL on the back of the wrist. Rigid with the forearm (the hand turns inside it, as a real wrap holds it)."""
    spec = WRIST_WRAP
    m = body.landmarks()
    wrist = m["wrist"]
    allG = Garment()
    stacks = {}
    for side, sx in (("Left", 1), ("Right", -1)):
        region = (side + "LowerArm", side + "Hand")
        z_lo, z_hi = wrist - spec["span"][0], wrist + spec["span"][1]
        G, rows = wound(body, coll, spec, region, (sx * m["armX"], 0), z_lo, z_hi, sx)
        stacks[side] = rows
        base = len(allG.verts)
        allG.verts += G.verts
        allG.faces += [tuple(base + i for i in f) for f in G.faces]
        allG.keys += G.keys
    o = allG.build(body.build + "_" + spec["worn"], coll)
    F["push_clear"](o, body, spec["clear"] * 0.5, region="All")
    F["transfer_weights"](o, body, region=("LeftLowerArm", "RightLowerArm"))
    pieces = split_keys(o, coll, body.build + "_" + spec["worn"])
    target = list(pieces.values())
    tails, texts = [], []
    for side, sx in (("Left", 1), ("Right", -1)):
        rows = stacks[side]
        axis = lambda z, rows=rows: F["stack_at"](rows, z)[0]
        outer = 0.0 if sx > 0 else math.pi
        path = [(outer, wrist + 0.10 - 0.16 * t) for t in [i / 4 for i in range(5)]]
        tl = limb_overlay(body, coll, target, axis, path, 0.11, 0.01, body.build + "_WristTail" + side)
        if tl:
            tails.append(tl)
        u0, u1 = LOGO_U
        v_top = 1 - LOGO_ROWS["White"] / 4.0
        back = math.pi / 2 if True else 0
        # the back of the hand faces outward (+X on the left, -X on the right) with the arms down: the logo there
        span = 1.1
        path = [(outer + span * (t - 0.5), wrist + 0.16) for t in [i / 8 for i in range(9)]]
        tx = limb_overlay(body, coll, target, axis, path, 0.075, 0.012, body.build + "_WristText" + side,
                          uv=(u0, u1, v_top - 0.25, v_top))
        if tx:
            texts.append(tx)
    for group, key in ((tails, spec["keys"]["tail"]), (texts, spec["keys"]["text"])):
        if not group:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for g in group:
            g.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        bpy.ops.object.join()
        F["transfer_weights"](group[0], body, region=("LeftLowerArm", "RightLowerArm"))
        pieces[key] = group[0]
    for key, p in pieces.items():
        p.data.materials.clear()
        p.data.materials.append(material(spec["worn"], key))
    return pieces


# ---------------------------------------------------------------- per build
BUILDERS = {"Belt": ("WornLeverBelt", build_belt), "Singlet": ("WornSinglet", build_singlet),
            "SquatSuit": ("WornSquatSuit", build_squat_suit), "DeadliftSuit": ("WornDeadliftSuit", build_deadlift_suit),
            "BenchShirt": ("WornBenchShirt", build_bench_shirt), "KneeSleeves": ("WornKneeSleeve", build_knee_sleeves),
            "KneeWraps": ("WornKneeWrap", build_knee_wraps), "WristWraps": ("WornWristWrap", build_wrist_wraps)}
# clothes: pieces named "<Item>__<Part>" (ClothesConfig), so no worn-model prefix
for _item, _fn in CLOTHES_BUILDERS.items():
    BUILDERS[_item] = (None, _fn)


def build_one(build, coll):
    body = F["Body"](build)
    rig = body.rig
    out = {}
    for item in ITEMS:
        worn, fn = BUILDERS[item]
        pieces = fn(body, coll)
        made = []
        for key, o in pieces.items():
            prefix = "%s_%s" % (worn, key) if worn else key
            made += F["split_parts"](o, prefix, body, coll, material=o.data.materials[0] if o.data.materials else None)
        out[worn or item] = made
    return body, out


def triangles(objs):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)


coll = bpy.data.collections.get(COLLECTION) or bpy.data.collections.new(COLLECTION)
if coll.name not in bpy.context.scene.collection.children:
    bpy.context.scene.collection.children.link(coll)
def owned(name, b, item):
    worn = BUILDERS[item][0]
    if worn:
        return name.startswith("%s_%s" % (b, worn)) or (item == "Belt" and name.startswith(b + "_Belt"))
    return name.startswith("%s_%s" % (b, item)) or (item == "Sneakers" and name.startswith(b + "_Sole"))


for o in list(coll.objects):
    if any(owned(o.name, b, i) for b in BUILDS for i in ITEMS):
        bpy.data.objects.remove(o, do_unlink=True)
RESULT = {}
for b in BUILDS:
    body, made = build_one(b, coll)
    RESULT[b] = made
    log(b, {w: triangles(ps) for w, ps in made.items()})


def export_build(b, pieces, kind):
    """One GLB per build: the rig + the pieces, named as the game expects ("<Worn>_<Key>__<Part>" / "<Item>__<Part>")."""
    rig = bpy.data.objects[b + "Rig"]
    saved = rig.location.copy()
    rig.location = (0, 0, 0)
    bpy.context.view_layer.update()
    names = {}
    for p in pieces:
        names[p] = p.name
        p.name = p.name.split("_", 1)[1]
        p.data.name = p.name
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for p in pieces:
        p.select_set(True)
    bpy.context.view_layer.objects.active = rig
    path = os.path.join(EXPORTS, "%s03_%s.glb" % (kind, b))
    # (no images in the GLB: the logo is one separate upload, put on in the game as a tinted Decal)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_yup=True,
                              export_skins=True, export_animations=False, export_morph=False,
                              export_image_format="NONE")
    for p, n in names.items():
        p.name = n
        p.data.name = n
    rig.location = saved
    log(b, "exported", path, len(pieces), "pieces", triangles(pieces), "triangles")


if EXPORT:
    for b in BUILDS:
        gear, clothes = [], []
        for o in coll.objects:
            if not o.name.startswith(b + "_") or "__" not in o.name:
                continue
            (clothes if any(o.name.startswith("%s_%s" % (b, c)) for c in CLOTHES) else gear).append(o)
        export_build(b, gear, "CartoonGear")
        export_build(b, clothes, "CartoonClothes")
    for name in ("Gear03Outline", "Gear03Test"):
        c = bpy.data.collections.get(name)
        if c:
            for o in list(c.objects):
                bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.collections.remove(c)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    log("saved", OUT_BLEND)
