# Unlockable fail styles (user 2026-11-11: "Replace the failure itself", "3 styles", played at every meet): each style
# is a full set of the six fails (fail_animations.py), one for each part of each lift, made with the same rig and
# helpers. Like the defaults, each starts about where its part stops in the meet (the server cross-fades into it), ends
# standing (bench: lying, relaxed), and lets go of the bar at its "release" (the spotters take it; the deadlift is set
# down), the spotters reaching it at "catch". Lengths stay near the defaults' so no meet gets slower.
#
#   GRINDER   long shaking grinds that get close, then give out
#   BAILOUT   quick escapes: dumps the squat off the back, lets go at once on the bench, drops the deadlift fast
#   DRAMATIC  big collapses and frustration: floor slaps, hands on the head, flopped out on the bench
#
#   blender -b --factory-startup --python art/scripts/fail_styles.py -- [preview folder]
# writes art/animations/Fail_<Style>_<Lift>_<Part>.rbxmx (Action priority, not looped) and, with a folder, preview
# sheets there. Publish with art/scripts/upload_animations.py; ids and timings go in StationAnimationConfig.FailStyles.
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
sq, dl, bk, HANG, tremble = F.sq, F.dl, F.bk, F.HANG, F.tremble
SAMPLE_STEP = F.SAMPLE_STEP


# ---------------------------------------------------------------- helpers
def arms_to(p, target, start):
    """Arm angles that put the hands at `target` (root frame, left hand; the right mirrored) for a standing key."""
    a, _ = S.solve_arms(F.standing_body_pose(p), target, start)
    return a


def stand(arm=None, neck=-10.0):
    return sq(0.0, arm=arm or HANG, neck=neck)


def hips(neck=-22.0):
    s = stand(neck=neck)
    return F.planted(dict(s, arm=F.hands_on_hips(s), neck=neck))


def head_hands(neck=18.0):
    """Standing, both hands on top of the head, looking up: frustration."""
    s = stand(neck=neck)
    # On top of the head: 0.414 above the head's centre (2.3 on the taller rig, user 2026-11-12; 2.0 on the block rig).
    top = Vector((-0.55, S.BENCH_HEAD_UP + 0.414, 0.15))
    return F.planted(dict(s, arm=arms_to(s, top, {"raise": 120.0, "swing": 20.0, "twist": -30.0, "elbow": 120.0}),
                          neck=neck))


def bent_over(neck=10.0):
    """Bent over, hands on the knees, catching a breath."""
    p = {"torso": -42.0, "thigh": 18.0, "shin": -14.0, "toes": S.SQUAT_TOES_OUT, "arm": HANG, "neck": neck}
    p = F.planted(p)
    p["arm"] = arms_to(p, Vector((-0.75, S.up_body(-1.35), -0.75)), {"raise": 10.0, "swing": 40.0, "twist": 0.0,
                                                                     "elbow": 10.0})
    return F.planted(p)


# Pushing the squat bar up and back off the shoulders (a bail-out dump), then the hands come away.
PUSH = {"raise": 60.0, "swing": -10.0, "twist": 60.0, "elbow": 90.0}
PUSH_UP = {"raise": 140.0, "swing": -25.0, "twist": 30.0, "elbow": 20.0}
SHAKE_OUT = {"raise": 14.0, "swing": 6.0, "twist": 0.0, "elbow": 20.0}


# ---------------------------------------------------------------- bench keys with free arms
# bk() keys drive both arms along the press; a bench key here may also carry its own arm angles ("armL", "armR",
# S.arms parameters) blended in by "free" (0 the press, 1 the given arms), for gestures while lying.
RELAXED = F.RELAXED


def bkf(ul, ur=None, kick_l=0.0, kick_r=0.0, relax=0.0, neck=0.0, free=0.0, arm_l=None, arm_r=None):
    k = bk(ul, ur, kick_l, kick_r, relax, neck)
    k["free"] = free
    k["armL"] = dict(arm_l or RELAXED)
    k["armR"] = dict(arm_r or arm_l or RELAXED)
    return k


