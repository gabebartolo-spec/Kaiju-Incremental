class_name FxParticleMats
extends RefCounted
## The process materials of Fx's dust, footfall, slam and tree puffs (split out of fx.gd, which was
## at the file-size limit). Presentation only.

## A tail slam's puff grows from 0.4 to full over the first SLAM_GROW of its life, has its alpha
## rise from 0 to its peak at SLAM_PEAK and stops growing by SLAM_HOLD (Fx.SLAM_SECONDS).
const SLAM_GROW := 0.15
const SLAM_PEAK := 0.18
const SLAM_HOLD := 0.4


## A dust puff's process material from a style (spread, gravity, speeds, sizes, grow, colours).
static func dust(o: Dictionary) -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.5, 0.3, 0.5)
	mat.direction = Vector3.UP
	mat.spread = Num.f(o["spread"])
	mat.gravity = o["gravity"]
	mat.initial_velocity_min = Num.f(o["vmin"])
	mat.initial_velocity_max = Num.f(o["vmax"])
	mat.angular_velocity_min = -120.0
	mat.angular_velocity_max = 120.0
	mat.damping_min = 1.5
	mat.damping_max = 3.0
	mat.scale_min = Num.f(o["smin"])
	mat.scale_max = Num.f(o["smax"])
	var curve := Curve.new()
	var grow: bool = o["grow"]
	curve.add_point(Vector2(0, 0.4 if grow else 1.0))
	curve.add_point(Vector2(1, 1.6 if grow else 0.2))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	mat.scale_curve = curve_tex
	var ramp := Gradient.new()
	var colors: Array = o["colors"]
	ramp.colors = PackedColorArray([colors[0], colors[1]])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	return mat


## The step puff's material with the slam's life curves (see SLAM_SECONDS).
static func slam(
	step: ParticleProcessMaterial, alpha: float, tone: Color
) -> ParticleProcessMaterial:
	var mat: ParticleProcessMaterial = step.duplicate()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(SLAM_GROW, 1.0))
	curve.add_point(Vector2(SLAM_HOLD, 1.05))
	curve.add_point(Vector2(1.0, 1.05))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	mat.scale_curve = curve_tex
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, SLAM_PEAK, 1.0])
	var c := tone
	ramp.colors = PackedColorArray([Color(c, 0.0), Color(c, alpha), Color(c, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	return mat


## The tree puff's motion: barely rising, growing to 1.35x over its life (its ramp is per puff).
static func tree() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.direction = Vector3.UP
	mat.spread = 40.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.6
	mat.gravity = Vector3(0, 0.2, 0)
	mat.angular_velocity_min = -60.0
	mat.angular_velocity_max = 60.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(1, 1.4))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	mat.scale_curve = curve_tex
	return mat
