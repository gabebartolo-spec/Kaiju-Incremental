extends RefCounted
## Every test function ran and made at least one check. This replaced the check-count
## floors in tests/expected_checks.txt (director 2026-10-19, github-hygiene §4): a new test
## counts itself, so no PR edits a shared file of counts and two PRs never conflict over one.
##
## A suite (tests/lib/runner.gd) calls each of its `_check_*` methods through `_t`, and each
## test helper from tests/lib through `_h`:
##
##   await _t("_check_data")
##   await _t("_check_powers", ["reptilian", "breath", UPGRADED])
##   await _h("FlowStadium", func() -> void: await FlowStadium.run(self, check))
##
## and the base prints `Ran.line(...)`: "<Suite> tests: K of M functions, N checks,
## F failures". The line fails, by name, every `_check_*` method the suite defines but never
## called; tools/run_tests.sh fails a suite whose line is short of functions or carries no
## function count at all.

const _CALLED := "_tests_called"
const PREFIX := "_check_"


## Runs suite.test(args...), records that it ran, and fails it by name when it made no
## check: an empty loop or an early return no longer passes quietly.
static func one(suite: Object, test: String, args: Array = []) -> Variant:
	_record(suite, test)
	if not suite.has_method(test):
		_fail(suite, "%s is called but not defined" % test)
		return null
	var before: int = _checks(suite)
	var result: Variant = await suite.callv(test, args)
	if _checks(suite) == before:
		_fail(suite, "%s made no checks" % test)
	return result


## Runs a helper (a tests/lib class) the same way: it must make at least one check.
static func helper(suite: Object, label: String, run: Callable) -> void:
	_record(suite, label)
	var before: int = _checks(suite)
	await run.call()
	if _checks(suite) == before:
		_fail(suite, "%s made no checks" % label)


## The suite's summary line. Every `_check_*` method the suite defines and never ran
## through one() fails here, by name, first.
static func line(label: String, suite: Object) -> String:
	var called: Array = suite.get_meta(_CALLED, [])
	var ran: int = 0
	var defined: Array[String] = defined_tests(suite)
	for test: String in defined:
		if called.has(test):
			ran += 1
		else:
			_fail(suite, '%s is never called: add await _t("%s") to run_checks()' % [test, test])
	return (
		"%s tests: %d of %d functions, %d checks, %d failures"
		% [label, ran, defined.size(), _checks(suite), _failures(suite).size()]
	)


## Every `_check_*` method the suite's own script defines.
static func defined_tests(suite: Object) -> Array[String]:
	var names: Array[String] = []
	var script: Script = suite.get_script()
	if script == null:
		return names
	for method: Dictionary in script.get_script_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with(PREFIX) and not names.has(method_name):
			names.append(method_name)
	return names


static func _record(suite: Object, test: String) -> void:
	var called: Array = suite.get_meta(_CALLED, [])
	called.append(test)
	suite.set_meta(_CALLED, called)


static func _checks(suite: Object) -> int:
	var value: Variant = suite.get("_checks")
	if value is int:
		return value
	return 0


static func _failures(suite: Object) -> Array:
	var value: Variant = suite.get("_failures")
	if value is Array:
		return value
	return []


static func _fail(suite: Object, message: String) -> void:
	_failures(suite).append(message)
	printerr("FAIL: " + message)