def build_bench(p, extra_u=0.0):
    thigh, table = F._bench()
    pose = {"Neck": S.rx(p["neck"])}
    left = S._bench_legs_at(thigh + p["kl"])
    right = S._bench_legs_at(thigh + p["kr"])
    for k in ("LeftHip", "LeftKnee", "LeftAnkle"):
        pose[k] = left[k]
    for k in ("RightHip", "RightKnee", "RightAnkle"):
        pose[k] = right[k]

    def arm(u, own):
        a = S.lerp_angles(table, max(0.0, min(1.0, u + extra_u)))
        a = F.lerp(a, RELAXED, p["relax"])
        return F.lerp(a, own, p.get("free", 0.0))
    al = S.arms(arm(p["ul"], p.get("armL", RELAXED)))
    ar = S.arms(arm(p["ur"], p.get("armR", RELAXED)))
    pose["LeftShoulder"], pose["LeftElbow"] = al["LeftShoulder"], al["LeftElbow"]
    pose["RightShoulder"], pose["RightElbow"] = ar["RightShoulder"], ar["RightElbow"]
    return pose


def sample(keys, t, shake):
    a, b, u = F.at(keys, t)
    if a["mode"] == "bench":
        return build_bench(F.lerp_params(a, b, u), shake)
    return F._sample(keys, t, shake)


# ---------------------------------------------------------------- GRINDER
def grinder_squat_1():
    return [(0.0, sq(0.6)), (0.5, sq(1.0, torso_add=-10.0)), (1.0, sq(0.97, torso_add=-12.0)),
            (2.6, sq(0.8, torso_add=-16.0)), (3.0, sq(0.82, torso_add=-18.0)), (3.5, sq(1.02, torso_add=-20.0)),
            (4.3, stand()), (5.2, hips())]


def grinder_squat_2():
    return [(0.0, sq(1.0)), (0.6, sq(0.9, torso_add=-8.0)), (2.4, sq(0.66, torso_add=-12.0)),
            (3.0, sq(0.68, torso_add=-14.0)), (3.6, sq(1.0, torso_add=-16.0)), (4.6, stand(neck=-12.0)),
            (5.6, hips(-24.0))]


def grinder_bench_1():
    return [(0.0, bkf(0.5)), (0.4, bkf(1.0)), (0.7, bkf(0.97)), (2.3, bkf(0.78, 0.8)), (2.8, bkf(0.8, 0.82)),
            (3.2, bkf(1.0)), (3.7, bkf(1.0, relax=1.0, neck=-6.0)), (4.6, bkf(1.0, relax=1.0, neck=-10.0))]


def grinder_bench_2():
    return [(0.0, bkf(1.0)), (1.6, bkf(0.5, 0.52)), (2.4, bkf(0.46, 0.5)), (3.0, bkf(1.0)),
            (3.5, bkf(1.0, relax=1.0, neck=-6.0)), (4.6, bkf(1.0, relax=1.0, neck=-10.0))]


def grinder_deadlift_1():
    b = F._dl_bottom()
    inch = dl(0.9, torso_add=-8.0, thigh_add=-b[1] * 0.25, shin_add=-b[2] * 0.25)
    return [(0.0, dl(1.0)), (0.4, dl(1.0, torso_add=-4.0)), (2.0, inch), (2.4, inch), (2.8, dl(1.0)),
            (3.5, dl(0.0, held=False)), (4.0, dl(0.0, held=False, arm=F._dl_hips_arm(), neck=-20.0)),
            (4.8, dl(0.0, held=False, arm=F._dl_hips_arm(), neck=-24.0))]


def grinder_deadlift_2():
    return [(0.0, dl(0.70)), (1.6, dl(0.45, torso_add=-3.0, shin_add=-3.0)), (2.1, dl(0.47, torso_add=-4.0)),
            (2.6, dl(1.0)), (3.2, dl(0.0, held=False)), (3.9, dl(0.0, held=False, arm=F._dl_hips_arm(), neck=-20.0))]


# ---------------------------------------------------------------- BAILOUT
def bailout_squat_1():
    return [(0.0, sq(0.6)), (0.3, sq(0.72, torso_add=10.0, arm=PUSH)), (0.6, sq(0.68, torso_add=8.0, arm=PUSH_UP)),
            (1.0, sq(0.5, torso_add=-6.0, arm=HANG)), (1.6, stand()), (2.4, hips()), (3.4, hips(-26.0))]


def bailout_squat_2():
    return [(0.0, sq(1.0)), (0.3, sq(1.0, torso_add=10.0, arm=PUSH)), (0.55, sq(0.95, torso_add=8.0, arm=PUSH_UP)),
            (1.3, sq(0.4, arm=HANG)), (2.0, stand()), (2.7, hips()), (3.4, hips(-26.0))]


