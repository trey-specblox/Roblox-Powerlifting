# The meet meal's food dispenser and the pile of food on the pan (GAME_DESIGN §40.7, user 2026-11-23: "Instead of the
# chef dropping the chicken in and pouring the stuff, lets add a dispenser on top of the bay. Where the chef can just
# press the button and out comes the chickens, brocolli, and rice ... when the food drops into the pan lets not have
# the plate also drop with the food ... just have the food piling up scaling with how much food is being cooked, then
# when its done then the plate scaling of the size of the food is in place").
#
# Two items, each round its own origin, the front toward -Y:
#   WcMealDispenser  a steel frame standing on the meat bay's side rails across its FRONT half, three hoppers hanging
#                    from its beam: CHICKEN (left, -x), BROCCOLI (middle), RICE (right), each with a window showing what
#                    is inside, a label, a funnel, a chute down into the bay and a red gate at its mouth; CENTRAL on the
#                    beam, an amber lamp on top. Origin = the bay's centre on the floor (placed like WcTubeIntake). It
#                    stays clear of the tube's funnel over the bay's middle (mouth radius 4.9 at 14.5 up) and of the
#                    intake run above the front (its underside 24.5 up).
#   MealPile         the food cooking on the pan, NO plate: a mound of rice, grilled chicken breasts and broccoli
#                    florets heaped on it. About 10 across at scale 1 (as MeetMeal): the game scales it to the cook.
#
# Every layer stands at least 0.05 proud of what it lies on, or cuts into it (memory "No flicker, no overlap").
#
#   blender -b --factory-startup --python art/scripts/build_wchews_dispenser_01.py -- <out.blend> [<out.glb>]

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

B = H.Builder("WChewsDispenser")
V = Vector

STEEL = H.material("Wc_Steel", (0.80, 0.82, 0.85), metallic=0.9, roughness=0.28)
STEEL_DARK = H.material("Wc_SteelDark", (0.42, 0.44, 0.48), metallic=0.85, roughness=0.35)
GLASS = H.material("Wc_Glass", (0.62, 0.80, 0.88), metallic=0.2, roughness=0.1, alpha=0.3)
NAVY = H.material("Wc_Navy", (0.05, 0.08, 0.21), roughness=0.55)
YELLOW = H.material("Wc_GlowYellow", (1.0, 0.84, 0.25), emission=(1.0, 0.78, 0.15))
RED = H.material("Wc_Red", (0.82, 0.12, 0.10), roughness=0.45)
AMBER = H.material("Wc_Amber", (1.0, 0.6, 0.1), emission=(1.0, 0.5, 0.05))
HEN = H.material("Meal_HenWhite", (0.97, 0.96, 0.93), roughness=0.7)
COMB = H.material("Meal_HenRed", (0.86, 0.12, 0.12), roughness=0.5)
GREEN = H.material("Meal_Broccoli", (0.1, 0.42, 0.12), roughness=0.7)
RICE = H.material("Meal_Rice", (0.96, 0.94, 0.86), roughness=0.75)
CHICKEN = H.material("Meal_Chicken", (0.82, 0.52, 0.22), roughness=0.6)
STEM = H.material("Meal_Stem", (0.55, 0.75, 0.3), roughness=0.65)

ITEMS = {}


def at(item, x):
    ITEMS[item] = x
    return V((x, 0, 0))


# ================================================================ WcMealDispenser (at x 0)
D0 = at("WcMealDispenser", 0.0)
RAIL = 12.65  # the bay's side rails' middle line (x), their top 12 up
HY = -8.5  # the hoppers' middle (y): the front half of the bay
HX = (-8.4, 0.0, 8.4)  # CHICKEN, BROCCOLI, RICE
HW, HD = 5.2, 4.6  # a hopper's width and depth
H0, H1 = 14.5, 19.5  # a hopper's body, bottom and top
BEAM0, BEAM1 = 20.0, 20.8
FACE = HY - HD / 2  # the hoppers' front face (y)
LABELS = ("CHICKEN", "BROCCOLI", "RICE")


