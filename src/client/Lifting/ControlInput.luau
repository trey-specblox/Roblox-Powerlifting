--!strict
--[[
	ControlInput
	Client / Lifting

	The control phase's input, as one abstract gameplay action rather than a
	hardcoded mouse button.

	WHY IT IS BUILT THIS WAY

	The mechanic needs the same action on PC, mobile, tablet and console. Binding
	MouseButton1 directly inside the minigame would mean rewriting the mechanic to
	add a platform later.

	So there is a single action, ControlImpulse, and a list of bindings that
	produce it. Adding a platform is adding to that list; the simulation, the UI
	and the server never learn which device sent anything.

	ContextActionService is used rather than UserInputService specifically because
	`createTouchButton` gives mobile and tablet an on-screen button for free, and
	because binding at a raised priority lets the action take precedence while a
	phase is running.

	Only PC is tested. The touch and gamepad bindings are present because they cost
	nothing to declare here, not because they have been verified.
]]

local ContextActionService = game:GetService("ContextActionService")

local ControlInput = {}

local ACTION_NAME = "RpfControlImpulse"

--[[
	Every input that produces one impulse.

	MouseButton1 is the PC control the design specifies. Space is deliberately NOT
	bound: the timing check already uses it, and sharing it would create contention
	if both phases were ever live at once.
]]
local BINDINGS = {
	Enum.UserInputType.MouseButton1,
	-- Console. Declared, not tested.
	Enum.KeyCode.ButtonA,
	Enum.KeyCode.ButtonR2,
}

local bound = false

--[[
	Starts routing impulses to `onImpulse`.

	Passing true for createTouchButton means touch devices get an on-screen button
	without any further work, which is what makes mobile and tablet support a
	configuration detail rather than a rewrite.
]]
function ControlInput.bind(onImpulse: () -> ())
	if bound then
		return
	end
	bound = true

	ContextActionService:BindActionAtPriority(
		ACTION_NAME,
		function(_actionName, state)
			if state == Enum.UserInputState.Begin then
				onImpulse()
			end
			-- Sink, so nothing else reacts to a click meant for the bar.
			return Enum.ContextActionResult.Sink
		end,
		true,
		Enum.ContextActionPriority.High.Value,
		table.unpack(BINDINGS)
	)
end

--[[
	Stops routing impulses and removes any touch button.
]]
function ControlInput.unbind()
	if not bound then
		return
	end
	bound = false
	ContextActionService:UnbindAction(ACTION_NAME)
end

--[[
	A short description of the PC control, for the on-screen prompt. Lives here so
	the prompt cannot drift away from the bindings above.
]]
function ControlInput.promptText(): string
	return "CLICK TO LIFT THE BAR - KEEP THE MARKER INSIDE IT"
end

return ControlInput
