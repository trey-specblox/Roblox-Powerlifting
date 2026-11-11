--!strict
--[[
	MeetLiftMoment
	Client / Meet

	"Your moment" (GAME_DESIGN §37.5, user 2026-11-05): a turn on the platform at a
	meet against other players feels like an event, on the lifter's own screen only:
		Ready    the card comes up (name, lift, attempt, weight, what is at stake) and
		         the camera follows the walk out, low behind the lifter
		at the bar  the camera glides to the lift's shot and slowly pushes in
		Result   the crowd's answer is louder than usual (MeetSoundController.expectRoar)
		walk back  the camera goes back to normal
	The higher the attempt's stakes level (LocalMeetConfig.StakesBuild), the further the
	camera pushes in.
	At State and up the coach's ritual (MeetRitualShot, user 2026-11-11) carries on into the
	walk out with its own shots, hard cuts and handheld (LocalMeetConfig.Ritual): low behind
	the lifter toward the platform, then low from the side; the film look (MeetCinema) ends
	and the card comes up at the bar. Skipped, the walk out gets the plain camera.
	The crowd yelling during the lift comes from the server, for every lifter
	(LocalMeetService crowdBehind).

	LocalMeetController passes it the meet's state. Display only: it decides and
	saves nothing, and takes no part in the lift. The shots and timings are in
	LocalMeetConfig.LiftMoment.

	PERFORMANCE: one small card, made once. Each frame while a turn runs: one camera
	move, and one ray during the walk out (so the camera stays out of walls).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LocalMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("LocalMeetConfig"))
local MockMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("MockMeetRemotes"))

local MeetCinema = require(script.Parent:WaitForChild("MeetCinema"))
local MeetSoundController = require(script.Parent:WaitForChild("MeetSoundController"))
local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours

local MeetLiftMoment = {}

local SETTINGS = LocalMeetConfig.LiftMoment
local RITUAL = LocalMeetConfig.Ritual
local RENDER_NAME = "MeetLiftMoment"
-- The attribute and value MeetLiftAnimation puts on a character while it is set up at a bar.
local LIFT_ATTRIBUTE = "MeetLift"
local RACK_VALUE = "MeetRack"
local CARD_SIZE = Vector2.new(480, 130)
local CARD_SHOWN = UDim2.fromOffset(0, 0)
-- Below the bottom of the screen: the card's place is about 170 px up from it.
local CARD_HIDDEN = UDim2.fromOffset(0, 260)
-- A part this see-through doesn't stop the camera (the hall's hidden walls).
local CLEAR_PART = 0.95

type Stage = "Walk" | "Set" | "Hold" | "Release"
type Run = {
	stage: Stage,
	lift: string,
	stageStart: number,
	-- The shot at the bar, in the world, once the lifter is there.
	eye: Vector3?,
	look: Vector3?,
	rayParams: RaycastParams,
	-- How far the slow push in goes on this attempt.
	pushInShare: number,
	-- The walk out gets the coach's ritual's shots (State and up, not skipped), and which one is on.
	ritualWalk: boolean,
	walkShot: string?,
	-- The card waits for the bar while the ritual's shots run.
	cardState: MockMeetRemotes.MeetState?,
}

local run: Run? = nil

type Card = {
	panel: Frame,
	tag: TextLabel,
	name: TextLabel,
	kg: TextLabel,
	stakes: TextLabel,
	token: number,
}
local card: Card? = nil

local function kgText(kg: number): string
	return if kg == math.floor(kg) then string.format("%d", kg) else string.format("%.1f", kg)
end

local function buildCard(): Card
	local gui = Instance.new("ScreenGui")
	gui.Name = "MeetLiftCard"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	UIStyle.fitToScreen(gui)

	-- Stays in place and carries the screen fit; the panel inside it slides.
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.new(0.5, -CARD_SIZE.X / 2, 1, -170)
	holder.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	holder.Parent = gui

	local panel, body = UIStyle.panel(holder, "Card", CARD_HIDDEN, UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y))
	panel.Visible = false
	local tag = UIStyle.titleTag(panel, "Tag", "", UDim2.fromOffset(-14, -24), UDim2.fromOffset(300, 38))
	local name = UIStyle.label(body, "Name", UDim2.fromOffset(20, 22), UDim2.fromOffset(280, 44), C.white, UIStyle.heading())
	local kg = UIStyle.label(body, "Kg", UDim2.fromOffset(304, 20), UDim2.fromOffset(156, 50), C.yellow, UIStyle.heading(),
		Enum.TextXAlignment.Right)
	local stakes = UIStyle.label(body, "Stakes", UDim2.fromOffset(20, 76), UDim2.fromOffset(440, 32), C.yellow,
		UIStyle.heading())

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return { panel = panel, tag = tag, name = name, kg = kg, stakes = stakes, token = 0 }
end

