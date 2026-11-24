--!strict
--[[
	RankNameTags
	Client / UI

	The small name tag over OTHER players (GAME_DESIGN §41, References/Ranks and Titles Study.md): their rank emblem,
	their name, and their title under it in its rarity colour. It replaces Roblox's own name over their head.

	Kept small on purpose (the user's no-clutter rule; a DevForum lesson: big tags "get in the way of seeing things"):
		- made on THIS player's screen only (a BillboardGui in PlayerGui), never on their own character
		- only within NEAR_STUDS, never through walls, and only for the MAX_TAGS nearest players
		- hidden while this player is on their turn at a meet, during cutscenes (a scripted camera) and while
		  lifting at a meet
	The data comes from attributes the server sets (RankService): RankIndex, TitleId, TitleCount. Display only.

	PERFORMANCE: one BillboardGui per other player, about 20 frames each; visibility is rechecked every REFRESH seconds,
	not every frame.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RankLook = require(script.Parent:WaitForChild("RankLook"))
local UIFancy = require(script.Parent:WaitForChild("UIFancy"))
local MenuKeys = require(script.Parent:WaitForChild("MenuKeys"))
local make = UIFancy.make

local RankNameTags = {}

local NEAR_STUDS = 70
local MAX_TAGS = 16
local REFRESH = 0.4
local TAG_WIDTH, TAG_HEIGHT = 230, 50
local EMBLEM = 40

type Tag = { gui: BillboardGui, player: Player, connections: { RBXScriptConnection } }

local tags: { [Player]: Tag } = {}
local started = false

local function build(tag: Tag)
	local gui = tag.gui
	for _, child in ipairs(gui:GetChildren()) do
		child:Destroy()
	end
	local player = tag.player
	local rank = player:GetAttribute("RankIndex")
	local titleId = player:GetAttribute("TitleId")
	local count = player:GetAttribute("TitleCount")
	local rankNumber = if typeof(rank) == "number" then rank else 0
	RankLook.emblem(gui, "Emblem", UDim2.new(0, EMBLEM / 2, 0.5, 0), EMBLEM, rankNumber)
	local name = UIFancy.words(gui, "Name", UDim2.fromOffset(EMBLEM + 4, 2), UDim2.new(1, -EMBLEM - 4, 0, 22), 18, 2)
	name.Text = player.DisplayName
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextWrapped = false
	local title = UIFancy.words(gui, "Title", UDim2.fromOffset(EMBLEM + 4, 24), UDim2.new(1, -EMBLEM - 4, 0, 18), 14, 1.5)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextWrapped = false
	title.TextTruncate = Enum.TextTruncate.AtEnd
	RankLook.title(title, if typeof(titleId) == "string" then titleId else "", if typeof(count) == "number" then count else nil)
	if title.Text == "" then
		-- No title: the rank's name sits there instead, in grey.
		title.Text = RankLook.rankText(rankNumber)
		title.TextColor3 = Color3.fromRGB(190, 192, 200)
	end
end

local function attach(tag: Tag, character: Model)
	local head = character:WaitForChild("Head", 10)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if head == nil or tag.gui.Parent == nil then
		return
	end
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	tag.gui.Adornee = head :: BasePart
end

local function add(player: Player)
	if player == Players.LocalPlayer or tags[player] then
		return
	end
	local gui = make("BillboardGui", {
		Name = "RankTag_" .. player.Name, Size = UDim2.fromOffset(TAG_WIDTH, TAG_HEIGHT), StudsOffset = Vector3.new(0, 2.7, 0),
		AlwaysOnTop = false, LightInfluence = 0, MaxDistance = NEAR_STUDS, ResetOnSpawn = false, Enabled = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local tag: Tag = { gui = gui, player = player, connections = {} }
	tags[player] = tag
	build(tag)
	for _, attribute in ipairs({ "RankIndex", "TitleId", "TitleCount" }) do
		table.insert(tag.connections, player:GetAttributeChangedSignal(attribute):Connect(function()
			build(tag)
		end))
	end
	table.insert(tag.connections, player.CharacterAdded:Connect(function(character)
		attach(tag, character)
	end))
	if player.Character then
		task.spawn(attach, tag, player.Character)
	end
end

local function remove(player: Player)
	local tag = tags[player]
	if tag == nil then
		return
	end
	tags[player] = nil
	for _, connection in ipairs(tag.connections) do
		connection:Disconnect()
	end
	tag.gui:Destroy()
end

-- Whether tags should show at all right now on this screen.
local function allowed(): boolean
	local camera = Workspace.CurrentCamera
	if camera == nil or camera.CameraType == Enum.CameraType.Scriptable or MenuKeys.isOnTurn() then
		return false
	end
	return true
end

local function refresh()
	local camera = Workspace.CurrentCamera
	local show = allowed()
	local candidates: { { tag: Tag, distance: number } } = {}
	for _, tag in pairs(tags) do
		local head = tag.gui.Adornee
		if show and camera and head and head:IsA("BasePart") and head.Parent then
			local distance = (head.Position - camera.CFrame.Position).Magnitude
			if distance <= NEAR_STUDS then
				table.insert(candidates, { tag = tag, distance = distance })
			else
				tag.gui.Enabled = false
			end
		else
			tag.gui.Enabled = false
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)
	for index, candidate in ipairs(candidates) do
		candidate.tag.gui.Enabled = index <= MAX_TAGS
	end
end

function RankNameTags.start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(add)
	Players.PlayerRemoving:Connect(remove)
	for _, player in ipairs(Players:GetPlayers()) do
		add(player)
	end
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH)
		end
	end)
end

return RankNameTags
