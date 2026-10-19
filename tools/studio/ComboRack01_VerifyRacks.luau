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
	    which sit either as modelled (squat hole) or exactly 0.35 lower (bench hole);
	  - the J-cups are on the rack's front (-Z at facing 0);
	  - it has exactly one prompt and one sign.
	And overall: the configured racks are the only tagged racks, and the template
	in ServerStorage is untouched (26 MeshParts, no tag, StationId or RackTemplate).

	2026-10-19 (Starter Gym Option B, 30 racks): also checks that the config
	holds GymLayout.rows x racksPerRow racks and that no two racks stand closer
	than GymLayout.rackSpacingStuds. With 30 racks the full list is long, so
	PASS lines are only counted (set SHOW_PASSES = true to print them); FAIL,
	LOOK and INFO lines are always printed.

	Each rack's "Barbell" Model (2026-10-19) is left out of the part checks and
	checked on its own: bar + display load + collars, anchored, not solid or
	queryable, plates outside the J-cups, and the bar where the look puts it.

	It also prints each rack's current LOOK (bench, J-cups, bar). Run it again
	while a player trains Squat, Bench or Deadlift to confirm it follows the lift:
	  free or Bench -> bench shown, J-cups at bench height, bar in the J-cups
	  Squat         -> bench hidden, J-cups and bar at squat height
	  Deadlift      -> bench hidden, J-cups at bench height, bar on the floor
	And for every player in a station pose (StationPose attribute): their root
	is anchored, and they lie face up on the bench (Bench), or stand facing the
	rack at the squat spot (Squat) or behind the floor bar (Deadlift). Players
	not posed must be free.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
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
local BENCH_JCUP_DROP = -0.35   -- StationLayout benchJCupDrop (J-cups are modelled at the squat hole)
local POSITION_TOLERANCE = 0.01
local STAND_HALF_HEIGHT = 0.1

local SHOW_PASSES = false

local lines = {}
local failures = 0
local passes = 0

