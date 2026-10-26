extends RefCounted
## Render plan item 13 (soft smoke) for tests/run_soft_smoke_tests.gd. The pieces:
##  - scenes/smoke.gdshader (smoke, fire columns, street dust, blast clouds all use it) samples the
##    depth texture, rebuilds the view depth with INV_PROJECTION_MATRIX and fades alpha over the
##    gap with the global uniform `smoke_soft_m`, and keeps the camera rule (view_clear) intact;
##  - project.godot declares that global (0 = no fade, so a scene that never sets it is as before);
##  - data/tuning.json render_opt holds the flag (ON by default) and the width in metres;
##  - SmokeSoft (scenes/smoke_soft.gd) turns the data into the uniform: 0 with the flag off;
##  - CityView applies it when a city is built.

const SHADER := "res://scenes/smoke.gdshader"
const CLASS_FILE := "res://scenes/smoke_soft.gd"
const CITY_VIEW := "res://scenes/city_view.gd"
const GLOBAL := "smoke_soft_m"

var _check: Callable


func _init(check: Callable) -> void:
	_check = check


func run() -> void:
	_shader()
	_project()
	_data()
	_class()
	_wired()


## A file's code with its // comments cut, so a comment cannot satisfy a check.
func _code(path: String) -> String:
	var out := PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var cut := line.find("//")
		if cut < 0:
			cut = line.find("#")
		out.append(line if cut < 0 else line.substr(0, cut))
	return "\n".join(out)


func _shader() -> void:
	var src := _code(SHADER)
	_check.call(src.length() > 100, "smoke.gdshader is readable")
	_check.call(
		src.contains("hint_depth_texture"), "smoke.gdshader samples the scene depth texture"
	)
	_check.call(
		src.contains("INV_PROJECTION_MATRIX"),
		"smoke.gdshader rebuilds view depth with INV_PROJECTION_MATRIX"
	)
	_check.call(
		src.contains("global uniform float " + GLOBAL),
		"smoke.gdshader takes its fade width from the global uniform " + GLOBAL
	)
	var fade := RegEx.create_from_string("smoothstep\\(\\s*0\\.0\\s*,\\s*" + GLOBAL)
	_check.call(
		fade.search(src) != null,
		"the fade is smoothstep(0.0, %s, gap): no width written in code" % GLOBAL
	)
	_check.call(
		src.contains("view_clear("), "the camera rule (view_clear, D-025) still shapes the alpha"
	)


func _project() -> void:
	var key := "shader_globals/" + GLOBAL
	_check.call(ProjectSettings.has_setting(key), "project.godot declares the global " + GLOBAL)
	if not ProjectSettings.has_setting(key):
		return
	var decl: Dictionary = ProjectSettings.get_setting(key)
	_check.call(decl.get("type", "") == "float", GLOBAL + " is a float")
	_check.call(Num.f(decl.get("value", 1.0)) == 0.0, GLOBAL + " starts at 0 (no fade until set)")


func _data() -> void:
	var opt := Content.section("render_opt")
	_check.call(opt.get("soft_smoke", false) == true, "render_opt.soft_smoke is ON by default")
	var width := Num.f(opt.get("soft_smoke_m", 0.0))
	_check.call(width > 0.0, "render_opt.soft_smoke_m is a positive width in metres (%.2f)" % width)
	_check.call(width <= 5.0, "the fade width stays a soft edge, not a haze (%.2f m)" % width)


func _class() -> void:
	var script: GDScript = null
	if ResourceLoader.exists(CLASS_FILE):
		script = load(CLASS_FILE)
	_check.call(script != null, "scenes/smoke_soft.gd exists and compiles")
	if script == null:
		return
	var on := {"soft_smoke": true, "soft_smoke_m": 2.5}
	var off := {"soft_smoke": false, "soft_smoke_m": 2.5}
	_check.call(script.call("soft_m_from", on) == 2.5, "flag on: the uniform is the data width")
	_check.call(script.call("soft_m_from", off) == 0.0, "flag off: the uniform is 0, no fade")
	_check.call(script.call("soft_m_from", {}) == 0.0, "no data: no fade")
	var shipped := Num.f(Content.section("render_opt").get("soft_smoke_m", -1.0))
	_check.call(
		is_equal_approx(Num.f(script.call("soft_m")), shipped),
		"the shipped data feeds the uniform (%.2f m)" % shipped
	)
	script.call("apply")
	_check.call(
		is_equal_approx(Num.f(script.get("applied")), shipped),
		"apply() hands the data width to the global (%.2f m)" % Num.f(script.get("applied"))
	)


func _wired() -> void:
	_check.call(
		_code(CITY_VIEW).contains("SmokeSoft.apply()"),
		"CityView applies the soft smoke width when it builds"
	)
