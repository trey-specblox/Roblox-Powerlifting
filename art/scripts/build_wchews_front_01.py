# W Chews' building in the front square: the way in (GAME_DESIGN §40.7; user 2026-11-21: "update the shell, so it goes
# with the inside and reference photos"; References/W Chews/kitchen1.png: a pale building of tall wall panels stepping
# down in height with glowing light strips between them, a tall glass entrance box glowing from inside, wide shallow
# steps with a light under every nosing, black handrails, a raised terrace with a glass rail). Replaces
# KitchenBuilding_01's KitchenHouse (the cream cottage). Its own design in that style: no real restaurant's name or
# logo; the name floats over it as UI (memory: floating names, not boards).
#
# The photo's building has flat parapets; this game's rule is no flat roofs (memory), so every wall panel carries its
# own dark sloping roof and the glass box a gable: a stepped, broken-up roofline.
#
# Built round its own centre, front toward -Y, standing on z = 0. Pieces (one colour each):
#   WChewsFront_Walls      the pale wall panels (each a block as deep as the building), the terrace's back block
#   WChewsFront_Base       the dark stone plinth, the terrace and its planter wall
#   WChewsFront_Steps      the four steps and the landing
#   WChewsFront_Roofs      the sloping roofs and the glass box's gable
#   WChewsFront_Glass      the glass entrance box and the terrace's glass rail
#   WChewsFront_Mullions   the glass box's black frame and the door frame
#   WChewsFront_Inside     the warm glow behind the glass (the restaurant lit inside)
#   WChewsFront_Strips     the glowing strips between the wall panels and along the plinth
#   WChewsFront_StepLights the little lights under every step's nosing
#   WChewsFront_Rails      the black handrails
#   WChewsFront_Carpet     the burgundy carpet up the middle of the steps to the doors (as inside)
#   WChewsFront_Brass      the carpet's edges and the doors' tall handles
#   WChewsFront_Door       the two glass door leaves (KitchenBuilding puts the Enter prompt here)
#
#   blender -b --factory-startup --python art/scripts/build_wchews_front_01.py -- <out.blend> [<out.glb>]

import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, r"D:\Powerlifting Roblox\art\scripts")
import importlib  # noqa: E402

import prop_helpers as H  # noqa: E402

importlib.reload(H)

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

B = H.Builder("WChewsFront")

STUCCO = H.material("Wf_Stucco", (0.62, 0.57, 0.48), roughness=0.85)
STONE = H.material("Wf_DarkStone", (0.13, 0.13, 0.15), roughness=0.6)
STEP = H.material("Wf_StepStone", (0.40, 0.40, 0.43), roughness=0.7)
ROOF = H.material("Wf_Roof", (0.07, 0.09, 0.10), metallic=0.5, roughness=0.45)
GLASS = H.material("Wf_Glass", (0.62, 0.80, 0.88), metallic=0.2, roughness=0.1, alpha=0.3)
BLACK = H.material("Wf_Black", (0.03, 0.03, 0.04), roughness=0.5)
INSIDE = H.material("Wf_InsideGlow", (1.0, 0.72, 0.42), emission=(1.0, 0.62, 0.30))
STRIP = H.material("Wf_StripGlow", (1.0, 0.36, 0.18), emission=(1.0, 0.30, 0.10))
STEP_LIGHT = H.material("Wf_StepLight", (1.0, 0.95, 0.85), emission=(1.0, 0.92, 0.75))
CARPET = H.material("Wf_Burgundy", (0.36, 0.06, 0.10), roughness=0.95)
BRASS = H.material("Wf_Brass", (0.86, 0.64, 0.22), metallic=0.9, roughness=0.3)

S = H.span
V = Vector

FRONT = -11.0  # the wall panels' front face (y)
BACK = 15.0
LAND = 1.6  # the landing's height (four steps of 0.4)
BOX = (-9.0, 9.0, -15.0, 24.0)  # the glass entrance box: x0, x1, its front y, its top z
# The wall panels: (x0, x1, height). They step down away from the entrance, as in the photo; the right side ends in
# a low terrace.
PANELS = [(-17.0, -9.6, 22.0), (-24.6, -17.6, 20.0), (-32.2, -25.2, 18.0), (-39.8, -32.8, 16.0),
          (9.6, 17.0, 22.0), (17.6, 24.6, 20.0)]
TERRACE = (25.2, 40.0, -15.0, 5.0)  # x0, x1, its front y, its top z
STEPS = 4
STEP_X = 21.0  # half the steps' width
STEP_RUN = 2.2


