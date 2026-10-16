# Tests

One command runs everything CI runs (import, every suite, the harness self-test):

```sh
GODOT=/path/to/godot_console tools/run_tests.sh            # everything
GODOT=/path/to/godot_console tools/run_tests.sh smoke      # some suites
```

Every run gets its own user data (APPDATA and the XDG dirs point at a temp dir), so two
agents' runs never share saves, settings or caches. The rules are the `game-architecture`
skill §6 and the `kaiju-godot-tests` skill: one runner per suite extending
`tests/lib/runner.gd`; a floor per suite in `expected_checks.txt` that only goes up; a
`SCRIPT ERROR` fails the suite; seeds pinned; a new suite registered in `ALL_SUITES`
(`tools/run_tests.sh`), `tools/ci_shards.txt`, `expected_checks.txt` and the table below.

## Suites

| Suite | Covers | Floor |
|---|---|---:|
| `smoke` | typing warnings are errors; exactly the sanctioned autoloads; every script compiles; the main scene opens headless and stays up | 9 |

The harness self-test (`tools/test_run_tests.sh`) proves the runner fails a suite short of
its floor or without one, and that an untyped declaration does not compile.
