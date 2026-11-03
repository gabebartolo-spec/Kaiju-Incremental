class_name GlobeMissions
extends CanvasLayer
## The globe's mission flow (Overworld plan row G5), on a layer above the markers: a picked
## continent shows its MissionPanel; LAUNCH starts its real city where one exists (D-454: Ostia
## Minor, Carthago, Thule; Campaign.real_city) at the continent's stage, the save's kaiju sent in
## and the globe hidden; when that rampage is over the globe comes back on the StubMission's WIN /
## LOSE (no rule yet says what wins a city). Other continents open the StubMission at once. The
## globe ignores the pointer meanwhile. A win stores the conquest in the save (Campaign.conquer;
## written back when there is a save on disk), the continents take their new states and the camera
## flies back out; a loss returns to the panel with nothing changed.

const LAYER := 2  # over the markers' layer (1)

var panel: MissionPanel
var mission: StubMission

## The real city's rampage under way (null when none).
var city: Rampage

var _globe: GlobeView
## The save the globe reads and writes (SaveFile's slot when it opened).
var _save := {}


func _init(globe: GlobeView) -> void:
	_globe = globe
	layer = LAYER
	_save = SaveFile.load_game()
	panel = MissionPanel.new()
	add_child(panel)
	mission = StubMission.new()
	add_child(mission)
	panel.launched.connect(_launch)
	mission.won.connect(_won)
	mission.lost.connect(_end)


func save() -> Dictionary:
	return _save


## Each continent's Campaign.State from the save.
func states() -> Dictionary:
	var conquered: Array = _save.get("conquered", [])
	return Campaign.states(Content.continents(), conquered)


func _launch(id: String) -> void:
	_globe.set_process_unhandled_input(false)
	var def := Content.continent(id)
	if Campaign.real_city(def):
		_start_city(def)
	else:
		mission.start(def)


## The continent's city at its stage, with the save's kaiju and upgrades (as Main starts a run,
## CitySeed planning the slot's own city on the rampage's worker behind its loading screen).
func _start_city(def: Dictionary) -> void:
	var species := Content.species_def(str(_save.get("species", "")))
	var levels: Dictionary = _save.get("levels", {})
	var picked: Dictionary = _save.get("bonuses", {})
	var tree := UpgradeTree.new(Content.upgrades(), levels, str(species["id"]), picked)
	var base := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var stats := Campaign.city_stats(base, def)
	var runs := Num.i(_save.get("runs", 0))
	var seed := Num.i(_save.get("seed", 0))
	var tier := Num.i(stats["size"])
	var plan := CitySeed.layout.bind(Content.tuning(), tier, seed, runs, str(def["id"]))
	city = Rampage.new()
	city.staged = true
	city.setup_later(species, stats, plan, runs)
	city.finished.connect(_city_over.bind(def), CONNECT_DEFERRED)
	panel.visible = false
	_globe.set_shown(false)
	PlayerSettings.in_play = true
	_globe.add_sibling(city)


## The rampage is over: the globe comes back and the mission resolves on WIN / LOSE as the
## stand-in did, until a rule says what wins a city.
func _city_over(_result: Dictionary, def: Dictionary) -> void:
	if city != null:
		city.queue_free()
		city = null
	PlayerSettings.in_play = false
	_globe.set_shown(true)
	panel.visible = true
	mission.start(def, tr("The rampage is over"))


func _won(id: String, bonus_id: String) -> void:
	_save = Campaign.conquer(_save, Content.continent(id), bonus_id)
	if SaveFile.has_save():
		SaveFile.save_game(_save)
	_globe.set_states(states())
	_end(id)
	_globe.fly_out()


func _end(_id: String) -> void:
	mission.visible = false
	_globe.set_process_unhandled_input(true)
