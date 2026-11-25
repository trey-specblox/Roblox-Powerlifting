--!strict
--[[
	MeetCoachLook
	Client / Meet

	YOUR CHOSEN COACH AT YOUR MEETS (GAME_DESIGN §40.5; user 2026-11-24: "Let's do show your chosen coach at meets";
	2026-11-23: "Client based as in only the user can see their own coach talking to them"). Every platform has one
	coach figure the server builds and walks (out behind the lifter, the chalk, the back slaps), and its name tag and
	speech bubble are already moved into the lifter's own screen (LocalMeetVenue.staffFor). On THIS player's screen
	only, that coach becomes the coach they chose: the tag says their name and the shirt takes their colour (the squat
	coach yellow, bench red, deadlift blue). Everyone else keeps seeing the gym's own coach. With the gym owner as the
	coach (everyone's free basic coach), the tag says GYM OWNER and the look stays as it is.

	Until the three coaches' own bodies are made (Blender, later), a chosen coach is the meet coach in their colours.

	Display only: who the active coach is comes from the server (CoachingRemotes.GET).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared:WaitForChild("Config"):WaitForChild("QuestConfig"))
local CoachingConfig = require(Shared:WaitForChild("Config"):WaitForChild("CoachingConfig"))
local CoachingRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("CoachingRemotes"))

local MeetCoachLook = {}

-- The meet coach's own shirt colour (MeetFigures OUTFITS.Coach.top): the parts in it are the shirt.
local GYM_COACH_TOP = Color3.fromRGB(28, 40, 78)
local TAG_WIDTH = 150

local started = false

local function close(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.03
end

-- What the coach is called on the tag: "SQUATAVIOUS", "BENCHAMIN", "SUMO"; the gym owner's title for him.
local function tagFor(active: string): string
	local coach = QuestConfig.Coaches[active]
	if coach then
		return string.upper((string.gsub(coach.name, "^Coach%s+", "")))
	end
	return CoachingConfig.Owner.title
end

function MeetCoachLook.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local remotes = CoachingRemotes.waitForClient(ReplicatedStorage)

	local function activeCoach(): string
		for _ = 1, 4 do
			local ok, view = pcall(function()
				return remotes.get:InvokeServer()
			end)
			if ok and typeof(view) == "table" and typeof(view.active) == "string" then
				return view.active
			end
			task.wait(0.5)
		end
		return CoachingConfig.OwnerId
	end

	-- A coach's tag arrived on this screen: that platform's coach is this player's coach for this meet.
	local function dress(billboard: BillboardGui)
		local active = activeCoach()
		local label = billboard:FindFirstChild("Name")
		if label and label:IsA("TextLabel") then
			label.Text = tagFor(active)
			label.Size = UDim2.fromOffset(TAG_WIDTH, label.Size.Y.Offset)
		end
		local coach = QuestConfig.Coaches[active]
		local head = billboard.Adornee
		local figure = head and head.Parent
		if coach == nil or figure == nil or not figure:IsA("Model") then
			return
		end
		-- The shirt in the coach's colour, on this screen only (the parts stay the server's: nothing else changes).
		for _, part in ipairs(figure:GetDescendants()) do
			if part:IsA("BasePart") and close(part.Color, GYM_COACH_TOP) then
				part.Color = coach.shirt
			end
		end
	end

	local function watch(child: Instance)
		if child:IsA("BillboardGui") and child.Name == "CoachTag" then
			task.spawn(dress, child)
		end
	end
	for _, child in ipairs(playerGui:GetChildren()) do
		watch(child)
	end
	playerGui.ChildAdded:Connect(watch)
end

return MeetCoachLook
