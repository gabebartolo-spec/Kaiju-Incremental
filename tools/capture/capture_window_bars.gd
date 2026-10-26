extends SceneTree
## Dark horizontal bars across lit windows (the director, 2026-10-27: "sometimes the windows have
## flickering horizontal black bars across them, it creates a lot of visual noise"). One tower per
## facade archetype of the stage-2 city at night, seen from the rampage's own camera (framed on a
## kaiju standing `--gap` m east of it, the kaiju hidden), the camera drifting `--step` m per frame
## the way it follows a walking kaiju. For each variant (one suspect switched off, see _apply) it
## renders `--frames` frames through a 4K SubViewport on the player's graphics row (medium: FSR1 at
## 0.75, MSAA 2x, SSAO and SSIL, soft shadows, the far blur on the camera) and saves the building's
## rectangle of each frame as <out>/<variant>/b<N>_a<arch>/f<NNN>.png. tools/capture/window_bars_count.py
## counts the bars in them. Needs a window and the no-focus override.cfg (Kit.window_ok).
##   godot --path . --resolution 1280x720 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_window_bars.gd -- --out=<dir> [--variants=base,noshadow]
##     [--style=-1] [--frames=24] [--step=0.06] [--time=night] [--gfx=medium] [--size=3840x2160]

const Kit := preload("res://tools/capture/capture_kit.gd")
const SPECIES := "reptilian"
const SETTLE_FRAMES := 6

var _opt := {}
var _out := ""
var _size := Vector2i(3840, 2160)
var _sim: RampageSim
var _city: CityView
var _cam: Camera3D
var _kaiju: KaijuModel
var _port: SubViewport
var _eye: Camera3D
var _far: FarDepth
var _sun: DirectionalLight3D
var _env: Environment


func _initialize() -> void:
	_opt = Kit.args(
		{
			"out": "user://window_bars",
			"variants": "base",
			"style": -1,
			"floors": 8,
			"gap": 5.0,
			"stage": 2,
			"frames": 24,
			"step": 0.06,
			"time": "night",
			"gfx": "medium",
			"size": "3840x2160",
			"pick": 0,
		}
	)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_out = str(_opt["out"])
	DirAccess.make_dir_recursive_absolute(_out)
	var wh := str(_opt["size"]).split("x")
	_size = Vector2i(int(wh[0]), int(wh[1]))
	Content.set_time(str(_opt["time"]))
	PlayerSettings.graphics = str(_opt["gfx"])
	var stage_n := Num.i(_opt["stage"])
	var stats := Kit.stats(SPECIES, Kit.STAGE_LEVELS[1], SPECIES)
	_sim = Kit.stage_sim(stats, stage_n, CityGrowth.tuning_for(Content.tuning(), stage_n))
	var stage := Node3D.new()
	_city = CityView.new(_sim, Seeds.make("fx", 0))
	stage.add_child(_city)
	var species := Content.species_def(SPECIES)
	var colors: Dictionary = species["colors"]
	var scale := _sim.body_scale()
	_kaiju = KaijuModel.new(SPECIES, colors, KaijuModel.stage_for(_sim.size_tier()))
	_kaiju.scale = Vector3.ONE * scale
	stage.add_child(_kaiju)
	_cam = Camera3D.new()
	stage.add_child(_cam)
	root.add_child(stage)
	_cam.current = true
	_make_port()
	_kaiju.visible = false
	for _i: int in 40:
		await process_frame
	_city.process_mode = Node.PROCESS_MODE_DISABLED
	for node: Node in get_nodes_in_group(GraphicsPresets.GROUP):
		if node is DirectionalLight3D:
			_sun = node
		elif node is WorldEnvironment:
			_env = (node as WorldEnvironment).environment
	print(
		(
			"graphics %s row %s | sun %s env %s | time %s | window_lit %s glow %s"
			% [
				PlayerSettings.graphics_level(),
				PlayerSettings.graphics_row(),
				_sun != null,
				_env != null,
				_opt["time"],
				Look.value("window_lit"),
				Look.value("window_glow"),
			]
		)
	)
	var picks := _pick()
	for variant: String in str(_opt["variants"]).split(","):
		for n: int in picks:
			await _building(n, scale, variant)
	quit()


