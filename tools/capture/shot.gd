extends SceneTree
## One general still tool: a seeded rampage, stills at chosen seconds, any camera, any feature off,
## any tuning value changed, so a bug is isolated in one run instead of a new one-off script.
## Grew out of the bay sessions' capture_bay.gd (2026-11-01).
##   bash C:/kt/gpu_slot.sh godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/shot.gd -- --still-at=8,12 --out=C:/kt/shots --tag=base
## Flags (all optional):
##   --species=reptilian  --stage=0..3 (0 baby, else Kit.STAGE_LEVELS[stage-1])  --run=0 (city/army seed)
##   --time=day|dusk|night  --still-at=8,12 (seconds)  --out=dir  --tag=name (file prefix)
##   --cam=x,y,z --at=x,y,z   a fixed camera there looking at that point (else the game camera)
##   --walk=x,z               the kaiju walks to that ground point (else autoplay)
##   --tune=sec.key.sub=v     a tuning value, before the city is built; repeat the flag for more
##   --off=a,b                switch off: fog volfog ssao ssil glow adjust postfx crease ocean sim
##                            (ocean/sim: the water shader's FFT swell / liquid heights)
## Each still prints its path and the camera, so a shot can be framed again exactly.

const Kit := preload("res://tools/capture/capture_kit.gd")
const OFF_AT_FRAME := 5  # the water's own binds run deferred in the first frames

var _species := ""
var _stage := 0
var _run_seed := 0
var _time := ""
var _still_at := ""
var _out := ""
var _tag := ""
var _cam := ""
var _at := ""
var _off := ""
var _walk := Vector2.INF


func _initialize() -> void:
	if not NativeGuard.ok(self):
		return
	var o := Kit.args({
		"species": "reptilian", "stage": 0, "run": 0, "time": "day", "still-at": "8",
		"out": "user://shots", "tag": "shot", "cam": "", "at": "0,0,0", "walk": "", "off": "",
	})
	_species = str(o["species"])
	_stage = str(o["stage"]).to_int()
	_run_seed = str(o["run"]).to_int()
	_time = str(o["time"])
	_still_at = str(o["still-at"])
	_out = str(o["out"])
	_tag = str(o["tag"])
	_cam = str(o["cam"])
	_at = str(o["at"])
	_off = str(o["off"])
	var walk := str(o["walk"])
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tune="):
			_tune(arg.substr(7))
	if walk != "":
		var w := _floats(walk)
		_walk = Vector2(w[0], w[1])
	if not Kit.window_ok():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	Content.set_time(_time)
	var levels: Dictionary = {}
	if _stage > 0:
		levels = Kit.STAGE_LEVELS[mini(_stage, Kit.STAGE_LEVELS.size()) - 1]
	var rampage := Kit.autoplay(self, _species, Kit.stats(_species, levels), _run_seed)
	if _walk != Vector2.INF:
		rampage.scripted = _walk_to
	if _cam != "":
		var c := _floats(_cam)
		var a := _floats(_at)
		var cam := Kit.camera(rampage)
		cam.position = Vector3(c[0], c[1], c[2])
		cam.look_at(Vector3(a[0], a[1], a[2]))
		cam.current = true
	var stills: Array[int] = []
	for at: float in _floats(_still_at):
		stills.append(roundi(at * 60.0))
	var last: int = stills.max()
	var frames := 0
	while frames <= last and not rampage.sim.over:
		await physics_frame
		frames += 1
		if frames == OFF_AT_FRAME:
			_switch_off(_off.split(",", false))
		if frames in stills:
			var path := Kit.still(self, _out, "%s_%.1fs" % [_tag, frames / 60.0])
			var cam := root.get_camera_3d()
			print("shot: saved %s cam %s fov %.2f" % [path, cam.global_transform, cam.fov])
	if rampage.sim.over and frames <= last:
		printerr("shot: the rampage ended at %.1f s, before the last still" % (frames / 60.0))
	quit()


## "a.b.c=v": sets tuning section a, key path b.c, to the number v.
func _tune(spec: String) -> void:
	var tv := spec.split("=")
	var path := tv[0].split(".")
	var table: Dictionary = Content.section(path[0])
	for i: int in range(1, path.size() - 1):
		table = table[path[i]]
	table[path[path.size() - 1]] = tv[1].to_float()
	print("shot: tune %s = %s" % [tv[0], tv[1]])


func _switch_off(names: PackedStringArray) -> void:
	if names.is_empty():
		return
	var env: Environment = null
	for node: Node in root.find_children("*", "WorldEnvironment", true, false):
		env = (node as WorldEnvironment).environment
	for name: String in names:
		match name:
			"fog":
				env.fog_enabled = false
			"volfog":
				env.volumetric_fog_enabled = false
			"ssao":
				env.ssao_enabled = false
			"ssil":
				env.ssil_enabled = false
			"glow":
				env.glow_enabled = false
			"adjust":
				env.adjustment_enabled = false
			"postfx":
				PostFx.enabled = false
			"crease":
				for node: Node in root.find_children("*", "CreasePass", true, false):
					(node as Node3D).visible = false
			"ocean", "sim":
				_water_param("ocean_on" if name == "ocean" else "sim_on", 0.0)
			_:
				printerr("shot: unknown --off name ", name)
	print("shot: off ", names)


func _water_param(key: String, value: float) -> void:
	for node: Node in get_nodes_in_group(WaterSurface.GROUP):
		var mi := node as MeshInstance3D
		if mi == null:
			continue
		var mat := mi.material_override as ShaderMaterial
		if mat == null and mi.mesh != null:
			mat = mi.mesh.surface_get_material(0) as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter(key, value)


func _walk_to(sim: RampageSim) -> Dictionary:
	var to := _walk - sim.kaiju_pos
	return {"move": to.normalized() if to.length() > 0.5 else Vector2.ZERO}


static func _floats(s: String) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for part: String in s.split(",", false):
		out.append(part.to_float())
	return out
