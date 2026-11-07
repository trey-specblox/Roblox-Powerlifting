--!strict
--[[
	StateArenaConfig
	Shared / Config

	The State Championship arena (GAME_DESIGN.md §36, user 2026-11-01): its own
	big domed venue, built from the user's reference photos (§36.1), with 4
	racks, a screen above each, and seats all round, and the State meet held in
	it (§36.4: every 20 minutes with 2+ qualified lifters, one lifter at a time,
	max 4). Anyone may walk in and watch.

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
	CompetitorGroup, which passes through them (StateArenaService.setCompetitor).
	The rest of the floor is open: spectators may hop the low wall from the stands.
]]
StateArenaConfig.MeetBarrierGroup = "StateMeetBarrier"
StateArenaConfig.CompetitorGroup = "StateMeetCompetitor"
StateArenaConfig.MeetBarrierHeightStuds = 60

-- The 4 racks in a row across the floor (x), facing the main stand (-Z), and how far apart they are.
StateArenaConfig.Racks = 4
StateArenaConfig.RackSpacingStuds = 30

-- ------------------------------------------------ the State meet (§36.4)

-- A meet every this often, and when its sign-ups close before the start.
StateArenaConfig.CycleSeconds = 20 * 60
StateArenaConfig.SignUpClosesSeconds = 60
-- It needs this many qualified lifters; fewer, no meet and the list carries over. Never computer lifters (§37).
StateArenaConfig.MinimumLifters = 2
-- In Studio, to test alone, without waiting. A lifter in Studio need not be qualified, unless the workspace attribute
-- StudioStateNeedsQualifying is on.
StateArenaConfig.StudioCycleSeconds = 120
StateArenaConfig.StudioSignUpClosesSeconds = 15
StateArenaConfig.StudioMinimumLifters = 1
-- Roblox's own R15 sitting pose, while a lifter waits on their bench for their turn.
StateArenaConfig.SitAnimationId = "rbxassetid://2506281703"

return StateArenaConfig
