# QA

## Stage A — technical spike

Status as of 2026-11-12.

| Check | Status | Evidence |
|---|---|---|
| CI reproducibly builds an unsigned IPA without secrets | **UNVERIFIED** | Workflow written; never executed (no repo/CI run yet) |
| Build manifest carries real versions and paths | **UNVERIFIED** | Manifest step not yet implemented in workflow |
| App executable is arm64 | **UNVERIFIED** | Needs the real artifact |
| Game runs on the specified physical device | **NOT DONE** | No device test performed |
| Channel explicitly named | **PENDING** | LiveContainer is the intended channel; device info not supplied |
| Restart preserves the counter | **Verified on Windows only** | `tests/smoke_test.gd` — headless, not on iOS |
| Airplane mode works | **NOT DONE** | Requires device |
| PCK update verified separately | **Partially** | PCK export on Windows OK; swap tool has 18 passing unit tests; device smoke test pending |

## Stage A — local verification detail

Passing now:

- Headless import: clean, no errors/warnings.
- Smoke test: 17/17 — counter increment, JSON persistence, restore-after-reload,
  corrupt-save quarantine, scene instantiation, label text, ≥44 px button,
  ru/en translation resolution and difference.
- `--export-pack "iOS"` → exit 0, valid PCK.
- `tools/swap_pck.py` → 18/18 tests: valid swap, missing/duplicate PCK, two apps,
  duplicate ZIP entries, corrupt ZIP, identical in/out, existing output without `--force`,
  paths with spaces and Cyrillic, Unix exec mode preserved, symlink entry preserved,
  no temp files left behind, input unmodified.

Not achievable on this box:

- Full iOS export (no export templates locally, by design).
- Anything requiring a physical iPhone.

## MVP acceptance

Not started. Tracked in the spec (§8) — will be filled in once Stage A's gate passes.
