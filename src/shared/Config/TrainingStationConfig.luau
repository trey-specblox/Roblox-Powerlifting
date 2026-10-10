--!strict
--[[
	TrainingStationConfig
	Shared / Config

	Named settings for the gym training racks of checkpoint 5B.6
	(GAME_DESIGN.md section 34.3 and 34.12).

	This is RACK MECHANICS, not balance. How much EV an hour earns, the 4.00 EV
	daily cap and H(t) all live in ProgressionConfig.DailyTraining and are not
	repeated here. Nothing below changes how fast a player progresses; it only
	changes how often the rack measures them, how strict it is about where they
	stand, and what the menu offers.

	=========================================================================
	EVERY VALUE BELOW IS A PROVISIONAL STARTING VALUE, NOT FINAL.
	=========================================================================
]]

local ProgressionConfig = require(script.Parent.ProgressionConfig)

local TrainingStationConfig = {}

--[[
	How often the server's single training loop measures every occupant, in
	seconds. Each tick credits the time since that player's previous tick.

	10 s is about 0.0028 EV at full rate, so the daily cap is reached precisely,
	and a player who disconnects loses at most one tick of unbanked time.
	ProfileStore only saves every few minutes, so ticks add no DataStore traffic.
]]
TrainingStationConfig.TickSeconds = 10

--[[
	The most time one tick may ever credit, in seconds. Anything longer -- a
	server hitch, a frozen thread -- is DISCARDED, never back-paid.

	Three times the tick period: generous enough that ordinary lag never costs a
	player anything, tight enough that a stalled server cannot pay out a large
	interval nobody actually observed.
]]
TrainingStationConfig.MaxCreditSecondsPerTick = 30

--[[
	How close the player's HumanoidRootPart must be to the rack's stand point,
	in studs, checked by the SERVER when the menu opens, on every request and on
	every tick. A little larger than the prompt's reach so stepping around on the
	platform is fine.
]]
TrainingStationConfig.PresenceRadiusStuds = 12

--[[
	Minimum seconds between two training selections by the same player (a new
	lift, mode or primary stat). Stops a spammed Start button from calling the
	progression gateway many times a second. Re-confirming the selection already
	running is not a change and is never throttled.
]]
TrainingStationConfig.SelectionCooldownSeconds = 1

-- ProximityPrompt reach, in studs. Must stay below PresenceRadiusStuds.
TrainingStationConfig.PromptMaxDistanceStuds = 8

--[[
	ONE prompt per rack, HELD to open the Training Selection menu. Holding rather
	than tapping stops a player from opening a menu by brushing past a rack.
	E and ButtonX are not bound by any lifting minigame or debug key.
]]
TrainingStationConfig.PromptHoldSeconds = 0.5
TrainingStationConfig.PromptKeyboardKey = Enum.KeyCode.E
TrainingStationConfig.PromptGamepadKey = Enum.KeyCode.ButtonX

--[[
	REMOTE SPAM LIMIT. Every menu request (Start, Stop, Close) and every prompt
	trigger counts. Beyond RequestLimit within RequestWindowSeconds, the extra
	requests are ignored until the window clears. A real player clicks a few
	times a second at most.
]]
TrainingStationConfig.RequestLimit = 8
TrainingStationConfig.RequestWindowSeconds = 4

--[[
	What the menu calls each technique stat. WHICH stats a lift trains, and the
	80/20 split, are NOT here: ProgressionConfig.TrainableTechnique is the one
	authoritative pairing table (checkpoint 5B.7).
]]
TrainingStationConfig.TechniqueStatNames = {
	SquatControl = "Squat Control",
	DepthAwareness = "Depth Awareness",
	StartControl = "Start Control",
	PressPower = "Press Power",
	Lockout = "Lockout",
}

--[[
	CollectionService tag carried by every rack the server trusts. A rack also
	needs a string attribute "StationId", unique per rack. Tags and attributes
	set by a client never reach the server, so a client cannot invent a rack.
]]
TrainingStationConfig.StationTag = "GymTrainingStation"

