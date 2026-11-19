--!strict
--[[
	NationalsConfig
	Shared / Config

	Nationals (GAME_DESIGN.md §39, user 2026-11-17), STEP 1: the gathering. At set times, every
	spot-holder who signed up in any server is sent to ONE Nationals server (a reserved server), where
	they arrive in the stand-in venue: the State arena dressed as NATIONALS. The meet itself (per class,
	titles, the x5 pot, the Worlds spot) is step 2; the new arena from the user's photos is step 3.

	Decided by the user (2026-11-17, picked from options):
		- sign up in the MEETS list AND at a NATIONALS desk (in the State arena, beside the State desk)
		- a spot-holder who is mid-meet elsewhere when Nationals starts is PULLED OUT of that meet (it
		  counts as withdrawing) and goes to Nationals
		- it needs 2 lifters across all servers; fewer, no Nationals and the sign-ups carry to the next

	All numbers [PROVISIONAL].
]]

local NationalsConfig = {}

--[[
	LIVE = false until step 2 (the meet itself) is built: in a live server only admins (AdminService's
	list) see the NATIONALS row and desk, so the cross-server teleport can be tested in the real game
	without sending real players to an empty arena. In Studio it is always on. Turning it on is the
	user's decision.
]]
NationalsConfig.Live = false

--[[
	TESTERS (user 2026-11-17: other accounts, e.g. on a phone, couldn't see Nationals): while not Live, these accounts
	see and join Nationals too, like the admins. Their UserIds (Roblox profile link: roblox.com/users/<UserId>/profile).
	They still need a Nationals spot (the admin panel's NATIONALS PLACINGS can give it while they're in your server).
]]
NationalsConfig.TesterUserIds = {
	[1126689936] = true, -- Vietnames_e (user 2026-11-17)
} :: { [number]: boolean }

-- The admin panel's START NATIONALS NOW: the next Nationals starts this long after the press, in every server (so each
-- server sees it, warns its lifters and moves their sign-ups in time). Servers with someone signed up look every
-- ForcePollSeconds.
NationalsConfig.ForceLeadSeconds = 30
NationalsConfig.ForcePollSeconds = 5

-- ------------------------------------------------ the timetable

-- A Nationals starts every this many seconds, on the same clock in every server (UTC: 00:00, 02:00, ...).
NationalsConfig.CycleSeconds = 2 * 60 * 60
-- While not Live: the admins' test Nationals in live servers, more often so a test doesn't wait 2 hours.
NationalsConfig.TestCycleSeconds = 10 * 60
-- In Studio, to test alone without waiting.
NationalsConfig.StudioCycleSeconds = 120

