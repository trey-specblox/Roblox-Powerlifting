# The basic clothes (GAME_DESIGN.md §38.6, user 2026-11-12: "make a bunch of plain basic cloths, shorts, shoes,
# shirts"). Plain pieces, coloured in the game (one mesh serves every colour).
#
# Every piece is shaped over the lifter body (build_lifter_body_01.py's base_body: same skeleton, same weights), pushed
# out along the skin, given a thin hem and split into one mesh per R15 body part, named "<Item>__<Part>". In Roblox each
# piece is skinned like the body, so it bends with it exactly (tested 2026-11-12: a shell over the torso and arm followed
# a raised arm and bent elbow). Layers keep out of each other by distance from the skin: bottoms, then shirts over
# their waistband, then (later) the gear over both.
#
# Run inside Blender with MPFB enabled (it builds its own body, in an empty file):
#   exec(open(r"D:\Powerlifting Roblox\art\scripts\build_clothes_01.py").read())
# Writes art/blender/Clothes_01.blend and art/exports/Clothes_01.glb. Then check_models.py must say CHECK PASSED.
import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = r"D:\Powerlifting Roblox"
BODY_SCRIPT = os.path.join(ROOT, "art", "scripts", "build_lifter_body_01.py")
OUT_BLEND = os.path.join(ROOT, "art", "blender", "Clothes_01.blend")
OUT_GLB = os.path.join(ROOT, "art", "exports", "Clothes_01.glb")

HEM = 0.02            # studs: a garment's edge thickness (turned inward)

# Heights on the body, studs (LifterBody_01's joints): see art/exports/LifterBody_01_joints.json.
NECK_TOP = 4.35
SHOULDER_Z = 3.797
ELBOW_Z = 3.105
WRIST_Z = 2.372
HIP_Z = 2.529
KNEE_Z = 1.379
ANKLE_Z = 0.18


def part_of(weights):
    return max(weights.items(), key=lambda kv: kv[1])[0] if weights else "UpperTorso"


def is_arm(p):
    return "Arm" in p or "Hand" in p


def is_leg(p):
    return "Leg" in p or "Foot" in p


# Each item covers the skin of some body parts (coarse), trimmed by flat cuts for clean hems. A cut is
# (point, normal, where): everything on the normal's side goes, among the vertices of `where` ("all", "arms", "legs",
# "torso"). Rest pose, studs; front is -Y, the character's left is +X.
UP, DOWN = Vector((0, 0, 1)), Vector((0, 0, -1))
WAIST_TOP = 2.84      # bottoms' waistband
SHIRT_HEM = 2.60      # shirts come down over the waistband
COLLAR = ((Vector((0, 0, 4.095)), Vector((0, -0.12, 1)).normalized(), "torso"),)   # crew neck, lower in front


def shirt_parts(p):
    return not is_leg(p) and "Hand" not in p


TEE_CUTS = ((Vector((0, 0, SHIRT_HEM)), DOWN, "all"), (Vector((0, 0, SHOULDER_Z - 0.38)), DOWN, "arms")) + COLLAR
LONG_CUTS = ((Vector((0, 0, SHIRT_HEM)), DOWN, "all"), (Vector((0, 0, WRIST_Z + 0.08)), DOWN, "arms")) + COLLAR
TANK_CUTS = ((Vector((0, 0, SHIRT_HEM)), DOWN, "all"),
             (Vector((0.30, 0, 3.40)), Vector((1, 0, 0.25)).normalized(), "torso"),     # arm holes, leaving straps
             (Vector((-0.30, 0, 3.40)), Vector((-1, 0, 0.25)).normalized(), "torso"),
             (Vector((0, -0.2, 3.98)), Vector((0, -0.55, 1)).normalized(), "torso")) + COLLAR   # scooped neck
SHORTS_CUTS = ((Vector((0, 0, WAIST_TOP)), UP, "all"), (Vector((0, 0, 1.80)), DOWN, "legs"))
JOGGERS_CUTS = ((Vector((0, 0, WAIST_TOP)), UP, "all"), (Vector((0, 0, ANKLE_Z + 0.17)), DOWN, "legs"))

