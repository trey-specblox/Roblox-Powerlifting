--!strict
--[[
	AttemptRules
	Shared / Meet

	Decides whether a declared attempt weight is legal.

	Rules implemented, from GAME_DESIGN.md Group C / Q11:

		- Three attempts per lift.
		- A weight may never be LOWER than one already attempted.
		- After a failed attempt the same weight may be repeated.
		- Any increase must be at least MinimumIncrementKg.
		- After a good lift the weight must increase (see MeetConfig note).

	Worked example from the design doc:

		Squat 1: 180 kg GOOD
		Squat 2: 190 kg NO LIFT
		Squat 3: 190 kg legal (repeating a failure)
		         192.5 kg legal (a 2.5 kg increase)
		         185 kg ILLEGAL (below a weight already attempted)
		         191 kg ILLEGAL (an increase smaller than 2.5 kg)

	SERVER AUTHORITY

	This module is pure and lives in Shared so the client can grey out illegal
	choices in the attempt-selection UI. That is a convenience only. The server
	must run this same check on every declaration it receives and treat its own
	answer as the only one that counts. A client that declares 500 kg, or tries to
	take a fourth attempt, is simply rejected.
]]

local MeetConfig = require(script.Parent.Parent.Config.MeetConfig)

local AttemptRules = {}

export type AttemptResult = "GoodLift" | "NoLift"

export type Attempt = {
	weightKg: number,
	result: AttemptResult,
}

-- Attempts for a single lift, in the order they were taken.
export type AttemptHistory = { Attempt }

export type Rejection = {
	-- Stable identifier for code and localisation.
	code: string,
	-- Plain-English explanation, safe to show a player.
	message: string,
}

--[[
	How many attempts the lifter still has on this lift.
]]
function AttemptRules.attemptsRemaining(history: AttemptHistory): number
	return math.max(0, MeetConfig.AttemptsPerLift - #history)
end

--[[
	True once every attempt on this lift has been taken.
]]
function AttemptRules.isComplete(history: AttemptHistory): boolean
	return #history >= MeetConfig.AttemptsPerLift
end

--[[
	The heaviest weight already attempted on this lift, successful or not,
	or nil when no attempt has been taken.

	Weights cannot decrease, so in normal play this equals the last attempt's
	weight. It is computed as a maximum anyway so that the rule holds even if a
	history is ever assembled out of order.
]]
function AttemptRules.highestAttemptedWeight(history: AttemptHistory): number?
	local highest: number? = nil
	for _, attempt in ipairs(history) do
		if highest == nil or attempt.weightKg > highest then
			highest = attempt.weightKg
		end
	end
	return highest
end

--[[
	The result recorded for a given weight, or nil if it was never attempted.
	Used to decide whether repeating that weight is allowed.
]]
local function resultAtWeight(history: AttemptHistory, weightKg: number): AttemptResult?
	local epsilon = MeetConfig.WeightEpsilonKg
	local found: AttemptResult? = nil
	for _, attempt in ipairs(history) do
		if math.abs(attempt.weightKg - weightKg) <= epsilon then
			-- Keep the latest result for that weight.
			found = attempt.result
		end
	end
	return found
end

--[[
	Checks a declared weight against the rules.

	Returns true when legal. Returns false plus a Rejection when not, so the
	caller can explain the refusal rather than silently dropping it.
]]
function AttemptRules.validate(history: AttemptHistory, requestedWeightKg: number): (boolean, Rejection?)
	if typeof(requestedWeightKg) ~= "number" or requestedWeightKg ~= requestedWeightKg then
		return false, {
			code = "InvalidWeight",
			message = "That attempt weight is not a valid number.",
		}
	end

	if requestedWeightKg <= 0 then
		return false, {
			code = "InvalidWeight",
			message = "An attempt weight must be greater than zero.",
		}
	end

	if AttemptRules.isComplete(history) then
		return false, {
			code = "NoAttemptsRemaining",
			message = string.format(
				"You have already taken all %d attempts on this lift.",
				MeetConfig.AttemptsPerLift
			),
		}
	end

	local floor = AttemptRules.highestAttemptedWeight(history)

	-- First attempt on this lift: any positive weight is acceptable.
	if floor == nil then
		return true, nil
	end

	local epsilon = MeetConfig.WeightEpsilonKg

	-- Below a weight already attempted.
	if requestedWeightKg < floor - epsilon then
		return false, {
			code = "WeightDecreased",
			message = string.format(
				"You cannot go below %.1f kg, which you have already attempted.",
				floor
			),
		}
	end

	-- Repeating the same weight.
	if math.abs(requestedWeightKg - floor) <= epsilon then
		local previousResult = resultAtWeight(history, floor)

		if previousResult == "GoodLift" and not MeetConfig.AllowRepeatAfterGoodLift then
			return false, {
				code = "MustIncreaseAfterGoodLift",
				message = string.format(
					"You already made %.1f kg, so your next attempt must be heavier.",
					floor
				),
			}
		end

		return true, nil
	end

	-- Increasing: the jump must clear the minimum increment.
	local increase = requestedWeightKg - floor
	if increase < MeetConfig.MinimumIncrementKg - epsilon then
		return false, {
			code = "IncreaseTooSmall",
			message = string.format(
				"An increase must be at least %.1f kg. Choose %.1f kg or heavier.",
				MeetConfig.MinimumIncrementKg,
				floor + MeetConfig.MinimumIncrementKg
			),
		}
	end

	return true, nil
end

--[[
	The lowest weight the lifter could legally declare next.

	Returns nil in two different situations, so call isComplete first if you need to
	tell them apart: either the lifter has no attempts remaining, or this is their
	first attempt on the lift and any positive weight is legal.
]]
function AttemptRules.lowestLegalNextWeight(history: AttemptHistory): number?
	if AttemptRules.isComplete(history) then
		return nil
	end

	local floor = AttemptRules.highestAttemptedWeight(history)
	if floor == nil then
		return nil
	end

	local previousResult = resultAtWeight(history, floor)
	if previousResult == "NoLift" or MeetConfig.AllowRepeatAfterGoodLift then
		return floor
	end

	return floor + MeetConfig.MinimumIncrementKg
end

return AttemptRules
