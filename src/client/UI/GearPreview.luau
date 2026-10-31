--!strict
--[[
	GearPreview
	Client / UI

	A 3D preview of a Shop item (ShopConfig) in a ViewportFrame: the Shop's
	gear model (ReplicatedStorage[ShopRemotes.PREVIEWS_NAME]) in the item's
	colours, framed on its coloured parts. Used by the Shop menu and MY GEAR.
	Without the models it shows the item's main colours as stripes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopConfig = require(Shared:WaitForChild("Config"):WaitForChild("ShopConfig"))
local ShopRemotes = require(Shared:WaitForChild("Economy"):WaitForChild("ShopRemotes"))

local UIStyle = require(script.Parent:WaitForChild("UIStyle"))
local C = UIStyle.Colours

local GearPreview = {}

function GearPreview.build(parent: GuiObject, item: ShopConfig.Item, position: UDim2, size: UDim2): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.Position = position
	viewport.Size = size
	viewport.BackgroundColor3 = C.navyDeep
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(170, 170, 180)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.6)
	viewport.Parent = parent
	local models = ReplicatedStorage:FindFirstChild(ShopRemotes.PREVIEWS_NAME)
	local template = models and models:FindFirstChild(item.model)
	if template == nil or not template:IsA("Model") then
		local index = 0
		for _, colour in pairs(item.colours) do
			if index < 3 then
				local stripe = UIStyle.frame(viewport, "Swatch", UDim2.fromScale(0.15 + index * 0.25, 0.2),
					UDim2.fromScale(0.2, 0.6), colour)
				stripe.BorderSizePixel = 0
			end
			index += 1
		end
		return viewport
	end
	local model = template:Clone()
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local suffix = string.match(part.Name, "^" .. item.model .. "_(.+)$")
			local colour = suffix and item.colours[suffix]
			if colour then
				part.Color = colour
			end
		end
	end
	model:PivotTo(CFrame.new())
	model.Parent = viewport
	-- Framed on the item's own coloured parts (a singlet, not its mannequin's stand), else the whole model.
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in ipairs(model:GetDescendants()) do
		local suffix = if part:IsA("BasePart") then string.match(part.Name, "^" .. item.model .. "_(.+)$") else nil
		if part:IsA("BasePart") and suffix and item.colours[suffix] then
			low = low:Min(part.Position - part.Size / 2)
			high = high:Max(part.Position + part.Size / 2)
		end
	end
	local centre, extent
	if low.X <= high.X then
		centre, extent = (low + high) / 2, high - low
	else
		local cf, whole = model:GetBoundingBox()
		centre, extent = cf.Position, whole
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local radius = extent.Magnitude / 2
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
	local direction = Vector3.new(0.55, 0.3, -1).Unit
	camera.CFrame = CFrame.lookAt(centre + direction * distance, centre)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

return GearPreview
