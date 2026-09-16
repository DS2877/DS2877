"""Economy configuration for Fuse a Nomling.

This file is the single source of truth for the simulator. Every number here
maps 1:1 onto a key that will live in `src/shared/Config/Economy.luau`, so
tuning happens here first and is copied across once the pacing targets pass.

Odds are integer parts-per-million and MUST sum to exactly 1_000_000 per egg
(brief 5.2; enforced by `validate()` below and by a CI unit test).
"""

RARITIES = ["common", "uncommon", "rare", "epic", "legendary", "mythic", "secret"]

# Base income in coins/second, per rarity (brief 4.5 E).
BASE_INCOME = {
    "common": 1,
    "uncommon": 4,
    "rare": 15,
    "epic": 60,
    "legendary": 300,
    "mythic": 2_500,
    "secret": 50_000,
}

# ---------------------------------------------------------------------------
# Eggs
# ---------------------------------------------------------------------------
# `unlock_rebirth` is the rebirth count at which the tier becomes buyable.
# `price` is in coins. `hatch` is seconds.
EGGS = {
    "basic": {
        "unlock_rebirth": 0,
        "price": 25,
        "hatch": 10,
        "odds": {
            "common": 700_000,
            "uncommon": 220_000,
            "rare": 65_000,
            "epic": 13_000,
            "legendary": 1_900,
            "mythic": 99,
            "secret": 1,
        },
    },
    "picnic": {
        "unlock_rebirth": 1,
        "price": 1_200,
        "hatch": 30,
        "odds": {
            "common": 450_000,
            "uncommon": 380_000,
            "rare": 140_000,
            "epic": 26_000,
            "legendary": 3_800,
            "mythic": 195,
            "secret": 5,
        },
    },
    "bakery": {
        "unlock_rebirth": 2,
        "price": 60_000,
        "hatch": 75,
        "odds": {
            "common": 220_000,
            "uncommon": 430_000,
            "rare": 270_000,
            "epic": 72_000,
            "legendary": 7_400,
            "mythic": 580,
            "secret": 20,
        },
    },
    "sushibar": {
        "unlock_rebirth": 4,
        "price": 3_500_000,
        "hatch": 150,
        "odds": {
            "common": 80_000,
            "uncommon": 300_000,
            "rare": 400_000,
            "epic": 190_000,
            "legendary": 27_000,
            "mythic": 2_900,
            "secret": 100,
        },
    },
    "candycloud": {
        "unlock_rebirth": 6,
        "price": 250_000_000,
        "hatch": 300,
        "odds": {
            "common": 0,
            "uncommon": 150_000,
            "rare": 400_000,
            "epic": 330_000,
            "legendary": 108_000,
            "mythic": 11_500,
            "secret": 500,
        },
    },
    "cosmic": {
        "unlock_rebirth": 8,
        "price": 40_000_000_000,
        "hatch": 600,
        "odds": {
            "common": 0,
            "uncommon": 0,
            "rare": 300_000,
            "epic": 420_000,
            "legendary": 240_000,
            "mythic": 37_000,
            "secret": 3_000,
        },
    },
}

# The very first egg of a new player's life hatches fast, so the FTUE can land
# a reveal inside 15 seconds (brief 4.6).
FIRST_EGG_HATCH_SECONDS = 5

# A new player is GIVEN this egg, already incubating. The simulator has always
# assumed it -- every pacing number in docs/ECONOMY.md was derived with it --
# but it was an unnamed line in simulate.py rather than a constant, and the game
# never implemented it. A new profile therefore had 0 coins and 0 income and
# could not afford the cheapest egg: soft-locked on the first screen.
#
# Same failure as rebirth (D-008), same fix. Set to None for no starting egg,
# and expect the FTUE to need a coin grant instead.
STARTER_EGG = "basic"

# Egg prices scale with rebirth count. Without this, eggs become free relative
# to late-game income, the shop stops being a sink, and income runs away — the
# simulator showed heavy players reaching 220 rebirths in 28 days.
EGG_PRICE_REBIRTH_SCALE = 2.9


def egg_price(egg_key: str, rebirths: int) -> int:
    return int(EGGS[egg_key]["price"] * (EGG_PRICE_REBIRTH_SCALE ** rebirths))

# ---------------------------------------------------------------------------
# Base / plot
# ---------------------------------------------------------------------------
PEDESTALS_BASE = 8
PEDESTALS_MAX = 16
INCUBATORS_BASE = 2
INCUBATORS_MAX = 4

# Coin cost of the Nth extra pedestal / incubator (index 0 = first extra).
# Reset by rebirth (brief 4.5 I).
PEDESTAL_UPGRADE_COST = lambda n: int(500 * (3.2 ** n))
INCUBATOR_UPGRADE_COST = lambda n: int(4_000 * (14 ** n))

