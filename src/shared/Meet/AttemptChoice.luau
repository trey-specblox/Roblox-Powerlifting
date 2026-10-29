--!strict
--[[
	AttemptChoice
	Shared / Meet

	Which weights a lifter may declare for their next meet attempt, shared by the
	Mock Meet and the Local meet so both check a choice the same way (GAME_DESIGN
	§29.10): a multiple of `stepKg`, inside the Competition Number's percentage
	bounds (LiftAttemptConfig), and legal under AttemptRules (§15).

	Pure: the caller passes the lift's Competition Number and attempt history.
	The server's answer is the one that counts.
]]

local ConfigFolder = script.Parent.Parent:WaitForChild("Config")
local LiftAttemptConfig = require(ConfigFolder:WaitForChild("LiftAttemptConfig"))
local AttemptRules = require(script.Parent:WaitForChild("AttemptRules"))

local AttemptChoice = {}

local function roundDown(kg: number, stepKg: number): number
	return math.floor(kg / stepKg + 1e-6) * stepKg
end

local function roundUp(kg: number, stepKg: number): number
	return math.ceil(kg / stepKg - 1e-6) * stepKg
end

-- The range of weights the lifter may declare: the Competition Number's percentage bounds, on the step grid.
function AttemptChoice.bounds(competitionNumberKg: number, stepKg: number): (number, number)
	return roundUp(competitionNumberKg * LiftAttemptConfig.MinimumAttemptPercent, stepKg),
		roundDown(competitionNumberKg * LiftAttemptConfig.MaximumAttemptPercent, stepKg)
end

--[[
	The lightest legal next weight and the default (what a time-out takes) for
	the lift's next attempt, or nil when no legal weight lies inside the bounds
	(the attempt is passed). The opener's default is `openerPercent` of the
	Competition Number; after a miss it is the same weight, after a good lift the
	smallest legal increase.
]]
function AttemptChoice.nextWeights(competitionNumberKg: number, history: AttemptRules.AttemptHistory, stepKg: number,
	openerPercent: number): (number?, number?)
	local minKg, maxKg = AttemptChoice.bounds(competitionNumberKg, stepKg)
	local lowest = AttemptRules.lowestLegalNextWeight(history)
	if lowest == nil then
		-- The opener: anything in range; the default is the suggestion.
		local suggestion = roundDown(competitionNumberKg * openerPercent, stepKg)
		return minKg, math.clamp(suggestion, minKg, maxKg)
	end
	local legal = math.max(roundUp(lowest, stepKg), minKg)
	if legal > maxKg then
		return nil, nil
	end
	return legal, legal
end

-- Checks a weight the client asked for. Returns the weight, or nil and a reason to show.
function AttemptChoice.check(competitionNumberKg: number, history: AttemptRules.AttemptHistory, stepKg: number,
	requested: unknown): (number?, string?)
	if typeof(requested) ~= "number" or requested ~= requested or requested == math.huge or requested == -math.huge then
		return nil, "That is not a weight."
	end
	local kg = requested :: number
	if math.abs(kg / stepKg - math.floor(kg / stepKg + 0.5)) > 1e-6 then
		return nil, string.format("Weights go up in %.1f kg steps.", stepKg)
	end
	local minKg, maxKg = AttemptChoice.bounds(competitionNumberKg, stepKg)
	if kg < minKg - 1e-6 or kg > maxKg + 1e-6 then
		return nil, string.format("Choose between %.1f and %.1f kg.", minKg, maxKg)
	end
	local ok, rejection = AttemptRules.validate(history, kg)
	if not ok then
		return nil, if rejection then rejection.message else "That weight is not allowed."
	end
	return kg, nil
end

return AttemptChoice
