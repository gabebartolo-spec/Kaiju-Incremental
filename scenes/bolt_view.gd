class_name BoltView
extends MeshInstance3D
## One bolt drawn as camera-facing ribbons on a single ImmediateMesh with the game's one beam shader
## (bolt.gdshader): a main channel and its branches, each as a narrow white-hot core strip over a
## wide halo strip, so four surfaces. The same class draws the breath, the Thunder Beam and later
## the Taskforce's lasers; only the widths and the colours differ by owner. The shader turns the
## strips to the camera, so the mesh is rebuilt only when the shape changes. Presentation only.

const SHADER := preload("res://scenes/bolt.gdshader")
const CORE_COLOUR := Color(1.0, 0.97, 0.92)
const BLOB_CORNERS: Array[Vector2] = [
	Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)
]
## Which halo colours to draw instead of the tuning's choice ("" = the tuning's): a capture sets
## this to show the director's three options (R 17.6) from the same frame.
static var halo_mode_override := ""

var _mesh := ImmediateMesh.new()
var _blob_step: int
var _halo_boost := 1.0
var _branch_tip: float
var _blob_share: float
var _halo_main := ShaderMaterial.new()
var _core_main := ShaderMaterial.new()
var _halo_branch := ShaderMaterial.new()
var _core_branch := ShaderMaterial.new()


## widths: Vector2(core, halo) in world units; eye: the species' eye colour (the "eye" halo mode);
## cfg: tuning "fx" "bolt".
func _init(widths: Vector2, eye: Color, cfg: Dictionary) -> void:
	mesh = _mesh
	_blob_step = Num.i(cfg["blob_step"])
	_branch_tip = Num.f(cfg["branch_tip"])
	_blob_share = Num.f(cfg["blob_share"])
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var colours := halo_colours(cfg, eye)
	_halo_boost = halo_boost(cfg)
	for mat: ShaderMaterial in [_halo_main, _halo_branch]:
		mat.shader = SHADER
		mat.set_shader_parameter("tint", colours[0])
		mat.set_shader_parameter("fringe", colours[1])
		mat.set_shader_parameter("width", widths.y)
		mat.set_shader_parameter("boost", Num.f(cfg["boost_halo"]) * _halo_boost)
		mat.set_shader_parameter("falloff", Num.f(cfg["falloff_halo"]))
		mat.set_shader_parameter("min_px", Num.f(cfg["halo_min_px"]))
		mat.set_shader_parameter("rim", Num.f(cfg["rim"]["alpha"]))
		mat.set_shader_parameter("max_px", Num.f(cfg["halo_max_px"]))
		mat.render_priority = 1
	for mat: ShaderMaterial in [_core_main, _core_branch]:
		mat.shader = SHADER
		mat.set_shader_parameter("tint", CORE_COLOUR)
		mat.set_shader_parameter("fringe", colours[0])
		mat.set_shader_parameter("width", widths.x)
		mat.set_shader_parameter("boost", Num.f(cfg["boost_core"]))
		mat.set_shader_parameter("falloff", Num.f(cfg["falloff_core"]))
		mat.set_shader_parameter("min_px", Num.f(cfg["core_min_px"]))
		mat.set_shader_parameter("rim", Num.f(cfg["rim"]["core_alpha"]))
		mat.set_shader_parameter("rim_band", Vector4(0.55, 0.75, 0.9, 1.0))
		mat.render_priority = 2  # drawn after the glows, so its dark rim keeps it readable in them
	for mat: ShaderMaterial in all_materials():
		mat.set_shader_parameter("rim_tint", Color(str(cfg["rim"]["tint"])))
		mat.set_shader_parameter("wobble", Num.f(cfg["wobble"]))
		mat.set_shader_parameter("wobble_hz", Num.f(cfg["wobble_hz"]))
		mat.set_shader_parameter("level", 0.0)


## The halo's [inner, fringe] colours for the tuning's mode (or the capture's override).
static func halo_colours(cfg: Dictionary, eye: Color) -> Array[Color]:
	var mode := halo_mode_override if halo_mode_override != "" else str(cfg["halo_mode"])
	var row: Dictionary = cfg["halo_modes"][mode]
	var out: Array[Color] = []
	for key: String in ["inner", "fringe"]:
		var text := str(row[key])
		out.append(eye if text == "eye" else Color(text))
	out[0] = out[0].lerp(CORE_COLOUR, Num.f(row.get("inner_white", 0.0)))  # a white-hot inner
	return out


