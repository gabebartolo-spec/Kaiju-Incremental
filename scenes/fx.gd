class_name Fx
extends Node3D
## Particle and shader effects, presentation only: dust clouds from breaking floors and landing
## towers, a puff at each footfall, sparks from shell hits, embers, and the stomp shockwave.
## Every effect is built once at start (prewarm) so its shaders compile before play instead of
## freezing the first time.

const SHOCKWAVE := preload("res://scenes/shockwave.gdshader")
## A tail slam's puffs (shockwave(tail), lead review PR #54): one at the tip and SLAM_PUFFS around
## it, each SLAM_SIZE x the ring radius it was given; they live SLAM_SECONDS, grow from 0.4 to full
## over the first FxParticleMats.SLAM_GROW of it with their alpha rising from 0 to its peak at
## SLAM_PEAK, stop growing by SLAM_HOLD and fade to nothing by the end (not the step puff's pop and
## slow climb).
const SLAM_PUFFS := 3
const SLAM_SIZE := 0.6
const SLAM_SECONDS := 0.85
const SMOKE := preload("res://scenes/smoke.gdshader")
## The street's dust: one tone for every dust call (the cloud, a person's puff, the footfall and
## slam puffs, a tree's soil puff and the ring; docs/VFX_STYLE.md families 3 and 7; the VFX look
## sheet review of 2026-10-23: the dust was a charcoal that vanished into the road, then a blue
## haze at night under the blue ambient light).
const STREET_DUST := Color("8a6f4e")
## The one switch: 1 draws every dust puff in its own colour (the smoke shader's `self_lit`, an
## emission) so night and noon show the same warm dust; 0 lights it by the scene like smoke.
const DUST_SELF_LIT := 1.0
## A stomp's ring is this many times its reach (rampage.gd): it must read as huge.
const STOMP_RING := 3.0
## The same dust at night, a little darker; the sun (night 0.35 to noon 1.6, data/looks.json)
## picks between the two.
const NIGHT_DUST := Color("6a5238")
const SUN_NIGHT := 0.35
const SUN_NOON := 1.6
## A tree's puffs are this many times the tree's size: the first look was lost beside the stump.
const TREE_PUFF_SCALE := 2.4
## A crushed tree's dust (lead, #55 r14): at its peak by frame 3, held to frame 5, then fading
## evenly to nothing by frame 29 (30 fps). Drawn as the street dust (docs/VFX_STYLE.md family 3,
## director 2026-10-23: one dust look), with the smoke shader's screen-centre clearing off, since
## a tree falls right where the kaiju walks (lead, #55 r13).
const PUFF_RISE := 0.1
const PUFF_HOLD := 0.07
const PUFF_FADE := 0.35
## Where a shell or the beam's end sparks cool to (white-hot first: FxParticles.sparks).
const SPARK_TINT := Color(1.0, 0.45, 0.1)
## A shell hit's sparks: how many, and the glow cube's size in metres (family 5: 0.12-0.22 m).
const SPARK_COUNT := 28
const SPARK_CUBE := 0.2

## One hidden user of each effect material, so no shader is compiled again mid-rampage.
var keep := ShaderKeep.new()
## Footfall puffs still in the air (at most tuning "fx" "footfall_dust" "max_live").
var steps_live: Array[GPUParticles3D] = []
## The reused particle systems (render plan item 8, tuning render_opt.fx_pool): every burst below
## takes one instead of building and freeing a system. Shared with Fire and BlastParts through
## FxPool.shared.
var pool: FxPool

var _dust_mat: ParticleProcessMaterial
var _dust_mesh: Mesh
var _puff_mesh: Mesh
var _step_mat: ParticleProcessMaterial
var _step_mesh: QuadMesh
var _step_cfg: Dictionary
var _slam_mat: ParticleProcessMaterial
var _spark_mat: ParticleProcessMaterial
var _tree_mat: ParticleProcessMaterial
var _tree_mesh: QuadMesh
var _spark_mesh: BoxMesh
var _hide_hit: HideHit


