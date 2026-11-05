--!strict
--[[
	ControlInput
	Client / Lifting

	The control phase's input, as one abstract gameplay action rather than a
	hardcoded mouse button: the squat steadying the bar and the bench's mashing.

	WHY IT IS BUILT THIS WAY

	The mechanic needs the same action on PC, mobile, tablet and console. The
	simulation, the UI and the server never learn which device sent anything.

	A finger anywhere on the screen or the left mouse button comes through LiftTap
	(user 2026-11-05: no on-screen button to find). A gamepad comes through
	ContextActionService, which also keeps it from reaching anything else while a
	phase runs. Gamepad is declared, not tested.
]]

local ContextActionService = game:GetService("ContextActionService")

local LiftTap = require(script.Parent:WaitForChild("LiftTap"))
local UIStyle = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIStyle"))

local ControlInput = {}

local ACTION_NAME = "RpfControlImpulse"

--[[
	Space is deliberately NOT bound: the timing check already uses it, and sharing it
	would create contention if both phases were ever live at once.
]]
local GAMEPAD_BINDINGS = {
	Enum.KeyCode.ButtonA,
	Enum.KeyCode.ButtonR2,
}

local stopTap: (() -> ())? = nil

--[[
	Starts routing impulses to `onImpulse`.

	`onRelease` is optional and receives the matching release. The squat's control
	phase only cares about presses and passes nothing, so its behaviour is
	unchanged; the bench's power phase needs releases, because telling a continuous
	hold from a burst of clicks is impossible without knowing when the input went
	back up.
]]
function ControlInput.bind(onImpulse: () -> (), onRelease: (() -> ())?)
	if stopTap then
		return
	end
	stopTap = LiftTap.listen(onImpulse, onRelease)

	ContextActionService:BindActionAtPriority(
		ACTION_NAME,
		function(_actionName, state)
			if state == Enum.UserInputState.Begin then
				onImpulse()
			elseif state == Enum.UserInputState.End and onRelease ~= nil then
				onRelease()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		table.unpack(GAMEPAD_BINDINGS)
	)
end

-- Stops routing impulses.
function ControlInput.unbind()
	local stop = stopTap
	if stop == nil then
		return
	end
	stopTap = nil
	stop()
	ContextActionService:UnbindAction(ACTION_NAME)
end

--[[
	A short description of the control, for the on-screen prompt. Lives here so the
	prompt cannot drift away from the bindings above.
]]
function ControlInput.promptText(): string
	return (if UIStyle.isTouchOnly() then "TAP" else "CLICK") .. " TO LIFT THE BAR - KEEP THE MARKER INSIDE IT"
end

return ControlInput
