class_name BlastShock
extends RefCounted
## A red-barrel blast's shockwave (BlastFx; director comments #20, "shockwaves and sonicboom";
## motion critic 2026-10-21: "a flat ring of dust/voxel chunks expanding along the ground"):
## a ring of street-coloured voxel chunks skidding out along the ground from the site to
## `reach` in shock.ring.seconds, a dust band under it and dust clouds thrown out with it; and
## the sonic boom you can see, a brief ripple that bends the whole screen out from the blast
## when the boom reaches the camera. Looks: data/tuning.json "blast_fx" shock, ripple.
## Presentation only.

const SHOCKWAVE := preload("res://scenes/shockwave.gdshader")
const RIPPLE := preload("res://scenes/blast_ripple.gdshader")
const SMOKE := preload("res://scenes/smoke.gdshader")


## How far the shock runs: the larger of shock.ring.footprint_scale times the site's widest
## side (halved: a radius) and the sim's own blast reach (full force to `radius`, gone at twice).
static func reach(span: float, radius: float, cfg: Dictionary) -> float:
	var ring: Dictionary = cfg["ring"]
	return maxf(span * Num.f(ring["footprint_scale"]) * 0.5, radius * 2.0)


## The shock along the ground from `at` (y ignored) out to `out`.
static func ground(host: Node3D, at: Vector3, out: float, cfg: Dictionary) -> void:
	var ring: Dictionary = cfg["ring"]
	var seconds := Num.f(ring["seconds"])
	_band(host, at, out, seconds, cfg)
	_chunks(host, at, out, seconds, cfg)
	_dust(host, at, out, seconds, cfg)


## The boom reaching the camera: the screen ripples out from where `at` is on screen.
static func ripple(host: Node3D, at: Vector3, cfg: Dictionary) -> void:
	var cam := host.get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(at):
		return
	var size := host.get_viewport().get_visible_rect().size
	var centre := cam.unproject_position(at) / size
	var layer := CanvasLayer.new()
	layer.layer = Num.i(cfg["layer"])  # under the HUD: only the city bends
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = RIPPLE
	mat.set_shader_parameter("centre", centre)
	mat.set_shader_parameter("aspect", size.x / size.y)
	mat.set_shader_parameter("strength", Num.f(cfg["strength"]))
	mat.set_shader_parameter("width", Num.f(cfg["width"]))
	rect.material = mat
	layer.add_child(rect)
	host.add_child(layer)
	var tween := layer.create_tween()
	var drive := func(v: float) -> void: mat.set_shader_parameter("progress", v)
	tween.tween_method(drive, 0.0, 1.0, Num.f(cfg["seconds"]))
	tween.tween_callback(layer.queue_free)


## The dust band: a soft ring of dust on the street running out with the chunks.
static func _band(host: Node3D, at: Vector3, out: float, seconds: float, cfg: Dictionary) -> void:
	var quad := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * out * 2.0
	var band := ShaderMaterial.new()
	band.shader = SHOCKWAVE
	band.set_shader_parameter("peak", Num.f(cfg["alpha"]))
	band.set_shader_parameter("soft", Num.f(cfg["soft"]))
	band.set_shader_parameter("tint", Color(str(cfg["band_tint"])))
	plane.material = band
	quad.mesh = plane
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.position = Vector3(at.x, 0.15, at.z)
	host.add_child(quad)
	var tween := quad.create_tween()
	var drive := func(v: float) -> void: band.set_shader_parameter("progress", v)
	tween.tween_method(drive, 0.05, 1.0, seconds * Num.f(cfg["band_share"]))
	tween.tween_callback(quad.queue_free)


## The voxel ring: chunks of street and dust thrown flat out from the site, decelerating so
## they stop at `out` at `seconds` (start speed 2*out/seconds, damping speed/seconds).
static func _chunks(host: Node3D, at: Vector3, out: float, seconds: float, cfg: Dictionary) -> void:
	var ring: Dictionary = cfg["ring"]
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_radius = 1.0
	mat.emission_ring_inner_radius = 0.5
	mat.emission_ring_height = 0.2
	mat.direction = Vector3.UP
	mat.spread = 15.0
	mat.initial_velocity_min = Num.f(ring["lift"]) * 0.4
	mat.initial_velocity_max = Num.f(ring["lift"])
	var speed := 2.0 * out / seconds
	mat.radial_velocity_min = speed * 0.85
	mat.radial_velocity_max = speed
	mat.damping_min = speed / seconds * 0.85
	mat.damping_max = speed / seconds
	mat.gravity = Vector3(0, -Num.f(ring["gravity"]), 0)
	mat.angular_velocity_min = -360.0
	mat.angular_velocity_max = 360.0
	var sizes: Array = ring["size"]
	BlastParts.curve(mat, Vector2(Num.f(sizes[0]), Num.f(sizes[1])), [1.0, 1.0, 0.0])
	var colours: Array = ring["colors"]
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray(colours.map(func(c: String) -> Color: return Color(c)))
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	mat.color_initial_ramp = tex
	var cube := BoxMesh.new()
	var look := StandardMaterial3D.new()
	look.vertex_color_use_as_albedo = true
	look.roughness = 1.0
	cube.material = look
	var life := seconds * Num.f(ring["life_share"])
	var lift := Vector3(at.x, 0.3, at.z)
	var p := BlastParts.emit(host, mat, cube, Num.i(ring["chunks"]), life, lift)
	p.visibility_aabb = AABB(Vector3(-out, -2, -out) * 1.2, Vector3(out * 2.4, 8, out * 2.4))


## Dust clouds thrown out along with the ring, hanging where it passed.
static func _dust(host: Node3D, at: Vector3, out: float, seconds: float, cfg: Dictionary) -> void:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_radius = 1.5
	mat.emission_ring_inner_radius = 0.8
	mat.emission_ring_height = 0.3
	mat.direction = Vector3.UP
	mat.spread = 10.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 1.2
	var speed := 2.0 * out / seconds
	mat.radial_velocity_min = speed * 0.6
	mat.radial_velocity_max = speed
	mat.damping_min = speed / seconds * 0.8
	mat.damping_max = speed / seconds
	mat.gravity = Vector3(0, 0.3, 0)
	BlastParts.curve(mat, Vector2(1.0, 1.6) * out * 0.18, [0.6, 1.6, 2.4])
	var dust := Color(str(cfg["tint"]))
	mat.color_ramp = BlastParts.ramp(
		[Color(dust, 0.0), Color(dust, Num.f(cfg["dust_alpha"])), Color(dust, 0.0)], [0.0, 0.1, 1.0]
	)
	var puff := QuadMesh.new()
	var look := ShaderMaterial.new()
	look.shader = SMOKE
	puff.material = look
	var life := Num.f(cfg["dust_seconds"])
	BlastParts.emit(host, mat, puff, Num.i(cfg["dust_amount"]), life, Vector3(at.x, 0.6, at.z))
