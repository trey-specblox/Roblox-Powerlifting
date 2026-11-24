# The meet meal's chef scene props (GAME_DESIGN §40.7, user 2026-11-23: "have it where the chef walks up, drops a
# chicken inside the meat bay, and pours in a bag of broccoli and a bag of rice then the thing sucks it up, and drops it
# on the pan. Maby you can add a little staircase, to the bay so the chef can dump the things with his hands", with
# photos of a frozen broccoli florets bag and a long grain rice bag). The bags say CENTRAL (memory: no real brands).
#
# Five items, each round its own origin, standing on z = 0, the front toward -Y:
#   WcBayStairs   a steel stair up to a little platform in front of the meat bay's glass (placed in the hall; the chef
#                 climbs it to tip things over the glass). 4 wide; the platform's top 4.2 up, its front at y = 0
#   RawChicken    a whole raw, plucked cartoon chicken: a plump pink body, two drumsticks with bone knobs, little wings
#   BroccoliBag   a frozen broccoli florets bag: a green-tinted pillow bag with florets printed on it, a white oval
#                 CENTRAL label and BROCCOLI FLORETS
#   RiceBag       a long grain rice bag: a pale woven pillow bag, a navy band, a white oval CENTRAL label, LONG GRAIN RICE
#   BroccoliBit   one loose floret (the pour drops a handful)
#
# Every layer stands at least 0.05 proud of what it lies on, or cuts into it (memory "No flicker, no overlap").
#
#   blender -b --factory-startup --python art/scripts/build_wchews_meal_props_01.py -- <out.blend> [<out.glb>]

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

B = H.Builder("WChewsMealProps")
V = Vector

STEEL = H.material("Wc_Steel", (0.80, 0.82, 0.85), metallic=0.9, roughness=0.28)
STEEL_DARK = H.material("Wc_SteelDark", (0.42, 0.44, 0.48), metallic=0.85, roughness=0.35)
SAFETY = H.material("Wc_SafetyYellow", (0.98, 0.78, 0.08), roughness=0.5)
SKIN = H.material("Meal_RawChicken", (0.98, 0.78, 0.70), roughness=0.55)
BONE = H.material("Meal_Bone", (0.97, 0.94, 0.86), roughness=0.6)
BAG_GREEN = H.material("Meal_BagGreen", (0.62, 0.82, 0.62), roughness=0.3)
FLORET = H.material("Meal_Broccoli", (0.1, 0.42, 0.12), roughness=0.7)
STEM = H.material("Meal_Stem", (0.55, 0.75, 0.3), roughness=0.65)
LABEL_WHITE = H.material("Meal_LabelWhite", (0.97, 0.97, 0.96), roughness=0.5)
NAVY = H.material("Meal_Navy", (0.05, 0.14, 0.42), roughness=0.45)
BLUE = H.material("Meal_Blue", (0.1, 0.45, 0.85), roughness=0.45)
RICE_BAG = H.material("Meal_RiceBag", (0.86, 0.82, 0.70), roughness=0.85)
INK = H.material("Meal_Ink", (0.04, 0.12, 0.38), roughness=0.5)
GREEN_INK = H.material("Meal_GreenInk", (0.08, 0.36, 0.12), roughness=0.5)

ITEMS = {}  # item -> its offset in the file (each item is built round its own origin, then spread out for the pictures)


def at(item, x):
    ITEMS[item] = x
    return V((x, 0, 0))


def text_flat(bm, text, size, origin, depth_y):
    """Text on a flat face looking toward -Y, its back 0.02 inside the face at y = depth_y, its face 0.06 proud."""
    B.add_text(bm, text, size, 0.04, H.on_front(origin, depth_y + 0.02, 0.0))


# ================================================================ WcBayStairs (at x 0)
S0 = at("WcBayStairs", 0.0)
W = 4.0  # the stair's width
TOP = 4.2  # the platform's top
DECK = 3.0  # the platform's depth (its front edge at y = 0, it runs back to -DECK... see below)
STEPS = 6
RUN = 1.1  # each step's tread depth
RISE = TOP / STEPS
# The platform: y from -DECK to 0 (its front, toward the bay's glass, at y = 0: the stair comes down toward -Y).
# The steps: below the platform's back edge, going down toward -Y.


