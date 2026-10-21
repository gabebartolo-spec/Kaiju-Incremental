class_name BlastShock
extends RefCounted
## A red-barrel blast's shockwave (BlastFx; director comments #20, "shockwaves and sonicboom";
## lead QC 2026-10-21: "a thin ring of small pale dust cubes expanding fast and fading, so it
## reads as a crisp ring from the game camera"): small pale dust voxels thrown flat out along the
## street from a thin ring round the site, all at the same speed, stopping at `reach` in
## shock.ring.seconds and shrinking away; and the sonic boom you can see, a brief ripple that
## bends the whole screen out from the blast when the boom reaches the camera. Looks:
## data/tuning.json "blast_fx" shock, ripple. Presentation only.

const RIPPLE := preload("res://scenes/blast_ripple.gdshader")


## How far the shock runs: the larger of shock.ring.footprint_scale times the site's widest
## side (halved: a radius) and the sim's own blast reach (full force to `radius`, gone at twice).
static func reach(span: float, radius: float, cfg: Dictionary) -> float:
	var ring: Dictionary = cfg["ring"]
	return maxf(span * Num.f(ring["footprint_scale"]) * 0.5, radius * 2.0)


## The ring along the ground from `at` (y ignored) out to `out`: every cube leaves at the same
## speed (2 * out / seconds) and is damped to a stop at `out`, so they stay one thin ring.
static func ground(host: Node3D, at: Vector3, out: float, cfg: Dictionary) -> void:
	var ring: Dictionary = cfg["ring"]
	var seconds := Num.f(ring["seconds"])
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_radius = 0.6
	mat.emission_ring_inner_radius = 0.5
	mat.emission_ring_height = 0.05
	mat.direction = Vector3.UP
	mat.spread = 0.0
	mat.initial_velocity_min = Num.f(ring["lift"])
	mat.initial_velocity_max = Num.f(ring["lift"])
	var speed := 2.0 * out / seconds
	mat.radial_velocity_min = speed
	mat.radial_velocity_max = speed
	mat.damping_min = speed / seconds
	mat.damping_max = speed / seconds
	mat.gravity = Vector3.ZERO
	mat.angular_velocity_min = -180.0
	mat.angular_velocity_max = 180.0
	var sizes: Array = ring["size"]
	BlastParts.curve(mat, Vector2(Num.f(sizes[0]), Num.f(sizes[1])), [1.0, 1.0, 0.0])
	var colours: Array = ring["colors"]
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray(colours.map(func(c: String) -> Color: return Color(c)))
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	mat.color_initial_ramp = tex
	var life := seconds * Num.f(ring["life_share"])
	var lift := Vector3(at.x, Num.f(ring["height"]), at.z)
	var p := BlastParts.emit(host, mat, BlastParts.voxel_cube(), Num.i(ring["chunks"]), life, lift)
	p.visibility_aabb = AABB(Vector3(-out, -2, -out) * 1.2, Vector3(out * 2.4, 8, out * 2.4))


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
