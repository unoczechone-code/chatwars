# DEVICE TESTS

Actual device results. Nothing here is filled in until a real iPhone ran the build.

| # | Date | Device | iOS | Channel | Result | Notes |
|---|---|---|---|---|---|---|
| — | — | — | — | — | **NOT RUN** | Awaiting first IPA + device info |

## Pending: what to verify on the device

Per §A3. Each row must be answered by observation, not assumption.

- [ ] App opens (not just installs)
- [ ] Button increments the counter
- [ ] Close and reopen the app → counter value persists
- [ ] Airplane mode → app still works (offline-only)
- [ ] Language toggle switches ru ↔ en
- [ ] Record model, iOS version, LiveContainer version, date

A screenshot is useful evidence but does **not** substitute for the persistence check.

## Installation (LiveContainer)

1. Get the unsigned IPA from the CI artifact (`ChatWars-unsigned-ipa`).
2. Import it into LiveContainer as a guest app.
3. Let LiveContainer sign and install it.
4. Launch and run the checklist above.

LiveContainer and SideStore/AltStore each need their own host signature and periodic
refresh; JIT-less mode does not remove that requirement. Guest app permissions are shared
and guest data is not fully isolated — do not store secrets in the game.

## Not yet attempted

- Direct sideload of our own game (allowed fallback if LiveContainer is incompatible).
- Crash/import log collection (no build has been installed yet).
