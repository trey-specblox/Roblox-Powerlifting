--!strict
--[[
	KitchenScene
	Client / World

	The chef scene (GAME_DESIGN §40.7), played on the cooking player's own screen right after the chef takes their order
	(KitchenMenu calls play). THE W CHEWS SCENE (user 2026-11-21, replacing the scoop / carry / throw of the same day):

		1. the chef steps to the start button by his counter and slaps it with his open palm (Chef_ButtonPress,
		   art/scripts/chef_animations.py); the button goes down, its lamp blinks; "Alright, I'll handle this for you!"
		2. the bag (a cow from KitchenConfig.CowFrom steaks, more cows for huge cooks) falls out of the ceiling chute into
		   the grinder's tub
		3. the grinder churns and squirts the meat out of its outlet into the display bay, where the lifter's mountain of
		   meat grows under the YOUR MEAT sign
		4. the funnel over the bay draws it up in lumps; they run along the overhead trunk, down the branch over the
		   lifter's column of pans, and drop out of the nozzle onto the lifter's OWN pan, which bursts into steam as the
		   big steak appears
		5. in the background of the last shot the mafia boss cow walks on two legs through the EMPLOYEES ONLY door (a
		   small detail to make players curious; it plays once his model exists: KitchenModels.CowBoss)

	Everything here is local: copies of the shared props in ReplicatedStorage.KitchenModels, the camera, and this
	screen's own copy of the chef (the server's chef is hidden on this screen meanwhile); nobody else sees it, and the
	server's steak in the pan is only hidden from this player until the meat lands. About 17 seconds for one bag. It
	always plays the first time; after one full watch a SKIP button shows.

	PERFORMANCE: a few prop copies, one chef copy, two particle emitters and a camera, all removed when it ends.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))
local WChewsLayout = require(Shared:WaitForChild("Config"):WaitForChild("WChewsLayout"))

local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local UIFancy = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIFancy"))
local PromptController = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("PromptController"))
local KitchenBackDoor = require(script.Parent:WaitForChild("KitchenBackDoor"))

local KitchenScene = {}

local playing = false
-- Set by the SKIP button: every wait and move of the running scene stops at once (SKIP is raised through them).
local skipping = false
local SKIP = "KitchenScene skipped"
-- What the running scene changed on this screen and must put back when it ends (the button, the staff door).
local undo: { () -> () } = {}

-- Studio only: the workspace attribute StudioSceneSlow (a number above 1) plays the scene that many times slower, so
-- each shot can be checked in a picture.
local function slow(): number
	local value = Workspace:GetAttribute("StudioSceneSlow")
	if RunService:IsStudio() and typeof(value) == "number" and value > 1 and value < 20 then
		return value
	end
	return 1
end

local function wait(seconds: number)
	local finish = os.clock() + seconds * slow()
	while os.clock() < finish do
		if skipping then
			error(SKIP, 0)
		end
		task.wait(math.min(0.05, finish - os.clock()))
	end
end

