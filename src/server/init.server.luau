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

local TrainingFolder = script:WaitForChild("Training")
local TrainingStationService = require(TrainingFolder:WaitForChild("TrainingStationService"))
local RackSpawner = require(TrainingFolder:WaitForChild("RackSpawner"))

local WorldFolder = script:WaitForChild("World")
local StarterGymBuilder = require(WorldFolder:WaitForChild("StarterGymBuilder"))
local CardioMachineService = require(WorldFolder:WaitForChild("CardioMachineService"))

--[[
	The Starter Gym's floors and walls (Starter Gym step 3), around the rack rows.
	Visual and physical only; if it fails, everything else still starts.
]]
StarterGymBuilder.build()

-- The Cardio room's machines players can hop on (after the gym, which places them). Fun only: no stats.
CardioMachineService.start()

-- The treadmill rhythm game: rounds, notes and judging are the server's. Fun only: no stats, nothing saved yet.
local CardioRhythmService = require(WorldFolder:WaitForChild("CardioRhythmService"))
CardioRhythmService.start()

--[[
	Gym racks from TrainingStationConfig.GymRacks (6D.2a), built from the
	Git-tracked templates and tagged before TrainingStationService looks for racks.
]]
RackSpawner.spawnAll()

-- Of the game systems, player data comes first. Nothing that touches a player's stats can run safely
-- before the gateway is listening for joins.
PlayerDataService.start()

--[[
	The orchestrator owns every lift attempt and all the lifting remotes. The phase
	services are driven by it rather than started on their own, so phase order is a
	server property and a client cannot ask for a phase directly.
]]
LiftAttemptService.start()

--[[
	Gym training racks: the only source of Competition Number. Starts after
	player data, because every tick goes through the data gateway.
]]
TrainingStationService.start()
