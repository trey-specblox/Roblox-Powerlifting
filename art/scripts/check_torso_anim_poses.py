# Pose check for the TORSO-rig animations (CHARACTER_ART_DIRECTION.md §11 Phase 1, 2026-11-13): every animation in
# art/animations re-made for lifter_heights.py's "torso" table, played on the new bodies in
# art/blender/CartoonBodies_04_Rigged.blend (rigs <Build>Rig, parts <Build>_<Part>; joints = the torso table).
#   - each station rep at several moments (squat stand / half / bottom, bench lockout / chest lying on a bench, deadlift
#     grip / lockout) with the bar where the hands hold it (or where it rests);
#   - the setups' key moments; every other animation at its hardest moment (gear_fit_03.extreme_time);
#   - the game's hand shapes (HandShapeConfig: FISTS while gripping the bar and in its Fist spans; open elsewhere);
#   - numbers per moment and build: the deepest a hand goes into the torso, the two hands' overlap, the lowest foot
#     point below the floor, and for the squat the bar's distance from the upper back.
# READ-ONLY: the .blend is opened and NOT saved. Pictures (contact sheets) go to <out_dir>.
#   blender -b art/blender/CartoonBodies_04_Rigged.blend --python art/scripts/check_torso_anim_poses.py -- <out_dir>
#   (env TORSO_ANIMS = another animation folder; default art/animations)
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
OUT = sys.argv[sys.argv.index("--") + 1]
TILES = os.path.join(OUT, "tiles")
os.makedirs(TILES, exist_ok=True)
ANIMS = os.environ.get("TORSO_ANIMS") or os.path.join(ROOT, "art", "animations")
ONLY = os.environ.get("TORSO_ONLY", "")          # (comma-separated sheet names, for a quick re-run)

G = {"__name__": "gear_fit_03"}
exec(open(os.path.join(SCRIPTS, "gear_fit_03.py")).read(), G)
G["ANIMS"] = ANIMS
src = open(os.path.join(SCRIPTS, "build_cartoon_rig_02.py")).read().split("\ncoll = collection()\nRESULTS")[0]
R = {"__name__": "rig02_lib"}
exec(src, R)                                   # (only its hand meshes are used: make_hand, hand_space)
P = {"__name__": "body04_lib", "PROTO04_AS_LIBRARY": True}
exec(open(os.path.join(SCRIPTS, "build_cartoon_body_04.py")).read(), P)
L = P["TORSO_TALL"]
BUILDS = [b for b in ("Skinny", "Heavy", "Muscular") if bpy.data.objects.get(b + "Rig")]
rigs = {b: bpy.data.objects[b + "Rig"] for b in BUILDS}
home = {b: r.matrix_world.copy() for b, r in rigs.items()}
coll = bpy.data.collections.new("CheckTorso")
bpy.context.scene.collection.children.link(coll)


def material(name, rgba):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = rgba
    return m


# ---------------------------------------------------------------- fists (HandShapeConfig's swap) on each hand bone
skin = bpy.data.materials.get("CartoonSkin")
fists, opens = {}, {}
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

# HandShapeConfig's Fist spans (Point / ThumbsUp are drawn open here). (from, to, sides)
FIST = {"Station_Squat": [(0, 99, "LR")], "Station_Bench": [(0, 99, "LR")], "Station_Deadlift": [(1.6, 4.3, "LR")],
        "Celebrate_ChalkClapPump": [(1.6, 2.45, "R")], "Celebrate_ExitFistPump": [(0.15, 1.5, "R")],
        "Celebrate_FistSalute": [(0.2, 1.9, "R")], "Celebrate_ReliefRoar": [(0.25, 1.6, "LR")],
        "Celebrate_LightsArmsUp": [(1.45, 3.1, "LR")], "Celebrate_RackSideRoar": [(0.2, 2.3, "LR")],
        "Celebrate_CrouchRoarJump": [(0.25, 3.6, "LR")], "Celebrate_WingspanCrunch": [(2.45, 3.6, "LR")],
        "Celebrate_DisbeliefPrayer": [(1.85, 2.5, "LR"), (6.4, 7.5, "LR")],
        "Celebrate_WingspanBiceps": [(0.2, 0.9, "LR"), (3.95, 5.2, "LR")], "Celebrate_BowAndRise": [(3.6, 4.95, "LR")],
        "Celebrate_RecordJumpRoar": [(5.4, 6.6, "LR"), (7.2, 7.75, "R")], "Celebrate_CrowdPleaser": [(0.2, 1.25, "R")],
        "Emote_BeltTighten": [(0.3, 2.2, "LR")], "Emote_DoubleBiceps": [(0, 99, "LR")],
        "Emote_MostMuscular": [(0, 99, "LR")], "Setup_Squat": [(1.2, 99, "LR")], "Setup_Bench": [(4.6, 99, "LR")],
        "Setup_Deadlift": [(2.9, 99, "LR")]}


