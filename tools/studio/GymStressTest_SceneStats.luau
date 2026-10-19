--[[
	GymStressTest_SceneStats  (TEMPORARY Command Bar script, 2026-10-19)

	READ-ONLY. Changes nothing. Starter Gym step 2: the 30-rack stress test.

	Run while PLAYING, from the CLIENT view (the Command Bar's default while
	you play; the Test tab button says "Current: Client"), standing where you
	want to measure, for example at the spawn looking at all the racks.

	It prints:
	  - how many racks, MeshParts, parts, signs, prompts and lights exist;
	  - the gym's triangles at full detail, added up from the measured Blender
	    meshes (ComboRack_01 and Barbell_01, measured 2026-10-19), counting only
	    visible parts. Roblox draws far-away meshes with fewer triangles, so the
	    real number on screen is lower;
	  - your frame rate over 5 seconds: average, and the slowest frame.
	Run it two or three times (standing still, then walking along the rows).
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local SAMPLE_SECONDS = 5

-- Triangles per mesh, measured in Blender (art/blender/*.blend), 2026-10-19.
local TRIANGLES: { [string]: number } = {
	-- ComboRack_01 (7,176 in total)
	BaseFoot_Left = 108, BaseFoot_Right = 108, BaseRail_Back = 108, BaseRail_Left = 108,
	BaseRail_Right = 108, Bench_Frame = 540, Bench_Pad = 188, FootCaps = 264, FrameBolts = 200,
	InsertLockPins = 128, JCupLiner_Left = 24, JCupLiner_Right = 24, JCupPin_Left = 36,
	JCupPin_Right = 36, JCup_Left = 76, JCup_Right = 76, SafetyArm_Left = 216, SafetyArm_Right = 216,
	SafetyPins = 256, SpotterDeck = 108, SpotterPost_Left = 532, SpotterPost_Right = 532,
	UprightInsert_Left = 1036, UprightInsert_Right = 1036, Upright_Left = 556, Upright_Right = 556,
	-- Barbell_01
	Bar_Shaft = 60, Bar_Sleeves = 768, Collar_Lock = 300, Plate_25 = 896, Plate_20 = 896,
	Plate_15 = 896, Plate_10 = 896, Plate_5 = 384, Plate_2_5 = 384, Plate_1_25 = 384,
}

local function run()
	if not (RunService:IsRunning() and RunService:IsClient()) then
		warn("[Gym stress test] Not run: press Play and use the Command Bar in the CLIENT view.")
		return
	end

	local racksFolder = workspace:FindFirstChild("GymRacks")
	local rackCount = if racksFolder then #racksFolder:GetChildren() else 0

	local meshParts, parts, lights, signs, prompts = 0, 0, 0, 0, 0
	local gymTriangles, unknownMeshes = 0, {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
			if d:IsA("MeshPart") then
				meshParts += 1
				if racksFolder and d:IsDescendantOf(racksFolder) and d.Transparency < 1 then
					local triangles = TRIANGLES[d.Name]
					if triangles then
						gymTriangles += triangles
					else
						unknownMeshes[d.Name] = true
					end
				end
			end
		elseif d:IsA("Light") then
			lights += 1
		elseif d:IsA("BillboardGui") then
			signs += 1
		elseif d:IsA("ProximityPrompt") then
			prompts += 1
		end
	end

	local unknownNames = {}
	for name in pairs(unknownMeshes) do
		table.insert(unknownNames, name)
	end

	print(string.format(
		"[Gym stress test] %d racks | %d players | Workspace: %d parts (%d MeshParts), %d lights, %d signs, %d prompts",
		rackCount, #Players:GetPlayers(), parts, meshParts, lights, signs, prompts))
	print(string.format("[Gym stress test] gym racks + barbells at full detail: about %d triangles%s",
		gymTriangles,
		if #unknownNames > 0 then " (not counted, unknown meshes: " .. table.concat(unknownNames, ", ") .. ")" else ""))

	print(string.format("[Gym stress test] measuring frame rate for %d seconds, keep the game window in focus...",
		SAMPLE_SECONDS))
	-- Skip the first frame: it includes this script's own scan of the Workspace
	-- (both 2026-10-19 runs showed exactly one ~67 ms frame).
	RunService.RenderStepped:Wait()
	local frames, slowest, elapsed = 0, 0, 0
	while elapsed < SAMPLE_SECONDS do
		local dt = RunService.RenderStepped:Wait()
		frames += 1
		elapsed += dt
		slowest = math.max(slowest, dt)
	end
	print(string.format("[Gym stress test] average %.0f FPS over %d frames, slowest frame %.1f ms (%.0f FPS)",
		frames / elapsed, frames, slowest * 1000, 1 / slowest))
end

local ok, err = pcall(run)
if not ok then
	warn("[Gym stress test] SCRIPT ERROR: " .. tostring(err))
end
