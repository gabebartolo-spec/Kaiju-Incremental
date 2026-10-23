class_name BlastParts
extends RefCounted
## The pieces a red-barrel blast is drawn from (BlastFx; director comments #19, #20), each a
## one-shot node that frees itself. The blast is the GAME'S OWN FIRE (director 2026-10-22, D-151:
## "consistency is absolutely key"): a sudden tall burst of Fire's flames, then that fire stays
## burning (BlastFx leaves a real Fire at the site, with its light and its smoke). The burst
## uses Fire's flame exactly: its voxel (Fire.FLAME_CUBE at Fire.FLAME_SCALE), its ember shader at
## its own heat, its colours and their ramp, rising like Fire's flames (narrow spread, gravity up,
## shrinking to a tenth); a bigger blast is more flames, never bigger cubes. Also here: the
## white-hot flash that marks the instant, the fireworks bursts and the chem lab's gas, which is
## the game's soft smoke (smoke.gdshader) tinted green. All start from the site's own box (`half`:
## its half extents, `at` its centre), so a blast always comes out of a building, never out of
## the air. The ground shock is BlastShock. Sizes come from the sim's blast radius, looks from
## data/tuning.json "blast_fx". Presentation only.

## The flash's voxels: hotter than the fireball, gone in a few frames.
## Yellow-white, capped so the flash blooms without whiting out the screen (round 5).
const FLASH: Array[Color] = [Color(2.2, 2.0, 1.25, 1.0), Color(2.0, 1.2, 0.35, 1.0)]


## The burst: Fire's flame voxels (cube, sizes, ember shader at its own heat, colours, ramp) leaving
## the site's own box, emitted over fireball.burst_seconds at a high rate (so the column builds in a
## few frames and every blast grows its own), going up on a narrow spread with gravity up like
## Fire's flames, damped to stop `top_scale` site heights up, and shrinking to a tenth. `amount`
## flames at a blast radius of 5, more for a bigger one.
static func fireball(
	host: Node3D, at: Vector3, half: Vector3, radius: float, cfg: Dictionary
) -> void:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = half
	mat.direction = Vector3.UP
	mat.spread = Num.f(cfg["spread"])
	var speed := radius * Num.f(cfg["speed_scale"])
	var rise := maxf(0.4, half.y * 2.0 * (Num.f(cfg["top_scale"]) - 1.0))
	mat.initial_velocity_min = speed * 0.5
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, Num.f(cfg["lift"]), 0)
	mat.damping_min = speed * speed / (2.0 * rise)
	mat.damping_max = mat.damping_min * 1.3
	var grow := clampf(radius / 5.0, 1.0, 3.0)  # a blast past radius 5 has bigger flames, so it
	mat.scale_min = Fire.FLAME_SCALE.x * grow  # reads as one body at the game camera
	mat.scale_max = Fire.FLAME_SCALE.y * grow
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.1))
	var tex := CurveTexture.new()
	tex.curve = curve
	mat.scale_curve = tex
	var flame := Gradient.new()  # as Fire's own ramp: an ordinary 8-bit texture, not an HDR one
	flame.colors = PackedColorArray(Fire.FLAME_COLORS)
	flame.offsets = PackedFloat32Array(Fire.FLAME_AT)
	var flame_tex := GradientTexture1D.new()
	flame_tex.gradient = flame
	mat.color_ramp = flame_tex
	var life := Num.f(cfg["seconds"])
	var amount := roundi(Num.f(cfg["amount"]) * clampf(radius / 5.0, 0.5, 1.6))
	var p := emit(host, mat, flame_cube(), amount, life, at)
	p.explosiveness = 1.0 - Num.f(cfg["burst_seconds"]) / life  # it spawns over burst_seconds


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
	var strength := clampf(radius / Num.f(cfg["full_radius"]), 0.5, 1.0)  # a small blast flashes less
	mat.color_ramp = ramp(FLASH.map(func(c: Color) -> Color: return c * strength), [0.0, 1.0])
	var amount := roundi(Num.f(cfg["amount"]) * clampf(radius / 5.0, 0.5, 1.6))
	emit(host, mat, spark_cube(), amount, seconds, at)


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
	emit(host, mat, spark_cube(), Num.i(cfg["sparks"]), Num.f(cfg["seconds"]), at)


