class_name PlayerSettings
extends RefCounted
## The player's settings: volume (overall and sound effects), camera motion, fullscreen, UI scale,
## the frame cap, held moves, reduce flashing, rumble, gore and the key bindings (KeyBinds), kept in
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
	["Leap", "Shift", "B"],
	["Ultimate", "E", "Y"],
	["Pause", "Esc / P", "Start"],
	["Fullscreen", "F11", "-"],
	["Confirm", "Enter / Space", "A"],
	["Back", "Esc", "B"],
]

static var volume := 0.8
## The SFX bus volume (0..1); the default is tuning "sfx" default_volume.
static var sfx_volume := -1.0
## Camera motion (0..1): scales the shake, the footfall dip and the breath swing together (XAG
## 117); -1 = tuning "camera_shake" default_motion.
static var camera_motion := -1.0
static var fullscreen := false
static var ui_scale := 1.0
## Frames a second at most in play (0 = unlimited); -1 = tuning "display" fps_default.
static var fps_cap := -1
## True while a rampage is on screen (main.gd); menus and pause run at tuning menu_fps at most.
static var in_play := false
## Graphics quality, a key of tuning "display" graphics; "" = graphics_default for this screen.
static var graphics := ""
## True once the controls card has shown at the start of a rampage (b2-10: once, then the
## controls live in Settings).
static var controls_seen := false
## The time of day every rampage plays (D-145): TimeOfDay.RANDOM (the default) or a time's id.
static var time_of_day := TimeOfDay.RANDOM
## The weather every rampage plays (D-155): Weather.RANDOM (the default) or a weather's id.
static var weather := Weather.RANDOM
## Held moves (D-259 "Hold or toggle for held moves"): false = hold the button, true = one press
## holds the move on and the next lets it go (HeldButton).
static var hold_toggle := false
## Reduce flashing (D-259): lights, flares and screen flashes at tuning "accessibility"
## flash_scale, no colour fringe (flash_scale(), fringe_on()).
static var reduce_flashing := false
## Pad rumble (D-259 "Yes, scaled by size, with a toggle"; PadRumble), on by default.
static var rumble := true
## Gore (D-259 "On by default, with a toggle"): false = reduced gore, splatter and blood mist
## become dust (the VFX reads gore_on()).
static var gore := true


static func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	apply()
	save()


static func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	apply()
	save()


static func set_camera_motion(value: float) -> void:
	camera_motion = clampf(value, 0.0, 1.0)
	save()


## The camera-motion setting in use, its tuning default until the player sets one.
static func motion() -> float:
	if camera_motion < 0.0:
		return Num.f(Content.section("camera_shake")["default_motion"])
	return camera_motion


static func mark_controls_seen() -> void:
	controls_seen = true
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


## Steps the weather setting to the next of Weather.settings() (wrapping round).
static func next_weather() -> void:
	weather = Weather.next(weather)
	save()


## Steps the time-of-day setting to the next of TimeOfDay.settings() (wrapping round).
static func next_time_of_day() -> void:
	time_of_day = TimeOfDay.next(time_of_day)
	save()


static func toggle_hold() -> void:
	hold_toggle = not hold_toggle
	save()


static func toggle_flashing() -> void:
	reduce_flashing = not reduce_flashing
	save()


static func toggle_rumble() -> void:
	rumble = not rumble
	save()


static func toggle_gore() -> void:
	gore = not gore
	save()


## How bright a flash of light is drawn (lights, flares, screen flashes): 1, or tuning
## "accessibility" flash_scale while Reduce flashing is on.
static func flash_scale() -> float:
	if not reduce_flashing:
		return 1.0
	return Num.f(Content.section("accessibility")["flash_scale"])


## True while the colour fringe may show (off under Reduce flashing).
static func fringe_on() -> bool:
	return not reduce_flashing


## True while full gore shows (splatter and blood mist); false: dust instead.
static func gore_on() -> bool:
	return gore


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
	AudioBuses.apply()
	_set_bus(0, volume)
	_set_bus(bus("SFX"), sfx())
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


## The index of a bus, made (sending to Master) the first time it is asked for; AudioBuses
## then sets its real send.
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


static func _set_bus(at: int, value: float) -> void:
	AudioServer.set_bus_volume_db(at, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(at, value <= 0.0)


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "sfx_volume", sfx())
	cfg.set_value("display", "camera_motion", motion())
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "ui_scale", ui_scale)
	cfg.set_value("display", "version", DISPLAY_VERSION)
	cfg.set_value("display", "fps_cap", fps_cap)
	cfg.set_value("display", "graphics", graphics)
	cfg.set_value("ui", "controls_seen", controls_seen)
	cfg.set_value("display", "time_of_day", TimeOfDay.clean(time_of_day))
	cfg.set_value("display", "weather", Weather.clean(weather))
	cfg.set_value("access", "hold_toggle", hold_toggle)
	cfg.set_value("access", "reduce_flashing", reduce_flashing)
	cfg.set_value("access", "rumble", rumble)
	cfg.set_value("access", "gore", gore)
	KeyBinds.write(cfg)
	cfg.save(PATH)


## Reads settings.cfg (missing keys keep their defaults; `start_full` is the default mode).
static func load_saved(start_full: bool) -> void:
	fullscreen = start_full
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	volume = clampf(Num.f(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)
	sfx_volume = clampf(Num.f(cfg.get_value("audio", "sfx_volume", sfx())), 0.0, 1.0)
	camera_motion = clampf(Num.f(cfg.get_value("display", "camera_motion", motion())), 0.0, 1.0)
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen) == true
	controls_seen = cfg.get_value("ui", "controls_seen", false) == true
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
	# An older file has no time of day: Random. An unknown time (since renamed) counts as Random.
	time_of_day = TimeOfDay.clean(str(cfg.get_value("display", "time_of_day", TimeOfDay.RANDOM)))
	weather = Weather.clean(str(cfg.get_value("display", "weather", Weather.RANDOM)))
	hold_toggle = cfg.get_value("access", "hold_toggle", false) == true
	reduce_flashing = cfg.get_value("access", "reduce_flashing", false) == true
	rumble = cfg.get_value("access", "rumble", true) != false
	gore = cfg.get_value("access", "gore", true) != false
	KeyBinds.read(cfg)
