## Stage

**Stage C — MVP implemented, build produced. Device playtest pending.**

## Done

- [x] Stage A closed: installed and launched on iPhone 15 Pro / iOS 27.2 via
      LiveContainer + SideStore 3.8.8 (free Apple ID).
- [x] Stage B (PCK hot-swap) deliberately skipped by the owner's direction: not needed
      while full CI builds cost ~2 minutes. `tools/swap_pck.py` and its 18 tests remain
      available but are not on the critical path.
- [x] MVP gameplay implemented in `game/scripts/`:
      180s run, 3 waves, boss at 120s, 3 enemy kinds + boss, auto-attack, drag movement,
      AoE button, pause, 6 upgradable stats with stack caps, 5 screens, ru/en,
      best score / wins / settings persistence.
- [x] CI run 43222755789 green (macos-26, Xcode 26.6). Artifact verified: arm64,
      UIDeviceFamily=[1], PCK sha256 matches manifest, all 17 scripts/scenes present
      inside the packed PCK.
- [x] Tests: smoke, gameplay (24), UI flow (19), soak (full 180s run + cap enforcement
      + no leaks) — all green; swap_pck 18/18.

## Bugs the tests caught (all fixed)

1. The upgrade prompt freed the running game, so every pick destroyed the run.
   The run is now detached and restored as the same instance.
2. A pending upgrade at 120s suppressed the boss spawn.
3. Pause button was 31pt tall — below the 44pt touch minimum.
4. Runs could start paused if the previous one ended on an upgrade.

## Blockers

None technically. Needs a device playtest to judge balance and confirm the new build runs.

## Next single step

Owner installs `ChatWars-MVP.ipa` and plays one full run; then tune `balance.gd`.

- [x] Environment verified: Godot 4.7.2.stable.official.ed1daf0bf present and runs; `gh` installed
      (2.103.3, SHA-256 verified); Python 3.12; git 2.56.1.
- [x] GitHub auth re-checked: `gh` absent → installed; SSH key rejected by GitHub;
      GCM has a github.com entry but it is **expired/inaccessible non-interactively**
      (`Cannot prompt because user interactivity has been disabled`), so no working auth.
- [x] Minimal Godot project (`game/`) — title, counter button, version label, ru/en, icon.
- [x] `SaveManager` autoload: versioned JSON, sanitization, atomic tmp→bak→replace,
      corrupt-file quarantine.
- [x] Headless import: clean, zero errors.
- [x] Smoke test `tests/smoke_test.gd`: **17/17 pass**.
- [x] iOS preset `game/export_presets.cfg` — field names taken from the engine's own
      `--doctool` output for 4.7.2, not guessed.
- [x] `--export-pack "iOS"` on Windows: exit 0, PCK produced (22.7 KB).
- [x] `.github/workflows/ios.yml` — 13 steps, valid YAML, no secrets, `macos-26`.
- [x] `tools/swap_pck.py` + `tests/test_swap_pck.py`: **18/18 pass**.
- [x] Docs: TOOLCHAIN, BUILD, SIGNING, DEVICE_TESTS, QA, README, CREDITS, godot LICENSE.

## In progress

- GitHub device login started twice; both codes expired before use. Needs the human.

## Blockers

1. **GitHub authentication** — device-code login needs the owner to open
   https://github.com/login/device and enter the code. Without it: no repo, no push, no CI,
   no IPA. This is the only thing preventing Stage A2 completion.
2. **iPhone details** — model, exact iOS version, LiveContainer/SideStore/AltStore presence,
   free vs paid Apple ID. Needed for A3 instructions.
3. **Full iOS export** cannot be validated on this Windows box (no export templates).
   Expect the first CI run to surface exporter/Xcode issues; `0000000000` Team ID
   placeholder is `UNVERIFIED` until then.

## Next single step

Human completes the device login → `gh auth status` returns OK → create repo, push,
run workflow, fix failures until an IPA is produced and verified.

## Environment changes made

- Installed `gh` 2.103.3 to `C:\Agent\tools\gh\`.
- Created `C:\Agent\ChatWars\` (project root only; other files under `C:\Agent` untouched).
- No system settings, drivers, or services were modified.
