--!strict
--[[
	CelebrationViewer
	Client / UI

	The celebrations, to click through and quick-watch (user 2026-11-11: "make sure i can click through them to inspect,
	Give me the ability to quick watch them"). Opened from the admin panel for now (the user: only them for testing);
	when celebrations come from crates, every player opens it to see what they could unbox.

		on the left   a copy of your own avatar on a small lit stage, playing the chosen celebration over and over
		              (a "Walk" one over a walk, as in a meet), with its sounds; 3/4, FRONT or SIDE view; SLOW-MO
		on the right  every celebration by rarity (CelebrationConfig.List): its name, rarity, length, the real meet it
		              came from and what happens in it
		buttons       < PREV, REPLAY, NEXT >, PLAY ON ME (admin: plays it on your real character for everyone, with its
		              cinematic if it has one; AdminService "PlayCelebration" checks the account), CLOSE

	Display only: the copy lives in this screen's ViewportFrame; nothing is saved or given.
	PERFORMANCE: one avatar copy and two animation tracks while open; nothing when closed. (Chalk particles don't show in
	a ViewportFrame: PLAY ON ME shows them.)
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CelebrationConfig = require(Shared:WaitForChild("Config"):WaitForChild("CelebrationConfig"))
local GearStatsConfig = require(Shared:WaitForChild("Config"):WaitForChild("GearStatsConfig"))
local MeetSoundConfig = require(Shared:WaitForChild("Config"):WaitForChild("MeetSoundConfig"))
local AdminRemotes = require(Shared:WaitForChild("Admin"):WaitForChild("AdminRemotes"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes

local CelebrationViewer = {}

local PANEL_WIDTH, PANEL_HEIGHT = 1040, 660
local MARGIN = 24
local VIEW_SIZE = Vector2.new(560, 470)
local RIGHT_X = MARGIN + VIEW_SIZE.X + 22
local RIGHT_WIDTH = PANEL_WIDTH - RIGHT_X - MARGIN
-- Roblox's own R15 walk, for a celebration played over the walk.
local WALK_ANIMATION_ID = "rbxassetid://507777826"
-- Seconds between one play and the next.
local REPLAY_GAP = 0.9

-- Where the camera looks from, around the figure (it faces -Z, its right is +X), and at.
local VIEWS = {
	ThreeQuarter = Vector3.new(7.5, 4.6, -10.5),
	Front = Vector3.new(0, 3.8, -13),
	Side = Vector3.new(13, 3.6, 0),
}
local LOOK_AT = Vector3.new(0, 2.5, 0)

type Screen = {
	gui: ScreenGui,
	viewport: ViewportFrame,
	world: WorldModel,
	camera: Camera,
	list: ScrollingFrame,
	rows: { [string]: TextButton },
	name: TextLabel,
	rarity: TextLabel,
	facts: TextLabel,
	about: TextLabel,
	counter: TextLabel,
	status: TextLabel,
	slow: TextButton,
	viewButtons: { [string]: TextButton },
}
local screen: Screen? = nil
local figure: Model? = nil
local tracks: { AnimationTrack } = {}
local sounds: { Sound } = {}
local index = 1
local slowMotion = false
local view = "ThreeQuarter"
local playToken = 0
local actionRemote: RemoteFunction? = nil

local function rarityColour(rarity: string): Color3
	for _, entry in ipairs(GearStatsConfig.Rarities) do
		if entry.id == rarity then
			return entry.colour
		end
	end
	return C.white
end

-- The list in rarity order (the config's own order within each).
local function ordered(): { CelebrationConfig.Celebration }
	local out = {}
	for _, rarity in ipairs(CelebrationConfig.RarityOrder) do
		for _, celebration in ipairs(CelebrationConfig.List) do
			if celebration.rarity == rarity then
				table.insert(out, celebration)
			end
		end
	end
	return out
end
local ORDER = ordered()

local function stopPlaying()
	playToken += 1
	for _, track in ipairs(tracks) do
		track:Stop(0)
		track:Destroy()
	end
	table.clear(tracks)
	for _, sound in ipairs(sounds) do
		sound:Destroy()
	end
	table.clear(sounds)
end

local function animatorOf(model: Model): Animator?
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
	return animator
end

local function load(animator: Animator, id: string, priority: Enum.AnimationPriority, looped: boolean): AnimationTrack?
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok then
		return nil
	end
	local loaded = track :: AnimationTrack
	loaded.Priority = priority
	loaded.Looped = looped
	return loaded
end

local lastTake: { [string]: string } = {}
local function soundFor(name: string): (string?, number)
	local id, volume = CelebrationConfig.pickSound(name, lastTake[name])
	if id then
		lastTake[name] = id
		return id, volume
	end
	local cue = MeetSoundConfig.Cues[name]
	if cue then
		return cue.id, cue.volume
	end
	return nil, 0
end

-- Plays the chosen one on the copy, again and again until another is chosen or the viewer closes.
local function playChosen()
	stopPlaying()
	local model = figure
	local celebration = ORDER[index]
	if model == nil or celebration == nil then
		return
	end
	local animator = animatorOf(model)
	if animator == nil then
		return
	end
	local speed = if slowMotion then 0.5 else 1
	local mine = playToken
	task.spawn(function()
		while playToken == mine do
			if celebration.kind == "Walk" then
				local walk = load(animator, WALK_ANIMATION_ID, Enum.AnimationPriority.Movement, true)
				if walk then
					table.insert(tracks, walk)
					walk:Play(0.1, 1, speed)
				end
			end
			local track = load(animator, celebration.animationId, Enum.AnimationPriority.Action, false)
			local soundtrack = celebration.soundtrack
			local sound: Sound? = nil
			if soundtrack then
				local made = Instance.new("Sound")
				made.SoundId = soundtrack
				made.Volume = CelebrationConfig.SoundtrackVolume
				made.PlaybackSpeed = speed
				made.Parent = SoundService
				table.insert(sounds, made)
				sound = made
			end
			-- Both loaded first, then started together, so the sound lines up with the moves.
			local loading: { Instance } = {}
			if sound then
				table.insert(loading, sound)
			end
			local animation = Instance.new("Animation")
			animation.AnimationId = celebration.animationId
			table.insert(loading, animation)
			pcall(function()
				ContentProvider:PreloadAsync(loading)
			end)
			animation:Destroy()
			if playToken ~= mine then
				return
			end
			if track then
				table.insert(tracks, track)
				track:Play(0, 1, speed)
			end
			if sound then
				sound:Play()
			end
			for _, event in ipairs(if soundtrack then {} else celebration.events) do
				local id, volume = soundFor(event.sound or "")
				if id then
					local sound = Instance.new("Sound")
					sound.SoundId = id
					sound.Volume = volume * 0.8
					sound.PlaybackSpeed = speed
					sound.Parent = SoundService
					table.insert(sounds, sound)
					task.delay(event.at / speed, function()
						if playToken == mine and sound.Parent then
							sound:Play()
						end
					end)
				end
			end
			task.wait(celebration.seconds / speed + REPLAY_GAP)
			if playToken ~= mine then
				return
			end
			for _, old in ipairs(tracks) do
				old:Stop(0.2)
			end
			table.clear(tracks)
			for _, sound in ipairs(sounds) do
				sound:Destroy()
			end
			table.clear(sounds)
		end
	end)
end

local function placeCamera()
	local current = screen
	if current then
		current.camera.CFrame = CFrame.lookAt(VIEWS[view], LOOK_AT)
		for name, button in pairs(current.viewButtons) do
			local chosen = name == view
			button.BackgroundColor3 = if chosen then C.yellow else C.navyDeep
			button.TextColor3 = if chosen then C.ink else C.white
		end
	end
end

local function show()
	local current = screen
	local celebration = ORDER[index]
	if current == nil or celebration == nil then
		return
	end
	local colour = rarityColour(celebration.rarity)
	current.name.Text = string.upper(celebration.name)
	current.rarity.Text = if celebration.rarity == "Default" then "DEFAULT  ·  EVERYONE'S" else string.upper(celebration.rarity)
	current.rarity.TextColor3 = colour
	local kindText = if celebration.kind == "Walk" then "played over the walk back" else "on the platform"
	local cinematic = if celebration.cinematic then "  ·  HAS A CINEMATIC (PLAY ON ME)" else ""
	current.facts.Text = string.format("%.1f s  ·  %s  ·  from a real meet (%s)%s", celebration.seconds, kindText,
		celebration.source, cinematic)
	current.about.Text = celebration.description
	current.counter.Text = string.format("%d / %d", index, #ORDER)
	-- Keep the chosen row in view.
	local rowTop = (index - 1) * 38
	local shown = current.list.AbsoluteWindowSize.Y
	local scroll = current.list.CanvasPosition.Y
	if rowTop < scroll or rowTop + 32 > scroll + shown then
		current.list.CanvasPosition = Vector2.new(0, math.max(0, rowTop - shown / 2 + 16))
	end
	for id, row in pairs(current.rows) do
		local chosen = id == celebration.id
		row.BackgroundColor3 = if chosen then C.navy else C.navyDeep
		local stroke = row:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if chosen then C.yellow else C.white
			stroke.Transparency = if chosen then 0 else 0.7
		end
	end
	current.status.Text = ""
	playChosen()
end

local function choose(newIndex: number)
	index = ((newIndex - 1) % #ORDER) + 1
	show()
end

-- A copy of the player's own avatar for the stage: no scripts, nothing that moves by itself, the root held still.
local function makeFigure(world: WorldModel): Model?
	local character = Players.LocalPlayer.Character
	if character == nil then
		return nil
	end
	local was = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = was
	if copy == nil then
		return nil
	end
	for _, item in ipairs(copy:GetDescendants()) do
		if item:IsA("BaseScript") or item:IsA("Sound") or item:IsA("ForceField") or item:IsA("BillboardGui") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = false
			item.CanCollide = false
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	local root = copy:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		copy:Destroy()
		return nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	root.Anchored = true
	copy:PivotTo(CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	copy.Parent = world
	return copy
end

local function build(): Screen
	local gui = Instance.new("ScreenGui")
	gui.Name = "CelebrationViewer"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 25
	gui.Enabled = false
	UIStyle.fitToScreen(gui)

	local holder, body = UIStyle.panel(gui, "Panel", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT))
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	UIStyle.titleTag(holder, "Tag", "CELEBRATIONS", UDim2.fromOffset(-18, -30), UDim2.fromOffset(300, 52), nil, "star")

	-- The stage.
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Stage"
	viewport.Position = UDim2.fromOffset(MARGIN, 40)
	viewport.Size = UDim2.fromOffset(VIEW_SIZE.X, VIEW_SIZE.Y)
	-- (No UIGradient here: on a ViewportFrame it tints the 3D inside too, which made the stage murky.)
	viewport.BackgroundColor3 = Color3.fromRGB(38, 48, 88)
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(205, 205, 215)
	viewport.LightColor = Color3.fromRGB(255, 252, 245)
	viewport.LightDirection = Vector3.new(-0.35, -1, 0.55)
	viewport.Parent = body
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local floor = Instance.new("Part")
	floor.Name = "Platform"
	floor.Anchored = true
	floor.Size = Vector3.new(12, 0.4, 12)
	floor.CFrame = CFrame.new(0, -0.2, 0)
	floor.Color = Color3.fromRGB(46, 40, 38)
	floor.Material = Enum.Material.Wood
	floor.Parent = world
	local camera = Instance.new("Camera")
	camera.FieldOfView = 38
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	-- Under the stage: the counter, the views, slow motion; then prev / replay / next.
	local underY = 40 + VIEW_SIZE.Y + 10
	local counter = UIStyle.text(body, "Counter", UDim2.fromOffset(MARGIN, underY), UDim2.fromOffset(90, 36), SIZES.body,
		C.muted, UIStyle.font(Enum.FontWeight.Bold))
	local viewButtons: { [string]: TextButton } = {}
	for i, entry in ipairs({ { "ThreeQuarter", "3/4" }, { "Front", "FRONT" }, { "Side", "SIDE" } }) do
		viewButtons[entry[1]] = UIStyle.button(body, "View_" .. entry[1], entry[2],
			UDim2.fromOffset(MARGIN + 96 + (i - 1) * 104, underY), UDim2.fromOffset(96, 36), "outline", function()
				view = entry[1]
				placeCamera()
			end)
	end
	local slow: TextButton
	slow = UIStyle.button(body, "Slow", "SLOW-MO: OFF", UDim2.fromOffset(MARGIN + VIEW_SIZE.X - 150, underY),
		UDim2.fromOffset(150, 36), "outline", function()
			slowMotion = not slowMotion
			slow.Text = if slowMotion then "SLOW-MO: ON" else "SLOW-MO: OFF"
			playChosen()
		end)
	local rowY = underY + 46
	local third = (VIEW_SIZE.X - 20) / 3
	UIStyle.button(body, "Prev", "< PREV", UDim2.fromOffset(MARGIN, rowY), UDim2.fromOffset(third, 46), "outline", function()
		choose(index - 1)
	end)
	UIStyle.button(body, "Replay", "REPLAY", UDim2.fromOffset(MARGIN + third + 10, rowY), UDim2.fromOffset(third, 46),
		"outline", function()
			playChosen()
		end)
	UIStyle.button(body, "Next", "NEXT >", UDim2.fromOffset(MARGIN + 2 * (third + 10), rowY), UDim2.fromOffset(third, 46),
		"outline", function()
			choose(index + 1)
		end)

	-- The right side: the list, then the chosen one.
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(RIGHT_X, 40)
	list.Size = UDim2.fromOffset(RIGHT_WIDTH, 270)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = C.yellow
	list.CanvasSize = UDim2.fromOffset(0, #ORDER * 38)
	list.Parent = body
	local rows: { [string]: TextButton } = {}
	for i, celebration in ipairs(ORDER) do
		local row = Instance.new("TextButton")
		row.Name = celebration.id
		row.Position = UDim2.fromOffset(0, (i - 1) * 38)
		row.Size = UDim2.new(1, -12, 0, 32)
		row.BackgroundColor3 = C.navyDeep
		row.BorderSizePixel = 0
		row.AutoButtonColor = true
		row.Text = ""
		row.Parent = list
		UIStyle.stroke(row, C.white, 1, 0.7)
		local chip = Instance.new("Frame")
		chip.Name = "Rarity"
		chip.Position = UDim2.fromOffset(0, 0)
		chip.Size = UDim2.new(0, 6, 1, 0)
		chip.BorderSizePixel = 0
		chip.BackgroundColor3 = rarityColour(celebration.rarity)
		chip.Parent = row
		local label = UIStyle.text(row, "Name", UDim2.fromOffset(14, 0), UDim2.new(1, -130, 1, 0), SIZES.small, C.white,
			UIStyle.font(Enum.FontWeight.Bold))
		label.Text = string.upper(celebration.name)
		label.TextYAlignment = Enum.TextYAlignment.Center
		local tag = UIStyle.text(row, "Tag", UDim2.new(1, -122, 0, 0), UDim2.new(0, 114, 1, 0), SIZES.small,
			rarityColour(celebration.rarity), UIStyle.font(Enum.FontWeight.Bold), Enum.TextXAlignment.Right)
		tag.Text = string.upper(celebration.rarity)
		tag.TextYAlignment = Enum.TextYAlignment.Center
		tag.TextWrapped = false
		row.Activated:Connect(function()
			choose(i)
		end)
		rows[celebration.id] = row
	end

	local infoY = 40 + 270 + 14
	local name = UIStyle.text(body, "Name", UDim2.fromOffset(RIGHT_X, infoY), UDim2.fromOffset(RIGHT_WIDTH, 34),
		SIZES.heading, C.white, UIStyle.heading())
	local rarity = UIStyle.text(body, "Rarity", UDim2.fromOffset(RIGHT_X, infoY + 36), UDim2.fromOffset(RIGHT_WIDTH, 22),
		SIZES.body, C.white, UIStyle.font(Enum.FontWeight.Bold))
	local facts = UIStyle.text(body, "Facts", UDim2.fromOffset(RIGHT_X, infoY + 60), UDim2.fromOffset(RIGHT_WIDTH, 40),
		SIZES.small, C.muted)
	facts.TextWrapped = true
	local about = UIStyle.text(body, "About", UDim2.fromOffset(RIGHT_X, infoY + 102), UDim2.fromOffset(RIGHT_WIDTH, 92),
		SIZES.small, C.white)
	about.TextWrapped = true
	about.TextYAlignment = Enum.TextYAlignment.Top

	local status = UIStyle.text(body, "Status", UDim2.fromOffset(RIGHT_X, rowY - 34), UDim2.fromOffset(RIGHT_WIDTH, 28),
		SIZES.small, C.yellow)
	UIStyle.button(body, "PlayOnMe", "PLAY ON ME", UDim2.fromOffset(RIGHT_X, rowY), UDim2.fromOffset(RIGHT_WIDTH - 150, 46),
		"primary", function()
			local celebration = ORDER[index]
			local remote = actionRemote
			if celebration == nil or remote == nil then
				return
			end
			local ok, done, message = pcall(function()
				return remote:InvokeServer("PlayCelebration", celebration.id)
			end)
			if ok and done then
				CelebrationViewer.close()
			elseif screen then
				(screen :: Screen).status.Text = if ok and typeof(message) == "string" then message else "The server didn't answer."
			end
		end)
	UIStyle.button(body, "Close", "CLOSE", UDim2.new(1, -MARGIN - 140, 0, rowY), UDim2.fromOffset(140, 46), "outline",
		function()
			CelebrationViewer.close()
		end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return {
		gui = gui, viewport = viewport, world = world, camera = camera, list = list, rows = rows, name = name,
		rarity = rarity, facts = facts, about = about, counter = counter, status = status, slow = slow,
		viewButtons = viewButtons,
	}
end

function CelebrationViewer.isOpen(): boolean
	local current = screen
	return current ~= nil and current.gui.Enabled
end

-- Opens the viewer on the first celebration (or where it was left), with a fresh copy of the player's avatar.
function CelebrationViewer.open()
	if actionRemote == nil then
		actionRemote = AdminRemotes.waitForClient(ReplicatedStorage).action
	end
	local current = screen or build()
	screen = current
	if figure then
		figure:Destroy()
	end
	figure = makeFigure(current.world)
	current.gui.Enabled = true
	placeCamera()
	show()
	if figure == nil then
		current.status.Text = "No character to show yet: open it again once you've spawned."
	end
end

function CelebrationViewer.close()
	stopPlaying()
	if figure then
		figure:Destroy()
		figure = nil
	end
	local current = screen
	if current then
		current.gui.Enabled = false
	end
end

return CelebrationViewer
