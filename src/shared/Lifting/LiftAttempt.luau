--!strict
--[[
	LiftAttempt
	Shared / Lifting

	The vocabulary a lift attempt is described in: phase kinds, verdicts, and the
	shape of every message that crosses between server and client.

	Having the payload types in one shared place means the orchestrator and the
	client controller cannot quietly disagree about a field name, which is the sort
	of bug that shows up as a blank HUD rather than an error.

	Nothing here decides anything. It is types and constants.
]]

local LiftAttempt = {}

--[[
	Which phase system runs a phase.

	"Control"    the Fisch-style control minigame      (Squat phase 1)
	"Power"      the Test Your Might rapid-input phase (Bench phase 1)
	"Typing"     the character-first typing pull       (Deadlift phase 1)
	"SkillCheck" the circular timing check             (every lift's phase 2)

	Note that Control is Squat-only, Power is Bench-only and Typing is
	Deadlift-only, while SkillCheck is shared by all three lifts. That asymmetry is
	the design: each lift has its own first phase and they converge on the same
	timing check.
]]
export type PhaseKind = "Control" | "Power" | "Typing" | "SkillCheck"

LiftAttempt.PhaseKind = {
	Control = "Control" :: PhaseKind,
	Power = "Power" :: PhaseKind,
	Typing = "Typing" :: PhaseKind,
	SkillCheck = "SkillCheck" :: PhaseKind,
}

export type AttemptVerdict = "GoodLift" | "NoLift"

LiftAttempt.Verdict = {
	GoodLift = "GoodLift" :: AttemptVerdict,
	NoLift = "NoLift" :: AttemptVerdict,
}

--[[
	What one phase produced. Built by a phase service, consumed by the orchestrator.

	`passed` is the only field the orchestrator's decisions read. Everything else
	is for the player's feedback and for logs.
]]
export type PhaseResult = {
	phaseName: string,
	kind: PhaseKind,
	passed: boolean,
	-- Phase-specific outcome string, e.g. "FailedTimeout" or "Late".
	outcome: string,
	-- Player-facing line for this phase, from the phase's own config.
	verdict: string,
	-- Diagnostics for the dev HUD and server log.
	detail: string,
}

--[[
	What a phase service needs in order to run a phase.

	The difficulty arrives already resolved, and the weights already derived. A
	phase service never reads a player's profile, which is what makes an attempt's
	numbers lockable.
]]
export type PhaseContext = {
	attemptId: number,
	phaseName: string,
	kind: PhaseKind,
	attemptWeightKg: number,
	forecastedMaxKg: number,
}

-- server -> client: render this phase
export type PresentPhasePayload = {
	attemptId: number,
	kind: PhaseKind,
	phaseName: string,
	phaseIndex: number,
	phaseCount: number,
	challenge: any,
}

-- server -> client: that phase is decided
export type PhaseResultPayload = {
	attemptId: number,
	kind: PhaseKind,
	phaseName: string,
	passed: boolean,
	verdict: string,
	detail: string,
	-- True when another phase follows, so the client can show a transition.
	hasNextPhase: boolean,
	--[[
		The label of the phase that follows, e.g. "DEPTH" or "PRESS". Sent so the
		transition banner can name it without the client needing to know each lift's
		sequence. Nil when this phase ended the attempt.
	]]
	nextPhaseDisplayName: string?,
}

-- server -> client: the whole attempt is decided
export type AttemptResultPayload = {
	attemptId: number,
	liftName: string,
	verdict: AttemptVerdict,
	-- Player-facing line, "GOOD LIFT" or "NO LIFT".
	verdictText: string,
	attemptWeightKg: number,
	forecastedMaxKg: number,
	attemptPercent: number,
	-- Set only on a No Lift: which phase ended it.
	failedPhase: string?,
	resultHoldSeconds: number,
}

return LiftAttempt
