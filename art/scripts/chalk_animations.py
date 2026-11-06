# Chalking up before an attempt (GAME_DESIGN.md 37.5, user 2026-11-06), on the same Roblox R15 block rig and tools as
# the station reps (station_animations.py) and the fails (fail_animations.py):
#   Chalk_Lifter      leans to the stand, hands in the bowl, rubs them, comes up rubbing palms, claps twice, relaxes
#   Chalk_Coach_Back  behind the lifter on squat: rubs chalk across their upper back, two slaps, hands down
#   Chalk_Coach_Talk  in front of the lifter: holds the clipboard, talks with the other hand, nods
# All looped. Chalk_Lifter and Chalk_Coach_Back are the same length and start together; the claps and slaps fall at
# CLAPS and SLAPS, kept in step with LocalMeetConfig.Chalk.
#
# Distances: the lifter stands STAND_AHEAD from the stand's post (LocalMeetVenue), the coach COACH_BEHIND behind them.
#
#   blender -b --factory-startup --python art/scripts/chalk_animations.py -- <preview.png>
# writes art/animations/Chalk_<Name>.rbxmx and a preview of the key moments next to the real stand. Publish with
# art/scripts/upload_animations.py.
import importlib.util
import math
import os
import sys

from mathutils import Matrix, Vector

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\Powerlifting Roblox\art\scripts"
_spec = importlib.util.spec_from_file_location("fail_animations", os.path.join(_HERE, "fail_animations.py"))
F = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(F)
S = F.S

STAND_AHEAD = 1.75
COACH_BEHIND = 2.0
LOOP_SECONDS = 9.0
TALK_SECONDS = 4.0
CLAPS = (4.4, 4.77)
SLAPS = (4.85, 5.15)

HANG_HAND = Vector((-1.5, -0.85, 0.0))
STAND = {"torso": 0.0, "thigh": 0.0, "shin": 0.0, "toes": S.SQUAT_TOES_OUT, "neck": 0.0}
LEAN = {"torso": -20.0, "thigh": 12.0, "shin": -4.5, "toes": S.SQUAT_TOES_OUT, "neck": -4.0}
LOOK_AT_HANDS = {"torso": -3.0, "thigh": 2.0, "shin": -1.0, "toes": S.SQUAT_TOES_OUT, "neck": -8.0}
LOOK_AT_BACK = {"torso": -3.0, "thigh": 2.0, "shin": -1.0, "toes": S.SQUAT_TOES_OUT, "neck": -3.0}
SOLVE_STEPS = (4, 2, 1, 0.5, 0.25)
START_ARM = {"raise": 0.0, "swing": 45.0, "twist": 0.0, "elbow": 45.0}


def body_at(keys, t):
    a, b, u = F.at(keys, t)
    p = {k: a[k] + (b[k] - a[k]) * u for k in a}
    p["arm"] = F.HANG
    return F.planted(p)


def hand_at(keys, t):
    a, b, u = F.at(keys, t)
    return a.lerp(b, u)


def wave(t, t0, t1, hz):
    """A smooth back and forth between t0 and t1, faded in and out."""
    if t <= t0 or t >= t1:
        return 0.0
    edge = min(1.0, (t - t0) / 0.2, (t1 - t) / 0.2)
    return edge * math.sin(2 * math.pi * hz * (t - t0))


def mirror(v):
    return Vector((-v.x, v.y, v.z))


def preference(_world, a):
    # Elbows down and out, no needless twist: the hand's position alone leaves the arm free to turn oddly.
    return 0.002 * abs(a["twist"]) + 0.001 * abs(a["raise"])


