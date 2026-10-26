extends SceneTree
## Render plan item 7 (render_opt.people_buffers): what the whole crowd costs a frame with the
## people placed natively and written as buffers (StreetDraw, KaijuBuckets) against the
## GDScript per-instance setters, in ONE process. Refuses to run without the native library.
## Two seeded streets (same people, same steps) run in turn: frames go in threes (one street
## steps, the other steps, nothing steps), the order swapping every cycle so a busy PC hits both
## alike. A frame's cost is the time from the end of the last frame to the end of this one (the
## street's own step, then the engine's box pass and buffer upload for what changed); the crowd's
## cost is that minus the idle frame's. Needs the real renderer (not headless: the dummy server
## ignores MultiMesh writes).
##
##   <engine> --path . --windowed --resolution 1280x720 --fixed-fps 60 --disable-vsync \
##     --script tools/capture/bench_people_buffers.gd -- [--tier=3] [--cycles=600]

const Replay := preload("res://tests/lib/street_replay.gd")
const WARMUP := 60  # cycles

var _tier := 3
var _preset := "medium"
var _cycles := 600


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tier="):
			_tier = arg.substr(7).to_int()
		elif arg.begins_with("--preset="):
			_preset = arg.substr(9)
		elif arg.begins_with("--cycles="):
			_cycles = arg.substr(9).to_int()
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var runs: Array[Replay] = [
		Replay.new(self, _tier, _preset, false), Replay.new(self, _tier, _preset, true)
	]
	if runs[1].street._draw == null:
		printerr("BENCH_PEOPLE KaijuBuckets is not registered: both runs would be the setters")
		quit(2)
		return
	print(
		(
			"BENCH_PEOPLE people=%d tier=%d preset=%s cycles=%d adapter=%s"
			% [
				runs[0].street.pos.size(),
				_tier,
				_preset,
				_cycles,
				RenderingServer.get_video_adapter_name()
			]
		)
	)
	# Per mode (0 = off, 1 = on): the frame's wall time, StreetLife's own step, the crowd's draw (ms).
	var wall: Array[PackedFloat64Array] = [PackedFloat64Array(), PackedFloat64Array()]
	var step: Array[PackedFloat64Array] = [PackedFloat64Array(), PackedFloat64Array()]
	var draw: Array[PackedFloat64Array] = [PackedFloat64Array(), PackedFloat64Array()]
	var idle := PackedFloat64Array()
	for c: int in WARMUP + _cycles:
		var order := PackedInt32Array([0, 1, -1]) if c % 2 == 0 else PackedInt32Array([1, 0, -1])
		for m: int in order:
			var t0 := Time.get_ticks_usec()
			var s0 := 0
			var d0 := 0
			if m >= 0:
				s0 = runs[m].street.total_usec
				d0 = _draw_usec(runs[m])
				runs[m].step()
			var stepped := Time.get_ticks_usec()
			await process_frame
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			if c < WARMUP:
				continue
			if m < 0:
				idle.append(ms)
			else:
				wall[m].append(ms)
				step[m].append((stepped - t0) / 1000.0)
				draw[m].append((_draw_usec(runs[m]) - d0) / 1000.0)
	var base := _mean(idle)
	print("BENCH_PEOPLE idle frame mean %.3f p50 %.3f ms" % [base, _pct(idle, 0.5)])
	var cost: Array[float] = [0.0, 0.0]
	for m: int in 2:
		cost[m] = _mean(wall[m]) - base
		print(
			(
				"BENCH_PEOPLE %s crowd mean %.3f p50 %.3f p95 %.3f | step mean %.3f | native draw %.3f ms"
				% [
					"on " if m == 1 else "off",
					cost[m],
					_pct(wall[m], 0.5) - _pct(idle, 0.5),
					_pct(wall[m], 0.95) - _pct(idle, 0.5),
					_mean(step[m]),
					_mean(draw[m])
				]
			)
		)
	print(
		(
			"BENCH_PEOPLE on vs off: whole crowd %+.1f%%, street step %+.1f%%"
			% [100.0 * (cost[1] / cost[0] - 1.0), 100.0 * (_mean(step[1]) / _mean(step[0]) - 1.0)]
		)
	)
	print("BENCH_PEOPLE same people: %s" % (runs[0].digest() == runs[1].digest()))
	for r: Replay in runs:
		r.finish()
	quit(0)


## Microseconds the native draw has taken so far (0 for the setters' run, which has none).
func _draw_usec(r: Replay) -> int:
	return r.street._draw.buckets.usec if r.street._draw != null else 0


func _mean(a: PackedFloat64Array) -> float:
	var s := 0.0
	for v: float in a:
		s += v
	return s / maxf(a.size(), 1.0)


func _pct(a: PackedFloat64Array, p: float) -> float:
	var sorted := a.duplicate()
	sorted.sort()
	return sorted[clampi(ceili(p * sorted.size()) - 1, 0, sorted.size() - 1)]
