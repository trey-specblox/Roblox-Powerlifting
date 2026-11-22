--!strict
--[[
	KitchenLights
	Server / Economy

	W Chews' lighting (GAME_DESIGN §40.7, user 2026-11-21: "Light the restaurant"). Before this the hall stood in open
	sunlight (nothing in it cast a shadow), so every room looked the same flat daylight.

		- SUN BLOCKERS: plain thick blocks outside the walls and over the ceilings, where nobody can see them, so no
		  sunlight reaches the inside. Thick on purpose: on phones and far from the camera Roblox works shadows out on a
		  coarse grid, and a thin ceiling lets the sun leak through it in patches (the "blue shade here, sunlit there"
		  floor of Studio 2026-11-21). A canopy over the glass front keeps the sun off the dining room's floor.
		- THE DINING ROOM: dim and warm. A cone of warm light under every hanging pendant (a pool on each table and on
		  the service counter), the chandelier over the carpet, and a soft wash from each wall light.
		- THE KITCHEN: bright and clean white from 15 big, far-reaching lights under the ceiling (few wide lights
		  light a room this size more evenly, and more cheaply, than one small light under each of the 45 panels),
		  plus one key light on the grinder from the side (the centre of the room and of the chef scene).

	PERFORMANCE: 15 plain blocks and 64 lights (53 in the restaurant, 11 in the back room: its four pendants, its
	chandelier, five fills and a spot on the wheel), none of them casting shadows (the costly part of a light). The
	world had 344 shadowless lights before this. The dining room's are small on purpose (each covers little of the
	screen); on low graphics settings Roblox draws local lights the cheap way by itself.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitchenConfig = require(Shared:WaitForChild("Config"):WaitForChild("KitchenConfig"))
local StarterGymConfig = require(Shared:WaitForChild("Config"):WaitForChild("StarterGymConfig"))
local WChewsLayout = require(Shared:WaitForChild("Config"):WaitForChild("WChewsLayout"))

local ServerFolder = script.Parent.Parent
local StyledScreen = require(ServerFolder:WaitForChild("World"):WaitForChild("StyledScreen"))

local KitchenLights = {}

local WARM = Color3.fromRGB(255, 200, 142) -- the dining room's bulbs
local WHITE = StarterGymConfig.LightColor -- the kitchen's panels
local BLOCKER_COLOUR = Color3.fromRGB(38, 36, 36)

-- The dining room (numbers tuned by picture in Studio, 2026-11-21).
local PENDANT = { range = 18, brightness = 2.2, angle = 105 }
local CHANDELIER = { range = 40, brightness = 0.85 }
local SCONCE = { range = 12, brightness = 0.9 }
local SCONCE_YS = { -89, -71, -53, -35 } -- (as build_wchews_hall_01.py's front_sconces)
local SCONCE_X = 78.4 -- just inside the side walls (x 80)
local SCONCE_HEIGHT = 11.5
-- The kitchen (x -285..285, y -20..265): a grid of wide lights a little under the ceiling.
-- Point lights, so the ceiling is lit too (cones pointing down left the ceiling and upper walls dark: Studio).
local PANEL = { range = 110, brightness = 0.5 } -- (1.4 burned the white walls out)
local PANEL_XS = { -208, -104, 0, 104, 208 }
local PANEL_YS = { 34, 130, 226 }
local PANEL_DROP = 6
-- A key light on the grinder from one side, so the steel keeps its shape (lit from the front it went flat white in
-- the chef scene's close-up: Studio). Plan space: where it hangs, and what it points at.
local HERO = { range = 46, brightness = 0.9, angle = 60 }
local HERO_FROM = Vector3.new(-26, 28, 30)
-- The back room's fills (where they hang is WChewsLayout.BackFills: they move with the room).
local BACK_FILL = { range = 38, brightness = 0.75 }
local HERO_ONTO = Vector3.new(0, 52, 8)

-- A hidden anchored point to carry a light.
local function lightPoint(parent: Instance, name: string, at: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = at
	part.Parent = parent
	return part
end

local function pointLight(parent: Instance, look: { range: number, brightness: number }, colour: Color3)
	local light = Instance.new("PointLight")
	light.Range = look.range
	light.Brightness = look.brightness
	light.Color = colour
	light.Shadows = false
	light.Parent = parent
end

-- A cone of light straight down out of `part`.
local function downLight(part: BasePart, look: { range: number, brightness: number, angle: number }, colour: Color3)
	local light = Instance.new("SpotLight")
	light.Face = StyledScreen.faceToward(part, -Vector3.yAxis)
	light.Range = look.range
	light.Brightness = look.brightness
	light.Angle = look.angle
	light.Color = colour
	light.Shadows = false
	light.Parent = part
end

--[[
	Builds the sun blockers and every light. `kit`: the folder of placed kit copies (the pendants and the chandelier
	carry their own lights); `hall0`: the hall's origin. Returns how many lights it made.
]]
function KitchenLights.build(hallFolder: Instance, kit: Instance, hall0: CFrame): number
	local folder = Instance.new("Folder")
	folder.Name = "KitchenLights"
	folder.Parent = hallFolder

	-- A plain block between two plan corners and two heights (PLAN space: x across, y front to back).
	local function blocker(name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = BLOCKER_COLOUR
		part.Size = Vector3.new(math.abs(x1 - x0), math.abs(z1 - z0), math.abs(y1 - y0))
		part.CFrame = hall0 * KitchenConfig.planSpot((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
		part.Parent = folder
	end
	local top = WChewsLayout.KitchenHeight + 11
	-- The kitchen (x -285..285, y -20..265, 36 high; its walls and ceiling end at 287, -22, 267 and 37).
	blocker("SunBlock_KitchenRoof", -297, 297, -32, 277, 37.2, top)
	blocker("SunBlock_KitchenLeft", -297, -287.2, -32, 277, -1, 37.2)
	blocker("SunBlock_KitchenRight", 287.2, 297, -32, 277, -1, 37.2)
	-- (the kitchen's back wall, either side of the back room that stands behind its middle)
	local room, thick = WChewsLayout.BackRoom, WChewsLayout.WallThickness
	local roomLeft, roomRight = room.X0 - thick - 0.2, room.X1 + thick + 0.2
	local roomEnd, roomRoof = room.Y1 + thick + 0.2, WChewsLayout.BackHeight + 1.2
	blocker("SunBlock_KitchenBack", -287.2, roomLeft, 267.2, 277, -1, 37.2)
	blocker("SunBlock_KitchenBackRight", roomRight, 287.2, 267.2, 277, -1, 37.2)
	blocker("SunBlock_KitchenFrontLeft", -287.2, -82.2, -32, -22.2, -1, 37.2)
	blocker("SunBlock_KitchenFrontRight", 82.2, 287.2, -32, -22.2, -1, 37.2)
	-- The fancy front (x -80..80, y -110..-20, 22 high; its walls and ceiling end at 82, -112 and 23).
	blocker("SunBlock_FrontRoof", -92, 92, -112.2, -22.2, 23.2, top)
	blocker("SunBlock_FrontLeft", -92, -82.2, -112.2, -32, -1, 23.2)
	blocker("SunBlock_FrontRight", 82.2, 92, -112.2, -32, -1, 23.2)
	-- A canopy over the glass front (the glass stops at 17): the sun comes from the front at 53 degrees and would
	-- reach 9 studs in through the glass.
	blocker("SunBlock_FrontCanopy", -96, 96, -127, -112.2, 17.4, top)
	-- The back room (WChewsLayout.BackRoom, 18 high; its walls are 2 thick and its ceiling ends at 19), and the
	-- kitchen's back wall above it.
	blocker("SunBlock_BackRoomRoof", roomLeft - 9.8, roomRight + 9.8, 267.2, roomEnd + 9.8, roomRoof, top)
	blocker("SunBlock_BackRoomSides", roomLeft - 9.8, roomLeft, 277, roomEnd + 9.8, -1, roomRoof)
	blocker("SunBlock_BackRoomRight", roomRight, roomRight + 9.8, 277, roomEnd + 9.8, -1, roomRoof)
	blocker("SunBlock_BackRoomBack", roomLeft, roomRight, roomEnd, roomEnd + 9.8, -1, roomRoof)

	local lights = 0
	-- The dining room: every pendant and the chandelier (kit copies), and the wall lights (part of the shell's mesh).
	for _, copy in ipairs(kit:GetChildren()) do
		if copy.Name == "WcPendant" then
			local bulb = copy:FindFirstChild("WcPendant_Bulb", true)
			if bulb and bulb:IsA("BasePart") then
				downLight(bulb, PENDANT, WARM)
				lights += 1
			end
		elseif copy.Name == "WcChandelier" then
			local globes = copy:FindFirstChild("WcChandelier_Globes", true)
			if globes and globes:IsA("BasePart") then
				pointLight(globes, CHANDELIER, WARM)
				lights += 1
			end
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		for _, y in ipairs(SCONCE_YS) do
			pointLight(lightPoint(folder, "SconceLight", hall0 * KitchenConfig.planSpot(side * SCONCE_X, y, SCONCE_HEIGHT)),
				SCONCE, WARM)
			lights += 1
		end
	end
	-- The kitchen's grid of wide lights.
	for _, x in ipairs(PANEL_XS) do
		for _, y in ipairs(PANEL_YS) do
			pointLight(lightPoint(folder, "PanelLight",
				hall0 * KitchenConfig.planSpot(x, y, WChewsLayout.KitchenHeight - PANEL_DROP)), PANEL, WHITE)
			lights += 1
		end
	end
	-- The grinder's key light.
	local from = (hall0 * KitchenConfig.planSpot(HERO_FROM.X, HERO_FROM.Y, HERO_FROM.Z)).Position
	local onto = (hall0 * KitchenConfig.planSpot(HERO_ONTO.X, HERO_ONTO.Y, HERO_ONTO.Z)).Position
	local hero = lightPoint(folder, "GrinderLight", CFrame.lookAt(from, onto))
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Range = HERO.range
	spot.Brightness = HERO.brightness
	spot.Angle = HERO.angle
	spot.Color = WHITE
	spot.Shadows = false
	spot.Parent = hero
	lights += 1
	-- The back room (its pendants and chandelier carry their own, above): five soft warm fills so the walnut walls
	-- and the booths don't sink into black (with the fittings alone the room was a few pools in the dark: Studio),
	-- and a warm spot on the luck wheel.
	for _, at in ipairs(WChewsLayout.BackFills) do
		pointLight(lightPoint(folder, "BackFill", hall0 * KitchenConfig.planSpot(at.X, at.Y, at.Z)), BACK_FILL, WARM)
		lights += 1
	end
	local wheel = WChewsLayout.Wheel
	local wheelFrom = (hall0 * KitchenConfig.planSpot(wheel.X, wheel.Y - 13, WChewsLayout.BackHeight - 1)).Position
	local wheelOnto = (hall0 * KitchenConfig.planSpot(wheel.X, wheel.Y, WChewsLayout.WheelAxis)).Position
	local wheelSpot = Instance.new("SpotLight")
	wheelSpot.Face = Enum.NormalId.Front
	wheelSpot.Range = 30
	wheelSpot.Brightness = 1.0
	wheelSpot.Angle = 58
	wheelSpot.Color = Color3.fromRGB(255, 236, 200)
	wheelSpot.Shadows = false
	wheelSpot.Parent = lightPoint(folder, "WheelLight", CFrame.lookAt(wheelFrom, wheelOnto))
	lights += 1
	return lights
end

return KitchenLights
