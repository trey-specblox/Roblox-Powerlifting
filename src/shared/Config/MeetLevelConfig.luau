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
	-- The chance each lifter with a total gets a rare suit (GAME_DESIGN §35.10). Only at meets that pay a prize pot.
	suitDropChance: number,
}

MeetLevelConfig.Levels = {
	Local = { id = "Local", label = "LOCAL MEET", suitDropChance = 0.0001, chance = 0, potMultiplier = 1, ladderMultiplier = 1, titles = false },
	Regional = { id = "Regional", label = "REGIONAL MEET", suitDropChance = 0.001, chance = 0.25, potMultiplier = 2, ladderMultiplier = 2,
		titles = true },
	-- chance 0: State is never rolled in the Local venue any more (user, 2026-11-01, GAME_DESIGN §36): a new
	-- player's first meet must not be a State meet. State gets its own arena; until then it only happens when
	-- forced in Studio (workspace attribute ForceMeetLevel). Its titles stay for the arena.
	State = { id = "State", label = "STATE MEET", suitDropChance = 0.005, chance = 0, potMultiplier = 3, ladderMultiplier = 3, titles = true },
	-- Nationals (GAME_DESIGN §39): its own server and arena, never rolled. Placed per weight class; each class's top 3
	-- earn the titles, and the x5 pot is paid per class. No ladder points (the ladder leads to State). Suit chance 1%
	-- (user 2026-11-17, State's doubled).
	Nationals = { id = "Nationals", label = "NATIONALS", suitDropChance = 0.01, chance = 0, potMultiplier = 5, ladderMultiplier = 0,
		titles = true },
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
	-- Per weight class at Nationals (§39): the class is said with it ("74 kg National Champion").
	NationalsChampion = "National Champion",
	NationalsRunnerUp = "National Runner-up",
	NationalsThird = "National 3rd Place",
} :: { [string]: string }

--[[
	THE NUMBERED STATE CHAMPION BADGE (user 2026-11-16, GAME_DESIGN §36.4; it replaced the planned "finisher badge for
	everyone"). Only the State meet's WINNER (1st place, in a meet that pays in full) earns one: "#1001 STATE CHAMPION",
	"NOV 2026". The number comes from ONE counter for the whole game (every server), never reset: the 1001st badge ever
	given is #1001. One badge per season (calendar month): a second win in the same month gives no new badge or number.
	Saved in the player's career (PlayerProfileSchema version 26); numbered by the server's ChampionBadges.
]]
MeetLevelConfig.ChampionBadge = {
	-- The game-wide counter's DataStore and key. NEVER RENAME: the count would start again at 1.
	CounterStore = "StateChampionCounter",
	CounterKey = "Count",
	-- Studio counts on its own key, so test wins never use up live numbers (Studio numbers can repeat live ones).
	StudioCounterKey = "StudioCount",
	-- What the badge says under its number.
	Name = "STATE CHAMPION",
}

-- "2026-11" -> "NOV 2026" (a badge's season as players read it); anything else comes back as it is.
local MONTHS = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }
function MeetLevelConfig.seasonLabel(season: string): string
	local year, month = string.match(season, "^(%d%d%d%d)-(%d%d)$")
	local name = month and MONTHS[tonumber(month) :: number]
	return if year and name then name .. " " .. year else season
end

--[[
	Roblox profile badges for winning a meet (user 2026-11-16): 1st place in a meet that counts as a win (enough real
	players, not a solo or Mock Meet), one badge per level, given once. Made on the Creator Dashboard (Engagement ->
	Badges); 0 = not made yet, so nothing is given. Never change an id once players have it.
]]
MeetLevelConfig.WinnerBadgeIds = {
	Local = 3517943830860955, -- "Local Meet Winner!"
	Regional = 4321150741828938, -- "Won Regionals!"
	State = 3696266731109373, -- "State Champion!"
} :: { [string]: number }

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
	boundary once its dates exist.

	Kinder to new and impatient players (user 2026-11-01, "Yes, all three"):
	- a player who has never qualified for State (any class, any season)
	  needs only FirstStateTarget points;
	- a perfect meet (every attempt a good lift, 9/9) pays PerfectMeetPoints
	  more, multiplied by the level like the rest;
	- when a season starts, a class keeps SeasonCarryShare of the points it
	  had in the season just before (rounded down, always under the target);
	  points from older seasons are gone.
]]
MeetLevelConfig.Ladder = {
	PlacePoints = { 3, 2, 1 } :: { number },
	FinishPoints = 1,
	PerfectMeetPoints = 1,
	StateTarget = 25,
	FirstStateTarget = 10,
	SeasonCarryShare = 0.5,
	-- Each Local win saved before ladder points existed (career.localWins) becomes this many points, once.
	PointsPerOldLocalWin = 3,
}

