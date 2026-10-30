class_name Traffic
extends TrafficNet
## Moving cars on the street plan (CityGen.map). Side streets are one-way (the parked rows
## leave one lane down the middle), alternating direction street by street; avenues and the
## diagonal carry a lane each way. Cars turn at crossings, queue behind the car ahead, and when
## the kaiju comes near they brake, back away and flee (the wrong way down a one-way street if
## they must). Police cruisers drive in and park across a street for a blockade. Crushed cars
## flatten like parked ones. Presentation only.

const ACCEL := 6.0
const BRAKE := 12.0
const BACK_SPEED := 0.6  # backing away, as a share of flee speed
const LANE_HALF := 0.6  # how far sideways another car still counts as in my lane
const ARRIVE_SECONDS := 1.4
const FLASH_HZ := 4.0
const CRUSHED := Vector3(1.1, 0.25, 1.1)


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
	var palette := TrafficMeshes.palette()
	_meshes = TrafficMeshes.cars(palette)
	_police_meshes = TrafficMeshes.police(palette)
	var tries := 0
	while cars.size() < Num.i(_cfg["cars"]) and tries < 500:
		tries += 1
		_spawn_random()
	DiagonalParking.park(self, sim)


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
		if TankKeepOut.run_over(sim, car):  # a tank drives over it: flattened, as by the kaiju
			crush(car.pos, 0.0)
			continue
		if car.police and swap:
			car.body.mesh = _police_meshes[lit]
		if car.parked:
			TankKeepOut.make_way(sim, car)
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


## A car's flight starts when the kaiju comes within panic_radius and ends past calm_radius.
func _scare(car: Car, kaiju: Vector2) -> void:
	var d := car.pos.distance_to(kaiju)
	if not car.fleeing and d < Num.f(_cfg["panic_radius"]):
		car.fleeing = true
		fled += 1
		car.braking = car.dir.dot(kaiju - car.pos) > 0.0  # heading at it: stop, then back away
	elif car.fleeing and d > Num.f(_cfg["calm_radius"]):
		car.fleeing = false


func _drive(car: Car, delta: float, kaiju: Vector2) -> void:
	var dir := car.dir
	_scare(car, kaiju)
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
	var wait := _blocked(car)
	if wait >= 0.0:
		target = 0.0
		car.blocked += delta
		if car.blocked > wait:
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


## How long to sit before turning round, or -1 when the lane ahead is clear. Behind a wreck or
## a parked cruiser a car soon gives up; behind a live car it queues, so jams back up the street.
func _blocked(car: Car) -> float:
	var dir := car.dir
	var gap := Num.f(_cfg["car_gap"])
	for other: Car in cars:
		if other == car:
			continue
		var rel := other.pos - car.pos
		var ahead := rel.dot(dir)
		if ahead > 0.0 and ahead < gap and absf(rel.cross(dir)) < LANE_HALF:
			var dead := other.crushed or other.parked
			return Num.f(_cfg["jam_wreck_s"]) if dead else Num.f(_cfg["jam_queue_s"])
	if TankKeepOut.in_lane(sim, car, dir):  # a tank: no waiting it out, turn round at once
		return 0.0
	return -1.0


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
