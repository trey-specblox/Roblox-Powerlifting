--!strict
--[[
	ControlPhaseConfig
	Shared / Config

	Every balance and physics number for the reusable Fisch-style control phase.

	Reference: References/FischeGame.md and References/testyourmight.md.

	THE MECHANIC

	A success marker travels vertically. The player holds a white bar under it by
	clicking: each click pushes the bar upward, and gravity pulls it down between
	clicks. While the marker is inside the bar a progress meter fills; while it is
	outside, the meter drains. Full meter passes the phase, empty meter fails it.

	=========================================================================
	STATUS: PROVISIONAL. NOT FINAL BALANCE. DO NOT TREAT AS SETTLED.
	=========================================================================

	These are the values of a development stopping point, accepted as good enough
	to move on from rather than as balance. They reached this state over five
	Studio tuning passes, each recorded beside the value it changed:

		pass 1   first approved specification: 80 px bar, fill multiplier 1.0
		pass 2   bar 80 -> 110 px
		pass 3   bar 110 -> 150 px
		pass 4   fill multiplier 1.0 -> 1.5
		pass 5   fill multiplier 1.5 -> 3.0

	Where that leaves a 100% attempt by a lifter with no Control at all:

		150 px bar on a 400 px track          (37.5% of the track)
		marker at 230 px/s, retargeting ~0.9s
		meter fills at 30 points/s
		2.17s of continuous perfect tracking to fill it
		the marker need only be inside the bar 40% of the time to net progress

	TWO THINGS TO REVISIT, DELIBERATELY LEFT ALONE

	The fill multiplier moved charge speed and the break-even requirement together,
	because they are the same lever. The required on-target share at a 100% attempt
	consequently fell from 67% to 40%, which is softer than intended and is the
	drain curve's job to correct, not the fill rate's.

	Easy attempts are now very brief: a warmup fills in about 1.0s, which barely
	registers as gameplay. The fill curve's shape, not its scale, is the fix.

	Both wait until Squat Control and Squat Depth run as one complete squat
	attempt, because a phase judged alone says little about how the whole lift
	feels.

	WHAT THE GAME_DESIGN.md px/s ANCHORS CONTROL

	GAME_DESIGN.md lists its anchors directly beneath "Control influences: target
	movement speed". They are therefore the SUCCESS MARKER's vertical travel
	speed, not the white bar's speed and not any zone size:

		difficulty 20 -> 100 px/s
		difficulty 50 -> 180 px/s
		difficulty 80 -> 280 px/s
		difficulty 95 -> 400 px/s

	Those four values are used exactly. Only the 0 and 100 endpoints are added.

	WHY A REFERENCE TRACK HEIGHT EXISTS

	Pixels per second is meaningless without knowing how tall the track is. All
	simulation happens in a fixed reference track, and the UI scales visually, so
	a player on a larger monitor does not get an easier game.

	REUSABLE ACROSS TWO LIFTS

	FischeGame.md assigns this same mechanic to the Bench Press, driven by Start
	Control. The Phases table below is therefore the only place anything
	lift-specific lives, exactly as in SkillCheckConfig. Only Squat Control is
	implemented; Bench is deliberately absent rather than stubbed.
]]

local Curve = require(script.Parent.Parent.Util.Curve)
local ParameterMapper = require(script.Parent.Parent.Difficulty.ParameterMapper)

local ControlPhaseConfig = {}

--[[
	TRACK GEOMETRY, in reference pixels. Position 0 is the bottom of the track and
	TrackHeightPx is the top. The bar's position is its CENTRE.
]]
ControlPhaseConfig.TrackHeightPx = 400

