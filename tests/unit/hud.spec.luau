--!strict
local h = require("./helpers")
local HudLayout = require("../../src/shared/Logic/HudLayout")

h.suite("HUD layout")

--- The phones this has to work on, by their SHORT side -- Roblox plays
--- landscape, so that is the dimension the HUD has to survive. 375 is the
--- smallest current Roblox-capable iPhone (SE, 667 x 375); 430 is a Pro Max.
local SCREEN_HEIGHTS = { 375, 390, 414, 430 }

h.test("REGRESSION: no two bands of chrome overlap", function()
	-- The playtest screenshot had four collisions at once: the objective banner
	-- under the Roblox topbar, the "?" on the banner, the toast behind the
	-- bottom bar, and the incubator adrift above it. Every band is now derived
	-- from the one under it, and this is what holds that.
	for _, height in SCREEN_HEIGHTS do
		local bands = HudLayout.bands(height)
		for a = 1, #bands do
			for b = a + 1, #bands do
				local first, second = bands[a], bands[b]
				local overlap = math.min(first.bottom, second.bottom)
					- math.max(first.top, second.top)
				h.expectTrue(
					overlap <= 0,
					`at {height}pt, {first.name} and {second.name} overlap by {overlap}pt`
				)
			end
		end
	end
end)

h.test("REGRESSION: chrome leaves the game most of the screen", function()
	-- "Make the buttons smaller" was a playtest note, and a note is not a
	-- guardrail. The first HUD spent 72 px on the bar, 58 on the tray and 70 on
	-- the purse: on a 375pt screen that is 64% of the display given over to
	-- furniture, with the game playing through the gap. The game has to be the
	-- biggest thing on screen.
	--
	-- Two budgets, because the tray only exists while an egg is hatching.
	for _, height in SCREEN_HEIGHTS do
		local resting = HudLayout.chromeFraction(height, false)
		h.expectTrue(
			resting <= 0.32,
			`at {height}pt the resting HUD covers {math.floor(resting * 100)}%`
		)
		local peak = HudLayout.chromeFraction(height, true)
		h.expectTrue(
			peak <= 0.45,
			`at {height}pt the HUD with the tray up covers {math.floor(peak * 100)}%`
		)
	end
end)

h.test("every touch target clears the 44pt floor", function()
	local targets = {
		bar = HudLayout.BAR_H,
		rail = HudLayout.RAIL_W,
		incubator = HudLayout.SLOT_H,
	}
	for name, size in targets do
		h.expectTrue(
			size >= HudLayout.TOUCH_MIN,
			`{name} is {size}pt, under the {HudLayout.TOUCH_MIN}pt touch floor`
		)
	end
end)

h.test("the bottom bar's three buttons fill the row exactly", function()
	local total = 0
	for _, share in HudLayout.BAR_SPLIT do
		total += share
	end
	h.expectNear(total, 1, 1e-9, "bar button widths must sum to 1")
end)

h.test("the smallest bar button still clears the touch floor", function()
	-- Narrowest supported landscape width, and the row is inset from both edges.
	local rowWidth = math.min(HudLayout.BAR_MAX_W, 568 - HudLayout.EDGE * 2 - 4)
	local narrowest = math.huge
	for _, share in HudLayout.BAR_SPLIT do
		narrowest = math.min(narrowest, share * rowWidth - 6)
	end
	h.expectTrue(
		narrowest >= HudLayout.TOUCH_MIN,
		`narrowest bar button is {math.floor(narrowest)}pt wide`
	)
end)

h.test("the top row leaves the rail its own column", function()
	-- Sized (1, -(EDGE*2 + RAIL_W + GAP)) so the two can never meet.
	local reserved = HudLayout.EDGE * 2 + HudLayout.RAIL_W + HudLayout.GAP
	for _, width in { 568, 667, 844, 1024 } do
		local rowRight = HudLayout.EDGE + (width - reserved)
		local railLeft = width - HudLayout.EDGE - HudLayout.RAIL_W
		h.expectTrue(
			rowRight <= railLeft,
			`at {width}pt wide the top row reaches {rowRight}, rail starts at {railLeft}`
		)
	end
end)

h.test("the purse leaves the objective banner room to read", function()
	-- At the narrowest screen the banner still has to fit two short lines.
	local reserved = HudLayout.EDGE * 2 + HudLayout.RAIL_W + HudLayout.GAP
	local rowWidth = 568 - reserved
	local bannerWidth = rowWidth - (HudLayout.PURSE_W + HudLayout.GAP)
	h.expectTrue(bannerWidth >= 240, `objective banner is only {bannerWidth}pt wide at 568pt`)
end)
