extends Node
## Game flow: title -> species select (new game) -> rampage -> end beat -> results ->
## evolution tree (evolution reveal on an evolution) -> rampage ...
## The demo (D-050, data/tuning.json "demo") offers its species only and, after its end
## evolution's reveal, shows the demo end card; Continue on that save lands there again.
## Owns the save state; screens get what they need through setup() and report back by signal.
## Progress comes only from playing: nothing accrues while the game is closed.

const CITY_STREAM := "city"

var _screen: Node
var _save: Dictionary = {}
var _tree: UpgradeTree


func _ready() -> void:
	_save = SaveSystem.load_game()
	_show_title()


## The window's own close (Alt+F4, the X): the same hidden-first quit as the QUIT buttons.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		QuitGame.now(get_tree())


## The screen on show (the flow suite and captures read it).
func screen() -> Node:
	return _screen


func _swap(next: Node) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = next
	PlayerSettings.in_play = next is Rampage
	add_child(next)


func _show_title() -> void:
	var title := TitleScreen.new()
	title.setup(_summary())
	title.continue_pressed.connect(_continue)
	title.new_game_pressed.connect(_new_game)
	_swap(title)


## What Continue resumes, e.g. "Reptilian, 3 rampages, 120 biomass"; "" with no save (or a
## save of a species the demo leaves out).
func _summary() -> String:
	if _save.is_empty() or not Demo.allows(str(_save.get("species", ""))):
		return ""
	var runs := Num.i(_save.get("runs", 0))
	return (
		"%s, %d rampage%s, %d biomass"
		% [
			str(_species()["name"]),
			runs,
			"" if runs == 1 else "s",
			Num.i(_save.get("rubble", 0)),
		]
	)


func _new_game() -> void:
	var select := SpeciesSelect.new()
	select.chosen.connect(_on_species_chosen)
	select.back_pressed.connect(_show_title)
	_swap(select)


func _on_species_chosen(species_id: String) -> void:
	_save = SaveFile.new_save(species_id)
	SaveSystem.save_game(_save)
	_continue()


func _continue() -> void:
	var levels: Dictionary = _save.get("levels", {})
	_tree = UpgradeTree.new(GameData.upgrades, levels, str(_save.get("species", "")))
	if Demo.complete(levels):
		_show_demo_end()
	elif Num.i(_save.get("runs", 0)) == 0:
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
	rampage.staged = true  # built over several frames behind a loading screen (b2-30)
	var runs := Num.i(_save.get("runs", 0))
	rampage.setup(_species(), stats, layout, runs)
	# The time of day (D-145): random, never the last run's, unless the options fix one. The
	# save remembers it, even if the rampage is quit before it ends.
	var time_id := TimeOfDay.pick(runs, str(_save.get("last_time", "")), PlayerSettings.time_of_day)
	Content.set_time(time_id)
	_save["last_time"] = time_id
	# The weather (D-155) the same way: seeded, never the last run's, unless the options fix one.
	var weather_id := Weather.pick(runs, str(_save.get("last_weather", "")), PlayerSettings.weather)
	Content.set_weather(weather_id)
	_save["last_weather"] = weather_id
	SaveSystem.save_game(_save)
	rampage.finished.connect(_on_rampage_finished)
	_swap(rampage)


## Banks the rampage, then shows the results over the wrecked city, against the best before it.
func _on_rampage_finished(result: Dictionary) -> void:
	var previous: Dictionary = _save.get("best", {})
	if Num.i(_save.get("runs", 0)) == 0:
		previous = {}
	_save["rubble"] = Num.i(_save.get("rubble", 0)) + Num.i(result["rubble"])
	_save["runs"] = Num.i(_save.get("runs", 0)) + 1
	_save["best"] = SaveFile.merge_best(previous, result)
	SaveSystem.save_game(_save)
	var results := ResultsScreen.new(result, previous)
	results.continued.connect(_show_tree)
	_screen.add_child(results)


func _show_tree() -> void:
	var screen := UpgradeScreen.new()
	screen.setup(_tree, Num.i(_save.get("rubble", 0)), _species(), _base_stats())
	screen.bought.connect(func(id: String) -> void: _on_bought(screen, id))
	screen.start_pressed.connect(_start_rampage)
	screen.menu_pressed.connect(_show_title)
	_swap(screen)


func _on_bought(screen: UpgradeScreen, id: String) -> void:
	_save["rubble"] = screen.rubble
	_save["levels"] = _tree.levels.duplicate()
	SaveSystem.save_game(_save)
	var def: Dictionary = _tree.defs[id]
	var effects: Dictionary = def.get("effects", {})
	if effects.has("size"):
		_reveal(screen, id)


## The evolution reveal over the tree: the body before this purchase against the body after.
func _reveal(screen: UpgradeScreen, id: String) -> void:
	var before_levels := _tree.levels.duplicate()
	before_levels[id] = _tree.level(id) - 1
	var before_tree := UpgradeTree.new(GameData.upgrades, before_levels, str(_save["species"]))
	var after := UpgradeTree.run_stats(_base_stats(), _species(), _tree)
	var stage_city: Dictionary = CityGrowth.for_stats(after)["city"]
	var reveal := EvolutionReveal.new()
	var def: Dictionary = _tree.defs[id]
	reveal.title = EvolutionReveal.title_of(def)
	# The new stage's city (D-039), so "towers up to N floors" matches the city it will face.
	reveal.setup(
		_species(), UpgradeTree.run_stats(_base_stats(), _species(), before_tree), after, stage_city
	)
	if Demo.is_end(id):
		reveal.done.connect(_show_demo_end, CONNECT_DEFERRED)
	else:
		var node := screen.node_button(id)
		reveal.done.connect(func() -> void: node.grab_focus.call_deferred())
	screen.add_child(reveal)


## The demo's last screen: the next stage roaring, Title or Quit (D-050).
func _show_demo_end() -> void:
	var card := DemoEnd.new()
	card.setup(_species(), _base_stats())
	card.title_pressed.connect(_show_title)
	_swap(card)
