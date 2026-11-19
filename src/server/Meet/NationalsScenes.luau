--!strict
--[[
	NationalsScenes
	Server / Meet

	The Nationals meet's cinematics, as the server plays them in the world (GAME_DESIGN §39, user 2026-11-18): it moves
	the real figures (they stay in the hall, where anyone can see them) and tells the lifters in the scene when each
	moment comes (LocalMeetRemotes.SCENE); each of those lifters' own screens then runs the camera, the lights and the
	words (client NationalsLiftOffScene). Nothing here decides or saves anything: LocalMeetService calls it and carries
	on when it returns.

	THE LIFT-OFF'S JUDGE (every tie for a medal place): the platform's head referee gets up from their chair with the
	score sheet, walks round the stage and through the curtain's split into the lifters' zone, stops and looks over at
	the tied lifters on their bench; they get up and walk over to stand in front of the judge, who then tells them
	together that they lift off for the place. Then LocalMeetService shows them the pick; once they have picked, the
	judge walks back and sits down (`back`).

	THE OPENING (as the meet starts, the lifters on their benches): while the lifters' screens fly round the hall, the
	head referee of the platform nearest the middle gets up with a microphone and walks out between the chair and the
	barricades; a spotlight comes on, and they welcome the crowd over the hall's speakers (NationalsConfig.WelcomeVoiceId:
	everyone in the hall hears it); then they walk back and sit down, while each lifter's own coach tells them who they
	are up against.

	PERFORMANCE: no new figures or parts: the head referee who is already there walks, under a spotlight that is already
	there (off the rest of the time). One message to each lifter in the scene.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local NationalsConfig = require(ConfigFolder:WaitForChild("NationalsConfig"))
local LocalMeetConfig = require(ConfigFolder:WaitForChild("LocalMeetConfig"))
local ClothesConfig = require(ConfigFolder:WaitForChild("ClothesConfig"))
local MeetWalkPath = require(Shared:WaitForChild("Meet"):WaitForChild("MeetWalkPath"))
local LiftOffLineUp = require(Shared:WaitForChild("Meet"):WaitForChild("LiftOffLineUp"))

local LocalMeetVenue = require(script.Parent:WaitForChild("LocalMeetVenue"))
local MeetFigures = require(script.Parent:WaitForChild("MeetFigures"))
local MeetChalk = require(script.Parent:WaitForChild("MeetChalk"))
local ComputerLifters = require(script.Parent:WaitForChild("ComputerLifters"))

local NationalsScenes = {}

local LIFT_OFF = NationalsConfig.LiftOffScene
local OPENING = NationalsConfig.Opening

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.new(0, 0, -1)
end

-- Waits until the server clock reads `at`, or `stillOn()` turns false. Returns whether it is still on.
local function waitUntil(at: number, stillOn: () -> boolean): boolean
	while serverNow() < at do
		if not stillOn() then
			return false
		end
		task.wait(math.min(0.1, math.max(0, at - serverNow())))
	end
	return stillOn()
end

-- How long into the walk `path` the body is `studs` along it.
local function secondsAt(path: MeetWalkPath.Path, studs: number): number
	local count = #path.distances
	if count < 2 then
		return 0
	end
	local step = path.duration / (count - 1)
	for index, distance in ipairs(path.distances) do
		if distance >= studs then
			return (index - 1) * step
		end
	end
	return path.duration
end

-- ---------------------------------------------------------------- the lift-off's judge

--[[
	How wide a lifter's body is across, hand to hand (studs): its build's width (LIFT_OFF.BodyWidths, the character's
	"LifterBodyBuild"), or more when something worn sticks out further either side. The same whatever the pose (a
	sitting or walking body measures no narrower).
]]
function NationalsScenes.bodyWidth(character: Model?): number
	local build = if character then character:GetAttribute(ClothesConfig.StudioBuildAttribute) else nil
	local width = (if typeof(build) == "string" then LIFT_OFF.BodyWidths[build] else nil) or LIFT_OFF.WidestBodyStuds
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if character and root and root:IsA("BasePart") then
		for _, item in ipairs(character:GetChildren()) do
			local handle = if item:IsA("Accessory") then item:FindFirstChild("Handle") else nil
			if handle and handle:IsA("BasePart") and handle.Transparency < 0.99 then
				local frame = root.CFrame:ToObjectSpace(handle.CFrame)
				local half = handle.Size / 2
				local reach = math.abs(frame.RightVector.X) * half.X + math.abs(frame.UpVector.X) * half.Y
					+ math.abs(frame.LookVector.X) * half.Z
				width = math.max(width, 2 * (math.abs(frame.Position.X) + reach))
			end
		end
	end
	return math.min(width, LIFT_OFF.MaxBodyWidthStuds)
end

--[[
	Where tied lifters of these body `widths` stand for the lift-off's judge: side by side and shoulder to shoulder in
	their platform's lifters' zone, facing the curtain (LiftOffLineUp, user 2026-11-18). Spot 1 is the one nearest the
	chalk stand, the last the furthest toward the stage's outer side: give the lifters their spots in that order (as
	they sit along the bench) and their walks never cross. Also where the judge stops in front of them, facing them.
	Nil when the platform has no curtain or no way for the judge (any venue but the Nationals hall).
]]
function NationalsScenes.liftOffSpots(platform: LocalMeetVenue.Platform, widths: { number }): ({ CFrame }?, CFrame?)
	local curtain = platform.curtainSpot
	if curtain == nil or platform.judgeWay == nil or #widths < 1 then
		return nil, nil
	end
	return LiftOffLineUp.spots(curtain, platform.chalkOut, widths)