def frame(bm):
    o = D0
    for sx in (-1, 1):
        # a leg standing on each side rail, with a foot plate
        H.span(bm, o + V((sx * RAIL - 0.3, HY - 0.3, 12.0)), o + V((sx * RAIL + 0.3, HY + 0.3, BEAM1)))
        H.span(bm, o + V((sx * RAIL - 0.35, HY - 1.2, 12.0)), o + V((sx * RAIL + 0.35, HY + 1.2, 12.25)))
        # a brace from the leg to the beam
        H.box(bm, o + V((sx * (RAIL - 1.3), HY, BEAM0 - 1.2)), (0.25, 0.25, 3.4),
              rotation=Matrix.Rotation(sx * math.radians(45), 4, "Y"))
    # the cross beam
    H.span(bm, o + V((-RAIL - 0.3, HY - 0.5, BEAM0)), o + V((RAIL + 0.3, HY + 0.5, BEAM1)))
    # each hopper hangs from it by two short straps
    for x in HX:
        for dx in (-1.6, 1.6):
            H.span(bm, o + V((x + dx - 0.15, HY - 0.15, H1 - 0.05)), o + V((x + dx + 0.15, HY + 0.15, BEAM0 + 0.05)))


def bodies(bm):
    o = D0
    for x in HX:
        H.rounded_box(bm, o + V((x, HY, (H0 + H1) / 2)), (HW, HD, H1 - H0), 0.3, segments=2)
        # the funnel under it, round, to the chute; the chute down into the bay
        H.cylinder(bm, o + V((x, HY, H0 - 1.15)), 2.25, 2.4, segments=16, radius2=0.95)
        H.cylinder(bm, o + V((x, HY, 11.4)), 0.95, 2.0, segments=12)
        # a lid on top
        H.rounded_box(bm, o + V((x, HY, H1 + 0.1)), (HW - 0.6, HD - 0.6, 0.3), 0.1, segments=1)


