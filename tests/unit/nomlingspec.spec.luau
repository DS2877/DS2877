--!strict
local h = require("./helpers")
local NomlingSpec = require("../../src/shared/Logic/NomlingSpec")
local Nomlings = require("../../src/shared/Config/Nomlings")

h.suite("NomlingSpec")

local ARCHETYPES = {
	"quadruped_wide",
	"quadruped_small",
	"quadruped_bulky",
	"quadruped_round",
	"biped_upright",
	"biped_round",
	"biped_winged",
	"squat_wide",
	"squat_small",
	"long_low",
	"pinniped_long",
	"aquatic_long",
}

local function genomeFor(species: any, gen: number?, mutation: string?): NomlingSpec.Genome
	return {
		snack = species.snack,
		animal = species.animal,
		gen = gen or 1,
		mutation = mutation,
		seed = 12345,
		archetype = species.archetype,
	}
end

h.test("every species on the roster builds a creature", function()
	for _, species in Nomlings.SPECIES do
		local parts = NomlingSpec.build(genomeFor(species))
		h.expectTrue(#parts > 0, `{species.id} produced no parts`)
	end
end)

h.test("REGRESSION: the 30-part budget is never exceeded", function()
	-- GDD 9: the test case is 8 players with 150+ Nomlings visible at once on a
	-- mid-range phone. Going over here multiplies by 150.
	for _, species in Nomlings.SPECIES do
		for gen = 1, 3 do
			for _, mutation in { nil :: string?, "rainbow" } do
				local parts = NomlingSpec.build(genomeFor(species, gen, mutation))
				h.expectTrue(
					#parts <= NomlingSpec.MAX_PARTS,
					`{species.id} gen {gen} used {#parts} parts, budget is {NomlingSpec.MAX_PARTS}`
				)
			end
		end
	end
end)

h.test("REGRESSION: every creature has two eyes and two pupils", function()
	-- A creature with no eyes reads as broken, not stylised. This is the single
	-- most noticeable way the builder could silently regress.
	for _, species in Nomlings.SPECIES do
		local parts = NomlingSpec.build(genomeFor(species))
		local eyes, pupils = 0, 0
		for _, part in parts do
			if part.role == "eye" then
				eyes += 1
			elseif part.role == "pupil" then
				pupils += 1
			end
		end
		h.expectEqual(eyes, 2, `{species.id} eye count`)
		h.expectEqual(pupils, 2, `{species.id} pupil count`)
	end
end)

h.test("every creature carries its snack layer", function()
	-- The snack overlay is what makes a fusion legible in under a second
	-- (docs/NOMLINGS.md 5). Without it every creature is just a coloured animal.
	for _, species in Nomlings.SPECIES do
		local parts = NomlingSpec.build(genomeFor(species))
		local snackParts = 0
		for _, part in parts do
			if part.role == "snack" then
				snackParts += 1
			end
		end
		h.expectTrue(snackParts >= 1, `{species.id} has no snack overlay`)
	end
end)

h.test("an unknown archetype still builds, using the fallback body", function()
	-- A species added by a future content update with a typo'd archetype must
	-- render as something plain rather than as nothing.
	local parts = NomlingSpec.build({
		snack = "taco",
		animal = "rhino",
		gen = 1,
		mutation = nil,
		seed = 1,
		archetype = "not_a_real_archetype",
	})
	h.expectTrue(#parts > 5, "fallback body produced almost nothing")
end)

h.test("an unknown snack still gets a topping", function()
	local parts = NomlingSpec.build({
		snack = "quesadilla",
		animal = "rhino",
		gen = 1,
		mutation = nil,
		seed = 1,
		archetype = "quadruped_wide",
	})
	local snackParts = 0
	for _, part in parts do
		if part.role == "snack" then
			snackParts += 1
		end
	end
	h.expectTrue(snackParts >= 1, "an unknown snack rendered no topping at all")
end)

h.test("every archetype has a distinct silhouette", function()
	-- If two archetypes produce the same torso, the roster's variety is a lie
	-- and fused creatures stop looking different from each other.
	local seen: { [string]: string } = {}
	for _, archetype in ARCHETYPES do
		local parts = NomlingSpec.build({
			snack = "taco",
			animal = "rhino",
			gen = 1,
			mutation = nil,
			seed = 1,
			archetype = archetype,
		})
		local torso = parts[1]
		h.expectEqual(torso.name, "Torso", `{archetype} does not start with a torso`)
		local key = `{torso.size.x}x{torso.size.y}x{torso.size.z}`
		h.expectEqual(seen[key], nil, `{archetype} has the same torso as {seen[key] or "?"}`)
		seen[key] = archetype
	end
end)

h.test("REGRESSION: geometry is deterministic from the genome", function()
	-- The same genome must build the same creature on every client, in every
	-- session, forever -- otherwise the Fusion Book, World First credit and
	-- every screenshot disagree with each other (docs/NOMLINGS.md 2).
	local genome = {
		snack = "sushi",
		animal = "walrus",
		gen = 2,
		mutation = "rainbow",
		seed = 987654,
		archetype = "pinniped_long",
	}
	local first = NomlingSpec.build(genome)
	local second = NomlingSpec.build(genome)
	h.expectEqual(#first, #second, "part count changed between builds")
	for i, part in first do
		local other = second[i]
		h.expectEqual(part.name, other.name, `part {i} name`)
		h.expectEqual(part.size.x, other.size.x, `part {i} size.x`)
		h.expectEqual(part.offset.y, other.offset.y, `part {i} offset.y`)
		h.expectEqual(part.role, other.role, `part {i} role`)
	end
	h.expectEqual(NomlingSpec.scaleFor(genome), NomlingSpec.scaleFor(genome), "scale")
end)

h.test("nothing sits below the ground", function()
	-- The origin is between the feet so a creature can be dropped on a pedestal
	-- without knowing its height. A part poking through the pedestal is the
	-- kind of thing that reads as amateur immediately.
	for _, species in Nomlings.SPECIES do
		local parts = NomlingSpec.build(genomeFor(species))
		for _, part in parts do
			local lowest = part.offset.y - part.size.y * 0.5
			h.expectTrue(
				lowest >= -0.35,
				`{species.id} part {part.name} reaches {lowest} studs below the origin`
			)
		end
	end
end)

h.test("gen 3 is visibly bigger than gen 1", function()
	local species = Nomlings.SPECIES[1]
	local small = NomlingSpec.scaleFor(genomeFor(species, 1))
	local large = NomlingSpec.scaleFor(genomeFor(species, 3))
	h.expectTrue(large > small * 1.25, `gen 3 scale {large} is not clearly bigger than {small}`)
end)

h.test("gen 3 gets its crown, gen 1 does not", function()
	local species = Nomlings.SPECIES[1]
	local function hasCrown(gen: number): boolean
		for _, part in NomlingSpec.build(genomeFor(species, gen)) do
			if part.name == "Crown" then
				return true
			end
		end
		return false
	end
	h.expectTrue(hasCrown(3), "gen 3 should carry a crown")
	h.expectTrue(not hasCrown(1), "gen 1 should not carry a crown")
end)
