class_name CityGreenery
extends RefCounted
## D-065 (director 2026-10-18: "make sure there are a believable amount of trees, bushes,
## floral areas, parks, gardens, playgrounds throughout the city"): plants CityDecor's
## greenery into its PropField, so every tree, bush, flower bed and swing flattens under the
## kaiju like the cars do: street trees down the avenues, a garden and a playground in every
## park, hedges and flowers in the front yards. Seeded; presentation only.

const PALETTE := {
	"bush": Color("4f6a3a"),
	"bush_dark": Color("3a5230"),
	"soil": Color("4a3a2c"),
	"flower_red": Color("b8443a"),
	"flower_yellow": Color("d8b440"),
	"flower_white": Color("d8d4c8"),
	"flower_pink": Color("c87890"),
	"play_mat": Color("6a4a3a"),
	"play_red": Color("b04838"),
	"play_yellow": Color("d0a838"),
	"play_blue": Color("3a6a98"),
	"play_metal": Color("8a8e90"),
}

## What was planted: "street_trees" (positions), "avenue_m" (avenue length they line),
## "bushes", "flower_beds", "playgrounds", "parks", "yards" (building faces with a front yard),
## "hedges" (bushes planted in those yards).
var green := {
	"street_trees": [] as Array[Vector2],
	"avenue_m": 0.0,
	"bushes": 0,
	"flower_beds": 0,
	"playgrounds": 0,
	"parks": 0,
	"yards": 0,
	"hedges": 0,
}
var _sim: RampageSim
var _plan: Dictionary
var _props: PropField
var _rng: RandomNumberGenerator
var _on_building: Callable  # Callable(p: Vector2) -> bool
var _lamps: Array[Vector2]
var _park_trees: Array[Vector2]
var _half: float


## decor: the CityDecor whose PropField this plants into (its lamps and park trees are kept
## clear); rng: the decor's own stream, drawn after everything it placed.
func _init(decor: CityDecor, rng: RandomNumberGenerator) -> void:
	_sim = decor.sim
	_plan = decor.plan
	_props = decor._props
	_rng = rng
	_on_building = decor._on_building
	_lamps = decor._lamp_spots
	_park_trees = decor._park_trees
	_half = CityGen.half_extent(_sim.city)


func _inside(p: Vector2, margin: float) -> bool:
	return maxf(absf(p.x), absf(p.y)) <= _half + margin


## D-065 (director 2026-10-18: "make sure there are a believable amount of trees, bushes,
## floral areas, parks, gardens, playgrounds throughout the city"): street trees down the
## avenues, a garden and a playground in every park, hedges and flowers in the front yards.
func plant() -> void:
	_avenue_trees()
	for block: Dictionary in _plan["blocks"]:
		var rect: Rect2 = block["rect"]
		if str(block["use"]) == "park" and _inside(rect.get_center(), 0.0):
			_park_garden(rect)
	_yards()


## A street tree every city.street_tree_gap metres down both pavements of every avenue in the
## playable city, clear of the crossings (city.street_tree_clear), the lamps and the diagonal.
func _avenue_trees() -> void:
	var nodes: Array[Vector2] = _plan["nodes"]
	var gap: Array = _sim.city["street_tree_gap"]
	var clear := Num.f(_sim.city["street_tree_clear"])
	var walk := Num.f(_sim.city["sidewalk"])
	var diagonal := CityGen.width_of(CityGen.DIAGONAL, _sim.city) * 0.5 + walk
	var trees: Array[Vector2] = green["street_trees"]
	for street: Dictionary in _plan["streets"]:
		if str(street["kind"]) != CityGen.AVENUE:
			continue
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		if not (_inside(a, 0.5) and _inside(b, 0.5)):
			continue
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var length := a.distance_to(b)
		var kerb := Num.f(street["width"]) * 0.5 + walk * 0.45
		green["avenue_m"] = Num.f(green["avenue_m"]) + length
		for s: float in [-1.0, 1.0]:
			var t := clear + _rng.randf_range(0.0, Num.f(gap[0]) * 0.5)
			while t < length - clear:
				var p := a + dir * t + side * s * kerb
				var clear_of_lamps := true
				for lamp: Vector2 in _lamps:
					clear_of_lamps = clear_of_lamps and lamp.distance_to(p) > walk * 1.5
				if (
					clear_of_lamps
					and not _on_building.call(p)
					and CityGen.diagonal_distance(_plan, p) > diagonal
				):
					_props.add(Vector3(p.x, 0, p.y), _street_tree)
					trees.append(p)
				t += _rng.randf_range(Num.f(gap[0]), Num.f(gap[1]))


