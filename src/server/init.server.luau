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
local LiftAttemptService = require(LiftingFolder:WaitForChild("LiftAttemptService"))

-- Player data comes first. Nothing that touches a player's stats can run safely
-- before the gateway is listening for joins.
PlayerDataService.start()

--[[
	The orchestrator owns every lift attempt and all the lifting remotes. The phase
	services are driven by it rather than started on their own, so phase order is a
	server property and a client cannot ask for a phase directly.
]]
LiftAttemptService.start()
