"""Revenue scenario model for Fuse a Nomling.

Produces docs/reports/revenue-scenarios.csv plus a printed summary for
1k / 10k / 100k daily active users.

EVERY number in ASSUMPTIONS is a guess until we have live data. They are
labelled with a confidence so the model is never mistaken for a forecast.
Re-run after the first month of live analytics and replace the guesses.

Run:  python3 model.py
"""

from __future__ import annotations

import csv
import os

# ---------------------------------------------------------------------------
# Platform constants — these are VERIFIED (see docs/VERIFY.md 3.3)
# ---------------------------------------------------------------------------
CREATOR_SHARE = 0.70              # creator keeps 70% of Robux spent in-game
DEVEX_RATE = 0.0038               # USD per earned Robux, standard rate
DEVEX_RATE_18PLUS_US = 0.0054     # higher rate, US age-verified 18+, R15 games
DAILY_ENGAGEMENT_ROBUX = 5        # per Active Spender per day, first 3 games
AUDIENCE_EXPANSION_SHARE = 0.35   # of first $100, needs 100+ DAU for 60 days
AUDIENCE_EXPANSION_CAP_USD = 100.0
PLUS_SIGNUP_ROBUX_TOTAL = 750     # 250/month for 3 months, per subscriber
PLUS_PRIVATE_SERVER_ROBUX = 100   # per subscriber per month, 60+ min, top-5
PRIVATE_SERVER_PRICE = 99         # Robux/month

# ---------------------------------------------------------------------------
# Assumptions — GUESSES. Confidence: low / medium.
# ---------------------------------------------------------------------------
ASSUMPTIONS = {
    # Monetization funnel
    "payer_conversion": (0.030, "low", "share of DAU who spend in a given month"),
    "arppu_robux_month": (600, "low", "Robux spent per paying user per month"),
    # Creator Rewards
    "active_spender_share": (0.12, "low", "share of DAU meeting the $9.99/60d bar"),
    "first_three_share": (0.15, "low", "share of those for whom we are a top-3 game that day"),
    # Audience Expansion — only pays above 100 DAU sustained for 60 days
    "new_user_share": (0.0008, "low", "share of DAU who are new/reactivated AND attributed to us"),
    "new_user_spend_usd": (6.0, "low", "average qualifying spend by such a user in 60 days"),
    # Roblox Plus
    "plus_signup_rate": (0.0015, "low", "share of DAU who subscribe to Plus via our prompt, monthly"),
    "plus_private_server_owners": (0.0008, "low", "share of DAU who are Plus subs with 60+ min in our paid PS"),
    # Private servers (paid, non-Plus)
    "private_server_rate": (0.002, "low", "share of DAU paying for a private server monthly"),
    # Rewarded video — requires 2,000+ unique monthly visitors
    "ad_eligible_share": (0.45, "medium", "share of DAU eligible to see rewarded video"),
    "ads_per_eligible_day": (1.2, "low", "capped voluntary views per eligible user per day"),
    "epm_robux": (9.0, "low", "Robux earned per 1,000 impressions"),
    # Mix of spend across our catalog — must sum to 1.0
    "mix_passes": (0.42, "low", "game passes: VIP, 2x Coins, Bigger Base, ..."),
    "mix_skips": (0.22, "low", "hatch/fusion skip products"),
    "mix_coinpacks": (0.16, "low", "coin packs (Tier 1)"),
    "mix_server_boosts": (0.10, "low", "server-wide boosts"),
    "mix_exclusives": (0.10, "low", "named Bonded Nomlings, Starter Pack"),
}

DAU_SCENARIOS = [1_000, 10_000, 100_000]


def a(key: str) -> float:
    return ASSUMPTIONS[key][0]


def check_mix() -> None:
    total = sum(v for k, (v, _, _) in ASSUMPTIONS.items() if k.startswith("mix_"))
    if abs(total - 1.0) > 1e-9:
        raise ValueError(f"product mix sums to {total}, expected 1.0")


