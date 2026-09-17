"""'Nomling Glade' -- the Fuse a Nomling main theme, as data.

Written in the pastoral-folk idiom of the great fantasy overworld themes: 6/8
lilt, modal harmony with a borrowed flat-VII, tin whistle over harp, a fiddle
countermelody and a bodhran keeping the walk. That idiom is genre convention
and free to use. The melody, harmony and arrangement here are original to this
project -- deliberately NOT a transcription of anyone's copyrighted tune.
Roblox fingerprints uploaded audio, so this is practical, not academic.
See docs/MUSIC.md.

The score is the single source of truth: render.py turns it into MIDI, WAV, OGG
and the JSON that drives the browser player. Nothing duplicates the notes.
"""

from __future__ import annotations

# --- Tuning of the piece -----------------------------------------------------

TITLE = "Nomling Glade"
KEY = "D major, with a borrowed flat-VII; the development lifts to G"
METER = "6/8"
DOTTED_QUARTER_BPM = 72          # gentle walking pace; one bar every 1.67 s
EIGHTHS_PER_BAR = 6

# MIDI pitch helpers. The lead lives between D4 and A5 -- the range of a real
# D tin whistle, so a live player could double this line as written.
D3, E3, Fs3, G3, A3, B3, C4 = 50, 52, 54, 55, 57, 59, 60
Cs4, D4, E4, Fs4, G4, A4, B4 = 61, 62, 64, 66, 67, 69, 71
C5, Cs5, D5, E5, Fs5, G5, A5 = 72, 73, 74, 76, 78, 79, 81
B5, Cs6, D6 = 83, 85, 86

# --- Harmony -----------------------------------------------------------------
# One chord per bar. The C major in bar 6 is the flat-VII: the chord built on a
# note outside the key. Borrowing it is what makes a major key suddenly sound
# old and wide, and it is the emotional hinge of the whole piece.

CHORDS = {
    "D":    (D3, [D4, Fs4, A4]),
    "A/C#": (Cs4 - 12, [Cs4, E4, A4]),
    "Bm":   (B3 - 12, [B3, D4, Fs4]),
    "G":    (G3 - 12, [G3, B3, D4]),
    "C":    (C4 - 24, [C4, E4, G4]),
    "Em":   (E3 - 12, [E3, G3, B3]),
    "A7":   (A3 - 12, [A3, Cs4, E4, G4]),
    "D7":   (D3, [D4, Fs4, A4, C5]),
    "G/D":  (D3, [G3, B3, D4]),
    "Am":   (A3 - 12, [A3, C4, E4]),
}

A_PROGRESSION = ["D", "A/C#", "Bm", "G", "D", "C", "G", "A7"]
B_PROGRESSION = ["G", "A7", "Bm", "G", "Em", "A7", "D", "A7"]
# The development leans on the subdominant, which is why it feels like the
# piece has walked somewhere new without ever changing key signature.
C_PROGRESSION = ["G", "Em", "C", "D", "G", "Bm", "C", "D", "Em", "C", "G/D", "D7"]

# --- Melody ------------------------------------------------------------------
# Each bar is a list of (pitch, eighths). Every bar must total 6.

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

# The bridge is "what did I just make?!" as an interval: it opens on the widest
# leap in the piece, a sixth up to G5, used exactly once.
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

# The development. Faster note values, a wider range, and the only two bars in
# the piece that touch A5 -- so the climax has somewhere left to go.
C_DEVELOPMENT = [
    [(D5, 1), (E5, 1), (G5, 1), (Fs5, 2), (E5, 1)],   # 17  G
    [(D5, 2), (B4, 1), (E5, 3)],                      # 18  Em
    [(G4, 1), (A4, 1), (C5, 1), (E5, 2), (D5, 1)],    # 19  C
    [(Cs5, 2), (D5, 1), (A4, 3)],                     # 20  D
    [(B4, 1), (D5, 1), (G5, 1), (A5, 2), (G5, 1)],    # 21  G    reaches A5
    [(Fs5, 2), (D5, 1), (B4, 3)],                     # 22  Bm
    [(E5, 1), (G5, 1), (E5, 1), (C5, 2), (D5, 1)],    # 23  C
    [(E5, 2), (Fs5, 1), (A5, 3)],                     # 24  D    the peak
    [(G5, 2), (Fs5, 1), (E5, 2), (D5, 1)],            # 25  Em   long descent
    [(C5, 2), (E5, 1), (G5, 3)],                      # 26  C
    [(Fs5, 2), (E5, 1), (D5, 2), (Cs5, 1)],           # 27  G/D
    [(D5, 3), (A4, 3)],                               # 28  D7   home
]

