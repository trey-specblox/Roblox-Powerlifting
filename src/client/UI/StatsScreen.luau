--!strict
--[[
	StatsScreen
	Client / UI

	The PLAYER STATS screen (GAME_DESIGN "One UI style for the whole game",
	user 2026-10-28: "the last photo should be the stat visual"; opened "a key
	plus a button"). Built from UIStyle. It only shows what the server answers
	(StatsRemotes.GET_MY_STATS, a read-only snapshot); it changes nothing.

	Opening: press OPEN_KEY (not while typing), or the STATS tab on the left edge
	of the screen (phones). OPEN_KEY again, BACK, or the tab closes it.

		left    the player's avatar, name, weight class, bodyweight and coins
		middle  COMPETITION NUMBER per lift and the total; PROVEN (Competition
		        Scale) per lift, or UNPROVEN, and the BEST TOTAL; all for the
		        build of the current weight class
		right   TECHNIQUE: a five-cornered radar of the five trainable stats
		        (effective values, the outer edge = 100) with each stat's name
		        and value at its corner
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local CoinConfig = require(Shared:WaitForChild("Config"):WaitForChild("CoinConfig"))
local StatsRemotes = require(Shared:WaitForChild("Stats"):WaitForChild("StatsRemotes"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local C = UIStyle.Colours
local SIZES = UIStyle.TextSizes

local StatsScreen = {}

local OPEN_KEY = Enum.KeyCode.C
local PANEL_WIDTH, PANEL_HEIGHT = 940, 520
local RADAR_RADIUS = 118
local started = false

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d kg", kg) else string.format("%.1f kg", kg)
end

-- A straight line from `a` to `b` (pixels inside `parent`).
local function line(parent: Instance, name: string, a: Vector2, b: Vector2, thickness: number, colour: Color3,
	transparency: number?): Frame
	local delta = b - a
	local piece = UIStyle.frame(parent, name, UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
		UDim2.fromOffset(delta.Magnitude, thickness), colour, math.deg(math.atan2(delta.Y, delta.X)))
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.BackgroundTransparency = transparency or 0
	return piece
end

local function dot(parent: Instance, name: string, at: Vector2, size: number, colour: Color3): Frame
	local piece = UIStyle.frame(parent, name, UDim2.fromOffset(at.X, at.Y), UDim2.fromOffset(size, size), colour)
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = piece
	return piece
end

-- Corner `index` of `count` at `radius` around `centre`, the first at the top, going clockwise.
local function corner(centre: Vector2, radius: number, index: number, count: number): Vector2
	local angle = math.rad(-90 + (index - 1) * 360 / count)
	return centre + Vector2.new(math.cos(angle), math.sin(angle)) * radius
end

function StatsScreen.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local remotes = StatsRemotes.waitForClient(ReplicatedStorage)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Stats"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	UIStyle.fitToScreen(gui) -- shrink on short screens so nothing overlaps

	-- The STATS tab on the left edge (also the way in on a phone).
	local tab = Instance.new("TextButton")
	tab.Name = "Tab"
	tab.AnchorPoint = Vector2.new(0, 0.5)
	tab.Position = UDim2.new(0, 0, 0.5, 0)
	tab.Size = UDim2.fromOffset(118, 44)
	tab.BackgroundColor3 = C.ink
	tab.BorderSizePixel = 0
	tab.AutoButtonColor = true
	tab.Text = ""
	tab.Parent = gui
	UIStyle.stroke(tab, C.yellow, 2)
	local tabText = UIStyle.text(tab, "Text", UDim2.fromOffset(10, 0), UDim2.new(1, -40, 1, 0), SIZES.body, C.white,
		UIStyle.heading())
	tabText.Text = "STATS"
	UIStyle.slashes(tab, UDim2.new(1, -28, 0, 9), 26)
	local keyHint = UIStyle.text(tab, "Key", UDim2.new(0, 10, 1, 2), UDim2.fromOffset(100, 16), SIZES.small, C.muted)
	keyHint.Text = "[" .. OPEN_KEY.Name .. "]"

	-- The panel.
	local holder, body = UIStyle.panel(gui, "Panel", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT))
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Visible = false
	UIStyle.titleTag(holder, "Tag", "PLAYER STATS", UDim2.fromOffset(-18, -30), UDim2.fromOffset(300, 52), nil, "star")

	-- Left: avatar, name, class.
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.Position = UDim2.fromOffset(34, 44)
	avatar.Size = UDim2.fromOffset(200, 200)
	avatar.BackgroundColor3 = C.navyDeep
	avatar.BorderSizePixel = 0
	avatar.Image = ""
	avatar.Parent = body
	UIStyle.stroke(avatar, C.white, 2)
	local nameSlab = UIStyle.frame(body, "NameSlab", UDim2.fromOffset(24, 258), UDim2.fromOffset(230, 42), C.white, -3)
	local nameText = UIStyle.text(nameSlab, "Text", UDim2.fromOffset(10, 0), UDim2.new(1, -20, 1, 0), SIZES.body, C.ink,
		UIStyle.heading(), Enum.TextXAlignment.Center)
	nameText.Text = player.DisplayName
	local classText = UIStyle.text(body, "Class", UDim2.fromOffset(24, 314), UDim2.fromOffset(230, 30), SIZES.heading,
		C.yellow, UIStyle.heading(), Enum.TextXAlignment.Center)
	local weightText = UIStyle.text(body, "Bodyweight", UDim2.fromOffset(24, 348), UDim2.fromOffset(230, 48), SIZES.body,
		C.white, nil, Enum.TextXAlignment.Center)
	-- The coins (GAME_DESIGN 30.6), under the bodyweight.
	local coinsText = UIStyle.text(body, "Coins", UDim2.fromOffset(24, 410), UDim2.fromOffset(230, 30), SIZES.heading,
		C.yellow, UIStyle.heading(), Enum.TextXAlignment.Center)
	-- The meet titles (GAME_DESIGN §35.8), under the coins.
	local titlesText = UIStyle.text(body, "Titles", UDim2.fromOffset(24, 444), UDim2.fromOffset(230, 40), SIZES.small,
		C.white, UIStyle.heading(), Enum.TextXAlignment.Center)
	titlesText.TextWrapped = true

	-- Middle: Competition Number and Scale.
	local middleX = 290
	UIStyle.sectionHead(body, "CNHead", "COMPETITION NUMBER", UDim2.fromOffset(middleX, 40), 236, 300, "bar")
	local cnRows: { [string]: TextLabel } = {}
	local scaleRows: { [string]: TextLabel } = {}
	for index, lift in ipairs(ProgressionConfig.Lifts) do
		local y = 74 + (index - 1) * 40
		UIStyle.frame(body, lift .. "_Mark", UDim2.fromOffset(middleX, y + 8), UDim2.fromOffset(6, 22),
			UIStyle.LiftColours[lift] or C.yellow)
		UIStyle.text(body, lift .. "_Name", UDim2.fromOffset(middleX + 16, y), UDim2.fromOffset(140, 36), SIZES.body, C.white,
			UIStyle.heading()).Text = string.upper(lift)
		cnRows[lift] = UIStyle.text(body, lift .. "_CN", UDim2.fromOffset(middleX + 150, y), UDim2.fromOffset(140, 36),
			SIZES.heading, C.white, UIStyle.heading(), Enum.TextXAlignment.Right)
	end
	UIStyle.frame(body, "TotalRule", UDim2.fromOffset(middleX, 198), UDim2.fromOffset(290, 2), C.white)
	UIStyle.text(body, "TotalName", UDim2.fromOffset(middleX, 206), UDim2.fromOffset(140, 36), SIZES.body, C.yellow,
		UIStyle.heading()).Text = "TOTAL"
	local totalText = UIStyle.text(body, "Total", UDim2.fromOffset(middleX + 150, 206), UDim2.fromOffset(140, 36),
		SIZES.heading, C.yellow, UIStyle.heading(), Enum.TextXAlignment.Right)
	UIStyle.sectionHead(body, "ScaleHead", "PROVEN IN A MEET", UDim2.fromOffset(middleX, 266), 210, 300, "dots")
	for index, lift in ipairs(ProgressionConfig.Lifts) do
		local y = 298 + (index - 1) * 36
		UIStyle.text(body, lift .. "_ScaleName", UDim2.fromOffset(middleX + 16, y), UDim2.fromOffset(140, 32), SIZES.body,
			C.muted, UIStyle.heading()).Text = string.upper(lift)
		scaleRows[lift] = UIStyle.text(body, lift .. "_Scale", UDim2.fromOffset(middleX + 150, y), UDim2.fromOffset(140, 32),
			SIZES.body, C.white, UIStyle.heading(), Enum.TextXAlignment.Right)
	end
	-- The best Total from one finished meet in this class (personal, never a record).
	local bestY = 298 + #ProgressionConfig.Lifts * 36
	UIStyle.text(body, "BestTotalName", UDim2.fromOffset(middleX + 16, bestY), UDim2.fromOffset(140, 32), SIZES.body,
		C.yellow, UIStyle.heading()).Text = "BEST TOTAL"
	local bestTotalText = UIStyle.text(body, "BestTotal", UDim2.fromOffset(middleX + 150, bestY), UDim2.fromOffset(140, 32),
		SIZES.body, C.yellow, UIStyle.heading(), Enum.TextXAlignment.Right)
	local hint = UIStyle.text(body, "Hint", UDim2.fromOffset(middleX, bestY + 38), UDim2.fromOffset(300, 50), SIZES.small,
		C.muted)
	hint.Text = "Competition Number is what training built. A lift is proven when you make it in a meet in this class."

	-- Right: the technique radar.
	UIStyle.sectionHead(body, "TechHead", "TECHNIQUE", UDim2.fromOffset(640, 40), 118, 270, "corner")
	local radar = Instance.new("Frame")
	radar.Name = "Radar"
	radar.BackgroundTransparency = 1
	radar.Position = UDim2.fromOffset(620, 70)
	radar.Size = UDim2.fromOffset(300, 300)
	radar.Parent = body
	local radarValues = Instance.new("Frame")
	radarValues.Name = "Values"
	radarValues.BackgroundTransparency = 1
	radarValues.Size = UDim2.fromScale(1, 1)
	radarValues.Parent = radar
	local radarLabels: { TextLabel } = {}
	local loading = UIStyle.text(body, "Loading", UDim2.fromOffset(620, 440), UDim2.fromOffset(300, 30), SIZES.body, C.muted,
		nil, Enum.TextXAlignment.Center)

	UIStyle.exitButton(holder, "Back", "BACK", UDim2.new(1, -150, 1, 20), function()
		holder.Visible = false
	end)

	-- The radar's fixed grid: pentagon rings at 25/50/75/100 and the spokes.
	local centre = Vector2.new(150, 160)
	local function drawGrid(count: number)
		for _, child in ipairs(radar:GetChildren()) do
			if child ~= radarValues then
				child:Destroy()
			end
		end
		for ring = 1, 4 do
			local radius = RADAR_RADIUS * ring / 4
			for index = 1, count do
				line(radar, "Ring", corner(centre, radius, index, count), corner(centre, radius, index % count + 1, count),
					if ring == 4 then 2 else 1, C.white, if ring == 4 then 0 else 0.7)
			end
		end
		for index = 1, count do
			line(radar, "Spoke", centre, corner(centre, RADAR_RADIUS, index, count), 1, C.white, 0.7)
		end
	end

	local function draw(snapshot: StatsRemotes.StatsSnapshot)
		classText.Text = string.upper(snapshot.classLabel) .. " CLASS"
		weightText.Text = string.format("Bodyweight %.1f kg\nTarget %.1f kg", snapshot.bodyweightKg, snapshot.targetKg)
		coinsText.Text = string.format("%s %s", CoinConfig.format(snapshot.coins or 0), CoinConfig.Name)
		local titles = snapshot.titles or {}
		titlesText.Text = if #titles > 0 then string.upper(table.concat(titles, "  ·  ")) else ""
		local total = 0
		for _, lift in ipairs(ProgressionConfig.Lifts) do
			local cn = snapshot.competitionNumber[lift] or 0
			total += cn
			cnRows[lift].Text = kgText(cn)
			local scale = snapshot.competitionScale[lift] or 0
			scaleRows[lift].Text = if scale > 0 then kgText(scale) else "UNPROVEN"
			scaleRows[lift].TextColor3 = if scale > 0 then C.white else C.muted
		end
		totalText.Text = kgText(total)
		local bestTotal = snapshot.bestTotalKg or 0
		bestTotalText.Text = if bestTotal > 0 then kgText(bestTotal) else "—"
		bestTotalText.TextColor3 = if bestTotal > 0 then C.yellow else C.muted

		local stats = snapshot.technique
		local count = #stats
		drawGrid(math.max(count, 3))
		for _, child in ipairs(radarValues:GetChildren()) do
			child:Destroy()
		end
		for _, label in ipairs(radarLabels) do
			label:Destroy()
		end
		table.clear(radarLabels)
		if count < 3 then
			loading.Text = "No technique stats yet."
			return
		end
		loading.Text = ""
		local points: { Vector2 } = {}
		for index, view in ipairs(stats) do
			points[index] = corner(centre, RADAR_RADIUS * math.clamp(view.effective / 100, 0, 1), index, count)
		end
		for index, point in ipairs(points) do
			line(radarValues, "Edge", point, points[index % count + 1], 3, C.yellow)
		end
		for index, point in ipairs(points) do
			local view = stats[index]
			dot(radarValues, "Dot", point, 10, UIStyle.LiftColours[view.lift] or C.yellow)
			-- The stat's name and value just outside its corner.
			local labelAt = corner(centre, RADAR_RADIUS + 38, index, count)
			local label = UIStyle.text(radar, "Label", UDim2.fromOffset(labelAt.X, labelAt.Y), UDim2.fromOffset(150, 60),
				SIZES.small, C.white, UIStyle.heading(), Enum.TextXAlignment.Center)
			label.TextYAlignment = Enum.TextYAlignment.Center
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			-- Name in white, value in yellow under it (rich text keeps it one label).
			label.RichText = true
			label.Text = string.format('%s\n<font color="#FACE24">%.1f</font>', string.upper(view.name), view.effective)
			table.insert(radarLabels, label)
		end
	end

	local asking = false
	local function open()
		holder.Visible = true
		if avatar.Image == "" then
			task.spawn(function()
				local ok, image = pcall(function()
					return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot,
						Enum.ThumbnailSize.Size420x420)
				end)
				if ok then
					avatar.Image = image
				end
			end)
		end
		if asking then
			return
		end
		asking = true
		loading.Text = "Loading…"
		local ok, snapshot = pcall(function()
			return remotes.getMyStats:InvokeServer()
		end)
		asking = false
		if ok and snapshot then
			draw(snapshot :: StatsRemotes.StatsSnapshot)
		else
			loading.Text = "Stats are still loading. Try again in a moment."
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
		-- Not while typing in a box (chat, the meet's weight box, the deadlift typing).
		if gameProcessed or UserInputService:GetFocusedTextBox() ~= nil then
			return
		end
		if input.KeyCode == OPEN_KEY then
			toggle()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return StatsScreen
