--!strict
--[[
	MeetCeremony
	Server / Meet

	THE PODIUM CEREMONY (GAME_DESIGN §40.5 "The podium ceremony", user 2026-11-25, the line 2026-11-26): the top 3 wait
	in a LINE beside the podium facing the referee (user: "The 1st, second, 3rd winner should be in line, in front the
	ref, facing the ref, then the lifters one bye one get their medal and handshake"; they walked there at the end of
	the coach scene, MeetEndScene), 3rd at the front, then 2nd, then 1st. One by one the front of the line steps up to
	the referee, who puts a MEDAL over their neck (Local and Regional; 2nd and 3rd at State and Nationals) or hands 1st
	the TROPHY (State and Nationals); they shake hands; the referee steps aside, the lifter walks along the podium's
	front to their block, hops up and turns to the crowd, and the line steps forward. On the floor because the blocks
	(1.4-3 studs high) are too high for a referee to reach a neck. Everything here comes from CeremonyConfig (generated
	from the Blender work: medal offsets per build, the clips, their times, where the referee stands) and
	LocalMeetConfig.MeetEnd.Line (where the line stands: lineSpots).

	The referee is a MeetFigures "Referee" built for the ceremony and removed after it. The held medal follows the
	referee's two fists every frame (between his grips, art/scripts/ceremony_animations.py), swapped for the opened loop
	while it goes over the head, then for the worn medal welded to the lifter's UpperTorso. A computer lifter goes
	through it too. Kept out of LocalMeetService (its main chunk is at Luau's 200-local limit).
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local CeremonyConfig = require(ConfigFolder:WaitForChild("CeremonyConfig"))
local LocalMeetConfig = require(ConfigFolder:WaitForChild("LocalMeetConfig"))
local StarterGymConfig = require(ConfigFolder:WaitForChild("StarterGymConfig"))

local ComputerLifters = require(script.Parent:WaitForChild("ComputerLifters"))
local MeetChalk = require(script.Parent:WaitForChild("MeetChalk"))
local MeetFigures = require(script.Parent:WaitForChild("MeetFigures"))
local Trophies = require(script.Parent:WaitForChild("Trophies"))

local T = CeremonyConfig.Times
local FALLBACK_BUILD = "Fit"
local TURN_SECONDS = 0.35

local MeetCeremony = {}

export type Entry = { model: Model, place: number, lifter: any? }
-- `notify(data)` tells everyone in the hall what the camera should show (LocalMeetRemotes.SCENE: "Ceremony" with the
-- gold block's top, "CeremonyFocus" with who is being called up and the referee, "CeremonyEnd").
export type Args = { lifters: { Entry }, podiumSpots: { CFrame }, level: string, stillOn: () -> boolean,
	notify: ((any) -> ())? }

-- ---------------------------------------------------------------- the medal's pieces

local templates: { [string]: BasePart } = {}
local loaded = false

local function loadPieces()
	if loaded then
		return
	end
	loaded = true
	for name, id in pairs(CeremonyConfig.MedalAssets) do
		local ok, problem = pcall(function()
			local model = InsertService:LoadAsset(id)
			local part = model:FindFirstChild(name, true) or model:FindFirstChildWhichIsA("BasePart", true)
			assert(part and part:IsA("BasePart"), "no part in " .. name)
			part.Parent = nil
			templates[name] = part
			model:Destroy()
		end)
		if not ok then
			warn("[MeetCeremony] the medal piece " .. name .. " did not load: " .. tostring(problem))
		end
	end
end

local function paint(part: BasePart, paintName: string)
	local paints = StarterGymConfig.PropPaints :: any
	local p = paints[paintName]
	if p then
		part.Color = p.color
		part.Material = p.material or Enum.Material.SmoothPlastic
	end
end

local function piece(name: string, paintName: string, parent: Instance): BasePart?
	local template = templates[name]
	if template == nil then
		return nil
	end
	local part = template:Clone()
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	paint(part, paintName)
	part.Parent = parent
	return part
end

-- ---------------------------------------------------------------- bodies

local function buildOf(model: Model): string
	local build = model:GetAttribute("LifterBodyBuild")
	return if typeof(build) == "string" and CeremonyConfig.Worn[build] then build else FALLBACK_BUILD
end

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function standingHeight(model: Model): number
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = rootOf(model)
	if humanoid == nil or root == nil then
		return 3
	end
	return humanoid.HipHeight + root.Size.Y / 2
end

-- Stands `model` with its feet at `spot` (a floor CFrame), held still.
local function setFloor(model: Model, spot: CFrame)
	local root = rootOf(model)
	if root then
		root.Anchored = true
	end
	model:PivotTo(spot * CFrame.new(0, standingHeight(model), 0))
end

local function floorOf(model: Model): CFrame
	return model:GetPivot() * CFrame.new(0, -standingHeight(model), 0)
end

local function play(model: Model, id: string?): AnimationTrack?
	if id == nil or id == "" then
		return nil
	end
	local track = MeetChalk.play(model, id)
	if track then
		track.Looped = false
	end
	return track
end

-- Turns `model` on the spot to face `toward` over TURN_SECONDS.
local function turnTo(model: Model, toward: Vector3, going: () -> boolean)
	local from = floorOf(model)
	local flat = Vector3.new(toward.X - from.X, 0, toward.Z - from.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	local target = CFrame.lookAt(from.Position, from.Position + flat)
	local started = os.clock()
	while going() do
		local u = math.clamp((os.clock() - started) / TURN_SECONDS, 0, 1)
		setFloor(model, from:Lerp(target, u * u * (3 - 2 * u)))
		if u >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
end

local function waitUntil(clock: number, going: () -> boolean)
	while going() and os.clock() < clock do
		RunService.Heartbeat:Wait()
	end
end

-- Where a hand's grip hole is (the medal's hold point): CeremonyConfig.GripFromWrist off its WristRigAttachment.
local function gripOf(figure: Model, side: string): Vector3?
	local hand = figure:FindFirstChild(side .. "Hand")
	local wrist = hand and hand:FindFirstChild(side .. "WristRigAttachment")
	if wrist == nil or not wrist:IsA("Attachment") then
		return nil
	end
	local offset = CeremonyConfig.GripFromWrist
	local sign = if side == "Left" then 1 else -1
	return (wrist.WorldCFrame * CFrame.new(offset.X * sign, offset.Y, offset.Z)).Position
end

-- ---------------------------------------------------------------- the medal

--[[
	The referee puts the medal on: the held ribbon (with disc and text) between his fists every frame, the opened loop
	while it goes over the head, the worn medal on the lifter from MedalOnNeck. Returns the worn pieces.
]]
local function placeMedal(referee: Model, lifter: Model, place: number, folder: Instance, going: () -> boolean): { BasePart }
	local paints = CeremonyConfig.MedalPaints[place] or CeremonyConfig.MedalPaints[1]
	local held = piece("HeldMedal_Ribbon", paints.Ribbon, folder)
	local open = piece("HeldMedal_Open", paints.Ribbon, folder)
	local disc = piece("WornMedal_Disc", paints.Disc, folder)
	local text = piece("WornMedal_Text", paints.Text, folder)
	if open then
		open.Transparency = 1
	end
	local refTrack = play(referee, CeremonyConfig.Animations.RefPlaceMedal)
	play(lifter, CeremonyConfig.Animations.LifterReceiveMedal)
	local started = os.clock()
	local worn: { BasePart } = {}
	local wornAt = started + T.MedalOnNeck
	local beat = RunService.Heartbeat:Connect(function()
		local t = os.clock() - started
		local left, right = gripOf(referee, "Left"), gripOf(referee, "Right")
		if left == nil or right == nil or held == nil then
			return
		end
		local useOpen = open ~= nil and t >= T.MedalOpenFrom and t < T.MedalOpenTo
		local spec = if useOpen then CeremonyConfig.HeldOpen else CeremonyConfig.Held
		local x = (left - right).Unit
		local y = (Vector3.yAxis - x * Vector3.yAxis:Dot(x)).Unit
		local rotation = CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y))
		local frame = CFrame.new((left + right) / 2) * rotation * CFrame.new(-spec.holdMidpoint)
		held.Transparency = if useOpen then 1 else 0
		if open then
			open.Transparency = if useOpen then 0 else 1
			open.CFrame = frame
		end
		if not useOpen then
			held.CFrame = frame
		end
		if disc then
			disc.CFrame = frame * CFrame.new(spec.Disc)
		end
		if text then
			text.CFrame = frame * CFrame.new(spec.Text)
		end
	end)
	waitUntil(wornAt, going)
	beat:Disconnect()
	for _, part in ipairs({ held, open, disc, text }) do
		if part then
			part:Destroy()
		end
	end
	-- On the neck: each piece welded to the UpperTorso at its build's offset.
	local torso = lifter:FindFirstChild("UpperTorso")
	local offsets = CeremonyConfig.Worn[buildOf(lifter)]
	if torso and torso:IsA("BasePart") and offsets then
		for _, spec in ipairs({ { "WornMedal_Disc", paints.Disc, offsets.Disc }, { "WornMedal_Text", paints.Text, offsets.Text },
			{ "WornMedal_Ribbon_" .. buildOf(lifter), paints.Ribbon, offsets.Ribbon } }) do
			local part = piece(spec[1], spec[2], lifter)
			if part then
				part.Anchored = false
				part.CFrame = torso.CFrame * spec[3]
				local weld = Instance.new("Weld")
				weld.Part0 = torso
				weld.Part1 = part
				weld.C0 = spec[3]
				weld.Parent = part
				table.insert(worn, part)
			end
		end
	end
	waitUntil(started + T.MedalLength, going)
	MeetChalk.stop(refTrack)
	return worn
end

-- ---------------------------------------------------------------- the trophy

-- Welds every part of `model` to `hand` so its pivot sits at `pivot` (world) now.
local function weldTo(model: Model, hand: BasePart, pivot: CFrame)
	for _, weld in ipairs(model:GetDescendants()) do
		if weld:IsA("Weld") and weld.Name == "CeremonyHold" then
			weld:Destroy()
		end
	end
	local old = model:GetPivot()
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local inModel = old:ToObjectSpace(part.CFrame)
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
			part.CFrame = pivot * inModel
			local weld = Instance.new("Weld")
			weld.Name = "CeremonyHold"
			weld.Part0 = hand
			weld.Part1 = part
			weld.C0 = hand.CFrame:ToObjectSpace(pivot * inModel)
			weld.Parent = part
		end
	end
end

local function handTrophy(referee: Model, lifter: Model, place: number, going: () -> boolean): Model?
	local trophy = Trophies.copy(place)
	local refHand = referee:FindFirstChild("RightHand")
	local refWrist = refHand and refHand:FindFirstChild("RightWristRigAttachment")
	if trophy == nil or refHand == nil or not refHand:IsA("BasePart") or refWrist == nil or not refWrist:IsA("Attachment") then
		return nil
	end
	trophy.Parent = referee
	weldTo(trophy, refHand, refWrist.WorldCFrame * CeremonyConfig.TrophyInRefHand)
	local refTrack = play(referee, CeremonyConfig.Animations.RefHandTrophy)
	play(lifter, CeremonyConfig.TakeTrophy[buildOf(lifter)])
	local started = os.clock()
	waitUntil(started + T.TrophyTaken, going)
	local hand = lifter:FindFirstChild("RightHand")
	local wrist = hand and hand:FindFirstChild("RightWristRigAttachment")
	if hand and hand:IsA("BasePart") and wrist and wrist:IsA("Attachment") then
		trophy.Parent = lifter
		weldTo(trophy, hand, wrist.WorldCFrame * CeremonyConfig.TrophyInLifterHand[buildOf(lifter)])
	end
	waitUntil(started + T.TrophyLength, going)
	MeetChalk.stop(refTrack)
	return trophy
end

-- ---------------------------------------------------------------- the hop

-- The root's (up, forward) at `t` into Ceremony_Lifter_StepUp (ceremony_animations.py step_arc).
local function stepArc(t: number, h: number, fwd: number): (number, number)
	if t <= T.StepLaunch then
		return 0, 0
	end
	if t >= T.StepLand then
		return h, fwd
	end
	local u = (t - T.StepLaunch) / (T.StepLand - T.StepLaunch)
	local up = h * u + 4 * (0.45 * h) * u * (1 - u)
	local f = math.clamp((u - 0.2) / 0.8, 0, 1)
	return up, fwd * f * f * (3 - 2 * f)
end

local function hopUp(lifter: Model, from: CFrame, top: CFrame, going: () -> boolean)
	local h = top.Position.Y - from.Position.Y
	local fwd = Vector3.new(top.Position.X - from.Position.X, 0, top.Position.Z - from.Position.Z).Magnitude
	play(lifter, CeremonyConfig.Animations.LifterStepUp)
	local started = os.clock()
	while going() do
		local t = os.clock() - started
		local up, ahead = stepArc(t, h, fwd)
		setFloor(lifter, from * CFrame.new(0, up, -ahead))
		if t >= T.StepLength then
			break
		end
		RunService.Heartbeat:Wait()
	end
end

-- ---------------------------------------------------------------- the line

export type LineSpots = { refAt: CFrame, slots: { CFrame }, crowd: Vector3, floorY: number, middle: Vector3 }

--[[
	Where the line for the podium stands (LocalMeetConfig.MeetEnd.Line), from the gold block's top `gold` (facing the
	crowd): the referee's spot (facing the line) and the line's places, front (1) to back (3), each facing him. On the
	bronze block's side of the podium, on the floor.
]]
function MeetCeremony.lineSpots(gold: CFrame): LineSpots
	local L = LocalMeetConfig.MeetEnd.Line
	local floorY = gold.Position.Y - 3 -- (the gold block is 3 studs high: build_local_meet_01.py)
	local middle = Vector3.new(gold.Position.X, floorY, gold.Position.Z)
	local crowd = Vector3.new(gold.LookVector.X, 0, gold.LookVector.Z).Unit
	local along = -Vector3.new(gold.RightVector.X, 0, gold.RightVector.Z).Unit -- toward the bronze block and past it
	local ref = middle + along * L.RefOut + crowd * L.LineIn
	local slots: { CFrame } = {}
	for k = 1, 3 do
		local at = ref + along * (L.FirstGap + L.SlotGap * (k - 1))
		slots[k] = CFrame.lookAt(at, at - along)
	end
	return { refAt = CFrame.lookAt(ref, ref + along), slots = slots, crowd = crowd, floorY = floorY, middle = middle }
end

-- ---------------------------------------------------------------- the ceremony

--[[
	Runs the ceremony for `args.lifters` (each ends on their place's block, podiumSpots[place]: the block's top, facing
	the crowd). Returns when they all stand on their blocks, and a clean-up that takes the medals, trophies and the
	referee away (called after the awards' moment).
]]
function MeetCeremony.run(args: Args): () -> ()
	loadPieces()
	local folder = Instance.new("Folder")
	folder.Name = "MeetCeremony"
	folder.Parent = Workspace
	local made: { Instance } = { folder }
	local going = args.stillOn
	local gold = args.podiumSpots[1]
	if gold == nil then
		return function()
			folder:Destroy()
		end
	end
	local line = MeetCeremony.lineSpots(gold)
	local floorY = line.floorY
	local crowd = gold.LookVector -- the blocks face the crowd
	local L = LocalMeetConfig.MeetEnd.Line
	local refHome = line.refAt
	local _, referee = MeetFigures.build(folder, "Referee", refHome.Position, refHome.Position + refHome.LookVector)
	local trophyWins = args.level == "State" or args.level == "Nationals"
	local notify = args.notify or function(_: any) end

	local order = table.clone(args.lifters)
	table.sort(order, function(a, b)
		return a.place > b.place -- 3rd, 2nd, 1st
	end)
	-- Everyone in their place in the line before the camera cuts in (they walked there in the coach scene; anyone
	-- who didn't, e.g. no player had a scene, is put there now, off camera).
	for index, entry in ipairs(order) do
		local slot = line.slots[index]
		if slot and entry.model.Parent and (floorOf(entry.model).Position - slot.Position).Magnitude > 1.5 then
			ComputerLifters.moveBody(entry.model, slot)
			setFloor(entry.model, slot)
		end
	end
	notify({ kind = "Ceremony", gold = gold, line = line.slots[1], seconds = 13 * #args.lifters + 6 })
	task.wait(0.8)

	for index, entry in ipairs(order) do
		local top = args.podiumSpots[entry.place]
		local lifter = entry.model
		if top == nil or lifter.Parent == nil or not going() then
			continue
		end
		-- The front of the line steps up to the referee (its build's medal reach in front of him), facing him.
		local build = buildOf(lifter)
		local trophy = trophyWins and entry.place == 1
		local spot = if trophy then CeremonyConfig.Place.Trophy else (CeremonyConfig.Place.Medal :: any)[build]
		local awardAt = (refHome * CFrame.new(spot.x, 0, -spot.d)).Position
		local awardSpot = CFrame.lookAt(awardAt, awardAt - refHome.LookVector)
		notify({ kind = "CeremonyFocus", lifter = lifter, referee = referee })
		ComputerLifters.walkBody(lifter, {}, awardSpot, going)
		setFloor(lifter, awardSpot)
		-- The block it goes up onto: from in front of its face, facing it.
		local faceZ = top.Position + crowd * 2.5
		local hopFrom = CFrame.lookAt(Vector3.new(faceZ.X, floorY, faceZ.Z) + crowd * CeremonyConfig.StepFromFace,
			Vector3.new(top.Position.X, floorY, top.Position.Z))
		if referee then
			local refAt = awardSpot * CFrame.new(spot.x, 0, -spot.d) * CFrame.Angles(0, math.pi, 0)
			ComputerLifters.walkBody(referee, {}, refAt, going)
			setFloor(referee, refAt)
			if trophy then
				local cup = handTrophy(referee, lifter, entry.place, going)
				if cup then
					table.insert(made, cup)
				end
			else
				for _, part in ipairs(placeMedal(referee, lifter, entry.place, folder, going)) do
					table.insert(made, part)
				end
			end
			-- The handshake: half a step to its own spot first.
			local shake = (CeremonyConfig.Place.Handshake :: any)[build] or { x = 0.35, d = 3.45 }
			local shakeAt = awardSpot * CFrame.new(shake.x, 0, -shake.d) * CFrame.Angles(0, math.pi, 0)
			local before = floorOf(referee)
			local started = os.clock()
			while going() and os.clock() - started < 0.4 do
				setFloor(referee, before:Lerp(shakeAt, (os.clock() - started) / 0.4))
				RunService.Heartbeat:Wait()
			end
			setFloor(referee, shakeAt)
			local refShake = play(referee, CeremonyConfig.Animations.RefHandshake)
			play(lifter, CeremonyConfig.Animations.LifterHandshake)
			waitUntil(os.clock() + T.HandshakeLength, going)
			MeetChalk.stop(refShake)
			-- The referee steps aside (toward the platforms, still facing the line) to let them by.
			local aside = refHome.Position - line.crowd * L.RefStepBack
			task.spawn(ComputerLifters.walkBody, referee, {}, CFrame.lookAt(aside, aside + refHome.LookVector), going)
		end
		-- Out toward the crowd, along the podium's front to their block, up onto it and round to the crowd; the line
		-- steps forward behind them.
		notify({ kind = "CeremonyFocus", lifter = lifter, referee = nil })
		-- (a point's place on the strip StripOut in front of the podium's middle, toward the crowd)
		local function onStrip(at: Vector3): Vector3
			local flat = Vector3.new(at.X, floorY, at.Z)
			return flat + line.crowd * (L.StripOut - (flat - line.middle):Dot(line.crowd))
		end
		local out = onStrip(floorOf(lifter).Position)
		local strip = onStrip(hopFrom.Position)
		task.delay(0.7, function()
			for behind = index + 1, #order do
				local waiting = order[behind]
				local to = line.slots[behind - index]
				if waiting.model.Parent and to and going() then
					task.spawn(ComputerLifters.walkBody, waiting.model, {}, to, going)
				end
			end
		end)
		ComputerLifters.walkBody(lifter, { out, strip }, hopFrom, going)
		setFloor(lifter, hopFrom)
		hopUp(lifter, hopFrom, CFrame.lookAt(top.Position, top.Position + (top.Position - hopFrom.Position) * Vector3.new(1, 0, 1)), going)
		turnTo(lifter, top.Position + crowd * 10, going)
		setFloor(lifter, top)
		-- (the referee back in his place for the next)
		if referee and index < #order then
			ComputerLifters.walkBody(referee, {}, refHome, going)
			setFloor(referee, refHome)
		end
	end
	notify({ kind = "CeremonyEnd" })
	return function()
		for _, thing in ipairs(made) do
			thing:Destroy()
		end
	end
end

return MeetCeremony
