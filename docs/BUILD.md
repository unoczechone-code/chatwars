# BUILD

## Local (Windows) — what actually works here

The Windows box has **no iOS export templates**, so a full iOS export cannot run locally.
That is by design: the full build happens on macOS CI. Locally we verify the project and
produce a PCK.

```bash
GODOT=/c/Agent/tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe

# 1. Import resources (headless; the VM has no usable GPU)
"$GODOT" --headless --path game --import

# 2. Runtime/save/locale smoke test
"$GODOT" --headless --path game --script ../tests/smoke_test.gd

# 3. Export just the project data as a PCK (works on Windows)
mkdir -p game/build
"$GODOT" --headless --path game --export-pack "iOS" game/build/ChatWars.pck
```

Verified 2026-11-12: steps 1–3 all exit 0; the smoke test reports 17/17 passing.

```bash
# 4. Full iOS export — FAILS locally, expected
"$GODOT" --headless --path game --export-release "iOS" build/xcode/ChatWars.xcodeproj
# ERROR: Export templates not found at
#   C:/Users/Agent/AppData/Roaming/Godot/export_templates/4.7.2.stable/ios.zip
```

## CI (macOS) — the real iOS build

Workflow: `.github/workflows/ios.yml`, runner `macos-26`.

Steps:

1. Report the real toolchain (`sw_vers`, `uname -m`, `xcodebuild -version`, `-showsdks`).
2. Download the official Godot editor and `SHA512-SUMS.txt`; **abort on checksum mismatch**.
3. Install export templates (cached by version; verified by checksum before unpacking).
4. `Godot --headless --path game --import`.
5. `Godot --headless --path game --export-release "iOS" "$GITHUB_WORKSPACE/build/xcode/ChatWars.xcodeproj"`.
6. `xcodebuild -list -json` to discover the real scheme (not guessed from the folder name).
7. `xcodebuild ... -sdk iphoneos -destination 'generic/platform=iOS' ARCHS=arm64` with
   `CODE_SIGNING_ALLOWED=NO`.
8. Package `Payload/<App>.app` with `ditto` (preserves modes/symlinks) and `zip -qry`.
9. Upload `ChatWars-unsigned.ipa` + `build.log`, 30-day retention.

### Notes

- `application/export_project_only=true` is set in the preset, so the exporter emits an
  Xcode project rather than a signed app.
- The export path's basename determines the product name: `ChatWars.xcodeproj` → `ChatWars`.
- An unsigned IPA is **not** installable until re-signed by an installer.
- CI green ≠ device QA.

## PCK iteration (stage B)

After a base IPA exists, `tools/swap_pck.py` swaps the PCK without repacking unrelated
entries:

```bash
python tools/swap_pck.py \
  --ipa  build/base/ChatWars-unsigned.ipa \
  --pck  game/build/ChatWars.pck \
  --out  build/patched/ChatWars-patched.ipa \
  --manifest build/base/build-manifest.json
```

Tests: `python -m unittest discover -s tests -p "test_*.py"` — 18 cases, all passing.
