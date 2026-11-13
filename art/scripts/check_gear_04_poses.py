# Picture check for the PROTOTYPE-04 bodies with the v4 gear (build_cartoon_gear_04.py): the gear and clothes
# line-ups (front, three-quarter, back, each build's side) and the lift / emote / celebration moments, with
#   - the game's hand shapes (HandShapeConfig): FISTS while gripping the bar and in the moves that close the hands
#     (belt tighten, double biceps, the roars, the prayer's fists), open hands everywhere else;
#   - a CONTACT FIX prototype: in the moves where the hands meet something (claps, praying hands, fists pressed
#     together, palms on the chest, fists on the belt) each arm is bent by two-bone IK (shoulder kept) so the hand
#     ENDS ON its contact point for this build (touching, not passing through); in every other pose overlapping hands
#     are only pushed apart. The same rule would run in the game as an IKControl per arm (not built: a game change
#     that needs a Studio test). Each moment is drawn before/after, contact moves also close up.
# Read-only: CartoonGear_04_Proto.blend is opened and NOT saved. GEAR04_ANIMS = the block-rig animation folder.
#   blender -b art/blender/CartoonGear_04_Proto.blend --python art/scripts/check_gear_04_poses.py -- <out_dir>
import os
import sys

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
OUT = sys.argv[sys.argv.index("--") + 1]
os.makedirs(OUT, exist_ok=True)
ANIMS = os.environ.get("GEAR04_ANIMS", "")
assert os.path.isdir(ANIMS), "set GEAR04_ANIMS to the folder of the block-rig animations"
BUILDS = ("Skinny", "Heavy", "Muscular")
SPACING = 4.6

G = {"__name__": "gear_fit_03"}
exec(open(os.path.join(SCRIPTS, "gear_fit_03.py")).read(), G)
G["ANIMS"] = ANIMS
src = open(os.path.join(SCRIPTS, "build_cartoon_rig_02.py")).read().split("\ncoll = collection()\nRESULTS")[0]
R = {"__name__": "rig02_lib"}
exec(src, R)
P = {"__name__": "body04_lib", "PROTO04_AS_LIBRARY": True}
exec(open(os.path.join(SCRIPTS, "build_cartoon_body_04.py")).read(), P)
L = P["TORSO_TALL"]
rigs = {b: bpy.data.objects[b + "Rig"] for b in BUILDS}
coll = bpy.data.collections.new("Check04")
bpy.context.scene.collection.children.link(coll)


def item_of(o):
    if "__" not in o.name:
        return None
    b, rest = o.name.split("_", 1)
    return b, rest.split("__")[0].split("_")[0]


pieces = [o for o in bpy.data.objects if o.type == "MESH" and item_of(o) and item_of(o)[0] in BUILDS]

# ---------------------------------------------------------------- fists (HandShapeConfig's swap) on each hand bone
fists, opens = {}, {}
skin = bpy.data.materials.get("CartoonSkin")
for b, rig in rigs.items():
    spec = P["BUILDS"][b](L)
    for side, sx in (("Left", 1), ("Right", -1)):
        f = R["H"]["make_hand"]("Fist", coll)
        f.name = "%s_Fist%s" % (b, side)
        f.data.transform(Matrix.Translation(Vector((sx * spec["arm_x"], 0, L["WR"]))) @ R["hand_space"](side, spec["hand"]))
        if sx < 0:
            f.data.flip_normals()
        for g in list(f.vertex_groups):
            f.vertex_groups.remove(g)
        f.data.materials.clear()
        if skin:
            f.data.materials.append(skin)
        for p in f.data.polygons:
            p.use_smooth = True
        f.matrix_world = rig.matrix_world.copy()
        bpy.context.view_layer.update()
        mw = f.matrix_world.copy()
        f.parent, f.parent_type, f.parent_bone = rig, "BONE", side + "Hand"
        bpy.context.view_layer.update()
        f.matrix_world = mw
        fists[(b, side)] = f
        opens[(b, side)] = bpy.data.objects["%s_%sHand" % (b, side)]


def hands(shape):
    for key in fists:
        fists[key].hide_render = shape != "Fist"
        opens[key].hide_render = shape == "Fist"


