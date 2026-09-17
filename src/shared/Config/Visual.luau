--!strict
--[[
	The art direction, as numbers.

	"Toy food court diorama at golden hour" (docs/GDD.md 7). Late afternoon sun,
	long warm shadows, a hazy warm atmosphere with real depth down the street,
	and enough bloom that neon and mutations glow without washing out.

	WHY THIS FILE IS THE MOST VALUABLE VISUAL WORK IN THE PROJECT. Roblox games
	do not read as premium because of polygon counts -- they read as premium
	because of lighting, atmosphere, post-processing and a coherent palette.
	Every value here is free at runtime and none of it costs a single part
	against the GDD's performance budget.

	AAA INSPIRATION, HONESTLY SCOPED. Philip asked for GTA 6. Photoreal grit is
	not reachable on a mid-range phone and would push the maturity rating to
	Moderate, which loses the Roblox Kids tier that M6 is built around. What
	transfers from a production like that is not the renderer, it is the
	DISCIPLINE: one committed time of day, a considered colour grade, real
	atmospheric depth, and nothing left at its engine default. That is what
	this file is.

	DEPENDENCY-FREE so Lune can test the ranges.
]]

local Visual = {}

--- Lighting. ClockTime 15.6 is mid-afternoon: the sun is high enough to light
--- faces but low enough to throw shadows that describe the street.
Visual.LIGHTING = {
	clockTime = 15.6,
	geographicLatitude = 18,
	brightness = 2.4,
	exposureCompensation = 0.18,
	-- Ambient is the colour of light in shadow. Warm-neutral, never grey:
	-- grey shadow is the single most common reason a Roblox scene looks flat.
	ambient = { 74, 68, 82 },
	outdoorAmbient = { 128, 132, 150 },
	shadowSoftness = 0.34,
	environmentDiffuseScale = 0.55,
	environmentSpecularScale = 0.42,
	fogEnd = 1_000_000, -- Atmosphere replaces legacy fog entirely
}

--- Atmosphere is the biggest single upgrade available in Roblox, and it is one
--- instance. Haze gives the street depth; Glare makes the sun feel like a
--- light source rather than a texture.
Visual.ATMOSPHERE = {
	density = 0.34,
	offset = 0.08,
	color = { 232, 214, 190 },
	decay = { 122, 134, 158 },
	glare = 0.32,
	haze = 1.7,
}

--- Volumetric clouds. Free, and they turn a flat skybox into a sky.
Visual.CLOUDS = {
	cover = 0.55,
	density = 0.048,
	color = { 255, 250, 244 },
}

--- Bloom. Restrained on purpose: the threshold sits just above white so only
--- genuinely bright things glow, which is what makes a mutated Nomling read as
--- special instead of making the whole screen soft.
Visual.BLOOM = {
	intensity = 0.55,
	size = 22,
	threshold = 1.05,
}

--- The colour grade. Small numbers -- a grade you can see is a grade that is
--- too strong.
Visual.COLOR_CORRECTION = {
	brightness = 0.015,
	contrast = 0.13,
	saturation = 0.15,
	tintColor = { 255, 249, 240 },
}

Visual.SUN_RAYS = {
	intensity = 0.11,
	spread = 0.92,
}

--- Depth of field, deliberately subtle. A far blur gives the street length;
--- anything stronger costs readability, and readability on a phone is worth
--- more than any single effect here.
Visual.DEPTH_OF_FIELD = {
	farIntensity = 0.13,
	focusDistance = 42,
	inFocusRadius = 44,
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
