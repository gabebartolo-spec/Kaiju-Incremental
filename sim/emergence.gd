class_name Emergence
extends RefCounted
## The start of a run (D-083, director 2026-10-19: "a city caught unaware - have our reptilian
## emerge from a river to start each run"): the kaiju waits submerged in the city's river
## (CityRiver) for "emerge" "hold_seconds" (the water ripples and founts over it), rises out of
## it over "rise_seconds", wades onto the city's bank (inside the arena) over "wade_seconds", and
## then the run begins: the sim emits "kaiju_emerged" (the army's alert ramp starts from it).
## Until then nothing else happens: no clock, no stomps, no army. The whole start fits the run
## intro's 3 s (director 2026-10-20 #11: "the entire scene should run for no longer than 3
## seconds"; R 20.1). Only a run the game starts (Rampage.setup) emerges; a RampageSim built on
## its own starts on land. The start never takes longer than "emerge" "max_seconds": past it the
## kaiju steps onto the bank point at once, so nothing (a bank point in the water, a wade that
## cannot finish) can stall a run before it begins.

var active := false
## The holes (x, z) the rise breaks in the bay's decks (CityRiver.bay_bridges): over the body's
## footprint, grown by city "river_bay" "burst_margin", each the deck's full depth. Set by
## start(); the first rise step emits them as "deck_burst" (director 2026-10-21: "burst
## through": he rises up through the bridge deck and breaks it; the street grid stays whole).
var burst: Array[Rect2] = []
var burst_ns: Array[Rect2] = []  # the same over the north-south decks (bay_bridges_ns)
## Whether its head has broken the water's surface yet (the "surface_break" event; the intro
## roars on it, R 20.3).
var surfaced := false
var _broke := false
var _t := 0.0
var _hold: float
var _rise: float
var _depth: float
var _wade: float
var _start_y := 0.0
var _cap: float
var _bed: float  # how far the river's water lies below the street (city "river_depth")
var _spawn: Vector2
var _bank: Vector2
var _plan: Dictionary  # the city's street plan (CityGen.map): its river, bay and shore
var _city: Dictionary


func _init(city: Dictionary, tuning: Dictionary) -> void:
	var cfg: Dictionary = tuning["emerge"]
	_hold = Num.f(cfg["hold_seconds"])
	_rise = Num.f(cfg["rise_seconds"])
	_depth = Num.f(cfg["depth"])
	_wade = Num.f(cfg["wade_seconds"])
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
	surfaced = false
	sim.kaiju_pos = _rise_point(sim)
	# Wholly under the water at first, its top "depth" (per body scale) below the surface, so the
	# water ripples and founts before anything shows (#11).
	_start_y = -_bed - sim.reach_height() - _depth * sim.body_scale()
	sim.stand_y = _start_y
	# It rises already facing the city, the way it will walk out (director 2026-10-21 #17: "have
	# him emerging facing the city so he can walk straight in"), in the river's bay, wide enough
	# for its whole body (director 2026-10-20: "emerging from the water, not from the asphalt").
	sim.facing = _ahead()
	sim.body.heading = sim.facing
	var foot := _footprint(sim)
	burst = _holes(foot, CityRiver.bay_bridges(_plan, _city), true)
	burst_ns = _holes(foot, CityRiver.bay_bridges_ns(_plan, _city), false)
	_broke = false


## How far through its rise the kaiju is, 0 (under, still holding) to 1 (wading in the river).
func risen() -> float:
	return clampf((_t - _hold) / _rise, 0.0, 1.0) if active else 1.0


## How far through the whole start (hold, rise and wade) it is, 0 to 1; 1 once it has emerged.
func progress() -> float:
	return clampf(_t / total(), 0.0, 1.0) if active else 1.0


## Seconds the whole start lasts when nothing stalls it.
func total() -> float:
	return _hold + _rise + _wade


## Seconds into the start the head breaks the surface (the intro's short cut starts near it).
func break_at(sim: RampageSim) -> float:
	var up := (-_bed - sim.reach_height() - _start_y) / maxf(0.001, -_bed - _start_y)
	# smoothstep's inverse, by bisection (the rise eases in and out)
	var lo := 0.0
	var hi := 1.0
	for _i: int in 20:
		var mid := (lo + hi) * 0.5
		if smoothstep(0.0, 1.0, mid) < up:
			lo = mid
		else:
			hi = mid
	return _hold + hi * _rise


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
	if _t < _hold:
		return true  # still under: the water ripples over it
	if _t < _hold + _rise:
		var up := smoothstep(0.0, 1.0, (_t - _hold) / _rise)
		sim.stand_y = lerpf(_start_y, -_bed, up)  # up to wading depth
		_surface(sim)
		return true
	_surface(sim)
	var bank := sim.clamp_to_arena(_bank)
	# The wade takes "wade_seconds" whatever the body's size, so the start's length never grows
	# with the stage (a Behemoth wades further, in proportion to its body).
	var left := maxf(1.0, roundf((total() - _t) / dt) + 1.0)
	var stride := sim.kaiju_pos.distance_to(bank) / left
	var floor_y := CityRiver.floor_at(_plan, _city, sim.kaiju_pos)
	var climb := maxf(stride, absf(floor_y - sim.stand_y) / left)
	sim.stand_y = move_toward(sim.stand_y, floor_y, climb)  # climbs the shore
	if sim.kaiju_pos.distance_to(bank) > stride or sim.stand_y < 0.0:
		sim.kaiju_pos = sim.kaiju_pos.move_toward(bank, stride)  # straight ahead: it never turns
		return true
	_land(sim, bank)
	return true


## The tick its top clears the water: "surface_break", and he breaks up through any deck over him
## (the deck's holes, "deck_burst").
func _surface(sim: RampageSim) -> void:
	if surfaced or sim.stand_y + sim.reach_height() < -_bed:
		return
	surfaced = true
	sim.events.append({"type": "surface_break"})
	if not _broke and not (burst.is_empty() and burst_ns.is_empty()):
		_broke = true
		sim.events.append({"type": "deck_burst", "holes": burst, "holes_ns": burst_ns})


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


## The body's footprint at the rise: its discs' bounds, grown by the burst margin.
func _footprint(sim: RampageSim) -> Rect2:
	var s := sim.body_scale()
	var foot := Rect2()
	for d: Array in sim.body.discs():
		var c := sim.kaiju_pos + sim.facing * Num.f(d[0]) * s
		var r := Num.f(d[1]) * s
		var disc := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
		foot = disc if not foot.has_area() else foot.merge(disc)
	if not foot.has_area():
		return foot
	var bay: Dictionary = _city.get("river_bay", {})
	return foot.grow(Num.f(bay.get("burst_margin", 0.0)))


## The footprint cut across each deck it covers, the deck's full width (so no sliver of deck is
## left inside it): across x for an east-west deck (along_x), across z for a north-south one.
func _holes(foot: Rect2, decks: Array[Rect2], along_x: bool) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not foot.has_area():
		return out
	for deck: Rect2 in decks:
		if not deck.intersects(foot):
			continue
		var cut := deck.intersection(foot)
		if along_x:
			out.append(Rect2(cut.position.x, deck.position.y, cut.size.x, deck.size.y))
		else:
			out.append(Rect2(deck.position.x, cut.position.y, deck.size.x, cut.size.y))
	return out


## From the rise point to the bank point it wades to: into the city.
func _ahead() -> Vector2:
	return _spawn.direction_to(_bank) if _spawn != _bank else Vector2(0, -1)
