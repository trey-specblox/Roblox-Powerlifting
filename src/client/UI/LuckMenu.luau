--!strict
--[[
	LuckMenu
	Client / UI

	Talking to the mafia boss cow in W Chews' back room (GAME_DESIGN §40.7, user 2026-11-21; LuckConfig). His "Talk"
	prompt (KitchenBackRoom) opens the NPC dialogue the coaches and the chef use (CoachDialogue.converse), then:

		SPIN THE WHEEL   the WHEEL OF LUCK card, built from the UI kit (UIFancy: turning rays, a glow, outlined words,
		                 a glossy button): every band of results with its colour and its real chance, your luck now,
		                 and SPIN. A spin turns the real wheel in the room to the wedge the SERVER rolled, the camera on
		                 it, the pegs ticking past the pointer; then the band's results roll past in the pop and stop
		                 on the one the server drew.
		PLAY THE SHUFFLE "follow the steak": the cow shows a steak under one of three cloches on his table, swaps them
		                 faster and faster for 11 seconds, and you pick one before a 10 second countdown runs out. Win
		                 and you get a spin. Costs one of the day's tries, never anything else.

	Display only. The server rolls the wedge, decides where the steak starts and every swap, knows where it ended and
	gives the spin (LuckService); this screen only shows what it was told and sends the cloche that was picked.

	Everything that moves is on this screen only: the wheel's turn, the cloches, a copy of the cow at his table (the
	standing cow is hidden meanwhile: he can't be in two places).

	PERFORMANCE: one screen, built once; a per-frame step only while the wheel turns or the cloches move.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))
