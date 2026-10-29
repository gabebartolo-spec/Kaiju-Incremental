extends SceneTree
## Base for every suite runner. A suite is one file, tests/run_<suite>_tests.gd, that
## starts with `extends "res://tests/lib/runner.gd"`, overrides suite_name() and
## run_checks(), keeps its tests in `_check_*` methods that run_checks() calls through
## `await _t("_check_name")` (and tests/lib helpers through `await _h(...)`), and calls
## check() once per check. The base prints "<Suite> tests: K of M functions, N checks,
## F failures" (tests/lib/functions_ran.gd; tools/run_tests.sh reads that line) and quits
## non-zero when any check failed. A `_check_*` method never called, or a test that made no
## check, is a failure by name; there is no floor file to keep (director 2026-10-19). CI runs the
## heaviest suites in parts, each a share of the `_t`/`_h` calls (`-- --part=K/N`, see
## tests/lib/functions_ran.gd part()): make no check outside `_t` and `_h` in such a suite.
##   godot --headless --path . --script tests/run_<suite>_tests.gd

const Ran := preload("res://tests/lib/functions_ran.gd")

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	# A test that drops a RampageSim without dispose() would leak it at the exit (debt row 2):
	# the quit cuts every sim's rings, so no test has to remember.
	QuitGame.release_sims_at_exit(self)
	SaveFile.pinned_seed = 0  # a kaiju made through the lab plays the same cities every run
	_start.call_deferred()


func _start() -> void:
	# Autoloads are in the tree once the first frame has run.
	await process_frame
	await run_checks()
	print(Ran.line(suite_name(), self))
	# A menu sound still playing (Sfx.ui) at the quit leaks its stream and playbacks (debt row 2).
	await QuitGame.settle_audio(self)
	quit(0 if _failures.is_empty() else 1)


## The name in the summary line, e.g. "Data".
func suite_name() -> String:
	return "Unnamed"


## Which part of a suite split in CI (tools/ci_timings.txt "split") runs a call: 0 to parts - 1.
## The default deals the calls out in turn; a suite with a few long calls overrides it to balance
## its parts, by the call's label (`_check_x`, or the `_h` label). Pure: the same answer in every
## part.
func part_for(_label: String, index: int, parts: int) -> int:
	return index % parts


## Each suite overrides this: one `await _t("_check_x")` per test function.
func run_checks() -> void:
	await process_frame


## Runs one test function; it must make at least one check (tests/lib/functions_ran.gd).
func _t(test: String, args: Array = []) -> Variant:
	return await Ran.one(self, test, args)


## Runs one tests/lib helper; it must make at least one check.
func _h(label: String, run: Callable) -> void:
	await Ran.helper(self, label, run)


## Records one check. `expectation` says what should be true; a failure prints
## "FAIL: <expectation>" so tools/run_tests.sh and CI can show it without the full log.
func check(condition: bool, expectation: String) -> void:
	_checks += 1
	Ran.check_stray(self, expectation)
	if not condition:
		_failures.append(expectation)
		printerr("FAIL: " + expectation)
