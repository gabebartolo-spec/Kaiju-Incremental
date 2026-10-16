class_name AbilityFx
extends Node3D
## The look of every unlockable power, presentation only (D-026). Each signature attack has its
## own shape: Atomic Breath a plasma beam that scorches a wedge into the street, Leap Slam a
## trail through the air and a glowing crater, Tentacle Lash an arc whipping round the kaiju.
## Upgrades show too: Signature Power brightens the attack, heavy stomps crack the street,
## Signature Recharge pulses when the attack is ready, Regeneration sheds green motes, Armoured
## Scales throw shells off in a cold glint. Nothing here hides the kaiju (D-025): no smoke above
## knee height, glow is additive and narrow, dust uses the camera-safe smoke shader.

const BEAM := preload("res://scenes/beam.gdshader")
const SCORCH := preload("res://scenes/scorch.gdshader")
const SWEEP := preload("res://scenes/sweep.gdshader")
const EMBER := preload("res://scenes/ember.gdshader")
const STREET := Color("3a3d40")
const MOLTEN := Color("ff7a2a")

## Every effect played, in order ("breath", "leap", "lash", "cracks", "ready", "deflect",
## "regen");
## read by the flow suite to prove each power leaves its own mark.
var played: Array[String] = []
var _city: CityView
var _tint: Color
var _scale: float
var _tune: Dictionary
var _trail: GPUParticles3D
var _regen: GPUParticles3D
var _glint_mesh: BoxMesh


## tint: the species' eye colour; body_scale: the kaiju's size this run.
func _init(city: CityView, tint: Color, body_scale: float) -> void:
	_city = city
	_tint = tint
	_scale = body_scale
	_tune = Content.section("fx")


func _ready() -> void:
	_glint_mesh = _glow_cube(0.14)
	_trail = _emitter(_trail_mat(), _glow_cube(0.3), 70, Num.f(_tune["leap_trail_seconds"]))
	_regen = _emitter(_regen_mat(), _glow_cube(0.12), 26, 1.5)
	# Prewarm every shader out of sight so the first real use does not stall a frame.
	var away := Vector3(0, -50, 0)
	breath(away, Vector3.FORWARD * 4.0, 0.5, 1.0)
	leap_land(away, 2.0, 1.0)
	lash(away, 2.0, 1.0)
	stomp_cracks(away, 2.0, 3.0)
	ready_pulse(away)
	deflect(away, Vector3.UP)
	played.clear()


## How far an upgraded stat is above the species' own value, as 1..power_max.
func power(value: float, base: float) -> float:
	return clampf(value / maxf(base, 0.001), 1.0, Num.f(_tune["power_max"]))


## Atomic Breath: a white-hot beam from the mouth along `span` (mouth to the street at full
## reach), a light racing down it, and a scorched wedge on the street that glows, then cools.
func breath(mouth: Vector3, span: Vector3, half_angle: float, strength: float) -> void:
	played.append("breath")
	var seconds := Num.f(_tune["beam_seconds"])
	var length := span.length()
	var reach := Vector2(span.x, span.z).length()
	var dir := span / maxf(length, 0.001)
	var cyl := CylinderMesh.new()
	cyl.height = length
	cyl.bottom_radius = 0.35 * _scale
	cyl.top_radius = reach * tan(half_angle) * 0.4
	cyl.radial_segments = 24
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var mat := _shader(BEAM, strength)
	cyl.material = mat
	var beam := MeshInstance3D.new()
	beam.mesh = cyl
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.basis = _basis_along(dir)
	beam.position = mouth + dir * length * 0.5
	add_child(beam)
	_drive(mat, "progress", seconds, beam)
	var light := _light(mouth, _tint.lightened(0.3), 6.0 * strength)
	var tween := light.create_tween()
	tween.tween_property(light, "position", mouth + span, seconds * 0.4)
	tween.tween_property(light, "light_energy", 0.0, seconds * 0.6)
	tween.tween_callback(light.queue_free)
	var feet := Vector3(mouth.x, mouth.y + span.y - 0.5, mouth.z)
	var flat := Vector3(dir.x, 0.0, dir.z)
	var mark := _mark(feet, reach * 2.0, 1, Num.f(_tune["scorch_seconds"]))
	if flat.length() > 0.01:
		mark.basis = Basis.looking_at(flat.normalized(), Vector3.UP)
	var scorch: ShaderMaterial = (mark.mesh as PlaneMesh).material
	scorch.set_shader_parameter("half_angle", half_angle)
	scorch.set_shader_parameter("glow", 2.0 + strength)


