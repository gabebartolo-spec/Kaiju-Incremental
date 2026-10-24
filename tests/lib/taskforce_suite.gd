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


## Lets the Taskforce spawn: the rampage time in the city already played (D-160), enough of the
## city fallen for the escalation, and a clock no run can end.
func _open(sim: RampageSim) -> void:
	sim.army_units.taskforce.carried = 1.0e9
	sim.chunks_destroyed = 5000
	sim.chunks_total = 10000000
	sim.time_left = 1.0e9


## A direction the kaiju can walk 10 units along with its whole body clear of standing walls and
## the arena's edge and nothing slowing its stride (so a dodge is not a bump), the one that needs
## the least turning; (0, 0) if there is none.
func _free_way(sim: RampageSim) -> Vector2:
	var best := Vector2.ZERO
	var least := INF
	for n: int in 16:
		var way := Vector2.from_angle(n * TAU / 16.0)
		var clear := true
		for reach: int in range(1, 11):
			var spot := sim.kaiju_pos + way * reach
			clear = (
				clear
				and sim.clamp_to_arena(spot) == spot
				and not sim.powers.blocked(spot, sim.powers.block_radius())
				and sim.body.inside(spot, way).is_empty()
			)
		var turn := absf(sim.body.heading.angle_to(way))
		if clear and turn < least:
			best = way
			least = turn
	return best


## Turns the standing kaiju to a free way and lets the body settle on it, so a walk along it needs
## no turn (a real turn takes the body longer than a railgun's last 0.4 s); the way, or (0, 0).
func _face_free_way(sim: RampageSim) -> Vector2:
	var way := _free_way(sim)
	sim.facing = way
	_run(sim, 1.0)
	return way


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


## The railgun_aim events in `events` that this agent fired (the squad's other agents aim on their
## own cooldowns; in the wider adolescent city their roofs are in range too).
func _aims_by(events: Array[Dictionary], agent_id: int) -> Array[Dictionary]:
	return events.filter(
		func(e: Dictionary) -> bool:
			return str(e["type"]) == "railgun_aim" and Num.i(e["agent"]) == agent_id
	)


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


## A scripted player for `seconds` (walks to the nearest standing building, as _autoplay does; or
## `walk` false: stands and smashes where it is), healed to full each step so the run goes on: what
## the Taskforce did to it, as {"hurt": damage taken, "railgun": hits, "frost": grenades that
## froze it}.
func _play(sim: RampageSim, seconds: float, walk := true) -> Dictionary:
	var out := {"hurt": 0.0, "railgun": 0, "frost": 0}
	var target := Vector2(INF, INF)
	for n: int in roundi(seconds / DT):
		if n % 15 == 0:
			target = sim.nearest_standing(sim.kaiju_pos)
		var near := target.x < INF and not sim.stomp_reaches(target)
		var move := (target - sim.kaiju_pos).normalized() if near and walk else Vector2.ZERO
		var events := sim.step(DT, move, false)
		out["hurt"] = Num.f(out["hurt"]) + sim.max_hp - sim.hp
		sim.hp = sim.max_hp
		for event: Dictionary in events:
			match str(event["type"]):
				"railgun_hit":
					out["railgun"] = Num.i(out["railgun"]) + 1
				"frost_hit":
					out["frost"] = Num.i(out["frost"]) + 1
	return out
