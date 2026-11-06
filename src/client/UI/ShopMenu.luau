--!strict
--[[
	ShopMenu
	Client / UI

	The Shop's menu. Opens when the server says the player held E at the Shop's
	counter (ShopRemotes.OPEN). Built from UIStyle. Crates are the only thing it sells
	(user 2026-11-06: gear is unlocked through crates, never bought; GAME_DESIGN §35.12):

		SHOP (tag)                                   [coin] 1,250 COINS
		one button per crate (belt, wraps, singlet, sleeves), then the chosen crate:
		its price, every rarity's odds and stats, the lifts it helps, OPEN CRATE (press
		again to CONFIRM)   |   what came out, with WEAR and SCRAP
		a status line                                            BACK

	OPENING (user 2026-11-06) starts with the crate: it drops onto a platform, rattles, its
	latches snap and its lid flies up, then a circle of light fills the panel and shows the
	reel: a strip of gear cards races past a marker, slows and stops on the prize. A tap skips
	all of it. Display only: the server has already rolled the prize and saved it before any
	of this starts, so leaving or skipping changes nothing.

	PERFORMANCE: one 3D preview per card, built over a few frames when a crate opens and
	destroyed after it. Only the cards on screen are visible, so at most about 7 draw at once.
	The crate is about 25 parts in its own view, moved each frame for about 2 seconds and
	destroyed after, with the reel's cards still hidden.

	It only asks (GetShop, OpenCrate) and shows what the server answers; the server
	decides the price and rolls the crate. Walking away from the counter closes it.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local ShopConfig = require(ConfigFolder:WaitForChild("ShopConfig"))
local CoinConfig = require(ConfigFolder:WaitForChild("CoinConfig"))
local GearStatsConfig = require(ConfigFolder:WaitForChild("GearStatsConfig"))
local EconomyFolder = Shared:WaitForChild("Economy")
local ShopRemotes = require(EconomyFolder:WaitForChild("ShopRemotes"))
local GearRemotes = require(EconomyFolder:WaitForChild("GearRemotes"))
local GearStats = require(EconomyFolder:WaitForChild("GearStats"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local GearPreview = require(script.Parent:WaitForChild("GearPreview"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes

local ShopMenu = {}

local PANEL_WIDTH, PANEL_HEIGHT = 940, 560
local CONFIRM_SECONDS = 3
-- The menu closes when the player walks this far from where they opened it (studs).
local CLOSE_DISTANCE = 20
-- Reel cards built per frame when a crate opens, so it doesn't hitch.
local CARDS_PER_FRAME = 6
-- The longest a crate's intro waits for its model to finish loading (a very slow connection then sees it fill in).
local CRATE_LOAD_WAIT_SECONDS = 2.5

local started = false

function ShopMenu.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remotes = ShopRemotes.waitForClient(ReplicatedStorage)
	local gearRemotes = GearRemotes.waitForClient(ReplicatedStorage)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 8
	UIStyle.fitToScreen(gui)

	local holder, body = UIStyle.panel(gui, "Panel", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT))
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Visible = false
	UIStyle.titleTag(holder, "Tag", "SHOP", UDim2.fromOffset(-18, -30), UDim2.fromOffset(220, 52), nil, "star")

	-- The player's coins, top right.
	UIStyle.coin(body, UDim2.new(1, -236, 0, 22), 26)
	local coinsText = UIStyle.text(body, "Coins", UDim2.new(1, -202, 0, 20), UDim2.fromOffset(186, 30), SIZES.heading, C.yellow,
		UIStyle.heading())
	coinsText.TextWrapped = false

	local status = UIStyle.text(body, "Status", UDim2.new(0, 24, 1, -46), UDim2.new(1, -230, 0, 36), SIZES.body, C.muted)
	status.TextYAlignment = Enum.TextYAlignment.Center

	local coins = 0
	local built = false

	-- Set when the crate is built: redraws its button for the new coins.
	local onCoinsChanged: (() -> ())? = nil

	local function apply(view: ShopRemotes.ShopView?)
		if view == nil then
			return
		end
		coins = view.coins
		coinsText.Text = string.format("%s %s", CoinConfig.format(coins), CoinConfig.Name)
		if onCoinsChanged then
			onCoinsChanged()
		end
	end

	-- ------------------------------------------------ the crate
	local function sound(id: string): Sound?
		if id == "" then
			return nil
		end
		local made = Instance.new("Sound")
		made.SoundId = id
		made.Volume = 0.8
		made.Parent = gui
		return made
	end
	local openSound = sound(GearStatsConfig.Sounds.Open)
	local tickSound = sound(GearStatsConfig.Sounds.Tick)
	local dropSound = sound(GearStatsConfig.Sounds.Drop)
	local rattleSound = sound(GearStatsConfig.Sounds.Rattle)
	local bigSound = sound(GearStatsConfig.Sounds.Big)

	local function buildCrates()
		local panel = Instance.new("Frame")
		panel.Name = "Crates"
		panel.BackgroundTransparency = 1
		panel.Position = UDim2.fromOffset(20, 66)
		panel.Size = UDim2.new(1, -30, 1, -120)
		panel.Parent = body

		-- The left: the crate, its price and every rarity's odds and stats.
		local info = UIStyle.frame(panel, "Info", UDim2.fromOffset(4, 4), UDim2.new(0, 430, 1, -8), C.navyDeep)
		UIStyle.stroke(info, C.yellow, 2, 0)
		local selected: GearStatsConfig.Crate = GearStatsConfig.Crates[1]
		local title = UIStyle.text(info, "Title", UDim2.fromOffset(14, 50), UDim2.new(1, -28, 0, 30), SIZES.heading, C.white, UIStyle.heading())
		UIStyle.coin(info, UDim2.fromOffset(14, 86), 22)
		local price = UIStyle.text(info, "Price", UDim2.fromOffset(42, 82), UDim2.new(1, -56, 0, 28), SIZES.heading, C.yellow, UIStyle.heading())
		for index, rarity in ipairs(GearStatsConfig.Rarities) do
			local y = 116 + (index - 1) * 27
			local name = UIStyle.text(info, "Name_" .. rarity.id, UDim2.fromOffset(14, y), UDim2.fromOffset(120, 24), SIZES.body, rarity.colour, UIStyle.heading())
			name.Text = string.upper(rarity.id)
			local odds = UIStyle.text(info, "Odds_" .. rarity.id, UDim2.fromOffset(134, y), UDim2.fromOffset(50, 24), SIZES.body, C.white)
			odds.Text = string.format("%d%%", math.floor(rarity.odds * 100 + 0.5))
			local stats = UIStyle.text(info, "Stats_" .. rarity.id, UDim2.fromOffset(186, y), UDim2.fromOffset(232, 24), SIZES.small, C.muted)
			stats.Text = GearStats.statText(rarity.id)
			stats.TextScaled = true
		end
		local helps = UIStyle.text(info, "Helps", UDim2.fromOffset(14, 256), UDim2.new(1, -28, 0, 24), SIZES.small, C.white)
		local openButton: TextButton
		local confirmUntil = 0
		local function drawOpen()
			if os.clock() < confirmUntil then
				openButton.Text = "CONFIRM " .. CoinConfig.format(selected.price) .. "?"
				openButton.BackgroundColor3, openButton.TextColor3 = C.white, C.ink
			else
				local afford = coins >= selected.price
				openButton.Text = "OPEN CRATE"
				openButton.BackgroundColor3, openButton.TextColor3 = if afford then C.yellow else C.empty, if afford then C.ink else C.muted
			end
		end
		openButton = Instance.new("TextButton")
		openButton.Name = "Open"
		openButton.Position = UDim2.new(0, 14, 1, -52)
		openButton.Size = UDim2.new(1, -28, 0, 40)
		openButton.BorderSizePixel = 0
		openButton.FontFace = UIStyle.heading()
		openButton.TextSize = SIZES.body
		openButton.Parent = info

		-- The right: what came out.
		local reveal = UIStyle.frame(panel, "Reveal", UDim2.new(0, 446, 0, 4), UDim2.new(1, -456, 1, -8), C.navyDeep)
		local revealEdge = UIStyle.stroke(reveal, C.white, 2, 0.4)
		local waiting = UIStyle.text(reveal, "Waiting", UDim2.new(0, 14, 0.4, 0), UDim2.new(1, -28, 0, 30), SIZES.body, C.muted)
		waiting.Text = "Open a crate to see what's inside."
		waiting.TextXAlignment = Enum.TextXAlignment.Center
		local rarityText = UIStyle.text(reveal, "Rarity", UDim2.fromOffset(14, 160), UDim2.new(1, -28, 0, 30), SIZES.heading, C.white, UIStyle.heading())
		rarityText.TextXAlignment = Enum.TextXAlignment.Center
		local nameText = UIStyle.text(reveal, "Name", UDim2.fromOffset(14, 190), UDim2.new(1, -28, 0, 24), SIZES.body, C.white, UIStyle.heading())
		nameText.TextXAlignment = Enum.TextXAlignment.Center
		local statText = UIStyle.text(reveal, "Stats", UDim2.fromOffset(14, 214), UDim2.new(1, -28, 0, 20), SIZES.small, C.white)
		statText.TextXAlignment = Enum.TextXAlignment.Center
		local liftsText = UIStyle.text(reveal, "Lifts", UDim2.fromOffset(14, 234), UDim2.new(1, -28, 0, 20), SIZES.small, C.muted)
		liftsText.TextXAlignment = Enum.TextXAlignment.Center
		local wearButton = UIStyle.button(reveal, "Wear", "WEAR", UDim2.new(0, 14, 1, -46), UDim2.new(0.5, -18, 0, 36), "primary", function() end)
		local scrapButton = UIStyle.button(reveal, "Scrap", "SCRAP", UDim2.new(0.5, 4, 1, -46), UDim2.new(0.5, -18, 0, 36), "outline", function() end)

		local currentId: string? = nil
		local currentPiece: GearStats.Piece? = nil
		local preview: ViewportFrame? = nil
		local scrapSureUntil = 0
		local function clearReveal()
			currentId, currentPiece = nil, nil
			waiting.Visible = true
			if preview then
				preview:Destroy()
				preview = nil
			end
			rarityText.Text, nameText.Text, statText.Text, liftsText.Text = "", "", "", ""
			wearButton.Visible, scrapButton.Visible = false, false
			revealEdge.Color, revealEdge.Transparency = C.white, 0.4
		end
		clearReveal()

		local function showPiece(id: string, piece: GearStats.Piece)
			local rarity = GearStats.rarity(piece.rarity)
			local look = ShopConfig.find(piece.look)
			if rarity == nil or look == nil then
				return
			end
			clearReveal()
			currentId, currentPiece = id, piece
			waiting.Visible = false
			preview = GearPreview.build(reveal, look, UDim2.fromOffset(14, 12), UDim2.new(1, -28, 0, 144))
			rarityText.Text, rarityText.TextColor3 = string.upper(rarity.id), rarity.colour
			nameText.Text = string.upper(look.name)
			statText.Text = GearStats.statText(piece.rarity)
			liftsText.Text = "HELPS " .. GearStats.liftsText(piece.slot)
			wearButton.Text = "WEAR"
			scrapButton.Text = "SCRAP +" .. rarity.scrap
			wearButton.Visible, scrapButton.Visible = true, true
			revealEdge.Color, revealEdge.Transparency = rarity.colour, 0
			-- The rarity's colour flashes round the panel, longer and brighter the better it is.
			revealEdge.Thickness = 2 + GearStats.rank(piece.rarity) * 2
			TweenService:Create(revealEdge, TweenInfo.new(0.4 + GearStats.rank(piece.rarity) * 0.15), { Thickness = 2 }):Play()
			if bigSound and GearStats.rank(piece.rarity) >= GearStats.rank(GearStatsConfig.BigFrom) then
				bigSound:Play()
			end
		end

		-- ---------------------------------------------- the reel, over the crate and its result while it spins
		local REEL = GearStatsConfig.Reel
		local reelStep = REEL.CardWidth + REEL.Gap
		local reelLayer = UIStyle.frame(panel, "Reel", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), C.navyDeep)
		reelLayer.Visible = false
		UIStyle.stroke(reelLayer, C.yellow, 2, 0)
		local reelTitle = UIStyle.text(reelLayer, "Title", UDim2.fromOffset(14, 16), UDim2.new(1, -28, 0, 34), SIZES.heading, C.white, UIStyle.heading())
		reelTitle.Text = selected.name
		reelTitle.TextXAlignment = Enum.TextXAlignment.Center
		local reelWindow = Instance.new("Frame")
		reelWindow.Name = "Window"
		reelWindow.AnchorPoint = Vector2.new(0.5, 0.5)
		reelWindow.Position = UDim2.fromScale(0.5, 0.5)
		reelWindow.Size = UDim2.new(1, -16, 0, REEL.CardHeight + 16)
		reelWindow.BackgroundColor3 = C.ink
		reelWindow.BorderSizePixel = 0
		reelWindow.ClipsDescendants = true
		reelWindow.Parent = reelLayer
		local reelStrip = Instance.new("Frame")
		reelStrip.Name = "Strip"
		reelStrip.BackgroundTransparency = 1
		reelStrip.Size = UDim2.fromOffset(REEL.Cards * reelStep, REEL.CardHeight)
		reelStrip.Parent = reelWindow
		-- The marker: a bright line down the middle, with a notch at each end.
		local marker = UIStyle.frame(reelLayer, "Marker", UDim2.new(0.5, -2, 0.5, -(REEL.CardHeight / 2 + 16)), UDim2.fromOffset(4, REEL.CardHeight + 32), C.yellow)
		marker.ZIndex = 5
		for _, y in ipairs({ -8, REEL.CardHeight + 24 }) do
			local notch = UIStyle.frame(marker, "Notch", UDim2.fromOffset(-6, y), UDim2.fromOffset(16, 16), C.yellow, 45)
			notch.ZIndex = 5
		end
		local skipHint = UIStyle.text(reelLayer, "Hint", UDim2.new(0, 14, 1, -40), UDim2.new(1, -28, 0, 26), SIZES.small, C.muted)
		skipHint.Text = "TAP TO SKIP"
		skipHint.TextXAlignment = Enum.TextXAlignment.Center
		local skipped = false
		local skipButton = Instance.new("TextButton")
		skipButton.Name = "Skip"
		skipButton.BackgroundTransparency = 1
		skipButton.Text = ""
		skipButton.Size = UDim2.fromScale(1, 1)
		skipButton.ZIndex = 8
		skipButton.Parent = reelLayer
		skipButton.Activated:Connect(function()
			skipped = true
		end)
		local fillerRandom = Random.new()

		-- ---------------------------------------------- the crate's intro, over the reel
		local INTRO = GearStatsConfig.CrateIntro
		local introLayer = Instance.new("Frame")
		introLayer.Name = "Intro"
		introLayer.BackgroundTransparency = 1
		introLayer.BorderSizePixel = 0
		introLayer.Size = UDim2.fromScale(1, 1)
		introLayer.ClipsDescendants = true
		introLayer.Visible = false
		introLayer.ZIndex = 7
		introLayer.Parent = reelLayer
		-- The circle of light that fills the panel and then fades off the reel.
		local flash = Instance.new("Frame")
		flash.Name = "Flash"
		flash.AnchorPoint = Vector2.new(0.5, 0.5)
		flash.Position = UDim2.fromScale(0.5, 0.45)
		flash.SizeConstraint = Enum.SizeConstraint.RelativeXX
		flash.BackgroundColor3 = Color3.fromRGB(255, 240, 185)
		flash.BorderSizePixel = 0
		flash.ZIndex = 3
		flash.Parent = introLayer
		local flashRound = Instance.new("UICorner")
		flashRound.CornerRadius = UDim.new(0.5, 0)
		flashRound.Parent = flash
		local introHint = UIStyle.text(introLayer, "Hint", UDim2.new(0, 14, 1, -40), UDim2.new(1, -28, 0, 26), SIZES.small, C.muted)
		introHint.Text = "TAP TO SKIP"
		introHint.TextXAlignment = Enum.TextXAlignment.Center
		introHint.ZIndex = 2

		-- A mesh in a 3D view only appears once it has downloaded, so the crate would open with pieces missing the first
		-- time. This starts when the Shop is first opened, so it is normally done long before a crate is.
		local crateLoaded = false
		task.spawn(function()
			local template = ReplicatedStorage:WaitForChild(ShopRemotes.CRATE_MODEL_NAME, 60)
			if template then
				pcall(function()
					ContentProvider:PreloadAsync({ template })
				end)
			end
			crateLoaded = true
		end)

		-- Swings a part about a hinge across the crate.
		local function swung(hinge: Vector3, degrees: number): CFrame
			return CFrame.new(hinge) * CFrame.Angles(math.rad(degrees), 0, 0) * CFrame.new(-hinge)
		end

		local function backOut(u: number): number
			local over = 1.4
			return 1 + (over + 1) * (u - 1) ^ 3 + over * (u - 1) ^ 2
		end

		-- Plays the crate's intro for `crate`. Yields until the light has filled the panel, or it was skipped or left.
		local function runIntro(crate: GearStatsConfig.Crate)
			local template = ReplicatedStorage:FindFirstChild(ShopRemotes.CRATE_MODEL_NAME)
			if template == nil or not template:IsA("Model") then
				if openSound then
					openSound:Play()
				end
				introLayer.Visible = false
				return
			end
			local viewport = Instance.new("ViewportFrame")
			viewport.Name = "Crate"
			viewport.Size = UDim2.fromScale(1, 1)
			viewport.BackgroundColor3 = C.ink
			viewport.BorderSizePixel = 0
			viewport.Ambient = Color3.fromRGB(150, 150, 165)
			viewport.LightColor = Color3.fromRGB(255, 255, 255)
			viewport.LightDirection = Vector3.new(0.5, -1, 0.7)
			viewport.Parent = introLayer
			introHint.Visible = true
			local loadUntil = os.clock() + CRATE_LOAD_WAIT_SECONDS
			while not crateLoaded and os.clock() < loadUntil and holder.Visible and not skipped do
				RunService.RenderStepped:Wait()
			end
			local model = template:Clone()
			model:PivotTo(CFrame.new())
			model.Parent = viewport

			-- This crate's colour and labels, and which pieces move how.
			local still: { { part: BasePart, base: CFrame } } = {}
			local lid: { { part: BasePart, base: CFrame } } = {}
			local latches: { { part: BasePart, base: CFrame, hinge: Vector3, delay: number } } = {}
			local body: BasePart? = nil
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					local piece = string.match(part.Name, "_(%w+)$") or ""
					local labelOf = string.match(piece, "^LidLabel(%w+)$") or string.match(piece, "^Label(%w+)$")
					if labelOf and labelOf ~= crate.id then
						part:Destroy()
					elseif string.sub(piece, 1, 8) == "Platform" or string.sub(piece, 1, 5) == "Plate" then
						-- Stays where it is.
						continue
					elseif piece == "LatchLeft" or piece == "LatchRight" then
						local hinge = Vector3.new(0, part.Position.Y - part.Size.Y / 2 + 0.08, part.Position.Z + part.Size.Z / 2)
						table.insert(latches, { part = part, base = part.CFrame, hinge = hinge, delay = if piece == "LatchLeft" then 0 else INTRO.LatchGap })
					elseif string.sub(piece, 1, 3) == "Lid" then
						if piece == "Lid" then
							part.Color = crate.colour
						end
						table.insert(lid, { part = part, base = part.CFrame })
					else
						if piece == "Body" then
							part.Color = crate.colour
							body = part
						end
						table.insert(still, { part = part, base = part.CFrame })
					end
				end
			end
			local bodyPart = body :: BasePart
			local lidHinge = Vector3.new(0, bodyPart.Position.Y + bodyPart.Size.Y / 2, bodyPart.Position.Z + bodyPart.Size.Z / 2)

			local camera = Instance.new("Camera")
			camera.FieldOfView = 30
			camera.Parent = viewport
			viewport.CurrentCamera = camera
			local target = Vector3.new(-0.4, 2, 0)
			local farEye = Vector3.new(-4, 5.2, -11.5)
			local nearEye = Vector3.new(-3.5, 4.6, -9.9)

			local dropAt = INTRO.DropSeconds
			local rattleAt = dropAt + INTRO.BounceSeconds
			local latchAt = rattleAt + INTRO.RattleSeconds
			local lidAt = latchAt + INTRO.LidAfter
			local flashAt = lidAt + INTRO.FlashAfter
			local filledAt = flashAt + INTRO.FlashSeconds

			flash.Size = UDim2.fromScale(0, 0)
			flash.BackgroundTransparency = 0
			flash.Visible = false
			local dropped, rattled, unlatched = false, false, false
			local started = os.clock()
			while holder.Visible and not skipped do
				local t = os.clock() - started
				-- The whole crate: falling, one small bounce, then rattling harder and harder.
				local crateMove = CFrame.new()
				if t < dropAt then
					crateMove = CFrame.new(0, INTRO.DropHeight * (1 - (t / dropAt) ^ 2), 0)
				elseif t < rattleAt then
					crateMove = CFrame.new(0, INTRO.BounceHeight * math.sin(math.pi * (t - dropAt) / INTRO.BounceSeconds), 0)
				elseif t < latchAt then
					local u = (t - rattleAt) / INTRO.RattleSeconds
					local swing = math.rad(INTRO.RattleDegrees) * u * math.sin(t * 70)
					crateMove = CFrame.Angles(0, swing * 0.5, swing) * CFrame.new(0, 0.05 * u * math.abs(math.sin(t * 55)), 0)
				end
				for _, entry in ipairs(still) do
					entry.part.CFrame = crateMove * entry.base
				end
				-- The lid swings up about its hinge, past open and back a little.
				local lidU = math.clamp((t - lidAt) / INTRO.LidSeconds, 0, 1)
				local lidSwing = crateMove * swung(lidHinge, INTRO.LidDegrees * backOut(lidU))
				if lidU <= 0 then
					lidSwing = crateMove
				end
				for _, entry in ipairs(lid) do
					entry.part.CFrame = lidSwing * entry.base
				end
				-- The latches snap down, one after the other.
				for _, entry in ipairs(latches) do
					local u = math.clamp((t - latchAt - entry.delay) / INTRO.LatchSeconds, 0, 1)
					entry.part.CFrame = crateMove * swung(entry.hinge, -INTRO.LatchDegrees * (1 - (1 - u) ^ 2)) * entry.base
				end
				-- The camera moves in as it rattles.
				local push = math.clamp((t - dropAt) / (latchAt - dropAt), 0, 1)
				camera.CFrame = CFrame.lookAt(farEye:Lerp(nearEye, push * push * (3 - 2 * push)), target)

				if not dropped and t >= dropAt then
					dropped = true
					if dropSound then
						dropSound:Play()
					end
				end
				if not rattled and t >= rattleAt then
					rattled = true
					if rattleSound then
						rattleSound:Play()
					end
				end
				if not unlatched and t >= latchAt then
					unlatched = true
					-- (The recording runs longer than the rattle.)
					if rattleSound then
						rattleSound:Stop()
					end
					if openSound then
						openSound:Play()
					end
				end
				if t >= flashAt then
					local u = math.min(1, (t - flashAt) / INTRO.FlashSeconds)
					flash.Visible = true
					local size = 2.4 * u * u
					flash.Size = UDim2.fromScale(size, size)
				end
				if t >= filledAt then
					break
				end
				RunService.RenderStepped:Wait()
			end
			viewport:Destroy()
			introHint.Visible = false
			if skipped or not holder.Visible then
				for _, playing in ipairs({ dropSound, rattleSound, openSound }) do
					if playing then
						playing:Stop()
					end
				end
				introLayer.Visible = false
			else
				-- Full of light: fade it off the reel, which starts spinning underneath.
				flash.Size = UDim2.fromScale(2.4, 2.4)
				local fade = TweenService:Create(flash, TweenInfo.new(INTRO.FadeSeconds), { BackgroundTransparency = 1 })
				fade.Completed:Once(function()
					introLayer.Visible = false
				end)
				fade:Play()
			end
		end

		-- One card on the strip: its preview, name and a bar in its rarity's colour.
		local function reelCard(index: number, piece: GearStats.Piece): (Frame?, UIStroke?)
			local rarity = GearStats.rarity(piece.rarity)
			local look = ShopConfig.find(piece.look)
			if rarity == nil or look == nil then
				return nil, nil
			end
			local card = UIStyle.frame(reelStrip, "Card_" .. index, UDim2.fromOffset((index - 1) * reelStep, 8),
				UDim2.fromOffset(REEL.CardWidth, REEL.CardHeight), C.navyDeep:Lerp(rarity.colour, 0.16))
			card.Visible = false
			local edge = UIStyle.stroke(card, rarity.colour, 1, 0.5)
			local shown = GearPreview.build(card, look, UDim2.fromOffset(6, 6), UDim2.new(1, -12, 0, REEL.CardHeight - 62))
			shown.BackgroundTransparency = 1
			local name = UIStyle.text(card, "Name", UDim2.new(0, 8, 1, -54), UDim2.new(1, -16, 0, 36), SIZES.small, C.white, UIStyle.heading())
			name.Text = string.upper(look.name)
			name.TextXAlignment = Enum.TextXAlignment.Center
			UIStyle.frame(card, "Bar", UDim2.new(0, 0, 1, -12), UDim2.new(1, 0, 0, 12), rarity.colour)
			return card, edge
		end

		-- Spins the strip and stops on `prize`. Yields until it has stopped, or the player walked away from the counter.
		local function runReel(crate: GearStatsConfig.Crate, prize: GearStats.Piece)
			skipped = false
			reelTitle.Text = crate.name
			reelStrip:ClearAllChildren()
			introLayer.Visible = true
			reelLayer.Visible = true
			skipHint.Visible = true
			local cards: { Frame } = {}
			local prizeEdge: UIStroke? = nil
			for index = 1, REEL.Cards do
				local card, edge = reelCard(index, if index == REEL.PrizeAt then prize else GearStats.roll(fillerRandom, crate))
				if card then
					cards[index] = card
				end
				if index == REEL.PrizeAt then
					prizeEdge = edge
				end
				if index % CARDS_PER_FRAME == 0 then
					RunService.RenderStepped:Wait()
				end
			end
			runIntro(crate)
			-- In the Shop's design size: the panel is scaled as a whole, so measure that from the strip.
			local scale = math.max(reelStrip.AbsoluteSize.X / (REEL.Cards * reelStep), 0.01)
			local windowWidth = reelWindow.AbsoluteSize.X / scale
			local stopOffset = fillerRandom:NextNumber(-REEL.StopOffset, REEL.StopOffset)
			-- Starts with the window already full of cards.
			local startX = 0
			local endX = windowWidth / 2 - ((REEL.PrizeAt - 1) * reelStep + REEL.CardWidth / 2 + stopOffset)
			local firstShown, lastShown = 1, 0
			local function place(x: number)
				reelStrip.Position = UDim2.fromOffset(x, 0)
				-- Only the cards on screen are visible, so only they draw.
				local first = math.max(1, math.floor(-x / reelStep) + 1)
				local last = math.min(REEL.Cards, math.floor((windowWidth - x) / reelStep) + 1)
				if first ~= firstShown or last ~= lastShown then
					for index = firstShown, lastShown do
						if cards[index] and (index < first or index > last) then
							cards[index].Visible = false
						end
					end
					for index = first, last do
						if cards[index] then
							cards[index].Visible = true
						end
					end
					firstShown, lastShown = first, last
				end
			end
			place(startX)
			local started = os.clock()
			local lastCard = 0
			local lastTick = 0
			while holder.Visible and not skipped do
				local u = math.min(1, (os.clock() - started) / REEL.Seconds)
				-- Fast at first, then a long slow finish.
				local eased = 1 - (1 - u) ^ 4
				local x = startX + (endX - startX) * eased
				place(x)
				local passing = math.floor((windowWidth / 2 - x) / reelStep)
				if passing ~= lastCard then
					lastCard = passing
					if tickSound and os.clock() - lastTick >= 1 / REEL.TicksPerSecond then
						lastTick = os.clock()
						tickSound:Play()
					end
				end
				if u >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end
			place(endX)
			skipHint.Visible = false
			if prizeEdge then
				prizeEdge.Transparency = 0
				prizeEdge.Thickness = 4
			end
			if holder.Visible and not skipped then
				task.wait(REEL.HoldSeconds)
			end
			reelLayer.Visible = false
			reelStrip:ClearAllChildren()
		end

		local busy = false

		-- Choosing a crate: one button each, the chosen one in yellow.
		local crateButtons: { [string]: TextButton } = {}
		local function drawCrate()
			title.Text = selected.name
			price.Text = CoinConfig.format(selected.price)
			helps.Text = "HELPS " .. GearStats.liftsText(selected.slot)
			for id, button in pairs(crateButtons) do
				local chosen = id == selected.id
				button.BackgroundColor3 = if chosen then C.yellow else C.navy
				button.TextColor3 = if chosen then C.ink else C.white
			end
		end
		local crateCount = #GearStatsConfig.Crates
		for index, crate in ipairs(GearStatsConfig.Crates) do
			local button = Instance.new("TextButton")
			button.Name = "Crate_" .. crate.id
			button.Position = UDim2.new((index - 1) / crateCount, 14 - 28 * (index - 1) / crateCount, 0, 10)
			button.Size = UDim2.new(1 / crateCount, -28 / crateCount - 4, 0, 34)
			button.BorderSizePixel = 0
			button.FontFace = UIStyle.heading()
			button.TextSize = SIZES.small
			button.Text = crate.button
			button.Parent = info
			UIStyle.stroke(button, C.yellow, 1, 0.4)
			button.Activated:Connect(function()
				if busy then
					return
				end
				selected = crate
				confirmUntil = 0
				drawCrate()
				drawOpen()
			end)
			crateButtons[crate.id] = button
		end
		drawCrate()

		openButton.Activated:Connect(function()
			if busy then
				return
			end
			if os.clock() >= confirmUntil then
				confirmUntil = os.clock() + CONFIRM_SECONDS
				drawOpen()
				task.delay(CONFIRM_SECONDS + 0.05, drawOpen)
				return
			end
			confirmUntil = 0
			busy = true
			clearReveal()
			status.TextColor3, status.Text = C.muted, "Opening..."
			openButton.Text = "OPENING..."
			local crate = selected
			local ok, done, message, view, id, piece = pcall(function()
				return remotes.crate:InvokeServer(crate.id)
			end)
			if ok then
				apply(view)
				-- It's saved already; the reel only shows it.
				if done and typeof(id) == "string" and piece then
					status.Text = ""
					runReel(crate, piece)
					showPiece(id, piece)
				end
				status.TextColor3 = if done then C.yellow else C.red
				status.Text = if typeof(message) == "string" then message else ""
			else
				status.TextColor3, status.Text = C.red, "The shop didn't answer. Try again."
			end
			busy = false
			drawOpen()
		end)

		wearButton.Activated:Connect(function()
			local id = currentId
			if busy or id == nil then
				return
			end
			busy = true
			local ok, done, message = pcall(function()
				return gearRemotes.setPiece:InvokeServer(id)
			end)
			busy = false
			if ok then
				status.TextColor3 = if done then C.yellow else C.red
				status.Text = if typeof(message) == "string" then message else ""
				if done then
					wearButton.Visible, scrapButton.Visible = false, false
				end
			end
		end)
		scrapButton.Activated:Connect(function()
			local id, piece = currentId, currentPiece
			local rarity = if piece then GearStats.rarity(piece.rarity) else nil
			if busy or id == nil or rarity == nil then
				return
			end
			-- The first press asks; a piece can't be got back.
			if os.clock() >= scrapSureUntil then
				scrapSureUntil = os.clock() + CONFIRM_SECONDS
				scrapButton.Text = "SURE? +" .. rarity.scrap
				task.delay(CONFIRM_SECONDS + 0.05, function()
					if os.clock() >= scrapSureUntil and scrapButton.Visible then
						scrapButton.Text = "SCRAP +" .. rarity.scrap
					end
				end)
				return
			end
			scrapSureUntil = 0
			busy = true
			local ok, done, message = pcall(function()
				return gearRemotes.scrap:InvokeServer(id)
			end)
			busy = false
			if ok then
				status.TextColor3 = if done then C.yellow else C.red
				status.Text = if typeof(message) == "string" then message else ""
				if done then
					clearReveal()
					local gotView, view = pcall(function()
						return remotes.get:InvokeServer()
					end)
					if gotView then
						apply(view)
					end
				end
			end
			drawOpen()
		end)
		onCoinsChanged = drawOpen
		drawOpen()
	end

	local function build()
		if built then
			return
		end
		built = true
		buildCrates()
	end

	UIStyle.exitButton(holder, "Back", "BACK", UDim2.new(1, -150, 1, 20), function()
		holder.Visible = false
	end)

	local openedAt: Vector3? = nil
	local function open()
		build()
		holder.Visible = true
		status.TextColor3, status.Text = C.muted, "Gear comes from crates. Press once, then CONFIRM."
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		openedAt = if rootPart and rootPart:IsA("BasePart") then rootPart.Position else nil
		local ok, view = pcall(function()
			return remotes.get:InvokeServer()
		end)
		if ok then
			apply(view)
		end
	end
	remotes.open.OnClientEvent:Connect(function()
		task.spawn(open)
	end)

	-- Walking away from the counter closes the menu.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if holder.Visible and openedAt then
				local character = player.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				if rootPart == nil or not rootPart:IsA("BasePart")
					or (rootPart.Position - (openedAt :: Vector3)).Magnitude > CLOSE_DISTANCE then
					holder.Visible = false
				end
			end
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return ShopMenu
