--!strict
--[[
	GymRecordsConfig
	Shared / Config

	Settings for the GYM RECORD wall's saved records (GAME_DESIGN.md §31.6,
	"The gym record wall — first build", user 2026-10-30). GymRecords keeps
	one set of records for the whole game; a record set on any server shows
	on every server.
]]

local GymRecordsConfig = {}

-- The four records each weight class has. Total = one lifter's three official-meet bests added up.
GymRecordsConfig.Records = { "Squat", "Bench", "Deadlift", "Total" }

-- CHANGING THESE NAMES STARTS THE WALL FROM EMPTY (the old records stay in the old store).
GymRecordsConfig.Store = "GymRecords"
GymRecordsConfig.Key = "AllClasses" -- one key holds every class (records are rare, so one key is plenty)

-- In Studio with API access on, the store uses this name in front, so test runs never reach the live wall.
GymRecordsConfig.StudioPrefix = "Studio_"

GymRecordsConfig.RefreshSeconds = 60 -- read the records again (picks up records set on other servers)
GymRecordsConfig.SaveRetries = 3

-- The chalk wall's GYM RECORDS table (RoomProps FRONT.RecordsWall) carries this tag; GymRecordsWall fills it in.
GymRecordsConfig.WallTag = "GymRecordsTable"

return GymRecordsConfig
