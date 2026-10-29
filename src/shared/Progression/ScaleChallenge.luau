--!strict
--[[
	ScaleChallenge
	Shared / Progression

	The Competition Scale challenge modifier (GAME_DESIGN.md section 33.4): how many
	extra base-difficulty points a meet attempt carries for being above what the
	lifter has proven. The numbers live in ScaleChallengeConfig.

	Pure: no player data, no services. LiftAttemptService passes the attempt weight,
	the lift's Competition Scale and whether the attempt is a meet attempt in the
	ModifierRegistry context, and this module's source turns that into one
	BaseDifficulty modifier. Scale only ever changes how hard an attempt feels,
	never whether it is allowed (section 33.5).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ScaleChallengeConfig = require(Shared:WaitForChild("Config"):WaitForChild("ScaleChallengeConfig"))
local ModifiersFolder = Shared:WaitForChild("Modifiers")
local ModifierSet = require(ModifiersFolder:WaitForChild("ModifierSet"))
local ModifierChannel = require(ModifiersFolder:WaitForChild("ModifierChannel"))
local ModifierRegistry = require(ModifiersFolder:WaitForChild("ModifierRegistry"))

local ScaleChallenge = {}

-- The ModifierRegistry source name, also the modifier's `source` for tracing.
ScaleChallenge.SourceName = "ScaleChallenge"

--[[
	The extra base-difficulty points for an attempt of `attemptWeightKg` against a
	Competition Scale of `competitionScaleKg`. 0 or nil Scale means unproven.
	0 at or below the Scale, rising evenly to the cap at FullRatio.
]]
function ScaleChallenge.bonusFor(attemptWeightKg: number, competitionScaleKg: number?): number
	if typeof(attemptWeightKg) ~= "number" or attemptWeightKg ~= attemptWeightKg or attemptWeightKg <= 0 then
		return 0
	end
	local scale = competitionScaleKg
	if scale == nil or scale ~= scale or scale <= 0 then
		return ScaleChallengeConfig.UnprovenBonus
	end
	local ratio = attemptWeightKg / scale
	if ratio <= 1 then
		return 0
	end
	local share = math.min((ratio - 1) / (ScaleChallengeConfig.FullRatio - 1), 1)
	return ScaleChallengeConfig.MaxBonus * share
end

--[[
	The ModifierRegistry source: one BaseDifficulty "Add" modifier for a meet
	attempt, nothing otherwise (practice lifts, training, a half-built context).
]]
function ScaleChallenge.producer(context: ModifierRegistry.ModifierContext): ModifierSet.ModifierSet
	local set = ModifierSet.create()
	if context.isCompetition ~= true or typeof(context.attemptWeightKg) ~= "number" then
		return set
	end
	local bonus = ScaleChallenge.bonusFor(context.attemptWeightKg :: number, context.competitionScaleKg)
	if bonus > 0 then
		ModifierSet.add(set, {
			channel = ModifierChannel.BaseDifficulty,
			operation = "Add",
			value = bonus,
			source = ScaleChallenge.SourceName,
		})
	end
	return set
end

return ScaleChallenge
