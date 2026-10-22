class_name HazardBox
extends StyleBox
## The emergency-broadcast box (the director's UI look A): a flat fill with square corners, an
## edge (solid or dashed), an optional band of hazard tape on the left, the top or both sides, and
## an optional focus ring drawn just inside the edge (never outside: a ring outside the box
## covered the controls next to it). The city's alarm system pointing at you. UiKit builds every
## one. With `plated` the box is a worn industrial steel plate instead (director #97 "Worn
## industrial plates"): chamfered corners, a bevel, a brushed sheen, scuffs, four rivets and a drop
## shadow, the hazard tape kept down both sides; the buttons use it.

enum Band { NONE, LEFT, TOP, SIDES }

## One stripe of tape is this wide (px, measured along the band).
const STRIPE := 10.0
## A dash and its gap on a dashed edge (px).
const DASH := 12.0
## The focus ring sits this far inside the box's edge and is this thick.
const RING_GAP := 4.0
const RING_WIDTH := 3.0
## Corner brackets (a broadcast monitor's registration marks): each arm this long and thick,
## this far inside the edge.
const CORNER_LEN := 26.0
const CORNER_WIDTH := 4.0
const CORNER_GAP := 6.0
## The plate: chamfer, drop shadow (kept inside the box's rect), bevel, scuffs and rivets.
const CUT := 7.0
const PLATE_SHADOW := Vector2(4.0, 6.0)
const PLATE_BEVEL := 3.0
const RIVET := 3.2
## The outline of a plate in focus.
const FOCUS_OUTLINE := 4.5
## A button without the focus pointer needs only this much room between its tape and its text.
const POINTERLESS_ROOM := 10.0
const SCUFFS := 9
## The focus pointer: a solid triangle this wide, this far in from the right edge, its height a
## share of the box's.
const CHEVRON_WIDTH := 14.0
const CHEVRON_INSET := 14.0
## With tape on the right too, the pointer sits this far inside it.
const CHEVRON_GAP := 6.0
const CHEVRON_SHARE := 0.36

static var _text_material: ShaderMaterial

var fill := Color.BLACK:
	set(value):
		if value != fill:
			fill = value
			emit_changed()
var edge := Color.WHITE
var border := 2.0
var band := Band.NONE
var band_size := 20.0
var tape_on := Color("ffcc00")
var tape_off := Color("111114")
var dashed := false
var ring := false
var ring_color := Color("ffcc00")
## A plate in focus (or pressed) is outlined in this, thicker: no fine inner frame (it turns to
## noise at TV distance).
var focus_edge := Color.WHITE
## Brackets in `corner_color` at the corners clear of the tape band.
var corners := false
var corner_color := Color("ffcc00")
## A pointer in `ring_color` at the right edge (the focused button: "you are here").
var chevron := false
## A worn steel plate in `fill` (see above) instead of the flat square box.
var plated := false
## 0 normal, 1 pressed (the plate sinks, the bevel flips, the shadow shrinks).
var press := 0.0


## Takes the focus pointer off a plated button (the focus shows in the outline) and closes the room
## the pointer needed, so a narrow button keeps its text.
static func drop_pointer(button: Button) -> void:
	for state: String in ["normal", "hover", "focus", "pressed", "disabled"]:
		var box := button.get_theme_stylebox(state) as HazardBox
		box.chevron = false
		box.content_margin_left = box.band_size + POINTERLESS_ROOM
		box.content_margin_right = box.band_size + POINTERLESS_ROOM


## The text material of the plated buttons: a faint stamped highlight on the letters' top edge.
static func text_material() -> ShaderMaterial:
	if _text_material == null:
		_text_material = ShaderMaterial.new()
		_text_material.shader = preload("res://scenes/plate_text.gdshader")
	return _text_material


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if plated:
		rect = _draw_plate(to_canvas_item, rect)
	else:
		RenderingServer.canvas_item_add_rect(to_canvas_item, rect, fill)
		_draw_band(to_canvas_item, rect)
		frame(to_canvas_item, rect, edge, border, dashed)
	if corners:
		_corners(to_canvas_item, rect)
	if chevron:
		var h := rect.size.y * CHEVRON_SHARE
		var inset := CHEVRON_INSET if band != Band.SIDES else band_size + CHEVRON_GAP
		var tip := Vector2(rect.end.x - inset, rect.get_center().y)
		var back := tip.x - CHEVRON_WIDTH
		var tri := PackedVector2Array(
			[Vector2(back, tip.y - h / 2.0), tip, Vector2(back, tip.y + h / 2.0)]
		)
		RenderingServer.canvas_item_add_polygon(to_canvas_item, tri, PackedColorArray([ring_color]))
	if ring and not plated:
		var inner := rect.grow(-(border + RING_GAP))
		# Clear of the tape too: a ring crossing the stripe reads as a glitch (screen critic).
		if band == Band.LEFT or band == Band.SIDES:
			inner = inner.grow_side(SIDE_LEFT, -band_size)
		if band == Band.SIDES:
			inner = inner.grow_side(SIDE_RIGHT, -band_size)
		elif band == Band.TOP:
			inner = inner.grow_side(SIDE_TOP, -band_size)
		frame(to_canvas_item, inner, ring_color, RING_WIDTH, false)


