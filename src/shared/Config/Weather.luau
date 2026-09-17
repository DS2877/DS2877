--!strict
--[[
	Weather: the free content engine.

	A weather event sweeps the street every 12-20 minutes, multiplies everyone's
	income while it lasts, and gives each Nomling on a pedestal a small chance
	to gain a MUTATION permanently. That last part is why weather matters
	structurally rather than just decoratively -- it is the only way a creature
	a player already owns can become something rarer, and it is the renewable
	half of the discovery engine (docs/NOMLINGS.md 3: a seasonal mutation opens
	a fresh Mutation First sweep across the whole roster at zero content cost).

	The NUMBERS live in Config/Economy, mirrored from the simulator. What lives
	here is the mapping from a weather event to the mutation it leaves behind,
	and how each one looks -- neither of which the economy model cares about,
	and keeping them out of Economy keeps the parity test honest.

	DEPENDENCY-FREE.
]]

local Weather = {}

--- Which mutation each event can leave on a creature, and how it looks while
--- it is happening. The weather and the mutation share a colour on purpose: a
--- player should be able to tell what a Golden Glaze leaves behind by looking
--- at the sky during one.
export type Kind = {
	label: string,
	mutation: string,
	tint: { number },
	--- Particle colour and how heavy the fall is.
	particle: { number },
	rate: number,
}

local KINDS: { [string]: Kind } = {
	golden_glaze = {
		label = "Golden Glaze",
		mutation = "glazed",
		tint = { 255, 216, 150 },
		particle = { 255, 226, 150 },
		rate = 26,
	},
	frost_sugar = {
		label = "Frost Sugar",
		mutation = "frosted",
		tint = { 196, 232, 255 },
		particle = { 226, 244, 255 },
		rate = 34,
	},
	lava_salsa = {
		label = "Lava Salsa",
		mutation = "spicy",
		tint = { 255, 148, 110 },
		particle = { 255, 118, 86 },
		rate = 22,
	},
	rainbow_sprinkles = {
		label = "Rainbow Sprinkles",
		mutation = "rainbow",
		tint = { 255, 186, 226 },
		particle = { 255, 160, 220 },
		rate = 40,
	},
	galaxy_jelly = {
		label = "Galaxy Jelly",
		mutation = "galaxy",
		tint = { 168, 150, 255 },
		particle = { 140, 120, 255 },
		rate = 18,
	},
}

Weather.KINDS = KINDS

--- Announced this long before it lands, so a player can run home and make sure
--- their best creatures are out on pedestals rather than sitting in the book.
--- The warning is the interesting decision; the event itself is just weather.
Weather.WARNING_SECONDS = 15

--- Picks a kind from the weighted table in Economy. `roll` is 0-1.
--- Pure, so the weighting is testable.
--- The parameter names BOTH fields, not just the `weight` this function reads.
--- Luau table types are invariant, so `{ mult, weight }` is not a
--- `{ weight }` -- and Economy.WEATHER, the only thing ever passed here, has
--- both. Shaping the parameter to its one real caller is honest; the
--- alternative is a cast at the call site, which would hide a genuine mismatch
--- the day these two disagree. Duplicated rather than imported because both
--- Config modules are deliberately dependency-free.
function Weather.pick(weights: { [string]: { weight: number, mult: number } }, roll: number): string
	local total = 0
	for _, entry in weights do
		total += entry.weight
	end
	if total <= 0 then
		return "golden_glaze"
	end

	-- Sorted, so the same roll always picks the same kind. Iterating a Luau
	-- table is order-undefined, which would otherwise make this
	-- non-deterministic between servers for no reason.
	local names: { string } = {}
	for name in weights do
		table.insert(names, name)
	end
	table.sort(names)

	local target = roll * total
	local cursor = 0
	for _, name in names do
		cursor += weights[name].weight
		if target <= cursor then
			return name
		end
	end
	return names[#names]
end

return Weather
