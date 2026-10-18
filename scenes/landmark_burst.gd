class_name LandmarkBurst
extends Node3D
## A landmark section the sim topples inward (a stadium's stands, over its own pitch) bursts
## where it stands instead (D-078 round 2): its piece shrinks into its middle over a few frames
## under a dust cloud, so nothing swings over the pitch and nothing pops. CityView keeps it in
## place of the piece until the sim lands the fall; the piece is top_level, so the topple
## rotation CityView gives this node never reaches it. Its landing leaves no strip (CityView).

const SECONDS := 0.15  # about four frames at 30 fps

var _piece: Node3D
var _pivot := Vector3.ZERO
var _middle := Vector3.ZERO
var _t := 0.0


## True for a landmark's topple that falls toward the landmark's own middle.
static func inward(sim: RampageSim, event: Dictionary) -> bool:
	var b := sim.buildings[Num.i(event["building"])]
	if b.landmark == "" or str(event["kind"]) != "topple":
		return false
	var dir: Vector2 = event["dir"]
	var pivot: Vector3 = event["pivot"]
	return dir.dot(Vector2(b.x - pivot.x, b.z - pivot.z)) > 0.0


## A section that has landed: an ordinary building's goes at once (its debris and rubble take
## over); a landmark's shrinks into its hinge over SECONDS under the dust, so it never pops.
static func retire(node: Node3D, landmark: bool) -> void:
	if not landmark:
		node.queue_free()
		return
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * 0.01, SECONDS)
	tween.tween_callback(node.queue_free)


## piece: the lifted section (BuildingView.lift_piece). fx: for its dust.
func _init(piece: Node3D, fx: Fx) -> void:
	_piece = piece
	_pivot = piece.position
	var parts: Array = piece.get_meta("parts", [])
	for part: Dictionary in parts:
		var pos: Vector3 = part["pos"]
		_middle += pos
	_middle = _middle / maxi(1, parts.size()) if not parts.is_empty() else _pivot
	add_child(piece)
	piece.top_level = true
	fx.dust(_middle, 1.0 + parts.size() * 0.0004)


func _process(delta: float) -> void:
	if _piece == null:
		return
	_t += delta
	var s := 1.0 - clampf(_t / SECONDS, 0.0, 1.0)
	if s <= 0.0:
		_piece.queue_free()
		_piece = null
		return
	# Scale about the section's middle: a cell at world p goes to middle + (p - middle) * s.
	_piece.global_transform = Transform3D(
		Basis.from_scale(Vector3.ONE * s), _middle + (_pivot - _middle) * s
	)
