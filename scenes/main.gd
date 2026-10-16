extends Node
## Game flow: title -> species select (new game) -> rampage -> evolution tree -> rampage ...
## Owns the save state; screens get what they need through setup() and report back by signal.
## Progress comes only from playing: nothing accrues while the game is closed.

const CITY_STREAM := "city"

var _screen: Node
var _save: Dictionary = {}
var _tree: UpgradeTree


func _ready() -> void:
	_save = SaveSystem.load_game()
	_show_title()


func _swap(next: Node) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = next
	add_child(next)


func _show_title() -> void:
	var screen := Control.new()
	UiKit.full_rect(screen)
	screen.add_child(UiKit.backdrop())
	var col := VBoxContainer.new()
	UiKit.full_rect(col)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 24)
	screen.add_child(col)
	var title := UiKit.label("KAIJU INCREMENTAL", 104, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := UiKit.label("Grow. Evolve. Flatten the city.", UiKit.SIZE_HEAD, UiKit.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size = Vector2(520, 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons.add_theme_constant_override("separation", 16)
	col.add_child(buttons)
	var focus: Button
	if not _save.is_empty():
		var species := GameData.species_def(str(_save.get("species", "")))
		var cont := UiKit.button("CONTINUE  (%s)" % str(species["name"]), UiKit.SIZE_HEAD)
		cont.pressed.connect(_continue)
		buttons.add_child(cont)
		focus = cont
	var fresh := UiKit.button(
		"NEW KAIJU", UiKit.SIZE_HEAD, UiKit.PANEL_EDGE if focus else UiKit.ACCENT
	)
	fresh.pressed.connect(_new_game)
	buttons.add_child(fresh)
	if focus == null:
		focus = fresh
	var hint := UiKit.label("F11 fullscreen", UiKit.SIZE_SMALL, UiKit.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	_swap(screen)
	focus.grab_focus.call_deferred()


func _new_game() -> void:
	var select := SpeciesSelect.new()
	select.chosen.connect(_on_species_chosen)
	_swap(select)


func _on_species_chosen(species_id: String) -> void:
	_save = {"species": species_id, "rubble": 0, "levels": {}, "runs": 0, "best_destruction": 0.0}
	SaveSystem.save_game(_save)
	_continue()


func _continue() -> void:
	var levels: Dictionary = _save.get("levels", {})
	_tree = UpgradeTree.new(GameData.upgrades, levels, str(_save.get("species", "")))
	if Num.i(_save.get("runs", 0)) == 0:
		_start_rampage()
	else:
		_show_tree()


func _species() -> Dictionary:
	return GameData.species_def(str(_save.get("species", "")))


func _base_stats() -> Dictionary:
	return GameData.section("kaiju")


func _start_rampage() -> void:
	var stats := UpgradeTree.run_stats(_base_stats(), _species(), _tree)
	var tier := Num.i(stats["size"])
	var layout := CityGrowth.layout(Content.tuning(), tier, Rng.make(CITY_STREAM, 0))
	var rampage := Rampage.new()
	rampage.setup(_species(), stats, layout, Num.i(_save.get("runs", 0)))
	rampage.finished.connect(_on_rampage_finished)
	_swap(rampage)


func _on_rampage_finished(result: Dictionary) -> void:
	_save["rubble"] = Num.i(_save.get("rubble", 0)) + Num.i(result["rubble"])
	_save["runs"] = Num.i(_save.get("runs", 0)) + 1
	_save["best_destruction"] = maxf(
		Num.f(_save.get("best_destruction", 0.0)), Num.f(result["destruction"])
	)
	SaveSystem.save_game(_save)
	_show_tree()


func _show_tree() -> void:
	var screen := UpgradeScreen.new()
	screen.setup(_tree, Num.i(_save.get("rubble", 0)), _species(), _base_stats())
	screen.bought.connect(func(_id: String) -> void: _on_bought(screen))
	screen.start_pressed.connect(_start_rampage)
	_swap(screen)


func _on_bought(screen: UpgradeScreen) -> void:
	_save["rubble"] = screen.rubble
	_save["levels"] = _tree.levels.duplicate()
	SaveSystem.save_game(_save)
