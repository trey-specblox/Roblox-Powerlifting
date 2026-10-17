--[[
	Step6D2a_VerifyRacks  (Step 6D.2a, updated for 6D.2b; TEMPORARY Command Bar script)

	READ-ONLY. Changes nothing. Run while PLAYING, from the SERVER view
	(Test tab -> "Current: Client" button switches it to "Current: Server"),
	after the game has started.

	Checks, for every entry in TrainingStationConfig.GymRacks:
	  - Workspace.GymRacks holds exactly one rack of that name and nothing else;
	  - it is tagged, its StationId matches, its PrimaryPart is StandPoint;
	  - it has the 21 MeshParts, all anchored, only the 4 Uprights solid;
	  - its floor centre and facing match the config; its size is 6.06 x 8 x 6.54;
	  - it has exactly one TrainingPrompt and one TrainingStatus sign, and the
	    sign shows the full rack number.
	And overall:
	  - every tagged rack has a unique StationId (lists them all);
	  - the registered racks are exactly the configured gym racks and both
	    placeholders (6D.2b: the hand-placed rack is no longer set up);
	  - if the hand-placed Workspace.PowerRack_01 is still in the place (before
	    its removal), it is inert: no tag, no StationId, no prompt, no sign;
	  - the template in ServerStorage is still untagged, ID-free and 21 MeshParts.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local EXPECTED_SIZE = Vector3.new(6.06, 8, 6.54)
local SIZE_TOLERANCE = 0.05
local POSITION_TOLERANCE = 0.01
local STAND_HALF_HEIGHT = 0.1
local UPRIGHTS = {
	Upright_FrontLeft = true,
	Upright_FrontRight = true,
	Upright_BackLeft = true,
	Upright_BackRight = true,
}

local lines = {}
local failures = 0

local function check(passed: boolean, label: string)
	if not passed then
		failures += 1
	end
	table.insert(lines, (if passed then "  PASS  " else "  FAIL  ") .. label)
end

local function fmtV(v: Vector3): string
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end

local function run()
	if not (RunService:IsRunning() and RunService:IsServer()) then
		warn("[6D.2b verify] Not run: press Play, then switch the Command Bar to the SERVER view (Test tab).")
		return
	end

	local config = require(ReplicatedStorage.Shared.Config.TrainingStationConfig)
	local tag = config.StationTag
	local gymRacks = config.GymRacks

	-- Spawned racks.
	local folder = workspace:FindFirstChild("GymRacks")
	check(folder ~= nil and folder:IsA("Folder"), "Workspace.GymRacks folder exists")
	if folder then
		check(#folder:GetChildren() == #gymRacks,
			string.format("Workspace.GymRacks holds %d racks (expected %d)", #folder:GetChildren(), #gymRacks))

		for _, entry in ipairs(gymRacks) do
			local id = entry.stationId
			local matches = {}
			for _, child in ipairs(folder:GetChildren()) do
				if child.Name == id then
					table.insert(matches, child)
				end
			end
			check(#matches == 1, string.format("%s: exactly 1 rack (found %d)", id, #matches))

			local rack = matches[1]
			if rack and rack:IsA("Model") then
				check(CollectionService:HasTag(rack, tag), id .. ": has the " .. tag .. " tag")
				check(rack:GetAttribute("StationId") == id,
					string.format("%s: StationId = %s", id, tostring(rack:GetAttribute("StationId"))))
				check(rack.PrimaryPart ~= nil and rack.PrimaryPart.Name == "StandPoint", id .. ": PrimaryPart is StandPoint")

				local meshParts, unanchored, wrongCollision = 0, 0, {}
				for _, d in ipairs(rack:GetDescendants()) do
					if d:IsA("BasePart") and not d.Anchored then
						unanchored += 1
					end
					if d:IsA("MeshPart") then
						meshParts += 1
						if d.CanCollide ~= (UPRIGHTS[d.Name] == true) then
							table.insert(wrongCollision, d.Name)
						end
					end
				end
				check(meshParts == 21, string.format("%s: 21 MeshParts (found %d)", id, meshParts))
				check(unanchored == 0, string.format("%s: every part anchored (%d unanchored)", id, unanchored))
				check(#wrongCollision == 0, string.format("%s: only the 4 Uprights are solid%s", id,
					if #wrongCollision > 0 then " (wrong: " .. table.concat(wrongCollision, ", ") .. ")" else ""))

				local pivot = rack:GetPivot()
				local floorCentre = pivot.Position - Vector3.new(0, STAND_HALF_HEIGHT, 0)
				check((floorCentre - entry.position).Magnitude <= POSITION_TOLERANCE,
					string.format("%s: floor centre %s (config %s)", id, fmtV(floorCentre), fmtV(entry.position)))

				local expectedLook = CFrame.Angles(0, math.rad(entry.facingDegrees), 0).LookVector
				check(pivot.LookVector:Dot(expectedLook) > 0.999 and pivot.UpVector.Y > 0.999,
					string.format("%s: upright and facing %g degrees", id, entry.facingDegrees))

				local size = rack:GetExtentsSize()
				local sizeOk = math.abs(size.X - EXPECTED_SIZE.X) <= SIZE_TOLERANCE
					and math.abs(size.Y - EXPECTED_SIZE.Y) <= SIZE_TOLERANCE
					and math.abs(size.Z - EXPECTED_SIZE.Z) <= SIZE_TOLERANCE
				check(sizeOk, string.format("%s: size %s (expected %s)", id, fmtV(size), fmtV(EXPECTED_SIZE)))

				local prompts, signs, signText = 0, 0, ""
				for _, d in ipairs(rack:GetDescendants()) do
					if d:IsA("ProximityPrompt") then
						prompts += 1
					elseif d:IsA("BillboardGui") and d.Name == "TrainingStatus" then
						signs += 1
						local label = d:FindFirstChildWhichIsA("TextLabel")
						signText = if label then label.Text else ""
					end
				end
				check(prompts == 1, string.format("%s: exactly 1 prompt (found %d)", id, prompts))
				check(signs == 1, string.format("%s: exactly 1 sign (found %d)", id, signs))
				local number = string.match(id, "%d+$") or ""
				check(string.find(signText, "Training Rack " .. number, 1, true) == 1,
					string.format("%s: sign starts with \"Training Rack %s\" (shows \"%s\")", id, number,
						(string.gsub(signText, "\n", " | "))))
			end

			local everywhere = 0
			for _, d in ipairs(workspace:GetDescendants()) do
				if d.Name == id then
					everywhere += 1
				end
			end
			check(everywhere == 1, string.format("%s: exactly 1 instance with this name in Workspace (found %d)", id, everywhere))
		end
	end

	-- Every registered rack.
	local ids, duplicates = {}, {}
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		local id = tostring(instance:GetAttribute("StationId"))
		if ids[id] then
			table.insert(duplicates, id)
		end
		ids[id] = instance:GetFullName()
	end
	check(#duplicates == 0, "all tagged racks have unique StationIds"
		.. (if #duplicates > 0 then " (duplicates: " .. table.concat(duplicates, ", ") .. ")" else ""))
	local expectedIds = {}
	for _, entry in ipairs(config.PlaceholderStations) do
		table.insert(expectedIds, entry.stationId)
	end
	for _, entry in ipairs(gymRacks) do
		table.insert(expectedIds, entry.stationId)
	end
	for _, id in ipairs(expectedIds) do
		check(ids[id] ~= nil, string.format("rack %s is tagged (%s)", id, ids[id] or "missing"))
	end
	local tagged = #CollectionService:GetTagged(tag)
	check(tagged == #expectedIds, string.format("%d tagged racks in total (expected %d)", tagged, #expectedIds))
	check(ids["PowerRack_01"] == nil, "the hand-placed rack's old StationId PowerRack_01 is not registered")

	-- 6D.2b: until it is removed from the place, the hand-placed rack must be inert decoration.
	local handPlaced = workspace:FindFirstChild("PowerRack_01")
	if handPlaced == nil then
		table.insert(lines, "  INFO  no hand-placed Workspace.PowerRack_01 in this place")
	else
		local runtimeOnly = 0
		for _, d in ipairs(handPlaced:GetDescendants()) do
			if d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d.Name == "StandPoint" then
				runtimeOnly += 1
			end
		end
		check(not CollectionService:HasTag(handPlaced, tag) and handPlaced:GetAttribute("StationId") == nil
			and runtimeOnly == 0,
			string.format("hand-placed Workspace.PowerRack_01 is inert (no tag, StationId, prompt, sign or StandPoint; found %d runtime parts)",
				runtimeOnly))
	end

	-- Template untouched.
	local templateFolder = ServerStorage:FindFirstChild("RackTemplates")
	local template = templateFolder and templateFolder:FindFirstChild("PowerRack_01")
	check(template ~= nil, "template ServerStorage.RackTemplates.PowerRack_01 exists")
	if template then
		check(not CollectionService:HasTag(template, tag) and template:GetAttribute("StationId") == nil,
			"template has no tag and no StationId")
		check(#template:GetDescendants() == 21,
			string.format("template still has exactly 21 parts (found %d descendants)", #template:GetDescendants()))
	end
end

local ok, err = pcall(run)
if not ok then
	warn("[6D.2b verify] SCRIPT ERROR: " .. tostring(err))
elseif #lines > 0 then
	local header = if failures == 0
		then "[6D.2b verify] ALL CHECKS PASSED"
		else string.format("[6D.2b verify] %d CHECK(S) FAILED", failures)
	local report = header .. "\n" .. table.concat(lines, "\n")
	if failures == 0 then
		print(report)
	else
		warn(report)
	end
end
