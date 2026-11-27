# Builds HeldMedal_Open: the referee's held medal (build_worn_medal_01.py's HeldMedal_Ribbon) stretched OPEN to go over
# a bowed head, for the podium clip art/animations/Ceremony_Ref_PlaceMedal.rbxmx (ceremony_animations.py). The rigid
# HeldMedal_Ribbon opens only ~0.45 front-to-back; over t ~0.9-1.5 the lifter's bowed head sits between and below the
# grips (in the held medal's frame: from 0.33 in FRONT of the grip line to 1.65 behind it, its crown up to 0.33 above
# the grips) and the ribbon passed 0.2-0.4 through it (D:\ClaudeScratch\ceremony\medal_v7).
#
# The same ribbon (same length 5.12 as HeldMedal_Ribbon / Fit's worn loop, same width, thickness, taper and colours),
# the same two hold points (the grip line; the ribbon runs through each fist), shaped as when held up and pulled open:
#   - the back strand pulled back and UP into a wide arch over and behind the crown (a semi-ellipse from fist to fist,
#     its top ARCH_UP above the grips and ARCH_BACK behind them; its flat face toward the opening, like a hoop);
#   - the front strands straight from the fists to the ring FRONT_Z in front of the grips (in front of the face), the
#     disc hanging from the ring facing the referee. With the length fixed, the ring rides higher than the held
#     medal's (0.68 below the grips instead of 1.10): a bigger opening costs length the front V had.
# The shape was searched against the six lifters' stand-in heads over the clip (D:\ClaudeScratch\medal\open\design_open.py)
# and then checked with the real meshes in the pair check (D:\ClaudeScratch\medal\open\run_open_qa.py).
#
#   blender -b art/blender/WornMedal_01.blend --python art/scripts/build_held_medal_open_01.py
# (run AFTER build_worn_medal_01.py, which rewrites WornMedal_01.blend without this piece). Adds/replaces the object
# HeldMedal_Open (+ Preview copies of the disc/text where they hang), saves the file, exports
# art/exports/HeldMedal_Open.glb and writes "heldOpen" into art/exports/WornMedal_01_fit.json.
import importlib
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
EXPORTS = os.path.join(ROOT, "art", "exports")
sys.path.insert(0, SCRIPTS)
import prop_helpers as H  # noqa: E402

importlib.reload(H)

# the same ribbon and disc numbers as build_worn_medal_01.py
L_TOTAL = 5.12
HX = 0.75
RIB_W, RIB_T, RIB_W_TIP, TAPER, TIP_R = 0.20, 0.025, 0.05, 0.35, 0.035
RING_R, RING_Z = 0.055, 0.30 + 0.025
STEP = 0.025
# the open shape (Roblox axes in the hold-midpoint frame: y up, -z toward the referee / the medal's face)
ARCH_UP, ARCH_BACK = 0.70, 0.60     # the back strand's top: this far above and behind the grip line
FRONT_Z = -0.70                     # the front strands and the ring: this far in front of the grip line
ORIGIN = Vector((-6.0, -3.0, 4.4))  # where it stands in the .blend (beside the HeldMedal_Ribbon)


def log(*a):
    print("[HeldOpen]", *a, flush=True)


def B_(v):
    """Roblox (x right, y up, -z front) -> Blender (x left, -y front, z up)."""
    return Vector((-v.x, v.z, v.y))


def resample(pts, step, closed=True):
    seq = pts + ([pts[0]] if closed else [])
    d = [0.0]
    for p, q in zip(seq, seq[1:]):
        d.append(d[-1] + (q - p).length)
    total = d[-1]
    n = max(8, int(round(total / step)))
    out, j = [], 0
    for i in range(n):
        t = total * i / n
        while j < len(d) - 2 and d[j + 1] < t:
            j += 1
        k = (t - d[j]) / max(1e-9, d[j + 1] - d[j])
        out.append(seq[j].lerp(seq[j + 1], k))
    return out, total


def loop_len(pts):
    return sum((pts[(i + 1) % len(pts)] - pts[i]).length for i in range(len(pts)))


