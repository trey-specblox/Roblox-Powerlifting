# W Chews' hall: the restaurant's shell, off the map like the meet halls (GAME_DESIGN §40.7, user 2026-11-21; floor
# plan 02, art/previews/WChews_FloorPlan_02.png: "enter in the middle ... straight across you'll see the kitchen and
# the process"). Replaces KitchenBuilding_01's KitchenHall (the red and white checked pan hall).
#
# VERSION 02 (user 2026-11-22: "a double door ... move the room, and the door to the middle of the wall"): the
# EMPLOYEES ONLY doorway is 16 wide and 13 high in the MIDDLE of the kitchen's back wall, and the back room stands
# behind it. The doorway and the room come from art/scripts/wchews_layout.py (DOOR_X and the numbers round it), so
# the shell, the door model and the game's placements can't drift apart. Version 01 had a 6 x 9 doorway at x 245..251
# and the room at x 195..285. The pieces' names are the same: only one of the two versions may be in the game's list.
#
# Built in PLAN space: x = across (+x is the walking-in player's RIGHT), y = front to back, z = up. In the game a
# Blender point (x, y, z) lands at the hall's (-x, z, y): KitchenConfig keeps the plan's numbers and flips x.
#
#   the fancy front      x -80..80,   y -110..-20, 22 high: glass front wall with glowing doors, walnut floor and
#                        wainscot, deep green walls, a coffered ceiling with a warm cove light
#   the kitchen          x -285..285, y -20..265,  36 high: pale tile floor, white tiled walls with a teal band and a
#                        steel rail, a white ceiling with dark beams and light panels; wide open to the fancy front
#   the back room        x -53..37,   y 267..337,  18 high: burgundy carpet, walnut panelling, brass rails; the
#                        doorway (x -8..8, 13 high) for WcDoubleDoor (build_wchews_door_01.py)
#
# Every piece is decor: KitchenBuilding adds the hidden collision blocks.
#
#   blender -b --factory-startup --python art/scripts/build_wchews_hall_02.py -- <out.blend> [<out.glb>]

import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, r"D:\Powerlifting Roblox\art\scripts")
import importlib  # noqa: E402

import prop_helpers as H  # noqa: E402
import wchews_layout as L  # noqa: E402

importlib.reload(H)
importlib.reload(L)

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

B = H.Builder("WChewsHall")

FLOOR = H.material("Wh_FloorTile", (0.33, 0.37, 0.43), roughness=0.4)
NAVY = H.material("Wh_Navy", (0.05, 0.08, 0.21), roughness=0.55)
LINES = H.material("Wh_Yellow", (0.98, 0.80, 0.12), roughness=0.5)
TILE = H.material("Wh_WallTile", (0.95, 0.95, 0.93), roughness=0.4)
UPPER = H.material("Wh_WallUpper", (0.82, 0.85, 0.88), roughness=0.8)
TEAL = H.material("Wh_Teal", (0.06, 0.52, 0.52), roughness=0.5)
STEEL = H.material("Wh_Steel", (0.80, 0.82, 0.85), metallic=0.9, roughness=0.28)
BEAM = H.material("Wh_Beam", (0.20, 0.22, 0.26), roughness=0.6)
CEILING = H.material("Wh_Ceiling", (0.92, 0.93, 0.94), roughness=0.9)
GLOW_WHITE = H.material("Wh_GlowWhite", (1.0, 0.98, 0.94), emission=(1.0, 0.97, 0.9))
GLOW_WARM = H.material("Wh_GlowWarm", (1.0, 0.80, 0.55), emission=(1.0, 0.72, 0.38))
GLOW_GREEN = H.material("Wh_GlowGreen", (0.2, 0.95, 0.4), emission=(0.1, 0.95, 0.3))
WALNUT = H.material("Wh_Walnut", (0.26, 0.14, 0.07), roughness=0.55)
WOOD_FLOOR = H.material("Wh_WoodFloor", (0.42, 0.25, 0.13), roughness=0.5)
GREEN = H.material("Wh_DeepGreen", (0.05, 0.20, 0.15), roughness=0.8)
CREAM = H.material("Wh_Cream", (0.93, 0.88, 0.76), roughness=0.9)
BLACK = H.material("Wh_Black", (0.04, 0.04, 0.05), roughness=0.5)
BRASS = H.material("Wh_Brass", (0.86, 0.64, 0.22), metallic=0.9, roughness=0.3)
GLASS = H.material("Wh_Glass", (0.62, 0.80, 0.88), metallic=0.2, roughness=0.1, alpha=0.3)
CARPET = H.material("Wh_Burgundy", (0.36, 0.06, 0.10), roughness=0.95)
DARK = H.material("Wh_DarkCeiling", (0.10, 0.08, 0.08), roughness=0.9)

