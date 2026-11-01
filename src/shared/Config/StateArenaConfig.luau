--!strict
--[[
	StateArenaConfig
	Shared / Config

	The State Championship arena (GAME_DESIGN.md §36, user 2026-11-01): its own
	big domed venue, built from the user's reference photos (§36.1), with 4
	racks, a screen above each, and seats all round. This first step builds the
	arena and its entrance building beside the gym; anyone may walk in and look
	round. The State meet itself (§36.4: every 20 minutes with 2+ qualified
	lifters, one lifter at a time, max 4) is built later.

	All numbers [PROVISIONAL].
]]

local StateArenaConfig = {}

-- ------------------------------------------------ getting there and back

-- The invisible point in front of the entrance building's doors that carries the "Go to the State arena" prompt.
StateArenaConfig.EntranceTag = "StateArenaEntrance"
StateArenaConfig.PromptHoldSeconds = 0.5
StateArenaConfig.PromptDistanceStuds = 8

-- The player attribute the server sets while a player is in the arena.
StateArenaConfig.VenueAttribute = "StateArenaVenue"

-- Where the arena is built: far from the gym (about 2000 studs across round 0,0,0), the Local meet venue
-- (-X 4000) and the Mock Meet rooms (+X 4000), high up, so nobody walks in by accident.
StateArenaConfig.Origin = Vector3.new(0, 1000, 4000)

-- A visitor who ends up this far from the arena's middle (the TELEPORT menu, a reset) has left it.
StateArenaConfig.LeftAfterStuds = 400

-- ------------------------------------------------ the arena

-- The 4 racks in a row across the floor (x), facing the main stand (-Z), and how far apart they are.
StateArenaConfig.Racks = 4
StateArenaConfig.RackSpacingStuds = 30

return StateArenaConfig
