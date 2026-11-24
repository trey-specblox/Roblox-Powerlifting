--!strict
--[[
	RanksMenu
	Client / UI

	The RANKS menu (GAME_DESIGN §41, References/Ranks and Titles Study.md): a RANKS tab on the left edge under EMOTES
	(key R), with a red dot while something waits (a rank's rewards, free crates, a NEW title).

		TOP     the lifter's emblem, rank and best total; a bar to the next rank with the GL points it needs and what
		        that means in kilograms on their total at their bodyweight; CLAIM for rewards waiting; OPEN FREE CRATES
		        (opens the shop's crate opener anywhere); the luck boost's time left
		ROAD    every name in order with its picture and material (the order reads at a glance), its five levels with
		        the points and coins of each, a crate on every level and the luck boost at each new name; the lifter's
		        spot marked, the ranks ahead shown greyed (Trophy Road, Pet Simulator 99)
		TITLES  a preview of the lifter's name tag, then every title grouped Feats / Clubs / Meets: owned ones in their
		        rarity colour with EQUIP (or EQUIPPED), locked ones greyed with how to earn them and, where it counts up,
		        a progress bar; NEW on titles not seen yet (Sol's RNG, Destiny, Overwatch)

	Display only: the server decides everything (RankService).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RankConfig = require(Shared:WaitForChild("Config"):WaitForChild("RankConfig"))
local RankRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("RankRemotes"))
local MeetPlacing = require(Shared:WaitForChild("Meet"):WaitForChild("MeetPlacing"))
local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local UIFancy = require(script.Parent:WaitForChild("UIFancy"))
local RankLook = require(script.Parent:WaitForChild("RankLook"))
local RankMoment = require(script.Parent:WaitForChild("RankMoment"))
local MenuKeys = require(script.Parent:WaitForChild("MenuKeys"))
local ShopMenu = require(script.Parent:WaitForChild("ShopMenu"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes
local make = UIFancy.make

local RanksMenu = {}

local PANEL_WIDTH, PANEL_HEIGHT = 980, 600
-- Under the EMOTES tab (EmoteWheel sits 216 px under STATS).
local TAB_OFFSET_Y = 288
local OPEN_KEY = Enum.KeyCode.R
local CARD_WIDTH, CARD_GAP = 196, 12
local TITLE_W, TITLE_H = 290, 92

local started = false

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d", kg) else string.format("%.1f", kg)
end

function RanksMenu.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remotes = RankRemotes.waitForClient(ReplicatedStorage)

	local gui = make("ScreenGui", { Name = "Ranks", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 6 })
	UIStyle.fitToScreen(gui)

	-- The tab, with its red dot.
	local tab = make("TextButton", {
		Name = "Tab", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, TAB_OFFSET_Y), Size = UDim2.fromOffset(150, 44),
		BackgroundColor3 = C.ink, BorderSizePixel = 0, AutoButtonColor = true, Text = "", Parent = gui,
	})
	UIStyle.stroke(tab, C.yellow, 2)
	local tabText = UIStyle.text(tab, "Text", UDim2.fromOffset(10, 0), UDim2.new(1, -46, 1, 0), SIZES.body, C.white, UIStyle.heading())
	tabText.Text = "RANKS"
	local tabEmblemSpot = make("Frame", { Name = "EmblemSpot", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = tab })
	local dot = make("Frame", {
		Name = "Dot", BackgroundColor3 = Color3.fromRGB(235, 40, 50), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(16, 16), Visible = false, ZIndex = 5, Parent = tab,
	})
	UIFancy.corner(dot, UDim.new(0.5, 0))
	UIFancy.outline(dot, 2)
	local keyHint = UIStyle.text(tab, "Key", UDim2.new(0, 10, 1, 2), UDim2.fromOffset(100, 16), SIZES.small, C.muted)
	keyHint.Text = "[" .. OPEN_KEY.Name .. "]"
	keyHint.Visible = not UIStyle.isTouchOnly()

	-- The panel.
	local holder, body = UIStyle.panel(gui, "Panel", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT))
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Visible = false
	UIStyle.titleTag(holder, "Tag", "RANKS", UDim2.fromOffset(-18, -30), UDim2.fromOffset(220, 52), nil, "star")
	UIStyle.exitButton(holder, "Back", "BACK", UDim2.new(1, -150, 1, 20), function()
		holder.Visible = false
	end)

	local header = make("Frame", { Name = "Header", BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 30), Size = UDim2.new(1, -40, 0, 150), Parent = body })
	local pages = make("Frame", { Name = "Pages", BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 236), Size = UDim2.new(1, -40, 1, -250), Parent = body })
	local status = UIStyle.text(body, "Status", UDim2.new(0, 20, 1, -30), UDim2.new(1, -220, 0, 24), SIZES.small, C.muted)

	local view: RankRemotes.RankView? = nil
	local page = "Road"
	local asking = false

	local redraw: () -> () = function() end

	local function setView(newView: any)
		if typeof(newView) == "table" then
			view = newView
		end
		local current = view
		dot.Visible = current ~= nil and (current.rank > current.claimed or current.freeCrates > 0 or (function()
			for _, owned in pairs(current.titles) do
				if owned.new then
					return true
				end
			end
			return false
		end)())
		for _, child in ipairs(tabEmblemSpot:GetChildren()) do
			child:Destroy()
		end
		if current and current.rank > 0 then
			RankLook.emblem(tabEmblemSpot, "Emblem", UDim2.new(1, -22, 0.5, 0), 36, current.rank)
		end
		if holder.Visible then
			redraw()
		end
	end
	RankMoment.onView(setView)

	local function ask(remote: RemoteFunction, ...: any): any
		if asking then
			return nil
		end
		asking = true
		local ok, answer = pcall(remote.InvokeServer, remote, ...)
		asking = false
		return if ok then answer else nil
	end

	-- ------------------------------------------------ the header
	local function drawHeader()
		for _, child in ipairs(header:GetChildren()) do
			child:Destroy()
		end
		local current = view
		if current == nil then
			return
		end
		RankLook.emblem(header, "Emblem", UDim2.fromOffset(70, 70), 140, current.rank)
		local entry = RankConfig.Ranks[current.rank]
		local nameLabel = UIFancy.words(header, "Rank", UDim2.fromOffset(150, 0), UDim2.fromOffset(470, 46), 40, 3)
		nameLabel.Text = string.upper(RankLook.rankText(current.rank))
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		if entry then
			make("UIGradient", { Rotation = 90, Color = RankLook.nameGradient(current.rank), Parent = nameLabel })
		end
		local best = UIStyle.text(header, "Best", UDim2.fromOffset(152, 46), UDim2.fromOffset(470, 24), SIZES.body, C.white)
		best.Text = if current.rank > 0
			then string.format("Best meet total %s kg at %s kg  ·  %.1f GL", kgText(current.bestTotalKg), kgText(current.bestBodyweightKg), current.points)
			else "Finish a real meet with a total to get your first rank."
		-- The bar to the next rank.
		local nextEntry = RankConfig.Ranks[current.rank + 1]
		local track = make("Frame", {
			Name = "Track", BackgroundColor3 = Color3.fromRGB(30, 34, 60), BorderSizePixel = 0, Position = UDim2.fromOffset(152, 80),
			Size = UDim2.fromOffset(460, 18), Parent = header,
		})
		UIFancy.corner(track, UDim.new(0.5, 0))
		UIFancy.outline(track, 2)
		local line = UIStyle.text(header, "Next", UDim2.fromOffset(152, 102), UDim2.fromOffset(470, 40), SIZES.small, C.yellow)
		line.TextWrapped = true
		if nextEntry and entry then
			local span = nextEntry.points - entry.points
			local fill = make("Frame", {
				Name = "Fill", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
				Size = UDim2.fromScale(math.clamp(if span > 0 then (current.points - entry.points) / span else 0, 0.02, 1), 1), Parent = track,
			})
			UIFancy.corner(fill, UDim.new(0.5, 0))
			make("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.yellow, Color3.fromRGB(230, 150, 20)), Parent = fill })
			local need = nextEntry.points - current.points
			local kg = if current.bestBodyweightKg > 0
				then MeetPlacing.totalForPoints(current.bestBodyweightKg, nextEntry.points) - current.bestTotalKg else 0
			line.Text = string.format("%.1f GL to %s  (about +%s kg on your total at %s kg bodyweight)", need, nextEntry.label,
				kgText(math.ceil(math.max(kg, 0) * 2) / 2), kgText(current.bestBodyweightKg))
		elseif current.rank >= RankConfig.Count then
			local full = make("Frame", { Name = "Fill", BackgroundColor3 = C.yellow, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = track })
			UIFancy.corner(full, UDim.new(0.5, 0))
			line.Text = "The top rank. More ranks come in later updates."
		else
			line.Text = string.format("Your first meet total gives %s.", RankConfig.Ranks[1].label)
		end
		-- The buttons on the right.
		local right = make("Frame", { Name = "Right", BackgroundTransparency = 1, Position = UDim2.new(1, -300, 0, 0), Size = UDim2.fromOffset(300, 150), Parent = header })
		local waiting = current.rank - current.claimed
		if waiting > 0 then
			UIFancy.button(right, "Claim", string.format("CLAIM %d RANK%s", waiting, if waiting == 1 then "" else "S"),
				UDim2.fromOffset(10, 0), UDim2.fromOffset(280, 50), Color3.fromRGB(120, 230, 90), Color3.fromRGB(40, 150, 40), 24, function()
					local answer = ask(remotes.claim)
					if typeof(answer) == "table" then
						local paid = answer.paid
						if typeof(paid) == "table" and #paid.ranks > 0 then
							status.TextColor3 = C.yellow
							status.Text = string.format("+%d free crate%s, +%d coins%s", paid.crates, if paid.crates == 1 then "" else "s",
								paid.coins, if paid.luckBoost then ", luck x2 for 24 hours" else "")
						end
						setView(answer.view)
					end
				end)
		end
		if current.freeCrates > 0 then
			UIFancy.button(right, "Crates", string.format("OPEN %d FREE CRATE%s", current.freeCrates, if current.freeCrates == 1 then "" else "S"),
				UDim2.fromOffset(10, if waiting > 0 then 58 else 0), UDim2.fromOffset(280, 50), Color3.fromRGB(255, 220, 80),
				Color3.fromRGB(220, 150, 20), 22, function()
					holder.Visible = false
					ShopMenu.openFree()
				end)
		end
		if current.luckBoostLeft > 0 then
			local chip = UIStyle.text(right, "Luck", UDim2.fromOffset(10, 118), UDim2.fromOffset(280, 26), SIZES.small, Color3.fromRGB(120, 255, 140), UIStyle.heading())
			chip.Text = string.format("RANK LUCK x2  ·  %dh %dm left", current.luckBoostLeft // 3600, (current.luckBoostLeft % 3600) // 60)
			chip.TextXAlignment = Enum.TextXAlignment.Center
		end
	end

	-- ------------------------------------------------ the page tabs
	local pageButtons: { [string]: TextButton } = {}
	for i, name in ipairs({ "Road", "Titles" }) do
		local button = make("TextButton", {
			Name = name, Position = UDim2.fromOffset(20 + (i - 1) * 170, 192), Size = UDim2.fromOffset(160, 38),
			BackgroundColor3 = C.ink, BorderSizePixel = 0, AutoButtonColor = true, FontFace = UIStyle.heading(),
			TextSize = SIZES.body, TextColor3 = C.white, Text = if name == "Road" then "RANK ROAD" else "TITLES", Parent = body,
		})
		UIStyle.stroke(button, C.yellow, 2)
		pageButtons[name] = button
	end

	-- ------------------------------------------------ ROAD
	local function drawRoad()
		local current = view
		local road = make("ScrollingFrame", {
			Name = "Road", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 6, ScrollBarImageColor3 = C.yellow,
			CanvasSize = UDim2.fromOffset(#RankConfig.Names * (CARD_WIDTH + CARD_GAP) + CARD_GAP, 0), Parent = pages,
		})
		local rank = if current then current.rank else 0
		for tier, name in ipairs(RankConfig.Names) do
			local tierLook = RankConfig.TierLooks[tier]
			local first = RankConfig.Ranks[(tier - 1) * RankConfig.LevelsPerName + 1]
			local reached = rank >= first.index
			local here = RankConfig.Ranks[rank] ~= nil and RankConfig.Ranks[rank].tier == tier
			local card = make("Frame", {
				Name = "Name" .. tier, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
				Position = UDim2.fromOffset(CARD_GAP + (tier - 1) * (CARD_WIDTH + CARD_GAP), 6), Size = UDim2.new(0, CARD_WIDTH, 1, -20), Parent = road,
			})
			UIFancy.corner(card, UDim.new(0, 14))
			local edge = UIFancy.outline(card, if here then 4 else 2, if here then C.yellow else UIFancy.Ink)
			edge.Transparency = 0
			make("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.navy, C.navyDeep), Parent = card })
			if here then
				UIFancy.glow(card, tierLook.glow, 18, 0.45)
			end
			-- The name's picture, at the lifter's level on their own name, else at V (reached) or I (ahead).
			local shown = if here then rank elseif reached then first.index + RankConfig.LevelsPerName - 1 else first.index
			local emblem = RankLook.emblem(card, "Emblem", UDim2.new(0.5, 0, 0, 62), 112, shown)
			local title = UIFancy.words(card, "Name", UDim2.fromOffset(6, 120), UDim2.new(1, -12, 0, 28), 22, 2)
			title.Text = string.upper(name)
			title.TextScaled = true
			make("UITextSizeConstraint", { MaxTextSize = 22, Parent = title })
			make("UIGradient", { Rotation = 90, Color = RankLook.nameGradient(first.index), Parent = title })
			local material = UIStyle.text(card, "Material", UDim2.fromOffset(6, 146), UDim2.new(1, -12, 0, 18), SIZES.small, C.muted)
			material.Text = string.upper(tierLook.material) .. (if first.newName then "  ·  LUCK x2" else "")
			material.TextXAlignment = Enum.TextXAlignment.Center
			-- Its five levels: points and coins, the lifter's marked.
			for level = 1, RankConfig.LevelsPerName do
				local entry = RankConfig.Ranks[first.index + level - 1]
				local row = UIStyle.text(card, "Level" .. level, UDim2.fromOffset(10, 168 + (level - 1) * 22), UDim2.new(1, -20, 0, 20),
					SIZES.small, if entry.index == rank then C.yellow elseif entry.index < rank then C.white else C.muted)
				row.Text = string.format("%s  %s GL  ·  1 crate + %d", RankConfig.Roman[level],
					if entry.points <= 0 then "any" else kgText(entry.points), entry.coins)
				if entry.index == rank then
					row.FontFace = UIStyle.heading()
				end
			end
			if not reached then
				for _, child in ipairs(emblem:GetDescendants()) do
					if child:IsA("Frame") then
						child.BackgroundTransparency = math.max(child.BackgroundTransparency, 0.55)
					end
				end
				title.TextTransparency = 0.45
			end
		end
		-- Scroll so the lifter's name is in view.
		local here = RankConfig.Ranks[rank]
		if here then
			road.CanvasPosition = Vector2.new(math.max(0, (here.tier - 2) * (CARD_WIDTH + CARD_GAP)), 0)
		end
	end

	-- ------------------------------------------------ TITLES
	local function progressFor(id: string, current: RankRemotes.RankView): (number?, string?)
		for _, club in ipairs(RankConfig.TotalClubs) do
			if club.id == id then
				return math.clamp(current.bestTotalKg / club.kg, 0, 1), string.format("best %s / %d kg", kgText(current.bestTotalKg), club.kg)
			end
		end
		if id == "IronStreak" then
			return math.clamp(current.streakDays / RankConfig.StreakDays, 0, 1), string.format("%d / %d days", current.streakDays, RankConfig.StreakDays)
		end
		return nil, nil
	end

	local function drawTitles()
		local current = view
		if current == nil then
			return
		end
		local list = make("ScrollingFrame", {
			Name = "Titles", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 6, ScrollBarImageColor3 = C.yellow, Parent = pages,
		})
		-- The preview of the lifter's own name tag.
		local preview = make("Frame", { Name = "Preview", BackgroundColor3 = C.navyDeep, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -16, 0, 64), Parent = list })
		UIFancy.corner(preview, UDim.new(0, 12))
		UIFancy.outline(preview, 2, C.yellow)
		local previewLabel = UIStyle.text(preview, "Label", UDim2.fromOffset(14, 0), UDim2.fromOffset(170, 64), SIZES.small, C.muted)
		previewLabel.Text = "YOUR NAME TAG"
		RankLook.emblem(preview, "Emblem", UDim2.fromOffset(210, 32), 54, current.rank)
		local nameText = UIFancy.words(preview, "Name", UDim2.fromOffset(244, 4), UDim2.fromOffset(400, 28), 24, 2)
		nameText.Text = player.DisplayName
		nameText.TextXAlignment = Enum.TextXAlignment.Left
		local titleText = UIFancy.words(preview, "Title", UDim2.fromOffset(244, 32), UDim2.fromOffset(400, 24), 18, 1.5)
		titleText.TextXAlignment = Enum.TextXAlignment.Left
		local owned = current.titles[current.title]
		RankLook.title(titleText, current.title, if owned then owned.count else nil)
		if titleText.Text == "" then
			titleText.Text = RankLook.rankText(current.rank)
			titleText.TextColor3 = Color3.fromRGB(190, 192, 200)
		end
		local y = 80
		local columns = 3
		for _, group in ipairs({ "Feats", "Clubs", "Meets" }) do
			UIStyle.sectionHead(list, group, string.upper(group), UDim2.fromOffset(0, y), 120)
			y += 34
			local index = 0
			for _, entry in ipairs(RankConfig.Titles) do
				if entry.group == group then
					local col, row = index % columns, index // columns
					index += 1
					local have = current.titles[entry.id]
					local equipped = current.picked == entry.id
					local card = make("TextButton", {
						Name = entry.id, Text = "", AutoButtonColor = have ~= nil, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
						Position = UDim2.fromOffset(col * (TITLE_W + 10), y + row * (TITLE_H + 10)), Size = UDim2.fromOffset(TITLE_W, TITLE_H), Parent = list,
					})
					UIFancy.corner(card, UDim.new(0, 12))
					UIFancy.outline(card, if equipped then 4 else 2, if equipped then C.yellow elseif have then RankConfig.TitleColours[entry.tier] else UIFancy.Ink)
					make("UIGradient", { Rotation = 90, Color = ColorSequence.new(if have then C.navy else Color3.fromRGB(34, 36, 46), C.navyDeep), Parent = card })
					local name = UIFancy.words(card, "Name", UDim2.fromOffset(10, 6), UDim2.new(1, -20, 0, 28), 22, 2)
					name.TextXAlignment = Enum.TextXAlignment.Left
					name.TextScaled = true
					make("UITextSizeConstraint", { MaxTextSize = 22, Parent = name })
					if have then
						RankLook.title(name, entry.id, have.count)
					else
						name.Text = entry.name
						name.TextColor3 = Color3.fromRGB(120, 124, 140)
					end
					local tier = UIStyle.text(card, "Tier", UDim2.fromOffset(10, 34), UDim2.new(1, -20, 0, 16), SIZES.small,
						if have then RankConfig.TitleColours[entry.tier] else C.muted, UIStyle.heading())
					tier.Text = RankConfig.TierNames[entry.tier] .. (if equipped then "  ·  EQUIPPED" elseif have then "  ·  TAP TO EQUIP" else "  ·  LOCKED")
					local how = UIStyle.text(card, "How", UDim2.fromOffset(10, 52), UDim2.new(1, -20, 0, 18), SIZES.small, C.muted)
					how.Text = entry.how
					how.TextTruncate = Enum.TextTruncate.AtEnd
					if not have then
						local fraction, words = progressFor(entry.id, current)
						if fraction and words then
							local track = make("Frame", { Name = "Track", BackgroundColor3 = Color3.fromRGB(30, 34, 60), BorderSizePixel = 0, Position = UDim2.fromOffset(10, 74), Size = UDim2.new(0.55, 0, 0, 10), Parent = card })
							UIFancy.corner(track, UDim.new(0.5, 0))
							local fill = make("Frame", { Name = "Fill", BackgroundColor3 = C.yellow, BorderSizePixel = 0, Size = UDim2.fromScale(math.max(fraction, 0.02), 1), Parent = track })
							UIFancy.corner(fill, UDim.new(0.5, 0))
							local count = UIStyle.text(card, "Count", UDim2.new(0.55, 16, 0, 68), UDim2.new(0.45, -26, 0, 20), SIZES.small, C.muted)
							count.Text = words
						end
					end
					if have and have.new then
						local new = make("TextLabel", {
							Name = "New", BackgroundColor3 = Color3.fromRGB(235, 40, 50), BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(46, 20), FontFace = UIStyle.heading(), TextSize = 14,
							TextColor3 = C.white, Text = "NEW", ZIndex = 4, Parent = card,
						})
						UIFancy.corner(new, UDim.new(0, 6))
					end
					if have then
						card.Activated:Connect(function()
							local answer = ask(remotes.setTitle, if equipped then "" else entry.id)
							if answer then
								status.TextColor3 = C.yellow
								status.Text = if equipped then "Title taken off: your best title shows instead." else entry.name .. " equipped!"
								setView(answer)
							end
						end)
					end
				end
			end
			y += math.ceil(index / columns) * (TITLE_H + 10) + 10
		end
		list.CanvasSize = UDim2.fromOffset(0, y + 10)
	end

	redraw = function()
		for _, child in ipairs(pages:GetChildren()) do
			child:Destroy()
		end
		drawHeader()
		for name, button in pairs(pageButtons) do
			button.BackgroundColor3 = if name == page then C.yellow else C.ink
			button.TextColor3 = if name == page then C.ink else C.white
		end
		if page == "Road" then
			drawRoad()
		else
			drawTitles()
		end
	end

	local function markSeen()
		local current = view
		if current == nil then
			return
		end
		for _, owned in pairs(current.titles) do
			if owned.new then
				task.spawn(function()
					local answer = ask(remotes.titlesSeen)
					if answer then
						-- Keep this view's NEW tags until the next redraw, so the lifter sees which are new.
						task.delay(0.1, function()
							view = answer
							dot.Visible = answer.rank > answer.claimed or answer.freeCrates > 0
						end)
					end
				end)
				return
			end
		end
	end

	for name, button in pairs(pageButtons) do
		button.Activated:Connect(function()
			page = name
			redraw()
			if name == "Titles" then
				markSeen()
			end
		end)
	end

	local function open()
		local answer = ask(remotes.get)
		if answer then
			setView(answer)
		end
		holder.Visible = true
		status.Text = ""
		redraw()
		if page == "Titles" then
			markSeen()
		end
	end
	local function toggle()
		if holder.Visible then
			holder.Visible = false
		else
			task.spawn(open)
		end
	end
	tab.Activated:Connect(toggle)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.KeyCode == OPEN_KEY and MenuKeys.allowed(gameProcessed) then
			toggle()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	-- The first view, for the tab's emblem and red dot.
	task.spawn(function()
		local answer = ask(remotes.get)
		if answer then
			setView(answer)
		end
	end)
end

return RanksMenu