T = 2.0  # wall thickness
KX, KY0, KY1, KH = 285.0, -20.0, 265.0, 36.0  # the kitchen
FX, FY0, FY1, FH = 80.0, -110.0, -20.0, 22.0  # the fancy front
GLASS_TOP = 17.0  # the glass front wall's top
RX0, RX1, RY0, RY1 = L.BACK_ROOM  # the back room
RH = L.BACK_HEIGHT
TILE_H = 12.0  # white tile up to here, paint above
OPEN_H = 14.0  # the opening between the front and the kitchen
# The EMPLOYEES ONLY doorway in the kitchen's back wall: x0, x1, height.
DOOR = (L.DOOR_X - L.DOOR_HALF, L.DOOR_X + L.DOOR_HALF, L.DOOR_HEIGHT)
# The double door's frame (build_wchews_door_01.py) reaches this far either side of the doorway's middle: the steel
# rail on the back wall stops inside it.
FRAME_HALF = L.DOOR_HALF + 1.4
PAN_COLUMNS = (-234.0, -182.0, -130.0, -78.0, 78.0, 130.0, 182.0, 234.0)
PAN_ROWS = (34.0, 82.0, 130.0, 178.0, 226.0)
S = H.span


def kitchen_walls(bm, z0, z1):
    """The kitchen's four walls between two heights, with the opening to the front and the staff doorway."""
    S(bm, (-KX - T, KY0, z0), (-KX, KY1 + T, z1))  # left
    S(bm, (KX, KY0, z0), (KX + T, KY1 + T, z1))  # right
    # Back, with the doorway.
    if z0 < DOOR[2]:
        S(bm, (-KX, KY1, z0), (DOOR[0], KY1 + T, z1))
        S(bm, (DOOR[1], KY1, z0), (KX, KY1 + T, z1))
        if z1 > DOOR[2]:
            S(bm, (DOOR[0], KY1, DOOR[2]), (DOOR[1], KY1 + T, z1))
    else:
        S(bm, (-KX, KY1, z0), (KX, KY1 + T, z1))
    # Front: solid beside the fancy front, open across it up to OPEN_H.
    S(bm, (-KX - T, KY0 - T, z0), (-FX, KY0, z1))
    S(bm, (FX, KY0 - T, z0), (KX + T, KY0, z1))
    if z1 > OPEN_H:
        S(bm, (-FX, KY0 - T, max(z0, OPEN_H)), (FX, KY0, z1))


def floor(bm):
    S(bm, (-KX, KY0, -1.0), (KX, KY1, 0.0))


def floor_lines(bm):
    # A yellow safety line round the grinder station, and one along each side of the opening's walk-throughs.
    x0, x1, y0, y1, w = -42.0, 42.0, 16.0, 112.0, 0.8
    S(bm, (x0, y0, 0.0), (x1, y0 + w, 0.05))
    S(bm, (x0, y1 - w, 0.0), (x1, y1, 0.05))
    S(bm, (x0, y0 + w, 0.0), (x0 + w, y1 - w, 0.05))
    S(bm, (x1 - w, y0 + w, 0.0), (x1, y1 - w, 0.05))


def wall_tile(bm):
    kitchen_walls(bm, 0.0, 9.0)
    kitchen_walls(bm, 10.0, TILE_H)


def wall_accent(bm):
    kitchen_walls(bm, 9.0, 10.0)  # a teal tile band


def wall_upper(bm):
    kitchen_walls(bm, TILE_H, KH)


def wall_rail(bm):
    # A steel rail where the tile stops (proud of the inside faces), and the two steel-clad columns of the opening.
    z0, z1, p = TILE_H - 0.3, TILE_H + 0.3, 0.2
    S(bm, (-KX, KY0, z0), (-KX + p, KY1, z1))
    S(bm, (KX - p, KY0, z0), (KX, KY1, z1))
    S(bm, (-KX, KY1 - p, z0), (L.DOOR_X - FRAME_HALF + 0.2, KY1, z1))  # (the back wall's, either side of the door)
    S(bm, (L.DOOR_X + FRAME_HALF - 0.2, KY1 - p, z0), (KX, KY1, z1))
    S(bm, (-KX, KY0, z0), (-FX, KY0 + p, z1))
    S(bm, (FX, KY0, z0), (KX, KY0 + p, z1))
    for x in (-50.0, 50.0):
        S(bm, (x - 1.2, KY0 - T - 0.2, 0.0), (x + 1.2, KY0 + 0.2, OPEN_H))
    S(bm, (-FX, KY0 - T - 0.2, OPEN_H - 0.6), (FX, KY0 + 0.2, OPEN_H))  # the opening's steel lintel


