class_name VipHeli
extends RefCounted
## The leader's escape helicopter (D-149): once a rampage, at a seeded moment, the city's leader
## (Mayor, Governor or President by city) lifts off a mid-rise roof and flees. It climbs while it
## flies one smooth lap round the pad (a banked circle at its own speed, never pinned to the
## kaiju, D-183), then runs straight for the map edge so that the whole flight takes about
## `window_seconds`. Bringing it down pays `payout` (about a city block's worth, Tuning "vip");
## letting it reach the edge costs only that payout.
## How it dies: any area attack that reaches its height (the breath, the Thunder Beam, ink and limbs
## reach the sky; a stomp or claw only while it is still low over the roofs), a toppling tower
## sweeping its height, a tank or car in flight (thrown), or a grab while it is low (a tentacle).
## It falls like any gunship (AirWing's fates and wreck), under its own id. Own file and own
## seeded stream, so it never shifts the army's or the air wing's draws. Part of RampageSim.

## Its id among the sky's helicopters: far above AirWing's own counter.
const ID := 1000000
const NO_TARGET := Vector2(INF, INF)

var sim: RampageSim
var cfg: Dictionary
## "waiting" (before lift-off), "flying", "killed", "escaped" or "none" (no roof to lift off).
var state := "waiting"
var pos := Vector2.ZERO
var heading := 0.0
var speed := 0.0
## Radians a second it is turning now: the view banks on it.
var turn_rate := 0.0
var flight_t := 0.0
var rank := ""
## What a kill pays (before the kaiju's rubble multiplier), and what it paid.
var payout := 0.0
var paid := 0.0
var _rng: RandomNumberGenerator
var _fall_rng: RandomNumberGenerator  # its own fall draws: a kill never shifts the air wing's
var _hp := 0.0
var _spawn_at := 0.0
var _roof := 0.0
var _turned := 0.0
var _exit := NO_TARGET
var _dash_speed := 0.0
var _last_blow := 0.0
var _coat_t := 0.0
var _coat_dps := 0.0