def stair_steel(bm):
    o = S0
    # The platform's deck and its four legs.
    H.span(bm, o + V((-W / 2, -DECK, TOP - 0.25)), o + V((W / 2, 0, TOP)))
    for sx in (-1, 1):
        for y in (-DECK + 0.15, -0.15):
            H.span(bm, o + V((sx * (W / 2 - 0.15) - 0.12, y - 0.12, 0)), o + V((sx * (W / 2 - 0.15) + 0.12, y + 0.12, TOP - 0.25)))
    # The treads (each a slab), from the deck down toward -Y.
    for k in range(STEPS - 1):
        z = TOP - RISE * (k + 1)
        y1 = -DECK - RUN * k
        H.span(bm, o + V((-W / 2 + 0.25, y1 - RUN, z - 0.18)), o + V((W / 2 - 0.25, y1, z)))
    # The two stringers: slanted planks under the treads' ends, from the floor (their foot flat on it) up to under the
    # deck's back edge, 0.5 deep measured straight up.
    y_bot, y_top = -DECK - RUN * (STEPS - 1) - 0.3, -DECK
    for sx in (-1, 1):
        x0, x1 = sx * (W / 2) - 0.0, sx * (W / 2 - 0.24)
        x0, x1 = min(x0, x1), max(x0, x1)
        plank = bmesh.new()
        corners = [(y_bot, 0.0), (y_bot + 0.6, 0.0), (y_top, TOP - 0.75), (y_top, TOP - 0.25), (y_bot, 0.5)]
        low = [plank.verts.new(o + V((x0, y, z))) for y, z in corners]
        high = [plank.verts.new(o + V((x1, y, z))) for y, z in corners]
        plank.faces.new(low)
        plank.faces.new(list(reversed(high)))
        n = len(corners)
        for i in range(n):
            j = (i + 1) % n
            plank.faces.new((low[i], low[j], high[j], high[i]))
        bmesh.ops.recalc_face_normals(plank, faces=plank.faces[:])
        H._merge(bm, plank)


def stair_rails_solid(bm):
    # Hand rails up both sides of the stair and along the platform's sides (not its front: he leans over the glass).
    o = S0
    run = RUN * (STEPS - 1)
    angle = math.atan2(TOP, run)
    length = math.hypot(run, TOP)
    for sx in (-1, 1):
        x = sx * (W / 2 - 0.12)
        mid = o + V((x, -DECK - run / 2, TOP / 2 + 3.0))
        H.box(bm, mid, (0.16, length + 0.2, 0.16), rotation=Matrix.Rotation(angle, 4, "X"))
        # posts: at the bottom, at the deck's back corner, at the deck's front corner
        for y, z0 in ((-DECK - run, RISE), (-DECK, TOP), (-0.2, TOP)):
            H.span(bm, o + V((x - 0.08, y - 0.08, z0 - 0.05)), o + V((x + 0.08, y + 0.08, z0 + 3.0)))
        # the deck's side rail (level), front corner to back corner
        H.span(bm, o + V((x - 0.08, -DECK, TOP + 2.92)), o + V((x + 0.08, -0.2, TOP + 3.08)))
        # a knee rail halfway up the deck's side
        H.span(bm, o + V((x - 0.06, -DECK, TOP + 1.45)), o + V((x + 0.06, -0.2, TOP + 1.57)))


def stair_nosing(bm):
    o = S0
    # A yellow safety strip on each tread's front edge and on the deck's back edge, 0.05 proud of the tread.
    for k in range(STEPS - 1):
        z = TOP - RISE * (k + 1)
        y0 = -DECK - RUN * k - RUN
        H.span(bm, o + V((-W / 2 + 0.3, y0 - 0.02, z - 0.05)), o + V((W / 2 - 0.3, y0 + 0.25, z + 0.05)))
    H.span(bm, o + V((-W / 2 + 0.05, -DECK - 0.02, TOP - 0.05)), o + V((W / 2 - 0.05, -DECK + 0.25, TOP + 0.05)))


B.piece("WcBayStairs_Steel", STEEL_DARK, stair_steel, smooth=False)
B.piece("WcBayStairs_Rails", STEEL, stair_rails_solid, smooth=False)
B.piece("WcBayStairs_Nosing", SAFETY, stair_nosing, smooth=False)

