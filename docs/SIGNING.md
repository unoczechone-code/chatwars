# SIGNING

## What the CI build is

`ChatWars-unsigned.ipa` is an **unsigned** IPA. It contains no provisioning profile, no
code signature, and no entitlements that reference a real Apple team.

It is a build artifact for testing the pipeline, **not** an installable app on its own.

## The `0000000000` Team ID placeholder

Godot 4.7.2's iOS exporter requires `application/app_store_team_id` to be non-empty even in
project-only export mode. The check happens before the `export_project_only` branch, so an
empty value aborts the export regardless.

The CI preset therefore carries the literal string:

```
application/app_store_team_id="0000000000"
```

This is **ten zeros — deliberately not a real Team ID**. It exists only to satisfy the
non-emptiness check. The build runs with:

```
CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

so `xcodebuild` never attempts to use it for signing.

**Status: `UNVERIFIED` until the first successful CI run.** If either the exporter or
Xcode rejects the placeholder, the fix is to supply the real Team ID (a free personal team
has one too). Do not describe the placeholder as a working signature.

## Re-signing after a PCK swap

`tools/swap_pck.py` replaces the `.pck` inside an existing IPA. That invalidates the
resource signature. The result **must** be re-signed by the installer
(LiveContainer / SideStore / AltStore) before installation.

The tool prints this warning on success and never claims the output is installable as-is.

## Rules

- No secrets in the repository. No provisioning profiles, no certificates, no tokens.
- Real Team IDs and profile UUIDs are not published without the owner's consent.
- The CI stage has no signing secrets by design.
