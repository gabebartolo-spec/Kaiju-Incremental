class_name Damped
extends RefCounted
## A critically damped follower (the camera's "smooth damp"): `value` chases a target without
## overshoot and its velocity is continuous, so a target that starts, stops or turns abruptly
## moves the camera up to speed and back down over a handful of frames, never in one (the motion
## critic's pan pops). `smooth_s` is the time constant (the velocity peaks about `smooth_s` / 2
## after a step in the target); `max_accel` (units/s^2, 0 = none) caps how fast the velocity may
## change. Vector3 for the aim and the lead; the tilt uses x alone. Presentation only.

var value := Vector3.ZERO
var velocity := Vector3.ZERO


func _init(start := Vector3.ZERO) -> void:
	value = start


## One frame of `delta` s toward `target`; returns the new value.
func step(target: Vector3, smooth_s: float, max_accel: float, delta: float) -> Vector3:
	if delta <= 0.0:
		return value
	var omega := 2.0 / maxf(smooth_s, 0.0001)
	var x := omega * delta
	var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := value - target
	var temp := (velocity + change * omega) * delta
	var next := (velocity - temp * omega) * decay
	if max_accel > 0.0:
		next = velocity + (next - velocity).limit_length(max_accel * delta)
	value = target + (change + temp) * decay
	velocity = next
	return value
