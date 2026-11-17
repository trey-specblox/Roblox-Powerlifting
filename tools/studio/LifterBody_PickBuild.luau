--[[
	LifterBody_PickBuild (TEMPORARY TEST TOOL, Studio Command Bar, run in EDIT mode before pressing Play)

	What it does: sets ONE workspace attribute, LifterBodyBuild, to the build named below, so your character
	spawns with that body in the next Studio play test (LifterBodyService.buildFor reads it in Studio only; the
	live game ignores it). Also checks that the Studio copy of ClothesConfig has the new (2026-11-16) body ids, so
	you know Rojo has synced them. Touches nothing else. Safe to run again with another build.

	Builds: "Skinny", "SkinnyFat", "Fat", "Fit", "Muscular", "BigBuff"
	To go back to the normal choice (your bodyweight and numbers): set BUILD = nil.
]]

local BUILD: string? = "Fit"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[PickBuild] FAILED: stop the play test first, run this in Edit mode, then press Play.")
	return
end

local shared = ReplicatedStorage:FindFirstChild("Shared")
local configFolder = shared and shared:FindFirstChild("Config")
local module = configFolder and configFolder:FindFirstChild("ClothesConfig")
if module == nil or not module:IsA("ModuleScript") then
	warn("[PickBuild] FAILED: ReplicatedStorage.Shared.Config.ClothesConfig not found. Is Rojo connected?")
	return
end

-- Rojo sync check: the Fit body uploaded on 2026-11-16 (CartoonBody08_Fit).
local NEW_FIT_BODY = "77562974459220"
if not string.find(module.Source, NEW_FIT_BODY, 1, true) then
	warn("[PickBuild] FAILED: Studio still has the OLD body ids. Connect Rojo (Rojo plugin > Connect) and run this again.")
	return
end

local BUILDS = { Skinny = true, SkinnyFat = true, Fat = true, Fit = true, Muscular = true, BigBuff = true }
if BUILD ~= nil and not BUILDS[BUILD] then
	warn("[PickBuild] FAILED: unknown build '" .. tostring(BUILD) .. "'. Use one of: Skinny, SkinnyFat, Fat, Fit, Muscular, BigBuff.")
	return
end

workspace:SetAttribute("LifterBodyBuild", BUILD)
if BUILD then
	print("[PickBuild] OK: next play test spawns you as " .. BUILD .. ". Rojo has the new body ids.")
else
	print("[PickBuild] OK: build override cleared (normal choice by bodyweight). Rojo has the new body ids.")
end
