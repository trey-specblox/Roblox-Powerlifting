# Gear fitting tools, version 3 (approved plan 2026-11-12, memory "gear-fitting-architecture"; user: "do all of the
# phases"). A LIBRARY: build_cartoon_gear_03.py (and anything that checks gear) loads it with exec().
#
# Why: the v02 gear was the body's own skin pushed outward, so it copied every muscle, clipped into the body and looked
# painted on. Here each item is ONE master shape (modelled like the real thing, in the build script) and this file
# fits it to each build automatically, so a new or redesigned body is a re-run, never a rebuild by hand.
#
# What is in here:
#   Body(build)        the build's skin in its rig's own space (rest pose), with a fast search tree per body region
#   Body.ring(...)     one smooth OUTLINE ring: rays from inside the body to the skin, then the tightest convex loop round
#                      the hits (fabric bridges muscle grooves; it never follows them in)
#   Body.stack(...)    rings up a body region (torso, a leg, an arm), smoothed up and down too: the SMOOTHED OUTLINE
#   outline_mesh(...)  a stack as a mesh, coloured by how far it bridges over the real skin (for the pictures)
#   transfer_weights   gives a fitted piece the body's own bone weights (nearest skin point), optionally smoothed
#   split_parts        cuts a piece into one mesh per body part, "<prefix>__<Part>", skinned to the rig (game format)
#   read_anim / pose_rig / extreme_time
#                      poses a rig with the REAL animation files (art/animations/*.rbxmx), exactly as Roblox does:
#                      part = parent * joint offset * Transform. (Fixes v02's posed check, which mixed object, parent
#                      and armature spaces: here every number is in the rig's own space, whatever the rig's location.)
#   clearance(...)     how far each piece is from the real skin, at rest and in each pose: points inside, closest point
#   shots(...)         the same picture set every time: front, back, left, right for every build, one camera, one light,
#                      back faces hidden (as Roblox draws them)
import math
import os
import xml.etree.ElementTree as ET

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.interpolate import poly_3d_calc

