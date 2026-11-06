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
# collision, no shadows (step 5b). A suit in place of the singlet adds about 5 more; a bench shirt about 12; knee wraps
# take the sleeves' place, 12 for 8.
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
import worn_rough  # noqa: E402

importlib.reload(H)
importlib.reload(worn_rough)
from worn_rough import grain, relief, ridge, rope, stitches, strap  # noqa: E402

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


def piece(name, part, mat, build, smooth=True):
    obj = B.piece(name, mat, build, smooth)
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

# =================================================================== The rare suits (GAME_DESIGN 35.10, 35.12)
# The supportive gear of equipped powerlifting, the rarest things in the game, from the user's photos (2026-11-06):
#   WornSquatSuit    "just way tighter singlets": skin-tight, with wide straps and very short legs. Replaces the singlet.
#   WornDeadliftSuit the same cut, its legs a little shorter. Replaces the singlet.
#   WornBenchShirt   a stiff shirt worn UNDER the singlet: a coloured front, black sides and back with a strap, a thick rolled
#                    collar, pleats across the chest, thick short sleeves with a patch. Its own slot.
# They are rough, stiff canvas (user: "way more texturized ... rough and 3d modeled ... cannot just be a flat plane"). So nothing
# here is a plain shell: every surface has creases and lumps (worn_rough.relief), every seam is raised piping with thread
# stitched down it, every edge is a rolled hem, and the lettering is on patches sewn on top. The canvas's weave is a
# MaterialVariant in the game (Suit_RoughCanvas, make_suit_canvas.py), not in these meshes.
SUIT_ITEMS = ("WornSquatSuit", "WornBenchShirt", "WornDeadliftSuit")
SUIT_OFF = 0.028


def on_back(y_back, z_mid):
    """place() for text on the flat back, looking toward +Y: a half turn of the front's, so it reads and stays one-sided."""
    def place(x, up, depth):
        return Vector((-x, y_back + depth, z_mid + up))
    return place


def column_at(cols, lx, front):
    """The column nearest this sideways position, on the front or the back."""
    return min((c for c in cols if (c["lz"] < 0) == front), key=lambda c: abs(c["lx"] - lx))


def out_from(c, y, amount):
    return P(c["x"] + c["nx"] * amount, y, c["z"] + c["nz"] * amount)


def label_plate(bm, y_front, z_mid, width, height):
    # A patch sewn on: a thick plate with soft edges, on the front.
    H.rounded_box(bm, Vector((0, y_front - 0.02, z_mid)), (width, 0.04, height), 0.018, 1)


def back_plate(bm, y_back, z_mid, width, height):
    H.rounded_box(bm, Vector((0, y_back + 0.02, z_mid)), (width, 0.04, height), 0.018, 1)


def word_width(word, size):
    return len(word) * size * 0.72 + 0.14


def suit_labels(worn, y_front, y_back, word, size, chest_z, word_z, back_z):
    """A small patch sewn on the chest with CENTRAL on it, and the lift's name in raised lettering, front and back."""
    def plates(bm):
        label_plate(bm, y_front, chest_z, 0.98, 0.26)

    def letters(bm):
        front = y_front - 0.04
        B.add_text(bm, BRAND, 0.15, 0.006, H.on_front(Vector((0, 0, 0)), front, chest_z))
        # The letters stand up off the cloth, thick enough to catch the light.
        B.add_text(bm, word, size, 0.016, H.on_front(Vector((0, 0, 0)), y_front + 0.004, word_z))
        B.add_text(bm, word, size, 0.016, on_back(y_back - 0.004, back_z))

    piece(worn + "_Label_Upper", "UpperTorso", MAT["Black"], plates, smooth=False)
    piece(worn + "_Patch_Upper", "UpperTorso", MAT["White"], letters, smooth=False)


