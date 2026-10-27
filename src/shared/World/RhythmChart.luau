--!strict
--[[
	RhythmChart
	Shared / World

	Builds a treadmill rhythm round's notes and beats from its seed
	(CardioRhythmConfig). Pure and deterministic: the server and every client
	call generate(seed) and get exactly the same notes, so the server can judge
	a press against the note the player saw. Times are seconds from the round's
	start; levels change every LevelSeconds, each faster and busier.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardioRhythmConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CardioRhythmConfig"))

local RhythmChart = {}

export type Note = { index: number, time: number, lane: number, level: number }
-- One beat of the music: `half` is the half-beat between two beats.
export type Beat = { time: number, number: number, half: boolean, level: number }
export type Chart = { notes: { Note }, beats: { Beat } }

function RhythmChart.generate(seed: number): Chart
	local rng = Random.new(seed)
	local notes: { Note } = {}
	local beats: { Beat } = {}
	local lanes = CardioRhythmConfig.Lanes
	local lastLane, sameCount = 0, 0

	-- A lane for the next note, never the same one more than twice in a row.
	local function pickLane(except: number?): number
		local lane = rng:NextInteger(1, lanes)
		while lane == except or (lane == lastLane and sameCount >= 2) do
			lane = rng:NextInteger(1, lanes)
		end
		return lane
	end

	local function addNotes(time: number, level: number, chordChance: number)
		local lane = pickLane(nil)
		sameCount = if lane == lastLane then sameCount + 1 else 1
		lastLane = lane
		table.insert(notes, { index = #notes + 1, time = time, lane = lane, level = level })
		if rng:NextNumber() < chordChance then
			table.insert(notes, { index = #notes + 1, time = time, lane = pickLane(lane), level = level })
		end
	end

	local time, number = 0, 0
	while time < CardioRhythmConfig.MaxRoundSeconds do
		local level = CardioRhythmConfig.levelAt(time)
		local beatLength = 60 / CardioRhythmConfig.bpmFor(level)
		local pattern = CardioRhythmConfig.patternFor(level)
		number += 1
		table.insert(beats, { time = time, number = number, half = false, level = level })
		table.insert(beats, { time = time + beatLength / 2, number = number, half = true, level = level })
		if number > CardioRhythmConfig.LeadInBeats then
			if rng:NextNumber() < pattern.beat then
				addNotes(time, level, pattern.chord)
			end
			if rng:NextNumber() < pattern.halfBeat then
				addNotes(time + beatLength / 2, level, pattern.chord)
			end
		end
		time += beatLength
	end
	return { notes = notes, beats = beats }
end

-- The first note at or after `time` (binary search; #notes + 1 if none).
function RhythmChart.firstFrom(notes: { Note }, time: number): number
	local low, high = 1, #notes + 1
	while low < high do
		local middle = (low + high) // 2
		if notes[middle].time < time then
			low = middle + 1
		else
			high = middle
		end
	end
	return low
end

return RhythmChart
