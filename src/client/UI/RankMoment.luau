--!strict
--[[
	RankMoment
	Client / UI

	The moments when a lifter ranks up or earns a title (GAME_DESIGN §41, References/Ranks and Titles Study.md), on
	their own screen, AFTER the meet is over (never over the awards, a cutscene or their turn):

		- A NEW LEVEL inside the same name (Bar Bender II -> III): a small TOAST at the top for about 3 s that never blocks
		  the screen, with a tick and the rewards collected at once ("+1 FREE CRATE · +170 COINS"). Several levels from one
		  meet make one toast.
		- A NEW NAME (Bar Bender V -> Gym Regular I): the full CEREMONY (Sol's RNG: the moment grows with the step). The
		  screen dims, the old plate shakes and drops away, the new one slams in with turning rays, a flash and a shake,
		  "NEW RANK!" and its name in its material's colours, the rewards in a row (crates, coins, LUCK x2 · 24H), and a
		  big CLAIM button that collects them with a coin burst. Any tap before the button skips to it. LATER leaves the
		  rewards waiting (a red dot on the RANKS tab).
		- A NEW BEST that ranks nothing: a toast with the progress to the next rank (Overwatch's lesson: show progress
		  after every meet).
		- NEW TITLES: one card each (up to 3, then "and N more"), the title in its rarity colour with its tier, EQUIP or
		  LATER.
	Sounds: the game's own crate sounds for now (Tick, Big, Open) and the crowd's cheer under the ceremony (real meets
	are loud, never a hush). Display only: the server decides and saves everything (RankService).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RankConfig = require(Shared:WaitForChild("Config"):WaitForChild("RankConfig"))
local GearStatsConfig = require(Shared:WaitForChild("Config"):WaitForChild("GearStatsConfig"))
local MeetSoundConfig = require(Shared:WaitForChild("Config"):WaitForChild("MeetSoundConfig"))
local RankRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("RankRemotes"))
local UIFancy = require(script.Parent:WaitForChild("UIFancy"))
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local RankLook = require(script.Parent:WaitForChild("RankLook"))
local MenuKeys = require(script.Parent:WaitForChild("MenuKeys"))
local make = UIFancy.make
local C = UIStyle.Colours

local RankMoment = {}

local TOAST_SECONDS = 3.2
local WAIT_AFTER_NEWS = 2.5
local MAX_TITLE_CARDS = 3

local remotes: RankRemotes.RemoteSet? = nil
local queue: { RankRemotes.RankNews } = {}
local busy = false
local started = false
-- Things outside this module that must be over first (LocalMeetAwards.isPlaying), registered by init.
local blockers: { () -> boolean } = {}
-- Called with the newest view after a claim, an equip or news (the RANKS menu and its red dot listen).
local listeners: { (RankRemotes.RankView?) -> () } = {}

local function tell(view: RankRemotes.RankView?)
	for _, listener in ipairs(listeners) do
		task.spawn(listener, view)
	end
end

function RankMoment.onView(listener: (RankRemotes.RankView?) -> ())
	table.insert(listeners, listener)
end

function RankMoment.addBlocker(check: () -> boolean)
	table.insert(blockers, check)
end

local function play(id: string, volume: number)
	local sound = make("Sound", { SoundId = id, Volume = volume, Parent = SoundService })
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(12, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function screen(name: string, order: number): ScreenGui
	local gui = make("ScreenGui", {
		Name = name, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = order,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	return gui
end

-- Sizes a card to the screen like the other menus (UIStyle.screenScale), without moving its anchor.
local function fit(frame: GuiObject)
	make("UIScale", { Name = "Fit", Scale = UIStyle.screenScale(), Parent = frame })
end

-- Whether a moment may show now: no cutscene, not on their turn, nothing registered still playing.
local function clear(): boolean
	local camera = Workspace.CurrentCamera
	if camera == nil or camera.CameraType == Enum.CameraType.Scriptable or MenuKeys.isOnTurn() then
		return false
	end
	for _, check in ipairs(blockers) do
		if check() then
			return false
		end
	end
	return true
end

local function claim(upTo: number): RankRemotes.RankRewards?
	if remotes == nil then
		return nil
	end
	local ok, answer = pcall(function()
		return remotes.claim:InvokeServer(upTo)
	end)
	if ok and typeof(answer) == "table" then
		tell(answer.view)
		return answer.paid
	end
	return nil
end

local function rewardText(paid: RankRemotes.RankRewards?): string
	if paid == nil or #paid.ranks == 0 then
		return "Rewards collected"
	end
	local parts = { string.format("+%d FREE CRATE%s", paid.crates, if paid.crates == 1 then "" else "S") }
	if paid.coins > 0 then
		table.insert(parts, string.format("+%d COINS", paid.coins))
	end
	if paid.luckBoost then
		table.insert(parts, "LUCK x2 · 24H")
	end
	return table.concat(parts, "  ·  ")
end

-- The small card at the top: an emblem, a heading, a line (and an optional progress bar 0..1).
local function toast(rank: number, heading: string, line: string, progress: number?, headingColour: Color3?)
	local gui = screen("RankToast", 26)
	local card = make("Frame", {
		Name = "Card", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -120), Size = UDim2.fromOffset(520, 92), Parent = gui,
	})
	UIFancy.corner(card, UDim.new(0, 16))
	UIFancy.outline(card, 3)
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.navy, C.navyDeep), Parent = card })
	UIFancy.glow(card, Color3.new(0, 0, 0), 24, 0.4)
	local tierLook = RankConfig.Ranks[rank] and RankConfig.TierLooks[RankConfig.Ranks[rank].tier]
	make("Frame", {
		Name = "Bar", BackgroundColor3 = if tierLook then tierLook.top else C.yellow, BorderSizePixel = 0,
		Size = UDim2.new(0, 8, 1, 0), Parent = card,
	})
	RankLook.emblem(card, "Emblem", UDim2.fromOffset(58, 46), 84, rank)
	local head = UIFancy.words(card, "Heading", UDim2.fromOffset(108, 8), UDim2.new(1, -120, 0, 34), 30, 3, headingColour)
	head.Text = heading
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.TextWrapped = false
	head.TextScaled = true
	make("UITextSizeConstraint", { MaxTextSize = 30, Parent = head })
	local text = UIFancy.words(card, "Line", UDim2.fromOffset(108, 44), UDim2.new(1, -120, 0, 22), 18, 1.5, C.yellow, UIFancy.BodyFont)
	text.Text = line
	text.TextXAlignment = Enum.TextXAlignment.Left
	if progress then
		local track = make("Frame", {
			Name = "Track", BackgroundColor3 = Color3.fromRGB(30, 34, 60), BorderSizePixel = 0, Position = UDim2.fromOffset(108, 70),
			Size = UDim2.new(1, -124, 0, 12), Parent = card,
		})
		UIFancy.corner(track, UDim.new(0.5, 0))
		UIFancy.outline(track, 2)
		local fill = make("Frame", {
			Name = "Fill", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = track,
		})
		UIFancy.corner(fill, UDim.new(0.5, 0))
		make("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.yellow, Color3.fromRGB(230, 150, 20)), Parent = fill })
		task.delay(0.5, function()
			TweenService:Create(fill, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1) }):Play()
		end)
	end
	fit(card)
	play(GearStatsConfig.Sounds.Tick, 0.6)
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0, 18) }):Play()
	task.wait(TOAST_SECONDS)
	TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(0.5, 0, 0, -120) }):Play()
	task.wait(0.32)
	gui:Destroy()