# ================================================================ RawChicken (at x 12)
C0 = at("RawChicken", 12.0)


# The classic cartoon raw chicken, breast up: a round body with a deep breast ridge, two fat drumsticks rising up and
# back from the hips with white bone ends (the shape everybody reads as "a chicken"), and the wings folded at the sides.
LEG_DIR = [V((sx * 0.45, 0.75, 0.5)).normalized() for sx in (-1, 1)]


def chicken_body(bm):
    o = C0
    # the body: a fat egg, and the two breast halves bulging on top either side of the breastbone
    H.sphere(bm, o + V((0, 0, 0.66)), 0.9, scale=(0.95, 1.15, 0.7), segments=16, rings=10)
    for sx in (-1, 1):
        H.sphere(bm, o + V((sx * 0.3, -0.15, 0.98)), 0.52, scale=(0.9, 1.3, 0.62), segments=12, rings=7)
    # the wings, folded flat against the sides near the front: a fat upper part and a pointed tip
    for sx in (-1, 1):
        H.sphere(bm, o + V((sx * 0.86, -0.25, 0.7)), 0.3, scale=(0.55, 1.2, 0.8), segments=8, rings=5)
        H.sphere(bm, o + V((sx * 0.84, -0.72, 0.6)), 0.18, scale=(0.55, 1.2, 0.7), segments=8, rings=5)
    # the drumsticks: a fat thigh ball at each hip, then a meaty cone up and back toward the bone
    for leg, sx in zip(LEG_DIR, (-1, 1)):
        hip = o + V((sx * 0.48, 0.65, 0.62))
        H.sphere(bm, hip, 0.44, scale=(1, 1, 0.95), segments=10, rings=6)
        mid = hip + leg * 0.55
        turn = leg.to_track_quat("Z", "Y").to_matrix().to_4x4()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=10, radius1=0.33, radius2=0.15, depth=0.85,
                              matrix=Matrix.Translation(mid) @ turn)


def chicken_bones(bm):
    o = C0
    # the white bone ends at the drumsticks' tips: a short stub and the two round knuckles
    for leg, sx in zip(LEG_DIR, (-1, 1)):
        hip = o + V((sx * 0.48, 0.65, 0.62))
        tip = hip + leg * 0.92
        turn = leg.to_track_quat("Z", "Y").to_matrix().to_4x4()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=8, radius1=0.09, radius2=0.09, depth=0.36,
                              matrix=Matrix.Translation(tip + leg * 0.12) @ turn)
        side = leg.cross(V((0, 0, 1))).normalized()
        for k in (-1, 1):
            H.sphere(bm, tip + leg * 0.32 + side * (k * 0.08), 0.12, segments=8, rings=5)


B.piece("RawChicken_Body", SKIN, chicken_body)
B.piece("RawChicken_Bones", BONE, chicken_bones)

# ================================================================ BroccoliBag (at x 18)
G0 = at("BroccoliBag", 18.0)
BAG = (2.4, 0.8, 3.2)  # width, depth, height


def broccoli_bag(bm):
    # A pillow bag: a rounded block, crimped flat strips at the top and bottom.
    o = G0
    H.rounded_box(bm, o + V((0, 0, BAG[2] / 2)), BAG, 0.36, segments=3)
    for z in (0.08, BAG[2] - 0.08):
        H.span(bm, o + V((-BAG[0] / 2 + 0.05, -0.08, z - 0.08)), o + V((BAG[0] / 2 - 0.05, 0.08, z + 0.08)))


# The frozen florets seen through the clear bag (the photo: the bag is packed full of them): floret heads, each a
# clump of bumps, packed over the front and back faces, half sunk into the bag. Places on a grid with a little jitter.
FLORET_SPOTS = []
for row in range(5):
    for col in range(4):
        x = -0.84 + col * 0.56 + (0.14 if row % 2 else 0) + 0.05 * math.sin(row * 3 + col)
        z = 0.42 + row * 0.6 + 0.05 * math.cos(row + col * 2)
        if abs(x) < 0.98 and not (abs(x) < 0.82 and 1.3 < z < 2.45):  # (keep the label clear)
            FLORET_SPOTS.append((x, z))


