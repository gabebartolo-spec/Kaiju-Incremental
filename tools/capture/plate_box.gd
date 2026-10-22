class_name PlateBox
extends StyleBox
## PROTOTYPE for the plates board (director #97 "Worn industrial plates"), not shipped: a worn
## steel plate with chamfered corners, a bevel, a drop shadow, a brushed sheen, seeded scuffs and
## four rivets, hazard tape down both edges like HazardBox.Band.SIDES. Drawn only by
## tools/capture/capture_plates.gd until the director approves the style; then it moves to scenes/
## beside HazardBox and UiKit builds it.

const CUT := 7.0
const SHADOW := Vector2(4.0, 6.0)
const BEVEL := 3.0
const RIVET := 3.2
const SCUFFS := 9

var fill := Color("3a3a40")
var edge := Color("0b0b0d")
var band_size := 22.0
var tape_on := Color("ffcc00")
var tape_off := Color("111114")
## 0 normal, 1 pressed (the plate sinks, the bevel flips, the shadow shrinks).
var press := 0.0


func _draw(item: RID, rect: Rect2) -> void:
	var shadow := rect
	shadow.position += SHADOW * (0.35 if press > 0.0 else 1.0)
	_poly(item, _octagon(shadow, CUT), Color(0, 0, 0, 0.6))
	var body := rect
	if press > 0.0:
		body.position += Vector2(0.0, 2.0)
		body.size -= Vector2(0.0, 2.0)
	var shape := _octagon(body, CUT)
	var top := fill.lightened(0.18)
	var bottom := fill.darkened(0.28)
	var colours := PackedColorArray()
	for p: Vector2 in shape:
		colours.append(top.lerp(bottom, clampf((p.y - body.position.y) / body.size.y, 0.0, 1.0)))
	RenderingServer.canvas_item_add_polygon(item, shape, colours)
	_tape(item, body)
	_bevel(item, body)
	_sheen(item, body)
	_scuffs(item, body)
	_rivets(item, body)
	var outline := shape.duplicate()
	outline.append(shape[0])
	RenderingServer.canvas_item_add_polyline(item, outline, PackedColorArray([edge]), 2.5, true)


static func _octagon(r: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			r.position + Vector2(cut, 0.0),
			Vector2(r.end.x - cut, r.position.y),
			Vector2(r.end.x, r.position.y + cut),
			Vector2(r.end.x, r.end.y - cut),
			Vector2(r.end.x - cut, r.end.y),
			Vector2(r.position.x + cut, r.end.y),
			Vector2(r.position.x, r.end.y - cut),
			Vector2(r.position.x, r.position.y + cut),
		]
	)


static func _poly(item: RID, pts: PackedVector2Array, colour: Color) -> void:
	RenderingServer.canvas_item_add_polygon(item, pts, PackedColorArray([colour]))


func _tape(item: RID, body: Rect2) -> void:
	var side := Vector2(band_size, body.size.y - 2.0 * CUT)
	HazardBox.tape(item, Rect2(body.position + Vector2(0.0, CUT), side), tape_on, tape_off)
	var right := Vector2(body.end.x - band_size, body.position.y + CUT)
	HazardBox.tape(item, Rect2(right, side), tape_on, tape_off)


func _bevel(item: RID, body: Rect2) -> void:
	var light := Color(1, 1, 1, 0.34 if press == 0.0 else 0.1)
	var dark := Color(0, 0, 0, 0.45 if press == 0.0 else 0.6)
	var x0 := body.position.x + band_size
	var x1 := body.end.x - band_size
	RenderingServer.canvas_item_add_rect(item, Rect2(x0, body.position.y, x1 - x0, BEVEL), light)
	RenderingServer.canvas_item_add_rect(item, Rect2(x0, body.end.y - BEVEL, x1 - x0, BEVEL), dark)
	RenderingServer.canvas_item_add_rect(item, Rect2(x0, body.position.y, 2.0, body.size.y), light)
	RenderingServer.canvas_item_add_rect(
		item, Rect2(x1 - 2.0, body.position.y, 2.0, body.size.y), dark
	)


## A soft diagonal gleam across the upper half, as on brushed steel.
func _sheen(item: RID, body: Rect2) -> void:
	var x0 := body.position.x + band_size + 8.0
	var x1 := body.end.x - band_size - 8.0
	var y0 := body.position.y + BEVEL
	var y1 := body.position.y + body.size.y * 0.5
	var pts := PackedVector2Array(
		[Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1 - 10.0), Vector2(x0, y1)]
	)
	var top := Color(1, 1, 1, 0.14)
	var low := Color(1, 1, 1, 0.0)
	RenderingServer.canvas_item_add_polygon(item, pts, PackedColorArray([top, top, low, low]))


## Short light and dark scratches, seeded from the size so a plate never changes between frames.
func _scuffs(item: RID, body: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(body.size.x) * 7919 + int(body.size.y) * 104729
	var x0 := body.position.x + band_size + 10.0
	var w := body.size.x - 2.0 * band_size - 20.0
	for i: int in SCUFFS:
		var at := Vector2(
			x0 + rng.randf() * w, body.position.y + 6.0 + rng.randf() * (body.size.y - 12.0)
		)
		var along := Vector2(rng.randf_range(10.0, 34.0), rng.randf_range(-4.0, 4.0))
		var colour := Color(1, 1, 1, 0.16) if i % 2 == 0 else Color(0, 0, 0, 0.3)
		RenderingServer.canvas_item_add_line(item, at, at + along, colour, 1.5)


func _rivets(item: RID, body: Rect2) -> void:
	var x0 := body.position.x + band_size + 11.0
	var x1 := body.end.x - band_size - 11.0
	var y0 := body.position.y + 10.0
	var y1 := body.end.y - 10.0
	for p: Vector2 in [Vector2(x0, y0), Vector2(x1, y0), Vector2(x0, y1), Vector2(x1, y1)]:
		RenderingServer.canvas_item_add_circle(
			item, p + Vector2(1.0, 1.5), RIVET + 1.0, Color(0, 0, 0, 0.55)
		)
		RenderingServer.canvas_item_add_circle(item, p, RIVET, Color("55555c"))
		RenderingServer.canvas_item_add_circle(
			item, p + Vector2(-1.0, -1.0), RIVET * 0.45, Color(1, 1, 1, 0.55)
		)