end

-- The full-screen ceremony for a new name. Returns once the player has claimed or chosen LATER.
local function ceremony(rankBefore: number, rankAfter: number, ranksGained: number)
	local entry = RankConfig.Ranks[rankAfter]
	local tierLook = RankConfig.TierLooks[entry.tier]
	local gui = screen("RankCeremony", 40)
	local dim = make("TextButton", {
		Name = "Dim", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
		BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = gui,
	})
	local stage = make("Frame", {
		Name = "Stage", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(900, 620), Parent = gui,
	})
	local rays = UIFancy.rays(stage, UDim2.fromScale(0.5, 0.36), 760, 14, tierLook.glow)
	rays.Visible = false
	local flash = make("Frame", {
		Name = "Flash", BackgroundColor3 = tierLook.glow, BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = gui,
	})
	local holder = make("Frame", {
		Name = "EmblemSpot", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(300, 300), Parent = stage,
	})
	local holderScale = make("UIScale", { Scale = 1, Parent = holder })
	local heading = UIFancy.words(stage, "Heading", UDim2.new(0, 0, 0.6, 0), UDim2.new(1, 0, 0, 60), 54, 4)
	heading.Text = if ranksGained > 1 then string.format("NEW RANK!  (+%d)", ranksGained) else "NEW RANK!"
	heading.TextTransparency = 1
	local nameLabel = UIFancy.words(stage, "RankName", UDim2.new(0, 0, 0.6, 58), UDim2.new(1, 0, 0, 64), 60, 4)
	nameLabel.Text = string.upper(entry.label)
	make("UIGradient", { Rotation = 90, Color = RankLook.nameGradient(rankAfter), Parent = nameLabel })
	nameLabel.TextTransparency = 1
	local material = UIFancy.words(stage, "Material", UDim2.new(0, 0, 0.6, 122), UDim2.new(1, 0, 0, 26), 22, 2, C.yellow, UIFancy.BodyFont)
	material.Text = string.format("%s · RANK %d OF %d", string.upper(tierLook.material), entry.index, RankConfig.Count)
	material.TextTransparency = 1
	local buttons = make("Frame", {
		Name = "Buttons", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.6, 160),
		Size = UDim2.fromOffset(560, 110), Visible = false, Parent = stage,
	})
	local rewards = UIFancy.words(buttons, "Rewards", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 26), 22, 2, Color3.new(1, 1, 1), UIFancy.BodyFont)
	local crates, coins = 0, 0
	local luck = false
	for index = math.max(rankBefore, 0) + 1, rankAfter do
		local rank = RankConfig.Ranks[index]
		crates += RankConfig.CratesPerRank
		coins += rank.coins
		luck = luck or rank.newName
	end
	rewards.Text = string.format("+%d FREE CRATE%s  ·  +%d COINS%s", crates, if crates == 1 then "" else "S", coins,
		if luck then "  ·  LUCK x2 · 24H" else "")
	fit(stage)

	local done = false
	local skipped = false
	local function showEnd()
		if done then
			return
		end
		done = true
		dim.BackgroundTransparency = 0.35
		holderScale.Scale = 1
		rays.Visible = true
		heading.TextTransparency, nameLabel.TextTransparency, material.TextTransparency = 0, 0, 0
		buttons.Visible = true
	end
	dim.Activated:Connect(function()
		skipped = true
		showEnd()
	end)

	-- 1. Dim, the old plate (if any) shakes and drops away.
	TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 0.35 }):Play()
	if rankBefore > 0 then
		local old = RankLook.emblem(holder, "Old", UDim2.fromScale(0.5, 0.5), 260, rankBefore)
		task.wait(0.35)
		for i = 1, 6 do
			if skipped then
				break
			end
			old.Rotation = if i % 2 == 0 then 6 else -6
			task.wait(0.05)
		end
		old.Rotation = 0
		TweenService:Create(old, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.fromScale(0.5, 1.4), Rotation = 25 }):Play()
		task.wait(if skipped then 0 else 0.3)
		old:Destroy()
	else
		task.wait(0.35)
	end
	-- 2. The new plate slams in: flash, rays, a shake, the hit.
	RankLook.emblem(holder, "New", UDim2.fromScale(0.5, 0.5), 300, rankAfter)
	if not skipped then
		holderScale.Scale = 1.5
		TweenService:Create(holderScale, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		play(GearStatsConfig.Sounds.Big, 0.9)
		play(MeetSoundConfig.Cues.CrowdCheer.id, 0.5)
		flash.BackgroundTransparency = 0.3
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		rays.Visible = true
		task.spawn(function()
			for i = 1, 8 do
				stage.Position = UDim2.new(0.5, (math.random() - 0.5) * 16, 0.5, (math.random() - 0.5) * 16)
				task.wait(0.03)
			end
			stage.Position = UDim2.fromScale(0.5, 0.5)
		end)
		task.wait(0.5)
	end
	-- 3. The words, then the rewards and CLAIM.
	if not skipped then
		for _, label in ipairs({ heading, nameLabel, material }) do
			TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
			task.wait(0.18)
		end
		task.wait(0.3)
	end
	showEnd()
	local spinTween = TweenService:Create(rays, TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
	spinTween:Play()

	local finished = false
	local answer: string? = nil
	UIFancy.button(buttons, "Claim", "CLAIM", UDim2.new(0.5, -150, 0, 40), UDim2.fromOffset(300, 64),
		Color3.fromRGB(120, 230, 90), Color3.fromRGB(40, 150, 40), 34, function()
			if answer then
				return
			end
			answer = "claim"
			play(GearStatsConfig.Sounds.Open, 0.8)
			local paid = claim(rankAfter)
			rewards.Text = rewardText(paid)
			rewards.TextColor3 = C.yellow
			task.wait(1.2)
			finished = true
		end)
	local later = make("TextButton", {
		Name = "Later", BackgroundTransparency = 1, Text = "LATER", FontFace = UIFancy.BodyFont, TextSize = 18,
		TextColor3 = Color3.fromRGB(200, 204, 220), Position = UDim2.new(0.5, 170, 0, 58), Size = UDim2.fromOffset(90, 30),
		Parent = buttons,
	})
	later.Activated:Connect(function()
		if answer == nil then
			answer = "later"
			finished = true
		end
	end)
	while not finished and gui.Parent do
		task.wait(0.1)
	end
	spinTween:Cancel()
	TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	stage.Visible = false
	task.wait(0.3)
	gui:Destroy()
end

-- One title card: the title in its colour, its tier, EQUIP or LATER (or "and N more").
local function titleCard(id: string, more: number)
	local entry = RankConfig.TitleById[id]
	if entry == nil then
		return
	end
	local gui = screen("TitleUnlocked", 38)
	local card = make("Frame", {
		Name = "Card", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(600, 250), Parent = gui,
	})
	UIFancy.corner(card, UDim.new(0, 20))
	UIFancy.outline(card, 4)
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.navy, C.navyDeep), Parent = card })
	local colour = RankConfig.TitleColours[entry.tier]
	UIFancy.glow(card, colour, 40, if entry.tier >= 3 then 0.3 else 0.6)
	local base = UIStyle.screenScale()
	local scale = make("UIScale", { Scale = 0.6 * base, Parent = card })
	local tagLine = UIFancy.words(card, "Tag", UDim2.fromOffset(0, 14), UDim2.new(1, 0, 0, 30), 26, 3, C.yellow)
	tagLine.Text = "TITLE UNLOCKED!"
	local title = UIFancy.words(card, "Title", UDim2.fromOffset(20, 50), UDim2.new(1, -40, 0, 56), 46, 4)
	RankLook.title(title, id, nil)
	local tier = UIFancy.words(card, "Tier", UDim2.fromOffset(0, 106), UDim2.new(1, 0, 0, 24), 20, 2, colour)
	tier.Text = RankConfig.TierNames[entry.tier] .. (if more > 0 then string.format("   ·   and %d more in RANKS", more) else "")
	local how = UIFancy.words(card, "How", UDim2.fromOffset(20, 132), UDim2.new(1, -40, 0, 22), 18, 1.5, Color3.fromRGB(200, 204, 220), UIFancy.BodyFont)
	how.Text = entry.how
	local finished = false
	UIFancy.button(card, "Equip", "EQUIP", UDim2.new(0.5, -170, 1, -78), UDim2.fromOffset(200, 56),
		Color3.fromRGB(255, 220, 80), Color3.fromRGB(220, 150, 20), 28, function()
			if finished or remotes == nil then
				return
			end
			finished = true
			local ok, view = pcall(function()
				return remotes.setTitle:InvokeServer(id)
			end)
			if ok then
				tell(view)
			end
		end)
	local later = make("TextButton", {
		Name = "Later", BackgroundTransparency = 1, Text = "LATER", FontFace = UIFancy.BodyFont, TextSize = 20,
		TextColor3 = Color3.fromRGB(200, 204, 220), Position = UDim2.new(0.5, 50, 1, -70), Size = UDim2.fromOffset(120, 40),
		Parent = card,
	})
	later.Activated:Connect(function()
		finished = true
	end)
	play(if entry.tier >= 3 then GearStatsConfig.Sounds.Big else GearStatsConfig.Sounds.Open, 0.7)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = base }):Play()
	local started_ = os.clock()
	while not finished and os.clock() - started_ < 20 do
		task.wait(0.1)
	end
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.6 * base }):Play()
	task.wait(0.2)
	gui:Destroy()
