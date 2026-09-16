"""Render 'Nomling Glade' to MIDI, WAV and JSON from tools/music/score.py.

    python3 tools/music/render.py --out build

No dependencies -- MIDI is written byte by byte and the audio is synthesised
with additive synthesis and a small reverb, both from the standard library.
That is a deliberate constraint: CLAUDE.md says ask before adding a dependency,
and a theme song is not a good reason to make the toolchain heavier.
"""

from __future__ import annotations

import argparse
import array
import json
import math
import os
import struct
import sys
import wave

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score  # noqa: E402

SAMPLE_RATE = 44100
EIGHTH_SECONDS = 60.0 / score.DOTTED_QUARTER_BPM / 3.0   # 3 eighths per dotted quarter


# --- Arrangement -------------------------------------------------------------
# Turns the score into flat note lists per voice. Everything about who plays
# what lives here, so the score file stays pure notes and the synth stays pure
# sound -- neither knows about the other.

def arrange() -> dict:
    voices: dict[str, list] = {}
    bar_index = 0

    def add(voice: str, pitch: int, start: float, dur: float, vel: float) -> None:
        voices.setdefault(voice, []).append(
            {"p": pitch, "t": round(start, 5), "d": round(dur, 5), "v": round(vel, 3)}
        )

    def add_at(voice, pitch, start, dur, vel, level):
        add(voice, pitch, start, dur, vel * level)

    for label, bars, progression, melody, active, level in score.SECTIONS:
        for bar in range(bars):
            chord_name = progression[bar % len(progression)]
            bass, tones = score.CHORDS[chord_name]
            bar_start = bar_index * score.EIGHTHS_PER_BAR * EIGHTH_SECONDS

            # Harp: a rolling 6/8 arpeggio, one note per eighth. This is the
            # spine -- it plays in every section, which is what lets the loop
            # point disappear.
            pattern = [tones[0], tones[1], tones[2], tones[0] + 12, tones[1], tones[2]]
            if "harp" in active:
                for e, pitch in enumerate(pattern):
                    # Lean on beats 1 and 4 so the 6/8 lilt is audible with no drums.
                    vel = 0.42 if e % 3 == 0 else 0.26
                    add_at("harp", pitch, bar_start + e * EIGHTH_SECONDS,
                           EIGHTH_SECONDS * 2.4, vel, level)

            if "strings" in active:
                for pitch in tones:
                    add_at("strings", pitch - 12, bar_start,
                           score.EIGHTHS_PER_BAR * EIGHTH_SECONDS, 0.20, level)

            if "pizz" in active:
                for e in (0, 3):
                    add_at("pizz", bass, bar_start + e * EIGHTH_SECONDS,
                           EIGHTH_SECONDS * 1.5, 0.38, level)

            if "marimba" in active:
                for e in (2, 5):
                    add_at("marimba", tones[(e // 2) % len(tones)] + 12,
                           bar_start + e * EIGHTH_SECONDS, EIGHTH_SECONDS, 0.22, level)

            if melody is not None:
                cursor = bar_start
                for note_index, (pitch, eighths) in enumerate(melody[bar]):
                    dur = eighths * EIGHTH_SECONDS
                    for voice, octave, vel in (
                        ("recorder", 0, 0.62), ("flute", 0, 0.58), ("horn", -12, 0.42)
                    ):
                        if voice in active:
                            # A hair of separation between notes, or a woodwind
                            # line turns into one long smear.
                            add_at(voice, pitch + octave, cursor, dur * 0.94, vel, level)
                    # Glockenspiel doubles only the first note of each half-bar,
                    # two octaves up: sparkle on the accent, not a second melody.
                    if "glock" in active and note_index == 0:
                        add_at("glock", pitch + 12, cursor, min(dur, EIGHTH_SECONDS * 2), 0.30, level)
                    cursor += dur

            bar_index += 1

    return voices


# --- MIDI --------------------------------------------------------------------

TICKS_PER_QUARTER = 480
# General MIDI programs, so the file opens sounding roughly right anywhere.
GM_PROGRAM = {
    "recorder": 74, "flute": 73, "horn": 60, "strings": 48,
    "harp": 46, "glock": 9, "marimba": 12, "pizz": 45,
}


def _vlq(value: int) -> bytes:
    """MIDI variable-length quantity."""
    out = bytearray([value & 0x7F])
    value >>= 7
    while value:
        out.insert(0, (value & 0x7F) | 0x80)
        value >>= 7
    return bytes(out)


def _track(events: list[tuple[int, bytes]]) -> bytes:
    events.sort(key=lambda e: e[0])
    data, last = bytearray(), 0
    for tick, payload in events:
        data += _vlq(tick - last) + payload
        last = tick
    data += _vlq(0) + b"\xff\x2f\x00"
    return b"MTrk" + struct.pack(">I", len(data)) + bytes(data)


def write_midi(voices: dict, path: str) -> None:
    def ticks(seconds: float) -> int:
        return int(round(seconds / EIGHTH_SECONDS * (TICKS_PER_QUARTER // 2)))

    tempo = int(round(60_000_000 / (score.DOTTED_QUARTER_BPM * 1.5)))  # per quarter
    meta = [
        (0, b"\xff\x51\x03" + struct.pack(">I", tempo)[1:]),
        (0, b"\xff\x58\x04" + bytes([6, 3, 36, 8])),        # 6/8
        (0, b"\xff\x03" + _vlq(len(score.TITLE)) + score.TITLE.encode()),
    ]
    tracks = [_track(meta)]

    for channel, (name, notes) in enumerate(sorted(voices.items())):
        ch = channel + 1 if channel + 1 != 9 else 10      # keep off the drum channel
        ch &= 0x0F
        events: list[tuple[int, bytes]] = [
            (0, bytes([0xC0 | ch, GM_PROGRAM.get(name, 0)])),
            (0, bytes([0xB0 | ch, 91, 64])),               # a little reverb send
        ]
        for n in notes:
            velocity = max(1, min(127, int(n["v"] * 127)))
            events.append((ticks(n["t"]), bytes([0x90 | ch, n["p"], velocity])))
            events.append((ticks(n["t"] + n["d"]), bytes([0x80 | ch, n["p"], 0])))
        tracks.append(_track(events))

    header = b"MThd" + struct.pack(">IHHH", 6, 1, len(tracks), TICKS_PER_QUARTER)
    with open(path, "wb") as fh:
        fh.write(header + b"".join(tracks))


# --- Synthesis ---------------------------------------------------------------
# Each instrument is a harmonic recipe plus an envelope. A single cycle is
# pre-computed into a wavetable, so rendering a note is one table lookup per
# sample rather than one sin() per harmonic per sample -- the difference
# between seconds and minutes.

TABLE_SIZE = 2048

INSTRUMENTS = {
    # name:      harmonics,                          attack, decay, sustain, release, pluck
    "recorder": ([1.0, 0.22, 0.10, 0.03],            0.055, 0.09, 0.86, 0.22, None),
    "flute":    ([1.0, 0.33, 0.11, 0.06, 0.02],      0.050, 0.09, 0.84, 0.24, None),
    "horn":     ([1.0, 0.58, 0.34, 0.19, 0.11, 0.05], 0.110, 0.14, 0.80, 0.34, None),
    "strings":  ([1.0, 0.50, 0.33, 0.25, 0.20, 0.15, 0.11, 0.08], 0.34, 0.20, 0.88, 0.55, None),
    "harp":     ([1.0, 0.45, 0.28, 0.16, 0.09, 0.05], 0.004, 0, 0, 0, 1.9),
    "glock":    ([1.0, 0.0, 0.0, 0.42, 0.0, 0.26],   0.002, 0, 0, 0, 1.3),
    "marimba":  ([1.0, 0.0, 0.0, 0.34],              0.003, 0, 0, 0, 0.65),
    "pizz":     ([1.0, 0.66, 0.38, 0.22, 0.13],      0.004, 0, 0, 0, 0.55),
}

# Vibrato makes the sustained voices breathe. Plucked voices get none.
VIBRATO = {"recorder": (5.2, 0.0045), "flute": (5.6, 0.0040), "horn": (4.8, 0.0035)}

# Where each voice sits in the stereo field, and how loud.
MIX = {
    "recorder": (0.95, -0.15), "flute": (0.88, 0.12), "horn": (1.05, -0.30),
    "strings": (0.52, 0.0), "harp": (0.70, 0.22), "glock": (0.50, 0.40),
    "marimba": (0.45, -0.38), "pizz": (0.62, 0.0),
}


def _wavetable(harmonics: list[float]) -> array.array:
    table = array.array("d", [0.0] * TABLE_SIZE)
    norm = sum(harmonics)
    for h, amp in enumerate(harmonics, start=1):
        if amp == 0.0:
            continue
        step = 2.0 * math.pi * h / TABLE_SIZE
        for i in range(TABLE_SIZE):
            table[i] += amp * math.sin(step * i)
    for i in range(TABLE_SIZE):
        table[i] /= norm
    return table


def render_wav(voices: dict, path: str) -> float:
    tail = 2.5
    end = max(n["t"] + n["d"] for notes in voices.values() for n in notes) + tail
    total = int(end * SAMPLE_RATE)
    left = array.array("d", [0.0]) * total
    right = array.array("d", [0.0]) * total

    tables = {name: _wavetable(spec[0]) for name, spec in INSTRUMENTS.items()}

    for name, notes in voices.items():
        harmonics, attack, decay, sustain, release, pluck = INSTRUMENTS[name]
        table = tables[name]
        gain, pan = MIX[name]
        gl, gr = gain * (1.0 - pan) * 0.5, gain * (1.0 + pan) * 0.5
        vib_rate, vib_depth = VIBRATO.get(name, (0.0, 0.0))

        for note in notes:
            freq = 440.0 * (2.0 ** ((note["p"] - 69) / 12.0))
            start = int(note["t"] * SAMPLE_RATE)
            if pluck:
                length = int(min(pluck * 3.0, note["d"] + pluck) * SAMPLE_RATE)
                k = math.exp(-1.0 / (pluck * SAMPLE_RATE))
            else:
                length = int((note["d"] + release) * SAMPLE_RATE)
                k = 0.0
            length = min(length, total - start)
            if length <= 0:
                continue

            amp = note["v"]
            phase = 0.0
            inc = freq * TABLE_SIZE / SAMPLE_RATE
            a_len = max(1, int(attack * SAMPLE_RATE))
            d_len = max(1, int(decay * SAMPLE_RATE)) if decay else 1
            off = int(note["d"] * SAMPLE_RATE)
            r_len = max(1, int(release * SAMPLE_RATE)) if release else 1
            env = 1.0                      # running envelope for plucked voices
            vib_inc = 2.0 * math.pi * vib_rate / SAMPLE_RATE

            for i in range(length):
                if pluck:
                    if i < a_len:
                        e = i / a_len          # very short ramp, kills the click
                    else:
                        env *= k               # then free exponential decay
                        e = env
                else:
                    if i < a_len:
                        e = i / a_len
                    elif i < a_len + d_len:
                        e = 1.0 - (1.0 - sustain) * (i - a_len) / d_len
                    elif i < off:
                        e = sustain
                    else:
                        e = sustain * max(0.0, 1.0 - (i - off) / r_len)
                # Only stop once the note is genuinely spent. Testing e <= 0 on
                # every sample also matches sample 0 of the attack ramp, which
                # silenced every note in the first version of this.
                if i > a_len and e <= 1e-5:
                    break

                if vib_depth and i > a_len:
                    step = inc * (1.0 + vib_depth * math.sin(vib_inc * i))
                else:
                    step = inc

                idx = int(phase)
                frac = phase - idx
                s = table[idx] + (table[(idx + 1) & (TABLE_SIZE - 1)] - table[idx]) * frac
                phase += step
                if phase >= TABLE_SIZE:
                    phase -= TABLE_SIZE

                value = s * e * amp
                j = start + i
                left[j] += value * gl
                right[j] += value * gr

    _reverb(left, right)
    _write(path, left, right)
    return end


def _reverb(left: array.array, right: array.array) -> None:
    """A small Schroeder reverb -- it is what turns a synth demo into a glade."""
    total = len(left)
    for delay_ms, feedback, wet in ((37.1, 0.36, 0.20), (53.7, 0.31, 0.16), (79.3, 0.27, 0.13)):
        d = int(delay_ms * SAMPLE_RATE / 1000.0)
        for buf in (left, right):
            for i in range(d, total):
                buf[i] += buf[i - d] * feedback * wet
        # Offset the right channel slightly so the tail is wide, not centred.
        d = int(d * 1.13)
        for i in range(d, total):
            right[i] += right[i - d] * feedback * wet * 0.6


def _write(path: str, left: array.array, right: array.array) -> None:
    peak = max(max(abs(v) for v in left), max(abs(v) for v in right)) or 1.0
    # Leave 1.5 dB of headroom; a theme that clips on a phone speaker is worse
    # than one that is slightly quiet.
    scale = 0.84 / peak
    frames = array.array("h", [0]) * (len(left) * 2)
    for i in range(len(left)):
        frames[i * 2] = int(max(-32767, min(32767, left[i] * scale * 32767)))
        frames[i * 2 + 1] = int(max(-32767, min(32767, right[i] * scale * 32767)))
    with wave.open(path, "wb") as fh:
        fh.setnchannels(2)
        fh.setsampwidth(2)
        fh.setframerate(SAMPLE_RATE)
        fh.writeframes(frames.tobytes())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default="build")
    parser.add_argument("--no-wav", action="store_true", help="skip the slow part")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)

    voices = arrange()
    count = sum(len(v) for v in voices.values())
    bars = score.TOTAL_BARS
    length = bars * score.EIGHTHS_PER_BAR * EIGHTH_SECONDS
    print(f"{score.TITLE} -- {bars} bars, {length:.1f} s, {count} notes")
    for name in sorted(voices):
        print(f"  {name:9s} {len(voices[name]):4d} notes")

    midi_path = os.path.join(args.out, "nomling-theme.mid")
    write_midi(voices, midi_path)
    print(f"\nMIDI  {midi_path} ({os.path.getsize(midi_path)} bytes)")

    json_path = os.path.join(args.out, "nomling-theme.json")
    with open(json_path, "w", encoding="utf-8") as fh:
        json.dump({
            "title": score.TITLE, "key": score.KEY, "meter": score.METER,
            "bpm": score.DOTTED_QUARTER_BPM, "bars": bars,
            "loopSeconds": round(length, 3), "voices": voices,
        }, fh, separators=(",", ":"))
    print(f"JSON  {json_path} ({os.path.getsize(json_path)} bytes)")

    if not args.no_wav:
        wav_path = os.path.join(args.out, "nomling-theme.wav")
        print("WAV   synthesising...", flush=True)
        render_wav(voices, wav_path)
        mb = os.path.getsize(wav_path) / 1024 / 1024
        print(f"WAV   {wav_path} ({mb:.1f} MB)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
