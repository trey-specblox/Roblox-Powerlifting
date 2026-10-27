--!strict
--[[
	StarterGymConfig
	Shared / Config

	The Starter Gym building, "version 2" (GAME_DESIGN.md §27, approved
	2026-10-21). StarterGymBuilder builds it at server start, around the rack
	rows of TrainingStationConfig.GymLayout:

	  - a double-height RACK HALL in the middle (all 30 racks);
	  - two-floor ROOM BLOCKS on the left, the right and the front, every room
	    with a glass front onto the hall (decoration only for now; NPCs later);
	  - the ENTRANCE in the front block: glass front, lobby with the spawn.

	Built in stages. Stage 1: floors, upper floor slabs, the room blocks'
	ceilings, every wall and glass front, the rooms. Stage 2: one pitched roof
	over the whole building with skylights over the hall, gable walls and steel
	roof beams. Stage 3: the balcony and the two glass staircases. Stage 4:
	the reception desk, the gym-name wall and the outside name sign, and
	(2026-10-23) automatic sliding doors in the entrance and the hall opening.
	Stage 5: room ceilings and lights.

	The building's size is WORKED OUT from GymLayout, so adding racks or rows
	moves the walls with it. Directions (as in GymLayout): the entrance is at
	-Z and the rows go back toward +Z. Walking in (toward +Z), your LEFT is +X.

	=========================================================================
	EVERY VALUE BELOW IS A PROVISIONAL STARTING VALUE, NOT FINAL.
	=========================================================================
]]

local StarterGymConfig = {}

-- How much room a rack needs around its position (ComboRack_01, facing 0;
-- StationLayout: deadlift stance 4.8 and exit spot 6.2 in front).
StarterGymConfig.RackFrontClearanceStuds = 7.0
StarterGymConfig.RackBackReachStuds = 2.05

-- The rack hall around the rows.
StarterGymConfig.SideAisleStuds = 14 -- beyond the outermost rack's half-spacing, each side
StarterGymConfig.BackAisleStuds = 14 -- behind the last row's racks
-- In front of row 1's lifting space: the front balcony (12) and the stairs
-- behind it (8) stand here, with a 10-stud walkway left before the racks.
-- Kept in step with GymLayout.firstRowZ so the lobby does not move.
StarterGymConfig.FrontOpenAreaStuds = 30

-- The room blocks.
StarterGymConfig.SideBlockDepthStuds = 30 -- left and right blocks, across (X)
StarterGymConfig.FrontBlockDepthStuds = 32 -- front block, front to back (Z)
StarterGymConfig.StoreyHeightStuds = 14 -- floor to floor; the hall's walls are two storeys tall
StarterGymConfig.SlabThicknessStuds = 1 -- upper floors and the blocks' flat roofs

StarterGymConfig.WallThicknessStuds = 1
StarterGymConfig.WallBandHeightStuds = 3 -- the dark strip along the bottom of the outer walls
StarterGymConfig.FloorThicknessStuds = 1

-- Openings.
-- The lobby, in the middle of the front block. 90 since 2026-10-21 (was 70):
-- the user asked for a bigger entrance so the reception desk can be bigger.
StarterGymConfig.LobbyWidthStuds = 90
StarterGymConfig.LobbyOpeningWidthStuds = 46 -- the wide opening from the lobby into the hall
StarterGymConfig.LobbyOpeningHeightStuds = 10
StarterGymConfig.EntranceWidthStuds = 16 -- in the glass front of the lobby
StarterGymConfig.EntranceHeightStuds = 10
StarterGymConfig.RoomDoorWidthStuds = 6
StarterGymConfig.RoomDoorHeightStuds = 9

--[[
	The roof (stage 2; GAME_DESIGN §27): ONE pitched roof over the WHOLE
	building, no flat roof tops (user, 2026-10-21). The ridge runs left to right
	(X) over the middle of the building; the two slopes come down to the front
	and back outer walls (the eaves, at the walls' top). The left and right ends
	are closed by triangular gable walls on the outer side walls.

	Under the roof, the room blocks keep flat CEILINGS over their upper rooms
	(hidden by the roof), and walls above the hall's glass fronts close the
	hall off from the space under the roof over the rooms.
]]
StarterGymConfig.RoofRiseStuds = 21 -- the ridge above the eaves (about 17 degrees)
StarterGymConfig.RoofThicknessStuds = 1
StarterGymConfig.RoofOverhangStuds = 1 -- past the gable walls at each end
-- Skylights: only over the rack hall (the rooms have ceilings). On each slope a
-- band that starts SkylightStartFromRidgeStuds from the ridge and reaches
-- SkylightDepthStuds further toward the eave (measured front to back), split
-- into separate windows along the ridge.
StarterGymConfig.SkylightStartFromRidgeStuds = 6
StarterGymConfig.SkylightDepthStuds = 21
StarterGymConfig.SkylightsPerSlope = 6
StarterGymConfig.SkylightGapStuds = 6 -- solid roof between two skylights
-- Exposed steel roof beams, evenly spaced along the hall: two rafters under
-- the slopes and a tie beam across at eave height each, and one ridge beam.
StarterGymConfig.RoofBeamCount = 9
StarterGymConfig.RoofBeamWidthStuds = 1
StarterGymConfig.RoofBeamDepthStuds = 1.5

--[[
	The balcony and the glass staircases (stage 3; GAME_DESIGN §27). The balcony
	is a U-shaped walkway on the upper floor's level around the left, front and
	right sides of the hall, in front of every upstairs room, with a glass
	railing. Two glass staircases rise from the hall's front corners, right
	where you walk in from the lobby: each runs along the front of the hall,
	just behind the balcony, up toward its corner and lands on the side
	balcony. They must leave every room door clear (checked by
	StarterGym_VerifyShell).
]]
-- Wide enough for 2-3 characters side by side, bulkier future players
-- included (user, 2026-10-21): a bulky character is about 3 studs wide.
StarterGymConfig.BalconyDepthStuds = 12
StarterGymConfig.RailingHeightStuds = 3.5
StarterGymConfig.RailingThicknessStuds = 0.3
StarterGymConfig.HandrailSizeStuds = 0.4
StarterGymConfig.ColumnSizeStuds = 1 -- steel columns under the balcony's inner edge
StarterGymConfig.StairWidthStuds = 8
StarterGymConfig.StairStepRiseStuds = 1 -- StoreyHeightStuds / this = the number of steps
StarterGymConfig.TreadThicknessStuds = 0.4
-- Where a staircase starts, measured in from the hall's side wall. It ends at
-- the side balcony (BalconyDepthStuds in), so it is this minus the balcony
-- long: 30 - 12 = 18 studs for the 14-stud climb.
StarterGymConfig.StairBottomFromSideStuds = 30

--[[
	The gym's name and the reception (stage 4; GAME_DESIGN §27, user
	2026-10-21), styled after the Academia 2.0 reception photo: a white
	counter with a glowing base, a computer, entrance gates, linear lights.

	  - the name wall: a dark sign on the lobby's left wall (as you walk in),
	    standing off the wall with a glowing halo round its edges, above the
	    reception desk in front of it;
	  - the outside sign: the same, on the front of the building above the
	    entrance, lit by two spotlights;
	  - the desk: a white counter (raised front ledge, work surface behind,
	    LED glow along its base), monitor, keyboard and card reader;
	  - entrance gates across the lobby, in front of the hall: turnstiles and
	    steel railings, with a wide free lane in the middle. Decoration only:
	    the turnstile arms are not solid, so nobody is ever blocked;
	  - a merch wall (shelves with shirts and shakers) opposite the desk;
	  - a white lobby ceiling with long LED strips and a light bar over the desk.
]]
StarterGymConfig.GymName = "ELITE PREP GYM"
StarterGymConfig.SignThicknessStuds = 0.3
StarterGymConfig.SignStandOffStuds = 0.6 -- the gap between a sign and its wall, where the halo glows
StarterGymConfig.SignHaloStuds = 0.25 -- how far the halo shows round the sign's edges
StarterGymConfig.NameWallHeightStuds = 7
StarterGymConfig.NameWallBottomStuds = 5 -- above the lobby floor, so the desk does not hide it
StarterGymConfig.FrontSignWidthStuds = 60
StarterGymConfig.FrontSignHeightStuds = 8
StarterGymConfig.FrontSignBottomStuds = 15 -- above the floor, on the wall above the lobby's glass front
-- The desk: in front of the name wall (which is as long as the desk), facing the middle of the lobby.
StarterGymConfig.DeskLengthStuds = 22
StarterGymConfig.DeskDepthStuds = 3.5
StarterGymConfig.DeskCounterHeightStuds = 4.4 -- the front ledge customers lean on
StarterGymConfig.DeskWorkHeightStuds = 3 -- the work surface behind it
StarterGymConfig.DeskGapToWallStuds = 6 -- room behind the desk for the receptionist (an NPC later)
StarterGymConfig.DeskCentreFromFrontStuds = 15 -- the desk's middle, from the lobby's front wall
-- An uploaded image cut into pieces (Roblox shrinks images wider than 1024
-- pixels), shown side by side, left to right, as one picture.
export type ImagePiece = { image: string, widthPixels: number }

