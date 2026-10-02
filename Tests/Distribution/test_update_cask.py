import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("update_cask", ROOT / "script/update-cask.py")
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)


class CaskUpdateTests(unittest.TestCase):
    def test_pin_and_repin(self):
        with tempfile.TemporaryDirectory() as directory:
            dmg = Path(directory) / "Murmur.dmg"
            cask = Path(directory) / "murmur.rb"
            dmg.write_bytes(b"test disk image")
            cask.write_text((ROOT / "Casks/murmur.rb").read_text())
            for tag in ("v0.0.2", "v1.2.3"):
                updater.update_cask(tag, dmg, cask)
                text = cask.read_text()
                self.assertIn(f'version "{tag[1:]}"', text)
                self.assertIn(f'sha256 "{hashlib.sha256(dmg.read_bytes()).hexdigest()}"', text)
                self.assertIn('/releases/download/v#{version}/Murmur.dmg', text)
                self.assertNotIn(':no_check', text)
                self.assertIn('depends_on macos: ">= :tahoe"', text)
                updater.update_cask(tag, dmg, cask)
                self.assertEqual(text, cask.read_text())

    def test_invalid_tag_does_not_change_cask(self):
        with tempfile.TemporaryDirectory() as directory:
            cask = Path(directory) / "murmur.rb"
            cask.write_text("unchanged")
            for tag in ("main", "v1", "v1.2.3-rc1", "v1.2.3\n"):
                with self.assertRaises(ValueError):
                    updater.update_cask(tag, Path(directory) / "missing.dmg", cask)
                self.assertEqual("unchanged", cask.read_text())


if __name__ == "__main__":
    unittest.main()
