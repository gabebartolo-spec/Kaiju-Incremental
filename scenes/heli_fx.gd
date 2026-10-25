class_name HeliFx
extends RefCounted
## The recipes a downed helicopter is drawn with (HeliWreck), each one an existing family's owner
## (docs/VFX_STYLE.md): the flash is family 5's flare shader, the fireball is family 1's flame
## voxel (Fire's shader, ramp and voxel size) thrown in a ball, the smoke is family 2's shader.
## Numbers: tuning "heli_wreck". Presentation only.

const FLARE := preload("res://scenes/flare.gdshader")
## A flash is the shell-hit orange-white, hot at the core.
const FLASH_TINT := Color("ffb468")
## Fire's flame ramp spending less of its life cream: the same four colours (Fire.FLAME_COLORS),
## at stops that suit a fireball seen at the game camera, not a street fire.
const FIREBALL_STOPS: Array[float] = [0.0, 0.22, 0.5, 0.85]


## A flash of light: a hot core, a halo and short rays (flare.gdshader), `size` metres across,
## fading out over `seconds`.
static func flare(parent: Node3D, at: Vector3, size: float, seconds: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var mat := ShaderMaterial.new()
	mat.shader = FLARE
	mat.set_shader_parameter("tint", FLASH_TINT)
	mat.set_shader_parameter("ray_gain", 0.0)  # a soft burst of light, no straight streaks
	quad.material = mat
	var flash := MeshInstance3D.new()
	flash.mesh = quad
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.position = at
	parent.add_child(flash)
	var bright := PlayerSettings.flash_scale()  # Reduce flashing (D-259)
	var tween := flash.create_tween()
	tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("fade", (1.0 - v) * bright),
		0.0,
		1.0,
		seconds
	)
	tween.tween_callback(flash.queue_free)


## A sudden ball of Fire's own flame voxels (same 0.18 m cube, shader and ramp), thrown out
## in every direction, slowing as it blooms and rising as it cools. `scale` multiplies how many
## and how far (a crash's is smaller than a kill's).
static func fireball(parent: Node3D, at: Vector3, cfg: Dictionary, scale := 1.0) -> void:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = Num.f(cfg["fireball_radius"]) * scale
	mat.direction = Vector3.UP
	mat.spread = 180.0
	mat.initial_velocity_min = Num.f(cfg["fireball_speed_min"]) * scale
	mat.initial_velocity_max = Num.f(cfg["fireball_speed_max"]) * scale
	mat.damping_min = 0.4
	mat.damping_max = 0.9
	mat.gravity = Vector3(0, Num.f(cfg["fireball_rise"]), 0)  # hot gas climbs: a rolling fireball
	mat.scale_min = 0.8
	mat.scale_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.1))
	var tex := CurveTexture.new()
	tex.curve = curve
	mat.scale_curve = tex
	var ramp := Gradient.new()
	var stops: Array[Color] = []  # the ramp's hexes as they read on screen (the shader is linear)
	for hex: Color in Fire.FLAME_COLORS:
		stops.append(hex.srgb_to_linear())
	ramp.colors = PackedColorArray(stops)
	ramp.offsets = PackedFloat32Array(FIREBALL_STOPS)
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.18
	var hot := ShaderMaterial.new()
	hot.shader = Fire.EMBER_SHADER
	hot.set_shader_parameter("heat", Num.f(cfg["fireball_heat"]))  # per-owner heat
	cube.material = hot
	var life := Num.f(cfg["fireball_seconds"])
	var voxels := roundi(Num.f(cfg["fireball_voxels"]) * scale)
	_burst(parent, mat, cube, voxels, life, at, Num.f(cfg["fireball_spread"]))


## A puff of the smoke shader (Fire's own charcoal ramp, its first stop warmed by the flames
## under it): `puffs` quads `size` across billowing up and leaning with the wind.
static func smoke_puff(parent: Node3D, at: Vector3, cfg: Dictionary, scale := 1.0) -> void:
	var size := Num.f(cfg["smoke_size"]) * scale
	var mat := _smoke_mat(cfg)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = size * 0.2
	mat.direction = Vector3.UP
	mat.spread = 100.0
	mat.initial_velocity_min = Num.f(cfg["smoke_speed"]) * 0.4 * scale
	mat.initial_velocity_max = Num.f(cfg["smoke_speed"]) * scale
	mat.damping_min = 0.8
	mat.damping_max = 1.6
	var puffs := roundi(Num.f(cfg["smoke_puffs"]) * scale)
	_burst(parent, mat, _smoke_quad(size, cfg), puffs, Num.f(cfg["smoke_seconds"]), at)


