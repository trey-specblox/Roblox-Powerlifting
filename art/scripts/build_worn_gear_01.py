# Builds WornGear_01 in the live Blender scene: the Shop's gear as WORN on a Roblox R15 body (GAME_DESIGN.md
# 30.6, the money system's step 5a; user 2026-10-30: all four kinds are 3D models, the singlet too, R15 only,
# always visible). The Shop previews (build_shop_gear_01.py) stay as they are; these are new models that fit
# the body, in the same colour pieces, so ShopConfig's colours apply to them too.
#
# Fitted to the default R15 body measured in Studio (CreateHumanoidModelFromDescription, 2026-10-30): its
# parts are rounded boxes about 1 stud across, so each piece is a rounded-box tube a little outside one body
# part. The game (step 5b) welds each piece to its part and scales it with the part's size.
#
# Units: 1 Blender unit = 1 stud. Blender is Z-up, front toward -Y (prop_helpers). P() turns a point given
# relative to the HumanoidRootPart in Roblox axes (X = the character's right, Y up, -Z its front) into
# Blender. Limb pieces are built on the RIGHT limb only and used on both (they are symmetric, one mesh each).
#
# Object names: "Worn<Item>_<Colour>[_<Segment>]". <Colour> is the ShopConfig colour key (LeverBelt_Outer ->
# WornLeverBelt_Outer); <Segment> says which body part a split item sits on (a knee sleeve is two halves, one
# on the thigh and one on the shin, so it bends with the knee). Each object keeps "body_part" (the R15 part
# it is welded to) and the script prints every piece's offset from its part's centre, for step 5b.
#
#   WornLeverBelt   Outer, Lining (a thin edge above and below), Stitch, Lever, Text     LowerTorso
#   WornKneeSleeve  Body_Upper, Stripes_Upper (thigh), Body_Lower, Patch_Lower (shin)   Upper/LowerLeg
#   WornWristWrap   Body (the wide wrap and its loose end), Stripes, Text                LowerArm
#
# Look (user's reference photos, 2026-10-31; see the "worn-gear-style" memory): the belt is chunky and stands
# out (a thick band with rounded, bulging edges, a big steel lever); a knee sleeve reads as ONE tube from
# mid-thigh to mid-shin with no step at the knee, a diagonal stripe down the side and a bold logo low on the
# front; the wraps cover the whole wrist.
#   WornSinglet     Black_Upper, Red_Upper (side panels), Trim_Upper (neck, armholes,
#                   straps), Patch_Upper (UpperTorso); Black_Lower, Red_Lower
#                   (LowerTorso); Shorts_Leg, ShortsRed_Leg (UpperLeg)
#
# A fully dressed player wears 29 small pieces (belt 5, sleeves 4 x 2, wraps 3 x 2, singlet 6 + 2 x 2): no
# collision, no shadows (step 5b).
#
# The "Preview" collection (skipped by check_models.py) holds a reference R15 body and four dressed figures in
# Shop colours, one of them squatting, for the user's approval. Run in an empty file.
import importlib
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

SCRIPTS = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\Powerlifting Roblox\art\scripts"
sys.path.insert(0, SCRIPTS)
import prop_helpers as H  # noqa: E402

importlib.reload(H)

B = H.Builder("WornGear_01")
BRAND = H.BRAND


def P(x, y, z):
    """Roblox axes, relative to the HumanoidRootPart -> Blender."""
    return Vector((-x, z, y))


def to_roblox(v):
    return Vector((-v.x, v.z, v.y))


