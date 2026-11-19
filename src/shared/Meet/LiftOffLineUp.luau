--!strict
--[[
	LiftOffLineUp
	Shared / Meet

	Where tied lifters stand for the lift-off's judge (GAME_DESIGN §39 "Lift-off cinematic"; user 2026-11-18: "make sure
	they are shoulder to shoulder not inside each other"): side by side behind their platform's curtain, facing it, each
	taking their OWN body's width with a little air to the next. They stood a fixed 3.4 studs apart before, whatever
	their size, and the bodies run from 2.74 to 4.31 wide.

	Pure sums (no instances, nothing remembered), so NationalsScenes uses it for the meet and a Studio check can run the
	very same maths on test bodies. The settings are NationalsConfig.LiftOffScene.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NationalsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("NationalsConfig"))

local LIFT_OFF = NationalsConfig.LiftOffScene

local LiftOffLineUp = {}

local function flat(v: Vector3): Vector3
	local level = Vector3.new(v.X, 0, v.Z)
	return if level.Magnitude > 1e-4 then level.Unit else Vector3.new(0, 0, -1)
end

--[[
	The spots for lifters of these body `widths` (studs, hand to hand), and where the judge stops in front of them,
	facing them. `curtain`: the spot right behind the curtain's split, facing the stage. `outer`: toward the stage's
	outer side, away from the chalk stand and the coach.

	Spot 1 is the one nearest the chalk stand, the last the furthest out: hand the spots out in the order the lifters
	sit along the bench and no two walks cross. Neighbours stand (their two half widths + ShoulderGapStuds) apart. The
	line's middle sits OuterShiftStuds out from the split, further when the line is long, so its inner end never comes
	nearer the chalk stand's side than InnerLimitStuds from the split.
]]
function LiftOffLineUp.spots(curtain: CFrame, outer: Vector3, widths: { number }): ({ CFrame }, CFrame)
	local toStage = flat(curtain.LookVector)
	local out = flat(outer)
	local gap = LIFT_OFF.ShoulderGapStuds
	local total = -gap
	for _, width in ipairs(widths) do
		total += width + gap
	end
	local shift = math.max(LIFT_OFF.OuterShiftStuds, total / 2 - LIFT_OFF.InnerLimitStuds)
	local centre = curtain.Position - toStage * LIFT_OFF.LiftersBehindStuds + out * shift
	local spots: { CFrame } = {}
	local edge = -total / 2
	for _, width in ipairs(widths) do
		local at = centre + out * (edge + width / 2)
		table.insert(spots, CFrame.lookAt(at, at + toStage))
		edge += width + gap
	end
	local judgeAt = centre + toStage * LIFT_OFF.JudgeAheadStuds
	return spots, CFrame.lookAt(judgeAt, judgeAt - toStage)
end

return LiftOffLineUp
