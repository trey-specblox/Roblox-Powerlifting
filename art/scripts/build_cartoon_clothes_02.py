# The basic clothes refitted to the cartoon bodies (GAME_DESIGN.md §38.6-38.7; user 2026-11-12: "Clothes and gear
# refitted to the new shapes"). Replaces build_clothes_01.py (shaped for the dropped realistic body).
#
# Style (References/Body Study.md, the BodyClips frames): tight shells over the muscles; sleeves and shorts end in thick
# WHITE fabric cuffs; shorts (and joggers) have a doubled white waistband with drawstrings. Plain colours otherwise
# (coloured in the game: one mesh serves every colour; the white pieces keep their colour, ClothesConfig `fixed`).
#
# How (per build, from art/blender/CartoonBodies_02.blend, which must be open):
#   1. the build's 14 skinned parts joined back into one skin (seams merged), weights kept
#   2. each garment: the skin it covers (by body part), cut with flat planes for clean edges, pushed out along the skin
#      (bottoms under shirts), thinned a little (performance), every open edge given a rolled lip (never paper-thin)
#   3. bands (cuffs, waistbands, a collar) the same way: a strip of skin between two planes, pushed further out, lipped
#   4. split into one mesh per R15 body part, "<Item>__<Part>" (white pieces "<Item>White__<Part>"), skinned to the same
#      skeleton, so in Roblox each piece bends with the body (LifterBodyService.dressOutfit places it from the rest pose)
# Writes art/blender/CartoonClothes_02.blend and art/exports/CartoonClothes_<Build>.glb (+ a line-up preview).
# Run inside Blender with CartoonBodies_02.blend open:
#   exec(open(r"D:\Powerlifting Roblox\art\scripts\build_cartoon_clothes_02.py").read())
import os

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = r"D:\Powerlifting Roblox"
OUT_BLEND = os.path.join(ROOT, "art", "blender", "CartoonClothes_02.blend")
EXPORTS = os.path.join(ROOT, "art", "exports")
BUILDS = ("Skinny", "Heavy", "Muscular")
PARTS = ["LowerTorso", "UpperTorso"] + [s + p for s in ("Left", "Right") for p in
                                         ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")]

# Layers: distance from the skin (studs).
BOTTOM_T = 0.025
SHIRT_T = 0.04
SHOE_T = 0.045
BAND_EXTRA = 0.03          # cuffs and waistbands stand this much further out than their garment
THIN = 0.6                 # garments keep this share of the skin's triangles (performance)

# Heights on the block skeleton (build_cartoon_rig_02.py): neck 4.0, shoulder pivot 3.763, elbow 3.035, wrist 2.275
# (the forearm is cut at 2.37), waist 2.4, hips 2.0, knee 1.178, ankle 0.252.
# The taller bodies (user 2026-11-12, lifter_heights.py): the heights below are written on the block skeleton and go
# through Z() to the new one.
_LH = {"__name__": "lifter_heights"}
exec(open(os.path.join(ROOT, "art", "scripts", "lifter_heights.py")).read(), _LH)
Z = _LH["z"]

SLEEVE_END = Z(3.28)       # a tee's sleeve: mid-biceps, tight
SLEEVE_CUFF = 0.13
LONG_END = Z(2.44)         # a long sleeve: just above the forearm's end
WAIST_TOP = Z(2.40)        # bottoms' top; the shirt's hem sits on it
BAND = 0.08                # each of the two waistband rolls
SHORTS_END = Z(1.56)       # shorts: mid-thigh
LEG_CUFF = 0.13
JOGGERS_END = 0.42         # joggers: just above the shoe's collar
SHOE_TOP = 0.40
# A round crew neck per build: (centre x, centre y, radius x, radius y, from z); the head sits into the body at 4.0.
NECK = {"Skinny": (0.0, 0.02, 0.42, 0.34, Z(3.78)), "Heavy": (0.0, 0.12, 0.5, 0.42, Z(3.8)),
        "Muscular": (0.0, 0.03, 0.5, 0.4, Z(3.8))}
WHITE = (0.93, 0.93, 0.91, 1)
SKIN_TREE = None           # the build's skin, to keep every garment outside it (set per build)
SKIN_LOW = None            # a lighter copy of the skin the bands are cut from (performance)
BAND_SKIN = 0.45


def log(*a):
    print("[CartoonClothes]", *a)


def arm(part):
    return "Arm" in part or "Hand" in part


def leg(part):
    return "Leg" in part or "Foot" in part


def skin_of(build, coll):
    """The build's parts joined into one skin with their weights (seams merged), in the rig's own space."""
    rig = bpy.data.objects[build + "Rig"]
    copies = []
    for part in PARTS:
        src = bpy.data.objects[build + "_" + part]
        o = src.copy()
        o.data = src.data.copy()
        o.modifiers.clear()
        o.parent = None
        o.matrix_world = rig.matrix_world.inverted() @ src.matrix_world
        coll.objects.link(o)
        copies.append(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in copies:
        o.select_set(True)
    bpy.context.view_layer.objects.active = copies[0]
    bpy.ops.object.join()
    skin = bpy.context.view_layer.objects.active
    skin.name = build + "_ClothesSkin"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(skin.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bm.to_mesh(skin.data)
    bm.free()
    if skin.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    return skin


def dominant(v, deform, names):
    best, weight = None, 0.0
    for index, w in v[deform].items():
        if w > weight and index in names:
            best, weight = names[index], w
    return best or "UpperTorso"


def cut(bm, point, normal, keep_where=None, deform=None, names=None):
    """Bisects the mesh with a plane and removes the side the normal points to (only among faces `keep_where` picks
    by body part, when given)."""
    if keep_where:
        faces = [f for f in bm.faces if all(keep_where(dominant(v, deform, names)) for v in f.verts)]
    else:
        faces = list(bm.faces)
    if not faces:
        return
    geom = faces + list({e for f in faces for e in f.edges}) + list({v for f in faces for v in f.verts})
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=point, plane_no=normal, clear_outer=True)


def thin_out(o, ratio):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    d = o.modifiers.new("Fewer", "DECIMATE")
    d.ratio = ratio
    bpy.ops.object.modifier_apply(modifier=d.name)


def region(skin, name, coll, parts_ok, cuts, thin=None, neck=None, spikes=True):
    """A copy of the skin keeping the faces whose verts lie on `parts_ok` parts, thinned (BEFORE the cuts, so every
    edge stays a clean line), then cut by each (point, normal, where) plane (the normal's side goes). `neck`
    (centre x, centre y, radius x, radius y, from z) cuts a round neck hole."""
    o = skin.copy()
    o.data = skin.data.copy()
    o.name = name
    coll.objects.link(o)
    names = {g.index: g.name for g in o.vertex_groups}
    bm = bmesh.new()
    bm.from_mesh(o.data)
    deform = bm.verts.layers.deform.active
    gone = [f for f in bm.faces if not all(parts_ok(dominant(v, deform, names)) for v in f.verts)]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bm.to_mesh(o.data)
    bm.free()
    if thin and thin < 1.0:
        thin_out(o, thin)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    deform = bm.verts.layers.deform.active
    for point, normal, where in cuts:
        cut(bm, point, normal, where, deform, names)
    if neck:
        cx, cy, rx, ry, z0 = neck
        def inside(v):
            return v.co.z > z0 and ((v.co.x - cx) / rx) ** 2 + ((v.co.y - cy) / ry) ** 2 < 1.0
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if any(inside(v) for v in f.verts)], context="FACES")
        # The hole's edge onto the ellipse, so the neckline is round, not ragged.
        for v in bm.verts:
            if v.is_boundary and v.co.z > z0 - 0.05:
                dx, dy = (v.co.x - cx) / rx, (v.co.y - cy) / ry
                r = (dx * dx + dy * dy) ** 0.5
                if 0.0 < r < 1.35:
                    v.co.x, v.co.y = cx + dx / r * rx, cy + dy / r * ry
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    tidy(bm, spikes)
    bm.to_mesh(o.data)
    bm.free()
    return o


