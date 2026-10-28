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
## The first stroke of a play landed at `at`: the sound hook for a thunder layer under it (no
## thunder asset exists yet: nothing is connected, the lead's side adds the cleared sound).
signal thundered(at: Vector3)

const FLARE := preload("res://scenes/flare.gdshader")
## The mouth light's and the flares' colour where the halo mode names none (the purple names
## its own, D-357).
const HOT := Color(1.0, 0.85, 0.65)
const STRIKE_WHITE := Color(1.0, 0.96, 0.88)
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
## The polylines drawn at the last rebuild (main channel, branches), world points: a capture
## projects them to measure the bolt on screen.
var drawn_main := PackedVector3Array()
var drawn_lines: Array[PackedVector3Array] = []

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
var _arcs: BoltArcs
var _thrown: BoltImpact
var _forks: BoltBranches


## kind: the owner's row in tuning "fx" "bolt" ("breath", "thunder"); eye: the species' eye colour.
func _init(kind: String, eye: Color, body_scale: float, cfg: Dictionary) -> void:
	_cfg = cfg
	_row = cfg[kind]
	_scale = body_scale
	_arcs = BoltArcs.new(_row, cfg, body_scale)
	_thrown = BoltImpact.new(_row, cfg, body_scale)
	_forks = BoltBranches.new(self, cfg, _row)
	_view = BoltView.new(Num.f(_row["core"]) * body_scale, eye, cfg)
	add_child(_view)
	var colours := BoltView.halo_colours(cfg, eye)
	_setup_light(_mouth_light, BoltView.flare_colour(cfg, HOT))
	_setup_light(_hit_light, colours[0].lightened(0.3))
	_muzzle = _flare(BoltView.flare_colour(cfg, HOT))
	_strike = _flare(BoltView.flare_colour(cfg, STRIKE_WHITE))
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
	_arcs.clear()
	var lift := lerpf(1.0, power, Num.f(_cfg["power_share"]))
	_view.set_power(Num.f(_cfg["boost_core"]) * lift, Num.f(_cfg["fringe_boost"]) * lift)
	live = true
	_dirty = true
	for node: Node3D in [_view, _mouth_light, _hit_light, _muzzle, _strike]:
		node.visible = true


## Where the bolt runs now: from the mouth to the struck point. Cheap to call every frame.
func aim(mouth: Vector3, hit: Vector3) -> void:
	var move := Num.f(_cfg["rebuild_move"]) * _scale
	if mouth.distance_to(_mouth) > move or hit.distance_to(_hit) > move:
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
	if _arcs.step(delta, _mouth, _hit, _rng):
		_dirty = true
	_shine(delta)
	if _dirty:
		_draw()


## The dim leader: the main channel growing from the mouth to the target, a frame at a time, until
## the first stroke (a return stroke down a channel that is already there, never a bolt from
## nothing).
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
func _shine(delta: float) -> void:
	var fade := smoothstep(0.0, Num.f(_cfg["tail"]), _end - _t)
	var main := Num.f(_cfg["feeler_level"])
	var branch := 0.0
	var flash := 0.0
	if _index > 0:
		var hold := Num.f(_cfg["hold_level"])
		var attack := Num.f(_cfg["attack"])
		var from := Num.f(_cfg["feeler_level"]) if _index == 1 else hold
		main = hold + (1.0 - hold) * _env(Num.f(_cfg["stroke_decay"]))
		if _since < attack:
			main = lerpf(from, 1.0, _since / attack)
		var peak := Num.f(_cfg["branch_peak"])
		var held := Num.f(_cfg["branch_hold"])  # the forks stay lit between strokes
		branch = held + (peak - held) * _env(Num.f(_cfg["branch_decay"]))
		flash = _env(Num.f(_cfg["light_decay"]))
	_view.set_levels(main * fade, branch * fade, Num.f(_cfg["arc_level"]) * fade)
	var lights: Dictionary = _cfg["light"]
	var base := Num.f(lights["hold_share"])
	var flood := (
		(base + (1.0 - base) * flash) * fade * lerpf(1.0, power, Num.f(_cfg["power_share"]))
	)
	if _index == 0:  # the lights come up with the feeler, so the first stroke is no jump
		flood = base * clampf(_t / Num.f(_cfg["first_at"]), 0.0, 1.0) * fade
	var mouth_row: Array = lights["mouth"]
	var impact_row: Array = lights["impact"]
	_light(_mouth_light, mouth_row, flood, delta)
	_light(_hit_light, impact_row, flood, delta)
	_flare_fade(_muzzle, flash * fade)
	var burst := _env(Num.f(_cfg["strike_decay"])) if _index > 0 else 0.0
	_flare_fade(_strike, burst * fade * clampf((_reveal - 0.9) * 10.0, 0.0, 1.0))