def bailout_bench_1():
    return [(0.0, bkf(0.5)), (0.3, bkf(0.95)), (0.55, bkf(0.95)), (1.1, bkf(1.0, relax=1.0, neck=-4.0)),
            (3.0, bkf(1.0, relax=1.0, neck=-8.0))]


def bailout_bench_2():
    return [(0.0, bkf(1.0)), (0.4, bkf(0.75)), (0.65, bkf(0.78)), (1.2, bkf(1.0, relax=1.0, neck=-4.0)),
            (3.0, bkf(1.0, relax=1.0, neck=-8.0))]


def bailout_deadlift_1():
    return [(0.0, dl(1.0)), (0.4, dl(0.97, torso_add=-4.0)), (0.8, dl(1.0)), (1.5, dl(0.0, held=False)),
            (2.2, dl(0.0, held=False, arm=SHAKE_OUT, neck=-6.0)), (3.4, dl(0.0, held=False, arm=F._dl_hips_arm(),
                                                                          neck=-20.0))]


def bailout_deadlift_2():
    return [(0.0, dl(0.70)), (0.3, dl(0.74)), (0.6, dl(0.76, held=False, neck=0.0)), (1.4, dl(0.0, held=False)),
            (2.2, dl(0.0, held=False, arm=F._dl_hips_arm(), neck=-20.0)),
            (3.0, dl(0.0, held=False, arm=F._dl_hips_arm(), neck=-24.0))]


# ---------------------------------------------------------------- DRAMATIC
def dramatic_squat_1():
    keys = F._squat_1_keys()
    by_time = dict(keys)
    kneel = by_time[1.8]
    slap_up = dict(kneel, arm={"raise": 14.0, "swing": 105.0, "twist": 0.0, "elbow": 70.0}, neck=4.0)
    return [(0.0, keys[0][1]), (0.6, by_time[0.6]), (1.1, by_time[1.1]), (1.45, by_time[1.45]), (1.8, kneel),
            (2.15, slap_up), (2.4, kneel), (2.75, slap_up), (3.0, kneel), (3.6, dict(kneel, neck=-10.0)),
            (4.4, sq(1.0, torso_add=-14.0, arm={"raise": 10.0, "swing": 55.0, "twist": 0.0, "elbow": 25.0},
                     neck=10.0)),
            (5.0, stand()), (5.6, head_hands())]


def dramatic_squat_2():
    keys = F._squat_2_keys()
    sit = keys[-3][1] if len(keys) >= 3 else keys[-1][1]
    for _, k in keys:
        if k.get("mode") == "ground":
            sit = k
            break
    sit_head = dict(sit, arm={"raise": 115.0, "swing": 30.0, "twist": -40.0, "elbow": 140.0}, neck=24.0)
    return [(0.0, sq(1.0)), (0.45, sq(0.86, torso_add=-8.0)), (1.6, sq(0.88, torso_add=-12.0)),
            (2.6, sit), (3.2, sit_head), (4.2, sit_head), (5.0, stand(neck=-6.0)), (5.6, hips())]


def dramatic_bench_1():
    flop = {"raise": 80.0, "swing": 0.0, "twist": 0.0, "elbow": 10.0}
    return [(0.0, bkf(0.5)), (0.35, bkf(1.0)), (0.7, bkf(0.95, 1.0, kick_l=40.0)), (1.0, bkf(1.0, 0.95, kick_r=40.0)),
            (1.3, bkf(0.96, 0.98, kick_l=40.0)), (1.6, bkf(0.98, 0.96, kick_r=40.0)), (2.2, bkf(1.0)),
            (2.8, bkf(1.0, relax=1.0, neck=-6.0, free=1.0, arm_l=flop)),
            (4.6, bkf(1.0, relax=1.0, neck=-12.0, free=1.0, arm_l=flop))]