def tidy(bm, spikes=True):
    """Cleans the cut edges: spikes (faces hanging on by one edge, where a cut on the arm meets the torso's edge in the
    armpit) go, folds left by thinning are smoothed, and each edge line is smoothed along itself. First the slivers a
    flat cut leaves along its line (hair-thin triangles shade badly) are dissolved."""
    bmesh.ops.dissolve_degenerate(bm, dist=0.006, edges=bm.edges)
    # Only small faces: removing every face with two open edges eats a thinned garment row by row.
    for _ in range(2 if spikes else 0):
        hanging = [f for f in bm.faces if sum(1 for e in f.edges if e.is_boundary) >= 2 and f.calc_area() < 0.004]
        if not hanging:
            break
        bmesh.ops.delete(bm, geom=hanging, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    folded = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle() > 1.9]
    around = {o for e in folded for v in e.verts for le in v.link_edges for o in le.verts}
    if around:
        for _ in range(3):
            bmesh.ops.smooth_vert(bm, verts=[v for v in around if not v.is_boundary], factor=0.7,
                                  use_axis_x=True, use_axis_y=True, use_axis_z=True)
    for _ in range(3):
        moves = {}
        for v in bm.verts:
            if not v.is_boundary:
                continue
            ends = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
            if len(ends) == 2:
                moves[v] = v.co.lerp((ends[0].co + ends[1].co) / 2, 0.5)
        for v, co in moves.items():
            v.co = co


