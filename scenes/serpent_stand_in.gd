class_name SerpentStandIn
extends Node3D
## The serpent prototype's stand-in body (D-198, "a stand-in segmented body"): plain boxes, head
## to tail, tapering, laid each frame along the drawn S (SerpentWeave) over the sim's trail
## (SerpentBody). Every fourth box is darker so a slide along the body would show. The head and
## neck bend into a turn ahead of the path and the head lifts, sprung (data/tuning.json "serpent"
## head_lead*, neck_bend, head_lift); a stop settles (SerpentSettle). No skin, no voxels
## yet. Presentation only: it reads the body and never moves it. World space (x, z).

const BODY := Color("3d6b22")
const BAND := Color("223f14")
const HEAD := Color("7a9a2e")

## Joint points drawn this frame (ground plane, head first), for captures and tests.
var joints := PackedVector2Array()
## The head's look into the turn now (rad, signed as Vector2.angle_to).
var lead := 0.0
var _cfg: Dictionary
var _weave: SerpentWeave
var _settle: SerpentSettle
## The body's joints as settled, before the neck bends into the lead.
var _settled := PackedVector2Array()
var _mm: MultiMesh
var _lead_v := 0.0


func _init(cfg: Dictionary) -> void:
	_cfg = cfg
	_settle = SerpentSettle.new(cfg)
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
	var moving := body.speed > 0.0
	if moving and _settle.still > 0.0:  # sets off from the shape it settled in
		_weave.settle_into(_settled)
	_weave.step(body, delta)
	var laid := SerpentWeave.joints(_weave.path(body.length() + seg), seg, count)
	_settled = _settle.apply(laid, moving, delta, seg)
	_spring_lead(body, delta)
	joints = _bend_neck(_settled)
	var bends: Array = _cfg["neck_bend"]
	var swell := _settle.swell()
	for i: int in count:
		var front := joints[i]
		var back := joints[i + 1]
		var along := front - back
		var t := float(i) / maxf(1.0, count - 1.0)
		var width := lerpf(Num.f(_cfg["head_width"]), Num.f(_cfg["tail_width"]), t) * swell
		var height := width * Num.f(_cfg["height_share"])
		var share := Num.f(bends[i]) if i < bends.size() else 0.0
		var lift := Num.f(_cfg["head_lift"]) * absf(lead) * share
		var mid := (front + back) * 0.5
		var look := Vector3(along.x, 0.0, along.y).normalized()
		var basis := Basis.looking_at(look if look.length() > 0.0 else Vector3.FORWARD)
		basis = basis.scaled_local(Vector3(width, height, seg * 1.12))
		var at := Vector3(mid.x, height * 0.5 + lift, mid.y)
		_mm.set_instance_transform(i, Transform3D(basis, at))


## The front of the body bent into the head's lead: each front segment turned by its neck_bend
## share of it, rebuilt from the first unbent joint forward, so the head looks into the turn first.
func _bend_neck(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	var bends: Array = _cfg["neck_bend"]
	if lead == 0.0:
		return out
	for i: int in range(mini(bends.size(), out.size() - 1) - 1, -1, -1):
		var along := (points[i] - points[i + 1]).rotated(lead * Num.f(bends[i]))
		out[i] = out[i + 1] + along
	return out


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
