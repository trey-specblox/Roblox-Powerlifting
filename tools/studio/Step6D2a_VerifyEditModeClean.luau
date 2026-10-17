--[[
	Step6D2a_VerifyEditModeClean  (Step 6D.2a, TEMPORARY Command Bar script)

	READ-ONLY. Changes nothing. Run in Studio EDIT mode (after stopping Play)
	to prove a Play session left nothing behind in the saved place:
	  - no Workspace.GymRacks folder and no GymRack_* instance anywhere;
	  - no instance carries the GymTrainingStation tag in Edit mode;
	  - the hand-placed Workspace.PowerRack_01 is still exactly one Model with
	    21 MeshParts and none of the runtime-only setup (no StandPoint, no
	    StationId, no prompt or sign);
	  - the template in ServerStorage is unchanged (21 MeshParts, no tag/ID).
	Racks are built fresh by each Play session; this shows none were saved.
]]

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local TAG = "GymTrainingStation"
local lines = {}
local failures = 0

local function check(passed: boolean, label: string)
	if not passed then
		failures += 1
	end
	table.insert(lines, (if passed then "  PASS  " else "  FAIL  ") .. label)
end

local function run()
	if RunService:IsRunning() then
		warn("[6D.2a edit check] Not run: stop Play first. This check is for Edit mode.")
		return
	end

	check(workspace:FindFirstChild("GymRacks") == nil, "no Workspace.GymRacks folder")

	local gymRackNames = 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if string.match(d.Name, "^GymRack_") then
			gymRackNames += 1
		end
	end
	check(gymRackNames == 0, string.format("no GymRack_* instance in Workspace (found %d)", gymRackNames))

	local tagged = #CollectionService:GetTagged(TAG)
	check(tagged == 0, string.format("nothing tagged %s in Edit mode (found %d)", TAG, tagged))

	local racks = {}
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == "PowerRack_01" then
			table.insert(racks, child)
		end
	end
	check(#racks == 1 and racks[1]:IsA("Model"), string.format("exactly 1 Workspace.PowerRack_01 Model (found %d)", #racks))
	if #racks == 1 then
		local rack = racks[1]
		local meshParts, runtimeOnly = 0, {}
		for _, d in ipairs(rack:GetDescendants()) do
			if d:IsA("MeshPart") then
				meshParts += 1
			elseif d.Name == "StandPoint" or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
				table.insert(runtimeOnly, d.ClassName .. " " .. d.Name)
			end
		end
		check(meshParts == 21, string.format("Workspace.PowerRack_01 has 21 MeshParts (found %d)", meshParts))
		check(#runtimeOnly == 0 and rack:GetAttribute("StationId") == nil,
			"Workspace.PowerRack_01 has no saved runtime setup (StandPoint, StationId, prompt, sign)"
				.. (if #runtimeOnly > 0 then " -- found: " .. table.concat(runtimeOnly, ", ") else ""))
	end

	local folder = ServerStorage:FindFirstChild("RackTemplates")
	local template = folder and folder:FindFirstChild("PowerRack_01")
	check(template ~= nil and #template:GetDescendants() == 21,
		"template ServerStorage.RackTemplates.PowerRack_01 still has exactly 21 parts")
	if template then
		check(not CollectionService:HasTag(template, TAG) and template:GetAttribute("StationId") == nil,
			"template has no tag and no StationId")
	end
end

local ok, err = pcall(run)
if not ok then
	warn("[6D.2a edit check] SCRIPT ERROR: " .. tostring(err))
elseif #lines > 0 then
	local header = if failures == 0
		then "[6D.2a edit check] ALL CHECKS PASSED"
		else string.format("[6D.2a edit check] %d CHECK(S) FAILED", failures)
	local text = header .. "\n" .. table.concat(lines, "\n")
	if failures == 0 then
		print(text)
	else
		warn(text)
	end
end
