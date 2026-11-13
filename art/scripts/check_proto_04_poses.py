# Pose check for the PROTOTYPE 04 bodies (CHARACTER_ART_DIRECTION.md §7): rigs each body on the taller R15 skeleton
# (build_cartoon_rig_02.py's joints and automatic weights), poses it with the REAL animation files at their hardest
# moments (gear_fit_03.py's read_anim / pose_rig, exactly as Roblox applies them) and renders one row per pose.
# Read-only for every existing file: CartoonBodies_04_Proto.blend is opened and NOT saved.
#
#   blender -b art/blender/CartoonBodies_04_Proto.blend --python art/scripts/check_proto_04_poses.py -- <out_dir>
import os
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(ROOT, "art", "previews")
BUILDS = ("Skinny", "Heavy", "Muscular")
SPACING = 4.6
POSES = [
    ("Rest", None, None),
    ("SquatBottom", "Station_Squat", 1.9),
    ("BenchChest", "Station_Bench", 2.0),
    ("DeadliftBottom", "Station_Deadlift", 1.6),
    ("ArmsUp", "Celebrate_ArmsUpBounce", None),
    ("DoubleBiceps", "Emote_DoubleBiceps", None),
    ("ChestSlap", "Entrance_Hype_ChestSlap", None),
    ("BeltTighten", "Emote_BeltTighten", None),
    ("CrouchRoar", "Celebrate_CrouchRoarJump", None),
]


def lib(path, **extra):
    ns = {"__name__": "lib"}
    ns.update(extra)
    exec(open(path).read(), ns)
    return ns


src = open(os.path.join(SCRIPTS, "build_cartoon_rig_02.py")).read().split("\ncoll = collection()\nRESULTS")[0]
R = {"__name__": "rig02_lib"}
exec(src, R)
G = lib(os.path.join(SCRIPTS, "gear_fit_03.py"))
P = lib(os.path.join(SCRIPTS, "build_cartoon_body_04.py"), PROTO04_AS_LIBRARY=True)

coll = bpy.data.collections.new("PoseCheck")
bpy.context.scene.collection.children.link(coll)
for o in bpy.data.objects:
    o.hide_render = True

rigs = {}
for i, build in enumerate(BUILDS):
    spec = P["BUILDS"][build](P["TALLER"])
    body = bpy.data.objects["Proto_" + build].copy()
    body.data = body.data.copy()
    body.location = (0, 0, 0)
    body.name = "Pose_" + build
    coll.objects.link(body)
    body.hide_render = False
    j = R["joints"](spec["arm_x"], spec["arm_x"] - spec["pivot_x"])
    rig, order = R["make_rig"]("Pose" + build, j, coll)
    R["weight"](body, rig)
    for side in ("Left", "Right"):
        hand = bpy.data.objects["Proto_%s_%sHand" % (build, side)].copy()
        hand.data = hand.data.copy()
        hand.location = (0, 0, 0)
        coll.objects.link(hand)
        grp = hand.vertex_groups.new(name=side + "Hand")
        grp.add(list(range(len(hand.data.vertices))), 1.0, "REPLACE")
        bpy.ops.object.select_all(action="DESELECT")
        hand.select_set(True)
        body.select_set(True)
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.join()
    rig.location.x = i * SPACING
    rigs[build] = rig

sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading
sh.light, sh.color_type, sh.show_backface_culling, sh.show_cavity = "STUDIO", "MATERIAL", True, True
if sc.world is None:
    sc.world = bpy.data.worlds.new("W")
sc.world.color = (0.16, 0.17, 0.2)
sc.render.resolution_x, sc.render.resolution_y = 1500, 700
cd = bpy.data.cameras.new("PoseCam")
cd.type, cd.ortho_scale = "ORTHO", 13.5
cam = bpy.data.objects.new("PoseCam", cd)
coll.objects.link(cam)
sc.camera = cam
target = Vector((SPACING, 0, 2.8))
cam.location = target + Vector((-16, -22, 6))
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()

made = []
for name, anim, t in POSES:
    for build, rig in rigs.items():
        if anim is None:
            G["rest_rig"](rig)
        else:
            tt = t if t is not None else G["extreme_time"](anim)
            G["pose_rig"](rig, G["anim_at"](anim, tt))
    path = os.path.join(OUT, "PoseCheck_%s.png" % name)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    made.append((name, path))
    print("[PoseCheck]", name, path)
