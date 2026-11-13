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
	-- J-cup offset from where they are modelled (the squat hole) to the bench hole,
	-- used for bench, deadlift and a free rack. Squat uses the modelled hole.
	benchJCupDrop: number,
	-- For the taller cartoon bodies (GAME_DESIGN §38.7, user 2026-11-12: everyone taller), the J-cups set higher, as a
	-- taller lifter sets them: squat (from the modelled hole) and bench (instead of benchJCupDrop). Used while the
	-- cartoon bodies are on (LifterBodyService.enabled); the block bodies keep the heights above.
	tallSquatJCupRaise: number,
	tallBenchJCupDrop: number,
	-- Bar centre resting in the J-cups as modelled (squat height).
	barRest: Vector3,
	-- Z of the bar on the floor for deadlift (its height comes from the plates).
	deadliftBarZ: number,
	-- Top of the bench pad, and the Z the lying lifter's head sits at (under the bar).
	benchPadTop: number,
	benchHeadZ: number,
	-- Z where the lifter stands for squat (walked out) and deadlift (behind the
	-- floor bar), both FACING THE RACK (+Z; user choices 2026-10-19), and where a
	-- released lifter is put back on their feet (facing -Z).
	squatStandZ: number,
	deadliftStandZ: number,
	exitZ: number,
}

local LAYOUTS: { [string]: Layout } = {
	-- art/scripts/build_combo_rack_01.py (Blender X/Y/Z = rack-local -X/Z/Y).
	ComboRack_01 = {
		benchParts = { "Bench_Pad", "Bench_Frame" },
		jCupParts = { "JCup_Left", "JCup_Right", "JCupLiner_Left", "JCupLiner_Right", "JCupPin_Left", "JCupPin_Right" },
		-- J-cups modelled at the 3.975 hole (squat, bar 3.665: at the lifter's shoulder blades, just under an
		-- R15 avatar's 3.75 bar-on-back height, so a slight knee bend gets under it; user 2026-11-08, "make it
		-- the height of their shoulder blades", was the 3.80 hole and bar 3.49); bench uses the 3.45 hole (bar
		-- 3.14: just under its 3.25 lockout lying on the bench). The posts' holes are 0.175 apart.
		benchJCupDrop = -0.525,
		-- 4 holes up (bar 4.365: just under the taller back's 4.41 bar-on-back height, art/scripts/lifter_heights.py),
		-- and the bench 1 hole up (bar 3.315: the longer arms lock out 0.23 higher).
		tallSquatJCupRaise = 0.70,
		tallBenchJCupDrop = -0.35,
		-- J-cup seat at z 3.595 + bar shaft radius 0.07; seat centre 0.28 in front of the posts
		barRest = Vector3.new(0, 3.665, -0.28),
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

--[[
	Z of the floor bar, and of the lifter behind it, for a deadlift. A meet platform's
	rack goes away for the deadlift (the attribute DeadliftAtCentre), so the bar lies
	in the middle of the platform instead of in front of where the rack stands.
]]
function StationLayout.deadliftZ(rack: Model, layout: Layout): (number, number)
	if rack:GetAttribute("DeadliftAtCentre") == true then
		return 0, layout.deadliftStandZ - layout.deadliftBarZ
	end
	return layout.deadliftBarZ, layout.deadliftStandZ
end

-- The rack's floor centre, oriented like the rack. Rack-local positions are relative to this.
function StationLayout.floorFrame(rack: Model): CFrame
	return rack:GetPivot() * CFrame.new(0, -RackConfigurator.StandPointSize.Y / 2, 0)
end

return StationLayout
