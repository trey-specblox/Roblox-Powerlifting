--!strict
--[[
	LocalMeetConfig
	Shared / Config

	The Local meet, the first meet against other players (GAME_DESIGN.md §29.10
	"The Local meet — first build", user 2026-10-29): everyone lifts together on
	their own platform, one ranking by score, a meet every 10 minutes with at
	least 1 signed-up player (computer lifters fill the rest, §37.2), in a
	separate building on the same server.

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

--[[
	FIVE MEETS AT ONCE (user 2026-11-05: "I am not waiting 10 minutes"): five full halls, each with its own
	meet, placings and rewards. Further apart than a client loads the world around itself (workspace
	StreamingTargetRadius 1024), so a player only ever has the hall they are in loaded.
]]
LocalMeetConfig.HallCount = 5
LocalMeetConfig.HallSpacingStuds = 1400

-- Where hall `index` is built (1 = Origin, the rest further out along -X, away from the gym).
function LocalMeetConfig.hallOrigin(index: number): Vector3
	return LocalMeetConfig.Origin - Vector3.new((index - 1) * LocalMeetConfig.HallSpacingStuds, 0, 0)
end

-- ------------------------------------------------ the meet

-- One platform per lifter, side by side; more sign-ups than this wait for the next meet.
LocalMeetConfig.MaxLifters = 8
LocalMeetConfig.PlatformSpacingStuds = 24

-- A hall's meet starts once every CycleSeconds of server time (a fixed timetable), if enough lifters signed
-- up; sign-ups close SignUpClosesSeconds before. A start that falls during a running meet is skipped and its
-- sign-ups carry to the next one. The halls are evenly staggered, so somewhere a meet starts every
-- CycleSeconds / HallCount: 2 minutes.
LocalMeetConfig.CycleSeconds = 10 * 60
LocalMeetConfig.SignUpClosesSeconds = 60
-- In Studio, so a test does not wait ten minutes.
LocalMeetConfig.StudioCycleSeconds = 90
LocalMeetConfig.StudioSignUpClosesSeconds = 15

-- Real players needed to hold a meet: ONE (user 2026-11-01, GAME_DESIGN §37.2: Local and Regional meets always
-- run; computer lifters fill the empty spots).
LocalMeetConfig.MinimumLifters = 1
LocalMeetConfig.StudioMinimumLifters = 1

--[[
	STEP 2, THE REWARDS (§33.3b, §37.2): a meet pays IN FULL (CN at full
	speed, the prize pot, gym records, titles, a win) only when it STARTED
	with at least this many REAL players. With one real player it pays the
	reduced rewards of §37.2 (finishing and 9/9 coins, finishing ladder points,
	Scale, CN at half speed). In Studio a one-player meet pays in full, so the
	full rewards can be tested alone; set the workspace attribute
	"ForceSoloMeet" to true to test the reduced ones. A live server never uses
	that.
]]
LocalMeetConfig.RewardMinimumLifters = MeetConfig.OfficialLocalMeetMinimumRealPlayers
LocalMeetConfig.StudioRewardMinimumLifters = 1

--[[
	THE REFEREE'S COMMANDS (user 2026-11-01, GAME_DESIGN §37.5, as in real
	powerlifting), said by the head referee in a bubble only the lifter sees:
		phases   the command as each minigame phase starts (none = the lifter
		         goes when ready: the deadlift)
		good     after a good lift: when the lift is finished (rack), or the moment
		         it is locked out (`goodAtLockout`: the deadlift's DOWN)
]]
LocalMeetConfig.RefereeCommands = {
	Squat = { phases = { "SQUAT!" }, good = "RACK!", goodAtLockout = false },
	Bench = { phases = { "START!", "PRESS!" }, good = "RACK!", goodAtLockout = false },
	Deadlift = { phases = {}, good = "DOWN!", goodAtLockout = true },
} :: { [string]: { phases: { string }, good: string, goodAtLockout: boolean } }

--[[
	COMPUTER LIFTERS (§37.2, ComputerLifters): with fewer real players than
	FillToLifters, computer lifters fill the meet up to it. They never take a
	reward from a real player. All numbers [PROVISIONAL].
]]
LocalMeetConfig.FillToLifters = 4
LocalMeetConfig.ComputerLifters = {
	-- Each copies a real lifter's Competition Numbers times a random factor in this range ("near your level").
	StrengthSpread = { 0.92, 1.08 },
	-- Its bodyweight: the real lifter's times this (a little lighter or the same).
	BodyweightSpread = { 0.97, 1.0 },
	-- Attempts 1, 2 and 3 aim at these shares of its CN, and are made with these chances.
	AttemptShares = { 0.9, 0.96, 1.02 },
	MakeChances = { 0.95, 0.85, 0.6 },
	-- How long it takes over a lift, in seconds.
	LiftSeconds = { 4, 9 },
	-- The walk out to the platform and back, for computer lifters and players alike (studs per second), with
	-- Roblox's own R15 walk animation.
	WalkSpeed = 9,
	WalkAnimationId = "rbxassetid://507777826",
	-- Made-up first names (never real people); "(CPU)" is added.
	Names = { "Marco", "Dana", "Kai", "Rosa", "Theo", "Imani", "Felix", "Nadia", "Jonah", "Priya", "Luca", "Yara",
		"Omar", "Greta", "Silas", "Mei", "Ruben", "Tess", "Emil", "Zora" },
	SkinColours = { Color3.fromRGB(234, 192, 160), Color3.fromRGB(198, 145, 105), Color3.fromRGB(141, 95, 65),
		Color3.fromRGB(96, 63, 43), Color3.fromRGB(245, 214, 186) },
	-- Singlet colours, many and bright (props colour variety).
	SingletColours = { Color3.fromRGB(30, 90, 200), Color3.fromRGB(220, 60, 50), Color3.fromRGB(40, 170, 90),
		Color3.fromRGB(240, 190, 30), Color3.fromRGB(140, 60, 190), Color3.fromRGB(20, 160, 170),
		Color3.fromRGB(240, 120, 30), Color3.fromRGB(35, 35, 40) },
	--[[
		THEIR AVATARS (user 2026-11-01: "Make sure the npc have avatars"): free
		hair and glasses made by Roblox itself, found with the catalog search
		(AvatarEditorService, Studio 2026-11-01). Never a real player's avatar.
		Each computer lifter gets a random hairstyle (sometimes none), now and
		then glasses, and a build a little bigger or smaller.
	]]
	Hair = { 9174353649, 9244089488, 9244097555, 7193448988, 7193401217, 7193445686, 7193450455, 9243987340,
		7193449810, 7193444640, 6993754725, 7193386173, 9244038785, 376524487, 1103003368, 9174354743, 451221329,
		2956239660, 451220849, 63690008, 9244021842, 9243992729, 3814476174, 3814474927, 9244111257, 9244095135,
		7193442167, 376526888, 9174355709 },
	NoHairChance = 0.12,
	Glasses = { 376527500, 376526673 },
	GlassesChance = 0.15,
	-- Their build: how much wider/deeper (lifters are broad) and taller or shorter than a standard avatar.
	WidthSpread = { 1.0, 1.25 },
	HeightSpread = { 0.95, 1.05 },
	-- Roblox's own R15 idle (standing about between lifts) and cheer (a good lift, and the podium).
	IdleAnimationId = "rbxassetid://507766388",
	CheerAnimationId = "rbxassetid://507770677",
	-- How long the cheer after a good lift lasts before they walk back.
	GoodLiftCheerSeconds = 1.4,
}

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

-- ------------------------------------------------ "your moment" (GAME_DESIGN §37.5, user 2026-11-05)

--[[
	The lifter's own screen during their turn (client MeetLiftMoment). Shots are
	rack-local: from the rack's pivot, +Z toward the rack from the walk-in side,
	feet near Y = 0. `eye` is where the camera stands, `look` what it looks at.
]]
LocalMeetConfig.LiftMoment = {
	Shots = {
		-- Near the head referee's own view (user 2026-11-05): they stand at Z 13.45, facing the lifter through the rack.
		Squat = { eye = Vector3.new(0.8, 4.6, 10.5), look = Vector3.new(0, 3.2, -1.6) },
		-- From toward the feet: any closer to the side, a spotter's arm (X 6.25, Z -0.28) fills the screen.
		Bench = { eye = Vector3.new(3.4, 4.2, -9), look = Vector3.new(0, 1.8, -0.5) },
		Deadlift = { eye = Vector3.new(6.8, 3, 6.6), look = Vector3.new(0, 2.5, -1) },
	} :: { [string]: { eye: Vector3, look: Vector3 } },
	-- The slow push in: this share of the way to what it looks at, over this long.
	PushInShare = 0.18,
	PushInSeconds = 14,
	-- How quickly the camera catches up with where it should be (higher = tighter).
	WalkRate = 4,
	SetRate = 2,
	ReleaseRate = 6,
	-- The walk out: this far behind and above the lifter, looking this far ahead of them (studs).
	WalkBack = 10,
	WalkUp = 2.5,
	WalkAhead = 6,
	-- The longest the camera stays on the platform after the lights; it normally leaves when the lifter does.
	HoldMaxSeconds = 9,
	-- Gliding back to behind the lifter before the player has the camera again.
	ReleaseSeconds = 0.7,
	ReleaseBack = 13,
	ReleaseUp = 5,
	CardSlideSeconds = 0.35,
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
