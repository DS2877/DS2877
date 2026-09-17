"""Checks the game's player-facing content against the audience it is for.

    python3 tools/validate-kid-safe.py

Run by scripts/check.sh and by CI. This is a GUARDRAIL, not a review: the point
is that it keeps holding as the game grows, the way the odds-sum check and the
economy parity test do.

WHY EACH RULE EXISTS
--------------------
1. NO CASINO LANGUAGE OR IMAGERY. "Unplayable gambling content" forces a
   Moderate maturity rating, which loses the Roblox Kids tier outright -- the
   thing the whole M6 plan is built on. It is the cheapest compliance win we
   have and the easiest to lose by accident during an art pass.
   docs/COMPLIANCE.md 1, docs/DECISIONS.md D-002.

2. NO VIOLENT OR FRIGHTENING WORDS. The audience is 9-15, with 5-8 to follow,
   and the design word for the PvP is "friendly snatchers". A game where you
   "kill" or "destroy" anything is a different game from the one in the GDD.

3. NO MESSAGE THAT LEAKS A CODE WORD. A player should never see a config key,
   a nil, or an internal name. "invalid request" is not an acceptable message
   for a nine-year-old.

4. RARITY IS NEVER COLOUR ALONE. Colourblind players are roughly 1 in 12 boys,
   which at any real scale is thousands of them. docs/GDD.md 5.16.

It scans STRING LITERALS only, so `instance:Destroy()` is not mistaken for the
word "destroy" shown to a player.
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE_DIRS = ["src"]

# Casino imagery and language. Any of these in a player-facing string or an
# instance name is a rating risk.
CASINO = [
    "casino", "gamble", "gambling", "jackpot", "slot machine", "slots",
    "prize wheel", "spin the wheel", "roulette", "lottery", "wager",
    "betting", "poker", "blackjack",
]

# Violent or frightening language. "snatch", "steal" and "thief" are the brief's
# own words for a friendly mechanic and are deliberately allowed.
VIOLENT = [
    "kill", "killed", "murder", "blood", "bloody", "gun", "weapon", "shoot",
    "stab", "die", "dying", "dead", "corpse", "attack", "destroy", "destroyed",
    "evil", "demon", "devil", "curse", "doom", "hell", "damn", "hate",
]

# Emoji that read as menacing or adult.
BAD_EMOJI = ["😈", "👹", "💀", "🔫", "🩸", "⚰️", "🖕", "🤬", "🎰", "🃏", "🎲"]

# Internal-looking text that must never reach a player.
LEAKY = ["nil", "userdata", "InvokeServer", "RemoteEvent", "invalid request", "error:"]

ALLOW_FILE_SUBSTRINGS = [
    # The validator's own word lists.
    "validate-kid-safe.py",
    # NameSafety.luau IS the blocklist. It contains every word we screen
    # generated names against, on purpose, and none of it is ever shown to a
    # player -- so scanning it would flag the safety net as the hazard.
    "NameSafety.luau",
]


def source_files() -> list[pathlib.Path]:
    files: list[pathlib.Path] = []
    for directory in SOURCE_DIRS:
        files.extend((ROOT / directory).rglob("*.luau"))
    return sorted(files)


STRING_RE = re.compile(r'"([^"\\]*(?:\\.[^"\\]*)*)"|`([^`]*)`')


def player_strings(text: str) -> list[tuple[int, str]]:
    """Every string literal, with its line number."""
    out: list[tuple[int, str]] = []
    for line_number, line in enumerate(text.split("\n"), start=1):
        stripped = line.lstrip()
        # Comments are documentation, not player text.
        if stripped.startswith("--"):
            continue
        for match in STRING_RE.finditer(line):
            value = match.group(1) if match.group(1) is not None else match.group(2)
            if value:
                out.append((line_number, value))
    return out


def contains_word(haystack: str, needle: str) -> bool:
    """Whole-word match, not substring.

    This project already learned this lesson the hard way: the name blocklist
    flagged "Titan" for containing "tit" and "shell" for containing "hell", and
    needed an allowlist to be usable at all (docs/NOMLINGS.md 4). A word-boundary
    match is the right fix here, because unlike generated names these strings are
    real English written by us.
    """
    pattern = r"\b" + re.escape(needle).replace(r"\ ", r"\s+") + r"\b"
    return re.search(pattern, haystack) is not None


def check_words(path: pathlib.Path, strings: list[tuple[int, str]]) -> list[str]:
    problems: list[str] = []
    for line_number, value in strings:
        lowered = value.lower()
        for word in CASINO:
            if contains_word(lowered, word):
                problems.append(
                    f"{path.relative_to(ROOT)}:{line_number}: casino language "
                    f"'{word}' in {value!r} -- forces a Moderate rating "
                    "(docs/COMPLIANCE.md 1)"
                )
        for word in VIOLENT:
            if contains_word(lowered, word):
                problems.append(
                    f"{path.relative_to(ROOT)}:{line_number}: violent/frightening "
                    f"word '{word}' in {value!r}"
                )
        for emoji in BAD_EMOJI:
            if emoji in value:
                problems.append(
                    f"{path.relative_to(ROOT)}:{line_number}: emoji {emoji} "
                    f"reads as menacing or adult, in {value!r}"
                )
        for leak in LEAKY:
            # Only flag text that looks like a SENTENCE shown to somebody --
            # a bare identifier in a type cast is not player-facing.
            if leak in value and (" " in value.strip() and len(value) > 12):
                problems.append(
                    f"{path.relative_to(ROOT)}:{line_number}: looks like internal "
                    f"text reaching a player: {value!r}"
                )
    return problems


def check_rarity_pairing() -> list[str]:
    """Rarity colour must always be accompanied by its label.

    Checked structurally: every Style.RARITY entry needs a `label`, and the
    label must not be empty. A colour with no word beside it is unreadable for
    a colourblind player.
    """
    problems: list[str] = []
    style = (ROOT / "src/shared/Style/init.luau").read_text()
    block = re.search(r"Style\.RARITY = \{(.*?)\n\}", style, re.S)
    if not block:
        return [f"src/shared/Style/init.luau: could not find Style.RARITY"]

    entries = re.findall(r"(\w+)\s*=\s*\{([^}]*)\}", block.group(1))
    if not entries:
        return ["src/shared/Style/init.luau: Style.RARITY has no entries"]
    for name, body in entries:
        if "color" in body and "label" not in body:
            problems.append(
                f"src/shared/Style/init.luau: rarity '{name}' has a colour but no "
                "label -- colour alone is unreadable for a colourblind player "
                "(docs/GDD.md 5.16)"
            )
        label = re.search(r'label\s*=\s*"([^"]*)"', body)
        if label and not label.group(1).strip():
            problems.append(
                f"src/shared/Style/init.luau: rarity '{name}' has an empty label"
            )
    return problems


def main() -> int:
    problems: list[str] = []
    scanned = 0
    strings_checked = 0

    for path in source_files():
        if any(part in str(path) for part in ALLOW_FILE_SUBSTRINGS):
            continue
        text = path.read_text(encoding="utf-8")
        strings = player_strings(text)
        scanned += 1
        strings_checked += len(strings)
        problems.extend(check_words(path, strings))

    problems.extend(check_rarity_pairing())

    if problems:
        print("Kid-safety check FAILED:\n")
        for problem in problems:
            print(f"  - {problem}")
        print(f"\n{len(problems)} problem(s) across {scanned} files.")
        return 1

    print(
        f"Kid-safe OK - {scanned} files, {strings_checked} strings checked."
        "\n  no casino language, nothing violent or frightening, no menacing emoji,"
        "\n  no internal text leaking to players, every rarity paired with a label."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
