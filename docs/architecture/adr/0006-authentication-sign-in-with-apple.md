# ADR 0006: Sign in with Apple as the sole MVP authentication method

**Status:** Accepted
**Date:** 2026-09-03

## Context

The brief wants minimal account friction and lists Sign in with Apple as primary, with email/magic link/device activation as things to investigate. App Store Guideline 4.8 ("Login Services") research: `/docs/research/apple-platform-requirements.md`.

## Decision

MVP ships with **Sign in with Apple only**. No email/password, no other social login, no separate device-activation flow at launch.

## Rationale

- Guideline 4.8 only triggers an "equivalent option" requirement when a **third-party/social login** is offered for the primary account. Offering *only* Sign in with Apple avoids 4.8 entirely — there's no other social login to need an equivalent for, and no email/password system to build, secure, and support (password resets, credential-stuffing exposure, support burden) before launch.
- Directly serves "minimize account friction": one tap, no password to create or remember, biometric-backed by the OS.
- Matches the brief's Apple-first philosophy and reduces MVP surface area (fewer auth failure modes = fewer kill-switch/session edge cases to test).

## Consequences

- Aeria is fully dependent on Apple ID availability; a user without an Apple ID cannot sign up. Acceptable for an Apple-ecosystem-first MVP; revisit if Windows (secondary platform) launch data shows this is a blocker.
- Email/password or magic-link login is deferred to a post-MVP phase, and if added later, must be evaluated against 4.8 again at that time (adding *any* other social login, e.g. Google, would then require offering an Apple-equivalent option too — already satisfied since Sign in with Apple would already exist).
- Device management (`/docs/product/PRODUCT_REQUIREMENTS.md`) is keyed off the Apple ID-derived stable user identifier plus a per-device registration record, not a separate account system.
