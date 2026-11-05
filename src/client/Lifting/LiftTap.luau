--!strict
--[[
	LiftTap
	Client / Lifting

	A press anywhere on the screen, for the lift minigames (user 2026-11-05: "you can
	tap the screen and the bar moves ... every skillcheck game ... i should be able to
	use my mouse(m1)"): a finger on a phone, the left mouse button on a computer. A tap
	on a real button (LEAVE, the side tabs) stays that button's, because Roblox marks
	those inputs as already used.

	Several fingers can be down at once: the press goes up only when the last one lifts,
	so a bench hold doesn't end because a second finger tapped.
]]

local UserInputService = game:GetService("UserInputService")

local LiftTap = {}

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

--[[
	Calls `onPress` for each new press, and `onRelease` (if any) when the last one is
	released. Presses in the first `ignoreSeconds` don't count: a skill check follows a
	game of mashing, and the mash must not spill into it. Returns what stops listening.
]]
function LiftTap.listen(onPress: () -> (), onRelease: (() -> ())?, ignoreSeconds: number?): () -> ()
	local startsAt = os.clock() + (ignoreSeconds or 0)
	-- The presses this listener counted that are still down.
	local down: { [InputObject]: boolean } = {}
	local began = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not isPress(input) or os.clock() < startsAt then
			return
		end
		down[input] = true
		onPress()
	end)
	local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
		if down[input] then
			down[input] = nil
			if next(down) == nil and onRelease then
				onRelease()
			end
		end
	end)
	return function()
		began:Disconnect()
		ended:Disconnect()
	end
end

return LiftTap
