--!strict
--[[
	The bridge between a stored Nomling and the attributes the client needs to
	render it.

	One place that knows the attribute names, so the server writing them and the
	client reading them cannot drift apart -- which would show up as creatures
	silently rendering as the fallback body rather than as an error.

	DEPENDENCY-FREE: the archetype lookup takes the species table as an argument
	rather than requiring Config.
]]

local Genome = {}

--- Attribute names, written by the server and read by the client. Changing one
--- is a breaking change on both sides at once.
Genome.ATTRIBUTES = {
	snack = "Snack",
	animal = "Animal",
	gen = "Gen",
	mutation = "Mutation",
	seed = "Seed",
	archetype = "Archetype",
	rarity = "Rarity",
	nomlingId = "NomlingId",
	owner = "OwnerUserId",
}

export type Stored = {
	id: string,
	snack: string,
	animal: string,
	gen: number,
	mutation: string?,
	rarity: string,
	seed: number,
}

--- The species id used by Config/Nomlings. Kept here because both the renderer
--- and the services need it and neither should guess the format.
function Genome.speciesId(snack: string, animal: string): string
	return `{snack}_{animal}`
end

--- The archetype for a creature, or the fallback when the species is unknown
--- (a creature saved before a roster change, for instance).
function Genome.archetypeFor(stored: Stored, byId: { [string]: { archetype: string } }): string
	local species = byId[Genome.speciesId(stored.snack, stored.animal)]
	return if species then species.archetype else "quadruped_small"
end

--- The attribute table to stamp on an anchor part.
function Genome.attributes(
	stored: Stored,
	byId: { [string]: { archetype: string } },
	ownerUserId: number?
): { [string]: any }
	return {
		[Genome.ATTRIBUTES.snack] = stored.snack,
		[Genome.ATTRIBUTES.animal] = stored.animal,
		[Genome.ATTRIBUTES.gen] = stored.gen,
		-- An attribute cannot hold nil, so "none" is the empty string and the
		-- reader treats empty as absent.
		[Genome.ATTRIBUTES.mutation] = stored.mutation or "",
		[Genome.ATTRIBUTES.seed] = stored.seed,
		[Genome.ATTRIBUTES.archetype] = Genome.archetypeFor(stored, byId),
		[Genome.ATTRIBUTES.rarity] = stored.rarity,
		[Genome.ATTRIBUTES.nomlingId] = stored.id,
		[Genome.ATTRIBUTES.owner] = ownerUserId or 0,
	}
end

return Genome
