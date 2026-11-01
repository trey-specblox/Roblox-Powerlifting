--!strict
--[[
	MeetLevelConfig
	Shared / Config

	The meet ladder's levels held in the Local meet venue (GAME_DESIGN.md
	§35.8, "The meet ladder — design", user 2026-10-31): a scheduled Local
	meet can turn out to be a REGIONAL meet (STATE was rolled too until
	2026-11-01; it is moving to its own arena, §36). The level is rolled
	when the meet's sign-ups open and announced straight away; anyone may
	enter. A Regional or State meet pays a bigger prize pot and gives its top
	3 a title and a trophy. Lifting, judging and CN are the same at every
	level.

	All numbers [PROVISIONAL]: tune them here.
]]

local MeetLevelConfig = {}

-- "Local", "Regional" or "State".
export type LevelId = string

export type Level = {
	id: LevelId,
	-- On signs and boards ("STATE MEET").
	label: string,
	-- The chance a scheduled meet is this level (Local takes what is left).
	chance: number,
	-- The prize pot is multiplied by this (§30.6's pot; the finishing, 9/9 and record bonuses are not).
	potMultiplier: number,
	-- Ladder points are multiplied by this (§35.8, MeetLevelConfig.Ladder).
	ladderMultiplier: number,
	-- Whether the top 3 earn a title and a trophy.
	titles: boolean,
}

MeetLevelConfig.Levels = {
	Local = { id = "Local", label = "LOCAL MEET", chance = 0, potMultiplier = 1, ladderMultiplier = 1, titles = false },
	Regional = { id = "Regional", label = "REGIONAL MEET", chance = 0.25, potMultiplier = 2, ladderMultiplier = 2,
		titles = true },
	-- chance 0: State is never rolled in the Local venue any more (user, 2026-11-01, GAME_DESIGN §36): a new
	-- player's first meet must not be a State meet. State gets its own arena; until then it only happens when
	-- forced in Studio (workspace attribute ForceMeetLevel). Its titles stay for the arena.
	State = { id = "State", label = "STATE MEET", chance = 0, potMultiplier = 3, ladderMultiplier = 3, titles = true },
} :: { [LevelId]: Level }

-- Rolled in this order (the rarest first); Local when none comes up.
MeetLevelConfig.RollOrder = { "State", "Regional" } :: { LevelId }

--[[
	The titles the top 3 earn at a Regional or State meet, by id ("<Level><Place>").
	These ids are saved in players' careers: never rename or reuse one.
]]
MeetLevelConfig.Titles = {
	RegionalChampion = "Regional Champion",
	RegionalRunnerUp = "Regional Runner-up",
	RegionalThird = "Regional 3rd Place",
	StateChampion = "State Champion",
	StateRunnerUp = "State Runner-up",
	StateThird = "State 3rd Place",
} :: { [string]: string }

-- The trophy model the top 3 hold on the podium at a level with titles (art/blender/Trophy_01.blend; 0 = not
-- uploaded yet: no trophies; materials.json "Trophy_01") and its metal's colour by place.
MeetLevelConfig.TrophyAssetId = 96903806374655
MeetLevelConfig.TrophyColours = {
	Color3.fromRGB(214, 170, 52),
	Color3.fromRGB(196, 200, 206),
	Color3.fromRGB(176, 112, 58),
} :: { Color3 }

-- The title id for a place (1-3) at a level, or nil (no titles at that level or place).
function MeetLevelConfig.titleFor(level: LevelId, place: number?): string?
	local info = MeetLevelConfig.Levels[level]
	if info == nil or not info.titles or place == nil then
		return nil
	end
	local suffix = if place == 1 then "Champion" elseif place == 2 then "RunnerUp" elseif place == 3 then "Third" else nil
	local id = suffix and (level .. suffix)
	return if id and MeetLevelConfig.Titles[id] then id else nil
end

--[[
	LADDER POINTS (§35.8 "Ladder points", ladder step 2; per class §36.3): how
	a player qualifies for the State Championship. Every official meet
	finished with a total pays PlacePoints for a top 3 place plus
	FinishPoints, all multiplied by the meet level's ladderMultiplier, to the
	weight class the lifter weighed in at. A bomb-out, leaving early, or a
	Solo / Mock Meet pays nothing. StateTarget points in one SEASON, in one
	class, qualify for State in that class; then that class's extra points
	stop until the next season. Seasons are calendar months in
	UTC for now ("2026-11"); the Sheffield cycle (§32.1) will set the real
	boundary once its dates exist. Points reset when a season starts.
]]
MeetLevelConfig.Ladder = {
	PlacePoints = { 3, 2, 1 } :: { number },
	FinishPoints = 1,
	StateTarget = 25,
	-- Each Local win saved before ladder points existed (career.localWins) becomes this many points, once.
	PointsPerOldLocalWin = 3,
}

--[[
	SCORE TOTALS (user, 2026-11-01): the made-up reference Total for each
	weight class that a Local or Regional meet scores against
	(Score = Total / ScoreTotals[class], MeetPlacing). Evenly spaced: each
	class is about 8% above the one below, from 670 kg (59 kg) to 1150 kg
	(120+ kg), so no class scores more easily than its neighbours. Even
	percentage steps, not even kg steps, because strength grows by about the
	same percentage per class (bodyweight^(2/3)); even kg steps would favour
	the heavy classes. Separate from ReferenceRecordConfig's real records,
	which keep driving difficulty and prestige. State and Nationals may get
	their own table later. Labels must match WeightClassConfig exactly.
]]
MeetLevelConfig.ScoreTotals = {
	["59 kg"] = 670,
	["66 kg"] = 725,
	["74 kg"] = 780,
	["83 kg"] = 845,
	["93 kg"] = 915,
	["105 kg"] = 985,
	["120 kg"] = 1065,
	["120+ kg"] = 1150,
} :: { [string]: number }

-- Startup check: one positive score Total per weight class, nothing else (a missing class would leave its
-- lifters with no score and no place).
do
	local WeightClassConfig = require(script.Parent:WaitForChild("WeightClassConfig"))
	local validLabels: { [string]: boolean } = {}
	for _, class in ipairs(WeightClassConfig.Classes) do
		validLabels[class.label] = true
		local value = MeetLevelConfig.ScoreTotals[class.label]
		assert(typeof(value) == "number" and value > 0,
			string.format("[MeetLevelConfig] ScoreTotals is missing a positive Total for the %s class", class.label))
	end
	for label in pairs(MeetLevelConfig.ScoreTotals) do
		assert(validLabels[label], string.format("[MeetLevelConfig] ScoreTotals has unknown weight class %q", label))
	end
end

-- The ladder points for finishing an official meet at `level` in `place` (nil = no top 3 place).
function MeetLevelConfig.ladderPointsFor(level: LevelId, place: number?): number
	local info = MeetLevelConfig.Levels[level] or MeetLevelConfig.Levels.Local
	local placePoints = if place then MeetLevelConfig.Ladder.PlacePoints[place] or 0 else 0
	return (placePoints + MeetLevelConfig.Ladder.FinishPoints) * info.ladderMultiplier
end

-- The ladder season a moment (Unix seconds) belongs to: its UTC calendar month, "2026-11".
function MeetLevelConfig.seasonFor(unix: number): string
	local date = os.date("!*t", math.floor(unix))
	return string.format("%04d-%02d", date.year, date.month)
end

-- When the season holding `unix` ends (the next UTC month starts), in Unix seconds.
function MeetLevelConfig.seasonEndsAt(unix: number): number
	local date = os.date("!*t", math.floor(unix))
	local year, month = date.year, date.month + 1
	if month > 12 then
		year, month = year + 1, 1
	end
	-- Days from 1970-01-01 to the 1st of that month (the civil calendar counted from March, so the leap day
	-- comes last), worked out by hand so no computer's time zone can move it.
	local y = if month <= 2 then year - 1 else year
	local era = y // 400
	local yearOfEra = y - era * 400
	local dayOfYear = (153 * (if month > 2 then month - 3 else month + 9) + 2) // 5
	local dayOfEra = yearOfEra * 365 + yearOfEra // 4 - yearOfEra // 100 + dayOfYear
	return (era * 146097 + dayOfEra - 719468) * 86400
end

-- The level for a random number in [0, 1): each rarer level takes its slice first.
function MeetLevelConfig.roll(random: number): LevelId
	local edge = 0
	for _, id in ipairs(MeetLevelConfig.RollOrder) do
		edge += MeetLevelConfig.Levels[id].chance
		if random < edge then
			return id
		end
	end
	return "Local"
end

return MeetLevelConfig
