# ADR 0002: Native Swift/SwiftUI clients, no cross-platform UI framework

**Status:** Accepted
**Date:** 2026-09-03

## Context

Aeria's core promise is Apple-level polish. The client must integrate deeply with `NetworkExtension`, `StoreKit 2`, Keychain, App Groups, and Sign in with Apple — all platform APIs with no mature cross-platform bridge that doesn't compromise reliability or feel.

## Decision

Build all Apple clients natively in **Swift + SwiftUI**. Do not use React Native, Flutter, or any WebView-based UI for the core experience.

*(Note, 2026-09-03: the original client list here was iPhone/iPad/Mac/Apple TV. Per ADR 0007, Mac and iPhone/iPad are the near-term build targets; Apple TV is deprioritized out of the roadmap for now. The native-Swift decision itself is unaffected — if/when Apple TV is built, it follows the same reasoning.)*

## Rationale

- `NEPacketTunnelProvider` is an app-extension API; VPN state, kill switch, and on-demand rules must be rock solid — a translation/bridge layer adds failure modes in exactly the place where failure is least acceptable (the brief is explicit: "if the VPN isn't actually working, the UI must not say Protected").
- StoreKit 2, Keychain, App Groups, and Sign in with Apple are all first-class Swift APIs; cross-platform frameworks lag behind or wrap them awkwardly.
- (Historical rationale, still valid if/when built: Apple TV's focus-engine interaction model and tvOS's NetworkExtension constraints — whole-tunnel only, min tvOS 17, see `/docs/research/apple-platform-requirements.md` — are best handled with native tvOS SwiftUI, not a generic cross-platform renderer.)
- "Feels like a real Apple app" is a stated product requirement, not a nice-to-have.

## Consequences

- Higher initial per-platform engineering cost than a shared cross-platform UI, accepted deliberately.
- A shared Swift package structure (`AeriaCore`, `AeriaNetworking`, `AeriaModels`, `AeriaDesignSystem`, `AeriaVPN`, `AeriaAuthentication`, `AeriaSubscriptions`) shares business logic and design tokens across iOS/iPadOS/macOS (and tvOS, if/when built) without sharing UI rendering — see `/docs/architecture/ARCHITECTURE.md`.
- Windows client (secondary priority) will necessarily be a separate native codebase (e.g. WinUI or similar) reusing only the backend API contract and WireGuard protocol, not any Swift code.
- Platform-specific code is allowed and expected to diverge where it improves stability or UX (explicit brief instruction — no blind code sharing).
