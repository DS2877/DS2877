--!strict
--[[
	Turns a genome into a list of parts. This is the creature builder.

	PURE AND DEPENDENCY-FREE, so Lune can test the thing that would otherwise
	only be testable by looking at it -- and Philip has no Studio, so "looking
	at it" costs a deploy and a screenshot. The tests here check the part
	budget, that every archetype produces a body, that eyes always exist (a
	creature with no eyes reads as broken, not stylised), and that the same
	genome yields byte-identical geometry forever.

	THE TRICK THAT MAKES FUSION READ (docs/NOMLINGS.md 5): the ANIMAL sets the
	silhouette and the SNACK contributes a recognisable topping layer. A player
	sees "walrus shape, sushi colours, nori band" and understands the fusion in
	under a second -- which is exactly what a 2-3 second reveal has time for.

	Budget: 30 parts (GDD 9). A plot holds 8 and the test case is 150 visible
	at once, so this is a hard ceiling, not a guideline.
]]

local NomlingSpec = {}

NomlingSpec.MAX_PARTS = 30

export type Vec = { x: number, y: number, z: number }

export type PartSpec = {
	name: string,
	shape: "block" | "ball" | "cylinder",
	size: Vec,
	--- Offset from the creature's origin. The origin is between the feet, so a
	--- creature can be dropped on a pedestal without knowing its height.
	offset: Vec,
	--- Degrees.
	tilt: Vec,
	--- A palette role, resolved to a colour by Style. Never a literal colour:
	--- the palette is per-species and the builder must not know about it.
	role: "primary" | "secondary" | "accent" | "snack" | "eye" | "pupil" | "dark",
	material: "plastic" | "smooth" | "neon" | "fabric",
}

export type Genome = {
	snack: string,
	animal: string,
	gen: number,
	mutation: string?,
	seed: number,
	archetype: string,
}

local function v(x: number, y: number, z: number): Vec
	return { x = x, y = y, z = z }
end

local ZERO = v(0, 0, 0)

--- Deterministic 0-1 from a seed and a channel. Lets the builder vary details
--- per creature without an RNG, so the same genome is the same creature on
--- every client, in every session, forever.
local function noise(seed: number, channel: number): number
	local h = (seed * 2654435761 + channel * 40503) % 4294967296
	h = (h * 1103515245 + 12345) % 4294967296
	return h / 4294967296
end

