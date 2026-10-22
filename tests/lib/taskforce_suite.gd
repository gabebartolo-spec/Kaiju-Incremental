extends "res://tests/lib/sim_suite.gd"
## The Taskforce suite's shared set-up (tests/run_taskforce_tests.gd): an adolescent-city rampage,
## agents placed on roofs, a stepping runner and a free way to walk. It defines no test, so it adds
## no function to the suite's count.

const DASH_BUTTON := 4  # Dash.BUTTON
const FAR := 25.0  # a perch this far from the kaiju is inside every range


## A rampage at the adolescent city (size tier 2), the kaiju where the run puts it: on the ring
## avenue at the south edge, with the street open to walk along.
func _adolescent(species: String = "reptilian", levels: Dictionary = {"evolve1": 1}) -> RampageSim:
	var sim := _sim(species, levels, 0, CityGrowth.tuning_for(Content.tuning(), 2))
	return sim


## Lets the Taskforce spawn: enough of the city fallen, and a clock no run can end.
func _open(sim: RampageSim) -> void:
	sim.chunks_destroyed = 5000
	sim.chunks_total = 10000000
	sim.time_left = 1.0e9


## A direction the kaiju can walk a few steps along without meeting a building (so a dodge is
## not a bump); (0, 0) if every way is blocked.
func _free_way(sim: RampageSim) -> Vector2:
	for n: int in 16:
		var way := Vector2.from_angle(n * TAU / 16.0)
		var blocked := false
		for reach: float in [3.0, 6.0, 9.0]:
			var spot := sim.kaiju_pos + way * reach
			for b: RampageSim.Building in sim.buildings:
				blocked = (
					blocked
					or (
						absf(spot.x - b.x) < b.w * 0.5 + 2.0
						and absf(spot.y - b.z) < b.d * 0.5 + 2.0
					)
				)
		if not blocked:
			return way
	return Vector2.ZERO


## The index of a tall building about `FAR` from the kaiju, for an agent to perch on.
func _roof(sim: RampageSim, tf: Taskforce) -> int:
	var best := -1
	var gap := INF
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		var away := Vector2(b.x, b.z).distance_to(sim.kaiju_pos)
		if b.height >= Num.i(tf.cfg["perch_min_height"]) and absf(away - FAR) < gap:
			best = i
			gap = absf(away - FAR)
	return best


## A perched agent with nothing else to do but what a test wants: its railgun ready or not,
## frost grenades off.
func _perched(sim: RampageSim, rail_ready: bool) -> Taskforce.Agent:
	var tf := sim.army_units.taskforce
	var i := _roof(sim, tf)
	var b := sim.buildings[i]
	var agent := tf.place_agent(i, Vector3i(b.w / 2, b.height - 1, b.d / 2))
	agent.rail_cd = 0.0 if rail_ready else 1.0e9
	agent.frost_cd = 1.0e9
	agent.wait = 1.0e9
	return agent


func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for event: Dictionary in events:
		out.append(str(event["type"]))
	return out


func _first(events: Array[Dictionary], type: String) -> Dictionary:
	for event: Dictionary in events:
		if str(event["type"]) == type:
			return event
	return {}


## Steps `seconds` walking `move` (stopping early at the first event of `until`); every event
## it saw.
func _run(
	sim: RampageSim, seconds: float, until: String = "", move := Vector2.ZERO
) -> Array[Dictionary]:
	var seen: Array[Dictionary] = []
	for _n: int in roundi(seconds / DT):
		var events := sim.step(DT, move, false)
		seen.append_array(events)
		if until != "" and not _first(events, until).is_empty():
			break
	return seen


## The damage the kaiju takes over `seconds`, healed back to full each step so the run goes on.
func _hurt_in(sim: RampageSim, seconds: float) -> float:
	var hurt := 0.0
	for _n: int in roundi(seconds / DT):
		sim.step(DT, Vector2.ZERO, false)
		hurt += sim.max_hp - sim.hp
		sim.hp = sim.max_hp
	return hurt
