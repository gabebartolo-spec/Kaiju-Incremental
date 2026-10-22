class_name BlastShock
extends RefCounted
## A red-barrel blast's shockwave (BlastFx; director comments #20, "shockwaves and sonicboom";
## lead QC 2026-10-21: "a thin ring of small pale dust cubes expanding fast and fading, so it
## reads as a crisp ring from the game camera"): small pale dust voxels thrown flat out along the
## street from a thin ring round the site, all at the same speed, stopping at `reach` in
## shock.ring.seconds and shrinking away. (The screen-bending ripple of the sonic boom is gone:
## it smeared the facades and put a grey blob over the kaiju, clip critic round 6.) Looks:
## data/tuning.json "blast_fx" shock. Presentation only.


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
