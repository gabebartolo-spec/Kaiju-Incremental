class_name CityDecor
extends Node3D
## Street life on the street plan (CityGen.map): cars parked along the kerbs, streetlights at
## the crossings and down the long blocks, trees in the park, round the plaza and along the
## diagonal avenue, and parking lots full of cars; street trees down the avenues, gardens and
## a playground in every park, hedges and flowers in the front yards (D-065). All seeded, all
## voxels; cars, trees, bushes, flowers, swings and lights flatten under the kaiju's feet.
## Presentation only.

const PROP_VOXEL := 0.25
const CROSSING_CLEAR := 3.0  # no parking this close to a crossing
const LAMP_EVERY := 13.0
## Half the footprint of car(): 3 voxels across and 6 long (PROP_VOXEL), along its street.
const CAR_HALF := Vector2(0.375, 0.75)

var sim: RampageSim
var plan: Dictionary
## D-065 greenery counts (CityGreenery.green), for the city suite and the report.
var green: Dictionary = {}
var cars: Array[Rect2] = []  # every car's ground footprint, parked or stopped
var islands: Array[Vector2] = []  # traffic islands' middles (TrafficIsland), for the tests
var trampling := true  # off only for a before/after capture of the same frame
var _rng: RandomNumberGenerator
var _props := PropField.new(PROP_VOXEL)
var _half: float
var _view: float  # parked cars reach this far from the centre: the arena and what the camera
# shows past its edge (city.view_beyond)
var _lamps: Array[PooledLight] = []
var _footprints: Array[Rect2] = []
var _water: Array[Rect2] = []  # the river and its bridges (CityRiver): no car parks, no lamp
var _paints := 0  # how many car paints
var _walked := Vector2(INF, INF)  # where the kaiju stood last frame (trample)
var _kaiju: KaijuModel  # the drawn kaiju (found once), whose body tramples what it covers
var _foot := Rect2()  # its ground box in its own frame: x across, y along (model z)
var _fx := Fx.new()  # puffs where trees are crushed
var _lamp_spots: Array[Vector2] = []
var _park_trees: Array[Vector2] = []
var _kerb := TreeSpots.new()  # the street trees' kerb spots (CityGreenery.kerb_spots)
var _trees: CityTrees  # the park, plaza ring and diagonal trees


## Parked and moving car paints (city.car_colors), each light enough to read against the
## asphalt under fog (D-062).
static func car_colors() -> Array[Color]:
	var out: Array[Color] = []
	var raw: Array = Content.section("city")["car_colors"]
	for hex: String in raw:
		out.append(Color(hex))
	return out


func _init(p_sim: RampageSim, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	_rng = rng
	plan = CityGen.map(sim.city)
	_half = CityGen.half_extent(sim.city)
	_paints = car_colors().size()
	_view = sim.arena_half + Num.f(sim.city["view_beyond"])
	for channel: Rect2 in CityRiver.water(plan, sim.city):
		_water.append(channel.grow(0.5 + CAR_HALF.y))  # a car at a bridge end clears the wall
	for basin: Rect2 in CityRiver.bay(plan, sim.city):
		_props.keep_out.append(basin.grow(0.3))  # nothing planted in the bay the kaiju rises in
	for b: RampageSim.Building in sim.buildings:
		_footprints.append(Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d).grow(0.4))


func _ready() -> void:
	# The street trees' kerb spots first, so the parking leaves room for them (D-065).
	var greenery := CityGreenery.new(self, _rng)
	for spot: Vector2 in greenery.kerb_spots():
		_kerb.add(spot)
	_streets()
	_trees = CityTrees.new(self, _rng)
	_blocks()
	_trees.diagonal()
	# D-065 greenery planted last, so the cars and trees before it keep their RNG draws.
	greenery.plant()
	green = greenery.green
	RiverQuay.plant(self)
	TrafficIsland.plant(self)  # last: an all-junction cell left with nothing gets an island
	var palette := {
		"glass": Color("2b3640"),
		"wheel": Color("1a1a1a"),
		"ivory": Color("b8b2a0"),
		"tail": Color("6a1a1a"),
		"bark": Color("5a4030"),
		"leaf": Color("55703f"),
		"leaf_dark": Color("3f5832"),
		"pole": Color("4a4c4e"),
		"lamp": Color(1.0, 0.86, 0.6, 0.0),
	}
	var paints := car_colors()
	for i: int in paints.size():
		palette["car%d" % i] = paints[i]
	palette.merge(CityGreenery.PALETTE)
	var island: Dictionary = sim.city["traffic_island"]["colors"]
	for key: String in island:
		palette[key] = Color(str(island[key]))
	var quay: Dictionary = sim.city["river_quay"]["colors"]
	for key: String in quay:
		palette[key] = Color(str(quay[key]))
	add_child(_props.build(palette, 31, 3.0))
	_props.configure(sim.city)
	add_child(_fx)
	add_child(_props.leaf_field)
	add_child(_props.bark_field)