## Where a park's playground goes (city.playground_size square in its south-west corner), or
## an empty Rect2 when the park is too small. CityDecor keeps its park trees off it.
static func playground_pad(park: Rect2, cfg: Dictionary) -> Rect2:
	var inner := park.grow(-1.0)
	var pad := Num.f(cfg["playground_size"])
	if inner.size.x < pad * 2.0 or inner.size.y < pad:
		return Rect2()
	return Rect2(inner.position.x, inner.end.y - pad, pad, pad)


## A park's garden: a low hedge round its edge with gaps for the middle path, hedges and flower
## beds down both sides of the path (city.park_flower_beds per 100 m2), and a playground.
func _park_garden(rect: Rect2) -> void:
	green["parks"] = Num.i(green["parks"]) + 1
	var mid := rect.get_center().x
	var inner := rect.grow(-1.0)
	var gap := Num.f(_sim.city["garden_bush_gap"])
	var play_rect := playground_pad(rect, _sim.city)
	if play_rect.has_area():
		var at := play_rect.get_center()
		_props.add(Vector3(at.x, 0, at.y), _playground)
		green["playgrounds"] = Num.i(green["playgrounds"]) + 1
	var beds := roundi(rect.get_area() / 100.0 * Num.f(_sim.city["park_flower_beds"]))
	var spots: Array[Vector2] = []
	var z := inner.position.y + gap * 0.5
	while z < inner.end.y:
		for s: float in [-1.0, 1.0]:
			spots.append(Vector2(mid + s * 1.6, z))
		z += gap
	# The border hedge, open where the path meets the street.
	var border := rect.grow(-0.6)
	var x := border.position.x + gap * 0.5
	while x < border.end.x:
		if absf(x - mid) > 1.6:
			spots.append(Vector2(x, border.position.y))
			spots.append(Vector2(x, border.end.y))
		x += gap
	z = border.position.y + gap * 1.5
	while z < border.end.y - gap:
		spots.append(Vector2(border.position.x, z))
		spots.append(Vector2(border.end.x, z))
		z += gap
	var blooms: Array[String] = ["flower_red", "flower_yellow", "flower_white", "flower_pink"]
	for i: int in spots.size():
		var p := spots[i]
		if play_rect.grow(0.4).has_point(p) or _near_park_tree(p):
			continue
		if beds > 0 and i % 3 == 1:
			var bloom := blooms[_rng.randi_range(0, blooms.size() - 1)]
			_props.add(Vector3(p.x, 0, p.y), func(v: VoxelBuilder) -> void: _flower_bed(v, bloom))
			green["flower_beds"] = Num.i(green["flower_beds"]) + 1
			beds -= 1
		else:
			_props.add(Vector3(p.x, 0, p.y), _bush)
			green["bushes"] = Num.i(green["bushes"]) + 1


func _near_park_tree(p: Vector2) -> bool:
	for tree: Vector2 in _park_trees:
		if tree.distance_to(p) < 1.0:
			return true
	return false


## Front yards: where a house steps back off the street (CityLots yards, city.yard_depth deep),
## a hedge with now and then a flower bed fills the strip between its wall and the pavement.
func _yards() -> void:
	var depth_range: Array = _sim.city["yard_depth"]
	var gap := Num.f(_sim.city["garden_bush_gap"])
	var rects: Array[Rect2] = []
	for block: Dictionary in _plan["blocks"]:
		if str(block["use"]) == "built":
			rects.append(block["rect"])
	for b: RampageSim.Building in _sim.buildings:
		var box := Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d)
		for rect: Rect2 in rects:
			if not rect.has_point(box.get_center()):
				continue
			var gaps: Array[float] = [
				box.position.y - rect.position.y,
				rect.end.y - box.end.y,
				box.position.x - rect.position.x,
				rect.end.x - box.end.x,
			]
			var normals: Array[Vector2] = [
				Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)
			]
			for f: int in 4:
				var depth := gaps[f]
				if depth < Num.f(depth_range[0]) or depth > Num.f(depth_range[1]):
					continue
				green["yards"] = Num.i(green["yards"]) + 1
				var normal := normals[f]
				var along := Vector2(-normal.y, normal.x)
				var span := absf(along.dot(box.size))
				var reach := absf(normal.dot(box.size)) * 0.5 + depth * 0.5
				var centre := box.get_center() + normal * reach
				var t := -span * 0.5 + gap * 0.5
				while t < span * 0.5:
					var p := centre + along * t
					if _rng.randf() < 0.25:
						_props.add(
							Vector3(p.x, 0, p.y),
							func(v: VoxelBuilder) -> void: _flower_bed(v, "flower_white")
						)
						green["flower_beds"] = Num.i(green["flower_beds"]) + 1
					else:
						_props.add(Vector3(p.x, 0, p.y), _bush)
						green["hedges"] = Num.i(green["hedges"]) + 1
					t += gap
			break


