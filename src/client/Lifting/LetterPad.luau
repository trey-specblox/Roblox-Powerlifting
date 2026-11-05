--!strict
--[[
	LetterPad
	Client / Lifting

	The deadlift's typing pull on a phone (user 2026-11-05: the phone's own keyboard
	is so small it "causes a lot of fat-fingering"). Takes SequenceInput's place on a
	touch-only device: the game's own QWERTY keyboard (user: "a normal qwert
	keyboard"), with much taller keys, so the phone's keyboard never opens.
	GAME_DESIGN "How the lift games are played".

	THE SAME LIFT, THE SAME RULES

	A press produces the same token a typed letter does, handed to the same
	TypingUI.registerToken. The server replays those tokens exactly as it replays a
	keyboard's, so nothing here can change a result, and no setting depends on the
	player saying they are on a phone.

	Every letter is always in its usual place, and the next correct key is NOT marked:
	reading the word is the game.

	Each key reacts to its own press (InputBegan, not a click), the moment a finger
	lands, so two thumbs can overlap and a key does not wait for its release.
]]

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local CardioRhythmConfig = require(Config:WaitForChild("CardioRhythmConfig"))
local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))
local C = UIStyle.Colours

local LetterPad = {}

local ROWS = { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" }
-- The top row sets a key's width; the shorter rows are centred under it, as on a real keyboard.
local COLUMNS = #ROWS[1]

--[[
	In real screen points, not shrunk by UIStyle.fitToScreen as the panels are: the
	keys must stay finger-sized on the smallest phone. On a 752 x 390 phone the pad
	is about 736 x 218, stopping just under the typing panel, so a key is about
	68 x 67. The maximum keeps a tablet's keys from turning huge.
]]
local PAD_HEIGHT_FRACTION = 0.56
local PAD_MAX_SIZE = Vector2.new(980, 300)
local BOTTOM_GAP = 6
local KEY_GAP = 6
local LETTER_SIZE = 30
-- See-through enough to watch the lift between the letters.
local KEY_TRANSPARENCY = 0.2

local FLASH_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TAP_VOLUME = 0.3
local MISS_VOLUME = 0.5

type Key = {
	button: TextButton,
	tween: Tween?,
}

local gui: ScreenGui? = nil
local onToken: ((token: string) -> ())? = nil
local lastPressed: Key? = nil
local tapSound: Sound? = nil
local missSound: Sound? = nil

local function flash(key: Key, colour: Color3)
	if key.tween then
		key.tween:Cancel()
	end
	key.button.BackgroundColor3 = colour
	local tween = TweenService:Create(key.button, FLASH_INFO, { BackgroundColor3 = C.navyDeep })
	key.tween = tween
	tween:Play()
end

local function makeKey(pad: Frame, letter: string, position: UDim2)
	local button = Instance.new("TextButton")
	button.Name = "Key" .. letter
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = position
	button.Size = UDim2.new(1 / COLUMNS, -KEY_GAP, 1 / #ROWS, -KEY_GAP)
	button.BackgroundColor3 = C.navyDeep
	button.BackgroundTransparency = KEY_TRANSPARENCY
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.FontFace = UIStyle.heading()
	button.TextColor3 = C.white
	button.TextSize = LETTER_SIZE
	button.Text = letter
	button.Parent = pad
	UIStyle.stroke(button, C.white, 2)

	local key: Key = { button = button, tween = nil }
	button.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local send = onToken
		if send == nil then
			return
		end
		lastPressed = key
		flash(key, UIStyle.LiftColours.Deadlift)
		send(letter)
	end)
end

local function makeSound(name: string, volume: number): Sound?
	local id = CardioRhythmConfig.Sounds[name]
	if id == nil or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "LetterPad" .. name
	sound.SoundId = id
	sound.Volume = volume
	-- In the player's ears, not placed in the world: these are their own taps.
	sound.Parent = SoundService
	return sound
end

local function playSound(sound: Sound?)
	if sound then
		sound.TimePosition = 0
		sound:Play()
	end
end

-- True on a phone or tablet with no keyboard attached.
function LetterPad.isWanted(): boolean
	return UIStyle.isTouchOnly()
end

function LetterPad.promptText(): string
	return "TAP THE LETTERS - KEEP THE BAR MOVING"
end

--[[
	Builds the keyboard, hidden. Call once.
]]
function LetterPad.mount(parent: Instance)
	if gui ~= nil then
		return
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "LetterPad"
	screen.ResetOnSpawn = false
	-- Inside a phone's notch and rounded corners.
	screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.DisplayOrder = 100
	screen.Enabled = false

	local pad = Instance.new("Frame")
	pad.Name = "Pad"
	pad.AnchorPoint = Vector2.new(0.5, 1)
	pad.Position = UDim2.new(0.5, 0, 1, -BOTTOM_GAP)
	pad.Size = UDim2.new(1, -16, PAD_HEIGHT_FRACTION, 0)
	pad.BackgroundTransparency = 1
	pad.Parent = screen

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = PAD_MAX_SIZE
	limit.Parent = pad

	for rowIndex, row in ipairs(ROWS) do
		local indent = (COLUMNS - #row) / 2
		for index = 1, #row do
			makeKey(
				pad,
				string.sub(row, index, index),
				UDim2.fromScale((indent + index - 0.5) / COLUMNS, (rowIndex - 0.5) / #ROWS)
			)
		end
	end

	screen.Parent = parent
	gui = screen
	tapSound = makeSound("Hit", TAP_VOLUME)
	missSound = makeSound("Miss", MISS_VOLUME)
end

--[[
	Shows the keyboard for one pull.
]]
function LetterPad.start(send: (token: string) -> ())
	local screen = gui
	if screen == nil then
		warn("[LetterPad] start() called before mount(); no letters can be tapped")
		return
	end
	onToken = send
	lastPressed = nil
	screen.Enabled = true
end

-- The last press was the right letter. Called by TypingUI.
function LetterPad.hit()
	playSound(tapSound)
end

-- The last press was a wrong letter. Called by TypingUI.
function LetterPad.miss()
	if lastPressed then
		flash(lastPressed, C.red)
	end
	playSound(missSound)
end

--[[
	Hides the keyboard. Safe to call when it is not showing, so every way out of a lift
	can call it.
]]
function LetterPad.stop()
	onToken = nil
	lastPressed = nil
	if gui then
		gui.Enabled = false
	end
end

return LetterPad
