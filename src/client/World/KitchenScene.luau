--!strict
--[[
	KitchenScene
	Client / World

	The chef scene (GAME_DESIGN §40.7), played on the cooking player's own screen right after the chef takes their order
	(KitchenMenu calls play). THE W CHEWS SCENE (user 2026-11-21, replacing the scoop / carry / throw of the same day):

		1. the chef steps to the start button by his counter and slaps it with his open palm (Chef_ButtonPress,
		   art/scripts/chef_animations.py); the button goes down, its lamp blinks; he turns to the PLAYER, who is seen
		   standing where they really are, and says "Alright, I'll handle this for you!" to them, heard in full, both
		   of them in the picture; then he walks back to his spot
		2. raw meat tumbles out of the ceiling chute into the grinder's tub (a cow from KitchenConfig.CowFrom steaks,
		   more cows for huge cooks)
		3. the grinder churns and squirts the meat out of its outlet into the display bay, where the lifter's mountain of
		   mince grows under the YOUR MEAT sign
		4. the funnel over the bay draws it up (ONE shot); the lumps run along the overhead trunk and down the branch
		   over the lifter's column of pans
		   IN THE BACKGROUND of shots 3 and 4, far down the kitchen: the mafia boss cow waddles up to the EMPLOYEES
		   ONLY double door in the middle of the back wall, pushes both leaves open at once and goes through; they
		   swing shut behind him. No camera move toward him: a detail for the second or third watch.
		5. they drop out of the nozzle onto the lifter's OWN pan and STACK UP into a pile
		6. the GIANT MEAT PRESS slides in over the pan, SLAMS the pile, and slowly lifts off a RAW steak
		7. the raw steak cooks in its steam: it browns, the sear marks come up, and it is the big steak

	USER 2026-11-22, after watching it: the chef's line was cut off (it played from his head and the camera left him:
	now it plays flat and the camera waits); bags were too much for a little meat (meat falls); the cuts were too fast
	and the second tube shot wasn't needed (fewer shots, held longer, glides); the meat plopped straight into a steak
	(now the pile, the press, the raw steak, the cooking); nobody could see the cow (his own shot).
	USER 2026-11-22, second notes: "he turns back and talks to the counter, but you cant visibly see yourself" (the
	player's character is no longer hidden: it is turned to the chef, he talks to it, and it is hidden only for a
	shot it would stand in the way of); "the cutscene for the cow walking in is too obvious ... what i was looking
	for was like a background type of thing" (his own shot is gone: he is in the background of the two bay shots,
	which are filmed with a longer lens from further back so the door at the far wall is big enough to notice).

	ITS MEAT MODELS (WChewsMeat_01, uploaded 2026-11-22; the scene still plays if one fails to load): MeatPress (without
	it the pile just presses itself flat in a puff), MincePile (the mountain of mince, as the user's photo; the old
	MeatMound stands in) and MeatChunk (the falling raw meat; MeatMound lumps stand in). The lumps in the tube stay
	the light MeatMound: there are twelve of them.

	Everything here is local: copies of the shared props in ReplicatedStorage.KitchenModels, the camera, and this
	screen's own copy of the chef (the server's chef is hidden on this screen meanwhile); nobody else sees it, and the
	server's steak in the pan is only hidden from this player until the raw one has cooked. About 28 seconds. It
	always plays the first time; after one full watch a SKIP button shows.

	PERFORMANCE: a few prop copies, one chef copy, two particle emitters and a camera, all removed when it ends.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
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

