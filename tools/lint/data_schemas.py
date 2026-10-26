#!/usr/bin/env python3
"""Every data/*.json file is checked against its schema in data/schemas/ (CLAUDE.md hard rule 4).

Debt row 5 (D-295, 2026-10-27). The schema for data/<name>.json is data/schemas/<name>.schema.json
(JSON Schema 2020-12, validated with the `jsonschema` library, MIT). A schema lists every key a file
may hold and its type, so a misspelled key, a missing key or a number written as a string fails here
instead of silently reading a default in the game. The check also fails on a repeated key in one
object (JSON keeps the last one without a word) and on a broken cross-reference between the files
(an upgrade that requires an upgrade that does not exist, an unknown species, a repeated id).

    python tools/lint/data_schemas.py              # check data/*.json (CI preflight, tools/prepush.sh)
    python tools/lint/data_schemas.py --self-test  # plant a wrong type and an unknown key in each file

Adding a key to a data file: add it to the file's schema in the same PR; the failure message prints the
line to paste (data/schemas/README.md). Exit 0 when everything passes, 1 on any failure.
"""
import copy
import glob
import json
import os
import sys

try:
    from jsonschema import Draft202012Validator
except ImportError:  # the one dependency: pip install "jsonschema>=4.18,<5" (MIT)
    print('::error::python package jsonschema is missing: pip install "jsonschema>=4.18,<5"')
    sys.exit(1)

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
MAX_ERRORS = 25  # per file; the rest is a count


def load(path: str):
    """The parsed JSON and a list of repeated keys (object path, key)."""
    repeats: list[str] = []

    def pairs(items):
        seen: dict = {}
        for k, v in items:
            if k in seen:
                repeats.append(k)
            seen[k] = v
        return seen

    with open(path, encoding="utf-8") as f:
        return json.load(f, object_pairs_hook=pairs), repeats


def suggest(value) -> str:
    """The schema line for a key a data file has and its schema lacks."""
    if isinstance(value, bool):
        return '{"$ref": "#/$defs/bool"}'
    if isinstance(value, (int, float)):
        return '{"$ref": "#/$defs/num"}'
    if isinstance(value, str):
        return '{"$ref": "#/$defs/str"}'
    if isinstance(value, list):
        return '{"type": "array"}'
    return '{"type": "object"}'


def where(error) -> str:
    return ".".join(str(p) for p in error.absolute_path) or "(top level)"


def describe(error, name: str) -> list[str]:
    """One or more printable lines for a validation error."""
    if error.validator == "additionalProperties":
        props = set(error.schema.get("properties", {}))
        extra = [k for k in error.instance if k not in props and not str(k).startswith("_")]
        lines = []
        for k in extra:
            lines.append(
                f"{name}: {where(error)}: unknown key '{k}'; to allow it add to data/schemas/"
                f"{name[:-5]}.schema.json under that object's properties:  \"{k}\": {suggest(error.instance[k])}"
            )
        return lines or [f"{name}: {where(error)}: {error.message}"]
    return [f"{name}: {where(error)}: {error.message[:200]}"]


def check_file(name: str, data, schema) -> list[str]:
    problems: list[str] = []
    errors = sorted(Draft202012Validator(schema).iter_errors(data), key=lambda e: list(map(str, e.absolute_path)))
    for e in errors[:MAX_ERRORS]:
        problems += describe(e, name)
    if len(errors) > MAX_ERRORS:
        problems.append(f"{name}: and {len(errors) - MAX_ERRORS} more")
    return problems


def cross_checks(datas: dict) -> list[str]:
    """References between the data files that a per-file schema cannot see."""
    out: list[str] = []

    def unique(file: str, ids: list, what: str) -> None:
        for i in sorted({x for x in ids if ids.count(x) > 1}, key=str):
            out.append(f"{file}: {what} id '{i}' appears more than once")

    species = [s.get("id") for s in datas.get("species.json", {}).get("species", [])]
    unique("species.json", species, "species")
    ups = datas.get("upgrades.json", {}).get("upgrades", [])
    up_ids = [u.get("id") for u in ups]
    unique("upgrades.json", up_ids, "upgrade")
    for u in ups:
        for r in u.get("requires", []):
            if r not in up_ids:
                out.append(f"upgrades.json: upgrade '{u.get('id')}' requires '{r}', which does not exist")
        sp = u.get("species")
        for s in sp if isinstance(sp, list) else ([sp] if sp else []):
            if s not in species:
                out.append(f"upgrades.json: upgrade '{u.get('id')}' names unknown species '{s}'")
        for key in ("species_desc", "species_effects"):
            for s in u.get(key, {}):
                if s not in species:
                    out.append(f"upgrades.json: upgrade '{u.get('id')}' {key} names unknown species '{s}'")
    unique("materials.json", [m.get("id") for m in datas.get("materials.json", {}).get("materials", [])], "material")
    unique("sports.json", [s.get("id") for s in datas.get("sports.json", {}).get("sports", [])], "sport")
    looks = datas.get("looks.json", {})
    look_ids = [x.get("id") for x in looks.get("looks", [])]
    unique("looks.json", look_ids, "look")
    if looks and looks.get("default") not in look_ids:
        out.append(f"looks.json: default look '{looks.get('default')}' is not in looks")
    times = looks.get("times", {})
    for t in times.get("order", []):
        if t not in times:
            out.append(f"looks.json: times.order lists '{t}', which has no entry in times")
    return out


