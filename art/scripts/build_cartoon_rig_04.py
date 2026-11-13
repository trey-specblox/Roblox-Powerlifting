# The prototype-04 cartoon bodies (CHARACTER_ART_DIRECTION.md §10.1) rigged for checking clothes and gear: each build
# from art/blender/CartoonBodies_04_Proto.blend (the "height in the torso" set, approved 2026-11-13, arms x1.2) on its
# own R15 skeleton (TORSO_TALL joints: hips/HipHeight 2.0, waist 2.54, shoulder 4.38, elbow 3.51, wrist 2.59, knee
# 1.178), Blender's automatic weights, the open hands joined on their hand bones, then split into the 14 R15 parts
# "<Build>_<Part>" + "<Build>Rig" (the layout gear_fit_03.Body and the gear scripts read), a stand-in 1.2-stud head on
# the neck (the player's own head in the game). PROTOTYPE: nothing exported or uploaded.
#   blender -b art/blender/CartoonBodies_04_Proto.blend --python art/scripts/build_cartoon_rig_04.py
# Writes art/blender/CartoonBodies_04_Rigged.blend.
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
OUT = os.path.join(ROOT, "art", "blender", "CartoonBodies_04_Rigged.blend")
BUILDS = ("Skinny", "Heavy", "Muscular")
SPACING = 4.6
PARTS = ["LowerTorso", "UpperTorso"] + [s + p for s in ("Left", "Right") for p in
                                         ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")]

# build_cartoon_rig_02.py's helpers (bones, automatic weights) without running its build; that file is unchanged
src = open(os.path.join(SCRIPTS, "build_cartoon_rig_02.py")).read().split("\ncoll = collection()\nRESULTS")[0]
R = {"__name__": "rig02_lib"}
exec(src, R)
P = {"__name__": "lib", "PROTO04_AS_LIBRARY": True}
exec(open(os.path.join(SCRIPTS, "build_cartoon_body_04.py")).read(), P)
L = P["TORSO_TALL"]
R["HIP_HEIGHT"] = L["HJ"]          # the root node stands at HipHeight + 1


def joints(arm_x, pivot):
    j = {"LowerTorso": Vector((0, 0, L["HJ"])), "UpperTorso": Vector((0, 0, L["W"]))}
    for side, sx in (("Left", 1), ("Right", -1)):
        j[side + "UpperArm"] = Vector((sx * pivot, 0, L["SH"]))
        j[side + "LowerArm"] = Vector((sx * arm_x, 0, L["E"]))
        j[side + "Hand"] = Vector((sx * arm_x, 0, L["WR"]))
        j[side + "UpperLeg"] = Vector((sx * 0.5, 0, L["HJ"]))
        j[side + "LowerLeg"] = Vector((sx * 0.5, 0, L["K"]))
        j[side + "Foot"] = Vector((sx * 0.5, 0, L["A"]))
    return j


def shoulder_weights(body, pivot):
    """Automatic weights let the upper-arm bones pull the traps and upper chest (skin INSIDE the shoulder joint), so a
    raised arm stretched the shoulder into a sheet and pushed it out through the singlet's straps. Inside the shoulder
    joint the torso now holds that skin: the arm's share fades from nothing 0.30 in from the joint to all of it at the
    joint (round the shoulder only)."""
    groups = {g.name: g.index for g in body.vertex_groups}
    ut = groups["UpperTorso"]
    for v in body.data.vertices:
        if v.co.z < L["SH"] - 0.8:
            continue
        s = abs(v.co.x)
        t = min(1.0, max(0.0, (s - (pivot - 0.30)) / 0.28))
        keep = t * t * (3 - 2 * t)
        moved = 0.0
        for g in v.groups:
            name = body.vertex_groups[g.group].name
            if name in ("LeftUpperArm", "RightUpperArm") and g.weight > 0:
                moved += g.weight * (1 - keep)
                g.weight *= keep
        if moved > 0:
            body.vertex_groups[ut].add([v.index], moved + next((g.weight for g in v.groups if g.group == ut), 0.0),
                                       "REPLACE")


def main_part(v, deform, names):
    best, w = "UpperTorso", 0.0
    for gi, gw in v[deform].items():
        if gw > w and names.get(gi) in PARTS:
            best, w = names[gi], gw
    return best


coll = bpy.data.collections.new("CartoonRig")
bpy.context.scene.collection.children.link(coll)
skin_mat = bpy.data.materials.get("CartoonSkin") or bpy.data.materials.new("CartoonSkin")
for i, build in enumerate(BUILDS):
    spec = P["BUILDS"][build](L)
    body = bpy.data.objects["ProtoTorsoTall_" + build].copy()
    body.data = body.data.copy()
    body.location = (0, 0, 0)
    body.name = build + "_Skin"
    coll.objects.link(body)
    rig, order = R["make_rig"](build, joints(spec["arm_x"], spec["pivot_x"]), coll)
    R["weight"](body, rig)
    shoulder_weights(body, spec["pivot_x"])
    for side in ("Left", "Right"):
        hand = bpy.data.objects["ProtoTorsoTall_%s_%sHand" % (build, side)].copy()
        hand.data = hand.data.copy()
        hand.location = (0, 0, 0)
        coll.objects.link(hand)
        hand.vertex_groups.new(name=side + "Hand").add(list(range(len(hand.data.vertices))), 1.0, "REPLACE")
        bpy.ops.object.select_all(action="DESELECT")
        hand.select_set(True)
        body.select_set(True)
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.join()
    # one piece per body part, by each face's main bone
    me = body.data
    me.materials.clear()
    for part in PARTS:
        me.materials.append(bpy.data.materials.get("Split_" + part) or bpy.data.materials.new("Split_" + part))
    names = {g.index: g.name for g in body.vertex_groups}
    bm = bmesh.new()
    bm.from_mesh(me)
    deform = bm.verts.layers.deform.active
    for f in bm.faces:
        votes = {}
        for v in f.verts:
            p = main_part(v, deform, names)
            votes[p] = votes.get(p, 0) + 1
        f.material_index = PARTS.index(max(votes.items(), key=lambda kv: kv[1])[0])
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in [x for x in coll.objects if x.name == body.name or x.name.startswith(body.name + ".")]:
        if not o.data.polygons:
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        part = o.data.materials[o.data.polygons[0].material_index].name.replace("Split_", "")
        o.data.materials.clear()
        o.data.materials.append(skin_mat)
        o.name = build + "_" + part
        o.data.name = o.name
    head = P["stand_in_head"](build + "_StandInHead", L, 0.0, coll)
    bpy.context.view_layer.update()
    mw = head.matrix_world.copy()
    head.parent = rig
    head.parent_type = "BONE"
    head.parent_bone = "UpperTorso"
    bpy.context.view_layer.update()
    head.matrix_world = mw
    rig.location.x = i * SPACING
    print("[Rig04]", build, len([o for o in coll.objects if o.name.startswith(build + "_")]), "objects")

# only the rigged set stays in this file
for o in list(bpy.data.objects):
    if coll not in o.users_collection:
        bpy.data.objects.remove(o, do_unlink=True)
for c in list(bpy.data.collections):
    if c is not coll:
        bpy.data.collections.remove(c)
bpy.data.orphans_purge(do_recursive=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("[Rig04] saved", OUT)
