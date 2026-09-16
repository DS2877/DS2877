--!strict
--[[
	Palette and material tokens -- "toy food court diorama" (docs/GDD.md 7).

	One source of truth for colour so the art direction stays coherent as the
	game grows. Nothing hardcodes a Color3 outside this module.

	HARD RULE, from docs/COMPLIANCE.md section 1: no casino visual language
	anywhere. No prize wheels, slot reels, cards, dice, chips or jackpot
	levers. Gambling imagery forces a Moderate maturity rating, which loses the
	Roblox Kids tier entirely. The Egg Market is a market stall; the Fusion Lab
	is a kitchen.
]]

local Style = {}

Style.PALETTE = {
	-- Surfaces
	plazaStone = Color3.fromRGB(246, 232, 205),
	plazaStoneAlt = Color3.fromRGB(233, 212, 178),
	plotPad = Color3.fromRGB(198, 228, 192),
	plotEdge = Color3.fromRGB(150, 196, 148),

	-- Brand
	nomOrange = Color3.fromRGB(255, 148, 61),
	nomPink = Color3.fromRGB(255, 122, 168),
	nomMint = Color3.fromRGB(120, 224, 196),
	nomBlue = Color3.fromRGB(96, 178, 255),
	nomCream = Color3.fromRGB(255, 246, 228),
	nomCocoa = Color3.fromRGB(122, 85, 62),

	-- Neutrals
	ink = Color3.fromRGB(58, 44, 40),
	shadow = Color3.fromRGB(196, 168, 148),
}

--- Rarity colours. ALWAYS paired with an icon and a text label -- colour alone
--- is not readable for colourblind players (docs/GDD.md 5.16).
Style.RARITY = {
	common = { color = Color3.fromRGB(176, 182, 190), label = "Common", icon = "circle" },
	uncommon = { color = Color3.fromRGB(116, 204, 122), label = "Uncommon", icon = "leaf" },
	rare = { color = Color3.fromRGB(86, 158, 255), label = "Rare", icon = "droplet" },
	epic = { color = Color3.fromRGB(178, 112, 240), label = "Epic", icon = "star" },
	legendary = { color = Color3.fromRGB(255, 176, 48), label = "Legendary", icon = "crown" },
	mythic = { color = Color3.fromRGB(255, 92, 120), label = "Mythic", icon = "flame" },
	secret = { color = Color3.fromRGB(250, 250, 255), label = "Secret", icon = "sparkle" },
}

--- Per-species colour sets, keyed by the `palette` field in Config/Nomlings.
--- Three roles each: the body, a lighter belly/limb tone, and the snack layer.
--- Picked so the snack colour always contrasts with the body -- the overlay is
--- what makes a fusion legible, and it cannot read if it blends in.
Style.SPECIES_PALETTE = {
	ochre_shell = {
		primary = Color3.fromRGB(196, 142, 78),
		secondary = Color3.fromRGB(240, 222, 186),
		snack = Color3.fromRGB(240, 186, 86),
	},
	rice_salmon = {
		primary = Color3.fromRGB(246, 242, 232),
		secondary = Color3.fromRGB(255, 226, 214),
		snack = Color3.fromRGB(244, 122, 108),
	},
	crust_tomato = {
		primary = Color3.fromRGB(238, 196, 116),
		secondary = Color3.fromRGB(250, 232, 196),
		snack = Color3.fromRGB(214, 74, 58),
	},
	glaze_sprinkle = {
		primary = Color3.fromRGB(252, 228, 160),
		secondary = Color3.fromRGB(255, 246, 216),
		snack = Color3.fromRGB(250, 158, 196),
	},
	bun_lettuce = {
		primary = Color3.fromRGB(214, 164, 104),
		secondary = Color3.fromRGB(242, 214, 168),
		snack = Color3.fromRGB(126, 196, 106),
	},
	broth_scallion = {
		primary = Color3.fromRGB(226, 186, 118),
		secondary = Color3.fromRGB(246, 226, 178),
		snack = Color3.fromRGB(148, 206, 118),
	},
	popcorn_butter = {
		primary = Color3.fromRGB(250, 238, 206),
		secondary = Color3.fromRGB(255, 250, 234),
		snack = Color3.fromRGB(252, 206, 92),
	},
	waffle_syrup = {
		primary = Color3.fromRGB(206, 154, 96),
		secondary = Color3.fromRGB(238, 208, 158),
		snack = Color3.fromRGB(168, 104, 48),
	},
	frosting_cherry = {
		primary = Color3.fromRGB(216, 196, 240),
		secondary = Color3.fromRGB(242, 232, 252),
		snack = Color3.fromRGB(226, 76, 102),
	},
	pickle_beak = {
		primary = Color3.fromRGB(132, 180, 92),
		secondary = Color3.fromRGB(196, 224, 158),
		snack = Color3.fromRGB(246, 154, 62),
	},
	mochi_dust = {
		primary = Color3.fromRGB(248, 242, 244),
		secondary = Color3.fromRGB(255, 250, 250),
		snack = Color3.fromRGB(198, 172, 186),
	},
	nacho_cheese = {
		primary = Color3.fromRGB(240, 196, 96),
		secondary = Color3.fromRGB(250, 228, 168),
		snack = Color3.fromRGB(246, 150, 54),
	},
}

--- Mutation tints. A mutation recolours and adds a glow -- it must be obvious
--- from across the street, because it is the single biggest reason to want a
--- particular creature off the belt.
Style.MUTATION = {
	glazed = { tint = Color3.fromRGB(255, 226, 150), glow = 0.35 },
	frosted = { tint = Color3.fromRGB(186, 232, 255), glow = 0.45 },
	spicy = { tint = Color3.fromRGB(255, 118, 86), glow = 0.55 },
	rainbow = { tint = Color3.fromRGB(255, 160, 220), glow = 0.75 },
	galaxy = { tint = Color3.fromRGB(140, 120, 255), glow = 0.95 },
}

--- Eye colours are fixed across every species. A creature reads as alive
--- because of its eyes, and inconsistent eyes read as a bug.
Style.EYE = {
	white = Color3.fromRGB(252, 252, 255),
	pupil = Color3.fromRGB(38, 30, 34),
}

Style.MATERIAL = {
	plaza = Enum.Material.SmoothPlastic,
	plot = Enum.Material.Grass,
	prop = Enum.Material.SmoothPlastic,
	accent = Enum.Material.Neon,
}

--- Abbreviates large numbers for phone-sized UI: 1.2K, 3.4M, 5.6Qa.
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Style.abbreviate(value: number): string
	if value < 1000 then
		return string.format("%d", math.floor(value))
	end
	local index = math.min(math.floor(math.log(value, 1000)), #SUFFIXES - 1)
	local scaled = value / (1000 ^ index)
	if scaled >= 100 then
		return string.format("%.0f%s", scaled, SUFFIXES[index + 1])
	elseif scaled >= 10 then
		return string.format("%.1f%s", scaled, SUFFIXES[index + 1])
	end
	return string.format("%.2f%s", scaled, SUFFIXES[index + 1])
end

return Style
