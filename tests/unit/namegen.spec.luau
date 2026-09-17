--!strict
local h = require("./helpers")
local NameGen = require("../../src/shared/Logic/NameGen")
local Nomlings = require("../../src/shared/Config/Nomlings")
local NameSafety = require("../../src/shared/Config/NameSafety")

h.suite("NameGen")

local SPECIES = Nomlings.SPECIES
local AFFIXES = Nomlings.GEN3_AFFIXES
local PUREBRED = Nomlings.PUREBRED_AFFIX

h.test("reproduces the brief's own example", function()
	-- Sushi Pup + Waffle Walrus -> Sushiwal. If this ever changes, the naming
	-- rule has drifted from the design.
	local sushi = Nomlings.get("sushi_pup")
	local walrus = Nomlings.get("waffle_walrus")
	h.expectEqual(NameGen.build(sushi, walrus, 2, AFFIXES, PUREBRED), "Sushiwal")
end)

h.test("ordered pairs give different creatures", function()
	local sushi = Nomlings.get("sushi_pup")
	local walrus = Nomlings.get("waffle_walrus")
	h.expectEqual(NameGen.build(sushi, walrus, 2, AFFIXES, PUREBRED), "Sushiwal")
	h.expectEqual(NameGen.build(walrus, sushi, 2, AFFIXES, PUREBRED), "Wafflepup")
end)

h.test("same species fused with itself is a Prime", function()
	local taco = Nomlings.get("taco_rhino")
	h.expectEqual(NameGen.build(taco, taco, 2, AFFIXES, PUREBRED), "Prime Tacorhino")
end)

h.test("names are deterministic across repeated calls", function()
	-- Determinism is load-bearing: the Fusion Book, World First credit and
	-- every screenshot depend on the same genome always producing the same name.
	for _, snack in SPECIES do
		for _, animal in SPECIES do
			local seed = NameGen.seedFor(snack.id, animal.id, 3, nil)
			local first = NameGen.build(snack, animal, 3, AFFIXES, PUREBRED, seed)
			for _ = 1, 3 do
				h.expectEqual(NameGen.build(snack, animal, 3, AFFIXES, PUREBRED, seed), first)
			end
		end
	end
end)

h.test("the seed depends only on what the creature is", function()
	local a = NameGen.seedFor("sushi_pup", "waffle_walrus", 2, nil)
	local b = NameGen.seedFor("sushi_pup", "waffle_walrus", 2, nil)
	h.expectEqual(a, b, "same inputs must give the same seed")

	local differentGen = NameGen.seedFor("sushi_pup", "waffle_walrus", 3, nil)
	h.expectTrue(differentGen ~= a, "generation must change the seed")

	local withMutation = NameGen.seedFor("sushi_pup", "waffle_walrus", 2, "rainbow")
	h.expectTrue(withMutation ~= a, "mutation must change the seed")
end)

h.test("the name space is exactly 876 creatures", function()
	-- 12 base + 144 gen-2 (ordered) + 720 gen-3 (144 x 5 affixes).
	-- docs/NOMLINGS.md and docs/MARKETING.md both quote this number; marketing
	-- must never claim "thousands of creatures" when it is 876.
	local all = NameGen.enumerate(SPECIES, AFFIXES, PUREBRED)
	h.expectEqual(#all, 876, "total reachable creatures")

	local counts = { [1] = 0, [2] = 0, [3] = 0 }
	for _, entry in all do
		counts[entry.gen] += 1
	end
	h.expectEqual(counts[1], 12, "gen 1")
	h.expectEqual(counts[2], 144, "gen 2")
	h.expectEqual(counts[3], 720, "gen 3")
end)

h.test("every combo key is unique", function()
	-- World First is claimed by DataStore UpdateAsync on the combo key. A
	-- duplicate key would let two different creatures claim the same first.
	local seen: { [string]: string } = {}
	for _, entry in NameGen.enumerate(SPECIES, AFFIXES, PUREBRED) do
		local existing = seen[entry.key]
		h.expectTrue(
			existing == nil,
			`key '{entry.key}' is used by both '{existing}' and '{entry.name}'`
		)
		seen[entry.key] = entry.name
	end
end)

h.test("gen-3 names never collide with gen-2 names", function()
	local gen2: { [string]: boolean } = {}
	for _, entry in NameGen.enumerate(SPECIES, AFFIXES, PUREBRED) do
		if entry.gen == 2 then
			gen2[entry.name] = true
		end
	end
	for _, entry in NameGen.enumerate(SPECIES, AFFIXES, PUREBRED) do
		if entry.gen == 3 then
			h.expectTrue(
				not gen2[entry.name],
				`gen-3 name '{entry.name}' collides with a gen-2 name`
			)
		end
	end
end)

h.suite("NameSafety")

h.test("EXHAUSTIVE: no generated name hits the blocklist", function()
	-- The full cross-product, never a sample. A sampled test would let a bad
	-- name ship on the day someone adds a species.
	local offenders = {}
	for _, entry in NameGen.enumerate(SPECIES, AFFIXES, PUREBRED) do
		local hit = NameSafety.check(entry.name)
		if hit then
			table.insert(offenders, `{entry.name} (contains '{hit}')`)
		end
	end
	h.expectTrue(#offenders == 0, `{#offenders} unsafe name(s): {table.concat(offenders, ", ")}`)
end)

h.test("the safety check actually catches things", function()
	-- Guards against the check silently passing everything, which would make
	-- the exhaustive test above worthless.
	h.expectTrue(NameSafety.check("Shitake Mushroom") ~= nil, "profanity substring")
	h.expectTrue(NameSafety.check("Sushitiger") ~= nil, "the real collision this test caught")
	h.expectTrue(NameSafety.check("Pikachu Pup") ~= nil, "brand")
	h.expectTrue(NameSafety.check("Free Robux Cat") ~= nil, "filter risk")
	h.expectEqual(NameSafety.check("Sushiwal"), nil, "a clean name must pass")
	h.expectEqual(NameSafety.check("Titan Tacorhino"), nil, "allowlist: 'Titan' is not 'tit'")
	h.expectEqual(NameSafety.check("Mega Cupcakeparr"), nil, "a clean gen-3 name must pass")
end)

h.test("the check ignores spaces, so affixes cannot hide a collision", function()
	h.expectTrue(NameSafety.check("Mega Shitter") ~= nil, "spaced profanity")
	h.expectTrue(NameSafety.check("Pika chu") ~= nil, "spaced brand")
end)

h.test("species ids and tokens are unique", function()
	local ids, heads, tails = {}, {}, {}
	for _, species in SPECIES do
		h.expectTrue(ids[species.id] == nil, `duplicate species id '{species.id}'`)
		h.expectTrue(heads[species.head] == nil, `duplicate head '{species.head}'`)
		h.expectTrue(tails[species.tail] == nil, `duplicate tail '{species.tail}'`)
		ids[species.id], heads[species.head], tails[species.tail] = true, true, true
	end
	h.expectEqual(#SPECIES, 12, "roster size")
end)

return true
