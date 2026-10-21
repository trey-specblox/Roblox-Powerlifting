--[[
	StarterGym_MoveSpawnToLobby  (TEMPORARY Command Bar script, 2026-10-21)

	ONE-TIME SETUP, Starter Gym steps 3-4. Moves the place's spawn pad,
	Workspace.SpawnLocation, into the middle of the Starter Gym lobby. The
	StarterGym_VerifyShell check found it at (1.0, 0.5, 2.0), sticking out of
	the first shell's lobby. Updated 2026-10-21 for the "version 2" building:
	the lobby is now further forward, so the target moved; a pad already moved
	by the first version of this script, to (0, 0.5, -5), is accepted too.

	Run in EDIT mode (not while playing), in the cloud place 96814269062063.

	What it changes: ONLY Workspace.SpawnLocation's position (X and Z; its
	height, size, rotation and every other property stay as they are). It
	deletes nothing and creates nothing. It is one Undo step (Ctrl+Z).

	It changes NOTHING unless every check passes:
	  - Edit mode, and the place is 96814269062063;
	  - exactly one SpawnLocation in Workspace, named SpawnLocation, directly
	    under Workspace, not inside a model;
	  - it is at one of the two known spots, (1.0, 0.5, 2.0) or (0.0, 0.5, -5.0),
	    within 0.1 stud, OR already at the target (then it reports that and
	    changes nothing);
	  - at the target, the whole pad fits inside the lobby.

	Afterwards: File -> Save to Roblox, so the place keeps the new spot.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local PLACE_ID = 96814269062063
-- Where the pad may be now: where the check found it, or where the first version of this script put it.
local KNOWN_SPOTS = { Vector3.new(1.0, 0.5, 2.0), Vector3.new(0.0, 0.5, -5.0) }
local TOLERANCE = 0.1
local TAG = "[Move spawn]"

local function run()
	if RunService:IsRunning() then
		warn(TAG .. " NOT changed: stop the game first, this runs in Edit mode.")
		return
	end
	if game.PlaceId ~= PLACE_ID then
		warn(string.format("%s NOT changed: this is place %d, not the game's cloud place %d.", TAG, game.PlaceId, PLACE_ID))
		return
	end

	local spawns = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SpawnLocation") then
			table.insert(spawns, d)
		end
	end
	if #spawns ~= 1 then
		warn(string.format("%s NOT changed: expected exactly 1 SpawnLocation in Workspace, found %d.", TAG, #spawns))
		return
	end
	local spawn = spawns[1]
	if spawn.Name ~= "SpawnLocation" or spawn.Parent ~= workspace then
		warn(string.format("%s NOT changed: the spawn is %s, expected Workspace.SpawnLocation.", TAG, spawn:GetFullName()))
		return
	end

	--[[
		The Command Bar keeps the FIRST copy of every module it required for the
		whole Studio session, so after Rojo syncs a newer version it would still
		get the old one (that broke this script on 2026-10-21). Require fresh
		copies from an unparented clone of the Config folder instead: the clone
		never enters the place, so nothing in the place changes.
	]]
	local configCopy = ReplicatedStorage.Shared.Config:Clone()
	local layout = require(configCopy.TrainingStationConfig).GymLayout
	local gymConfig = require(configCopy.StarterGymConfig)
	local plan = gymConfig.footprint(layout)
	if plan.hallFrontZ == nil or plan.centreX == nil then
		warn(TAG .. " NOT changed: Studio has an old StarterGymConfig. Is Rojo connected and synced? Tell Claude.")
		return
	end
	-- The lobby: the middle of the front block (its back face is one wall in front of the hall).
	local lobbyBackZ = plan.hallFrontZ - gymConfig.WallThicknessStuds
	local target = Vector3.new(plan.centreX, spawn.Position.Y, (plan.frontZ + lobbyBackZ) / 2)

	if (spawn.Position - target).Magnitude <= TOLERANCE then
		print(string.format("%s Already in the lobby at (%.1f, %.1f, %.1f). Nothing changed.", TAG,
			spawn.Position.X, spawn.Position.Y, spawn.Position.Z))
		return
	end
	local known = false
	for _, spot in ipairs(KNOWN_SPOTS) do
		if (spawn.Position - spot).Magnitude <= TOLERANCE then
			known = true
		end
	end
	if not known then
		warn(string.format("%s NOT changed: the spawn is at (%.2f, %.2f, %.2f), not at a known spot. Tell Claude.",
			TAG, spawn.Position.X, spawn.Position.Y, spawn.Position.Z))
		return
	end

	-- The pad's footprint at the target must fit inside the lobby (the size is measured, not assumed).
	local half = spawn.CFrame.Rotation:VectorToWorldSpace(spawn.Size / 2)
	local halfX, halfZ = math.abs(half.X), math.abs(half.Z)
	local fits = math.abs(target.X - plan.centreX) + halfX <= plan.lobbyHalfWidth
		and target.Z - halfZ >= plan.frontZ and target.Z + halfZ <= lobbyBackZ
	if not fits then
		warn(string.format("%s NOT changed: the pad (%.1f x %.1f) would not fit in the lobby (Z %.1f..%.1f). Tell Claude.",
			TAG, spawn.Size.X, spawn.Size.Z, plan.frontZ, lobbyBackZ))
		return
	end

	local recording = ChangeHistoryService:TryBeginRecording("Move spawn to the Starter Gym lobby")
	local from = spawn.Position
	spawn.CFrame = CFrame.new(target) * spawn.CFrame.Rotation
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	print(string.format("%s SUCCESS: moved Workspace.SpawnLocation (%.1f x %.1f) from (%.1f, %.1f, %.1f) to (%.1f, %.1f, %.1f), the middle of the lobby.",
		TAG, spawn.Size.X, spawn.Size.Z, from.X, from.Y, from.Z, target.X, target.Y, target.Z))
	print(TAG .. " Now save the place: File -> Save to Roblox. (Ctrl+Z undoes the move before you save.)")
end

local ok, err = pcall(run)
if not ok then
	warn(TAG .. " SCRIPT ERROR (nothing was changed unless SUCCESS was printed): " .. tostring(err))
end
