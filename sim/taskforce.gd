class_name Taskforce
extends RefCounted
## The Anti Kaiju Taskforce (D-137, D-139, D-141, D-143, D-145), agents only: squads of 3-4 jetpack
## in from the map edge, arriving faster the more of the city has fallen (about 12 alive at most,
## none in the young city), grapple and jet from roof to roof near the kaiju and perch. A perched
## agent aims a railgun: the aiming line tracks the kaiju, locks shortly before the shot, and the
## shot costs `railgun.share` of its max health if the kaiju still stands in the lock (a late
## step dodges it). It also launches frost grenades at the kaiju's feet (TaskforceFrost). An
## agent dies when the roof chunk it clings to goes (broken, dropped or toppled) or when a claw
## swipe swats it out of the air mid-hop; each kill pays biomass. Part of Army; pure and
## seeded from its own stream; numbers in data/tuning.json "taskforce". Presentation reads the
## agents and the events (taskforce_deployed, railgun_aim, railgun_locked, railgun_hit,
## railgun_missed, frost_launched, frost_hit, frost_cracked, agent_died).

const ARRIVE := 0  # jetpacking in from the map edge
const HOP := 1  # grappling and jetting to another roof
const PERCH := 2  # on a roof chunk: holds, throws, hops on
const AIM := 3  # on a roof chunk: the railgun's aiming line is up


class Agent:
	var id: int
	var squad: int
	var state := ARRIVE
	var pos := Vector2.ZERO  # on the ground plane (x, z)
	var y := 0.0  # its height above the ground
	var building := -1  # the roof it clings to (PERCH, AIM) or is flying to (ARRIVE, HOP)
	var cell := Vector3i.ZERO
	var from := Vector3.ZERO  # where this flight began and where it ends
	var to := Vector3.ZERO
	var flight := 0.0  # seconds left in this flight
	var flight_len := 1.0
	var wait := 0.0  # perched: seconds until it hops on
	var rail_cd := 0.0
	var frost_cd := 0.0
	var aim_left := 0.0
	var aim_at := Vector2.ZERO  # where the line points; locked once `locked`
	var locked := false


var sim: RampageSim
var cfg: Dictionary
var frost: TaskforceFrost
var agents: Array[Agent] = []
## Agents killed this run, and each squad's size as it arrived.
var kills := 0
var squad_sizes: Array[int] = []
var _rng: RandomNumberGenerator
var _timer: float
var _next_id := 0


