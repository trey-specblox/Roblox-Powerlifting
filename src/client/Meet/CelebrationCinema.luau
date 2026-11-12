--!strict
--[[
	CelebrationCinema
	Client / Meet

	The cinematic of a Legendary celebration (CelebrationConfig `cinematic`; user 2026-11-11: "if there is a REALLY
	dramatic celebration, you can add cinematic to them like the coach ritual cinematic specially with the lightings"),
	on the celebrating player's own screen only. When the server says it started (CelebrationRemotes, through
	CelebrationFx), the camera cuts
	through its shots, framed around the lifter as they stood when it began, with the coach ritual's film look
	(MeetCinema: black bars, a soft background, every other screen out of the way, a hand-held drift) and the lifter lit
	for it: a coloured key light from the front, a white rim light from behind, a tint and more haze. All put back after.

	Shots (from the source videos' camera work, References/Clip Study):
		FrontMid   in front at chest height          Close     a close three-quarter on the face
		LowFront   low in front, looking up           Wide      far in front, the whole body
		Side       from the side, chest height        LowSide   low from the side (floor moves)
		BackHigh   high behind, over the shoulder at the crowd

	Display only: it decides and saves nothing.
	PERFORMANCE: while it runs, one camera move and one ray a frame, two lights (the key one casts shadows), one colour
	effect. Nothing at all otherwise, but once on joining it fetches the body sounds, the Default's animation and its
	sound track, so they're ready the first time.
]]

local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CelebrationConfig = require(Shared:WaitForChild("Config"):WaitForChild("CelebrationConfig"))

local MeetCinema = require(script.Parent:WaitForChild("MeetCinema"))

local CelebrationCinema = {}

local RENDER_NAME = "CelebrationCinema"
local CLEAR_PART = 0.95
local LOOK_IN_SECONDS = 0.6

type Run = {
	celebration: CelebrationConfig.Celebration,
	startedAt: number,
	base: CFrame,
	shot: string?,
	shotStart: number,
	params: RaycastParams,
	cameraType: Enum.CameraType,
	lights: { Instance },
	tint: ColorCorrectionEffect,
	atmosphere: Atmosphere?,
	density: number?,
	token: number,
}
local run: Run? = nil
local token = 0

local function part(model: Model?, name: string): BasePart?
	local found = model and model:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

local function flat(vector: Vector3): Vector3
	local level = Vector3.new(vector.X, 0, vector.Z)
	return if level.Magnitude > 0.01 then level.Unit else Vector3.new(0, 0, -1)
end

-- As far from `subject` toward `eye` as the camera can go without passing through something solid and visible.
local function clearOf(subject: Vector3, eye: Vector3, params: RaycastParams): Vector3
	local ignored = table.clone(params.FilterDescendantsInstances)
	for _ = 1, 4 do
		local hit = Workspace:Raycast(subject, eye - subject, params)
		if hit == nil then
			return eye
		end
		if hit.Instance.Transparency < CLEAR_PART then
			return hit.Position + (subject - eye).Unit * 0.4
		end
		table.insert(ignored, hit.Instance)
		params.FilterDescendantsInstances = ignored
	end
	return eye
end

local function shotAt(shots: { CelebrationConfig.Shot }, elapsed: number): string
	local name = shots[1].shot
	for _, shot in ipairs(shots) do
		if elapsed >= shot.at then
			name = shot.shot
		end
	end
	return name
end

-- A light on an invisible part, pointing at `at` (client only: nobody else sees it).
local function light(from: Vector3, at: Vector3, colour: Color3, brightness: number, shadows: boolean): Part
	local holder = Instance.new("Part")
	holder.Name = "CelebrationLight"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.lookAt(from, at)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Color = colour
	spot.Brightness = brightness
	spot.Range = 40
	spot.Angle = 50
	spot.Shadows = shadows
	spot.Parent = holder
	holder.Parent = Workspace
	return holder
end

local function finish()
	local current = run
	if current == nil then
		return
	end
	run = nil
	RunService:UnbindFromRenderStep(RENDER_NAME)
	MeetCinema.close()
	for _, item in ipairs(current.lights) do
		item:Destroy()
	end
	current.tint:Destroy()
	local atmosphere, density = current.atmosphere, current.density
	if atmosphere and density then
		TweenService:Create(atmosphere, TweenInfo.new(0.6), { Density = density }):Play()
	end
	local camera = Workspace.CurrentCamera
	if current.cameraType ~= Enum.CameraType.Scriptable then
		local humanoid = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		camera.CameraType = current.cameraType
	end
end

local function step()
	local current = run
	if current == nil then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local character = Players.LocalPlayer.Character
	local head = part(character, "Head")
	local chest = part(character, "UpperTorso")
	local hips = part(character, "LowerTorso")
	if head == nil or chest == nil or hips == nil then
		return
	end
	local elapsed = Workspace:GetServerTimeNow() - current.startedAt
	local cinematic = current.celebration.cinematic
	if cinematic == nil then
		return
	end
	local name = shotAt(cinematic.shots, elapsed)
	if name ~= current.shot then
		current.shot = name
		current.shotStart = os.clock()
	end
	local base = current.base
	local forward, right, up = base.LookVector, base.RightVector, Vector3.yAxis
	local at = base.Position
	local eye: Vector3
	local look: Vector3
	if name == "Close" then
		eye = at + forward * 3.4 + right * 1.0 + up * 1.4
		look = head.Position - up * 0.1
	elseif name == "LowFront" then
		eye = at + forward * 7.2 - right * 0.8 - up * 2.2
		look = chest.Position + up * 0.3
	elseif name == "Wide" then
		eye = at + forward * 15 + right * 2 + up * 2.6
		look = chest.Position
	elseif name == "Side" then
		eye = at + right * 10 + forward * 1.4 + up * 0.7
		look = chest.Position
	elseif name == "LowSide" then
		eye = at + right * 6.5 + forward * 1.6 - up * 2.1
		look = hips.Position + up * 0.4
	elseif name == "BackHigh" then
		eye = at - forward * 6.5 + right * 1.6 + up * 4.4
		look = head.Position + forward * 5 + up * 0.5
	else -- FrontMid
		eye = at + forward * 7.5 - right * 1.2 + up * 0.7
		look = chest.Position + up * 0.2
	end
	-- A slow push in through each shot.
	local shotTime = os.clock() - current.shotStart
	eye = eye:Lerp(look, 0.08 * math.min(1, shotTime / 3))
	eye = clearOf(look, eye, current.params)
	MeetCinema.focus((eye - look).Magnitude)
	camera.CFrame = CFrame.lookAt(eye, look) * MeetCinema.handheld(os.clock())
	if elapsed >= current.celebration.seconds then
		finish()
	end
end

--[[
	Runs celebration `id`'s cinematic, as of `startedAt` (Workspace:GetServerTimeNow()). Nothing for one without a
	cinematic, or with no character.
]]
function CelebrationCinema.play(id: string, startedAt: number)
	local celebration = CelebrationConfig.byId[id]
	local cinematic = celebration and celebration.cinematic
	local character = Players.LocalPlayer.Character
	local root = part(character, "HumanoidRootPart")
	if celebration == nil or cinematic == nil or root == nil or character == nil then
		return
	end
	finish()
	token += 1
	local camera = Workspace.CurrentCamera
	local base = CFrame.lookAt(root.Position, root.Position + flat(root.CFrame.LookVector))
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = false

	-- The look: a key light from the front in the cinematic's colour, a white rim light from behind, a tint, more haze.
	local look = cinematic.look
	local lights: { Instance } = {
		light(base.Position + base.LookVector * 9 + Vector3.new(0, 12, 0), base.Position, look.key, 2.6, true),
		light(base.Position - base.LookVector * 7 + Vector3.new(0, 10, 0), base.Position + Vector3.new(0, 1.5, 0),
			Color3.new(1, 1, 1), 2.4, false),
	}
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "CelebrationLook"
	-- (Half way to the cinematic's tint: the full one washed a bright room out, Studio test 2026-11-11.)
	tint.TintColor = Color3.new(1, 1, 1):Lerp(look.tint, 0.5)
	tint.Contrast = 0.08
	tint.Saturation = 0.08
	tint.Parent = Lighting
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local density = atmosphere and atmosphere.Density
	if atmosphere and density then
		TweenService:Create(atmosphere, TweenInfo.new(0.8), { Density = math.min(1, density + look.haze * 0.5) }):Play()
	end

	run = {
		celebration = celebration,
		startedAt = startedAt,
		base = base,
		shot = nil,
		shotStart = os.clock(),
		params = params,
		cameraType = camera.CameraType,
		lights = lights,
		tint = tint,
		atmosphere = atmosphere,
		density = density,
		token = token,
	}
	MeetCinema.open()
	MeetCinema.caption(string.upper(celebration.rarity), string.upper(celebration.name))
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 5, step)
	-- (Safety: never longer than the celebration plus a moment, whatever happens to the clock.)
	local mine = token
	task.delay(celebration.seconds + LOOK_IN_SECONDS + 1, function()
		local current = run
		if current and current.token == mine then
			finish()
		end
	end)
end

-- Ends it at once (the player left the meet, died...).
function CelebrationCinema.stop()
	finish()
end

function CelebrationCinema.start()
	-- The celebration sounds and the Default's animation fetched now, in the background, so a player's first celebration
	-- doesn't start before its roar has arrived (Studio test 2026-11-11: the first roar wasn't loaded in time).
	-- (As Sound and Animation objects: bare id strings are fetched as images and warn "Asset type does not match".)
	task.spawn(function()
		local items: { Instance } = {}
		for _, sound in pairs(CelebrationConfig.Sounds) do
			for _, id in ipairs(sound.ids) do
				local item = Instance.new("Sound")
				item.SoundId = id
				table.insert(items, item)
			end
		end
		local default = CelebrationConfig.byId[CelebrationConfig.Default]
		if default then
			local animation = Instance.new("Animation")
			animation.AnimationId = default.animationId
			table.insert(items, animation)
			if default.soundtrack then
				local track = Instance.new("Sound")
				track.SoundId = default.soundtrack
				table.insert(items, track)
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(items)
		end)
		for _, item in ipairs(items) do
			item:Destroy()
		end
	end)
	-- (The server's "a celebration started" comes through CelebrationFx, which hands this player's own to play.)
	Players.LocalPlayer.CharacterRemoving:Connect(function()
		finish()
	end)
end

return CelebrationCinema