## Whatever the kaiju's body walks over goes down on that frame, not only what a stomp hits, so
## a walk leaves a continuous trampled path (D-065): every prop whose base lies under the drawn
## body's ground box (the model's own, at its stage, species, scale and facing; the middle
## city.trample_share of it, as the splayed feet and tail tip only reach its corners). A tree
## bursts into debris on the frame it is crushed, with an earth puff at its stump. On the
## ground only; presentation only, the sim never knows.
func _process(_delta: float) -> void:
	var at := sim.kaiju_pos
	if at != _walked and _walked.x != INF and not sim.airborne and trampling and _found_kaiju():
		var body := _kaiju.global_transform
		_props.crush_box(body, _foot)
		var into := body.affine_inverse()
		for lamp: PooledLight in _lamps.duplicate():
			var local := into * Vector3(lamp.position.x, body.origin.y, lamp.position.z)
			if _foot.has_point(Vector2(local.x, local.z)):
				_lamps.erase(lamp)
				lamp.queue_free()
	_walked = at
	_props.throw(_fx)


## Finds the drawn kaiju beside this city and its ground box (KaijuFootprint); false where
## there is none (stills, tests).
func _found_kaiju() -> bool:
	if is_instance_valid(_kaiju) and _foot.has_area():
		return true
	_kaiju = KaijuFootprint.find(self)
	if _kaiju == null:
		return false
	_foot = KaijuFootprint.of(_kaiju, sim.size_tier(), Num.f(sim.city["trample_share"]))
	return _foot.has_area()


## Flattens props under a stomp.
func crush(at: Vector3, radius: float) -> void:
	if trampling:
		_props.crush(at, radius)
	for lamp: PooledLight in _lamps.duplicate():
		if Vector2(lamp.position.x - at.x, lamp.position.z - at.z).length() <= radius:
			_lamps.erase(lamp)
			lamp.queue_free()


func _inside(p: Vector2, margin: float = 0.0) -> bool:
	return maxf(absf(p.x), absf(p.y)) <= _half + margin


func _on_building(p: Vector2) -> bool:
	for r: Rect2 in _footprints + _water:
		if r.has_point(p):
			return true
	return false


## Parked cars along both kerbs, now and then one stopped in the lane, out past the playable
## edge as far as the camera sees (D-062: no empty ground); a streetlight at a corner of every
## crossing and down the long blocks of the playable city.
func _streets() -> void:
	var nodes: Array[Vector2] = plan["nodes"]
	var lit_nodes := {}
	var chance := Num.f(sim.city["parked_chance"])
	var chance_beyond := Num.f(sim.city["parked_chance_beyond"])
	var lane_stop := Num.f(sim.city["lane_stop_chance"])
	var gap: Array = sim.city["parked_gap"]
	for street: Dictionary in plan["streets"]:
		var kind := str(street["kind"])
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		if not (_inside(a, _view - _half) or _inside(b, _view - _half)) or kind == CityGen.ALLEY:
			continue
		var playable := _inside(a, 0.5) and _inside(b, 0.5)
		var width := Num.f(street["width"])
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var length := a.distance_to(b)
		if kind != CityGen.DIAGONAL:
			var along_x := absf(dir.x) > 0.5
			# Past the edge, where nothing drives, cars may stand where a street runs into the
			# diagonal, and a short block still gets one mid-kerb (D-062: no bare asphalt).
			for kerb: float in [-1.0, 1.0]:
				var t := CROSSING_CLEAR + _rng.randf_range(0.0, 2.0)
				if not playable and t >= length - CROSSING_CLEAR:
					t = length * 0.5
				while t < length - CROSSING_CLEAR or is_equal_approx(t, length * 0.5):
					var lane := width * 0.5 - 0.6
					if _rng.randf() < lane_stop:
						lane = width * 0.25  # stopped in the traffic lane
					var p := a + dir * t + side * kerb * lane
					var color := "car%d" % _rng.randi_range(0, _paints - 1)
					var on_diagonal := (
						playable
						and (
							CityGen.diagonal_distance(plan, p)
							< CityGen.width_of(CityGen.DIAGONAL, sim.city) * 0.5 + 1.0
						)
					)
					var seen := _inside(p, _view - _half) and not _on_building(p)
					var half := Vector2(CAR_HALF.y, CAR_HALF.x) if along_x else CAR_HALF
					var body := Rect2(p - half, half * 2.0)
					if (
						_rng.randf() < (chance if playable else chance_beyond)
						and not on_diagonal
						and seen
						and _clear_of_trees(body)
					):
						_props.add(
							Vector3(p.x, 0, p.y),
							func(v: VoxelBuilder) -> void: car(v, color, along_x)
						)
						cars.append(body)
					t += _rng.randf_range(Num.f(gap[0]), Num.f(gap[1]))
		if not playable:
			continue  # past the edge: cars only (lamps only on the streets)
		for end: int in [Num.i(street["from"]), Num.i(street["to"])]:
			if not lit_nodes.has(end) and kind != CityGen.DIAGONAL:
				lit_nodes[end] = true
				var corner := nodes[end] + (dir + side) * (width * 0.5 + 0.7)
				_lamp(corner, -(dir + side))
		var t2 := LAMP_EVERY
		var flip := 1.0
		while t2 < length - LAMP_EVERY * 0.6:
			var p2 := a + dir * t2 + side * flip * (width * 0.5 + 0.6)
			_lamp(p2, -side * flip)
			flip = -flip
			t2 += LAMP_EVERY


