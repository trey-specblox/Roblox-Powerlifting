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
	(2026-10-23) automatic sliding doors in the entrance. Later: lights.

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

--[[
	The rooms (GAME_DESIGN §27: names are PLACEHOLDERS until the NPCs are
	designed; a name here is only the room's name in Workspace). Each becomes an
	invisible region part "Room_<Name>" in Workspace.StarterGym.Rooms, with its
	floor and door position as attributes, ready for NPCs and signs later.
]]
StarterGymConfig.Rooms = {
	-- The side blocks, FRONT TO BACK. Left = +X (your left as you walk in).
	LeftGround = { "Office", "Recovery", "Massage", "Physio" },
	RightGround = { "Storage", "Sauna", "Coach", "Shop" },
	LeftUpper = { "Room4", "Room3", "Room2", "Room1" },
	RightUpper = { "Room8", "Room7", "Room6", "Room5" },
	-- The front block between its two corner rooms, LEFT TO RIGHT as you walk in.
	-- Ground: the middle one is the lobby (LobbyWidthStuds); upstairs: equal widths.
	FrontGround = { "Lockers", "Lobby", "Cafe" },
	FrontUpper = { "WarmUp", "MaxTesting", "Studio" },
	-- The front corners, both floors (the stairs' place in the drawing; see stage 3).
	CornerGround = { Left = "CornerLeft", Right = "CornerRight" },
	CornerUpper = { Left = "CornerLeftUpper", Right = "CornerRightUpper" },
}

export type Look = { material: Enum.Material, color: Color3, transparency: number?, reflectance: number? }

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
	ShirtBlack = { material = Enum.Material.Fabric, color = Color3.fromRGB(26, 26, 28) },
	ShirtWhite = { material = Enum.Material.Fabric, color = Color3.fromRGB(235, 235, 232) },
	ShirtRed = { material = Enum.Material.Fabric, color = Color3.fromRGB(190, 30, 38) },
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
