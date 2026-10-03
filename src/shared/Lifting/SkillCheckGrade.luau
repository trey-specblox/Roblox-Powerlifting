--!strict
--[[
	SkillCheckGrade
	Shared / Lifting

	Judges one press against one challenge.

	Pure and deterministic: the same challenge and press time always produce the
	same outcome. That is what lets the server be the authority while the client
	shows immediate visual feedback.

	THE RULE

	There is one target zone, so the outcome is binary.

		inside the target  -> the execution succeeds
		before the target  -> failed, pressed too early
		past the target    -> failed, pressed too late
		no press at all    -> failed, the needle ran out

	There is no second zone and no graded tier above success. A press one degree
	inside the zone counts exactly as much as one dead centre.

	ONE PRESS PER CHECK

	A check resolves on the first press. Pressing before the zone is an immediate
	failure rather than being ignored, so panicking costs the attempt. That is a
	deliberate design decision, not an implementation shortcut.

	PHASE-AGNOSTIC

	Nothing here knows about squats. The wording of a verdict comes from the
	phase's own config, so the same judging serves Squat Depth, Bench Press and
	Deadlift Lockout.
]]

local SkillCheckConfig = require(script.Parent.Parent.Config.SkillCheckConfig)
local SkillCheckChallenge = require(script.Parent.SkillCheckChallenge)

local SkillCheckGrade = {}

--[[
	Float tolerance in degrees, so a press landing exactly on a zone boundary is
	not thrown out by rounding. This is NOT input grace: it is far too small to
	matter to a player, and no separate grace mechanic exists.
]]
local BOUNDARY_EPSILON_DEGREES = 0.01

export type FailureReason = "Early" | "Late" | "NoInput"

export type Result = {
	-- Whether the phase counts as completed. False means No Lift.
	passed: boolean,
	-- Only set when passed is false.
	failureReason: FailureReason?,
	-- Where the needle was, for feedback and debugging. Nil when never pressed.
	needleAngleDeg: number?,
	--[[
		How centred the press was: 0 is dead centre of the target, 1 is its edge.
		Nil on a miss.

		This does NOT affect whether the lift counted, and no gameplay reads it
		yet. It is the internal execution-quality signal GAME_DESIGN.md Q4 asks
		for, kept because it is the only thing that could later let training
		reward precision rather than mere success. It is a single measurement, not
		a tier system.
	]]
	centreOffset: number?,
}

--[[
	Judges a press.

	pressTimeSeconds is the time from the check appearing to the press, or nil if
	the player never pressed and the check timed out.
]]
function SkillCheckGrade.evaluate(
	challenge: SkillCheckChallenge.Challenge,
	pressTimeSeconds: number?
): Result
	if pressTimeSeconds == nil then
		return {
			passed = false,
			failureReason = "NoInput",
		}
	end

	assert(
		typeof(pressTimeSeconds) == "number" and pressTimeSeconds == pressTimeSeconds,
		"[SkillCheckGrade] pressTimeSeconds must be a number"
	)

	local angle = challenge.needleSpeedDegPerSec * math.max(pressTimeSeconds, 0)
	local zoneStart = challenge.targetStartDeg
	local zoneEnd = zoneStart + challenge.targetArcDeg

	if angle < zoneStart - BOUNDARY_EPSILON_DEGREES then
		return {
			passed = false,
			failureReason = "Early",
			needleAngleDeg = angle,
		}
	end

	if angle > zoneEnd + BOUNDARY_EPSILON_DEGREES then
		return {
			passed = false,
			failureReason = "Late",
			needleAngleDeg = angle,
		}
	end

	-- Inside the target: the execution succeeded.
	local halfArc = challenge.targetArcDeg / 2
	local centreOffset = 0
	if halfArc > 0 then
		centreOffset = math.clamp(math.abs(angle - (zoneStart + halfArc)) / halfArc, 0, 1)
	end

	return {
		passed = true,
		needleAngleDeg = angle,
		centreOffset = centreOffset,
	}
end

--[[
	The player-facing verdict line for a result.

	The phase is required, because the wording is phase-specific: a missed depth
	call means nothing on a bench press. Reading it from the phase's own config is
	what stops one lift's language leaking into another.
]]
function SkillCheckGrade.verdictText(result: Result, phaseName: string): string
	local phase = SkillCheckConfig.Phases[phaseName]
	assert(phase ~= nil, string.format("[SkillCheckGrade] unknown phase %q", phaseName))

	local verdicts = phase.verdicts

	if result.passed then
		return verdicts.pass
	end

	if result.failureReason == "Early" then
		return verdicts.early
	elseif result.failureReason == "Late" then
		return verdicts.late
	end

	return verdicts.noInput
end

return SkillCheckGrade
