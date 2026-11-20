--!strict
--[[
	GainBoosts
	Shared / Progression

	The one place that says how much the player's active gain boosts raise a gain (GAME_DESIGN §40.1, §40.2, §40.7).
	Boosts ADD TOGETHER (a steak's +50% and, later, a booster's +30% = +80%), so several at once can't multiply into
	runaway gains.

	Today there is one boost: the steak meal (a TRAINING boost, KitchenConfig). Meet meals, the strongman NPC's
	boosters and stat-gain gear add their own entries to the save's `boosts` record and to the sums below.

	Pure: reads the saved boosts record and a SERVER clock passed in, writes nothing, never yields. The server uses it
	in the training awards; the client uses the same numbers to show the boost timer.
]]

local GainBoosts = {}

export type Boost = { percent: number, endsAt: number }

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- An active boost from a saved entry, or nil when it is missing, broken or over.
function GainBoosts.active(entry: any, nowUnix: number): Boost?
	if typeof(entry) ~= "table" or not isFiniteNumber(nowUnix) then
		return nil
	end
	local percent, endsAt = entry.percent, entry.endsAt
	if not isFiniteNumber(percent) or percent <= 0 or not isFiniteNumber(endsAt) or endsAt <= nowUnix then
		return nil
	end
	return { percent = percent, endsAt = endsAt }
end

--[[
	How much the active boosts raise TRAINING gains right now, as a fraction (0.8 = +80%). `boosts` is the save's
	`boosts` record (nil or broken reads as no boost).
]]
function GainBoosts.trainingBonus(boosts: any, nowUnix: number): number
	if typeof(boosts) ~= "table" then
		return 0
	end
	local total = 0
	local steak = GainBoosts.active(boosts.steak, nowUnix)
	if steak then
		total += steak.percent / 100
	end
	return total
end

return GainBoosts
