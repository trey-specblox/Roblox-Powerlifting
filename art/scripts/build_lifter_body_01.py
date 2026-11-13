# The lifter body (GAME_DESIGN.md §38, "Body types"; §38.5 the realistic skeleton, user 2026-11-12).
#
# Builds one realistic body on the game's new skeleton from MPFB (MakeHuman for Blender, CC0 bodies; the extension
# is installed in Blender, its download kept in D:\Powerlifting Roblox Extras\RobloxKits\MPFB, outside the repo).
#
#   1. an MPFB human from macro sliders (BUILDS below), with MPFB's game_engine rig and weights
#   2. the head cut off at the neck (every player keeps their own Roblox head, shrunk to HEAD_SCALE)
#   3. arms and legs posed straight down, as Roblox's rest pose, and that pose made the new rest
#   4. scaled so the neck joint sits at NECK_Y studs (with the shrunk head the lifter stands about 5.2 studs)
#   5. a Roblox R15 skeleton (15 part-named bones + Root / HumanoidRootNode) at the body's own joints, the MPFB
#      weights merged into the 15 parts (at most 4 per vertex)
#   6. fewer triangles (performance: one body is about an avatar's worth), split into one mesh per R15 part
#      (the cuts keep the smooth normals, so no seams show)
#   7. exported as GLB (1 Blender unit = 1 stud), still facing MPFB's -Y: Roblox's importer turns it half round, so
#      in Roblox it faces -Z with the character's left at -X
#
# The joint table it prints (and writes to art/exports/LifterBody_01_joints.json) is the new rig for the animation
# scripts (station_animations.py JOINTS / SIZES), replacing the R15 block rig's.
#
# Run inside Blender with MPFB enabled:  exec(open(r"D:\Powerlifting Roblox\art\scripts\build_lifter_body_01.py").read())
import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

from bl_ext.user_default.mpfb.services.humanservice import HumanService

ROOT = r"D:\Powerlifting Roblox"
OUT_GLB = os.path.join(ROOT, "art", "exports", "LifterBody_01.glb")
OUT_JOINTS = os.path.join(ROOT, "art", "exports", "LifterBody_01_joints.json")
COLLECTION = "LifterBody"

NECK_Y = 4.35            # studs: the Neck joint (top of the neck stump), where the player's head sits
HEAD_SCALE = 0.7         # the player's own head, shrunk so a real body doesn't look like a bobblehead
TRIANGLES = 9000         # the whole body (head excluded), after decimating
ARM_OUT_DEG = 4.0        # arms hang this far out from straight down
MAX_INFLUENCES = 4

BUILDS = {
    "Average": {"gender": 1.0, "age": 0.5, "muscle": 0.5, "weight": 0.5, "proportions": 0.5, "height": 0.5,
                "cupsize": 0.5, "firmness": 0.5, "race": {"african": 0.333, "asian": 0.333, "caucasian": 0.334}},
}

# MPFB game_engine bones -> the R15 part each one's weight goes to ("_l" is the character's left).
PART_OF = {"pelvis": "LowerTorso", "spine_01": "LowerTorso",
           "spine_02": "UpperTorso", "spine_03": "UpperTorso", "neck_01": "UpperTorso", "head": "UpperTorso",
           "clavicle_l": "UpperTorso", "clavicle_r": "UpperTorso"}
for _s, _side in (("l", "Left"), ("r", "Right")):
    PART_OF["upperarm_" + _s] = _side + "UpperArm"
    PART_OF["lowerarm_" + _s] = _side + "LowerArm"
    PART_OF["hand_" + _s] = _side + "Hand"
    for _f in ("index", "middle", "ring", "pinky", "thumb"):
        for _i in (1, 2, 3):
            PART_OF["%s_0%d_%s" % (_f, _i, _s)] = _side + "Hand"
    PART_OF["thigh_" + _s] = _side + "UpperLeg"
    PART_OF["calf_" + _s] = _side + "LowerLeg"
    PART_OF["foot_" + _s] = _side + "Foot"
    PART_OF["ball_" + _s] = _side + "Foot"

