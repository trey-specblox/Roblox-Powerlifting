--!strict
--[[
	MeetPlacing
	Shared / Meet

	Ranks the lifters of a meet against other players (GAME_DESIGN.md §29.10,
	§37.4): ONE ranking for everyone, by IPF GL points (user, 2026-11-06).

		Points = Total x 100 / (A - B x e^(-C x bodyweight))   (MeetLevelConfig.Points)

	so a light lifter can beat a heavy one and a lifter alone in their class does
	not win automatically. Ties: more good lifts first (user, 2026-11-01: 9/9 beats
	8/9 on equal points), then [PROVISIONAL] the lighter bodyweight, as in real
	meets, then the earlier entry. A lifter with no total (a bomb-out, or withdrawn)
	has no points and no place, and is listed after everyone who placed.

	Pure, so the server ranks and the client could preview with the same code.
	The server's ranking is the one that counts.
]]

local ConfigFolder = script.Parent.Parent:WaitForChild("Config")
local MeetLevelConfig = require(ConfigFolder:WaitForChild("MeetLevelConfig"))

local MeetPlacing = {}

export type Entry = {
	-- Anything that identifies the lifter to the caller (a UserId).
	key: number,
	bodyweightKg: number,
	-- The meet total, or nil for no total (bombed out or withdrawn).
	totalKg: number?,
	-- Good lifts made (0-9), the first tie-break.
	goodLifts: number,
	-- Entry order (lower = earlier), the last tie-break.
	order: number,
}

export type Placing = {
	key: number,
	-- IPF GL points, or nil for no total.
	points: number?,
	-- 1 = first, or nil for no total.
	place: number?,
}

-- What 100 points takes at this bodyweight, in kilograms: the bottom of the formula.
local function hundredPointsKg(bodyweightKg: number): number
	local c = MeetLevelConfig.Points
	return c.A - c.B * math.exp(-c.C * bodyweightKg)
end

-- The points for a total at a bodyweight, or nil when there is no total.
function MeetPlacing.points(bodyweightKg: number, totalKg: number?): number?
	if totalKg == nil then
		return nil
	end
	return totalKg * 100 / hundredPointsKg(bodyweightKg)
end

-- The total that gives `points` at a bodyweight: how the race turns a rival's points into this lifter's kilograms.
function MeetPlacing.totalForPoints(bodyweightKg: number, points: number): number
	return points * hundredPointsKg(bodyweightKg) / 100
end

-- Ranks `entries`, best first. Lifters without points follow, in entry order.
function MeetPlacing.rank(entries: { Entry }): { Placing }
	local scored: { { entry: Entry, points: number? } } = {}
	for _, entry in ipairs(entries) do
		table.insert(scored, { entry = entry, points = MeetPlacing.points(entry.bodyweightKg, entry.totalKg) })
	end
	table.sort(scored, function(a, b)
		if (a.points ~= nil) ~= (b.points ~= nil) then
			return a.points ~= nil
		end
		if a.points and b.points and math.abs(a.points - b.points) > 1e-9 then
			return a.points > b.points
		end
		if a.points and b.points and a.entry.goodLifts ~= b.entry.goodLifts then
			return a.entry.goodLifts > b.entry.goodLifts
		end
		if a.points and b.points and math.abs(a.entry.bodyweightKg - b.entry.bodyweightKg) > 1e-9 then
			return a.entry.bodyweightKg < b.entry.bodyweightKg
		end
		return a.entry.order < b.entry.order
	end)
	local placings: { Placing } = {}
	local place = 0
	for _, item in ipairs(scored) do
		if item.points then
			place += 1
		end
		table.insert(placings, { key = item.entry.key, points = item.points, place = if item.points then place else nil })
	end
	return placings
end

--[[
	NATIONALS (GAME_DESIGN §39, user 2026-11-17): ONE WEIGHT CLASS ranked by its TOTAL in kilograms, best first, as real
	meets place a class. Equal totals: `liftOff` first (key -> its finish in a lift-off, 1 = won; the lift-off decides tied
	medal places), then more good lifts, the lighter bodyweight, the earlier entry. `points` are still worked out (shown).
]]
function MeetPlacing.rankByTotal(entries: { Entry }, liftOff: { [number]: number }?): { Placing }
	local sorted = table.clone(entries)
	local finish = liftOff or {}
	table.sort(sorted, function(a, b)
		if (a.totalKg ~= nil) ~= (b.totalKg ~= nil) then
			return a.totalKg ~= nil
		end
		if a.totalKg and b.totalKg then
			if math.abs(a.totalKg - b.totalKg) > 1e-9 then
				return a.totalKg > b.totalKg
			end
			local aFinish, bFinish = finish[a.key] or math.huge, finish[b.key] or math.huge
			if aFinish ~= bFinish then
				return aFinish < bFinish
			end
			if a.goodLifts ~= b.goodLifts then
				return a.goodLifts > b.goodLifts
			end
			if math.abs(a.bodyweightKg - b.bodyweightKg) > 1e-9 then
				return a.bodyweightKg < b.bodyweightKg
			end
		end
		return a.order < b.order
	end)
	local placings: { Placing } = {}
	local place = 0
	for _, entry in ipairs(sorted) do
		if entry.totalKg then
			place += 1
		end
		table.insert(placings, { key = entry.key, points = MeetPlacing.points(entry.bodyweightKg, entry.totalKg),
			place = if entry.totalKg then place else nil })
	end
	return placings
end

--[[
	The ties a lift-off decides (Nationals, user 2026-11-17: "only for medal places"): groups of two or more keys in one
	class with the same total where the group reaches into the top `medalPlaces`, best total first. `entries` is one class.
]]
function MeetPlacing.medalTies(entries: { Entry }, medalPlaces: number): { { number } }
	local placings = MeetPlacing.rankByTotal(entries)
	local totals: { [number]: number } = {}
	for _, entry in ipairs(entries) do
		if entry.totalKg then
			totals[entry.key] = entry.totalKg
		end
	end
	local groups: { { number } } = {}
	local index = 1
	while index <= #placings do
		local first = placings[index]
		local total = totals[first.key]
		if total == nil or (first.place or math.huge) > medalPlaces then
			break
		end
		local group = { first.key }
		local nextIndex = index + 1
		while nextIndex <= #placings and totals[placings[nextIndex].key]
			and math.abs((totals[placings[nextIndex].key] :: number) - total) <= 1e-9 do
			table.insert(group, placings[nextIndex].key)
			nextIndex += 1
		end
		if #group >= 2 then
			table.insert(groups, group)
		end
		index = nextIndex
	end
	return groups
end

return MeetPlacing
