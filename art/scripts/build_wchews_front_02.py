# W Chews' building in the front square, version 02: the same building as build_wchews_front_01.py (the uploaded
# WChewsFront_01) with ONLY its raised terrace remodelled. In 01 the terrace and its planter were one solid dark block
# with a plain glass sheet on top, and it read as heavy and blank from the side. Here it is a restaurant terrace:
#   - a warm sandstone body on a dark base band, broken up by pale pilasters, a pale stone coping on top and a glowing
#     strip under the coping (the same orange glow as the strips between the wall panels);
#   - a wooden deck, an open glass balustrade between black posts with a black handrail;
#   - two tables with chairs, mustard cushions and teal parasols, potted cypresses and bushes in terracotta pots;
#   - the front planter in the same sandstone with a clipped green hedge on it;
#   - glowing glass doors from the dining room onto the terrace under a dark canopy, and two tall glowing windows in
#     the end wall that faces the side.
# Everything else (wall panels, glass entrance box, steps, carpet, rails, roofs, door) is unchanged from 01, and the
# terrace keeps 01's walkable footprint and heights (deck top at z 5 over x 25.2..40, y -15..-3; planter 2.4 high over
# x 24.8..40.4, y -17.6..-15), so KitchenBuilding.luau's hidden collision blocks still fit.
#
# (01's notes: GAME_DESIGN §40.7; References/W Chews/kitchen1.png: a pale building of tall wall panels stepping down in
# height with glowing light strips between them, a tall glass entrance box glowing from inside, wide shallow steps with
# a light under every nosing, black handrails, a raised terrace with a glass rail. No real restaurant's name or logo;
# the name floats over it as UI. No flat roofs: every wall panel carries its own dark sloping roof, the glass box a
# gable.)
#
# Built round its own centre, front toward -Y, standing on z = 0. Pieces (one colour each):
#   WChewsFront_Walls      the pale wall panels, the terrace's back block, the terrace's pilasters
#   WChewsFront_Base       the dark stone plinth, the dark base bands under the terrace and the planter
#   WChewsFront_Steps      the four steps and the landing, the terrace's and planter's pale stone coping
#   WChewsFront_Roofs      the sloping roofs, the glass box's gable, the canopy over the terrace doors
#   WChewsFront_Glass      the glass entrance box, the terrace's glass balustrade and its doors' and windows' glass
#   WChewsFront_Mullions   the glass box's black frame and the door frame, the terrace doors' and windows' frames
#   WChewsFront_Inside     the warm glow behind the glass (the restaurant lit inside), also behind the terrace glass
#   WChewsFront_Strips     the glowing strips between the wall panels, along the planter and under the terrace coping
#   WChewsFront_StepLights the little lights under every step's nosing
#   WChewsFront_Rails      the black handrails, the terrace's balustrade posts and handrail, table stands, parasol poles
#   WChewsFront_Carpet     the burgundy carpet up the middle of the steps to the doors (as inside)
#   WChewsFront_Brass      the carpet's edges and the doors' tall handles
#   WChewsFront_Door       the two glass door leaves (KitchenBuilding puts the Enter prompt here)
#   new in 02 (all decor; paint suggestions in the hand-over note):
#   WChewsFront_TerraceStone  the terrace's and the planter's sandstone body
#   WChewsFront_Deck          the terrace's wooden deck
#   WChewsFront_Furniture     the two table tops and four chairs (light wood)
#   WChewsFront_Cushions      the chairs' seat cushions (mustard)
#   WChewsFront_Parasols      the two parasol canopies (teal)
#   WChewsFront_Greenery      the planter's hedge, the potted cypresses and bushes
#   WChewsFront_Pots          the terracotta plant pots
#
#   blender -b --factory-startup --python art/scripts/build_wchews_front_02.py -- <out.blend> [<out.glb>]

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
# New in 02 (the terrace).
SANDSTONE = H.material("Wf_Sandstone", (0.66, 0.47, 0.30), roughness=0.9)
DECK = H.material("Wf_DeckWood", (0.26, 0.13, 0.06), roughness=0.8)
MAPLE = H.material("Wf_Maple", (0.66, 0.44, 0.22), roughness=0.7)
MUSTARD = H.material("Wf_Mustard", (0.67, 0.36, 0.03), roughness=0.95)
TEAL = H.material("Wf_Teal", (0.0, 0.26, 0.27), roughness=0.9)
LEAF = H.material("Wf_Leaf", (0.04, 0.26, 0.05), roughness=0.9)
TERRACOTTA = H.material("Wf_Terracotta", (0.55, 0.13, 0.05), roughness=0.85)

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
TERRACE = (25.2, 40.0, -15.0, 5.0)  # x0, x1, its front y, its top z (unchanged from 01: the collision blocks)
TERRACE_BACK = -3.0  # the terrace's back edge, where the back block's front wall stands
PLANTER = (24.8, 40.4, -17.6, -15.0, 2.4)  # x0, x1, y0, y1, height (unchanged from 01)
COPING = 4.7  # the terrace's coping runs from here up to just over the deck (z 5)
STEPS = 4
STEP_X = 21.0  # half the steps' width
STEP_RUN = 2.2
# The terrace's furniture: the two tables (x, y) with a parasol each, and the potted plants (x, y, kind).
TABLES = [(29.2, -10.0), (35.6, -7.2)]
POTS = [(26.3, -4.1, "cypress"), (38.9, -4.1, "cypress"), (26.3, -13.8, "bush"), (38.8, -13.8, "bush")]
RAIL_TOP = 7.55  # the balustrade's handrail height (2.55 over the deck)


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
    wall_block(bm, TERRACE[0], TERRACE[1], TERRACE_BACK, BACK, 0.6, 14.0, 14.0 + 3.5)
    # 02: pale pilasters on the terrace's sandstone body (from the base band up to the glowing strip): one round each
    # front corner and one more halfway along the side that faces the square's end, so the side is panelled, not one slab.
    tx0, tx1, ty0, _ = TERRACE
    S(bm, (tx1 - 0.55, ty0 - 0.15, 0.8), (tx1 + 0.15, ty0 + 0.55, 4.42))
    S(bm, (tx0 - 0.15, ty0 - 0.15, 0.8), (tx0 + 0.55, ty0 + 0.55, 4.42))
    S(bm, (tx1 - 0.1, -9.35, 0.8), (tx1 + 0.15, -8.65, 4.42))