def push(o, distance, relax=3):
    """Pushes the surface out along its smooth normals, then relaxes it: in the creases between muscles the pushed
    points cross over each other and flip triangles (dark jagged patches); fabric bridges those creases anyway.
    Logs any face still flipped against the skin."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.normal_update()
    normals = {v.index: v.normal.copy() for v in bm.verts}
    before = {f.index: f.normal.copy() for f in bm.faces}
    for v in bm.verts:
        v.co += normals[v.index] * distance
    inner = [v for v in bm.verts if not v.is_boundary]
    for _ in range(relax):
        bmesh.ops.smooth_vert(bm, verts=inner, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    # Relaxing pulls a curved shell back into the skin: every point goes back out to at least 90% of its distance,
    # measured to the real skin (nearest point on it).
    if SKIN_TREE is not None:
        floor = distance * 0.9
        for v in bm.verts:
            loc, nrm, _i, d = SKIN_TREE.find_nearest(v.co)
            if loc is None or d is None:
                continue
            away = v.co - loc
            outside = away.dot(nrm) > 0
            if d < floor or not outside:
                v.co = loc + nrm.normalized() * floor
    bm.normal_update()
    flipped = sum(1 for f in bm.faces if f.normal.dot(before[f.index]) < 0)
    if flipped:
        log(o.name, "faces still flipped:", flipped)
    bm.to_mesh(o.data)
    bm.free()


def lip(o, depth, roll=0.012):
    """Turns every open edge inward (toward the skin) by `depth`, with a small roll outward first, so an edge reads as
    a thick hem from any angle. Built point by point: each edge vertex gets a partner pushed in along its normal, and
    each edge a quad to its partners."""
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.normal_update()
    deform = bm.verts.layers.deform.active
    edges = [e for e in bm.edges if e.is_boundary]
    if not edges:
        bm.free()
        return
    rim = {v for e in edges for v in e.verts}
    normal = {v: v.normal.copy() for v in rim}
    partner = {}
    for v in rim:
        p = bm.verts.new(v.co - normal[v] * depth)
        if deform is not None:
            for k, w in v[deform].items():
                p[deform][k] = w
        partner[v] = p
    for v in rim:
        v.co += normal[v] * roll
    for e in edges:
        a, b = e.verts
        try:
            bm.faces.new((a, b, partner[b], partner[a]))
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(o.data)
    bm.free()


def band(skin, name, coll, parts_ok, low, high, distance, where=None):
    """A thick fabric band: the skin between two flat planes (z = low..high), pushed out, its edges lipped."""
    cuts = [(Vector((0, 0, high)), Vector((0, 0, 1)), where), (Vector((0, 0, low)), Vector((0, 0, -1)), where)]
    # (a band is a narrow strip: not thinned, and its one-face-tall edges are not spikes)
    o = region(SKIN_LOW or skin, name, coll, parts_ok, cuts, spikes=False)
    if where:
        # Keep only the parts of the band on `where` parts (the planes only cut those).
        names = {g.index: g.name for g in o.vertex_groups}
        bm = bmesh.new()
        bm.from_mesh(o.data)
        deform = bm.verts.layers.deform.active
        gone = [f for f in bm.faces if not where(dominant(f.verts[0], deform, names))]
        bmesh.ops.delete(bm, geom=gone, context="FACES")
        bm.to_mesh(o.data)
        bm.free()
    push(o, distance)
    lip(o, distance - 0.008, roll=0.01)
    return o


def string(name, coll, start, end, r=0.026):
    """A drawstring hanging from the waistband, with a tip (an aglet) on its end (weighted to the LowerTorso)."""
    bm = bmesh.new()
    d = end - start
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix()
    geom = bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=1.0)
    for v in geom["verts"]:
        v.co = rot @ Vector((v.co.x * r, v.co.y * r * 0.75, v.co.z * (d.length / 2 + r))) + (start + end) / 2
    geom = bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=1.0)
    for v in geom["verts"]:
        v.co = rot @ Vector((v.co.x * r * 1.25, v.co.y * r * 1.25, v.co.z * r * 1.9)) + end
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    o.vertex_groups.new(name="LowerTorso").add(list(range(len(me.vertices))), 1.0, "REPLACE")
    return o


def front_of(skin, x, z):
    """The skin's front surface (smallest y) near (x, z)."""
    pts = [v.co for v in skin.data.vertices if abs(v.co.x - x) < 0.05 and abs(v.co.z - z) < 0.05]
    return min(p.y for p in pts) if pts else -0.5