local function check(passed: boolean, label: string)
	if passed then
		passes += 1
		if not SHOW_PASSES then
			return
		end
	else
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

	-- The floor plan: the expected number of racks, and no two too close together.
	local layout = config.GymLayout
	check(#gymRacks == layout.rows * layout.racksPerRow,
		string.format("config holds %d racks (%d rows x %d)", #gymRacks, layout.rows, layout.racksPerRow))
	local closest, closestPair = math.huge, ""
	for i = 1, #gymRacks do
		for j = i + 1, #gymRacks do
			local distance = (gymRacks[i].position - gymRacks[j].position).Magnitude
			if distance < closest then
				closest, closestPair = distance, gymRacks[i].stationId .. " / " .. gymRacks[j].stationId
			end
		end
	end
	if #gymRacks > 1 then
		check(closest >= layout.rackSpacingStuds - POSITION_TOLERANCE,
			string.format("closest racks %.2f studs apart (%s), minimum %g", closest, closestPair, layout.rackSpacingStuds))
	end

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
		local barbellModel = rack:FindFirstChild("Barbell")
		for _, d in ipairs(rack:GetDescendants()) do
			if barbellModel ~= nil and d:IsDescendantOf(barbellModel) then
				continue -- the station's barbell is checked separately below
			end
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
		local atBench = math.abs(raise - BENCH_JCUP_DROP) <= POSITION_TOLERANCE
		local atSquat = math.abs(raise) <= POSITION_TOLERANCE
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

		-- The station's barbell: where it should be for this look.
		local barWhere = "MISSING"
		local shaft = barbellModel and barbellModel:FindFirstChild("Bar_Shaft") :: BasePart?
		check(barbellModel ~= nil and shaft ~= nil, id .. ": has its Barbell (with Bar_Shaft)")
		if barbellModel and shaft then
			local loadSize = #config.BarbellDisplayLoadPerSide
			local barParts, solidOrQueryable, unanchoredBar, insidePlates = 0, 0, 0, 0
			for _, d in ipairs(barbellModel:GetDescendants()) do
				if d:IsA("BasePart") then
					barParts += 1
					if d.CanCollide or d.CanQuery then
						solidOrQueryable += 1
					end
					if not d.Anchored then
						unanchoredBar += 1
					end
					if string.sub(d.Name, 1, 6) == "Plate_"
						and math.abs(floorCF:PointToObjectSpace(d.Position).X) < 3.31 then
						insidePlates += 1
					end
				end
			end
			check(barParts == 2 + 2 * (loadSize + 1),
				string.format("%s: barbell has bar + %d plates and a collar per side (%d parts)", id, loadSize, barParts))
			check(solidOrQueryable == 0 and unanchoredBar == 0,
				string.format("%s: barbell anchored, not solid, not queryable", id))
			check(insidePlates == 0, string.format("%s: all plates outside the J-cups", id))

			local at = floorCF:PointToObjectSpace(shaft.Position)
			local function near(v: Vector3): boolean
				return (at - v).Magnitude <= POSITION_TOLERANCE
			end
			local expected = if benchHidden and atBench then "floor"
				elseif atSquat then "squat"
				else "bench"
			barWhere = if near(Vector3.new(0, 3.14, -0.28)) then "bench"
				elseif near(Vector3.new(0, 3.49, -0.28)) then "squat"
				elseif math.abs(at.X) <= POSITION_TOLERANCE and math.abs(at.Z + 4.2) <= POSITION_TOLERANCE then "floor"
				else "UNKNOWN " .. fmtV(at)
			check(barWhere == expected, string.format("%s: bar at %s position (expected %s)", id, barWhere, expected))
		end

		table.insert(lines, string.format("  LOOK  %s: bench %s, J-cups at %s height, bar %s | sign: %s", id,
			if benchHidden then "HIDDEN" else "shown",
			if atSquat then "SQUAT" elseif atBench then "bench" else "UNKNOWN",
			barWhere,
			(string.gsub(signText, "\n", " | "))))
	end

	local tagged = CollectionService:GetTagged(tag)
	check(#tagged == #gymRacks, string.format("%d tagged racks in total (expected %d)", #tagged, #gymRacks))

	-- Lifters held in a station pose: anchored, and where their lift puts them on the nearest rack.
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local poseName = character and character:GetAttribute("StationPose")
		if character == nil or root == nil then
			table.insert(lines, "  INFO  " .. player.Name .. ": no character")
			continue
		end
		if poseName == nil then
			check(not root.Anchored, player.Name .. ": not posed and free to move")
			continue
		end
		local nearest, nearestDistance = nil, math.huge
		for _, rack in ipairs(folder:GetChildren()) do
			if rack:IsA("Model") then
				local distance = (rack:GetPivot().Position - root.Position).Magnitude
				if distance < nearestDistance then
					nearest, nearestDistance = rack, distance
				end
			end
		end
		check(root.Anchored, string.format("%s: posed for %s and held (root anchored)", player.Name, tostring(poseName)))
		if nearest then
			local frame = nearest:GetPivot() * CFrame.new(0, -STAND_HALF_HEIGHT, 0)
			local at = frame:PointToObjectSpace(root.Position)
			local faceUp = frame:VectorToObjectSpace(root.CFrame.LookVector).Y > 0.99
			if poseName == "Bench" then
				check(faceUp and at.Z < 0 and at.Z > -3.4, string.format("%s: lying face up on %s's bench at %s",
					player.Name, nearest.Name, fmtV(at)))
			elseif poseName == "Squat" then
				local facingRack = frame:VectorToObjectSpace(root.CFrame.LookVector).Z > 0.99
				check(facingRack and math.abs(at.Z + 1.0) <= 0.05 and math.abs(at.X) <= 0.05,
					string.format("%s: standing for Squat at %s on %s, facing the rack", player.Name,
						fmtV(at), nearest.Name))
			else
				local facingRack = frame:VectorToObjectSpace(root.CFrame.LookVector).Z > 0.99
				check(facingRack and math.abs(at.Z + 4.8) <= 0.05 and math.abs(at.X) <= 0.05,
					string.format("%s: standing for %s behind the bar at %s on %s, facing the rack", player.Name,
						tostring(poseName), fmtV(at), nearest.Name))
			end
		end
	end
end

local ok, err = pcall(run)
if not ok then
	warn("[ComboRack_01 verify] SCRIPT ERROR: " .. tostring(err))
elseif #lines > 0 then
	local header = if failures == 0
		then string.format("[ComboRack_01 verify] ALL %d CHECKS PASSED", passes)
		else string.format("[ComboRack_01 verify] %d CHECK(S) FAILED, %d passed", failures, passes)
	local report = header .. "\n" .. table.concat(lines, "\n")
	if failures == 0 then
		print(report)
	else
		warn(report)
	end
end
