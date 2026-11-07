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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LocalMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("LocalMeetConfig"))
local LocalMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("LocalMeetRemotes"))
local MockMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("MockMeetRemotes"))

local MockMeetController = require(script.Parent:WaitForChild("MockMeetController"))
local LocalMeetLobbyUI = require(script.Parent:WaitForChild("LocalMeetLobbyUI"))
local LocalMeetAwards = require(script.Parent:WaitForChild("LocalMeetAwards"))
local LocalMeetWarmUpUI = require(script.Parent:WaitForChild("LocalMeetWarmUpUI"))
local MeetLiftMoment = require(script.Parent:WaitForChild("MeetLiftMoment"))
local MeetChalkShot = require(script.Parent:WaitForChild("MeetChalkShot"))
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

	-- The lifter's own meet screen: the Mock Meet's, with the Local meet's title.
	MockMeetController.attach(remotes, LocalMeetConfig.PlatformAttribute, {
		guiName = "LocalMeet",
		tag = "LOCAL MEET",
		sub = "REFEREES  ·  COACH WATCHING",
		liftMoment = true,
	})
	-- Chalking up while they choose: the camera beside the panel, the puffs of chalk and their sounds.
	remotes.state.OnClientEvent:Connect(MeetChalkShot.onState)
	-- The lifter's turn on their own screen: the camera and the card.
	remotes.state.OnClientEvent:Connect(MeetLiftMoment.onState)

	local lobby: LocalMeetRemotes.LobbyState? = nil
	local standings: LocalMeetRemotes.Standings? = nil
	local ui = LocalMeetLobbyUI.build({
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
			MeetChalkShot.stop(true)
			MeetLiftMoment.stop(true)
			ui.setClearView(false)
		end
	end
	tab = MeetsTab.build(function()
		listOpen = not listOpen
		if listOpen then
			remotes.lobbyRequest:FireServer()
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
			tab.setCountdown(text)
			task.wait(1)
		end
	end)
	-- The list and the countdown work from anywhere, so ask for them from the start.
	remotes.lobbyRequest:FireServer()
end

return LocalMeetController
