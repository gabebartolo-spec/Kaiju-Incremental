class_name SwingPath
extends RefCounted
## Where a lifted foot of a clip-driven kaiju (ClipGait) is: it leaves where it stood and joins its
## clip path by landing. Presentation only.
## A foot that lifts after the body turned over it is left behind its clip path: it stays where it
## stood as it lifts, then swings to the path (which the body carries round) in LAG_SECONDS, an arc
## lifted LAG_LIFT of the way it has to go, at most LAG_LIFT_MAX hip heights, never a glide along
## the ground (motion critic 2026-10-22: "the foot skates"). Walking, it is on the path by
## LAG_SWING of the clip's swing however quick the steps (a quicker swing than LAG_SECONDS landed
## the young croc's foot short and caught it up with a catch step every other plant).
## A foot that lifts on its path (walking straight: within GAP_STRAIGHT strides of it) follows the
## clip's own swing, its small offset fading out: held back where it stood, the whole swing was
## made in the last part of the air time and landed with a knee pop (motion gate, D-177: shin jerk
## 6.8 on the Behemoth). Past GAP_TURN strides (a turn) it is held back as above; between, a blend.
## A foot lifting into a turn's quick short step (the sim's step_ratio at RATIO_TURN or under) is
## held back too, however near its path: the Colossus's long stride (D-302, ~15 m) left a turn's
## lift within GAP_STRAIGHT of it, and its toe, the walk's slow peel off the street played at the
## turn's quick cadence, skimmed the ground (smoke turn check 2026-10-27: 3.2 foot-frames a second).
## A stepping turner's foot (D-187's stepped yaw; not the young croc's smooth turn, D-131) aims
## as it comes down at where the body's turn will have carried its clip spot when it lands: the
## spot swung round with the body, and a foot that followed it skimmed the street in its last
## frames aloft (smoke turn check 2026-10-28: 1.7 foot-frames a second). The aim turns the spot
## about the body by the yaw still to come (this frame's yaw run on for the clip frames left
## aloft) about the planted foot, the point the sim turns the body about (motion gate pivot),
## faded in with the swing (`aim`). Only the yaw: the clip's own swing and the body's travel
## already meet where a straight walk lands (run on too, they kicked the knees: motion gate
## 2026-10-28, shin jerk p99 34.5 on the Colossus); turned about the body's origin instead, the
## aim missed the spot's sweep (smoke 3.5 foot-frames a second).

const LAG_SECONDS := 0.25
const LAG_SWING := 0.85
const LAG_LIFT := 0.3
const LAG_LIFT_MAX := 0.15
const GAP_STRAIGHT := 0.03
const GAP_TURN := 0.08
const RATIO_TURN := 0.5

## Each foot's offset from its clip path (world), set by target().
var lag: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _swing_frames := 1.0  # walk clip frames a foot is in the air each cycle
var _air_s: Array[float] = [0.0, 0.0]  # seconds since it lifted
var _lift_frame: Array[float] = [0.0, 0.0]  # walk frames played when it lifted
var _lift_toe: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]  # its clip spot when it lifted
var _lock: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]  # where it stood (world)
var _straight: Array[float] = [1.0, 1.0]  # 1 lifting into a full step, 0 into a turn's short one
var _last_yaw: Array[float] = [INF, INF]  # the body's yaw last frame (rad)
var _last_frames: Array[float] = [0.0, 0.0]  # walk frames played last frame


func _init(swing_frames: float) -> void:
	_swing_frames = swing_frames


## Foot i of `gait` lifts now: it stood at `lock` (world), its clip spot at `clip_toe`, into a step
## the gait's step_ratio of a full one long.
func lift(gait: ClipGait, i: int, clip_toe: Vector3, lock: Vector3) -> void:
	_air_s[i] = 0.0
	_straight[i] = smoothstep(RATIO_TURN, 1.0, gait.step_ratio)
	_lift_frame[i] = gait.walk_frames
	_lift_toe[i] = clip_toe
	_last_yaw[i] = INF
	_last_frames[i] = gait.walk_frames
	_lock[i] = lock


## Foot i's toe this frame in the air (world), its clip spot now at `clip_toe`.
func target(gait: ClipGait, i: int, dt: float, clip_toe: Vector3) -> Vector3:
	_air_s[i] = minf(_air_s[i] + dt, LAG_SECONDS)
	var swung := (gait.walk_frames - _lift_frame[i]) / (LAG_SWING * _swing_frames)
	var k := clampf(maxf(_air_s[i] / LAG_SECONDS, swung if gait.state == "walk" else 0.0), 0.0, 1.0)
	var gone := (_lock[i] - _lift_toe[i]).length() / gait.stride()
	var on_path := (1.0 - smoothstep(GAP_STRAIGHT, GAP_TURN, gone)) * _straight[i]
	var gap := _lock[i] - clip_toe + (clip_toe - _lift_toe[i]) * on_path  # from where it went
	lag[i] = gap * (1.0 - smoothstep(0.0, 1.0, k))
	var lift_h := minf(LAG_LIFT * gap.length(), LAG_LIFT_MAX * gait.hip_height * gait.s)
	var aim := _aim(gait, i, clip_toe) * smoothstep(0.0, 1.0, k)
	return clip_toe + lag[i] + aim + Vector3.UP * lift_h * sin(PI * k)


## How far the body's turn carries foot i's clip spot before the foot lands (world): this frame's
## yaw run on for the clip frames it has left aloft, about the other (planted) foot. Zero for a
## smooth turner (D-131), a foot not walking, the first frame aloft, or no foot down.
func _aim(gait: ClipGait, i: int, clip_toe: Vector3) -> Vector3:
	var body := gait.rig.global_transform
	var yaw := atan2(body.basis.z.x, body.basis.z.z)
	var turned := wrapf(yaw - _last_yaw[i], -PI, PI) if is_finite(_last_yaw[i]) else 0.0
	var played := gait.walk_frames - _last_frames[i]
	_last_yaw[i] = yaw
	_last_frames[i] = gait.walk_frames
	if (
		gait.step_phase == INF
		or gait.state != "walk"
		or played <= 0.0
		or not gait.legs[1 - i].planted
	):
		return Vector3.ZERO
	var left := maxf(_swing_frames - (gait.walk_frames - _lift_frame[i]), 0.0)
	var arm := clip_toe - gait._lock[1 - i]
	return arm.rotated(Vector3.UP, turned * maxf(left / played, 1.0)) - arm