end

local function show(news: RankRemotes.RankNews)
	tell(news.view)
	local before, after = news.rankBefore, news.rankAfter
	local beforeTier = if RankConfig.Ranks[before] then RankConfig.Ranks[before].tier else 0
	local afterEntry = RankConfig.Ranks[after]
	if afterEntry and after > before then
		if afterEntry.tier > beforeTier and beforeTier > 0 or (beforeTier == 0 and afterEntry.tier > 1) then
			ceremony(before, after, after - before)
		else
			-- A new level (or the very first rank): collect at once and say so in a toast.
			local paid = claim(after)
			local heading = if before == 0 then "FIRST RANK!  " .. string.upper(afterEntry.label)
				else "RANK UP!  " .. string.upper(afterEntry.label)
			toast(after, heading, rewardText(paid), nil, nil)
		end
	elseif news.newBest and afterEntry then
		local nextRank = RankConfig.Ranks[after + 1]
		if nextRank then
			local span = nextRank.points - afterEntry.points
			local progress = if span > 0 then (news.points - afterEntry.points) / span else 1
			toast(after, "NEW BEST TOTAL!", string.format("%.1f GL  ·  %.1f to %s", news.points, nextRank.points - news.points,
				nextRank.label), progress, nil)
		end
	end
	local count = #news.newFeats
	for i = 1, math.min(count, MAX_TITLE_CARDS) do
		titleCard(news.newFeats[i], if i == MAX_TITLE_CARDS then count - MAX_TITLE_CARDS else 0)
	end
