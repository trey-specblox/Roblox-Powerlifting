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

	THE WHEEL'S RESULTS (user 2026-11-22: "Add more things you can roll for, like 10x, 9x ... 0.1x ... bunch them up
	... this makes it even more rare to get 10x and makes players want to keep spinning"): the wheel's 20 equal wedges
	are six BANDS of results. A spin lands on a wedge (a band's chance is its wedges / 20, so the picture of the wheel
	never lies about the odds), and then one of that band's results is drawn, each as likely as the next: whole
	numbers from 10x down to 4x in the top band, every tenth below that.

		4x to 10x      1 wedge   5%     (7 results: 10x is 1 spin in 140)
		2.1x to 3x     2 wedges  10%
		1.6x to 2x     3 wedges  15%
		1.3x to 1.5x   5 wedges  25%
		0.9x to 1.2x   6 wedges  30%
		0.1x to 0.8x   3 wedges  15%

	The user's message gave five of the six chances (5, 10, 15, 30, 15: 75% in all) with ranges that overlap, so the
	bands' edges and the 25 / 30 split were Claude's reading of it (the old wheel's chances kept, each old result now
	the top of a band). APPROVED by the user 2026-11-22 ("Yes, keep them ... Yes the wheel is good"; the idea, in the
	user's words: "like games that have clans or styles, and there is multiple legendaries, you role a legendary and
	you only get 1 out of lets say 10 legendaries"). The tries and the cap on suits are still Claude's draft.
]]

local LuckConfig = {}

-- A band of results: every multiplier from `low` to `high` in steps of `step`, each as likely as the next.
export type Prize = {
	id: string,
	low: number,
	high: number,
	step: number,
	wedges: number,
	colour: Color3, -- the wedge's colour on the wheel and the band's colour on screens
	ink: Color3, -- the colour of the numbers written on it
}

-- The wheel's bands, worst to best. Their wedges must add up to WedgeCount.
LuckConfig.WedgeCount = 20
LuckConfig.Prizes = {
	{ id = "low", low = 0.1, high = 0.8, step = 0.1, wedges = 3, colour = Color3.fromRGB(70, 70, 82), ink = Color3.fromRGB(255, 255, 255) },
	{ id = "even", low = 0.9, high = 1.2, step = 0.1, wedges = 6, colour = Color3.fromRGB(240, 232, 212), ink = Color3.fromRGB(30, 30, 36) },
	{ id = "good", low = 1.3, high = 1.5, step = 0.1, wedges = 5, colour = Color3.fromRGB(46, 150, 92), ink = Color3.fromRGB(255, 255, 255) },
	{ id = "great", low = 1.6, high = 2, step = 0.1, wedges = 3, colour = Color3.fromRGB(60, 120, 230), ink = Color3.fromRGB(255, 255, 255) },
	{ id = "rare", low = 2.1, high = 3, step = 0.1, wedges = 2, colour = Color3.fromRGB(170, 84, 230), ink = Color3.fromRGB(255, 255, 255) },
	{ id = "top", low = 4, high = 10, step = 1, wedges = 1, colour = Color3.fromRGB(250, 196, 40), ink = Color3.fromRGB(30, 30, 36) },
} :: { Prize }

-- Which band each wedge carries, clockwise from the top (wedge 1 is under the pointer when the wheel is at rest),
-- spread so the same band is never side by side.
LuckConfig.Wedges = {
	"top", "even", "good", "low", "even", "great", "good", "even", "rare", "good",
	"low", "even", "great", "good", "even", "rare", "good", "low", "even", "great",
}

-- The lowest and the highest multiplier any band can give.
LuckConfig.LowestMultiplier = 0.1
LuckConfig.HighestMultiplier = 10

-- How long the wheel's multiplier lasts: good luck (and an even 1x) LuckHours, bad luck (below 1x) only BadLuckHours
-- (user 2026-11-22: "Keep the bad luck, make it last 2 hours ... after 2 hours their luck goes back to 1.0x"). Bad
-- luck gives no extra spin: the next spin is still tomorrow's free one or one won from the Boss.
LuckConfig.LuckHours = 24
LuckConfig.BadLuckHours = 2

