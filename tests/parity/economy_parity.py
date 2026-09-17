"""Assert src/shared/Config/Economy.luau matches tools/simulate-economy/config.py.

Those numbers were tuned by tune.py against the pacing targets in
docs/ECONOMY.md. If the game and the simulator drift apart, every pacing claim
in that document quietly becomes fiction -- and nothing else would catch it.

Run:  python3 tests/parity/economy_parity.py
Exit code 0 = in sync.
"""

from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LUAU = os.path.join(ROOT, "src", "shared", "Config", "Economy.luau")
sys.path.insert(0, os.path.join(ROOT, "tools", "simulate-economy"))

import config as C  # noqa: E402


def strip_comments(src: str) -> str:
    src = re.sub(r"--\[\[.*?\]\]", "", src, flags=re.S)
    return re.sub(r"--[^\n]*", "", src)


def extract_block(src: str, name: str) -> str:
    """Return the balanced `{...}` literal that defines <name>.

    Matches both shapes the config file uses: `Economy.EGGS = {` and the typed
    form `local EGGS: { [string]: EggSpec } = {`. The typed one exists because
    Luau cannot annotate a table field assignment, and without an annotation the
    analyzer types every iteration of these tables as `unknown` (D-023).

    Anchored on the `=` that opens the literal, NOT on the first `{` after the
    name -- a type annotation contains braces of its own, and taking the first
    one would return the annotation instead of the table. The trailing \\b also
    stops `WEATHER` from matching `WEATHER_DURATION`.
    """
    pattern = rf"(?:Economy\.|local\s+){re.escape(name)}\b[^=\n]*=\s*\{{"
    match = re.search(pattern, src)
    if match is None:
        raise ValueError(f"no table literal found for {name}")
    brace = match.end() - 1
    depth, i = 0, brace
    while i < len(src):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return src[brace : i + 1]
        i += 1
    raise ValueError(f"unbalanced table for {name}")


def luau_table_to_py(block: str):
    """Convert a Luau table literal of scalars/nested tables into Python data."""
    s = block
    s = re.sub(r"\[(\d+)\]\s*=", r'"\1":', s)          # [2] = ...
    s = re.sub(r"([A-Za-z_]\w*)\s*=", r'"\1":', s)      # key = ...
    s = re.sub(r",(\s*[}\]])", r"\1", s)                # trailing commas
    s = s.replace("true", "true").replace("false", "false")
    return json.loads(s)


def scalars(src: str) -> dict:
    out = {}
    for m in re.finditer(r"^Economy\.([A-Z][A-Z0-9_]*)\s*=\s*([-\d.eE]+|true|false)\s*$", src, re.M):
        raw = m.group(2)
        if raw in ("true", "false"):
            out[m.group(1)] = raw == "true"
        else:
            out[m.group(1)] = float(raw) if ("." in raw or "e" in raw.lower()) else int(raw)
    return out


failures: list[str] = []


def check(label: str, lua, py) -> None:
    if isinstance(lua, float) or isinstance(py, float):
        ok = abs(float(lua) - float(py)) < 1e-9
    else:
        ok = lua == py
    if not ok:
        failures.append(f"{label}: Economy.luau={lua!r} config.py={py!r}")