def window_contents(bm, x, kind):
    # What shows through the window: bumps half-sunk into the hopper's front face (y FACE), under the glass.
    o = D0
    y = FACE + 0.02
    if kind == "CHICKEN":
        for k, (dx, dz) in enumerate(((-1.0, 15.7), (0.9, 15.8), (0.0, 17.0), (-1.2, 17.6), (1.1, 17.4))):
            H.sphere(bm, o + V((x + dx, y, dz)), 0.62, scale=(1.0, 0.35, 0.85), segments=10, rings=6)
    elif kind == "BROCCOLI":
        # floret heads: each a clump of a middle bump and three round it
        for k in range(9):
            dx, dz = -1.35 + (k % 3) * 1.35, 15.6 + (k // 3) * 0.95
            c = o + V((x + dx, y, dz))
            H.sphere(bm, c, 0.32, scale=(1.0, 0.35, 0.9), segments=7, rings=4)
            for j in range(3):
                a = 2 * math.pi * j / 3 + k
                H.sphere(bm, c + V((0.25 * math.cos(a), 0, 0.25 * math.sin(a))), 0.22, scale=(1.0, 0.35, 0.9),
                         segments=6, rings=4)
    else:
        H.sphere(bm, o + V((x, y, 16.0)), 1.9, scale=(1.0, 0.18, 0.75), segments=14, rings=7)


def contents_hens(bm):
    window_contents(bm, HX[0], "CHICKEN")


def contents_combs(bm):
    # little red combs on the hens' heads in the window
    o = D0
    for dx, dz in ((-1.0, 15.7), (0.9, 15.8), (0.0, 17.0), (-1.2, 17.6), (1.1, 17.4)):
        H.sphere(bm, o + V((HX[0] + dx, FACE - 0.18, dz + 0.42)), 0.14, scale=(1.4, 0.6, 0.8), segments=6, rings=4)


def contents_beaks(bm):
    # little yellow beaks, so the white shapes read as hens (not eggs)
    o = D0
    for dx, dz in ((-1.0, 15.7), (0.9, 15.8), (0.0, 17.0), (-1.2, 17.6), (1.1, 17.4)):
        H.cylinder(bm, o + V((HX[0] + dx + 0.42, FACE - 0.12, dz + 0.1)), 0.11, 0.3, axis="X", segments=6, radius2=0.01)


def contents_greens(bm):
    window_contents(bm, HX[1], "BROCCOLI")


def contents_rice(bm):
    window_contents(bm, HX[2], "RICE")


def windows(bm):
    # A glass pane in front of the contents (0.3 in front of the face: the bumps stand at most 0.24 out).
    o = D0
    for x in HX:
        H.span(bm, o + V((x - 2.0, FACE - 0.36, 15.0)), o + V((x + 2.0, FACE - 0.3, 18.3)))


def window_frames(bm):
    o = D0
    for x in HX:
        for x0, x1, z0, z1 in ((x - 2.2, x + 2.2, 14.8, 15.0), (x - 2.2, x + 2.2, 18.3, 18.5), (x - 2.2, x - 2.0, 14.8, 18.5),
                               (x + 2.0, x + 2.2, 14.8, 18.5)):
            H.span(bm, o + V((x0, FACE - 0.42, z0)), o + V((x1, FACE + 0.05, z1)))


def label_plates(bm):
    o = D0
    for x in HX:
        H.span(bm, o + V((x - 2.2, FACE - 0.12, 18.65)), o + V((x + 2.2, FACE + 0.05, 19.35)))
    # CENTRAL's plate on the beam's front
    H.span(bm, o + V((-3.0, HY - 0.6, BEAM0 + 0.05)), o + V((3.0, HY - 0.45, BEAM1 - 0.05)))


def label_text(bm):
    o = D0
    for x, word in zip(HX, LABELS):
        B.add_text(bm, word, 0.48, 0.03, H.on_front(o + V((x, 0, 0)), FACE - 0.14, 19.0))
    B.add_text(bm, "CENTRAL", 0.5, 0.03, H.on_front(o, HY - 0.62, (BEAM0 + BEAM1) / 2))


def gates(bm):
    # a red flap at each chute's mouth
    o = D0
    for x in HX:
        H.cylinder(bm, o + V((x, HY, 10.3)), 1.15, 0.25, segments=14)


def lamp(bm):
    o = D0
    H.sphere(bm, o + V((0, HY, BEAM1 + 0.35)), 0.55, scale=(1, 1, 0.8), segments=12, rings=6)


B.piece("WcMealDispenser_Frame", STEEL_DARK, frame, smooth=False)
B.piece("WcMealDispenser_Body", STEEL, bodies)
B.piece("WcMealDispenser_Hens", HEN, contents_hens)
B.piece("WcMealDispenser_Combs", COMB, contents_combs)
B.piece("WcMealDispenser_Beaks", H.material("Meal_HenBeak", (0.98, 0.72, 0.1), roughness=0.5), contents_beaks)
B.piece("WcMealDispenser_Greens", GREEN, contents_greens)
B.piece("WcMealDispenser_Rice", RICE, contents_rice)
B.piece("WcMealDispenser_Glass", GLASS, windows, smooth=False)
B.piece("WcMealDispenser_Trim", STEEL_DARK, window_frames, smooth=False)
B.piece("WcMealDispenser_Plates", NAVY, label_plates, smooth=False)
B.piece("WcMealDispenser_Text", YELLOW, label_text, smooth=False)
B.piece("WcMealDispenser_Gates", RED, gates)
B.piece("WcMealDispenser_Lamp", AMBER, lamp)

# ================================================================ MealPile (at x 40)
P0 = at("MealPile", 40.0)
# (2026-11-23: a wide low dome with a clean edge read as a PLATE: now a tall heap, its foot broken up by rice clumps)
MOUND_R, MOUND_H = 3.5, 2.4


def mound_z(x, y):
    d = math.hypot(x, y) / MOUND_R
    return MOUND_H * max(0.0, 1 - d * d) ** 0.7


def pile_rice(bm):
    profile = [(0.0, 0.0)]
    for k in range(10):
        r = MOUND_R * (1 - k / 9)
        profile.append((r + 0.1 * math.sin(k * 2.3), mound_z(r, 0)))
    profile[-1] = (0.0, MOUND_H)
    H.lathe_z(bm, profile, segments=28, centre=P0)
    # rice clumps round the foot and on the slope, half sunk in, so the edge is a heap's, not a rim
    for k in range(18):
        a = 2 * math.pi * k / 18 + 0.3 * math.sin(k)
        r = MOUND_R * (0.92 if k % 2 else 0.7)
        x, y = r * math.cos(a), r * math.sin(a)
        H.sphere(bm, P0 + V((x, y, mound_z(x, y))), 0.55 if k % 2 else 0.45, scale=(1, 1, 0.7), segments=8, rings=4)


def loft(bm, rings):
    layers = [[bm.verts.new(V((x, y, z))) for x, y in ring] for ring, z in rings]
    bm.faces.new(list(reversed(layers[0])))
    bm.faces.new(layers[-1])
    n = len(layers[0])
    for low, high in zip(layers, layers[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((low[i], low[j], high[j], high[i]))


# (kept near the top: one far down the steep side hung down it like a slab)
BREASTS = ((-1.0, 0.7, -25), (1.0, 0.9, 40), (0.4, -1.0, 10), (-0.2, 0.0, 75), (1.3, -0.5, -40))  # x, y, turn


def pile_chicken(bm):
    # grilled chicken breasts lying ON the heap: every point of a breast follows the slope under it (sunk 0.15 in), so
    # none floats over the side of the heap or sinks into it
    for cx, cy, turn in BREASTS:
        a = math.radians(turn)
        rings = []
        for share, rise in ((1.0, -0.15), (1.0, 0.25), (0.75, 0.45)):
            pts = []
            for k in range(16):
                t = 2 * math.pi * k / 16
                x, y = 1.15 * share * math.cos(t), (0.62 + 0.16 * math.cos(t)) * share * math.sin(t)
                px, py = cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)
                pts.append(V((P0.x + px, P0.y + py, mound_z(px, py) + rise)))
            rings.append(pts)
        layers = [[bm.verts.new(p) for p in ring] for ring in rings]
        bm.faces.new(list(reversed(layers[0])))
        bm.faces.new(layers[-1])
        for low, high in zip(layers, layers[1:]):
            for i in range(16):
                j = (i + 1) % 16
                bm.faces.new((low[i], low[j], high[j], high[i]))


FLORETS = ((2.6, 0.2), (-0.9, 2.3), (1.0, -0.2), (-2.6, -0.4), (1.6, 2.2), (-1.4, -1.9), (0.2, 1.4))


def pile_heads(bm):
    for fx, fy in FLORETS:
        top = mound_z(fx, fy) + 0.75
        c = P0 + V((fx, fy, top))
        H.sphere(bm, c, 0.48, scale=(1, 1, 0.75), segments=8, rings=5)
        for k in range(5):
            a = 2 * math.pi * k / 5 + fx
            H.sphere(bm, c + V((0.42 * math.cos(a), 0.42 * math.sin(a), -0.12)), 0.32, scale=(1, 1, 0.8),
                     segments=7, rings=4)


def pile_stems(bm):
    for fx, fy in FLORETS:
        base = mound_z(fx, fy) - 0.1
        H.cylinder(bm, P0 + V((fx, fy, base + 0.4)), 0.24, 0.8, segments=8, radius2=0.18)


B.piece("MealPile_Rice", RICE, pile_rice)
B.piece("MealPile_Chicken", CHICKEN, pile_chicken)
B.piece("MealPile_Broccoli", GREEN, pile_heads)
B.piece("MealPile_Stems", STEM, pile_stems)

# ================================================================ bounds per item (relative to its own origin)
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
print("WCHEWS DISPENSER BUILT:", len(B.coll.objects), "objects; triangles", tris, "; bounds", bounds)
