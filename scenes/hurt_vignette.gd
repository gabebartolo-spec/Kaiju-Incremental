class_name HurtVignette
extends ColorRect
## Health without a bar (b2-13, R 15.3): a red edge vignette that widens as the kaiju's health
## falls, beats like a heart below tuning "ui" hurt heartbeat_below, and flashes on each hit.
## Shape (how far it reaches), colour and motion all carry it, never colour alone. Reads the
## sim; presentation only. Numbers in tuning "ui" hurt.

const SHADER := preload("res://scenes/hurt_vignette.gdshader")
## The beat's shape: higher is a sharper thump between quiet stretches.
const THUMP_SHARPNESS := 4.0
## A hit reaches at least this share of width_max, even at full health.
const FLASH_REACH := 0.5

var sim: RampageSim
## How far the red reaches now (0..1 of the way to the centre) and its edge strength.
var width := 0.0
var strength := 0.0
var _cfg: Dictionary
var _shown := 0.0
var _beat := 0.0
var _flash := 0.0
var _last_hp := -1.0


func _init(p_sim: RampageSim) -> void:
	sim = p_sim
	_cfg = UiKit.ui()["hurt"]
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("tint", Color(str(_cfg["color"])))
	material = mat


func _ready() -> void:
	UiKit.full_rect(self)


## The share of health lost (0 full, 1 dead).
func hurt() -> float:
	if sim.max_hp <= 0.0:
		return 0.0
	return clampf(1.0 - sim.hp / sim.max_hp, 0.0, 1.0)


## True while the heart beats (health below heartbeat_below).
func beating() -> bool:
	return sim.max_hp > 0.0 and sim.hp / sim.max_hp < Num.f(_cfg["heartbeat_below"])


func _process(delta: float) -> void:
	step(delta)


## One frame of the vignette (the capture tool and the flow suite call it with a fixed dt).
func step(dt: float) -> void:
	if _last_hp >= 0.0 and sim.hp < _last_hp:
		_flash = Num.f(_cfg["flash_s"])
	_last_hp = sim.hp
	_flash = maxf(0.0, _flash - dt)
	_shown = lerpf(_shown, hurt(), 1.0 - exp(-Num.f(_cfg["ease_rate"]) * dt))
	var pulse := 1.0
	if beating():
		_beat += dt * Num.f(_cfg["heartbeat_hz"])
		var thump := pow(maxf(0.0, sin(TAU * _beat)), THUMP_SHARPNESS)
		pulse = 1.0 - Num.f(_cfg["heartbeat_depth"]) * (1.0 - thump)
	var flash := Num.f(_cfg["flash_alpha"]) * _flash / maxf(0.001, Num.f(_cfg["flash_s"]))
	width = Num.f(_cfg["width_max"]) * _shown
	strength = clampf(Num.f(_cfg["alpha_max"]) * sqrt(_shown) * pulse + flash, 0.0, 1.0)
	if flash > 0.0:
		width = maxf(width, Num.f(_cfg["width_max"]) * FLASH_REACH)
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("width", width)
	mat.set_shader_parameter("alpha", strength)
