class_name GlobeMissions
extends CanvasLayer
## The globe's mission flow (Overworld plan row G5), on a layer above the markers: a picked
## continent shows its MissionPanel; LAUNCH opens the StubMission, the globe ignoring the pointer
## meanwhile. A win stores the conquest in the save (Campaign.conquer; written back when there is
## a save on disk), the continents take their new states and the camera flies back out; a loss
## returns to the panel with nothing changed.

const LAYER := 2  # over the markers' layer (1)

var panel: MissionPanel
var mission: StubMission

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
	mission.start(Content.continent(id))


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
