extends RefCounted
## Playtest note 4, the charge: in a real rampage started from the title, a Shift key press
## (real input through Input, as a player's arrives) dashes the croc forward along its facing,
## and the HUD's dash ring empties and refills beside the breath ring.

const GuiInput := preload("res://tests/lib/gui_input.gd")
## Frames to let the dash run out (it lasts about 0.4 s).
const SETTLE_FRAMES := 40


static func run(t: SceneTree, check: Callable, rampage: Rampage) -> void:
	var sim := rampage.sim
	while sim.emerge.active:  # the river rise holds the sim back (D-083)
		await t.physics_frame
	sim.facing = _open_way(sim)  # the plan decides what stands by the bank; the dash needs room
	var from := sim.kaiju_pos
	var facing := sim.facing
	await GuiInput.key(t, KEY_SHIFT)
	for _i: int in SETTLE_FRAMES:
		await t.process_frame
	var moved := (sim.kaiju_pos - from).dot(facing)
	check.call(
		sim.body.dash.dashes == 1 and moved > sim.body.length(),
		(
			"Shift dashes the croc forward more than a body length (%d dash, %.1f m of %.1f m)"
			% [sim.body.dash.dashes, moved, sim.body.length()]
		)
	)
	var hud: RampageHud = rampage.find_children("*", "RampageHud", true, false)[0]
	var ring := hud.dash_ring
	check.call(
		ring.modulate.a > 0.0 and ring.ratio > 0.0 and not ring.is_ready(),
		"the HUD's dash ring shows the dash recharging after it (%.2f full)" % ring.ratio
	)
	_check_roars(rampage, check)


## D-145: the kaiju roars on a dash and on an ultimate, at most once in the sfx "roar_cooldown".
static func _check_roars(rampage: Rampage, check: Callable) -> void:
	var view: PowersView = rampage.get("_powers")
	var roars := view.roar
	check.call(roars.roars == 1, "the dash roars once (%d roars)" % roars.roars)
	var dash := {"type": "dash", "dir": Vector2(0, -1)}
	view.on_event(dash, Vector3.ZERO)
	view.on_event({"type": "ultimate"}, Vector3.ZERO)
	check.call(roars.roars == 1, "dash spam does not stack roars (%d roars)" % roars.roars)
	rampage.sim.time_left -= Num.f(Content.section("sfx")["roar_cooldown"]) + 0.1
	view.on_event({"type": "ultimate"}, Vector3.ZERO)
	check.call(
		roars.roars == 2, "an ultimate roars once the cooldown has passed (%d)" % roars.roars
	)


## The facing nearest the current one with 1.5 body lengths clear of walls ahead (the dash's reach).
static func _open_way(sim: RampageSim) -> Vector2:
	var best := sim.facing
	var least := INF
	var reach := ceili(sim.body.length() * 2.0)
	for n: int in 16:
		var way := Vector2.from_angle(n * TAU / 16.0)
		var clear := true
		for step: int in range(1, reach + 1):
			var spot := sim.kaiju_pos + way * step
			clear = (
				clear
				and sim.clamp_to_arena(spot) == spot
				and not sim.powers.blocked(spot, sim.powers.block_radius())
				and sim.body.inside(spot, way).is_empty()
			)
		var turn := absf(sim.facing.angle_to(way))
		if clear and turn < least:
			best = way
			least = turn
	return best
