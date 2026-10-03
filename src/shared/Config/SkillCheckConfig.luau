--!strict
--[[
	SkillCheckConfig
	Shared / Config

	Every balance number for the reusable timing Skill Check.

	Reference: References/DBD.md. A needle sweeps clockwise around a circle from
	12 o'clock. There is ONE target zone on the ring. The player presses once as
	the needle's tip crosses it.

	Inside the zone is a successful execution; outside it, or too early, is a
	failure. There is no second zone and no graded tier above success.

	THE SAME SYSTEM SERVES THREE PHASES

	Squat Depth, Bench Press and Deadlift Lockout are the same mechanic with
	different numbers and different driving stats. They therefore share one
	profile of curves rather than holding three copies that would have to be
	edited in parallel. A phase can be given its own profile later by adding one
	to Profiles and pointing at it from Phases.

	HOW A PARAMETER IS BUILT

	Each parameter has two curves, per the rule in ParameterMapper:

		fromDifficulty  the value for an UNTRAINED lifter at that difficulty
		fromTechnique   a multiplier applied on top, 1.00 at effective 10

	Technique is never subtracted from difficulty. Every fromDifficulty curve
	below is therefore exactly what a brand-new lifter experiences, which makes
	"is low technique still playable?" directly readable from the tables.

	WHY THE TECHNIQUE MULTIPLIERS LOOK LINEAR

	They are near-linear in EFFECTIVE technique on purpose. Diminishing returns
	already live in the raw-to-effective curve in TechniqueConfig. Curving these
	as well would compound the two and make training feel worthless at high
	levels. In raw terms the result is properly diminishing: raw 0 to 500 buys
	+17% zone, while raw 10,000 to 100,000 (nine times the training) buys +10%.

	UNITS

	Degrees and degrees per second, not pixels. GAME_DESIGN.md's px/sec anchors
	belong to the Squat Control minigame, which is a different linear mechanic.
	Angular units are resolution-independent and survive any UI resize.

	=========================================================================
	STATUS: PROVISIONAL. NOT FINAL BALANCE. DO NOT TREAT AS SETTLED.
	=========================================================================

	Every number in this file is a temporary playtest value. The current baseline
	is a 90 ms hit window on a 100% attempt at raw technique 0, reached over four
	tuning passes recorded in the comments on each curve.

	Difficulty tuning is deliberately PAUSED here, and paused for a reason rather
	than because it felt right. Squat Depth is currently judged in isolation: it
	is the second phase of a squat whose first phase (Squat Control) does not
	exist yet, and none of the modifier sources that are meant to feed it --
	equipment, height and leverages, coaches, origins -- are implemented, so the
	modifier set it resolves against is always empty.

	Judging a timing check on its own therefore says little about how the complete
	attempt will feel. Re-evaluate once Squat Control and Squat Depth run as one
	continuous squat and real stats and modifiers are influencing the result.

	Everything needed to retune lives in this file: no gameplay script contains a
	balance number, and each curve carries its previous tables for reverting.
]]

local Curve = require(script.Parent.Parent.Util.Curve)
local ParameterMapper = require(script.Parent.Parent.Difficulty.ParameterMapper)

local SkillCheckConfig = {}

--[[
	Total arc budget for one sweep: lead distance plus target zone must fit
	inside this, leaving headroom before a full 360 so the needle can never wrap
	past the zone before the player can react.

	This constraint is real. Without it the raw tables overflowed to 371 degrees
	at low difficulty with trained technique, which would have drawn a zone
	overlapping the needle's start.
]]
SkillCheckConfig.SweepBudgetDegrees = 345

--[[
	Random variation applied to lead time, so players cannot learn one fixed
	rhythm. The lead cap reserves room for this, so a +10% roll always still fits
	inside the sweep budget.
]]
SkillCheckConfig.LeadJitter = 0.10


--[[
	Bounds on what a client may request as an attempt percentage of their
	forecasted max. The server derives the actual weight, so this is the only
	number the client gets to influence.

	The ceiling sits above 110% so players can attempt a genuine PR, while
	refusing an absurd request that would resolve to difficulty 100 instantly.
]]
SkillCheckConfig.MinimumAttemptPercent = 0.40
SkillCheckConfig.MaximumAttemptPercent = 1.25

--[[
	How far a client's reported press time may disagree with the server's own
	measurement before it is rejected. Covers network latency.

	Read the honest limits of this in SquatDepthService.
]]
SkillCheckConfig.PressTimeToleranceSeconds = 1.0

--[[
	Verdict wording lives on each PHASE, not here.

	It has to. "NO LIFT - HIGH SQUAT" is meaningless for a bench press, so a single
	shared set would guarantee that the second phase built announces squat
	failures. See the verdicts field on each entry in Phases below.
]]

local function linear(anchors: { Curve.Anchor }): Curve.Curve
	return {
		space = "linear",
		anchors = anchors,
	}
end

