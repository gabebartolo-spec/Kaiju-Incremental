class_name RailView
extends Node3D
## The railway in a rampage (Rail): the viaduct and the station built once, one voxel model per
## car moved to the sim's pose each frame (yaw, then roll about its length), and the derailment's
## look and sound on the sim's events: sparks, debris, a flash and fire where the train left the
## rail, the camera shaken like a topple, a wheel screech and the crash, the long metal slide
## while a wreck still moves, the horn at the station and when the kaiju comes near, and the
## running rumble rising with the nearest train's speed. Presentation only (Rampage owns it).

## The car's floor sits this far over the sim's height (the rails and sleepers under it).
const FLOOR := 0.5
const SOUNDS := "res://assets/sfx/%s.ogg"
## How far a falling part leans per second of its fall, radians (towards its outer side).
const TILT := 0.25

var _host: Rampage
var _sim: RampageSim
var _city: CityView
## Train id -> its car nodes, lead first.
var _cars: Dictionary = {}
## Part id -> the node drawing it (RailParts); a broken part's node falls, then goes.
var _parts: Dictionary = {}
var _rumble: AudioStreamPlayer
var _slide: AudioStreamPlayer
## Train id -> when its horn may sound again (it blares while the kaiju is near).
var _horned: Dictionary = {}
## Wrecks whose survivors have not crawled out yet: [train, seconds left].
var _pending: Array = []
var _people_rng := Seeds.make("wreck_survivors", 0)
var _clock := 0.0


func _init(host: Rampage, sim: RampageSim, city: CityView) -> void:
	_host = host
	_sim = sim
	_city = city


func _ready() -> void:
	for part: RailParts.Part in _sim.rail.parts.list:
		var node := _part_model(part)
		_parts[part.id] = node
		add_child(node)
	_rumble = _loop("train_rumble")
	_slide = _loop("train_slide")


## The voxel model of one part of the viaduct or station (RailParts), built in world cells.
func _part_model(part: RailParts.Part) -> MultiMeshInstance3D:
	var rail := _sim.rail
	var cfg := rail.cfg
	var mid := Vector2(rail.avenue(), 0.0)
	match part.kind:
		RailParts.PILLAR:
			return TrainModel.column(part.x, part.z0, cfg)
		RailParts.SPAN:
			var ends := rail.point(rail.length, 1).y
			return TrainModel.span(part.x, part.z0, part.z1, part.z1 >= ends - 0.01, cfg)
		RailParts.STATION:
			var south := rail.point(rail.station_s(1), 1).y
			var long := rail.station_length()
			mid.y = south - long * 0.5
			return TrainModel.platform(part.side, Vector2(part.z0, part.z1), mid, long, cfg)
		_:
			var south := rail.point(rail.station_s(1), 1).y
			var long := rail.station_length()
			mid.y = south - long * 0.5
			return TrainModel.stairs(part.side, mid, long, cfg)


func _loop(sound: String) -> AudioStreamPlayer:
	if not ResourceLoader.exists(SOUNDS % sound):
		return null
	var player := AudioStreamPlayer.new()
	player.bus = AudioBuses.of(sound)
	var stream: AudioStreamOggVorbis = load(SOUNDS % sound)
	stream.loop = true
	player.stream = stream
	player.volume_db = -80.0
	add_child(player)
	player.play()
	return player


## A one-shot at `at`, heard in 3D from the camera (its own player, freed when done).
func _play(sound: String, at: Vector3) -> void:
	if not ResourceLoader.exists(SOUNDS % sound):
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = load(SOUNDS % sound)
	player.bus = AudioBuses.of(sound)
	player.unit_size = Num.f(_look()["unit_size"])
	player.position = at
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _process(delta: float) -> void:
	_clock += delta
	_fall_parts()
	_crawl_out(delta)
	var seen := {}
	var loudest := 0.0
	var sliding := false
	for train: Rail.Train in _sim.rail.trains:
		seen[train.id] = true
		if not _cars.has(train.id):
			_cars[train.id] = _build(train)
		var nodes: Array = _cars[train.id]
		for i: int in train.cars.size():
			var node: Node3D = nodes[i]
			_pose(node, train.cars[i])
			sliding = sliding or train.cars[i].vel.length() > 0.5
		loudest = maxf(loudest, _heard(train))
		_horn_near(train)
	for id: int in _cars.keys():
		if not seen.has(id):
			for node: Node3D in _cars[id]:
				node.queue_free()
			_cars.erase(id)
	if _rumble != null:
		_rumble.volume_db = linear_to_db(maxf(loudest, 0.0001)) + Num.f(_look()["rumble_db"])
	if _slide != null:
		_slide.volume_db = Num.f(_look()["slide_db"]) if sliding else -80.0


func _look() -> Dictionary:
	return Content.section("rail_look")


func _build(train: Rail.Train) -> Array:
	var nodes: Array = []
	for car: Rail.Car in train.cars:
		var node := Node3D.new()
		node.add_child(TrainModel.car(car.loco, Num.f(_sim.rail.cfg["car_length"])))
		add_child(node)
		nodes.append(node)
	return nodes


func _pose(node: Node3D, car: Rail.Car) -> void:
	var basis := Basis(Vector3.UP, car.yaw) * Basis(Vector3.BACK, car.roll)
	node.transform = Transform3D(basis, Vector3(car.pos.x, car.y + FLOOR, car.pos.y))


