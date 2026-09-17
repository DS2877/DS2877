--!strict
--[[
	Where every band of on-screen furniture sits, in pixels from the safe-area
	edges. Numbers only -- no Instances -- so Lune can check the whole screen
	composition without a DataModel, the same way World.luau lets it check the
	street.

	THIS EXISTS BECAUSE OF A PLAYTEST. The first HUD used 58-72 px controls,
	each band positioned by hand against a screen edge. On a phone the objective
	banner ran under the Roblox menu buttons, the "?" landed on top of the
	banner, the incubator button floated in the middle of nowhere, and the three
	bottom buttons ate the bottom fifth of the display. Every one of those is an
	arithmetic mistake, and arithmetic is testable. Change a number here and
	tests/unit/hud.spec.luau tells you what you just covered up.

	BaseHudController reads these and lays out Instances; it invents no
	positions of its own.
]]

local HudLayout = {}

--- Apple's and Google's floor for a touch target, and the number to argue with
--- if any of these get smaller.
HudLayout.TOUCH_MIN = 44

--- Gap from the safe-area edge.
HudLayout.EDGE = 10

--- The purse / objective row across the top.
HudLayout.TOP_H = 44
HudLayout.TOP_Y = 6
HudLayout.PURSE_W = 152

--- Round buttons down the right edge.
HudLayout.RAIL_W = 44
HudLayout.RAIL_GAP = 6

--- The three-button row along the bottom.
HudLayout.BAR_H = 50
--- Stretched across a tablet a row of three is a worse row of three.
HudLayout.BAR_MAX_W = 520

-- THE INCUBATOR TRAY IS GONE FROM THE SCREEN. It used to sit on top of the
-- bar, and a playtester asked for two things at once: "the buttons and layout
-- on the screen is way too much", and "the 'tap to hatch' should be grounded
-- on something next to what's about to hatch". Both are answered by the same
-- move -- the eggs are now a nest you walk up to in your own base, built by
-- HatcheryController, so the screen gets a whole band back and the thing you
-- press is where the thing you are waiting for actually is.

HudLayout.TOAST_H = 40

--- Gap between two stacked bands.
HudLayout.GAP = 8

-- --- derived ---------------------------------------------------------------
-- Each band is measured from the edge it hangs off, so a band never has to
-- know a screen height. Stacked upward from the bottom, downward from the top.

HudLayout.RAIL_TOP = HudLayout.TOP_Y + HudLayout.TOP_H + HudLayout.GAP
HudLayout.BANNER_H = 44

HudLayout.BAR_TOP = HudLayout.EDGE + HudLayout.BAR_H
--- The toast is anchored by its BOTTOM edge, so this is the gap under it.
HudLayout.TOAST_TOP = HudLayout.BAR_TOP + HudLayout.GAP

--- Everything the rail must not run into, so its height is derived rather
--- than guessed.
HudLayout.RAIL_BOTTOM = HudLayout.TOAST_TOP + HudLayout.TOAST_H

export type Band = {
	name: string,
	--- Distance from the top of the safe area to this band's top edge.
	top: number,
	--- ...to its bottom edge.
	bottom: number,
	--- True when the band is anchored to the bottom of the screen; `top` and
	--- `bottom` are then measured from the bottom edge upward.
	fromBottom: boolean,
}

--- Every band, for a screen `height` points tall. Returned top-down in screen
--- coordinates so overlaps are a simple interval check.
function HudLayout.bands(height: number): { Band }
	local function up(name: string, topOffset: number, bandHeight: number): Band
		return {
			name = name,
			top = height - topOffset,
			bottom = height - topOffset + bandHeight,
			fromBottom = true,
		}
	end

	return {
		{
			name = "topRow",
			top = HudLayout.TOP_Y,
			bottom = HudLayout.TOP_Y + HudLayout.TOP_H,
			fromBottom = false,
		},
		{
			name = "bannerSlot",
			top = HudLayout.RAIL_TOP,
			bottom = HudLayout.RAIL_TOP + HudLayout.BANNER_H,
			fromBottom = false,
		},
		up("toast", HudLayout.TOAST_TOP + HudLayout.TOAST_H, HudLayout.TOAST_H),
		up("bar", HudLayout.BAR_TOP, HudLayout.BAR_H),
	}
end

--- How much of a `height`-tall screen the top and bottom furniture covers, as
--- a fraction. The middle is the game; this is the tax.
---
--- One number now that the incubator tray has moved into the world. It used to
--- take two, because the tray came and went and measuring only the resting
--- layout would have missed the case the playtest complained about.
function HudLayout.chromeFraction(height: number): number
	local top = HudLayout.TOP_Y + HudLayout.TOP_H
	return (top + HudLayout.BAR_TOP) / height
end

--- Widths of the three bottom-bar buttons, as fractions of the row. They MUST
--- sum to 1: the row sizes each child `scale` wide minus the gap, so anything
--- else either overflows the row or leaves a ragged end.
HudLayout.BAR_SPLIT = { fuse = 0.24, egg = 0.5, bubble = 0.26 }

return HudLayout
