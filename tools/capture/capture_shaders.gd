extends SceneTree
## Shader comparison (director 2026-10-20: "find a few different shaders and create side by side
## comparisons at different times of day"): the same seeded, autoplayed rampage (city seed 0, the
## reptilian) under one shader candidate and one time of day, saving stills once the kaiju has
## risen. Times of day are the look's "times" in data/looks.json.
##   today   the concrete look as shipped (crease edges)
##   toon      cel light in three flat bands on every lit surface, inked silhouettes, no crease
##   diorama   strong tilt-shift blur near and far, rich colour, ambient occlusion (a miniature)
##   cinematic heavy ambient occlusion, high contrast, a warm haze and bloom on fire, no crease
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 \
##     --script tools/capture/capture_shaders.gd -- --shader=toon --time=noon --out=<dir>

const TOON := preload("res://scenes/toon_post.gdshader")
## The lit surface shaders toon gives a cel light() to.
const LIT := [
	"res://scenes/voxel.gdshader",
	"res://scenes/voxel_skin.gdshader",
	"res://scenes/voxel_skin_fill.gdshader",
	"res://scenes/building_baked.gdshader",
	"res://scenes/facade.gdshader",
	"res://scenes/facade_far.gdshader",
]
const CEL := """
void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float band = ndl > 0.45 ? 1.0 : (ndl > 0.12 ? 0.55 : 0.2);
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
"""

var _shader := "today"
var _time := "dusk"
var _out := "user://shaders"
var _stills: Array[float] = [4.0, 10.0]


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shader="):
			_shader = arg.substr(9)
		elif arg.begins_with("--time="):
			_time = arg.substr(7)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	Content.set_time(_time)
	var look := Content.look()
	if _shader != "today":
		look["crease_strength"] = 0.0
	if _shader == "toon":
		for path: String in LIT:
			var shader: Shader = load(path)
			if not shader.code.contains("void light()"):
				shader.code += CEL
	var rampage := Rampage.new()
	var species := Content.species_def("reptilian")
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"), species, UpgradeTree.new(Content.upgrades())
	)
	rampage.setup(
		species,
		stats,
		CityGen.generate(Seeds.make("city", 0), Content.section("city")),
		Content.times().find(_time)  # the run that plays this time of day
	)
	rampage.set_autoplay(true)
	root.add_child(rampage)
	await physics_frame
	_apply(rampage)
	while rampage.sim.emerge.active:
		await physics_frame
	var frames := 0
	for at: float in _stills:
		while frames < int(at * 60.0) and not rampage.sim.over:
			await physics_frame
			frames += 1
		await process_frame
		var image := root.get_viewport().get_texture().get_image()
		image.save_png("%s/%s_%s_t%02d.png" % [_out, _shader, _time, int(at)])
	quit()


func _apply(rampage: Rampage) -> void:
	var env: Environment = null
	for node: Node in rampage.find_children("*", "WorldEnvironment", true, false):
		env = (node as WorldEnvironment).environment
	var camera := root.get_viewport().get_camera_3d()
	match _shader:
		"toon":
			var quad := MeshInstance3D.new()
			var mesh := QuadMesh.new()
			mesh.size = Vector2(2, 2)
			quad.mesh = mesh
			var mat := ShaderMaterial.new()
			mat.shader = TOON
			mat.render_priority = Material.RENDER_PRIORITY_MIN
			mat.set_shader_parameter("band_mix", 0.0)
			quad.material_override = mat
			quad.custom_aabb = AABB(Vector3(-1e6, -1e6, -1e6), Vector3(2e6, 2e6, 2e6))
			quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rampage.add_child(quad)
		"diorama":
			env.ssao_enabled = true
			env.ssao_intensity = 2.5
			env.adjustment_enabled = true
			env.adjustment_saturation = 1.5
			env.adjustment_contrast = 1.08
			# In focus at the kaiju (the camera's rest distance, zoomed by body size as Rampage does).
			var focus := rampage.camera_rest.length() * CameraTuning.zoom(rampage.sim.body_scale())
			var attrs := CameraAttributesPractical.new()
			attrs.dof_blur_far_enabled = true
			attrs.dof_blur_far_distance = focus + 8.0
			attrs.dof_blur_far_transition = 10.0
			attrs.dof_blur_near_enabled = true
			attrs.dof_blur_near_distance = focus - 10.0
			attrs.dof_blur_near_transition = 6.0
			attrs.dof_blur_amount = 0.35
			camera.attributes = attrs
		"cinematic":
			env.ssao_enabled = true
			env.ssao_intensity = 3.0
			env.ssao_power = 2.0
			env.glow_enabled = true
			env.glow_intensity = 1.0
			env.glow_hdr_threshold = 0.9
			env.adjustment_enabled = true
			env.adjustment_contrast = 1.3
			env.adjustment_saturation = 0.9