--[[
	Height of the player's white bar, as a share of the 400 px reference track.

	PLAYTEST PASS 3: raised again, 110 px to 150 px (27.5% to 37.5% of the track).

	This is a deliberately ISOLATED experiment. Three passes have now moved only
	this one number -- 80, then 110, now 150 -- while marker speed, retarget
	frequency, duration, all the bar physics, the fill and drain rates, starting
	progress and every scaling curve stayed exactly as first approved. The point is
	to find out whether bar size is the main source of the baseline difficulty
	before touching the movement physics or the difficulty curves.

	If 150 px still reads as too hard at the beginner level, bar size is NOT the
	dominant factor and the answer lies elsewhere: most likely the drain rate, or
	how responsive the bar feels under gravity.

	Widening the bar raises the share of the phase a player CAN keep the marker
	inside. The share they MUST achieve is untouched, because that comes from the
	fill and drain rates.

	Still held constant across difficulty: difficulty is expressed through marker
	speed, retarget frequency and required duration. testyourmight.md also lists
	"Target/safe-zone size" as a lever, so this may become a curve later.

	Note the bar is always kept fully on the track, so at 150 px its centre travels
	between 75 and 325. A bar resting at either end still covers the very edge of
	the track, so no marker position is unreachable.

	History: 80 px (pass 1), 110 px (pass 2).
]]
ControlPhaseConfig.BarHeightPx = 150

--[[
	BAR PHYSICS.

	A click SETS upward velocity rather than adding to it. This is deliberate and
	is the main anti-spam measure: spamming can never exceed ClickImpulsePxPerSec,
	so an auto-clicker gains nothing over a human clicking about three times a
	second. Additive impulses would let spam rocket the bar into the ceiling.

	Resulting feel at these values: 0.300 s from click to apex, 49.5 px gained per
	click, about 3.3 clicks per second to hover, and 0.89 s to fall the whole
	track.
]]
ControlPhaseConfig.GravityPxPerSec2 = 1100
ControlPhaseConfig.ClickImpulsePxPerSec = 330
ControlPhaseConfig.MaxUpwardVelocityPxPerSec = 500
-- Stops a long fall from becoming unrecoverable.
ControlPhaseConfig.MaxDownwardVelocityPxPerSec = 700

--[[
	SIMULATION TIMESTEP.

	Fixed, and identical on both sides. The server replays the player's inputs to
	decide the result, so a variable frame delta would let client and server
	diverge on floating point and disagree about the outcome.
]]
ControlPhaseConfig.FixedTimestepSeconds = 1 / 60

--[[
	PROGRESS METER, on a 0 to 100 scale.

	Starting above zero gives a recovery buffer so one early fumble is not fatal,
	without being enough to coast on.
]]
ControlPhaseConfig.MaxProgress = 100
ControlPhaseConfig.StartingProgress = 35

--[[
	PLAYTEST PASS 5: meter charge speed, doubled again.

	The fill rate is derived from holdDuration, which made charging deliberately
	slow on heavy attempts. Studio testing showed the problem was not how long the
	phase lasted but how slowly the meter climbed while the player WAS succeeding,
	which reads as unrewarding. The aim is for the meter to visibly leap when the
	marker is held inside the bar.

	This multiplier scales the derived fill rate without touching the holdDuration
	curve, which is what keeps these passes isolated to charge speed alone.

	History at a 100% attempt with Control 0:
		x1.0  10.0 points/s, 6.50 s to fill   (original derivation)
		x1.5  15.0 points/s, 4.33 s to fill   (pass 4)
		x3.0  30.0 points/s, 2.17 s to fill   (pass 5, current)

	TWO CONSEQUENCES, STATED PLAINLY:

	holdDuration is no longer the completion time. Actual completion time is
	holdDuration / FillRateMultiplier.

	And because the break-even share is drain / (fill + drain), a faster fill also
	lowers the share of the phase the marker must spend inside the bar: at a 100%
	attempt that share has fallen from 67% to 40%. Charging faster and being easier
	to net progress are the same lever and cannot be separated without also moving
	the drain rate.

	Set back to 1.0 to restore the original behaviour.
]]
ControlPhaseConfig.FillRateMultiplier = 3.0

--[[
	Grace before the fill/drain direction flips at the bar's edge.

	Without it, a marker sitting exactly on the boundary flickers between filling
	and draining every frame, which looks broken even though the maths is right.
]]
ControlPhaseConfig.EdgeHysteresisSeconds = 0.1

--[[
	Safety bound on how long a phase may run before it is failed outright. This is
	a backstop against a player hovering forever near the break-even point, not a
	gameplay timer. Multiplies the resolved hold duration.
]]
ControlPhaseConfig.MaxPhaseDurationMultiplier = 3

--[[
	INPUT LIMITS.

	Clicks arriving closer together than 1 / MaxClicksPerSecond are discarded.
	With a velocity-setting impulse this is already redundant for balance, so it
	exists purely so an auto-clicker cannot flood the report with thousands of
	entries.
]]
ControlPhaseConfig.MaxClicksPerSecond = 12