## The band of tape on the left, the top or both sides.
func _draw_band(item: RID, rect: Rect2) -> void:
	var side := Vector2(band_size, rect.size.y)
	if band == Band.LEFT or band == Band.SIDES:
		tape(item, Rect2(rect.position, side), tape_on, tape_off)
	if band == Band.SIDES:
		tape(item, Rect2(Vector2(rect.end.x - band_size, rect.position.y), side), tape_on, tape_off)
	elif band == Band.TOP:
		tape(item, Rect2(rect.position, Vector2(rect.size.x, band_size)), tape_on, tape_off)


## Diagonal hazard tape filling `rect`: stripes of `on` over `off`, leaning like road tape.
static func tape(item: RID, rect: Rect2, on: Color, off: Color, stripe: float = STRIPE) -> void:
	RenderingServer.canvas_item_add_rect(item, rect, off)
	var clip := PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)
	var h := rect.size.y
	var x := rect.position.x - h
	while x < rect.end.x:
		var stripe_poly := PackedVector2Array(
			[
				Vector2(x, rect.end.y),
				Vector2(x + stripe, rect.end.y),
				Vector2(x + stripe + h, rect.position.y),
				Vector2(x + h, rect.position.y),
			]
		)
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(stripe_poly, clip):
			RenderingServer.canvas_item_add_polygon(item, piece, PackedColorArray([on]))
		x += stripe * 2.0


## A rectangle's edge drawn inside `rect`, `width` thick; dashed draws DASH-long pieces.
static func frame(item: RID, rect: Rect2, color: Color, width: float, dashed_edge: bool) -> void:
	if width <= 0.0:
		return
	var sides: Array[Rect2] = [
		Rect2(rect.position, Vector2(rect.size.x, width)),
		Rect2(Vector2(rect.position.x, rect.end.y - width), Vector2(rect.size.x, width)),
		Rect2(rect.position, Vector2(width, rect.size.y)),
		Rect2(Vector2(rect.end.x - width, rect.position.y), Vector2(width, rect.size.y)),
	]
	for side: Rect2 in sides:
		if not dashed_edge:
			RenderingServer.canvas_item_add_rect(item, side, color)
			continue
		var along_x := side.size.x > side.size.y
		var length := side.size.x if along_x else side.size.y
		var at := 0.0
		while at < length:
			var piece := minf(DASH, length - at)
			var offset := Vector2(at, 0.0) if along_x else Vector2(0.0, at)
			var extent := Vector2(piece, width) if along_x else Vector2(width, piece)
			RenderingServer.canvas_item_add_rect(item, Rect2(side.position + offset, extent), color)
			at += DASH * 2.0


## The corner brackets, inside the edge; never on the tape (the band's corners have none).
func _corners(item: RID, rect: Rect2) -> void:
	var inner := rect.grow(-(border + CORNER_GAP))
	var at: Array[Vector2] = [inner.end, Vector2(inner.position.x, inner.end.y)]
	if band != Band.TOP:
		at.append_array([inner.position, Vector2(inner.end.x, inner.position.y)])
	if band == Band.LEFT:
		at = at.filter(func(p: Vector2) -> bool: return p.x > inner.position.x)
	for p: Vector2 in at:
		var sx := -1.0 if p.x > rect.get_center().x else 1.0
		var sy := -1.0 if p.y > rect.get_center().y else 1.0
		var arm_x := Rect2(p, Vector2(CORNER_LEN * sx, CORNER_WIDTH * sy)).abs()
		var arm_y := Rect2(p, Vector2(CORNER_WIDTH * sx, CORNER_LEN * sy)).abs()
		RenderingServer.canvas_item_add_rect(item, arm_x, corner_color)
		RenderingServer.canvas_item_add_rect(item, arm_y, corner_color)