func _ready() -> void:
	var dust_style := {
		"spread": 70.0,
		"gravity": Vector3(0, 0.6, 0),
		"vmin": 1.5,
		"vmax": 4.0,
		"smin": 1.0,
		"smax": 2.6,
		"grow": true,
		"colors": [Color(_dust_light(), 0.47), Color(_dust_light(), 0.0)],
	}
	_dust_mat = FxParticleMats.dust(dust_style)
	_dust_mesh = _puff(2.2)
	_puff_mesh = _puff(0.5)
	_step_cfg = Content.section("fx")["footfall_dust"]
	var alpha := Num.f(_step_cfg["alpha"])
	var step_style := {
		"spread": 55.0,
		"gravity": Vector3(0, 0.2, 0),
		"vmin": 0.5,
		"vmax": Num.f(_step_cfg["rise"]),
		"smin": 0.8,
		"smax": 1.6,
		"grow": true,
		"colors": [Color(_dust_light(), alpha), Color(_dust_light(), 0.0)],
	}
	_step_mat = FxParticleMats.dust(step_style)
	_step_mesh = _puff(3.0)
	_clear_centre_off(_step_mesh)  # a footfall is at the kaiju's foot: the dust must show there
	_slam_mat = FxParticleMats.slam(_step_mat, alpha, _dust_light())
	# The game's one spark (docs/VFX_STYLE.md family 5): white-hot glow cubes cooling to orange.
	_spark_mat = FxParticles.sparks(SPARK_TINT)
	_spark_mat.direction = Vector3.UP
	_spark_mesh = FxParticles.glow_cube(SPARK_CUBE)
	_tree_mat = FxParticleMats.tree()
	_tree_mesh = _puff(1.0)
	_clear_centre_off(_tree_mesh)
	add_child(keep)
	_register_pool()
	_hide_hit = HideHit.new()
	add_child(_hide_hit)
	_keep_materials()
	_prewarm()


## Holds every effect material compiled for the run (see ShaderKeep).
func _keep_materials() -> void:
	var claws := ClawSlash.marks_material(Content.section("claw_fx"))
	var kept: Array[Material] = [_dust_mat, _step_mat, _slam_mat, _spark_mat, _tree_mat]
	kept.append_array([_tree_mesh.material, _spark_mesh.material, _step_mesh.material])
	kept.append_array([claws, LandmarkBurst.chunk_material()])
	for mat: Material in kept:
		keep.hold(str(mat.get_instance_id()), mat)


## Slots per burst kind, from tuning render_opt.fx_pool.slots (provisional: to be re-sized from
## the bench's peak concurrency), then the bare slots the blasts and fires take from FxPool.shared.
func _register_pool() -> void:
	pool = FxPool.new()
	add_child(pool)
	pool.register("dust", _dust_mat, _dust_mesh, FxPool.slots_for("dust", 24))
	pool.register("puff", _dust_mat, _puff_mesh, FxPool.slots_for("puff", 8))
	pool.register("step", _step_mat, _step_mesh, FxPool.slots_for("step", 8))
	pool.register("slam", _slam_mat, _step_mesh, FxPool.slots_for("slam", 8))
	pool.register("tree", _tree_mat, _tree_mesh, FxPool.slots_for("tree", 8))
	pool.register("spark", _spark_mat, _spark_mesh, FxPool.slots_for("spark", 8))
	pool.register_bare("burst", FxPool.slots_for("burst", 16))
	for part: String in ["flames", "embers", "smoke"]:
		pool.register_bare(part, FxPool.slots_for(part, 12))


## Prewarm: one of each, out of sight, so the first real one does not stall a frame.
func _prewarm() -> void:
	dust(Vector3(0, -50, 0), 0.5)
	footfall(Vector3(0, -50, 0), 0.5)
	sparks(Vector3(0, -50, 0))
	shockwave(Vector3(0, -50, 0), 1.0)
	hide_hit(Vector3(0, -50, 0), Vector3.UP, 0.12)


## A billowing dust cloud; size ~ the width of what came down.
## tint (alpha > 0): the puff's colour instead of the grey (a toppled tower's pale concrete).
func dust(at: Vector3, size: float, tint := Color(0, 0, 0, 0)) -> void:
	var p := _burst("dust", roundi(12 * clampf(size, 0.5, 4.0)), 2.6)
	p.position = at
	var mat: ParticleProcessMaterial = p.process_material
	mat.emission_box_extents = Vector3(size, 0.4, size)
	if tint.a > 0.0:
		var k := _tint_scale()
		var lit := Color(tint.r * k, tint.g * k, tint.b * k, tint.a)
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([lit, Color(lit, 0.0)])
		var tex := GradientTexture1D.new()
		tex.gradient = ramp
		mat.color_ramp = tex


