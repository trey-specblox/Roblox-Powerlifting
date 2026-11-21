--!strict
--[[
	LuckService
	Server / Economy

	The mafia boss cow's WHEEL OF LUCK and his games (GAME_DESIGN §40.7, user 2026-11-21; the rules and numbers are
	LuckConfig's, the save's operations ProfileOperations').

		- LuckRemotes: the luck view (GET), a spin (SPIN: the server rolls the wedge), a game's start (GAME_START: the
		  server decides where the steak starts and every swap) and its answer (GAME_FINISH: the server knows where the
		  steak ended).
		- The player attributes LuckConfig.MultiplierAttribute / EndsAtAttribute, kept current, for every screen that
		  shows odds with luck applied (the luck chip, the crate shop, the celebration spinner).

	SECURITY: the client never names a wedge, a multiplier, a reward or the steak's place. It asks to spin and learns
	where the wheel landed; it asks to play and sends the cloche it picked. A game costs one of the day's tries and can
	only ever ADD one spin (capped); a player who reads the swaps from the network to win every time gains at most
	GameTriesPerDay spins a day on a free wheel. Every request is rate limited and needs the lifter in the back room.
	Nothing is staked, anywhere (Roblox bans simulated gambling).

	NOT BUILT: the Robux SPIN NOW (LuckConfig.SpinProductId is 0). It needs the user's Developer Product, one receipt
	handler for the whole game (MarketplaceService.ProcessReceipt can only have one), and the PolicyService check for
	paid random items; ProfileOperations.addLuckSpins(..., false) is the operation it will call.

	PERFORMANCE: no loop; one small record per player while a game is being played.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))
local LuckConfig = require(Shared:WaitForChild("Config"):WaitForChild("LuckConfig"))
local WChewsLayout = require(Shared:WaitForChild("Config"):WaitForChild("WChewsLayout"))
local LuckRemotes = require(Shared:WaitForChild("Progression"):WaitForChild("LuckRemotes"))

local PlayerDataService = require(script.Parent.Parent:WaitForChild("PlayerData"):WaitForChild("PlayerDataService"))

local LuckService = {}

