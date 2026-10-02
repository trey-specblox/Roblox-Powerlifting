--!strict
--[[
	IntensityConfig
	Shared / Config

	Turns PERSONAL INTENSITY into BASE (physical) DIFFICULTY.

		Personal Intensity = Attempt Weight / Forecasted Max

	Design anchors (from GAME_DESIGN.md Group A / Q2):

		intensity      base difficulty
		    50%   ->        10
		    60%   ->        15
		    70%   ->        22
		    80%   ->        32
		    90%   ->        45
		    95%   ->        55
		   100%   ->        65
		 102.5%   ->        72
		   105%   ->        80
		 107.5%   ->        88
		   110%   ->        95
		  >110%   ->   approaches 100

	The intent behind these numbers: a 100% attempt means "what this character is
	capable of", so it lands at 65 (hard, but realistically makeable if the player
	executes well) rather than near-impossible. Past the forecasted max the curve
	turns progressively nastier.

	Values between anchors are interpolated smoothly, never stepped.

	IMPORTANT: base difficulty is NOT reduced by the player's technique stat.
	Difficulty and effective technique stay separate inputs, and both are fed into
	each minigame's parameter mapping. See ParameterMapper.

	These are balancing anchors, NOT permanent constants. Retune them here.
]]

local Curve = require(script.Parent.Parent.Util.Curve)

local IntensityConfig = {}

local baseDifficultyCurve: Curve.Curve = {
	space = "linear",
	anchors = {
		{ x = 0.50, y = 10 },
		{ x = 0.60, y = 15 },
		{ x = 0.70, y = 22 },
		{ x = 0.80, y = 32 },
		{ x = 0.90, y = 45 },
		{ x = 0.95, y = 55 },
		{ x = 1.00, y = 65 },
		{ x = 1.025, y = 72 },
		{ x = 1.05, y = 80 },
		{ x = 1.075, y = 88 },
		{ x = 1.10, y = 95 },
	},

	--[[
		NOTE: this tail rate was NOT specified in the design doc. GAME_DESIGN.md
		says only that above 110% difficulty should "approach 100 with diminishing
		room remaining", so a rate was chosen to produce: 115% -> 96.8,
		120% -> 98.0, 130% -> 99.2. Adjust freely during playtesting.
	]]
	tail = {
		ceiling = 100,
		rate = 9.16,
	},
}

Curve.validate(baseDifficultyCurve, "IntensityConfig.BaseDifficultyCurve")

IntensityConfig.BaseDifficultyCurve = baseDifficultyCurve

--[[
	The shared difficulty vocabulary from GAME_DESIGN.md. Purely descriptive:
	these labels are for UI, logging and debugging. No gameplay math reads them.

	A band matches when difficulty is at or below its maxDifficulty.
]]
IntensityConfig.Classifications = {
	{ maxDifficulty = 10, label = "Extremely Easy" },
	{ maxDifficulty = 20, label = "Beginner" },
	{ maxDifficulty = 35, label = "Easy" },
	{ maxDifficulty = 50, label = "Moderate" },
	{ maxDifficulty = 65, label = "Hard" },
	{ maxDifficulty = 80, label = "Very Hard" },
	{ maxDifficulty = 90, label = "Expert" },
	{ maxDifficulty = 97, label = "Extremely Difficult" },
	{ maxDifficulty = 100, label = "Near Maximum" },
}

return IntensityConfig
