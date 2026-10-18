class_name StrikeWing
extends RefCounted
## Military jets (D-072): once enough of the city has fallen, a jet makes a fast straight pass
## across the arena at where the kaiju stood when it was called in, then flies on and out;
## another follows after `interval`, the kinds taking turns in the stage's `order`. Passes run
## across the game camera's view (at right angles to `camera_bearing`, give or take
## `yaw_jitter`), so a pass is seen edge to edge and never flies at the lens; a jet flies
## `clearance` over the kaiju's head. Each kind (`kinds`, over the shared keys) strafes a line of
## `rounds`, drops `bombs` that fall `drop_seconds` and blast `bomb_radius`, or both.
## `warn_seconds` before the first round or bomb lands the sim says where (jet_inbound): a kaiju
## that gets out of the way takes nothing. Rounds and blasts also wreck the roofs they hit:
## collateral that falls like any other but pays the player no biomass (director, D-072). Only an
## attack that reaches the air (or a cephalopod's grab) downs a jet; unlike the helicopters
## (AirWing) a jet never circles. Part of RampageSim. Pure and seeded.


class Jet:
	var id: int
	var kind: String
	var cfg: Dictionary  # the shared keys with its kind's on top
	var start: Vector2  # where it enters, `approach` short of the pass's centre
	var dir: Vector2  # its heading on the ground plane
	var s := 0.0  # distance flown from start
	var pos: Vector2
	var hp: float
	var next_round := 0  # the next point of the strafing line to land
	var next_bomb := 0  # the next bomb to release
	var warned := false


class Bomb:
	var jet: int
	var at: Vector2
	var t: float  # seconds until it lands


var sim: RampageSim
var cfg: Dictionary
var jets: Array[Jet] = []
var bombs: Array[Bomb] = []
var destroyed := 0
var _rng: RandomNumberGenerator
var _spawn_timer := 0.0
var _next_id := 0
var _next_kind := 0
var _side := 1.0


