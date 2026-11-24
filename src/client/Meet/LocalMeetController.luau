--!strict
--[[
	LocalMeetController
	Client / Meet

	The Local meet on the player's screen (GAME_DESIGN.md §29.10 "The Local
	meet — first build"):
		- while in the venue (player attribute LocalMeetConfig.VenueAttribute):
		  the venue screen (LocalMeetLobbyUI) with the countdown, SIGN UP, EXIT
		  and the standings
		- while lifting (LocalMeetConfig.PlatformAttribute): the Mock Meet's
		  screen (MockMeetController.attach) with the Local meet's title,
		  driven by the Local meet's remotes
		- the awards ceremony when a meet ends (LocalMeetAwards)
		- the WARM-UP card at a warm-up rack (LocalMeetWarmUpUI)

	It only ASKS (sign up, exit, the weight, LIFT, LEAVE); the server checks and
	decides everything. The countdown runs on server time
	(workspace:GetServerTimeNow()), so every player sees the same one.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LocalMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("LocalMeetConfig"))
local LocalMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("LocalMeetRemotes"))
local NationalsRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("NationalsRemotes"))
local MockMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("MockMeetRemotes"))

local MockMeetController = require(script.Parent:WaitForChild("MockMeetController"))
local LocalMeetLobbyUI = require(script.Parent:WaitForChild("LocalMeetLobbyUI"))
local LocalMeetAwards = require(script.Parent:WaitForChild("LocalMeetAwards"))
local LocalMeetWarmUpUI = require(script.Parent:WaitForChild("LocalMeetWarmUpUI"))
local MeetLiftMoment = require(script.Parent:WaitForChild("MeetLiftMoment"))
local MeetChalkShot = require(script.Parent:WaitForChild("MeetChalkShot"))
local MeetRitualShot = require(script.Parent:WaitForChild("MeetRitualShot"))
local MeetsTab = require(script.Parent:WaitForChild("MeetsTab"))

local LocalMeetController = {}

local started = false