-- The hours a result of `multiplier` lasts.
function LuckConfig.hoursFor(multiplier: number): number
	return if multiplier < 1 then LuckConfig.BadLuckHours else LuckConfig.LuckHours
end
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
	-- The swaps take ShuffleSeconds in all (user 2026-11-22: "make the game shuffle around the plates 11 seconds")
	-- and get faster: the first swap is FirstToLast times as long as the last (0.62 s down to 0.3 s with these).
	Swaps = 24,
	ShuffleSeconds = 11,
	FirstToLast = 2.1,
	-- The show of the steak before the swaps.
	RevealSeconds = 2.2,
	-- The time to pick a cloche, counted down on screen (user 2026-11-22: "add a time limit ... 10 seconds").
	AnswerSeconds = 10,
}

-- The seconds swap `index` (1..Swaps) of the shuffle takes: they get faster, and add up to ShuffleSeconds.
function LuckConfig.swapSeconds(index: number): number
	local shuffle = LuckConfig.Shuffle
	local share = if shuffle.Swaps > 1 then (index - 1) / (shuffle.Swaps - 1) else 0
	local weight = shuffle.FirstToLast + (1 - shuffle.FirstToLast) * share
	return shuffle.ShuffleSeconds * weight / (shuffle.Swaps * (shuffle.FirstToLast + 1) / 2)
end

local byId: { [string]: Prize } = {}
for _, prize in ipairs(LuckConfig.Prizes) do
	byId[prize.id] = prize
end

-- A multiplier as the wheel writes it: one decimal place, no float dust (0.30000000000000004 is 0.3).
local function tidy(multiplier: number): number
	return math.floor(multiplier * 10 + 0.5) / 10
end

-- Every result of a band, lowest first.
function LuckConfig.bandValues(prize: Prize): { number }
	local values: { number } = {}
	local count = math.floor((prize.high - prize.low) / prize.step + 0.5)
	for index = 0, count do
		table.insert(values, tidy(prize.low + index * prize.step))
	end
	return values
end

-- Whether `multiplier` is one of the band's results.
function LuckConfig.inBand(prize: Prize, multiplier: any): boolean
	if typeof(multiplier) ~= "number" or multiplier ~= multiplier then
		return false
	end
	for _, value in ipairs(LuckConfig.bandValues(prize)) do
		if math.abs(value - multiplier) < 0.001 then
			return true
		end
	end
	return false
end

-- One of the band's results, each as likely as the next (the server's roll, after the wedge).
function LuckConfig.rollIn(prize: Prize, random: Random): number
	local values = LuckConfig.bandValues(prize)
	return values[random:NextInteger(1, #values)]
end

-- The chance of ONE result of a band on one spin (0..1): the band's chance shared between its results.
function LuckConfig.resultChance(prize: Prize): number
	return prize.wedges / LuckConfig.WedgeCount / #LuckConfig.bandValues(prize)
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

-- A band's chance on one spin (0..1).
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

-- A band for a screen ("4x to 10x") and for its wedge on the wheel ("4-10x").
function LuckConfig.bandText(prize: Prize): string
	return LuckConfig.multiplierText(prize.low) .. " to " .. LuckConfig.multiplierText(prize.high)
end
function LuckConfig.bandShort(prize: Prize): string
	return (LuckConfig.multiplierText(prize.low):gsub("x$", "")) .. "-" .. LuckConfig.multiplierText(prize.high)
end

-- Whether `value` is a usable luck multiplier (between the lowest and the highest the wheel can give).
function LuckConfig.isMultiplier(value: any): boolean
	return typeof(value) == "number" and value == value and value >= LuckConfig.LowestMultiplier - 0.001
		and value <= LuckConfig.HighestMultiplier + 0.001
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
		assert(LuckConfig.isMultiplier(prize.low) and LuckConfig.isMultiplier(prize.high) and prize.high >= prize.low
			and prize.step > 0 and prize.wedges >= 1, "[LuckConfig] bad band " .. prize.id)
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