## 0..1: a stroke ramps up over `attack` (no one-frame jump), then falls with time constant `decay`.
func _env(decay: float) -> float:
	var attack := Num.f(_cfg["attack"])
	if _since < attack:
		return _since / attack
	return exp(-(_since - attack) / decay)


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
	if _index == 1:
		thundered.emit(_hit)


## Fresh branches off the main channel for this stroke (BoltBranches).
func _roll_branches() -> void:
	_branches = _forks.roll(_rng, _main_world(), _mouth, _hit)


## The main channel in the world, from the mouth to the struck point, kept inside the cone.
func _main_world() -> PackedVector3Array:
	var line := BoltShape.place(_main_shape, _clear_of_head(), _hit)
	var bow := Num.f(_row["bow"]) * line[0].distance_to(line[line.size() - 1])
	for i: int in range(1, line.size() - 1):  # bowed up by `bow` (0: straight from the throat, D-357)
		line[i] += Vector3.UP * bow * sin(PI * i / (line.size() - 1))
	return _kept(line)


## Where the main channel starts: `clear` out along the aim from the mouth point (0: right in the
## throat, D-357).
func _clear_of_head() -> Vector3:
	return _mouth + (_hit - _mouth).normalized() * Num.f(_row["clear"]) * _scale


## `line` with its inner points pulled inside the cone (ends stay where they are).
func _kept(line: PackedVector3Array) -> PackedVector3Array:
	if cone.is_empty():
		return line
	for i: int in range(1, line.size() - 1):
		line[i] = BoltShape.clamp_to_cone(line[i], cone)
	return line


## Rebuilds the capsules for the current shape, aim and reach.
func _draw() -> void:
	_dirty = false
	var main := _main_world()
	var lines: Array[PackedVector3Array] = []
	for b: Dictionary in _branches:
		var shape: PackedVector3Array = b["shape"]
		var end: Vector3 = b["end"]
		var of := Num.i(b["of"])
		var host := main if of < 0 else lines[of]
		if host.size() < 2 or (of < 0 and Num.f(b["t"]) > _reveal):  # not reached yet
			lines.append(PackedVector3Array())
			continue
		lines.append(_kept(BoltShape.place(shape, BoltShape.at_t(host, Num.f(b["t"])), end)))
	var widths := Vector2(Num.f(_row["branch_width"]), Num.f(_row["arc_width"]))
	drawn_main = BoltShape.cut(main, _reveal)
	drawn_lines = lines
	_view.rebuild(drawn_main, lines, _arcs.lines, widths)
	var dir := (_hit - _mouth).normalized()
	_muzzle.position = _clear_of_head() + Vector3.UP * Num.f(_cfg["muzzle_up"]) * _scale
	_strike.position = _hit - dir * 0.6 + Vector3.UP * Num.f(_cfg["strike_lift"]) * _scale
	var lift := _scale * lerpf(1.0, power, Num.f(_cfg["power_share"]))
	(_muzzle.mesh as QuadMesh).size = Vector2.ONE * Num.f(_cfg["muzzle_flare"]) * lift
	var strike := Num.f(_cfg["strike_flare"]) * Num.f(_row["strike_scale"])
	(_strike.mesh as QuadMesh).size = Vector2.ONE * strike * lift
	_mouth_light.position = _mouth
	_hit_light.position = _hit - dir * LIGHT_BACK * _scale + Vector3.UP * _scale * 0.5


## What the stroke throws where it lands (BoltImpact).
func _impact() -> void:
	var ends: Array[Vector3] = []
	for b: Dictionary in _branches:
		ends.append(b["end"])
	_thrown.strike(fx, _hit, ends)


func _setup_light(light: OmniLight3D, colour: Color) -> void:
	var lights: Dictionary = _cfg["light"]
	light.light_color = colour
	light.omni_attenuation = Num.f(lights["falloff"])
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 0.0  # no fog shafts: their shadow edges drew straight wedges
	light.light_energy = 0.0
	add_child(light)


func _light(light: OmniLight3D, row: Array, flood: float, delta: float) -> void:
	var follow := 1.0 - exp(-delta * Num.f(_cfg["light_follow"]))  # over 2-3 frames, never a jump
	var bright := Num.f(row[0]) * flood * PlayerSettings.flash_scale()  # Reduce flashing (D-259)
	light.light_energy = lerpf(light.light_energy, bright, follow)
	light.omni_range = Num.f(row[1]) * _scale


func _flare(tint: Color) -> MeshInstance3D:
	var quad := QuadMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = FLARE
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("edge", Num.f(_cfg["flare_edge"]))
	mat.set_shader_parameter("soft", Num.f(_cfg["flare_soft"]) * _scale)
	quad.material = mat
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


static func _flare_fade(flare: MeshInstance3D, fade: float) -> void:
	((flare.mesh as QuadMesh).material as ShaderMaterial).set_shader_parameter(
		"fade", fade * PlayerSettings.flash_scale()
	)  # Reduce flashing (D-259)
