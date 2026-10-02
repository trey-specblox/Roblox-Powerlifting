--!strict
--[[
	ParameterMapper
	Shared / Difficulty

	Converts a resolved LiftDifficulty into the concrete numbers one minigame
	needs: needle speed, success-zone size, perfect-zone size, reaction window,
	movement speed, stability, phrase length, and so on.

	THE RULE THIS MODULE EXISTS TO ENFORCE

	Technique is never subtracted from difficulty. Each parameter is built from
	two independent curves:

		difficulty  -> a demanded base value   (harder lift = harsher parameter)
		technique   -> a multiplier on it      (better character = kinder parameter)

		final = base * multiplier, then modifiers, then clamped

	A multiplier of 1.0 means technique offers no help. Below 1.0 shrinks the
	parameter, above 1.0 grows it, so each minigame decides for itself which
	direction is "easier" for a given parameter. Needle speed wants a multiplier
	under 1.0 (slower is kinder); zone size wants one over 1.0 (bigger is kinder).

	Because every parameter is a pair of curves held in Config/, a minigame can be
	rebalanced entirely from configuration without editing its gameplay code.

	Equipment and other sources may also target a named parameter directly through
	the MinigameParameter channel, for effects too specific to express as a general
	technique change.

	No minigame specs exist yet. Those arrive with each minigame, and their numbers
	need design sign-off before they are written down.
]]

local Curve = require(script.Parent.Parent.Util.Curve)
local DifficultyResolver = require(script.Parent.DifficultyResolver)
local ModifierChannel = require(script.Parent.Parent.Modifiers.ModifierChannel)
local ModifierSet = require(script.Parent.Parent.Modifiers.ModifierSet)

local ParameterMapper = {}

export type ParameterSpec = {
	-- x = base difficulty (0-100), y = the demanded base value for this parameter.
	fromDifficulty: Curve.Curve,
	-- x = effective technique (about 10 to the curve ceiling), y = a multiplier.
	-- Omit when a parameter should ignore technique entirely.
	fromTechnique: Curve.Curve?,
	-- Optional hard safety bounds, applied last.
	minimum: number?,
	maximum: number?,
}

export type MinigameSpec = { [string]: ParameterSpec }

--[[
	Resolves one named parameter.

	`name` identifies the parameter both for its own sake and so that modifiers
	targeting it through the MinigameParameter channel can be matched.
]]
function ParameterMapper.resolve(
	name: string,
	spec: ParameterSpec,
	difficulty: DifficultyResolver.LiftDifficulty
): number
	local base = Curve.evaluate(spec.fromDifficulty, difficulty.baseDifficulty)

	local multiplier = 1
	if spec.fromTechnique then
		multiplier = Curve.evaluate(spec.fromTechnique, difficulty.effectiveTechnique)
	end

	local value = base * multiplier

	-- Modifiers aimed at this specific parameter, e.g. a bench shirt steadying
	-- the bar. Absent modifiers leave the value untouched.
	local modifiers = difficulty.modifiers
	if modifiers then
		value = ModifierSet.apply(modifiers, ModifierChannel.MinigameParameter, value, name)
	end

	if spec.minimum then
		value = math.max(value, spec.minimum)
	end
	if spec.maximum then
		value = math.min(value, spec.maximum)
	end

	return value
end

--[[
	Resolves a whole minigame's parameter set at once.

	Returns a plain name -> number table, which is exactly the shape that should
	be handed to the client to render a minigame.
]]
function ParameterMapper.resolveAll(
	spec: MinigameSpec,
	difficulty: DifficultyResolver.LiftDifficulty
): { [string]: number }
	local resolved = {}
	for name, parameterSpec in pairs(spec) do
		resolved[name] = ParameterMapper.resolve(name, parameterSpec, difficulty)
	end
	return resolved
end

--[[
	Validates every curve in a minigame spec. Call once when a spec is authored,
	so a typo in a balancing table fails at startup rather than mid-lift.
]]
function ParameterMapper.validate(spec: MinigameSpec, name: string)
	for parameterName, parameterSpec in pairs(spec) do
		Curve.validate(parameterSpec.fromDifficulty, string.format("%s.%s.fromDifficulty", name, parameterName))
		if parameterSpec.fromTechnique then
			Curve.validate(parameterSpec.fromTechnique, string.format("%s.%s.fromTechnique", name, parameterName))
		end
	end
end

return ParameterMapper