local function showCard(state: MockMeetRemotes.MeetState)
	local built = card or buildCard()
	card = built
	built.token += 1
	built.tag.Text = string.format("%s  ·  ATTEMPT %d", string.upper(state.lift or ""), state.attemptNumber or 1)
	built.name.Text = Players.LocalPlayer.DisplayName
	built.kg.Text = kgText(state.declaredKg or 0) .. " KG"
	local stakes = state.stakes
	built.stakes.Text = stakes or ""
	built.stakes.Visible = stakes ~= nil
	-- With no stakes line the name and weight sit in the middle of the card.
	built.name.Position = UDim2.fromOffset(20, if stakes then 22 else 40)
	built.kg.Position = UDim2.fromOffset(304, if stakes then 20 else 38)
	built.panel.Position = CARD_HIDDEN
	built.panel.Visible = true
	TweenService:Create(built.panel, TweenInfo.new(SETTINGS.CardSlideSeconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Position = CARD_SHOWN }):Play()
end

local function hideCard()
	local built = card
	if built == nil or not built.panel.Visible then
		return
	end
	built.token += 1
	local token = built.token
	local tween = TweenService:Create(built.panel, TweenInfo.new(SETTINGS.CardSlideSeconds, Enum.EasingStyle.Quart,
		Enum.EasingDirection.In), { Position = CARD_HIDDEN })
	tween.Completed:Once(function()
		if built.token == token then
			built.panel.Visible = false
		end
	end)
	tween:Play()
end

local function rootOf(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- The way the part faces, along the floor. Lying on a bench it faces up, so then the camera's own way instead.
local function flatLook(root: BasePart, camera: Camera): Vector3
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.3 then
		local own = camera.CFrame.LookVector
		flat = Vector3.new(own.X, 0, own.Z)
	end
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
end

-- As far along from `from` to `to` as the camera can go without passing through something solid and visible.
local function clearOf(from: Vector3, to: Vector3, params: RaycastParams): Vector3
	local ignored = table.clone(params.FilterDescendantsInstances)
	for _ = 1, 4 do
		local hit = Workspace:Raycast(from, to - from, params)
		if hit == nil then
			return to
		end
		if hit.Instance.Transparency < CLEAR_PART then
			return hit.Position + (from - to).Unit * 0.5
		end
		table.insert(ignored, hit.Instance)
		params.FilterDescendantsInstances = ignored
	end
	return to
end

-- The shot at the bar, in the world (LocalMeetConfig.LiftMoment.Shots are rack-local), or nil without a rack.
local function shotAtBar(character: Model, lift: string): (Vector3?, Vector3?)
	local value = character:FindFirstChild(RACK_VALUE)
	local rack = if value and value:IsA("ObjectValue") then value.Value else nil
	local shot = SETTINGS.Shots[lift]
	if rack == nil or not rack:IsA("Model") or shot == nil then
		return nil, nil
	end
	local frame = rack:GetPivot()
	return frame:PointToWorldSpace(shot.eye), frame:PointToWorldSpace(shot.look)
end

local function enterStage(current: Run, stage: Stage)
	current.stage = stage
	current.stageStart = os.clock()
end

-- Ends the turn's camera. `restore`: the camera goes back on the player (false: something else takes it straight over).
local function finish(restore: boolean)
	local current = run
	if current == nil then
		return
	end
	run = nil
	RunService:UnbindFromRenderStep(RENDER_NAME)
	hideCard()
	if current.ritualWalk then
		MeetCinema.close()
	end
	if restore then
		local camera = Workspace.CurrentCamera
		local humanoid = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- The coach's ritual skipped on the way out, or done at the bar: the film look ends and the card comes up.
local function endRitual(current: Run)
	current.ritualWalk = false
	MeetCinema.close()
	local cardState = current.cardState
	if cardState then
		current.cardState = nil
		showCard(cardState)
	end
end

local function step(dt: number)
	local current = run
	if current == nil then
		return
	end
	local camera = Workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = rootOf(character)
	if character == nil or root == nil then
		finish(true)
		return
	end
	local atBar = character:GetAttribute(LIFT_ATTRIBUTE) ~= nil
	local elapsed = os.clock() - current.stageStart

	if current.ritualWalk and not MeetCinema.walkShots then
		endRitual(current)
	end
	if current.stage == "Walk" and atBar then
		current.eye, current.look = shotAtBar(character, current.lift)
		if current.eye then
			enterStage(current, "Set")
			elapsed = 0
			if current.ritualWalk then
				endRitual(current)
			end
		end
	elseif current.stage == "Hold" and (not atBar or elapsed > SETTINGS.HoldMaxSeconds) then
		enterStage(current, "Release")
		elapsed = 0
	end

	local eye: Vector3
	local look: Vector3
	local rate: number
	if current.stage == "Walk" and current.ritualWalk then
		-- The coach's ritual's walk out: low behind them toward the lit platform, then low from in front and to one side.
		local ahead = flatLook(root, camera)
		local shot = if elapsed < RITUAL.FollowSeconds then "Follow" else "Side"
		local from = root.Position + Vector3.new(0, 1, 0)
		if shot == "Follow" then
			eye = root.Position - ahead * RITUAL.Walk.FollowBack + Vector3.new(0, RITUAL.Walk.FollowUp, 0)
			look = root.Position + ahead * RITUAL.Walk.FollowAhead + Vector3.new(0, 1.6, 0)
		else
			-- In front and to one side, low, looking back at them as they come (clear of the side referees).
			local side = ahead:Cross(Vector3.yAxis)
			eye = root.Position + side * RITUAL.Walk.SideOut + ahead * RITUAL.Walk.SideAhead + Vector3.new(0, RITUAL.Walk.SideUp, 0)
			look = root.Position + Vector3.new(0, RITUAL.Walk.SideLookUp, 0)
		end
		eye = clearOf(from, eye, current.rayParams)
		MeetCinema.focus((eye - root.Position).Magnitude)
		local target = CFrame.lookAt(eye, look) * MeetCinema.handheld(os.clock())
		-- A hard cut into each shot, then it rides with them.
		if shot ~= current.walkShot then
			current.walkShot = shot
			camera.CFrame = target
		else
			camera.CFrame = camera.CFrame:Lerp(target, 1 - math.exp(-RITUAL.Walk.Rate * dt))
		end
		return
	elseif current.stage == "Walk" then
		local ahead = flatLook(root, camera)
		local from = root.Position + Vector3.new(0, 1, 0)
		eye = clearOf(from, root.Position - ahead * SETTINGS.WalkBack + Vector3.new(0, SETTINGS.WalkUp, 0), current.rayParams)
		look = root.Position + ahead * SETTINGS.WalkAhead + Vector3.new(0, 1.5, 0)
		rate = SETTINGS.WalkRate
	elseif current.stage == "Release" then
		if elapsed >= SETTINGS.ReleaseSeconds then
			finish(true)
			return
		end
		local ahead = flatLook(root, camera)
		eye = root.Position - ahead * SETTINGS.ReleaseBack + Vector3.new(0, SETTINGS.ReleaseUp, 0)
		look = root.Position + Vector3.new(0, 1.5, 0)
		rate = SETTINGS.ReleaseRate
	else
		look = current.look :: Vector3
		if current.stage == "Hold" then
			-- The lights: the camera stays where the push in got to.
			eye = camera.CFrame.Position
		else
			-- The slow push in, while the lift runs.
			local pushed = math.min(1, elapsed / SETTINGS.PushInSeconds) * current.pushInShare
			eye = (current.eye :: Vector3):Lerp(look, pushed)
		end
		rate = SETTINGS.SetRate
	end
	camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(eye, look), 1 - math.exp(-rate * dt))
