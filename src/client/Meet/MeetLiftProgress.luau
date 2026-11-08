--!strict
--[[
	MeetLiftProgress
	Client / Meet

	Tells the server how far the running minigame has got (GAME_DESIGN §37.5,
	user 2026-11-02: "make sure the typing game progress bar is tracking
	correctly with my characters position"), so the lifter's character on the
	platform moves with the minigame instead of with a timer: the squat goes
	down as the control meter fills, the bench bar comes down as the power ring
	closes, the deadlift comes up as the typing bar rises.

	Each minigame panel calls report(fraction) as it redraws. Only while the
	character is lifting in a meet (the MeetLift attribute); at most ten times a
	second, and only when it changed. VISUAL ONLY: the server never uses it to
	decide a lift (it replays the inputs itself).

	live(a, b, c, d) does the same job for a State rack's big screen (GAME_DESIGN
	§36.1, MeetLiveScreen): the numbers that draw the running minigame, only while
	the server has marked the character MeetLiveScreen. What each number means
	depends on the game (MeetLiveScreens, on the server, checks them).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalMeetRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Meet"):WaitForChild("LocalMeetRemotes"))

local MeetLiftProgress = {}

local SEND_INTERVAL_SECONDS = 0.1
local MIN_CHANGE = 0.01

local LIVE_ATTRIBUTE = "MeetLiveScreen"

local lastSentAt = 0
local lastSent = -1
local lastLiveAt = 0

-- The running minigame is `fraction` (0..1) of the way through.
function MeetLiftProgress.report(fraction: number)
	local character = Players.LocalPlayer.Character
	if character == nil or character:GetAttribute("MeetLift") == nil then
		lastSent = -1
		return
	end
	local now = os.clock()
	if now - lastSentAt < SEND_INTERVAL_SECONDS or math.abs(fraction - lastSent) < MIN_CHANGE then
		return
	end
	local folder = ReplicatedStorage:FindFirstChild(LocalMeetRemotes.FOLDER_NAME)
	local remote = folder and folder:FindFirstChild(LocalMeetRemotes.LIFT_PROGRESS)
	if remote == nil or not remote:IsA("RemoteEvent") then
		return
	end
	lastSentAt, lastSent = now, fraction
	remote:FireServer(math.clamp(fraction, 0, 1))
end

-- The running minigame's numbers for the big screen. Sent at most ten times a second; one lost on the way costs nothing.
function MeetLiftProgress.live(a: number, b: number, c: number, d: number)
	local character = Players.LocalPlayer.Character
	if character == nil or character:GetAttribute(LIVE_ATTRIBUTE) ~= true then
		return
	end
	local now = os.clock()
	if now - lastLiveAt < SEND_INTERVAL_SECONDS then
		return
	end
	local folder = ReplicatedStorage:FindFirstChild(LocalMeetRemotes.FOLDER_NAME)
	local remote = folder and folder:FindFirstChild(LocalMeetRemotes.LIVE_REPORT)
	if remote == nil or not remote:IsA("UnreliableRemoteEvent") then
		return
	end
	lastLiveAt = now
	remote:FireServer(a, b, c, d)
end

return MeetLiftProgress
