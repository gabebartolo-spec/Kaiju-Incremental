class_name FootSwing
extends RefCounted
## How far a lifted foot of a clip-driven kaiju is off its clip path: it leaves where it stood and
## joins the path by landing. ClipGait draws it (SwingPath adds the arc) and a heavy body's contact
## volume holds its foot there (HeavyFeet, D-208: the drawn foot and the sim's are one). Pure.
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

const LAG_SECONDS := 0.25
const LAG_SWING := 0.85
const LAG_LIFT := 0.3
const LAG_LIFT_MAX := 0.15
const GAP_STRAIGHT := 0.03
const GAP_TURN := 0.08

## Each foot's offset from its clip path (world), set by lag_at().
var lag: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## How far each foot is through its way back to the path, 0..1 (set by lag_at()).
var through: Array[float] = [1.0, 1.0]
var _swing_frames := 1.0  # walk clip frames a foot is in the air each cycle
var _air_s: Array[float] = [0.0, 0.0]  # seconds since it lifted
var _lift_frame: Array[float] = [0.0, 0.0]  # walk frames played when it lifted
var _lift_toe: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]  # its clip spot when it lifted
var _lock: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]  # where it stood (world)


func _init(swing_frames: float) -> void:
	_swing_frames = swing_frames


## Foot i lifts now: it stood at `lock` (world), `walked` walk clip frames played, its clip spot
## at `clip_toe`.
func lift(i: int, walked: float, clip_toe: Vector3, lock: Vector3) -> void:
	_air_s[i] = 0.0
	_lift_frame[i] = walked
	_lift_toe[i] = clip_toe
	_lock[i] = lock


## Foot i's offset from its clip spot `clip_toe` (world) this step in the air; walk: [walk clip
## frames played, whether the walk clip plays, one walk cycle's length (world)]. Returns the way it
## still has to go (the arc's size).
func lag_at(i: int, dt: float, clip_toe: Vector3, walk: Array) -> Vector3:
	_air_s[i] = minf(_air_s[i] + dt, LAG_SECONDS)
	var walked: float = walk[0]
	var walking: bool = walk[1]
	var stride: float = walk[2]
	var swung := (walked - _lift_frame[i]) / (LAG_SWING * _swing_frames)
	var k := clampf(maxf(_air_s[i] / LAG_SECONDS, swung if walking else 0.0), 0.0, 1.0)
	var gone := (_lock[i] - _lift_toe[i]).length() / maxf(stride, 0.0001)
	var on_path := 1.0 - smoothstep(GAP_STRAIGHT, GAP_TURN, gone)
	var gap := _lock[i] - clip_toe + (clip_toe - _lift_toe[i]) * on_path  # from where it went
	lag[i] = gap * (1.0 - smoothstep(0.0, 1.0, k))
	through[i] = k
	return gap
