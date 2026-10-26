# Data schemas

One schema per data file (CLAUDE.md hard rule 4: data is schema-validated): `data/<name>.json` is described by
`data/schemas/<name>.schema.json` (JSON Schema 2020-12). `tools/lint/data_schemas.py` checks all of them in
the CI preflight (`tests.yml`) and in `tools/prepush.sh`; `--self-test` plants a wrong type and an unknown
key in every file and fails unless each is caught.

What a schema fixes: every key a file may hold, its type, and which keys must be present. Unknown keys fail
(a typo no longer reads a default); `_note` / `_doc` style keys (a leading underscore, a string) are always
allowed. Numbers are `num` (an int or a float); a count that must be whole is `int`; a six-digit hex colour is
`hex6`. The checker also fails on a key repeated in one object and on a broken cross-reference (an upgrade
that requires an unknown upgrade or species, a repeated id).

## You added, renamed or removed a key

Run `python tools/lint/data_schemas.py --update`, read `git diff data/schemas`, commit it with your data
change. It allows each key the data now has (typed from its value; in a list of objects it is optional) and
drops each key the data lost. It never touches a wrong type or a bad reference: those are mistakes in the data.
Without the tool, the failure names the file, the path and the line to paste:

    ERROR: tuning.json: city.stream_chunks: unknown key 'stream_extra'; to allow it add to
    data/schemas/tuning.schema.json under that object's properties:  "stream_extra": {"$ref": "#/$defs/num"}

(`--suggest` prints a large key's whole schema.) A new data file needs a schema of the same name in the
same PR (`--update` writes a first one). Ranges are not in the schemas (they are balance, in the data).
