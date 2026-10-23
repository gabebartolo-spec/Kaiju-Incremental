class_name SwingPath
extends FootSwing
## Where a lifted foot of a clip-driven kaiju (ClipGait) is: its way back to the clip path
## (FootSwing, the sim's rule too) lifted in an arc. Presentation only.


## Foot i's toe this frame in the air (world), its clip spot now at `clip_toe`.
func target(gait: ClipGait, i: int, dt: float, clip_toe: Vector3) -> Vector3:
	var gap := lag_at(i, dt, clip_toe, [gait.walk_frames, gait.state == "walk", gait.stride()])
	var most := Num.f(_tune["lag_lift_max"]) * gait.hip_height * gait.s
	var lift_h := minf(Num.f(_tune["lag_lift"]) * gap.length(), most)
	return clip_toe + lag[i] + Vector3.UP * lift_h * sin(PI * through[i])