ITEMS = {
    # name: (kind, offset from the skin, extra loose on the limbs, triangles, parts covered, cuts)
    "Tee": ("Shirt", 0.050, 0.025, 2200, lambda p: shirt_parts(p) and "LowerArm" not in p, TEE_CUTS),
    "LongSleeve": ("Shirt", 0.050, 0.020, 2600, shirt_parts, LONG_CUTS),
    "Tank": ("Shirt", 0.050, 0.0, 1600, lambda p: not is_leg(p) and not is_arm(p), TANK_CUTS),
    "Shorts": ("Bottom", 0.032, 0.05, 1600, lambda p: "Torso" in p or "UpperLeg" in p, SHORTS_CUTS),
    "Joggers": ("Bottom", 0.032, 0.03, 2200, lambda p: ("Torso" in p or "Leg" in p), JOGGERS_CUTS),
}

# Sneakers are shaped, not copied from the foot (a copied foot keeps its toes): a loft along the foot from heel to toe,
# with a white sole under it. Foot measurements from LifterBody_01 (the foot part spans y -0.495 .. 0.215).
SHOE = {"x": 0.299, "heel_y": 0.255, "toe_y": -0.545, "sections": 22, "around": 20}


def log(*a):
    print("[Clothes]", *a)


def load_body_library():
    ns = {"LIFTER_BODY_AS_LIBRARY": True, "__name__": "lifter_body"}
    exec(open(BODY_SCRIPT).read(), ns)
    return ns


def collection(name):
    coll = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if coll.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(coll)
    return coll


def weights_of(obj):
    names = {g.index: g.name for g in obj.vertex_groups}
    return [{names[g.group]: g.weight for g in v.groups if g.weight > 0} for v in obj.data.vertices]


def vert_part(v, deform, names):
    return max(((names[i], w) for i, w in v[deform].items()), key=lambda kv: kv[1], default=("UpperTorso", 0))[0]


def in_region(part, where):
    if where == "all":
        return True
    if where == "arms":
        return is_arm(part)
    if where == "legs":
        return is_leg(part)
    return not is_arm(part) and not is_leg(part)      # "torso"


def make_item(name, spec, body, rig, coll):
    kind, offset, loose, budget, covers, cuts = spec
    me = body.data.copy()
    obj = bpy.data.objects.new(name, me)
    coll.objects.link(obj)
    for g in body.vertex_groups:        # the weights are stored on the mesh; the object needs the group names
        obj.vertex_groups.new(name=g.name)
    names = {g.index: g.name for g in obj.vertex_groups}
    bm = bmesh.new()
    bm.from_mesh(me)
    deform = bm.verts.layers.deform.verify()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not covers(vert_part(v, deform, names))], context="VERTS")
    # Clean hems: flat cuts, each through its own region only.
    for point, normal, where in cuts:
        inside = {v for v in bm.verts if in_region(vert_part(v, deform, names), where)}
        faces = [f for f in bm.faces if all(v in inside for v in f.verts)]
        edges = list({e for f in faces for e in f.edges})
        geom = list(inside) + edges + faces
        if faces:
            bmesh.ops.bisect_plane(bm, geom=geom, plane_co=point, plane_no=normal, clear_outer=True)
    # Strays left by a cut go (pieces of fewer than 12 faces).
    seen = set()
    for f in list(bm.faces):
        if f in seen or not f.is_valid:
            continue
        island, todo = [], [f]
        seen.add(f)
        while todo:
            g = todo.pop()
            island.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen:
                        seen.add(h)
                        todo.append(h)
        if len(island) < 12:
            bmesh.ops.delete(bm, geom=island, context="FACES")
    bm.normal_update()
    bmesh.ops.smooth_vert(bm, verts=bm.verts, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.normal_update()
    for v in bm.verts:
        push = offset
        if loose and (is_arm(vert_part(v, deform, names)) or is_leg(vert_part(v, deform, names))):
            push += loose
        v.co += v.normal * push
    bm.to_mesh(me)
    bm.free()
    me.update()
    # A thin hem, turned inward.
    sol = obj.modifiers.new("Hem", "SOLIDIFY")
    sol.thickness = HEM
    sol.offset = -1.0
    sol.use_rim = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=sol.name)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    if tris > budget:
        dec = obj.modifiers.new("Fewer", "DECIMATE")
        dec.ratio = budget / tris
        dec.use_symmetry = True
        dec.symmetry_axis = "X"
        bpy.ops.object.modifier_apply(modifier=dec.name)
    obj["kind"] = kind
    log(name, kind, "triangles", sum(len(p.vertices) - 2 for p in me.polygons))
    return obj


