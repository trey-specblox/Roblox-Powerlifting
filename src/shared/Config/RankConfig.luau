--!strict
--[[
	RankConfig
	Shared / Config

	RANKS AND TITLES (GAME_DESIGN §41, user 2026-11-23, picked from Claude's options).

	A lifter's RANK comes from the best total they have made at a real meet (Local and up, computer lifters included;
	never the Mock Meet), scored in the IPF GL points the meets already rank by (MeetPlacing.points), so every weight
	class is judged the same way. A rank never goes down. The ladder is 12 fun names, each with levels I to V (60 ranks),
	built for about 3 months of daily play; later updates may add ranks ON TOP (never renumbering these), so nobody's
	rank is ever reset (§41 "SCOPE: THE FIRST 3 MONTHS").

	Every rank-up pays a free crate and coins that grow with the rank; reaching a new name also doubles the lifter's luck
	for 24 hours (stacking with the cow's wheel, total capped at LuckBoost.Cap; a meet's rare suit drop keeps its own cap).

	TITLES are earned feats; the lifter picks one to show under their name. The meet titles (career.titles,
	MeetLevelConfig.Titles) are titles too.

	[PROVISIONAL] every number here: the thresholds come from a simulation of the game's progression (§41.2) and are to be
	tuned after real playtests.
]]

local RankConfig = {}

-- The 12 names, lowest first (user 2026-11-23: fun gym names).
RankConfig.Names = {
	"Fresh Chalk", "Plate Loader", "Bar Bender", "Gym Regular", "Iron Addict", "Platform Pro",
	"Big Total", "Plate Crusher", "Meet Monster", "Iron Titan", "Record Breaker", "Strength God",
} :: { string }

RankConfig.LevelsPerName = 5
RankConfig.Roman = { "I", "II", "III", "IV", "V" } :: { string }

--[[
	The GL points each rank needs, rank 1 first (rank 1 = any meet total). From the §41.2 simulation: a player who uses
	all their training and meets every day reaches rank k on day about 90 x ((k - 1) / 59)^2, so about 7 ranks on day 1,
	about one a day by the second week and one every 2 to 3 days near the top (Strength God V about day 90).
]]
RankConfig.Points = {
	0, 12.5, 13, 13.5, 14,
	14.5, 15, 16, 17, 18,
	19.5, 21, 22.5, 24, 26,
	28, 30, 32.5, 34.5, 37,
	40, 42.5, 45.5, 48.5, 51.5,
	55, 58.5, 61.5, 65, 68.5,
	72, 75.5, 79, 82.5, 86,
	89.5, 92.5, 95.5, 98.5, 101.5,
	104, 106.5, 109, 111.5, 114,
	116, 118.5, 120.5, 122.5, 124.5,
	126, 128, 129.5, 131.5, 133,
	134.5, 136, 137.5, 139, 140.5,
} :: { number }

RankConfig.Count = #RankConfig.Points

export type Rank = {
	index: number, -- 1 .. Count
	tier: number, -- which name, 1 .. #Names
	level: number, -- 1 .. LevelsPerName
	name: string, -- "Bar Bender"
	label: string, -- "Bar Bender III"
	points: number, -- the GL points it needs
	coins: number, -- what reaching it pays
	newName: boolean, -- the first rank of a name (level I, from rank 6 up): it also pays the luck boost
}

-- Coins for reaching rank `index` (user: "crates + growing coins"): 50 for rank 1, +10 a rank.
function RankConfig.coinsFor(index: number): number
	return 50 + 10 * (index - 1)
end

-- A free crate on every rank-up (user: "Let's have a player earn a crate every level").
RankConfig.CratesPerRank = 1

-- The luck boost a new name pays: luck in force x Factor for Hours, never above Cap in all.
RankConfig.LuckBoost = {
	Factor = 2,
	Hours = 24,
	Cap = 10,
}

RankConfig.Ranks = {} :: { Rank }
for index, points in ipairs(RankConfig.Points) do
	local tier = (index - 1) // RankConfig.LevelsPerName + 1
	local level = (index - 1) % RankConfig.LevelsPerName + 1
	local name = RankConfig.Names[tier]
	RankConfig.Ranks[index] = {
		index = index,
		tier = tier,
		level = level,
		name = name,
		label = name .. " " .. RankConfig.Roman[level],
		points = points,
		coins = RankConfig.coinsFor(index),
		newName = level == 1 and tier > 1,
	}
end

