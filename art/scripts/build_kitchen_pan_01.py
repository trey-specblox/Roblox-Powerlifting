# The Kitchen's giant pan zone (GAME_DESIGN §40.7, user 2026-11-19): every player in the server gets one pan zone in
# the Kitchen. The chef throws your steak mountain onto your pan; a giant kitchen timer above it shows when it's done.
#
# Three items, each ONE shared mesh set reused by all 40 zones (Roblox draws repeated meshes together):
#   GiantPan_*    a huge cast-iron pan with a CENTRAL grip, sitting on a navy burner stand with a glowing ring
#   PanClock_*    a giant round kitchen timer on a steel post behind the pan; Clock_Face is a flat white disc that
#                 carries the live countdown (a SurfaceGui in Roblox)
#   BigSteak_*    ONE big cartoon T-bone steak (user: not a pile); Roblox scales it to the size of each cook
#
# Units: 1 Blender unit = 1 stud; z up; fronts toward -Y (the walkway). Build with prop_helpers.Builder (it stops on
# any inside-out piece), then run check_models.py before export.
#
#   blender -b art/blender/KitchenPan_01.blend --python art/scripts/build_kitchen_pan_01.py   (or exec in Blender)

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(bpy.data.filepath or ""), "..", "scripts"))
sys.path.insert(0, r"D:\Powerlifting Roblox\art\scripts")
import importlib  # noqa: E402

import prop_helpers as H  # noqa: E402

importlib.reload(H)

B = H.Builder("KitchenPan")

IRON = H.material("Kitchen_PanIron", (0.05, 0.05, 0.06), metallic=0.6, roughness=0.45)
GRIP = H.material("Kitchen_PanGrip", (0.86, 0.13, 0.13), roughness=0.5)
LABEL = H.material("Kitchen_Label", (0.97, 0.97, 0.95), roughness=0.5)
STAND = H.material("Kitchen_StandNavy", (0.05, 0.08, 0.21), metallic=0.3, roughness=0.5)
STEEL = H.material("Kitchen_Steel", (0.62, 0.64, 0.68), metallic=0.85, roughness=0.3)
FLAME = H.material("Kitchen_BurnerGlow", (1.0, 0.45, 0.08), roughness=0.4, emission=(1.0, 0.42, 0.05))
CLOCK = H.material("Kitchen_ClockYellow", (0.98, 0.79, 0.12), roughness=0.45)
FACE = H.material("Kitchen_ClockFace", (0.97, 0.97, 0.95), roughness=0.6)
INK = H.material("Kitchen_Ink", (0.04, 0.04, 0.05), roughness=0.6)
MEAT = H.material("Kitchen_SteakMeat", (0.3, 0.09, 0.045), roughness=0.75)
BONE = H.material("Kitchen_SteakBone", (0.95, 0.9, 0.78), roughness=0.7)

PAN_R = 6.2  # the pan's outer radius at the rim
STAND_R = 5.0
STAND_H = 2.6
PAN_Z = STAND_H + 0.3  # the pan's underside

# ---------------------------------------------------------------- GiantPan


def pan_body(bm):
    # The pan: a lathe of its wall section (outside up, over the rolled rim, inside down, across the floor).
    H.lathe_z(bm, [
        (0.0, PAN_Z),
        (5.5, PAN_Z),
        (5.95, PAN_Z + 0.35),
        (PAN_R, PAN_Z + 1.5),
        (PAN_R + 0.15, PAN_Z + 1.75),
        (PAN_R - 0.25, PAN_Z + 1.8),
        (5.6, PAN_Z + 0.45),
        (5.2, PAN_Z + 0.3),
        (0.0, PAN_Z + 0.3),
    ], segments=40)
    # The handle's iron stem, out to the side (+X), angled up a little.
    stem = Matrix.Rotation(math.radians(-8), 4, "Y")
    H.rounded_box(bm, Vector((PAN_R + 1.6, 0, PAN_Z + 1.55)), (3.6, 1.0, 0.55), 0.18, rotation=stem)


def pan_grip(bm):
    turn = Matrix.Rotation(math.radians(-8), 4, "Y")
    H.rounded_box(bm, Vector((PAN_R + 5.6, 0, PAN_Z + 2.1)), (5.0, 1.3, 0.95), 0.35, rotation=turn)


def pan_label(bm):
    # CENTRAL on the grip's top (gear-brand rule).
    angle = math.radians(8)

    def place(x, up, depth):
        local = Vector((x, up, 0.0))
        p = Matrix.Rotation(-angle, 3, "Y") @ Vector((local.x, local.y, depth))
        return Vector((PAN_R + 5.6, 0, PAN_Z + 2.1 + 0.48)) + p

    B.add_text(bm, "CENTRAL", 0.62, 0.04, place)


