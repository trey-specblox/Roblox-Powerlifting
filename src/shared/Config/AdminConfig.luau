--!strict
--[[
	AdminConfig
	Shared / Config

	What the admin panel offers (user 2026-11-06: testing on a phone means joining the real
	game; 2026-11-08: "fully control anyones stats" to playtest without earning them). Who may
	use it is NOT here: that list is on the server only (AdminService). A coin button's amount
	is read by the server from here by the button's id; a client only ever sends the id, so it
	can't ask for any other amount. A typed stat is clamped by the server to StatLimits.
]]

local ConfigFolder = script.Parent
local ProgressionConfig = require(ConfigFolder:WaitForChild("ProgressionConfig"))
local TrainingStationConfig = require(ConfigFolder:WaitForChild("TrainingStationConfig"))

local AdminConfig = {}

export type CoinButton = {
	id: string,
	label: string,
	amount: number,
}

AdminConfig.CoinButtons = {
	{ id = "Coins1000", label = "+1,000", amount = 1000 },
	{ id = "Coins10000", label = "+10,000", amount = 10000 },
	{ id = "Coins100000", label = "+100,000", amount = 100000 },
} :: { CoinButton }

-- The ADMIN tab on the left edge, from the middle of the screen: above the MEETS tab.
AdminConfig.TabOffsetY = -218

--[[
	The PLAYER STATS page: every stat the admin can type for any player in the server, in the
	order shown. `kind` picks the limits below and how the server writes it:
		Bodyweight         the current bodyweight (and the target, so it stays): picks the class
		Ladder             State ladder points in the current class, this season
		CompetitionNumber  one lift's CN in the current class
		Scale              one lift's proven weight (Competition Scale) in the current class
		Technique          one raw technique stat (the stats screen shows it through the curve)
]]
export type StatField = { id: string, label: string, kind: string, lift: string?, stat: string? }

AdminConfig.StatLimits = {
	Bodyweight = { min = 40, max = 200 },
	Ladder = { min = 0, max = 100 },
	CompetitionNumber = { min = 20, max = 1000 },
	Scale = { min = 0, max = 1000 },
	Technique = { min = 0, max = 1000 },
} :: { [string]: { min: number, max: number } }

local fields: { StatField } = {
	{ id = "Bodyweight", label = "BODYWEIGHT KG", kind = "Bodyweight" },
	{ id = "Ladder", label = "LADDER POINTS", kind = "Ladder" },
}
for _, lift in ipairs(ProgressionConfig.Lifts) do
	table.insert(fields, { id = "CN_" .. lift, label = string.upper(lift) .. " CN", kind = "CompetitionNumber", lift = lift })
end
for _, lift in ipairs(ProgressionConfig.Lifts) do
	table.insert(fields, { id = "Scale_" .. lift, label = string.upper(lift) .. " PROVEN", kind = "Scale", lift = lift })
end
for _, lift in ipairs(ProgressionConfig.Lifts) do
	for _, stat in ipairs((ProgressionConfig.TrainableTechnique :: any)[lift] or {}) do
		local name = (TrainingStationConfig.TechniqueStatNames :: any)[stat] or stat
		table.insert(fields, { id = "Tech_" .. stat, label = string.upper(name), kind = "Technique", stat = stat })
	end
end
AdminConfig.StatFields = fields

-- The stat field with this id, or nil. Safe with anything a client sends.
function AdminConfig.statField(id: any): StatField?
	for _, field in ipairs(AdminConfig.StatFields) do
		if field.id == id then
			return field
		end
	end
	return nil
end

return AdminConfig
