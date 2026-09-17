"""Generates the game's sound effects, using the same synth as the theme.

    python3 tools/music/sfx.py --out assets/audio

Seven short cues, all original and all built from the additive engine in
render.py -- which matters for two reasons. They are free of any licence
question, and they share the theme's harmonic language, so the feedback sounds
like it belongs to the music rather than being bolted on beside it.

Every cue is in D major or its dominant, the theme's key, so nothing ever
clashes with the loop playing underneath it.
"""

from __future__ import annotations

import argparse
import array
import math
import os
import random
import sys
import wave

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render  # noqa: E402

SAMPLE_RATE = render.SAMPLE_RATE


def note(pitch: float, start: float, dur: float, gain: float, instrument: str) -> dict:
    return {"p": pitch, "t": start, "d": dur, "v": gain, "i": instrument}


# All pitches are MIDI numbers in D major -- the theme's key -- so a cue firing
# over the loop is consonant with it rather than merely loud.
D5, Fs5, A5, D6, Fs6, A6, D7 = 74, 78, 81, 86, 90, 93, 98
A4, D4, E4, A3, D3 = 69, 62, 64, 57, 50

CUES: dict[str, list[dict]] = {
    # A single bright chime. Heard constantly, so it is short, quiet and high --
    # anything with body becomes exhausting within a minute.
    "coin": [
        note(D6, 0.0, 0.16, 0.55, "bells"),
        note(A6, 0.01, 0.12, 0.30, "bells"),
    ],
    # Two rising notes: the universal "that worked".
    "purchase": [
        note(A5, 0.0, 0.12, 0.60, "whistle"),
        note(D6, 0.09, 0.22, 0.70, "whistle"),
        note(D4, 0.0, 0.25, 0.35, "harp"),
    ],
    # A rising arpeggio for a hatch. Resolves upward and stops, so it reads as
    # an arrival rather than a flourish.
    "hatch": [
        note(D5, 0.00, 0.14, 0.55, "whistle"),
        note(Fs5, 0.09, 0.14, 0.58, "whistle"),
        note(A5, 0.18, 0.14, 0.60, "whistle"),
        note(D6, 0.27, 0.38, 0.72, "whistle"),
        note(D4, 0.00, 0.5, 0.40, "harp"),
        note(A4, 0.18, 0.4, 0.30, "harp"),
    ],
    # The reveal fanfare. The longest cue, and the only one that uses the horn:
    # it has to feel like an announcement.
    "reveal": [
        note(D4, 0.00, 0.6, 0.45, "horn"),
        note(A4, 0.00, 0.6, 0.35, "horn"),
        note(D5, 0.12, 0.18, 0.55, "whistle"),
        note(Fs5, 0.26, 0.18, 0.58, "whistle"),
        note(A5, 0.40, 0.20, 0.62, "whistle"),
        note(D6, 0.56, 0.70, 0.78, "whistle"),
        note(Fs6, 0.56, 0.70, 0.40, "bells"),
        note(D3, 0.00, 0.9, 0.42, "cello"),
        note(D6, 0.56, 0.5, 0.35, "bells"),
    ],
    # The alarm. A falling minor interval, which is the one shape in this key
    # that reads as bad news, repeated twice so it cannot be mistaken for music.
    "snatchAlarm": [
        note(A5, 0.00, 0.16, 0.65, "fiddle"),
        note(Fs5, 0.16, 0.20, 0.65, "fiddle"),
        note(A5, 0.40, 0.16, 0.65, "fiddle"),
        note(Fs5, 0.56, 0.28, 0.65, "fiddle"),
        note(D3, 0.00, 0.5, 0.45, "bodhran"),
    ],
    # The grab: a drum hit with a short pluck on top. Physical, not musical.
    "snatchGrab": [
        note(D3, 0.00, 0.25, 0.70, "bodhran"),
        note(D5, 0.02, 0.18, 0.40, "harp"),
    ],
    # Refusal. Low, short, and deliberately unsatisfying.
    "deny": [
        note(A3, 0.00, 0.18, 0.55, "cello"),
        note(A3 - 2, 0.08, 0.22, 0.50, "cello"),
    ],
}


