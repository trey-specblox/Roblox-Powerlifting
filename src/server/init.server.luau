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

-- The treadmill rhythm game: rounds, notes and judging are the server's. Fun only: no stats, no rewards.
local CardioRhythmService = require(WorldFolder:WaitForChild("CardioRhythmService"))
CardioRhythmService.start()

-- Its saved all-time and weekly boards of best single runs (their own ordered stores, not player data).
local CardioRhythmLeaderboard = require(WorldFolder:WaitForChild("CardioRhythmLeaderboard"))
CardioRhythmLeaderboard.start()

-- The Mock Meet: the check-in desk moves a player into their own private meet room and back.
-- Part 1: no lifting yet, nothing saved.
local MeetFolder = script:WaitForChild("Meet")
local MockMeetService = require(MeetFolder:WaitForChild("MockMeetService"))
MockMeetService.start()

-- The Local meet against other players: the venue, the sign-up timetable and the meet itself.
-- Step 1: nothing saved yet.
-- The gym record wall's saved records (GAME_DESIGN §31.6), before the meet that sets them.
local GymRecords = require(MeetFolder:WaitForChild("GymRecords"))
GymRecords.start()

-- The hall's chalk GYM RECORDS table shows them (built above by StarterGymBuilder).
local GymRecordsWall = require(WorldFolder:WaitForChild("GymRecordsWall"))
GymRecordsWall.start()

local LocalMeetService = require(MeetFolder:WaitForChild("LocalMeetService"))
LocalMeetService.start()

-- The TELEPORT menu: the client asks for a place, the server checks and moves the player.
local TeleportService = require(WorldFolder:WaitForChild("TeleportService"))
TeleportService.start()

--[[
	Gym racks from TrainingStationConfig.GymRacks (6D.2a), built from the
	Git-tracked templates and tagged before TrainingStationService looks for racks.
]]
RackSpawner.spawnAll()

-- Of the game systems, player data comes first. Nothing that touches a player's stats can run safely
-- before the gateway is listening for joins.
PlayerDataService.start()

-- The stats screen's read-only answer: a player's own stats, never written.
local PlayerStatsService = require(PlayerDataFolder:WaitForChild("PlayerStatsService"))
PlayerStatsService.start()

-- Each player's coins on their screen (the counter and the "+150 COINS" pop-ups). Display only.
local CoinDisplayService = require(PlayerDataFolder:WaitForChild("CoinDisplayService"))
CoinDisplayService.start()

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
