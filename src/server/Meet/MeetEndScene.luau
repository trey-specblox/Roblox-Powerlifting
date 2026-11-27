--!strict
--[[
	MeetEndScene
	Server / Meet

	THE END-OF-MEET COACH SCENE (GAME_DESIGN §40.5 "End-of-meet scene", user 2026-11-25, redone 2026-11-26): when a meet
	ends, before the podium, each player's own coach is already at their right side as the scene opens (user: "The 3rd
	screenshot is where the cutscene should start, waiting for the coach to walk up takes too long"). He pats their
	upper back twice with an open hand and says how it went (the CoachVoiceConfig P line for their place, 9/9 or no
	total: lineKey), talking with his free hand while he does (the TalkPat / WalkTalk clips, art/scripts/
	meet_end_animations.py).
	  Off the podium (or at a State meet) the scene stays where they are, in the warm-up room; once he has said it he
	lets go and walks away.
	  On the podium at a Local meet hall they walk off together while he talks, his arm round their back (user: "the
	coach should be walking with the lifter saying this with his arm patting his back"): a few steps toward their
	platform's front, then a CUT to the floor in front of the platforms walking into their place in the line for the
	podium (MeetCeremony.lineSpots), and there he lets go and walks away (user: "he should just walk away after the
	lifter gets by the podium"). The computer lifters in the top 3 walk into the line at the same moment, so nobody
	ever walks through anybody: the nearer the referee their place, the nearer it they start.
	On the player's screen the client MeetEndScene runs the camera, the subtitle and SKIP (LocalMeetRemotes.SCENE kinds
	"MeetEndCoach" / "MeetEndCoachLine" / "MeetEndWalk" / "MeetEndCut" / "MeetEndCoachEnd"). SKIP ends their camera; a
	player off the podium is also let go at once (`onSkipFree`); a podium lifter's body still walks to the line.

	The platform's coach figure is the one moved (LocalMeetVenue.coachFigure); on the lifter's own screen MeetCoachLook
	shows their chosen coach's body copying it. When every scene is over the coaches are put back behind the warm-up
	wall (out of the ceremony's shot). Kept out of LocalMeetService (its main chunk is at Luau's 200-local limit).
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
	lifterAt: CFrame, -- where the lifter stands (their root's floor point), facing the way they face
	lineKey: string, -- CoachVoiceConfig P key (lineKey)
	podium: boolean, -- in the top 3: SKIP doesn't let them go
	-- (a top-3 lifter at a Local meet hall) the walk into the line for the podium: their place in it (slot: a floor
	-- CFrame facing the referee; slotIndex: 1 = nearest him)
	stage: { slot: CFrame, slotIndex: number }?,
	-- called with where the lifter is put or ends up (the cut, the end of the walk): LocalMeetService keeps them there
	onArrived: ((CFrame) -> ())?,
}

-- A computer lifter in the top 3, walked into its place in the line with the players (no coach, no camera).
export type Walker = { body: Model, slot: CFrame, slotIndex: number }

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

-- How long coach `coachId`'s take of line `key` lasts.
local function lineSeconds(coachId: string, key: string): number
	local lines = (CoachVoiceConfig.Lines :: any)[coachId] or CoachVoiceConfig.Lines.Owner
	local line = lines[key]
	return if line and typeof(line.seconds) == "number" then line.seconds else SETTINGS.LineFallbackSeconds
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

-- The floor's height under `at` (a platform's top where there is one), or `at`'s own.
local function floorAt(at: Vector3): Vector3
	local down = blockedAt(at + Vector3.new(0, 4, 0), Vector3.new(0, -8, 0))
	return if down then Vector3.new(at.X, at.Y + 4 - down, at.Z) else at
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

-- Where a top-3 lifter stands on their platform for the scene (left of its middle: the coach has the platform at his
-- right side; the racks are gone by then, so the walk to its front is clear).
function MeetEndScene.platformSpot(platformTop: CFrame): CFrame
	return platformTop * CFrame.new(-SETTINGS.PlatformLeft, 0, SETTINGS.PlatformBack)
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

-- Where the coach stands off a lifter's floor spot `at` by a placement (side to their right, back behind, yaw turned in).
local function offsetFrom(at: CFrame, spot: { side: number, back: number, yaw: number? }): CFrame
	return at * CFrame.new(spot.side, 0, spot.back) * CFrame.Angles(0, math.rad(spot.yaw or 0), 0)
end

--[[
	His walk away once he's done (user 2026-11-26): from where he stands, the way with the most open floor that isn't
	toward the lifter (to his right, right and back, back, right and front), LeaveStuds at most, for LeaveSeconds.
]]
local function walkAway(coach: Model, lifterAt: CFrame, alive: () -> boolean)
	local from = ComputerLifters.positionOf(coach) * CFrame.new(0, -3, 0)
	local start = Vector3.new(from.Position.X, lifterAt.Position.Y, from.Position.Z)
	local right = lifterAt.RightVector
	local back = -lifterAt.LookVector
	local bestDir, bestRoom = right, -1
	for _, dir in ipairs({ right, (right + back).Unit, back, (right - back).Unit }) do
		local room = blockedAt(start + Vector3.new(0, 3, 0), dir * (SETTINGS.LeaveStuds + 2)) or (SETTINGS.LeaveStuds + 2)
		if room > bestRoom then
			bestRoom, bestDir = room, dir
		end
	end
	local studs = math.clamp(bestRoom - 1.5, 0, SETTINGS.LeaveStuds)
	if studs < 1 then
		return
	end
	local to = floorAt(start + bestDir * studs)
	local began = os.clock()
	ComputerLifters.walkBody(coach, {}, CFrame.lookAt(to, to + bestDir), function()
		return alive() and os.clock() - began < SETTINGS.LeaveSeconds
	end, { animationId = LocalMeetConfig.ComputerLifters.WalkAnimationId, speed = SETTINGS.WalkSpeed,
		styleStuds = math.huge })
end

local function waitUntil(clock: number, alive: () -> boolean)
	while alive() and os.clock() < clock do
		task.wait(POLL_SECONDS)
	end
end

local function runBeat(beat: Beat, remotes: any, stillOn: () -> boolean, began: number, laneStart: CFrame?,
	onDone: (Model?) -> ())
	local coach = LocalMeetVenue.coachFigure(beat.platform)
	local state = active[beat.player]
	local function going(): boolean
		return stillOn() and coach ~= nil and coach.Parent ~= nil and beat.player.Parent ~= nil
	end
	if coach == nil or state == nil then
		onDone(nil)
		return
	end
	-- The chosen coach's own version of the pat, and where it has him stand for this lifter's build.
	local coaching = PlayerDataService.getCoaching(beat.player)
	local coachId = if coaching and coaching.active then coaching.active else "Owner"
	local version = SETTINGS.PatVersions[coachId] or SETTINGS.PatVersions.Owner
	local okBuild, build = pcall(LifterBodyService.buildFor, beat.player)
	local spot = version.place[if okBuild then build else ""] or version.place[SETTINGS.PatFallbackBuild]
	local line = MeetEndScene.lineText(beat.lineKey)
	local seconds = lineSeconds(coachId, beat.lineKey)
	-- Already beside them as the scene opens.
	MeetFigures.showClipboard(coach, false)
	LocalMeetVenue.coachSays(beat.platform, nil)
	local coachAt = offsetFrom(beat.lifterAt, spot)
	ComputerLifters.moveBody(coach, coachAt)
	remotes.scene:FireClient(beat.player, { kind = "MeetEndCoach", lifterAt = beat.lifterAt, coachAt = coachAt,
		startedAt = Workspace:GetServerTimeNow(), seconds = SETTINGS.MaxSeconds })
	-- The two pats, then his line (his free hand talking: the clip).
	local track = if version.animationId ~= "" then MeetChalk.play(coach, version.animationId) else nil
	if track then
		track.Looped = false
	end
	waitUntil(began + SETTINGS.LineAt, going)
	if going() then
		LocalMeetVenue.coachSays(beat.platform, line)
		remotes.scene:FireClient(beat.player, { kind = "MeetEndCoachLine", line = line })
	end
	local stage = beat.stage
	if stage == nil or laneStart == nil then
		-- Off the podium: he says it where they stand, then goes.
		waitUntil(began + SETTINGS.LineAt + math.max(SETTINGS.PatSeconds, seconds + SETTINGS.LineTail), going)
		if going() then
			LocalMeetVenue.coachSays(beat.platform, nil)
			MeetChalk.stop(track)
			track = nil
			walkAway(coach, beat.lifterAt, going)
		end
	elseif going() then
		-- On the podium: off together while he talks, his arm round their back.
		local walkVersion = SETTINGS.WalkPatVersions[coachId] or SETTINGS.WalkPatVersions.Owner
		local walkSpot = walkVersion.place[if okBuild then build else ""] or walkVersion.place[SETTINGS.PatFallbackBuild]
			or { side = spot.side, back = 0 }
		MeetChalk.stop(track)
		track = nil
		local armTrack = if walkVersion.animationId ~= "" then MeetChalk.play(coach, walkVersion.animationId) else nil
		local options = { animationId = LocalMeetConfig.ComputerLifters.WalkAnimationId, speed = SETTINGS.WalkSpeed,
			styleStuds = math.huge }
		-- On the lifter's screen the coach is kept beside them every frame from these (client MeetEndScene).
		coach:SetAttribute("WalkWithUserId", beat.player.UserId)
		coach:SetAttribute("WalkSide", walkSpot.side)
		coach:SetAttribute("WalkBack", walkSpot.back)
		remotes.scene:FireClient(beat.player, { kind = "MeetEndWalk", coach = coach, seconds = SETTINGS.MaxSeconds })
		local character = beat.player.Character
		local function walkPair(lifterTo: CFrame)
			local done = 0
			task.spawn(function()
				if character then
					ComputerLifters.walkBody(character, {}, lifterTo, going, options)
				end
				done += 1
			end)
			task.spawn(function()
				ComputerLifters.walkBody(coach, {}, offsetFrom(lifterTo, walkSpot), going, options)
				done += 1
			end)
			return function(): boolean
				return done >= 2
			end
		end
		-- A few steps toward their platform's front...
		local platformEnd = beat.lifterAt * CFrame.new(0, 0, -SETTINGS.PlatformWalkSeconds * SETTINGS.WalkSpeed)
		walkPair(platformEnd)
		local cutAt = began + SETTINGS.LineAt + SETTINGS.PlatformWalkSeconds
		waitUntil(cutAt, going)
		-- ...CUT to the floor in front of the platforms, walking into their place in the line (all at once: run).
		if going() then
			if beat.onArrived then
				beat.onArrived(laneStart)
			end
			ComputerLifters.moveBody(coach, offsetFrom(laneStart, walkSpot))
			remotes.scene:FireClient(beat.player, { kind = "MeetEndCut" })
			local arrived = walkPair(stage.slot)
			while going() and not arrived() and os.clock() - began < SETTINGS.MaxSeconds do
				task.wait(POLL_SECONDS)
			end
			if beat.onArrived and beat.player.Parent then
				beat.onArrived(stage.slot)
			end
		end
		MeetChalk.stop(armTrack)
		coach:SetAttribute("WalkWithUserId", nil)
		if coach.Parent then
			LocalMeetVenue.coachSays(beat.platform, nil)
			walkAway(coach, stage.slot, going)
		end
	end
	MeetChalk.stop(track)
	if beat.player.Parent then
		remotes.scene:FireClient(beat.player, { kind = "MeetEndCoachEnd" })
	end
	onDone(coach)
end

--[[
	Where each walker into the line starts, after the cut (user 2026-11-26): `seconds` of walking (at least LaneSeconds)
	back along the line from their place, and never closer to the referee than SlotGap behind the walker for the place
	in front, so everyone walks in single file at the same pace and nobody passes anybody.
]]
local function laneStarts(walkers: { { slot: CFrame, slotIndex: number, seconds: number } }): { CFrame }
	local order = {}
	for index in ipairs(walkers) do
		table.insert(order, index)
	end
	table.sort(order, function(a, b)
		return walkers[a].slotIndex < walkers[b].slotIndex
	end)
	local starts: { CFrame } = {}
	local origin = walkers[order[1]] and walkers[order[1]].slot
	local lastBack = -math.huge
	for _, index in ipairs(order) do
		local walker = walkers[index]
		local behind = -walker.slot.LookVector -- (the slot faces the referee: the line runs back from him)
		local at = if origin then (walker.slot.Position - origin.Position):Dot(behind) else 0
		local back = math.max(at + math.max(SETTINGS.LaneSeconds, walker.seconds) * SETTINGS.WalkSpeed,
			lastBack + LocalMeetConfig.MeetEnd.Line.SlotGap)
		lastBack = back
		local start = walker.slot.Position + behind * (back - at)
		starts[index] = CFrame.lookAt(start, start + walker.slot.LookVector)
	end
	return starts
end

--[[
	Runs every beat at once (each player's own coach at their own platform), walks `walkers` (the computer lifters in
	the top 3) into the line with them, and returns when all are over, or after MaxSeconds at most, with the coaches
	put back behind the warm-up wall. `stillOn` says the meet is still on; `onSkipFree(player)` lets a player off the
	podium go when they press SKIP. Returns the players who skipped.
]]
function MeetEndScene.run(beats: { Beat }, remotes: any, stillOn: () -> boolean, onSkipFree: (Player) -> (),
	walkers: { Walker }?): { [Player]: boolean }
	listen(remotes)
	local began = os.clock()
	local left = #beats
	for _, beat in ipairs(beats) do
		active[beat.player] = { skipped = false, onSkipFree = onSkipFree, podium = beat.podium }
	end
	-- Everyone walking into the line, and where each starts after the cut.
	local lane: { { slot: CFrame, slotIndex: number, seconds: number } } = {}
	local laneOf: { [any]: number } = {}
	for _, beat in ipairs(beats) do
		local stage = beat.stage
		if stage then
			local coaching = PlayerDataService.getCoaching(beat.player)
			local coachId = if coaching and coaching.active then coaching.active else "Owner"
			-- (he finishes talking on the way: what's left of his line after the steps on the platform)
			local talk = lineSeconds(coachId, beat.lineKey) + SETTINGS.LineTail - SETTINGS.PlatformWalkSeconds
			table.insert(lane, { slot = stage.slot, slotIndex = stage.slotIndex, seconds = talk })
			laneOf[beat] = #lane
		end
	end
	for _, walker in ipairs(walkers or {}) do
		table.insert(lane, { slot = walker.slot, slotIndex = walker.slotIndex, seconds = SETTINGS.LaneSeconds })
		laneOf[walker] = #lane
	end
	local starts = if #lane > 0 then laneStarts(lane) else {}
	local coaches: { [Model]: LocalMeetVenue.Platform } = {}
	for _, beat in ipairs(beats) do
		local index = laneOf[beat]
		task.spawn(runBeat, beat, remotes, stillOn, began, if index then starts[index] else nil, function(coach: Model?)
			if coach then
				coaches[coach] = beat.platform
			end
			left -= 1
		end)
	end
	-- The computer lifters set off at the cut, with the players.
	for _, walker in ipairs(walkers or {}) do
		local start = starts[laneOf[walker]]
		task.spawn(function()
			while stillOn() and os.clock() < began + SETTINGS.LineAt + SETTINGS.PlatformWalkSeconds do
				task.wait(POLL_SECONDS)
			end
			if stillOn() and walker.body.Parent and start then
				ComputerLifters.moveBody(walker.body, start)
				ComputerLifters.walkBody(walker.body, {}, walker.slot, stillOn, {
					animationId = LocalMeetConfig.ComputerLifters.WalkAnimationId, speed = SETTINGS.WalkSpeed,
					styleStuds = math.huge })
			end
		end)
	end
	while left > 0 and stillOn() and os.clock() - began < SETTINGS.MaxSeconds do
		task.wait(POLL_SECONDS)
	end
	for coach in pairs(coaches) do
		if coach.Parent then
			MeetFigures.showClipboard(coach, true)
		end
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

--[[
	Out of the ceremony's shot (user 2026-11-26: "if you look at the background you can still see the coach"; Studio:
	the coaches waiting behind the warm-up wall show through the doorways): every platform's coach is stood out of
	sight under the floor until the platforms are staffed again (LocalMeetVenue.staffPlatform builds new ones).
]]
function MeetEndScene.hideCoaches(platforms: { LocalMeetVenue.Platform })
	for _, platform in ipairs(platforms) do
		local coach = LocalMeetVenue.coachFigure(platform)
		if coach then
			LocalMeetVenue.coachSays(platform, nil)
			coach:SetAttribute("WalkWithUserId", nil)
			ComputerLifters.moveBody(coach, CFrame.new(platform.coachSpot - Vector3.new(0, 40, 0)))
		end
	end
end

return MeetEndScene
