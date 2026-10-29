class_name Emergence
extends RefCounted
## The start of a run (D-083, director 2026-10-19: "a city caught unaware"; 2026-10-26: "deploy
## the kaiju from the bay rather than the river", "Sea bay, real beach"): the kaiju waits
## submerged in the city's sea bay (CityHarbour) for "emerge" "hold_seconds" (the water ripples
## and founts over it), rises onto the sea floor over "rise_seconds", wades up the beach onto the
## promenade (inside the arena) over "wade_seconds", and
## then the run begins: the sim emits "kaiju_emerged" (the army's alert ramp starts from it).
## Until then nothing else happens: no clock, no stomps, no army. The whole start fits the run
## intro's 3 s (director 2026-10-20 #11: "the entire scene should run for no longer than 3
## seconds"; R 20.1). Only a run the game starts (Rampage.setup) emerges; a RampageSim built on
## its own starts on land. The start never takes longer than "emerge" "max_seconds": past it the
## kaiju steps onto the bank point at once, so nothing (a bank point in the water, a wade that
## cannot finish) can stall a run before it begins.
## A body with a keyed rise clip (D-270, D-199: the adult's "rise_bay"; Rampage passes its length)
## rises by the clip instead: it crouches on the sea floor from the first tick, nothing lifts it,
## the clip plays at its own speed and the head breaks the water "keyed_surface_seconds" in; the
## wade follows the clip (the start, and its cap, run longer by the clip's extra length).

var active := false
## Where it rose (x, z), once start() has placed it; the run intro's shot is set about it.
var rise_at := Vector2.ZERO
## Whether its head has broken the water's surface yet (the "surface_break" event; the intro
## roars on it, R 20.3).
var surfaced := false
## Whether this start rises by the body's keyed clip (start's `keyed`), not by lifting it.
var keyed_rise := false
var _t := 0.0
var _hold: float
var _rise: float
var _depth: float
var _wade: float
var _start_y := 0.0
var _wade_from := Vector2.INF  # where the wade began (the rise point), once it has
var _cap: float
var _sea: float  # the sea's surface (CityHarbour.sea)
var _spawn: Vector2
var _bank: Vector2
var _plan: Dictionary  # the city's street plan (CityGen.map): its sea bay and beach
var _city: Dictionary
var _cfg: Dictionary


func _init(city: Dictionary, tuning: Dictionary) -> void:
	_cfg = tuning["emerge"]
	_depth = Num.f(_cfg["depth"])
	_wade = Num.f(_cfg["wade_seconds"])
	_time(0.0)
	_sea = CityHarbour.sea(city)
	_city = city
	_plan = CityGen.map(city)
	_spawn = _plan.get("rise_spawn", Vector2(INF, INF))
	_bank = _plan.get("rise_bank", _spawn)


## Puts the kaiju under the sea bay's surface; the run waits until it has risen. A city without
## a bay starts on land at once. `keyed`: seconds of the body's keyed rise clip (0: none).
func start(sim: RampageSim, keyed := 0.0) -> void:
	if _spawn.x == INF:
		return
	_time(keyed)
	active = true
	_t = 0.0
	surfaced = false
	_wade_from = Vector2.INF
	sim.kaiju_pos = _rise_point(sim)
	rise_at = sim.kaiju_pos
	# Wholly under the water at first, its top "depth" (per body scale) below the surface, so the
	# water ripples and founts before anything shows (#11).
	_start_y = _sea - sim.reach_height() - _depth * sim.body_scale()
	if keyed_rise:  # crouched on the sea floor: the clip rises it (city "harbour" "crouch_back")
		_start_y = ground_at(rise_at)
	sim.stand_y = _start_y
	# It rises already facing the city, the way it will walk out (director 2026-10-21 #17: "have
	# him emerging facing the city so he can walk straight in"), in the bay, wide enough for its
	# whole body (director 2026-10-20: "emerging from the water, not from the asphalt").
	sim.facing = _ahead()
	sim.body.heading = sim.facing


## The start's timing: the data's, or a keyed rise of `keyed` seconds in place of its hold and rise.
func _time(keyed: float) -> void:
	keyed_rise = keyed > 0.0
	_hold = 0.0 if keyed_rise else Num.f(_cfg["hold_seconds"])
	_rise = keyed if keyed_rise else Num.f(_cfg["rise_seconds"])
	_cap = Num.f(_cfg["max_seconds"]) + late()


## Seconds a keyed rise adds to the data's hold and rise (0 without one; the intro's pull-out).
func late() -> float:
	return _hold + _rise - Num.f(_cfg["hold_seconds"]) - Num.f(_cfg["rise_seconds"])


