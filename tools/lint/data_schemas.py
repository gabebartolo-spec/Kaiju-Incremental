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
    python tools/lint/data_schemas.py --suggest    # as the check, with each missing key's whole schema to paste
    python tools/lint/data_schemas.py --update     # allow the keys the data now has, drop the ones it lost (then review the diff)

Adding a key to a data file: add it to the file's schema in the same PR; the failure message prints the
line to paste (data/schemas/README.md). Exit 0 when everything passes, 1 on any failure.
"""
import copy
import glob
import json
import os
import re
import sys

try:
    from jsonschema import Draft202012Validator
except ImportError:  # the one dependency: pip install "jsonschema>=4.18,<5" (MIT)
    print('::error::python package jsonschema is missing: pip install "jsonschema>=4.18,<5"')
    sys.exit(1)

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
MAX_ERRORS = 25  # per file; the rest is a count
FULL = False  # --suggest: print each suggested schema whole, indented


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


HEX6 = re.compile(r"^[0-9a-fA-F]{6}$")
COLOUR_KEY = re.compile(
    r"colou?r|^(body|belly|accent|eye|line|ball|shirt|pants|hair|strip|glass|roof|rail|seam|white|window|under)$"
)
INT_KEY = re.compile(r"^(id|max_level|per_side)$|_count$|^count$")


DEFS = {
    "bool": {"type": "boolean"},
    "int": {"type": "integer"},
    "num": {"type": "number"},
    "str": {"type": "string"},
    "hex6": {"type": "string", "pattern": "^[0-9a-fA-F]{6}$"},
}


def ref(name: str) -> dict:
    return {"$ref": "#/$defs/" + name}


def infer(value, key: str = "") -> dict:
    """The schema a value would get: the type of every leaf, every key required and no other key allowed.

    This is how the schemas in data/schemas were first written, and what a failure message offers for a
    key the schema lacks. Whole numbers are `num` (an int or a float) unless the key is an id or a count;
    a six-digit hex string under a colour-like key is `hex6`; `_`-prefixed keys are documentation.
    """
    if isinstance(value, bool):
        return ref("bool")
    if isinstance(value, int):
        return ref("int") if INT_KEY.search(key) else ref("num")
    if isinstance(value, float):
        return ref("num")
    if isinstance(value, str):
        return ref("hex6") if HEX6.match(value) and COLOUR_KEY.search(key) else ref("str")
    if isinstance(value, list):
        if not value:
            return {"type": "array"}
        item = infer(value[0], key)
        for x in value[1:]:
            item = merge(item, infer(x, key))
        return {"type": "array", "items": item}
    if isinstance(value, dict):
        props = {k: infer(v, k) for k, v in value.items() if not k.startswith("_")}
        if not props:
            return {"type": "object"}
        return {
            "type": "object",
            "properties": props,
            "required": list(props),
            "patternProperties": {"^_": ref("str")},
            "additionalProperties": False,
        }
    return {"type": "null"}


def merge(a: dict, b: dict) -> dict:
    """One schema for two values that sit in the same list (a key is required only if both have it)."""
    if a == b:
        return a
    pair = {a.get("$ref"), b.get("$ref")}
    if pair == {"#/$defs/int", "#/$defs/num"}:
        return ref("num")
    if pair == {"#/$defs/hex6", "#/$defs/str"}:
        return ref("str")
    if a.get("type") == "object" and b.get("type") == "object":
        if "properties" not in a or "properties" not in b:  # an empty one has none of the keys
            full = b if "properties" in b else a
            return {k: v for k, v in full.items() if k != "required"}
        props = {k: merge(a["properties"][k], b["properties"][k]) if k in a["properties"] and k in b["properties"]
                 else a["properties"].get(k) or b["properties"][k] for k in [*a["properties"], *b["properties"]]}
        return {
            "type": "object",
            "properties": props,
            "required": [k for k in props if k in a.get("required", []) and k in b.get("required", [])],
            "patternProperties": {"^_": ref("str")},
            "additionalProperties": False,
        }
    if a.get("type") == "array" and b.get("type") == "array":
        out: dict = {"type": "array"}
        if "items" in a and "items" in b:
            out["items"] = merge(a["items"], b["items"])
        elif "items" in a or "items" in b:
            out["items"] = a.get("items") or b["items"]
        return out
    options = [*(a.get("anyOf") or [a]), *(b.get("anyOf") or [b])]
    unique = [x for i, x in enumerate(options) if x not in options[:i]]
    return unique[0] if len(unique) == 1 else {"anyOf": unique}


def suggest(value, key: str = "") -> str:
    """The schema text to paste for a key a data file has and its schema lacks."""
    if FULL:
        return json.dumps(infer(value, key), ensure_ascii=False, indent=2)
    text = json.dumps(infer(value, key), ensure_ascii=False)
    return text if len(text) <= 600 else text[:600] + " ... (the key is large: python tools/lint/data_schemas.py --suggest)"


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
                f"{name[:-5]}.schema.json under that object's properties:  \"{k}\": {suggest(error.instance[k], k)}"
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
    for t in times.get("play", []):
        if t not in times.get("order", []):
            out.append(f"looks.json: times.play lists '{t}', which is not in times.order")
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


def dump_schema(node, depth: int = 0) -> str:
    """The schemas' own layout: small nodes on one line, keys of larger objects one per line."""
    flat = json.dumps(node, ensure_ascii=False)
    if len(flat) <= 96 or not isinstance(node, (dict, list)):
        return flat
    pad, end = "  " * (depth + 1), "  " * depth
    if isinstance(node, dict):
        rows = [f"{pad}{json.dumps(k, ensure_ascii=False)}: {dump_schema(v, depth + 1)}" for k, v in node.items()]
        return "{\n" + ",\n".join(rows) + "\n" + end + "}"
    if all(isinstance(x, str) for x in node):  # a wrapped list of strings
        lines, cur = [], ""
        for x in node:
            piece = json.dumps(x, ensure_ascii=False) + ", "
            if cur and len(pad + cur + piece) > 100:
                lines.append(cur.rstrip())
                cur = ""
            cur += piece
        lines.append(cur.rstrip().rstrip(","))
        return "[\n" + "\n".join(pad + line for line in lines) + "\n" + end + "]"
    return "[\n" + ",\n".join(pad + dump_schema(x, depth + 1) for x in node) + "\n" + end + "]"