-- The rank (index) a best of `points` GL reaches, or 0 for no meet total yet. `hasTotal`: whether any total exists.
function RankConfig.rankFor(points: number, hasTotal: boolean): number
	if not hasTotal or typeof(points) ~= "number" or points ~= points then
		return 0
	end
	local reached = 1
	for index, needed in ipairs(RankConfig.Points) do
		if points >= needed then
			reached = index
		else
			break
		end
	end
	return reached
end

--[[
	TITLES. `tier` is how rare and grand it looks (1 Common, 2 Rare, 3 Epic, 4 Legendary); `how` is the hint a locked
	title shows. FEATS are checked by the server at the end of a real meet (LocalMeetService); MEET titles come from
	the meet's placing (MeetLevelConfig.Titles, kept in career.titles with a count).
]]
export type TitleTier = number
export type Title = {
	id: string,
	name: string,
	how: string,
	tier: TitleTier,
	group: string, -- "Feats", "Clubs", "Meets"
	order: number,
}

RankConfig.TierNames = { "COMMON", "RARE", "EPIC", "LEGENDARY" } :: { string }

local titles: { Title } = {}
local function title(id: string, name: string, how: string, tier: number, group: string)
	table.insert(titles, { id = id, name = name, how = how, tier = tier, group = group, order = #titles + 1 })
end

-- Feats (user-approved list, §41.2).
title("NineForNine", "Nine for Nine", "Go 9/9 at a real meet", 2, "Feats")
title("Clutch", "Clutch", "Make your third attempt after missing the first two on that lift", 2, "Feats")
title("IronStreak", "Iron Streak", "Finish a real meet on 7 days in a row", 2, "Feats")
title("GymRecordHolder", "Gym Record Holder", "Set a gym record", 3, "Feats")
-- Total clubs.
title("Total300", "300 kg Total Club", "Make a 300 kg total at a meet", 1, "Clubs")
title("Total500", "500 kg Total Club", "Make a 500 kg total at a meet", 2, "Clubs")
title("Total700", "700 kg Total Club", "Make a 700 kg total at a meet", 3, "Clubs")
-- Lift clubs (a good lift at a meet).
title("Squat100", "100 kg Squat Club", "Squat 100 kg at a meet", 1, "Clubs")
title("Squat200", "200 kg Squat Club", "Squat 200 kg at a meet", 2, "Clubs")
title("Squat300", "300 kg Squat Club", "Squat 300 kg at a meet", 3, "Clubs")
title("Bench100", "100 kg Bench Club", "Bench 100 kg at a meet", 1, "Clubs")
title("Bench150", "150 kg Bench Club", "Bench 150 kg at a meet", 2, "Clubs")
title("Bench200", "200 kg Bench Club", "Bench 200 kg at a meet", 3, "Clubs")
title("Deadlift150", "150 kg Deadlift Club", "Deadlift 150 kg at a meet", 1, "Clubs")
title("Deadlift250", "250 kg Deadlift Club", "Deadlift 250 kg at a meet", 2, "Clubs")
title("Deadlift350", "350 kg Deadlift Club", "Deadlift 350 kg at a meet", 3, "Clubs")
-- The meet titles (their names live in MeetLevelConfig.Titles; the count shows as "2x").
title("RegionalThird", "Regional 3rd Place", "Place 3rd at a Regional meet", 1, "Meets")
title("RegionalRunnerUp", "Regional Runner-up", "Place 2nd at a Regional meet", 2, "Meets")
title("RegionalChampion", "Regional Champion", "Win a Regional meet", 2, "Meets")
title("StateThird", "State 3rd Place", "Place 3rd at a State meet", 2, "Meets")
title("StateRunnerUp", "State Runner-up", "Place 2nd at a State meet", 3, "Meets")
title("StateChampion", "State Champion", "Win a State meet", 3, "Meets")
title("NationalsThird", "National 3rd Place", "Place 3rd in your class at Nationals", 3, "Meets")
title("NationalsRunnerUp", "National Runner-up", "Place 2nd in your class at Nationals", 4, "Meets")
title("NationalsChampion", "National Champion", "Win your class at Nationals", 4, "Meets")

RankConfig.Titles = titles
RankConfig.TitleById = {} :: { [string]: Title }
for _, entry in ipairs(titles) do
	RankConfig.TitleById[entry.id] = entry
end

-- Feat titles kept in the ranks record (the meet titles stay in career.titles).
function RankConfig.isFeat(id: string): boolean
	local entry = RankConfig.TitleById[id]
	return entry ~= nil and entry.group ~= "Meets"
end

-- The lift clubs: lift -> { { kg, id }, ... } lowest first.
RankConfig.LiftClubs = {
	Squat = { { kg = 100, id = "Squat100" }, { kg = 200, id = "Squat200" }, { kg = 300, id = "Squat300" } },
	Bench = { { kg = 100, id = "Bench100" }, { kg = 150, id = "Bench150" }, { kg = 200, id = "Bench200" } },
	Deadlift = { { kg = 150, id = "Deadlift150" }, { kg = 250, id = "Deadlift250" }, { kg = 350, id = "Deadlift350" } },
} :: { [string]: { { kg: number, id: string } } }

RankConfig.TotalClubs = { { kg = 300, id = "Total300" }, { kg = 500, id = "Total500" }, { kg = 700, id = "Total700" } }

-- Iron Streak: real meets finished on this many UTC days in a row.
RankConfig.StreakDays = 7

--[[
	HOW THEY LOOK (References/Ranks and Titles Study.md). Every name has its own MATERIAL, in an order anyone can read
	(the Deadlock lesson: fun names need a visible order): plain and cool at the bottom, warm, shiny and glowing at the
	top. Only Strength God is animated. `top`/`bottom` fill the emblem, `rim` is its edge, `glow` its soft light.
	`Images` holds the Blender-rendered emblem pictures once uploaded (rbxassetid per name; empty = drawn in code).
]]
export type TierLook = { material: string, top: Color3, bottom: Color3, rim: Color3, glow: Color3, animated: boolean }
local function look(material: string, top: { number }, bottom: { number }, rim: { number }, glow: { number }, animated: boolean?): TierLook
	return {
		material = material,
		top = Color3.fromRGB(top[1], top[2], top[3]),
		bottom = Color3.fromRGB(bottom[1], bottom[2], bottom[3]),
		rim = Color3.fromRGB(rim[1], rim[2], rim[3]),
		glow = Color3.fromRGB(glow[1], glow[2], glow[3]),
		animated = animated == true,
	}
end
RankConfig.TierLooks = {
	look("Chalk", { 250, 250, 246 }, { 196, 198, 192 }, { 120, 122, 118 }, { 255, 255, 255 }),
	look("Rubber", { 92, 94, 104 }, { 34, 35, 42 }, { 12, 12, 16 }, { 150, 150, 170 }),
	look("Iron", { 168, 156, 144 }, { 92, 82, 74 }, { 56, 48, 42 }, { 200, 180, 160 }),
	look("Blue steel", { 150, 190, 235 }, { 54, 88, 146 }, { 28, 46, 88 }, { 120, 180, 255 }),
	look("Bronze", { 240, 170, 108 }, { 150, 82, 36 }, { 96, 50, 20 }, { 255, 160, 90 }),
	look("Silver", { 250, 252, 255 }, { 150, 160, 176 }, { 92, 100, 116 }, { 220, 235, 255 }),
	look("Gold", { 255, 232, 120 }, { 214, 146, 18 }, { 140, 92, 8 }, { 255, 200, 60 }),
	look("Platinum", { 226, 246, 250 }, { 120, 170, 186 }, { 62, 104, 120 }, { 170, 240, 255 }),
	look("Emerald", { 130, 245, 170 }, { 18, 140, 70 }, { 8, 78, 38 }, { 80, 255, 150 }),
	look("Ruby", { 255, 128, 140 }, { 176, 20, 44 }, { 100, 8, 24 }, { 255, 70, 100 }),
	look("Diamond", { 220, 252, 255 }, { 80, 196, 255 }, { 30, 110, 186 }, { 140, 230, 255 }),
	look("Cosmic", { 255, 150, 255 }, { 104, 40, 224 }, { 46, 14, 108 }, { 220, 120, 255 }, true),
} :: { TierLook }
RankConfig.Images = {} :: { [number]: string }

-- Title colours by tier, in the rarity order players already know: white, blue, purple, gold (gold shimmers).
RankConfig.TitleColours = {
	Color3.fromRGB(236, 236, 236),
	Color3.fromRGB(84, 176, 255),
	Color3.fromRGB(194, 108, 255),
	Color3.fromRGB(255, 204, 48),
} :: { Color3 }

-- Sanity checks.
assert(#RankConfig.TierLooks == #RankConfig.Names, "[RankConfig] one look per name")
assert(#RankConfig.Names * RankConfig.LevelsPerName == RankConfig.Count, "[RankConfig] 12 names x 5 levels must match Points")
for index = 2, RankConfig.Count do
	assert(RankConfig.Points[index] > RankConfig.Points[index - 1], "[RankConfig] Points must rise")
end

return RankConfig