ROOT = r"D:\Powerlifting Roblox"
ANIMS = os.path.join(ROOT, "art", "animations")
PREVIEWS = os.path.join(ROOT, "art", "previews")
BUILDS = ("Skinny", "Heavy", "Muscular")
PARTS = ["LowerTorso", "UpperTorso"] + [s + p for s in ("Left", "Right") for p in
                                         ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")]
REGIONS = {
    "Torso": ("LowerTorso", "UpperTorso"),
    "LeftLeg": ("LeftUpperLeg", "LeftLowerLeg"), "RightLeg": ("RightUpperLeg", "RightLowerLeg"),
    "LeftArm": ("LeftUpperArm", "LeftLowerArm"), "RightArm": ("RightUpperArm", "RightLowerArm"),
    "LeftHand": ("LeftHand",), "RightHand": ("RightHand",),
    # the hips: the torso with the tops of the legs (the glutes and outer hips follow the leg bones)
    "TorsoHips": ("LowerTorso", "UpperTorso", "LeftUpperLeg", "RightUpperLeg"),
    # above the armpits: the torso with the shoulders (the deltoids follow the arm bones)
    "Yoke": ("LowerTorso", "UpperTorso", "LeftUpperArm", "RightUpperArm"),
    "All": tuple(PARTS),
    # every part but the hands (they hang beside the thighs: a thigh's nearest skin can be a hand)
    "NoHands": tuple(p for p in PARTS if "Hand" not in p),
}
# Each body part's parent (the R15 chain; LowerTorso hangs from the root part).
PARENT = {"LowerTorso": "HumanoidRootNode", "UpperTorso": "LowerTorso"}
for _s in ("Left", "Right"):
    PARENT.update({_s + "UpperArm": "UpperTorso", _s + "LowerArm": _s + "UpperArm", _s + "Hand": _s + "LowerArm",
                   _s + "UpperLeg": "LowerTorso", _s + "LowerLeg": _s + "UpperLeg", _s + "Foot": _s + "LowerLeg"})
# Blender (front -Y, the character's left +X, up +Z) <-> Roblox (front -Z after the importer's half turn, up +Y).
# The same matrix goes both ways.
TO_B = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def log(*a):
    print("[GearFit03]", *a)


# ---------------------------------------------------------------- 2D helpers
def hull_2d(points):
    """Convex hull (counter-clockwise) of 2D points (monotone chain)."""
    pts = sorted(set((round(p[0], 6), round(p[1], 6)) for p in points))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def radial(hull, angles):
    """Distance from the origin to the hull along each angle (the origin must be inside the hull)."""
    out = []
    for a in angles:
        dx, dy = math.cos(a), math.sin(a)
        best = 0.0
        for i in range(len(hull)):
            px, py = hull[i]
            qx, qy = hull[(i + 1) % len(hull)]
            ex, ey = qx - px, qy - py
            den = dx * ey - dy * ex
            if abs(den) < 1e-12:
                continue
            t = (px * ey - py * ex) / den
            s = (px * dy - py * dx) / den
            if t > 0 and -1e-9 <= s <= 1 + 1e-9:
                best = max(best, t)
        if best == 0.0:   # origin outside or degenerate: the farthest hull point in that direction
            best = max(0.02, max(p[0] * dx + p[1] * dy for p in hull))
        out.append(best)
    return out


def window_fill(values, half, wrap=False):
    """Fills valleys narrower than the window and keeps every bump: max(value, mean of its window)."""
    n = len(values)
    out = []
    for i in range(n):
        if wrap:
            win = [values[(i + k) % n] for k in range(-half, half + 1)]
        else:
            win = values[max(0, i - half):min(n, i + half + 1)]
        out.append(max(values[i], sum(win) / len(win)))
    return out


# ---------------------------------------------------------------- the body
class Body:
    """One build's skin (rest pose, rig space), its bone weights and joints, and search trees per region."""

    def __init__(self, build):
        self.build = build
        self.rig = bpy.data.objects[build + "Rig"]
        to_rig = self.rig.matrix_world.inverted()
        self.verts, self.faces, self.face_part, self.weights = [], [], [], []
        for part in PARTS:
            o = bpy.data.objects[build + "_" + part]
            m = to_rig @ o.matrix_world
            names = {g.index: g.name for g in o.vertex_groups}
            base = len(self.verts)
            for v in o.data.vertices:
                self.verts.append(m @ v.co)
                self.weights.append({names[g.group]: g.weight for g in v.groups if g.weight > 0 and g.group in names})
            for p in o.data.polygons:
                self.faces.append(tuple(base + i for i in p.vertices))
                self.face_part.append(part)
        self._bvh = {}
        self.joints = {b.name: b.head_local.copy() for b in self.rig.data.bones}

    def bvh(self, region="All"):
        key = region if isinstance(region, str) else "|".join(region)
        if key not in self._bvh:
            keep = set(REGIONS[region]) if isinstance(region, str) else set(region)
            faces = [f for f, p in zip(self.faces, self.face_part) if p in keep]
            self._bvh[key] = BVHTree.FromPolygons(self.verts, faces)
            self._bvh[key + "#faces"] = faces
        return self._bvh[key]

    def faces_of(self, region="All"):
        key = region if isinstance(region, str) else "|".join(region)
        self.bvh(region)
        return self._bvh[key + "#faces"]

    def hit(self, region, origin, direction, far=4.0):
        loc, _n, _i, _d = self.bvh(region).ray_cast(origin, direction.normalized(), far)
        return loc

    def centre(self, region, guess, u, v, rounds=2):
        """Moves a point inside a region to the middle of its slice (along u and v)."""
        c = guess.copy()
        for _ in range(rounds):
            for axis in (u, v):
                a, b = self.hit(region, c, axis), self.hit(region, c, -axis)
                if a is not None and b is not None:
                    c = c + axis * (((a - c).dot(axis) + (b - c).dot(axis)) / 2)
        return c

    def ring(self, region, centre, u, v, n=48, rays=96, fill=0):
        """The outline ring round a slice: `rays` rays from `centre` in the plane (u, v) to the region's skin, the convex
        loop round the hits, then `n` points on it at even angles. Returns (radii, centre); angle 0 is along u.
        `fill` > 0 also fills dents narrower than that many points round the ring (it is convex already, so 0)."""
        pts = []
        for i in range(rays):
            a = 2 * math.pi * i / rays
            d = u * math.cos(a) + v * math.sin(a)
            loc = self.hit(region, centre, d)
            if loc is not None:
                w = loc - centre
                pts.append((w.dot(u), w.dot(v)))
        if len(pts) < 3:
            return None
        hull = hull_2d(pts)
        rs = radial(hull, [2 * math.pi * k / n for k in range(n)])
        if fill:
            rs = window_fill(rs, fill, wrap=True)
        return rs

    def stack(self, region, z0, z1, step, guess_xy, n=48, smooth=2):
        """Horizontal outline rings up a region from z0 to z1 (rig space; at rest every limb hangs straight down).
        Returns [(z, centre, radii)], radii also smoothed up and down (valleys shorter than 2*smooth+1 rings filled)."""
        u, v = Vector((1, 0, 0)), Vector((0, 1, 0))
        rows = []
        count = max(2, int(round((z1 - z0) / step)) + 1)
        guess = Vector((guess_xy[0], guess_xy[1], z0))
        for k in range(count):
            z = z0 + (z1 - z0) * k / (count - 1)
            g = Vector((guess.x, guess.y, z))
            reg = region(z) if callable(region) else region
            c = self.centre(reg, g, u, v)
            rs = self.ring(reg, c, u, v, n)
            if rs is None:
                continue
            rows.append([z, c, rs])
            guess = c
        if smooth and len(rows) > 2:
            for a in range(n):
                col = window_fill([r[2][a] for r in rows], smooth)
                for r, val in zip(rows, col):
                    r[2][a] = val
        return [(z, c, rs) for z, c, rs in rows]

    def landmarks(self):
        """Heights found on the skin itself (so a new body needs no hand-typed numbers): crotch (the skin straight up
        from between the feet), armpit (the highest height where a ray out from the torso's middle leaves the skin and
        meets the arm again: below it the arm hangs free of the torso), shoulder top, waist joint, knees, wrists."""
        if hasattr(self, "_marks"):
            return self._marks
        j = self.joints
        crotch = self.hit("All", Vector((0, 0, 0.6)), Vector((0, 0, 1))).z
        armpit = []
        for sx in (1, -1):
            found = None
            z = j["LeftUpperArm"].z
            while z > j["LeftLowerArm"].z:
                c = Vector((0, 0, z))
                d = Vector((sx, 0, 0))
                out = self.hit("All", c, d)
                if out is not None:
                    back = self.hit("All", out + d * 0.002, d)
                    if back is not None and (back - out).length > 0.004:
                        found = z
                        break
                z -= 0.01
            armpit.append(found or j["LeftUpperArm"].z - 0.45)
        top = self.hit("All", Vector((j["LeftUpperArm"].x * 0.5, 0, min(armpit) - 0.2)), Vector((0, 0, 1)))
        # the top of the neck stump (the head sits over it): the highest skin near the middle
        neck_rim = max(v.z for v in self.verts if abs(v.x) < 0.3 and abs(v.y) < 0.45)
        self._marks = {"crotch": crotch, "armpit": min(armpit), "waist": j["UpperTorso"].z, "neckRim": neck_rim,
                       "shoulderTop": top.z if top is not None else j["LeftUpperArm"].z + 0.2,
                       "knee": j["LeftLowerLeg"].z, "ankle": j["LeftFoot"].z, "wrist": j["LeftHand"].z,
                       "elbow": j["LeftLowerArm"].z, "armX": j["LeftLowerArm"].x, "pivotX": j["LeftUpperArm"].x}
        return self._marks

    def torso_region(self, z):
        """Which skin a torso ring at height z wraps: hips and torso below the armpits, torso and shoulders above."""
        return "Yoke" if z >= self.landmarks()["armpit"] else "TorsoHips"

    def gap(self, point, region="All"):
        """Signed distance from the real skin (negative = inside)."""
        loc, nrm, _i, d = self.bvh(region).find_nearest(point)
        if loc is None:
            return 9.0
        return d if (point - loc).dot(nrm) >= 0 else -d

    def weights_at(self, point, region="All"):
        """The skin's bone weights at the nearest skin point to `point` (blended over that face's corners)."""
        loc, _n, idx, _d = self.bvh(region).find_nearest(point)
        face = self.faces_of(region)[idx]
        corners = [self.verts[i] for i in face]
        ws = poly_3d_calc(corners, loc)
        out = {}
        for vi, w in zip(face, ws):
            for bone, bw in self.weights[vi].items():
                out[bone] = out.get(bone, 0.0) + bw * w
        return out


def body_outlines(body, step=0.04):
    """The build's whole smoothed outline: {"Torso", "LeftLeg", "RightLeg", "LeftArm", "RightArm": stack rows}."""
    m = body.landmarks()
    out = {"Torso": body.stack(body.torso_region, m["crotch"] + 0.03, 4.62, step, (0, 0))}
    for side, sx in (("Left", 1), ("Right", -1)):
        out[side + "Leg"] = body.stack(side + "Leg", 0.45, m["crotch"] - 0.05, step, (sx * 0.5, 0))
        out[side + "Arm"] = body.stack(side + "Arm", 2.84, m["armpit"] - 0.02, step, (sx * m["armX"], 0))
    return out


def ring_point(centre, u, v, radii, angle, extra=0.0):
    """A point on an outline ring at any angle (radii linearly between samples), `extra` further out."""
    n = len(radii)
    f = (angle / (2 * math.pi)) % 1.0 * n
    i = int(f) % n
    t = f - int(f)
    r = radii[i] * (1 - t) + radii[(i + 1) % n] * t + extra
    return centre + (u * math.cos(angle) + v * math.sin(angle)) * r


def stack_at(rows, z):
    """The outline ring at height z, between the stack's rings: (centre, radii)."""
    if z <= rows[0][0]:
        return rows[0][1], rows[0][2]
    if z >= rows[-1][0]:
        return rows[-1][1], rows[-1][2]
    for (za, ca, ra), (zb, cb, rb) in zip(rows, rows[1:]):
        if za <= z <= zb:
            t = (z - za) / max(1e-9, zb - za)
            return ca.lerp(cb, t), [x * (1 - t) + y * t for x, y in zip(ra, rb)]
    return rows[-1][1], rows[-1][2]


# ---------------------------------------------------------------- meshes
def new_object(name, coll, verts, faces, smooth=True):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.validate(verbose=False)
    for p in me.polygons:
        p.use_smooth = smooth
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    return o


def outline_mesh(body, rows, name, coll, colour_gap=0.10):
    """A stack of outline rings as a tube mesh, coloured by how far each point bridges over the real skin: blue = on
    the skin, red = `colour_gap` or more over a groove."""
    n = len(rows[0][2])
    u, v = Vector((1, 0, 0)), Vector((0, 1, 0))
    verts, faces = [], []
    for z, c, rs in rows:
        for k in range(n):
            verts.append(ring_point(c, u, v, rs, 2 * math.pi * k / n))
    for i in range(len(rows) - 1):
        for k in range(n):
            a, b = i * n + k, i * n + (k + 1) % n
            faces.append((a, b, b + n, a + n))
    o = new_object(name, coll, verts, faces)
    attr = o.data.color_attributes.new("Gap", "FLOAT_COLOR", "POINT")
    for i, p in enumerate(verts):
        g = max(0.0, min(1.0, body.gap(p) / colour_gap))
        attr.data[i].color = (0.15 + 0.85 * g, 0.35 * (1 - g) + 0.25, 1.0 - 0.85 * g, 1.0)
    return o


def transfer_weights(obj, body, region="NoHands", only=None, smooth=0, rigid=None):
    """Gives obj (already in rig space) the body's bone weights: each point takes the weights of the nearest skin point.
    `only`: keep only these bones (renormalised). `rigid`: one bone for everything (a belt). `smooth`: rounds of
    averaging with the neighbours (a softer bend across a joint, e.g. a knee sleeve). At most 4 bones per point."""
    me = obj.data
    obj.vertex_groups.clear()
    per = []
    for v in me.vertices:
        if rigid:
            per.append({rigid: 1.0})
            continue
        w = body.weights_at(v.co, region)
        if only:
            w = {b: x for b, x in w.items() if b in only} or {only[0]: 1.0}
        per.append(w)
    if smooth:
        nbr = [set() for _ in me.vertices]
        for e in me.edges:
            a, b = e.vertices
            nbr[a].add(b)
            nbr[b].add(a)
        for _ in range(smooth):
            nxt = []
            for i, w in enumerate(per):
                acc = dict((k, x * 0.5) for k, x in w.items())
                if nbr[i]:
                    share = 0.5 / len(nbr[i])
                    for j in nbr[i]:
                        for k, x in per[j].items():
                            acc[k] = acc.get(k, 0.0) + x * share
                else:
                    acc = dict(w)
                nxt.append(acc)
            per = nxt
    groups = {}
    for i, w in enumerate(per):
        top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
        total = sum(x for _k, x in top) or 1.0
        for bone, x in top:
            if x / total < 0.01:
                continue
            g = groups.get(bone) or obj.vertex_groups.new(name=bone)
            groups[bone] = g
            g.add([i], x / total, "REPLACE")
    return obj


def dominant_part(obj, vi):
    best, bw = None, 0.0
    names = {g.index: g.name for g in obj.vertex_groups}
    for g in obj.data.vertices[vi].groups:
        n = names.get(g.group)
        if n in PARTS and g.weight > bw:
            best, bw = n, g.weight
    return best or "UpperTorso"


def posed_skin(build, rig):
    """The posed skin: (points, normals, faces, part per face, part per point), rig space."""
    dg = bpy.context.evaluated_depsgraph_get()
    pts, nrms, faces, fparts, vparts = [], [], [], [], []
    for part in PARTS:
        o = bpy.data.objects[build + "_" + part]
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        m = rig.matrix_world.inverted() @ o.matrix_world
        r = m.to_3x3()
        base = len(pts)
        for v in me.vertices:
            pts.append(m @ v.co)
            nrms.append((r @ v.normal).normalized())
            vparts.append(part)
        for p in me.polygons:
            faces.append(tuple(base + i for i in p.vertices))
            fparts.append(part)
        ev.to_mesh_clear()
    return pts, nrms, faces, fparts, vparts


def covered_skin(build, rig, objs):
    """Skin points (indices in posed_skin order) that the pieces cover at REST: a ray straight out from the skin meets
    the inside of a piece within 0.15. Only these must stay covered in poses (a bare thigh in front of the singlet's
    belly in a deep squat is not a clip). The rig must be at rest."""
    gv, gf = [], []
    for o in objs:
        pts, fs = evaluated_points(o, rig)
        base = len(gv)
        gv += pts
        gf += [tuple(base + i for i in f) for f in fs]
    if not gf:
        return set()
    gtree = BVHTree.FromPolygons(gv, gf)
    sp, sn, _sf, _sfp, svp = posed_skin(build, rig)
    out = set()
    for i, (p, n, part) in enumerate(zip(sp, sn, svp)):
        if "Hand" in part:
            continue
        loc, fn, _fi, _d = gtree.ray_cast(p + n * 0.0005, n, 0.15)
        if loc is not None and fn.dot(n) > 0:
            out.add(i)
    return out


def pose_relief(obj, body, poses=None, margin=0.01, cap=0.05, rounds=3):
    """Targeted room where the body needs it (NOT a general inflate): the weighted piece (rig space, before
    splitting) is checked at rest and in every check pose, two ways: (1) each of its points against the skin of the
    body part it moves with and the parts joined to it (a glute sits between hip and thigh), (2) each skin point of
    those parts that comes out THROUGH one of its faces (between its points, e.g. a lat bulging between two rows).
    Wherever the skin comes closer than `margin`, the points move out at rest by the shortfall (at most `cap`, spread
    a little to their neighbours so it stays smooth). Repeated `rounds` times. Returns the largest move."""
    rig = body.rig
    poses = list(poses or CHECK_POSES)
    names = {g.index: g.name for g in obj.vertex_groups}
    main = [max(((names.get(g.group), g.weight) for g in v.groups), key=lambda x: x[1], default=(None, 0))[0]
            for v in obj.data.vertices]
    nbr = [set() for _ in obj.data.vertices]
    for e in obj.data.edges:
        a, b = e.vertices
        nbr[a].add(b)
        nbr[b].add(a)
    near = {p: {p, PARENT.get(p)} | {c for c, par in PARENT.items() if par == p} for p in PARTS}
    saved = obj.matrix_world.copy()
    biggest = 0.0
    for _round in range(rounds):
        obj.matrix_world = rig.matrix_world.copy()
        mod = obj.modifiers.new("ReliefArmature", "ARMATURE")
        mod.object = rig
        need = [0.0] * len(obj.data.vertices)
        try:
            rest_rig(rig)
            covered = covered_skin(body.build, rig, [obj])
            for _label, anim, t in poses:
                if anim is None:
                    rest_rig(rig)
                else:
                    pose_rig(rig, anim_at(anim, extreme_time(anim) if t is None else t))
                sp, sn, sf, sfp, svp = posed_skin(body.build, rig)
                tree = BVHTree.FromPolygons(sp, sf)
                gp, gf = evaluated_points(obj, rig)
                for i, p in enumerate(gp):
                    loc, nrm, fi, d = tree.find_nearest(p)
                    if loc is None or sfp[fi] not in near.get(main[i], ()):
                        continue
                    g = d if (p - loc).dot(nrm) >= 0 else -d
                    if g < margin:
                        need[i] = max(need[i], margin - g)
                gtree = BVHTree.FromPolygons(gp, gf)
                for si in covered:
                    p, n = sp[si], sn[si]
                    loc, fn, fi, d = gtree.ray_cast(p + n * 0.0005, -n, 0.2)
                    if loc is None or fn.dot(-n) >= 0:
                        continue
                    face = gf[fi]
                    for vi in face:
                        need[vi] = max(need[vi], d + margin)
        finally:
            obj.modifiers.remove(mod)
            rest_rig(rig)
            obj.matrix_world = saved
        # spread to the neighbours, then even it out (a gentle swell, never a dent or a bump)
        for _ in range(3):
            need = [max(n, 0.7 * max((need[j] for j in nbr[i]), default=0.0)) for i, n in enumerate(need)]
        for _ in range(4):
            need = [0.5 * n + 0.5 * (sum(need[j] for j in nbr[i]) / len(nbr[i]) if nbr[i] else n)
                    for i, n in enumerate(need)]
        tree = body.bvh("NoHands")
        moved = 0
        for i, v in enumerate(obj.data.vertices):
            n = min(cap, need[i])
            if n <= 1e-4:
                continue
            loc, nrm, _fi, _d = tree.find_nearest(v.co)
            v.co = v.co + nrm.normalized() * n
            biggest = max(biggest, n)
            moved += 1
        obj.data.update()
        if moved == 0:
            break
    return biggest


def push_clear(points, body, min_gap, region="NoHands"):
    """Moves every point that is closer than min_gap to the real skin (or inside it) straight out to min_gap.
    `points`: a list of Vectors (changed in place) or a mesh object (its vertices). Returns how many moved."""
    tree = body.bvh(region)
    moved = 0
    seq = [v.co for v in points.data.vertices] if hasattr(points, "data") else points
    for co in seq:
        loc, nrm, _i, d = tree.find_nearest(co)
        if loc is None:
            continue
        g = d if (co - loc).dot(nrm) >= 0 else -d
        if g < min_gap:
            new = loc + nrm.normalized() * min_gap
            co.x, co.y, co.z = new.x, new.y, new.z
            moved += 1
    if hasattr(points, "data"):
        points.data.update()
    return moved


def apply_kept_normals(o):
    """Sets the piece's normals from the whole garment's (point attribute "gearNormal", kept through the cuts), so the
    pieces shade as one surface; then drops the attribute."""
    me = o.data
    attr = me.attributes.get("gearNormal")
    if attr is None:
        return
    normals = [Vector(attr.data[i].vector).normalized() for i in range(len(me.vertices))]
    me.attributes.remove(attr)
    if any(p.use_smooth for p in me.polygons):
        me.normals_split_custom_set_from_vertices(normals)


def split_parts(obj, prefix, body, coll, material=None):
    """One mesh per body part (each face goes to its corners' main bone), named "<Build>_<prefix>__<Part>", parented
    to the rig with an armature modifier (the game format, WornGearFit.dressCartoon). The smooth shading of the whole
    piece is kept on every piece (no seam lines where it is cut)."""
    me = obj.data
    if any(p.use_smooth for p in me.polygons) and not me.has_custom_normals:
        me.normals_split_custom_set_from_vertices([v.normal for v in me.vertices])
    dom = [dominant_part(obj, i) for i in range(len(me.vertices))]
    by_part = {}
    for p in me.polygons:
        votes = {}
        for vi in p.vertices:
            votes[dom[vi]] = votes.get(dom[vi], 0) + 1
        by_part.setdefault(max(votes.items(), key=lambda kv: (kv[1], kv[0]))[0], []).append(p.index)
    pieces = []
    for part, polys in sorted(by_part.items()):
        # (a copy of the whole object keeps its vertex groups; building a new object from the cut mesh lost them)
        nm = "%s_%s__%s" % (body.build, prefix, part)
        o = obj.copy()
        o.data = me.copy()
        o.name = nm
        o.data.name = nm
        o.modifiers.clear()
        coll.objects.link(o)
        m2 = o.data
        bm = bmesh.new()
        bm.from_mesh(m2)
        keep = set(polys)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.to_mesh(m2)
        bm.free()
        m2.validate(verbose=False, clean_customdata=False)
        m2.materials.clear()
        if material:
            m2.materials.append(material)
        apply_kept_normals(o)
        o.parent = body.rig
        o.matrix_parent_inverse = Matrix.Identity(4)
        o.matrix_world = body.rig.matrix_world.copy()
        mod = o.modifiers.new("Armature", "ARMATURE")
        mod.object = body.rig
        pieces.append(o)
    bpy.data.objects.remove(obj, do_unlink=True)
    return pieces


# ---------------------------------------------------------------- posing with the real animations
_ANIM_CACHE = {}


def read_anim(name):
    """[(time, {part: Transform (Roblox space)})] from art/animations/<name>.rbxmx."""
    if name in _ANIM_CACHE:
        return _ANIM_CACHE[name]
    tree = ET.parse(os.path.join(ANIMS, name + ".rbxmx"))
    out = []
    for kf in tree.iter("Item"):
        if kf.get("class") != "Keyframe":
            continue
        t = float(kf.find("Properties/float[@name='Time']").text)
        poses = {}
        for pose in kf.iter("Item"):
            if pose.get("class") != "Pose":
                continue
            props = pose.find("Properties")
            part = props.find("string[@name='Name']").text
            cf = props.find("CoordinateFrame[@name='CFrame']")
            g = {c.tag: float(c.text) for c in cf}
            poses[part] = Matrix(((g["R00"], g["R01"], g["R02"], g["X"]), (g["R10"], g["R11"], g["R12"], g["Y"]),
                                  (g["R20"], g["R21"], g["R22"], g["Z"]), (0, 0, 0, 1)))
        out.append((t, poses))
    out.sort(key=lambda x: x[0])
    _ANIM_CACHE[name] = out
    return out


def anim_at(name, t):
    """The keyframe nearest to time t."""
    frames = read_anim(name)
    return min(frames, key=lambda f: abs(f[0] - t))[1]


def extreme_time(name):
    """The keyframe that bends the body most (sum of every joint's turn): where gear is tested hardest."""
    best, bt = -1.0, 0.0
    for t, poses in read_anim(name):
        s = sum(m.to_quaternion().angle for p, m in poses.items() if p in PARTS)
        if s > best:
            best, bt = s, t
    return bt


def rest_rig(rig):
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()


def pose_rig(rig, transforms):
    """Poses the rig as Roblox would: every part's world = parent's world * (joint offset) * Transform, the joints at
    the rig's own rest positions, the root part fixed where it stands (3.4 up). transforms: {part: Transform} as read
    from an animation (the Pose named after a part carries the Transform of the joint above it)."""
    J = {b.name: TO_B @ b.head_local for b in rig.data.bones}       # rest joints in Roblox space
    world = {"HumanoidRootNode": Matrix.Translation(J["HumanoidRootNode"])}
    order = ["LowerTorso", "UpperTorso"] + [s + p for s in ("Left", "Right") for p in
                                             ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")]
    for part in order:
        par = PARENT[part]
        world[part] = world[par] @ Matrix.Translation(J[part] - J[par]) @ transforms.get(part, Matrix.Identity(4))
    # rest -> posed, per bone, in the armature's space (Blender)
    posed = {}
    for b in rig.data.bones:
        if b.name in world and b.name != "HumanoidRootNode":
            delta = world[b.name] @ Matrix.Translation(-J[b.name])
            posed[b.name] = TO_B @ delta @ TO_B @ b.matrix_local
        else:
            posed[b.name] = b.matrix_local.copy()
    for pb in rig.pose.bones:
        b = pb.bone
        if b.parent:
            rel = b.parent.matrix_local.inverted() @ b.matrix_local
            pb.matrix_basis = rel.inverted() @ posed[b.parent.name].inverted() @ posed[b.name]
        else:
            pb.matrix_basis = b.matrix_local.inverted() @ posed[b.name]
    bpy.context.view_layer.update()
    return world


# The poses every piece is checked in (the hardest moment of each, found automatically unless a time is given).
CHECK_POSES = [
    ("Rest", None, None),
    ("SquatBottom", "Station_Squat", 1.9),
    ("BenchChest", "Station_Bench", 2.0),
    ("DeadliftBottom", "Station_Deadlift", 1.6),
    ("SquatSetup", "Setup_Squat", None),
    ("Walk", "Entrance_Walk_Swagger", None),
    ("WalkHeavy", "Entrance_Walk_Stomp", None),
    ("ArmsUp", "Celebrate_ArmsUpBounce", None),
    ("DoubleBiceps", "Emote_DoubleBiceps", None),
    ("CrouchRoar", "Celebrate_CrouchRoarJump", None),
]


def evaluated_points(obj, rig):
    """The object's points as drawn now (armature applied), in the rig's space."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    m = rig.matrix_world.inverted() @ obj.matrix_world
    pts = [m @ v.co for v in me.vertices]
    faces = [tuple(p.vertices) for p in me.polygons]
    ev.to_mesh_clear()
    return pts, faces


def posed_body_tree(build):
    rig = bpy.data.objects[build + "Rig"]
    verts, faces = [], []
    for part in PARTS:
        pts, fs = evaluated_points(bpy.data.objects[build + "_" + part], rig)
        base = len(verts)
        verts += pts
        faces += [tuple(base + i for i in f) for f in fs]
    return BVHTree.FromPolygons(verts, faces)


def clearance(build, items, poses=None, skip_parts=None):
    """items: {item name: [skinned piece objects]}. For each pose, per item: points inside the posed skin, split into
    OWN (inside the skin of the body part the point moves with: the body shows through: a real clip) and FOLD (inside
    another part pressed against it, e.g. a thigh folded onto the belly in a deep squat: hidden inside the fold, as
    on a real lifter), the closest own-part distance and the closest of all. skip_parts: {item: [body parts left out
    of its test, e.g. the hands for wrist wraps]}. Returns {pose: {item: dict}}."""
    rig = bpy.data.objects[build + "Rig"]
    poses = poses or CHECK_POSES
    report = {}
    # each point's main bone, from the piece's own weights (the evaluated mesh keeps the point order)
    mains = {}
    for pieces in items.values():
        for o in pieces:
            names = {g.index: g.name for g in o.vertex_groups}
            mains[o.name] = [max(((names.get(g.group), g.weight) for g in v.groups), key=lambda x: x[1],
                                 default=(None, 0))[0] for v in o.data.vertices]
    try:
        rest_rig(rig)
        covers = {item: covered_skin(build, rig, pieces) for item, pieces in items.items()}
        for label, anim, t in poses:
            if anim is None:
                rest_rig(rig)
            else:
                pose_rig(rig, anim_at(anim, extreme_time(anim) if t is None else t))
            trees = {}
            row = {}
            for item, pieces in items.items():
                skip = tuple((skip_parts or {}).get(item, ()))
                if skip not in trees:
                    keep = [p for p in PARTS if p not in skip]
                    verts, faces, fparts = [], [], []
                    for part in keep:
                        pts, fs = evaluated_points(bpy.data.objects[build + "_" + part], rig)
                        base = len(verts)
                        verts += pts
                        faces += [tuple(base + i for i in f) for f in fs]
                        fparts += [part] * len(fs)
                    trees[skip] = (BVHTree.FromPolygons(verts, faces), fparts)
                tree, fparts = trees[skip]
                own, fold, total, min_own, min_all = 0, 0, 0, 9.0, 9.0
                for o in pieces:
                    pts, _f = evaluated_points(o, rig)
                    main = mains[o.name]
                    for i, p in enumerate(pts):
                        loc, nrm, fi, d = tree.find_nearest(p)
                        if loc is None:
                            continue
                        total += 1
                        g = d if (p - loc).dot(nrm) >= 0 else -d
                        mine = fparts[fi] == main[i]
                        min_all = min(min_all, g)
                        if mine:
                            min_own = min(min_own, g)
                        if g < 0:
                            if mine:
                                own += 1
                            else:
                                fold += 1
                # skin it covers at rest coming out THROUGH its faces (between its points)
                gv, gfs = [], []
                for o in pieces:
                    pts, fs = evaluated_points(o, rig)
                    base = len(gv)
                    gv += pts
                    gfs += [tuple(base + i for i in f) for f in fs]
                pokes, poke_max = 0, 0.0
                if gfs and covers[item]:
                    if "skin" not in trees:
                        trees["skin"] = posed_skin(build, rig)
                    sp, sn = trees["skin"][0], trees["skin"][1]
                    gtree = BVHTree.FromPolygons(gv, gfs)
                    for si in covers[item]:
                        p, n = sp[si], sn[si]
                        loc, fn, _fi, d = gtree.ray_cast(p + n * 0.0005, -n, 0.2)
                        if loc is not None and fn.dot(-n) < 0 and d > 0.004:
                            pokes += 1
                            poke_max = max(poke_max, d)
                row[item] = {"own": own, "fold": fold, "total": total, "minOwn": round(min_own, 3),
                             "minAll": round(min_all, 3), "pokes": pokes, "pokeMax": round(poke_max, 3)}
            report[label] = row
    finally:
        rest_rig(rig)
    return report


def format_report(build, report):
    lines = []
    for label, row in report.items():
        cells = ["%s clip %d fold %d /%d min %+.3f (all %+.3f) skin-through %d (%.3f)" % (
            item, r["own"], r["fold"], r["total"], r["minOwn"], r["minAll"], r["pokes"], r["pokeMax"])
            for item, r in row.items()]
        lines.append("%s %-14s %s" % (build, label, " | ".join(cells)))
    return "\n".join(lines)


# ---------------------------------------------------------------- the picture set
VIEWS = {"front": Vector((0, -1, 0)), "back": Vector((0, 1, 0)), "left": Vector((1, 0, 0)), "right": Vector((-1, 0, 0))}


def shots(tag, per_build, views=("front", "back", "left", "right"), size=(360, 560), colour="MATERIAL",
          centre_z=2.95, scale=6.3, out_dir=None):
    """Renders every build from every view with one orthographic camera and the studio light, back faces hidden,
    and returns the image paths in a grid order [(build, view, path)]. per_build: {build: [objects to show]}."""
    scene = bpy.context.scene
    out_dir = out_dir or os.path.join(PREVIEWS, "gear03_tmp")
    os.makedirs(out_dir, exist_ok=True)
    saved = {o.name: o.hide_render for o in bpy.data.objects}
    cam_data = bpy.data.cameras.get("Gear03Cam") or bpy.data.cameras.new("Gear03Cam")
    cam = bpy.data.objects.get("Gear03Cam") or bpy.data.objects.new("Gear03Cam", cam_data)
    if cam.name not in scene.collection.objects:
        scene.collection.objects.link(cam)
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = scale
    cam_data.clip_end = 100
    old_cam, old_engine = scene.camera, scene.render.engine
    scene.camera = cam
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError as e:
        log("engine", e)
    sh = scene.display.shading
    sh.light = "STUDIO"
    sh.color_type = colour
    sh.show_backface_culling = True
    sh.show_cavity = True
    sh.cavity_type = "SCREEN"   # (world cavity darkens every cut between pieces: misleading)
    sh.show_shadows = False
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.16, 0.17, 0.2)
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    out = []
    try:
        for build, objs in per_build.items():
            show = {o.name for o in objs}
            for o in bpy.data.objects:
                if o.type in ("MESH", "CURVE", "FONT"):
                    o.hide_render = o.name not in show
            rig = bpy.data.objects[build + "Rig"]
            target = rig.matrix_world @ Vector((0, 0, centre_z))
            for view in views:
                d = VIEWS[view]
                cam.location = target + d * 20
                cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
                path = os.path.join(out_dir, "%s_%s_%s.png" % (tag, build, view))
                scene.render.filepath = path
                bpy.ops.render.render(write_still=True)
                out.append((build, view, path))
    finally:
        for name, h in saved.items():
            o = bpy.data.objects.get(name)
            if o:
                o.hide_render = h
        scene.camera = old_cam
        try:
            scene.render.engine = old_engine
        except TypeError:
            pass
    return out


def contact_sheet(images, path, cols=4):
    """Tiles the rendered images into one PNG (rows = builds, columns = views), with Blender's own image tools."""
    import numpy as np
    loaded = []
    for _b, _v, p in images:
        img = bpy.data.images.load(p, check_existing=False)
        w, h = img.size
        arr = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
        loaded.append(arr)
        bpy.data.images.remove(img)
    h, w = loaded[0].shape[:2]
    rows = (len(loaded) + cols - 1) // cols
    sheet = np.zeros((rows * h, cols * w, 4), dtype=np.float32)
    sheet[..., 3] = 1.0
    for i, arr in enumerate(loaded):
        r, c = i // cols, i % cols
        # Blender images start at the bottom row
        sheet[(rows - 1 - r) * h:(rows - r) * h, c * w:(c + 1) * w] = arr
    out = bpy.data.images.new("Gear03Sheet", cols * w, rows * h, alpha=True)
    out.pixels = sheet.ravel()
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    return path
