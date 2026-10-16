extends SceneTree
## Base for every suite runner. A suite is one file, tests/run_<suite>_tests.gd, that
## starts with `extends "res://tests/lib/runner.gd"`, overrides suite_name() and
## run_checks(), and calls check() once per check. The base prints
## "<Suite> tests: N checks, M failures" (tools/run_tests.sh reads that line) and quits
## non-zero when any check failed.
##   godot --headless --path . --script tests/run_<suite>_tests.gd

var _checks: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	# Autoloads are in the tree once the first frame has run.
	await process_frame
	await run_checks()
	print("%s tests: %d checks, %d failures" % [suite_name(), _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


## The name in the summary line, e.g. "Data".
func suite_name() -> String:
	return "Unnamed"


## Each suite overrides this. It may await (scene checks wait for frames).
func run_checks() -> void:
	await process_frame


## Records one check. `expectation` says what should be true; a failure prints
## "FAIL: <expectation>" so tools/run_tests.sh and CI can show it without the full log.
func check(condition: bool, expectation: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(expectation)
		printerr("FAIL: " + expectation)