def apply_fixes(data, schema) -> list[str]:
    """Brings a schema in line with its data file: allows each unknown key, drops each key the data no longer has.

    Only those two edits. A wrong type or a bad reference is a mistake in the data and stays an error.
    """
    done: list[str] = []
    for _ in range(4):  # a pass can expose the next layer of errors
        errors = list(Draft202012Validator(schema).iter_errors(data))
        if not any(e.validator in ("additionalProperties", "required") for e in errors):
            break
        for e in errors:
            in_list = any(isinstance(p, int) for p in e.absolute_path)  # items of a list may differ from one another
            if e.validator == "additionalProperties":
                props = e.schema.setdefault("properties", {})
                for k in e.instance:
                    if k not in props and not str(k).startswith("_"):
                        props[k] = infer(e.instance[k], k)
                        if not in_list:
                            e.schema.setdefault("required", []).append(k)
                        done.append(f"{where(e)}: allowed '{k}'")
            elif e.validator == "required":
                for k in [x for x in e.validator_value if x not in e.instance]:
                    if k in e.schema.get("required", []):
                        e.schema["required"].remove(k)
                    if not in_list:  # a key the one object lost is gone; a list item may just lack an optional key
                        e.schema.get("properties", {}).pop(k, None)
                    done.append(f"{where(e)}: {'dropped' if not in_list else 'made optional'} '{k}'")
    return done


def update(root: str) -> int:
    """--update: rewrite each schema so it allows what its data file holds now (review the diff, commit it)."""
    total = 0
    for path in sorted(glob.glob(os.path.join(root, "data", "*.json"))):
        name = os.path.basename(path)
        spath = os.path.join(root, "data", "schemas", name[:-5] + ".schema.json")
        data, _ = load(path)
        if os.path.exists(spath):
            with open(spath, encoding="utf-8") as f:
                schema = json.load(f)
        else:
            schema = {"$schema": "https://json-schema.org/draft/2020-12/schema", "title": f"data/{name}", **infer(data)}
            schema["$defs"] = DEFS
        done = apply_fixes(data, schema)
        if done or not os.path.exists(spath):
            with open(spath, "w", encoding="utf-8", newline="\n") as f:
                f.write(dump_schema(schema) + "\n")
            print(f"{name}: schema updated ({len(done) or 'new file'})")
            for line in done[:40]:
                print(f"  {line}")
            total += 1
    print("schemas up to date" if not total else f"{total} schema files rewritten: review `git diff data/schemas` and commit")
    return 0


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
        if not Draft202012Validator({**infer(data), "$defs": DEFS}).is_valid(data):  # what a failure suggests must itself hold
            print(f"FAIL: the schema inferred from {name} does not validate {name}")
            bad = 1
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
        grown = copy.deepcopy(schema)  # --update must let the file with the planted unknown key pass
        apply_fixes(plants[0][1], grown)
        if check_file(name, plants[0][1], grown):
            print(f"FAIL: {name}: --update did not allow a new top-level key")
            bad = 1
    if bad == 0:
        print("ok: the schemas catch a planted wrong type and a planted unknown key in every data file")
    return bad


def main(argv: list[str]) -> int:
    global FULL
    if "--self-test" in argv:
        return self_test(ROOT)
    if "--update" in argv:
        return update(ROOT)
    FULL = "--suggest" in argv
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
