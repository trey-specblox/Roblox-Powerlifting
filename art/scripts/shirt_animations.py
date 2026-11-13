# The bench shirt holds the arms forward (GAME_DESIGN 35.12, user's photo, 2026-11-06): a stiff shirt pulls them out in front.
#
#   BenchShirt_ArmsForward  both arms held forward, elbows a little bent, with a slow small sway. Only the arms are keyed
#                           (Weight 0 on the torso's poses), so the legs and body go on walking and idling.
#
# Exported at Movement priority: above walking and idling, below every lift, chalk, station and cardio animation, which are all
# Action, so those simply take over while they play. No game code has to stop it.
#
#   blender -b --factory-startup --python art/scripts/shirt_animations.py
# writes art/animations/BenchShirt_ArmsForward.rbxmx. Publish with art/scripts/upload_animations.py.
import importlib.util
import math
import os

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"D:\Powerlifting Roblox\art\scripts"
_spec = importlib.util.spec_from_file_location("station_animations", os.path.join(_HERE, "station_animations.py"))
S = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(S)

NAME = "BenchShirt_ArmsForward"
LENGTH = 3.0
STEP = 0.5
# In Roblox's enum order: Idle 0, Movement 1, Action 2.
MOVEMENT = 1
ARM_JOINTS = ("LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow")


def pose(t):
    sway = math.sin(2 * math.pi * t / LENGTH)
    return S.arms({"raise": 6.0, "swing": 74.0 + 2.0 * sway, "twist": 0.0, "elbow": 12.0 + 2.0 * sway})


def main():
    refs = iter(range(1, 1_000_000))
    children = {}
    for joint, (parent, child, _c0, _c1) in S.JOINTS.items():
        children.setdefault(parent, []).append((child, joint))
    wanted = {"HumanoidRootPart", "LowerTorso", "UpperTorso", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm"}

    def pose_xml(part, transforms):
        joint = S.CHILD_JOINT.get(part)
        keyed = joint in ARM_JOINTS
        m = transforms[joint] if keyed else S.Matrix.Identity(4)
        s = (f'<Item class="Pose" referent="RBX{next(refs)}"><Properties>'
             f'<CoordinateFrame name="CFrame">{S._cframe_xml(m)}</CoordinateFrame>'
             f'<token name="EasingDirection">0</token><token name="EasingStyle">0</token>'
             f'<string name="Name">{part}</string><float name="Weight">{1 if keyed else 0}</float></Properties>')
        for child, _ in children.get(part, []):
            if child in wanted:
                s += pose_xml(child, transforms)
        return s + "</Item>"

    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
           f'<Item class="KeyframeSequence" referent="RBX{next(refs)}"><Properties>'
           f'<float name="AuthoredHipHeight">{S.AUTHORED_HIP_HEIGHT:g}</float><bool name="Loop">true</bool>'
           f'<string name="Name">{NAME}</string><token name="Priority">{MOVEMENT}</token>'
           f'</Properties>']
    for i in range(int(round(LENGTH / STEP)) + 1):
        t = i * STEP
        out.append(f'<Item class="Keyframe" referent="RBX{next(refs)}"><Properties>'
                   f'<string name="Name">Keyframe</string><float name="Time">{t:.3f}</float></Properties>')
        out.append(pose_xml("HumanoidRootPart", pose(t)))
        out.append("</Item>")
    out.append("</Item></roblox>")
    path = os.path.join(S.OUT_DIR, NAME + ".rbxmx")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    print("wrote", path)


main()
print("DONE")