def dramatic_bench_2():
    face = {"raise": 12.0, "swing": 150.0, "twist": 0.0, "elbow": 115.0}
    return [(0.0, bkf(1.0)), (0.6, bkf(0.67, 0.65)), (1.0, bkf(0.74, 0.6)), (1.9, bkf(0.76, 0.62)), (2.5, bkf(1.0)),
            (2.8, bkf(1.0)), (3.4, bkf(1.0, relax=1.0, free=1.0, arm_l=face, neck=-4.0)),
            (4.0, bkf(1.0, relax=1.0, free=1.0, arm_l=face, neck=-6.0)),
            (4.6, bkf(1.0, relax=1.0, neck=-10.0))]


def dramatic_deadlift_1():
    b = F._dl_bottom()
    stuck = dl(0.95, torso_add=-6.0, thigh_add=-b[1] * 0.4, shin_add=-b[2] * 0.4)
    return [(0.0, dl(1.0)), (0.5, stuck), (1.4, stuck), (1.8, dl(1.0)), (2.2, stuck), (2.8, dl(1.0)),
            (3.5, dl(0.0, held=False)), (4.1, dl(0.0, held=False, arm=head_hands()["arm"], neck=18.0)),
            (4.8, dl(0.0, held=False, arm=head_hands()["arm"], neck=16.0))]


def dramatic_deadlift_2():
    soft = dict(torso_add=-8.0, shin_add=-8.0)
    down = {"raise": 8.0, "swing": -30.0, "twist": 0.0, "elbow": 5.0}
    return [(0.0, dl(0.70)), (0.5, dl(0.72, **soft)), (1.0, dl(0.62, torso_add=-4.0, shin_add=-4.0)),
            (1.3, dl(0.75, **soft)), (1.45, dl(0.76, **soft)), (1.8, dl(0.76, held=False, neck=0.0, **soft)),
            (2.3, dl(0.0, held=False, arm=down, neck=-12.0)), (3.0, bent_over()), (3.9, bent_over(6.0))]


# ---------------------------------------------------------------- the styles
def grind(t0, t1, amp, hz=7.0):
    return lambda t: tremble(t, t0, t1, amp, hz)


STYLES = {
    "Grinder": {
        "Squat_1": (grinder_squat_1, 5.2, 3.6, 3.2, grind(0.9, 3.4, 1.8)),
        "Squat_2": (grinder_squat_2, 5.6, 3.8, 3.4, grind(0.5, 3.5, 1.9)),
        "Bench_1": (grinder_bench_1, 4.6, 3.4, 3.1, grind(0.8, 3.0, 0.025, 8.0)),
        "Bench_2": (grinder_bench_2, 4.6, 3.3, 2.9, grind(0.4, 2.6, 0.025, 8.0)),
        "Deadlift_1": (grinder_deadlift_1, 4.8, 2.9, None, grind(0.3, 2.6, 2.0)),
        "Deadlift_2": (grinder_deadlift_2, 3.9, 2.7, None, grind(0.2, 2.2, 1.6)),
    },
    "Bailout": {
        "Squat_1": (bailout_squat_1, 3.4, 0.6, 0.5, grind(0.0, 0.0, 0.0)),
        "Squat_2": (bailout_squat_2, 3.4, 0.55, 0.45, grind(0.0, 0.0, 0.0)),
        "Bench_1": (bailout_bench_1, 3.0, 0.7, 0.45, grind(0.0, 0.0, 0.0)),
        "Bench_2": (bailout_bench_2, 3.0, 0.8, 0.55, grind(0.0, 0.0, 0.0)),
        "Deadlift_1": (bailout_deadlift_1, 3.4, 0.9, None, grind(0.1, 0.8, 1.0)),
        "Deadlift_2": (bailout_deadlift_2, 3.0, 0.35, None, grind(0.0, 0.0, 0.0)),
    },
    "Dramatic": {
        "Squat_1": (dramatic_squat_1, 5.6, 1.3, 0.9, grind(0.4, 1.2, 1.5)),
        "Squat_2": (dramatic_squat_2, 5.6, 2.6, 2.1, grind(0.5, 2.2, 1.6)),
        "Bench_1": (dramatic_bench_1, 4.6, 2.2, 1.5, grind(0.5, 2.2, 0.03, 9.0)),
        "Bench_2": (dramatic_bench_2, 4.6, 2.8, 2.2, grind(0.7, 2.4, 0.04, 9.0)),
        "Deadlift_1": (dramatic_deadlift_1, 4.8, 3.0, None, grind(0.4, 2.8, 2.2)),
        "Deadlift_2": (dramatic_deadlift_2, 3.9, 1.45, None, grind(0.2, 1.4, 1.5)),
    },
}
_KEYS = {}


