--!strict
--[[
	LightingSetup
	Server / World

	Applies LightingConfig to the Lighting service when the server starts
	(the clients get it by replication). Creates the Bloom and Atmosphere
	effects if the place does not have them, so the look does not depend on
	the place file. Changes nothing else in Lighting.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LightingConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("LightingConfig"))

local LightingSetup = {}

local function effect(className: string): Instance
	local found = Lighting:FindFirstChildOfClass(className)
	if found then
		return found
	end
	local made = Instance.new(className)
	made.Parent = Lighting
	return made
end

local function apply(target: Instance, values: { [string]: any })
	for property, value in pairs(values) do
		(target :: any)[property] = value
	end
end

function LightingSetup.apply()
	apply(Lighting, LightingConfig.Lighting)
	apply(effect("BloomEffect"), LightingConfig.Bloom)
	apply(effect("Atmosphere"), LightingConfig.Atmosphere)
end

return LightingSetup