## A 4K off-screen viewport on the same world, with the game's graphics row, through _cam.
func _make_port() -> void:
	_port = SubViewport.new()
	_port.size = _size
	_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	PlayerSettings.apply_graphics(_port)
	_eye = Camera3D.new()
	_port.add_child(_eye)
	root.add_child(_port)
	_eye.current = true
	_far = FarDepth.new(_eye)  # the far blur, as the rampage's camera has it


## One tower per facade archetype: tall enough (--floors), the nearest to the city's middle
## (--pick skips that many nearer ones).
func _pick() -> Array[int]:
	var out: Array[int] = []
	var want := Num.i(_opt["style"])
	for style: int in 4:
		if want >= 0 and style != want:
			continue
		var found: Array[Vector2] = []
		for i: int in _sim.buildings.size():
			var b := _sim.buildings[i]
			if b.landmark != "" or b.hazard != "" or b.is_rail() or b.style % 4 != style:
				continue
			if b.height < Num.i(_opt["floors"]) or b.w < 3 or b.d < 3:
				continue
			found.append(Vector2(Vector2(b.x, b.z).length(), i))
		found.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
		var at := mini(Num.i(_opt["pick"]), found.size() - 1)
		if at >= 0:
			out.append(roundi(found[at].y))
	return out


## Switches one suspect off; returns what puts it back.
func _apply(variant: String, view: BuildingView, index: int) -> Callable:
	var undo: Array[Callable] = []
	for part: String in variant.split("+"):
		match part:
			"base":
				pass
			"noshadow":
				_sun.shadow_enabled = false
				undo.append(func() -> void: _sun.shadow_enabled = true)
			"noao":
				_env.ssao_enabled = false
				undo.append(func() -> void: _env.ssao_enabled = true)
			"nossil":
				_env.ssil_enabled = false
				undo.append(func() -> void: _env.ssil_enabled = true)
			"noglow":
				_env.glow_enabled = false
				undo.append(func() -> void: _env.glow_enabled = true)
			"nofog":
				_env.fog_enabled = false
				undo.append(func() -> void: _env.fog_enabled = true)
			"nodof":
				var attrs := _eye.attributes
				_eye.attributes = null
				undo.append(func() -> void: _eye.attributes = attrs)
			"nomsaa":
				_port.msaa_3d = Viewport.MSAA_DISABLED
				undo.append(func() -> void: PlayerSettings.apply_graphics(_port))
			"msaa4":
				_port.msaa_3d = Viewport.MSAA_4X
				undo.append(func() -> void: PlayerSettings.apply_graphics(_port))
			"native":
				_port.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
				_port.scaling_3d_scale = 1.0
				undo.append(func() -> void: PlayerSettings.apply_graphics(_port))
			"slabs":
				view._slabs.visible = true
				undo.append(func() -> void: view._slabs.visible = false)
			"box":
				# The stand-in box (facade.gdshader) in place of the meshed building, as the stream shows
				# a building it has not meshed.
				var stream: BuildingStream = _city._stream
				view.visible = false
				stream._stand_ins.show(index)
				undo.append(
					func() -> void:
						stream._stand_ins.hide(index)
						view.visible = true
				)
			"main":
				# The shell as origin/main bakes it: no wall face behind a balcony slab.
				var fixed := view._shell.mesh
				view._shell.mesh = _without_balcony_walls(view)
				undo.append(func() -> void: view._shell.mesh = fixed)
			"hardshadow":
				var old := _sun.light_angular_distance
				_sun.light_angular_distance = 0.0
				_sun.shadow_blur = 0.0
				undo.append(
					func() -> void:
						_sun.light_angular_distance = old
						_sun.shadow_blur = 1.5
				)
			_:
				printerr("unknown variant part ", part)
	return func() -> void:
		for u: Callable in undo:
			u.call()