def ceiling(bm):
    S(bm, (-KX - T, KY0 - T, KH), (KX + T, KY1 + T, KH + 1.0))


def beams(bm):
    for x in (-260.0, -208.0, -156.0, -104.0, -52.0, 52.0, 104.0, 156.0, 208.0, 260.0):
        S(bm, (x - 0.8, KY0, KH - 2.0), (x + 0.8, KY1, KH))
    for y in (10.0, 58.0, 106.0, 154.0, 202.0, 250.0):
        S(bm, (-KX, y - 0.7, KH - 1.6), (KX, y + 0.7, KH))


def light_panels(bm):
    for x in PAN_COLUMNS + (0.0,):
        for y in PAN_ROWS:
            S(bm, (x - 11.0, y - 4.0, KH - 0.3), (x + 11.0, y + 4.0, KH - 0.02))


# ----------------------------------------------------------------------- the fancy front

def front_floor(bm):
    S(bm, (-FX, FY0, -1.0), (FX, FY1 - T, 0.0))


def front_walls(bm):
    # Side walls above the wainscot, the front wall's band over the glass, and its corner piers.
    for s in (-1, 1):
        S(bm, (s * FX, FY0 - T, 4.0), (s * (FX + T), FY1 - T, FH))
        S(bm, (s * (FX - 2.0), FY0 - T, 0.0), (s * (FX + T), FY0, FH))
    S(bm, (-FX, FY0 - T, GLASS_TOP), (FX, FY0, FH))
    # The fancy side of the wall over the opening (the kitchen's wall is pale): W CHEWS glows on it (front_sign).
    S(bm, (-FX, FY1 - T - 0.3, OPEN_H), (FX, FY1 - T, FH))


def front_wainscot(bm):
    for s in (-1, 1):
        S(bm, (s * (FX - 0.3), FY0, 0.0), (s * (FX + T), FY1 - T, 4.0))
        S(bm, (s * (FX - 0.5), FY0, 3.7), (s * FX, FY1 - T, 4.2))  # its cap rail


def front_ceiling(bm):
    S(bm, (-FX - T, FY0 - T, FH), (FX + T, FY1 - T, FH + 1.0))


def front_beams(bm):
    # Walnut coffers: beams across and along the ceiling.
    y = FY0 + 15.0
    while y < FY1 - 6:
        S(bm, (-FX, y - 0.7, FH - 1.2), (FX, y + 0.7, FH))
        y += 20.0
    for x in (-40.0, 0.0, 40.0):
        S(bm, (x - 0.7, FY0, FH - 1.2), (x + 0.7, FY1 - T, FH))


def front_cove(bm):
    # A warm light strip round the top of the walls, a glowing frame round the doors, and a glow under the sill.
    for s in (-1, 1):
        S(bm, (s * (FX - 0.6), FY0 + 1, FH - 1.9), (s * (FX - 0.1), FY1 - T - 1, FH - 1.5))
    S(bm, (-FX + 1, FY0 + 0.1, FH - 1.9), (FX - 1, FY0 + 0.6, FH - 1.5))
    for s in (-1, 1):
        S(bm, (s * 8.6, FY0 - 1.4, 0.0), (s * 9.4, FY0 - 0.6, 12.8))
    S(bm, (-9.4, FY0 - 1.4, 12.0), (9.4, FY0 - 0.6, 12.8))
    for s in (-1, 1):
        S(bm, (s * 10.5, FY0 + 0.05, 0.1), (s * (FX - 2.5), FY0 + 0.35, 0.5))


def front_glass(bm):
    for s in (-1, 1):
        S(bm, (s * 10.0, FY0 - 1.2, 1.5), (s * (FX - 2.0), FY0 - 1.0, GLASS_TOP))
    S(bm, (-8.5, FY0 - 1.2, 12.8), (8.5, FY0 - 1.0, GLASS_TOP))
    for s in (-1, 1):  # the two door leaves
        S(bm, (s * 0.15, FY0 - 1.15, 0.2), (s * 8.4, FY0 - 1.0, 11.9))


