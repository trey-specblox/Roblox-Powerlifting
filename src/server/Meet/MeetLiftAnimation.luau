--!strict
--[[
	MeetLiftAnimation
	Server / Meet

	The lift on the platform (GAME_DESIGN.md §37.5, user 2026-11-01: "I should
	be doing the lifts"). The meet's rack faces the entrance, so the lifter
	walks straight in to it (approachFor) and is set up for the lift exactly as
	at a gym training rack (StationPoses), facing the rack and, through it, the
	head referee:
		Squat     under the bar; unrack, then step slowly back from the rack
		Bench     lying on the bench, head under the bar; unrack and get steady
		Deadlift  behind the bar on the floor; hinge down and set
	(unrack plays that part and says how long it takes; then the referee gives
	the start command.)
	With a published setup animation (StationAnimationConfig.Setups, user
	2026-11-08: "no walk up animation, no sitting down animation"), the lifter
	does all of that for real instead, from where the walk out ends: steps up to
	the bar, grips it, ducks under and walks it out (squat); turns, sits on the
	bench and lies back for the hand-off (bench); sets the feet and grips the floor
	bar (deadlift). The root part stands at the lift's spot all along (the walking
	is in the animation), and the bar stays in the J-cups until the unrack.
	The station rep animation (StationAnimationConfig) then plays ONE STAGE AT
	A TIME (StationAnimationConfig.MeetStages) instead of looping. Each minigame
	phase moves it through its stretch over that phase's time, then holds it:
	the first phase is the descent. After a good lift comes the finish (stand
	up, press, lower). The character itself is held still (anchored): no bobbing.

	Played by the SERVER, so everyone (the lifter too) sees the same lift, and
	the same code serves computer lifters. The character is marked with the
	attribute MeetLift = the lift and an ObjectValue MeetRack = the rack, so
	every client's StationPoseAnimator moves that rack's barbell with the
	lifter's hands. Visual only: nothing here decides a lift.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StationAnimationConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
	:WaitForChild("StationAnimationConfig"))
local StationLayout = require(script.Parent.Parent:WaitForChild("Training"):WaitForChild("StationLayout"))
local ComputerLifters = require(script.Parent:WaitForChild("ComputerLifters"))

local MeetLiftAnimation = {}

local LIFT_ATTRIBUTE = "MeetLift"
local RACK_VALUE = "MeetRack"
-- While a missed lift plays: true until the bar leaves the hands, then false (StationPoseAnimator moves the bar).
local BAR_HELD_ATTRIBUTE = "MeetBarHeld"
-- The cross-fade from the held lift into its fail animation (long enough to read as the bar sinking back).
local FAIL_FADE_SECONDS = 0.5
-- The glide from one progress update to the next (they come about ten times a second).
local PROGRESS_GLIDE_SECONDS = 0.15
local FADE_SECONDS = 0.15
-- Face up, head toward the rack (+Z), feet toward the open front (as StationPoses lies a lifter on the bench).
local LYING = CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, Vector3.zAxis)
-- Facing the rack (rack-local +Z), as every lift at a gym rack does.
local FACING_RACK = CFrame.Angles(0, math.pi, 0)
-- The squat: under the bar at this rack-local Z, then the walk-out, step by step, to WALKOUT_Z.
local SQUAT_UNDER_Z = -0.4
local WALKOUT_Z = -1.6
local WALKOUT_STEPS = 3
local WALKOUT_SECONDS = 2.4
-- Holding the bar before the walk-out (unracked), the bench's "get steady", and settling into the squat stance.
local UNRACK_HOLD_SECONDS = 0.8
local BENCH_STEADY_SECONDS = 1.6
local SETTLE_SECONDS = 0.7
-- Putting a good lift's bar back (rerack): the walk in, the dip under it, and the step out, clear of its plates.
local RERACK_WALK_SECONDS = 1.2
local RERACK_DIP_SECONDS = 0.35
local RERACK_DIP_SHARE = 0.6
local RERACK_STEP_OUT_SECONDS = 0.6
local RERACK_STEP_OUT_STUDS = 2.2
local RERACK_BENCH_SECONDS = 0.6
-- Where the walk to the rack ends, rack-local Z, for each lift (then the setup takes over). With a setup animation
-- the bench's walk ends just past the foot of the bench (pad to -3.4), where the lifter turns round to sit on it.
local APPROACH_Z = { Squat = -1.2, Bench = -3.4 }
local SETUP_APPROACH_Z = { Squat = -1.2, Bench = -4.6 }
-- A lifter farther than this from where the setup starts (a warm-up rack's spot) walks there first.
local PRE_WALK_STUDS = 0.4
-- The setup's hand-over to the rep animation (both hold the same pose there), and a beat after it before the command.
local SETUP_HANDOVER_SECONDS = 0.15
local SETUP_SETTLE_SECONDS = 0.3

export type Handle = {
	character: Model,
	lift: string,
	track: AnimationTrack?,
	-- The fail animation, once a missed lift plays one.
	failTrack: AnimationTrack?,
	-- Bumped by every new stage, so an older stage's timer never stops a newer one.
	token: number,
	-- How far the running minigame has got at most (0..1): the lift never goes back down.
	reached: number,
	-- The setup animation while it plays (nil once the rep animation has taken over), and when the lifter is ready.
	setupTrack: AnimationTrack?,
	readyAt: number?,
	-- When the setup takes the bar out of the J-cups (os.clock()).
	barLeavesAt: number?,
}

-- The lift's published setup animation, or nil.
local function setupOf(lift: string): StationAnimationConfig.Setup?
	local setup = StationAnimationConfig.Setups[lift]
	return if setup and setup.id ~= "" then setup else nil
end

local function animatorOf(character: Model): Animator?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		local made = Instance.new("Animator")
		made.Parent = humanoid
		animator = made
	end
	return animator
end

local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Height of the root part's centre above the floor when the character stands.
local function standingHeight(character: Model, root: BasePart): number
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.RigType == Enum.HumanoidRigType.R6 then
		return 3
	end
	return humanoid.HipHeight + root.Size.Y / 2
end

-- Where the character is set up for `lift` at `rack`, in the world, or nil.
local function frameFor(character: Model, root: BasePart, rack: Model, lift: string): CFrame?
	local layout = StationLayout.of(rack)
	if layout == nil then
		return nil
	end
	local floor = StationLayout.floorFrame(rack)
	if lift == "Squat" then
		-- Under the bar in the J-cups, facing the rack (the walk-out comes after: unrack); with a setup animation,
		-- where its walk-out ends.
		local z = if setupOf("Squat") then WALKOUT_Z else SQUAT_UNDER_Z
		return floor * CFrame.new(0, standingHeight(character, root), z) * FACING_RACK
	elseif lift == "Deadlift" then
		-- Behind the floor bar, facing the rack, as at a gym rack.
		local _, standZ = StationLayout.deadliftZ(rack, layout)
		return floor * CFrame.new(0, standingHeight(character, root), standZ) * FACING_RACK
	elseif lift == "Bench" then
		local head = character:FindFirstChild("Head")
		local headUp = if head and head:IsA("BasePart") then root.CFrame:PointToObjectSpace(head.Position).Y else 1.5
		return floor * CFrame.new(0, layout.benchPadTop + root.Size.Z / 2, layout.benchHeadZ - headUp) * LYING
	end
	return nil
end

-- Moves the track from `from` to `to` over `seconds` and holds it there (`seconds` 0: straight to `to`).
local function stage(handle: Handle, from: number, to: number, seconds: number)
	handle.token += 1
	local token = handle.token
	local track = handle.track
	if track == nil then
		return
	end
	track.TimePosition = from
	if to <= from + 1e-3 or seconds <= 0 then
		track.TimePosition = to
		track:AdjustSpeed(0)
		return
	end
	track:AdjustSpeed((to - from) / seconds)
	task.delay(seconds, function()
		if handle.token == token and handle.track then
			handle.track:AdjustSpeed(0)
			handle.track.TimePosition = to
		end
	end)
end

--[[
	Sets `character` up for `lift` at `rack` and starts the lift's animation at
	its setup stage. Holds the character still (anchored). Returns the handle,
	or nil when the rack has no layout or the character no root.
]]
function MeetLiftAnimation.begin(character: Model, rack: Model, lift: string): Handle?
	local root = rootOf(character)
	local frame = root and frameFor(character, root, rack, lift)
	local stages = StationAnimationConfig.MeetStages[lift]
	if root == nil or frame == nil or stages == nil then
		return nil
	end
	-- (Put at the lift's spot further down: at once without a setup animation, or as its setup starts.)
	root.Anchored = true
	character:SetAttribute(LIFT_ATTRIBUTE, lift)
	local rackValue = character:FindFirstChild(RACK_VALUE)
	if rackValue == nil or not rackValue:IsA("ObjectValue") then
		local made = Instance.new("ObjectValue")
		made.Name = RACK_VALUE
		made.Parent = character
		rackValue = made
	end
	(rackValue :: ObjectValue).Value = rack

	local handle: Handle = { character = character, lift = lift, track = nil, failTrack = nil, token = 0, reached = 0 }
	local animator = animatorOf(character)
	local function load(id: string?, name: string): AnimationTrack?
		if animator == nil or id == nil or id == "" then
			return nil
		end
		local animation = Instance.new("Animation")
		animation.Name = name
		animation.AnimationId = id
		local ok, loaded = pcall(function()
			return (animator :: Animator):LoadAnimation(animation)
		end)
		if not ok then
			return nil
		end
		local track = loaded :: AnimationTrack
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = false
		return track
	end
	handle.track = load(StationAnimationConfig.AnimationIds[lift], "MeetLift_" .. lift)
	local setupStage = stages.setup
	-- Into the rep animation's setup pose (held, or played for the deadlift's hinge without a setup animation).
	local function startRep(fade: number)
		local track = handle.track
		if track then
			track:Play(fade, 1, 0)
			stage(handle, setupStage[1], setupStage[2], setupStage[2] - setupStage[1])
		end
	end

	local setup = setupOf(lift)
	local setupTrack = if setup then load(setup.id, "MeetSetup_" .. lift) else nil
	if setup == nil or setupTrack == nil then
		character:PivotTo(frame)
		startRep(FADE_SECONDS)
		return handle
	end
	-- From where they stand to where the setup starts first, when they are not there (a warm-up rack's spot).
	local approach = MeetLiftAnimation.approachFor(rack, lift)
	local walkSeconds = 0
	if approach then
		local here = character:GetPivot().Position
		local away = Vector3.new(here.X - approach.Position.X, 0, here.Z - approach.Position.Z)
		if away.Magnitude > PRE_WALK_STUDS then
			walkSeconds = ComputerLifters.walkSeconds(character, {}, approach)
		end
	end
	handle.setupTrack = setupTrack
	handle.readyAt = os.clock() + walkSeconds + setup.length
	handle.barLeavesAt = os.clock() + walkSeconds + setup.barHeldAt
	-- The bar stays where it rests (the J-cups, the floor) until the setup takes it.
	character:SetAttribute(BAR_HELD_ATTRIBUTE, false)
	task.spawn(function()
		local function current(): boolean
			return handle.setupTrack == setupTrack and character.Parent ~= nil
		end
		if walkSeconds > 0 and approach then
			ComputerLifters.walkBody(character, {}, approach, current)
		end
		if not current() then
			return
		end
		-- The root part goes to the lift's spot and the setup starts in the same step: its first pose stands the body
		-- where the walk ended. (No fade in: fading would slide the body between the two spots.)
		character:PivotTo(frame)
		setupTrack:Play(0)
		-- The rep animation starts now too, all but weightless, held where the setup ends (set at the bar), so every
		-- player's copy is already there at the hand-over. (Started at the hand-over, clients first showed its start,
		-- standing, for a moment: the deadlift stood up and bent down again.)
		local rep = handle.track
		if rep then
			rep:Play(0, 0.001, 0)
			stage(handle, setupStage[2], setupStage[2], 0)
		end
		if setup.barHeldAt < setup.length - SETUP_HANDOVER_SECONDS then
			task.delay(setup.barHeldAt, function()
				if current() then
					character:SetAttribute(BAR_HELD_ATTRIBUTE, true)
				end
			end)
		end
		task.wait(math.max(0, setup.length - SETUP_HANDOVER_SECONDS))
		if not current() then
			return
		end
		-- The rep animation takes over on the same pose.
		if handle.track then
			handle.track:AdjustWeight(1, SETUP_HANDOVER_SECONDS)
		end
		setupTrack:Stop(SETUP_HANDOVER_SECONDS)
		handle.setupTrack = nil
		character:SetAttribute(BAR_HELD_ATTRIBUTE, nil)
		task.delay(SETUP_HANDOVER_SECONDS + 0.1, function()
			setupTrack:Destroy()
		end)
	end)
	return handle
end

--[[
	Where the walk to the rack ends for `lift` (a floor point facing the rack),
	walking straight in from the entrance: in front of the bar for squat, at
	the foot of the bench for bench, behind the floor bar for deadlift. Nil
	when the rack has no layout.
]]
function MeetLiftAnimation.approachFor(rack: Model, lift: string): CFrame?
	local layout = StationLayout.of(rack)
	if layout == nil then
		return nil
	end
	local _, deadliftStandZ = StationLayout.deadliftZ(rack, layout)
	local z = (if setupOf(lift) then SETUP_APPROACH_Z[lift] else APPROACH_Z[lift]) or deadliftStandZ
	return StationLayout.floorFrame(rack) * CFrame.new(0, 0, z) * FACING_RACK
end

--[[
	The part of the lift before the referee's start command (GAME_DESIGN §37.5),
	played now; returns how long it takes in seconds. Squat: unrack, then step
	slowly back from the rack with the bar on the back and settle into the
	stance. Bench: unrack and get steady. Deadlift: hinge down to the bar and
	set (the setup already did it).
]]
function MeetLiftAnimation.unrack(handle: Handle?): number
	if handle == nil then
		return 0
	end
	if handle.readyAt then
		-- The setup animation does it all; the command comes once it is over.
		return math.max(0, handle.readyAt - os.clock()) + SETUP_SETTLE_SECONDS
	end
	if handle.lift == "Bench" then
		return BENCH_STEADY_SECONDS
	elseif handle.lift ~= "Squat" then
		return SETTLE_SECONDS
	end
	local character = handle.character
	local root = rootOf(character)
	if root == nil then
		return 0
	end
	local token = handle.token
	local start = character:GetPivot()
	task.spawn(function()
		task.wait(UNRACK_HOLD_SECONDS)
		-- Step by step: each step moves back, eased, then a short stop, like a real walk-out.
		local stepSeconds = WALKOUT_SECONDS / WALKOUT_STEPS
		local stepLength = (SQUAT_UNDER_Z - WALKOUT_Z) / WALKOUT_STEPS
		for step = 1, WALKOUT_STEPS do
			local elapsed = 0
			local moveSeconds = stepSeconds * 0.7
			while elapsed < moveSeconds do
				if handle.token ~= token or not character.Parent then
					return
				end
				elapsed = math.min(moveSeconds, elapsed + task.wait())
				local u = elapsed / moveSeconds
				local eased = u * u * (3 - 2 * u)
				-- Backwards = along the lifter's own -LookVector (they face the rack).
				character:PivotTo(start * CFrame.new(0, 0, ((step - 1) + eased) * stepLength))
			end
			task.wait(stepSeconds * 0.3)
		end
	end)
	return UNRACK_HOLD_SECONDS + WALKOUT_SECONDS + SETTLE_SECONDS
end

-- Seconds until the bar comes out of the J-cups (its sound): later with a setup animation, now without one.
function MeetLiftAnimation.unrackSoundIn(handle: Handle?): number
	local at = handle and handle.barLeavesAt
	return if at then math.max(0, at - os.clock()) else 0
end

--[[
	Minigame phase `index` started and can run `seconds`. Moves through its
	stretch over that time, or, when `driven` (a player's first phase, GAME_DESIGN
	§37.5), waits at its start for MeetLiftAnimation.progress to move it.
]]
function MeetLiftAnimation.phase(handle: Handle?, index: number, seconds: number?, driven: boolean?)
	local stages = handle and StationAnimationConfig.MeetStages[handle.lift]
	local stretch = stages and stages.phases[index]
	if handle == nil or stretch == nil then
		return
	end
	handle.reached = 0
	if driven then
		stage(handle, stretch[1], stretch[1], 0)
	else
		stage(handle, stretch[1], stretch[2], math.max(0.3, seconds or 1))
	end
end

--[[
	The running minigame (phase `index`) is `fraction` (0..1) of the way through
	(MeetLiftProgress): the lift moves to that point of the phase's stretch, never
	back (user 2026-11-02: "If my progress bar goes down just make my character
	stand still"). Short glides between the updates keep it smooth.
]]
function MeetLiftAnimation.progress(handle: Handle?, index: number, fraction: number)
	local stages = handle and StationAnimationConfig.MeetStages[handle.lift]
	local stretch = stages and stages.phases[index]
	local track = handle and handle.track
	if handle == nil or stretch == nil or track == nil or fraction <= handle.reached then
		return
	end
	handle.reached = math.min(1, fraction)
	local target = stretch[1] + (stretch[2] - stretch[1]) * handle.reached
	stage(handle, track.TimePosition, target, PROGRESS_GLIDE_SECONDS)
end

--[[
	The lift is over. After a good lift: the finish (stand up, press, lower).
	After a miss: `fail` (GAME_DESIGN §37.5 "The fail animations"; the caller
	picks it, so a player's own unlocked fail can replace the default). Its
	animation cross-fades in from where the lift stopped; without a published
	animation the lifter holds there. Either way the bar stays in the hands
	until the fail's release, then goes back to its rest (the spotters take it).
	Returns how long the finish or the fail lasts, in seconds.
]]
function MeetLiftAnimation.finish(handle: Handle?, good: boolean, fail: StationAnimationConfig.Fail?): number
	local stages = handle and StationAnimationConfig.MeetStages[handle.lift]
	if handle == nil or stages == nil then
		return 0
	end
	if not good then
		handle.token += 1
		local token = handle.token
		local character = handle.character
		local track = handle.track
		if track then
			track:AdjustSpeed(0)
		end
		if fail == nil then
			return 0
		end
		character:SetAttribute(BAR_HELD_ATTRIBUTE, true)
		task.delay(fail.release, function()
			if handle.token == token and character.Parent then
				character:SetAttribute(BAR_HELD_ATTRIBUTE, false)
			end
		end)
		local animator = animatorOf(character)
		if animator and fail.id ~= "" then
			local animation = Instance.new("Animation")
			animation.Name = "MeetFail_" .. handle.lift
			animation.AnimationId = fail.id
			local ok, loaded = pcall(function()
				return (animator :: Animator):LoadAnimation(animation)
			end)
			if ok then
				local failTrack = loaded :: AnimationTrack
				failTrack.Priority = Enum.AnimationPriority.Action
				failTrack.Looped = false
				failTrack:Play(FAIL_FADE_SECONDS)
				handle.failTrack = failTrack
				-- Holds its last frame (standing again) until the walk back stops it.
				failTrack.Stopped:Once(function()
					if handle.failTrack == failTrack then
						failTrack:Play(0, 1, 0)
						failTrack.TimePosition = math.max(0, fail.length - 0.05)
					end
				end)
				if track then
					track:Stop(FAIL_FADE_SECONDS)
				end
			end
		end
		return fail.length
	end
	local finish = stages.finish
	stage(handle, finish[1], finish[2], finish[2] - finish[1])
	return finish[2] - finish[1]
end

--[[
	After a good squat or bench the bar goes back in the rack with the lifter clear
	of it, so it never passes through them (user 2026-11-07).
	  Squat  they walk it back in, let it down into the J-cups, dip under it and step out.
	  Bench  it glides up into the J-cups while they stay lying under it.
	  Deadlift  nothing: it is already on the floor in front of them.
	Returns the seconds until the bar is in the rack, and until the lifter can go.
]]
function MeetLiftAnimation.rerack(handle: Handle?): (number, number)
	if handle == nil or handle.lift == "Deadlift" then
		return 0, 0
	end
	local character = handle.character
	if handle.lift == "Bench" then
		character:SetAttribute(BAR_HELD_ATTRIBUTE, false)
		return 0, RERACK_BENCH_SECONDS
	end
	local stages = StationAnimationConfig.MeetStages.Squat
	local dip = stages.phases[1]
	handle.token += 1
	local token = handle.token
	-- Moves the character `distance` backwards (its own +Z) over `seconds`, eased.
	local function move(distance: number, seconds: number)
		local start = character:GetPivot()
		local elapsed = 0
		while elapsed < seconds do
			if handle.token ~= token or not character.Parent then
				return
			end
			elapsed = math.min(seconds, elapsed + task.wait())
			local u = elapsed / seconds
			character:PivotTo(start * CFrame.new(0, 0, distance * (u * u * (3 - 2 * u))))
		end
	end
	character:SetAttribute(BAR_HELD_ATTRIBUTE, true)
	task.spawn(function()
		move(WALKOUT_Z - SQUAT_UNDER_Z, RERACK_WALK_SECONDS)
		if handle.token ~= token or not character.Parent then
			return
		end
		character:SetAttribute(BAR_HELD_ATTRIBUTE, false)
		-- Down under the bar (part of the way into the squat), then back out from under it.
		stage(handle, dip[1], dip[1] + (dip[2] - dip[1]) * RERACK_DIP_SHARE, RERACK_DIP_SECONDS)
		token = handle.token
		task.wait(RERACK_DIP_SECONDS)
		move(RERACK_STEP_OUT_STUDS, RERACK_STEP_OUT_SECONDS)
	end)
	return RERACK_WALK_SECONDS, RERACK_WALK_SECONDS + RERACK_DIP_SECONDS + RERACK_STEP_OUT_SECONDS
end

-- Ends the lift: stops the animation and takes the marks off. Leaves the character where it is (still anchored).
function MeetLiftAnimation.stop(handle: Handle?)
	if handle == nil then
		return
	end
	handle.token += 1
	local track, failTrack, setupTrack = handle.track, handle.failTrack, handle.setupTrack
	handle.track, handle.failTrack, handle.setupTrack = nil, nil, nil
	if setupTrack then
		setupTrack:Stop(FADE_SECONDS)
		setupTrack:Destroy()
	end
	if track then
		track:Stop(FADE_SECONDS)
		track:Destroy()
	end
	if failTrack then
		failTrack:Stop(FADE_SECONDS)
		failTrack:Destroy()
	end
	local character = handle.character
	if character.Parent then
		character:SetAttribute(LIFT_ATTRIBUTE, nil)
		character:SetAttribute(BAR_HELD_ATTRIBUTE, nil)
		local rackValue = character:FindFirstChild(RACK_VALUE)
		if rackValue then
			rackValue:Destroy()
		end
	end
end

return MeetLiftAnimation