def sole(name, coll, side_x):
    """The sneaker's white sole: a rounded slab under the foot (the foot shape: centre (+-0.5, -0.1), 0.26 x 0.42)."""
    bm = bmesh.new()
    geom = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=24, radius1=1.0, radius2=1.0, depth=1.0)
    for v in geom["verts"]:
        v.co = Vector((side_x + v.co.x * 0.31, -0.11 + v.co.y * 0.48, 0.05 + v.co.z * 0.1))
    bmesh.ops.bevel(bm, geom=[e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-6],
                    offset=0.03, segments=2, affect="EDGES")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    o.vertex_groups.new(name=("Left" if side_x > 0 else "Right") + "Foot").add(list(range(len(me.vertices))), 1.0,
                                                                               "REPLACE")
    return o


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    return o


def garments(build, skin, coll):
    """Every item's pieces: {prefix: object} (prefix = the item id, or <item>White for its white pieces)."""
    out = {}
    torso_arms = lambda p: not leg(p) and "Hand" not in p
    # The shirt's hem tucks under the waistband's top roll (it stands further out), so no skin shows between them.
    hem = (Vector((0, 0, WAIST_TOP - 0.06)), Vector((0, 0, -1)), None)
    neck = NECK[build]
    sleeve = (Vector((0, 0, SLEEVE_END)), Vector((0, 0, -1)), arm)
    # T-shirt: sleeves to mid-biceps with a white cuff, a round crew neck.
    tee = region(skin, build + "_Tee", coll, torso_arms, [hem, sleeve], thin=THIN, neck=neck)
    push(tee, SHIRT_T)
    lip(tee, SHIRT_T - 0.006)
    out["Tee"] = tee
    out["TeeWhite"] = band(skin, build + "_TeeWhite", coll, torso_arms, SLEEVE_END - 0.01, SLEEVE_END + SLEEVE_CUFF,
                           SHIRT_T + BAND_EXTRA, where=arm)
    # Long sleeve: down to the forearm's end, a white cuff.
    long = region(skin, build + "_LongSleeve", coll, torso_arms,
                  [hem, (Vector((0, 0, LONG_END)), Vector((0, 0, -1)), arm)], thin=THIN, neck=neck)
    push(long, SHIRT_T)
    lip(long, SHIRT_T - 0.006)
    out["LongSleeve"] = long
    out["LongSleeveWhite"] = band(skin, build + "_LongSleeveWhite", coll, torso_arms, LONG_END - 0.01,
                                  LONG_END + SLEEVE_CUFF, SHIRT_T + BAND_EXTRA, where=arm)
    # Tank top: no sleeves, deep armholes and a U-neck (a sloped neck cut took the big pecs' tops off), edges rolled.
    rig = bpy.data.objects[build + "Rig"]
    pivot = abs(rig.data.bones["LeftUpperArm"].head_local.x)
    tank_cuts = [hem]
    for sx in (1, -1):
        # steep armholes, so the straps over the shoulders stay
        tank_cuts.append((Vector((sx * (pivot - 0.12), 0, Z(3.05))), Vector((sx * 1.0, 0, 0.15)).normalized(), None))
    cx, cy, rx, ry, z0 = neck
    # From the arms too: on the skinny and muscular builds the skin over the upper chest and traps follows the
    # shoulder bone most, so a torso-only tank lost it. The arms come off: below the armpit, then the armholes.
    tank_cuts.insert(0, (Vector((0, 0, Z(3.3))), Vector((0, 0, -1)), arm))
    tank = region(skin, build + "_Tank", coll, torso_arms, tank_cuts, thin=THIN,
                  neck=(cx, cy + 0.02, rx * 1.12, ry, z0 - 0.04))   # a U-neck, in front of the pecs' tops
    push(tank, SHIRT_T)
    lip(tank, SHIRT_T - 0.006, roll=0.02)
    out["Tank"] = tank
    # Shorts: to mid-thigh with white cuffs; the doubled white waistband with drawstrings.
    # (the torso too: a heavy belly hangs below the waist joint)
    lower = lambda p: "Torso" in p or "UpperLeg" in p or "LowerLeg" in p
    waist_parts = lambda p: "Torso" in p or "UpperLeg" in p
    # The shorts' top tucks under the waistband's bottom roll.
    top = (Vector((0, 0, WAIST_TOP - BAND - 0.02)), Vector((0, 0, 1)), None)
    shorts = region(skin, build + "_Shorts", coll, lower, [top, (Vector((0, 0, SHORTS_END)), Vector((0, 0, -1)), leg)],
                    thin=THIN)
    push(shorts, BOTTOM_T)
    lip(shorts, BOTTOM_T - 0.006)
    out["Shorts"] = shorts
    y = front_of(skin, 0.0, WAIST_TOP - BAND) - BOTTOM_T - BAND_EXTRA - 0.02

    def waistband(tag):
        rolls = [band(skin, build + "_%sWaist%d" % (tag, i), coll, waist_parts, WAIST_TOP - (i + 1) * BAND,
                      WAIST_TOP - i * BAND + 0.004, BOTTOM_T + BAND_EXTRA + 0.01 * (1 - i)) for i in range(2)]
        strings = [string(build + "_%sString%d" % (tag, i), coll, Vector((sx * 0.06, y, WAIST_TOP - BAND * 1.05)),
                          Vector((sx * 0.085, y - 0.03, WAIST_TOP - BAND * 1.05 - 0.17))) for i, sx in enumerate((1, -1))]
        return rolls + strings
    cuffs = band(skin, build + "_ShortsCuff", coll, lower, SHORTS_END - 0.01, SHORTS_END + LEG_CUFF, BOTTOM_T + BAND_EXTRA,
                 where=leg)
    out["ShortsWhite"] = join(waistband("S") + [cuffs], build + "_ShortsWhite")
    # Joggers: to the shoe with white cuffs; the same waistband.
    joggers = region(skin, build + "_Joggers", coll, lambda p: lower(p) or "Foot" in p,
                     [top, (Vector((0, 0, JOGGERS_END)), Vector((0, 0, -1)), leg)], thin=THIN)
    push(joggers, BOTTOM_T)
    lip(joggers, BOTTOM_T - 0.006)
    out["Joggers"] = joggers
    cuffs = band(skin, build + "_JoggersCuff", coll, lambda p: "LowerLeg" in p or "Foot" in p, JOGGERS_END - 0.01,
                 JOGGERS_END + LEG_CUFF, BOTTOM_T + BAND_EXTRA, where=leg)
    out["JoggersWhite"] = join(waistband("J") + [cuffs], build + "_JoggersWhite")
    # Sneakers: a shell over the foot up to the collar; a white sole.
    shoes = region(skin, build + "_Sneakers", coll, lambda p: "Foot" in p or "LowerLeg" in p,
                   [(Vector((0, 0, SHOE_TOP)), Vector((0, 0, 1)), None), (Vector((0, 0, 0.07)), Vector((0, 0, -1)), None)])
    push(shoes, SHOE_T)
    lip(shoes, SHOE_T - 0.006, roll=0.015)
    out["Sneakers"] = shoes
    out["SneakersSole"] = join([sole(build + "_SoleL", coll, 0.5), sole(build + "_SoleR", coll, -0.5)],
                               build + "_SneakersSole")
    for o in out.values():
        for p in o.data.polygons:
            p.use_smooth = True
    return out


