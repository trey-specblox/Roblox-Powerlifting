--!strict
--[[
	ResourceRegeneration
	Shared / Progression

	Lazy, timestamp-driven regeneration for continuously refilling resources.

	Used by the three Competition Budgets and by Training Energy. Both regenerate
	in real time, including while the player is offline, so neither can be
	modelled as "add some amount every tick".

	NO LOOP IS REQUIRED. A resource is stored as

		amount                 how much was left when it was last touched
		lastUpdatedUnix        the server time at which that was true

	and the current value is computed from those two plus the clock whenever it is
	read or spent. A player offline for three days regenerates exactly as much as
	one who sat in the lobby, with no running task, no heartbeat, and no cost for
	players who are not playing.

	PURE FUNCTIONS, NO STATE

	This module holds no state and performs no writes. It is in Shared rather
	than Server because the maths is not secret and a future UI will want to
	predict the same curve for a smooth meter. That is safe: the client can
	compute a display value but has no path to store one, because every write
	goes through PlayerDataService on the server.

	THE CLOCK IS THE SERVER'S

	Callers pass `nowUnix`, and every caller inside the game passes os.time()
	from a server script. A client-supplied timestamp must never reach these
	functions. Taking the clock as a parameter rather than reading it here is
	what makes the behaviour deterministic and therefore testable: the dev
	harness drives whole days of regeneration in a few milliseconds by passing
	synthetic times.

	CLOCKS CAN GO BACKWARD

	os.time() reads the host clock, which can be corrected backward by NTP or by
	a machine rebooting with a bad RTC. A naive elapsed-time subtraction would
	then be negative and would DRAIN the resource. Every function below treats
	negative elapsed time as zero, so the worst a backward clock can do is pause
	regeneration until the clock catches up.
]]

local ResourceRegeneration = {}

--[[
	A continuously regenerating resource, as stored in a player's profile.

	`amount` may be negative for resources that model overflow, which is why
	nothing in this module floors it at zero. The caller supplies the floor.
]]
export type Resource = {
	amount: number,
	lastUpdatedUnix: number,
}

--[[
	Whole seconds between two timestamps, never negative.

	See the clock note above: a backward clock yields 0 rather than a negative
	elapsed time that would drain the resource.
]]
local function elapsedSeconds(fromUnix: number, nowUnix: number): number
	if typeof(fromUnix) ~= "number" or fromUnix ~= fromUnix then
		--[[
			Missing or NaN timestamp. Treat it as "just now" and grant nothing:
			granting a full refill would reward corruption, and granting a
			negative would punish it.
		]]
		return 0
	end

	local elapsed = nowUnix - fromUnix

	if elapsed ~= elapsed or elapsed < 0 then
		return 0
	end

	return elapsed
end

--[[
	The resource's value right now, without writing anything.

	Regeneration is clamped at `capacity`, so time spent at full does not bank.
	A resource sitting above capacity -- which only a config change lowering the
	cap can produce -- is brought DOWN to the cap rather than left there.
]]
function ResourceRegeneration.current(
	resource: Resource,
	nowUnix: number,
	capacity: number,
	ratePerHour: number
): number
	local amount = resource.amount

	if typeof(amount) ~= "number" or amount ~= amount then
		--[[
			NaN or missing. Rebuild at full rather than at zero: the cause is a
			bug or a corrupt save, and a player should not be punished for it.
		]]
		return capacity
	end

	if amount >= capacity then
		return capacity
	end

	local hours = elapsedSeconds(resource.lastUpdatedUnix, nowUnix) / 3600
	local regenerated = amount + hours * ratePerHour

	if regenerated > capacity then
		return capacity
	end

	return regenerated
end

--[[
	Writes the regenerated value back into the resource and returns it.

	Call this before spending, so the stored amount and timestamp describe the
	same instant. Spending from a stale amount would silently discard whatever
	regenerated since it was written.
]]
function ResourceRegeneration.settle(
	resource: Resource,
	nowUnix: number,
	capacity: number,
	ratePerHour: number
): number
	local amount = ResourceRegeneration.current(resource, nowUnix, capacity, ratePerHour)

	resource.amount = amount
	resource.lastUpdatedUnix = nowUnix

	return amount
end

--[[
	Spends `cost` if the resource can cover it, after regenerating.

	Returns whether it was spent and what remains. ALL-OR-NOTHING: a cost that
	cannot be covered changes nothing, so a caller cannot half-pay for something
	and then fail.

	`floor` is the lowest value the resource may reach. Pass 0 for a resource
	that simply runs out, such as Training Energy. Pass a negative value for one
	that models overflow, such as a Competition Budget, where a negative amount
	IS the overflow depth.
]]
function ResourceRegeneration.trySpend(
	resource: Resource,
	nowUnix: number,
	capacity: number,
	ratePerHour: number,
	cost: number,
	floor: number
): (boolean, number)
	local available = ResourceRegeneration.settle(resource, nowUnix, capacity, ratePerHour)

	if typeof(cost) ~= "number" or cost ~= cost or cost == math.huge or cost == -math.huge then
		return false, available
	end

	if cost < 0 then
		--[[
			A negative cost would be a refund, and refunds are not a thing this
			system has. Section 29.9: leaving a meet or disconnecting consumes
			exactly what was earned and is never given back.
		]]
		return false, available
	end

	if cost == 0 then
		-- Nothing to do, and reporting success keeps callers from special-casing it.
		return true, available
	end

	local remaining = available - cost

	if remaining < floor then
		return false, available
	end

	resource.amount = remaining
	resource.lastUpdatedUnix = nowUnix

	return true, remaining
end

--[[
	A fresh resource, full, stamped at `nowUnix`.

	Used for new profiles and when a migration adds a resource to an existing
	one. Starting full rather than empty is deliberate: an existing player should
	not log in to find a new allowance they have to wait a week for.
]]
function ResourceRegeneration.newFull(capacity: number, nowUnix: number): Resource
	return {
		amount = capacity,
		lastUpdatedUnix = nowUnix,
	}
end

return ResourceRegeneration
