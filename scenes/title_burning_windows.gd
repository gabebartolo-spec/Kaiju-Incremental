class_name TitleBurningWindows
extends MultiMeshInstance3D
## The windows of the burning floors on the title's far shore, fire-orange (director D-151: "burning
## floors' windows turn fire-orange", the fire-spread GLOWING state): a row of panes either side of
## every window fire, on the same window grid the towers' facades are painted on, brightest at the
## fire and dimmer along the floor. Presentation only; numbers in tuning "title" "fires" "windows".

const GLOW := preload("res://scenes/title_burning_windows.gdshader")
## A window is one cell wide and two rows tall on the facade grid.
const ROWS := 2.0
## Panes stand this far out from the wall (m), clear of its facade.
const OUT := 0.04

var _spots: Array[Vector3]
var _cfg: Dictionary
var _rng := Seeds.make("title_windows", 0)


## spots: each burning window's cell centre (x, y of its lower row's middle, z of the wall).
func _init(spots: Array[Vector3], cfg: Dictionary) -> void:
	_spots = spots
	_cfg = cfg


func _ready() -> void:
	var cell := 1.0 / CitySkyline.FAR_GRAIN
	var reach := Num.i(_cfg["cells"])
	var panes: Array[Transform3D] = []
	var shades := PackedColorArray()
	for spot: Vector3 in _spots:
		for k: int in range(-reach, reach + 1):
			if k != 0 and _rng.randf() < Num.f(_cfg["gap"]):
				continue
			var at := Vector3(spot.x + k * cell, spot.y, spot.z + OUT)
			panes.append(Transform3D(Basis.from_scale(Vector3(cell, cell * ROWS, 1.0)), at))
			var share := 1.0 - float(absi(k)) / float(reach + 1)
			shades.append(Color(share, share, share))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = GLOW
	mat.set_shader_parameter("colour", Color(str(_cfg["colour"])))
	mat.set_shader_parameter("glow", Num.f(_cfg["glow"]))
	quad.material = mat
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = panes.size()
	for i: int in panes.size():
		multimesh.set_instance_transform(i, panes[i])
		multimesh.set_instance_color(i, shades[i])
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
