# Checks for the v5 gear (build_cartoon_gear_05.py -> art/blender/CartoonGear_05.blend), read-only (the .blend is NOT
# saved): per build and outfit, gear_fit_03.clearance at rest and in the re-made lift / walk / raise poses (art/animations,
# the torso-tall rig), and the picture set: every outfit on all six builds from the front, back and both sides (backface
# culling on, as Roblox draws), plus the meet gear in the squat bottom, bench and deadlift bottom with the game's grip
# hands.
#   blender -b art/blender/CartoonGear_05.blend --python art/scripts/check_gear_05.py -- <out_dir> [only]
# only: "clearance" or "pictures" (default both). Writes <out_dir>/Gear05_*.png and <out_dir>/gear05_clearance.txt.
import os
import sys

import bpy

ROOT = r"D:\Powerlifting Roblox"
SCRIPTS = os.path.join(ROOT, "art", "scripts")
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else os.path.join(ROOT, "art", "previews")
ONLY = argv[1] if len(argv) > 1 else ""
TMP = os.path.join(r"D:\ClaudeScratch", "gear05_shots")
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)
G = {"__name__": "gear_fit_03"}
exec(open(os.path.join(SCRIPTS, "gear_fit_03.py")).read(), G)
G["ANIMS"] = os.path.join(ROOT, "art", "animations")
ORDER = ("Skinny", "SkinnyFat", "Fat", "Fit", "Muscular", "BigBuff")
BUILDS = [b for b in ORDER if bpy.data.objects.get(b + "Rig")]
PARTS = G["PARTS"]

OUTFITS = {
    "MeetGear": ("TeeUnder", "WornSinglet", "WornLeverBelt", "WornKneeSleeve", "WornWristWrap", "Sneakers"),
    "SquatSuit": ("TeeUnder", "WornSquatSuit", "WornLeverBelt", "WornKneeWrap", "WornWristWrap", "Sneakers"),
    "DeadliftSuit": ("TeeUnder", "WornDeadliftSuit", "WornLeverBelt", "Sneakers"),
    "BenchShirt": ("WornBenchShirt", "WornSinglet", "WornLeverBelt", "WornWristWrap", "Sneakers"),
    "TeeShorts": ("Tee", "Shorts", "Sneakers"),
    "LongSleeveJoggers": ("LongSleeve", "Joggers", "Sneakers"),
    "TankShorts": ("Tank", "Shorts", "Sneakers"),
}
LIFT_POSES = [("SquatBottom", "Station_Squat", 1.9), ("BenchChest", "Station_Bench", 2.0),
              ("DeadliftBottom", "Station_Deadlift", 1.6)]


def pieces(build, item):
    """The game pieces of one item: "<Build>_<Item>_<Key>__<Part>" (gear) or "<Build>_<Item>__<Part>" /
    "<Build>_<Item>White__<Part>" (clothes)."""
    out = []
    for o in bpy.data.objects:
        if o.type != "MESH" or "__" not in o.name or not o.name.startswith(build + "_"):
            continue
        head = o.name[len(build) + 1:].split("__")[0]
        if head == item or head.startswith(item + "_") or head == item + "White" or \
                (item == "Sneakers" and head == "SneakersSole"):
            if item == "Tee" and head.startswith("TeeUnder"):
                continue
            out.append(o)
    return out


def body_objs(build, hands="open"):
    objs = [bpy.data.objects[build + "_" + p] for p in PARTS
            if not (hands != "open" and p.endswith("Hand"))]
    head = bpy.data.objects.get(build + "_StandInHead")
    if head:
        objs.append(head)
    if hands != "open":
        for s in ("Left", "Right"):
            h = bpy.data.objects.get("%s_%s%s" % (build, hands, s))
            if h:
                objs.append(h)
    return objs


# ---------------------------------------------------------------- clearance
if ONLY in ("", "clearance"):
    lines = []
    totals = {}
    for b in BUILDS:
        items = {}
        for outfit in OUTFITS.values():
            for it in outfit:
                if it not in items:
                    ps = pieces(b, it)
                    if ps:
                        items[it] = ps
        # the hands are IN the wrist-wrap test (leaving them out hid the hand pushing through the wrap; user
        # 2026-11-14); a sneaker is a shell round the foot, so its own foot stays out of its test
        skip = {"Sneakers": ["LeftFoot", "RightFoot"]}
        rep = G["clearance"](b, items, skip_parts=skip)
        lines.append(G["format_report"](b, rep))
        for pose, row in rep.items():
            for it, r in row.items():
                t = totals.setdefault((it, pose), [0, 0, 0.0])
                t[0] += r["own"]
                t[1] += r["pokes"]
                t[2] = max(t[2], r["pokeMax"])
        tri = {it: sum(len(p.vertices) - 2 for o in ps for p in o.data.polygons) for it, ps in items.items()}
        lines.append("%s TRIANGLES %s" % (b, tri))
        print("[Check05g]", b, "done", flush=True)
    lines.append("")
    lines.append("SUMMARY over all builds (item, pose: clip points, skin-through points, deepest skin-through)")
    for (it, pose), (own, pokes, mx) in sorted(totals.items()):
        lines.append("  %-16s %-14s clip %4d  skin-through %4d  (%.3f)" % (it, pose, own, pokes, mx))
    path = os.path.join(OUT, "gear05_clearance.txt")
    open(path, "w").write("\n".join(lines))
    print("[Check05g] wrote", path, flush=True)

# ---------------------------------------------------------------- pictures
if ONLY in ("", "pictures"):
    for name, outfit in OUTFITS.items():
        per = {b: body_objs(b) + [o for it in outfit for o in pieces(b, it)] for b in BUILDS}
        imgs = G["shots"]("Gear05_" + name, per, size=(300, 470), centre_z=2.95, scale=6.3, out_dir=TMP,
                          colour="TEXTURE")
        G["contact_sheet"](imgs, os.path.join(OUT, "Gear05_%s.png" % name), cols=4)
        print("[Check05g] sheet", name, flush=True)
    meet = OUTFITS["MeetGear"]
    for label, anim, t in LIFT_POSES:
        data = G["anim_at"](anim, t)
        for b in BUILDS:
            G["pose_rig"](bpy.data.objects[b + "Rig"], data)
        hands = "Grip" if bpy.data.objects.get(BUILDS[0] + "_GripLeft") else "open"
        per = {b: body_objs(b, hands) + [o for it in meet for o in pieces(b, it)] for b in BUILDS}
        imgs = G["shots"]("Gear05_Pose_" + label, per, views=("front", "left", "back"), size=(300, 470),
                          centre_z=2.6, scale=6.3, out_dir=TMP, colour="TEXTURE")
        G["contact_sheet"](imgs, os.path.join(OUT, "Gear05_Pose_%s.png" % label), cols=3)
        for b in BUILDS:
            G["rest_rig"](bpy.data.objects[b + "Rig"])
        print("[Check05g] pose sheet", label, flush=True)
