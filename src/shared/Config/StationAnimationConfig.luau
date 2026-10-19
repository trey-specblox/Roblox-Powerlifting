--!strict
--[[
	StationAnimationConfig
	Shared / Config

	The station rep animations (GAME_DESIGN.md §34.12 decision 15: slow repeating
	reps). They are made by art/scripts/station_animations.py, exported to
	art/animations/Station_<Lift>.rbxmx, and published to Roblox from Studio
	(Insert from File -> right-click the KeyframeSequence -> Save to Roblox).

	Paste each published ID below as "rbxassetid://<number>". An empty ID means
	that lift has no animation yet: the lifter keeps the still station position
	and the bar stays where it rests. Visual only; nothing here affects training.
]]

local StationAnimationConfig = {}

-- Published 2026-10-19 from art/animations/Station_<Lift>.rbxmx under the GROUP
-- that owns the game (529442797). An animation owned by anyone else (even the
-- group's owner personally) will not play in this game.
StationAnimationConfig.AnimationIds = {
	Squat = "rbxassetid://132820904488036",
	Bench = "rbxassetid://87040674560117",
	Deadlift = "rbxassetid://91506920973531",
} :: { [string]: string }

--[[
	When the bar is in the lifter's hands, in seconds into the 6-second loop.
	A lift not listed holds the bar the whole time (squat: on the back; bench).
	Deadlift: gripped at 1.6 s, set down at 4.3 s (station_animations.py
	DEADLIFT_BAR_HELD); otherwise the bar lies on the floor.
]]
StationAnimationConfig.BarHeldWindows = {
	Deadlift = { { 1.6, 4.3 } },
} :: { [string]: { { number } } }

function StationAnimationConfig.isBarHeld(lift: string, timePosition: number): boolean
	local windows = StationAnimationConfig.BarHeldWindows[lift]
	if windows == nil then
		return true
	end
	for _, window in ipairs(windows) do
		if timePosition >= window[1] and timePosition < window[2] then
			return true
		end
	end
	return false
end

return StationAnimationConfig
