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

	Built in stages. Stage 1 (now): floors, upper floor slabs, the room blocks'
	flat roofs, every wall and glass front, the rooms. Later stages: the hall's
	pitched roof with skylights, the stairs and balcony, reception desk and
	gym-name wall, lights.

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
StarterGymConfig.FrontOpenAreaStuds = 21 -- in front of row 1's lifting space, for later equipment

-- The room blocks.
StarterGymConfig.SideBlockDepthStuds = 30 -- left and right blocks, across (X)
StarterGymConfig.FrontBlockDepthStuds = 32 -- front block, front to back (Z)
StarterGymConfig.StoreyHeightStuds = 14 -- floor to floor; the hall's walls are two storeys tall
StarterGymConfig.SlabThicknessStuds = 1 -- upper floors and the blocks' flat roofs

StarterGymConfig.WallThicknessStuds = 1
StarterGymConfig.WallBandHeightStuds = 3 -- the dark strip along the bottom of the outer walls
StarterGymConfig.FloorThicknessStuds = 1

-- Openings.
StarterGymConfig.LobbyWidthStuds = 70 -- the lobby, in the middle of the front block
StarterGymConfig.LobbyOpeningWidthStuds = 46 -- the wide opening from the lobby into the hall
StarterGymConfig.LobbyOpeningHeightStuds = 10
StarterGymConfig.EntranceWidthStuds = 16 -- in the glass front of the lobby
StarterGymConfig.EntranceHeightStuds = 10
StarterGymConfig.RoomDoorWidthStuds = 6
StarterGymConfig.RoomDoorHeightStuds = 9

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

export type Look = { material: Enum.Material, color: Color3, transparency: number? }

-- Bright and clean, black rubber under the racks (References/Visual Style).
StarterGymConfig.Looks = {
	GymFloor = { material = Enum.Material.Rubber, color = Color3.fromRGB(30, 30, 32) },
	LobbyFloor = { material = Enum.Material.Concrete, color = Color3.fromRGB(168, 168, 164) },
	RoomFloor = { material = Enum.Material.CeramicTiles, color = Color3.fromRGB(205, 205, 200) },
	WallPaint = { material = Enum.Material.Plaster, color = Color3.fromRGB(228, 228, 224) },
	WallBand = { material = Enum.Material.Concrete, color = Color3.fromRGB(62, 62, 66) },
	Glass = { material = Enum.Material.Glass, color = Color3.fromRGB(196, 218, 230), transparency = 0.7 },
	Roof = { material = Enum.Material.Concrete, color = Color3.fromRGB(150, 150, 150) },
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
