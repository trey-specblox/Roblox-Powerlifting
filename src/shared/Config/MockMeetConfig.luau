--!strict
--[[
	MockMeetConfig
	Shared / Config

	The Mock Meet (GAME_DESIGN.md §29.10 "The Solo meet — first build", user
	2026-10-27): a player checks in at the desk in the gym's Mock Meet Room and
	is moved into their OWN private meet room, so there is never a crowd or a
	line. Each private room is built for one player far away from the gym, and
	cleared away when they leave.

	Part 1 (this file's first version): the rooms and the move in and out. The
	meet itself (weigh-in, attempts, lifts) is Part 2. Nothing is saved.
]]

local MockMeetConfig = {}

-- The invisible part in front of the check-in desk that carries the prompt (RoomProps tags it).
MockMeetConfig.CheckInTag = "MockMeetCheckIn"
MockMeetConfig.PromptHoldSeconds = 0.5
MockMeetConfig.PromptDistanceStuds = 8

-- The player attribute the server sets while a player is in their private room
-- (the room's slot number); the client shows the Leave button from it.
MockMeetConfig.SlotAttribute = "MockMeetSlot"

--[[
	Where the private rooms are built: slot 1's centre at Origin, the next ones
	Spacing apart along +X. Far outside the gym (whose whole map is about 2000
	studs across around 0,0,0) and high up, so nobody in the gym can see or
	reach them. One slot per player at most, so MaxSlots matches the server's
	player limit.
]]
MockMeetConfig.Origin = Vector3.new(4000, 1000, 0)
MockMeetConfig.SpacingStuds = 200
MockMeetConfig.MaxSlots = 60

-- The private room's inside, in studs: across (X), deep (Z) and high.
MockMeetConfig.RoomSize = Vector3.new(64, 26, 72)

-- How long a player must wait between two Leave presses (stops button spam).
MockMeetConfig.LeaveCooldownSeconds = 1

return MockMeetConfig
