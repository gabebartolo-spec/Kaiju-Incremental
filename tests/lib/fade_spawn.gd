extends RefCounted
## The rise from the river in sight (R 19.4, comment #27 "Kaiju spawn seems to be blocked by
## buildings in the foreground"): for each stage (capture_growth's upgrades, the city and army a
## real first run gets), the kaiju rises from the river, wades in and stands SECONDS, while the
## camera follows it the way Rampage does (CameraFollow from its first frame, the body eased in
## at the model's 12/s) and BuildingFade, fed the eye and CityView's sight points, fades what it
## decides. The kaiju is seen on a frame when the eye is not in a standing chunk of a building
## that still hides (opacity above HIDES) and the line to the middle of its body above the water
## is clear of them; it must be seen on SEEN_SHARE of the frames it is above the water, and its
## feet on SEEN_SHARE of the standing frames. Headless and sim-only: no shake, dip or breath move.

const Kit := preload("res://tools/capture/capture_kit.gd")
const SECONDS := 4.0
const SEEN_SHARE := 0.95
## A building still hides what is behind it while more of its screen door than this is drawn.
const HIDES := 0.5
## The body's top (share of its height) and the feet sight line's end above the ground (units).
const TOP := 0.9
const FEET_SIGHT := 0.5
## The sight lines are sampled every SIGHT_STEP units; the model eases to the sim at BODY_FOLLOW/s
## (RampageAbility.place).
const SIGHT_STEP := 0.5
const BODY_FOLLOW := 12.0
const DT := 1.0 / 60.0

var _check: Callable


func _init(p_check: Callable) -> void:
	_check = p_check


func run() -> void:
	for stage: int in range(1, CityGrowth.stage_count(Content.tuning()) + 1):
		_stage(stage)


func _stage(stage: int) -> void:
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), Kit.STAGE_LEVELS[stage - 1], "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var tier := Num.i(stats["size"])
	var layout := CityGrowth.layout(Content.tuning(), tier, Seeds.make("city", 0))
	var sim := RampageSim.new(stats, CityGrowth.for_stats(stats), layout, Seeds.make("army", 0))
	sim.emerge.start(sim)
	var water := -Num.f(sim.city.get("river_depth", 0.0))
	var body := Vector3(sim.kaiju_pos.x, sim.stand_y, sim.kaiju_pos.y)
	var zoom := CameraTuning.zoom(sim.body_scale())
	var follow := CameraFollow.new(body, CameraTuning.offset())
	follow.step(body, CameraTuning.offset() * zoom, 1.0)  # Rampage._ready's first placement
	var fade := BuildingFade.new(sim.buildings, func(_n: int) -> BuildingView: return null)
	var shown := 0
	var above := 0
	var feet_seen := 0
	var standing := 0
	var left := int(SECONDS / DT)
	while left > 0:
		var rising := sim.emerge.active
		sim.step(DT, Vector2.ZERO, false, RampageSim.STOMP)
		var at := Vector3(sim.kaiju_pos.x, sim.stand_y, sim.kaiju_pos.y)
		body = body.lerp(at, minf(1.0, DT * BODY_FOLLOW))
		follow.step(body, CameraTuning.offset() * zoom, DT)
		follow.step_lead(body, sim.body_scale(), false, DT)
		var eye := follow.eye()
		fade.update(eye, BuildingFade.sight_of(sim, eye), DT)
		var hiding: Array[RampageSim.Building] = []
		for n: int in sim.buildings.size():
			if fade.opacity(n) > HIDES:
				hiding.append(sim.buildings[n])
		var inside := _blocked(eye, eye, hiding)
		var top := sim.stand_y + sim.reach_height() * TOP
		if top > water:
			above += 1
			var mid := Vector3(at.x, (maxf(sim.stand_y, water) + top) * 0.5, at.z)
			shown += 0 if inside or _blocked(eye, mid, hiding) else 1
		if not rising:
			left -= 1
			standing += 1
			var feet := at + Vector3(0, FEET_SIGHT, 0)
			feet_seen += 0 if inside or _blocked(eye, feet, hiding) else 1
	_check.call(
		shown >= SEEN_SHARE * above and feet_seen >= SEEN_SHARE * standing,
		(
			(
				"stage %d: the kaiju is in sight on %d of %d frames above the water through the"
				+ " rise and walk-in, and its feet on %d of %d standing frames (>= %d%% each)"
			)
			% [stage, shown, above, feet_seen, standing, roundi(SEEN_SHARE * 100.0)]
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
