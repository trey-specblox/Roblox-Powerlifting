--!strict
--[[
	GearStats
	Shared / Economy

	The sums for gear with stats (GAME_DESIGN.md §35.12), from GearStatsConfig. Pure:
	it decides nothing about who owns what and never writes a save. The server's
	answer is the one that counts; the client uses the same sums to draw the menus.

		crate            a crate by its id
		roll             what a crate gives
		techniqueBonus / trainingSpeed    what worn pieces add on one lift
		producer         the lift's modifier source (ModifierRegistry): gear's technique
		                 on EffectiveTechnique, so a lift is easier to perform. There is
		                 no channel for Competition Number, so gear can never raise it.

	PERFORMANCE: a few table lookups, once when a lift starts or a training tick runs.
]]

local Shared = script.Parent.Parent
local ConfigFolder = Shared:WaitForChild("Config")
local GearStatsConfig = require(ConfigFolder:WaitForChild("GearStatsConfig"))
local ShopConfig = require(ConfigFolder:WaitForChild("ShopConfig"))
local WornGearConfig = require(ConfigFolder:WaitForChild("WornGearConfig"))
local ModifiersFolder = Shared:WaitForChild("Modifiers")
local ModifierChannel = require(ModifiersFolder:WaitForChild("ModifierChannel"))
local ModifierSet = require(ModifiersFolder:WaitForChild("ModifierSet"))

local GearStats = {}

GearStats.SourceName = "GearStats"

-- One piece of stat gear, as saved. Its stats are read from its rarity, so they can be rebalanced.
export type Piece = {
	slot: string,
	rarity: string,
	-- The ShopConfig item whose look it has.
	look: string,
}

function GearStats.rarity(id: any): GearStatsConfig.Rarity?
	for _, rarity in ipairs(GearStatsConfig.Rarities) do
		if rarity.id == id then
			return rarity
		end
	end
	return nil
end

-- A rarity's place from the bottom (1 = Common); 0 for an unknown one.
function GearStats.rank(id: any): number
	for index, rarity in ipairs(GearStatsConfig.Rarities) do
		if rarity.id == id then
			return index
		end
	end
	return 0
end

-- The crate with this id, or nil. Safe with anything a client sends.
function GearStats.crate(id: any): GearStatsConfig.Crate?
	for _, crate in ipairs(GearStatsConfig.Crates) do
		if crate.id == id then
			return crate
		end
	end
	return nil
end

-- What a crate of this item gives: its rarity by the odds, with one of that item's Shop looks.
function GearStats.roll(random: Random, slotId: string): Piece
	local category: string? = nil
	for _, slot in ipairs(WornGearConfig.Slots) do
		if slot.id == slotId then
			category = slot.category
		end
	end
	local looks: { string } = {}
	for _, item in ipairs(ShopConfig.Items) do
		if item.category == category then
			table.insert(looks, item.id)
		end
	end
	local pick = random:NextNumber()
	local rarity = GearStatsConfig.Rarities[1].id
	local upTo = 0
	for _, entry in ipairs(GearStatsConfig.Rarities) do
		upTo += entry.odds
		if pick < upTo then
			rarity = entry.id
			break
		end
	end
	return { slot = slotId, rarity = rarity, look = looks[random:NextInteger(1, #looks)] }
end

-- slot -> rarity for what a saved inventory has on. Bad entries count for nothing.
function GearStats.wornRarities(inventory: any): { [string]: string }
	local worn: { [string]: string } = {}
	local wearing = if typeof(inventory) == "table" then inventory.wearingPieces else nil
	local pieces = if typeof(inventory) == "table" then inventory.pieces else nil
	if typeof(wearing) ~= "table" or typeof(pieces) ~= "table" then
		return worn
	end
	for slot, pieceId in pairs(wearing) do
		local piece = pieces[pieceId]
		if typeof(piece) == "table" and piece.slot == slot and GearStats.rarity(piece.rarity) then
			worn[slot] = piece.rarity
		end
	end
	return worn
end

-- What pieces of these rarities (slot -> rarity) add to effective technique on `lift`.
function GearStats.techniqueBonus(worn: { [string]: string }, lift: string): number
	local total = 0
	for slot, rarityId in pairs(worn) do
		local helps = GearStatsConfig.SlotLifts[slot]
		local rarity = GearStats.rarity(rarityId)
		if helps and helps[lift] and rarity then
			total += rarity.technique
		end
	end
	return total
end

-- What they add to technique training speed on `lift` (0.1 = +10%), up to the cap.
function GearStats.trainingSpeed(worn: { [string]: string }, lift: string): number
	local total = 0
	for slot, rarityId in pairs(worn) do
		local helps = GearStatsConfig.SlotLifts[slot]
		local rarity = GearStats.rarity(rarityId)
		if helps and helps[lift] and rarity then
			total += rarity.trainingSpeed
		end
	end
	return math.min(total, GearStatsConfig.MaxTrainingSpeed)
end

-- "RARE GOLD STANDARD BELT".
function GearStats.pieceName(piece: Piece): string
	local item = ShopConfig.find(piece.look)
	return string.upper(piece.rarity .. " " .. (if item then item.name else "gear"))
end

-- "+2 TECHNIQUE  ·  +5% TRAINING".
function GearStats.statText(rarityId: string): string
	local rarity = GearStats.rarity(rarityId)
	if rarity == nil then
		return ""
	end
	return string.format("+%s TECHNIQUE  ·  +%d%% TRAINING", tostring(rarity.technique), math.floor(rarity.trainingSpeed * 100 + 0.5))
end

-- "SQUAT AND BENCH": which lifts a slot's pieces help.
function GearStats.liftsText(slot: string): string
	local helps = GearStatsConfig.SlotLifts[slot] or {}
	local names = {}
	for _, lift in ipairs({ "Squat", "Bench", "Deadlift" }) do
		if helps[lift] then
			table.insert(names, string.upper(lift))
		end
	end
	if #names == 3 then
		return "ALL THREE LIFTS"
	end
	return table.concat(names, " AND ")
end

-- The lift's modifier source (ModifierRegistry.register): the worn pieces' technique, on every lift the player makes.
function GearStats.producer(context: any): ModifierSet.ModifierSet
	local set = ModifierSet.create()
	local profile = context.profile
	local lift = context.liftName
	if typeof(profile) ~= "table" or typeof(lift) ~= "string" then
		return set
	end
	local bonus = GearStats.techniqueBonus(GearStats.wornRarities(profile.inventory), lift)
	if bonus > 0 then
		ModifierSet.add(set, { channel = ModifierChannel.EffectiveTechnique, operation = "Add", value = bonus, source = GearStats.SourceName })
	end
	return set
end

return GearStats
