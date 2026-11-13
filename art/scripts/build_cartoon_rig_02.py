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
HAND_TRIANGLES = 1400      # per hand (build_cartoon_hands_03.py makes them at this already)
MAX_INFLUENCES = 4
NECK_Y = 4.0               # the block rig's neck (remapped to the taller bodies below: 4.70)
SKIN = (0.95, 0.76, 0.60, 1)


def load(path, **flags):
    ns = {"CARTOON_AS_LIBRARY": True, "__name__": "cartoon_lib"}
    ns.update(flags)
    exec(open(path).read(), ns)
    return ns


B = load(os.path.join(SCRIPTS, "build_cartoon_body_02.py"))
# The taller bodies (user 2026-11-12, lifter_heights.py): every block-skeleton height below goes through Z().
Z = B["HEIGHTS"]["z"]
NECK_Y = Z(NECK_Y)
HIP_HEIGHT = B["HEIGHTS"]["HIP_HEIGHT"]
# Third-pass hands (2026-11-12): smooth fused shells with clear knuckles, a wrist ball on the joint (no wrist ridge).
H = load(os.path.join(SCRIPTS, "build_cartoon_hands_03.py"))
S = B["S"]
# The forearm is cut here (above the bulge its rounded end made at the wrist: the "wrist ridge") and capped with a
# smooth end; the hand's wrist ball turns inside it. The wrist joint is at 2.275.
FOREARM_CUT_Z = 2.37      # (block height; remapped where it's used)
FOREARM_CAP_DEPTH = 0.06
FOREARM_TAPER = 0.3        # the last stretch of the forearm narrows to TAPER_X / TAPER_Y of its width at the cut
TAPER_X, TAPER_Y = 0.8, 0.88
# The swap hands (celebrations, §38.7) that aren't on the body: one rigid mesh per shape and side.
SWAP_SHAPES = ("Open", "Point", "ThumbsUp", "Fist")
# The body's own hands (user 2026-11-12, after a play test): OPEN by default; they close (the Fist swap) only to grip:
# the bar, the belt, the chalk bowl, a fist pump. HandShapeConfig places the swaps from the open hand.
DEFAULT_HAND = "Open"

# Foot: a rounded foot under each ankle, as the references' plain feet (sneakers go over it, §38.6).
FOOT = S((0.50, -0.10, 0.15), (0.26, 0.42, 0.15))

