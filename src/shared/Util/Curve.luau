--!strict
--[[
	Curve
	Shared / Util

	Evaluates a configurable "anchor curve": a list of known (x, y) points with
	smooth interpolation between them.

	Any balancing rule shaped like "as X rises, Y follows a hand-tuned curve"
	should use this module instead of hardcoding math inside gameplay code.
	That keeps every tunable number in Config/ where it can be retuned during
	playtesting without touching gameplay logic.

	Curve fields:
		anchors  list of { x = number, y = number }, sorted by ascending x
		space    "linear" interpolates directly between anchors.
		         "log" interpolates across log(1 + x), which keeps a curve smooth
		         when its anchors span a huge range (0 up to 100,000).
		tail     optional. Describes behaviour PAST the final anchor: y approaches
		         `ceiling` but never reaches it, at `rate` speed. With no tail, y
		         simply stays flat at the final anchor's y.

	Below the first anchor, y is clamped to the first anchor's y.
]]

local Curve = {}

export type Anchor = {
	x: number,
	y: number,
}

export type Tail = {
	ceiling: number,
	rate: number,
}

export type Curve = {
	anchors: { Anchor },
	space: "linear" | "log",
	tail: Tail?,
}

local function toSpace(value: number, space: string): number
	if space == "log" then
		-- log(1 + x) rather than log(x) so that x = 0 is a legal input
		return math.log(1 + value)
	end
	return value
end

--[[
	Checks a curve is well-formed and throws a clear error if it is not.
	Config modules call this when they load, so a bad balancing table fails
	loudly at startup instead of silently producing nonsense during a lift.
]]
function Curve.validate(curve: Curve, name: string)
	local anchors = curve.anchors

	assert(typeof(anchors) == "table", string.format("[Curve] %s is missing its anchors list", name))
	assert(#anchors >= 2, string.format("[Curve] %s needs at least 2 anchors", name))
	assert(
		curve.space == "linear" or curve.space == "log",
		string.format("[Curve] %s has an invalid space (expected \"linear\" or \"log\")", name)
	)

	for index, anchor in ipairs(anchors) do
		assert(
			typeof(anchor.x) == "number" and typeof(anchor.y) == "number",
			string.format("[Curve] %s anchor %d must have numeric x and y", name, index)
		)
		if curve.space == "log" then
			assert(
				anchor.x >= 0,
				string.format("[Curve] %s anchor %d has a negative x, which log space does not allow", name, index)
			)
		end
		if index > 1 then
			assert(
				anchor.x > anchors[index - 1].x,
				string.format("[Curve] %s anchors must be sorted by ascending x (anchor %d breaks this)", name, index)
			)
		end
	end

	local tail = curve.tail
	if tail then
		assert(tail.rate > 0, string.format("[Curve] %s tail rate must be greater than 0", name))
		assert(
			tail.ceiling > anchors[#anchors].y,
			string.format("[Curve] %s tail ceiling must sit above the final anchor's y", name)
		)
	end
end

--[[
	Returns the curve's y value for the given x.
]]
function Curve.evaluate(curve: Curve, x: number): number
	local anchors = curve.anchors
	local first = anchors[1]
	local last = anchors[#anchors]

	-- Below the curve: clamp to the first anchor.
	if x <= first.x then
		return first.y
	end

	-- Past the curve: either approach the tail ceiling, or hold the last value.
	if x >= last.x then
		local tail = curve.tail
		if not tail then
			return last.y
		end
		local distance = toSpace(x, curve.space) - toSpace(last.x, curve.space)
		return tail.ceiling - (tail.ceiling - last.y) * math.exp(-tail.rate * distance)
	end

	-- Inside the curve: straight-line interpolation between the bracketing anchors.
	for index = 1, #anchors - 1 do
		local lower = anchors[index]
		local upper = anchors[index + 1]

		if x <= upper.x then
			local lowerX = toSpace(lower.x, curve.space)
			local upperX = toSpace(upper.x, curve.space)
			local alpha = if upperX == lowerX then 0 else (toSpace(x, curve.space) - lowerX) / (upperX - lowerX)
			return lower.y + (upper.y - lower.y) * alpha
		end
	end

	return last.y
end

return Curve