## Leap Slam lift-off: a kick of dust and a small ring where the kaiju left the ground.
func leap_takeoff(at: Vector3) -> void:
	_city.fx.dust(at + Vector3(0, 0.3, 0), 1.2 * _scale)
	_city.fx.shockwave(at, 2.5 * _scale, _tint)


## The streak behind the kaiju while it is in the air; on: false stops the trail.
func leap_trail(at: Vector3, on: bool) -> void:
	_trail.position = at
	_trail.emitting = on


## Leap Slam landing: a glowing crater with radial cracks, two shockwaves, street chunks
## thrown outward and a low ring of dust.
func leap_land(at: Vector3, reach: float, strength: float) -> void:
	played.append("leap")
	var crater := _mark(at, reach * 2.2, 0, Num.f(_tune["crater_seconds"]))
	var mat: ShaderMaterial = (crater.mesh as PlaneMesh).material
	mat.set_shader_parameter("crack_count", 11.0)
	mat.set_shader_parameter("glow", 3.0 + 2.0 * strength)
	_city.fx.shockwave(at, reach * 1.3, _tint)
	_city.fx.shockwave(at, reach * 0.8)
	for n: int in 12:
		var out := Vector3.FORWARD.rotated(Vector3.UP, TAU * n / 12.0)
		_city.debris(at + out * 0.8 + Vector3(0, 0.4, 0), STREET, out + Vector3(0, 1.2, 0))
	for n: int in 6:
		var out := Vector3.FORWARD.rotated(Vector3.UP, TAU * (n + 0.5) / 6.0)
		_city.fx.dust(at + out * reach * 0.55 + Vector3(0, 0.3, 0), 0.9 * _scale)
	_city.flash(at + Vector3(0, 1.5, 0), _tint, 7.0 * strength, 0.5)


## Tentacle Lash: one bright arc whipping round the kaiju at shin height, and spray flung off
## its edge.
func lash(centre: Vector3, reach: float, strength: float) -> void:
	played.append("lash")
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * reach * 2.0
	var mat := _shader(SWEEP, strength)
	plane.material = mat
	var sweep := MeshInstance3D.new()
	sweep.mesh = plane
	sweep.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sweep.position = Vector3(centre.x, 0.7 * _scale, centre.z)
	add_child(sweep)
	_drive(mat, "progress", Num.f(_tune["sweep_seconds"]), sweep)
	var spray := _burst(_spray_mat(reach), _glint_mesh, roundi(60 * strength), 0.9)
	spray.position = Vector3(centre.x, 0.8 * _scale, centre.z)
	_city.flash(centre + Vector3(0, 2.0, 0), _tint, 5.0 * strength, 0.45)


## Heavy stomps crack the street; past the threshold the cracks glow molten.
func stomp_cracks(at: Vector3, radius: float, strength: float) -> void:
	var from := Num.f(_tune["crack_stomp_power"])
	if strength < from:
		return
	played.append("cracks")
	var mark := _mark(at, radius * 2.0, 0, Num.f(_tune["crack_seconds"]))
	var mat: ShaderMaterial = (mark.mesh as PlaneMesh).material
	mat.set_shader_parameter("char_strength", 0.35)
	mat.set_shader_parameter("crack_count", 7.0)
	mat.set_shader_parameter("tint", MOLTEN)
	mat.set_shader_parameter("glow", 4.0 * (strength - from))


## Signature ready again: a halo rises from the feet to the shoulders.
func ready_pulse(at: Vector3) -> void:
	played.append("ready")
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(_tint, 0.9)
	torus.material = mat
	var halo := MeshInstance3D.new()
	halo.mesh = torus
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position = at + Vector3(0, 0.3, 0)
	halo.scale = Vector3(2.4, 0.4, 2.4) * _scale
	add_child(halo)
	var tween := halo.create_tween().set_parallel(true)
	tween.tween_property(halo, "position:y", at.y + 5.0 * _scale, 0.6)
	tween.tween_property(halo, "scale", Vector3(1.4, 0.4, 1.4) * _scale, 0.6)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tween.chain().tween_callback(halo.queue_free)


## Regeneration: green motes drift off the body while it heals.
func regen(body_centre: Vector3, healing: bool) -> void:
	_regen.position = body_centre
	if healing and not _regen.emitting:
		played.append("regen")
	_regen.emitting = healing


