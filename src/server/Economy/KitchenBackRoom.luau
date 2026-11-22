--!strict
--[[
	KitchenBackRoom
	Server / Economy

	W Chews' back room behind the EMPLOYEES ONLY door (GAME_DESIGN §40.7, user 2026-11-21): the mafia boss cow's
	room. Its furniture is placed by KitchenBuilding with the rest of the restaurant kit (WChewsLayout); this module
	adds the two things that are not plain furniture:

		- THE LUCK WHEEL: 20 copies of one wedge (WcWheelWedge) round the wheel's axis, in the model
		  KitchenHall.BackRoom.LuckWheel, whose pivot is the axis (a client turns the whole wheel with PivotTo for its
		  own spin). Wedge i (attribute Index) stands (i - 1) steps clockwise from the top, seen from the front.
		- THE MAFIA BOSS COW (CowBoss) standing beside his wheel with his name tag, and a copy of him in
		  ReplicatedStorage.KitchenModels for the chef scene's walk-on (KitchenScene).

	Nothing in this room is ever bet (Roblox bans simulated gambling): the wheel is a free daily spin and the cow's
	games are skill games (LuckService).

	Each wedge is painted in its band's colour with the band written on it ("4-10x", LuckConfig.Wedges), so the wheel
	shows the real odds: a band's chance is its share of the 20 wedges.

	PERFORMANCE: 40 wedge parts of 2 shared meshes (1,280 triangles) with 20 small text screens, and the cow's 20
	parts (3,088 triangles), all decor without shadows; one hidden block so nobody walks through him.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))
local LuckConfig = require(Shared:WaitForChild("Config"):WaitForChild("LuckConfig"))
local WChewsLayout = require(Shared:WaitForChild("Config"):WaitForChild("WChewsLayout"))
local LuckRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("LuckRemotes"))

local ServerFolder = script.Parent.Parent
local RoomProps = require(ServerFolder:WaitForChild("World"):WaitForChild("RoomProps"))
local StyledScreen = require(ServerFolder:WaitForChild("World"):WaitForChild("StyledScreen"))

local KitchenBackRoom = {}

KitchenBackRoom.CowName = "THE BOSS"

local TAG_GAP = 0.45 -- studs of air between the top of his hat and his name tag (as MeetFigures)

local function noShadows(model: Instance)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CastShadow = false
		end
	end
end

-- From a model's own origin frame to where its copy's pivot goes (a copy is pivoted at the bottom centre of its bounds).
local function pivotFrom(origin: CFrame, item: string): CFrame
	local offset = WChewsLayout.PivotOffset[item]
	return origin * CFrame.new(-offset.X, offset.Z, offset.Y)
end

-- The cow's name tag, in the look of every figure's (MeetFigures): a dark slab with white italic letters, sitting
-- just above his hat at every distance.
local function nameTag(cow: Model)
	local hat = cow:FindFirstChild("CowBoss_HeadHat", true)
	if hat == nil or not hat:IsA("BasePart") then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BossTag"
	billboard.Size = UDim2.fromOffset(220, 90)
	billboard.StudsOffset = Vector3.new(0, hat.Size.Y / 2 + TAG_GAP, 0)
	billboard.SizeOffset = Vector2.new(0, 0.5)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 80
	billboard.Adornee = hat
	billboard.Parent = cow
	local tag = Instance.new("TextLabel")
	tag.Name = "Name"
	tag.AnchorPoint = Vector2.new(0.5, 1)
	tag.Position = UDim2.fromScale(0.5, 1)
	tag.Size = UDim2.fromOffset(110, 22)
	tag.Rotation = -4
	tag.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
	tag.Text = KitchenBackRoom.CowName
	tag.TextColor3 = Color3.new(1, 1, 1)
	tag.TextScaled = true
	tag.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
	tag.Parent = billboard
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.new(1, 1, 1)
	edge.Thickness = 2
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = tag
end

