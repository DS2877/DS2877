--!strict
local h = require("./helpers")
local Economy = require("../../src/shared/Config/Economy")
local FusionRules = require("../../src/shared/Logic/FusionRules")
local NameGen = require("../../src/shared/Logic/NameGen")
local Nomlings = require("../../src/shared/Config/Nomlings")

h.suite("FusionRules")

local CONFIG: FusionRules.Config = {
	MAX_GEN = Economy.MAX_GEN,
	FUSION_UPGRADE_CHANCE_SAME_TIER = Economy.FUSION_UPGRADE_CHANCE_SAME_TIER,
	FUSION_UPGRADE_CHANCE_DIFF_TIER = Economy.FUSION_UPGRADE_CHANCE_DIFF_TIER,
	FUSION_MUTATION_INHERIT_CHANCE = Economy.FUSION_MUTATION_INHERIT_CHANCE,
	RARITY_ORDER = Economy.RARITY_ORDER,
}

local NO_UPGRADE: FusionRules.Rolls = { upgrade = 0.99, mutation = 0.99, mutationPick = 0 }
local ALWAYS_UPGRADE: FusionRules.Rolls = { upgrade = 0.0, mutation = 0.99, mutationPick = 0 }
local INHERIT: FusionRules.Rolls = { upgrade = 0.99, mutation = 0.0, mutationPick = 0 }

local function parent(
	id: string,
	snack: string,
	animal: string,
	rarity: string,
	gen: number?,
	mutation: string?
): FusionRules.Parent
	return {
		id = id,
		snack = snack,
		animal = animal,
		gen = gen or 1,
		mutation = mutation,
		rarity = rarity,
		seed = 42,
	}
end

h.test("REGRESSION: fusion is an ORDERED pair", function()
	-- Sushi Pup + Waffle Walrus is Sushiwal; the other way round is Wafflepup.
	-- Different creature, different Book entry. If this ever collapses into an
	-- unordered pair the discovery space halves overnight.
	local a = parent("1", "sushi", "pup", "common")
	local b = parent("2", "waffle", "walrus", "common")
	local ab = FusionRules.combine(a, b, CONFIG, NO_UPGRADE)
	local ba = FusionRules.combine(b, a, CONFIG, NO_UPGRADE)
	h.expectEqual(ab.snack, "sushi", "A contributes the snack")
	h.expectEqual(ab.animal, "walrus", "B contributes the animal")
	h.expectEqual(ba.snack, "waffle", "reversed: A contributes the snack")
	h.expectEqual(ba.animal, "pup", "reversed: B contributes the animal")
	h.expectTrue(ab.snack ~= ba.snack, "the two orders must differ")
end)

h.test("the generated name matches the combination", function()
	local sushi = Nomlings.BY_ID.sushi_pup
	local waffle = Nomlings.BY_ID.waffle_walrus
	local name = NameGen.build(sushi, waffle, 2, Nomlings.GEN3_AFFIXES, Nomlings.PUREBRED_AFFIX)
	-- The brief's own worked example.
	h.expectEqual(name, "Sushiwal", "Sushi Pup + Waffle Walrus")
end)

h.test("gen climbs and then caps", function()
	local a = parent("1", "taco", "rhino", "common", 1)
	local b = parent("2", "sushi", "pup", "common", 1)
	h.expectEqual(FusionRules.combine(a, b, CONFIG, NO_UPGRADE).gen, 2, "gen 1 + gen 1")

	local c = parent("3", "taco", "rhino", "common", 2)
	h.expectEqual(FusionRules.combine(c, b, CONFIG, NO_UPGRADE).gen, 3, "gen 2 + gen 1")

	local d = parent("4", "taco", "rhino", "common", 3)
	local e = parent("5", "sushi", "pup", "common", 2)
	h.expectEqual(FusionRules.combine(d, e, CONFIG, NO_UPGRADE).gen, Economy.MAX_GEN, "capped")
end)

