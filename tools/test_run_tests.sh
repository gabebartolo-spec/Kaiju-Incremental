#!/usr/bin/env bash
# The harness must not report green when it should not. Through tools/run_tests.sh:
#   0. (a fake Godot) the speed-run gate (D-299) and the 6144 MB free-RAM floor (D-317, a stand-in reader): asked before
#      every launch, waited on; no gate file, no change
#   1. the quick smoke suite                                 -> must pass
#   2. a fixture with a _check_ function nobody calls         -> must fail ("functions short")
#   3. a fixture with a _check_ function that makes no check  -> must fail, by name
# (the fixtures are tests/fixtures/run_<name>_tests.gd), and, with Godot directly, that the
# project's typing rules hold:
#   4. tests/fixtures/compile/untyped_var.gd must fail to parse ("has no static type")
#   5. tests/fixtures/compile/typed_ok.gd must parse
set -u
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bad=0
. tools/speed_gate.sh

# D-299 (director 2026-10-27, "PC to itself"): the runner asks the speed-run gate before EVERY Godot
# launch (the version query, the import, each suite), so a run of 7-20 suites stops between suites
# while a speed run holds the PC. No real Godot: a fake one logs each launch next to the gate's calls.
# `tools/test_run_tests.sh speed-gate` runs only this case.
check_speed_gate() {
	local log="$tmp/gate.log" runs="$tmp/gate_runs"
	cat > "$tmp/fake_godot.sh" << 'EOF'
#!/usr/bin/env bash
echo "godot $*" >> "$GATE_LOG"
case "$*" in
*--version*) echo "4.7.2.fake" ;;
*--script*) echo "Fake tests: 1 of 1 functions, 1 checks, 0 failures" ;;
esac
EOF
	cat > "$tmp/gate.sh" << 'EOF'
#!/usr/bin/env bash
n=$(cat "$GATE_COUNT" 2> /dev/null || echo 0)
n=$((n + 1))
echo "$n" > "$GATE_COUNT"
if [ "$n" -le 2 ]; then echo "gate wait $n" >> "$GATE_LOG"; exit 1; fi
echo "gate ok $n" >> "$GATE_LOG"
EOF
	# D-317: a stand-in free-RAM reader (MB), so the cases below never read this PC's real memory
	cat > "$tmp/free_ram.sh" << 'EOF'
#!/usr/bin/env bash
n=$(cat "$RAM_COUNT" 2> /dev/null || echo 0)
n=$((n + 1))
echo "$n" > "$RAM_COUNT"
mb=9999
[ -n "${RAM_LOW_READS:-}" ] && [ "$n" -le "$RAM_LOW_READS" ] && mb=1000
echo "ram $n $mb" >> "$GATE_LOG"
echo "$mb"
EOF
	chmod +x "$tmp/fake_godot.sh" "$tmp/gate.sh" "$tmp/free_ram.sh"
	export RAM_COUNT="$tmp/ram_runs"
	# 1. a gate that fails twice, then passes: the runner waits, and asks again before every launch
	rm -f "$log" "$runs" "$RAM_COUNT"
	GATE_LOG="$log" GATE_COUNT="$runs" SPEED_GATE="$tmp/gate.sh" GODOT="$tmp/fake_godot.sh" FREE_RAM_CMD="bash $tmp/free_ram.sh" \
		SUITES_ONLY=1 tools/run_tests.sh alpha beta > "$tmp/gate_out.txt" 2>&1
	local code=$?
	local before launches unguarded
	before=$(awk '/^godot/ {exit} /^gate/ {n++} END {print n + 0}' "$log" 2> /dev/null)
	launches=$(grep -c '^godot' "$log" 2> /dev/null)
	# a "gate ok" since the previous launch, and no "gate wait" after it
	unguarded=$(awk '/^gate ok/ {g = 1} /^gate wait/ {g = 0} /^godot/ {if (!g) n++; g = 0} END {print n + 0}' "$log" 2> /dev/null)
	if [ "$code" = 0 ] && [ "${before:-0}" -ge 3 ] && [ "$launches" = 4 ] && [ "$unguarded" = 0 ]; then
		echo "ok: the runner waits for the speed-run gate before every Godot launch ($before gate calls before the first)"
	else
		echo "FAIL: the runner must wait for SPEED_GATE before every Godot launch (exit $code, $before gate calls" \
			"before the first launch, want 3 or more; $launches launches, want 4; $unguarded not right after a pass)"
		cat "$log" "$tmp/gate_out.txt" 2> /dev/null
		bad=1
	fi
	# 2. no gate file (CI, Linux): nothing changes - same result, same launches, no wait
	rm -f "$log" "$runs" "$RAM_COUNT"
	GATE_LOG="$log" GATE_COUNT="$runs" SPEED_GATE="$tmp/no_such_gate.sh" GODOT="$tmp/fake_godot.sh" \
		FREE_RAM_CMD="bash $tmp/free_ram.sh" RAM_LOW_READS=3 RAM_POLL_SECS=1 \
		SUITES_ONLY=1 tools/run_tests.sh alpha beta > "$tmp/gate_out_none.txt" 2>&1
	code=$?
	launches=$(grep -c '^godot' "$log" 2> /dev/null)
	# no gate call, no memory read (the stand-in reader would say 1000 MB, below the floor, for 3 reads), one plain line
	if [ "$code" = 0 ] && [ "$launches" = 4 ] && ! grep -qE '^(gate|ram)' "$log" \
		&& [ "$(cat "$tmp/gate_out_none.txt")" = "All checks passed (2 suites)." ]; then
		echo "ok: a missing SPEED_GATE file changes nothing"
	else
		echo "FAIL: a missing SPEED_GATE file must change nothing (exit $code, $launches launches, want 4)"
		cat "$log" "$tmp/gate_out_none.txt" 2> /dev/null
		bad=1
	fi
	# 3. D-317 memory floor: the stand-in reader says 1000 MB twice (floor 6144), then 9999: before the first launch the
	# runner polls (RAM_POLL_SECS), and it counts the wait in its output
	rm -f "$log" "$runs" "$RAM_COUNT"
	echo 99 > "$runs"  # the speed-run gate itself passes at once
	GATE_LOG="$log" GATE_COUNT="$runs" SPEED_GATE="$tmp/gate.sh" GODOT="$tmp/fake_godot.sh" \
		FREE_RAM_CMD="bash $tmp/free_ram.sh" RAM_LOW_READS=2 RAM_POLL_SECS=1 \
		SUITES_ONLY=1 tools/run_tests.sh alpha beta > "$tmp/gate_out_ram.txt" 2>&1
	code=$?
	before=$(awk '/^godot/ {exit} /^ram/ {n++} END {print n + 0}' "$log" 2> /dev/null)
	launches=$(grep -c '^godot' "$log" 2> /dev/null)
	unguarded=$(awk '/^ram/ {r = ($3 >= 6144)} /^godot/ {if (!r) n++; r = 0} END {print n + 0}' "$log" 2> /dev/null)
	local waited
	waited=$(grep -oE '^Waited [0-9]+s' "$tmp/gate_out_ram.txt" | grep -oE '[0-9]+')
	if [ "$code" = 0 ] && [ "${before:-0}" -ge 3 ] && [ "$launches" = 4 ] && [ "$unguarded" = 0 ] && [ "${waited:-0}" -ge 2 ]; then
		echo "ok: the runner waits for 6144 MB of free RAM before every Godot launch ($before reads before the first, waited ${waited}s)"
	else
		echo "FAIL: the runner must wait for 6144 MB free before every Godot launch (exit $code, $before reads before the" \
			"first launch, want 3 or more; $launches launches, want 4; $unguarded without a passing read; waited ${waited:-none} s, want 2 or more)"
		cat "$log" "$tmp/gate_out_ram.txt" 2> /dev/null
		bad=1
	fi
}
check_speed_gate
if [ "${1:-}" = speed-gate ]; then exit "$bad"; fi