function LocalMeetController.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local remotes = LocalMeetRemotes.waitForClient(ReplicatedStorage)

	-- THE LEAVE SIGN beside each platform's waiting spot (user 2026-11-24): its hold-to-leave prompt is off for
	-- everyone; this switches on the one for the platform this player is lifting on (the server checks it again).
	-- No prompt tile over the screen (user 2026-11-24: "it covers up the screen. Just have the screen n when players
	-- hold it the bar fills up"): the sign's own screen is the button. A finger (or the mouse) held on it holds the
	-- prompt (InputHoldBegin), E still works, and a bar along the sign's foot fills over the hold.
	local leaveOverlay: SurfaceGui? = nil
	local overlayFor: ProximityPrompt? = nil
	local overlayConnections: { RBXScriptConnection } = {}
	local function clearOverlay()
		for _, connection in ipairs(overlayConnections) do
			connection:Disconnect()
		end
		table.clear(overlayConnections)
		if leaveOverlay then
			leaveOverlay:Destroy()
		end
		leaveOverlay, overlayFor = nil, nil
	end
	local function overlayLeave(leave: ProximityPrompt)
		if overlayFor == leave and leaveOverlay then
			return
		end
		clearOverlay()
		local point = leave.Parent
		local board = point and point.Parent and point.Parent:FindFirstChild("LeaveBoard_" .. tostring(leave:GetAttribute("Platform")))
		local screenPart = if board and board:IsA("BasePart") then board
			elseif board then board:FindFirstChild("MeetBoard_Screen", true) else nil
		if screenPart == nil or not screenPart:IsA("BasePart") then
			return
		end
		local writing = screenPart:FindFirstChildOfClass("SurfaceGui")
		local gui = Instance.new("SurfaceGui")
		gui.Name = "LeaveHold"
		gui.Adornee = screenPart
		gui.Face = if writing then writing.Face else Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.ZOffset = 1
		gui.ResetOnSpawn = false
		local button = Instance.new("TextButton")
		button.Name = "Hold"
		button.BackgroundTransparency = 1
		button.Text = ""
		button.Size = UDim2.fromScale(1, 1)
		button.Parent = gui
		local track = Instance.new("Frame")
		track.Name = "Track"
		track.AnchorPoint = Vector2.new(0.5, 1)
		track.Position = UDim2.fromScale(0.5, 0.94)
		track.Size = UDim2.fromScale(0.86, 0.12)
		track.BackgroundColor3 = Color3.fromRGB(10, 14, 34)
		track.BorderSizePixel = 0
		track.Parent = gui
		local edge = Instance.new("UIStroke")
		edge.Color = Color3.fromRGB(255, 206, 40)
		edge.Thickness = 2
		edge.Parent = track
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = Color3.fromRGB(255, 206, 40)
		fill.BorderSizePixel = 0
		fill.Parent = track
		local filling: Tween? = nil
		local function empty()
			if filling then
				filling:Cancel()
				filling = nil
			end
			fill.Size = UDim2.fromScale(0, 1)
		end
		local function holdInput(input: InputObject): boolean
			return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
		end
		table.insert(overlayConnections, button.InputBegan:Connect(function(input)
			if holdInput(input) then
				leave:InputHoldBegin()
			end
		end))
		table.insert(overlayConnections, button.InputEnded:Connect(function(input)
			if holdInput(input) then
				leave:InputHoldEnd()
			end
		end))
		table.insert(overlayConnections, leave.PromptButtonHoldBegan:Connect(function()
			empty()
			filling = TweenService:Create(fill, TweenInfo.new(leave.HoldDuration, Enum.EasingStyle.Linear),
				{ Size = UDim2.fromScale(1, 1) })
			;(filling :: Tween):Play()
		end))
		table.insert(overlayConnections, leave.PromptButtonHoldEnded:Connect(empty))
		table.insert(overlayConnections, leave.Triggered:Connect(empty))
		gui.Parent = player:WaitForChild("PlayerGui")
		leaveOverlay, overlayFor = gui, leave
	end
	local function fitLeavePrompts()
		local hallIndex = player:GetAttribute(LocalMeetConfig.HallAttribute)
		local platformIndex = player:GetAttribute(LocalMeetConfig.PlatformAttribute)
		local mine: ProximityPrompt? = nil
		for _, leave in ipairs(CollectionService:GetTagged(LocalMeetConfig.LeavePromptTag)) do
			if leave:IsA("ProximityPrompt") then
				leave.Enabled = platformIndex ~= nil and leave:GetAttribute("Platform") == platformIndex
					and leave:GetAttribute("Hall") == hallIndex
				if leave.Enabled then
					mine = leave
				end
			end
		end
		if mine then
			overlayLeave(mine)
		else
			clearOverlay()
		end
	end
	player:GetAttributeChangedSignal(LocalMeetConfig.PlatformAttribute):Connect(fitLeavePrompts)
	player:GetAttributeChangedSignal(LocalMeetConfig.HallAttribute):Connect(fitLeavePrompts)
	CollectionService:GetInstanceAddedSignal(LocalMeetConfig.LeavePromptTag):Connect(fitLeavePrompts)
	fitLeavePrompts()

	-- The lifter's own meet screen: the Mock Meet's, with the Local meet's title.
	MockMeetController.attach(remotes, LocalMeetConfig.PlatformAttribute, {
		guiName = "LocalMeet",
		tag = "LOCAL MEET",
		sub = "REFEREES  ·  COACH WATCHING",
		liftMoment = true,
		-- (on a phone, no LEAVE bar: a stray tap withdrew the lifter; the venue's EXIT sign is the way out)
		leaveOnPhone = false,
	})
	-- Chalking up while they choose: the camera beside the panel, the puffs of chalk and their sounds.
	remotes.state.OnClientEvent:Connect(MeetChalkShot.onState)
	-- The coach's ritual on their turn at State and up: the cinematic at the chalk stand (on into the walk out).
	remotes.state.OnClientEvent:Connect(MeetRitualShot.onState)
	-- The lifter's turn on their own screen: the camera and the card.
	remotes.state.OnClientEvent:Connect(MeetLiftMoment.onState)

	local lobby: LocalMeetRemotes.LobbyState? = nil
	local standings: LocalMeetRemotes.Standings? = nil
	-- Nationals (GAME_DESIGN §39): its own remotes, its row in the same list.
	local nationalsRemotes = NationalsRemotes.waitForClient(ReplicatedStorage)
	local nationals: NationalsRemotes.View? = nil
	local ui = LocalMeetLobbyUI.build({
		nationalsSignUp = function()
			nationalsRemotes.signUp:FireServer()
		end,
		nationalsLeave = function()
			nationalsRemotes.leave:FireServer()
		end,
		exit = function()
			remotes.exit:FireServer()
		end,
		signUp = function(index: number)
			remotes.signUp:FireServer(index)
		end,
		spectate = function(index: number)
			remotes.spectate:FireServer(index)
		end,
	})
	ui.gui.Parent = player:WaitForChild("PlayerGui")

	--[[
		While lifting in a meet the character never trips or ragdolls (GAME_DESIGN
		§37.5: the walk out and the lift on the platform). The client owns its
		humanoid's states, so this is set here; it is put back after the meet.
	]]
	local function holdFooting(lifting: boolean)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not lifting)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not lifting)
			if lifting then
				local state = humanoid:GetState()
				if state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.Ragdoll then
					humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
				end
			end
		end
	end

	-- Elsewhere in the game, the MEETS tab can open the list (user 2026-11-06).
	local listOpen = false
	local tab: MeetsTab.Tab
	local function refresh()
		local inVenue = player:GetAttribute(LocalMeetConfig.VenueAttribute) ~= nil
		local lifting = player:GetAttribute(LocalMeetConfig.PlatformAttribute) ~= nil
		if not inVenue then
			standings = nil
		else
			listOpen = false
		end
		tab.setVisible(not inVenue)
		ui.setMode(inVenue, lifting, listOpen)
		ui.drawStandings(standings)
		holdFooting(lifting)
		if not lifting then
			MeetRitualShot.stop()
			MeetChalkShot.stop(true)
			MeetLiftMoment.stop(true)
			ui.setClearView(false)
		end
	end
	tab = MeetsTab.build(function()
		listOpen = not listOpen
		if listOpen then
			remotes.lobbyRequest:FireServer()
			nationalsRemotes.request:FireServer()
		end
		refresh()
	end)
	remotes.state.OnClientEvent:Connect(function(state: MockMeetRemotes.MeetState)
		-- The weight panel sits to the right now, so the standings stay beside it, on a phone too (user 2026-11-06).
		ui.setClearView(state.phase == "Ready" or state.phase == "Lifting")
	end)
	player:GetAttributeChangedSignal(LocalMeetConfig.VenueAttribute):Connect(refresh)
	player:GetAttributeChangedSignal(LocalMeetConfig.PlatformAttribute):Connect(refresh)
	refresh()

	remotes.lobby.OnClientEvent:Connect(function(newLobby: LocalMeetRemotes.LobbyState)
		lobby = newLobby
	end)
	nationalsRemotes.state.OnClientEvent:Connect(function(view: NationalsRemotes.View)
		nationals = view
		ui.drawNationals(nationals, Workspace:GetServerTimeNow())
	end)
	remotes.standings.OnClientEvent:Connect(function(newStandings: LocalMeetRemotes.Standings)
		standings = newStandings
		ui.drawStandings(standings)
	end)
	-- The awards ceremony: the podium camera, the cheer, the winner's theme song and celebration.
	remotes.awards.OnClientEvent:Connect(function(moment: LocalMeetRemotes.AwardsMoment)
		MeetLiftMoment.stop(false)
		LocalMeetAwards.play(moment)
	end)

	-- The WARM-UP card at a warm-up rack: it only asks for a lift or to step off.
	local warmUp = LocalMeetWarmUpUI.build({
		lift = function(liftName: string, weightKg: number)
			remotes.warmUpLift:FireServer(liftName, weightKg)
		end,
		leave = function()
			remotes.warmUpLeave:FireServer()
		end,
	})
	warmUp.gui.Parent = player:WaitForChild("PlayerGui")
	remotes.warmUpState.OnClientEvent:Connect(warmUp.draw)

	-- The countdown, a few times a second.
	local nextDraw = 0
	RunService.Heartbeat:Connect(function()
		if not ui.gui.Enabled or os.clock() < nextDraw then
			return
		end
		nextDraw = os.clock() + 0.25
		ui.drawLobby(lobby, Workspace:GetServerTimeNow())
		ui.drawNationals(nationals, Workspace:GetServerTimeNow())
	end)
	-- The tab counts down to the meet the player is signed up for, once a second.
	task.spawn(function()
		while true do
			local text: string? = nil
			for _, meet in ipairs(if lobby then (lobby :: LocalMeetRemotes.LobbyState).meets else {}) do
				if meet.signedUp then
					local seconds = math.max(0, math.ceil(meet.nextStartAt - Workspace:GetServerTimeNow()))
					text = string.format("%s  %d:%02d", if meet.state then "STATE" else "MEET " .. meet.index, seconds // 60, seconds % 60)
				end
			end
			-- Signed up for Nationals and no meet sooner: its countdown (hours, so "NATS 1:59").
			local view = nationals
			if text == nil and view and view.signedUp and view.status == nil then
				local seconds = math.max(0, math.ceil(view.nextStartAt - Workspace:GetServerTimeNow()))
				text = if seconds >= 3600 then string.format("NATS  %d:%02d", seconds // 3600, (seconds % 3600) // 60)
					else string.format("NATS  %d:%02d", seconds // 60, seconds % 60)
			end
			tab.setCountdown(text)
			task.wait(1)
		end
	end)
	-- The list and the countdown work from anywhere, so ask for them from the start.
	remotes.lobbyRequest:FireServer()
	nationalsRemotes.request:FireServer()
end

return LocalMeetController
