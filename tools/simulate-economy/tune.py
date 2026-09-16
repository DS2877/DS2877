"""Grid-search rebirth constants until the casual player hits the brief's targets.

Targets (brief 7.6):
    first rebirth   25-40 min of playtime
    10th rebirth    14-21 days of casual play (15 min/day)

Run:  python3 tune.py
Then copy the winning triple into config.py.
"""

from __future__ import annotations

import statistics

import config as C
import simulate as S

TRIALS = 7
CASUAL_SESSION = S.ARCHETYPES["casual"]


def evaluate(base: float, growth: float, mult_base: float):
    C.REBIRTH_COST = lambda n: int(base * (growth ** n))
    C.REBIRTH_MULT = lambda n: mult_base ** n
    firsts, tenths, heavy = [], [], []
    for seed in range(TRIALS):
        p = S.simulate("casual", seed, days=28)
        if p.rebirth_times:
            firsts.append(p.rebirth_times[0])
        if len(p.rebirth_times) >= 10:
            tenths.append(p.rebirth_times[9] / CASUAL_SESSION)
    for seed in range(3):
        heavy.append(len(S.simulate("heavy", seed, days=28).rebirth_times))
    first = statistics.median(firsts) if firsts else None
    tenth = statistics.median(tenths) if len(tenths) >= TRIALS / 2 else None
    return first, tenth, statistics.median(heavy)


def score(first, tenth, heavy_rebirths) -> float:
    """Lower is better. Distance outside each target window."""
    if first is None:
        return 1e9
    penalty = 0.0
    lo, hi = 25 * 60, 40 * 60
    if first < lo:
        penalty += (lo - first) / 60
    elif first > hi:
        penalty += (first - hi) / 60
    if tenth is None:
        penalty += 100.0
    else:
        if tenth < 14:
            penalty += (14 - tenth) * 3
        elif tenth > 21:
            penalty += (tenth - 21) * 3
    # A 28-day heavy player should still be climbing, not spiralling.
    if heavy_rebirths > 45:
        penalty += (heavy_rebirths - 45) * 0.4
    elif heavy_rebirths < 14:
        penalty += (14 - heavy_rebirths) * 1.0
    return penalty


def main() -> None:
    results = []
    for base in (1_200_000, 1_500_000, 1_900_000, 2_400_000):
        for growth in (2.2, 2.5, 2.8, 3.1):
            for mult_base in (2.6, 3.0, 3.4):
                first, tenth, heavy = evaluate(base, growth, mult_base)
                s = score(first, tenth, heavy)
                results.append((s, base, growth, mult_base, first, tenth, heavy))
    results.sort(key=lambda r: r[0])

    print("| score | rebirth base | growth | mult base | 1st rebirth | 10th rebirth | heavy 28d |")
    print("|---|---|---|---|---|---|---|")
    for s, base, growth, mult_base, first, tenth, heavy in results[:12]:
        first_s = f"{first/60:.1f}m" if first else "never"
        tenth_s = f"day {tenth:.1f}" if tenth else "never"
        print(f"| {s:.2f} | {base:,} | {growth} | {mult_base} | {first_s} | {tenth_s} | {heavy:.0f} |")

    best = results[0]
    print(f"\nBEST: base={best[1]:,} growth={best[2]} mult_base={best[3]}")


if __name__ == "__main__":
    main()
