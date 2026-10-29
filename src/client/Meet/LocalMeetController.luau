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

local MockMeetController = require(script.Parent:WaitForChild("MockMeetController"))
local LocalMeetLobbyUI = require(script.Parent:WaitForChild("LocalMeetLobbyUI"))

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
	})

	local lobby: LocalMeetRemotes.LobbyState? = nil
	local standings: LocalMeetRemotes.Standings? = nil
	local ui = LocalMeetLobbyUI.build({
		exit = function()
			remotes.exit:FireServer()
		end,
		signUp = function()
			remotes.signUp:FireServer()
		end,
	})
	ui.gui.Parent = player:WaitForChild("PlayerGui")

	local function refresh()
		local inVenue = player:GetAttribute(LocalMeetConfig.VenueAttribute) ~= nil
		local lifting = player:GetAttribute(LocalMeetConfig.PlatformAttribute) ~= nil
		if not inVenue then
			lobby, standings = nil, nil
		end
		ui.setMode(inVenue, lifting)
		ui.drawStandings(standings)
	end
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

	-- The countdown, a few times a second.
	local nextDraw = 0
	RunService.Heartbeat:Connect(function()
		if not ui.gui.Enabled or os.clock() < nextDraw then
			return
		end
		nextDraw = os.clock() + 0.25
		local current = lobby
		ui.drawLobby(current, if current then current.nextStartAt - Workspace:GetServerTimeNow() else nil)
	end)
end

return LocalMeetController