def stand(bm):
    # A navy burner stand: a stepped round base, a waist, and a top plate.
    H.lathe_z(bm, [(0.0, 0.0), (STAND_R + 0.4, 0.0), (STAND_R + 0.4, 0.45), (STAND_R - 0.2, 0.7),
                   (STAND_R - 0.6, STAND_H - 0.5), (STAND_R, STAND_H - 0.2), (STAND_R, STAND_H), (0.0, STAND_H)],
              segments=32)


def stand_label(bm):
    H_text_r = STAND_R - 0.32
    B.add_text(bm, "CENTRAL", 0.75, 0.04, H.on_cylinder((0, 0, 0), H_text_r + 0.06, STAND_H * 0.5))


def grate(bm):
    # Steel grate bars the pan rests on.
    for k in range(4):
        a = math.pi * k / 4
        rot = Matrix.Rotation(a, 4, "Z")
        H.box(bm, Vector((0, 0, STAND_H + 0.15)), (2 * STAND_R - 0.6, 0.35, 0.3), rotation=rot)


def burner_ring(bm):
    H.torus(bm, (0, 0, STAND_H + 0.05), STAND_R - 1.6, 0.22, segments=32, sides=8)


B.piece("GiantPan_Body", IRON, pan_body)
B.piece("GiantPan_Grip", GRIP, pan_grip)
B.piece("GiantPan_Label", LABEL, pan_label, smooth=False)
B.piece("GiantPan_Stand", STAND, stand)
B.piece("GiantPan_StandLabel", LABEL, stand_label, smooth=False)
B.piece("GiantPan_Grate", STEEL, grate, smooth=False)
B.piece("GiantPan_Burner", FLAME, burner_ring)

# ---------------------------------------------------------------- PanClock (behind the pan, facing the walkway)

POST_Y = PAN_R + 1.8
CLOCK_Z = 17.0
CLOCK_R = 3.4
CLOCK_D = 1.6


def clock_post(bm):
    H.cylinder(bm, Vector((0, POST_Y, 0.15)), 1.2, 0.3, segments=20)
    H.cylinder(bm, Vector((0, POST_Y, (CLOCK_Z - CLOCK_R) / 2 + 0.2)), 0.35, CLOCK_Z - CLOCK_R + 0.1, segments=12)


def clock_body(bm):
    # A fat round kitchen timer: the drum, a rim round the face, a winding knob on top and two feet.
    H.cylinder(bm, Vector((0, POST_Y, CLOCK_Z)), CLOCK_R, CLOCK_D, axis="Y", segments=36)
    H.torus(bm, (0, POST_Y - CLOCK_D / 2, CLOCK_Z), CLOCK_R - 0.15, 0.22, plane="XZ", segments=36, sides=8)
    H.cylinder(bm, Vector((0, POST_Y, CLOCK_Z + CLOCK_R + 0.35)), 0.55, 0.7, segments=16)


def clock_bell(bm):
    # Two bells on top, like a wind-up timer, and the knob's cap.
    for side in (-1, 1):
        H.sphere(bm, Vector((side * 1.9, POST_Y, CLOCK_Z + CLOCK_R - 0.1)), 1.0, scale=(1, 1, 0.75), segments=16, rings=8)
    H.sphere(bm, Vector((0, POST_Y, CLOCK_Z + CLOCK_R + 0.8)), 0.55, scale=(1, 1, 0.6), segments=12, rings=6)


def clock_face(bm):
    # A flat white disc just in front of the drum: Roblox puts the countdown on it.
    H.cylinder(bm, Vector((0, POST_Y - CLOCK_D / 2 - 0.06, CLOCK_Z)), CLOCK_R - 0.45, 0.12, axis="Y", segments=36)


def clock_ticks(bm):
    # Twelve hour marks round the face's edge.
    r = CLOCK_R - 0.75
    y = POST_Y - CLOCK_D / 2 - 0.15
    for k in range(12):
        a = 2 * math.pi * k / 12
        size = (0.18, 0.08, 0.5 if k % 3 == 0 else 0.3)
        rot = Matrix.Rotation(-a, 4, "Y")
        H.box(bm, Vector((r * math.sin(a), y, CLOCK_Z + r * math.cos(a))), size, rotation=rot)


