--!strict
--[[
	MeetPlacing
	Shared / Meet

	Ranks the lifters of a meet against other players (GAME_DESIGN.md §29.10,
	"The Local meet — first build", user 2026-10-29): ONE ranking for everyone,
	by score.

		Score = Total / the weight class's reference Total (ReferenceRecordConfig)

	so a light lifter can beat a heavy one and a lifter alone in their class
	does not win automatically. Ties [PROVISIONAL]: the lighter bodyweight
	first, as in real meets, then the earlier entry. A lifter with no total
	(a bomb-out, or withdrawn) has no score and no place, and is listed after
	everyone who placed.

	Pure, so the server ranks and the client could preview with the same code.
	The server's ranking is the one that counts.
]]

local ConfigFolder = script.Parent.Parent:WaitForChild("Config")
local ReferenceRecordConfig = require(ConfigFolder:WaitForChild("ReferenceRecordConfig"))

local MeetPlacing = {}

export type Entry = {
	-- Anything that identifies the lifter to the caller (a UserId).
	key: number,
	classLabel: string,
	bodyweightKg: number,
	-- The meet total, or nil for no total (bombed out or withdrawn).
	totalKg: number?,
	-- Entry order (lower = earlier), the last tie-break.
	order: number,
}

export type Placing = {
	key: number,
	-- Total / class reference Total (0.25 = 25%), or nil for no total.
	score: number?,
	-- 1 = first, or nil for no total.
	place: number?,
}

-- The score for a total in a class, or nil when there is no total or no reference for the class.
function MeetPlacing.score(classLabel: string, totalKg: number?): number?
	local reference = ReferenceRecordConfig.Records.Total[classLabel]
	if totalKg == nil or reference == nil or reference <= 0 then
		return nil
	end
	return totalKg / reference
end

-- Ranks `entries`, best first. Lifters without a score follow, in entry order.
function MeetPlacing.rank(entries: { Entry }): { Placing }
	local scored: { { entry: Entry, score: number? } } = {}
	for _, entry in ipairs(entries) do
		table.insert(scored, { entry = entry, score = MeetPlacing.score(entry.classLabel, entry.totalKg) })
	end
	table.sort(scored, function(a, b)
		if (a.score ~= nil) ~= (b.score ~= nil) then
			return a.score ~= nil
		end
		if a.score and b.score and math.abs(a.score - b.score) > 1e-9 then
			return a.score > b.score
		end
		if a.score and b.score and math.abs(a.entry.bodyweightKg - b.entry.bodyweightKg) > 1e-9 then
			return a.entry.bodyweightKg < b.entry.bodyweightKg
		end
		return a.entry.order < b.entry.order
	end)
	local placings: { Placing } = {}
	local place = 0
	for _, item in ipairs(scored) do
		if item.score then
			place += 1
		end
		table.insert(placings, { key = item.entry.key, score = item.score, place = if item.score then place else nil })
	end
	return placings
end

return MeetPlacing