-- The desk's whole front as ONE picture (user, 2026-10-21): their "SBD
-- Central" logo banner on a white background with chrome trim, a black band
-- with red lines behind the letters and red and black speed slashes. Drawn by
-- `art/scripts/build_desk_front.ps1` (22 x 4.1 studs, 3072 x 573 pixels) and
-- cut into `art/logos/EPG_DeskFront_1-3.png`, because the same details drawn
-- in Roblox had jagged edges and flickered. Each piece uploaded with the
-- game's group as creator; IDs as "rbxassetid://<number>", left to right.
-- Any piece empty = a plain white desk front.
StarterGymConfig.DeskFrontPieces = {
	{ image = "rbxassetid://133447969053464", widthPixels = 1024 }, -- EPG_DeskFront_1 (left end)
	{ image = "rbxassetid://126387502452428", widthPixels = 1024 }, -- EPG_DeskFront_2
	{ image = "rbxassetid://116605252867039", widthPixels = 1024 }, -- EPG_DeskFront_3 (right end)
} :: { ImagePiece }
-- The gym-name signs' background art behind "ELITE PREP GYM" (user,
-- 2026-10-21: a muscular back; the name stays big in the middle, over it).
-- Name wall: the user's 2170 x 725 artwork cropped to the wall's 22 x 7
-- (2170 x 690) and cut into `art/logos/EPG_NameWallArt_1-3.png`; its
-- see-through edges fade into the dark panel. Any image ID empty = a plain
-- dark sign.
StarterGymConfig.NameSignArt = {
	{ image = "rbxassetid://79949429252377", widthPixels = 723 }, -- EPG_NameWallArt_1 (left end)
	{ image = "rbxassetid://95378292317440", widthPixels = 723 }, -- EPG_NameWallArt_2
	{ image = "rbxassetid://98882870153735", widthPixels = 724 }, -- EPG_NameWallArt_3 (right end)
} :: { ImagePiece }
StarterGymConfig.NameSignArtHeightPixels = 690
-- Outside sign (60 x 8, 7.5 times wider than tall): the same art made wide
-- by `art/scripts/build_front_sign_art.ps1` so it fills the WHOLE sign
-- (user, 2026-10-21): the sharp figure in the middle on a blurred, darkened,
-- enlarged copy of itself. Cut into `art/logos/EPG_FrontSignArt_1-4.png`.
StarterGymConfig.FrontSignArt = {
	{ image = "rbxassetid://82111432062100", widthPixels = 960 }, -- EPG_FrontSignArt_1 (left end)
	{ image = "rbxassetid://111820337142904", widthPixels = 960 }, -- EPG_FrontSignArt_2
	{ image = "rbxassetid://79408703692167", widthPixels = 960 }, -- EPG_FrontSignArt_3
	{ image = "rbxassetid://118298598117791", widthPixels = 960 }, -- EPG_FrontSignArt_4 (right end)
} :: { ImagePiece }
StarterGymConfig.FrontSignArtHeightPixels = 512
-- The user's own "SBD Central" logo banner (barbell over "SBD CENTRAL",
-- transparent, 2172 x 564), the pieces first uploaded for the desk
-- (art/logos/SBDCentral_DeskBanner_1-3.png, Group 529442797). The Shop's
-- logo wall and counter show it on black (user, 2026-10-23: like an SBD stand).
StarterGymConfig.ShopLogoPieces = {
	{ image = "rbxassetid://72367430802433", widthPixels = 724 }, -- SBDCentral_DeskBanner_1 (left)
	{ image = "rbxassetid://137359481610495", widthPixels = 724 }, -- SBDCentral_DeskBanner_2
	{ image = "rbxassetid://72007290259241", widthPixels = 724 }, -- SBDCentral_DeskBanner_3 (right)
} :: { ImagePiece }
StarterGymConfig.ShopLogoHeightPixels = 564
-- Where the Shop's gear models live (art/roblox/ShopGear_01.rbxmx, Rojo-mapped).
StarterGymConfig.ShopGearTemplate = "ShopGear_01"
-- The gates: a line across the lobby this far in front of the hall's glass.
StarterGymConfig.GateLineFromHallStuds = 5
StarterGymConfig.GateFreeLaneStuds = 16 -- the open middle lane (as wide as the entrance)
StarterGymConfig.GateLaneStuds = 4 -- each turnstile lane
StarterGymConfig.TurnstilesPerSide = 2
-- The lights.
StarterGymConfig.CeilingStripCount = 4
StarterGymConfig.CeilingStripWidthStuds = 0.4
StarterGymConfig.SignTextColor = Color3.fromRGB(255, 255, 255)
StarterGymConfig.SignAccentColor = Color3.fromRGB(200, 32, 40) -- the red of the 25 kg plates
StarterGymConfig.LightColor = Color3.fromRGB(255, 250, 240) -- a clean, slightly warm white

--[[
	Lighting (stage 5; References/Visual Style: "bright, clean, even
	lighting"). The Lighting service's own settings (ambient light, time of
	day, Future lighting) are in default.project.json, which Rojo applies.
	Here: what StarterGymBuilder adds to the building.

	  - white ceilings under the ground-floor rooms and under the balcony, so
	    nobody looks up at the upper floor's tiles;
	  - in the rack hall: long LED light bars hanging under the steel beams,
	    front to back, in a few segments each;
	  - in every room except the lobby (which has its own LED strips): one
	    square LED panel in the middle of the ceiling.

	Every light is a SurfaceLight shining down from a glowing (Neon) part,
	without shadows (cheaper, and the rooms stay evenly lit).
]]
StarterGymConfig.CeilingThicknessStuds = 0.2
StarterGymConfig.HallLightDropStuds = 2 -- how far the light bars hang below the steel beams
StarterGymConfig.HallLightSegmentsPerRow = 3
StarterGymConfig.HallLightGapStuds = 4 -- between two segments of a row
StarterGymConfig.HallLightWidthStuds = 0.6
StarterGymConfig.HallLightRange = 40 -- the bars hang about 24 studs above the floor
StarterGymConfig.HallLightBrightness = 1.5
StarterGymConfig.RoomLightPanelStuds = 6
StarterGymConfig.RoomLightRange = 18 -- a storey is 14 studs high
StarterGymConfig.RoomLightBrightness = 1.2
-- Rooms that bring their own (warm) lights in RoomProps and get no white panel.
StarterGymConfig.OwnLightRooms = { Sauna = true }