def synth(notes: list[dict], tail: float = 0.7) -> tuple[array.array, array.array]:
    end = max(n["t"] + n["d"] for n in notes) + tail
    total = int(end * SAMPLE_RATE)
    left = array.array("d", [0.0]) * total
    right = array.array("d", [0.0]) * total

    tables = {name: render._wavetable(spec[0]) for name, spec in render.INSTRUMENTS.items()}

    for n in notes:
        name = n["i"]
        harmonics, attack, decay, sustain, release, pluck = render.INSTRUMENTS[name]
        table = tables[name]
        gain, pan = render.MIX[name]
        noise_mix = render.NOISE.get(name, 0.0)
        breath = render.BREATH.get(name, 0.0)
        gl, gr = gain * (1.0 - pan) * 0.5, gain * (1.0 + pan) * 0.5

        freq = 440.0 * (2.0 ** ((n["p"] - 69) / 12.0))
        start = int(n["t"] * SAMPLE_RATE)
        if pluck:
            length = int(min(pluck * 3.0, n["d"] + pluck) * SAMPLE_RATE)
            k = math.exp(-1.0 / (pluck * SAMPLE_RATE))
        else:
            length = int((n["d"] + release) * SAMPLE_RATE)
            k = 0.0
        length = min(length, total - start)
        if length <= 0:
            continue

        phase = 0.0
        inc = freq * render.TABLE_SIZE / SAMPLE_RATE
        a_len = max(1, int(attack * SAMPLE_RATE))
        d_len = max(1, int(decay * SAMPLE_RATE)) if decay else 1
        off = int(n["d"] * SAMPLE_RATE)
        r_len = max(1, int(release * SAMPLE_RATE)) if release else 1
        env = 1.0
        rnd = random.Random(int(n["p"] * 7919 + n["t"] * 1000)).random
        lp = 0.0

        for i in range(length):
            if pluck:
                if i < a_len:
                    e = i / a_len
                else:
                    env *= k
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
            if i > a_len and e <= 1e-5:
                break

            idx = int(phase)
            frac = phase - idx
            s = table[idx] + (table[(idx + 1) & (render.TABLE_SIZE - 1)] - table[idx]) * frac
            phase += inc
            if phase >= render.TABLE_SIZE:
                phase -= render.TABLE_SIZE

            if noise_mix:
                lp += 0.28 * ((rnd() * 2.0 - 1.0) - lp)
                s = lp * (1.0 - noise_mix) + s * noise_mix
            elif breath:
                lp += 0.55 * ((rnd() * 2.0 - 1.0) - lp)
                s += lp * breath

            value = s * e * n["v"]
            j = start + i
            left[j] += value * gl
            right[j] += value * gr

    # A short reverb, much smaller than the theme's -- a cue needs a little
    # space, not a hall.
    for delay_ms, feedback, wet in ((21.3, 0.30, 0.14), (34.7, 0.24, 0.10)):
        d = int(delay_ms * SAMPLE_RATE / 1000.0)
        for buf in (left, right):
            for i in range(d, total):
                buf[i] += buf[i - d] * feedback * wet

    return left, right


def write(path: str, left: array.array, right: array.array) -> None:
    peak = max(max(abs(v) for v in left), max(abs(v) for v in right)) or 1.0
    scale = 0.82 / peak
    frames = array.array("h", [0]) * (len(left) * 2)
    for i in range(len(left)):
        frames[i * 2] = int(max(-32767, min(32767, left[i] * scale * 32767)))
        frames[i * 2 + 1] = int(max(-32767, min(32767, right[i] * scale * 32767)))
    with wave.open(path, "wb") as fh:
        fh.setnchannels(2)
        fh.setsampwidth(2)
        fh.setframerate(SAMPLE_RATE)
        fh.writeframes(frames.tobytes())


def to_ogg(wav_path: str, ogg_path: str) -> bool:
    try:
        import soundfile  # type: ignore
    except ImportError:
        return False
    with soundfile.SoundFile(wav_path) as src:
        with soundfile.SoundFile(
            ogg_path, "w", samplerate=src.samplerate, channels=src.channels,
            format="OGG", subtype="VORBIS",
        ) as dst:
            while True:
                block = src.read(65536, dtype="float32")
                if len(block) == 0:
                    break
                dst.write(block)
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default="assets/audio")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)

    encoded = 0
    for name, notes in CUES.items():
        left, right = synth(notes)
        wav_path = os.path.join(args.out, f"sfx-{name}.wav")
        write(wav_path, left, right)
        ogg_path = os.path.join(args.out, f"sfx-{name}.ogg")
        if to_ogg(wav_path, ogg_path):
            os.remove(wav_path)
            encoded += 1
            kb = os.path.getsize(ogg_path) / 1024
            print(f"  {name:12s} {len(left) / SAMPLE_RATE:5.2f} s  {kb:6.1f} KB")
        else:
            print(f"  {name:12s} wav only -- `pip install soundfile` to encode")

    print(f"\n{encoded}/{len(CUES)} cues encoded to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
