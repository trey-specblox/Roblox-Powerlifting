--!strict
--[[
	UIFancy
	Client / UI

	The UI kit's look as small building blocks, for screens that should not be one more plain panel (user 2026-11-19:
	"we cant have everything the same boring plain box"). Techniques copied from the user's kit
	(RobloxUIReferences/roblox-ui/kit: Decor.glow = UIShadow, Decor.rays, Decor.vignette, Decor.shine / gloss), the same
	ones CelebrationSpinner uses: chunky glossy buttons, outlined text, soft glows, turning rays.
]]

local TweenService = game:GetService("TweenService")

local UIFancy = {}

UIFancy.White = Color3.new(1, 1, 1)
UIFancy.Ink = Color3.fromRGB(12, 12, 16)
UIFancy.TitleFont = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
UIFancy.BodyFont = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)

function UIFancy.make(className: string, props: { [string]: any }): any
	local made = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(made :: any)[key] = value
		end
	end
	made.Parent = props.Parent
	return made
end
local make = UIFancy.make

function UIFancy.corner(target: GuiObject, radius: UDim)
	make("UICorner", { CornerRadius = radius, Parent = target })
end

function UIFancy.outline(target: GuiObject, thickness: number, colour: Color3?, transparency: number?): UIStroke
	return make("UIStroke", {
		Thickness = thickness, Color = colour or UIFancy.Ink, Transparency = transparency or 0,
		LineJoinMode = Enum.LineJoinMode.Round, Parent = target,
	})
end

-- A soft glow round a frame (the kit's Decor.glow: a UIShadow with no offset).
function UIFancy.glow(target: GuiObject, colour: Color3, blur: number, transparency: number)
	make("UIShadow", {
		Name = "Glow", Color = colour, Offset = UDim2.fromOffset(0, 0), BlurRadius = UDim.new(0, blur),
		Transparency = transparency, Parent = target,
	})
end

-- Outlined text: white (or `colour`) with a thick dark edge.
function UIFancy.words(parent: Instance, name: string, position: UDim2, size: UDim2, textSize: number, stroke: number,
	colour: Color3?, font: Font?): TextLabel
	local label = make("TextLabel", {
		Name = name, BackgroundTransparency = 1, Position = position, Size = size, FontFace = font or UIFancy.TitleFont,
		TextSize = textSize, TextColor3 = colour or UIFancy.White, Text = "", TextWrapped = true, Parent = parent,
	})
	if stroke > 0 then
		UIFancy.outline(label, stroke)
	end
	return label
end

--[[
	A chunky rounded button: a gradient fill with a dark edge, a soft shine on its top half and a gloss streak, and
	outlined white text; it grows a little under the mouse and springs when pressed. Returns the button, its fill's
	gradient (recolour it) and its label.
]]
function UIFancy.button(parent: Instance, name: string, text: string, position: UDim2, size: UDim2, top: Color3,
	bottom: Color3, textSize: number, onClick: () -> ()): (TextButton, UIGradient, TextLabel)
	local button = make("TextButton", {
		Name = name, BackgroundTransparency = 1, Position = position, Size = size, Text = "", AutoButtonColor = false,
		Parent = parent,
	})
	local fill = make("Frame", { Name = "Fill", BackgroundColor3 = UIFancy.White, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = button })
	UIFancy.corner(fill, UDim.new(0, 14))
	UIFancy.outline(fill, 3)
	local gradient = make("UIGradient", { Rotation = 90, Color = ColorSequence.new(top, bottom), Parent = fill })
	local shine = make("Frame", {
		Name = "Shine", BackgroundColor3 = UIFancy.White, BorderSizePixel = 0, Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 0.46, 0), Parent = fill,
	})
	UIFancy.corner(shine, UDim.new(0, 11))
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.45, 1), Parent = shine })
	local gloss = make("Frame", { Name = "Gloss", BackgroundColor3 = UIFancy.White, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = fill })
	UIFancy.corner(gloss, UDim.new(0, 14))
	make("UIGradient", {
		Rotation = -60,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.22, 1), NumberSequenceKeypoint.new(0.27, 0.78),
			NumberSequenceKeypoint.new(0.33, 0.78), NumberSequenceKeypoint.new(0.38, 1), NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = gloss,
	})
	local label = UIFancy.words(button, "Label", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), textSize, 3)
	label.Text = text
	label.ZIndex = 3
	local scale = make("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.04 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		scale.Scale = 0.94
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		onClick()
	end)
	return button, gradient, label
end

-- Rays round the middle of `parent` (the kit's Decor.rays), `count` of them; turn the returned frame to spin them.
function UIFancy.rays(parent: Instance, position: UDim2, size: number, count: number, colour: Color3): Frame
	local rays = make("Frame", {
		Name = "Rays", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = position,
		Size = UDim2.fromOffset(size, size), Parent = parent,
	})
	for i = 1, count do
		local arm = make("Frame", {
			Name = "Arm", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Rotation = (360 / count) * (i - 1), Parent = rays,
		})
		local ray = make("Frame", {
			Name = "Ray", BackgroundColor3 = colour, BackgroundTransparency = 0.8, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.07, 0.5), Parent = arm,
		})
		make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.1), Parent = ray })
	end
	return rays
end

-- Darker bands at the top and bottom of `parent` so words on it read (the kit's Decor.vignette).
function UIFancy.vignette(parent: Instance, top: number, bottom: number)
	for _, atBottom in ipairs({ false, true }) do
		local band = make("Frame", {
			Name = "Vignette", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, if atBottom then 1 else 0), Position = UDim2.fromScale(0, if atBottom then 1 else 0),
			Size = UDim2.fromScale(1, if atBottom then bottom else top), Parent = parent,
		})
		make("UIGradient", { Rotation = if atBottom then 90 else -90, Transparency = NumberSequence.new(1, 0.2), Parent = band })
	end
end

return UIFancy
