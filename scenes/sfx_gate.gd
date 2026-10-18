class_name SfxGate
extends Node
## Keeps a rampage's Sfx silent while it loads (director's playtest: "gunfire audio kicks in
## while the visuals are still loading"). It opens Sfx.live once a frame has drawn and tuning
## "sfx" "start_gate" smooth_frames frames in a row came in under max_frame seconds, dropping
## what queued meanwhile, then frees itself.

var _sfx: Sfx
var _gate: Dictionary
var _drawn := false
var _smooth := 0


func _init(sfx: Sfx) -> void:
	_sfx = sfx
	_gate = Content.section("sfx")["start_gate"]


func _ready() -> void:
	_drawn = DisplayServer.get_name() == "headless"  # headless draws nothing: smooth frames only
	RenderingServer.frame_post_draw.connect(func() -> void: _drawn = true, CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	if _sfx.live:
		queue_free()
		return
	_smooth = _smooth + 1 if _drawn and delta <= Num.f(_gate["max_frame"]) else 0
	if _smooth < Num.i(_gate["smooth_frames"]):
		return
	_sfx._landings.clear()  # collapses queued while loading are dropped, not played in a burst
	_sfx._pending = ""
	_sfx.live = true
	queue_free()
