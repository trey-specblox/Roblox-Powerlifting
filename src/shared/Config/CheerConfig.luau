--!strict
--[[
	CheerConfig
	Shared / Config

	Cheering at the big meets (GAME_DESIGN.md §36.4 "Cheering", user 2026-11-08):
	players in a rack's invisible watching zones cheer the lifter on through voice
	chat; a full cheering bar makes the lift easier, and if it's a good lift everyone
	who helped gets its GL points in coins. Voice only (user's pick).

	The bonus (user's rule, "30% off, then an extra 30% off is 51%, not 60%"): a full
	bar adds the lifter's own gear Technique on that lift again, but as a second
	discount, bonus x (1 - bonus / 100). Gear +15 gets +12.75 more. No stat gear
	counts as MinimumGearTechnique (user's pick).

	Numbers marked [PROVISIONAL] are Claude's and need a real voice test.
]]

local CheerConfig = {}

-- The meet levels with cheering: State and up (user 2026-11-08). Nationals and the rest join here when they exist.
CheerConfig.MeetLevels = { State = true } :: { [string]: boolean }

-- A lifter with less stat gear than this on the lift counts as having this much (user's pick: +5).
CheerConfig.MinimumGearTechnique = 5

-- The technique a full bar adds for a lifter whose gear gives `gearTechnique` on the lift.
function CheerConfig.bonusFor(gearTechnique: number): number
	local base = math.clamp(if gearTechnique == gearTechnique then gearTechnique else 0, CheerConfig.MinimumGearTechnique, 100)
	return base * (1 - base / 100)
end

--[[
	The bar [PROVISIONAL]. Each cheer report says how loud (0..1) the cheerer was since the
	last one. One person cheering at full voice fills the bar in FillSecondsAlone; several fill it
	faster, up to MaxFillPerSecond together. Quiet, it drains at DrainPerSecond; once full it stays
	full for the rest of that attempt.
]]
CheerConfig.FillSecondsAlone = 10
CheerConfig.MaxFillPerSecond = 1 / 2.5
CheerConfig.DrainPerSecond = 1 / 30
-- How often the server works out the bars and who stands in which zone.
CheerConfig.TickSeconds = 0.25

-- The cheerer's device: how often it reports, and how loud counts. Its microphone's level (AudioAnalyzer.RmsLevel)
-- at QuietRms or under is 0 and at LoudRms or over is 1. [PROVISIONAL]: needs a real voice test.
CheerConfig.ReportSeconds = 0.25
CheerConfig.QuietRms = 0.02
CheerConfig.LoudRms = 0.12
-- The server ignores reports closer together than this, and counts at most this long since a cheerer's last report.
CheerConfig.MinReportGapSeconds = 0.15
CheerConfig.MaxReportSpanSeconds = 0.5

-- Coins go only to people who cheered at least this many full-voice seconds into that attempt's bar.
CheerConfig.HelperSeconds = 2

-- The zones' tag (invisible parts, StateArenaVenue), the attribute naming a zone's rack, and the one marking the lifters' zone (the
-- whole meet area), where each picks which rack's lifter to cheer for (user 2026-11-08: "They can only cheer for one lifter").
CheerConfig.ZoneTag = "CheerZone"
CheerConfig.ZoneRackAttribute = "RackIndex"
CheerConfig.ZoneChoiceAttribute = "CheerChoice"

-- Studio only: a number 0..1 on workspace that stands in for the local player's microphone, because Studio has no voice.
CheerConfig.StudioLoudnessAttribute = "CheerTestLoudness"

-- The lifter's own note when the bar is full (seconds on screen).
CheerConfig.LifterNoteSeconds = 4

return CheerConfig