--[[
	The automatic sliding doors (user, 2026-10-23: "like the ones you see in
	stores"), in the entrance and in the lobby's wide opening into the hall.
	Glass panels close the opening from the lobby side and slide apart, behind
	the fixed glass, when anyone comes near (either side); they slide shut
	again a moment after everyone has gone. StarterGymBuilder builds them
	(Doors.EntranceDoor and Doors.HallDoor, tagged AutoDoorTag) and the
	client's AutoDoorAnimator moves them on every player's screen.
]]
StarterGymConfig.AutoDoorTag = "AutoDoor"
StarterGymConfig.EntranceDoorPanelsPerSide = 1
-- The hall opening is 46 wide: one 23-stud panel per side would not fit
-- beside it in the lobby when open, so two per side slide over each other.
StarterGymConfig.HallDoorPanelsPerSide = 2
StarterGymConfig.DoorSensorReachStuds = 10 -- how far in front of and behind the doors someone opens them
StarterGymConfig.DoorSensorSideStuds = 2 -- and how far past the entrance's sides
StarterGymConfig.DoorSlideSeconds = 0.6 -- closed to fully open
StarterGymConfig.DoorHoldOpenSeconds = 1 -- they stay open this long after the last person has left
StarterGymConfig.DoorPanelThicknessStuds = 0.3
StarterGymConfig.DoorPanelOverlapStuds = 0.5 -- each closed panel reaches this far behind the fixed glass
StarterGymConfig.DoorFrameStuds = 0.25 -- the aluminium frame round each panel
-- Rooms whose doorway gets real swing doors (user, 2026-10-23: the sauna must
-- not have an open door; 2026-10-25: bigger, double doors). A frame fills the
-- rest of the doorway, and the doors swing into the room when someone is near.
-- The lockers (user, 2026-10-25: a locker room must not be seen into and needs
-- a door) get a single solid door without a window.
export type SwingDoorSpec = {
	openingWidth: number, -- the hole in the wall
	openingHeight: number,
	leaves: number, -- 1 = a single door, 2 = double doors
	width: number, -- all leaves together, inside the frame
	height: number,
	window: boolean, -- a window in each leaf
	look: string, -- Looks names: the leaves,
	frame: string, -- the frame round them,
	handle: string, -- the handles
	plaque: boolean?, -- false = no name plaque over the door (default: one)
}
StarterGymConfig.SwingDoors = {
	Sauna = { openingWidth = 8, openingHeight = 10, leaves = 2, width = 7.4, height = 9, window = true,
		look = "SaunaWood", frame = "SaunaWood", handle = "SaunaBench" },
	Lockers = { openingWidth = 6, openingHeight = 9, leaves = 1, width = 5.2, height = 8.6, window = false,
		look = "LockersSlats", frame = "SignPanel", handle = "Stainless" },
} :: { [string]: SwingDoorSpec }
StarterGymConfig.SwingDoorSensorReachStuds = 5 -- on each side of the wall

--[[
	Closed rooms (GAME_DESIGN §27 "Closed rooms and the spa wing", user
	2026-10-26: real-life rooms are not seen into and have doors). Only the
	GlassFrontRooms keep a glass front onto the hall (shop windows). Every other
	room has a solid wall wherever it faces the hall and a real door that
	closes (SwingDoors, or else one solid door coloured like its room's wall),
	except the lobby and the OpenDoorwayRooms.

	ClosedRooms: what the hall sees of a room. `label` is the room's name on its
	name plaque; `colour` paints its wall on the hall side and its door
	(2026-10-26; the user found plain colours "lazy", so they stay only until
	the room's themed front is built); `face` = a Looks name for the wall's hall
	side instead (a themed front's base texture; RoomProps FRONT adds its
	details); `slats` = oak slats instead (the lockers); `door` = a Looks name
	for the door instead of the colour; `plaque = false` = no name plaque. A
	room with no entry gets a plain door and its own name.
	The name plaque (user 2026-10-26, with photos of real office door signs:
	"instead of the big ugly text on top of every room, a small sign"): a room
	with a wall onto the hall gets a small wall plaque beside its door
	(NamePlaque below), on the door's right as you face it (`plaqueSide = -1`:
	its left), `plaqueOffset` studs from the door trim (default
	NamePlaque.offsetStuds); other rooms keep a small plaque over the door.
]]
-- How far a themed front's details may stand out from its wall (aisles and the
-- 12-stud balcony stay clear).
StarterGymConfig.FrontDepthStuds = 3
StarterGymConfig.GlassFrontRooms = { Cafe = true, SupplementBar = true, Shop = true } :: { [string]: boolean }
-- The showers are reached only through the lockers, which have the door.
StarterGymConfig.OpenDoorwayRooms = { Showers = true } :: { [string]: boolean }
export type ClosedRoom = {
	label: string,
	colour: Color3?,
	face: string?,
	slats: boolean?,
	door: string?,
	plaque: boolean?,
	plaqueSide: number?,
	plaqueOffset: number?,
}
StarterGymConfig.ClosedRooms = {
	Lockers = { label = "LOCKER ROOM", slats = true },
	-- Ground floor.
	-- Themed fronts, batch 2a: walnut panels, a frosted window with blinds, brass lamps.
	Office = { label = "OFFICE", face = "OfficeWalnut", door = "OfficeWalnut", plaqueSide = -1 },
	-- Themed fronts, batch 1 (GAME_DESIGN §27 "Themed room fronts"): black steel and diamond plate.
	Dumbbells = { label = "DUMBBELLS", face = "FrontCharcoal", door = "DumbbellsPlate" },
	-- Batch 2a: bolted steel panels, a yellow portal, two weight stacks.
	Machines = { label = "MACHINES", face = "MachinesSteel", door = "FrontGraphite" },
	-- The Index room (GAME_DESIGN §27); batch 2a: teal tiles, the lit meet-ladder board, medals. Its door keeps the teal.
	Physio = { label = "INDEX", colour = Color3.fromRGB(0, 124, 124), face = "IndexTiles", plaqueSide = -1 },
	-- Batch 2a: green corrugated steel, stencilled letters, crates on a pallet, stacks of bumper plates.
	Storage = { label = "STORAGE", face = "StorageSteel", door = "SignPanel" },
	Cardio = { label = "CARDIO", face = "FrontGraphite", door = "CardioTrack" }, -- running track, speed lines
	-- Behind the cafe: the cafe's own "STAFF ONLY" sign is over this door.
	StaffRoom = { label = "STAFF ROOM", colour = Color3.fromRGB(96, 132, 160), plaque = false }, -- dusty blue
	-- Upper floor. The spa wing: its wall onto the hall, then the rooms off its
	-- corridor (oak doors; the sauna's own doors are in SwingDoors).
	SpaReception = { label = "RECOVERY & SPA", face = "MassageStone", door = "LockersSlats" }, -- stone, oak, planters
	Sauna = { label = "SAUNA" },
	Recovery = { label = "RECOVERY", door = "LockersSlats" },
	Massage = { label = "MASSAGE", door = "LockersSlats" },
	SpareRoom = { label = "COMING SOON", colour = Color3.fromRGB(150, 154, 160) }, -- its use is decided later (user, 2026-10-26)
	-- Themed fronts, batch 2b: a chalkboard in an oak frame with chalk technique drawings (the plaque on its oak pillar).
	Classroom = { label = "CLASSROOM", face = "ClassroomBoard", door = "LockersSlats", plaqueOffset = 0.2 },
	-- Batch 2b: charcoal felt, acoustic foam panels in colours, a studio mic, ON AIR over the door.
	MediaRoom = { label = "MEDIA ROOM", face = "MediaFelt", door = "SignPanel" },
	-- Batch 2b: light oak with horizontal slats, bands on hooks, foam-roller racks.
	WarmUp = { label = "WARM-UP & MOBILITY", face = "LockersSlats", door = "LockersSlats" },
	MaxTesting = { label = "MAX TESTING", face = "MaxBlack", door = "MaxBlack" }, -- black, red stripes, plates
	-- Batch 2b: navy panels, a big whiteboard with the week's programme, clipboards.
	Coach = { label = "COACHES", face = "CoachesNavy", door = "CoachesNavy" },
	Lounge = { label = "LOUNGE", colour = Color3.fromRGB(214, 108, 88) }, -- coral
	TrophyRoom = { label = "TROPHY ROOM", colour = Color3.fromRGB(176, 136, 48) }, -- gold
} :: { [string]: ClosedRoom }
-- The name plaque beside a closed room's door (see ClosedRooms; user 2026-10-26, from photos of real
-- office door signs): a brushed-steel back plate on four stand-offs, a black face, the name in pale gold, at
-- eye height. Measured along the wall from the door trim, and up from the floor.
StarterGymConfig.NamePlaque = {
	offsetStuds = 1.4, -- from the door trim to the plaque (clear of the fronts' door portals)
	widthStuds = 2.0,
	bottomStuds = 5.6,
	heightStuds = 1.4,
	standOffStuds = 0.24, -- the back plate's distance from the wall (clear of slats and battens)
	textColour = Color3.fromRGB(232, 206, 140),
}

-- The door of a closed room that has no SwingDoors entry: one solid door
-- (no window, user 2026-10-26), its look from ClosedRooms.
StarterGymConfig.ClosedRoomDoor = { openingWidth = 6, openingHeight = 9, leaves = 1, width = 5.2, height = 8.6,
	window = false, look = "DoorPlain", frame = "SignPanel", handle = "Stainless" } :: SwingDoorSpec

--[[
	The rooms (GAME_DESIGN §27). What each room is and holds was approved by
	the user on 2026-10-23 (step 6); the ground floor's furniture is built by
	RoomProps (6a), the upper floor keeps placeholder names until step 6b. A
	name here is the room's name in Workspace. Each becomes an
	invisible region part "Room_<Name>" in Workspace.StarterGym.Rooms, with its
	floor and door position as attributes, ready for NPCs and signs later.
]]
StarterGymConfig.Rooms = {
	-- The side blocks, FRONT TO BACK. Left = +X (your left as you walk in).
	-- A name in two neighbouring places is ONE room across both (no wall
	-- between, one door in the middle): the sauna upstairs, where Room8 and
	-- Room7 were (user, 2026-10-25: upstairs, bigger).
	-- Where each room goes: user, 2026-10-26 (GAME_DESIGN §27 "Closed rooms and
	-- the spa wing"); the old ground-floor Coach room is Cardio, the coaches
	-- are upstairs (where the Studio was planned).
	-- The left block's upper floor is the Recovery & Spa wing (SpaWing below).
	LeftGround = { "Office", "Dumbbells", "Machines", "Physio" },
	RightGround = { "Storage", "SupplementBar", "Cardio", "Shop" },
	LeftUpper = { "SpaWing", "SpaWing", "SpaWing", "SpaWing" },
	-- SpareRoom: where Strongman was (it is the StrongmanShed beside the gym now); its use is decided later.
	RightUpper = { "SpareRoom", "SpareRoom", "Classroom", "MediaRoom" },
	-- The front block between its two corner rooms, LEFT TO RIGHT as you walk in.
	-- Ground: the middle one is the lobby (LobbyWidthStuds); upstairs: equal widths.
	FrontGround = { "Lockers", "Lobby", "Cafe" },
	FrontUpper = { "WarmUp", "MaxTesting", "Coach" },
	-- The front corners, both floors (the stairs' place in the drawing; see stage 3).
	-- Ground: reached through Lockers (left) and Cafe (right). The Staff Room was
	-- the Kitchen (user, 2026-10-25: the steak kitchen becomes its own building).
	-- Upper: reached through Warm-up (left) and Coach (right).
	CornerGround = { Left = "Showers", Right = "StaffRoom" },
	CornerUpper = { Left = "Lounge", Right = "TrophyRoom" },
}

--[[
	The Recovery & Spa wing (GAME_DESIGN §27 "Closed rooms and the spa wing",
	user 2026-10-26: three big rooms). It fills the places named `name` in
	Rooms (the left block's upper floor): one door from the balcony into the
	reception at the wing's front end, across the whole block; from there a
	corridor runs back along the hall wall, and the rooms open off it, front
	to back, each with its own door. The last room takes what is left. No
	windows onto the hall.
]]
--[[
	The Strongman Shed (GAME_DESIGN §27 "Strongman becomes an outdoor yard",
	then "a big shed", user 2026-10-26): its own building, disconnected from the
	gym, beside it on the side `side` (-1 = -X: on your right as you face the
	entrance from outside, by the Cafe corner), `gapStuds` from its side wall,
	its front level with the gym's front so players see it as they walk out. A
	steel and timber barn: weathered timber along the bottom, dark corrugated
	steel above, a pitched corrugated roof (the ridge front to back, gable ends
	front and back), steel trusses with hanging lamps inside, and a big roller
	door in its front, always rolled up, with the sign over it. RoomProps lays
	out its equipment (FURNISH.StrongmanShed) like a room's, from the door.
]]
StarterGymConfig.StrongmanShed = {
	name = "StrongmanShed",
	label = "STRONGMAN",
	side = -1,
	gapStuds = 12,
	widthStuds = 80, -- outside, across (X)
	depthStuds = 60, -- outside, from its front (level with the gym's front) back (Z)
	wallHeightStuds = 16,
	roofRiseStuds = 9, -- the ridge above the walls' top
	roofOverhangStuds = 1.5,
	timberBandStuds = 4, -- the weathered timber along the bottom of the walls
	doorWidthStuds = 22,
	doorHeightStuds = 13,
	trussSpacingStuds = 12,
}

export type SpaWingRoom = { name: string, lengthStuds: number? }
StarterGymConfig.SpaWing = {
	name = "SpaWing",
	reception = "SpaReception",
	receptionDepthStuds = 20, -- front to back
	corridorWidthStuds = 6, -- from the hall wall's inside face to the corridor wall's middle
	rooms = {
		{ name = "Sauna", lengthStuds = 33 },
		{ name = "Recovery", lengthStuds = 28 },
		{ name = "Massage" },
	} :: { SpaWingRoom },
}

--[[
	The rooms' 3D props (2026-10-25): uploaded as Model assets owned by the
	game's group (art/materials/materials.json) and loaded by RoomProps with
	InsertService when the server starts. A room whose props fail to load uses
	simple part-built ones (or leaves them out).
	An asset holds one item per name prefix ("<Item>_<Piece>": SBarWhey_Body,
	Locker_Door, ...); `whole` makes the whole asset one item instead (a Poly
	Haven model with its own part names). Sources: art/scripts/
	build_sbar_props_01.py, prep_sbar_plant.py, build_room_props_02.py, build_room_props_03.py.
]]
export type PropAsset = { id: number, whole: string? }
StarterGymConfig.PropAssets = {
	{ id = 126463004640141 }, -- SBarProps_01: supplement bar products, shaker, bar stool
	{ id = 72818612497691, whole = "SBarPlant" }, -- SBarPlant_01: the leafy potted plant
	{ id = 93719454817045 }, -- RoomProps_02: Lockers, Cafe and Staff Room
	{ id = 109192629566668 }, -- RoomProps_03: Showers, Recovery and Massage
	{ id = 91749281309773 }, -- RoomProps_04: themed room fronts, batch 1
	{ id = 126419721956699 }, -- RoomProps_05: Strongman Yard (tyre, sandbag, yoke, farmer's handle)
	{ id = 89330038688157 }, -- RoomProps_06: themed room fronts, batch 2a (weight stack, sconce, crate, pallet, bumper plate, medal)
	{ id = 111460003222169 }, -- RoomProps_07: themed room fronts, batch 2b (mic, ON AIR lamp, headphones, band, roller, rack, clipboard)
} :: { PropAsset }

-- The colours a prop piece can take (material SmoothPlastic unless named here).
export type PropPaint = { color: Color3, material: Enum.Material?, reflectance: number?, transparency: number? }
StarterGymConfig.PropPaints = {
	Black = { color = Color3.fromRGB(22, 22, 24) },
	Charcoal = { color = Color3.fromRGB(46, 48, 54) },
	Red = { color = Color3.fromRGB(200, 30, 38) },
	White = { color = Color3.fromRGB(236, 236, 232) },
	LightGrey = { color = Color3.fromRGB(176, 180, 186) },
	Blue = { color = Color3.fromRGB(30, 92, 205) },
	Navy = { color = Color3.fromRGB(30, 48, 98) },
	Yellow = { color = Color3.fromRGB(242, 190, 30) },
	Mustard = { color = Color3.fromRGB(214, 160, 38) },
	Green = { color = Color3.fromRGB(95, 222, 60) },
	Forest = { color = Color3.fromRGB(34, 98, 62) },
	Sage = { color = Color3.fromRGB(140, 164, 134) },
	Mint = { color = Color3.fromRGB(172, 218, 196) },
	Teal = { color = Color3.fromRGB(0, 138, 140) },
	Purple = { color = Color3.fromRGB(128, 52, 190) },
	Lavender = { color = Color3.fromRGB(184, 170, 222) },
	Orange = { color = Color3.fromRGB(245, 130, 30) },
	Terracotta = { color = Color3.fromRGB(196, 98, 62) },
	Pink = { color = Color3.fromRGB(240, 125, 172) },
	Cream = { color = Color3.fromRGB(236, 224, 196) },
	Kraft = { color = Color3.fromRGB(184, 142, 98) },
	Oak = { color = Color3.fromRGB(198, 152, 102), material = Enum.Material.Wood },
	Coffee = { color = Color3.fromRGB(62, 34, 20) },
	Chocolate = { color = Color3.fromRGB(94, 52, 32) },
	Dough = { color = Color3.fromRGB(214, 160, 92) },
	Silver = { color = Color3.fromRGB(190, 192, 198), material = Enum.Material.Metal },
	Brass = { color = Color3.fromRGB(200, 160, 82), material = Enum.Material.Metal },
	Glass = { color = Color3.fromRGB(205, 225, 235), transparency = 0.7, reflectance = 0.1 },
	WaterBlue = { color = Color3.fromRGB(150, 200, 235), transparency = 0.35 },
	Mirror = { color = Color3.fromRGB(122, 134, 148), reflectance = 0.6 }, -- darker, so it reads as glass, not a white plate
	WarmGlow = { color = Color3.fromRGB(255, 205, 150), material = Enum.Material.Neon },
	-- Showers, Recovery and Massage (2026-10-26).
	Coral = { color = Color3.fromRGB(238, 112, 92) },
	Lime = { color = Color3.fromRGB(170, 214, 60) },
	Sky = { color = Color3.fromRGB(120, 178, 224) },
	Slate = { color = Color3.fromRGB(78, 82, 88), material = Enum.Material.Slate },
	Amber = { color = Color3.fromRGB(190, 110, 40), transparency = 0.25, reflectance = 0.1 }, -- brown glass
	BlueGlass = { color = Color3.fromRGB(40, 90, 170), transparency = 0.25, reflectance = 0.1 },
	Ice = { color = Color3.fromRGB(225, 240, 250), transparency = 0.35, reflectance = 0.1 },
	-- RoomProps_04 (themed room fronts, batch 1)
	Granite = { color = Color3.fromRGB(150, 150, 146), material = Enum.Material.Granite },
	-- RoomProps_06 (themed room fronts, batch 2a)
	Bronze = { color = Color3.fromRGB(176, 110, 60), material = Enum.Material.Metal },
	-- RoomProps_07 (themed room fronts, batch 2b): the ON AIR lamp's light.
	RedGlow = { color = Color3.fromRGB(230, 40, 40), material = Enum.Material.Neon },
} :: { [string]: PropPaint }

-- Pieces made of cloth (Fabric) whatever their colour, as "<Item>_<Piece>".
StarterGymConfig.PropFabricPieces = {
	Sandbag_Body = true,
	Sofa_Frame = true,
	Sofa_Cushion = true,
	Curtain_Cloth = true,
	GymBag_Body = true,
	StaffTee_Body = true,
	Towel_Body = true,
	Towel_Stripe = true,
	HangingTowel_Body = true,
	HangingTowel_Stripe = true,
	TowelBin_Body = true,
	TowelBin_Fill = true,
	Lounger_Pad = true,
	Lounger_Pillow = true,
	MassageTable_Towel = true,
	Pouf_Body = true,
	Pouf_Piping = true,
	FoldingScreen_Panel = true,
}

--[[
	Each item's colourways: piece -> paint name (PropPaints). A piece left out
	keeps the asset's plain look. Variety, not just red and black (user,
	2026-10-25); every product, bag and tee label says CENTRAL.
]]
StarterGymConfig.PropColourways = {
	-- The supplement bar (product: body, lid, label, text; the shaker has no label).
	SBarWhey = {
		{ Body = "Black", Lid = "Red", Label = "Red", Text = "White" },
		{ Body = "White", Lid = "Black", Label = "Black", Text = "White" },
	},
	SBarIsolate = { { Body = "White", Lid = "Blue", Label = "Blue", Text = "White" } },
	SBarGainer = { { Body = "Black", Lid = "Black", Label = "Yellow", Text = "Black" } },
	SBarPreWorkout = {
		{ Body = "Black", Lid = "Green", Label = "Green", Text = "Black" },
		{ Body = "Black", Lid = "Purple", Label = "Purple", Text = "White" },
	},
	SBarCreatine = { { Body = "White", Lid = "Silver", Label = "Silver", Text = "Black" } },
	SBarBCAA = { { Body = "White", Lid = "Orange", Label = "Orange", Text = "White" } },
	SBarShaker = {
		{ Body = "Red", Lid = "Black", Text = "White" },
		{ Body = "Blue", Lid = "Black", Text = "White" },
		{ Body = "White", Lid = "Black", Text = "Black" },
		{ Body = "Black", Lid = "White", Text = "White" },
		{ Body = "Green", Lid = "Black", Text = "Black" },
		{ Body = "Pink", Lid = "White", Text = "White" },
	},
	SBarStool = { { Seat = "Black", Metal = "Silver" } },
	-- Lockers (as art/scripts/build_room_props_02.py COLOURWAYS).
	Locker = {
		{ Door = "Navy", Frame = "Charcoal", Metal = "Silver", Dark = "Black" },
		{ Door = "Sage", Frame = "Charcoal", Metal = "Silver", Dark = "Black" },
		{ Door = "Oak", Frame = "Charcoal", Metal = "Silver", Dark = "Black" },
		{ Door = "LightGrey", Frame = "Charcoal", Metal = "Silver", Dark = "Black" },
	},
	LockerBench = { { Seat = "Oak", Metal = "Black" } },
	GymBag = {
		{ Body = "Black", Trim = "Red", Text = "White" },
		{ Body = "Navy", Trim = "White", Text = "White" },
		{ Body = "Pink", Trim = "Black", Text = "Black" },
		{ Body = "LightGrey", Trim = "Teal", Text = "Black" },
		{ Body = "Mustard", Trim = "Black", Text = "Black" },
	},
	WaterBottle = {
		{ Body = "Blue", Cap = "Black", Text = "White" },
		{ Body = "Pink", Cap = "White", Text = "White" },
		{ Body = "Teal", Cap = "Black", Text = "White" },
		{ Body = "Orange", Cap = "Black", Text = "Black" },
	},
	RoundMirror = { { Glass = "Mirror", Glow = "WarmGlow" } },
	Sink = { { Bowl = "White", Metal = "Silver" } },
	Curtain = {
		{ Cloth = "Teal", Metal = "Silver" },
		{ Cloth = "Mustard", Metal = "Silver" },
		{ Cloth = "Terracotta", Metal = "Silver" },
	},
	-- Cafe.
	Espresso = {
		{ Body = "Silver", Panel = "Black", Metal = "Silver", Text = "White" },
		{ Body = "Mint", Panel = "Cream", Metal = "Silver", Text = "Black" },
	},
	Grinder = { { Body = "Black", Hopper = "Glass", Beans = "Coffee", Metal = "Silver" } },
	CoffeeCup = {
		{ Body = "White", Lid = "Black", Label = "Kraft", Text = "White" },
		{ Body = "White", Lid = "Black", Label = "Forest", Text = "White" },
		{ Body = "White", Lid = "Black", Label = "Terracotta", Text = "White" },
		{ Body = "White", Lid = "Black", Label = "Black", Text = "White" },
	},
	Mug = {
		{ Body = "White", Coffee = "Coffee" },
		{ Body = "Mint", Coffee = "Coffee" },
		{ Body = "Mustard", Coffee = "Coffee" },
		{ Body = "Terracotta", Coffee = "Coffee" },
		{ Body = "Navy", Coffee = "Coffee" },
	},
	PastryCase = { { Base = "Oak", Glass = "Glass", Metal = "Brass" } },
	Donut = { { Dough = "Dough", Icing = "Pink" }, { Dough = "Dough", Icing = "Chocolate" }, { Dough = "Dough", Icing = "White" } },
	Muffin = { { Case = "Red", Top = "Chocolate" }, { Case = "Teal", Top = "Dough" }, { Case = "Mustard", Top = "Chocolate" } },
	Croissant = { { Dough = "Dough" } },
	CafeChair = {
		{ Shell = "Mustard", Legs = "Oak" },
		{ Shell = "Teal", Legs = "Oak" },
		{ Shell = "Terracotta", Legs = "Black" },
		{ Shell = "White", Legs = "Oak" },
	},
	Booth = { { Frame = "Oak", Cushion = "Forest" }, { Frame = "Black", Cushion = "Mustard" }, { Frame = "Oak", Cushion = "Terracotta" } },
	PendantLamp = {
		{ Shade = "Brass", Bulb = "WarmGlow" },
		{ Shade = "Black", Bulb = "WarmGlow" },
		{ Shade = "Sage", Bulb = "WarmGlow" },
		{ Shade = "Terracotta", Bulb = "WarmGlow" },
	},
	CoffeeBag = {
		{ Body = "Black", Label = "Cream", Text = "Black" },
		{ Body = "Kraft", Label = "Cream", Text = "Black" },
		{ Body = "Forest", Label = "Cream", Text = "Black" },
		{ Body = "Terracotta", Label = "Cream", Text = "Black" },
	},
	-- Staff Room.
	Sofa = {
		{ Frame = "Teal", Cushion = "Teal", Legs = "Oak" },
		{ Frame = "Mustard", Cushion = "Mustard", Legs = "Oak" },
		{ Frame = "LightGrey", Cushion = "LightGrey", Legs = "Oak" },
	},
	Microwave = {
		{ Body = "White", Door = "Black", Panel = "Black", Metal = "Silver" },
		{ Body = "Silver", Door = "Black", Panel = "Black", Metal = "Silver" },
	},
	Kettle = { { Body = "Cream", Trim = "Black" }, { Body = "Sage", Trim = "Silver" }, { Body = "Red", Trim = "Black" } },
	WaterCooler = { { Body = "White", Bottle = "WaterBlue", Tap = "Blue", Dark = "Black" } },
	Fridge = {
		{ Body = "Mint", Dark = "Charcoal", Metal = "Silver" },
		{ Body = "Cream", Dark = "Charcoal", Metal = "Silver" },
		{ Body = "Lavender", Dark = "Charcoal", Metal = "Silver" },
	},
	StaffTee = {
		{ Body = "Black", Text = "White", Metal = "Silver" },
		{ Body = "Red", Text = "White", Metal = "Silver" },
		{ Body = "Navy", Text = "White", Metal = "Silver" },
		{ Body = "White", Text = "Black", Metal = "Silver" },
	},
	-- Showers, Recovery and Massage (as art/scripts/build_room_props_03.py COLOURWAYS).
	RainShower = {
		{ Metal = "Silver", Head = "Silver", Dark = "Charcoal" },
		{ Metal = "Black", Head = "Black", Dark = "Charcoal" },
		{ Metal = "Brass", Head = "Brass", Dark = "Charcoal" },
	},
	ShowerGel = {
		{ Body = "Teal", Pump = "White", Label = "White", Text = "Black" },
		{ Body = "Lavender", Pump = "White", Label = "White", Text = "Black" },
		{ Body = "Coral", Pump = "Black", Label = "White", Text = "Black" },
		{ Body = "Charcoal", Pump = "Silver", Label = "White", Text = "Black" },
		{ Body = "Mint", Pump = "White", Label = "White", Text = "Black" },
	},
	Shampoo = {
		{ Body = "Sky", Cap = "White", Label = "White", Text = "Navy" },
		{ Body = "Lime", Cap = "White", Label = "White", Text = "Black" },
		{ Body = "Orange", Cap = "Black", Label = "Cream", Text = "Black" },
		{ Body = "White", Cap = "Navy", Label = "Navy", Text = "White" },
	},
	Towel = {
		{ Body = "White", Stripe = "LightGrey" },
		{ Body = "Sage", Stripe = "White" },
		{ Body = "Navy", Stripe = "White" },
		{ Body = "Terracotta", Stripe = "Cream" },
		{ Body = "Mustard", Stripe = "White" },
		{ Body = "Sky", Stripe = "White" },
	},
	HangingTowel = {
		{ Body = "White", Stripe = "LightGrey", Metal = "Silver" },
		{ Body = "Sage", Stripe = "White", Metal = "Silver" },
		{ Body = "Navy", Stripe = "White", Metal = "Silver" },
		{ Body = "Terracotta", Stripe = "Cream", Metal = "Silver" },
		{ Body = "Mustard", Stripe = "White", Metal = "Silver" },
		{ Body = "Sky", Stripe = "White", Metal = "Silver" },
	},
	SoapDispenser = {
		{ Body = "White", Window = "Ice", Button = "Silver", Text = "Black" },
		{ Body = "Black", Window = "Ice", Button = "Silver", Text = "White" },
	},
	TowelBin = {
		{ Body = "Sage", Rim = "Oak", Text = "White", Fill = "White" },
		{ Body = "Charcoal", Rim = "Oak", Text = "White", Fill = "White" },
		{ Body = "Cream", Rim = "Black", Text = "Black", Fill = "White" },
	},
	Slides = {
		{ Sole = "Black", Strap = "Black", Text = "White" },
		{ Sole = "White", Strap = "Navy", Text = "White" },
		{ Sole = "White", Strap = "Teal", Text = "White" },
		{ Sole = "Black", Strap = "Sage", Text = "Black" },
		{ Sole = "Cream", Strap = "Coral", Text = "White" },
	},
	ColdPlunge = {
		{ Body = "Oak", Band = "Black", Rim = "Oak", Water = "WaterBlue", Ice = "Ice" },
		{ Body = "White", Band = "Silver", Rim = "Silver", Water = "WaterBlue", Ice = "Ice" },
		{ Body = "Charcoal", Band = "Oak", Rim = "Oak", Water = "WaterBlue", Ice = "Ice" },
	},
	FoamRoller = {
		{ Body = "Blue", Core = "Black" },
		{ Body = "Orange", Core = "Black" },
		{ Body = "Pink", Core = "White" },
		{ Body = "Lime", Core = "Charcoal" },
		{ Body = "Teal", Core = "White" },
		{ Body = "Purple", Core = "Black" },
	},
	Lounger = {
		{ Pad = "Charcoal", Frame = "Silver", Pillow = "LightGrey" },
		{ Pad = "Sage", Frame = "Oak", Pillow = "Cream" },
		{ Pad = "Terracotta", Frame = "Black", Pillow = "Cream" },
		{ Pad = "Navy", Frame = "Silver", Pillow = "White" },
	},
	MassageGun = {
		{ Body = "Black", Grip = "Charcoal", Head = "Orange", Text = "White" },
		{ Body = "Sage", Grip = "Charcoal", Head = "White", Text = "White" },
		{ Body = "White", Grip = "LightGrey", Head = "Teal", Text = "Black" },
		{ Body = "Lavender", Grip = "Charcoal", Head = "White", Text = "Black" },
	},
	YogaMat = {
		{ Body = "Purple", Strap = "Black" },
		{ Body = "Teal", Strap = "Black" },
		{ Body = "Coral", Strap = "White" },
		{ Body = "Mustard", Strap = "Black" },
		{ Body = "Sky", Strap = "White" },
		{ Body = "Sage", Strap = "Oak" },
	},
	MassageTable = {
		{ Pad = "Cream", Frame = "Oak", Legs = "Oak", Bolster = "Sage", Towel = "White" },
		{ Pad = "Sage", Frame = "Oak", Legs = "Oak", Bolster = "Cream", Towel = "White" },
		{ Pad = "Charcoal", Frame = "Black", Legs = "Black", Bolster = "Terracotta", Towel = "White" },
		{ Pad = "Terracotta", Frame = "Oak", Legs = "Oak", Bolster = "Cream", Towel = "Cream" },
	},
	OilBottle = {
		{ Body = "Amber", Cap = "Black", Label = "Cream", Text = "Black" },
		{ Body = "BlueGlass", Cap = "White", Label = "Cream", Text = "Black" },
		{ Body = "White", Cap = "Brass", Label = "Cream", Text = "Black" },
	},
	CandleSet = {
		{ Wax = "Cream", Flame = "WarmGlow", Tray = "Brass" },
		{ Wax = "Sage", Flame = "WarmGlow", Tray = "Oak" },
		{ Wax = "Terracotta", Flame = "WarmGlow", Tray = "Black" },
		{ Wax = "White", Flame = "WarmGlow", Tray = "Oak" },
	},
	Diffuser = {
		{ Body = "White", Base = "Oak", Light = "WarmGlow" },
		{ Body = "Sage", Base = "Oak", Light = "WarmGlow" },
		{ Body = "Terracotta", Base = "Black", Light = "WarmGlow" },
	},
	SpaStones = {
		{ Stone = "Slate" },
		{ Stone = "Charcoal" },
	},
	Pouf = {
		{ Body = "Mustard", Piping = "Cream" },
		{ Body = "Sage", Piping = "Cream" },
		{ Body = "Terracotta", Piping = "Cream" },
		{ Body = "Cream", Piping = "Kraft" },
		{ Body = "Navy", Piping = "Cream" },
	},
	FoldingScreen = {
		{ Frame = "Oak", Panel = "Cream" },
		{ Frame = "Black", Panel = "Sage" },
		{ Frame = "Oak", Panel = "Kraft" },
	},
	-- RoomProps_04: the themed room fronts, batch 1 (art/scripts/build_room_props_04.py COLOURWAYS).
	AtlasStone = { { Stone = "Granite" }, { Stone = "Slate" }, { Stone = "Charcoal" } },
	AtlasStand = { { Frame = "Oak", Top = "Chocolate" }, { Frame = "Black", Top = "Oak" } },
	StrongLog = {
		{ Body = "Black", Cap = "Silver", Slot = "Charcoal", Handle = "Silver", Text = "White" },
		{ Body = "Navy", Cap = "Silver", Slot = "Charcoal", Handle = "Silver", Text = "White" },
		{ Body = "Forest", Cap = "Brass", Slot = "Charcoal", Handle = "Silver", Text = "Cream" },
		{ Body = "Orange", Cap = "Black", Slot = "Charcoal", Handle = "Silver", Text = "Black" },
	},
	Chain = { { Metal = "Silver" }, { Metal = "Charcoal" } },
	HexDumbbell = {
		{ Head = "Black", Face = "Red", Handle = "Silver", Text = "White" },
		{ Head = "Black", Face = "Blue", Handle = "Silver", Text = "White" },
		{ Head = "Black", Face = "Yellow", Handle = "Silver", Text = "Black" },
		{ Head = "Black", Face = "Green", Handle = "Silver", Text = "Black" },
		{ Head = "Black", Face = "Orange", Handle = "Silver", Text = "Black" },
		{ Head = "Black", Face = "White", Handle = "Silver", Text = "Black" },
		{ Head = "Black", Face = "Purple", Handle = "Silver", Text = "White" },
		{ Head = "Black", Face = "Teal", Handle = "Silver", Text = "White" },
	},
	DumbbellRack = { { Frame = "Black", Shelf = "Charcoal", Text = "White" }, { Frame = "Silver", Shelf = "Black", Text = "Black" } },
	-- IPF calibrated plate colours: 25 red, 20 blue, 15 yellow, 10 green, 5 white.
	CompPlate = {
		{ Disc = "Red", Hub = "Silver", Text = "White" },
		{ Disc = "Blue", Hub = "Silver", Text = "White" },
		{ Disc = "Yellow", Hub = "Silver", Text = "Black" },
		{ Disc = "Green", Hub = "Silver", Text = "White" },
		{ Disc = "White", Hub = "Silver", Text = "Black" },
	},
	Planter = { { Body = "Oak", Soil = "Chocolate" }, { Body = "Charcoal", Soil = "Chocolate" },
		{ Body = "Terracotta", Soil = "Chocolate" }, { Body = "Cream", Soil = "Chocolate" } },
	WallUplight = { { Body = "Brass", Light = "WarmGlow" }, { Body = "Black", Light = "WarmGlow" },
		{ Body = "White", Light = "WarmGlow" } },
	-- RoomProps_05: the Strongman Yard (art/scripts/build_room_props_05.py COLOURWAYS).
	Tyre = { { Rubber = "Black", Text = "Yellow" }, { Rubber = "Black", Text = "White" } },
	Sandbag = {
		{ Body = "Forest", Strap = "Black", Text = "White" },
		{ Body = "Kraft", Strap = "Black", Text = "Black" },
		{ Body = "Navy", Strap = "Black", Text = "White" },
		{ Body = "Terracotta", Strap = "Black", Text = "White" },
		{ Body = "Black", Strap = "Black", Text = "Yellow" },
	},
	Yoke = {
		{ Frame = "Black", Horn = "Silver", Pad = "Black", Text = "White" },
		{ Frame = "Red", Horn = "Silver", Pad = "Black", Text = "White" },
		{ Frame = "Navy", Horn = "Silver", Pad = "Black", Text = "White" },
	},
	FarmerHandle = {
		{ Frame = "Black", Grip = "Silver", Text = "White" },
		{ Frame = "Orange", Grip = "Silver", Text = "Black" },
		{ Frame = "Teal", Grip = "Silver", Text = "White" },
	},
	-- RoomProps_06: themed room fronts, batch 2a (art/scripts/build_room_props_06.py COLOURWAYS).
	WeightStack = {
		{ Frame = "Black", Rod = "Silver", Plate = "Black", Top = "Red", Pin = "Yellow", Cable = "Black", Pulley = "Silver",
			Text = "White", Logo = "White" },
		{ Frame = "LightGrey", Rod = "Silver", Plate = "Charcoal", Top = "Blue", Pin = "Red", Cable = "Black", Pulley = "Silver",
			Text = "White", Logo = "White" },
		{ Frame = "White", Rod = "Silver", Plate = "Black", Top = "Yellow", Pin = "Red", Cable = "Black", Pulley = "Silver",
			Text = "White", Logo = "Black" },
		{ Frame = "Navy", Rod = "Silver", Plate = "Black", Top = "Orange", Pin = "Yellow", Cable = "Black", Pulley = "Silver",
			Text = "White", Logo = "Black" },
	},
	WallSconce = {
		{ Mount = "Brass", Shade = "Cream", Light = "WarmGlow" },
		{ Mount = "Black", Shade = "White", Light = "WarmGlow" },
		{ Mount = "Brass", Shade = "Forest", Light = "WarmGlow" },
		{ Mount = "Silver", Shade = "Navy", Light = "WarmGlow" },
	},
	WoodCrate = {
		{ Slats = "Oak", Frame = "Chocolate", Text = "Black" },
		{ Slats = "Kraft", Frame = "Coffee", Text = "Black" },
		{ Slats = "Forest", Frame = "Black", Text = "White" },
		{ Slats = "Navy", Frame = "Black", Text = "White" },
		{ Slats = "Mustard", Frame = "Black", Text = "Black" },
	},
	Pallet = { { Boards = "Kraft", Blocks = "Kraft" }, { Boards = "Blue", Blocks = "Blue" }, { Boards = "Oak", Blocks = "Chocolate" } },
	BumperPlate = {
		{ Disc = "Red", Hub = "Silver", Text = "White" },
		{ Disc = "Blue", Hub = "Silver", Text = "White" },
		{ Disc = "Yellow", Hub = "Silver", Text = "Black" },
		{ Disc = "Green", Hub = "Silver", Text = "Black" },
		{ Disc = "Black", Hub = "Silver", Text = "White" },
		{ Disc = "LightGrey", Hub = "Silver", Text = "Black" },
	},
	Medal = {
		{ Disc = "Brass", Ribbon = "Red", Text = "Coffee" },
		{ Disc = "Silver", Ribbon = "Blue", Text = "Charcoal" },
		{ Disc = "Bronze", Ribbon = "Forest", Text = "Coffee" },
		{ Disc = "Brass", Ribbon = "Navy", Text = "Coffee" },
		{ Disc = "Silver", Ribbon = "Purple", Text = "Charcoal" },
	},
	-- RoomProps_07: themed room fronts, batch 2b (art/scripts/build_room_props_07.py COLOURWAYS).
	StudioMic = {
		{ Mount = "Black", Body = "Black", Grille = "Silver", Ring = "Silver", Text = "White" },
		{ Mount = "Black", Body = "Silver", Grille = "Charcoal", Ring = "Silver", Text = "Black" },
		{ Mount = "Black", Body = "Red", Grille = "Silver", Ring = "Silver", Text = "White" },
	},
	OnAirLamp = { { Body = "Black", Glow = "RedGlow", Text = "White" } },
	Headphones = {
		{ Band = "Black", Cups = "Red", Pads = "Black", Text = "White" },
		{ Band = "White", Cups = "Sky", Pads = "Black", Text = "Black" },
		{ Band = "Black", Cups = "Yellow", Pads = "Black", Text = "Black" },
		{ Band = "Charcoal", Cups = "Teal", Pads = "Black", Text = "White" },
	},
	ResistanceBand = {
		{ Band = "Red", Hook = "Silver" },
		{ Band = "Yellow", Hook = "Silver" },
		{ Band = "Green", Hook = "Silver" },
		{ Band = "Blue", Hook = "Silver" },
		{ Band = "Purple", Hook = "Silver" },
		{ Band = "Black", Hook = "Silver" },
		{ Band = "Orange", Hook = "Silver" },
	},
	-- (MobilityRoller, not FoamRoller: that is the Recovery room's roller from RoomProps_03.)
	MobilityRoller = {
		{ Body = "Teal", Ends = "Black", Text = "White" },
		{ Body = "Orange", Ends = "Black", Text = "White" },
		{ Body = "Purple", Ends = "Black", Text = "White" },
		{ Body = "Blue", Ends = "Black", Text = "White" },
		{ Body = "Lime", Ends = "Black", Text = "White" },
		{ Body = "Pink", Ends = "Black", Text = "White" },
	},
	RollerRack = { { Frame = "Black", Text = "White" }, { Frame = "Silver", Text = "Black" }, { Frame = "White", Text = "Black" } },
	Clipboard = {
		{ Board = "Kraft", Clip = "Silver", Paper = "White", Lines = "Charcoal", Text = "Black" },
		{ Board = "Blue", Clip = "Silver", Paper = "White", Lines = "Charcoal", Text = "Black" },
		{ Board = "Red", Clip = "Silver", Paper = "White", Lines = "Charcoal", Text = "Black" },
		{ Board = "Green", Clip = "Silver", Paper = "White", Lines = "Charcoal", Text = "Black" },
		{ Board = "Orange", Clip = "Silver", Paper = "White", Lines = "Charcoal", Text = "Black" },
		{ Board = "Purple", Clip = "Silver", Paper = "White", Lines = "Charcoal", Text = "Black" },
	},
} :: { [string]: { { [string]: string } } }

-- `variant` names one of the MaterialVariants below; `material` must then be that variant's base material.
export type Look = { material: Enum.Material, color: Color3, transparency: number?, reflectance: number?, variant: string? }

--[[
	Textured materials (2026-10-25): free CC0 maps from ambientCG and Poly Haven,
	prepared with the Roblox Maps kit and uploaded as images owned by the
	game's group (art/scripts/upload_group_images.py; sources, licences and ids
	in art/materials/materials.json). Game scripts may not create
	MaterialVariants, so Rojo does: default.project.json has one
	MaterialService.<name> MaterialVariant per entry below, with the same
	values. KEEP THE TWO IN STEP (the verify script compares them). A part
	whose variant is missing just shows its plain base material.
]]
export type MaterialVariantSpec = {
	base: Enum.Material,
	studsPerTile: number,
	color: string,
	normal: string,
	roughness: string,
}
StarterGymConfig.MaterialVariants = {
	SBar_DarkWoodFloor = { -- ambientCG WoodFloor064
		base = Enum.Material.WoodPlanks,
		studsPerTile = 9,
		color = "rbxassetid://116853125392813",
		normal = "rbxassetid://131023733106403",
		roughness = "rbxassetid://99877885379174",
	},
	SBar_CreamWallTiles = { -- Poly Haven long_white_tiles
		base = Enum.Material.CeramicTiles,
		studsPerTile = 6,
		color = "rbxassetid://87087652044414",
		normal = "rbxassetid://78705441173025",
		roughness = "rbxassetid://136168219104020",
	},
	SBar_BlackMarble = { -- ambientCG Marble006
		base = Enum.Material.Marble,
		studsPerTile = 8,
		color = "rbxassetid://134658265297491",
		normal = "rbxassetid://81687991928406",
		roughness = "rbxassetid://85154963086209",
	},
	SBar_DarkPlanks = { -- ambientCG Planks037A
		base = Enum.Material.Wood,
		studsPerTile = 6,
		color = "rbxassetid://78285911641083",
		normal = "rbxassetid://77687587802341",
		roughness = "rbxassetid://134955031392788",
	},
	-- Lockers, Cafe and Staff Room (2026-10-25, picked by the user from a preview sheet).
	Lockers_DarkGridTiles = { -- ambientcg Tiles108
		base = Enum.Material.CeramicTiles,
		studsPerTile = 14,
		color = "rbxassetid://82594454999235",
		normal = "rbxassetid://101853108914550",
		roughness = "rbxassetid://74507281506922",
	},
	Lockers_OakSlats = { -- polyhaven oak_veneer_02
		base = Enum.Material.Wood,
		studsPerTile = 8,
		color = "rbxassetid://89603927198995",
		normal = "rbxassetid://128274853236069",
		roughness = "rbxassetid://87590195110822",
	},
	Lockers_GreenPennyTiles = { -- ambientcg Tiles126
		base = Enum.Material.CeramicTiles,
		studsPerTile = 6,
		color = "rbxassetid://87108536379404",
		normal = "rbxassetid://85589153419592",
		roughness = "rbxassetid://110819419280798",
	},
	Cafe_Herringbone = { -- polyhaven herringbone_parquet
		base = Enum.Material.WoodPlanks,
		studsPerTile = 10,
		color = "rbxassetid://117332819213723",
		normal = "rbxassetid://90927464344679",
		roughness = "rbxassetid://131534083397873",
	},
	Cafe_RedBrick = { -- polyhaven red_brick_03
		base = Enum.Material.Brick,
		studsPerTile = 6,
		color = "rbxassetid://117468038485514",
		normal = "rbxassetid://102691661534276",
		roughness = "rbxassetid://86141807694480",
	},
	Cafe_GreenTiles = { -- ambientcg Tiles032
		base = Enum.Material.CeramicTiles,
		studsPerTile = 5,
		color = "rbxassetid://124067811087466",
		normal = "rbxassetid://91163032168998",
		roughness = "rbxassetid://105784961345502",
	},
	Cafe_WhiteMarble = { -- ambientcg Marble021
		base = Enum.Material.Marble,
		studsPerTile = 10,
		color = "rbxassetid://112174899086953",
		normal = "rbxassetid://98757688022461",
		roughness = "rbxassetid://79859733110735",
	},
	Staff_Laminate = { -- polyhaven laminate_floor_03
		base = Enum.Material.WoodPlanks,
		studsPerTile = 10,
		color = "rbxassetid://71311120498653",
		normal = "rbxassetid://104370922500764",
		roughness = "rbxassetid://74679013768559",
	},
	Staff_WoodWorktop = { -- ambientcg Wood049
		base = Enum.Material.Wood,
		studsPerTile = 6,
		color = "rbxassetid://121763820794578",
		normal = "rbxassetid://111180060671694",
		roughness = "rbxassetid://104817297102607",
	},
	Staff_Cork = { -- ambientcg Cork002
		base = Enum.Material.Cardboard,
		studsPerTile = 6,
		color = "rbxassetid://116250822379910",
		normal = "rbxassetid://138250345893095",
		roughness = "rbxassetid://108333057618621",
	},
	-- Showers, Recovery and Massage (2026-10-26, picked by the user from a preview board).
	Showers_BlueMosaic = { -- ambientcg Tiles035
		base = Enum.Material.CeramicTiles,
		studsPerTile = 5,
		color = "rbxassetid://79063036119056",
		normal = "rbxassetid://118506027233058",
		roughness = "rbxassetid://136996293743606",
	},
	Showers_MarbleBrick = { -- ambientcg Tiles010
		base = Enum.Material.CeramicTiles,
		studsPerTile = 5,
		color = "rbxassetid://113634510763149",
		normal = "rbxassetid://88969744448400",
		roughness = "rbxassetid://92946355183459",
	},
	Showers_Terrazzo = { -- ambientcg Terrazzo018
		base = Enum.Material.Marble,
		studsPerTile = 8,
		color = "rbxassetid://120098259872294",
		normal = "rbxassetid://93489427314386",
		roughness = "rbxassetid://123968892636231",
	},
	Recovery_Rubber = { -- ambientcg Rubber004
		base = Enum.Material.Rubber,
		studsPerTile = 10,
		color = "rbxassetid://72558321603795",
		normal = "rbxassetid://110859541932271",
		roughness = "rbxassetid://94838493037491",
	},
	Recovery_MicroCement = { -- ambientcg Concrete048
		base = Enum.Material.Concrete,
		studsPerTile = 14,
		color = "rbxassetid://79376788124469",
		normal = "rbxassetid://134234346592830",
		roughness = "rbxassetid://111992267111245",
	},
	Massage_LightWood = { -- ambientcg WoodFloor051
		base = Enum.Material.WoodPlanks,
		studsPerTile = 10,
		color = "rbxassetid://72532828654279",
		normal = "rbxassetid://79403708872298",
		roughness = "rbxassetid://118527570413370",
	},
	Massage_StoneWall = { -- polyhaven japanese_stone_wall
		base = Enum.Material.Slate,
		studsPerTile = 12,
		color = "rbxassetid://124186023288911",
		normal = "rbxassetid://78046982833492",
		roughness = "rbxassetid://112502857619364",
	},
	Massage_Limewash = { -- polyhaven painted_plaster_wall
		base = Enum.Material.Plaster,
		studsPerTile = 12,
		color = "rbxassetid://105884708597781",
		normal = "rbxassetid://80941039028506",
		roughness = "rbxassetid://128584025842739",
	},
	-- Themed room fronts, batch 1 (2026-10-26).
	Strongman_Timber = { -- polyhaven weathered_brown_planks
		base = Enum.Material.WoodPlanks,
		studsPerTile = 10,
		color = "rbxassetid://115601618684425",
		normal = "rbxassetid://89422451719522",
		roughness = "rbxassetid://118545744197354",
	},
	Strongman_SteelPlates = { -- ambientCG MetalPlates013
		base = Enum.Material.Metal,
		studsPerTile = 8,
		color = "rbxassetid://109321439128150",
		normal = "rbxassetid://86451185616305",
		roughness = "rbxassetid://130651176889490",
	},
	Dumbbells_DiamondPlate = { -- ambientCG DiamondPlate008A
		base = Enum.Material.DiamondPlate,
		studsPerTile = 6,
		color = "rbxassetid://103167934441698",
		normal = "rbxassetid://84895998611329",
		roughness = "rbxassetid://101546373474764",
	},
	Cardio_Track = { -- polyhaven rubberized_track
		base = Enum.Material.Rubber,
		studsPerTile = 10,
		color = "rbxassetid://115211432323838",
		normal = "rbxassetid://97991264023733",
		roughness = "rbxassetid://135222975761483",
	},
	-- The Strongman Shed (2026-10-26).
	Shed_CorrugatedSteel = { -- ambientCG CorrugatedSteel005
		base = Enum.Material.Metal,
		studsPerTile = 8,
		color = "rbxassetid://78063520458469",
		normal = "rbxassetid://108554226634224",
		roughness = "rbxassetid://110330213785139",
	},
	Shed_Shutter = { -- polyhaven painted_metal_shutter
		base = Enum.Material.Metal,
		studsPerTile = 6,
		color = "rbxassetid://121529721433172",
		normal = "rbxassetid://119842376730446",
		roughness = "rbxassetid://75579880290713",
	},
	-- Themed room fronts, batch 2a (2026-10-26, picked by the user from a preview board).
	Office_Walnut = { -- polyhaven walnut_veneer_02
		base = Enum.Material.Wood,
		studsPerTile = 8,
		color = "rbxassetid://94298329377256",
		normal = "rbxassetid://120418570645120",
		roughness = "rbxassetid://128706919134224",
	},
	Machines_SteelPanels = { -- ambientCG MetalPlates001
		base = Enum.Material.Metal,
		studsPerTile = 10,
		color = "rbxassetid://120663242806268",
		normal = "rbxassetid://77095484702474",
		roughness = "rbxassetid://122670398560555",
	},
	Index_Tiles = { -- ambientCG Tiles107
		base = Enum.Material.CeramicTiles,
		studsPerTile = 6,
		color = "rbxassetid://84345694547823",
		normal = "rbxassetid://125733647653307",
		roughness = "rbxassetid://72505428069044",
	},
	Storage_Corrugated = { -- ambientCG CorrugatedSteel006A
		base = Enum.Material.Metal,
		studsPerTile = 8,
		color = "rbxassetid://95672327931285",
		normal = "rbxassetid://90858943002731",
		roughness = "rbxassetid://108191610762847",
	},
	-- Themed room fronts, batch 2b (2026-10-26, picked by the user from a preview board).
	Classroom_Chalkboard = { -- ambientCG Plaster001
		base = Enum.Material.Plaster,
		studsPerTile = 10,
		color = "rbxassetid://112307825250984",
		normal = "rbxassetid://127097939765707",
		roughness = "rbxassetid://103438640351702",
	},
	Media_Foam = { -- ambientCG AcousticFoam003 (colour map lightened so tints show)
		base = Enum.Material.Fabric,
		studsPerTile = 4,
		color = "rbxassetid://122357090322313",
		normal = "rbxassetid://75000682808290",
		roughness = "rbxassetid://128022995157349",
	},
	Media_Felt = { -- ambientCG Fabric030
		base = Enum.Material.Fabric,
		studsPerTile = 8,
		color = "rbxassetid://116386534932599",
		normal = "rbxassetid://81250484802635",
		roughness = "rbxassetid://123834114511186",
	},
	Coaches_Panels = { -- polyhaven white_planks_clean
		base = Enum.Material.WoodPlanks,
		studsPerTile = 8,
		color = "rbxassetid://97890308702102",
		normal = "rbxassetid://125195452589850",
		roughness = "rbxassetid://130902670264775",
	},
} :: { [string]: MaterialVariantSpec }

-- The Classroom front's chalk drawings (transparent PNGs drawn by art/scripts/draw_chalk_lessons.py, uploaded
-- as group images, user-approved 2026-10-26), left to right on the chalkboard.
StarterGymConfig.ChalkLessons = {
	"rbxassetid://82768532927795", -- TECHNIQUE 101: the big three
	"rbxassetid://105865566921970", -- squat
	"rbxassetid://109475773438357", -- bench
	"rbxassetid://78602138170847", -- deadlift
}

-- Bright and clean, black rubber under the racks (References/Visual Style).
StarterGymConfig.Looks = {
	GymFloor = { material = Enum.Material.Rubber, color = Color3.fromRGB(30, 30, 32) },
	LobbyFloor = { material = Enum.Material.Concrete, color = Color3.fromRGB(168, 168, 164) },
	RoomFloor = { material = Enum.Material.CeramicTiles, color = Color3.fromRGB(205, 205, 200) },
	WallPaint = { material = Enum.Material.Plaster, color = Color3.fromRGB(228, 228, 224) },
	WallBand = { material = Enum.Material.Concrete, color = Color3.fromRGB(62, 62, 66) },
	-- Not the Glass material: Roblox hides see-through things behind Glass,
	-- signs included, so the lobby's logos were invisible from outside
	-- (user, 2026-10-21). Clear plastic with a little shine instead.
	Glass = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(196, 218, 230), transparency = 0.7,
		reflectance = 0.15 },
	-- The pitched roof is seen from below in the hall, so it stays light (bright and clean).
	HallRoof = { material = Enum.Material.Metal, color = Color3.fromRGB(212, 214, 218) },
	Skylight = { material = Enum.Material.Glass, color = Color3.fromRGB(205, 228, 240), transparency = 0.55 },
	SteelBeam = { material = Enum.Material.Metal, color = Color3.fromRGB(38, 38, 42) },
	-- Glass steps: less see-through than the walls, so players can see where to step.
	StairGlass = { material = Enum.Material.Glass, color = Color3.fromRGB(200, 224, 236), transparency = 0.35 },
	-- Reception: a white desk, dark name signs with white letters, steel gates.
	DeskBody = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(242, 242, 240) },
	DeskWork = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(222, 222, 220) },
	DeskPlinth = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(28, 28, 30) },
	SignPanel = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(22, 22, 24) },
	Gadget = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(18, 18, 20) }, -- monitor, keyboard
	Stainless = { material = Enum.Material.Metal, color = Color3.fromRGB(200, 202, 206) },
	TurnstileBody = { material = Enum.Material.Metal, color = Color3.fromRGB(42, 42, 46) },
	Ceiling = { material = Enum.Material.Plaster, color = Color3.fromRGB(246, 246, 244) },
	GlowWhite = { material = Enum.Material.Neon, color = Color3.fromRGB(255, 250, 240) },
	GlowGreen = { material = Enum.Material.Neon, color = Color3.fromRGB(60, 220, 110) },
	GlowRed = { material = Enum.Material.Neon, color = Color3.fromRGB(225, 40, 40) }, -- the door sensor while closed
	DoorFrame = { material = Enum.Material.Metal, color = Color3.fromRGB(52, 54, 58) }, -- the entrance doors' aluminium
	-- Room furniture (RoomProps, step 6).
	LockerBody = { material = Enum.Material.Metal, color = Color3.fromRGB(64, 70, 80) },
	Wood = { material = Enum.Material.Wood, color = Color3.fromRGB(190, 150, 104) },
	SaunaWood = { material = Enum.Material.WoodPlanks, color = Color3.fromRGB(178, 126, 78) },
	SaunaBench = { material = Enum.Material.Wood, color = Color3.fromRGB(214, 172, 118) }, -- lighter slats
	SaunaGlass = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(150, 108, 66), transparency = 0.45 },
	Tile = { material = Enum.Material.CeramicTiles, color = Color3.fromRGB(236, 238, 240) },
	Mat = { material = Enum.Material.Rubber, color = Color3.fromRGB(44, 44, 48) },
	Carpet = { material = Enum.Material.Fabric, color = Color3.fromRGB(150, 20, 28) }, -- the shop's red carpet
	Padding = { material = Enum.Material.Fabric, color = Color3.fromRGB(34, 34, 38) },
	PaddingBlue = { material = Enum.Material.Fabric, color = Color3.fromRGB(40, 78, 150) },
	Water = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(150, 205, 230), transparency = 0.25 },
	Cardboard = { material = Enum.Material.Cardboard, color = Color3.fromRGB(176, 136, 92) },
	Whiteboard = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(250, 250, 250) },
	Mirror = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(205, 214, 222), reflectance = 0.5 },
	Plant = { material = Enum.Material.Grass, color = Color3.fromRGB(70, 140, 62) },
	Stone = { material = Enum.Material.Slate, color = Color3.fromRGB(92, 92, 96) },
	GlowWarm = { material = Enum.Material.Neon, color = Color3.fromRGB(255, 140, 60) },
	-- IPF plate colours (SignAccentColor is the 25 kg red).
	PlateRed = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(200, 32, 40) },
	PlateBlue = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(30, 72, 180) },
	PlateYellow = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(232, 190, 30) },
	PlateGreen = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(40, 150, 70) },
	ShirtBlack = { material = Enum.Material.Fabric, color = Color3.fromRGB(26, 26, 28) },
	ShirtWhite = { material = Enum.Material.Fabric, color = Color3.fromRGB(235, 235, 232) },
	ShirtRed = { material = Enum.Material.Fabric, color = Color3.fromRGB(190, 30, 38) },
	-- The supplement bar (2026-10-25): textured materials, white so the maps show their own colours.
	SBarFloor = { material = Enum.Material.WoodPlanks, color = Color3.fromRGB(255, 255, 255), variant = "SBar_DarkWoodFloor" },
	SBarTiles = { material = Enum.Material.CeramicTiles, color = Color3.fromRGB(255, 255, 255), variant = "SBar_CreamWallTiles" },
	SBarMarble = { material = Enum.Material.Marble, color = Color3.fromRGB(255, 255, 255), variant = "SBar_BlackMarble" },
	SBarPlanks = { material = Enum.Material.Wood, color = Color3.fromRGB(255, 255, 255), variant = "SBar_DarkPlanks" },
	SBarWall = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(34, 34, 38) }, -- charcoal side walls
	-- Lockers, Cafe and Staff Room (2026-10-25): textured the same way.
	LockersFloor = { material = Enum.Material.CeramicTiles, color = Color3.fromRGB(255, 255, 255), variant = "Lockers_DarkGridTiles" },
	LockersSlats = { material = Enum.Material.Wood, color = Color3.fromRGB(255, 255, 255), variant = "Lockers_OakSlats" },
	LockersPenny = { material = Enum.Material.CeramicTiles, color = Color3.fromRGB(255, 255, 255), variant = "Lockers_GreenPennyTiles" },
	LockersWall = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(226, 226, 222) }, -- warm white walls
	CafeFloor = { material = Enum.Material.WoodPlanks, color = Color3.fromRGB(255, 255, 255), variant = "Cafe_Herringbone" },
	CafeBrick = { material = Enum.Material.Brick, color = Color3.fromRGB(255, 255, 255), variant = "Cafe_RedBrick" },
	CafeTiles = { material = Enum.Material.CeramicTiles, color = Color3.fromRGB(255, 255, 255), variant = "Cafe_GreenTiles" },
	CafeMarble = { material = Enum.Material.Marble, color = Color3.fromRGB(255, 255, 255), variant = "Cafe_WhiteMarble" },
	CafeWall = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(238, 230, 214) }, -- cream walls
	StaffFloor = { material = Enum.Material.WoodPlanks, color = Color3.fromRGB(255, 255, 255), variant = "Staff_Laminate" },
	StaffWorktop = { material = Enum.Material.Wood, color = Color3.fromRGB(255, 255, 255), variant = "Staff_WoodWorktop" },
	StaffCork = { material = Enum.Material.Cardboard, color = Color3.fromRGB(255, 255, 255), variant = "Staff_Cork" },
	StaffCabinet = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(140, 164, 134) }, -- sage kitchen units
	StaffAccent = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(96, 132, 160) }, -- a dusty blue wall
	-- Showers, Recovery and Massage (2026-10-26): textured the same way.
	ShowersFloor = { material = Enum.Material.CeramicTiles, color = Color3.fromRGB(255, 255, 255), variant = "Showers_BlueMosaic" },
	ShowersTiles = { material = Enum.Material.CeramicTiles, color = Color3.fromRGB(255, 255, 255), variant = "Showers_MarbleBrick" },
	ShowersTerrazzo = { material = Enum.Material.Marble, color = Color3.fromRGB(255, 255, 255), variant = "Showers_Terrazzo" },
	RecoveryFloor = { material = Enum.Material.Rubber, color = Color3.fromRGB(255, 255, 255), variant = "Recovery_Rubber" },
	RecoveryCement = { material = Enum.Material.Concrete, color = Color3.fromRGB(255, 255, 255), variant = "Recovery_MicroCement" },
	RecoveryWall = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(198, 222, 234) }, -- icy blue walls
	GlowIce = { material = Enum.Material.Neon, color = Color3.fromRGB(150, 215, 255) },
	MatTeal = { material = Enum.Material.Rubber, color = Color3.fromRGB(0, 138, 140) }, -- stretching mats
	MatCoral = { material = Enum.Material.Rubber, color = Color3.fromRGB(238, 112, 92) },
	MatLavender = { material = Enum.Material.Rubber, color = Color3.fromRGB(184, 170, 222) },
	MassageFloor = { material = Enum.Material.WoodPlanks, color = Color3.fromRGB(255, 255, 255), variant = "Massage_LightWood" },
	MassageStone = { material = Enum.Material.Slate, color = Color3.fromRGB(255, 255, 255), variant = "Massage_StoneWall" },
	-- The grey limewash tinted warm (Roblox multiplies the map by the colour).
	MassageWall = { material = Enum.Material.Plaster, color = Color3.fromRGB(255, 236, 214), variant = "Massage_Limewash" },
	-- The door of a closed room without a colour of its own (2026-10-26).
	DoorPlain = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(236, 236, 232) },
	-- The Strongman Shed's turf lanes (yoke, farmer's walk).
	YardTurf = { material = Enum.Material.Grass, color = Color3.fromRGB(78, 132, 62) },
	-- The Strongman Shed's corrugated steel (tinted dark) and its roller door's shutter.
	ShedSteel = { material = Enum.Material.Metal, color = Color3.fromRGB(92, 96, 104), variant = "Shed_CorrugatedSteel" },
	ShedShutter = { material = Enum.Material.Metal, color = Color3.fromRGB(205, 205, 210), variant = "Shed_Shutter" },
	-- Themed room fronts, batch 1 (2026-10-26).
	StrongmanTimber = { material = Enum.Material.WoodPlanks, color = Color3.fromRGB(255, 255, 255), variant = "Strongman_Timber" },
	StrongmanSteel = { material = Enum.Material.Metal, color = Color3.fromRGB(255, 255, 255), variant = "Strongman_SteelPlates" },
	-- The diamond plate's map is a pale steel: tinted dark, it reads as black steel plate.
	DumbbellsPlate = { material = Enum.Material.DiamondPlate, color = Color3.fromRGB(92, 94, 100), variant = "Dumbbells_DiamondPlate" },
	CardioTrack = { material = Enum.Material.Rubber, color = Color3.fromRGB(255, 255, 255), variant = "Cardio_Track" },
	FrontCharcoal = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(38, 40, 46) },
	FrontGraphite = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(30, 34, 44) },
	MaxBlack = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(16, 16, 18) },
	LaneWhite = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(240, 240, 236) },
	-- Rusted barbells on the Max Testing wall (user, 2026-10-26: black bars were invisible on black).
	RustBar = { material = Enum.Material.CorrodedMetal, color = Color3.fromRGB(118, 66, 40) },
	RustSleeve = { material = Enum.Material.CorrodedMetal, color = Color3.fromRGB(96, 76, 64) }, -- the rusted bar's sleeves
	-- Themed room fronts, batch 2a (2026-10-26). The walnut veneer tinted dark; the white tiles tinted teal.
	OfficeWalnut = { material = Enum.Material.Wood, color = Color3.fromRGB(84, 62, 52), variant = "Office_Walnut" },
	MachinesSteel = { material = Enum.Material.Metal, color = Color3.fromRGB(150, 154, 160), variant = "Machines_SteelPanels" },
	IndexTiles = { material = Enum.Material.CeramicTiles, color = Color3.fromRGB(16, 112, 116), variant = "Index_Tiles" },
	StorageSteel = { material = Enum.Material.Metal, color = Color3.fromRGB(255, 255, 255), variant = "Storage_Corrugated" },
	-- A frosted office window, half see-through: the blinds and a pale panel behind it stand in for the room
	-- (no seeing in).
	FrostedGlass = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(212, 226, 232), transparency = 0.45,
		reflectance = 0.2 },
	Brass = { material = Enum.Material.Metal, color = Color3.fromRGB(200, 160, 82) },
	GlowTeal = { material = Enum.Material.Neon, color = Color3.fromRGB(60, 220, 210) },
	GlowGold = { material = Enum.Material.Neon, color = Color3.fromRGB(255, 196, 60) },
	-- Themed room fronts, batch 2b (2026-10-26), tinted darker than the board (Studio shows them brighter).
	ClassroomBoard = { material = Enum.Material.Plaster, color = Color3.fromRGB(46, 72, 66), variant = "Classroom_Chalkboard" },
	MediaFelt = { material = Enum.Material.Fabric, color = Color3.fromRGB(84, 84, 98), variant = "Media_Felt" },
	CoachesNavy = { material = Enum.Material.WoodPlanks, color = Color3.fromRGB(32, 54, 124), variant = "Coaches_Panels" },
	-- The Media Room's acoustic foam panels in several colours.
	FoamRed = { material = Enum.Material.Fabric, color = Color3.fromRGB(220, 60, 60), variant = "Media_Foam" },
	FoamBlue = { material = Enum.Material.Fabric, color = Color3.fromRGB(50, 110, 210), variant = "Media_Foam" },
	FoamYellow = { material = Enum.Material.Fabric, color = Color3.fromRGB(240, 180, 40), variant = "Media_Foam" },
	FoamGreen = { material = Enum.Material.Fabric, color = Color3.fromRGB(60, 180, 110), variant = "Media_Foam" },
	FoamPurple = { material = Enum.Material.Fabric, color = Color3.fromRGB(130, 70, 200), variant = "Media_Foam" },
	FoamGrey = { material = Enum.Material.Fabric, color = Color3.fromRGB(120, 122, 130), variant = "Media_Foam" },
} :: { [string]: Look }
-- Each closed room's colour (ClosedRooms) as a look: its wall on the hall side and its door.
for name, closed in pairs(StarterGymConfig.ClosedRooms) do
	if closed.colour then
		StarterGymConfig.Looks["HallFront_" .. name] = { material = Enum.Material.SmoothPlastic, color = closed.colour }
	end