end

local function pump()
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		task.wait(WAIT_AFTER_NEWS)
		while #queue > 0 do
			while not clear() do
				task.wait(0.5)
			end
			task.wait(1)
			if clear() then
				local news = table.remove(queue, 1)
				local ok, err = pcall(show, news)
				if not ok then
					warn("[RankMoment] " .. tostring(err))
				end
			end
		end
		busy = false
	end)
end

--[[
	The chat line for the rare (a high rank name or a Legendary title someone reached), in the rank's or title's colour.
]]
local function announce(line: RankRemotes.Announcement)
	local TextChatService = game:GetService("TextChatService")
	local channels = TextChatService:FindFirstChild("TextChannels")
	local general = channels and channels:FindFirstChild("RBXGeneral")
	if general == nil or not general:IsA("TextChannel") then
		return
	end
	local text: string
	if line.kind == "Rank" then
		local rank = RankConfig.Ranks[line.rank or 0]
		local colour = if rank then RankConfig.TierLooks[rank.tier].top else Color3.new(1, 1, 1)
		text = string.format("<font color=\"#%s\"><b>%s reached %s!</b></font>", colour:ToHex(), line.name, string.upper(line.id))
	else
		local entry = RankConfig.TitleById[line.id]
		if entry == nil then
			return
		end
		text = string.format("<font color=\"#%s\"><b>%s earned the title %s!</b></font>", RankConfig.TitleColours[entry.tier]:ToHex(),
			line.name, string.upper(entry.name))
	end
	pcall(function()
		(general :: TextChannel):DisplaySystemMessage(text)
	end)
end

function RankMoment.start()
	if started then
		return
	end
	started = true
	local set = RankRemotes.waitForClient(ReplicatedStorage)
	remotes = set
	set.news.OnClientEvent:Connect(function(news: any)
		if typeof(news) ~= "table" then
			return
		end
		table.insert(queue, news)
		pump()
	end)
	set.announce.OnClientEvent:Connect(function(line: any)
		if typeof(line) == "table" and typeof(line.name) == "string" and typeof(line.id) == "string" then
			announce(line)
		end
	end)
end

-- Asks the server for the newest view and tells the listeners (the RANKS tab's red dot), e.g. after a free crate.
function RankMoment.refresh()
	local set = remotes
	if set == nil then
		return
	end
	task.spawn(function()
		local ok, view = pcall(function()
			return set.get:InvokeServer()
		end)
		if ok then
			tell(view)
		end
	end)
end

-- For the RANKS menu: the remotes once started.
function RankMoment.remotes(): RankRemotes.RemoteSet?
	return remotes
end

-- The ceremony on its own, for the admin preview and tests.
function RankMoment.preview(rankBefore: number, rankAfter: number)
	task.spawn(ceremony, rankBefore, rankAfter, rankAfter - rankBefore)
end

return RankMoment
