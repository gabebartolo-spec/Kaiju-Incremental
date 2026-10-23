class_name TaskforceVolley
extends RefCounted
## The Taskforce's railguns (D-139, D-161, D-166, D-178 "Lock together, fire in turn"): a squad
## shoots in volleys. The first ready gunner opens one and every other ready gunner of its squad
## puts its aiming line up with it. The lines follow the kaiju, then lock together at one moment
## on one point (`lock_seconds` before the first shot), and the shots land `squad_gap` seconds
## apart in the squad's list order, so a single dash at the lock saves the kaiju from the whole
## squad and a kaiju standing still takes at most 2 hits a second from a squad. A shot costs
## `share` of max health if the kaiju still stands in the lock. Part of Taskforce; pure, no
## random draw. Events: railgun_aim, railgun_locked, railgun_hit, railgun_missed.

var sim: RampageSim
var cfg: Dictionary  # tuning "taskforce" "railgun"
## Per squad, the volley in progress: {"lock": seconds until its lines lock, "left": seconds until
## its last shot, after which the squad may open another}. A gunner killed mid-aim leaves its
## shot out; the volley still runs to its planned end.
var _volleys := {}


func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
	sim = p_sim
	cfg = p_cfg


## Whether the squad has a volley in progress (its other gunners hold their fire until it ends).
func busy(squad: int) -> bool:
	return _volleys.has(squad)


## Counts every volley down: the squad's lines lock together when theirs is up, and a volley whose
## last shot is due is over.
func tick(dt: float, agents: Array[Taskforce.Agent]) -> void:
	for squad: int in _volleys.keys():
		var volley: Dictionary = _volleys[squad]
		var left := Num.f(volley["left"]) - dt
		if left <= 0.0:
			_volleys.erase(squad)
			continue
		volley["left"] = left
		var lock := Num.f(volley["lock"])
		if lock > 0.0:
			volley["lock"] = lock - dt
			if lock - dt <= 0.0:
				_lock(squad, agents)


## `opener` (a perched gunner with its railgun ready and the kaiju in range) opens its squad's
## volley: it and every later-listed ready gunner of the squad put their lines up now. The nth
## shot is due `aim_seconds` + n x `squad_gap` after, the first shot first. A gunner listed after
## the opener also runs `aim` this very step, so it starts one `dt` behind to stay level.
func open(opener: Taskforce.Agent, agents: Array[Taskforce.Agent], dt: float) -> void:
	var gap := Num.f(cfg["squad_gap"])
	var shots := 0
	for i: int in range(agents.find(opener), agents.size()):
		var agent := agents[i]
		if agent == opener or _can_join(agent, opener.squad):
			_start_aim(agent, shots * gap + (0.0 if agent == opener else dt))
			shots += 1
	var first_shot := Num.f(cfg["aim_seconds"])
	_volleys[opener.squad] = {
		"lock": first_shot - Num.f(cfg["lock_seconds"]), "left": first_shot + (shots - 1) * gap
	}


## One step of an aiming gunner: the line follows the kaiju until the squad's lines lock, then the
## shot lands when its turn comes, on the kaiju only if it still stands in the lock.
func aim(agent: Taskforce.Agent, dt: float) -> void:
	agent.aim_left -= dt
	if agent.aim_left <= 0.0:
		_fire(agent)
	elif not agent.locked:
		agent.aim_at = sim.kaiju_pos


func _can_join(agent: Taskforce.Agent, squad: int) -> bool:
	return (
		agent.squad == squad
		and agent.state == Taskforce.PERCH
		and agent.rail_cd <= 0.0
		and agent.pos.distance_to(sim.kaiju_pos) <= Num.f(cfg["range"])
	)


## The gunner puts its railgun line up; its shot is due `aim_seconds` + `delay` from now.
func _start_aim(agent: Taskforce.Agent, delay: float) -> void:
	agent.state = Taskforce.AIM
	agent.aim_left = Num.f(cfg["aim_seconds"]) + delay
	agent.aim_at = sim.kaiju_pos
	agent.locked = false
	sim.events.append({"type": "railgun_aim", "agent": agent.id, "from": agent.muzzle()})


## The squad's lines lock together, every one on the first line's point.
func _lock(squad: int, agents: Array[Taskforce.Agent]) -> void:
	var point := Vector2.ZERO
	var first := true
	for agent: Taskforce.Agent in agents:
		if agent.squad != squad or agent.state != Taskforce.AIM or agent.locked:
			continue
		if first:
			point = agent.aim_at
			first = false
		agent.aim_at = point
		agent.locked = true
		sim.events.append({"type": "railgun_locked", "agent": agent.id, "x": point.x, "z": point.y})


func _fire(agent: Taskforce.Agent) -> void:
	var reach := Num.f(cfg["hit_radius"])
	var shot := {"type": "railgun_hit", "agent": agent.id, "from": agent.muzzle()}
	if sim.kaiju_pos.distance_to(agent.aim_at) <= reach:
		# armour softens it as it does a tank's shell (D-161), never below the army's minimum
		var damage := maxf(
			Num.f(sim.army["min_damage"]), sim.max_hp * Num.f(cfg["share"]) - sim.stat("armor")
		)
		sim.hp -= damage
		# every hit fires the colour fringe (D-145); `share` is what it cost of max health
		sim.events.append(
			shot.merged(
				{
					"damage": damage,
					"share": damage / sim.max_hp,
					"x": sim.kaiju_pos.x,
					"z": sim.kaiju_pos.y
				}
			)
		)
	else:
		sim.events.append(
			{"type": "railgun_missed", "agent": agent.id, "x": agent.aim_at.x, "z": agent.aim_at.y}
		)
	agent.state = Taskforce.PERCH
	agent.rail_cd = Num.f(cfg["cooldown"])
	agent.wait = Num.f(cfg["hop_after"])
