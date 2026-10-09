--!strict
--[[
	DayKey
	Shared / Progression

	The UTC calendar day a server timestamp falls in, as a stable string.

	Used by the daily training allowances of GAME_DESIGN.md section 34.12. An
	allowance is not a regenerating resource -- it does not refill continuously,
	it resets at a day boundary -- so ResourceRegeneration is the wrong model for
	it. What an allowance needs is a cheap, exact answer to "is the stored day
	still the current day", and that is all this module provides.

	WHY A STORED KEY AND NOT A STORED RESET TIME

	Comparing a stored day key against the current one is a string comparison
	that needs no scheduled job, no heartbeat and no login hook. A player offline
	across three midnights comes back with a stale key, the next read sees the
	mismatch, and the allowance resets once. A player who never logs out has
	their key go stale at midnight and resets on the next read. Both cases are
	the same single line of logic, which is why section 34.12 requires the phase
	to be DERIVED from persisted counters rather than driven by an event that can
	be missed.

	WHY UTC

	A local-time boundary would mean the reset moment depends on which machine
	answered, and Roblox servers are spread across regions. Two servers would
	disagree about what day it is, and a player could cross the boundary twice by
	rejoining. UTC is the only clock every server already agrees on.

	The cost is that the reset lands at a different wall-clock hour for different
	players, which is a product decision rather than a correctness one. Section
	34.13 does not list it, so it is noted here: if a friendlier local reset is
	ever wanted, it belongs in a presentation layer that still stores UTC.

	THE CLOCK IS THE CALLER'S, AND IT IS ALWAYS THE SERVER'S

	Like ResourceRegeneration, this takes `nowUnix` as a parameter rather than
	reading the clock itself. That keeps it deterministic and therefore testable:
	the dev probe steps across midnight boundaries by passing synthetic times.

	A client-supplied timestamp must never reach here. Section 34.12 is explicit
	that the day key is stamped by the server, because a client that chooses its
	own day boundary has an unlimited daily allowance.

	A BAD CLOCK FAILS CLOSED, LOUDLY

	`fromUnix` asserts rather than coercing. That is deliberate and it is the
	opposite of ResourceRegeneration's forgiving treatment of a bad timestamp,
	for a reason worth stating: a regenerating resource that mishandles a clock
	grants slightly too little or too much of something that refills anyway,
	while an allowance that mishandles a clock can be made to reset on demand.

	Returning any VARYING value for a bad input would hand out a fresh allowance
	on every read. Returning the "never stamped" sentinel would do the same,
	because the sentinel deliberately matches no real key. So the only safe
	behaviours are to fail, or to return one fixed value forever -- and failing
	is better, because it surfaces the bug instead of freezing a player's
	allowance in a state nobody will notice.

	Every caller inside the game passes `os.time()` from a server script, which
	cannot produce a value this rejects. Writes go through
	PlayerDataService.update, which already pcalls its mutator, so an assert here
	refuses one allowance operation rather than taking down a server.
]]

local DayKey = {}

--[[
	Seconds in a UTC day. Exact, because Unix time ignores leap seconds: every
	UTC day is 86400 Unix seconds long with no exceptions, which is what makes
	the arithmetic below safe without a calendar library.
]]
local SECONDS_PER_DAY = 86400

--[[
	The day key of a counter that has never been stamped.

	An empty string, which `fromUnix` can never return, so it is unambiguous.
	Stored by the template and by migrations for the same reason those store a
	zero timestamp: a real key baked into the template would record the day the
	SERVER started, and every profile that server created would share it.

	IT DELIBERATELY MATCHES NO REAL DAY. The first read therefore sees a mismatch
	and resets the allowance to zero, which is already its value. That is a
	no-op, not a grant -- and it is why an unstamped counter needs no special
	case anywhere in the reader.
]]
DayKey.UNSTAMPED = ""

--[[
	The UTC calendar day `nowUnix` falls in, as "YYYY-MM-DD".

	A readable key rather than a bare day number, because this string is what a
	support request or a DataStore inspection will show, and "2026-10-08" is
	answerable at a glance where "20734" is not. Nothing parses it back: the only
	operation performed on a day key is equality against another day key.

	Asserts on anything that is not a finite, non-negative number. See the
	fail-closed note in the module header.
]]
function DayKey.fromUnix(nowUnix: number): string
	assert(
		typeof(nowUnix) == "number" and nowUnix == nowUnix,
		"[DayKey] nowUnix must be a number, and not NaN"
	)
	assert(
		nowUnix >= 0 and nowUnix < math.huge,
		string.format("[DayKey] nowUnix must be finite and not before the epoch, got %s", tostring(nowUnix))
	)

	--[[
		The "!" prefix is what makes this UTC rather than the host machine's
		local time. Without it two servers in different regions would disagree
		about the current day, which is the whole failure this module exists to
		avoid.
	]]
	return os.date("!%Y-%m-%d", math.floor(nowUnix))
end

--[[
	Whether a stored key is a real day rather than the never-stamped sentinel.

	Callers do not normally need this -- an unstamped key compares unequal to the
	current day and resets, which is correct without asking. It exists so the dev
	probe can assert the distinction, and so a future display can tell "no
	training today" apart from "never trained".
]]
function DayKey.isStamped(dayKey: any): boolean
	return typeof(dayKey) == "string" and dayKey ~= DayKey.UNSTAMPED
end

--[[
	The UTC midnight that starts the day containing `nowUnix`.

	Not used by the allowances, which compare keys rather than times. Exposed
	because a UI will want "resets in 4h 12m", and deriving that from the key
	string would mean parsing it, which nothing else does.
]]
function DayKey.startOfDayUnix(nowUnix: number): number
	assert(
		typeof(nowUnix) == "number" and nowUnix == nowUnix,
		"[DayKey] nowUnix must be a number, and not NaN"
	)
	assert(
		nowUnix >= 0 and nowUnix < math.huge,
		string.format("[DayKey] nowUnix must be finite and not before the epoch, got %s", tostring(nowUnix))
	)

	return math.floor(nowUnix / SECONDS_PER_DAY) * SECONDS_PER_DAY
end

return DayKey
