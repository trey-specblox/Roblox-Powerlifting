--!strict
--[[
	MeetCheerBar
	Client / Meet

	Cheering at the big meets (GAME_DESIGN.md §36.4, user 2026-11-08), on this
	player's screen. The server (MeetCheering) says what to show:
	  - walk into a rack's invisible watching zone while someone is up there and a
	    bar pops up: "CHEER FOR <NAME>", how full the crowd has got it, and a small
	    meter of your own microphone. Cheer through voice chat to fill it. Without
	    voice chat it says so: voice only (user's pick).
	  - the lifter, when the crowd fills their bar: a short note, CROWD BONUS.
	  - a cheerer, when the lift they helped with is good: the coins they earned.

	Your microphone's loudness is measured here, on your own device (Roblox gives the
	server nobody's voice): an AudioAnalyzer wired to your AudioDeviceInput, read only
	while you stand in a zone. Every CheerConfig.ReportSeconds the average goes to the
	server, which decides what it counts for. In Studio, which has no voice, the
	workspace attribute CheerConfig.StudioLoudnessAttribute (0..1) stands in for it.

	PERFORMANCE: one small panel, made once. While in a zone: one analyzer read a frame
	and a tiny message 4 times a second.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CheerConfig = require(Shared:WaitForChild("Config"):WaitForChild("CheerConfig"))
local LocalMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("LocalMeetRemotes"))

local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours

local MeetCheerBar = {}

local PANEL_WIDTH = 440
local PANEL_HEIGHT = 92
-- Where the bar sits: the top middle, which is empty at a meet (a waiting lifter's meet card is at the bottom middle), slid up
-- off the screen when hidden.
local SHOWN_AT = UDim2.new(0.5, 0, 0, 78)
local HIDDEN_AT = UDim2.new(0.5, 0, 0, -130)
-- The note (the lifter's bonus, a cheerer's coins): top right between LEAVE and the scorecard, clear of a running minigame in
-- the middle.
local NOTE_AT = UDim2.new(1, -24, 0, 170)

local started = false

-- The microphone: this player's voice input, an analyzer wired to it, and its loudness now (0..1).
local analyzer: AudioAnalyzer? = nil
local voiceInput: AudioDeviceInput? = nil

local function findVoiceInput(): AudioDeviceInput?
	local player = Players.LocalPlayer
	local found = player:FindFirstChildOfClass("AudioDeviceInput")
	if found then
		return found
	end
	for _, item in ipairs(player:GetDescendants()) do
		if item:IsA("AudioDeviceInput") then
			return item
		end
	end
	return nil
end

-- The analyzer on this player's microphone, made the first time it's needed (nil: no voice input).
local function ensureAnalyzer(): AudioAnalyzer?
	local input = findVoiceInput()
	if input == nil then
		return nil
	end
	if analyzer and voiceInput == input and analyzer.Parent then
		return analyzer
	end
	local made = Instance.new("AudioAnalyzer")
	made.Name = "CheerMeter"
	made.Parent = input
	local wire = Instance.new("Wire")
	wire.Name = "CheerMeterWire"
	wire.SourceInstance = input
	wire.TargetInstance = made
	wire.Parent = made
	analyzer, voiceInput = made, input
	return made
end

-- How loud this player is right now, 0..1.
local function loudnessNow(): number
	if RunService:IsStudio() then
		local test = workspace:GetAttribute(CheerConfig.StudioLoudnessAttribute)
		if typeof(test) == "number" then
			return math.clamp(test, 0, 1)
		end
	end
	local meter = ensureAnalyzer()
	local input = voiceInput
	if meter == nil or input == nil or input.Muted then
		return 0
	end
	local rms = meter.RmsLevel
	return math.clamp((rms - CheerConfig.QuietRms) / (CheerConfig.LoudRms - CheerConfig.QuietRms), 0, 1)
end

local function hasMicrophone(): boolean
	if RunService:IsStudio() and typeof(workspace:GetAttribute(CheerConfig.StudioLoudnessAttribute)) == "number" then
		return true
	end
	return findVoiceInput() ~= nil
end

function MeetCheerBar.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local set = LocalMeetRemotes.waitForClient(ReplicatedStorage)

	local gui = Instance.new("ScreenGui")
	gui.Name = "MeetCheerBar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")

	-- The bar's panel, slid off the bottom until needed.
	local holder, body = UIStyle.panel(gui, "CheerPanel", HIDDEN_AT, UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT))
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Visible = false
	UIStyle.seeThrough(holder, 0.25)
	local title = UIStyle.titleTag(holder, "Tag", "CHEER FOR", UDim2.fromOffset(-10, -22), UDim2.fromOffset(330, 38), C.yellow, "star")
	-- The bar itself.
	local track = UIStyle.frame(body, "Track", UDim2.fromOffset(18, 26), UDim2.new(1, -36, 0, 22), C.empty)
	UIStyle.stroke(track, C.white, 2)
	local fillBar = UIStyle.frame(track, "Fill", UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), C.yellow)
	local fullText = UIStyle.label(track, "FullText", UDim2.fromScale(0, 0.05), UDim2.fromScale(1, 0.9), C.ink, UIStyle.heading(),
		Enum.TextXAlignment.Center)
	fullText.ZIndex = 3
	fullText.Text = ""
	-- Under it: the hint on the left, your microphone's level on the right.
	local hint = UIStyle.text(body, "Hint", UDim2.fromOffset(18, 54), UDim2.new(1, -150, 0, 26), UIStyle.TextSizes.small, C.white,
		UIStyle.font(Enum.FontWeight.Bold))
	hint.TextWrapped = false
	local micLabel = UIStyle.text(body, "MicLabel", UDim2.new(1, -128, 0, 54), UDim2.fromOffset(40, 26), UIStyle.TextSizes.small,
		C.muted, UIStyle.font(Enum.FontWeight.Bold))
	micLabel.Text = "MIC"
	micLabel.TextWrapped = false
	local micTrack = UIStyle.frame(body, "MicTrack", UDim2.new(1, -86, 0, 61), UDim2.fromOffset(68, 12), C.navyDeep)
	UIStyle.stroke(micTrack, C.white, 1, 0.4)
	local micFill = UIStyle.frame(micTrack, "MicFill", UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), C.white)

	-- The note at the top: the lifter's bonus, or a cheerer's coins.
	local noteHolder, noteBody = UIStyle.panel(gui, "CheerNote", NOTE_AT, UDim2.fromOffset(400, 64))
	noteHolder.AnchorPoint = Vector2.new(1, 0)
	noteHolder.Visible = false
	local noteText = UIStyle.text(noteBody, "Text", UDim2.fromOffset(16, 8), UDim2.new(1, -32, 1, -16), UIStyle.TextSizes.body,
		C.white, UIStyle.heading(), Enum.TextXAlignment.Center)
	UIStyle.fitToScreen(gui)

	local noteToken = 0
	local function showNote(text: string, colour: Color3, seconds: number)
		noteToken += 1
		local token = noteToken
		noteText.Text = text
		noteText.TextColor3 = colour
		noteHolder.Visible = true
		task.delay(seconds, function()
			if noteToken == token then
				noteHolder.Visible = false
			end
		end)
	end

	-- What the server last said for the bar.
	local view: LocalMeetRemotes.CheerView = { role = "none" }
	local shown = false
	local slide: Tween? = nil
	local function setShown(show: boolean)
		if show == shown then
			return
		end
		shown = show
		if slide then
			slide:Cancel()
		end
		if show then
			holder.Visible = true
			holder.Position = HIDDEN_AT
		end
		local tween = TweenService:Create(holder, TweenInfo.new(if show then 0.35 else 0.25,
			if show then Enum.EasingStyle.Back else Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = if show then SHOWN_AT else HIDDEN_AT })
		slide = tween
		tween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and not shown then
				holder.Visible = false
			end
		end)
		tween:Play()
	end

	local function redraw()
		if view.role ~= "cheer" then
			setShown(false)
			return
		end
		title.Text = "CHEER FOR " .. string.upper(view.name or "")
		local fill = math.clamp(view.fill or 0, 0, 1)
		TweenService:Create(fillBar, TweenInfo.new(0.25, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(fill, 1) }):Play()
		fillBar.BackgroundColor3 = if view.full then C.white else C.yellow
		local canCheer = view.voice == true and hasMicrophone()
		if view.result then
			fullText.Text = view.result
			fullText.TextColor3 = if view.result == "GOOD LIFT" then C.ink else C.red
			hint.Text = if view.full then "THE CROWD HAD THEIR BACK" else "THE BAR DIDN'T FILL THIS TIME"
		elseif view.full then
			fullText.Text = "FULL!"
			fullText.TextColor3 = C.ink
			hint.Text = "THEIR LIFT IS EASIER. KEEP IT LOUD!"
		else
			fullText.Text = ""
			hint.Text = if canCheer then "YELL IN VOICE CHAT TO FILL IT!" else "VOICE CHAT IS NEEDED TO CHEER"
		end
		hint.TextColor3 = if canCheer or view.full or view.result then C.white else C.muted
		micLabel.Visible = canCheer and view.result == nil
		micTrack.Visible = canCheer and view.result == nil
		setShown(true)
	end

	set.cheerState.OnClientEvent:Connect(function(incoming: LocalMeetRemotes.CheerView)
		if typeof(incoming) ~= "table" then
			return
		end
		if incoming.role == "lifter" then
			-- "+12.75", "+5" (no trailing zeros).
			local bonus = string.format("%.2f", incoming.bonus or 0)
			bonus = string.gsub(bonus, "0+$", "")
			bonus = string.gsub(bonus, "%.$", "")
			showNote(string.format("THE CROWD IS BEHIND YOU!  +%s TECHNIQUE", bonus), C.yellow, CheerConfig.LifterNoteSeconds)
			return
		elseif incoming.role == "coins" then
			showNote(string.format("+%d COINS FOR CHEERING %s", incoming.coins or 0, string.upper(incoming.name or "")), C.yellow, 4)
			return
		end
		view = incoming
		redraw()
	end)

	-- While standing in a zone with a lift to cheer: your microphone's level each frame, its average sent 4 times a second.
	local sum, samples, sinceReport = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		local cheering = view.role == "cheer" and view.voice == true and view.result == nil
		if not cheering then
			sum, samples, sinceReport = 0, 0, 0
			return
		end
		local loud = loudnessNow()
		micFill.Size = UDim2.fromScale(loud, 1)
		micFill.BackgroundColor3 = if loud >= 0.6 then C.yellow else C.white
		sum += loud
		samples += 1
		sinceReport += dt
		if sinceReport >= CheerConfig.ReportSeconds then
			local average = if samples > 0 then sum / samples else 0
			sum, samples, sinceReport = 0, 0, 0
			if average > 0 then
				set.cheerReport:FireServer(average)
			end
		end
	end)
end

return MeetCheerBar
