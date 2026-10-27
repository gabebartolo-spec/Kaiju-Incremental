class_name BoltView
extends MeshInstance3D
## One bolt drawn as capsules with the game's one beam shader (bolt.gdshader): every segment of the
## main channel, its branches and the charge arcs is its own camera-facing quad, and the shader
## rounds joints and caps by distance to the segment (no halo strips, no blobs: the glow is the
## engine's own bloom on the HDR core, plus a thin tinted fringe). The same class draws the breath,
## the Thunder Beam and later the Taskforce's lasers; only widths and colours differ by owner.
## Presentation only.

const SHADER := preload("res://scenes/bolt.gdshader")
const CORE_COLOUR := Color(1.0, 0.97, 0.92)
## The bolt's quads are cut by the camera's frustum only at their ends: keep them from being culled
## by a bounding box that ignores the pixel floor.
const CULL_MARGIN := 40.0
## Which fringe colours to draw instead of the tuning's choice ("" = the tuning's): a capture sets
## this to show the director's three options (R 17.6) from the same frame.
static var halo_mode_override := ""

var _mesh := ArrayMesh.new()
var _main_tip: float
var _mouth_share: float
var _branch_tip: float
var _main := ShaderMaterial.new()
var _branch := ShaderMaterial.new()
var _arc := ShaderMaterial.new()


## core: the main channel's width in world units; eye: the species' eye colour (the "eye" mode);
## cfg: tuning "fx" "bolt".
func _init(core: float, eye: Color, cfg: Dictionary) -> void:
	mesh = _mesh
	_branch_tip = Num.f(cfg["branch_tip"])
	_main_tip = Num.f(cfg["main_tip"])
	_mouth_share = Num.f(cfg["mouth_share"])
	extra_cull_margin = CULL_MARGIN
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var colours := halo_colours(cfg, eye)
	var fringe_boost := Num.f(cfg["fringe_boost"]) * halo_boost(cfg)
	for mat: ShaderMaterial in all_materials():
		mat.shader = SHADER
		mat.set_shader_parameter("tint", colours[0])
		mat.set_shader_parameter("fringe", colours[1])
		mat.set_shader_parameter("core_colour", core_colour(cfg))
		mat.set_shader_parameter("width", core)
		mat.set_shader_parameter("boost", Num.f(cfg["boost_core"]))
		mat.set_shader_parameter("fringe_boost", fringe_boost)
		mat.set_shader_parameter("white_to", Num.f(cfg["white_to"]))
		mat.set_shader_parameter("tint_to", Num.f(cfg["tint_to"]))
		mat.set_shader_parameter("min_px", Num.f(cfg["core_min_px"]))
		mat.set_shader_parameter("soft", Num.f(cfg["bolt_soft"]))
		mat.set_shader_parameter("wobble", Num.f(cfg["wobble"]))
		mat.set_shader_parameter("wobble_hz", Num.f(cfg["wobble_hz"]))
		mat.set_shader_parameter("level", 0.0)
	_arc.set_shader_parameter("alpha_scale", Num.f(cfg["arc_alpha"]))
	_arc.set_shader_parameter("min_px", Num.f(cfg["arc_min_px"]))
	_main.render_priority = 2
	_branch.render_priority = 1
	_arc.render_priority = 0


## The fringe's [inner, fringe] colours for the tuning's mode (or the capture's override).
static func halo_colours(cfg: Dictionary, eye: Color) -> Array[Color]:
	var row := _mode_row(cfg)
	var out: Array[Color] = []
	for key: String in ["inner", "fringe"]:
		var text := str(row[key])
		out.append(eye if text == "eye" else Color(text))
	out[0] = out[0].lerp(core_colour(cfg), Num.f(row.get("inner_white", 0.0)))  # a white-hot inner
	return out


## How bright the tuning's fringe mode is (1: as is); a near-white fringe is dimmed so it does not
## veil pale ground.
static func halo_boost(cfg: Dictionary) -> float:
	return Num.f(_mode_row(cfg).get("halo_boost", 1.0))