-- The chef's line is 2.49 s long (KitchenConfig.Sounds.ChefLine); the camera stays on him this long.
local CHEF_LINE_SECONDS = 2.6
-- The press (plan in the scene): the slide in over the pan, the pause above the pile, the slam, the hold, the slow lift.
local PRESS = { SlideIn = 0.85, Pause = 0.5, Slam = 0.14, Hold = 0.8, Lift = 2.2, SlideOut = 1.0 }
-- The raw steak's colours before it cooks, and how long the cooking takes.
local RAW_MEAT = Color3.fromRGB(204, 52, 60)
local RAW_FAT = Color3.fromRGB(252, 238, 230)
local COOK_SECONDS = 2.6
-- The nozzle over a pan ends this far under the tube's axis (the meat's path below).
local NOZZLE_DROP = 9
-- The player's own character is hidden for a shot only when it stands this near the line from the camera to what the
-- camera looks at.
local CHARACTER_CLEAR = 4
-- The two bay shots (the grinding and the suction) are filmed from further back with a longer lens, aimed between
-- the bay and the double door at the far wall (Weight of the way toward the bay): the door is 250 studs behind the
-- bay, and with the game's usual 70 degrees the cow at it was 27 pixels tall on a 1080p screen. At 40 degrees he is
-- about 45, the open doorway 75 by 90. Checked in art/scripts/preview_wchews.py (views 30 and 31), which uses the
-- same numbers.
local BAY_SHOT = { FieldOfView = 40, Weight = 0.6 }
-- The cow in the background: how fast he waddles (studs a second), how far along the wall he starts from the door,
-- and when he sets off (seconds into the grinding shot, which lasts about 4.6: he is through the doors before it
-- ends, and they shut behind him in the suction shot).
local COW_WALK = { Speed = 8, From = 12, After = 0.4 }

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

-- Hides (or shows) this player's own character on their screen. The character is SEEN in the scene (user 2026-11-22:
-- "you cant visibly see yourself"); it is hidden only for a shot it would stand in the way of (shoot, in play).
local characterHidden = false
local function hideCharacter(hidden: boolean)
	if hidden == characterHidden then
		return
	end
	characterHidden = hidden
	local character = Players.LocalPlayer.Character
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") or part:IsA("Decal") then
				(part :: any).LocalTransparencyModifier = if hidden then 1 else 0
			end
		end
	end
end