def tight_suit(worn, word, word_size, leg_low, seed):
    """A skin-tight one-piece of stiff canvas: wide doubled straps, a deep neck, very short legs."""
    off = SUIT_OFF
    shell = ring(thx + off, thz + off, R_TORSO, step=0.075, corner=5)
    top = tcy + thy + off
    strap_in, strap_out = 0.34, 0.74
    tops = singlet_tops_for(shell, thx + off, thz + off, R_TORSO, top, strap_in, strap_out, 0.3, 0.46, 0.16)
    side = [is_side(shell, i) for i in range(len(shell))]
    # How far each column is round from a seam between the coloured body and the side panel, for the groove along it.
    to_seam = []
    for i, c in enumerate(shell):
        best = 9.0
        for j in range(len(shell)):
            if side[j] != side[(j + 1) % len(shell)]:
                best = min(best, abs(shell[j]["s"] - c["s"]))
        to_seam.append(best)
    ROWS = 22
    bottom = tcy - thy - 0.02
    rows_cache = {}

    def rows_of(i):
        if i not in rows_cache:
            rows_cache[i] = [bottom + (tops[i] - bottom) * k / ROWS for k in range(ROWS + 1)]
        return rows_cache[i]

    index_of = {id(c): i for i, c in enumerate(shell)}

    def shell_disp(c, y):
        x = c["lx"]
        d = 0.012 + 0.009 * grain(c["s"], y, seed)
        if c["lz"] < 0:
            # Pulled tight from the straps to the armpits, and bunched into rolls above the belt.
            for sx in (-1, 1):
                d += 0.06 * ridge(x, y, sx * 0.56, 1.0, sx * 0.94, 0.2, 0.12)
                d += 0.05 * ridge(x, y, sx * 0.3, 0.8, sx * 0.9, -0.12, 0.1)
                d += 0.04 * ridge(x, y, sx * 0.1, 0.28, sx * 0.9, -0.3, 0.09)
            d += 0.06 * ridge(x, y, -0.9, -0.42, 0.9, -0.36, 0.07)
            d += 0.05 * ridge(x, y, -0.86, -0.2, 0.8, -0.27, 0.06)
            # Calmer under the patch and the lettering.
            if abs(x) < 0.7 and -0.22 < y < 0.56:
                d *= 0.45
        else:
            for sx in (-1, 1):
                d += 0.055 * ridge(x, y, sx * 0.4, 0.98, sx * 0.9, 0.02, 0.12)
            d += 0.05 * ridge(x, y, -0.9, -0.36, 0.9, -0.42, 0.07)
            d += 0.04 * ridge(x, y, -0.9, -0.14, 0.9, -0.2, 0.06)
            if abs(x) < 0.66 and 0.06 < y < 0.5:
                d *= 0.45
        # A groove along each panel seam, with the piping in it.
        d -= 0.018 * max(0.0, 1 - to_seam[index_of[id(c)]] / 0.06)
        return max(d, 0.0)

    def strap_path(sx):
        # Roblox x, y, z down the chest, over the shoulder, down the back, standing on the cloth.
        x = sx * (strap_in + strap_out) / 2
        front, back = -(thz + off) - 0.036, thz + off + 0.036
        line = [(x, 0.4, front), (x, 0.7, front), (x, 0.95, front - 0.004), (x, top + 0.0, front + 0.02), (x, top + 0.028, front + 0.1),
                (x, top + 0.028, back - 0.1), (x, top + 0.0, back - 0.02), (x, 0.95, back + 0.004), (x, 0.7, back), (x, 0.4, back)]
        return [P(*q) for q in line]

    def body_piece(bm):
        relief(bm, P, shell, rows_of, shell_disp, lambda i, k: not side[i])
        # The doubled straps: solid bands sewn on top, from the chest over the shoulder and down the back.
        for sx in (-1, 1):
            strap(bm, strap_path(sx), strap_out - strap_in + 0.04, 0.05)

    piece(worn + "_Body_Upper", "UpperTorso", MAT["Red"], body_piece)
    piece(worn + "_Panel_Upper", "UpperTorso", MAT["Black"],
          lambda bm: relief(bm, P, shell, rows_of, shell_disp, lambda i, k: side[i]))

    def trim_piece(bm):
        # Rolled edges round the neck and armholes, tight against the cloth, all the way between the straps.
        run = []
        for i in list(range(len(shell))) + [0]:
            c = shell[i]
            if tops[i] < top - 0.012:
                run.append(out_from(c, tops[i], shell_disp(c, tops[i]) + 0.004))
            else:
                if len(run) > 2:
                    rope(bm, run[::2] + [run[-1]], 0.026, 5)
                run = []
        if len(run) > 2:
            rope(bm, run[::2] + [run[-1]], 0.026, 5)
        # Raised piping sitting in the groove down each side seam.
        for j in range(len(shell)):
            if side[j] != side[(j + 1) % len(shell)] and tops[j] > bottom + 0.2:
                c = shell[j]
                ys = [bottom + (tops[j] - 0.03 - bottom) * k / 6 for k in range(7)]
                rope(bm, [out_from(c, y, shell_disp(c, y) + 0.006) for y in ys], 0.02, 5)

    piece(worn + "_Trim_Upper", "UpperTorso", MAT["Grey"], trim_piece)

    def thread_piece(bm):
        # Two rows of thread down each strap, front and back.
        for sx in (-1, 1):
            middle = (strap_in + strap_out) / 2
            for offset in (-0.13, 0.13):
                x = sx * (middle + offset)
                stitches(bm, [Vector((-x, -(thz + off) - 0.062, z)) for z in (0.44, top)])
                stitches(bm, [Vector((-x, thz + off + 0.062, z)) for z in (0.44, top)])

    piece(worn + "_Stitch_Upper", "UpperTorso", MAT["White"], thread_piece, smooth=False)
    suit_labels(worn, -(thz + off + 0.022), thz + off + 0.022, word, word_size, 0.42, 0.03, 0.26)

    hip = ring(lthx + off + 0.006, lthz + off + 0.006, 0.13, step=0.12, corner=4)
    hip_rows = [ltcy - lthy - 0.03 + (2 * lthy + 0.08) * k / 7 for k in range(8)]

    def hip_disp(c, y):
        d = 0.01 + 0.008 * grain(c["s"], y, seed + 3)
        if c["lz"] < 0:
            # The creases where the hip folds into the leg, from the user's photo.
            for sx in (-1, 1):
                d += 0.04 * ridge(c["lx"], y, sx * 0.1, -1.04, sx * 0.86, -0.74, 0.1)
        return d

    piece(worn + "_Body_Lower", "LowerTorso", MAT["Red"],
          lambda bm: relief(bm, P, hip, lambda i: hip_rows, hip_disp, lambda i, k: not is_side(hip, i)))
    piece(worn + "_Panel_Lower", "LowerTorso", MAT["Black"],
          lambda bm: relief(bm, P, hip, lambda i: hip_rows, hip_disp, lambda i, k: is_side(hip, i)))

    leg_off = off + 0.008
    legs = ring(lhx + leg_off, lhz + leg_off, 0.12, lcx, lcz, step=0.11, corner=4)
    top_y = HIP_Y + 0.05
    leg_rows = [leg_low + (top_y - leg_low) * k / 5 for k in range(6)]

    def leg_disp(c, y):
        d = 0.008 + 0.009 * grain(c["s"], y, seed + 5)
        d += 0.022 * max(0.0, 1 - (y - leg_low) / 0.09)  # bunched at the hem
        return d

    piece(worn + "_Body_Leg", "UpperLeg", MAT["Red"],
          lambda bm: relief(bm, P, legs, lambda i: leg_rows, leg_disp, lambda i, k: not is_side(legs, i)))
    piece(worn + "_Panel_Leg", "UpperLeg", MAT["Black"],
          lambda bm: relief(bm, P, legs, lambda i: leg_rows, leg_disp, lambda i, k: is_side(legs, i)))
    # A thick rolled hem, with a band of thread above it.
    hem_points = [out_from(c, leg_low, 0.03) for c in legs[::2]]
    piece(worn + "_Trim_Leg", "UpperLeg", MAT["Grey"], lambda bm: rope(bm, hem_points, 0.034, 5, closed=True))


