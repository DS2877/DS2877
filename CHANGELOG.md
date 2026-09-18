# Changelog

All notable changes to this project. Newest first.

## [Unreleased]

### The Laser Gate you can actually find · 2026-09-18

*"Activating the laser gate"* was one of three things the playtest said did not
work, and unlike the kitchen there was no code defect — the button was just 47
studs along the road in a corner of a 108 × 76 plot behind a 12-stud activation
range. It is now beside the path, mirroring the egg nest across it, so walking
in from the road puts the eggs on one side and the gate on the other. It also
has an on-screen way in for the first time: the bottom bar's third button, the
one that shows SAVE IT! when a thief is near, offers LASER GATE when you are
home with the gate down (D-030). The server still re-checks everything.

**Every client controller is now proved to load in a real engine.**
`tests/cloud/smoke.luau` requires all fourteen inside the published place and
checks each one reports its own name and has a `start()`. `Bootstrap.client`
pcalls every require on purpose, so a controller that throws while loading is
skipped in silence — its buttons never wired, and the report from a phone is
"nothing happens when I press it". Both halves of that hole, server and client,
are now closed: 38 checks, all passing.

**The base geometry is arithmetic a test can check.** `World.pedestalRing()` and
`World.nestFootprint()` are pure and shared with `PlotService`, and
`tests/unit/nest.spec.luau` holds the clearances that were previously true by
luck — including the one that was not, the bench overlapping the path by half a
stud.


### The playtest round: dead buttons, silent music, eggs in the world · 2026-09-17

Philip's report was *"none of the buttons in game works. I tried buying,
activating the laser gate, and opening the kitchen"*, plus *"I don't have any of
the relevant sounds you said you added. And I don't have a themesong playing in
the background"*, plus a list of things to fix before going further. The server
was proven healthy first — all 19 services survive `init()` and `start()` in the
real engine, and all 8 audio assets came back Approved and correctly owned — so
everything here is client-side or world-building, which is where the evidence
pointed.

**The kitchen prompt had no handler.** `ShopController` walked the world once at
startup: `WaitForChild("FusionLab")` and then a plain `FindFirstChild("Counter")`.
`WaitForChild` on a Model returns when the MODEL replicates, not when its
children have — and under `StreamingEnabled` a landmark far down the street has
no parts on the client at all. The lookup returned nil, nothing was connected,
and later the prompt streamed in, drew its "Open the Kitchen" label and did
nothing when tapped. It now listens to `ProximityPromptService.PromptTriggered`,
which needs nothing to be found and has nothing to race.

**StreamingEnabled is off** (D-027). The radius was 512 and the street is 520.

**The theme was playing at 3% of full scale.** `SoundGroup.Volume` multiplies
`Sound.Volume`, and both were being set to the track's level: 0.32 × 0.32, of a
number already chosen to be discreet on a phone. Approved, loaded, playing, and
inaudible. The group is now a plain 0..1 fader and the level lives in one place.
`AudioController` also reports a fault if the theme asset has not loaded after
ten seconds, which is the one remaining way silence could still be the assets.

**Every failure now lands on the phone screen.** The fault panel moved into its
own dependency-free `src/client/Fault.luau`, and `Net.invoke()` routes every
client→server call through it: a missing remote, a handler that errors, and a
handler that never answers are three different bugs that all used to look like
"the button does nothing". A `RemoteFunction` with no `OnServerInvoke` does not
error when invoked — it yields forever — so there is a six-second deadline.

**Eggs are in the world now** (D-028). A nest bench in your own base, an egg per
occupied slot, the countdown on a sign above it, and a prompt that appears the
moment it is ready. The HUD tray is gone and the chrome budget dropped to 30%.

**The awning is a market stall rather than a floating slab.** It was 108 studs
wide, held up by two thin posts at the far ends that were four studs behind the
weight, and you walked through all of it. It now has six posts along the front
edge, a beam across them and a scalloped valance, at a height a jumping player
clears (13.1 studs of clearance against a ~12.7-stud head at the top of a jump).

**Visible scenery collides** (D-029) — the shrubbery and the cooking pots were
ghosts.

