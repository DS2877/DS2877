# Aeria — Competitive Analysis

Full research notes with sources: `/docs/research/competitor-landscape.md`. This document is the synthesized, decision-facing version.

## Competitors analyzed

NordVPN, Surfshark, ExpressVPN, Proton VPN, Mullvad, IVPN, Private Internet Access, CyberGhost.

## What every serious competitor already has (commodity — do not compete here)

WireGuard support, a kill switch, split tunneling, DNS leak protection, a published no-logs audit from a recognized firm (Deloitte/KPMG/PwC/Cure53/Securitum), a native Mac app, a 30-day refund window. A single historical audit no longer differentiates — market leaders now run **recurring annual** audits. Aeria must match this bar, not try to win on it.

## What competitors do badly (Aeria's opening)

1. **Deceptive pricing mechanics.** Steep intro-to-renewal price jumps (Surfshark cited up to 230-315% renewal increases) and App-Store-vs-direct refund confusion are near-universal complaints for NordVPN, Surfshark, ExpressVPN, PIA, CyberGhost.
2. **Mediocre Mac experiences specifically.** Mullvad's Mac app is menu-bar-only with no full window — the exact platform Aeria is prioritizing most (`/docs/architecture/adr/0007-platform-sequencing.md`) is one where even a respected privacy-purist competitor under-delivers.
3. **Upsell fatigue.** Bundled antivirus/password-manager/identity-theft add-ons pushed via email and in-app nags (Surfshark, NordVPN) annoy users who just want a VPN.
4. **Speed inconsistency on less-popular servers**, recurring theme for CyberGhost, PIA, Proton on distant regions.
5. **Narrow platform reach from the privacy-purist camp** — Mullvad and IVPN have neither an Apple TV app nor, in Mullvad's case, a genuinely full-featured Mac app, forcing privacy-conscious users to choose between "trust the provider" and "works well with my devices across the board."

## The market splits into two camps

- **Mainstream generalists** (Nord, Surfshark, ExpressVPN, CyberGhost, PIA): broad platform coverage, large server networks, aggressive marketing, but commodity trust and pricing tactics that erode it.
- **Privacy-purist minimalists** (Mullvad, IVPN): excellent trust posture (flat pricing, minimal data collection, audited) but neglected platform craft (menu-bar-only Mac apps) and narrower device reach than the mainstream camp.

**Nobody currently owns the intersection**: Mullvad/IVPN-grade privacy discipline + genuinely native, platform-idiomatic craft (starting with a real, full-featured Mac app — not a menu-bar utility) + the broad, "works on whatever you own" device reach of the mainstream camp + transparent, non-manipulative pricing. Aeria is explicitly not positioning itself as narrow like Mullvad/IVPN — the goal is broad device availability (Mac and iPhone first, Windows and Android close behind) built with the craft neither camp currently delivers (`/docs/architecture/adr/0007-platform-sequencing.md`).

## What Aeria will NOT try to win on

- Server/country count (Nord, Surfshark, CyberGhost already dominate this; commodity metric, diminishing marginal value to the target customer).
- Feature breadth / bundling (antivirus, password managers, identity monitoring — explicitly excluded from MVP, see `/docs/product/PRODUCT_REQUIREMENTS.md`).
- Discount-driven acquisition (steep multi-year teaser pricing that renews high is precisely the pattern Aeria's positioning rejects).

## Where Aeria differentiates

1. **Mac-first craft** — a real, full-featured native Mac app (not menu-bar-only), built alongside iPhone from day one, not a port added later (`/docs/architecture/adr/0007-platform-sequencing.md`).
2. **Broad reach without sacrificing craft** — Mac and iPhone first, Windows and Android as committed fast-follow rather than indefinitely deferred, so Aeria doesn't trap itself in Apple-only narrowness the way the privacy-purist camp traps itself in small platform footprints.
3. **Honest, simple pricing** — no bait-and-switch renewal jump; whatever price is shown is close to the price paid long-term (final pricing model in `/docs/business/unit-economics.md`).
4. **Trust through minimal data collection, architecturally** — not just a policy promise (see `/docs/security/data-collection.md`), backed by a public commitment to recurring independent audits once Aeria has the revenue to fund them (post-MVP; see `/docs/product/ROADMAP.md`).
5. **Design restraint** — no dashboards, no giant stat screens, no "99 features" — matching the whitespace of "trust + craft" that neither camp currently owns simultaneously.

## Direct implication for MVP scope

Confirms `/docs/product/PRODUCT_REQUIREMENTS.md`'s MVP boundary: launch with a small, premium server footprint (not 50+ countries), Mac and iPhone/iPad first with Windows/Android close behind (not Apple-only indefinitely, not tvOS-led), and resist the urge to bundle features competitors use to justify higher price points — Aeria's premium price is justified by craft and trust, not feature count.