--[[
	Paints a wedge in its prize's colour and writes the prize on it (LuckConfig.Wedges), along the wedge from the hub
	out to the rim. `outward`: the direction from the wheel's axis to this wedge's middle; `front`: the way the wheel
	faces.
]]
local LABEL_PIXELS_PER_STUD = 50
local LABEL_AT = 1.05 -- studs from the wedge's middle toward the rim
local function dress(wedge: Model, index: number, outward: Vector3, front: Vector3)
	local prize = LuckConfig.wedgePrize(index)
	local face = wedge:FindFirstChild("WcWheelWedge_Face", true)
	if prize == nil or face == nil or not face:IsA("BasePart") then
		return
	end
	face.Color = prize.colour
	face.Material = Enum.Material.SmoothPlastic
	local side = StyledScreen.faceToward(face, front)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Prize"
	gui.Face = side
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = LABEL_PIXELS_PER_STUD
	gui.LightInfluence = 0.3
	gui.Parent = face
	-- The screen's own up and right on that face, in the world, to turn the words along the wedge.
	local normal = face.CFrame:VectorToWorldSpace(Vector3.FromNormalId(side))
	local upLocal = if side == Enum.NormalId.Top then -Vector3.zAxis elseif side == Enum.NormalId.Bottom then Vector3.zAxis
		else Vector3.yAxis
	local up = face.CFrame:VectorToWorldSpace(upLocal)
	local right = up:Cross(normal)
	local along = math.deg(math.atan2(outward:Dot(right), outward:Dot(up)))
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, outward:Dot(right) * LABEL_AT * LABEL_PIXELS_PER_STUD, 0.5,
		-outward:Dot(up) * LABEL_AT * LABEL_PIXELS_PER_STUD)
	label.Size = UDim2.fromOffset(130, 46)
	label.Rotation = along - 90 -- (reads from the hub out to the rim)
	label.BackgroundTransparency = 1
	label.Text = LuckConfig.bandShort(prize) -- ("4-10x": the band; the exact result is drawn when the wheel stops)
	label.TextColor3 = prize.ink
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
	label.Parent = gui
	wedge:SetAttribute("Prize", prize.id)
end

--[[
	Builds the wheel and the cow in `hallFolder` (the hall's origin is `hall0`). Returns the wheel model and the cow
	(nil for one whose model didn't load).
]]
function KitchenBackRoom.build(hallFolder: Instance, hall0: CFrame): (Model?, Model?)
	local folder = Instance.new("Folder")
	folder.Name = "BackRoom"
	folder.Parent = hallFolder

	-- The wheel: its axis frame looks at the door (-Z), so turning round its Z turns the wheel in its own plane.
	local axis = hall0 * KitchenConfig.planSpot(WChewsLayout.Wheel.X, WChewsLayout.Wheel.Y, WChewsLayout.WheelAxis)
	local wedges = WChewsLayout.WheelWedges
	local wheel: Model? = nil
	if WChewsLayout.PivotOffset.WcWheelWedge then
		local made = Instance.new("Model")
		made.Name = "LuckWheel"
		for index = 1, wedges do
			local copy = RoomProps.propCopy("WcWheelWedge", 1)
			if copy == nil then
				break
			end
			copy.Name = string.format("Wedge_%02d", index)
			copy:SetAttribute("Index", index)
			noShadows(copy)
			local turned = axis * CFrame.Angles(0, 0, 2 * math.pi * (index - 1) / wedges)
			copy:PivotTo(pivotFrom(turned, "WcWheelWedge"))
			dress(copy, index, turned.UpVector, axis.LookVector)
			copy.Parent = made
		end
		if #made:GetChildren() == wedges then
			made.WorldPivot = axis
			made:SetAttribute("Wedges", wedges)
			-- The whole wheel streams in at once: a client turns it as one piece.
			made.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			made.Parent = folder
			wheel = made
		else
			made:Destroy()
			warn("[KitchenBackRoom] the luck wheel's wedge didn't load; no wheel")
		end
	end

	-- The cow, facing the door.
	local cow = if WChewsLayout.PivotOffset.CowBoss then RoomProps.propCopy("CowBoss", 1) else nil
	if cow then
		cow.Name = "CowBoss"
		noShadows(cow)
		-- A copy for the chef scene's walk-on (the scene's props live in KitchenModels: KitchenPans makes the folder).
		task.spawn(function()
			local shared = ReplicatedStorage:WaitForChild("KitchenModels", 120)
			if shared then
				local double = cow:Clone()
				double.Name = "CowBoss"
				double.Parent = shared
			end
		end)
		local stand = hall0 * KitchenConfig.planSpot(WChewsLayout.Cow.X, WChewsLayout.Cow.Y, 0)
		cow:PivotTo(pivotFrom(stand, "CowBoss"))
		nameTag(cow)
		cow.Parent = folder
		local block = Instance.new("Part")
		block.Name = "CowBlock"
		block.Anchored = true
		block.Transparency = 1
		block.CanQuery = false
		block.CanTouch = false
		block.CastShadow = false
		block.Size = Vector3.new(4.4, 7.6, 3.2)
		block.CFrame = stand * CFrame.new(0, 3.8, 0)
		block.Parent = folder
		-- "Talk" to him: the wheel and his games (LuckMenu, client). And how his portrait copy is framed in the
		-- dialogue (he is bigger than a coach and stands on his pivot: CoachDialogue).
		cow:SetAttribute("PortraitScale", 0.62)
		cow:SetAttribute("PortraitDrop", 2.15)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TalkPrompt"
		prompt.ActionText = "Talk"
		prompt.ObjectText = "The Boss"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 13
		prompt.RequiresLineOfSight = false
		prompt:AddTag(LuckRemotes.PromptTag)
		prompt.Parent = block
	else
		warn("[KitchenBackRoom] the mafia boss cow's model didn't load; the back room has no boss")
	end
	return wheel, cow
end

return KitchenBackRoom