def singlet_tops_for(cols, hx, hz, r, top, strap_in, strap_out, armhole, neck_front, neck_back):
    """Each column's top: the neckline, the strap or the armhole (as singlet_tops, with this suit's own sizes)."""
    ix, iz = hx - r, hz - r
    lf, lc, ls = 2 * ix, math.pi * r / 2, 2 * iz
    perimeter = 2 * lf + 2 * ls + 4 * lc
    s_right = lf + lc + ls / 2
    s_left = s_right + perimeter / 2
    reach = ls / 2 + lc + (ix - strap_out)

    def round_trip(v):
        v %= perimeter
        return min(v, perimeter - v)

    result = []
    for c in cols:
        d = min(round_trip(c["s"] - s_right), round_trip(c["s"] - s_left))
        if d < reach:
            result.append(top - (top - armhole) * math.sqrt(1 - (d / reach) ** 2))
        elif abs(c["lx"]) < strap_in:
            result.append(top - (neck_front if c["lz"] < 0 else neck_back) * (1 - (c["lx"] / strap_in) ** 2))
        else:
            result.append(top)
    return result


tight_suit("WornSquatSuit", "SQUAT", 0.34, -1.34, 1.0)
tight_suit("WornDeadliftSuit", "DEADLIFT", 0.24, -1.26, 4.0)

