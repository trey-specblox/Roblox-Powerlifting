--!strict
--[[
	SuitCutscene
	Client / Meet

	The coach's cutscene when a player wins a rare suit at a meet (GAME_DESIGN §35.12, user 2026-11-06), played out as a scene:

		the win comes, and all the screen's UI disappears at once
		one fixed shot from then to the end: the coach walks in carrying the suit in both hands
		the coach hands it over: the player's hands come up and take hold of it, the coach's let go, the big sound
		nothing moves on: the two stay as they are, the coach looking at the player, and the dialogue pops up over the shot
		with a big portrait of the coach, their name and their words:
			"You should use this..."
			"Let me see you try it on. I have to know if you can handle it."
		then the answers: "Let's do it." (GearRemotes.START_TEST: the server checks it and moves the player to the test) or
		"Not yet." (MY GEAR has the same button). The suit stays locked until the test is passed.

	Hands really hold the suit: each hand is pulled by an IKControl onto a grip point on it (attachments on the suit), so the arms
	follow it whatever size the player's body is.

	Everything in the scene is a copy only this player sees: the coach, the portrait, the suit, and the player held still. Display
	only: the suit is already saved when this starts. Whatever goes wrong, the player gets their screen and camera back.

	Also plays the big sound when a test is passed.

	PERFORMANCE: two figures of about 16 parts (one drawn in the portrait) and one suit (about 20 pieces, up to 10,000 triangles),
	four IK arms, for about 15 seconds, on the winner's screen only. All destroyed after.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local GearStatsConfig = require(ConfigFolder:WaitForChild("GearStatsConfig"))
local ShopConfig = require(ConfigFolder:WaitForChild("ShopConfig"))
local WornGearConfig = require(ConfigFolder:WaitForChild("WornGearConfig"))
local EconomyFolder = Shared:WaitForChild("Economy")
local GearRemotes = require(EconomyFolder:WaitForChild("GearRemotes"))
local GearStats = require(EconomyFolder:WaitForChild("GearStats"))
local ShopRemotes = require(EconomyFolder:WaitForChild("ShopRemotes"))

local UIFolder = script.Parent.Parent:WaitForChild("UI")
local UIStyle = require(UIFolder:WaitForChild("UIStyle"))
local C = UIStyle.Colours

local SuitCutscene = {}

local LINE_ONE = "You should use this..."
local LINE_TWO = "Let me see you try it on. I have to know if you can handle it."
local LETTER_SECONDS = 0.035
local PAUSE_AFTER_LINE = 1.1
-- How far off the coach starts and how far from the player they stop, in studs, and their walking speed. They stop close enough
-- for both pairs of hands to reach the suit.
local COACH_START = 16
local COACH_MIN_START = 7
local COACH_STOP = 4
local WALK_SPEED = 4.5
-- The suit: how far ahead of whoever holds it, how high its middle is above their root, and how much it turns toward the camera.
local CARRY_AHEAD = 2
local KEEP_AHEAD = 1.5
local HOLD_UP = 0.1
local SUIT_TURN = math.rad(40)
local SUIT_SCALE = 0.9
local PRELOAD_SECONDS = 2
-- Where hands grip it, from its middle: up, out to each side (no further than the sleeves), and to the holder's side of its middle.
local GRIP_UP = 0.2
local GRIP_MOST_OUT = 1.2
local GRIP_DEPTH = 0.25
local REACH_SECONDS = 0.45
local LET_GO_SECONDS = 0.35
local HANDOVER_SECONDS = 0.5
-- The one shot: from how far (it stops short of anything in the way), how far round from side-on toward the coach's back, its
-- lens and how low it looks. The player's back falls just past the answers' right edge and the width of the two figures (the
-- first in the dialogue's sizes, the second in screen heights), or as far right as this, leaving the left for the dialogue.
local CAMERA_BACK = 13
local CAMERA_MIN_BACK = 5
local CAMERA_TURN = math.rad(15)
local CAMERA_LENS = 50
local CAMERA_DROP = 0.1
local ANSWERS_RIGHT_EDGE = 995
local FIGURES_WIDTH = 0.55
local PLAYER_MOST_ACROSS = 0.92
-- How long the answers wait before it counts as "Not yet".
local ANSWER_SECONDS = 40
-- Roblox's own R15 walk and stand. The arms forward are the bench shirt's, for a body with no hands to grip with.
local WALK_ANIMATION = "rbxassetid://507777826"
local STAND_ANIMATION = "rbxassetid://507766388"

local started = false

-- Loads and plays an animation on a body, or nil if it can't.
local function playOn(model: Model, id: string, priority: Enum.AnimationPriority): AnimationTrack?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
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
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if not ok then
		return nil
	end
	track.Priority = priority
	track.Looped = true
	track:Play(0.2)
	return track
end

-- A copy of the suit to carry: its worn pieces in this look's colours, without the menus' stand-in body. Pivot in its middle.
local function suitCopy(look: ShopConfig.Item): Model?
	local previews = ReplicatedStorage:FindFirstChild(ShopRemotes.PREVIEWS_NAME)
	local template = previews and previews:FindFirstChild(look.model)
	if template == nil or not template:IsA("Model") then
		return nil
	end
	local copy = template:Clone()
	for _, part in ipairs(copy:GetDescendants()) do
		if part:IsA("BasePart") then
			local key = string.match(part.Name, "_(%a+)$")
			if key == "StandIn" then
				part:Destroy()
			else
				local colour = key and look.colours[key]
				if colour then
					part.Color = colour
				end
			end
		end
	end
	local middle = copy:GetBoundingBox()
	copy.WorldPivot = middle
	copy:ScaleTo(SUIT_SCALE)
	-- Its meshes loaded before the scene needs them (a first use can take a moment), but the scene waits no more than a moment.
	local ready = false
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ copy })
		end)
		ready = true
	end)
	local deadline = os.clock() + PRELOAD_SECONDS
	while not ready and os.clock() < deadline do
		task.wait(0.05)
	end
	return copy
