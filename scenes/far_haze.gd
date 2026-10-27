class_name FarHaze
extends RefCounted
## The far skyline's haze, one set of numbers for every far material: CitySkyline's towers, far
## quay and lattice tower, and SkylineRampage's beast and smoke. Each is built with a gentler haze
## of its own and no engine fog (facade_far, concrete_stand_far, far_impostor, horizon_smoke) and
## has a _fogged twin that takes the engine's depth fog as well. Director comment #37 (2026-10-25,
## asked twice: "something funky going on with the distant city"): the far city floated crisp
## above the haze, clearer than the bay in front of it. Tuning city "far_fog" puts it in the same
## air as the bay by default (apply_default); a rampage's escalation sets it through
## CitySkyline.set_far_haze. Presentation only.

## Each far shader's twin that takes the engine's fog as well.
const TWINS := {
	"res://scenes/facade_far.gdshader": preload("res://scenes/facade_far_fogged.gdshader"),
	"res://scenes/concrete_stand_far.gdshader":
	preload("res://scenes/concrete_stand_far_fogged.gdshader"),
	"res://scenes/far_impostor.gdshader": preload("res://scenes/far_impostor_fogged.gdshader"),
	"res://scenes/horizon_smoke.gdshader": preload("res://scenes/horizon_smoke_fogged.gdshader"),
}
const OWN_CAP := 0.94  # far_haze.gdshaderinc: the own haze never takes more than this
const CAP := 0.97  # ...nor the own haze and the height fog together

## In force on every far material: the haze colour, the share of each one's built haze (1 = as
## built), the height fog at the foot (0..1), the metres from the camera where the haze begins,
## and whether the engine's fog is on them too.
var color := Color.BLACK
var amount := 1.0
var base := 0.0
var start := 0.0
var fogged := false
var built_color := Color.BLACK  # the haze colour the far skyline was built with
var _cfg: Dictionary  # tuning city far_fog
var _mats: Array[ShaderMaterial] = []
var _built: Array[Dictionary] = []  # per material: its built haze and its two shaders


func _init(cfg: Dictionary) -> void:
	_cfg = cfg
	start = Num.f(cfg["start"])


## Adds each of `mats` (built with its own haze and a shader TWINS knows) and gives it the haze now
## in force. The first one's haze colour is the built colour.
func track(mats: Array) -> void:
	for mat: ShaderMaterial in mats:
		if _mats.is_empty():
			built_color = mat.get_shader_parameter("haze_color")
			color = built_color
		_mats.append(mat)
		var haze := Num.f(mat.get_shader_parameter("haze"))
		_built.append(
			{"haze": haze, "plain": mat.shader, "fogged": TWINS[mat.shader.resource_path]}
		)
		_apply(_mats.size() - 1)


## Every far material takes `p_color` and its own built haze times `p_amount`; `p_base` adds
## height fog at the foot; the haze begins `p_start` metres from the camera (-1: as built).
func set_haze(p_color: Color, p_amount: float, p_base: float, p_start: float) -> void:
	color = p_color
	amount = p_amount
	base = p_base
	start = p_start if p_start >= 0.0 else Num.f(_cfg["start"])
	for i: int in _mats.size():
		_apply(i)


## Whether the far materials take the engine's fog as well as their own haze (off: as built).
func set_fogged(on: bool) -> void:
	fogged = on
	for i: int in _mats.size():
		_apply(i)


## The far city in the same air as the bay when tuning city far_fog is on: the engine's fog on
## it, its own haze at own_haze of its built strength, base height fog at its foot.
func apply_default() -> void:
	if _cfg["on"] != true:
		return
	fogged = true
	set_haze(color, Num.f(_cfg["own_haze"]), Num.f(_cfg["base"]), -1.0)


## The share of the light the own haze and height fog take at `metres` from the camera and
## `height` metres up, for a material built with `haze` per metre (far_haze.gdshaderinc's curve
## with the numbers in force; the engine's fog comes on top when fogged).
func share_at(metres: float, height: float, haze: float) -> float:
	var f := clampf(1.0 - exp(-maxf(metres - start, 0.0) * haze * amount), 0.0, OWN_CAP)
	var foot := base * exp(-maxf(height, 0.0) / Num.f(_cfg["base_height"]))
	return clampf(f + (1.0 - f) * foot * smoothstep(start * 0.5, start, metres), 0.0, CAP)


## The far materials in order of tracking (tests and captures read what is drawn).
func materials() -> Array[ShaderMaterial]:
	return _mats


func _apply(i: int) -> void:
	var mat := _mats[i]
	var want: Shader = _built[i]["fogged"] if fogged else _built[i]["plain"]
	if mat.shader != want:
		mat.shader = want
	mat.set_shader_parameter("haze_color", color)
	mat.set_shader_parameter("haze", Num.f(_built[i]["haze"]) * amount)
	mat.set_shader_parameter("haze_start", start)
	mat.set_shader_parameter("haze_base", base)
	mat.set_shader_parameter("haze_base_height", Num.f(_cfg["base_height"]))
