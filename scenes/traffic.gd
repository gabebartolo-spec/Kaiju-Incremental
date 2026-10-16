class_name Traffic
extends Node3D
## Moving cars on the street grid. Streets are one-way (the parked rows leave one lane down the
## middle), alternating direction street by street; cars turn at crossings, queue behind the
## car ahead, and when the kaiju comes near they brake, back away and flee. Police cruisers
## drive in and park across a street for a blockade. Crushed cars flatten like parked ones.
## Presentation only.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
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
	var dir := Vector2i(0, -1)
	var node := Vector2i.ZERO  # the crossing it is driving to
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
var _grid: int
var _half: float
var _spacing: float
var _meshes: Array[ArrayMesh] = []
var _police_meshes: Array[ArrayMesh] = []
var _clock := 0.0
var _lit := 0


func _init(p_sim: RampageSim, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	_rng = rng
	_cfg = Content.section("street")
	_grid = Num.i(sim.city["grid"])
	_spacing = Num.f(sim.city["spacing"])
	_half = CityGen.half_extent(sim.city)


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


## Street centre line k = 0..grid (the same lines CityDecor marks).
func street(k: int) -> float:
	return -_half + (k - 0.5) * _spacing


func crossing(n: Vector2i) -> Vector2:
	return Vector2(street(n.x), street(n.y))


## One-way rule: a street's direction alternates with its index.
func _oneway(k: int) -> int:
	return 1 if k % 2 == 0 else -1


func _in_grid(n: Vector2i) -> bool:
	return n.x >= 0 and n.y >= 0 and n.x <= _grid and n.y <= _grid


func _legal(at: Vector2i, d: Vector2i) -> bool:
	if not _in_grid(at + d):
		return false
	return d.x == _oneway(at.y) if d.x != 0 else d.y == _oneway(at.x)


func _spawn_random() -> void:
	var from := Vector2i(_rng.randi_range(0, _grid), _rng.randi_range(0, _grid))
	var options: Array[Vector2i] = []
	for d: Vector2i in DIRS:
		if _legal(from, d):
			options.append(d)
	if options.is_empty():
		return
	var d := options[_rng.randi_range(0, options.size() - 1)]
	var pos := crossing(from) + Vector2(d) * _rng.randf_range(1.0, _spacing - 1.0)
	for other: Car in cars:
		if other.pos.distance_to(pos) < Num.f(_cfg["car_gap"]) + 0.5:
			return
	var car := _make(_meshes[_rng.randi_range(0, _meshes.size() - 1)], false)
	car.pos = pos
	car.dir = d
	car.node = from + d
	car.speed = Num.f(_cfg["drive_speed"])
	_place(car, 1.0)


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
	var dir := Vector2(car.dir)
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
		var room := maxf(0.0, (crossing(car.node) - car.pos).dot(dir))
		car.pos += dir * minf(car.speed * delta, room)
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
	var rest := (crossing(car.node) - car.pos).dot(dir)
	if step < rest:
		car.pos += dir * step
		return
	car.pos = crossing(car.node)
	car.backing = false
	car.dir = _next_dir(car, kaiju)
	car.node += car.dir


## Reverses along the street: backing up (still facing the kaiju) or a full U-turn.
func _turn_back(car: Car, backing: bool) -> void:
	car.node -= car.dir
	car.dir = -car.dir
	car.backing = backing
	car.blocked = 0.0


func _blocked(car: Car) -> bool:
	var dir := Vector2(car.dir)
	var gap := Num.f(_cfg["car_gap"])
	for other: Car in cars:
		if other == car:
			continue
		var rel := other.pos - car.pos
		var ahead := rel.dot(dir)
		if ahead > 0.0 and ahead < gap and absf(rel.cross(dir)) < LANE_HALF:
			return true
	return false


func _next_dir(car: Car, kaiju: Vector2) -> Vector2i:
	var at := car.node
	var options: Array[Vector2i] = []
	for d: Vector2i in DIRS:
		if d == -car.dir:
			continue
		if _legal(at, d) or (car.fleeing and _in_grid(at + d)):
			options.append(d)
	if options.is_empty():
		return -car.dir if _in_grid(at - car.dir) else car.dir
	if not car.fleeing:
		return options[_rng.randi_range(0, options.size() - 1)]
	var best := options[0]
	for d: Vector2i in options:
		if crossing(at + d).distance_to(kaiju) > crossing(at + best).distance_to(kaiju):
			best = d
	return best


func _place(car: Car, delta: float) -> void:
	var facing := Vector2(-car.dir) if car.backing else Vector2(car.dir)
	if car.arrive_t >= 0.0 or car.parked:
		var drive := car.arrive_to - car.arrive_from
		facing = car.arrive_facing if car.arrive_t > 0.6 or car.parked else drive
	car.view.position = Vector3(car.pos.x, 0.0, car.pos.y)
	var yaw := atan2(-facing.x, -facing.y)
	car.view.rotation.y = lerp_angle(car.view.rotation.y, yaw, minf(1.0, delta * 8.0))
