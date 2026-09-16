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
