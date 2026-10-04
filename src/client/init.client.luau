--!strict
--[[
	Client entry point
	StarterPlayerScripts.Client

	Starts client systems. Keep this file thin: it wires systems up and nothing
	else.
]]

local LiftingFolder = script:WaitForChild("Lifting")
local SquatDepthController = require(LiftingFolder:WaitForChild("SquatDepthController"))
local SquatControlController = require(LiftingFolder:WaitForChild("SquatControlController"))

-- Both phases are driven by temporary debug triggers on separate keys and are not
-- yet chained into one squat attempt.
SquatDepthController.start()
SquatControlController.start()
