--!strict
--[[
	The v1 Nomling roster. Data only -- see docs/NOMLINGS.md for the reasoning.

	DEPENDENCY-FREE so Lune can require it in tests.

	Each species contributes a `head` (used when it is parent A, the snack side)
	and a `tail` (used when it is parent B, the animal side). A fusion name is
	simply affix .. head(A) .. tail(B), which reproduces the brief's own example:
	Sushi Pup + Waffle Walrus -> "Sushi" .. "wal" -> Sushiwal.

	Two tails are clipped for phonetics: Pizza Penguin gives `guin` rather than
	`penguin` (or we get "Tacopenguin", too long for a reveal banner) and Nacho
	Narwhal gives `narw`.
]]

local Nomlings = {}

export type Species = {
	id: string,
	name: string,
	snack: string,
	animal: string,
	head: string,
	tail: string,
	archetype: string,
	palette: string,
}

local SPECIES: { Species } = {
	-- Taco RHINO, not Taco Tiger. "Sushi" + any tail starting with "t" spells a
	-- slur ("Sushitiger"), and tiger was the only t-initial tail on the roster.
	-- Caught by the exhaustive name-safety test, not by a human reading a list.
	{ id = "taco_rhino", name = "Taco Rhino", snack = "taco", animal = "rhino",
	  head = "Taco", tail = "rhino", archetype = "quadruped_wide", palette = "ochre_shell" },
	{ id = "sushi_pup", name = "Sushi Pup", snack = "sushi", animal = "pup",
	  head = "Sushi", tail = "pup", archetype = "quadruped_small", palette = "rice_salmon" },
	{ id = "pizza_penguin", name = "Pizza Penguin", snack = "pizza", animal = "penguin",
	  head = "Pizza", tail = "guin", archetype = "biped_upright", palette = "crust_tomato" },
	{ id = "donut_duck", name = "Donut Duck", snack = "donut", animal = "duck",
	  head = "Donut", tail = "duck", archetype = "biped_round", palette = "glaze_sprinkle" },
	{ id = "burger_bear", name = "Burger Bear", snack = "burger", animal = "bear",
	  head = "Burger", tail = "bear", archetype = "quadruped_bulky", palette = "bun_lettuce" },
	{ id = "noodle_frog", name = "Noodle Frog", snack = "noodle", animal = "frog",
	  head = "Noodle", tail = "frog", archetype = "squat_wide", palette = "broth_scallion" },
	{ id = "popcorn_pig", name = "Popcorn Pig", snack = "popcorn", animal = "pig",
	  head = "Popcorn", tail = "pig", archetype = "quadruped_round", palette = "popcorn_butter" },
	{ id = "waffle_walrus", name = "Waffle Walrus", snack = "waffle", animal = "walrus",
	  head = "Waffle", tail = "wal", archetype = "pinniped_long", palette = "waffle_syrup" },
	{ id = "cupcake_croc", name = "Cupcake Croc", snack = "cupcake", animal = "croc",
	  head = "Cupcake", tail = "croc", archetype = "long_low", palette = "frosting_cherry" },
	{ id = "pickle_parrot", name = "Pickle Parrot", snack = "pickle", animal = "parrot",
	  head = "Pickle", tail = "parr", archetype = "biped_winged", palette = "pickle_beak" },
	{ id = "mochi_mole", name = "Mochi Mole", snack = "mochi", animal = "mole",
	  head = "Mochi", tail = "mole", archetype = "squat_small", palette = "mochi_dust" },
	{ id = "nacho_narwhal", name = "Nacho Narwhal", snack = "nacho", animal = "narwhal",
	  head = "Nacho", tail = "narw", archetype = "aquatic_long", palette = "nacho_cheese" },
}

Nomlings.SPECIES = SPECIES

--- Gen 3 creatures carry one of these. Without an affix their names would
--- collide with gen 2, since a gen-3 creature still has one head and one tail.
--- It doubles as the "Mega" label the brief asks for and gives five visual
--- sub-themes for the aura.
Nomlings.GEN3_AFFIXES = { "Mega", "Ultra", "Giga", "Omni", "Titan" }

--- A gen-2 fusion of a species with itself is a "purebred".
Nomlings.PUREBRED_AFFIX = "Prime"

local byId: { [string]: Species } = {}
for _, species in SPECIES do
	byId[species.id] = species
end
Nomlings.BY_ID = byId

function Nomlings.get(id: string): Species
	local species = byId[id]
	assert(species ~= nil, `unknown Nomling species '{id}'`)
	return species
end

return Nomlings
