--!strict
--[[
	WeightClassConfig
	Shared / Config

	The competition weight classes, taken directly from GAME_DESIGN.md section 13:

		59, 66, 74, 83, 93, 105, 120, 120+

	Each class is an UPPER bound: a lifter belongs to the first class whose
	maximum their bodyweight does not exceed. So 58.0 kg and 59.0 kg are both
	59 kg lifters, while 59.1 kg is a 66 kg lifter.

	The final class has no maximum, which is what "120+" means.

	NOTE FOR DESIGN: GAME_DESIGN.md lists one single set of classes and does not
	split them by gender or division. This module therefore has one list. If
	separate men's/women's or equipped/raw divisions are wanted later, this is
	where that branch goes.
]]

local WeightClassConfig = {}

export type WeightClassDefinition = {
	-- Shown to the player.
	label: string,
	-- Highest bodyweight in kg that still belongs to this class.
	-- Absent means unlimited, which is only valid on the final class.
	maximumBodyweight: number?,
}

local classes: { WeightClassDefinition } = {
	{ label = "59 kg", maximumBodyweight = 59 },
	{ label = "66 kg", maximumBodyweight = 66 },
	{ label = "74 kg", maximumBodyweight = 74 },
	{ label = "83 kg", maximumBodyweight = 83 },
	{ label = "93 kg", maximumBodyweight = 93 },
	{ label = "105 kg", maximumBodyweight = 105 },
	{ label = "120 kg", maximumBodyweight = 120 },
	-- Unlimited: no maximumBodyweight.
	{ label = "120+ kg" },
}

-- Fail loudly at startup if this list is ever edited into an invalid shape.
do
	assert(#classes >= 1, "[WeightClassConfig] needs at least one class")

	local previousMaximum = 0
	for index, class in ipairs(classes) do
		local isFinal = index == #classes
		local maximum = class.maximumBodyweight

		if isFinal then
			assert(
				maximum == nil,
				"[WeightClassConfig] the final class must be unlimited (no maximumBodyweight)"
			)
		else
			assert(
				maximum ~= nil,
				string.format("[WeightClassConfig] class %d (%s) must have a maximumBodyweight", index, class.label)
			)
			assert(
				(maximum :: number) > previousMaximum,
				string.format("[WeightClassConfig] class maximums must ascend (%s breaks this)", class.label)
			)
			previousMaximum = maximum :: number
		end
	end
end

WeightClassConfig.Classes = classes

return WeightClassConfig
