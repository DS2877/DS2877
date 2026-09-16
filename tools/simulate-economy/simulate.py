"""Economy simulator for Fuse a Nomling.

Models a single player's progression second by second across many days and
reports when they hit the pacing milestones from brief 7.6:

    first hatch    <= 15 s
    first fusion   <= 3 min
    first rebirth  25-40 min
    10th rebirth   ~2-3 weeks of casual play

Usage:
    python3 simulate.py              # run all archetypes; output is Markdown
    python3 simulate.py --trials 50  # more trials, tighter medians

The simulator is deliberately a *behaviour* model, not a spreadsheet: it plays
the game with a simple greedy policy, so pacing numbers reflect what a player
actually does rather than what a perfectly-optimising one could do.
"""

from __future__ import annotations

import argparse
import random
import statistics
from dataclasses import dataclass, field

import config as C

# Archetypes from brief 7.6.
ARCHETYPES = {
    "casual": 15 * 60,
    "regular": 45 * 60,
    "heavy": 120 * 60,
}

SECONDS_PER_DAY = 24 * 3600
DAYS = 28  # matches the D1 / D2-7 / D8-28 windows Roblox ranks on


@dataclass
class Nomling:
    rarity: str
    income: float
    gen: int = 1
    mutation: str | None = None

    @property
    def effective(self) -> float:
        mult = C.MUTATIONS[self.mutation] if self.mutation else 1.0
        return self.income * mult


