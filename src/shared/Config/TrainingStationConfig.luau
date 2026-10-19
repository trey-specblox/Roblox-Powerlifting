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
	GYM RACKS, spawned at server start by RackSpawner (checkpoint 6D.2a) from a
	Git-tracked template in ServerStorage.RackTemplates (art/roblox/*.rbxmx).

	  stationId      "GymRack_" + at least two digits, unique. Also the rack's
	                 name in Workspace.GymRacks. The sign and menu show the
	                 trailing number: "Training Rack 01".
	  template       name of the Model in ServerStorage.RackTemplates.
	  position       floor centre of the rack (the Baseplate top is Y = 0).
	  facingDegrees  turn about the vertical axis. 0 = the J-cup (front) side
	                 faces -Z, as modelled; 90 = it faces -X. (Checked from both
	                 templates' .rbxmx files 2026-10-18; older notes said +Z.)

	Adding a rack = adding a line here. RackSpawner checks every entry and
	SKIPS a bad one with a warning, so one typo never stops the other racks or
	the rest of the game.

	Positions are PROVISIONAL: no final gym layout is approved yet, so racks
	are moved by editing these lines, never by hand in Studio.
]]
export type GymRackEntry = {
	stationId: string,
	template: string,
	position: Vector3,
	facingDegrees: number,
}

--[[
	2026-10-18: every station uses ComboRack_01 (GAME_DESIGN §34.12 decision 15),
	at the same spots the PowerRack_01 racks used. Its position is the floor
	centre between the two tall posts; the rack reaches 3.0 studs to the front
	(-Z at facing 0), 2.05 to the back and 3.95 to each side, and the lifter
	deadlifts in front of it. PowerRack_01 still has a profile and template, so
	a line can switch back by changing its template name.
]]
TrainingStationConfig.GymRacks = {
	{ stationId = "GymRack_01", template = "ComboRack_01", position = Vector3.new(0, 0, -30), facingDegrees = 0 },
	-- 6D.2b: replaced the hand-placed Workspace.PowerRack_01, at its exact spot.
	{ stationId = "GymRack_02", template = "ComboRack_01", position = Vector3.new(-1.3, 0, 12), facingDegrees = 0 },
	-- 6D.2c: replaced the retired placeholder platforms A and B, at their spots.
	{ stationId = "GymRack_03", template = "ComboRack_01", position = Vector3.new(-14, 0, -18), facingDegrees = 0 },
	{ stationId = "GymRack_04", template = "ComboRack_01", position = Vector3.new(14, 0, -18), facingDegrees = 0 },
} :: { GymRackEntry }

--[[
	The plates on every station's barbell, per side, inside to outside, before
	the lock collar (part names in ServerStorage.BarbellTemplates.Barbell_01).
	Visual only: it shows a loaded bar, it is NOT the player's training weight.
	2 x 25 kg + 2.5 kg collar per side on a 20 kg bar = 125 kg on the bar.
]]
TrainingStationConfig.BarbellDisplayLoadPerSide = { "Plate_25", "Plate_25" }

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
