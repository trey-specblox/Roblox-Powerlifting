--!strict
--[[
	RackConfigurator
	Server / Training

	Prepares ONE rack Model cloned from a known template so the training service
	can use it: checks the template's named MeshParts, anchors everything, makes
	only the template's posts solid, and gives it an invisible StandPoint floor
	marker as its PrimaryPart (and therefore its pivot).

	Every template the game can spawn has a profile in RACK_PROFILES below: its
	parts, which of them are solid, and which posts mark the rack's centre. A
	template without a profile is refused.

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

type RackProfile = {
	-- The only rack parts a player collides with.
	solid: { string },
	-- Every other part of the template. Players pass through these.
	nonColliding: { string },
	-- Posts whose average centre is the rack's centre (StandPoint goes below it, on the floor).
	centrePosts: { string },
}

local RACK_PROFILES: { [string]: RackProfile } = {
	-- art/scripts/build_power_rack_01.py: four-post cage, StandPoint in the middle.
	PowerRack_01 = {
		solid = { "Upright_FrontLeft", "Upright_FrontRight", "Upright_BackLeft", "Upright_BackRight" },
		nonColliding = {
			"Crossbar_Front", "Crossbar_Back", "Crossbar_Left", "Crossbar_Right",
			"BaseRail_Left", "BaseRail_Right", "BaseRail_Back",
			"JCup_Left", "JCup_Right", "JCupLiner_Left", "JCupLiner_Right", "JCupPin_Left", "JCupPin_Right",
			"SafetyBar_Left", "SafetyBar_Right", "SafetyPins", "FrameBolts",
		},
		centrePosts = { "Upright_FrontLeft", "Upright_FrontRight", "Upright_BackLeft", "Upright_BackRight" },
	},
	-- art/scripts/build_combo_rack_01.py: combo rack with a bench, StandPoint between
	-- the two tall posts (under the racked bar). The bench is not solid, so it can
	-- be hidden per lift (StationVisuals) without changing what blocks players.
	ComboRack_01 = {
		solid = { "Upright_Left", "Upright_Right", "SpotterPost_Left", "SpotterPost_Right" },
		nonColliding = {
			"UprightInsert_Left", "UprightInsert_Right", "InsertLockPins",
			"SafetyArm_Left", "SafetyArm_Right", "SafetyPins",
			"BaseRail_Left", "BaseRail_Right", "BaseRail_Back", "BaseFoot_Left", "BaseFoot_Right",
			"SpotterDeck", "FootCaps",
			"JCup_Left", "JCup_Right", "JCupLiner_Left", "JCupLiner_Right", "JCupPin_Left", "JCupPin_Right",
			"FrameBolts", "Bench_Pad", "Bench_Frame",
		},
		centrePosts = { "Upright_Left", "Upright_Right" },
	},
}

--[[
	How many MeshParts a template must hold, exactly. nil = no profile, so the
	template cannot be spawned.
]]
function RackConfigurator.expectedPartCount(templateName: string): number?
	local profile = RACK_PROFILES[templateName]
	if profile == nil then
		return nil
	end
	return #profile.solid + #profile.nonColliding
end

-- How far the posts may lean from one another before the rack is treated as broken.
local MIN_POST_ALIGNMENT = 0.999

--[[
	Finds every expected rack part inside the Model, by name. Refuses a missing
	part, a doubled name, or a name on something that is not a MeshPart.
]]
local function collectParts(rack: Model, profile: RackProfile): ({ [string]: MeshPart }?, string?)
	local expected: { [string]: boolean } = {}
	for _, name in ipairs(profile.solid) do
		expected[name] = true
	end
	for _, name in ipairs(profile.nonColliding) do
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
	Where StandPoint goes, from the parts as they are placed now: the average of
	the centre posts is the rack's centre, and the lowest point of any rack part,
	measured along the posts' own long axis, is the floor. Oriented like the posts.
]]
local function standPointCFrame(posts: { MeshPart }, allParts: { [string]: MeshPart }): (CFrame?, string?)
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

	-- Lowest point of the whole rack along `up` (a part's half-extent along `up`
	-- comes from its size and how it is turned).
	local floorHeight = math.huge
	for _, part in pairs(allParts) do
		local cf, half = part.CFrame, part.Size / 2
		local reach = math.abs(cf.RightVector:Dot(up)) * half.X
			+ math.abs(cf.UpVector:Dot(up)) * half.Y
			+ math.abs(cf.LookVector:Dot(up)) * half.Z
		floorHeight = math.min(floorHeight, part.Position:Dot(up) - reach)
	end

	local frameCentre = centreSum / #posts
	local floor = frameCentre - up * (frameCentre:Dot(up) - floorHeight)
	local position = floor + up * (RackConfigurator.StandPointSize.Y / 2)

	return CFrame.fromMatrix(position, reference.CFrame.RightVector, up), nil
end

--[[
	Configures the rack Model in place, using the profile of the template it was
	cloned from. Returns true, or false and the reason. On false the Model may be
	partly configured and must not be used; it is never tagged here, so it can
	never register by accident.
]]
function RackConfigurator.configure(rack: Model, templateName: string): (boolean, string?)
	local profile = RACK_PROFILES[templateName]
	if profile == nil then
		return false, "no rack profile for template " .. templateName
	end

	local parts, partsProblem = collectParts(rack, profile)
	if parts == nil then
		return false, partsProblem or "its parts could not be read"
	end

	for _, child in ipairs(rack:GetChildren()) do
		if child.Name == STAND_POINT_NAME then
			return false, "it already has a " .. STAND_POINT_NAME .. " (templates must not carry one)"
		end
	end

	local posts: { MeshPart } = {}
	for _, name in ipairs(profile.centrePosts) do
		table.insert(posts, parts[name])
	end

	local standCFrame, standProblem = standPointCFrame(posts, parts)
	if standCFrame == nil then
		return false, standProblem or "the stand point could not be placed"
	end

	-- Anchoring and collision. Position, size, materials and colours are not touched.
	for _, name in ipairs(profile.solid) do
		local part = parts[name]
		part.Anchored = true
		part.CanTouch = false
		part.CanCollide = true
	end
	for _, name in ipairs(profile.nonColliding) do
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
