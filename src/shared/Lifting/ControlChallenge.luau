--!strict
--[[
	ControlChallenge
	Shared / Lifting

	Turns a resolved LiftDifficulty into one concrete control phase.

	WHY THE MARKER PATH IS SENT, NOT SEEDED

	The server could send a random seed and have both sides generate the same
	path. That would be smaller on the wire, but it makes the result depend on two
	machines agreeing about a pseudo-random sequence, which is a fragile thing to
	stake an authoritative outcome on.

	Instead the server generates the whole path up front as an explicit list of
	retarget events and sends it. There is nothing to agree about: both sides read
	the same numbers. The client renders them, the server replays them.

	The challenge also carries its own physics constants rather than having each
	side read config independently. One attempt therefore has exactly one set of
	rules, and ControlSimulation is a pure function of the challenge.

	SERVER AUTHORITY

	A challenge is built ONCE, on the server, and never derived client-side. The
	client's copy exists so it can draw a responsive bar and predict the outcome;
	the server replays the player's inputs against its own copy and that result is
	the only one that counts.
]]

local ControlPhaseConfig = require(script.Parent.Parent.Config.ControlPhaseConfig)
local DifficultyResolver = require(script.Parent.Parent.Difficulty.DifficultyResolver)
local ParameterMapper = require(script.Parent.Parent.Difficulty.ParameterMapper)

local ControlChallenge = {}

export type RetargetEvent = {
	-- Seconds from the start of the phase.
	atTime: number,
	-- Where the marker should head next, in reference pixels from the bottom.
	targetPosition: number,
}

export type Challenge = {
	phase: string,
	displayName: string,

	-- Geometry, in reference pixels.
	trackHeightPx: number,
	barHeightPx: number,

	-- Bar physics.
	gravityPxPerSec2: number,
	clickImpulsePxPerSec: number,
	maxUpwardVelocityPxPerSec: number,
	maxDownwardVelocityPxPerSec: number,

	-- Starting positions, both the centre of the track.
	barStartPosition: number,
	markerStartPosition: number,

	-- Marker behaviour.
	markerSpeedPxPerSec: number,
	retargetEvents: { RetargetEvent },

	-- Progress meter.
	startingProgress: number,
	maxProgress: number,
	fillRatePerSec: number,
	drainRatePerSec: number,
	edgeHysteresisSeconds: number,

	-- Simulation.
	fixedTimestepSeconds: number,
	maxPhaseSeconds: number,

	-- Display only.
	holdDurationSeconds: number,
	retargetIntervalSeconds: number,
	attemptWeightKg: number,
	forecastedMaxKg: number,
	intensityPercent: number,
	baseDifficulty: number,
	classification: string,
}

export type DisplayWeights = {
	attemptWeightKg: number,
	forecastedMaxKg: number,
}

--[[
	Picks the marker's next position, at least MinRetargetTravelFraction of the
	track away from where it is now.

	Without that minimum a retarget could be a five pixel twitch, which spends one
	of the phase's direction changes on nothing.
]]
local function pickNextPosition(current: number, trackHeight: number, rng: Random): number
	local minTravel = trackHeight * ControlPhaseConfig.MinRetargetTravelFraction

	-- Space available above and below, once the minimum travel is taken out.
	local lowCeiling = current - minTravel
	local highFloor = current + minTravel

	local canGoLow = lowCeiling > 0
	local canGoHigh = highFloor < trackHeight

	if canGoLow and canGoHigh then
		if rng:NextNumber() < 0.5 then
			return rng:NextNumber(0, lowCeiling)
		end
		return rng:NextNumber(highFloor, trackHeight)
	elseif canGoLow then
		return rng:NextNumber(0, lowCeiling)
	elseif canGoHigh then
		return rng:NextNumber(highFloor, trackHeight)
	end

	-- Track too short for the minimum travel; fall back to anywhere.
	return rng:NextNumber(0, trackHeight)
end

--[[
	Builds the complete retarget schedule for the phase.

	Covers the full safety-bound duration, so the marker never runs out of
	instructions even if the player hovers near break-even for the whole phase.
]]
local function buildRetargetEvents(
	markerStart: number,
	trackHeight: number,
	retargetInterval: number,
	maxPhaseSeconds: number,
	rng: Random
): { RetargetEvent }
	local events: { RetargetEvent } = {}
	local jitter = ControlPhaseConfig.RetargetJitter
	local position = markerStart
	local time = 0

	-- The first target is chosen immediately, so the marker starts moving at once.
	while time <= maxPhaseSeconds do
		position = pickNextPosition(position, trackHeight, rng)
		table.insert(events, {
			atTime = time,
			targetPosition = position,
		})

		local interval = retargetInterval * (1 + rng:NextNumber(-jitter, jitter))
		time += math.max(interval, ControlPhaseConfig.FixedTimestepSeconds)
	end

	return events
end

