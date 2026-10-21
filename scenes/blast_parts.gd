class_name BlastParts
extends RefCounted
## The pieces a red-barrel blast is drawn from (BlastFx; director comments #19, #20), each a
## one-shot node that frees itself: the fireball (glowing voxels cooling from white-hot to soot),
## the white core that marks the instant, the smoke column, the ground shock (a dust band and a
## ring of dust thrown out along the street), the heat-haze shell that bends the city behind it,
## fireworks bursts and the chem lab's green cloud. Sizes come from the sim's blast radius, looks
## from data/tuning.json "blast_fx". Presentation only.

const SHOCKWAVE := preload("res://scenes/shockwave.gdshader")
const HAZE := preload("res://scenes/heat_haze.gdshader")
const SMOKE := preload("res://scenes/smoke.gdshader")
const EMBER := preload("res://scenes/blast_ember.gdshader")
## The fireball's colour over its life: white-hot, orange, red, soot, gone (HDR: the bloom).
const FIREBALL: Array[Color] = [
	Color(2.4, 1.9, 1.0, 1.0),
	Color(1.6, 0.62, 0.08, 1.0),
	Color(0.85, 0.16, 0.03, 1.0),
	Color(0.16, 0.07, 0.04, 0.95),
	Color(0.09, 0.085, 0.08, 0.8),
	Color(0.1, 0.1, 0.1, 0.0),
]
const FIREBALL_AT: Array[float] = [0.0, 0.1, 0.28, 0.45, 0.7, 1.0]

static var _ball: SphereMesh


## One sphere mesh shared by every core and haze shell (each draws it with its own material).
static func _sphere() -> SphereMesh:
	if _ball == null:
		_ball = SphereMesh.new()
		_ball.radius = 1.0
		_ball.height = 2.0
		_ball.radial_segments = 24
		_ball.rings = 12
	return _ball


## Glowing voxels thrown up and out from `at`, cooling to soot as they rise and slow.
static func fireball(host: Node3D, at: Vector3, radius: float, cfg: Dictionary) -> void:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = radius * 0.35
	mat.direction = Vector3.UP
	mat.spread = 75.0
	mat.initial_velocity_min = radius * 0.8
	mat.initial_velocity_max = radius * 2.2
	mat.gravity = Vector3(0, radius * 0.6, 0)  # hot air: it rises as it burns out
	mat.damping_min = radius * 0.5
	mat.damping_max = radius * 0.9
	mat.angular_velocity_min = -90.0
	mat.angular_velocity_max = 90.0
	_scale(mat, Vector2(0.6, 1.4) * radius * 0.16, [0.6, 1.4, 1.1])
	mat.color_ramp = _ramp(FIREBALL, FIREBALL_AT)
	var cube := _ember_cube()
	var life := Num.f(cfg["seconds"])
	_emit(host, mat, cube, roundi(Num.f(cfg["amount"]) * clampf(radius / 5.0, 0.5, 1.6)), life, at)


## A white-hot ball that swells to the blast radius in an instant and fades: the detonation.
static func core(host: Node3D, at: Vector3, radius: float, cfg: Dictionary) -> void:
	var ball := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(2.2, 1.5, 0.6, 0.9)
	ball.mesh = _sphere()
	ball.material_override = mat
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.position = at
	ball.scale = Vector3.ONE * 0.2
	host.add_child(ball)
	var grow := Num.f(cfg["grow_seconds"])
	var tween := ball.create_tween()
	tween.tween_property(ball, "scale", Vector3.ONE * radius * Num.f(cfg["radius_scale"]), grow)
	tween.tween_property(mat, "albedo_color:a", 0.0, Num.f(cfg["fade_seconds"]))
	tween.tween_callback(ball.queue_free)