## A thick smoke trail for a wreck on the move: puffs left in the air along its way (the
## particles stay where they are born), rising and leaning with the wind. The caller moves the
## node and calls go_out_trail when the wreck lands.
static func smoke_trail(parent: Node3D, cfg: Dictionary) -> GPUParticles3D:
	var size := Num.f(cfg["trail_smoke_size"])
	var dark := cfg.duplicate()  # a trail is darker and less self-lit than a fresh burst's smoke
	dark["smoke_warm"] = cfg["trail_warm"]
	dark["smoke_mid"] = cfg["trail_mid"]
	dark["smoke_self_lit"] = cfg["trail_self_lit"]
	dark["smoke_alpha"] = cfg["trail_alpha"]
	var mat := _smoke_mat(dark)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = size * 0.15
	mat.direction = Vector3.UP
	mat.spread = 60.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 1.2
	var p := GPUParticles3D.new()
	p.amount_ratio = GraphicsPresets.cap("particles")
	p.process_material = mat
	p.draw_pass_1 = _smoke_quad(size, dark)
	p.amount = Num.i(cfg["trail_puffs"])
	p.lifetime = Num.f(cfg["trail_smoke_seconds"])
	p.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 60, 80))
	parent.add_child(p)
	return p


## Stops a trail making smoke; what is in the air finishes, then it frees itself.
static func end_trail(trail: GPUParticles3D) -> void:
	trail.emitting = false
	if trail.is_inside_tree():
		trail.get_tree().create_timer(trail.lifetime + 0.2).timeout.connect(trail.queue_free)
	else:
		trail.queue_free()


static func _smoke_mat(cfg: Dictionary) -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.gravity = Fire.WIND * 0.7 + Vector3(0, 1.6, 0)
	mat.angular_velocity_min = -40.0
	mat.angular_velocity_max = 40.0
	mat.scale_min = 0.7
	mat.scale_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 1.7))
	var tex := CurveTexture.new()
	tex.curve = curve
	mat.scale_curve = tex
	var warm := Color(str(cfg["smoke_warm"]))
	var mid := Color(str(cfg["smoke_mid"]))
	var stops: Array[Color] = []  # Fire's charcoal ramp, young smoke glowing with the flames under it
	stops.append_array(Fire.SMOKE_COLORS)
	var thick := Num.f(cfg["smoke_alpha"])  # denser than a street fire's smoke
	stops[1] = Color(warm.r, warm.g, warm.b, minf(1.0, stops[1].a * thick))
	stops[2] = Color(mid.r, mid.g, mid.b, minf(1.0, stops[2].a * thick))
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray(stops)
	ramp.offsets = PackedFloat32Array([0.0, 0.08, 0.45, 1.0])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	return mat


static func _smoke_quad(size: float, cfg: Dictionary) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var draw := ShaderMaterial.new()
	draw.shader = Fire.SMOKE_SHADER
	# Part of the colour as the smoke's own glow (the flames under it), so it shows at night.
	draw.set_shader_parameter("self_lit", Num.f(cfg["smoke_self_lit"]))
	draw.set_shader_parameter("centre_keep", Num.f(cfg["smoke_centre_keep"]))
	quad.material = draw
	return quad


static func _burst(
	parent: Node3D,
	mat: ParticleProcessMaterial,
	mesh: Mesh,
	amount: int,
	life: float,
	at: Vector3,
	explosive := 0.95
) -> void:
	var p := GPUParticles3D.new()
	p.amount_ratio = GraphicsPresets.cap("particles")
	p.process_material = mat
	p.draw_pass_1 = mesh
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = explosive
	p.emitting = true
	p.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 60, 80))
	p.position = at
	parent.add_child(p)
	parent.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)
