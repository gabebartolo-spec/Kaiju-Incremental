extends SceneTree
## Measures the city's sound over one seeded, autoplayed rampage (CitySound, D-155): plays the real
## game scene with the real mixer and prints, once a second, the RMS in dBFS that each bed puts out,
## so "panic peaks early, then eerie quiet" is read off audio, not off the curve. Each bed is
## measured on its own bus with an AudioEffectCapture: the crowd on "Crowd"; the siren, gunfire,
## fire and wind loops on a probe bus each (sent on to "Bed", so Hero still ducks them as in play);
## the whole mix on Master. Run it with --write-movie so the mixer runs on the frame clock, not
## the wall clock. A headless --write-movie crashes (no frame to read), so it is a windowed run,
## only with the untracked no_focus override.cfg in the project folder (off-screen, never takes
## focus), deleted afterwards:
##
##   godot --windowed --resolution 640x360 --fixed-fps 60 --path . \
##     --write-movie <dir>/city_sound.avi --script tools/capture/capture_city_sound.gd -- \
##     --secs=60 --stage=1 --out=<dir>/city_sound.csv
##
## CSV rows: second, phase, fled, destroyed share, then the RMS dB of crowd, siren, gunfire, fire,
## wind and master (-120 for silence).

const Kit := preload("res://tools/capture/capture_kit.gd")
const BEDS: Array[String] = ["crowd", "city_siren", "city_gunfire", "city_fire", "city_wind"]
const SILENT := -120.0
const FPS := 60  # the --fixed-fps the run is started with

var _captures: Dictionary = {}  # bed or "master" -> AudioEffectCapture
var _sums: Dictionary = {}
var _frames: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var opts := Kit.args({"secs": 60.0, "stage": 1, "out": "city_sound.csv", "run": 0})
	var levels: Dictionary = Kit.STAGE_LEVELS[clampi(Num.i(opts["stage"]) - 1, 0, 3)]
	var stats := Kit.stats("reptilian", levels, "reptilian")
	var rampage := Kit.rampage("reptilian", stats, Num.i(opts["run"]))
	rampage.set_autoplay(true)
	rampage.sim.air.cfg["max"] = 2
	rampage.sim.time_left = Num.f(opts["secs"]) + 30.0
	root.add_child(rampage)
	await rampage.wait_loaded()
	var sound: CitySound = _find(rampage)
	_tap(sound)
	var file := FileAccess.open(str(opts["out"]), FileAccess.WRITE)
	file.store_line("t,phase,fled,destroyed,crowd,siren,gunfire,fire,wind,master")
	for frame: int in roundi(Num.f(opts["secs"]) * FPS):
		await process_frame
		_drain()
		if (frame + 1) % FPS == 0:
			var street: StreetLife = rampage._city.street
			file.store_line(
				(
					"%d,%.3f,%d,%.4f,%s"
					% [
						(frame + 1) / FPS,
						sound.phase,
						street.fled,
						rampage.sim.destruction(),
						_row()
					]
				)
			)
	file.close()
	quit()


func _find(node: Node) -> CitySound:
	for child: Node in node.get_children():
		if child is CitySound:
			return child
	return null


## Routes each bed's player to its own capture bus and puts a capture on Crowd and Master.
func _tap(sound: CitySound) -> void:
	for bed: String in BEDS:
		var bus := "Crowd"
		if bed != "crowd":
			bus = "Probe_" + bed
			AudioServer.add_bus()
			var at := AudioServer.bus_count - 1
			AudioServer.set_bus_name(at, bus)
			AudioServer.set_bus_send(at, "Bed")
			var player: AudioStreamPlayer = sound._players.get(bed)
			if player == null:  # not imported in this checkout: read the .ogg file itself
				player = _raw_player(sound, bed)
			if player != null:
				player.bus = bus
		_capture(bed, bus)
	_capture("master", "Master")


## A looping player for a bed whose .ogg has no import yet, decoded from the file on disk and
## handed to the driver; null when there is no such file.
func _raw_player(sound: CitySound, bed: String) -> AudioStreamPlayer:
	var path := ProjectSettings.globalize_path("res://assets/sfx/%s.ogg" % bed)
	var loop := AudioStreamOggVorbis.load_from_file(path)
	if loop == null:
		return null
	loop.loop = true
	var player := AudioStreamPlayer.new()
	player.stream = loop
	player.volume_db = Num.f(Content.section("city_sound")["silent_db"])
	sound.add_child(player)
	sound._players[bed] = player
	return player


func _capture(key: String, bus: String) -> void:
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 0.5
	AudioServer.add_bus_effect(AudioServer.get_bus_index(bus), capture)
	_captures[key] = capture
	_sums[key] = 0.0
	_frames[key] = 0


## Reads what each capture has gathered this frame into its running sum of squares.
func _drain() -> void:
	for key: String in _captures:
		var capture: AudioEffectCapture = _captures[key]
		var buffer := capture.get_buffer(capture.get_frames_available())
		var sum := Num.f(_sums[key])
		for v: Vector2 in buffer:
			sum += (v.x * v.x + v.y * v.y) * 0.5
		_sums[key] = sum
		_frames[key] = Num.i(_frames[key]) + buffer.size()


## The RMS in dB of each bed over the second just ended, as CSV, and the sums reset.
func _row() -> String:
	var out: Array[String] = []
	var keys: Array[String] = BEDS.duplicate()
	keys.append("master")
	for key: String in keys:
		var n := maxi(1, Num.i(_frames[key]))
		var rms := sqrt(Num.f(_sums[key]) / n)
		out.append("%.1f" % (20.0 * log(rms) / log(10.0) if rms > 0.0 else SILENT))
		_sums[key] = 0.0
		_frames[key] = 0
	return ",".join(out)
