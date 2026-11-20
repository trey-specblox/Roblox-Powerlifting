--!strict
--[[
	CoachDialogue
	Client / UI

	Talking to a coach in the gym (GAME_DESIGN §40.5, §40.6, user 2026-11-19): pressing a coach's "Talk" prompt
	(QuestService tags it, with the coach's lift) opens the same dialogue look as the coach handing over a rare suit
	(SuitCutscene, §35.12): the panel with a big portrait of the coach in the lower left, their name on a black bar,
	their words typed out, and the answers as speech bubbles beside the portrait.

		"Can you coach me?"           coaching (§40.5) isn't open yet: the coach says so
		"I need a stronger squat"     takes today's quest (QuestRemotes.TAKE, it goes on the QuestTracker): what to do and
		                              how far you are, or done
		"Bye."                        closes it

	Walking away from the coach, or nothing pressed for a while, closes it too. Display only: the server keeps the
	quests (QuestService, ProfileOperations).

	PERFORMANCE: one copy of the coach figure in the portrait while open; destroyed on close.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GearStatsConfig = require(Shared:WaitForChild("Config"):WaitForChild("GearStatsConfig"))
local QuestConfig = require(Shared:WaitForChild("Config"):WaitForChild("QuestConfig"))
local QuestRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("QuestRemotes"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local QuestTracker = require(script.Parent:WaitForChild("QuestTracker"))
local C = UIStyle.Colours

local CoachDialogue = {}

-- QuestService.PromptTag (server-side constant, repeated here).
local PROMPT_TAG = "QuestCoachPrompt"
local LETTER_SECONDS = 0.03
local STAND_ANIMATION = "rbxassetid://507766388"
-- Farther than this from the coach (studs) closes the dialogue.
local WALK_AWAY = 14
-- Seconds with no answer before it closes by itself.
local IDLE_SECONDS = 45
-- Pixels kept free between the coach's head and the top of the screen (the Roblox buttons sit above it).
local TOP_ROOM = 10
-- Where the name bar's top sits above the screen's bottom (design pixels): the coach's feet stand just above it.
local NAME_BAR_TOP = 172

local started = false

function CoachDialogue.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remotes = QuestRemotes.waitForClient(ReplicatedStorage)
	local playerGui = player:WaitForChild("PlayerGui")

	local tickSound = Instance.new("Sound")
	tickSound.SoundId = GearStatsConfig.Sounds.Tick
	tickSound.Volume = 0.25
	tickSound.Parent = playerGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "CoachDialogue"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 30
	gui.Enabled = false
	UIStyle.fitToScreen(gui)

	-- Who is talking: the panel and, on it, a portrait, in the lower left corner (the suit scene's layout).
	local SPEAKER_SIZE = 980
	local speakerAt = UDim2.new(0, SPEAKER_SIZE / 2, 1, -SPEAKER_SIZE / 2)
	local speaker = Instance.new("Frame")
	speaker.Name = "Speaker"
	speaker.AnchorPoint = Vector2.new(0.5, 0.5)
	speaker.Position = speakerAt
	speaker.Size = UDim2.fromOffset(SPEAKER_SIZE, SPEAKER_SIZE)
	speaker.BackgroundTransparency = 1
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
	-- The suit scene's framing (head to thighs); a phone frames the whole coach instead (frameCoach, below).
	local CLOSE_UP = CFrame.lookAt(Vector3.new(-0.95, 0.9, -11.5), Vector3.new(-0.95, 0.5, 0))
	portraitCamera.CFrame = CLOSE_UP
	portraitCamera.Parent = portrait
	portrait.CurrentCamera = portraitCamera

	local nameBar = UIStyle.frame(gui, "NameBar", UDim2.new(0, 0, 1, -172), UDim2.fromOffset(560, 52), C.ink)
	nameBar.BackgroundTransparency = 0.1
	nameBar.ZIndex = 2
	UIStyle.frame(nameBar, "Mark", UDim2.fromOffset(26, 8), UDim2.fromOffset(12, 36), C.yellow, 12)
	local who = UIStyle.text(nameBar, "Who", UDim2.fromOffset(60, 0), UDim2.new(1, -70, 1, 0), 34, C.white, UIStyle.heading())
	who.TextYAlignment = Enum.TextYAlignment.Center
	local words = UIStyle.text(gui, "Words", UDim2.new(0, 60, 1, -112), UDim2.fromOffset(1180, 100), 42, C.white, UIStyle.heading())
	words.TextStrokeColor3 = Color3.new(0, 0, 0)
	words.TextStrokeTransparency = 0
	words.TextYAlignment = Enum.TextYAlignment.Top
	words.TextWrapped = true
	words.ZIndex = 3

	-- Up to three answers: speech tabs beside the portrait, tails toward it.
	local picked: string? = nil
	local tabs: { ImageButton } = {}
	local SLOTS = { { y = -260, turn = -3 }, { y = -80, turn = 2 }, { y = 100, turn = -2 } }
	for index, slot in ipairs(SLOTS) do
		local tab = Instance.new("ImageButton")
		tab.Name = "Answer" .. index
		tab.AnchorPoint = Vector2.new(0.5, 0.5)
		tab.Position = UDim2.new(0, 760, 0.5, slot.y)
		tab.Size = UDim2.fromOffset(470, 184)
		tab.Rotation = slot.turn
		tab.BackgroundTransparency = 1
		tab.Image = GearStatsConfig.CutsceneArt.Bubble
		tab.Visible = false
		tab.ZIndex = 4
		tab.Parent = gui
		local label = UIStyle.text(tab, "Text", UDim2.new(0.2, 0, 0.14, 0), UDim2.new(0.68, 0, 0.58, 0), 34, C.white, UIStyle.heading())
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.TextWrapped = true
		tab.Activated:Connect(function()
			picked = tab:GetAttribute("Value") :: string?
		end)
		tabs[index] = tab
	end
	gui.Parent = playerGui

	--[[
		The panel stays full size (user 2026-11-19: "return the background"), even where it runs off the top of a short
		screen. Only the camera changes: on a phone, or whenever the close-up's head would be off the top, it backs off
		until the whole coach, head to feet, stands in the part of the panel that is on screen, above the name bar
		(user 2026-11-19: "make sure the coach is fully in frame").
	]]
	-- How much of the panel's square is off the top of the screen, and where the name bar starts (shares of its height).
	local function onScreenPart(): (number, number)
		local room = gui.AbsoluteSize.Y
		local square = SPEAKER_SIZE * UIStyle.screenScale()
		local top = if room > 0 then math.max(0, square - room) / square else 0
		return top, 1 - NAME_BAR_TOP / SPEAKER_SIZE
	end

	local function wholeBody(copy: Model, topShare: number, bottomShare: number)
		local box, size = copy:GetBoundingBox()
		local top = box.Position.Y + size.Y / 2
		local height = size.Y
		local square = SPEAKER_SIZE * UIStyle.screenScale()
		local headRoom = topShare + TOP_ROOM / square
		local feet = math.min(bottomShare + 0.02, 0.98)
		local view = height / math.max(feet - headRoom, 0.2)
		local distance = view / (2 * math.tan(math.rad(portraitCamera.FieldOfView / 2)))
		local centreY = top + headRoom * view - view / 2
		-- The coach a little left of the middle, as in the close-up, so the answer bubbles don't cover them.
		local side = -0.154 * view
		portraitCamera.CFrame = CFrame.lookAt(Vector3.new(side, centreY, -distance), Vector3.new(side, centreY, 0))
	end

	--[[
		A phone keeps menus out of its notch, so the gui starts a strip in from the screen's left edge and the gym showed
		through beside the camera cutout (user's phone, 2026-11-19). The panel art alone grows left and up into that strip
		(bottom right corner fixed, so it stays square); the coach, name and words stay in the safe area.
	]]
	-- An empty gui that ignores the safe area: it starts at the true screen edge, so its position (relative to the safe
	-- area) is minus the notch strip. (A normal gui always reports 0; Studio 2026-11-19: the top bar showed as -58 here.)
	local edge = Instance.new("ScreenGui")
	edge.Name = "CoachDialogueScreenEdge"
	edge.ResetOnSpawn = false
	edge.ScreenInsets = Enum.ScreenInsets.None
	edge.Parent = playerGui
	local function fillNotch()
		local strip = math.max(-edge.AbsolutePosition.X, 0)
		local extra = if strip > 0 then (strip + 6) / UIStyle.screenScale() else 0
		panel.Position = UDim2.fromOffset(-extra, -extra)
		panel.Size = UDim2.new(1, extra, 1, extra)
	end
	fillNotch()
	edge:GetPropertyChangedSignal("AbsolutePosition"):Connect(fillNotch)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fillNotch)

	local function frameCoach(copy: Model?)
		local topShare, bottomShare = onScreenPart()
		if copy and (UIStyle.isTouchOnly() or topShare > 0) then
			wholeBody(copy, topShare, bottomShare)
		else
			portraitCamera.CFrame = CLOSE_UP
		end
	end

	local open = false
	local session = 0

	local function say(text: string, mine: number)
		words.Text = text
		words.MaxVisibleGraphemes = 0
		for shown = 1, #text do
			if session ~= mine then
				return
			end
			words.MaxVisibleGraphemes = shown
			if shown % 3 == 0 then
				tickSound:Play()
			end
			task.wait(LETTER_SECONDS)
		end
		words.MaxVisibleGraphemes = -1
	end

	-- Shows these answers (text, value) and waits for one; nil when the dialogue closed instead.
	local function ask(choices: { { text: string, value: string } }, mine: number): string?
		picked = nil
		for index, tab in ipairs(tabs) do
			local choice = choices[index]
			tab.Visible = false
			if choice then
				(tab:FindFirstChild("Text") :: TextLabel).Text = choice.text
				tab:SetAttribute("Value", choice.value)
				-- Just appears, like the panel (no bounce).
				tab.Visible = true
			end
		end
		local deadline = os.clock() + IDLE_SECONDS
		while session == mine and picked == nil and os.clock() < deadline do
			task.wait(0.05)
		end
		for _, tab in ipairs(tabs) do
			tab.Visible = false
		end
		return if session == mine then picked else nil
	end

	local function close()
		session += 1
		open = false
		gui.Enabled = false
		portraitWorld:ClearAllChildren()
	end

	-- A copy of the coach for the portrait, without its name tag, bubble, clipboard or prompt.
	local function portraitOf(coach: Model): Model?
		coach.Archivable = true
		local ok, copy = pcall(function()
			return coach:Clone()
		end)
		if not ok or copy == nil then
			return nil
		end
		for _, child in ipairs(copy:GetDescendants()) do
			if child:IsA("BillboardGui") or child:IsA("ProximityPrompt") or string.sub(child.Name, 1, 9) == "Clipboard" then
				child:Destroy()
			end
		end
		copy:PivotTo(CFrame.Angles(0, math.rad(24), 0))
		copy.Parent = portraitWorld
		local humanoid = copy:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
			local animation = Instance.new("Animation")
			animation.AnimationId = STAND_ANIMATION
			local loaded, track = pcall(function()
				return (animator :: Animator):LoadAnimation(animation)
			end)
			if loaded and track then
				track.Looped = true
				track:Play(0)
			end
		end
		return copy
	end

	local function talk(prompt: ProximityPrompt)
		local lift = prompt:GetAttribute("Lift")
		local coach = if typeof(lift) == "string" then QuestConfig.Coaches[lift] else nil
		local figure = prompt:FindFirstAncestorOfClass("Model")
		if open or coach == nil or figure == nil then
			return
		end
		open = true
		session += 1
		local mine = session
		local liftName = lift :: string
		portraitWorld:ClearAllChildren()
		fillNotch()
		frameCoach(portraitOf(figure))
		who.Text = string.upper(coach.name)
		words.Text = ""
		-- Just appears: no slide, no bounce (user 2026-11-19: the bounce "looks weird").
		speaker.Position = speakerAt
		gui.Enabled = true

		-- Walking away closes it.
		task.spawn(function()
			while session == mine do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local where = figure:GetPivot().Position
				if root == nil or (root.Position - where).Magnitude > WALK_AWAY then
					close()
					return
				end
				task.wait(0.25)
			end
		end)

		task.wait(0.25)
		say("What do you need?", mine)
		while session == mine do
			local choice = ask({
				{ text = "Can you coach me?", value = "Coach" },
				{ text = "I need a stronger " .. string.lower(liftName), value = "Quest" },
				{ text = "Bye.", value = "Bye" },
			}, mine)
			if choice == nil or choice == "Bye" then
				break
			elseif choice == "Coach" then
				say("It's gonna cost you... but I'm not taking new lifters yet. Come back soon.", mine)
			elseif choice == "Quest" then
				-- Asking for it takes it: the quest goes on the tracker (QuestService checks the lift).
				local ok, quests = pcall(function()
					return remotes.take:InvokeServer(liftName)
				end)
				if ok and typeof(quests) == "table" then
					QuestTracker.show(quests)
				end
				local mineToday = if ok and typeof(quests) == "table" then quests[liftName] else nil
				local plural = QuestConfig.Plural[liftName] or liftName
				if typeof(mineToday) ~= "table" then
					say("Give me a second... ask me again.", mine)
				elseif mineToday.done then
					say("You did my work for today. Rest up and come back tomorrow.", mine)
				else
					say(string.format("Make %d good %s in a meet today and I'll make it worth your while. So far: %d of %d.",
						mineToday.needed, plural, mineToday.goodLifts, mineToday.needed), mine)
				end
			end
		end
		if session == mine then
			close()
		end
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredBy)
		if triggeredBy == player and prompt:HasTag(PROMPT_TAG) then
			task.spawn(talk, prompt)
		end
	end)

	-- After a meet: each quest it moved, as a line at the top of the screen.
	local Announcer = require(script.Parent.Parent:WaitForChild("Meet"):WaitForChild("GymRecordAnnouncer"))
	remotes.news.OnClientEvent:Connect(function(lines: any)
		if typeof(lines) ~= "table" then
			return
		end
		for _, line in ipairs(lines) do
			if typeof(line) == "string" then
				Announcer.note(line)
			end
		end
	end)
end

return CoachDialogue
