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
-- Which of the five halls they are in, while in the venue (the client hides WATCH for a lift in their own hall).
LocalMeetConfig.HallAttribute = "LocalMeetHall"
-- The LEAVE sign's prompt beside each platform's waiting spot (user 2026-11-24): tagged so the lifter's own client can
-- switch on the one for their platform (attributes Hall, Platform).
LocalMeetConfig.LeavePromptTag = "LocalMeetLeavePrompt"

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
-- A lifter signed up from elsewhere is told this long before their meet that they're about to be taken there.
LocalMeetConfig.CallSeconds = 15
-- The MEETS tab on the left edge: above the coins, clear of a phone's thumbstick (from the middle of the screen).
LocalMeetConfig.MeetsTabOffsetY = -146
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
	Scale, CN at full speed since 2026-11-19). In Studio a one-player meet pays in full, so the
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
	--[[
		THEIR GEAR (user 2026-11-12: "Computer lifter yes they can have random gear"; Studio 2026-11-16: "none of the
		npcs had gear"): random items from the shop (ShopConfig, all CENTRAL), worn like a player's. A singlet always
		(a meet's rule), the rest by chance. Over a tee, as players wear it (user's SBD reference).
	]]
	GearChances = { Singlet = 1.0, Belt = 0.85, KneeSleeves = 0.75, WristWraps = 0.6 },
	TeeColours = { Color3.fromRGB(28, 28, 32), Color3.fromRGB(236, 236, 232), Color3.fromRGB(70, 74, 82),
		Color3.fromRGB(28, 40, 78) },
	Glasses = { 376527500, 376526673 },
	GlassesChance = 0.15,
	-- Their build: how much wider/deeper (lifters are broad) and taller or shorter than a standard avatar.
	WidthSpread = { 1.0, 1.25 },
	HeightSpread = { 0.95, 1.05 },
	-- Roblox's own R15 idle (standing about between lifts) and cheer (only a fallback now: a meet level without
	-- celebrations, CelebrationConfig.MeetLevels, which today is none).
	IdleAnimationId = "rbxassetid://507766388",
	CheerAnimationId = "rbxassetid://507770677",
	-- How long the cheer after a good lift lasts before they walk back.
	GoodLiftCheerSeconds = 1.4,
	--[[
		THE SAME CELEBRATIONS, FAILS AND EMOTES AS PLAYERS (user 2026-11-01: "have the same animations. and emotes n
		stuff"; GAME_DESIGN §37.2 "What they do"). CLAUDE'S DEFAULTS (2026-11-18), WAITING FOR THE USER'S OK. Each is
		picked once when the body is made (like the gear), so a computer lifter keeps its own style all meet.
	]]
	-- Its celebration after a good lift: a rarity by these weights, then one celebration of that rarity at random
	-- (CelebrationConfig.List). Never a Legendary: those are the rare prizes players chase, and the longest.
	CelebrationRarityWeights = { Default = 30, Common = 25, Uncommon = 20, Rare = 15, Epic = 10 } :: { [string]: number },
	-- Its fail style (StationAnimationConfig.FailStyles; "Default" = the standard set).
	FailStyleWeights = { Default = 40, Bailout = 25, Grinder = 20, Dramatic = 15 } :: { [string]: number },
	--[[
		Its emotes while it stands waiting between lifts (EmoteConfig): the free ones, Belt Tighten when it wears a belt,
		and `ExtraEmotes` more of `EmoteWeights`' others at random, like a player who has won a few. Never Catch Your
		Breath (it sits on the floor). Each one plays only when it has stood still at its waiting spot for
		`SettleSeconds` (never walking, chalking, lifting, celebrating or seated), and only on the podium or while another
		lifter is still out for longer than the emote lasts (a round's chalking starts the moment the last one is back, and
		would cut it off); then every `GapSeconds` (random in the
		range) it plays one with `Chance`, weighted by `EmoteWeights`, never the same twice in a row. The first waits
		`FirstDelaySeconds`. On the podium it waves, then now and then one of its others, the same way.
	]]
	IdleEmotes = {
		EmoteWeights = { ChalkClap = 3, BeltTighten = 3, TrapSlap = 2, Wave = 1, DoubleBiceps = 1, PointLaugh = 1,
			MostMuscular = 1 } :: { [string]: number },
		ExtraEmotes = 2,
		SettleSeconds = 1.0,
		FirstDelaySeconds = { 4, 15 },
		GapSeconds = { 14, 32 },
		Chance = 0.7,
	},
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
--[[
	CHALKING UP while choosing a weight (GAME_DESIGN §37.5, user 2026-11-06). The lifter
	at the chalk stand in the warm-up room; the coach behind them on squat, chalking
	their upper back, and in front of them on bench and deadlift, talking to them.
	Made by art/scripts/chalk_animations.py; keep its distances and times in step.
]]
-- The coach follows the lifter out to watch, and back again, this long after them (user 2026-11-07): about 9 studs behind at the walking
-- speed, and on their own line.
LocalMeetConfig.CoachFollowSeconds = 1

LocalMeetConfig.Chalk = {
	LifterAnimationId = "rbxassetid://133012402954744",
	CoachBackAnimationId = "rbxassetid://116488229566310",
	CoachTalkAnimationId = "rbxassetid://91384972687834",
	-- From the lifter's spot to the stand's post, and to the coach behind them.
	StandAheadStuds = 1.75,
	CoachBehindStuds = 2,
	-- The coach in front of the lifter, facing them across the stand: in plain view of the camera, with the wall behind
	-- them, so nothing cuts off what they say (user 2026-11-06: their words went through the wall).
	CoachFrontAheadStuds = 3.7,
	CoachFrontSideStuds = 0.8,
	-- However fast everyone chooses, the walk out waits this long, so a lifter is seen chalking up once (to the claps).
	MinSeconds = 5.4,
	-- Where things happen in the animations' loop (seconds).
	RubAt = { 1.3, 3.1 },
	ClapAt = { 4.4, 4.77 },
	SlapAt = { 4.85, 5.15 },
	-- Chalk_Lifter's and Chalk_Coach_Back's loop (both the same length).
	LoopSeconds = 9,
	PuffParticles = 14,
	-- The camera: side-on to them, this far back and this far up from the middle of the group, gliding at this rate,
	-- with the group this share of the way across the clear part of the screen.
	Shot = { Back = 10, Up = 1.2, Rate = 3, ClearShare = 0.58 },
}

LocalMeetConfig.LiftMoment = {
	Shots = {
		-- Near the head referee's own view (user 2026-11-05): they stand at Z 13.45, facing the lifter through the rack.
		Squat = { eye = Vector3.new(0.8, 4.6, 10.5), look = Vector3.new(0, 3.2, -1.6) },
		-- From toward the feet: any closer to the side, a spotter's arm (X 6.25, Z -0.28) fills the screen.
		Bench = { eye = Vector3.new(3.4, 4.2, -9), look = Vector3.new(0, 1.8, -0.5) },
		Deadlift = { eye = Vector3.new(6.8, 3, 6.6), look = Vector3.new(0, 2.5, -1) },
	} :: { [string]: { eye: Vector3, look: Vector3 } },
	-- The slow push in takes this long; how far it goes is StakesBuild.PushInShare.
	PushInSeconds = 14,
	-- How quickly the camera catches up with where it should be (higher = tighter).
	WalkRate = 4,
	SetRate = 2,
	ReleaseRate = 6,
	-- The walk out: this far behind and above the lifter, looking this far ahead of them (studs).
	WalkBack = 10,
	WalkUp = 2.5,
	WalkAhead = 6,
	-- (The State meet's walk out has the coach's ritual's shots now: Ritual.Walk.)
	-- The longest the camera stays on the platform after the lights; it normally leaves when the lifter does.
	HoldMaxSeconds = 9,
	-- Gliding back to behind the lifter before the player has the camera again.
	ReleaseSeconds = 0.7,
	ReleaseBack = 13,
	ReleaseUp = 5,
	CardSlideSeconds = 0.35,
}

--[[
	The coach's ritual before the walk out (GAME_DESIGN §36.4, user 2026-11-11), a short cinematic on the lifter's own
	screen on every turn at State and up. Shot list from the user's reference video (IPF World Classic 2026): hard cuts,
	slightly handheld, the background soft, black bars top and bottom.
		Face      a profile close-up of the lifter chalking up; the attempt and weight come up below
		OverCoach over the coach's shoulder: the lifter faces the camera while the coach talks (their words as a subtitle)
		Hands     the hands, close, on the chalk claps
		SendOff   from behind: the coach, now behind the lifter, slaps their back twice and shouts (text only, user's choice)
		Follow    the walk out, low behind the lifter, toward the lit platform
		Side      low, from in front and to one side as they come to the bar; then the lift's own shot (LiftMoment)
		          takes over
	The first turn of each meet always plays it; after that a SKIP button cuts straight to the plain camera.
	Server timings are in seconds from "You're up" (the chalking up starts then).
	PERFORMANCE: on the lifter's own screen only: one camera move a frame, a depth of field effect and a few frames of
	screen text while it runs. Nothing for anyone else.
]]
LocalMeetConfig.Ritual = {
	-- Meets where it plays: State and up (Nationals, Worlds and Sheffield join here when they exist).
	MeetLevels = { State = true } :: { [string]: boolean },
	-- The chalking up lasts this long with the ritual (Chalk.MinSeconds without it).
	Seconds = 7.6,
	-- The coach leaves the front of the stand for the lifter's back (during the Hands shot, off camera).
	CoachMoveAt = 3.9,
	-- About how long the coach's walk round to the lifter's back takes, out wide round the Hands shot's camera (measured
	-- in Studio 2026-11-15: 2.3 s).
	CoachRoundSeconds = 2.3,
	-- The coach's back-slap animation starts this far into its loop, so the slaps come soon after they arrive.
	SlapLeadSeconds = 0.45,
	-- What the coach shouts with the slaps (text only).
	SendOffLines = { "LET'S GO!", "YOUR WEIGHT!", "THIS IS YOURS!", "BIG LIFT! GO!", "TAKE IT!" },
	-- The shots at the chalk stand: when each one cuts in (seconds from "You're up").
	Shots = {
		{ name = "Face", from = 0 },
		{ name = "OverCoach", from = 2.0 },
		{ name = "Hands", from = 4.15 },
		{ name = "SendOff", from = 5.1 },
	},
	-- The walk out: the Follow shot this long, then Side until the lifter is at the bar (MeetLiftMoment).
	FollowSeconds = 2.6,
	-- Follow: this far behind the lifter and this far above (below: low) their middle, looking this far ahead of them.
	-- Side: this far out to the side, this far ahead of them and this far above their middle, looking back at them (the
	-- earlier State walk out's shot, clear of the side referees: straight out to the side sat behind their chairs).
	-- Rate: how tightly the camera rides with them between cuts.
	Walk = { FollowBack = 6, FollowUp = -0.5, FollowAhead = 10, SideOut = 5, SideAhead = 11, SideUp = 0.6, SideLookUp = 0.8,
		Rate = 8 },
	-- The camera's lens (degrees) during the ritual: narrower than usual, like the video's long lens.
	FieldOfView = 42,
	-- The black bars: this share of the screen's height each, sliding in and out this fast.
	BarShare = 0.085,
	BarSeconds = 0.35,
	-- The caption under the Face shot: on screen this long.
	CaptionSeconds = 2.2,
	-- Handheld: how far (studs) and how much (degrees) the camera drifts, and how quickly.
	Shake = { Studs = 0.04, Degrees = 0.45, Speed = 0.55 },
	-- The soft background: blurred beyond the subject (FarIntensity), the foreground a little (NearIntensity).
	Focus = { FarIntensity = 0.5, NearIntensity = 0.45, InFocusRadius = 2.5 },
}

--[[
	Stakes that build through the attempts (GAME_DESIGN §37.5, user 2026-11-05). Each
	attempt has a level, and these lists have one entry per level:
		1  an opener
		2  a second attempt
		3  a third attempt
		4  the top: a third attempt with something on it, or the meet's last lift
	Something on the line (a record, the lead, a new best) raises an earlier attempt one
	level too. Volumes and brightness multiply the normal ones. First guesses: Claude
	can't hear or judge them, so the user's ear and eye set them.
	PERFORMANCE: no new parts, lights or sounds, and no extra messages except a second
	cheer after a big moment. Shouts from other platforms stay spaced out
	(MeetSoundConfig.LiftCrowd.OthersShoutGapSeconds), however high their levels.
]]
LocalMeetConfig.StakesBuild = {
	-- The crowd under the lift, and the single voices.
	CrowdVolume = { 1, 1.25, 1.6, 2 },
	ShoutVolume = { 1, 1, 1.1, 1.25 },
	-- The time between two shouts for this lifter, in seconds: a random time between these.
	ShoutGapSeconds = { { 1.0, 2.2 }, { 0.9, 1.9 }, { 0.7, 1.5 }, { 0.5, 1.1 } },
	-- The platform's stage light, from the walk out to the walk back.
	StageLight = { 1, 1.15, 1.4, 1.8 },
	-- The camera's slow push in: this share of the way to what it looks at.
	PushInShare = { 0.18, 0.22, 0.28, 0.34 },
	-- The crowd's answer at the lights, cheer or groan.
	AnswerVolume = { 1, 1.15, 1.35, 1.6 },
	-- A new best, a change of place or a record: the cheer is this much louder, and a second one follows it.
	BigMomentVolume = 1.3,
	SecondCheerSeconds = 0.7,
	-- How many single voices react after the lights (MeetSoundConfig.goodShouts, missShouts), when the first comes
	-- after the cheer or groan starts, and how far apart the rest are.
	ReactionVoices = { 1, 1, 2, 3 },
	ReactionDelaySeconds = 0.3,
	ReactionGapSeconds = 0.8,
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

--[[
	THE END-OF-MEET COACH SCENE (GAME_DESIGN §40.5, user 2026-11-25; server MeetEndScene, client MeetEndScene): when a
	meet ends, each player's coach walks up beside them, pats their back and says how it went (CoachVoiceConfig P lines),
	his hand resting on their back while he talks, before the podium. Skippable.
]]
LocalMeetConfig.MeetEnd = {
	--[[
		Coach_TalkPat (2026-11-26, user: "the coach should be talking through motions"), one version per coach body
		(art/scripts/meet_end_animations.py, anim_qa PASS on each body and the pair check on every lifter build): two pats,
		then the hand rests on the back with small pats while the free hand talks (points, chops, open palm, nods); 9 s, not
		looped. Elbows keep the arm's shape. Keyed by the player's active coach (CoachingConfig: "Owner" and the lift coaches
		"Squat" = Squatavious, "Bench" = Benchamin, "Deadlift" = Sumo). The platform coach plays the chosen coach's version
		and stands where its table says for the lifter's build, because on the lifter's screen MeetCoachLook's copy of that
		coach copies his joints and stands where he stands. `side` to the lifter's right, `back` behind them (+), `yaw`
		degrees turned toward them: coach = lifter * CFrame.new(side, 0, back) * Angles(0, yaw, 0), on the floor. An empty
		id: the scene runs without the pat. (The old Coach_BackPat ids: 122353536445792, 109214888150364, 72117187498410, 113519422221555.)
	]]
	PatVersions = {
		Owner = { -- the gym coach's own body (the Fat build: LifterBuild.BuildRules.Spotter)
			animationId = "rbxassetid://140445976565061",
			place = {
				Skinny = { side = 3.600, back = -0.110, yaw = 38 },
				SkinnyFat = { side = 3.638, back = -0.076, yaw = 38 },
				Fit = { side = 3.655, back = -0.198, yaw = 42 },
				Fat = { side = 3.678, back = -0.360, yaw = 45 },
				Muscular = { side = 3.670, back = -0.312, yaw = 45 },
				BigBuff = { side = 3.729, back = -0.217, yaw = 45 },
			},
		},
		Squat = { -- Coach Squatavious (short: pats the middle of the back)
			animationId = "rbxassetid://126206342907972",
			place = {
				Skinny = { side = 2.350, back = 0.315, yaw = 45 },
				SkinnyFat = { side = 2.390, back = 0.360, yaw = 45 },
				Fit = { side = 2.462, back = 0.457, yaw = 45 },
				Fat = { side = 2.540, back = 0.470, yaw = 45 },
				Muscular = { side = 2.530, back = 0.736, yaw = 38 },
				BigBuff = { side = 2.609, back = 0.809, yaw = 38 },
			},
		},
		Bench = { -- Coach Benchamin
			animationId = "rbxassetid://93052574568688",
			place = {
				Skinny = { side = 3.721, back = -0.117, yaw = 38 },
				SkinnyFat = { side = 3.759, back = -0.082, yaw = 38 },
				Fit = { side = 3.778, back = -0.208, yaw = 42 },
				Fat = { side = 3.798, back = -0.383, yaw = 45 },
				Muscular = { side = 3.829, back = -0.150, yaw = 42 },
				BigBuff = { side = 3.851, back = -0.236, yaw = 45 },
			},
		},
		Deadlift = { -- Coach Sumo
			animationId = "rbxassetid://104494360312128",
			place = {
				Skinny = { side = 3.991, back = -0.023, yaw = 38 },
				SkinnyFat = { side = 4.030, back = 0.013, yaw = 38 },
				Fit = { side = 4.049, back = -0.168, yaw = 42 },
				Fat = { side = 4.082, back = -0.312, yaw = 45 },
				Muscular = { side = 4.098, back = -0.110, yaw = 42 },
				BigBuff = { side = 4.125, back = -0.208, yaw = 45 },
			},
		},
	},
	-- A build missing from a table stands the coach as for this one.
	PatFallbackBuild = "Fit",
	--[[
		THE WALK TO THE PODIUM (user 2026-11-25: "if the lifter made podium let the cutscene have the lifter and coach walk
		together, with the coach having the same arm position ... until the lifter has to walk up to the podium"). At a
		Local meet hall a lifter in the top 3 has the scene on their own platform (the warm-up doorway is too narrow
		for two side by side), then they walk off its front together and along the front floor to the side of the
		podium. Coach_WalkPat per coach: the arm resting on the back over the walk (upper body only); `place` as
		PatVersions but walking (both face the way they go). An empty id: the walk runs without the arm.
	]]
	-- Coach_WalkTalk (2026-11-26): arm round the back, a pat every couple of seconds, the free hand talking; 8 s, looped.
	-- Beside the lifter with a gap, never behind. (The old Coach_WalkPat ids: 85161077240106, 86454459242819, 112595927308177, 125573340359200.)
	WalkPatVersions = {
		Owner = {
			animationId = "rbxassetid://109444446005513",
			place = {
				Skinny = { side = 3.900, back = 0.407 }, SkinnyFat = { side = 3.948, back = 0.432 }, Fit = { side = 3.963, back = 0.545 },
				Fat = { side = 4.142, back = 0.555 }, Muscular = { side = 3.996, back = 0.607 }, BigBuff = { side = 4.164, back = 0.661 },
			},
		},
		Squat = {
			animationId = "rbxassetid://125742556136485",
			place = {
				Skinny = { side = 2.973, back = 0.242 }, SkinnyFat = { side = 3.041, back = 0.257 }, Fit = { side = 3.241, back = 0.361 },
				Fat = { side = 3.371, back = 0.413 }, Muscular = { side = 3.491, back = 0.505 }, BigBuff = { side = 3.625, back = 0.581 },
			},
		},
		Bench = {
			animationId = "rbxassetid://135594416192492",
			place = {
				Skinny = { side = 4.002, back = 0.426 }, SkinnyFat = { side = 4.051, back = 0.456 }, Fit = { side = 4.058, back = 0.538 },
				Fat = { side = 4.248, back = 0.559 }, Muscular = { side = 4.087, back = 0.600 }, BigBuff = { side = 4.202, back = 0.697 },
			},
		},
		Deadlift = {
			animationId = "rbxassetid://109743382223923",
			place = {
				Skinny = { side = 4.279, back = 0.398 }, SkinnyFat = { side = 4.327, back = 0.421 }, Fit = { side = 4.350, back = 0.522 },
				Fat = { side = 4.516, back = 0.529 }, Muscular = { side = 4.391, back = 0.583 }, BigBuff = { side = 4.562, back = 0.624 },
			},
		},
	},
	WalkSpeed = 5.0, -- studs per second, both of them (a slow walk while he talks, the hand stays on the back)
	-- Where the lifter stands on the platform for the scene: this far to the left of its middle (the coach then has
	-- the platform at their right) and this far back from it.
	PlatformLeft = 1.8,
	PlatformBack = 3.0,
	--[[
		THE WALK WHILE HE TALKS (user 2026-11-26: "The 3rd screenshot is where the cutscene should start, waiting for the
		coach to walk up takes too long ... the coach should be walking with the lifter saying this with his arm patting
		his back"): the scene opens on the pat (the coach already beside them), then they walk off together and he says
		his line on the way. PlatformWalkSeconds of walking toward their platform's front, then a CUT to the floor in
		front of the platforms, walking into their place in the line for the podium (MeetCeremony.lineSpots) for at
		least LaneSeconds, longer for a longer line so he finishes talking on the way (his line plus LineTail).
	]]
	PlatformWalkSeconds = 2.0,
	LaneSeconds = 2.5,
	LineTail = 0.6,
	-- When they get there he lets go and walks away (user: "he should just walk away after the lifter gets by the
	-- podium"): this long, this far, then he is put back behind the warm-up wall when the ceremony's camera cuts in.
	LeaveSeconds = 1.8,
	LeaveStuds = 7.0,
	-- The scene's spot (server MeetEndScene.sceneSpot): this far out from where the lifter waited, facing a way with
	-- at least this much clear room at their right (the coach stands up to ~4.2 studs out) and in front (the camera).
	SceneStep = 6.0, -- (3 left the pair beside the doorway: the coach stood half in its edge, user's phone 2026-11-25)
	SceneRightRoom = 5.5,
	SceneFrontRoom = 9.0,
	-- (Studio 2026-11-26: the coach stood on a State rack's caller) the lifter's spot and the coach's (this far to their
	-- right) keep this far from anyone else standing there: the widest bodies are 4.31 across.
	SceneCoachSide = 3.7,
	SceneClearOfPeople = 3.8,
	-- (Off the podium) the scene holds while he talks, at least this long, and his line plus LineTail.
	PatSeconds = 5.0,
	-- He starts talking (and on the podium, walking) this long into the pat: after the two pats.
	LineAt = 1.35,
	-- A line's length when its take has none written (CoachVoiceConfig seconds).
	LineFallbackSeconds = 5.0,
	-- The whole scene never holds the podium longer than this (the walk to the podium included).
	MaxSeconds = 20.0,
	--[[
		THE LINE FOR THE PODIUM (user 2026-11-26: "The 1st, second, 3rd winner should be in line, in front the ref,
		facing the ref, then the lifters one bye one get their medal and handshake"): beside the podium on its bronze
		side, on the floor in front of the platforms (the racks and referee chairs are gone by then). Measured from the
		gold block's floor middle: the referee RefOut along the podium (its blocks end at 7.5), the line LineIn toward
		the crowd (the coach walks on its platforms' side, clear of their edge), the first in line FirstGap in front of
		the referee (about the medal's reach), the others SlotGap apart (front to back: the deepest build is about 2.6).
		Leaving with the medal, the lifter steps out to StripOut toward the crowd (clear of the referee, who steps
		RefStepBack toward the platforms) and walks along the podium's front to their block.
	]]
	Line = {
		RefOut = 9.4,
		LineIn = 1.6,
		FirstGap = 3.35,
		SlotGap = 4.6,
		StripOut = 5.1,
		RefStepBack = 1.0,
		RefWalkOff = 14.0, -- after the last award he walks this far on past the line's end and goes (out of the close-up)
	},
	-- The camera: a held two-shot, this far away (less where a wall is), looking at this height over their feet (chest
	-- high, so both heads are in the frame), gliding this far in; HeadHeight is where it checks it can see their heads.
	CameraDistance = 10.0,
	CameraHeight = 3.8,
	CameraGlide = 1.0,
	HeadHeight = 5.2,
}

return LocalMeetConfig
