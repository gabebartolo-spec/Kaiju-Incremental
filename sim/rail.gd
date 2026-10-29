class_name Rail
extends RefCounted
## The city's elevated railway (the director 2026-10-21 #63 "train stations + tracks with trains on
## them", #69 "Derail and smash"; research in the 022 result): a two-track viaduct up the avenue
## nearest the city's middle, crossing the river on its own deck, with one station. Trains (a
## locomotive and its carriages, coupled at a fixed spacing) run on a schedule: they speed up,
## cruise, brake into the station, dwell and go on, one each way. A hit strong enough (a stomp,
## tail, breath, swipe: RampageSim.hit_area) on a car derails its train: the hit car is kicked
## sideways, the cars behind fold the other way and back again (the jackknife), all slide on with
## their momentum against friction, roll, and any car off the deck falls to the street; the
## couplers are gone, a car that runs into the one ahead shares its speed (the concertina). The
## viaduct and the station are voxel structures among the city's buildings (RailLayout, `pieces`):
## the kaiju's body, its blows and toppled towers carve them, and they settle and fall, by the
## rules every building does (Carving, Collapse; the director 2026-10-25 "destroyed with the same
## logic as all other buildings"). The track is broken wherever the deck under it is gone: a
## train over it derails, a train behind stops short of it, or ploughs in if it cannot. Pure and
## seeded: positions are on the ground plane (x, z) with a height y; the presentation reads them.
## Every number: tuning "rail".

const RUN := "run"
const DWELL := "dwell"
const STOPPED := "stopped"
const WRECK := "wreck"

static var _x_cache := {}


class Car:
	var pos := Vector2.ZERO
	var y := 0.0
	var yaw := 0.0
	var roll := 0.0
	var vel := Vector2.ZERO
	var vy := 0.0
	var yaw_rate := 0.0
	var roll_rate := 0.0
	var loco := false


class Train:
	var id := 0
	## +1 runs north to south (z rising) on the west track, -1 back on the east track.
	var dir := 1
	## The lead car's front along the line (0..length, from the train's own start).
	var s := 0.0
	var v := 0.0
	var state := RUN
	var dwell := 0.0
	var dwelled := false
	var cars: Array[Car] = []


var cfg: Dictionary
var trains: Array[Train] = []
var length := 0.0
var deck_y := 0.0
var derailed := 0
## The viaduct's pieces: their indices in the sim's buildings (RailLayout), north to south.
var pieces: Array[int] = []
## The station stands while the deck under it does.
var station_standing := true
var _sim: RampageSim
var _rng: RandomNumberGenerator
var _x := 0.0
var _z0 := 0.0
var _station := Vector2.ZERO  # station_span, from the north end
var _next := 0.0
var _next_id := 0
var _dir := 1
## Broken track: along-line positions measured from the north end.
var _breaks: Array[float] = []
## Piece index -> its standing chunks when last read.
var _alive_seen: Dictionary = {}
var _wreck := RailWreck.new(self)


func _init(sim: RampageSim, tuning: Dictionary, rng: RandomNumberGenerator) -> void:
	_sim = sim
	cfg = tuning["rail"]
	_rng = rng
	var line := RailLayout.ends(sim.city, cfg)
	_z0 = line.x
	length = line.y - line.x
	var st := RailLayout.station_z(sim.city, cfg)
	_station = Vector2(st.x - _z0, st.y - _z0)
	deck_y = Num.f(cfg["deck_y"])
	_x = avenue_x(sim.city)
	_next = Num.f(cfg["first_s"])


## The x of the north-south avenue nearest the city's middle (not the ring), from the street plan
## (none: the middle). The fixed front (D-381) spans the whole width north of the back street, so
## every avenue ends there and the line with it (RailLayout.ends), short of the beach.
static func avenue_x(city: Dictionary) -> float:
	var key := "%s:%s" % [city["map_seed"], city["half"]]
	if _x_cache.has(key):
		return Num.f(_x_cache[key])
	var half := CityGen.half_extent(city)
	var plan := CityGen.map(city)
	var nodes: Array = plan["nodes"]
	var best := INF
	for street: Dictionary in plan["streets"]:
		var a: Vector2 = nodes[Num.i(street["from"])]
		var b: Vector2 = nodes[Num.i(street["to"])]
		if str(street["kind"]) != CityGen.AVENUE or absf(a.x - b.x) > 0.01:
			continue
		if absf(a.x) < half - 1.0 and absf(a.x) < absf(best):
			best = a.x
	if best == INF:
		best = 0.0
	_x_cache[key] = best
	return best


## The x of the track a train running `dir` uses.
func track_x(dir: int) -> float:
	return _x - dir * Num.f(cfg["track_gap"]) * 0.5