@dataclass
class Player:
    rng: random.Random
    coins: float = 0.0
    rebirths: int = 0
    pedestals: list[Nomling] = field(default_factory=list)
    pedestal_slots: int = C.PEDESTALS_BASE
    incubator_slots: int = C.INCUBATORS_BASE
    hatching: list[tuple[float, str]] = field(default_factory=list)  # (finish_t, egg)
    fusing: list[tuple[float, Nomling]] = field(default_factory=list)
    fusion_slots: int = C.FUSION_SLOTS_BASE
    inventory: list[Nomling] = field(default_factory=list)
    playtime: float = 0.0
    hatched_ever: int = 0
    fused_ever: int = 0
    # Milestones, in seconds of playtime.
    first_hatch: float | None = None
    first_fusion: float | None = None
    rebirth_times: list[float] = field(default_factory=list)
    # Economy accounting.
    coins_earned: float = 0.0
    coins_spent_eggs: float = 0.0
    coins_spent_upgrades: float = 0.0
    coins_spent_rebirth: float = 0.0

    # -- derived ----------------------------------------------------------
    def income_per_second(self) -> float:
        raw = sum(n.effective for n in self.pedestals)
        return raw * C.REBIRTH_MULT(self.rebirths) * C.average_weather_factor()

    def best_egg(self) -> str:
        best = "basic"
        for key, egg in C.EGGS.items():
            if egg["unlock_rebirth"] <= self.rebirths:
                if C.EGGS[key]["price"] > C.EGGS[best]["price"]:
                    best = key
        return best

    def affordable_egg(self) -> str | None:
        """Best egg we can afford right now, without eating the rebirth fund."""
        candidates = [
            k for k, e in C.EGGS.items()
            if e["unlock_rebirth"] <= self.rebirths
            and C.egg_price(k, self.rebirths) <= self.coins
        ]
        if not candidates:
            return None
        return max(candidates, key=lambda k: C.EGGS[k]["price"])

    # -- actions ----------------------------------------------------------
    def roll_rarity(self, egg_key: str) -> str:
        roll = self.rng.randrange(1_000_000)
        cumulative = 0
        for rarity in C.RARITIES:
            cumulative += C.EGGS[egg_key]["odds"].get(rarity, 0)
            if roll < cumulative:
                return rarity
        return "common"

    def try_buy_egg(self, t: float) -> None:
        while len(self.hatching) < self.incubator_slots:
            egg = self.affordable_egg()
            if egg is None:
                return
            price = C.egg_price(egg, self.rebirths)
            hatch = C.EGGS[egg]["hatch"]
            if self.hatched_ever == 0:
                hatch = C.FIRST_EGG_HATCH_SECONDS
            self.coins -= price
            self.coins_spent_eggs += price
            self.hatching.append((t + hatch, egg))

    def resolve_hatches(self, t: float) -> None:
        done = [h for h in self.hatching if h[0] <= t]
        for finish_t, egg in done:
            self.hatching.remove((finish_t, egg))
            rarity = self.roll_rarity(egg)
            nom = Nomling(rarity=rarity, income=C.BASE_INCOME[rarity])
            self.hatched_ever += 1
            if self.first_hatch is None:
                self.first_hatch = t
            self.place_or_fuse(t, nom)

    def place_or_fuse(self, t: float, nom: Nomling) -> None:
        if len(self.pedestals) < self.pedestal_slots:
            self.pedestals.append(nom)
            return
        # Base is full. Keep it if it beats the weakest earner, else it waits in
        # inventory as fusion fodder.
        self.pedestals.sort(key=lambda n: n.effective)
        if nom.effective > self.pedestals[0].effective:
            displaced = self.pedestals[0]
            self.pedestals[0] = nom
            nom = displaced
        if len(self.inventory) < C.INVENTORY_CAP:
            self.inventory.append(nom)

    def try_fuse(self, t: float) -> None:
        """Feed the Fusion Lab whenever a slot is free and there is fodder."""
        while len(self.fusing) < self.fusion_slots:
            if len(self.inventory) >= 2:
                self.inventory.sort(key=lambda n: n.effective)
                a = self.inventory.pop()
                b = self.inventory.pop()
            elif len(self.inventory) == 1 and len(self.pedestals) == self.pedestal_slots:
                # One spare: pair it with the weakest earner on the base.
                self.pedestals.sort(key=lambda n: n.effective)
                a = self.inventory.pop()
                b = self.pedestals.pop(0)
            else:
                return
            self.start_fusion(t, a, b)

    def start_fusion(self, t: float, a: Nomling, b: Nomling) -> None:
        higher = a if C.RARITIES.index(a.rarity) >= C.RARITIES.index(b.rarity) else b
        gen = min(max(a.gen, b.gen) + 1, C.MAX_GEN)
        rarity = higher.rarity
        same = a.rarity == b.rarity
        chance = (
            C.FUSION_UPGRADE_CHANCE_SAME_TIER if same
            else C.FUSION_UPGRADE_CHANCE_DIFF_TIER
        )
        if self.rng.random() < chance:
            idx = min(C.RARITIES.index(rarity) + 1, len(C.RARITIES) - 1)
            rarity = C.RARITIES[idx]
        income = (a.income + b.income) * C.FUSION_INCOME_FACTOR * C.FUSION_GEN_BONUS.get(gen, 1.0)
        mutation = None
        parent_mut = a.mutation or b.mutation
        if parent_mut and self.rng.random() < C.FUSION_MUTATION_INHERIT_CHANCE:
            mutation = parent_mut
        child = Nomling(rarity=rarity, income=income, gen=gen, mutation=mutation)
        duration = C.FUSION_SECONDS[higher.rarity]
        if self.fused_ever == 0:
            duration = C.FUSION_FIRST_TIME_SECONDS
        self.fusing.append((t + duration, child))
        self.fused_ever += 1
        if self.first_fusion is None:
            self.first_fusion = t

    def resolve_fusions(self, t: float) -> None:
        done = [f for f in self.fusing if f[0] <= t]
        for finish_t, child in done:
            self.fusing.remove((finish_t, child))
            if len(self.pedestals) < self.pedestal_slots:
                self.pedestals.append(child)
            else:
                self.pedestals.sort(key=lambda n: n.effective)
                if child.effective > self.pedestals[0].effective:
                    displaced = self.pedestals[0]
                    self.pedestals[0] = child
                    if len(self.inventory) < C.INVENTORY_CAP:
                        self.inventory.append(displaced)
                elif len(self.inventory) < C.INVENTORY_CAP:
                    self.inventory.append(child)

    def try_upgrades(self) -> None:
        # Buy capacity while it is cheap relative to the bank, so upgrades never
        # starve egg buying. Reset by rebirth.
        extra_ped = self.pedestal_slots - C.PEDESTALS_BASE
        if extra_ped < C.PEDESTALS_MAX - C.PEDESTALS_BASE:
            cost = C.PEDESTAL_UPGRADE_COST(extra_ped)
            if self.coins >= cost * 3:
                self.coins -= cost
                self.coins_spent_upgrades += cost
                self.pedestal_slots += 1
        extra_inc = self.incubator_slots - C.INCUBATORS_BASE
        if extra_inc < C.INCUBATORS_MAX - C.INCUBATORS_BASE:
            cost = C.INCUBATOR_UPGRADE_COST(extra_inc)
            if self.coins >= cost * 3:
                self.coins -= cost
                self.coins_spent_upgrades += cost
                self.incubator_slots += 1

    def try_rebirth(self, t: float) -> None:
        cost = C.REBIRTH_COST(self.rebirths)
        if self.coins < cost:
            return
        self.coins_spent_rebirth += cost
        self.rebirths += 1
        self.rebirth_times.append(t)
        # Resets: coins, base Nomlings, coin upgrades (brief 4.5 I).
        self.coins = 0.0
        self.pedestals = []
        self.pedestal_slots = C.PEDESTALS_BASE
        self.incubator_slots = C.INCUBATORS_BASE
        self.hatching = []
        self.fusing = []
        self.inventory = []
        self.fusion_slots = C.FUSION_SLOTS_BASE
        if C.REBIRTH_GRANTS_FREE_EGG:
            egg = self.best_egg()
            self.hatching.append((t + C.EGGS[egg]["hatch"], egg))

    def apply_mutations(self) -> None:
        for nom in self.pedestals:
            if nom.mutation is None and self.rng.random() < C.MUTATION_CHANCE_PER_EVENT:
                nom.mutation = self.rng.choice(list(C.MUTATIONS))


