--!strict
--[[
	NationalsMeetUI
	Client / Meet

	The lifter's own screen at the Nationals meet (GAME_DESIGN §39, user 2026-11-17), two small things only (no screen
	clutter):
	- BEHIND THE CURTAIN: while they wait right behind their platform's curtain (the server's "Waiting" state carries
	  `curtain`), a small line at the bottom, "CLICK ANYWHERE TO STEP ONTO THE PLATFORM", and a click or tap anywhere sends
	  READY. The server walks them out then (or anyway when its wait runs out).
	- A LIFT-OFF (a tie for a medal place): three buttons, one per lift with its weight (their best + 2.5 kg), until they
	  pick or the time runs out (the server then picks their strongest).
	A client only asks: the server checks every press.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LocalMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("LocalMeetRemotes"))
local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours

local NationalsMeetUI = {}

local CURTAIN_TEXT = "CLICK ANYWHERE TO STEP ONTO THE PLATFORM"
local CURTAIN_TEXT_TOUCH = "TAP ANYWHERE TO STEP ONTO THE PLATFORM"

local started = false

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d", kg) else string.format("%.1f", kg)
end

function NationalsMeetUI.start()
	if started then
		return
	end
	started = true
	local remotes = LocalMeetRemotes.waitForClient(ReplicatedStorage)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "NationalsMeetUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Behind the curtain: the whole screen is the button, with one small line on it.
	local curtain = Instance.new("TextButton")
	curtain.Name = "Curtain"
	curtain.BackgroundTransparency = 1
	curtain.Text = ""
	curtain.Size = UDim2.fromScale(1, 1)
	curtain.Visible = false
	curtain.ZIndex = 1
	curtain.Parent = gui
	-- (Above the meet panel at the bottom, which keeps showing the declared weight.)
	local line = UIStyle.label(curtain, "Line", UDim2.new(0.5, 0, 0.6, 0), UDim2.fromOffset(560, 30), C.white,
		UIStyle.heading(), Enum.TextXAlignment.Center)
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Size = UDim2.new(0.9, 0, 0, 30)
	local lineConstraint = Instance.new("UISizeConstraint")
	lineConstraint.MaxSize = Vector2.new(620, 30)
	lineConstraint.Parent = line
	local lineStroke = Instance.new("UIStroke")
	lineStroke.Color = C.ink
	lineStroke.Thickness = 2
	lineStroke.Parent = line
	local curtainOn = false
	local function stepOut()
		if curtainOn then
			curtainOn = false
			curtain.Visible = false
			remotes.ready:FireServer()
		end
	end
	curtain.Activated:Connect(stepOut)
	-- (A click on another screen's button still counts: anywhere on the screen.)
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if curtainOn and (input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA) then
			stepOut()
		end
	end)
	-- A slow pulse, so it reads as waiting on them.
	RunService.RenderStepped:Connect(function()
		if curtainOn then
			line.TextTransparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(os.clock() * 3))
		end
	end)

	-- The lift-off's pick.
	local panel, body = UIStyle.panel(gui, "LiftOff", UDim2.new(0.5, -210, 0.5, -110), UDim2.fromOffset(420, 220))
	panel.Visible = false
	UIStyle.titleTag(panel, "Tag", "LIFT-OFF", UDim2.fromOffset(-10, -22), UDim2.fromOffset(220, 38), C.yellow, "star")
	local info = UIStyle.text(body, "Info", UDim2.fromOffset(18, 24), UDim2.new(1, -36, 0, 40), UIStyle.TextSizes.small,
		C.white)
	local buttons: { TextButton } = {}
	local choosing = false
	local pickToken = 0
	local function hidePanel()
		choosing = false
		panel.Visible = false
		for _, button in ipairs(buttons) do
			button:Destroy()
		end
		table.clear(buttons)
	end

	remotes.state.OnClientEvent:Connect(function(state: any)
		if typeof(state) ~= "table" then
			return
		end
		local wait = state.curtain
		if state.phase == "Waiting" and typeof(wait) == "table" then
			curtainOn = true
			line.Text = if UIStyle.isTouchOnly() then CURTAIN_TEXT_TOUCH else CURTAIN_TEXT
			curtain.Visible = true
		elseif curtainOn then
			curtainOn = false
			curtain.Visible = false
		end
		local liftOff = state.liftOff
		if state.phase == "Waiting" and typeof(liftOff) == "table" and typeof(liftOff.options) == "table" then
			hidePanel()
			choosing = true
			local place = if typeof(liftOff.place) == "number" then liftOff.place else 1
			info.Text = string.format("Tied for %s place in %s. Pick your lift: your best + 2.5 kg. Miss while the other "
				.. "makes it and you're out.", if place == 1 then "1st" elseif place == 2 then "2nd" else "3rd",
				tostring(liftOff.classLabel or "your class"))
			for index, option in ipairs(liftOff.options) do
				if typeof(option) == "table" and typeof(option.lift) == "string" and typeof(option.weightKg) == "number" then
					local lift = option.lift :: string
					local button = UIStyle.button(body, "Pick_" .. lift, string.format("%s  %s KG", string.upper(lift),
						kgText(option.weightKg)), UDim2.fromOffset(18, 70 + (index - 1) * 42), UDim2.new(1, -36, 0, 36),
						if index == 1 then "primary" else "outline", function()
							if choosing then
								remotes.liftOffChoose:FireServer(lift)
								hidePanel()
							end
						end)
					table.insert(buttons, button)
				end
			end
			panel.Visible = true
			-- (The server picks for them when its time is up; the panel goes then too.)
			local seconds = if typeof(liftOff.secondsLeft) == "number" then liftOff.secondsLeft else 15
			pickToken += 1
			local token = pickToken
			task.delay(seconds + 0.5, function()
				if pickToken == token and choosing then
					hidePanel()
				end
			end)
		elseif choosing then
			hidePanel()
		end
	end)
end

return NationalsMeetUI
