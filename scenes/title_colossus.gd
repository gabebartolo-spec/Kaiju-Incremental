class_name TitleColossus
extends Node3D
## The kaiju behind the title's burning city (director 2026-10-22: "occasional explosions should
## reveal the silhouette of the reptilian colossus obscured in the inferno"): the game's own adult
## reptilian model, standing deep in the far shore's smoke and hidden. A big explosion behind it
## lights it for a moment, dark against the fireball, then it is hidden again; each footfall (the
## thud and the water's shiver) walks it one step along its path, so every reveal finds it a little
## further on. Presentation only; numbers in tuning "title" "colossus".

var _cfg: Dictionary
var _model: KaijuModel
var _steps := 0
var _left := 0.0
var _glow: MeshInstance3D


func _init(cfg: Dictionary) -> void:
	_cfg = cfg


func _ready() -> void:
	var species := Content.species_def(str(_cfg["species"]))
	var colors: Dictionary = species["colors"]
	_model = KaijuModel.new(str(_cfg["species"]), colors, "adult")
	_model.scale = Vector3.ONE * Num.f(_cfg["scale"])
	add_child(_model)
	_glow = _glow_sprite()
	add_child(_glow)
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
	var seen := maxf(Num.f(_cfg["idle_alpha"]), amount)
	# The model builds and swaps its meshes as it loads, so find them afresh each time.
	for node: Node in _model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).transparency = 1.0 - seen
	var mat := _glow.material_override as StandardMaterial3D
	var glow := lerpf(Num.f(_cfg["glow_idle"]), Num.f(_cfg["glow_peak"]), amount)
	mat.albedo_color = Color(Color(str(_cfg["glow_color"])), glow)


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
