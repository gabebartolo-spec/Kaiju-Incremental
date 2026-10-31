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
## A stepping turner's foot (D-187's stepped yaw; not the young croc's smooth turn, D-131) aims,
## from AIM_FROM of its swing on, at where the body's turn will have carried its clip spot when it
## lands: this frame's yaw run on for the clip frames left aloft, about the planted foot, the point
## the sim turns the body about (motion gate pivot). Only the yaw: the clip's swing and the body's
## travel already meet where a straight walk lands (run on too, they kicked the knees: shin jerk
## p99 34.5 on the Colossus). Aimed from the lift, it swept the toes along the street as they rose
## (smoke turn check 2026-10-28: 2.3 foot-frames a second). A turn's short-step foot lands under
## where it was aloft the frame before (`down`), not on the clip spot the turning body swung on
## that frame: it jumped there as it touched down (1.7); a full step lands on its spot (landing
## where it was aloft kicked the young croc's knees: shin jerk p99 4.8 walking).

const LAG_SECONDS := 0.25
const LAG_SWING := 0.85
const LAG_LIFT := 0.3
const LAG_LIFT_MAX := 0.15
const GAP_STRAIGHT := 0.03
const GAP_TURN := 0.08
const RATIO_TURN := 0.5
const AIM_FROM := 0.25
## The aim moves at most this fast (hip heights a second): at a slow cadence a frame's yaw, run on
## for the many frames left aloft, jumped the toe 1.8 m in a frame (Colossus U-turn, director
## 2026-11-01). A turn's aim moves well under 1 hip/s, so only a jump is held back (an ease lagged
## every turn and moved the pivot off the foot: motion gate).
const AIM_RATE := 6.0
## A foot lifted walking rises this much (hip heights) mid-swing, over the clip's own toe lift
## (1.5%): in a slow turn step it hung a metre up for over a second and read as a slide
## (director 2026-11-01 "left foot slides forward"). Within the motion gate's lift_max (20%).
const SWING_LIFT := 0.08

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
var _aloft: Array[bool] = [false, false]  # it was on this path last frame
var _last_toe: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]  # where then, below its lift (world)
var _aim_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]  # its eased aim (world offset)
var _walk_lift: Array[bool] = [false, false]  # it lifted in the walk loop (its swing is the clip's)


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
	_aim_at[i] = Vector3.ZERO
	_walk_lift[i] = gait.state == "walk"


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
	var aim_to := _aim(gait, i, clip_toe) * smoothstep(AIM_FROM, 1.0, k)
	_aim_at[i] = _aim_at[i].move_toward(aim_to, AIM_RATE * gait.hip_height * gait.s * dt)
	var aim := _aim_at[i]
	_aloft[i] = true
	_last_toe[i] = clip_toe + lag[i] + aim
	var through := (gait.walk_frames - _lift_frame[i]) / _swing_frames if _walk_lift[i] else 1.0
	var arc := SWING_LIFT * gait.hip_height * gait.s * sin(PI * clampf(through, 0.0, 1.0))
	lift_h = lift_h * sin(PI * k) + arc
	return _last_toe[i] + Vector3.UP * lift_h


## Where foot i lands if its clip puts it down this frame (world): a turn's short step under where
## it was last frame on this path (blended by how full a step it is), else at `spot` (its clip spot
## and offset); at `spot`'s height.
func down(i: int, spot: Vector3) -> Vector3:
	var was := _aloft[i]
	_aloft[i] = false
	var aloft := Vector3(_last_toe[i].x, spot.y, _last_toe[i].z)
	return spot.lerp(aloft, 1.0 - _straight[i]) if was else spot


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
