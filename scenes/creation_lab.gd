class_name CreationLab
extends Node3D
## The set Kaiju Creation plays on (D-207, the board approved 2026-10-25): a secret bio-weapon lab
## built from Tripo props in the game's blocks (CreationSet), the dish's genome and its lightning
## takeover (CreationGenome), the injector (CreationInjector) and the camera. The director
## (2026-10-25): picking a genome sends the injector to that genome's vial, it drains it and puts
## the gene into the dish; injecting Special K sends it to the canister and back, and the needle
## striking the agar starts the takeover; no vial flies. Every beat is a pure function of its
## progress (0..1), so a frame is the same on any machine. `flash` is the white the screen should
## show this tick (KaijuCreation draws it).

var camera: Camera3D
## The white over the screen this tick (0..1).
var flash := 0.0
var genome: CreationGenome
var injector: CreationInjector
## Each unlocked titan's vial liquid (titan index -> CreationLiquid), and the Special K.
var vials: Dictionary[int, CreationLiquid] = {}
var special_k: CreationLiquid
var _titans: Array[Dictionary] = []
var _rack: Node3D
var _canister_at := Vector3.ZERO
var _focus: OmniLight3D
var _screens: OmniLight3D
var _flash_age := -1
var _struck := false
var _overloaded := false
var _poured := false
var _tick := 0


func setup(titans: Array[Dictionary]) -> void:
	_titans = titans


func _ready() -> void:
	CreationSet.environment(self)
	CreationSet.lights(self)
	CreationSet.slab(self, "bench", false)
	CreationSet.slab(self, "wall", true)
	_add_props()
	genome = CreationGenome.new()
	add_child(genome)
	_add_glows()
	camera = Camera3D.new()
	add_child(camera)
	zoom(0.0)


func _add_props() -> void:
	var cradle := CreationSet.read("cradle")
	CreationSet.clean_dish(cradle)
	var agar := CreationSet.agar_node(cradle)
	CreationSet.place(self, "cradle", cradle).add_child(agar)
	var monitors := CreationSet.read("monitors")
	CreationSet.paint(monitors, CreationSet.screen_color)
	CreationSet.place(self, "monitors", monitors)
	_add_rack()
	_add_injector()
	_add_canister()


## The rack, each unlocked genome's liquid drawn on its own so it can drain, and a port cut over
## each for the needle.
func _add_rack() -> void:
	var rack := CreationSet.read("rack")
	CreationSet.paint(
		rack, func(c: Vector3i, col: Color) -> Color: return CreationSet.vial_color(c, col, _titans)
	)
	var liquids: Dictionary[int, Dictionary] = {}
	for i: int in _titans.size():
		if _titans[i]["locked"] != true:
			liquids[i] = CreationSet.take_liquid(rack, CreationSet.vial_of(i))
	_rack = CreationSet.place(self, "rack", rack)
	for i: int in liquids:
		var dna: Color = _titans[i]["genome"]
		var vial := CreationLiquid.new(liquids[i], Color(dna, 0.0), 1.0)
		_rack.add_child(vial.node)
		vials[i] = vial


## Where the needle goes down into titan `index`'s vial (the lab's space, at the bench).
func vial_point(index: int) -> Vector3:
	var voxel := Num.f(CreationSet.cfg()["voxel"])
	var c := CreationSet.vial_centre(CreationSet.vial_of(index))
	return _rack.transform * Vector3(c.x * voxel, 0.0, c.y * voxel)


## The injector's post stands behind the dish and the croc's vial, where the needle reaches both.
func _add_injector() -> void:
	injector = CreationInjector.new()
	var reach := CreationInjector.reach()
	var v := vial_point(0)
	var to := Vector2(v.x, v.z)
	var half := to.length() * 0.5
	var side := to.normalized().orthogonal() * sqrt(maxf(reach * reach - half * half, 0.0))
	var post := to * 0.5 + (side if side.y < 0.0 else -side)
	injector.position = Vector3(post.x, 0.0, post.y)
	add_child(injector)


## The Special K canister, a needle's reach from the post, turned round it from the dish.
func _add_canister() -> void:
	var cfg: Dictionary = CreationSet.cfg()["injector"]
	var post := injector.position
	var turn := deg_to_rad(Num.f(cfg["canister_turn"]))
	_canister_at = post + (-post).rotated(Vector3.UP, turn)
	var canister := CreationSet.read("canister")
	var empties := CreationSet.take_canister_liquid(canister)
	var node := CreationSet.place(self, "canister", canister)
	node.position = _canister_at
	special_k = CreationLiquid.new(empties, Color(CreationSet.color("special_k"), 0.0), 1.0)
	node.add_child(special_k.node)


## The focused vial's glow and the screens' green spill (pulsing like a heartbeat in the strike).
func _add_glows() -> void:
	_focus = OmniLight3D.new()
	_focus.light_color = CreationSet.color("screen")
	_focus.omni_range = 0.45
	add_child(_focus)
	_screens = OmniLight3D.new()
	_screens.light_color = CreationSet.color("screen")
	_screens.light_energy = CreationSet.energy("screens")
	_screens.omni_range = 1.2
	var props: Dictionary = CreationSet.cfg()["props"]
	var monitors: Dictionary = props["monitors"]
	_screens.position = CreationSet.vec(monitors["at"]) + Vector3(-0.1, 0.4, 0.35)
	add_child(_screens)
	focus(0)