## How bright the tuning's halo mode is (1: as is); a near-white halo is dimmed so it does not veil
## pale ground.
static func halo_boost(cfg: Dictionary) -> float:
	var mode := halo_mode_override if halo_mode_override != "" else str(cfg["halo_mode"])
	var row: Dictionary = cfg["halo_modes"][mode]
	return Num.f(row.get("halo_boost", 1.0))


## Every material this bolt draws with (a ShaderKeep holds them so none compiles mid-rampage).
func all_materials() -> Array[ShaderMaterial]:
	return [_halo_main, _core_main, _halo_branch, _core_branch]


## The brightness (0..1) of the main channel and of the branches.
func set_levels(main: float, branch: float) -> void:
	for mat: ShaderMaterial in [_halo_main, _core_main]:
		mat.set_shader_parameter("level", main)
	for mat: ShaderMaterial in [_halo_branch, _core_branch]:
		mat.set_shader_parameter("level", branch)


## The colour multiplier for the next frames (the signature's power brightens the bolt).
func set_power(boost_core: float, boost_halo: float) -> void:
	for mat: ShaderMaterial in [_core_main, _core_branch]:
		mat.set_shader_parameter("boost", boost_core)
	for mat: ShaderMaterial in [_halo_main, _halo_branch]:
		mat.set_shader_parameter("boost", boost_halo * _halo_boost)


## Redraws the bolt: `main` (world points) and `branches` (each a world polyline), the branches at
## `branch_width` of the main channel's width and fading toward their tips.
func rebuild(
	main: PackedVector3Array, branches: Array[PackedVector3Array], branch_width: float
) -> void:
	_mesh.clear_surfaces()
	_surface(_halo_main, [main], 1.0, 0.7)
	_surface(_core_main, [main], 1.0, 0.7)
	_surface(_halo_branch, branches, branch_width, _branch_tip)
	_surface(_core_branch, branches, branch_width, _branch_tip)


func hide_all() -> void:
	_mesh.clear_surfaces()


## One surface: every polyline as a strip of quads, tapering to `tip` of its width and brightness.
func _surface(mat: ShaderMaterial, lines: Array, width: float, tip: float) -> void:
	var any := false
	for line: PackedVector3Array in lines:
		any = any or line.size() > 1
	if not any:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	for line: PackedVector3Array in lines:
		for i: int in line.size() - 1:
			_quad(line, i, width, tip)
		for i: int in range(0, line.size() if _glows(mat) else 0, _blob_step):
			_blob(line[i], width, lerpf(1.0, tip, float(i) / (line.size() - 1)))
	_mesh.surface_end()


## The segment i..i+1 as two triangles; joints share their tangent so the strip has no gaps.
func _quad(line: PackedVector3Array, i: int, width: float, tip: float) -> void:
	var last := float(line.size() - 1)
	var ends: Array[Vector3] = []  # [a-, a+, b-, b+] as (side, along, taper)
	for k: int in 2:
		var taper := lerpf(1.0, tip, (i + k) / last)
		for side: float in [-1.0, 1.0]:
			ends.append(Vector3(side, (i + k) / last, taper))
	var at: Array[int] = [0, 1, 2, 1, 3, 2]
	for n: int in at:
		var e := ends[n]
		var p := line[i + n / 2]
		_mesh.surface_set_color(Color(width * e.z, e.z, 0.0))
		_mesh.surface_set_normal(_tangent(line, i + n / 2))
		_mesh.surface_set_uv(Vector2(e.x, e.y))
		_mesh.surface_add_vertex(p)


## Whether `mat` is one of the glows (the halo strips): only they get blobs, the core stays a line.
func _glows(mat: ShaderMaterial) -> bool:
	return mat == _halo_main or mat == _halo_branch


## A round camera-facing blob on a point of the line (UV = the quad's corner, COLOR.b = 1).
func _blob(at: Vector3, width: float, taper: float) -> void:
	for corner: Vector2 in BLOB_CORNERS:
		_mesh.surface_set_color(Color(width * taper, taper * _blob_share, 1.0))
		_mesh.surface_set_normal(Vector3.UP)
		_mesh.surface_set_uv(corner)
		_mesh.surface_add_vertex(at)


static func _tangent(line: PackedVector3Array, i: int) -> Vector3:
	var a := line[maxi(i - 1, 0)]
	var b := line[mini(i + 1, line.size() - 1)]
	return (b - a).normalized()
