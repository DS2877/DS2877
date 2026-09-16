--!strict
local h = require("./helpers")
local Income = require("../../src/shared/Logic/Income")
local Economy = require("../../src/shared/Config/Economy")

h.suite("Income")

local MUT: { [string]: number } = {}
for name, spec in Economy.MUTATIONS do
	MUT[name] = if type(spec) == "table" then (spec :: any).incomeMultiplier or 1 else spec
end

h.test("an empty base earns nothing", function()
	h.expectEqual(Income.perSecond({}, Economy.BASE_INCOME, MUT, 1, 1), 0, "empty base")
end)

h.test("income scales with rarity, in the configured order", function()
	local previous = -1
	for _, rarity in Economy.RARITY_ORDER do
		local rate = Income.forOne({ rarity = rarity }, Economy.BASE_INCOME, MUT)
		h.expectTrue(rate > previous, `{rarity} must out-earn the tier below it`)
		previous = rate
	end
end)

h.test("an unknown rarity earns zero instead of erroring", function()
	-- A creature from a future content update must not break a whole base's
	-- income on an old server.
	local rate = Income.forOne({ rarity = "impossible" }, Economy.BASE_INCOME, MUT)
	h.expectEqual(rate, 0, "unknown rarity")
end)

h.test("rebirth and weather multiply the whole base", function()
	local base = { { rarity = "common" }, { rarity = "rare" } }
	local plain = Income.perSecond(base, Economy.BASE_INCOME, MUT, 1, 1)
	local boosted = Income.perSecond(base, Economy.BASE_INCOME, MUT, 2.6, 2)
	h.expectNear(boosted, plain * 5.2, 1e-9, "multipliers should compose")
end)

-- --- offline ---------------------------------------------------------------

h.test("offline earnings are capped", function()
	local perSecond = 100
	local capped = Income.offline(
		perSecond,
		30 * 24 * 3600,
		Economy.OFFLINE_EFFICIENCY,
		Economy.OFFLINE_CAP_SECONDS
	)
	local atCap = Income.offline(
		perSecond,
		Economy.OFFLINE_CAP_SECONDS,
		Economy.OFFLINE_EFFICIENCY,
		Economy.OFFLINE_CAP_SECONDS
	)
	h.expectEqual(capped, atCap, "a month away must pay the same as the cap")
end)

h.test("REGRESSION: a clock that jumps backwards pays nothing", function()
	-- os.time() can move backwards across servers. A negative elapsed time must
	-- never become a negative payout, and must never become a huge positive one.
	h.expectEqual(Income.offline(100, -9999, 0.25, 7200), 0, "negative elapsed")
	h.expectEqual(Income.offline(100, 0, 0.25, 7200), 0, "zero elapsed")
	h.expectEqual(Income.offline(0, 9999, 0.25, 7200), 0, "zero rate")
end)

h.test("offline is worth less than playing", function()
	-- If this ever inverts, the best strategy becomes not playing the game.
	h.expectTrue(Economy.OFFLINE_EFFICIENCY < 1, "OFFLINE_EFFICIENCY must stay below 1")
	local seconds = 3600
	local online = 100 * seconds
	local offline =
		Income.offline(100, seconds, Economy.OFFLINE_EFFICIENCY, Economy.OFFLINE_CAP_SECONDS)
	h.expectTrue(offline < online, "an hour away must earn less than an hour played")
end)

-- --- display ---------------------------------------------------------------

h.test("numbers shorten for a phone screen", function()
	h.expectEqual(Income.format(0), "0", "zero")
	h.expectEqual(Income.format(999), "999", "under 1K")
	h.expectEqual(Income.format(1000), "1.00K", "exactly 1K")
	h.expectEqual(Income.format(1234), "1.23K", "1.23K")
	h.expectEqual(Income.format(12345), "12.3K", "12.3K")
	h.expectEqual(Income.format(123456), "123K", "123K")
	h.expectEqual(Income.format(1e6), "1.00M", "1M")
	h.expectEqual(Income.format(1e9), "1.00B", "1B")
end)

h.test("the display never runs out of units", function()
	-- Late game reaches numbers that would index past the end of the table.
	for power = 0, 40 do
		local text = Income.format(10 ^ power)
		h.expectTrue(#text > 0 and #text <= 8, `10^{power} formatted as '{text}'`)
	end
end)
