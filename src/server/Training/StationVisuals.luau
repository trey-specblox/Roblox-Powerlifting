--!strict
--[[
	StationVisuals
	Server / Training

	Makes a rack LOOK like the lift its occupant selected (GAME_DESIGN.md
	§34.12, decision 15). Visual only: it changes no rule, credit, presence or
	collision, and every station stays universal.

	  free / no lift yet   bench shown, J-cups at the bench hole, bar in the J-cups
	  Bench                bench shown, J-cups at the bench hole, bar in the J-cups
	  Squat                bench hidden, J-cups and bar at the squat hole (as modelled)
	  Deadlift             bench hidden, bar on the floor in front of the rack
	                       (a meet's platform: the whole rack gone, only the bar; see show)

	Every rack with a layout gets its own barbell (a "Barbell" Model inside the
	rack), built from ServerStorage.BarbellTemplates.Barbell_01. It is decoration:
	anchored, not solid, not queryable.

	What is on it (loadBar, user 2026-11-07): the plates and collars for the weight
	being lifted (BarLoad), or until someone lifts on it, one of
	TrainingStationConfig.BarbellIdleLoadsKg.

	A deadlift starts with the hands a full plate's radius off the floor. A bar with
	only smaller plates on it lies lower than that, so it goes up on a stack of flat
	rubber plates ("BarBlocks", next to the barbell) to that same height, as a gym does.

	Runs on the server, so every player sees the same rack. Positions come from
	StationLayout; a rack without a layout (PowerRack_01) is left as it is.
	The lifter's position is StationPoses' job.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrainingStationConfig = require(Shared:WaitForChild("Config"):WaitForChild("TrainingStationConfig"))
local BarLoad = require(Shared:WaitForChild("Training"):WaitForChild("BarLoad"))
local StationLayout = require(script.Parent.StationLayout)
local LifterBodyService = require(script.Parent.Parent:WaitForChild("Economy"):WaitForChild("LifterBodyService"))

local StationVisuals = {}

local BARBELL_FOLDER, BARBELL_TEMPLATE = "BarbellTemplates", "Barbell_01"
local BARBELL_MODEL_NAME = "Barbell"
local BLOCKS_MODEL_NAME = "BarBlocks"
-- Each barbell part's place relative to the bar's centre, for clients (StationPoseAnimator).
local BAR_OFFSET_ATTRIBUTE = "BarOffset"
-- The flat stacks under a light deadlift bar: from the bar's middle, wide enough for whatever is on the sleeve.
local BLOCK_ALONG_BAR = 3.9
local BLOCK_DIAMETER = 1.7
local BLOCK_PLATE_THICKNESS = 0.18
local BLOCK_COLOUR = Color3.fromRGB(32, 32, 34)

type Barbell = {
	model: Model,
	template: Instance,
	shaft: BasePart,
	-- Each part with its place relative to the bar's centre. The first two are the bar itself, the rest its load.
	parts: { { part: BasePart, offset: CFrame } },
	-- The weight it is loaded with, what it weighs lying down, and where it is now (nil until first placed).
	kg: number,
	restRadius: number,
	frame: CFrame?,
	-- Where the stacks go, in the rack's floor space, while the bar lies on the floor for a deadlift.
	floorZ: number?,
}

--[[
	Ordinary (strong) tables, NOT weak ones. Roblox may drop an Instance key from
	a weak table while the Instance still exists (once no script holds its Lua
	handle). A forgotten base CFrame was then re-read from the already lowered
	J-cups, which dropped them a second time (GymRack_28 at -0.70 in the
	2026-10-19 stress test). Entries are removed when the rack is destroyed.
]]
-- Each moving part's modelled (squat-hole) CFrame, remembered the first time the rack is shown.
local baseCFrames: { [BasePart]: CFrame } = {}
-- The look each rack last got, so repeated sign refreshes change nothing.
local lastLook: { [Instance]: string } = {}
local barbells: { [Instance]: Barbell } = {}
-- The parts of a rack hidden for a meet's deadlift, and how each looked before.
local hiddenParts: { [BasePart]: { transparency: number, castShadow: boolean, canCollide: boolean } } = {}
local watchedRacks: { [Instance]: boolean } = {}
local warnedMissingTemplate = false

local function forgetWhenDestroyed(rack: Model)
	if watchedRacks[rack] then
		return
	end
	watchedRacks[rack] = true
	rack.Destroying:Connect(function()
		watchedRacks[rack] = nil
		lastLook[rack] = nil
		barbells[rack] = nil
		for part in pairs(baseCFrames) do
			if part:IsDescendantOf(rack) then
				baseCFrames[part] = nil
			end
		end
		for part in pairs(hiddenParts) do
			if part:IsDescendantOf(rack) then
				hiddenParts[part] = nil
			end
		end
	end)
end

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

-- A part of the bar, or of its load: a clone of `source`, placed if the bar already has a place.
local function addToBar(barbell: Barbell, source: BasePart, offset: CFrame, size: Vector3?)
	local part = source:Clone()
	decorate(part)
	if size then
		part.Size = size
	end
	part:SetAttribute(BAR_OFFSET_ATTRIBUTE, offset)
	if barbell.frame then
		part.CFrame = barbell.frame * offset
	end
	part.Parent = barbell.model
	table.insert(barbell.parts, { part = part, offset = offset })
end

-- Takes the old load off and puts on the one for `kg`. Does nothing if that is what is on it.
local function setLoad(barbell: Barbell, load: BarLoad.Load)
	if barbell.kg == load.kg then
		return
	end
	barbell.kg = load.kg
	barbell.restRadius = load.restRadius
	for index = #barbell.parts, 3, -1 do
		barbell.parts[index].part:Destroy()
		barbell.parts[index] = nil
	end
	local template = barbell.template
	for _, side in ipairs({ 1, -1 }) do
		local x = BarLoad.SleeveStart
		for _, plate in ipairs(load.plates) do
			local source = template:FindFirstChild(plate.part)
			if source and source:IsA("BasePart") then
				local width = plate.thickness * load.squeeze
				addToBar(barbell, source, CFrame.new(side * (x + width / 2), 0, 0),
					Vector3.new(width, plate.diameter, plate.diameter))
				x += width
			else
				warn("[StationVisuals] barbell template has no part " .. plate.part .. "; skipped")
			end
		end
		local collar = template:FindFirstChild("Collar_Lock")
		if load.collar and collar and collar:IsA("BasePart") then
			-- The collar's round part is on the bar's line; its lever makes the mesh's middle sit a little above that.
			local scale = BarLoad.CollarScale
			local lift = barbell.shaft.CFrame:ToObjectSpace(collar.CFrame).Y * scale
			addToBar(barbell, collar, CFrame.new(side * (x + collar.Size.X / 2), lift, 0),
				Vector3.new(collar.Size.X, collar.Size.Y * scale, collar.Size.Z * scale))
		end
	end
end

-- The load a rack shows until someone lifts on it. Always the same for the same rack.
local function idleKg(rack: Model): number
	local loads = TrainingStationConfig.BarbellIdleLoadsKg
	local hash = 0
	for _, byte in ipairs({ string.byte(rack:GetFullName(), 1, -1) }) do
		hash = (hash * 31 + byte) % 1000003
	end
	return loads[hash % #loads + 1]
end

--[[
	The flat stacks that bring a light bar up to deadlift height, on the floor under
	each end of it, or none when it isn't lying there or its plates reach the floor.
]]
local function placeBlocks(rack: Model, barbell: Barbell)
	local old = rack:FindFirstChild(BLOCKS_MODEL_NAME)
	if old then
		old:Destroy()
	end
	local height = BarLoad.FullPlateRadius - barbell.restRadius
	local source = barbell.template:FindFirstChild("Plate_25")
	local z = barbell.floorZ
	if z == nil or height < 0.01 or source == nil or not source:IsA("BasePart") then
		return
	end
	local model = Instance.new("Model")
	model.Name = BLOCKS_MODEL_NAME
	local count = math.ceil(height / BLOCK_PLATE_THICKNESS - 0.001)
	local thickness = height / count
	local floor = StationLayout.floorFrame(rack)
	for _, side in ipairs({ 1, -1 }) do
		for level = 1, count do
			local plate = source:Clone()
			decorate(plate)
			plate.Name = "BarBlock"
			plate.Color = BLOCK_COLOUR
			plate.CastShadow = false
			plate.Size = Vector3.new(thickness, BLOCK_DIAMETER, BLOCK_DIAMETER)
			-- Lying flat: the plate's own thickness (its X) straight up.
			plate.CFrame = floor * CFrame.new(side * BLOCK_ALONG_BAR, thickness * (level - 0.5), z) * CFrame.Angles(0, 0, math.pi / 2)
			plate.Parent = model
		end
	end
	model.Parent = rack
end

--[[
	Builds the rack's barbell from the template, with its idle load.
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
	model.Name = BARBELL_MODEL_NAME
	local barbell: Barbell = { model = model, template = template :: Instance, shaft = shaft, parts = {}, kg = 0,
		restRadius = BarLoad.FullPlateRadius, frame = nil, floorZ = nil }

	-- The bar, placed relative to the shaft's centre (the template's bar lies along its X).
	addToBar(barbell, shaft, CFrame.identity)
	addToBar(barbell, sleeves, shaft.CFrame:ToObjectSpace(sleeves.CFrame))
	setLoad(barbell, BarLoad.forKg(idleKg(rack)))

	model.Parent = rack
	return barbell
end

local function placeBarbell(barbell: Barbell, rack: Model, centre: Vector3)
	local frame = StationLayout.floorFrame(rack) * CFrame.new(centre)
	barbell.frame = frame
	for _, entry in ipairs(barbell.parts) do
		entry.part.CFrame = frame * entry.offset
	end
	-- Where the bar rests, for clients: StationPoseAnimator moves the bar with the
	-- lifter's hands locally and puts it back here when it is not in the hands.
	local model = barbell.parts[1].part.Parent
	if model then
		model:SetAttribute("RestCFrame", frame)
	end
end

--[[
	Hides every part of the rack but its barbell (invisible and not solid, so
	nobody walks into it), or puts them back as they were.
]]
local function setRackHidden(rack: Model, hidden: boolean)
	for _, part in ipairs(rack:GetDescendants()) do
		if part:IsA("BasePart") and part.Parent and part.Parent.Name ~= BARBELL_MODEL_NAME
			and part.Parent.Name ~= BLOCKS_MODEL_NAME then
			local before = hiddenParts[part]
			if hidden and before == nil then
				hiddenParts[part] = {
					transparency = part.Transparency,
					castShadow = part.CastShadow,
					canCollide = part.CanCollide,
				}
				part.Transparency = 1
				part.CastShadow = false
				part.CanCollide = false
			elseif not hidden and before ~= nil then
				hiddenParts[part] = nil
				part.Transparency = before.transparency
				part.CastShadow = before.castShadow
				part.CanCollide = before.canCollide
			end
		end
	end
end

--[[
	Shows `rack` for `lift` ("Squat", "Bench", "Deadlift", or nil for a free rack
	or one whose occupant has not picked a lift yet). Safe to call as often as
	the sign refreshes; it only changes parts when the look changes.

	`noRackForDeadlift`: a meet's platform (GAME_DESIGN §37.5, user 2026-11-03):
	for deadlift the whole rack goes, only the bar stays. A gym rack stays standing.
]]
function StationVisuals.show(rack: Instance, lift: string?, noRackForDeadlift: boolean?)
	local layout = StationLayout.of(rack)
	if layout == nil or not rack:IsA("Model") then
		return
	end

	local look = lift or "Free"
	if lastLook[rack] == look then
		return
	end
	lastLook[rack] = look
	forgetWhenDestroyed(rack)

	-- First, so that coming back from it the bench below still gets the look of the new lift.
	setRackHidden(rack, noRackForDeadlift == true and lift == "Deadlift")

	local benchVisible = lift ~= "Squat" and lift ~= "Deadlift"
	for _, name in ipairs(layout.benchParts) do
		local part = findPart(rack, name)
		if part then
			part.Transparency = if benchVisible then 0 else 1
			part.CastShadow = benchVisible
		end
	end

	-- The taller cartoon bodies set the J-cups higher (StationLayout tall*).
	local tall = LifterBodyService.enabled()
	local raise = if lift == "Squat" then (if tall then layout.tallSquatJCupRaise else 0)
		else (if tall then layout.tallBenchJCupDrop else layout.benchJCupDrop)
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
		local floorZ = if lift == "Deadlift" then (StationLayout.deadliftZ(rack, layout)) else nil
		local centre = if floorZ
			then Vector3.new(0, BarLoad.FullPlateRadius, floorZ)
			else layout.barRest + Vector3.new(0, raise, 0)
		barbell.floorZ = floorZ
		placeBarbell(barbell, rack, centre)
		placeBlocks(rack, barbell)
	end
end

--[[
	Loads `rack`'s bar for `kg` (BarLoad: the right plates and collars, to the
	nearest 2.5 kg). Safe to call as often as you like: it only changes parts when
	the load changes, and the bar stays wherever it is.
]]
function StationVisuals.loadBar(rack: Instance, kg: number)
	if StationLayout.of(rack) == nil or not rack:IsA("Model") then
		return
	end
	if barbells[rack] == nil then
		StationVisuals.show(rack, nil)
	end
	local barbell = barbells[rack]
	if barbell then
		local before = barbell.restRadius
		setLoad(barbell, BarLoad.forKg(kg))
		if barbell.restRadius ~= before then
			placeBlocks(rack, barbell)
		end
	end
end

return StationVisuals