## The axis colour of the mode (the purple's white-violet, D-357; white-hot where it names none).
static func core_colour(cfg: Dictionary) -> Color:
	return Color(str(_mode_row(cfg).get("core", CORE_COLOUR.to_html(false))))


## The mouth light's and the flares' colour of the mode (`fallback` where it names none).
static func flare_colour(cfg: Dictionary, fallback: Color) -> Color:
	return Color(str(_mode_row(cfg).get("flare", fallback.to_html(false))))


static func _mode_row(cfg: Dictionary) -> Dictionary:
	var mode := halo_mode_override if halo_mode_override != "" else str(cfg["halo_mode"])
	var row: Dictionary = cfg["halo_modes"][mode]
	return row


## The charge-up's look (SpineCharge): its arcs `alpha` see-through, at least `min_px` wide, and
## never faded against the hide they jump over (the soft fade would eat them on the back).
func arc_look(alpha: float, min_px: float) -> void:
	_arc.set_shader_parameter("alpha_scale", alpha)
	_arc.set_shader_parameter("min_px", min_px)
	_arc.set_shader_parameter("soft", 0.0)


## Every material this bolt draws with (a ShaderKeep holds them so none compiles mid-rampage).
func all_materials() -> Array[ShaderMaterial]:
	return [_main, _branch, _arc]


## The brightness (0..1) of the main channel, of the branches and of the charge-up arcs.
func set_levels(main: float, branch: float, arc: float) -> void:
	_main.set_shader_parameter("level", main)
	_branch.set_shader_parameter("level", branch)
	_arc.set_shader_parameter("level", arc)


## The colour multipliers for the next frames (the signature's power brightens the bolt): the
## white-hot axis and the tinted fringe.
func set_power(boost_core: float, boost_fringe: float) -> void:
	for mat: ShaderMaterial in all_materials():
		mat.set_shader_parameter("boost", boost_core)
		mat.set_shader_parameter("fringe_boost", boost_fringe)


## Redraws the bolt: `main` (world points), `branches` and `arcs` (each a world polyline), the
## branches at widths.x and the arcs at widths.y of the main channel's width, fading to their tips.
func rebuild(
	main: PackedVector3Array,
	branches: Array[PackedVector3Array],
	arcs: Array[PackedVector3Array],
	widths: Vector2
) -> void:
	_mesh.clear_surfaces()
	_surface(_main, [main], Vector2(1.0, _main_tip), Vector2(_mouth_share, 1.0))
	_surface(
		_branch, branches, Vector2(widths.x, widths.x * _branch_tip), Vector2(1.0, _branch_tip)
	)
	_surface(_arc, arcs, Vector2(widths.y, widths.y * _branch_tip), Vector2(1.0, _branch_tip))


func hide_all() -> void:
	_mesh.clear_surfaces()


## One surface: every segment of every line as a capsule quad. `taper` is the width share at the
## line's start and end, `bright` the brightness share there.
func _surface(mat: ShaderMaterial, lines: Array, taper: Vector2, bright: Vector2) -> void:
	var verts := PackedVector3Array()
	var other := PackedFloat32Array()
	var info := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for line: PackedVector3Array in lines:
		var last := float(line.size() - 1)
		for i: int in line.size() - 1:
			var t0 := i / last
			var t1 := (i + 1) / last
			var share := lerpf(taper.x, taper.y, (t0 + t1) * 0.5)
			var base := verts.size()
			for end: int in 2:
				var here := line[i + end]
				var there := line[i + 1 - end]
				var t := t1 if end == 1 else t0
				for side: float in [-1.0, 1.0]:
					verts.append(here)
					other.append_array([there.x, there.y, there.z, 0.0])
					info.append_array([share, lerpf(bright.x, bright.y, t), t, 0.0])
					uvs.append(Vector2(float(end), side))
			idx.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_CUSTOM0] = other
	arrays[Mesh.ARRAY_CUSTOM1] = info
	arrays[Mesh.ARRAY_INDEX] = idx
	var flags := (
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	)
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	_mesh.surface_set_material(_mesh.get_surface_count() - 1, mat)
