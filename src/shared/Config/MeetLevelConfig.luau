--!strict
--[[
	MeetLevelConfig
	Shared / Config

	The meet ladder's levels held in the Local meet venue (GAME_DESIGN.md
	§35.8, "The meet ladder — design", user 2026-10-31): a scheduled Local
	meet can turn out to be a REGIONAL or a STATE meet. The level is rolled
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
	-- Ladder points are multiplied by this (§35.8; ladder points are a later build step).
	ladderMultiplier: number,
	-- Whether the top 3 earn a title and a trophy.
	titles: boolean,
}

MeetLevelConfig.Levels = {
	Local = { id = "Local", label = "LOCAL MEET", chance = 0, potMultiplier = 1, ladderMultiplier = 1, titles = false },
	Regional = { id = "Regional", label = "REGIONAL MEET", chance = 0.25, potMultiplier = 2, ladderMultiplier = 2,
		titles = true },
	State = { id = "State", label = "STATE MEET", chance = 0.10, potMultiplier = 3, ladderMultiplier = 3, titles = true },
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
