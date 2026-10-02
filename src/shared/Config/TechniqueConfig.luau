--!strict
--[[
	TechniqueConfig
	Shared / Config

	Turns a RAW technique stat into an EFFECTIVE technique value.

	Raw technique stats (Squat Control, Depth Awareness, Start Control,
	Press Power, Lockout, and any technique stat added later) are UNBOUNDED.
	They can climb forever. There is no 0-100 cap on the raw number.

	Before a raw stat is allowed to touch a minigame it passes through this
	diminishing-returns curve. That is what lets raw stats reach absurd values
	without a player's execution ever becoming automatic.

	Design anchors (from GAME_DESIGN.md Group A / Q1):

		raw        effective
		      0 ->    10
		    100 ->    15
		    250 ->    22
		    500 ->    30
		  1,000 ->    40
		  2,500 ->    55
		  5,000 ->    70
		 10,000 ->    82
		 25,000 ->    92
		100,000 ->    98

	Past 100,000 the value keeps creeping toward the tail ceiling but never
	reaches it, so there is always some execution left for the player to fail.

	These are balancing anchors, NOT permanent constants. Retune them here.
]]

local Curve = require(script.Parent.Parent.Util.Curve)

local TechniqueConfig = {}

--[[
	Log space is used because the anchors span 0 to 100,000. In linear space the
	huge gap between 25,000 and 100,000 would flatten the whole early curve.
]]
local effectivenessCurve: Curve.Curve = {
	space = "log",
	anchors = {
		{ x = 0, y = 10 },
		{ x = 100, y = 15 },
		{ x = 250, y = 22 },
		{ x = 500, y = 30 },
		{ x = 1000, y = 40 },
		{ x = 2500, y = 55 },
		{ x = 5000, y = 70 },
		{ x = 10000, y = 82 },
		{ x = 25000, y = 92 },
		{ x = 100000, y = 98 },
	},

	--[[
		NOTE: these two tail numbers were NOT specified in the design doc.
		GAME_DESIGN.md says only "approaches 100 but should never make a minigame
		completely automatic", so a ceiling just under 100 was chosen to satisfy
		that. Resulting values: 250k -> 98.8, 1m -> 99.3, 10m -> 99.5.
		Adjust freely during playtesting.
	]]
	tail = {
		ceiling = 99.5,
		rate = 0.9,
	},
}

Curve.validate(effectivenessCurve, "TechniqueConfig.EffectivenessCurve")

TechniqueConfig.EffectivenessCurve = effectivenessCurve

return TechniqueConfig
