--!strict
--[[
	CoinPayoutProbe
	Server / Dev

	DEV TOOL, NOT GAMEPLAY. Checks the money system's meet payout (GAME_DESIGN
	30.6, step 3) in Studio and prints a pass/fail line per check:

		1. MeetPayout's sums (pot, place shares, finishing, 9/9, gym record
		   bonus) for made-up meets
		2. the real coin path: pays the first player in the server a few
		   payouts through PlayerDataService.addCoins, exactly as a meet does,
		   so the counter and the pop-ups can be watched

	Studio only, and OFF BY DEFAULT: set ENABLED to true, play, then set it back.
	Studio does not save player data while API access is off, so the coins it
	pays disappear when Play stops. Nothing requires this file.
]]

local ENABLED = false

local RunService = game:GetService("RunService")
if not ENABLED or not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoinConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CoinConfig"))
local ServerFolder = script.Parent.Parent
local MeetPayout = require(ServerFolder:WaitForChild("Meet"):WaitForChild("MeetPayout"))
local PlayerDataService = require(ServerFolder:WaitForChild("PlayerData"):WaitForChild("PlayerDataService"))

local passed, failed = 0, 0
local function check(label: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		print("  PASS  " .. label)
	else
		failed += 1
		warn("  FAIL  " .. label .. (if detail then "  -- " .. detail else ""))
	end
end

local function total(items: { MeetPayout.Item }?): number
	local sum = 0
	for _, item in ipairs(items or {}) do
		sum += item.amount
	end
	return sum
end

local S = {
	BasePot = 100,
	PerQualifiedLifter = 50,
	PlaceShares = { { 1 }, { 0.6, 0.4 }, { 0.5, 0.3, 0.2 } },
	FinishBonus = 25,
	PerfectBonus = 50,
	GymRecordBonus = 150,
	OwnGymRecordBonus = 40,
}

print("=== Coin payout probe ===")

print("1. a 4-lifter meet (the GAME_DESIGN 30.6 example)")
do
	local lifters: { MeetPayout.Lifter } = {
		{ key = 1, place = 1, hasTotal = true, qualified = true, perfect = true },
		{ key = 2, place = 2, hasTotal = true, qualified = true, perfect = false },
		{ key = 3, place = 3, hasTotal = true, qualified = true, perfect = false },
		{ key = 4, place = 4, hasTotal = true, qualified = true, perfect = false },
	}
	check("pot = 100 + 4 x 50 = 300", MeetPayout.pot(lifters, S) == 300)
	local pay = MeetPayout.forMeet(lifters, S)
	check("1st: 150 + 25 + 50 (9/9) = 225", total(pay[1]) == 225, tostring(total(pay[1])))
	check("2nd: 90 + 25 = 115", total(pay[2]) == 115, tostring(total(pay[2])))
	check("3rd: 60 + 25 = 85", total(pay[3]) == 85, tostring(total(pay[3])))
	check("4th: only the finishing 25", total(pay[4]) == 25, tostring(total(pay[4])))
	check("1st's reasons", pay[1][1].reason == "1st place" and pay[1][2].reason == "Finished with a total"
		and pay[1][3].reason == "9/9")
end

print("2. bomb-outs, withdrawals and AFK sign-ups")
do
	local lifters: { MeetPayout.Lifter } = {
		{ key = 1, place = 1, hasTotal = true, qualified = true, perfect = false },
		{ key = 2, place = nil, hasTotal = false, qualified = true, perfect = false }, -- bombed out
		{ key = 3, place = nil, hasTotal = false, qualified = false, perfect = false }, -- never started a lift
	}
	check("pot counts only lifters who started a lift: 100 + 2 x 50", MeetPayout.pot(lifters, S) == 200)
	local pay = MeetPayout.forMeet(lifters, S)
	check("the only lifter with a total takes the whole pot + 25", total(pay[1]) == 225, tostring(total(pay[1])))
	check("a bomb-out earns nothing", total(pay[2]) == 0)
	check("an AFK sign-up earns nothing", total(pay[3]) == 0)
end

print("3. two placed lifters split 60 / 40")
do
	local lifters: { MeetPayout.Lifter } = {
		{ key = 1, place = 1, hasTotal = true, qualified = true, perfect = false },
		{ key = 2, place = 2, hasTotal = true, qualified = true, perfect = false },
	}
	local pay = MeetPayout.forMeet(lifters, S)
	check("1st: 120 + 25", total(pay[1]) == 145, tostring(total(pay[1])))
	check("2nd: 80 + 25", total(pay[2]) == 105, tostring(total(pay[2])))
	local none = MeetPayout.forMeet({}, S)
	check("a meet with nobody pays nobody", next(none) == nil)
end

print("4. the gym record bonus")
do
	local me = 42
	local function bonus(broken: any): number
		local item = MeetPayout.forGymRecord(me, broken, S)
		return if item then item.amount else 0
	end
	check("an empty spot pays nothing", bonus({ { record = "Squat", previous = nil } }) == 0)
	check("someone else's record pays 150", bonus({ { record = "Squat", previous = { userId = 7 } } }) == 150)
	check("your own record pays 40", bonus({ { record = "Squat", previous = { userId = me } } }) == 40)
	check("lift + Total broken pays once, not twice",
		bonus({ { record = "Squat", previous = { userId = 7 } }, { record = "Total", previous = { userId = 7 } } }) == 150)
	check("own lift + someone else's Total pays the better one once",
		bonus({ { record = "Squat", previous = { userId = me } }, { record = "Total", previous = { userId = 7 } } }) == 150)
	check("empty lift + empty Total pays nothing",
		bonus({ { record = "Squat", previous = nil }, { record = "Total", previous = nil } }) == 0)
	local item = MeetPayout.forGymRecord(me, { { record = "Bench", previous = { userId = 7 } } }, S)
	check("its reason names the lift", item ~= nil and item.reason == "Gym record: Bench")
end

print("5. the live settings are the planned ones")
do
	local live = CoinConfig.LocalMeet
	check("CoinConfig.LocalMeet matches GAME_DESIGN 30.6", live.BasePot == 100 and live.PerQualifiedLifter == 50
		and live.FinishBonus == 25 and live.PerfectBonus == 50 and live.GymRecordBonus == 150
		and live.OwnGymRecordBonus == 40 and live.PlaceShares[3][1] == 0.5)
end

print(string.format("=== %d passed, %d failed ===", passed, failed))

-- 6. The real coin path, on the first player to load (watch the counter and the pop-ups).
task.spawn(function()
	local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	if PlayerDataService.waitForData(player, 60) == nil then
		warn("[CoinPayoutProbe] no player data: real coin path not tested")
		return
	end
	task.wait(4) -- let the client's counter start
	local before = PlayerDataService.getCoins(player) or -1
	local payouts: { MeetPayout.Item } = {
		{ amount = 150, reason = "1st place" },
		{ amount = 25, reason = "Finished with a total" },
		{ amount = 50, reason = "9/9" },
	}
	for _, item in ipairs(payouts) do
		PlayerDataService.addCoins(player, item.amount, item.reason)
	end
	local after = PlayerDataService.getCoins(player) or -1
	local outcome = PlayerDataService.spendCoins(player, 1000000, "Probe: too expensive")
	print(string.format("[CoinPayoutProbe] real path: %d -> %d coins (attribute %s); a 1,000,000 spend: %s", before, after,
		tostring(player:GetAttribute(CoinConfig.BalanceAttribute)), tostring(outcome)))
end)