## A street tree: slimmer than a park tree, so its crown stays over the pavement.
func _street_tree(v: VoxelBuilder) -> void:
	var tall := 5 + _rng.randi_range(0, 2)
	v.box(Vector3i(0, 0, 0), Vector3i(0, tall, 0), "bark")
	var r := _rng.randf_range(1.6, 2.1)
	v.blob(Vector3(0.0, tall + r * 0.7, 0.0), Vector3(r, r * 0.9, r), "leaf")
	v.blob(Vector3(r * 0.4, tall + r * 0.4, 0.0), Vector3(r * 0.6, r * 0.5, r * 0.6), "leaf_dark")


## A low round bush.
func _bush(v: VoxelBuilder) -> void:
	var r := _rng.randf_range(1.3, 1.9)
	v.blob(Vector3(0.0, r * 0.6, 0.0), Vector3(r, r * 0.7, r), "bush")
	v.blob(Vector3(r * 0.3, r * 0.4, r * 0.2), Vector3(r * 0.6, r * 0.5, r * 0.6), "bush_dark")


## A flower bed: a soil border with blooms of one colour on top, leaves between.
func _flower_bed(v: VoxelBuilder, bloom: String) -> void:
	v.box(Vector3i(-2, 0, -1), Vector3i(2, 0, 1), "soil")
	for x: int in range(-2, 3):
		for z: int in range(-1, 2):
			v.put(Vector3i(x, 1, z), bloom if posmod(x + z, 2) == 0 else "bush")


## A playground on a soft pad (city.playground_size): a slide, a swing frame, a climbing frame.
func _playground(v: VoxelBuilder) -> void:
	var half := roundi(Num.f(_sim.city["playground_size"]) * 0.5 / CityDecor.PROP_VOXEL) - 1
	v.box(Vector3i(-half, 0, -half), Vector3i(half, 0, half), "play_mat")
	# The slide: a tower and a ramp down to the pad.
	v.box(Vector3i(-half + 1, 1, -half + 1), Vector3i(-half + 2, 6, -half + 2), "play_red")
	for k: int in 6:
		var x := -half + 3 + k
		v.box(Vector3i(x, 6 - k, -half + 1), Vector3i(x, 6 - k, -half + 2), "play_yellow")
	# The swings: two posts, a top bar, two seats.
	for x: int in [1, half - 1]:
		v.box(Vector3i(x, 1, half - 2), Vector3i(x, 8, half - 2), "play_metal")
	v.box(Vector3i(1, 8, half - 2), Vector3i(half - 1, 8, half - 2), "play_metal")
	for x: int in [3, half - 3]:
		v.put(Vector3i(x, 3, half - 2), "play_blue")
	# The climbing frame: four posts and a top rail.
	var c0 := Vector3i(-half + 1, 1, 1)
	var c1 := Vector3i(-half + 4, 4, 4)
	for x: int in [c0.x, c1.x]:
		for z: int in [c0.z, c1.z]:
			v.box(Vector3i(x, c0.y, z), Vector3i(x, c1.y, z), "play_metal")
	v.box(Vector3i(c0.x, c1.y, c0.z), Vector3i(c1.x, c1.y, c0.z), "play_blue")
	v.box(Vector3i(c0.x, c1.y, c1.z), Vector3i(c1.x, c1.y, c1.z), "play_blue")
