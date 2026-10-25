extends RefCounted
## The leap on the dash button (D-259): in a real rampage started from the title, a Shift key press
## (real input through Input, as a player's arrives) makes the croc crouch, fly forward along its
## facing and land, with the landing's ring in the sim's events; the HUD's dash ring empties and
## refills beside the breath ring.

const GuiInput := preload("res://tests/lib/gui_input.gd")
## Frames to let the leap run out (the young croc's lasts about 2.1 s).
const SETTLE_FRAMES := 160


static func run(t: SceneTree, check: Callable, rampage: Rampage) -> void:
	var sim := rampage.sim
	while sim.emerge.active:  # the river rise holds the sim back (D-083)
		await t.physics_frame
	var from := sim.kaiju_pos
	var facing := sim.facing
	var landed := []
	await GuiInput.key(t, KEY_SHIFT)
	for _i: int in SETTLE_FRAMES:
		await t.physics_frame
		for event: Dictionary in sim.events:
			if str(event["type"]) == "leap_land":
				landed.append(event)
	var moved := (sim.kaiju_pos - from).dot(facing)
	check.call(
		sim.body.dash.dashes == 1 and landed.size() == 1 and moved > sim.body.length() * 0.25,
		(
			"Shift leaps the croc forward and lands it (%d leap, %d landing, %.1f m, body %.1f m)"
			% [sim.body.dash.dashes, landed.size(), moved, sim.body.length()]
		)
	)
	var hud: RampageHud = rampage.find_children("*", "RampageHud", true, false)[0]
	var ring := hud.dash_ring
	check.call(
		ring.modulate.a > 0.0 and ring.ratio > 0.0 and not ring.is_ready(),
		"the HUD's dash ring shows the leap recharging after it (%.2f full)" % ring.ratio
	)
	_check_roars(rampage, check)


## D-145: the kaiju roars on a leap (the dash's roar) and on an ultimate, at most once in the
## sfx "roar_cooldown".
static func _check_roars(rampage: Rampage, check: Callable) -> void:
	var view: PowersView = rampage.get("_powers")
	var roars := view.roar
	check.call(roars.roars == 1, "the leap roars once (%d roars)" % roars.roars)
	var dash := {"type": "leap", "dir": Vector2(0, -1)}
	view.on_event(dash, Vector3.ZERO)
	view.on_event({"type": "ultimate"}, Vector3.ZERO)
	check.call(roars.roars == 1, "leap spam does not stack roars (%d roars)" % roars.roars)
	rampage.sim.time_left -= Num.f(Content.section("sfx")["roar_cooldown"]) + 0.1
	view.on_event({"type": "ultimate"}, Vector3.ZERO)
	check.call(
		roars.roars == 2, "an ultimate roars once the cooldown has passed (%d)" % roars.roars
	)
