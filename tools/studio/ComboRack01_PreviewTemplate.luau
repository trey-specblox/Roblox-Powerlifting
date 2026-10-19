--[[
	ComboRack01_PreviewTemplate  (TEMPORARY Command Bar script, 2026-10-18)

	Diagnostic for "the spawned racks look like blocky shrink-wrapped shapes".
	Run in Studio EDIT mode (not Play), in the game place.

	It creates exactly ONE new object and changes nothing else: a copy of the
	template ServerStorage.RackTemplates.ComboRack_01, named
	Workspace.ComboRack01_Preview, placed at (0, 0, 45) so it is easy to find,
	and marked with the attribute ComboRack01Preview = true. It refuses if
	that name already exists. The template itself is only read.

	It also prints, for 4 parts, what Studio knows about their meshes, so we can
	compare the template with what Rojo synced.

	Look at the preview up close (holes in the posts, U-shaped J-cups, small
	separate caps and pins?). Afterwards select Workspace.ComboRack01_Preview
	and press Delete. Do not save the place with it.
]]

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local PREVIEW_NAME = "ComboRack01_Preview"
local PREVIEW_SPOT = Vector3.new(0, 0, 45)

local function run(): (boolean, string)
	if RunService:IsRunning() then
		return false, "Studio is in Play/Run mode. Stop the test and run this in Edit mode."
	end
	if workspace:FindFirstChild(PREVIEW_NAME) then
		return false, "Workspace." .. PREVIEW_NAME .. " already exists; delete it first"
	end
	local folder = ServerStorage:FindFirstChild("RackTemplates")
	local template = folder and folder:FindFirstChild("ComboRack_01")
	if template == nil or not template:IsA("Model") then
		return false, "ServerStorage.RackTemplates.ComboRack_01 is missing (is Rojo connected?)"
	end

	for _, name in ipairs({ "Upright_Left", "JCup_Left", "SafetyPins", "FootCaps" }) do
		local part = template:FindFirstChild(name, true)
		if part and part:IsA("MeshPart") then
			print(string.format("[ComboRack_01 preview] template %s: MeshId=%s RenderFidelity=%s CollisionFidelity=%s Size=%s",
				name, part.MeshId, part.RenderFidelity.Name, part.CollisionFidelity.Name, tostring(part.Size)))
		else
			print("[ComboRack_01 preview] template " .. name .. ": MISSING or not a MeshPart")
		end
	end

	local recording = ChangeHistoryService:TryBeginRecording("ComboRack_01 preview copy")
	local preview = template:Clone() :: Model
	preview.Name = PREVIEW_NAME
	preview:SetAttribute("ComboRack01Preview", true)
	local _, size = preview:GetBoundingBox()
	preview:PivotTo(CFrame.new(PREVIEW_SPOT + Vector3.new(0, size.Y / 2, 0)))
	preview.Parent = workspace
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	return true, "Workspace." .. PREVIEW_NAME .. " created at " .. tostring(PREVIEW_SPOT)
		.. ". Look at it up close, then select it and press Delete (or Ctrl+Z)."
end

local ok, success, message = pcall(run)
if not ok then
	warn("[ComboRack_01 preview] SCRIPT ERROR: " .. tostring(success))
elseif success then
	print("[ComboRack_01 preview] SUCCESS: " .. message)
else
	warn("[ComboRack_01 preview] REFUSED, nothing was changed: " .. tostring(message))
end
