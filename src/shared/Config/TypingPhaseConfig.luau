--!strict
--[[
	TypingPhaseConfig
	Shared / Config

	Every balance number for the Deadlift's typing pull.

	Reference: References/TypingGame.md.

	THE MECHANIC

	A vertical bar rises from the floor toward lockout. One authoritative progress
	value drives its height, and reaching the top completes the phase.

	The player types short powerlifting cues, ONE CHARACTER AT A TIME. The current
	required character is shown very large; the cue it belongs to is shown beneath
	it as spaced letters so a fluent player can read ahead. Each correct character
	raises the bar. The bar sags continuously, so hesitation costs height.

		correct token  -> progress += progressPerToken
		wrong token    -> progress -= mistakePenalty (no stall; every key is processed)
		no input       -> progress -= sagPerSecond, continuously

		progress >= completionThreshold -> PASSED, terminal
		budget expires                  -> NO LIFT

	ONE COMPLETION CONDITION

	The value that drives the bar's height is the value the pass is tested against.
	The bar reaching lockout IS the pass. There is deliberately no second
	requirement behind a visually completed bar.

	=========================================================================
	STATUS: PROVISIONAL. NOT FINAL BALANCE. DO NOT TREAT AS SETTLED.
	=========================================================================

	WHY THIS IS NOT A TYPING-SPEED TEST

	The required rate band was fixed FIRST and everything else derived beneath it:

		80% 1.59/s    90% 1.96/s    100% 2.40/s    105% 2.76/s    110% 3.00/s
		   19 WPM        24 WPM         29 WPM         33 WPM         36 WPM

	Average adult typing is around 40 WPM and a slow typist manages 20, so even a
	110% pull sits under what a modest typist can do. Difficulty is expressed
	through the CHARACTER COUNT (9 at 80%, 24 at 110%), the sag rate and the cost
	of a mistake -- not through speed, which barely moves.

		required tokens/sec = (sag + completionThreshold / activeSeconds)
		                      / progressPerToken

	DO NOT RAISE THE TOP-END REQUIRED RATE. If character-first reading makes 110%
	feel too demanding in play, the approved levers are the WINDOW and the SAG, not
	a faster required rate.

	PULLSTRENGTH SUBSTITUTES FOR TYPING ABILITY

	A trained lifter needs FEWER keystrokes, not faster ones. At a 110% pull:

		PullStrength      0  ->  24 characters at 36 WPM
		PullStrength 10,000  ->  18 characters at 24 WPM
		PullStrength max     ->  17 characters at 22 WPM

	It never becomes automatic: seventeen characters still have to be typed
	correctly against a live sag, and PullStrength never touches the bar target,
	the time window or the cue content.
]]

local Curve = require(script.Parent.Parent.Util.Curve)
local ParameterMapper = require(script.Parent.Parent.Difficulty.ParameterMapper)

local TypingPhaseConfig = {}

-- Progress bounds. The bar starts on the floor.
TypingPhaseConfig.ProgressMax = 100
TypingPhaseConfig.StartingProgress = 0

--[[
	=========================================================================
	THERE IS NO PER-KEY RATE LIMIT ANYWHERE. THIS IS DELIBERATE.
	=========================================================================

	An earlier version discarded any token arriving less than 1/12 second after the
	previous one, mirroring the Bench's click cap. That was the wrong model for
	typing and it broke normal play.

	A typist's AVERAGE rate is modest, but the gap between ADJACENT keystrokes is
	wildly variable. Rolled digraphs -- the LL in PULL, the BR in BRACE, the HI in
	CHIN -- land at roughly a third of the average gap:

		 40 WPM  ->  300ms average, ~105ms rolled
		 60 WPM  ->  200ms average,  ~70ms rolled   <- under 83ms, DISCARDED
		100 WPM  ->  120ms average,  ~42ms rolled   <- under 83ms, DISCARDED

	So from about 50 WPM upward, legitimate keystrokes were being dropped on the
	client (the letter visibly did nothing) and again on the server. Anti-cheat
	must not punish a fast typist, and that cap did exactly that.

	Removing it costs nothing in security, because the cap was never what protected
	this phase:

		- a token only earns progress if it MATCHES the expected one, and the
		  server owns the expected sequence
		- a wrong token COSTS progress, so flooding tokens is actively harmful
		- payload size is bounded by the length cap below
		- the wall-clock check still rejects a phase reported faster than it
		  could have been played

	A flood of tokens cannot help a cheater and could only ever hurt an honest
	player, so there is nothing left for a per-key limit to do.

	This value now sizes the PAYLOAD LENGTH CAP and nothing else. It is set far
	above any human rate -- 25 tokens per second is around 300 WPM -- so it bounds
	memory and loop cost without being reachable by play.
]]
TypingPhaseConfig.MaxAverageTokensPerSecond = 25

