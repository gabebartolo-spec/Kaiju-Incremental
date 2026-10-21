class_name PooledLight
extends OmniLight3D
## One street lamp, fire or police beacon light. LightPool decides which of these are real: only
## the nearest to the camera are lit, and each fades in or out over city/lights.fade_seconds so
## the hand-over never pops. A light that is out is its owner's emissive voxels and glow, nothing
## more. It also fades with camera distance (distance_fade_*, from data). Presentation only.
##
## Owners set the energy they want with set_energy (never light_energy: the pool scales it).

const GROUP := "pooled_lights"

## What the owner wants; the light shows this times `weight`.
var energy := 0.0
## 0 (out) to 1 (fully lit); LightPool moves `wanted`, this follows it.
var weight := 0.0
var wanted := false
var _seconds: float


## kind: "lamp", "fire" or "beacon" (data/tuning.json "lights").
func _init(kind: String) -> void:
	var cfg := Content.section("lights")
	var fade: Dictionary = cfg[kind]
	_seconds = Num.f(cfg["fade_seconds"])
	distance_fade_enabled = true
	distance_fade_begin = Num.f(fade["fade_begin"])
	distance_fade_length = Num.f(fade["fade_length"])
	shadow_enabled = false  # small lights never cast shadows (R 12.1)
	visible = false
	light_energy = 0.0
	set_process(false)


func _ready() -> void:
	add_to_group(GROUP)
	if get_tree().get_first_node_in_group(LightPool.GROUP) == null:
		# No pool (a stage without a CityView): an ordinary light.
		wanted = true
		weight = 1.0
		visible = true
		light_energy = energy


func set_energy(value: float) -> void:
	energy = value
	light_energy = energy * weight


## Whether the light is drawn at all (lit, or still fading out): what counts against the pool.
func is_live() -> bool:
	return wanted or weight > 0.0


func set_wanted(value: bool) -> void:
	if value == wanted:
		return
	wanted = value
	if wanted:
		visible = true
	set_process(true)


func _process(delta: float) -> void:
	var step := delta / maxf(_seconds, 0.001)
	weight = move_toward(weight, 1.0 if wanted else 0.0, step)
	light_energy = energy * weight
	if weight <= 0.0:
		visible = false
	if weight == (1.0 if wanted else 0.0):
		set_process(false)