local MIN_SECONDS_BETWEEN_ASKS = 0.4
-- A game's answer is accepted this many seconds before the show could have ended (clocks and frames differ a little).
local EARLY_ALLOWED = 1.5
-- ... and this long after the time to answer ran out (the answer's trip to the server).
local LATE_ALLOWED = 6

type Game = { final: number, earliest: number, latest: number }

local started = false
local random = Random.new()
local lastAsked: { [Player]: number } = {}
local games: { [Player]: Game } = {}

local function tooSoon(player: Player): boolean
	local now = os.clock()
	if now - (lastAsked[player] or -math.huge) < MIN_SECONDS_BETWEEN_ASKS then
		return true
	end
	lastAsked[player] = now
	return false
end

-- Whether the lifter is in the back room (near the wheel).
local function inRoom(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local wheel = (KitchenConfig.HallOrigin * KitchenConfig.planSpot(WChewsLayout.Wheel.X, WChewsLayout.Wheel.Y, 3)).Position
	return (root.Position - wheel).Magnitude <= LuckConfig.Reach
end

-- Writes the player's luck onto their attributes (for the screens that show odds).
local function publish(player: Player): any
	local view = PlayerDataService.getLuck(player)
	if view then
		player:SetAttribute(LuckConfig.MultiplierAttribute, view.multiplier)
		player:SetAttribute(LuckConfig.EndsAtAttribute, if view.multiplier ~= 1 then os.time() + view.secondsLeft else 0)
	end
	return view
end

function LuckService.start()
	if started then
		return
	end
	started = true
	local set = LuckRemotes.createOnServer(ReplicatedStorage)

	set.get.OnServerInvoke = function(player: Player): any
		if tooSoon(player) then
			return nil
		end
		return publish(player)
	end

	set.spin.OnServerInvoke = function(player: Player): any
		if tooSoon(player) or games[player] ~= nil then
			return { outcome = "Busy" }
		end
		if not inRoom(player) then
			return { outcome = "TooFar", view = PlayerDataService.getLuck(player) }
		end
		-- Every wedge is as likely as any other: a result's chance is its wedges / WedgeCount, as the wheel shows.
		local wedge = random:NextInteger(1, LuckConfig.WedgeCount)
		local outcome, multiplier, free = PlayerDataService.spinLuckWheel(player, wedge)
		local view = publish(player)
		if outcome ~= "Spun" then
			return { outcome = outcome or "Rejected", view = view }
		end
		return { outcome = "Spun", wedge = wedge, multiplier = multiplier, free = free, view = view }
	end

	set.gameStart.OnServerInvoke = function(player: Player, kind: any): any
		if tooSoon(player) then
			return { outcome = "Busy" }
		end
		if typeof(kind) ~= "string" or kind ~= "Shuffle" then
			return { outcome = "Rejected" }
		end
		local running = games[player]
		if running and os.clock() <= running.latest then
			return { outcome = "Busy" }
		end
		games[player] = nil
		if not inRoom(player) then
			return { outcome = "TooFar", view = PlayerDataService.getLuck(player) }
		end
		local outcome = PlayerDataService.startCowGame(player)
		if outcome ~= "Started" then
			return { outcome = outcome or "Rejected", view = PlayerDataService.getLuck(player) }
		end
		-- Where the steak starts, and every swap (two of the three places change over); the steak rides its cloche.
		local shuffle = LuckConfig.Shuffle
		local start = random:NextInteger(1, 3)
		local at = start
		local swaps: { { number } } = {}
		local show = shuffle.RevealSeconds
		for index = 1, shuffle.Swaps do
			local stays = random:NextInteger(1, 3)
			local a, b = if stays == 1 then 2 else 1, if stays == 3 then 2 else 3
			table.insert(swaps, { a, b })
			if at == a then
				at = b
			elseif at == b then
				at = a
			end
			show += LuckConfig.swapSeconds(index)
		end
		local now = os.clock()
		games[player] = { final = at, earliest = now + show - EARLY_ALLOWED, latest = now + show + shuffle.AnswerSeconds + LATE_ALLOWED }
		return { outcome = "Started", start = start, swaps = swaps, view = PlayerDataService.getLuck(player) }
	end

	set.gameFinish.OnServerInvoke = function(player: Player, pick: any): any
		local running = games[player]
		games[player] = nil
		if running == nil or tooSoon(player) then
			return { outcome = "Rejected", view = PlayerDataService.getLuck(player) }
		end
		local now = os.clock()
		if now > running.latest then
			return { outcome = "TooLate", final = running.final, view = PlayerDataService.getLuck(player) }
		end
		-- An answer before the swaps could have been watched, or one that isn't a cloche: the try is spent, no spin.
		if now < running.earliest or typeof(pick) ~= "number" or (pick ~= 1 and pick ~= 2 and pick ~= 3) then
			return { outcome = "Rejected", final = running.final, view = PlayerDataService.getLuck(player) }
		end
		if pick ~= running.final then
			return { outcome = "Lost", final = running.final, view = PlayerDataService.getLuck(player) }
		end
		local spins = PlayerDataService.addLuckSpins(player, 1, true)
		print(string.format("[LuckService] %s beat the cow at the shuffle: %s spins waiting", player.Name, tostring(spins)))
		return { outcome = "Won", final = running.final, view = PlayerDataService.getLuck(player) }
	end

	local function joined(player: Player)
		task.spawn(function()
			if PlayerDataService.waitForData(player) then
				publish(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in ipairs(Players:GetPlayers()) do
		joined(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAsked[player] = nil
		games[player] = nil
	end)
end

return LuckService