## A footfall's puff: short-lived and thin, so a walk leaves a puff per step instead of piling
## into a haze that greys out the ground (greenery review). Skipped while max_live are still up,
## unless uncapped (a tail slam's puffs, shockwave(tail)).
func footfall(at: Vector3, size: float, capped := true) -> void:
	var alive: Array[GPUParticles3D] = []
	for puff: Variant in steps_live:  # a finished puff is freed or given back: check it
		if not is_instance_valid(puff):
			continue
		var system: GPUParticles3D = puff
		if system.visible and not alive.has(system):  # a pooled puff given back is hidden
			alive.append(system)
	steps_live = alive
	if capped and steps_live.size() >= Num.i(_step_cfg["max_live"]):
		return
	var amount := roundi(6 * clampf(size, 0.5, 3.0))
	var p := _burst("step", amount, Num.f(_step_cfg["seconds"]))
	p.position = at
	var mat: ParticleProcessMaterial = p.process_material
	mat.emission_box_extents = Vector3(size * 0.6, 0.2, size * 0.6)
	mat.scale_min = 0.8 * size  # as wide as the foot that threw it
	mat.scale_max = 1.3 * size
	steps_live.append(p)


## A dust puff over a crushed tree's stump: a few street-dust puffs `size` across in the soil's
## tint that come up to `peak` in PUFF_RISE, hold, grow a little and are gone in under a second.
func tree_puff(at: Vector3, size: float, peak: float) -> void:
	var p := _burst("tree", 3, PUFF_RISE + PUFF_HOLD + PUFF_FADE)
	p.position = at + Vector3(0, size * 0.35, 0)
	var mat: ParticleProcessMaterial = p.process_material
	mat.emission_box_extents = Vector3(size * 0.2, 0.1, size * 0.2)
	mat.scale_min = size * 0.8 * TREE_PUFF_SCALE
	mat.scale_max = size * TREE_PUFF_SCALE
	var total := PUFF_RISE + PUFF_HOLD + PUFF_FADE
	var soil := _dust_light()
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array(
		[0.0, PUFF_RISE / total, (PUFF_RISE + PUFF_HOLD) / total, 1.0]
	)
	ramp.colors = PackedColorArray(
		[Color(soil, 0.0), Color(soil, peak), Color(soil, peak), Color(soil, 0.0)]
	)
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	mat.color_ramp = tex


## A small puff of dust: a person crushed underfoot.
func puff(at: Vector3) -> void:
	var p := _burst("puff", 6, 1.2)
	p.position = at
	var mat: ParticleProcessMaterial = p.process_material
	mat.emission_box_extents = Vector3(0.2, 0.1, 0.2)
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.0


## Dust along a line: where a toppled tower hits the street.
func dust_line(from: Vector3, to: Vector3, width: float, tint := Color(0, 0, 0, 0)) -> void:
	var steps := maxi(2, ceili(from.distance_to(to) / 2.5))
	for i: int in steps + 1:
		dust(from.lerp(to, float(i) / steps) + Vector3(0, 0.5, 0), width * 0.6, tint)


## A shot landing on the kaiju's hide (HideHit): `normal` is the surface's, `unit` one voxel of the
## hide in the world. A glance (armour) passes `away`, along which its sparks go. Use HideHit.land
## to find the real hit point first.
func hide_hit(at: Vector3, normal: Vector3, unit: float, away := HideHit.NO_GLANCE) -> void:
	_hide_hit.play(at, normal, unit, away)


func sparks(at: Vector3) -> void:
	var p := _burst("spark", SPARK_COUNT, 0.5)
	p.position = at


## A soft ripple of dust that runs out across the ground from a landing (no glow, no tint: a ring
## with no visible impact behind it is not drawn by the callers). Size, life and opacity are
## tuning "fx" "shockwave": small and faint so it reads as dust kicked off the street.
## A foot's ring (foot) starts out at foot_start of its radius, clear of the foot that
## made it, on the landing frame. A tail slam (tail) draws no ring: a few footfall puffs thrown
## out around the tip instead (lead review PR #54: three custom rings in a row popped; the step
## puff of #62 reads right).
func shockwave(at: Vector3, radius: float, tail := false, foot := false) -> void:
	if tail:
		_slam_puff(at + Vector3(0, 0.2, 0), radius * SLAM_SIZE)
		for k: int in SLAM_PUFFS:
			var a := TAU * k / SLAM_PUFFS
			_slam_puff(at + Vector3(cos(a), 0.4, sin(a)) * radius * 0.35, radius * SLAM_SIZE * 0.8)
		return
	var cfg: Dictionary = Content.section("fx")["shockwave"]
	var quad := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * Num.f(cfg["radius_scale"]) * 2.4
	var mat := ShaderMaterial.new()
	mat.shader = SHOCKWAVE
	mat.set_shader_parameter("tint", _dust_tone())
	mat.set_shader_parameter("peak", Num.f(cfg["alpha"]))
	mat.set_shader_parameter("soft", Num.f(cfg["soft"]))
	var start := Num.f(cfg["foot_start"]) if foot else 0.0  # a foot's ring starts outside it
	mat.set_shader_parameter("progress", start)
	plane.material = mat
	quad.mesh = plane
	quad.position = at + Vector3(0, 0.15, 0)
	add_child(quad)
	var tween := quad.create_tween()
	tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("progress", v),
		start,
		1.0,
		Num.f(cfg["seconds"]) * (1.0 - start)
	)
	tween.tween_callback(quad.queue_free)


