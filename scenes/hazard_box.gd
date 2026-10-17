class_name HazardBox
extends StyleBox
## The emergency-broadcast box (the director's UI look A): a flat fill with square corners, an
## edge (solid or dashed), an optional band of hazard tape on the left or top, and an optional
## focus ring drawn just inside the edge (never outside: a ring outside the box covered the
## controls next to it). The city's alarm system pointing at you. UiKit builds every one.

enum Band { NONE, LEFT, TOP }

## One stripe of tape is this wide (px, measured along the band).
const STRIPE := 10.0
## A dash and its gap on a dashed edge (px).
const DASH := 12.0
## The focus ring sits this far inside the box's edge and is this thick.
const RING_GAP := 4.0
const RING_WIDTH := 3.0

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


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	RenderingServer.canvas_item_add_rect(to_canvas_item, rect, fill)
	if band == Band.LEFT:
		tape(
			to_canvas_item, Rect2(rect.position, Vector2(band_size, rect.size.y)), tape_on, tape_off
		)
	elif band == Band.TOP:
		tape(
			to_canvas_item, Rect2(rect.position, Vector2(rect.size.x, band_size)), tape_on, tape_off
		)
	frame(to_canvas_item, rect, edge, border, dashed)
	if ring:
		var inner := rect.grow(-(border + RING_GAP))
		# Clear of the tape too: a ring crossing the stripe reads as a glitch (screen critic).
		if band == Band.LEFT:
			inner = inner.grow_side(SIDE_LEFT, -band_size)
		elif band == Band.TOP:
			inner = inner.grow_side(SIDE_TOP, -band_size)
		frame(to_canvas_item, inner, ring_color, RING_WIDTH, false)


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
