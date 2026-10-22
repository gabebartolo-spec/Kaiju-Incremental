class_name ThunderBeam
extends Node3D
## The Thunder Beam (D-112, VFX_STYLE family 6): the Lightning Breath's bolt held for the beam's
## seconds. Its main channel runs from the jaw along the kaiju's facing to the sim's full beam
## range and is re-struck on the stroke schedule while the head steers; at each stroke its branches
## lash the buildings the beam crosses (the ones the sim is coating, D-129). It replaces the solid
## emissive box. Reads the sim's state and decides nothing; the burning is the sim's existing coat.

var rig: BoltRig
var _sim: RampageSim
var _kaiju: Node3D
var _jaw: Node3D
var _run: int
var _bolts := 0
var _bs: float
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
	var length := Num.f(_sim.powers_cfg["beam_range"]) * _bs
	var end := kaiju_at + facing * length + Vector3(0, Num.f(_row["end_height"]), 0)
	rig.aim(mouth, end)


## `count` points on the buildings the beam crosses (the sim's corridor, a little wider), each at
## a height on the wall facing the beam; short of buildings, forks into the street beside it.
func _lash_targets(rng: RandomNumberGenerator, count: int) -> Array[Vector3]:
	var axis := _sim.facing
	var reach := Num.f(_sim.powers_cfg["beam_range"]) * _bs
	var slack := Num.f(_row["lash_slack"]) * _bs
	var half := Num.f(_sim.powers_cfg["beam_half_width"]) * _bs + slack
	var near: Array[RampageSim.Building] = []
	for b: RampageSim.Building in _sim.buildings:
		var rel := Vector2(b.x, b.z) - _sim.kaiju_pos
		var along := rel.dot(axis)
		var wide := maxi(b.w, b.d) * 0.5
		var side := absf(rel.dot(axis.orthogonal()))
		if along > -wide and along < reach + wide and side < half + wide:
			near.append(b)
	var out: Array[Vector3] = []
	while out.size() < count and not near.is_empty():
		var b: RampageSim.Building = near.pop_at(rng.randi_range(0, near.size() - 1))
		var top := b.frame.top_below(floori(b.w * 0.5), floori(b.d * 0.5), b.height)
		if top > 0:
			out.append(_wall_point(b, rng, top))
	while out.size() < count:
		out.append(_street_fork(rng, reach))
	return out


## A point on building `b`'s wall facing the beam, at a random height up its standing part.
func _wall_point(b: RampageSim.Building, rng: RandomNumberGenerator, top: int) -> Vector3:
	var centre := Vector2(b.x, b.z)
	var axis := _sim.facing
	var on_axis := _sim.kaiju_pos + axis * (centre - _sim.kaiju_pos).dot(axis)
	var wall := centre + (on_axis - centre).normalized() * minf(b.w, b.d) * 0.5
	var share := rng.randf_range(Num.f(_row["lash_height"][0]), Num.f(_row["lash_height"][1]))
	return Vector3(wall.x, maxf(1.0, (top + 1) * share), wall.y)


## A point in the street a way along the beam and to one side of it.
func _street_fork(rng: RandomNumberGenerator, reach: float) -> Vector3:
	var axis := _sim.facing
	var along := reach * rng.randf_range(0.2, 0.95)
	var side := Num.f(_row["fork_side"]) * _bs * rng.randf_range(-1.0, 1.0)
	var at := _sim.kaiju_pos + axis * along + axis.orthogonal() * side
	return Vector3(at.x, 0.5, at.y)
