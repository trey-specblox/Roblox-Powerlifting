--!strict
--[[
	MeetPayout
	Server / Meet

	Works out what a real meet pays each lifter in coins (GAME_DESIGN §41.4, which replaced 30.6's prize pot). Pure: it
	only does the sums from the settings (CoinConfig.LocalMeet) and the meet's result; the meet pays the coins itself
	through PlayerDataService.addCoins. Every amount is times the meet level's multiplier (Local 1 ... Nationals 5),
	except the over-the-limit bonus.

		forMeet      finishing, 9/9 and place, per lifter
		forGymRecord the once-a-meet bonus for setting gym records
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoinConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CoinConfig"))

local MeetPayout = {}

export type Settings = typeof(CoinConfig.LocalMeet)

-- One lifter's meet result, as far as money goes.
export type Lifter = {
	key: number,
	-- 1 = first in the whole field (computer lifters counted), nil without a total.
	place: number?,
	hasTotal: boolean,
	-- 9 good lifts of 9.
	perfect: boolean,
	-- Good lifts over the normal limit (GAME_DESIGN §37.5): each pays CoinConfig.overLimitCoins, on top of the rest.
	overLimit: { { lift: string, percentOfCn: number } }?,
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

--[[
	Every lifter's payments, by key (a lifter who earns nothing has an empty list): with a total, the finishing pay, the
	9/9 bonus and a top-3 place bonus, each times `multiplier`; and the over-the-limit bonus for each such lift.
]]
function MeetPayout.forMeet(lifters: { Lifter }, settings: Settings, multiplier: number?): { [number]: { Item } }
	local m = multiplier or 1
	local result: { [number]: { Item } } = {}
	for _, lifter in ipairs(lifters) do
		local items: { Item } = {}
		if lifter.hasTotal then
			table.insert(items, { amount = settings.FinishBonus * m, reason = "Finished with a total" })
			if lifter.perfect then
				table.insert(items, { amount = settings.PerfectBonus * m, reason = "9/9" })
			end
			local place = lifter.place
			local bonus = if place then settings.PlaceBonus[place] else nil
			if place and bonus and bonus > 0 then
				table.insert(items, { amount = bonus * m, reason = placeText(place) })
			end
		end
		if lifter.hasTotal then
			for _, heavy in ipairs(lifter.overLimit or {}) do
				local amount = CoinConfig.overLimitCoins(heavy.percentOfCn)
				if amount > 0 then
					table.insert(items, { amount = amount, reason = string.format("Over the limit: %s %d%%", heavy.lift,
						math.floor(heavy.percentOfCn * 100 + 0.5)) })
				end
			end
		end
		result[lifter.key] = items
	end
	return result
end

--[[
	The gym record bonus (GAME_DESIGN §41.4): GymRecordBonus x `multiplier` ONCE A MEET, however many records the lifter
	sets there (`alreadyPaid` = this meet has paid it already). A record someone held, or the lifter's own, counts; an
	empty spot pays nothing. `broken` is GymRecords' list: { record, previous = { userId }? }. Nil when it pays nothing.
]]
function MeetPayout.forGymRecord(userId: number, broken: { { record: string, previous: { userId: number }? } },
	settings: Settings, multiplier: number?, alreadyPaid: boolean?): Item?
	if alreadyPaid or settings.GymRecordBonus <= 0 then
		return nil
	end
	for _, record in ipairs(broken) do
		local previous = record.previous
		if previous then
			return {
				amount = settings.GymRecordBonus * (multiplier or 1),
				reason = (if previous.userId == userId then "Own gym record: " else "Gym record: ") .. record.record,
			}
		end
	end
	return nil
end

return MeetPayout
