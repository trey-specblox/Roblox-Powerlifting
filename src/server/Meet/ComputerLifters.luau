--!strict
--[[
	ComputerLifters
	Server / Meet

	The computer lifters that fill a Local meet's empty spots (GAME_DESIGN.md
	§37.2, user 2026-11-01), so a Local or Regional meet always runs, even with
	one real player. A computer lifter weighs in, declares its attempts and
	makes or misses them; the server decides all of it, and no client is
	involved. Its name ends in "(CPU)" so players always know who is real.

	HOW STRONG: each one copies a real lifter of the meet (in turn): the same
	class, about the same bodyweight, and that lifter's Competition Numbers
	times a random factor (LocalMeetConfig.ComputerLifters.StrengthSpread), so
	its score lands a bit below to a bit above the real lifters' and placing is
	a real race.

	THEIR ATTEMPTS: each attempt aims at a share of its CN (AttemptShares) and
	is made with a chance (MakeChances); after a miss it repeats the weight.
	Every weight goes through AttemptChoice, the same rules real lifters have.

	It never touches player data and never pays anything: LocalMeetService
	keeps every reward for real players (§37.2).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local LocalMeetConfig = require(ConfigFolder:WaitForChild("LocalMeetConfig"))
local MeetConfig = require(ConfigFolder:WaitForChild("MeetConfig"))
local MeetFolder = Shared:WaitForChild("Meet")
local AttemptRules = require(MeetFolder:WaitForChild("AttemptRules"))
local AttemptChoice = require(MeetFolder:WaitForChild("AttemptChoice"))
local MeetFigures = require(script.Parent:WaitForChild("MeetFigures"))

local ComputerLifters = {}

local CONFIG = LocalMeetConfig.ComputerLifters
local FOLDER_NAME = "LocalMeetComputerLifters"
-- How much of the way to its new heading a walking body turns each frame (smooth turns at the corners).
local TURN_RATE = 0.18

-- What a computer lifter brings to the weigh-in.
export type Plan = {
	name: string,
	classLabel: string,
	bodyweightKg: number,
	competitionNumber: { [string]: number },
}

-- The real lifter a computer lifter is planned from.
export type Template = {
	classLabel: string,
	bodyweightKg: number,
	competitionNumber: { [string]: number },
}

local function between(random: Random, range: { number }): number
	return random:NextNumber(range[1], range[2])
end

--[[
	Plans `count` computer lifters from the meet's real lifters (`templates`,
	used in turn). Names are made up (never real people), unique in the meet,
	and marked "(CPU)".
]]
function ComputerLifters.plan(templates: { Template }, count: number, random: Random): { Plan }
	local plans: { Plan } = {}
	if #templates == 0 then
		return plans
	end
	local names = table.clone(CONFIG.Names)
	for index = 1, count do
		local template = templates[(index - 1) % #templates + 1]
		local factor = between(random, CONFIG.StrengthSpread)
		local competitionNumber: { [string]: number } = {}
		for _, lift in ipairs(MeetConfig.LiftOrder) do
			competitionNumber[lift] = math.max(20, template.competitionNumber[lift] * factor)
		end
		local name = "Lifter " .. index
		if #names > 0 then
			name = table.remove(names, random:NextInteger(1, #names)) :: string
		end
		table.insert(plans, {
			name = name .. " (CPU)",
			classLabel = template.classLabel,
			-- A little lighter or the same, so it stays in the template's class.
			bodyweightKg = math.floor(template.bodyweightKg * between(random, CONFIG.BodyweightSpread) * 10 + 0.5) / 10,
			competitionNumber = competitionNumber,
		})
	end
	return plans
end

--[[
	The weight a computer lifter declares for `attemptNumber` of a lift, or nil
	when no heavier weight is allowed (the attempt is passed). After a miss it
	repeats the weight; otherwise it aims at AttemptShares of its CN.
]]
function ComputerLifters.nextWeight(cnKg: number, history: AttemptRules.AttemptHistory, attemptNumber: number): number?
	local minKg, default = AttemptChoice.nextWeights(cnKg, history, LocalMeetConfig.WeightStepKg,
		LocalMeetConfig.OpenerSuggestionPercent)
	if minKg == nil or default == nil then
		return nil
	end
	local last = history[#history]
	local want: number
	if last and last.result ~= "GoodLift" then
		want = last.weightKg
	else
		local share = CONFIG.AttemptShares[math.clamp(attemptNumber, 1, #CONFIG.AttemptShares)]
		want = cnKg * share
	end
	local step = LocalMeetConfig.WeightStepKg
	want = math.floor(want / step + 0.5) * step
	local kg = AttemptChoice.check(cnKg, history, step, math.max(want, minKg))
	return kg or default
end

-- Whether a computer lifter makes `attemptNumber` (1 to 3) of a lift.
function ComputerLifters.makes(attemptNumber: number, random: Random): boolean
	return random:NextNumber() < CONFIG.MakeChances[math.clamp(attemptNumber, 1, #CONFIG.MakeChances)]
end

-- How long a computer lifter takes over a lift, in seconds (so its lights do not come up at once).
function ComputerLifters.liftSeconds(random: Random): number
	return between(random, CONFIG.LiftSeconds)
end

-- ---------------------------------------------------------------- its body on the platform

local loadTrack: (body: Model, id: string) -> AnimationTrack?

local function folder(): Folder
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = FOLDER_NAME
	made.Parent = Workspace
	return made
end

-- Height of the root part's centre above the floor when the body stands.
local function standingHeight(body: Model): number
	local humanoid = body:FindFirstChildOfClass("Humanoid")
	local root = body:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") then
		return humanoid.HipHeight + root.Size.Y / 2
	end
	return 3
end

--[[
	A plain avatar for the computer lifter, standing (anchored) at `spot`, its
	name above its head. Nil when Roblox could not make one: the computer
	lifter still lifts, on the boards only.
]]
function ComputerLifters.spawnBody(plan: Plan, spot: CFrame, random: Random): Model?
	local ok, body = pcall(function()
		local description = Instance.new("HumanoidDescription")
		local skin = CONFIG.SkinColours[random:NextInteger(1, #CONFIG.SkinColours)]
		description.HeadColor = skin
		description.LeftArmColor = skin
		description.RightArmColor = skin
		description.LeftLegColor = skin
		description.RightLegColor = skin
		-- The singlet.
		description.TorsoColor = CONFIG.SingletColours[random:NextInteger(1, #CONFIG.SingletColours)]
		-- A real-looking avatar (§37.2): Roblox's own free hair, sometimes glasses, and a lifter's build.
		if random:NextNumber() >= CONFIG.NoHairChance then
			description.HairAccessory = tostring(CONFIG.Hair[random:NextInteger(1, #CONFIG.Hair)])
		end
		if random:NextNumber() < CONFIG.GlassesChance then
			description.FaceAccessory = tostring(CONFIG.Glasses[random:NextInteger(1, #CONFIG.Glasses)])
		end
		local width = between(random, CONFIG.WidthSpread)
		description.WidthScale = width
		description.DepthScale = width
		description.HeightScale = between(random, CONFIG.HeightSpread)
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(body) ~= "Instance" or not body:IsA("Model") then
		warn("[ComputerLifters] could not make a body for " .. plan.name .. ": " .. tostring(body))
		return nil
	end
	local model = body :: Model
	model.Name = plan.name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = plan.name
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		humanoid.BreakJointsOnDeath = false
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Only the root is anchored: an animation can't move anchored limbs.
			part.Anchored = part.Name == "HumanoidRootPart"
			part.CanCollide = false
			part.CanTouch = false
			part.CastShadow = false
		end
	end
	-- Never in a player's way (a Humanoid switches collision back on for its limbs).
	MeetFigures.makeGhost(model)
	model.Parent = folder()
	ComputerLifters.moveBody(model, spot)
	-- Standing about like a player does between lifts (walking and lifting play over it).
	local idle = loadTrack(model, CONFIG.IdleAnimationId)
	if idle then
		idle.Priority = Enum.AnimationPriority.Idle
		idle.Looped = true
		idle:Play(0.2)
	end
	return model
end

-- Stands a computer lifter's body at `spot` (a floor point facing its way).
function ComputerLifters.moveBody(body: Model?, spot: CFrame)
	if body and body.Parent then
		body:PivotTo(spot * CFrame.new(0, standingHeight(body), 0))
	end
end

-- Loads animation `id` on a computer lifter's body (nil without a humanoid, or when it cannot load).
function loadTrack(body: Model, id: string): AnimationTrack?
	local humanoid = body:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		local made = Instance.new("Animator")
		made.Parent = humanoid
		animator = made
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, loaded = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	return if ok then loaded :: AnimationTrack else nil
end

-- Plays the walk on a computer lifter's body while it moves (Roblox's own R15 walk; nil without an animator).
local function playWalk(body: Model, animationId: string?): AnimationTrack?
	local track = loadTrack(body, animationId or CONFIG.WalkAnimationId)
	if track == nil then
		return nil
	end
	track.Priority = Enum.AnimationPriority.Movement
	track.Looped = true
	track:Play(0.1)
	return track
end

--[[
	A computer lifter's cheer (Roblox's R15 cheer, like a player's emote): for
	`seconds`, or until stopped when `seconds` is nil (the podium). Returns the
	track so the caller can stop it.
]]
function ComputerLifters.cheer(body: Model?, seconds: number?): AnimationTrack?
	if not body or not body.Parent then
		return nil
	end
	local track = loadTrack(body, CONFIG.CheerAnimationId)
	if track == nil then
		return nil
	end
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play(0.15)
	if seconds then
		task.delay(seconds, function()
			track:Stop(0.25)
		end)
	end
	return track
end

--[[
	Walks a computer lifter's body along `points` (floor points) to `final`,
	facing the way it goes, at CONFIG.WalkSpeed (GAME_DESIGN §37.5: the walk
	out to the platform and back). Yields until it arrives, or stops where it
	is when `stillGoing()` turns false.
]]
function ComputerLifters.walkBody(body: Model?, points: { Vector3 }, final: CFrame, stillGoing: () -> boolean, walkAnimationId: string?)
	if not body or not body.Parent then
		return
	end
	local track = playWalk(body, walkAnimationId)
	local height = standingHeight(body)
	-- The whole route as one line, walked at a steady pace without stopping at the corners (user 2026-11-01:
	-- "one fluid walk"); the body turns smoothly toward where it is heading.
	local route = { body:GetPivot().Position - Vector3.new(0, height, 0) }
	for _, point in ipairs(points) do
		table.insert(route, point)
	end
	table.insert(route, final.Position)
	local facing = body:GetPivot().LookVector
	local segment, along = 1, 0
	local arrived = true
	while segment < #route do
		if not stillGoing() or not body.Parent then
			arrived = false
			break
		end
		along += CONFIG.WalkSpeed * task.wait()
		local from, to = route[segment], route[segment + 1]
		local length = (to - from).Magnitude
		while along >= length and segment < #route do
			along -= length
			segment += 1
			if segment < #route then
				from, to = route[segment], route[segment + 1]
				length = (to - from).Magnitude
			end
		end
		if segment >= #route then
			break
		end
		local at = if length > 1e-3 then from:Lerp(to, along / length) else to
		local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
		if flat.Magnitude > 0.05 then
			-- (A straight about-turn would blend to nothing: then face the new way at once.)
			local blended = facing:Lerp(flat.Unit, TURN_RATE)
			facing = if blended.Magnitude > 1e-3 then blended.Unit else flat.Unit
		end
		body:PivotTo(CFrame.lookAt(at, at + facing) + Vector3.new(0, height, 0))
	end
	if track then
		track:Stop(0.2)
	end
	if arrived then
		ComputerLifters.moveBody(body, final)
	end
end

function ComputerLifters.removeBody(body: Model?)
	if body then
		body:Destroy()
	end
end

return ComputerLifters