def base(bm):
    # A dark plinth under every wall and under the terrace's back block.
    for x0, x1, _ in PANELS:
        S(bm, (x0 - 0.15, FRONT - 0.25, 0.0), (x1 + 0.15, BACK + 0.15, 0.6))
    S(bm, (TERRACE[0] - 0.15, -3.2, 0.0), (TERRACE[1] + 0.15, BACK + 0.15, 0.6))
    # 02: only a dark base band under the terrace's and the planter's sandstone (01 had the whole terrace dark).
    tx0, tx1, ty0, _ = TERRACE
    S(bm, (tx0 - 0.12, ty0 - 0.12, 0.0), (tx1 + 0.12, TERRACE_BACK, 0.8))
    px0, px1, py0, py1, _ = PLANTER
    S(bm, (px0 - 0.08, py0 - 0.08, 0.0), (px1 + 0.08, py1, 0.5))


def terrace_stone(bm):
    # The terrace's body under the deck, and the planter in front of it, in warm sandstone.
    tx0, tx1, ty0, _ = TERRACE
    S(bm, (tx0, ty0, 0.6), (tx1, TERRACE_BACK, COPING))
    px0, px1, py0, py1, ph = PLANTER
    S(bm, (px0, py0, 0.4), (px1, py1, ph - 0.2))


