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
## The holes (x, z) the rise breaks in the bay's decks (CityRiver.bay_bridges): over the body's
## footprint, grown by city "river_bay" "burst_margin", each the deck's full depth. Set by
## start(); the first rise step emits them as "deck_burst" (director 2026-10-21: "burst
## through": he rises up through the bridge deck and breaks it; the street grid stays whole).
var burst: Array[Rect2] = []
var _broke := false
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
	burst = _holes(sim)
	_broke = false


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
	if not _broke and not burst.is_empty():  # the first step: he breaks up through the deck
		_broke = true
		sim.events.append({"type": "deck_burst", "holes": burst})
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


## The body's footprint at the rise (its discs' bounds, grown by the burst margin) cut across
## each bay deck it covers, the deck's full depth (so no sliver of deck is left inside it).
func _holes(sim: RampageSim) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var s := sim.body_scale()
	var foot := Rect2()
	for d: Array in sim.body.discs():
		var c := sim.kaiju_pos + sim.facing * Num.f(d[0]) * s
		var r := Num.f(d[1]) * s
		var disc := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
		foot = disc if not foot.has_area() else foot.merge(disc)
	if not foot.has_area():
		return out
	var bay: Dictionary = _city.get("river_bay", {})
	foot = foot.grow(Num.f(bay.get("burst_margin", 0.0)))
	for deck: Rect2 in CityRiver.bay_bridges(_plan, _city):
		if deck.intersects(foot):
			var x0 := maxf(deck.position.x, foot.position.x)
			var x1 := minf(deck.end.x, foot.end.x)
			out.append(Rect2(x0, deck.position.y, x1 - x0, deck.size.y))
	return out


## From the rise point to the bank point it wades to: into the city.
func _ahead() -> Vector2:
	return _spawn.direction_to(_bank) if _spawn != _bank else Vector2(0, -1)