--[[
	TEMPORARY PLACEHOLDER RACKS, built from basic Parts by PlaceholderStations.

	Two, so the one-player-per-rack and one-rack-per-player rules can be tested
	for real. Positions are the centre of each platform on the Baseplate (whose
	top surface is at Y = 0), a short walk from the default spawn.

	Delete these entries, and PlaceholderStations, when real rack models exist.
	Real racks are registered the same way, through the tag, so nothing in the
	progression system changes.
]]
TrainingStationConfig.PlaceholderStations = {
	{ stationId = "PlaceholderStationA", position = Vector3.new(-14, 0, -18) },
	{ stationId = "PlaceholderStationB", position = Vector3.new(14, 0, -18) },
}

--[[
	=========================================================================
	CONFIGURATION INTEGRITY -- CHECKED AT STARTUP
	=========================================================================

	Same pattern as ProgressionConfig: a bad edit fails loudly on server start
	rather than quietly changing what the rack credits.
]]

local function requirePositiveFinite(name: string, value: any)
	assert(
		typeof(value) == "number" and value == value and value > 0 and value < math.huge,
		string.format("[TrainingStationConfig] %s must be a finite number above zero", name)
	)
end

requirePositiveFinite("TickSeconds", TrainingStationConfig.TickSeconds)
requirePositiveFinite("MaxCreditSecondsPerTick", TrainingStationConfig.MaxCreditSecondsPerTick)
requirePositiveFinite("PresenceRadiusStuds", TrainingStationConfig.PresenceRadiusStuds)
requirePositiveFinite("PromptMaxDistanceStuds", TrainingStationConfig.PromptMaxDistanceStuds)
requirePositiveFinite("PromptHoldSeconds", TrainingStationConfig.PromptHoldSeconds)
requirePositiveFinite("RequestLimit", TrainingStationConfig.RequestLimit)
requirePositiveFinite("RequestWindowSeconds", TrainingStationConfig.RequestWindowSeconds)

assert(
	typeof(TrainingStationConfig.SelectionCooldownSeconds) == "number"
		and TrainingStationConfig.SelectionCooldownSeconds >= 0
		and TrainingStationConfig.SelectionCooldownSeconds < math.huge,
	"[TrainingStationConfig] SelectionCooldownSeconds must be a finite number of 0 or more"
)

--[[
	A cap below the tick period would discard part of EVERY ordinary tick, so a
	player standing at the rack the whole time would be silently underpaid.
]]
assert(
	TrainingStationConfig.MaxCreditSecondsPerTick >= TrainingStationConfig.TickSeconds,
	"[TrainingStationConfig] MaxCreditSecondsPerTick must be at least TickSeconds, "
		.. "or every normal tick is partly thrown away"
)

--[[
	The progression gateway refuses any interval over one day. Staying far below
	that keeps a rack tick from ever being a whole-update rejection.
]]
assert(
	TrainingStationConfig.MaxCreditSecondsPerTick <= 3600,
	"[TrainingStationConfig] MaxCreditSecondsPerTick must be at most an hour"
)

assert(
	TrainingStationConfig.PromptMaxDistanceStuds < TrainingStationConfig.PresenceRadiusStuds,
	"[TrainingStationConfig] PromptMaxDistanceStuds must be below PresenceRadiusStuds, "
		.. "or a player could open the menu from a spot the next tick rejects"
)

-- Every stat the authoritative pairing table can train needs a menu name.
for _, stats in pairs(ProgressionConfig.TrainableTechnique :: { [string]: { string } }) do
	for _, stat in ipairs(stats) do
		assert(
			(TrainingStationConfig.TechniqueStatNames :: any)[stat] ~= nil,
			string.format("[TrainingStationConfig] technique stat %s has no display name", stat)
		)
	end
end

return TrainingStationConfig