def simulate(archetype: str, seed: int, days: int = DAYS) -> Player:
    rng = random.Random(seed)
    p = Player(rng=rng)
    session = ARCHETYPES[archetype]
    avg_weather_interval = (C.WEATHER_INTERVAL_MIN + C.WEATHER_INTERVAL_MAX) / 2
    next_weather = avg_weather_interval

    # Seed the FTUE: the free starting egg is already incubating at t=0.
    p.hatching.append((C.FIRST_EGG_HATCH_SECONDS, "basic"))

    for day in range(days):
        if day > 0:
            # Offline accrual since the last session, capped (brief 4.5 E).
            offline = min(SECONDS_PER_DAY - session, C.OFFLINE_CAP_SECONDS)
            gain = p.income_per_second() * offline * C.OFFLINE_EFFICIENCY
            p.coins += gain
            p.coins_earned += gain
        for _ in range(int(session)):
            p.playtime += 1
            gain = p.income_per_second()
            p.coins += gain
            p.coins_earned += gain
            p.resolve_hatches(p.playtime)
            p.resolve_fusions(p.playtime)
            p.try_fuse(p.playtime)
            p.try_rebirth(p.playtime)
            p.try_upgrades()
            p.try_buy_egg(p.playtime)
            if p.playtime >= next_weather:
                p.apply_mutations()
                next_weather += avg_weather_interval
    return p


def fmt_time(seconds: float | None) -> str:
    if seconds is None:
        return "never"
    if seconds < 60:
        return f"{seconds:.0f}s"
    if seconds < 3600:
        return f"{seconds / 60:.1f}m"
    return f"{seconds / 3600:.1f}h"


def fmt_days(playtime: float | None, archetype: str) -> str:
    if playtime is None:
        return "never"
    return f"day {playtime / ARCHETYPES[archetype]:.1f}"