end

--[[
	Where everything goes, worked out from the rack floor plan. Pure maths, used
	by StarterGymBuilder and by the Studio check and setup scripts, so they can
	never disagree. X and Z values are INSIDE faces; the walls stand outside them.
]]
export type Footprint = {
	hallMinX: number,
	hallMaxX: number,
	hallFrontZ: number, -- the hall's front glass wall stands just in front of this
	hallBackZ: number, -- the back wall stands just behind this
	frontZ: number, -- the front wall (entrance) stands just in front of this
	centreX: number, -- the building's middle (the rows' centre)
	hallHalfWidth: number,
	outerHalfWidth: number, -- the side outer walls stand just outside centreX +/- this
	lobbyHalfWidth: number,
	floorY: number, -- top of the ground floor
	upperFloorY: number, -- top of the upper floor
	upperSlabBottomY: number, -- the ground floor's ceiling
	roofSlabBottomY: number, -- the upper floor's ceiling
	roofY: number, -- top of the room blocks' flat roofs = the hall's eaves
}

type FloorPlan = {
	rows: number,
	racksPerRow: number,
	rackSpacingStuds: number,
	rowSpacingStuds: number,
	firstRowZ: number,
	rowCentreX: number,
	floorY: number,
}

function StarterGymConfig.footprint(layout: FloorPlan): Footprint
	local cfg = StarterGymConfig
	local halfRow = (layout.racksPerRow - 1) / 2 * layout.rackSpacingStuds
	local hallHalfWidth = halfRow + layout.rackSpacingStuds / 2 + cfg.SideAisleStuds
	local lastRowZ = layout.firstRowZ + (layout.rows - 1) * layout.rowSpacingStuds
	local hallFrontZ = layout.firstRowZ - cfg.RackFrontClearanceStuds - cfg.FrontOpenAreaStuds
	local upperFloorY = layout.floorY + cfg.StoreyHeightStuds
	local roofY = upperFloorY + cfg.StoreyHeightStuds
	return {
		hallMinX = layout.rowCentreX - hallHalfWidth,
		hallMaxX = layout.rowCentreX + hallHalfWidth,
		hallFrontZ = hallFrontZ,
		hallBackZ = lastRowZ + cfg.RackBackReachStuds + cfg.BackAisleStuds,
		frontZ = hallFrontZ - cfg.WallThicknessStuds - cfg.FrontBlockDepthStuds,
		centreX = layout.rowCentreX,
		hallHalfWidth = hallHalfWidth,
		outerHalfWidth = hallHalfWidth + cfg.WallThicknessStuds + cfg.SideBlockDepthStuds,
		lobbyHalfWidth = cfg.LobbyWidthStuds / 2,
		floorY = layout.floorY,
		upperFloorY = upperFloorY,
		upperSlabBottomY = upperFloorY - cfg.SlabThicknessStuds,
		roofSlabBottomY = roofY - cfg.SlabThicknessStuds,
		roofY = roofY,
	}
