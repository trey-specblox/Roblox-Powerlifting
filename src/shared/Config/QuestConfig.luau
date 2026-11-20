--!strict
--[[
	QuestConfig
	Shared / Config

	The coaches' daily quests (GAME_DESIGN §40.6, user 2026-11-19, picked from Claude's options):

		- three coaches, one quest each: the Squat, Bench and Deadlift coach each ask for GoodLiftsNeeded good lifts of
		  their lift in meets today (meets against others; computer lifters count, the Mock Meet doesn't)
		- the reward is strength directly: RewardTrainingDays full training days for that lift (the training formula,
		  so it shrinks near the world-record level like everything else)
		- each day is fresh (DayKey, the same UTC day as the training cap): unfinished quests disappear at the reset

	The coaches stand in the upstairs Coach room at points RoomProps tags with CoachSpotTag (attribute "Lift").
	Shared so the coach dialogue on the client says the same numbers the server uses.
]]

local QuestConfig = {}

-- Good lifts of the coach's lift to make in today's meets (Claude's default; they add up over the day's meets).
QuestConfig.GoodLiftsNeeded = 2

-- Full training days of strength per finished quest (user's pick: one).
QuestConfig.RewardTrainingDays = 1

-- One paid reset a day (user 2026-11-19); not sold yet, the price is still being decided.
QuestConfig.PaidResetsPerDay = 1

-- RoomProps tags a point in the Coach room for each coach; its "Lift" attribute says whose.
QuestConfig.CoachSpotTag = "QuestCoachSpot"

export type Coach = {
	name: string,
	title: string,
	-- The figure's shirt and trousers, so the three coaches don't look the same.
	shirt: Color3,
	trousers: Color3,
}

-- The bench and deadlift coaches' names are placeholders until the user names them.
QuestConfig.Coaches = {
	Squat = { name = "Coach Olivera", title = "SQUAT COACH", shirt = Color3.fromRGB(250, 206, 36), trousers = Color3.fromRGB(20, 22, 30) },
	Bench = { name = "Bench Coach", title = "BENCH COACH", shirt = Color3.fromRGB(226, 46, 56), trousers = Color3.fromRGB(20, 22, 30) },
	Deadlift = { name = "Deadlift Coach", title = "DEADLIFT COACH", shirt = Color3.fromRGB(70, 146, 255), trousers = Color3.fromRGB(20, 22, 30) },
} :: { [string]: Coach }

-- What a lift is called in a coach's line ("squats", "bench presses", "deadlifts").
QuestConfig.Plural = { Squat = "squats", Bench = "bench presses", Deadlift = "deadlifts" } :: { [string]: string }

assert(QuestConfig.GoodLiftsNeeded >= 1 and QuestConfig.GoodLiftsNeeded == math.floor(QuestConfig.GoodLiftsNeeded),
	"[QuestConfig] GoodLiftsNeeded must be a whole number of at least 1")
assert(QuestConfig.RewardTrainingDays > 0, "[QuestConfig] RewardTrainingDays must be above zero")

return QuestConfig
