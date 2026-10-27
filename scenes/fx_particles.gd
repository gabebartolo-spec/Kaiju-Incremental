class_name FxParticles
extends RefCounted
## Particle recipes for the power effects (AbilityFx): glowing voxels that shrink as they fly; and
## the dust his stone chunks trail as he shatters (DeathView).
## Presentation only.

const EMBER := preload("res://scenes/ember.gdshader")
## Share of a spark's life it stays white-hot before it cools to its tint, and its cone (degrees).
const SPARK_WHITE := 0.15
const SPARK_SPREAD := 35.0


## The glow left behind a leaping kaiju.
static func trail(tint: Color, body_scale: float) -> ParticleProcessMaterial:
	var mat := _base(tint.lightened(0.2), tint.darkened(0.4))
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.2 * body_scale
	mat.spread = 180.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 1.0
	mat.gravity = Vector3(0, -1.0, 0)
	_shrink(mat, 1.2 * body_scale)
	return mat


## Motes rising off a healing body.
static func motes(tint: Color, body_scale: float) -> ParticleProcessMaterial:
	var mat := _base(tint, Color(tint, 0.0))
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(1.0, 2.0, 1.0) * body_scale
	mat.direction = Vector3.UP
	mat.spread = 15.0
	mat.initial_velocity_min = 0.6
	mat.initial_velocity_max = 1.4
	mat.gravity = Vector3(0, 0.8, 0)
	_shrink(mat, 1.0 + 0.3 * body_scale)
	return mat


## Droplets flung off a ring of radius `radius`, swirling the way the lash turns.
static func spray(radius: float, tint: Color) -> ParticleProcessMaterial:
	var mat := _base(tint.lightened(0.3), tint)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_radius = radius * 1.05
	mat.emission_ring_inner_radius = radius * 0.85
	mat.emission_ring_height = 0.2
	mat.direction = Vector3.UP
	mat.spread = 35.0
	mat.radial_velocity_min = 3.0
	mat.radial_velocity_max = 7.0
	mat.orbit_velocity_min = 0.25
	mat.orbit_velocity_max = 0.45
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 7.0
	mat.gravity = Vector3(0, -16, 0)
	_shrink(mat, 1.0)
	return mat


## The game's one spark (docs/VFX_STYLE.md family 5): white-hot for the first SPARK_WHITE of its
## life, then `tint` (orange for a shell or the breath), dimming as it dies; thrown up in a cone,
## so set its direction after. Drawn as a glow cube (glow_cube) the bloom catches.
static func sparks(tint: Color) -> ParticleProcessMaterial:
	var mat := _base(Color.WHITE, tint)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, SPARK_WHITE, 1.0])
	ramp.colors = PackedColorArray([Color.WHITE, tint, tint.darkened(0.45)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	mat.spread = SPARK_SPREAD
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 16.0
	mat.gravity = Vector3(0, -18, 0)
	_shrink(mat, 1.0)
	return mat


## A glowing voxel `size` across, bright enough for the bloom.
static func glow_cube(size: float) -> BoxMesh:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * size
	var mat := ShaderMaterial.new()
	mat.shader = EMBER
	cube.material = mat
	return cube


## One dust puff for every trail of a death (FxParticles.dust_trail): Fx's smoke puff in the
## street dust, self-lit as Fx draws it, with the screen-centre clearing off (the chunks fly from
## where he stood, the middle of the view; Fx does the same for a footfall).
static func dust_puff() -> QuadMesh:
	var quad := QuadMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = Fx.SMOKE
	mat.set_shader_parameter("self_lit", Fx.DUST_SELF_LIT)
	mat.set_shader_parameter("centre_keep", 1.0)
	mat.set_shader_parameter("focus_clear", 0.0)
	mat.set_shader_parameter("focus_full", 0.001)
	quad.material = mat
	return quad


## The dust a flying chunk of his stone trails as he shatters (DeathView; director 2026-10-27,
## D-323: "tumbling with dust"): the street's dust (Fx's tone, one dust look), let out as the
## emitter moves and left hanging where it passed, then rising and spreading. `size`: the chunk's
## (world units); `o`: tuning death.look.trail; `puff`: dust_puff(). Stop it with emitting = false.
static func dust_trail(size: float, o: Dictionary, puff: QuadMesh) -> GPUParticles3D:
	var dust := Fx._dust_light()
	var mat := _base(Color(dust, Num.f(o["alpha"])), Color(dust, 0.0))
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = size * 0.4
	mat.direction = Vector3.UP
	mat.spread = 180.0
	mat.initial_velocity_max = Num.f(o["rise"])
	mat.gravity = Vector3(0, Num.f(o["rise"]), 0)
	mat.scale_min = size * Num.f(o["size"]) * 0.7
	mat.scale_max = size * Num.f(o["size"]) * 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 1.6))
	FxCurve.set_scale(mat, curve)
	var p := GPUParticles3D.new()
	p.amount_ratio = GraphicsPresets.cap("particles")  # R 18.3
	p.process_material = mat
	p.draw_pass_1 = puff
	p.amount = Num.i(o["amount"])
	p.lifetime = Num.f(o["life"])
	p.local_coords = false
	return p


static func _base(start: Color, end: Color) -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.damping_min = 0.5
	mat.damping_max = 1.5
	mat.angular_velocity_min = -180.0
	mat.angular_velocity_max = 180.0
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([start, end])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	return mat


## Particles start at `size` and shrink to nothing over their life.
static func _shrink(mat: ParticleProcessMaterial, size: float) -> void:
	mat.scale_min = size * 0.6
	mat.scale_max = size
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.0))
	FxCurve.set_scale(mat, curve)