## The view's shell mesh without the wall faces that look at a balcony slab (a slab outside the
## hollow): what BuildingMesher baked before the fix, face for face.
func _without_balcony_walls(view: BuildingView) -> ArrayMesh:
	var voxels := view.voxels
	var cells: Dictionary = voxels.vox.cells
	var res := BuildingVoxels.RES
	var w := view.b.w * res
	var d := view.b.d * res
	var h := view.b.height * res
	var half := BuildingVoxels.VOXEL * 0.5
	var skip := {}
	for cell: Vector3i in cells:
		if cells[cell] == "slab":
			continue
		for dir: Vector3i in BuildingMesher.NEIGHBOURS:
			var o := cell + dir
			var inside := o.x >= 1 and o.x <= w - 2 and o.z >= 1 and o.z <= d - 2
			inside = inside and o.y >= 0 and o.y < h - 1
			if cells.get(o, "") == "slab" and not inside:
				var at := voxels.origin() + Vector3(0, half, 0) + Vector3(cell) * BuildingVoxels.VOXEL
				skip[Vector3i(((at + Vector3(dir) * half) * 1024.0).round())] = true
	var src := view.mesher.shell.surface_get_arrays(0)
	var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = src[Mesh.ARRAY_COLOR]
	var uv2: PackedVector2Array = src[Mesh.ARRAY_TEX_UV2]
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nc := PackedColorArray()
	var nu := PackedVector2Array()
	var index := PackedInt32Array()
	var dropped := 0
	for q: int in range(0, verts.size(), 4):
		var centre := (verts[q] + verts[q + 1] + verts[q + 2] + verts[q + 3]) * 0.25
		if skip.has(Vector3i((centre * 1024.0).round())):
			dropped += 1
			continue
		var at := nv.size()
		for k: int in 4:
			nv.append(verts[q + k])
			nn.append(normals[q + k])
			nc.append(colors[q + k])
			nu.append(uv2[q + k])
		index.append_array([at, at + 2, at + 1, at, at + 3, at + 2])
	print("  main shell: dropped %d wall faces behind balcony slabs" % dropped)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = nv
	arrays[Mesh.ARRAY_NORMAL] = nn
	arrays[Mesh.ARRAY_COLOR] = nc
	arrays[Mesh.ARRAY_TEX_UV2] = nu
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _building(n: int, scale: float, variant: String) -> void:
	var b := _sim.buildings[n]
	var at := Vector3(b.x + b.w * 0.5 + Num.f(_opt["gap"]), 0, b.z)
	_kaiju.rotation.y = PI * 0.5
	var stream: BuildingStream = _city._stream
	var view := stream.view(n)
	var undo := _apply(variant, view, n)
	var tag := "b%d_a%d" % [n, b.style % 4]
	var dir := _out.path_join(variant).path_join(tag)
	DirAccess.make_dir_recursive_absolute(dir)
	var step := Num.f(_opt["step"])
	var rect := Rect2i()
	for f: int in Num.i(_opt["frames"]):
		_kaiju.position = at + Vector3(0, 0, step * f)
		_kaiju.animate(0.0, 0.0)
		Kit.place_game_camera(_cam, _kaiju, scale)
		_eye.fov = _cam.fov
		_eye.global_transform = _cam.global_transform
		_far.follow(_kaiju.position)
		for _i: int in (SETTLE_FRAMES if f == 0 else 1):
			await process_frame
		var shot := _port.get_texture().get_image()
		if f == 0:
			rect = _rect(b)
			print(
				"%s %s: %dx%dx%d style %d at (%.1f, %.1f), rect %s"
				% [variant, tag, b.w, b.d, b.height, b.style, b.x, b.z, rect]
			)
			shot.save_png(dir.path_join("full0.png"))
		shot.get_region(rect).save_png(dir.path_join("f%03d.png" % f))
	undo.call()


## The building's screen rectangle in the shot (its standing box through the eye camera), taken
## from the first frame and padded for the camera drift.
func _rect(b: RampageSim.Building) -> Rect2i:
	var lo := Vector2(1.0e9, 1.0e9)
	var hi := Vector2(-1.0e9, -1.0e9)
	for i: int in 8:
		var corner := Vector3(
			b.x + b.w * 0.5 * (1 if (i & 1) != 0 else -1),
			float(b.height) * float((i >> 1) & 1),
			b.z + b.d * 0.5 * (1 if ((i >> 2) & 1) != 0 else -1)
		)
		if _eye.is_position_behind(corner):
			continue
		var p := _eye.unproject_position(corner)
		lo = lo.min(p)
		hi = hi.max(p)
	var pad := Vector2(120.0, 40.0)
	return Rect2i(Vector2i((lo - pad).floor()), Vector2i((hi - lo + pad * 2.0).ceil())).intersection(
		Rect2i(Vector2i.ZERO, _size)
	)
