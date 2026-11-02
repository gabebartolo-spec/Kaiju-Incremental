"""Smoke test for tools/triage.py's log parser: suite lines, grouped FAIL and SCRIPT ERROR lines, counts."""

import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("triage", ROOT / "tools" / "triage.py")
triage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(triage)

P = "shard 4\tRun the suites\t2026-11-02T13:21:32.4877462Z "
LOG = "\n".join(
    P + line
    for line in [
        "pass  citypool      71s  CityPool tests: 10 of 10 functions, 23 checks, 0 failures",
        "FAIL  city_sound   126s  City sound tests: 9 of 9 functions, 93 checks, 2 failures",
        "##[group]city_sound log (failures and errors)",
        "FAIL: all stems are fully in: -60.0 dB",
        "FAIL: all stems are fully in: -60.0 dB",
        "SCRIPT ERROR: Invalid call. Nonexistent function 'step' in base 'Nil'.",
        "##[endgroup]",
        "FAIL: outside any group is ignored",
    ]
)


class TriageParse(unittest.TestCase):
    def test_suites_and_counts(self):
        s = triage.parse(LOG)
        self.assertEqual(s["citypool"]["status"], "pass")
        self.assertEqual(s["city_sound"]["status"], "FAIL")
        self.assertEqual(s["city_sound"]["secs"], 126)
        self.assertEqual(s["city_sound"]["fails"]["all stems are fully in: -60.0 dB"], 2)
        self.assertEqual(sum(s["city_sound"]["errors"].values()), 1)
        self.assertNotIn("outside any group is ignored", s["city_sound"]["fails"])


if __name__ == "__main__":
    unittest.main()
