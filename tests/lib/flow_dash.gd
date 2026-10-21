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
		(ring.get_parent() as Control).modulate.a > 0.0 and ring.ratio > 0.0 and not ring.is_ready(),
		"the HUD's dash ring shows the dash recharging after it (%.2f full)" % ring.ratio
	)
