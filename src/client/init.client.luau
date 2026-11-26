--!strict
--[[
	Client entry point
	StarterPlayerScripts.Client

	Starts client systems. Keep this file thin: it wires systems up and nothing
	else.
]]

-- Every "hold E" prompt in the game, drawn in the game's one look. Drawing only.
local UIFolder = script:WaitForChild("UI")
local PromptController = require(UIFolder:WaitForChild("PromptController"))
PromptController.start()

-- The PLAYER STATS screen: press C or the STATS tab. It only shows the server's read-only snapshot.
local StatsScreen = require(UIFolder:WaitForChild("StatsScreen"))
task.spawn(StatsScreen.start)

-- The TELEPORT menu: press T or the TELEPORT tab. It only asks; the server checks and moves the player.
local TeleportMenu = require(UIFolder:WaitForChild("TeleportMenu"))
task.spawn(TeleportMenu.start)

-- The player's coins: the counter above STATS and the "+150 COINS" pop-ups. Display only.
local CoinCounter = require(UIFolder:WaitForChild("CoinCounter"))
task.spawn(CoinCounter.start)
local GainDisplay = require(UIFolder:WaitForChild("GainDisplay"))
task.spawn(GainDisplay.start)
local BoostBar = require(UIFolder:WaitForChild("BoostBar"))
task.spawn(BoostBar.start)
local KitchenMenu = require(UIFolder:WaitForChild("KitchenMenu"))
task.spawn(KitchenMenu.start)
-- The mafia boss cow's wheel of luck and his games (W Chews' back room).
local LuckMenu = require(UIFolder:WaitForChild("LuckMenu"))
task.spawn(LuckMenu.start)
local QuestTracker = require(UIFolder:WaitForChild("QuestTracker"))
task.spawn(QuestTracker.start)
local CoachDialogue = require(UIFolder:WaitForChild("CoachDialogue"))
task.spawn(CoachDialogue.start)

-- The Shop's menu (hold E at the Shop's counter). It only asks; the server checks every purchase.
local ShopMenu = require(UIFolder:WaitForChild("ShopMenu"))
task.spawn(ShopMenu.start)
-- The celebration spin screen (hold E on the NPC in the dumbbell corner). It only asks; the server rolls and takes the coins.
local CelebrationSpinner = require(UIFolder:WaitForChild("CelebrationSpinner"))
task.spawn(CelebrationSpinner.start)
-- The emote wheel (B, or the EMOTES tab): it only asks; the server plays the emote.
local EmoteWheel = require(UIFolder:WaitForChild("EmoteWheel"))
task.spawn(EmoteWheel.start)
-- Ranks and titles (GAME_DESIGN §41): the rank-up moments (after the awards), the RANKS menu (R) and the small name
-- tags over other players.
local RankMoment = require(UIFolder:WaitForChild("RankMoment"))
local LocalMeetAwardsForRanks = require(script:WaitForChild("Meet"):WaitForChild("LocalMeetAwards"))
RankMoment.addBlocker(LocalMeetAwardsForRanks.isPlaying)
task.spawn(RankMoment.start)
task.spawn(require(UIFolder:WaitForChild("RanksMenu")).start)
task.spawn(require(UIFolder:WaitForChild("RankNameTags")).start)

-- MY GEAR (the GEAR tab): put on and take off owned gear. It only asks; the server checks and dresses.
-- THE INVENTORY (GAME_DESIGN §42, user 2026-11-24): replaces MY GEAR (GearMenu, retired, no longer started): gear,
-- clothes, food from the chef, medals and trophies, in one screen on the same tab and key.
local InventoryMenu = require(UIFolder:WaitForChild("InventoryMenu"))
task.spawn(InventoryMenu.start)
-- Held items (GAME_DESIGN §42) are Roblox Tools in the hand; the INVENTORY is the item screen, so Roblox's own backpack bar
-- stays hidden. The floating win counter over held medals and trophies:
pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)
task.spawn(require(UIFolder:WaitForChild("HeldCounters")).start)
-- Food is carried in both hands: each screen fits the plate onto the carrier's palms.
task.spawn(require(script:WaitForChild("World"):WaitForChild("HeldPlates")).start)

local LiftingFolder = script:WaitForChild("Lifting")
local LiftAttemptController = require(LiftingFolder:WaitForChild("LiftAttemptController"))

-- The single client owner of a lift attempt. It shows whichever phase the server
-- presents and reports raw inputs; it decides nothing.
LiftAttemptController.start()