--[[
	Fixed simulation timestep, identical on both sides. The server replays the
	player's reported tokens to decide the result, so a variable frame delta would
	let the two disagree.
]]
TypingPhaseConfig.FixedTimestepSeconds = 1 / 60

--[[
	How far a client's reported timings may disagree with the server's own
	measurement of elapsed time before the attempt is rejected.
]]
TypingPhaseConfig.TimingToleranceSeconds = 1.5

--[[
	=========================================================================
	THERE IS NO MISTAKE STALL EITHER. ALSO DELIBERATE.
	=========================================================================

	An earlier version ignored all input for 0.12 seconds after a wrong token. It
	was introduced as the anti-mash guard, and it was both unnecessary and actively
	harmful.

	HARMFUL: typing BRQCE while aiming for BRACE went

		B  correct
		R  correct
		Q  wrong, penalty, stall opens
		C  DISCARDED
		E  DISCARDED

	Two real keystrokes vanished with no feedback at all. One fumbled key threw
	away the next two, which is exactly how input feels broken.

	UNNECESSARY: the progress penalty was always the real guard. Mashing at ten
	keys a second lands roughly one correct key in twenty-six, so per second it
	gains one correct character and pays for twenty-five wrong ones:

		 80%:  +1.5 gained,  -19.2 lost  =  -17.7 progress/sec
		100%:  +1.5 gained,  -38.5 lost  =  -36.9 progress/sec
		110%:  +1.5 gained,  -57.7 lost  =  -56.2 progress/sec

	Mashing drives the bar to the floor and pins it there. The stall contributed
	nothing to that and only ever cost honest players characters.

	So a wrong token now costs progress and nothing else. Every keystroke is
	processed, always, which is what makes the controls feel responsive.
]]

--[[
	How much more cue text is generated than the pull should need.

	Cues are not a script to be finished -- completion is by PROGRESS -- so this is
	pure headroom. It exists so a player who makes mistakes, or who is fighting the
	sag, never runs out of characters to type. Running dry would produce exactly
	the "I did everything and still failed" state this design exists to avoid.
]]
TypingPhaseConfig.CueHeadroomMultiplier = 2.5

local function linear(anchors: { Curve.Anchor }): Curve.Curve
	return {
		space = "linear",
		anchors = anchors,
	}
end

--[[
	The shared profile. PROVISIONAL.

	Resulting experience at PullStrength 0:

		attempt  diff  target  window  sag  miss | chars | required |  WPM
		    80%    32      35     8.0  2.0   2.0 |     9 |  1.59/s  |   19
		    90%    45      50     9.0  2.3   2.8 |    13 |  1.96/s  |   24
		   100%    65      70    10.0  2.6   4.0 |    18 |  2.40/s  |   29
		   105%    80      85    11.0  3.3   5.0 |    22 |  2.76/s  |   33
		   110%    95      95    12.0  4.1   6.0 |    24 |  3.00/s  |   36
]]
local defaultProfile: ParameterMapper.MinigameSpec = {
	--[[
		Progress that completes the phase, and the height the bar has to reach.

		NOTE: no fromTechnique curve, deliberately. Together with the window, this is
		what keeps the pull from becoming automatic however trained the lifter is.
	]]
	completionThreshold = {
		fromDifficulty = linear({
			{ x = 0, y = 20 },
			{ x = 20, y = 30 },
			{ x = 32, y = 35 },
			{ x = 45, y = 50 },
			{ x = 65, y = 70 },
			{ x = 80, y = 85 },
			{ x = 95, y = 95 },
			{ x = 100, y = 98 },
		}),
		minimum = 5,
		maximum = 100,
	},

	--[[
		Wall-clock seconds available. A TIMEOUT, not a target: passing is terminal, so
		a competent pull finishes well inside it.

		Longer than the Bench's windows because typing is slower than clicking, and
		because reading a character costs time a click does not.
	]]
	duration = {
		fromDifficulty = linear({
			{ x = 0, y = 6.5 },
			{ x = 32, y = 8.0 },
			{ x = 45, y = 9.0 },
			{ x = 65, y = 10.0 },
			{ x = 80, y = 11.0 },
			{ x = 95, y = 12.0 },
			{ x = 100, y = 12.4 },
		}),
		minimum = 3.0,
	},

	--[[
		Progress lost per second, continuously. The bar sagging back toward the floor.

		Deliberately gentle compared with the Bench's decay, because reading the next
		character is a legitimate pause that clicking does not have. Sag divided by
		progressPerToken is the rate below which the bar falls instead of rising.
	]]
	sagPerSecond = {
		fromDifficulty = linear({
			{ x = 0, y = 1.5 },
			{ x = 32, y = 2.0 },
			{ x = 45, y = 2.3 },
			{ x = 65, y = 2.6 },
			{ x = 80, y = 3.3 },
			{ x = 95, y = 4.1 },
			{ x = 100, y = 4.4 },
		}),
		fromTechnique = linear({
			{ x = 10, y = 1.00 },
			{ x = 30, y = 0.92 },
			{ x = 55, y = 0.82 },
			{ x = 82, y = 0.70 },
			{ x = 99.5, y = 0.62 },
		}),
		minimum = 0.4,
	},

	--[[
		Progress added by one correct token.

		Flat across difficulty on purpose: a heavier bar does not make a keystroke
		worth less, it makes the climb longer and the sag faster.

		PullStrength raises it, which is how a trained lifter needs FEWER keystrokes
		rather than faster ones. This is the single most important curve in the file.
	]]
	progressPerToken = {
		fromDifficulty = linear({
			{ x = 0, y = 4.0 },
			{ x = 100, y = 4.0 },
		}),
		fromTechnique = linear({
			{ x = 10, y = 1.00 },
			{ x = 30, y = 1.10 },
			{ x = 55, y = 1.22 },
			{ x = 82, y = 1.35 },
			{ x = 99.5, y = 1.45 },
		}),
		minimum = 0.5,
	},

	--[[
		Progress lost for a wrong token.

		At a 100% pull this is 4.0, exactly one correct character's gain, so a mistake
		costs the character you just earned. At 110% it is one and a half.

		PullStrength softens it.
	]]
	mistakePenalty = {
		fromDifficulty = linear({
			{ x = 0, y = 1.5 },
			{ x = 32, y = 2.0 },
			{ x = 65, y = 4.0 },
			{ x = 95, y = 6.0 },
			{ x = 100, y = 6.4 },
		}),
		fromTechnique = linear({
			{ x = 10, y = 1.00 },
			{ x = 30, y = 0.92 },
			{ x = 55, y = 0.82 },
			{ x = 82, y = 0.70 },
			{ x = 99.5, y = 0.62 },
		}),
		minimum = 0.5,
	},
}

