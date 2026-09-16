--!strict
local h = require("./helpers")
local Snatch = require("../../src/shared/Config/Snatch")
local SnatchRules = require("../../src/shared/Logic/SnatchRules")

h.suite("SnatchRules")

local function ctx(overrides: { [string]: any }): SnatchRules.Context
	local base: { [string]: any } = {
		thiefUserId = 1,
		targetUserId = 2,
		targetPlaytime = 9999,
		thiefIncomePerSecond = 100,
		targetIncomePerSecond = 100,
		lastAttemptAt = nil,
		now = 1000,
		gateUp = false,
		protected = false,
		thiefHasFreePedestal = true,
		thiefCarrying = false,
	}
	for key, value in overrides do
		base[key] = value
	end
	return base :: any
end

h.test("a fair snatch is allowed", function()
	local ok = SnatchRules.check(ctx({}), Snatch)
	h.expectTrue(ok, "a normal snatch between equals should be allowed")
end)

h.test("every refusal carries a readable reason", function()
	local cases = {
		{ targetUserId = 1 },
		{ thiefCarrying = true },
		{ protected = true },
		{ gateUp = true },
		{ thiefHasFreePedestal = false },
		{ targetPlaytime = 0 },
		{ targetIncomePerSecond = 1 },
		{ lastAttemptAt = 990 },
	}
	for i, overrides in cases do
		local ok, reason = SnatchRules.check(ctx(overrides), Snatch)
		h.expectTrue(not ok, `case {i} should have been refused`)
		h.expectTrue(reason ~= nil and #reason > 0, `case {i} refused with no reason`)
		-- These strings go straight to a child's screen.
		h.expectTrue(
			not string.find(reason :: string, "nil"),
			`case {i} leaked a nil into its message`
		)
	end
end)

h.test("REGRESSION: you cannot snatch from your own base", function()
	local ok = SnatchRules.check(ctx({ targetUserId = 1 }), Snatch)
	h.expectTrue(not ok, "self-snatch must be refused")
end)

h.test("the newcomer shield holds for the configured time", function()
	local justUnder =
		SnatchRules.check(ctx({ targetPlaytime = Snatch.NEWCOMER_SHIELD_SECONDS - 1 }), Snatch)
	local justOver =
		SnatchRules.check(ctx({ targetPlaytime = Snatch.NEWCOMER_SHIELD_SECONDS + 1 }), Snatch)
	h.expectTrue(not justUnder, "a newcomer must be protected")
	h.expectTrue(justOver, "the shield must expire")
end)

h.test("the strong cannot farm the weak, but the weak may rob the strong", function()
	-- The asymmetry is the point: being behind should make the game more
	-- interesting, not mark you as prey.
	local strongOnWeak =
		SnatchRules.check(ctx({ thiefIncomePerSecond = 1000, targetIncomePerSecond = 10 }), Snatch)
	h.expectTrue(not strongOnWeak, "a far stronger player must be refused")

	local weakOnStrong =
		SnatchRules.check(ctx({ thiefIncomePerSecond = 10, targetIncomePerSecond = 1000 }), Snatch)
	h.expectTrue(weakOnStrong, "a weaker player must be allowed to rob a stronger one")
end)

h.test("a brand-new thief with no income can still snatch", function()
	-- The ratio rule divides by the thief's income. At zero it must not block
	-- them, and must not divide by zero either.
	local ok = SnatchRules.check(ctx({ thiefIncomePerSecond = 0 }), Snatch)
	h.expectTrue(ok, "a thief earning nothing must still be allowed to try")
end)

h.test("the per-target cooldown counts down and then clears", function()
	local tooSoon, reason = SnatchRules.check(ctx({ lastAttemptAt = 1000 - 10 }), Snatch)
	h.expectTrue(not tooSoon, "a repeat attempt must be refused")
	h.expectTrue(
		string.find(reason :: string, "%d") ~= nil,
		"the refusal should say how long to wait"
	)

	local later = SnatchRules.check(
		ctx({ lastAttemptAt = 1000 - Snatch.TARGET_COOLDOWN_SECONDS - 1 }),
		Snatch
	)
	h.expectTrue(later, "the cooldown must expire")
end)

h.test("the loss softener exists", function()
	-- Being robbed must hand you something, not only take something (GDD 5.8).
	h.expectTrue(Snatch.COMEBACK_EGG ~= nil, "a victim must get a comeback egg")
	h.expectTrue(Snatch.CARRY_TIMEOUT_SECONDS > 0, "a carried Nomling must come home by itself")
end)