class Clip:
    """One animation: `body(t)` gives a planted body, `hands(t)` both hands' centres in the root part's frame (the
    right hand given as its own true position). Each arm is solved on its own, so the hands can move differently."""

    def __init__(self, name, length, body, hands):
        self.name, self.length, self.body, self.hands = name, length, body, hands
        self.cache = {}
        self.left, self.right = dict(START_ARM), dict(START_ARM)
        self.worst = 0.0

    def pose(self, t):
        key = round(t, 3)
        if key in self.cache:
            return self.cache[key]
        p = self.body(t)
        body = F._body(p, p["root"])
        left, right = self.hands(t)
        a_left, miss_left = S.solve_arms(body, left, self.left, preference, 5.0, SOLVE_STEPS)
        a_right, miss_right = S.solve_arms(body, mirror(right), self.right, preference, 5.0, SOLVE_STEPS)
        self.left, self.right = a_left, a_right
        pose = dict(body)
        from_left, from_right = S.arms(a_left), S.arms(a_right)
        pose["LeftShoulder"], pose["LeftElbow"] = from_left["LeftShoulder"], from_left["LeftElbow"]
        pose["RightShoulder"], pose["RightElbow"] = from_right["RightShoulder"], from_right["RightElbow"]
        w = S.forward_kinematics(Matrix.Identity(4), pose)
        self.worst = max(self.worst, (w["LeftHand"].to_translation() - left).length,
                         (w["RightHand"].to_translation() - right).length)
        self.cache[key] = pose
        return pose


# ---------------------------------------------------------------- the lifter
BOWL_HAND = Vector((-0.55, -0.12, -STAND_AHEAD + 0.3))
CHEST_HAND = Vector((-0.5, 0.35, -1.05))
APART_HAND = Vector((-1.05, 0.42, -1.1))
LOW_HAND = Vector((-0.55, 0.0, -1.0))
LIFTER_HANDS = [
    (0.0, HANG_HAND), (0.5, HANG_HAND), (1.1, BOWL_HAND), (2.3, BOWL_HAND), (2.9, CHEST_HAND), (4.0, CHEST_HAND),
    (4.2, APART_HAND), (CLAPS[0], CHEST_HAND), (4.6, APART_HAND), (CLAPS[1], CHEST_HAND), (5.1, LOW_HAND),
    (5.8, HANG_HAND), (LOOP_SECONDS, HANG_HAND),
]
LIFTER_BODY = [(0.0, STAND), (0.5, STAND), (1.1, LEAN), (2.3, LEAN), (2.9, LOOK_AT_HANDS), (5.1, LOOK_AT_HANDS),
               (5.8, STAND), (LOOP_SECONDS, STAND)]


def lifter_body(t):
    p = body_at(LIFTER_BODY, t)
    return p


def lifter_hands(t):
    base = hand_at(LIFTER_HANDS, t)
    # Hands working in the bowl, then palms rubbing together, each hand opposite the other.
    bowl = wave(t, 1.15, 2.25, 2.2)
    palms = wave(t, 3.0, 3.95, 2.4)
    left = base + Vector((0, 0.03 * bowl + 0.18 * palms, 0.12 * bowl))
    right = mirror(base) + Vector((0, -0.03 * bowl - 0.18 * palms, -0.12 * bowl))
    return left, right


# ---------------------------------------------------------------- the coach, behind the lifter (squat)
ON_BACK = Vector((-0.62, 0.35, -(COACH_BEHIND - 0.7)))
OFF_BACK = ON_BACK + Vector((0, 0.1, 0.3))
COACH_BACK_HANDS = [
    (0.0, HANG_HAND), (0.3, HANG_HAND), (0.9, ON_BACK), (4.55, ON_BACK), (4.72, OFF_BACK), (SLAPS[0], ON_BACK),
    (5.02, OFF_BACK), (SLAPS[1], ON_BACK), (5.4, ON_BACK), (6.1, HANG_HAND), (LOOP_SECONDS, HANG_HAND),
]
COACH_BACK_BODY = [(0.0, STAND), (0.3, STAND), (0.9, LOOK_AT_BACK), (5.4, LOOK_AT_BACK), (6.1, STAND), (LOOP_SECONDS, STAND)]


