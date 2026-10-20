class_name PlayerSettings
extends RefCounted
## The player's settings: volume (overall and sound effects), fullscreen, UI scale and the frame
## cap, kept in
## their own file apart from the save. Static so the settings screen and tests reach them
## without the Settings autoload (which loads them at start and owns the input actions and F11).

const PATH := "user://settings.cfg"
## settings.cfg's display section version. 2: fps_cap is the player's own choice (-1 = the
## default for this screen); an older file saved the resolved cap, so its fps_cap is ignored.
const DISPLAY_VERSION := 2
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
## Frames a second at most in play (0 = unlimited); -1 = tuning "display" fps_default.
static var fps_cap := -1
## True while a rampage is on screen (main.gd); menus and pause run at tuning menu_fps at most.
static var in_play := false
## Graphics quality, a key of tuning "display" graphics; "" = graphics_default for this screen.
static var graphics := ""


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


## Steps the frame cap to the next of tuning "display" fps_caps (wrapping round).
static func next_fps_cap() -> void:
	var caps := _caps()
	fps_cap = caps[(caps.find(cap()) + 1) % caps.size()]
	save()


## tuning "display" fps_caps as ints (JSON numbers load as floats, and 120.0 is not found as 120).
static func _caps() -> Array[int]:
	var out: Array[int] = []
	for value: Variant in Content.section("display")["fps_caps"]:
		out.append(Num.i(value))
	return out


## The player's frame cap in play (0 = unlimited); on a large (4K) screen the default is
## tuning "display" graphics_default large_fps.
static func cap() -> int:
	if fps_cap >= 0:
		return fps_cap
	var display := Content.section("display")
	if _large():
		return Num.i(display["graphics_default"]["large_fps"])
	return Num.i(display["fps_default"])


## The graphics quality in use: the player's, else the default for this screen size.
static func graphics_level() -> String:
	if _levels().has(graphics):
		return graphics
	var defaults: Dictionary = Content.section("display")["graphics_default"]
	return str(defaults["large"] if _large() else defaults["small"])


## Steps the graphics quality to the next level (wrapping round).
static func next_graphics() -> void:
	var levels := _levels()
	graphics = levels[(levels.find(graphics_level()) + 1) % levels.size()]
	save()


static func _levels() -> Array[String]:
	var out: Array[String] = []
	var table: Dictionary = Content.section("display")["graphics"]
	for key: Variant in table.keys():
		out.append(str(key))
	return out


## A screen at least graphics_default min_height tall (4K); never in headless runs.
static func _large() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var tall := Num.i(Content.section("display")["graphics_default"]["min_height"])
	return DisplayServer.screen_get_size().y >= tall


## The row of tuning "display" graphics in use.
static func graphics_row() -> Dictionary:
	var table: Dictionary = Content.section("display")["graphics"]
	return table[graphics_level()]


## Puts the graphics level on a viewport's 3D render, the shadows and the city's sun and
## environment (GraphicsPresets) (Settings does it each frame it changes).
static func apply_graphics(view: Viewport) -> void:
	GraphicsPresets.apply(graphics_row(), view)


## The frame cap right now: the player's in an unpaused rampage, never above tuning menu_fps in
## menus or pause, so an idle screen does not spin the graphics card (director's playtest).
static func frame_cap(paused: bool) -> int:
	var menu := Num.i(Content.section("display")["menu_fps"])
	if in_play and not paused:
		return cap()
	return menu if cap() == 0 else mini(cap(), menu)


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
	cfg.set_value("display", "version", DISPLAY_VERSION)
	cfg.set_value("display", "fps_cap", fps_cap)
	cfg.set_value("display", "graphics", graphics)
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
	var saved_cap := Num.i(cfg.get_value("display", "fps_cap", -1))
	var current := Num.i(cfg.get_value("display", "version", 1)) >= DISPLAY_VERSION
	fps_cap = saved_cap if current and _caps().has(saved_cap) else -1
	var saved := str(cfg.get_value("display", "graphics", graphics))
	# A level renamed since (tuning "display" graphics_renamed: balanced is now medium).
	var renamed: Dictionary = Content.section("display")["graphics_renamed"]
	saved = str(renamed.get(saved, saved))
	graphics = saved if _levels().has(saved) else ""
