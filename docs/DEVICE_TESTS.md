# DEVICE TESTS

Actual device results. Nothing here is filled in without a real observation.

| # | Date | Device | iOS | Channel | Result | Notes |
|---|---|---|---|---|---|---|
| 1 | 2026-11-12 | iPhone 15 Pro | 27.2 | LiveContainer + SideStore 3.8.8, free Apple ID | **PASS** | Owner confirmed install + launch; app works |

## Confirmed by the owner (2026-11-12)

- [x] Install via LiveContainer succeeded
- [x] App launches on iPhone 15 Pro / iOS 27.2
- [x] Owner states the app works

**This closes gate A**: at least one real install and launch through the agreed channel.

## Environment

| Field | Value |
|---|---|
| Device | iPhone 15 Pro |
| iOS | 27.2 |
| Installer | LiveContainer + SideStore 3.8.8 |
| Apple ID | Free personal team |
| Build | `ChatWars-unsigned.ipa`, bundle `com.chatwars.game`, arm64, min iOS 15.0 |
| Renderer | Compatibility (`gl_compatibility`) |

The Compatibility renderer choice carried an open `UNVERIFIED` from stage A ("docs only claim
Simulator support"). It now boots and runs on this physical device. That is evidence for
**this device and iOS version only** — not a claim about other hardware.

## Not yet separately confirmed

The confirmation was brief, so these remain open and are re-checked in the MVP device pass:

- [ ] Counter increments visibly on tap
- [ ] Counter survives a full app close and relaunch (save persistence)
- [ ] Airplane mode: app still functional
- [ ] Language toggle switches ru ↔ en on device
- [ ] Screenshot on file

A screenshot is useful evidence but does **not** substitute for the persistence check.

## Installation (LiveContainer)

1. Get the unsigned IPA from the CI artifact (`ChatWars-unsigned-ipa`).
2. Import it into LiveContainer as a guest app.
3. Let LiveContainer re-sign and install it.
4. Launch and run the checklist above.

LiveContainer and SideStore/AltStore each need their own host signature and periodic
refresh; JIT-less mode does not remove that requirement. Guest app permissions are shared
and guest data is not fully isolated — do not store secrets in the game.

## Not yet attempted

- Direct sideload of our own game (allowed fallback; not needed — LiveContainer works).
- Crash log collection (no crash observed).

