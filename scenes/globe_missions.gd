class_name GlobeMissions
extends CanvasLayer
## The globe's mission flow (Overworld plan row G5), on a layer above the markers: a picked
## continent shows its MissionPanel; LAUNCH starts its real city where one exists (D-454: Ostia
## Minor, Carthago, Thule; Campaign.real_city) at the continent's stage, the save's kaiju sent in
## and the globe hidden; when that rampage is over the globe comes back on the StubMission's WIN /
## LOSE (no rule yet says what wins a city). The city starts as any run does (RunStart: the lab
## card after a death, the clock, time of day, weather, the intro) and its end is banked as any
## rampage's (SaveFile.bank: biomass, runs, bests, specimen), its results shown over the wrecked
## city before WIN / LOSE. Other continents open the StubMission at once. The globe ignores the
## pointer meanwhile. A win stores the conquest in the save (Campaign.conquer), the continents take
## their new states and the camera flies back out; a loss returns to the panel with nothing changed.
## The global Threat Level (D-422, Campaign.conquer) reads in the top-left corner while the globe
## is up (look, place and wording are placeholders until the director rules).
## One save: a host hands its own in (host()) and hears every write (saved); run alone, the globe
## reads the slot's and writes it back when there is a save on disk.

## Every write of the save (the host keeps its copy in step: Campaign.conquer returns a new one).
signal saved(save: Dictionary)

const LAYER := 2  # over the markers' layer (1)

var panel: MissionPanel
var mission: StubMission
## The global Threat Level readout (D-422).
var threat_label: Label

## The real city's rampage under way (null when none).
var city: Rampage
## The lab card before the city, after a death (null when none; SaveFile.take_lab_card).
var card: SpecimenCard
## The real city's results over the wrecked city (null when none).
var results: ResultsScreen

var _globe: GlobeView
## The save the globe reads and writes (SaveFile's slot when it opened, or the host's).
var _save := {}
## Whether writes reach the slot's file (a save on disk when it opened, or a host's save).
var _persist := false


func _init(globe: GlobeView) -> void:
	_globe = globe
	layer = LAYER
	_save = SaveFile.load_game()
	_persist = SaveFile.has_save()
	panel = MissionPanel.new()
	add_child(panel)
	mission = StubMission.new()
	add_child(mission)
	threat_label = UiKit.label("", UiKit.SIZE_HEAD, UiKit.ALERT)
	threat_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	threat_label.position = UiKit.safe_margin()
	add_child(threat_label)
	_show_threat()
	panel.launched.connect(_launch)
	mission.won.connect(_won)
	mission.lost.connect(_end)


func save() -> Dictionary:
	return _save


## Plays on from this save instead of the slot's (tests and proofs; nothing written to disk).
func use_save(save_in: Dictionary) -> void:
	_save = save_in
	_persist = false
	_globe.set_states(states())
	_show_threat()


## Plays on the host's save (the game's, on the slot in play): every write goes to the slot and
## out on saved, so the host and the globe never hold two different saves.
func host(save_in: Dictionary) -> void:
	use_save(save_in)
	_persist = true


func _write() -> void:
	if _persist:
		SaveFile.save_game(_save)
	saved.emit(_save)


## The readout shows the save's Threat Level, a whole percent.
func _show_threat() -> void:
	threat_label.text = tr("Threat %d%%") % roundi(Num.f(_save.get("threat", 0.0)))


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


## The continent's city at its stage, with the save's kaiju and upgrades, started as Main starts a
## run (CitySeed planning the slot's own city on the rampage's worker behind its loading screen;
## RunStart). A death last time shows the lab card first.
func _start_city(def: Dictionary) -> void:
	panel.visible = false
	threat_label.visible = false
	_globe.set_shown(false)
	if SaveFile.take_lab_card(_save):  # it died last time: the lab card, then the new specimen
		_write()
		card = SpecimenCard.new(Num.i(_save.get("specimen", 1)))
		card.done.connect(_after_card.bind(def), CONNECT_DEFERRED)
		add_child(card)
		return
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
	RunStart.prepare(_save, city)
	_write()
	RunStart.intro(_save, city, tier)  # saved with the city's result
	city.finished.connect(_city_over.bind(def), CONNECT_DEFERRED)
	PlayerSettings.in_play = true
	_globe.add_sibling(city)


## The lab card read: on into the city.
func _after_card(def: Dictionary) -> void:
	if card != null:
		card.queue_free()
		card = null
	_start_city(def)


## The rampage is over: banked as any rampage and its results shown over the wrecked city; then
## the globe comes back and the mission resolves on WIN / LOSE as the stand-in did, until a rule
## says what wins a city.
func _city_over(result: Dictionary, def: Dictionary) -> void:
	var previous := SaveFile.bank(_save, result, false)
	_write()
	PlayerSettings.in_play = false
	results = ResultsScreen.new(result, previous)
	results.go_label = tr("BACK  >")  # placeholder wording: back to the globe
	results.continued.connect(_back_to_globe.bind(def), CONNECT_DEFERRED)
	if city != null:
		city.add_child(results)
	else:
		add_child(results)


## The results read: the city goes, the globe comes back on the mission's WIN / LOSE.
func _back_to_globe(def: Dictionary) -> void:
	if results != null:
		results.queue_free()
		results = null
	if city != null:
		city.queue_free()
		city = null
	_globe.set_shown(true)
	panel.visible = true
	threat_label.visible = true
	mission.start(def, tr("The rampage is over"))


func _won(id: String, bonus_id: String) -> void:
	_save = Campaign.conquer(_save, Content.continent(id), bonus_id)
	_write()
	_globe.set_states(states())
	_show_threat()
	_end(id)
	_globe.fly_out()


func _end(_id: String) -> void:
	mission.visible = false
	_globe.set_process_unhandled_input(true)