if SUITES_ONLY=1 tools/run_tests.sh smoke > "$tmp/out.txt" 2>&1; then echo "ok: the smoke suite passes"; else
	echo "FAIL: the smoke suite should pass"
	cat "$tmp/out.txt"
	bad=1
fi
# The fixtures reuse the import the first run made.
if QUICK=1 RUNNER_DIR=tests/fixtures SUITES_ONLY=1 tools/run_tests.sh uncalled > "$tmp/out.txt" 2>&1; then
	echo "FAIL: a suite with an uncalled test function passed"
	bad=1
elif grep -q "functions short" "$tmp/out.txt" && grep -q "_check_x is never called" "$tmp/out.txt"; then
	echo "ok: an uncalled test function fails the run, by name"
else
	echo "FAIL: the uncalled fixture failed without saying why"
	cat "$tmp/out.txt"
	bad=1
fi
if QUICK=1 RUNNER_DIR=tests/fixtures SUITES_ONLY=1 tools/run_tests.sh nocheck > "$tmp/out.txt" 2>&1; then
	echo "FAIL: a test function with no check passed"
	bad=1
elif grep -q "_check_empty made no checks" "$tmp/out.txt"; then
	echo "ok: a test function with no check fails the run, by name"
else
	echo "FAIL: the no-check fixture failed without saying why"
	cat "$tmp/out.txt"
	bad=1
fi

native_path() {  # Godot on Windows needs a Windows path in APPDATA
	if command -v cygpath > /dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi
}
check_parse() {  # script, expect (fail|pass); isolated like every run
	wait_speed_gate  # D-299: this is a Godot launch too
	APPDATA="$(native_path "$tmp")" XDG_DATA_HOME="$tmp/data" XDG_CONFIG_HOME="$tmp/config" \
		"$GODOT" --headless --path . --check-only --script "$1" > "$tmp/parse.txt" 2>&1
	local code=$?
	if [ "$2" = fail ] && [ "$code" != 0 ] && grep -q "has no static type" "$tmp/parse.txt"; then
		echo "ok: $1 is rejected (untyped declaration)"
	elif [ "$2" = pass ] && [ "$code" = 0 ]; then
		echo "ok: $1 parses"
	else
		echo "FAIL: $1 should $2 to parse (exit $code)"
		cat "$tmp/parse.txt"
		bad=1
	fi
}
check_parse tests/fixtures/compile/untyped_var.gd fail
check_parse tests/fixtures/compile/typed_ok.gd pass
exit "$bad"