**The SAVE button only appears when there is something to save**, and says
"SAVE IT!". *"The save button I don't even know what the function is for."*

**The tutorial stops promising a green button that never existed.** It now names
the nest and puts a marker on it.

**`tests/cloud/smoke.luau` asserts every world prompt exists** — the gate button
on all eight bases, both landmark counters, and the nest cups. Each of those is
built by a service that `continue`s past a part it cannot find, so a missing
prompt is not an error anywhere: it is a landmark you can stand in front of that
does nothing.


### The rest of the analytics · 2026-09-17

Six events that `docs/ANALYTICS.md` has specified since Phase 1 and nothing
emitted, so §1b's "what is actually wired" table now has one ⬜ left in §3 and it
is one we are choosing not to build.

- **`weather_started`** and **`mutation_gained`**, per player. Weather is the
  free content engine and mutations are the most valuable thing the server hands
  out, and neither was measured at all. Per player because Roblox custom events
  are per player — there is no server-wide event — which also answers the
  question that matters: is anyone PRESENT for weather, or does it keep firing
  into an empty street?
- **`snatch_defended`**, with `method` = `bubble` or `timeout`. Together with
  `snatch_attempted`'s `blocked_reason` this is the whole picture of whether the
  fair-play rules protect victims or merely frustrate attackers.
- **`comeback_egg_granted`**, the loss softener. Being robbed has to hand you
  something; this is how we find out whether it lands.
- **`fusion_book_milestone`**, at 1, 5, 10, 25, 50, 100, 250, 500, 1000.
  Deliberately sparse: the question is how far down the collection curve people
  get, and an event per entry would be thousands of rows saying nothing.
- **`is_vault` on `nomling_placed`.** D-024's reversal condition says the Vault
  is wrong if it sits empty. This field is the only way to know.

**Session length and retention are deliberately NOT custom events.** Roblox
reports both natively (§5), and duplicating them would spend cardinality budget
on numbers we already have.

### Offline pay was a salary for owning nothing · 2026-09-17

**Reported:** *"The 2/sec continues while not in game and should not, my
character suddenly has over 7k gold just from being offline."*

Over 7k is exactly right, and the number says which two bugs fired together:
**7,200 = 2/s stipend × 2 (Frost Sugar) × 7,200 s cap × 25% efficiency.**

`payOffline` used `IncomeService.perSecond`, which carries two things that have
no business in an offline calculation.

**The stipend.** It is a mid-session rescue — you have nothing, here is enough
to act — and `STIPEND_PER_SECOND`'s own comment says it pays only at zero so it
"never touches normal play and cannot be farmed". Multiplied by a two-hour cap
it became a salary for owning nothing, collectable on every single login:
**3,600 coins** on a completely empty base, in a game where the first egg costs
25. The economy simulator has never modelled a stipend at all, so this broke
every pacing number in `docs/ECONOMY.md` without the parity test noticing —
parity compares constants, not consequences.

**The live weather multiplier, which was worse.** Weather is a 90-second event
worth up to ×10. Opening the app while one happened to be running multiplied the
*entire* two-hour offline payout by it — for weather the player was not there
for. Galaxy Jelly would have paid **36,000** on an empty base. The simulator
uses `average_weather_factor()`, a long-run ~1.05 uplift, which is what the
pacing targets were actually tuned against; the game now uses the same.

Offline pay now uses a new `Income.earnedPerSecond` — no stipend — at the
average weather factor. The real offline grant is untouched: a base that
genuinely earns is still paid 2 h at 25%, because that is a tuned part of
pacing and a returning player should be rewarded.

Three regression tests, one of which asserts the size of the old payout rather
than only the fix, so the reason the test exists survives in the test.

### The Laser Gate, the Vault, and a typechecker that pays for itself · 2026-09-17

**CI typechecks Luau now.** Philip approved it, so `luau-lsp` 1.69.0 runs over
`src` on every run, blocking like every other check. Getting it to mean anything
took three things beyond installing it: a Rojo **sourcemap**, because Roblox
resolves a require through the DataModel tree and without one every cross-module
require is `any`; **`globalTypes.d.luau`**, Roblox's own API as types, without
which `BasePart` — the exact type the base bug turned on — is also `any`; and
**`strictDatamodelTypes` off**, because this game builds its whole world at
runtime and the strict setting would report every one of those instances as an
error.