def steps(bm):
    # Four wide steps up to the landing in front of the doors.
    for k in range(STEPS):
        y0 = BOX[2] - 4.0 - STEP_RUN * (STEPS - k)
        S(bm, (-STEP_X, y0, 0.0), (STEP_X, FRONT, LAND * (k + 1) / STEPS))
    S(bm, (BOX[0] - 0.6, FRONT, 0.0), (BOX[1] + 0.6, FRONT + 4.0, LAND))  # the floor inside the glass box
    # 02: the pale stone coping round the terrace's open edges (its top just over the deck) and on the planter.
    tx0, tx1, ty0, tz = TERRACE
    top = tz + 0.02
    S(bm, (tx0 - 0.2, ty0 - 0.2, COPING), (tx1 + 0.2, ty0 + 0.4, top))
    S(bm, (tx1 - 0.4, ty0 + 0.4, COPING), (tx1 + 0.2, TERRACE_BACK, top))
    S(bm, (tx0 - 0.2, ty0 + 0.4, COPING), (tx0 + 0.4, TERRACE_BACK, top))
    px0, px1, py0, py1, ph = PLANTER
    S(bm, (px0 - 0.1, py0 - 0.1, ph - 0.2), (px1 + 0.1, py1, ph))


def deck(bm):
    # The terrace's wooden floor, inside the coping (its edges tuck under the coping).
    tx0, tx1, ty0, tz = TERRACE
    S(bm, (tx0 + 0.3, ty0 + 0.3, COPING - 0.1), (tx1 - 0.3, TERRACE_BACK, tz - 0.03))


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
    roof_slab(bm, TERRACE[0], TERRACE[1], TERRACE_BACK, BACK, 14.0, 17.5, over=0.5)
    # The glass box's gable: two slopes meeting on a ridge that runs front to back.
    half = (BOX[1] - BOX[0]) / 2 + 1.0
    rise = 5.0
    slope = math.atan2(rise, half)
    length = math.hypot(half, rise)
    for side in (-1, 1):
        H.box(bm, V((side * half / 2, (BOX[2] + BACK) / 2, BOX[3] + rise / 2 - 0.2)), (length + 0.4, BACK - BOX[2] + 1.6, 0.5),
              rotation=Matrix.Rotation(side * slope, 4, "Y"))
    # 02: a dark canopy over the terrace's glass doors, tipping down away from the wall.
    H.box(bm, V((32.6, TERRACE_BACK - 1.0, 12.25)), (13.0, 2.3, 0.22), rotation=Matrix.Rotation(math.radians(8), 4, "X"))


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


# 02: the terrace's openings. The glass doors in the back block's front wall (x0, x1, z0, z1, its bars' x), and the two
# tall windows in the back block's end wall (y0, y1, z0, z1).
TERRACE_DOORS = (26.7, 38.5, 5.05, 11.5, (30.63, 34.57), 9.55)
END_WINDOWS = [(0.6, 4.4, 5.6, 11.6), (8.0, 11.8, 5.6, 11.6)]
END_X = TERRACE[1]  # the end wall's face (x)


def glass(bm):
    x0, x1, y0, top = BOX
    S(bm, (x0 + 0.3, y0, 12.2), (x1 - 0.3, y0 + 0.15, top - 1.0))  # the front, above the doors
    for s in (-1, 1):
        S(bm, (s * 4.3, y0, LAND), (s * (x1 - 0.3), y0 + 0.15, 12.2))  # beside the doors
        S(bm, (s * (x1 - 0.15), y0 + 0.3, LAND), (s * x1, FRONT, top - 1.0))  # the box's sides
    # 02: the terrace's glass balustrade (panels between the posts, along the front and both open sides).
    px, py, lx = TERRACE[1] - 0.1, TERRACE[2] + 0.1, TERRACE[0] + 0.1
    z0, z1 = TERRACE[3] + 0.15, RAIL_TOP - 0.13
    S(bm, (lx, py - 0.03, z0), (px, py + 0.03, z1))
    S(bm, (px - 0.03, py, z0), (px + 0.03, TERRACE_BACK - 0.2, z1))
    S(bm, (lx - 0.03, py, z0), (lx + 0.03, FRONT, z1))
    # The terrace doors' and the end windows' glass.
    d0, d1, dz0, dz1, _, _ = TERRACE_DOORS
    S(bm, (d0, TERRACE_BACK - 0.3, dz0), (d1, TERRACE_BACK - 0.24, dz1))
    for w0, w1, wz0, wz1 in END_WINDOWS:
        S(bm, (END_X + 0.24, w0, wz0), (END_X + 0.3, w1, wz1))


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
    # 02: the terrace doors' frame (a dark plate round the glow), their bars and transom.
    d0, d1, dz0, dz1, bars, transom = TERRACE_DOORS
    S(bm, (d0 - 0.3, TERRACE_BACK - 0.12, dz0 - 0.05), (d1 + 0.3, TERRACE_BACK, dz1 + 0.3))
    for x in bars:
        S(bm, (x - 0.14, TERRACE_BACK - 0.38, dz0 - 0.05), (x + 0.14, TERRACE_BACK - 0.1, dz1))
    S(bm, (d0 - 0.3, TERRACE_BACK - 0.38, transom), (d1 + 0.3, TERRACE_BACK - 0.1, transom + 0.28))
    # The end windows' frames (a dark plate round each glow).
    for w0, w1, wz0, wz1 in END_WINDOWS:
        S(bm, (END_X, w0 - 0.3, wz0 - 0.3), (END_X + 0.12, w1 + 0.3, wz1 + 0.3))