PARTS = ["LowerTorso", "UpperTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm",
         "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]
# R15 joint: (parent part, child part)
JOINT_PARTS = {"Root": ("HumanoidRootPart", "LowerTorso"), "Waist": ("LowerTorso", "UpperTorso"),
               "Neck": ("UpperTorso", "Head"),
               "LeftShoulder": ("UpperTorso", "LeftUpperArm"), "LeftElbow": ("LeftUpperArm", "LeftLowerArm"),
               "LeftWrist": ("LeftLowerArm", "LeftHand"),
               "RightShoulder": ("UpperTorso", "RightUpperArm"), "RightElbow": ("RightUpperArm", "RightLowerArm"),
               "RightWrist": ("RightLowerArm", "RightHand"),
               "LeftHip": ("LowerTorso", "LeftUpperLeg"), "LeftKnee": ("LeftUpperLeg", "LeftLowerLeg"),
               "LeftAnkle": ("LeftLowerLeg", "LeftFoot"),
               "RightHip": ("LowerTorso", "RightUpperLeg"), "RightKnee": ("RightUpperLeg", "RightLowerLeg"),
               "RightAnkle": ("RightLowerLeg", "RightFoot")}


def log(*a):
    print("[LifterBody]", *a)


def collection():
    coll = bpy.data.collections.get(COLLECTION)
    if coll is None:
        coll = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(coll)
    for o in list(coll.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.orphans_purge(do_recursive=True)   # so the rebuilt meshes keep their plain names
    return coll


def move_to(obj, coll):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    coll.objects.link(obj)


def make_human(macro, coll):
    # detailed_helpers must stay on: MPFB places the rig's joints from those helper groups.
    body = HumanService.create_human(mask_helpers=True, detailed_helpers=True, extra_vertex_groups=True,
                                     feet_on_ground=True, scale=0.1, macro_detail_dict=macro)
    rig = HumanService.add_builtin_rig(body, "game_engine", import_weights=True)
    move_to(body, coll)
    move_to(rig, coll)
    bpy.context.view_layer.objects.active = body
    if body.data.shape_keys:
        bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
    for m in list(body.modifiers):
        if m.type == "MASK":
            body.modifiers.remove(m)
    return body, rig


def weight_of(v, index):
    for g in v.groups:
        if g.group == index:
            return g.weight
    return 0.0


def cut_to_body(body):
    """Keep the skin only (no helpers, eyes, teeth) and cut the head off; cap the neck."""
    me = body.data
    keep = body.vertex_groups["body"].index
    head = body.vertex_groups["head"].index
    doomed = set()
    for v in me.vertices:
        if weight_of(v, keep) <= 0.0 or weight_of(v, head) >= 0.5:
            doomed.add(v.index)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in doomed], context="VERTS")
    # Cap the neck: its open rim is the boundary loop highest up the body.
    loops = []
    seen = set()
    for e in bm.edges:
        if e.is_boundary and e not in seen:
            loop = [e]
            seen.add(e)
            grow = True
            while grow:
                grow = False
                for x in list(loop):
                    for v in x.verts:
                        for y in v.link_edges:
                            if y.is_boundary and y not in seen:
                                seen.add(y)
                                loop.append(y)
                                grow = True
            loops.append(loop)
    if loops:
        neck = max(loops, key=lambda l: sum(v.co.z for x in l for v in x.verts) / (2 * len(l)))
        bmesh.ops.holes_fill(bm, edges=neck, sides=0)
    bm.to_mesh(me)
    bm.free()
    log("skin vertices", len(me.vertices), "open rims", len(loops))


def pose_to_rest(body, rig):
    """Arms and legs straight down (Roblox's rest pose), then that pose becomes the new rest."""
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    out = math.sin(math.radians(ARM_OUT_DEG))

    def aim(name, direction):
        pb = rig.pose.bones[name]
        bpy.context.view_layer.update()
        cur = pb.matrix.copy()
        d = (cur.to_3x3() @ Vector((0, 1, 0))).normalized()
        rot = d.rotation_difference(direction.normalized()).to_matrix().to_4x4()
        at = cur.translation.copy()
        m = rot @ cur
        m.translation = at
        pb.matrix = m
        bpy.context.view_layer.update()

    for s, sx in (("l", 1), ("r", -1)):
        aim("upperarm_" + s, Vector((sx * out, 0, -1)))
        aim("lowerarm_" + s, Vector((sx * out, 0, -1)))
        aim("hand_" + s, Vector((sx * out, 0, -1)))
        aim("thigh_" + s, Vector((0, 0, -1)))
        aim("calf_" + s, Vector((0, 0.02, -1)))
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.objects.active = body
    for m in body.modifiers:
        if m.type == "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=m.name)
            break
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def joint_points(rig):
    """Where each R15 joint is (Blender space, MPFB facing -Y with its left at +X), in metres."""
    b = rig.data.bones
    p = {}
    hips = (b["thigh_l"].head_local + b["thigh_r"].head_local) / 2
    p["Root"] = Vector((0, hips.y, hips.z))
    p["Waist"] = Vector((0, b["spine_02"].head_local.y, b["spine_02"].head_local.z))
    p["Neck"] = Vector((0, b["head"].head_local.y, b["head"].head_local.z))
    for s, side in (("l", "Left"), ("r", "Right")):
        p[side + "Shoulder"] = b["upperarm_" + s].head_local.copy()
        p[side + "Elbow"] = b["lowerarm_" + s].head_local.copy()
        p[side + "Wrist"] = b["hand_" + s].head_local.copy()
        p[side + "Hip"] = b["thigh_" + s].head_local.copy()
        p[side + "Knee"] = b["calf_" + s].head_local.copy()
        p[side + "Ankle"] = b["foot_" + s].head_local.copy()
    return p


