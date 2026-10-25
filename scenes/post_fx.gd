class_name PostFx
extends CanvasLayer
## The two post effects of a rampage (D-142, tuning "post_fx"), on every graphics preset: a subtle
## vignette (dark screen edges, red and pulsing at low health) and a split-second colour fringe on
## the top-tier impacts. Two full-screen rects over the 3D view and under the HUD, so the HUD stays
## clean. The vignette is alpha only; the fringe reads the screen, so its rect is shown only while
## a burst runs. PostFxState holds the numbers; this node only draws them.

const VIGNETTE := preload("res://scenes/vignette.gdshader")
const FRINGE := preload("res://scenes/fringe.gdshader")
## Below the HUD (its layer is 1), above the 3D view.
const UNDER_HUD := 0

## Off draws nothing and costs nothing (the benchmark's baseline; no setting turns it off).
static var enabled := true

var state := PostFxState.new()
var _rampage: Rampage
var _rings := 0
var _vignette: ColorRect
var _fringe: ColorRect
var _vignette_mat := ShaderMaterial.new()
var _fringe_mat := ShaderMaterial.new()


func _init(p_rampage: Rampage = null) -> void:
	_rampage = p_rampage
	layer = UNDER_HUD
	var cfg: Dictionary = Content.section("post_fx")["vignette"]
	_vignette_mat.shader = VIGNETTE
	_vignette_mat.set_shader_parameter("inner", Num.f(cfg["inner"]))
	_vignette_mat.set_shader_parameter("outer", Num.f(cfg["outer"]))
	var low: Dictionary = Content.section("post_fx")["low_health"]
	_vignette_mat.set_shader_parameter("red_depth", Num.f(low["depth_px"]))
	_fringe_mat.shader = FRINGE
	_vignette = _rect(_vignette_mat)
	_fringe = _rect(_fringe_mat)
	_fringe.visible = false
	update(0.0, 1.0, 1.0)


func _rect(mat: ShaderMaterial) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = mat
	add_child(rect)
	return rect


## Reads the sim as the rampage steps it (this node is its child, so it runs right after the
## step): the collapses that landed this step.
func _physics_process(_delta: float) -> void:
	if _rampage == null or _rampage.sim == null or _rampage.sim.over:
		return  # (an ended run leaves its last step's events in place)
	for event: Dictionary in _rampage.sim.events:
		match str(event["type"]):
			"fall_land":
				state.fall(event)
			"railgun_hit":
				state.railgun()


func _process(delta: float) -> void:
	if _rampage == null or _rampage.sim == null:
		return
	var rings := _rampage.stomp_ring_at.size()  # a stomp's foot came down since the last frame
	if rings > _rings:
		state.stomp(_rampage.sim.stomp_radius())
	_rings = rings
	var sim := _rampage.sim
	update(delta, sim.hp / maxf(sim.max_hp, 0.001), PlayerSettings.motion())


## One frame: `hp_share` is the kaiju's health over its max (0..1), `motion` the camera-motion
## setting (0..1).
func update(delta: float, hp_share: float, motion: float) -> void:
	if not enabled:
		_vignette.visible = false
		_fringe.visible = false
		return
	state.update(delta, hp_share, motion)
	_vignette.visible = true
	_vignette_mat.set_shader_parameter("tint", state.vignette_color)
	_vignette_mat.set_shader_parameter("strength", state.vignette_alpha)
	_vignette_mat.set_shader_parameter("red_tint", state.red_color)
	_vignette_mat.set_shader_parameter("red_alpha", state.red_alpha)
	_fringe.visible = state.fringe_px > 0.0 and PlayerSettings.fringe_on()  # Reduce flashing
	if _fringe.visible:
		_fringe_mat.set_shader_parameter("amount_px", state.fringe_px)


## The rects, for the tests: [vignette, fringe].
func rects() -> Array[ColorRect]:
	return [_vignette, _fringe]