# ------------------------------------------------------------------- the bench shirt, under the singlet
# The stiffest thing in the game. When a singlet goes over it, the game fits the singlet wider (WornGearFit), so this
# can stand well off the body.
SHIRT_OFF = 0.02
shirt = ring(thx + SHIRT_OFF, thz + SHIRT_OFF, R_TORSO, step=0.075, corner=5)
SHIRT_TOP = tcy + thy + SHIRT_OFF
SHIRT_FRONT, SHIRT_BACK = -(thz + SHIRT_OFF), thz + SHIRT_OFF
NECK_WIDE = 0.6


def shirt_top_at(c):
    u = min(1.0, abs(c["lx"]) / NECK_WIDE)
    return SHIRT_TOP - (0.2 if c["lz"] < 0 else 0.12) * (1 - u * u)


def is_side_at(cols, c):
    return is_side(cols, cols.index(c))


shirt_tops = [shirt_top_at(c) for c in shirt]
shirt_front_cells = [c["lz"] < 0 and not is_side(shirt, i) for i, c in enumerate(shirt)]
SHIRT_ROWS = 24
shirt_bottom = tcy - thy - 0.02
shirt_rows_cache = {}


def shirt_rows(i):
    if i not in shirt_rows_cache:
        shirt_rows_cache[i] = [shirt_bottom + (shirt_tops[i] - shirt_bottom) * k / SHIRT_ROWS for k in range(SHIRT_ROWS + 1)]
    return shirt_rows_cache[i]


def shirt_disp(c, y):
    x = c["lx"]
    d = 0.012 + 0.009 * grain(c["s"], y, 7.0)
    if c["lz"] < 0:
        # Heavy stitched pleats across the chest, like the user's photo, and stiff folds below them.
        for level, amount in ((0.84, 0.06), (0.66, 0.075), (0.48, 0.075)):
            d += amount * ridge(x, y, -1.05, level, 1.05, level - 0.02, 0.085)
        for sx in (-1, 1):
            d += 0.05 * ridge(x, y, sx * 0.2, 0.34, sx * 0.94, -0.34, 0.11)
            d += 0.04 * ridge(x, y, sx * 0.1, -0.1, sx * 0.9, -0.5, 0.09)
        if abs(x) < 0.66 and -0.2 < y < 0.3:
            d *= 0.45
    else:
        for level in (0.72, 0.26, -0.26):
            d += 0.03 * ridge(x, y, -1.05, level, 1.05, level + 0.03, 0.08)
    return d


def shirt_body(bm):
    relief(bm, P, shirt, shirt_rows, shirt_disp, lambda i, k: shirt_front_cells[i])


piece("WornBenchShirt_Body_Upper", "UpperTorso", MAT["Red"], shirt_body)


