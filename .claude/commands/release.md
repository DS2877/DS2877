---
description: Prepare a PROD release (does not publish)
---

**This command never publishes.** PROD publishing requires Philip's explicit approval through the `production` GitHub Environment gate (brief §11.3).

Prepare the release:

1. Confirm `main` is green and TEST has been played on a phone since the last change.
2. Draft the `CHANGELOG.md` entry from the commits since the last tag.
3. Run through the launch checklist in `docs/STORE-PAGE.md` §7 and report anything unticked.
4. Check `docs/COMPLIANCE.md` §9 — has anything shipped that changes a questionnaire answer? If so, the questionnaire must be resubmitted first.
5. Propose the version tag and show Philip exactly what tagging it would do.

Then **stop** and wait for his go-ahead.