h.test("two max-gen parents cannot be fused, and the refusal says so", function()
	local a = parent("1", "taco", "rhino", "common", Economy.MAX_GEN)
	local b = parent("2", "sushi", "pup", "common", Economy.MAX_GEN)
	local ok, reason = FusionRules.check(a, b, CONFIG)
	h.expectTrue(not ok, "two gen-3 parents should be refused")
	h.expectTrue(reason ~= nil and #(reason :: string) > 0, "refusal must carry a reason")
end)

h.test("the child never comes out worse than its best parent", function()
	-- A fusion that can downgrade is a fusion nobody will ever risk.
	for i = 1, #Economy.RARITY_ORDER do
		for j = 1, #Economy.RARITY_ORDER do
			local a = parent("1", "taco", "rhino", Economy.RARITY_ORDER[i])
			local b = parent("2", "sushi", "pup", Economy.RARITY_ORDER[j])
			for _, rolls in { NO_UPGRADE, ALWAYS_UPGRADE } do
				local child = FusionRules.combine(a, b, CONFIG, rolls)
				local childIndex = table.find(Economy.RARITY_ORDER, child.rarity) or 0
				h.expectTrue(
					childIndex >= math.max(i, j),
					`{Economy.RARITY_ORDER[i]} + {Economy.RARITY_ORDER[j]} produced {child.rarity}`
				)
			end
		end
	end
end)

h.test("matching tiers upgrade more often than mismatched ones", function()
	-- The whole strategy layer: pairing two of the same tier must be better
	-- than fusing whatever is nearest, or there is no decision to make.
	h.expectTrue(
		Economy.FUSION_UPGRADE_CHANCE_SAME_TIER > Economy.FUSION_UPGRADE_CHANCE_DIFF_TIER,
		"same-tier upgrade chance must beat mismatched"
	)
	local same = FusionRules.combine(
		parent("1", "taco", "rhino", "rare"),
		parent("2", "sushi", "pup", "rare"),
		CONFIG,
		{
			upgrade = (
				Economy.FUSION_UPGRADE_CHANCE_SAME_TIER + Economy.FUSION_UPGRADE_CHANCE_DIFF_TIER
			) / 2,
			mutation = 1,
			mutationPick = 0,
		}
	)
	local mixed = FusionRules.combine(
		parent("1", "taco", "rhino", "rare"),
		parent("2", "sushi", "pup", "common"),
		CONFIG,
		{
			upgrade = (
				Economy.FUSION_UPGRADE_CHANCE_SAME_TIER + Economy.FUSION_UPGRADE_CHANCE_DIFF_TIER
			) / 2,
			mutation = 1,
			mutationPick = 0,
		}
	)
	h.expectTrue(same.upgraded, "matching tiers should have upgraded at this roll")
	h.expectTrue(not mixed.upgraded, "mismatched tiers should not have")
end)

h.test("the top tier cannot be upgraded past itself", function()
	local top = Economy.RARITY_ORDER[#Economy.RARITY_ORDER]
	local child = FusionRules.combine(
		parent("1", "taco", "rhino", top),
		parent("2", "sushi", "pup", top),
		CONFIG,
		ALWAYS_UPGRADE
	)
	h.expectEqual(child.rarity, top, "must stay at the top tier")
	h.expectTrue(not child.upgraded, "and must not claim it upgraded")
end)

h.test("REGRESSION: fusion cannot invent a mutation", function()
	-- Mutations come from weather (GDD 5.7). If fusion could create them,
	-- weather stops mattering and fusion becomes the only thing worth doing.
	local child = FusionRules.combine(
		parent("1", "taco", "rhino", "common"),
		parent("2", "sushi", "pup", "common"),
		CONFIG,
		INHERIT
	)
	h.expectEqual(child.mutation, nil, "two unmutated parents produced a mutation")
end)

h.test("a mutation can be inherited from either parent", function()
	local fromA = FusionRules.combine(
		parent("1", "taco", "rhino", "common", 1, "rainbow"),
		parent("2", "sushi", "pup", "common"),
		CONFIG,
		INHERIT
	)
	h.expectEqual(fromA.mutation, "rainbow", "should inherit from A")

	local fromB = FusionRules.combine(
		parent("1", "taco", "rhino", "common"),
		parent("2", "sushi", "pup", "common", 1, "galaxy"),
		CONFIG,
		INHERIT
	)
	h.expectEqual(fromB.mutation, "galaxy", "should inherit from B")

	local both = FusionRules.combine(
		parent("1", "taco", "rhino", "common", 1, "rainbow"),
		parent("2", "sushi", "pup", "common", 1, "galaxy"),
		CONFIG,
		{ upgrade = 0.99, mutation = 0.0, mutationPick = 0.99 }
	)
	h.expectEqual(both.mutation, "galaxy", "the pick roll should choose the second")
end)

h.test("a Nomling cannot be fused with itself", function()
	local a = parent("1", "taco", "rhino", "common")
	local ok, reason = FusionRules.check(a, a, CONFIG)
	h.expectTrue(not ok, "self-fusion must be refused")
	h.expectTrue(reason ~= nil, "refusal must carry a reason")
end)

h.test("income compounds, and gen 3 compounds harder", function()
	local gen2 =
		FusionRules.income(10, 10, 2, Economy.FUSION_INCOME_FACTOR, Economy.FUSION_GEN_BONUS)
	local gen3 =
		FusionRules.income(10, 10, 3, Economy.FUSION_INCOME_FACTOR, Economy.FUSION_GEN_BONUS)
	h.expectTrue(gen2 > 20, "a fused child must out-earn its parents combined")
	h.expectTrue(gen3 > gen2, "gen 3 must out-earn gen 2")
end)

h.test("purebred pairs are recognised", function()
	local a = parent("1", "taco", "rhino", "common")
	local b = parent("2", "taco", "rhino", "rare")
	h.expectTrue(FusionRules.isPurebred(a, b), "same species should be purebred")
	h.expectTrue(
		not FusionRules.isPurebred(a, parent("3", "sushi", "pup", "common")),
		"different species should not be"
	)
end)

h.test("every ordered pair on the roster produces a safe, named creature", function()
	-- 144 combinations. The name safety test already sweeps the names; this
	-- checks the RULES hold for every pair, which is the half that decides what
	-- a player actually owns.
	local checked = 0
	for _, a in Nomlings.SPECIES do
		for _, b in Nomlings.SPECIES do
			local pa = parent("a", a.snack, a.animal, "common")
			local pb = parent("b", b.snack, b.animal, "uncommon")
			local child = FusionRules.combine(pa, pb, CONFIG, NO_UPGRADE)
			h.expectEqual(child.snack, a.snack, `{a.id} + {b.id} snack`)
			h.expectEqual(child.animal, b.animal, `{a.id} + {b.id} animal`)
			h.expectEqual(child.gen, 2, `{a.id} + {b.id} gen`)
			local name = NameGen.build(a, b, 2, Nomlings.GEN3_AFFIXES, Nomlings.PUREBRED_AFFIX)
			h.expectTrue(#name > 0, `{a.id} + {b.id} produced an empty name`)
			checked += 1
		end
	end
	h.expectEqual(checked, #Nomlings.SPECIES * #Nomlings.SPECIES, "should cover every ordered pair")
end)

h.test("REGRESSION: fusion timings are keyed by rarity, not gen", function()
	-- FUSION_SECONDS is a rarity -> seconds table. An early version of
	-- FusionService indexed it by gen, which returned nil for every fusion and
	-- silently fell through to the 8-second FTUE time -- collapsing the entire
	-- timing curve without any error.
	for _, rarity in Economy.RARITY_ORDER do
		h.expectTrue(
			type(Economy.FUSION_SECONDS[rarity]) == "number",
			`FUSION_SECONDS has no entry for rarity '{rarity}'`
		)
	end
	for gen = 1, Economy.MAX_GEN do
		h.expectEqual(
			Economy.FUSION_SECONDS[gen],
			nil,
			`FUSION_SECONDS should not be indexable by gen {gen}`
		)
	end
	-- And the curve must actually climb, or rarity costs nothing to wait for.
	local previous = 0
	for _, rarity in Economy.RARITY_ORDER do
		local seconds = Economy.FUSION_SECONDS[rarity]
		h.expectTrue(seconds > previous, `{rarity} fuses no slower than the tier below`)
		previous = seconds
	end
end)