end

-- Every room's name, once each (a name in two neighbouring places is one
-- room; the spa wing is its reception and its rooms).
function StarterGymConfig.roomNames(): { string }
	local wing = StarterGymConfig.SpaWing
	local names = {}
	local function add(name: string)
		if not table.find(names, name) then
			table.insert(names, name)
		end
	end
	for _, list in pairs(StarterGymConfig.Rooms) do
		for _, name in pairs(list) do
			if name == wing.name then
				add(wing.reception)
				for _, wingRoom in ipairs(wing.rooms) do
					add(wingRoom.name)
				end
			else
				add(name)
			end
		end
	end
	return names
end

-- The text on a room's sign and door plaque.
function StarterGymConfig.roomLabel(name: string): string
	local closed = StarterGymConfig.ClosedRooms[name]
	return if closed then closed.label else string.upper(name)
end

-- The real door in a room's doorway (ClosedRooms), or nil for a room with an
-- open doorway: a glass-fronted room, the lobby and the OpenDoorwayRooms.
function StarterGymConfig.swingDoorFor(name: string): SwingDoorSpec?
	local cfg = StarterGymConfig
	local own = cfg.SwingDoors[name]
	if own then
		return own
	end
	if cfg.GlassFrontRooms[name] or cfg.OpenDoorwayRooms[name] or name == cfg.Rooms.FrontGround[2] then
		return nil
	end
	local spec = table.clone(cfg.ClosedRoomDoor)
	local closed = cfg.ClosedRooms[name]
	if closed then
		spec.look = closed.door or (if closed.colour then "HallFront_" .. name else spec.look)
		spec.plaque = closed.plaque
	end
	return spec
end

return StarterGymConfig
