--[[
	ComboRack01_VerifyRacks  (TEMPORARY Command Bar script, 2026-10-18)

	READ-ONLY. Changes nothing. Replaces Step6D2a_VerifyRacks now that the gym
	racks use the ComboRack_01 template (that script expects PowerRack_01's 21
	parts and will report failures).

	Run while PLAYING, from the SERVER view (Test tab -> "Current: Client"
	button switches it to "Current: Server"), after the game has started.

	Checks, for every entry in TrainingStationConfig.GymRacks:
	  - Workspace.GymRacks holds exactly one rack of that name;
	  - it is tagged, its StationId and RackTemplate match, PrimaryPart is StandPoint;
	  - it has the template's 26 MeshParts, all anchored, and only the 4 posts
	    (Upright_*, SpotterPost_*) are solid;
	  - its floor centre and facing match the config;
	  - every part sits where the template puts it, relative to the floor
	    centre (so nothing is shifted, rotated or mirrored), except the J-cups,
	    which may be raised by exactly the squat amount (0.70);
	  - the J-cups are on the rack's front (-Z at facing 0);
	  - it has exactly one prompt and one sign.
	And overall: the four racks are the only tagged racks, and the template in
	ServerStorage is untouched (26 MeshParts, no tag, StationId or RackTemplate).

	It also prints each rack's current LOOK (bench shown/hidden, J-cups at bench
	or squat height). Run it again while a player trains Squat, Bench or
	Deadlift to confirm the look follows the lift:
	  free or Bench -> bench shown, J-cups at bench height
	  Squat         -> bench hidden, J-cups at squat height
	  Deadlift      -> bench hidden, J-cups at bench height
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local TEMPLATE_NAME = "ComboRack_01"
local EXPECTED_PARTS = 26
local SOLID = { Upright_Left = true, Upright_Right = true, SpotterPost_Left = true, SpotterPost_Right = true }
local JCUP_PARTS = {
	JCup_Left = true, JCup_Right = true, JCupLiner_Left = true, JCupLiner_Right = true,
	JCupPin_Left = true, JCupPin_Right = true,
}
local SQUAT_RAISE = 0.70
local POSITION_TOLERANCE = 0.01
local STAND_HALF_HEIGHT = 0.1

local lines = {}
local failures = 0

local function check(passed: boolean, label: string)
	if not passed then
		failures += 1
	end
	table.insert(lines, (if passed then "  PASS  " else "  FAIL  ") .. label)
end

local function fmtV(v: Vector3): string
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end

-- Name -> offset of each template part from the template's floor centre
-- (between the two tall posts, at the lowest point of the rack).
local function templateOffsets(template: Instance): { [string]: Vector3 }
	local parts: { [string]: BasePart } = {}
	local lowest = math.huge
	for _, d in ipairs(template:GetDescendants()) do
		if d:IsA("BasePart") then
			parts[d.Name] = d
			lowest = math.min(lowest, d.Position.Y - d.Size.Y / 2)
		end
	end
	local centre = (parts.Upright_Left.Position + parts.Upright_Right.Position) / 2
	local floor = Vector3.new(centre.X, lowest, centre.Z)
	local offsets = {}
	for name, part in pairs(parts) do
		offsets[name] = part.Position - floor
	end
	return offsets
end

local function run()
	if not (RunService:IsRunning() and RunService:IsServer()) then
		warn("[ComboRack_01 verify] Not run: press Play, then switch the Command Bar to the SERVER view (Test tab).")
		return
	end

	local config = require(ReplicatedStorage.Shared.Config.TrainingStationConfig)
	local tag = config.StationTag
	local gymRacks = config.GymRacks

	local templateFolder = ServerStorage:FindFirstChild("RackTemplates")
	local template = templateFolder and templateFolder:FindFirstChild(TEMPLATE_NAME)
	check(template ~= nil, "template ServerStorage.RackTemplates." .. TEMPLATE_NAME .. " exists")
	if template == nil then
		return
	end
	check(#template:GetDescendants() == EXPECTED_PARTS
		and not CollectionService:HasTag(template, tag)
		and template:GetAttribute("StationId") == nil
		and template:GetAttribute("RackTemplate") == nil,
		string.format("template untouched: %d parts, no tag, StationId or RackTemplate", #template:GetDescendants()))
	local expectedOffsets = templateOffsets(template)

	local folder = workspace:FindFirstChild("GymRacks")
	check(folder ~= nil and folder:IsA("Folder"), "Workspace.GymRacks folder exists")
	if folder == nil then
		return
	end

	for _, entry in ipairs(gymRacks) do
		local id = entry.stationId
		check(entry.template == TEMPLATE_NAME, string.format("%s: config template is %s", id, tostring(entry.template)))
		local matches = {}
		for _, child in ipairs(folder:GetChildren()) do
			if child.Name == id then
				table.insert(matches, child)
			end
		end
		check(#matches == 1, string.format("%s: exactly 1 rack (found %d)", id, #matches))
		local rack = matches[1]
		if rack == nil or not rack:IsA("Model") then
			continue
		end

		check(CollectionService:HasTag(rack, tag), id .. ": has the " .. tag .. " tag")
		check(rack:GetAttribute("StationId") == id, id .. ": StationId matches")
		check(rack:GetAttribute("RackTemplate") == TEMPLATE_NAME,
			string.format("%s: RackTemplate = %s", id, tostring(rack:GetAttribute("RackTemplate"))))
		check(rack.PrimaryPart ~= nil and rack.PrimaryPart.Name == "StandPoint", id .. ": PrimaryPart is StandPoint")

		local pivot = rack:GetPivot()
		local floorCF = pivot * CFrame.new(0, -STAND_HALF_HEIGHT, 0)
		check((floorCF.Position - entry.position).Magnitude <= POSITION_TOLERANCE,
			string.format("%s: floor centre %s (config %s)", id, fmtV(floorCF.Position), fmtV(entry.position)))
		local expectedLook = CFrame.Angles(0, math.rad(entry.facingDegrees), 0).LookVector
		check(pivot.LookVector:Dot(expectedLook) > 0.999 and pivot.UpVector.Y > 0.999,
			string.format("%s: upright and facing %g degrees", id, entry.facingDegrees))

		local meshParts, unanchored, wrongCollision, misplaced = 0, 0, {}, {}
		local jCupRaise: number? = nil
		local jCupsConsistent = true
		for _, d in ipairs(rack:GetDescendants()) do
			if d:IsA("BasePart") and not d.Anchored then
				unanchored += 1
			end
			if d:IsA("MeshPart") then
				meshParts += 1
				if d.CanCollide ~= (SOLID[d.Name] == true) then
					table.insert(wrongCollision, d.Name)
				end
				local expected = expectedOffsets[d.Name]
				local offset = floorCF:PointToObjectSpace(d.Position)
				if expected == nil then
					table.insert(misplaced, d.Name .. " (not in template)")
				elseif JCUP_PARTS[d.Name] then
					local rise = offset.Y - expected.Y
					local flat = Vector3.new(offset.X - expected.X, 0, offset.Z - expected.Z).Magnitude
					if flat > POSITION_TOLERANCE then
						table.insert(misplaced, d.Name)
					end
					if jCupRaise == nil then
						jCupRaise = rise
					elseif math.abs(rise - jCupRaise) > POSITION_TOLERANCE then
						jCupsConsistent = false
					end
				elseif (offset - expected).Magnitude > POSITION_TOLERANCE then
					table.insert(misplaced, string.format("%s off by %.3f", d.Name, (offset - expected).Magnitude))
				end
			end
		end

		-- The bench is shown or hidden as a whole.
		local pad = rack:FindFirstChild("Bench_Pad", true) :: BasePart?
		local frame = rack:FindFirstChild("Bench_Frame", true) :: BasePart?
		local benchHidden = pad ~= nil and pad.Transparency >= 1
		local benchConsistent = pad ~= nil and frame ~= nil and (pad.Transparency >= 1) == (frame.Transparency >= 1)

		check(meshParts == EXPECTED_PARTS, string.format("%s: %d MeshParts (found %d)", id, EXPECTED_PARTS, meshParts))
		check(unanchored == 0, string.format("%s: every part anchored (%d unanchored)", id, unanchored))
		check(#wrongCollision == 0, string.format("%s: only the 4 posts are solid%s", id,
			if #wrongCollision > 0 then " (wrong: " .. table.concat(wrongCollision, ", ") .. ")" else ""))
		check(#misplaced == 0, string.format("%s: every part where the template puts it%s", id,
			if #misplaced > 0 then " (" .. table.concat(misplaced, ", ") .. ")" else ""))

		local raise = jCupRaise or -1
		local atBench = math.abs(raise) <= POSITION_TOLERANCE
		local atSquat = math.abs(raise - SQUAT_RAISE) <= POSITION_TOLERANCE
		check(jCupsConsistent and (atBench or atSquat),
			string.format("%s: J-cups together at bench or squat height (raise %.3f)", id, raise))
		check(benchConsistent, id .. ": Bench_Pad and Bench_Frame are both shown or both hidden")

		local jcup = rack:FindFirstChild("JCup_Left", true) :: BasePart?
		local post = rack:FindFirstChild("Upright_Left", true) :: BasePart?
		if jcup and post then
			check(floorCF:PointToObjectSpace(jcup.Position).Z < floorCF:PointToObjectSpace(post.Position).Z,
				id .. ": J-cups on the rack's front (-Z at facing 0)")
		end

		local prompts, signs, signText = 0, 0, ""
		for _, d in ipairs(rack:GetDescendants()) do
			if d:IsA("ProximityPrompt") then
				prompts += 1
			elseif d:IsA("BillboardGui") and d.Name == "TrainingStatus" then
				signs += 1
				local label = d:FindFirstChildWhichIsA("TextLabel")
				signText = if label then label.Text else ""
			end
		end
		check(prompts == 1, string.format("%s: exactly 1 prompt (found %d)", id, prompts))
		check(signs == 1, string.format("%s: exactly 1 sign (found %d)", id, signs))

		table.insert(lines, string.format("  LOOK  %s: bench %s, J-cups at %s height | sign: %s", id,
			if benchHidden then "HIDDEN" else "shown",
			if atSquat then "SQUAT" elseif atBench then "bench" else "UNKNOWN",
			(string.gsub(signText, "\n", " | "))))
	end

	local tagged = CollectionService:GetTagged(tag)
	check(#tagged == #gymRacks, string.format("%d tagged racks in total (expected %d)", #tagged, #gymRacks))
end

local ok, err = pcall(run)
if not ok then
	warn("[ComboRack_01 verify] SCRIPT ERROR: " .. tostring(err))
elseif #lines > 0 then
	local header = if failures == 0
		then "[ComboRack_01 verify] ALL CHECKS PASSED"
		else string.format("[ComboRack_01 verify] %d CHECK(S) FAILED", failures)
	local report = header .. "\n" .. table.concat(lines, "\n")
	if failures == 0 then
		print(report)
	else
		warn(report)
	end
end
