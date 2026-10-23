class_name BreathProbe
extends RefCounted
## Where the breath puts points of the croc's body on the screen (D-165, the breath trade): the
## probe points sit on bones (neck, shoulders, back, flanks, head-top); at the breath's bottom and
## top, their bones' places (head lift and the rest of what the bones do) plus the skin shader's
## push (voxel_breath.gdshaderinc, mirrored here) are projected through the locked game camera.
## Measurement only: the shader is what the game draws.

## Probe points: label -> [bone, offset in rig units, share override (-1: the bone's tuned share)].
const POINTS := {
	"head-top": ["head1", Vector3(0.0, 0.9, 0.0), 0.0],
	"neck": ["head0", Vector3(0.0, 0.9, 0.0), -1.0],
	"shoulder L": ["spine2", Vector3(-1.1, 0.5, 0.0), -1.0],
	"shoulder R": ["spine2", Vector3(1.1, 0.5, 0.0), -1.0],
	"back": ["spine1", Vector3(0.0, 1.0, 0.0), -1.0],
	"flank L": ["spine1", Vector3(-1.3, 0.0, 0.0), -1.0],
	"flank R": ["spine1", Vector3(1.3, 0.0, 0.0), -1.0],
}

var _cfg := Content.section("croc_idle")
var _locked := Transform3D.IDENTITY
var _fov := 60.0
var _size := Vector2(1920.0, 1080.0)
var _seen := {}  # "bottom" / "top" -> label -> Vector2 (screen px)
var _where := {}  # the same -> label -> Vector3 (rig units)
var _stage := 0


## The camera the points are projected through (held where the capture holds it).
func setup(locked: Transform3D, fov: float, size: Vector2) -> void:
	_locked = locked
	_fov = fov
	_size = size


## Notes the probes' screen places now: `push_it`, the breath at the top of its curve (the shader
## push, the biggest), else at its bottom (none).
func record(label: String, gait: ClipAlive, push_it: bool) -> void:
	var rig := gait.rig
	_stage = gait.life.stage
	var shares: Dictionary = _cfg["skin_bones"]
	var to_rig := rig.global_transform.affine_inverse()
	var a := to_rig * rig.bone("spine0").global_position
	var b := to_rig * rig.bone("head0").global_position
	var peak := gait.life.skin_peak() * KaijuModel.MODEL_HEIGHT if push_it else 0.0
	var out := {}
	var spots := {}
	for point: String in POINTS:
		var row: Array = POINTS[point]
		var bone_name: String = row[0]
		var offset: Vector3 = row[1]
		var p: Vector3 = to_rig * rig.bone(bone_name).global_position + offset
		var share := Num.f(shares.get(bone_name, 0.0)) if Num.f(row[2]) < 0.0 else Num.f(row[2])
		var push := _push(p, Vector2(share, peak), [a, b], gait.life) if push_it else Vector3.ZERO
		out[point] = _project(rig.global_transform * (p + push))
		spots[point] = p + push
	_seen[label] = out
	_where[label] = spots


## The shader's push, mirrored: amount is (share, peak); at the top of the curve, lagged as played.
func _push(p: Vector3, amount: Vector2, axis: Array, idle: ClipIdle) -> Vector3:
	var share := amount.x
	var peak := amount.y
	var a: Vector3 = axis[0]
	var b: Vector3 = axis[1]
	var ab: Vector3 = b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.dot(ab), 0.0001), 0.0, 1.0)
	var radial := p - (a + ab * t)
	var dir := radial.normalized() if radial.length() > 0.0001 else Vector3.UP
	var lift := Num.f(_cfg["skin_lift"])
	var belly := lerpf(Num.f(_cfg["skin_belly"]), 1.0, smoothstep(-0.4, 0.2, dir.y))
	var c := idle.curve(Num.f(_cfg["inhale"]) - Num.f(_cfg["skin_lag"]) * (1.0 - t))
	var push := (dir + Vector3(0.0, lift, 0.0)) * (belly * peak * c * share / (1.0 + lift))
	var depth := idle.depth_weight()
	push.x += radial.x * idle.trade("swell") * c * belly * share * depth
	var crest := idle.trade("plate_lift") * KaijuModel.MODEL_HEIGHT * c * share
	push.y += crest * smoothstep(0.3, 0.7, dir.y) * depth
	return push


func _project(world: Vector3) -> Vector2:
	var v := _locked.affine_inverse() * world
	var half := tan(deg_to_rad(_fov) * 0.5)
	var x := v.x / (-v.z * half * _size.x / _size.y)
	var y := v.y / (-v.z * half)
	return Vector2((0.5 + 0.5 * x) * _size.x, (0.5 - 0.5 * y) * _size.y)


## How much wider the two sides' points (label + " L" and " R") stand apart at the top (px).
func _gain(low: Dictionary, high: Dictionary, label: String) -> float:
	var right: Vector2 = high[label + " R"] - low[label + " R"]
	var left: Vector2 = high[label + " L"] - low[label + " L"]
	return right.x - left.x


## The quickest a point goes as a share of its travel per second: a smooth rise over the shortest
## inhale (cosine, so pi / 2 over its length).
func _quickest() -> float:
	var breaths: Array = _cfg["breath_s"]
	var inhale := (
		Num.f(_cfg["inhale"]) * Num.f(breaths[_stage]) * (1.0 - Num.f(_cfg["breath_vary"]))
	)
	return PI / (2.0 * inhale)


## The table: how far each probe moved from the breath's bottom to its top (px at the capture's
## size; up and sideways), and the width the two flanks and the two shoulders gain.
func report() -> String:
	var low: Dictionary = _seen["bottom"]
	var high: Dictionary = _seen["top"]
	var lines: Array[String] = []
	for point: String in POINTS:
		var d: Vector2 = high[point] - low[point]
		var top_spot: Vector3 = _where["top"][point]
		var low_spot: Vector3 = _where["bottom"][point]
		var moved := (top_spot - low_spot).length() / KaijuModel.MODEL_HEIGHT
		(
			lines
			. append(
				(
					"  %-11s up %5.2f px, sideways %+5.2f px; travels %.2f %%H, %.2f %%H/s at its quickest"
					% [point, -d.y, d.x, moved * 100.0, moved * 100.0 * _quickest()]
				)
			)
		)
	lines.append(
		(
			"  width gained: shoulders %.2f px, flanks %.2f px"
			% [_gain(low, high, "shoulder"), _gain(low, high, "flank")]
		)
	)
	return "\n".join(lines)
