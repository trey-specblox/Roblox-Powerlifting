--!strict
--[[
	RackSpawner
	Server / Training

	Checkpoint 6D.2a. At server start, builds every rack listed in
	TrainingStationConfig.GymRacks from its Git-tracked template in
	ServerStorage.RackTemplates, so racks are placed by configuration instead
	of by hand.

	For each entry, in this order:
	  1. check the entry (ID format, unique ID, template name, position, facing);
	  2. check the template: exactly one Model of that name, exactly the
	     expected MeshParts and nothing else, no station tag, no StationId;
	  3. clone it (the template itself is never changed);
	  4. configure the clone with RackConfigurator while it is still unparented,
	     so it is anchored before it ever enters Workspace;
	  5. move and turn it to its configured spot, and check it landed there;
	  6. set its StationId and RackTemplate attributes, parent it into
	     Workspace.GymRacks;
	  7. add the station tag LAST. From that moment TrainingStationService
	     registers it like any other rack: same prompt, menu, rules, progression.

	FAILS CLOSED PER RACK: a bad entry or template is skipped with a warning and
	any half-built clone is destroyed. Other racks and every other system
	carry on.

	Runtime only: the racks exist only while the server runs, so nothing is
	saved into the place and a fresh Play session builds the same racks again.
	Call spawnAll() once, BEFORE TrainingStationService.start(); later calls do
	nothing.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local TrainingStationConfig = require(ConfigFolder:WaitForChild("TrainingStationConfig"))

local RackConfigurator = require(script.Parent.RackConfigurator)

local RackSpawner = {}

local TEMPLATE_FOLDER_NAME = "RackTemplates"
local RACKS_FOLDER_NAME = "GymRacks"
local STATION_ID_PATTERN = "^GymRack_%d%d+$"
-- How far a placed rack's StandPoint may sit from its configured spot.
local PLACEMENT_TOLERANCE = 0.01

local spawned = false

local function log(message: string, ...: any)
	print(string.format("[RackSpawner] " .. message, ...))
end

local function skip(stationId: string, reason: string)
	warn(string.format("[RackSpawner] %s was NOT spawned: %s", stationId, reason))
end

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

--[[
	StationIds that are already taken: anything tagged already.
]]
local function reservedStationIds(): { [string]: string }
	local reserved: { [string]: string } = {}
	for _, instance in ipairs(CollectionService:GetTagged(TrainingStationConfig.StationTag)) do
		local id = instance:GetAttribute("StationId")
		if typeof(id) == "string" then
			reserved[id] = instance:GetFullName()
		end
	end
	return reserved
end

-- Checks one config entry. Returns the reason it is unusable, or nil.
local function entryProblem(entry: any, reserved: { [string]: string }, seen: { [string]: boolean }): string?
	if typeof(entry) ~= "table" then
		return "the entry is not a table"
	end
	local id = entry.stationId
	if typeof(id) ~= "string" or not string.match(id, STATION_ID_PATTERN) then
		return string.format("stationId %s must look like GymRack_01", tostring(id))
	end
	if seen[id] then
		return "the stationId is listed more than once in GymRacks"
	end
	if reserved[id] then
		return "the stationId is already used by " .. reserved[id]
	end
	if typeof(entry.template) ~= "string" or entry.template == "" then
		return "template must be a template name"
	end
	local position = entry.position
	if typeof(position) ~= "Vector3" or not (isFinite(position.X) and isFinite(position.Y) and isFinite(position.Z)) then
		return "position must be a finite Vector3"
	end
	if typeof(entry.facingDegrees) ~= "number" or not isFinite(entry.facingDegrees) then
		return "facingDegrees must be a finite number"
	end
	return nil
end

-- Checks one template. Returns the template, or nil and the reason.
local function findTemplate(templateName: string): (Model?, string?)
	local folder = ServerStorage:FindFirstChild(TEMPLATE_FOLDER_NAME)
	if folder == nil then
		return nil, "ServerStorage." .. TEMPLATE_FOLDER_NAME .. " is missing (is the place synced by Rojo?)"
	end

	local matches: { Instance } = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child.Name == templateName then
			table.insert(matches, child)
		end
	end
	if #matches ~= 1 then
		return nil, string.format("expected exactly 1 template %s, found %d", templateName, #matches)
	end

	local template = matches[1]
	if not template:IsA("Model") then
		return nil, string.format("template %s is a %s, not a Model", templateName, template.ClassName)
	end

	--[[
		A tagged or IDed template would register as a rack itself (tags work
		even in ServerStorage), and its clones would inherit the tag before
		they were placed. Refuse rather than repair: the template is never edited.
	]]
	if CollectionService:HasTag(template, TrainingStationConfig.StationTag) then
		return nil, string.format("template %s has the %s tag", templateName, TrainingStationConfig.StationTag)
	end
	if template:GetAttribute("StationId") ~= nil then
		return nil, string.format("template %s has a StationId attribute", templateName)
	end

	local expectedCount = RackConfigurator.expectedPartCount(templateName)
	if expectedCount == nil then
		return nil, string.format("template %s has no rack profile in RackConfigurator", templateName)
	end
	local descendants = template:GetDescendants()
	if #descendants ~= expectedCount then
		return nil, string.format("template %s has %d descendants, expected exactly %d MeshParts",
			templateName, #descendants, expectedCount)
	end
	for _, descendant in ipairs(descendants) do
		if not descendant:IsA("MeshPart") then
			return nil, string.format("template %s contains a %s (%s)", templateName, descendant.ClassName, descendant.Name)
		end
		if CollectionService:HasTag(descendant, TrainingStationConfig.StationTag) then
			return nil, string.format("template %s part %s has the station tag", templateName, descendant.Name)
		end
	end

	return template :: Model, nil
end

-- The runtime folder the racks live in. Returns nil if something else has the name.
local function racksFolder(): Folder?
	local existing = Workspace:FindFirstChild(RACKS_FOLDER_NAME)
	if existing ~= nil then
		if existing:IsA("Folder") then
			return existing
		end
		warn(string.format("[RackSpawner] Workspace.%s is a %s, not a Folder; no gym racks spawned",
			RACKS_FOLDER_NAME, existing.ClassName))
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = RACKS_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

--[[
	Builds one rack. Returns the rack, or nil and the reason. Anything it built
	is destroyed on failure; the template is only ever read.
]]
local function spawnRack(entry: TrainingStationConfig.GymRackEntry, folder: Folder): (Model?, string?)
	if folder:FindFirstChild(entry.stationId) ~= nil then
		return nil, string.format("Workspace.%s.%s already exists", RACKS_FOLDER_NAME, entry.stationId)
	end

	local template, templateProblem = findTemplate(entry.template)
	if template == nil then
		return nil, templateProblem
	end

	-- Clone() returns nil when the template's Archivable is off, despite its type.
	local clone = template:Clone() :: Model?
	if clone == nil then
		return nil, string.format("template %s could not be cloned (Archivable is off)", entry.template)
	end
	clone.Name = entry.stationId

	local configured, configureProblem = RackConfigurator.configure(clone, entry.template)
	if not configured then
		clone:Destroy()
		return nil, configureProblem
	end

	-- The pivot is StandPoint's centre, half its height above the floor.
	local standHeight = RackConfigurator.StandPointSize.Y / 2
	local target = CFrame.new(entry.position + Vector3.new(0, standHeight, 0))
		* CFrame.Angles(0, math.rad(entry.facingDegrees), 0)
	clone:PivotTo(target)

	local landedOff = (clone:GetPivot().Position - target.Position).Magnitude
	if landedOff > PLACEMENT_TOLERANCE then
		clone:Destroy()
		return nil, string.format("it landed %.3f studs from its configured position", landedOff)
	end

	clone:SetAttribute("StationId", entry.stationId)
	-- Which template it came from, for StationVisuals (what moves or hides per lift).
	clone:SetAttribute("RackTemplate", entry.template)
	clone.Parent = folder

	-- LAST: from here on TrainingStationService can register it.
	CollectionService:AddTag(clone, TrainingStationConfig.StationTag)

	return clone, nil
end

--[[
	Spawns every rack in TrainingStationConfig.GymRacks. Returns the racks it
	built. Call once, from the server entry point, BEFORE
	TrainingStationService.start(); later calls do nothing.
]]
function RackSpawner.spawnAll(): { Model }
	local built: { Model } = {}
	if spawned then
		warn("[RackSpawner] spawnAll() was called again; ignored so no rack is built twice")
		return built
	end
	spawned = true

	local entries = TrainingStationConfig.GymRacks
	if #entries == 0 then
		log("no gym racks configured")
		return built
	end

	local folder = racksFolder()
	if folder == nil then
		return built
	end

	local reserved = reservedStationIds()
	local seen: { [string]: boolean } = {}

	for index, entry in ipairs(entries) do
		local label = if typeof(entry) == "table" and typeof((entry :: any).stationId) == "string"
			then (entry :: any).stationId
			else string.format("GymRacks entry %d", index)

		local problem = entryProblem(entry, reserved, seen)
		if problem ~= nil then
			skip(label, problem)
			continue
		end
		seen[entry.stationId] = true

		-- A script error inside one rack must not stop the others or the server start.
		local ok, rack, reason = pcall(spawnRack, entry, folder)
		if not ok then
			skip(label, "script error: " .. tostring(rack))
			-- Remove anything this attempt left behind, but only our own untagged clone.
			local leftover = folder:FindFirstChild(entry.stationId)
			if leftover ~= nil and not CollectionService:HasTag(leftover, TrainingStationConfig.StationTag) then
				leftover:Destroy()
			end
		elseif rack == nil then
			skip(label, reason or "unknown reason")
		else
			table.insert(built, rack)
			local position = entry.position
			log("spawned %s from template %s at (%.2f, %.2f, %.2f), facing %g degrees",
				entry.stationId, entry.template, position.X, position.Y, position.Z, entry.facingDegrees)
		end
	end

	log("%d of %d gym racks spawned", #built, #entries)
	return built
end

return RackSpawner