def front_mullions(bm):
    # The dark frame of the glass wall: the sill, the posts and the rail above the doors.
    for s in (-1, 1):
        S(bm, (s * 9.6, FY0 - T, 0.0), (s * (FX - 2.0), FY0, 1.5))
        x = 10.0
        while x <= FX - 2.0 + 0.01:
            S(bm, (s * (x - 0.4), FY0 - 1.5, 1.5), (s * (x + 0.4), FY0 - 0.7, GLASS_TOP))
            x += 17.0
        S(bm, (s * 10.0, FY0 - 1.5, 8.8), (s * (FX - 2.0), FY0 - 0.7, 9.2))
    S(bm, (-9.6, FY0 - 1.5, GLASS_TOP - 0.6), (9.6, FY0 - 0.7, GLASS_TOP))


def front_brass(bm):
    # The doors' brass rails and tall handles.
    for s in (-1, 1):
        S(bm, (s * 0.15, FY0 - 1.25, 0.0), (s * 8.4, FY0 - 0.9, 0.5))
        S(bm, (s * 0.15, FY0 - 1.25, 11.6), (s * 8.4, FY0 - 0.9, 12.0))
        for y in (FY0 - 1.55, FY0 - 0.6):
            H.cylinder(bm, Vector((s * 1.4, y, 5.5)), 0.18, 5.0, segments=10)


RUNNER = (-9.0, 9.0, FY0 + 1.0, FY1 - 14.0)  # the carpet from the doors to the counter: x0, x1, y0, y1
PANEL_YS = (-98.0, -80.0, -62.0, -44.0)  # framed panels along the side walls


def front_runner(bm):
    S(bm, (RUNNER[0], RUNNER[2], 0.0), (RUNNER[1], RUNNER[3], 0.08))


def front_runner_edge(bm):
    # Brass borders along the carpet, and the brass frames of the wall panels.
    for s in (-1, 1):
        S(bm, (s * (RUNNER[1] - 0.2), RUNNER[2], 0.0), (s * (RUNNER[1] + 0.4), RUNNER[3], 0.12))
    S(bm, (RUNNER[0], RUNNER[3] - 0.3, 0.0), (RUNNER[1], RUNNER[3] + 0.3, 0.12))
    for s in (-1, 1):
        for y in PANEL_YS:
            x0, x1 = s * (FX - 0.25), s * (FX - 0.05)
            S(bm, (x0, y - 5.5, 5.4), (x1, y + 5.5, 5.8))
            S(bm, (x0, y - 5.5, 16.6), (x1, y + 5.5, 17.0))
            S(bm, (x0, y - 5.5, 5.8), (x1, y - 5.1, 16.6))
            S(bm, (x0, y + 5.1, 5.8), (x1, y + 5.5, 16.6))


def front_panels(bm):
    # Navy panels inside the brass frames.
    for s in (-1, 1):
        for y in PANEL_YS:
            S(bm, (s * (FX - 0.15), y - 5.1, 5.8), (s * FX, y + 5.1, 16.6))


def front_sconces(bm):
    # A glowing wall light between the panels.
    for s in (-1, 1):
        for y in (-89.0, -71.0, -53.0, -35.0):
            H.cylinder(bm, Vector((s * (FX - 0.6), y, 11.5)), 0.45, 2.6, segments=10)


def front_sign(bm):
    # W CHEWS in glowing letters over the opening to the kitchen: straight ahead as you walk in.
    B.add_text(bm, "W CHEWS", 4.2, 0.15, H.on_front((0, 0, 0), FY1 - T - 0.32, 18.0))


def exit_text(bm):
    # Read from inside (looking toward -Y): the text faces +Y, so it is written along -x.
    def place(x, up, depth):
        return Vector((-x, FY0 + 0.05 + depth, 19.4 + up))
    B.add_text(bm, "EXIT", 1.6, 0.06, place)


# ----------------------------------------------------------------------- the back room's shell

def back_floor(bm):
    S(bm, (RX0, RY0, -1.0), (RX1, RY1, 0.0))
    S(bm, (DOOR[0], KY1, -1.0), (DOOR[1], RY0, 0.0))  # the doorway's threshold


