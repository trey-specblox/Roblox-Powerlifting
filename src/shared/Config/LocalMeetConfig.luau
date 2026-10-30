--!strict
--[[
	LocalMeetConfig
	Shared / Config

	The Local meet, the first meet against other players (GAME_DESIGN.md §29.10
	"The Local meet — first build", user 2026-10-29): everyone lifts together on
	their own platform, one ranking by score, a meet every 10 minutes with at
	least 2 signed-up players, in a separate building on the same server.

	STEP 1: the meet itself on a TEMPORARY venue. STEP 2: its rewards (§33.3b:
	CN raises within the meet allowance, Competition Scale, best Total, Local
	wins). Step 3 is the Blender venue. The numbers are [PROVISIONAL].
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

-- Real players needed to hold a meet. In Studio one is enough, so a test can run alone.
LocalMeetConfig.MinimumLifters = MeetConfig.OfficialLocalMeetMinimumRealPlayers
LocalMeetConfig.StudioMinimumLifters = 1

--[[
	STEP 2, THE REWARDS (§33.3b): a meet raises CN (within the build's meet
	allowance) and counts a win only when it STARTED with at least this many
	lifters, so only meets against other players reward. In Studio a one-lifter
	meet counts too, so the rewards can be tested alone; a live server never
	uses that.
]]
LocalMeetConfig.RewardMinimumLifters = MeetConfig.OfficialLocalMeetMinimumRealPlayers
LocalMeetConfig.StudioRewardMinimumLifters = 1

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

-- ------------------------------------------------ the awards (GAME_DESIGN §29.10 "Venue redesign and awards ceremony")

--[[
	When the meet ends the awards stage stands for DoneSeconds: everyone in the
	venue gets the camera shots below, the crowd cheers, and the WINNER's theme
	song plays while the winner does their celebration. The theme and the
	celebration are DEFAULTS for now; the user's custom theme songs and
	celebrations plug in on the server (LocalMeetService themeFor /
	celebrationFor), so these are only what a winner without their own gets.
	The sounds are our own (art/scripts/make_awards_sounds.py); the cheer
	animation is Roblox's own R15 "cheer" emote.
]]
LocalMeetConfig.Awards = {
	DefaultThemeSoundId = "rbxassetid://116724943474598",
	DefaultCelebrationAnimationId = "rbxassetid://507770677",
	CrowdCheerSoundId = "rbxassetid://74322878777614",
	ThemeVolume = 0.7,
	CheerVolume = 0.6,
	-- The camera, in seconds from the start: the whole stage, then the winner up close, then the stage again
	-- until DoneSeconds ends.
	WideShotSeconds = 4,
	CloseUpSeconds = 10,
	-- How far the shots stand from what they look at (studs).
	WideShotDistance = 30,
	CloseUpDistance = 8,
	-- How long the camera takes to glide from one shot to the next.
	GlideSeconds = 1.2,
}

-- ------------------------------------------------ the warm-up room (GAME_DESIGN §29.10, build step 3)

--[[
	The warm-up racks behind the platforms work like a meet attempt (user
	2026-10-29: "make them work like a normal meet"; at Nationals and Worlds
	lifters wait longer and practise over and over): hold E at a rack, pick the
	lift and the bar weight (WeightStepKg steps inside the meet's 40-125% of
	CN), LIFT runs the real meet minigame at meet difficulty, GOOD LIFT or NO
	LIFT, as often as you like. PRACTICE ONLY: nothing is saved (no CN, no
	Scale, no records).
]]
LocalMeetConfig.WarmUp = {
	PromptAction = "Warm up",
	PromptObject = "Warm-up rack",
	-- The first weight offered for a lift: this share of its CN, like a meet opener.
	StartPercent = MockMeetConfig.OpenerSuggestionPercent,
	-- Where the lifter stands: this far in front of the rack's middle, facing away from it (like a platform).
	LiftSpotInFrontStuds = 4,
}

assert(LocalMeetConfig.MaxLifters >= 1, "[LocalMeetConfig] MaxLifters must be at least 1")
assert(
	LocalMeetConfig.SignUpClosesSeconds < LocalMeetConfig.CycleSeconds
		and LocalMeetConfig.StudioSignUpClosesSeconds < LocalMeetConfig.StudioCycleSeconds,
	"[LocalMeetConfig] sign-ups must close inside the cycle"
)

return LocalMeetConfig