def loft(sections, around, ring):
    """A closed tube through `sections` rings (ring(i, j) -> Vector), capped at both ends. Returns a bmesh."""
    bm = bmesh.new()
    rings = [[bm.verts.new(ring(i, j)) for j in range(around)] for i in range(sections)]
    for i in range(sections - 1):
        for j in range(around):
            a, b = rings[i][j], rings[i][(j + 1) % around]
            c, d = rings[i + 1][(j + 1) % around], rings[i + 1][j]
            bm.faces.new((a, b, c, d))
    for r, flip in ((rings[0], True), (rings[-1], False)):
        centre = bm.verts.new(sum((v.co for v in r), Vector()) / len(r))
        for j in range(around):
            a, b = r[j], r[(j + 1) % around]
            bm.faces.new((centre, b, a) if flip else (centre, a, b))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def make_shoes(rig, coll):
    """Sneakers: a shaped upper and a white sole per foot, all on the foot's bone."""
    s = SHOE
    n, m = s["sections"], s["around"]
    made = []
    for side, sx in (("Left", 1), ("Right", -1)):
        cx = sx * s["x"]

        def profile(t):
            # t 0 = heel, 1 = toe tip: half width, top height
            width = 0.135 + 0.03 * math.sin(math.pi * min(t / 0.7, 1.0)) - (0.12 * ((t - 0.8) / 0.2) ** 2 if t > 0.8 else 0)
            top = 0.40 - 0.18 * t ** 1.3 if t < 0.85 else 0.20 - 0.6 * (t - 0.85)
            return max(width, 0.03), max(top, 0.09)

        def section_y(t):
            return s["heel_y"] + (s["toe_y"] - s["heel_y"]) * t

        def upper(i, j):
            t = 0.02 + 0.96 * i / (n - 1)
            w, top = profile(t)
            a = 2 * math.pi * j / m
            c, sn = math.cos(a), math.sin(a)
            x = cx + w * math.copysign(abs(c) ** 0.7, c)
            zc, hz = (top + 0.04) / 2, (top - 0.04) / 2
            z = zc + hz * math.copysign(abs(sn) ** 0.7, sn)
            return Vector((x, section_y(t), z))

        def sole(i, j):
            t = 0.01 * (1 - i / (n - 1)) + 0.99 * i / (n - 1)
            w, _ = profile(t)
            w += 0.022
            a = 2 * math.pi * j / m
            c, sn = math.cos(a), math.sin(a)
            x = cx + w * math.copysign(abs(c) ** 0.4, c)
            z = 0.015 + 0.045 * math.copysign(abs(sn) ** 0.4, sn)
            y = section_y(t) + (0.02 if i == 0 else (-0.02 if i == n - 1 else 0))
            return Vector((x, y, z))

        for name, ring in (("Sneakers", upper), ("SneakersSole", sole)):
            bm = loft(n, m, ring)
            me = bpy.data.meshes.new(name + "__" + side + "Foot")
            bm.to_mesh(me)
            bm.free()
            obj = bpy.data.objects.new(me.name, me)
            coll.objects.link(obj)
            group = obj.vertex_groups.new(name=side + "Foot")
            group.add(list(range(len(me.vertices))), 1.0, "REPLACE")
            for p in me.polygons:
                p.use_smooth = True
            mat_name = "SoleWhite" if name.endswith("Sole") else "ClothGrey"
            mat = bpy.data.materials.get(mat_name) or bpy.data.materials.new(mat_name)
            me.materials.append(mat)
            mod = obj.modifiers.new("Armature", "ARMATURE")
            mod.object = rig
            obj.parent = rig
            obj["kind"] = "Shoes"
            made.append(obj)
    log("sneakers", [(o.name, len(o.data.polygons)) for o in made])
    return made