def split(build, prefix, o, coll, rig):
    """One mesh per body part (by each face's main bone), "<prefix>__<Part>", parented to the build's rig."""
    names = {g.index: g.name for g in o.vertex_groups}
    me = o.data
    # The whole garment's smooth shading kept on every piece (else each piece shades its own edge: seam lines).
    for p in me.polygons:
        p.use_smooth = True
    me.normals_split_custom_set_from_vertices([v.normal for v in me.vertices])
    me.materials.clear()
    for part in PARTS:
        me.materials.append(bpy.data.materials.get("Split_" + part) or bpy.data.materials.new("Split_" + part))
    bm = bmesh.new()
    bm.from_mesh(me)
    deform = bm.verts.layers.deform.active
    for f in bm.faces:
        votes = {}
        for v in f.verts:
            p = dominant(v, deform, names)
            votes[p] = votes.get(p, 0) + 1
        f.material_index = PARTS.index(max(votes.items(), key=lambda kv: kv[1])[0])
    bm.to_mesh(me)
    bm.free()
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")
    pieces = []
    for p in [x for x in coll.objects if x == o or x.name.startswith(o.name + ".")]:
        if not p.data.polygons:
            bpy.data.objects.remove(p, do_unlink=True)
            continue
        part = p.data.materials[p.data.polygons[0].material_index].name.replace("Split_", "")
        for poly in p.data.polygons:
            poly.material_index = 0
        p.data.materials.clear()
        mat = bpy.data.materials.get("Clothes_" + ("White" if "White" in prefix or "Sole" in prefix else "Colour")) \
            or bpy.data.materials.new("Clothes_" + ("White" if "White" in prefix or "Sole" in prefix else "Colour"))
        mat.diffuse_color = WHITE if ("White" in prefix or "Sole" in prefix) else (0.45, 0.47, 0.52, 1)
        p.data.materials.append(mat)
        p.data.validate(verbose=False, clean_customdata=False)
        p.name = "%s_%s__%s" % (build, prefix, part)
        p.data.name = p.name
        # skinned to the rig like the body
        p.parent = rig
        p.matrix_parent_inverse = rig.matrix_world.inverted()
        m = p.modifiers.new("Armature", "ARMATURE")
        m.object = rig
        pieces.append(p)
    return pieces


