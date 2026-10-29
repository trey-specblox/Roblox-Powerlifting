--!strict
--[[
	LocalMeetConfig
	Shared / Config

	The Local meet, the first meet against other players (GAME_DESIGN.md §29.10
	"The Local meet — first build", user 2026-10-29): everyone lifts together on
	their own platform, one ranking by score, a meet every 10 minutes with at
	least 2 signed-up players, in a separate building on the same server.

	STEP 1 (this build): the meet itself on a TEMPORARY venue. Nothing is saved
	yet; the rewards (§33.3b) are step 2 and the Blender venue step 3.
	The numbers are [PROVISIONAL].
]]

local MeetConfig = require(script.Parent:WaitForChild("MeetConfig"))
local MockMeetConfig = require(script.Parent:WaitForChild("MockMeetConfig"))

local LocalMeetConfig = {}

-- ------------------------------------------------ getting there and back

-- The invisible part in the gym that carries the "Go to the Local Meet" prompt (RoomProps tags it).
LocalMeetConfig.EntranceTag = "LocalMeetEntrance"
LocalMeetConfig.PromptHoldSeconds = 0.5
LocalMeetConfig.PromptDistanceStuds = 8

-- The player attribute the server sets while a player is in the venue (true), and while they lift in a
-- meet (their platform number). The client shows the venue screen and the meet screen from them.
LocalMeetConfig.VenueAttribute = "LocalMeetVenue"
LocalMeetConfig.PlatformAttribute = "LocalMeetPlatform"

-- Where the temporary venue is built: far from the gym (about 2000 studs across round 0,0,0) and from
-- the Mock Meet rooms (+X from 4000), high up, so nobody walks in by accident.
LocalMeetConfig.Origin = Vector3.new(-4000, 1000, 0)

-- ------------------------------------------------ the meet

-- One platform per lifter, side by side; more sign-ups than this wait for the next meet.
LocalMeetConfig.MaxLifters = 8
LocalMeetConfig.PlatformSpacingStuds = 24

-- A meet starts on every multiple of CycleSeconds of server time (a fixed timetable), if enough lifters
-- signed up; sign-ups close SignUpClosesSeconds before. A start that falls during a running meet is
-- skipped and its sign-ups carry to the next one.
LocalMeetConfig.CycleSeconds = 10 * 60
LocalMeetConfig.SignUpClosesSeconds = 60
-- In Studio, so a test does not wait ten minutes.
LocalMeetConfig.StudioCycleSeconds = 90
LocalMeetConfig.StudioSignUpClosesSeconds = 15

-- Real players needed to hold a meet. In Studio one is enough, so a test can run alone; a one-lifter
-- meet never counts as a win (that rule comes with the rewards, step 2).
LocalMeetConfig.MinimumLifters = MeetConfig.OfficialLocalMeetMinimumRealPlayers
LocalMeetConfig.StudioMinimumLifters = 1

-- The timers of each round: everyone chooses, then everyone lifts (each presses LIFT when ready), then
-- the referees' lights show. A round moves on as soon as every lifter is done.
LocalMeetConfig.WeighInSeconds = 6
LocalMeetConfig.ChooseSeconds = MockMeetConfig.ChooseSeconds
LocalMeetConfig.ReadySeconds = MockMeetConfig.ReadySeconds
LocalMeetConfig.ResultSeconds = 6
-- How long the final standings show before the lifters step off the platforms.
LocalMeetConfig.DoneSeconds = 20

LocalMeetConfig.OpenerSuggestionPercent = MockMeetConfig.OpenerSuggestionPercent
LocalMeetConfig.WeightStepKg = MockMeetConfig.WeightStepKg

-- How long a player must wait between two presses of Exit or Sign up (stops button spam).
LocalMeetConfig.ButtonCooldownSeconds = 1

assert(LocalMeetConfig.MaxLifters >= 1, "[LocalMeetConfig] MaxLifters must be at least 1")
assert(
	LocalMeetConfig.SignUpClosesSeconds < LocalMeetConfig.CycleSeconds
		and LocalMeetConfig.StudioSignUpClosesSeconds < LocalMeetConfig.StudioCycleSeconds,
	"[LocalMeetConfig] sign-ups must close inside the cycle"
)

return LocalMeetConfig
