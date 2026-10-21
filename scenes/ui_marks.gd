class_name UiMarks
extends RefCounted
## The broadcast look's drawn marks (UI look A, D-061): tape, meter ticks, the alert tag and
## scanlines. Original and drawn in code, so no image asset to license. UiKit places them.


## Hazard tape filling the control.
class Tape:
	extends Control

	func _draw() -> void:
		HazardBox.tape(get_canvas_item(), Rect2(Vector2.ZERO, size), UiKit.ACCENT, Color("111114"))


## A broadcast meter's scale: a dark tick every tenth, over the fill, so a meter reads as a
## signal gauge and its level reads by position as well as colour.
class Ticks:
	extends Control

	const STEPS := 10
	const WIDTH := 3.0

	func _draw() -> void:
		var line := Color(UiKit.BG, 0.85)
		for i: int in range(1, STEPS):
			var x := roundf(size.x * i / STEPS - WIDTH / 2.0)
			draw_rect(Rect2(x, 0.0, WIDTH, size.y), line)


## The warning tag on a header's left: a hazard-yellow triangle with a black bar and dot on a
## near-black square.
class AlertTag:
	extends Control

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UiKit.BG)
		var s := minf(size.x, size.y)
		var c := size / 2.0
		var h := s * 0.8
		var top := c + Vector2(0.0, -h * 0.55)
		var tri := PackedVector2Array(
			[top, c + Vector2(h * 0.58, h * 0.45), c + Vector2(-h * 0.58, h * 0.45)]
		)
		draw_colored_polygon(tri, UiKit.ACCENT)
		var w := maxf(3.0, h * 0.11)
		draw_rect(Rect2(c.x - w / 2.0, c.y - h * 0.22, w, h * 0.4), UiKit.BG)
		draw_rect(Rect2(c.x - w / 2.0, c.y + h * 0.25, w, w), UiKit.BG)


## Faint horizontal lines, like an old broadcast monitor.
class Scanlines:
	extends Control

	func _draw() -> void:
		var y := 0.0
		var line := Color(1, 1, 1, UiKit.SCANLINE_ALPHA)
		while y < size.y:
			draw_rect(Rect2(0.0, y, size.x, UiKit.SCANLINE_STEP / 2.0), line)
			y += UiKit.SCANLINE_STEP
