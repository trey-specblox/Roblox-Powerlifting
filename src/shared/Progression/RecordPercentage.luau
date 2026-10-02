--!strict
--[[
	RecordPercentage
	Shared / Progression

	How close a lifter is to the reference record for their weight class.

		Record Percentage = performance / reference record

	Kept deliberately separate from the lift-difficulty path. Per Q3, a lifter
	near a world record must not be punished twice for the same strength: their
	immediate lift difficulty comes from Personal Intensity only, while Record
	Percentage slows down how fast they gain further strength.

	Worked example from the design doc:

		Forecasted Squat 200, attempt 200, class record 350
			Personal Intensity 100%  (a hard max attempt)
			Record Percentage   57%  (progression still comes quickly)

		Forecasted Squat 340, attempt 340, class record 350
			Personal Intensity 100%  (still a hard max attempt)
			Record Percentage   97%  (progression now crawls)
]]

local ReferenceRecordConfig = require(script.Parent.Parent.Config.ReferenceRecordConfig)

local RecordPercentage = {}

-- Missing records are warned about once each, rather than every training tick.
local warnedKeys: { [string]: boolean } = {}

local function warnOnce(key: string, message: string)
	if warnedKeys[key] then
		return
	end
	warnedKeys[key] = true
	warn(message)
end

--[[
	Returns the reference record in kg for a lift and weight class, or nil when
	none is configured yet.
]]
function RecordPercentage.getReferenceRecord(liftName: string, weightClassLabel: string): number?
	local liftRecords = ReferenceRecordConfig.Records[liftName]
	if liftRecords == nil then
		warnOnce(
			liftName,
			string.format("[RecordPercentage] no record table exists for lift %q", liftName)
		)
		return nil
	end

	local record = liftRecords[weightClassLabel]
	if record == nil then
		warnOnce(
			liftName .. "|" .. weightClassLabel,
			string.format(
				"[RecordPercentage] no reference record set for %s in the %s class. "
					.. "Record-based progression scaling is INACTIVE for this lifter until "
					.. "ReferenceRecordConfig is filled in.",
				liftName,
				weightClassLabel
			)
		)
		return nil
	end

	return record
end

--[[
	Returns record percentage as a ratio (1.0 means exactly at the record), or nil
	when no reference record is configured for that lift and class.

	Callers must handle nil by applying NO record-based scaling. That keeps the
	game playable while the record table is still empty, instead of inventing a
	pace that was never designed.
]]
function RecordPercentage.resolve(liftName: string, weightClassLabel: string, performanceKg: number): number?
	assert(
		typeof(performanceKg) == "number" and performanceKg >= 0,
		"[RecordPercentage] performance must be a number of 0 or higher"
	)

	local record = RecordPercentage.getReferenceRecord(liftName, weightClassLabel)
	if record == nil then
		return nil
	end

	assert(record > 0, string.format("[RecordPercentage] reference record for %s must be above 0", liftName))
	return performanceKg / record
end

--[[
	True once at least one reference record has been configured. Useful for a
	startup check or an admin readout.
]]
function RecordPercentage.isConfigured(): boolean
	for _, liftRecords in pairs(ReferenceRecordConfig.Records) do
		for _ in pairs(liftRecords) do
			return true
		end
	end
	return false
end

return RecordPercentage
