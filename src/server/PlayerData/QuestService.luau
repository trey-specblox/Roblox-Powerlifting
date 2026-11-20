--!strict
--[[
	QuestService
	Server / PlayerData

	The coaches' daily quests (GAME_DESIGN §40.6, user 2026-11-19):

		- puts the three coaches in the upstairs Coach room, at the points RoomProps tags QuestConfig.CoachSpotTag (each
		  with a "Lift" attribute): a MeetFigures coach in that lift's colours, with a "Talk" prompt the client's
		  CoachDialogue answers
		- QuestRemotes.GET: today's quests, for the dialogue and the quest tracker (reads only)
		- QuestRemotes.TAKE: asking a coach for their quest puts it on the player's tracker (the one write here)
		- tell(player, progress): after a meet's save (LocalMeetService), a line per quest it moved

	The progress and the strength reward are saved by the meet itself (ProfileOperations.addQuestGoodLifts, in the
	meet's one write). This service writes only the "taken" flag (ProfileOperations.takeQuest), which changes no stat.

	PERFORMANCE: three standing figures (about 16 parts each, anchored, no collision), built once.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared:WaitForChild("Config"):WaitForChild("QuestConfig"))
local QuestRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("QuestRemotes"))

local ServerFolder = script.Parent.Parent
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local ProfileOperations = require(script.Parent:WaitForChild("ProfileOperations"))
local MeetFigures = require(ServerFolder:WaitForChild("Meet"):WaitForChild("MeetFigures"))

local QuestService = {}

-- The tag the client looks for on a coach's prompt (its "Lift" attribute says which coach).
QuestService.PromptTag = "QuestCoachPrompt"

local MIN_SECONDS_BETWEEN_ASKS = 0.5
-- How far above the head the coach's name tag floats (studs).
local TAG_HEIGHT = 3.6

local started = false
local remotes: QuestRemotes.RemoteSet? = nil
local lastAsked: { [Player]: number } = {}
local placed: { [Instance]: boolean } = {}
local folder: Folder? = nil

-- One coach at a tagged spot: the figure, facing the way the spot says, and its prompt.
local function placeCoach(spot: Instance)
	if placed[spot] or not spot:IsA("BasePart") then
		return
	end
	local lift = spot:GetAttribute("Lift")
	local coach = if typeof(lift) == "string" then QuestConfig.Coaches[lift] else nil
	if coach == nil then
		return
	end
	placed[spot] = true
	local facing = spot:GetAttribute("Facing")
	local forward = if typeof(facing) == "Vector3" and facing.Magnitude > 0 then facing.Unit else spot.CFrame.LookVector
	local at = Vector3.new(spot.Position.X, spot.Position.Y - spot.Size.Y / 2, spot.Position.Z)
	local _, figure = MeetFigures.build(folder :: Folder, "Coach", at, at + forward * 10, nil,
		{ top = coach.shirt, trousers = coach.trousers, tag = coach.title })
	if figure == nil then
		return
	end
	figure.Name = "QuestCoach_" .. lift
	figure:SetAttribute("Lift", lift)
	-- The name tag clear of the cartoon head (at MeetFigures' height the head covered its middle; Studio 2026-11-19).
	local tag = figure:FindFirstChild("CoachTag")
	if tag and tag:IsA("BillboardGui") then
		tag.StudsOffset = Vector3.new(0, TAG_HEIGHT, 0)
		tag.MaxDistance = 40
	end
	local root = figure:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Talk"
	prompt.ObjectText = coach.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Lift", lift)
	prompt:AddTag(QuestService.PromptTag)
	prompt.Parent = root
end

--[[
	After a meet's save: one line per quest it moved, sent to that player's screen. `progress` comes from
	ProfileOperations.addQuestGoodLifts.
]]
function QuestService.tell(player: Player, progress: { ProfileOperations.QuestProgress })
	local set = remotes
	if set == nil or player.Parent == nil or #progress == 0 then
		return
	end
	local lines: { string } = {}
	for _, step in ipairs(progress) do
		local coach = QuestConfig.Coaches[step.lift]
		local name = if coach then coach.name else step.lift
		local plural = QuestConfig.Plural[step.lift] or step.lift
		if step.finished then
			local gained = if step.cnBefore and step.cnAfter
				then string.format(" +%.2f kg %s strength.", step.cnAfter - step.cnBefore, string.lower(step.lift))
				else ""
			table.insert(lines, string.format("%s's quest done: %d/%d good %s!%s", name, step.goodLifts, step.needed,
				plural, gained))
		else
			table.insert(lines, string.format("%s's quest: %d/%d good %s today.", name, step.goodLifts, step.needed, plural))
		end
	end
	set.news:FireClient(player, lines)
end

function QuestService.start()
	if started then
		return
	end
	started = true
	local set = QuestRemotes.createOnServer(ReplicatedStorage)
	remotes = set
	set.get.OnServerInvoke = function(player: Player): { [string]: QuestRemotes.QuestView }?
		local now = os.clock()
		if now - (lastAsked[player] or -math.huge) < MIN_SECONDS_BETWEEN_ASKS then
			return nil
		end
		lastAsked[player] = now
		local data = PlayerDataService.getData(player)
		if data == nil then
			return nil
		end
		return ProfileOperations.getDailyQuests(data, os.time())
	end
	set.take.OnServerInvoke = function(player: Player, lift: any): { [string]: QuestRemotes.QuestView }?
		if typeof(lift) ~= "string" or QuestConfig.Coaches[lift] == nil then
			return nil
		end
		local now = os.clock()
		if now - (lastAsked[player] or -math.huge) < MIN_SECONDS_BETWEEN_ASKS then
			return nil
		end
		lastAsked[player] = now
		local took = false
		PlayerDataService.update(player, function(data)
			took = ProfileOperations.takeQuest(data, lift, os.time())
		end)
		local data = PlayerDataService.getData(player)
		if not took or data == nil then
			return nil
		end
		return ProfileOperations.getDailyQuests(data, os.time())
	end

	local made = Instance.new("Folder")
	made.Name = "QuestCoaches"
	made.Parent = Workspace
	folder = made
	for _, spot in ipairs(CollectionService:GetTagged(QuestConfig.CoachSpotTag)) do
		task.spawn(placeCoach, spot)
	end
	CollectionService:GetInstanceAddedSignal(QuestConfig.CoachSpotTag):Connect(function(spot)
		task.spawn(placeCoach, spot)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastAsked[player] = nil
	end)
end

return QuestService