--[[
	MARKER MOVEMENT.

	The marker picks a position, travels to it at the resolved speed, then picks
	another. A minimum travel distance stops a retarget being a wasted few-pixel
	twitch, and jitter keeps the rhythm from being memorisable, matching how the
	skill check jitters its lead.
]]
ControlPhaseConfig.MinRetargetTravelFraction = 0.15
ControlPhaseConfig.RetargetJitter = 0.15

--[[
	How far a client's reported timings may disagree with the server's own
	measurement of elapsed time before the attempt is rejected.
]]
ControlPhaseConfig.TimingToleranceSeconds = 1.5

local function linear(anchors: { Curve.Anchor }): Curve.Curve
	return {
		space = "linear",
		anchors = anchors,
	}
end

--[[
	The shared profile. PROVISIONAL playtest values.

	Resulting experience at Control 0:

		diff  marker   retarget  hold   drain   fail-from   min % on
		       px/s        s       s    pts/s    start s     target
		   0      70      2.00    3.00   10.0      3.50        32%
		  20     100      1.60    4.00   13.0      2.69        44%
		  50     180      1.10    5.50   17.0      2.06        59%
		  65     230      0.90    6.50   20.0      1.75        67%
		  80     280      0.72    7.50   23.0      1.52        73%
		  95     400      0.55    9.00   27.0      1.30        79%
		 100     450      0.50    9.50   28.0      1.25        80%

	"min % on target" is the share of the phase the marker must spend inside the
	bar for the meter to make any net progress, which is drain / (fill + drain).
	It is the clearest single expression of how hard a given attempt is.
]]
local defaultProfile: ParameterMapper.MinigameSpec = {
	--[[
		Success marker travel speed. The GAME_DESIGN.md anchors, used exactly.

		NOTE: there is deliberately no fromTechnique curve here. The Control stat
		must not slow the marker down, because marker speed is the one thing that
		keeps the phase from becoming automatic for a fully trained lifter. With no
		technique curve, that guarantee is structural rather than a matter of
		choosing a conservative multiplier.
	]]
	markerSpeed = {
		fromDifficulty = linear({
			{ x = 0, y = 70 },
			{ x = 20, y = 100 },
			{ x = 50, y = 180 },
			{ x = 80, y = 280 },
			{ x = 95, y = 400 },
			{ x = 100, y = 450 },
		}),
		minimum = 40,
	},

	-- Seconds between the marker choosing a new position. Shorter is harder.
	retargetInterval = {
		fromDifficulty = linear({
			{ x = 0, y = 2.00 },
			{ x = 20, y = 1.60 },
			{ x = 50, y = 1.10 },
			{ x = 65, y = 0.90 },
			{ x = 80, y = 0.72 },
			{ x = 95, y = 0.55 },
			{ x = 100, y = 0.50 },
		}),
		--[[
			Above 1.0: better Control means fewer direction changes to react to.
			Near-linear in EFFECTIVE technique on purpose, because diminishing
			returns already live in the raw-to-effective curve in TechniqueConfig.
			Curving it again would compound them.
		]]
		fromTechnique = linear({
			{ x = 10, y = 1.00 },
			{ x = 20, y = 1.06 },
			{ x = 30, y = 1.12 },
			{ x = 40, y = 1.18 },
			{ x = 55, y = 1.28 },
			{ x = 70, y = 1.38 },
			{ x = 82, y = 1.47 },
			{ x = 92, y = 1.54 },
			{ x = 99.5, y = 1.60 },
		}),
		minimum = 0.25,
	},

	--[[
		Seconds of perfect control needed to carry the meter from its starting
		value to full. The fill rate is derived from this, so the name means
		exactly what it says.
	]]
	holdDuration = {
		fromDifficulty = linear({
			{ x = 0, y = 3.0 },
			{ x = 20, y = 4.0 },
			{ x = 50, y = 5.5 },
			{ x = 65, y = 6.5 },
			{ x = 80, y = 7.5 },
			{ x = 95, y = 9.0 },
			{ x = 100, y = 9.5 },
		}),
		-- Below 1.0: better Control shortens the ordeal.
		fromTechnique = linear({
			{ x = 10, y = 1.00 },
			{ x = 20, y = 0.96 },
			{ x = 30, y = 0.92 },
			{ x = 40, y = 0.88 },
			{ x = 55, y = 0.81 },
			{ x = 70, y = 0.73 },
			{ x = 82, y = 0.66 },
			{ x = 92, y = 0.60 },
			{ x = 99.5, y = 0.55 },
		}),
		minimum = 1.0,
	},

	--[[
		Progress points lost per second while the marker is outside the bar.

		Its own curve rather than a multiple of the fill rate. Tying it to fill
		inverted the difficulty: fill slows at high difficulty, so a derived drain
		also slowed, which made failure MORE forgiving on the hardest attempts. An
		independent rising curve gives 3.50 s of recovery at a warmup down to
		1.25 s at the top.
	]]
	drainRate = {
		fromDifficulty = linear({
			{ x = 0, y = 10 },
			{ x = 20, y = 13 },
			{ x = 50, y = 17 },
			{ x = 65, y = 20 },
			{ x = 80, y = 23 },
			{ x = 95, y = 27 },
			{ x = 100, y = 28 },
		}),
		minimum = 2,
	},
}

