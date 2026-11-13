# The worn lifting gear refitted to the cartoon bodies (GAME_DESIGN.md §38.6-38.7; user 2026-11-12 after a play test:
# "The singlet, shirt, belt, sleeves and wraps have to fit the body the lifter actually has"). Replaces, for the cartoon
# bodies, build_worn_gear_01.py's rigid block-body pieces (which floated off the new bodies like an apron and a skirt).
#
# The rules that stand (memory "worn-gear-style", "gear-brand-central"): CENTRAL on every logo, a CHUNKY belt (a thick
# band with rounded bulging edges and a big steel lever), knee sleeves ONE seamless tube from mid-thigh to mid-shin
# (it bends with the knee here, as one skinned piece), wraps covering the whole wrist, the shirt showing through the
# singlet's open sides, neckline and arm holes (the singlet sits further out than the shirt).
#
# Built like the clothes (build_cartoon_clothes_02.py, loaded as a library for its tools): per build, from the build's
# own skin, cut, pushed out by its layer, edges rolled, split per body part and skinned to the same skeleton. Each
# COLOUR KEY of an item (ShopConfig colours: Black / Red / Trim / Patch / Shorts / ShortsRed for the singlet, Body /
# Panel / Shoulder / Trim / Label / Patch for suits and the bench shirt, Outer / Lining / Stitch / Lever / Text for the
# belt, Body / Stripes / Patch for knee sleeves, Body / Stripes / Accent for knee wraps, Body / Tail / Stripes / Text for
# wrist wraps) is its own piece, "<Worn>_<Key>__<Part>", so the game colours each one (WornGearFit.dressCartoon).
#
# Layers, distance from the skin: shirt 0.04 (clothes) < bench shirt 0.055 < singlet / suit 0.07 < belt 0.17.
# Writes art/blender/CartoonGear_02.blend and art/exports/CartoonGear_<Build>.glb. Run inside Blender with
# CartoonBodies_02.blend open:
#   exec(open(r"D:\Powerlifting Roblox\art\scripts\build_cartoon_gear_02.py").read())
import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = r"D:\Powerlifting Roblox"
C = {"CLOTHES_AS_LIBRARY": True, "__name__": "cartoon_clothes_lib"}
exec(open(os.path.join(ROOT, "art", "scripts", "build_cartoon_clothes_02.py")).read(), C)
Z = C["Z"]
OUT_BLEND = os.path.join(ROOT, "art", "blender", "CartoonGear_02.blend")
EXPORTS = os.path.join(ROOT, "art", "exports")
BUILDS = ("Skinny", "Heavy", "Muscular")

BENCH_T = 0.055
SINGLET_T = 0.07
BELT_T = 0.17
SLEEVE_T = 0.045           # knee sleeves (over bare legs: gear on takes the shorts off)
WRAP_T = 0.065             # knee wraps, wound thick
WRIST_T = 0.04


def log(*a):
    print("[CartoonGear]", *a)


def arm(p):
    return C["arm"](p)


def leg(p):
    return C["leg"](p)


def tagged_lip(o, depth, roll=0.012):
    """C.lip, and returns how many faces the garment had before it (the faces after are the rolled edges: Trim)."""
    n = len(o.data.polygons)
    C["lip"](o, depth, roll)
    return n


