--!strict
--[[
	MeetWalkView
	Client / Meet

	Draws the meet's walks (the walk out to the bar and back, the coaches) on this player's screen every frame, from the
	walk the server sends once (LocalMeetRemotes.WALK, MeetWalkPath). The server used to move each body itself, and
	clients only saw it move every other frame or so: a stutter (user 2026-11-08: "not smooth"). Drawing only: the server
	still decides where every walk goes and where the body ends up.

	A drawn body stops being drawn when the walk ends, when the server says so, or as soon as the server moves the body
	somewhere else itself (a teleport), which then stands.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MeetFolder = Shared:WaitForChild("Meet")
local LocalMeetRemotes = require(MeetFolder:WaitForChild("LocalMeetRemotes"))
local MeetWalkPath = require(MeetFolder:WaitForChild("MeetWalkPath"))

local MeetWalkView = {}

type Drawn = {
	path: MeetWalkPath.Path,
	startAt: number,
	root: BasePart,
	-- The root's frame as this client last set it: anything else there means the server moved it.
	lastSet: CFrame?,
}

local drawn: { [Model]: Drawn } = {}

local function draw()
	local now = Workspace:GetServerTimeNow()
	for body, walk in pairs(drawn) do
		local root = walk.root
		if body.Parent == nil or root.Parent == nil then
			drawn[body] = nil
			continue
		end
		local last = walk.lastSet
		if last and not root.CFrame.Position:FuzzyEq(last.Position, 1e-3) then
			-- The server moved it itself.
			drawn[body] = nil
			continue
		end
		local frame, over = MeetWalkPath.at(walk.path, now - walk.startAt)
		body:PivotTo(frame)
		walk.lastSet = root.CFrame
		if over then
			drawn[body] = nil
		end
	end
end

function MeetWalkView.start()
	task.spawn(function()
		local remotes = LocalMeetRemotes.waitForClient(ReplicatedStorage)
		remotes.walk.OnClientEvent:Connect(function(body: any, data: any, startAt: any)
			if typeof(body) ~= "Instance" or not body:IsA("Model") then
				return
			end
			drawn[body] = nil
			local spec = MeetWalkPath.fromData(data)
			local root = body:FindFirstChild("HumanoidRootPart")
			if spec == nil or typeof(startAt) ~= "number" or root == nil or not root:IsA("BasePart") then
				return
			end
			drawn[body] = { path = MeetWalkPath.new(spec), startAt = startAt, root = root }
		end)
	end)
	-- Before the camera, so a camera following a walker sees where it is this frame.
	RunService:BindToRenderStep("MeetWalkView", Enum.RenderPriority.Camera.Value - 1, draw)
end

return MeetWalkView