def pose_of(style, name):
    keys_fn, length, _release, _catch, shake = STYLES[style][name]

    def pose(t):
        key = (style, name)
        if key not in _KEYS:
            _KEYS[key] = keys_fn()
        return sample(_KEYS[key], max(0.0, min(length, t)), shake(t))
    return pose


# ---------------------------------------------------------------- export, checks, previews
def export(style, name):
    _, length, *_ = STYLES[style][name]
    pose = pose_of(style, name)
    clip = f"Fail_{style}_{name}"
    refs = iter(range(1, 1_000_000))
    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
           f'<Item class="KeyframeSequence" referent="RBX{next(refs)}"><Properties>'
           f'<float name="AuthoredHipHeight">{S.AUTHORED_HIP_HEIGHT:g}</float><bool name="Loop">false</bool>'
           f'<string name="Name">{clip}</string><token name="Priority">2</token>'
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

    steps = int(round(length / SAMPLE_STEP))
    for i in range(steps + 1):
        t = i * SAMPLE_STEP
        out.append(f'<Item class="Keyframe" referent="RBX{next(refs)}"><Properties>'
                   f'<string name="Name">Keyframe</string><float name="Time">{t:.3f}</float></Properties>')
        out.append(pose_xml("HumanoidRootPart", pose(t)))
        out.append("</Item>")
    out.append("</Item></roblox>")
    path = os.path.join(S.OUT_DIR, f"{clip}.rbxmx")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    return path


def base_of(name):
    return S.PREVIEW_BASES["Bench"] if name.startswith("Bench") else S.T((0, S.HRP_STAND_Y, 0))


def lowest(style, name):
    """The lowest corner of the feet, shins, hands, torso and head through the clip (nothing may go below 0; the bench
    figure lies over a bench that isn't there, so its number is only compared with the default's)."""
    _, length, *_ = STYLES[style][name]
    pose = pose_of(style, name)
    low = 9.0
    t = 0.0
    while t <= length + 1e-6:
        w = S.forward_kinematics(base_of(name), pose(t))
        for part in ("LeftFoot", "RightFoot", "LeftLowerLeg", "RightLowerLeg", "LeftHand", "RightHand", "LowerTorso", "Head"):
            sx, sy, sz = S.SIZES[part]
            m = w[part]
            low = min(low, min((m @ Vector((x * sx / 2, y * sy / 2, z * sz / 2))).y
                               for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)))
        t += 0.05
    return low


def preview(folder):
    import bpy
    E_spec = importlib.util.spec_from_file_location("entrance_animations", os.path.join(_HERE, "entrance_animations.py"))
    E = importlib.util.module_from_spec(E_spec)
    E_spec.loader.exec_module(E)
    os.makedirs(folder, exist_ok=True)
    for style, fails in STYLES.items():
        for name, (_, length, release, catch, _) in fails.items():
            scene = E._scene_setup(bpy)
            count, spacing = 8, 4.6
            pose = pose_of(style, name)
            for i in range(count):
                t = length * i / (count - 1)
                objs = E._figure(bpy, f"F{i}", E.COLOURS[0] if t < release else E.COLOURS[2])
                world = S.forward_kinematics(base_of(name), pose(t))
                for part, ob in objs.items():
                    ob.matrix_world = Matrix.Translation(Vector((i * spacing, 0, 0))) @ S.TO_BLENDER @ world[part]
            centre = Vector(((count - 1) * spacing / 2, 0, 2.2))
            # Standing fails from in front (they face Blender -Y); bench fails from above, a little toward the feet.
            view = Vector((3.0, -20.0, 4.0)) if not name.startswith("Bench") else Vector((0.0, -9.0, 22.0))
            E._camera(bpy, scene, centre + view, centre, count * spacing + 2)
            scene.render.resolution_x, scene.render.resolution_y = 1800, 520
            scene.render.filepath = os.path.join(folder, f"Fail_{style}_{name}.png")
            bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    for style, fails in STYLES.items():
        for name, (_, length, release, catch, _) in fails.items():
            print(f"CHECK Fail_{style}_{name}: {length} s, release {release}, catch {catch}, lowest {lowest(style, name):.2f}")
            print("EXPORTED", export(style, name))
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argv:
        preview(argv[0])
    print("DONE")
