--!strict
--[[
	Server entry point
	ServerScriptService.Server

	Starts server systems in order. Keep this file thin: it wires systems up and
	nothing else, so the startup sequence stays readable as the game grows.
]]

local PlayerDataFolder = script:WaitForChild("PlayerData")
local PlayerDataService = require(PlayerDataFolder:WaitForChild("PlayerDataService"))

local LiftingFolder = script:WaitForChild("Lifting")
local SquatDepthService = require(LiftingFolder:WaitForChild("SquatDepthService"))
local SquatControlService = require(LiftingFolder:WaitForChild("SquatControlService"))

-- Player data comes first. Nothing that touches a player's stats can run safely
-- before the gateway is listening for joins.
PlayerDataService.start()

-- Lifting reads forecasted maxes and technique stats, so it starts after.
-- The two phases are independent for now and are not yet chained into one squat.
SquatDepthService.start()
SquatControlService.start()
