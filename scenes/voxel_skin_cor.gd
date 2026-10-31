class_name VoxelSkinCor
extends RefCounted
## Director 2026-10-31 (thighs): optimized centres of rotation (Le & Hodgins 2016). The linear
## blend of a cube's bones shrinks where they turn apart (the thin, pinched thigh). With a centre
## of rotation c per blended cube (baked by tools/kaiju_skin/cor.py), the cube shader moves c by
## the linear blend and the cube by the bones' blended rotation about it, so it keeps its distance
## from the joint. Read from an optional block after the helpers; tuning
## render_opt.kaiju_cor_skinning turns it off. Presentation only.

## Block tag, then u32 count; per cube f32 x, y, z (rig units) and f32 flag (1 = has a centre).
const TAG := "CORS"
const RECORD_BYTES := 16
## Texels per row of the centres texture (each cube reads its own by its instance index).
const WIDTH := 4096


## Byte offset just past the helper block that starts at `at` (`at` itself when there is none).
static func after_helpers(at: int, helpers: int) -> int:
	if helpers <= 0:
		return at
	return at + 6 + helpers * VoxelSkinHelpers.HELPER_BYTES


## The centres as an RGBA float texture, WIDTH texels a row, or null when raw has no block for
## `cells` cubes at `at`.
static func texture(raw: PackedByteArray, at: int, cells: int) -> ImageTexture:
	if at + 8 > raw.size() or raw.slice(at, at + 4).get_string_from_ascii() != TAG:
		return null
	if raw.decode_u32(at + 4) != cells or at + 8 + cells * RECORD_BYTES > raw.size():
		push_warning("VoxelSkinCor: the centre block does not match the cubes")
		return null
	var rows := ceili(float(cells) / WIDTH)
	var data := raw.slice(at + 8, at + 8 + cells * RECORD_BYTES)
	data.resize(rows * WIDTH * RECORD_BYTES)
	var img := Image.create_from_data(WIDTH, rows, false, Image.FORMAT_RGBAF, data)
	return ImageTexture.create_from_image(img)


## Hands the skin's cube material the centres when raw carries them and tuning allows.
static func apply(mat: ShaderMaterial, raw: PackedByteArray, at: int, cells: int) -> bool:
	if Num.i(Content.section("render_opt")["kaiju_cor_skinning"]) == 0:
		return false
	var tex := texture(raw, at, cells)
	if tex == null:
		return false
	mat.set_shader_parameter("cors", tex)
	mat.set_shader_parameter("use_cor", true)
	return true
