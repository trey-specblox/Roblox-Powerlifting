--!strict
--[[
	MeetTotal
	Shared / Meet

	Works out a lifter's total from their attempts.

	From GAME_DESIGN.md Group C / Q11:

		Best Squat + Best Bench + Best Deadlift = Total

	"Best" means the heaviest SUCCESSFUL attempt on that lift. Failed attempts
	contribute nothing. If a lifter records no successful attempt on any one of
	the three lifts, they bomb out and have no total at all, which is exactly how
	real powerlifting works.

	Pure functions only, so the server can score a meet and the client can preview
	a running total from the same code.
]]

local AttemptRules = require(script.Parent.AttemptRules)
local MeetConfig = require(script.Parent.Parent.Config.MeetConfig)

local MeetTotal = {}

-- Attempt histories keyed by lift name, e.g. results.Squat
export type MeetAttempts = { [string]: AttemptRules.AttemptHistory }

export type MeetResult = {
	-- Heaviest successful attempt per lift. A lift is absent when nothing was made.
	best: { [string]: number },
	-- Sum of the three bests, or nil when the lifter bombed out.
	total: number?,
	-- True when at least one lift has no successful attempt.
	bombedOut: boolean,
	-- Which lifts had no successful attempt. Empty when the total stands.
	bombedLifts: { string },
}

--[[
	The heaviest successful attempt on one lift, or nil if none was made.
]]
function MeetTotal.bestSuccessful(history: AttemptRules.AttemptHistory): number?
	local best: number? = nil
	for _, attempt in ipairs(history) do
		if attempt.result == "GoodLift" then
			if best == nil or attempt.weightKg > best then
				best = attempt.weightKg
			end
		end
	end
	return best
end

--[[
	Scores a complete set of meet attempts.

	Missing lifts are treated as "nothing made", so a partially recorded meet
	reports as a bomb-out rather than quietly producing a smaller total.
]]
function MeetTotal.resolve(attempts: MeetAttempts): MeetResult
	local best: { [string]: number } = {}
	local bombedLifts: { string } = {}
	local runningTotal = 0

	for _, liftName in ipairs(MeetConfig.LiftOrder) do
		local history = attempts[liftName] or {}
		local liftBest = MeetTotal.bestSuccessful(history)

		if liftBest == nil then
			table.insert(bombedLifts, liftName)
		else
			best[liftName] = liftBest
			runningTotal += liftBest
		end
	end

	local bombedOut = #bombedLifts > 0

	return {
		best = best,
		total = if bombedOut then nil else runningTotal,
		bombedOut = bombedOut,
		bombedLifts = bombedLifts,
	}
end

return MeetTotal
