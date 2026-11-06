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

-- QUICK PICK: these shares of the lift's Competition Number, one button each.
local QUICK_PICK_SHARES = { 0.90, 0.95, 1.00, 1.05, 1.10, 1.15, 1.20, 1.25 }
-- How light the extra picks go when a small number leaves buttons spare.
local QUICK_PICK_LOWEST_SHARE = 0.7

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

-- The range a lifter may declare AT A MEET: as above, but up to the meet's ceiling, past the normal limit.
function AttemptChoice.meetBounds(competitionNumberKg: number, stepKg: number): (number, number)
	return roundUp(competitionNumberKg * LiftAttemptConfig.MinimumAttemptPercent, stepKg),
		roundDown(competitionNumberKg * LiftAttemptConfig.MeetCeilingPercent, stepKg)
end

-- True for a weight past the normal limit (LiftAttemptConfig.MeetCeilingPercent): it can't raise CN or set a record.
function AttemptChoice.isOverLimit(competitionNumberKg: number, kg: number): boolean
	return kg > competitionNumberKg * LiftAttemptConfig.MaximumAttemptPercent + 1e-6
end

-- The heaviest good lift at or under the normal limit, or nil: what Competition Scale may rise to.
function AttemptChoice.bestWithinLimit(competitionNumberKg: number, history: AttemptRules.AttemptHistory): number?
	local best: number? = nil
	for _, attempt in ipairs(history) do
		if attempt.result == "GoodLift" and not AttemptChoice.isOverLimit(competitionNumberKg, attempt.weightKg)
			and (best == nil or attempt.weightKg > best) then
			best = attempt.weightKg
		end
	end
	return best
end

--[[
	The lightest legal next weight and the default (what a time-out takes) for
	the lift's next attempt, or nil when no legal weight lies inside the bounds
	(the attempt is passed). The opener's default is `openerPercent` of the
	Competition Number; after a miss it is the same weight, after a good lift the
	smallest legal increase. `overLimit`: a real lifter at a meet, who may go past
	the normal limit (not a computer lifter or a warm-up).
]]
function AttemptChoice.nextWeights(competitionNumberKg: number, history: AttemptRules.AttemptHistory, stepKg: number,
	openerPercent: number, overLimit: boolean?): (number?, number?)
	local minKg, maxKg = AttemptChoice.bounds(competitionNumberKg, stepKg)
	if overLimit then
		_, maxKg = AttemptChoice.meetBounds(competitionNumberKg, stepKg)
	end
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

--[[
	The QUICK PICK weights for one attempt, lightest first: all different and all
	allowed. Starts from 90-125% of the Competition Number. On a small number those
	shares round to the same weight (user 2026-11-06: "100% 25kg but 105% 25kg"), so
	a weight already taken is skipped. With room left, it adds lighter weights down
	to QUICK_PICK_LOWEST_SHARE, then weights over the normal limit, if `maxKg` goes
	that far (AttemptChoice.meetBounds).
]]
function AttemptChoice.quickPicks(competitionNumberKg: number, minKg: number, maxKg: number, stepKg: number): { number }
	local picks: { number } = {}
	if competitionNumberKg <= 0 then
		return picks
	end
	local last = -math.huge
	for _, share in ipairs(QUICK_PICK_SHARES) do
		local kg = roundDown(competitionNumberKg * share, stepKg)
		if kg > maxKg + 1e-6 then
			break
		end
		if kg >= minKg - 1e-6 and kg > last + 1e-6 then
			table.insert(picks, kg)
			last = kg
		end
	end
	-- Already past every share: start from the lightest weight allowed.
	if #picks == 0 and minKg <= maxKg + 1e-6 then
		table.insert(picks, minKg)
		last = minKg
	end
	local lowest = math.max(minKg, roundUp(competitionNumberKg * QUICK_PICK_LOWEST_SHARE, stepKg))
	while #picks > 0 and #picks < #QUICK_PICK_SHARES and picks[1] - stepKg >= lowest - 1e-6 do
		table.insert(picks, 1, picks[1] - stepKg)
	end
	-- Over the limit, in steps of about 5% of the number.
	local jump = math.max(stepKg, roundDown(competitionNumberKg * 0.05, stepKg))
	while #picks < #QUICK_PICK_SHARES and last + jump <= maxKg + 1e-6 do
		last += jump
		table.insert(picks, last)
	end
	return picks
end

-- Checks a weight the client asked for. Returns the weight, or nil and a reason to show.
function AttemptChoice.check(competitionNumberKg: number, history: AttemptRules.AttemptHistory, stepKg: number,
	requested: unknown, overLimit: boolean?): (number?, string?)
	if typeof(requested) ~= "number" or requested ~= requested or requested == math.huge or requested == -math.huge then
		return nil, "That is not a weight."
	end
	local kg = requested :: number
	if math.abs(kg / stepKg - math.floor(kg / stepKg + 0.5)) > 1e-6 then
		return nil, string.format("Weights go up in %.1f kg steps.", stepKg)
	end
	local minKg, maxKg = AttemptChoice.bounds(competitionNumberKg, stepKg)
	if overLimit then
		_, maxKg = AttemptChoice.meetBounds(competitionNumberKg, stepKg)
	end
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