--- Body proportions per archetype: torso size, leg count, leg length, how high
--- the head sits and how far forward. Twelve silhouettes from one table --
--- adding a thirteenth species is a row here, not new code.
local BODIES: {
	[string]: {
		torso: Vec,
		legs: number,
		legLen: number,
		legThick: number,
		headUp: number,
		headFwd: number,
		headSize: number,
	},
} =
	{
		quadruped_wide = {
			torso = v(3.4, 2.0, 4.4),
			legs = 4,
			legLen = 1.0,
			legThick = 0.85,
			headUp = 1.5,
			headFwd = 2.6,
			headSize = 2.0,
		},
		quadruped_small = {
			torso = v(1.9, 1.6, 2.7),
			legs = 4,
			legLen = 0.9,
			legThick = 0.45,
			headUp = 1.3,
			headFwd = 1.8,
			headSize = 1.5,
		},
		quadruped_bulky = {
			torso = v(3.0, 2.4, 3.6),
			legs = 4,
			legLen = 1.1,
			legThick = 0.95,
			headUp = 1.7,
			headFwd = 2.2,
			headSize = 2.1,
		},
		quadruped_round = {
			torso = v(2.6, 2.3, 2.8),
			legs = 4,
			legLen = 0.7,
			legThick = 0.6,
			headUp = 1.6,
			headFwd = 1.8,
			headSize = 1.7,
		},
		biped_upright = {
			torso = v(2.0, 2.7, 1.7),
			legs = 2,
			legLen = 1.0,
			legThick = 0.55,
			headUp = 2.2,
			headFwd = 0.4,
			headSize = 1.6,
		},
		biped_round = {
			torso = v(2.4, 2.3, 2.2),
			legs = 2,
			legLen = 0.6,
			legThick = 0.55,
			headUp = 1.9,
			headFwd = 0.5,
			headSize = 1.6,
		},
		biped_winged = {
			torso = v(1.9, 2.3, 1.9),
			legs = 2,
			legLen = 0.9,
			legThick = 0.35,
			headUp = 1.9,
			headFwd = 0.4,
			headSize = 1.4,
		},
		squat_wide = {
			torso = v(3.2, 1.5, 2.8),
			legs = 4,
			legLen = 0.4,
			legThick = 0.6,
			headUp = 1.0,
			headFwd = 1.7,
			headSize = 1.7,
		},
		squat_small = {
			torso = v(1.9, 1.4, 2.1),
			legs = 4,
			legLen = 0.35,
			legThick = 0.4,
			headUp = 0.9,
			headFwd = 1.3,
			headSize = 1.4,
		},
		long_low = {
			torso = v(1.7, 1.3, 5.0),
			legs = 4,
			legLen = 0.4,
			legThick = 0.45,
			headUp = 0.8,
			headFwd = 2.9,
			headSize = 1.4,
		},
		pinniped_long = {
			torso = v(1.9, 1.7, 4.6),
			legs = 0,
			legLen = 0,
			legThick = 0,
			headUp = 1.4,
			headFwd = 2.6,
			headSize = 1.6,
		},
		aquatic_long = {
			torso = v(1.7, 1.7, 5.2),
			legs = 0,
			legLen = 0,
			legThick = 0,
			headUp = 1.3,
			headFwd = 3.0,
			headSize = 1.5,
		},
	}

local FALLBACK_BODY = BODIES.quadruped_small

local function body(archetype: string)
	return BODIES[archetype] or FALLBACK_BODY
end

-- --- the snack overlay -----------------------------------------------------
-- Each snack contributes 1-3 parts. Kept small deliberately: the overlay has
-- to read instantly at phone size, and a busy one reads as noise.

