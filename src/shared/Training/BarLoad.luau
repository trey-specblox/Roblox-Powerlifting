--!strict
--[[
	BarLoad
	Shared / Training

	Works out what is on a bar for a weight (user 2026-11-07, with screenshots of
	each load). Visual only: it never decides a lift or a reward.

	  The bar is 20 kg.
	  22.5 kg is the bar and one silver a side, with no collars.
	  Anything heavier has a 2.5 kg collar on each side.
	  Each side then takes the biggest plates that fit, biggest first, nearest
	  the middle of the bar: 75 kg is one red and a collar, never a blue and a white.

	Sizes are read off the user's screenshots, relative to the red plate. Diameters
	and thicknesses are in studs; a red is 2 studs across (art/scripts/build_barbell_01.py).
]]

local BarLoad = {}

BarLoad.BarKg = 20
BarLoad.CollarKg = 2.5
-- The smallest step a bar can show: one silver a side.
BarLoad.StepKg = 2.5

-- Where a sleeve's loadable part starts and ends, from the bar's middle (build_barbell_01.py COLLAR_X1, SLEEVE_X1).
BarLoad.SleeveStart = 3.31
BarLoad.SleeveEnd = 4.95
BarLoad.CollarWidth = 0.222
-- The collar's mesh is scaled to this across its round part, a little under a silver (as in the screenshots).
BarLoad.CollarScale = 0.82
-- How high a bar lies with a full-size plate on it. The deadlift's hands reach exactly this far down.
BarLoad.FullPlateRadius = 1

-- The radius of the collar's round part, and of the bar's own inner flange (what a bare bar lies on).
local COLLAR_RADIUS = 0.2
local BAR_RADIUS = 0.17

export type Plate = { part: string, kg: number, diameter: number, thickness: number }

-- Heaviest first. `part` is the mesh in ServerStorage.BarbellTemplates.Barbell_01.
BarLoad.Plates = {
	{ part = "Plate_25", kg = 25, diameter = 2.0, thickness = 0.12 }, -- red
	{ part = "Plate_20", kg = 20, diameter = 2.0, thickness = 0.125 }, -- blue
	{ part = "Plate_15", kg = 15, diameter = 1.76, thickness = 0.125 }, -- yellow
	{ part = "Plate_10", kg = 10, diameter = 1.44, thickness = 0.115 }, -- green
	{ part = "Plate_5", kg = 5, diameter = 1.08, thickness = 0.11 }, -- white
	{ part = "Plate_2_5", kg = 2.5, diameter = 0.75, thickness = 0.125 }, -- black
	{ part = "Plate_1_25", kg = 1.25, diameter = 0.5, thickness = 0.06 }, -- silver
} :: { Plate }

export type Load = {
	-- What the bar really weighs: `kg` to the nearest step, and never under the bar itself.
	kg: number,
	-- One side's plates, from the middle of the bar outwards.
	plates: { Plate },
	collar: boolean,
	-- Every plate's thickness is multiplied by this: 1, unless a huge load would not fit on the sleeve otherwise.
	squeeze: number,
	-- How high the bar's middle is when it lies on what is on it, with nothing under it.
	restRadius: number,
}

function BarLoad.forKg(kg: number): Load
	local shown = math.max(BarLoad.BarKg, math.floor(kg / BarLoad.StepKg + 0.5) * BarLoad.StepKg)
	local perSide = (shown - BarLoad.BarKg) / 2
	local collar = shown > BarLoad.BarKg + BarLoad.StepKg
	if collar then
		perSide -= BarLoad.CollarKg
	end

	local plates: { Plate } = {}
	local width = 0
	for _, plate in ipairs(BarLoad.Plates) do
		while perSide >= plate.kg - 0.001 do
			table.insert(plates, plate)
			perSide -= plate.kg
			width += plate.thickness
		end
	end

	local room = BarLoad.SleeveEnd - BarLoad.SleeveStart - (if collar then BarLoad.CollarWidth else 0)
	local restRadius = if collar then COLLAR_RADIUS else BAR_RADIUS
	if plates[1] then
		restRadius = math.max(restRadius, plates[1].diameter / 2)
	end
	return {
		kg = shown,
		plates = plates,
		collar = collar,
		squeeze = if width > room then room / width else 1,
		restRadius = restRadius,
	}
end

return BarLoad