**It found nine things on its first run, and one was live.** `EggService.buy`
inserted an incubator with no `total`, so every *bought* egg — the ordinary
case, every egg after the free starter — drew its hatch progress ring with no
denominator. Nothing errored; the ring was simply wrong. The same field was
missing from the Comeback Egg. The other eight were three patterns: config
tables sealed to their literal fields so `for key, value in Economy.EGGS` typed
both as `unknown`, `UpdateAsync` transforms whose abort path made Luau infer
`nil` as the whole return type, and `pcall(f)` destructured into two values
where `f` returns none.

**The Laser Gate.** A button beside the path on every base, and five lasers
across its front that are invisible until it goes up. 60 seconds up, 90 seconds
of cooldown measured **from the raise** — so a base can be locked at most 60
seconds in every 90, and the gap between one gate falling and the next going up
is 30. Measured from the *drop* it would be a very different game, which is why
`tests/unit/gate.spec.luau` asserts which one it is rather than trusting the
comment.

The lasers do **not** collide. A solid barrier traps the owner on whichever side
they are standing and puts client physics in charge of who gets robbed; the
refusal is a server rule and the lasers are how a thief sees it coming from the
road. Proximity is checked server-side on both entry points, because defending
has to mean being home rather than a button you press while robbing somebody
else.

**The Vault.** Pedestal 9 — a fridge against the back wall, so reaching it means
crossing the whole base. A creature in it cannot be snatched and does not mutate
(GDD 5.7), **and does not earn** (D-024). That third one is ours, not the GDD's:
"safe but no mutation" alone makes the Vault a strictly better ninth pedestal
and the correct play becomes "vault your best one and never think about it
again". Costing its income makes it a decision. It also keeps the economy
simulator honest, which models exactly eight earners.

It is a SLOT, not a flag, so placing, rendering, storing and sanitizing a
vaulted Nomling are all the same code as any other pedestal — only auto-placement
and snatching treat it specially. `DataService` now sanitizes against
`PEDESTALS_TOTAL` rather than `PEDESTALS_BASE`; with the old bound every vaulted
creature would have been silently dropped on load.

**Sneaky Sam respects both.** The NPC snatchers exist because Philip is
phone-only and cannot run two clients, so a defence they ignore is a defence
that is never actually tested — and from inside the game it would read as the
gate simply not working.

`snatch_attempted` now logs its `blocked_reason`, which is the only way to learn
whether the new defences protect victims or just frustrate attackers, plus a new
`gate_raised` row in `docs/ANALYTICS.md`.

### Every base was empty, and one number is why · 2026-09-17

**Fixed: no player, on any server, was ever assigned a base.** Philip reported it
three times, each report sharper than the last — first "I don't seem to get a
base", then "I still don't get assigned a base", finally the one that solved it:
*"all bases are labelled as empty base."* Not his base. All of them. That is not a
player being unlucky, it is a server where assignment never ran once.

It was one argument. `buildPedestals` called `pedestalPositions(plot.index)` where
the function takes `pad: BasePart`. Indexing a number throws, the throw happened on
the **first** base, and it aborted the discovery loop before a single plot was
registered — so `plots` stayed empty, `assign()` had nothing to hand out, and every
sign kept the "EMPTY BASE" text it was built with. The line was introduced four
commits ago in the street rebuild (`65d722c`), where `plot.pad` became `plot.index`.

**Nothing in this project typechecks Luau.** Every file says `--!strict`; no tool
reads it. `DECISIONS.md` D-014 claimed CI covered it — the job was never written.
So a plain argument-type error passed formatting, linting, 142 unit tests, economy
parity, the kid-safe gate and the Rojo build, published to TEST, and cost Philip
two playtests. D-014 is corrected in place and D-023 proposes the CI job; it adds a
tool, so it is a question for Philip rather than a commit.

Three structural changes so the next mistake of this shape is survivable:

