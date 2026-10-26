class_name HideHit
extends Node3D
## What a shot looks like landing on the kaiju's hide (director 2026-10-25: "the shot impacts look a
## bit flat, like theyre pasted on top of the image"; "it glows too much"; "a toned down impact
## indicator with a tiny red blood mist at the impact site"). One impact for every hitter (tank
## shells, helicopter guns, an armoured glance): found on the real cube the shot meets, lying on its
## face along the normal, depth-tested so a body in front hides it. A flash under a tenth of a
## second and under the bloom threshold, a few dull sparks, a small dark-red puff (the smoke
## family), and a faint wound the hide keeps (SkinHits). Numbers in tuning "fx" "hide_hit". Child of
## Fx. Presentation only.

const FLASH := preload("res://scenes/hide_hit.gdshader")
const SMOKE := preload("res://scenes/smoke.gdshader")
## How far off the surface the flash lies, in voxels: a hair, so the cubes do not cut it.
const LIFT := 0.35
## `away` for a shot that is not a glance (a glance with no slide direction passes Vector3.ZERO).
const NO_GLANCE := Vector3(INF, INF, INF)

var _tune: Dictionary
var _flash_mesh: QuadMesh
var _spark_mesh: BoxMesh


func _init() -> void:
	_tune = Content.section("fx")["hide_hit"]
	_flash_mesh = QuadMesh.new()
	_flash_mesh.size = Vector2.ONE
	var spark := StandardMaterial3D.new()
	spark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark.vertex_color_use_as_albedo = true
	spark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_mesh = BoxMesh.new()
	_spark_mesh.size = Vector3.ONE
	_spark_mesh.material = spark


## Lands a shot on `kaiju` along from -> aim: the real hit if the segment meets the hide (carried a
## little past `aim`), else the aim point facing the shooter. A glance (armour) leaves no blood and
## no wound and throws its sparks along `away`. Returns the hit that was drawn (point, normal).
static func land(
	fx: Fx, kaiju: Node3D, from: Vector3, aim: Vector3, glance := false, away := Vector3.ZERO
) -> Dictionary:
	var tune: Dictionary = Content.section("fx")["hide_hit"]
	var dir := (aim - from).normalized()
	var hit := _find(kaiju, from, aim, Num.f(tune["ray_extra"]), Num.f(tune["aim_rings"]))
	var unit := 0.12 * absf(kaiju.scale.x)
	if kaiju.has_method("voxel_world"):
		var world: float = kaiju.call("voxel_world")
		unit = world
	var point := aim
	var normal := -dir
	if not hit.is_empty():
		point = hit["point"]
		normal = hit["normal"]
		var eye: bool = hit["eye"]
		if not glance and not eye and kaiju.has_method("hide_hits"):
			kaiju.call("hide_hits").add_wound(hit["rest"], 1.0)
	fx.hide_hit(point, normal, unit, away if glance else NO_GLANCE)
	return {"point": point, "normal": normal, "hit": not hit.is_empty()}


## The hide cube a shot at `aim` meets: the straight ray first, then rings of rays round the aim
## point (a shell aimed between his legs still lands on the nearest thigh, never in the air),
## nearest first.
static func _find(
	kaiju: Node3D, from: Vector3, aim: Vector3, extra: float, rings: float
) -> Dictionary:
	if not kaiju.has_method("hide_cast"):
		return {}
	var bs := absf(kaiju.scale.x)
	var dir := (aim - from).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var up := side.cross(dir)
	var reach := from.distance_to(aim) + extra * bs
	for ring: int in range(0, 4):
		var radius := rings * bs * ring
		var best: Dictionary = {}
		var best_gap := INF
		for k: int in 1 if ring == 0 else 8:
			var a := TAU * k / 8.0
			var to := aim + (side * cos(a) + up * sin(a)) * radius
			var line := (to - from).normalized()
			var cast: Variant = kaiju.call("hide_cast", from, from + line * reach)
			var found: Dictionary = cast
			if found.is_empty():
				continue
			var point: Vector3 = found["point"]
			if point.distance_to(aim) < best_gap:
				best_gap = point.distance_to(aim)
				best = found
		if not best.is_empty():
			return best
	return {}


## Draws the impact at `at` on a surface facing `normal`; `unit` is one voxel of the hide (world).
func play(at: Vector3, normal: Vector3, unit: float, away := NO_GLANCE) -> void:
	var n := normal.normalized()
	_flash(at, n, unit, away)
	_sparks(at, n, unit, away)
	if away == NO_GLANCE:
		_mist(at, n, unit)


