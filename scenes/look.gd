class_name Look
extends RefCounted
## Reads the active look (Content.look(), data/looks.json) for presentation: colours, the voxel
## material, per-voxel colour noise. One place, so a look change never touches scene code.

const VOXEL_SHADER := preload("res://scenes/voxel.gdshader")


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


## The voxel material: colour is sRGB, alpha 0 marks a glowing cell. `box_mesh` for a BoxMesh
## per cell (MultiMesh); otherwise a baked mesh of faces that carries its face UVs.
static func voxel_material(glow: float, box_mesh := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = VOXEL_SHADER
	mat.set_shader_parameter("glow", glow)
	mat.set_shader_parameter("box_mesh", box_mesh)
	edge_params(mat)
	return mat


## The look's voxel edge shading (voxel_edge.gdshaderinc) on a voxel material.
static func edge_params(mat: ShaderMaterial) -> void:
	for key: String in ["edge_width", "edge_bevel", "edge_dark"]:
		mat.set_shader_parameter(key, value(key))


## A cube mesh for one voxel of `size`, inset by the look so the grid shows (or not).
static func voxel_mesh(size: float, glow: float) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size * value("voxel_inset")
	mesh.material = voxel_material(glow, true)
	return mesh


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
