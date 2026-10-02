--!strict
--[[
	ModifierChannel
	Shared / Modifiers

	The complete list of things a modifier is allowed to affect.

	A "channel" is a named quantity that outside systems may push on. Keeping this
	list short and explicit is what stops the modifier system turning into "any
	script can change any number", which is the failure mode GAME_DESIGN.md Q4
	warns about.

	Note what is deliberately ABSENT: there is no channel for Forecasted Max.
	Per Q4, equipment must never permanently alter the lifter's underlying
	capability. A belt makes a lift easier to execute; it does not make the lifter
	stronger. Because no channel exists, that rule cannot be broken by accident.
]]

local ModifierChannel = {}

--[[
	Adjusts effective technique for the phase being resolved, after the
	diminishing-returns curve has run. This is the main channel for equipment,
	height and coaches: knee sleeves make a squat easier to control without
	pretending the lifter trained more.

	Clamped so it can never exceed the technique ceiling, keeping execution from
	becoming automatic no matter how much gear is stacked.
]]
ModifierChannel.EffectiveTechnique = "EffectiveTechnique"

--[[
	Adjusts the physical difficulty of the attempt, on the shared 0-100 scale.
	Height and leverages are the natural fit: a tall lifter's deadlift lockout is
	genuinely less punishing.
]]
ModifierChannel.BaseDifficulty = "BaseDifficulty"

--[[
	Scales one named minigame parameter directly, e.g. "needleSpeed". Requires the
	modifier's `target` field. For effects too specific to express as a general
	technique change.
]]
ModifierChannel.MinigameParameter = "MinigameParameter"

--[[
	Scales training progress. The home for coach training-efficiency bonuses, food
	buffs and origin progression traits.
]]
ModifierChannel.TrainingEffectiveness = "TrainingEffectiveness"

-- Every valid channel, for validation.
ModifierChannel.All = {
	ModifierChannel.EffectiveTechnique,
	ModifierChannel.BaseDifficulty,
	ModifierChannel.MinigameParameter,
	ModifierChannel.TrainingEffectiveness,
}

function ModifierChannel.isValid(channel: string): boolean
	for _, valid in ipairs(ModifierChannel.All) do
		if channel == valid then
			return true
		end
	end
	return false
end

return ModifierChannel
