--!strict
--[[
	Fusing two Nomlings into one that has never existed.

	This is the product. Everything else in the game -- the belt, the base, the
	stealing -- exists to get a player to this moment with two creatures they
	care about. docs/TITLES.md is blunt about why: the market leader already has
	stealing, hatching, income pets, base upgrades and a fuse machine. What it
	does not have is a creature nobody has ever seen, with a name nobody has
	heard. That is this file.

	PURE AND DEPENDENCY-FREE. Odds, name generation and the roster all come in
	as arguments, so Lune can test the inheritance rules exhaustively -- and it
	does, because these rules decide what a player owns forever and a bug here
	is not something a playtest would notice.

	ORDERED PAIRS MATTER. Sushi Pup + Waffle Walrus is Sushiwal; Waffle Walrus +
	Sushi Pup is Wafflepup. Different creature, different Book entry. This
	doubles the discovery space for free and makes "which order?" a thing
	players talk about (docs/NOMLINGS.md 2).
]]

local FusionRules = {}

export type Parent = {
	id: string,
	snack: string,
	animal: string,
	gen: number,
	mutation: string?,
	rarity: string,
	seed: number,
}

export type Config = {
	MAX_GEN: number,
	FUSION_UPGRADE_CHANCE_SAME_TIER: number,
	FUSION_UPGRADE_CHANCE_DIFF_TIER: number,
	FUSION_MUTATION_INHERIT_CHANCE: number,
	RARITY_ORDER: { string },
}

export type Rolls = {
	--- 0-1. Decides whether the tier steps up.
	upgrade: number,
	--- 0-1. Decides whether a parent's mutation carries over.
	mutation: number,
	--- 0-1. Picks which parent's mutation, when both have one.
	mutationPick: number,
}

export type Child = {
	snack: string,
	animal: string,
	gen: number,
	mutation: string?,
	rarity: string,
	--- True when the tier stepped up. The reveal makes a meal of this.
	upgraded: boolean,
}

local function rarityIndex(order: { string }, rarity: string): number
	for i, name in order do
		if name == rarity then
			return i
		end
	end
	-- An unknown rarity is treated as the weakest rather than erroring: a
	-- creature from a future content update must still be fusable.
	return 1
end

--- Can these two actually be fused?
--- Returns ok, reason. Every reason is a sentence a child can read.
function FusionRules.check(a: Parent?, b: Parent?, config: Config): (boolean, string?)
	if not a or not b then
		return false, "Pick two Nomlings to fuse."
	end
	if a.id == b.id then
		return false, "Pick two different Nomlings."
	end
	if a.gen >= config.MAX_GEN and b.gen >= config.MAX_GEN then
		return false, `Gen {config.MAX_GEN} is as far as fusing goes.`
	end
	return true, nil
end

--- The child of A and B. Deterministic given the rolls, so the server decides
--- the rolls and this decides everything else -- which means the whole rule
--- set is testable without a DataModel or an RNG.
function FusionRules.combine(a: Parent, b: Parent, config: Config, rolls: Rolls): Child
	-- Snack from A, animal from B. This is what makes the pair ordered.
	local snack = a.snack
	local animal = b.animal
	local gen = math.min(math.max(a.gen, b.gen) + 1, config.MAX_GEN)

	local order = config.RARITY_ORDER
	local indexA = rarityIndex(order, a.rarity)
	local indexB = rarityIndex(order, b.rarity)
	local best = math.max(indexA, indexB)

	-- Matching parents are likelier to step the tier up. That is the whole
	-- strategy layer: a player with two rares has a real reason to pair them
	-- rather than fusing whatever is nearest.
	local chance = if indexA == indexB
		then config.FUSION_UPGRADE_CHANCE_SAME_TIER
		else config.FUSION_UPGRADE_CHANCE_DIFF_TIER

	local upgraded = false
	if rolls.upgrade < chance and best < #order then
		best += 1
		upgraded = true
	end

	-- Mutations are inherited, never invented here. A fusion cannot create a
	-- mutation from nothing -- that is weather's job (GDD 5.7), and keeping the
	-- two sources separate is what stops fusion becoming the only thing worth
	-- doing.
	local mutation: string? = nil
	local candidates: { string } = {}
	if a.mutation then
		table.insert(candidates, a.mutation)
	end
	if b.mutation then
		table.insert(candidates, b.mutation)
	end
	if #candidates > 0 and rolls.mutation < config.FUSION_MUTATION_INHERIT_CHANCE then
		local pick = 1 + math.floor(rolls.mutationPick * #candidates)
		mutation = candidates[math.min(pick, #candidates)]
	end

	return {
		snack = snack,
		animal = animal,
		gen = gen,
		mutation = mutation,
		rarity = order[best],
		upgraded = upgraded,
	}
end

--- What the child earns, before base-wide multipliers.
--- `(A + B) x FUSION_INCOME_FACTOR x genBonus` (docs/NOMLINGS.md 2).
function FusionRules.income(
	incomeA: number,
	incomeB: number,
	gen: number,
	factor: number,
	genBonus: { [number]: number }
): number
	return (incomeA + incomeB) * factor * (genBonus[gen] or 1)
end

--- True when the two parents are the same species, which is what earns the
--- purebred affix rather than a blended name.
function FusionRules.isPurebred(a: Parent, b: Parent): boolean
	return a.snack == b.snack and a.animal == b.animal
end

return FusionRules