def merge_weights(body):
    """One vertex group per R15 part; at most MAX_INFLUENCES per vertex, normalised."""
    vg = body.vertex_groups
    src = {g.index: PART_OF[g.name] for g in vg if g.name in PART_OF}
    sums = {}
    for v in body.data.vertices:
        acc = {}
        for g in v.groups:
            part = src.get(g.group)
            if part and g.weight > 0:
                acc[part] = acc.get(part, 0.0) + g.weight
        top = sorted(acc.items(), key=lambda kv: -kv[1])[:MAX_INFLUENCES]
        total = sum(w for _, w in top)
        sums[v.index] = [(part, w / total) for part, w in top] if total > 0 else []
    for g in list(vg):
        vg.remove(g)
    groups = {part: vg.new(name=part) for part in PARTS}
    unweighted = 0
    for i, pairs in sums.items():
        if not pairs:
            unweighted += 1
        for part, w in pairs:
            groups[part].add([i], w, "REPLACE")
    log("merged weights; vertices with none:", unweighted)
    return unweighted


def build_skeleton(points, coll, k):
    """The R15 armature, in studs, still MPFB-facing (turned with the body at the end)."""
    arm = bpy.data.armatures.new("LifterBodyRig")
    rig = bpy.data.objects.new("LifterBodyRig", arm)
    coll.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.edit_bones
    hip_h = points["Root"].z * k

    def bone(name, head, parent=None):
        b = eb.new(name)
        b.head = head
        # Every bone points up (+Z): the GLB then has no rotation on any joint (checked 2026-11-12), so in Roblox
        # each joint is a pure offset, like the block rig's C0/C1. Pointing +Y left a -90 degree turn on Root.
        b.tail = head + Vector((0, 0, 0.25))
        if parent:
            b.parent = eb[parent]
        return b

    bone("Root", Vector((0, 0, 0)))
    bone("HumanoidRootNode", Vector((0, points["Root"].y * k, hip_h + 1.0)), "Root")
    bone("LowerTorso", points["Root"] * k, "HumanoidRootNode")
    bone("UpperTorso", points["Waist"] * k, "LowerTorso")
    for side in ("Left", "Right"):
        bone(side + "UpperArm", points[side + "Shoulder"] * k, "UpperTorso")
        bone(side + "LowerArm", points[side + "Elbow"] * k, side + "UpperArm")
        bone(side + "Hand", points[side + "Wrist"] * k, side + "LowerArm")
        bone(side + "UpperLeg", points[side + "Hip"] * k, "LowerTorso")
        bone(side + "LowerLeg", points[side + "Knee"] * k, side + "UpperLeg")
        bone(side + "Foot", points[side + "Ankle"] * k, side + "LowerLeg")
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def decimate(body):
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    ratio = min(1.0, TRIANGLES / max(tris, 1))
    m = body.modifiers.new("Fewer", "DECIMATE")
    m.ratio = ratio
    m.use_symmetry = True
    m.symmetry_axis = "X"
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier=m.name)
    after = sum(len(p.vertices) - 2 for p in body.data.polygons)
    log("triangles", tris, "->", after)


