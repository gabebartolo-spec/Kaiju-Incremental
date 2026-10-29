class_name GraphicsPreview
extends PanelContainer
## The graphics preview beside Settings (comment #90, director 2026-10-22: "a live example of what
## that will look like so players can choose their tolerance"): a small burning street corner (the
## game's own Fire with its smoke, and the game's own blast going off every BLAST_EVERY seconds)
## redrawn live at the graphics level in use, with the frame rate under it. Each level change puts
## the new row on its view (GraphicsPresets.apply) and on its particles (the row's "particles"),
## so the picture changes as the player steps GRAPHICS. While it is open the menu frame cap is
## lifted to the player's own (PlayerSettings.previewing), so the frame rate shown is the real one.
## Presentation only: its world is its own, nothing reaches the sim.

## The view's size at 1080p (px), 16:9.
const VIEW := Vector2i(420, 236)
const BLAST_EVERY := 3.0
const BLAST_AT := Vector3(-3.0, 0.6, -2.0)
const FIRE_AT := Vector3(1.6, 0.0, 0.4)
const CAMERA_AT := Vector3(7.5, 4.5, 9.0)
const LOOK_AT := Vector3(-0.5, 1.6, -1.0)
## The corner's buildings: [centre on the ground, size] (m), concrete grey.
const BLOCKS: Array[Array] = [
	[Vector3(-4.0, 0.0, -5.0), Vector3(5.0, 9.0, 4.0)],
	[Vector3(3.0, 0.0, -5.5), Vector3(4.0, 6.0, 3.0)],
	[Vector3(-6.5, 0.0, 1.5), Vector3(3.0, 5.0, 5.0)],
]
const ROAD := Color("2b2b2e")
const WALL := Color("6d6a64")

var _port: SubViewport
var _world: Node3D
var _fps: Label
var _level := ""
var _clock := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UiKit.panel().get_theme_stylebox("panel"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	var title := UiKit.label("PREVIEW", UiKit.SIZE_BODY, UiKit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.custom_minimum_size = Vector2(VIEW)
	col.add_child(frame)
	_port = SubViewport.new()
	_port.own_world_3d = true
	_port.size = VIEW
	_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	frame.add_child(_port)
	_world = Node3D.new()
	_port.add_child(_world)
	_build_corner()
	_fps = UiKit.label("", UiKit.SIZE_SMALL)
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_fps)
	PlayerSettings.previewing = true
	_apply()


func _exit_tree() -> void:
	PlayerSettings.previewing = false


func _process(delta: float) -> void:
	if PlayerSettings.graphics_level() != _level:
		_apply()
	_clock += delta
	if _clock >= BLAST_EVERY:
		_clock = 0.0
		_blast()
	_fps.text = "%s · %d FPS" % [_level.to_upper(), roundi(Engine.get_frames_per_second())]


## Puts the level in use on the view, its sun and environment, and every particle in it.
func _apply() -> void:
	_level = PlayerSettings.graphics_level()
	var row := PlayerSettings.graphics_row()
	GraphicsPresets.apply(row, _port)
	for node: Node in _world.find_children("*", "", true, false):
		GraphicsPresets.apply_to(row, node)
	_set_particles(_world)


func _set_particles(under: Node) -> void:
	var ratio := Num.f(PlayerSettings.graphics_row()["particles"])
	for node: Node in under.find_children("*", "GPUParticles3D", true, false):
		(node as GPUParticles3D).amount_ratio = ratio


## The street, three blocks, the sun and sky, the camera and the burning ruin.
func _build_corner() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("1a1c24")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("5a6070")
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.glow_enabled = true
	_world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
	_world.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 55.0
	_world.add_child(camera)
	camera.look_at_from_position(CAMERA_AT, LOOK_AT)
	_world.add_child(_box(Vector3(0, -0.05, 0), Vector3(40, 0.1, 40), ROAD))
	for block: Array in BLOCKS:
		var size: Vector3 = block[1]
		var at: Vector3 = block[0]
		_world.add_child(_box(at + Vector3(0, size.y * 0.5, 0), size, WALL))
	var fire := Fire.new(1.2, 0.0)
	fire.position = FIRE_AT
	_world.add_child(fire)


func _box(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	return node


## The game's own blast (BlastFx's core and fireball) on the corner's far side.
func _blast() -> void:
	var cfg := Content.section("blast_fx")
	var core: Dictionary = cfg["core"]
	var fireball: Dictionary = cfg["fireball"]
	var half := Vector3(1.2, 0.6, 1.2)
	BlastParts.core(_world, BLAST_AT, half, 4.0, core)
	BlastParts.fireball(_world, BLAST_AT, half, 4.0, fireball)
	_set_particles(_world)