end

export type LiftOffArgs = {
	platform: LocalMeetVenue.Platform,
	-- The tied lifters (on their benches) and the place they are tied for, in which class, on what total.
	players: { Player },
	place: number,
	classLabel: string,
	totalKg: number?,
	-- Where they come to stand and where the judge stops (liftOffSpots), and how wide each spot's lifter is. There can
	-- be more spots than players (a Studio test of one lifter stands as one of two).
	spots: { CFrame },
	judgeSpot: CFrame,
	widths: { number },
	-- Brings the tied lifters off their benches to their liftOffSpots, once the judge has come through and looked at
	-- them. Yields until they stand there.
	gather: () -> (),
	remote: RemoteEvent,
	-- False once the scene should stop (the meet ended, every tied lifter left).
	stillOn: () -> boolean,
}

export type LiftOffHandle = {
	-- The judge walks back to their chair and sits down. Yields until they are seated.
	back: () -> (),
}

--[[
	Plays the lift-off's judge for `args.players`, who sit on their benches (user 2026-11-18: "the ref comes through,
	looks at the two lifters, then they go to him, then he says what he has to say"): the judge walks to the lifters'
	zone and stops, looking at them; `args.gather` brings them over to stand in front of the judge, who turns with them;
	then the judge tells them. Yields until that is said. Returns a handle whose `back` sends the judge to their chair
	again; nil when there is no judge to walk (the lift-off then goes straight to the pick, as before).
]]
function NationalsScenes.liftOff(args: LiftOffArgs): LiftOffHandle?
	local platform = args.platform
	local judge = platform.headRef
	local way = platform.judgeWay
	local spots, judgeSpot = args.spots, args.judgeSpot
	local chair = MeetFigures.standSpot(judge)
	if judge == nil or judge.Parent == nil or way == nil or #spots < 1 or chair == nil
		or not MeetFigures.isSeated(judge) then
		return nil
	end
	local stillOn = function(): boolean
		return judge.Parent ~= nil and args.stillOn()
	end
	local toStage = flat((platform.curtainSpot :: CFrame).LookVector)
	local outer = flat(platform.chalkOut)
	local judgeAt = judgeSpot.Position
	local centre = Vector3.zero
	for _, spot in ipairs(spots) do
		centre += spot.Position / #spots
	end
	-- For the camera behind the lifters: how far along the line from its middle the nearest gap between two of them is
	-- (it looks through that gap at the judge), and half the line's length.
	local between = 0
	local nearest = math.huge
	for index = 1, #spots - 1 do
		local gapAt = (spots[index].Position + outer * ((args.widths[index] or 0) / 2)):Lerp(
			spots[index + 1].Position - outer * ((args.widths[index + 1] or 0) / 2), 0.5)
		local along = (gapAt - centre):Dot(outer)
		if math.abs(along) < nearest then
			nearest, between = math.abs(along), along
		end
	end
	local spread = (spots[#spots].Position - spots[1].Position).Magnitude / 2

	-- Where the tied lifters are now (the floor point between them): on their benches, then on the way over.
	local function liftersAt(): Vector3?
		local sum, count = Vector3.zero, 0
		for _, player in ipairs(args.players) do
			local character = player.Character
			if character and character.Parent then
				sum += ComputerLifters.positionOf(character).Position
				count += 1
			end
		end
		return if count > 0 then sum / count else nil
	end
	-- The judge on their spot, facing `target` (straight at where the lifters will stand when it is too near to tell).
	local function facing(target: Vector3?): CFrame
		local to = if target then Vector3.new(target.X - judgeAt.X, 0, target.Z - judgeAt.Z) else Vector3.zero
		return if to.Magnitude > 0.5 then CFrame.lookAt(judgeAt, judgeAt + to.Unit) else judgeSpot
	end
	local benchAt = liftersAt() or centre
	benchAt = Vector3.new(benchAt.X, judgeAt.Y, benchAt.Z)
	-- (the judge stops looking over at them)
	local arriveSpot = facing(benchAt)

	-- The walk, worked out ahead (MeetWalkPath: the same on the server and every screen), for the scene's times.
	local path = MeetWalkPath.new({ from = chair.Position, look = chair.LookVector, points = way, final = arriveSpot,
		height = 0, usualSpeed = LocalMeetConfig.ComputerLifters.WalkSpeed })
	local toCorner = (way[1] - chair.Position).Magnitude + (way[2] - way[1]).Magnitude
	local toCurtain = toCorner + (way[3] - way[2]).Magnitude + (way[4] - way[3]).Magnitude

	-- What the judge says: shown and spoken (the same words; the class and the total are in the caption).
	local first = LIFT_OFF.FirstLines[math.clamp(args.place, 1, #LIFT_OFF.FirstLines)]
	local words = { first, LIFT_OFF.SecondLine }
	local voices: { string } = {}
	for _, line in ipairs(words) do
		if line.voiceId ~= "" then
			table.insert(voices, line.voiceId)
		end
	end

	-- (STUDIO TEST ONLY: the workspace attribute "StudioSceneHoldSeconds" holds the first shot, the judge's look and each
	-- line that much longer, to photograph them.)
	local studioHold = if RunService:IsStudio() then Workspace:GetAttribute("StudioSceneHoldSeconds") else nil
	local hold = if typeof(studioHold) == "number" then studioHold else 0
	local t0 = serverNow() + LIFT_OFF.LeadSeconds
	local tWalk = t0 + LIFT_OFF.TieSeconds + hold
	local tArrive = tWalk + path.duration
	local userIds: { number } = {}
	for _, player in ipairs(args.players) do
		table.insert(userIds, player.UserId)
	end
	local function send(message: { [string]: any })
		for _, player in ipairs(args.players) do
			if player.Parent then
				args.remote:FireClient(player, message)
			end
		end
	end
	send({
		kind = "LiftOff",
		t0 = t0,
		tWalk = tWalk,
		-- (the judge turns the stage's front corner; a moment before the curtain parts)
		tSide = tWalk + secondsAt(path, toCorner),
		tThrough = tWalk + secondsAt(path, toCurtain) - LIFT_OFF.ThroughLeadSeconds,
		tArrive = tArrive,
		judge = judge,
		lifters = userIds,
		count = #spots,
		place = args.place,
		classLabel = args.classLabel,
		totalKg = args.totalKg,
		voices = voices,
		chair = chair.Position,
		way = way,
		judgeAt = judgeAt,
		centre = centre,
		benchAt = benchAt,
		spread = spread,
		between = between,
		toStage = toStage,
		outer = outer,
		stageCentre = platform.liftSpot.Position,
	})

	-- Up off the chair, the score sheet in hand, while the lifters' screens are still on the two of them.
	task.spawn(function()
		if waitUntil(t0 + LIFT_OFF.StandUpAt, stillOn) then
			MeetFigures.giveClipboard(judge)
			MeetFigures.showClipboard(judge, true)
			MeetFigures.standUp(judge, LIFT_OFF.StandUpSeconds)
		end
	end)
	local talk: AnimationTrack? = nil
	if waitUntil(tWalk, stillOn) then
		-- (in case the stand up was cut short)
		MeetFigures.standUp(judge, 0)
		ComputerLifters.walkBody(judge, way, arriveSpot, stillOn)
		-- Through the curtain, stopped, looking over at them on their bench.
		if waitUntil(tArrive + LIFT_OFF.LookSeconds + hold, stillOn) then
			-- They get up and come over; the judge turns with them as they come.
			local turning = true
			task.spawn(function()
				local height = judge:GetPivot().Position.Y - judgeAt.Y
				while turning and stillOn() do
					local dt = RunService.Heartbeat:Wait()
					if not turning then
						break
					end
					local goal = facing(liftersAt()) + Vector3.new(0, height, 0)
					judge:PivotTo(judge:GetPivot():Lerp(goal, math.min(1, LIFT_OFF.TurnRate * dt)))
				end
			end)
			args.gather()
			turning = false
			if stillOn() then
				-- Square to them, and the words: the sheet held up, talking with the other hand (the coach's talking move).
				ComputerLifters.moveBody(judge, judgeSpot)
				local lines: { { at: number, seconds: number, who: string, text: string, voiceId: string } } = {}
				local at = serverNow() + LIFT_OFF.GatherPauseSeconds
				for _, line in ipairs(words) do
					local seconds = (if line.seconds > 0 then line.seconds + LIFT_OFF.AfterVoiceSeconds else LIFT_OFF.LineSeconds) + hold
					table.insert(lines, { at = at, seconds = seconds, who = "HEAD JUDGE", text = line.text, voiceId = line.voiceId })
					at += seconds + LIFT_OFF.LinePauseSeconds
				end
				local tEnd = at
				send({ kind = "LiftOffLines", lines = lines, tEnd = tEnd })
				talk = MeetChalk.play(judge, LocalMeetConfig.Chalk.CoachTalkAnimationId)
				waitUntil(tEnd, stillOn)
			end
		end
	end
	MeetChalk.stop(talk)

	local returned = false
	local function back()
		if returned then
			return
		end
		returned = true
		if judge.Parent == nil then
			return
		end
		if stillOn() and not MeetFigures.isSeated(judge) then
			local route: { Vector3 } = {}
			for index = #way, 1, -1 do
				table.insert(route, way[index])
			end
			ComputerLifters.walkBody(judge, route, chair, stillOn)
		end
		-- Seated again whatever happened on the way (a meet that ended mid-walk puts them straight back).
		ComputerLifters.moveBody(judge, chair)
		MeetFigures.sitDown(judge, if stillOn() then LIFT_OFF.StandUpSeconds else 0)
		MeetFigures.showClipboard(judge, false)
	end
	if not stillOn() then
		back()
		return nil
	end
	return { back = back }
end

-- ---------------------------------------------------------------- the opening

export type OpeningLifter = {
	player: Player,
	platform: LocalMeetVenue.Platform,
	-- The lifters they are placed against (UserIds): the rest of their class, or everyone when the meet is on points.
	rivals: { number },
	-- The meet is placed on points; and nobody else is in their class.
	onPoints: boolean,
	alone: boolean,
	-- (Studio test of one lifter: they stand in as their own rival, to look at that part.)
	studioSelfRival: boolean?,
}

export type OpeningArgs = {
	venue: LocalMeetVenue.Venue,
	lifters: { OpeningLifter },
	remote: RemoteEvent,
	-- The hall's crowd cheers (a sound for everyone in the hall), at the announcer's platform.
	cheer: (platform: LocalMeetVenue.Platform) -> (),
	stillOn: () -> boolean,
}

-- The platform whose head referee announces: among the lifters' platforms that can (a seated head referee, a spot to
-- stand on), the one nearest the middle of the hall.
local function announcerPlatform(args: OpeningArgs): LocalMeetVenue.Platform?
	local middle = Vector3.zero
	for _, platform in ipairs(args.venue.platforms) do
		middle += platform.liftSpot.Position / #args.venue.platforms
	end
	local best: LocalMeetVenue.Platform? = nil
	local bestDistance = math.huge
	for _, lifter in ipairs(args.lifters) do
		local platform = lifter.platform
		if platform.announceSpot and platform.announceWay and MeetFigures.isSeated(platform.headRef) then
			local distance = (platform.liftSpot.Position - middle).Magnitude
			if distance < bestDistance then
				best, bestDistance = platform, distance
			end
		end
	end
	return best
end

--[[
	Plays the opening for `args.lifters` (seated on their benches). Yields until it is over. Returns whether it played:
	false when the venue has no tour or no platform has an announcer (the meet then just starts, as before).
]]
function NationalsScenes.opening(args: OpeningArgs): boolean
	local tourFor = args.venue.tour
	local platform = announcerPlatform(args)
	if tourFor == nil or platform == nil then
		return false
	end
	local announcer = platform.headRef :: Model
	local spot = platform.announceSpot :: CFrame
	local way = platform.announceWay :: { Vector3 }
	local chair = MeetFigures.standSpot(announcer)
	if chair == nil then
		return false
	end
	local stillOn = function(): boolean
		return announcer.Parent ~= nil and args.stillOn()
	end
	local toStands = flat(spot.LookVector)
	local walk = MeetWalkPath.new({ from = chair.Position, look = chair.LookVector, points = way, final = spot, height = 0,
		usualSpeed = LocalMeetConfig.ComputerLifters.WalkSpeed })

	-- (STUDIO TEST ONLY: the workspace attribute "StudioSceneHoldSeconds" holds the coach's part that much longer.)
	local studioHold = if RunService:IsStudio() then Workspace:GetAttribute("StudioSceneHoldSeconds") else nil
	local hold = if typeof(studioHold) == "number" then studioHold else 0
	local t0 = serverNow() + OPENING.LeadSeconds
	local tSpeak = t0 + OPENING.TourSeconds
	local tBack = tSpeak + NationalsConfig.WelcomeVoiceSeconds + OPENING.AfterVoiceSeconds
	local tCoach = tBack + OPENING.BackSeconds
	local tEnd = tCoach + OPENING.CoachSeconds + hold
	local voiceLines: { { at: number, seconds: number, who: string, text: string } } = {}
	for _, line in ipairs(OPENING.VoiceLines) do
		table.insert(voiceLines, { at = tSpeak + line.from, seconds = line.to - line.from, who = "ANNOUNCER", text = line.text })
	end
	local tour = tourFor(platform.index)

	for _, lifter in ipairs(args.lifters) do
		local player = lifter.player
		if player.Parent == nil then
			continue
		end
		local words: { string }
		if lifter.onPoints and lifter.alone then
			words = { OPENING.CoachAlone }
		elseif lifter.onPoints then
			words = OPENING.CoachPoints
		else
			words = OPENING.CoachRivals
		end
		local coachLines: { { at: number, seconds: number, text: string } } = {}
		if #words == 1 then
			table.insert(coachLines, { at = tCoach + OPENING.CoachLineAt,
				seconds = OPENING.CoachSeconds - OPENING.CoachLineAt - 0.4 + hold, text = words[1] })
		else
			local second = tCoach + OPENING.CoachLineAt + OPENING.CoachFirstSeconds + 0.3 + hold / 2
			table.insert(coachLines, { at = tCoach + OPENING.CoachLineAt, seconds = OPENING.CoachFirstSeconds + hold / 2,
				text = words[1] })
			table.insert(coachLines, { at = second, seconds = OPENING.CoachSecondSeconds + hold / 2, text = words[2] })
		end
		local seat = lifter.platform.seats
		args.remote:FireClient(player, {
			kind = "Opening",
			t0 = t0,
			tSpeak = tSpeak,
			tBack = tBack,
			tCoach = tCoach,
			tEnd = tEnd,
			tour = tour,
			announcer = announcer,
			announceAt = spot.Position,
			toStands = toStands,
			chair = chair.Position,
			announceCuts = { tSpeak + OPENING.AnnounceCuts[1], tSpeak + OPENING.AnnounceCuts[2] },
			voiceLines = voiceLines,
			coach = LocalMeetVenue.coachFigure(lifter.platform),
			coachLines = coachLines,
			rivals = if lifter.alone then {} else lifter.rivals,
			studioSelfRival = lifter.studioSelfRival,
			-- (the way the benches face: toward the backdrop's back)
			benchFacing = if seat and seat[1] then flat(seat[1].CFrame.LookVector) else -toStands,
		})
	end

	-- The coaches talk to their lifters at the end (each lifter's own screen stands their coach in front of them).
	local coaches: { AnimationTrack } = {}
	task.spawn(function()
		if not waitUntil(tCoach, stillOn) then
			return
		end
		local seen: { [LocalMeetVenue.Platform]: boolean } = {}
		for _, lifter in ipairs(args.lifters) do
			if not seen[lifter.platform] then
				seen[lifter.platform] = true
				local track = MeetChalk.play(LocalMeetVenue.coachFigure(lifter.platform), LocalMeetConfig.Chalk.CoachTalkAnimationId)
				if track then
					table.insert(coaches, track)
				end
			end
		end
	end)

	-- The announcer: up off the chair with the microphone and out to the spot while the screens fly round the hall.
	local light = platform.announceLight
	local voice = args.venue.announcerVoice
	local talk: AnimationTrack? = nil
	local leave = tSpeak - walk.duration - 1.2
	if waitUntil(leave - 1.1, stillOn) then
		MeetFigures.giveMicrophone(announcer)
		MeetFigures.standUp(announcer, 0.9)
	end
	if waitUntil(leave, stillOn) then
		MeetFigures.standUp(announcer, 0)
		ComputerLifters.walkBody(announcer, way, spot, stillOn)
	end
	if light and waitUntil(tSpeak - OPENING.SpotLeadSeconds, stillOn) then
		light.Brightness = OPENING.SpotBrightness
	end
	if waitUntil(tSpeak - OPENING.AnnounceLeadSeconds, stillOn) then
		-- (the microphone comes up just before the first word; the move is one take, not a loop)
		talk = MeetChalk.play(announcer, OPENING.AnnounceAnimationId)
		if talk then
			talk.Looped = false
		end
	end
	if waitUntil(tSpeak, stillOn) then
		if voice then
			voice.TimePosition = 0
			voice:Play()
		end
		for _, at in ipairs(OPENING.CheerAt) do
			task.delay(at, function()
				if stillOn() then
					args.cheer(platform)
				end
			end)
		end
		waitUntil(tBack, stillOn)
	end
	MeetChalk.stop(talk)
	if voice and not stillOn() then
		voice:Stop()
	end
	-- Back to the chair, in the background: the screens watch the start of it, then go to their lifter and coach.
	task.spawn(function()
		if announcer.Parent == nil then
			return
		end
		if stillOn() and not MeetFigures.isSeated(announcer) then
			ComputerLifters.walkBody(announcer, { way[2], way[1] }, chair, stillOn)
		end
		ComputerLifters.moveBody(announcer, chair)
		MeetFigures.sitDown(announcer, if stillOn() then 0.9 else 0)
		MeetFigures.showMicrophone(announcer, false)
	end)
	task.delay(1.6, function()
		if light then
			light.Brightness = 0
		end
	end)
	waitUntil(tEnd, stillOn)
	for _, track in ipairs(coaches) do
		MeetChalk.stop(track)
	end
	return true
end

return NationalsScenes