ROOF_RISE = 4.5  # every panel's roof rises this much from its front edge to the back


def wall_block(bm, x0, x1, y0, y1, z0, z_front, z_back):
    """A wall panel whose top slopes from the front up to the back, so its roof sits right on it (no gap)."""
    pts = [(y0, z0), (y1, z0), (y1, z_back), (y0, z_front)]
    left = [bm.verts.new((x0, y, z)) for y, z in pts]
    right = [bm.verts.new((x1, y, z)) for y, z in pts]
    made = [bm.faces.new(list(reversed(left))), bm.faces.new(right)]
    for i in range(4):
        j = (i + 1) % 4
        made.append(bm.faces.new((left[i], left[j], right[j], right[i])))
    bmesh.ops.recalc_face_normals(bm, faces=made)


def walls(bm):
    for x0, x1, h in PANELS:
        wall_block(bm, x0, x1, FRONT, BACK, 0.6, h, h + ROOF_RISE)
    # Behind the glass box (the box's back wall, with the doorway dark inside) and the mass behind the terrace.
    S(bm, (BOX[0], FRONT + 4.0, 0.6), (BOX[1], BACK, BOX[3] - 1.0))
    wall_block(bm, TERRACE[0], TERRACE[1], -3.0, BACK, 0.6, 14.0, 14.0 + 3.5)


def base(bm):
    # A dark plinth under every wall, the terrace and its front planter wall.
    for x0, x1, _ in PANELS:
        S(bm, (x0 - 0.15, FRONT - 0.25, 0.0), (x1 + 0.15, BACK + 0.15, 0.6))
    S(bm, (TERRACE[0] - 0.15, -3.2, 0.0), (TERRACE[1] + 0.15, BACK + 0.15, 0.6))
    S(bm, (TERRACE[0], TERRACE[2], 0.0), (TERRACE[1], -3.0, TERRACE[3]))
    S(bm, (TERRACE[0] - 0.4, TERRACE[2] - 2.6, 0.0), (TERRACE[1] + 0.4, TERRACE[2], 2.4))  # the planter wall


def steps(bm):
    # Four wide steps up to the landing in front of the doors.
    for k in range(STEPS):
        y0 = BOX[2] - 4.0 - STEP_RUN * (STEPS - k)
        S(bm, (-STEP_X, y0, 0.0), (STEP_X, FRONT, LAND * (k + 1) / STEPS))
    S(bm, (BOX[0] - 0.6, FRONT, 0.0), (BOX[1] + 0.6, FRONT + 4.0, LAND))  # the floor inside the glass box


def roof_slab(bm, x0, x1, y0, y1, z_front, z_back, t=0.5, over=0.7):
    """A roof sloping from the front (z_front) up or down to the back (z_back), with an overhang."""
    slope = (z_back - z_front) / (y1 - y0)
    low, high = V((x0 - over, y0 - over, z_front - over * slope)), V((x1 + over, y1 + over, z_back + over * slope))
    pts = [(low.y, low.z), (high.y, high.z), (high.y, high.z + t), (low.y, low.z + t)]
    left = [bm.verts.new((low.x, y, z)) for y, z in pts]
    right = [bm.verts.new((high.x, y, z)) for y, z in pts]
    made = [bm.faces.new(list(reversed(left))), bm.faces.new(right)]
    for i in range(4):
        j = (i + 1) % 4
        made.append(bm.faces.new((left[i], left[j], right[j], right[i])))
    bmesh.ops.recalc_face_normals(bm, faces=made)


def roofs(bm):
    # Every wall panel's own roof, low at the front and rising to the back (seen from the square as a dark sloping cap).
    for x0, x1, h in PANELS:
        roof_slab(bm, x0, x1, FRONT, BACK, h, h + ROOF_RISE, over=0.5)
    roof_slab(bm, TERRACE[0], TERRACE[1], -3.0, BACK, 14.0, 17.5, over=0.5)
    # The glass box's gable: two slopes meeting on a ridge that runs front to back.
    half = (BOX[1] - BOX[0]) / 2 + 1.0
    rise = 5.0
    slope = math.atan2(rise, half)
    length = math.hypot(half, rise)
    for side in (-1, 1):
        H.box(bm, V((side * half / 2, (BOX[2] + BACK) / 2, BOX[3] + rise / 2 - 0.2)), (length + 0.4, BACK - BOX[2] + 1.6, 0.5),
              rotation=Matrix.Rotation(side * slope, 4, "Y"))


