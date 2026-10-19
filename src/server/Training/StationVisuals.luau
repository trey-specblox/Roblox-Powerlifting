--!strict
--[[
	StationVisuals
	Server / Training

	Makes a rack LOOK like the lift its occupant selected (GAME_DESIGN.md
	§34.12, decision 15). Visual only: it changes no rule, credit, presence or
	collision, and every station stays universal.

	  free / no lift yet   bench shown, J-cups at bench height, bar in the J-cups
	  Bench                bench shown, J-cups at bench height, bar in the J-cups
	  Squat                bench hidden, J-cups and bar raised to the squat hole
	  Deadlift             bench hidden, bar on the floor in front of the rack

	Every rack with a layout gets its own barbell (a "Barbell" Model inside the
	rack), built from ServerStorage.BarbellTemplates.Barbell_01 and loaded with
	TrainingStationConfig.BarbellDisplayLoadPerSide. It is decoration: anchored,
	not solid, not queryable.

	Runs on the server, so every player sees the same rack. Positions come from
	StationLayout; a rack without a layout (PowerRack_01) is left as it is.
	The lifter's position is StationPoses' job.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TrainingStationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("TrainingStationConfig"))
local StationLayout = require(script.Parent.StationLayout)

local StationVisuals = {}

local BARBELL_FOLDER, BARBELL_TEMPLATE = "BarbellTemplates", "Barbell_01"
-- Where the plates start on each sleeve: art/scripts/build_barbell_01.py COLLAR_X1.
local SLEEVE_START = 3.31

type Barbell = {
	-- Each part with its place relative to the bar's centre.
	parts: { { part: BasePart, offset: CFrame } },
	-- Largest plate radius: the bar's height when it lies on the floor.
	plateRadius: number,
}

-- Each moving part's modelled (bench-height) CFrame, remembered the first time the rack is shown.
local baseCFrames: { [BasePart]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
-- The look each rack last got, so repeated sign refreshes change nothing.
local lastLook: { [Instance]: string } = setmetatable({}, { __mode = "k" }) :: any
local barbells: { [Instance]: Barbell } = setmetatable({}, { __mode = "k" }) :: any
local warnedMissingTemplate = false

local function findPart(rack: Instance, name: string): BasePart?
	local part = rack:FindFirstChild(name, true)
	if part ~= nil and part:IsA("BasePart") then
		return part
	end
	return nil
end

local function decorate(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

--[[
	Builds the rack's barbell from the template, loaded with the display load.
	Returns nil (after one warning per server) if the template is missing; the
	rack then simply has no bar.
]]
local function buildBarbell(rack: Model): Barbell?
	local folder = ServerStorage:FindFirstChild(BARBELL_FOLDER)
	local template = folder and folder:FindFirstChild(BARBELL_TEMPLATE)
	local shaft = template and template:FindFirstChild("Bar_Shaft")
	local sleeves = template and template:FindFirstChild("Bar_Sleeves")
	if template == nil or shaft == nil or sleeves == nil or not shaft:IsA("BasePart") or not sleeves:IsA("BasePart") then
		if not warnedMissingTemplate then
			warnedMissingTemplate = true
			warn(string.format("[StationVisuals] ServerStorage.%s.%s is missing or incomplete; racks get no barbell",
				BARBELL_FOLDER, BARBELL_TEMPLATE))
		end
		return nil
	end

	local model = Instance.new("Model")
	model.Name = "Barbell"
	local barbell: Barbell = { parts = {}, plateRadius = 0 }

	local function add(source: BasePart, offset: CFrame)
		local part = source:Clone()
		decorate(part)
		part.Parent = model
		table.insert(barbell.parts, { part = part, offset = offset })
	end

	-- The bar, placed relative to the shaft's centre (the template's bar lies along its X).
	add(shaft, CFrame.identity)
	add(sleeves, shaft.CFrame:ToObjectSpace(sleeves.CFrame))

	-- Plates and collar, stacked outwards from each sleeve's start.
	local load = table.clone(TrainingStationConfig.BarbellDisplayLoadPerSide)
	table.insert(load, "Collar_Lock")
	for _, side in ipairs({ 1, -1 }) do
		local x = SLEEVE_START
		for _, name in ipairs(load) do
			local source = template:FindFirstChild(name)
			if source == nil or not source:IsA("BasePart") then
				warn("[StationVisuals] barbell template has no part " .. name .. "; skipped")
				continue
			end
			local width = source.Size.X
			add(source, CFrame.new(side * (x + width / 2), 0, 0))
			x += width
			if string.sub(name, 1, 6) == "Plate_" then
				barbell.plateRadius = math.max(barbell.plateRadius, source.Size.Y / 2)
			end
		end
	end

	model.Parent = rack
	return barbell
end

local function placeBarbell(barbell: Barbell, rack: Model, centre: Vector3)
	local frame = StationLayout.floorFrame(rack) * CFrame.new(centre)
	for _, entry in ipairs(barbell.parts) do
		entry.part.CFrame = frame * entry.offset
	end
end

--[[
	Shows `rack` for `lift` ("Squat", "Bench", "Deadlift", or nil for a free rack
	or one whose occupant has not picked a lift yet). Safe to call as often as
	the sign refreshes; it only changes parts when the look changes.
]]
function StationVisuals.show(rack: Instance, lift: string?)
	local layout = StationLayout.of(rack)
	if layout == nil or not rack:IsA("Model") then
		return
	end

	local look = lift or "Free"
	if lastLook[rack] == look then
		return
	end
	lastLook[rack] = look

	local benchVisible = lift ~= "Squat" and lift ~= "Deadlift"
	for _, name in ipairs(layout.benchParts) do
		local part = findPart(rack, name)
		if part then
			part.Transparency = if benchVisible then 0 else 1
			part.CastShadow = benchVisible
		end
	end

	local raise = if lift == "Squat" then layout.squatRaise else 0
	-- Up along the rack's own vertical (its StandPoint pivot), so a turned rack works too.
	local up = rack:GetPivot().UpVector
	for _, name in ipairs(layout.jCupParts) do
		local part = findPart(rack, name)
		if part then
			local base: CFrame = baseCFrames[part] or part.CFrame
			baseCFrames[part] = base
			part.CFrame = base + up * raise
		end
	end

	local barbell: Barbell? = barbells[rack]
	if barbell == nil then
		barbell = buildBarbell(rack)
		if barbell ~= nil then
			barbells[rack] = barbell
		end
	end
	if barbell then
		local centre = if lift == "Deadlift"
			then Vector3.new(0, barbell.plateRadius, layout.deadliftBarZ)
			else layout.barRest + Vector3.new(0, raise, 0)
		placeBarbell(barbell, rack, centre)
	end
end

return StationVisuals
