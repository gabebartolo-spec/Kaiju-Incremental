class_name BreathBeam
extends Node3D
## Atomic Breath's light, built once and reused (pooled): a slim white-hot core from the mouth to
## what it strikes, and a soft fan across the breath's cone out to full reach. From the game
## camera behind the kaiju the body hides the core, so the fan's width is what reads.
## Presentation only; both are additive, so neither hides the kaiju (D-025).

const BEAM := preload("res://scenes/beam.gdshader")
const FAN := preload("res://scenes/breath_fan.gdshader")
const FAN_SEGMENTS := 24

## Signature Power's brightness for the next fire (1..fx.power_max).
var power := 1.0
var _scale: float
var _seconds: float
var _core: MeshInstance3D
var _core_mesh: CylinderMesh
var _core_mat: ShaderMaterial
var _fan: MeshInstance3D
var _fan_mat: ShaderMaterial
var _fan_half := -1.0
var _tween: Tween


func _init(tint: Color, body_scale: float, tune: Dictionary) -> void:
	_scale = body_scale
	_seconds = Num.f(tune["beam_seconds"])
	_core_mesh = CylinderMesh.new()
	_core_mesh.radial_segments = 16
	_core_mesh.rings = 1
	_core_mesh.cap_top = false
	_core_mesh.cap_bottom = false
	_core_mat = _material(BEAM, tint, tune)
	_core_mesh.material = _core_mat
	_core = _instance(_core_mesh)
	_fan_mat = _material(FAN, tint, tune)
	_fan_mat.set_shader_parameter("strength", Num.f(tune["breath_fan_alpha"]))
	_fan = _instance(null)
	_fan.material_override = _fan_mat


## Lights the breath from `mouth`: the core to `hit`, the fan along `span` (mouth to the street
## at full reach) over `half_angle` either side, for fx.beam_seconds.
func fire(mouth: Vector3, hit: Vector3, span: Vector3, half_angle: float) -> void:
	var dir := (hit - mouth).normalized()
	var length := mouth.distance_to(hit)
	_core_mesh.height = length
	_core_mesh.bottom_radius = 0.3 * _scale
	_core_mesh.top_radius = 0.45 * _scale
	_core.basis = along(dir)
	_core.position = mouth + dir * length * 0.5
	if not is_equal_approx(half_angle, _fan_half):
		_fan_half = half_angle
		_fan.mesh = _sector(half_angle)
	# The fan lies in the breath's sloped plane; narrowing it by the slope keeps its footprint on
	# the street exactly the sim's hit cone (half_angle, out to full reach), never wider.
	var span_length := span.length()
	var slope := Vector2(span.x, span.z).length() / maxf(span_length, 0.001)
	var b := along(span.normalized())
	_fan.basis = Basis(b.x * span_length * slope, b.y * span_length, b.z * span_length)
	_fan.position = mouth
	for mat: ShaderMaterial in [_core_mat, _fan_mat]:
		mat.set_shader_parameter("power", power)
		mat.set_shader_parameter("progress", 0.0)
	_core.visible = true
	_fan.visible = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_progress, 0.0, 1.0, _seconds)
	_tween.tween_callback(_hide)


## A basis whose y runs along `dir` and whose x lies flat (across the breath).
static func along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, y, x.cross(y))


func _set_progress(v: float) -> void:
	_core_mat.set_shader_parameter("progress", v)
	_fan_mat.set_shader_parameter("progress", v)


func _hide() -> void:
	_core.visible = false
	_fan.visible = false


func _material(shader: Shader, tint: Color, tune: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("fade_in", Num.f(tune["breath_fade_in"]) / Num.f(tune["beam_seconds"]))
	return mat


func _instance(mesh: Mesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	return node


## A flat unit fan in the local xy plane: apex at the origin, opening along +y over
## `half_angle` either side. UV.x runs -1..1 across it, UV.y 0..1 outward.
func _sector(half_angle: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in FAN_SEGMENTS:
		var a0 := lerpf(-half_angle, half_angle, float(i) / FAN_SEGMENTS)
		var a1 := lerpf(-half_angle, half_angle, float(i + 1) / FAN_SEGMENTS)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(Vector3.ZERO)
		st.set_uv(Vector2(a0 / half_angle, 1.0))
		st.add_vertex(Vector3(sin(a0), cos(a0), 0.0))
		st.set_uv(Vector2(a1 / half_angle, 1.0))
		st.add_vertex(Vector3(sin(a1), cos(a1), 0.0))
	return st.commit()
