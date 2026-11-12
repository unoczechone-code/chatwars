#!/usr/bin/env python3
"""Swap the Godot PCK inside an unsigned IPA without repacking unrelated entries.

The output ZIP is NOT byte-identical to the input (recompression may differ), but
every non-PCK entry's decompressed bytes and critical ZipInfo metadata are verified
unchanged. The result MUST be re-signed by the installer (LiveContainer/SideStore/
AltStore) before it can be installed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import tempfile
import zipfile

MAX_ARCHIVE_BYTES = 4 * 1024 * 1024 * 1024  # 4 GiB hard ceiling
PCK_SUFFIX = ".pck"


class SwapError(Exception):
    """A condition that must abort the swap without touching the output."""


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _is_unsafe_name(name: str) -> bool:
    if not name:
        return True
    norm = name.replace("\\", "/")
    if norm.startswith("/"):
        return True
    if norm.startswith("../") or "/../" in norm or norm == "..":
        return True
    # Windows drive letter, e.g. "C:/evil"
    if len(norm) > 1 and norm[1] == ":":
        return True
    return False


def load_manifest(path: str) -> dict:
    if not path:
        return {}
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        raise SwapError(f"manifest not found: {path}")
    except json.JSONDecodeError as e:
        raise SwapError(f"manifest is not valid JSON: {e}")
    if not isinstance(data, dict):
        raise SwapError("manifest root must be a JSON object")
    return data


def _expected_pck_entry(manifest: dict) -> str:
    for key in ("pck_entry", "pck_path", "pck"):
        val = manifest.get(key)
        if isinstance(val, str) and val.strip():
            return val.strip()
    raise SwapError(
        "manifest has no PCK entry name (expected one of: pck_entry, pck_path, pck)")


def inspect_ipa(path: str, expected_app_hint: str | None) -> dict:
    """Validates structure; returns {'pck_entries': [...], 'app_count': n, 'infos': {}}."""
    if not os.path.isfile(path):
        raise SwapError(f"IPA not found: {path}")
    size = os.path.getsize(path)
    if size == 0:
        raise SwapError("IPA is empty")
    if size > MAX_ARCHIVE_BYTES:
        raise SwapError(f"IPA too large ({size} bytes > {MAX_ARCHIVE_BYTES})")

    try:
        with zipfile.ZipFile(path) as zf:
            bad = zf.testzip()
            if bad is not None:
                raise SwapError(f"ZIP CRC failure on entry: {bad}")
            infos = zf.infolist()
    except zipfile.BadZipFile as e:
        raise SwapError(f"not a valid ZIP/IPA: {e}")

    names = [i.filename for i in infos]
    seen = set()
    dupes = set()
    for n in names:
        if n in seen:
            dupes.add(n)
        seen.add(n)
    if dupes:
        raise SwapError(f"duplicate ZIP entries: {sorted(dupes)[:5]}")

    for n in names:
        if _is_unsafe_name(n):
            raise SwapError(f"unsafe/absolute path in archive: {n!r}")

    # Find Payload/*.app top-level bundles.
    apps = set()
    for n in names:
        parts = n.split("/")
        if len(parts) >= 2 and parts[0] == "Payload" and parts[1].endswith(".app"):
            apps.add(parts[1])
    if not apps:
        raise SwapError("no Payload/<App>.app found in IPA")
    if len(apps) > 1:
        raise SwapError(f"expected exactly one app, found {len(apps)}: {sorted(apps)}")
    app = next(iter(apps))

    if expected_app_hint:
        hint = expected_app_hint.strip()
        if not hint.endswith(".app"):
            hint = hint + ".app"
        if hint != app:
            raise SwapError(
                f"manifest app {expected_app_hint!r} does not match IPA app {app!r}")

    pck_entries = [n for n in names
                   if n.startswith(f"Payload/{app}/") and n.lower().endswith(PCK_SUFFIX)]
    return {
        "app": app,
        "app_count": len(apps),
        "pck_entries": sorted(pck_entries),
        "infos": {i.filename: i for i in infos},
        "names": names,
        "size": size,
    }


def plan_swap(ipa: str, pck: str, manifest: dict) -> dict:
    info = inspect_ipa(ipa, manifest.get("app_name") or manifest.get("app"))
    expected_entry = _expected_pck_entry(manifest)

    if not os.path.isfile(pck):
        raise SwapError(f"PCK not found: {pck}")
    pck_size = os.path.getsize(pck)
    if pck_size < 4:
        raise SwapError(f"PCK too small to be real ({pck_size} bytes)")

    found = info["pck_entries"]
    if expected_entry not in found:
        raise SwapError(
            "manifest PCK entry not present in IPA: "
            f"{expected_entry!r}. Present .pck entries: {found}")
    if len(found) != 1:
        raise SwapError(
            f"expected exactly one .pck entry in the app bundle, found {len(found)}: {found}")
    return {**info, "pck_entry": expected_entry, "pck_size": pck_size}


def perform_swap(ipa: str, pck: str, out: str, manifest: dict, force: bool) -> dict:
    ipa_abs = os.path.abspath(ipa)
    pck_abs = os.path.abspath(pck)
    out_abs = os.path.abspath(out)

    if not os.path.isabs(ipa_abs) or not os.path.isabs(out_abs):
        raise SwapError("all paths must be absolute")
    if os.path.normcase(ipa_abs) == os.path.normcase(out_abs):
        raise SwapError("input and output must differ")
    if os.path.normcase(pck_abs) == os.path.normcase(out_abs):
        raise SwapError("PCK and output must differ")
    if os.path.exists(out_abs) and not force:
        raise SwapError(f"output exists (use --force): {out_abs}")

    plan = plan_swap(ipa_abs, pck_abs, manifest)
    entry = plan["pck_entry"]
    src_infos = plan["infos"]

    # Hash every non-PCK entry's decompressed bytes from the source for later verification.
    baseline = {}
    with zipfile.ZipFile(ipa_abs) as zin:
        for i in zin.infolist():
            if i.filename == entry:
                continue
            baseline[i.filename] = hashlib.sha256(zin.read(i.filename)).hexdigest()

    with open(pck_abs, "rb") as f:
        new_pck_bytes = f.read()

    out_dir = os.path.dirname(out_abs) or "."
    os.makedirs(out_dir, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(suffix=".ipa.tmp", dir=out_dir)
    os.close(fd)

    try:
        with zipfile.ZipFile(ipa_abs) as zin, \
                zipfile.ZipFile(tmp_path, "w", allowZip64=True) as zout:
            for info in zin.infolist():
                if info.filename == entry:
                    new_info = zipfile.ZipInfo(info.filename, date_time=info.date_time)
                    new_info.compress_type = info.compress_type
                    new_info.comment = info.comment
                    new_info.extra = info.extra
                    new_info.create_system = info.create_system
                    new_info.external_attr = info.external_attr
                    new_info.internal_attr = info.internal_attr
                    zout.writestr(new_info, new_pck_bytes)
                else:
                    # Preserve ZipInfo exactly; re-read then re-write unchanged bytes.
                    zout.writestr(info, zin.read(info.filename))

        # Verify the result before committing.
        with zipfile.ZipFile(tmp_path) as zchk:
            if zchk.testzip() is not None:
                raise SwapError("post-write ZIP CRC verification failed")
            names = [i.filename for i in zchk.infolist()]
            if len(names) != len(set(names)):
                raise SwapError("post-write archive has duplicate entries")
            if entry not in names:
                raise SwapError("post-write archive lost the PCK entry")
            if zchk.read(entry) != new_pck_bytes:
                raise SwapError("post-write PCK bytes do not match the source PCK")
            for name, digest in baseline.items():
                got = hashlib.sha256(zchk.read(name)).hexdigest()
                if got != digest:
                    raise SwapError(f"entry content changed unexpectedly: {name}")
            # Metadata spot-check on a sample of preserved entries.
            chk_infos = {i.filename: i for i in zchk.infolist()}
            for name, orig in src_infos.items():
                if name == entry:
                    continue
                new = chk_infos.get(name)
                if new is None:
                    raise SwapError(f"entry disappeared: {name}")
                if name.endswith("/"):
                    continue
                if (orig.external_attr >> 16) != (new.external_attr >> 16):
                    raise SwapError(f"unix mode changed for {name}: "
                                    f"{oct(orig.external_attr >> 16)} -> "
                                    f"{oct(new.external_attr >> 16)}")

        os.replace(tmp_path, out_abs)
        tmp_path = None
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)

    return {
        "ok": True,
        "input_ipa": ipa_abs,
        "output_ipa": out_abs,
        "pck_entry": entry,
        "pck_sha256": hashlib.sha256(new_pck_bytes).hexdigest(),
        "pck_bytes": len(new_pck_bytes),
        "output_sha256": sha256_file(out_abs),
        "output_bytes": os.path.getsize(out_abs),
        "entries_verified": len(baseline),
        "warning": "PCK swapped. The IPA is now unsigned-invalid: re-sign it with the "
                   "installer (LiveContainer/SideStore/AltStore) before installing.",
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Swap the Godot PCK inside an unsigned IPA.")
    ap.add_argument("--ipa", required=True)
    ap.add_argument("--pck", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--json", action="store_true", help="machine-readable result")
    args = ap.parse_args(argv)

    try:
        manifest = load_manifest(args.manifest)
        result = perform_swap(args.ipa, args.pck, args.out, manifest, args.force)
    except SwapError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2
    except (OSError, zipfile.BadZipFile) as e:
        print(f"ERROR: {type(e).__name__}: {e}", file=sys.stderr)
        return 3

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print("PCK swapped OK")
        print(f"  entry      : {result['pck_entry']}")
        print(f"  pck sha256 : {result['pck_sha256']}")
        print(f"  out sha256 : {result['output_sha256']}")
        print(f"  out size   : {result['output_bytes']} bytes")
        print(f"  verified   : {result['entries_verified']} unchanged entries")
        print(f"  WARNING    : {result['warning']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
