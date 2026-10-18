class_name StrikeWing
extends RefCounted
## Military jets (D-072): once enough of the city has fallen, a jet makes a fast straight pass
## across the arena, strafing a line through where the kaiju stood when it was called in, then
## flies on and out; another follows after `interval`. Passes run across the game camera's view
## (at right angles to `camera_bearing`, give or take `yaw_jitter`), so a pass is seen edge to
## edge and never flies at the lens; it flies `clearance` over the kaiju's head. Before the first
## round lands the sim says where (jet_inbound), as long before as the kaiju needs to walk clear
## of the line at its size and speed plus `react_seconds` (D-080), entering further out when it
## needs to: a kaiju that steps off the line takes nothing. Rounds also chew the roofs they land
## on: collateral that falls like any other but pays the player no biomass (director, D-072).
## Only an attack that reaches the air (or a cephalopod's grab) downs a jet. Unlike the
## helicopters (AirWing) a jet never circles.
## Part of RampageSim. Pure and seeded.


class Jet:
	var id: int
	var kind: String
	var start: Vector2  # where it enters, `approach` short of the line's centre
	var approach: float  # how far short: `approach`, or further when the warning needs it
	var lead: float  # seconds of warning before its first round lands
	var dir: Vector2  # its heading on the ground plane
	var s := 0.0  # distance flown from start
	var pos: Vector2
	var hp: float
	var next_round := 0  # the next point of the strafing line to land
	var warned := false


var sim: RampageSim
var cfg: Dictionary
var jets: Array[Jet] = []
var destroyed := 0
var _rng: RandomNumberGenerator
var _spawn_timer := 0.0
var _next_id := 0
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
		jet.s += Num.f(cfg["speed"]) * dt
		jet.pos = jet.start + jet.dir * jet.s
		_strafe(jet)
		if jet.s >= 2.0 * jet.approach:
			gone.append(jet)
	for jet: Jet in gone:
		jets.erase(jet)
		sim.events.append({"type": "jet_left", "jet": jet.id})


## A new jet lines up on the kaiju: it enters `approach` short of the kaiju's spot (off screen;
## further if its warning needs the room) from alternate sides, heading across the camera's view.
func spawn() -> Jet:
	var jet := Jet.new()
	jet.id = _next_id
	_next_id += 1
	jet.kind = str(cfg["kind"])
	var across := Vector2.from_angle(deg_to_rad(Num.f(cfg["camera_bearing"]))).orthogonal()
	var jitter := deg_to_rad(Num.f(cfg["yaw_jitter"]))
	jet.dir = (across * _side).rotated(_rng.randf_range(-jitter, jitter))
	_side = -_side
	var centre := sim.kaiju_pos - _toward_camera() * Num.f(cfg["lane_behind"])
	jet.lead = warn_lead(0.0)
	var speed := Num.f(cfg["speed"])
	var half_line := Num.f(cfg["strafe_step"]) * (Num.i(cfg["rounds"]) - 1) * 0.5
	var room := speed * (jet.lead + Num.f(cfg["react_seconds"])) + half_line
	jet.approach = maxf(Num.f(cfg["approach"]), room + Num.f(cfg["strafe_lead"]))
	jet.start = centre - jet.dir * jet.approach
	jet.pos = jet.start
	jet.hp = Num.f(cfg["hp"])
	jets.append(jet)
	sim.events.append(
		{"type": "jet_spawned", "jet": jet.id, "kind": jet.kind, "from": jet.start, "dir": jet.dir}
	)
	return jet


## The ground points its rounds land on, in order: `rounds` of them, `strafe_step` apart,
## centred on the point it lined up on.
func line(jet: Jet) -> PackedVector2Array:
	var out := PackedVector2Array()
	var step := Num.f(cfg["strafe_step"])
	var first := jet.approach - step * (Num.i(cfg["rounds"]) - 1) * 0.5
	for k: int in Num.i(cfg["rounds"]):
		out.append(jet.start + jet.dir * (first + step * k))
	return out


## Its guns hit `strafe_lead` ahead of it: each line point lands as that spot reaches it, and
## the warning goes out `lead` seconds before the first.
func _strafe(jet: Jet) -> void:
	var points := line(jet)
	var gun := jet.s + Num.f(cfg["strafe_lead"])
	var first := jet.start.distance_to(points[0])
	if not jet.warned and gun >= first - Num.f(cfg["speed"]) * jet.lead:
		jet.warned = true
		(
			sim
			. events
			. append(
				{
					"type": "jet_inbound",
					"jet": jet.id,
					"from": points[0],
					"to": points[-1],
					"lead": jet.lead,
				}
			)
		)
	var body := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale()
	while jet.next_round < points.size():
		var at := points[jet.next_round]
		if gun < jet.start.distance_to(at):
			break
		jet.next_round += 1
		var hit := at.distance_to(sim.kaiju_pos) <= body
		if hit:
			var hurt := Num.f(cfg["damage"]) - sim.stat("armor")
			sim.hp -= maxf(Num.f(sim.army["min_damage"]), hurt)
		_wreck(at)
		sim.events.append({"type": "jet_strafe", "jet": jet.id, "at": at, "hit": hit})


## Collateral: a round chews the roof it lands on, the top standing chunk of each column within
## `round_radius`; those chunks fall like any other, but the biomass they would pay is taken back.
func _wreck(at: Vector2) -> void:
	var radius := Num.f(cfg["round_radius"])
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
					for y: int in range(b.height - 1, -1, -1):
						if b.frame.alive(Vector3i(x, y, z)):
							cells.append(Vector3i(x, y, z))
							break
		if not cells.is_empty():
			var kept := sim.rubble
			sim.damage_chunks(i, cells, Num.f(cfg["round_damage"]))
			sim.rubble = kept


## D-080: seconds of warning the kaiju needs to walk clear of a hit `blast` wide (its body
## radius plus the blast, at its speed) plus `react_seconds` to see it.
func warn_lead(blast: float) -> float:
	var clear := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale() + blast
	return clear / maxf(0.1, sim.stat("speed")) + Num.f(cfg["react_seconds"])


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
