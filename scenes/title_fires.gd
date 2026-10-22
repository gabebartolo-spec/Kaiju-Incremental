class_name TitleFires
extends RefCounted
## The title's burning district (comments #88, #98, #99, D-151): the tallest far-shore towers each
## burn at the roof with a smoke column, a few floors up the street face a flame pours out of a
## window hole, two hero blazes per focus engulf several floors, and the burning floors' windows
## glow fire-orange. Every fire is the game's own Fire at a zoom (FarFire). Presentation only;
## numbers in tuning "title" "fires".

## Window flames stand this far out from the wall (m), clear of its facade.
const WINDOW_OUT := 0.6

var _city: Node3D
var _cfg: Dictionary
var _far_z: float
## Each window fire's window (its middle on the wall), for the glowing panes beside it.
var _burning: Array[Vector3] = []
var _hero_windows: Array[Vector3] = []


func _init(city: Node3D, cfg: Dictionary, far_z: float) -> void:
	_city = city
	_cfg = cfg
	_far_z = far_z


## A district burns: the tallest far-shore towers around each focus each burn at the top.
func light() -> PackedFloat32Array:
	var stands: Array[Dictionary] = []
	for node: Node in _city.find_children("*", "CitySkyline", true, false):
		stands.append_array((node as CitySkyline).stand_ins())
	var lit := PackedFloat32Array()
	var rng := Seeds.make("title_fire", 0)
	var far: Dictionary = _cfg["far"]
	var no_smoke := far.duplicate()
	no_smoke["smoke_density"] = 0.0
	var foci: Array = _cfg["foci"]
	for at: Array in foci:
		var towers := _tallest(Vector2(Num.f(at[0]), Num.f(at[1])), stands)
		for n: int in mini(Num.i(_cfg["count"]), towers.size()):
			var centre: Vector3 = towers[n]["centre"]
			var size: Vector3 = towers[n]["size"]
			# The tallest burn at the roof; the others part way up their street face.
			var up := 0.5 if n < Num.i(_cfg["roof_fires"]) else rng.randf_range(-0.25, 0.25)
			# Only the roof fires give a smoke column: fewer, thicker ones.
			var fire := FarFire.new(far if up >= 0.5 else no_smoke, rng.randf() * 10.0)
			fire.position = centre + Vector3(0.0, size.y * up, size.z * 0.5 if up < 0.5 else 0.0)
			_city.add_child(fire)
			lit.append(fire.position.x)
			_window_fires(centre, size, _cfg, rng)
			if n < Num.i(_cfg["hero_per_focus"]):
				lit.append(_hero_blaze(centre, size, _cfg, rng))
	_burn_windows()
	return lit


## The front-row stand-in towers within the burning radius of `focus`, tallest first.
func _tallest(focus: Vector2, stands: Array[Dictionary]) -> Array[Dictionary]:
	var towers: Array[Dictionary] = []
	for box: Dictionary in stands:
		var centre: Vector3 = box["at"]
		var front := centre.z < _far_z and centre.z > _far_z - Num.f(_cfg["depth"])
		if front and Vector2(centre.x, centre.z).distance_to(focus) <= Num.f(_cfg["radius"]):
			towers.append({"centre": centre, "size": box["size"]})
	towers.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var size_a: Vector3 = a["size"]
			var size_b: Vector3 = b["size"]
			return size_a.y > size_b.y
	)
	return towers


## Flames pouring out of the windows of a burning tower, on several floors of its street face:
## each fire stands in a real window cell of the facade's grid (the emitters are anchored in the
## window rects) and the floor's windows beside it glow fire-orange (D-151), see _burn_windows().
func _window_fires(
	centre: Vector3, size: Vector3, cfg: Dictionary, rng: RandomNumberGenerator
) -> void:
	var far: Dictionary = cfg["far"]
	var window: Dictionary = cfg["window"]
	var spec := far.duplicate()
	spec.merge(window, true)
	var grain := CitySkyline.FAR_GRAIN
	for _i: int in Num.i(cfg["window_fires"]):
		var fire := FarFire.new(spec, rng.randf() * 10.0)
		var wall := centre.z + size.z * 0.5
		var at := Vector3(
			centre.x + rng.randf_range(-0.4, 0.4) * size.x,
			centre.y + size.y * rng.randf_range(-0.25, 0.4),
			wall
		)
		# A window is one cell wide and two rows tall, its lower row on a multiple of four rows
		# (+1): snap the fire to the middle of the window it comes out of.
		var column := floorf(at.x * grain)
		var floor_row := floorf(at.y * grain / 4.0) * 4.0 + 1.0
		at.x = (column + 0.5) / grain
		at.y = (floor_row + 1.0) / grain
		_burning.append(at)
		fire.position = at + Vector3(0.0, 0.0, WINDOW_OUT)
		_city.add_child(fire)


## A hero blaze: a stack of big window fires up several floors of one tower's street face, the
## flames pouring out of the window holes and up the wall, its floors' windows fire-orange. Returns
## its x (for the bay's reflection).
func _hero_blaze(
	centre: Vector3, size: Vector3, cfg: Dictionary, rng: RandomNumberGenerator
) -> float:
	var hero: Dictionary = cfg["hero"]
	var far: Dictionary = cfg["far"]
	var spec := far.duplicate()
	spec.merge(hero, true)
	var grain := CitySkyline.FAR_GRAIN
	var column := floorf((centre.x + rng.randf_range(-0.25, 0.25) * size.x) * grain)
	var rise := centre.y + size.y * rng.randf_range(-0.1, 0.25)
	var base_row := floorf(rise * grain / 4.0) * 4.0 + 1.0
	var floors := Num.i(hero["floors"])
	for level: int in floors:
		var floor_spec := spec.duplicate()
		if level < floors - 1:
			floor_spec["smoke_density"] = 0.0  # the top floor's fire gives the column
		var fire := FarFire.new(floor_spec, rng.randf() * 10.0)
		var sway := rng.randf_range(-1.0, 1.0) * Num.f(hero["spread"])
		var at := Vector3(
			(column + 0.5 + sway) / grain,
			(base_row + 4.0 * level + 1.0) / grain,
			centre.z + size.z * 0.5
		)
		_hero_windows.append(at)
		fire.position = at + Vector3(0.0, 0.0, WINDOW_OUT)
		_city.add_child(fire)
	return (column + 0.5) / grain


## The burning floors' windows: fire-orange panes along each fire's floor (the hero blazes' wider).
func _burn_windows() -> void:
	var windows: Dictionary = _cfg["windows"]
	_city.add_child(TitleBurningWindows.new(_burning, windows))
	var hero_windows := windows.duplicate()
	var hero: Dictionary = _cfg["hero"]
	hero_windows["cells"] = hero["cells"]
	_city.add_child(TitleBurningWindows.new(_hero_windows, hero_windows))
