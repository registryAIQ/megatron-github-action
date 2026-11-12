import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import runner


class RunnerTests(unittest.TestCase):
    def test_path_rejects_escape(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "workspace"
            root.mkdir()
            with self.assertRaises(ValueError):
                runner.resolve_inside_workspace(root, "../outside", "scan-path")

    def test_path_accepts_workspace_child(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            child = root / "src"
            child.mkdir()
            self.assertEqual(runner.resolve_inside_workspace(root, "src", "scan-path"), child.resolve())

    def test_sarif_validation(self):
        with tempfile.TemporaryDirectory() as tmp:
            report = Path(tmp) / "report.sarif"
            report.write_text(json.dumps({"version": "2.1.0", "runs": []}))
            self.assertEqual(runner.validate_sarif(report)["version"], "2.1.0")

    def test_rejects_wrong_sarif_version(self):
        with tempfile.TemporaryDirectory() as tmp:
            report = Path(tmp) / "report.sarif"
            report.write_text(json.dumps({"version": "1.0.0", "runs": []}))
            with self.assertRaises(ValueError):
                runner.validate_sarif(report)

    def test_severity_numeric_and_labels(self):
        self.assertEqual(runner.severity_of_result({"properties": {"security-severity": "9.5"}}, {}), 4)
        self.assertEqual(runner.severity_of_result({"properties": {"severity": "medium"}}, {}), 2)
        self.assertEqual(runner.severity_of_result({"level": "error"}, {}), 3)

    def test_bool_parser(self):
        self.assertTrue(runner.parse_bool("TRUE", "flag"))
        with self.assertRaises(ValueError):
            runner.parse_bool("yes", "flag")


if __name__ == "__main__":
    unittest.main()
