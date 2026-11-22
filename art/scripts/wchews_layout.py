"""W Chews' layout: where every kit item stands (GAME_DESIGN §40.7, floor plan 02, user 2026-11-21).

ONE list for both the Blender preview (art/scripts/preview_wchews.py) and the game (write_luau() makes
src/shared/Config/WChewsLayout.luau, which KitchenBuilding places from), so the picture the user approves and the
game can't drift apart.

PLAN space, as build_wchews_hall_01.py: x across (+x = the walking-in player's RIGHT), y front to back, z up.
A placement is (item, colourway, x, y, z, turn, scale): the item's own origin goes to (x, y, z); `turn` is degrees
anticlockwise seen from above (0 = its front toward the entrance, -y; 180 = its front toward the back).
"""
import math

PAN_COLUMNS = (-234.0, -182.0, -130.0, -78.0, 78.0, 130.0, 182.0, 234.0)
PAN_ROWS = (34.0, 82.0, 130.0, 178.0, 226.0)
KITCHEN_HEIGHT = 36.0
FRONT_HEIGHT = 22.0
TUBE_HEIGHT = 26.0  # the meat tube's axis
BAY = (0.0, 36.0)  # the meat display bay's centre
GRINDER_SCALE = 2.0  # 13 x 19.4 x 27 studs: big enough to read from the doors, and for a cow
GRINDER = (0.0, 57.6)  # the grinder's centre (its outlet reaches 2 studs into the bay's open back)
CHUTE = (0.0, 61.4)  # over the grinder's tub
CHUTE_MOUTH = 24.0
TRUNK_Y = 10.0
CHEF = (0.0, -25.4)  # close behind his counter (its back edge is y -28.1): you talk to him across it
BIG = 1.6  # the kitchen's wall equipment is built for the giant pans' world
# The kitchen's back wall (its inside face; the wall is WALL thick) and the EMPLOYEES ONLY doorway through it: a
# DOUBLE door in the MIDDLE of the wall (user 2026-11-22: "like a double door ... move the room, and the door to the
# middle of the wall"). Everything about the back room is measured from DOOR_X, so the doorway and the room behind it
# move together by changing that one number.
BACK_WALL_Y = 265.0
WALL = 2.0
DOOR_X = 0.0  # the doorway's middle
DOOR_HALF = 8.0  # the doorway is 16 wide
DOOR_HEIGHT = 13.0
# The two door leaves (WcDoubleDoor, build_wchews_door_01.py): each hangs on its outer edge, LEAF_HINGE from the
# doorway's middle, and turns on the corner of that edge on the back room's side (LEAF_HALF_THICK behind the wall's
# middle line), into the back room.
LEAF_HINGE = 7.6
LEAF_HALF_THICK = 0.15
# The back room (18 high): 90 wide and 70 deep behind the wall, its doorway 53 from its left wall as it always was.
BACK_HEIGHT = 18.0
BACK_ROOM = (DOOR_X - 53.0, DOOR_X + 37.0, BACK_WALL_Y + WALL, BACK_WALL_Y + WALL + 70.0)  # x0, x1, y0, y1 (inside)
BACK_DX = DOOR_X - 248.0  # (the room was laid out round a doorway at x 248: every back room point moves by this)
WHEEL = (248.0 + BACK_DX, 331.0)  # the luck wheel's stand; its axis is WHEEL_AXIS up
WHEEL_AXIS = 7.6
WHEEL_WEDGES = 20
COW = (262.0 + BACK_DX, 321.0)  # the mafia boss cow stands here, beside his wheel, facing the door (-y)
COW_NECK = (0.0, 0.0, 5.1)  # his joints in his own model's space (write_wchews_layout.py reads the real ones)
COW_SHOULDER = (-1.75, 0.0, 4.75)
ARM_TABLE = (216.0 + BACK_DX, 298.0)
SHUFFLE_TABLE = (271.0 + BACK_DX, 294.0)
# The prep islands stand in two lines either side of a wide middle aisle that runs from the grinder to the double door
# (they stood at x -15 and 15, across the middle, until the door moved there).
ISLAND_XS = (-36.0, 36.0)
ISLAND_YS = (104.0, 152.0, 200.0)  # between the pans' rows: the left pans' handles reach x -47
ISLAND_SCALE = 2.0
# The back wall's prep counters: 13 places 12.8 apart; the three in the middle are left out for the double door.
COUNTER_PLACES = tuple(k for k in range(13) if abs(-76.8 + 12.8 * k - DOOR_X) > 19.0)
CLOCHE_XS = (-2.7, 0.0, 2.7)  # the three cloches' places along the shuffle table
TABLE_TOP = 3.33  # both game tables' tops

