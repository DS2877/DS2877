# Research Notes: VPN Competitor Landscape

**Date researched:** 2026-09-03
**Method:** Web search against official pricing pages, App Store listings, published audit reports, and review-aggregator sites where official sources were unreachable (noted inline).
**Status:** Primary-source where possible; several server-count and renewal-price figures are review-aggregator sourced (flagged below). Re-verify exact figures against provider trust centers before using in external-facing (marketing/legal) materials — this document is an internal research input, not a citable external claim.

---

## Pricing & Plans

| Provider | Monthly (no commitment) | Best long-term effective/mo | Family plan | Source |
|---|---|---|---|---|
| NordVPN | $14.99–$29.99 (Basic→Prime) | $3.49–$7.49 (2-yr) | No dedicated SKU; up to 10 devices | nordvpn.com/blog |
| Surfshark | $16.45–$21.85 (Starter→One+) | $2.49–$4.49 (2-yr, intro) | No separate tier; unlimited simultaneous devices on every plan | cybernews.com |
| ExpressVPN | $15.99–$22.99 (Basic→Pro) | $2.49–$5.49 (2-yr, intro) | No; 5–14 devices depending on tier | cybernews.com, expressvpn.com |
| Proton VPN | $9.99 (Plus) / $12.99 (Unlimited) | $2.99/mo (Plus, 2-yr) / $7.99 (Unlimited, 2-yr) | Proton Family: up to 6 users, ~$23.99–29.99/mo | cybernews.com, insight-ict.eu |
| Mullvad | €5/mo flat — no tiers, no discounts, no renewal hike | €5/mo (same at 1mo or 10yr) | No | mullvad.net/pricing |
| IVPN | $6 (Standard) / $10 (Pro) | $5/mo (Standard, annual) / $8.33 (Pro, annual) | No | costbench.com |
| PIA | $11.95–$11.99 | ~$2.03–$2.19/mo (2-yr, heavily promo'd) | No | security.org |
| CyberGhost | $12.99 | ~$2.03/mo (2-yr+3mo free, intro) | No | security.org |

Note: Nord/Surfshark/ExpressVPN/PIA/CyberGhost long-term rates are heavily promo-driven and third-party-aggregated. Mullvad and Proton figures are the most independently verifiable (flat price / official-adjacent sources). NordVPN's own pricing page returned 403 to automated fetch in this session.

## Platform, Protocol & Trust

| Provider | Apple TV native app | Mac app quality | Protocols | No-logs audit | Kill switch / split tunnel |
|---|---|---|---|---|---|
| NordVPN | Yes (native tvOS) | Native, Apple Silicon optimized, menu bar | NordLynx (WireGuard-based), OpenVPN | Deloitte, 6 engagements since 2018, latest Dec 2025 (ISAE 3000) | Yes / Yes |
| Surfshark | Yes | Native, dark mode, menu bar quick-connect | WireGuard, OpenVPN | Deloitte, 2023 & 2025 | Yes / Yes |
| ExpressVPN | Yes (no split tunneling on tvOS — Apple sandbox limit) | Native | Lightway (proprietary, Cure53-audited), WireGuard, OpenVPN | KPMG (3rd time 2025) + PwC 2019 + Cure53 (Lightway, 2022) | Yes / Yes (except tvOS) |
| Proton VPN | Yes (launched Oct 2024, tvOS 17+, WireGuard) | Native, fully open-source | WireGuard, OpenVPN | Securitum, 5 consecutive annual audits, latest Aug 2025 | Yes / Yes |
| Mullvad | No | Native but menu-bar-only, no full window mode | WireGuard, OpenVPN | Cure53 (infra, 4th audit June 2024) + Assured (web app) | Yes / Yes |
| IVPN | No (router-level workaround only) | Native | WireGuard, OpenVPN | Independent audits since 2019 (Cure53/others) | Yes / Yes |
| PIA | Yes | Native | WireGuard, OpenVPN | Deloitte, 2022 & 2024 (infra), Jan 2025 | Yes / Yes |
| CyberGhost | Yes | Native | WireGuard, OpenVPN | Deloitte Romania, 3x (2022, 2024, Q4 2025) | Yes / Yes |

Server networks (approximate, varies by source): NordVPN ~5,200–7,800 servers/60–118 countries; Surfshark ~4,500/100; ExpressVPN 214 locations/113 countries (official, Jul 2026); Proton VPN ~8,500–15,000+/112–126+; Mullvad 569 servers/50 countries (official, live count); IVPN 165/37; PIA 10,000+/91; CyberGhost 11,500+/100.

## Sentiment Themes (aggregated, not individually verified)

- **NordVPN** — strong ratings; recurring complaints: auto-renewal surprise charges, renewal price jumps, App Store refund friction.
- **Surfshark** — aggressive upsell emails, renewal spikes (~230–315% cited), occasional split-tunnel bugs; broadly high satisfaction.
- **ExpressVPN** — praised for reliability (4.7★ App Store); "pricey" dominant complaint even after 2026 cuts.
- **Proton VPN** — trust/transparency praised; complaints: speed on distant servers, no smart DNS, support only Swiss business hours.
- **Mullvad** — "most privacy-serious"; complaints: growing pains, CAPTCHA friction, menu-bar-only Mac app feels limited for non-technical users.
- **IVPN** — privacy audience satisfied with transparency; smallest network and no Apple TV app are recurring gaps.
- **PIA/CyberGhost** — value-priced, large networks; degraded speed on distant/unpopular servers; "friendly but unhelpful" support; steep multi-year discounting that renews high.

## Brand Positioning

- **NordVPN** — mainstream, marketing-heavy, broad bundling (Threat Protection, password manager).
- **Surfshark** — value + unlimited devices, aggressive bundling (antivirus, alt-ID).
- **ExpressVPN** — premium/simplicity, proprietary Lightway protocol, strong audit cadence.
- **Proton VPN** — Swiss privacy + full ecosystem (Mail/Drive/Pass/Calendar), open-source apps.
- **Mullvad** — radical minimalism: flat pricing, anonymous numbered accounts, no email required.
- **IVPN** — privacy-purist niche, ethical business practices (subscription reminders, discourages over-subscribing).
- **PIA** — budget/large-network, Kape-owned.
- **CyberGhost** — budget/streaming-unblock focus, Kape-owned sibling to PIA/ExpressVPN.

## Synthesis

**1. Commodity now (table stakes, not differentiators):** WireGuard support, kill switch, split tunneling, DNS leak protection, a published no-logs audit from a recognized firm, a native Mac app, 30-day refund window. A one-off audit is no longer impressive — leaders now run *recurring annual* audits.

**2. Common complaints a premium Apple-native product could fix:**
- Deceptive pricing mechanics (steep intro-to-renewal jumps, App Store refund confusion) — nearly universal across mainstream players.
- Mediocre non-primary-platform experiences (Mullvad Mac app is menu-bar-only; ExpressVPN drops split tunneling on tvOS; several tvOS apps are afterthought ports, not focus-engine-idiomatic).
- Upsell fatigue (bundled antivirus/password-manager/ID-theft add-ons pushed via email and in-app nags).
- Speed inconsistency on less-popular servers.
- No Apple TV app at all for the two most privacy-purist brands (Mullvad, IVPN).

**3. Whitespace for Aeria:** No competitor combines (a) Mullvad/IVPN-grade minimalist privacy ethos + audit rigor, (b) a truly native, platform-idiomatic app on every Apple surface including a first-class tvOS focus-engine UI and a full (not menu-bar-only) native Mac app, and (c) transparent, non-manipulative pricing with no bait-and-switch renewal jump. The market splits into marketing-heavy generalists (commodity trust, murky pricing, broad platform coverage) vs. privacy-purist minimalists (excellent trust, neglected non-desktop platforms, no interest in ecosystem polish). Aeria's opening: Apple-ecosystem-first, trust + craft, honest pricing — not a server-count or streaming-unblock race.

**Confidence notes:** Mullvad pricing/servers, Proton's Family plan and Apple TV launch are the most directly source-verified. Server-count and renewal-price figures for Nord/Surfshark/ExpressVPN/PIA/CyberGhost rely partly on secondary/aggregator sources — re-verify against official trust centers before external use.