-- The training rack menu. The server opens it when the player holds E at a rack;
-- it only sends requests and shows what the server says.
local TrainingFolder = script:WaitForChild("Training")
local TrainingMenuController = require(TrainingFolder:WaitForChild("TrainingMenuController"))
TrainingMenuController.start()

-- Station rep animations and the bar following the lifter's hands. Visual only.
local StationPoseAnimator = require(TrainingFolder:WaitForChild("StationPoseAnimator"))
StationPoseAnimator.start()

-- The automatic sliding doors at the gym's entrance open for anyone near them. Visual only.
local WorldFolder = script:WaitForChild("World")
local KitchenClocks = require(WorldFolder:WaitForChild("KitchenClocks"))
task.spawn(KitchenClocks.start)
local KitchenWelcome = require(WorldFolder:WaitForChild("KitchenWelcome"))
task.spawn(KitchenWelcome.start)
local KitchenSignTimer = require(WorldFolder:WaitForChild("KitchenSignTimer"))
task.spawn(KitchenSignTimer.start)
local KitchenBackDoor = require(WorldFolder:WaitForChild("KitchenBackDoor"))
task.spawn(KitchenBackDoor.start)
local AutoDoorAnimator = require(WorldFolder:WaitForChild("AutoDoorAnimator"))
AutoDoorAnimator.start()

-- The wall mirrors show the room and the players in them. Visual only.
local MirrorController = require(WorldFolder:WaitForChild("MirrorController"))
MirrorController.start()

-- Riders on the Cardio room's machines run, cycle, row and ski; Jump hops you off. Visual only.
local CardioMachineAnimator = require(WorldFolder:WaitForChild("CardioMachineAnimator"))
CardioMachineAnimator.start()

-- The treadmill rhythm game: your lanes, the wall TV and the beat; it only sends lane presses.
local CardioRhythmController = require(WorldFolder:WaitForChild("CardioRhythmController"))
CardioRhythmController.start()

-- While the game holds you in place (meets, Mock Meets, practice), you stand instead of hanging in a fall. Visual only.
require(WorldFolder:WaitForChild("LockedStance")).start()

-- The Mock Meet: the title and Leave button while you are in your private meet room.
local MeetFolder = script:WaitForChild("Meet")
local MockMeetController = require(MeetFolder:WaitForChild("MockMeetController"))
MockMeetController.start()

-- The Local meet: the venue screen (countdown, sign-up, standings) and the lifter's meet screen.
local LocalMeetController = require(MeetFolder:WaitForChild("LocalMeetController"))
task.spawn(LocalMeetController.start)
-- Your chosen coach at your meets, on your screen only (GAME_DESIGN §40.5).
task.spawn(require(MeetFolder:WaitForChild("MeetCoachLook")).start)
-- The coaches' voices: your coach says his lines out loud, on your screen only (GAME_DESIGN §40.5).
task.spawn(require(MeetFolder:WaitForChild("CoachVoice")).start)
-- The end-of-meet coach scene's camera, subtitle and SKIP, on your screen only (GAME_DESIGN §40.5).
task.spawn(require(MeetFolder:WaitForChild("MeetEndScene")).start)

-- The meet's spotters follow the bar and the lifter (GAME_DESIGN §37.5). Visual only.
local MeetSpotterAnimator = require(MeetFolder:WaitForChild("MeetSpotterAnimator"))
MeetSpotterAnimator.start()

-- The dark State arena with its racks spotlit, while a State meet runs and you are inside. Visual only.
local StateArenaLights = require(MeetFolder:WaitForChild("StateArenaLights"))
StateArenaLights.start()
-- The Nationals hall as a dark room, while you are inside it (GAME_DESIGN §39). Visual only.
local NationalsHallLights = require(MeetFolder:WaitForChild("NationalsHallLights"))
NationalsHallLights.start()
-- The Nationals meet on the lifter's own screen: the click to step out from behind the curtain, a lift-off's pick.
local NationalsMeetUI = require(MeetFolder:WaitForChild("NationalsMeetUI"))
task.spawn(NationalsMeetUI.start)
-- The cinematic behind the Nationals curtain and the reveal as they push through it, on their own screen. Display only.
local NationalsCurtainScene = require(MeetFolder:WaitForChild("NationalsCurtainScene"))
task.spawn(NationalsCurtainScene.start)
-- The lift-off's judge walking through the curtain to the tied lifters, as a cinematic on their own screens. Display only.
local NationalsLiftOffScene = require(MeetFolder:WaitForChild("NationalsLiftOffScene"))
task.spawn(NationalsLiftOffScene.start)
-- The Nationals opening: the camera tour, the announcer's welcome and the coach's words, on each lifter's screen. Display only.
local NationalsOpeningScene = require(MeetFolder:WaitForChild("NationalsOpeningScene"))
task.spawn(NationalsOpeningScene.start)
-- The Nationals curtains swinging apart as lifters walk through them, on every screen. Visual only.
local NationalsCurtains = require(MeetFolder:WaitForChild("NationalsCurtains"))
NationalsCurtains.start()
-- In the Nationals hall the camera stays this side of the backdrops and inside the building. Display only.
local HallCameraGuard = require(MeetFolder:WaitForChild("HallCameraGuard"))
HallCameraGuard.start()
-- The State arena crowd's stomp-clap chant, on third attempts from chalking up to the lift's result. Sound only.
local MeetChant = require(MeetFolder:WaitForChild("MeetChant"))
MeetChant.start()
-- The Nationals hall crowd's chant, building while a lifter waits behind the curtain, until the lift's result. Sound only.
local NationalsChant = require(MeetFolder:WaitForChild("NationalsChant"))
NationalsChant.start()