# build: (shapes, arm line x, arm radius (for the shoulder pivot), hand size)
BUILDS = {
    "Skinny": (B["skinny"](), B["SKINNY_ARMS"], 0.222, 0.95),
    "Heavy": (B["heavy"](), B["HEAVY_ARMS"], 0.36, 1.15),
    "Muscular": (B["muscular"](), 1.5, 0.5, 1.28),
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
    j = {"LowerTorso": Vector((0, 0, Z(2.0))), "UpperTorso": Vector((0, 0, Z(2.4)))}
    for side, sx in (("Left", 1), ("Right", -1)):
        j[side + "UpperArm"] = Vector((sx * pivot, 0, Z(3.763)))
        j[side + "LowerArm"] = Vector((sx * arm_x, 0, Z(3.035)))
        j[side + "Hand"] = Vector((sx * arm_x, 0, Z(2.275)))
        j[side + "UpperLeg"] = Vector((sx * 0.5, 0, Z(2.0)))
        j[side + "LowerLeg"] = Vector((sx * 0.5, 0, Z(1.178)))
        j[side + "Foot"] = Vector((sx * 0.5, 0, Z(0.252)))
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
    hrn.head, hrn.tail = Vector((0, 0, HIP_HEIGHT + 1.0)), Vector((0, 0, HIP_HEIGHT + 1.25))
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


def unfold(body):
    """Smooths away folds the thinning can leave (a face turned over on its neighbour shows as a dark slash: the heavy
    build's upper-back crease, 2026-11-12). Returns how many folded edges it found."""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    folded = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle() > 2.0]
    if folded:
        around = set()
        for e in folded:
            for v in e.verts:
                around.add(v)
                around.update(o for le in v.link_edges for o in le.verts)
        for _ in range(4):
            bmesh.ops.smooth_vert(bm, verts=list(around), factor=0.7, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.to_mesh(body.data)
    bm.free()
    return len(folded)


def group_weight(dvert, index):
    return dvert.get(index, 0.0) if index is not None else 0.0


def cut_forearms(body, rig):
    """Cuts each forearm off just above the bulge of its rounded end (the wrist ridge) and caps it with a smooth end,
    rigid with the forearm (the hand's wrist ball turns inside it). Runs after weighting."""
    groups = {g.name: g.index for g in body.vertex_groups}
    bm = bmesh.new()
    bm.from_mesh(body.data)
    deform = bm.verts.layers.deform.active
    for side in ("Left", "Right"):
        arm, hand = groups.get(side + "LowerArm"), groups.get(side + "Hand")
        def on_arm(v):
            d = v[deform]
            total = sum(d.values()) or 1.0
            return (group_weight(d, arm) + group_weight(d, hand)) / total > 0.5
        faces = [f for f in bm.faces if all(on_arm(v) for v in f.verts)]
        if not faces:
            continue
        edges = list({e for f in faces for e in f.edges})
        verts = list({v for f in faces for v in f.verts})
        bmesh.ops.bisect_plane(bm, geom=faces + edges + verts, plane_co=Vector((0, 0, Z(FOREARM_CUT_Z))),
                               plane_no=Vector((0, 0, 1)), clear_inner=True)
        # Below the cut on this arm only (the bisect keeps arm pieces not joined to the faces it was given).
        loose = [v for v in bm.verts if v.co.z < Z(FOREARM_CUT_Z) - 1e-4 and on_arm(v)]
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
        rim = [e for e in bm.edges if e.is_boundary and abs((e.verts[0].co.z + e.verts[1].co.z) / 2 - Z(FOREARM_CUT_Z)) < 0.01
               and all(on_arm(v) for v in e.verts)]
        if not rim:
            continue
        made = bmesh.ops.holes_fill(bm, edges=rim, sides=0)["faces"]
        poked = bmesh.ops.poke(bm, faces=made)
        centres = poked["verts"]
        for c in centres:
            c.co.z -= FOREARM_CAP_DEPTH
        # The forearm tapers into the wrist over its last stretch (the references: forearm thick at the elbow,
        # narrowing to the wrist), so the end isn't a wide cut tube; then the rim is rounded off.
        rim_verts = {v for c in centres for e in c.link_edges for v in e.verts} - set(centres)
        axis = sum((v.co for v in rim_verts), Vector()) / max(1, len(rim_verts))
        for v in bm.verts:
            if v.co.z < Z(FOREARM_CUT_Z) + FOREARM_TAPER and on_arm(v):
                u = min(1.0, (Z(FOREARM_CUT_Z) + FOREARM_TAPER - v.co.z) / FOREARM_TAPER)
                u = u * u * (3 - 2 * u)
                v.co.x = axis.x + (v.co.x - axis.x) * (1 - (1 - TAPER_X) * u)
                v.co.y = axis.y + (v.co.y - axis.y) * (1 - (1 - TAPER_Y) * u)
        ring = {o for c in centres for e in c.link_edges for o in e.verts}
        near = {o for v in ring for e in v.link_edges for o in e.verts}
        for _ in range(2):
            bmesh.ops.smooth_vert(bm, verts=list(near - set(centres)), factor=0.5, use_axis_x=True, use_axis_y=True,
                                  use_axis_z=True)
        # The end is rigid with the forearm: everything near it follows the LowerArm only.
        for v in bm.verts:
            if v.co.z < Z(FOREARM_CUT_Z) + 0.12 and on_arm(v):
                d = v[deform]
                for k in list(d.keys()):
                    del d[k]
                d[arm] = 1.0
    bm.to_mesh(body.data)
    bm.free()


def hand_space(side, size):
    """Hand space (build_cartoon_hands_03.py) to the hand bone's own space: left turned -90 degrees, right mirrored
    and turned +90 (palm facing the body, thumb forward), scaled to the build, the wrist ball centred on the joint."""
    sx = 1 if side == "Left" else -1
    return Matrix.Translation(Vector((0, 0, 0.06 * size))) @ Matrix.Rotation(math.radians(-90 * sx), 4, "Z") \
        @ Matrix.Diagonal((size * sx, size, size, 1.0))


def add_hands(body, rig, j, arm_x, size, coll):
    """The DEFAULT_HAND (open) on each hand bone: palm facing the body, thumb forward, weighted fully to the hand. The
    body itself keeps no weight on the hand bones, so the hand part is exactly that hand (a swap replaces it whole)."""
    for side in ("Left", "Right"):
        hand_group, arm_group = body.vertex_groups.get(side + "Hand"), body.vertex_groups.get(side + "LowerArm")
        if hand_group and arm_group:
            for v in body.data.vertices:
                w = next((g.weight for g in v.groups if g.group == hand_group.index), 0.0)
                if w > 0:
                    arm_group.add([v.index], w, "ADD")
                    hand_group.remove([v.index])
    hands = []
    for side, sx in (("Left", 1), ("Right", -1)):
        hand = H["make_hand"](DEFAULT_HAND, coll)
        hand.name = body.name + "_" + side + "Hand"
        m = Matrix.Translation(j[side + "Hand"]) @ hand_space(side, size)
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
        o.data.name = name + "_" + part   # unique per build; the GLB gets plain part names on export below
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
        o.data.name = part
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
        o.data.name = name + "_" + part
    upper = parts["UpperTorso"]
    vs = [v.co for v in upper.data.vertices]
    centre = Vector(((min(v.x for v in vs) + max(v.x for v in vs)) / 2, (min(v.y for v in vs) + max(v.y for v in vs)) / 2,
                     (min(v.z for v in vs) + max(v.z for v in vs)) / 2))
    info = {"build": name, "joints": {b.name: rbx(b.head_local) for b in rig.data.bones},
            "neckMark": rbx(Vector((0, 0, NECK_Y)) - centre), "hipHeight": HIP_HEIGHT,
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
    log(name, "folds smoothed:", unfold(body))
    j = joints(arm_x, arm_r)
    rig, order = make_rig(name, j, coll)
    weight(body, rig)
    cut_forearms(body, rig)
    add_hands(body, rig, j, arm_x, hand, coll)
    parts = split_parts(body, rig, order, coll, name)
    point_bones_up(rig)
    info = export(name, rig, parts)
    rig.location.x = spacing_x
    return rig, parts, info


def export_swap_hands(coll, results):
    """The swap hands as rigid meshes, at a build size of 1, in the hand bone's space (Roblox recentres each mesh), in
    one GLB: <Shape>_<Side>. Their centres and sizes (Roblox axes) go into CartoonHands_03.json, with each build's hand
    size, so the game can put a shape exactly where the body's fist is: offset = size * (centre - Fist centre)."""
    made, info = [], {"shapes": {}, "builds": {}}
    for shape in SWAP_SHAPES:
        for side in ("Left", "Right"):
            o = H["make_hand"](shape, coll, name="%s_%s" % (shape, side))
            o.data.name = o.name
            o.data.transform(hand_space(side, 1.0))
            if side == "Right":
                o.data.flip_normals()
            o.data.validate(verbose=False, clean_customdata=False)
            vs = [v.co for v in o.data.vertices]
            lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
            hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
            centre, extent = (lo + hi) / 2, hi - lo
            info["shapes"][o.name] = {"centre": rbx(centre), "size": [round(extent.x, 4), round(extent.z, 4),
                                                                      round(extent.y, 4)],
                                      "triangles": sum(len(p.vertices) - 2 for p in o.data.polygons)}
            made.append(o)
    for name, (_rig, parts, _info) in results.items():
        info["builds"][name] = {"handSize": BUILDS[name][3]}
    bpy.ops.object.select_all(action="DESELECT")
    for o in made:
        o.select_set(True)
    bpy.context.view_layer.objects.active = made[0]
    path = os.path.join(EXPORTS, "CartoonHands_03.glb")
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_yup=True,
                              export_skins=False, export_animations=False, export_morph=False)
    with open(os.path.join(EXPORTS, "CartoonHands_03.json"), "w") as f:
        f.write(json.dumps(info, indent=1))
    for i, o in enumerate(made):
        o.location = (-4.0 - (i // 2) * 0.8, -1.5 + (i % 2) * 0.8, 2.3)
    log("exported", path, len(made), "swap hands")


coll = collection()
RESULTS = {}
for i, name in enumerate(BUILDS):
    RESULTS[name] = build_one(name, i * 4.4, coll)
export_swap_hands(coll, RESULTS)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
log({n: r[2]["triangles"] for n, r in RESULTS.items()})
