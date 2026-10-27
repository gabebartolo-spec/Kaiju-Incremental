"""Smoke test for tools/lint/prepush_picks.py (tools/prepush.sh step 5 picks the suites a change reaches).

Builds a scratch project with two suites and checks: a docs-only change picks nothing; a script a
runner loads picks that suite and not the other; a class_name use reaches the declaring script; a
.uid follows its file; a changed data/tuning.json section picks the suite that reads it (via git);
and a suite that nothing changed touches is never picked (the failure that makes a PR go red late).
"""

import json
import subprocess
import unittest

import helpers

TOOL = helpers.tool("tools", "lint", "prepush_picks.py")


def project(root):
    helpers.write(root, "tests/run_alpha_tests.gd", 'const A := preload("res://sim/alpha_sim.gd")\n')
    helpers.write(root, "tests/run_beta_tests.gd", "func run_checks() -> void:\n\tvar b := Beta.new()\n")
    helpers.write(root, "sim/alpha_sim.gd", "func tick() -> void:\n\tpass\n")
    helpers.write(root, "sim/beta.gd", "class_name Beta\nfunc go() -> void:\n\tpass\n")
    helpers.write(root, "sim/unrelated.gd", "func idle() -> void:\n\tpass\n")
    helpers.write(root, "project.godot", "[autoload]\n")


def picks(root, changed, env=None):
    exit_code, out = helpers.run(TOOL, ["--root", str(root), *changed], env=env)
    assert exit_code == 0, out
    return sorted(line.split("\t")[0] for line in out.splitlines() if line and not line.startswith("#"))


class PrepushPicksSmoke(unittest.TestCase):
    def test_docs_only_picks_nothing(self):
        with helpers.scratch() as root:
            project(root)
            self.assertEqual(picks(root, ["docs/DESIGN.md", "README.md"]), [])

    def test_script_a_runner_loads_picks_that_suite_only(self):
        with helpers.scratch() as root:
            project(root)
            self.assertEqual(picks(root, ["sim/alpha_sim.gd"]), ["alpha"])

    def test_class_name_use_reaches_the_declaring_script(self):
        with helpers.scratch() as root:
            project(root)
            self.assertEqual(picks(root, ["sim/beta.gd"]), ["beta"])

    def test_a_script_no_suite_reaches_picks_nothing(self):
        with helpers.scratch() as root:
            project(root)
            self.assertEqual(picks(root, ["sim/unrelated.gd"]), [])

    def test_runner_and_its_uid_pick_the_suite(self):
        with helpers.scratch() as root:
            project(root)
            self.assertEqual(picks(root, ["tests/run_beta_tests.gd"]), ["beta"])
            self.assertEqual(picks(root, ["tests/run_beta_tests.gd.uid"]), ["beta"])

    def test_names_can_come_on_stdin_and_timings_print_an_estimate(self):
        with helpers.scratch() as root:
            project(root)
            helpers.write(root, "timings.txt", "alpha 12.5\n")
            code, out = helpers.run(TOOL, ["--root", str(root), "--timings", str(root / "timings.txt")], stdin="sim/alpha_sim.gd\n")
        self.assertEqual(code, 0, out)
        self.assertIn("# expected: 1 suites, ~12 s", out)

    def test_changed_tuning_section_picks_the_suite_that_reads_it(self):
        with helpers.scratch() as root:
            project(root)
            helpers.write(root, "sim/alpha_sim.gd", 'func tick() -> void:\n\tvar c := Content.section("stomp")\n')
            helpers.write(root, "data/tuning.json", json.dumps({"stomp": {"damage": 5}, "fire": {"spread": 1}}))
            git = ["git", "-C", str(root), "-c", "user.name=t", "-c", "user.email=t@example.com"]
            subprocess.run([*git, "init", "-q"], check=True)
            subprocess.run([*git, "add", "-A"], check=True)
            subprocess.run([*git, "commit", "-q", "-m", "base"], check=True)
            subprocess.run([*git, "branch", "-M", "base"], check=True)
            helpers.write(root, "data/tuning.json", json.dumps({"stomp": {"damage": 9}, "fire": {"spread": 1}}))
            self.assertEqual(picks(root, ["data/tuning.json"], env={"BASE_REF": "base"}), ["alpha"])
            helpers.write(root, "data/tuning.json", json.dumps({"stomp": {"damage": 5}, "fire": {"spread": 3}}))
            self.assertEqual(picks(root, ["data/tuning.json"], env={"BASE_REF": "base"}), [])

    # #279 (run 40419798629): a new tools/capture script printed PASS locally and failed the native suite
    # ("does not start with the guard") on GitHub, because no runner loads those scripts.
    def test_new_or_changed_capture_or_bench_script_picks_native(self):
        with helpers.scratch() as root:
            project(root)
            helpers.write(root, "tests/run_native_tests.gd", "func run_checks() -> void:\n\tpass\n")
            self.assertEqual(picks(root, ["tools/capture/capture_vehicle_solid.gd"]), ["native"])
            self.assertEqual(picks(root, ["tools/bench/bench_city.gd"]), ["native"])
            self.assertEqual(picks(root, ["tools/capture/capture_vehicle_solid.gd.uid"]), ["native"])
            self.assertEqual(picks(root, ["sim/alpha_sim.gd", "tools/capture/x.gd"]), ["alpha", "native"])

    def test_native_is_not_added_twice_or_for_other_tool_files(self):
        with helpers.scratch() as root:
            project(root)
            helpers.write(root, "tests/run_native_tests.gd", "func run_checks() -> void:\n\tpass\n")
            self.assertEqual(picks(root, ["tests/run_native_tests.gd", "tools/capture/x.gd"]), ["native"])
            self.assertEqual(picks(root, ["tools/capture/README.md", "tools/capture/ci_capture.sh"]), [])
            self.assertEqual(picks(root, ["tools/lint/prepush_picks.py", "tools/check_scripts.gd"]), [])

    def test_a_project_without_a_native_suite_picks_nothing_for_them(self):
        with helpers.scratch() as root:
            project(root)
            self.assertEqual(picks(root, ["tools/capture/capture_vehicle_solid.gd"]), [])


if __name__ == "__main__":
    unittest.main()
