class_name Strikes
extends RefCounted
## Damage lands on impact (D-166, D-175): the reptilian's big attacks wreck when the jaws or the
## foot land, a beat after the press, not on it. The breath's cone is read at the strike (where he
## faces then); the Thunder Beam's stream starts at the strike (its walk slow from the press); a
## standing stomp lands `stomp_standing` seconds after its tick (on the foot RampageStomp chose), a
## walking one on its tick (the view syncs it to the footfall); the dash is instant. Cooldowns
## count from the press. A strike waits in `pending` until its time is up and lands nothing if
## the size tier changed meanwhile (he evolved); a rampage that ends stops stepping, so nothing
## lands either. Delays in data/tuning.json "strike". Part of RampageSim; pure, no randomness.

const BREATH := "breath"
const BEAM := "beam"
const STOMP := "stomp"

var sim: RampageSim
var cfg: Dictionary
## Strikes still to land: {"kind", "left": seconds, "tier": the size tier at the press}.
var pending: Array[Dictionary] = []


func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
	sim = p_sim
	cfg = p_cfg


## Seconds from the breath's press to its strike at this size tier (young, Behemoth, Colossus).
func breath_delay() -> float:
	var by_tier: Array = cfg["breath"]
	return Num.f(by_tier[clampi(sim.size_tier() - 1, 0, by_tier.size() - 1)])


## Seconds from the Thunder Beam's press to its stream.
func beam_delay() -> float:
	return Num.f(cfg["beam"])


## The breath is pressed: the cone burns at the strike.
func breath() -> void:
	_begin(BREATH, breath_delay())


## The Thunder Beam is pressed: the stream starts at the strike.
func beam() -> void:
	_begin(BEAM, beam_delay())


## Seconds from a stomp's tick to its damage: the reptilian's standing stomp lifts and plants a
## foot (`stomp_standing`); a walking stomp, and every other body's, lands on its tick.
func stomp_delay(on_foot: bool) -> float:
	if on_foot or sim.ability_type != "cone":
		return 0.0
	return Num.f(cfg["stomp_standing"])


## A stomp's foot comes down on `centre` after `wait` seconds (at once when 0).
func stomp(centre: Vector2, wait: float) -> void:
	_begin(STOMP, wait, centre)


## Whether a strike of this kind is still to land.
func winding(kind: String) -> bool:
	for strike: Dictionary in pending:
		if strike["kind"] == kind:
			return true
	return false


## Counts the waiting strikes down and lands the ones that are due, in the order they were pressed.
func step(dt: float) -> void:
	var due: Array[Dictionary] = []
	for strike: Dictionary in pending:
		strike["left"] = Num.f(strike["left"]) - dt
		if Num.f(strike["left"]) <= 0.0:
			due.append(strike)
	for strike: Dictionary in due:
		pending.erase(strike)
		if Num.i(strike["tier"]) == sim.size_tier():
			var centre: Vector2 = strike.get("centre", Vector2.ZERO)
			_land(str(strike["kind"]), centre)


func _begin(kind: String, wait: float, centre := Vector2.ZERO) -> void:
	if wait <= 0.0:
		_land(kind, centre)
		return
	pending.append({"kind": kind, "left": wait, "tier": sim.size_tier(), "centre": centre})
	if kind != STOMP:  # the stomp event itself carries its time
		sim.events.append({"type": "strike_windup", "kind": kind, "strike_in": wait})


func _land(kind: String, centre: Vector2) -> void:
	match kind:
		BREATH:
			BreathCone.breathe(sim, sim.ability_reach(), sim.stat("ability_damage"))
		BEAM:
			sim.powers.start_beam()
		STOMP:
			_land_stomp(centre)


## The foot comes down: full force within the stomp radius, fading to nothing at twice it.
func _land_stomp(centre: Vector2) -> void:
	if sim.airborne:
		return
	var radius := sim.stomp_radius()
	sim.hit_area(
		func(p: Vector2, r: float) -> float:
			return RampageSim.falloff(p.distance_to(centre) - r, radius),
		sim.stat("stomp_damage") * sim.powers.hit_mult(),
		maxi(0, floori(sim.stand_y) - Num.i(sim.powers_cfg["climb_dig"])),
		ceili(sim.reach_top())
	)