def coach_back_body(t):
    return body_at(COACH_BACK_BODY, t)


def coach_back_hands(t):
    base = hand_at(COACH_BACK_HANDS, t)
    # Rubbing the chalk across the upper back, the hands going opposite ways.
    rub = wave(t, 1.0, 4.5, 1.3)
    side = wave(t, 1.0, 4.5, 0.65)
    return (base + Vector((0.12 * side, 0.2 * rub, 0)),
            mirror(base) + Vector((0.12 * side, -0.2 * rub, 0)))


# ---------------------------------------------------------------- the coach, in front of the lifter, talking
HOLD = Vector((-0.62, -0.2, -1.05))
TALK_LOW = Vector((-0.78, -0.1, -1.0))
TALK_HIGH = Vector((-0.7, 0.36, -1.2))
TALK_MID = Vector((-0.76, 0.14, -1.1))
TALK_HAND = [(0.0, TALK_LOW), (1.0, TALK_HIGH), (1.5, TALK_MID), (2.2, TALK_HIGH), (3.2, TALK_LOW), (TALK_SECONDS, TALK_LOW)]


def coach_talk_body(t):
    nod = 4.0 * math.sin(2 * math.pi * t * 2 / TALK_SECONDS)
    p = dict(STAND, neck=-3.0 + nod)
    p["arm"] = F.HANG
    return F.planted(p)


def coach_talk_hands(t):
    return HOLD, mirror(hand_at(TALK_HAND, t))


CLIPS = {
    "Lifter": Clip("Lifter", LOOP_SECONDS, lifter_body, lifter_hands),
    "Coach_Back": Clip("Coach_Back", LOOP_SECONDS, coach_back_body, coach_back_hands),
    "Coach_Talk": Clip("Coach_Talk", TALK_SECONDS, coach_talk_body, coach_talk_hands),
}


# ---------------------------------------------------------------- export
def sample_times(clip):
    """Every 0.1 s, every 0.05 s where it moves fast (the claps and slaps)."""
    times, t = [], 0.0
    while t < clip.length - 1e-6:
        times.append(round(t, 3))
        t += 0.05 if clip.name != "Coach_Talk" and 4.0 <= t < 5.3 else 0.1
    times.append(clip.length)
    return times


def export(clip):
    """Writes art/animations/Chalk_<name>.rbxmx (Action priority, looped)."""
    refs = iter(range(1, 1_000_000))
    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
           f'<Item class="KeyframeSequence" referent="RBX{next(refs)}"><Properties>'
           f'<float name="AuthoredHipHeight">2</float><bool name="Loop">true</bool>'
           f'<string name="Name">Chalk_{clip.name}</string><token name="Priority">2</token>'
           f'</Properties>']
    children = {}
    for joint, (parent, child, c0, c1) in S.JOINTS.items():
        children.setdefault(parent, []).append((child, joint))

    def pose_xml(part, transforms):
        joint = S.CHILD_JOINT.get(part)
        m = transforms.get(joint, Matrix.Identity(4)) if joint else Matrix.Identity(4)
        s = (f'<Item class="Pose" referent="RBX{next(refs)}"><Properties>'
             f'<CoordinateFrame name="CFrame">{S._cframe_xml(m)}</CoordinateFrame>'
             f'<token name="EasingDirection">0</token><token name="EasingStyle">0</token>'
             f'<string name="Name">{part}</string><float name="Weight">1</float></Properties>')
        for child, _ in children.get(part, []):
            s += pose_xml(child, transforms)
        return s + "</Item>"

    times = sample_times(clip)
    for t in times:
        out.append(f'<Item class="Keyframe" referent="RBX{next(refs)}"><Properties>'
                   f'<string name="Name">Keyframe</string><float name="Time">{t:.3f}</float></Properties>')
        out.append(pose_xml("HumanoidRootPart", clip.pose(t)))
        out.append("</Item>")
    out.append("</Item></roblox>")
    os.makedirs(S.OUT_DIR, exist_ok=True)
    path = os.path.join(S.OUT_DIR, f"Chalk_{clip.name}.rbxmx")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    return path, len(times), round(clip.worst, 3)


