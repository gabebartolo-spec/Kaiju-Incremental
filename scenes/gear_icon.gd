class_name GearIcon
extends Control
## A settings gear drawn in code (eight teeth round a hub with a hole), centred in its control, in
## `color`. Used on the title's settings button.

const TEETH := 8
## Shares of the control's shorter side: the tooth tips, the body, the hub hole.
const TIP := 0.46
const BODY := 0.34
const HOLE := 0.15
## The hole shows what is behind the gear: a near-black.
const HOLE_COLOUR := Color("111114")

var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var middle := size / 2.0
	var side := minf(size.x, size.y)
	var outline := PackedVector2Array()
	var step := TAU / TEETH
	for tooth: int in TEETH:
		var base := step * tooth
		# One tooth: up from the body to the tip, along it, back down to the body.
		for part: Vector2 in [
			Vector2(-0.3, BODY), Vector2(-0.17, TIP), Vector2(0.17, TIP), Vector2(0.3, BODY)
		]:
			var angle := base + step * part.x
			outline.append(middle + Vector2.from_angle(angle) * side * part.y)
	draw_colored_polygon(outline, color)
	draw_circle(middle, side * HOLE, HOLE_COLOUR)