P = []  # (item, colourway, x, y, z, turn, scale)


def put(item, x, y, z=0.0, turn=0.0, scale=1.0, colourway=1):
    P.append((item, colourway, round(x, 3), round(y, 3), round(z, 3), turn % 360, scale))


# ---- the cooking line under hoods: along the kitchen's front wall, both sides of the opening, facing the kitchen
LINE = ["WcRange", "WcRange", "WcCounter", "WcFryer", "WcRange", "WcCounter", "WcRange", "WcRange", "WcFryer",
        "WcCounter", "WcRange", "WcRange", "WcCounter", "WcFryer"]
for side in (-1, 1):
    for k, item in enumerate(LINE):
        x = side * (98.4 + 12.8 * k)
        put(item, x, -20 + 1.5 * BIG, 0, 180, BIG)
        put("WcHood", x, -20 + 1.7 * BIG + 0.2, 11.5, 180, BIG)

# ---- the back wall: cold storage (left), prep counters (middle), sinks (right), facing the kitchen
for k in range(18):
    put("WcFridge", -275.2 + 9.6 * k, 265 - 1.5 * BIG, 0, 0, BIG)
for k in COUNTER_PLACES:
    put("WcCounter", -76.8 + 12.8 * k, 265 - 1.5 * BIG, 0, 0, BIG)
for k in range(9):
    put("WcSink", 106.4 + 12.8 * k, 265 - 1.5 * BIG, 0, 0, BIG)
# (the three counters the double door displaced stand where the old single door was, past the sinks)
for k in range(13 - len(COUNTER_PLACES)):
    put("WcCounter", 228.0 + 12.8 * k, 265 - 1.5 * BIG, 0, 0, BIG)
put("WcDoubleDoor", DOOR_X, BACK_WALL_Y + WALL / 2, 0, 0, 1.0)

# ---- prep islands either side of the middle aisle, behind the grinder
for y in ISLAND_YS:
    for x in ISLAND_XS:
        put("WcIsland", x, y, 0, 0, ISLAND_SCALE)

# ---- the chef scene's machines, on the centre line
put("WcBay", BAY[0], BAY[1])
put("WcTubeIntake", BAY[0], BAY[1])
put("WcChute", CHUTE[0], CHUTE[1], CHUTE_MOUTH)
put("WcTubeTrunk", 0, TRUNK_Y, TUBE_HEIGHT, 0)
put("WcTubeTrunk", 0, TRUNK_Y, TUBE_HEIGHT, 180)
for x in PAN_COLUMNS:
    put("WcTubeBranch", x, TRUNK_Y, TUBE_HEIGHT)
# The start button, to the chef's left (he faces the entrance): scale 0.6 puts the button's top 2.5 studs up, under
# his palm in Chef_ButtonPress (KitchenConfig.ChefPress).
put("WcButtonPanel", 4.6, -25.4, 0, 0, 0.6)

# ---- the fancy front: the service counter, dining tables under hanging lights, the host stand, plants
for k in range(8):
    put("WcBar", -42 + 12 * k, -30)
TABLES = [(s * x, y) for y in (-96, -78, -60, -42) for x in (24, 46, 68) for s in (-1, 1)]
for n, (x, y) in enumerate(TABLES):
    put("WcTable", x, y)
    put("WcPendant", x, y, FRONT_HEIGHT - 7.0 * 1.8, 0, 1.8)
    for c in range(4):
        a = math.radians(45 + 90 * c)
        # The chair's front (-y) is the way the sitter faces: toward the table.
        put("WcChair", x + 3.7 * math.cos(a), y + 3.7 * math.sin(a), 0, math.degrees(a) - 90, 1.0, 1 + n % 3)
