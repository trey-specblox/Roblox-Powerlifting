# Exports each production body's skin (rest pose) for the animation scripts' hand-contact rule (References/Character
# Animation Quality.md: "a hand aimed at the body stops at its skin"): for every build in CartoonBodies_05_Rigged.blend,
# the points and outward normals of the torso, the stand-in head and the thighs, in the rig's own Roblox space (studs,
# from the floor, +Y up, the body facing -Z), keyed by the R15 part they move with (the stand-in head rides the
# UpperTorso, as in the .blend). READ-ONLY: the .blend is opened and not saved.
#   blender -b art/blender/CartoonBodies_05_Rigged.blend --python art/scripts/export_body_surface.py
# writes art/data/body_surface_05.json
import json
import os

import bpy

ROOT = r"D:\Powerlifting Roblox"
G = {"__name__": "gear_fit_03"}
exec(open(os.path.join(ROOT, "art", "scripts", "gear_fit_03.py")).read(), G)
TO_B = G["TO_B"]
BUILDS = ("Skinny", "SkinnyFat", "Fat", "Fit", "Muscular", "BigBuff")
PARTS = {"UpperTorso": ["UpperTorso", "StandInHead"], "LowerTorso": ["LowerTorso"],
         "LeftUpperLeg": ["LeftUpperLeg"], "RightUpperLeg": ["RightUpperLeg"]}
out = {"note": "rest-pose skin points [x, y, z, nx, ny, nz], rig-local Roblox studs from the floor; see the script",
       "builds": {}}
dg = bpy.context.evaluated_depsgraph_get()
for b in BUILDS:
    rig = bpy.data.objects[b + "Rig"]
    G["rest_rig"](rig)
    inv = rig.matrix_world.inverted()
    r3 = TO_B.to_3x3()
    parts = {}
    for key, names in PARTS.items():
        pts = []
        for n in names:
            o = bpy.data.objects.get("%s_%s" % (b, n))
            if o is None:
                continue
            ev = o.evaluated_get(dg)
            me = ev.to_mesh()
            m = inv @ o.matrix_world
            nm = m.to_3x3().inverted().transposed()
            for v in me.vertices:
                p = TO_B @ (m @ v.co)
                q = (r3 @ (nm @ v.normal)).normalized()
                pts.append([round(c, 4) for c in (p.x, p.y, p.z, q.x, q.y, q.z)])
            ev.to_mesh_clear()
        parts[key] = pts
    out["builds"][b] = parts
    print("[BodySurface]", b, {k: len(v) for k, v in parts.items()})
path = os.path.join(ROOT, "art", "data", "body_surface_05.json")
json.dump(out, open(path, "w"), separators=(",", ":"))
print("[BodySurface] wrote", path, os.path.getsize(path), "bytes")
