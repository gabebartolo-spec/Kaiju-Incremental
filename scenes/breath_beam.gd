class_name BreathBeam
extends Node3D
## Atomic Breath's light, built once and reused (pooled): a slim white-hot core from the jaw to
## what it strikes, a soft glow on the street over the breath's hit cone, a curtain of flame
## standing up along the cone's far arc, a muzzle flash, a flare and a light at the struck point.
## From the game camera behind the kaiju the body hides the core; the curtain rises above the
## head, so the breath still reads. Everything eases in together over fx.breath_fade_in.
## Presentation only; all additive, so nothing hides the kaiju (D-025).

const BEAM := preload("res://scenes/beam.gdshader")
const FAN := preload("res://scenes/breath_fan.gdshader")
const CURTAIN := preload("res://scenes/breath_curtain.gdshader")
const FLARE := preload("res://scenes/flare.gdshader")
const HOT := Color(1.0, 0.92, 0.7)
const FAN_SEGMENTS := 24
## How far along the jaw bone (hinge 0, chin 1) the breath leaves the mouth.
const MOUTH_ALONG_JAW := 0.7
## How far under the struck street point the fan lies (the target sits 0.5 above the street).
const FAN_LIFT := 0.3
## Flash sizes (world units at body scale 1) and the strike light's peak energy, as #6 had them.
const MUZZLE_SIZE := 4.5
const STRIKE_SIZE := 3.5
const LIGHT_ENERGY := 10.0

## Signature Power's brightness for the next fire (1..fx.power_max).
var power := 1.0
## Where the sim's hit cone starts (the kaiju's feet) for the next fire.
var cone_origin := Vector3.ZERO
## The body breathing: while the beam is lit its core stays on the jaw as the head moves.
var follow: Node3D
var _jaw: Node3D
var _hit := Vector3.ZERO
var _scale: float
var _seconds: float
var _core: MeshInstance3D
var _core_mesh: CylinderMesh
var _core_mat: ShaderMaterial
var _fan: MeshInstance3D
var _fan_mat: ShaderMaterial
var _fan_half := -1.0
var _curtain: MeshInstance3D
var _curtain_mat: ShaderMaterial
var _curtain_height: float
var _muzzle: MeshInstance3D
var _strike: MeshInstance3D
var _light: OmniLight3D
var _fade_in: float
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
	_curtain_mat = _material(CURTAIN, tint, tune)
	_curtain_mat.set_shader_parameter("strength", Num.f(tune["breath_curtain_alpha"]))
	_curtain = _instance(null)
	_curtain.material_override = _curtain_mat
	_curtain_height = Num.f(tune["breath_curtain_height"]) * body_scale
	_fade_in = Num.f(tune["breath_fade_in"]) / _seconds
	_muzzle = _instance(_flare_quad(HOT))
	_strike = _instance(_flare_quad(tint.lightened(0.4)))
	_light = OmniLight3D.new()
	_light.light_color = tint.lightened(0.3)
	_light.visible = false
	add_child(_light)


## Lights the breath from `mouth`: the core to `hit`, the fan along `span` (mouth to the street
## at full reach) over `half_angle` either side, for fx.beam_seconds.
func fire(mouth: Vector3, hit: Vector3, span: Vector3, half_angle: float) -> void:
	_hit = hit
	_jaw = _jaw_of(follow)
	_core_mesh.bottom_radius = 0.3 * _scale
	_core_mesh.top_radius = 0.45 * _scale
	_place_core(mouth)
	if not is_equal_approx(half_angle, _fan_half):
		_fan_half = half_angle
		_fan.mesh = _sector(half_angle)
		_fan_mat.set_shader_parameter("half_angle", half_angle)
		_curtain.mesh = _arc_wall(half_angle)
	# The fan lies flat on the street over exactly the sim's hit cone: from the kaiju's feet
	# (`cone_origin`) out to where the breath strikes at full reach, half_angle either side.
	# Face-up to the game camera, it spills past both sides of the body that hides the core.
	var target := mouth + span
	var flat := Vector3(target.x - cone_origin.x, 0.0, target.z - cone_origin.z)
	var b := along(flat.normalized())
	_fan.basis = b.scaled(Vector3.ONE * flat.length())
	_fan.position = Vector3(cone_origin.x, target.y - FAN_LIFT, cone_origin.z)
	var reach := flat.length()
	_curtain.basis = Basis(b.x * reach, b.y * reach, Vector3.UP * _curtain_height)
	_curtain.position = _fan.position
	var dir := (hit - mouth).normalized()
	_muzzle.position = mouth
	(_muzzle.mesh as QuadMesh).size = Vector2.ONE * MUZZLE_SIZE * _scale * power
	_strike.position = hit - dir * 0.6
	(_strike.mesh as QuadMesh).size = Vector2.ONE * STRIKE_SIZE * _scale * power
	_light.position = hit - dir * 1.5
	_light.omni_range = 3.0 + LIGHT_ENERGY * power
	for mat: ShaderMaterial in [_core_mat, _fan_mat, _curtain_mat]:
		mat.set_shader_parameter("power", power)
	_set_progress(0.0)
	for node: Node3D in [_core, _fan, _curtain, _muzzle, _strike, _light]:
		node.visible = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_progress, 0.0, 1.0, _seconds)
	_tween.tween_callback(_hide)


