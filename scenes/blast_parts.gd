class_name BlastParts
extends RefCounted
## The pieces a red-barrel blast is drawn from (BlastFx; director comments #19, #20), each a
## one-shot node that frees itself: the white-hot flash that marks the instant, the fireball, the
## fireworks bursts and the chem lab's billowing green cubes. The FIREBALL IS THE GAME'S OWN FIRE
## (director 2026-10-22: "doesnt match the fire we use the rest of the time, consistency is
## absolutely key"): the glowing flame voxels of Fire (its ember shader, its flame colours and
## their ramp), thrown out of the site and shrinking out, scaled up for a blast; its smoke is
## Fire's own soft smoke column, left by BlastFx (CityView.fire). Debris and the dust ring stay
## solid voxels. All start from the site's own box (`half`: its half extents, `at` its centre), so
## a blast always comes out of a building, never out of the air. The ground shock is BlastShock.
## Sizes come from the sim's blast radius, looks from data/tuning.json "blast_fx". Presentation
## only.

const EMBER := preload("res://scenes/blast_ember.gdshader")
const VOXEL := preload("res://scenes/blast_voxel.gdshader")
## Where on a flame's life each of Fire.FLAME_COLORS sits: Fire's own colours, in a shorter ball's
## time (the flames of a ball that lives 1.6 s are red-orange within half a second).
const FLAME_AT: Array[float] = [0.0, 0.03, 0.15, 0.7]
## The flash's voxels: hotter than the fireball, gone in a few frames.
## Yellow-white, capped so the flash blooms without whiting out the screen (round 5).
const FLASH: Array[Color] = [Color(2.2, 2.0, 1.25, 1.0), Color(2.0, 1.2, 0.35, 1.0)]


## Flame voxels (Fire's ember shader, flame colours and ramp) thrown up and out of the site's own
## box, so the ball grows from the site and never pops in wide, cooling from yellow-white through
## orange to dark as they slow and shrink; damped to stop fireball.reach_scale x (the rise to
## top_scale site heights) away (a cube at speed v stops after v^2 / 2 damping).
static func fireball(
	host: Node3D, at: Vector3, half: Vector3, radius: float, cfg: Dictionary
) -> void:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = half
	mat.direction = Vector3.UP
	mat.spread = 80.0
	var speed := radius * Num.f(cfg["speed_scale"])
	var size := radius * Num.f(cfg["size"])
	var rise := maxf(0.4, half.y * 2.0 * Num.f(cfg["top_scale"]) - half.y * 2.0)
	rise *= Num.f(cfg["reach_scale"])
	mat.initial_velocity_min = speed * 0.5
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, Num.f(cfg["lift"]), 0)  # hot air: a little rise as it burns out
	mat.damping_min = speed * speed / (2.0 * rise)
	mat.damping_max = mat.damping_min * 1.3
	mat.scale_min = 0.5 * size  # Fire's flame spread of sizes
	mat.scale_max = 1.2 * size
	var size_curve: Array = cfg["size_curve"]
	mat.scale_curve = _boil(size_curve)
	mat.color_ramp = ramp(Fire.FLAME_COLORS, FLAME_AT)
	var life := Num.f(cfg["seconds"])
	var amount := roundi(Num.f(cfg["amount"]) * clampf(radius / 5.0, 0.5, 1.6))
	var p := emit(host, mat, flame_cube(Num.f(cfg["heat"])), amount, life, at)
	p.explosiveness = 1.0 - Num.f(cfg["build_seconds"]) / life  # it builds over a few frames


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
	emit(host, mat, ember_cube(), amount, seconds, at)


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


## The chem lab's cloud: green cubes in cloud.shades, billowing up and out of a box twice the
## lab's size (at least cloud_share of the sim cloud's radius wide; `half` is the lab's half
## extents): a burst at once, then a steady boil for as long as the sim keeps the cloud
## (`seconds`), each cube growing and then shrinking away.
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
	mat.angular_velocity_min = -25.0
	mat.angular_velocity_max = 25.0
	var sizes: Array = cfg["voxel"]
	mat.scale_min = Num.f(sizes[0])
	mat.scale_max = Num.f(sizes[1])
	var boil_at: Array = cfg["boil"]
	mat.scale_curve = _boil(boil_at)
	var shades: Array = cfg["shades"]
	var glow := Num.f(cfg["glow"])  # just over 1: a faint green glow (blast_voxel)
	mat.color_initial_ramp = _shades(shades.map(func(c: String) -> Color: return Color(c) * glow))
	var life := Num.f(cfg["billow_seconds"])
	var burst := emit(host, mat, voxel_cube(), Num.i(cfg["amount"]), life, at)
	burst.explosiveness = 0.8
	var boil := emit(host, mat, voxel_cube(), Num.i(cfg["boil_amount"]), life, at, seconds + life)
	boil.one_shot = false
	boil.explosiveness = 0.0
	# The boil stops a cube's life before the sim's cloud ends, so the last cubes shrink out
	# by then: the cloud fades over its last billow_seconds rather than hanging on.
	host.get_tree().create_timer(maxf(0.1, seconds - life)).timeout.connect(
		func() -> void:
			if is_instance_valid(boil):
				boil.emitting = false
	)


## A cube's size over its life from [life share, scale] points (the fireball's size_curve; the
## gas's cloud.boil: growing in, swelling and sagging, then shrinking away: a boil, never a
## frozen block).
static func _boil(points: Array) -> CurveTexture:
	var c := Curve.new()
	c.max_value = 4.0
	for pt: Array in points:
		c.add_point(Vector2(Num.f(pt[0]), Num.f(pt[1])))
	var tex := CurveTexture.new()
	tex.curve = c
	return tex


## A unit voxel drawn opaque and lit (blast_voxel.gdshader): fireball, smoke, gas, dust.
static func voxel_cube() -> BoxMesh:
	var cube := BoxMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = VOXEL
	cube.material = mat
	return cube


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


## A unit voxel drawn with Fire's own ember shader: the game's flame cube. `heat` is the shader's
## own uniform: a dense ball of flames blooms and whitens at Fire's 1.4, so a blast's runs cooler.
static func flame_cube(heat: float) -> BoxMesh:
	var cube := BoxMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = Fire.EMBER_SHADER
	mat.set_shader_parameter("heat", heat)
	cube.material = mat
	return cube


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
