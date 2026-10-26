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
}
StarterGymConfig.SwingDoors = {
	Sauna = { openingWidth = 8, openingHeight = 10, leaves = 2, width = 7.4, height = 9, window = true,
		look = "SaunaWood", frame = "SaunaWood", handle = "SaunaBench" },
	Lockers = { openingWidth = 6, openingHeight = 9, leaves = 1, width = 5.2, height = 8.6, window = false,
		look = "LockersSlats", frame = "SignPanel", handle = "Stainless" },
} :: { [string]: SwingDoorSpec }
StarterGymConfig.SwingDoorSensorReachStuds = 5 -- on each side of the wall
-- Rooms with a solid wall onto the hall instead of glass (privacy; user,
-- 2026-10-25: the lockers), with the big sign over the door on its hall side
-- (oak slats around it). Front block, ground floor only for now.
StarterGymConfig.PrivateRooms = { Lockers = "LOCKER ROOM" } :: { [string]: string }

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
	LeftGround = { "Office", "Recovery", "Massage", "Physio" },
	RightGround = { "Storage", "SupplementBar", "Coach", "Shop" },
	LeftUpper = { "Room4", "Room3", "Room2", "Room1" },
	RightUpper = { "Sauna", "Sauna", "Room6", "Room5" },
	-- The front block between its two corner rooms, LEFT TO RIGHT as you walk in.
	-- Ground: the middle one is the lobby (LobbyWidthStuds); upstairs: equal widths.
	FrontGround = { "Lockers", "Lobby", "Cafe" },
	FrontUpper = { "WarmUp", "MaxTesting", "Studio" },
	-- The front corners, both floors (the stairs' place in the drawing; see stage 3).
	-- Ground: reached through Lockers (left) and Cafe (right). The Staff Room was
	-- the Kitchen (user, 2026-10-25: the steak kitchen becomes its own building).
	CornerGround = { Left = "Showers", Right = "StaffRoom" },
	CornerUpper = { Left = "CornerLeftUpper", Right = "CornerRightUpper" },
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
} :: { [string]: PropPaint }

-- Pieces made of cloth (Fabric) whatever their colour, as "<Item>_<Piece>".
StarterGymConfig.PropFabricPieces = {
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
} :: { [string]: MaterialVariantSpec }

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
} :: { [string]: Look }

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

return StarterGymConfig
