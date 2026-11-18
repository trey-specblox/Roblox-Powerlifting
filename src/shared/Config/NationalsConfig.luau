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
-- The fewest lifters there for the meet to run (fewer: everyone is told and sent back). Studio: 1.
NationalsConfig.MeetMinimumLifters = 2
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

return NationalsConfig