def split_parts(body, rig, coll):
    """One mesh per R15 part: each face goes to the part most of its corners belong to."""
    me = body.data
    # Keep the smooth look across the cuts.
    me.normals_split_custom_set_from_vertices([v.normal for v in me.vertices])
    index = {g.index: g.name for g in body.vertex_groups}
    dominant = []
    for v in me.vertices:
        best = max(v.groups, key=lambda g: g.weight, default=None)
        dominant.append(index[best.group] if best else "UpperTorso")
    me.materials.clear()
    mats = []
    for part in PARTS:
        m = bpy.data.materials.get("Part_" + part) or bpy.data.materials.new("Part_" + part)
        me.materials.append(m)
        mats.append(m)
    for poly in me.polygons:
        votes = {}
        for vi in poly.vertices:
            votes[dominant[vi]] = votes.get(dominant[vi], 0) + 1
        poly.material_index = PARTS.index(max(votes.items(), key=lambda kv: kv[1])[0])
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")
    skin = bpy.data.materials.get("LifterSkin") or bpy.data.materials.new("LifterSkin")
    skin.diffuse_color = (0.80, 0.62, 0.50, 1.0)
    parts = {}
    for o in list(coll.objects):
        if o.type != "MESH" or not o.data.materials:
            continue
        name = o.data.materials[0].name.replace("Part_", "")
        if name not in PARTS:
            continue
        o.name = name
        o.data.name = name
        o.data.materials.clear()
        o.data.materials.append(skin)
        parts[name] = o
    log("parts", len(parts), sorted((n, len(o.data.polygons)) for n, o in parts.items()))
    return parts


def base_body(name="Average", coll=None):
    """Steps 1-5: the full-detail body (studs, rest pose, R15 weights) and its R15 skeleton, not yet decimated or split.
    The clothes (build_clothes_01.py) are shaped over this, so they share the body's exact skeleton."""
    coll = coll or collection()
    body, mrig = make_human(BUILDS[name], coll)
    cut_to_body(body)
    pose_to_rest(body, mrig)
    pts = joint_points(mrig)
    k = NECK_Y / pts["Neck"].z
    world = body.matrix_world.copy()
    body.parent = None
    body.matrix_world = Matrix.Scale(k, 4) @ world
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    merge_weights(body)
    bpy.data.objects.remove(mrig, do_unlink=True)
    rig = build_skeleton(pts, coll, k)
    return body, rig, k


def build(name="Average"):
    # Facing MPFB's way (front -Y, the character's left at +X): Roblox's importer turns a GLB half round (seen
    # 2026-11-12: a body exported facing +Y arrived facing +Z), so this arrives facing -Z with its left at -X.
    coll = collection()
    body, rig, k = base_body(name, coll)
    decimate(body)
    body.name = "LifterBodyMesh"
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    body.parent = rig
    parts = split_parts(body, rig, coll)
    return rig, parts, k


def rbx(v):
    """Blender (+Z up, front -Y) to Roblox (+Y up, front -Z): the GLB export's Y-up, then the importer's half turn."""
    return [round(-v.x, 4), round(v.z, 4), round(v.y, 4)]


def write_joints(rig, parts):
    """The new joint table for the animation scripts: bone positions are the R15 joints."""
    joints = {b.name: rbx(b.head_local) for b in rig.data.bones}
    sizes = {}
    for name, o in parts.items():
        vs = [o.matrix_world @ v.co for v in o.data.vertices]
        lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
        hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
        s = hi - lo
        sizes[name] = {"center": rbx((lo + hi) / 2), "size": [round(s.x, 4), round(s.z, 4), round(s.y, 4)],
                       "triangles": sum(len(p.vertices) - 2 for p in o.data.polygons)}
    top = [parts["UpperTorso"].matrix_world @ v.co for v in parts["UpperTorso"].data.vertices]
    top = [v for v in top if v.z > NECK_Y - 0.1]
    neck_z = sum(v.y for v in top) / max(len(top), 1)
    out = {"note": "LifterBody_01 (Average), Roblox space (+Y up, front -Z, left -X), studs, standing rest pose. Bone "
                   "positions = R15 joint positions (Root bone at the floor; HumanoidRootNode = the HumanoidRootPart's "
                   "centre). Built by art/scripts/build_lifter_body_01.py.",
           "neckY": NECK_Y, "headScale": HEAD_SCALE, "joints": joints, "parts": sizes,
           "neckJoint": [0.0, NECK_Y, round(neck_z, 4)]}
    with open(OUT_JOINTS, "w") as f:
        f.write(json.dumps(out, indent=1))
    log("joints written", OUT_JOINTS)


def export_glb(rig, parts):
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for o in parts.values():
        o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, use_selection=True, export_format="GLB", export_yup=True,
                              export_skins=True, export_animations=False, export_morph=False)
    log("exported", OUT_GLB)


if globals().get("LIFTER_BODY_AS_LIBRARY") is not True:
    RIG, PARTS_BUILT, SCALE = build("Average")
    log("studs per metre", round(SCALE, 4))
    write_joints(RIG, PARTS_BUILT)
    export_glb(RIG, PARTS_BUILT)
    # Then: blender -b art/blender/LifterBody_01.blend --python art/scripts/check_models.py  (must say CHECK PASSED)
