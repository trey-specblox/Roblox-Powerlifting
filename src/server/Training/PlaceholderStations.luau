--!strict
--[[
	PlaceholderStations
	Server / Training

	TEMPORARY. Builds plain grey platforms for the gym training racks of
	checkpoint 5B.6, so training can be tested before any real rack model
	exists. Delete this file, and TrainingStationConfig.PlaceholderStations,
	once real models are placed.

	It builds GEOMETRY ONLY, tagged and given a StationId exactly the way a real
	rack will be. Prompts, the status sign, occupancy and every rule
	belong to TrainingStationService, which finds every rack through the tag,
	so replacing these platforms with real models needs no code change there.

	Built on the server, so the platforms exist on the server and replicate to
	clients. A client cannot add a rack: anything it creates or tags locally never
	reaches the server, and the service only trusts racks the server can see.
]]

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local PlaceholderStations = {}

export type BuiltStation = {
	stationId: string,
	part: BasePart,
	-- Where the player is expected to stand: the middle of the platform's top.
	standPosition: Vector3,
}

local PLATFORM_SIZE = Vector3.new(8, 1, 8)
local PLATFORM_COLOR = Color3.fromRGB(90, 110, 140)

--[[
	Creates one tagged platform per config entry under Workspace.TrainingStations
	and returns them. TrainingStationService registers them through the tag.
]]
function PlaceholderStations.build(
	entries: { { stationId: string, position: Vector3 } },
	tag: string
): { BuiltStation }
	local folder = Instance.new("Folder")
	folder.Name = "TrainingStations"

	local built: { BuiltStation } = {}

	for _, entry in ipairs(entries) do
		local platform = Instance.new("Part")
		platform.Name = entry.stationId
		platform.Size = PLATFORM_SIZE
		-- Config positions are on the Baseplate's top surface; lift the platform onto it.
		platform.Position = entry.position + Vector3.new(0, PLATFORM_SIZE.Y / 2, 0)
		platform.Anchored = true
		platform.CanCollide = true
		platform.Material = Enum.Material.SmoothPlastic
		platform.Color = PLATFORM_COLOR
		platform.TopSurface = Enum.SurfaceType.Smooth
		platform.BottomSurface = Enum.SurfaceType.Smooth
		platform:SetAttribute("StationId", entry.stationId)
		CollectionService:AddTag(platform, tag)
		platform.Parent = folder

		table.insert(built, {
			stationId = entry.stationId,
			part = platform :: BasePart,
			standPosition = platform.Position + Vector3.new(0, PLATFORM_SIZE.Y / 2, 0),
		})
	end

	folder.Parent = Workspace

	return built
end

return PlaceholderStations