func _flash(at: Vector3, n: Vector3, unit: float, away: Vector3) -> void:
	var glance := away != NO_GLANCE
	var seconds := Num.f(_tune["glance_seconds"] if glance else _tune["flash_seconds"])
	var width := Num.f(_tune["flash_voxels"]) * unit
	var mat := ShaderMaterial.new()
	mat.shader = FLASH
	mat.set_shader_parameter("tint", Color(str(_tune["glance_tint" if glance else "flash_tint"])))
	mat.set_shader_parameter("peak", Num.f(_tune["flash_alpha"]))
	var quad := MeshInstance3D.new()
	quad.mesh = _flash_mesh
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The quad lies on the surface: its +Z is the normal, its X along the glance's slide if any.
	var slide := away - n * away.dot(n)
	var side := slide.normalized() if glance and slide.length() > 0.01 else n.cross(Vector3.UP)
	if side.length() < 0.01:
		side = n.cross(Vector3.RIGHT)
	side = side.normalized()
	quad.basis = (
		Basis(side, n.cross(side), n)
		* Basis.from_scale(
			Vector3(width * (1.6 if glance else 1.0), width * (0.6 if glance else 1.0), 1.0)
		)
	)
	quad.position = at + n * LIFT * unit
	add_child(quad)
	var tween := quad.create_tween()
	tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("fade", 1.0 - v), 0.0, 1.0, seconds
	)
	tween.tween_callback(quad.queue_free)


## A few dull sparks, below the bloom threshold: thrown along the normal (a glance: along `away`).
func _sparks(at: Vector3, n: Vector3, unit: float, away: Vector3) -> void:
	var glance := away != NO_GLANCE
	var count := Num.i(_tune["glance_sparks" if glance else "spark_count"])
	var tint := Color(str(_tune["spark_tint"]))
	var mat := ParticleProcessMaterial.new()
	mat.direction = away.normalized() if glance and away.length() > 0.01 else n
	mat.spread = 35.0
	mat.initial_velocity_min = 2.0 * unit / 0.12
	mat.initial_velocity_max = 5.0 * unit / 0.12
	mat.gravity = Vector3(0, -9.0, 0)
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([tint, Color(tint.darkened(0.5), 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	var cube := _spark_mesh.duplicate() as BoxMesh
	cube.size = Vector3.ONE * Num.f(_tune["spark_voxels"]) * unit
	var p := _particles(mat, cube, count, 0.2)
	p.position = at + n * LIFT * unit


## The mist's colour over its life: fades in fast, then out.
func _mist_ramp() -> GradientTexture1D:
	var tint := Color(str(_tune["mist_tint"])).srgb_to_linear()
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	ramp.colors = PackedColorArray(
		[Color(tint, 0.0), Color(tint, Num.f(_tune["mist_alpha"])), Color(tint, 0.0)]
	)
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	return tex


## The blood: a few small dark-red smoke puffs drifting out along the normal, gone in half a second.
func _mist(at: Vector3, n: Vector3, unit: float) -> void:
	var seconds := Num.f(_tune["mist_seconds"])
	var size := Num.f(_tune["mist_voxels"]) * unit
	var mat := ParticleProcessMaterial.new()
	mat.direction = n
	mat.spread = 30.0
	mat.initial_velocity_min = 0.6 * unit / 0.12
	mat.initial_velocity_max = 1.4 * unit / 0.12
	mat.damping_min = 1.0
	mat.damping_max = 2.0
	mat.gravity = Vector3(0, -0.4, 0)
	mat.scale_min = 0.8
	mat.scale_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 1.5))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	mat.scale_curve = grow_tex
	mat.color_ramp = _mist_ramp()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var smoke := ShaderMaterial.new()
	smoke.shader = SMOKE
	smoke.set_shader_parameter("self_lit", 1.0)
	# The puff is on the kaiju's own hide: the smoke's clearing over him and the screen centre is
	# off.
	smoke.set_shader_parameter("centre_keep", 1.0)
	smoke.set_shader_parameter("focus_clear", 0.0)
	smoke.set_shader_parameter("focus_full", 0.001)
	quad.material = smoke
	var p := _particles(mat, quad, Num.i(_tune["mist_count"]), seconds)
	p.position = at + n * LIFT * unit


func _particles(
	mat: ParticleProcessMaterial, mesh: Mesh, count: int, life: float
) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount_ratio = 1.0
	p.process_material = mat
	p.draw_pass_1 = mesh
	p.amount = maxi(1, count)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.randomness = 0.4
	p.fixed_fps = 60
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	p.emitting = true
	add_child(p)
	get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)
	return p
