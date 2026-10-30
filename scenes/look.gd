class_name Look
extends RefCounted
## Reads the active look (Content.look(), data/looks.json) for presentation: colours, the voxel
## material, per-voxel colour noise. One place, so a look change never touches scene code.

const VOXEL_SHADER := preload("res://scenes/voxel.gdshader")
## The voxel material in the city's surface family, for a model that moves as a whole (a train car).
const VOXEL_DETAIL_SHADER := preload("res://scenes/voxel_detail.gdshader")
## The voxel material with the kaiju's hide grain, for the voxels a kaiju rig puts on its bones.
const VOXEL_HIDE_SHADER := preload("res://scenes/voxel_hide.gdshader")
## hide_grain.gdshaderinc's uniforms and the look keys (kaiju_hide_*) they read.
const HIDE_KEYS: Array[String] = ["crevice", "crevice_width", "tone", "fleck", "fleck_dark", "seed"]


static func value(key: String) -> float:
	return Num.f(Content.look().get(key, 0.0))


static func color(key: String) -> Color:
	return Color(str(Content.look().get(key, "ff00ff")))


static func styles() -> Array[Color]:
	var out: Array[Color] = []
	var raw: Array = Content.look().get("styles", [])
	for hex: String in raw:
		out.append(Color(hex))
	return out


## The MultiMesh material: instance colour is sRGB, alpha 0 marks a glowing cell.
static func voxel_material(glow: float) -> ShaderMaterial:
	ThreadCheck.main_only("Look.voxel_material")
	var mat := ShaderMaterial.new()
	mat.shader = VOXEL_SHADER
	mat.set_shader_parameter("glow", glow)
	return mat


## A cube mesh for one voxel of `size`, inset by the look so the grid shows (or not).
static func voxel_mesh(size: float, glow: float) -> BoxMesh:
	ThreadCheck.main_only("Look.voxel_mesh")
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size * value("voxel_inset")
	mesh.material = voxel_material(glow)
	return mesh


## voxel_mesh() drawn in the city's surface family (voxel_detail.gdshader): the MultiMesh must carry
## each cell's grid index in its custom data (VoxelBuilder.detail).
static func voxel_detail_mesh(size: float, glow: float) -> BoxMesh:
	var mesh := voxel_mesh(size, glow)
	mesh.material = voxel_detail_material(size, glow, false)
	return mesh


## The voxel material in the city's surface family (voxel_detail.gdshader) for cells `size` wide;
## baked: a VoxelBuilder.bake() mesh (detail from its vertices) instead of a detail MultiMesh.
static func voxel_detail_material(size: float, glow: float, baked: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = VOXEL_DETAIL_SHADER
	mat.set_shader_parameter("glow", glow)
	mat.set_shader_parameter("voxel", size)
	mat.set_shader_parameter("baked", baked)
	return mat


## D-397: the kaiju's own hide grain (hide_grain.gdshaderinc) on `mat`, for cells `voxel` wide:
## scutes kaiju_hide_cell_voxels cells wide. kaiju_hide_on false leaves the hide flat (the
## grain's crevices, tone and flecks at 0).
static func hide_grain(mat: ShaderMaterial, voxel: float) -> void:
	var on: bool = Content.look().get("kaiju_hide_on", false) == true
	mat.set_shader_parameter("hide_cell", voxel * value("kaiju_hide_cell_voxels"))
	for key: String in HIDE_KEYS:
		var amount := value("kaiju_hide_" + key)
		mat.set_shader_parameter("hide_" + key, amount if on or key.ends_with("_width") else 0.0)


## The voxel material with the hide grain (voxel_hide.gdshader) for a kaiju rig's bone voxels.
static func hide_material(voxel: float, glow: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = VOXEL_HIDE_SHADER
	mat.set_shader_parameter("glow", glow)
	mat.set_shader_parameter("roughness_value", value("kaiju_roughness"))
	hide_grain(mat, voxel)
	return mat


## Deterministic brightness jitter per cell, so surfaces read as built from blocks.
static func jitter(base: Color, cell: Vector3i, salt: int) -> Color:
	var amount := value("color_noise")
	if amount <= 0.0:
		return base
	var h := absi(hash(Vector4i(cell.x, cell.y, cell.z, salt)))
	var t := float(h % 1000) / 1000.0 * 2.0 - 1.0
	return Color(
		base.r * (1.0 + t * amount),
		base.g * (1.0 + t * amount),
		base.b * (1.0 + t * amount),
		base.a
	)
