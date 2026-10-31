class_name BodyBite
extends RefCounted
## The body's bite (playtest note 2), split out of CityView: the chunks the kaiju's body breaks
## are torn off as one piece of the building's own voxels (BuildingView.lift_piece, as a falling
## section is) that tumbles out away from the kaiju and bursts into debris where it lands, every
## sampled voxel of it, so a hole reads as torn open, never vanished. No dust cloud or fire: they
## hid the body. The walls round the hole stay up until the sim says they lose support.
## Presentation only.

## How far out from the wall a torn piece lands (world units).
const THROW := 1.2
## The lowest a piece falls from, so a ground-floor bite still tumbles (world units).
const MIN_DROP := 0.4


static func tear(
	city: CityView,
	view: BuildingView,
	cells: Array[Vector3i],
	kaiju_at: Vector3,
	rng: RandomNumberGenerator
) -> void:
	var b := view.b
	var mid := Vector3.ZERO
	for c: Vector3i in cells:
		mid += b.chunk_world(c)
	mid /= cells.size()
	var chipped := view.chip(cells, rng)  # ragged edges round the hole, as for any blow
	var piece := city.carve.bite(view, mid)  # exactly the cells the blow carved, when drawn fine
	if piece == null:
		piece = view.lift_piece(cells, mid)
	city.add_child(piece)
	var away := Vector3(mid.x - kaiju_at.x, 0, mid.z - kaiju_at.z).normalized()
	var land := Vector3(mid.x, MIN_DROP * 0.5, mid.z) + away * THROW
	var seconds := sqrt(2.0 * maxf(MIN_DROP, mid.y) / Num.f(city.sim.city["fall_gravity"]))
	var spin := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
	var tween := piece.create_tween().set_parallel(true)
	tween.tween_property(piece, "position", land, seconds).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	tween.tween_property(piece, "rotation", spin, seconds)
	tween.chain().tween_callback(
		func() -> void:
			var parts := PieceParts.of(piece)
			for part: Dictionary in parts:
				var pos: Vector3 = part["pos"]
				var color: Color = part["color"]
				city.debris(pos + land - mid, color, away)
			piece.queue_free()
	)
	for part: Dictionary in chipped:
		var at: Vector3 = part["pos"]
		var tint: Color = part["color"]
		city.debris(at, tint, away)
