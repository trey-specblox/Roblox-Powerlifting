--!strict
--[[
	CoinConfig
	Shared / Config

	The money system's settings (GAME_DESIGN.md 30.6, "The money system — first
	build", user 2026-10-30). One currency, COINS, earned at official meets and
	spent on cosmetic gear in the Shop. What a Local meet pays is LocalMeet
	below (step 3); the Shop's prices come with the Shop (step 4).
]]

local LiftAttemptConfig = require(script.Parent:WaitForChild("LiftAttemptConfig"))

local CoinConfig = {}

-- What the money is called on screens (user's pick).
CoinConfig.Name = "COINS"

--[[
	Safety limits (not balance): the most one add or spend may move, and the
	most a wallet may hold. A legitimate payout or price is far below both; a
	bigger number can only be a bug, so ProfileOperations refuses it instead
	of saving it.
]]
CoinConfig.MaxSingleChange = 1000000
CoinConfig.MaxBalance = 1000000000

--[[
	What a real meet pays at the LOCAL level (GAME_DESIGN §41.4, APPROVED by the user 2026-11-23: "Yea that works let's
	do 28000"). Every amount is multiplied by the meet's level (MeetLevelConfig potMultiplier: Local 1, Regional 2,
	State 3, Nationals 5). The user's rule: finishing a meet with a total (win or lose) pays enough for a crate (500),
	and all the bonuses together are worth one more crate. It replaced the old prize pot (100 + 50 a lifter, shared by
	place). Any real meet counts, computer-lifter meets included; never the Mock Meet; a bomb-out gets nothing.

		FinishBonus     every lifter who ends with a total
		PerfectBonus    9 good lifts of 9
		PlaceBonus      1st / 2nd / 3rd in the WHOLE field, computer lifters counted (at Nationals: in the class)
		GymRecordBonus  setting gym records at the meet, once a meet however many: someone else's record or your own;
		                an empty spot pays nothing (and a meet with only computer lifters sets no records, §37.2)
	500 + 200 + 200 + 100 = 1,000 at most, two crates.
]]
CoinConfig.LocalMeet = {
	FinishBonus = 500,
	PerfectBonus = 200,
	PlaceBonus = { 200, 130, 70 } :: { number },
	GymRecordBonus = 100,
	-- A good lift over the normal limit (LiftAttemptConfig.MeetCeilingPercent): this, plus OverLimitStepBonus for every
	-- full OverLimitStepPercent of CN past the limit. Each such lift pays, on top of everything else.
	OverLimitBonus = 50,
	OverLimitStepBonus = 25,
	OverLimitStepPercent = 0.05,
}

-- What a good meet lift at `percentOfCn` (1.3 = 130% of CN) pays for going over the normal limit; 0 at or under it.
function CoinConfig.overLimitCoins(percentOfCn: number): number
	local past = percentOfCn - LiftAttemptConfig.MaximumAttemptPercent
	if past <= 1e-6 then
		return 0
	end
	local settings = CoinConfig.LocalMeet
	return settings.OverLimitBonus
		+ settings.OverLimitStepBonus * math.floor(past / settings.OverLimitStepPercent + 1e-6)
end

-- The player attribute the server keeps at the player's balance, for screens (CoinDisplayService).
CoinConfig.BalanceAttribute = "Coins"

-- "1250" -> "1,250".
function CoinConfig.format(coins: number): string
	local text = tostring(math.floor(coins))
	local sign, digits = string.match(text, "^(%-?)(%d+)$")
	if digits == nil then
		return text
	end
	local grouped = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")))
	if string.sub(grouped, 1, 1) == "," then
		grouped = string.sub(grouped, 2)
	end
	return (sign or "") .. grouped
end

return CoinConfig
