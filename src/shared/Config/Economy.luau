--!strict
--[[
	Economy configuration.

	MIRRORS tools/simulate-economy/config.py EXACTLY. Those numbers were tuned
	by tools/simulate-economy/tune.py against the pacing targets in
	docs/ECONOMY.md; if the two files drift apart, every pacing claim we have
	made becomes fiction.

	tests/parity/economy_parity.py asserts they match, and CI runs it.

	Change numbers in config.py first, re-run tune.py, then copy here.

	DEPENDENCY-FREE so Lune can require it directly (see Logic/Odds.luau).
]]

local Economy = {}

Economy.RARITY_ORDER = {
	"common",
	"uncommon",
	"rare",
	"epic",
	"legendary",
	"mythic",
	"secret",
}

--- Coins per second, per rarity, before any multiplier.
Economy.BASE_INCOME = {
	common = 1,
	uncommon = 4,
	rare = 15,
	epic = 60,
	legendary = 300,
	mythic = 2500,
	secret = 50000,
}

--- Egg tiers. `odds` values are integer ppm and MUST sum to 1,000,000.
Economy.EGGS = {
	basic = {
		unlockRebirth = 0,
		price = 25,
		hatch = 10,
		odds = {
			common = 700000,
			uncommon = 220000,
			rare = 65000,
			epic = 13000,
			legendary = 1900,
			mythic = 99,
			secret = 1,
		},
	},
	picnic = {
		unlockRebirth = 1,
		price = 1200,
		hatch = 30,
		odds = {
			common = 450000,
			uncommon = 380000,
			rare = 140000,
			epic = 26000,
			legendary = 3800,
			mythic = 195,
			secret = 5,
		},
	},
	bakery = {
		unlockRebirth = 2,
		price = 60000,
		hatch = 75,
		odds = {
			common = 220000,
			uncommon = 430000,
			rare = 270000,
			epic = 72000,
			legendary = 7400,
			mythic = 580,
			secret = 20,
		},
	},
	sushibar = {
		unlockRebirth = 4,
		price = 3500000,
		hatch = 150,
		odds = {
			common = 80000,
			uncommon = 300000,
			rare = 400000,
			epic = 190000,
			legendary = 27000,
			mythic = 2900,
			secret = 100,
		},
	},
	candycloud = {
		unlockRebirth = 6,
		price = 250000000,
		hatch = 300,
		odds = {
			common = 0,
			uncommon = 150000,
			rare = 400000,
			epic = 330000,
			legendary = 108000,
			mythic = 11500,
			secret = 500,
		},
	},
	cosmic = {
		unlockRebirth = 8,
		price = 40000000000,
		hatch = 600,
		odds = {
			common = 0,
			uncommon = 0,
			rare = 300000,
			epic = 420000,
			legendary = 240000,
			mythic = 37000,
			secret = 3000,
		},
	},
}

--- The first egg of a player's life hatches fast so the FTUE lands a reveal
--- inside 15 seconds (docs/GDD.md section 4).
Economy.FIRST_EGG_HATCH_SECONDS = 5

--- A new player is GIVEN this egg, already incubating.
--- The simulator has always assumed it, so every pacing number in
--- docs/ECONOMY.md depends on it. Without it a new profile has 0 coins and 0
--- income and cannot afford the cheapest egg -- soft-locked on the first
--- screen, the same failure REBIRTH_GRANTS_FREE_EGG fixes for rebirth (D-008).
Economy.STARTER_EGG = "basic"

--- Egg prices scale with rebirth count. Without this the shop stops being a
--- sink and income runs away -- the simulator showed a heavy player reaching
--- 220 rebirths in 28 days. See docs/ECONOMY.md section 5.
Economy.EGG_PRICE_REBIRTH_SCALE = 2.9

Economy.PEDESTALS_BASE = 8
Economy.PEDESTALS_MAX = 16
Economy.INCUBATORS_BASE = 2
Economy.INCUBATORS_MAX = 4

--- The Fusion Lab takes one pair at a time. This is the main throttle on
--- income growth; without it fusion becomes an auto-upgrade treadmill.
Economy.FUSION_SLOTS_BASE = 1
Economy.FUSION_SLOTS_PRO = 2

Economy.INVENTORY_CAP = 300

Economy.FUSION_INCOME_FACTOR = 1.3
Economy.FUSION_GEN_BONUS = { [2] = 1.0, [3] = 1.6 }
Economy.FUSION_UPGRADE_CHANCE_SAME_TIER = 0.12
Economy.FUSION_UPGRADE_CHANCE_DIFF_TIER = 0.05
Economy.FUSION_MUTATION_INHERIT_CHANCE = 0.35
Economy.FUSION_FIRST_TIME_SECONDS = 8
Economy.MAX_GEN = 3

Economy.FUSION_SECONDS = {
	common = 30,
	uncommon = 60,
	rare = 150,
	epic = 300,
	legendary = 600,
	mythic = 900,
	secret = 1200,
}

Economy.WEATHER = {
	golden_glaze = { mult = 3, weight = 0.35 },
	frost_sugar = { mult = 2, weight = 0.30 },
	lava_salsa = { mult = 4, weight = 0.20 },
	rainbow_sprinkles = { mult = 5, weight = 0.12 },
	galaxy_jelly = { mult = 10, weight = 0.03 },
}

Economy.WEATHER_DURATION = 90
Economy.WEATHER_INTERVAL_MIN = 720
Economy.WEATHER_INTERVAL_MAX = 1200
Economy.MUTATION_CHANCE_PER_EVENT = 0.06

Economy.MUTATIONS = {
	glazed = 2.0,
	frosted = 2.5,
	spicy = 3.0,
	rainbow = 5.0,
	galaxy = 8.0,
}

--- Tuned by tools/simulate-economy/tune.py on 2026-09-16.
Economy.REBIRTH_COST_BASE = 1900000
Economy.REBIRTH_COST_GROWTH = 2.5
Economy.REBIRTH_MULT_BASE = 2.6

--- Rebirth wipes coins AND pedestals. Without a free restart egg the player
--- has no income and no bank and can never buy another -- permanently stuck.
--- See docs/ECONOMY.md section 4.1. Covered by a regression test.
Economy.REBIRTH_GRANTS_FREE_EGG = true

Economy.OFFLINE_EFFICIENCY = 0.25
Economy.OFFLINE_CAP_SECONDS = 7200
Economy.OFFLINE_CAP_SECONDS_VIP = 14400

function Economy.rebirthCost(rebirths: number): number
	return math.floor(Economy.REBIRTH_COST_BASE * Economy.REBIRTH_COST_GROWTH ^ rebirths)
end

function Economy.rebirthMultiplier(rebirths: number): number
	return Economy.REBIRTH_MULT_BASE ^ rebirths
end

function Economy.eggPrice(eggKey: string, rebirths: number): number
	local egg = Economy.EGGS[eggKey]
	assert(egg ~= nil, `unknown egg '{eggKey}'`)
	return math.floor(egg.price * Economy.EGG_PRICE_REBIRTH_SCALE ^ rebirths)
end

--- Long-run income multiplier from weather events. Weather is free, so this is
--- pure upside and is baked into pacing.
function Economy.averageWeatherFactor(): number
	local evMult = 0
	for _, entry in Economy.WEATHER do
		evMult += entry.mult * entry.weight
	end
	local avgInterval = (Economy.WEATHER_INTERVAL_MIN + Economy.WEATHER_INTERVAL_MAX) / 2
	local duty = Economy.WEATHER_DURATION / avgInterval
	return 1 + duty * (evMult - 1)
end

return Economy
