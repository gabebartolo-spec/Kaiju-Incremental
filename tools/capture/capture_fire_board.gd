extends SceneTree
## The Fire family treatment board (director D-188, VFX lead): ONE building fire at the game camera in
## three treatments side by side, A / B / C, plus the same frame without them. Experiments only: each
## is a stand-in for Fire's flame and core systems, built here from Fire's own embers, smoke and light;
## nothing in the game changes. Needs a window and the no-focus override.cfg.
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_fire_board.gd -- --out=<dir> --run=1   (1 night, 3 noon)
## A: voxel plates graded by flame HEIGHT in the shader. B: A on tall tapering overlapping plates.
## C: soft camera-facing tongues (a teardrop mask) graded by height.

const Kit := preload("res://tools/capture/capture_kit.gd")
const HEIGHT := preload("res://tools/capture/fire_board_height.gdshader")
const TONGUE := preload("res://tools/capture/fire_board_tongue.gdshader")
const LEVELS := {"claws": 5, "hide": 5, "rage": 3, "evolve1": 1, "sig_power": 2, "r_beam": 1}
const SETTLE := 120
const SPOT := Vector3(7.0, 0.0, -7.0)
const ROOF := 5.0
const SPACING := 3.4
const SIZE := 1.2  # a building's fire (fire_spread.view_size)
const FRAMES := 240

var _out := "user://fire_board"
var _rampage: Rampage
var _points := {}


func _initialize() -> void:
	var a := Kit.args({"out": _out, "run": 1})
	_out = str(a["out"])
	DirAccess.make_dir_recursive_absolute(_out)
	if not Kit.window_ok():
		quit(1)
		return
	_run.call_deferred(Num.i(a["run"]))