local function snackOverlay(snack: string, torso: Vec): { PartSpec }
	local out: { PartSpec } = {}
	local function push(name: string, shape: any, size: Vec, offset: Vec, tilt: Vec, material: any)
		table.insert(out, {
			name = name,
			shape = shape,
			size = size,
			offset = offset,
			tilt = tilt,
			role = "snack",
			material = material or "smooth",
		})
	end

	if snack == "taco" then
		-- A shell arching over the back.
		push(
			"Shell",
			"cylinder",
			v(torso.x * 1.15, torso.z * 0.9, torso.z * 0.9),
			v(0, torso.y * 0.95, 0),
			v(0, 0, 90),
			"smooth"
		)
	elseif snack == "sushi" then
		-- A nori band around the middle, the single most recognisable sushi cue.
		push(
			"Nori",
			"block",
			v(torso.x * 1.06, torso.y * 0.62, torso.z * 0.34),
			v(0, torso.y * 0.5, 0),
			ZERO,
			"fabric"
		)
	elseif snack == "pizza" then
		-- A crust rim, worn like a collar.
		push(
			"Crust",
			"cylinder",
			v(0.5, torso.x * 1.5, torso.x * 1.5),
			v(0, torso.y * 0.72, torso.z * 0.1),
			v(0, 0, 90),
			"smooth"
		)
	elseif snack == "donut" then
		push(
			"Glaze",
			"cylinder",
			v(0.45, torso.x * 1.2, torso.x * 1.2),
			v(0, torso.y * 1.02, 0),
			v(0, 0, 90),
			"smooth"
		)
		push(
			"Sprinkle",
			"block",
			v(0.22, 0.22, 0.7),
			v(torso.x * 0.3, torso.y * 1.18, 0.3),
			v(0, 25, 0),
			"neon"
		)
		push(
			"Sprinkle2",
			"block",
			v(0.22, 0.22, 0.7),
			v(-torso.x * 0.25, torso.y * 1.18, -0.2),
			v(0, -40, 0),
			"neon"
		)
	elseif snack == "burger" then
		push(
			"BunTop",
			"ball",
			v(torso.x * 1.05, torso.y * 0.7, torso.z * 0.95),
			v(0, torso.y * 1.05, 0),
			ZERO,
			"smooth"
		)
		push(
			"Lettuce",
			"block",
			v(torso.x * 1.12, 0.3, torso.z * 1.02),
			v(0, torso.y * 0.78, 0),
			ZERO,
			"fabric"
		)
	elseif snack == "noodle" then
		push(
			"Noodle",
			"cylinder",
			v(torso.x * 1.1, 0.42, 0.42),
			v(0, torso.y * 0.95, torso.z * 0.18),
			ZERO,
			"smooth"
		)
		push(
			"Noodle2",
			"cylinder",
			v(torso.x * 0.9, 0.36, 0.36),
			v(0, torso.y * 1.08, -torso.z * 0.12),
			v(0, 18, 0),
			"smooth"
		)
	elseif snack == "popcorn" then
		push(
			"Puff",
			"ball",
			v(0.95, 0.95, 0.95),
			v(torso.x * 0.32, torso.y * 1.02, torso.z * 0.2),
			ZERO,
			"smooth"
		)
		push(
			"Puff2",
			"ball",
			v(0.8, 0.8, 0.8),
			v(-torso.x * 0.3, torso.y * 1.06, -torso.z * 0.15),
			ZERO,
			"smooth"
		)
		push("Puff3", "ball", v(0.7, 0.7, 0.7), v(0, torso.y * 1.12, torso.z * 0.3), ZERO, "smooth")
	elseif snack == "waffle" then
		-- A waffle plate on the back, with the grid implied by two ridges.
		push(
			"Waffle",
			"block",
			v(torso.x * 0.95, 0.34, torso.z * 0.8),
			v(0, torso.y * 1.0, 0),
			ZERO,
			"smooth"
		)
		push(
			"Ridge",
			"block",
			v(torso.x * 0.98, 0.16, 0.18),
			v(0, torso.y * 1.14, torso.z * 0.2),
			ZERO,
			"smooth"
		)
		push(
			"Ridge2",
			"block",
			v(0.18, 0.16, torso.z * 0.82),
			v(torso.x * 0.2, torso.y * 1.14, 0),
			ZERO,
			"smooth"
		)
	elseif snack == "cupcake" then
		push(
			"Frosting",
			"ball",
			v(torso.x * 0.95, torso.y * 0.8, torso.z * 0.8),
			v(0, torso.y * 1.08, 0),
			ZERO,
			"smooth"
		)
		push("Cherry", "ball", v(0.5, 0.5, 0.5), v(0, torso.y * 1.5, 0), ZERO, "smooth")
	elseif snack == "pickle" then
		push(
			"Bump",
			"ball",
			v(0.5, 0.5, 0.5),
			v(torso.x * 0.35, torso.y * 0.9, torso.z * 0.25),
			ZERO,
			"smooth"
		)
		push(
			"Bump2",
			"ball",
			v(0.42, 0.42, 0.42),
			v(-torso.x * 0.32, torso.y * 0.95, -torso.z * 0.2),
			ZERO,
			"smooth"
		)
	elseif snack == "mochi" then
		push(
			"Dust",
			"ball",
			v(torso.x * 1.02, torso.y * 0.55, torso.z * 1.0),
			v(0, torso.y * 0.95, 0),
			ZERO,
			"fabric"
		)
	elseif snack == "nacho" then
		push(
			"Chip",
			"block",
			v(0.22, 1.5, 1.5),
			v(torso.x * 0.18, torso.y * 1.1, 0),
			v(0, 0, 18),
			"smooth"
		)
		push(
			"Chip2",
			"block",
			v(0.22, 1.2, 1.2),
			v(-torso.x * 0.22, torso.y * 1.05, -torso.z * 0.2),
			v(0, 0, -22),
			"smooth"
		)
	else
		-- An unknown snack still gets something, so a species added by a future
		-- content update is plain rather than invisible.
		push(
			"Topping",
			"ball",
			v(torso.x * 0.7, torso.y * 0.5, torso.z * 0.6),
			v(0, torso.y * 1.0, 0),
			ZERO,
			"smooth"
		)
	end

	return out
