class_name BlastParts
extends RefCounted
## The pieces a red-barrel blast is drawn from (BlastFx; director comments #19, #20), each a
## one-shot node that frees itself: the white-hot voxel flash that marks the instant, the
## fireball (glowing voxels cooling from white-hot to soot), the smoke column, fireworks bursts
## and the chem lab's green voxel cloud. All start from the site's own box (`half`: its half
## extents, `at` its centre), so a blast always comes out of a building, never out of the air.
## The ground shock and the visible sonic boom are BlastShock. Sizes come from the sim's blast
## radius, looks from data/tuning.json "blast_fx". Presentation only.

const SMOKE := preload("res://scenes/smoke.gdshader")
const EMBER := preload("res://scenes/blast_ember.gdshader")
## The fireball's colour over its life: white-hot, orange, red, soot, gone (HDR: the bloom).
## The soot is short and thin (critic 2026-10-21: "shorter dark phase").
const FIREBALL: Array[Color] = [
	Color(3.0, 2.4, 1.3, 1.0),
	Color(2.0, 0.8, 0.12, 1.0),
	Color(1.1, 0.24, 0.04, 1.0),
	Color(0.3, 0.1, 0.05, 0.7),
	Color(0.12, 0.1, 0.09, 0.0),
]
const FIREBALL_AT: Array[float] = [0.0, 0.14, 0.45, 0.72, 1.0]
## The flash's voxels: hotter than the fireball, gone in a few frames.
const FLASH: Array[Color] = [Color(5.0, 4.4, 3.2, 1.0), Color(3.4, 2.0, 0.6, 1.0)]


## Glowing voxels thrown up and out of the site's box, cooling to soot as they rise and slow.
static func fireball(
	host: Node3D, at: Vector3, half: Vector3, radius: float, cfg: Dictionary
) -> void:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = half
	mat.direction = Vector3.UP
	mat.spread = 80.0
	mat.initial_velocity_min = radius * 1.0
	mat.initial_velocity_max = radius * 2.6
	mat.gravity = Vector3(0, radius * 0.6, 0)  # hot air: it rises as it burns out
	mat.damping_min = radius * 0.6
	mat.damping_max = radius * 1.0
	mat.angular_velocity_min = -90.0
	mat.angular_velocity_max = 90.0
	curve(mat, Vector2(0.6, 1.4) * radius * Num.f(cfg["size"]), [0.7, 1.5, 0.8])
	mat.color_ramp = ramp(FIREBALL, FIREBALL_AT)
	var life := Num.f(cfg["seconds"])
	var amount := roundi(Num.f(cfg["amount"]) * clampf(radius / 5.0, 0.5, 1.6))
	emit(host, mat, ember_cube(), amount, life, at)


## The instant: white-hot voxels bursting out of the whole site and gone in core.seconds (a few
## frames), the brightest thing on screen.
static func core(host: Node3D, at: Vector3, half: Vector3, radius: float, cfg: Dictionary) -> void:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = half
	mat.direction = Vector3.UP
	mat.spread = 180.0
	var seconds := Num.f(cfg["seconds"])
	mat.initial_velocity_min = radius * Num.f(cfg["throw"]) * 0.5 / seconds
	mat.initial_velocity_max = radius * Num.f(cfg["throw"]) / seconds
	mat.gravity = Vector3.ZERO
	curve(mat, Vector2(0.8, 1.2) * radius * Num.f(cfg["size"]), [1.0, 1.1, 0.3])
	mat.color_ramp = ramp(FLASH, [0.0, 1.0])
	var amount := roundi(Num.f(cfg["amount"]) * clampf(radius / 5.0, 0.5, 1.6))
	emit(host, mat, ember_cube(), amount, seconds, at)


## Dark smoke boiling up from the site after the fireball.
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
	curve(mat, Vector2(1.0, 1.8) * radius * 0.45, [0.6, 1.4, 2.2])
	var dark := Color(0.16, 0.15, 0.14)
	var alpha := Num.f(cfg["alpha"])
	mat.color_ramp = ramp(
		[
			Color(dark, 0.0),
			Color(dark, alpha),
			Color(0.26, 0.26, 0.27, alpha * 0.5),
			Color(0.3, 0.3, 0.31, 0.0)
		],
		[0.0, 0.15, 0.6, 1.0]
	)
	var p := emit(host, mat, _puff(), Num.i(cfg["amount"]), Num.f(cfg["seconds"]), at)
	p.explosiveness = 0.5


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
	curve(mat, Vector2(0.8, 1.2) * Num.f(cfg["spark_size"]), [1.0, 1.0, 0.2])
	var hot := Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 1.0)
	mat.color_ramp = ramp(
		[Color(2.0, 2.0, 2.0, 1.0), hot, Color(hot, 0.8), Color(color, 0.0)], [0.0, 0.04, 0.6, 1.0]
	)
	emit(host, mat, ember_cube(), Num.i(cfg["sparks"]), Num.f(cfg["seconds"]), at)