## The worn plate; returns the rect of its face (the room the pointer and ring work in).
func _draw_plate(item: RID, rect: Rect2) -> Rect2:
	var gap := PLATE_SHADOW * (0.35 if press > 0.0 else 1.0)
	var body := Rect2(rect.position, rect.size - PLATE_SHADOW)
	_poly(item, _octagon(Rect2(body.position + gap, body.size), CUT), Color(0, 0, 0, 0.6))
	if press > 0.0:
		body.position.y += 2.0
		body.size.y -= 2.0
	var shape := _octagon(body, CUT)
	var top := fill.lightened(0.18)
	var bottom := fill.darkened(0.28)
	var colours := PackedColorArray()
	for p: Vector2 in shape:
		colours.append(top.lerp(bottom, clampf((p.y - body.position.y) / body.size.y, 0.0, 1.0)))
	RenderingServer.canvas_item_add_polygon(item, shape, colours)
	_draw_band_plate(item, body)
	_bevel(item, body)
	_sheen(item, body)
	_scuffs(item, body)
	_rivets(item, body)
	var outline := shape.duplicate()
	outline.append(shape[0])
	var outline_colour := focus_edge if ring else edge
	var outline_width := FOCUS_OUTLINE if ring else 2.5
	RenderingServer.canvas_item_add_polyline(
		item, outline, PackedColorArray([outline_colour]), outline_width, true
	)
	return body


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


## Tape down both sides of the plate, inside its chamfered corners.
func _draw_band_plate(item: RID, body: Rect2) -> void:
	if band != Band.SIDES:
		return
	var side := Vector2(_inset(), body.size.y - 2.0 * CUT)
	tape(item, Rect2(body.position + Vector2(0.0, CUT), side), tape_on, tape_off)
	var right := Vector2(body.end.x - _inset(), body.position.y + CUT)
	tape(item, Rect2(right, side), tape_on, tape_off)


func _bevel(item: RID, body: Rect2) -> void:
	var light := Color(1, 1, 1, 0.34 if press == 0.0 else 0.1)
	var dark := Color(0, 0, 0, 0.45 if press == 0.0 else 0.6)
	var x0 := body.position.x + _inset()
	var x1 := body.end.x - _inset()
	RenderingServer.canvas_item_add_rect(
		item, Rect2(x0, body.position.y, x1 - x0, PLATE_BEVEL), light
	)
	RenderingServer.canvas_item_add_rect(
		item, Rect2(x0, body.end.y - PLATE_BEVEL, x1 - x0, PLATE_BEVEL), dark
	)
	RenderingServer.canvas_item_add_rect(item, Rect2(x0, body.position.y, 2.0, body.size.y), light)
	RenderingServer.canvas_item_add_rect(
		item, Rect2(x1 - 2.0, body.position.y, 2.0, body.size.y), dark
	)


## A soft diagonal gleam across the upper half, as on brushed steel.
func _sheen(item: RID, body: Rect2) -> void:
	var x0 := body.position.x + _inset() + 8.0
	var x1 := body.end.x - _inset() - 8.0
	var y0 := body.position.y + PLATE_BEVEL
	var y1 := body.position.y + body.size.y * 0.5
	var pts := PackedVector2Array(
		[Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1 - 10.0), Vector2(x0, y1)]
	)
	var high := Color(1, 1, 1, 0.14)
	var low := Color(1, 1, 1, 0.0)
	RenderingServer.canvas_item_add_polygon(item, pts, PackedColorArray([high, high, low, low]))


## Short light and dark scratches, seeded from the size so a plate never changes between frames.
func _scuffs(item: RID, body: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(body.size.x) * 7919 + int(body.size.y) * 104729
	var x0 := body.position.x + _inset() + 10.0
	var w := body.size.x - 2.0 * _inset() - 20.0
	for i: int in SCUFFS:
		var at := Vector2(
			x0 + rng.randf() * w, body.position.y + 6.0 + rng.randf() * (body.size.y - 12.0)
		)
		var along := Vector2(rng.randf_range(10.0, 34.0), rng.randf_range(-4.0, 4.0))
		var colour := Color(1, 1, 1, 0.16) if i % 2 == 0 else Color(0, 0, 0, 0.3)
		RenderingServer.canvas_item_add_line(item, at, at + along, colour, 1.5)


func _rivets(item: RID, body: Rect2) -> void:
	var x0 := body.position.x + _inset() + 11.0
	var x1 := body.end.x - _inset() - 11.0
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


## How far the plate's tape reaches in from each side (0 without it).
func _inset() -> float:
	return band_size if band == Band.SIDES else 0.0
