class_name CameraShake
extends RefCounted
## The gameplay camera's shake (R 19.2, research 19-camera finding 7, Eiserloh's trauma model):
## every hit adds trauma (0..1, stacking up to 1, fading at "decay_per_s"); the camera turns by
## trauma squared, so small hits barely stir it and big ones kick, on smooth noise sampled by
## time ("noise_hz"), never redrawn white noise. Rotation only (yaw and pitch, no roll, no
## translation), so the framing never drifts. Full trauma turns it "deg_per_root_scale" x
## sqrt(body scale) degrees, at most "max_deg": an adult's topple shakes harder than a baby's.
## A hit away from the camera's focus fades with distance ("near_per_scale" to "far_per_scale"
## body scales). The player's camera-motion setting (PlayerSettings.camera_motion) scales it all.
## Tuning "camera_shake"; time is the frames' own delta. Presentation only.

## Current trauma, 0..1.
var trauma := 0.0
var _cfg: Dictionary
var _noise := FastNoiseLite.new()
var _time := 0.0
## The shake's strength on screen: trauma squared, but rising at most "rise_per_s" a second, so a
## big hit swells over a few frames instead of jumping the frame (motion critic 2026-10-21).
var _shown := 0.0


func _init() -> void:
	_cfg = Content.section("camera_shake")
	_noise.seed = Num.i(_cfg["noise_seed"])
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.fractal_type = FastNoiseLite.FRACTAL_NONE  # one smooth octave, no jagged detail


## The trauma a named source adds (tuning "camera_shake" "sources": stomp, topple, ...).
func source(kind: String) -> float:
	var sources: Dictionary = _cfg["sources"]
	return Num.f(sources[kind])


## Adds `amount` trauma from a hit at `at` (Vector3.INF: at the kaiju, full strength), faded by
## its distance from `focus` for a body of `scale`.
func add(amount: float, at: Vector3, focus: Vector3, scale: float) -> void:
	var fade := 1.0
	if at.is_finite():
		var near := Num.f(_cfg["near_per_scale"]) * scale
		var far := maxf(Num.f(_cfg["far_per_scale"]) * scale, near + 0.001)
		fade = 1.0 - clampf((at.distance_to(focus) - near) / (far - near), 0.0, 1.0)
	trauma = clampf(trauma + maxf(amount, 0.0) * fade, 0.0, 1.0)


## One frame: trauma fades and the noise moves on.
func update(delta: float) -> void:
	_time += delta
	trauma = maxf(0.0, trauma - Num.f(_cfg["decay_per_s"]) * delta)
	var goal := trauma * trauma
	_shown = goal if goal < _shown else move_toward(_shown, goal, Num.f(_cfg["rise_per_s"]) * delta)


## The largest turn (radians) full trauma gives a body of `scale`, before the player's setting.
func max_turn(scale: float) -> float:
	var deg := Num.f(_cfg["deg_per_root_scale"]) * sqrt(maxf(scale, 0.0))
	return deg_to_rad(minf(Num.f(_cfg["max_deg"]), deg))


## This frame's turn in radians (x yaw, y pitch; together never past the cap); motion is the
## player's 0..1 setting.
func turn(scale: float, motion: float) -> Vector2:
	var amp := max_turn(scale) * _shown * clampf(motion, 0.0, 1.0)
	if amp <= 0.0:
		return Vector2.ZERO
	var t := _time * Num.f(_cfg["noise_hz"])
	var wave := Vector2(_noise.get_noise_2d(t, 0.0), _noise.get_noise_2d(t, 100.0))
	return (wave * Num.f(_cfg["noise_gain"])).limit_length(1.0) * amp


## Turns `camera` (already aimed) by this frame's shake.
func apply(camera: Node3D, scale: float, motion: float) -> void:
	var angles := turn(scale, motion)
	if angles == Vector2.ZERO:
		return
	camera.global_rotate(Vector3.UP, angles.x)
	camera.rotate_object_local(Vector3.RIGHT, angles.y)