def shirt_panel(bm):
    relief(bm, P, shirt, shirt_rows, shirt_disp, lambda i, k: not shirt_front_cells[i])


piece("WornBenchShirt_Panel_Upper", "UpperTorso", MAT["Black"], shirt_panel)


def shirt_shoulders(bm):
    # Thick padded shoulders, closing the top over the arm.
    width = thx + SHIRT_OFF - NECK_WIDE + 0.04
    for side_x in (-1, 1):
        H.rounded_box(bm, P(side_x * (NECK_WIDE + width / 2 - 0.02), SHIRT_TOP + 0.015, 0), (width, 2 * (thz + SHIRT_OFF) + 0.06, 0.07), 0.03, 2)


piece("WornBenchShirt_Shoulder_Upper", "UpperTorso", MAT["Red"], shirt_shoulders)


shirt_hips = ring(lthx + 0.026, lthz + 0.026, 0.13, step=0.12, corner=4)


def shirt_trim(bm):
    # The thick rolled collar, the seams between front and back, the seam over each shoulder, the strap across the back.
    collar = []
    for i, c in enumerate(shirt):
        if abs(c["lx"]) <= NECK_WIDE:
            collar.append((c["lz"] < 0, c["lx"], out_from(c, shirt_tops[i], 0.012)))
    front = [p for is_front, _, p in sorted((e for e in collar if e[0]), key=lambda e: e[1])]
    back = [p for is_front, _, p in sorted((e for e in collar if not e[0]), key=lambda e: -e[1])]
    rope(bm, (front + back)[::2], 0.058, 6, closed=True)
    for j in range(len(shirt)):
        if shirt_front_cells[j] != shirt_front_cells[(j + 1) % len(shirt)]:
            c = shirt[j]
            rope(bm, [out_from(c, y, 0.03) for y in (shirt_bottom, -0.2, 0.2, 0.6, shirt_tops[j])], 0.026, 5)
    # A thick rolled hem along the bottom of the front.
    hem = [out_from(c, ltcy - lthy, 0.04) for c in shirt_hips if c["lz"] < 0 and not is_side_at(shirt_hips, c)]
    if len(hem) > 1:
        rope(bm, sorted(hem, key=lambda v: v.x), 0.03, 5)
    # The wide strap across the back, thick, with its flap standing out at one side.
    H.rounded_box(bm, Vector((0, SHIRT_BACK + 0.05, -0.2)), (1.7, 0.07, 0.36), 0.03, 2)
    H.rounded_box(bm, P(thx + SHIRT_OFF + 0.06, -0.2, 0.36), (0.14, 0.42, 0.36), 0.03, 2)


piece("WornBenchShirt_Trim_Upper", "UpperTorso", MAT["Grey"], shirt_trim)


def shirt_thread(bm):
    # Thread along each chest pleat, and round the strap.
    for level in (0.77, 0.59):
        columns = [column_at(shirt, x, True) for x in (-0.84, -0.42, 0.0, 0.42, 0.84)]
        stitches(bm, [out_from(c, level, shirt_disp(c, level) + 0.006) for c in columns])
    stitches(bm, [Vector((x, SHIRT_BACK + 0.09, -0.08)) for x in (-0.8, 0.8)])
    stitches(bm, [Vector((x, SHIRT_BACK + 0.09, -0.32)) for x in (-0.8, 0.8)])


piece("WornBenchShirt_Stitch_Upper", "UpperTorso", MAT["White"], shirt_thread, smooth=False)
suit_labels("WornBenchShirt", SHIRT_FRONT - 0.022, SHIRT_BACK + 0.022, "BENCH", 0.3, 0.2, -0.08, 0.34)

shirt_hip_rows = [ltcy - lthy + (2 * lthy + 0.05) * k / 6 for k in range(7)]


def shirt_hip_disp(c, y):
    return 0.008 + 0.008 * grain(c["s"], y, 9.0)