## Where the breath leaves `model`: most of the way along its jaw bone, between the jaws, so the
## beam starts at the snout rather than inside the body. `fallback` for bodies with no jaw.
static func mouth_of(model: Node3D, fallback: Vector3) -> Vector3:
	var jaw := _jaw_of(model)
	return _along_jaw(jaw) if jaw != null else fallback


## The model's "jaw" bone, when it hangs under a KaijuRig.
static func _jaw_of(model: Node3D) -> Node3D:
	if model == null:
		return null
	var jaw := model.find_child("jaw", true, false) as Node3D
	var rig := jaw.get_parent() if jaw != null else null
	while rig != null and not rig is KaijuRig:
		rig = rig.get_parent()
	return jaw if rig != null else null


static func _along_jaw(jaw: Node3D) -> Vector3:
	var rig := jaw.get_parent()
	while not rig is KaijuRig:
		rig = rig.get_parent()
	return jaw.global_transform * ((rig as KaijuRig).dir_of("jaw") * MOUTH_ALONG_JAW)


## A basis whose y runs along `dir` and whose x lies flat (across the breath); for a flat `dir`
## the xy plane is the street.
static func along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, y, x.cross(y))


func _process(_delta: float) -> void:
	if _core.visible and is_instance_valid(_jaw):
		_place_core(_along_jaw(_jaw))


func _place_core(mouth: Vector3) -> void:
	var dir := (_hit - mouth).normalized()
	var length := mouth.distance_to(_hit)
	_core_mesh.height = length
	_core.basis = along(dir)
	_core.position = mouth + dir * length * 0.5


func _set_progress(v: float) -> void:
	for mat: ShaderMaterial in [_core_mat, _fan_mat, _curtain_mat]:
		mat.set_shader_parameter("progress", v)
	var grow := smoothstep(0.0, _fade_in, v)
	var struck := smoothstep(0.1, 0.25, v)  # the front reaches what it hits
	_flare_fade(_muzzle, grow * (1.0 - smoothstep(0.1, 0.35, v)))
	_flare_fade(_strike, struck * (1.0 - v))
	_light.light_energy = LIGHT_ENERGY * power * struck * (1.0 - v)


func _hide() -> void:
	for node: Node3D in [_core, _fan, _curtain, _muzzle, _strike, _light]:
		node.visible = false


func _flare_quad(tint: Color) -> QuadMesh:
	var quad := QuadMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = FLARE
	mat.set_shader_parameter("tint", tint)
	quad.material = mat
	return quad


static func _flare_fade(flare: MeshInstance3D, fade: float) -> void:
	((flare.mesh as QuadMesh).material as ShaderMaterial).set_shader_parameter("fade", fade)


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


## A unit wall standing on the fan's arc: x/y on the unit circle over `half_angle` either side
## of +y, z from 0 (street) to 1 (top). UV.x runs -1..1 along the arc, UV.y up the wall.
func _arc_wall(half_angle: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in FAN_SEGMENTS:
		var t0 := float(i) / FAN_SEGMENTS
		var t1 := float(i + 1) / FAN_SEGMENTS
		var a0 := lerpf(-half_angle, half_angle, t0)
		var a1 := lerpf(-half_angle, half_angle, t1)
		var p0 := Vector3(sin(a0), cos(a0), 0.0)
		var p1 := Vector3(sin(a1), cos(a1), 0.0)
		_wall_vertex(st, p0, t0, 0.0)
		_wall_vertex(st, p1, t1, 0.0)
		_wall_vertex(st, p1, t1, 1.0)
		_wall_vertex(st, p0, t0, 0.0)
		_wall_vertex(st, p1, t1, 1.0)
		_wall_vertex(st, p0, t0, 1.0)
	return st.commit()


static func _wall_vertex(st: SurfaceTool, at: Vector3, along_arc: float, up: float) -> void:
	st.set_uv(Vector2(along_arc * 2.0 - 1.0, up))
	st.add_vertex(at + Vector3(0.0, 0.0, up))


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
