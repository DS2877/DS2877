# MUSIC.md — "Nomling Glade", the main theme

Written 2026-09-16. Source of truth: `tools/music/score.py`.
Browser player: [Nomling Glade](https://claude.ai/artifact/RykBMyuAYjMB9p8chWgmbF)

```bash
python3 tools/music/render.py --out build            # MIDI + JSON + WAV
python3 tools/music/render.py --out build --no-wav   # skip the slow part
```

---

## 1. What it is

**113 seconds, 66 bars**, 6/8, **D major with a borrowed ♭VII**, dotted quarter = 72.
Tin whistle over harp, growing to a full folk ensemble — fiddle countermelody, cello, bodhrán, strings, horn, bells — and stripping back so the loop is seamless.

| | |
|---|---|
| Form | Intro 6 · A1 8 · A2 8 · Bridge 8 · **Development 12** · A3 8 · **Finale 8** · Outro 8 |
| A harmony | D – A/C# – Bm – G – D – **C** – G – A7 |
| Bridge harmony | G – A7 – Bm – G – Em – A7 – D – A7 |
| Range | F#3 – G5 (comfortable for a real recorder or flute) |
| Loop point | exactly **110.000 s** |

## 2. The four decisions

1. **6/8 does the walking.** Six eighths grouped 3+3 lean long-short. The harp accents beats 1 and 4, so the lilt reads with no percussion at all.
2. **The ♭VII is the whole feeling.** Bar 6 goes to **C major** — a chord outside the key. That borrowing is what makes a major key sound old and wide, and the melody lands on the C natural exactly as the chord arrives. It is the hook, and it lasts 1.7 seconds.
3. **The bridge is the game's pitch.** It opens with a sixth up to G5, the widest leap in the piece, used once. That is *"What did I just make?!"* written as an interval.
4. **It grows by layer, not volume.** Each section adds an instrument. The outro strips to bare harp so the loop point is inaudible — this runs for hours behind someone's base.

## 3. Copyright — read before uploading anything

The brief for this piece was "as close to Elwynn Forest as possible". It is written in **that idiom** — compound meter, modal harmony, solo woodwind over harp — and the melody, harmony and arrangement are original.

That distinction is not academic:

- Musical **style and genre are not protectable**. Specific melodies are.
- Roblox **fingerprints uploaded audio**. A close copy of a known theme gets muted, and repeat hits put the account at risk — the same account that will hold the game's revenue.
- Blizzard is an active enforcer of its music.

**Rule for this project:** never upload a transcription of someone else's theme, however "inspired". If a future track needs to sound like something, name the *technique*, not the song.

## 4. How the files relate

```
tools/music/score.py     the notes -- edit here, nowhere else
tools/music/render.py    arrangement, MIDI writer, synth, JSON export
build/nomling-theme.mid  MIDI, General MIDI programs, opens in any DAW
build/nomling-theme.wav  60 s stereo synth mockup, 44.1 kHz
build/nomling-theme.json the same notes the browser player reads
```

The synth is additive — a harmonic recipe and an envelope per instrument, plus a
small Schroeder reverb. Pure standard library, **no new dependencies** (CLAUDE.md).
The browser player uses the same recipes via `PeriodicWave`, so it and the WAV are
the same instruments.

## 5. Before it ships

- [x] ~~Convert WAV → OGG.~~ `render.py` emits OGG directly (optional `soundfile`), encoded in blocks because handing libsndfile's Vorbis encoder five million frames at once segfaults it.
- [ ] 🔴 **Add the `asset` API system with Write to the API key.** Audio upload needs a different permission from publishing; the attempt returns `401 "User not authenticated"`. This is the only thing between the audio and the game.
- [ ] Upload to Roblox, set `Sound.Looped = true`, let the reverb tail overlap the restart.
- [ ] **Mix check on a phone speaker.** Bass is deliberately light because that is where this gets heard.
- [ ] Decide whether to re-record with real players or better samples before launch. The mockup is good enough to ship at M1 and is not the final artefact.
- [ ] Verify Roblox's current audio length and file-size limits before upload — not yet checked (`docs/VERIFY.md` has no entry for audio).

## 6. Where it plays

| Cue | Track | Notes |
|---|---|---|
| Plaza / base idle | Nomling Glade | the loop above |
| Fusion reveal | *not written* | must duck the theme, not fight it — M2a |
| Nom Storm | *not written* | seasonal variant, reuse the harmony — M2b |

A reveal sting and a storm variant can both be derived from this harmony rather than
written fresh, which keeps the score coherent and is far cheaper.