def split_by(o, coll, classify):
    """Splits a garment into one object per colour key: classify(face, index, centre, normal) -> key. Returns {key: obj}."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.faces.ensure_lookup_table()
    keys = {}
    for f in bm.faces:
        keys[f.index] = classify(f, f.index, f.calc_center_median(), f.normal)
    bm.free()
    out = {}
    for key in sorted(set(keys.values())):
        copy = o.copy()
        copy.data = o.data.copy()
        copy.name = o.name + "_" + key
        coll.objects.link(copy)
        bm = bmesh.new()
        bm.from_mesh(copy.data)
        bm.faces.ensure_lookup_table()
        gone = [f for f in bm.faces if keys[f.index] != key]
        bmesh.ops.delete(bm, geom=gone, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.to_mesh(copy.data)
        bm.free()
        if copy.data.polygons:
            out[key] = copy
        else:
            bpy.data.objects.remove(copy, do_unlink=True)
    bpy.data.objects.remove(o, do_unlink=True)
    return out


def weighted(obj, group):
    obj.vertex_groups.clear()
    obj.vertex_groups.new(name=group).add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    return obj


def text_mesh(name, coll, text, width, depth=0.008):
    """'CENTRAL' (or any text) as a mesh, `width` studs wide, facing -Y (the front), centred on the origin."""
    curve = bpy.data.curves.new(name + "_Curve", type="FONT")
    curve.body = text
    curve.extrude = depth / 2
    curve.resolution_u = 1
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    tmp = bpy.data.objects.new(name + "_Tmp", curve)
    coll.objects.link(tmp)
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(tmp, do_unlink=True)
    bpy.data.curves.remove(curve)
    xs = [v.co.x for v in me.vertices]
    scale = width / max(1e-6, max(xs) - min(xs))
    for v in me.vertices:
        # text lies in X-Y facing +Z: stand it up facing -Y
        v.co = Vector((v.co.x * scale, -v.co.z * scale, v.co.y * scale))
    obj = bpy.data.objects.new(name, me)
    coll.objects.link(obj)
    return obj


def card(name, coll, w, h, d=0.02):
    """A logo box: a thin rounded card facing -Y, centred on the origin."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * w, v.co.y * d, v.co.z * h))
    # rounded, but never more than the card is thick (a bigger bevel folded the faces inside out)
    bmesh.ops.bevel(bm, geom=[e for e in bm.edges], offset=min(w, h, d) * 0.35, segments=2, affect="EDGES",
                    clamp_overlap=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    coll.objects.link(obj)
    for p in me.polygons:
        p.use_smooth = False
    return obj


def place(obj, at, facing="front"):
    """Moves a front-facing mesh to `at`, turned to face `facing` ('front' -Y, 'back' +Y, 'left' +X, 'right' -X)."""
    turn = {"front": 0.0, "back": math.pi, "left": math.pi / 2, "right": -math.pi / 2}[facing]
    c, s = math.cos(turn), math.sin(turn)
    for v in obj.data.vertices:
        x, y = v.co.x, v.co.y
        v.co = Vector((x * c - y * s, x * s + y * c, v.co.z)) + at
    return obj


def surface(skin, x, z, side, extra):
    """A point on the skin's surface near (x, z) on `side` ('front' smallest y, 'back' largest), `extra` further out."""
    pts = [v.co for v in skin.data.vertices if abs(v.co.x - x) < 0.06 and abs(v.co.z - z) < 0.06]
    if not pts:
        return Vector((x, -0.5 if side == "front" else 0.5, z))
    y = min(p.y for p in pts) - extra if side == "front" else max(p.y for p in pts) + extra
    return Vector((x, y, z))


def logo(skin, coll, name, x, z, side, extra, box_key, text_key, group, w=0.46, h=0.17):
    """A CENTRAL logo box (box_key) with the text (text_key) on it; or just the text when box_key is None."""
    at = surface(skin, x, z, side, extra)
    out = {}
    if box_key:
        out[box_key] = weighted(place(card(name + "Box", coll, w, h), at, side), group)
    out[text_key] = weighted(place(text_mesh(name + "Text", coll, "CENTRAL", w * 0.82),
                                   at + Vector((0, -0.016 if side == "front" else 0.016, 0)), side), group)
    return out


def merge_keys(*dicts):
    out = {}
    for d in dicts:
        for k, o in d.items():
            out.setdefault(k, []).append(o)
    return {k: (v[0] if len(v) == 1 else C["join"](v, v[0].name + "_All")) for k, v in out.items()}


def torso_suit(build, skin, coll, name, distance, leg_end, deep, straps_key=None, panel_key="Panel",
               body_key="Body", legs_key=None, leg_panel_key=None):
    """A singlet-shaped shell: torso and thighs to `leg_end`, deep arm holes and a low neck so the shirt shows
    (`deep`: how far in the arm holes go), colour keys by face."""
    rig = bpy.data.objects[build + "Rig"]
    pivot = abs(rig.data.bones["LeftUpperArm"].head_local.x)
    cx, cy, rx, ry, z0 = C["NECK"][build]
    cuts = [(Vector((0, 0, Z(3.3))), Vector((0, 0, -1)), arm),
            (Vector((0, 0, leg_end)), Vector((0, 0, -1)), leg)]
    for sx in (1, -1):
        cuts.append((Vector((sx * (pivot - deep), 0, Z(3.0))), Vector((sx * 1.0, 0, 0.3)).normalized(), None))
    parts_ok = lambda p: "Hand" not in p and "Foot" not in p and "LowerLeg" not in p
    o = C["region"](skin, build + "_" + name, coll, parts_ok, cuts, thin=C["THIN"],
                    neck=(cx, cy - 0.02, rx * 1.12, ry * 1.12, z0 - 0.06))   # a singlet's scoop, straps stay
    C["push"](o, distance)
    n = tagged_lip(o, distance - 0.008, roll=0.018)
    strap_z = Z(3.55)
    names = {g.index: g.name for g in o.vertex_groups}

    def classify(f, i, c, nrm):
        if i >= n:
            return "Trim"
        is_leg = abs(c.x) > 0.15 and c.z < Z(1.95)
        if is_leg and legs_key:
            return leg_panel_key if (leg_panel_key and abs(nrm.x) > 0.72) else legs_key
        if abs(nrm.x) > 0.72 and c.z < strap_z:
            return panel_key
        if straps_key and c.z >= strap_z:
            return straps_key
        return body_key
    return split_by(o, coll, classify)


def gear_for(build, skin, coll):
    """Every worn model's colour pieces: {worn: {key: obj}}."""
    out = {}
    chest_z, back_z = Z(3.45), Z(3.5)
    # SINGLET: deep open sides, a low neck; side panels, the leg's side stripes, a CENTRAL logo box on the chest.
    singlet = torso_suit(build, skin, coll, "WornSinglet", SINGLET_T, Z(1.62), 0.32, panel_key="Red", body_key="Black",
                         legs_key="Shorts", leg_panel_key="ShortsRed")
    out["WornSinglet"] = merge_keys(singlet, logo(skin, coll, build + "_SingletLogo", 0.0, chest_z, "front",
                                                  SINGLET_T + 0.012, "Patch", "Black", "UpperTorso"))
    # SUITS: thicker canvas, longer legs, straps (Shoulder), a Label box with Patch text.
    for worn, leg_end in (("WornSquatSuit", Z(1.45)), ("WornDeadliftSuit", Z(1.55))):
        suit = torso_suit(build, skin, coll, worn, SINGLET_T + 0.008, leg_end, 0.26, straps_key="Shoulder")
        out[worn] = merge_keys(suit, logo(skin, coll, build + "_" + worn + "Logo", 0.0, chest_z, "front",
                                          SINGLET_T + 0.02, "Label", "Patch", "UpperTorso"))
    # BENCH SHIRT: thick, tight, sleeves to mid upper arm (Shoulder), side panels, a Label box with Patch text on the
    # back (the singlet goes over its chest).
    torso_arms = lambda p: not leg(p) and "Hand" not in p
    shirt = C["region"](skin, build + "_WornBenchShirt", coll, torso_arms,
                        [(Vector((0, 0, C["WAIST_TOP"] - 0.06)), Vector((0, 0, -1)), None),
                         (Vector((0, 0, Z(3.18))), Vector((0, 0, -1)), arm)], thin=C["THIN"], neck=C["NECK"][build])
    C["push"](shirt, BENCH_T)
    n = tagged_lip(shirt, BENCH_T - 0.008, roll=0.015)
    names = {g.index: g.name for g in shirt.vertex_groups}

    def bench_key(f, i, c, nrm):
        if i >= n:
            return "Trim"
        if abs(c.x) > abs(bpy.data.objects[build + "Rig"].data.bones["LeftUpperArm"].head_local.x) + 0.1:
            return "Shoulder"
        return "Panel" if abs(nrm.x) > 0.75 else "Body"
    out["WornBenchShirt"] = merge_keys(split_by(shirt, coll, bench_key),
                                       logo(skin, coll, build + "_BenchLogo", 0.0, back_z, "back", BENCH_T + 0.012,
                                            "Label", "Patch", "UpperTorso"))
    # LEVER BELT: chunky (0.17 out, 0.55 tall, bulging rolled edges), a lining edge above and below, two stitch rows,
    # a big steel lever on the front, CENTRAL on the back.
    mid, half = Z(2.25), 0.275
    belt_parts = lambda p: "Torso" in p or "UpperLeg" in p
    outer = C["band"](skin, build + "_BeltOuter", coll, belt_parts, mid - half, mid + half, BELT_T)
    lining = [C["band"](skin, build + "_BeltLining%d" % i, coll, belt_parts, lo, hi, BELT_T - 0.03)
              for i, (lo, hi) in enumerate(((mid + half - 0.01, mid + half + 0.035), (mid - half - 0.035, mid - half + 0.01)))]
    stitch = [C["band"](skin, build + "_BeltStitch%d" % i, coll, belt_parts, z - 0.012, z + 0.012, BELT_T + 0.012)
              for i, z in enumerate((mid + half - 0.09, mid - half + 0.09))]
    lever_at = surface(skin, 0.0, mid, "front", BELT_T + 0.035)
    lever = weighted(place(card(build + "_BeltLever", coll, 0.36, 0.24, 0.07), lever_at, "front"), "LowerTorso")
    text = weighted(place(text_mesh(build + "_BeltText", coll, "CENTRAL", 0.62, 0.012),
                          surface(skin, 0.0, mid, "back", BELT_T + 0.008), "back"), "LowerTorso")
    out["WornLeverBelt"] = {"Outer": outer, "Lining": C["join"](lining, build + "_BeltLining"),
                            "Stitch": C["join"](stitch, build + "_BeltStitch"), "Lever": lever, "Text": text}
    # KNEE SLEEVES: one seamless tube mid-thigh to mid-shin (skinned across the knee), a diagonal stripe down the
    # outer side, CENTRAL low on the front.
    legs_only = lambda p: "UpperLeg" in p or "LowerLeg" in p
    sleeve = C["band"](skin, build + "_KneeSleeve", coll, legs_only, Z(0.8), Z(1.55), SLEEVE_T)

    def sleeve_key(f, i, c, nrm):
        # one clean diagonal line down the outer side (a looser test speckled grey over the sleeve)
        outer_side = (c.x > 0.5 and nrm.x > 0.6) or (c.x < -0.5 and nrm.x < -0.6)
        d = c.z + 0.6 * c.y
        return "Stripes" if outer_side and abs(d - Z(1.18)) < 0.045 else "Body"
    patches = {}
    for sx, side in ((1, "L"), (-1, "R")):
        patches = merge_keys(patches, {"Patch": weighted(place(text_mesh(build + "_SleeveText" + side, coll, "CENTRAL", 0.36),
                                                               surface(skin, sx * 0.5, Z(0.98), "front", SLEEVE_T + 0.01), "front"),
                                                         ("Left" if sx > 0 else "Right") + "LowerLeg")})
    out["WornKneeSleeve"] = merge_keys(split_by(sleeve, coll, sleeve_key), patches)
    # KNEE WRAPS: wound thick round the knee, a spiral stripe, accent edges.
    wrap = C["band"](skin, build + "_KneeWrap", coll, legs_only, Z(0.95), Z(1.45), WRAP_T)

    def wrap_key(f, i, c, nrm):
        if abs(c.z - Z(0.95)) < 0.03 or abs(c.z - Z(1.45)) < 0.03:
            return "Accent"
        cx = 0.5 if c.x > 0 else -0.5
        a = math.atan2(c.y, c.x - cx) / (2 * math.pi)
        return "Stripes" if ((c.z * 3.2 + a) % 1.0) < 0.2 else "Body"
    out["WornKneeWrap"] = split_by(wrap, coll, wrap_key)
    # WRIST WRAPS: over the forearm's end and down over the wrist (a tube to below the wrist joint, with the forearm,
    # so the hand turns inside it), a stripe, the loose tail, small CENTRAL text.
    cut = Z(2.37)
    wrist = C["band"](skin, build + "_WristWrap", coll, lambda p: "LowerArm" in p, cut - 0.02, cut + 0.3, WRIST_T, where=arm)
    tubes, tails, texts = [], [], []
    rig = bpy.data.objects[build + "Rig"]
    for side, sx in (("Left", 1), ("Right", -1)):
        jx = rig.data.bones[side + "Hand"].head_local.x
        jz = rig.data.bones[side + "Hand"].head_local.z
        ring = [v.co for v in skin.data.vertices if abs(v.co.z - (cut + 0.05)) < 0.04 and abs(v.co.x - jx) < 0.4]
        rx = (max(p.x for p in ring) - min(p.x for p in ring)) / 2 + WRIST_T if ring else 0.16
        ry = (max(p.y for p in ring) - min(p.y for p in ring)) / 2 + WRIST_T if ring else 0.14
        bm = bmesh.new()
        geom = bmesh.ops.create_cone(bm, cap_ends=False, cap_tris=False, segments=20, radius1=1.0, radius2=1.0, depth=1.0)
        top, bottom = cut + 0.06, jz - 0.07
        for v in geom["verts"]:
            u = (v.co.z + 0.5)
            shrink = 0.94 + 0.06 * u
            v.co = Vector((jx + v.co.x * rx * shrink, v.co.y * ry * shrink, bottom + u * (top - bottom)))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new(build + "_WristTube" + side)
        bm.to_mesh(me)
        bm.free()
        tube = bpy.data.objects.new(me.name, me)
        coll.objects.link(tube)
        weighted(tube, side + "LowerArm")
        C["lip"](tube, 0.03, roll=0.01)
        tubes.append(tube)
        tails.append(weighted(place(card(build + "_WristTail" + side, coll, 0.12, 0.16, 0.02),
                                    Vector((jx + sx * (rx + 0.01), 0.0, cut - 0.02)), "left" if sx > 0 else "right"), side + "LowerArm"))
        texts.append(weighted(place(text_mesh(build + "_WristText" + side, coll, "CENTRAL", 0.22, 0.006),
                                    Vector((jx, -(ry + 0.012), cut + 0.02)), "front"), side + "LowerArm"))

    def wrist_key(f, i, c, nrm):
        return "Stripes" if abs(c.z - (cut + 0.24)) < 0.03 else "Body"
    body = split_by(C["join"]([wrist] + tubes, build + "_WristAll"), coll, wrist_key)
    out["WornWristWrap"] = merge_keys(body, {"Tail": C["join"](tails, build + "_WristTails"),
                                             "Text": C["join"](texts, build + "_WristTexts")})
    for worn in out.values():
        for o in worn.values():
            for p in o.data.polygons:
                p.use_smooth = not ("Text" in o.name or "Lever" in o.name or "Box" in o.name)
    return out


def build_one(build, coll):
    rig = bpy.data.objects[build + "Rig"]
    saved = rig.location.copy()
    rig.location = (0, 0, 0)
    bpy.context.view_layer.update()
    skin = C["skin_of"](build, coll)
    bm = bmesh.new()
    bm.from_mesh(skin.data)
    C["SKIN_TREE"] = C["BVHTree"].FromBMesh(bm)
    bm.free()
    # the bands (belt, sleeves, wraps) from a lighter copy of the skin (performance: the belt alone was 3,400 triangles)
    low = skin.copy()
    low.data = skin.data.copy()
    low.name = build + "_GearSkinLow"
    coll.objects.link(low)
    C["thin_out"](low, 0.45)
    C["SKIN_LOW"] = low
    pieces = []
    for worn, keys in gear_for(build, skin, coll).items():
        for key, o in keys.items():
            pieces += C["split"](build, worn + "_" + key, o, coll, rig)
    bpy.data.objects.remove(skin, do_unlink=True)
    bpy.data.objects.remove(low, do_unlink=True)
    C["SKIN_LOW"] = None
    for p in pieces:
        p.name = p.name.split("_", 1)[1]
        p.data.name = p.name
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for p in pieces:
        p.select_set(True)
    bpy.context.view_layer.objects.active = rig
    path = os.path.join(EXPORTS, "CartoonGear_%s.glb" % build)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_yup=True,
                              export_skins=True, export_animations=False, export_morph=False)
    for p in pieces:
        p.name = build + "_" + p.name
        p.data.name = p.name
    rig.location = saved
    tris = {}
    for p in pieces:
        worn = p.name.split("_", 1)[1].split("__")[0].split("_")[0]
        tris[worn] = tris.get(worn, 0) + sum(len(f.vertices) - 2 for f in p.data.polygons)
    log(build, "exported", path, tris)
    return pieces


coll = bpy.data.collections.get("CartoonGear") or bpy.data.collections.new("CartoonGear")
if coll.name not in bpy.context.scene.collection.children:
    bpy.context.scene.collection.children.link(coll)
for o in list(coll.objects):
    bpy.data.objects.remove(o, do_unlink=True)
RESULT = {b: build_one(b, coll) for b in BUILDS}
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