def run(trials: int = 25) -> None:
    print("## Pacing by archetype\n")
    header = "| Archetype | Session | First hatch | First fusion | 1st rebirth | 5th rebirth | 10th rebirth | Rebirths in 28d |"
    print(header)
    print("|---|---|---|---|---|---|---|---|")
    results = {}
    for name, session in ARCHETYPES.items():
        runs = [simulate(name, seed) for seed in range(trials)]
        results[name] = runs

        def med(fn):
            vals = [fn(r) for r in runs if fn(r) is not None]
            return statistics.median(vals) if vals else None

        def nth(n):
            vals = [r.rebirth_times[n - 1] for r in runs if len(r.rebirth_times) >= n]
            return statistics.median(vals) if len(vals) >= trials / 2 else None

        total = statistics.median([len(r.rebirth_times) for r in runs])
        print(
            f"| {name} | {session // 60} min/day "
            f"| {fmt_time(med(lambda r: r.first_hatch))} "
            f"| {fmt_time(med(lambda r: r.first_fusion))} "
            f"| {fmt_time(nth(1))} "
            f"| {fmt_time(nth(5))} ({fmt_days(nth(5), name)}) "
            f"| {fmt_time(nth(10))} ({fmt_days(nth(10), name)}) "
            f"| {total:.0f} |"
        )

    print("\n## Target check\n")
    casual = results["casual"]
    checks = [
        ("first hatch <= 15s",
         statistics.median([r.first_hatch for r in casual]) <= 15),
        ("first fusion <= 3min",
         statistics.median([r.first_fusion for r in casual]) <= 180),
        ("first rebirth 25-40min",
         25 * 60 <= statistics.median([r.rebirth_times[0] for r in casual if r.rebirth_times]) <= 40 * 60),
        ("10th rebirth within 14-21 casual days",
         14 <= statistics.median(
             [r.rebirth_times[9] / ARCHETYPES["casual"] for r in casual if len(r.rebirth_times) >= 10]
             or [999]) <= 21),
    ]
    for label, ok in checks:
        print(f"- {'PASS' if ok else 'FAIL'} — {label}")

    print("\n## Economy reference\n")
    print("| Egg | Unlock | Price | Hatch | Expected coins/s | Payback |")
    print("|---|---|---|---|---|---|")
    for key, egg in C.EGGS.items():
        ev = C.expected_income(key)
        payback = egg["price"] / ev if ev else float("inf")
        print(
            f"| {key} | rebirth {egg['unlock_rebirth']} | {egg['price']:,} "
            f"| {egg['hatch']}s | {ev:,.1f} | {fmt_time(payback)} |"
        )
    print(f"\nAverage weather uplift: x{C.average_weather_factor():.3f}")

    print("\n## Coin sources and sinks (casual, 28 days)\n")
    runs = results["casual"]
    earned = statistics.median([r.coins_earned for r in runs])
    eggs = statistics.median([r.coins_spent_eggs for r in runs])
    ups = statistics.median([r.coins_spent_upgrades for r in runs])
    reb = statistics.median([r.coins_spent_rebirth for r in runs])
    sunk = eggs + ups + reb
    print("| Flow | Coins | Share of earnings |")
    print("|---|---|---|")
    print(f"| Source: income (incl. offline) | {earned:,.0f} | 100% |")
    print(f"| Sink: eggs | {eggs:,.0f} | {eggs / earned * 100:.1f}% |")
    print(f"| Sink: base upgrades | {ups:,.0f} | {ups / earned * 100:.1f}% |")
    print(f"| Sink: rebirths | {reb:,.0f} | {reb / earned * 100:.1f}% |")
    print(f"| **Total sunk** | **{sunk:,.0f}** | **{sunk / earned * 100:.1f}%** |")
    print(f"\nUnspent float: {(1 - sunk / earned) * 100:.1f}% of everything earned.")
    print("A healthy idle economy sinks most of what it prints; a large float means")
    print("players are sitting on coins with nothing to want.")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--trials", type=int, default=25)
    args = ap.parse_args()
    run(trials=args.trials)
