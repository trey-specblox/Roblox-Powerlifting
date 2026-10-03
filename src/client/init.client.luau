--!strict
--[[
	Client entry point
	StarterPlayerScripts.Client

	Starts client systems. Keep this file thin: it wires systems up and nothing
	else.
]]

local LiftingFolder = script:WaitForChild("Lifting")
local SquatDepthController = require(LiftingFolder:WaitForChild("SquatDepthController"))

SquatDepthController.start()
