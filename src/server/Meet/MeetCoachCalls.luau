--!strict
--[[
	MeetCoachCalls
	Server / Meet

	Which big-moment line your coach yells at a meet (GAME_DESIGN §40.5 "Big-moment lines", user 2026-11-25):

	- walkOut: as you walk out for a THIRD attempt that decides places, he screams what it is for: first place,
	  the podium, a place up, or (the meet's very last attempt) leave it all out there. Nil when nothing big hangs on
	  it, and the usual ready line is said instead.
	- bigYell: after a big made lift (a third attempt, or one that took the lead or moved you up) he screams
	  "AYYYYYYY!" / "LET'S GOOOOOO!"; nil otherwise, and the usual good-lift line is said instead.

	The words match round 3 of the coach voice lines exactly (CoachVoiceConfig: W and H keys), so CoachVoice plays the
	coach's own take for the bubble. Kept out of LocalMeetService (its main chunk is at Luau's 200-local limit).
]]

local MeetCoachCalls = {}

local random = Random.new()

local FIRST_PLACE = "THIS IS FOR FIRST PLACE!" -- W1
local TAKE_THE_LEAD = "TAKE THE LEAD! THIS IS YOURS!" -- W2 (the take says "leed")
local PODIUM = "THIS PUTS YOU ON THE PODIUM!" -- W3
local MOVE_UP = "MAKE THIS AND YOU MOVE UP!" -- W4
local LAST_LIFT = "LAST LIFT OF THE DAY! LEAVE IT ALL OUT THERE!" -- W5
local YELLS = { "AYYYYYYY!", "LET'S GOOOOOO!", "THAT'S WHAT I'M TALKING ABOUT!" } -- H1-H3
local IN_FIRST = "YOU'RE IN FIRST! LET'S GO!" -- H4
local PODIUM_PLACES = 3
local THIRD_ATTEMPT = 3

--[[
	`stakes` is the attempt's line for the lifter's card (LocalMeetService.stakesFor: "TO TAKE THE LEAD", "FOR THE
	WIN", "TO MOVE UP TO 2ND", "FOR 3RD PLACE", ...), `placeNow` their place before it (nil with no score yet).
]]
function MeetCoachCalls.walkOut(stakes: string?, attemptNumber: number, lastOfMeet: boolean, placeNow: number?): string?
	if attemptNumber < THIRD_ATTEMPT then
		return nil
	end
	if stakes == "FOR THE WIN" then
		return FIRST_PLACE
	end
	if stakes == "TO TAKE THE LEAD" then
		return if random:NextInteger(1, 2) == 1 then FIRST_PLACE else TAKE_THE_LEAD
	end
	local target = if stakes and (string.find(stakes, "MOVE UP TO", 1, true) or string.find(stakes, "PLACE", 1, true))
		then tonumber(string.match(stakes, "(%d+)"))
		else nil
	if target then
		return if target <= PODIUM_PLACES and (placeNow == nil or placeNow > PODIUM_PLACES) then PODIUM else MOVE_UP
	end
	if lastOfMeet then
		return LAST_LIFT
	end
	return nil
end

-- `moment` is what the good lift just did (LocalMeetService.momentAfter: "TAKES THE LEAD!", "UP TO 2ND!", ...).
function MeetCoachCalls.bigYell(attemptNumber: number, moment: string?): string?
	if moment == "TAKES THE LEAD!" then
		return if random:NextInteger(1, 2) == 1 then IN_FIRST else YELLS[random:NextInteger(1, #YELLS)]
	end
	local movedUp = moment ~= nil and string.sub(moment, 1, 6) == "UP TO "
	if attemptNumber >= THIRD_ATTEMPT or movedUp then
		return YELLS[random:NextInteger(1, #YELLS)]
	end
	return nil
end

return MeetCoachCalls
