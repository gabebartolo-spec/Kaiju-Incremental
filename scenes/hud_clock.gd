class_name HudClock
extends VBoxContainer
## The top of the rampage HUD: the clock, a plain outlined number (red and pulsing only in the last
## seconds), and the threat bar under it (the bar is the threat, D-259). Reads the sim.

## The clock's digits keep at least this width, so the box does not jump as they change.
const CLOCK_MIN_WIDTH := 96.0

var sim: RampageSim
var time: Label
var threat: ThreatBar
var _hud: Dictionary
var _last_second := -1


func _init(p_sim: RampageSim, hud: Dictionary) -> void:
	sim = p_sim
	_hud = hud
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override("separation", Num.i(_hud["meter_gap"]))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	time = UiKit.label("", Num.i(_hud["clock_size"]))
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time.custom_minimum_size = Vector2(CLOCK_MIN_WIDTH, 0)
	time.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	time.resized.connect(func() -> void: time.pivot_offset = time.size / 2.0)
	add_child(time)
	threat = ThreatBar.new()
	add_child(threat)


func refresh() -> void:
	var second := ceili(maxf(0.0, sim.time_left))
	time.text = HudCounts.clock(sim)
	# The last seconds: the clock turns red and pulses each second; otherwise it is plain white.
	var hurry := sim.time_left < Num.f(_hud["hurry_seconds"]) and sim.endless == null
	time.add_theme_color_override("font_color", UiKit.ALERT if hurry else Color.WHITE)
	if hurry and second != _last_second and _last_second >= 0 and not sim.over:
		time.scale = Vector2.ONE * Num.f(_hud["hurry_pulse_scale"])
		create_tween().tween_property(time, "scale", Vector2.ONE, Num.f(_hud["hurry_pulse_s"]))
	_last_second = second
	threat.show_level(sim.news.level, sim.news.progress)
