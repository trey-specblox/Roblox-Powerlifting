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

-- ------------------------------------------------ the stand-in venue (the State arena re-dressed)

-- Workspace attribute set in a Nationals server (and in Studio while its stand-in runs): the Nationals' start time.
NationalsConfig.ServerAttribute = "NationalsServer"
-- Player attribute while a lifter is at Nationals: the class their spot is in ("74 kg").
NationalsConfig.AtNationalsAttribute = "AtNationals"
-- On the arena's signs.
NationalsConfig.EventTitle = "NATIONALS"
NationalsConfig.EventSub = "NATIONAL CHAMPIONSHIP"

-- The NATIONALS desk in the State arena's lobby, left of the State desk (arena frame), and its prompt.
NationalsConfig.DeskAt = Vector3.new(-42, 0, -40)
NationalsConfig.PromptHoldSeconds = 0.5
NationalsConfig.PromptDistanceStuds = 8

-- A press of SIGN UP / LEAVE, at most this often per player.
NationalsConfig.ButtonCooldownSeconds = 0.75

-- The prize pot multiplier shown on the list (§39: 5x the Local pot). Paid in step 2.
NationalsConfig.PotMultiplier = 5

return NationalsConfig
