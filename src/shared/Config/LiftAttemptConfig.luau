--!strict
--[[
	LiftAttemptConfig
	Shared / Config

	Defines what a complete lift attempt IS: which phases it runs, in what order,
	and the timings around them.

	This is structure, not balance. The difficulty of each phase lives in that
	phase's own config (ControlPhaseConfig, SkillCheckConfig) and nothing here
	changes how hard a minigame is.

	WHY THE SEQUENCE IS A TABLE

	A lift is a list of phases. Adding Bench later should be an entry here plus an
	interaction point, not a new orchestrator:

		Bench = {
			displayName = "BENCH",
			phases = {
				{ kind = "Control",    phaseName = "BenchBarControl" },
				{ kind = "SkillCheck", phaseName = "BenchPress" },
			},
		}

	Deadlift will need a third kind ("Typing") when that mechanic exists. The
	orchestrator dispatches on `kind`, so a new kind is a new branch there and
	nothing else changes.

	Only Squat is defined. The others are deliberately absent rather than stubbed.

	=========================================================================
	TIMINGS BELOW ARE PROVISIONAL UI VALUES, NOT FINAL.
	=========================================================================
]]

local ControlPhaseConfig = require(script.Parent.ControlPhaseConfig)
local SkillCheckConfig = require(script.Parent.SkillCheckConfig)

local LiftAttemptConfig = {}

--[[
	Bounds on the attempt percentage a client may request.

	These moved here from SkillCheckConfig, which was the wrong owner: an attempt
	percentage describes the whole LIFT, not one phase of it, and the control phase
	was previously borrowing the timing check's copy. The values are unchanged.

	The ceiling sits above 110% so a genuine PR attempt is possible, while refusing
	an absurd request that would resolve straight to difficulty 100.
]]
LiftAttemptConfig.MinimumAttemptPercent = 0.40
LiftAttemptConfig.MaximumAttemptPercent = 1.25

--[[
	Pause between one phase passing and the next being presented.

	Without it the squat would snap from the control minigame straight into a
	timing check with no beat, which reads as a glitch rather than a transition.
]]
LiftAttemptConfig.InterPhaseTransitionSeconds = 0.75

--[[
	How long the final verdict stays on screen before the attempt clears and the
	player may start another.
]]
LiftAttemptConfig.ResultHoldSeconds = 2.5

--[[
	Safety bound on a whole attempt. If an attempt somehow outlives this, it is
	abandoned and the player is freed rather than being locked out forever.

	Generous on purpose: the individual phases have their own, tighter timeouts,
	so this only ever fires if something has genuinely gone wrong.
]]
LiftAttemptConfig.MaxAttemptSeconds = 120

-- Final attempt wording. Placeholder copy, kept out of gameplay code.
LiftAttemptConfig.Verdicts = {
	goodLift = "GOOD LIFT",
	noLift = "NO LIFT",
}

--[[
	The phase sequence per lift.

	`kind` selects which phase system runs it. `phaseName` must be a key in that
	system's own config, which is asserted at startup below.
]]
LiftAttemptConfig.Sequences = {
	Squat = {
		displayName = "SQUAT",
		-- Must match a key in PlayerProfileSchema.Forecasted.
		lift = "Squat",
		phases = {
			{ kind = "Control", phaseName = "SquatControl" },
			{ kind = "SkillCheck", phaseName = "SquatDepth" },
		},
	},
}

--[[
	Startup validation.

	A typo in a phaseName would otherwise surface as an attempt that silently
	cannot start, which is a miserable thing to debug. Checking it against the
	phase systems' own config tables makes it a boot error instead.
]]
for liftName, sequence in pairs(LiftAttemptConfig.Sequences) do
	assert(
		typeof(sequence.lift) == "string" and sequence.lift ~= "",
		string.format("[LiftAttemptConfig] sequence %s must name its lift", liftName)
	)
	assert(
		typeof(sequence.displayName) == "string" and sequence.displayName ~= "",
		string.format("[LiftAttemptConfig] sequence %s must have a displayName", liftName)
	)
	assert(
		typeof(sequence.phases) == "table" and #sequence.phases > 0,
		string.format("[LiftAttemptConfig] sequence %s must list at least one phase", liftName)
	)

	for index, phase in ipairs(sequence.phases) do
		if phase.kind == "Control" then
			assert(
				ControlPhaseConfig.Phases[phase.phaseName] ~= nil,
				string.format(
					"[LiftAttemptConfig] %s phase %d names %q, which is not in ControlPhaseConfig.Phases",
					liftName,
					index,
					tostring(phase.phaseName)
				)
			)
		elseif phase.kind == "SkillCheck" then
			assert(
				SkillCheckConfig.Phases[phase.phaseName] ~= nil,
				string.format(
					"[LiftAttemptConfig] %s phase %d names %q, which is not in SkillCheckConfig.Phases",
					liftName,
					index,
					tostring(phase.phaseName)
				)
			)
		else
			error(string.format(
				"[LiftAttemptConfig] %s phase %d has unknown kind %q",
				liftName,
				index,
				tostring(phase.kind)
			))
		end
	end
end

assert(
	LiftAttemptConfig.MinimumAttemptPercent > 0
		and LiftAttemptConfig.MinimumAttemptPercent < LiftAttemptConfig.MaximumAttemptPercent,
	"[LiftAttemptConfig] attempt percentage bounds are inverted"
)

return LiftAttemptConfig
