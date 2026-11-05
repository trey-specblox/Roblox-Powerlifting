--!strict
--[[
	MenuKeys
	Client / UI

	Whether a menu's hot key (STATS C, TELEPORT T, GEAR Y) may open it right
	now. Not while the player types in a box, and never during a lift attempt
	(user 2026-11-01: the deadlift's typing pull uses letters, and a menu
	popping open hid the lockout).
]]

local UserInputService = game:GetService("UserInputService")

local LiftAttemptController = require(script.Parent.Parent:WaitForChild("Lifting"):WaitForChild("LiftAttemptController"))

local MenuKeys = {}

function MenuKeys.allowed(gameProcessed: boolean): boolean
	return not gameProcessed and UserInputService:GetFocusedTextBox() == nil
		and not LiftAttemptController.isAttemptActive()
end

return MenuKeys
