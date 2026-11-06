# Shapes for worn gear that must look rough and solid, not like a flat shell (user, 2026-11-06, on the rare suits: "way more
# texturized ... rough and 3d modeled ... cannot just be a flat plane"). Used by build_worn_gear_01.py.
#
#   relief   a garment's surface pushed in and out by a function: creases, rolls, pleats, grooves
#   rope     a tube along a line: piping on a seam, a rolled hem, a thick collar, a thread line
#   stitches a row of raised thread dashes
#   ridge    one crease, for use inside a relief function
#
# Points are in Blender axes unless a function says Roblox. PERFORMANCE: every helper's triangle count grows with its
# points, so callers keep them low. As worn (measured 2026-11-06): a suit about 10,000 triangles, a bench shirt about 12,000 and
# knee wraps about 3,600, against a singlet's 2,500 and sleeves' 2,600.
import math

from mathutils import Vector


def relief(bm, P, cols, rows_of, disp, include=None):
    """An open outer surface round `cols`. rows_of(i) lists heights bottom to top (the same count for every column);
    disp(c, y) is how far out from the column's own position; include(i, k) keeps a cell. Faces point outward."""
    n = len(cols)
    rows = len(rows_of(0)) - 1
    verts = {}

    def v(i, k):
        key = (i % n, k)
        if key not in verts:
            c = cols[i % n]
            y = rows_of(i % n)[k]
            d = disp(c, y)
            verts[key] = bm.verts.new(P(c["x"] + c["nx"] * d, y, c["z"] + c["nz"] * d))
        return verts[key]

    for i in range(n):
        for k in range(rows):
            if include is None or include(i, k):
                face = bm.faces.new((v(i, k), v(i + 1, k), v(i + 1, k + 1), v(i, k + 1)))
                face.normal_update()
                c = cols[i]
                if face.normal.dot(Vector((-c["nx"], c["nz"], 0))) < 0:
                    face.normal_flip()


def _frames(points, closed):
    """A steady pair of side directions along a line, so a rope doesn't twist."""
    n = len(points)
    tangents = []
    for i in range(n):
        a = points[(i - 1) % n] if closed or i > 0 else points[i]
        b = points[(i + 1) % n] if closed or i < n - 1 else points[i]
        tangents.append((b - a).normalized())
    start = Vector((0, 0, 1)) if abs(tangents[0].z) < 0.9 else Vector((1, 0, 0))
    side = tangents[0].cross(start).normalized()
    result = []
    for t in tangents:
        side = (side - t * side.dot(t)).normalized()
        result.append((side, t.cross(side).normalized()))
    return result


def rope(bm, points, radius, sides=5, closed=False):
    """A closed tube along `points` (Blender axes): capped ends, or joined into a ring with closed=True."""
    if len(points) < 2:
        return
    frames = _frames(points, closed)
    rings = []
    for p, (a, b) in zip(points, frames):
        ring_verts = []
        for k in range(sides):
            angle = 2 * math.pi * k / sides
            ring_verts.append(bm.verts.new(p + (a * math.cos(angle) + b * math.sin(angle)) * radius))
        rings.append(ring_verts)
    faces = []
    count = len(points)
    for i in range(count if closed else count - 1):
        here, there = rings[i], rings[(i + 1) % count]
        for k in range(sides):
            faces.append(bm.faces.new((here[k], here[(k + 1) % sides], there[(k + 1) % sides], there[k])))
    if not closed:
        faces.append(bm.faces.new(rings[0]))
        faces.append(bm.faces.new(list(reversed(rings[-1]))))
    import bmesh  # noqa: PLC0415 (only inside Blender)
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def strap(bm, points, width, thick):
    """A solid strap along `points` (Blender axes, a line in the Y-Z plane): as wide as `width` across X, `thick` through,
    its long edges chamfered. Real thickness you can see from the side, and closed so it is solid from every angle."""
    frames = []
    for i, p in enumerate(points):
        a = points[max(i - 1, 0)]
        b = points[min(i + 1, len(points) - 1)]
        tangent = (b - a).normalized()
        frames.append(Vector((1, 0, 0)).cross(tangent).normalized())
    half, depth, bevel = width / 2, thick / 2, min(thick * 0.35, width * 0.2)
    outline = [(-half + bevel, -depth), (half - bevel, -depth), (half, -depth + bevel), (half, depth - bevel),
               (half - bevel, depth), (-half + bevel, depth), (-half, depth - bevel), (-half, -depth + bevel)]
    rings = []
    for p, up in zip(points, frames):
        rings.append([bm.verts.new(p + Vector((x, 0, 0)) + up * y) for x, y in outline])
    faces = []
    m = len(outline)
    for here, there in zip(rings, rings[1:]):
        for k in range(m):
            faces.append(bm.faces.new((here[k], here[(k + 1) % m], there[(k + 1) % m], there[k])))
    faces.append(bm.faces.new(rings[0]))
    faces.append(bm.faces.new(list(reversed(rings[-1]))))
    import bmesh  # noqa: PLC0415 (only inside Blender)
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def stitches(bm, points, dash=0.055, gap=0.04, radius=0.012):
    """Raised thread dashes along a line (Blender axes). Each dash is 12 triangles, so keep the rows short."""
    position = 0.0
    want_start = 0.0
    for a, b in zip(points, points[1:]):
        length = (b - a).length
        if length < 1e-6:
            continue
        direction = (b - a) / length
        while want_start < position + length:
            start = max(want_start, position)
            stop = min(want_start + dash, position + length)
            if stop > start + 1e-4:
                rope(bm, [a + direction * (start - position), a + direction * (stop - position)], radius, 4)
            want_start += dash + gap
        position += length


def ridge(x, y, ax, ay, bx, by, width):
    """How much of a crease along the line (ax, ay)-(bx, by) is at (x, y): 1 on it, fading to 0 by `width` away and at its
    ends. Soft, so several can be added together."""
    dx, dy = bx - ax, by - ay
    length_sq = dx * dx + dy * dy
    t = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / length_sq))
    distance = math.hypot(x - (ax + dx * t), y - (ay + dy * t))
    across = max(0.0, 1 - distance / width)
    return across * across * (3 - 2 * across) * math.sin(math.pi * t)


def grain(s, y, seed=0.0):
    """Small uneven lumps in stiff cloth, about -1 to 1."""
    return (math.sin(11.0 * s + 6.0 * y + seed) * 0.45 + math.sin(23.0 * s - 13.0 * y + seed * 2.1) * 0.3
            + math.sin(5.0 * s + 19.0 * y + seed * 0.7) * 0.25)
