extends "res://tools/capture/capture_motion.gd"
## The croc titan's clip moves (D-047) at the game camera, for the before/after review: walk, stop,
## a 90 deg turn on the spot (the sim turns the standing kaiju left), then the roar. The same
## script on a branch without the .kclip records the procedural gait doing the same moves.
##   godot --path . --resolution 1280x720 --windowed --write-movie <dir/f.png> --fixed-fps 60 \
##     --script tools/capture/capture_clips.gd -- --cam=game
## Same options as capture_motion.gd (--cam, --pose-trace, --trace, ...); 20 s by default.
## Prints "CLIPSTATE t <from> -> <to>" at each cross-fade start and "CLIPSEAM t <clip>" each time a
## looping clip wraps (for the per-frame difference plot); nothing on a kaiju without clips.
## --procedural: the same moves on the procedural gait (ClipGait.off), the "before".
## --frames=N saves every Nth frame as PNG to <out>/frames (--out=<dir>, default user://clips),
## optionally only from --from=<s> to --to=<s>: lossless frames for the difference plot and clips
## (each is the frame drawn before that step, one frame behind the label).

const TURN_AT := 8.5
const ROAR_AT := 13.0

var _gait: ClipGait
var _state := ""
var _lap := 0
var _out := "user://clips"
var _every := 0
var _from := 0.0
var _to := INF
var _frame := 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--procedural":
			ClipGait.off = true
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--frames="):
			_every = int(arg.substr(9))
		elif arg.begins_with("--from="):
			_from = float(arg.substr(7))
		elif arg.begins_with("--to="):
			_to = float(arg.substr(5))
	if _every > 0:
		DirAccess.make_dir_recursive_absolute(_out.path_join("frames"))
	super()
	_roar_at = ROAR_AT
	if not "--seconds=" in " ".join(OS.get_cmdline_user_args()):
		_seconds = 20.0


func _input_at(t: float) -> Vector2:
	if t < 1.0 or t >= 7.0:
		return Vector2.ZERO
	return Vector2(0, -1)


func _standing_facing(t: float, facing: Vector2) -> Vector2:
	return Vector2(-1, 0) if t >= TURN_AT else facing


func _event_at(t: float) -> String:
	_log_clip(t)
	if _every > 0 and _frame % _every == 0 and t >= _from and t <= _to:
		var shot := root.get_viewport().get_texture().get_image()
		shot.save_png(_out.path_join("frames/f%05d.png" % _frame))
	_frame += 1
	if t < 1.0:
		return "STAND"
	if t < 7.0:
		return "WALK"
	if t < TURN_AT:
		return "STOP"
	if t < ROAR_AT:
		return "TURN 90 LEFT (standing)"
	if t < ROAR_AT + 6.0:
		return "ROAR"
	return "STAND"


func _log_clip(t: float) -> void:
	if _gait == null:
		for rig: Node in root.find_children("*", "KaijuRig", true, false):
			if (rig as KaijuRig).gait is ClipGait:
				_gait = (rig as KaijuRig).gait
		if _gait == null:
			return
	if _gait.state != _state:
		print("CLIPSTATE %.4f %s -> %s" % [t, _state, _gait.state])
		_state = _gait.state
		_lap = floori(_gait.clip_time / _gait.clips.frames_of(_state))
	elif _gait.clips.loops(_state):
		var lap := floori(_gait.clip_time / _gait.clips.frames_of(_state))
		if lap != _lap:
			print("CLIPSEAM %.4f %s" % [t, _state])
			_lap = lap
