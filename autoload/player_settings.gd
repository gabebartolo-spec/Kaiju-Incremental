class_name PlayerSettings
extends RefCounted
## The player's settings: volume (overall and sound effects), fullscreen and UI scale, kept in
## their own file apart from the save. Static so the settings screen and tests reach them
## without the Settings autoload (which loads them at start and owns the input actions and F11).

const PATH := "user://settings.cfg"
## UI scale steps on top of the 1080p canvas (D-027: already 2x on a 4K TV). Every screen fits
## at the largest step; the evolution tree scrolls when it has to.
const UI_SCALES: Array[float] = [1.0, 1.15, 1.25]
## The controls list the settings screen shows: action, keyboard, pad, and for a species-only
## row that species's id (hidden while Demo.allows() says it is not playable).
const CONTROLS: Array[Array] = [
	["Move", "WASD / arrows", "Left stick"],
	["Signature attack", "Space", "A"],
	["Glide (insectoid, hold)", "Hold Space", "Hold A", "insectoid"],
	["Ultimate", "E", "Y"],
	["Pause", "Esc / P", "Start"],
	["Fullscreen", "F11", "Keyboard only"],
	["Confirm", "Enter / Space", "A"],
	["Back", "Esc", "B"],
]

## Mixer buses under Master: every game sound plays on SFX; Music waits for the music.
const BUSES: Array[String] = ["SFX", "Music"]

static var volume := 0.8
## The SFX bus volume (0..1); the default is tuning "sfx" default_volume.
static var sfx_volume := -1.0
static var fullscreen := false
static var ui_scale := 1.0


static func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	apply()
	save()


static func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
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
	for bus_name: String in BUSES:
		bus(bus_name)
	_set_bus(0, volume)
	_set_bus(bus("SFX"), sfx())
	_dynamics()
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


## The index of a bus in BUSES, made (sending to Master) the first time it is asked for.
static func bus(bus_name: String) -> int:
	var at := AudioServer.get_bus_index(bus_name)
	if at >= 0:
		return at
	AudioServer.add_bus()
	at = AudioServer.bus_count - 1
	AudioServer.set_bus_name(at, bus_name)
	AudioServer.set_bus_send(at, "Master")
	return at


## The sound-effects volume, its tuning default until the player sets one.
static func sfx() -> float:
	if sfx_volume < 0.0:
		return Num.f(Content.section("sfx")["default_volume"])
	return sfx_volume


## Keeps the loudest moments clean (tuning "sfx" "dynamics"): a gentle compressor on SFX
## evens out a stack of big sounds, and a hard limiter on Master holds the peak under the
## ceiling, so breath + collapses + tanks never clip. Added once, at the end of each chain.
static func _dynamics() -> void:
	var cfg: Dictionary = Content.section("sfx")["dynamics"]
	var sfx_bus := bus("SFX")
	if not _has_effect(sfx_bus, AudioEffectCompressor):
		var comp := AudioEffectCompressor.new()
		comp.threshold = Num.f(cfg["threshold_db"])
		comp.ratio = Num.f(cfg["ratio"])
		comp.attack_us = Num.f(cfg["attack_us"])
		comp.release_ms = Num.f(cfg["release_ms"])
		AudioServer.add_bus_effect(sfx_bus, comp)
	if not _has_effect(0, AudioEffectHardLimiter):
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = Num.f(cfg["ceiling_db"])
		limiter.release = Num.f(cfg["limiter_release"])
		AudioServer.add_bus_effect(0, limiter)


static func _has_effect(at: int, kind: Variant) -> bool:
	for i: int in AudioServer.get_bus_effect_count(at):
		if is_instance_of(AudioServer.get_bus_effect(at, i), kind):
			return true
	return false


static func _set_bus(at: int, value: float) -> void:
	AudioServer.set_bus_volume_db(at, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(at, value <= 0.0)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "sfx_volume", sfx())
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
	sfx_volume = clampf(Num.f(cfg.get_value("audio", "sfx_volume", sfx())), 0.0, 1.0)
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen) == true
	var scale := Num.f(cfg.get_value("display", "ui_scale", ui_scale))
	ui_scale = scale if UI_SCALES.has(scale) else UI_SCALES[0]