## A ring that spreads to `reach` (world units), where shockwave's `radius` is the stomp's own
## figure (its band ends at radius_scale x 1.2 of it): a tail sweep's ring reaches the tail's end.
func shockwave_to(at: Vector3, reach: float) -> void:
	var cfg: Dictionary = Content.section("fx")["shockwave"]
	shockwave(at, reach / (Num.f(cfg["radius_scale"]) * 1.2))


func _slam_puff(at: Vector3, size: float) -> void:
	var amount := roundi(6 * clampf(size, 0.5, 3.0))
	var p := _burst("slam", amount, SLAM_SECONDS)
	p.position = at
	var mat: ParticleProcessMaterial = p.process_material
	mat.emission_box_extents = Vector3(size * 0.6, 0.2, size * 0.6)
	mat.scale_min = 0.4 * size
	mat.scale_max = 0.8 * size


## One burst of `kind`: a pooled system when one is free (its values set, then restart()ed so no
## stale particle shows; it is given back when its particles are done), else a new one that frees
## itself, as before, so a burst is never dropped.
func _burst(kind: String, amount: int, life: float) -> GPUParticles3D:
	var pooled := pool.acquire(kind, amount)
	if pooled == null:
		return _build_burst(pool.base_of(kind), pool.mesh_of(kind), amount, life)
	pooled.amount_ratio = GraphicsPresets.cap("particles")  # R 18.3
	if pooled.amount != amount:
		pooled.amount = amount
	pooled.lifetime = life
	pooled.one_shot = true
	pooled.explosiveness = 0.9
	pooled.restart()
	FxPool.give_after(pooled, life + 0.2)
	return pooled


## The burst built from nothing: the way every burst was made before the pool.
func _build_burst(
	mat: ParticleProcessMaterial, mesh: Mesh, amount: int, life: float
) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount_ratio = GraphicsPresets.cap("particles")  # R 18.3
	p.process_material = mat.duplicate()
	p.draw_pass_1 = mesh
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = true
	add_child(p)
	get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)
	return p


## The street dust's tone for this time of day (NIGHT_DUST in the dark, STREET_DUST at noon).
static func _dust_tone() -> Color:
	var day := inverse_lerp(SUN_NIGHT, SUN_NOON, Look.value("sun_energy"))
	return NIGHT_DUST.lerp(STREET_DUST, clampf(day, 0.0, 1.0))


## How much of a tinted dust's own colour shows at this time of day: all of it by full day (the
## sun share squared, so dusk is dim too), only fx.tint_dust_night in the dark. The tint is drawn
## self-lit, so unscaled a toppled tower's pale concrete (c9c1b0) glowed white round the kaiju all
## night (the night glow, director 2026-10-23).
static func _tint_scale() -> float:
	var day := clampf(inverse_lerp(SUN_NIGHT, SUN_NOON, Look.value("sun_energy")), 0.0, 1.0)
	return lerpf(Num.f(Content.section("fx")["tint_dust_night"]), 1.0, day * day)


## The tone as a particle colour (the smoke shader reads COLOR as linear light).
static func _dust_light() -> Color:
	return _dust_tone().srgb_to_linear()


## The smoke shader's clearing of puffs near the screen centre and in front of the kaiju (D-018)
## off for this mesh: a footfall or a crushed tree is right where the kaiju stands.
func _clear_centre_off(mesh: QuadMesh) -> void:
	var mat := mesh.material as ShaderMaterial
	mat.set_shader_parameter("centre_keep", 1.0)
	mat.set_shader_parameter("focus_clear", 0.0)
	mat.set_shader_parameter("focus_full", 0.001)


## A soft camera-facing puff (the smoke shader), for dust clouds.
func _puff(size: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var mat := ShaderMaterial.new()
	mat.shader = SMOKE
	mat.set_shader_parameter("self_lit", DUST_SELF_LIT)
	quad.material = mat
	return quad
