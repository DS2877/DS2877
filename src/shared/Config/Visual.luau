--!strict
--[[
	The art direction, as numbers.

	"Toy food court diorama" (docs/GDD.md 7) -- bright, saturated, and cheerful,
	read at arm's length on a phone by a nine-year-old.

	⚠️ RETUNED 2026-09-17, AND THE REASON MATTERS. An earlier pass chased a
	cinematic look: late-afternoon sun, dark purple ambient, strong contrast,
	heavy haze, depth of field. It was well made and it was WRONG FOR THIS
	AUDIENCE. Prestige-game lighting reads as serious and slightly gloomy, and
	our players are 9-15 with 5-8 to follow. Every top kids' game on Roblox is
	high-key: bright sky, open shadows, punchy colour, almost no gloom.

	So the rules here now are:

	1. SHADOWS STAY BRIGHT. High ambient, low contrast. A dark shadow makes a
	   toy look like a prop; an open one keeps it looking like a toy.
	2. COLOUR OVER CONTRAST. Saturation does the work that contrast would do in
	   a grown-up game, and it never costs legibility.
	3. NOTHING CINEMATIC. No depth of field, barely any haze. A blurred
	   background is film language, and on a phone it mostly just hides things a
	   player wanted to see -- like somebody running off with their Nomling.
	4. THE SUN IS HIGH. Midday, not golden hour. Long dramatic shadows are
	   atmosphere; short cheerful ones are a playground.

	None of this costs a single part against the performance budget.

	DEPENDENCY-FREE so Lune can test the ranges.
]]

local Visual = {}

--- Lighting. ClockTime 15.6 is mid-afternoon: the sun is high enough to light
--- faces but low enough to throw shadows that describe the street.
Visual.LIGHTING = {
	-- Just after midday. Short, cheerful shadows rather than long dramatic ones.
	clockTime = 13.2,
	geographicLatitude = 8,
	brightness = 3.0,
	exposureCompensation = 0.1,
	-- Ambient is the colour of light in SHADOW, and this is the single most
	-- important number in the file. Bright and faintly warm, so a Nomling
	-- standing in shade still reads as a colourful toy instead of a dark lump.
	ambient = { 136, 130, 142 },
	outdoorAmbient = { 172, 182, 204 },
	-- Soft. Hard-edged shadows look serious.
	shadowSoftness = 0.62,
	environmentDiffuseScale = 0.75,
	-- NEARLY OFF. From a playtest: "the ground are a bit too shiny". Specular
	-- is what makes a big flat surface read as wet, and a street is the
	-- biggest flat surface in the game -- under Future lighting it was
	-- catching the sky across its whole length. Diffuse goes up by the same
	-- breath so the world does not get darker in exchange, because the point
	-- is matte and bright, not matte and dull.
	environmentSpecularScale = 0.06,
	fogEnd = 1_000_000, -- Atmosphere replaces legacy fog entirely
}

--- Atmosphere is the biggest single upgrade available in Roblox, and it is one
--- instance. Haze gives the street depth; Glare makes the sun feel like a
--- light source rather than a texture.
Visual.ATMOSPHERE = {
	-- Light. Just enough that the far end of the street sits back a little;
	-- anything heavier turns a bright day into a moody one.
	density = 0.22,
	offset = 0.05,
	color = { 226, 238, 255 },
	decay = { 150, 190, 235 },
	glare = 0.16,
	haze = 0.85,
}

--- Volumetric clouds. Free, and they turn a flat skybox into a sky.
Visual.CLOUDS = {
	-- Fat, white, cartoon clouds. Cover is high because a mostly-blue sky with
	-- a few big clouds is what a child draws when you ask them to draw a nice day.
	cover = 0.62,
	density = 0.038,
	color = { 255, 255, 255 },
}

--- Bloom. Restrained on purpose: the threshold sits just above white so only
--- genuinely bright things glow, which is what makes a mutated Nomling read as
--- special instead of making the whole screen soft.
Visual.BLOOM = {
	-- Soft and generous. On a bright scene bloom reads as sunshine, and it is
	-- what makes a mutated Nomling glow like a sweet.
	intensity = 0.6,
	size = 26,
	threshold = 0.92,
}

--- The colour grade. Small numbers -- a grade you can see is a grade that is
--- too strong.
Visual.COLOR_CORRECTION = {
	brightness = 0.04,
	-- LOW on purpose. Contrast deepens shadows, and deep shadows are the enemy
	-- of a toy look. Saturation does the work instead.
	contrast = 0.03,
	saturation = 0.3,
	tintColor = { 255, 252, 246 },
}

Visual.SUN_RAYS = {
	intensity = 0.06,
	spread = 1,
}

--- Depth of field is OFF. It is film language, it reads as "serious game", and
--- on a phone a blurred background mostly hides things a player wanted to see --
--- like somebody running off with their Nomling. Kept as a zeroed entry rather
--- than deleted so nobody re-adds it without reading this.
Visual.DEPTH_OF_FIELD = {
	farIntensity = 0,
	focusDistance = 1000,
	inFocusRadius = 1000,
	nearIntensity = 0,
}

Visual.SKY = {
	sunAngularSize = 13,
	moonAngularSize = 11,
	starCount = 0, -- daytime
}

--- Quality tiers. A low-end phone drops the expensive effects and keeps the
--- cheap ones that carry most of the look: atmosphere and the colour grade cost
--- almost nothing, while depth of field and sun rays are the first to go.
Visual.QUALITY = {
	high = { bloom = true, colorCorrection = true, sunRays = true, dof = true, clouds = true },
	medium = { bloom = true, colorCorrection = true, sunRays = false, dof = false, clouds = true },
	low = { bloom = false, colorCorrection = true, sunRays = false, dof = false, clouds = false },
}

--- Rendering below this many frames per second for a sustained stretch drops a
--- tier. Measured, not guessed at, by the controller.
Visual.DOWNGRADE_FPS = 40
Visual.DOWNGRADE_SECONDS = 6

return Visual