func _init(p_sim: RampageSim, p_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = p_cfg
	_rng = rng
	_fall_rng = Seeds.derive(rng, 0x71C)
	var window: Array = cfg["window"]
	_spawn_at = lerpf(Num.f(window[0]), Num.f(window[1]), _rng.randf()) * sim.stat("run_seconds")
	var ranks: Array = cfg["ranks"]
	var payouts: Array = cfg["payout"]
	var tier := clampi(sim.size_tier() - 1, 0, ranks.size() - 1)
	rank = str(ranks[tier])
	payout = Num.f(payouts[tier])


## Is it in the air now (the one thing the view and the other powers ask)?
func flying() -> bool:
	return state == "flying"


## Its height: off the pad's roof at lift-off, climbing to its cruise over `climb_seconds`.
func altitude() -> float:
	var up := smoothstep(0.0, 1.0, flight_t / maxf(0.1, Num.f(cfg["climb_seconds"])))
	return lerpf(_roof, Num.f(cfg["altitude"]), up)


## What the result screen and the news read.
func summary() -> Dictionary:
	return {
		"vip_killed": 1 if state == "killed" else 0,
		"vip_escaped": 1 if state == "escaped" else 0,
		"vip_paid": paid
	}


func step(dt: float) -> void:
	if state == "waiting":
		if sim.elapsed >= _spawn_at:
			_lift_off()
		return
	if state != "flying":
		return
	flight_t += dt
	_swept_by_falls()
	_hit_by_thrown()
	_burn(dt)
	if state == "flying":
		_fly(dt)


## An area attack: reaches it when it fires into the sky (hit_air) or the kaiju stands as high.
func hit(force: Callable, damage: float) -> void:
	if state != "flying" or sim.air._crashing:  # a gunship wreck's impact never reaches the sky
		return
	if not (sim.hit_air or sim.reach_top() >= altitude()):
		return
	var k: float = force.call(pos, Num.f(cfg["radius"]))
	if k <= 0.0:
		return
	_hp -= damage * k
	_last_blow = damage * k
	if not sim.hit_coat.is_empty():
		_coat_t = Num.f(sim.hit_coat["seconds"])
		_coat_dps = Num.f(sim.hit_coat["dps"]) * Num.f(sim.powers_cfg["ink_unit_mult"])
	if _hp <= 0.0:
		down(false, "blow")


## Where a tentacle can seize it (within `reach` of the kaiju and low enough to touch), or none.
func grab_pos(reach: float) -> Vector2:
	if state != "flying" or altitude() > sim.reach_top():
		return NO_TARGET
	return pos if pos.distance_to(sim.kaiju_pos) <= reach else NO_TARGET


## It is down: pays the kill, then falls as AirWing's fates say ("grabbed" only leaves the sky).
func down(grabbed: bool, by: String) -> void:
	state = "killed"
	paid = payout * sim.stat("rubble_mult")
	sim.rubble += paid
	var air: Dictionary = sim.air.cfg
	var heli := AirWing.Heli.new()
	heli.id = ID
	heli.pos = pos
	var event := {"type": "vip_down", "heli": ID, "x": pos.x, "z": pos.y, "y": altitude()}
	if grabbed:
		event["fate"] = "grabbed"
	elif _last_blow >= Num.f(air["hp"]) * Num.f(cfg["hp_mult"]) * Num.f(air["blow_apart"]):
		event["fate"] = "burst"
	else:
		event.merge(sim.air._spin_down(heli, _fall_rng))
	sim.events.append(event)
	sim.events.append({"type": "vip_killed", "rank": rank, "payout": paid, "by": by})


func _lift_off() -> void:
	var pad := _pick_pad()
	if pad < 0:
		state = "none"
		return
	var b := sim.buildings[pad]
	_roof = minf(float(b.height), Num.f(cfg["altitude"]) - 1.0)
	pos = Vector2(b.x, b.z)
	heading = _rng.randf() * TAU
	_hp = Num.f(sim.air.cfg["hp"]) * Num.f(cfg["hp_mult"])
	state = "flying"
	sim.events.append({"type": "vip_spawned", "heli": ID, "rank": rank, "x": pos.x, "z": pos.y})


## A seeded standing mid-rise in the arena, near enough to chase; any such roof when none is near.
func _pick_pad() -> int:
	var heights: Array = cfg["pad_height"]
	var range_m: Array = cfg["pad_range"]
	var near: Array[int] = []
	var any: Array[int] = []
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		var tall := b.height >= Num.i(heights[0]) and b.height <= Num.i(heights[1])
		if not (tall and b.in_arena and _standing(i)):
			continue
		any.append(i)
		var gap := Vector2(b.x, b.z).distance_to(sim.kaiju_pos)
		if gap >= Num.f(range_m[0]) and gap <= Num.f(range_m[1]):
			near.append(i)
	var pool := near if not near.is_empty() else any
	return -1 if pool.is_empty() else pool[_rng.randi() % pool.size()]


## Does building `i` still stand? A building the kaiju has been near is promoted to the fine
## destruction grid (Carving), and its coarse frame then reads empty: ask the grid.
func _standing(i: int) -> bool:
	var grid := sim.carving.frame(i)
	return (grid.alive_count if grid != null else sim.buildings[i].frame.alive_count) > 0


## A tower toppling this step that reaches its height sweeps its landing strip: it goes down.
func _swept_by_falls() -> void:
	for event: Dictionary in sim.events:
		if str(event["type"]) != "fall_start" or not event.has("to"):
			continue
		var pivot: Vector3 = event["pivot"]
		var start := Vector2(pivot.x, pivot.z)
		var end: Vector2 = event["to"]
		var span := end - start
		if span.length() + pivot.y < altitude():
			continue
		var half := Num.f(event["width"]) * 0.5 + Num.f(cfg["radius"])
		var t := clampf((pos - start).dot(span) / maxf(0.001, span.length_squared()), 0.0, 1.0)
		if pos.distance_to(start + span * t) <= half:
			_last_blow = 0.0  # knocked aside, never blown apart
			down(false, "topple")
			return


## A tank or car a tentacle has thrown that flies through it while it is low enough: it goes down.
func _hit_by_thrown() -> void:
	if altitude() > Num.f(cfg["throw_ceiling"]):
		return
	for throw: Tentacles.Thrown in sim.powers.tentacles.thrown:
		var at := throw.from.lerp(throw.to, clampf(throw.t / throw.duration, 0.0, 1.0))
		if at.distance_to(pos) <= Num.f(cfg["throw_pass"]):
			_last_blow = Num.f(sim.air.cfg["hp"])  # a thrown tank blows it apart
			down(false, "thrown")
			return


## A burning or ink coat keeps eating it after the blow.
func _burn(dt: float) -> void:
	if _coat_t <= 0.0:
		return
	_coat_t -= dt
	_hp -= _coat_dps * dt
	_last_blow = _coat_dps * dt  # a coat kill is a light blow: it spins down
	if _hp <= 0.0:
		down(false, "burn")


## One step of the flight: the banked lap round the pad, then the dash to the edge.
func _fly(dt: float) -> void:
	var radius := Num.f(cfg["circle_radius"]) * sim.body_scale()
	var lap_speed := TAU * radius / Num.f(cfg["circle_seconds"])
	if _turned < TAU:
		speed = lap_speed * minf(1.0, flight_t / Num.f(cfg["liftoff_seconds"]))
		turn_rate = speed / radius
		heading += turn_rate * dt
		_turned += turn_rate * dt
		if _turned >= TAU:
			_begin_dash(lap_speed)
	else:
		_dash(dt)
	pos += Vector2.from_angle(heading) * speed * dt
	var limit := sim.arena_half + Num.f(cfg["exit_margin"])
	if (
		absf(pos.x) >= limit
		or absf(pos.y) >= limit
		or flight_t >= Num.f(cfg["window_seconds"]) * Num.f(cfg["escape_cap"])
	):
		state = "escaped"
		sim.events.append({"type": "vip_escaped", "heli": ID, "rank": rank, "payout": payout})


## Picks the edge point it runs to, away from the kaiju, and the speed that makes the whole
## flight last `window_seconds`.
func _begin_dash(lap_speed: float) -> void:
	var away := (pos - sim.kaiju_pos).angle()
	var spread := deg_to_rad(Num.f(cfg["exit_spread_deg"]))
	var dir := Vector2.from_angle(away + _rng.randf_range(-spread, spread))
	var limit := sim.arena_half + Num.f(cfg["exit_margin"])
	var reach := INF
	for axis: int in 2:
		if absf(dir[axis]) > 0.001:
			reach = minf(reach, (limit * signf(dir[axis]) - pos[axis]) / dir[axis])
	_exit = pos + dir * reach
	var left := maxf(1.0, Num.f(cfg["window_seconds"]) - flight_t)
	_dash_speed = maxf(lap_speed, pos.distance_to(_exit) / left)


## Straight for the edge: turning no faster than `turn_limit` rad/s, gathering speed to its dash.
func _dash(dt: float) -> void:
	var want := (_exit - pos).angle()
	var limit := Num.f(cfg["turn_limit"]) * dt
	var turn := clampf(angle_difference(heading, want), -limit, limit)
	heading += turn
	turn_rate = turn / maxf(0.001, dt)
	speed = move_toward(speed, _dash_speed, Num.f(cfg["accel"]) * dt)