func _init(p_sim: RampageSim, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = Content.section("taskforce").duplicate(true)  # a run (or a test) may edit its own copy
	_rng = rng
	_timer = Num.f(cfg["first_delay"])
	var frost_cfg: Dictionary = cfg["frost"]
	frost = TaskforceFrost.new(sim, frost_cfg)


## How many may be alive at once: none in the young city, the same from the adolescent city on.
func cap() -> int:
	var by_tier: Array = cfg["max_by_tier"]
	return Num.i(by_tier[clampi(sim.size_tier() - 1, 0, by_tier.size() - 1)])


## Seconds between squads: shorter the more of the city has fallen, never under min_interval.
func interval() -> float:
	var left := (
		Num.f(cfg["start_interval"]) - Num.f(cfg["escalation_per_chunk"]) * sim.chunks_destroyed
	)
	return maxf(Num.f(cfg["min_interval"]), left)


func step(dt: float) -> void:
	if cap() > 0 and sim.chunks_destroyed >= Num.i(cfg["after_chunks"]):
		_timer -= dt
		if _timer <= 0.0 and cap() - agents.size() >= _squad_min():
			_timer = interval()
			spawn_squad()
	frost.step(dt)
	var fallen: Array[Agent] = []
	for agent: Agent in agents:
		agent.rail_cd = maxf(0.0, agent.rail_cd - dt)
		agent.frost_cd = maxf(0.0, agent.frost_cd - dt)
		if agent.state == ARRIVE or agent.state == HOP:
			_fly(agent, dt)
		elif not _holds(agent):
			fallen.append(agent)
		elif agent.state == AIM:
			_aim(agent, dt)
		else:
			_perched(agent, dt)
	for agent: Agent in fallen:
		_kill(agent, "perch_collapse", {})


## A squad of 3-4 jetpacks in from a seeded point of the map edge, each bound for a roof near
## the kaiju (as many as fit under the cap). The first squad of a run raises taskforce_deployed.
func spawn_squad() -> void:
	var sizes: Array = cfg["squad_size"]
	var size := mini(_rng.randi_range(Num.i(sizes[0]), Num.i(sizes[1])), cap() - agents.size())
	var edge := _edge_point()
	var along := Vector2.from_angle(_rng.randf() * TAU).orthogonal() * Num.f(cfg["squad_spacing"])
	var squad := squad_sizes.size()
	squad_sizes.append(size)
	for n: int in size:
		var at := edge + along * (n - (size - 1) * 0.5)
		var agent := _new_agent(squad, at, Num.f(cfg["jet_height"]))
		_hop_to(agent, ARRIVE, Num.f(cfg["jet_speed"]))
	if squad == 0:
		sim.events.append({"type": "taskforce_deployed", "x": edge.x, "z": edge.y, "agents": size})


## An agent perched on chunk `cell` of building `building` (spawn and the tests' way to place one).
func place_agent(building: int, cell: Vector3i) -> Agent:
	var agent := _new_agent(squad_sizes.size(), Vector2.ZERO, 0.0)
	agent.state = PERCH
	agent.building = building
	agent.cell = cell
	var at := sim.buildings[building].chunk_world(cell)
	agent.pos = Vector2(at.x, at.z)
	agent.y = at.y + 0.5
	agent.wait = _perch_time()
	return agent


## A claw swipe (its `force` over ground points, up to height `top`) swats every agent in the
## air inside it: it spins off into the nearest wall and dies there.
func swat(force: Callable, top: float) -> void:
	var down: Array[Agent] = []
	for agent: Agent in agents:
		var flying := agent.state == ARRIVE or agent.state == HOP
		if flying and agent.y <= top and Num.f(force.call(agent.pos, _swat_radius())) > 0.0:
			down.append(agent)
	for agent: Agent in down:
		_kill(agent, "swatted", _wall(agent))


func _swat_radius() -> float:
	var swat_cfg: Dictionary = cfg["swat"]
	return Num.f(swat_cfg["radius"])


func _squad_min() -> int:
	var sizes: Array = cfg["squad_size"]
	return Num.i(sizes[0])


func _perch_time() -> float:
	var span: Array = cfg["perch_seconds"]
	return _rng.randf_range(Num.f(span[0]), Num.f(span[1]))


func _new_agent(squad: int, at: Vector2, height: float) -> Agent:
	var agent := Agent.new()
	agent.id = _next_id
	_next_id += 1
	agent.squad = squad
	agent.pos = at
	agent.y = height
	agent.rail_cd = Num.f(_rail()["cooldown"]) * 0.5
	agent.frost_cd = Num.f(frost.cfg["cooldown"]) * 0.5
	agents.append(agent)
	return agent


func _rail() -> Dictionary:
	var rail: Dictionary = cfg["railgun"]
	return rail


## A point on the square ring just outside the playable arena, at a seeded bearing.
func _edge_point() -> Vector2:
	var dir := Vector2.from_angle(_rng.randf() * TAU)
	var reach := sim.arena_half + Num.f(cfg["edge_inset"])
	return dir * reach / maxf(absf(dir.x), absf(dir.y))


## Starts a flight (state ARRIVE or HOP) to a roof near the kaiju at `speed` units a second; with
## no roof to go to the agent hovers where it is a second and looks again.
func _hop_to(agent: Agent, state: int, speed: float) -> void:
	agent.state = state
	agent.from = Vector3(agent.pos.x, agent.y, agent.pos.y)
	var spot := _pick_perch(agent)
	if spot.is_empty():
		agent.building = -1
		agent.to = agent.from
		agent.flight_len = 1.0
	else:
		agent.building = Num.i(spot[0])
		agent.cell = spot[1]
		var roof := sim.buildings[agent.building].chunk_world(agent.cell)
		agent.to = Vector3(roof.x, roof.y + 0.5, roof.z)
		agent.flight_len = maxf(0.2, agent.from.distance_to(agent.to) / speed)
	agent.flight = agent.flight_len


## A standing roof chunk in the perch band around the kaiju, on a building no other agent holds
## or is bound for: [building index, cell], or [] when there is none.
func _pick_perch(agent: Agent) -> Array:
	var options := _perch_options(agent)
	for _try: int in Num.i(cfg["perch_tries"]):
		if options.is_empty():
			break
		var i := options[_rng.randi_range(0, options.size() - 1)]
		var b := sim.buildings[i]
		var cell := Vector3i(
			_rng.randi_range(0, b.w - 1), b.height - 1, _rng.randi_range(0, b.d - 1)
		)
		if b.frame.alive(cell):
			return [i, cell]
	return []


## The buildings an agent may perch on: standing, tall enough, in the perch band round the kaiju,
## and not held or aimed at by another agent.
func _perch_options(agent: Agent) -> Array[int]:
	var span: Array = cfg["perch_range"]
	var taken := {}
	for other: Agent in agents:
		if other != agent and other.building >= 0:
			taken[other.building] = true
	var options: Array[int] = []
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if taken.has(i) or not b.in_arena or b.frame.alive_count == 0:
			continue
		var away := Vector2(b.x, b.z).distance_to(sim.kaiju_pos)
		if (
			b.height >= Num.i(cfg["perch_min_height"])
			and away >= Num.f(span[0])
			and away <= Num.f(span[1])
		):
			options.append(i)
	return options


## One step of a flight: along a straight line with an arc over it; on landing the agent perches
## if its roof chunk still stands, else looks for another.
func _fly(agent: Agent, dt: float) -> void:
	agent.flight -= dt
	var t := 1.0 - clampf(agent.flight / agent.flight_len, 0.0, 1.0)
	var at := agent.from.lerp(agent.to, t)
	var arc := Num.f(cfg["hop_arc"]) if agent.state == HOP else 0.0
	agent.pos = Vector2(at.x, at.z)
	agent.y = at.y + arc * sin(PI * t)
	if agent.flight > 0.0:
		return
	if agent.building >= 0 and sim.buildings[agent.building].frame.alive(agent.cell):
		agent.state = PERCH
		agent.pos = Vector2(agent.to.x, agent.to.z)
		agent.y = agent.to.y
		agent.wait = _perch_time()
	else:
		_hop_to(agent, HOP, Num.f(cfg["jet_speed"]))


## Whether the roof chunk the agent clings to still stands.
func _holds(agent: Agent) -> bool:
	return sim.buildings[agent.building].frame.alive(agent.cell)


## A perched agent: the railgun when it is ready and the kaiju in range, else a frost grenade,
## else (when it has held long enough) a hop to another roof.
func _perched(agent: Agent, dt: float) -> void:
	agent.wait -= dt
	var dist := agent.pos.distance_to(sim.kaiju_pos)
	if agent.rail_cd <= 0.0 and dist <= Num.f(_rail()["range"]):
		agent.state = AIM
		agent.aim_left = Num.f(_rail()["aim_seconds"])
		agent.aim_at = sim.kaiju_pos
		agent.locked = false
		sim.events.append({"type": "railgun_aim", "agent": agent.id, "from": _muzzle(agent)})
	elif agent.frost_cd <= 0.0 and frost.reaches(dist):
		agent.frost_cd = Num.f(frost.cfg["cooldown"])
		frost.launch(agent.id, _muzzle(agent))
	elif agent.wait <= 0.0:
		_hop_to(agent, HOP, Num.f(cfg["jet_speed"]) * Num.f(cfg["hop_speed_share"]))


## The railgun's line follows the kaiju until `lock_seconds` before the shot, then holds where it
## was: the shot lands there, on the kaiju only if it still stands in the lock.
func _aim(agent: Agent, dt: float) -> void:
	agent.aim_left -= dt
	if agent.aim_left > Num.f(_rail()["lock_seconds"]):
		agent.aim_at = sim.kaiju_pos
		return
	if not agent.locked:
		agent.locked = true
		sim.events.append(
			{"type": "railgun_locked", "agent": agent.id, "x": agent.aim_at.x, "z": agent.aim_at.y}
		)
	if agent.aim_left > 0.0:
		return
	_fire(agent)


func _fire(agent: Agent) -> void:
	var reach := Num.f(_rail()["hit_radius"])
	var shot := {"type": "railgun_hit", "agent": agent.id, "from": _muzzle(agent)}
	if sim.kaiju_pos.distance_to(agent.aim_at) <= reach:
		var damage := sim.max_hp * Num.f(_rail()["share"])
		sim.hp -= damage
		sim.events.append(
			shot.merged({"damage": damage, "x": sim.kaiju_pos.x, "z": sim.kaiju_pos.y})
		)
	else:
		sim.events.append(
			{"type": "railgun_missed", "agent": agent.id, "x": agent.aim_at.x, "z": agent.aim_at.y}
		)
	agent.state = PERCH
	agent.rail_cd = Num.f(_rail()["cooldown"])
	agent.wait = Num.f(_rail()["hop_after"])


func _muzzle(agent: Agent) -> Vector3:
	return Vector3(agent.pos.x, agent.y, agent.pos.y)


## Removes an agent (a collapsed perch, or swatted into a wall) and pays its biomass.
func _kill(agent: Agent, kind: String, extra: Dictionary) -> void:
	agents.erase(agent)
	kills += 1
	sim.rubble += Num.f(cfg["rubble"]) * sim.stat("rubble_mult")
	var death := {"type": "agent_died", "agent": agent.id, "kind": kind}
	sim.events.append(
		death.merged({"x": agent.pos.x, "y": agent.y, "z": agent.pos.y}).merged(extra)
	)


## Where a swatted agent hits: the nearest standing wall, as {"wall": building, "hit": Vector3}
## (empty when no building is within swat.wall_range).
func _wall(agent: Agent) -> Dictionary:
	var swat_cfg: Dictionary = cfg["swat"]
	var best := Num.f(swat_cfg["wall_range"])
	var found := {}
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if b.frame.alive_count == 0:
			continue
		var near := Vector2(
			clampf(agent.pos.x, b.x - b.w * 0.5, b.x + b.w * 0.5),
			clampf(agent.pos.y, b.z - b.d * 0.5, b.z + b.d * 0.5)
		)
		if near.distance_to(agent.pos) < best:
			best = near.distance_to(agent.pos)
			found = {"wall": i, "hit": Vector3(near.x, clampf(agent.y, 0.5, b.height), near.y)}
	return found
