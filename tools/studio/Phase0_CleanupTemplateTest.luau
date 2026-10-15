--[[
	Phase0_CleanupTemplateTest  (Step 6D.2 Phase 0, TEMPORARY Command Bar script)

	NOT game code. Run ONLY after the user approves cleanup, in Studio EDIT mode.

	Removes exactly one instance: the Workspace.TemplateTest Model made by
	Phase0_SpawnTemplateTest. Before touching anything it checks that the model:
	  - is the ONLY instance named TemplateTest anywhere in Workspace,
	  - is a direct child of Workspace and a Model,
	  - carries the marker attribute TemporaryTestModel = "Step6D2_Phase0",
	  - holds exactly 21 MeshParts and nothing else,
	  - has no tags and no StationId.
	If any check fails it changes nothing. It never touches Workspace.PowerRack_01,
	the template in ServerStorage, or the placeholder racks. Undo with Ctrl+Z.
]]

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local function run(): (boolean, string)
	if RunService:IsRunning() then
		return false, "Studio is in Play/Run mode. Stop the test and run this in Edit mode."
	end

	local found = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name == "TemplateTest" then
			table.insert(found, d)
		end
	end
	if #found ~= 1 then
		return false, string.format("expected exactly 1 TemplateTest in Workspace, found %d", #found)
	end
	local model = found[1]
	if model.Parent ~= workspace or not model:IsA("Model") then
		return false, model:GetFullName() .. " is not a Model directly in Workspace"
	end
	if model:GetAttribute("TemporaryTestModel") ~= "Step6D2_Phase0" then
		return false, "TemplateTest has no Step6D2_Phase0 marker, so it was not made by the test script"
	end
	if #CollectionService:GetTags(model) > 0 or model:GetAttribute("StationId") ~= nil then
		return false, "TemplateTest has tags or a StationId"
	end
	local descendants = model:GetDescendants()
	if #descendants ~= 21 then
		return false, string.format("TemplateTest has %d descendants, expected 21", #descendants)
	end
	for _, d in ipairs(descendants) do
		if not d:IsA("MeshPart") then
			return false, string.format("unexpected %s '%s' inside TemplateTest", d.ClassName, d.Name)
		end
	end

	local recording = ChangeHistoryService:TryBeginRecording("Remove TemplateTest")
	-- Parent = nil instead of Destroy() so Ctrl+Z can bring it back.
	model.Parent = nil
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	return true, "Workspace.TemplateTest removed. Nothing else was changed."
end

local ok, success, message = pcall(run)
if not ok then
	warn("[TemplateTest cleanup] SCRIPT ERROR: " .. tostring(success))
elseif success then
	print("[TemplateTest cleanup] SUCCESS. " .. message)
else
	warn("[TemplateTest cleanup] REFUSED, nothing was changed: " .. message)
end
