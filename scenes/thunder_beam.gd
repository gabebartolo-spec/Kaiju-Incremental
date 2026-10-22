class_name ThunderBeam
extends Node3D
## The Thunder Beam (D-112, VFX_STYLE family 6): the Lightning Breath's bolt held for the beam's
## seconds. Its main channel runs from the jaw along the kaiju's facing into the first standing
## facade the beam meets (about 6 m up it; the sim's full range in the open) and is re-struck on
## the stroke schedule while the head steers; at each stroke its branches crawl up the wall from
## the impact, never down to the street. It replaces the solid emissive box. Reads the sim's state
## and decides nothing; the burning is the sim's existing coat (D-129).

var rig: BoltRig
var _sim: RampageSim
var _kaiju: Node3D
var _jaw: Node3D
var _run: int
var _bolts := 0
var _bs: float
var _end := Vector3.ZERO
var _latched := Vector2.ZERO  # the facing the target was picked at
var _cfg: Dictionary
var _row: Dictionary


## kaiju: the body whose jaw the bolt leaves; eye: the species' eye colour; run: the run's number
## (seeds each beam's strokes).
func _init(sim: RampageSim, kaiju: Node3D, eye: Color, run: int) -> void:
	_sim = sim
	_kaiju = kaiju
	_run = run
	_bs = sim.body_scale()
	var tune: Dictionary = Content.section("fx")
	_cfg = tune["bolt"]
	_row = _cfg["thunder"]
	rig = BoltRig.new("thunder", eye, _bs, _cfg)
	rig.ends = _lash_targets
	add_child(rig)


## Draws a throwaway beam out of sight for a few frames, so its shaders compile now (and stay).
func prewarm(keep: ShaderKeep) -> void:
	rig.aim(Vector3(0, -50, 0), Vector3(0, -50, 4))
	rig.play(Num.f(_cfg["prewarm_seconds"]), Seeds.make("thunder_prewarm"))
	for mat: ShaderMaterial in rig.materials():
		keep.hold("thunder_%d" % mat.get_instance_id(), mat)


## The beam begins (the sim's beam_start): lit for `seconds`, or until stop().
func start(seconds: float, kaiju_at: Vector3) -> void:
	_jaw = BreathBeam.jaw_of(_kaiju)
	_bolts += 1
	_latched = Vector2.ZERO
	_aim(kaiju_at)
	rig.play(seconds, Seeds.make("thunder_bolt", _run * BoltRig.SEEDS_PER_RUN + _bolts))


## The beam ends (the sim's beam_end): the bolt fades out.
func stop() -> void:
	rig.release()


## Every frame: the bolt follows the jaw and the facing the sim steers.
func update(kaiju_at: Vector3) -> void:
	if rig.live:
		_aim(kaiju_at)


func _aim(kaiju_at: Vector3) -> void:
	var facing := Vector3(_sim.facing.x, 0.0, _sim.facing.y)
	var mouth := kaiju_at + Vector3(0, 5.0 * _bs, 0) + facing * _bs
	if is_instance_valid(_jaw):
		mouth = BreathBeam.along_jaw(_jaw)
	if _latched == Vector2.ZERO or _sim.facing.angle_to(_latched) > Num.f(_row["turn_hold"]):
		_latched = _sim.facing  # the beam stays on one point of the facade until the player turns
		_end = _facade_end(kaiju_at, facing)
	rig.aim(mouth, _end)


## Where the beam ends: into the first standing facade on its line (`end_height` up it), else the
## sim's full range at street height.
func _facade_end(kaiju_at: Vector3, facing: Vector3) -> Vector3:
	var reach := Num.f(_sim.powers_cfg["beam_range"]) * _bs
	var best := reach
	var top := -1
	for b: RampageSim.Building in _sim.buildings:
		var t := _enter(b)
		if t >= best:
			continue
		var up := b.frame.top_below(floori(b.w * 0.5), floori(b.d * 0.5), b.height)
		if up > 0:
			best = t
			top = up
	var into := best + Num.f(_row["into_wall"]) * _bs if top > 0 else best
	var y := minf(Num.f(_row["end_height"]), top) if top > 0 else Num.f(_row["street_height"])
	return Vector3(kaiju_at.x + facing.x * into, y, kaiju_at.z + facing.z * into)


## How far along the beam's line (from the kaiju) it meets building `b`'s footprint; INF if it
## does not.
func _enter(b: RampageSim.Building) -> float:
	var dir := _sim.facing
	var lo := Vector2(b.x - b.w * 0.5, b.z - b.d * 0.5) - _sim.kaiju_pos
	var hi := lo + Vector2(b.w, b.d)
	var t0 := -INF
	var t1 := INF
	for a: int in 2:
		if absf(dir[a]) < 0.000001:
			if lo[a] > 0.0 or hi[a] < 0.0:
				return INF
			continue
		var ta := lo[a] / dir[a]
		var tb := hi[a] / dir[a]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
	return t0 if t1 >= t0 and t0 > 0.0 else INF


## `count` points up the wall from where the beam lands, each a way to one side: the lashes that
## crawl up the facade.
func _lash_targets(rng: RandomNumberGenerator, count: int) -> Array[Vector3]:
	var axis := _sim.facing
	var side := Vector3(-axis.y, 0.0, axis.x)
	var climb: Array = _row["lash_climb"]
	var out: Array[Vector3] = []
	for i: int in count:
		var up := rng.randf_range(Num.f(climb[0]), Num.f(climb[1])) * _bs
		var across := rng.randf_range(-1.0, 1.0) * Num.f(_row["lash_side"]) * _bs
		out.append(_end + side * across + Vector3.UP * up)
	return out
