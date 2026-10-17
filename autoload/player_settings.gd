class_name PlayerSettings
extends RefCounted
## The player's settings: volume, fullscreen and UI scale, kept in their own file apart from
## the save. Static so the settings screen and tests reach them without the Settings autoload
## (which loads them at start and owns the input actions and F11).

const PATH := "user://settings.cfg"
## UI scale steps on top of the 1080p canvas (D-027: already 2x on a 4K TV). Every screen fits
## at the largest step; the evolution tree scrolls when it has to.
const UI_SCALES: Array[float] = [1.0, 1.15, 1.25]
## The controls list the settings screen shows: action, keyboard, pad.
const CONTROLS: Array[Array] = [
	["Move", "WASD / arrows", "Left stick"],
	["Signature attack", "Space", "A"],
	["Glide (insectoid, hold)", "Hold Space", "Hold A"],
	["Ultimate", "E", "Y"],
	["Pause", "Esc / P", "Start"],
	["Fullscreen", "F11", "-"],
	["Confirm", "Enter / Space", "A"],
	["Back", "Esc", "B"],
]

static var volume := 0.8
static var fullscreen := false
static var ui_scale := 1.0


static func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	apply()
	save()


static func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply()
	save()


## Steps the UI scale to the next of UI_SCALES (wrapping round).
static func next_ui_scale() -> void:
	var at := UI_SCALES.find(ui_scale)
	ui_scale = UI_SCALES[(at + 1) % UI_SCALES.size()]
	apply()
	save()


static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.root.content_scale_factor = ui_scale
	# Headless runs (tests, CI) have no window to resize.
	if DisplayServer.get_name() == "headless":
		return
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if full != fullscreen:
		DisplayServer.window_set_mode(
			(
				DisplayServer.WINDOW_MODE_FULLSCREEN
				if fullscreen
				else DisplayServer.WINDOW_MODE_WINDOWED
			)
		)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "ui_scale", ui_scale)
	cfg.save(PATH)


## Reads settings.cfg (missing keys keep their defaults; `start_full` is the default mode).
static func load_saved(start_full: bool) -> void:
	fullscreen = start_full
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	volume = clampf(Num.f(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen) == true
	var scale := Num.f(cfg.get_value("display", "ui_scale", ui_scale))
	ui_scale = scale if UI_SCALES.has(scale) else UI_SCALES[0]