end

-- A copy of the coach, with no name tag and nothing in their hands.
local function coachCopy(): Model
	local folder = ReplicatedStorage:WaitForChild(GearRemotes.COACH_FIGURE, 10)
	local template = folder and folder:FindFirstChild("Coach")
	if template == nil or not template:IsA("Model") then
		error("no coach figure")
	end
	local copy = template:Clone()
	for _, child in ipairs(copy:GetChildren()) do
		if string.sub(child.Name, 1, 9) == "Clipboard" then
			child:Destroy()
		end
	end
	for _, part in ipairs(copy:GetDescendants()) do
		if part:IsA("BillboardGui") then
			part:Destroy()
		end
	end
	return copy
end

-- An arm that reaches for `target`, not at all until its Weight goes up. Nil on a body without hands.
local function armFor(body: Model, side: string, target: Attachment): IKControl?
	local humanoid = body:FindFirstChildOfClass("Humanoid")
	local upper = body:FindFirstChild(side .. "UpperArm")
	local hand = body:FindFirstChild(side .. "Hand")
	if humanoid == nil or upper == nil or hand == nil then
		return nil
	end
	local arm = Instance.new("IKControl")
	arm.Name = "SuitCutsceneGrip_" .. side
	arm.Type = Enum.IKControlType.Position
	arm.ChainRoot = upper
	arm.EndEffector = hand
	arm.Target = target
	arm.Weight = 0
	arm.Parent = humanoid
	return arm
end

local function setArms(arms: { IKControl }, weight: number, seconds: number)
	for _, arm in ipairs(arms) do
		if seconds <= 0 then
			arm.Weight = weight
		else
			TweenService:Create(arm, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Weight = weight }):Play()
		end
	end
end

-- Where the camera stands from the middle of the scene: side-on with the coach on the left and the player on the right, then
-- turned toward the coach's back, so the suit's front faces it. `way` points from the player to the coach.
local function cameraDirection(way: Vector3): Vector3
	return -way:Cross(Vector3.yAxis).Unit * math.cos(CAMERA_TURN) + way * math.sin(CAMERA_TURN)
end

