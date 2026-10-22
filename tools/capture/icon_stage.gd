extends RefCounted
## The little studio the UI icons are rendered in (render_icon.gd, render_digits.gd): a
## transparent square viewport, the game's own light and look (the species card's key light and
## fill, the kaiju's cool rim light, the city's tone map, contrast, saturation and glow) and the
## HUD's dark outline, drawn as a second pass round whatever the first pass shows. Tools only.

const OUTLINE_SHADER := preload("res://tools/capture/icon_outline.gdshader")
## Lights, as the species card (KEY, FILL) and KaijuModel (RIM) set them; fill offsets in model
## radii.
const KEY_ROTATION := Vector3(-40.0, -30.0, 0.0)
const KEY_ENERGY := 1.25
const FILL_AT := Vector3(-0.8, 0.8, 1.1)
const FILL_ENERGY := 0.8
const RIM_ROTATION := Vector3(-35.0, 160.0, 0.0)
const RIM_ENERGY := 2.4
const RIM_COLOR := Color("9fc4ff")
## The object's render layers: the world's lights (1) and the kaiju-only rim light (2).
const LAYERS := 1 | 2
const WARMUP_FRAMES := 6


## Renders `subject` (a Node3D, origin and size in `fit`) to a transparent `size` square image.
## opts: yaw (deg off straight on the face), pitch (deg above), fov (deg), face (the way the model
## looks, a Vector3), margin (share of the frame kept clear), outline (share of the frame),
## fx (a Node3D already placed in the subject's space), hdr_glow (bool).
static func render(
	tree: SceneTree, subject: Node3D, fit: AABB, size: int, opts: Dictionary
) -> Image:
	var pass_one := SubViewport.new()
	pass_one.size = Vector2i(size, size)
	pass_one.transparent_bg = true
	pass_one.own_world_3d = true
	pass_one.msaa_3d = Viewport.MSAA_8X
	pass_one.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(pass_one)
	var glow: bool = opts.get("hdr_glow", true)
	pass_one.add_child(_environment(glow))
	var radius := fit.size.length() * 0.5
	for light: Node in _lights(radius):
		pass_one.add_child(light)
	_layer(subject)
	pass_one.add_child(subject)
	if opts.has("fx"):
		var fx: Node3D = opts["fx"]
		pass_one.add_child(fx)
	var cam := Camera3D.new()
	cam.fov = Num.f(opts.get("fov", 28.0))
	pass_one.add_child(cam)
	var margin := 1.0 + Num.f(opts.get("margin", 0.16))
	var dist := radius * margin / sin(deg_to_rad(cam.fov) * 0.5)
	var face: Vector3 = opts.get("face", Vector3(0, 0, -1))
	var yaw := deg_to_rad(Num.f(opts.get("yaw", 38.0)))
	var pitch := deg_to_rad(Num.f(opts.get("pitch", 14.0)))
	var dir := view_from(face, yaw, pitch)
	var centre := fit.get_center()
	cam.position = centre + dir.normalized() * dist
	cam.look_at(centre)
	# Pass two: the dark outline round everything pass one drew.
	var pass_two := SubViewport.new()
	pass_two.size = Vector2i(size, size)
	pass_two.transparent_bg = true
	pass_two.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var rect := TextureRect.new()
	rect.texture = pass_one.get_texture()
	rect.size = Vector2(size, size)
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.set_shader_parameter("outline_color", UiKit.outline_color())
	mat.set_shader_parameter("radius_px", Num.f(opts.get("outline", 0.025)) * size)
	rect.material = mat
	pass_two.add_child(rect)
	tree.root.add_child(pass_two)
	for _i: int in WARMUP_FRAMES:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var image := pass_two.get_texture().get_image()
	pass_two.queue_free()
	pass_one.queue_free()
	return image


## The unit vector from the subject toward the camera: 3/4 view, `yaw` radians off straight at the
## face, `pitch` radians above.
static func view_from(face: Vector3, yaw: float, pitch: float) -> Vector3:
	return (face.rotated(Vector3.UP, yaw) * cos(pitch) + Vector3.UP * sin(pitch)).normalized()


## The 80 px (or any) preview of a full-size icon, made from premultiplied colour so the soft edge
## keeps no halo.
static func preview(source: Image, size: int) -> Image:
	var img := source.duplicate() as Image
	img.convert(Image.FORMAT_RGBAF)
	img.premultiply_alpha()
	img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	for y: int in size:
		for x: int in size:
			var c := img.get_pixel(x, y)
			if c.a > 0.0001:
				img.set_pixel(x, y, Color(c.r / c.a, c.g / c.a, c.b / c.a, c.a))
	img.convert(Image.FORMAT_RGBA8)
	return img


static func _environment(glow: bool) -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = (
		Look.color("ambient_color") if Content.look().has("ambient_color") else Color("6f86a8")
	)
	env.ambient_light_energy = maxf(0.6, Look.value("ambient"))
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.adjustment_enabled = true
	env.adjustment_saturation = Look.value("saturation")
	env.adjustment_contrast = Look.value("contrast")
	env.ssao_enabled = true
	env.ssao_intensity = Look.value("ssao")
	env.glow_enabled = glow
	env.glow_intensity = maxf(0.6, Look.value("glow"))
	env.glow_hdr_threshold = 1.0
	var out := WorldEnvironment.new()
	out.environment = env
	return out


static func _lights(radius: float) -> Array[Node]:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = KEY_ROTATION
	key.light_energy = KEY_ENERGY
	var fill := OmniLight3D.new()
	fill.position = FILL_AT * radius * 3.0
	fill.omni_range = radius * 12.0
	fill.light_energy = FILL_ENERGY
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = RIM_ROTATION
	rim.light_color = RIM_COLOR
	rim.light_energy = RIM_ENERGY
	rim.light_cull_mask = 2
	return [key, fill, rim]


static func _layer(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = LAYERS
	for child: Node in node.get_children():
		_layer(child)