## The chem lab's cloud: the game's soft smoke (smoke.gdshader, as Fire's column) tinted toxic
## green in cloud.shades, billowing up and out of a box twice the lab's size (at least cloud_share
## of the sim cloud's radius wide; `half` is the lab's half extents): a burst at once, then a
## steady boil for as long as the sim keeps the cloud (`seconds`), each puff swelling and sagging
## on cloud.boil and fading out.
static func toxic_cloud(
	host: Node3D, at: Vector3, half: Vector3, radius: float, seconds: float, cfg: Dictionary
) -> void:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	var wide := radius * Num.f(cfg["cloud_share"])
	var box := half * Num.f(cfg["size_scale"])
	mat.emission_box_extents = Vector3(maxf(box.x, wide), box.y, maxf(box.z, wide))
	mat.direction = Vector3.UP
	mat.spread = 90.0
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.6
	mat.gravity = Vector3(0.3, 0.35, 0.15)
	mat.damping_min = 0.3
	mat.damping_max = 0.6
	var sizes: Array = cfg["puff"]
	mat.scale_min = Num.f(sizes[0])
	mat.scale_max = Num.f(sizes[1])
	var boil_at: Array = cfg["boil"]
	mat.scale_curve = _boil(boil_at)
	var shades: Array = cfg["shades"]
	mat.color_initial_ramp = _shades(shades.map(func(c: String) -> Color: return Color(c)))
	var fade := Gradient.new()  # the puff's own opacity over its life, white so the shade stays
	fade.colors = PackedColorArray(
		[Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)]
	)
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	mat.color_ramp = fade_tex
	var life := Num.f(cfg["billow_seconds"])
	var burst := emit(host, mat, smoke_quad(), Num.i(cfg["amount"]), life, at)
	burst.explosiveness = 0.8
	var boil := emit(host, mat, smoke_quad(), Num.i(cfg["boil_amount"]), life, at, seconds + life)
	boil.one_shot = false
	boil.explosiveness = 0.0
	# The boil stops a puff's life before the sim's cloud ends, so the last puffs fade out by
	# then: the cloud thins over its last billow_seconds rather than hanging on.
	host.get_tree().create_timer(maxf(0.1, seconds - life)).timeout.connect(
		func() -> void:
			if is_instance_valid(boil):
				boil.emitting = false
	)


## A puff's size over its life from [life share, scale] points (the gas's cloud.boil: growing in,
## swelling and sagging, then shrinking away: a boil, never a frozen block).
static func _boil(points: Array) -> CurveTexture:
	var c := Curve.new()
	c.max_value = 4.0
	for pt: Array in points:
		c.add_point(Vector2(Num.f(pt[0]), Num.f(pt[1])))
	var tex := CurveTexture.new()
	tex.curve = c
	return tex


## A camera-facing soft smoke puff, the game's own (smoke.gdshader): a unit quad to scale.
static func smoke_quad() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = Fire.SMOKE_SHADER
	quad.material = mat
	return quad


## Each particle's starting shade, picked from `colors` at random (no blend between them).
static func _shades(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	for k: int in colors.size():
		offsets.append(float(k) / colors.size())
	g.offsets = offsets
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex


## Fire's own flame voxel: its cube, drawn with its ember shader at its own heat.
static func flame_cube() -> BoxMesh:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * Fire.FLAME_CUBE
	var mat := ShaderMaterial.new()
	mat.shader = Fire.EMBER_SHADER
	cube.material = mat
	return cube


## A unit spark voxel (the flash's core, a firework's sparks): the same ember shader, at heat 1
## because their colours are already pushed above white.
static func spark_cube() -> BoxMesh:
	var cube := BoxMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = Fire.EMBER_SHADER
	mat.set_shader_parameter("heat", 1.0)
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