--[[
	The shared profile. PROVISIONAL playtest values; see the status note at the top
	of this file before treating any of them as settled.

	Resulting hit windows, in milliseconds the needle spends inside the target:

		difficulty   attempt   untrained   raw 2.5k   raw 100k
		        20       67%      229 ms       393        658
		        35       82%      179 ms       306        513
		        50     92.5%      133 ms       227        381
		        65      100%       90 ms       153        256
		        80      105%       64 ms       110        185
		        95      110%       39 ms        66        110

	Pass 4 held these windows and raised needle speed instead, so the numbers above
	are near-identical to pass 3 by design. What changed is the speed the needle
	crosses the target at: 330 to 500 deg/s on a 100% attempt.

	For calibration: a practised player times to roughly 40-60 ms, an average one
	80-120 ms, and visual reaction time is about 250 ms.
]]
local defaultProfile: ParameterMapper.MinigameSpec = {
	-- Degrees per second the needle travels.
	needleSpeed = {
		--[[
			PLAYTEST PASS 4. Three passes of shrinking the target did not make the
			check feel harder, because the limiting factor was not the window size
			but how PREDICTABLE a slow needle is: there is ample time to track it
			and anticipate the zone.

			So this pass raises speed substantially and widens the target to
			compensate, holding the hit window at the same 90 ms. The check should
			now demand reaction rather than patience.

			The curve is re-shaped rather than scaled: the low end moves only a
			little, so warmups stay readable, while the top end climbs steeply.

			Previous table:
				0:150  10:175  20:200  35:240  50:280  65:330  80:390  90:440  100:520
		]]
		fromDifficulty = linear({
			{ x = 0, y = 170 },
			{ x = 10, y = 200 },
			{ x = 20, y = 240 },
			{ x = 35, y = 305 },
			{ x = 50, y = 400 },
			{ x = 65, y = 500 },
			{ x = 80, y = 585 },
			{ x = 90, y = 645 },
			{ x = 100, y = 715 },
		}),
		-- Below 1.0: better technique slows the needle down.
		fromTechnique = linear({
			{ x = 10, y = 1.00 },
			{ x = 20, y = 0.96 },
			{ x = 30, y = 0.92 },
			{ x = 40, y = 0.88 },
			{ x = 55, y = 0.82 },
			{ x = 70, y = 0.75 },
			{ x = 82, y = 0.70 },
			{ x = 92, y = 0.66 },
			{ x = 99.5, y = 0.62 },
		}),
		-- Never so slow that the check stops being a timing test.
		minimum = 80,
	},

	-- Arc of the single target zone, in degrees. This is the whole target: inside
	-- it the execution succeeds, outside it fails.
	targetArc = {
		--[[
			PLAYTEST PASS 4. Every value here is DERIVED, not chosen: it is the
			target window multiplied by the new needle speed at that difficulty.

				arc = window x speed      e.g. 0.090 s x 500 deg/s = 45 degrees

			The windows are deliberately identical to pass 3, so this pass changes
			only how fast the needle crosses the target, never how long the player
			has inside it:

				diff    0   10   20   35   50   65   80   90  100
				window 335  280  229  179  133   90   64   48   31   ms

			Note the target is now WIDER than pass 3 (45 degrees at difficulty 65
			rather than 29.7) while being harder to hit, because the needle crosses
			it half again as fast. A bigger-looking zone is not a softer one.

			History, for reverting:
				pass 1   0:90  10:88  20:84  35:77  50:67  65:53   80:45  90:37  100:29
				pass 2   0:67  10:66  20:63  35:58  50:50  65:40   80:34  90:28  100:22
				pass 3   0:50  10:49  20:46  35:43  50:37  65:29.7 80:25  90:21  100:16
		]]
		fromDifficulty = linear({
			{ x = 0, y = 57 },
			{ x = 10, y = 56 },
			{ x = 20, y = 55 },
			{ x = 35, y = 54.5 },
			{ x = 50, y = 53 },
			{ x = 65, y = 45 },
			{ x = 80, y = 37.5 },
			{ x = 90, y = 31 },
			{ x = 100, y = 22 },
		}),
		--[[
			Above 1.0: better technique widens the zone. The 1.80 ceiling is a
			deliberate design decision. At 2.20 a maxed lifter got 556 ms on a
			100% attempt, which was comfortable enough to stop demanding
			attention. At 1.80 the same attempt gives 456 ms: meaningfully easier
			than the 161 ms an untrained lifter faces, but still a press that can
			be fumbled.
		]]
		fromTechnique = linear({
			{ x = 10, y = 1.00 },
			{ x = 20, y = 1.08 },
			{ x = 30, y = 1.17 },
			{ x = 40, y = 1.25 },
			{ x = 55, y = 1.39 },
			{ x = 70, y = 1.52 },
			{ x = 82, y = 1.63 },
			{ x = 92, y = 1.72 },
			{ x = 99.5, y = 1.80 },
		}),
		minimum = 8,
		-- Keeps room in the sweep budget for the lead distance.
		maximum = 150,
	},

	--[[
		Lead time: seconds of warning between the check appearing and the needle
		reaching the target zone. This is what "reaction window" means here, per
		the DBD reference. There is no separate hidden input-grace mechanic.
	]]
	reactionWindow = {
		--[[
			PLAYTEST PASS 4. Lowered because the faster needle made the old values
			geometrically impossible, not as a balance choice.

			At 500 deg/s one full lap takes 0.720 s. The old 0.70 s of lead needed
			350 degrees of travel, but only 273 are available once a 45 degree zone
			and the jitter reserve are subtracted from the 345 degree budget. The
			lead clamp would have silently cut it to 0.545 s, and worse, the clamp
			would then have pinned lead to the cap everywhere above difficulty ~50,
			making this entire curve a dead knob.

			These values fit inside the geometry instead, so the curve stays live.
			Verified: an untrained lifter is never clamped at any difficulty, so the
			baseline gets exactly what is configured here. Trained lifters lose at
			most ~9% of their lead to the cap, which on a 1.37 s warmup warning is
			imperceptible.

			Previous table:
				0:1.30  20:1.10  50:0.85  65:0.70  80:0.58  90:0.50  100:0.42
		]]
		fromDifficulty = linear({
			{ x = 0, y = 1.30 },
			{ x = 20, y = 1.05 },
			{ x = 50, y = 0.62 },
			{ x = 65, y = 0.52 },
			{ x = 80, y = 0.45 },
			{ x = 90, y = 0.42 },
			{ x = 100, y = 0.39 },
		}),
		fromTechnique = linear({
			{ x = 10, y = 1.00 },
			{ x = 30, y = 1.15 },
			{ x = 55, y = 1.30 },
			{ x = 82, y = 1.42 },
			{ x = 99.5, y = 1.50 },
		}),
		--[[
			Never drop below human visual reaction time, or the check becomes a
			coin flip rather than a test of timing.
		]]
		minimum = 0.35,
	},
}

