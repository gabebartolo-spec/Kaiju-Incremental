extends SceneTree
## The people bench's engine-log smoke run (debt list row 2, D-295): the seeded street replay the
## people bench and the street suite drive (tests/lib/street_replay.gd), built, stepped and freed
## the way the bench frees it, so the log shows every engine error, warning and leak the crowd path
## makes at exit. tools/lint/log_smoke.sh runs this (the `street` run) and fails on any ERROR /
## WARNING / leak line in the log.
##
##   godot --headless --fixed-fps 60 --path . --script tools/lint/log_smoke_street.gd --
##     [--tier=N] [--preset=medium] [--frames=N]
## Seeded by design: Replay's Seeds.make streams, its scripted kaiju line and a fixed frame step.

const Kit := preload("res://tools/capture/capture_kit.gd")
const Replay := preload("res://tests/lib/street_replay.gd")
## Frames after everything is freed, so deferred frees run before the engine exits.
const DRAIN_FRAMES := 30

var _tier := 3
var _preset := "medium"
var _frames := 300  # past the first stomp (42), the first brace (150) and a police blockade


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var a := Kit.args({"tier": _tier, "preset": _preset, "frames": _frames})
	_tier = Num.i(a["tier"])
	_preset = str(a["preset"])
	_frames = Num.i(a["frames"])
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var replay := Replay.new(self, _tier, _preset)
	var people := replay.street.pos.size()
	for _f: int in _frames:
		replay.step()
		await process_frame
	print(
		(
			"log_smoke: street %d people, %d frames, fled %d, killed %d, digest %s"
			% [
				people,
				_frames,
				replay.street.fled,
				replay.street.killed,
				replay.digest().substr(0, 16)
			]
		)
	)
	replay.finish()
	await Kit.frames(self, DRAIN_FRAMES)
	print("LOG_SMOKE street done")
	quit(0 if people > 0 else 1)