TypingPhaseConfig.Profiles = {
	Default = defaultProfile,
}

--[[
	EVERYTHING LIFT-SPECIFIC ABOUT A TYPING PHASE LIVES HERE.

	Only the deadlift uses this mechanic. Squat uses the Fisch-style control phase
	and Bench uses Test Your Might, so this table has one entry and is expected to
	keep having one.
]]
TypingPhaseConfig.Phases = {
	DeadliftPull = {
		lift = "Deadlift",
		techniqueStat = "PullStrength",
		profile = "Default",
		displayName = "PULL",
		--[[
			Only two outcomes exist. A mistake cannot end the phase and an empty bar is
			not a loss, so running out of time is the single way to fail.
		]]
		verdicts = {
			pass = "BAR AT LOCKOUT",
			failTimeout = "NO LIFT - BAR DIED",
		},
	},
}

-- Fail at startup rather than mid-lift if a balancing table is malformed.
for profileName, profile in pairs(TypingPhaseConfig.Profiles) do
	ParameterMapper.validate(profile, "TypingPhaseConfig.Profiles." .. profileName)
end

for phaseName, phase in pairs(TypingPhaseConfig.Phases) do
	assert(
		TypingPhaseConfig.Profiles[phase.profile] ~= nil,
		string.format("[TypingPhaseConfig] phase %s points at unknown profile %q", phaseName, phase.profile)
	)
	assert(
		typeof(phase.lift) == "string" and phase.lift ~= "",
		string.format("[TypingPhaseConfig] phase %s must name the lift it reads", phaseName)
	)
	assert(
		typeof(phase.techniqueStat) == "string" and phase.techniqueStat ~= "",
		string.format("[TypingPhaseConfig] phase %s must name its technique stat", phaseName)
	)
	assert(
		typeof(phase.displayName) == "string" and phase.displayName ~= "",
		string.format("[TypingPhaseConfig] phase %s must have a displayName", phaseName)
	)

	for _, key in ipairs({ "pass", "failTimeout" }) do
		assert(
			typeof(phase.verdicts) == "table" and typeof(phase.verdicts[key]) == "string",
			string.format("[TypingPhaseConfig] phase %s is missing its %q verdict wording", phaseName, key)
		)
	end
end

assert(
	TypingPhaseConfig.StartingProgress >= 0
		and TypingPhaseConfig.StartingProgress < TypingPhaseConfig.ProgressMax,
	"[TypingPhaseConfig] StartingProgress must sit below ProgressMax"
)
assert(
	TypingPhaseConfig.MaxAverageTokensPerSecond > 0,
	"[TypingPhaseConfig] MaxAverageTokensPerSecond must be above 0"
)
assert(
	TypingPhaseConfig.CueHeadroomMultiplier >= 1,
	--[[
		Below 1 the generated cues would be shorter than the pull needs, which could
		leave a player with nothing left to type and no way to finish. That is exactly
		the failure this design is built to make impossible.
	]]
	"[TypingPhaseConfig] cue headroom below 1 could leave a pull unfinishable"
)

return TypingPhaseConfig