- **A plot is registered before its pedestals are built**, and the build is
  pcall'd. A throw now costs one base its pedestals instead of costing every
  player on the server their home.
- **Subscribing to a profile is also a delivery.** `DataService` connects
  `PlayerAdded` in `init()`, services subscribe in `start()`, and every `init()`
  runs before any `start()` — so a player who joined during boot loaded against a
  callback list that was empty, and no service ever heard about them. The new
  `Subscribers` registry replays every profile already loaded to whoever subscribes
  next, in arrival order. This was a second, independent cause of exactly the same
  symptom, and it was live.
- **A profile cannot be delivered twice.** `load()` is reachable from both the
  `PlayerAdded` connection and `start()`'s sweep, and the DataStore call between
  them yields for a second or more — long enough for both to be in flight. That
  handed one player two bases and left two respawn handlers arguing. Guarded at the
  load, and `assign()` is idempotent as well.

`Subscribers` is engine-free under `src/shared/Logic/`, so the ordering properties
that are impossible to reproduce by hand in a live server are covered by six unit
tests: late subscriber caught up, replay in arrival order, a forgotten key not
replayed, no duplicate on re-publish, and one broken listener not stopping the
rest. 142 tests pass.

### Sound, a working key, and a test that had never run · 2026-09-17

**The game has sound.** The theme and all seven effects are uploaded, live, and
wired — 113 seconds of *Nomling Glade* plus coin, purchase, hatch, reveal, snatch
alarm, snatch grab and deny. Every entry had been `assetId = 0`, which
`Audio.isReady()` treats as inert, so the game had been deliberately silent rather
than broken while the upload was blocked on a key scope.

Uploaded in two passes on purpose: **one small effect first as a canary**, then the
set. Roblox allows 10 audio uploads per month on an account that is not
ID-verified, we have 8 files, and audio is *"not available for updating"* — so a
bad upload is a spent slot, not something to fix in place. A canary costs one slot
and proves the key, the creator id and the multipart format before the budget goes.

**TEST was never actually live, and a log line is why.** CI publishes with
`--type Saved`, which creates a version *without* making it live — correct for
validation. But `publish.py` printed `Published as version N` either way. That line
went into a CI log, into my summary, and Philip spent a playtest on a build four
commits old whose belt button was still the broken one. It now prints
`SAVED as version N — NOT LIVE` and names the workflow that does deploy.