## `tuning` is the rampage's tuning; the jets read its "jets" section.
func _init(p_sim: RampageSim, tuning: Dictionary, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = tuning["jets"]
	_rng = rng
	_spawn_timer = Num.f(cfg["first_delay"])


## Its flying height: `clearance` over the kaiju's head, so it never flies through a grown body.
func altitude() -> float:
	return Num.f(cfg["clearance"]) + sim.reach_height()


## How many may be in the air at once: more the more of the city has fallen.
func cap() -> int:
	var after := Num.i(cfg["after_chunks"])
	if sim.chunks_destroyed < after:
		return 0
	var extra := (sim.chunks_destroyed - after) / maxi(1, Num.i(cfg["max_per_chunks"]))
	return mini(Num.i(cfg["max"]), 1 + extra)


func step(dt: float) -> void:
	if jets.size() < cap():
		_spawn_timer -= dt
		if _spawn_timer <= 0.0:
			_spawn_timer = Num.f(cfg["interval"])
			spawn()
	var gone: Array[Jet] = []
	for jet: Jet in jets:
		jet.s += Num.f(jet.cfg["speed"]) * dt
		jet.pos = jet.start + jet.dir * jet.s
		_warn(jet)
		_strafe(jet)
		_release(jet)
		if jet.s >= 2.0 * Num.f(cfg["approach"]):
			gone.append(jet)
	for jet: Jet in gone:
		jets.erase(jet)
		sim.events.append({"type": "jet_left", "jet": jet.id})
	_fall(dt)


## A new jet lines up on the kaiju: the next kind in `order`, entering `approach` short of the
## kaiju's spot (off screen) from alternate sides, heading across the camera's view.
func spawn() -> Jet:
	var jet := Jet.new()
	jet.id = _next_id
	_next_id += 1
	var order: Array = cfg["order"]
	jet.kind = str(order[_next_kind % order.size()])
	_next_kind += 1
	var kinds: Dictionary = cfg["kinds"]
	var own: Dictionary = kinds[jet.kind]
	jet.cfg = cfg.merged(own, true)
	var across := Vector2.from_angle(deg_to_rad(Num.f(cfg["camera_bearing"]))).orthogonal()
	var jitter := deg_to_rad(Num.f(cfg["yaw_jitter"]))
	jet.dir = (across * _side).rotated(_rng.randf_range(-jitter, jitter))
	_side = -_side
	var centre := sim.kaiju_pos - _toward_camera() * Num.f(cfg["lane_behind"])
	jet.start = centre - jet.dir * Num.f(cfg["approach"])
	jet.pos = jet.start
	jet.hp = Num.f(cfg["hp"]) * Num.f(jet.cfg["hp_mult"])
	jets.append(jet)
	sim.events.append(
		{"type": "jet_spawned", "jet": jet.id, "kind": jet.kind, "from": jet.start, "dir": jet.dir}
	)
	return jet


## The ground points its rounds land on, in order: `rounds` of them, `strafe_step` apart,
## centred on the point it lined up on.
func line(jet: Jet) -> PackedVector2Array:
	return _spread(jet, Num.i(jet.cfg["rounds"]), Num.f(jet.cfg["strafe_step"]))


## Where its bombs land, in order: `bombs` of them, `bomb_step` apart, centred the same way.
func targets(jet: Jet) -> PackedVector2Array:
	return _spread(jet, Num.i(jet.cfg["bombs"]), Num.f(jet.cfg["bomb_step"]))


func _spread(jet: Jet, count: int, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var first := Num.f(cfg["approach"]) - step * (count - 1) * 0.5
	for k: int in count:
		out.append(jet.start + jet.dir * (first + step * k))
	return out


## `warn_seconds` before its first round or bomb lands: where they all will.
func _warn(jet: Jet) -> void:
	if jet.warned:
		return
	var rounds := line(jet)
	var drops := targets(jet)
	var first := INF  # how far along it will have flown when the first lands
	if not rounds.is_empty():
		first = jet.start.distance_to(rounds[0]) - Num.f(jet.cfg["strafe_lead"])
	if not drops.is_empty():
		first = minf(first, jet.start.distance_to(drops[0]))
	if jet.s < first - Num.f(jet.cfg["speed"]) * Num.f(cfg["warn_seconds"]):
		return
	jet.warned = true
	sim.events.append(
		{
			"type": "jet_inbound",
			"jet": jet.id,
			"rounds": rounds,
			"bombs": drops,
			"radius": Num.f(jet.cfg["bomb_radius"]),
		}
	)


## Its guns hit `strafe_lead` ahead of it: each line point lands as that spot reaches it.
func _strafe(jet: Jet) -> void:
	var points := line(jet)
	var gun := jet.s + Num.f(jet.cfg["strafe_lead"])
	while jet.next_round < points.size():
		var at := points[jet.next_round]
		if gun < jet.start.distance_to(at):
			break
		jet.next_round += 1
		var hit := at.distance_to(sim.kaiju_pos) <= _body()
		if hit:
			_hurt(Num.f(jet.cfg["damage"]))
		_wreck(at, Num.f(cfg["round_radius"]), Num.f(cfg["round_damage"]), 1)
		sim.events.append({"type": "jet_strafe", "jet": jet.id, "at": at, "hit": hit})


## A bomb leaves `drop_seconds` of flight before its target, thrown forward, so it lands on it.
func _release(jet: Jet) -> void:
	var drops := targets(jet)
	var lead := Num.f(jet.cfg["speed"]) * Num.f(jet.cfg["drop_seconds"])
	while jet.next_bomb < drops.size():
		var at := drops[jet.next_bomb]
		var land := jet.start.distance_to(at)
		if jet.s < land - lead:
			break
		jet.next_bomb += 1
		var bomb := Bomb.new()
		bomb.jet = jet.id
		bomb.at = at
		bomb.t = (land - jet.s) / Num.f(jet.cfg["speed"])
		bombs.append(bomb)
		sim.events.append(
			{"type": "jet_bomb_drop", "jet": jet.id, "from": jet.pos, "at": at, "seconds": bomb.t}
		)


## Falling bombs land: a blast that hurts the kaiju if it reaches the body, and wrecks roofs.
func _fall(dt: float) -> void:
	var landed: Array[Bomb] = []
	for bomb: Bomb in bombs:
		bomb.t -= dt
		if bomb.t <= 0.0:
			landed.append(bomb)
	var radius := Num.f(cfg["bomb_radius"])
	for bomb: Bomb in landed:
		bombs.erase(bomb)
		var hit := bomb.at.distance_to(sim.kaiju_pos) <= radius + _body()
		if hit:
			_hurt(Num.f(cfg["bomb_damage"]))
		_wreck(bomb.at, radius, Num.f(cfg["bomb_chunk_damage"]), Num.i(cfg["bomb_floors"]))
		sim.events.append(
			{"type": "jet_bomb", "jet": bomb.jet, "at": bomb.at, "radius": radius, "hit": hit}
		)


func _body() -> float:
	return Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale()


## The kaiju takes `damage` less its armour, at least the army's minimum, as from a tank shell.
func _hurt(damage: float) -> void:
	sim.hp -= maxf(Num.f(sim.army["min_damage"]), damage - sim.stat("armor"))


## Collateral: the top `floors` standing chunks of each column within `radius` of `at` take
## `damage`; broken ones fall like any other, but the biomass they would pay is taken back.
func _wreck(at: Vector2, radius: float, damage: float, floors: int) -> void:
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		var reach := Vector2(b.w, b.d).length() * 0.5 + radius
		if b.frame.alive_count == 0 or Vector2(b.x, b.z).distance_to(at) > reach:
			continue
		var cells: Array[Vector3i] = []
		for x: int in b.w:
			for z: int in b.d:
				var p := b.chunk_world(Vector3i(x, 0, z))
				if Vector2(p.x, p.z).distance_to(at) <= radius:
					cells.append_array(_top(b, x, z, floors))
		if not cells.is_empty():
			var kept := sim.rubble
			sim.damage_chunks(i, cells, damage)
			sim.rubble = kept


## The top `floors` standing chunks of column (x, z), highest first.
func _top(b: RampageSim.Building, x: int, z: int, floors: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for y: int in range(b.height - 1, -1, -1):
		if out.size() >= floors:
			break
		if b.frame.alive(Vector3i(x, y, z)):
			out.append(Vector3i(x, y, z))
	return out


## The direction from the kaiju toward the game camera, on the ground plane.
func _toward_camera() -> Vector2:
	return Vector2.from_angle(deg_to_rad(Num.f(cfg["camera_bearing"])))


## An attack's force reaches jets only when reaches_air (else they fly too high and fast).
func hit(force: Callable, damage: float, reaches_air: bool) -> void:
	if not reaches_air or jets.is_empty():
		return
	for jet: Jet in jets:
		jet.hp -= damage * Num.f(force.call(jet.pos, Num.f(cfg["jet_radius"])))
	clear_dead()


## Downed jets (hp 0: shot, or seized by a tentacle) pay rubble and leave the sky.
func clear_dead() -> void:
	var alive: Array[Jet] = []
	for jet: Jet in jets:
		if jet.hp > 0.0:
			alive.append(jet)
			continue
		destroyed += 1
		sim.rubble += Num.f(cfg["rubble"]) * sim.stat("rubble_mult")
		sim.events.append({"type": "jet_destroyed", "jet": jet.id, "x": jet.pos.x, "z": jet.pos.y})
	jets = alive
