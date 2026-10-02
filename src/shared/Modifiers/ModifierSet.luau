--!strict
--[[
	ModifierSet
	Shared / Modifiers

	A collected bundle of modifiers, and the rules for applying them.

	AGGREGATION ORDER

	Order matters, and leaving it implicit is how modifier systems become
	impossible to balance. The rule here is fixed and applies to every channel:

		result = (base + sum of all Add values) * product of all Multiply values

	So additive effects land first and multiplicative effects scale the outcome.
	Two +10% multipliers give 1.21x rather than 1.2x, which is normal for stacking
	gear and keeps each item's contribution independent of evaluation order.

	Every modifier records which system produced it, so a balancing problem can be
	traced to its source and so the UI can eventually show a player why their lift
	got easier.

	WHAT THIS MODULE DOES NOT CONTAIN

	No magnitudes. Not one. Equipment percentages, height curves, origin bonuses
	and coach effects are all undefined in GAME_DESIGN.md, and Q4 is explicit that
	they must not be invented. This module is the machinery; the numbers arrive
	with each system, in that system's own config.
]]

local ModifierChannel = require(script.Parent.ModifierChannel)

local ModifierSet = {}

export type Operation = "Add" | "Multiply"

export type Modifier = {
	-- Which quantity this affects. Must be a ModifierChannel value.
	channel: string,
	operation: Operation,
	value: number,
	-- Which system produced this, e.g. "Equipment:Belt". Used for tracing and UI.
	source: string,
	-- Required for the MinigameParameter channel, naming the parameter affected.
	target: string?,
}

export type ModifierSet = {
	modifiers: { Modifier },
}

function ModifierSet.create(): ModifierSet
	return { modifiers = {} }
end

--[[
	Adds one modifier, rejecting malformed input loudly rather than letting a typo
	silently do nothing.
]]
function ModifierSet.add(set: ModifierSet, modifier: Modifier)
	assert(
		ModifierChannel.isValid(modifier.channel),
		string.format("[ModifierSet] unknown channel %q from source %q", modifier.channel, modifier.source)
	)
	assert(
		modifier.operation == "Add" or modifier.operation == "Multiply",
		string.format("[ModifierSet] modifier from %q needs operation \"Add\" or \"Multiply\"", modifier.source)
	)
	assert(
		typeof(modifier.value) == "number" and modifier.value == modifier.value,
		string.format("[ModifierSet] modifier from %q has a non-numeric value", modifier.source)
	)
	if modifier.channel == ModifierChannel.MinigameParameter then
		assert(
			modifier.target ~= nil,
			string.format(
				"[ModifierSet] modifier from %q targets a minigame parameter but names none",
				modifier.source
			)
		)
	end

	table.insert(set.modifiers, modifier)
end

--[[
	Merges another set in. Used by the registry to combine every source.
]]
function ModifierSet.merge(set: ModifierSet, other: ModifierSet)
	for _, modifier in ipairs(other.modifiers) do
		table.insert(set.modifiers, modifier)
	end
end

--[[
	Every modifier affecting one channel (and optionally one target).

	Useful on its own for a "why is this lift easier?" breakdown in the UI.
]]
function ModifierSet.relevantTo(set: ModifierSet, channel: string, target: string?): { Modifier }
	local relevant: { Modifier } = {}
	for _, modifier in ipairs(set.modifiers) do
		if modifier.channel == channel and modifier.target == target then
			table.insert(relevant, modifier)
		end
	end
	return relevant
end

--[[
	Applies a channel's modifiers to a base value using the documented order.

	An empty set returns the base value untouched, which is what makes modifiers
	entirely optional throughout the codebase.
]]
function ModifierSet.apply(set: ModifierSet, channel: string, baseValue: number, target: string?): number
	local additive = 0
	local multiplicative = 1

	for _, modifier in ipairs(set.modifiers) do
		if modifier.channel == channel and modifier.target == target then
			if modifier.operation == "Add" then
				additive += modifier.value
			else
				multiplicative *= modifier.value
			end
		end
	end

	return (baseValue + additive) * multiplicative
end

--[[
	A human-readable breakdown, for the dev probe and for balancing sessions.
]]
function ModifierSet.describe(set: ModifierSet, channel: string, target: string?): string
	local relevant = ModifierSet.relevantTo(set, channel, target)
	if #relevant == 0 then
		return "no modifiers"
	end

	local parts: { string } = {}
	for _, modifier in ipairs(relevant) do
		local sign = if modifier.operation == "Add" then "+" else "x"
		table.insert(parts, string.format("%s%s (%s)", sign, tostring(modifier.value), modifier.source))
	end
	return table.concat(parts, ", ")
end

return ModifierSet
