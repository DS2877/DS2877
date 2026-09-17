--!strict
local h = require("./helpers")
local Visual = require("../../src/shared/Config/Visual")

h.suite("Visual exposure budget")

--- Rough perceptual luminance, 0-1, from an { r, g, b } 0-255 triple.
local function luminance(rgb: { number }): number
	return (0.2126 * rgb[1] + 0.7152 * rgb[2] + 0.0722 * rgb[3]) / 255
end

h.test("REGRESSION: the scene is not blown out", function()
	-- This is the one thing a cloud session cannot see. There is no Studio
	-- here, no screenshot, and no renderer -- so the first version of this was
	-- shipped twice before a photo showed the road, the pavement, the awnings
	-- and the buildings all clipped to flat white with no detail in them.
	--
	-- It was never one setting. brightness 3.0, exposureCompensation +0.1,
	-- outdoorAmbient 172, environmentDiffuseScale 0.75 and a FOURTH helping of
	-- +0.04 from the colour grade all stack on the same pixels. Each looked
	-- reasonable alone. The budget is the thing worth testing, so the next
	-- person to raise one of these finds out here rather than from a photo.
	local light = Visual.LIGHTING

	h.expectTrue(
		light.brightness <= 2.4,
		`Lighting.Brightness is {light.brightness}; above ~2.4 pale surfaces clip`
	)
	h.expectTrue(
		light.exposureCompensation <= 0,
		`exposureCompensation is {light.exposureCompensation}; positive stacks on Brightness`
	)
	h.expectTrue(
		luminance(light.outdoorAmbient) <= 0.72,
		"outdoorAmbient is a second sun at this level -- it lights every outdoor surface flatly"
	)
	h.expectTrue(
		light.environmentDiffuseScale <= 0.6,
		`environmentDiffuseScale is {light.environmentDiffuseScale}; it adds sky light on top of Brightness`
	)

	-- The grade must not be a brightness control. Exposure belongs to Lighting,
	-- in one place, or nobody can reason about the total.
	h.expectTrue(
		math.abs(Visual.COLOR_CORRECTION.brightness) <= 0.01,
		"ColorCorrection.Brightness is a fourth exposure knob; use Lighting.Brightness"
	)
end)

h.test("REGRESSION: bloom only catches things brighter than white", function()
	-- The comment on BLOOM claimed "the threshold sits just above white" while
	-- the value was 0.92, which is below it. Every lit pale surface bloomed,
	-- which is what smeared the road into the pavement into the awnings.
	--
	-- Above 1.0 it does what the comment always said: neon, the sun and a
	-- mutated Nomling glow, and ordinary bright scenery does not.
	h.expectTrue(
		Visual.BLOOM.threshold > 1.0,
		`bloom threshold is {Visual.BLOOM.threshold}; at or below 1.0 ordinary scenery glows`
	)
end)

h.test("the world is still bright, not merely un-blown", function()
	-- The opposite failure is the one that started all of this: an earlier
	-- pass was moody and dark and had to be retuned for kids. Pulling exposure
	-- back must not walk into that, so this asserts a floor as well as a cap.
	local light = Visual.LIGHTING
	h.expectTrue(light.brightness >= 1.6, "too dim for a children's game")
	h.expectTrue(
		luminance(light.ambient) >= 0.35,
		"ambient is the colour of SHADOW; too low and creatures in shade go muddy"
	)
	h.expectTrue(
		Visual.COLOR_CORRECTION.saturation >= 0.2,
		"colour has to come from saturation once it stops coming from exposure"
	)
end)
