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

var _host: Rampage
var _sim: RampageSim
var _city: CityView
## Train id -> its car nodes, lead first.
var _cars: Dictionary = {}
var _rumble: AudioStreamPlayer
var _slide: AudioStreamPlayer
var _horned: Dictionary = {}


func _init(host: Rampage, sim: RampageSim, city: CityView) -> void:
	_host = host
	_sim = sim
	_city = city


func _ready() -> void:
	var rail := _sim.rail
	var north := rail.point(0.0, 1)
	var south := rail.point(rail.length, 1)
	var mid := (north.x + rail.track_x(-1)) * 0.5
	add_child(TrainModel.viaduct(mid, north.y, south.y, rail.cfg))
	var at := rail.point(rail.station_s(1), 1)
	var long := Num.i(rail.cfg["cars"]) * (Num.f(rail.cfg["car_length"]) + 0.3) + 2.0
	add_child(TrainModel.station(mid, at.y - long * 0.5, long, rail.cfg))
	_rumble = _loop("train_rumble")
	_slide = _loop("train_slide")


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


func _play(sound: String, at: Vector3) -> void:
	if ResourceLoader.exists(SOUNDS % sound):
		_host.sfx.play_at(sound, at)


func _process(_delta: float) -> void:
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


## The horn once per train when the kaiju first comes within horn_range of it.
func _horn_near(train: Rail.Train) -> void:
	if train.state == Rail.WRECK or _horned.has(train.id):
		return
	if train.cars[0].pos.distance_to(_sim.kaiju_pos) < Num.f(_look()["horn_range"]):
		_horned[train.id] = true
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