-- The celebrations' effects for everyone near, and a Legendary one's cinematic on the celebrating player's own screen
-- (GAME_DESIGN §36.4).
local CelebrationFx = require(MeetFolder:WaitForChild("CelebrationFx"))
task.spawn(CelebrationFx.start)

-- Hand-shape swaps on the cartoon bodies during celebrations and emotes (GAME_DESIGN §38.7). Visual only.
local HandShapeAnimator = require(MeetFolder:WaitForChild("HandShapeAnimator"))
HandShapeAnimator.start()

-- Every meet animation downloaded in the background, so none is still loading the first time it plays (a gap there
-- showed the idle pose mid-lift). Visual only.
local MeetAnimationPreload = require(MeetFolder:WaitForChild("MeetAnimationPreload"))
MeetAnimationPreload.start()

-- The meet's walks (walk-outs, walks back, coaches), drawn smoothly every frame from what the server sends. Visual only.
local MeetWalkView = require(MeetFolder:WaitForChild("MeetWalkView"))
MeetWalkView.start()

-- The meet's sounds: referee claps, the bar, the lights and the crowd (GAME_DESIGN §37.5).
local MeetSoundController = require(MeetFolder:WaitForChild("MeetSoundController"))
task.spawn(MeetSoundController.start)

-- The bar's sound in each gym training rep, on the animation. Audio only.
local StationRepSounds = require(TrainingFolder:WaitForChild("StationRepSounds"))
StationRepSounds.start()

-- A gym record set at an official meet, for everyone in the server (GAME_DESIGN §31.6).
local GymRecordAnnouncer = require(MeetFolder:WaitForChild("GymRecordAnnouncer"))
task.spawn(GymRecordAnnouncer.start)

-- The coach's cutscene when a player wins a rare suit (GAME_DESIGN §35.12). Display only.
local SuitCutscene = require(MeetFolder:WaitForChild("SuitCutscene"))
task.spawn(SuitCutscene.start)

-- The State meet's caller, out loud (GAME_DESIGN §36.4). Display only.
local MeetCallerVoice = require(MeetFolder:WaitForChild("MeetCallerVoice"))
task.spawn(MeetCallerVoice.start)
local MeetLiveScreen = require(MeetFolder:WaitForChild("MeetLiveScreen"))
task.spawn(MeetLiveScreen.start)
-- Cheering at the big meets (GAME_DESIGN §36.4): the bar in a watching zone, and the microphone meter. Display only.
local MeetCheerBar = require(MeetFolder:WaitForChild("MeetCheerBar"))
task.spawn(MeetCheerBar.start)

-- The admin panel, only on an admin's screen: the server says who is one and checks every press.
local AdminPanel = require(script:WaitForChild("UI"):WaitForChild("AdminPanel"))
task.spawn(AdminPanel.start)

--[[
	TEMPORARY. There is no rack, barbell or attempt-selection UI yet, so a complete
	lift is started from the keyboard. Deleting the Dev folder and these two lines
	removes all test-only behaviour.
]]
local DevFolder = script:WaitForChild("Dev")
local LiftAttemptDebugTrigger = require(DevFolder:WaitForChild("LiftAttemptDebugTrigger"))
LiftAttemptDebugTrigger.start()

-- TEMPORARY (6D.2a). Studio only, and only while the server's GymRackWatchProbe is ENABLED:
-- shows its PASS/FAIL results on screen. Display only; it sends nothing to the server.
local GymRackWatchDisplay = require(DevFolder:WaitForChild("GymRackWatchDisplay"))
GymRackWatchDisplay.start()
