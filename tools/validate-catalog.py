"""Validate monetization/catalog.json against the rules in docs/MONETIZATION.md.

These are the CI enforcement points from the currency firewall (section 2):
  - every item carries a riskTier
  - every Tier 1 item that changes odds carries odds metadata
  - no Tier 1 or Tier 2 item is missing from the PRI-restricted hide list
  - server-wide boosts are deterministic: they may not be Tier 1 or 2
  - prices are sane and present

Run:  python3 tools/validate-catalog.py
"""

from __future__ import annotations

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "monetization", "catalog.json")

VALID_TIERS = {1, 2, 3}
# Tiers hidden from players where PolicyService reports
# ArePaidRandomItemsRestricted = true. See docs/COMPLIANCE.md section 2.
RESTRICTED_TIERS = {1, 2}

errors: list[str] = []
warnings: list[str] = []


def check_item(kind: str, key: str, item: dict) -> None:
    where = f"{kind}.{key}"

    if "riskTier" not in item:
        errors.append(f"{where}: missing riskTier (every item must declare one)")
        return

    tier = item["riskTier"]
    if tier not in VALID_TIERS:
        errors.append(f"{where}: riskTier {tier!r} is not one of {sorted(VALID_TIERS)}")

    if "name" not in item or not item["name"].strip():
        errors.append(f"{where}: missing name")
    if "description" not in item or not item["description"].strip():
        errors.append(f"{where}: missing description")

    price = item.get("priceRobux")
    if price is None:
        errors.append(f"{where}: missing priceRobux")
    elif not isinstance(price, int) or price < 0:
        errors.append(f"{where}: priceRobux {price!r} must be a non-negative integer")
    elif price == 0 and item.get("enabled", True):
        errors.append(f"{where}: priceRobux is 0 but the item is enabled")

    # Tier 1 covers "sells coins OR changes odds". Anything that changes odds
    # must say so in metadata, because the odds panel has to disclose it and
    # update live while it is active.
    has_odds_effect = "oddsEffect" in item
    if has_odds_effect:
        if tier != 1:
            errors.append(f"{where}: has oddsEffect but riskTier is {tier}, must be 1")
        effect = item["oddsEffect"]
        for field in ("kind", "value", "disclosure"):
            if field not in effect:
                errors.append(f"{where}.oddsEffect: missing '{field}'")
        if isinstance(effect.get("value"), (int, float)) and effect["value"] <= 1:
            warnings.append(
                f"{where}.oddsEffect: value {effect['value']} does not improve odds"
            )

    # A luck-shaped name with no metadata is the failure mode this catches:
    # an item that changes odds but never discloses them.
    looks_lucky = any(w in key.lower() for w in ("luck", "lucky", "fortune", "rate"))
    if looks_lucky and not has_odds_effect:
        errors.append(
            f"{where}: name suggests it changes odds but it carries no oddsEffect metadata"
        )

    # Server-wide boosts apply to everyone in the server, including players who
    # may not access paid random items. They must therefore be deterministic:
    # never touching coins or odds. docs/MONETIZATION.md section 2.
    if item.get("serverWide") and tier in RESTRICTED_TIERS:
        errors.append(
            f"{where}: serverWide items must be deterministic (Tier 3), not Tier {tier} -- "
            "they affect players who may be restricted from paid random items"
        )


def main() -> int:
    with open(CATALOG, encoding="utf-8") as fh:
        catalog = json.load(fh)

    passes = catalog.get("gamePasses", {})
    products = catalog.get("developerProducts", {})

    if not passes and not products:
        errors.append("catalog is empty")

    for key, item in passes.items():
        check_item("gamePasses", key, item)
    for key, item in products.items():
        check_item("developerProducts", key, item)

    overlap = set(passes) & set(products)
    if overlap:
        errors.append(f"keys used as both a pass and a product: {sorted(overlap)}")

    restricted = sorted(
        f"{kind}.{key}"
        for kind, group in (("gamePasses", passes), ("developerProducts", products))
        for key, item in group.items()
        if item.get("riskTier") in RESTRICTED_TIERS
    )

    for warning in warnings:
        print(f"WARNING: {warning}")

    if errors:
        print(f"\nCATALOG VALIDATION FAILED ({len(errors)} error(s)):\n")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(f"Catalog OK - {len(passes)} passes, {len(products)} products.")
    print(f"  Hidden from PRI-restricted players ({len(restricted)}): {', '.join(restricted)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