--[[
	Builds a challenge.

	phaseName  a key in ControlPhaseConfig.Phases
	difficulty a resolved LiftDifficulty
	weights    the kilograms behind that difficulty, for the client's HUD
	rng        the caller's Random, so the server controls all randomness
]]
function ControlChallenge.build(
	phaseName: string,
	difficulty: DifficultyResolver.LiftDifficulty,
	weights: DisplayWeights,
	rng: Random
): Challenge
	local phase = ControlPhaseConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[ControlChallenge] unknown phase %q", phaseName))

	local profile = ControlPhaseConfig.Profiles[phase.profile]
	local resolved = ParameterMapper.resolveAll(profile, difficulty)

	local trackHeight = ControlPhaseConfig.TrackHeightPx
	local centre = trackHeight / 2

	local holdDuration = resolved.holdDuration
	local maxPhaseSeconds = holdDuration * ControlPhaseConfig.MaxPhaseDurationMultiplier

	--[[
		Fill is derived from the hold duration, then scaled by the charge-speed
		multiplier.

		With the multiplier at 1.0, holdDuration is literally "seconds of perfect
		control to go from the starting value to full". Above 1.0 the meter charges
		faster and the real completion time is holdDuration / multiplier.
	]]
	local progressToWin = ControlPhaseConfig.MaxProgress - ControlPhaseConfig.StartingProgress
	local fillRate = (progressToWin / holdDuration) * ControlPhaseConfig.FillRateMultiplier

	return {
		phase = phaseName,
		displayName = phase.displayName,

		trackHeightPx = trackHeight,
		barHeightPx = ControlPhaseConfig.BarHeightPx,

		gravityPxPerSec2 = ControlPhaseConfig.GravityPxPerSec2,
		clickImpulsePxPerSec = ControlPhaseConfig.ClickImpulsePxPerSec,
		maxUpwardVelocityPxPerSec = ControlPhaseConfig.MaxUpwardVelocityPxPerSec,
		maxDownwardVelocityPxPerSec = ControlPhaseConfig.MaxDownwardVelocityPxPerSec,

		barStartPosition = centre,
		markerStartPosition = centre,

		markerSpeedPxPerSec = resolved.markerSpeed,
		retargetEvents = buildRetargetEvents(
			centre,
			trackHeight,
			resolved.retargetInterval,
			maxPhaseSeconds,
			rng
		),

		startingProgress = ControlPhaseConfig.StartingProgress,
		maxProgress = ControlPhaseConfig.MaxProgress,
		fillRatePerSec = fillRate,
		drainRatePerSec = resolved.drainRate,
		edgeHysteresisSeconds = ControlPhaseConfig.EdgeHysteresisSeconds,

		fixedTimestepSeconds = ControlPhaseConfig.FixedTimestepSeconds,
		maxPhaseSeconds = maxPhaseSeconds,

		holdDurationSeconds = holdDuration,
		retargetIntervalSeconds = resolved.retargetInterval,
		attemptWeightKg = weights.attemptWeightKg,
		forecastedMaxKg = weights.forecastedMaxKg,
		intensityPercent = difficulty.intensityPercent,
		baseDifficulty = difficulty.baseDifficulty,
		classification = difficulty.classification,
	}
end

--[[
	The technique stat a phase reads, e.g. "SquatControl" for Squat Control.
]]
function ControlChallenge.techniqueStatFor(phaseName: string): string
	local phase = ControlPhaseConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[ControlChallenge] unknown phase %q", phaseName))
	return phase.techniqueStat
end

--[[
	The lift whose forecasted max a phase measures against, e.g. "Squat".
]]
function ControlChallenge.liftFor(phaseName: string): string
	local phase = ControlPhaseConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[ControlChallenge] unknown phase %q", phaseName))
	return phase.lift
end

--[[
	Whether a name refers to a configured phase, so a client's request can be
	validated without trusting the string it sent.
]]
function ControlChallenge.isKnownPhase(phaseName: unknown): boolean
	if typeof(phaseName) ~= "string" then
		return false
	end
	return ControlPhaseConfig.Phases[phaseName :: string] ~= nil
end

--[[
	The player-facing verdict for an outcome, read from the phase's own config so
	one lift's wording cannot leak into another.
]]
function ControlChallenge.verdictText(phaseName: string, outcome: string): string
	local phase = ControlPhaseConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[ControlChallenge] unknown phase %q", phaseName))

	if outcome == "Passed" then
		return phase.verdicts.pass
	elseif outcome == "FailedTimeout" then
		return phase.verdicts.failTimeout
	end

	return phase.verdicts.failLostControl
end

--[[
	The label shown for a phase, e.g. "DEPTH". The attempt banner uses it so a
	transition can name the phase that is coming next, instead of the client having
	to know each lift's sequence.
]]
function ControlChallenge.displayNameFor(phaseName: string): string
	local phase = ControlPhaseConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[ControlChallenge] unknown phase %q", phaseName))
	return phase.displayName
end

return ControlChallenge