--[[
	THE NATIONALS SPOT (user 2026-11-17, GAME_DESIGN §36.4 "The Nationals spot"). A top-3 place at a State meet is a
	PLACING, in the class the lifter weighed in at, but never for more than half the lifters in that meet (rounded up):
	2 lifters give 1 placing (the winner), 3-4 give 2, 5 or more give 3. PlacingsTarget placings in one class earn that
	class's Nationals spot. Placings never reset with the month. The spot is kept until the player competes at Nationals;
	when the month of their first Nationals meet on it is over, the class goes back to 0 placings and no spot.
	Saved in the career (PlayerProfileSchema version 27). Nationals itself is not built yet.
]]
MeetLevelConfig.Nationals = {
	PlacingsTarget = 10,
	TopPlaces = 3,
	-- A meet gives placings to at most this share of its lifters, rounded up.
	MaxShareOfField = 0.5,
}

-- How many places count toward Nationals at a State meet with `lifters` lifters in it.
function MeetLevelConfig.nationalsPlaces(lifters: number): number
	local settings = MeetLevelConfig.Nationals
	return math.clamp(math.ceil(lifters * settings.MaxShareOfField), 0, settings.TopPlaces)
end

-- The fewest lifters a State meet needs for `place` (1-3) to count toward Nationals, or nil when it never does.
function MeetLevelConfig.nationalsFieldFor(place: number): number?
	if place < 1 or place > MeetLevelConfig.Nationals.TopPlaces or place ~= math.floor(place) then
		return nil
	end
	for lifters = 1, 100 do
		if MeetLevelConfig.nationalsPlaces(lifters) >= place then
			return lifters
		end
	end
	return nil
end

--[[
	POINTS (user, 2026-11-06, GAME_DESIGN §37.4): every meet against other players
	ranks by IPF GL points, in place of the old % of a made-up class Total:
		points = total x 100 / (A - B x e^(-C x bodyweight))
	One set of the real numbers for everyone (the IPF's men's raw ones, user's pick): the
	game has no men's or women's tables, and no equipped lifting.
]]
MeetLevelConfig.Points = { A = 1199.72839, B = 1025.18162, C = 0.00921 }

-- The ladder points for finishing an official meet at `level` in `place` (nil = no top 3 place), with
-- `perfect` = every attempt a good lift.
function MeetLevelConfig.ladderPointsFor(level: LevelId, place: number?, perfect: boolean?): number
	local info = MeetLevelConfig.Levels[level] or MeetLevelConfig.Levels.Local
	local placePoints = if place then MeetLevelConfig.Ladder.PlacePoints[place] or 0 else 0
	local perfectPoints = if perfect then MeetLevelConfig.Ladder.PerfectMeetPoints else 0
	return (placePoints + MeetLevelConfig.Ladder.FinishPoints + perfectPoints) * info.ladderMultiplier
end

-- The ladder season a moment (Unix seconds) belongs to: its UTC calendar month, "2026-11".
function MeetLevelConfig.seasonFor(unix: number): string
	local date = os.date("!*t", math.floor(unix))
	return string.format("%04d-%02d", date.year, date.month)
end

-- The season just before `season` ("2026-01" -> "2025-12"), or nil when `season` is not "YYYY-MM".
function MeetLevelConfig.previousSeason(season: string): string?
	local yearText, monthText = string.match(season, "^(%d%d%d%d)-(%d%d)$")
	if yearText == nil or monthText == nil then
		return nil
	end
	local year, month = tonumber(yearText) :: number, (tonumber(monthText) :: number) - 1
	if month < 1 then
		year, month = year - 1, 12
	end
	return string.format("%04d-%02d", year, month)
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