## Dark smoke boiling up from the site long after the fireball.
static func smoke(host: Node3D, at: Vector3, radius: float, cfg: Dictionary) -> void:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = radius * 0.5
	mat.direction = Vector3.UP
	mat.spread = 25.0
	mat.initial_velocity_min = radius * 0.5
	mat.initial_velocity_max = radius * 1.1
	mat.gravity = Vector3(1.2, radius * 0.25, 0.5)
	mat.damping_min = 0.4
	mat.damping_max = 0.8
	_scale(mat, Vector2(1.0, 1.8) * radius * 0.45, [0.6, 1.4, 2.2])
	var dark := Color(0.09, 0.085, 0.08)
	mat.color_ramp = _ramp(
		[
			Color(dark, 0.0),
			Color(dark, 0.7),
			Color(0.2, 0.2, 0.21, 0.4),
			Color(0.25, 0.25, 0.26, 0.0)
		],
		[0.0, 0.1, 0.6, 1.0]
	)
	var p := _emit(host, mat, _puff(), Num.i(cfg["amount"]), Num.f(cfg["seconds"]), at)
	p.explosiveness = 0.5


## The ground shock: a dust band racing out over the street and a ring of dust clouds thrown out
## with it, both well past the blast radius, so the blow reads from the game camera.
static func ground_shock(host: Node3D, at: Vector3, radius: float, cfg: Dictionary) -> void:
	var reach := radius * Num.f(cfg["radius_scale"])
	var seconds := Num.f(cfg["seconds"])
	var quad := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * reach * 2.0
	var band := ShaderMaterial.new()
	band.shader = SHOCKWAVE
	band.set_shader_parameter("peak", Num.f(cfg["alpha"]))
	band.set_shader_parameter("soft", Num.f(cfg["soft"]))
	band.set_shader_parameter("tint", Color(str(cfg["band_tint"])))
	plane.material = band
	quad.mesh = plane
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.position = Vector3(at.x, 0.2, at.z)
	host.add_child(quad)
	var tween := quad.create_tween()
	var drive := func(v: float) -> void: band.set_shader_parameter("progress", v)
	tween.tween_method(drive, 0.05, 1.0, seconds)
	tween.tween_callback(quad.queue_free)
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_radius = radius * 0.5
	mat.emission_ring_inner_radius = radius * 0.3
	mat.emission_ring_height = 0.3
	mat.direction = Vector3.UP
	mat.spread = 10.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 1.2
	var speed := reach / seconds
	mat.radial_velocity_min = speed * 0.9
	mat.radial_velocity_max = speed * 1.5
	mat.damping_min = speed * 0.5
	mat.damping_max = speed * 0.8
	mat.gravity = Vector3(0, 0.3, 0)
	_scale(mat, Vector2(1.0, 1.6) * radius * 0.45, [0.6, 1.6, 2.4])
	var dust := Color(str(cfg["tint"]))
	mat.color_ramp = _ramp(
		[Color(dust, 0.0), Color(dust, Num.f(cfg["dust_alpha"])), Color(dust, 0.0)], [0.0, 0.1, 1.0]
	)
	var life := seconds * 2.2
	_emit(host, mat, _puff(), Num.i(cfg["dust_amount"]), life, Vector3(at.x, 0.6, at.z))


## A shell of bent air that swells past the blast and is gone in half a second (the sonic boom
## you can see: the city behind it wobbles).
static func haze(host: Node3D, at: Vector3, radius: float, cfg: Dictionary) -> void:
	var shell := MeshInstance3D.new()
	var mat := ShaderMaterial.new()
	mat.shader = HAZE
	mat.set_shader_parameter("strength", Num.f(cfg["strength"]))
	shell.mesh = _sphere()
	shell.material_override = mat
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.position = at
	shell.scale = Vector3.ONE * radius * 0.4
	host.add_child(shell)
	var seconds := Num.f(cfg["seconds"])
	var full := Vector3.ONE * radius * Num.f(cfg["radius_scale"])
	var tween := shell.create_tween().set_parallel()
	tween.tween_property(shell, "scale", full, seconds).set_ease(Tween.EASE_OUT).set_trans(
		Tween.TRANS_QUAD
	)
	tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("progress", v), 0.0, 1.0, seconds
	)
	tween.chain().tween_callback(shell.queue_free)


## One fireworks shell bursting: a sphere of coloured sparks falling as they fade.
static func firework(host: Node3D, at: Vector3, color: Color, cfg: Dictionary) -> void:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	mat.direction = Vector3.UP
	mat.spread = 180.0
	var speed := Num.f(cfg["speed"])
	mat.initial_velocity_min = speed * 0.8
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, -4.0, 0)
	mat.damping_min = speed * 0.45
	mat.damping_max = speed * 0.6
	_scale(mat, Vector2(0.8, 1.2) * Num.f(cfg["spark_size"]), [1.0, 1.0, 0.2])
	var hot := Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 1.0)
	mat.color_ramp = _ramp(
		[Color(2.0, 2.0, 2.0, 1.0), hot, Color(hot, 0.8), Color(color, 0.0)], [0.0, 0.04, 0.6, 1.0]
	)
	var spark := _ember_cube()
	_emit(host, mat, spark, Num.i(cfg["sparks"]), Num.f(cfg["seconds"]), at)