-- Sign-ups close this long before the start (so every server's list is written in time).
NationalsConfig.SignUpClosesSeconds = 60
NationalsConfig.StudioSignUpClosesSeconds = 15
-- The signed-up lifters are warned this long before the start ("you'll be taken out of any meet").
NationalsConfig.CallSeconds = 30

-- It needs this many lifters across all servers (user 2026-11-17); fewer, no Nationals and every sign-up carries over.
NationalsConfig.MinimumLifters = 2
-- Studio (one player) and the admins' test Nationals while not Live.
NationalsConfig.StudioMinimumLifters = 1
NationalsConfig.TestMinimumLifters = 1
-- At most this many go to one Nationals server, first signed up first (the State arena's 4 racks x 10). The rest carry
-- over. NOTE: a reserved server holds at most the place's Max Players (Creator Dashboard); keep that at least this high.
NationalsConfig.MaxLifters = 40

-- ------------------------------------------------ the shared sign-up list (MemoryStore)

-- One sorted map per Nationals (this name .. its start time): key = UserId, value = the entry, sorted by sign-up time.
NationalsConfig.SignUpMapPrefix = "NationalsSignUps_"
-- One sorted map for every Nationals' outcome (key = its start time) and each Nationals server's facts (key = "server_" ..
-- its PrivateServerId).
NationalsConfig.RoundMapName = "NationalsRounds"
-- Studio's keys never mix with a live server's.
NationalsConfig.StudioPrefix = "Studio_"
-- How long the entries last after the start (MemoryStore forgets them by itself).
NationalsConfig.SignUpKeepSeconds = 15 * 60
NationalsConfig.RoundKeepSeconds = 3 * 60 * 60
-- At the start: how long the server that runs the gathering waits for late writes before reading the list, how long a
-- server whose claim went quiet keeps it, and how long every server waits for the outcome.
NationalsConfig.SettleSeconds = 4
NationalsConfig.ClaimStaleSeconds = 40
NationalsConfig.OutcomeWaitSeconds = 75
-- How often a server with spot-holders online re-reads how many have signed up across all servers (for the list).
NationalsConfig.CountRefreshSeconds = 30

-- ------------------------------------------------ the teleport

NationalsConfig.TeleportTries = 3
NationalsConfig.TeleportRetrySeconds = 4
-- In the Nationals server: how long it keeps trying to read who it is for.
NationalsConfig.ServerInfoTries = 10

-- ------------------------------------------------ the arena (NationalsArenaVenue, GAME_DESIGN §39 step 3)

-- Workspace attribute set in a Nationals server (and in Studio while its stand-in runs): the Nationals' start time.
NationalsConfig.ServerAttribute = "NationalsServer"
-- Player attribute while a lifter is at Nationals: the class their spot is in ("74 kg").
NationalsConfig.AtNationalsAttribute = "AtNationals"
-- On the arena's signs.
NationalsConfig.EventTitle = "NATIONALS"
NationalsConfig.EventSub = "NATIONAL CHAMPIONSHIP"

-- The building on the plaza (every server, user 2026-11-17): the middle of its glass front, left of the gym's front and
-- opposite the State arena's entrance; it faces the gym's doors (+Z). It spans about x -236..-80, z -200..-117.
NationalsConfig.BuildingOrigin = Vector3.new(-158, 0, -130)
-- The hall, far from the gym like the State arena (0, 1000, 4000), the Local meet (-4000, 1000, 0) and the Mock Meet (+4000).
NationalsConfig.HallOrigin = Vector3.new(0, 1000, -4000)
-- The 4 platforms across the hall (the hall's own x, as the build script).
NationalsConfig.PlatformXs = { -78, -26, 26, 78 }
-- The point in front of the porch's doors carrying the "Go inside" prompt; the hall model's tag (NationalsHallLights).
NationalsConfig.EntranceTag = "NationalsEntrance"
NationalsConfig.HallTag = "NationalsHall"
-- Player attribute while they are inside the hall.
NationalsConfig.InHallAttribute = "InNationalsHall"
-- The doors' and the desk's prompts.
NationalsConfig.PromptHoldSeconds = 0.5
NationalsConfig.PromptDistanceStuds = 8

-- A press of SIGN UP / LEAVE, at most this often per player.
NationalsConfig.ButtonCooldownSeconds = 0.75

-- The prize pot multiplier shown on the list (§39: 5x the Local pot), paid per weight class (MeetLevelConfig.Levels.Nationals).
NationalsConfig.PotMultiplier = 5

-- ---------------------------------------------------------------- the meet (step 2, user 2026-11-17)
-- After the lifters land, the meet starts once every listed lifter is inside the hall, or this long after the first one
-- landed (Studio: StudioArriveSeconds). Lifters still outside then are walked in. [PROVISIONAL]
NationalsConfig.ArriveSeconds = 120
NationalsConfig.StudioArriveSeconds = 20
-- The fewest lifters there for the meet to run (fewer: everyone is told and sent back). Studio: 1. While not Live, the
-- admins' test Nationals: TestMeetMinimumLifters, the same as the gathering's TestMinimumLifters (2026-11-18: it was 2
-- here and 1 there, so a lone tester was sent to the Nationals server, walked in, was told "the Nationals meet couldn't
-- start (only 1 lifter could lift (2 needed))" and was teleported straight back; the user's phone test).
NationalsConfig.MeetMinimumLifters = 2
NationalsConfig.TestMeetMinimumLifters = 1
-- Each class's awards stay up this long (the classes go one after another). [PROVISIONAL]
NationalsConfig.AwardsClassSeconds = 14
-- After the awards, lifters are sent back to the game this long after the meet's end (live; Studio: out of the hall).
NationalsConfig.SendHomeSeconds = 45
-- A lift-off's lift choice: this long to pick (then their strongest lift).
NationalsConfig.LiftOffChooseSeconds = 15
-- The "flow state" behind the curtain: a 4 s loop, rocking slowly forward and back on planted feet, head bowed, a slow
-- breath, the hands shaken out loose halfway (Blender, art/scripts/nationals_flow_animation.py; anim_qa PASS on Skinny,
-- Fat, Muscular, BigBuff in the meet outfit). Empty: the lifter just stands there.
NationalsConfig.FlowAnimationId = "rbxassetid://89830873511612"
-- The hall model's attribute naming what the crowd chants now ("ForTheWin", "Squat", "Bench", "Deadlift"; nil = quiet).
NationalsConfig.ChantAttribute = "NationalsChant"

-- The opening announcer's welcome (user 2026-11-18, for the opening cinematic: "Welcome ladies and gentlemen, To central
-- nationals! where these lifters will be at a all or nothing battle competing for the Worlds invitation, This meet will
-- begin shortly!"): ElevenLabs, voice "David - Sports Arena Announcer", shouted with excitement to a packed arena, 10.8 s.
-- Two takes; A is used until the user picks (B: rbxassetid://107631807856915). Words checked locally.
NationalsConfig.WelcomeVoiceId = "rbxassetid://80969960609874"
NationalsConfig.WelcomeVoiceSeconds = 10.8
NationalsConfig.WelcomeLine = "Welcome, ladies and gentlemen, to Central Nationals! Where these lifters will be in an all or "
	.. "nothing battle, competing for the Worlds invitation! This meet will begin shortly!"

-- ---------------------------------------------------------------- the curtain and the camera (user 2026-11-18)
-- Hidden walls that stop the camera in the hall (the backdrops with their curtains, the hall's walls and roof), so it
-- never ends up behind a screen or outside the building (HallCameraGuard; MeetLiftMoment's shots too).
NationalsConfig.CameraBlockTag = "NationalsCameraBlock"
-- The lifter's curtain: the two panels beside each split (they swing apart as someone walks through, NationalsCurtains)
-- and the stage's light showing through the split.
NationalsConfig.CurtainFlapTag = "NationalsCurtainFlap"
NationalsConfig.CurtainGlowTag = "NationalsCurtainGlow"
-- Figures that aren't players but walk through the curtain too (the platforms' coaches); it parts for them as well.
NationalsConfig.CurtainWalkerTag = "NationalsCurtainWalker"
-- Parting the curtain: both hands come up together, push the two halves apart and hold them while stepping through,
-- then drop (arms, chest and head only, over the walk; art/scripts/nationals_flow_animation.py; anim_qa PASS on Skinny,
-- Fat, Muscular, BigBuff in the meet outfit). Empty: they just walk.
NationalsConfig.CurtainPartAnimationId = "rbxassetid://77278447505588"
-- After the click, how long they stand reaching into the split before the walk starts (the hands meet the cloth first).
NationalsConfig.CurtainPartLeadSeconds = 0.3
-- How the curtain swings (NationalsCurtains): the most each half turns aside (bottom outward) and forward (the way they
-- walk), in degrees; how near (studs, across the curtain) a body opens it, nearer with the parting hands out; how fast it
-- follows (share a second).
NationalsConfig.Curtain = {
	SwingDegrees = 5.5,
	TiltDegrees = 3.5,
	OpenFrom = 1.1,
	-- (first test: from 2.3 the hands were already in the cloth before it moved)
	OpenFromReaching = 3,
	SideReach = 2.4,
	FollowRate = 12,
	SettleRate = 3.2,
}
-- The cinematic behind the curtain, on the waiting lifter's own screen (NationalsCurtainScene): its shots in turn, each
-- this long; then on the click (or the time running out), the reveal from the stage side for RevealSeconds.
NationalsConfig.CurtainScene = {
	ShotSeconds = 4.2,
	RevealSeconds = 2.2,
	FieldOfView = 42,
}

--[[
	THE LIFT-OFF'S JUDGE (user 2026-11-18: "both lifters ... are put in a cinematic where the judge walks through the
	curtain, to tell both lifters together that they must lift off"). The server walks the platform's head referee
	(NationalsScenes); each tied lifter's screen runs the shots (NationalsLiftOffScene). Seconds, and studs.
]]
NationalsConfig.LiftOffScene = {
	-- From the server sending it to its first moment (the screens get ready).
	LeadSeconds = 0.8,
	-- The first shot, on the tied lifters on their bench, before the judge sets off; within it the judge gets up off
	-- the chair.
	TieSeconds = 3.2,
	StandUpAt = 0.6,
	StandUpSeconds = 0.9,
	-- The camera goes to the lifters' zone this long before the judge reaches the curtain, to see it part.
	ThroughLeadSeconds = 0.9,
	-- Through the curtain, the judge stops and looks over at the lifters on their bench this long before they get up;
	-- then turns with them as they walk over (share of the way round a second); once they stand there, this pause
	-- before the first word.
	LookSeconds = 1.6,
	TurnRate = 4,
	GatherPauseSeconds = 0.6,
	-- What the judge says, shown in the bottom bar and spoken (user 2026-11-18: "tell elevenlabs to generate the same
	-- voice for the text": ElevenLabs eleven_v4, the announcer's own voice "David - Sports Arena Announcer", who IS the
	-- head judge, firm and close over the hall's noise). The same words on screen and aloud, so no class, total or
	-- name in them (those are in the caption): one first line per place, then the rules. `seconds`: the recording's
	-- length; a line with no recording (voiceId "") stays up LineSeconds.
	FirstLines = {
		{ text = "You finished dead level on total. First place goes to a lift-off.",
			voiceId = "rbxassetid://109357897168685", seconds = 5.09 },
		{ text = "You finished dead level on total. Second place goes to a lift-off.",
			voiceId = "rbxassetid://87394996343198", seconds = 5.13 },
		{ text = "You finished dead level on total. Third place goes to a lift-off.",
			voiceId = "rbxassetid://127909988397691", seconds = 5.02 },
	},
	SecondLine = { text = "One lift each, your choice: your best plus two and a half kilos. Miss while another makes it, "
		.. "and you are out.", voiceId = "rbxassetid://136963528084285", seconds = 7.57 },
	-- (The recordings: D:\Powerlifting Roblox Extras\Sounds\Announcer\LiftOffJudge_First / _Second / _Third /
	-- _Rules.wav, one take each, uploaded 2026-11-18 on the user's "Yes, upload all"; art/sounds/elevenlabs_shouts.json.)
	VoiceVolume = 1,
	-- A spoken line stays up this long after its last word; a line with no recording stays up LineSeconds. This pause
	-- between lines.
	AfterVoiceSeconds = 0.6,
	LineSeconds = 5,
	LinePauseSeconds = 0.4,
	-- Where the tied lifters come to stand, from the spot behind the curtain's split: this far further back, side by
	-- side and SHOULDER TO SHOULDER (user 2026-11-18: "make sure they are shoulder to shoulder not inside each other";
	-- they stood 3.4 apart whatever their size): each takes their own body's width (BodyWidths) with ShoulderGapStuds of
	-- air to the next. The line's middle sits OuterShiftStuds toward the stage's outer side (clear of the chalk stand),
	-- and further out when the line is long, so its inner end never comes nearer the chalk stand's side than
	-- InnerLimitStuds from the split. The judge stops JudgeAheadStuds in front of the middle.
	-- (LiftersBehindStuds puts the line ON THE LANE the lifters walk along their bench row, NationalsArenaVenue
	-- SEAT_LANE: they come along it one behind another and stop on their spots, never sideways through anybody. It was
	-- 4.2: a wide lifter walking in along that line brushed the chalk stand.)
	LiftersBehindStuds = 5.3,
	OuterShiftStuds = 1.8,
	InnerLimitStuds = 6,
	ShoulderGapStuds = 0.3,
	-- They get up one after another, this long apart, the one nearest the curtain first (user 2026-11-18: "make sure
	-- there is a separation between the walk"): two wide lifters sitting side by side never turn at the same moment.
	-- The same on the way back to the bench.
	GatherStaggerSeconds = 0.6,
	JudgeAheadStuds = 4.4,
	-- How wide each body build is, hand to hand with the arms hanging (studs; measured in Studio 2026-11-18 on a player's
	-- body in the tee and shorts, NationalsScenes.bodyWidth). A body with no known build counts as the widest; anything
	-- worn that sticks out further (a wide hat, wings) widens it, up to MaxBodyWidthStuds.
	BodyWidths = { Skinny = 2.74, SkinnyFat = 2.94, Fat = 3.69, Fit = 3.36, Muscular = 3.97, BigBuff = 4.31 } :: { [string]: number },
	WidestBodyStuds = 4.31,
	MaxBodyWidthStuds = 7,
	FieldOfView = 42,
}

--[[
	THE OPENING (user 2026-11-18: "when they enter the meet area ... a cinematic flying camera, of the venue. Then it pans
	to the announcer (a judge), talking to the crowd under a spotlight ... he walks back to his seat, Then the camera goes
	back to the lifter", whose coach tells them who they are up against). The server moves the figures and plays the voice
	(NationalsScenes); each lifter's screen runs the shots (NationalsOpeningScene). Seconds.
]]
NationalsConfig.Opening = {
	-- Before it starts, every lifter's screen must have the hall: a place only just walked into arrives piece by piece
	-- and shows its lights late (in Studio the lit platforms came 10 to 25 s after walking in), and the tour would fly
	-- through a black hall. Each screen says when the hall has stopped arriving (nothing new for HallQuietSeconds); the
	-- opening starts LightsSeconds after the last one, or anyway after ReadyWaitSeconds. Lifters who walked in early
	-- wait for nothing.
	HallQuietSeconds = 2.5,
	LightsSeconds = 8,
	ReadyWaitSeconds = 35,
	-- From the server sending it to the tour's first moment. The screen is BLACK with the title on it meanwhile, the
	-- camera already waiting at the tour's start with its Focus on the platforms (NationalsOpeningScene.step): after the
	-- trip into the hall the engine works out the light near the camera's Focus first, and this is the time it gets for
	-- the far platforms (Studio 2026-11-18: without the Focus the tour's first 5 s were unlit in 3 runs of 5; with it,
	-- lit as the title fades). The title then fades out over TitleFadeSeconds as the tour starts.
	LeadSeconds = 4.2,
	TitleFadeSeconds = 1.1,
	-- The camera tour of the hall, ending in front of the announcer as they start to speak.
	TourSeconds = 10,
	-- The spotlight comes on this long before the first word, this bright.
	SpotLeadSeconds = 1.4,
	SpotBrightness = 14,
	VoiceVolume = 1,
	-- What the announcer says, in the bottom bar, in step with the recording (WelcomeVoiceId; seconds into it, from a
	-- word-by-word reading of take A): { from, to, words }.
	VoiceLines = {
		{ from = 0.0, to = 3.4, text = "Welcome, ladies and gentlemen, to Central Nationals!" },
		{ from = 3.6, to = 8.6, text = "Where these lifters will be in an all or nothing battle, competing for the Worlds "
			.. "invitation!" },
		{ from = 8.8, to = 10.9, text = "This meet will begin shortly!" },
	},
	-- The crowd answers: seconds into the recording (after "Central Nationals!" and at the end).
	CheerAt = { 3.1, 10.3 },
	-- The shots on the announcer cut at these seconds into the recording (front, over the shoulder to the stands, close).
	AnnounceCuts = { 3.7, 8.7 },
	-- After the last word the announcer walks back to the chair; the screens watch that this long, then go to the lifter.
	AfterVoiceSeconds = 0.5,
	BackSeconds = 3.4,
	-- The coach's words, then the film look ends. A lifter with rivals: the first line (them, highlighted), the second.
	CoachSeconds = 9.4,
	CoachLineAt = 0.5,
	CoachFirstSeconds = 3.4,
	CoachSecondSeconds = 4.8,
	-- (the user's words, 2026-11-18)
	CoachAlone = "Alright, no one is competing in your weight class today, so you will be judged based off points.",
	CoachRivals = { "Alright, there is your competition.",
		"We are going to play it smart, win this meet and get you your invitation." },
	-- (Claude's, for a meet placed on points where this lifter's class still has others in it)
	CoachPoints = { "Alright, some classes are short today, so everyone here is judged on points. There is your competition.",
		"We are going to play it smart, win this meet and get you your invitation." },
	-- The announcer's move while speaking: the microphone up in the right hand, the open left arm doing the talking in step
	-- with the words (art/scripts/nationals_announce_animation.py, art/animations/Nationals_Announce.rbxmx; anim_qa PASS
	-- on Skinny, Fat and Muscular; previewed in Studio from the file with a stand-in microphone). It starts
	-- AnnounceLeadSeconds before the first word, so the microphone is up for it. Empty: they just stand there.
	-- Uploaded 2026-11-18 (the user's "Yes, upload all").
	AnnounceAnimationId = "rbxassetid://81351484139860",
	AnnounceLeadSeconds = 0.7,
	FieldOfView = 46,
}

return NationalsConfig
