# Aeria — Competitive Analysis

Full research notes with sources: `/docs/research/competitor-landscape.md`. This document is the synthesized, decision-facing version.

## Competitors analyzed

NordVPN, Surfshark, ExpressVPN, Proton VPN, Mullvad, IVPN, Private Internet Access, CyberGhost.

## What every serious competitor already has (commodity — do not compete here)

WireGuard support, a kill switch, split tunneling, DNS leak protection, a published no-logs audit from a recognized firm (Deloitte/KPMG/PwC/Cure53/Securitum), a native Mac app, a 30-day refund window. A single historical audit no longer differentiates — market leaders now run **recurring annual** audits. Aeria must match this bar, not try to win on it.

## What competitors do badly (Aeria's opening)

1. **Deceptive pricing mechanics.** Steep intro-to-renewal price jumps (Surfshark cited up to 230-315% renewal increases) and App-Store-vs-direct refund confusion are near-universal complaints for NordVPN, Surfshark, ExpressVPN, PIA, CyberGhost.
2. **Mediocre non-primary-platform experiences.** Mullvad's Mac app is menu-bar-only with no full window; ExpressVPN drops split tunneling on tvOS (Apple sandbox constraint); most tvOS apps are ports, not focus-engine-idiomatic native experiences.
3. **Upsell fatigue.** Bundled antivirus/password-manager/identity-theft add-ons pushed via email and in-app nags (Surfshark, NordVPN) annoy users who just want a VPN.
4. **Speed inconsistency on less-popular servers**, recurring theme for CyberGhost, PIA, Proton on distant regions.
5. **No Apple TV app at all** from the two most privacy-purist brands (Mullvad, IVPN) — forcing privacy-conscious users to choose between "trust the provider" and "works well with my devices."

## The market splits into two camps

- **Mainstream generalists** (Nord, Surfshark, ExpressVPN, CyberGhost, PIA): broad platform coverage, large server networks, aggressive marketing, but commodity trust and pricing tactics that erode it.
- **Privacy-purist minimalists** (Mullvad, IVPN): excellent trust posture (flat pricing, minimal data collection, audited) but neglected non-desktop platforms and no interest in ecosystem polish.

**Nobody currently owns the intersection**: Mullvad/IVPN-grade privacy discipline + genuinely native, platform-idiomatic craft across the entire Apple ecosystem (including a first-class tvOS experience and a full native Mac app, not a menu-bar utility) + transparent, non-manipulative pricing.

## What Aeria will NOT try to win on

- Server/country count (Nord, Surfshark, CyberGhost already dominate this; commodity metric, diminishing marginal value to the target customer).
- Feature breadth / bundling (antivirus, password managers, identity monitoring — explicitly excluded from MVP, see `/docs/product/PRODUCT_REQUIREMENTS.md`).
- Discount-driven acquisition (steep multi-year teaser pricing that renews high is precisely the pattern Aeria's positioning rejects).

## Where Aeria differentiates

1. **Apple-ecosystem craft** — a genuinely native app on every Apple surface, tvOS treated as a first-class citizen from day one (technically feasible since tvOS 17, per `/docs/research/apple-platform-requirements.md`), a real Mac app (not menu-bar-only).
2. **Honest, simple pricing** — no bait-and-switch renewal jump; whatever price is shown is close to the price paid long-term (final pricing model in `/docs/business/unit-economics.md`).
3. **Trust through minimal data collection, architecturally** — not just a policy promise (see `/docs/security/data-collection.md`), backed by a public commitment to recurring independent audits once Aeria has the revenue to fund them (post-MVP; see `/docs/product/ROADMAP.md`).
4. **Design restraint** — no dashboards, no giant stat screens, no "99 features" — matching the whitespace of "trust + craft" that neither camp currently owns simultaneously.

## Direct implication for MVP scope

Confirms `/docs/product/PRODUCT_REQUIREMENTS.md`'s MVP boundary: launch with a small, premium server footprint (not 50+ countries), Apple platforms only, and resist the urge to bundle features competitors use to justify higher price points — Aeria's premium price is justified by craft and trust, not feature count.