def lin(r, g, b):
    """An sRGB colour (0-255, as ShopConfig) -> Blender's linear colour."""
    def one(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (one(r), one(g), one(b))


MAT = {
    "Black": H.material("WG_Black", lin(24, 24, 26), roughness=0.9),
    "Red": H.material("WG_Red", lin(190, 28, 36), roughness=0.85),
    "RedPrint": H.material("WG_RedPrint", lin(210, 32, 40), roughness=0.5),
    "Grey": H.material("WG_Grey", lin(78, 78, 82), roughness=0.9),
    "Steel": H.material("WG_Steel", lin(150, 152, 158), metallic=1.0, roughness=0.35),
    "White": H.material("WG_White", lin(238, 238, 238), roughness=0.5),
    "Skin": H.material("WG_PreviewBody", lin(196, 186, 170), roughness=0.7),
}

# ------------------------------------------------------------------ the R15 body (default, measured 2026-10-30)
# size (X, Y, Z in Roblox) and centre relative to the HumanoidRootPart.
BODY = {
    "Head": ((1.159, 1.182, 1.161), (0, 1.674, 0)),
    "UpperTorso": ((1.943, 1.698, 1.004), (0, 0.249, 0)),
    "LowerTorso": ((1.991, 0.401, 1.004), (0, -0.800, 0)),
    "UpperArm": ((1.001, 1.242, 1.002), (1.472, 0.428, 0)),
    "LowerArm": ((1.001, 1.118, 1.002), (1.472, -0.202, 0)),
    "Hand": ((0.984, 0.316, 1.028), (1.472, -0.866, 0)),
    "UpperLeg": ((0.993, 1.363, 0.973), (0.500, -1.471, 0)),
    "LowerLeg": ((0.993, 1.301, 0.973), (0.500, -2.334, 0)),
    "Foot": ((1.009, 0.312, 1.001), (0.500, -3.036, 0)),
}
LIMBS = ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")
# Joints (rig attachments), Roblox axes.
HIP_Y, KNEE_Y, ANKLE_Y = -1.000, -1.921, -2.930
SHOULDER = (0.972, 0.847)


def r15_name(part, side):
    return (side + part) if part in LIMBS else part


# ------------------------------------------------------------------ shells round a rounded box
def ring(hx, hz, r, cx=0.0, cz=0.0, step=10.0, corner=4):
    """Columns round a rounded rectangle (half sizes hx, hz, corner radius r) in the Roblox X-Z plane, starting
    on the front (-Z) and running round. Each: position, local position, outward normal, distance round (s).
    PERFORMANCE: a flat side needs no columns between its ends, so by default each straight side is one cell
    and only the corners have more; pass a small `step` where the shell's top must follow a curve."""
    raw = []

    def straight(a, b, n):
        length = (b - a).length
        if length < 1e-9:
            return
        k = max(1, math.ceil(length / step))
        for i in range(k):
            raw.append((a + (b - a) * (i / k), n))

    def arc(c, a0, a1):
        for i in range(corner):
            a = a0 + (a1 - a0) * i / corner
            n = Vector((math.cos(a), math.sin(a)))
            raw.append((c + n * r, n))

    ix, iz = hx - r, hz - r
    straight(Vector((-ix, -hz)), Vector((ix, -hz)), Vector((0, -1)))
    arc(Vector((ix, -iz)), -math.pi / 2, 0)
    straight(Vector((hx, -iz)), Vector((hx, iz)), Vector((1, 0)))
    arc(Vector((ix, iz)), 0, math.pi / 2)
    straight(Vector((ix, hz)), Vector((-ix, hz)), Vector((0, 1)))
    arc(Vector((-ix, iz)), math.pi / 2, math.pi)
    straight(Vector((-hx, iz)), Vector((-hx, -iz)), Vector((-1, 0)))
    arc(Vector((-ix, -iz)), math.pi, 3 * math.pi / 2)
    cols, s = [], 0.0
    for i, (p, n) in enumerate(raw):
        if i:
            s += (p - raw[i - 1][0]).length
        cols.append({"x": cx + p.x, "z": cz + p.y, "lx": p.x, "lz": p.y, "nx": n.x, "nz": n.y, "s": s})
    return cols


def cell_solid(bm, cols, heights, thickness, include):
    """A closed solid made of the cells of a shell round `cols`. heights[i] is the list of heights (bottom to top,
    the same count for every column) of column i; cell (i, k) runs from column i to the next and from height k to
    k + 1, and is kept when include(i, k). The surface is the columns; the solid goes `thickness` inward."""
    n, rows = len(cols), len(heights[0]) - 1
    verts, faces = {}, []

    def v(i, k, inner):
        key = (i % n, k, inner)
        if key not in verts:
            c, t = cols[i % n], (thickness if inner else 0.0)
            verts[key] = bm.verts.new(P(c["x"] - c["nx"] * t, heights[i % n][k], c["z"] - c["nz"] * t))
        return verts[key]

    def kept(i, k):
        return 0 <= k < rows and include(i % n, k)

    def face(*corners):
        faces.append(bm.faces.new(corners))

    for i in range(n):
        for k in range(rows):
            if not kept(i, k):
                continue
            face(v(i, k, 0), v(i + 1, k, 0), v(i + 1, k + 1, 0), v(i, k + 1, 0))
            face(v(i, k, 1), v(i, k + 1, 1), v(i + 1, k + 1, 1), v(i + 1, k, 1))
            if not kept(i, k - 1):
                face(v(i, k, 0), v(i, k, 1), v(i + 1, k, 1), v(i + 1, k, 0))
            if not kept(i, k + 1):
                face(v(i, k + 1, 0), v(i + 1, k + 1, 0), v(i + 1, k + 1, 1), v(i, k + 1, 1))
            if not kept(i - 1, k):
                face(v(i, k, 0), v(i, k + 1, 0), v(i, k + 1, 1), v(i, k, 1))
            if not kept(i + 1, k):
                face(v(i + 1, k, 0), v(i + 1, k, 1), v(i + 1, k + 1, 1), v(i + 1, k + 1, 0))
    # Whichever way the columns run, turn every face outward (Roblox draws one side only).
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def band(bm, cols, y0, y1, thickness, include=lambda i, k: True):
    """A straight band of the shell between two heights."""
    cell_solid(bm, cols, [[y0, y1]] * len(cols), thickness, include)


def swept(bm, hx, hz, r, profile, cx=0.0, cz=0.0):
    """A closed solid round a rounded box: `profile` is a closed outline of (offset out from the box, height)
    points, swept all the way round (so a band can have rounded, bulging edges)."""
    rings = [ring(hx + off, hz + off, r + off, cx, cz) for off, _ in profile]
    n, m = len(rings[0]), len(profile)
    assert all(len(rg) == n for rg in rings), "every ring needs the same columns"
    verts = [[bm.verts.new(P(rings[k][i]["x"], profile[k][1], rings[k][i]["z"])) for k in range(m)] for i in range(n)]
    faces = []
    for i in range(n):
        for k in range(m):
            faces.append(bm.faces.new((verts[i][k], verts[(i + 1) % n][k], verts[(i + 1) % n][(k + 1) % m],
                                       verts[i][(k + 1) % m])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def side_slab(bm, x, corners, thickness):
    """A thin flat piece on a side face (Roblox x = `x`), its outline `corners` given as (z, y) points."""
    out = 1 if x > 0 else -1
    low = [bm.verts.new(P(x, y, z)) for z, y in corners]
    high = [bm.verts.new(P(x + out * thickness, y, z)) for z, y in corners]
    k = len(corners)
    faces = [bm.faces.new(low), bm.faces.new(list(reversed(high)))]
    for i in range(k):
        faces.append(bm.faces.new((low[i], low[(i + 1) % k], high[(i + 1) % k], high[i])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def is_side(cols, i, limit=0.85):
    """The cell from column i to the next faces sideways (the side panels)."""
    a, b = cols[i], cols[(i + 1) % len(cols)]
    nx, nz = a["nx"] + b["nx"], a["nz"] + b["nz"]
    return abs(nx) > limit * math.hypot(nx, nz)


PART_OF = {}


def piece(name, part, mat, build):
    obj = B.piece(name, mat, build)
    obj["body_part"] = part
    PART_OF[name] = part
    return obj


def part_box(part):
    (sx, sy, sz), (x, y, z) = BODY[part]
    return sx / 2, sy / 2, sz / 2, x, y, z


def badge(bm, cx_b, y_front, z_mid, width, height, line, depth=0.012):
    """A rectangular outline on a flat face looking toward -Y (Blender), its back on y_front."""
    hw, hh = width / 2, height / 2
    for zz in (z_mid - hh, z_mid + hh - line):
        H.span(bm, (cx_b - hw, y_front - depth, zz), (cx_b + hw, y_front, zz + line))
    for xx in (cx_b - hw, cx_b + hw - line):
        H.span(bm, (xx, y_front - depth, z_mid - hh + line), (xx + line, y_front, z_mid + hh - line))


# =================================================================== WornLeverBelt (LowerTorso)
# A thick lever belt round the waist, over the singlet: tall (0.62 stud), standing well out from the body
# (0.17 stud at its middle) with rounded, bulging edges, a red lining edge, two rows of stitching and a big
# steel lever buckle on the front.
hx, hy, hz, _, cy, _ = part_box("LowerTorso")
BELT_IN, BELT_R = 0.075, 0.2
BELT_LOW, BELT_HIGH = cy - 0.31, cy + 0.31
BELT_PROFILE = [(BELT_IN, BELT_LOW), (0.12, BELT_LOW), (0.15, BELT_LOW + 0.025), (0.165, BELT_LOW + 0.07), (0.17, cy),
                (0.165, BELT_HIGH - 0.07), (0.15, BELT_HIGH - 0.025), (0.12, BELT_HIGH), (BELT_IN, BELT_HIGH)]
piece("WornLeverBelt_Outer", "LowerTorso", MAT["Black"], lambda bm: swept(bm, hx, hz, BELT_R, BELT_PROFILE))
# The lining shows as a thin edge above and below the belt, on its inside.
piece("WornLeverBelt_Lining", "LowerTorso", MAT["Red"],
      lambda bm: band(bm, ring(hx + 0.082, hz + 0.082, BELT_R + 0.082), BELT_LOW - 0.016, BELT_HIGH + 0.016, 0.02))


def belt_stitch(bm):
    stitch_ring = ring(hx + 0.168, hz + 0.168, BELT_R + 0.168)
    for y in (BELT_LOW + 0.07, BELT_HIGH - 0.07):
        band(bm, stitch_ring, y - 0.007, y + 0.007, 0.01)


piece("WornLeverBelt_Stitch", "LowerTorso", MAT["Grey"], belt_stitch)
BELT_FRONT = -(hz + 0.17)  # the belt's front, at its middle (Roblox Z)
LEVER_FACE = BELT_FRONT - 0.05 - 0.06


def belt_lever(bm):
    H.rounded_box(bm, P(0, cy, BELT_FRONT - 0.02), (0.62, 0.06, 0.46), 0.02)              # base plate
    H.rounded_box(bm, P(-0.03, cy, BELT_FRONT - 0.05 - 0.03), (0.5, 0.06, 0.34), 0.025)   # lever
    H.rounded_box(bm, P(0.3, cy, BELT_FRONT - 0.045), (0.08, 0.09, 0.42), 0.02)           # hinge


piece("WornLeverBelt_Lever", "LowerTorso", MAT["Steel"], belt_lever)
piece("WornLeverBelt_Text", "LowerTorso", MAT["Black"],
      lambda bm: B.add_text(bm, BRAND, 0.085, 0.004, H.on_front(P(-0.03, 0, 0), LEVER_FACE + 0.002, cy)))

# =================================================================== WornKneeSleeve (UpperLeg + LowerLeg)
# A 7 mm neoprene sleeve from the singlet's leg to mid-shin. It is two pieces so it bends with the knee (the top
# on the thigh, the bottom on the shin), but they are the same size and meet exactly at the knee, so standing it
# is one smooth tube. Each piece has a collar, very nearly as big as the sleeve, reaching past the knee into
# the other piece: hidden inside it when the leg is straight, it fills the opening when the knee bends (many
# avatars' idle poses bend the knees about 30 degrees; a squat far more).
lhx, _, lhz, lcx, _, lcz = part_box("UpperLeg")
SLEEVE_OFF, SLEEVE_R, SLEEVE_T = 0.06, 0.17, 0.035
SLEEVE_TOP, SLEEVE_BOTTOM = KNEE_Y + 0.42, KNEE_Y - 0.46  # the top tucks under the singlet's leg
sleeve_ring = ring(lhx + SLEEVE_OFF, lhz + SLEEVE_OFF, SLEEVE_R, lcx, lcz)
COLLAR_OFF, COLLAR_REACH = 0.054, 0.22
collar_ring = ring(lhx + COLLAR_OFF, lhz + COLLAR_OFF, SLEEVE_R - (SLEEVE_OFF - COLLAR_OFF), lcx, lcz)


def sleeve_upper(bm):
    band(bm, sleeve_ring, KNEE_Y, SLEEVE_TOP, SLEEVE_T)
    band(bm, collar_ring, KNEE_Y - COLLAR_REACH, KNEE_Y + 0.02, 0.025)


piece("WornKneeSleeve_Body_Upper", "UpperLeg", MAT["Black"], sleeve_upper)


def sleeve_lower(bm):
    band(bm, sleeve_ring, SLEEVE_BOTTOM, KNEE_Y, SLEEVE_T)
    band(bm, collar_ring, KNEE_Y - 0.02, KNEE_Y + COLLAR_REACH, 0.025)


piece("WornKneeSleeve_Body_Lower", "LowerLeg", MAT["Black"], sleeve_lower)


def sleeve_stripes(bm):
    # A diagonal stripe down each side, from the front near the top toward the back by the knee (both sides,
    # so one mesh fits both legs).
    flat = lhz + SLEEVE_OFF - SLEEVE_R - 0.01
    top, bottom, half = SLEEVE_TOP - 0.07, KNEE_Y + 0.06, 0.035
    for side in (-1, 1):
        x = lcx + side * (lhx + SLEEVE_OFF + 0.002)
        side_slab(bm, x, [(-flat, top + half), (flat, bottom + half), (flat, bottom - half), (-flat, top - half)], 0.01)


piece("WornKneeSleeve_Stripes_Upper", "UpperLeg", MAT["Red"], sleeve_stripes)
SLEEVE_FRONT = -(lhz + SLEEVE_OFF)
PATCH_Y = KNEE_Y - 0.28


def sleeve_patch(bm):
    badge(bm, -lcx, SLEEVE_FRONT, PATCH_Y, 0.66, 0.21, 0.028)
    B.add_text(bm, BRAND, 0.115, 0.004, H.on_front(P(lcx, 0, 0), SLEEVE_FRONT, PATCH_Y))


piece("WornKneeSleeve_Patch_Lower", "LowerLeg", MAT["RedPrint"], sleeve_patch)

# =================================================================== WornWristWrap (LowerArm)
# A wide, thick wrap that covers the whole wrist, from over the top of the hand well up the forearm, with
# rounded edges, its loose end on the front (the same colour as the wrap: ShopConfig's Tail is always the Body
# colour), a thin stripe along each edge and the brand on the loose end.
ahx, _, ahz, acx, _, acz = part_box("LowerArm")
WRAP_R, WRAP_LOW, WRAP_HIGH = 0.14, -0.86, -0.30
WRAP_PROFILE = [(0.035, WRAP_LOW), (0.07, WRAP_LOW), (0.095, WRAP_LOW + 0.025), (0.105, WRAP_LOW + 0.07),
                (0.105, WRAP_HIGH - 0.07), (0.095, WRAP_HIGH - 0.025), (0.07, WRAP_HIGH), (0.035, WRAP_HIGH)]
WRAP_FRONT = -(ahz + 0.105)
TAIL_Y = (WRAP_LOW + WRAP_HIGH) / 2
TAIL_FRONT = WRAP_FRONT - 0.045  # the loose end's front face


def wrap_body(bm):
    swept(bm, ahx, ahz, WRAP_R, WRAP_PROFILE, acx, acz)
    H.rounded_box(bm, P(acx, TAIL_Y, WRAP_FRONT - 0.0175), (0.6, 0.055, 0.3), 0.015)  # the loose end


piece("WornWristWrap_Body", "LowerArm", MAT["Black"], wrap_body)


def wrap_stripes(bm):
    edge_ring = ring(ahx + 0.106, ahz + 0.106, WRAP_R + 0.106, acx, acz)
    for y in (WRAP_LOW + 0.085, WRAP_HIGH - 0.11):
        band(bm, edge_ring, y, y + 0.025, 0.012)


piece("WornWristWrap_Stripes", "LowerArm", MAT["Red"], wrap_stripes)
piece("WornWristWrap_Text", "LowerArm", MAT["White"],
      lambda bm: B.add_text(bm, BRAND, 0.11, 0.003, H.on_front(P(acx, 0, 0), TAIL_FRONT + 0.001, TAIL_Y)))

# =================================================================== WornSinglet
# The one-piece meet singlet (user's photo, 2026-10-23): a high round neck, deep armholes and straps over the
# shoulders, red trim round every opening and over the straps, red panels down the sides of the body and the
# legs, mid-thigh legs, the CENTRAL badge on the chest. The UpperTorso shell's top follows the openings
# (each column's top is the neckline, the strap or the armhole), so its edges are smooth.
thx, thy, thz, _, tcy, _ = part_box("UpperTorso")
OFF = 0.03
GARMENT_T = 0.012
TOP = tcy + thy + OFF          # the shoulders' top (the straps)
ARMHOLE_LOW = 0.30             # how far down the side the armhole goes
STRAP_IN, STRAP_OUT = 0.40, 0.68
NECK_FRONT, NECK_BACK, TRIM = 0.20, 0.10, 0.06
R_TORSO = 0.15
torso = ring(thx + OFF, thz + OFF, R_TORSO, step=0.08)


def singlet_tops(cols, hx, hz, r):
    ix, iz = hx - r, hz - r
    lf, lc, ls = 2 * ix, math.pi * r / 2, 2 * iz
    perimeter = 2 * lf + 2 * ls + 4 * lc
    s_right = lf + lc + ls / 2
    s_left = s_right + perimeter / 2
    reach = ls / 2 + lc + (ix - STRAP_OUT)

    def round_trip(v):
        v %= perimeter
        return min(v, perimeter - v)

    tops = []
    for c in cols:
        d = min(round_trip(c["s"] - s_right), round_trip(c["s"] - s_left))
        if d < reach:
            top = TOP - (TOP - ARMHOLE_LOW) * math.sqrt(1 - (d / reach) ** 2)
        elif abs(c["lx"]) < STRAP_IN:
            top = TOP - (NECK_FRONT if c["lz"] < 0 else NECK_BACK) * (1 - (c["lx"] / STRAP_IN) ** 2)
        else:
            top = TOP
        tops.append(top)
    return tops


tops = singlet_tops(torso, thx + OFF, thz + OFF, R_TORSO)
torso_heights = [[tcy - thy - 0.02, top - TRIM, top] for top in tops]
piece("WornSinglet_Black_Upper", "UpperTorso", MAT["Black"],
      lambda bm: cell_solid(bm, torso, torso_heights, GARMENT_T, lambda i, k: k == 0 and not is_side(torso, i)))
piece("WornSinglet_Red_Upper", "UpperTorso", MAT["Red"],
      lambda bm: cell_solid(bm, torso, torso_heights, GARMENT_T, lambda i, k: k == 0 and is_side(torso, i)))


def singlet_trim(bm):
    cell_solid(bm, torso, torso_heights, GARMENT_T, lambda i, k: k == 1)
    # The straps over the shoulders, front edge to back edge.
    for side in (-1, 1):
        H.span(bm, P(side * STRAP_IN, TOP - GARMENT_T, -(thz + OFF)), P(side * STRAP_OUT, TOP, thz + OFF))


piece("WornSinglet_Trim_Upper", "UpperTorso", MAT["Red"], singlet_trim)
CHEST_FRONT = -(thz + OFF)
CHEST_Y = 0.52


def singlet_patch(bm):
    badge(bm, 0.0, CHEST_FRONT, CHEST_Y, 0.72, 0.22, 0.03)
    B.add_text(bm, BRAND, 0.13, 0.004, H.on_front(P(0, 0, 0), CHEST_FRONT, CHEST_Y))


piece("WornSinglet_Patch_Upper", "UpperTorso", MAT["RedPrint"], singlet_patch)

# The LowerTorso shell, a little bigger than the UpperTorso one where they overlap at the waist (no flicker).
lthx, lthy, lthz, _, ltcy, _ = part_box("LowerTorso")
hips = ring(lthx + 0.04, lthz + 0.04, 0.13)
piece("WornSinglet_Black_Lower", "LowerTorso", MAT["Black"],
      lambda bm: band(bm, hips, ltcy - lthy - 0.02, ltcy + lthy + 0.04, GARMENT_T, lambda i, k: not is_side(hips, i)))
piece("WornSinglet_Red_Lower", "LowerTorso", MAT["Red"],
      lambda bm: band(bm, hips, ltcy - lthy - 0.02, ltcy + lthy + 0.04, GARMENT_T, lambda i, k: is_side(hips, i)))

# The legs, from inside the hips to mid-thigh, with the side panels down both sides (one mesh for both legs).
thigh = ring(lhx + OFF, lhz + OFF, 0.12, lcx, lcz)
piece("WornSinglet_Shorts_Leg", "UpperLeg", MAT["Black"],
      lambda bm: band(bm, thigh, -1.52, HIP_Y + 0.05, GARMENT_T, lambda i, k: not is_side(thigh, i)))
piece("WornSinglet_ShortsRed_Leg", "UpperLeg", MAT["Red"],
      lambda bm: band(bm, thigh, -1.52, HIP_Y + 0.05, GARMENT_T, lambda i, k: is_side(thigh, i)))

WORN = [o for o in B.coll.objects if o.name.startswith("Worn")]

# =================================================================== preview (not exported)
preview = bpy.data.collections.get("Preview")
if preview is None:
    preview = bpy.data.collections.new("Preview")
    bpy.context.scene.collection.children.link(preview)
for old in list(preview.objects):
    bpy.data.objects.remove(old, do_unlink=True)
for mesh in [m for m in bpy.data.meshes if m.users == 0]:
    bpy.data.meshes.remove(mesh)


def body_mesh(part):
    name = "PreviewBody_" + part
    mesh = bpy.data.meshes.get(name)
    if mesh is None:
        (sx, sy, sz), _ = BODY[part]
        bm = bmesh.new()
        H.rounded_box(bm, Vector((0, 0, 0)), (sx, sz, sy), 0.12 if part == "Head" else 0.06)
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(MAT["Skin"])
    return mesh


variant_mats = {}


def variant(colour):
    key = tuple(colour)
    if key not in variant_mats:
        variant_mats[key] = H.material("WG_Preview_%d_%d_%d" % key, lin(*colour), roughness=0.8)
    return variant_mats[key]


def rot_x(degrees, pivot):
    return Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(degrees), 4, "X") @ Matrix.Translation(-pivot)


def pose_matrix(part, side, pose):
    sx = 1 if side == "Right" else -1
    lean = rot_x(pose.get("lean", 0), P(0, HIP_Y, 0))
    if part in ("Head", "UpperTorso", "LowerTorso"):
        return lean
    if part in ("UpperArm", "LowerArm", "Hand"):
        return lean @ rot_x(pose.get("shoulder", 0), P(sx * SHOULDER[0], SHOULDER[1], 0))
    m = rot_x(pose.get("thigh", 0), P(sx * 0.5, HIP_Y, 0))
    if part in ("LowerLeg", "Foot"):
        m = m @ rot_x(pose.get("knee", 0), P(sx * 0.5, KNEE_Y, 0))
    if part == "Foot":
        m = m @ rot_x(pose.get("ankle", 0), P(sx * 0.5, ANKLE_Y, 0))
    return m


def figure(label, offset, colours, pose=None, with_worn=False):
    """A reference body wearing the gear: `colours` maps Worn<Item> -> ShopConfig colour key -> sRGB (missing keys
    keep the model's own colours). with_worn: the exported pieces themselves already stand here (the right limbs)."""
    pose = pose or {}
    foot = pose_matrix("Foot", "Right", pose) @ P(0.5, -3.192, 0)
    shift = Matrix.Translation(Vector(offset) + Vector((0, 0, -3.192 - foot.z)))
    for part in BODY:
        for side in (("Right", "Left") if part in LIMBS else ("",)):
            (_, _, _), (x, y, z) = BODY[part]
            centre = P(x if side != "Left" else -x, y, z)
            ob = bpy.data.objects.new(f"Preview_{label}_{side}{part}", body_mesh(part))
            preview.objects.link(ob)
            ob.matrix_world = shift @ pose_matrix(part, side or "Right", pose) @ Matrix.Translation(centre)
    for src in WORN:
        part = PART_OF[src.name]
        for side in (("Right", "Left") if part in LIMBS else ("",)):
            if with_worn and side != "Left":
                continue
            loc = src.location.copy()
            if side == "Left":
                loc.x = -loc.x
            ob = bpy.data.objects.new(f"Preview_{label}_{side}_{src.name}", src.data)
            preview.objects.link(ob)
            ob.matrix_world = shift @ pose_matrix(part, side or "Right", pose) @ Matrix.Translation(loc)
            item, key = src.name.split("_")[:2]
            colour = colours.get(item, {}).get(key)
            if colour:
                ob.material_slots[0].link = "OBJECT"
                ob.material_slots[0].material = variant(colour)


# Shop colours (ShopConfig.luau), per item: Worn<Item> -> colour key -> sRGB.
BLACK, WHITE, STEEL = (22, 22, 24), (238, 238, 238), (150, 152, 158)
GOLD, NAVY, YELLOW, TEAL = (214, 170, 52), (20, 30, 74), (250, 206, 36), (18, 140, 140)
NAVY_SET = {  # Central Navy Singlet, Royal Blue Belt, Central Navy Sleeves, Ice Wraps
    "WornSinglet": {"Black": NAVY, "Red": YELLOW, "Trim": YELLOW, "Patch": YELLOW, "Shorts": NAVY, "ShortsRed": YELLOW},
    "WornLeverBelt": {"Outer": (28, 74, 196), "Lining": BLACK, "Stitch": WHITE, "Lever": STEEL, "Text": WHITE},
    "WornKneeSleeve": {"Body": NAVY, "Stripes": YELLOW, "Patch": YELLOW},
    "WornWristWrap": {"Body": WHITE, "Stripes": (70, 146, 255), "Text": (20, 60, 140)},
}
GOLD_SET = {  # Black & Gold Singlet, Gold Standard Belt, Flamingo Sleeves, Blaze Wraps
    "WornSinglet": {"Black": BLACK, "Red": GOLD, "Trim": GOLD, "Patch": GOLD, "Shorts": BLACK, "ShortsRed": GOLD},
    "WornLeverBelt": {"Outer": GOLD, "Lining": BLACK, "Stitch": BLACK, "Lever": (60, 60, 64), "Text": BLACK},
    "WornKneeSleeve": {"Body": (236, 96, 150), "Stripes": WHITE, "Patch": WHITE},
    "WornWristWrap": {"Body": (240, 120, 24), "Stripes": BLACK, "Text": BLACK},
}
TEAL_SET = {  # Lagoon Singlet, Forest Green Belt, Teal Sleeves, Lime Wraps
    "WornSinglet": {"Black": TEAL, "Red": WHITE, "Trim": WHITE, "Patch": WHITE, "Shorts": TEAL, "ShortsRed": WHITE},
    "WornLeverBelt": {"Outer": (28, 104, 58), "Lining": (232, 224, 200), "Stitch": (232, 224, 200), "Lever": STEEL,
                      "Text": (232, 224, 200)},
    "WornKneeSleeve": {"Body": TEAL, "Stripes": WHITE, "Patch": BLACK},
    "WornWristWrap": {"Body": (150, 210, 40), "Stripes": (30, 60, 30), "Text": (30, 60, 30)},
}

figure("Classic", (0, 0, 0), {}, with_worn=True)
figure("Navy", (-4.5, 0, 0), NAVY_SET)
figure("Gold", (-9.0, 0, 0), GOLD_SET)
figure("Squat", (-14.0, 0, 0), TEAL_SET, {"lean": 30, "thigh": -70, "knee": 95, "ankle": -25, "shoulder": -30})

# Every material is drawn from one side, as Roblox does.
for mat in bpy.data.materials:
    mat.use_backface_culling = True

bpy.context.view_layer.update()
print("built", len(WORN), "worn pieces")
for ob in WORN:
    part = PART_OF[ob.name]
    size, centre = BODY[part]
    offset = to_roblox(ob.location) - Vector(centre)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    print(f"  {ob.name:30s} {part:11s} offset ({offset.x:+.3f}, {offset.y:+.3f}, {offset.z:+.3f})  {tris} tris")
