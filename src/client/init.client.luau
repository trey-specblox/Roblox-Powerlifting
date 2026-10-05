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

--[[
	TEMPORARY. There is no rack, barbell or attempt-selection UI yet, so a complete
	lift is started from the keyboard. Deleting the Dev folder and these two lines
	removes all test-only behaviour.
]]
local DevFolder = script:WaitForChild("Dev")
local LiftAttemptDebugTrigger = require(DevFolder:WaitForChild("LiftAttemptDebugTrigger"))
LiftAttemptDebugTrigger.start()
