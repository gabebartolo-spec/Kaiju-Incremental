class_name SkylineMeshes
extends RefCounted
## CitySkyline's meshes: the painted stand-in and far facade boxes (facade.gdshader, or
## facade_far.gdshader in the haze) and the plain boxes. Split out of CitySkyline to keep files
## small; presentation only.

const FACADE := preload("res://scenes/facade.gdshader")
const FACADE_FAR := preload("res://scenes/facade_far.gdshader")


static func facades(boxes: Array[Dictionary], haze: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var mesh := BoxMesh.new()
	mesh.material = facade_material(haze)
	mm.mesh = mesh
	mm.instance_count = boxes.size()
	for i: int in boxes.size():
		var box: Dictionary = boxes[i]
		var size: Vector3 = box["size"]
		var at: Vector3 = box["at"]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(size), at))
		var color: Color = box["color"]
		var custom: Color = box["custom"]
		mm.set_instance_color(i, color)
		mm.set_instance_custom_data(i, custom)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if haze > 0.0:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


static func facade_material(haze: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FACADE_FAR if haze > 0.0 else FACADE
	mat.set_shader_parameter("roof_color", Look.color("roof"))
	mat.set_shader_parameter("window_color", Look.color("window"))
	mat.set_shader_parameter("lit_color", Look.color("window_lit_color"))
	mat.set_shader_parameter("glow", Look.value("window_glow"))
	mat.set_shader_parameter("haze_color", Look.color("fog_color"))
	mat.set_shader_parameter("haze", haze)
	# Windows filtered over the pixel once they are thinner than it (render_opt.facade_aa).
	var cfg := Content.section("render_opt")
	mat.set_shader_parameter("filter_windows", cfg.get("facade_aa", true) == true)
	mat.set_shader_parameter("filter_start", Num.f(cfg["facade_aa_start"]))
	mat.set_shader_parameter("filter_cells", Num.f(cfg["facade_aa_cells"]))
	return WindowPalette.apply_common(mat)


## CitySkyline's plain boxes (`plain`: its _plain list): roof gear and the lattice tower in the
## instance colour; the concrete (expressway, far shore quay) in the ground's concrete look. The
## hazy ones fade like the far skyline.
static func plain_boxes(plain: Array[Dictionary], cfg: Dictionary, far_haze: FarHaze) -> Node3D:
	var holder := Node3D.new()
	for variant: int in 4:
		var hazy := variant % 2 == 1
		var concrete := variant >= 2
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		var mesh := BoxMesh.new()
		var haze := Num.f(cfg["far_haze"]) * 1.6 if hazy else 0.0
		var mat := (
			GroundKit.concrete_material(haze, hazy, Num.i(cfg["map_seed"]))
			if concrete
			else facade_material(haze)
		)
		if not concrete:
			mat.set_shader_parameter("plain", true)
		if hazy:
			far_haze.track([mat])
		mesh.material = mat
		mm.mesh = mesh
		var picked: Array[Dictionary] = []
		for box: Dictionary in plain:
			if box["hazy"] == hazy and box["concrete"] == concrete:
				picked.append(box)
		mm.instance_count = picked.size()
		for i: int in picked.size():
			var t: Transform3D = picked[i]["t"]
			var c: Color = picked[i]["c"]
			mm.set_instance_transform(i, t)
			mm.set_instance_color(i, c)
			mm.set_instance_custom_data(i, Color(0, 0, 0, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mmi)
	return holder
