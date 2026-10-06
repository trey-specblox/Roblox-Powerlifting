--!strict
--[[
	CompetitionBudget
	Shared / Progression

	The harmonic diminishing overflow of a per-lift Competition Budget, from
	GAME_DESIGN.md section 29.9.

	=========================================================================
	THE STATE IS ONE NUMBER
	=========================================================================

	A budget is the `amount` already stored by ResourceRegeneration, which may be
	NEGATIVE. That single number is sufficient, and no second field is needed:

		amount >  0     unspent allowance remains
		amount <= 0     the player is in overflow, and -amount IS the depth

	Everything below is derived from it. There is deliberately NO meet counter,
	NO attempt counter and NO "meet number" anywhere in the data model, because
	consumption is driven by actual progression EV. A 0.4 EV attempt advances the
	state by 0.4 and a 1.0 EV attempt by 1.0, and neither needs to know what a
	meet is.

	=========================================================================
	THE EQUATION
	=========================================================================

	The multiplier applied to progression at overflow depth d:

		M(d) = 1 / (1 + d / K)          K = OverflowK x UnitEV

	K is the only place UnitEV appears. It is a SCALE for the curve, chosen so
	that one normal meet's worth of overflow costs the same as it did in the
	discrete model we approved. It is not a count and nothing divides by it to
	ask "which meet is this".

	Consuming raw EV `r` from state `a` integrates M across the span consumed,
	because the multiplier falls continuously as the span is consumed rather
	than being fixed for a whole meet:

		f(d)        = K x ln(1 + d / K)              (antiderivative of M)
		fullRate    = min(r, max(a, 0))              (span still inside allowance)
		effectiveEV = fullRate + f(max(0, r - a)) - f(max(0, -a))
		newAmount   = a - r

	NOTE WHICH VALUE IS SUBTRACTED. The state advances by the RAW EV, never by
	the effective EV. That is what makes overflow actually diminish: spending
	effective EV instead would let a player in deep overflow consume almost
	nothing and so never sink further, turning the curve into a soft plateau.

	The exploit closure from section 29.9 still holds, because raw EV already
	encodes success, failure and intensity. A failed attempt carries 0.20 of the
	raw EV of the same attempt succeeded, so it consumes 0.20 as much, and the
	effective-per-raw ratio at a given state is identical either way. There is
	still no way to game the ratio and still no reason to fail on purpose.

	PATH INDEPENDENCE. Because f is a true antiderivative, consuming 1.886 EV in
	one call and in a hundred small calls yield the same total effective EV and
	the same final state. The dev harness asserts this.

	=========================================================================
	NEVER LITERALLY ZERO
	=========================================================================

	M(d) > 0 for every finite d, so additional legitimate progression always
	pays something. After five years of thirty meets a week the multiplier is
	still about 0.00046, which is tiny but real.

	THERE IS NO NEGATIVE FLOOR, deliberately. An earlier draft clamped the
	amount at -5 x capacity as a "corruption guard", and that was a bug: thirty
	meets in a week lands at exactly -47.15, which was exactly the clamp, so the
	guard silently refused the busiest week we had explicitly approved as
	legitimate. Deep overflow needs no floor because M already makes it
	worthless, and a floor can only ever turn into an accidental hard cap.
	Corrupt stored values are handled by finite-number validation and by the
	schema's migration repair, which is where that concern belongs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))

local ProgressionFolder = Shared:WaitForChild("Progression")
local ResourceRegeneration = require(ProgressionFolder:WaitForChild("ResourceRegeneration"))

local CompetitionBudget = {}

local BUDGET = ProgressionConfig.CompetitionBudget

--[[
	The curve scale, K = OverflowK x UnitEV.

	Computed once. This is the only place either constant is read, so the
	relationship cannot drift between call sites.
]]
local K = BUDGET.OverflowK * BUDGET.UnitEV

CompetitionBudget.CurveScaleEV = K

--[[
	How deep into overflow a stored amount is, in EV. Zero while allowance
	remains.
]]
function CompetitionBudget.overflowDepth(amount: number): number
	if amount >= 0 then
		return 0
	end
	return -amount
end

--[[
	The multiplier progression would receive RIGHT NOW at this amount.

	This is the instantaneous rate, useful for a Fresh / Worked / Fatigued
	readout. It is NOT what an award is scaled by: an award spans a range of
	depths, so it uses effectiveEV below.
]]
function CompetitionBudget.multiplierAt(amount: number): number
	if amount >= 0 then
		return 1
	end
	return 1 / (1 + CompetitionBudget.overflowDepth(amount) / K)
end

--[[
	The antiderivative of the multiplier. f(0) = 0.
]]
local function integral(depth: number): number
	if depth <= 0 then
		return 0
	end
	return K * math.log(1 + depth / K)
end

--[[
	The effective EV that consuming `rawEV` from state `amount` produces.

	Returns the effective EV and the resulting amount. Pure: writes nothing.

	Rejects nothing, because there is nothing to reject -- see the semantics note
	in ProfileOperations. A non-finite or non-positive rawEV is caught by the
	caller before it reaches here; this function assumes a valid span.
]]
function CompetitionBudget.effectiveEV(amount: number, rawEV: number): (number, number)
	if rawEV <= 0 then
		return 0, amount
	end

	-- The part of the span still covered by unspent allowance, at full rate.
	local fullRate = math.min(rawEV, math.max(amount, 0))

	local depthBefore = CompetitionBudget.overflowDepth(amount)
	local depthAfter = CompetitionBudget.overflowDepth(amount - rawEV)

	local effective = fullRate + integral(depthAfter) - integral(depthBefore)

	return effective, amount - rawEV
end

--[[
	Consumes `rawEV` from a lift's budget resource and returns the effective EV.

	ALWAYS SUCCEEDS for a valid span. A Competition Budget has no floor and
	cannot be "insufficient": once the allowance is gone, progression continues
	at a diminishing multiplier. That is the frozen rule that active meet
	progression never hard-zeros.

	Contrast ResourceRegeneration.trySpend, which Training Energy uses: that is
	all-or-nothing and refuses when short, because passive gain DOES stop at
	empty. The two resources deliberately behave differently and the difference
	is the whole reason they are separate functions.

	Regenerates before consuming, so the span starts from the state the player
	actually has rather than a stale stored value.
]]
function CompetitionBudget.consume(
	resource: ResourceRegeneration.Resource,
	nowUnix: number,
	rawEV: number
): (number, number)
	local available = ResourceRegeneration.settle(
		resource,
		nowUnix,
		BUDGET.CapacityEV,
		BUDGET.RegenerationEVPerHour
	)

	local effective, remaining = CompetitionBudget.effectiveEV(available, rawEV)

	resource.amount = remaining
	resource.lastUpdatedUnix = nowUnix

	return effective, remaining
end

--[[
	The player-facing freshness state for a lift, per section 29.9.

	Three states rather than three resource bars. Thresholds are read from the
	capacity so they track a tuned capacity automatically.
]]
function CompetitionBudget.freshness(amount: number): string
	local fraction = amount / BUDGET.CapacityEV

	if fraction > 0.60 then
		return "FRESH"
	elseif fraction >= 0.20 then
		return "WORKED"
	end

	return "FATIGUED"
end

return CompetitionBudget
