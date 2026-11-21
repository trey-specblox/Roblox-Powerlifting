# The Kitchen's buildings (GAME_DESIGN §40.7, user 2026-11-19; map design comes last, so both are placed from one point):
#
#   KitchenHouse_*  the entrance building in the front square: cream walls, a pitched red roof with gables and an
#                   overhang, a projecting entrance with its own little gable, a striped awning, windows, a brick chimney
#                   and a big CENTRAL KITCHEN sign. Never a flat roof or a plain box (memory: no flat roofs).
#   KitchenHall_*   the pan hall's shell (off the map, like the meet halls): white tiled walls with a red band, a pitched
#                   roof on steel trusses, a red and white checked floor, a KITCHEN sign on the back wall and an EXIT door
#                   with its sign at the front.
#
# House: built round its own centre, front toward -Y. Hall: in the hall's own space (KitchenConfig.HallOrigin), the
# zones' floor x -228..228, y (Roblox z) -90..242. Units: studs; z up.
#
#   blender -b --factory-startup --python art/scripts/build_kitchen_building_01.py -- <out.blend> [<out.glb>]

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

B = H.Builder("KitchenBuilding")

CREAM = H.material("Bld_Cream", (0.94, 0.88, 0.74), roughness=0.8)
ROOF = H.material("Bld_RoofRed", (0.62, 0.12, 0.1), roughness=0.7)
TRIM = H.material("Bld_TrimWhite", (0.96, 0.96, 0.94), roughness=0.6)
DOOR = H.material("Bld_DoorDark", (0.12, 0.09, 0.08), roughness=0.6)
GLASS = H.material("Bld_Glass", (0.45, 0.62, 0.78), metallic=0.3, roughness=0.15)
NAVY = H.material("Bld_SignNavy", (0.05, 0.08, 0.21), roughness=0.6)
YELLOW = H.material("Bld_Yellow", (0.98, 0.79, 0.12), roughness=0.5)
BRICK = H.material("Bld_Brick", (0.55, 0.22, 0.16), roughness=0.9)
STRIPE_RED = H.material("Bld_StripeRed", (0.78, 0.12, 0.12), roughness=0.7)
TILE = H.material("Bld_TileWhite", (0.95, 0.95, 0.93), roughness=0.5)
STEEL = H.material("Bld_Steel", (0.42, 0.44, 0.48), metallic=0.8, roughness=0.4)
HALL_ROOF = H.material("Bld_HallRoof", (0.2, 0.21, 0.24), roughness=0.8)
FLOOR_RED = H.material("Bld_FloorRed", (0.7, 0.14, 0.12), roughness=0.6)
FLOOR_WHITE = H.material("Bld_FloorWhite", (0.93, 0.92, 0.88), roughness=0.6)
GREEN = H.material("Bld_ExitGreen", (0.15, 0.8, 0.35), roughness=0.5, emission=(0.1, 0.9, 0.3))


