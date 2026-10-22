class_name BoltRig
extends Node3D
## A lightning bolt that strikes on a schedule (VFX_STYLE family 6; research 17): a dim feeler
## creeping out of the mouth, then bright strokes down one fixed main channel, with a few branches
## re-rolled at each stroke, and two pooled lights (mouth and impact) that flood the street on each
## stroke. The breath (BreathBeam) and the Thunder Beam (ThunderBeam) are this rig with different
## widths and targets. It draws through BoltView (one shader), kicks the family-5 sparks and the
## family-3 dust where it lands, and tells its owner of every stroke (camera shake, sound).
## Strokes come at least `stroke_gap` apart, so never more than 3 full flashes a second. All
## numbers are tuning "fx" "bolt"; presentation only, the sim decides nothing here.

## A stroke fired: its number (1 on) and where the bolt lands.
signal stroked(index: int, at: Vector3)

const FLARE := preload("res://scenes/flare.gdshader")
const HOT := Color(1.0, 0.85, 0.65)
## Bolt seeds per run: an owner's seed is run * this + the play's number.
const SEEDS_PER_RUN := 4096
## The impact light sits this far back from the struck point (world units at body scale 1).
const LIGHT_BACK := 1.5

## The signature Power's brightness for this play (1..fx.power_max).
var power := 1.0
## The sim's breath cone (BoltShape): branches never leave it. Empty: no cone to keep inside.
var cone: Dictionary = {}
## (from: Vector3, span: Vector3) -> float: how much of the span a branch gets before it meets
## something solid (AbilityFx._first_hit). Invalid: branches run their whole way.
var blocker: Callable
## (rng, count) -> Array[Vector3]: where this play's branches strike. Invalid: across the cone.
var ends: Callable
## Where the sparks and dust come from (the city's Fx); null: none.
var fx: Fx
## Lit now (between play and the end).
var live := false

var _cfg: Dictionary
var _row: Dictionary
var _scale: float
var _view: BoltView
var _mouth_light := OmniLight3D.new()
var _hit_light := OmniLight3D.new()
var _muzzle: MeshInstance3D
var _strike: MeshInstance3D
var _rng: RandomNumberGenerator
var _t := 0.0
var _since := 0.0
var _next := 0.0
var _end := 0.0
var _index := 0
var _reveal := 1.0
var _dirty := true
var _mouth := Vector3.ZERO
var _hit := Vector3.ZERO
var _main_shape := PackedVector3Array()
var _branches: Array[Dictionary] = []


## kind: the owner's row in tuning "fx" "bolt" ("breath", "thunder"); eye: the species' eye colour.
func _init(kind: String, eye: Color, body_scale: float, cfg: Dictionary) -> void:
	_cfg = cfg
	_row = cfg[kind]
	_scale = body_scale
	var widths := Vector2(Num.f(_row["core"]), Num.f(_row["halo"])) * body_scale
	_view = BoltView.new(widths, eye, cfg)
	add_child(_view)
	var colours := BoltView.halo_colours(cfg, eye)
	_setup_light(_mouth_light, HOT)
	_setup_light(_hit_light, colours[0].lightened(0.3))
	_muzzle = _flare(HOT)
	_strike = _flare(colours[0].lightened(0.4))
	cancel()


## Every material the rig draws with, for the shader keep.
func materials() -> Array[ShaderMaterial]:
	var out := _view.all_materials()
	for flare: MeshInstance3D in [_muzzle, _strike]:
		out.append((flare.mesh as QuadMesh).material as ShaderMaterial)
	return out


## Starts the bolt for `seconds` (0 or less: until release()), strokes drawn from `rng`.
func play(seconds: float, rng: RandomNumberGenerator) -> void:
	_rng = rng
	_t = 0.0
	_since = 0.0
	_index = 0
	_end = seconds if seconds > 0.0 else INF
	_next = Num.f(_cfg["first_at"])
	_reveal = Num.f(_cfg["feeler_reach"][0])
	_main_shape = BoltShape.channel(_rng, Num.i(_cfg["depth"]), Num.f(_row["sway"]))
	_branches.clear()
	var lift := lerpf(1.0, power, Num.f(_cfg["power_share"]))
	_view.set_power(Num.f(_cfg["boost_core"]) * lift, Num.f(_cfg["boost_halo"]) * lift)
	live = true
	_dirty = true
	for node: Node3D in [_view, _mouth_light, _hit_light, _muzzle, _strike]:
		node.visible = true


