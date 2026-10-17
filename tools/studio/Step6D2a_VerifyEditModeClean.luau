--[[
	Step6D2a_VerifyEditModeClean  (Step 6D.2a, updated for 6D.2b; TEMPORARY Command Bar script)

	READ-ONLY. Changes nothing. Run in Studio EDIT mode (after stopping Play)
	to prove a Play session left nothing behind in the saved place:
	  - no Workspace.GymRacks folder and no GymRack_* instance anywhere;
	  - no instance carries the GymTrainingStation tag in Edit mode;
	  - 6D.2b: the hand-placed Workspace.PowerRack_01 is GONE (run this only
	    after Step6D2b_RemoveHandPlacedRack);
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

	local handPlaced = 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name == "PowerRack_01" then
			handPlaced += 1
		end
	end
	check(handPlaced == 0, string.format("no hand-placed PowerRack_01 left in Workspace (found %d)", handPlaced))

	local folder = ServerStorage:FindFirstChild("RackTemplates")
	local template = folder and folder:FindFirstChild("PowerRack_01")
	local templateCount = if folder then #folder:GetChildren() else 0
	check(template ~= nil and template:IsA("Model") and templateCount == 1 and #template:GetDescendants() == 21,
		string.format("exactly 1 template ServerStorage.RackTemplates.PowerRack_01 with 21 parts (folder holds %d)", templateCount))
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