def inside(bm):
    # The restaurant's warm light, seen through the glass: a glowing wall just inside the box.
    S(bm, (BOX[0] + 0.4, FRONT + 3.6, LAND), (BOX[1] - 0.4, FRONT + 3.9, BOX[3] - 1.2))
    # 02: the same glow behind the terrace doors and the end windows.
    d0, d1, dz0, dz1, _, _ = TERRACE_DOORS
    S(bm, (d0, TERRACE_BACK - 0.2, dz0), (d1, TERRACE_BACK - 0.1, dz1))
    for w0, w1, wz0, wz1 in END_WINDOWS:
        S(bm, (END_X + 0.1, w0, wz0), (END_X + 0.2, w1, wz1))


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
    # 02: the planter's line turns its end corner, and a glowing strip runs under the terrace's coping all round.
    px0, px1, py0, py1, _ = PLANTER
    S(bm, (px1, py0, 1.9), (px1 + 0.08, py1, 2.15))
    tx0, tx1, ty0, _ = TERRACE
    S(bm, (tx0, ty0 - 0.08, 4.42), (tx1, ty0, 4.62))
    S(bm, (tx1, ty0, 4.42), (tx1 + 0.08, TERRACE_BACK, 4.62))
    S(bm, (tx0 - 0.08, ty0, 4.42), (tx0, FRONT, 4.62))


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
    # 02: the terrace balustrade's black posts and handrail (along the front, the end side and the short open side
    # next to the right wing).
    tz = TERRACE[3]
    px, py, lx = TERRACE[1] - 0.1, TERRACE[2] + 0.1, TERRACE[0] + 0.1
    posts = [(lx + (px - lx) * k / 4, py) for k in range(5)]
    posts += [(px, py + (TERRACE_BACK - 0.2 - py) * k / 3) for k in range(1, 4)]
    posts += [(lx, FRONT)]
    for x, y in posts:
        S(bm, (x - 0.09, y - 0.09, tz), (x + 0.09, y + 0.09, RAIL_TOP))
    S(bm, (lx - 0.14, py - 0.14, RAIL_TOP - 0.13), (px + 0.14, py + 0.14, RAIL_TOP + 0.12))
    S(bm, (px - 0.14, py - 0.14, RAIL_TOP - 0.13), (px + 0.14, TERRACE_BACK - 0.2, RAIL_TOP + 0.12))
    S(bm, (lx - 0.14, py - 0.14, RAIL_TOP - 0.13), (lx + 0.14, FRONT + 0.09, RAIL_TOP + 0.12))
    # The tables' stands: a foot plate and the parasol's pole, which holds the table top.
    for x, y in TABLES:
        S(bm, (x - 0.55, y - 0.55, tz - 0.03), (x + 0.55, y + 0.55, tz + 0.09))
        S(bm, (x - 0.1, y - 0.1, tz - 0.03), (x + 0.1, y + 0.1, tz + 4.9))


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


