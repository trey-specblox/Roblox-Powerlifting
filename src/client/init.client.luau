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

-- The Mock Meet: the title and Leave button while you are in your private meet room.
local MeetFolder = script:WaitForChild("Meet")
local MockMeetController = require(MeetFolder:WaitForChild("MockMeetController"))
MockMeetController.start()

-- The Local meet: the venue screen (countdown, sign-up, standings) and the lifter's meet screen.
local LocalMeetController = require(MeetFolder:WaitForChild("LocalMeetController"))
task.spawn(LocalMeetController.start)

-- A gym record set at an official meet, for everyone in the server (GAME_DESIGN §31.6).
local GymRecordAnnouncer = require(MeetFolder:WaitForChild("GymRecordAnnouncer"))
task.spawn(GymRecordAnnouncer.start)

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
