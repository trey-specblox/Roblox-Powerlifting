--[[
	MeetLift_BodyTest (TEMPORARY TEST TOOL, run on the SERVER during a Studio play test)

	Plays one good meet lift on the first player's character at an empty meet platform, through the meet's own
	MeetLiftAnimation (the same calls LocalMeetService makes, minus the minigame input): walk to the bar, setup,
	unrack, the two lift stages, finish, rerack. Each client's StationPoseAnimator moves the bar with the hands,
	exactly as in a real meet. Used to check the cartoon bodies (GAME_DESIGN §38.7) on a platform.

	Sets workspace attribute BodyTestStage ("Setup", "Unrack", "Phase1", "Phase2", "Finish", "Rerack", "Done") so a
	client script can sample at the right moments. Touches only the first player's character and the named rack;
	the platform must not be running a meet. Change LIFT / HALL below.
]]

local LIFT = "Squat" -- "Squat", "Bench" or "Deadlift"
local HALL = "Hall_3"

local MeetLiftAnimation = require(game:GetService("ServerScriptService").Server.Meet.MeetLiftAnimation)

local player = game:GetService("Players"):GetPlayers()[1]
local character = player and player.Character
local venue = workspace:FindFirstChild("LocalMeetVenue")
local hall = venue and venue:FindFirstChild(HALL)
local gear = hall and hall:FindFirstChild("Gear_1")
local rack = gear and gear:FindFirstChild("CompetitionRack")
if character == nil or rack == nil or not rack:IsA("Model") then
	warn("[MeetLift_BodyTest] FAILED: no player character or no " .. HALL .. ".Gear_1.CompetitionRack")
	return
end

local function stage(name: string)
	workspace:SetAttribute("BodyTestStage", name)
end

local approach = MeetLiftAnimation.approachFor(rack, LIFT)
local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
root.Anchored = true
character:PivotTo((approach :: CFrame) * CFrame.new(0, 3, 0))
task.wait(1)

stage("Setup")
local handle = MeetLiftAnimation.begin(character, rack, LIFT)
task.wait(0.2)
stage("Unrack")
task.wait(MeetLiftAnimation.unrack(handle) + 0.6)
stage("Phase1")
MeetLiftAnimation.phase(handle, 1, 2.2, false)
task.wait(2.2)
stage("Phase2")
MeetLiftAnimation.phase(handle, 2, 0.8, false)
task.wait(0.8)
stage("Finish")
task.wait(MeetLiftAnimation.finish(handle, true, nil))
stage("Rerack")
local racked, clear = MeetLiftAnimation.rerack(handle)
task.wait(math.max(racked, clear) + 0.3)
MeetLiftAnimation.stop(handle)
stage("Done")
print("[MeetLift_BodyTest] " .. LIFT .. " done on " .. tostring(character:GetAttribute("LifterBodyBuild")))
