extends RefCounted
## The flow suite's layout checks (tests/lib/flow_screens.gd calls them): every screen's buttons
## stay on the director's 4K TV at every UI scale, and the evolution reveal fits and measures
## against the new stage's city.

## The director's TV (D-027). Headless windows are 64x64 (a tall square canvas), so each check
## sizes the window to this first.
const TV_SIZE := Vector2i(3840, 2160)

var t: SceneTree
var check: Callable


func _init(runner: SceneTree, p_check: Callable) -> void:
	t = runner
	check = p_check


func _frames(n: int) -> void:
	for _i: int in n:
		await t.process_frame


## Every UI scale keeps a screen's buttons fully on screen (the 4K TV at 125%, lead review 1).
func fits_at_scales(screen: Control, what: String) -> void:
	var misses: Array[String] = []
	# Headless windows are 64x64 (a tall square canvas); measure on the director's 4K TV.
	var window := t.root.size
	t.root.size = TV_SIZE
	for scale: float in PlayerSettings.UI_SCALES:
		PlayerSettings.ui_scale = scale
		PlayerSettings.apply()
		await _frames(3)
		var view := t.root.get_visible_rect()
		for node: Node in screen.find_children("*", "Button", true, false):
			var b: Button = node
			if b.is_visible_in_tree() and not _on_screen(b, view):
				var name := b.text.get_slice(String.chr(10), 0)
				misses.append("%s at %d%%" % [name, roundi(scale * 100.0)])
	PlayerSettings.ui_scale = PlayerSettings.UI_SCALES[0]
	PlayerSettings.apply()
	t.root.size = window
	await _frames(2)
	check.call(
		misses.is_empty(), "the %s's buttons stay on screen at every UI scale: %s" % [what, misses]
	)


## Fully inside the visible screen (tree nodes included: the tree shrinks to fit, never scrolls).
func _on_screen(b: Button, view: Rect2) -> bool:
	return view.encloses(b.get_global_rect())


## The reveal measures against the new stage's city (D-039): the Apex Titan topples size x tier
## height floors, more than the first city's tallest tower allows.
func reveal_stage_city() -> void:
	var tuning := Content.tuning()
	var stage4: Dictionary = CityGrowth.tuning_for(tuning, 4)["city"]
	var first: Dictionary = tuning["city"]
	var reveal := EvolutionReveal.new()
	reveal.setup(Content.species_def("reptilian"), {"size": 3}, {"size": 4}, stage4)
	var want := mini(4 * Num.i(stage4["tier_height"]), Num.i(stage4["max_height"]))
	check.call(
		reveal.tower_floors == want and want > Num.i(first["max_height"]),
		(
			"the Apex Titan's reveal tower is %d floors from its stage's city (first city caps %d)"
			% [reveal.tower_floors, Num.i(first["max_height"])]
		)
	)
	reveal.free()


## The reveal's size lines stay on screen on the TV at the largest UI scale (lead review 2).
func reveal_fits() -> void:
	var window := t.root.size
	t.root.size = TV_SIZE
	PlayerSettings.ui_scale = PlayerSettings.UI_SCALES[-1]
	PlayerSettings.apply()
	var reveal := EvolutionReveal.new()
	reveal.setup(
		Content.species_def("reptilian"), {"size": 1}, {"size": 2}, Content.section("city")
	)
	t.root.add_child(reveal)
	await _frames(EvolutionReveal.SWAP_FRAME + 4)
	var rect := reveal.lines.get_global_rect()
	var on := t.root.get_visible_rect().encloses(rect) and reveal.lines.text != ""
	reveal.finish()
	PlayerSettings.ui_scale = PlayerSettings.UI_SCALES[0]
	PlayerSettings.apply()
	t.root.size = window
	await _frames(2)
	check.call(on, "the reveal's size lines stay on screen at 125%% on the TV: %s" % [rect])
