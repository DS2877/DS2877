--!strict
local h = require("./helpers")
local Odds = require("../../src/shared/Logic/Odds")
local Economy = require("../../src/shared/Config/Economy")

h.suite("Odds")

h.test("every egg's odds sum to exactly 1,000,000 ppm", function()
	-- This is a COMPLIANCE requirement, not a balance one: Roblox requires
	-- disclosed odds to total 100%. docs/COMPLIANCE.md section 2.
	for eggKey, egg in Economy.EGGS do
		Odds.assertValid(egg.odds, eggKey)
	end
end)

h.test("assertValid rejects a table that is one ppm short", function()
	h.expectError(function()
		Odds.assertValid({ common = 999999 }, "broken")
	end)
end)

h.test("pick is deterministic for a given roll", function()
	local odds = Economy.EGGS.basic.odds
	for _, roll in { 0, 1, 699999, 700000, 999999 } do
		h.expectEqual(Odds.pick(odds, roll), Odds.pick(odds, roll), `roll {roll}`)
	end
end)

h.test("pick respects the cumulative boundaries of the basic egg", function()
	local odds = Economy.EGGS.basic.odds
	h.expectEqual(Odds.pick(odds, 0), "common", "roll 0")
	h.expectEqual(Odds.pick(odds, 699999), "common", "last common roll")
	h.expectEqual(Odds.pick(odds, 700000), "uncommon", "first uncommon roll")
	h.expectEqual(Odds.pick(odds, 999999), "secret", "last roll is the 1-in-a-million")
end)

h.test("pick covers every roll in range", function()
	-- Walk the whole space in coarse steps; no roll may fall through.
	local odds = Economy.EGGS.basic.odds
	for roll = 0, 999999, 997 do
		local rarity = Odds.pick(odds, roll)
		h.expectTrue(Economy.BASE_INCOME[rarity] ~= nil, `roll {roll} produced '{rarity}'`)
	end
end)

h.test("formatPercent keeps tiny odds visible", function()
	-- 1 ppm must not render as "0%" -- players are entitled to see the real number.
	h.expectEqual(Odds.formatPercent(1), "0.0001%")
	h.expectEqual(Odds.formatPercent(99), "0.0099%")
	h.expectEqual(Odds.formatPercent(700000), "70.0%")
end)

return true
