--!strict
--[[
	Coin income: what a base earns per second, and what it earned while the
	player was away.

	DEPENDENCY-FREE (CLAUDE.md) -- every rate comes in as an argument so Lune
	can test this without a DataModel and without Config. The caller wires
	Economy to it.

	This module is the reason the economy simulator and the game can be checked
	against each other: the formula here is the same one
	tools/simulate-economy/ uses, so if they disagree the parity test says so.
]]

local Income = {}

export type Earner = {
	rarity: string,
	mutation: string?,
}

--- Coins per second for one creature, before the base-wide multipliers.
function Income.forOne(
	earner: Earner,
	baseIncome: { [string]: number },
	mutationMultiplier: { [string]: number }
): number
	local base = baseIncome[earner.rarity]
	if not base then
		-- An unknown rarity earns nothing rather than erroring. A creature from
		-- a future content update loaded by an old server must not break the
		-- whole base's income.
		return 0
	end
	local multiplier = 1
	if earner.mutation then
		multiplier = mutationMultiplier[earner.mutation] or 1
	end
	return base * multiplier
end

--- Coins per second for the whole base.
---
--- `stipendPerSecond` is pocket money, and it pays ONLY when the placed
--- Nomlings earn nothing at all. A player robbed down to nothing otherwise has
--- zero income, and every way out of that costs coins -- a dead end rather
--- than a setback. Paying only at zero keeps it out of normal play entirely:
--- a single common already earns more than sitting still, so there is nothing
--- to farm here.
---
--- It goes through the same multipliers as real income, so it stays
--- proportionate to a rebirthed player's egg prices instead of becoming
--- irrelevant.
function Income.perSecond(
	earners: { Earner },
	baseIncome: { [string]: number },
	mutationMultiplier: { [string]: number },
	rebirthMultiplier: number,
	weatherFactor: number,
	stipendPerSecond: number?
): number
	local total = 0
	for _, earner in earners do
		total += Income.forOne(earner, baseIncome, mutationMultiplier)
	end
	if total <= 0 then
		total = stipendPerSecond or 0
	end
	return total * rebirthMultiplier * weatherFactor
end

--- What accrued while the player was offline.
---
--- Two limits, and they are both deliberate. `efficiency` (< 1) keeps playing
--- worth more than not playing. `capSeconds` stops a player who leaves for a
--- month from returning to a number that makes the rest of the game pointless
--- -- the returning-player reward has to feel good without ending the game.
function Income.offline(
	perSecond: number,
	elapsedSeconds: number,
	efficiency: number,
	capSeconds: number
): number
	if perSecond <= 0 or elapsedSeconds <= 0 then
		return 0
	end
	-- A clock that jumped backwards, or a save from the future, must not pay
	-- out and must not go negative.
	local seconds = math.min(elapsedSeconds, capSeconds)
	return math.floor(perSecond * seconds * efficiency)
end

--- Short display form: 1234 -> "1.23K". Roblox UI has very little width on a
--- phone, and a raw late-game number is fifteen digits.
local UNITS = {
	"",
	"K",
	"M",
	"B",
	"T",
	"Qa",
	"Qi",
	"Sx",
	"Sp",
	"Oc",
	"No",
	"Dc",
	"UD",
	"DD",
	"TD",
	"QaD",
	"QiD",
	"SxD",
	"SpD",
	"OcD",
	"NoD",
	"Vg",
}

function Income.format(value: number): string
	if value ~= value then
		return "0"
	end
	local sign = if value < 0 then "-" else ""
	local n = math.abs(value)
	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end
	local tier = math.floor(math.log(n, 1000))
	-- Past the last suffix, fall back to scientific notation. Clamping to the
	-- final unit instead would keep growing the string -- 10^39 rendered as
	-- "1000000Dc", nine characters, which overflows a phone HUD. The units
	-- above already cover far more than the economy can reach; this is only
	-- here so the width is bounded no matter what.
	if tier >= #UNITS then
		return sign .. string.format("%.2e", n)
	end
	local scaled = n / (1000 ^ tier)
	-- Three significant figures, so the width stays stable as the value grows.
	local text = if scaled < 10
		then string.format("%.2f", scaled)
		elseif scaled < 100 then string.format("%.1f", scaled)
		else string.format("%.0f", scaled)
	return sign .. text .. UNITS[tier + 1]
end

return Income
