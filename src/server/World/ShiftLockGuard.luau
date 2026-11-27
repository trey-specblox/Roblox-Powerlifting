--!strict
--[[
	ShiftLockGuard
	Server / World

	No Shift Lock while the game holds a character in place (user 2026-11-27: "if you shift lock before the automatic
	animation, it starts shaking rapidly, and whatever direction your facing your locked in that position, even when
	your lifting, you face the direction u were originally facing with the shift lock, and it moves the whole bar").

	Meets, Mock Meets, coach's trials, gym practice and the training stations hold the lifter by anchoring the
	HumanoidRootPart on the server (see client LockedStance). Shift Lock turns the character to face the camera every
	frame, fighting that hold (the shaking) and turning the lifter, bar and all, off the platform's line. So while the
	root is anchored, the player's Shift Lock option is off (Roblox's camera then ends Shift Lock if it was on, and it
	can't be switched back on), and it comes back when the hold ends. Only the server may set this option.
]]

local Players = game:GetService("Players")

local ShiftLockGuard = {}

local function watch(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local function sync()
		if player.Parent then
			player.DevEnableMouseLock = not root.Anchored
		end
	end
	sync()
	local changed = root:GetPropertyChangedSignal("Anchored"):Connect(sync)
	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			changed:Disconnect()
			if player.Parent then
				player.DevEnableMouseLock = true
			end
		end
	end)
end

function ShiftLockGuard.start()
	local function added(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(watch, player, character)
		end)
		if player.Character then
			task.spawn(watch, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(added)
	for _, player in ipairs(Players:GetPlayers()) do
		added(player)
	end
end

return ShiftLockGuard