## Where the bolt runs now: from the mouth to the struck point. Cheap to call every frame.
func aim(mouth: Vector3, hit: Vector3) -> void:
	if mouth.distance_to(_mouth) > 0.02 or hit.distance_to(_hit) > 0.02:
		_dirty = true
	_mouth = mouth
	_hit = hit


## Lets a held bolt fade out over `tail`.
func release() -> void:
	_end = minf(_end, _t + Num.f(_cfg["tail"]))


## Stops at once and hides everything.
func cancel() -> void:
	live = false
	_view.hide_all()
	for node: Node3D in [_view, _mouth_light, _hit_light, _muzzle, _strike]:
		node.visible = false


func _process(delta: float) -> void:
	if not live:
		return
	_t += delta
	_since += delta
	if _t >= _end:
		cancel()
		return
	if _t >= _next:
		_stroke()
	_feel()
	_shine()
	if _dirty:
		_draw()


## The dim feeler: the main channel creeping out of the mouth in steps until the first stroke.
func _feel() -> void:
	if _index > 0:
		return
	var reach: Array = _cfg["feeler_reach"]
	var step := Num.f(_cfg["feeler_step"])
	var first := Num.f(_cfg["first_at"])
	var done := floorf(_t / step) * step / first
	var now := lerpf(Num.f(reach[0]), Num.f(reach[1]), clampf(done, 0.0, 1.0))
	if not is_equal_approx(now, _reveal):
		_reveal = now
		_dirty = true


## Brightness of the bolt and its lights this frame.
func _shine() -> void:
	var fade := smoothstep(0.0, Num.f(_cfg["tail"]), _end - _t)
	var main := Num.f(_cfg["feeler_level"])
	var branch := 0.0
	var flash := 0.0
	if _index > 0:
		var hold := Num.f(_cfg["hold_level"])
		main = hold + (1.0 - hold) * exp(-_since / Num.f(_cfg["stroke_decay"]))
		branch = Num.f(_cfg["branch_peak"]) * exp(-_since / Num.f(_cfg["branch_decay"]))
		flash = exp(-_since / Num.f(_cfg["light_decay"]))
	_view.set_levels(main * fade, branch * fade)
	var lights: Dictionary = _cfg["light"]
	var base := Num.f(lights["hold_share"])
	var flood := (
		(base + (1.0 - base) * flash) * fade * lerpf(1.0, power, Num.f(_cfg["power_share"]))
	)
	if _index == 0:
		flood = 0.0
	var mouth_row: Array = lights["mouth"]
	var impact_row: Array = lights["impact"]
	_light(_mouth_light, mouth_row, flood)
	_light(_hit_light, impact_row, flood)
	_flare_fade(_muzzle, flash * fade)
	_flare_fade(_strike, flash * fade)


## One stroke: a new shape on the same channel's branches, a flash, sparks, dust, the shake.
func _stroke() -> void:
	_index += 1
	_since = 0.0
	_reveal = 1.0
	_roll_branches()
	_dirty = true
	var gap := Num.f(_cfg["stroke_gap"]) + _rng.randf() * Num.f(_cfg["gap_jitter"])
	_next = _t + gap
	if _next > _end - Num.f(_cfg["end_margin"]):
		_next = INF
	_impact()
	stroked.emit(_index, _hit)


## 3-5 (the owner's row) fresh branches off the main channel, each to its own target.
func _roll_branches() -> void:
	_branches.clear()
	var count: Array = _row["branches"]
	var n := _rng.randi_range(Num.i(count[0]), Num.i(count[1]))
	var main := _main_world()
	var targets: Array = []
	if ends.is_valid():
		targets = ends.call(_rng, n)
	elif not cone.is_empty():
		targets = BoltShape.fan_ends(_rng, cone, n)
	for target: Vector3 in targets:
		var t := _anchor(target)
		var from := BoltShape.at_t(main, t)
		var shape := BoltShape.channel(
			_rng, Num.i(_cfg["branch_depth"]), Num.f(_row["branch_sway"])
		)
		_branches.append({"t": t, "end": _stopped(from, target), "shape": shape})


