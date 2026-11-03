class_name TaskforceGunships
extends RefCounted
## The Taskforce's gunships (D-143, D-145, D-152), adult city only: up to 2 at once, beside the
## city's own helicopters (which keep coming, D-143). They fly as the military helicopters do
## (AirFlight: a stand-off ring, glides, strafing passes) and fire a blue laser cannon on the
## helicopters' own cadence and damage (tuning "air"); like any helicopter, a blow that reaches
## the air downs one (no hit points, D-437) and pays a helicopter's rubble. Only the cap is the
## Taskforce's own number (tuning "taskforce" "gunships"). Part of Taskforce; pure and seeded.
## Events: gunship_spawned, gunship_laser (from, to), gunship_destroyed.

var sim: RampageSim
var cfg: Dictionary
var flight: AirFlight  # made on first use: the Army (and so this) is built before the air wing
var ships: Array[AirWing.Heli] = []
var kills := 0
var _rng: RandomNumberGenerator
var _timer := 0.0
var _next_id := 0


func _init(p_sim: RampageSim, p_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = p_cfg
	_rng = rng


## How many may fly at once in this city (none before the adult city).
func cap() -> int:
	var by_tier: Array = cfg["max_by_tier"]
	return Num.i(by_tier[clampi(sim.size_tier() - 1, 0, by_tier.size() - 1)])


## `open`: the Taskforce has joined this rampage. A downed gunship is replaced after the
## helicopters' own call-in `interval`.
func step(dt: float, open: bool) -> void:
	if open and ships.size() < cap():
		_timer -= dt
		if _timer <= 0.0:
			_timer = Num.f(_air()["interval"])
			spawn()
	_flight().step(ships, dt)
	var air := _air()
	for ship: AirWing.Heli in ships:
		ship.cooldown -= dt
		if ship.cooldown > 0.0:
			continue
		ship.cooldown = Num.f(air["fire_interval"])
		var hurt := Num.f(air["damage"]) - sim.stat("armor")
		sim.hp -= maxf(Num.f(sim.army["min_damage"]), hurt)
		var from := Vector3(ship.pos.x, altitude(), ship.pos.y)
		var to := Vector3(sim.kaiju_pos.x, sim.stand_y, sim.kaiju_pos.y)
		sim.events.append({"type": "gunship_laser", "ship": ship.id, "from": from, "to": to})


## A gunship flying in from beyond its ring on the far side from the camera.
func spawn() -> AirWing.Heli:
	var ship := AirWing.Heli.new()
	ship.id = _next_id
	_next_id += 1
	_flight().place(ship)
	ship.cooldown = Num.f(_air()["fire_interval"]) * Num.f(_air()["first_burst_delay"])
	ships.append(ship)
	sim.events.append({"type": "gunship_spawned", "ship": ship.id})
	return ship


func altitude() -> float:
	return Num.f(_air()["altitude"])


## An area blow downs every gunship it reaches, when it reaches the air (as AirWing.hit).
func hit(force: Callable, damage: float, reaches_air: bool) -> void:
	if not reaches_air or damage <= 0.0:
		return
	var alive: Array[AirWing.Heli] = []
	for ship: AirWing.Heli in ships:
		if Num.f(force.call(ship.pos, Num.f(_air()["heli_radius"]))) <= 0.0:
			alive.append(ship)
			continue
		kills += 1
		sim.rubble += Num.f(_air()["rubble"]) * sim.stat("rubble_mult")
		sim.events.append(
			{"type": "gunship_destroyed", "ship": ship.id, "x": ship.pos.x, "z": ship.pos.y}
		)
	ships = alive


func _flight() -> AirFlight:
	if flight == null:
		flight = AirFlight.new(sim, _air(), _rng)
	return flight


func _air() -> Dictionary:
	return sim.air.cfg
