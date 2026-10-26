extends SceneTree
## Captures the Lightning Breath and the Thunder Beam (b2-18, VFX_STYLE family 6) in a real rampage:
## stills at the game camera mid-stroke (and from the side), or with --clip the breath and then the
## ultimate for one ~6 s movie. The same run and bolt seed give the same frame, so --halo=amber|eye|
## violet shows the director's three halo options (R 17.6) from one frame. Needs a window (no
## --headless) and the no-focus off-screen override.cfg. Pair with --write-movie for the clip.
##
##   godot --path . --resolution 3840x2160 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_bolt.gd -- --out=<dir> --mode=breath --run=1 --halo=amber
## --mode=breath|beam|clip; --run=1 night, 3 noon (Content.times() order); --side: from the kaiju's
## right, level with its chest; --young: the baby-stage build (no first evolution).

const Kit := preload("res://tools/capture/capture_kit.gd")
const SETTLE := 120
## The physics step the bolt is fired on (the kaiju is out of the river by then).
const FIRE_AT := 125
## The clip waits this many steps first (the camera pulls in from far, with the city's fade panels).
const CLIP_SETTLE := 240
## The clip's ultimate comes this many steps after its breath.
const CLIP_GAP := 110
## Frames after the fire at which a breath / a beam is shot (the first stroke is at about 7).
const BREATH_SHOTS: Array[int] = [9, 20, 32]
const BEAM_SHOTS: Array[int] = [10, 40, 80, 150]
const CLIP_FRAMES := 380
const SIDE_DISTANCE := 40.0
const SIDE_HEIGHT := 14.0
const CROP := Vector2i(1280, 720)
const LEVELS := {"claws": 3, "hide": 1, "evolve1": 1, "sig_power": 2, "r_beam": 1}

var _out := "user://bolt"
var _mode := "breath"
var _run := 1
var _halo := ""
var _side := false
var _young := false
var _debug := false
var _shots := ""
var _step := 0
var _fire_breath := -1
var _fire_beam := -1
var _walk := AutoWalk.new()
var _cam: Camera3D


func _initialize() -> void:
	var a := (
		Kit
		. args(
			{
				"out": _out,
				"mode": _mode,
				"run": _run,
				"halo": _halo,
				"side": false,
				"young": false,
				"min_px": -1.0,
				"debug": false,
				"shots": "",
			}
		)
	)
	_out = str(a["out"])
	_mode = str(a["mode"])
	_run = a["run"]
	_halo = str(a["halo"])
	_side = a["side"]
	_young = a["young"]
	_debug = a["debug"]
	_shots = str(a["shots"])
	if _halo == "debug":  # a pure green halo: proves which frame pixels are the bolt
		var modes: Dictionary = Content.section("fx")["bolt"]["halo_modes"]
		modes["debug"] = {"inner": "00ff00", "fringe": "00ff00"}
	if Num.f(a["min_px"]) >= 0.0:  # try a different least width without editing the tuning
		var bolt: Dictionary = Content.section("fx")["bolt"]
		bolt["core_min_px"] = a["min_px"]
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_go.call_deferred()


func _go() -> void:
	await process_frame
	BoltView.halo_mode_override = _halo
	var levels := LEVELS.duplicate()
	if _young:
		levels.erase("evolve1")
	var rampage := Kit.rampage("reptilian", Kit.stats("reptilian", levels, "reptilian"), _run)
	rampage.scripted = _scripted_input
	root.add_child(rampage)
	var settle := CLIP_SETTLE if _mode == "clip" else SETTLE
	var fire := FIRE_AT + settle - SETTLE
	_fire_breath = fire if _mode != "beam" else -1
	_fire_beam = fire if _mode == "beam" else (fire + CLIP_GAP if _mode == "clip" else -1)
	await Kit.ticks(self, settle)
	if _mode == "clip":
		await Kit.frames(self, CLIP_FRAMES)
	else:
		await _stills(rampage)
	rampage.queue_free()
	await Kit.frames(self, 2)
	quit()


## Stills a set number of frames after the fire.
func _stills(rampage: Rampage) -> void:
	var shots := BEAM_SHOTS if _mode == "beam" else BREATH_SHOTS
	if _shots != "":  # --shots=1,2,3: other frames after the fire (the onset)
		shots = []
		for text: String in _shots.split(","):
			shots.append(text.to_int())
	var played := rampage.ability_fx.played if _mode != "beam" else rampage._powers.played
	var event := "breath" if _mode != "beam" else "beam_start"
	while not played.has(event):  # waits for the press to land (the kaiju out of the river)
		await physics_frame
	if _mode == "beam":  # the breath's wedge is hidden while it recharges in a real fire frame
		var aim := rampage.find_child("BreathAim", false, false) as BreathAim
		aim.set_physics_process(false)
		aim.visible = false
	if _side:  # placed where the kaiju stands at the fire, so the whole bolt is in frame
		_side_camera(rampage)
	var waited := 0
	for after: int in shots:
		await Kit.frames(self, after - waited)
		waited = after
		var halo := _halo if _halo != "" else "default"
		var shot_name := (
			"%s_run%d_%s%s_f%03d" % [_mode, _run, halo, "_side" if _side else "", after]
		)
		var path := Kit.still(self, _out, shot_name)
		_print_points(rampage, shot_name)
		if _debug:
			_print_rig(rampage)
		_crop(rampage, path)


