"""Smoke test for tools/lint/data_schemas.py (tests.yml preflight and tools/prepush.sh step 2).

CLAUDE.md hard rule 4: every data/*.json is checked against data/schemas/<name>.schema.json. The tool finds
its project root from its own location, so each test copies it into a scratch project. Green on a file that
matches its schema; red, naming file and key, on a wrong type, an unknown key, a missing schema, a schema with
no data file, a key written twice in one object and a broken cross-reference. Needs the jsonschema package
(MIT, the one dependency of the tool, pinned in tests.yml); skipped where it is not installed.
"""

import importlib.util
import json
import unittest

import helpers

HAS_JSONSCHEMA = importlib.util.find_spec("jsonschema") is not None
DRAFT = "https://json-schema.org/draft/2020-12/schema"
TUNING_SCHEMA = {
    "$schema": DRAFT,
    # the shared types the tool's own self-test and --update refer to (data/schemas/*.schema.json all carry them)
    "$defs": {
        "bool": {"type": "boolean"},
        "int": {"type": "integer"},
        "num": {"type": "number"},
        "str": {"type": "string"},
        "hex6": {"type": "string", "pattern": "^[0-9a-fA-F]{6}$"},
    },
    "type": "object",
    "properties": {
        "stomp": {
            "type": "object",
            "properties": {"damage": {"type": "number"}},
            "required": ["damage"],
            "additionalProperties": False,
        }
    },
    "required": ["stomp"],
    "additionalProperties": False,
}
LOOSE = {"$schema": DRAFT, "type": "object"}


def project(root, files):
    """A scratch project with the tool and data/<name>.json + a schema for each (name, data text, schema)."""
    helpers.copy_tool(root, "tools", "lint", "data_schemas.py")
    for name, text, schema in files:
        helpers.write(root, f"data/{name}.json", text)
        if schema is not None:
            helpers.write(root, f"data/schemas/{name}.schema.json", json.dumps(schema))
    return str(root / "tools" / "lint" / "data_schemas.py")


def tuning(data):
    return ("tuning", json.dumps(data), TUNING_SCHEMA)


def check(files, *args):
    with helpers.scratch() as root:
        tool = project(root, files)
        return helpers.run(tool, args, cwd=root, env={"GITHUB_ACTIONS": ""}, isolated=False)


@unittest.skipUnless(HAS_JSONSCHEMA, 'jsonschema is not installed: pip install "jsonschema>=4.18,<5"')
class DataSchemasSmoke(unittest.TestCase):
    def test_matching_file_passes(self):
        exit_code, out = check([tuning({"stomp": {"damage": 5}})])
        self.assertEqual(exit_code, 0, out)
        self.assertIn("ok: 1 data files match their schemas", out)

    def test_wrong_type_fails_by_file_and_key(self):
        exit_code, out = check([tuning({"stomp": {"damage": "five"}})])
        self.assertEqual(exit_code, 1, out)
        self.assertIn("tuning.json: stomp.damage:", out)
        self.assertIn("is not of type 'number'", out)

    def test_unknown_key_fails_and_offers_the_schema_line(self):
        exit_code, out = check([tuning({"stomp": {"damage": 5, "dmg": 2}})])
        self.assertEqual(exit_code, 1, out)
        self.assertIn("unknown key 'dmg'", out)
        self.assertIn("data/schemas/tuning.schema.json", out)

    def test_missing_key_fails(self):
        exit_code, out = check([tuning({"stomp": {}})])
        self.assertEqual(exit_code, 1, out)
        self.assertIn("'damage' is a required property", out)

    def test_data_file_without_schema_fails(self):
        exit_code, out = check([tuning({"stomp": {"damage": 5}}), ("fire", '{"spread": 1}', None)])
        self.assertEqual(exit_code, 1, out)
        self.assertIn("fire.json: no schema", out)

    def test_schema_without_data_file_fails(self):
        with helpers.scratch() as root:
            tool = project(root, [tuning({"stomp": {"damage": 5}})])
            helpers.write(root, "data/schemas/orphan.schema.json", json.dumps(LOOSE))
            exit_code, out = helpers.run(tool, [], cwd=root, env={"GITHUB_ACTIONS": ""}, isolated=False)
        self.assertEqual(exit_code, 1, out)
        self.assertIn("orphan.schema.json: no data/orphan.json to describe", out)

    def test_key_written_twice_fails(self):
        exit_code, out = check([("tuning", '{"stomp": {"damage": 5, "damage": 6}}', TUNING_SCHEMA)])
        self.assertEqual(exit_code, 1, out)
        self.assertIn("the key 'damage' appears twice in one object", out)

    def test_upgrade_requiring_a_missing_upgrade_fails(self):
        good = json.dumps({"upgrades": [{"id": "a"}, {"id": "b", "requires": ["a"]}]})
        bad = json.dumps({"upgrades": [{"id": "a"}, {"id": "b", "requires": ["ghost"]}]})
        exit_code, out = check([("upgrades", good, LOOSE)])
        self.assertEqual(exit_code, 0, out)
        exit_code, out = check([("upgrades", bad, LOOSE)])
        self.assertEqual(exit_code, 1, out)
        self.assertIn("upgrade 'b' requires 'ghost', which does not exist", out)

    def test_repeated_id_fails(self):
        data = json.dumps({"species": [{"id": "reptilian"}, {"id": "reptilian"}]})
        exit_code, out = check([("species", data, LOOSE)])
        self.assertEqual(exit_code, 1, out)
        self.assertIn("species id 'reptilian' appears more than once", out)

    def test_continents_campaign_rules(self):
        def row(cid, stage=0, capital=False, bonuses=None):
            picks = [] if capital else [f"{cid}_{i}" for i in range(3)]
            return {"id": cid, "stage": stage, "capital": capital,
                    "bonuses": picks if bonuses is None else bonuses}
        stages = ("tuning", json.dumps({"growth": {"stages": [{}, {}]}}), LOOSE)

        def run(rows):
            return check([("continents", json.dumps({"continents": rows}), LOOSE), stages])
        exit_code, out = run([row("a"), row("b", 1), row("cap", 1, True)])
        self.assertEqual(exit_code, 0, out)
        bad = {
            "continent id 'a' appears more than once": [row("a"), row("a"), row("cap", 0, True)],
            "'b' stage 2 is not a growth stage (0..1)": [row("a"), row("b", 2), row("cap", 0, True)],
            "'b' offers 2 bonuses, not 3": [row("a"), row("b", 0, False, ["x", "y"]), row("cap", 0, True)],
            "bonus id 'a_0' appears more than once": [row("a"), row("b", 0, False, ["a_0", "y", "z"]),
                                                      row("cap", 0, True)],
            "the capital 'cap' is not the last continent": [row("cap", 0, True), row("a")],
            "2 capitals, not 1": [row("a"), row("c1", 0, True), row("c2", 0, True)],
            "0 capitals, not 1": [row("a"), row("b")],
        }
        for message, rows in bad.items():
            exit_code, out = run(rows)
            self.assertEqual(exit_code, 1, message)
            self.assertIn(message, out)

    def test_own_self_test_plants_defects_and_catches_them(self):
        exit_code, out = check([tuning({"stomp": {"damage": 5}})], "--self-test")
        self.assertEqual(exit_code, 0, out)
        self.assertIn("ok: tuning.json: an unknown key at the top level fails", out)
        self.assertIn("ok: the schemas catch a planted wrong type and a planted unknown key", out)


if __name__ == "__main__":
    unittest.main()