def broccoli_bag_print(bm):
    # (front only: the back faces the chef's chest in the scene; low-poly bumps: 5,000 triangles each object at most)
    o = G0
    y = -BAG[1] / 2 + 0.06
    for x, z in FLORET_SPOTS:
        centre = o + V((x, y, z))
        H.sphere(bm, centre, 0.17, scale=(1, 0.6, 1), segments=6, rings=3)
        for k in range(4):
            a = 2 * math.pi * k / 4 + x * 3
            H.sphere(bm, centre + V((0.15 * math.cos(a), -0.02, 0.15 * math.sin(a))), 0.12, scale=(1, 0.6, 1),
                     segments=5, rings=3)


def broccoli_bag_stems(bm):
    # each floret's little pale stalk, pointing down out of its head
    o = G0
    y = -BAG[1] / 2 + 0.03
    for x, z in FLORET_SPOTS:
        H.span(bm, o + V((x - 0.05, y - 0.05, z - 0.3)), o + V((x + 0.05, y + 0.05, z - 0.08)))


def broccoli_bag_label(bm):
    # A white oval label in the middle of the front, standing 0.08 proud.
    o = G0
    face = -BAG[1] / 2
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=28, radius1=1.0, radius2=1.0, depth=0.12,
                          matrix=Matrix.Translation(o + V((0, face - 0.02, 1.85))) @ Matrix.Rotation(math.pi / 2, 4, "X")
                          @ Matrix.Diagonal((1.05, 0.62, 1, 1)))


def broccoli_bag_blue(bm):
    # A blue strip across the label's top (the "CENTRAL" banner).
    o = G0
    face = -BAG[1] / 2
    H.rounded_box(bm, o + V((0, face - 0.1, 2.25)), (1.3, 0.1, 0.36), 0.08, segments=2)


def broccoli_bag_words(bm):
    o = G0
    face = -BAG[1] / 2
    # (the font's curves at a low resolution: words this size read the same with fewer triangles)
    B.add_text(bm, "BROCCOLI", 0.3, 0.03, H.on_front(o + V((0, 0, 0)), face - 0.12, 1.86))
    B.add_text(bm, "FLORETS", 0.3, 0.03, H.on_front(o + V((0, 0, 0)), face - 0.12, 1.5))


def broccoli_bag_brand(bm):
    o = G0
    face = -BAG[1] / 2
    B.add_text(bm, "CENTRAL", 0.24, 0.03, H.on_front(o + V((0, 0, 0)), face - 0.2, 2.25))


B.piece("BroccoliBag_Bag", BAG_GREEN, broccoli_bag)
B.piece("BroccoliBag_Print", FLORET, broccoli_bag_print)
B.piece("BroccoliBag_Stems", STEM, broccoli_bag_stems, smooth=False)
B.piece("BroccoliBag_Label", LABEL_WHITE, broccoli_bag_label)
B.piece("BroccoliBag_Banner", BLUE, broccoli_bag_blue)
B.piece("BroccoliBag_Words", GREEN_INK, broccoli_bag_words, smooth=False)
B.piece("BroccoliBag_Brand", LABEL_WHITE, broccoli_bag_brand, smooth=False)

# ================================================================ RiceBag (at x 23)
R0 = at("RiceBag", 23.0)
RBAG = (2.2, 1.0, 3.4)


def rice_bag(bm):
    o = R0
    H.rounded_box(bm, o + V((0, 0, RBAG[2] / 2)), RBAG, 0.42, segments=3)
    for z in (0.08, RBAG[2] - 0.08):
        H.span(bm, o + V((-RBAG[0] / 2 + 0.05, -0.1, z - 0.08)), o + V((RBAG[0] / 2 - 0.05, 0.1, z + 0.08)))


def rice_bag_band(bm):
    # A navy band round the bag's middle, cutting into it (it wraps the pillow's rounded sides).
    o = R0
    H.rounded_box(bm, o + V((0, 0, 1.75)), (RBAG[0] + 0.06, RBAG[1] + 0.06, 1.25), 0.42, segments=3)