def split_item(obj, rig, coll, lib):
    """One mesh per R15 part, "<Item>__<Part>"; shoes also split off their sole as "<Item>Sole__<Part>"."""
    me = obj.data
    me.normals_split_custom_set_from_vertices([v.normal for v in me.vertices])
    names = {g.index: g.name for g in obj.vertex_groups}
    dominant = []
    for v in me.vertices:
        best = max(v.groups, key=lambda g: g.weight, default=None)
        dominant.append(names[best.group] if best else "UpperTorso")
    parts = lib["PARTS"]
    is_shoe = obj.get("kind") == "Shoes"
    me.materials.clear()
    keys = []
    for part in parts:
        for sole in ((False, True) if is_shoe else (False,)):
            keys.append((part, sole))
            mat = bpy.data.materials.get("Split_%s_%s" % (part, sole)) or bpy.data.materials.new("Split_%s_%s" % (part, sole))
            me.materials.append(mat)
    for poly in me.polygons:
        votes = {}
        for vi in poly.vertices:
            votes[dominant[vi]] = votes.get(dominant[vi], 0) + 1
        part = max(votes.items(), key=lambda kv: kv[1])[0]
        sole = is_shoe and max(me.vertices[vi].co.z for vi in poly.vertices) < 0.07
        poly.material_index = keys.index((part, sole))
    base = obj.name
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")
    cloth = bpy.data.materials.get("ClothGrey") or bpy.data.materials.new("ClothGrey")
    cloth.diffuse_color = (0.55, 0.57, 0.62, 1.0)
    sole_mat = bpy.data.materials.get("SoleWhite") or bpy.data.materials.new("SoleWhite")
    sole_mat.diffuse_color = (0.92, 0.92, 0.9, 1.0)
    made = []
    for o in [x for x in coll.objects if x.type == "MESH" and (x.name == base or x.name.startswith(base + "."))]:
        if not o.data.polygons:
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        tag = o.data.materials[0].name.replace("Split_", "")
        part, sole = tag.rsplit("_", 1)
        sole = sole == "True"
        o.name = "%s%s__%s" % (base, "Sole" if sole else "", part)
        o.data.name = o.name
        o.data.materials.clear()
        o.data.materials.append(sole_mat if sole else cloth)
        mod = o.modifiers.new("Armature", "ARMATURE")
        mod.object = rig
        o.parent = rig
        made.append(o)
    return made


def build():
    # Start from an empty scene (read_homefile would lose the window context MPFB needs).
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    bpy.data.orphans_purge(do_recursive=True)
    lib = load_body_library()
    base_coll = collection("LifterBody")
    body, rig, k = lib["base_body"]("Average", base_coll)
    rig.name = "ClothesRig"
    clothes = collection("Clothes")
    pieces = []
    for name, spec in ITEMS.items():
        item = make_item(name, spec, body, rig, clothes)
        pieces += split_item(item, rig, clothes, lib)
    pieces += make_shoes(rig, clothes)
    # The body itself, for previews only (check_models.py skips the "Preview" collection).
    preview = collection("Preview")
    lib["decimate"](body)
    body.name = "PreviewBody"
    for c in list(body.users_collection):
        c.objects.unlink(body)
    preview.objects.link(body)
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    body.parent = rig
    skin = bpy.data.materials.get("LifterSkin") or bpy.data.materials.new("LifterSkin")
    skin.diffuse_color = (0.78, 0.6, 0.48, 1.0)
    body.data.materials.clear()
    body.data.materials.append(skin)
    log("pieces", len(pieces), sorted(o.name for o in pieces))
    return rig, pieces, body


def export(rig, pieces):
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for o in pieces:
        o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, use_selection=True, export_format="GLB", export_yup=True,
                              export_skins=True, export_animations=False, export_morph=False)
    log("exported", OUT_GLB)


RIG, PIECES, PREVIEW_BODY = build()
export(RIG, PIECES)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
