--!strict
--[[
	WeightClass
	Shared / Progression

	Resolves a bodyweight into a competition weight class.

	Per GAME_DESIGN.md Group B / Q9, bodyweight is a strategic decision rather
	than something that drifts upward with time, and the player's CURRENT
	bodyweight is what determines their current class. This module is the single
	place that conversion happens, so meets, records and progression all agree.
]]

local WeightClassConfig = require(script.Parent.Parent.Config.WeightClassConfig)

local WeightClass = {}

export type ResolvedWeightClass = {
	-- Position in the class list, 1 being the lightest.
	index: number,
	-- Shown to the player, e.g. "83 kg".
	label: string,
	-- Upper bound in kg, or nil for the unlimited top class.
	maximumBodyweight: number?,
}

--[[
	Returns the weight class a given bodyweight competes in.

	A lifter belongs to the first class whose maximum their bodyweight does not
	exceed, so 83.0 kg is an 83 kg lifter and 83.1 kg is a 93 kg lifter.
]]
function WeightClass.resolve(bodyweightKg: number): ResolvedWeightClass
	assert(
		typeof(bodyweightKg) == "number" and bodyweightKg > 0,
		"[WeightClass] bodyweight must be a number above 0"
	)

	for index, class in ipairs(WeightClassConfig.Classes) do
		local maximum = class.maximumBodyweight
		if maximum == nil or bodyweightKg <= maximum then
			return {
				index = index,
				label = class.label,
				maximumBodyweight = maximum,
			}
		end
	end

	-- Unreachable while the config's final class is unlimited, which it validates.
	error("[WeightClass] no class matched bodyweight " .. tostring(bodyweightKg))
end

--[[
	How many kg the lifter can still gain before moving up a class.

	Returns nil when already in the unlimited top class. Useful for the bulk /
	maintain / cut decision described in Q9: a player sitting 0.4 kg under a
	threshold is making a very different choice from one sitting 8 kg under it.
]]
function WeightClass.headroomToNextClass(bodyweightKg: number): number?
	local current = WeightClass.resolve(bodyweightKg)
	local maximum = current.maximumBodyweight
	if maximum == nil then
		return nil
	end
	return maximum - bodyweightKg
end

--[[
	The class immediately above the lifter's current one, or nil if already top.
]]
function WeightClass.nextClassAbove(bodyweightKg: number): ResolvedWeightClass?
	local current = WeightClass.resolve(bodyweightKg)
	local nextDefinition = WeightClassConfig.Classes[current.index + 1]
	if nextDefinition == nil then
		return nil
	end
	return {
		index = current.index + 1,
		label = nextDefinition.label,
		maximumBodyweight = nextDefinition.maximumBodyweight,
	}
end

return WeightClass