def build_one(build, coll):
    rig = bpy.data.objects[build + "Rig"]
    saved = rig.location.copy()
    rig.location = (0, 0, 0)
    bpy.context.view_layer.update()
    skin = skin_of(build, coll)
    global SKIN_TREE
    bm = bmesh.new()
    bm.from_mesh(skin.data)
    SKIN_TREE = BVHTree.FromBMesh(bm)
    bm.free()
    global SKIN_LOW
    SKIN_LOW = skin.copy()
    SKIN_LOW.data = skin.data.copy()
    SKIN_LOW.name = build + "_ClothesSkinLow"
    coll.objects.link(SKIN_LOW)
    thin_out(SKIN_LOW, BAND_SKIN)
    pieces = []
    for prefix, o in garments(build, skin, coll).items():
        pieces += split(build, prefix, o, coll, rig)
    bpy.data.objects.remove(skin, do_unlink=True)
    bpy.data.objects.remove(SKIN_LOW, do_unlink=True)
    SKIN_LOW = None
    # export: rig + pieces, plain "<prefix>__<Part>" names
    for p in pieces:
        p.name = p.name.split("_", 1)[1]
        p.data.name = p.name
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for p in pieces:
        p.select_set(True)
    bpy.context.view_layer.objects.active = rig
    path = os.path.join(EXPORTS, "CartoonClothes_%s.glb" % build)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_yup=True,
                              export_skins=True, export_animations=False, export_morph=False)
    for p in pieces:
        p.name = build + "_" + p.name
        p.data.name = p.name
    rig.location = saved
    tris = {}
    for p in pieces:
        item = p.name.split("_", 1)[1].split("__")[0]
        tris[item] = tris.get(item, 0) + sum(len(f.vertices) - 2 for f in p.data.polygons)
    log(build, "exported", path, tris)
    return pieces


# (build_cartoon_gear_02.py loads this file as a library, with CLOTHES_AS_LIBRARY = True, for its tools)
if globals().get("CLOTHES_AS_LIBRARY") is not True:
    coll = bpy.data.collections.get("CartoonClothes") or bpy.data.collections.new("CartoonClothes")
    if coll.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(coll)
    for o in list(coll.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    RESULT = {b: build_one(b, coll) for b in BUILDS}
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