def main() -> int:
    src = strip_comments(open(LUAU, encoding="utf-8").read())
    sc = scalars(src)

    # --- scalar constants ---------------------------------------------------
    for luau_name, py_value in [
        ("FIRST_EGG_HATCH_SECONDS", C.FIRST_EGG_HATCH_SECONDS),
        ("EGG_PRICE_REBIRTH_SCALE", C.EGG_PRICE_REBIRTH_SCALE),
        ("PEDESTALS_BASE", C.PEDESTALS_BASE),
        ("PEDESTALS_MAX", C.PEDESTALS_MAX),
        ("VAULT_PEDESTAL", C.VAULT_PEDESTAL),
        ("PEDESTALS_TOTAL", C.PEDESTALS_TOTAL),
        ("INCUBATORS_BASE", C.INCUBATORS_BASE),
        ("INCUBATORS_MAX", C.INCUBATORS_MAX),
        ("FUSION_SLOTS_BASE", C.FUSION_SLOTS_BASE),
        ("FUSION_SLOTS_PRO", C.FUSION_SLOTS_PRO),
        ("INVENTORY_CAP", C.INVENTORY_CAP),
        ("FUSION_INCOME_FACTOR", C.FUSION_INCOME_FACTOR),
        ("FUSION_UPGRADE_CHANCE_SAME_TIER", C.FUSION_UPGRADE_CHANCE_SAME_TIER),
        ("FUSION_UPGRADE_CHANCE_DIFF_TIER", C.FUSION_UPGRADE_CHANCE_DIFF_TIER),
        ("FUSION_MUTATION_INHERIT_CHANCE", C.FUSION_MUTATION_INHERIT_CHANCE),
        ("FUSION_FIRST_TIME_SECONDS", C.FUSION_FIRST_TIME_SECONDS),
        ("MAX_GEN", C.MAX_GEN),
        ("WEATHER_DURATION", C.WEATHER_DURATION),
        ("WEATHER_INTERVAL_MIN", C.WEATHER_INTERVAL_MIN),
        ("WEATHER_INTERVAL_MAX", C.WEATHER_INTERVAL_MAX),
        ("MUTATION_CHANCE_PER_EVENT", C.MUTATION_CHANCE_PER_EVENT),
        ("REBIRTH_GRANTS_FREE_EGG", C.REBIRTH_GRANTS_FREE_EGG),
        ("OFFLINE_EFFICIENCY", C.OFFLINE_EFFICIENCY),
        ("OFFLINE_CAP_SECONDS", C.OFFLINE_CAP_SECONDS),
        ("OFFLINE_CAP_SECONDS_VIP", C.OFFLINE_CAP_SECONDS_VIP),
        ("STIPEND_PER_SECOND", C.STIPEND_PER_SECOND),
    ]:
        if luau_name not in sc:
            failures.append(f"{luau_name}: missing from Economy.luau")
        else:
            check(luau_name, sc[luau_name], py_value)

    # --- rebirth curve ------------------------------------------------------
    # config.py stores these as lambdas, so compare the curve, not the source.
    base, growth = sc.get("REBIRTH_COST_BASE"), sc.get("REBIRTH_COST_GROWTH")
    mult = sc.get("REBIRTH_MULT_BASE")
    for n in range(0, 11):
        check(f"rebirthCost({n})", int(base * growth**n), C.REBIRTH_COST(n))
        check(f"rebirthMult({n})", mult**n, C.REBIRTH_MULT(n))

    # --- tables -------------------------------------------------------------
    check("BASE_INCOME", luau_table_to_py(extract_block(src, "BASE_INCOME")), C.BASE_INCOME)
    check("MUTATIONS", luau_table_to_py(extract_block(src, "MUTATIONS")), C.MUTATIONS)
    check("FUSION_SECONDS", luau_table_to_py(extract_block(src, "FUSION_SECONDS")), C.FUSION_SECONDS)

    weather = luau_table_to_py(extract_block(src, "WEATHER"))
    check("WEATHER keys", sorted(weather), sorted(C.WEATHER))
    for key, entry in weather.items():
        check(f"WEATHER.{key}.mult", entry["mult"], C.WEATHER[key]["mult"])
        check(f"WEATHER.{key}.weight", entry["weight"], C.WEATHER[key]["weight"])

    eggs = luau_table_to_py(extract_block(src, "EGGS"))
    check("EGGS keys", sorted(eggs), sorted(C.EGGS))
    for key, egg in eggs.items():
        py = C.EGGS[key]
        check(f"EGGS.{key}.unlockRebirth", egg["unlockRebirth"], py["unlock_rebirth"])
        check(f"EGGS.{key}.price", egg["price"], py["price"])
        check(f"EGGS.{key}.hatch", egg["hatch"], py["hatch"])
        check(f"EGGS.{key}.odds", egg["odds"], py["odds"])
        total = sum(egg["odds"].values())
        if total != 1_000_000:
            failures.append(f"EGGS.{key}.odds sums to {total:,} ppm, expected 1,000,000")

    fgb = luau_table_to_py(extract_block(src, "FUSION_GEN_BONUS"))
    check("FUSION_GEN_BONUS", {int(k): v for k, v in fgb.items()}, C.FUSION_GEN_BONUS)

    if failures:
        print(f"ECONOMY PARITY FAILED ({len(failures)} mismatch(es)):\n")
        for f in failures:
            print(f"  - {f}")
        print("\nFix config.py first, re-run tune.py, then copy into Economy.luau.")
        return 1

    print("Economy parity OK - Economy.luau matches config.py.")
    print("  odds tables checked: " + ", ".join(sorted(eggs)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
