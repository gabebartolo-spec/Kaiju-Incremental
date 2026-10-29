class_name Endless
extends RefCounted
## The demo's Endless mode (D-156): a separate mode, unlocked by the final upgrade, in which the
## city regrows slowly while the military escalates without end and no clock or fall ends the
## run; only the kaiju's defeat or End Rampage does. Its tunables are their own rows
## (data/tuning.json "demo.endless"): this class is only ever created for an endless run, so
## normal mode never reads them (the balance is decided by normal mode, DESIGN.md).

## Buildings regrown so far (the view and the tests read it).
var regrown := 0
var _timer: float
var _cursor := 0
var _owed := 0.0  # buildings earned back by the share-a-minute rule, not yet regrown


func _init() -> void:
	_timer = Num.f(cfg()["regrow_interval"])


static func cfg() -> Dictionary:
	return Content.section("demo")["endless"]


## Extra chunks' worth of escalation an endless `sim` has built up by its elapsed time: a share of
## the city's chunk total (start_share), growing by share_per_second of it, with no cap, so the
## army keeps worsening past the full ruin however big the city is. 0 in a normal run.
static func escalation(sim: RampageSim) -> int:
	if sim.endless == null:
		return 0
	var c := cfg()
	var share := Num.f(c["start_share"]) + Num.f(c["share_per_second"]) * sim.elapsed
	return floori(Num.f(sim.chunks_total) * share)


## True when the army may not field another tank (endless caps those alive at once; a toppled
## one is out of the fight and does not count, TankFlight).
static func tanks_full(sim: RampageSim) -> bool:
	if sim.endless == null:
		return false
	var fighting := sim.tanks.filter(func(t: RampageSim.Tank) -> bool: return not t.toppled)
	return fighting.size() >= Num.i(cfg()["max_tanks"])


## Why `sim` ends now, or "": endless ignores the clock and the city's fall.
static func over_reason(sim: RampageSim) -> String:
	if sim.endless == null and sim.chunks_destroyed >= sim.chunks_total:
		return "city_fallen"
	if sim.hp <= 0.0:
		return "defeated"
	return "time" if sim.endless == null and sim.time_left <= 0.0 else ""


## One step of an endless run (nothing in a normal one): the regrowth clock.
static func step(sim: RampageSim, dt: float) -> void:
	if sim.endless != null:
		sim.endless.regrow_step(sim, dt)


## Every regrow_interval seconds, regrow_share_per_minute of the flattened buildings come back
## (the fractions carry over), so there is always something new to wreck at any city size.
func regrow_step(sim: RampageSim, dt: float) -> void:
	_timer -= dt
	if _timer > 0.0:
		return
	var every := Num.f(cfg()["regrow_interval"])
	_timer = every
	_owed += (
		sim.collapse.destroyed_buildings() * Num.f(cfg()["regrow_share_per_minute"]) * every / 60.0
	)
	var left := floori(_owed)
	var n := sim.buildings.size()
	for k: int in n:
		var i := (_cursor + k) % n
		if left > 0 and regrowable(sim, i):
			regrow(sim, i)
			left -= 1
			_owed -= 1.0
			_cursor = i + 1


## True when building `i` is gone (every chunk, the sim's ruin rule), plain, in the arena, with
## nothing falling from it and the kaiju well clear.
func regrowable(sim: RampageSim, i: int) -> bool:
	var b := sim.buildings[i]
	if b.landmark != "" or not b.in_arena or b.frame.alive_count > 0:
		return false
	for f: RampageSim.Fall in sim.falls:
		if f.building == i:
			return false
	return Vector2(b.x, b.z).distance_to(sim.kaiju_pos) > Num.f(cfg()["regrow_clear"])


## Stands building `i` whole again: a fresh chunk structure, no fine grid, the destroyed count
## taken back, and no fire, pay or topple state left from its first life. The view rebuilds it on
## the "building_regrown" event.
func regrow(sim: RampageSim, i: int) -> void:
	var b := sim.buildings[i]
	var full := b.w * b.d * b.height
	b.frame = Structure.new(b.w, b.d, b.height, b.frame.max_hp)
	sim.carving.grids.erase(i)
	sim.carving.promoter.grids.erase(i)
	sim.chunks_destroyed = maxi(0, sim.chunks_destroyed - full)
	sim.powers.fire.reset_building(i)
	sim.collapse.forget_topple(i)
	regrown += 1
	sim.events.append({"type": "building_regrown", "building": i})
