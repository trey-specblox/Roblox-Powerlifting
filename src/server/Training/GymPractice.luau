--!strict
--[[
	GymPractice
	Server / Training

	Practice lifts at a gym training rack (user 2026-11-05: "you could also just
	practice specific lifts and numbers just to do it", in the gym as well as the
	warm-up room). GAME_DESIGN §34.3.

	It IS the warm-up room's practice: its own LocalMeetWarmUp, with no prompts of
	its own, so the lift, the weight rules, the real minigames, the animations, the
	bar sounds and the card on screen are the same code. PRACTICE ONLY: nothing is
	saved (no CN, no technique, no Scale, no records, no allowance).

	TrainingStationService owns the rack: it holds the player's session (state
	"Practising", which earns nothing), so one player per rack and every way of
	losing a rack (death, leaving, moving away) work as they do for training. It
	calls enter when the player picks Practice Lifts, and stop when the rack is lost.
	LEAVE RACK on the card comes back to it through hooks.onLeft.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LocalMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("LocalMeetConfig"))
local LocalMeetRemotes = require(Shared:WaitForChild("Meet"):WaitForChild("LocalMeetRemotes"))

local ServerFolder = script.Parent.Parent
local LiftAttemptService = require(ServerFolder:WaitForChild("Lifting"):WaitForChild("LiftAttemptService"))
local LocalMeetWarmUp = require(ServerFolder:WaitForChild("Meet"):WaitForChild("LocalMeetWarmUp"))
local StationLayout = require(script.Parent:WaitForChild("StationLayout"))

local GymPractice = {}

local CARD_TITLE = "PRACTICE"

export type Hooks = {
	notify: (player: Player, message: string) -> (),
	-- The player left practice from the card: TrainingStationService frees their rack.
	onLeft: (player: Player) -> (),
}

local practice: LocalMeetWarmUp.WarmUp? = nil
local lastPress: { [Player]: number } = {}
-- A number for each rack, handed out as racks are first used.
local rackNumbers: { [Model]: number } = {}
local rackCount = 0

local function bodyOf(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or root == nil or not root:IsA("BasePart") or humanoid == nil then
		return nil, nil, nil
	end
	return character, root, humanoid
end

local function standAt(player: Player, spot: CFrame, anchored: boolean)
	local character, root, humanoid = bodyOf(player)
	if character == nil or root == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	root.Anchored = anchored
	local height = if humanoid.RigType == Enum.HumanoidRigType.R6 then 3 else humanoid.HipHeight + root.Size.Y / 2
	character:PivotTo(spot * CFrame.new(0, height, 0))
end

local function release(player: Player)
	local _, root = bodyOf(player)
	if root then
		root.Anchored = false
	end
end

--[[
	Why this player can't practice at this rack right now, or nil if they can. Asked
	before anything about their training changes.
]]
function GymPractice.refusal(player: Player, rack: Instance): string?
	if not rack:IsA("Model") or StationLayout.of(rack) == nil then
		return "This rack can't be used for practice."
	end
	local _, _, humanoid = bodyOf(player)
	if humanoid == nil or humanoid.Health <= 0 then
		return "You can't practice right now."
	end
	if LiftAttemptService.isAttemptActive(player) then
		return "Finish your lift first."
	end
	return nil
end

--[[
	Steps the player up to `rack` and shows the card. Returns whether they are on it.
	They stand clear of the rack's floor bar, facing the rack, and walk off from there.
]]
function GymPractice.enter(player: Player, rack: Model): boolean
	local current = practice
	local layout = StationLayout.of(rack)
	if current == nil or layout == nil then
		return false
	end
	local number = rackNumbers[rack]
	if number == nil then
		rackCount += 1
		number = rackCount
		rackNumbers[rack] = number
	end
	local spot = StationLayout.floorFrame(rack) * CFrame.new(0, 0, layout.exitZ) * CFrame.Angles(0, math.pi, 0)
	current.stepUp(player, {
		index = number,
		rack = rack,
		liftSpot = spot,
		stepOffSpot = spot,
		point = rack.PrimaryPart :: BasePart,
	})
	return current.isWarmingUp(player)
end

-- Takes the player off practice, stopping any lift. Safe to call when they are not practising.
function GymPractice.stop(player: Player)
	local current = practice
	if current then
		current.stop(player, false)
	end
end

function GymPractice.start(hooks: Hooks)
	if practice then
		return
	end
	local set = LocalMeetRemotes.createOnServer(ReplicatedStorage)
	practice = LocalMeetWarmUp.new({}, set, {
		canUse = function(player: Player): (boolean, string?)
			local _, _, humanoid = bodyOf(player)
			return humanoid ~= nil and humanoid.Health > 0 and not LiftAttemptService.isAttemptActive(player), nil
		end,
		standAt = standAt,
		release = release,
		notify = hooks.notify,
		pressAllowed = function(player: Player): boolean
			local time = os.clock()
			if time - (lastPress[player] or 0) < LocalMeetConfig.ButtonCooldownSeconds then
				return false
			end
			lastPress[player] = time
			return true
		end,
		onLeft = hooks.onLeft,
		cardTitle = CARD_TITLE,
	})
	-- The running minigame's progress moves the character's lift (MeetLiftProgress). Visual only.
	set.liftProgress.OnServerEvent:Connect(function(player: Player, fraction: unknown)
		local current = practice
		if current and typeof(fraction) == "number" and fraction == fraction then
			current.progress(player, math.clamp(fraction, 0, 1))
		end
	end)
end

-- The player left the game: forgets their button press.
function GymPractice.forget(player: Player)
	lastPress[player] = nil
end

return GymPractice
