# The cartoon lifter bodies, made game-ready (GAME_DESIGN.md §38.7, user 2026-11-12: "Yes, start").
#
# For each build (Skinny, Heavy, Muscular) from build_cartoon_body_02.py:
#   1. the fused body with feet, fewer triangles (performance), skin only (clothes are separate pieces, §38.6)
#   2. an R15 skeleton on the game's ORIGINAL block-rig heights (station_animations.py JOINTS): hips 2.0, waist 2.4,
#      neck 4.0, knees 1.178, ankles 0.252. The arms are each build's own: the elbow and wrist down the middle of the
#      arm (x = the build's arm line), the shoulder pivot at the arm's inner top, as the block arm's is. The bar
#      follows the hands (StationPoseAnimator.followHands), so a skinny lifter's narrower grip still holds it.
#   3. smooth weights (Blender's automatic weights), at most 4 per vertex
#   4. the Fist hands (build_cartoon_hands_02.py) on the hand bones, palms facing in, thumbs forward
#   5. split into the 14 R15 parts (the head is the player's own), every bone pointing +Z (no joint rotations in the
#      GLB), exported facing Blender -Y: Roblox's importer turns a GLB half round, so it lands facing -Z.
# Writes art/blender/CartoonBodies_02.blend and art/exports/CartoonBody_<Build>.glb (+ _joints.json).
# Run inside Blender:  exec(open(r"D:\Powerlifting Roblox\art\scripts\build_cartoon_rig_02.py").read())
import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
OUT_BLEND = os.path.join(ROOT, "art", "blender", "CartoonBodies_02.blend")
EXPORTS = os.path.join(ROOT, "art", "exports")
COLLECTION = "CartoonRig"

BODY_TRIANGLES = 5200      # per body before the hands (the preview bodies were 12,000)
HAND_TRIANGLES = 900       # per hand
MAX_INFLUENCES = 4
NECK_Y = 4.0               # the block rig's neck: the player's full-size head sits here
SKIN = (0.95, 0.76, 0.60, 1)


def load(path, **flags):
    ns = {"CARTOON_AS_LIBRARY": True, "__name__": "cartoon_lib"}
    ns.update(flags)
    exec(open(path).read(), ns)
    return ns


B = load(os.path.join(SCRIPTS, "build_cartoon_body_02.py"))
H = load(os.path.join(SCRIPTS, "build_cartoon_hands_02.py"))
S = B["S"]

# Foot: a rounded foot under each ankle, as the references' plain feet (sneakers go over it, §38.6).
FOOT = S((0.50, -0.10, 0.15), (0.26, 0.42, 0.15))

# build: (shapes, arm line x, arm radius (for the shoulder pivot), hand size)
BUILDS = {
    "Skinny": (B["skinny"](), B["SKINNY_ARMS"], 0.222, 0.88),
    "Heavy": (B["heavy"](), B["HEAVY_ARMS"], 0.36, 1.05),
    "Muscular": (B["muscular"](), 1.5, 0.5, 1.18),
}


def log(*a):
    print("[CartoonRig]", *a)


