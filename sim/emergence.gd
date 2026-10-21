class_name Emergence
extends RefCounted
## The start of a run (D-083, director 2026-10-19: "a city caught unaware - have our reptilian
## emerge from a river to start each run"): the kaiju waits submerged in the city's river
## (CityRiver), rises out of it over tuning "emerge" "rise_seconds", wades out onto the city's
## bank (inside the arena), and then the run begins: the sim
## emits "kaiju_emerged" (the army's alert ramp starts from it). Until then nothing else
## happens: no clock, no stomps, no army. Only a run the game starts (Rampage.setup) emerges;
## a RampageSim built on its own starts on land, as before. The whole start never takes longer
## than "emerge" "max_seconds": past it the kaiju steps onto the bank point at once, so nothing
## (a bank point in the water, a wade that cannot finish) can stall a run before it begins.

var active := false
var _t := 0.0
var _rise: float
var _depth: float
var _wade: float
var _cap: float
var _bed: float  # how far the river's water lies below the street (city "river_depth")
var _spawn: Vector2
var _bank: Vector2
var _plan: Dictionary  # the city's street plan (CityGen.map): its river, bay and shore
var _city: Dictionary


func _init(city: Dictionary, tuning: Dictionary) -> void:
	var cfg: Dictionary = tuning["emerge"]
	_rise = Num.f(cfg["rise_seconds"])
	_depth = Num.f(cfg["depth"])
	_wade = Num.f(cfg["wade_speed"])
	_cap = Num.f(cfg["max_seconds"])
	_bed = Num.f(city.get("river_depth", 0.0))
	_city = city
	_plan = CityGen.map(city)
	_spawn = _plan.get("river_spawn", Vector2(INF, INF))
	_bank = _plan.get("river_bank", _spawn)


## Puts the kaiju under the river's surface; the run waits until it has risen. A city without
## a river starts on land at once.
func start(sim: RampageSim) -> void:
	if _spawn.x == INF:
		return
	active = true
	_t = 0.0
	sim.kaiju_pos = _rise_point(sim)
	sim.stand_y = -_depth * sim.body_scale()
	# It rises already facing the city, the way it will walk out (director 2026-10-21 #17: "have
	# him emerging facing the city so he can walk straight in"), in the river's bay, wide enough
	# for its whole body (director 2026-10-20: "emerging from the water, not from the asphalt").
	sim.facing = _ahead()
	sim.body.heading = sim.facing


## How far through its rise the kaiju is, 0 (under) to 1 (wading in the river).
func risen() -> float:
	return clampf(_t / _rise, 0.0, 1.0) if active else 1.0


## Advances the rise; true while it holds the rest of the sim back. While it does, the
## buildings around the kaiju get their fine grids ready (Carving.warm), so its first blows
## land on warm ones.
func step(sim: RampageSim, dt: float) -> bool:
	if not active:
		return false
	sim.carving.warm(true)
	return _advance(sim, dt)


func _advance(sim: RampageSim, dt: float) -> bool:
	_t += dt
	if _t >= _cap:  # never stalls: out on the bank, on its feet
		sim.stand_y = 0.0
		_land(sim, sim.clamp_to_arena(_bank))
		return true
	if _t < _rise:
		var up := smoothstep(0.0, 1.0, _t / _rise)
		sim.stand_y = lerpf(-_depth * sim.body_scale(), -_bed, up)  # up to wading depth
		return true
	var bank := sim.clamp_to_arena(_bank)
	var stride := sim.stat("speed") * _wade * dt
	var floor_y := CityRiver.floor_at(_plan, _city, sim.kaiju_pos)
	sim.stand_y = move_toward(sim.stand_y, floor_y, stride)  # climbs the shore
	if sim.kaiju_pos.distance_to(bank) > stride or sim.stand_y < 0.0:
		sim.kaiju_pos = sim.kaiju_pos.move_toward(bank, stride)  # straight ahead: it never turns
		return true
	_land(sim, bank)
	return true


func _land(sim: RampageSim, bank: Vector2) -> void:
	sim.kaiju_pos = bank
	active = false
	sim.events.append({"type": "kaiju_emerged"})


## Where it rises: in the bay, its nose just short of the foot of the shore (so the whole body is
## in open water), on the line to the bank point; the plan's rise point without a shore.
func _rise_point(sim: RampageSim) -> Vector2:
	var sand := CityRiver.shore(_plan, _city)
	if not sand.has_area():
		return _spawn
	var nose := 0.0
	for d: Array in sim.body.discs():
		nose = maxf(nose, Num.f(d[0]) + Num.f(d[1]))
	if nose <= 0.0:
		return _spawn  # no body yet (a bare sim): the bay's middle
	var gap := Num.f(_city["river_bay"]["nose_gap"])
	return Vector2(_spawn.x, sand.end.y + nose * sim.body_scale() + gap)


## From the rise point to the bank point it wades to: into the city.
func _ahead() -> Vector2:
	return _spawn.direction_to(_bank) if _spawn != _bank else Vector2(0, -1)
