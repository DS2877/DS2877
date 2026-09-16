---
description: Generate a 3-minute phone playtest script for the current branch
---

Write a playtest script Philip can run on his iPhone in **3 minutes or less**.

Look at what actually changed on this branch (`git diff main...HEAD`), then write:

1. **Setup** — which place to open (TEST unless told otherwise), and anything to reset first.
2. **Steps** — numbered, each one a single physical action with the expected result. No step may need Studio, a second device or a second player. If the change is PvP, say which NPC or scripted stand-in exercises it.
3. **What would prove it broken** — the specific wrong outcome to watch for, not "check it works".
4. **Screenshot request** — exactly one shot that would tell Claude the most, since screenshots are the only way Claude sees the game.

Time the steps honestly. If it cannot be tested in 3 minutes, say so and cut scope rather than writing a 10-minute script.
