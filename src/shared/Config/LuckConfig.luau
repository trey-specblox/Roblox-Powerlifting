--!strict
--[[
	LuckConfig
	Shared / Config

	The mafia boss cow's WHEEL OF LUCK and his games (GAME_DESIGN §40.7, user 2026-11-21):

		- LUCK is one multiplier on your chances at every rollable: gear crates, celebration spins, and the rare suit
		  a meet can drop. "You can only have one multiplier from the wheel": a new spin replaces the old one, better
		  or worse. It lasts LuckHours.
		- The wheel has good results and a bad one (0.8x, "so there is risk"), on every spin.
		- One FREE spin a day (UTC day). Beating the cow at a game earns a spin; each game costs one of the day's
		  tries (GameTriesPerDay), never luck, spins or coins. A Robux SPIN NOW is planned (SpinProductId, off at 0).

	NOTHING IS EVER BET. Roblox bans simulated gambling: no coins, items or Robux are staked on a game or a spin; the
	cow's games are skill games with a fixed reward; the wheel is a free daily reward. Once a spin can be BOUGHT the
	wheel is a "paid random item": every result's odds must be shown before buying (the wheel screen always shows
	them), the button must be hidden where PolicyService says paid random items are restricted, and anything that
	rolls with luck must show its REAL odds with the player's luck applied (LuckConfig.applyToOdds, used by the screens
	and by the server's rolls alike).

	THE NUMBERS BELOW ARE CLAUDE'S FIRST DRAFT (2026-11-21, built overnight with the user's go-ahead "Wheel plus the
	cow's games"), for the user to change: the results and how many wedges each has, the hours, the tries, the cap on
	suits. The wheel model has 20 equal wedges, so every result's chance is its wedges / 20 and the picture of the
	wheel never lies about the odds.
]]

local LuckConfig = {}

export type Prize = {
	id: string,
	multiplier: number,
	wedges: number,
	colour: Color3, -- the wedge's colour on the wheel and the result's colour on screens
	ink: Color3, -- the colour of the number written on it
}

-- The wheel's results, worst to best. Their wedges must add up to WedgeCount.
LuckConfig.WedgeCount = 20
LuckConfig.Prizes = {
	{ id = "x0.8", multiplier = 0.8, wedges = 3, colour = Color3.fromRGB(70, 70, 82), ink = Color3.fromRGB(255, 255, 255) },
	{ id = "x1.2", multiplier = 1.2, wedges = 6, colour = Color3.fromRGB(240, 232, 212), ink = Color3.fromRGB(30, 30, 36) },
	{ id = "x1.5", multiplier = 1.5, wedges = 5, colour = Color3.fromRGB(46, 150, 92), ink = Color3.fromRGB(255, 255, 255) },
	{ id = "x2", multiplier = 2, wedges = 3, colour = Color3.fromRGB(60, 120, 230), ink = Color3.fromRGB(255, 255, 255) },
	{ id = "x3", multiplier = 3, wedges = 2, colour = Color3.fromRGB(170, 84, 230), ink = Color3.fromRGB(255, 255, 255) },
	{ id = "x10", multiplier = 10, wedges = 1, colour = Color3.fromRGB(250, 196, 40), ink = Color3.fromRGB(30, 30, 36) },
} :: { Prize }

-- Which result each wedge carries, clockwise from the top (wedge 1 is under the pointer when the wheel is at rest),
-- spread so the same result is never side by side.
LuckConfig.Wedges = {
	"x10", "x1.2", "x1.5", "x0.8", "x1.2", "x2", "x1.5", "x1.2", "x3", "x1.5",
	"x0.8", "x1.2", "x2", "x1.5", "x1.2", "x3", "x1.5", "x0.8", "x1.2", "x2",
}

-- How long the wheel's multiplier lasts.
LuckConfig.LuckHours = 24
-- The cow's games: tries a day (all games together), and how many won spins can wait unused.
LuckConfig.GameTriesPerDay = 3
LuckConfig.MaxBankedSpins = 5
-- A meet's rare suit drop takes luck only up to this much (10x on the rarest thing in the game would flood it).
LuckConfig.SuitLuckCap = 3
-- The Robux SPIN NOW Developer Product (the user creates it on the Creator Dashboard). 0 = not sold: no button.
LuckConfig.SpinProductId = 0
-- Spinning and playing need the lifter in the back room: this close to the wheel (studs).
LuckConfig.Reach = 90

-- The player attributes the server keeps current for every screen that shows odds (LuckService).
LuckConfig.MultiplierAttribute = "Luck"
LuckConfig.EndsAtAttribute = "LuckEndsAt" -- server unix time (compare with Workspace:GetServerTimeNow())

-- The cloche shuffle ("follow the steak"): the cow hides a steak under one of three cloches and swaps them.
LuckConfig.Shuffle = {
	Swaps = 9,
	-- Seconds for the first and the last swap (they get faster), the show before them and the time to answer.
	FirstSwapSeconds = 0.62,
	LastSwapSeconds = 0.3,
	RevealSeconds = 2.2,
	AnswerSeconds = 12,
}

