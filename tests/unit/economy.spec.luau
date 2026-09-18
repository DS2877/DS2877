--!strict
local h = require("./helpers")
local Economy = require("../../src/shared/Config/Economy")

h.suite("Economy")

h.test("REGRESSION: rebirth must not be a dead end", function()
	-- The simulator found this before any code existed (docs/ECONOMY.md 4.1):
	-- rebirth resets coins AND every pedestal Nomling, so income and bank are
	-- both zero. The cheapest egg costs more than zero, so without a free
	-- restart egg the player can never earn another coin -- permanently stuck,
	-- one minute into the reward for their first half hour.
	--
	-- If this ever fails, the game is unplayable after the first rebirth.
	for rebirths = 0, 10 do
		local cheapest = math.huge
		for eggKey, egg in Economy.EGGS do
			if egg.unlockRebirth <= rebirths then
				cheapest = math.min(cheapest, Economy.eggPrice(eggKey, rebirths))
			end
		end
		h.expectTrue(cheapest > 0, `an egg at rebirth {rebirths} costs nothing?`)
	end

	h.expectTrue(
		Economy.REBIRTH_GRANTS_FREE_EGG,
		"post-rebirth coins and income are both zero and every egg costs coins, "
			.. "so REBIRTH_GRANTS_FREE_EGG must stay true or players soft-lock"
	)
end)

h.test("rebirth cost grows strictly with each rebirth", function()
	local previous = 0
	for n = 0, 12 do
		local cost = Economy.rebirthCost(n)
		h.expectTrue(cost > previous, `rebirthCost({n}) = {cost} is not above {previous}`)
		previous = cost
	end
end)

h.test("rebirth multiplier grows strictly", function()
	h.expectEqual(Economy.rebirthMultiplier(0), 1, "no rebirths means no multiplier")
	local previous = 0
	for n = 0, 12 do
		local mult = Economy.rebirthMultiplier(n)
		h.expectTrue(mult > previous, `rebirthMultiplier({n}) did not grow`)
		previous = mult
	end
end)

h.test("egg prices scale with rebirth count", function()
	-- Without this the shop stops being a coin sink and income runs away:
	-- the simulator hit 220 rebirths in 28 days with flat prices.
	local atZero = Economy.eggPrice("basic", 0)
	local atFive = Economy.eggPrice("basic", 5)
	h.expectEqual(atZero, Economy.EGGS.basic.price, "base price at rebirth 0")
	h.expectTrue(atFive > atZero * 100, "prices must climb steeply across five rebirths")
end)

h.test("eggPrice rejects an unknown egg", function()
	h.expectError(function()
		Economy.eggPrice("nonexistent", 0)
	end)
end)

h.test("every egg tier is reachable", function()
	for eggKey, egg in Economy.EGGS do
		h.expectTrue(egg.unlockRebirth >= 0, `{eggKey} has a negative unlock`)
		h.expectTrue(
			egg.unlockRebirth <= 10,
			`{eggKey} unlocks at rebirth {egg.unlockRebirth}, likely unreachable`
		)
		h.expectTrue(egg.hatch > 0, `{eggKey} hatches instantly`)
	end
end)

h.test("higher egg tiers pay better on average", function()
	local function expectedIncome(eggKey: string): number
		local total = 0
		for rarity, ppm in Economy.EGGS[eggKey].odds do
			total += Economy.BASE_INCOME[rarity] * (ppm / 1000000)
		end
		return total
	end

	local order = { "basic", "picnic", "bakery", "sushibar", "candycloud", "cosmic" }
	local previous = 0
	for _, eggKey in order do
		local income = expectedIncome(eggKey)
		h.expectTrue(income > previous, `{eggKey} pays {income}, not above {previous}`)
		previous = income
	end
end)

h.test("weather uplift matches the documented 1.22x", function()
	-- docs/ECONOMY.md quotes this figure; if weather is retuned, that document
	-- needs updating in the same change.
	h.expectNear(Economy.averageWeatherFactor(), 1.220, 0.001, "average weather factor")
end)

h.test("fusion has exactly one slot at base", function()
	-- The single slot is the economy's main throttle (docs/ECONOMY.md 4.2).
	-- Changing it is a release, not a tweak.
	h.expectEqual(Economy.FUSION_SLOTS_BASE, 1, "base fusion slots")
end)

h.test("REGRESSION: rarity ranks come from a lookup, not the array", function()
	-- RARITY_ORDER is an ARRAY. It reads like a lookup table and is not one:
	-- RARITY_ORDER["rare"] is nil, silently, and a caller comparing creatures
	-- that way rates every one of them equally. PlotService picks which stored
	-- Nomling to put back out by exactly this comparison.
	for rank, name in Economy.RARITY_ORDER do
		h.expectEqual(Economy.rarityRank(name), rank, `{name} should rank {rank}`)
	end
	h.expectEqual(Economy.rarityRank("not-a-rarity"), 0, "unknown rarities rank last")

	-- And the order is an order: every rarity strictly beats the one before.
	for i = 2, #Economy.RARITY_ORDER do
		h.expectTrue(
			Economy.rarityRank(Economy.RARITY_ORDER[i])
				> Economy.rarityRank(Economy.RARITY_ORDER[i - 1]),
			`{Economy.RARITY_ORDER[i]} does not outrank {Economy.RARITY_ORDER[i - 1]}`
		)
	end
end)

return true