-- This player's own character's root part, if it is there.
local function characterRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local body = character and character:FindFirstChild("HumanoidRootPart")
	return if body and body:IsA("BasePart") then body else nil
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
	The mafia boss cow in the BACKGROUND of the two bay shots (user 2026-11-21: "a cow on 2 legs opening and walking
	through the door, so it raises suspicion"; 2026-11-22: his own shot was "too obvious ... what i was looking for
	was like a background type of thing ... the mafia boss cow can push open both of them at the same time"). Far
	down the kitchen he waddles along the back wall to the EMPLOYEES ONLY double door, turns in, leans into both
	leaves with his hoof out (they swing open into the back room: KitchenBackDoor), goes through, and they shut
	behind him. The camera never moves toward him. On this screen only; it runs beside the scene and returns when he
	is gone. Does nothing if his model didn't load (ReplicatedStorage.KitchenModels.CowBoss, KitchenBackRoom).
]]
local function cowInTheBackground(hall0: CFrame, made: { Instance })
	local cow = prop("CowBoss")
	if cow == nil then
		return
	end
	for _, item in ipairs(cow:GetDescendants()) do
		if item:IsA("BillboardGui") or item:IsA("ProximityPrompt") then
			item:Destroy()
		end
	end
	table.insert(made, cow)
	-- While his double walks, the cow standing in the back room isn't drawn on this screen (he can't be in two places
	-- when the doors open), and the doors are held open for him.
	local hall = Workspace:FindFirstChild("KitchenHall")
	local room = hall and hall:FindFirstChild("BackRoom")
	local standing = room and room:FindFirstChild("CowBoss")
	local hidden: { BasePart } = {}
	local tags: { BillboardGui } = {}
	if standing then
		for _, part in ipairs(standing:GetDescendants()) do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 1
				table.insert(hidden, part)
			elseif part:IsA("BillboardGui") and part.Enabled then
				part.Enabled = false -- (his name tag goes with him)
				table.insert(tags, part)
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
		for _, tag in ipairs(tags) do
			tag.Enabled = true
		end
	end)

	-- His right arm's pieces turn round his shoulder (rigid pieces, no skeleton: WChewsLayout.CowShoulder), as at his
	-- shuffle table (LuckMenu). `reach` 0..1: his hoof out in front of him.
	local offset, shoulder = WChewsLayout.PivotOffset.CowBoss, WChewsLayout.CowShoulder
	local toShoulder = CFrame.new(offset.X - shoulder.X, shoulder.Z - offset.Z, shoulder.Y - offset.Y)
	local joint = cow:GetPivot() * toShoulder
	local arm: { { part: BasePart, home: CFrame } } = {}
	for _, part in ipairs(cow:GetDescendants()) do
		if part:IsA("BasePart") and string.find(part.Name, "CowBoss_ArmR", 1, true) then
			table.insert(arm, { part = part, home = joint:ToObjectSpace(part.CFrame) })
		end
	end
	local reach = 0
	local function stand(at: CFrame)
		cow:PivotTo(at)
		local turned = at * toShoulder * CFrame.Angles(math.rad(78) * reach, 0, 0)
		for _, piece in ipairs(arm) do
			piece.part.CFrame = turned * piece.home
		end
	end

	-- (plan points: the doorway is in the back wall, BackWallY .. BackWallY + WallThickness)
	local door, wallY = WChewsLayout.BackDoor, WChewsLayout.BackWallY
	local function at(x: number, y: number): Vector3
		return (hall0 * KitchenConfig.planSpot(x, y, 0)).Position
	end
	local from = at(door.Middle + COW_WALK.From, wallY - 9)
	local front = at(door.Middle + 0.8, wallY - 8)
	local push = at(door.Middle + 0.4, wallY - 1.8) -- (his hoof, 2.6 in front of him, reaches the leaves here)
	local inside = at(door.Middle, wallY + WChewsLayout.WallThickness + 13)
	-- Waddles from a to b: `lean` (0..1) tips him forward into the doors.
	local function waddle(a: Vector3, b: Vector3, lean: number, during: ((number) -> ())?)
		local seconds = (b - a).Magnitude / COW_WALK.Speed
		animate(seconds, function(t)
			if during then
				during(t)
			end
			local sway = math.sin(t * seconds * 9)
			stand(CFrame.lookAt(a:Lerp(b, t), b + (b - a)) * CFrame.Angles(math.rad(-7) * lean, 0, math.rad(5) * sway)
				+ Vector3.new(0, math.abs(sway) * 0.15, 0))
		end, Enum.EasingStyle.Linear)
	end

	wait(COW_WALK.After)
	stand(CFrame.lookAt(from, front))
	cow.Parent = Workspace
	waddle(from, front, 0)
	-- He turns in to the doors, his hoof coming up.
	local facingAlong = CFrame.lookAt(front, front + (front - from))
	local facingDoor = CFrame.lookAt(front, Vector3.new(push.X, front.Y, push.Z))
	animate(0.35, function(t)
		reach = t
		stand(facingAlong:Lerp(facingDoor, t))
	end)
	-- Up to the doors, leaning in: both leaves give way together as his hoof reaches them.
	waddle(front, push, 1)
	holding = true
	KitchenBackDoor.hold(true)
	-- Through the doorway, his arm coming down once he is past the leaves.
	waddle(push, inside, 1, function(t)
		reach = 1 - math.clamp((t - 0.35) / 0.3, 0, 1)
	end)
	-- The leaves swing shut behind him; he is taken away once they have.
	release()
	wait(1.0)
	cow.Parent = nil
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
	-- A short shake (the press's slam): `shakeSize` studs, dying away until `shakeUntil`.
	local shakeUntil, shakeFor, shakeSize = 0, 1, 0
	local function shakeCamera(size: number, seconds: number)
		shakeSize, shakeFor, shakeUntil = size, seconds * slow(), os.clock() + seconds * slow()
	end
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
	-- Whether this player's own character would stand in a shot's way: near the line from the camera to what it
	-- looks at.
	local function inTheWay(from: Vector3, at: Vector3): boolean
		local body = characterRoot()
		if body == nil then
			return false
		end
		local along = at - from
		local share = if along.Magnitude > 0.01 then math.clamp((body.Position - from):Dot(along) / along:Dot(along), 0, 1) else 0
		return (from + along * share - body.Position).Magnitude < CHARACTER_CLEAR
	end
	-- `withPlayer`: the shot is framed on the player's character too, so it is shown wherever it stands; in every
	-- other shot it is shown unless it would stand in the way.
	local function shoot(from: Vector3, at: Vector3, cut: boolean?, withPlayer: boolean?)
		wantFrom, wantAt = from, at
		if cut or blocked(camFrom, from) then
			camFrom, camAt = from, at
		end
		hideCharacter(not withPlayer and inTheWay(from, at))
	end
	local usualFieldOfView = camera.FieldOfView
	RunService:BindToRenderStep("KitchenSceneCamera", Enum.RenderPriority.Camera.Value + 2, function(dt)
		local follow = 1 - math.exp(-dt / (0.45 * slow()))
		camFrom = camFrom:Lerp(wantFrom, follow)
		camAt = camAt:Lerp(wantAt, follow)
		local jolt = Vector3.zero
		local left = shakeUntil - os.clock()
		if left > 0 then
			local size = shakeSize * left / shakeFor
			jolt = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2 * size
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(camFrom + jolt, camAt)
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
		-- The player's character stays where it really is, in the picture, turned to the chef (controls are held).
		local body = characterRoot()
		if body then
			local chefAt = Vector3.new(home.Position.X, body.Position.Y, home.Position.Z)
			if (chefAt - body.Position).Magnitude > 1 then
				body.CFrame = CFrame.lookAt(body.Position, chefAt)
			end
		end
		-- A plan point is inside the restaurant's walkable rooms (the dining room, the kitchen, the opening between).
		local function inRooms(at: Vector3): boolean
			local p = hall0:PointToObjectSpace(at)
			local x, y = math.abs(p.X), p.Z
			return (x < 77 and y > -107 and y < -18) or (x < 282 and y >= -18 and y < 262)
		end

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
			-- (his hand comes back up off the button before he turns)
			wait(math.max(press.Seconds - press.Press - 0.5, 0.1))
		end

		-- He turns to the PLAYER and says his line to them (user 2026-11-22: "he turns back and talks to the counter, but
		-- you cant visibly see yourself, as in my character"), then walks back to his spot. A two-shot from the side,
		-- level with their heads, looking along the counter between them: the chef on one half of the picture and the
		-- player on the other, both the same size, face to face, neither in front of the other. (From behind the
		-- player's shoulder the chef was a small figure far across the counter: Studio 2026-11-22.) The line is heard
		-- in full (user 2026-11-22: "the audio gets cut off"): it plays flat instead of from his head, so no camera
		-- move can fade it, and the camera stays on the two of them until he has said it.
		local listener = if body then body.Position else chefRoot.Position + home.LookVector * 10
		local toListener = Vector3.new(listener.X - chefRoot.Position.X, 0, listener.Z - chefRoot.Position.Z)
		if body and toListener.Magnitude > 2 then
			local toward = toListener.Unit
			local side = toward:Cross(up)
			local between = chefRoot.Position:Lerp(listener, 0.5)
			-- (the player's character looks at him where he stands now, by the button)
			body.CFrame = CFrame.lookAt(body.Position, Vector3.new(chefRoot.Position.X, body.Position.Y, chefRoot.Position.Z))
			-- (far enough to the side for both to fit a narrow screen; a little toward the player's end, so the chef's
			--  face shows more than his ear)
			local aside = math.clamp(toListener.Magnitude * 0.85, 8, 16)
			-- (from whichever side is inside the rooms; of two that are, the one nearer the middle aisle)
			local spots = { between + side * aside + toward * 1.5 + up * 2.2, between - side * aside + toward * 1.5 + up * 2.2 }
			local function rank(at: Vector3): number
				return (if inRooms(at) then 0 else 1000) + math.abs(hall0:PointToObjectSpace(at).X)
			end
			local from = if rank(spots[1]) <= rank(spots[2]) then spots[1] else spots[2]
			shoot(from, between + up * 1.2, true, true)
		else
			-- (no character to talk to: he says it over his counter, as before)
			shoot(chefRoot.Position + hallVector(-7, 4.2, 12), chefRoot.Position + up * 1.3)
		end
		beside(function()
			turnChef(chefRoot, listener, 0.5)
		end)
		chefSays(head, "Alright, I'll handle this for you!", (CHEF_LINE_SECONDS + 0.5) * slow())
		sound(KitchenConfig.Sounds.ChefLine, 1, SoundService)
		wait(CHEF_LINE_SECONDS)
		beside(function()
			walkChef(chefRoot, tracks.Walk, home.Position, home.Position + home.LookVector * 10)
			chefRoot.CFrame = home
		end)
		wait(0.7) -- (he sets off back to his spot)

		-- 2. The meat falls out of the ceiling chute into the grinder's tub (user 2026-11-22: "the bags of meats are too
		-- much for a little amount of meat so instead ... meat falls"): a handful of raw chunks, more for a bigger cook;
		-- a cow from CowFrom steaks, more cows for huge cooks.
		local chuteMouth = spot(WChewsLayout.Chute.X, WChewsLayout.Chute.Y, WChewsLayout.ChuteMouth + 3)
		-- (from the grinder's side, behind the display bay: from the front corner the bay's frame and the funnel filled the
		--  picture; Studio 2026-11-21)
		shoot(inKitchen(grinderAt + hallVector(34, 14, -4)), grinderAt + up * 19, true)
		wait(0.5)
		local drops: { Model } = {}
		local kind, count = KitchenConfig.sceneDrops(steaks)
		for index = 1, count do
			local item = if kind == "Cow" then prop("Cow") else (prop("MeatChunk") or prop("MeatMound"))
			if item then
				-- (sized for the big grinder: a chunk 3.6 to 5.6 studs, a cow 10: at 2 to 3 studs a chunk was a dot against
				--  the grinder, Studio 2026-11-22, as the cow was a speck at a fixed scale the day before)
				local size = item:GetExtentsSize()
				local longest = math.max(size.X, size.Y, size.Z, 0.1)
				item:ScaleTo((if kind == "Cow" then 10 else 3.6 + (index * 7 % 5) * 0.5) / longest)
				table.insert(drops, item)
			end
		end
		local dropGap = if kind == "Cow" then KitchenConfig.DropGap else KitchenConfig.ChunkGap
		local fall = KitchenConfig.DropSeconds - 0.35
		for index, item in ipairs(drops) do
			table.insert(made, item)
			local spin = math.rad(40 * index)
			-- (the chunks spread over the tub's mouth; a cow comes down its middle)
			local aside = if kind == "Cow" then Vector3.zero
				else Vector3.new(math.sin(index * 2.4), 0, math.cos(index * 1.7)) * math.min(hopper.Size.X, hopper.Size.Z) * 0.22
			item:PivotTo(CFrame.new(chuteMouth) * CFrame.Angles(0.4, spin, 0.3))
			beside(function()
				wait((index - 1) * dropGap)
				item.Parent = Workspace
				if index == 1 or kind == "Cow" then
					sound(KitchenConfig.Sounds.Chute, 0.7, hopper) -- (the rumble down the chute; the thud follows as it lands)
				end
				if kind == "Cow" then
					sound(KitchenConfig.Sounds.CowMoo, 0.8, hopper)
				end
				local baseScale = item:GetScale()
				animate(fall, function(t)
					item:PivotTo(CFrame.new(chuteMouth:Lerp(hopperTop + up + aside, t)) * CFrame.Angles(0.4 + t * 2.5, spin, 0.3 - t))
				end, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				if kind == "Cow" then
					sound(KitchenConfig.Sounds.BagThud, 0.9, hopper)
				else
					-- (every chunk slaps into the tub, each at a slightly different pitch)
					sound(KitchenConfig.Sounds.MeatFall, 0.8, hopper).PlaybackSpeed = 0.9 + 0.05 * (index % 5)
				end
				animate(0.35, function(t)
					item:ScaleTo(math.max(baseScale * (1 - t), 0.02))
					item:PivotTo(CFrame.new(hopperTop + aside + Vector3.new(0, 1 - 2 * t, 0)))
				end)
				item.Parent = nil
			end)
		end
		wait(KitchenConfig.DropSeconds + (math.max(#drops, 1) - 1) * dropGap + 0.5)

		-- 3. Grinding: the grinder churns and squirts the meat out of its outlet into the display bay, where the lifter's
		-- mountain of mince grows under the YOUR MEAT sign.
		local bayAt = spot(WChewsLayout.Bay.X, WChewsLayout.Bay.Y, 0.3)
		local spoutDir = Vector3.new(spout.CFrame.LookVector.X, 0, spout.CFrame.LookVector.Z).Unit -- (the way it points)
		local spoutFront = spout.Position + spoutDir * (spout.Size.Z / 2 + 0.4)
		local mound = prop("MincePile") or prop("MeatMound")
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
		-- The two bay shots (this one and the suction shot) are filmed from far back by the kitchen's front wall with a
		-- longer lens, aimed between the bay and the EMPLOYEES ONLY double door in the middle of the far wall, so the
		-- door stands in the picture beside the bay, big enough to notice (BAY_SHOT). The cow sets off as this shot
		-- starts.
		local backDoor = WChewsLayout.BackDoor
		local farDoor = spot(backDoor.Middle, WChewsLayout.BackWallY, backDoor.Height / 2)
		local function bayShot(from: Vector3, subject: Vector3)
			local aim = (subject - from).Unit * BAY_SHOT.Weight + (farDoor - from).Unit * (1 - BAY_SHOT.Weight)
			camera.FieldOfView = BAY_SHOT.FieldOfView
			shoot(from, from + aim * 50, true)
		end
		-- (from the dining side of the bay, a little to one side: the sign, the mound, the grinder shaking behind it,
		--  and the double door far behind, between the grinder and the left-hand islands)
		bayShot(inKitchen(bayAt + hallVector(20 + radius * 0.5, 11.7 + radius * 0.3, -50 - radius)), bayAt + up * (3.5 + radius * 0.35))
		beside(function()
			cowInTheBackground(hall0, made)
		end)
		wait(0.4)
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
		wait(1.0)

		-- The pan end, worked out before the meat sets off: where the steak lies, how thick it is, how much room there is
		-- under the nozzle, and from that the press's size, how high it hovers and how tall the pile can stand.
		local panFloor = KitchenConfig.PanFloorHeight * KitchenConfig.PanScale - KitchenConfig.PanSink
		local zoneAt = if zone then (zone :: Model):GetPivot().Position else spot(WChewsLayout.PanColumns[5], WChewsLayout.PanRows[1])
		local target = zoneAt + up * panFloor
		local zoneHall = hall0:PointToObjectSpace(zoneAt)
		local tubeY = WChewsLayout.TubeHeight
		local served = zone and (zone :: Model):FindFirstChild("Steak")
		local steakModel: Model? = if served and served:IsA("Model") then served else nil
		local steakBase = if steakModel then steakModel:GetPivot() else CFrame.new(target) * CFrame.Angles(0, math.rad(18), 0)
		local thickness = if steakModel then steakModel:GetExtentsSize().Y else math.max(length * 0.135, 0.6)
		local steakTop = steakBase.Position.Y + thickness
		local nozzleBottom = hall0:PointToWorldSpace(Vector3.new(zoneHall.X, tubeY - NOZZLE_DROP, zoneHall.Z)).Y
		local room = nozzleBottom - 0.4 - steakTop
		local pressModel = prop("MeatPress")
		local pressScale, lift = 1, math.clamp(room * 0.5, 1.5, 5)
		if pressModel then
			local size = pressModel:GetExtentsSize()
			-- Big enough to cover the steak, but never so tall that it would reach the nozzle with 1.5 studs to lift in.
			pressScale = math.min(1.15 * length / math.max(size.X, 0.1), (room - 1.5) / math.max(size.Y, 0.1))
			if pressScale * size.X < length * 0.5 then
				pressModel = nil -- (no room for a press that covers even half the steak: the pile presses itself)
			else
				lift = math.clamp(room - size.Y * pressScale, 1.5, 7)
				table.insert(made, pressModel)
			end
		end
		local pile = prop("MincePile") or prop("MeatMound")
		local pileScale = 1
		if pile then
			table.insert(made, pile)
			pileScale = (thickness + lift * 0.6) / math.max(pile:GetExtentsSize().Y, 0.1)
			pile:ScaleTo(pileScale * 0.05)
			pile:PivotTo(CFrame.new(target))
		end

		-- 4. The tube: the funnel over the bay draws the meat up in lumps; they run along the overhead trunk, down the
		-- branch over the lifter's column of pans, and drop out of the nozzle onto the lifter's own pan.
		local path = {
			bayAt + up * math.min(radius, 6),
			spot(WChewsLayout.Bay.X, WChewsLayout.Bay.Y, tubeY),
			spot(WChewsLayout.Bay.X, WChewsLayout.TrunkY, tubeY),
			hall0:PointToWorldSpace(Vector3.new(zoneHall.X, tubeY, WChewsLayout.TrunkY)),
			hall0:PointToWorldSpace(Vector3.new(zoneHall.X, tubeY, zoneHall.Z)),
			hall0:PointToWorldSpace(Vector3.new(zoneHall.X, tubeY - NOZZLE_DROP, zoneHall.Z)),
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
		sound(KitchenConfig.Sounds.Tube, 0.7, SoundService) -- (3.2 s: the suction and the rush along the tube; the run takes 2.4 to 3.6)
		table.insert(connections, RunService.RenderStepped:Connect(function()
			local now = (os.clock() - streamStart) / slow()
			for _, lump in ipairs(lumps) do
				if not lump.done then
					local t = now - lump.delay
					if t >= travel then
						-- 5. A lump lands on the pan: the pile grows by it (user 2026-11-22: "instead of the meat plopping
						-- instantly to the steak ... the meat gets stacked up"), each with its own plop at its own pitch.
						lump.done = true
						lump.model.Parent = nil
						landed += 1
						if pile then
							pile:ScaleTo(pileScale * math.max(landed / math.max(#lumps, 1), 0.08))
							pile:PivotTo(CFrame.new(target))
							pile.Parent = Workspace
						end
						if landed == 1 then
							sound(KitchenConfig.Sounds.MeatLand, 0.8, SoundService)
						else
							sound(KitchenConfig.Sounds.Plop, 0.55, SoundService).PlaybackSpeed = 0.94 + 0.03 * (landed % 5)
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
		local drawUp = #lumps * KitchenConfig.TubeLumpGap + 0.9
		beside(function()
			if mound then
				local leaving = mound :: Model
				animate(drawUp, function(t)
					leaving:ScaleTo(moundScale * math.max(1 - t, 0.04))
					leaving:PivotTo(CFrame.new(bayAt))
				end, Enum.EasingStyle.Linear)
				leaving.Parent = nil
			end
		end)
		-- ONE shot of it (user 2026-11-22: "the first frame, when the meat first starts getting sucked in is enough we
		-- dont need the second frame"): low beside the bay, looking up at the funnel, well outside the bay's front corner
		-- (closer in, a post crossed the picture and the sign showed from behind). It holds until the first lump is
		-- nearly at the pan.
		-- (with the bay shots' longer lens, from the other front corner: the double door stands right of the bay here)
		bayShot(inKitchen(bayAt + hallVector(-26, 4.2, -50)), bayAt + up * 10.7)
		wait(math.max(travel - 0.6, 1.8))

		-- 5. At the lifter's pan: the lumps drop out of the nozzle and stack up. The camera stands on the pan's side away
		-- from the back wall's right end (the pan shots were framed from that point when the single staff door stood
		-- there, and are kept as they were) and stays here, only gliding, until the steak is cooked.
		local farCorner = spot(248, 266, 5)
		local away = Vector3.new(target.X - farCorner.X, 0, target.Z - farCorner.Z)
		away = if away.Magnitude > 1 then away.Unit else hallVector(0, 0, -1)
		camera.FieldOfView = usualFieldOfView
		shoot(inKitchen(target + away * (19 + length * 0.5) + up * (8 + length * 0.25)), target + up * 6, true)
		wait(0.6 + #lumps * KitchenConfig.TubeLumpGap + 0.7)

		-- 6. The giant meat press (user 2026-11-22: "a Giant meat presser ... that slams the meat and slowly lifts up
		-- which makes it form into a raw steak"). It slides in under the nozzle from the kitchen's middle aisle, hangs
		-- over the pile, slams down, holds, and lifts slowly off the raw steak. The raw steak is this screen's copy of
		-- the server's steak in the pan, in raw colours.
		local raw: Model? = nil
		local cooked: { { part: BasePart, colour: Color3, sear: boolean } } = {}
		if steakModel then
			local copy = steakModel:Clone()
			copy.Name = "KitchenRawSteak"
			for _, part in ipairs(copy:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
					part.CastShadow = false
					part.LocalTransparencyModifier = 0
					local sear = string.find(part.Name, "Sear", 1, true) ~= nil
					table.insert(cooked, { part = part, colour = part.Color, sear = sear })
					if sear then
						part.Transparency = 1
					elseif string.find(part.Name, "Meat", 1, true) then
						part.Color = RAW_MEAT
					elseif string.find(part.Name, "Fat", 1, true) then
						part.Color = RAW_FAT
					end
				end
			end
			table.insert(made, copy)
			raw = copy
		end
		local pressDown = CFrame.new(steakBase.Position.X, steakTop, steakBase.Position.Z) * steakBase.Rotation
		local function pressed(byPress: boolean)
			-- The moment the pile is pressed flat: it is gone, the raw steak lies there, and meat spits out sideways.
			if pile then
				pile.Parent = nil
			end
			if raw then
				raw.Parent = Workspace
			else
				hideSteak(zone :: Model?, false)
			end
			burst(target + up * 0.6, Color3.fromRGB(205, 82, 80), 26, 0.6, 0.25, 220)
			if byPress then
				sound(KitchenConfig.Sounds.PressSlam, 1, SoundService) -- (its loudest moment is its start: the plate landing)
			else
				sound(KitchenConfig.Sounds.BagThud, 1, SoundService)
				sound(KitchenConfig.Sounds.MeatLand, 0.9, SoundService)
			end
			shakeCamera(0.35, 0.5)
		end
		if pressModel then
			local machine = pressModel :: Model
			local hover = pressDown + up * lift
			-- (from the middle aisle's side, along the row: the tube's branch runs along the column, so nothing hangs in
			--  the way across it)
			local fromSide = hallVector(if zoneHall.X >= 0 then -1 else 1, 0, 0)
			local enter = hover + fromSide * (machine:GetExtentsSize().X * pressScale * 0.6 + 16)
			machine:ScaleTo(pressScale)
			machine:PivotTo(enter)
			machine.Parent = Workspace
			-- (closer in for the press)
			shoot(inKitchen(target + away * (15 + length * 0.45) + up * (6.5 + length * 0.2)), target + up * (thickness + lift * 0.5))
			animate(PRESS.SlideIn, function(t)
				machine:PivotTo(enter:Lerp(hover, t))
			end, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			wait(PRESS.Pause)
			local pileFull = if pile then (pile :: Model):GetScale() else 1
			animate(PRESS.Slam, function(t)
				machine:PivotTo(hover:Lerp(pressDown, t))
				if pile and (pile :: Model).Parent then
					-- (the pile gives way under the plate)
					(pile :: Model):ScaleTo(pileFull * math.max(1 - 0.7 * t, 0.05))
					;(pile :: Model):PivotTo(CFrame.new(target))
				end
			end, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			pressed(true)
			wait(PRESS.Hold)
			sound(KitchenConfig.Sounds.PressLift, 0.8, SoundService) -- (the wet peel as the plate lets go of the meat)
			animate(PRESS.Lift, function(t)
				machine:PivotTo(pressDown:Lerp(hover, t))
			end, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			wait(0.5)
			beside(function()
				animate(PRESS.SlideOut, function(t)
					machine:PivotTo(hover:Lerp(enter, t))
				end, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				machine.Parent = nil
			end)
		else
			-- (the press's model didn't load: the pile presses itself flat in a puff)
			pressed(false)
			wait(0.8)
		end

		-- 7. The raw steak cooks: steam, the sizzle, the meat browns and the sear marks come up; then it IS the server's
		-- steak (the copy goes, the real one shows: the same thing in the same place).
		shoot(inKitchen(target + away * (22 + length * 0.55) + up * (12 + length * 0.3)), target + up * 1.5)
		if raw then
			sound(KitchenConfig.Sounds.Sizzle, 0.7, SoundService)
			burst(target + up * 1, Color3.fromRGB(240, 240, 240), 9, 2.4, COOK_SECONDS, 34)
			animate(COOK_SECONDS, function(t)
				for _, piece in ipairs(cooked) do
					if piece.sear then
						piece.part.Transparency = 1 - math.clamp((t - 0.35) / 0.65, 0, 1)
					elseif piece.part.Color ~= piece.colour or t < 1 then
						local from = if string.find(piece.part.Name, "Meat", 1, true) then RAW_MEAT
							elseif string.find(piece.part.Name, "Fat", 1, true) then RAW_FAT
							else piece.colour
						piece.part.Color = from:Lerp(piece.colour, t)
					end
				end
			end, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			hideSteak(zone :: Model?, false)
			;(raw :: Model).Parent = nil
		else
			burst(target + up * 1, Color3.fromRGB(240, 240, 240), 10, 2.5, 1.2, 40)
		end
		-- (a slow pull back off the finished steak)
		shoot(inKitchen(target + away * (26 + length * 0.6) + up * (18 + length * 0.4)), target)
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
	camera.FieldOfView = usualFieldOfView
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
