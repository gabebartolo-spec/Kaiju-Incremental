extends SceneTree
## Fire spread at the game camera (R 26.2-26.4, D-126, D-129): the croc with City Ablaze and
## Five-Alarm is set down before the nearest low, wide block that has neighbours, breathes on it,
## and the fire spreads; the block burns out and collapses. The real Rampage, its own camera, the
## real breath (its seeded ignite chance; breathes again when ready until the block catches).
## Prints the physics
## frame of each beat ("FIREBEAT <frame> <what>") so the movie can be cut to them. Needs a window,
## --fixed-fps 60 and the no-focus override.cfg.
##
##   godot --path . --resolution 1920x1080 --windowed --fixed-fps 60 --write-movie <out>.avi \
##     --script tools/capture/capture_fire_spread.gd -- --run=1 --after=2.0 --min-tier=1 --stop=0.4
## --headless (no movie) prints the beats: pick a --run (time of day, army seed) that lights.

const LEVELS := {"r_ablaze": 1, "r_alarm": 3}
## A target this big (chunks) stands through the breath, so the breath can set it alight (the
## breath breaks the small blocks it reaches outright, and a broken block has nothing to burn).
const MIN_CHUNKS := 80
## Frames the camera gets to settle on the kaiju once it is set down before the block.
const SETTLE := 120
## At most this many floors, so it burns out within a short clip.
const MAX_FLOORS := 8
## Gives up after this many physics frames.
const LIMIT := 60 * 60

var _run := 1
var _after := 2.0
var _min_tier := 1
var _stop := 0.4
var _target := -1


## The scripted input: set down before a low, wide block with neighbours and breathe until
## something catches; then stand and watch the fire spread and burn out.
class Plan:
	extends RefCounted
	var target := -1
	var lit := -1  # the first building the breath set burning
	var lit_at := -1
	var min_tier := 1
	var pinned := false  # --target: the block to light, not the nearest one
	## Stands this share of the breath's reach off the target's footprint: far enough that its
	## claws (they rake ahead on their own) do not break the block it lights.
	var stop_share := 0.4
	var _settled := 0

	func input(s: RampageSim) -> Dictionary:
		if s.emerge.active:
			return {}
		var fire := s.powers.fire
		if target < 0 or (pinned and _settled == 0):
			target = target if pinned else pick(s)
			face(s, s.buildings[target])
		_settled += 1
		if lit_at < 0 and fire.state.has(FireSpread.State.BURNING):
			lit = fire.state.find(FireSpread.State.BURNING)
			lit_at = Engine.get_physics_frames()
			var alive := s.buildings[lit].frame.alive_count
			print(
				"FIREBEAT %d lit %d (target %d), %d chunks standing" % [lit_at, lit, target, alive]
			)
		if _settled < SETTLE or lit_at >= 0:
			return {}
		return _breathe(s)

	## Sets the kaiju down in the street before `b`, facing it, the block inside the breath's reach
	## (the walk there is not the point of the clip; the cut starts at the breath).
	func face(sim: RampageSim, b: RampageSim.Building) -> void:
		var at := Vector2(b.x, b.z)
		var away := (sim.kaiju_pos - at).normalized()
		var stop := sim.ability_reach() * stop_share + Vector2(b.w, b.d).length() * 0.5
		sim.kaiju_pos = at + away * stop
		sim.facing = -away
		print("FIREBEAT - placed %s, %.1f m from the centre (reach %.1f, stop %.1f)" % [sim.kaiju_pos, sim.kaiju_pos.distance_to(at), sim.ability_reach(), stop])

	## The nearest big, low standing ordinary building with at least two neighbours a fire can
	## reach (low: it burns out sooner, burn_per_floor).
	func pick(sim: RampageSim) -> int:
		var best := -1
		var best_d := INF
		var fire := sim.powers.fire
		for i: int in sim.buildings.size():
			var b := sim.buildings[i]
			if b.frame.alive_count < MIN_CHUNKS or b.height > MAX_FLOORS or b.tier < min_tier:
				continue
			if b.landmark != "":
				continue
			var d := Vector2(b.x, b.z).distance_to(sim.kaiju_pos)
			var near: PackedInt32Array = fire._neighbours(i)[0]
			if d < best_d and near.size() >= 2:
				best = i
				best_d = d
		print("FIREBEAT - target %d at %.1f m" % [best, best_d])
		return best

	func _breathe(s: RampageSim) -> Dictionary:
		if s.ability_ready_in > 0.0:
			return {}
		print("FIREBEAT %d breath" % Engine.get_physics_frames())
		return {"signature": true}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--run="):
			_run = arg.substr(6).to_int()
		elif arg.begins_with("--target="):
			_target = arg.substr(9).to_int()
		elif arg.begins_with("--stop="):
			_stop = arg.substr(7).to_float()
		elif arg.begins_with("--min-tier="):
			_min_tier = arg.substr(11).to_int()
		elif arg.begins_with("--after="):
			_after = arg.substr(8).to_float()
	_go.call_deferred()