def prism_x(bm, points, x0, x1):
    """A solid from an outline in the YZ plane (points anticlockwise seen from +X), from x0 to x1."""
    left = [bm.verts.new((x0, y, z)) for y, z in points]
    right = [bm.verts.new((x1, y, z)) for y, z in points]
    bm.faces.new(list(reversed(left)))
    bm.faces.new(right)
    n = len(points)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((left[i], left[j], right[j], right[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


def prism_y(bm, points, y0, y1):
    """A solid from an outline in the XZ plane, from y0 to y1."""
    front = [bm.verts.new((x, y0, z)) for x, z in points]
    back = [bm.verts.new((x, y1, z)) for x, z in points]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(points)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], back[i], back[j], front[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


# ======================================================================= KitchenHouse (about 40 x 34, front -Y)

HW, HD, HH = 34.0, 26.0, 16.0  # body width, depth, wall height
RIDGE = 11.0  # roof rise above the walls
OVER = 2.0  # roof overhang


def house_body(bm):
    # The main block with gable ends (the walls rise into the roof's triangle at the front and back).
    prism_y(bm, [(-HW / 2, 0), (HW / 2, 0), (HW / 2, HH), (0, HH + RIDGE - 0.6), (-HW / 2, HH)], -HD / 2, HD / 2)
    # A side wing on the right, lower, with its own roof (breaks up the outline).
    H.box(bm, Vector((HW / 2 + 5, 3, 5.5)), (10, 16, 11))
    # The projecting entrance at the front, with its own gable.
    prism_y(bm, [(-6, 0), (6, 0), (6, 12), (0, 16.5), (-6, 12)], -HD / 2 - 5, -HD / 2 + 0.5)


def house_roof(bm):
    # Two slopes over the main block, with an overhang; the entrance and the wing get their own little roofs.
    half = HW / 2 + OVER
    slope = math.atan2(RIDGE, HW / 2)
    length = math.hypot(half, RIDGE + OVER * RIDGE / (HW / 2))
    for side in (-1, 1):
        rot = Matrix.Rotation(side * slope, 4, "Y")
        centre = Vector((side * half / 2, 0, HH + RIDGE / 2 - OVER * 0.25))
        H.box(bm, centre, (length, HD + 2 * OVER, 0.8), rotation=rot)
    # The entrance's gable roof.
    for side in (-1, 1):
        rot = Matrix.Rotation(side * math.atan2(4.5, 6), 4, "Y")
        H.box(bm, Vector((side * 3.4, -HD / 2 - 2.5, 14.4)), (8.4, 6.6, 0.6), rotation=rot)
    # The wing's lean-to roof, sloping away from the main block.
    H.box(bm, Vector((HW / 2 + 5.5, 3, 11.6)), (12, 18, 0.6), rotation=Matrix.Rotation(-0.25, 4, "Y"))


def house_trim(bm):
    # Corner posts, a band at the top of the walls, window frames and the door frame.
    for x in (-HW / 2, HW / 2):
        for y in (-HD / 2, HD / 2):
            H.box(bm, Vector((x, y, HH / 2)), (1.0, 1.0, HH))
    H.box(bm, Vector((0, -HD / 2 - 0.1, HH - 0.4)), (HW + 1, 0.4, 0.8))
    for x in (-11, 11):
        H.box(bm, Vector((x, -HD / 2 - 0.25, 7)), (7.2, 0.3, 6.2))
    H.box(bm, Vector((0, -HD / 2 - 5.25, 5)), (6.6, 0.3, 9.8))


def house_glass(bm):
    for x in (-11, 11):
        H.box(bm, Vector((x, -HD / 2 - 0.35, 7)), (6, 0.2, 5))
    H.box(bm, Vector((0, -HD / 2 - 5.35, 11.4)), (3.4, 0.2, 1.6))


def house_door(bm):
    # Two door leaves with a gap and a step.
    for x in (-1.45, 1.45):
        H.box(bm, Vector((x, -HD / 2 - 5.4, 4.2)), (2.7, 0.3, 8.4))
    H.box(bm, Vector((0, -HD / 2 - 6.5, 0.25)), (9, 3, 0.5))


def house_sign(bm):
    # The sign board above the entrance roof line, on two posts.
    H.rounded_box(bm, Vector((0, -HD / 2 - 1.2, HH + 3.6)), (22, 0.8, 5.2), 0.3, segments=2)


def house_sign_text(bm):
    B.add_text(bm, "CENTRAL KITCHEN", 2.2, 0.12, H.on_front((0, 0, 0), -HD / 2 - 1.65, HH + 3.6))


def house_awning(bm):
    # A striped awning over each window: alternating red (this) and white (house_awning_white) bands.
    for x in (-11, 11):
        for k in range(6):
            if k % 2 == 0:
                H.box(bm, Vector((x - 3.2 + 1.1 * k + 0.55, -HD / 2 - 1.6, 10.9)), (1.1, 3.0, 0.3),
                      rotation=Matrix.Rotation(-0.35, 4, "X"))


def house_awning_white(bm):
    for x in (-11, 11):
        for k in range(6):
            if k % 2 == 1:
                H.box(bm, Vector((x - 3.2 + 1.1 * k + 0.55, -HD / 2 - 1.6, 10.9)), (1.1, 3.0, 0.3),
                      rotation=Matrix.Rotation(-0.35, 4, "X"))


def house_chimney(bm):
    H.box(bm, Vector((-8, 4, HH + 8)), (3, 3, 12))
    H.box(bm, Vector((-8, 4, HH + 14.2)), (3.8, 3.8, 0.6))


B.piece("KitchenHouse_Body", CREAM, house_body, smooth=False)
B.piece("KitchenHouse_Roof", ROOF, house_roof, smooth=False)
B.piece("KitchenHouse_Trim", TRIM, house_trim, smooth=False)
B.piece("KitchenHouse_Glass", GLASS, house_glass, smooth=False)
B.piece("KitchenHouse_Door", DOOR, house_door, smooth=False)
B.piece("KitchenHouse_Sign", NAVY, house_sign)
B.piece("KitchenHouse_SignText", YELLOW, house_sign_text, smooth=False)
B.piece("KitchenHouse_Awning", STRIPE_RED, house_awning, smooth=False)
B.piece("KitchenHouse_AwningWhite", TRIM, house_awning_white, smooth=False)
B.piece("KitchenHouse_Chimney", BRICK, house_chimney, smooth=False)

# ======================================================================= KitchenHall (the hall's own space)

X0, X1 = -228.0, 228.0
Y0, Y1 = -90.0, 242.0
WALL_H = 34.0
HALL_RIDGE = 38.0
T = 2.0  # wall thickness


def hall_walls(bm):
    # Four walls round the floor, with the exit's doorway gap in the front wall (x -9..9).
    H.span(bm, (X0 - T, Y0 - T, 0), (-9, Y0, WALL_H))
    H.span(bm, (9, Y0 - T, 0), (X1 + T, Y0, WALL_H))
    H.span(bm, (-9, Y0 - T, 14), (9, Y0, WALL_H))
    H.span(bm, (X0 - T, Y1, 0), (X1 + T, Y1 + T, WALL_H))
    H.span(bm, (X0 - T, Y0, 0), (X0, Y1, WALL_H))
    H.span(bm, (X1, Y0, 0), (X1 + T, Y1, WALL_H))
    # The gables: triangles on the front and back walls up to the roof's ridge (ridge along Y).
    for y0, y1 in ((Y0 - T, Y0), (Y1, Y1 + T)):
        prism_y(bm, [(X0 - T, WALL_H), (X1 + T, WALL_H), (0, WALL_H + HALL_RIDGE)], y0, y1)


def hall_band(bm):
    # A red band round the inside of the walls at shoulder height, and a skirting at the floor.
    for z, h in ((7.0, 1.6), (0.6, 1.2)):
        H.span(bm, (X0 + 0.01, Y0 + 0.01, z), (X0 + 0.25, Y1 - 0.01, z + h))
        H.span(bm, (X1 - 0.25, Y0 + 0.01, z), (X1 - 0.01, Y1 - 0.01, z + h))
        H.span(bm, (X0 + 0.01, Y1 - 0.25, z), (X1 - 0.01, Y1 - 0.01, z + h))
        H.span(bm, (X0 + 0.01, Y0 + 0.01, z), (-9.01, Y0 + 0.25, z + h))
        H.span(bm, (9.01, Y0 + 0.01, z), (X1 - 0.01, Y0 + 0.25, z + h))


def hall_roof(bm):
    half = (X1 - X0) / 2 + 3
    slope = math.atan2(HALL_RIDGE, (X1 - X0) / 2)
    length = math.hypot(half, HALL_RIDGE * half / ((X1 - X0) / 2))
    for side in (-1, 1):
        rot = Matrix.Rotation(side * slope, 4, "Y")
        H.box(bm, Vector((side * half / 2, (Y0 + Y1) / 2, WALL_H + HALL_RIDGE / 2 - 1)), (length, Y1 - Y0 + 2 * T + 4, 1.5),
              rotation=rot)


def hall_trusses(bm):
    # Steel trusses across the hall every 40 studs: a tie beam and the two rafters.
    span = (X1 - X0) / 2
    slope = math.atan2(HALL_RIDGE, span)
    rafter = math.hypot(span, HALL_RIDGE)
    y = Y0 + 30
    while y < Y1:
        H.box(bm, Vector((0, y, WALL_H)), (X1 - X0, 1.2, 1.2))
        for side in (-1, 1):
            H.box(bm, Vector((side * span / 2, y, WALL_H + HALL_RIDGE / 2 - 1.6)), (rafter, 1.0, 1.0),
                  rotation=Matrix.Rotation(side * slope, 4, "Y"))
        H.box(bm, Vector((0, y, WALL_H + HALL_RIDGE / 2 - 1)), (1.0, 1.0, HALL_RIDGE - 2))
        y += 40


def hall_floor(bm, red):
    # A checked floor of 12-stud tiles (top faces only: a surface), red where (i + j) is even.
    size = 12.0
    i = 0
    x = X0
    while x < X1 - 0.01:
        j = 0
        y = Y0
        while y < Y1 - 0.01:
            if ((i + j) % 2 == 0) == red:
                x1, y1 = min(x + size, X1), min(y + size, Y1)
                v = [bm.verts.new((x, y, 0.05)), bm.verts.new((x1, y, 0.05)), bm.verts.new((x1, y1, 0.05)), bm.verts.new((x, y1, 0.05))]
                bm.faces.new(v)
            y += size
            j += 1
        x += size
        i += 1


def hall_exit_door(bm):
    for x in (-4.4, 4.4):
        H.box(bm, Vector((x, Y0 - T / 2, 6.5)), (8.6, 0.5, 13))


def hall_exit_sign(bm):
    H.rounded_box(bm, Vector((0, Y0 + 0.4, 17.5)), (9, 0.4, 3.2), 0.2, segments=1)


def hall_exit_text(bm):
    # Read from inside the hall (looking toward -Y): its text faces +Y, so it is written along -X.
    def place(x, up, depth):
        return Vector((-x, Y0 + 0.65 + depth, 17.5 + up))
    B.add_text(bm, "EXIT", 2.2, 0.1, place)


def hall_back_sign(bm):
    # KITCHEN in big letters high on the back wall, facing the hall (toward -Y).
    B.add_text(bm, "CENTRAL KITCHEN", 16.0, 0.5, H.on_front((0, 0, 0), Y1 - 0.6, WALL_H - 10))


B.piece("KitchenHall_Walls", TILE, hall_walls, smooth=False)
B.piece("KitchenHall_Band", STRIPE_RED, hall_band, smooth=False)
B.piece("KitchenHall_Roof", HALL_ROOF, hall_roof, smooth=False)
B.piece("KitchenHall_Trusses", STEEL, hall_trusses, smooth=False)
B.piece("KitchenHall_FloorRed", FLOOR_RED, lambda bm: hall_floor(bm, True), smooth=False)
B.piece("KitchenHall_FloorWhite", FLOOR_WHITE, lambda bm: hall_floor(bm, False), smooth=False)
B.piece("KitchenHall_ExitDoor", DOOR, hall_exit_door, smooth=False)
B.piece("KitchenHall_ExitSign", NAVY, hall_exit_sign)
B.piece("KitchenHall_ExitText", GREEN, hall_exit_text, smooth=False)
B.piece("KitchenHall_BackSign", YELLOW, hall_back_sign, smooth=False)

# The hall's pieces are big on purpose (the whole hall): give them their own budgets (check_models' tri_budget).
for ob in B.coll.objects:
    if ob.name.startswith("KitchenHall_"):
        ob["tri_budget"] = 12000

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if argv:
    bpy.ops.wm.save_as_mainfile(filepath=argv[0])
if len(argv) >= 2:
    bpy.ops.object.select_all(action="DESELECT")
    for ob in B.coll.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=argv[1], export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
print("KITCHEN BUILDING BUILT:", [o.name for o in B.coll.objects])
