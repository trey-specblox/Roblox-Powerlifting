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
	  On the podium (user 2026-11-28, after a two-player State test: no cut, no teleport) the scene opens with them
	already walking together, his arm round their back, and he walks them all the way to their place in the line for
	the podium (MeetCeremony.lineSpots), round anything solid on the way (pathfinding), saying his line as they go; there
	he lets go and walks away (user: "he should just walk away after the lifter gets by the podium"). The computer
	lifters in the top 3 walk into the line from where they are at the same time.
	On the player's screen the client MeetEndScene runs the camera, the subtitle, his voice and SKIP
	(LocalMeetRemotes.SCENE kinds "MeetEndCoach" / "MeetEndCoachLine" / "MeetEndWalk" / "MeetEndCoachEnd"). SKIP ends
	their camera; a player off the podium is also let go at once (`onSkipFree`); a podium lifter's body still walks to
	the line.

	EVERY PLAYER HAS THEIR OWN COACH (user 2026-11-28: "every person should have their OWN coach ... only visible to the
	lifters screen"): a coach figure built for the scene for each player (privateCoach), seen only on their screen, where
	MeetCoachLook shows their chosen coach's body copying it. The platforms' shared coaches are put out of sight for the
	scene. Kept out of LocalMeetService (its main chunk is at Luau's 200-local limit).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
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
local MeetRoute = require(script.Parent:WaitForChild("MeetRoute"))

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
function MeetEndScene.sceneSpot(at: CFrame, ignore: { Instance? }?, peopleRoot: Instance?): CFrame
	local chest = Vector3.new(0, 3, 0)
	local best, bestScore = at, -math.huge
	-- (Studio 2026-11-26: at a State meet the coach's place at the lifter's right was on the rack's caller, whom the
	-- raycasts pass through like any body) the people standing about: figures under `peopleRoot` (the venue's staff)
	-- and the players, all but those in `ignore` (the lifter, their coach); neither spot may be on one of them.
	local people: { Vector3 } = {}
	local skip: { [Instance]: boolean } = {}
	for _, thing in pairs(ignore or {}) do
		if thing then
			skip[thing] = true
		end
	end
	local function consider(model: Instance?)
		if model and model:IsA("Model") and not skip[model] and model:FindFirstChildOfClass("Humanoid") then
			local spot = model:GetPivot().Position
			if (spot - at.Position).Magnitude < 24 then
				table.insert(people, spot)
			end
		end
	end
	if peopleRoot then
		for _, item in ipairs(peopleRoot:GetDescendants()) do
			if item:IsA("Humanoid") then
				consider(item.Parent)
			end
		end
	end
	for _, other in ipairs(Players:GetPlayers()) do
		consider(other.Character)
	end
	local function crowded(spot: Vector3): boolean
		for _, person in ipairs(people) do
			if Vector3.new(person.X - spot.X, 0, person.Z - spot.Z).Magnitude < SETTINGS.SceneClearOfPeople then
				return true
			end
		end
		return false
	end
	for step = 0, 7 do
		local facing = CFrame.Angles(0, math.rad(step * 45), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
		local from = at.Position + chest
		local stepped = from + facing * SETTINGS.SceneStep
		local coachSpot = stepped + facing:Cross(Vector3.yAxis) * SETTINGS.SceneCoachSide
		if blockedAt(from, facing * (SETTINGS.SceneStep + 1)) == nil and not crowded(stepped) and not crowded(coachSpot) then
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
	local final = CFrame.lookAt(to, to + bestDir)
	-- (round the barricades, banners and the rest of the furniture: MeetRoute)
	ComputerLifters.walkBody(coach, MeetRoute.reroute(start, {}, final, SETTINGS.RouteBodyRadius), final, function()
		return alive() and os.clock() - began < SETTINGS.LeaveSeconds
	end, { animationId = LocalMeetConfig.ComputerLifters.WalkAnimationId, speed = SETTINGS.WalkSpeed,
		styleStuds = math.huge })
end

local function waitUntil(clock: number, alive: () -> boolean)
	while alive() and os.clock() < clock do
		task.wait(POLL_SECONDS)
	end
end

--[[
	THE COACH IS YOURS ALONE (user 2026-11-28, after a two-player State test where one platform coach walked both
	winners in turn and jumped between them: "every person should have their OWN coach ... only visible to the lifters
	screen"): each player in the scene gets a coach figure of their own, built for the scene and removed after it. It is
	tagged PrivateFigure with their UserId, so every other screen hides it (client MeetEndScene), and his name tag and
	speech bubble go into their PlayerGui, so MeetCoachLook dresses him as their chosen coach and CoachVoice says his
	lines. He is built out of sight and only then moved beside them, so no other screen ever sees him for a frame.
]]
MeetEndScene.PrivateTag = "PrivateFigure"
MeetEndScene.PrivateUserAttribute = "OnlyForUserId"
local COACHES_FOLDER = "MeetEndCoaches"

local function privateCoach(player: Player, at: CFrame): (Model?, TextLabel?)
	local folder = Workspace:FindFirstChild(COACHES_FOLDER)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = COACHES_FOLDER
		folder.Parent = Workspace
	end
	local hidden = at.Position - Vector3.new(0, 200, 0)
	local line, figure = MeetFigures.build(folder :: Instance, "Coach", hidden, hidden + at.LookVector * 4)
	if figure == nil then
		return nil, nil
	end
	figure:SetAttribute(MeetEndScene.PrivateUserAttribute, player.UserId)
	CollectionService:AddTag(figure, MeetEndScene.PrivateTag)
	local gui = player:FindFirstChildOfClass("PlayerGui")
	for _, billboard in ipairs(figure:GetDescendants()) do
		if billboard:IsA("BillboardGui") then
			if gui then
				billboard.ResetOnSpawn = false
				billboard.Parent = gui
			else
				billboard:Destroy()
			end
		end
	end
	ComputerLifters.moveBody(figure, at)
	return figure, line
end

-- Removes a scene coach and his tag and bubble on the lifter's screen.
local function removeCoach(coach: Model)
	for _, player in ipairs(Players:GetPlayers()) do
		local gui = player:FindFirstChildOfClass("PlayerGui")
		for _, billboard in ipairs(if gui then gui:GetChildren() else {}) do
			local adornee = if billboard:IsA("BillboardGui") then billboard.Adornee else nil
			if adornee and adornee:IsDescendantOf(coach) then
				billboard:Destroy()
			end
		end
	end
	coach:Destroy()
end

--[[
	THE WAY TO THE LINE, IN ONE WALK (user 2026-11-28: "have the coach actually walk the lifter out, and NOT cut and
	teleport"; and coaches must never walk through banners): MeetRoute finds a way round the furniture and anything
	solid for the two of them side by side: the way of the middle between them, wide enough for both, then the lifter
	on its left and the coach on its right.
]]
local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.zero
end

-- The lifter's and the coach's corners for walking side by side from `fromAt` to `toAt` (the coach `side` studs to the
-- lifter's right).
local function pairRoute(fromAt: CFrame, toAt: CFrame, side: number): ({ Vector3 }, { Vector3 })
	local half = side / 2
	local middle = MeetRoute.route(fromAt.Position + fromAt.RightVector * half, toAt.Position + toAt.RightVector * half,
		half + SETTINGS.RouteBodyRadius)
	local lifter: { Vector3 }, coach: { Vector3 } = {}, {}
	for index = 2, #middle - 1 do
		local along = flat(flat(middle[index] - middle[index - 1]) + flat(middle[index + 1] - middle[index]))
		if along.Magnitude > 0 then
			local right = along:Cross(Vector3.yAxis)
			table.insert(lifter, middle[index] - right * half)
			table.insert(coach, middle[index] + right * half)
		end
	end
	return lifter, coach
end

local function runBeat(beat: Beat, remotes: any, stillOn: () -> boolean, began: number, onDone: (Model?) -> ())
	local state = active[beat.player]
	-- The chosen coach's own versions of the pat and the walk, and where they have him stand for this lifter's build.
	local coaching = PlayerDataService.getCoaching(beat.player)
	local coachId = if coaching and coaching.active then coaching.active else "Owner"
	local okBuild, build = pcall(LifterBodyService.buildFor, beat.player)
	local buildKey = if okBuild then build else ""
	local version = SETTINGS.PatVersions[coachId] or SETTINGS.PatVersions.Owner
	local spot = version.place[buildKey] or version.place[SETTINGS.PatFallbackBuild]
	local walkVersion = SETTINGS.WalkPatVersions[coachId] or SETTINGS.WalkPatVersions.Owner
	local walkSpot = walkVersion.place[buildKey] or walkVersion.place[SETTINGS.PatFallbackBuild]
		or { side = spot.side, back = 0 }
	local stage = beat.stage
	local coachAt = if stage then offsetFrom(beat.lifterAt, walkSpot) else offsetFrom(beat.lifterAt, spot)
	local coach, bubble = if state then privateCoach(beat.player, coachAt) else nil, nil
	local function going(): boolean
		return stillOn() and coach ~= nil and coach.Parent ~= nil and beat.player.Parent ~= nil
	end
	if coach == nil or state == nil then
		onDone(nil)
		return
	end
	local line = MeetEndScene.lineText(beat.lineKey)
	local seconds = lineSeconds(coachId, beat.lineKey)
	MeetFigures.showClipboard(coach, false)
	remotes.scene:FireClient(beat.player, { kind = "MeetEndCoach", lifterAt = beat.lifterAt, coachAt = coachAt,
		startedAt = Workspace:GetServerTimeNow(), seconds = SETTINGS.MaxSeconds })
	-- His words: the bubble (on their screen only, hidden under the film look) and the subtitle; the client also says
	-- the line in his voice (user 2026-11-28: "the coaches have 0 voicelines for the podium cutscene").
	local function say(words: string?)
		MeetFigures.say(bubble, words)
		if words then
			remotes.scene:FireClient(beat.player, { kind = "MeetEndCoachLine", line = words, coachId = coachId })
		end
	end
	if stage == nil then
		-- Off the podium: the two pats, then his line where they stand (his free hand talking: the clip), then he goes.
		local track = if version.animationId ~= "" then MeetChalk.play(coach, version.animationId) else nil
		if track then
			track.Looped = false
		end
		waitUntil(began + SETTINGS.LineAt, going)
		if going() then
			say(line)
		end
		waitUntil(began + SETTINGS.LineAt + math.max(SETTINGS.PatSeconds, seconds + SETTINGS.LineTail), going)
		MeetChalk.stop(track)
		if going() then
			say(nil)
			walkAway(coach, beat.lifterAt, going)
		end
	else
		-- On the podium (user 2026-11-28: start already walking together): his arm round their back from the first
		-- frame, walking the whole way to their place in the line while he talks, round anything in the way.
		local armTrack = if walkVersion.animationId ~= "" then MeetChalk.play(coach, walkVersion.animationId) else nil
		local options = { animationId = LocalMeetConfig.ComputerLifters.WalkAnimationId, speed = SETTINGS.WalkSpeed,
			styleStuds = math.huge }
		-- On the lifter's screen the coach is kept beside them every frame from these (client MeetEndScene).
		coach:SetAttribute("WalkWithUserId", beat.player.UserId)
		coach:SetAttribute("WalkSide", walkSpot.side)
		coach:SetAttribute("WalkBack", walkSpot.back)
		remotes.scene:FireClient(beat.player, { kind = "MeetEndWalk", coach = coach, seconds = SETTINGS.MaxSeconds })
		-- (on their own platform at a Local meet hall, Studio 2026-11-28: the way to the line ran straight across the
		-- row of empty platforms) first off its front onto the floor, then the way to the line.
		local startAt = beat.lifterAt
		local lead: { Vector3 } = {}
		local coachLead: { Vector3 } = {}
		local top, front = beat.platform.platformTop, beat.platform.frontFloor
		if top and front then
			local out = flat(front - top.Position)
			local fromMiddle = beat.lifterAt.Position - top.Position
			local sideways = fromMiddle - out * fromMiddle:Dot(out)
			local edge = (front - top.Position):Dot(out)
			if out.Magnitude > 0 and Vector3.new(sideways.X, 0, sideways.Z).Magnitude < SETTINGS.PlatformLeft + 2
				and math.abs(fromMiddle:Dot(out)) < edge then
				local off = Vector3.new(top.Position.X, front.Y, top.Position.Z) + Vector3.new(sideways.X, 0, sideways.Z)
					+ out * (edge + SETTINGS.PlatformStepOff)
				startAt = CFrame.lookAt(off, off + out)
				lead = { off }
				coachLead = { off + startAt.RightVector * walkSpot.side }
			end
		end
		local lifterPoints, coachPoints = pairRoute(startAt, stage.slot, walkSpot.side)
		table.move(lifterPoints, 1, #lifterPoints, #lead + 1, lead)
		table.move(coachPoints, 1, #coachPoints, #coachLead + 1, coachLead)
		lifterPoints, coachPoints = lead, coachLead
		local done = 0
		local character = beat.player.Character
		task.spawn(function()
			if character then
				ComputerLifters.walkBody(character, lifterPoints, stage.slot, going, options)
			end
			done += 1
		end)
		task.spawn(function()
			ComputerLifters.walkBody(coach, coachPoints, offsetFrom(stage.slot, walkSpot), going, options)
			done += 1
		end)
		local lineAt = began + SETTINGS.WalkLineAt
		waitUntil(lineAt, going)
		if going() then
			say(line)
		end
		-- (there before he has finished? he finishes it, then lets go)
		local talkEnds = lineAt + seconds + SETTINGS.LineTail
		while going() and (done < 2 or os.clock() < talkEnds) and os.clock() - began < SETTINGS.MaxSeconds do
			task.wait(POLL_SECONDS)
		end
		if beat.onArrived and beat.player.Parent then
			beat.onArrived(stage.slot)
		end
		MeetChalk.stop(armTrack)
		coach:SetAttribute("WalkWithUserId", nil)
		if coach.Parent then
			say(nil)
			walkAway(coach, stage.slot, going)
		end
	end
	if beat.player.Parent then
		remotes.scene:FireClient(beat.player, { kind = "MeetEndCoachEnd" })
	end
	onDone(coach)
end

--[[
	Runs every beat at once (each player with their own coach), walks `walkers` (the computer lifters in the top 3)
	from where they are into the line with them, and returns when all are over, or after MaxSeconds at most, with the
	scene coaches removed and the platforms' coaches put out of sight. `stillOn` says the meet is still on;
	`onSkipFree(player)` lets a player off the podium go when they press SKIP. Returns the players who skipped.
]]
function MeetEndScene.run(beats: { Beat }, remotes: any, stillOn: () -> boolean, onSkipFree: (Player) -> (),
	walkers: { Walker }?): { [Player]: boolean }
	listen(remotes)
	local began = os.clock()
	local left = #beats
	local platforms: { LocalMeetVenue.Platform } = {}
	for _, beat in ipairs(beats) do
		active[beat.player] = { skipped = false, onSkipFree = onSkipFree, podium = beat.podium }
		table.insert(platforms, beat.platform)
	end
	-- (the platforms' own coaches stay out of the scene: each player has their own here)
	MeetEndScene.hideCoaches(platforms)
	local coaches: { Model } = {}
	for _, beat in ipairs(beats) do
		task.spawn(runBeat, beat, remotes, stillOn, began, function(coach: Model?)
			if coach then
				table.insert(coaches, coach)
			end
			left -= 1
		end)
	end
	-- The computer lifters walk into the line with the players, from where they are, round anything in the way.
	for _, walker in ipairs(walkers or {}) do
		task.spawn(function()
			local from = ComputerLifters.positionOf(walker.body) * CFrame.new(0, -3, 0)
			local start = floorAt(from.Position)
			local route = MeetRoute.route(start, walker.slot.Position, SETTINGS.RouteBodyRadius)
			local points = {}
			for index = 2, #route - 1 do
				table.insert(points, route[index])
			end
			waitUntil(began + SETTINGS.WalkLineAt, stillOn)
			if stillOn() and walker.body.Parent then
				ComputerLifters.walkBody(walker.body, points, walker.slot, stillOn, {
					animationId = LocalMeetConfig.ComputerLifters.WalkAnimationId, speed = SETTINGS.WalkSpeed,
					styleStuds = math.huge })
			end
		end)
	end
	while left > 0 and stillOn() and os.clock() - began < SETTINGS.MaxSeconds do
		task.wait(POLL_SECONDS)
	end
	for _, coach in ipairs(coaches) do
		removeCoach(coach)
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
