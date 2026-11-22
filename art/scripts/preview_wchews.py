# Preview of the whole W Chews restaurant, assembled in Blender to floor plan 02 exactly as the game will place it
# (art/scripts/wchews_layout.py), drawn with backface culling on, as Roblox draws (CLAUDE.md: 3D models).
# Nothing is saved: it only renders pictures.
#
#   blender -b art/blender/WChewsHall_02.blend --python art/scripts/preview_wchews.py -- <out folder> [view names...]
#
# "+cow" among the names: the double door stands open and the mafia boss cow's double is in the doorway, as in the
# chef scene's background (KitchenScene). The 3x_Scene views are that scene's two bay shots, from its real camera
# spots with its real lens.

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
ONLY = {a for a in argv[1:] if not a.startswith("+")}
FLAGS = {a for a in argv[1:] if a.startswith("+")}
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
kit.update(group(append("WChewsDoor_01.blend", ("Wc",))))
for item, colourway, x, y, z, turn, scale in L.PLACEMENTS:
    if item == "WcDoubleDoor" and "+cow" in FLAGS:
        # Open, as the game opens it (KitchenBackDoor): each leaf turned 90 degrees into the back room about the
        # corner of its hung edge on the back room's side.
        fixed = [o for o in kit[item] if "_Leaf" not in o.name]
        place(fixed, turned(x, y, z, turn, scale))
        for side, sign in (("L", -1), ("R", 1)):
            hinge = Matrix.Translation((sign * L.LEAF_HINGE, L.LEAF_HALF_THICK, 0))
            swing = hinge @ Matrix.Rotation(math.radians(-sign * 90), 4, "Z") @ hinge.inverted()
            place([o for o in kit[item] if "_Leaf" + side in o.name], turned(x, y, z, turn, scale) @ swing)
        continue
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
    cow = append("WChewsCowBoss_01.blend", ("CowBoss",))
    if "+cow" in FLAGS:
        place(cow, turned(L.DOOR_X + 0.5, L.BACK_WALL_Y - 2.5, 0, 180))  # (his double, walking through the doorway)
    else:
        place(cow, turned(L.COW[0], L.COW[1], 0))

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

D = L.BACK_DX  # (the back room's views were set up round a doorway at x 248)
DX = L.DOOR_X


def scene_shot(cam, subject, weight=0.6):
    """A bay shot of the chef scene (KitchenScene): from `cam`, aimed between `subject` (the bay) and the double
    door, `weight` of the way toward the subject; 40 degrees of picture, top to bottom."""
    cam = Vector(cam)
    door = Vector((DX, L.BACK_WALL_Y, L.DOOR_HEIGHT / 2))
    aim = (Vector(subject) - cam).normalized() * weight + (door - cam).normalized() * (1 - weight)
    return (tuple(cam), tuple(cam + aim * 50), 40.0)


VIEWS = {
    "01_FromTheDoor": ((0, -105, 6.5), (0, 40, 7)),
    "02_Dining": ((-72, -106, 9), (40, -36, 3)),
    "03_ChefCounter": ((-26, -70, 7), (6, -24, 5)),
    "04_IntoKitchen": ((0, -8, 11), (0, 70, 9)),
    "05_GrinderStation": ((44, -2, 15), (-2, 44, 8)),
    "06_KitchenWide": ((-276, 4, 32), (40, 150, 0)),
    "07_CookingLine": ((66, 16, 10), (190, -19, 7)),
    "08_ColdStorage": ((-104, 247, 9), (-200, 262, 6)),
    "09_SinksAndOldDoorPlace": ((168, 246, 8), (250, 266, 5)),
    "10_PansAndTube": ((56, 58, 16), (190, 150, 6)),
    "11_BackRoom": ((200 + D, 330, 9), (275 + D, 275, 5)),
    "13_BackFromDoor": ((248 + D, 270, 6.5), (248 + D, 331, 7)),
    "14_BackWheel": ((240 + D, 306, 7), (252 + D, 331, 7)),
    "15_BackLeft": ((262 + D, 312, 9), (200 + D, 280, 4)),
    "16_BackRight": ((228 + D, 312, 9), (283 + D, 285, 4)),
    "17_BackDesk": ((252 + D, 300, 8), (274 + D, 322, 4)),
    "18_BackMilkBar": ((236 + D, 296, 8), (214 + D, 268, 5)),
    # The double door in the middle of the back wall.
    "20_DoorFromTheAisle": ((DX - 14, 206, 8), (DX, 266, 8)),
    "21_DoorClose": ((DX + 3, 243, 6.5), (DX, 266, 8.5)),
    "22_DoorSide": ((DX - 26, 252, 7), (DX - 2, 265, 7)),
    "23_DoorFromBackRoom": ((DX + 9, 292, 7), (DX, 267, 6.5)),
    "24_DoorHingeFromBackRoom": ((DX + 14, 274, 6), (DX + 7.6, 268, 6)),
    "25_AisleFromGrinder": ((DX, 76, 12), (DX, 266, 6)),
    # What a player sees walking in (Roblox's own 70 degree lens): from the doors, and a few steps to one side.
    "26_WalkingIn": ((0, -104, 7), (0, 60, 7), 70.0),
    "27_WalkingInAside": ((30, -40, 7), (DX, 266, 7), 70.0),
    "28_FromFirstPans": ((60, 20, 8), (DX, 266, 7), 70.0),
    # The chef scene's two bay shots (KitchenScene: the grinding shot, the suction shot).
    "30_SceneGrind": scene_shot((-20.75, -14, 12.45), (0, 36, 4.0)),
    "31_SceneSuction": scene_shot((26, -14, 4.5), (0, 36, 11.0)),
    "32_SceneGrindOldLens": ((-15.75, 11.5, 8.95), (0, 36, 4.0), 70.0),
}
for name, view in VIEWS.items():
    if ONLY and name not in ONLY:
        continue
    pos, target = Vector(view[0]), Vector(view[1])
    if len(view) > 2:  # (a lens given as degrees of picture, top to bottom, as Roblox's FieldOfView)
        cam_data.sensor_fit = "VERTICAL"
        cam_data.angle_y = math.radians(view[2])
    else:
        cam_data.sensor_fit = "AUTO"
        cam_data.lens = 22
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
