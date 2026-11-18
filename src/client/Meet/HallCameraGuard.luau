--!strict
--[[
	HallCameraGuard
	Client / Meet

	In the Nationals hall the camera stays on the player's side of the platforms' backdrops and inside the building (user
	2026-11-18: after a lift "your camera is seen going behind the screen, so if your not zoomed in to the perfect angle,
	you wont see yourself. Make it where you cant see behind building by just simply zooming out").

	Roblox's own camera only stops at solid, visible parts, and the hall's walls and backdrops are hidden solid blocks
	behind decor meshes, so it went straight through them. The hidden blocks that should stop it carry
	NationalsConfig.CameraBlockTag (NationalsArenaVenue: each backdrop with its curtains, the hall's walls and roof; never
	the barricades' hidden walls). Every frame, after Roblox's camera has moved, if one lies between what the camera looks
	at and the camera, the camera is pulled in to just this side of it (same direction, nearer). The meet's own scripted
	shots use `clear` for the same.

	Display only. PERFORMANCE: one ray a frame, only while the player is inside the hall with the normal camera.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local NationalsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("NationalsConfig"))

local HallCameraGuard = {}

local RENDER_NAME = "HallCameraGuard"
-- How far in front of a blocking wall the camera stops.
local MARGIN = 0.6

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.RespectCanCollide = false
local blockers: { Instance } = {}

local function refresh()
	blockers = CollectionService:GetTagged(NationalsConfig.CameraBlockTag)
	params.FilterDescendantsInstances = blockers
end

-- Whether `part` stops the camera in the hall.
function HallCameraGuard.blocks(part: Instance): boolean
	return CollectionService:HasTag(part, NationalsConfig.CameraBlockTag)
end

-- As far along from `from` toward `to` as the camera may go without passing one of the hall's camera walls.
function HallCameraGuard.clear(from: Vector3, to: Vector3): Vector3
	if #blockers == 0 then
		return to
	end
	local offset = to - from
	if offset.Magnitude < 0.05 then
		return to
	end
	local hit = Workspace:Raycast(from, offset, params)
	if hit == nil then
		return to
	end
	return hit.Position - offset.Unit * MARGIN
end

local function step()
	local player = Players.LocalPlayer
	if player:GetAttribute(NationalsConfig.InHallAttribute) == nil then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local at = camera.CFrame
	local cleared = HallCameraGuard.clear(camera.Focus.Position, at.Position)
	if cleared ~= at.Position then
		camera.CFrame = CFrame.new(cleared) * at.Rotation
	end
end

function HallCameraGuard.start()
	refresh()
	CollectionService:GetInstanceAddedSignal(NationalsConfig.CameraBlockTag):Connect(refresh)
	CollectionService:GetInstanceRemovedSignal(NationalsConfig.CameraBlockTag):Connect(refresh)
	-- Right after Roblox's camera has moved for the frame.
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 2, step)
end

return HallCameraGuard