## How loud a train's run is here: its speed share, fading with the kaiju's distance.
func _heard(train: Rail.Train) -> float:
	if train.state == Rail.WRECK:
		return 0.0
	var d := train.cars[0].pos.distance_to(_sim.kaiju_pos)
	var near := clampf(1.0 - d / Num.f(_look()["hear_range"]), 0.0, 1.0)
	return near * train.v / Num.f(_sim.rail.cfg["cruise"])


## The horn blares every horn_every seconds while the kaiju is within horn_range of a running
## train (the director's answer, 022 update: it keeps running, no braking, the horn blares).
func _horn_near(train: Rail.Train) -> void:
	if train.state == Rail.WRECK or _clock < Num.f(_horned.get(train.id, 0.0)):
		return
	if train.cars[0].pos.distance_to(_sim.kaiju_pos) < Num.f(_look()["horn_range"]):
		_horned[train.id] = _clock + Num.f(_look()["horn_every"])
		_play("train_horn", _world(train.cars[0]))


func _world(car: Rail.Car) -> Vector3:
	return Vector3(car.pos.x, car.y + FLOOR, car.pos.y)


func on_event(event: Dictionary) -> void:
	match str(event["type"]):
		"train_derailed":
			_derailed(event)
		"track_broken":
			var at: Vector2 = event["at"]
			var pos := Vector3(at.x, _sim.rail.deck_y, at.y)
			for n: int in 6:
				_city.debris(pos, TrainModel._c("concrete"), Vector3.UP)
			_city.flash(pos, Color("ffd27a"), 4.0, 0.25)
		"rail_part_broken":
			_part_broken(event)
		"rail_part_landed":
			_part_landed(event)
		"train_station":
			_play("station_bell", Vector3(_sim.rail.track_x(1), _sim.rail.deck_y, 0.0))


## Sparks and a flash where the train left the rail, debris, fire, the biomass it paid, the
## shake, the screech and the crash.
func _derailed(event: Dictionary) -> void:
	var pos := Vector3(Num.f(event["x"]), _sim.rail.deck_y + FLOOR, Num.f(event["z"]))
	for n: int in 10:
		var col := TrainModel._c("stripe") if n % 2 == 0 else TrainModel._c("body")
		_city.debris(pos + Vector3(0, 0.5, 0), col, Vector3.UP)
	_city.flash(pos, Color("ffb35a"), 9.0, 0.6)
	_city.fire(pos, 0.7)
	var gained := Num.f(event["rubble"]) * _sim.stat("rubble_mult")
	_city.float_text("+%d" % Num.i(gained), pos + Vector3(0, 2, 0), UiKit.WARN)
	_host.add_trauma(_host.shake.source("topple"), pos)
	_play("train_screech", pos)
	_play("train_crash", pos)
	for train: Rail.Train in _sim.rail.trains:
		if train.id == Num.i(event["train"]):
			_pending.append([train, Num.f(_look()["crawl_s"])])


## Survivors crawl out of each car of a wreck once it has had crawl_s to come to rest, and flee.
func _crawl_out(delta: float) -> void:
	for entry: Array in _pending.duplicate():
		entry[1] = Num.f(entry[1]) - delta
		if Num.f(entry[1]) > 0.0:
			continue
		_pending.erase(entry)
		var train: Rail.Train = entry[0]
		for car: Rail.Car in train.cars:
			var count := Num.i(_look()["survivors_per_car"])
			WreckSurvivors.spill(_city.street, car.pos, count, _people_rng)


## A part snapped or began to fall: a burst of its concrete where it went.
func _part_broken(event: Dictionary) -> void:
	var at: Vector3 = event["at"]
	var count := 5 if str(event["kind"]) == RailParts.PILLAR else 3
	for n: int in count:
		_city.debris(at, TrainModel._c("column"), Vector3.UP)
	_city.fx.dust(at, 0.8)
	_host.add_trauma(_host.shake.source("drop"), at)
	if str(event["kind"]) == RailParts.PILLAR:
		_drop_node(Num.i(event["id"]))


## A part that is falling comes down as the sim says (its fall time), tilting as it goes.
func _fall_parts() -> void:
	var gravity := Num.f(_sim.city["fall_gravity"])
	for part: RailParts.Part in _sim.rail.parts.list:
		if part.alive or part.landed or not _parts.has(part.id):
			continue
		var node: MultiMeshInstance3D = _parts[part.id]
		var pivot := Vector3(part.x, part.y0, part.middle().y)
		var tilt := Basis(Vector3.BACK, part.side * part.fall_t * TILT)
		var drop := Vector3(0.0, -minf(0.5 * gravity * part.fall_t * part.fall_t, part.y0), 0.0)
		node.transform = Transform3D(tilt, pivot - tilt * pivot + drop)


## A fallen part breaks on the street: its rubble flies and the dust rises, and it is gone.
func _part_landed(event: Dictionary) -> void:
	var part: RailParts.Part = _sim.rail.parts.list[Num.i(event["id"])]
	var at := Vector3(part.x, 0.4, part.middle().y)
	for n: int in 8:
		_city.debris(at, TrainModel._c("concrete"), Vector3.UP)
	_city.fx.dust(at, 1.6)
	_host.add_trauma(_host.shake.source("drop"), at)
	_drop_node(part.id)


func _drop_node(id: int) -> void:
	if _parts.has(id):
		var node: MultiMeshInstance3D = _parts[id]
		node.queue_free()
		_parts.erase(id)
