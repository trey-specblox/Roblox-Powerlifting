--!strict
--[[
	CoinConfig
	Shared / Config

	The money system's settings (GAME_DESIGN.md 30.6, "The money system — first
	build", user 2026-10-30). One currency, COINS, earned at official meets and
	spent on cosmetic gear in the Shop. The amounts meets pay are added with
	the meets' payout (build step 3); the Shop's prices with the Shop (step 4).
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

return CoinConfig