B.piece("PanClock_Post", STEEL, clock_post)
B.piece("PanClock_Body", CLOCK, clock_body)
B.piece("PanClock_Bells", STAND, clock_bell)
B.piece("PanClock_Face", FACE, clock_face, smooth=False)
B.piece("PanClock_Ticks", INK, clock_ticks, smooth=False)

# ---------------------------------------------------------------- BigSteak (one steak; code scales it to the cook)
# User 2026-11-19: not a pile ("too much single things", bad for performance with 40 players). However many steaks go
# in, the pan holds ONE big steak whose size scales with that number. At scale 1 it fills the pan.

SEAR = H.material("Kitchen_SteakSear", (0.18, 0.06, 0.03), roughness=0.8)
FAT = H.material("Kitchen_SteakFat", (0.98, 0.9, 0.78), roughness=0.7)

STEAK_SCALE = 3.4  # the outline below is about 2.9 x 2.1; this makes the steak about 9.6 x 7 studs
STEAK_Z = PAN_Z + 0.3  # sits on the pan's floor
RIM = 24  # points round the outline


def steak_point(t, grow=0.0):
    """A cartoon steak seen from above: a fat kidney shape, wider at the bone end (+X), with a dent in one side."""
    x = 1.35 * math.cos(t) - 0.12 * math.cos(2 * t)
    y = (0.95 + 0.12 * math.cos(t)) * math.sin(t)
    if math.sin(t) > 0.6:
        y -= 0.18 * (math.sin(t) - 0.6) / 0.4
    d = math.hypot(x, y)
    return (STEAK_SCALE * x * (1 + grow / d), STEAK_SCALE * y * (1 + grow / d))


def loft(bm, rings):
    """A closed solid through horizontal rings of (x, y) points, bottom ring first, each ring anticlockwise from above
    and the same length. Caps the bottom and the top; faces point outward."""
    layers = [[bm.verts.new(Vector((x, y, z))) for x, y in ring] for ring, z in rings]
    bm.faces.new(list(reversed(layers[0])))
    bm.faces.new(layers[-1])
    n = len(layers[0])
    for low, high in zip(layers, layers[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((low[i], low[j], high[j], high[i]))


def outline(grow, ts):
    return [steak_point(t, grow) for t in ts]


ROUND = [2 * math.pi * k / RIM for k in range(RIM)]
THICK = 1.1  # the steak's thickness at scale 1


def big_steak_meat(bm):
    # Rounded edges: narrower at the very bottom and top than at the middle, so it reads as a juicy slab, not a board.
    z0 = STEAK_Z
    loft(bm, [
        (outline(-0.12, ROUND), z0),
        (outline(0.0, ROUND), z0 + 0.25),
        (outline(0.0, ROUND), z0 + THICK - 0.3),
        (outline(-0.1, ROUND), z0 + THICK),
    ])


def big_steak_fat(bm):
    # The fat strip along the long curved back edge (-Y side) only: a band just outside the meat, tucked inside it.
    arc = [math.pi + 0.3 + (math.pi - 0.6) * k / 13 for k in range(14)]
    band_outer = outline(0.08, arc)
    band_inner = outline(-0.06, list(reversed(arc)))
    ring = band_outer + band_inner
    z0 = STEAK_Z
    loft(bm, [(ring, z0 + 0.12), (ring, z0 + THICK - 0.12)])


def big_steak_sear(bm):
    # Four dark grill marks across the top, at an angle.
    top = STEAK_Z + THICK
    m = Matrix.Rotation(math.radians(35), 4, "Z")
    for off in (-1.8, -0.6, 0.6, 1.8):
        length = 4.2 - abs(off) * 0.9
        bmesh.ops.create_cube(bm, size=1.0, matrix=m @ Matrix.Translation((off, 0, top + 0.02))
                              @ Matrix.Diagonal((0.42, length, 0.08, 1)))


def big_steak_bone(bm):
    # The T-bone: a strip across the steak near the wide end and a knob reaching to the edge.
    top = STEAK_Z + THICK
    for centre, size in (((1.9, 0.2, top + 0.06), (0.7, 3.4, 0.2)), ((2.85, 0.2, top + 0.06), (1.6, 0.75, 0.2))):
        H.rounded_box(bm, Vector(centre), size, 0.08, segments=2)


B.piece("BigSteak_Meat", MEAT, big_steak_meat)
B.piece("BigSteak_Fat", FAT, big_steak_fat)
B.piece("BigSteak_Sear", SEAR, big_steak_sear, smooth=False)
B.piece("BigSteak_Bone", BONE, big_steak_bone)

print("KITCHEN PAN BUILT:", [o.name for o in B.coll.objects])
