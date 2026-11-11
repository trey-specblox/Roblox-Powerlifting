--!strict
--[[
	StateArenaLights
	Client / Meet

	The dark arena at a State meet (GAME_DESIGN §36.4, user 2026-11-10: "Whole meet, lit racks"), on this player's
	screen only and only while they are inside the State arena: the light dims, the bowl's lights go low, and every
	rack with a lifter on it is spotlit bright while the others stay dim, like the Sheffield stage. Back to normal
	when the meet ends or the player leaves the arena.

	The server only marks it (StateArenaShow): the arena model's MeetLit attribute, each rack lamp's Active attribute.
	Drawing only. PERFORMANCE: a check five times a second; light changes only while easing between the two looks.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local StateArenaLights = {}

local ARENA_NAME = "StateArenaVenue"
local RACK_TAG, BOWL_TAG = "StateRackLight", "StateBowlLight"
local CHECK_SECONDS = 0.2
-- How fast the lights ease to their new look (share of the way per second, about 1.5 s to settle).
local EASE_RATE = 3

-- The dark look.
local DARK = {
	Ambient = Color3.new(0.07, 0.07, 0.1),
	OutdoorAmbient = Color3.new(0.08, 0.08, 0.11),
	Brightness = 0.3,
	ExposureCompensation = -0.35,
}
-- The bowl's lights at this share of their own brightness; a rack's spotlight, lit and idle.
local BOWL_SHARE = 0.2
local RACK_LIT = { Brightness = 10, Angle = 42 }
local RACK_IDLE = { Brightness = 1, Angle = 50 }

type Saved = { [string]: any }

local dark = 0 -- 0 normal .. 1 dark, eased
local wantDark = false
local normalLighting: Saved? = nil
local normalLight: { [Light]: Saved } = {}

local function lightOf(lamp: Instance): Light?
	return lamp:FindFirstChildWhichIsA("Light")
end

local function remember(light: Light): Saved
	local saved = normalLight[light]
	if saved == nil then
		saved = { Brightness = light.Brightness, Angle = if light:IsA("SpotLight") then light.Angle else nil }
		normalLight[light] = saved
		light.Destroying:Once(function()
			normalLight[light] = nil
		end)
	end
	return saved
end

local function insideArena(): boolean
	local arena = Workspace:FindFirstChild(ARENA_NAME)
	if arena == nil or arena:GetAttribute("MeetLit") ~= true then
		return false
	end
	local centre, radius, top = arena:GetAttribute("ArenaCentre"), arena:GetAttribute("ArenaRadius"), arena:GetAttribute("ArenaTop")
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if typeof(centre) ~= "Vector3" or typeof(radius) ~= "number" or typeof(top) ~= "number" or root == nil
		or not root:IsA("BasePart") then
		return false
	end
	local offset = root.Position - centre
	return Vector3.new(offset.X, 0, offset.Z).Magnitude < radius and offset.Y > -10 and offset.Y < top
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
	-- The arena's own light.
	local saved = normalLighting
	if saved == nil then
		saved = {}
		for key in pairs(DARK) do
			saved[key] = (Lighting :: any)[key]
		end
		normalLighting = saved
	end
	for key, value in pairs(DARK) do
		local from = saved[key]
		if typeof(value) == "Color3" then
			(Lighting :: any)[key] = (from :: Color3):Lerp(value, dark)
		else
			(Lighting :: any)[key] = from + (value - from) * dark
		end
	end
	for _, lamp in ipairs(CollectionService:GetTagged(BOWL_TAG)) do
		local light = lightOf(lamp)
		if light then
			local normal = remember(light)
			light.Brightness = normal.Brightness * (1 - (1 - BOWL_SHARE) * dark)
		end
	end
	-- Each rack: toward lit or idle, by how dark the arena is (normal when it isn't).
	for _, lamp in ipairs(CollectionService:GetTagged(RACK_TAG)) do
		local light = lightOf(lamp)
		if light and light:IsA("SpotLight") then
			local normal = remember(light)
			local look = if lamp:GetAttribute("Active") == true then RACK_LIT else RACK_IDLE
			local brightness = normal.Brightness + (look.Brightness - normal.Brightness) * dark
			local angle = (normal.Angle or light.Angle) + (look.Angle - (normal.Angle or light.Angle)) * dark
			light.Brightness += (brightness - light.Brightness) * math.min(1, EASE_RATE * dt)
			light.Angle += (angle - light.Angle) * math.min(1, EASE_RATE * dt)
		end
	end
	if dark == 0 then
		-- Fully back: exactly as before, and forget it (the next meet reads it afresh).
		for key, value in pairs(saved) do
			(Lighting :: any)[key] = value
		end
		normalLighting = nil
		for light, normal in pairs(normalLight) do
			if light.Parent then
				light.Brightness = normal.Brightness
				if normal.Angle and light:IsA("SpotLight") then
					light.Angle = normal.Angle
				end
			end
		end
		table.clear(normalLight)
	end
end

-- Whether a State meet is on and this player is inside the arena (MeetChant plays the crowd's chant only then).
StateArenaLights.insideArena = insideArena

function StateArenaLights.start()
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			wantDark = insideArena()
		end
	end)
	RunService.RenderStepped:Connect(apply)
end

return StateArenaLights