## Lights the vial of titan `index` (-1: none); a locked titan's vial stays dark.
func focus(index: int) -> void:
	var lit: bool = index >= 0 and index < _titans.size() and _titans[index]["locked"] != true
	_focus.light_energy = CreationSet.energy("focus") if lit else 0.0
	_focus.position = vial_point(maxi(index, 0)) + Vector3(0.0, 0.3, 0.2)


## The swing heights and needle depths of a trip to a source as tall as `top`.
func _heights(source_tip: float, top: float) -> Vector3:
	var cfg: Dictionary = CreationSet.cfg()["injector"]
	var tallest := maxf(maxf(top, Num.f(cfg["cradle_top"])), Num.f(cfg["park_tip"]))
	var clear := tallest + Num.f(cfg["clear"])
	return Vector3(source_tip, clear, Num.f(cfg["dish_tip"]))


## The gene goes in (t 0..1): the injector drains titan `index`'s vial into its barrel, swings
## back and puts the gene into the agar, which settles from the needle out.
func place(index: int, t: float) -> void:
	if not _poured:
		_poured = true
		var colors: Dictionary = Content.species_def(str(_titans[index]["species"]))["colors"]
		var dna: Color = _titans[index]["genome"]
		genome.set_titan(dna, Color(str(colors["body"])))
		injector.barrel.set_color(Color(dna, 0.0))
	var cfg: Dictionary = CreationSet.cfg()["injector"]
	var heights := _heights(Num.f(cfg["vial_tip"]), Num.f(cfg["vial_top"]))
	var r := injector.trip(t, "place", vial_point(index), heights)
	if vials.has(index):
		vials[index].set_level(1.0 - r.x)
	injector.barrel.set_level(r.x - r.y)
	genome.settle(r.y)


## The injection (t 0..1): the injector draws Special K from the canister and lowers the needle
## into the agar (the strike at its end); the screens' glow starts to beat.
func inject(t: float) -> void:
	_tick += 1
	if t <= 0.0 or is_zero_approx(injector.barrel.level()):
		injector.barrel.set_color(Color(CreationSet.color("special_k"), 0.0))
	var cfg: Dictionary = CreationSet.cfg()["injector"]
	var heights := _heights(Num.f(cfg["canister_tip"]), Num.f(cfg["canister_top"]))
	var r := injector.trip(t, "inject", _canister_at, heights)
	special_k.set_level(1.0 - Num.f(cfg["canister_draw"]) * r.x)
	injector.barrel.set_level(r.x - r.y)
	_beat(0.5)


## The takeover (t 0..1): a hit-stop at the strike, the lightning, a second hit-stop at the
## overload, then the dish burns white. Each hit-stop flashes white (one tick at full, fading
## over flash_ticks) and shakes the camera; the barrel's Special K drains into the dish.
func takeover(t: float) -> void:
	_tick += 1
	var cfg := CreationSet.cfg()
	var timing: Dictionary = Content.section("creation")["timing"]
	var freeze := Num.f(cfg["freeze_s"]) / Num.f(timing["takeover_s"])
	var ov := Num.f(cfg["overload_at"])
	if not _struck:
		_struck = true
		_flash_age = 0
	if t >= ov and not _overloaded:
		_overloaded = true
		_flash_age = 0
	if t < freeze:
		genome.takeover(0.0)
	elif t < ov:
		genome.takeover((t - freeze) / (ov - freeze))
	elif t >= ov + freeze:
		genome.overload((t - ov - freeze) / (1.0 - ov - freeze))
	_hit(Num.i(cfg["flash_ticks"]), Num.f(cfg["shake"]), Num.f(cfg["shake_s"]))
	_beat(1.0 + t)
	injector.barrel.set_level(1.0 - smoothstep(freeze, 0.3, t))
	injector.rest(smoothstep(0.3, 0.6, t), Num.f(cfg["injector"]["dish_tip"]))


## A hit-stop's white (full on its first tick, fading over `ticks`) and camera shake (`amount`
## metres, fading over `seconds`); deterministic, from the tick.
func _hit(ticks: int, amount: float, seconds: float) -> void:
	if _flash_age < 0:
		flash = 0.0
		return
	flash = clampf(1.0 - float(_flash_age) / maxi(ticks, 1), 0.0, 1.0)
	var fade := 1.0 - clampf(_flash_age / (seconds * Engine.physics_ticks_per_second), 0.0, 1.0)
	camera.h_offset = sin(_flash_age * 2.3) * amount * fade
	camera.v_offset = cos(_flash_age * 3.1) * amount * fade
	_flash_age += 1


## The screens' green spill beats like a heart, faster as the takeover grows.
func _beat(rate: float) -> void:
	var pulse := pow(maxf(sin(_tick * 0.16 * rate), 0.0), 6.0)
	_screens.light_energy = CreationSet.energy("screens") * (0.6 + 1.4 * pulse)


## The camera (t 0..1): from the close-up over the bench it turns onto the dish in the first half
## and rushes down into it, faster and faster, narrowing; the screen goes black from black_from
## on (KaijuCreation draws it).
func zoom(t: float) -> void:
	flash = 0.0
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	var shot: Dictionary = CreationSet.cfg()["camera"]
	var end: Dictionary = CreationSet.cfg()["zoom"]
	var k := t * t
	camera.position = CreationSet.vec(shot["position"]).lerp(CreationSet.vec(end["position"]), k)
	camera.fov = lerpf(Num.f(shot["fov"]), Num.f(end["fov"]), k)
	var turn := smoothstep(0.0, 0.5, t)
	var aim := CreationSet.vec(shot["look"]).lerp(CreationSet.vec(end["look"]), turn)
	camera.look_at(aim, Vector3.UP)
