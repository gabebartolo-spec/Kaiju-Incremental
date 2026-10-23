class_name HeliFx
extends RefCounted
## The recipes a downed helicopter is drawn with (HeliWreck), each one an existing family's owner
## (docs/VFX_STYLE.md): the flash is family 5's flare shader, the fireball is family 1's flame
## flame (Fire's smooth tongues) thrown in a ball, the smoke is family 2's shader.
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
	mat.set_shader_parameter("fade", 1.0)  # full on the very first frame it is drawn
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


## The explosion's ball of fire: Fire's own smooth flame (its tongue mesh and shader, coloured by
## height), thrown out of a box about the helicopter's size and over `ball.build` seconds, so the
## youngest flames, small, sit in the middle and push the older out, shrinking at the rim, which
## turbulence pulls into lobes. It rises as it burns. `scale` multiplies the box and the throw (a
## crash's is smaller than a kill's).
static func fireball(parent: Node3D, at: Vector3, cfg: Dictionary, scale := 1.0) -> void:
	var ball: Dictionary = cfg["ball"]
	var wide := Num.f(cfg["fireball_radius"]) * scale
	var half := Vector3(wide, Num.f(cfg["fireball_height"]) * scale, wide)
	var tongue := Fire.flame_mesh(Num.f(ball["tongue"]), at.x + at.z)  # Fire's smooth tongue
	var flame := tongue.material as ShaderMaterial  # graded by height from the ball's foot up
	flame.set_shader_parameter("base_y", at.y - wide)
	flame.set_shader_parameter("flame_h", Num.f(ball["flame_h"]) * scale)
	var life := Num.f(ball["seconds"])
	var amount := roundi(Num.f(ball["amount"]) * scale)
	_burst(
		parent,
		_ball_material(ball, half, scale),
		tongue,
		amount,
		life,
		at,
		1.0 - Num.f(ball["build"]) / life
	)


## The ball's particle physics: out of `half` in every direction, damped so the oldest flames stop
## at the rim, lifted, pulled into lobes by turbulence, shrinking from a small start.
static func _ball_material(
	ball: Dictionary, half: Vector3, scale: float
) -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = half
	mat.direction = Vector3.UP
	mat.spread = 180.0
	var throw: Array = ball["speed"]
	mat.initial_velocity_min = Num.f(throw[0]) * scale
	mat.initial_velocity_max = Num.f(throw[1]) * scale
	mat.damping_min = Num.f(ball["damping"])
	mat.damping_max = Num.f(ball["damping"]) * 1.4
	mat.gravity = Vector3(0, Num.f(ball["lift"]), 0)
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = Num.f(ball["turbulence"])
	mat.turbulence_noise_scale = Num.f(ball["turbulence_scale"])
	mat.turbulence_influence_min = 0.4
	mat.turbulence_influence_max = 1.0
	mat.scale_min = 0.8
	mat.scale_max = 1.2
	var shrink: Array = ball["shrink"]  # size: young and small, full in the body, a speck at the rim
	var sizes := Curve.new()
	for pt: Vector2 in [
		Vector2(0.0, Num.f(shrink[0])),
		Vector2(0.15, 1.0),
		Vector2(0.6, Num.f(shrink[1])),
		Vector2(1.0, Num.f(shrink[2]))
	]:
		sizes.add_point(pt)
	var sizes_tex := CurveTexture.new()
	sizes_tex.curve = sizes
	mat.scale_curve = sizes_tex
	var ramp := Gradient.new()  # only the life fade: the colour is the flame shader's, by height
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.06, 0.8, 1.0])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	return mat


## The smoke of a kill: a plume of the smoke shader's puffs (family 2) thrown up from `lobe_base`
## above the fire, rising and leaning with the wind over `plume_seconds`, so it stands above and
## behind the flames and never in the middle of them.
static func smoke_puff(parent: Node3D, at: Vector3, cfg: Dictionary, scale := 1.0) -> void:
	var tinted := cfg.duplicate()  # young smoke glows with the flames under it, then goes charcoal
	tinted["smoke_warm"] = cfg["plume_warm"]
	tinted["smoke_mid"] = cfg["plume_mid"]
	var mat := _smoke_mat(tinted)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = Num.f(cfg["lobe_spread"]) * scale
	mat.direction = Vector3(0, 1, -0.4)  # up and away from the camera
	mat.spread = 35.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 3.5
	var rise := Vector3(0, Num.f(cfg["lobe_base"]) * scale, 0)
	var puffs := maxi(1, roundi(Num.f(cfg["plume_puffs"]) * scale))
	var quad := _smoke_quad(Num.f(cfg["lobe_size"]) * scale, cfg)
	_burst(parent, mat, quad, puffs, Num.f(cfg["plume_seconds"]), at + rise, 0.5)


## Fire's options for a flame body: Fire's zoom (the same fire with every size and speed
## multiplied: flames `flame_zoom` times larger, taller than wide and overlapping, so they read as
## one body at the game camera), the smoke kept at street size and thinned to `smoke`.
static func tongues(cfg: Dictionary, smoke: float, zoom_to := 0.0) -> Dictionary:
	var zoom := zoom_to if zoom_to > 0.0 else Num.f(cfg["flame_zoom"])
	return {
		"zoom": zoom,
		"smoke_share": 1.0 / zoom,
		"density": Num.f(cfg["flame_density"]),
		"wind": 1.0,
		"puff": 1.0,
		"ember_density": 0.2,
		"smoke_density": smoke,
	}


## A Fire of tongues that rides a moving part: its flames are born in the part's own space (they
## move with it, never left behind as a rope of cubes), its smoke trails.
static func riding_fire(
	size: float, seed_value: float, cfg: Dictionary, smoke: float, zoom := 0.0
) -> Fire:
	var fire := Fire.new(size, seed_value, tongues(cfg, smoke, zoom))
	var moving := 0
	for child: Node in fire.get_children():
		if child is GPUParticles3D and moving < 1:  # the first is the flames
			(child as GPUParticles3D).local_coords = true
			moving += 1
	return fire


## A thick smoke trail for a wreck on the move: puffs left in the air along its way (the
## particles stay where they are born), rising and leaning with the wind. The caller moves the
## node and calls go_out_trail when the wreck lands.
static func smoke_trail(parent: Node3D, cfg: Dictionary, share := 1.0) -> GPUParticles3D:
	var size := Num.f(cfg["trail_smoke_size"]) * share
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
	p.amount = maxi(1, roundi(Num.f(cfg["trail_puffs"]) * share))
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
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 60, 80))
	p.position = at
	parent.add_child(p)
	parent.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)
