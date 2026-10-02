--!strict
--[[
	MeetConfig
	Shared / Config

	Competition rules and thresholds, centralised so meet formats can be retuned
	or extended without touching meet logic.

	Sources: GAME_DESIGN.md sections 15-17 and Group C answers Q11/Q12.
]]

local MeetConfig = {}

-- Q11: three attempts on each of the three competition lifts.
MeetConfig.AttemptsPerLift = 3

-- Q11: the competition lifts, in the order they are contested.
MeetConfig.LiftOrder = { "Squat", "Bench", "Deadlift" }

--[[
	Q11: the smallest permitted jump between two DIFFERENT attempt weights.
	Repeating a weight exactly is governed separately, below.

	This is a minimum increase, not a quantisation. 182.5 -> 185 is legal, and so
	is 182.5 -> 186.25, because the design specifies only a floor on the increase.
]]
MeetConfig.MinimumIncrementKg = 2.5

--[[
	NOTE: THIS RULE WAS NOT SPECIFIED AND IS A BEST READING OF THE DESIGN.

	Q11 states a player "can repeat a failed weight or increase it", and that
	after a failed attempt they may repeat or increase. It does not say what
	happens after a SUCCESSFUL attempt.

	Real powerlifting requires an increase after a good lift: you cannot take a
	weight you have already made. Since Q11 opens with "follow real powerlifting
	closely", that is the behaviour chosen here.

	Set this to true to allow repeating a successfully completed weight.
]]
MeetConfig.AllowRepeatAfterGoodLift = false

--[[
	Tolerance for comparing attempt weights, so floating-point noise arriving from
	a client cannot make a legal declaration look illegal (or the reverse).
]]
MeetConfig.WeightEpsilonKg = 0.001

-- Q12: an official Local Meet needs at least this many real players.
MeetConfig.OfficialLocalMeetMinimumRealPlayers = 2

-- Q12 / section 16: Nationals keeps its 3 real competitor minimum.
MeetConfig.OfficialNationalsMinimumRealPlayers = 3

--[[
	Section 15: official Local Meet wins needed to unlock Nationals.

	Q12 is explicit that only official multiplayer wins count. Solo and practice
	meets must never increment this, or "National Champion" stops meaning anything.
]]
MeetConfig.LocalVictoriesForNationals = 10

return MeetConfig