function SuitCutscene.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remotes = GearRemotes.waitForClient(ReplicatedStorage)
	local playerGui = player:WaitForChild("PlayerGui")

	local bigSound = Instance.new("Sound")
	bigSound.SoundId = GearStatsConfig.Sounds.Big
	bigSound.Volume = 0.8
	bigSound.Parent = playerGui
	local tickSound = Instance.new("Sound")
	tickSound.SoundId = GearStatsConfig.Sounds.Tick
	tickSound.Volume = 0.25
	tickSound.Parent = playerGui

	remotes.suitTestPassed.OnClientEvent:Connect(function()
		bigSound:Play()
	end)

	-- ------------------------------------------------------------ the dialogue
	local gui = Instance.new("ScreenGui")
	gui.Name = "SuitCutscene"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 31
	gui.Enabled = false
	UIStyle.fitToScreen(gui)

	-- Who is talking: the panel and, on it, a portrait, in the lower left corner. The real coach stays in the scene behind.
	local SPEAKER_SIZE = 980
	local speakerAt = UDim2.new(0, SPEAKER_SIZE / 2, 1, -SPEAKER_SIZE / 2)
	local speaker = Instance.new("Frame")
	speaker.Name = "Speaker"
	speaker.AnchorPoint = Vector2.new(0.5, 0.5)
	speaker.Position = speakerAt
	speaker.Size = UDim2.fromOffset(SPEAKER_SIZE, SPEAKER_SIZE)
	speaker.BackgroundTransparency = 1
	speaker.ZIndex = 1
	speaker.Parent = gui
	local panel = Instance.new("ImageLabel")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundTransparency = 1
	panel.Image = GearStatsConfig.CutsceneArt.Panel
	panel.ZIndex = 1
	panel.Parent = speaker
	local portrait = Instance.new("ViewportFrame")
	portrait.Name = "Portrait"
	portrait.Size = UDim2.fromScale(1, 1)
	portrait.BackgroundTransparency = 1
	portrait.Ambient = Color3.fromRGB(170, 170, 170)
	portrait.LightColor = Color3.fromRGB(255, 250, 240)
	portrait.LightDirection = Vector3.new(-0.6, -1, 0.5)
	portrait.ZIndex = 2
	portrait.Parent = speaker
	local portraitWorld = Instance.new("WorldModel")
	portraitWorld.Parent = portrait
	local portraitCamera = Instance.new("Camera")
	portraitCamera.FieldOfView = 30
	-- Looks toward +Z at the coach (who faces -Z, turned to the screen's right), who stands left of the middle.
	portraitCamera.CFrame = CFrame.lookAt(Vector3.new(-0.95, 0.9, -11.5), Vector3.new(-0.95, 0.5, 0))
	portraitCamera.Parent = portrait
	portrait.CurrentCamera = portraitCamera

	-- The name on a black bar, and the words under it.
	local nameBar = UIStyle.frame(gui, "NameBar", UDim2.new(0, 0, 1, -172), UDim2.fromOffset(560, 52), C.ink)
	nameBar.BackgroundTransparency = 0.1
	nameBar.ZIndex = 2
	UIStyle.frame(nameBar, "Mark", UDim2.fromOffset(26, 8), UDim2.fromOffset(12, 36), C.yellow, 12)
	local who = UIStyle.text(nameBar, "Who", UDim2.fromOffset(60, 0), UDim2.new(1, -70, 1, 0), 34, C.white, UIStyle.heading())
	who.Text = "COACH"
	who.TextYAlignment = Enum.TextYAlignment.Center
	local words = UIStyle.text(gui, "Words", UDim2.new(0, 60, 1, -112), UDim2.fromOffset(1180, 100), 42, C.white, UIStyle.heading())
	words.TextStrokeColor3 = Color3.new(0, 0, 0)
	words.TextStrokeTransparency = 0
	words.TextYAlignment = Enum.TextYAlignment.Top
	words.TextWrapped = true
	words.ZIndex = 3

	-- An answer: a speech tab beside the portrait, its tail toward it.
	local answer: string? = nil
	local function bubble(name: string, text: string, y: number, turn: number, value: string): ImageButton
		local tab = Instance.new("ImageButton")
		tab.Name = name
		tab.AnchorPoint = Vector2.new(0.5, 0.5)
		tab.Position = UDim2.new(0, 760, 0.5, y)
		tab.Size = UDim2.fromOffset(470, 184)
		tab.Rotation = turn
		tab.BackgroundTransparency = 1
		tab.Image = GearStatsConfig.CutsceneArt.Bubble
		tab.Visible = false
		tab.ZIndex = 4
		tab.Parent = gui
		local label = UIStyle.text(tab, "Text", UDim2.new(0.2, 0, 0.14, 0), UDim2.new(0.68, 0, 0.58, 0), 38, C.white, UIStyle.heading())
		label.Text = text
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		tab.Activated:Connect(function()
			answer = value
		end)
		return tab
	end
	local yes = bubble("TakeTest", "Let's do it.", -170, -3, "Test")
	local no = bubble("Later", "Not yet.", 10, 2, "Later")
	gui.Parent = playerGui

	local function popIn(tab: ImageButton)
		local size = tab.Size
		tab.Size = UDim2.fromOffset(0, 0)
		tab.Visible = true
		TweenService:Create(tab, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = size }):Play()
	end

	local function say(text: string)
		words.Text = text
		words.MaxVisibleGraphemes = 0
		for shown = 1, #text do
			words.MaxVisibleGraphemes = shown
			if shown % 3 == 0 then
				tickSound:Play()
			end
			task.wait(LETTER_SECONDS)
		end
	end

	-- How far it is clear from a point along a flat direction, at head height, up to `reach`.
	local function roomFrom(from: Vector3, direction: Vector3, reach: number, character: Model): number
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local hit = workspace:Raycast(from + Vector3.new(0, 1.5, 0), direction * reach, params)
		return if hit then hit.Distance else reach
	end

	-- Which way the coach walks in from: the one with the most floor for the walk and for the camera, up to COACH_START.
	local function clearWay(root: BasePart, character: Model): (Vector3, number)
		local looks = root.CFrame
		local best, bestRoom, bestScore = Vector3.new(looks.LookVector.X, 0, looks.LookVector.Z).Unit, 0, -1
		for _, way in ipairs({ looks.LookVector, looks.RightVector, -looks.RightVector, -looks.LookVector }) do
			local flat = Vector3.new(way.X, 0, way.Z).Unit
			local room = roomFrom(root.Position, flat, COACH_START + 3, character) - 2
			local cameraRoom = roomFrom(root.Position + flat * (COACH_STOP / 2), cameraDirection(flat), CAMERA_BACK + 2, character)
			local score = math.min(room, COACH_START) + math.min(cameraRoom, CAMERA_BACK) * 2
			if score > bestScore then
				best, bestRoom, bestScore = flat, room, score
			end
		end
		return best, math.clamp(bestRoom, COACH_MIN_START, COACH_START)
	end

	-- ------------------------------------------------------------ the scene
	local function scene(news: GearRemotes.SuitCutsceneNews, look: ShopConfig.Item, character: Model, root: BasePart,
		cleanup: { () -> () }, hidden: { ScreenGui })
		local camera = workspace.CurrentCamera
		-- Made first, while the game still looks normal: it can take a moment to load.
		local suit = suitCopy(look)

		-- Everything off the screen, all at once.
		for _, other in ipairs(playerGui:GetChildren()) do
			if other:IsA("ScreenGui") and other.Enabled and other ~= gui then
				other.Enabled = false
				table.insert(hidden, other)
			end
		end

		-- Held still, on this screen only, facing the way the coach comes from.
		local wasAnchored = root.Anchored
		root.Anchored = true
		table.insert(cleanup, function()
			if root.Parent then
				root.Anchored = wasAnchored
			end
		end)
		local way, startDistance = clearWay(root, character)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + way)
		local playerAt = root.CFrame

		-- The coach, a long way off, on the player's floor whatever size the player is.
		local coach = coachCopy()
		table.insert(cleanup, function()
			coach:Destroy()
		end)
		local playerBody = character:FindFirstChildOfClass("Humanoid")
		local coachBody = coach:FindFirstChildOfClass("Humanoid")
		local coachRoot = coach:FindFirstChild("HumanoidRootPart")
		local coachHeight = playerAt.Position.Y
		if playerBody and coachBody and coachRoot and coachRoot:IsA("BasePart") then
			local floor = playerAt.Position.Y - playerBody.HipHeight - root.Size.Y / 2
			coachHeight = floor + coachBody.HipHeight + coachRoot.Size.Y / 2
		end
		local function coachAt(distance: number): CFrame
			local spot = playerAt.Position + way * distance
			spot = Vector3.new(spot.X, coachHeight, spot.Z)
			return CFrame.lookAt(spot, Vector3.new(playerAt.Position.X, coachHeight, playerAt.Position.Z))
		end
		coach:PivotTo(coachAt(startDistance))
		coach.Parent = workspace
		local walking = playOn(coach, WALK_ANIMATION, Enum.AnimationPriority.Movement)

		-- The suit in the coach's hands, its front turned toward the camera.
		local toCamera = cameraDirection(way)
		local front = (way * math.cos(SUIT_TURN) + -way:Cross(Vector3.yAxis).Unit * math.sin(SUIT_TURN)).Unit
		local function suitWith(holder: CFrame, ahead: number): CFrame
			local at = holder.Position + holder.LookVector * ahead + Vector3.new(0, HOLD_UP, 0)
			return CFrame.lookAt(at, at + front)
		end
		local coachArms: { IKControl } = {}
		local playerArms: { IKControl } = {}
		if suit then
			local made = suit
			made:PivotTo(suitWith(coachAt(startDistance), CARRY_AHEAD))
			made.Parent = workspace
			table.insert(cleanup, function()
				made:Destroy()
			end)
			local _, size = made:GetBoundingBox()
			local out = math.min(size.X / 2, GRIP_MOST_OUT)
			local base = made:FindFirstChildWhichIsA("BasePart", true)
			-- The suit's front is its -Z, the side toward the coach. Its +X is on the player's right and the coach's left.
			local function grip(name: string, x: number, z: number): Attachment
				local point = Instance.new("Attachment")
				point.Name = name
				point.Parent = base
				point.WorldCFrame = made:GetPivot() * CFrame.new(x, GRIP_UP, z)
				return point
			end
			for _, hold in ipairs({
				{ body = coach, side = "Left", x = out, z = -GRIP_DEPTH, into = coachArms },
				{ body = coach, side = "Right", x = -out, z = -GRIP_DEPTH, into = coachArms },
				{ body = character, side = "Right", x = out, z = GRIP_DEPTH, into = playerArms },
				{ body = character, side = "Left", x = -out, z = GRIP_DEPTH, into = playerArms },
			}) do
				local arm = armFor(hold.body, hold.side, grip(hold.side .. "Grip", hold.x, hold.z))
				if arm then
					table.insert(hold.into, arm)
					local made2 = arm
					table.insert(cleanup, function()
						made2:Destroy()
					end)
				end
			end
			setArms(coachArms, 1, 0)
		end

		-- The one shot, from the moment the UI goes. The lens is put back after.
		local oldLens = camera.FieldOfView
		local oldType = camera.CameraType
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = CAMERA_LENS
		table.insert(cleanup, function()
			camera.CameraType = if oldType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else oldType
			camera.FieldOfView = oldLens
		end)
		local middle = playerAt.Position + way * (COACH_STOP / 2)
		local room = roomFrom(middle, toCamera, CAMERA_BACK + 1, character) - 1
		local eye = middle + toCamera * math.clamp(room, CAMERA_MIN_BACK, CAMERA_BACK) + Vector3.new(0, 1, 0)
		-- Turned left of the player's back by just enough to put it there on this screen's shape.
		local backOfPlayer = playerAt.Position - way * 1.2 - eye
		local halfWidth = math.tan(math.rad(CAMERA_LENS / 2)) * camera.ViewportSize.X / camera.ViewportSize.Y
		local screen = camera.ViewportSize
		local across = math.min(PLAYER_MOST_ACROSS, (ANSWERS_RIGHT_EDGE * UIStyle.screenScale() + FIGURES_WIDTH * screen.Y) / screen.X)
		local turnLeft = math.atan((2 * across - 1) * halfWidth)
		local looking = CFrame.fromAxisAngle(Vector3.yAxis, turnLeft):VectorToWorldSpace(Vector3.new(backOfPlayer.X, 0, backOfPlayer.Z).Unit)
		local shot = CFrame.lookAt(eye, eye + looking - Vector3.new(0, CAMERA_DROP, 0))
		local loop = RunService.RenderStepped:Connect(function()
			camera.CFrame = shot
		end)
		table.insert(cleanup, function()
			loop:Disconnect()
		end)

		-- The walk.
		local walkFrom = os.clock()
		local walkSeconds = (startDistance - COACH_STOP) / WALK_SPEED
		while true do
			local u = math.min(1, (os.clock() - walkFrom) / walkSeconds)
			local at = coachAt(startDistance + (COACH_STOP - startDistance) * u)
			coach:PivotTo(at)
			if suit then
				suit:PivotTo(suitWith(at, CARRY_AHEAD))
			end
			if u >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		if walking then
			walking:Stop(0.25)
		end
		local standing = playOn(coach, STAND_ANIMATION, Enum.AnimationPriority.Idle)
		if standing then
			standing:Play(0.25)
		end
		task.wait(0.35)

		-- The handover: the player's hands come up and take hold, then the coach's let go and it comes in to the player.
		if #playerArms > 0 then
			setArms(playerArms, 1, REACH_SECONDS)
		else
			local raised = playOn(character, WornGearConfig.BenchShirtArmsAnimation, Enum.AnimationPriority.Action)
			if raised then
				local arms = raised
				table.insert(cleanup, function()
					arms:Stop(0.3)
				end)
			end
		end
		task.wait(REACH_SECONDS + 0.15)
		bigSound:Play()
		setArms(coachArms, 0, LET_GO_SECONDS)
		if suit then
			local from, to = suit:GetPivot(), suitWith(playerAt, KEEP_AHEAD)
			local began = os.clock()
			while true do
				local u = math.min(1, (os.clock() - began) / HANDOVER_SECONDS)
				suit:PivotTo(from:Lerp(to, u * u * (3 - 2 * u)))
				if u >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end
		end
		task.wait(0.35)

		-- The dialogue, over the same shot. A figure of the coach for the portrait, turned toward the answers.
		local face = coachCopy()
		table.insert(cleanup, function()
			face:Destroy()
		end)
		face:PivotTo(CFrame.Angles(0, math.rad(24), 0))
		face.Parent = portraitWorld
		local posing = playOn(face, STAND_ANIMATION, Enum.AnimationPriority.Idle)
		if posing then
			posing:Play(0)
		end
		words.Text = ""
		words.MaxVisibleGraphemes = -1
		yes.Visible, no.Visible = false, false
		answer = nil
		speaker.Position = speakerAt - UDim2.fromOffset(420, 0)
		gui.Enabled = true
		TweenService:Create(speaker, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = speakerAt }):Play()
		task.wait(0.25)
		say(LINE_ONE)
		task.wait(PAUSE_AFTER_LINE)
		say(LINE_TWO)
		popIn(yes)
		task.wait(0.12)
		popIn(no)

		-- Until they answer. A test the server refuses leaves the answers up, with its reason.
		local deadline = os.clock() + ANSWER_SECONDS
		while os.clock() < deadline do
			if answer == "Later" then
				break
			elseif answer == "Test" then
				answer = nil
				yes.Visible = false
				local ok, done, message = pcall(function()
					return remotes.startTest:InvokeServer(news.pieceId)
				end)
				if ok and done then
					break
				end
				yes.Visible = true
				words.MaxVisibleGraphemes = -1
				words.Text = if ok and typeof(message) == "string" then message else "That didn't go through. Try again."
			end
			task.wait(0.05)
		end
	end

	local playing = false
	local function play(news: GearRemotes.SuitCutsceneNews)
		local suit = GearStats.suit(news.suitId)
		local look = suit and ShopConfig.find(suit.look)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if playing or look == nil or character == nil or root == nil or not root:IsA("BasePart") then
			return
		end
		playing = true
		local cleanup: { () -> () } = {}
		local hidden: { ScreenGui } = {}
		local ok, problem = pcall(scene, news, look, character, root, cleanup, hidden)
		if not ok then
			warn("[SuitCutscene] " .. tostring(problem))
		end
		-- Whatever happened, everything comes back.
		gui.Enabled = false
		for index = #cleanup, 1, -1 do
			pcall(cleanup[index])
		end
		for _, other in ipairs(hidden) do
			if other.Parent then
				other.Enabled = true
			end
		end
		playing = false
	end

	remotes.suitCutscene.OnClientEvent:Connect(function(news: GearRemotes.SuitCutsceneNews)
		if typeof(news) == "table" and typeof(news.suitId) == "string" and typeof(news.pieceId) == "string" then
			task.spawn(play, news)
		end
	end)
end

return SuitCutscene
