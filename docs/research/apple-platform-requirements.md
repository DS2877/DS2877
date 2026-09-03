# Research Notes: Apple Platform Requirements for VPN Apps

**Date researched:** 2026-09-03
**Method:** Direct fetch of Apple primary sources (developer.apple.com doc pages, Technotes, live App Store Review Guidelines) plus targeted secondary corroboration where noted.

---

## 1. NetworkExtension / Packet Tunnel Provider

- **API**: `NEPacketTunnelProvider` is the app-extension class for custom-protocol VPN clients; `NETunnelProviderManager` configures/controls it from the container app.
  Source: https://developer.apple.com/documentation/networkextension/nepackettunnelprovider
- **Entitlement**: `com.apple.developer.networking.networkextension` with value(s) including `packet-tunnel-provider`. Both the container app and the extension need it. Related values: `app-proxy-provider`, `content-filter-provider`, `dns-proxy`, plus Developer-ID/system-extension variants (`*-systemextension`).
  Source: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.networkextension
- **Approval**: Packet tunnel and app-proxy providers are **self-service** (enabled via Xcode/developer portal, no manual Apple approval gate). Apple's Tech Note TN3134 ("Deploying Network Extension Providers," updated 2025-08-19) explicitly calls out manual-approval requirements only for Family Controls (Screen Time) and Hotspot Helper entitlements — silent on packet-tunnel-provider/app-proxy-provider, implying no gate for those.
  Source: https://developer.apple.com/documentation/Technotes/tn3134-network-extension-provider-deployment
  *(Historical pre-2016 "managed approval" narrative is forum/blog-sourced, not an Apple primary statement — consistent with TN3134's current silence, but not independently confirmed.)*
- **TN3134 deployment table** (primary source) for packet tunnel provider:
  - iOS — app extension, min OS 9.0, per-app mode requires managed device
  - macOS — app extension, min OS 10.11, App Store only (or system extension, min OS 10.15)
  - Mac Catalyst — min OS 10.15, App Store only
  - **tvOS — app extension, min OS 17.0, per-app mode NOT supported**
  - visionOS — app extension, min OS 1.0, per-app mode NOT supported
- **App Groups**: standard `com.apple.security.application-groups` + shared `UserDefaults(suiteName:)`/shared container is the general Apple mechanism for container-app ↔ extension data sharing. Not independently re-verified against a NetworkExtension-specific doc page — flag for follow-up before treating as load-bearing.

## 2. tvOS VPN Support — RESOLVED

**tvOS supports third-party packet-tunnel VPN as of tvOS 17.0** (2023+), packaged as an app extension, **whole-device tunnel only** — per-app VPN mode is explicitly unsupported. Pre-tvOS-17 has no NetworkExtension VPN at all.
Source: https://developer.apple.com/documentation/Technotes/tn3134-network-extension-provider-deployment

Known build-config gotcha (secondary/forum source): the tvOS extension target's `productType` must be `com.apple.product-type.app-extension`, not a tv-specific app-extension type.
Source: https://developer.apple.com/forums/thread/738007

**Implication for Aeria**: Apple TV VPN is real and technically supported now, but full-tunnel only (no per-app split tunneling on tvOS) and requires tvOS 17+ as the minimum deployment target.

## 3. App Store Review Guidelines — Guideline 5.4 "VPN Apps" (verbatim, live-fetched)

> "Apps offering VPN services must utilize the NEVPNManager API and may only be offered by developers enrolled as an organization. You must make a clear declaration of what user data will be collected and how it will be used on an app screen prior to any user action to purchase or otherwise use the service. Apps offering VPN services may not sell, use, or disclose to third parties any data for any purpose, and must commit to this in their privacy policy. VPN apps must not violate local laws, and if you choose to make your VPN app available in a territory that requires a VPN license, you must provide your license information in the App Review Notes field. Parental control, content blocking, and security apps, among others, from approved providers may also use the NEVPNManager API. Apps that do not comply with this guideline will be removed from the App Store and blocked from installing via alternative distribution and you may be removed from the Apple Developer Program."

Source: https://developer.apple.com/app-store/review/guidelines/#5.4

**Architecture implications:**
- **Organization-type Apple Developer Program account is mandatory** — Aeria cannot ship under an individual developer account.
- **In-app pre-purchase disclosure screen is required**, distinct from the App Store Connect Privacy Nutrition Label (general app-wide questionnaire: https://developer.apple.com/app-store/app-privacy-details/).
- No sell/use/disclose-to-third-parties commitment must appear in the privacy policy.
- Per-territory VPN licensing (if applicable) must be declared in App Review Notes.

## 4. StoreKit 2 / App Store Server API

- StoreKit 2 (`Transaction`, `Product`, `AppTransaction`) auto-validates JWS-signed transaction receipts client-side.
- **App Store Server API** (JWT-authenticated) provides `getAllSubscriptionStatuses` and transaction/history endpoints for authoritative **server-side** verification, plus App Store Server Notifications V2 for renewal/refund webhooks. This is the current recommended path for a subscription backend that must never blindly trust client state.
  Reference: WWDC25 session — https://developer.apple.com/videos/play/wwdc2025/241/
- Free trials/intro offers: configured in App Store Connect subscription-group setup, consumed via `Product.subscription.introductoryOffer`. **Not independently re-fetched against a primary doc page — spot-check before implementation.**

## 5. Sign in with Apple

Guideline **4.8 "Login Services"** (live-fetched, current text) does **not** name Sign in with Apple specifically. It requires: if a third-party/social login (Facebook, Google, etc.) is offered for a **primary account**, an equivalent option meeting three privacy criteria must also be offered (name+email-only data collection, private-email relay option, no ad-tracking without consent). Sign in with Apple satisfies this but is not the *only* way to satisfy it.

**Email/password-only apps (no third-party social login at all) are unaffected by 4.8** — it only triggers when a third-party/social login is offered.

Source: https://developer.apple.com/app-store/review/guidelines/#4.8
(Corroborates the Jan 2024 relaxation reported by 9to5mac: https://9to5mac.com/2024/01/27/sign-in-with-apple-rules-app-store/)

**Implication**: Aeria can ship Sign in with Apple as the *only* login method (simplest, no 4.8 exposure) or add email/password without triggering 4.8, as long as no other third-party social login is added.

## 6. WireGuard on Apple Platforms — Licensing RESOLVED

- **`github.com/WireGuard/wireguard-apple`** (mirror of `git.zx2c4.com/wireguard-apple`) is the official reference NetworkExtension implementation: `WireGuardKit` (Swift) for `NEPacketTunnelProvider` integration + a Go-based `wireguard-go` userspace core via `libwg`.
- **License (confirmed from repo `COPYING` file): MIT** — "Copyright © 2018-2023 WireGuard LLC. All Rights Reserved" + standard MIT permission text. Fully permissive, no copyleft, commercial use allowed with attribution retained.
- `wireguard-go` is separately MIT-licensed.
- **Nuance**: GPL2 applies only to the **Linux kernel module**. The Apple/Go userspace stack used on iOS/macOS is MIT and safe for a closed-source commercial app — consistent with production use by ProtonVPN, PIA, etc. (their own forks are also MIT: github.com/ProtonVPN/wireguard-apple, github.com/pia-foss/mobile-ios-wireguard).

---

## Flags / Not Fully Primary-Source-Verified (follow up before implementation)
- App Groups requirement specifics for NetworkExtension data sharing.
- Exact StoreKit 2 free-trial/introductory-offer configuration mechanics.
- Historical pre-2016 NetworkExtension entitlement approval process (irrelevant today given TN3134's current self-service framing, kept for context only).
