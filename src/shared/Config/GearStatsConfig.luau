--!strict
--[[
	GearStatsConfig
	Shared / Config

	Gear with stats (GAME_DESIGN.md §35.12, user 2026-11-06, picked from options): what
	each rarity gives, which lifts each piece helps, and the crates. The server reads
	every number from here, never from a client; the client reads the same list to draw
	the menus. All [PROVISIONAL]: a piece saves only its rarity, so changing a number
	here rebalances every piece already owned, with no save change.

	Gear never raises Competition Number: technique makes a lift easier to perform and
	training speed is technique training only.

	A rarity's `id` is saved in players' inventories, so never rename or reuse one.
]]

local GearStatsConfig = {}

export type Rarity = {
	id: string,
	-- The chance a crate gives this rarity, the same in every crate. They add up to 1.
	odds: number,
	-- Added to effective technique on every lift this piece helps.
	technique: number,
	-- Added to technique training speed on those lifts (0.1 = +10%).
	trainingSpeed: number,
	-- The coins a piece scraps for.
	scrap: number,
	colour: Color3,
}

-- One crate at the Shop. Its id is only sent when asking to open one; it is never saved.
export type Crate = {
	id: string,
	-- The WornGearConfig slot of everything inside.
	slot: string,
	name: string,
	-- The menu's short name for it.
	button: string,
	price: number,
	-- The crate model's body colour.
	colour: Color3,
}

local rgb = Color3.fromRGB

-- Lowest to highest.
GearStatsConfig.Rarities = {
	{ id = "Common", odds = 0.60, technique = 1, trainingSpeed = 0.02, scrap = 50, colour = rgb(176, 178, 186) },
	{ id = "Uncommon", odds = 0.25, technique = 1.5, trainingSpeed = 0.03, scrap = 100, colour = rgb(84, 200, 96) },
	{ id = "Rare", odds = 0.10, technique = 2, trainingSpeed = 0.05, scrap = 200, colour = rgb(70, 146, 255) },
	{ id = "Epic", odds = 0.04, technique = 3, trainingSpeed = 0.07, scrap = 400, colour = rgb(176, 96, 240) },
	{ id = "Legendary", odds = 0.01, technique = 4, trainingSpeed = 0.10, scrap = 800, colour = rgb(250, 206, 36) },
} :: { Rarity }

-- WornGearConfig slot -> the lifts a piece in it helps. Every lift has three pieces.
GearStatsConfig.SlotLifts = {
	KneeSleeves = { Squat = true },
	Belt = { Squat = true, Bench = true, Deadlift = true },
	WristWraps = { Bench = true, Deadlift = true },
	Singlet = { Squat = true, Bench = true, Deadlift = true },
} :: { [string]: { [string]: boolean } }

-- Gear's total technique training speed on one lift stops here.
GearStatsConfig.MaxTrainingSpeed = 0.25

-- One crate per item (user 2026-11-06: "every item to have its own crate"). [PROVISIONAL] all the same price.
GearStatsConfig.Crates = {
	{ id = "Belt", slot = "Belt", name = "BELT CRATE", button = "BELT", price = 500, colour = rgb(28, 44, 100) },
	{ id = "WristWraps", slot = "WristWraps", name = "WRIST WRAP CRATE", button = "WRAPS", price = 500, colour = rgb(150, 28, 36) },
	{ id = "Singlet", slot = "Singlet", name = "SINGLET CRATE", button = "SINGLET", price = 500, colour = rgb(16, 110, 110) },
	{ id = "KneeSleeves", slot = "KneeSleeves", name = "KNEE SLEEVE CRATE", button = "SLEEVES", price = 500, colour = rgb(44, 46, 54) },
} :: { Crate }
-- How many stat pieces a player can hold: a full inventory has to scrap before opening another crate.
GearStatsConfig.MaxPieces = 100

-- The crate's sounds, played on the player's own screen: Drop, Rattle and Open through its intro, Tick for the reel's
-- cards passing, Big for Epic and up.
GearStatsConfig.Sounds = {
	Open = "rbxassetid://78601167944819",
	Big = "rbxassetid://93621931694016",
	Tick = "rbxassetid://77524292668778",
	Drop = "rbxassetid://89711320801766",
	Rattle = "rbxassetid://104195321031097",
}
GearStatsConfig.BigFrom = "Epic"

--[[
	The crate's intro before the reel (client ShopMenu, user 2026-11-06), in seconds: it drops onto the
	platform, rattles, its latches snap, its lid flies up and a circle of light fills the panel.
]]
GearStatsConfig.CrateIntro = {
	DropSeconds = 0.4,
	DropHeight = 8,
	BounceSeconds = 0.3,
	BounceHeight = 0.2,
	RattleSeconds = 0.75,
	RattleDegrees = 3,
	-- Each latch, the second starting this long after the first.
	LatchSeconds = 0.14,
	LatchGap = 0.14,
	-- The lid starts this long after the first latch.
	LidAfter = 0.32,
	LidSeconds = 0.42,
	LidDegrees = 105,
	LatchDegrees = 100,
	-- The light starts this long after the lid and takes this long to fill the panel, then this long to fade off the reel.
	FlashAfter = 0.12,
	FlashSeconds = 0.34,
	FadeSeconds = 0.3,
}

--[[
	The reel a crate opens with (client ShopMenu, user 2026-11-06). Display only: the server
	has already rolled what is inside, and the reel lands on that. The other cards are rolled
	on the same odds, so the reel never fakes a near miss.
]]
GearStatsConfig.Reel = {
	Seconds = 5.5,
	-- How many cards the strip has, and which one is the prize (some after it, so it doesn't end on the prize).
	Cards = 34,
	PrizeAt = 29,
	-- In the Shop's design size: the card, the gap between cards, and how far off the middle of the prize the marker may stop.
	CardWidth = 170,
	CardHeight = 210,
	Gap = 8,
	StopOffset = 60,
	-- The tick as each card passes, at most this many a second.
	TicksPerSecond = 18,
	-- How long the prize stays under the marker before the result shows.
	HoldSeconds = 0.9,
}

do
	local total = 0
	for _, rarity in ipairs(GearStatsConfig.Rarities) do
		total += rarity.odds
		assert(rarity.scrap > 0 and rarity.scrap == math.floor(rarity.scrap), "[GearStatsConfig] a scrap value is unusable")
	end
	assert(math.abs(total - 1) < 1e-9, "[GearStatsConfig] the crate's odds do not add up to 1")
	for _, crate in ipairs(GearStatsConfig.Crates) do
		assert(GearStatsConfig.SlotLifts[crate.slot] ~= nil, "[GearStatsConfig] a crate holds an unknown item")
	end
end

return GearStatsConfig
