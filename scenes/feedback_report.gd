class_name FeedbackReport
extends RefCounted
## The pause menu's bug / feedback report (D-145): what to write and where. A report is a folder
## user://<folder>/<timestamp>/ (tuning "feedback") holding report.txt (the game version, what the
## player typed and the facts a bug needs) and screenshot.png (the rampage as it stood). It is a
## file on the player's disk and nothing else: no network call of any kind.

const TEXT_FILE := "report.txt"
const SHOT_FILE := "screenshot.png"
const VERSION_KEY := "application/config/version"
const SHOT_PLACEHOLDER := Vector2i(64, 36)


## The game's version line, from project.godot: "Kaiju Evolution 0.1.0-demo".
static func version() -> String:
	var game := str(Content.section("feedback")["game"])
	return "%s %s" % [game, str(ProjectSettings.get_setting(VERSION_KEY, "unversioned"))]


## The facts report.txt carries, in order, as label -> value. `view` is the viewport the player
## sees (its size and the window's are the resolution).
static func facts(sim: RampageSim, species_id: String, view: Viewport) -> Dictionary:
	var tier := sim.size_tier()
	var level := PlayerSettings.graphics_level()
	var render_scale := Num.f(Content.section("display")["graphics"][level]["scale"])
	var window := DisplayServer.window_get_size()
	var out := {}
	out["Species"] = species_id
	out["City"] = "stage %d, map seed %d" % [tier, _map_seed(sim)]
	out["Growth step"] = "%s (size tier %d)" % [KaijuModel.stage_for(tier), tier]
	out["Run time"] = _run_time(sim)
	out["OS"] = "%s %s" % [OS.get_name(), OS.get_version()]
	out["GPU"] = RenderingServer.get_video_adapter_name()
	out["Graphics preset"] = "%s (render scale %s)" % [level, render_scale]
	var canvas := view.get_visible_rect().size
	out["Resolution"] = "window %dx%d, canvas %dx%d" % [window.x, window.y, canvas.x, canvas.y]
	return out


## report.txt: the version first, then the facts, then what the player typed.
static func compose(typed: String, details: Dictionary, stamp: String) -> String:
	var lines: Array[String] = ["Version: " + version(), "Reported: " + stamp]
	for key: Variant in details:
		lines.append("%s: %s" % [str(key), str(details[key])])
	lines.append("Screenshot: " + SHOT_FILE)
	lines.append("")
	lines.append("--- What the player wrote ---")
	lines.append(typed.strip_edges() if not typed.strip_edges().is_empty() else "(nothing)")
	return "\n".join(lines) + "\n"


## Writes the report folder; returns {"ok", "path" (absolute), "error"}. `shot` null or empty
## (a headless run has no picture) saves a small black placeholder and says so in the text.
static func write(typed: String, details: Dictionary, shot: Image, stamp: String) -> Dictionary:
	var root := "user://" + str(Content.section("feedback")["folder"])
	var folder := _free_folder(root, stamp.replace(":", "-").replace("T", "_"))
	var made := DirAccess.make_dir_recursive_absolute(folder)
	if made != OK:
		return {"ok": false, "path": "", "error": error_string(made)}
	var image := shot
	var note := details.duplicate()
	if image == null or image.is_empty():
		image = Image.create(SHOT_PLACEHOLDER.x, SHOT_PLACEHOLDER.y, false, Image.FORMAT_RGB8)
		note["Screenshot note"] = "no renderer, so screenshot.png is a black placeholder"
	var saved := image.save_png(folder.path_join(SHOT_FILE))
	if saved != OK:
		return {"ok": false, "path": "", "error": error_string(saved)}
	var file := FileAccess.open(folder.path_join(TEXT_FILE), FileAccess.WRITE)
	if file == null:
		return {"ok": false, "path": "", "error": error_string(FileAccess.get_open_error())}
	file.store_string(compose(typed, note, stamp))
	file.close()
	return {"ok": true, "path": ProjectSettings.globalize_path(folder), "error": ""}


## The rampage as the viewport shows it now (null when there is nothing to read back).
static func grab(view: Viewport) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	var texture := view.get_texture()
	return texture.get_image() if texture != null else null


## The current local date and time as 2026-10-23T14:05:33.
static func stamp_now() -> String:
	return Time.get_datetime_string_from_system()


static func _free_folder(root: String, name: String) -> String:
	var folder := root.path_join(name)
	var n := 2
	while DirAccess.dir_exists_absolute(folder):
		folder = root.path_join("%s_%d" % [name, n])
		n += 1
	return folder


static func _run_time(sim: RampageSim) -> String:
	var seconds := maxf(0.0, sim.stat("run_seconds") - sim.time_left)
	var whole := int(seconds)
	return "%d:%02d (%d s left)" % [floori(whole / 60.0), whole % 60, int(sim.time_left)]


static func _map_seed(sim: RampageSim) -> int:
	return Num.i(sim.city["map_seed"])