piece("WornBenchShirt_Body_Lower", "LowerTorso", MAT["Red"],
      lambda bm: relief(bm, P, shirt_hips, lambda i: shirt_hip_rows, shirt_hip_disp, lambda i, k: shirt_hips[i]["lz"] < 0 and not is_side(shirt_hips, i)))
piece("WornBenchShirt_Panel_Lower", "LowerTorso", MAT["Black"],
      lambda bm: relief(bm, P, shirt_hips, lambda i: shirt_hip_rows, shirt_hip_disp, lambda i, k: not (shirt_hips[i]["lz"] < 0 and not is_side(shirt_hips, i))))

# The sleeves are the thickest part: stiff, short, standing well off the arm, with rolls where they fold.
uahx, _, uahz, uacx, uacy, uacz = part_box("UpperArm")
SHIRT_SLEEVE_LOW, SHIRT_SLEEVE_HIGH = 0.36, 1.1
arm = ring(uahx + 0.075, uahz + 0.075, 0.17, uacx, uacz, step=0.13, corner=4)
arm_rows = [SHIRT_SLEEVE_LOW + (SHIRT_SLEEVE_HIGH - SHIRT_SLEEVE_LOW) * k / 10 for k in range(11)]
ARM_FRONT = -(uahz + 0.075)


def arm_disp(c, y):
    d = 0.012 + 0.01 * grain(c["s"], y, 11.0)
    # Two thick rolls round the sleeve, and a bunch at the hem.
    for level in (0.96, 0.58):
        d += 0.06 * max(0.0, 1 - abs(y - level) / 0.075)
    d += 0.04 * max(0.0, 1 - (y - SHIRT_SLEEVE_LOW) / 0.1)
    return d


def shirt_sleeve(bm):
    relief(bm, P, arm, lambda i: arm_rows, arm_disp)
    H.rounded_box(bm, P(uacx, SHIRT_SLEEVE_HIGH + 0.01, uacz), (2 * (uahx + 0.075), 2 * (uahz + 0.075), 0.05), 0.04, 2)


piece("WornBenchShirt_Body_Sleeve", "UpperArm", MAT["Red"], shirt_sleeve)
piece("WornBenchShirt_Trim_Sleeve", "UpperArm", MAT["Grey"],
      lambda bm: rope(bm, [out_from(c, SHIRT_SLEEVE_LOW, 0.05) for c in arm[::2]], 0.04, 5, closed=True))


def sleeve_label(bm):
    H.rounded_box(bm, P(uacx, 0.79, ARM_FRONT - 0.03), (0.86, 0.04, 0.3), 0.018, 1)


piece("WornBenchShirt_Label_Sleeve", "UpperArm", MAT["Black"], sleeve_label, smooth=False)


def sleeve_letters(bm):
    # On the sleeve's front, so it reads the right way round on both arms (one mesh for both).
    face = ARM_FRONT - 0.05
    badge(bm, -uacx, face, 0.79, 0.78, 0.24, 0.024, depth=0.012)
    B.add_text(bm, BRAND, 0.13, 0.005, H.on_front(P(uacx, 0, 0), face, 0.79))


piece("WornBenchShirt_Patch_Sleeve", "UpperArm", MAT["White"], sleeve_letters, smooth=False)

# =================================================================== WornKneeWrap (UpperLeg + LowerLeg)
# Knee wraps, a separate item from the sleeves (user's photo, 2026-11-06): one long striped strap wound tight round the knee,
# each turn lapping the last, crossing over itself at the knee, its end tucked in. A real spiral, not a tube. Two pieces so
# it bends with the knee, like the sleeves. Replaces the sleeves while worn.
WRAP_TURNS = 6
WRAP_TOP = KNEE_Y + 0.5
WRAP_PITCH = (WRAP_TOP - (KNEE_Y - 0.5)) / WRAP_TURNS
WRAP_WIDE = WRAP_PITCH * 1.7
# PERFORMANCE: common crate gear, so far fewer points than a suit: about 3,600 triangles a pair.
wrap_ring = ring(lhx + 0.05, lhz + 0.05, 0.17, lcx, lcz, step=0.36, corner=2)
WRAP_ROUND = wrap_ring[-1]["s"] + (Vector((wrap_ring[0]["x"], wrap_ring[0]["z"])) - Vector((wrap_ring[-1]["x"], wrap_ring[-1]["z"]))).length
# The ring once round with its start repeated at the end, so each turn runs on unbroken into the next.
wrap_cols = wrap_ring + [dict(wrap_ring[0], s=WRAP_ROUND)]