def back_walls(bm):
    S(bm, (RX0 - T, RY0, 0.0), (RX0, RY1 + T, RH))
    S(bm, (RX1, RY0, 0.0), (RX1 + T, RY1 + T, RH))
    S(bm, (RX0, RY1, 0.0), (RX1, RY1 + T, RH))
    # The panelling on the kitchen's back wall, round the doorway.
    S(bm, (RX0, RY0, 0.0), (DOOR[0], RY0 + 0.3, RH))
    S(bm, (DOOR[1], RY0, 0.0), (RX1, RY0 + 0.3, RH))
    S(bm, (DOOR[0], RY0, DOOR[2]), (DOOR[1], RY0 + 0.3, RH))


def back_trim(bm):
    # Brass rails round the room at chair height and under the ceiling.
    for z in (5.0, RH - 1.2):
        S(bm, (RX0, RY0 + 0.3, z), (RX0 + 0.2, RY1, z + 0.3))
        S(bm, (RX1 - 0.2, RY0 + 0.3, z), (RX1, RY1, z + 0.3))
        S(bm, (RX0, RY1 - 0.2, z), (RX1, RY1, z + 0.3))


def back_ceiling(bm):
    S(bm, (RX0 - T, RY0, RH), (RX1 + T, RY1 + T, RH + 1.0))


B.piece("WChewsHall_Floor", FLOOR, floor, smooth=False)
B.piece("WChewsHall_FloorLines", LINES, floor_lines, smooth=False)
B.piece("WChewsHall_WallTile", TILE, wall_tile, smooth=False)
B.piece("WChewsHall_WallAccent", TEAL, wall_accent, smooth=False)
B.piece("WChewsHall_WallUpper", UPPER, wall_upper, smooth=False)
B.piece("WChewsHall_WallRail", STEEL, wall_rail, smooth=False)
B.piece("WChewsHall_Ceiling", CEILING, ceiling, smooth=False)
B.piece("WChewsHall_Beams", BEAM, beams, smooth=False)
B.piece("WChewsHall_LightPanels", GLOW_WHITE, light_panels, smooth=False)
B.piece("WChewsHall_FrontFloor", WOOD_FLOOR, front_floor, smooth=False)
B.piece("WChewsHall_FrontWalls", GREEN, front_walls, smooth=False)
B.piece("WChewsHall_FrontWainscot", WALNUT, front_wainscot, smooth=False)
B.piece("WChewsHall_FrontCeiling", CREAM, front_ceiling, smooth=False)
B.piece("WChewsHall_FrontBeams", WALNUT, front_beams, smooth=False)
B.piece("WChewsHall_FrontCove", GLOW_WARM, front_cove, smooth=False)
B.piece("WChewsHall_FrontGlass", GLASS, front_glass, smooth=False)
B.piece("WChewsHall_FrontMullions", BLACK, front_mullions, smooth=False)
B.piece("WChewsHall_FrontBrass", BRASS, front_brass)
B.piece("WChewsHall_ExitText", GLOW_GREEN, exit_text, smooth=False)
B.piece("WChewsHall_FrontRunner", CARPET, front_runner, smooth=False)
B.piece("WChewsHall_FrontRunnerEdge", BRASS, front_runner_edge, smooth=False)
B.piece("WChewsHall_FrontPanels", NAVY, front_panels, smooth=False)
B.piece("WChewsHall_FrontSconces", GLOW_WARM, front_sconces)
B.piece("WChewsHall_FrontSign", GLOW_WARM, front_sign, smooth=False)
B.piece("WChewsHall_BackFloor", CARPET, back_floor, smooth=False)
B.piece("WChewsHall_BackWalls", WALNUT, back_walls, smooth=False)
B.piece("WChewsHall_BackTrim", BRASS, back_trim, smooth=False)
B.piece("WChewsHall_BackCeiling", DARK, back_ceiling, smooth=False)

# The hall's pieces are big on purpose (the whole restaurant): their own budgets (check_models' tri_budget).
bpy.context.view_layer.update()  # the new objects' world matrices
lo = Vector((1e9, 1e9, 1e9))
hi = -lo
for ob in B.coll.objects:
    ob["tri_budget"] = 12000
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
print("WCHEWS HALL BUILT:", len(B.coll.objects), "objects,", tris, "triangles; bounds", [round(v, 2) for v in lo],
      [round(v, 2) for v in hi], "pivot (bottom centre)", [round((lo[i] + hi[i]) / 2, 2) for i in range(2)], round(lo.z, 2))