func _run(run: int) -> void:
	await process_frame
	_rampage = Kit.rampage("reptilian", Kit.stats("reptilian", LEVELS), run)
	_rampage.scripted = func(_sim: RampageSim) -> Dictionary: return {}
	root.add_child(_rampage)
	await _rampage.wait_loaded()
	while _rampage.sim.emerge.active:
		await physics_frame
	await Kit.frames(self, SETTLE)
	_rampage.sim.time_left = 600.0
	_rampage.sim._stomp_timer = 99999.0
	for node: Node in _rampage.get_children():
		if node is BreathAim:
			node.set_physics_process(false)
			(node as Node3D).visible = false
	_rampage.sim.ability_ready_in = 0.0
	await Kit.frames(self, 90)
	var city: CityView = _rampage.get("_city")
	var feet := Vector3(_rampage.sim.kaiju_pos.x, 0.0, _rampage.sim.kaiju_pos.y)
	var spot := feet + SPOT * _rampage.sim.body_scale() + Vector3(0, ROOF, 0)
	var fires: Array[Fire] = []
	for k: int in 3:
		var fire := Fire.new(SIZE, 3.0 + k)
		var at := spot + Vector3((k - 1) * SPACING, 0, 0)
		city.add_child(fire)
		fire.global_position = at
		_dress(fire, k, at)
		fires.append(fire)
	await Kit.frames(self, FRAMES)
	var cam := root.get_viewport().get_camera_3d()
	var size := Vector2(root.get_texture().get_image().get_size())
	for k: int in 3:
		var px := Kit.image_point(self, cam, fires[k].global_position + Vector3(0, 1.4, 0), size)
		_points["abc"[k]] = [px.x, px.y]
	Kit.still(self, _out, "board")
	for fire: Fire in fires:
		fire.queue_free()
	await Kit.frames(self, FRAMES)
	Kit.still(self, _out, "none")
	var file := FileAccess.open(_out.path_join("points.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_points))
	file.close()
	quit()


## Swaps the fire's own flame and core systems for treatment `k` (0 A, 1 B, 2 C); its light, embers
## and smoke stay Fire's.
func _dress(fire: Fire, k: int, at: Vector3) -> void:
	var systems: Array[GPUParticles3D] = []
	for child: Node in fire.get_children():
		if child is GPUParticles3D:
			systems.append(child as GPUParticles3D)
	systems[0].queue_free()  # the flames
	systems[1].queue_free()  # the core column
	match k:
		0:
			fire.add_child(_plates(at, 1.9, 0.55, false))
		1:
			fire.add_child(_plates(at, 2.4, 0.5, true))
		_:
			fire.add_child(_tongues())


## Voxel plates graded by height (height.gdshader): A is Fire's old blobby flame (cubes, 12 degrees),
## B tall tapering stretched plates (1:1.8, narrowing to 40%) at 6 degrees and half again as many.
func _plates(at: Vector3, flame_h: float, half_w: float, tall: bool) -> GPUParticles3D:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(
		SIZE * (0.45 if tall else 0.6), 0.2, SIZE * (0.45 if tall else 0.6)
	)
	mat.direction = Vector3.UP
	mat.spread = 6.0 if tall else 12.0
	mat.gravity = Vector3(0, 2.2 if tall else 2.5, 0)
	mat.initial_velocity_min = 1.1 if tall else 0.8
	mat.initial_velocity_max = 2.2 if tall else 2.0
	mat.scale_min = Fire.FLAME_SCALE.x
	mat.scale_max = Fire.FLAME_SCALE.y
	var sizes := Curve.new()
	sizes.add_point(Vector2(0, 0.7 if tall else 1.0))
	sizes.add_point(Vector2(0.15, 1.0))
	sizes.add_point(Vector2(1, 0.4 if tall else 0.1))
	var sizes_tex := CurveTexture.new()
	sizes_tex.curve = sizes
	mat.scale_curve = sizes_tex
	mat.color_ramp = _alpha_ramp([0.95, 0.95, 0.85] if tall else [1.0, 1.0, 1.0])
	var cube := BoxMesh.new()
	cube.size = Fire.FLAME_PLATE if tall else Vector3.ONE * Fire.FLAME_CUBE
	var draw := ShaderMaterial.new()
	draw.shader = HEIGHT
	draw.set_shader_parameter("base_y", at.y)
	draw.set_shader_parameter("flame_h", flame_h)
	draw.set_shader_parameter("axis", Vector2(at.x, at.z))
	draw.set_shader_parameter("half_w", half_w)
	cube.material = draw
	return _system(mat, cube, roundi((170 if tall else 130) * maxf(1.0, SIZE)), 1.0)


## Soft tongues (tongue.gdshader): a few big camera-facing teardrops rising and flickering.
func _tongues() -> GPUParticles3D:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(SIZE * 0.4, 0.1, SIZE * 0.4)
	mat.direction = Vector3.UP
	mat.spread = 5.0
	mat.gravity = Vector3(0, 0.6, 0)
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.0
	mat.scale_min = 0.8
	mat.scale_max = 1.25
	var sizes := Curve.new()
	sizes.add_point(Vector2(0, 0.55))
	sizes.add_point(Vector2(0.2, 1.0))
	sizes.add_point(Vector2(1, 0.8))
	var sizes_tex := CurveTexture.new()
	sizes_tex.curve = sizes
	mat.scale_curve = sizes_tex
	mat.color_ramp = _alpha_ramp([0.0, 0.95, 0.0], [0.0, 0.18, 1.0])
	var seeds := Gradient.new()
	seeds.colors = PackedColorArray(
		[Color(0.1, 0, 0), Color(0.4, 0, 0), Color(0.7, 0, 0), Color(0.95, 0, 0)]
	)
	seeds.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var seeds_tex := GradientTexture1D.new()
	seeds_tex.gradient = seeds
	mat.color_initial_ramp = seeds_tex
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 3.4)
	quad.center_offset = Vector3(0, 1.5, 0)  # the foot at the particle, the tip 3.4 m up
	var draw := ShaderMaterial.new()
	draw.shader = TONGUE
	quad.material = draw
	return _system(mat, quad, 26, 1.0)


func _alpha_ramp(alphas: Array, offsets: Array = [0.0, 0.3, 1.0]) -> GradientTexture1D:
	var ramp := Gradient.new()
	var colors := PackedColorArray()
	for a: Variant in alphas:
		colors.append(Color(1, 1, 1, Num.f(a)))
	ramp.colors = colors
	ramp.offsets = PackedFloat32Array(offsets)
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	return tex


func _system(mat: ParticleProcessMaterial, mesh: Mesh, amount: int, life: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = mat
	p.draw_pass_1 = mesh
	p.amount = amount
	p.lifetime = life
	p.position = Vector3(0, 0.2, 0)
	p.visibility_aabb = AABB(Vector3(-6, -2, -6), Vector3(12, 12, 12))
	return p
