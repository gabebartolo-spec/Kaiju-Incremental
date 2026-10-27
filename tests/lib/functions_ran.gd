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
const _FIRST := "_tests_first"
const _INDEX := "_tests_index"
const _PART := "_tests_part"
const _RAN_CALLS := "_tests_ran_calls"
const _OPEN := "_tests_open"
const PREFIX := "_check_"
const PART_ARG := "--part="


## Runs suite.test(args...), records that it ran, and fails it by name when it made no
## check: an empty loop or an early return no longer passes quietly. In a split run (see
## part()) a call that belongs to another part is skipped here and returns null.
static func one(suite: Object, test: String, args: Array = []) -> Variant:
	if not _claim(suite, test):
		return null
	var started: int = Time.get_ticks_msec()
	if not suite.has_method(test):
		_fail(suite, "%s is called but not defined" % test)
		return null
	var before: int = _checks(suite)
	_depth(suite, 1)
	var result: Variant = await suite.callv(test, args)
	_depth(suite, -1)
	if _checks(suite) == before:
		_fail(suite, "%s made no checks" % test)
	_timed(suite, test, started)
	return result


## Runs a helper (a tests/lib class) the same way: it must make at least one check.
static func helper(suite: Object, label: String, run: Callable) -> void:
	if not _claim(suite, label):
		return
	var started: int = Time.get_ticks_msec()
	var before: int = _checks(suite)
	_depth(suite, 1)
	await run.call()
	_depth(suite, -1)
	if _checks(suite) == before:
		_fail(suite, "%s made no checks" % label)
	_timed(suite, label, started)


## A suite runs split in CI when tools/ci_timings.txt has a "split <suite> <n>" line: the same
## runner starts n times with `-- --part=K/N` (tools/run_tests.sh "<suite>@K/N"), and part K runs
## the calls of run_checks() (every _t and _h, counted in the order they are reached) that
## part_for() gives to part K, by default those whose position is K-1 modulo N. Every call
## runs in exactly one part, so the parts together make
## exactly the checks the whole suite makes. x = K, y = N, z = 1 when the argument was given.
## Anything run_checks() does outside _t and _h runs in every part, so a check made there fails
## a split run (check_stray).
static func part(suite: Object) -> Vector3i:
	if suite.has_meta(_PART):
		return suite.get_meta(_PART)
	var found := Vector3i(1, 1, 0)
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with(PART_ARG):
			continue
		var bits: PackedStringArray = arg.trim_prefix(PART_ARG).split("/")
		var k: int = int(bits[0]) if bits.size() == 2 and bits[0].is_valid_int() else 0
		var n: int = int(bits[1]) if bits.size() == 2 and bits[1].is_valid_int() else 0
		if k < 1 or n < 1 or k > n:
			_fail(suite, "bad %s: want %sK/N with 1 <= K <= N" % [arg, PART_ARG])
			continue
		found = Vector3i(k, n, 1)
	suite.set_meta(_PART, found)
	return found


## Fails a check made outside any _t or _h call in a split run (it would run once per part).
static func check_stray(suite: Object, expectation: String) -> void:
	if part(suite).y > 1 and _in_call(suite) == 0:
		_fail(
			suite, "a check outside _t and _h runs in every part of a split suite: " + expectation
		)


## The suite's summary line. Every `_check_*` method the suite defines and never ran
## through one() fails here, by name, first. A split part counts a function once, in the part that
## ran its first call, so the parts' "K of M functions" add up to the whole suite's.
static func line(label: String, suite: Object) -> String:
	var called: Array = suite.get_meta(_CALLED, [])
	var first: Dictionary = suite.get_meta(_FIRST, {})
	var split: bool = part(suite).y > 1
	var ran: int = 0
	var counted: int = 0
	for test: String in defined_tests(suite):
		if not called.has(test):
			_fail(suite, '%s is never called: add await _t("%s") to run_checks()' % [test, test])
			counted += 1
		elif not split or first.get(test, false):
			ran += 1
			counted += 1
	var text: String = (
		"%s tests: %d of %d functions, %d checks, %d failures"
		% [label, ran, counted, _checks(suite), _failures(suite).size()]
	)
	if split:
		var p: Vector3i = part(suite)
		text += " (part %d of %d: %d of %d calls)" % [p.x, p.y, _ran_calls(suite), _index(suite)]
	return text


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


## Which part (0-based) runs a call: the suite's part_for(label, index, parts), by default the
## call's position modulo the part count. A suite whose calls differ a lot in length overrides
## part_for (tests/lib/runner.gd) to balance its parts by name; it must answer the same in every
## part.
static func _owner(suite: Object, label: String, index: int, parts: int) -> int:
	var owner: int = index % parts
	if parts > 1 and suite.has_method("part_for"):
		owner = suite.call("part_for", label, index, parts)
		if owner < 0 or owner >= parts:
			_fail(
				suite,
				"part_for(%s) says part %d of %d: want 0 to %d" % [label, owner, parts, parts - 1]
			)
			owner = index % parts
	return owner


## Notes that the suite reached this call, and says whether this process runs it: always when the
## suite is not split, else when the call belongs to this part.
static func _claim(suite: Object, label: String) -> bool:
	var index: int = _index(suite)
	suite.set_meta(_INDEX, index + 1)
	var p: Vector3i = part(suite)
	var mine: bool = _owner(suite, label, index, p.y) == p.x - 1
	var first: Dictionary = suite.get_meta(_FIRST, {})
	if not first.has(label):
		first[label] = mine
		suite.set_meta(_FIRST, first)
	var called: Array = suite.get_meta(_CALLED, [])
	called.append(label)
	suite.set_meta(_CALLED, called)
	if mine:
		suite.set_meta(_RAN_CALLS, _ran_calls(suite) + 1)
	return mine


static func _index(suite: Object) -> int:
	return suite.get_meta(_INDEX, 0)


static func _ran_calls(suite: Object) -> int:
	return suite.get_meta(_RAN_CALLS, 0)


## How many _t or _h calls are open right now (they do not nest in practice, but a count is safe).
static func _depth(suite: Object, change: int) -> void:
	suite.set_meta(_OPEN, _in_call(suite) + change)


static func _in_call(suite: Object) -> int:
	return suite.get_meta(_OPEN, 0)


## One line per call run with --part=..., so a split can be balanced from a --part=1/1 run.
static func _timed(suite: Object, label: String, started: int) -> void:
	if part(suite).z == 1:
		print("CALL %d %s %d ms" % [_index(suite), label, Time.get_ticks_msec() - started])


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
