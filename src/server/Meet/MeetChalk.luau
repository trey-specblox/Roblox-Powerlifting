--!strict
--[[
	MeetChalk
	Server / Meet

	Plays the chalking-up animations at a meet (GAME_DESIGN §37.5, user 2026-11-06):
	the lifter at the chalk stand while they choose a weight, and their coach,
	behind them chalking their upper back on squat or in front of them talking on
	bench and deadlift. Ids and timings: LocalMeetConfig.Chalk.

	Played by the server, so everyone in the hall sees the same thing, as with the
	lifts (MeetLiftAnimation). Visual only: nothing here decides anything. Each
	round loads and later destroys its tracks, so nothing builds up over a meet.
]]

local FADE_SECONDS = 0.25

local MeetChalk = {}

-- Plays looped animation `id` on a figure (a player, a computer lifter or a coach). Nil when it can't: not R15, no id.
function MeetChalk.play(figure: Model?, id: string): AnimationTrack?
	local humanoid = figure and figure:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.RigType ~= Enum.HumanoidRigType.R15 or id == "" then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		local made = Instance.new("Animator")
		made.Parent = humanoid
		animator = made
	end
	local animation = Instance.new("Animation")
	animation.Name = "MeetChalk"
	animation.AnimationId = id
	local ok, loaded = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if not ok then
		return nil
	end
	local track = loaded :: AnimationTrack
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play(FADE_SECONDS)
	return track
end

function MeetChalk.stop(track: AnimationTrack?)
	if track then
		track:Stop(FADE_SECONDS)
		task.delay(FADE_SECONDS + 0.05, function()
			track:Destroy()
		end)
	end
end

return MeetChalk
