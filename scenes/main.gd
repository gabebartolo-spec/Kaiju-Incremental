extends Node
## Game flow: title -> Kaiju Creation (new game) -> rampage -> end beat -> results ->
## evolution tree (evolution reveal on an evolution) -> rampage ...
## The demo (D-050, data/tuning.json "demo") offers its species only. Buying its final upgrade (the
## whole tree) shows the thanks screen and unlocks Endless mode (Endless, D-156), started from the
## thanks screen or the tree; normal mode stays replayable.
## Owns the save state; screens get what they need through setup() and report back by signal.
## Progress comes only from playing: nothing accrues while the game is closed.

const CITY_STREAM := "city"

var _screen: Node
var _save: Dictionary = {}
var _tree: UpgradeTree
## Whether the rampage on show is Endless mode (it banks nothing: normal mode sets the balance).
var _endless := false


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
	if not Demo.continues(_save):
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


## New Kaiju: Kaiju Creation (D-207), the lab where the player picks a genome and makes the titan;
## its rack reads which titans the save on disk has unlocked. Nothing is saved until it is done.
func _new_game() -> void:
	var lab := KaijuCreation.new()
	lab.setup(_save)
	lab.created.connect(_on_species_chosen)
	lab.back_pressed.connect(_show_title)
	_swap(lab)


func _on_species_chosen(species_id: String) -> void:
	_save = SaveFile.new_save(species_id)
	_save["demo"] = Demo.enabled()  # a demo save never continues in the full game (D-145)
	SaveSystem.save_game(_save)
	_continue()


func _continue() -> void:
	var levels: Dictionary = _save.get("levels", {})
	_tree = UpgradeTree.new(GameData.upgrades, levels, str(_save.get("species", "")))
	if Num.i(_save.get("runs", 0)) == 0:
		_start_rampage()
	else:
		_show_tree()


## The demo's rampage totals so far (Demo.add).
func _totals() -> Dictionary:
	var totals: Dictionary = _save.get("totals", {})
	return totals


func _species() -> Dictionary:
	return GameData.species_def(str(_save.get("species", "")))


func _base_stats() -> Dictionary:
	return GameData.section("kaiju")


func _start_rampage(endless := false) -> void:
	var stats := UpgradeTree.run_stats(_base_stats(), _species(), _tree)
	var tier := Num.i(stats["size"])
	var layout := CityGrowth.layout(Content.tuning(), tier, Rng.make(CITY_STREAM, 0))
	_endless = endless
	var rampage := Rampage.new()
	rampage.staged = true  # built over several frames behind a loading screen (b2-30)
	var runs := Num.i(_save.get("runs", 0))
	rampage.city_seconds = Num.f(_save.get("city_seconds", 0.0))
	rampage.setup(_species(), stats, layout, runs)
	if endless:  # the demo's Endless mode (D-156)
		rampage.sim.endless = Endless.new()
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
## An Endless run banks nothing; a demo rampage adds to the thanks screen's totals (Demo.add).
func _on_rampage_finished(result: Dictionary) -> void:
	var previous: Dictionary = _save.get("best", {})
	if Num.i(_save.get("runs", 0)) == 0:
		previous = {}
	if not _endless:
		_save["rubble"] = Num.i(_save.get("rubble", 0)) + Num.i(result["rubble"])
		_save["runs"] = Num.i(_save.get("runs", 0)) + 1
		var clock := Num.f(_save.get("city_seconds", 0.0))
		_save["city_seconds"] = Num.f(result.get("city_seconds", clock))  # the Taskforce's clock
		_save["best"] = SaveFile.merge_best(previous, result)
		if Demo.enabled():
			_save["totals"] = Demo.add(_totals(), result)
		SaveSystem.save_game(_save)
	var results := ResultsScreen.new(result, previous)
	if _endless:
		results.go_label = "BACK  >"
	results.continued.connect(_show_tree)
	_screen.add_child(results)


func _show_tree() -> void:
	var screen := UpgradeScreen.new()
	screen.setup(_tree, Num.i(_save.get("rubble", 0)), _species(), _base_stats())
	screen.bought.connect(func(id: String) -> void: _on_bought(screen, id))
	screen.start_pressed.connect(_start_rampage)
	screen.endless_unlocked = _save.get("demo_done", false) == true
	screen.endless_pressed.connect(_start_rampage.bind(true))
	screen.menu_pressed.connect(_show_title)
	_swap(screen)


func _on_bought(screen: UpgradeScreen, id: String) -> void:
	_save["rubble"] = screen.rubble
	_save["levels"] = _tree.levels.duplicate()
	SaveSystem.save_game(_save)
	var def: Dictionary = _tree.defs[id]
	var effects: Dictionary = def.get("effects", {})
	# The final upgrade: every node owned, and the thanks not shown before.
	var last: bool = Demo.complete(_tree) and _save.get("demo_done", false) != true
	if last:  # the whole tree is owned (D-156): the thanks screen, and Endless mode unlocks
		_save["demo_done"] = true
		SaveSystem.save_game(_save)
	if effects.has("size"):
		_reveal(screen, id, _show_demo_end if last else Callable())
	elif last:
		_show_demo_end.call_deferred()


## The evolution reveal over the tree: the body before this purchase against the body after.
func _reveal(screen: UpgradeScreen, id: String, then := Callable()) -> void:
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
	var node := screen.node_button(id)
	if then.is_valid():
		reveal.done.connect(then, CONNECT_DEFERRED)
	else:
		reveal.done.connect(func() -> void: node.grab_focus.call_deferred())
	screen.add_child(reveal)


## The demo's thanks screen: rampage totals, a feedback link, Endless mode or back to the tree
## (D-152, D-156).
func _show_demo_end() -> void:
	var card := DemoEnd.new()
	card.setup(_species(), _base_stats(), _totals())
	card.endless_pressed.connect(_start_rampage.bind(true))
	card.keep_pressed.connect(_show_tree)
	_swap(card)