def gable_wall(bm):
    # The triangle of wall under the glass box's gable, front and back (part of the walls' colour).
    half = (BOX[1] - BOX[0]) / 2
    for y0, y1 in ((BOX[2] + 0.2, BOX[2] + 0.6), (BACK - 0.4, BACK)):
        pts = [(-half, BOX[3] - 1.0), (half, BOX[3] - 1.0), (0.0, BOX[3] + 4.3)]
        front = [bm.verts.new((x, y0, z)) for x, z in pts]
        back = [bm.verts.new((x, y1, z)) for x, z in pts]
        made = [bm.faces.new(front), bm.faces.new(list(reversed(back)))]
        for i in range(3):
            j = (i + 1) % 3
            made.append(bm.faces.new((front[i], back[i], back[j], front[j])))
        bmesh.ops.recalc_face_normals(bm, faces=made)
    S(bm, (BOX[0], BOX[2], BOX[3] - 1.0), (BOX[1], FRONT + 4.0, BOX[3]))  # the box's solid top band


def glass(bm):
    x0, x1, y0, top = BOX
    S(bm, (x0 + 0.3, y0, 12.2), (x1 - 0.3, y0 + 0.15, top - 1.0))  # the front, above the doors
    for s in (-1, 1):
        S(bm, (s * 4.3, y0, LAND), (s * (x1 - 0.3), y0 + 0.15, 12.2))  # beside the doors
        S(bm, (s * (x1 - 0.15), y0 + 0.3, LAND), (s * x1, FRONT, top - 1.0))  # the box's sides
    # The terrace's glass rail.
    tx0, tx1, ty0, tz = TERRACE
    S(bm, (tx0 + 0.3, ty0 + 0.2, tz), (tx1 - 0.3, ty0 + 0.32, tz + 2.2))
    S(bm, (tx1 - 0.32, ty0 + 0.32, tz), (tx1 - 0.2, -3.2, tz + 2.2))


def mullions(bm):
    x0, x1, y0, top = BOX
    t = 0.35
    for x in (x0, -4.3, 4.3, x1):  # the front's posts
        S(bm, (x - t / 2, y0 - 0.1, LAND), (x + t / 2, y0 + 0.3, top - 1.0))
    for z in (12.2, 18.0):  # its rails
        S(bm, (x0, y0 - 0.1, z - t / 2), (x1, y0 + 0.3, z + t / 2))
    S(bm, (x0 - t / 2, y0 - 0.1, top - 1.2), (x1 + t / 2, y0 + 0.3, top - 0.9))
    for s in (-1, 1):  # the sides' rails and back posts
        for z in (12.2, 18.0):
            S(bm, (s * (x1 - 0.25), y0, z - t / 2), (s * (x1 + 0.1), FRONT, z + t / 2))
    S(bm, (-0.12, y0 - 0.1, LAND), (0.12, y0 + 0.3, 12.2))  # between the two doors


def inside(bm):
    # The restaurant's warm light, seen through the glass: a glowing wall just inside the box.
    S(bm, (BOX[0] + 0.4, FRONT + 3.6, LAND), (BOX[1] - 0.4, FRONT + 3.9, BOX[3] - 1.2))


def strips(bm):
    # A glowing strip in every gap between two wall panels, as tall as the lower of the two, and one each side of the
    # glass box; a thin line of light along the terrace's planter wall.
    edges = sorted(PANELS)
    for (a0, a1, ah), (b0, b1, bh) in zip(edges, edges[1:]):
        if 0 < b0 - a1 < 1.0:
            S(bm, (a1, FRONT + 0.3, 0.6), (b0, FRONT + 0.5, min(ah, bh)))
    for s in (-1, 1):
        S(bm, (s * BOX[1], FRONT + 0.3, 0.6), (s * 9.6, FRONT + 0.5, 22.0))
    S(bm, (TERRACE[0], TERRACE[2] - 2.72, 1.9), (TERRACE[1], TERRACE[2] - 2.6, 2.15))
    S(bm, (24.6, FRONT + 0.3, 0.6), (25.2, FRONT + 0.5, 14.0))


def step_lights(bm):
    # A row of small lights under each step's nosing.
    for k in range(STEPS):
        y0 = BOX[2] - 4.0 - STEP_RUN * (STEPS - k)
        z = LAND * (k + 1) / STEPS - 0.2
        x = -STEP_X + 1.5
        while x <= STEP_X - 1.5 + 0.01:
            if abs(x) > 5.2:  # (the carpet covers the middle)
                S(bm, (x - 0.22, y0 - 0.05, z - 0.1), (x + 0.22, y0 + 0.02, z + 0.1))
            x += 2.0


