--!strict
--[[
	MenuKeys
	Client / UI

	Whether a menu's hot key (MEETS M, STATS C, TELEPORT T, GEAR Y, EMOTES B) may open it right
	now. Not while the player types in a box, never during a lift attempt (user 2026-11-01: the
	deadlift's typing pull uses letters, and a menu popping open hid the lockout), and never on
	the lifter's turn at a meet.

	THE TURN (user 2026-11-18: "when someone is walking to the platform to lift, make sure the
	UI's disappear like the gear, teleport etc. and make sure keyboard players cant press a short
	cut-key to pop it up"): MeetLiftMoment calls setOnTurn(true) as the lifter walks out to the
	platform and setOnTurn(false) when the walk back is over. Meanwhile the side menus
	(HIDDEN_ON_TURN: their tabs and any panel open) are switched off and their keys do nothing.
	Anything that switches one back on meanwhile (the film look ending, MeetCinema) is held off
	and gets its way when the turn is over. The meet's own screen (scorecard, the turn's card)
	stays.

	LIFTING (user 2026-11-24, a phone: the luck chip "stays popped up during lifts"; "when someone is trying to lift
	the uis disappear"): the same screens go, plus the boost and luck chips and the quest tracker, during ANY lift
	attempt (the gym's lifts and practice too, LiftAttemptController.isAttemptActive), and come back as they were.

	Display only.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LiftAttemptController = require(script.Parent.Parent:WaitForChild("Lifting"):WaitForChild("LiftAttemptController"))

local MenuKeys = {}

-- The side menus' screens (their ScreenGui names): ADMIN, MEETS, COINS, STATS, TELEPORT, GEAR, EMOTES, and the shop.
-- Also the boost and luck chips (BoostBar, "Boosts"), the cow's luck screen ("Luck") and the quest tracker.
local HIDDEN_ON_TURN = { "AdminPanel", "MeetsTab", "Coins", "Stats", "Teleport", "Gear", "EmoteWheel", "Shop", "Ranks",
	"Boosts", "Luck", "QuestTracker" }

local onTurn = false
-- Whether a lift attempt was running at the last check, and whether the screens are hidden now (on the turn OR lifting).
local lifting = false
local hidden = false
-- While on the turn: each hidden screen, whether it should be on once the turn is over.
local wanted: { [ScreenGui]: boolean } = {}
local watchers: { RBXScriptConnection } = {}

function MenuKeys.allowed(gameProcessed: boolean): boolean
	return not gameProcessed and UserInputService:GetFocusedTextBox() == nil
		and not LiftAttemptController.isAttemptActive() and not onTurn
end

-- Whether the lifter is on their turn at a meet (the side menus are hidden).
function MenuKeys.isOnTurn(): boolean
	return onTurn
end

-- Hides the screens (`on`) or brings them back as they were.
local function setHidden(on: boolean)
	if on == hidden then
		return
	end
	hidden = on
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if on then
		if playerGui == nil then
			return
		end
		for _, name in ipairs(HIDDEN_ON_TURN) do
			local gui = playerGui:FindFirstChild(name)
			if gui and gui:IsA("ScreenGui") then
				wanted[gui] = gui.Enabled
				gui.Enabled = false
				table.insert(watchers, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
					if hidden and gui.Enabled then
						wanted[gui] = true
						gui.Enabled = false
					end
				end))
			end
		end
	else
		for _, connection in ipairs(watchers) do
			connection:Disconnect()
		end
		table.clear(watchers)
		for gui, enabled in pairs(wanted) do
			if gui.Parent then
				gui.Enabled = enabled
			end
		end
		table.clear(wanted)
	end
end

-- The lifter's turn at a meet starts (`on`) or is over: the side menus go, or come back as they were.
function MenuKeys.setOnTurn(on: boolean)
	if on == onTurn then
		return
	end
	onTurn = on
	setHidden(onTurn or lifting)
end

-- Every lift attempt hides them too (checked a few times a second: cheap, one boolean).
if RunService:IsClient() then
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < 0.1 then
			return
		end
		since = 0
		local now = LiftAttemptController.isAttemptActive()
		if now ~= lifting then
			lifting = now
			setHidden(onTurn or lifting)
		end
	end)
end

return MenuKeys
