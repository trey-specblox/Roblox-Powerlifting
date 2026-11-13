--!strict
--[[
	HandShapeAnimator
	Client / Meet

	Hand-shape swaps (GAME_DESIGN.md §38.7, HandShapeConfig): the cartoon bodies' hands are OPEN; while a celebration
	or emote with a hand timeline plays they switch to the shape the moment needs (a fist pump, a finger to the sky,
	thumbs up) and back, and while they hold the bar in a lift (setGrip) they close. The server puts the hidden shapes
	on each body (LifterBodyService, folder HandShapeConfig.FolderName); every client runs this for every character it
	sees, from the animation's own playing time, so everyone sees the same hands at the same moment. Looks only, local changes: nothing is sent anywhere.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HandShapeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HandShapeConfig"))

local HandShapeAnimator = {}

type Watch = { character: Model, folder: Instance, shown: { [string]: string? }, tracks: { [AnimationTrack]: { HandShapeConfig.Span } } }

local watched: { [Model]: Watch } = {}
-- Characters whose hands grip something right now (the bar in a lift: StationPoseAnimator).
local gripping: { [Model]: boolean } = {}
local SIDES = { "Left", "Right" }

-- Shows `shape` (nil = the open hand) on `side`.
local function show(watch: Watch, side: string, shape: string?)
	if watch.shown[side] == shape then
		return
	end
	watch.shown[side] = shape
	local hand = watch.character:FindFirstChild(side .. "Hand")
	if hand and hand:IsA("BasePart") then
		hand.Transparency = if shape then 1 else 0
	end
	for _, name in ipairs(HandShapeConfig.Shapes) do
		local part = watch.folder:FindFirstChild(name .. "_" .. side)
		if part and part:IsA("BasePart") then
			part.Transparency = if name == shape then 0 else 1
		end
	end
end

local function watch(character: Model, folder: Instance)
	if watched[character] then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		return
	end
	local w: Watch = { character = character, folder = folder, shown = {}, tracks = {} }
	watched[character] = w
	-- Tracks already playing (a celebration started before this character streamed in).
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		local spans = track.Animation and HandShapeConfig.timelineFor(track.Animation.AnimationId)
		if spans then
			w.tracks[track] = spans
		end
	end
	animator.AnimationPlayed:Connect(function(track: AnimationTrack)
		local spans = track.Animation and HandShapeConfig.timelineFor(track.Animation.AnimationId)
		if spans then
			w.tracks[track] = spans
		end
	end)
	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			watched[character] = nil
		end
	end)
end

local function step()
	for character, w in pairs(watched) do
		if w.folder.Parent ~= character then
			watched[character] = nil
			gripping[character] = nil
			continue
		end
		local wanted: { [string]: string? } = {}
		for track, spans in pairs(w.tracks) do
			if not track.IsPlaying then
				w.tracks[track] = nil
				continue
			end
			-- A faded-out track keeps playing a moment: its hands go back with it.
			if track.WeightCurrent < 0.5 then
				continue
			end
			for _, side in ipairs(SIDES) do
				wanted[side] = wanted[side] or HandShapeConfig.shapeAt(spans, track.TimePosition, side)
			end
		end
		for _, side in ipairs(SIDES) do
			show(w, side, wanted[side] or (if gripping[character] then HandShapeConfig.Grip else nil))
		end
	end
end

-- Whether `character`'s hands grip something (the bar): they close (HandShapeConfig.Grip) while nothing else is shown.
function HandShapeAnimator.setGrip(character: Model, on: boolean)
	gripping[character] = if on then true else nil
end

function HandShapeAnimator.start()
	local function found(instance: Instance)
		if instance.Name == HandShapeConfig.FolderName and instance:IsA("Folder") then
			local character = instance.Parent
			if character and character:IsA("Model") then
				task.defer(watch, character, instance)
			end
		end
	end
	for _, d in ipairs(Workspace:GetDescendants()) do
		found(d)
	end
	Workspace.DescendantAdded:Connect(found)
	RunService.Heartbeat:Connect(step)
end

return HandShapeAnimator