## The chem lab's cloud: green, glowing faintly, rolling low over the ground for `seconds`.
static func toxic_cloud(
	host: Node3D, at: Vector3, radius: float, seconds: float, cfg: Dictionary
) -> void:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(radius * 0.8, 0.6, radius * 0.8)
	mat.direction = Vector3.UP
	mat.spread = 60.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.9
	mat.gravity = Vector3(0.4, 0.15, 0.2)
	_scale(mat, Vector2(0.8, 1.4) * radius * 0.45, [0.5, 1.2, 1.6])
	var green := Color(str(cfg["color"]))
	var alpha := Num.f(cfg["alpha"])
	mat.color_ramp = _ramp(
		[
			Color(green, 0.0),
			Color(green, alpha),
			Color(green.darkened(0.3), alpha * 0.6),
			Color(green, 0.0)
		],
		[0.0, 0.2, 0.7, 1.0]
	)
	var life := Num.f(cfg["life"])
	var lift := at + Vector3(0, 0.8, 0)
	var p := _emit(host, mat, _soft_quad(true), Num.i(cfg["amount"]), life, lift, seconds + life)
	p.one_shot = false
	p.explosiveness = 0.0
	host.get_tree().create_timer(seconds).timeout.connect(
		func() -> void:
			if is_instance_valid(p):
				p.emitting = false
	)


## A unit voxel drawn with the blast's own ember shader (bright, no haze).
static func _ember_cube() -> BoxMesh:
	var cube := BoxMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = EMBER
	cube.material = mat
	return cube


## A particle system that emits once and frees itself after `life`.
static func _emit(
	host: Node3D,
	mat: ParticleProcessMaterial,
	mesh: Mesh,
	amount: int,
	life: float,
	at: Vector3,
	free_after := -1.0
) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = mat
	p.draw_pass_1 = mesh
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 60, 80))
	p.position = at
	p.emitting = true
	host.add_child(p)
	var gone := (free_after if free_after > 0.0 else life) + 0.3
	host.get_tree().create_timer(gone).timeout.connect(p.queue_free)
	return p


## Scale range and a three-point curve over life (start, middle, end).
static func _scale(mat: ParticleProcessMaterial, span: Vector2, curve_at: Array) -> void:
	mat.scale_min = span.x
	mat.scale_max = span.y
	var curve := Curve.new()
	curve.max_value = 4.0
	curve.add_point(Vector2(0.0, Num.f(curve_at[0])))
	curve.add_point(Vector2(0.4, Num.f(curve_at[1])))
	curve.add_point(Vector2(1.0, Num.f(curve_at[2])))
	var tex := CurveTexture.new()
	tex.curve = curve
	mat.scale_curve = tex


static func _ramp(colors: Array, offsets: Array) -> GradientTexture1D:
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray(colors)
	ramp.offsets = PackedFloat32Array(offsets)
	var tex := GradientTexture1D.new()
	tex.use_hdr = true
	tex.gradient = ramp
	return tex


## A soft smoke puff (the city's smoke shader, lit dimly by the scene).
static func _puff() -> QuadMesh:
	var quad := QuadMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = SMOKE
	quad.material = mat
	return quad


## A round, soft-edged, camera-facing sprite in the particle's colour (glow: unshaded).
static func _soft_quad(glow := false) -> QuadMesh:
	var falloff := Gradient.new()
	falloff.offsets = PackedFloat32Array([0.0, 0.4, 0.75, 1.0])
	falloff.colors = PackedColorArray(
		[Color(1, 1, 1, 1), Color(1, 1, 1, 0.65), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0)]
	)
	var tex := GradientTexture2D.new()
	tex.gradient = falloff
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 0.8
	mat.roughness = 1.0
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var quad := QuadMesh.new()
	quad.material = mat
	return quad