ControlPhaseConfig.Profiles = {
	Default = defaultProfile,
}

--[[
	EVERYTHING LIFT-SPECIFIC ABOUT A CONTROL PHASE LIVES HERE.

	The physics, the marker, the meter, the input handling and the server
	validation are all phase-agnostic and read what they need from this entry.

	Adding Bench Bar Control later should be an entry here plus an interaction
	point, not a second copy of the mechanic:

		BenchBarControl = {
			lift = "Bench",
			techniqueStat = "StartControl",
			profile = "Default",
			displayName = "BAR",
			verdicts = { ... },
		}

	`lift` must match a key in PlayerProfileSchema.Forecasted and `techniqueStat`
	a key in PlayerProfileSchema.Technique.
]]
ControlPhaseConfig.Phases = {
	SquatControl = {
		lift = "Squat",
		techniqueStat = "SquatControl",
		profile = "Default",
		displayName = "CONTROL",
		-- Placeholder copy. Failing Phase 1 will eventually mean the whole squat
		-- is a No Lift and the depth check never runs.
		verdicts = {
			pass = "CONTROL MAINTAINED",
			failLostControl = "NO LIFT - LOST CONTROL",
			failTimeout = "NO LIFT - OUT OF TIME",
		},
	},
}

-- Fail at startup rather than mid-lift if a balancing table is malformed.
for profileName, profile in pairs(ControlPhaseConfig.Profiles) do
	ParameterMapper.validate(profile, "ControlPhaseConfig.Profiles." .. profileName)
end

for phaseName, phase in pairs(ControlPhaseConfig.Phases) do
	assert(
		ControlPhaseConfig.Profiles[phase.profile] ~= nil,
		string.format("[ControlPhaseConfig] phase %s points at unknown profile %q", phaseName, phase.profile)
	)
	assert(
		typeof(phase.lift) == "string" and phase.lift ~= "",
		string.format("[ControlPhaseConfig] phase %s must name the lift it reads", phaseName)
	)
	assert(
		typeof(phase.techniqueStat) == "string" and phase.techniqueStat ~= "",
		string.format("[ControlPhaseConfig] phase %s must name its technique stat", phaseName)
	)
	assert(
		typeof(phase.displayName) == "string" and phase.displayName ~= "",
		string.format("[ControlPhaseConfig] phase %s must have a displayName", phaseName)
	)

	for _, key in ipairs({ "pass", "failLostControl", "failTimeout" }) do
		assert(
			typeof(phase.verdicts) == "table" and typeof(phase.verdicts[key]) == "string",
			string.format("[ControlPhaseConfig] phase %s is missing its %q verdict wording", phaseName, key)
		)
	end
end

assert(
	ControlPhaseConfig.StartingProgress > 0
		and ControlPhaseConfig.StartingProgress < ControlPhaseConfig.MaxProgress,
	"[ControlPhaseConfig] StartingProgress must sit between 0 and MaxProgress"
)
assert(
	ControlPhaseConfig.BarHeightPx < ControlPhaseConfig.TrackHeightPx,
	"[ControlPhaseConfig] the bar must be shorter than the track"
)

return ControlPhaseConfig