-- The seconds swap `index` (1..Swaps) of the shuffle takes: they get faster.
function LuckConfig.swapSeconds(index: number): number
	local shuffle = LuckConfig.Shuffle
	local share = if shuffle.Swaps > 1 then (index - 1) / (shuffle.Swaps - 1) else 0
	return shuffle.FirstSwapSeconds + (shuffle.LastSwapSeconds - shuffle.FirstSwapSeconds) * share
end

local byId: { [string]: Prize } = {}
for _, prize in ipairs(LuckConfig.Prizes) do
	byId[prize.id] = prize
end

function LuckConfig.prize(id: any): Prize?
	return if typeof(id) == "string" then byId[id] else nil
end

-- The result on wedge `index` (1..WedgeCount), or nil.
function LuckConfig.wedgePrize(index: any): Prize?
	if typeof(index) ~= "number" or index ~= math.floor(index) then
		return nil
	end
	return byId[LuckConfig.Wedges[index] or ""]
end

-- A result's chance on one spin (0..1).
function LuckConfig.chance(prize: Prize): number
	return prize.wedges / LuckConfig.WedgeCount
end

-- "1.5x", "10x", "0.8x".
function LuckConfig.multiplierText(multiplier: number): string
	if math.abs(multiplier - math.floor(multiplier + 0.5)) < 0.005 then
		return string.format("%dx", math.floor(multiplier + 0.5))
	end
	return (string.format("%.2f", multiplier):gsub("0+$", "")) .. "x"
end

-- Whether `value` is a usable luck multiplier (the lowest and highest the wheel can give).
function LuckConfig.isMultiplier(value: any): boolean
	return typeof(value) == "number" and value == value and value >= 0.5 and value <= 10
end

--[[
	The real odds of a list of results under `luck`. `odds` runs from the most common result to the rarest (each a
	share of 1, adding up to 1); the answer is the same list with luck applied.

	Luck is a true multiplier on the rare results: from the rarest down, each result's chance is its own times `luck`
	(as far as the 100% lasts), and the most common result takes whatever is left. So 2x luck is twice the chance of
	a Legendary, an Epic, a Rare and an Uncommon, and 0.8x is 0.8 times each. With luck 1 the list is unchanged.
]]
function LuckConfig.applyToOdds(odds: { number }, luck: number): { number }
	local out = table.create(#odds, 0)
	if not LuckConfig.isMultiplier(luck) or #odds == 0 then
		for index, value in ipairs(odds) do
			out[index] = value
		end
		return out
	end
	local left = 1
	for index = #odds, 2, -1 do
		local share = math.clamp(odds[index] * luck, 0, left)
		out[index] = share
		left -= share
	end
	out[1] = math.max(left, 0)
	return out
end

-- The real odds of a list of rarities (each with `odds`, most common first, as GearStatsConfig.Rarities) under `luck`.
function LuckConfig.rarityOdds(rarities: { { odds: number } }, luck: number): { number }
	local odds = table.create(#rarities, 0)
	for index, rarity in ipairs(rarities) do
		odds[index] = rarity.odds
	end
	return LuckConfig.applyToOdds(odds, luck)
end

-- "60%", "37.5%", "0.8%": a chance for a screen.
function LuckConfig.percentText(chance: number): string
	local percent = chance * 100
	if math.abs(percent - math.floor(percent + 0.5)) < 0.05 then
		return string.format("%d%%", math.floor(percent + 0.5))
	end
	return string.format("%.1f%%", percent)
end

-- A yes-or-no drop's chance under `luck`, capped at `cap` times its own chance when a cap is given.
function LuckConfig.applyToChance(chance: number, luck: number, cap: number?): number
	if not LuckConfig.isMultiplier(luck) then
		return chance
	end
	return math.clamp(chance * (if cap then math.min(luck, cap) else luck), 0, 1)
end

-- The multiplier a player has right now, from their attributes (clients; `now` = Workspace:GetServerTimeNow()).
function LuckConfig.ofPlayer(player: Player, now: number): number
	local multiplier = player:GetAttribute(LuckConfig.MultiplierAttribute)
	local endsAt = player:GetAttribute(LuckConfig.EndsAtAttribute)
	if LuckConfig.isMultiplier(multiplier) and typeof(endsAt) == "number" and endsAt > now then
		return multiplier :: number
	end
	return 1
end

do
	local wedges = 0
	for _, prize in ipairs(LuckConfig.Prizes) do
		assert(LuckConfig.isMultiplier(prize.multiplier) and prize.wedges >= 1, "[LuckConfig] bad prize " .. prize.id)
		wedges += prize.wedges
	end
	assert(wedges == LuckConfig.WedgeCount and #LuckConfig.Wedges == LuckConfig.WedgeCount,
		"[LuckConfig] the prizes' wedges must add up to WedgeCount")
	local counted: { [string]: number } = {}
	for _, id in ipairs(LuckConfig.Wedges) do
		assert(byId[id] ~= nil, "[LuckConfig] wedge with an unknown prize " .. id)
		counted[id] = (counted[id] or 0) + 1
	end
	for _, prize in ipairs(LuckConfig.Prizes) do
		assert(counted[prize.id] == prize.wedges, "[LuckConfig] the wheel's wedges don't match prize " .. prize.id)
	end
end

return LuckConfig