## Where along the main channel (0..1) a branch to `target` forks off: the owner's range at random,
## or, where its branches strike things beside the beam, just short of the point nearest the target.
func _anchor(target: Vector3) -> float:
	var span: Array = _row["branch_from"]
	var lo := Num.f(span[0])
	var hi := Num.f(span[1])
	var near: bool = _row["anchor_near"]
	if not near:
		return _rng.randf_range(lo, hi)
	var axis := _hit - _mouth
	var along := (target - _mouth).dot(axis) / maxf(axis.length_squared(), 0.001)
	return clampf(along - Num.f(_row["anchor_back"]), lo, hi)


## `target` cut short where something solid is in the way from `from`.
func _stopped(from: Vector3, target: Vector3) -> Vector3:
	if not blocker.is_valid():
		return target
	var span := target - from
	var share: float = blocker.call(from, span)
	return from + span * share


## The main channel in the world, from the mouth to the struck point, kept inside the cone.
func _main_world() -> PackedVector3Array:
	return _kept(BoltShape.place(_main_shape, _mouth, _hit))


## `line` with its inner points pulled inside the cone (ends stay where they are).
func _kept(line: PackedVector3Array) -> PackedVector3Array:
	if cone.is_empty():
		return line
	for i: int in range(1, line.size() - 1):
		line[i] = BoltShape.clamp_to_cone(line[i], cone)
	return line


## Rebuilds the ribbons for the current shape, aim and reach.
func _draw() -> void:
	_dirty = false
	var main := _main_world()
	var lines: Array[PackedVector3Array] = []
	for b: Dictionary in _branches:
		var shape: PackedVector3Array = b["shape"]
		var end: Vector3 = b["end"]
		lines.append(_kept(BoltShape.place(shape, BoltShape.at_t(main, Num.f(b["t"])), end)))
	var shown := mini(main.size(), ceili(_reveal * (main.size() - 1)) + 1)
	_view.rebuild(main.slice(0, shown), lines, Num.f(_row["branch_width"]))
	var dir := (_hit - _mouth).normalized()
	_muzzle.position = _mouth
	_strike.position = _hit - dir * 0.6
	var size := Num.f(_cfg["flare_size"]) * _scale * lerpf(1.0, power, Num.f(_cfg["power_share"]))
	(_muzzle.mesh as QuadMesh).size = Vector2.ONE * size
	(_strike.mesh as QuadMesh).size = Vector2.ONE * size
	_mouth_light.position = _mouth
	_hit_light.position = _hit - dir * LIGHT_BACK * _scale + Vector3.UP * _scale * 0.5


## Sparks where the bolt lands (and where the first branches do), dust off the street.
func _impact() -> void:
	if fx == null:
		return
	fx.sparks(_hit)
	for b: Dictionary in _branches.slice(0, Num.i(_cfg["branch_sparks"])):
		var end: Vector3 = b["end"]
		fx.sparks(end)
	fx.dust(Vector3(_hit.x, 0.4, _hit.z), Num.f(_row["dust"]) * _scale)


func _setup_light(light: OmniLight3D, colour: Color) -> void:
	var lights: Dictionary = _cfg["light"]
	light.light_color = colour
	light.omni_attenuation = Num.f(lights["falloff"])
	light.shadow_enabled = false
	light.light_energy = 0.0
	add_child(light)


func _light(light: OmniLight3D, row: Array, flood: float) -> void:
	light.light_energy = Num.f(row[0]) * flood
	light.omni_range = Num.f(row[1]) * _scale


func _flare(tint: Color) -> MeshInstance3D:
	var quad := QuadMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = FLARE
	mat.set_shader_parameter("tint", tint)
	quad.material = mat
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


static func _flare_fade(flare: MeshInstance3D, fade: float) -> void:
	((flare.mesh as QuadMesh).material as ShaderMaterial).set_shader_parameter("fade", fade)
