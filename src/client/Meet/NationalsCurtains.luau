--!strict
--[[
	NationalsCurtains
	Client / Meet

	The lifter's curtain at each Nationals platform (user 2026-11-18: "once the user clicks, they are seen using their
	arms and moving the curtain to enter the platform"), on every screen: the two panels either side of the split
	(NationalsConfig.CurtainFlapTag, NationalsArenaVenue) swing apart as someone walks through it, each turning about its
	top far corner on the pipe, so the split opens in an upside-down V (widest at the floor, as a pushed stage curtain
	does), and the bottoms trail the way the body moves. They open sooner while that body's hands part them (the
	Nationals_CurtainPart animation playing), and settle back slower than they open, like cloth falling closed. The
	stage's light showing through the split (NationalsConfig.CurtainGlowTag) goes while the split is open.

	It follows the bodies themselves, so it is in step with every lifter's walk on every screen with nothing sent.
	Display only: anchored parts moved on this screen only.
	PERFORMANCE: only while the player is inside the hall; per frame, each split checks the players near it (a few
	position reads); two parts per platform move only while a curtain is moving.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NationalsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("NationalsConfig"))

local NationalsCurtains = {}

local SETTINGS = NationalsConfig.Curtain
-- How near the split (studs, either way) a body has to be for it to be looked at at all.
local NEAR = 6

type Flap = {
	part: BasePart,
	hinge: Vector3,
	rest: CFrame,
	-- Turning about these (through the hinge), a positive angle swings the bottom away from the split / toward the stage.
	swingAxis: Vector3,
	tiltAxis: Vector3,
	swing: number,
	tilt: number,
}
type Split = {
	at: Vector3,
	toStage: Vector3,
	along: Vector3,
	flaps: { Flap },
	glows: { BasePart },
	-- The last frame's offset of each body across the curtain (for which way it is moving).
	lastAcross: { [Model]: number },
	moving: number,
}

local splits: { [string]: Split } = {}
local started = false

local function keyOf(v: Vector3): string
	return string.format("%d_%d_%d", math.round(v.X), math.round(v.Y), math.round(v.Z))
end

local function splitFor(at: Vector3, toStage: Vector3): Split
	local key = keyOf(at)
	local split = splits[key]
	if split == nil then
		local flat = Vector3.new(toStage.X, 0, toStage.Z).Unit
		split = { at = at, toStage = flat, along = flat:Cross(Vector3.yAxis), flaps = {}, glows = {}, lastAcross = {},
			moving = 0 }
		splits[key] = split
	end
	return split
end

-- Which way about `axis` (through `hinge`) moves the point `probe` along `want` for a positive angle.
local function signedAxis(axis: Vector3, hinge: Vector3, probe: Vector3, want: Vector3): Vector3
	local turned = CFrame.fromAxisAngle(axis, 0.05) * (probe - hinge)
	return if (turned - (probe - hinge)):Dot(want) >= 0 then axis else -axis
end

local function addFlap(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local hinge, rest, at, toStage = part:GetAttribute("Hinge"), part:GetAttribute("Rest"), part:GetAttribute("Split"),
		part:GetAttribute("TowardStage")
	if typeof(hinge) ~= "Vector3" or typeof(rest) ~= "CFrame" or typeof(at) ~= "Vector3" or typeof(toStage) ~= "Vector3" then
		return
	end
	local split = splitFor(at, toStage)
	-- (A glow can make the split first, not knowing the stage's way: the flap's attribute is the truth.)
	split.toStage = Vector3.new(toStage.X, 0, toStage.Z).Unit
	split.along = split.toStage:Cross(Vector3.yAxis)
	for _, flap in ipairs(split.flaps) do
		if flap.part == part then
			return
		end
	end
	-- The flap's bottom corner at the split: it should move away from the split (toward the hinge's side), and forward.
	local probe = Vector3.new(at.X, part.Position.Y - part.Size.Y / 2, at.Z)
	local away = Vector3.new(hinge.X - at.X, 0, hinge.Z - at.Z).Unit
	table.insert(split.flaps, {
		part = part,
		hinge = hinge,
		rest = rest,
		swingAxis = signedAxis(split.toStage, hinge, probe, away),
		tiltAxis = signedAxis(split.along, hinge, probe, split.toStage),
		swing = 0,
		tilt = 0,
	})
end

local function addGlow(part: Instance)
	local at = part:GetAttribute("Split")
	if not part:IsA("BasePart") or typeof(at) ~= "Vector3" then
		return
	end
	-- (Its flaps may not be here yet: then the split is made now, and they join it and set its way.)
	local split = splitFor(at, Vector3.new(0, 0, -1))
	if not table.find(split.glows, part) then
		table.insert(split.glows, part)
	end
