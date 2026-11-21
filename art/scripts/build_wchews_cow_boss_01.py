# The mafia boss cow (GAME_DESIGN §40.7, user 2026-11-21: the boss of W Chews' back room, "a cow on 2 legs" seen
# slipping through the EMPLOYEES ONLY door during the chef scene; his wheel gives the luck multiplier and his games
# earn spins). A big cartoon cow standing upright in a pinstripe suit and a fedora: white hide with black patches, a
# pink snout, cream horns up through the hat's brim, a red tie and pocket square, white spats over black shoes, hooves
# for hands, a yellow ear tag. No cigar, no weapon, no real brand.
#
# One item, "CowBoss": about 4.5 wide, 7.9 tall, standing on z = 0, facing -Y. His RIGHT side is -X.
# Pieces "CowBoss_<Piece>", one colour each. Two groups can be moved by code round a joint (rigid pieces, no skeleton):
#     Head*   round the NECK  (0, 0, 5.1):       HeadHide, HeadSpots, HeadSnout, HeadEyes, HeadWhites, HeadHorns, HeadHat,
#                                                HeadBand, HeadTag
#     ArmR*   round the SHOULDER (-1.75, 0, 4.75): ArmRSuit, ArmRHoof, ArmRCuff
# Everything else is his body.
#
#   blender -b --factory-startup --python art/scripts/build_wchews_cow_boss_01.py -- <out.blend> [<out.glb>]

import json
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, r"D:\Powerlifting Roblox\art\scripts")
import importlib  # noqa: E402

import prop_helpers as H  # noqa: E402

importlib.reload(H)

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

B = H.Builder("WChewsCowBoss")
V = Vector
S = H.span

SUIT = H.material("Cow_Suit", (0.09, 0.10, 0.16), roughness=0.8)
LAPEL = H.material("Cow_Lapel", (0.03, 0.03, 0.05), roughness=0.6)
STRIPE = H.material("Cow_Stripe", (0.70, 0.72, 0.78), roughness=0.8)
WHITE = H.material("Cow_White", (0.96, 0.96, 0.94), roughness=0.7)
HIDE = H.material("Cow_Hide", (0.95, 0.94, 0.90), roughness=0.75)
BLACK = H.material("Cow_Black", (0.05, 0.05, 0.06), roughness=0.6)
PINK = H.material("Cow_Snout", (0.96, 0.62, 0.66), roughness=0.6)
CREAM = H.material("Cow_Horn", (0.95, 0.90, 0.76), roughness=0.6)
RED = H.material("Cow_Red", (0.78, 0.10, 0.10), roughness=0.6)
BRASS = H.material("Cow_Brass", (0.86, 0.64, 0.22), metallic=0.9, roughness=0.3)
HAT = H.material("Cow_Hat", (0.10, 0.10, 0.12), roughness=0.85)
BAND = H.material("Cow_HatBand", (0.42, 0.07, 0.12), roughness=0.7)
TAG = H.material("Cow_Tag", (0.98, 0.80, 0.12), roughness=0.5)

NECK = (0.0, 0.0, 5.1)
SHOULDER = (-1.75, 0.0, 4.75)
FRONT = -1.1  # the jacket's front face (y)
BACK = 1.1


def tube(bm, a, b, radius, segments=8, radius2=None):
    a, b = V(a), V(b)
    d = b - a
    rot = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius,
                          radius2=radius if radius2 is None else radius2, depth=d.length,
                          matrix=Matrix.Translation((a + b) / 2) @ rot)


