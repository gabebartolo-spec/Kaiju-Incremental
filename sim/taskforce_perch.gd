class_name TaskforcePerch
extends RefCounted
## Where a Taskforce agent lands (D-137): a standing top chunk of a building in the band round the
## kaiju that no other agent holds. Part of Taskforce; pure, and shares its seeded stream.

var sim: RampageSim
var cfg: Dictionary
var _rng: RandomNumberGenerator


func _init(p_sim: RampageSim, p_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = p_cfg
	_rng = rng


## A standing top chunk in the perch band around the kaiju, on a building no other agent holds
## or is bound for: [building index, cell], or [] when there is none.
func pick(agent: Taskforce.Agent, agents: Array[Taskforce.Agent]) -> Array:
	var options := _options(agent, agents)
	for _try: int in Num.i(cfg["perch_tries"]):
		if options.is_empty():
			break
		var i := options[_rng.randi_range(0, options.size() - 1)]
		var b := sim.buildings[i]
		var x := _rng.randi_range(0, b.w - 1)
		var z := _rng.randi_range(0, b.d - 1)
		var y := _top(b, x, z)
		if y >= 0:
			return [i, Vector3i(x, y, z)]
	return []


## The highest standing chunk of a column that is tall enough to perch on (the building's roof
## where it is whole, a lower floor where its top was chewed away), or -1.
func _top(b: RampageSim.Building, x: int, z: int) -> int:
	for y: int in range(b.height - 1, Num.i(cfg["perch_min_height"]) - 2, -1):
		if b.frame.alive(Vector3i(x, y, z)):
			return y
	return -1


## Whether any column of the building still has a chunk to perch on.
func _has_top(b: RampageSim.Building) -> bool:
	for x: int in b.w:
		for z: int in b.d:
			if _top(b, x, z) >= 0:
				return true
	return false


## The buildings an agent may perch on: standing, tall enough, in the perch band round the kaiju,
## and not held or aimed at by another agent. With none in the band (the kaiju at the map edge, or
## the city round it flattened) the `perch_fallback` nearest to the band, so a squad never hovers.
func _options(agent: Taskforce.Agent, agents: Array[Taskforce.Agent]) -> Array[int]:
	var span: Array = cfg["perch_range"]
	var taken := {}
	for other: Taskforce.Agent in agents:
		if other != agent and other.building >= 0:
			taken[other.building] = true
	var options: Array[int] = []
	var outside: Array[Array] = []  # [distance outside the band, building]
	for i: int in sim.buildings.size():
		if taken.has(i) or not _perchable(sim.buildings[i]):
			continue
		var b := sim.buildings[i]
		var away := Vector2(b.x, b.z).distance_to(sim.kaiju_pos)
		var gap := maxf(maxf(Num.f(span[0]) - away, away - Num.f(span[1])), 0.0)
		if gap == 0.0:
			options.append(i)
		else:
			outside.append([gap, i])
	if options.is_empty():
		outside.sort_custom(func(a: Array, c: Array) -> bool: return Num.f(a[0]) < Num.f(c[0]))
		for pair: Array in outside.slice(0, Num.i(cfg["perch_fallback"])):
			options.append(Num.i(pair[1]))
	return options


## Standing, in the arena, tall enough, and with a chunk left to land on.
func _perchable(b: RampageSim.Building) -> bool:
	return (
		b.in_arena
		and b.frame.alive_count > 0
		and b.height >= Num.i(cfg["perch_min_height"])
		and _has_top(b)
	)
