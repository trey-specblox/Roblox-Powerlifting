--!strict
--[[
	MeetCinema
	Client / Meet

	The film look of the coach's ritual (GAME_DESIGN §36.4, user 2026-11-11; LocalMeetConfig.Ritual), on this player's
	screen only. MeetRitualShot runs the shots at the chalk stand and MeetLiftMoment the walk out; this holds what they
	share:
		open / close   black bars top and bottom, every other screen and the staff's tags and bubble out of the way, the
		               lens narrower, a soft background (depth of field); close puts everything back as it was
		caption        the attempt and weight, low in the middle (the video's lower third)
		subtitle       what the coach says, in the bottom bar (text only, user's choice)
		focus          how far away the sharp subject is
		handheld       a slight drift for the camera, like a camera held by hand
		skipButton     SKIP, in the bottom bar (not on the first turn of a meet, user's choice)
	It also carries two flags the camera modules share: `ritualCamera` (the chalk-stand shots own the camera, so
	MeetChalkShot keeps off it) and `walkShots` (the walk out gets the ritual's shots).

	Display only: it decides and saves nothing.
	PERFORMANCE: one small ScreenGui made once; a DepthOfFieldEffect only while a ritual runs.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LocalMeetConfig = require(Shared:WaitForChild("Config"):WaitForChild("LocalMeetConfig"))

local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours

local MeetCinema = {}

local SETTINGS = LocalMeetConfig.Ritual

-- The chalk-stand shots own the camera (MeetChalkShot keeps off it).
MeetCinema.ritualCamera = false
-- The walk out gets the ritual's shots (MeetLiftMoment); false once skipped.
MeetCinema.walkShots = false

type Screen = {
	gui: ScreenGui,
	top: Frame,
	bottom: Frame,
	captionHolder: Frame,
	captionSmall: TextLabel,
	captionBig: TextLabel,
	subtitle: TextLabel,
	skip: TextButton,
}
local screen: Screen? = nil

type Held = {
	guis: { [ScreenGui]: boolean },
	watchers: { RBXScriptConnection },
	bubbles: { BillboardGui },
	fieldOfView: number,
	focus: DepthOfFieldEffect,
}
local held: Held? = nil
local skipAction: (() -> ())? = nil
local captionToken = 0

local function bar(gui: ScreenGui, name: string, top: boolean): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(0, if top then 1 else 0)
	frame.Position = UDim2.fromScale(0, if top then 0 else 1)
	frame.Size = UDim2.fromScale(1, SETTINGS.BarShare)
	frame.Parent = gui
	return frame
end

local function build(): Screen
	local gui = Instance.new("ScreenGui")
	gui.Name = "MeetCinema"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Enabled = false

	local top = bar(gui, "TopBar", true)
	local bottom = bar(gui, "BottomBar", false)

	-- The caption: the attempt small above, the weight big below, in the middle just over the bottom bar.
	local captionHolder = Instance.new("Frame")
	captionHolder.Name = "Caption"
	captionHolder.BackgroundTransparency = 1
	captionHolder.AnchorPoint = Vector2.new(0.5, 1)
	captionHolder.Position = UDim2.new(0.5, 0, 1 - SETTINGS.BarShare, -14)
	captionHolder.Size = UDim2.fromOffset(640, 78)
	captionHolder.Visible = false
	captionHolder.Parent = gui
	local captionSmall = UIStyle.text(captionHolder, "Attempt", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 24), 18, C.white,
		UIStyle.font(Enum.FontWeight.Bold), Enum.TextXAlignment.Center)
	local captionBig = UIStyle.text(captionHolder, "Weight", UDim2.fromOffset(0, 24), UDim2.new(1, 0, 0, 50), 40, C.yellow,
		UIStyle.heading(), Enum.TextXAlignment.Center)
	-- (A long line, a celebration's name, shrinks to fit.)
	captionBig.TextScaled = true
	local bigLimit = Instance.new("UITextSizeConstraint")
	bigLimit.MaxTextSize = 40
	bigLimit.Parent = captionBig
	for _, label in ipairs({ captionSmall, captionBig }) do
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.5
		stroke.Transparency = 0.35
		stroke.Color = C.ink
		stroke.Parent = label
	end

	-- The subtitle: in the bottom bar.
	local subtitle = UIStyle.text(bottom, "Subtitle", UDim2.fromScale(0.15, 0.1), UDim2.fromScale(0.7, 0.8), 22, C.white,
		UIStyle.font(Enum.FontWeight.SemiBold), Enum.TextXAlignment.Center)
	subtitle.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 24
	limit.Parent = subtitle

	local skip = UIStyle.button(bottom, "Skip", "SKIP", UDim2.new(1, -150, 0.5, -18), UDim2.fromOffset(130, 36), "outline",
		function()
			local action = skipAction
			if action then
				action()
			end
		end)
	skip.AnchorPoint = Vector2.new(0, 0)
	skip.Visible = false

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return { gui = gui, top = top, bottom = bottom, captionHolder = captionHolder, captionSmall = captionSmall,
		captionBig = captionBig, subtitle = subtitle, skip = skip }
end

local function slideBars(current: Screen, shown: boolean)
	local info = TweenInfo.new(SETTINGS.BarSeconds, Enum.EasingStyle.Quart, if shown then Enum.EasingDirection.Out
		else Enum.EasingDirection.In)
	TweenService:Create(current.top, info, { AnchorPoint = Vector2.new(0, if shown then 0 else 1) }):Play()
	TweenService:Create(current.bottom, info, { AnchorPoint = Vector2.new(0, if shown then 1 else 0) }):Play()
end

-- Whether a ritual is on screen.
function MeetCinema.isOpen(): boolean
	return held ~= nil
end

-- The film look on: bars in, every other screen and the staff's tags and the coach's speech bubble out of the way, the
-- lens and the soft background. Does nothing if already open.
function MeetCinema.open()
	if held then
		return
	end
	local current = screen or build()
	screen = current
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local guis: { [ScreenGui]: boolean } = {}
	local watchers: { RBXScriptConnection } = {}
	-- Every other screen out of the way (the meet's panels, the menu, coins...), like a film.
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui ~= current.gui and gui.Enabled then
			guis[gui] = gui.Enabled
			gui.Enabled = false
			-- Their own code may turn them back on meanwhile: what it wants is kept for later, and they stay hidden.
			table.insert(watchers, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
				if gui.Enabled and held then
					guis[gui] = true
					gui.Enabled = false
				end
			end))
		end
	end
	-- The staff's name tags and the coach's speech bubble: private to this lifter, so they live in their PlayerGui
	-- (LocalMeetVenue.staffFor). The coach's words are the subtitle meanwhile.
	local bubbles: { BillboardGui } = {}
	for _, item in ipairs(playerGui:GetChildren()) do
		if item:IsA("BillboardGui") and item.Enabled then
			item.Enabled = false
			table.insert(bubbles, item)
		end
	end
	local camera = Workspace.CurrentCamera
	local focus = Instance.new("DepthOfFieldEffect")
	focus.Name = "MeetCinemaFocus"
	focus.FarIntensity = SETTINGS.Focus.FarIntensity
	focus.NearIntensity = SETTINGS.Focus.NearIntensity
	focus.InFocusRadius = SETTINGS.Focus.InFocusRadius
	focus.FocusDistance = 6
	focus.Parent = Lighting
	held = { guis = guis, watchers = watchers, bubbles = bubbles, fieldOfView = camera.FieldOfView, focus = focus }
	camera.FieldOfView = SETTINGS.FieldOfView

	current.subtitle.Text = ""
	current.captionHolder.Visible = false
	current.skip.Visible = false
	current.top.AnchorPoint = Vector2.new(0, 1)
	current.bottom.AnchorPoint = Vector2.new(0, 0)
	current.gui.Enabled = true
	slideBars(current, true)
end

-- Everything back as it was. Safe to call when not open.
function MeetCinema.close()
	local was = held
	if was == nil then
		return
	end
	held = nil
	MeetCinema.ritualCamera = false
	MeetCinema.walkShots = false
	skipAction = nil
	for _, watcher in ipairs(was.watchers) do
		watcher:Disconnect()
	end
	for gui, enabled in pairs(was.guis) do
		if gui.Parent then
			gui.Enabled = enabled
		end
	end
	for _, bubble in ipairs(was.bubbles) do
		if bubble.Parent then
			bubble.Enabled = true
		end
	end
	was.focus:Destroy()
	Workspace.CurrentCamera.FieldOfView = was.fieldOfView
	local current = screen
	if current then
		current.skip.Visible = false
		current.captionHolder.Visible = false
		current.subtitle.Text = ""
		slideBars(current, false)
		task.delay(SETTINGS.BarSeconds + 0.05, function()
			if held == nil then
				current.gui.Enabled = false
			end
		end)
	end
end

-- The attempt and weight under the opening shot, for CaptionSeconds.
function MeetCinema.caption(small: string, big: string)
	local current = screen
	if current == nil or held == nil then
		return
	end
	captionToken += 1
	local token = captionToken
	current.captionSmall.Text = small
	current.captionBig.Text = big
	current.captionHolder.Visible = true
	task.delay(SETTINGS.CaptionSeconds, function()
		if captionToken == token then
			current.captionHolder.Visible = false
		end
	end)
end

-- What the coach says, in the bottom bar (nil: nothing).
function MeetCinema.subtitle(line: string?)
	local current = screen
	if current then
		current.subtitle.Text = if line then "COACH:  " .. line else ""
	end
end

-- The sharp subject is this far from the camera (studs).
function MeetCinema.focus(distance: number)
	local current = held
	if current then
		current.focus.FocusDistance = math.max(0.5, distance)
	end
end

-- A slight drift, like a camera held by hand, at `time` seconds (layer it on a shot's CFrame).
function MeetCinema.handheld(time: number): CFrame
	local shake = SETTINGS.Shake
	local s = time * shake.Speed
	local move = Vector3.new(math.noise(s, 1.3), math.noise(s, 7.1), math.noise(s, 4.7)) * shake.Studs * 2
	local turn = math.rad(shake.Degrees)
	return CFrame.new(move) * CFrame.Angles(math.noise(s, 11.9) * turn, math.noise(s, 17.3) * turn, math.noise(s, 23.1) * turn * 0.4)
end

-- SKIP in the bottom bar, doing `action` when pressed (nil: no button).
function MeetCinema.skipButton(action: (() -> ())?)
	skipAction = action
	local current = screen
	if current then
		current.skip.Visible = action ~= nil and held ~= nil
	end
end

return MeetCinema
