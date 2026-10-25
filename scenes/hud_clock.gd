class_name HudClock
extends VBoxContainer
## The top of the rampage HUD: the clock, a plain outlined number (red and pulsing only in the last
## seconds), the threat badge to its right (D-259) and the city-destroyed strip under it. A spacer
## as wide as the badge sits on the clock's left, so the clock stays dead centre. Reads the sim.

## The clock's digits keep at least this width, so the box does not jump as they change.
const CLOCK_MIN_WIDTH := 96.0

var sim: RampageSim
var time: Label
var city_meter: ProgressBar
var badge: ThreatBadge
var _hud: Dictionary
## The empty box left of the clock, as wide as the badge.
var _mirror: Control
## The badge's place in the row (as big as the badge).
var _slot: Control
var _last_second := -1


func _init(p_sim: RampageSim, hud: Dictionary) -> void:
	sim = p_sim
	_hud = hud
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override("separation", Num.i(_hud["meter_gap"]))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", Num.i(UiKit.ui()["threat_badge"]["clock_gap"]))
	add_child(row)
	_mirror = Control.new()
	_mirror.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_mirror)
	time = UiKit.label("", Num.i(_hud["clock_size"]))
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time.custom_minimum_size = Vector2(CLOCK_MIN_WIDTH, 0)
	time.resized.connect(func() -> void: time.pivot_offset = time.size / 2.0)
	row.add_child(time)
	# The badge sits in a plain slot, not straight in the row: a container resets its children's
	# scale when it lays them out, which would cut the badge's pop short.
	_slot = Control.new()
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_slot)
	badge = ThreatBadge.new()
	_slot.add_child(badge)
	badge.minimum_size_changed.connect(_fit_mirror)
	var meter: Array = _hud["meter_size"]
	city_meter = UiKit.bar(UiKit.ACCENT, Num.i(meter[1]), false, false)
	city_meter.custom_minimum_size.x = Num.f(meter[0])
	city_meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(city_meter)


func _ready() -> void:
	_fit_mirror()


func _fit_mirror() -> void:
	var want := badge.get_combined_minimum_size()
	_mirror.custom_minimum_size.x = want.x
	_slot.custom_minimum_size = want
	badge.size = want


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
	city_meter.value = sim.destruction() * 100.0
	badge.show_level(sim.news.level)
