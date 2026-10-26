class_name Explosives
extends RefCounted
## The city's red barrels going off (director comments #19). Any damage to a hazard site
## (CityHazards: the kaiju, its breath, falling rubble, an army shell, another blast) arms it:
## damage_cells and hit_area report it, and a site that lost a chunk any other way (Carving,
## Collapse) is caught each step. After a short fuse it explodes through RampageSim.hit_area, so
## the blast breaks buildings, tanks and rooftop squads in its radius and arms the sites it
## reaches (a chain, on the shorter chain fuse). Kinds (tuning "explosives"): a fuel silo is one
## big blast; a fireworks factory throws seeded bursts around that set what they hit burning; a
## chem lab leaves a toxic cloud that hurts tanks and squads inside it over time. Pure and seeded.

const IDLE := 0
const ARMED := 1
const BLOWN := 2


class Site:
	var building: int
	var kind: String
	var pos: Vector2
	var state := IDLE
	var fuse := 0.0
	var alive_at_start := 0


var sites: Array[Site] = []
var cfg: Dictionary
## Fireworks still to burst: {"t", "pos": Vector2}. Toxic clouds: {"t", "pos", "exposure": {}}.
var bursts: Array[Dictionary] = []
var clouds: Array[Dictionary] = []
var _sim: RampageSim
var _rng: RandomNumberGenerator
var _of := {}  # building index -> Site


func _init(sim: RampageSim, tuning: Dictionary, rng: RandomNumberGenerator) -> void:
	_sim = sim
	_rng = rng
	cfg = tuning.get("explosives", {})
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		if b.hazard == "" or cfg.is_empty():
			continue
		var s := Site.new()
		s.building = i
		s.kind = b.hazard
		s.pos = Vector2(b.x, b.z)
		s.alive_at_start = b.frame.alive_count
		sites.append(s)
		_of[i] = s


## Building `index` took damage: a hazard there lights its fuse.
func damaged(index: int, chained := false) -> void:
	var s: Site = _of.get(index, null)
	if s == null or s.state != IDLE:
		return
	s.state = ARMED
	s.fuse = Num.f(cfg["chain_fuse_s" if chained else "fuse_s"])
	_sim.events.append({"type": "hazard_armed", "kind": s.kind, "building": index, "fuse": s.fuse})


func step(dt: float) -> void:
	for s: Site in sites:
		if s.state == IDLE and _hurt(s):
			damaged(s.building)
		elif s.state == ARMED:
			s.fuse -= dt
			if s.fuse <= 0.0:
				_blow(s)
	_step_bursts(dt)
	_step_clouds(dt)


func _hurt(s: Site) -> bool:
	return (
		_sim.buildings[s.building].frame.alive_count < s.alive_at_start
		or _sim.carving.promoted(s.building)
	)


func _blow(s: Site) -> void:
	s.state = BLOWN
	var k: Dictionary = cfg[s.kind]
	var radius := Num.f(k["radius"])
	var at := {"kind": s.kind, "building": s.building, "x": s.pos.x, "z": s.pos.y}
	_sim.events.append(at.merged({"type": "explosion", "radius": radius}))
	_blast(s.pos, radius, Num.f(k["damage"]), Num.i(k["height"]))
	if s.kind == "fireworks_factory":
		for n: int in Num.i(k["bursts"]):
			var off := (
				Vector2.from_angle(_rng.randf() * TAU) * _rng.randf() * Num.f(k["burst_spread"])
			)
			bursts.append({"t": (n + 1) * Num.f(k["burst_every_s"]), "pos": s.pos + off})
	elif s.kind == "chem_lab":
		clouds.append({"t": Num.f(k["cloud_seconds"]), "pos": s.pos, "exposure": {}})
		(
			_sim
			. events
			. append(
				{
					"type": "toxic_cloud",
					"building": s.building,
					"x": s.pos.x,
					"z": s.pos.y,
					"radius": Num.f(k["cloud_radius"]),
					"seconds": Num.f(k["cloud_seconds"]),
				}
			)
		)


## One blast: full force within `radius`, fading to nothing at twice it (RampageSim.falloff).
## Sites it reaches are armed on the chain fuse before hit_area's own report can arm them.
func _blast(at: Vector2, radius: float, damage: float, height: int) -> void:
	var force := func(p: Vector2, r: float) -> float:
		return RampageSim.falloff(maxf(0.0, p.distance_to(at) - r), radius)
	for s: Site in sites:
		var b := _sim.buildings[s.building]
		if s.state == IDLE and force.call(s.pos, Vector2(b.w, b.d).length() * 0.5) > 0.0:
			damaged(s.building, true)
	_sim.hit_area(force, damage, 0, height)


func _step_bursts(dt: float) -> void:
	if bursts.is_empty():
		return
	var k: Dictionary = cfg["fireworks_factory"]
	var left: Array[Dictionary] = []
	for burst: Dictionary in bursts:
		burst["t"] = Num.f(burst["t"]) - dt
		if Num.f(burst["t"]) > 0.0:
			left.append(burst)
			continue
		var at: Vector2 = burst["pos"]
		_sim.events.append({"type": "firework_burst", "x": at.x, "z": at.y})
		var coat := _sim.hit_coat
		_sim.hit_coat = {
			"kind": "burn", "dps": Num.f(k["burn_dps"]), "seconds": Num.f(k["burn_seconds"])
		}
		_blast(at, Num.f(k["burst_radius"]), Num.f(k["burst_damage"]), Num.i(k["height"]))
		_sim.hit_coat = coat
	bursts = left


## Tanks inside a cloud lose cloud_tank_dps; a rooftop squad inside it for cloud_squad_seconds dies.
func _step_clouds(dt: float) -> void:
	if clouds.is_empty():
		return
	var k: Dictionary = cfg["chem_lab"]
	var r := Num.f(k["cloud_radius"])
	var left: Array[Dictionary] = []
	for cloud: Dictionary in clouds:
		var at: Vector2 = cloud["pos"]
		for tank: RampageSim.Tank in _sim.tanks:
			if tank.pos.distance_to(at) <= r:
				tank.hp -= Num.f(k["cloud_tank_dps"]) * dt
		var exposure: Dictionary = cloud["exposure"]
		for squad: Army.Squad in _sim.army_units.squads:
			if squad.pos.distance_to(at) <= r:
				exposure[squad] = Num.f(exposure.get(squad, 0.0)) + dt
				squad.dead = squad.dead or Num.f(exposure[squad]) >= Num.f(k["cloud_squad_seconds"])
		cloud["t"] = Num.f(cloud["t"]) - dt
		if Num.f(cloud["t"]) > 0.0:
			left.append(cloud)
	clouds = left
	_sim.army_units.clear_dead()
