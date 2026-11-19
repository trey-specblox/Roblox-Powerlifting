--[[
	ComputerLifterGear_Test (TEMPORARY TEST TOOL, run on the SERVER during a Studio play test, Hall 3 must be idle)

	What it does: makes one computer lifter of each body build (Skinny, SkinnyFat, Fit, Fat, Muscular, BigBuff) through
	the game's own ComputerLifters.spawnBody, so each gets the random gear a real meet gives it (GAME_DESIGN §38.4 step 4).
	The build is forced only inside this call (LifterBuild.forNumbers is put back at once). Nothing is saved.

	MODE = "Line": stands them in a row on Hall 3's floor (x -6834 .. -6794, z -28), facing -Z, for close-ups.
	MODE = "Squat" / "Bench" / "Deadlift": puts each at its own Hall 3 rack (Gear_1 .. Gear_6) and runs the meet lift
	(MeetLiftAnimation, as LocalMeetService does) to HOLD_PHASE at HOLD_FRACTION, then holds still for pictures.

	Prints each lifter's gear, piece count and how far the furthest piece sits from its body part. Run again to replace
	the test lifters (the old ones are removed first: only the six this tool made, kept in _G.GearTestBodies).
]]

local MODE = "Line" -- "Line", "Squat", "Bench" or "Deadlift"
local HOLD_PHASE = 1 -- the lift phase to hold (1 = down / off the floor, 2 = up / lockout)
local HOLD_FRACTION = 1.0 -- how far through that phase (1 = its end: the squat's bottom, the bench's chest)

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local hall = workspace:FindFirstChild("LocalMeetVenue") and workspace.LocalMeetVenue:FindFirstChild("Hall_3")
if hall == nil or not game:GetService("RunService"):IsServer() or not game:GetService("RunService"):IsRunning() then
	warn("[CPUGearTest] FAILED: run this on the SERVER during a play test (Hall_3 not found or not running).")
	return
end

local ComputerLifters = require(ServerScriptService.Server.Meet.ComputerLifters)
local MeetLiftAnimation = require(ServerScriptService.Server.Meet.MeetLiftAnimation)
local LifterBuild = require(ReplicatedStorage.Shared.Economy.LifterBuild)

local BUILDS = { "Skinny", "SkinnyFat", "Fit", "Fat", "Muscular", "BigBuff" }

-- Remove this tool's earlier lifters (and their lift handles) only.
local old = _G.GearTestBodies
if type(old) == "table" then
	for _, entry in pairs(old) do
		if typeof(entry) == "Instance" then
			entry:Destroy()
		end
	end
end
if type(_G.GearTestHandles) == "table" then
	for _, handle in pairs(_G.GearTestHandles) do
		pcall(MeetLiftAnimation.stop, handle)
	end
end
_G.GearTestBodies, _G.GearTestHandles = {}, {}

local original = LifterBuild.forNumbers
for index, build in ipairs(BUILDS) do
	local rack = hall:FindFirstChild("Gear_" .. index) and hall["Gear_" .. index]:FindFirstChild("CompetitionRack")
	local lift = if MODE == "Line" then "Squat" else MODE
	local spot = if MODE == "Line" then CFrame.new(-6834 + 8 * (index - 1), 1000, -28)
		else rack and MeetLiftAnimation.approachFor(rack, lift)
	if spot == nil then
		warn("[CPUGearTest] FAILED: no rack Gear_" .. index)
		continue
	end
	LifterBuild.forNumbers = function()
		return build
	end
	local ok, body = pcall(ComputerLifters.spawnBody, {
		name = "Test " .. build .. " (CPU)",
		classLabel = "83 kg",
		bodyweightKg = 80,
		competitionNumber = { Squat = 150, Bench = 100, Deadlift = 180 },
	}, spot, Random.new(index * 31))
	LifterBuild.forNumbers = original
	if not ok or body == nil then
		warn("[CPUGearTest] FAILED for " .. build .. ": " .. tostring(body))
		continue
	end
	_G.GearTestBodies[build] = body
	local worn, pieces, furthest = {}, 0, 0
	local folder = body:FindFirstChild("WornGear")
	for _, piece in ipairs(folder and folder:GetChildren() or {}) do
		if piece:IsA("BasePart") then
			pieces += 1
			worn[string.match(piece.Name, "^(.-)_%a+__") or piece.Name] = true
			local part = body:FindFirstChild(string.match(piece.Name, "__(.+)$") or "")
			if part and part:IsA("BasePart") then
				furthest = math.max(furthest, (piece.Position - part.Position).Magnitude)
			end
		end
	end
	local list = {}
	for id in pairs(worn) do
		table.insert(list, id)
	end
	table.sort(list)
	print(string.format("[CPUGearTest] %s (%s): %d pieces, furthest %.2f studs: %s", build,
		tostring(body:GetAttribute("LifterBodyBuild")), pieces, furthest, table.concat(list, ", ")))
	if MODE ~= "Line" and rack then
		task.spawn(function()
			local handle = MeetLiftAnimation.begin(body, rack, lift)
			_G.GearTestHandles[build] = handle
			task.wait(0.3)
			task.wait(MeetLiftAnimation.unrack(handle) + 0.5)
			for phase = 1, HOLD_PHASE do
				MeetLiftAnimation.phase(handle, phase, nil, true)
				MeetLiftAnimation.progress(handle, phase, if phase == HOLD_PHASE then HOLD_FRACTION else 1)
				task.wait(0.6)
			end
			print("[CPUGearTest] " .. build .. " holding " .. lift .. " phase " .. HOLD_PHASE)
		end)
	end
end
print("[CPUGearTest] done: " .. MODE)