def run_checks(root: str) -> tuple[list[str], int]:
    problems: list[str] = []
    datas: dict = {}
    files = sorted(glob.glob(os.path.join(root, "data", "*.json")))
    schema_dir = os.path.join(root, "data", "schemas")
    for path in files:
        name = os.path.basename(path)
        data, repeats = load(path)
        datas[name] = data
        for k in sorted(set(repeats)):
            problems.append(f"{name}: the key '{k}' appears twice in one object (the second silently wins)")
        schema_path = os.path.join(schema_dir, name[:-5] + ".schema.json")
        if not os.path.exists(schema_path):
            problems.append(f"{name}: no schema; add data/schemas/{name[:-5]}.schema.json (data/schemas/README.md)")
            continue
        with open(schema_path, encoding="utf-8") as f:
            schema = json.load(f)
        Draft202012Validator.check_schema(schema)
        problems += check_file(name, data, schema)
    for path in sorted(glob.glob(os.path.join(schema_dir, "*.schema.json"))):
        stem = os.path.basename(path)[: -len(".schema.json")]
        if not os.path.exists(os.path.join(root, "data", stem + ".json")):
            problems.append(f"data/schemas/{stem}.schema.json: no data/{stem}.json to describe")
    problems += cross_checks(datas)
    return problems, len(files)


def leaves(node, path=()):
    """Every scalar leaf of a parsed JSON value as (path, value)."""
    if isinstance(node, dict):
        for k, v in node.items():
            yield from leaves(v, path + (k,))
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from leaves(v, path + (i,))
    else:
        yield path, node


def put(node, path, value) -> None:
    for p in path[:-1]:
        node = node[p]
    node[path[-1]] = value


def self_test(root: str) -> int:
    """Plants a wrong type and an unknown key in each data file; each must fail, the real file must pass."""
    bad = 0
    for path in sorted(glob.glob(os.path.join(root, "data", "*.json"))):
        name = os.path.basename(path)
        data, _ = load(path)
        with open(os.path.join(root, "data", "schemas", name[:-5] + ".schema.json"), encoding="utf-8") as f:
            schema = json.load(f)
        if check_file(name, data, schema):
            print(f"FAIL: the real {name} does not pass its own schema")
            bad = 1
            continue
        plants: list[tuple[str, object]] = []
        unknown = copy.deepcopy(data)
        unknown["zz_planted_key"] = 1  # at the top level
        plants.append(("an unknown key at the top level", unknown))
        nested = copy.deepcopy(data)
        first = next((p for p, v in leaves(nested) if len(p) >= 2 and isinstance(p[-1], str)), None)
        if first is not None:  # beside the first leaf that sits inside an object
            parent = nested
            for p in first[:-1]:
                parent = parent[p]
            parent["zz_planted_key"] = 1
            plants.append(("an unknown key inside an object", nested))
        for kind, wanted, replacement in (
            ("a number written as a string", (int, float), "planted"),
            ("a string written as a number", str, 12345),
            ("a flag written as a string", bool, "planted"),
        ):
            copy_ = copy.deepcopy(data)
            hit = next(
                (
                    p
                    for p, v in leaves(copy_)
                    if p
                    and isinstance(v, wanted)
                    and (wanted is bool or not isinstance(v, bool))
                    and not str(p[-1]).startswith("_")
                ),
                None,
            )
            if hit is not None:
                put(copy_, hit, replacement)
                plants.append((kind, copy_))
        for what, planted in plants:
            if check_file(name, planted, schema):
                print(f"ok: {name}: {what} fails")
            else:
                print(f"FAIL: {name}: {what} passed its schema")
                bad = 1
    if bad == 0:
        print("ok: the schemas catch a planted wrong type and a planted unknown key in every data file")
    return bad


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test(ROOT)
    problems, n_files = run_checks(ROOT)
    for line in problems:
        print(f"::error::{line}" if os.environ.get("GITHUB_ACTIONS") else f"ERROR: {line}")
    if problems:
        print(f"data schemas: {len(problems)} problems in {n_files} data files")
        return 1
    print(f"ok: {n_files} data files match their schemas, no repeated keys, references resolve")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
