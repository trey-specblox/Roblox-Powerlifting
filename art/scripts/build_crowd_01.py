# Crowd_01: the fake spectators filling the Local meet's stands (GAME_DESIGN §29.10, user 2026-11-05: "Dont forget to
# fill in the stands with fake characters"). Blocky seated figures, in the game's character style, on the seats of
# LocalMeet_01's Bleachers. No real players' avatars.
#
#   CrowdA, CrowdB   one section's crowd each, a different seating and different poses: 8 places in each of 4 rows, some
#                    empty; some cheer with an arm or both arms up. Every section of stands gets one, and the game
#                    colours it from a colourway (StarterGymConfig.PropColourways), so sections differ.
#
# PERFORMANCE: every section shares these meshes, about 4,500 triangles a section (10 sections in a hall, and only the
# hall a player is in is loaded). A figure is a few boxes. The game makes them decor: no collision, no touch events, no
# shadows.
#
# Geometry as LocalMeet_01's Bleachers (art/scripts/build_local_meet_01.py): centred on x = 0, y = 0, front toward -Y, steps
# 3 deep and 1.5 high, seat tops 0.18 above each step, seat planks from 0.2 to 1.9 back from each step's front.
# It prints each item's bounds: LocalMeetVenue needs them, because a prop's pivot is the bottom centre of its bounds.
#
# Units, axes and names as in prop_helpers.py. Run headless, so a live Blender keeps what it has open:
#   blender -b --python art/scripts/build_crowd_01.py -- <out.blend> <out.glb> <preview.png>

import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prop_helpers as H  # noqa: E402

bpy.ops.wm.read_factory_settings(use_empty=True)
B = H.Builder("Crowd_01")


def linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, rgb):
    return H.material("Crowd_" + name, tuple(linear(c) for c in rgb), 0.0, 0.7)


# Preview colours only: Roblox colours each piece from StarterGymConfig.PropColourways.
SKINS = [mat("Skin1", (232, 190, 160)), mat("Skin2", (190, 136, 96)), mat("Skin3", (112, 72, 50))]
SHIRTS = [mat("Shirt1", (200, 30, 38)), mat("Shirt2", (30, 92, 205)), mat("Shirt3", (242, 190, 30)),
          mat("Shirt4", (236, 236, 232)), mat("Shirt5", (0, 138, 140))]
PANTS = [mat("Pants1", (30, 48, 98)), mat("Pants2", (46, 48, 54))]
HAIRS = [mat("Hair1", (30, 24, 20)), mat("Hair2", (110, 74, 40))]
EYES = mat("Eyes", (20, 20, 24))

SEATS_PER_ROW = 8
SECTION_W = 24.0
ROWS = 4
STEP_D = 3.0
STEP_H = 1.5
FRONT_Y = -ROWS * STEP_D / 2
SEAT_TOP_ABOVE_STEP = 0.18
FILLED = 0.82

TORSO = Vector((1.7, 0.85, 1.9))
HEAD = 1.05
ARM = 0.62
LEG = 0.72
THIGH = 1.55
SHIN = 1.6