# --- Countermelody -----------------------------------------------------------
# The fiddle line under the A theme. Long notes that move against the whistle
# rather than with it -- this is what stops a solo tune sounding like a demo.
A_COUNTER = [
    [(D4, 3), (Fs4, 3)],
    [(A4, 3), (G4, 3)],
    [(Fs4, 3), (A4, 3)],
    [(G4, 3), (D4, 3)],
    [(A4, 3), (D5, 3)],
    [(G4, 3), (C5, 3)],
    [(D5, 3), (B4, 3)],
    [(A4, 6)],
]


def _check() -> None:
    named = (
        ("A_THEME", A_THEME), ("B_BRIDGE", B_BRIDGE),
        ("C_DEVELOPMENT", C_DEVELOPMENT), ("A_COUNTER", A_COUNTER),
    )
    for name, bars in named:
        for i, bar in enumerate(bars, 1):
            total = sum(d for _, d in bar)
            assert total == EIGHTHS_PER_BAR, f"{name} bar {i} is {total}/6 eighths"
    assert len(A_THEME) == len(A_PROGRESSION) == len(A_COUNTER)
    assert len(B_BRIDGE) == len(B_PROGRESSION)
    assert len(C_DEVELOPMENT) == len(C_PROGRESSION)


_check()


def transposed(bars, semitones: int):
    """The same melody, moved. Used to voice the final statement an octave up."""
    return [[(p + semitones, d) for p, d in bar] for bar in bars]


# --- Form --------------------------------------------------------------------
# `level` is the section's dynamic, and it has to be stated rather than left to
# emerge from the instrument gains. An early draft had the solo section louder
# than the full-band one, because the lead is the loudest single voice and
# adding quiet strings underneath does not change that.

SECTIONS = [
    # (label, bars, progression, melody, counter, voices, level)
    ("Intro", 6, ["D", "D", "G", "D", "A7", "D"], None, None,
     ["harp", "strings"], 0.42),

    ("A1", 8, A_PROGRESSION, A_THEME, None,
     ["harp", "whistle", "cello"], 0.62),

    ("A2", 8, A_PROGRESSION, A_THEME, A_COUNTER,
     ["harp", "whistle", "fiddle", "strings", "cello", "bells"], 0.78),

    ("Bridge", 8, B_PROGRESSION, B_BRIDGE, None,
     ["harp", "horn", "strings", "cello", "bodhran"], 0.86),

    ("Development", 12, C_PROGRESSION, C_DEVELOPMENT, None,
     ["harp", "fiddle", "whistle", "strings", "cello", "bodhran", "bells"], 0.92),

    ("A3", 8, A_PROGRESSION, A_THEME, A_COUNTER,
     ["harp", "whistle", "fiddle", "horn", "strings", "cello", "bodhran"], 1.00),

    # The final statement, an octave up. Nothing new is added -- the tune simply
    # arrives somewhere it has not been, which is the cheapest real climax there is.
    ("Finale", 8, A_PROGRESSION, transposed(A_THEME, 12), A_COUNTER,
     ["harp", "whistle", "fiddle", "horn", "strings", "cello", "bodhran", "bells"], 1.00),

    # Strips back to bare harp so the loop point is inaudible. This runs for
    # hours behind someone's base; the seam is the thing players would notice.
    ("Outro", 8, ["G", "D", "Em", "A7", "G", "D", "A7", "D"], None, None,
     ["harp", "strings", "cello"], 0.50),
]

TOTAL_BARS = sum(section[1] for section in SECTIONS)