## The 2x crop round the bolt, 12 m ahead of the kaiju and a few up.
func _crop(rampage: Rampage, path: String) -> void:
	var cam := root.get_viewport().get_camera_3d()
	var sim := rampage.sim
	var at := Vector3(sim.kaiju_pos.x, 3.0, sim.kaiju_pos.y)
	at += Vector3(sim.facing.x, 0.0, sim.facing.y) * 12.0 * sim.body_scale()
	var shot := Image.load_from_file(path)
	var centre := Kit.image_point(self, cam, at, Vector2(shot.get_size()))
	Kit.crop_2x(shot, centre, CROP, path.replace(".png", "_2x.png"))


func _scripted_input(sim: RampageSim) -> Dictionary:
	_step += 1
	return {
		"move": _walk.move(sim, _step),
		"signature": _fire_breath >= 0 and _step >= _fire_breath and sim.ability_ready_in <= 0.0,
		"held": false,
		"ultimate": _fire_beam >= 0 and _step >= _fire_beam,
	}


func _side_camera(rampage: Rampage) -> void:
	_cam = Camera3D.new()
	rampage.add_child(_cam)
	var at := Vector3(rampage.sim.kaiju_pos.x, 0.0, rampage.sim.kaiju_pos.y)
	var facing := Vector3(rampage.sim.facing.x, 0.0, rampage.sim.facing.y)
	var right := Vector3(-facing.z, 0.0, facing.x)
	var bs := rampage.sim.body_scale()
	_cam.position = at + right * SIDE_DISTANCE * bs + Vector3(0, SIDE_HEIGHT * bs, 0)
	_cam.look_at(at + facing * 10.0 * bs + Vector3.UP * 3.0 * bs)
	_cam.current = true


func _print_rig(rampage: Rampage) -> void:
	var rig: BoltRig = (
		rampage.ability_fx._beam.rig if _mode != "beam" else rampage._powers._thunder.rig
	)
	var view: BoltView = rig._view
	print(
		(
			"rig live=%s index=%d rings=%d mouth=%s hit=%s surfaces=%d aabb=%s vis=%s"
			% [
				rig.live,
				rig._index,
				rig._thrown.rings,
				rig._mouth,
				rig._hit,
				view.mesh.get_surface_count(),
				view.get_aabb(),
				view.is_visible_in_tree()
			]
		)
	)
	for mat: ShaderMaterial in view.all_materials():
		print(
			(
				"mat width=%s min_px=%s level=%s boost=%s scale=%s"
				% [
					mat.get_shader_parameter("width"),
					mat.get_shader_parameter("min_px"),
					mat.get_shader_parameter("level"),
					mat.get_shader_parameter("boost"),
					rig._scale,
				]
			)
		)
	var cam := root.get_viewport().get_camera_3d()
	print(
		(
			"cam fov=%s size=%s view_scale=%s"
			% [cam.fov, root.get_visible_rect().size, view.global_transform]
		)
	)


## The mouth, the struck point and the drawn polylines in the still (pixels), for measure_bolt.py.
func _print_points(rampage: Rampage, shot_name: String) -> void:
	var rig: BoltRig = (
		rampage.ability_fx._beam.rig if _mode != "beam" else rampage._powers._thunder.rig
	)
	var cam := root.get_viewport().get_camera_3d()
	var size := Vector2(root.get_texture().get_image().get_size())
	var mouth := Kit.image_point(self, cam, rig._mouth, size)
	var hit := Kit.image_point(self, cam, rig._hit, size)
	print("POINTS %s mouth=%d,%d hit=%d,%d live=%s" % [shot_name, mouth.x, mouth.y, hit.x, hit.y, rig.live])
	var lashes := 0  # branches that end up the wall above the struck point
	for line: PackedVector3Array in rig.drawn_lines:
		if line.size() > 1 and line[line.size() - 1].y > rig._hit.y + 1.0:
			lashes += 1
	print("LASHES %s %d" % [shot_name, lashes])
	var lines: Array[PackedVector3Array] = [rig.drawn_main]
	lines.append_array(rig.drawn_lines)
	for i: int in lines.size():
		var text := ""
		for p: Vector3 in lines[i]:
			var at := Kit.image_point(self, cam, p, size)
			text += " %d,%d" % [at.x, at.y]
		print("POLY %s %s%s" % [shot_name, "main" if i == 0 else "branch", text])
