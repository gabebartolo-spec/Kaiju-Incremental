extends SceneTree
## Stills of every landmark in the Behemoth's city (city.landmarks), from the rampage's own
## camera's angle with the kaiju beside it: standing, then after a short rampage into it (the
## sim breaks the chunks and settles what falls; the city view draws it as in a rampage). Needs
## a window: run it on CI (tools/capture/ci_capture.sh --resolution=1920x1080
## capture_landmarks.gd -- --out=<dir>), or off-screen with the no_focus override.
##
##   godot --path . --resolution 1920x1080 --windowed \
##     --script tools/capture/capture_landmarks.gd -- --out=<dir> [--tier=2]

const Kit := preload("res://tools/capture/capture_kit.gd")
const SETTLE := 4
## Real time to wait for every building to stream in before the standing still.
const STREAM_WAIT_MS := 120000
## Frames after the rampage before the broken still: the dust of the last falls clears.
const AFTER := 150
const SPECIES := "reptilian"
## Upgrades of a typical run on reaching each city stage (stage 2 = after the first evolution).
const LEVELS := [{"claws": 3, "hide": 2}, {"claws": 5, "hide": 5, "rage": 3, "evolve1": 1}]
## Sim time of the rampage into each landmark, and sim steps per drawn frame.
const RAMPAGE_SECONDS := 9.0
const STEPS_PER_FRAME := 3
const DT := 1.0 / 30.0
## Camera distance per unit of the landmark's largest size.
const FRAME := 1.7

var _out := "user://landmarks"
var _sim: RampageSim
var _city: CityView
var _kaiju_at := Vector3.ZERO


func _initialize() -> void:
	_out = str(Kit.args({"out": _out})["out"])
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for tier: int in range(1, LEVELS.size() + 1):
		await _stage(tier)
	quit()


## The city of stage `tier` with that stage's kaiju; shoots each landmark of that tier.
func _stage(tier: int) -> void:
	var species := Content.species_def(SPECIES)
	var levels: Dictionary = LEVELS[tier - 1]
	var stats := Kit.stats(SPECIES, levels, SPECIES)
	_sim = Kit.stage_sim(stats, tier, CityGrowth.tuning_for(Content.tuning(), tier))
	_sim.time_left = 1.0e6
	var stage := Node3D.new()
	_city = CityView.new(_sim, Seeds.make("fx", 0))
	stage.add_child(_city)
	var colors: Dictionary = species["colors"]
	var kaiju := KaijuModel.new(SPECIES, colors, KaijuModel.stage_for(_sim.size_tier()))
	kaiju.scale = Vector3.ONE * _sim.body_scale()
	stage.add_child(kaiju)
	var cam := Kit.camera(stage)
	root.add_child(stage)
	cam.current = true
	for n: int in _sim.buildings.size():
		var b := _sim.buildings[n]
		if b.landmark == "" or b.tier != tier:
			continue
		# South of it, in the plaza by the kerb, facing it, as a player walking up would be.
		_kaiju_at = Vector3(b.x, 0, b.z + b.d * 0.5 + 2.0)
		_sim.kaiju_pos = Vector2(_kaiju_at.x, _kaiju_at.z)
		kaiju.position = _kaiju_at
		# The game camera's angle, centred on the landmark and backed off to frame all of it, so
		# the towers south of the plaza (faded in a rampage) do not hide it.
		var centre := Vector3(b.x, b.height * 0.3, b.z)
		var reach := maxf(maxf(b.w, b.d), b.height) * FRAME
		cam.position = centre + CameraTuning.offset().normalized() * reach
		cam.look_at(centre)
		await _frames(SETTLE)
		var deadline := Time.get_ticks_msec() + STREAM_WAIT_MS
		while not _city._stream.complete() and Time.get_ticks_msec() < deadline:
			await process_frame  # a far landmark stands as a box until it streams in
		_shot("%s_standing" % b.landmark)
		var before := b.frame.alive_count
		await _break(n, kaiju)
		await _frames(AFTER)
		_shot("%s_broken" % b.landmark)
		print(
			(
				"%s: %d of %d chunks standing after the break"
				% [b.landmark, b.frame.alive_count, before]
			)
		)
	root.remove_child(stage)
	stage.free()


## A short rampage into it: the kaiju walks from the kerb toward the landmark's middle, stomping
## as it goes and using its signature whenever it is ready, the sim deciding what breaks and falls
## and the city view drawing every event as in a rampage. Several sim steps per drawn frame keep
## the software-rendered CI run short.
func _break(n: int, kaiju: Node3D) -> void:
	var b := _sim.buildings[n]
	var goal := Vector2(b.x, b.z)
	var t := 0.0
	while t < RAMPAGE_SECONDS:
		for _k: int in STEPS_PER_FRAME:
			var to := goal - _sim.kaiju_pos
			var move := to.normalized() if to.length() > 1.0 else Vector2.ZERO
			_apply(_sim.step(DT, move, _sim.ability_ready_in <= 0.0))
			t += DT
		_kaiju_at = Vector3(_sim.kaiju_pos.x, 0, _sim.kaiju_pos.y)
		kaiju.position = _kaiju_at
		await process_frame


func _apply(events: Array[Dictionary]) -> void:
	Kit.apply(_city, events, _kaiju_at)


func _frames(n: int) -> void:
	await Kit.frames(self, n)


func _shot(shot_name: String) -> void:
	print("saved ", Kit.still(self, _out, shot_name))
