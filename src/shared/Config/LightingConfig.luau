--!strict
--[[
	LightingConfig
	Shared / Config

	The game's overall lighting, applied by the server at start
	(src/server/World/LightingSetup.luau) so it lives in Git instead of only
	in the place file (user, 2026-10-31: "its so bright and glary").

	Before (the place file's own settings): sun Brightness 2.5, Ambient 0.43,
	OutdoorAmbient 0.5, EnvironmentSpecularScale 0.5, Bloom Intensity 1 /
	Size 24 / Threshold 2, Atmosphere Density 0.3. That put a glow halo on
	every brightly lit thing (the red plates, white uprights, the light bars,
	avatars' white clothes), let a strong sun pour through the skylights and
	washed the hall out with haze.

	Each value is the Lighting property (or the effect's) of the same name.
]]

local LightingConfig = {}

LightingConfig.Lighting = {
	Brightness = 1.6, -- the sun through the skylights
	ExposureCompensation = -0.25,
	Ambient = Color3.new(0.33, 0.33, 0.35),
	OutdoorAmbient = Color3.new(0.42, 0.42, 0.44),
	EnvironmentSpecularScale = 0.25, -- less shine on floors and metal
}

-- The glow round bright things: only the lamps themselves should glow, softly.
LightingConfig.Bloom = {
	Intensity = 0.3,
	Size = 14,
	Threshold = 2.6,
}

-- Less haze inside the hall.
LightingConfig.Atmosphere = {
	Density = 0.18,
}

return LightingConfig
