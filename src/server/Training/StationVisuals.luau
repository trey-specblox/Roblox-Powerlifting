--!strict
--[[
	StationVisuals
	Server / Training

	Makes a rack LOOK like the lift its occupant selected (GAME_DESIGN.md
	§34.12, decision 15). Visual only: it changes no rule, credit, presence or
	collision, and every station stays universal.

	  free / no lift yet   bench shown, J-cups at bench height (as modelled)
	  Bench                bench shown, J-cups at bench height
	  Squat                bench hidden, J-cups raised to the squat hole
	  Deadlift             bench hidden (the lifter pulls in front of the rack)

	Runs on the server, so every player sees the same rack. Which parts move is
	set per template in PROFILES; RackSpawner stores the template name on each
	rack as the "RackTemplate" attribute. A rack without a profile (PowerRack_01)
	is left exactly as it is.

	Player poses are a later step and are not handled here.
]]

local StationVisuals = {}

type VisualProfile = {
	-- Hidden for squat and deadlift. Must be non-colliding parts (RackConfigurator).
	benchParts: { string },
	-- Moved together between the bench and squat holes.
	jCupParts: { string },
	-- Studs from the bench hole (as modelled) up to the squat hole.
	squatRaise: number,
}

local PROFILES: { [string]: VisualProfile } = {
	-- art/scripts/build_combo_rack_01.py: J-cups modelled at BENCH_HOLE 3.80;
	-- SQUAT_HOLE is 4.50, two holes (0.70 studs) higher.
	ComboRack_01 = {
		benchParts = { "Bench_Pad", "Bench_Frame" },
		jCupParts = { "JCup_Left", "JCup_Right", "JCupLiner_Left", "JCupLiner_Right", "JCupPin_Left", "JCupPin_Right" },
		squatRaise = 0.70,
	},
}

-- Each moving part's modelled (bench-height) CFrame, remembered the first time the rack is shown.
local baseCFrames: { [BasePart]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
-- The look each rack last got, so repeated sign refreshes change nothing.
local lastLook: { [Instance]: string } = setmetatable({}, { __mode = "k" }) :: any

local function findPart(rack: Instance, name: string): BasePart?
	local part = rack:FindFirstChild(name, true)
	if part ~= nil and part:IsA("BasePart") then
		return part
	end
	return nil
end

--[[
	Shows `rack` for `lift` ("Squat", "Bench", "Deadlift", or nil for a free rack
	or one whose occupant has not picked a lift yet). Safe to call as often as
	the sign refreshes; it only changes parts when the look changes.
]]
function StationVisuals.show(rack: Instance, lift: string?)
	local templateName = rack:GetAttribute("RackTemplate")
	local profile = if typeof(templateName) == "string" then PROFILES[templateName] else nil
	if profile == nil then
		return
	end

	local look = lift or "Free"
	if lastLook[rack] == look then
		return
	end
	lastLook[rack] = look

	local benchVisible = lift ~= "Squat" and lift ~= "Deadlift"
	for _, name in ipairs(profile.benchParts) do
		local part = findPart(rack, name)
		if part then
			part.Transparency = if benchVisible then 0 else 1
			part.CastShadow = benchVisible
		end
	end

	local raise = if lift == "Squat" then profile.squatRaise else 0
	-- Up along the rack's own vertical (its StandPoint pivot), so a turned rack works too.
	local up = if rack:IsA("Model") then rack:GetPivot().UpVector else Vector3.yAxis
	for _, name in ipairs(profile.jCupParts) do
		local part = findPart(rack, name)
		if part then
			local base: CFrame = baseCFrames[part] or part.CFrame
			baseCFrames[part] = base
			part.CFrame = base + up * raise
		end
	end
end

return StationVisuals
