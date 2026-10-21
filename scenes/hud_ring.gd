class_name HudRing
extends Control
## A cooldown ring on the rampage HUD (b2-12): an icon with a ring that fills clockwise from
## the top while the move recharges. Ready, the ring closes, the icon lights and the ring pops
## once, so ready never rests on colour alone (the ready sound is the rampage's). No text.

enum Icon { BREATH, DASH, ULTIMATE }

## The bolt, the chevrons and the burst, in units of the icon's half-size (y down).
const BOLT: Array[Vector2] = [
	Vector2(0.2, -1.0),
	Vector2(-0.45, 0.15),
	Vector2(-0.05, 0.15),
	Vector2(-0.25, 1.0),
	Vector2(0.45, -0.25),
	Vector2(0.05, -0.25),
	Vector2(0.35, -1.0),
]
const CHEVRON: Array[Vector2] = [
	Vector2(-0.35, -0.75),
	Vector2(0.15, 0.0),
	Vector2(-0.35, 0.75),
	Vector2(-0.05, 0.75),
	Vector2(0.45, 0.0),
	Vector2(-0.05, -0.75),
]
const CHEVRON_STEP := 0.5
const BURST_POINTS := 8
const BURST_INNER := 0.45
## The icon fills this share of the ring's inner radius.
const ICON_SHARE := 0.62
const SEGMENTS := 64
## The dark outline around the ring and icon (px each side), for contrast over fire.
const OUTLINE := 3.0

var icon: Icon
## 0 = just used, 1 = ready.
var ratio := 1.0
var radius: float
var width: float
var _pulse: Tween


func _init(p_icon: Icon, p_radius: float, p_width: float) -> void:
	icon = p_icon
	radius = p_radius
	width = p_width
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2.ONE * 2.0 * (radius + width / 2.0 + OUTLINE + 1.0)
	resized.connect(func() -> void: pivot_offset = size / 2.0)


func is_ready() -> bool:
	return ratio >= 1.0


## The ring's fill (0..1); closing it pops the ring once.
func set_ratio(value: float) -> void:
	var was := is_ready()
	ratio = clampf(value, 0.0, 1.0)
	if is_ready() and not was:
		_pop()
	queue_redraw()


func _pop() -> void:
	var hud: Dictionary = UiKit.ui()["hud"]
	if _pulse != null:
		_pulse.kill()
	scale = Vector2.ONE * Num.f(hud["ring_ready_scale"])
	_pulse = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse.tween_property(self, "scale", Vector2.ONE, Num.f(hud["ring_ready_s"]))


func _draw() -> void:
	var c := size / 2.0
	var dark := UiKit.outline_color()
	draw_circle(c, radius + width / 2.0 + OUTLINE, Color(UiKit.BG, 0.55))
	draw_arc(c, radius, 0.0, TAU, SEGMENTS, dark, width + 2.0 * OUTLINE, true)
	draw_arc(c, radius, 0.0, TAU, SEGMENTS, UiKit.PANEL_EDGE, width, true)
	if ratio > 0.0:
		var start := -PI / 2.0
		draw_arc(c, radius, start, start + TAU * ratio, SEGMENTS, UiKit.ACCENT, width, true)
	var tint := Color.WHITE if is_ready() else UiKit.MUTED.darkened(0.25)
	var half := (radius - width / 2.0) * ICON_SHARE
	for shape: PackedVector2Array in _shapes(c, half):
		var closed := shape.duplicate()
		closed.append(shape[0])
		draw_polyline(closed, dark, OUTLINE * 2.0, true)
		draw_colored_polygon(shape, tint)


func _shapes(c: Vector2, half: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	match icon:
		Icon.BREATH:
			out.append(_placed(BOLT, c, half, 0.0))
		Icon.DASH:
			out.append(_placed(CHEVRON, c, half, -CHEVRON_STEP / 2.0))
			out.append(_placed(CHEVRON, c, half, CHEVRON_STEP / 2.0))
		Icon.ULTIMATE:
			var star := PackedVector2Array()
			for i: int in BURST_POINTS * 2:
				var r := half if i % 2 == 0 else half * BURST_INNER
				var a := -PI / 2.0 + PI * i / BURST_POINTS
				star.append(c + Vector2(cos(a), sin(a)) * r)
			out.append(star)
	return out


func _placed(points: Array[Vector2], c: Vector2, half: float, shift: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(c + (p + Vector2(shift, 0.0)) * half)
	return out
