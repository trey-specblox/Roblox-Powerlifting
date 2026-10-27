--!strict
--[[
	CardioRhythmConfig
	Shared / Config

	The treadmill rhythm game (GAME_DESIGN.md §27 "The treadmill rhythm game",
	user 2026-10-26): an original 4-lane rhythm game in rounds on the Cardio
	room's treadmills. Misses only drain health; a level every 30 seconds
	makes the beat faster and the notes denser; everyone who hops on a
	treadmill during the countdown runs the same round. Fun only: nothing here
	gives a stat, a reward or currency.

	The server (CardioRhythmService) and every client (CardioRhythmController)
	read the same numbers and build the same notes from the round's seed
	(RhythmChart), so what you see is what the server judges.
]]

local CardioRhythmConfig = {}

CardioRhythmConfig.Lanes = 4

-- Rounds.
CardioRhythmConfig.CountdownSeconds = 5
CardioRhythmConfig.ResultsSeconds = 6
CardioRhythmConfig.MaxRoundSeconds = 900 -- a safety stop: 15 minutes
CardioRhythmConfig.LeadInBeats = 4 -- beats of music before the first note

-- Health: misses only drain (user's pick). 10 misses and you are out.
CardioRhythmConfig.StartHealth = 100
CardioRhythmConfig.MissCost = 10
-- Pressing a lane with no note near costs a little, so mashing every key does not work.
CardioRhythmConfig.StrayPressCost = 4

-- Timing, in seconds either side of a note.
CardioRhythmConfig.HitWindowSeconds = 0.15 -- "GOOD"
CardioRhythmConfig.PerfectWindowSeconds = 0.06 -- "PERFECT" (only a label: both count as a hit)
-- The server allows for the player's lag, up to this much.
CardioRhythmConfig.MaxLagAllowanceSeconds = 0.2
CardioRhythmConfig.MaxPressesPerSecond = 16

-- Levels: one every 30 seconds (user's pick), each faster.
CardioRhythmConfig.LevelSeconds = 30
CardioRhythmConfig.StartBpm = 100
CardioRhythmConfig.BpmPerLevel = 8
CardioRhythmConfig.MaxBpm = 196 -- reached at level 13

-- How long a note takes to fall to the line: 1.6 s at level 1, quicker each level, never under 1.0 s.
CardioRhythmConfig.FallSecondsStart = 1.6
CardioRhythmConfig.FallSecondsPerLevel = 0.06
CardioRhythmConfig.FallSecondsMin = 1.0

--[[
	How busy each level is: the chance of a note on each beat, on each
	half-beat between beats, and that a note is a chord of two lanes.
]]
export type Pattern = { beat: number, halfBeat: number, chord: number }
local PATTERNS: { Pattern } = {
	{ beat = 0.6, halfBeat = 0, chord = 0 }, -- level 1
	{ beat = 0.8, halfBeat = 0, chord = 0 },
	{ beat = 1, halfBeat = 0, chord = 0 },
	{ beat = 1, halfBeat = 0.15, chord = 0 },
	{ beat = 1, halfBeat = 0.3, chord = 0.05 }, -- level 5
	{ beat = 1, halfBeat = 0.4, chord = 0.1 },
}

-- The keys of each lane (left to right): arrow keys, or D F J K; the controller's d-pad or X A Y B.
CardioRhythmConfig.LaneKeys = {
	{ Enum.KeyCode.Left, Enum.KeyCode.D, Enum.KeyCode.DPadLeft, Enum.KeyCode.ButtonX },
	{ Enum.KeyCode.Down, Enum.KeyCode.F, Enum.KeyCode.DPadDown, Enum.KeyCode.ButtonA },
	{ Enum.KeyCode.Up, Enum.KeyCode.J, Enum.KeyCode.DPadUp, Enum.KeyCode.ButtonY },
	{ Enum.KeyCode.Right, Enum.KeyCode.K, Enum.KeyCode.DPadRight, Enum.KeyCode.ButtonB },
}
CardioRhythmConfig.LaneLabels = { "D", "F", "J", "K" }
-- Mixed colours, not just red and black (user's rule).
CardioRhythmConfig.LaneColours = {
	Color3.fromRGB(64, 148, 255),
	Color3.fromRGB(255, 196, 40),
	Color3.fromRGB(80, 214, 110),
	Color3.fromRGB(255, 112, 92),
}

--[[
	The beat's sounds (original, made by art/scripts/make_rhythm_sounds.py and
	uploaded as group audio, art/materials/materials.json "sounds"). An empty id
	means no sound: the game then runs silently.
]]
CardioRhythmConfig.Sounds = {
	Kick = "rbxassetid://85088925719114",
	Snare = "rbxassetid://99723722634680",
	Hat = "rbxassetid://139986629908272",
	Hit = "rbxassetid://111016778868160",
	Miss = "rbxassetid://127344920469973",
	Count = "rbxassetid://105244845446461",
} :: { [string]: string }

--[[
	The two saved leaderboards (user 2026-10-27): each player's best single run,
	all-time and this week, top 10, one board on each side wall of the Cardio
	room. CardioRhythmLeaderboard keeps them in one OrderedDataStore per board
	(the player's own save is not touched). The weekly board starts a new store
	every Monday 00:00 UTC.
]]
CardioRhythmConfig.Leaderboard = {
	TopCount = 10,
	-- Times are saved in tenths of a second (an ordered store holds whole numbers).
	TicksPerSecond = 10,
	-- CHANGING THESE NAMES STARTS THE BOARDS FROM EMPTY (the old times stay in the old store).
	AllTimeStore = "RhythmBest_AllTime",
	WeeklyStorePrefix = "RhythmBest_Week_", -- + the Monday's date, e.g. RhythmBest_Week_2026-10-26
	-- In Studio with API access on, the boards use these names in front, so test runs never reach the live boards.
	StudioPrefix = "Studio_",
	RefreshSeconds = 60, -- read both top 10s again
	SaveRetries = 3,
	-- A run shorter than this is not saved (hopping straight back off).
	MinSecondsToSave = 1,
	-- RoomProps puts this tag on each board's SurfaceGui, with its board ("AllTime" or "Weekly") in "Board".
	BoardTag = "RhythmLeaderboard",
}

function CardioRhythmConfig.levelAt(seconds: number): number
	return math.max(1, math.floor(seconds / CardioRhythmConfig.LevelSeconds) + 1)
end

function CardioRhythmConfig.bpmFor(level: number): number
	return math.min(CardioRhythmConfig.StartBpm + CardioRhythmConfig.BpmPerLevel * (level - 1), CardioRhythmConfig.MaxBpm)
end

function CardioRhythmConfig.patternFor(level: number): Pattern
	local pattern = PATTERNS[level]
	if pattern then
		return pattern
	end
	-- Past level 6: more half-beats and chords, up to a limit.
	local extra = level - #PATTERNS
	return { beat = 1, halfBeat = math.min(0.4 + 0.05 * extra, 0.7), chord = math.min(0.1 + 0.03 * extra, 0.3) }
end

function CardioRhythmConfig.fallSecondsFor(level: number): number
	return math.max(CardioRhythmConfig.FallSecondsMin,
		CardioRhythmConfig.FallSecondsStart - CardioRhythmConfig.FallSecondsPerLevel * (level - 1))
end

return CardioRhythmConfig
