class_name SerpentStandIn
extends Node3D
## The serpent prototype's stand-in body (D-198, "a stand-in segmented body"): plain boxes, head
## to tail, tapering, laid each frame along the drawn S (SerpentWeave) over the sim's trail
## (SerpentBody). Every fourth box is darker so a slide along the body would show. The head box
## looks into a turn ahead of the path, sprung (data/tuning.json "serpent" head_lead*). No skin,
## no voxels yet. Presentation only: it reads the body and never moves it. World space (x, z).

const BODY := Color("3d6b22")
const BAND := Color("223f14")
const HEAD := Color("7a9a2e")

## Joint points drawn this frame (ground plane, head first), for captures and tests.
var joints := PackedVector2Array()
## The head's look into the turn now (rad, signed as Vector2.angle_to).
var lead := 0.0
var _cfg: Dictionary
var _weave: SerpentWeave
var _mm: MultiMesh
var _lead_v := 0.0


func _init(cfg: Dictionary) -> void:
	_cfg = cfg
	name = "SerpentStandIn"
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	var box := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true  # the colours below are sRGB, as written
	mat.roughness = 0.8
	box.material = mat
	_mm.mesh = box
	_mm.instance_count = Num.i(cfg["segments"])
	for i: int in _mm.instance_count:
		var color := BAND if i % 4 == 3 else BODY
		_mm.set_instance_color(i, HEAD if i == 0 else color)
	var node := MultiMeshInstance3D.new()
	node.multimesh = _mm
	add_child(node)


## Lays the boxes along the body as it is now; call once after every sim step (delta: that step).
func update(body: SerpentBody, delta: float) -> void:
	var count := Num.i(_cfg["segments"])
	var seg := body.length() / count
	if _weave == null:
		_weave = SerpentWeave.new(body)
	_weave.step(body, delta)
	joints = SerpentWeave.joints(_weave.path(body.length() + seg), seg, count)
	_spring_lead(body, delta)
	for i: int in count:
		var front := joints[i]
		var back := joints[i + 1]
		var along := front - back
		if i == 0:
			along = along.rotated(lead)
		var t := float(i) / maxf(1.0, count - 1.0)
		var width := lerpf(Num.f(_cfg["head_width"]), Num.f(_cfg["tail_width"]), t)
		var height := width * Num.f(_cfg["height_share"])
		var mid := (front + back) * 0.5
		var look := Vector3(along.x, 0.0, along.y).normalized()
		var basis := Basis.looking_at(look if look.length() > 0.0 else Vector3.FORWARD)
		basis = basis.scaled_local(Vector3(width, height, seg * 1.12))
		_mm.set_instance_transform(i, Transform3D(basis, Vector3(mid.x, height * 0.5, mid.y)))


## The head leads a turn by a share of the turn still to make, on a critically damped spring;
## it settles exactly once there is nothing left to lead and the body is still.
func _spring_lead(body: SerpentBody, delta: float) -> void:
	var cap := Num.f(_cfg["head_lead_max"])
	var target := clampf(body.turn_left * Num.f(_cfg["head_lead"]), -cap, cap)
	var omega := TAU * Num.f(_cfg["head_lead_hz"])
	var sprung := KaijuGait.spring(lead, _lead_v, target, omega, 1.0, delta)
	lead = sprung.x
	_lead_v = sprung.y
	if target == 0.0 and absf(lead) < 0.002 and absf(_lead_v) < 0.01:
		lead = 0.0
		_lead_v = 0.0