# ---------------------------------------------------------------------------
# Fusion (brief 4.5 F)
# ---------------------------------------------------------------------------
FUSION_INCOME_FACTOR = 1.3
FUSION_GEN_BONUS = {2: 1.0, 3: 1.6}
FUSION_UPGRADE_CHANCE_SAME_TIER = 0.12
FUSION_UPGRADE_CHANCE_DIFF_TIER = 0.05
FUSION_MUTATION_INHERIT_CHANCE = 0.35
# Fusion duration by the higher parent tier, in seconds.
FUSION_SECONDS = {
    "common": 30,
    "uncommon": 60,
    "rare": 150,
    "epic": 300,
    "legendary": 600,
    "mythic": 900,
    "secret": 1_200,
}
FUSION_FIRST_TIME_SECONDS = 8  # FTUE only, brief 4.6
MAX_GEN = 3

# The Fusion Lab takes one pair at a time. This is the main throttle on income
# growth: without it, fusion becomes an auto-upgrade treadmill and coins/s runs
# away geometrically. `fusionPro` sells a second slot (brief 5.3).
FUSION_SLOTS_BASE = 1
FUSION_SLOTS_PRO = 2

# Inventory cap (brief 7.5).
INVENTORY_CAP = 300

# ---------------------------------------------------------------------------
# Weather and mutations (brief 4.5 G) — free, so this is pure upside
# ---------------------------------------------------------------------------
WEATHER = {
    "golden_glaze": {"mult": 3, "weight": 0.35},
    "frost_sugar": {"mult": 2, "weight": 0.30},
    "lava_salsa": {"mult": 4, "weight": 0.20},
    "rainbow_sprinkles": {"mult": 5, "weight": 0.12},
    "galaxy_jelly": {"mult": 10, "weight": 0.03},
}
WEATHER_DURATION = 90
WEATHER_INTERVAL_MIN = 12 * 60
WEATHER_INTERVAL_MAX = 20 * 60

# Chance per weather event that a given Nomling on an open pedestal mutates.
MUTATION_CHANCE_PER_EVENT = 0.06
MUTATIONS = {
    "glazed": 2.0,
    "frosted": 2.5,
    "spicy": 3.0,
    "rainbow": 5.0,
    "galaxy": 8.0,
}

# ---------------------------------------------------------------------------
# Rebirth (brief 4.5 I)
# ---------------------------------------------------------------------------
# Tuned by tools/simulate-economy/tune.py on 2026-09-16. Lands the casual
# player's 1st rebirth at 30 min of playtime and 10th at ~day 17, both mid-window,
# while a heavy player reaches ~33 rebirths in 28 days rather than spiralling.
# Re-run tune.py after any change to income, egg pricing or fusion.
REBIRTH_COST = lambda n: int(1_900_000 * (2.5 ** n))
REBIRTH_MULT = lambda n: 2.6 ** n

# Rebirth wipes coins and pedestals, so without this the player has no income
# and no bank and can never restart. Every rebirth hands over one free egg of
# the best tier they have unlocked, already incubating.
REBIRTH_GRANTS_FREE_EGG = True

# ---------------------------------------------------------------------------
# Offline (brief 4.5 E)
# ---------------------------------------------------------------------------
OFFLINE_EFFICIENCY = 0.25
OFFLINE_CAP_SECONDS = 2 * 3600
OFFLINE_CAP_SECONDS_VIP = 4 * 3600


def expected_income(egg_key: str) -> float:
    """Expected coins/second from one Nomling hatched from this egg."""
    odds = EGGS[egg_key]["odds"]
    return sum(BASE_INCOME[r] * (p / 1_000_000) for r, p in odds.items())


def average_weather_factor() -> float:
    """Long-run income multiplier from weather events."""
    ev_mult = sum(w["mult"] * w["weight"] for w in WEATHER.values())
    avg_interval = (WEATHER_INTERVAL_MIN + WEATHER_INTERVAL_MAX) / 2
    duty = WEATHER_DURATION / avg_interval
    return 1.0 + duty * (ev_mult - 1.0)


def validate() -> None:
    """Every odds table must sum to exactly 1,000,000 ppm. CI enforces this too."""
    for key, egg in EGGS.items():
        total = sum(egg["odds"].values())
        if total != 1_000_000:
            raise ValueError(f"egg '{key}' odds sum to {total:,} ppm, expected 1,000,000")
        for rarity in egg["odds"]:
            if rarity not in RARITIES:
                raise ValueError(f"egg '{key}' has unknown rarity '{rarity}'")


validate()
