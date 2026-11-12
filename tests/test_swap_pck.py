#!/usr/bin/env python3
"""Tests for tools/swap_pck.py. Uses only stdlib + temp dirs."""

import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SWAP = os.path.join(ROOT, "tools", "swap_pck.py")


def build_ipa(path, app="ChatWars", pck_name="ChatWars.pck", pck_bytes=b"OLD-PCK-DATA-0123456789",
              extra_entries=None, with_pck=True, unix_exec=True):
    """Create a synthetic IPA shaped like a real one."""
    with zipfile.ZipFile(path, "w") as zf:
        def add(name, data, mode=None, comp=zipfile.ZIP_DEFLATED):
            zi = zipfile.ZipInfo(name, date_time=(2026, 11, 12, 12, 0, 0))
            zi.compress_type = comp
            if mode is not None:
                zi.external_attr = (mode & 0xFFFF) << 16
            zf.writestr(zi, data)

        base = f"Payload/{app}.app"
        add(f"{base}/Info.plist", b"<?xml version='1.0'?><plist>fake</plist>")
        add(f"{base}/{app}", b"\xcf\xfa\xed\xfeFAKE-MACHO", mode=0o100755 if unix_exec else 0o100644)
        add(f"{base}/_CodeSignature/CodeResources", b"<plist>sig</plist>")
        if with_pck:
            add(f"{base}/{pck_name}", pck_bytes)
        for n, data in (extra_entries or {}).items():
            add(n, data)
    return path


def manifest_for(app="ChatWars", pck_entry=None):
    if pck_entry is None:
        pck_entry = f"Payload/{app}.app/{app}.pck"
    return {"app_name": app, "pck_entry": pck_entry}


class SwapTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="swap_pck_test_")
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def p(self, name):
        return os.path.join(self.tmp, name)

    def write_manifest(self, m, name="manifest.json"):
        path = self.p(name)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(m, f)
        return path

    def write_pck(self, data=b"NEW-PCK-CONTENT-abcdef", name="new.pck"):
        path = self.p(name)
        with open(path, "wb") as f:
            f.write(data)
        return path

    def run_swap(self, *args):
        return subprocess.run([sys.executable, SWAP, *args],
                              capture_output=True, text=True, encoding="utf-8")

    # ---- happy path -------------------------------------------------------
    def test_valid_swap_succeeds_and_replaces_only_pck(self):
        ipa = build_ipa(self.p("in.ipa"), extra_entries={"Payload/ChatWars.app/data.bin": b"keepme"})
        pck = self.write_pck()
        man = self.write_manifest(manifest_for())
        out = self.p("out.ipa")
        r = self.run_swap("--ipa", ipa, "--pck", pck, "--out", out, "--manifest", man, "--json")
        self.assertEqual(r.returncode, 0, r.stderr)
        res = json.loads(r.stdout)
        self.assertTrue(res["ok"])
        with zipfile.ZipFile(out) as z:
            self.assertEqual(z.read("Payload/ChatWars.app/ChatWars.pck"), b"NEW-PCK-CONTENT-abcdef")
            self.assertEqual(z.read("Payload/ChatWars.app/data.bin"), b"keepme")
            self.assertEqual(z.read("Payload/ChatWars.app/Info.plist"),
                             b"<?xml version='1.0'?><plist>fake</plist>")

    def test_preserves_unix_exec_mode(self):
        ipa = build_ipa(self.p("in.ipa"), unix_exec=True)
        pck = self.write_pck()
        man = self.write_manifest(manifest_for())
        out = self.p("out.ipa")
        r = self.run_swap("--ipa", ipa, "--pck", pck, "--out", out, "--manifest", man)
        self.assertEqual(r.returncode, 0, r.stderr)
        with zipfile.ZipFile(out) as z:
            zi = z.getinfo("Payload/ChatWars.app/ChatWars")
            mode = (zi.external_attr >> 16) & 0o777
            self.assertEqual(mode, 0o755, f"expected 0o755, got {oct(mode)}")

    def test_preserves_symlink_entry(self):
        ipa = self.p("in.ipa")
        with zipfile.ZipFile(ipa, "w") as zf:
            zi = zipfile.ZipInfo("Payload/ChatWars.app/Info.plist")
            zf.writestr(zi, b"<plist/>")
            lk = zipfile.ZipInfo("Payload/ChatWars.app/link")
            lk.external_attr = (stat.S_IFLNK | 0o777) << 16
            zf.writestr(lk, b"Info.plist")
            zf.writestr("Payload/ChatWars.app/ChatWars.pck", b"OLDPCK")
        man = self.write_manifest(manifest_for())
        out = self.p("out.ipa")
        r = self.run_swap("--ipa", ipa, "--pck", self.write_pck(), "--out", out, "--manifest", man)
        self.assertEqual(r.returncode, 0, r.stderr)
        with zipfile.ZipFile(out) as z:
            zi = z.getinfo("Payload/ChatWars.app/link")
            self.assertTrue(stat.S_ISLNK((zi.external_attr >> 16)), "symlink mode lost")

    # ---- failure modes ----------------------------------------------------
    def test_missing_pck_entry_in_ipa_fails(self):
        ipa = build_ipa(self.p("in.ipa"), with_pck=False)
        man = self.write_manifest(manifest_for())
        r = self.run_swap("--ipa", ipa, "--pck", self.write_pck(), "--out", self.p("o.ipa"),
                          "--manifest", man)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("not present", r.stderr)
        self.assertFalse(os.path.exists(self.p("o.ipa")), "must not create output on failure")

    def test_manifest_entry_not_creating_new_entry(self):
        """A manifest naming a different PCK must fail, not inject a new file."""
        ipa = build_ipa(self.p("in.ipa"), pck_name="ChatWars.pck")
        man = self.write_manifest(manifest_for(pck_entry="Payload/ChatWars.app/Other.pck"))
        r = self.run_swap("--ipa", ipa, "--pck", self.write_pck(), "--out", self.p("o.ipa"),
                          "--manifest", man)
        self.assertNotEqual(r.returncode, 0)
        self.assertFalse(os.path.exists(self.p("o.ipa")))

    def test_two_pcks_fails(self):
        ipa = build_ipa(self.p("in.ipa"),
                        extra_entries={"Payload/ChatWars.app/Second.pck": b"x"})
        man = self.write_manifest(manifest_for())
        r = self.run_swap("--ipa", ipa, "--pck", self.write_pck(), "--out", self.p("o.ipa"),
                          "--manifest", man)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("exactly one .pck", r.stderr)

    def test_two_apps_fails(self):
        ipa = self.p("in.ipa")
        with zipfile.ZipFile(ipa, "w") as zf:
            zf.writestr("Payload/A.app/Info.plist", b"a")
            zf.writestr("Payload/B.app/Info.plist", b"b")
            zf.writestr("Payload/A.app/A.pck", b"p")
        man = self.write_manifest(manifest_for(app="A"))
        r = self.run_swap("--ipa", ipa, "--pck", self.write_pck(), "--out", self.p("o.ipa"),
                          "--manifest", man)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("exactly one app", r.stderr)

    def test_duplicate_entries_fails(self):
        ipa = self.p("in.ipa")
        with zipfile.ZipFile(ipa, "w") as zf:
            import warnings
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                zf.writestr("Payload/ChatWars.app/Info.plist", b"a")
                zf.writestr("Payload/ChatWars.app/Info.plist", b"b")
            zf.writestr("Payload/ChatWars.app/ChatWars.pck", b"p")
        man = self.write_manifest(manifest_for())
        r = self.run_swap("--ipa", ipa, "--pck", self.write_pck(), "--out", self.p("o.ipa"),
                          "--manifest", man)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("duplicate", r.stderr.lower())

    def test_corrupt_zip_fails(self):
        bad = self.p("bad.ipa")
        with open(bad, "wb") as f:
            f.write(b"PK\x03\x04this is not really a zip file at all" * 3)
        man = self.write_manifest(manifest_for())
        r = self.run_swap("--ipa", bad, "--pck", self.write_pck(), "--out", self.p("o.ipa"),
                          "--manifest", man)
        self.assertNotEqual(r.returncode, 0)
        self.assertFalse(os.path.exists(self.p("o.ipa")))

    def test_unsafe_path_fails(self):
        ipa = self.p("in.ipa")
        with zipfile.ZipFile(ipa, "w") as zf:
            zf.writestr("Payload/ChatWars.app/Info.plist", b"a")
            zf.writestr("Payload/ChatWars.app/ChatWars.pck", b"p")
            zf.writestr("../escape.txt", b"evil")
        man = self.write_manifest(manifest_for())
        r = self.run_swap("--ipa", ipa, "--pck", self.write_pck(), "--out", self.p("o.ipa"),
                          "--manifest", man)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("unsafe", r.stderr)

    def test_same_input_and_output_fails(self):
        ipa = build_ipa(self.p("in.ipa"))
        man = self.write_manifest(manifest_for())
        r = self.run_swap("--ipa", ipa, "--pck", self.write_pck(), "--out", ipa,
                          "--manifest", man)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("must differ", r.stderr)

    def test_existing_output_without_force_fails(self):
        ipa = build_ipa(self.p("in.ipa"))
        man = self.write_manifest(manifest_for())
        out = self.p("o.ipa")
        with open(out, "wb") as f:
            f.write(b"existing")
        r = self.run_swap("--ipa", ipa, "--pck", self.write_pck(), "--out", out, "--manifest", man)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("--force", r.stderr)
        with open(out, "rb") as f:
            self.assertEqual(f.read(), b"existing", "existing output must be untouched")

    def test_force_overwrites(self):
        ipa = build_ipa(self.p("in.ipa"))
        man = self.write_manifest(manifest_for())
        out = self.p("o.ipa")
        with open(out, "wb") as f:
            f.write(b"existing")
        r = self.run_swap("--ipa", ipa, "--pck", self.write_pck(), "--out", out,
                          "--manifest", man, "--force")
        self.assertEqual(r.returncode, 0, r.stderr)
        with zipfile.ZipFile(out) as z:
            self.assertIn("Payload/ChatWars.app/ChatWars.pck", z.namelist())

    def test_tiny_pck_rejected(self):
        ipa = build_ipa(self.p("in.ipa"))
        man = self.write_manifest(manifest_for())
        r = self.run_swap("--ipa", ipa, "--pck", self.write_pck(b"ab"), "--out", self.p("o.ipa"),
                          "--manifest", man)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("too small", r.stderr)

    def test_missing_manifest_pck_key_fails(self):
        ipa = build_ipa(self.p("in.ipa"))
        man = self.write_manifest({"app_name": "ChatWars"})
        r = self.run_swap("--ipa", ipa, "--pck", self.write_pck(), "--out", self.p("o.ipa"),
                          "--manifest", man)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("no PCK entry name", r.stderr)

    def test_spaces_and_cyrillic_in_paths(self):
        d = os.path.join(self.tmp, "путь с пробелами", "битва за чат")
        os.makedirs(d, exist_ok=True)
        ipa = build_ipa(os.path.join(d, "входной.ipa"))
        pck = self.write_pck(name="новый.pck")
        man = self.write_manifest(manifest_for())
        out = os.path.join(d, "выходной.ipa")
        r = self.run_swap("--ipa", ipa, "--pck", pck, "--out", out, "--manifest", man)
        self.assertEqual(r.returncode, 0, r.stderr)
        with zipfile.ZipFile(out) as z:
            self.assertEqual(z.read("Payload/ChatWars.app/ChatWars.pck"),
                             b"NEW-PCK-CONTENT-abcdef")

    def test_no_temp_file_left_behind(self):
        ipa = build_ipa(self.p("in.ipa"))
        man = self.write_manifest(manifest_for())
        out = self.p("o.ipa")
        r = self.run_swap("--ipa", ipa, "--pck", self.write_pck(), "--out", out, "--manifest", man)
        self.assertEqual(r.returncode, 0, r.stderr)
        leftovers = [f for f in os.listdir(self.tmp) if f.endswith(".ipa.tmp")]
        self.assertEqual(leftovers, [], f"temp files left: {leftovers}")

    def test_input_preserved_after_success(self):
        ipa = build_ipa(self.p("in.ipa"))
        before = open(ipa, "rb").read()
        man = self.write_manifest(manifest_for())
        r = self.run_swap("--ipa", ipa, "--pck", self.write_pck(), "--out", self.p("o.ipa"),
                          "--manifest", man)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(open(ipa, "rb").read(), before, "input IPA must be unmodified")


if __name__ == "__main__":
    unittest.main(verbosity=2)
