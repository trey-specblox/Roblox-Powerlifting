--!strict
--[[
	SkillCheckChallenge
	Shared / Lifting

	Turns a resolved LiftDifficulty into one concrete skill check: how fast the
	needle moves, how wide the zones are, and where they sit on the circle.

	GEOMETRY

	The needle starts at 0 degrees (12 o'clock) and sweeps clockwise. The single
	target zone begins at `targetStartDeg`, which is the lead distance. So:

		needle angle at time t = needleSpeedDegPerSec * t

	The check ends when the needle passes the end of the target zone. There is no
	second lap.

	WHY THE LEAD IS CAPPED

	Lead distance plus zone arc must fit inside the sweep budget, or the zone
	would be drawn across the needle's own starting point and the player would
	have no warning at all. The cap also reserves room for jitter, so a maximum
	jitter roll still fits.

	SERVER AUTHORITY

	A challenge is built ONCE, on the server, and sent to the client as concrete
	numbers. The client never derives it. The server keeps its copy and grades
	against that, so there is no shared-seed agreement to get wrong and nothing
	for a client to recompute in its own favour.

	This module is in Shared only so the client can read the challenge's type and
	render it. Building one client-side would be display-only and meaningless.
]]

local SkillCheckConfig = require(script.Parent.Parent.Config.SkillCheckConfig)
local DifficultyResolver = require(script.Parent.Parent.Difficulty.DifficultyResolver)
local ParameterMapper = require(script.Parent.Parent.Difficulty.ParameterMapper)

local SkillCheckChallenge = {}

export type Challenge = {
	-- Which phase this is, e.g. "SquatDepth". Selects wording and presentation.
	phase: string,
	displayName: string,

	-- Degrees per second, clockwise from 12 o'clock.
	needleSpeedDegPerSec: number,

	-- The single target zone, in degrees from the needle's start.
	targetStartDeg: number,
	targetArcDeg: number,

	-- When the needle passes the end of the target zone, in seconds.
	timeoutSeconds: number,

	-- Display only. Lets the client show what it is attempting without needing a
	-- copy of the player's profile.
	attemptWeightKg: number,
	forecastedMaxKg: number,
	intensityPercent: number,
	baseDifficulty: number,
	classification: string,
}

--[[
	The two weights the challenge echoes back for display.

	LiftDifficulty holds the intensity RATIO, not the kilograms it came from, so
	they are passed in rather than recovered by dividing. This is display data
	only: nothing in the grading path reads it.
]]
export type DisplayWeights = {
	attemptWeightKg: number,
	forecastedMaxKg: number,
}

--[[
	Builds a challenge.

	phaseName  a key in SkillCheckConfig.Phases
	difficulty a resolved LiftDifficulty
	weights    the kilograms behind that difficulty, for the client's HUD
	rng        the caller's Random, so the server controls all randomness
]]
function SkillCheckChallenge.build(
	phaseName: string,
	difficulty: DifficultyResolver.LiftDifficulty,
	weights: DisplayWeights,
	rng: Random
): Challenge
	local phase = SkillCheckConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[SkillCheckChallenge] unknown phase %q", phaseName))

	local profile = SkillCheckConfig.Profiles[phase.profile]
	local resolved = ParameterMapper.resolveAll(profile, difficulty)

	local needleSpeed = resolved.needleSpeed
	local targetArc = resolved.targetArc
	local reactionWindow = resolved.reactionWindow

	--[[
		Cap the lead so that lead + arc fits the sweep budget even after a maximum
		jitter roll. Dividing by (1 + jitter) is what reserves that room, and it
		means jitter keeps its full range instead of being flattened at the cap.
	]]
	local jitter = SkillCheckConfig.LeadJitter
	local leadCapDeg = (SkillCheckConfig.SweepBudgetDegrees - targetArc) / (1 + jitter)
	local baseLeadDeg = math.min(reactionWindow * needleSpeed, leadCapDeg)

	-- Jitter, so no fixed rhythm can be memorised.
	local targetStartDeg = baseLeadDeg * (1 + rng:NextNumber(-jitter, jitter))

	local timeoutSeconds = (targetStartDeg + targetArc) / needleSpeed

	return {
		phase = phaseName,
		displayName = phase.displayName,

		needleSpeedDegPerSec = needleSpeed,
		targetStartDeg = targetStartDeg,
		targetArcDeg = targetArc,
		timeoutSeconds = timeoutSeconds,

		attemptWeightKg = weights.attemptWeightKg,
		forecastedMaxKg = weights.forecastedMaxKg,
		intensityPercent = difficulty.intensityPercent,
		baseDifficulty = difficulty.baseDifficulty,
		classification = difficulty.classification,
	}
end

--[[
	The technique stat name a phase reads, e.g. "DepthAwareness" for Squat Depth.
]]
function SkillCheckChallenge.techniqueStatFor(phaseName: string): string
	local phase = SkillCheckConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[SkillCheckChallenge] unknown phase %q", phaseName))
	return phase.techniqueStat
end

--[[
	The lift whose forecasted max a phase measures against, e.g. "Squat".

	Read from config rather than hardcoded by the caller, so a phase's lift is
	declared in exactly one place.
]]
function SkillCheckChallenge.liftFor(phaseName: string): string
	local phase = SkillCheckConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[SkillCheckChallenge] unknown phase %q", phaseName))
	return phase.lift
end

--[[
	Whether a name refers to a configured phase. Used to validate client requests
	without trusting the string they sent.
]]
function SkillCheckChallenge.isKnownPhase(phaseName: unknown): boolean
	if typeof(phaseName) ~= "string" then
		return false
	end
	return SkillCheckConfig.Phases[phaseName :: string] ~= nil
end

--[[
	The label shown for a phase, e.g. "DEPTH". The attempt banner uses it so a
	transition can name the phase that is coming next, instead of the client having
	to know each lift's sequence.
]]
function SkillCheckChallenge.displayNameFor(phaseName: string): string
	local phase = SkillCheckConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[SkillCheckChallenge] unknown phase %q", phaseName))
	return phase.displayName
end

return SkillCheckChallenge
