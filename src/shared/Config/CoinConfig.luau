--!strict
--[[
	CoinConfig
	Shared / Config

	The money system's settings (GAME_DESIGN.md 30.6, "The money system — first
	build", user 2026-10-30). One currency, COINS, earned at official meets and
	spent on cosmetic gear in the Shop. What a Local meet pays is LocalMeet
	below (step 3); the Shop's prices come with the Shop (step 4).
]]

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
	[PROVISIONAL] What an OFFICIAL Local meet pays (GAME_DESIGN 30.6; only a
	meet that rewards, never a Solo / Mock Meet). Balance numbers: change them
	freely here.

		BasePot + PerQualifiedLifter x qualified lifters (a lifter who started
		at least one lift) = the prize pot, shared by place among the lifters
		with a total: PlaceShares[number placed] (more than 3 placed use the
		3-place split; places past 3rd get no share)
		FinishBonus   every lifter who ends with a total
		PerfectBonus  9 good lifts of 9
		GymRecordBonus / OwnGymRecordBonus   taking a gym record someone else
		              holds / beating your own; an empty spot pays nothing; one
		              bonus per lift (a Total broken by the same lift is not
		              paid again)
]]
CoinConfig.LocalMeet = {
	BasePot = 100,
	PerQualifiedLifter = 50,
	PlaceShares = {
		{ 1 },
		{ 0.6, 0.4 },
		{ 0.5, 0.3, 0.2 },
	} :: { { number } },
	FinishBonus = 25,
	PerfectBonus = 50,
	GymRecordBonus = 150,
	OwnGymRecordBonus = 40,
}

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
