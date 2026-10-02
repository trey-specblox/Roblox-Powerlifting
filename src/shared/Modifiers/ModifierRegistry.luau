--!strict
--[[
	ModifierRegistry
	Shared / Modifiers

	Where modifier sources sign up, and where the engine collects their output.

	THIS IS THE ANSWER TO Q4's ARCHITECTURE RULE.

	GAME_DESIGN.md requires that the Difficulty Engine must not become one giant
	hardcoded formula with every modifier multiplied together, and that systems
	such as equipment, height, origins, coaches and future clans must be able to
	contribute without rewriting core lifting logic.

	So the engine does not know those systems exist. It asks the registry for
	whatever modifiers apply to the current context and applies them generically.
	Adding clans later means one call:

		ModifierRegistry.register("Clan", function(context)
			local set = ModifierSet.create()
			-- read context.profile, add modifiers from the clan's own config
			return set
		end)

	No change to DifficultyResolver, ParameterMapper, or any minigame.

	NOTHING IS REGISTERED YET. Equipment, height, origins and coaches all have
	undefined magnitudes, and Q4 forbids inventing them. Each registers itself when
	it is built, with its numbers in its own config. Until then the registry
	returns an empty set and every lift resolves exactly as it does today.
]]

local ModifierSet = require(script.Parent.ModifierSet)

local ModifierRegistry = {}

--[[
	Everything a source might need to decide its contribution.

	Deliberately loose for now: `profile` becomes a typed PlayerProfile once the
	player data layer exists. Sources should treat every field as optional and
	contribute nothing when the information they need is absent, so a half-built
	context can never crash a lift.
]]
export type ModifierContext = {
	-- "Squat", "Bench" or "Deadlift".
	liftName: string?,
	-- Which phase is being resolved, e.g. "Control", "Depth", "Lockout".
	phase: string?,
	-- The lifter's persistent data. Untyped until the data layer lands.
	profile: any?,
	-- Set when the context is a training action rather than a competition lift.
	isTraining: boolean?,
}

-- (context) -> modifiers contributed by this source
export type ModifierProducer = (ModifierContext) -> ModifierSet.ModifierSet

type RegisteredSource = {
	name: string,
	producer: ModifierProducer,
}

local sources: { RegisteredSource } = {}

--[[
	Registers a modifier source under a unique name.

	Registering the same name twice is an error rather than a silent overwrite,
	because a duplicate registration means two systems are fighting and the result
	would otherwise depend on load order.
]]
function ModifierRegistry.register(name: string, producer: ModifierProducer)
	assert(typeof(name) == "string" and name ~= "", "[ModifierRegistry] a source needs a non-empty name")
	assert(typeof(producer) == "function", string.format("[ModifierRegistry] source %q needs a function", name))

	for _, existing in ipairs(sources) do
		assert(
			existing.name ~= name,
			string.format("[ModifierRegistry] a source named %q is already registered", name)
		)
	end

	table.insert(sources, { name = name, producer = producer })
end

--[[
	Collects every registered source's modifiers for one context.

	A source that errors is reported and skipped rather than being allowed to kill
	the lift in progress. A broken coach config should cost the player a bonus, not
	their attempt.
]]
function ModifierRegistry.gather(context: ModifierContext): ModifierSet.ModifierSet
	local combined = ModifierSet.create()

	for _, source in ipairs(sources) do
		local ok, result = pcall(source.producer, context)

		if not ok then
			warn(string.format("[ModifierRegistry] source %q errored and was skipped: %s", source.name, tostring(result)))
		elseif result ~= nil then
			ModifierSet.merge(combined, result)
		end
	end

	return combined
end

--[[
	The names of every registered source, for the dev probe and admin readouts.
]]
function ModifierRegistry.registeredSourceNames(): { string }
	local names: { string } = {}
	for _, source in ipairs(sources) do
		table.insert(names, source.name)
	end
	return names
end

--[[
	Removes every registered source. Intended for tests only, so one test's fake
	source cannot leak into the next.
]]
function ModifierRegistry.resetForTesting()
	sources = {}
end

return ModifierRegistry
