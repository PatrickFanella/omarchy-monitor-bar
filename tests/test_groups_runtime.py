# SPDX-License-Identifier: MIT
"""Load the embedded editor and exercise native saves without desktop writes."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
SHELL = Path("/usr/share/omarchy/shell")

@unittest.skipUnless(shutil.which("quickshell") and (SHELL / "Ui").is_dir(),
                     "requires the installed Omarchy Quickshell runtime")
class GroupRuntimeTest(unittest.TestCase):
    def test_components_and_native_save(self):
        with tempfile.TemporaryDirectory(prefix="monitor-groups-smoke-") as temporary:
            root = Path(temporary)
            for name in ("Commons", "Ui"):
                (root / name).symlink_to(SHELL / name, target_is_directory=True)
            (root / "groups").symlink_to(ROOT / "groups", target_is_directory=True)
            (root / "monitor").symlink_to(ROOT, target_is_directory=True)
            shutil.copyfile(ROOT / "tests/groups_runtime.qml", root / "shell.qml")
            result = subprocess.run(["quickshell", "--no-color", "-p", str(root)],
                                    capture_output=True, text=True, timeout=15)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("GROUP_SMOKE_PASSED", output)
            self.assertNotIn("Failed to load configuration", output)