def wrap_centre(turn, c):
    # Down the leg as it goes round, and tilted the other way over the knee, so the turns cross there as in the photo.
    y = WRAP_TOP - WRAP_PITCH * (turn + c["s"] / WRAP_ROUND)
    near_knee = max(0.0, 1 - abs(y - KNEE_Y) / 0.26)
    return y + 0.05 * near_knee * math.sin(2 * math.pi * c["s"] / WRAP_ROUND + turn)


def wrap_strip(bm, upper):
    n = len(wrap_ring)
    for turn in range(WRAP_TURNS):
        layer = 0.02 + 0.006 * turn + (0.03 if abs(WRAP_TOP - WRAP_PITCH * (turn + 0.5) - KNEE_Y) < 0.24 else 0.0)
        centres = [wrap_centre(turn, c) for c in wrap_cols]

        def rows(i, centres=centres):
            return [centres[i] + WRAP_WIDE * (k / 2 - 0.5) for k in range(3)]

        def disp(c, y, centres=centres, layer=layer):
            across = abs(y - wrap_centre(turn, c)) / (WRAP_WIDE / 2)
            return layer + 0.024 * max(0.0, 1 - across * across) + 0.004 * grain(c["s"], y, turn)

        def keep(i, k, centres=centres):
            return i < n and (centres[i] >= KNEE_Y) == upper

        relief(bm, P, wrap_cols, rows, disp, keep)


def wrap_lines(bm, upper, sideways, every):
    for turn in range(0, WRAP_TURNS, every):
        layer = 0.05 + 0.006 * turn + (0.03 if abs(WRAP_TOP - WRAP_PITCH * (turn + 0.5) - KNEE_Y) < 0.24 else 0.0)
        line, runs = [], []
        for c in wrap_cols:
            y = wrap_centre(turn, c) + sideways
            if (y >= KNEE_Y) == upper:
                line.append(out_from(c, y, layer))
            elif len(line) > 1:
                runs.append(line)
                line = []
            else:
                line = []
        if len(line) > 1:
            runs.append(line)
        for run in runs:
            rope(bm, run, 0.013, 3)


def wrap_under(bm, upper):
    # Hidden under the turns, and fills the knee when it bends.
    low, high = (KNEE_Y - 0.2, WRAP_TOP - 0.02) if upper else (KNEE_Y - 0.48, KNEE_Y + 0.2)
    band(bm, ring(lhx + 0.03, lhz + 0.03, 0.15, lcx, lcz), low, high, 0.02)


def wrap_tail(bm):
    # The strap's end, tucked over the last turn with its hook.
    front = -(lhz + 0.14)
    H.rounded_box(bm, P(lcx + 0.05, KNEE_Y - 0.36, front), (0.5, 0.05, 0.24), 0.02, 1)


piece("WornKneeWrap_Body_Upper", "UpperLeg", MAT["Black"], lambda bm: (wrap_under(bm, True), wrap_strip(bm, True)))
piece("WornKneeWrap_Body_Lower", "LowerLeg", MAT["Black"], lambda bm: (wrap_under(bm, False), wrap_strip(bm, False), wrap_tail(bm)))
piece("WornKneeWrap_Stripes_Upper", "UpperLeg", MAT["Red"], lambda bm: wrap_lines(bm, True, 0.022, 1), smooth=False)
piece("WornKneeWrap_Stripes_Lower", "LowerLeg", MAT["Red"], lambda bm: wrap_lines(bm, False, 0.022, 1), smooth=False)
piece("WornKneeWrap_Accent_Upper", "UpperLeg", MAT["White"], lambda bm: wrap_lines(bm, True, -0.022, 3), smooth=False)
piece("WornKneeWrap_Accent_Lower", "LowerLeg", MAT["White"], lambda bm: wrap_lines(bm, False, -0.022, 3), smooth=False)

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


