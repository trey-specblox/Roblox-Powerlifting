--[[
	Step6D2b_RemoveHandPlacedRack  (Step 6D.2b, TEMPORARY Command Bar script)

	NOT game code. DESTRUCTIVE: run ONLY after the user approves the removal,
	in Studio EDIT mode, in the real game place.

	Removes exactly one instance: the hand-placed Workspace.PowerRack_01 Model,
	which GymRack_02 (spawned from the Git-tracked template at the same spot)
	replaces. Before touching anything it checks that:
	  - Studio is in Edit mode, not Play;
	  - this is the real game place (PlaceId 96814269062063), not a blank
	    Baseplate or a backup copy;
	  - exactly ONE instance named PowerRack_01 exists anywhere in Workspace,
	    and it is a Model directly in Workspace;
	  - it holds exactly the 21 expected MeshParts and nothing else, with no
	    tag, no StationId and no StandPoint (so it is not a configured rack);
	  - the template ServerStorage.RackTemplates.PowerRack_01 exists, is a
	    different instance, and every part of the hand-placed rack sits exactly
	    where the template's part of the same name sits (proving it is the rack
	    GymRack_02 replaces).
	If any check fails it changes nothing. It never touches the template,
	GymRacks, placeholders or anything else.

	The removal is undoable with Ctrl+Z (Parent = nil, recorded in the undo
	history). It does NOT save the place: the user saves only after checking.
]]

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local GAME_PLACE_ID = 96814269062063
local RACK_NAME = "PowerRack_01"
local EXPECTED_PARTS = {
	"Upright_FrontLeft", "Upright_FrontRight", "Upright_BackLeft", "Upright_BackRight",
	"Crossbar_Front", "Crossbar_Back", "Crossbar_Left", "Crossbar_Right",
	"BaseRail_Left", "BaseRail_Right", "BaseRail_Back",
	"JCup_Left", "JCup_Right", "JCupLiner_Left", "JCupLiner_Right", "JCupPin_Left", "JCupPin_Right",
	"SafetyBar_Left", "SafetyBar_Right", "SafetyPins", "FrameBolts",
}
local POSITION_TOLERANCE = 0.01
local ROTATION_TOLERANCE = 0.999

-- Name -> MeshPart for a model holding exactly the 21 expected MeshParts and nothing else.
local function partsByName(model: Instance, label: string): ({ [string]: MeshPart }?, string?)
	local descendants = model:GetDescendants()
	if #descendants ~= #EXPECTED_PARTS then
		return nil, string.format("%s has %d descendants, expected exactly %d MeshParts", label, #descendants, #EXPECTED_PARTS)
	end
	local found: { [string]: MeshPart } = {}
	for _, d in ipairs(descendants) do
		if not d:IsA("MeshPart") then
			return nil, string.format("%s contains a %s (%s)", label, d.ClassName, d.Name)
		end
		if found[d.Name] then
			return nil, string.format("%s has two parts named %s", label, d.Name)
		end
		found[d.Name] = d
	end
	for _, name in ipairs(EXPECTED_PARTS) do
		if not found[name] then
			return nil, string.format("%s is missing %s", label, name)
		end
	end
	return found, nil
end

local function run(): (boolean, string)
	if RunService:IsRunning() then
		return false, "Studio is in Play/Run mode. Stop the test and run this in Edit mode."
	end
	if game.PlaceId ~= GAME_PLACE_ID then
		return false, string.format("this is place %d, not the game place %d. Open the real game first.",
			game.PlaceId, GAME_PLACE_ID)
	end

	local found = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name == RACK_NAME then
			table.insert(found, d)
		end
	end
	if #found ~= 1 then
		return false, string.format("expected exactly 1 %s in Workspace, found %d", RACK_NAME, #found)
	end
	local rack = found[1]
	if rack.Parent ~= workspace or not rack:IsA("Model") then
		return false, rack:GetFullName() .. " is not a Model directly in Workspace"
	end
	if #CollectionService:GetTags(rack) > 0 or rack:GetAttribute("StationId") ~= nil then
		return false, "the hand-placed rack has tags or a StationId (was it saved while configured?)"
	end
	local rackParts, rackProblem = partsByName(rack, "Workspace." .. RACK_NAME)
	if rackParts == nil then
		return false, rackProblem or "its parts could not be read"
	end

	local folder = ServerStorage:FindFirstChild("RackTemplates")
	local template = folder and folder:FindFirstChild(RACK_NAME)
	if template == nil or not template:IsA("Model") or template == rack then
		return false, "the template ServerStorage.RackTemplates." .. RACK_NAME .. " is missing; refusing to remove the only copy"
	end
	local templateParts, templateProblem = partsByName(template, "the template")
	if templateParts == nil then
		return false, templateProblem or "the template's parts could not be read"
	end

	for _, name in ipairs(EXPECTED_PARTS) do
		local a, b = rackParts[name].CFrame, templateParts[name].CFrame
		if (a.Position - b.Position).Magnitude > POSITION_TOLERANCE
			or a.LookVector:Dot(b.LookVector) < ROTATION_TOLERANCE
			or a.UpVector:Dot(b.UpVector) < ROTATION_TOLERANCE then
			return false, string.format("%s is not where the template's %s is, so this is not the rack GymRack_02 replaces",
				name, name)
		end
	end

	local recording = ChangeHistoryService:TryBeginRecording("Remove hand-placed PowerRack_01 (6D.2b)")
	-- Parent = nil instead of Destroy() so Ctrl+Z can bring it back.
	rack.Parent = nil
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	return true, "Workspace.PowerRack_01 removed. Nothing else was changed. Ctrl+Z undoes it. "
		.. "The place is NOT saved: run Step6D2a_VerifyEditModeClean, check the scene, then File -> Save to Roblox."
end

local ok, success, message = pcall(run)
if not ok then
	warn("[6D.2b rack removal] SCRIPT ERROR: " .. tostring(success)
		.. ". Check Workspace for PowerRack_01 (Ctrl+Z if it is gone) and do NOT save.")
elseif success then
	print("[6D.2b rack removal] SUCCESS. " .. message)
else
	warn("[6D.2b rack removal] REFUSED, nothing was changed: " .. tostring(message))
end
