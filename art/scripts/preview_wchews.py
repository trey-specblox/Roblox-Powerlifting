# Preview of the whole W Chews restaurant, assembled in Blender to floor plan 02 exactly as the game will place it
# (art/scripts/wchews_layout.py), drawn with backface culling on, as Roblox draws (CLAUDE.md: 3D models).
# Nothing is saved: it only renders pictures.
#
#   blender -b art/blender/WChewsHall_01.blend --python art/scripts/preview_wchews.py -- <out folder> [view names...]

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, r"D:\Powerlifting Roblox\art\scripts")
import wchews_layout as L  # noqa: E402

ART = r"D:\Powerlifting Roblox\art\blender"
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else r"D:\ClaudeScratch\wchews"
ONLY = set(argv[1:])
scene = bpy.context.scene


def append(blend, prefixes):
    """The mesh objects of another .blend whose names start with one of `prefixes`, unlinked (templates)."""
    with bpy.data.libraries.load(os.path.join(ART, blend)) as (src, dst):
        dst.objects = [n for n in src.objects if n.startswith(prefixes)]
    return [o for o in dst.objects if o is not None and o.type == "MESH"]


def group(objects):
    items = {}
    for ob in objects:
        items.setdefault(ob.name.split("_")[0], []).append(ob)
    return items


def bounds(objects):
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for ob in objects:
        for corner in ob.bound_box:
            w = Matrix.Translation(ob.location) @ Vector(corner)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def turned(x, y, z, turn=0.0, scale=1.0):
    return Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(turn), 4, "Z") @ Matrix.Diagonal((scale, scale, scale, 1))


def place(objects, matrix, tint=None):
    for ob in objects:
        copy = ob.copy()  # shares the mesh
        copy.matrix_world = matrix @ Matrix.Translation(ob.location)
        scene.collection.objects.link(copy)
        if tint and ob.name in tint:
            copy.material_slots[0].link = "OBJECT"
            copy.material_slots[0].material = tint[ob.name]


def flat(name, colour):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*colour, 1)
    bsdf.inputs["Roughness"].default_value = 0.9
    return mat


# The chairs' colourways as the game paints them (StarterGymConfig.PropColourways): 1 teal (the model's), 2, 3.
CUSHIONS = {2: {"WcChair_Cushion": flat("PreviewBurgundy", (0.42, 0.07, 0.12))},
            3: {"WcChair_Cushion": flat("PreviewMustard", (0.85, 0.60, 0.14))}}
kit = group(append("WChewsKit_01.blend", ("Wc",)))
kit.update(group(append("WChewsBack_01.blend", ("Wc",))))
for item, colourway, x, y, z, turn, scale in L.PLACEMENTS:
    place(kit[item], turned(x, y, z, turn, scale), CUSHIONS.get(colourway) if item == "WcChair" else None)

# The luck wheel's 20 wedges round its axis, as the game's code places them (three tints so the wheel reads).
WEDGE_TINTS = [flat("PreviewWedgeCream", (0.92, 0.88, 0.76)), flat("PreviewWedgeRed", (0.72, 0.12, 0.12)),
               flat("PreviewWedgeGreen", (0.07, 0.36, 0.22)), flat("PreviewWedgeGold", (0.92, 0.70, 0.18))]
for k in range(L.WHEEL_WEDGES):
    spin = Matrix.Rotation(math.radians(360.0 * k / L.WHEEL_WEDGES), 4, "Y")
    place(kit["WcWheelWedge"], Matrix.Translation((L.WHEEL[0], L.WHEEL[1], L.WHEEL_AXIS)) @ spin,
          {"WcWheelWedge_Face": WEDGE_TINTS[3 if k == 0 else k % 3]})

# The mafia boss cow at his spot (when his model exists).
if os.path.exists(os.path.join(ART, "WChewsCowBoss_01.blend")):
    place(append("WChewsCowBoss_01.blend", ("CowBoss",)), turned(L.COW[0], L.COW[1], 0))

# The grinder (GrinderScale 1.3) at its plan-02 spot, its outlet toward the entrance.
grinder = append("KitchenGrinder_02.blend", ("MeatGrinder",))
lo, hi = bounds(grinder)
place(grinder, turned(L.GRINDER[0], L.GRINDER[1], 0, 0, L.GRINDER_SCALE) @ Matrix.Translation((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)))

