--!strict
--[[
	MeetAnimationPreload
	Client / Meet

	Downloads every meet animation in the background as the game starts, so the first time one plays it is already here.
	(Studio 2026-11-15: the first rerack of a session showed the standing idle pose for about a third of a second between
	the lift and the rerack, while the rerack was still downloading: the arms swung down and back up, the "elbows and
	shoulders doing a full 360" the user saw at the bar.) Animations are small files; this loads about a hundred of them
	a few at a time and never waits on any. Nothing is shown or sent anywhere.
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local StationAnimationConfig = require(Config:WaitForChild("StationAnimationConfig"))
local LocalMeetConfig = require(Config:WaitForChild("LocalMeetConfig"))
local CelebrationConfig = require(Config:WaitForChild("CelebrationConfig"))
local EntranceConfig = require(Config:WaitForChild("EntranceConfig"))
local EmoteConfig = require(Config:WaitForChild("EmoteConfig"))
local NationalsConfig = require(Config:WaitForChild("NationalsConfig"))

local MeetAnimationPreload = {}

-- How many load together.
local BATCH = 8

-- Every meet animation id, the ones a lift needs first (set-ups, lifts, reracks, fails) at the front.
local function allIds(): { string }
	local ids: { string } = {}
	local seen: { [string]: boolean } = {}
	local function add(id: string?)
		if typeof(id) == "string" and id ~= "" and not seen[id] then
			seen[id] = true
			table.insert(ids, id)
		end
	end
	for _, id in pairs(StationAnimationConfig.AnimationIds) do
		add(id)
	end
	for _, setup in pairs(StationAnimationConfig.Setups) do
		add(setup.id)
	end
	for _, rerack in pairs(StationAnimationConfig.Reracks) do
		add(rerack.id)
	end
	for _, fails in pairs(StationAnimationConfig.Fails) do
		for _, fail in ipairs(fails) do
			add(fail.id)
		end
	end
	for _, style in pairs(StationAnimationConfig.FailStyles) do
		for _, fails in pairs(style.fails) do
			for _, fail in ipairs(fails) do
				add(fail.id)
			end
		end
	end
	add(LocalMeetConfig.Chalk.LifterAnimationId)
	add(LocalMeetConfig.Chalk.CoachBackAnimationId)
	add(LocalMeetConfig.Chalk.CoachTalkAnimationId)
	for _, reaction in ipairs(CelebrationConfig.MissReactions) do
		add(reaction.animationId)
	end
	for _, entrance in pairs(EntranceConfig.Entrances) do
		add(entrance.walkAnimationId)
		add(entrance.hypeAnimationId)
	end
	add(EntranceConfig.QuickTouch.animationId)
	-- (Nationals: the flow state behind the curtain, and parting it.)
	add(NationalsConfig.FlowAnimationId)
	add(NationalsConfig.CurtainPartAnimationId)
	for _, celebration in ipairs(CelebrationConfig.List) do
		add(celebration.animationId)
	end
	for _, emote in ipairs(EmoteConfig.List) do
		add(emote.animationId)
	end
	return ids
end

function MeetAnimationPreload.start()
	task.spawn(function()
		local animations: { Instance } = {}
		for _, id in ipairs(allIds()) do
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			table.insert(animations, animation)
		end
		for first = 1, #animations, BATCH do
			local batch = table.move(animations, first, math.min(#animations, first + BATCH - 1), 1, {})
			pcall(function()
				ContentProvider:PreloadAsync(batch)
			end)
		end
	end)
end

return MeetAnimationPreload
