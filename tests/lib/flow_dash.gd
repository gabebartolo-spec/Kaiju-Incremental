extends RefCounted
## Playtest note 4, the charge: in a real rampage started from the title, a Shift key press
## (real input through Input, as a player's arrives) dashes the croc forward along its facing,
## and the HUD shows the dash cooling down beside the other ability prompts.

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
	var prompt := ""
	for node: Node in rampage.find_children("*", "Label", true, false):
		var l: Label = node
		if l.text.begins_with("DASH") and l.is_visible_in_tree():
			prompt = l.text
	check.call(
		prompt.begins_with("DASH  ") and prompt.ends_with("s") and not prompt.contains("READY"),
		"the HUD shows the dash cooling down after it: '%s'" % prompt
	)
	_check_roars(rampage, check)


## D-145: the kaiju roars on a dash and on an ultimate, at most once in the sfx "roar_cooldown".
static func _check_roars(rampage: Rampage, check: Callable) -> void:
	var view: PowersView = rampage.get("_powers")
	check.call(view.roars == 1, "the dash roars once (%d roars)" % view.roars)
	var dash := {"type": "dash", "dir": Vector2(0, -1)}
	view.on_event(dash, Vector3.ZERO)
	view.on_event({"type": "ultimate"}, Vector3.ZERO)
	check.call(view.roars == 1, "dash spam does not stack roars (%d roars)" % view.roars)
	rampage.sim.time_left -= Num.f(Content.section("sfx")["roar_cooldown"]) + 0.1
	view.on_event({"type": "ultimate"}, Vector3.ZERO)
	check.call(view.roars == 2, "an ultimate roars once the cooldown has passed (%d)" % view.roars)
