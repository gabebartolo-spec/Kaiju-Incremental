class_name ThreatBar
extends Control
## The bar under the clock IS the threat meter (D-259 "A small threat icon", director 2026-10-26
## "the bar is the threat"): five equal segments with small gaps. Segments below the level are
## filled in the clock's white, the current one fills by progress toward the next level (at partial
## alpha), the rest are a thin outline. From tuning "ui" threat_bar alert_from the filled segments
## turn alert red, the only colour. A rise pops the newly filled segment. The level reads by the
## count of filled segments alone. Reads RunNews (level, progress) through `show`; presentation only.

var level := 0
var progress := 0.0
## 1.0, or the swell of the segment that just filled (tween target).
var pop := 1.0
var _cfg: Dictionary
var _pop: Tween


func _init() -> void:
	_cfg = UiKit.ui()["threat_bar"]
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size_px: Array = UiKit.ui()["hud"]["meter_size"]
	custom_minimum_size = Vector2(Num.f(size_px[0]), Num.f(size_px[1]))
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	show_level(1, 0.0, false)


## Sets the meter to `n` (1..segments) and `part` (0-1 toward the next); `rose`: n just went up.
func show_level(n: int, part: float, rose := true) -> void:
	var risen := n > level and level > 0
	level = n
	progress = clampf(part, 0.0, 1.0)
	queue_redraw()
	if not (rose and risen):
		return
	if _pop != null:
		_pop.kill()
	pop = Num.f(_cfg["pop_scale"])
	_pop = create_tween()
	_pop.tween_property(self, "pop", 1.0, Num.f(_cfg["pop_s"]))


## The segments that are completely filled.
func filled() -> int:
	return level - 1 if level < segments() else segments()


func segments() -> int:
	return Num.i(_cfg["segments"])


## The share of the current segment filled (0 when none is current, i.e. every segment is full).
func partial() -> float:
	return progress if level < segments() else 0.0


func _process(_delta: float) -> void:
	if pop != 1.0:
		queue_redraw()


func _draw() -> void:
	var n := segments()
	var gap := Num.f(_cfg["gap"])
	var w := (size.x - gap * (n - 1)) / n
	var white := Color.WHITE
	var colour := UiKit.ALERT if level >= Num.i(_cfg["alert_from"]) else white
	var done := filled()
	for i: int in n:
		var seg := Rect2(i * (w + gap), 0.0, w, size.y)
		if i < done:
			var grown := seg
			if i == done - 1 and pop != 1.0:
				grown = Rect2(seg.get_center() - seg.size * pop / 2.0, seg.size * pop)
			draw_rect(grown, colour)
		else:
			draw_rect(seg, Color(white, Num.f(_cfg["empty_alpha"])), false, 1.0)
			if i == done and partial() > 0.0:
				var part := Rect2(seg.position, Vector2(w * partial(), size.y))
				draw_rect(part, Color(colour, Num.f(_cfg["partial_alpha"])))
