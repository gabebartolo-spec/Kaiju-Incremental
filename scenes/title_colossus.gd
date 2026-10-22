class_name TitleColossus
extends Node3D
## The kaiju behind the title's burning city (director 2026-10-22: "occasional explosions should
## reveal the silhouette of the reptilian colossus obscured in the inferno"): the game's adult
## reptilian seen from behind, a baked black silhouette (tools/capture/bake_colossus.gd,
## assets/title/colossus_N.png) standing deep in the far shore's smoke, towering over the towers,
## hidden. A big explosion behind it lights it for a moment, dark against the fireball, then it is
## hidden again; each footfall (the thud and the water's shiver) walks it one step, so every reveal
## finds it a little further on, in the next pose of its stride. Presentation only; numbers in
## tuning "title" "colossus".

const BODY := preload("res://scenes/title_colossus.gdshader")
const POSE := "res://assets/title/colossus_%d.png"

var _cfg: Dictionary
var _steps := 0
var _left := 0.0
var _glow: MeshInstance3D
var _card: MeshInstance3D
var _poses: Array[Texture2D] = []
var _body: ShaderMaterial
var _eye: MeshInstance3D
var _t := 0.0
var _lit := 0.0


func _init(cfg: Dictionary) -> void:
	_cfg = cfg


func _ready() -> void:
	for i: int in Num.i(_cfg["poses"]):
		_poses.append(load(POSE % i) as Texture2D)
	_glow = _glow_sprite()
	add_child(_glow)
	_card = _card_sprite()
	add_child(_card)
	_eye = _eye_sprite()
	add_child(_eye)
	_show(0.0)
	_place()


## One footstep along the path (it goes out and comes back, so it never leaves the right side).
func step() -> void:
	_steps += 1
	_place()


## Lit for the length of the explosion's glow (tuning "reveal_s").
func reveal() -> void:
	_left = Num.f(_cfg["reveal_s"])


## Where the explosion that reveals it goes off: behind it and high, so it stands dark in front.
func burst_point() -> Vector3:
	return position + Vector3(0.0, Num.f(_cfg["burst_height"]), -Num.f(_cfg["burst_back"]))


func _process(delta: float) -> void:
	_t += delta
	if _left <= 0.0:
		_show(0.0)
		return
	_left = maxf(0.0, _left - delta)
	var total := Num.f(_cfg["reveal_s"])
	var age := total - _left
	var rise := Num.f(_cfg["rise_s"])
	var fall := Num.f(_cfg["fall_s"])
	_show(minf(1.0, age / rise) * minf(1.0, _left / fall))


## The colossus at `amount` (0 hidden .. 1 dark and clear) and the great fire glow behind it.
func _show(amount: float) -> void:
	_body.set_shader_parameter("amount", maxf(Num.f(_cfg["idle_alpha"]), amount))
	var mat := _glow.material_override as StandardMaterial3D
	var glow := lerpf(Num.f(_cfg["glow_idle"]), Num.f(_cfg["glow_peak"]), amount)
	mat.albedo_color = Color(Color(str(_cfg["glow_color"])), glow)
	# The eye: dim and slowly pulsing all the time, bright while it is revealed.
	var eye: Dictionary = _cfg["eye"]
	var pulse := 0.5 + 0.5 * sin(_t * TAU * Num.f(eye["pulse_hz"]))
	var idle := Num.f(eye["idle"]) * (1.0 - Num.f(eye["pulse"]) + Num.f(eye["pulse"]) * 2.0 * pulse)
	var eye_mat := _eye.material_override as StandardMaterial3D
	eye_mat.albedo_color = Color(Color(str(eye["colour"])), lerpf(idle, Num.f(eye["peak"]), amount))


## The card the silhouette is drawn on: as tall as tuning "height", its feet on the node's origin.
func _card_sprite() -> MeshInstance3D:
	var height := Num.f(_cfg["height"])
	var tex := _poses[0]
	var quad := QuadMesh.new()
	quad.size = Vector2(height * tex.get_width() / tex.get_height(), height)
	quad.center_offset = Vector3(0.0, height * 0.5, 0.0)
	_body = ShaderMaterial.new()
	_body.shader = BODY
	_body.render_priority = FarFire.FLAME_PRIORITY - 1
	_body.set_shader_parameter("body", tex)
	_body.set_shader_parameter("rim_colour", Color(str(_cfg["rim_colour"])))
	_body.set_shader_parameter("rim_strength", Num.f(_cfg["rim_strength"]))
	_body.set_shader_parameter("rim_width", Num.f(_cfg["rim_width"]))
	_body.set_shader_parameter("smog", Num.f(_cfg["smog"]))
	_body.set_shader_parameter("smog_tail", Num.f(_cfg["smog_tail"]))
	_body.set_shader_parameter("noise_tex", TitleSkySmoke.noise_texture())
	quad.material = _body
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## The colossus's one faint red eye: a small glow where the head's eye is on the picture (tuning
## "eye" "uv", from tools/capture/bake_colossus.gd), drawn over the card and the smoke.
func _eye_sprite() -> MeshInstance3D:
	var eye: Dictionary = _cfg["eye"]
	var tex := _poses[0]
	var height := Num.f(_cfg["height"])
	var width := height * tex.get_width() / tex.get_height()
	var uv: Array = eye["uv"]
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_fog = true
	mat.no_depth_test = false
	mat.render_priority = FarFire.FLAME_PRIORITY
	mat.albedo_texture = FarFire.soft_disc()
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = mat
	node.scale = Vector3.ONE * Num.f(eye["size"])
	node.position = Vector3(
		(Num.f(uv[0]) - 0.5) * width, (1.0 - Num.f(uv[1])) * height, Num.f(eye["forward"])
	)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## One huge soft orange glow behind the body, so the dark shape pops (a billboard, additive).
func _glow_sprite() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_fog = true
	mat.albedo_texture = FarFire.soft_disc()
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = mat
	node.scale = Vector3.ONE * Num.f(_cfg["glow_size"])
	node.position = Vector3(0.0, Num.f(_cfg["burst_height"]), -Num.f(_cfg["burst_back"]))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _place() -> void:
	var start: Array = _cfg["start"]
	var stride: Array = _cfg["step"]
	var count := Num.i(_cfg["steps_out"])
	var along := posmod(_steps, count * 2)
	if along > count:
		along = count * 2 - along
	position = Vector3(
		Num.f(start[0]) + Num.f(stride[0]) * along,
		Num.f(_cfg["ground_y"]),
		Num.f(start[1]) + Num.f(stride[1]) * along
	)
	_body.set_shader_parameter("body", _poses[posmod(_steps, _poses.size())])
