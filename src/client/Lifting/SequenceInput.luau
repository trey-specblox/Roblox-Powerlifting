--!strict
--[[
	SequenceInput
	Client / Lifting

	The typing pull's input, as abstract TOKENS rather than keyboard letters.

	=========================================================================
	PC TYPING IS CAPTURED AS TEXT ENTRY, NOT AS KEY PRESSES
	=========================================================================

	A hidden, focused TextBox receives the player's typing, and tokens are derived
	from the TEXT it reports.

	THIS IS LOAD-BEARING, NOT A STYLISTIC CHOICE. Reading individual keys does not
	work for the whole alphabet: Roblox's built-in controls claim some letters for
	themselves, and a listener or keybind competing for those keys loses. In
	testing, plain `i` and plain `o` never reached the game while every other
	letter did, and holding Shift bypassed it. Capturing text sidesteps the contest
	entirely, because text entry is delivered by the OS rather than contended for.

	If anyone later tries to "simplify" this back to UserInputService.InputBegan or
	ContextActionService keybinds, those two letters will silently stop working.

	THE TEXTBOX IS AN INPUT DEVICE, NOT A UI

	It is one pixel, fully transparent, and its text is cleared on every change, so
	nothing is ever rendered in it. A TextBox must be visible to take focus, so it
	is made imperceptible rather than hidden. The player sees only the word line and
	the bar that TypingUI draws.

	=========================================================================
	HOW A CHARACTER BECOMES A TOKEN
	=========================================================================

		player types `i`
		  -> TextBox.Text becomes "i"
		  -> the Text changed signal fires
		  -> we read "i", then immediately clear Text back to ""
		  -> string.upper("i") = "I"
		  -> "I" is in A-Z, so emit exactly one token "I"

	Clearing after every read is what makes the next change contain ONLY the newly
	typed characters, with no diffing against a growing string. It also means
	backspace has nothing to delete and therefore emits nothing.

	Case cannot matter: a single string.upper handles it, and Caps Lock only decides
	which case arrives before being discarded.

	Non-letters are dropped silently rather than scored. A typed space produces no
	token and no mistake, which is why the spaces in the word line never have to be
	typed.

	ONE CHARACTER, ONE TOKEN EVENT. Each accepted character results in exactly one
	onToken call, in order. There is a single input source, so a keypress cannot
	double-report.

	NO RATE LIMIT AND NO DEBOUNCE. Every accepted character is emitted immediately,
	so typing at speed never loses a keystroke.

	=========================================================================
	PASTE AND BULK INSERTION
	=========================================================================

	Normal typing changes the text one character at a time, so each change event
	carries one character. A paste carries the whole clipboard in a single change.

	Any change carrying more than MAX_CHARS_PER_CHANGE characters is treated as bulk
	insertion: the first character is accepted and the rest are discarded. Pasting a
	whole cue therefore yields one character, not a completed pull.

	The allowance is 2 rather than 1 so that an engine frame hitch coalescing two
	genuine keystrokes does not cost the player a character. The residual is that a
	two-character paste is indistinguishable from two fast keystrokes, which is
	accepted deliberately.

	THIS DOES NOT MAKE AUTOMATION IMPOSSIBLE and is not claimed to. A script that
	types one character at a time at a human rate is indistinguishable from a human.
	This only removes the trivial clipboard shortcut.

	SERVER AUTHORITY IS UNAFFECTED

	This module captures input and nothing else. The client reports only raw tokens
	with timestamps; the server owns the expected sequence and the authoritative
	result. The client never sends correctness, progress, completion or a verdict.

	PLATFORM ABSTRACTION IS PRESERVED

	Everything downstream consumes opaque token strings. A gamepad or touch
	vocabulary replaces this module's capture and nothing else changes.
]]

local SequenceInput = {}

--[[
	Characters accepted from a single text change before it is treated as a paste.

	See the note above: 2 absorbs an engine hitch coalescing two real keystrokes,
	while still reducing a pasted cue to a single character.
]]
local MAX_CHARS_PER_CHANGE = 2

local gui: ScreenGui? = nil
local textBox: TextBox? = nil

local bound = false

-- Guards the self-inflicted change when the box is cleared after a read.
local suppressChange = false

local connections: { RBXScriptConnection } = {}

--[[
	The token a typed character produces, or nil if it is not a letter.
]]
local function tokenForCharacter(char: string): string?
	local upper = string.upper(char)
	if string.match(upper, "^[A-Z]$") ~= nil then
		return upper
	end
	return nil