# ---------------------------------------------------------------- preview: real stand, the key moments side by side
def preview(path):
    import bpy
    import bmesh

    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    stand_file = os.path.join(S.ROOT_DIR, "art", "blender", "LocalMeet_03.blend")
    with bpy.data.libraries.load(stand_file) as (source, target):
        target.objects = [n for n in source.objects if n.startswith("MeetChalkStand_")]
    stand_parts = target.objects

    def colour(name, rgb):
        m = bpy.data.materials.new(name)
        m.diffuse_color = (*rgb, 1)
        return m

    looks = {"lifter_top": colour("LifterTop", (0.8, 0.08, 0.08)), "coach_top": colour("CoachTop", (0.03, 0.06, 0.2)),
             "skin": colour("Skin", (0.75, 0.5, 0.35)), "legs": colour("Legs", (0.12, 0.12, 0.14))}

    def figure(pose, at, top, turn=Matrix.Identity(4)):
        """A block body at `at` (Blender space): `at` is under the root part, on the floor."""
        world = S.forward_kinematics(S.T((0, S.HRP_STAND_Y, 0)), pose)
        for part, size in S.SIZES.items():
            if part == "HumanoidRootPart":
                continue
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Diagonal((*size, 1)))
            mesh = bpy.data.meshes.new(part)
            bm.to_mesh(mesh)
            bm.free()
            mesh.materials.append(looks[top] if "Torso" in part else looks["legs"] if "Leg" in part or "Foot" in part
                                  else looks["skin"])
            ob = bpy.data.objects.new(part, mesh)
            bpy.context.scene.collection.objects.link(ob)
            ob.matrix_world = Matrix.Translation(at) @ turn @ S.TO_BLENDER @ world[part]

    def stand_at(at):
        for source in stand_parts:
            ob = source.copy()
            bpy.context.scene.collection.objects.link(ob)
            ob.location = source.location + at

    # Roblox faces -Z, which TO_BLENDER turns into Blender -Y. The moments in a row along Y, seen from the side.
    moments = (("Lifter", 0.3), ("Lifter", 1.7), ("Lifter", 3.5), ("Lifter", CLAPS[0]), ("Back", 2.3), ("Back", SLAPS[0]),
               ("Talk", 1.0))
    for index, (kind, t) in enumerate(moments):
        at = Vector((0, index * 8.5, 0))
        if kind == "Lifter":
            figure(CLIPS["Lifter"].pose(t), at, "lifter_top")
            stand_at(at + Vector((0, -STAND_AHEAD, 0)))
        elif kind == "Back":
            figure(CLIPS["Lifter"].pose(t), at, "lifter_top")
            stand_at(at + Vector((0, -STAND_AHEAD, 0)))
            figure(CLIPS["Coach_Back"].pose(t), at + Vector((0, COACH_BEHIND, 0)), "coach_top")
        else:
            figure(CLIPS["Lifter"].pose(0.2), at, "lifter_top")
            # The coach a step in front, turned to face the lifter.
            figure(CLIPS["Coach_Talk"].pose(t), at + Vector((0, -3.2, 0)), "coach_top", Matrix.Rotation(math.pi, 4, "Z"))
    scene = bpy.context.scene
    camera = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
    scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 60
    centre = Vector((0, 3 * 8.5 - 0.5, 2.8))
    camera.location = centre + Vector((-40.0, -9.0, 6.0))
    camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_backface_culling = True
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.55, 0.57, 0.6)
    scene.display.shading.background_type = "WORLD"
    scene.render.resolution_x, scene.render.resolution_y = 1800, 420
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    for clip in CLIPS.values():
        print("EXPORTED", export(clip))
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argv:
        preview(argv[0])
    print("DONE")