# 02: the terrace's furniture and plants (decor: KitchenBuilding gives the building no collision but its hidden blocks).
SEAT_Z = TERRACE[3] + 1.7
TABLE_Z = TERRACE[3] + 2.6


def chairs(side):
    """Each table's two chairs, one each side across x, facing the table. side(bm, cx, cy, s) adds one chair part;
    s is +1 when the table is toward +x."""
    def build(bm):
        for x, y in TABLES:
            for s in (-1, 1):
                side(bm, x - s * 1.75, y, s)
    return build


def chair(bm, cx, cy, s):
    # A tulip cafe chair (cheap: three boxes): the seat on one slim stem, and a low back.
    tz = TERRACE[3]
    S(bm, (cx - 0.55, cy - 0.55, SEAT_Z - 0.15), (cx + 0.55, cy + 0.55, SEAT_Z))  # the seat
    S(bm, (cx - s * 0.68, cy - 0.5, SEAT_Z - 0.15), (cx - s * 0.54, cy + 0.5, SEAT_Z + 1.2))  # the back
    S(bm, (cx - 0.1, cy - 0.1, tz - 0.03), (cx + 0.1, cy + 0.1, SEAT_Z - 0.15))  # the stem


def furniture(bm):
    chairs(chair)(bm)
    for x, y in TABLES:  # the round table tops
        H.cylinder(bm, V((x, y, TABLE_Z)), 1.25, 0.12, segments=6)


def cushion(bm, cx, cy, s):
    S(bm, (cx - 0.48, cy - 0.48, SEAT_Z), (cx + 0.48, cy + 0.48, SEAT_Z + 0.12))


def parasols(bm):
    # Market parasols: a shallow six-sided cone with a thin rim, over each table.
    for x, y in TABLES:
        top = TERRACE[3] + 5.0
        H.lathe_z(bm, [(0.0, top), (2.45, top - 1.05), (2.45, top - 1.2), (0.0, top - 0.3)], 6, centre=V((x, y, 0)))


POT_H = 1.3


def pots(bm):
    # Square terracotta planters.
    for x, y, _ in POTS:
        S(bm, (x - 0.65, y - 0.65, TERRACE[3] - 0.03), (x + 0.65, y + 0.65, TERRACE[3] + POT_H))


def greenery(bm):
    # The planter's clipped hedge.
    px0, px1, py0, py1, ph = PLANTER
    H.rounded_box(bm, V(((px0 + px1) / 2, (py0 + py1) / 2, ph + 0.45)), (px1 - px0 - 0.5, py1 - py0 - 0.55, 1.1),
                  0.3, segments=1)
    # The pots' plants: tall cypresses at the back, round bushes at the front.
    for x, y, kind in POTS:
        if kind == "cypress":
            H.cylinder(bm, V((x, y, TERRACE[3] + POT_H + 1.6)), 0.8, 3.6, segments=6, radius2=0.0)
        else:
            H.sphere(bm, V((x, y, TERRACE[3] + POT_H + 0.55)), 0.85, scale=(1, 1, 0.9), segments=6, rings=4)


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
B.piece("WChewsFront_TerraceStone", SANDSTONE, terrace_stone, smooth=False)
B.piece("WChewsFront_Deck", DECK, deck, smooth=False)
B.piece("WChewsFront_Furniture", MAPLE, furniture, smooth=False)
B.piece("WChewsFront_Cushions", MUSTARD, chairs(cushion), smooth=False)
B.piece("WChewsFront_Parasols", TEAL, parasols, smooth=False)
B.piece("WChewsFront_Greenery", LEAF, greenery)
B.piece("WChewsFront_Pots", TERRACOTTA, pots)

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
for o in sorted(B.coll.objects, key=lambda o: o.name):
    print("  ", o.name, sum(len(p.vertices) - 2 for p in o.data.polygons), "triangles")
door_ob = B.coll.objects["WChewsFront_Door"]
print("WCHEWS FRONT 02 BUILT:", len(B.coll.objects), "objects,", tris, "triangles; bounds", [round(v, 2) for v in lo],
      [round(v, 2) for v in hi], "; door centre", [round(v, 3) for v in door_ob.location])
