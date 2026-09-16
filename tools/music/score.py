"""'Nomling Glade' -- the Fuse a Nomling main theme, as data.

Written in the pastoral-fantasy idiom: 6/8 lilt, diatonic modal harmony with a
flat-VII, solo woodwind over a harp. That idiom is genre convention and free to
use. The melody, harmony and arrangement here are original to this project --
deliberately NOT a transcription of anyone's copyrighted tune. Roblox
fingerprints uploaded audio, so this distinction is practical, not academic.
See docs/MUSIC.md.

The score is the single source of truth: render.py turns it into MIDI and WAV,
and the same JSON drives the browser player. Nothing duplicates the notes.
"""

from __future__ import annotations

# --- Tuning of the piece -----------------------------------------------------

TITLE = "Nomling Glade"
KEY = "D major, with a borrowed flat-VII (C major)"
METER = "6/8"
DOTTED_QUARTER_BPM = 72          # gentle walking pace; one bar every 1.67 s
EIGHTHS_PER_BAR = 6

# MIDI pitch helpers. The piece lives between F#3 and G5 -- a comfortable
# range for a recorder or flute, which is what the lead is written for.
D3, E3, Fs3, G3, A3, B3, C4 = 50, 52, 54, 55, 57, 59, 60
Cs4, D4, E4, Fs4, G4, A4, B4 = 61, 62, 64, 66, 67, 69, 71
C5, Cs5, D5, E5, Fs5, G5, A5 = 72, 73, 74, 76, 78, 79, 81

# --- Harmony -----------------------------------------------------------------
# One chord per bar. The C major in bar 6 is the flat-VII: the chord that makes
# a major key suddenly sound old and wide. It is the emotional hinge of the
# A section, and it is placed under the melody's second peak on purpose.

CHORDS = {
    "D":    (D3, [D4, Fs4, A4]),
    "A/C#": (Cs4 - 12, [Cs4, E4, A4]),
    "Bm":   (B3 - 12, [B3, D4, Fs4]),
    "G":    (G3 - 12, [G3, B3, D4]),
    "C":    (C4 - 24, [C4, E4, G4]),
    "Em":   (E3 - 12, [E3, G3, B3]),
    "A7":   (A3 - 12, [A3, Cs4, E4, G4]),
}

A_PROGRESSION = ["D", "A/C#", "Bm", "G", "D", "C", "G", "A7"]
B_PROGRESSION = ["G", "A7", "Bm", "G", "Em", "A7", "D", "A7"]

# --- Melody ------------------------------------------------------------------
# Each bar is a list of (pitch, eighths). Every bar must total 6.
#
# Shape: the A theme is a double arch. It climbs to F#5 in bar 2, settles, then
# climbs again in bar 5 -- and bar 6 answers that climb by falling onto the
# C natural. That fall is the hook. Bars 7-8 walk home.

A_THEME = [
    [(A4, 2), (B4, 1), (D5, 2), (E5, 1)],       # 1  D      rising, open
    [(Fs5, 2), (E5, 1), (Cs5, 3)],              # 2  A/C#   first peak
    [(D5, 2), (Cs5, 1), (B4, 2), (D5, 1)],      # 3  Bm
    [(B4, 2), (A4, 1), (G4, 3)],                # 4  G      settles
    [(Fs4, 2), (A4, 1), (D5, 2), (Fs5, 1)],     # 5  D      climbs again
    [(E5, 2), (D5, 1), (C5, 3)],                # 6  C      <- the flat-VII fall
    [(B4, 2), (A4, 1), (G4, 2), (B4, 1)],       # 7  G
    [(A4, 6)],                                  # 8  A7     breath
]

# The bridge is the "what did I just make?!" section. It opens with the widest
# leap in the piece -- a sixth up to G5 -- then descends in long steps, so the
# return of the A theme feels like coming home rather than starting again.
B_BRIDGE = [
    [(B4, 2), (D5, 1), (G5, 3)],                # 9   G     the leap
    [(Fs5, 2), (E5, 1), (D5, 2), (Cs5, 1)],     # 10  A7
    [(B4, 2), (D5, 1), (Fs5, 3)],               # 11  Bm
    [(E5, 2), (D5, 1), (B4, 3)],                # 12  G
    [(G4, 2), (B4, 1), (E5, 3)],                # 13  Em    lowest re-entry
    [(Cs5, 2), (D5, 1), (E5, 3)],               # 14  A7    lifts
    [(Fs5, 2), (E5, 1), (D5, 2), (B4, 1)],      # 15  D
    [(A4, 3), (Cs5, 3)],                        # 16  A7    turns back to D
]


def _check() -> None:
    for name, bars in (("A_THEME", A_THEME), ("B_BRIDGE", B_BRIDGE)):
        for i, bar in enumerate(bars, 1):
            total = sum(d for _, d in bar)
            assert total == EIGHTHS_PER_BAR, f"{name} bar {i} is {total}/6 eighths"
    assert len(A_THEME) == len(A_PROGRESSION)
    assert len(B_BRIDGE) == len(B_PROGRESSION)


_check()

# --- Form --------------------------------------------------------------------
# Each section names which parts play. The piece grows one layer at a time and
# then strips back, so the loop point lands on bare harp and is inaudible.

# `level` is the section's dynamic, and it has to be stated rather than left to
# emerge from the instrument gains. The first render had the solo recorder
# section louder than the full-band one, because the lead is the loudest single
# voice and adding quiet strings underneath does not change that. Loudness is a
# musical decision, so it is written here next to the orchestration.

SECTIONS = [
    # (label, bars, progression, melody or None, voices, level)
    ("Intro",  2, ["D", "A7"],   None,     ["harp"],                                            0.50),
    ("A1",     8, A_PROGRESSION, A_THEME,  ["harp", "recorder"],                                0.60),
    ("A2",     8, A_PROGRESSION, A_THEME,  ["harp", "flute", "strings", "pizz", "glock"],       0.82),
    ("Bridge", 8, B_PROGRESSION, B_BRIDGE, ["harp", "horn", "strings", "marimba", "pizz"],      0.90),
    ("A3",     8, A_PROGRESSION, A_THEME,  ["harp", "flute", "horn", "strings", "pizz", "glock"], 1.00),
    ("Outro",  2, ["G", "D"],    None,     ["harp", "strings"],                                 0.55),
]

TOTAL_BARS = sum(section[1] for section in SECTIONS)
