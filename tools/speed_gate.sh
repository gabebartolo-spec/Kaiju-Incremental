# speed_gate.sh: sourced by the scripts that start Godot (tools/run_tests.sh, prepush.sh, check_scripts.sh,
# test_run_tests.sh). Not run on its own.
#
# D-299 (director 2026-10-27, "PC to itself"): while a speed run holds the PC (a C:/kt/BENCH_WINDOW_<owner> flag),
# start no Godot, headless included. wait_speed_gate blocks until the gate script says the PC is free, and a script
# that runs many Godot processes calls it before EVERY one, so a run of 7-20 suites stops between suites instead of
# holding a speed run off for 20-40 minutes (the speed run waits for zero Godot).
#
#   SPEED_GATE=<script>   the gate: exits 0 when the PC is free, 1 after its own wait (wait_window.sh gives up
#                         after 9 min); default C:/kt/wait_window.sh. No such file (CI, Linux): no effect.
SPEED_GATE="${SPEED_GATE:-C:/kt/wait_window.sh}"
wait_speed_gate() {
	[ -f "$SPEED_GATE" ] || return 0
	until bash "$SPEED_GATE"; do sleep 1; done
}
