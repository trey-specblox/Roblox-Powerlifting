--!strict
--[[
	RackConfigurator
	Server / Training

	Prepares ONE PowerRack_01-style rack Model (checkpoint 6D.2a) so the training
	service can use it: checks its 21 named MeshParts, anchors everything, makes
	only the four posts solid, and gives it an invisible StandPoint floor marker
	as its PrimaryPart (and therefore its pivot).

	It does NOT set a StationId and does NOT add the station tag: RackSpawner
	does that, LAST, once the rack is fully placed. It never parents, moves or
	destroys the Model, so it is safe to run on an unparented clone.

	The checks and settings were first written for the hand-placed rack (6D.1,
	PowerRackSetup, removed in 6D.2b); every modelled rack is now set up here.
]]

local RackConfigurator = {}

local STAND_POINT_NAME = "StandPoint"

--[[
	Invisible floor marker at the centre of the rack. As the Model's PrimaryPart
	it is the rack's pivot, so it is where TrainingStationService measures
	presence from and where it hangs the prompt (+3 studs) and the sign.
]]
RackConfigurator.StandPointSize = Vector3.new(2, 0.2, 2)

-- The four posts: the only rack parts a player collides with.
local UPRIGHTS = {
	"Upright_FrontLeft",
	"Upright_FrontRight",
	"Upright_BackLeft",
	"Upright_BackRight",
}

-- Every other part of PowerRack_01 (art/scripts/build_power_rack_01.py). Players pass through these.
local NON_COLLIDING_PARTS = {
	"Crossbar_Front",
	"Crossbar_Back",
	"Crossbar_Left",
	"Crossbar_Right",
	"BaseRail_Left",
	"BaseRail_Right",
	"BaseRail_Back",
	"JCup_Left",
	"JCup_Right",
	"JCupLiner_Left",
	"JCupLiner_Right",
	"JCupPin_Left",
	"JCupPin_Right",
	"SafetyBar_Left",
	"SafetyBar_Right",
	"SafetyPins",
	"FrameBolts",
}

RackConfigurator.ExpectedPartCount = #UPRIGHTS + #NON_COLLIDING_PARTS

-- How far the posts may lean from one another before the rack is treated as broken.
local MIN_POST_ALIGNMENT = 0.999

--[[
	Finds every expected rack part inside the Model, by name. Refuses a missing
	part, a doubled name, or a name on something that is not a MeshPart.
]]
local function collectParts(rack: Model): ({ [string]: MeshPart }?, string?)
	local expected: { [string]: boolean } = {}
	for _, name in ipairs(UPRIGHTS) do
		expected[name] = true
	end
	for _, name in ipairs(NON_COLLIDING_PARTS) do
		expected[name] = true
	end

	local found: { [string]: MeshPart } = {}
	for _, descendant in ipairs(rack:GetDescendants()) do
		local name = descendant.Name
		if expected[name] then
			if not descendant:IsA("MeshPart") then
				return nil, string.format("%s is a %s, expected a MeshPart", name, descendant.ClassName)
			end
			if found[name] then
				return nil, "more than one part named " .. name
			end
			found[name] = descendant
		end
	end

	for name in pairs(expected) do
		if not found[name] then
			return nil, "missing MeshPart " .. name
		end
	end

	return found, nil
end

--[[
	Where StandPoint goes, from the posts as they are placed now: the average of
	the four post centres is the frame's centre, and half a post's height down
	its own long axis is the floor. Oriented like the posts.
]]
local function standPointCFrame(posts: { MeshPart }): (CFrame?, string?)
	local reference = posts[1]
	local up = reference.CFrame.UpVector
	local centreSum = Vector3.zero

	for _, post in ipairs(posts) do
		local size = post.Size
		if size.Y < size.X or size.Y < size.Z then
			return nil, string.format("%s is not tallest along its own Y axis (Size %s)", post.Name, tostring(size))
		end
		if post.CFrame.UpVector:Dot(up) < MIN_POST_ALIGNMENT then
			return nil, post.Name .. " does not point the same way as " .. reference.Name
		end
		centreSum += post.Position
	end

	local frameCentre = centreSum / #posts
	local floor = frameCentre - up * (reference.Size.Y / 2)
	local position = floor + up * (RackConfigurator.StandPointSize.Y / 2)

	return CFrame.fromMatrix(position, reference.CFrame.RightVector, up), nil
end

--[[
	Configures the rack Model in place. Returns true, or false and the reason.
	On false the Model may be partly configured and must not be used; it is
	never tagged here, so it can never register by accident.
]]
function RackConfigurator.configure(rack: Model): (boolean, string?)
	local parts, partsProblem = collectParts(rack)
	if parts == nil then
		return false, partsProblem or "its parts could not be read"
	end

	for _, child in ipairs(rack:GetChildren()) do
		if child.Name == STAND_POINT_NAME then
			return false, "it already has a " .. STAND_POINT_NAME .. " (templates must not carry one)"
		end
	end

	local posts: { MeshPart } = {}
	for _, name in ipairs(UPRIGHTS) do
		table.insert(posts, parts[name])
	end

	local standCFrame, standProblem = standPointCFrame(posts)
	if standCFrame == nil then
		return false, standProblem or "the stand point could not be placed"
	end

	-- Anchoring and collision. Position, size, materials and colours are not touched.
	for _, post in ipairs(posts) do
		post.Anchored = true
		post.CanTouch = false
		post.CanCollide = true
	end
	for _, name in ipairs(NON_COLLIDING_PARTS) do
		local part = parts[name]
		part.Anchored = true
		part.CanTouch = false
		part.CanCollide = false
	end

	local standPoint = Instance.new("Part")
	standPoint.Name = STAND_POINT_NAME
	standPoint.Size = RackConfigurator.StandPointSize
	standPoint.Transparency = 1
	standPoint.Anchored = true
	standPoint.CanCollide = false
	standPoint.CanTouch = false
	standPoint.CanQuery = false
	standPoint.CastShadow = false
	standPoint.CFrame = standCFrame
	-- A non-zero offset would move the Model's pivot, and presence with it, away from StandPoint.
	standPoint.PivotOffset = CFrame.identity
	standPoint.Parent = rack

	rack.PrimaryPart = standPoint

	local pivotError = (rack:GetPivot().Position - standPoint.Position).Magnitude
	if pivotError > 0.001 then
		return false, string.format("its pivot is %.3f studs away from StandPoint", pivotError)
	end

	return true, nil
end

return RackConfigurator
