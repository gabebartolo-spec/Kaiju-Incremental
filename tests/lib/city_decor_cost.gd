extends RefCounted
## The decor's load cost (the rampage took ~19 s to load, 2026-11-02): CityDecor._on_building
## files the buildings and channels by ground cell (BLOCK_CELL), so a spot tests the few rects
## round it and gives the answer the scan of every rect gave (on vs off: rects tested); the
## street props share one turned model per id and quarter turn rather than rebuilding it per
## prop, cell for cell the same model (on vs off: models built). Seeded: the street props
## fixture's city.

const StreetPropsCheck := preload("res://tests/lib/city_street_props.gd")

const STEP := 2.0  # the spacing of the sample spots (m)


static func check(root: Node, check_fn: Callable) -> void:
	var decor := StreetPropsCheck._decor(root, true)
	_building(decor, check_fn)
	_models(decor, check_fn)
	decor.get_parent().queue_free()


static func _building(decor: CityDecor, check_fn: Callable) -> void:
	var footprints: Array[Rect2] = decor.get("_footprints")
	var water: Array[Rect2] = decor.get("_water")
	var rects := footprints + water
	var blocked: Dictionary = decor.get("_blocked")
	var reach: float = decor.get("_view")
	var bad := 0
	var on := 0
	var off := 0
	var x := -reach
	while x <= reach:
		var z := -reach
		while z <= reach:
			var p := Vector2(x, z)
			var scan := rects.any(func(r: Rect2) -> bool: return r.has_point(p))
			bad += int(scan != decor._on_building(p))
			var near: Array = blocked.get(Vector2i((p / CityDecor.BLOCK_CELL).floor()), [])
			on += near.size()
			off += rects.size()
			z += STEP
		x += STEP
	check_fn.call(bad == 0, "decor: the filed building test answers as the full scan (%d)" % bad)
	check_fn.call(
		on * 20 < off, "decor: the building test reads %d rects where the scan read %d" % [on, off]
	)


static func _models(decor: CityDecor, check_fn: Callable) -> void:
	var street: StreetProps = decor.get("_street")
	var turns: Dictionary = street.get("_turns")
	var props := 0
	for id: String in street.placed:
		props += Num.i(street.placed[id])
	var same := true
	for key: Array in turns:
		var fresh := VoxelBuilder.new()
		StreetProps._turned(street.model(str(key[0])), Num.i(key[1]), fresh)
		var shared: VoxelBuilder = turns[key]
		same = same and fresh.cells == shared.cells and fresh.colors == shared.colors
	check_fn.call(same, "decor: each shared street prop model is the model turned")
	check_fn.call(
		not turns.is_empty() and turns.size() * 4 < props,
		"decor: %d street prop models built for %d props" % [turns.size(), props]
	)
