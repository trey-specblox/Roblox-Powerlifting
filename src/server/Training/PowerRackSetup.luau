--!strict
--[[
	PowerRackSetup
	Server / Training

	TEMPORARY BRIDGE for checkpoint 6D.1. Turns the hand-imported
	Workspace.PowerRack_01 Model into a gym training rack when the server
	starts, so TrainingStationService registers it through the tag exactly like
	any other rack. No rule, rate or progression code knows this rack exists.

	It only CONFIGURES a model that is already in the saved place. It never
	creates, copies or moves the rack. If Workspace.PowerRack_01 is missing from
	the place, it does nothing and the placeholder racks still work. The rack
	itself is therefore NOT reproducible from Git yet: a Git-tracked template
	and spawner are checkpoint 6D.2, which replaces this file.

	Everything here runs on the server at startup, so the changes exist only for
	that server session. Studio edit mode and the saved place are never changed,
	and every Play session applies the same setup again.

	FAILS CLOSED: if any check fails, the rack is left UNTAGGED, so the training
	service never sees a half-configured rack.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local TrainingStationConfig = require(ConfigFolder:WaitForChild("TrainingStationConfig"))

local PowerRackSetup = {}

local RACK_NAME = "PowerRack_01"
local STATION_ID = "PowerRack_01"

--[[
	Invisible floor marker at the centre of the rack. As the Model's PrimaryPart
	it is the rack's pivot, so it is where TrainingStationService measures
	presence from and where it hangs the prompt (+3 studs) and the sign.
]]
local STAND_POINT_NAME = "StandPoint"
local STAND_POINT_SIZE = Vector3.new(2, 0.2, 2)

-- The four posts: the only rack parts a player collides with.
local UPRIGHTS = {
	"Upright_FrontLeft",
	"Upright_FrontRight",
	"Upright_BackLeft",
	"Upright_BackRight",
}

-- Every other part of PowerRack_01 (art/scripts/build_power_rack_01.py). Players pass through these.
local NON_COLLIDING_PARTS = {
	"Crossbar_Front",
	"Crossbar_Back",
	"Crossbar_Left",
	"Crossbar_Right",
	"BaseRail_Left",
	"BaseRail_Right",
	"BaseRail_Back",
	"JCup_Left",
	"JCup_Right",
	"JCupLiner_Left",
	"JCupLiner_Right",
	"JCupPin_Left",
	"JCupPin_Right",
	"SafetyBar_Left",
	"SafetyBar_Right",
	"SafetyPins",
	"FrameBolts",
}

-- How far the posts may lean from one another before the rack is treated as broken.
local MIN_POST_ALIGNMENT = 0.999

local configured = false

local function refuse(reason: string)
	warn(string.format("[PowerRackSetup] %s was NOT set up as a training rack: %s", RACK_NAME, reason))
end

--------------------------------------------------------------------------------
-- DIAGNOSTICS (read-only)
--------------------------------------------------------------------------------

--[[
	One line of facts about an instance named like the rack, so copies can be
	told apart in Output. Reads only; changes nothing.
]]
local function describe(instance: Instance): string
	local parent = instance.Parent
	local where = string.format("%s (%s), parent %s", instance:GetFullName(), instance.ClassName,
		if parent then parent:GetFullName() else "nil")

	if not instance:IsA("Model") then
		return where
	end

	local model = instance :: Model
	local baseParts, meshParts, anchored = 0, 0, 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			baseParts += 1
			if (descendant :: BasePart).Anchored then
				anchored += 1
			end
			if descendant:IsA("MeshPart") then
				meshParts += 1
			end
		end
	end

	local primary = model.PrimaryPart
	local pivotRead, pivot = pcall(function()
		return model:GetPivot().Position
	end)
	local sizeRead, size = pcall(function()
		return model:GetExtentsSize()
	end)
	local stationId = model:GetAttribute("StationId")

	return string.format(
		"%s: %d MeshParts, %d of %d parts anchored, PrimaryPart %s, pivot %s, size %s, StationId %s, tagged %s",
		where,
		meshParts,
		anchored,
		baseParts,
		if primary then primary.Name else "none",
		if pivotRead then string.format("(%.2f, %.2f, %.2f)", pivot.X, pivot.Y, pivot.Z) else "unreadable",
		if sizeRead then string.format("(%.2f, %.2f, %.2f)", size.X, size.Y, size.Z) else "unreadable",
		if stationId == nil then "none" else tostring(stationId),
		tostring(CollectionService:HasTag(model, TrainingStationConfig.StationTag))
	)
end

--[[
	Prints every instance named like the rack in the places a rack could be:
	the direct Workspace children being chosen between, and any other copy deeper
	in Workspace or in ServerStorage / ReplicatedStorage (never used, listed only
	so nothing is hidden). Runs before any other game system has started, so
	whatever it lists came from the saved place, not from this project's code.
]]
local function reportCandidates(matches: { Instance })
	warn(string.format("[PowerRackSetup] found %d direct Workspace children named %s; refusing to guess which is the rack:",
		#matches, RACK_NAME))
	for index, instance in ipairs(matches) do
		warn(string.format("[PowerRackSetup]   candidate %d: %s", index, describe(instance)))
	end

	for _, root in ipairs({ Workspace, ServerStorage, ReplicatedStorage } :: { Instance }) do
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant.Name == RACK_NAME and descendant.Parent ~= Workspace then
				warn("[PowerRackSetup]   also found (not used): " .. describe(descendant))
			end
		end
	end
end

--------------------------------------------------------------------------------
-- SETUP
--------------------------------------------------------------------------------

--[[
	The one direct child of Workspace with the rack's name, if it is a Model.
	Only Workspace's own children are searched, so templates in ServerStorage
	and models anywhere else are never touched.
]]
local function findRack(): Model?
	local matches: { Instance } = {}
	for _, child in ipairs(Workspace:GetChildren()) do
		if child.Name == RACK_NAME then
			table.insert(matches, child)
		end
	end

	if #matches == 0 then
		print(string.format("[PowerRackSetup] no Workspace.%s in this place; skipped", RACK_NAME))
		return nil
	end

	if #matches > 1 then
		reportCandidates(matches)
		refuse(string.format("Workspace has %d children named %s", #matches, RACK_NAME))
		return nil
	end

	local rack = matches[1]
	if not rack:IsA("Model") then
		refuse("it is a " .. rack.ClassName .. ", not a Model")
		return nil
	end

	return rack
end

--[[
	Finds every expected rack part inside the Model, by name. Refuses a missing
	part, a doubled name, or a name on something that is not a MeshPart.
]]
local function collectParts(rack: Model): ({ [string]: MeshPart }?, string?)
	local expected: { [string]: boolean } = {}
	for _, name in ipairs(UPRIGHTS) do
		expected[name] = true
	end
	for _, name in ipairs(NON_COLLIDING_PARTS) do
		expected[name] = true
	end

	local found: { [string]: MeshPart } = {}
	for _, descendant in ipairs(rack:GetDescendants()) do
		local name = descendant.Name
		if expected[name] then
			if not descendant:IsA("MeshPart") then
				return nil, string.format("%s is a %s, expected a MeshPart", name, descendant.ClassName)
			end
			if found[name] then
				return nil, "more than one part named " .. name
			end
			found[name] = descendant
		end
	end

	for name in pairs(expected) do
		if not found[name] then
			return nil, "missing MeshPart " .. name
		end
	end

	return found, nil
end

--[[
	Where StandPoint goes, from the posts as they are placed now: the average of
	the four post centres is the frame's centre, and half a post's height down
	its own long axis is the floor. Oriented like the posts, so "up" for the
	prompt is up the rack even if the rack was rotated.
]]
local function standPointCFrame(posts: { MeshPart }): (CFrame?, string?)
	local reference = posts[1]
	local up = reference.CFrame.UpVector
	local centreSum = Vector3.zero

	for _, post in ipairs(posts) do
		local size = post.Size
		if size.Y < size.X or size.Y < size.Z then
			return nil, string.format("%s is not tallest along its own Y axis (Size %s)", post.Name, tostring(size))
		end
		if post.CFrame.UpVector:Dot(up) < MIN_POST_ALIGNMENT then
			return nil, post.Name .. " does not point the same way as " .. reference.Name
		end
		centreSum += post.Position
	end

	local frameCentre = centreSum / #posts
	local floor = frameCentre - up * (reference.Size.Y / 2)
	local position = floor + up * (STAND_POINT_SIZE.Y / 2)

	return CFrame.fromMatrix(position, reference.CFrame.RightVector, up), nil
end

--[[
	Reuses the Model's own StandPoint if it has exactly one, or makes a new one.
	A new one is not parented yet: the caller positions it first.
]]
local function standPointFor(rack: Model): (Part?, string?)
	local existing: { Instance } = {}
	for _, child in ipairs(rack:GetChildren()) do
		if child.Name == STAND_POINT_NAME then
			table.insert(existing, child)
		end
	end

	if #existing > 1 then
		return nil, "more than one " .. STAND_POINT_NAME
	end

	local found: Instance? = existing[1]
	if found then
		if not found:IsA("Part") then
			return nil, string.format("%s is a %s, expected a Part", STAND_POINT_NAME, found.ClassName)
		end
		return found, nil
	end

	local part = Instance.new("Part")
	part.Name = STAND_POINT_NAME
	return part, nil
end

--[[
	Configures Workspace.PowerRack_01 and tags it LAST. Returns the rack, or nil
	if there is none or it was refused. Call once, from the server entry point,
	BEFORE TrainingStationService.start(); later calls do nothing.
]]
function PowerRackSetup.configure(): Model?
	if configured then
		return nil
	end
	configured = true

	local rack = findRack()
	if rack == nil then
		return nil
	end

	--[[
		A tag added by hand in Studio is taken off until the rack is fully set
		up. Nothing is listening yet (the service starts after this), so this
		only guarantees a refused rack never registers.
	]]
	local tag = TrainingStationConfig.StationTag
	CollectionService:RemoveTag(rack, tag)

	local parts, partsProblem = collectParts(rack)
	if parts == nil then
		refuse(partsProblem or "its parts could not be read")
		return nil
	end

	local posts: { MeshPart } = {}
	for _, name in ipairs(UPRIGHTS) do
		table.insert(posts, parts[name])
	end

	local standCFrame, standProblem = standPointCFrame(posts)
	if standCFrame == nil then
		refuse(standProblem or "the stand point could not be placed")
		return nil
	end

	local standPoint, standPointProblem = standPointFor(rack)
	if standPoint == nil then
		refuse(standPointProblem or "StandPoint could not be made")
		return nil
	end

	-- Anchoring and collision. Position, size, materials and colours are not touched.
	for _, post in ipairs(posts) do
		post.Anchored = true
		post.CanTouch = false
		post.CanCollide = true
	end
	for _, name in ipairs(NON_COLLIDING_PARTS) do
		local part = parts[name]
		part.Anchored = true
		part.CanTouch = false
		part.CanCollide = false
	end

	standPoint.Size = STAND_POINT_SIZE
	standPoint.Transparency = 1
	standPoint.Anchored = true
	standPoint.CanCollide = false
	standPoint.CanTouch = false
	standPoint.CanQuery = false
	standPoint.CastShadow = false
	standPoint.CFrame = standCFrame
	-- A non-zero offset would move the Model's pivot, and presence with it, away from StandPoint.
	standPoint.PivotOffset = CFrame.identity
	standPoint.Parent = rack

	rack.PrimaryPart = standPoint

	local pivotError = (rack:GetPivot().Position - standPoint.Position).Magnitude
	if pivotError > 0.001 then
		refuse(string.format("its pivot is %.3f studs away from StandPoint", pivotError))
		return nil
	end

	local up = standCFrame.UpVector
	if up.Y < 0.99 then
		warn(string.format("[PowerRackSetup] %s is not standing straight up (up = %s); the prompt will tilt with it",
			RACK_NAME, tostring(up)))
	end

	rack:SetAttribute("StationId", STATION_ID)

	-- LAST: from here on TrainingStationService can register it.
	CollectionService:AddTag(rack, tag)

	local position = standPoint.Position
	print(string.format("[PowerRackSetup] %s ready as StationId %s; StandPoint at (%.2f, %.2f, %.2f)",
		RACK_NAME, STATION_ID, position.X, position.Y, position.Z))

	return rack
end

return PowerRackSetup