local function prop(name: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("KitchenModels")
	local source = folder and folder:FindFirstChild(name)
	if source and source:IsA("Model") then
		local copy = source:Clone()
		for _, part in ipairs(copy:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
			end
		end
		return copy
	end
	return nil
end

-- Runs `step(share)` every frame for `seconds` (share 0 -> 1), eased.
local function animate(seconds: number, step: (number) -> (), style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	seconds *= slow()
	local started = os.clock()
	while true do
		if skipping then
			error(SKIP, 0)
		end
		local share = math.clamp((os.clock() - started) / seconds, 0, 1)
		step(TweenService:GetValue(share, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.InOut))
		if share >= 1 then
			return
		end
		RunService.RenderStepped:Wait()
	end
end

local function sound(id: string, volume: number, parent: Instance): Sound
	local made = Instance.new("Sound")
	made.SoundId = id
	made.Volume = volume
	made.Parent = parent
	made:Play()
	task.delay(4, function()
		made:Destroy()
	end)
	return made
end

-- A burst of little particles (meat bits or steam) at `at`, for `seconds`.
local function burst(at: Vector3, colour: Color3, speed: number, size: number, seconds: number, rate: number, direction: Vector3?)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.CFrame = if direction then CFrame.lookAt(at, at + direction) else CFrame.new(at)
	anchor.Parent = Workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(colour)
	emitter.Size = NumberSequence.new(size, size * 0.4)
	emitter.Speed = NumberRange.new(speed * 0.6, speed)
	emitter.SpreadAngle = Vector2.new(if direction then 18 else 180, if direction then 18 else 180)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Lifetime = NumberRange.new(0.5, 1.0)
	emitter.Acceleration = if direction then Vector3.new(0, -30, 0) else Vector3.new(0, 6, 0)
	emitter.Transparency = NumberSequence.new(0.1, 1)
	emitter.Rate = rate
	emitter.Parent = anchor
	task.delay(seconds, function()
		emitter.Enabled = false
	end)
	task.delay(seconds + 1.2, function()
		anchor:Destroy()
	end)
end

-- The chef's line, as the game's dialogue caption over the live scene (memory: dialogue GUI over the scene): his name on
-- a black bar and the words typed out at the bottom of the screen, for `seconds`. (A bubble made on this screen over his
-- head didn't show; Studio 2026-11-20.)
local function chefSays(_head: BasePart, text: string, seconds: number)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChefLine"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 32
	UIStyle.fitToScreen(gui)
	local C = UIStyle.Colours
	local bar = UIStyle.frame(gui, "NameBar", UDim2.new(0, 0, 1, -172), UDim2.fromOffset(420, 52), C.ink)
	bar.BackgroundTransparency = 0.1
	UIStyle.frame(bar, "Mark", UDim2.fromOffset(26, 8), UDim2.fromOffset(12, 36), C.yellow, 12)
	local who = UIStyle.text(bar, "Who", UDim2.fromOffset(60, 0), UDim2.new(1, -70, 1, 0), 34, C.white, UIStyle.heading())
	who.TextYAlignment = Enum.TextYAlignment.Center
	who.Text = "CHEF"
	local words = UIStyle.text(gui, "Words", UDim2.new(0, 60, 1, -112), UDim2.fromOffset(1180, 100), 42, C.white, UIStyle.heading())
	words.TextStrokeColor3 = Color3.new(0, 0, 0)
	words.TextStrokeTransparency = 0
	words.TextYAlignment = Enum.TextYAlignment.Top
	words.Text = text
	words.MaxVisibleGraphemes = 0
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	task.spawn(function()
		for shown = 1, #text do
			if gui.Parent == nil then
				return
			end
			words.MaxVisibleGraphemes = shown
			task.wait(0.03)
		end
	end)
	task.delay(seconds, function()
		gui:Destroy()
	end)
end

-- Hides (or shows) this player's own character on their screen (so it can't block the chef's shots).
local function hideCharacter(hidden: boolean)
	local character = Players.LocalPlayer.Character
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") or part:IsA("Decal") then
				(part :: any).LocalTransparencyModifier = if hidden then 1 else 0
			end
		end
	end
end

-- Hides (or shows) the server's steak in the pan for this player only.
local function hideSteak(zone: Model?, hidden: boolean)
	local steak = zone and zone:FindFirstChild("Steak")
	if steak then
		for _, part in ipairs(steak:GetDescendants()) do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = if hidden then 1 else 0
			end
		end
	end
end

-- Holds the player still during the scene (this game has no standard PlayerModule to switch off): walking and
-- jumping set to zero on this client's own character, and put back after.
local held: { walk: number, jump: number, height: number }? = nil
local function controls(enabled: boolean)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	if not enabled then
		held = held or { walk = humanoid.WalkSpeed, jump = humanoid.JumpPower, height = humanoid.JumpHeight }
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	elseif held then
		humanoid.WalkSpeed = held.walk
		humanoid.JumpPower = held.jump
		humanoid.JumpHeight = held.height
		held = nil
	end
end

-- Runs `job` beside the scene; a skip just stops it.
local function beside(job: (...any) -> (), ...: any)
	local args = table.pack(...)
	task.spawn(function()
		local ok, problem = pcall(job, table.unpack(args, 1, args.n))
		if not ok and problem ~= SKIP then
			warn("[KitchenScene] " .. tostring(problem))
		end
	end)
end

-- The SKIP button (the UI kit's glossy button), bottom right, for players who have watched the scene once.
local function skipButton(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChefSceneSkip"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 33
	gui.IgnoreGuiInset = true
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 1)
	holder.Position = UDim2.new(1, -28, 1, -28)
	holder.Size = UDim2.fromOffset(190, 64)
	holder.Parent = gui
	UIFancy.button(holder, "Skip", "SKIP  >>", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1),
		Color3.fromRGB(255, 214, 64), Color3.fromRGB(235, 150, 20), 30, function()
			skipping = true
		end)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

-- A copy of the chef on this screen only, to play his scene moves on (the server's chef is hidden here meanwhile): no
-- prompts, tags or collisions, so nothing else in the game reacts to it. Returns it with its root and loaded tracks.
local function chefCopy(chef: Model): (Model?, BasePart?, { [string]: AnimationTrack })
	local tracks: { [string]: AnimationTrack } = {}
	local copy = chef:Clone()
	if copy == nil then
		return nil, nil, tracks
	end
	local items = copy:GetDescendants()
	for _, item in ipairs(items) do
		if item:IsA("ProximityPrompt") or item:IsA("BaseScript") then
			item:Destroy()
		else
			for _, tag in ipairs(item:GetTags()) do
				item:RemoveTag(tag)
			end
			if item:IsA("BasePart") then
				item.CanCollide = false
				item.CanQuery = false
				item.CanTouch = false
			end
		end
	end
	copy.Name = "KitchenChefScene"
	local root = copy:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	copy.Parent = Workspace
	if root == nil or humanoid == nil then
		return copy, nil, tracks
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		local made = Instance.new("Animator")
		made.Parent = humanoid
		animator = made
	end
	local priorities = {
		ButtonPress = Enum.AnimationPriority.Action,
		Walk = Enum.AnimationPriority.Movement,
	}
	for name, id in pairs(KitchenConfig.ChefAnimations) do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return (animator :: Animator):LoadAnimation(animation)
		end)
		if ok and track then
			track.Priority = priorities[name] or Enum.AnimationPriority.Action
			track.Looped = name == "Walk"
			tracks[name] = track
		end
	end
	return copy, root, tracks
end

-- Hides (or shows) the server's chef on this screen: his body, clothes and name tag.
local hiddenGuis: { BillboardGui } = {}
local function hideChef(chef: Model, hidden: boolean)
	for _, item in ipairs(chef:GetDescendants()) do
		if item:IsA("BasePart") or item:IsA("Decal") then
			(item :: any).LocalTransparencyModifier = if hidden then 1 else 0
		elseif hidden and item:IsA("BillboardGui") and item.Enabled then
			item.Enabled = false
			table.insert(hiddenGuis, item)
		end
	end
	if not hidden then
		for _, gui in ipairs(hiddenGuis) do
			gui.Enabled = true
		end
		table.clear(hiddenGuis)
	end
end

-- Plays one of the chef copy's tracks (scaled with the Studio slow-motion attribute).
local function playTrack(track: AnimationTrack?, fade: number, speed: number?)
	if track then
		track:Play(fade)
		track:AdjustSpeed((speed or 1) / slow())
	end
end

-- The root turned to face `toward` (flat), standing where it is.
local function facing(root: BasePart, toward: Vector3): CFrame
	local at = root.Position
	local flat = Vector3.new(toward.X, at.Y, toward.Z)
	if (flat - at).Magnitude < 0.05 then
		return root.CFrame
	end
	return CFrame.lookAt(at, flat)
end

-- A flat direction's turn angle (CFrame.Angles(0, yaw, 0) looks that way).
local function yawOf(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

-- Turns the chef copy to face `toward` over `seconds`, the short way round unless that swings him (and the big meat he
-- may be holding up in front of him) past `avoid` (the grinder): then the long way.
local function turnChef(root: BasePart, toward: Vector3, seconds: number, avoid: Vector3?)
	local at = root.Position
	local from = yawOf(root.CFrame.LookVector)
	local flat = Vector3.new(toward.X - at.X, 0, toward.Z - at.Z)
	if flat.Magnitude < 0.05 then
		return
	end
	local delta = (yawOf(flat) - from + math.pi) % (2 * math.pi) - math.pi
	if avoid then
		local away = Vector3.new(avoid.X - at.X, 0, avoid.Z - at.Z)
		local past = (yawOf(away) - from + math.pi) % (2 * math.pi) - math.pi
		if away.Magnitude > 0.05 and math.sign(past) == math.sign(delta) and math.abs(past) < math.abs(delta) then
			delta -= math.sign(delta) * 2 * math.pi
		end
	end
	animate(seconds * math.clamp(math.abs(delta) / math.pi, 0.5, 1.6), function(t)
		root.CFrame = CFrame.new(at) * CFrame.Angles(0, from + delta * t, 0)
	end)
end

-- Walks the chef copy to `to` (turning toward it first) at `speed` studs a second (ChefWalkSpeed if nil), then turns
-- him to face `faceAfter`.
local function walkChef(root: BasePart, walk: AnimationTrack?, to: Vector3, faceAfter: Vector3?, speed: number?, avoid: Vector3?)
	local pace = speed or KitchenConfig.ChefWalkSpeed
	local goal = Vector3.new(to.X, root.Position.Y, to.Z)
	local distance = (goal - root.Position).Magnitude
	playTrack(walk, 0.2, pace / 9)
	if distance > 0.3 then
		turnChef(root, goal, 0.35, avoid)
		local from = root.CFrame
		local finish = CFrame.lookAt(goal, goal + from.LookVector)
		animate(distance / pace, function(t)
			root.CFrame = from:Lerp(finish, t)
		end, Enum.EasingStyle.Linear)
	end
	if faceAfter then
		turnChef(root, faceAfter, 0.8, avoid)
	end
	if walk then
		walk:Stop(0.25)
	end
end

--[[
	The mafia boss cow's walk-on (user 2026-11-21: "a small detail that if players just look down or something they see
	a cow on 2 legs opening and walking through the door, so it raises suspicion"): he waddles to the EMPLOYEES ONLY
	door, it swings open into the back room (KitchenBackDoor), he goes through, it shuts. On this screen only. Does
	nothing if his model didn't load (ReplicatedStorage.KitchenModels.CowBoss, KitchenBackRoom).
]]
local function cowCameo(_kit: Instance?, hall0: CFrame, made: { Instance })
	local cow = prop("CowBoss")
	if cow == nil then
		return
	end
	table.insert(made, cow)
	-- While his double walks, the cow standing in the back room isn't drawn on this screen (he can't be in two places
	-- when the door opens), and the door is held open for him.
	local hall = Workspace:FindFirstChild("KitchenHall")
	local room = hall and hall:FindFirstChild("BackRoom")
	local standing = room and room:FindFirstChild("CowBoss")
	local hidden: { BasePart } = {}
	if standing then
		for _, part in ipairs(standing:GetDescendants()) do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 1
				table.insert(hidden, part)
			end
		end
	end
	local holding = false
	local function release()
		if holding then
			holding = false
			KitchenBackDoor.hold(false)
		end
	end
	table.insert(undo, function()
		release()
		for _, part in ipairs(hidden) do
			part.LocalTransparencyModifier = 0
		end
	end)
	local function at(x: number, y: number): Vector3
		return (hall0 * KitchenConfig.planSpot(x, y, 0)).Position
	end
	local from, doorway, inside = at(236, 250), at(248, 262), at(248, 277)
	local function waddle(a: Vector3, b: Vector3, seconds: number)
		animate(seconds, function(t)
			local sway = math.sin(t * seconds * 9)
			cow:PivotTo(CFrame.lookAt(a:Lerp(b, t), b + (b - a)) * CFrame.Angles(0, 0, math.rad(5) * sway)
				+ Vector3.new(0, math.abs(sway) * 0.15, 0))
		end, Enum.EasingStyle.Linear)
	end
	cow:PivotTo(CFrame.lookAt(from, doorway))
	cow.Parent = Workspace
	local short = doorway - (doorway - from).Unit * 3
	waddle(from, short, 0.9)
	holding = true
	KitchenBackDoor.hold(true)
	wait(0.4)
	waddle(short, inside, 0.9)
	cow.Parent = nil
	release()
end

--[[
	Plays the scene for a cook of `steaks`. Returns when it's over (about 18 seconds for one bag) whether it played to
	the very end (false when skipped, cut short or not played); does nothing when one is already playing or the hall's
	pieces aren't there. `canSkip`: show the SKIP button (the player has watched it once).
]]
function KitchenScene.play(steaks: number, canSkip: boolean?): boolean
	if playing then
		return false
	end
	local player = Players.LocalPlayer
	local hall = Workspace:FindFirstChild("KitchenHall")
	local chef = hall and hall:FindFirstChild("KitchenChef")
	local grinder = hall and hall:FindFirstChild("MeatGrinder")
	local zoneIndex = player:GetAttribute("KitchenZone")
	local zone = hall and hall:FindFirstChild(string.format("PanZone_%02d", if typeof(zoneIndex) == "number" then zoneIndex else 0))
	if chef == nil or grinder == nil or not chef:IsA("Model") or not grinder:IsA("Model") then
		return false
	end
	local hopper = grinder:FindFirstChild("MeatGrinder_Hopper", true) :: BasePart?
	local spout = grinder:FindFirstChild("MeatGrinder_Spout", true) :: BasePart?
	if hopper == nil or spout == nil or chef:FindFirstChild("HumanoidRootPart") == nil then
		return false
	end
	playing = true
	skipping = false
	controls(false)
	PromptController.hide("KitchenScene", true)
	local camera = Workspace.CurrentCamera

	-- The camera glides between shots (the old scene's hard cut every second was hard to follow); `cut` jumps, and so
	-- does any glide whose straight path would pass through the chef or the grinder (Studio 2026-11-21: going round
	-- him to the other side, it flew through his body).
	local wantFrom, wantAt = Vector3.zero, Vector3.zero
	local camFrom, camAt = Vector3.zero, Vector3.zero
	local obstacles: { () -> (Vector3, number) } = {}
	local function blocked(a: Vector3, b: Vector3): boolean
		local along = b - a
		for _, obstacle in ipairs(obstacles) do
			local centre, clear = obstacle()
			local share = if along.Magnitude > 0.01 then math.clamp((centre - a):Dot(along) / along:Dot(along), 0, 1) else 0
			if (a + along * share - centre).Magnitude < clear then
				return true
			end
		end
		return false
	end
	local function shoot(from: Vector3, at: Vector3, cut: boolean?)
		wantFrom, wantAt = from, at
		if cut or blocked(camFrom, from) then
			camFrom, camAt = from, at
		end
	end
	RunService:BindToRenderStep("KitchenSceneCamera", Enum.RenderPriority.Camera.Value + 2, function(dt)
		local follow = 1 - math.exp(-dt / (0.45 * slow()))
		camFrom = camFrom:Lerp(wantFrom, follow)
		camAt = camAt:Lerp(wantAt, follow)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(camFrom, camAt)
		camera.Focus = CFrame.new(camAt)
	end)
	local made: { Instance } = {}
	local connections: { RBXScriptConnection } = {}
	hideSteak(zone :: Model?, true)
	if canSkip then
		table.insert(made, skipButton())
	end

	-- This screen's own chef, so his hands and the meat always keep time (user 2026-11-21: "the meat just walks away").
	local copy, root, tracks = chefCopy(chef :: Model)
	if copy then
		table.insert(made, copy)
	end
	hideChef(chef :: Model, true)

	local ok, problem = pcall(function()
		assert(copy and root, "no chef copy")
		local chefRoot = root :: BasePart
		local head = (copy :: Model):FindFirstChild("Head") :: BasePart
		local leftHand = (copy :: Model):FindFirstChild("LeftHand") :: BasePart?
		local rightHand = (copy :: Model):FindFirstChild("RightHand") :: BasePart?
		assert(head, "the chef copy has no head")
		local home = chefRoot.CFrame
		table.insert(obstacles, function()
			return chefRoot.Position, 5
		end)
		local hall0 = KitchenConfig.HallOrigin
		local up = Vector3.yAxis
		-- A plan point (WChewsLayout: x across, y front to back, z up) in the world.
		local function spot(x: number, y: number, z: number?): Vector3
			return (hall0 * KitchenConfig.planSpot(x, y, z)).Position
		end
		-- A camera spot kept inside the kitchen's walls (hall space x -280..280, z -16..258) and under its ceiling.
		local function inKitchen(at: Vector3): Vector3
			local p = hall0:PointToObjectSpace(at)
			return hall0:PointToWorldSpace(Vector3.new(math.clamp(p.X, -278, 278), math.clamp(p.Y, 2, WChewsLayout.KitchenHeight - 3),
				math.clamp(p.Z, -16, 256)))
		end
		local function hallVector(x: number, y: number, z: number): Vector3
			return hall0:VectorToWorldSpace(Vector3.new(x, y, z))
		end
		local hopperTop = hopper.Position + Vector3.new(0, hopper.Size.Y / 2, 0)
		local length = KitchenConfig.steakLength(steaks)
		local grinderHome = grinder:GetPivot()
		local grinderAt = grinderHome.Position
		table.insert(obstacles, function()
			return grinderAt + up * 8, 12
		end)
		local kit = (hall :: Instance):FindFirstChild("WChewsKit")
		local panel = kit and kit:FindFirstChild("WcButtonPanel")
		local button = panel and panel:FindFirstChild("WcButtonPanel_Button", true)
		local lamp = panel and panel:FindFirstChild("WcButtonPanel_Lamp", true)
		hideCharacter(true)

		-- 1. The chef steps to the start button and slaps it with his open palm (Chef_ButtonPress). He stands so that his
		-- palm, ChefPress.HandAhead in front of him and HandRight to his right at the press, comes down on the button.
		local press = KitchenConfig.ChefPress
		if button and button:IsA("BasePart") then
			local buttonAt = button.Position
			local toward = Vector3.new(buttonAt.X - home.Position.X, 0, buttonAt.Z - home.Position.Z)
			toward = if toward.Magnitude > 0.05 then toward.Unit else home.RightVector
			local right = toward:Cross(up)
			local standAt = buttonAt - toward * press.HandAhead - right * press.HandRight
			standAt = Vector3.new(standAt.X, home.Position.Y, standAt.Z)
			-- (from the kitchen side, past the button: his front, his hand and the button, the dining room behind him)
			shoot(buttonAt + hallVector(-5, 3.4, 8), buttonAt:Lerp(standAt, 0.4) + up * 0.7, true)
			walkChef(chefRoot, tracks.Walk, standAt, standAt + toward * 10)
			chefRoot.CFrame = CFrame.lookAt(standAt, standAt + toward)
			shoot(buttonAt + hallVector(-4, 2.6, 6), buttonAt:Lerp(standAt, 0.3) + up * 0.9)
			playTrack(tracks.ButtonPress, 0.15)
			wait(press.Press)
			-- The button goes down under his palm and its lamp blinks: the machine is on.
			local buttonHome = button.CFrame
			local pressed = button :: BasePart
			table.insert(undo, function()
				pressed.CFrame = buttonHome
			end)
			pressed.CFrame = buttonHome - Vector3.new(0, pressed.Size.Y * 0.4, 0)
			-- (its own clunk under his palm, then the machine's start buzzer, quietly)
			sound(KitchenConfig.Sounds.Button, 0.9, pressed)
			beside(function()
				wait(0.12)
				sound(KitchenConfig.Sounds.Buzzer, 0.3, pressed)
			end)
			if lamp and lamp:IsA("BasePart") then
				local light = lamp :: BasePart
				table.insert(undo, function()
					light.LocalTransparencyModifier = 0
				end)
				beside(function()
					for _ = 1, 5 do
						light.LocalTransparencyModifier = 0.85
						wait(0.12)
						light.LocalTransparencyModifier = 0
						wait(0.12)
					end
				end)
			end
			wait(0.5)
			pressed.CFrame = buttonHome
		end

		-- He says his line and walks back to his spot while the machine does the work.
		chefSays(head, "Alright, I'll handle this for you!", 2.6 * slow())
		sound(KitchenConfig.Sounds.ChefLine, 1, head)
		beside(function()
			wait(math.max(press.Seconds - press.Press - 0.5, 0.1))
			walkChef(chefRoot, tracks.Walk, home.Position, home.Position + home.LookVector * 10)
			chefRoot.CFrame = home
		end)
		wait(0.9)

		-- 2. The bag (a cow for big cooks, more cows for huge ones) falls out of the ceiling chute into the grinder's tub.
		local chuteMouth = spot(WChewsLayout.Chute.X, WChewsLayout.Chute.Y, WChewsLayout.ChuteMouth + 3)
		-- (from the grinder's side, behind the display bay: from the front corner the bay's frame and the funnel filled the
		--  picture; Studio 2026-11-21)
		shoot(inKitchen(grinderAt + hallVector(34, 14, -4)), grinderAt + up * 19, true)
		local drops: { Model } = {}
		local kind, count = KitchenConfig.sceneDrops(steaks)
		for _ = 1, count do
			local item = prop(if kind == "Bag" then "MeatBag" else "Cow")
			if item then
				-- (sized for the big grinder: a bag 5 to 8 studs, a cow 10: at a fixed scale the cow was a speck; Studio 2026-11-21)
				local size = item:GetExtentsSize()
				local longest = math.max(size.X, size.Y, size.Z, 0.1)
				item:ScaleTo((if kind == "Bag" then math.clamp(5 + steaks / 30, 5, 8) else 10) / longest)
				table.insert(drops, item)
			end
		end
		local fall = KitchenConfig.DropSeconds - 0.35
		for index, item in ipairs(drops) do
			table.insert(made, item)
			local spin = math.rad(40 * index)
			item:PivotTo(CFrame.new(chuteMouth) * CFrame.Angles(0.4, spin, 0.3))
			beside(function()
				wait((index - 1) * KitchenConfig.DropGap)
				item.Parent = Workspace
				sound(KitchenConfig.Sounds.Chute, 0.7, hopper) -- (the rumble down the chute; the thud follows as it lands)
				if kind == "Cow" then
					sound(KitchenConfig.Sounds.CowMoo, 0.8, hopper)
				end
				local baseScale = item:GetScale()
				animate(fall, function(t)
					item:PivotTo(CFrame.new(chuteMouth:Lerp(hopperTop + up, t)) * CFrame.Angles(0.4 + t * 2.5, spin, 0.3 - t))
				end, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				sound(KitchenConfig.Sounds.BagThud, 0.9, hopper)
				animate(0.35, function(t)
					item:ScaleTo(math.max(baseScale * (1 - t), 0.02))
					item:PivotTo(CFrame.new(hopperTop + Vector3.new(0, 1 - 2 * t, 0)))
				end)
				item.Parent = nil
			end)
		end
		wait(KitchenConfig.DropSeconds + (math.max(#drops, 1) - 1) * KitchenConfig.DropGap)

		-- 3. Grinding: the grinder churns and squirts the meat out of its outlet into the display bay, where the lifter's
		-- mountain of meat grows under the YOUR MEAT sign.
		local bayAt = spot(WChewsLayout.Bay.X, WChewsLayout.Bay.Y, 0.3)
		local spoutDir = Vector3.new(spout.CFrame.LookVector.X, 0, spout.CFrame.LookVector.Z).Unit -- (the way it points)
		local spoutFront = spout.Position + spoutDir * (spout.Size.Z / 2 + 0.4)
		local mound = prop("MeatMound")
		local moundSize = math.clamp(length * 0.5, 3, 22)
		local radius = moundSize / 2
		local moundScale = 1
		if mound then
			table.insert(made, mound)
			moundScale = moundSize / math.max(mound:GetExtentsSize().X, 0.1)
			mound:ScaleTo(moundScale * 0.05)
			mound:PivotTo(CFrame.new(bayAt))
			mound.Parent = Workspace
		end
		-- (from the dining side of the bay, a little to one side: the sign, the mound, the grinder shaking behind it)
		shoot(inKitchen(bayAt + hallVector(15 + radius * 0.5, 8.5 + radius * 0.3, -23 - radius)), bayAt + up * (3.5 + radius * 0.35), true)
		burst(spoutFront, Color3.fromRGB(205, 82, 80), 16, 0.7, KitchenConfig.GrindSeconds - 0.4, 70, spoutDir - Vector3.new(0, 0.6, 0))
		sound(KitchenConfig.Sounds.Grinder, 0.8, spout)
		animate(KitchenConfig.GrindSeconds, function(t)
			local shake = math.sin(t * KitchenConfig.GrindSeconds * 40) * 0.3 * (1 - t * 0.5)
			grinder:PivotTo(grinderHome * CFrame.new(shake, 0, 0) * CFrame.Angles(0, 0, math.rad(shake * 4)))
			if mound then
				mound:ScaleTo(moundScale * math.max(t, 0.05))
				mound:PivotTo(CFrame.new(bayAt))
			end
		end, Enum.EasingStyle.Linear)
		grinder:PivotTo(grinderHome)
		wait(0.6)

		-- 4. The tube: the funnel over the bay draws the meat up in lumps; they run along the overhead trunk, down the
		-- branch over the lifter's column of pans, and drop out of the nozzle onto the lifter's own pan.
		local panFloor = KitchenConfig.PanFloorHeight * KitchenConfig.PanScale - KitchenConfig.PanSink
		local zoneAt = if zone then (zone :: Model):GetPivot().Position else spot(WChewsLayout.PanColumns[5], WChewsLayout.PanRows[1])
		local target = zoneAt + up * panFloor
		local zoneHall = hall0:PointToObjectSpace(zoneAt)
		local tubeY = WChewsLayout.TubeHeight
		local path = {
			bayAt + up * math.min(radius, 6),
			spot(WChewsLayout.Bay.X, WChewsLayout.Bay.Y, tubeY),
			spot(WChewsLayout.Bay.X, WChewsLayout.TrunkY, tubeY),
			hall0:PointToWorldSpace(Vector3.new(zoneHall.X, tubeY, WChewsLayout.TrunkY)),
			hall0:PointToWorldSpace(Vector3.new(zoneHall.X, tubeY, zoneHall.Z)),
			hall0:PointToWorldSpace(Vector3.new(zoneHall.X, tubeY - 9, zoneHall.Z)),
			target,
		}
		local lengths: { number } = {}
		local total = 0
		for index = 1, #path - 1 do
			lengths[index] = (path[index + 1] - path[index]).Magnitude
			total += lengths[index]
		end
		local function along(distance: number): Vector3
			for index = 1, #lengths do
				if distance <= lengths[index] or index == #lengths then
					return path[index]:Lerp(path[index + 1], math.clamp(distance / math.max(lengths[index], 0.01), 0, 1))
				end
				distance -= lengths[index]
			end
			return path[#path]
		end
		local travel = math.clamp(total / 150, KitchenConfig.TubeMinSeconds, KitchenConfig.TubeMaxSeconds)
		local speed = total / travel
		local lumps: { { model: Model, delay: number, done: boolean } } = {}
		for index = 1, KitchenConfig.TubeLumps do
			local lump = prop("MeatMound")
			if lump then
				lump:ScaleTo(KitchenConfig.TubeLumpSize / math.max(lump:GetExtentsSize().X, 0.1))
				table.insert(made, lump)
				table.insert(lumps, { model = lump, delay = (index - 1) * KitchenConfig.TubeLumpGap, done = false })
			end
		end
		local landed = 0
		local streamStart = os.clock()
		sound(KitchenConfig.Sounds.Tube, 0.7, Workspace) -- (3.2 s: the suction and the rush along the tube; the run takes 2.4 to 3.6)
		table.insert(connections, RunService.RenderStepped:Connect(function()
			local now = (os.clock() - streamStart) / slow()
			for _, lump in ipairs(lumps) do
				if not lump.done then
					local t = now - lump.delay
					if t >= travel then
						lump.done = true
						lump.model.Parent = nil
						landed += 1
						if landed == 1 then
							-- The first lump hits the pan: the steak is there, in a burst of steam.
							hideSteak(zone :: Model?, false)
							burst(target + Vector3.new(0, 1, 0), Color3.fromRGB(240, 240, 240), 10, 2.5, 1.2, 40)
							sound(KitchenConfig.Sounds.MeatLand, 0.9, Workspace)
						else
							-- Every lump after it lands with its own plop, each at a slightly different pitch.
							sound(KitchenConfig.Sounds.Plop, 0.55, Workspace).PlaybackSpeed = 0.94 + 0.03 * (landed % 5)
						end
					elseif t >= 0 then
						if lump.model.Parent == nil then
							lump.model.Parent = Workspace
						end
						lump.model:PivotTo(CFrame.new(along(speed * t)) * CFrame.Angles(t * 6, t * 4, 0))
					end
				end
			end
		end))
		-- The mound shrinks away as it is drawn up.
		beside(function()
			if mound then
				local leaving = mound :: Model
				animate(#lumps * KitchenConfig.TubeLumpGap + 0.9, function(t)
					leaving:ScaleTo(moundScale * math.max(1 - t, 0.04))
					leaving:PivotTo(CFrame.new(bayAt))
				end, Enum.EasingStyle.Linear)
				leaving.Parent = nil
			end
		end)
		-- (low beside the bay, looking up at the funnel)
		-- (well outside the bay's front corner: closer in, a post crossed the picture and the sign showed from behind)
		shoot(inKitchen(bayAt + hallVector(-24, 7, -27)), bayAt + up * 11, true)
		wait(1.0)
		-- (under the trunk near the middle, looking along it the way the meat runs)
		local side = if zoneHall.X >= 0 then 1 else -1
		shoot(inKitchen(hall0:PointToWorldSpace(Vector3.new(-side * 16, 20, WChewsLayout.TrunkY - 22))),
			hall0:PointToWorldSpace(Vector3.new(zoneHall.X * 0.55, tubeY, WChewsLayout.TrunkY + 6)), true)
		wait(math.max(travel - 1.0 - 1.1, 0.4))
		-- (at the lifter's pan, looking up at the nozzle the meat drops out of; the camera stands on the pan's side away
		--  from the EMPLOYEES ONLY door, so that door is in the background)
		local doorAt = spot(248, 266, 5)
		local away = Vector3.new(target.X - doorAt.X, 0, target.Z - doorAt.Z)
		away = if away.Magnitude > 1 then away.Unit else hallVector(0, 0, -1)
		shoot(inKitchen(target + away * (19 + length * 0.5) + up * (8 + length * 0.25)), target + up * 6, true)
		wait(1.1 + #lumps * KitchenConfig.TubeLumpGap + 0.2)

		-- 5. The steak in the pan, in its steam; behind it, the mafia boss cow slips through the EMPLOYEES ONLY door.
		shoot(inKitchen(target + away * (26 + length * 0.6) + up * (18 + length * 0.4)), target)
		beside(cowCameo, kit, hall0, made)
		wait(KitchenConfig.LandingSeconds)
	end)
	if not ok and problem ~= SKIP then
		warn("[KitchenScene] the scene stopped early: " .. tostring(problem))
	end

	-- Back to normal, whatever happened.
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	for _, item in ipairs(made) do
		item:Destroy()
	end
	for _, back in ipairs(undo) do
		pcall(back)
	end
	table.clear(undo)
	hideChef(chef :: Model, false)
	hideCharacter(false)
	hideSteak(zone :: Model?, false)
	RunService:UnbindFromRenderStep("KitchenSceneCamera")
	camera.CameraType = Enum.CameraType.Custom
	controls(true)
	PromptController.hide("KitchenScene", false)
	local finished = ok and not skipping
	skipping = false
	playing = false
	return finished
end

-- The chef's words in the scene's caption (his name on a black bar, the words typed out), for other moments too: the
-- welcome when you walk in (KitchenWelcome).
function KitchenScene.say(text: string, seconds: number)
	chefSays(nil :: any, text, seconds)
end

-- Whether the chef scene is playing on this screen now.
function KitchenScene.isPlaying(): boolean
	return playing
end

return KitchenScene
