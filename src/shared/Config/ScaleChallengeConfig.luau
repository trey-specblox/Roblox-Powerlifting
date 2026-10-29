--!strict
--[[
	ScaleChallengeConfig
	Shared / Config

	The numbers of the Competition Scale challenge modifier (GAME_DESIGN.md
	section 33.4, approved by the user 2026-10-29, checkpoint 6).

	A meet attempt above the weight a lifter has PROVEN in competition (their
	Competition Scale for that lift) carries a few extra base-difficulty points:
	their training says they can lift it, but they have never done it under
	pressure. The points are added AFTER the IntensityConfig curve, so the curve
	is never fed the Scale ratio (section 33.4's frozen rule).

		ratio = attempt weight / Competition Scale

		ratio <= 1.00          ->  +0 (at or below proven: neutral, no easing)
		1.00 .. FullRatio      ->  rises evenly
		ratio >= FullRatio     ->  +MaxBonus (the cap)
		unproven (Scale 0)     ->  +UnprovenBonus

	Meet attempts only; practice and training lifts never carry it.

	STATUS: the shape is decided, the values are PROVISIONAL balance.
]]

local ScaleChallengeConfig = {}

-- The cap, in base-difficulty points on the shared 0-100 scale. A 100% attempt is
-- difficulty 65 and a 110% one 95, so +10 feels like about 3% more on the bar.
ScaleChallengeConfig.MaxBonus = 10

-- The attempt-to-Scale ratio at which the bonus reaches the cap.
ScaleChallengeConfig.FullRatio = 1.5

-- A lift never made in a meet carries the full cap: the first meet is the most pressure.
ScaleChallengeConfig.UnprovenBonus = ScaleChallengeConfig.MaxBonus

assert(
	ScaleChallengeConfig.MaxBonus > 0 and ScaleChallengeConfig.MaxBonus <= 15,
	"[ScaleChallengeConfig] MaxBonus must stay moderate (section 33.4: never dominate physical difficulty)"
)
assert(ScaleChallengeConfig.FullRatio > 1, "[ScaleChallengeConfig] FullRatio must be above 1")
assert(
	ScaleChallengeConfig.UnprovenBonus >= 0 and ScaleChallengeConfig.UnprovenBonus <= ScaleChallengeConfig.MaxBonus,
	"[ScaleChallengeConfig] UnprovenBonus must lie within 0..MaxBonus"
)

return ScaleChallengeConfig