for x in (-30, -10, 10, 30):
    put("WcPendant", x, -30, FRONT_HEIGHT - 7.0 * 1.8, 0, 1.8)
# One chandelier over the carpet just inside the doors (its rose is 6.6 above the origin at scale 1). None further
# in: from the doors it would hang across the W CHEWS letters over the opening.
put("WcChandelier", 0, -90, FRONT_HEIGHT - 6.6 * 1.3, 0, 1.3)
put("WcHostStand", -13, -101)
for x, y in ((-76, -106), (76, -106), (-76, -26), (76, -26), (-12.5, -107), (12.5, -107)):
    put("WcPlant", x, y, 0, 0, 1.5)

# ---- the back room (WChewsBack_01; the wheel's 20 wedges are placed by code: they turn and are painted by prize).
# Laid out round a doorway at x 248 (where it first stood); `room` moves a point with the doorway.


def room(item, x, y, z=0.0, turn=0.0, scale=1.0, colourway=1):
    put(item, x + BACK_DX, y, z, turn, scale, colourway)


put("WcWheelStand", WHEEL[0], WHEEL[1])
put("WcRopeSpan", WHEEL[0] - 6.5, WHEEL[1] - 8)
put("WcRopeSpan", WHEEL[0] + 6.5, WHEEL[1] - 8)
room("WcBossDesk", 272, 319)
room("WcBossChair", 272, 323.6)
put("WcArmTable", ARM_TABLE[0], ARM_TABLE[1])
put("WcShuffleTable", SHUFFLE_TABLE[0], SHUFFLE_TABLE[1])
for dx in CLOCHE_XS:
    put("WcCloche", SHUFFLE_TABLE[0] + dx, SHUFFLE_TABLE[1], TABLE_TOP)
# Booths with their backs to the side walls (turn 90 = facing +x, 270 = facing -x), a portrait over each.
room("WcBooth", 197.0, 284, 0, 90)
room("WcBooth", 197.0, 297, 0, 90, 1.0, 2)
room("WcBooth", 283.0, 277, 0, 270, 1.0, 2)
room("WcPortrait", 195.02, 284, 10.3, 90)
room("WcPortrait", 195.02, 297, 10.3, 90, 1.0, 2)
room("WcPortrait", 284.98, 277, 10.3, 270, 1.0, 3)
room("WcPortrait", 284.98, 303, 10.3, 270)
room("WcPortrait", 264, 267.32, 10.3, 180, 1.0, 2)  # (2 further from the doorway than before: the double door is wider)
room("WcPortrait", 277, 267.32, 10.3, 180, 1.0, 3)
# The milk bar against the kitchen-side wall, left of the door: the shelf, a counter module of the restaurant's,
# four stools.
MILK_BAR = (218.0 + BACK_DX, 274.6)
room("WcMilkShelf", 218, 268.4, 0, 180)
put("WcBar", MILK_BAR[0], MILK_BAR[1], 0, 180)
for k in range(4):
    room("WcStool", 213.5 + 3.0 * k, 278.6)
room("WcNeonMoo", 222, 336.95, 12.6)
room("WcRug", 248, 298)
# Lights (the restaurant's own fittings) and plants.
room("WcChandelier", 248, 298, BACK_HEIGHT - 6.6)
BACK_PENDANTS = (ARM_TABLE, SHUFFLE_TABLE, (272 + BACK_DX, 319), (218 + BACK_DX, 276))
for x, y in BACK_PENDANTS:
    put("WcPendant", x, y, BACK_HEIGHT - 7.0)
for x, y in ((199, 333), (282, 334), (200, 270.5)):
    room("WcPlant", x, y, 0, 0, 1.5)
# The room's soft fill lights (KitchenLights): x, y, height.
BACK_FILLS = tuple((x + BACK_DX, y, z) for x, y, z in ((212, 300, 13), (282, 300, 13), (248, 284, 14), (224, 328, 12),
                                                        (272, 326, 12)))

PLACEMENTS = tuple(P)


