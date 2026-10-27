class_name BoltImpact
extends RefCounted
## What a bolt's stroke throws where it lands (VFX_STYLE families 5 and 3): the game's sparks at the
## strike and at the first branch ends, street dust, and a ring of street dust running out with a
## puff at points round it so it reads from the game camera. Presentation only; tuning "fx" "bolt".

## Rings thrown so far (a capture counts them).
var rings := 0
var _row: Dictionary
var _cfg: Dictionary
var _scale: float


func _init(row: Dictionary, cfg: Dictionary, body_scale: float) -> void:
	_row = row
	_cfg = cfg
	_scale = body_scale


## One stroke landing at `hit`, its first branches ending at `ends`; `fx`: the city's Fx or null.
func strike(fx: Fx, hit: Vector3, ends: Array[Vector3]) -> void:
	if fx == null:
		return
	for i: int in Num.i(_cfg["impact_sparks"]):
		fx.sparks(hit + Vector3.UP * i * _scale)
	for end: Vector3 in ends.slice(0, Num.i(_cfg["branch_sparks"])):
		fx.sparks(end)
	fx.dust(Vector3(hit.x, 0.4, hit.z), Num.f(_row["dust"]) * _scale)
	_ring(fx, hit)


func _ring(fx: Fx, hit: Vector3) -> void:
	var radius := Num.f(_row["ring"]) * _scale
	if radius <= 0.0:
		return
	rings += 1
	fx.shockwave(Vector3(hit.x, 0.0, hit.z), radius)
	var puffs := Num.i(_row["ring_puffs"])
	for k: int in puffs:
		var a := TAU * k / puffs
		var at := Vector3(hit.x + cos(a) * radius * 0.6, 0.4, hit.z + sin(a) * radius * 0.6)
		fx.dust(at, Num.f(_row["dust"]) * _scale * 0.5)