def visible_hand(b, side):
    return fists[(b, side)] if not fists[(b, side)].hide_render else opens[(b, side)]


# ---------------------------------------------------------------- outfits
GEAR = {"TeeUnder", "TeeUnderWhite", "WornSinglet", "WornLeverBelt", "WornKneeSleeve", "WornWristWrap", "Sneakers", "SneakersSole"}
CLOTHES = {"Tee", "TeeWhite", "Shorts", "ShortsWhite", "Sneakers", "SneakersSole"}


def srgb(r, g, b):
    return tuple(((c / 255.0) ** 2.2) for c in (r, g, b)) + (1.0,)


def colour(item, rgba):
    for o in pieces:
        if item_of(o)[1] == item and o.data.materials:
            m = o.data.materials[0]
            m.diffuse_color = rgba
            if m.use_nodes:
                n = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
                if n:
                    n.inputs["Base Color"].default_value = rgba


def wear(items):
    for o in pieces:
        o.hide_render = item_of(o)[1] not in items


# ---------------------------------------------------------------- the contact fix (IK prototype)
targets, iks = {}, {}
for b, rig in rigs.items():
    for side in ("Left", "Right"):
        e = bpy.data.objects.new("%s_%sReach" % (b, side), None)
        coll.objects.link(e)
        targets[(b, side)] = e
        c = rig.pose.bones[side + "LowerArm"].constraints.new("IK")
        c.target, c.chain_count, c.use_tail, c.use_stretch, c.influence = e, 2, True, False, 0.0
        iks[(b, side)] = c