def back_wall_runs():
    """The fridges, counters and sinks along the back wall as runs (x0, x1): the hidden blocks nobody walks through."""
    half = {"WcFridge": 3.0, "WcCounter": 4.0, "WcSink": 4.0}
    spans = [(x - half[item] * s, x + half[item] * s) for item, _, x, y, _, _, s in P
             if item in half and abs(y - (BACK_WALL_Y - 1.5 * BIG)) < 0.01]
    runs = []
    for a, b in sorted(spans):
        if runs and a - runs[-1][1] < 4.0:  # (a gap nobody could walk through: one run)
            runs[-1][1] = max(runs[-1][1], b)
        else:
            runs.append([a, b])
    return [(round(a, 2), round(b, 2)) for a, b in runs]


def write_luau(path, bounds):
    """The game's copy: plan-space placements plus each item's pivot offset (a copy is pivoted at the bottom centre of
    its bounds: `bounds` is build_wchews_kit_01.py's <blend>_bounds.json)."""
    lines = [
        "--!strict",
        "-- GENERATED by art/scripts/wchews_layout.py (write_luau): do not edit by hand, edit that file and run",
        "-- art/scripts/write_wchews_layout.py. W Chews' kit placements in PLAN space (GAME_DESIGN §40.7, floor plan 02):",
        "-- x across (+x = the walking-in player's right), y front to back, z up; the hall's own space is (-x, z, y).",
        "",
        "local WChewsLayout = {}",
        "",
        "-- From an item's own origin to the bottom centre of its bounds (where a copy's pivot is), plan space, scale 1.",
        "WChewsLayout.PivotOffset = {",
    ]
    for item, b in sorted(bounds.items()):
        lo, hi = b["low"], b["high"]
        lines.append(f"\t{item} = Vector3.new({(lo[0] + hi[0]) / 2:.4f}, {(lo[1] + hi[1]) / 2:.4f}, {lo[2]:.4f}),")
    lines += ["} :: { [string]: Vector3 }", "",
              "-- The plan's key numbers (plan space).",
              "WChewsLayout.PanColumns = { " + ", ".join(f"{x:g}" for x in PAN_COLUMNS) + " }",
              "WChewsLayout.PanRows = { " + ", ".join(f"{y:g}" for y in PAN_ROWS) + " }",
              f"WChewsLayout.KitchenHeight = {KITCHEN_HEIGHT:g}",
              f"WChewsLayout.FrontHeight = {FRONT_HEIGHT:g}",
              f"WChewsLayout.TubeHeight = {TUBE_HEIGHT:g} -- the meat tube's axis",
              f"WChewsLayout.TrunkY = {TRUNK_Y:g} -- the trunk runs across at this y",
              f"WChewsLayout.Bay = Vector2.new({BAY[0]:g}, {BAY[1]:g}) -- the meat display bay's centre",
              f"WChewsLayout.Grinder = Vector2.new({GRINDER[0]:g}, {GRINDER[1]:g}) -- the grinder's centre, its outlet toward -y",
              f"WChewsLayout.GrinderScale = {GRINDER_SCALE:g}",
              f"WChewsLayout.Chute = Vector2.new({CHUTE[0]:g}, {CHUTE[1]:g})",
              f"WChewsLayout.ChuteMouth = {CHUTE_MOUTH:g} -- the chute's mouth above the floor",
              f"WChewsLayout.Chef = Vector2.new({CHEF[0]:g}, {CHEF[1]:g}) -- he faces the entrance (-y)",
              "-- The kitchen's back wall (y from BackWallY, WallThickness thick) and the EMPLOYEES ONLY doorway in its middle:",
              "-- a double door (WcDoubleDoor). Each leaf turns on a hinge line LeafHinge from the doorway's middle, on the",
              "-- back room's side of the leaf (LeafHingeY), opening into the back room.",
              f"WChewsLayout.BackWallY = {BACK_WALL_Y:g}",
              f"WChewsLayout.WallThickness = {WALL:g}",
              f"WChewsLayout.BackDoor = {{ X0 = {DOOR_X - DOOR_HALF:g}, X1 = {DOOR_X + DOOR_HALF:g}, Middle = {DOOR_X:g}, Height = {DOOR_HEIGHT:g} }}",
              f"WChewsLayout.LeafHinge = {LEAF_HINGE:g}",
              f"WChewsLayout.LeafHingeY = {BACK_WALL_Y + WALL / 2 + LEAF_HALF_THICK:g}",
              "-- The runs of furniture along the back wall, either side of the double door (x0, x1), and the line they",
              "-- stand out to.",
              "WChewsLayout.BackWallRuns = { " + ", ".join(f"{{ {a:g}, {b:g} }}" for a, b in back_wall_runs()) + " }",
              f"WChewsLayout.BackWallRunY = {BACK_WALL_Y - 7.5:g}",
              "-- The prep islands (two lines either side of the middle aisle): their middles, and half their size across.",
              "WChewsLayout.IslandXs = { " + ", ".join(f"{x:g}" for x in ISLAND_XS) + " }",
              "WChewsLayout.IslandYs = { " + ", ".join(f"{y:g}" for y in ISLAND_YS) + " }",
              f"WChewsLayout.IslandHalf = {7.0 * ISLAND_SCALE:g}",
              "-- The back room behind the double door (its inside faces; its walls are WallThickness thick).",
              f"WChewsLayout.BackRoom = {{ X0 = {BACK_ROOM[0]:g}, X1 = {BACK_ROOM[1]:g}, Y0 = {BACK_ROOM[2]:g}, Y1 = {BACK_ROOM[3]:g} }}",
              f"WChewsLayout.BackHeight = {BACK_HEIGHT:g}",
              f"WChewsLayout.MilkBar = Vector2.new({MILK_BAR[0]:g}, {MILK_BAR[1]:g}) -- the milk bar's counter (12 x 4)",
              "-- The back room's soft fill lights (x, y, height).",
              "WChewsLayout.BackFills = { " + ", ".join(f"Vector3.new({x:g}, {y:g}, {z:g})" for x, y, z in BACK_FILLS) + " }",
              f"WChewsLayout.Wheel = Vector2.new({WHEEL[0]:g}, {WHEEL[1]:g}) -- the luck wheel's stand, facing the door (-y)",
              f"WChewsLayout.WheelAxis = {WHEEL_AXIS:g} -- the wheel's axis above the floor",
              f"WChewsLayout.WheelWedges = {WHEEL_WEDGES:g}",
              f"WChewsLayout.Cow = Vector2.new({COW[0]:g}, {COW[1]:g}) -- the mafia boss cow, facing the door (-y)",
              "-- His joints in his own model's space (x across, y front to back with his front at -y, z up): his head",
              "-- pieces (CowBoss_Head*) turn round the neck, his right arm's (CowBoss_ArmR*) round the shoulder.",
              f"WChewsLayout.CowNeck = Vector3.new({COW_NECK[0]:g}, {COW_NECK[1]:g}, {COW_NECK[2]:g})",
              f"WChewsLayout.CowShoulder = Vector3.new({COW_SHOULDER[0]:g}, {COW_SHOULDER[1]:g}, {COW_SHOULDER[2]:g})",
              f"WChewsLayout.ArmTable = Vector2.new({ARM_TABLE[0]:g}, {ARM_TABLE[1]:g})",
              f"WChewsLayout.ShuffleTable = Vector2.new({SHUFFLE_TABLE[0]:g}, {SHUFFLE_TABLE[1]:g})",
              "WChewsLayout.ClocheXs = { " + ", ".join(f"{x:g}" for x in CLOCHE_XS) + " } -- along the shuffle table",
              f"WChewsLayout.TableTop = {TABLE_TOP:g} -- the game tables' tops",
              "",
              "-- { item, colourway, x, y, z, turn (degrees anticlockwise from above), scale }",
              "WChewsLayout.Placements = {"]
    for item, colourway, x, y, z, turn, scale in PLACEMENTS:
        lines.append(f'\t{{ "{item}", {colourway}, {x:g}, {y:g}, {z:g}, {turn:g}, {scale:g} }},')
    lines += ["} :: { { any } }", "", "return WChewsLayout", ""]
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines))
