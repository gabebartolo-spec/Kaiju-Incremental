extends Node
## Game flow: title -> Kaiju Creation (new game) -> the globe (D-462; Continue goes there too) ->
## a city's rampage (a normal rampage, banked as any: D-462) -> results -> WIN / LOSE -> evolution
## tree (evolution reveal on an evolution). The tree's START goes back to the globe: the globe is
## the loop. A plain rampage with no globe is Endless only.
## The demo (D-050, data/tuning.json "demo") offers its species only. Buying its final upgrade (the
## whole tree) shows the thanks screen and unlocks Endless mode (Endless, D-156), started from the
## thanks screen or the tree; normal mode stays replayable.
## Owns the save state; screens get what they need through setup() and report back by signal.
## Progress comes only from playing: nothing accrues while the game is closed.

const GLOBE_SCENE := "res://scenes/globe_view.tscn"

var _screen: Node
var _save: Dictionary = {}
var _tree: UpgradeTree
## Whether the rampage on show is Endless mode (it banks nothing: normal mode sets the balance).
var _endless := false


func _ready() -> void:
	# A worker task started ahead of its use (WorkerWait) still running as the process quits
	# aborts the exit (exit 134); the game waits for them as it leaves.
	var exiting := get_tree().root.tree_exiting
	if not exiting.is_connected(WorkerWait.wait_all):
		exiting.connect(WorkerWait.wait_all, CONNECT_ONE_SHOT)
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
	var latest := SaveFile.latest_slot(_continues)
	title.setup(_summary(SaveFile.load_game(latest)), _slots(), latest)
	title.continue_pressed.connect(_continue_slot)
	title.new_game_pressed.connect(_new_game)
	title.delete_pressed.connect(func(n: int) -> void: _delete_slot(title, n))
	_swap(title)


## What each save slot holds, for the title's slot list (SlotList.slots).
func _slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: int in range(1, SaveFile.slot_count() + 1):
		var save := SaveFile.load_game(n)
		# A file that cannot be read (corrupt, newer) is still taken: never shown as EMPTY.
		var info := {
			"slot": n,
			"taken": FileAccess.file_exists(SaveFile.path(n)),
			"readable": not save.is_empty(),
		}
		if not save.is_empty():
			info["continues"] = Demo.continues(save)
			info["specimen"] = SaveFile.specimen_name(save)
			info["summary"] = _summary(save)
			info["species"] = str(GameData.species_def(str(save.get("species", "")))["name"])
		out.append(info)
	return out


## What Continue resumes, e.g. "Reptilian, 3 rampages, 120 biomass"; "" with no save (or a
## save of a species the demo leaves out).
func _summary(save: Dictionary) -> String:
	if not Demo.continues(save):
		return ""
	var runs := Num.i(save.get("runs", 0))
	var line := tr("%s, %d rampage, %d biomass") if runs == 1 else tr("%s, %d rampages, %d biomass")
	var who := tr(str(GameData.species_def(str(save.get("species", "")))["name"]))
	return line % [who, runs, Num.i(save.get("rubble", 0))]


## DELETE confirmed on slot `n`: the file goes, the slot list shows it empty.
func _delete_slot(title: TitleScreen, n: int) -> void:
	SaveFile.delete_save(n)
	var latest := SaveFile.latest_slot(_continues)
	var list := title.slot_list()
	var mode := list.mode if list != null else SlotList.Mode.CONTINUE
	title.refresh(_summary(SaveFile.load_game(latest)), _slots(), latest, mode)


## Whether this build can continue `save` (Demo.continues, as a Callable for SaveFile).
func _continues(save: Dictionary) -> bool:
	return Demo.continues(save)


## Continue on slot `n`: its save is the one in play.
func _continue_slot(n: int) -> void:
	SaveFile.slot = n
	_save = SaveSystem.load_game()
	_continue()


## New Kaiju in slot `n`: Kaiju Creation (D-207), the lab where the player picks a genome and
## makes the titan; its rack reads which titans the slot's save has unlocked. Nothing is saved
## (the slot's old kaiju stays) until it is done.
func _new_game(n: int) -> void:
	SaveFile.slot = n
	_save = SaveSystem.load_game()
	var lab := KaijuCreation.new()
	lab.setup(_save)
	lab.created.connect(_on_species_chosen)
	lab.back_pressed.connect(_show_title)
	_swap(lab)


