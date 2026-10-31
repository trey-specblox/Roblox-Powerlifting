--!strict
--[[
	MeetPayout
	Server / Meet

	Works out what an official meet pays each lifter in coins (GAME_DESIGN.md
	30.6, the money system's step 3). Pure: it only does the sums from the
	settings (CoinConfig.LocalMeet) and the meet's result; the meet pays the
	coins itself through PlayerDataService.addCoins.

		forMeet      the prize pot shares by place, the finishing bonus and
		             the 9/9 bonus, per lifter
		forGymRecord the bonus for the records one good lift broke
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoinConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CoinConfig"))

local MeetPayout = {}

export type Settings = typeof(CoinConfig.LocalMeet)

-- One lifter's meet result, as far as money goes.
export type Lifter = {
	key: number,
	-- 1 = first, nil without a total.
	place: number?,
	hasTotal: boolean,
	-- Started at least one lift (counts toward the pot).
	qualified: boolean,
	-- 9 good lifts of 9.
	perfect: boolean,
}

-- One payment: how many coins and what for (the pop-up's reason).
export type Item = { amount: number, reason: string }

local function placeText(place: number): string
	local last = place % 10
	local suffix = if place % 100 >= 11 and place % 100 <= 13 then "th"
		elseif last == 1 then "st"
		elseif last == 2 then "nd"
		elseif last == 3 then "rd"
		else "th"
	return string.format("%d%s place", place, suffix)
end

-- The pot: BasePot plus PerQualifiedLifter for each qualified lifter.
function MeetPayout.pot(lifters: { Lifter }, settings: Settings): number
	local qualified = 0
	for _, lifter in ipairs(lifters) do
		if lifter.qualified then
			qualified += 1
		end
	end
	return settings.BasePot + settings.PerQualifiedLifter * qualified
end

--[[
	Every lifter's payments, by key (a lifter who earns nothing has an empty
	list). Shares are rounded down to whole coins.
]]
function MeetPayout.forMeet(lifters: { Lifter }, settings: Settings): { [number]: { Item } }
	local pot = MeetPayout.pot(lifters, settings)
	local placed = 0
	for _, lifter in ipairs(lifters) do
		if lifter.place and lifter.hasTotal then
			placed += 1
		end
	end
	local splits = settings.PlaceShares
	local shares = if placed > 0 then splits[math.min(placed, #splits)] else {}

	local result: { [number]: { Item } } = {}
	for _, lifter in ipairs(lifters) do
		local items: { Item } = {}
		local place = lifter.place
		if place and lifter.hasTotal then
			local share = shares[place]
			local amount = if share then math.floor(pot * share) else 0
			if amount > 0 then
				table.insert(items, { amount = amount, reason = placeText(place) })
			end
		end
		if lifter.hasTotal and settings.FinishBonus > 0 then
			table.insert(items, { amount = settings.FinishBonus, reason = "Finished with a total" })
		end
		if lifter.hasTotal and lifter.perfect and settings.PerfectBonus > 0 then
			table.insert(items, { amount = settings.PerfectBonus, reason = "9/9" })
		end
		result[lifter.key] = items
	end
	return result
end

--[[
	The bonus for the records one good lift broke (GAME_DESIGN 30.5): each
	broken record is worth GymRecordBonus when someone else held it,
	OwnGymRecordBonus when the lifter did, and nothing for an empty spot; the
	lift pays the best of those ONCE (a Total broken by the same lift is not
	paid again). `broken` is GymRecords' list: { record, previous = { userId }? }.
	Returns nil when it pays nothing.
]]
function MeetPayout.forGymRecord(userId: number, broken: { { record: string, previous: { userId: number }? } },
	settings: Settings): Item?
	local best: Item? = nil
	for _, record in ipairs(broken) do
		local previous = record.previous
		local item: Item? = nil
		if previous and previous.userId ~= userId and settings.GymRecordBonus > 0 then
			item = { amount = settings.GymRecordBonus, reason = "Gym record: " .. record.record }
		elseif previous and previous.userId == userId and settings.OwnGymRecordBonus > 0 then
			item = { amount = settings.OwnGymRecordBonus, reason = "Own gym record: " .. record.record }
		end
		if item and (best == nil or item.amount > (best :: Item).amount) then
			best = item
		end
	end
	return best
end

return MeetPayout
