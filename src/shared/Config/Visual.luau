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
	-- THE WHOLE STACK IS AN EXPOSURE BUDGET, and it was massively over it.
	-- A screenshot showed the road, pavement, awnings and buildings all
	-- clipped to flat white with no detail left, reported as "very shiny".
	-- It was not reflection: brightness 3.0, +0.1 exposure, outdoorAmbient 172,
	-- diffuse 0.75 and another +0.04 of colour-correction brightness all stack,
	-- and then bloom at threshold 0.92 smeared whatever survived. A road at
	-- RGB 214 never stood a chance.
	--
	-- Every number below is now inside a budget that tests/unit/visual.spec
	-- enforces, because "is it blown out?" is invisible from a cloud session
	-- with no Studio and no screenshot -- I had to be told twice.
	brightness = 2.0,
	exposureCompensation = -0.15,
	-- Ambient is the colour of light in SHADOW. Still bright enough that a
	-- Nomling in shade reads as a colourful toy rather than a dark lump, but no
	-- longer bright enough to be a second sun.
	ambient = { 118, 114, 128 },
	outdoorAmbient = { 140, 150, 172 },
	-- Soft. Hard-edged shadows look serious.
	shadowSoftness = 0.62,
	environmentDiffuseScale = 0.45,
	-- Specular stays near off: a 520-stud road catching the sky along its whole
	-- length does read as wet. It was just never the main problem.
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
	-- THRESHOLD ABOVE WHITE, which is what the comment above always claimed and
	-- 0.92 never did. Below 1.0 every lit pale surface blooms, so the road, the
	-- pavement and the market awnings all smeared into each other. At 1.15 only
	-- things that are genuinely brighter than white glow -- neon, the sun, a
	-- mutated Nomling -- which is the whole point of having bloom at all.
	intensity = 0.35,
	size = 20,
	threshold = 1.15,
}

--- The colour grade. Small numbers -- a grade you can see is a grade that is
--- too strong.
Visual.COLOR_CORRECTION = {
	-- Zero. This was a fourth helping of brightness on top of three others.
	-- Colour comes from saturation; exposure comes from Lighting, once.
	brightness = 0.0,
	-- LOW on purpose. Contrast deepens shadows, and deep shadows are the enemy
	-- of a toy look. Saturation does the work instead.
	contrast = 0.05,
	saturation = 0.36,
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
