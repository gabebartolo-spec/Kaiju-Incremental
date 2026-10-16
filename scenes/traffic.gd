class_name Traffic
extends Node3D
## Moving cars on the street plan (CityGen.map). Side streets are one-way (the parked rows
## leave one lane down the middle), alternating direction street by street; avenues and the
## diagonal carry a lane each way. Cars turn at crossings, queue behind the car ahead, and when
## the kaiju comes near they brake, back away and flee (the wrong way down a one-way street if
## they must). Police cruisers drive in and park across a street for a blockade. Crushed cars
## flatten like parked ones. Presentation only.

const TWO_WAY_LANE := 1.0  # avenues: each lane's middle this far from the centre line
const ACCEL := 6.0
const BRAKE := 12.0
const BACK_SPEED := 0.6  # backing away, as a share of flee speed
const UTURN_AFTER := 2.5  # seconds stuck behind something before turning round
const LANE_HALF := 0.6  # how far sideways another car still counts as in my lane
const ARRIVE_SECONDS := 1.4
const FLASH_HZ := 4.0
const CRUSHED := Vector3(1.1, 0.25, 1.1)
const LIGHT_GLOW := 2.5  # police light bars


class Car:
	extends RefCounted
	var pos := Vector2.ZERO
	var line := Vector2.ZERO  # its point on the street's centre line (pos is off it by lane)
	var dir := Vector2(0, -1)
	var node := 0  # the crossing it is driving to
	var from := 0  # the crossing it came from
	var lane := 0.0  # sideways from the centre line, to the right of dir
	var speed := 0.0
	var fleeing := false
	var braking := false
	var backing := false
	var crushed := false
	var police := false
	var parked := false
	var blocked := 0.0
	var arrive_t := -1.0
	var arrive_from := Vector2.ZERO
	var arrive_to := Vector2.ZERO
	var arrive_facing := Vector2.ZERO
	var view: Node3D
	var body: MeshInstance3D


var sim: RampageSim
var cars: Array[Car] = []
## Cars that started fleeing the kaiju (tests read it).
var fled := 0
var _cfg: Dictionary
var _rng: RandomNumberGenerator
var _half: float
var _nodes: Array[Vector2] = []
## Per crossing: the lanes out of it, {"to": node, "lane": offset}, and the crossings every
## street it touches leads to (a fleeing car may drive any of them).
var _lanes: Array[Array] = []
var _links: Array[Array] = []
var _ends: Array[Vector2i] = []  # every lane as (from, to), for spawning
var _meshes: Array[ArrayMesh] = []
var _police_meshes: Array[ArrayMesh] = []
var _clock := 0.0
var _lit := 0