end

local function prune()
	for key, split in pairs(splits) do
		for i = #split.flaps, 1, -1 do
			if split.flaps[i].part.Parent == nil then
				table.remove(split.flaps, i)
			end
		end
		for i = #split.glows, 1, -1 do
			if split.glows[i].Parent == nil then
				table.remove(split.glows, i)
			end
		end
		if #split.flaps == 0 and #split.glows == 0 then
			splits[key] = nil
		end
	end
end

-- Whether this body's hands are parting the curtain now.
local function reaching(character: Model): boolean
	local id = NationalsConfig.CurtainPartAnimationId
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if id == "" or animator == nil then
		return false
	end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		local animation = track.Animation
		if animation and animation.AnimationId == id then
			return true
		end
	end
	return false
end

local function step(dt: number)
	if Players.LocalPlayer:GetAttribute(NationalsConfig.InHallAttribute) == nil then
		return
	end
	for _, split in pairs(splits) do
		if #split.flaps == 0 then
			continue
		end
		-- How open (0..1) and which way the bottoms trail (-1..1), from the nearest body in the split's way.
		local open, trail = 0, 0
		local bodies: { Model } = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then
				table.insert(bodies, player.Character)
			end
		end
		for _, figure in ipairs(CollectionService:GetTagged(NationalsConfig.CurtainWalkerTag)) do
			if figure:IsA("Model") then
				table.insert(bodies, figure)
			end
		end
		for _, character in ipairs(bodies) do
			local root = character:FindFirstChild("HumanoidRootPart")
			if character == nil or root == nil or not root:IsA("BasePart") then
				continue
			end
			local offset = root.Position - split.at
			local across = offset:Dot(split.toStage)
			local side = math.abs(offset:Dot(split.along))
			if math.abs(across) > NEAR or side > SETTINGS.SideReach or math.abs(offset.Y) > 8 then
				split.lastAcross[character] = nil
				continue
			end
			local from = if reaching(character) then SETTINGS.OpenFromReaching else SETTINGS.OpenFrom
			local share = math.clamp(1 - (math.abs(across) - 0.3) / (from - 0.3), 0, 1)
			local last = split.lastAcross[character]
			split.lastAcross[character] = across
			if share > open then
				open = share
				if last then
					local moving = across - last
					if math.abs(moving) > 1e-3 then
						split.moving = math.sign(moving)
					end
				end
				trail = split.moving * share
			end
		end
		local widest = 0
		for _, flap in ipairs(split.flaps) do
			local swingTo = math.rad(SETTINGS.SwingDegrees) * open
			local tiltTo = math.rad(SETTINGS.TiltDegrees) * trail
			local rate = if swingTo > flap.swing then SETTINGS.FollowRate else SETTINGS.SettleRate
			local k = math.min(1, rate * dt)
			local swing = flap.swing + (swingTo - flap.swing) * k
			local tilt = flap.tilt + (tiltTo - flap.tilt) * k
			if math.abs(swing) < 1e-4 and math.abs(tilt) < 1e-4 and open == 0 then
				swing, tilt = 0, 0
			end
			if swing ~= flap.swing or tilt ~= flap.tilt then
				flap.swing, flap.tilt = swing, tilt
				local turn = CFrame.fromAxisAngle(flap.swingAxis, swing) * CFrame.fromAxisAngle(flap.tiltAxis, tilt)
				flap.part.CFrame = CFrame.new(flap.hinge) * turn * CFrame.new(-flap.hinge) * flap.rest
			end
			widest = math.max(widest, flap.swing)
		end
		-- The light's line in the split shows only while it is closed.
		local shut = widest < math.rad(0.4)
		for _, glow in ipairs(split.glows) do
			glow.LocalTransparencyModifier = if shut then 0 else 1
		end
	end
end

function NationalsCurtains.start()
	if started then
		return
	end
	started = true
	for _, part in ipairs(CollectionService:GetTagged(NationalsConfig.CurtainFlapTag)) do
		addFlap(part)
	end
	for _, part in ipairs(CollectionService:GetTagged(NationalsConfig.CurtainGlowTag)) do
		addGlow(part)
	end
	CollectionService:GetInstanceAddedSignal(NationalsConfig.CurtainFlapTag):Connect(addFlap)
	CollectionService:GetInstanceAddedSignal(NationalsConfig.CurtainGlowTag):Connect(addGlow)
	CollectionService:GetInstanceRemovedSignal(NationalsConfig.CurtainFlapTag):Connect(prune)
	CollectionService:GetInstanceRemovedSignal(NationalsConfig.CurtainGlowTag):Connect(prune)
	RunService.RenderStepped:Connect(step)
end

return NationalsCurtains
