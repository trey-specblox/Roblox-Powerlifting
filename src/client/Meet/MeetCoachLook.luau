--!strict
--[[
	MeetCoachLook
	Client / Meet

	YOUR CHOSEN COACH AT YOUR MEETS (GAME_DESIGN §40.5; user 2026-11-24: "Let's do show your chosen coach at meets", then
	"Yes work on that" for their own bodies; 2026-11-23: "Client based as in only the user can see their own coach
	talking to them"). Every platform has one coach figure the server builds and walks (out behind the lifter, the chalk,
	the back slaps), and its name tag and speech bubble are already moved into the lifter's own screen
	(LocalMeetVenue.staffFor). On THIS player's screen only, that coach becomes the coach they chose:

	  - a lift coach (Squatavious, Benchamin, Sumo): the platform's coach is hidden here and a copy of the chosen coach
	    (his own body and clothes: CoachingConfig.FiguresFolder, built by CoachingService) stands in his place and copies
	    every move he makes, joint by joint, each frame, at his own hip height (Squatavious is short, Sumo long-legged).
	    The name tag and speech bubble sit over the copy, the clipboard shows and hides with the real one's.
	  - the gym owner (everyone's free basic coach): the tag says GYM OWNER and the coach stays as he is.
	  - (no figure yet in storage: the old look, the coach in the chosen coach's colours)

	Everyone else keeps seeing the gym's own coach. MeetChalkShot puts the chalk puffs on the copy's hands (shownAs).

	Display only: who the active coach is comes from the server (CoachingRemotes.GET); the server's coach still does the
	walking and the animating, the copy only follows it.

	PERFORMANCE: one extra figure, only during your own meet; each frame 14 joint copies and one root move (and for
	Squatavious, a look at the platform coach's playing animations for the jump).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared:WaitForChild("Config"):WaitForChild("QuestConfig"))
local LocalMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("LocalMeetConfig"))
local CoachingConfig = require(Shared:WaitForChild("Config"):WaitForChild("CoachingConfig"))
local CoachingRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("CoachingRemotes"))

local MeetCoachLook = {}

-- The meet coach's own shirt colour (MeetFigures OUTFITS.Coach.top): the parts in it are the shirt.
local GYM_COACH_TOP = Color3.fromRGB(28, 40, 78)
local TAG_WIDTH = 150
local FIGURES_WAIT_SECONDS = 10

local started = false
-- The platform coach being stood in for -> the copy shown in his place (MeetChalkShot reads it).
local doubles: { [Model]: Model } = {}
-- Copies whose slaps land hard (Squatavious's jump slap): MeetChalkShot plays the louder slap and a bigger puff.
local hardSlappers: { [Model]: boolean } = {}

--[[
	COACH SQUATAVIOUS'S JUMP SLAP (user 2026-11-24: "With squatavious Maby just have it where he jumps up in a funny way
	and slaps your back hard"). He is too short to reach the lifter's shoulders: in the coach's back-chalking loop
	(LocalMeetConfig.Chalk.CoachBackAnimationId) his hands came 1.35 studs under where the slaps land and 0.33 further
	back (measured in Studio 2026-11-24 against the lifter's UpperTorso at SlapAt 4.85 / 5.15). So round the two slaps he
	crouches, springs up and HANGS in the air through both slaps, knees tucked up like a cannonball, then lands with a
	squash: his open hands land where the gym coach's do, on the shoulders. Times in seconds of that loop; heights and
	moves in studs; angles in degrees.
]]
local JUMP = {
	crouch = 4.25, launch = 4.55, top = 4.75, fall = 5.25, land = 5.45, settle = 5.8,
	height = 1.35, forward = 0.33, float = 0.06,
	-- On the floor (the crouch and the landing squash) his hips drop exactly as far as his bent legs shorten, so the
	-- feet stay flat on the floor: thigh 0.52 + shin 0.42 (build_coach_bodies_01 SKELETONS), knee bent twice the hip,
	-- the shin then leans back the hip's angle: the drop is legLength * (1 - cos(hip)); 0.22 fully bent (hip 40 / knee
	-- 80). (A fixed drop sank his feet up to 0.27 into the floor, Studio 2026-11-24.)
	legLength = 0.94,
	tuckHip = 70, tuckKnee = 110, bendHip = 40, bendKnee = 80,
}
local JUMP_ANIMATION_ID = LocalMeetConfig.Chalk.CoachBackAnimationId

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- Where the jump has him at loop time t: (up, forward, tuck 0..1 legs pulled up, bend 0..1 knees bent on the floor).
local function jumpAt(t: number): (number, number, number, number)
	local j = JUMP
	if t < j.crouch or t > j.settle then
		return 0, 0, 0, 0
	end
	local function drop(b: number): number
		return j.legLength * (1 - math.cos(math.rad(j.bendHip * b)))
	end
	local up, bend = 0, 0
	if t < j.launch then
		bend = smooth((t - j.crouch) / (j.launch - j.crouch))
		up = -drop(bend)
	elseif t < j.top then
		local u = (t - j.launch) / (j.top - j.launch)
		bend = 1 - smooth(u * 2)
		up = -drop(bend) + j.height * (1 - (1 - u) ^ 2)                           -- legs straighten, fast off the floor
	elseif t < j.fall then
		up = j.height + j.float * math.sin(math.pi * (t - j.top) / (j.fall - j.top))  -- the cartoon hang
	elseif t < j.land then
		local u = (t - j.fall) / (j.land - j.fall)
		up = j.height * (1 - u * u)                                                  -- dropping, faster and faster
	else
		-- touching down on the floor, then the squash: knees bend as the hips drop, and back up (landing already low
		-- with straight legs put his feet 0.12 into the floor, Studio 2026-11-24)
		local u = (t - j.land) / (j.settle - j.land)
		bend = math.sin(math.pi * math.clamp(u, 0, 1))
		up = -drop(bend)
	end
	local forward = j.forward * smooth((t - j.launch) / (j.top - j.launch)) * (1 - smooth((t - j.fall) / (j.land - j.fall)))
	local tuck = smooth((t - j.launch) / (j.top + 0.05 - j.launch)) * (1 - smooth((t - j.fall) / (j.land - j.fall)))
	return up, forward, tuck, bend
end

-- The back-chalking loop's time on the platform coach, or nil while he isn't playing it.
local function backLoopTime(animator: Animator?): number?
	if animator == nil then
		return nil
	end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		local animation = track.Animation
		if animation and animation.AnimationId == JUMP_ANIMATION_ID then
			return track.TimePosition
		end
	end
	return nil
end

local function close(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.03
end

-- What the coach is called on the tag: "SQUATAVIOUS", "BENCHAMIN", "SUMO"; the gym owner's title for him.
local function tagFor(active: string): string
	local coach = QuestConfig.Coaches[active]
	if coach then
		return string.upper((string.gsub(coach.name, "^Coach%s+", "")))
	end
	return CoachingConfig.Owner.title
end

-- The figure shown on this screen for `figure` (its copy while one stands in for it), for effects placed on the body.
-- Copies placed again RIGHT NOW (a caller that just moved the platform coach this frame: MeetEndScene's walk to the
-- podium keeps him beside the lifter, and the copy would otherwise trail a frame behind, off the lifter's back).
local syncers: { [Model]: () -> () } = {}
function MeetCoachLook.syncNow(figure: Model?)
	local sync = figure and syncers[figure]
	if sync then
		sync()
	end
end

function MeetCoachLook.shownAs(figure: Model?): Model?
	if figure == nil then
		return nil
	end
	return doubles[figure] or figure
end

-- Whether the coach shown for `figure` slaps hard (Squatavious's jump slap: the louder slap, the bigger puff).
function MeetCoachLook.slapsHard(figure: Model?): boolean
	local shown = figure and doubles[figure]
	return shown ~= nil and hardSlappers[shown] == true
end

-- Hides (or shows again) every part of the platform's coach on this screen only.
local function hideHere(figure: Model, hidden: boolean): RBXScriptConnection?
	local function apply(d: Instance)
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if hidden then 1 else 0
		elseif d:IsA("Decal") then
			d.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
	for _, d in ipairs(figure:GetDescendants()) do
		apply(d)
	end
	-- (hand shapes, clothes and the clipboard can be added later)
	return if hidden then figure.DescendantAdded:Connect(apply) else nil
end

-- An animated joint: the bodies' rigs use AnimationConstraints (Studio 2026-11-24: the swapped bodies have no
-- Motor6Ds), older rigs Motor6Ds; both have a Transform the animations set.
local function isJoint(d: Instance): boolean
	return d:IsA("AnimationConstraint") or d:IsA("Motor6D")
end

-- The joint pairs: each of the copy's joints with the platform coach's joint of the same name in the same part.
local function jointPairs(copy: Model, figure: Model): { { any } }
	local pairsOut = {}
	for _, joint in ipairs(copy:GetDescendants()) do
		if isJoint(joint) and joint.Parent then
			local part = figure:FindFirstChild(joint.Parent.Name)
			local theirs = part and part:FindFirstChild(joint.Name)
			if theirs and isJoint(theirs) then
				table.insert(pairsOut, { joint, theirs })
			end
		end
	end
	return pairsOut
end

-- The clipboard parts of a figure, in a stable order (both figures' clipboards are the same model).
local function clipboardParts(figure: Model): { BasePart }
	local out = {}
	for _, child in ipairs(figure:GetChildren()) do
		if string.sub(child.Name, 1, 9) == "Clipboard" then
			local all: { Instance } = child:GetDescendants()
			table.insert(all, child)
			for _, d in ipairs(all) do
				if d:IsA("BasePart") then
					table.insert(out, d)
				end
			end
		end
	end
	table.sort(out, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
	return out
end

--[[
	Stands a copy of `template` (a lift coach's dressed figure) in for `figure` on this screen until `billboard` (the
	coach's tag in this player's screen) goes away. Returns whether it did.
]]
local function standIn(figure: Model, template: Model, billboard: BillboardGui, jumps: boolean): boolean
	local theirRoot = figure:FindFirstChild("HumanoidRootPart")
	local theirHumanoid = figure:FindFirstChildOfClass("Humanoid")
	if theirRoot == nil or not theirRoot:IsA("BasePart") or theirHumanoid == nil or doubles[figure] then
		return false
	end
	local copy = template:Clone()
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BillboardGui") or d:IsA("ProximityPrompt") or d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local root = copy:FindFirstChild("HumanoidRootPart")
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil then
		copy:Destroy()
		return false
	end
	root.Anchored = true
	-- (it only follows: no state machine, no animator of its own)
	humanoid.EvaluateStateMachine = false
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		animator:Destroy()
	end
	copy.Name = "YourCoach"
	local joints = jointPairs(copy, figure)
	local mine, theirs = clipboardParts(copy), clipboardParts(figure)
	-- A short coach stands lower, a long-legged one higher: each on his own legs, the same floor.
	local lift = humanoid.HipHeight - theirHumanoid.HipHeight
	local hideConnection = hideHere(figure, true)
	-- Squatavious's legs, for the jump's tuck (the joints in his thigh and shin parts).
	local legJoints: { [any]: string } = {}
	if jumps then
		for _, pair in ipairs(joints) do
			local name = pair[1].Name
			if name == "LeftHip" or name == "RightHip" then
				legJoints[pair[1]] = "hip"
			elseif name == "LeftKnee" or name == "RightKnee" then
				legJoints[pair[1]] = "knee"
			elseif name == "LeftAnkle" or name == "RightAnkle" then
				legJoints[pair[1]] = "ankle"
			end
		end
		hardSlappers[copy] = true
	end

	-- THE REACH (the back chalking and slaps, where the coach's hands land ON the lifter): a coach whose arms reach
	-- further or shorter than the gym coach's would rub and slap inside the lifter's back or in the air (Coach Sumo's
	-- long arms: his slaps 0.36 into the lifter's back, Studio 2026-11-24). While that loop plays, the copy stands as far
	-- forward or back as keeps his hands where the gym coach's are (forward of his own feet, both hands' average, from
	-- the last frame), eased so it never jumps. Squatavious's jump does it his way (JUMP.forward).
	local theirHands = { figure:FindFirstChild("RightHand"), figure:FindFirstChild("LeftHand") }
	local myHands = { copy:FindFirstChild("RightHand"), copy:FindFirstChild("LeftHand") }
	local myUpperArms = { copy:FindFirstChild("RightUpperArm"), copy:FindFirstChild("LeftUpperArm") }
	local reach = 0
	-- ...and as WIDE: each shoulder turns a little out or in (about the torso's up axis) so each hand keeps the gym
	-- coach's hand's sideways place (Sumo's long forearms crossed his hands over the middle of the lifter's back, the two
	-- hands through each other, Studio 2026-11-24). Radians, right then left; at most SPREAD_LIMIT.
	local spread = { 0, 0 }
	local SPREAD_LIMIT = 0.6
	-- ...and as HIGH: each shoulder tips down or up (about the torso's sideways axis) so each hand keeps the gym coach's
	-- hand's height, and never above the lifter's upper back (user 2026-11-27, State: Coach Benchamin's
	-- hand came up by the lifter's head. Measured in Studio: the gym coach's own chalking puts his hands 1.1 to 1.5 studs
	-- over a Skinny lifter's UpperTorso middle, 0.8 from the head, so the cap does the work). Radians, right then left; at
	-- most PITCH_LIMIT.
	local pitch = { 0, 0 }
	local PITCH_LIMIT = 0.9
	-- Studs under the bottom of the lifter's Head: the upper back, under the shoulder line. (Measured from the head, not the
	-- UpperTorso part: on the lifter bodies that part reaches above the head's bottom, so 0.15 and 0.5 under it still had
	-- the hands at the neck, Studio 2026-11-27; big head accessories hang down to the shoulders too.)
	local UNDER_HEAD = 0.6
	local shoulderSide: { [any]: number } = {}
	for _, pair in ipairs(joints) do
		if pair[1].Name == "RightShoulder" then
			shoulderSide[pair[1]] = 1
		elseif pair[1].Name == "LeftShoulder" then
			shoulderSide[pair[1]] = 2
		end
	end

	local function spreadStep(base: CFrame, rate: number, backTop: number?)
		for i = 1, 2 do
			local theirs, mine, upper = theirHands[i], myHands[i], myUpperArms[i]
			if theirs and mine and upper and theirs:IsA("BasePart") and mine:IsA("BasePart") and upper:IsA("BasePart") then
				local g = base:PointToObjectSpace(theirs.Position)
				local mineRoot = (root :: BasePart).CFrame
				local c = mineRoot:PointToObjectSpace(mine.Position)
				local s = mineRoot:PointToObjectSpace(upper.Position)
				-- (a turn about the up axis moves a hand out in front sideways by about its distance in front times the turn)
				local inFront = math.max(0.3, s.Z - c.Z)
				local turn = -(g.X - c.X) / inFront
				spread[i] = math.clamp(spread[i] + turn * rate, -SPREAD_LIMIT, SPREAD_LIMIT)
				-- (a turn about the sideways axis lifts a hand out in front by about its distance in front times the turn)
				-- (heights in the world: the copy stands on its own, longer or shorter, legs)
				local wantY = theirs.Position.Y
				if backTop then
					wantY = math.min(wantY, backTop)
				end
				local tip = (wantY - mine.Position.Y) / inFront
				pitch[i] = math.clamp(pitch[i] + tip * rate, -PITCH_LIMIT, PITCH_LIMIT)
			end
		end
	end

	local function reachTarget(base: CFrame): number
		local sum, n = 0, 0
		for i = 1, 2 do
			local theirs, mine = theirHands[i], myHands[i]
			if theirs and mine and theirs:IsA("BasePart") and mine:IsA("BasePart") then
				-- (root space: -Z is forward; the copy's own root, without this frame's move)
				local g = base:PointToObjectSpace(theirs.Position)
				local c = (root :: BasePart).CFrame:PointToObjectSpace(mine.Position)
				sum += c.Z - g.Z
				n += 1
			end
		end
		return if n > 0 then sum / n else 0
	end

	-- A jump once begun runs on its own clock to the landing (os.clock when it was at JUMP.crouch). It used to follow
	-- the back loop's time, so a lifter walking out mid-jump stopped the loop and froze him half way (user 2026-11-24:
	-- "he does not fully complete the jump ... then just stops because I'm already walking out").
	local jumpClock: number? = nil

	local function follow(dt: number)
		local up, forward, tuck, bend = 0, 0, 0, 0
		local t = backLoopTime(theirHumanoid:FindFirstChildOfClass("Animator"))
		local base = (theirRoot :: BasePart).CFrame
		if jumps then
			local now = os.clock()
			if jumpClock and now - jumpClock > JUMP.settle - JUMP.crouch then
				jumpClock = nil
			end
			if jumpClock == nil and t and t >= JUMP.crouch and t < JUMP.settle then
				jumpClock = now - (t - JUMP.crouch)
			end
			if jumpClock then
				up, forward, tuck, bend = jumpAt(JUMP.crouch + (now - jumpClock))
			end
		else
			local rate = math.min(1, (dt or 0) * 10)
			local target = if t then reachTarget(base) else 0
			reach += (target - reach) * rate
			forward = reach
			if t then
				-- (the lifter whose back he chalks: this player, his coach)
				local character = Players.LocalPlayer.Character
				local head = character and character:FindFirstChild("Head")
				local backTop = if head and head:IsA("BasePart")
					then head.Position.Y - head.Size.Y / 2 - UNDER_HEAD
					else nil
				spreadStep(base, rate, backTop)
			else
				spread[1] -= spread[1] * rate
				spread[2] -= spread[2] * rate
				pitch[1] -= pitch[1] * rate
				pitch[2] -= pitch[2] * rate
			end
		end
		local ahead = Vector3.new(base.LookVector.X, 0, base.LookVector.Z)
		ahead = if ahead.Magnitude > 1e-3 then ahead.Unit else Vector3.zero
		root.CFrame = base + Vector3.new(0, lift + up, 0) + ahead * forward
		for _, pair in ipairs(joints) do
			local leg = legJoints[pair[1]]
			if leg and (tuck > 0 or bend > 0) then
				-- (hips swing the thighs forward, knees fold the shins back: the cannonball tuck in the air, a knee bend on
				-- the floor for the crouch and the landing; on the floor the ankles tip the feet back flat, else the bent
				-- shin tipped them toes-down into the floor, Studio 2026-11-24; in the air the toes stay pointed)
				local degrees = if leg == "hip" then JUMP.tuckHip * tuck + JUMP.bendHip * bend
					elseif leg == "knee" then -(JUMP.tuckKnee * tuck + JUMP.bendKnee * bend)
					else (JUMP.bendKnee - JUMP.bendHip) * bend
				pair[1].Transform = pair[2].Transform * CFrame.Angles(math.rad(degrees), 0, 0)
			elseif shoulderSide[pair[1]] and (spread[shoulderSide[pair[1]]] ~= 0 or pitch[shoulderSide[pair[1]]] ~= 0) then
				-- (the turns in the torso's frame, before the animation's own shoulder turn)
				local i = shoulderSide[pair[1]]
				pair[1].Transform = CFrame.Angles(pitch[i], spread[i], 0) * pair[2].Transform
			else
				pair[1].Transform = pair[2].Transform
			end
		end
		if #mine == #theirs then
			for i, part in ipairs(mine) do
				part.Transparency = theirs[i].Transparency
			end
		end
	end
	follow()
	copy.Parent = Workspace
	doubles[figure] = copy
	syncers[figure] = function()
		root.CFrame = (theirRoot :: BasePart).CFrame + Vector3.new(0, lift, 0)
	end
	-- the tag and the speech bubble over the copy's head
	local head = copy:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		billboard.Adornee = head
	end
	-- (after the animations have posed the real coach this frame, before it is drawn)
	local stepping = RunService.PreSimulation:Connect(follow)

	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		stepping:Disconnect()
		if hideConnection then
			hideConnection:Disconnect()
		end
		doubles[figure] = nil
		syncers[figure] = nil
		hardSlappers[copy] = nil
		copy:Destroy()
		if figure.Parent then
			hideHere(figure, false)
		end
	end
	billboard.AncestryChanged:Connect(function()
		if not billboard:IsDescendantOf(game) then
			finish()
		end
	end)
	figure.AncestryChanged:Connect(function()
		if not figure:IsDescendantOf(Workspace) then
			finish()
		end
	end)
	return true
end

--[[
	THE GYM OWNER'S OWN CHALKING (user 2026-11-27, after Coach Benchamin's hands were fixed: "Yes, fix it"): the free coach
	has no copy standing in for him, so his own figure's arms are tipped on this screen instead. While he chalks this
	player's back, each shoulder tips down just enough that its hand stays under the player's shoulder line (UNDER_HEAD
	under the Head's bottom: the gym coach's chalk move put his hands up by a Skinny lifter's head, 0.8 from its middle).
	The animation poses him afresh every frame and the tip is put on top, nudged a little each frame, so it never jumps. Display only, this screen only; other players see him as the animation has him.
]]
local OWNER_PITCH_LIMIT = 0.9 -- radians
local OWNER_UNDER_HEAD = 0.6 -- studs under the bottom of the lifter's Head

local function capOwnHands(figure: Model, billboard: BillboardGui)
	local theirRoot = figure:FindFirstChild("HumanoidRootPart")
	local theirHumanoid = figure:FindFirstChildOfClass("Humanoid")
	if theirRoot == nil or not theirRoot:IsA("BasePart") or theirHumanoid == nil then
		return
	end
	-- (his joints are AnimationConstraints, the newer kind; Motor6D too, for any older figure: both have Transform)
	local sides: { { shoulder: any, hand: BasePart, upper: BasePart } } = {}
	for _, names in ipairs({ { "RightShoulder", "RightHand", "RightUpperArm" }, { "LeftShoulder", "LeftHand", "LeftUpperArm" } }) do
		local upper = figure:FindFirstChild(names[3])
		local hand = figure:FindFirstChild(names[2])
		local shoulder = upper and upper:FindFirstChild(names[1])
		if shoulder and (shoulder:IsA("Motor6D") or shoulder:IsA("AnimationConstraint")) and hand and hand:IsA("BasePart")
			and upper and upper:IsA("BasePart") then
			table.insert(sides, { shoulder = shoulder, hand = hand, upper = upper })
		end
	end
	if #sides == 0 then
		return
	end
	local pitch = { 0, 0 }
	local stepping = RunService.PreSimulation:Connect(function(dt: number)
		local t = backLoopTime(theirHumanoid:FindFirstChildOfClass("Animator"))
		local character = Players.LocalPlayer.Character
		local head = character and character:FindFirstChild("Head")
		local backTop = if t and head and head:IsA("BasePart") then head.Position.Y - head.Size.Y / 2 - OWNER_UNDER_HEAD
			else nil
		local rate = math.min(1, (dt or 0) * 12)
		local rootFrame = (theirRoot :: BasePart).CFrame
		for i, side in ipairs(sides) do
			if backTop then
				-- (a turn about the sideways axis moves a hand out in front up or down by about its distance in front
				-- times the turn. The hand read here was posed last frame, tip and all, so the tip is nudged toward the
				-- line, never above the animation's own pose)
				local c = rootFrame:PointToObjectSpace(side.hand.Position)
				local s = rootFrame:PointToObjectSpace(side.upper.Position)
				local inFront = math.max(0.3, s.Z - c.Z)
				pitch[i] = math.clamp(pitch[i] + (backTop - side.hand.Position.Y) / inFront * rate, -OWNER_PITCH_LIMIT, 0)
			else
				pitch[i] -= pitch[i] * rate
			end
			if math.abs(pitch[i]) > 1e-3 then
				side.shoulder.Transform = CFrame.Angles(pitch[i], 0, 0) * side.shoulder.Transform
			end
		end
	end)
	local function finish()
		stepping:Disconnect()
	end
	billboard.AncestryChanged:Connect(function()
		if not billboard:IsDescendantOf(game) then
			finish()
		end
	end)
	figure.AncestryChanged:Connect(function()
		if not figure:IsDescendantOf(Workspace) then
			finish()
		end
	end)
end

function MeetCoachLook.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local remotes = CoachingRemotes.waitForClient(ReplicatedStorage)

	local function activeCoach(): string
		for _ = 1, 4 do
			local ok, view = pcall(function()
				return remotes.get:InvokeServer()
			end)
			if ok and typeof(view) == "table" and typeof(view.active) == "string" then
				return view.active
			end
			task.wait(0.5)
		end
		return CoachingConfig.OwnerId
	end

	-- A coach's tag arrived on this screen: that platform's coach is this player's coach for this meet.
	local function dress(billboard: BillboardGui)
		local active = activeCoach()
		local label = billboard:FindFirstChild("Name")
		if label and label:IsA("TextLabel") then
			label.Text = tagFor(active)
			label.Size = UDim2.fromOffset(TAG_WIDTH, label.Size.Y.Offset)
		end
		local coach = QuestConfig.Coaches[active]
		local head = billboard.Adornee
		local figure = head and head.Parent
		if coach == nil and figure and figure:IsA("Model") then
			-- (the gym owner stays as he is, his chalking hands kept under the shoulder line)
			capOwnHands(figure, billboard)
			return
		end
		if coach == nil or figure == nil or not figure:IsA("Model") then
			return
		end
		-- His own body, standing in for the platform's coach.
		local folder = ReplicatedStorage:WaitForChild(CoachingConfig.FiguresFolder, FIGURES_WAIT_SECONDS)
		local template = folder and folder:FindFirstChild(active)
		if template and template:IsA("Model") and standIn(figure, template, billboard, active == "Squat") then
			return
		end
		-- (no figure to copy: the shirt in the coach's colour, on this screen only)
		for _, part in ipairs(figure:GetDescendants()) do
			if part:IsA("BasePart") and close(part.Color, GYM_COACH_TOP) then
				part.Color = coach.shirt
			end
		end
	end

	local function watch(child: Instance)
		if child:IsA("BillboardGui") and child.Name == "CoachTag" then
			task.spawn(dress, child)
		end
	end
	for _, child in ipairs(playerGui:GetChildren()) do
		watch(child)
	end
	playerGui.ChildAdded:Connect(watch)
end

return MeetCoachLook