def rails(bm):
    # Four black handrails up the steps: two posts and a sloping bar each, with a level end at the top.
    y_bottom = BOX[2] - 4.0 - STEP_RUN * STEPS - 0.2
    y_top = BOX[2] - 4.0 + 0.6
    run = y_top - y_bottom
    slope = math.atan2(LAND, run)
    for x in (-15.0, -7.0, 7.0, 15.0):
        H.box(bm, V((x, y_bottom, 1.55)), (0.22, 0.22, 3.1))
        H.box(bm, V((x, y_top, LAND + 1.55)), (0.22, 0.22, 3.1))
        H.box(bm, V((x, (y_bottom + y_top) / 2, 3.1 + LAND / 2)), (0.24, math.hypot(run, LAND) + 0.2, 0.24),
              rotation=Matrix.Rotation(slope, 4, "X"))
        H.box(bm, V((x, y_top + 1.0, LAND + 3.1)), (0.24, 2.0, 0.24))


def carpet(bm):
    # The burgundy carpet from the square up the steps to the doors (the same carpet runs to the chef inside).
    for k in range(STEPS):
        y0 = BOX[2] - 4.0 - STEP_RUN * (STEPS - k)
        z = LAND * (k + 1) / STEPS
        S(bm, (-4.5, y0 - 0.06, 0.0 if k == 0 else LAND * k / STEPS), (4.5, y0 + STEP_RUN + 0.02, z + 0.06))
    S(bm, (-4.5, BOX[2] - 4.0, LAND), (4.5, FRONT + 3.6, LAND + 0.06))


def brass(bm):
    for s in (-1, 1):
        for k in range(STEPS):
            y0 = BOX[2] - 4.0 - STEP_RUN * (STEPS - k)
            z = LAND * (k + 1) / STEPS
            S(bm, (s * 4.5, y0 - 0.08, 0.0 if k == 0 else LAND * k / STEPS), (s * 4.9, y0 + STEP_RUN + 0.02, z + 0.09))
        S(bm, (s * 4.5, BOX[2] - 4.0, LAND), (s * 4.9, BOX[2] - 0.2, LAND + 0.09))
        for y in (BOX[2] - 0.35, BOX[2] + 0.5):  # the doors' tall handles, outside and inside
            H.cylinder(bm, V((s * 0.9, y, LAND + 5.0)), 0.14, 4.6, segments=10)


def door(bm):
    for s in (-1, 1):
        S(bm, (s * 0.14, BOX[2] + 0.02, LAND + 0.05), (s * 4.1, BOX[2] + 0.14, 12.0))


B.piece("WChewsFront_Walls", STUCCO, lambda bm: (walls(bm), gable_wall(bm)), smooth=False)
B.piece("WChewsFront_Base", STONE, base, smooth=False)
B.piece("WChewsFront_Steps", STEP, steps, smooth=False)
B.piece("WChewsFront_Roofs", ROOF, roofs, smooth=False)
B.piece("WChewsFront_Glass", GLASS, glass, smooth=False)
B.piece("WChewsFront_Mullions", BLACK, mullions, smooth=False)
B.piece("WChewsFront_Inside", INSIDE, inside, smooth=False)
B.piece("WChewsFront_Strips", STRIP, strips, smooth=False)
B.piece("WChewsFront_StepLights", STEP_LIGHT, step_lights, smooth=False)
B.piece("WChewsFront_Rails", BLACK, rails, smooth=False)
B.piece("WChewsFront_Carpet", CARPET, carpet, smooth=False)
B.piece("WChewsFront_Brass", BRASS, brass)
B.piece("WChewsFront_Door", GLASS, door, smooth=False)

bpy.context.view_layer.update()
lo = Vector((1e9, 1e9, 1e9))
hi = -lo
for ob in B.coll.objects:
    ob["tri_budget"] = 8000
    for corner in ob.bound_box:
        w = ob.matrix_world @ Vector(corner)
        lo = Vector(map(min, lo, w))
        hi = Vector(map(max, hi, w))

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if argv:
    bpy.ops.wm.save_as_mainfile(filepath=argv[0])
if len(argv) >= 2:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in B.coll.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=argv[1], export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
tris = sum(len(p.vertices) - 2 for o in B.coll.objects for p in o.data.polygons)
print("WCHEWS FRONT BUILT:", len(B.coll.objects), "objects,", tris, "triangles; bounds", [round(v, 2) for v in lo],
      [round(v, 2) for v in hi])