func _go() -> void:
	await process_frame
	var species := Content.species_def("reptilian")
	var tree := UpgradeTree.new(Content.upgrades(), LEVELS, "reptilian")
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, tree)
	var rampage := Rampage.new()
	var layout := CityGen.generate(Seeds.make("city", 0), Content.section("city"))
	rampage.setup(species, stats, layout, _run)
	print("FIREBEAT 0 time of day %s" % Content.time_for_run(_run))
	rampage.autoplay_signature = false
	var sim := rampage.sim
	# The claws rake ahead on their own every 2 s, farther than the baby's breath reaches (swipe
	# 7 m, breath 5.9 m): no place to stand lights the block without the rake breaking it. Off for
	# this shot only (a clip setup, not a game rule).
	sim.stats["swipe_damage"] = 0.0
	var plan := Plan.new()
	plan.min_tier = _min_tier
	plan.stop_share = _stop
	plan.target = _target
	plan.pinned = _target >= 0
	rampage.scripted = plan.input
	root.add_child(rampage)
	print("FIREBEAT %d start (physics frame)" % Engine.get_physics_frames())
	var frames := 0
	var seen := {}
	var down_at := -1  # the lit building is down: it gave way (burnt out) or was broken
	var giving := false
	while frames < LIMIT and not sim.over:
		await physics_frame
		frames += 1
		var fire := sim.powers.fire
		_note(fire, frames, seen)
		if plan.lit < 0 or down_at >= 0:
			if down_at >= 0 and frames >= down_at + roundi(_after * 60.0):
				break
			continue
		if not giving and fire._crumbling.has(plan.lit):
			giving = true
			print("FIREBEAT %d lit building gives way" % Engine.get_physics_frames())
		if fire.state[plan.lit] == FireSpread.State.BURNT:
			down_at = frames
			var how := "burnt out" if giving or fire.timer[plan.lit] <= 0.0 else "broken first"
			print("FIREBEAT %d lit building down, %s" % [Engine.get_physics_frames(), how])
	var fire_now := sim.powers.fire
	print("FIREBEAT %d end: %d burnt out" % [frames, fire_now.burnt_out])
	rampage.queue_free()
	await process_frame
	quit()


## Prints the first frame of each beat from the fire's own state (the events are the view's).
func _note(fire: FireSpread, frames: int, seen: Dictionary) -> void:
	var counts := [0, 0, 0]  # glowing, burning, burnt
	for i: int in fire.state.size():
		match fire.state[i]:
			FireSpread.State.GLOWING:
				counts[0] += 1
			FireSpread.State.BURNING:
				counts[1] += 1
			FireSpread.State.BURNT:
				counts[2] += 1
	var key := "%d/%d/%d" % counts
	if not seen.has(key):
		seen[key] = true
		print(
			"FIREBEAT %d glowing %d burning %d burnt %d" % [frames, counts[0], counts[1], counts[2]]
		)
