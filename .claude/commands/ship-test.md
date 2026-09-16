---
description: Validate and publish the current branch to TEST
---

1. Run `./scripts/check.sh`. If anything fails, stop and fix it — do not publish a red build.
2. Build the place with Rojo.
3. Publish to TEST as a **Saved** version (`tools/publish.py --env test --type Saved`).
4. Run the cloud smoke test against that version.
5. Report the version number and a 3-minute phone playtest script.

If `ROBLOX_API_KEY` or the TEST universe/place IDs are missing, stop and say exactly which one, pointing at `docs/PHILIP-TODO.md`. Never guess an ID.