def model(dau: int) -> dict:
    """Monthly figures for a given DAU. Robux unless stated."""
    # --- direct in-game spend -------------------------------------------
    payers = dau * a("payer_conversion")
    gross_spend = payers * a("arppu_robux_month")
    direct_earned = gross_spend * CREATOR_SHARE

    # --- Creator Rewards: daily engagement ------------------------------
    qualifying_daily = dau * a("active_spender_share") * a("first_three_share")
    daily_engagement = qualifying_daily * DAILY_ENGAGEMENT_ROBUX * 30

    # --- Creator Rewards: audience expansion ----------------------------
    # Gated on a 100+ DAU average sustained for 60 days (docs/VERIFY.md 3.3).
    if dau >= 100:
        new_users = dau * a("new_user_share") * 30
        spend = min(a("new_user_spend_usd"), AUDIENCE_EXPANSION_CAP_USD)
        audience_expansion_usd = new_users * spend * AUDIENCE_EXPANSION_SHARE
    else:
        audience_expansion_usd = 0.0

    # --- Roblox Plus ----------------------------------------------------
    plus_signups = dau * a("plus_signup_rate")
    # 750 Robux total spread over 3 months = 250/month in steady state.
    plus_signup_income = plus_signups * (PLUS_SIGNUP_ROBUX_TOTAL / 3)
    plus_ps = dau * a("plus_private_server_owners") * PLUS_PRIVATE_SERVER_ROBUX

    # --- Paid private servers (non-Plus) --------------------------------
    private_servers = dau * a("private_server_rate") * PRIVATE_SERVER_PRICE * CREATOR_SHARE

    # --- Rewarded video -------------------------------------------------
    # Requires 2,000+ unique monthly visitors; approximate with DAU >= 100.
    if dau >= 100:
        impressions = dau * a("ad_eligible_share") * a("ads_per_eligible_day") * 30
        ads = impressions / 1000 * a("epm_robux")
    else:
        ads = 0.0

    robux_total = (
        direct_earned + daily_engagement + plus_signup_income
        + plus_ps + private_servers + ads
    )
    usd = robux_total * DEVEX_RATE + audience_expansion_usd

    return {
        "dau": dau,
        "payers": payers,
        "gross_spend_robux": gross_spend,
        "direct_earned_robux": direct_earned,
        "daily_engagement_robux": daily_engagement,
        "plus_signup_robux": plus_signup_income,
        "plus_private_server_robux": plus_ps,
        "private_servers_robux": private_servers,
        "rewarded_video_robux": ads,
        "total_earned_robux": robux_total,
        "audience_expansion_usd": audience_expansion_usd,
        "total_usd_month": usd,
        "usd_per_dau_month": usd / dau,
    }


def main() -> None:
    check_mix()
    rows = [model(d) for d in DAU_SCENARIOS]

    out_dir = os.path.join(os.path.dirname(__file__), "..", "..", "docs", "reports")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "revenue-scenarios.csv")
    with open(path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0]))
        writer.writeheader()
        for row in rows:
            writer.writerow({k: (round(v, 2) if isinstance(v, float) else v) for k, v in row.items()})

    print("## Monthly revenue scenarios\n")
    print("| Line | 1k DAU | 10k DAU | 100k DAU |")
    print("|---|---|---|---|")
    labels = [
        ("Paying users", "payers", "{:,.0f}"),
        ("Player spend (R$)", "gross_spend_robux", "{:,.0f}"),
        ("— our share (R$)", "direct_earned_robux", "{:,.0f}"),
        ("Daily Engagement (R$)", "daily_engagement_robux", "{:,.0f}"),
        ("Plus sign-ups (R$)", "plus_signup_robux", "{:,.0f}"),
        ("Plus private servers (R$)", "plus_private_server_robux", "{:,.0f}"),
        ("Paid private servers (R$)", "private_servers_robux", "{:,.0f}"),
        ("Rewarded video (R$)", "rewarded_video_robux", "{:,.0f}"),
        ("**Total earned Robux**", "total_earned_robux", "{:,.0f}"),
        ("Audience Expansion (USD)", "audience_expansion_usd", "${:,.0f}"),
        ("**Total USD / month**", "total_usd_month", "**${:,.0f}**"),
        ("USD per DAU / month", "usd_per_dau_month", "${:,.3f}"),
    ]
    for label, key, fmt in labels:
        cells = " | ".join(fmt.format(r[key]) for r in rows)
        print(f"| {label} | {cells} |")

    print(f"\nCSV written to docs/reports/revenue-scenarios.csv")
    print(f"DevEx minimum cash-out is 30,000 earned Robux (${30_000 * DEVEX_RATE:,.0f}).")
    for r in rows:
        months = 30_000 / r["total_earned_robux"] if r["total_earned_robux"] else float("inf")
        print(f"  {r['dau']:,} DAU reaches it in {months:.2f} months.")

    print("\n## Assumptions\n")
    print("| Key | Value | Confidence | Meaning |")
    print("|---|---|---|---|")
    for key, (val, conf, desc) in ASSUMPTIONS.items():
        print(f"| `{key}` | {val} | {conf} | {desc} |")


if __name__ == "__main__":
    main()