def centreline(front_z, up, back, foot_y):
    """Roblox-frame closed loop: the turn through the ring (index 0 its bottom), up the +x strand to the +x fist, the
    arch to the -x fist, down the -x strand. The corners at the fists rounded a little (the ribbon over the fingers)."""
    turn = [Vector((TIP_R * math.sin(math.radians(a)), foot_y - TIP_R * math.cos(math.radians(a)), front_z))
            for a in range(0, 91, 15)]                                   # bottom -> the +x strand's foot
    hp, hm = Vector((HX, 0, 0)), Vector((-HX, 0, 0))
    up_strand = [turn[-1].lerp(hp, i / 40) for i in range(1, 40)]
    arch = [Vector((HX * math.cos(math.pi * s), up * math.sin(math.pi * s), back * math.sin(math.pi * s)))
            for s in (i / 60 for i in range(0, 61))]
    down_strand = [hm.lerp(Vector((-TIP_R, foot_y, front_z)), i / 40) for i in range(1, 40)]
    right_turn = [Vector((-p.x, p.y, p.z)) for p in reversed(turn[1:])]
    pts = turn + up_strand + arch + down_strand + right_turn
    # round the fists' corners: a few passes of neighbour averaging near them only
    for _ in range(6):
        new = list(pts)
        for i, p in enumerate(pts):
            if min((p - hp).length, (p - hm).length) < 0.09:
                new[i] = p * 0.5 + (pts[i - 1] + pts[(i + 1) % len(pts)]) * 0.25
        pts = new
    return pts


def build_loop():
    """The front V's foot height that makes the loop exactly L_TOTAL long (halving)."""
    lo, hi = -2.5, -0.05
    for _ in range(50):
        mid = (lo + hi) / 2
        ln = loop_len(centreline(FRONT_Z, ARCH_UP, ARCH_BACK, mid))
        lo, hi = (lo, mid) if ln < L_TOTAL else (mid, hi)    # (a lower foot = a longer loop)
    foot = (lo + hi) / 2
    pts = centreline(FRONT_Z, ARCH_UP, ARCH_BACK, foot)
    return pts, foot


def width_at(d):
    t = min(1.0, max(0.0, d / TAPER))
    return RIB_W_TIP + (RIB_W - RIB_W_TIP) * t * t * (3 - 2 * t)


pts_r, foot_y = build_loop()
tip_y = foot_y - TIP_R
pts = [B_(p) for p in pts_r]
pts, total = resample(pts, STEP)
N = len(pts)
# frames: rotation-minimising from the ring (flat face toward the referee there), twist spread round the loop
tan = [(pts[(i + 1) % N] - pts[i - 1]).normalized() for i in range(N)]
n0 = Vector((0, -1, 0))
nrm = [(n0 - tan[0] * n0.dot(tan[0])).normalized()]
for i in range(1, N):
    v = nrm[-1] - tan[i] * nrm[-1].dot(tan[i])
    nrm.append(v.normalized())
closing = (n0 - tan[0] * n0.dot(tan[0])).normalized()
last = (nrm[-1] - tan[0] * nrm[-1].dot(tan[0])).normalized()
twist = last.angle(closing)
if last.cross(closing).dot(tan[0]) < 0:
    twist = -twist
for i in range(N):                      # spread the closing twist evenly
    ang = twist * i / N
    t = tan[i]
    c, s = math.cos(ang), math.sin(ang)
    v = nrm[i]
    nrm[i] = (v * c + t.cross(v) * s + t * t.dot(v) * (1 - c)).normalized()
d = [0.0]
for p, q in zip(pts, pts[1:]):
    d.append(d[-1] + (q - p).length)
dist = [min(x, total - x) for x in d]
secs = []
for i in range(N):
    t = tan[i]
    n = (nrm[i] - t * nrm[i].dot(t)).normalized()
    w = t.cross(n).normalized()
    hw = width_at(dist[i]) / 2
    p = pts[i]
    secs.append([p + w * hw - n * RIB_T / 2, p + w * hw + n * RIB_T / 2, p - w * hw + n * RIB_T / 2, p - w * hw - n * RIB_T / 2])