## How far through its rise the kaiju is, 0 (under, still holding) to 1 (on the sea floor).
func risen() -> float:
	return clampf((_t - _hold) / _rise, 0.0, 1.0) if active else 1.0


## How far through the whole start (hold, rise and wade) it is, 0 to 1; 1 once it has emerged.
func progress() -> float:
	return clampf(_t / total(), 0.0, 1.0) if active else 1.0


## Seconds the whole start lasts when nothing stalls it.
func total() -> float:
	return _hold + _rise + _wade


## How high the ground stands at p (CityHarbour.floor_at: the street, the beach's slope, the sea
## floor); the run intro keeps its low camera over it.
func ground_at(p: Vector2) -> float:
	return CityHarbour.floor_at(_plan, _city, p)


## The sea's surface (world y) the kaiju rises through.
func water_y() -> float:
	return _sea


## Seconds into the start the head breaks the surface (the intro's short cut starts near it).
func break_at(sim: RampageSim) -> float:
	if keyed_rise:
		return Num.f(_cfg["keyed_surface_seconds"])
	var floor_y := ground_at(rise_at)
	var up := (_sea - sim.reach_height() - _start_y) / maxf(0.001, floor_y - _start_y)
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
		var up := 0.0 if keyed_rise else smoothstep(0.0, 1.0, (_t - _hold) / _rise)
		sim.stand_y = lerpf(_start_y, ground_at(rise_at), up)  # up onto the sea floor
		_surface(sim)
		return true
	_surface(sim)
	var bank := sim.clamp_to_arena(_bank)
	# The wade takes "wade_seconds" whatever the body's size, so the start's length never grows
	# with the stage (a Behemoth wades further, in proportion to its body). It eases in from the
	# rise and out onto the bank (smoothstep), so the body (and the camera on it) never jolts.
	if _wade_from.x == INF:
		_wade_from = sim.kaiju_pos
	var left := maxf(1.0, roundf((total() - _t) / dt) + 1.0)
	var u := clampf((_t - _hold - _rise) / maxf(0.001, _wade), 0.0, 1.0)
	var stride := sim.kaiju_pos.distance_to(_wade_from.lerp(bank, smoothstep(0.0, 1.0, u)))
	var floor_y := ground_at(sim.kaiju_pos)
	var climb := maxf(stride, absf(floor_y - sim.stand_y) / left)
	sim.stand_y = move_toward(sim.stand_y, floor_y, climb)  # climbs the beach
	if sim.kaiju_pos.distance_to(bank) > stride or sim.stand_y < 0.0:
		sim.kaiju_pos = sim.kaiju_pos.move_toward(bank, stride)  # straight ahead: it never turns
		return true
	_land(sim, bank)
	return true


## The tick its top clears the water: "surface_break" (the intro roars on it).
func _surface(sim: RampageSim) -> void:
	var top := sim.stand_y + sim.reach_height()
	var up := _t >= break_at(sim) if keyed_rise else top >= _sea
	if not surfaced and up:
		surfaced = true
		sim.events.append({"type": "surface_break"})


func _land(sim: RampageSim, bank: Vector2) -> void:
	sim.kaiju_pos = bank
	active = false
	sim.events.append({"type": "kaiju_emerged"})


## Where it rises: in the bay on its centre line, its nose city "harbour" "nose_gap" short of the
## foot of the beach (so the whole body is in open water over the sea floor); the plan's rise
## point for a bare sim with no body yet.
func _rise_point(sim: RampageSim) -> Vector2:
	var nose := 0.0
	for d: Array in sim.body.discs():
		nose = maxf(nose, Num.f(d[0]) + Num.f(d[1]))
	if nose <= 0.0 or not _plan.has("harbour"):
		return _spawn
	var h: Dictionary = _city["harbour"]
	var foot := Num.f(_plan["harbour"]["apex"]) - Num.f(h["beach"])
	return Vector2(_spawn.x, foot - nose * sim.body_scale() - Num.f(h["nose_gap"]))


## The body's footprint now: its discs' bounds, grown by city "harbour" "fit_margin" (tests: the
## rise stays clear of the railway).
func footprint(sim: RampageSim) -> Rect2:
	var s := sim.body_scale()
	var foot := Rect2()
	for d: Array in sim.body.discs():
		var c := sim.kaiju_pos + sim.facing * Num.f(d[0]) * s
		var r := Num.f(d[1]) * s
		var disc := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
		foot = disc if not foot.has_area() else foot.merge(disc)
	if not foot.has_area():
		return foot
	var bay: Dictionary = _city.get("harbour", {})
	return foot.grow(Num.f(bay.get("fit_margin", 0.0)))


## From the rise point to the bank point it wades to: into the city.
func _ahead() -> Vector2:
	return _spawn.direction_to(_bank) if _spawn != _bank else Vector2(0, -1)
