extends RefCounted
## The adult at its spawn (R 19.4): a stage-4 kaiju (capture_growth's adult upgrades, city seed 0)
## stands where it rose from the river for SECONDS, the gameplay camera at rest behind it
## (CameraTuning offset x zoom). With BuildingFade's rule deciding which buildings fade, the
## feet must be in sight (no standing chunk of an unfaded building on the line from the eye) on
## at least FEET_SHARE of the frames, and the eye never inside a standing chunk of an unfaded
## building. Headless and sim-only: the camera is the rest framing, without easing, shake or lead.

const Growth := preload("res://tools/capture/capture_growth.gd")
const STAGE := 4
const SECONDS := 4.0
const FEET_SHARE := 0.95
## The feet sight line ends this high above the ground (units), sampled every SIGHT_STEP units.
const FEET_SIGHT := 0.5
const SIGHT_STEP := 0.5

var _check: Callable


func _init(p_check: Callable) -> void:
	_check = p_check


func run() -> void:
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), Growth.LEVELS[STAGE - 1], "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var layout := CityGrowth.layout(Content.tuning(), STAGE, Seeds.make("city", 0))
	var sim := RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 0))
	sim.emerge.start(sim)
	var dt := 1.0 / 60.0
	while sim.emerge.active:
		sim.step(dt, Vector2.ZERO, false, 0)
	var frames := int(SECONDS * 60.0)
	var seen := 0
	var inside := 0
	for _f: int in frames:
		sim.step(dt, Vector2.ZERO, false, 0)
		var feet := Vector3(sim.kaiju_pos.x, sim.stand_y, sim.kaiju_pos.y)
		var eye := feet + CameraTuning.offset() * CameraTuning.zoom(sim.body_scale())
		var reach := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale()
		var ahead := Vector3(sim.facing.x, 0, sim.facing.y) * reach
		var sight := BuildingFade.targets(feet, sim.reach_height(), ahead)
		var opaque: Array[RampageSim.Building] = []
		for b: RampageSim.Building in sim.buildings:
			if not BuildingFade.blocks(eye, sight, b):
				opaque.append(b)
		seen += 0 if _blocked(eye, feet + Vector3(0, FEET_SIGHT, 0), opaque) else 1
		inside += 1 if _blocked(eye, eye, opaque) else 0
	(
		_check
		. call(
			seen >= FEET_SHARE * frames and inside == 0,
			(
				(
					"the adult's feet are in sight at its spawn on %d of %d frames (>= %d%%) and the camera"
					+ " is inside an opaque tower on %d"
				)
				% [seen, frames, roundi(FEET_SHARE * 100.0), inside]
			)
		)
	)


## Whether a standing chunk of one of `buildings` lies on the segment eye -> to (or at `eye`
## itself when to == eye).
static func _blocked(eye: Vector3, to: Vector3, buildings: Array[RampageSim.Building]) -> bool:
	var steps := maxi(1, ceili(eye.distance_to(to) / SIGHT_STEP))
	var lo := Vector2(minf(eye.x, to.x), minf(eye.z, to.z))
	var hi := Vector2(maxf(eye.x, to.x), maxf(eye.z, to.z))
	for b: RampageSim.Building in buildings:
		if b.frame == null:
			continue
		if b.x + b.w * 0.5 < lo.x or b.x - b.w * 0.5 > hi.x:
			continue
		if b.z + b.d * 0.5 < lo.y or b.z - b.d * 0.5 > hi.y:
			continue
		var corner := Vector3(b.x - b.w * 0.5, 0.0, b.z - b.d * 0.5)
		for i: int in range(0 if to == eye else 1, steps + (1 if to == eye else 0)):
			var c := Vector3i((eye.lerp(to, float(i) / steps) - corner).floor())
			if b.frame.alive(c):
				return true
	return false
