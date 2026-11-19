"""Reject valid-UTF8 mojibake as well as invalid encodings and escaped corruption."""
import importlib.util
from pathlib import Path
import unittest
spec = importlib.util.spec_from_file_location("release", Path(__file__).resolve().parents[1] / "scripts/release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)

class EncodingTests(unittest.TestCase):
    def test_plain_text_preserved(self):
        raw = b"waits 0-10 seconds\nSettings > Mods\n"
        self.assertEqual(release.check_text(raw, "README.md").encode("utf-8"), raw)
    def test_invalid_utf8_rejected(self):
        with self.assertRaises(UnicodeError):
            release.check_text(bytes([0x96]), "README.md")
    def test_valid_utf8_mojibake_rejected(self):
        broken = "0" + chr(0xe2) + chr(0x20ac) + chr(0x201c) + "10"
        with self.assertRaises(ValueError):
            release.check_text(broken.encode("utf-8"), "README.md")
    def test_escaped_json_rejected(self):
        with self.assertRaises(ValueError):
            release.check_text(br'{"description":"bad \u00e2"}', "mod.json")
    def test_description_preserves_crlf(self):
        raw = b"<!-- drh:show -->\r\nwaits 0-10 seconds\r\nnext line\r\n<!-- /drh:show -->"
        shown = raw.decode("utf-8").split("<!-- drh:show -->")[1].split("<!-- /drh:show -->")[0].strip()
        import json
        self.assertEqual(json.loads(json.dumps({"longDescription": shown}))["longDescription"], "waits 0-10 seconds\r\nnext line")

    def test_control_rejected(self):
        with self.assertRaises(ValueError):
            release.check_text(b"bad\x00", "README.md")

if __name__ == "__main__":
    unittest.main()
