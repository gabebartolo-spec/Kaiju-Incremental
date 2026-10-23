class_name HeliFx
extends RefCounted
## The recipes a downed helicopter is drawn with (HeliWreck), each one an existing family's owner
## (docs/VFX_STYLE.md): the flash is family 5's flare shader, the fireball is family 1's flame
## voxel (Fire's shader, ramp and voxel size) thrown in a ball, the smoke is family 2's shader.
## Numbers: tuning "heli_wreck". Presentation only.

const FLARE := preload("res://scenes/flare.gdshader")
## A flash is the shell-hit orange-white, hot at the core.
const FLASH_TINT := Color("ffb468")


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
	var tween := flash.create_tween()
	tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("fade", 1.0 - v), 0.0, 1.0, seconds
	)
	tween.tween_callback(flash.queue_free)


## The explosion look: the shared blast recipe (BlastParts.fireball, Fire's own flames in a sudden
## tall burst) out of a box about the helicopter's size. `scale` multiplies the box and the blast
## radius (a crash's is smaller than a kill's).
static func fireball(parent: Node3D, at: Vector3, cfg: Dictionary, scale := 1.0) -> void:
	var wide := Num.f(cfg["fireball_radius"]) * scale
	var half := Vector3(wide, Num.f(cfg["fireball_height"]) * scale, wide)
	var blast := Num.f(cfg["fireball_blast_radius"]) * scale
	var recipe: Dictionary = Content.section("blast_fx")["fireball"]  # the city's own blast numbers
	BlastParts.fireball(parent, at, half, blast, recipe)
	var core: Dictionary = Content.section("blast_fx")["core"]  # the white-hot instant
	BlastParts.core(parent, at, half, Num.f(cfg["core_radius"]) * scale, core)  # its own size


## A smoke cloud of lobed puffs: the street's own puffs (Fx.dust, the smoke shader's noisy round
## masks) tinted charred dark, stacked up and sideways so the cloud has lobes, not one round disc.
static func smoke_puff(city: CityView, at: Vector3, cfg: Dictionary, scale := 1.0) -> void:
	var tint := Color(str(cfg["lobe_tint"]), Num.f(cfg["lobe_alpha"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(at)  # the same blast puffs the same way
	var lobes := maxi(1, roundi(Num.f(cfg["lobes"]) * scale))
	for n: int in lobes:
		var side := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
		var up := Vector3(0.0, Num.f(cfg["lobe_rise"]) * scale * n / lobes, 0.0)
		city.fx.dust(
			at + side * Num.f(cfg["lobe_spread"]) * scale + up,
			Num.f(cfg["lobe_size"]) * scale,
			tint
		)


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