end

-- The lifter's turn starts (the Ready state, as they walk out).
local function begin(state: MockMeetRemotes.MeetState)
	-- The coach's ritual carries on into the walk out (State and up, not skipped). (Read before finish, which ends the
	-- film look of an earlier turn still running.)
	local ritualWalk = state.walkOutShot == true and MeetCinema.walkShots and MeetCinema.isOpen()
	finish(false)
	local character = Players.LocalPlayer.Character
	if character == nil or state.lift == nil then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	local shares = LocalMeetConfig.StakesBuild.PushInShare
	run = { stage = "Walk", lift = state.lift, stageStart = os.clock(), rayParams = params,
		pushInShare = shares[state.stakesLevel or 1] or shares[1], ritualWalk = ritualWalk, walkShot = nil,
		cardState = if ritualWalk then state else nil }
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, step)
	if not ritualWalk then
		showCard(state)
	end
end

-- Every state of the meet the player is lifting in (LocalMeetController).
function MeetLiftMoment.onState(state: MockMeetRemotes.MeetState)
	if state.phase == "Ready" then
		if state.autoLift then
			begin(state)
		end
		return
	end
	local current = run
	if current == nil then
		return
	end
	if state.phase == "Lifting" then
		hideCard()
	elseif state.phase == "Result" then
		hideCard()
		MeetSoundController.expectRoar()
		-- Lights before the lifter ever reached the bar (a timed-out walk): nothing to hold on.
		enterStage(current, if current.stage == "Set" then "Hold" else "Release")
	elseif current.stage ~= "Release" then
		enterStage(current, "Release")
	end
end

-- Ends it at once: the player left the meet or the awards take the camera. `restore` as in finish.
function MeetLiftMoment.stop(restore: boolean)
	finish(restore)
end

return MeetLiftMoment
