class_name FallFade
extends RefCounted
## A falling or toppling section (CityView's falling pieces) between the camera and the kaiju
## fades like a standing building (BuildingFade, R 19.4): each frame every falling piece whose
## box, as it is tilted now, cuts a sight line to the kaiju's body eases to
## camera.fade_opacity, the rest back to solid (BuildingFade.eased: the same smoothstep ramp).
## A piece already in the way when it starts to fall starts faded. Presentation only.

var _cfg: Dictionary = Content.section("camera")
var _progress := {}  # piece instance id -> fade progress, 0 solid .. 1 faded


## Whether falling `piece` (BuildingView.lift_piece: meta "pivot" and "box", the piece's chunks
## at rest in world space) stands in a sight line from the eye to any of `sight`, or holds the eye.
static func covers(piece: Node3D, eye: Vector3, sight: PackedVector3Array) -> bool:
	if not piece.has_meta("box") or not piece.is_inside_tree():
		return false
	var box: AABB = piece.get_meta("box")
	var pivot: Vector3 = piece.get_meta("pivot")
	var to_rest := piece.global_transform.affine_inverse()
	var from := to_rest * eye + pivot
	if box.has_point(from):
		return true
	for target: Vector3 in sight:
		var p := to_rest * target + pivot
		if not box.has_point(p) and box.intersects_segment(from, p) != null:
			return true
	return false


## Piece `piece`'s opacity now (1 = solid).
func opacity(piece: Node3D) -> float:
	var id := piece.get_instance_id()
	return BuildingFade.eased(Num.f(_progress[id])) if _progress.has(id) else 1.0


func update(pieces: Array[Node3D], eye: Vector3, sight: PackedVector3Array, delta: float) -> void:
	var step := delta / Num.f(_cfg["fade_seconds"])
	var kept := {}
	for piece: Node3D in pieces:
		var id := piece.get_instance_id()
		var hit := covers(piece, eye, sight)
		var now: float = _progress.get(id, 1.0 if hit else 0.0)  # new and in the way: faded at once
		var next := move_toward(now, 1.0 if hit else 0.0, step)
		if next != now or (next > 0.0 and not _progress.has(id)):
			_apply(piece, BuildingFade.eased(next))
		if next > 0.0:
			kept[id] = next
	_progress = kept


static func _apply(piece: Node3D, value: float) -> void:
	for child: Node in piece.get_children():
		if child is CellView:
			(child as CellView).set_opacity(value)  # a fine-grid piece (CityCarve)
			continue
		var mi := child as MeshInstance3D
		if mi != null and mi.material_override is ShaderMaterial:
			(mi.material_override as ShaderMaterial).set_shader_parameter("opacity", value)
