--!strict
--[[
	TypingContentConfig
	Shared / Config

	The cue words the Deadlift's typing pull asks the player to type.

	SEPARATE FROM THE LOGIC ON PURPOSE

	References/TypingGame.md requires that "phrase content should be stored
	separately from the actual typing-minigame logic so more phrases can easily be
	added later". Adding a cue is adding a string to a list in this file. Nothing
	here is read by the simulation, which only ever sees a flat list of tokens.

	CONTENT RULES

	- original powerlifting vocabulary, written for this game
	- no quotations, no lyrics, no internet phrases, no real people
	- A-Z only: no spaces, digits, punctuation or apostrophes
	- short, because the player reads ONE CHARACTER at a time

	The single-character presentation is why these are cues rather than sentences.
	The giant letter in the middle of the screen is what the player reacts to; the
	spaced cue underneath exists so a fluent player can read ahead and type the
	word without waiting. Long text would serve neither.

	NO SPACES, DELIBERATELY

	Cues advance on their own when their last character lands, so the player never
	types a space. That keeps the spacebar free for the Lockout press one second
	later, where a stray space would read as a wildly early lockout.

	TIERS

	Harder attempts draw from longer cues. That raises the CHARACTER COUNT of a
	pull without raising the required typing speed, which is the whole basis of the
	difficulty model: see TypingPhaseConfig.
]]

local TypingContentConfig = {}

export type Tier = {
	name: string,
	-- Minimum base difficulty at which this tier becomes available.
	minimumDifficulty: number,
	words: { string },
}

--[[
	Cue tiers, shortest first.

	Every tier stays available once unlocked, so a heavy pull mixes short and long
	cues rather than being made entirely of long words. A wall of nine-letter cues
	would read as a vocabulary test; a mix reads as a cadence.
]]
TypingContentConfig.Tiers = {
	{
		name = "Short",
		minimumDifficulty = 0,
		words = {
			"GRIP",
			"PULL",
			"HIPS",
			"LOCK",
			"FEET",
			"LATS",
			"PINS",
			"CHIN",
			"BAR",
			"SET",
		},
	},
	{
		name = "Medium",
		-- Roughly a 90% attempt.
		minimumDifficulty = 45,
		words = {
			"BRACE",
			"DRIVE",
			"KNEES",
			"SHINS",
			"WEDGE",
			"CHALK",
			"SETUP",
			"STANCE",
			"LOCKED",
			"MIDFOOT",
		},
	},
	{
		name = "Long",
		-- Roughly a 105% attempt.
		minimumDifficulty = 80,
		words = {
			"TIGHTEN",
			"SQUEEZE",
			"PLATFORM",
			"LEVERAGE",
			"DEADLIFT",
			"STRAIGHTEN",
		},
	},
}

--[[
	Every cue word available at a given base difficulty, flattened.

	Returns a fresh table, so a caller shuffling the result cannot reorder the
	config itself.
]]
function TypingContentConfig.wordsFor(difficulty: number): { string }
	local available: { string } = {}

	for _, tier in ipairs(TypingContentConfig.Tiers) do
		if difficulty >= tier.minimumDifficulty then
			for _, word in ipairs(tier.words) do
				table.insert(available, word)
			end
		end
	end

	return available
end

--[[
	Startup validation.

	A cue containing a space or a character outside A-Z would produce a token the
	keyboard vocabulary cannot express, and the failure would surface mid-lift as a
	pull the player is unable to complete. Checked at boot instead.
]]
for tierIndex, tier in ipairs(TypingContentConfig.Tiers) do
	assert(
		typeof(tier.name) == "string" and tier.name ~= "",
		string.format("[TypingContentConfig] tier %d must be named", tierIndex)
	)
	assert(
		typeof(tier.minimumDifficulty) == "number"
			and tier.minimumDifficulty >= 0
			and tier.minimumDifficulty <= 100,
		string.format("[TypingContentConfig] tier %s needs a difficulty between 0 and 100", tier.name)
	)
	assert(
		typeof(tier.words) == "table" and #tier.words > 0,
		string.format("[TypingContentConfig] tier %s must list at least one cue", tier.name)
	)

	for _, word in ipairs(tier.words) do
		assert(
			typeof(word) == "string" and #word >= 2,
			string.format("[TypingContentConfig] tier %s contains a cue shorter than two letters", tier.name)
		)
		assert(
			string.match(word, "^[A-Z]+$") ~= nil,
			string.format(
				"[TypingContentConfig] cue %q in tier %s must be uppercase A-Z only, with no spaces or punctuation",
				word,
				tier.name
			)
		)
	end
end

--[[
	The lowest tier must be available from difficulty 0, or an easy pull would have
	no cues to draw at all.
]]
assert(
	TypingContentConfig.Tiers[1].minimumDifficulty == 0,
	"[TypingContentConfig] the first tier must be available at difficulty 0"
)

return TypingContentConfig