end

-- --- the build -------------------------------------------------------------

function NomlingSpec.build(genome: Genome): { PartSpec }
	local b = body(genome.archetype)
	local torso = b.torso
	local parts: { PartSpec } = {}

	local function push(spec: PartSpec)
		table.insert(parts, spec)
	end

	local groundY = b.legLen
	local torsoY = groundY + torso.y * 0.5

	-- Torso. A ball for the round archetypes, a block for the long ones: the
	-- silhouette is most of what a player reads at phone size.
	local roundBody = genome.archetype == "biped_round"
		or genome.archetype == "quadruped_round"
		or genome.archetype == "squat_small"
	push({
		name = "Torso",
		shape = if roundBody then "ball" else "block",
		size = torso,
		offset = v(0, torsoY, 0),
		tilt = ZERO,
		role = "primary",
		material = "smooth",
	})

	-- A belly panel in the secondary colour. Two-tone reads as designed; one
	-- flat colour reads as a placeholder.
	push({
		name = "Belly",
		shape = "block",
		size = v(torso.x * 0.7, torso.y * 0.45, torso.z * 0.88),
		offset = v(0, groundY + torso.y * 0.28, torso.z * 0.06),
		tilt = ZERO,
		role = "secondary",
		material = "smooth",
	})

	-- Head, snout, ears.
	local headY = torsoY + b.headUp
	local headZ = b.headFwd
	local head = b.headSize
	push({
		name = "Head",
		shape = "ball",
		size = v(head, head, head),
		offset = v(0, headY, headZ),
		tilt = ZERO,
		role = "primary",
		material = "smooth",
	})
	push({
		name = "Snout",
		shape = "block",
		size = v(head * 0.45, head * 0.35, head * 0.5),
		offset = v(0, headY - head * 0.18, headZ + head * 0.55),
		tilt = ZERO,
		role = "secondary",
		material = "smooth",
	})
	for _, side in { -1, 1 } do
		push({
			name = "Ear",
			shape = "ball",
			size = v(head * 0.34, head * 0.42, head * 0.24),
			offset = v(side * head * 0.38, headY + head * 0.45, headZ - head * 0.1),
			tilt = v(0, 0, side * 14),
			role = "primary",
			material = "smooth",
		})
	end

	-- Eyes. Always present, always two, always with pupils. A creature with no
	-- eyes reads as broken rather than stylised, so this is not optional and
	-- there is a test for it.
	local eyeOut = head * 0.28
	local eyeSize = head * 0.3
	for _, side in { -1, 1 } do
		push({
			name = "Eye",
			shape = "ball",
			size = v(eyeSize, eyeSize, eyeSize),
			offset = v(side * eyeOut, headY + head * 0.12, headZ + head * 0.4),
			tilt = ZERO,
			role = "eye",
			material = "smooth",
		})
		push({
			name = "Pupil",
			shape = "ball",
			size = v(eyeSize * 0.5, eyeSize * 0.5, eyeSize * 0.5),
			offset = v(side * eyeOut, headY + head * 0.12, headZ + head * 0.52),
			tilt = ZERO,
			role = "pupil",
			material = "smooth",
		})
	end

	-- Legs, flippers or fins, depending on the archetype.
	if b.legs > 0 then
		local spreadX = torso.x * 0.34
		local spreadZ = torso.z * 0.3
		local positions = if b.legs == 2
			then { v(-spreadX, 0, 0), v(spreadX, 0, 0) }
			else {
				v(-spreadX, 0, spreadZ),
				v(spreadX, 0, spreadZ),
				v(-spreadX, 0, -spreadZ),
				v(spreadX, 0, -spreadZ),
			}
		for _, position in positions do
			push({
				name = "Leg",
				shape = "cylinder",
				size = v(b.legLen, b.legThick, b.legThick),
				offset = v(position.x, b.legLen * 0.5, position.z),
				tilt = v(0, 0, 90),
				role = "secondary",
				material = "smooth",
			})
		end
	else
		-- Flippers for the swimmers, plus a tail fluke so the silhouette ends
		-- in something rather than stopping.
		for _, side in { -1, 1 } do
			push({
				name = "Flipper",
				shape = "block",
				size = v(torso.x * 0.9, 0.3, torso.z * 0.3),
				offset = v(side * torso.x * 0.7, groundY + torso.y * 0.3, torso.z * 0.1),
				tilt = v(0, 0, side * 18),
				role = "secondary",
				material = "smooth",
			})
		end
		push({
			name = "Fluke",
			shape = "block",
			size = v(torso.x * 1.5, 0.32, torso.z * 0.22),
			offset = v(0, groundY + torso.y * 0.45, -torso.z * 0.58),
			tilt = ZERO,
			role = "secondary",
			material = "smooth",
		})
	end

	-- Wings for the winged archetype.
	if genome.archetype == "biped_winged" then
		for _, side in { -1, 1 } do
			push({
				name = "Wing",
				shape = "block",
				size = v(0.26, torso.y * 0.9, torso.z * 1.1),
				offset = v(side * torso.x * 0.62, torsoY + torso.y * 0.12, -torso.z * 0.08),
				tilt = v(0, 0, side * 12),
				role = "accent",
				material = "smooth",
			})
		end
	end

	-- Tail, for the land animals that are not already ending in a fluke.
	if b.legs > 0 then
		push({
			name = "Tail",
			shape = "cylinder",
			size = v(torso.z * 0.5, 0.35, 0.35),
			offset = v(0, torsoY + torso.y * 0.18, -torso.z * 0.62),
			tilt = v(0, 90, 18),
			role = "primary",
			material = "smooth",
		})
	end

	-- The snack layer, which is what makes the fusion legible.
	for _, spec in snackOverlay(genome.snack, torso) do
		push(spec)
	end

	-- Gen 3 gets a floating crown shard: the affix made visible, so a Giga
	-- creature looks different from a plain one without new geometry per affix.
	if genome.gen >= 3 then
		push({
			name = "Crown",
			shape = "block",
			size = v(0.5, 0.9, 0.5),
			offset = v(0, headY + head * 1.05, headZ),
			tilt = v(0, 45, 0),
			role = "accent",
			material = "neon",
		})
	end

	-- An accessory on roughly a third of creatures, chosen by seed. Variety
	-- that costs one part and never changes the silhouette.
	if noise(genome.seed, 11) < 0.34 then
		push({
			name = "Accessory",
			shape = "cylinder",
			size = v(0.26, head * 0.85, head * 0.85),
			offset = v(0, headY + head * 0.62, headZ),
			tilt = v(90, 0, 0),
			role = "accent",
			material = "smooth",
		})
	end

	return parts
end

--- Uniform scale for a creature: a little natural variation, bigger at gen 3,
--- bigger again if mutated. Derived from the seed, so it never changes.
function NomlingSpec.scaleFor(genome: Genome): number
	local base = 0.88 + noise(genome.seed, 3) * 0.3
	if genome.gen >= 3 then
		base *= 1.4
	elseif genome.gen == 2 then
		base *= 1.12
	end
	if genome.mutation then
		base *= 1.08
	end
	return base
end

return NomlingSpec