def rice_bag_grains(bm):
    # Rice grains seen through the bag (the photo's bag shows the rice inside): little long grains over the front and
    # back above and below the band, each a flattened stretched ball half sunk into the bag's face.
    # Only on the face's flat middle (the rounded edges curve away: a grain there would float).
    o = R0
    golden = math.pi * (3 - math.sqrt(5))
    y = -RBAG[1] / 2 + 0.03
    k = 0
    for z0, z1 in ((0.5, 1.02), (2.5, 2.95)):
        rows = 3
        for row in range(rows):
            for col in range(6):
                k += 1
                x = -0.6 + col * 0.24 + (0.12 if row % 2 else 0) + 0.04 * math.sin(k * 2.7)
                z = z0 + (z1 - z0) * (row + 0.5) / rows + 0.04 * math.cos(k * 1.9)
                if abs(x) > 0.64:
                    continue
                turn = Matrix.Rotation(k * golden, 4, "Y")
                bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=3, radius=1.0,
                                          matrix=Matrix.Translation(o + V((x, y, z))) @ turn
                                          @ Matrix.Diagonal((0.11, 0.05, 0.04, 1)))


def rice_bag_label(bm):
    o = R0
    face = -RBAG[1] / 2 - 0.03
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=28, radius1=1.0, radius2=1.0, depth=0.12,
                          matrix=Matrix.Translation(o + V((0, face - 0.03, 1.78))) @ Matrix.Rotation(math.pi / 2, 4, "X")
                          @ Matrix.Diagonal((0.95, 0.5, 1, 1)))


def rice_bag_words(bm):
    o = R0
    face = -RBAG[1] / 2 - 0.03
    B.add_text(bm, "LONG GRAIN", 0.24, 0.03, H.on_front(o, face - 0.13, 1.72))
    B.add_text(bm, "RICE", 0.32, 0.03, H.on_front(o, face - 0.13, 1.4))


def rice_bag_brand(bm):
    o = R0
    face = -RBAG[1] / 2 - 0.03
    B.add_text(bm, "CENTRAL", 0.26, 0.03, H.on_front(o, face - 0.13, 2.05))


B.piece("RiceBag_Bag", RICE_BAG, rice_bag)
B.piece("RiceBag_Band", NAVY, rice_bag_band)
B.piece("RiceBag_Grains", LABEL_WHITE, rice_bag_grains)
B.piece("RiceBag_Label", LABEL_WHITE, rice_bag_label)
B.piece("RiceBag_Words", INK, rice_bag_words, smooth=False)
B.piece("RiceBag_Brand", BLUE, rice_bag_brand, smooth=False)

# ================================================================ BroccoliBit (at x 27)
F0 = at("BroccoliBit", 27.0)


def bit_head(bm):
    o = F0
    H.sphere(bm, o + V((0, 0, 0.62)), 0.3, scale=(1, 1, 0.75), segments=8, rings=5)
    for k in range(5):
        a = 2 * math.pi * k / 5
        H.sphere(bm, o + V((0.26 * math.cos(a), 0.26 * math.sin(a), 0.54)), 0.2, scale=(1, 1, 0.8), segments=7, rings=4)


def bit_stem(bm):
    H.cylinder(bm, F0 + V((0, 0, 0.25)), 0.13, 0.5, segments=8, radius2=0.1)


B.piece("BroccoliBit_Head", FLORET, bit_head)
B.piece("BroccoliBit_Stem", STEM, bit_stem)

# ================================================================ bounds per item (each relative to its own origin)

bpy.context.view_layer.update()
bounds = {}
for item, x in ITEMS.items():
    lo = V((1e9, 1e9, 1e9))
    hi = -lo
    for ob in B.coll.objects:
        if not ob.name.startswith(item + "_"):
            continue
        for corner in ob.bound_box:
            w = ob.matrix_world @ V(corner) - V((x, 0, 0))
            lo = V(map(min, lo, w))
            hi = V(map(max, hi, w))
    bounds[item] = {"low": [round(v, 4) for v in lo], "high": [round(v, 4) for v in hi]}

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
tris = {}
for ob in B.coll.objects:
    item = ob.name.split("_")[0]
    tris[item] = tris.get(item, 0) + sum(len(p.vertices) - 2 for p in ob.data.polygons)
print("WCHEWS MEAL PROPS BUILT:", len(B.coll.objects), "objects; triangles", tris, "; bounds", bounds)
