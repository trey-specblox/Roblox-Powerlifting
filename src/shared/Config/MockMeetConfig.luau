--!strict
--[[
	MockMeetConfig
	Shared / Config

	The Mock Meet (GAME_DESIGN.md §29.10 "The Solo meet — first build", user
	2026-10-27): a player checks in at the desk in the gym's Mock Meet Room and
	is moved into their OWN private meet room, so there is never a crowd or a
	line. Each private room is built for one player far away from the gym, and
	cleared away when they leave.

	Part 1 (this file's first version): the rooms and the move in and out. The
	meet itself (weigh-in, attempts, lifts) is Part 2. Nothing is saved.
]]

local MockMeetConfig = {}

-- The invisible part in front of the check-in desk that carries the prompt (RoomProps tags it).
MockMeetConfig.CheckInTag = "MockMeetCheckIn"
MockMeetConfig.PromptHoldSeconds = 0.5
MockMeetConfig.PromptDistanceStuds = 8

-- The player attribute the server sets while a player is in their private room
-- (the room's slot number); the client shows the Leave button from it.
MockMeetConfig.SlotAttribute = "MockMeetSlot"

--[[
	Where the private rooms are built: slot 1's centre at Origin, the next ones
	Spacing apart along +X. Far outside the gym (whose whole map is about 2000
	studs across around 0,0,0) and high up, so nobody in the gym can see or
	reach them. One slot per player at most, so MaxSlots matches the server's
	player limit.
]]
MockMeetConfig.Origin = Vector3.new(4000, 1000, 0)
MockMeetConfig.SpacingStuds = 200
MockMeetConfig.MaxSlots = 60

-- The private room's inside, in studs: across (X), deep (Z) and high.
MockMeetConfig.RoomSize = Vector3.new(64, 26, 72)

-- How long a player must wait between two Leave presses (stops button spam).
MockMeetConfig.LeaveCooldownSeconds = 1

--[[
	Part 2: the meet itself (§29.10). 3 attempts per lift, squat -> bench ->
	deadlift (MeetConfig); attempts chosen one at a time; the server checks
	every choice (AttemptRules, the percentage bounds of LiftAttemptConfig).
	Nothing is saved.
]]

-- [PROVISIONAL] Time between two Mock Meets, counted from check-in, so quitting after a bad
-- opener still uses it (user, 2026-10-27: "one every 30 minutes"). Kept by the server only for
-- now (a new server does not know it); saving it is part of the rewards step.
MockMeetConfig.CooldownSeconds = 30 * 60
-- In Studio, so a test does not wait half an hour.
MockMeetConfig.StudioCooldownSeconds = 15

-- How long the weigh-in shows before the first attempt is chosen.
MockMeetConfig.WeighInSeconds = 4
-- Time to choose the next attempt. When it runs out: the opener is the suggestion, after a
-- miss the same weight again, after a good lift the smallest legal increase.
MockMeetConfig.ChooseSeconds = 60
-- Once the bar is loaded the lifter has this long to press LIFT, like a real meet's one-minute
-- clock; when it runs out the attempt is a no lift.
MockMeetConfig.ReadySeconds = 60
-- How long the verdict (and the coach's reaction) shows before the next choice. The lift's own verdict
-- shows first (LiftAttemptConfig.ResultHoldSeconds, 2.5 s), then the meet's, so the two never overlap.
MockMeetConfig.ResultSeconds = 5

-- The opener suggestion: this share of the Competition Number, rounded down to WeightStepKg.
MockMeetConfig.OpenerSuggestionPercent = 0.90
-- The size of the + and - buttons; also what every declared weight must be a multiple of.
MockMeetConfig.WeightStepKg = 2.5

return MockMeetConfig