## The ground point at `s` along the line for a train running `dir`.
func point(s: float, dir: int) -> Vector2:
	var z := _z0 + s if dir > 0 else _z0 + length - s
	return Vector2(track_x(dir), z)


## The station's place along the line for a train running `dir`: its platforms' middle.
func station_s(dir: int) -> float:
	var st := station_span()
	var at := (st.x + st.y) * 0.5
	return at if dir > 0 else length - at


func step(dt: float) -> void:
	_next -= dt
	if _next <= 0.0 and _running() < Num.i(cfg["max_trains"]):
		_spawn()
		_next = Num.f(cfg["headway_s"])
	for train: Train in trains.duplicate():
		if train.state == WRECK:
			_wreck.slide(train, dt)
		else:
			_drive(train, dt)
			if train.s - _tail(train) > length:
				trains.erase(train)
	_body_contact()
	_read_deck()


func _running() -> int:
	var n := 0
	for train: Train in trains:
		n += int(train.state != WRECK)
	return n


func _spawn() -> void:
	var train := Train.new()
	train.id = _next_id
	_next_id += 1
	train.dir = _dir
	_dir = -_dir
	for i: int in Num.i(cfg["cars"]):
		var car := Car.new()
		car.loco = i == 0
		car.y = deck_y
		train.cars.append(car)
	train.v = Num.f(cfg["cruise"]) * Num.f(cfg["enter_share"])
	trains.append(train)
	_place(train)
	_sim.events.append({"type": "train_spawned", "train": train.id})


## The length from the lead car's front to the last car's back.
func _tail(train: Train) -> float:
	var n := train.cars.size()
	return n * Num.f(cfg["car_length"]) + (n - 1) * Num.f(cfg["coupler_gap"])


## Puts every car on the track behind the lead car's front.
func _place(train: Train) -> void:
	var pitch := Num.f(cfg["car_length"]) + Num.f(cfg["coupler_gap"])
	for i: int in train.cars.size():
		var car := train.cars[i]
		car.pos = point(train.s - Num.f(cfg["car_length"]) * 0.5 - i * pitch, train.dir)
		car.yaw = 0.0 if train.dir > 0 else PI


## Speeds up to cruise, brakes for the station and for anything ahead on its track.
func _drive(train: Train, dt: float) -> void:
	if train.state == DWELL:
		train.dwell -= dt
		if train.dwell <= 0.0:
			train.state = RUN
		return
	var stop := _stop_ahead(train)
	var room := stop - train.s
	var brake := Num.f(cfg["brake"])
	if train.v * train.v / (2.0 * brake) >= room - 0.05:
		var hard := Num.f(cfg["emergency"]) if room < _station_room(train) else brake
		train.v = maxf(0.0, train.v - hard * dt)
	else:
		train.v = minf(Num.f(cfg["cruise"]), train.v + Num.f(cfg["accel"]) * dt)
	train.s = minf(train.s + train.v * dt, stop)
	if train.v <= 0.0 and room < 0.5:
		_arrive(train, stop)
	_place(train)
	if _blocked(train):
		derail(train, 0, Vector2.ZERO)


## Where the train must stop next: the station it has not served, the broken track or the
## wreck ahead on its line, else far beyond the line's end.
func _stop_ahead(train: Train) -> float:
	var stop := INF
	if not train.dwelled:
		stop = station_s(train.dir) if train.s <= station_s(train.dir) else INF
	for at: float in _breaks:
		var s := at if train.dir > 0 else length - at
		if s > train.s and s - Num.f(cfg["stop_short"]) < stop:
			stop = s - Num.f(cfg["stop_short"])
	return stop


func _station_room(train: Train) -> float:
	return INF if train.dwelled else station_s(train.dir) - train.s + 0.01


func _arrive(train: Train, stop: float) -> void:
	if not train.dwelled and absf(stop - station_s(train.dir)) < 0.01:
		train.dwelled = true
		train.state = DWELL
		train.dwell = Num.f(cfg["dwell_s"])
		_sim.events.append({"type": "train_station", "train": train.id})
	else:
		train.state = STOPPED


## A running train that reached broken track it could not stop for.
func _blocked(train: Train) -> bool:
	for at: float in _breaks:
		var s := at if train.dir > 0 else length - at
		if train.s >= s and train.s - _tail(train) < s and train.v > Num.f(cfg["crash_speed"]):
			return true
	return false


