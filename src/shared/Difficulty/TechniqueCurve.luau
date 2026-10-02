--!strict
--[[
	TechniqueCurve
	Shared / Difficulty

	The single place where a raw technique stat becomes an effective one.

	Gameplay code must never read a raw technique stat directly. Always route it
	through here, so the diminishing-returns curve can never be bypassed or
	accidentally reimplemented somewhere else.
]]

local TechniqueConfig = require(script.Parent.Parent.Config.TechniqueConfig)
local Curve = require(script.Parent.Parent.Util.Curve)

local TechniqueCurve = {}

--[[
	Converts an unbounded raw technique stat into an effective value
	(roughly 10 at zero, approaching but never reaching 100).

	raw: the stored stat value, 0 or higher
]]
function TechniqueCurve.toEffective(raw: number): number
	assert(
		typeof(raw) == "number" and raw >= 0,
		"[TechniqueCurve] raw technique stat must be a number of 0 or higher"
	)
	return Curve.evaluate(TechniqueConfig.EffectivenessCurve, raw)
end

--[[
	The highest effective technique the curve can ever produce.

	Exposed so the modifier system can clamp against it: no amount of equipment,
	coaching or height advantage may push effective technique past this, which is
	what keeps execution from becoming automatic (Q1).
]]
function TechniqueCurve.ceiling(): number
	local tail = TechniqueConfig.EffectivenessCurve.tail
	if tail then
		return tail.ceiling
	end
	local anchors = TechniqueConfig.EffectivenessCurve.anchors
	return anchors[#anchors].y
end

return TechniqueCurve