def world_mesh(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    verts, polys = [], []
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        base = len(verts)
        M = o.matrix_world
        verts += [M @ v.co for v in me.vertices]
        polys += [tuple(base + i for i in p.vertices) for p in me.polygons]
        ev.to_mesh_clear()
    return verts, polys


def tree(objs):
    v, p = world_mesh(objs)
    return BVHTree.FromPolygons(v, p), (sum(v, Vector()) / len(v) if v else Vector())


def solids(b):
    out = [bpy.data.objects[b + "_" + p] for p in ("UpperTorso", "LowerTorso", "LeftUpperLeg", "RightUpperLeg")]
    out += [o for o in pieces if item_of(o) == (b, "WornLeverBelt") and not o.hide_render]
    return out


def contact_fix(on, step=0.015, rounds=18):
    """Pushes overlapping hands apart (and out of the body and belt) by bending each arm with IK. Returns how far."""
    for key, c in iks.items():
        c.influence = 0.0
    bpy.context.view_layer.update()
    if not on:
        return {}
    moved = {}
    for b, rig in rigs.items():
        wrist0 = {s: rig.matrix_world @ rig.pose.bones[s + "LowerArm"].tail for s in ("Left", "Right")}
        off = {"Left": Vector(), "Right": Vector()}
        solid = solids(b)
        for _ in range(rounds):
            for s in ("Left", "Right"):
                targets[(b, s)].location = wrist0[s] + off[s]
                iks[(b, s)].influence = 1.0 if off[s].length > 0 else 0.0
            bpy.context.view_layer.update()
            tl, cl = tree([visible_hand(b, "Left")])
            tr, cr = tree([visible_hand(b, "Right")])
            ts, _c = tree(solid)
            push = False
            if tl.overlap(tr):
                d = (cl - cr)
                d = d.normalized() if d.length > 1e-6 else Vector((1, 0, 0))
                off["Left"] += d * step
                off["Right"] -= d * step
                push = True
            for s, t, c in (("Left", tl, cl), ("Right", tr, cr)):
                if t.overlap(ts):
                    loc, n, _i, _d = ts.find_nearest(c)
                    if loc is not None:
                        d = n if (c - loc).dot(n) >= 0 or True else -n
                        off[s] += d.normalized() * step
                        push = True
            if not push:
                break
        moved[b] = max(off["Left"].length, off["Right"].length)
    return moved


# ---------------------------------------------------------------- contact targets (where the hands should END UP)
def centre(o):
    v, _p = world_mesh([o])
    return sum(v, Vector()) / len(v)


def hand_size(b):
    return P["BUILDS"][b](L)["hand"]


def belt_point(b, side):
    """The belt's outer face on one side of the front (where a hand grips it to tighten it)."""
    belt = [o for o in pieces if item_of(o) == (b, "WornLeverBelt")]
    t, c = tree(belt)
    sx = 1 if side == "Left" else -1
    import math
    d = Vector((sx * math.cos(math.radians(55)), -math.sin(math.radians(55)), 0))
    origin = Vector((c.x, c.y, c.z)) + d * 4.0
    loc, n, _i, _d = t.ray_cast(origin, -d, 8.0)
    return (loc, n) if loc is not None else (c + d * 1.0, d)


def contact_targets(b, kind):
    """{side: where that hand's centre should be} for a contact move, from where the hands are now."""
    cl, cr = centre(visible_hand(b, "Left")), centre(visible_hand(b, "Right"))
    shape = "Fist" if not fists[(b, "Left")].hide_render else "Open"
    half = (0.20 if shape == "Fist" else 0.13) * hand_size(b)
    if kind == "together":                        # a clap, praying hands, fists pressed together
        mid, u = (cl + cr) / 2, (cl - cr)
        u = u.normalized() if u.length > 1e-6 else Vector((1, 0, 0))
        return {"Left": mid + u * half * 0.9, "Right": mid - u * half * 0.9}
    if kind == "chest":                           # palms flat on the chest
        ts, _c = tree([bpy.data.objects[b + "_UpperTorso"]] +
                      [o for o in pieces if item_of(o) == (b, "WornSinglet") and not o.hide_render])
        out = {}
        for s, c in (("Left", cl), ("Right", cr)):
            loc, n, _i, _d = ts.find_nearest(c)
            out[s] = loc + n * half * 0.9
        return out
    if kind == "belt":                            # fists on the belt's front, either side of the lever
        out = {}
        for s in ("Left", "Right"):
            loc, n = belt_point(b, s)
            out[s] = loc + n * half * 0.9
        return out
    return {}


def reach(b, rig, kind, rounds=8):
    """Bends each arm (two-bone IK, shoulder kept) until its hand sits on its contact target."""
    wrist0 = {s: rig.matrix_world @ rig.pose.bones[s + "LowerArm"].tail for s in ("Left", "Right")}
    off = {"Left": Vector(), "Right": Vector()}
    for _ in range(rounds):
        want = contact_targets(b, kind)
        if not want:
            return off
        for s in ("Left", "Right"):
            off[s] += (want[s] - centre(visible_hand(b, s))) * 0.8
            targets[(b, s)].location = wrist0[s] + off[s]
            iks[(b, s)].influence = 1.0
        bpy.context.view_layer.update()
    return off


# ---------------------------------------------------------------- hand shapes over time (HandShapeConfig)
FIST_SPANS = {"Station_Squat": [(0, 99)], "Station_Bench": [(0, 99)], "Station_Deadlift": [(0, 99)],
              "Emote_BeltTighten": [(0.3, 2.2)], "Emote_DoubleBiceps": [(0, 99)],
              "Celebrate_CrouchRoarJump": [(0.25, 3.6)], "Celebrate_DisbeliefPrayer": [(1.85, 2.5), (6.4, 7.5)]}


def shape_at(anim, t):
    if anim is None:
        return "Open"
    return "Fist" if any(a <= t < b for a, b in FIST_SPANS.get(anim, [])) else "Open"


def closest_time(anim, rig, within=None):
    """The keyframe where this rig's two hands come closest together (a clap's meeting moment)."""
    best, bt = None, 0.0
    for t, poses in G["read_anim"](anim):
        if within and not (within[0] <= t <= within[1]):
            continue
        G["pose_rig"](rig, poses)
        a = rig.pose.bones["LeftLowerArm"].tail
        c = rig.pose.bones["RightLowerArm"].tail
        if best is None or (a - c).length < best:
            best, bt = (a - c).length, t
    return bt


# ---------------------------------------------------------------- pictures
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading
sh.light, sh.color_type, sh.show_backface_culling, sh.show_cavity = "STUDIO", "TEXTURE", True, True
if sc.world is None:
    sc.world = bpy.data.worlds.new("W")
sc.world.color = (0.16, 0.17, 0.2)
cd = bpy.data.cameras.new("Check04Cam")
cd.type = "ORTHO"
cam = bpy.data.objects.new("Check04Cam", cd)
coll.objects.link(cam)
sc.camera = cam
CENTRE = Vector((SPACING, 0, 3.0))


def shoot(name, direction, scale=13.0, res=(1500, 800), target=CENTRE):
    cd.ortho_scale = scale
    sc.render.resolution_x, sc.render.resolution_y = res
    cam.location = target + Vector(direction).normalized() * 30
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("[Check04] shot", name)


def lineup(tag):
    for rig in rigs.values():
        G["rest_rig"](rig)
    hands("Open")
    contact_fix(False)
    for view, d in {"Front": (0, -1, 0.05), "Threequarter": (-0.75, -1, 0.15), "Back": (0, 1, 0.05)}.items():
        shoot("%s_%s" % (tag, view), d)
    for b, rig in rigs.items():
        for other in rigs.values():
            other.location.y = 0 if other is rig else 200
        bpy.context.view_layer.update()
        shoot("%s_Side_%s" % (tag, b), (1, 0, 0.05), scale=7.5, res=(600, 800), target=Vector((rig.location.x, 0, 3.0)))
    for rig in rigs.values():
        rig.location.y = 0
    bpy.context.view_layer.update()


GREY, BLACK, WHITE = srgb(128, 131, 138), srgb(24, 24, 27), srgb(232, 232, 228)
colour("TeeUnder", BLACK)       # the photos: a black tee under the singlet
colour("Sneakers", srgb(30, 30, 34))
wear(GEAR)
lineup("Gear")
colour("Tee", GREY)
colour("Shorts", BLACK)
colour("Sneakers", WHITE)
wear(CLOTHES)
lineup("Clothes")
colour("Sneakers", srgb(30, 30, 34))
colour("TeeUnder", BLACK)       # (the tee and the under-tee share one preview material)
wear(GEAR)

POSES = [("SquatBottom", "Station_Squat", 1.9, None), ("BenchChest", "Station_Bench", 2.0, None),
         ("DeadliftBottom", "Station_Deadlift", 1.6, None), ("BeltTighten", "Emote_BeltTighten", 1.1, "belt"),
         ("DoubleBiceps", "Emote_DoubleBiceps", None, None),
         ("CrouchRoar", "Celebrate_CrouchRoarJump", ("closest", (0.25, 3.6)), "together"),
         ("ChalkClap", "Emote_ChalkClap", ("closest", None), "together"),
         ("OverheadClap", "Entrance_Hype_OverheadClap", ("closest", None), "together"),
         ("ChestSlap", "Entrance_Hype_ChestSlap", None, "chest"),
         ("Prayer", "Celebrate_DisbeliefPrayer", ("closest", (0.0, 1.8)), "together"),
         ("ArmsUp", "Celebrate_ArmsUpBounce", None, None), ("Walk", "Entrance_Walk_Swagger", None, None)]
CLOSE = {"SquatBottom", "BenchChest", "DeadliftBottom"}
report = []
for name, anim, t, kind in POSES:
    times = {}
    for b, rig in rigs.items():
        if isinstance(t, tuple):
            times[b] = closest_time(anim, rig, t[1])
        else:
            times[b] = t if t is not None else G["extreme_time"](anim)
        G["pose_rig"](rig, G["anim_at"](anim, times[b]))
    hands(shape_at(anim, times["Muscular"]))
    contact_fix(False)
    shoot("Before_" + name, (-16, -22, 6), scale=13.5, res=(1500, 700), target=Vector((SPACING, 0, 2.8)))
    for b, rig in rigs.items():
        if kind:
            reach(b, rig, kind)
    if not kind:
        contact_fix(True)          # no contact meant: only keep hands out of each other, the body and the belt
    report.append((name, {b: round(v, 2) for b, v in times.items()}, shape_at(anim, times["Muscular"]), kind))
    shoot("After_" + name, (-16, -22, 6), scale=13.5, res=(1500, 700), target=Vector((SPACING, 0, 2.8)))
    if kind:
        shoot("Close_" + name, (-0.35, -1, 0.25), scale=11.5, res=(1500, 800), target=Vector((SPACING, 0, 3.4)))
for r in report:
    print("[Check04] pose", r)
