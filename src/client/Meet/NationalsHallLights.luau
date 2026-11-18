--!strict
--[[
	NationalsHallLights
	Client / Meet

	The Nationals hall is a dark room (GAME_DESIGN §39 step 3, user 2026-11-17: "i want nationals to be a dark room, with
	lights on the platform, lifters having the spotlight"), on this player's screen only and only while they are inside
	the hall: the room's light drops to a dim cool blue (dark, never black, so phones still show the seats), and the
	platforms' own spotlights (NationalsArenaVenue) light the lifters. Back to normal on leaving.

	The hall model (tagged NationalsConfig.HallTag) carries its middle and half size as attributes. Drawing only.
	PERFORMANCE: a position check five times a second; the light only changes while easing between the two looks.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NationalsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("NationalsConfig"))

local NationalsHallLights = {}

local CHECK_SECONDS = 0.2
-- Share of the way per second (about 1.5 s to settle).
local EASE_RATE = 3

-- The dark look: tinted, not black (the fwjelaa lighting notes: near-black ambient vanishes on phones).
local DARK = {
	Ambient = Color3.fromRGB(22, 24, 40),
	OutdoorAmbient = Color3.fromRGB(20, 22, 36),
	Brightness = 0.2,
	ExposureCompensation = -0.2,
	-- The sky's light reaches indoors too (Future lighting): almost none in the dark room.
	EnvironmentDiffuseScale = 0.08,
	EnvironmentSpecularScale = 0.05,
}

local dark = 0 -- 0 normal .. 1 dark, eased
local wantDark = false
local saved: { [string]: any }? = nil

local function insideHall(): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	for _, hall in ipairs(CollectionService:GetTagged(NationalsConfig.HallTag)) do
		local middle, half = hall:GetAttribute("HallMiddle"), hall:GetAttribute("HallHalfSize")
		if typeof(middle) == "Vector3" and typeof(half) == "Vector3" then
			local offset = root.Position - middle
			if math.abs(offset.X) < half.X and math.abs(offset.Z) < half.Z and offset.Y > -10 and offset.Y < half.Y then
				return true
			end
		end
	end
	return false
end

local function apply(dt: number)
	if not wantDark and dark <= 0 then
		return
	end
	local target = if wantDark then 1 else 0
	dark += (target - dark) * math.min(1, EASE_RATE * dt)
	if math.abs(target - dark) < 0.01 then
		dark = target
	end
	local normal: { [string]: any } = saved or {}
	if saved == nil then
		for key in pairs(DARK) do
			normal[key] = (Lighting :: any)[key]
		end
		saved = normal
	end
	for key, value: any in pairs(DARK) do
		local from: any = normal[key]
		if typeof(value) == "Color3" then
			(Lighting :: any)[key] = (from :: Color3):Lerp(value, dark)
		else
			(Lighting :: any)[key] = from + (value - from) * dark
		end
	end
	if dark == 0 then
		-- Fully back: exactly as before, and forget it (the next visit reads it afresh).
		for key, value in pairs(normal) do
			(Lighting :: any)[key] = value
		end
		saved = nil
	end
end

function NationalsHallLights.start()
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			wantDark = insideHall()
		end
	end)
	RunService.RenderStepped:Connect(apply)
end

return NationalsHallLights
