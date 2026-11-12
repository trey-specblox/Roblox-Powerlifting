--!strict
--[[
	MeetEntrance
	Server / Meet

	A lifter's entrance at a meet (GAME_DESIGN §36.4, decided by the user 2026-11-08): their walk style out to the
	bar, and at State meets and up a short hype move before they set up. Which entrance: a player's own
	(PlayerDataService.getEntrance), or a random walk style for a computer lifter. Ids, speeds and lengths:
	EntranceConfig.

	Played by the server, so everyone sees the same thing, as with the lifts and the chalk. Visual only: nothing here
	decides anything. PERFORMANCE: one animation track per hype move, destroyed when it ends.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EntranceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EntranceConfig"))
local MeetWalkPath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Meet"):WaitForChild("MeetWalkPath"))
local CelebrationRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Meet"):WaitForChild("CelebrationRemotes"))
local Workspace = game:GetService("Workspace")

local FADE_SECONDS = 0.2

local random = Random.new()

local MeetEntrance = {}

-- A random walk style for a computer lifter (an uploaded one, or the Default's Roblox walk).
function MeetEntrance.randomComputerId(): string
	local ids = EntranceConfig.computerWalks()
	return ids[random:NextInteger(1, #ids)]
end

-- The walk to play and its speed: nil, nil for Roblox's own walk at the meet's usual speed.
function MeetEntrance.walkOf(entrance: EntranceConfig.Entrance?): (string?, number?)
	if entrance and EntranceConfig.hasWalk(entrance) then
		return entrance.walkAnimationId, entrance.walkSpeed
	end
	return nil, nil
end

-- How long the hype move lasts, or 0 when there is none to play (not uploaded yet).
function MeetEntrance.hypeSeconds(entrance: EntranceConfig.Entrance?): number
	if entrance and entrance.hypeAnimationId ~= "" then
		return entrance.hypeSeconds
	end
	return 0
end

--[[
	How far the walk style covers on `route` (floor points, start first): from where the walk passes `from` (the
	platform's banner at State, its doorway at Local and Regional; user 2026-11-11: "make the entrance animation start
	right when you start walking to the platform, so basically right when ur equal to the banner") to the end, flat.
	EntranceConfig.StyleWalkStuds when the platform has no such point.
]]
function MeetEntrance.styleStudsFrom(route: { Vector3 }, from: Vector3?): number
	if from == nil or #route < 2 then
		return EntranceConfig.StyleWalkStuds
	end
	local function flat(v: Vector3): Vector3
		return Vector3.new(v.X, 0, v.Z)
	end
	local target = flat(from)
	-- The point on the route nearest `from`: its segment, and how far along it.
	local bestIndex, bestAlong, bestGap = 1, 0, math.huge
	for index = 1, #route - 1 do
		local a, b = flat(route[index]), flat(route[index + 1])
		local span = b - a
		local length = span.Magnitude
		local along = if length > 1e-3 then math.clamp((target - a):Dot(span / length), 0, length) else 0
		local gap = ((if length > 1e-3 then a + span / length * along else a) - target).Magnitude
		if gap < bestGap then
			bestIndex, bestAlong, bestGap = index, along, gap
		end
	end
	local studs = (flat(route[bestIndex + 1]) - flat(route[bestIndex])).Magnitude - bestAlong
	for index = bestIndex + 1, #route - 1 do
		studs += (flat(route[index + 1]) - flat(route[index])).Magnitude
	end
	return math.max(1, studs)
end

-- How long the walk out along `route` (floor points, start first) takes: the usual speed, then the walk style's speed
-- over its last `styleStuds` (MeetEntrance.styleStudsFrom; EntranceConfig.StyleWalkStuds when nil), easing in and out
-- as the walk itself does (MeetWalkPath).
function MeetEntrance.walkOutSeconds(route: { Vector3 }, styleSpeed: number?, usualSpeed: number, styleStuds: number?): number
	if #route < 2 then
		return 0
	end
	local flat = function(v: Vector3): Vector3
		return Vector3.new(v.X, 0, v.Z)
	end
	local points: { Vector3 } = {}
	for index = 2, #route - 1 do
		table.insert(points, flat(route[index]))
	end
	return MeetWalkPath.new({
		from = flat(route[1]),
		look = Vector3.new(0, 0, -1),
		points = points,
		final = CFrame.new(flat(route[#route])),
		height = 0,
		usualSpeed = usualSpeed,
		styleSpeed = styleSpeed,
		styleStuds = if styleSpeed then (styleStuds or EntranceConfig.StyleWalkStuds) else nil,
	}).duration
end

--[[
	Plays the hype move on `character` and yields until it is over (its length in EntranceConfig). Returns at once when
	there is none, or the character can't play it (not R15).
]]
function MeetEntrance.playHype(character: Model?, entrance: EntranceConfig.Entrance?)
	local seconds = MeetEntrance.hypeSeconds(entrance)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if seconds <= 0 or entrance == nil or humanoid == nil or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		local made = Instance.new("Animator")
		made.Parent = humanoid
		animator = made
	end
	local animation = Instance.new("Animation")
	animation.Name = "MeetEntranceHype"
	animation.AnimationId = entrance.hypeAnimationId
	local ok, loaded = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if not ok then
		return
	end
	local track = loaded :: AnimationTrack
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false
	track:Play(FADE_SECONDS)
	-- Every player's game plays the move's own sound, in step with it (client CelebrationFx.playHype).
	if entrance.hypeSoundtrack then
		for id, known in pairs(EntranceConfig.Entrances) do
			if known == entrance then
				CelebrationRemotes.createHypeOnServer(ReplicatedStorage):FireAllClients(id, Workspace:GetServerTimeNow(), character)
				break
			end
		end
	end
	task.wait(seconds)
	track:Stop(FADE_SECONDS)
	task.delay(FADE_SECONDS + 0.05, function()
		track:Destroy()
	end)
end

return MeetEntrance
