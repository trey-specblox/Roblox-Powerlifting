--!strict
--[[
	LoadoutConfig
	Shared / Config

	Collections and attempt slots (user 2026-11-12: "I want people to be able to collect these walk outs, celebrations,
	and lift fails ... Give the user 3 slots ... 1st attempt celebration, 2nd attempt celebration 3rd attempt. Do the same
	for walk outs"). This replaces the earlier reroll (one at a time, each spin replacing it).

		collected   every walk-out, celebration and fail style won at Hype Man is kept (a duplicate gives coins back,
		            CelebrationConfig.Spin.duplicateRefund). Everyone has each kind's Default.
		slots       three per kind: what they do on their 1st, 2nd and 3rd attempt, at every lift (squat, bench and
		            deadlift alike). Any slot can hold any one they own; the same one can sit in several.
		pages       the emote wheel (client EmoteWheel, key B) has a page per kind, switched with its arrows: EMOTES,
		            WALK-OUTS, CELEBRATIONS, FAILS. The three slot pages are where they swap what is in each slot.

	The server decides everything (ProfileOperations.setLoadoutSlot checks they own it); this only names things.
]]

local ConfigFolder = script.Parent
local CelebrationConfig = require(ConfigFolder:WaitForChild("CelebrationConfig"))
local EntranceConfig = require(ConfigFolder:WaitForChild("EntranceConfig"))
local StationAnimationConfig = require(ConfigFolder:WaitForChild("StationAnimationConfig"))

local LoadoutConfig = {}

-- One slot per attempt.
LoadoutConfig.Slots = 3

-- The kinds with slots, in the wheel's page order (after EMOTES).
LoadoutConfig.Kinds = { "Entrance", "Celebration", "Fail" }

-- Every page of the wheel, in order, and what each is called on screen.
LoadoutConfig.Pages = { "Emote", "Entrance", "Celebration", "Fail" }
LoadoutConfig.Titles = {
	Emote = "EMOTES",
	Entrance = "WALK-OUTS",
	Celebration = "CELEBRATIONS",
	Fail = "FAILS",
} :: { [string]: string }

-- What each slot is called.
LoadoutConfig.SlotNames = { "1ST ATTEMPT", "2ND ATTEMPT", "3RD ATTEMPT" }

-- When each kind happens, for the wheel's hub.
LoadoutConfig.When = {
	Entrance = "Your walk out to the bar, then its hype move",
	Celebration = "After a good lift",
	Fail = "When you miss a lift",
} :: { [string]: string }

local KIND_SET = { Entrance = true, Celebration = true, Fail = true }

function LoadoutConfig.isKind(kind: any): boolean
	return typeof(kind) == "string" and KIND_SET[kind] == true
end

-- Everyone's free one of a kind.
function LoadoutConfig.defaultOf(kind: string): string
	if kind == "Entrance" then
		return EntranceConfig.DefaultId
	elseif kind == "Fail" then
		return "Default"
	end
	return CelebrationConfig.Default
end

-- True for any id of that kind the game has (its Default included).
function LoadoutConfig.isItem(kind: string, id: any): boolean
	if typeof(id) ~= "string" then
		return false
	end
	if kind == "Entrance" then
		return EntranceConfig.get(id) ~= nil
	elseif kind == "Fail" then
		return id == "Default" or StationAnimationConfig.FailStyles[id] ~= nil
	elseif kind == "Celebration" then
		return CelebrationConfig.byId[id] ~= nil
	end
	return false
end

export type Item = { id: string, name: string, rarity: string, description: string }

-- Everything of a kind, Default first then by rarity (each config's own order within a rarity).
function LoadoutConfig.items(kind: string): { Item }
	local all: { Item } = {}
	if kind == "Entrance" then
		for _, id in ipairs(EntranceConfig.Order) do
			local entrance = EntranceConfig.Entrances[id]
			table.insert(all, { id = id, name = entrance.name, rarity = entrance.rarity, description = entrance.description })
		end
	elseif kind == "Fail" then
		for _, id in ipairs(StationAnimationConfig.FailStyleOrder) do
			local style: any = if id == "Default" then StationAnimationConfig.DefaultFailStyle else StationAnimationConfig.FailStyles[id]
			if style then
				table.insert(all, { id = id, name = style.name, rarity = style.rarity, description = style.description })
			end
		end
	elseif kind == "Celebration" then
		for _, celebration in ipairs(CelebrationConfig.List) do
			table.insert(all, {
				id = celebration.id, name = celebration.name, rarity = celebration.rarity, description = celebration.description,
			})
		end
	end
	local rank: { [string]: number } = {}
	for index, rarity in ipairs(CelebrationConfig.RarityOrder) do
		rank[rarity] = index
	end
	local position: { [Item]: number } = {}
	for index, item in ipairs(all) do
		position[item] = index
	end
	table.sort(all, function(a, b)
		local ra, rb = rank[a.rarity] or 99, rank[b.rarity] or 99
		if ra ~= rb then
			return ra < rb
		end
		return position[a] < position[b]
	end)
	return all
end

-- The slot used on an attempt (1, 2, 3; anything else is the nearest).
function LoadoutConfig.slotFor(attempt: number?): number
	if typeof(attempt) ~= "number" or attempt ~= attempt then
		return 1
	end
	return math.clamp(math.floor(attempt), 1, LoadoutConfig.Slots)
end

return LoadoutConfig
