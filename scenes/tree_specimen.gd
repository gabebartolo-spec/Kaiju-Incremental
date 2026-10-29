class_name TreeSpecimen
extends SubViewportContainer
## The kaiju himself at the empty centre of the tree's rings (D-395): his model at his current
## stage turning slowly on a transparent plate, specimen_px canvas units tall, scaled with the
## camera. Rebuilt when he evolves. Tuning "tree" "skin" "fx" specimen_spin / specimen_px.

var _viewport: SubViewport
var _kaiju: KaijuModel
var _species: Dictionary
var _stage := ""
var _spin := 0.0


func _init(species: Dictionary, spin: float) -> void:
	_species = species
	_spin = spin
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	add_child(_viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0, 0, 0, 0)
	env.environment.ambient_light_color = Color("7fb7a6")
	env.environment.ambient_light_energy = 0.7
	_viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_color = Color("c79bff")
	key.light_energy = 1.1
	key.rotation_degrees = Vector3(-40, 35, 0)
	_viewport.add_child(key)
	var camera := Camera3D.new()
	camera.fov = 32.0
	var aim := Vector3(0.0, KaijuModel.MODEL_HEIGHT * 0.5, 0.0)
	var eye := aim + Vector3(0.0, KaijuModel.MODEL_HEIGHT * 0.12, KaijuModel.MODEL_HEIGHT * 2.1)
	camera.look_at_from_position(eye, aim)
	_viewport.add_child(camera)


## Shows the kaiju at `stage` ("baby" / "adolescent" / "adult"); nothing changes if he is already.
func show_stage(stage: String) -> void:
	if stage == _stage:
		return
	_stage = stage
	if _kaiju != null:
		_kaiju.queue_free()
	var colors: Dictionary = _species["colors"]
	_kaiju = KaijuModel.new(str(_species["id"]), colors, stage)
	_kaiju.rotation.y = PI * 0.8
	_viewport.add_child(_kaiju)


func _process(delta: float) -> void:
	if _kaiju != null and is_visible_in_tree():
		_kaiju.rotation.y += _spin * delta