## Armoured Scales: a shell glances off, sparks thrown back the way it came in a cold glint.
func deflect(at: Vector3, away: Vector3) -> void:
	played.append("deflect")
	var mat := _spark_mat(Color(str(_tune["deflect_tint"])))
	mat.direction = away.normalized()
	var sparks := _burst(mat, _glint_mesh, 22, 0.5)
	sparks.position = at
	_city.flash(at, Color(str(_tune["deflect_tint"])), 3.0, 0.15)


## A mark on the street (scorch.gdshader) that cools and fades over `seconds`.
func _mark(at: Vector3, size: float, shape: int, seconds: float) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * size
	var mat := ShaderMaterial.new()
	mat.shader = SCORCH
	mat.set_shader_parameter("shape", shape)
	mat.set_shader_parameter("tint", _tint)
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(at.x, at.y + 0.07, at.z)
	add_child(mi)
	_drive(mat, "age", seconds, mi)
	return mi


func _shader(shader: Shader, strength: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", _tint)
	mat.set_shader_parameter("power", strength)
	return mat


## Runs a shader parameter 0..1 over `seconds`, then frees `owner`.
func _drive(mat: ShaderMaterial, param: String, seconds: float, owner_node: Node) -> void:
	var tween := owner_node.create_tween()
	tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter(param, v), 0.0, 1.0, seconds
	)
	tween.tween_callback(owner_node.queue_free)


func _light(at: Vector3, color: Color, energy: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 4.0 + energy
	light.position = at
	add_child(light)
	return light


func _basis_along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, y, x.cross(y))


func _emitter(mat: ParticleProcessMaterial, mesh: Mesh, amount: int, life: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = mat
	p.draw_pass_1 = mesh
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-20, -10, -20), Vector3(40, 30, 40))
	add_child(p)
	return p


func _burst(mat: ParticleProcessMaterial, mesh: Mesh, amount: int, life: float) -> GPUParticles3D:
	var p := _emitter(mat, mesh, amount, life)
	p.one_shot = true
	p.explosiveness = 0.85
	p.emitting = true
	get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)
	return p


func _trail_mat() -> ParticleProcessMaterial:
	var mat := _base_mat(_tint.lightened(0.2), _tint.darkened(0.4))
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.2 * _scale
	mat.spread = 180.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 1.0
	mat.gravity = Vector3(0, -1.0, 0)
	_shrink(mat, 1.2 * _scale)
	return mat


func _regen_mat() -> ParticleProcessMaterial:
	var tint := Color(str(_tune["regen_tint"]))
	var mat := _base_mat(tint, Color(tint, 0.0))
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(1.0, 2.0, 1.0) * _scale
	mat.direction = Vector3.UP
	mat.spread = 15.0
	mat.initial_velocity_min = 0.6
	mat.initial_velocity_max = 1.4
	mat.gravity = Vector3(0, 0.8, 0)
	_shrink(mat, 1.0 + 0.3 * _scale)
	return mat


func _spray_mat(reach: float) -> ParticleProcessMaterial:
	var mat := _base_mat(_tint.lightened(0.5), _tint)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_radius = reach * 0.8
	mat.emission_ring_inner_radius = reach * 0.6
	mat.emission_ring_height = 0.2
	mat.direction = Vector3.UP
	mat.spread = 35.0
	mat.radial_velocity_min = 3.0
	mat.radial_velocity_max = 7.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 7.0
	mat.gravity = Vector3(0, -16, 0)
	_shrink(mat, 1.0)
	return mat


func _spark_mat(tint: Color) -> ParticleProcessMaterial:
	var mat := _base_mat(Color.WHITE, tint)
	mat.spread = 50.0
	mat.initial_velocity_min = 6.0
	mat.initial_velocity_max = 11.0
	mat.gravity = Vector3(0, -18, 0)
	_shrink(mat, 1.0)
	return mat


func _base_mat(start: Color, end: Color) -> ParticleProcessMaterial:
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
func _shrink(mat: ParticleProcessMaterial, size: float) -> void:
	mat.scale_min = size * 0.6
	mat.scale_max = size
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.0))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	mat.scale_curve = curve_tex


func _glow_cube(size: float) -> BoxMesh:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * size
	var mat := ShaderMaterial.new()
	mat.shader = EMBER
	cube.material = mat
	return cube
