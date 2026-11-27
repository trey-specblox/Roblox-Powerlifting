--!strict
--[[
	PodiumFloatSpin
	Client / Meet

	Turns and bobs what floats over the podium lifters' heads (server PodiumFloat, user 2026-11-27): the winner's big
	trophy turns slowly and bobs; a place number ("#1" "#2" "#3") only bobs, so it stays readable. Each screen does it
	for itself from the pivot the server put in the BaseCFrame attribute, so nothing is sent per frame. Looks only.

	PERFORMANCE: at most 3 at a podium, one PivotTo each a frame, only while a ceremony is on.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local PodiumFloatSpin = {}

local TAG = "PodiumFloat" -- PodiumFloat.Tag on the server
local TURN_SPEED = 0.9 -- radians a second
local BOB_HEIGHT = 0.25 -- studs
local BOB_SPEED = 1.6 -- radians a second

local floating: { [Instance]: number } = {} -- what floats -> when it was first seen
local stepping: RBXScriptConnection? = nil

local function step()
	local now = os.clock()
	for thing, since in pairs(floating) do
		local base = thing:GetAttribute("BaseCFrame")
		if thing.Parent == nil or typeof(base) ~= "CFrame" then
			continue
		end
		local t = now - since
		local bob = CFrame.new(0, math.sin(t * BOB_SPEED) * BOB_HEIGHT, 0)
		if thing:IsA("Model") then
			thing:PivotTo(base * bob * CFrame.Angles(0, t * TURN_SPEED, 0))
		elseif thing:IsA("BasePart") then
			thing.CFrame = base * bob
		end
	end
end

local function add(thing: Instance)
	floating[thing] = os.clock()
	if stepping == nil then
		stepping = RunService.RenderStepped:Connect(step)
	end
end

local function remove(thing: Instance)
	floating[thing] = nil
	if next(floating) == nil and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

function PodiumFloatSpin.start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	for _, thing in ipairs(CollectionService:GetTagged(TAG)) do
		add(thing)
	end
end

return PodiumFloatSpin
