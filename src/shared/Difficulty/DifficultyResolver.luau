--!strict
--[[
	DifficultyResolver
	Shared / Difficulty

	The entry point for the difficulty engine. Given an attempt and the relevant
	technique stat, it produces everything a minigame needs to configure itself.

	Deliberately NOT done here: technique is not subtracted from difficulty.
	The two travel side by side, exactly as specified in GAME_DESIGN.md:

		Attempt
		   |
		Physical Difficulty  ----+
		                         |--> Minigame parameters --> Player execution
		Effective Technique  ----+

	So difficulty 65 with poor Depth Awareness yields a small, fast skill check,
	while difficulty 65 with excellent Depth Awareness yields a larger, slower
	one. The lift is equally heavy in both cases; the character handles it better.

	MODIFIERS

	Per Q4 this module contains no knowledge of equipment, height, origins,
	coaches or clans. Callers gather modifiers from ModifierRegistry and pass the
	resulting set in. This module applies them generically by channel, so a new
	modifier source never requires a change here.

	Also absent: Record Percentage. Per Q3 it governs long-term progression speed,
	never the difficulty of the lift in front of the player, so a lifter near a
	record is not punished twice for the same strength.

	SERVER AUTHORITY

	This lives in Shared because the client needs it to DRAW a minigame. It is not
	an authority. The server resolves difficulty, the server sends the parameters,
	and the server scores the result. A client-side resolve is for display only and
	must never decide whether a lift counted.
]]

local IntensityCurve = require(script.Parent.IntensityCurve)
local TechniqueCurve = require(script.Parent.TechniqueCurve)
local ModifierChannel = require(script.Parent.Parent.Modifiers.ModifierChannel)
local ModifierSet = require(script.Parent.Parent.Modifiers.ModifierSet)

local DifficultyResolver = {}

-- The shared difficulty scale's bounds, per GAME_DESIGN.md.
local MINIMUM_DIFFICULTY = 0
local MAXIMUM_DIFFICULTY = 100

export type LiftInput = {
	-- The weight the player chose to attempt, in kg.
	attemptWeight: number,
	-- The character's forecasted max for this lift, in kg. Must be above 0.
	forecastedMax: number,
	-- The RAW (unbounded) technique stat relevant to the phase being resolved,
	-- e.g. Depth Awareness for a squat depth check.
	techniqueStat: number,
	--[[
		Modifiers from equipment, height, coaches and so on, normally obtained
		from ModifierRegistry.gather. Omit it and the lift resolves unmodified,
		which is why every system can ignore modifiers until it needs them.
	]]
	modifiers: ModifierSet.ModifierSet?,
}

export type LiftDifficulty = {
	-- Attempt / forecasted max, where 1.0 means a 100% attempt.
	intensity: number,
	-- The same value as a percentage, for display.
	intensityPercent: number,
	-- Physical difficulty after modifiers, on the shared 0-100 scale.
	baseDifficulty: number,
	-- Physical difficulty before modifiers, for balancing and debugging.
	baseDifficultyBeforeModifiers: number,
	-- Human-readable band for baseDifficulty.
	classification: string,
	-- The raw stat that was supplied.
	rawTechniqueStat: number,
	-- Effective technique after the curve AND modifiers.
	effectiveTechnique: number,
	-- Effective technique after the curve but before modifiers.
	effectiveTechniqueBeforeModifiers: number,
	-- Carried through so minigame parameter mapping can apply its own channel.
	modifiers: ModifierSet.ModifierSet?,
}

--[[
	Resolves one lift phase into difficulty data.
]]
function DifficultyResolver.resolve(input: LiftInput): LiftDifficulty
	assert(
		typeof(input.forecastedMax) == "number" and input.forecastedMax > 0,
		"[DifficultyResolver] forecastedMax must be a number above 0"
	)
	assert(
		typeof(input.attemptWeight) == "number" and input.attemptWeight >= 0,
		"[DifficultyResolver] attemptWeight must be a number of 0 or higher"
	)

	local intensity = input.attemptWeight / input.forecastedMax

	local rawDifficulty = IntensityCurve.toBaseDifficulty(intensity)
	local rawEffectiveTechnique = TechniqueCurve.toEffective(input.techniqueStat)

	local baseDifficulty = rawDifficulty
	local effectiveTechnique = rawEffectiveTechnique

	local modifiers = input.modifiers
	if modifiers then
		-- Difficulty stays inside the shared 0-100 scale whatever modifiers do.
		baseDifficulty = math.clamp(
			ModifierSet.apply(modifiers, ModifierChannel.BaseDifficulty, rawDifficulty),
			MINIMUM_DIFFICULTY,
			MAXIMUM_DIFFICULTY
		)

		--[[
			Effective technique is clamped to the curve's own ceiling. Stacking
			every piece of equipment in the game can bring a lifter close to that
			ceiling but never past it, so execution never becomes automatic.
		]]
		effectiveTechnique = math.clamp(
			ModifierSet.apply(modifiers, ModifierChannel.EffectiveTechnique, rawEffectiveTechnique),
			0,
			TechniqueCurve.ceiling()
		)
	end

	return {
		intensity = intensity,
		intensityPercent = intensity * 100,
		baseDifficulty = baseDifficulty,
		baseDifficultyBeforeModifiers = rawDifficulty,
		classification = IntensityCurve.classify(baseDifficulty),
		rawTechniqueStat = input.techniqueStat,
		effectiveTechnique = effectiveTechnique,
		effectiveTechniqueBeforeModifiers = rawEffectiveTechnique,
		modifiers = modifiers,
	}
end

return DifficultyResolver