func _init(p_sim: RampageSim, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	_rng = rng
	_cfg = Content.section("street")
	_half = CityGen.half_extent(sim.city)
	_build_lanes(CityGen.map(sim.city))


func _ready() -> void:
	var palette := _car_palette()
	for i: int in CityDecor.CAR_COLORS.size():
		var v := VoxelBuilder.new()
		v.salt = 40 + i
		CityDecor.car(v, "car%d" % i, false)
		_meshes.append(_bake(v, palette))
	for lit: int in 2:  # light bar: red lit, then blue lit
		var v := VoxelBuilder.new()
		v.salt = 50
		CityDecor.car(v, "police", false)
		v.repaint(
			func(cell: Vector3i, key: String) -> String:
				return "police_low" if key == "police" and cell.y == 0 else key
		)
		v.put(Vector3i(-1, 3, 0), "red_lit" if lit == 0 else "red")
		v.put(Vector3i(0, 3, 0), "bar")
		v.put(Vector3i(1, 3, 0), "blue" if lit == 0 else "blue_lit")
		_police_meshes.append(_bake(v, palette))
	var tries := 0
	while cars.size() < Num.i(_cfg["cars"]) and tries < 500:
		tries += 1
		_spawn_random()


func _car_palette() -> Dictionary:
	var palette := {
		"glass": Color("2b3640"),
		"wheel": Color("1a1a1a"),
		"ivory": Color("b8b2a0"),
		"tail": Color("6a1a1a"),
		"police": Color("d8d8d2"),
		"police_low": Color("1c1e22"),
		"bar": Color("2a2a2a"),
		"red": Color("4a1414"),
		"blue": Color("14204a"),
		"red_lit": Color(1.0, 0.12, 0.08, 0.0),
		"blue_lit": Color(0.15, 0.3, 1.0, 0.0),
	}
	for i: int in CityDecor.CAR_COLORS.size():
		palette["car%d" % i] = CityDecor.CAR_COLORS[i]
	return palette


func _bake(v: VoxelBuilder, palette: Dictionary) -> ArrayMesh:
	# Car cells span z -3..2: shift half a cell so the car's middle sits on its position.
	var voxel := CityDecor.PROP_VOXEL
	return v.bake(palette, voxel, Vector3(0, 0, voxel * 0.5), LIGHT_GLOW)


## The drivable network inside the playable city: alleys carry no cars.
func _build_lanes(plan: Dictionary) -> void:
	_nodes = plan["nodes"]
	for n: int in _nodes.size():
		_lanes.append([])
		_links.append([])
	var xs: Array[float] = plan["xs"]
	var zs: Array[float] = plan["zs"]
	for street: Dictionary in plan["streets"]:
		var kind := str(street["kind"])
		var a := Num.i(street["from"])
		var b := Num.i(street["to"])
		if kind == CityGen.ALLEY or not (_inside(_nodes[a]) and _inside(_nodes[b])):
			continue
		_links[a].append(b)
		_links[b].append(a)
		if kind != CityGen.STREET:
			_add_lane(a, b, TWO_WAY_LANE)
			_add_lane(b, a, TWO_WAY_LANE)
			continue
		# One-way, alternating with the street's index along its axis.
		var d := _nodes[b] - _nodes[a]
		var vertical := absf(d.y) > absf(d.x)
		var index := xs.find(_nodes[a].x) if vertical else zs.find(_nodes[a].y)
		var forward := (d.y if vertical else d.x) > 0.0
		if (posmod(index, 2) == 0) == forward:
			_add_lane(a, b, 0.0)
		else:
			_add_lane(b, a, 0.0)


func _add_lane(a: int, b: int, lane: float) -> void:
	_lanes[a].append({"to": b, "lane": lane})
	_ends.append(Vector2i(a, b))


func _inside(p: Vector2) -> bool:
	return maxf(absf(p.x), absf(p.y)) <= _half + 0.5


func crossing(n: int) -> Vector2:
	return _nodes[n]


## Crossings inside the city that cars can reach (the police pick blockade spots from these).
func crossings() -> Array[int]:
	var out: Array[int] = []
	for n: int in _nodes.size():
		if not _links[n].is_empty():
			out.append(n)
	return out


## Unit directions of the streets leaving crossing n.
func street_dirs(n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for other: int in _links[n]:
		out.append((_nodes[other] - _nodes[n]).normalized())
	return out


func _spawn_random() -> void:
	if _ends.is_empty():
		return
	var end := _ends[_rng.randi_range(0, _ends.size() - 1)]
	var length := _nodes[end.x].distance_to(_nodes[end.y])
	if length < 3.0:
		return
	var probe := Car.new()
	_enter(probe, end.x, end.y)
	probe.line = _nodes[end.x] + probe.dir * _rng.randf_range(1.0, length - 1.0)
	probe.pos = probe.line + _right(probe) * probe.lane
	for other: Car in cars:
		if other.pos.distance_to(probe.pos) < Num.f(_cfg["car_gap"]) + 0.5:
			return
	var car := _make(_meshes[_rng.randi_range(0, _meshes.size() - 1)], false)
	_enter(car, end.x, end.y)
	car.line = probe.line
	car.pos = probe.pos
	car.speed = Num.f(_cfg["drive_speed"])
	_place(car, 1.0)


## Puts a car on the lane from crossing a to crossing b.
func _enter(car: Car, a: int, b: int) -> void:
	car.from = a
	car.node = b
	car.dir = (_nodes[b] - _nodes[a]).normalized()
	car.lane = 0.0
	for lane: Dictionary in _lanes[a]:
		if Num.i(lane["to"]) == b:
			car.lane = Num.f(lane["lane"])


func _right(car: Car) -> Vector2:
	return Vector2(-car.dir.y, car.dir.x)


func _make(mesh: ArrayMesh, police: bool) -> Car:
	var car := Car.new()
	car.police = police
	car.view = Node3D.new()
	car.body = MeshInstance3D.new()
	car.body.mesh = mesh
	car.view.add_child(car.body)
	add_child(car.view)
	cars.append(car)
	return car


## A police cruiser drives from `from` and parks at `to` facing `facing`. Oldest cruiser goes
## when there are too many.
func add_police(from: Vector2, to: Vector2, facing: Vector2) -> void:
	var police: Array[Car] = []
	for c: Car in cars:
		if c.police:
			police.append(c)
	if police.size() >= Num.i(_cfg["max_police_cars"]):
		var old := police[0]
		cars.erase(old)
		old.view.queue_free()
	var car := _make(_police_meshes[0], true)
	car.pos = from
	car.arrive_from = from
	car.arrive_to = to
	car.arrive_facing = facing
	car.arrive_t = 0.0
	_place(car, 1.0)


## Flattens every car whose middle is within `radius` (plus half a car) of `at`.
func crush(at: Vector2, radius: float) -> void:
	for car: Car in cars:
		if not car.crushed and car.pos.distance_to(at) <= radius + 0.4:
			car.crushed = true
			car.speed = 0.0
			car.arrive_t = -1.0
			car.view.scale = CRUSHED


## Called by StreetLife each frame (so the bench counts traffic in its cost).
func update(delta: float) -> void:
	_clock += delta
	var kaiju := sim.kaiju_pos
	var lit := int(_clock * FLASH_HZ) % 2
	var swap := lit != _lit
	_lit = lit
	for car: Car in cars:
		if car.crushed:
			continue
		if car.police and swap:
			car.body.mesh = _police_meshes[lit]
		if car.arrive_t >= 0.0:
			_arrive(car, delta)
		elif not car.parked:
			_drive(car, delta, kaiju)
		_place(car, delta)


func _arrive(car: Car, delta: float) -> void:
	car.arrive_t = minf(1.0, car.arrive_t + delta / ARRIVE_SECONDS)
	var k := 1.0 - (1.0 - car.arrive_t) * (1.0 - car.arrive_t)
	car.pos = car.arrive_from.lerp(car.arrive_to, k)
	if car.arrive_t >= 1.0:
		car.arrive_t = -1.0
		car.parked = true


func _drive(car: Car, delta: float, kaiju: Vector2) -> void:
	var d := car.pos.distance_to(kaiju)
	var dir := car.dir
	if not car.fleeing and d < Num.f(_cfg["panic_radius"]):
		car.fleeing = true
		fled += 1
		car.braking = dir.dot(kaiju - car.pos) > 0.0  # heading at it: stop, then back away
	elif car.fleeing and d > Num.f(_cfg["calm_radius"]):
		car.fleeing = false
	var target := Num.f(_cfg["flee_speed"]) if car.fleeing else Num.f(_cfg["drive_speed"])
	if car.backing:
		target *= BACK_SPEED
	if car.braking:
		car.speed = move_toward(car.speed, 0.0, BRAKE * delta)
		var room := maxf(0.0, (_nodes[car.node] - car.line).dot(dir))
		car.line += dir * minf(car.speed * delta, room)
		car.pos = car.line + _right(car) * car.lane
		if car.speed <= 0.0:
			car.braking = false
			_turn_back(car, true)
		return
	if _blocked(car):
		target = 0.0
		car.blocked += delta
		if car.blocked > UTURN_AFTER:
			_turn_back(car, false)
	else:
		car.blocked = 0.0
	var rate := ACCEL if target > car.speed else BRAKE
	car.speed = move_toward(car.speed, target, rate * delta)
	var step := car.speed * delta
	var rest := (_nodes[car.node] - car.line).dot(dir)
	if step < rest:
		car.line += dir * step
		car.pos = car.line + _right(car) * car.lane
		return
	car.line = _nodes[car.node]
	car.backing = false
	_enter(car, car.node, _next_node(car, kaiju))
	car.pos = car.line + _right(car) * car.lane


## Reverses along the street: backing up (still facing the kaiju) or a full U-turn.
func _turn_back(car: Car, backing: bool) -> void:
	var was := car.node
	car.node = car.from
	car.from = was
	car.dir = -car.dir
	if backing:
		car.lane = -car.lane  # the same spot on the road, now reversing
	car.backing = backing
	car.blocked = 0.0


func _blocked(car: Car) -> bool:
	var dir := car.dir
	var gap := Num.f(_cfg["car_gap"])
	for other: Car in cars:
		if other == car:
			continue
		var rel := other.pos - car.pos
		var ahead := rel.dot(dir)
		if ahead > 0.0 and ahead < gap and absf(rel.cross(dir)) < LANE_HALF:
			return true
	return false


## The crossing to drive to next from car.node: a legal lane at random, or, fleeing, any
## street that leads furthest from the kaiju.
func _next_node(car: Car, kaiju: Vector2) -> int:
	var at := car.node
	var options: Array[int] = []
	for lane: Dictionary in _lanes[at]:
		if Num.i(lane["to"]) != car.from:
			options.append(Num.i(lane["to"]))
	if car.fleeing:
		for other: int in _links[at]:
			if other != car.from and not options.has(other):
				options.append(other)
	if options.is_empty():
		return car.from
	if not car.fleeing:
		return options[_rng.randi_range(0, options.size() - 1)]
	var best := options[0]
	for n: int in options:
		if _nodes[n].distance_to(kaiju) > _nodes[best].distance_to(kaiju):
			best = n
	return best


func _place(car: Car, delta: float) -> void:
	var facing := -car.dir if car.backing else car.dir
	if car.arrive_t >= 0.0 or car.parked:
		var drive := car.arrive_to - car.arrive_from
		facing = car.arrive_facing if car.arrive_t > 0.6 or car.parked else drive
	car.view.position = Vector3(car.pos.x, 0.0, car.pos.y)
	var yaw := atan2(-facing.x, -facing.y)
	car.view.rotation.y = lerp_angle(car.view.rotation.y, yaw, minf(1.0, delta * 8.0))