# The 40 pans and clocks as KitchenPans places them (PanScale 2.2, sunk 4.5; the clock 1.4, 17.6 behind).
pan_parts = group(append("KitchenPan_01.blend", ("GiantPan", "PanClock")))
stand = next(o for o in pan_parts["GiantPan"] if o.name == "GiantPan_Stand")
clo, chi = bounds(pan_parts["PanClock"])
for x in L.PAN_COLUMNS:
    for y in L.PAN_ROWS:
        place(pan_parts["GiantPan"], turned(x, y, -4.5, 0, 2.2) @ Matrix.Translation((-stand.location.x, -stand.location.y, 0)))
        place(pan_parts["PanClock"], turned(x, y + 17.6, 0, 0, 1.4) @ Matrix.Translation((-(clo.x + chi.x) / 2, -(clo.y + chi.y) / 2, -clo.z)))

for m in bpy.data.materials:
    m.use_backface_culling = True
    if m.use_nodes:
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf and bsdf.inputs["Alpha"].default_value < 0.99:
            try:
                m.surface_render_method = "BLENDED"
            except (AttributeError, TypeError):
                pass

try:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
except TypeError:
    scene.render.engine = "BLENDER_EEVEE"
try:
    scene.view_settings.view_transform = "Standard"
except TypeError:
    pass
world = bpy.data.worlds.new("PreviewWorld")
scene.world = world
world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs[0].default_value = (0.5, 0.52, 0.56, 1)
bg.inputs[1].default_value = 0.55


def sun(name, energy, rot, colour=(1, 1, 1)):
    data = bpy.data.lights.new(name, "SUN")
    data.energy = energy
    data.color = colour
    data.use_shadow = False  # an even indoor fill: it shines through the roof
    ob = bpy.data.objects.new(name, data)
    ob.rotation_euler = [math.radians(a) for a in rot]
    scene.collection.objects.link(ob)


sun("PreviewKey", 2.2, (35, 0, 20))
sun("PreviewFill", 1.1, (50, 0, -150))
sun("PreviewSide", 0.7, (70, 0, 100))
sun("PreviewUp", 1.3, (180, 0, 0))  # lights the ceilings (the other suns shine down)

cam_data = bpy.data.cameras.new("PreviewCam")
cam_data.lens = 22
cam_data.clip_end = 2000
cam = bpy.data.objects.new("PreviewCam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.resolution_x = 1600
scene.render.resolution_y = 900

VIEWS = {
    "01_FromTheDoor": ((0, -105, 6.5), (0, 40, 7)),
    "02_Dining": ((-72, -106, 9), (40, -36, 3)),
    "03_ChefCounter": ((-26, -70, 7), (6, -24, 5)),
    "04_IntoKitchen": ((0, -8, 11), (0, 70, 9)),
    "05_GrinderStation": ((44, -2, 15), (-2, 44, 8)),
    "06_KitchenWide": ((-276, 4, 32), (40, 150, 0)),
    "07_CookingLine": ((66, 16, 10), (190, -19, 7)),
    "08_ColdStorage": ((-104, 247, 9), (-200, 262, 6)),
    "09_SinksAndStaffDoor": ((168, 246, 8), (250, 266, 5)),
    "10_PansAndTube": ((56, 58, 16), (190, 150, 6)),
    "11_BackRoom": ((200, 330, 9), (275, 275, 5)),
    "13_BackFromDoor": ((248, 270, 6.5), (248, 331, 7)),
    "14_BackWheel": ((240, 306, 7), (252, 331, 7)),
    "15_BackLeft": ((262, 312, 9), (200, 280, 4)),
    "16_BackRight": ((228, 312, 9), (283, 285, 4)),
    "17_BackDesk": ((252, 300, 8), (274, 322, 4)),
    "18_BackMilkBar": ((236, 296, 8), (214, 268, 5)),
}
for name, (pos, target) in VIEWS.items():
    if ONLY and name not in ONLY:
        continue
    pos, target = Vector(pos), Vector(target)
    cam.location = pos
    cam.rotation_euler = (target - pos).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, "WChews_" + name + ".png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED", name)

if not ONLY or "12_TopNoRoof" in ONLY:
    for ob in scene.collection.all_objects:
        if ob.name.split(".")[0] in ("WChewsHall_Ceiling", "WChewsHall_Beams", "WChewsHall_LightPanels",
                                     "WChewsHall_FrontCeiling", "WChewsHall_FrontBeams", "WChewsHall_FrontCove",
                                     "WChewsHall_BackCeiling"):
            ob.hide_render = True
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 600
    cam.location = (0, 113, 300)
    cam.rotation_euler = (0, 0, 0)
    scene.render.resolution_y = 1280
    scene.render.filepath = os.path.join(OUT, "WChews_12_TopNoRoof.png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED top")
