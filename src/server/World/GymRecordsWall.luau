--!strict
--[[
	GymRecordsWall
	Server / World

	Fills in the hall's chalk GYM RECORDS table (RoomProps FRONT.RecordsWall,
	GAME_DESIGN.md §31.6, "The gym record wall — first build" step 3) from the
	saved gym records (GymRecords): each cell gets the holder's Roblox
	headshot, their username and the kg. An empty record shows "?" and "—".

	Display only: it reads GymRecords and never writes a record. It redraws a
	class whenever GymRecords says it changed (a record set here, or one read
	from another server about once a minute).

	STUDIO: the records there are test records (never the live wall), so the
	title says so.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ConfigFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local GymRecordsConfig = require(ConfigFolder:WaitForChild("GymRecordsConfig"))
local WeightClassConfig = require(ConfigFolder:WaitForChild("WeightClassConfig"))

local GymRecords = require(script.Parent.Parent:WaitForChild("Meet"):WaitForChild("GymRecords"))

local GymRecordsWall = {}

-- The wall's column names (RoomProps cells' "Lift" attribute) and the records they show.
local RECORD_FOR_COLUMN = { SQUAT = "Squat", BENCH = "Bench", DEADLIFT = "Deadlift", TOTAL = "Total" }

local tables: { SurfaceGui } = {}
local started = false

local function kgText(kg: number): string
	return string.format("%g KG", math.floor(kg * 100 + 0.5) / 100)
end

local function drawCell(cell: Frame, holder: GymRecords.Holder?)
	local avatar = cell:FindFirstChild("Avatar")
	local unknown = avatar and avatar:FindFirstChild("Unknown")
	local holderLabel = cell:FindFirstChild("Holder")
	local kgLabel = cell:FindFirstChild("Kg")
	if holder then
		if avatar and avatar:IsA("ImageLabel") then
			-- Studio's test players (negative ids) have no headshot; the "?" stays for them.
			avatar.Image = if holder.userId > 0
				then string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", holder.userId)
				else ""
		end
		if unknown and unknown:IsA("GuiObject") then
			unknown.Visible = holder.userId <= 0
		end
		if holderLabel and holderLabel:IsA("TextLabel") then
			holderLabel.Text = GymRecords.nameOf(holder.userId)
		end
		if kgLabel and kgLabel:IsA("TextLabel") then
			kgLabel.Text = kgText(holder.kg)
		end
	else
		if avatar and avatar:IsA("ImageLabel") then
			avatar.Image = ""
		end
		if unknown and unknown:IsA("GuiObject") then
			unknown.Visible = true
		end
		if holderLabel and holderLabel:IsA("TextLabel") then
			holderLabel.Text = "—"
		end
		if kgLabel and kgLabel:IsA("TextLabel") then
			kgLabel.Text = "— KG"
		end
	end
end

-- Redraws one class's row on every records table.
local function drawClass(classKey: string)
	local classRecords = GymRecords.get(classKey)
	if classRecords == nil then
		return
	end
	for _, gui in ipairs(tables) do
		for column, record in pairs(RECORD_FOR_COLUMN) do
			local cell = gui:FindFirstChild(string.format("Record_%s_%s", classKey, column))
			if cell and cell:IsA("Frame") then
				drawCell(cell, classRecords[record])
			end
		end
	end
end

local function drawAll()
	for _, class in ipairs(WeightClassConfig.Classes) do
		drawClass(class.label)
	end
end

local function attach(instance: Instance)
	if not instance:IsA("SurfaceGui") or table.find(tables, instance) then
		return
	end
	table.insert(tables, instance)
	instance.Destroying:Connect(function()
		local index = table.find(tables, instance)
		if index then
			table.remove(tables, index)
		end
	end)
	if RunService:IsStudio() then
		local title = instance:FindFirstChild("Title")
		if title and title:IsA("TextLabel") then
			title.Text = "GYM RECORDS (STUDIO TEST)"
		end
	end
	for _, class in ipairs(WeightClassConfig.Classes) do
		task.spawn(drawClass, class.label)
	end
end

function GymRecordsWall.start()
	if started then
		return
	end
	started = true
	GymRecords.onChanged(drawClass)
	for _, gui in ipairs(CollectionService:GetTagged(GymRecordsConfig.WallTag)) do
		attach(gui)
	end
	CollectionService:GetInstanceAddedSignal(GymRecordsConfig.WallTag):Connect(attach)
	task.spawn(drawAll)
end

return GymRecordsWall
