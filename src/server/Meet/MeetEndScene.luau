--!strict
--[[
	MeetEndScene
	Server / Meet

	THE END-OF-MEET COACH SCENE (GAME_DESIGN §40.5 "End-of-meet scene", user 2026-11-25): when a meet ends, before the
	podium, each player's own coach walks up and stands at their right side, pats their upper back twice with an open
	hand (Coach_BackPat, art/scripts/meet_end_animations.py) and, his hand resting on their back, says how it went: the
	CoachVoiceConfig P line for their place, 9/9 or no total (lineKey). On the player's screen the client MeetEndScene
	runs the camera, the subtitle and SKIP (LocalMeetRemotes.SCENE, kinds "MeetEndCoach" / "MeetEndCoachLine" /
	"MeetEndCoachEnd"). SKIP ends their scene; a player off the podium is also let go at once (`onSkipFree`), a podium
	lifter skips only the camera.

	The platform's coach figure is the one moved (LocalMeetVenue.coachFigure); on the lifter's own screen MeetCoachLook
	shows their chosen coach's body copying it. Computer lifters get no scene (they have no coach walking). Kept out of
	LocalMeetService (its main chunk is at Luau's 200-local limit).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local LocalMeetConfig = require(ConfigFolder:WaitForChild("LocalMeetConfig"))
local CoachVoiceConfig = require(ConfigFolder:WaitForChild("CoachVoiceConfig"))
local MeetConfig = require(ConfigFolder:WaitForChild("MeetConfig"))

local ComputerLifters = require(script.Parent:WaitForChild("ComputerLifters"))
local LocalMeetVenue = require(script.Parent:WaitForChild("LocalMeetVenue"))
local MeetFigures = require(script.Parent:WaitForChild("MeetFigures"))
local MeetChalk = require(script.Parent:WaitForChild("MeetChalk"))

local ServerRoot = script.Parent.Parent
local PlayerDataService = require(ServerRoot:WaitForChild("PlayerData"):WaitForChild("PlayerDataService"))
local LifterBodyService = require(ServerRoot:WaitForChild("Economy"):WaitForChild("LifterBodyService"))

local SETTINGS = LocalMeetConfig.MeetEnd
local PODIUM_PLACES = 3
local POLL_SECONDS = 0.1

local MeetEndScene = {}

export type Beat = {
	player: Player,
	platform: LocalMeetVenue.Platform,
	lifterAt: CFrame, -- where the lifter stands (their root), facing the way they face
	line: string,
	podium: boolean, -- in the top 3: SKIP leaves them for the podium
}

-- The players in a scene right now, and whether they pressed SKIP.
local active: { [Player]: { skipped: boolean, onSkipFree: ((Player) -> ())?, podium: boolean } } = {}
local listening = false

--[[
	The P line's key for a lifter's end of the meet (CoachVoiceConfig: P1-P8): `place` nil = no total (bombed out or
	withdrawn); `allNine` = all nine attempts were good lifts.
]]
function MeetEndScene.lineKey(place: number?, allNine: boolean): string
	if place == nil then
		return "P8" -- no total
	end
	if place == 1 then
		return if allNine then "P1" else "P2"
	end
	if place <= PODIUM_PLACES then
		if allNine then
			return "P5"
		end
		return if place == 2 then "P3" else "P4"
	end
	return if allNine then "P7" else "P6"
end

-- The words of a P line (every coach says the same words, so the bubble finds his own take: CoachVoice).
function MeetEndScene.lineText(key: string): string
	local line = CoachVoiceConfig.Lines.Owner[key] or CoachVoiceConfig.Lines.Squat[key]
	return if line then line.text else ""
end

-- True when every attempt of every lift in `histories` (lift -> its attempts with `result`) was a good lift.
function MeetEndScene.allGood(histories: { [string]: { { result: string? } } }): boolean
	local count = 0
	for _, lift in ipairs(MeetConfig.LiftOrder) do
		local history = histories[lift]
		if history == nil then
			return false
		end
		for _, attempt in ipairs(history) do
			if attempt.result ~= "GoodLift" then
				return false
			end
			count += 1
		end
	end
	return count >= #MeetConfig.LiftOrder * MeetConfig.AttemptsPerLift
end

-- The first solid thing from `from` along `along` (bodies, see-through and non-query parts don't count), or nil.
local function blockedAt(from: Vector3, along: Vector3): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _ = 1, 8 do
		params.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(from, along, params)
		if hit == nil then
			return nil
		end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		local body = model and model:FindFirstChildOfClass("Humanoid")
		if body or hit.Instance.Transparency >= 0.95 or not hit.Instance.CanCollide then
			table.insert(ignore, if body then model :: Model else hit.Instance)
		else
			return hit.Distance
		end
	end
	return nil
end

--[[
	WHERE THE SCENE STANDS (Studio 2026-11-25: at a Local meet the waiting spot faces along the warm-up room's back wall
	with the chalk stand in front, so the coach's place at the lifter's right was inside the wall and the bowl blocked
	the camera). From the lifter's floor spot `at`, a spot a short step out, facing a way with room for the coach at
	their right (SceneRightRoom) and for the camera in front (SceneFrontRoom), and nothing in the way of the step.
	Directions tried every 45 degrees, the one with the most room kept; `at` itself if nothing fits.
]]
function MeetEndScene.sceneSpot(at: CFrame): CFrame
	local chest = Vector3.new(0, 3, 0)
	local best, bestScore = at, -math.huge
	for step = 0, 7 do
		local facing = CFrame.Angles(0, math.rad(step * 45), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
		local from = at.Position + chest
		local stepped = from + facing * SETTINGS.SceneStep
		if blockedAt(from, facing * (SETTINGS.SceneStep + 1)) == nil then
			local right = facing:Cross(Vector3.yAxis)
			local rightRoom = blockedAt(stepped, right * 12) or 12
			local frontRoom = blockedAt(stepped, facing * 32) or 32
			local backRoom = blockedAt(stepped, -facing * 4) or 4
			if rightRoom >= SETTINGS.SceneRightRoom and frontRoom >= SETTINGS.SceneFrontRoom and backRoom >= 1.5 then
				-- (the most open way wins: into the warm-up room rather than out through a doorway)
				local score = math.min(rightRoom, 8) + frontRoom * 0.5
				if score > bestScore then
					bestScore = score
					local floor = stepped - chest
					best = CFrame.lookAt(floor, floor + facing)
				end
			end
		end
	end
	return best
end

local function listen(remotes: any)
	if listening then
		return
	end
	listening = true
	remotes.scene.OnServerEvent:Connect(function(player: Player, what: any)
		local state = active[player]
		if what ~= "MeetEndSkip" or state == nil or state.skipped then
			return
		end
		state.skipped = true
		if not state.podium and state.onSkipFree then
			task.spawn(state.onSkipFree, player)
		end
	end)
end

-- The coach's way to `final`: through the platform's doorway when he is on the other side of its wall (as coachWalk).
local function pathTo(platform: LocalMeetVenue.Platform, coach: Model, final: CFrame): { Vector3 }
	local way = (platform :: any).coachWay
	if typeof(way) ~= "table" or #way < 2 then
		return {}
	end
	local wallZ = way[1].Z
	local going = final.Position.Z < wallZ
	if (ComputerLifters.positionOf(coach).Position.Z < wallZ) ~= going then
		return if going then { way[1], way[2] } else { way[2], way[1] }
	end
	return {}
end

local function runBeat(beat: Beat, remotes: any, stillOn: () -> boolean, onDone: () -> ())
	local coach = LocalMeetVenue.coachFigure(beat.platform)
	local state = active[beat.player]
	local function going(): boolean
		return stillOn() and coach ~= nil and coach.Parent ~= nil and beat.player.Parent ~= nil
	end
	if coach == nil or state == nil then
		onDone()
		return
	end
	-- The chosen coach's own version of the pat, and where it has him stand for this lifter's build.
	local coaching = PlayerDataService.getCoaching(beat.player)
	local coachId = if coaching and coaching.active then coaching.active else "Owner"
	local version = SETTINGS.PatVersions[coachId] or SETTINGS.PatVersions.Owner
	local okBuild, build = pcall(LifterBodyService.buildFor, beat.player)
	local spot = version.place[if okBuild then build else ""] or version.place[SETTINGS.PatFallbackBuild]
	local final = beat.lifterAt * CFrame.new(spot.side, 0, spot.back) * CFrame.Angles(0, math.rad(spot.yaw), 0)
	remotes.scene:FireClient(beat.player, { kind = "MeetEndCoach", lifterAt = beat.lifterAt, coachAt = final,
		startedAt = Workspace:GetServerTimeNow(), seconds = SETTINGS.MaxSeconds })
	MeetFigures.showClipboard(coach, false)
	LocalMeetVenue.coachSays(beat.platform, nil)
	-- The walk up, cut short if it takes too long (then he's put beside them).
	local arrived = false
	local walkStarted = os.clock()
	task.spawn(function()
		ComputerLifters.walkBody(coach, pathTo(beat.platform, coach, final), final, function()
			return going() and os.clock() - walkStarted < SETTINGS.MaxWalkSeconds
		end)
		arrived = true
	end)
	while not arrived and going() and os.clock() - walkStarted < SETTINGS.MaxWalkSeconds + 0.5 do
		task.wait(POLL_SECONDS)
	end
	if not going() then
		onDone()
		return
	end
	if (ComputerLifters.positionOf(coach).Position - final.Position).Magnitude > 0.5 then
		ComputerLifters.moveBody(coach, final)
	end
	-- The pat, then his line with the hand resting on their back.
	local track = if version.animationId ~= "" then MeetChalk.play(coach, version.animationId) else nil
	if track then
		track.Looped = false
	end
	task.wait(SETTINGS.LineAt)
	if going() then
		LocalMeetVenue.coachSays(beat.platform, beat.line)
		remotes.scene:FireClient(beat.player, { kind = "MeetEndCoachLine", line = beat.line })
	end
	local talkEnds = os.clock() + math.max(0, SETTINGS.PatSeconds - SETTINGS.LineAt)
	while going() and os.clock() < talkEnds do
		task.wait(POLL_SECONDS)
	end
	if coach.Parent then
		LocalMeetVenue.coachSays(beat.platform, nil)
	end
	MeetChalk.stop(track)
	if beat.player.Parent then
		remotes.scene:FireClient(beat.player, { kind = "MeetEndCoachEnd" })
	end
	onDone()
end

--[[
	Runs every beat at once (each player's own coach at their own platform) and returns when all are over, or after
	MaxSeconds at most. `stillOn` says the meet is still on; `onSkipFree(player)` lets a player off the podium go when
	they press SKIP. Returns the players who skipped.
]]
function MeetEndScene.run(beats: { Beat }, remotes: any, stillOn: () -> boolean, onSkipFree: (Player) -> ()): { [Player]: boolean }
	listen(remotes)
	local left = #beats
	for _, beat in ipairs(beats) do
		active[beat.player] = { skipped = false, onSkipFree = onSkipFree, podium = beat.podium }
	end
	for _, beat in ipairs(beats) do
		task.spawn(runBeat, beat, remotes, stillOn, function()
			left -= 1
		end)
	end
	local started = os.clock()
	while left > 0 and stillOn() and os.clock() - started < SETTINGS.MaxSeconds do
		task.wait(POLL_SECONDS)
	end
	local skipped: { [Player]: boolean } = {}
	for _, beat in ipairs(beats) do
		local state = active[beat.player]
		if state and state.skipped then
			skipped[beat.player] = true
		end
		active[beat.player] = nil
	end
	return skipped
end

return MeetEndScene
