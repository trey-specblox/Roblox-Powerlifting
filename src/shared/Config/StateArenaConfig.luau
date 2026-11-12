--!strict
--[[
	StateArenaConfig
	Shared / Config

	The State Championship arena (GAME_DESIGN.md §36, user 2026-11-01): its own
	big domed venue, built from the user's reference photos (§36.1), with 4
	racks at most, a screen above each, and seats all round, and the State meet
	held in it (§36.4). Anyone may walk in and watch.

	All numbers [PROVISIONAL].
]]

local StateArenaConfig = {}

-- ------------------------------------------------ getting there and back

-- The invisible point in front of the entrance building's doors that carries the "Go to the State arena" prompt.
StateArenaConfig.EntranceTag = "StateArenaEntrance"
StateArenaConfig.PromptHoldSeconds = 0.5
StateArenaConfig.PromptDistanceStuds = 8

-- Where the arena is built: far from the gym (about 2000 studs across round 0,0,0), the Local meet venue
-- (-X 4000) and the Mock Meet rooms (+X 4000), high up, so nobody walks in by accident.
StateArenaConfig.Origin = Vector3.new(0, 1000, 4000)

-- ------------------------------------------------ the arena

--[[
	The meet area (user 2026-11-01: spectators "cannot go any further" than its
	barricades; "only people who were actually competing in the meet should be
	able to go all around the meet"): hidden walls along the barricade lines and
	along the floor's wall behind the warm-up area, too high to jump over, in the
	collision group MeetBarrierGroup. A competing lifter's character is put in
	CompetitorGroup, which passes through them (StateArenaVenue.setCompetitor).
	The rest of the floor is open: spectators may hop the low wall from the stands.
]]
StateArenaConfig.MeetBarrierGroup = "StateMeetBarrier"
StateArenaConfig.CompetitorGroup = "StateMeetCompetitor"
StateArenaConfig.MeetBarrierHeightStuds = 60

-- The racks in a row across the floor (x), facing the main stand (-Z), and how far apart they are (a little over a banner's width and
-- a gap to walk through: user 2026-11-06, "separate the banners"). As many as a meet needs, up to this.
StateArenaConfig.MaxRacks = 4
StateArenaConfig.RackSpacingStuds = 34
-- One rack for every this many lifters signed up (user 2026-11-06).
StateArenaConfig.LiftersPerRack = 10

-- ------------------------------------------------ the State meet (§36.4)

-- The next meet is this long after the last one finished (user 2026-11-06), and when its sign-ups close before the start.
StateArenaConfig.CycleSeconds = 20 * 60
StateArenaConfig.SignUpClosesSeconds = 60
-- It needs this many qualified lifters; fewer, no meet and the list carries over. Never computer lifters (§37).
StateArenaConfig.MinimumLifters = 2
-- In Studio, to test alone, without waiting. A lifter in Studio need not be qualified, unless the workspace attribute
-- StudioStateNeedsQualifying is on.
StateArenaConfig.StudioCycleSeconds = 120
StateArenaConfig.StudioSignUpClosesSeconds = 15
StateArenaConfig.StudioMinimumLifters = 1
-- The caller (user 2026-11-07): how a screen finds them, and what they say out loud (client MeetCallerVoice, Roblox's text to speech).
StateArenaConfig.CallerTag = "StateMeetCaller"
StateArenaConfig.CallerLineAttribute = "CallerLine"
StateArenaConfig.CallerVoiceId = "1"
StateArenaConfig.CallerVoiceSpeed = 1
StateArenaConfig.CallerVoiceVolume = 1
-- (A good lift's celebration on the platform: CelebrationConfig, each as long as its own animation.)
-- A lifter further than this from their rack when their turn comes is put back at once rather than walked.
StateArenaConfig.BringBackWalkStuds = 60

return StateArenaConfig