def figure(label, offset, colours, pose=None, with_worn=False, only=None):
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
        # `only` dresses a figure in just those items; the others wear the normal gear, never a suit or knee wraps.
        item_name = src.name.split("_")[0]
        if item_name not in only if only else item_name in SUIT_ITEMS + ("WornKneeWrap",):
            continue
        for side in (("Right", "Left") if part in LIMBS else ("",)):
            if with_worn and side != "Left":
                continue
            loc = src.location.copy()
            if side == "Left":
                loc.x = -loc.x
            ob = bpy.data.objects.new(f"Preview_{label}_{side}_{src.name}", src.data)
            preview.objects.link(ob)
            # A singlet over a bench shirt is fitted wider, as the game does (WornGearFit).
            over = Matrix.Identity(4)
            if only and "WornBenchShirt" in only and item_name == "WornSinglet" and part in ("UpperTorso", "LowerTorso"):
                body = P(*BODY[part][1])
                over = Matrix.Translation(body) @ Matrix.Diagonal((1.06, 1.14, 1.0, 1)) @ Matrix.Translation(-body)
            ob.matrix_world = shift @ pose_matrix(part, side or "Right", pose) @ over @ Matrix.Translation(loc)
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

# The rare suits and knee wraps, standing and in their lifts. Their colours go in ShopConfig too. No colour is near black:
# dark colours hide the canvas's weave in the game.
DARK = (46, 46, 52)
THREAD = (226, 196, 110)
SQUAT_COLOURS = {"Body": (176, 30, 38), "Panel": DARK, "Trim": DARK, "Stitch": THREAD, "Label": DARK, "Patch": THREAD}
DEADLIFT_COLOURS = {"Body": (104, 52, 170), "Panel": DARK, "Trim": DARK, "Stitch": THREAD, "Label": DARK, "Patch": THREAD}
SHIRT_COLOURS = {"Body": (240, 120, 24), "Shoulder": (240, 120, 24), "Panel": DARK, "Trim": DARK, "Stitch": (40, 30, 20),
                 "Label": DARK, "Patch": WHITE}
WRAP_COLOURS = {"Body": (28, 34, 60), "Stripes": (60, 130, 240), "Accent": (220, 50, 50)}
figure("SuitSquat", (-22.0, 0, 0), {"WornSquatSuit": SQUAT_COLOURS}, only=("WornSquatSuit",))
figure("SuitShirt", (-26.0, 0, 0), {"WornBenchShirt": SHIRT_COLOURS}, only=("WornBenchShirt",))
figure("SuitBoth", (-30.0, 0, 0), {"WornBenchShirt": SHIRT_COLOURS}, only=("WornBenchShirt", "WornSinglet"))
figure("SuitDeadlift", (-34.0, 0, 0), {"WornDeadliftSuit": DEADLIFT_COLOURS}, only=("WornDeadliftSuit",))
figure("SuitWraps", (-38.0, 0, 0), {"WornKneeWrap": WRAP_COLOURS}, only=("WornKneeWrap", "WornSinglet"))
figure("PoseSquat", (-23.0, 8, 0), {"WornSquatSuit": SQUAT_COLOURS, "WornKneeWrap": WRAP_COLOURS},
       {"lean": 30, "thigh": -70, "knee": 95, "ankle": -25, "shoulder": -30}, only=("WornSquatSuit", "WornKneeWrap"))
figure("PoseBench", (-28.0, 8, 0), {"WornBenchShirt": SHIRT_COLOURS}, {"shoulder": -80}, only=("WornBenchShirt", "WornSinglet"))
figure("PoseDeadlift", (-33.0, 8, 0), {"WornDeadliftSuit": DEADLIFT_COLOURS},
       {"lean": 50, "thigh": -40, "knee": 40, "ankle": -10}, only=("WornDeadliftSuit",))

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