## No street tree's trunk within city.street_tree_car_clear of a car body (the parking slot
## drops instead).
func _clear_of_trees(body: Rect2) -> bool:
	return not _kerb.near_box(body, Num.f(sim.city["street_tree_car_clear"]))


## A streetlight at p whose arm reaches toward `toward` (over the road), with a pooled light.
func _lamp(p: Vector2, toward: Vector2) -> void:
	if _on_building(p):
		return
	var arm := Vector2i(roundi(signf(toward.x)), roundi(signf(toward.y)))
	_lamp_spots.append(p)
	_props.add(Vector3(p.x, 0, p.y), func(v: VoxelBuilder) -> void: _streetlight(v, arm))
	var light := PooledLight.new("lamp")
	light.light_color = Color("ffd59a")
	light.set_energy(Look.value("lamp_energy"))
	light.omni_range = 6.0
	light.position = Vector3(p.x + arm.x * 0.5, 2.4, p.y + arm.y * 0.5)
	add_child(light)
	_lamps.append(light)


## The park, the plaza and the parking lots.
func _blocks() -> void:
	for block: Dictionary in plan["blocks"]:
		var rect: Rect2 = block["rect"]
		match str(block["use"]):
			"park":
				_trees.park(rect)
			"plaza", "landmark":  # trees round the plaza (round a landmark too)
				_trees.ring(rect)
			"parking":
				var bays := rect.grow(-0.6)
				var x := bays.position.x + 1.65
				while x < bays.end.x - 0.6:
					for z: float in [bays.position.y + 1.2, bays.end.y - 1.2]:
						if _rng.randf() < 0.7:
							var color := "car%d" % _rng.randi_range(0, _paints - 1)
							_props.add(
								Vector3(x, 0, z),
								func(v: VoxelBuilder) -> void: car(v, color, false)
							)
					x += 1.3


## A car (about 1.5 long at PROP_VOXEL), nose to -Z (to -X when along_x). Traffic reuses it.
static func car(v: VoxelBuilder, color: String, along_x: bool) -> void:
	var local := VoxelBuilder.new()
	local.box(Vector3i(-1, 0, -3), Vector3i(1, 1, 2), color)
	local.box(Vector3i(-1, 2, -1), Vector3i(1, 2, 1), "glass")
	for wheel: Vector3i in [
		Vector3i(-1, 0, -2), Vector3i(1, 0, -2), Vector3i(-1, 0, 1), Vector3i(1, 0, 1)
	]:
		local.put(wheel, "wheel")
	local.put(Vector3i(-1, 1, -3), "ivory")
	local.put(Vector3i(1, 1, -3), "ivory")
	local.put(Vector3i(-1, 1, 2), "tail")
	local.put(Vector3i(1, 1, 2), "tail")
	for cell: Vector3i in local.cells:
		var placed := Vector3i(cell.z, cell.y, cell.x) if along_x else cell
		v.put(placed, local.key_at(cell))


## arm: which way (x, z signs) the lamp arm reaches.
func _streetlight(v: VoxelBuilder, arm: Vector2i) -> void:
	var reach := Vector3i(arm.x * 2, 0, arm.y * 2)
	v.box(Vector3i(0, 0, 0), Vector3i(0, 11, 0), "pole")
	v.box(Vector3i(0, 11, 0), reach + Vector3i(0, 11, 0), "pole")
	v.put(reach + Vector3i(0, 10, 0), "lamp")