**The cloud smoke test had never once executed.** The API key had lacked the
luau-execution scope since the day it was made, so nobody had seen it pass — and
when it finally ran it failed on two assertions that were impossible from the day
they were written. It checked for `ReplicatedStorage.Net` and `Workspace.Plaza`,
both built at runtime by scripts a Luau task never starts (*"Server and local
scripts within the place also do not automatically run"*), and the Plaza had not
existed since the map became a street. Same shape as the format gate that sat green
and inert, except this one was red and unread.

Rewritten around what a task genuinely can do, which is also this project's real
blind spot: **every shared module is now required inside the real Roblox engine.**
Lune resolves `require` by file path and has no engine, and there is no Studio and
no `luau-lsp` in cloud sessions, so nothing else covers "does this actually load".
25/25 checks pass, including all 22 modules.

- **A hung cloud task used to print nothing at all.** The runner died on the
  timeout without fetching logs, so five minutes bought zero information. It now
  prints whatever the task logged, and the test names each module before requiring
  it — so the last line is always the culprit. Which is how the next hang got
  diagnosed as transient rather than blamed on the wrong code.
- **A beam of light over your own base.** "I can't find my base" — eight bases on
  one 520-stud road, same parts, same colours. A signpost, never a teleport:
  carrying a snatched Nomling home on foot is the whole risk half of stealing.
- **The egg button priced the tier it actually buys.** It read `prices.basic` while
  buying `bestEgg`, so after a Re-Nom it advertised 25 coins and charged 1200.
- **A manual CI run can no longer burn the audio quota** — the upload job is behind
  an input that defaults to false.

### Playtest fixes: the HUD, and the belt button that did nothing · 2026-09-17

From Philip's phone playtest: *"Screen composition looks a bit weird, make the buttons
smaller and the ui more ux friendly. Also you can't buy any of the animals from the band,
and the buttons don't seem to be working."* Two of those were the same bug wearing
different hats.

**The belt button was not broken — it was mute.** A `ProximityPrompt` fires on the
**server**, and nothing carries a return value back to the player the way a
`RemoteFunction` does. `ConveyorService.buy` returned `(false, "You need 90 coins.")` and
that string went nowhere. Tapping Buy on a Nomling you could not afford did *literally
nothing*, which is indistinguishable from a dead button. Every refusal now reaches the
player, with the deny cue, and says how much more they need rather than just the price.
`StoreNomling` had the same hole and is fixed the same way. `StealService` already got
this right, which is why nobody noticed.

**A button that renders blank is not a rendering bug you find in a log.** The Bubble
button was labelled U+1FAE7 🫧 — Emoji 14.0, from 2021. Roblox draws text with the host
platform's emoji font, so on a phone it was an empty blue rectangle. It threw nothing and
logged nothing. `tools/validate-kid-safe.py` now fails the build on any emoji outside an
explicit allowlist with its Emoji version recorded, floor 12.0 (2019); it caught four more
live instances the moment it was switched on. The bubble is now a **drawn** circle and the
word SAVE.

**The HUD is a third smaller and lays itself out.** Bottom bar 72 → 50, rail 56 → 44,
purse 208×70 → 152×44, incubators 150×58 → 108×44. Every number now lives in
`src/shared/Logic/HudLayout.luau`, which requires nothing — so Lune tests the whole screen
composition: **bands cannot overlap, nothing drops under the 44 pt touch floor, and the
furniture cannot take more than 32% of a resting screen** (it was 45%). That test caught a
42 pt incubator before a phone did.

- **Nothing positions itself against a screen edge any more.** The purse and the objective
  banner are one row that stops short of the rail; the weather banner is a strip under it;
  the incubator tray is docked to the top of the bottom bar instead of floating
  mid-screen; the toast sits above the tray. Four collisions in one screenshot, all
  arithmetic, all now derived.
- **`CoreUISafeInsets`, not `DeviceSafeInsets`.** The latter dodges the notch but does not
  reserve the Roblox top bar, so the banner rendered underneath the menu and chat buttons.
  Recorded in `docs/VERIFY.md` with its caveat — the docs publish no description for these
  enum values.
- **FUSE stopped falling off its own button.** `TextScaled` in a 72 px button asks for
  72 px type; with an emoji in front of it the E ran past the right edge. Labels are inset
  on all four sides and capped with a `UITextSizeConstraint`.
- **Nameplates have a hierarchy.** One `TextScaled` label makes every line the same size,
  so a whole street of them was stacks of unreadable grey. A shared `Nameplate` module
  gives the mutation (or the name) the headline and rarity/income/price the small line, so
  what you need from across the street stays readable after the rest stops being.
- **The tutorial counts.** "Buy a Nomling off the belt" with 12 coins in your purse reads
  as a broken game. It now reads *"Saving up for the belt: 12 / 90 coins — your Nomlings
  are earning it now"*, and the belt sign shows the price from across the street.

### The AAA sprint · 2026-09-17

**The game now looks and plays like a product.** Seven areas, one night.

**Creatures are real.** 15–20 parts each: torso, belly panel, head, snout, ears, two eyes with pupils, legs or flippers, a tail or fluke, wings where the archetype has them — and the **snack overlay** that makes a fusion legible in under a second: taco shells arching over backs, nori bands, pizza-crust collars, sprinkles, popcorn puffs, waffle grids. Built on the **client** from a replicated genome, because a genome is a handful of strings and a model is twenty parts, and the GDD's test case is 150 visible at once. 11 tests cover the part budget, the eyes, the snack layer, distinct silhouettes per archetype, and byte-identical geometry forever.

**Fusion, the reveal, and World First.** The differentiator, finally in. Ordered pairs (Sushiwal ≠ Wafflepup), a child never worse than its best parent, matching tiers upgrading more often than mismatched ones, and fusion that can inherit a mutation but never invent one. The reveal gets the whole screen: dim, silhouette before colour, rarity banner, then the **name types itself out** — because the name is the proof nobody has seen this creature before. World First is a DataStore first-writer-wins claim broadcast server-wide, storing a UserId and never a display name (D-013).

**Art direction.** One committed time of day, warm-neutral ambient instead of grey, Atmosphere with real haze, volumetric clouds, restrained bloom, a colour grade too small to notice working, sun rays, subtle far-only depth of field — plus measured per-device quality scaling. None of it costs a part.

**A street that reads as a place.** Pavement with a kerb you never jump, lane markings, lamp posts with warm lights, planters, striped market awnings, belt rails, and silhouetted buildings past both ends and behind both sides. A **Fusion Kitchen** and an **Egg Market** at either end, so the road runs between somewhere and somewhere else.

**Game feel.** Coin flight into the purse, particle bursts scaled by rarity, camera shake, a screen flash reserved for epic-or-better, a coin counter that eases rather than snaps, incubator progress that fills, toasts that fade. Sound and picture always fire together.

**Stealing you can actually test.** Sneaky Sam and friends rob your base and run for the street's end, and the **Bubble Wand** is the counter-play — which finally makes snatching something you survive rather than something that happens to you. Philip is alone in his server, so without NPCs this half of the game was untestable (GDD 5.8 planned for exactly this).

**The theme, rebuilt and premium.** 36 bars → 66 (60 s → 113 s), scored for tin whistle, fiddle, cello, bodhrán, harp, strings, horn and bells, with a 12-bar development and a finale an octave up. Seven original sound effects, all in the theme's key so feedback never clashes with the loop. **All eight audio files are committed and one click from the game** — blocked only on an API key scope Philip has to add.

**Bugs caught before they shipped**
- `FUSION_SECONDS` is keyed by **rarity**; the service indexed it by gen, silently returning nil and using the 8-second FTUE time for every fusion in the game.
- `DataService` fired "profile loaded" before the three services that listen had subscribed, so the first player on a fresh server would have got no base at all.
- FUSE and Buy Egg were independently bottom-anchored and **overlapped on a 390-point phone screen**.
- Moving creatures detached from their anchors beyond 70 studs — every belt creature and every carried one.
- `Income.format` overflowed the HUD past 10³³.
- An incubator saved by the previous build had no `total`, which would divide by zero on the client's progress bar.

### M1 vertical slice, first half · 2026-09-16

**The loop runs.** Join, get a plot, buy an egg, watch it hatch, a Nomling lands on a pedestal and starts earning, leave, come back to your coins.

**Added**
- `Logic/Profile.luau` — the save schema and every legal mutation. `sanitize` never rejects: a corrupt profile is repaired, not refused, because refusing locks a player out of the game permanently.
- `Logic/Income.luau` — per-second and offline accrual, the same formula the economy simulator uses.
- `DataService` — DataStore wrapper with a **session lock**, atomic writes, retry with backoff, autosave and a parallel `BindToClose` flush.
- `PlotService` — plot assignment, pedestal ring, Nomling rendering (placeholder visuals; the real builder is M2a).
- `EggService` — buy and hatch. The roll happens **on claim, on the server**, never at purchase and never on the client.
- `IncomeService` — time-based coin tick, so frame rate cannot change earnings.
- `BaseHudController` — phone-first HUD: coins, egg button, incubator slots, all touch targets ≥ 56 px.
- Three remotes declared in `shared/Net` first, implemented second.
- 24 tests, including regressions for double-placement, corrupt saves and backwards clocks.

**Fixed before it ever ran**
- **stylua was checking zero files.** Built without `--features luau` it drops `.luau` from its glob and exits 0, so the format gate was green and inert since day one across CI and local runs. See D-018.
- **A service ordering bug that would have killed the slice.** `PlotService` looked for the plaza in `init()`, but `PlazaService` builds it in `start()`, and every `init` runs before any `start`. Nobody would have been given a plot and nothing would have rendered.
- `Income.format` returned a nine-character string past 10³³, overflowing the HUD.

**The starter egg, which the model assumed and the game did not.**
A new profile had 0 coins, 0 income and no way to afford the cheapest egg — soft-locked on the first screen, the exact failure `REBIRTH_GRANTS_FREE_EGG` fixes for rebirth (D-008). The economy simulator had *always* granted a free starting egg, as an unnamed line inside `simulate.py`, so every pacing number in `docs/ECONOMY.md` already depended on it. It is now `STARTER_EGG` in both config files, used by both, with the grant written as a state test (`isStranded`) so it also rescues anyone already stranded by the previous build.

**Not done yet** — the analytics funnel and the rest of the FTUE, both listed under M1 in `docs/ROADMAP.md`.

### First TEST deploy · 2026-09-16

**Shipped**
- **`Fuse a Nomling TEST` is live at version 4** with the M0 plaza. The pipeline is real: a push to `main` builds and publishes on its own.

**Fixed**
- Open Cloud permission names were wrong in `tools/opencloud.py` — it named scopes that do not exist, so a 401 sent the reader hunting for something Creator Hub never shows. Roblox's guide says `universe-places` + the **Write** operation, picked from menus.
- Removed `Swatinem/rust-cache` from both workflows. It needs a Cargo workspace, and this repo is not one, so it cached nothing and failed in its post step on every run. `~/.cargo/bin` is cached directly instead, which turns a ~2-minute Rojo build into a restore.
- Dropped the deprecated `Workspace.FilteringEnabled` from the project file.

**Added**
- A universe/place preflight in `tools/publish.py`. It needs no API key, takes a second, and catches a mistyped GitHub variable before a multi-minute build instead of after it.
- Retry with backoff on transient Open Cloud failures (~135 s across 4 attempts).
- `docs/RUNBOOKS.md` §9a — the HTTP 409 decision tree.

**The 409, honestly**
Three failed publishes over 2½ hours, all `Save failed. Server is busy`. Everything on our side was ruled out by test: the universe/place pair against Roblox's public mapping endpoint, the key (an invalid one 401s instantly, ours got past that), the built file, the content type. Then it published first try with nothing changed — so it was Roblox-side and cleared on its own. The ruled-out table is kept because it is what makes the next one a minute's work.

### Name generator (M2a, pure-logic half) · 2026-09-16

**Added**
- `src/shared/Config/Nomlings.luau` — the 12 base species with their head/tail tokens.
- `src/shared/Logic/NameGen.luau` — deterministic name generation. The whole rule is `affix + head(A) + tail(B)`, which reproduces the brief's own Sushiwal example.
- `src/shared/Config/NameSafety.luau` — multilingual profanity, brand and filter-risk blocklists, plus an allowlist.
- 12 new tests, including an exhaustive sweep of all 876 names.
- `tools/sample/names.luau` — prints a sample of what the generator produces.

**The name-safety test found a real bug on its first run.**
`Sushi` + `tiger` spells **Sushitiger** — a name that would have appeared in a reveal banner, in front of children, read aloud by the game's text-to-speech. Tiger was the only tail on the roster starting with `t`, so slot 1 became **Taco Rhino**. No human reading twelve names would have caught it.

It also exposed a flaw in the blocklist itself: "Titan" contains "tit", "shell" contains "hell". A substring list needs an allowlist to be usable, so one was added — innocent words are stripped before scanning.


### Phase 2 — M0 pipeline · 2026-09-16

**Added**
- Repo scaffold: `default.project.json`, `.luaurc`, `stylua.toml`, `selene.toml`, `wally.toml`, `rokit.toml`, committed `roblox.yml`.
- Runtime skeleton: server and client bootstraps with explicit service ordering, `NetService` with per-player token buckets, `PlazaService` (eight plots, Egg Market, Fusion Lab, spawn), shared `Economy`, `Style`, `Net`, `Odds` and `TokenBucket` modules.
- 19 unit tests under Lune, plus an economy parity test and a catalog validator.
- Open Cloud tooling: `tools/publish.py`, `tools/run-cloud-tests.py`, shared `tools/opencloud.py`.
- `tests/cloud/smoke.luau` — one task, many assertions, because task creation is capped at 5/minute per key.
- Four GitHub Actions workflows, `scripts/setup-cloud.sh`, `scripts/check.sh`.
- `CLAUDE.md`, `.claude/settings.json`, five subagents, five slash commands.
- `docs/CLOUD-SETUP.md` — everything Philip needs to paste, in one page.

**Verified by experiment**
- The whole toolchain installs from crates.io: stylua 44 s, selene 54 s, wally 69 s, rojo 101 s, lune 172 s (~7.3 min cold, cached ~1 week).
- `luau-lsp` is **not** on crates.io, so typechecking is CI-only.
- `selene generate-roblox-std` cannot run here — it ignores the proxy CA — so `roblox.yml` is committed instead.

**Fixed**
- A real Luau syntax error the linter caught: `Net.REMOTES: {...} = {}`. Luau does not allow annotating a table field assignment; it needs a typed local.
- Dead `ReplicatedStorage` require in the client bootstrap.

**Guardrails**
- `tools/publish.py` refuses PROD without `--i-have-approval`, which only the approval-gated workflow supplies.
- The economy parity test fails on a one-ppm drift, verified deliberately.
- The catalog validator rejects an odds-changing item with no disclosure metadata, and a server-wide boost that is not deterministic.

### Phase 1 — Design pack · 2026-09-16

**Added**
- Full design pack: `GDD`, `NOMLINGS`, `ECONOMY`, `MONETIZATION`, `COMPLIANCE`, `TECH`, `CONFIG`, `ANALYTICS`, `ROADMAP`, `LIVEOPS`, `MARKETING`, `STORE-PAGE`, `RUNBOOKS`, `TITLES`, `RISKS`, `DECISIONS`.
- `tools/simulate-economy/` — behaviour-model economy simulator and grid-search tuner. All four of the brief's pacing targets pass.
- `tools/revenue-model/` — revenue scenarios for 1k/10k/100k DAU, with every assumption labelled by confidence.

**Found**
- **The brief's differentiation claim is false.** Steal An Egg, the most-played game on Roblox (~1.7M CCU), already has stealing, hatching, income pets, base upgrades, a Fuse Machine and seven mutations. Repositioned on procedural generation and World First.
- **Rebirth was a dead end** — it resets coins and all Nomlings, leaving the player with no income and no bank. Fixed with a free restart egg.
- **Fusion was an infinite upgrade treadmill** — unlimited concurrent fusions made income compound geometrically. Fixed with a single fusion slot.
- **Flat egg prices broke the late game** — a heavy player reached 220 rebirths in 28 days. Fixed by scaling egg prices with rebirth count.
- The fusion name space is **876 creatures / 6,132 book entries**, not "thousands" of creatures. World First split into Species and Mutation firsts.

**Decided**
- Toolchain installs via `cargo install --locked`; `toolchain-mirror.yml` dropped.
- UI: React-Lua, with high-frequency values bypassing the reconciler. Data: ProfileStore. Both pending dependency approval.
- Title stays "Fuse a Nomling"; Taco Cat becomes Taco Tiger.
- No casino visual language anywhere — gambling imagery would force a Moderate rating and lose the Roblox Kids tier.
- Launch re-planned to 8–12 December, all-ages to January. ✅ Approved 2026-09-16, along with React-Lua and ProfileStore.

### Phase 0 — Orientation · 2026-09-16

**Added**
- `docs/00-kickoff-brief.md` — the brief, saved unchanged.
- `docs/VERIFY.md` — every claim in brief §3 checked against official sources, with URLs and dates, plus environment detection.
- `docs/PHILIP-TODO.md` — owner-only tasks.

**Found**
- Discovery ranking counts only organically-acquired users; recruitment and ranking are separate funnels.
- Audience Expansion Rewards need a 100+ DAU average for 60 days.
- "Highly engaged player" includes a platform-spend test.
- Publishing to 16+ needs only an age check, a 2-day-old account and the questionnaire.
- Private server price changes cancel every active subscription.
- The 0.0054 DevEx rate requires R15 rigs for 100% of active playtime.
- Luau Execution allows 5 task creations per minute per key.