local LuckConfig = require(Shared:WaitForChild("Config"):WaitForChild("LuckConfig"))
local WChewsLayout = require(Shared:WaitForChild("Config"):WaitForChild("WChewsLayout"))
local LuckRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("LuckRemotes"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local UIFancy = require(script.Parent:WaitForChild("UIFancy"))
local BoostBar = require(script.Parent:WaitForChild("BoostBar"))
local CoachDialogue = require(script.Parent:WaitForChild("CoachDialogue"))
local PromptController = require(script.Parent:WaitForChild("PromptController"))

local make, corner, outline, glow, words = UIFancy.make, UIFancy.corner, UIFancy.outline, UIFancy.glow, UIFancy.words
local WHITE = UIFancy.White

local LuckMenu = {}

local CARD = Vector2.new(620, 560)
local FELT_TOP, FELT_BOTTOM = Color3.fromRGB(20, 92, 60), Color3.fromRGB(8, 34, 26)
local GOLD_TOP, GOLD_BOTTOM = Color3.fromRGB(255, 226, 92), Color3.fromRGB(232, 160, 24)
local GREY_TOP, GREY_BOTTOM = Color3.fromRGB(150, 150, 156), Color3.fromRGB(92, 92, 100)
local GREEN = Color3.fromRGB(110, 236, 96)
local RED = Color3.fromRGB(255, 110, 100)
local INSET = Color3.fromRGB(8, 26, 20)

local SPIN_SECONDS = 6
local SPIN_TURNS = 5
local CLOCHE_LIFT = 2.4

local started = false
local busy = false

local function hallOrigin(): CFrame
	return KitchenConfig.HallOrigin
end

local function planPoint(x: number, y: number, z: number): Vector3
	return (hallOrigin() * KitchenConfig.planSpot(x, y, z)).Position
end

local function playSound(id: string?, volume: number, speed: number?)
	if id == nil or id == "" then
		return
	end
	local made = Instance.new("Sound")
	made.SoundId = id
	made.Volume = volume
	made.PlaybackSpeed = speed or 1
	made.Parent = Workspace
	made:Play()
	made.Ended:Once(function()
		made:Destroy()
	end)
	task.delay(12, function()
		if made.Parent then
			made:Destroy()
		end
	end)
end

-- Runs `step(share)` every frame for `seconds` (share 0 -> 1, eased).
local function animate(seconds: number, step: (number) -> (), style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local begun = os.clock()
	while true do
		local share = math.clamp((os.clock() - begun) / seconds, 0, 1)
		step(TweenService:GetValue(share, style or Enum.EasingStyle.Sine, direction or Enum.EasingDirection.InOut))
		if share >= 1 then
			return
		end
		RunService.RenderStepped:Wait()
	end
end

-- Holds the player still (walking and jumping to zero on this client's own character) and puts it back.
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

local function hideParts(model: Instance?, hidden: boolean)
	if model == nil then
		return
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("Decal") then
			(part :: any).LocalTransparencyModifier = if hidden then 1 else 0
		elseif part:IsA("BillboardGui") then
			part.Enabled = not hidden -- (a hidden figure's name tag goes with it)
		end
	end
end

-- The camera held on a shot (gliding to it), until released.
local shotFrom, shotAt = Vector3.zero, Vector3.zero
local camFrom, camAt = Vector3.zero, Vector3.zero
local shooting = false
local function shoot(from: Vector3, at: Vector3)
	shotFrom, shotAt = from, at
	if shooting then
		return
	end
	shooting = true
	local camera = Workspace.CurrentCamera
	camFrom, camAt = camera.CFrame.Position, camera.CFrame.Position + camera.CFrame.LookVector * 12
	RunService:BindToRenderStep("LuckMenuCamera", Enum.RenderPriority.Camera.Value + 2, function(dt)
		local follow = 1 - math.exp(-dt / 0.3)
		camFrom = camFrom:Lerp(shotFrom, follow)
		camAt = camAt:Lerp(shotAt, follow)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(camFrom, camAt)
		camera.Focus = CFrame.new(camAt)
	end)
end
local function releaseCamera()
	if shooting then
		shooting = false
		RunService:UnbindFromRenderStep("LuckMenuCamera")
		Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end
end

local function backRoom(): Instance?
	local hall = Workspace:FindFirstChild("KitchenHall")
	return hall and hall:FindFirstChild("BackRoom")
end

-- "23:10:05" / "5:02".
local function clockText(seconds: number): string
	return KitchenConfig.clockText(seconds)
end

function LuckMenu.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remotes = LuckRemotes.waitForClient(ReplicatedStorage)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Luck"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 32
	UIStyle.fitToScreen(gui)

	------------------------------------------------------------------ the wheel card
	local card = make("Frame", {
		Name = "WheelCard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CARD.X, CARD.Y), BackgroundTransparency = 1, Visible = false, Parent = gui,
	})
	local scene = make("Frame", {
		Name = "Scene", BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ClipsDescendants = true,
		Parent = card,
	})
	corner(scene, UDim.new(0, 22))
	outline(scene, 4)
	glow(scene, Color3.fromRGB(255, 210, 110), 40, 0.55)
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(FELT_TOP, FELT_BOTTOM), Parent = scene })
	local rays = UIFancy.rays(scene, UDim2.fromScale(0.5, 0.2), 900, 14, Color3.fromRGB(255, 220, 120))
	UIFancy.vignette(scene, 0.12, 0.3)
	local title = words(scene, "Title", UDim2.fromOffset(0, 14), UDim2.new(1, 0, 0, 62), 54, 5, Color3.fromRGB(255, 226, 92))
	title.Text = "WHEEL OF LUCK"
	local subtitle = words(scene, "Sub", UDim2.fromOffset(30, 76), UDim2.new(1, -60, 0, 44), 19, 2.5)
	subtitle.Text = "Luck multiplies your chance of the rare results in crates, celebration spins and rare suit drops."
	local closeButton = UIFancy.button(scene, "Close", "X", UDim2.new(1, -62, 0, 12), UDim2.fromOffset(48, 44),
		Color3.fromRGB(240, 90, 80), Color3.fromRGB(170, 36, 36), 26, function() end)

	-- Every band of results: its colour, its multipliers and its real chance (the band's wedges out of the wheel's 20).
	local list = make("Frame", {
		Name = "Prizes", Position = UDim2.fromOffset(34, 132), Size = UDim2.new(1, -68, 0, 228), BackgroundColor3 = INSET,
		BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = scene,
	})
	corner(list, UDim.new(0, 14))
	outline(list, 2, Color3.fromRGB(255, 226, 92), 0.4)
	local heading = words(list, "Heading", UDim2.fromOffset(16, 6), UDim2.new(1, -32, 0, 24), 17, 2)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Text = "WHERE A SPIN CAN LAND, AND THE CHANCE OF EACH:"
	local ordered = table.clone(LuckConfig.Prizes)
	table.sort(ordered, function(a, b)
		return a.high > b.high
	end)
	for index, prize in ipairs(ordered) do
		local column, row = (index - 1) % 2, (index - 1) // 2
		local cell = make("Frame", {
			Name = prize.id, Position = UDim2.new(column * 0.5, 14, 0, 38 + row * 62), Size = UDim2.new(0.5, -22, 0, 54),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = list,
		})
		corner(cell, UDim.new(0, 12))
		local chip = make("Frame", {
			Name = "Chip", Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(158, 42), BackgroundColor3 = prize.colour,
			BorderSizePixel = 0, Parent = cell,
		})
		corner(chip, UDim.new(0, 10))
		outline(chip, 2.5)
		local amount = words(chip, "Amount", UDim2.fromOffset(6, 4), UDim2.new(1, -12, 1, -8), 24, 0, prize.ink)
		amount.TextWrapped = false
		amount.TextScaled = true
		make("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 12, Parent = amount })
		amount.Text = LuckConfig.bandText(prize)
		local chance = words(cell, "Chance", UDim2.fromOffset(172, 0), UDim2.new(1, -178, 1, 0), 26, 3)
		chance.TextXAlignment = Enum.TextXAlignment.Left
		chance.Text = LuckConfig.percentText(LuckConfig.chance(prize))
	end

	local nowLine = words(scene, "Now", UDim2.fromOffset(30, 368), UDim2.new(1, -60, 0, 30), 24, 3)
	local noteLine = words(scene, "Note", UDim2.fromOffset(30, 398), UDim2.new(1, -60, 0, 44), 18, 2.5, Color3.fromRGB(255, 214, 190))
	-- (short enough for two lines of the card: a longer note didn't fit; Studio 2026-11-22)
	noteLine.Text = string.format("Results in a band are equally likely. A new spin replaces your luck. Good luck lasts %d hours, bad luck %d.",
		LuckConfig.LuckHours, LuckConfig.BadLuckHours)
	noteLine.TextScaled = true
	-- (the least size is in screen pixels: low enough for the card shrunk to a phone's height)
	make("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 6, Parent = noteLine })
	local spinButton, spinGradient, spinLabel = UIFancy.button(scene, "Spin", "SPIN!", UDim2.new(0.5, -170, 1, -104),
		UDim2.fromOffset(340, 78), GOLD_TOP, GOLD_BOTTOM, 40, function() end)
	-- (its words change: they shrink to fit the button)
	spinLabel.Position, spinLabel.Size = UDim2.fromOffset(14, 8), UDim2.new(1, -28, 1, -16)
	spinLabel.TextScaled = true
	make("UITextSizeConstraint", { MaxTextSize = 40, MinTextSize = 16, Parent = spinLabel })

	------------------------------------------------------------------ the result pop and the game's words
	local pop = make("Frame", {
		Name = "Pop", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(700, 210),
		BackgroundTransparency = 1, Visible = false, Parent = gui,
	})
	-- (its own box inside: the screen-fitting scale lives on `pop`, the pop-in scale on the box)
	local popBox = make("Frame", { Name = "Box", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = pop })
	local halo = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 130),
		BackgroundColor3 = Color3.fromRGB(255, 200, 90), BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = popBox,
	})
	corner(halo, UDim.new(1, 0))
	glow(halo, Color3.fromRGB(255, 210, 120), 120, 0.2)
	local popHead = words(popBox, "Headline", UDim2.fromScale(0, 0.02), UDim2.new(1, 0, 0, 100), 84, 5)
	local popSub = words(popBox, "Line", UDim2.fromScale(0, 0.56), UDim2.new(1, 0, 0, 60), 38, 4, GREEN)
	local popScale = make("UIScale", { Parent = popBox })
	local popToken = 0
	local function showPop(headline: string, line: string, colour: Color3, lineColour: Color3, seconds: number)
		popToken += 1
		local mine = popToken
		popHead.Text, popHead.TextColor3 = headline, colour
		popSub.Text, popSub.TextColor3 = line, lineColour
		halo.BackgroundColor3 = colour
		pop.Visible = true
		popScale.Scale = 0.3
		TweenService:Create(popScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(seconds, function()
			if popToken == mine then
				TweenService:Create(popScale, TweenInfo.new(0.3), { Scale = 0 }):Play()
				task.wait(0.32)
				if popToken == mine then
					pop.Visible = false
				end
			end
		end)
	end

	local caption = words(gui, "Caption", UDim2.new(0.5, -400, 0, 70), UDim2.fromOffset(800, 60), 44, 4)
	caption.Visible = false
	local picks = make("Frame", {
		Name = "Picks", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -70), Size = UDim2.fromOffset(660, 84),
		BackgroundTransparency = 1, Visible = false, Parent = gui,
	})
	-- The time left to pick, draining above the three buttons.
	local timerTrack = make("Frame", {
		Name = "Timer", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -14), Size = UDim2.new(1, -30, 0, 14),
		BackgroundColor3 = INSET, BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = picks,
	})
	corner(timerTrack, UDim.new(1, 0))
	outline(timerTrack, 2.5)
	local timerFill = make("Frame", {
		Name = "Left", BackgroundColor3 = GOLD_TOP, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = timerTrack,
	})
	corner(timerFill, UDim.new(1, 0))
	local picked: number? = nil
	for index, name in ipairs({ "LEFT", "MIDDLE", "RIGHT" }) do
		UIFancy.button(picks, name, name, UDim2.fromOffset((index - 1) * 225, 0), UDim2.fromOffset(210, 84), GOLD_TOP, GOLD_BOTTOM,
			34, function()
				picked = index
			end)
	end

	gui.Parent = player:WaitForChild("PlayerGui")

	------------------------------------------------------------------ the luck view
	local view: any = nil
	local viewAt = os.clock()
	local function fetch(): any
		for _ = 1, 4 do
			local ok, fresh = pcall(function()
				return remotes.get:InvokeServer()
			end)
			if ok and typeof(fresh) == "table" then
				view, viewAt = fresh, os.clock()
				return fresh
			end
			task.wait(0.6)
		end
		return view
	end
	local function keep(fresh: any)
		if typeof(fresh) == "table" and typeof(fresh.multiplier) == "number" then
			view, viewAt = fresh, os.clock()
		end
	end

	local function canSpin(): boolean
		return view ~= nil and (view.freeSpin == true or view.spins >= 1)
	end
	local function drawCard()
		if view == nil then
			nowLine.Text = ""
			return
		end
		local left = math.max(0, view.secondsLeft - (os.clock() - viewAt))
		if view.multiplier ~= 1 and left > 0 then
			nowLine.Text = string.format("YOUR LUCK NOW: %s  (%s left)", LuckConfig.multiplierText(view.multiplier), clockText(left))
			nowLine.TextColor3 = if view.multiplier < 1 then RED else GREEN
		else
			nowLine.Text = "YOUR LUCK NOW: 1x  (none)"
			nowLine.TextColor3 = WHITE
		end
		if view.freeSpin then
			spinLabel.Text = "FREE SPIN!"
			spinGradient.Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM)
		elseif view.spins >= 1 then
			spinLabel.Text = string.format("SPIN!  (%d WON)", view.spins)
			spinGradient.Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM)
		else
			spinLabel.Text = "BEAT THE BOSS FOR A SPIN"
			spinGradient.Color = ColorSequence.new(GREY_TOP, GREY_BOTTOM)
		end
	end

	local cardOpen = false
	local function closeCard()
		cardOpen = false
		card.Visible = false
		PromptController.hide("LuckCard", false)
	end
	local function openCard()
		drawCard()
		cardOpen = true
		card.Visible = true
		PromptController.hide("LuckCard", true)
		task.spawn(function()
			local turn = 0
			local redrawAt = 0
			while cardOpen do
				local dt = RunService.RenderStepped:Wait()
				turn += dt * 8
				rays.Rotation = turn
				if os.clock() >= redrawAt then
					redrawAt = os.clock() + 1
					drawCard()
				end
			end
		end)
	end
	closeButton.Activated:Connect(closeCard)

	------------------------------------------------------------------ the spin: the real wheel turns to the server's wedge
	local function wheelAngle(wheel: Model, axis: CFrame): number
		local _, _, z = axis:ToObjectSpace(wheel:GetPivot()):ToEulerAnglesXYZ()
		return z
	end
	local function spin()
		if busy or not canSpin() then
			return
		end
		busy = true
		closeCard()
		-- (the luck chip keeps showing the old luck until the wheel has stopped: the server has already set the new one)
		BoostBar.holdLuck(true)
		local ok, answer = pcall(function()
			return remotes.spin:InvokeServer()
		end)
		if not ok or typeof(answer) ~= "table" then
			BoostBar.holdLuck(false)
			busy = false
			return
		end
		keep(answer.view)
		if answer.outcome ~= "Spun" or typeof(answer.wedge) ~= "number" then
			BoostBar.holdLuck(false)
			busy = false
			showPop(if answer.outcome == "TooFar" then "COME CLOSER" else "NO SPIN", if answer.outcome == "NoSpins"
				then "Beat the Boss to win one" else "Try again", WHITE, WHITE, 2)
			return
		end
		local prize = LuckConfig.wedgePrize(answer.wedge)
		local room = backRoom()
		local wheel = room and room:FindFirstChild("LuckWheel")
		local layout = WChewsLayout
		local axis = hallOrigin() * KitchenConfig.planSpot(layout.Wheel.X, layout.Wheel.Y, layout.WheelAxis)
		PromptController.hide("LuckSpin", true)
		controls(false)
		hideParts(player.Character, true)
		shoot(planPoint(layout.Wheel.X - 2.5, layout.Wheel.Y - 15.5, layout.WheelAxis + 0.6),
			planPoint(layout.Wheel.X, layout.Wheel.Y, layout.WheelAxis + 0.4))
		task.wait(0.7)
		if wheel and wheel:IsA("Model") and prize then
			local step = 2 * math.pi / LuckConfig.WedgeCount
			local from = wheelAngle(wheel, axis)
			-- Wedge i stands (i - 1) steps clockwise of the top: turning the wheel back by that brings it under the
			-- pointer. A little off the wedge's middle each time, so it doesn't always stop dead centre.
			local target = -(answer.wedge - 1) * step + (math.random() - 0.5) * step * 0.6
			local total = SPIN_TURNS * 2 * math.pi + ((target - from) % (2 * math.pi))
			local lastPeg = math.floor(from / step)
			local lastTick = 0
			animate(SPIN_SECONDS, function(share)
				local angle = from + total * share
				wheel:PivotTo(axis * CFrame.Angles(0, 0, angle))
				local peg = math.floor(angle / step)
				if peg ~= lastPeg and os.clock() - lastTick > 0.045 then
					lastPeg, lastTick = peg, os.clock()
					playSound(KitchenConfig.Sounds.WheelTick, 0.5, 0.95 + math.random() * 0.1)
				end
			end, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		else
			task.wait(1)
		end
		local won: number? = if typeof(answer.multiplier) == "number" then answer.multiplier else nil
		if prize and won then
			-- The wheel stopped on a band: its results roll past in the pop, slower and slower, and stop on the one
			-- the server drew.
			local values = LuckConfig.bandValues(prize)
			showPop("LUCK ?", LuckConfig.bandText(prize), prize.colour, WHITE, 30)
			if #values > 1 then
				local shown = 0
				for index = 1, 18 do
					shown = (shown + math.random(1, #values - 1) - 1) % #values + 1 -- (never the same one twice running)
					popHead.Text = "LUCK " .. LuckConfig.multiplierText(values[shown])
					playSound(KitchenConfig.Sounds.WheelTick, 0.45, 1.25)
					task.wait(0.045 + index * 0.011)
				end
			end
			BoostBar.holdLuck(false)
			if won > 1 then
				playSound(KitchenConfig.Sounds.WheelWin, 0.7)
			elseif won < 1 then
				playSound(KitchenConfig.Sounds.WheelLow, 0.7)
			end
			showPop("LUCK " .. LuckConfig.multiplierText(won), if won > 1 then string.format("for %d hours!", LuckConfig.hoursFor(won))
				elseif won < 1 then string.format("ouch... for %d hours", LuckConfig.hoursFor(won))
				else "no luck, no harm", prize.colour, if won > 1 then GREEN elseif won < 1 then RED else WHITE, 3)
		else
			BoostBar.holdLuck(false)
		end
		task.wait(3.2)
		releaseCamera()
		hideParts(player.Character, false)
		controls(true)
		PromptController.hide("LuckSpin", false)
		busy = false
	end
	spinButton.Activated:Connect(function()
		task.spawn(spin)
	end)

	------------------------------------------------------------------ the shuffle: follow the steak
	-- The cow's own copy at the table, his right arm lifted over it by `lift` (0..1): the ArmR pieces turn round his
	-- shoulder (rigid pieces, no skeleton: WChewsLayout.CowShoulder).
	local function cowAt(stand: CFrame): (Model?, (number) -> ())
		local folder = ReplicatedStorage:FindFirstChild("KitchenModels")
		local source = folder and folder:FindFirstChild("CowBoss")
		if source == nil or not source:IsA("Model") then
			return nil, function() end
		end
		local copy = source:Clone()
		for _, part in ipairs(copy:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
			elseif part:IsA("BillboardGui") or part:IsA("ProximityPrompt") then
				part:Destroy()
			end
		end
		local offset = WChewsLayout.PivotOffset.CowBoss
		copy:PivotTo(stand * CFrame.new(-offset.X, offset.Z, offset.Y))
		copy.Parent = Workspace
		local shoulder = WChewsLayout.CowShoulder
		local joint = stand * CFrame.new(-shoulder.X, shoulder.Z, shoulder.Y)
		local arm: { { part: BasePart, home: CFrame } } = {}
		for _, part in ipairs(copy:GetDescendants()) do
			if part:IsA("BasePart") and string.find(part.Name, "CowBoss_ArmR", 1, true) then
				table.insert(arm, { part = part, home = joint:ToObjectSpace(part.CFrame) })
			end
		end
		return copy, function(lift: number)
			-- (forward and up: his hoof out over the table)
			local turned = joint * CFrame.Angles(math.rad(78) * lift, 0, 0)
			for _, piece in ipairs(arm) do
				piece.part.CFrame = turned * piece.home
			end
		end
	end

	local function playShuffle()
		if busy then
			return
		end
		busy = true
		local ok, answer = pcall(function()
			return remotes.gameStart:InvokeServer("Shuffle")
		end)
		if not ok or typeof(answer) ~= "table" then
			busy = false
			return
		end
		keep(answer.view)
		if answer.outcome ~= "Started" or typeof(answer.start) ~= "number" or typeof(answer.swaps) ~= "table" then
			busy = false
			showPop(if answer.outcome == "NoTries" then "NO TRIES LEFT" elseif answer.outcome == "TooFar" then "COME CLOSER"
				else "NOT NOW", if answer.outcome == "NoTries" then "Come back tomorrow" else "Try again", WHITE, WHITE, 2.2)
			return
		end
		local layout = WChewsLayout
		local hall = Workspace:FindFirstChild("KitchenHall")
		local kit = hall and hall:FindFirstChild("WChewsKit")
		local room = backRoom()
		-- The three cloches on the table, left to right from the player's side (plan x rising).
		local cloches: { Model } = {}
		if kit then
			for _, child in ipairs(kit:GetChildren()) do
				if child.Name == "WcCloche" and child:IsA("Model") then
					table.insert(cloches, child)
				end
			end
		end
		local origin = hallOrigin()
		table.sort(cloches, function(a, b)
			return origin:PointToObjectSpace(a:GetPivot().Position).X > origin:PointToObjectSpace(b:GetPivot().Position).X
		end)
		if #cloches ~= 3 then
			busy = false
			return
		end
		local table0 = layout.ShuffleTable
		local homes: { CFrame } = {}
		for index, cloche in ipairs(cloches) do
			homes[index] = cloche:GetPivot()
		end
		-- slots[place] = the cloche standing at that place now.
		local slots = table.clone(cloches)
		PromptController.hide("LuckGame", true)
		controls(false)
		hideParts(player.Character, true)
		local standing = room and room:FindFirstChild("CowBoss")
		hideParts(standing, true)
		local cowStand = origin * KitchenConfig.planSpot(table0.X, table0.Y + 4.7, 0)
		local cow, liftArm = cowAt(cowStand)
		shoot(planPoint(table0.X, table0.Y - 10.5, 9.2), planPoint(table0.X, table0.Y + 0.6, layout.TableTop + 0.5))

		-- The steak: a small copy of the big steak, lying on the table under its cloche.
		local steak: Model? = nil
		local models = ReplicatedStorage:FindFirstChild("KitchenModels")
		local bigSteak = models and models:FindFirstChild("BigSteak")
		if bigSteak and bigSteak:IsA("Model") then
			local copy = bigSteak:Clone()
			for _, part in ipairs(copy:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
					part.CastShadow = false
				end
			end
			copy:ScaleTo(1.25 / math.max(copy:GetExtentsSize().X, 0.1))
			steak = copy
		end
		local steakAt = answer.start :: number
		local function placeSteak()
			if steak then
				local at = homes[steakAt]
				steak:PivotTo(CFrame.new(at.Position) * CFrame.Angles(0, math.rad(20), 0))
			end
		end
		local function raise(cloche: Model, home: CFrame, from: number, to: number, seconds: number)
			animate(seconds, function(share)
				cloche:PivotTo(home + Vector3.new(0, from + (to - from) * share, 0))
			end)
		end

		local okPlay, problem = pcall(function()
			task.wait(0.8)
			caption.Text = "WATCH THE STEAK"
			caption.Visible = true
			-- The show: the steak's cloche lifts, the steak is there, the cloche comes down.
			placeSteak()
			if steak then
				steak.Parent = Workspace
			end
			playSound(KitchenConfig.Sounds.ClocheLift, 0.6)
			raise(slots[steakAt], homes[steakAt], 0, CLOCHE_LIFT, 0.45)
			task.wait(0.85)
			raise(slots[steakAt], homes[steakAt], CLOCHE_LIFT, 0, 0.45)
			task.wait(0.3)
			-- The swaps: two cloches change places, one passing in front and one behind; the steak rides its cloche.
			animate(0.3, function(share)
				liftArm(share)
			end)
			for index, swap in ipairs(answer.swaps :: { any }) do
				local a, b = swap[1], swap[2]
				if typeof(a) ~= "number" or typeof(b) ~= "number" or slots[a] == nil or slots[b] == nil or a == b then
					continue
				end
				local first, second = slots[a], slots[b]
				local fromA, fromB = homes[a], homes[b]
				local bulge = (fromA.Position - fromB.Position).Magnitude * 0.28
				local sideways = (origin * KitchenConfig.planSpot(0, 1, 0)).Position - origin.Position -- plan +y in the world
				playSound(KitchenConfig.Sounds.ClocheSlide, 0.35, 0.9 + 0.3 * (index / #(answer.swaps :: { any })))
				animate(LuckConfig.swapSeconds(index), function(share)
					local arc = math.sin(share * math.pi) * bulge
					first:PivotTo(fromA:Lerp(fromB, share) + sideways * arc)
					second:PivotTo(fromB:Lerp(fromA, share) - sideways * arc)
					if steak and (steakAt == a or steakAt == b) then
						local rider = if steakAt == a then first else second
						steak:PivotTo(CFrame.new(rider:GetPivot().Position) * CFrame.Angles(0, math.rad(20), 0))
					end
				end)
				slots[a], slots[b] = second, first
				if steakAt == a then
					steakAt = b
				elseif steakAt == b then
					steakAt = a
				end
			end
			animate(0.3, function(share)
				liftArm(1 - share)
			end)
			-- The pick.
			-- The pick, against the clock (user 2026-11-22: a 10 second limit): the seconds count down in the caption
			-- and the bar above the buttons drains, red and ticking for the last three.
			picked = nil
			picks.Visible = true
			local answerSeconds = LuckConfig.Shuffle.AnswerSeconds
			local deadline = os.clock() + answerSeconds
			local lastSecond = -1
			while picked == nil and os.clock() < deadline do
				local left = deadline - os.clock()
				local second = math.ceil(left)
				if second ~= lastSecond then
					lastSecond = second
					caption.Text = string.format("WHERE IS THE STEAK?  %d", second)
					if second <= 3 then
						playSound(KitchenConfig.Sounds.WheelTick, 0.5, 0.8)
					end
				end
				timerFill.Size = UDim2.fromScale(math.clamp(left / answerSeconds, 0, 1), 1)
				timerFill.BackgroundColor3 = if left <= 3 then RED else GOLD_TOP
				task.wait(0.03)
			end
			picks.Visible = false
			local choice = picked
			if choice == nil then
				caption.Text = "TOO SLOW!"
				task.wait(1.6)
				fetch()
				return
			end
			local okFinish, result = pcall(function()
				return remotes.gameFinish:InvokeServer(choice)
			end)
			local final = if okFinish and typeof(result) == "table" and typeof(result.final) == "number" then result.final else steakAt
			if okFinish and typeof(result) == "table" then
				keep(result.view)
			end
			local won = okFinish and typeof(result) == "table" and result.outcome == "Won"
			-- The reveal: the picked cloche lifts; if the steak isn't there, so does the one it is under.
			caption.Visible = false
			playSound(KitchenConfig.Sounds.ClocheLift, 0.6)
			raise(slots[choice], homes[choice], 0, CLOCHE_LIFT, 0.4)
			if final ~= choice and slots[final] then
				task.wait(0.5)
				playSound(KitchenConfig.Sounds.ClocheLift, 0.6)
				raise(slots[final], homes[final], 0, CLOCHE_LIFT, 0.4)
			end
			local tries = if view then view.triesLeft else 0
			if won then
				playSound(KitchenConfig.Sounds.WheelWin, 0.7)
				showPop("YOU WIN!", "+1 SPIN OF THE WHEEL", Color3.fromRGB(255, 226, 92), GREEN, 2.8)
			else
				playSound(KitchenConfig.Sounds.WheelLow, 0.7)
				showPop("NOT THIS TIME", string.format("%d %s left today", tries, if tries == 1 then "try" else "tries"), WHITE, RED, 2.8)
			end
			task.wait(3)
		end)
		if not okPlay then
			warn("[LuckMenu] " .. tostring(problem))
		end
		-- Everything back where the server has it.
		caption.Visible = false
		picks.Visible = false
		for index, cloche in ipairs(cloches) do
			cloche:PivotTo(homes[index])
		end
		if steak then
			steak:Destroy()
		end
		if cow then
			cow:Destroy()
		end
		hideParts(standing, false)
		releaseCamera()
		hideParts(player.Character, false)
		controls(true)
		PromptController.hide("LuckGame", false)
		busy = false
	end

	------------------------------------------------------------------ the cow's conversation
	local function talk()
		local converse = CoachDialogue.converse
		local room = backRoom()
		local figure = room and room:FindFirstChild("CowBoss")
		if converse == nil or figure == nil or not figure:IsA("Model") or busy or cardOpen then
			return
		end
		fetch()
		playSound(KitchenConfig.Sounds.BossMoo, 0.6)
		local wants: string? = nil
		converse(figure, "The Boss", function(say, ask)
			if view and view.freeSpin then
				say("Moo. You look lucky today, kid. First spin of the day is on the house.")
			elseif view and view.spins >= 1 then
				say("You've got a spin coming. The wheel's waiting.")
			else
				say("You want another spin? Beat me at my game first.")
			end
			while true do
				local choice = ask({
					{ text = "Spin the wheel", value = "Wheel" },
					{ text = "Play the shuffle", value = "Shuffle" },
					{ text = "Bye.", value = "Bye" },
				})
				if choice == nil or choice == "Bye" then
					return
				elseif choice == "Wheel" then
					wants = "Wheel"
					return
				elseif view and view.triesLeft < 1 then
					say("That's enough for one day. Come back tomorrow.")
				else
					say("Three cloches, one steak. Keep your eyes on it. Find it in ten seconds and you win a spin.")
					wants = "Shuffle"
					return
				end
			end
		end)
		if wants == "Wheel" then
			openCard()
		elseif wants == "Shuffle" then
			playShuffle()
		end
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredBy)
		if triggeredBy == player and prompt:HasTag(LuckRemotes.PromptTag) then
			task.spawn(talk)
		end
	end)
end

return LuckMenu
