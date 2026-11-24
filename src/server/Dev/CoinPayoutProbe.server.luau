--!strict
--[[
	CoinPayoutProbe
	Server / Dev

	DEV TOOL, NOT GAMEPLAY. Checks the money system's meet payout (GAME_DESIGN
	30.6, step 3) in Studio and prints a pass/fail line per check:

		1. MeetPayout's sums (finishing, 9/9, place, the level, the gym record
		   bonus) for made-up meets (GAME_DESIGN §41.4)
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
	FinishBonus = 500,
	PerfectBonus = 200,
	PlaceBonus = { 200, 130, 70 },
	GymRecordBonus = 100,
	OverLimitBonus = 50,
	OverLimitStepBonus = 25,
	OverLimitStepPercent = 0.05,
}

print("=== Coin payout probe (GAME_DESIGN §41.4) ===")

print("1. a Local meet: finishing, 9/9 and place")
do
	local lifters: { MeetPayout.Lifter } = {
		{ key = 1, place = 1, hasTotal = true, perfect = true },
		{ key = 2, place = 2, hasTotal = true, perfect = false },
		{ key = 3, place = 3, hasTotal = true, perfect = false },
		{ key = 4, place = 4, hasTotal = true, perfect = false },
	}
	local pay = MeetPayout.forMeet(lifters, S, 1)
	check("1st with 9/9: 500 + 200 + 200 = 900", total(pay[1]) == 900, tostring(total(pay[1])))
	check("2nd: 500 + 130 = 630", total(pay[2]) == 630, tostring(total(pay[2])))
	check("3rd: 500 + 70 = 570", total(pay[3]) == 570, tostring(total(pay[3])))
	check("4th: only the finishing 500 (a crate)", total(pay[4]) == 500, tostring(total(pay[4])))
	check("1st's reasons", pay[1][1].reason == "Finished with a total" and pay[1][2].reason == "9/9"
		and pay[1][3].reason == "1st place")
end

print("2. the level multiplies it all; bomb-outs earn nothing")
do
	local lifters: { MeetPayout.Lifter } = {
		{ key = 1, place = 1, hasTotal = true, perfect = true },
		{ key = 2, place = nil, hasTotal = false, perfect = false },
	}
	check("State x3: 900 x 3 = 2,700", total(MeetPayout.forMeet(lifters, S, 3)[1]) == 2700)
	check("Nationals x5: 900 x 5 = 4,500", total(MeetPayout.forMeet(lifters, S, 5)[1]) == 4500)
	check("a bomb-out earns nothing", total(MeetPayout.forMeet(lifters, S, 3)[2]) == 0)
	check("a meet with nobody pays nobody", next(MeetPayout.forMeet({}, S, 1)) == nil)
end

print("3. the gym record bonus, once a meet")
do
	local me = 42
	local function bonus(broken: any, multiplier: number?, paid: boolean?): number
		local item = MeetPayout.forGymRecord(me, broken, S, multiplier, paid)
		return if item then item.amount else 0
	end
	check("an empty spot pays nothing", bonus({ { record = "Squat", previous = nil } }) == 0)
	check("someone else's record pays 100", bonus({ { record = "Squat", previous = { userId = 7 } } }) == 100)
	check("your own record pays 100", bonus({ { record = "Squat", previous = { userId = me } } }) == 100)
	check("lift + Total broken pays once", bonus({ { record = "Squat", previous = { userId = 7 } }, { record = "Total", previous = { userId = 7 } } }) == 100)
	check("x3 at State", bonus({ { record = "Squat", previous = { userId = 7 } } }, 3) == 300)
	check("already paid this meet: nothing", bonus({ { record = "Bench", previous = { userId = 7 } } }, 1, true) == 0)
end

print("4. most a Local meet pays = two crates")
do
	local live = CoinConfig.LocalMeet
	check("500 + 200 + 200 + 100 = 1,000", live.FinishBonus + live.PerfectBonus + live.PlaceBonus[1] + live.GymRecordBonus == 1000)
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
