--!strict
--[[
	CoachingConfig
	Shared / Config

	Getting coached (GAME_DESIGN §40.5, the user's design 2026-11-19 to 2026-11-23). The numbers both the server and the
	coach dialogue use:

		- every new player has the GYM OWNER as their basic coach, free
		- the three lift coaches (Squatavious, Benchamin, Sumo: QuestConfig.Coaches) cost Price coins, paid when you ask
		- then TRIAL 1, in your Mock Meet room: Trial1.Lifts good lifts IN A ROW of the coach's lift at
		  Trial1.PercentOfCn of your Competition Number; one miss fails it, and a fail means paying again
		- then TRIAL 2, in a real meet (free retries): 3/3 of the coach's lift, the third at Trial2.ThirdAtLeast of your
		  Competition Number or more, AND a top-Trial2.TopPlacesWithPlayers lift in that meet when other real players lift
		  in it, or the best one of the meet when only computer lifters do
		- then they're your coach, and you can make them your active coach (one at a time)

	The approved trials were written for the squat coach; the bench and deadlift coaches use the same rules on their own
	lift (Claude's reading, 2026-11-24).
]]

local CoachingConfig = {}

-- What hiring a lift coach costs (user 2026-11-23: "Yea that works let's do 28000").
CoachingConfig.Price = 28000

-- The basic coach every player starts with (user 2026-11-23: "set all new players with a basic coach like the gym owner").
CoachingConfig.OwnerId = "Owner"
CoachingConfig.Owner = { name = "The Gym Owner", title = "GYM OWNER" }

-- The lift coaches, in the order the dialogue and admin panel list them (QuestConfig.Coaches has their names).
CoachingConfig.Lifts = { "Squat", "Bench", "Deadlift" }

CoachingConfig.Trial1 = {
	Lifts = 10, -- good lifts in a row
	PercentOfCn = 1.0, -- of the Competition Number
}

CoachingConfig.Trial2 = {
	ThirdAtLeast = 1.05, -- the third attempt, of the Competition Number
	TopPlacesWithPlayers = 3, -- with other real players in the meet; with computer lifters only it must be the best
}

--[[
	Where each lift coach stands with a player (saved as text):
		"none"     not paid
		"trial1"   paid; trial 1 (the Mock Meet room) still to pass
		"trial2"   trial 1 passed; trial 2 (a real meet) still to pass
		"hired"    their coach: can be made the active coach
]]
CoachingConfig.Stages = { "none", "trial1", "trial2", "hired" }

function CoachingConfig.isStage(value: any): boolean
	return typeof(value) == "string" and table.find(CoachingConfig.Stages, value) ~= nil
end

function CoachingConfig.isLift(value: any): boolean
	return typeof(value) == "string" and table.find(CoachingConfig.Lifts, value) ~= nil
end

assert(CoachingConfig.Price >= 0 and CoachingConfig.Price == math.floor(CoachingConfig.Price),
	"[CoachingConfig] Price must be a whole number of coins")
assert(CoachingConfig.Trial1.Lifts >= 1, "[CoachingConfig] Trial1.Lifts must be at least 1")

return CoachingConfig
