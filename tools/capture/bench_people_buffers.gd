extends SceneTree
## Render plan item 7 (render_opt.people_buffers): the street's per-frame cost with the crowd
## written as buffers against the per-instance setters, in ONE process with the two runs stepped
## side by side (same seed, same people, alternating which goes first each frame), so a busy PC
## hits both alike. Needs the real renderer (not headless: the dummy server ignores MultiMesh
## writes). Prints BENCH_PEOPLE lines: StreetLife's whole frame (total_usec) and the crowd's draw
## alone (the buckets' begin-to-commit time), per frame in ms, off then on.
##
##   <engine> --path . --windowed --resolution 1280x720 --fixed-fps 60 \
##     --script tools/capture/bench_people_buffers.gd -- [--tier=3] [--frames=600]

const Replay := preload("res://tests/lib/street_replay.gd")
const WARMUP := 120

var _tier := 3
var _preset := "medium"
var _frames := 600


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tier="):
			_tier = arg.substr(7).to_int()
		elif arg.begins_with("--preset="):
			_preset = arg.substr(9)
		elif arg.begins_with("--frames="):
			_frames = arg.substr(9).to_int()
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var runs: Array[Replay] = [
		Replay.new(self, _tier, _preset, false), Replay.new(self, _tier, _preset, true)
	]
	print(
		(
			"BENCH_PEOPLE people=%d tier=%d preset=%s frames=%d"
			% [runs[0].street.pos.size(), _tier, _preset, _frames]
		)
	)
	# Per mode (0 = off, 1 = on): StreetLife's frame and the crowd's draw, in ms.
	var total: Array[PackedFloat64Array] = [PackedFloat64Array(), PackedFloat64Array()]
	var draw: Array[PackedFloat64Array] = [PackedFloat64Array(), PackedFloat64Array()]
	var boxes: Array[PackedFloat64Array] = [PackedFloat64Array(), PackedFloat64Array()]
	for f: int in WARMUP + _frames:
		for k: int in 2:
			var m := k if f % 2 == 0 else 1 - k  # which mode steps first alternates
			var street := runs[m].street
			var t0 := street.total_usec
			var d0 := street._buckets.usec
			runs[m].step()
			if f >= WARMUP:
				total[m].append((street.total_usec - t0) / 1000.0)
				draw[m].append((street._buckets.usec - d0) / 1000.0)
				boxes[m].append(_box_ms(street))
		await process_frame
	for m: int in 2:
		var mode := "on " if m == 1 else "off"
		print(
			(
				"BENCH_PEOPLE %s street mean %.3f p50 %.3f p95 %.3f | draw mean %.3f p50 %.3f p95 %.3f ms"
				% [
					mode,
					_mean(total[m]),
					_pct(total[m], 0.5),
					_pct(total[m], 0.95),
					_mean(draw[m]),
					_pct(draw[m], 0.5),
					_pct(draw[m], 0.95)
				]
			)
		)
	print(
		(
			"BENCH_PEOPLE on vs off: street %+.1f%%, draw %+.1f%%, draw is %.1f%% of street (off)"
			% [
				100.0 * (_mean(total[1]) / _mean(total[0]) - 1.0),
				100.0 * (_mean(draw[1]) / _mean(draw[0]) - 1.0),
				100.0 * _mean(draw[0]) / _mean(total[0])
			]
		)
	)
	for m: int in 2:
		print("BENCH_PEOPLE %s engine box pass mean %.3f ms" % [m, _mean(boxes[m])])
	print("BENCH_PEOPLE same people: %s" % (runs[0].digest() == runs[1].digest()))
	for r: Replay in runs:
		r.finish()
	quit(0)


## What the engine does each frame for a changed MultiMesh: asks its box, rebuilt over every
## instance slot unless a custom one is set. Asked here, in ms, so it counts as the street's.
func _box_ms(street: StreetLife) -> float:
	var t0 := Time.get_ticks_usec()
	for mm: MultiMesh in street._mms:
		if mm.get_aabb().size.x < 0.0:
			push_error("a MultiMesh box with a negative size")
	return (Time.get_ticks_usec() - t0) / 1000.0


func _mean(a: PackedFloat64Array) -> float:
	var s := 0.0
	for v: float in a:
		s += v
	return s / maxf(a.size(), 1.0)


func _pct(a: PackedFloat64Array, p: float) -> float:
	var sorted := a.duplicate()
	sorted.sort()
	return sorted[clampi(ceili(p * sorted.size()) - 1, 0, sorted.size() - 1)]