func _on_species_chosen(species_id: String) -> void:
	_save = SaveFile.new_save(species_id, SaveFile.fresh_seed())
	_save["demo"] = Demo.enabled()  # a demo save never continues in the full game (D-145)
	SaveSystem.save_game(_save)
	_continue()


func _continue() -> void:
	if not _save.has("seed"):  # a save from before saves had a city seed draws its own now
		_save["seed"] = SaveFile.fresh_seed()
		SaveSystem.save_game(_save)
	_build_tree()
	_show_globe()


## The evolution tree from the save's levels and the conquest bonuses it holds (plan row F4).
func _build_tree() -> void:
	var levels: Dictionary = _save.get("levels", {})
	var picked: Dictionary = _save.get("bonuses", {})
	_tree = UpgradeTree.new(GameData.upgrades, levels, str(_save.get("species", "")), picked)


## The globe, where a game goes from the title and from Kaiju Creation (D-462): the player picks a
## continent and plays its city. A city's WIN or LOSE lands on the tree (_on_globe_returned).
func _show_globe() -> void:
	var globe := (load(GLOBE_SCENE) as PackedScene).instantiate() as GlobeView
	_swap(globe)
	globe.host(_save)
	globe.returned().connect(_on_globe_returned.bind(globe), CONNECT_DEFERRED)


## A globe mission is over, won or lost (D-462): the globe's save (the conquest and the bonus
## kept, on a WIN) is the game's now, and the player lands on the tree.
func _on_globe_returned(_won: bool, globe: GlobeView) -> void:
	_save = globe.save()
	SaveSystem.save_game(_save)
	_build_tree()
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
	if SaveFile.take_lab_card(_save):  # it died last time: the lab card, then the new specimen
		SaveSystem.save_game(_save)
		var card := SpecimenCard.new(Num.i(_save.get("specimen", 1)))
		card.done.connect(_start_rampage.bind(endless))
		_swap(card)
		return
	var stats := UpgradeTree.run_stats(_base_stats(), _species(), _tree)
	var tier := Num.i(stats["size"])
	var runs := Num.i(_save.get("runs", 0))
	# The run's city (CitySeed): the slot's own seed and the run index, planned on the rampage's
	# worker behind its loading screen (Rampage.setup_later).
	var layout := CitySeed.layout.bind(Content.tuning(), tier, Num.i(_save.get("seed", 0)), runs)
	_endless = endless
	var rampage := Rampage.new()
	rampage.staged = true  # built over several frames behind a loading screen (b2-30)
	rampage.endless = endless  # the demo's Endless mode (D-156)
	rampage.setup_later(_species(), stats, layout, runs)
	RunStart.prepare(_save, rampage)  # the clock so far, time of day and weather (D-145, D-155)
	SaveSystem.save_game(_save)
	RunStart.intro(_save, rampage, tier)  # saved with the run's result
	rampage.finished.connect(_on_rampage_finished)
	_swap(rampage)


## Banks the rampage, then shows the results over the wrecked city, against the best before it.
## Every death (killed, time's up, End rampage; SaveFile.DEATHS) makes the next rise a new
## specimen, Endless included.
## An Endless run banks nothing; a demo rampage adds to the thanks screen's totals (Demo.add).
func _on_rampage_finished(result: Dictionary) -> void:
	var previous := SaveFile.bank(_save, result, _endless)
	SaveSystem.save_game(_save)
	var results := ResultsScreen.new(result, previous)
	if _endless:
		results.go_label = tr("BACK  >")
	results.continued.connect(_show_tree)
	_screen.add_child(results)


func _show_tree() -> void:
	var screen := UpgradeScreen.new()
	screen.setup(_tree, Num.i(_save.get("rubble", 0)), _species(), _base_stats())
	screen.bought.connect(func(id: String) -> void: _on_bought(screen, id))
	screen.start_pressed.connect(_show_globe)  # the globe is the loop (D-462)
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
	var picked: Dictionary = _save.get("bonuses", {})
	var before_tree := UpgradeTree.new(
		GameData.upgrades, before_levels, str(_save["species"]), picked
	)
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
