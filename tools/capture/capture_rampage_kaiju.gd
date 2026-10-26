extends SceneTree
## Records a real autoplayed rampage (the flow test's city and seed) for one species, so its
## locomotion is seen among buildings: the cephalopod gripping building edges, every species
## stomping and turning at the gameplay camera. Needs a window and --write-movie.
##
##   godot --path . --resolution 1920x1080 --windowed --write-movie <out.avi> --fixed-fps 60 \
##     --script tools/capture/capture_rampage_kaiju.gd -- --species=cephalopod --seconds=12
##
## --time=dusk|night|morning|noon sets the time of day (default: the game's). --train-still=<dir>
## (no --write-movie) saves <dir>/train.png at the game camera, HUD hidden, on the first frame a
## running train's middle car is in the middle of the screen within --near-rail metres of the
## kaiju, then quits (debt row 25: the train's surface in the real game); exit 1 if none came into
## view within --seconds. --near-rail=<m> (with --train-still) walks the kaiju, instead of the
## autoplay, to m metres from the railway at its own z and stands there, so trains pass it unhidden.

const Kit := preload("res://tools/capture/capture_kit.gd")
## The middle share of the screen (each axis) the train's middle car must be in for the still.
const TRAIN_FRAME := 0.6

var _species := "cephalopod"
var _seconds := 12.0
var _time := ""
var _train_still := ""
var _near_rail := 0.0


func _initialize() -> void:
	var defaults := {
		"species": _species,
		"seconds": _seconds,
		"time": _time,
		"train-still": _train_still,
		"near-rail": _near_rail,
	}
	var a := Kit.args(defaults)
	_species = str(a["species"])
	_seconds = Num.f(a["seconds"])
	_time = str(a["time"])
	_train_still = str(a["train-still"])
	_near_rail = Num.f(a["near-rail"])
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if _time != "":
		Content.set_time(_time)
	var rampage := Kit.autoplay(self, _species, Kit.stats(_species), 0)
	if _near_rail > 0.0:
		rampage.scripted = _to_rail
	var frames := 0
	while frames < int(_seconds * 60.0) and not rampage.sim.over:
		await physics_frame
		frames += 1
		if _train_still != "" and _train_in_view(rampage):
			await _save_train(rampage)
			quit()
			return
	quit(1 if _train_still != "" else 0)


## The scripted input that walks the kaiju to _near_rail metres from the railway and stands.
func _to_rail(sim: RampageSim) -> Dictionary:
	var track := sim.rail.track_x(1)
	var side := signf(sim.kaiju_pos.x - track) if sim.kaiju_pos.x != track else 1.0
	var to := Vector2(track + side * _near_rail, sim.kaiju_pos.y) - sim.kaiju_pos
	return {"move": to.normalized() if to.length() > 0.5 else Vector2.ZERO}


## True when a running train's middle car is in front of the game camera, inside the middle
## TRAIN_FRAME of the screen (and, with --near-rail, within 4x that of the kaiju).
func _train_in_view(rampage: Rampage) -> bool:
	var cam := Kit.game_camera(self)
	if cam == null:
		return false
	var size := root.get_visible_rect().size
	for train: Rail.Train in rampage.sim.rail.trains:
		if train.state == Rail.WRECK:
			continue
		var car: Rail.Car = train.cars[floori(train.cars.size() / 2.0)]
		var at := Vector3(car.pos.x, car.y + RailView.FLOOR, car.pos.y)
		var near := car.pos.distance_to(rampage.sim.kaiju_pos) < _near_rail * 4.0
		if cam.is_position_behind(at) or (_near_rail > 0.0 and not near):
			continue
		var p := cam.unproject_position(at) / size
		var lo := (1.0 - TRAIN_FRAME) * 0.5
		if p.x > lo and p.x < 1.0 - lo and p.y > lo and p.y < 1.0 - lo:
			print("train %d middle car at screen %.2f, %.2f" % [train.id, p.x, p.y])
			return true
	return false


func _save_train(rampage: Rampage) -> void:
	var hud: RampageHud = rampage.get("_hud")
	if hud != null:
		hud.visible = false
	await Kit.frames(self, 2)
	DirAccess.make_dir_recursive_absolute(_train_still)
	print("saved ", Kit.still(self, _train_still, "train"), " at sim ", rampage.sim.elapsed, " s")