## The chem lab's cloud: a billow of glowing green voxels twice the lab's size (`half` is the
## lab's half extents) for cloud.billow_seconds, then a thin green haze over the sim's cloud
## (`radius`) for as long as the sim keeps it (`seconds`).
static func toxic_cloud(
	host: Node3D, at: Vector3, half: Vector3, radius: float, seconds: float, cfg: Dictionary
) -> void:
	var green := Color(str(cfg["color"]))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = half * Num.f(cfg["size_scale"])
	mat.direction = Vector3.UP
	mat.spread = 90.0
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.6
	mat.gravity = Vector3(0.3, 0.2, 0.15)
	mat.damping_min = 0.3
	mat.damping_max = 0.6
	mat.angular_velocity_min = -25.0
	mat.angular_velocity_max = 25.0
	var sizes: Array = cfg["voxel"]
	curve(mat, Vector2(Num.f(sizes[0]), Num.f(sizes[1])), [0.6, 1.2, 0.0])
	var alpha := Num.f(cfg["alpha"])
	mat.color_ramp = ramp(
		[
			Color(green * 1.6, 0.0),
			Color(green * 1.6, alpha),
			Color(green, alpha * 0.8),
			Color(green.darkened(0.4), 0.0)
		],
		[0.0, 0.1, 0.7, 1.0]
	)
	var billow := Num.f(cfg["billow_seconds"])
	var p := emit(host, mat, ember_cube(), Num.i(cfg["amount"]), billow, at)
	p.explosiveness = 0.8
	_haze(host, at, radius, seconds, cfg)


## The thin haze that marks where the sim's cloud still hurts, after the billow.
static func _haze(
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
	curve(mat, Vector2(0.8, 1.4) * radius * 0.45, [0.5, 1.2, 1.6])
	var green := Color(str(cfg["color"]))
	var alpha := Num.f(cfg["haze_alpha"])
	mat.color_ramp = ramp(
		[Color(green, 0.0), Color(green, alpha), Color(green.darkened(0.3), 0.0)], [0.0, 0.3, 1.0]
	)
	var life := Num.f(cfg["life"])
	var lift := Vector3(at.x, 0.8, at.z)
	var p := emit(host, mat, _soft_quad(), Num.i(cfg["haze_amount"]), life, lift, seconds + life)
	p.one_shot = false
	p.explosiveness = 0.0
	host.get_tree().create_timer(seconds).timeout.connect(
		func() -> void:
			if is_instance_valid(p):
				p.emitting = false
	)


## A unit voxel drawn with the blast's own ember shader (bright, no haze).
static func ember_cube() -> BoxMesh:
	var cube := BoxMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = EMBER
	cube.material = mat
	return cube


## A particle system that emits once and frees itself after `life`.
static func emit(
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
static func curve(mat: ParticleProcessMaterial, span: Vector2, curve_at: Array) -> void:
	mat.scale_min = span.x
	mat.scale_max = span.y
	var c := Curve.new()
	c.max_value = 4.0
	c.add_point(Vector2(0.0, Num.f(curve_at[0])))
	c.add_point(Vector2(0.4, Num.f(curve_at[1])))
	c.add_point(Vector2(1.0, Num.f(curve_at[2])))
	var tex := CurveTexture.new()
	tex.curve = c
	mat.scale_curve = tex


static func ramp(colors: Array, offsets: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	g.offsets = PackedFloat32Array(offsets)
	var tex := GradientTexture1D.new()
	tex.use_hdr = true
	tex.gradient = g
	return tex


## A soft smoke puff (the city's smoke shader, lit dimly by the scene).
static func _puff() -> QuadMesh:
	var quad := QuadMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = SMOKE
	quad.material = mat
	return quad


## A round, soft-edged, camera-facing sprite in the particle's colour (unshaded: it glows).
static func _soft_quad() -> QuadMesh:
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
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var quad := QuadMesh.new()
	quad.material = mat
	return quad