SkillCheckConfig.Profiles = {
	Default = defaultProfile,
}

--[[
	EVERYTHING LIFT-SPECIFIC ABOUT A SKILL CHECK LIVES HERE.

	This table is the single place a phase differs. The circular component, the
	needle, the zone rendering, the input handling, the grading and the server
	validation are all phase-agnostic and read what they need from this entry.

		lift           which forecasted max sets the intensity
		techniqueStat  which raw technique stat eases execution
		profile        which balancing curves to use
		displayName    the label shown in the middle of the circle
		verdicts       the wording for each outcome

	Adding Bench Press or Deadlift Lockout should therefore be an entry here plus
	an interaction point, not a new copy of the mechanic.

		BenchPress = {
			lift = "Bench",
			techniqueStat = "PressPower",
			profile = "Default",
			displayName = "PRESS",
			verdicts = { ... },
		}

	`lift` must match a key in PlayerProfileSchema.Forecasted and `techniqueStat`
	a key in PlayerProfileSchema.Technique.

	Only Squat Depth is implemented. The others are deliberately absent rather than
	stubbed, because their wording and balance have not been designed.
]]
SkillCheckConfig.Phases = {
	SquatDepth = {
		lift = "Squat",
		techniqueStat = "DepthAwareness",
		profile = "Default",
		displayName = "DEPTH",
		--[[
			GAME_DESIGN.md specifies that failing depth gives a high squat and red
			lights rather than the character collapsing. Placeholder copy.
		]]
		verdicts = {
			pass = "GOOD LIFT",
			early = "NO LIFT - HIGH SQUAT",
			late = "NO LIFT - MISSED DEPTH",
			noInput = "NO LIFT - NO ATTEMPT",
		},
	},
}

-- Fail at startup rather than mid-lift if a balancing table is malformed.
for profileName, profile in pairs(SkillCheckConfig.Profiles) do
	ParameterMapper.validate(profile, "SkillCheckConfig.Profiles." .. profileName)
end

--[[
	Every phase must supply its own complete wording. Falling back to a shared
	default is exactly how a bench press would end up announcing a high squat, so
	a missing verdict is an error rather than a silent substitution.
]]
for phaseName, phase in pairs(SkillCheckConfig.Phases) do
	assert(
		SkillCheckConfig.Profiles[phase.profile] ~= nil,
		string.format("[SkillCheckConfig] phase %s points at unknown profile %q", phaseName, phase.profile)
	)
	assert(
		typeof(phase.lift) == "string" and phase.lift ~= "",
		string.format("[SkillCheckConfig] phase %s must name the lift it reads", phaseName)
	)
	assert(
		typeof(phase.techniqueStat) == "string" and phase.techniqueStat ~= "",
		string.format("[SkillCheckConfig] phase %s must name its technique stat", phaseName)
	)
	assert(
		typeof(phase.displayName) == "string" and phase.displayName ~= "",
		string.format("[SkillCheckConfig] phase %s must have a displayName", phaseName)
	)

	for _, key in ipairs({ "pass", "early", "late", "noInput" }) do
		assert(
			typeof(phase.verdicts) == "table" and typeof(phase.verdicts[key]) == "string",
			string.format("[SkillCheckConfig] phase %s is missing its %q verdict wording", phaseName, key)
		)
	end
end

return SkillCheckConfig