def set_hands(anim, t):
    for (b, side), f in fists.items():
        closed = any(a <= t < z and side[0] in s for a, z, s in FIST.get(anim, []))
        f.hide_render = not closed
        opens[(b, side)].hide_render = closed


def visible_hand(b, side):
    return fists[(b, side)] if not fists[(b, side)].hide_render else opens[(b, side)]


# ---------------------------------------------------------------- props: a bar per build, a bench, the floor
def box(name, size, rgba):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(material(name + "Mat", rgba))
    for c in o.users_collection:
        c.objects.unlink(o)
    coll.objects.link(o)
    return o


def bar_object(name):
    steel = material("CheckBarSteel", (0.55, 0.56, 0.6, 1))
    plate = material("CheckBarPlate", (0.75, 0.12, 0.1, 1))
    parts = []
    # (shortened to 4.6 with small end discs so neighbouring builds stay clear; the real bar is 7.2 with big plates)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.07, depth=4.6, vertices=16, rotation=(0, math.pi / 2, 0))
    parts.append(bpy.context.active_object)
    parts[-1].data.materials.append(steel)
    for x in (-2.2, 2.2):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.32, depth=0.2, vertices=24, location=(x, 0, 0), rotation=(0, math.pi / 2, 0))
        parts.append(bpy.context.active_object)
        parts[-1].data.materials.append(plate)
    o = parts[0]
    o.name = name
    for i, p in enumerate(parts):
        for c in p.users_collection:
            c.objects.unlink(p)
        coll.objects.link(p)
        if i:
            p.name = "%s_Plate%d" % (name, i)
            p.parent = o                     # (the plates ride with the shaft: its own axis, local Z, is the bar's)
            p.location = (0, 0, 2.2 if i == 1 else -2.2)
            p.rotation_euler = (0, 0, 0)
    return o


bpy.ops.object.select_all(action="DESELECT")
bars = {b: bar_object(b + "_CheckBar") for b in BUILDS}
benches = {b: box(b + "_CheckBench", (1.0, 4.0, 1.2), (0.12, 0.12, 0.14, 1)) for b in BUILDS}
floor = box("CheckFloor", (40, 30, 0.02), (0.34, 0.35, 0.38, 1))
floor.location = (4.6, 6.0, -0.011)
floor.hide_render = False


def hand_centre(b, side):
    o = visible_hand(b, side)
    dg = bpy.context.evaluated_depsgraph_get()
    ev = o.evaluated_get(dg)
    me = ev.to_mesh()
    c = sum((o.matrix_world @ v.co for v in me.vertices), Vector()) / max(1, len(me.vertices))
    ev.to_mesh_clear()
    return c