def collection():
    coll = bpy.data.collections.get(COLLECTION) or bpy.data.collections.new(COLLECTION)
    if coll.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(coll)
    for o in list(coll.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.orphans_purge(do_recursive=True)
    return coll


def joints(arm_x, arm_r):
    """R15 joint positions, Blender space (front -Y, the character's left at +X), studs."""
    pivot = arm_x - arm_r
    j = {"LowerTorso": Vector((0, 0, 2.0)), "UpperTorso": Vector((0, 0, 2.4))}
    for side, sx in (("Left", 1), ("Right", -1)):
        j[side + "UpperArm"] = Vector((sx * pivot, 0, 3.763))
        j[side + "LowerArm"] = Vector((sx * arm_x, 0, 3.035))
        j[side + "Hand"] = Vector((sx * arm_x, 0, 2.275))
        j[side + "UpperLeg"] = Vector((sx * 0.5, 0, 2.0))
        j[side + "LowerLeg"] = Vector((sx * 0.5, 0, 1.178))
        j[side + "Foot"] = Vector((sx * 0.5, 0, 0.252))
    return j


# Where each bone points while weighting (its next joint); for export they all point +Z.
def tail_of(name, j):
    side = "Left" if name.startswith("Left") else "Right"
    nxt = {"LowerTorso": "UpperTorso", "UpperArm": "LowerArm", "LowerArm": "Hand", "UpperLeg": "LowerLeg",
           "LowerLeg": "Foot"}
    if name == "UpperTorso":
        return Vector((0, 0, NECK_Y))
    if name == "LowerTorso":
        return j["UpperTorso"]
    base = name.replace(side, "")
    if base in nxt:
        return j[side + nxt[base]]
    if base == "Hand":
        return j[name] + Vector((0, 0, -0.45))
    if base == "Foot":
        return j[name] + Vector((0, -0.45, -0.15))
    raise KeyError(name)


def parent_of(name):
    side = "Left" if name.startswith("Left") else ("Right" if name.startswith("Right") else "")
    base = name.replace(side, "") if side else name
    return {"LowerTorso": "HumanoidRootNode", "UpperTorso": "LowerTorso", "UpperArm": "UpperTorso",
            "LowerArm": side + "UpperArm", "Hand": side + "LowerArm", "UpperLeg": "LowerTorso",
            "LowerLeg": side + "UpperLeg", "Foot": side + "LowerLeg"}[base]


def make_rig(name, j, coll):
    arm = bpy.data.armatures.new(name + "Rig")
    rig = bpy.data.objects.new(name + "Rig", arm)
    coll.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.edit_bones
    root = eb.new("Root")
    root.head, root.tail = Vector((0, 0, 0)), Vector((0, 0, 0.25))
    root.use_deform = False
    hrn = eb.new("HumanoidRootNode")
    hrn.head, hrn.tail = Vector((0, 0, 3.0)), Vector((0, 0, 3.25))
    hrn.parent = root
    hrn.use_deform = False
    order = ["LowerTorso", "UpperTorso"] + [s + p for s in ("Left", "Right") for p in
                                             ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")]
    for bone in order:
        b = eb.new(bone)
        b.head, b.tail = j[bone], tail_of(bone, j)
    for bone in order:
        eb[bone].parent = eb[parent_of(bone)]
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig, order


def weight(body, rig):
    """Automatic weights, then at most MAX_INFLUENCES per vertex; any vertex left without one goes to its nearest bone."""
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_limit_total(limit=MAX_INFLUENCES)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bones = [b for b in rig.data.bones if b.use_deform]
    missing = 0
    for v in body.data.vertices:
        if not any(g.weight > 0 for g in v.groups):
            missing += 1
            best = min(bones, key=lambda b: (v.co - (b.head_local + b.tail_local) / 2).length)
            body.vertex_groups[best.name].add([v.index], 1.0, "REPLACE")
    log(body.name, "unweighted vertices fixed:", missing)


def add_hands(body, rig, j, arm_x, size, coll):
    """The Fist on each hand bone: palm facing the body, thumb forward, weighted fully to the hand."""
    hands = []
    for side, sx in (("Left", 1), ("Right", -1)):
        hand = H["make_hand"]("Fist", coll)
        hand.name = body.name + "_" + side + "Hand"
        dec = hand.modifiers.new("Fewer", "DECIMATE")
        dec.ratio = min(1.0, HAND_TRIANGLES / max(1, sum(len(p.vertices) - 2 for p in hand.data.polygons)))
        bpy.context.view_layer.objects.active = hand
        bpy.ops.object.select_all(action="DESELECT")
        hand.select_set(True)
        bpy.ops.object.modifier_apply(modifier=dec.name)
        # Left: turn -90 degrees; right: mirror, then turn +90 (hand space: palm -Y, thumb +X).
        m = Matrix.Translation(j[side + "Hand"] + Vector((0, 0, 0.06))) @ Matrix.Rotation(math.radians(-90 * sx), 4, "Z") \
            @ Matrix.Diagonal((size * sx, size, size, 1.0))
        hand.data.transform(m)
        if sx < 0:
            hand.data.flip_normals()
        hand.matrix_world = Matrix.Identity(4)
        for g in list(hand.vertex_groups):
            hand.vertex_groups.remove(g)
        grp = hand.vertex_groups.new(name=side + "Hand")
        grp.add(list(range(len(hand.data.vertices))), 1.0, "REPLACE")
        hand.data.materials.clear()
        hands.append(hand)
    # Into the body (vertex groups merge by name).
    bpy.ops.object.select_all(action="DESELECT")
    for h in hands:
        h.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()


def split_parts(body, rig, parts, coll, name):
    me = body.data
    me.normals_split_custom_set_from_vertices([v.normal for v in me.vertices])
    index = {g.index: g.name for g in body.vertex_groups}
    dominant = []
    for v in me.vertices:
        best = max((g for g in v.groups if index.get(g.group) in parts), key=lambda g: g.weight, default=None)
        dominant.append(index[best.group] if best else "UpperTorso")
    me.materials.clear()
    for part in parts:
        me.materials.append(bpy.data.materials.get("Split_" + part) or bpy.data.materials.new("Split_" + part))
    for poly in me.polygons:
        votes = {}
        for vi in poly.vertices:
            votes[dominant[vi]] = votes.get(dominant[vi], 0) + 1
        poly.material_index = parts.index(max(votes.items(), key=lambda kv: kv[1])[0])
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")
    skin = bpy.data.materials.get("CartoonSkin") or bpy.data.materials.new("CartoonSkin")
    skin.diffuse_color = SKIN
    out = {}
    for o in [x for x in coll.objects if x.type == "MESH" and x.parent == rig]:
        if not o.data.polygons:
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        # (separating keeps every material slot, so the part is the slot its faces use)
        part = o.data.materials[o.data.polygons[0].material_index].name.replace("Split_", "")
        for p in o.data.polygons:
            p.material_index = 0
        # Cutting triangles can leave a zero-area face or a stray edge; the GLB exporter warns about those.
        o.data.validate(verbose=False, clean_customdata=False)
        o.name = name + "_" + part
        o.data.name = part        # the GLB node keeps the mesh object's name; renamed to the part on export below
        o.data.materials.clear()
        o.data.materials.append(skin)
        out[part] = o
    return out


def point_bones_up(rig):
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for b in rig.data.edit_bones:
        b.tail = b.head + Vector((0, 0, 0.25))
        b.roll = 0
    bpy.ops.object.mode_set(mode="OBJECT")


def rbx(v):
    """Blender (front -Y) to Roblox (front -Z, after the importer's half turn)."""
    return [round(-v.x, 4), round(v.z, 4), round(v.y, 4)]


def export(name, rig, parts):
    # Name each mesh object exactly as its R15 part for the GLB, then put the line-up names back.
    for part, o in parts.items():
        o.name = part
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for o in parts.values():
        o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    path = os.path.join(EXPORTS, "CartoonBody_%s.glb" % name)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_yup=True,
                              export_skins=True, export_animations=False, export_morph=False)
    for part, o in parts.items():
        o.name = name + "_" + part
    upper = parts["UpperTorso"]
    vs = [v.co for v in upper.data.vertices]
    centre = Vector(((min(v.x for v in vs) + max(v.x for v in vs)) / 2, (min(v.y for v in vs) + max(v.y for v in vs)) / 2,
                     (min(v.z for v in vs) + max(v.z for v in vs)) / 2))
    info = {"build": name, "joints": {b.name: rbx(b.head_local) for b in rig.data.bones},
            "neckMark": rbx(Vector((0, 0, NECK_Y)) - centre), "hipHeight": 2.0,
            "triangles": sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in parts.values())}
    with open(os.path.join(EXPORTS, "CartoonBody_%s_joints.json" % name), "w") as f:
        f.write(json.dumps(info, indent=1))
    log("exported", path, info["triangles"], "triangles")
    return info


def build_one(name, spacing_x, coll):
    shapes, arm_x, arm_r, hand = BUILDS[name]
    B["TRIANGLES"] = BODY_TRIANGLES
    body = B["build_body"]("Cartoon" + name, list(shapes) + [FOOT], 0.0, coll)
    for c in list(body.users_collection):
        c.objects.unlink(body)
    coll.objects.link(body)
    j = joints(arm_x, arm_r)
    rig, order = make_rig(name, j, coll)
    weight(body, rig)
    add_hands(body, rig, j, arm_x, hand, coll)
    parts = split_parts(body, rig, order, coll, name)
    point_bones_up(rig)
    info = export(name, rig, parts)
    rig.location.x = spacing_x
    return rig, parts, info


coll = collection()
RESULTS = {}
for i, name in enumerate(BUILDS):
    RESULTS[name] = build_one(name, i * 4.4, coll)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
log({n: r[2]["triangles"] for n, r in RESULTS.items()})
