# Aeria — App Store Release Checklist

Grounded in `/docs/research/apple-platform-requirements.md` (live-fetched Apple primary sources, 2026-09-03). Re-verify against current guidelines immediately before actual submission (Phase 7, `/docs/product/ROADMAP.md`) — policy can change between now and then.

## Account & entitlements

- [ ] **Organization-type Apple Developer Program account** — mandatory for VPN apps per Guideline 5.4; an individual account cannot submit Aeria.
- [ ] `com.apple.developer.networking.networkextension` entitlement with `packet-tunnel-provider` value, on both the container app and the tunnel-provider extension target(s).
- [ ] App Groups entitlement (`com.apple.security.application-groups`) for container-app ↔ extension shared state.
- [ ] Confirm entitlement is genuinely self-service per current developer portal (TN3134 implies no manual approval gate as of research date — verify this hasn't changed).
- [ ] *(Deferred with Apple TV itself — ADR 0007)* tvOS extension target `productType` set to `com.apple.product-type.app-extension` (known build-config gotcha, not the tv-specific extension type) — relevant only if/when Apple TV is built.

## Guideline 5.4 (VPN Apps) compliance

- [ ] Uses `NEVPNManager`/`NETunnelProviderManager` API (not a workaround).
- [ ] In-app disclosure screen, shown **before** any purchase or use action, clearly stating what user data is collected and how it's used — matches `/docs/security/data-collection.md` exactly.
- [ ] Privacy Policy explicitly commits to never selling, using, or disclosing user data to third parties for any purpose.
- [ ] Per-territory VPN license information declared in App Review Notes, for any launch territory that requires one (research existing territory requirements as part of `/docs/product/PRODUCT_REQUIREMENTS.md` §Server locations finalization).

## Guideline 4.8 (Login Services)

- [ ] Confirm MVP ships Sign in with Apple as the *only* login method (ADR 0006) — if this changes (e.g., email/password added) before submission, re-check whether any *other* third-party social login has also been added, which would newly trigger the "equivalent option" requirement.

## Privacy Nutrition Label

- [ ] App Store Connect Privacy Nutrition Label answers must match `/docs/security/data-collection.md` precisely — no under- or over-disclosure.
- [ ] Legal/product sign-off that the label, the in-app 5.4 disclosure screen, and the Privacy Policy are all consistent with each other.

## Subscriptions

- [ ] StoreKit 2 products configured in App Store Connect (monthly, annual; family deferred).
- [ ] Free trial (7 days, recommendation per `/docs/business/unit-economics.md`) configured as an introductory offer.
- [ ] Server-side verification via App Store Server API live and tested (never trust client-only state — `/docs/architecture/ARCHITECTURE.md` §3).
- [ ] Restore purchases flow tested.
- [ ] Grace period, cancellation, and refund handling tested against real App Store Server Notifications V2 events (sandbox first, then TestFlight).

## Account deletion

- [ ] In-app account deletion flow present and functional (Apple requires this for any app supporting account creation) — ties to `/docs/security/data-collection.md` retention/deletion commitments.

## Metadata & assets

- [ ] App icon, screenshots (selling the experience, not technical feature lists — brief §61), subtitle, description, keywords, promotional text drafted from `/docs/business/positioning.md` and reconciled with actual shipped features before submission.

## Process

- [ ] TestFlight: private alpha (5-20) → closed beta (50-200) → public beta (500-2,000), per `/docs/product/ROADMAP.md`.
- [ ] App Review submission with complete, accurate App Review Notes (VPN licensing, demo account if needed for reviewers to test the VPN connection itself).
- [ ] Phased release enabled for production rollout; monitoring plan in place (`/docs/product/PRODUCT_REQUIREMENTS.md` §Target metrics) before, during, and after rollout.

## Explicit re-verification note

Every checkbox above that references a specific Apple policy (5.4, 4.8, entitlement self-service status, StoreKit mechanics) is grounded in research performed 2026-09-03. Apple's guidelines and StoreKit APIs change between WWDC cycles — this checklist must be re-validated against live Apple documentation immediately before Phase 7 submission, not trusted as permanently current.