end

--[[
	Every token a typed string yields, in order.

	Separated from the signal handler so it is a pure function of its input, which
	is what makes the behaviour testable without a TextBox or a running game.
]]
local function tokensForText(text: string): { string }
	local tokens: { string } = {}
	for index = 1, #text do
		local token = tokenForCharacter(string.sub(text, index, index))
		if token ~= nil then
			table.insert(tokens, token)
		end
	end
	return tokens
end

--[[
	Creates the hidden capture box. Call once, before any bind.
]]
function SequenceInput.mount(parent: Instance)
	if gui ~= nil then
		return
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "TypingCapture"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 100
	screen.Enabled = true

	local box = Instance.new("TextBox")
	box.Name = "Capture"
	box.Size = UDim2.fromOffset(1, 1)
	box.Position = UDim2.fromOffset(0, 0)
	box.BackgroundTransparency = 1
	box.TextTransparency = 1
	box.TextStrokeTransparency = 1
	box.BorderSizePixel = 0
	box.Text = ""
	box.PlaceholderText = ""
	--[[
		Focusing must not wipe anything, and a pull is a single line. Both are set
		explicitly because the defaults would interfere with reading each change as
		"only what was just typed".
	]]
	box.ClearTextOnFocus = false
	box.MultiLine = false
	box.TextEditable = true
	box.Parent = screen

	screen.Parent = parent
	gui = screen
	textBox = box
end

local function disconnectAll()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}
end

--[[
	Starts routing tokens to `onToken` and focuses the capture box.

	REPLACES any existing binding rather than ignoring the request, so a phase that
	binds without the previous one unbinding cannot leave a stale listener running.
]]
function SequenceInput.bind(onToken: (token: string) -> ())
	local box = textBox
	if box == nil then
		warn("[SequenceInput] bind() called before mount(); no typing input will be captured")
		return
	end

	if bound then
		warn("[SequenceInput] bind() called while already bound; replacing the previous binding")
		disconnectAll()
		bound = false
	end

	bound = true

	-- Start from a clean box, without the clear counting as typed input.
	suppressChange = true
	box.Text = ""
	suppressChange = false

	table.insert(
		connections,
		box:GetPropertyChangedSignal("Text"):Connect(function()
			if suppressChange or not bound then
				return
			end

			local typed = box.Text

			-- Clear immediately, so the next change carries only new characters.
			suppressChange = true
			box.Text = ""
			suppressChange = false

			if typed == "" then
				return
			end

			local tokens = tokensForText(typed)

			--[[
				BULK INSERTION GUARD. A paste arrives as one large change; typing does
				not. Accept the allowance and discard the rest, so a pasted cue yields a
				single character rather than a finished pull.
			]]
			if #tokens > MAX_CHARS_PER_CHANGE then
				onToken(tokens[1])
				return
			end

			for _, token in ipairs(tokens) do
				onToken(token)
			end
		end)
	)

	--[[
		Focus is the mechanism, so losing it would make the minigame stop accepting
		input with no explanation. While the pull is live, focus is taken back
		deliberately rather than allowed to lapse.
	]]
	table.insert(
		connections,
		box.FocusLost:Connect(function()
			if not bound then
				return
			end
			task.defer(function()
				if bound and textBox ~= nil then
					textBox:CaptureFocus()
				end
			end)
		end)
	)

	box:CaptureFocus()
end

--[[
	Stops routing tokens and releases focus, returning normal controls.

	Releasing matters beyond tidiness: the lockout that follows a pull is a spacebar
	press, and a focused TextBox would swallow it.
]]
function SequenceInput.unbind()
	if not bound then
		return
	end

	--[[
		Cleared BEFORE releasing focus, so the FocusLost handler above sees that the
		phase is over and does not fight the release.
	]]
	bound = false
	disconnectAll()

	local box = textBox
	if box ~= nil then
		suppressChange = true
		box.Text = ""
		suppressChange = false
		box:ReleaseFocus()
	end
end

--[[
	True while the typing phase is capturing text.

	Exists so a caller can assert the release rather than assume it.
]]
function SequenceInput.isBound(): boolean
	return bound
end

--[[
	A short description of the PC control, for the on-screen prompt. Lives here so
	the prompt cannot drift away from what this module actually accepts.
]]
function SequenceInput.promptText(): string
	return "TYPE THE WORDS - NO SPACES NEEDED - KEEP THE BAR MOVING"
end

return SequenceInput
