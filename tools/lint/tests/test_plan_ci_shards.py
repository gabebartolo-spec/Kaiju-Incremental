"""Smoke test for tools/plan_ci_shards.sh (tests.yml plan job: it makes the shard matrix every PR run uses).

The script finds suites by tests/run_<suite>_tests.gd and splits them by the seconds in tools/ci_timings.txt,
from the project root above its own folder, so each test copies it into a scratch project. Green: the plan,
the matrix JSON and the slow list come out right (longest suite first into the lightest shard, a suite with
no timing counts DEFAULT_SECS, a "pr_skip" suite is left out). Red, exit 1 with an error line, when the
project has no suite at all (the plan job then fails the PR instead of running nothing).
"""

import json
import shutil
import unittest

import helpers

TIMINGS = "# suite seconds\nshards 2\nalpha 100\nbeta 60\ngamma 50\ndelta 30\npr_skip delta\n"
SUITES = ["alpha", "beta", "gamma", "delta"]


def project(root, suites, timings=TIMINGS):
    helpers.copy_tool(root, "tools", "plan_ci_shards.sh")
    helpers.write(root, "tools/ci_timings.txt", timings)
    for s in suites:
        helpers.write(root, f"tests/run_{s}_tests.gd", "extends SceneTree\n")


def plan(suites, args=(), timings=TIMINGS, env=None):
    with helpers.scratch() as root:
        project(root, suites, timings)
        return helpers.run_bash("tools/plan_ci_shards.sh", args, cwd=root, env=env)


@unittest.skipUnless(shutil.which("bash"), "bash is not on PATH")
class PlanCiShardsSmoke(unittest.TestCase):
    def test_longest_suite_goes_into_the_lightest_shard(self):
        exit_code, out = plan(SUITES)
        self.assertEqual(exit_code, 0, out)
        self.assertEqual(out.splitlines(), ["shard 1 (~100s): alpha", "shard 2 (~110s): beta gamma"])

    def test_matrix_is_valid_json_with_every_planned_suite_once(self):
        exit_code, out = plan(SUITES, ["--matrix"])
        self.assertEqual(exit_code, 0, out)
        matrix = json.loads(out)
        self.assertEqual(
            matrix["include"],
            [
                {"shard": "1", "lanes": "1", "suites": "alpha"},
                {"shard": "2", "lanes": "1", "suites": "beta gamma"},
            ],
        )

    def test_lanes_pack_more_bins_per_shard(self):
        # 2 shards x 2 lanes = 4 bins: each suite its own bin, the matrix says how many lanes to run
        timings = "shards 2\nlanes 2\nalpha 100\nbeta 60\ngamma 50\ndelta 30\n"
        exit_code, out = plan(SUITES, timings=timings)
        self.assertEqual(exit_code, 0, out)
        self.assertEqual(
            out.splitlines(), ["shard 1 (~100s, 2 lanes): alpha gamma", "shard 2 (~60s, 2 lanes): beta delta"]
        )
        exit_code, out = plan(SUITES, ["--matrix"], timings=timings)
        self.assertEqual({e["lanes"] for e in json.loads(out)["include"]}, {"2"})

    def test_split_suite_is_planned_as_its_parts_and_never_whole(self):
        timings = "shards 2\nsplit alpha 2\nalpha@1/2 60\nalpha@2/2 50\nbeta 40\ngamma 30\ndelta 20\n"
        exit_code, out = plan(SUITES, ["--matrix"], timings=timings)
        self.assertEqual(exit_code, 0, out)
        planned = " ".join(e["suites"] for e in json.loads(out)["include"]).split()
        self.assertEqual(sorted(planned), sorted(["alpha@1/2", "alpha@2/2", "beta", "gamma", "delta"]))

    def test_split_of_an_unknown_suite_or_one_part_fails(self):
        exit_code, out = plan(SUITES, timings="shards 2\nsplit nosuch 2\nalpha 1\n")
        self.assertNotEqual(exit_code, 0, out)
        exit_code, out = plan(SUITES, timings="shards 2\nsplit alpha 1\nalpha 1\n")
        self.assertNotEqual(exit_code, 0, out)

    def test_pr_skip_suite_is_in_the_slow_list_and_not_the_plan(self):
        exit_code, out = plan(SUITES, ["--slow"])
        self.assertEqual(exit_code, 0, out)
        self.assertEqual(out.strip(), "delta")
        self.assertNotIn("delta", plan(SUITES)[1])

    def test_suite_without_a_timing_counts_the_default(self):
        exit_code, out = plan(SUITES + ["epsilon"], env={"DEFAULT_SECS": "7"})
        self.assertEqual(exit_code, 0, out)
        self.assertEqual(out.splitlines(), ["shard 1 (~107s): alpha epsilon", "shard 2 (~110s): beta gamma"])

    def test_more_shards_than_suites_is_clamped(self):
        exit_code, out = plan(["alpha", "beta"], timings="shards 9\nalpha 10\nbeta 20\n")
        self.assertEqual(exit_code, 0, out)
        self.assertEqual(out.splitlines(), ["shard 1 (~20s): beta", "shard 2 (~10s): alpha"])

    def test_no_suites_fails(self):
        exit_code, out = plan([])
        self.assertEqual(exit_code, 1, out)
        self.assertIn("ERROR: no tests/run_*_tests.gd suites", out)


if __name__ == "__main__":
    unittest.main()
