--!strict
--[[
	ReferenceRecordConfig
	Shared / Config

	Reference records per lift, per weight class, in kilograms.

	These drive Record Percentage:

		Record Percentage = player performance / reference record for their class

	Per GAME_DESIGN.md Group A / Q3 and Group B / Q6, Record Percentage does NOT
	affect the difficulty of the lift in front of the player. It governs how hard
	further STRENGTH PROGRESSION becomes as a lifter approaches the limits of
	their weight class. Far below the record, Forecasted Max climbs quickly. Near
	it, progression becomes extremely difficult but never mathematically
	impossible.

	THESE ARE RPF GAMEPLAY VALUES.

	They may have started life as real-world performances, but once they are in
	this table they are balancing numbers and may be changed freely. Changing one
	must never require touching the progression, difficulty or competition
	systems, which is the entire reason they live here.

	Class labels must match WeightClassConfig exactly.
]]

local WeightClassConfig = require(script.Parent.WeightClassConfig)

local ReferenceRecordConfig = {}

export type LiftName = "Squat" | "Bench" | "Deadlift" | "Total"

-- [lift or "Total"][weight class label] = reference value in kg
export type RecordTable = { [string]: { [string]: number } }

local records: RecordTable = {
	Squat = {
		["59 kg"] = 240.5,
		["66 kg"] = 275.5,
		["74 kg"] = 341.0,
		["83 kg"] = 338.0,
		["93 kg"] = 356.0,
		["105 kg"] = 393.0,
		["120 kg"] = 393.0,
		["120+ kg"] = 478.0,
	},

	Bench = {
		["59 kg"] = 171.0,
		["66 kg"] = 213.5,
		["74 kg"] = 216.0,
		["83 kg"] = 219.0,
		["93 kg"] = 246.0,
		["105 kg"] = 251.0,
		["120 kg"] = 265.5,
		["120+ kg"] = 291.5,
	},

	Deadlift = {
		["59 kg"] = 303.0,
		["66 kg"] = 324.5,
		["74 kg"] = 344.0,
		["83 kg"] = 383.0,
		["93 kg"] = 380.0,
		["105 kg"] = 400.0,
		["120 kg"] = 401.5,
		["120+ kg"] = 411.0,
	},

	--[[
		Reference TOTAL per class, used by the normalised performance scoring
		described in Q13. Note these are the design's own totals and are not
		simply Squat + Bench + Deadlift from the rows above, which is expected:
		no single lifter holds every individual record in their class.
	]]
	Total = {
		["59 kg"] = 669.5,
		["66 kg"] = 782.0,
		["74 kg"] = 891.5,
		["83 kg"] = 890.0,
		["93 kg"] = 927.5,
		["105 kg"] = 980.0,
		["120 kg"] = 1000.0,
		["120+ kg"] = 1152.5,
	},
}

--[[
	Startup validation. Catches the two mistakes that would otherwise surface much
	later as mysterious progression behaviour: a typo in a class label (which would
	silently disable record scaling for that class) and a missing entry.
]]
do
	local validLabels: { [string]: boolean } = {}
	for _, class in ipairs(WeightClassConfig.Classes) do
		validLabels[class.label] = true
	end

	for liftName, liftRecords in pairs(records) do
		for label, value in pairs(liftRecords) do
			assert(
				validLabels[label],
				string.format(
					"[ReferenceRecordConfig] %s has record for unknown weight class %q. "
						.. "Labels must match WeightClassConfig exactly.",
					liftName,
					label
				)
			)
			assert(
				typeof(value) == "number" and value > 0,
				string.format("[ReferenceRecordConfig] %s record for %s must be above 0", liftName, label)
			)
		end

		for label in pairs(validLabels) do
			assert(
				liftRecords[label] ~= nil,
				string.format("[ReferenceRecordConfig] %s is missing a record for the %s class", liftName, label)
			)
		end
	end
end

ReferenceRecordConfig.Records = records

return ReferenceRecordConfig
