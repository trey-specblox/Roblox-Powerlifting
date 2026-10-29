--!strict
--[[
	MockMeetController
	Client / Meet

	The Mock Meet on the player's screen (GAME_DESIGN.md §29.10). While the
	server has the player in their private meet room (the player attribute
	MockMeetConfig.SlotAttribute) it shows MockMeetUI and draws the server's
	meet state (MockMeetRemotes.STATE).

	It only ASKS: Leave, the chosen attempt weight (typed, or nudged with the
	buttons; Enter or CONFIRM) and LIFT go to the server, which checks and
	decides everything. The weight box explains what the server would refuse
	(the range, 2.5 kg steps, AttemptRules shared with the server) as a
	convenience only. Notices (a refused choice, the cooldown) show under
	the title, also outside a meet.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MockMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("MockMeetConfig"))
local MeetFolder = Shared:WaitForChild("Meet")
local MockMeetRemotes = require(MeetFolder:WaitForChild("MockMeetRemotes"))
local AttemptRules = require(MeetFolder:WaitForChild("AttemptRules"))

local MockMeetUI = require(script.Parent:WaitForChild("MockMeetUI"))

local MockMeetController = {}

local started = false

function MockMeetController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local remotes = MockMeetRemotes.waitForClient(ReplicatedStorage)

	local state: MockMeetRemotes.MeetState? = nil
	local chosenKg: number? = nil
	local deadline: number? = nil

	-- What is wrong with `kg` for the lift being chosen (range, steps, attempt rules), or nil when it is fine.
	-- The same checks the server makes; the server's answer is the one that counts.
	local function problemWith(kg: number): string?
		local current = state
		if current == nil or current.lift == nil then
			return nil
		end
		if current.minKg and kg < current.minKg - 1e-6 or current.maxKg and kg > current.maxKg + 1e-6 then
			return string.format("Choose between %s and %s kg.", tostring(current.minKg), tostring(current.maxKg))
		end
		local step = MockMeetConfig.WeightStepKg
		if math.abs(kg / step - math.floor(kg / step + 0.5)) > 1e-6 then
			return string.format("Weights go in %s kg steps.", tostring(step))
		end
		local history: AttemptRules.AttemptHistory = {}
		for _, attempt in ipairs(current.attempts[current.lift] or {}) do
			if attempt.result == "GoodLift" or attempt.result == "NoLift" then
				local result: AttemptRules.AttemptResult = if attempt.result == "GoodLift" then "GoodLift" else "NoLift"
				table.insert(history, { weightKg = attempt.weightKg, result = result })
			end
		end
		local ok, rejection = AttemptRules.validate(history, kg)
		if not ok then
			return if rejection then rejection.message else "That weight is not allowed."
		end
		return nil
	end

	local ui: MockMeetUI.Ui
	local function redraw()
		local kg = chosenKg
		local problem: string? = nil
		if state and state.phase == "Choose" then
			problem = if kg then problemWith(kg) else "Type a weight in kg."
		end
		ui.draw(state, kg, problem)
	end

	local function confirm()
		local current = state
		local kg = chosenKg
		-- Nothing to send while the hint shows a problem (the server would refuse it anyway).
		if current == nil or current.phase ~= "Choose" or kg == nil or problemWith(kg) then
			return
		end
		remotes.choose:FireServer(kg)
	end

	ui = MockMeetUI.build({
		leave = function()
			remotes.leave:FireServer()
		end,
		step = function(deltaKg: number)
			local current = state
			if current == nil or current.phase ~= "Choose" then
				return
			end
			-- Nudge from the typed weight (or the suggestion), onto the step grid, inside the allowed range.
			local step = MockMeetConfig.WeightStepKg
			local from = chosenKg or current.suggestedKg or current.minKg or 0
			local kg = math.floor((from + deltaKg) / step + 0.5) * step
			if current.minKg then
				kg = math.max(kg, current.minKg)
			end
			if current.maxKg then
				kg = math.min(kg, current.maxKg)
			end
			chosenKg = kg
			redraw()
		end,
		typed = function(text: string, submit: boolean)
			if state == nil or state.phase ~= "Choose" then
				return
			end
			-- Digits and one decimal point only ("142,5" is read as 142.5).
			local withPoint = string.gsub(text, ",", ".")
			local cleaned = string.gsub(withPoint, "[^%d%.]", "")
			chosenKg = tonumber(cleaned)
			redraw()
			if submit then
				confirm()
			end
		end,
		confirm = confirm,
		lift = function()
			if state and state.phase == "Ready" then
				remotes.ready:FireServer()
			end
		end,
	})
	ui.gui.Parent = player:WaitForChild("PlayerGui")

	remotes.state.OnClientEvent:Connect(function(newState: MockMeetRemotes.MeetState)
		local previous = state
		state = newState
		-- A fresh choice starts from the server's default.
		if newState.phase == "Choose" and (previous == nil or previous.phase ~= "Choose"
			or previous.lift ~= newState.lift or previous.attemptNumber ~= newState.attemptNumber) then
			chosenKg = newState.suggestedKg
		end
		deadline = if newState.secondsLeft then os.clock() + newState.secondsLeft else nil
		redraw()
	end)
	remotes.notice.OnClientEvent:Connect(function(message: string)
		ui.notice(message)
		if not ui.gui.Enabled then
			-- Outside a meet (the cooldown): show just the notice for a moment.
			ui.gui.Enabled = true
			task.delay(4, function()
				if player:GetAttribute(MockMeetConfig.SlotAttribute) == nil then
					ui.gui.Enabled = false
				end
			end)
		end
	end)

	local function refresh()
		local inMeet = player:GetAttribute(MockMeetConfig.SlotAttribute) ~= nil
		ui.gui.Enabled = inMeet
		if not inMeet then
			state, chosenKg, deadline = nil, nil, nil
		end
		for _, name in ipairs({ "Scorecard", "Action", "Leave", "Title" }) do
			local child = ui.gui:FindFirstChild(name)
			if child and child:IsA("GuiObject") then
				child.Visible = inMeet and (name ~= "Action" or (state ~= nil and state.phase ~= "Lifting"))
			end
		end
	end
	player:GetAttributeChangedSignal(MockMeetConfig.SlotAttribute):Connect(refresh)
	refresh()

	RunService.Heartbeat:Connect(function()
		if ui.gui.Enabled then
			ui.setTimer(if deadline then deadline - os.clock() else nil)
		end
	end)
end

return MockMeetController
