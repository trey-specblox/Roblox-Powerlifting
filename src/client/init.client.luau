--!strict
--[[
	Client entry point
	StarterPlayerScripts.Client

	Starts client systems. Keep this file thin: it wires systems up and nothing
	else.
]]

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
