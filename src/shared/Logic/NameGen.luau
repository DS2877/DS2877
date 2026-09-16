--!strict
--[[
	Deterministic Nomling name generation.

	DEPENDENCY-FREE except for the roster it is given -- callers pass the
	species table in, so Lune can test this without any Roblox require path.

	THE WHOLE RULE IS:  name = affix .. head(A) .. tail(B)

	No syllable-splicing heuristics, no cleverness. It reproduces the brief's
	own example exactly (Sushi Pup + Waffle Walrus -> Sushiwal) and it is
	trivially enumerable, which is what makes the name-safety test exhaustive
	rather than a sample.

	DETERMINISM IS A HARD REQUIREMENT. The same parents must always produce the
	same name, on every client, forever -- otherwise the Fusion Book, World
	First credit and every screenshot a player takes stop agreeing with each
	other. Nothing here may read os.time(), tick() or an unseeded Random.
]]

local NameGen = {}

export type Species = {
	id: string,
	name: string,
	head: string,
	tail: string,
	[string]: any,
}

--- FNV-1a over a string. Used to derive a stable seed from a genome's own
--- identity, so the seed travels with the creature rather than with the
--- machine that made it.
function NameGen.hash(text: string): number
	local hash = 2166136261
	for index = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, index))
		hash = (hash * 16777619) % 4294967296
	end
	return hash
end

--- The seed for a creature. Derived only from what the creature *is*.
function NameGen.seedFor(snackId: string, animalId: string, gen: number, mutation: string?): number
	return NameGen.hash(`{snackId}|{animalId}|{gen}|{mutation or "none"}`)
end

--- Which gen-3 affix a creature gets. Deterministic from its seed.
function NameGen.affixForSeed(seed: number, affixes: { string }): string
	return affixes[(seed % #affixes) + 1]
end

--[[
	Builds a display name.

	`gen` 1 returns the species' own name. `gen` 2 is head(A) .. tail(B), with
	the purebred affix when both parents are the same species. `gen` 3 adds one
	of the gen-3 affixes.
]]
function NameGen.build(
	snack: Species,
	animal: Species,
	gen: number,
	affixes: { string },
	purebredAffix: string,
	seed: number?
): string
	if gen <= 1 then
		return snack.name
	end

	local stem = snack.head .. animal.tail

	if gen == 2 then
		if snack.id == animal.id then
			return `{purebredAffix} {stem}`
		end
		return stem
	end

	local resolvedSeed = seed or NameGen.seedFor(snack.id, animal.id, gen, nil)
	return `{NameGen.affixForSeed(resolvedSeed, affixes)} {stem}`
end

--[[
	The Fusion Book / World First key for a combination.

	Keys are what DataStore `UpdateAsync` writes against for World First
	(first writer wins), so their format is effectively permanent -- changing
	it would orphan every first ever claimed. Treat a change as a migration.
]]
function NameGen.comboKey(snackId: string, animalId: string, gen: number, affix: string?): string
	if gen <= 1 then
		return `species:{snackId}`
	elseif gen == 2 then
		return `g2:{snackId}-{animalId}`
	end
	return `g3:{snackId}-{animalId}-{string.lower(affix or "?")}`
end

--- The key for a Mutation First: the first time a combination appears with a
--- given mutation. These are the renewable half of the discovery engine.
function NameGen.mutationKey(comboKey: string, mutation: string): string
	return `m:{comboKey}:{mutation}`
end

--[[
	Enumerates every reachable name, with its combo key.

	Used by the name-safety test, which checks the FULL cross-product rather
	than a sample -- a sampled test would let a bad name ship on the day
	someone adds a species.
]]
function NameGen.enumerate(
	species: { Species },
	affixes: { string },
	purebredAffix: string
): { { name: string, key: string, gen: number } }
	local results = {}

	for _, s in species do
		table.insert(results, {
			name = NameGen.build(s, s, 1, affixes, purebredAffix),
			key = NameGen.comboKey(s.id, s.id, 1),
			gen = 1,
		})
	end

	for _, snack in species do
		for _, animal in species do
			table.insert(results, {
				name = NameGen.build(snack, animal, 2, affixes, purebredAffix),
				key = NameGen.comboKey(snack.id, animal.id, 2),
				gen = 2,
			})
			for _, affix in affixes do
				table.insert(results, {
					name = `{affix} {snack.head}{animal.tail}`,
					key = NameGen.comboKey(snack.id, animal.id, 3, affix),
					gen = 3,
				})
			end
		end
	end

	return results
end

return NameGen