## Breaks both tracks at `at` along the line (from the north end); a train over it derails.
func break_track(at: float) -> void:
	for s: float in _breaks:
		if absf(s - at) < Num.f(cfg["car_length"]):
			return
	_breaks.append(at)
	_sim.events.append({"type": "track_broken", "at": point(at, 1), "s": at})
	var st := station_span()
	if station_standing and at > st.x and at < st.y:  # the station goes with the deck under it
		station_standing = false
		_sim.events.append({"type": "station_broken", "at": point(station_s(1), 1)})
	var pitch := Num.f(cfg["car_length"]) + Num.f(cfg["coupler_gap"])
	for train: Train in trains.duplicate():
		if train.state == WRECK:
			continue
		var s := at if train.dir > 0 else length - at
		if train.s >= s and train.s - _tail(train) <= s:
			derail(
				train, clampi(floori((train.s - s) / pitch), 0, train.cars.size() - 1), Vector2.ZERO
			)


func broken() -> Array[float]:
	return _breaks.duplicate()


## A hit (RampageSim.hit_area's force and damage): any car it hits hard enough derails its
## train. The viaduct under it is carved by the same hit, as a building (RampageSim.hit_area).
func hit(force: Callable, damage: float) -> void:
	var need := Num.f(cfg["derail_damage"])
	for train: Train in trains:
		if train.state == WRECK:
			continue
		for i: int in train.cars.size():
			var k: float = force.call(train.cars[i].pos, Num.f(cfg["car_radius"]))
			if damage * k >= need:
				derail(train, i, train.cars[i].pos)
				break


## The pieces that lost a chunk since the last step are read again: the track breaks wherever
## the deck under it is gone (RailLayout.deck_gaps).
func _read_deck() -> void:
	for n: int in pieces:
		var alive := _sim.buildings[n].frame.alive_count
		if Num.i(_alive_seen[n]) != alive:
			_alive_seen[n] = alive
			for at: float in RailLayout.deck_gaps(_sim.buildings[n], self):
				break_track(at)


## Building n is a piece of the line (RampageSim builds them from RailLayout).
func add_piece(n: int) -> void:
	pieces.append(n)
	_alive_seen[n] = _sim.buildings[n].frame.alive_count


## The viaduct's x centre (the deck and the station are built round it).
func centre_x() -> float:
	return (track_x(1) + track_x(-1)) * 0.5


## The station's span along the line (from the north end): its platforms (RailLayout).
func station_span() -> Vector2:
	return _station


## The kaiju's body walking into a train (when it stands tall enough to reach the deck).
func _body_contact() -> void:
	if _sim.reach_height() < deck_y:
		return
	var r := _sim.stomp_radius() * Num.f(cfg["body_share"])
	for train: Train in trains:
		if train.state == WRECK:
			continue
		for i: int in train.cars.size():
			if train.cars[i].pos.distance_to(_sim.kaiju_pos) < r:
				derail(train, i, _sim.kaiju_pos)
				break


## Derails `train` at car `hit_index`, struck from `from` (ZERO: ran into broken track).
func derail(train: Train, hit_index: int, from: Vector2) -> void:
	train.state = WRECK
	derailed += 1
	var ahead := Vector2(0.0, train.dir)
	var side := Vector2(1.0, 0.0)
	var car := train.cars[hit_index]
	var away := 1.0 if from == Vector2.ZERO else signf(car.pos.x - from.x)
	if away == 0.0:
		away = 1.0 if _rng.randf() < 0.5 else -1.0
	var kick := Num.f(cfg["kick"])
	for i: int in train.cars.size():
		var c := train.cars[i]
		var fold := away * (1.0 if (i - hit_index) % 2 == 0 else -1.0)
		var near := 1.0 / (1.0 + absf(i - hit_index))
		c.vel = ahead * train.v + side * fold * kick * near * _rng.randf_range(0.7, 1.2)
		c.yaw_rate = fold * Num.f(cfg["yaw_rate"]) * _rng.randf_range(0.6, 1.3)
		c.roll_rate = fold * Num.f(cfg["roll_rate"]) * _rng.randf_range(0.3, 1.2) * near
	# Each car pays like a vehicle, and the derailment a big one-off bonus on top (the director's
	# answer, 022 update: "well above a car").
	var pay := Num.f(_sim.army["tank_rubble"]) * Num.f(cfg["rubble_share"]) * train.cars.size()
	pay += Num.f(cfg["derail_bonus"])
	_sim.rubble += pay * _sim.stat("rubble_mult")
	train.v = 0.0
	if from != Vector2.ZERO:
		break_track(_along(car.pos))
	_sim.events.append(
		{"type": "train_derailed", "train": train.id, "x": car.pos.x, "z": car.pos.y, "rubble": pay}
	)


## The along-line position (from the north end) nearest `at`.
func _along(at: Vector2) -> float:
	return clampf(at.y - _z0, 0.0, length)