def tree(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    verts, polys = [], []
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        base = len(verts)
        verts += [o.matrix_world @ v.co for v in me.vertices]
        polys += [tuple(base + i for i in p.vertices) for p in me.polygons]
        ev.to_mesh_clear()
    return BVHTree.FromPolygons(verts, polys), verts


def measure(b, bar_shown, on_back=False):
    """Numbers for one build in its current pose. (The body parts are open where they are split at the joints, so
    "inside" can't be judged by distance: these are surface-crossing tests.)
      hand_cuts_torso   a hand's surface crosses the torso's (the hand goes into the body)
      hands_cross       the two hands' surfaces cross (claps and prayer touch on purpose)
      feet_below_floor  how far the lowest foot point is under the floor (z 0)
      bar_gap           the bar shaft's centre to the nearest torso surface; bar_cuts: the shaft crosses the torso"""
    torso, _v = tree([bpy.data.objects[b + "_UpperTorso"], bpy.data.objects[b + "_LowerTorso"]])
    tl, _l = tree([visible_hand(b, "Left")])
    tr, _r = tree([visible_hand(b, "Right")])
    out = {"hand_cuts_torso": bool(tl.overlap(torso) or tr.overlap(torso)), "hands_cross": bool(tl.overlap(tr))}
    _f, fv = tree([bpy.data.objects[b + "_LeftFoot"], bpy.data.objects[b + "_RightFoot"]])
    out["feet_below_floor"] = round(max(0.0, -min(v.z for v in fv)), 3)
    if bar_shown:
        shaft, _s = tree([bars[b]])
        loc, _n, _i, d = torso.find_nearest(bars[b].location)
        out["bar_gap"] = round(d, 3) if loc is not None else 9.0
        out["bar_cuts"] = bool(shaft.overlap(torso))
        if not on_back:
            return out
        # how deep the bar's centre sits inside the body, seen from behind (a squat bar on the upper back): a ray from
        # behind along the body's front axis; > 0 = the centre is that far in front of the back's surface (sunk in)
        fwd = (rigs[b].matrix_world.to_3x3() @ Vector((0, -1, 0))).normalized()
        start = bars[b].location - fwd * 4.0
        hit, _n, _i, _d = torso.ray_cast(start, fwd, 8.0)
        out["bar_sunk"] = round((bars[b].location - hit).dot(fwd), 3) if hit is not None else -9.0
    return out


# ---------------------------------------------------------------- posing one moment
TO_B = G["TO_B"]
BENCH_LIE = Matrix.Translation((0, 0, 1.7)) @ Matrix.Rotation(math.radians(-90), 4, "X") @ Matrix.Translation((0, 0, -3.0))


STAGGER = {}                                   # (side views: each build moved back so they stand apart)


def pose_moment(anim, t, bar_mode):
    """Poses every build at time t of anim. bar_mode: None, "held" (the bar at the hands' midpoint), "floor"
    (deadlift bar resting on the floor in front), "bench" (lying on the bench)."""
    frames = G["anim_at"](anim, t)
    set_hands(anim, t)
    for b, rig in rigs.items():
        rig.matrix_world = Matrix.Translation(STAGGER.get(b, Vector())) @ home[b] @ (BENCH_LIE if bar_mode in ("bench", "bench_rest") else Matrix.Identity(4))
        G["pose_rig"](rig, frames)
        bench = benches[b]
        bench.hide_render = bar_mode not in ("bench", "bench_rest")
        if not bench.hide_render:      # the pad under the hips and back (the head toward +Y lying down)
            bench.location = rig.matrix_world.translation * Vector((1, 1, 0)) + Vector((0, 0.8, 0.6))
        bar = bars[b]
        bar.hide_render = bar_mode is None
        for plate in bar.children:
            plate.hide_render = bar.hide_render
        if bar_mode in ("held", "bench"):
            bar.location = (hand_centre(b, "Left") + hand_centre(b, "Right")) / 2
        elif bar_mode == "floor":
            bar.location = rig.matrix_world.translation * Vector((1, 1, 0)) + Vector((0, -0.6, 1.0))
    bpy.context.view_layer.update()


# ---------------------------------------------------------------- pictures
sc = bpy.context.scene
try:
    sc.render.engine = "BLENDER_WORKBENCH"
except TypeError as e:
    print("engine", e)
sh = sc.display.shading
sh.light, sh.color_type, sh.show_backface_culling, sh.show_cavity = "STUDIO", "MATERIAL", True, True
sh.cavity_type = "SCREEN"
sh.background_type = "VIEWPORT"
sh.background_color = (0.16, 0.17, 0.2)
sc.render.image_settings.file_format = "PNG"
cd = bpy.data.cameras.new("CheckTorsoCam")
cd.type = "ORTHO"
cd.clip_end = 200
cam = bpy.data.objects.new("CheckTorsoCam", cd)
coll.objects.link(cam)
sc.camera = cam
label_curve = bpy.data.curves.new("CheckTorsoLabel", "FONT")
label = bpy.data.objects.new("CheckTorsoLabel", label_curve)
label_curve.size = 0.42
label.data.materials.append(material("CheckLabel", (0.95, 0.95, 0.9, 1)))
coll.objects.link(label)
label.parent = cam
TILE = (900, 520)
SCALE = 14.5


def shoot(path, text, target=Vector((4.6, 0, 2.7)), direction=(-0.42, -1, 0.24)):
    cd.ortho_scale = SCALE
    sc.render.resolution_x, sc.render.resolution_y = TILE
    cam.location = target + Vector(direction).normalized() * 40
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    label_curve.body = text
    label.location = (-SCALE / 2 + 0.3, SCALE * TILE[1] / TILE[0] / 2 - 0.65, -5)
    label.rotation_euler = (0, 0, 0)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def sheet(name, tiles, cols=3):
    if tiles:
        G["contact_sheet"]([(None, None, p) for p in tiles], os.path.join(OUT, name + ".png"), cols)
        print("[CheckTorso] sheet", os.path.join(OUT, name + ".png"))


# ---------------------------------------------------------------- the moments
STATION = [("Station_Squat", 0.0, "held", "stand"), ("Station_Squat", 1.25, "held", "half way"),
           ("Station_Squat", 2.0, "held", "bottom"), ("Station_Bench", 0.0, "bench", "lockout"),
           ("Station_Bench", 2.1, "bench", "on the chest"), ("Station_Deadlift", 1.6, "held", "grip at the floor"),
           ("Station_Deadlift", 3.1, "held", "lockout"), ("Station_Deadlift", 0.5, "floor", "before the grip"),
           ("Setup_Squat", 1.759, "held", "duck under the bar"), ("Setup_Squat", 2.6, "held", "under the bar"),
           ("Setup_Squat", 3.1, "held", "unrack"), ("Setup_Bench", 5.4, "bench", "unrack (lying)"),
           ("Setup_Deadlift", 3.3, "floor", "set at the bar")]
names = sorted(f[:-6] for f in os.listdir(ANIMS) if f.endswith(".rbxmx") and f != "R15_BlockRig.rbxmx")
families = {"Celebrations": "Celebrate_", "Emotes_Chalk_Shirt": ("Emote_", "Chalk_", "BenchShirt_"),
            "Entrances": "Entrance_", "Fails": "Fail_"}
report = []


def run_moment(anim, t, mode, note, view=None):
    STAGGER.clear()
    if view and view[0] == "side":
        STAGGER.update({b: Vector((-4.6 * i, 3.2 * i - 3.2, 0)) for i, b in enumerate(BUILDS)})
    pose_moment(anim, t, mode)
    nums = {b: measure(b, mode in ("held", "bench", "floor"), "Squat" in anim and mode == "held") for b in BUILDS}
    report.append((anim, round(t, 2), note, nums))
    flags = []
    for b, n in nums.items():
        if n["hand_cuts_torso"]:
            flags.append("%s hand into the body" % b[:3])
        if n.get("bar_cuts") and n.get("bar_sunk", -9) > 0.0:
            flags.append("%s bar %.2f into the body" % (b[:3], n["bar_sunk"]))
        elif n.get("bar_cuts"):
            flags.append("%s bar touches the body" % b[:3])
        if n["feet_below_floor"] > 0.08:
            flags.append("%s feet %.2f under floor" % (b[:3], n["feet_below_floor"]))
    text = "%s  t %.2f  %s" % (anim, t, note) + ("\n" + "; ".join(flags) if flags else "")
    if view:
        return shoot(os.path.join(TILES, "%s_%.2f_%s.png" % (anim, t, view[0])), text, view[2], view[1])
    return shoot(os.path.join(TILES, "%s_%.2f.png" % (anim, t)), text)


if not ONLY or "Stations" in ONLY:
    tiles = [run_moment(a, t, m, n) for a, t, m, n in STATION]
    # the squat bar on the upper back, from behind and above (one build at a time is clearer: all three, closer)
    tiles.append(run_moment("Station_Squat", 0.0, "held", "stand, from behind", ("back", (0.25, 1, 0.55), Vector((4.6, 0, 4.2)))))
    tiles.append(run_moment("Station_Squat", 0.0, "held", "stand, from the side", ("side", (1, 0.0, 0.08), Vector((0, 0, 3.0)))))
    tiles.append(run_moment("Station_Squat", 2.0, "held", "bottom, from the side", ("side", (1, 0.0, 0.08), Vector((0, 0, 2.2)))))
    tiles.append(run_moment("Station_Bench", 2.1, "bench", "on the chest, from the side", ("side", (1, 0.0, 0.08), Vector((0, 0.5, 2.2)))))
    tiles.append(run_moment("Station_Deadlift", 1.6, "held", "grip, from the side", ("side", (1, 0.0, 0.08), Vector((0, 0, 2.2)))))
    sheet("TorsoAnim_Stations", tiles)
for fam, prefix in families.items():
    if ONLY and fam not in ONLY:
        continue
    tiles = []
    for anim in names:
        if not anim.startswith(prefix):
            continue
        t = G["extreme_time"](anim)
        tiles.append(run_moment(anim, t, None, "hardest moment"))
    sheet("TorsoAnim_" + fam, tiles)

for b, rig in rigs.items():
    rig.matrix_world = home[b]
    G["rest_rig"](rig)
for anim, t, note, nums in report:
    print("[CheckTorso] %-34s t %5.2f %-20s %s" % (anim, t, note, "  ".join(
        "%s: hand-cuts %d hands-cross %d feet %.2f%s" % (b[:3], n["hand_cuts_torso"], n["hands_cross"], n["feet_below_floor"],
                                                        (" bar gap %.2f cuts %d sunk %.2f" % (n["bar_gap"], n["bar_cuts"], n.get("bar_sunk", -9.0)))
                                                        if "bar_gap" in n else "")
        for b, n in nums.items())))
print("[CheckTorso] DONE (nothing saved)")
