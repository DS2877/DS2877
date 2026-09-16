--!strict
--[[
	Pure odds maths.

	DEPENDENCY-FREE ON PURPOSE. This module requires nothing -- not even shared
	Types -- so it runs unchanged both inside Roblox (where requires resolve via
	`script.Parent`) and under Lune in tests/unit (where they resolve via file
	paths). Every module under Logic/ follows the same rule. It is the reason
	the economy and odds are unit-testable at all.

	Odds are integer parts-per-million so that "sums to exactly 100%" is an
	exact integer check rather than a floating-point near-miss. Roblox requires
	every disclosed outcome set to total 100% -- see docs/COMPLIANCE.md.
]]

export type Rarity = "common" | "uncommon" | "rare" | "epic" | "legendary" | "mythic" | "secret"

--- Integer parts-per-million.
export type Ppm = number

export type OddsTable = { [string]: Ppm }

local Odds = {}

Odds.TOTAL_PPM = 1_000_000

--- Every rarity, weakest first. Order is meaningful: rolls walk it cumulatively.
local RARITY_ORDER: { Rarity } = {
	"common",
	"uncommon",
	"rare",
	"epic",
	"legendary",
	"mythic",
	"secret",
}

Odds.RARITY_ORDER = RARITY_ORDER

--- Sum of a table's ppm values.
function Odds.sum(odds: OddsTable): number
	local total = 0
	for _, ppm in odds do
		total += ppm
	end
	return total
end

--- True when the table totals exactly 1,000,000 ppm.
function Odds.isValid(odds: OddsTable): boolean
	return Odds.sum(odds) == Odds.TOTAL_PPM
end

--- Asserts validity, with a message naming the actual total.
function Odds.assertValid(odds: OddsTable, label: string)
	local total = Odds.sum(odds)
	if total ~= Odds.TOTAL_PPM then
		error(
			string.format("odds table '%s' sums to %d ppm, expected %d", label, total, Odds.TOTAL_PPM),
			2
		)
	end
end

--- Picks a rarity from `roll`, an integer in [0, 1_000_000).
--- Deterministic: the same roll always yields the same rarity.
function Odds.pick(odds: OddsTable, roll: number): Rarity
	local cumulative = 0
	for _, rarity in RARITY_ORDER do
		cumulative += odds[rarity] or 0
		if roll < cumulative then
			return rarity
		end
	end
	-- Only reachable if the table is invalid, which assertValid and CI prevent.
	return "common"
end

--- Formats ppm for display. Roblox permits rounding to four or more decimal
--- places below the first non-zero digit; we widen precision for small values
--- so 1 ppm reads as "0.0001%" rather than "0%".
function Odds.formatPercent(ppm: Ppm): string
	local percent = ppm / 10_000
	if percent >= 1 then
		return string.format("%.1f%%", percent)
	elseif percent >= 0.01 then
		return string.format("%.2f%%", percent)
	end
	return string.format("%.4f%%", percent)
end

return Odds