def figure(parts, x, row, rng):
    """Adds one seated figure's boxes to `parts`, a dict of piece name -> list of (centre, size)."""
    y0 = FRONT_Y + row * STEP_D
    seat = (row + 1) * STEP_H + SEAT_TOP_ABOVE_STEP
    back = y0 + 1.5
    skin, shirt, pants, hair = (rng.randrange(len(SKINS)), rng.randrange(len(SHIRTS)), rng.randrange(len(PANTS)),
                                rng.randrange(len(HAIRS)))
    x += rng.uniform(-0.2, 0.2)
    top = seat + LEG
    # Thighs out to the seat's front, shins down from there.
    for side in (-1, 1):
        leg_x = x + side * 0.45
        parts["Pants%d" % (pants + 1)].append((Vector((leg_x, back - THIGH / 2 + 0.2, seat + LEG / 2)),
                                               Vector((LEG, THIGH, LEG))))
        parts["Pants%d" % (pants + 1)].append((Vector((leg_x, back - THIGH + 0.2 + LEG / 2, seat - SHIN / 2)),
                                               Vector((LEG, LEG, SHIN))))
    parts["Shirt%d" % (shirt + 1)].append((Vector((x, back, top + TORSO.z / 2)), TORSO))
    # Head, hair and eyes, the face toward -Y.
    head_z = top + TORSO.z + HEAD / 2 + 0.02
    parts["Skin%d" % (skin + 1)].append((Vector((x, back, head_z)), Vector((HEAD, HEAD, HEAD))))
    parts["Hair%d" % (hair + 1)].append((Vector((x, back + 0.08, head_z + HEAD / 2 + 0.08)),
                                         Vector((HEAD + 0.08, HEAD + 0.04, 0.2))))
    for side in (-1, 1):
        parts["Eyes"].append((Vector((x + side * 0.22, back - HEAD / 2 - 0.01, head_z + 0.08)),
                              Vector((0.14, 0.04, 0.18))))
    # Arms: down on the thighs, or up cheering.
    pose = rng.random()
    up = [] if pose < 0.6 else ([rng.choice((-1, 1))] if pose < 0.85 else [-1, 1])
    for side in (-1, 1):
        arm_x = x + side * (TORSO.x / 2 + ARM / 2)
        if side in up:
            parts["Shirt%d" % (shirt + 1)].append((Vector((arm_x, back, top + TORSO.z + 0.55)), Vector((ARM, ARM, 1.9))))
            parts["Skin%d" % (skin + 1)].append((Vector((arm_x, back, top + TORSO.z + 1.7)), Vector((ARM, ARM, 0.42))))
        else:
            parts["Shirt%d" % (shirt + 1)].append((Vector((arm_x, back, top + TORSO.z - 0.75)), Vector((ARM, ARM, 1.5))))
            parts["Skin%d" % (skin + 1)].append((Vector((arm_x, back - 0.32, top + 0.02)), Vector((ARM, 0.95, 0.42))))


def build(item, seed):
    rng = random.Random(seed)
    names = ["Skin1", "Skin2", "Skin3", "Shirt1", "Shirt2", "Shirt3", "Shirt4", "Shirt5", "Pants1", "Pants2", "Hair1",
             "Hair2", "Eyes"]
    parts = {name: [] for name in names}
    slot = SECTION_W / SEATS_PER_ROW
    count = 0
    for row in range(ROWS):
        for seat in range(SEATS_PER_ROW):
            # The two end places of the back row are always taken, which keeps the bounds centred on x = 0.
            edge = row == ROWS - 1 and seat in (0, SEATS_PER_ROW - 1)
            if edge or rng.random() < FILLED:
                x = -SECTION_W / 2 + slot * (seat + 0.5)
                figure(parts, x, row, random.Random(rng.random()) if not edge else random.Random(seed + seat))
                count += 1
    materials = {m.name.replace("Crowd_", ""): m for m in SKINS + SHIRTS + PANTS + HAIRS + [EYES]}
    objects = []
    for name in names:
        boxes = parts[name]
        if not boxes:
            continue

        def make(bm, boxes=boxes):
            for centre, size in boxes:
                H.box(bm, centre, size)

        objects.append(B.piece("%s_%s" % (item, name), materials[name], make, smooth=False))
    lows = [Vector(o.location) + Vector(c) for o in objects for c in o.bound_box]
    low = Vector([min(v[i] for v in lows) for i in range(3)])
    high = Vector([max(v[i] for v in lows) for i in range(3)])
    tris = sum(len(o.data.polygons) * 2 for o in objects)
    print("BOUNDS %s figures=%d tris=%d low=(%.3f, %.3f, %.3f) high=(%.3f, %.3f, %.3f) centre=(%.3f, %.3f)" % (
        item, count, tris, low.x, low.y, low.z, high.x, high.y, high.z, (low.x + high.x) / 2, (low.y + high.y) / 2))
    return objects


objects = build("CrowdA", 7) + build("CrowdB", 23)
# CrowdB beside CrowdA in the file, as the other prop files lay items side by side.
for ob in objects:
    if ob.name.startswith("CrowdB"):
        ob.location.x += 30

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(argv) >= 1:
    bpy.ops.wm.save_as_mainfile(filepath=argv[0])
if len(argv) >= 2:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=argv[1], export_format="GLB", use_selection=True, export_apply=True)
if len(argv) >= 3:
    # A preview as Roblox draws them: one-sided faces.
    scene = bpy.context.scene
    camera = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    scene.collection.objects.link(camera)
    target = Vector((15, 0, 5))
    camera.location = Vector((15, -40, 18))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = 32
    scene.camera = camera
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_backface_culling = True
    scene.render.resolution_x, scene.render.resolution_y = 1280, 560
    scene.render.filepath = argv[2]
    bpy.ops.render.render(write_still=True)
print("DONE")
