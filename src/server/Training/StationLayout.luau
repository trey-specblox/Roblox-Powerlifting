--!strict
--[[
	StationLayout
	Server / Training

	Where things go on each rack model, for the station visuals (GAME_DESIGN.md
	§34.12, decision 15): which parts hide or move per lift, where the barbell
	rests, and where the lifter stands or lies. Read by StationVisuals (rack and
	barbell) and StationPoses (the lifter). Visual only: nothing here affects
	training rules, credit or presence.

	All positions are RACK-LOCAL, measured from the rack's floor centre (its
	StandPoint, on the floor): +Y up, and the rack's open front (J-cup side) is
	-Z. X runs along the barbell. Numbers come from the model's build script.

	A template without a layout (PowerRack_01) gets no visuals and no poses.
]]

local RackConfigurator = require(script.Parent.RackConfigurator)

local StationLayout = {}

export type Layout = {
	-- Hidden for squat and deadlift. Must be non-colliding parts (RackConfigurator).
	benchParts: { string },
	-- Moved together between the bench and squat holes.
	jCupParts: { string },
	-- Studs from the bench hole (as modelled) up to the squat hole.
	squatRaise: number,
	-- Bar centre resting in the J-cups at bench height (as modelled).
	barRest: Vector3,
	-- Z of the bar on the floor for deadlift (its height comes from the plates).
	deadliftBarZ: number,
	-- Top of the bench pad, and the Z the lying lifter's head sits at (under the bar).
	benchPadTop: number,
	benchHeadZ: number,
	-- Z where the lifter stands for squat (walked out, facing the open front, -Z),
	-- for deadlift (behind the bar, FACING THE RACK, +Z; user choice 2026-10-19),
	-- and where a released lifter is put back on their feet (facing -Z).
	squatStandZ: number,
	deadliftStandZ: number,
	exitZ: number,
}

local LAYOUTS: { [string]: Layout } = {
	-- art/scripts/build_combo_rack_01.py (Blender X/Y/Z = rack-local -X/Z/Y).
	ComboRack_01 = {
		benchParts = { "Bench_Pad", "Bench_Frame" },
		jCupParts = { "JCup_Left", "JCup_Right", "JCupLiner_Left", "JCupLiner_Right", "JCupPin_Left", "JCupPin_Right" },
		-- BENCH_HOLE 3.80 -> SQUAT_HOLE 4.50
		squatRaise = 0.70,
		-- J-cup seat at z 3.42 + bar shaft radius 0.07; seat centre 0.28 in front of the posts
		barRest = Vector3.new(0, 3.49, -0.28),
		-- the rack's clearance check keeps the floor 4.2 studs in front of the posts free
		deadliftBarZ = -4.2,
		benchPadTop = 1.2,
		benchHeadZ = -0.3,
		squatStandZ = -1.0,
		-- on the far side of the floor bar (z -4.2), shins just behind it
		deadliftStandZ = -4.8,
		-- in front of the deadlift bar and its plates (radius 1.0)
		exitZ = -6.2,
	},
}

-- The layout for a spawned rack (RackSpawner sets its RackTemplate attribute), or nil.
function StationLayout.of(rack: Instance): Layout?
	if not rack:IsA("Model") then
		return nil
	end
	local templateName = rack:GetAttribute("RackTemplate")
	if typeof(templateName) ~= "string" then
		return nil
	end
	return LAYOUTS[templateName]
end

-- The rack's floor centre, oriented like the rack. Rack-local positions are relative to this.
function StationLayout.floorFrame(rack: Model): CFrame
	return rack:GetPivot() * CFrame.new(0, -RackConfigurator.StandPointSize.Y / 2, 0)
end

return StationLayout