def tube(bm):
    verts = [[bm.verts.new(v + ORIGIN) for v in s] for s in secs]
    for i in range(N):
        a, b2 = verts[i], verts[(i + 1) % N]
        for k in range(4):
            bm.faces.new((a[k], b2[k], b2[(k + 1) % 4], a[(k + 1) % 4]))
    bm.normal_update()
    vol = sum(f.verts[0].co.dot(f.verts[j].co.cross(f.verts[j + 1].co)) / 6
              for f in bm.faces for j in range(1, len(f.verts) - 1))
    if vol < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])


ribbon_mat = bpy.data.materials.get("WM_Red") or H.material("WM_Red", (0.578, 0.013, 0.019), 0.0, 0.45)
Bld = H.Builder("WornMedal")
open_obj = Bld.piece("HeldMedal_Open", ribbon_mat, tube, smooth=True)
rib_c = open_obj.location - ORIGIN                     # its mesh's bounds centre in the hold-midpoint frame (Blender)

# the disc and the text where they hang (the shared meshes; Preview copies only)
disc, text = bpy.data.objects["WornMedal_Disc"], bpy.data.objects["WornMedal_Text"]
fit_path = os.path.join(EXPORTS, "WornMedal_01_fit.json")
fit = json.load(open(fit_path))
held = fit["held"]
# the disc mesh's own bounds centre relative to its circle centre (Roblox): from the held data
disc_off = Vector(held["Disc"]) - Vector(held["discCentre"])
text_off = Vector(held["Text"]) - Vector(held["discCentre"])
disc_c_r = Vector((0, tip_y - RING_R * 0.45 - RING_Z, FRONT_Z))      # Roblox, hold-midpoint frame
pv = bpy.data.collections.get("Preview") or bpy.data.collections.new("Preview")
if pv.name not in bpy.context.scene.collection.children:
    bpy.context.scene.collection.children.link(pv)
for name, src_, off in (("Disc", disc, disc_off), ("Text", text, text_off)):
    nm = "Preview_HeldMedalOpen_" + name
    old = bpy.data.objects.get(nm)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    o = bpy.data.objects.new(nm, src_.data)
    o.location = ORIGIN + B_(disc_c_r + off)
    pv.objects.link(o)


def rel(p_r):
    v = p_r - Vector((-rib_c.x, rib_c.z, rib_c.y))      # Roblox, from the part's centre
    return [round(v.x, 4), round(v.y, 4), round(v.z, 4)]


mid_open = rel(Vector((0, 0, 0)))
fit["heldOpen"] = {
    "space": "HeldMedal_Open MeshPart's own space (its mesh's bounds centre, Roblox axes, the medal's face toward -z)",
    "holdPointPlusX": rel(Vector((HX, 0, 0))), "holdPointMinusX": rel(Vector((-HX, 0, 0))), "holdMidpoint": mid_open,
    "discCentre": rel(disc_c_r), "Disc": rel(disc_c_r + disc_off), "Text": rel(disc_c_r + text_off),
    "fromHeldRibbon": [round(a - b, 4) for a, b in zip(held["holdMidpoint"], mid_open)],
    "loopLength": round(total, 3), "ringTipBelowGrips": round(-tip_y, 3), "frontZ": FRONT_Z,
    "archUp": ARCH_UP, "archBack": ARCH_BACK, "openingDepth": round(ARCH_BACK - FRONT_Z - RIB_T, 3),
}
json.dump(fit, open(fit_path, "w"), indent=1)
log("loop %.3f (target %.2f), ring tip %.3f below the grips, %d sections, closing twist %.1f deg" % (
    total, L_TOTAL, -tip_y, N, math.degrees(twist)))
log("heldOpen", fit["heldOpen"])
log("tris HeldMedal_Open %d" % sum(len(p.vertices) - 2 for p in open_obj.data.polygons))

bpy.ops.wm.save_mainfile()
loc = open_obj.location.copy()
open_obj.location = (0, 0, 0)
bpy.ops.object.select_all(action="DESELECT")
open_obj.select_set(True)
bpy.context.view_layer.objects.active = open_obj
bpy.ops.export_scene.gltf(filepath=os.path.join(EXPORTS, "HeldMedal_Open.glb"), export_format="GLB",
                          use_selection=True, export_apply=True)
open_obj.location = loc
bpy.ops.wm.save_mainfile()
log("exported HeldMedal_Open.glb; DONE")
