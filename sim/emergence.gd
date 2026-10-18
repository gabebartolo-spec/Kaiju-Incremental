class_name Emergence
extends RefCounted
## The start of a run (D-083, director 2026-10-19: "a city caught unaware - have our reptilian
## emerge from a river to start each run"): the kaiju waits submerged in the city's river
## (CityRiver), rises out of it over tuning "emerge" "rise_seconds", wades out onto the city's
## bank (inside the arena), and then the run begins: the sim
## emits "kaiju_emerged" (the army's alert ramp starts from it). Until then nothing else
## happens: no clock, no stomps, no army. Only a run the game starts (Rampage.setup) emerges;
## a RampageSim built on its own starts on land, as before.

var active := false
var _t := 0.0
var _rise: float
var _depth: float
var _wade: float
var _bed: float  # how far the river's water lies below the street (city "river_depth")
var _spawn: Vector2
var _bank: Vector2
var _water: Array[Rect2]  # the river's channels (CityRiver.channels)


func _init(city: Dictionary, tuning: Dictionary) -> void:
	var cfg: Dictionary = tuning["emerge"]
	_rise = Num.f(cfg["rise_seconds"])
	_depth = Num.f(cfg["depth"])
	_wade = Num.f(cfg["wade_speed"])
	_bed = Num.f(city.get("river_depth", 0.0))
	var plan := CityGen.map(city)
	_water = CityRiver.channels(plan, city)
	_spawn = plan.get("river_spawn", Vector2(INF, INF))
	_bank = plan.get("river_bank", _spawn)


## Puts the kaiju under the river's surface; the run waits until it has risen. A city without
## a river starts on land at once.
func start(sim: RampageSim) -> void:
	if _spawn.x == INF:
		return
	active = true
	_t = 0.0
	sim.kaiju_pos = _spawn
	sim.stand_y = -_depth * sim.body_scale()


## How far through its rise the kaiju is, 0 (under) to 1 (wading in the river).
func risen() -> float:
	return clampf(_t / _rise, 0.0, 1.0) if active else 1.0


## Advances the rise; true while it holds the rest of the sim back.
func step(sim: RampageSim, dt: float) -> bool:
	if not active:
		return false
	_t += dt
	if _t < _rise:
		var up := smoothstep(0.0, 1.0, _t / _rise)
		sim.stand_y = lerpf(-_depth * sim.body_scale(), -_bed, up)  # up to wading depth
		return true
	var bank := sim.clamp_to_arena(_bank)
	var stride := sim.stat("speed") * _wade * dt
	var floor_y := 0.0
	for water: Rect2 in _water:
		if water.has_point(sim.kaiju_pos):
			floor_y = -_bed
	sim.stand_y = move_toward(sim.stand_y, floor_y, stride)  # climbs out over the quay
	if sim.kaiju_pos.distance_to(bank) > stride or sim.stand_y < 0.0:
		sim.facing = sim.kaiju_pos.direction_to(bank) if sim.kaiju_pos != bank else sim.facing
		sim.kaiju_pos = sim.kaiju_pos.move_toward(bank, stride)
		return true
	sim.kaiju_pos = bank
	active = false
	sim.events.append({"type": "kaiju_emerged"})
	return true
