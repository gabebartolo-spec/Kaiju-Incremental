# speed_gate.sh: sourced by the scripts that start Godot (tools/run_tests.sh, prepush.sh, check_scripts.sh,
# test_run_tests.sh). Not run on its own.
#
# D-299 (director 2026-10-27, "PC to itself"): while a speed run holds the PC (a C:/kt/BENCH_WINDOW_<owner> flag),
# start no Godot, headless included. wait_speed_gate blocks until the gate script says the PC is free, and a script
# that runs many Godot processes calls it before EVERY one, so a run of 7-20 suites stops between suites instead of
# holding a speed run off for 20-40 minutes (the speed run waits for zero Godot).
# D-317 (director 2026-10-27, "keep the memory floor"): the same call also waits until at least MIN_FREE_MB of RAM is
# free (the freeze guard; the 85% CPU cap is off for the night shift).
#
#   SPEED_GATE=<script>   the gate: exits 0 when the PC is free, 1 after its own wait (wait_window.sh gives up
#                         after 9 min); default C:/kt/wait_window.sh. No such file (CI, Linux): no effect at all,
#                         the memory floor included (it is this PC's rule).
#   MIN_FREE_MB=<n>       the memory floor, default 6144 (6 GB); RAM_POLL_SECS=<n> between reads, default 5.
#   FREE_RAM_CMD=<cmd>    prints the free RAM in MB (default: Windows free physical memory through powershell).
#                         A reader that prints nothing or a non-number counts as enough RAM: it never blocks.
#   SPEED_GATE_WAITED     seconds all waits took so far; each launch that had to wait prints one "speed_gate:" line,
#                         and the runner prints the total at the end (a wait is not part of a suite's time).
SPEED_GATE="${SPEED_GATE:-C:/kt/wait_window.sh}"
MIN_FREE_MB="${MIN_FREE_MB:-6144}"
RAM_POLL_SECS="${RAM_POLL_SECS:-5}"
SPEED_GATE_WAITED=0
free_ram_mb() {
	if [ -n "${FREE_RAM_CMD:-}" ]; then
		bash -c "$FREE_RAM_CMD" 2> /dev/null | tr -d '\r' | head -n 1
	elif command -v powershell > /dev/null 2>&1; then
		powershell -NoProfile -Command "[math]::Floor((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1KB)" 2> /dev/null | tr -d '\r\n'
	fi
}
wait_speed_gate() {
	[ -f "$SPEED_GATE" ] || return 0
	local t0 free why="" waiting=0
	t0=$(date +%s)
	while true; do
		until bash "$SPEED_GATE"; do waiting=1; why=", a speed run holds the PC"; sleep 1; done
		free=$(free_ram_mb)
		case "$free" in '' | *[!0-9]*) break ;; esac
		[ "$free" -ge "$MIN_FREE_MB" ] && break
		waiting=1
		why=", free RAM ${free} MB is under ${MIN_FREE_MB} MB"
		sleep "$RAM_POLL_SECS"
	done
	[ "$waiting" = 1 ] || return 0  # a read that passed at once is not a wait
	local waited=$(($(date +%s) - t0))
	SPEED_GATE_WAITED=$((SPEED_GATE_WAITED + waited))
	echo "speed_gate: waited ${waited}s before a Godot launch${why}"
}
