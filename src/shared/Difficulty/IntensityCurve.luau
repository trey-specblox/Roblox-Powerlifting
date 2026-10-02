--!strict
--[[
	IntensityCurve
	Shared / Difficulty

	The single place where personal intensity becomes base physical difficulty.
]]

local IntensityConfig = require(script.Parent.Parent.Config.IntensityConfig)
local Curve = require(script.Parent.Parent.Util.Curve)

local IntensityCurve = {}

--[[
	Converts personal intensity (attempt weight / forecasted max, so 1.0 = 100%)
	into base physical difficulty on the shared 0-100 scale.
]]
function IntensityCurve.toBaseDifficulty(intensity: number): number
	assert(
		typeof(intensity) == "number" and intensity >= 0,
		"[IntensityCurve] intensity must be a number of 0 or higher"
	)
	return Curve.evaluate(IntensityConfig.BaseDifficultyCurve, intensity)
end

--[[
	Returns the human-readable band for a difficulty value, for UI and debugging.
]]
function IntensityCurve.classify(difficulty: number): string
	for _, band in ipairs(IntensityConfig.Classifications) do
		if difficulty <= band.maxDifficulty then
			return band.label
		end
	end
	-- Only reachable if difficulty somehow exceeds the final band.
	return IntensityConfig.Classifications[#IntensityConfig.Classifications].label
end

return IntensityCurve