def prism(bm, points, y0, y1):
    """A convex polygon in the XZ plane (points: (x, z), in order round it) pushed from y0 to y1."""
    tmp = bmesh.new()
    front = [tmp.verts.new((x, y0, z)) for x, z in points]
    back = [tmp.verts.new((x, y1, z)) for x, z in points]
    n = len(points)
    tmp.faces.new(front)
    tmp.faces.new(list(reversed(back)))
    for i in range(n):
        j = (i + 1) % n
        tmp.faces.new((front[j], front[i], back[i], back[j]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    H._merge(bm, tmp)


def lean(degrees):
    return Matrix.Rotation(math.radians(degrees), 4, "Y")


# ----------------------------------------------------------------------- the body


def suit(bm):
    # Trouser legs, the jacket with its skirt, and his left sleeve (hanging, a little out from the body).
    for s in (-1, 1):
        H.rounded_box(bm, V((s * 0.78, 0.05, 1.55)), (1.05, 1.15, 1.7), 0.25, segments=2)
    H.rounded_box(bm, V((0, 0, 3.6)), (3.3, 2.2, 3.0), 0.5, segments=3)
    H.rounded_box(bm, V((0, 0, 2.4)), (3.4, 2.3, 0.75), 0.2, segments=2)
    H.rounded_box(bm, V((2.05, 0, 3.75)), (0.95, 1.0, 2.5), 0.3, segments=2, rotation=lean(-6))


def lapels(bm):
    # Dark lapels down to the button, and the jacket's collar round the neck. Deep, so nothing floats off the chest.
    for s in (-1, 1):
        prism(bm, [(s * 0.2, 3.5), (s * 0.75, 4.9), (s * 1.05, 4.95), (s * 0.95, 4.2)], FRONT - 0.06, -0.5)
    H.rounded_box(bm, V((0, 0.35, 5.08)), (2.0, 1.5, 0.22), 0.08, segments=1)


def stripes(bm):
    # Pinstripes: down the jacket's front beside the lapels, across its back, and down each trouser leg.
    for x in (-1.15, 1.15):
        S(bm, (x - 0.03, FRONT - 0.09, 2.15), (x + 0.03, FRONT + 0.1, 4.55))
    for x in (-0.78, 0.78):
        S(bm, (x - 0.03, FRONT - 0.09, 2.15), (x + 0.03, FRONT + 0.1, 3.45))
        S(bm, (x - 0.03, -0.56, 0.95), (x + 0.03, -0.45, 2.05))
    for x in (-1.1, -0.55, 0.0, 0.55, 1.1):
        S(bm, (x - 0.03, BACK - 0.1, 2.15), (x + 0.03, BACK + 0.09, 4.55))


def white(bm):
    # The shirt front, his left cuff, and the spats over his shoes.
    prism(bm, [(-0.55, 4.98), (0.55, 4.98), (0.0, 3.6)], FRONT - 0.03, -0.5)
    H.box(bm, V((2.16, 0, 2.6)), (1.02, 1.06, 0.16), rotation=lean(-6))
    for s in (-1, 1):
        H.rounded_box(bm, V((s * 0.78, 0.02, 0.78)), (1.1, 1.2, 0.5), 0.12, segments=1)


def tie(bm):
    # A red tie and a red pocket square on his left chest.
    H.rounded_box(bm, V((0, FRONT - 0.1, 4.72)), (0.36, 0.22, 0.3), 0.06, segments=1)
    prism(bm, [(-0.18, 4.6), (0.18, 4.6), (0.28, 3.45), (0.0, 3.15), (-0.28, 3.45)], FRONT - 0.12, FRONT - 0.02)
    prism(bm, [(0.75, 4.2), (1.2, 4.2), (1.25, 4.42), (0.98, 4.36), (0.72, 4.45)], FRONT - 0.06, FRONT + 0.05)


def brass(bm):
    # Two jacket buttons and a tie pin.
    for z in (2.55, 2.95):
        H.sphere(bm, V((0, FRONT - 0.03, z)), 0.11, scale=(1, 0.6, 1), segments=8, rings=4)
    S(bm, (-0.2, FRONT - 0.15, 4.0), (0.2, FRONT - 0.11, 4.06))


def hooves(bm):
    # His shoes, his left hoof (a hand), and the tuft of his tail.
    for s in (-1, 1):
        H.rounded_box(bm, V((s * 0.78, -0.3, 0.32)), (1.0, 1.75, 0.64), 0.2, segments=2)
    H.rounded_box(bm, V((2.2, 0, 2.2)), (0.9, 0.95, 0.7), 0.22, segments=2, rotation=lean(-6))
    H.sphere(bm, V((0.42, 2.05, 1.9)), 0.22, scale=(1, 1, 1.5), segments=8, rings=4)


def hide(bm):
    # His neck, and his tail out of the jacket's back.
    H.cylinder(bm, V((0, 0, 5.15)), 0.72, 0.5, segments=12)
    tube(bm, (0, 1.0, 2.6), (0.4, 2.0, 2.0), 0.07, segments=6)


B.piece("CowBoss_Suit", SUIT, suit)
B.piece("CowBoss_Lapels", LAPEL, lapels, smooth=False)
B.piece("CowBoss_Stripes", STRIPE, stripes, smooth=False)
B.piece("CowBoss_White", WHITE, white, smooth=False)
B.piece("CowBoss_Tie", RED, tie, smooth=False)
B.piece("CowBoss_Brass", BRASS, brass)
B.piece("CowBoss_Hooves", BLACK, hooves)
B.piece("CowBoss_Hide", HIDE, hide)

# ----------------------------------------------------------------------- his right arm (round SHOULDER)


def arm_suit(bm):
    H.rounded_box(bm, V((-2.05, 0, 3.75)), (0.95, 1.0, 2.5), 0.3, segments=2, rotation=lean(6))


def arm_hoof(bm):
    H.rounded_box(bm, V((-2.2, 0, 2.2)), (0.9, 0.95, 0.7), 0.22, segments=2, rotation=lean(6))


def arm_cuff(bm):
    H.box(bm, V((-2.16, 0, 2.6)), (1.02, 1.06, 0.16), rotation=lean(6))


B.piece("CowBoss_ArmRSuit", SUIT, arm_suit)
B.piece("CowBoss_ArmRHoof", BLACK, arm_hoof)
B.piece("CowBoss_ArmRCuff", WHITE, arm_cuff, smooth=False)

# ----------------------------------------------------------------------- his head (round NECK)
FACE = -1.1  # the head's front face (y)


def head_hide(bm):
    H.rounded_box(bm, V((0, -0.1, 6.0)), (2.3, 2.0, 1.8), 0.55, segments=3)
    for s in (-1, 1):
        H.sphere(bm, V((s * 1.42, 0.0, 6.15)), 0.4, scale=(1.3, 0.45, 0.75), segments=10, rings=5)


def head_spots(bm):
    # A black patch round his left eye and one on his right cheek.
    H.rounded_box(bm, V((0.55, FACE + 0.02, 6.28)), (0.8, 0.16, 0.75), 0.06, segments=1)
    H.rounded_box(bm, V((-1.13, 0.15, 5.8)), (0.12, 0.8, 0.6), 0.05, segments=1)


def head_snout(bm):
    H.rounded_box(bm, V((0, FACE - 0.12, 5.6)), (1.7, 0.8, 0.95), 0.3, segments=2)


def head_eyes(bm):
    # Small dark eyes under heavy brows that slope down to the middle (a stern boss), nostrils and a flat mouth.
    for s in (-1, 1):
        H.sphere(bm, V((s * 0.5, FACE - 0.13, 6.28)), 0.12, scale=(1, 0.6, 1.25), segments=8, rings=4)
        H.box(bm, V((s * 0.5, FACE - 0.1, 6.64)), (0.62, 0.12, 0.14), rotation=lean(-s * 14))
        H.sphere(bm, V((s * 0.36, FACE - 0.5, 5.68)), 0.1, scale=(1, 0.6, 1.3), segments=6, rings=3)
    S(bm, (-0.38, FACE - 0.54, 5.3), (0.38, FACE - 0.48, 5.36))


def head_whites(bm):
    # The whites of his eyes (so the eye still reads inside the black patch).
    for s in (-1, 1):
        H.sphere(bm, V((s * 0.5, FACE - 0.03, 6.3)), 0.24, scale=(1, 0.5, 1.2), segments=10, rings=5)


def head_horns(bm):
    # Up and out through the hat's brim.
    for s in (-1, 1):
        tube(bm, (s * 0.95, 0.0, 6.55), (s * 1.8, 0.0, 7.3), 0.22, segments=8, radius2=0.05)


def head_hat(bm):
    # A fedora: a wide brim and a tall crown.
    H.lathe_z(bm, [(0.0, 6.84), (1.9, 6.82), (1.96, 6.9), (1.28, 7.0), (1.22, 7.72), (1.02, 7.9), (0.0, 7.84)], 20,
              centre=V((0, -0.05, 0)))


def head_band(bm):
    H.lathe_z(bm, [(1.24, 7.0), (1.31, 7.0), (1.29, 7.3), (1.22, 7.3)], 20, centre=V((0, -0.05, 0)))


def head_tag(bm):
    # A yellow ear tag hanging from his left ear.
    S(bm, (1.62, -0.06, 5.72), (1.92, 0.0, 6.08))


B.piece("CowBoss_HeadHide", HIDE, head_hide)
B.piece("CowBoss_HeadSpots", BLACK, head_spots)
B.piece("CowBoss_HeadSnout", PINK, head_snout)
B.piece("CowBoss_HeadEyes", BLACK, head_eyes)
B.piece("CowBoss_HeadWhites", WHITE, head_whites)
B.piece("CowBoss_HeadHorns", CREAM, head_horns)
B.piece("CowBoss_HeadHat", HAT, head_hat)
B.piece("CowBoss_HeadBand", BAND, head_band)
B.piece("CowBoss_HeadTag", TAG, head_tag, smooth=False)

bpy.context.view_layer.update()
lo = Vector((1e9, 1e9, 1e9))
hi = -lo
for ob in B.coll.objects:
    for corner in ob.bound_box:
        w = ob.matrix_world @ Vector(corner)
        lo = Vector(map(min, lo, w))
        hi = Vector(map(max, hi, w))
facts = {"low": [round(v, 4) for v in lo], "high": [round(v, 4) for v in hi], "neck": list(NECK),
         "shoulder": list(SHOULDER)}

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if argv:
    bpy.ops.wm.save_as_mainfile(filepath=argv[0])
    with open(argv[0].replace(".blend", "_bounds.json"), "w", encoding="utf-8") as handle:
        json.dump(facts, handle, indent=1)
if len(argv) >= 2:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in B.coll.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=argv[1], export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
tris = sum(len(p.vertices) - 2 for o in B.coll.objects for p in o.data.polygons)
print("COW BOSS BUILT:", len(B.coll.objects), "objects,", tris, "triangles; bounds", facts["low"], facts["high"])
